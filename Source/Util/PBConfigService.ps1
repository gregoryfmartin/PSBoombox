using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest





###############################################################################
#
# PB CONFIG SERVICE
#
# CENTRALIZED JSON CONFIGURATION MANAGER FOR %APPDATA%\PSBOOMBOX\CONFIG.JSON
# WITH GROUPED SECTIONS (THEME, EQUALIZER, NOTIFICATIONS), AUTO-CREATION ON
# FIRST LAUNCH, LEGACY MIGRATION, AND MALFORMED-JSON FALLBACK.
#
###############################################################################

Class PBConfigService {
    Static [Int]$SchemaVersion           = 1
    Static [String]$ConfigFileName       = 'config.json'
    Static [String]$ConfigDirectoryOverride = ''

    [String]$ConfigDirectory
    [String]$ConfigFilePath
    [Boolean]$IsLoaded
    [Boolean]$DidMigrateLegacyFiles
    [String]$LastError
    [String]$ThemeActiveTheme
    [String]$ThemeCustomThemePath
    [Boolean]$EqualizerEnabled
    [String]$EqualizerActivePreset
    [Int]$EqualizerPreampDb
    [Int[]]$EqualizerBands
    [List[Hashtable]]$EqualizerUserPresets
    [Boolean]$BurntToastEnabled

    PBConfigService() {
        $this.Initialize('')
    }

    PBConfigService(
        [String]$ConfigDirectory
    ) {
        $this.Initialize($ConfigDirectory)
    }

    [Void]Initialize(
        [String]$ConfigDirectory
    ) {
        [String]$TargetDir = $ConfigDirectory

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            $TargetDir = [PBConfigService]::ConfigDirectoryOverride
        }

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            [String]$AppDataRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
            $TargetDir           = [Path]::Combine($AppDataRoot, 'PSBoombox')
        }

        $this.ConfigDirectory       = [Path]::GetFullPath($TargetDir)
        $this.ConfigFilePath        = [Path]::Combine($this.ConfigDirectory, [PBConfigService]::ConfigFileName)
        $this.IsLoaded              = $false
        $this.DidMigrateLegacyFiles = $false
        $this.LastError             = ''

        $this.ResetDefaults()
    }

    [Void]ResetDefaults() {
        $this.ThemeActiveTheme      = 'PSBoombox Default'
        $this.ThemeCustomThemePath  = ''
        $this.EqualizerEnabled      = $false
        $this.EqualizerActivePreset = 'Flat'
        $this.EqualizerPreampDb     = 0
        $this.EqualizerBands        = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        $this.EqualizerUserPresets  = [List[Hashtable]]::new()
        $this.BurntToastEnabled     = $false
    }

    Static [Boolean]IsNumericValue(
        [Object]$Value
    ) {
        Return (($Value -IS [Int]) -OR ($Value -IS [Int64]) -OR ($Value -IS [Double]) -OR ($Value -IS [Decimal]))
    }

    [Void]ApplyThemeObject(
        [Object]$ThemeObj
    ) {
        If($null -EQ $ThemeObj) {
            Return
        }

        Try {
            If(($null -NE $ThemeObj.PSObject.Properties['ActiveTheme']) -AND ($ThemeObj.ActiveTheme -IS [String])) {
                [String]$SavedTheme = ([String]$ThemeObj.ActiveTheme).Trim()

                If($SavedTheme.Length -GT 0) {
                    $this.ThemeActiveTheme = $SavedTheme
                }
            }
        } Catch {
            # KEEP DEFAULT ACTIVE THEME ON MALFORMED VALUE
        }

        Try {
            If(($null -NE $ThemeObj.PSObject.Properties['CustomThemePath']) -AND ($ThemeObj.CustomThemePath -IS [String])) {
                $this.ThemeCustomThemePath = ([String]$ThemeObj.CustomThemePath).Trim()
            }
        } Catch {
            # KEEP DEFAULT CUSTOM THEME PATH ON MALFORMED VALUE
        }
    }

    [Void]ApplyEqualizerObject(
        [Object]$EqObj
    ) {
        If($null -EQ $EqObj) {
            Return
        }

        Try {
            If(($null -NE $EqObj.PSObject.Properties['Enabled']) -AND ($EqObj.Enabled -IS [Boolean])) {
                $this.EqualizerEnabled = [Boolean]$EqObj.Enabled
            }
        } Catch {
            # KEEP DEFAULT EQUALIZER ENABLED ON MALFORMED VALUE
        }

        Try {
            If(($null -NE $EqObj.PSObject.Properties['ActivePreset']) -AND ($EqObj.ActivePreset -IS [String])) {
                [String]$SavedPreset = ([String]$EqObj.ActivePreset).Trim()

                If($SavedPreset.Length -GT 0) {
                    $this.EqualizerActivePreset = $SavedPreset
                }
            }
        } Catch {
            # KEEP DEFAULT EQUALIZER PRESET ON MALFORMED VALUE
        }

        Try {
            If(($null -NE $EqObj.PSObject.Properties['PreampDb']) -AND ([PBConfigService]::IsNumericValue($EqObj.PreampDb) -EQ $true)) {
                $this.EqualizerPreampDb = [Math]::Clamp([Int]$EqObj.PreampDb, -12, 12)
            }
        } Catch {
            # KEEP DEFAULT PREAMP ON MALFORMED VALUE
        }

        Try {
            If(($null -NE $EqObj.PSObject.Properties['Bands']) -AND ($null -NE $EqObj.Bands) -AND ($EqObj.Bands -IS [IList])) {
                [Int[]]$LoadedBands = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

                For([Int]$Idx = 0; $Idx -LT 10; $Idx++) {
                    If($Idx -LT $EqObj.Bands.Count) {
                        [Object]$BandRaw = $EqObj.Bands[$Idx]

                        If([PBConfigService]::IsNumericValue($BandRaw) -EQ $true) {
                            $LoadedBands[$Idx] = [Math]::Clamp([Int]$BandRaw, -12, 12)
                        }
                    }
                }

                $this.EqualizerBands = $LoadedBands
            }
        } Catch {
            # KEEP DEFAULT BANDS ON MALFORMED VALUE
        }

        Try {
            If(($null -NE $EqObj.PSObject.Properties['UserPresets']) -AND ($null -NE $EqObj.UserPresets) -AND ($EqObj.UserPresets -IS [IList])) {
                [List[Hashtable]]$ParsedUsers = [List[Hashtable]]::new()

                Foreach($RawUser in $EqObj.UserPresets) {
                    If(($null -EQ $RawUser) -OR ($null -EQ $RawUser.PSObject.Properties['Name']) -OR (-NOT ($RawUser.Name -IS [String]))) {
                        Continue
                    }

                    [String]$UserName = ([String]$RawUser.Name).Trim()

                    If($UserName.Length -EQ 0) {
                        Continue
                    }

                    [Int]$UserPre = 0

                    If(($null -NE $RawUser.PSObject.Properties['PreampDb']) -AND ([PBConfigService]::IsNumericValue($RawUser.PreampDb) -EQ $true)) {
                        $UserPre = [Math]::Clamp([Int]$RawUser.PreampDb, -12, 12)
                    }

                    [Int[]]$UserBands = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

                    If(($null -NE $RawUser.PSObject.Properties['Bands']) -AND ($null -NE $RawUser.Bands) -AND ($RawUser.Bands -IS [IList])) {
                        For([Int]$BIdx = 0; $BIdx -LT 10; $BIdx++) {
                            If($BIdx -LT $RawUser.Bands.Count) {
                                [Object]$UserBandRaw = $RawUser.Bands[$BIdx]

                                If([PBConfigService]::IsNumericValue($UserBandRaw) -EQ $true) {
                                    $UserBands[$BIdx] = [Math]::Clamp([Int]$UserBandRaw, -12, 12)
                                }
                            }
                        }
                    }

                    $ParsedUsers.Add(@{
                        Name     = $UserName
                        PreampDb = $UserPre
                        Bands    = $UserBands
                    })
                }

                $this.EqualizerUserPresets = $ParsedUsers
            }
        } Catch {
            # KEEP DEFAULT USER PRESETS ON MALFORMED VALUE
        }
    }

    [Void]ApplyNotificationsObject(
        [Object]$NotifObj
    ) {
        If($null -EQ $NotifObj) {
            Return
        }

        Try {
            If(($null -NE $NotifObj.PSObject.Properties['BurntToastEnabled']) -AND ($NotifObj.BurntToastEnabled -IS [Boolean])) {
                $this.BurntToastEnabled = [Boolean]$NotifObj.BurntToastEnabled
            }
        } Catch {
            # KEEP DEFAULT NOTIFICATION ENABLED ON MALFORMED VALUE
        }
    }

    [List[String]]MigrateLegacyFiles() {
        # DEPRECATED: ONE-TIME MIGRATION FROM LEGACY THEME.JSON AND EQUALIZER.JSON; REMOVE IN A FUTURE RELEASE
        [List[String]]$MigratedPaths = [List[String]]::new()
        [String]$LegacyThemePath      = [Path]::Combine($this.ConfigDirectory, 'theme.json')
        [String]$LegacyEqPath         = [Path]::Combine($this.ConfigDirectory, 'equalizer.json')

        If([File]::Exists($LegacyThemePath) -EQ $true) {
            Try {
                [String]$RawTheme = [File]::ReadAllText($LegacyThemePath, [Encoding]::UTF8)

                If($RawTheme.Trim().Length -GT 0) {
                    [Object]$ParsedTheme = $RawTheme | ConvertFrom-Json -ErrorAction Stop

                    If($null -NE $ParsedTheme) {
                        $this.ApplyThemeObject($ParsedTheme)
                        $MigratedPaths.Add($LegacyThemePath)
                    }
                }
            } Catch {
                $this.LastError = "Failed to migrate legacy theme.json: $($_.Exception.Message)"
            }
        }

        If([File]::Exists($LegacyEqPath) -EQ $true) {
            Try {
                [String]$RawEq = [File]::ReadAllText($LegacyEqPath, [Encoding]::UTF8)

                If($RawEq.Trim().Length -GT 0) {
                    [Object]$ParsedEq = $RawEq | ConvertFrom-Json -ErrorAction Stop

                    If($null -NE $ParsedEq) {
                        $this.ApplyEqualizerObject($ParsedEq)
                        $MigratedPaths.Add($LegacyEqPath)
                    }
                }
            } Catch {
                $this.LastError = "Failed to migrate legacy equalizer.json: $($_.Exception.Message)"
            }
        }

        Return $MigratedPaths
    }

    [Void]Load() {
        $this.LastError             = ''
        $this.DidMigrateLegacyFiles = $false

        $this.ResetDefaults()

        If([File]::Exists($this.ConfigFilePath) -EQ $false) {
            [List[String]]$MigratedFiles = $this.MigrateLegacyFiles()
            [Boolean]$Saved              = $this.Save()

            If(($Saved -EQ $true) -AND ($MigratedFiles.Count -GT 0)) {
                $this.DidMigrateLegacyFiles = $true

                Foreach($LegacyFile in $MigratedFiles) {
                    Try {
                        If([File]::Exists($LegacyFile) -EQ $true) {
                            [File]::Delete($LegacyFile)
                        }
                    } Catch {
                        # IGNORE LEGACY CLEANUP ERRORS
                    }
                }
            }

            $this.IsLoaded = $true

            Return
        }

        Try {
            [String]$RawJson = [File]::ReadAllText($this.ConfigFilePath, [Encoding]::UTF8)

            If($RawJson.Trim().Length -EQ 0) {
                $this.IsLoaded = $true

                Return
            }

            [Object]$Parsed = $RawJson | ConvertFrom-Json -ErrorAction Stop

            If($null -EQ $Parsed) {
                $this.IsLoaded = $true

                Return
            }

            If($null -NE $Parsed.PSObject.Properties['Theme']) {
                $this.ApplyThemeObject($Parsed.Theme)
            }

            If($null -NE $Parsed.PSObject.Properties['Equalizer']) {
                $this.ApplyEqualizerObject($Parsed.Equalizer)
            }

            If($null -NE $Parsed.PSObject.Properties['Notifications']) {
                $this.ApplyNotificationsObject($Parsed.Notifications)
            }
        } Catch {
            $this.LastError = "Failed to parse config settings: $($_.Exception.Message)"
            $this.ResetDefaults()
        }

        $this.IsLoaded = $true
    }

    [Void]SetThemeSection(
        [String]$ActiveTheme,
        [String]$CustomThemePath
    ) {
        $this.ThemeActiveTheme     = (($null -NE $ActiveTheme) -AND ($ActiveTheme.Trim().Length -GT 0)) ? $ActiveTheme.Trim() : 'PSBoombox Default'
        $this.ThemeCustomThemePath = ($null -NE $CustomThemePath) ? $CustomThemePath.Trim() : ''
    }

    [Void]SetEqualizerSection(
        [Boolean]$Enabled,
        [String]$ActivePreset,
        [Int]$PreampDb,
        [Int[]]$Bands,
        [List[Hashtable]]$UserPresets
    ) {
        $this.EqualizerEnabled      = $Enabled
        $this.EqualizerActivePreset = (($null -NE $ActivePreset) -AND ($ActivePreset.Trim().Length -GT 0)) ? $ActivePreset.Trim() : 'Flat'
        $this.EqualizerPreampDb     = [Math]::Clamp($PreampDb, -12, 12)

        [Int[]]$NormalizedBands = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

        If($null -NE $Bands) {
            For([Int]$Idx = 0; $Idx -LT 10; $Idx++) {
                If($Idx -LT $Bands.Length) {
                    $NormalizedBands[$Idx] = [Math]::Clamp([Int]$Bands[$Idx], -12, 12)
                }
            }
        }

        $this.EqualizerBands = $NormalizedBands

        [List[Hashtable]]$CopiedUsers = [List[Hashtable]]::new()

        If($null -NE $UserPresets) {
            Foreach($PresetEntry in $UserPresets) {
                If($null -EQ $PresetEntry) {
                    Continue
                }

                [Int[]]$PresetBands = [Int[]]@(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

                If($null -NE $PresetEntry.Bands) {
                    For([Int]$BIdx = 0; $BIdx -LT 10; $BIdx++) {
                        If($BIdx -LT $PresetEntry.Bands.Length) {
                            $PresetBands[$BIdx] = [Math]::Clamp([Int]$PresetEntry.Bands[$BIdx], -12, 12)
                        }
                    }
                }

                $CopiedUsers.Add(@{
                    Name     = [String]$PresetEntry.Name
                    PreampDb = [Math]::Clamp([Int]$PresetEntry.PreampDb, -12, 12)
                    Bands    = $PresetBands
                })
            }
        }

        $this.EqualizerUserPresets = $CopiedUsers
    }

    [Void]SetBurntToastEnabled(
        [Boolean]$Enabled
    ) {
        $this.BurntToastEnabled = $Enabled
    }

    [Boolean]Save() {
        Try {
            If([Directory]::Exists($this.ConfigDirectory) -EQ $false) {
                $null = [Directory]::CreateDirectory($this.ConfigDirectory)
            }

            [OrderedDictionary]$Payload = [Ordered]@{
                Version       = [PBConfigService]::SchemaVersion
                Theme         = [Ordered]@{
                    ActiveTheme     = $this.ThemeActiveTheme
                    CustomThemePath = $this.ThemeCustomThemePath
                }
                Equalizer     = [Ordered]@{
                    Enabled      = $this.EqualizerEnabled
                    ActivePreset = $this.EqualizerActivePreset
                    PreampDb     = $this.EqualizerPreampDb
                    Bands        = @($this.EqualizerBands)
                    UserPresets  = @($this.EqualizerUserPresets)
                }
                Notifications = [Ordered]@{
                    BurntToastEnabled = $this.BurntToastEnabled
                }
            }

            [String]$JsonText        = $Payload | ConvertTo-Json -Depth 6
            [UTF8Encoding]$Utf8NoBom = [UTF8Encoding]::new($false)

            [File]::WriteAllText($this.ConfigFilePath, $JsonText, $Utf8NoBom)

            Return $true
        } Catch {
            $this.LastError = "Failed to save config settings: $($_.Exception.Message)"

            Return $false
        }
    }
}
