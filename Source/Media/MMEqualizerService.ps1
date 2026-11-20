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
# PRESETS, AND JSON PERSISTENCE IN %APPDATA%\PSBOOMBOX\EQUALIZER.JSON.
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

    [Void]Initialize(
        [String]$ConfigDirectory
    ) {
        $this.Enabled            = $false
        $this.ActivePresetName   = 'Flat'
        $this.PreampDb           = 0
        $this.BandGainsDb        = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $this.BuiltInPresets     = [List[MMEqualizerPreset]]::new()
        $this.UserPresets        = [List[MMEqualizerPreset]]::new()
        $this.LastError          = ''
        $this.OnEqualizerChanged = $null

        [String]$TargetDir = $ConfigDirectory

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            $TargetDir = [MMEqualizerService]::ConfigDirectoryOverride
        }

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            [String]$AppDataRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
            $TargetDir           = [Path]::Combine($AppDataRoot, 'PSBoombox')
        }

        $this.ConfigDirectory = [Path]::GetFullPath($TargetDir)
        $this.ConfigFilePath  = [Path]::Combine($this.ConfigDirectory, 'equalizer.json')

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

        If([File]::Exists($this.ConfigFilePath) -EQ $false) {
            Return
        }

        Try {
            [String]$RawJson = [File]::ReadAllText($this.ConfigFilePath, [Encoding]::UTF8)

            If($RawJson.Trim().Length -EQ 0) {
                Return
            }

            [Object]$Parsed = $RawJson | ConvertFrom-Json -ErrorAction Stop

            If($null -EQ $Parsed) {
                Return
            }

            If(($null -NE $Parsed.PSObject.Properties['UserPresets']) -AND ($null -NE $Parsed.UserPresets)) {
                Foreach($RawUser in $Parsed.UserPresets) {
                    If(($null -EQ $RawUser) -OR ($null -EQ $RawUser.PSObject.Properties['Name'])) {
                        Continue
                    }

                    [String]$UserName = [String]$RawUser.Name

                    If(($UserName.Trim().Length -EQ 0) -OR ($this.IsBuiltInPresetName($UserName) -EQ $true)) {
                        Continue
                    }

                    [Int]$UserPre     = ($null -NE $RawUser.PSObject.Properties['PreampDb']) ? [Int]$RawUser.PreampDb : 0
                    [Int[]]$UserBands = [Int[]]::new([MMEqualizerService]::BandCount)

                    If(($null -NE $RawUser.PSObject.Properties['Bands']) -AND ($null -NE $RawUser.Bands)) {
                        For([Int]$BIdx = 0; $BIdx -LT [MMEqualizerService]::BandCount; $BIdx++) {
                            If($BIdx -LT $RawUser.Bands.Count) {
                                $UserBands[$BIdx] = [Int]$RawUser.Bands[$BIdx]
                            }
                        }
                    }

                    $this.UserPresets.Add([MMEqualizerPreset]::new($UserName, $UserPre, $UserBands, $false))
                }
            }

            If($null -NE $Parsed.PSObject.Properties['Enabled']) {
                $this.Enabled = [Boolean]$Parsed.Enabled
            }

            If($null -NE $Parsed.PSObject.Properties['PreampDb']) {
                $this.PreampDb = [Math]::Clamp([Int]$Parsed.PreampDb, [MMEqualizerService]::MinGainDb, [MMEqualizerService]::MaxGainDb)
            }

            If(($null -NE $Parsed.PSObject.Properties['Bands']) -AND ($null -NE $Parsed.Bands)) {
                [Int[]]$LoadedBands = [Int[]]::new([MMEqualizerService]::BandCount)

                For([Int]$Idx = 0; $Idx -LT [MMEqualizerService]::BandCount; $Idx++) {
                    If($Idx -LT $Parsed.Bands.Count) {
                        $LoadedBands[$Idx] = [Int]$Parsed.Bands[$Idx]
                    }
                }

                $this.BandGainsDb = [MMEqualizerPreset]::NormalizeBands($LoadedBands)
            }

            [String]$SavedPreset = ($null -NE $Parsed.PSObject.Properties['ActivePreset']) ? [String]$Parsed.ActivePreset : ''

            If($SavedPreset.Trim().Length -GT 0) {
                [MMEqualizerPreset]$Matched = $this.FindPreset($SavedPreset)

                If($null -NE $Matched) {
                    $this.ActivePresetName = $Matched.Name

                    If(($null -EQ $Parsed.PSObject.Properties['Bands']) -OR ($null -EQ $Parsed.Bands)) {
                        $this.PreampDb    = $Matched.PreampDb
                        $this.BandGainsDb = [MMEqualizerPreset]::NormalizeBands($Matched.BandGainsDb)
                    }
                } Else {
                    $this.ActivePresetName = [MMEqualizerService]::CustomPresetName
                }
            }
        } Catch {
            $this.LastError        = "Failed to parse equalizer settings: $($_.Exception.Message)"
            $this.Enabled          = $false
            $this.ActivePresetName = 'Flat'
            $this.PreampDb         = 0
            $this.BandGainsDb      = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        }
    }

    [Boolean]Save() {
        Try {
            If([Directory]::Exists($this.ConfigDirectory) -EQ $false) {
                $null = [Directory]::CreateDirectory($this.ConfigDirectory)
            }

            [List[Hashtable]]$UserList = [List[Hashtable]]::new()

            Foreach($UserPreset in $this.UserPresets) {
                $UserList.Add(@{
                    Name     = $UserPreset.Name
                    PreampDb = $UserPreset.PreampDb
                    Bands    = @($UserPreset.BandGainsDb)
                })
            }

            [Hashtable]$Payload = @{
                Version      = 1
                Enabled      = $this.Enabled
                ActivePreset = $this.ActivePresetName
                PreampDb     = $this.PreampDb
                Bands        = @($this.BandGainsDb)
                UserPresets  = @($UserList)
            }

            [String]$JsonText        = $Payload | ConvertTo-Json -Depth 5
            [UTF8Encoding]$Utf8NoBom = [UTF8Encoding]::new($false)

            [File]::WriteAllText($this.ConfigFilePath, $JsonText, $Utf8NoBom)

            Return $true
        } Catch {
            $this.LastError = "Failed to save equalizer settings: $($_.Exception.Message)"

            Return $false
        }
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
