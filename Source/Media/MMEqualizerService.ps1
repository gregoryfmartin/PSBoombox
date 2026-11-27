using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest





###############################################################################
#
# MM EQUALIZER SERVICE
#
# MANAGES 10-BAND ISO EQUALIZER STATE, 9 BAKED-IN PRESETS, USER CUSTOM
# PRESETS, AND JSON PERSISTENCE IN %APPDATA%\PSBOOMBOX\CONFIG.JSON.
#
###############################################################################

Class MMEqualizerService {
    Static [Int]$BandCount                   = 10
    Static [Int]$MinGainDb                   = -12
    Static [Int]$MaxGainDb                   = 12
    Static [String]$CustomPresetName         = 'Custom'
    Static [String]$ConfigDirectoryOverride  = ''
    Static [String[]]$BandLabels             = @('31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k')

    [Boolean]$Enabled
    [String]$ActivePresetName
    [Int]$PreampDb
    [Int[]]$BandGainsDb
    [List[MMEqualizerPreset]]$BuiltInPresets
    [List[MMEqualizerPreset]]$UserPresets
    [PBConfigService]$ConfigService
    [String]$ConfigDirectory
    [String]$ConfigFilePath
    [String]$LastError
    [ScriptBlock]$OnEqualizerChanged

    MMEqualizerService() {
        $this.Initialize('')
    }

    MMEqualizerService(
        [String]$ConfigDirectory
    ) {
        $this.Initialize($ConfigDirectory)
    }

    MMEqualizerService(
        [PBConfigService]$ConfigService
    ) {
        $this.InitializeWithConfig($ConfigService)
    }

    [Void]Initialize(
        [String]$ConfigDirectory
    ) {
        [String]$TargetDir = $ConfigDirectory

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            $TargetDir = [MMEqualizerService]::ConfigDirectoryOverride
        }

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            $TargetDir = [PBConfigService]::ConfigDirectoryOverride
        }

        [PBConfigService]$LocalConfig = (($null -NE $TargetDir) -AND ($TargetDir.Trim().Length -GT 0)) ? [PBConfigService]::new($TargetDir) : [PBConfigService]::new()

        $this.InitializeWithConfig($LocalConfig)
    }

    [Void]InitializeWithConfig(
        [PBConfigService]$ConfigService
    ) {
        [PBConfigService]$ResolvedConfig = ($null -NE $ConfigService) ? $ConfigService : [PBConfigService]::new()

        $this.Enabled            = $false
        $this.ActivePresetName   = 'Flat'
        $this.PreampDb           = 0
        $this.BandGainsDb        = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $this.BuiltInPresets     = [List[MMEqualizerPreset]]::new()
        $this.UserPresets        = [List[MMEqualizerPreset]]::new()
        $this.ConfigService      = $ResolvedConfig
        $this.ConfigDirectory    = $ResolvedConfig.ConfigDirectory
        $this.ConfigFilePath     = $ResolvedConfig.ConfigFilePath
        $this.LastError          = ''
        $this.OnEqualizerChanged = $null

        $this.PopulateBuiltInPresets()
    }

    [Void]PopulateBuiltInPresets() {
        $this.BuiltInPresets.Clear()

        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Flat', 0, @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Bass Boost', -2, @(6, 5, 4, 2, 0, 0, 0, 0, 0, 0), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Rock', -1, @(4, 3, 2, 1, -1, -1, 1, 3, 4, 4), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Pop', -1, @(-1, 1, 3, 4, 3, 1, -1, -1, 1, 2), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Jazz', 0, @(3, 2, 1, 2, -1, -1, 0, 1, 2, 3), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Classical', 0, @(0, 0, 0, 0, 0, 0, -2, -2, -2, -3), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Vocal', 0, @(-2, -2, -1, 1, 3, 4, 3, 1, 0, -1), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Electronic', -2, @(5, 4, 2, 0, -2, 1, 2, 3, 4, 5), $true))
        $this.BuiltInPresets.Add([MMEqualizerPreset]::new('Treble Boost', -2, @(0, 0, 0, 0, 0, 1, 3, 5, 6, 6), $true))
    }

    [Void]NotifyChanged() {
        If($null -NE $this.OnEqualizerChanged) {
            $this.OnEqualizerChanged.Invoke($this)
        }
    }

    [Double[]]GetBandGainsAsDoubleArray() {
        [Double[]]$Values = [Double[]]::new([MMEqualizerService]::BandCount)

        For([Int]$Idx = 0; $Idx -LT [MMEqualizerService]::BandCount; $Idx++) {
            $Values[$Idx] = [Double]$this.BandGainsDb[$Idx]
        }

        Return $Values
    }

    [Boolean]IsBuiltInPresetName(
        [String]$Name
    ) {
        If(($null -EQ $Name) -OR ($Name.Trim().Length -EQ 0)) {
            Return $false
        }

        [String]$Trimmed = $Name.Trim()

        If([String]::Equals($Trimmed, [MMEqualizerService]::CustomPresetName, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
            Return $true
        }

        Foreach($Preset in $this.BuiltInPresets) {
            If([String]::Equals($Preset.Name, $Trimmed, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                Return $true
            }
        }

        Return $false
    }

    [MMEqualizerPreset]FindPreset(
        [String]$Name
    ) {
        If(($null -EQ $Name) -OR ($Name.Trim().Length -EQ 0)) {
            Return $null
        }

        [String]$Trimmed = $Name.Trim()

        Foreach($Preset in $this.BuiltInPresets) {
            If([String]::Equals($Preset.Name, $Trimmed, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                Return $Preset
            }
        }

        Foreach($Preset in $this.UserPresets) {
            If([String]::Equals($Preset.Name, $Trimmed, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                Return $Preset
            }
        }

        Return $null
    }

    [Boolean]IsActivePresetDeletable() {
        Foreach($Preset in $this.UserPresets) {
            If([String]::Equals($Preset.Name, $this.ActivePresetName, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                Return $true
            }
        }

        Return $false
    }

    [List[MMEqualizerPreset]]GetAllPresets() {
        [List[MMEqualizerPreset]]$Combined = [List[MMEqualizerPreset]]::new()

        Foreach($Preset in $this.BuiltInPresets) {
            $Combined.Add($Preset)
        }

        [List[MMEqualizerPreset]]$SortedUser = [List[MMEqualizerPreset]]::new($this.UserPresets)
        $SortedUser.Sort({
            Param(
                [MMEqualizerPreset]$Left,
                [MMEqualizerPreset]$Right
            )

            Return [StringComparer]::OrdinalIgnoreCase.Compare($Left.Name, $Right.Name)
        })

        Foreach($UserPreset in $SortedUser) {
            $Combined.Add($UserPreset)
        }

        Return $Combined
    }

    [Void]Load() {
        $this.LastError = ''
        $this.UserPresets.Clear()
        $this.Enabled          = $false
        $this.ActivePresetName = 'Flat'
        $this.PreampDb         = 0
        $this.BandGainsDb      = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

        If($this.ConfigService.IsLoaded -EQ $false) {
            $this.ConfigService.Load()
        }

        If($this.ConfigService.LastError.Length -GT 0) {
            $this.LastError = $this.ConfigService.LastError
        }

        If($null -NE $this.ConfigService.EqualizerUserPresets) {
            Foreach($RawUser in $this.ConfigService.EqualizerUserPresets) {
                If($null -EQ $RawUser) {
                    Continue
                }

                [String]$UserName = [String]$RawUser.Name

                If(($UserName.Trim().Length -EQ 0) -OR ($this.IsBuiltInPresetName($UserName) -EQ $true)) {
                    Continue
                }

                [Int]$UserPre     = [Int]$RawUser.PreampDb
                [Int[]]$UserBands = [MMEqualizerPreset]::NormalizeBands([Int[]]$RawUser.Bands)

                $this.UserPresets.Add([MMEqualizerPreset]::new($UserName, $UserPre, $UserBands, $false))
            }
        }

        $this.Enabled     = $this.ConfigService.EqualizerEnabled
        $this.PreampDb    = [Math]::Clamp($this.ConfigService.EqualizerPreampDb, [MMEqualizerService]::MinGainDb, [MMEqualizerService]::MaxGainDb)
        $this.BandGainsDb = [MMEqualizerPreset]::NormalizeBands($this.ConfigService.EqualizerBands)

        [String]$SavedPreset = $this.ConfigService.EqualizerActivePreset

        If($SavedPreset.Trim().Length -GT 0) {
            [MMEqualizerPreset]$Matched = $this.FindPreset($SavedPreset)

            If($null -NE $Matched) {
                $this.ActivePresetName = $Matched.Name
            } Else {
                $this.ActivePresetName = [MMEqualizerService]::CustomPresetName
            }
        }
    }

    [Boolean]Save() {
        [List[Hashtable]]$UserList = [List[Hashtable]]::new()

        Foreach($UserPreset in $this.UserPresets) {
            $UserList.Add(@{
                Name     = $UserPreset.Name
                PreampDb = $UserPreset.PreampDb
                Bands    = @($UserPreset.BandGainsDb)
            })
        }

        $this.ConfigService.SetEqualizerSection(
            $this.Enabled,
            $this.ActivePresetName,
            $this.PreampDb,
            $this.BandGainsDb,
            $UserList
        )

        [Boolean]$Saved = $this.ConfigService.Save()

        If($Saved -EQ $false) {
            $this.LastError = $this.ConfigService.LastError
        }

        Return $Saved
    }

    [Void]SetEnabled(
        [Boolean]$Enabled
    ) {
        If($this.Enabled -NE $Enabled) {
            $this.Enabled = $Enabled

            $null = $this.Save()
            $this.NotifyChanged()
        }
    }

    [Boolean]ToggleEnabled() {
        $this.SetEnabled(($this.Enabled -EQ $false))

        Return $this.Enabled
    }

    [Void]SetPreampDb(
        [Int]$GainDb
    ) {
        [Int]$Clamped = [Math]::Clamp($GainDb, [MMEqualizerService]::MinGainDb, [MMEqualizerService]::MaxGainDb)

        If(($this.PreampDb -NE $Clamped) -OR ($this.ActivePresetName -NE [MMEqualizerService]::CustomPresetName)) {
            $this.PreampDb         = $Clamped
            $this.ActivePresetName = [MMEqualizerService]::CustomPresetName

            $null = $this.Save()
            $this.NotifyChanged()
        }
    }

    [Void]AdjustPreamp(
        [Int]$DeltaDb
    ) {
        $this.SetPreampDb($this.PreampDb + $DeltaDb)
    }

    [Void]SetBandGainDb(
        [Int]$BandIndex,
        [Int]$GainDb
    ) {
        If(($BandIndex -LT 0) -OR ($BandIndex -GE [MMEqualizerService]::BandCount)) {
            Return
        }

        [Int]$Clamped = [Math]::Clamp($GainDb, [MMEqualizerService]::MinGainDb, [MMEqualizerService]::MaxGainDb)

        If(($this.BandGainsDb[$BandIndex] -NE $Clamped) -OR ($this.ActivePresetName -NE [MMEqualizerService]::CustomPresetName)) {
            $this.BandGainsDb[$BandIndex] = $Clamped
            $this.ActivePresetName        = [MMEqualizerService]::CustomPresetName

            $null = $this.Save()
            $this.NotifyChanged()
        }
    }

    [Void]AdjustBand(
        [Int]$BandIndex,
        [Int]$DeltaDb
    ) {
        If(($BandIndex -LT 0) -OR ($BandIndex -GE [MMEqualizerService]::BandCount)) {
            Return
        }

        $this.SetBandGainDb($BandIndex, ($this.BandGainsDb[$BandIndex] + $DeltaDb))
    }

    [Boolean]ApplyPreset(
        [String]$PresetName
    ) {
        [MMEqualizerPreset]$Preset = $this.FindPreset($PresetName)

        If($null -EQ $Preset) {
            Return $false
        }

        $this.ActivePresetName = $Preset.Name
        $this.PreampDb         = $Preset.PreampDb
        $this.BandGainsDb      = [MMEqualizerPreset]::NormalizeBands($Preset.BandGainsDb)

        $null = $this.Save()
        $this.NotifyChanged()

        Return $true
    }

    [String]CyclePreset(
        [Int]$Direction
    ) {
        [List[MMEqualizerPreset]]$All = $this.GetAllPresets()

        If($All.Count -EQ 0) {
            Return $this.ActivePresetName
        }

        [Int]$CurrentIdx = -1

        For([Int]$Idx = 0; $Idx -LT $All.Count; $Idx++) {
            If([String]::Equals($All[$Idx].Name, $this.ActivePresetName, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                $CurrentIdx = $Idx

                Break
            }
        }

        [Int]$Step    = ($Direction -LT 0) ? -1 : 1
        [Int]$NextIdx = ($CurrentIdx -LT 0) ? (($Step -GT 0) ? 0 : ($All.Count - 1)) : (($CurrentIdx + $Step + $All.Count) % $All.Count)

        $null = $this.ApplyPreset($All[$NextIdx].Name)

        Return $this.ActivePresetName
    }

    [Hashtable]SaveUserPreset(
        [String]$PresetName
    ) {
        [String]$Trimmed = ($null -EQ $PresetName) ? '' : $PresetName.Trim()

        If($Trimmed.Length -EQ 0) {
            Return @{
                Success = $false
                Message = 'Preset name cannot be empty.'
            }
        }

        If($this.IsBuiltInPresetName($Trimmed) -EQ $true) {
            Return @{
                Success = $false
                Message = "'$($Trimmed)' is reserved. Choose a custom preset name."
            }
        }

        [MMEqualizerPreset]$Existing = $null

        Foreach($UserPreset in $this.UserPresets) {
            If([String]::Equals($UserPreset.Name, $Trimmed, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                $Existing = $UserPreset

                Break
            }
        }

        If($null -NE $Existing) {
            $Existing.Name        = $Trimmed
            $Existing.PreampDb    = $this.PreampDb
            $Existing.BandGainsDb = [MMEqualizerPreset]::NormalizeBands($this.BandGainsDb)
        } Else {
            $this.UserPresets.Add([MMEqualizerPreset]::new($Trimmed, $this.PreampDb, $this.BandGainsDb, $false))
        }

        $this.ActivePresetName = $Trimmed

        [Boolean]$Saved = $this.Save()
        $this.NotifyChanged()

        If($Saved -EQ $false) {
            Return @{
                Success = $false
                Message = $this.LastError
            }
        }

        Return @{
            Success = $true
            Message = "Saved custom preset '$($Trimmed)'"
        }
    }

    [Hashtable]DeleteUserPreset(
        [String]$PresetName
    ) {
        [String]$Trimmed = ($null -EQ $PresetName) ? '' : $PresetName.Trim()

        If(($Trimmed.Length -EQ 0) -OR ($this.IsBuiltInPresetName($Trimmed) -EQ $true)) {
            Return @{
                Success = $false
                Message = 'Built-in presets cannot be deleted.'
            }
        }

        [Int]$TargetIdx = -1

        For([Int]$Idx = 0; $Idx -LT $this.UserPresets.Count; $Idx++) {
            If([String]::Equals($this.UserPresets[$Idx].Name, $Trimmed, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                $TargetIdx = $Idx

                Break
            }
        }

        If($TargetIdx -LT 0) {
            Return @{
                Success = $false
                Message = "User preset '$($Trimmed)' not found."
            }
        }

        [String]$DeletedName = $this.UserPresets[$TargetIdx].Name
        $this.UserPresets.RemoveAt($TargetIdx)

        If([String]::Equals($this.ActivePresetName, $DeletedName, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
            $this.ActivePresetName = [MMEqualizerService]::CustomPresetName
        }

        $null = $this.Save()
        $this.NotifyChanged()

        Return @{
            Success = $true
            Message = "Deleted custom preset '$($DeletedName)'"
        }
    }

    [Void]ResetToFlat() {
        $null = $this.ApplyPreset('Flat')
    }
}
