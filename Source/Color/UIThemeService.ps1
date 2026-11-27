using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest





###############################################################################
#
# UI THEME SERVICE
#
# LOADS EMBEDDED GOGH JSON COLOR THEMES AND OPTIONAL CUSTOM GOGH JSON FILES,
# MAPS PALETTES INTO COLORLIBRARY SEMANTIC TOKENS IN-PLACE, AND PERSISTS THE
# ACTIVE THEME TO %APPDATA%\PSBOOMBOX\CONFIG.JSON.
#
###############################################################################

Class UIThemeService {
    Static [String]$DefaultThemeName        = 'PSBoombox Default'
    Static [String]$ConfigDirectoryOverride = ''
    Static [String]$EmbeddedThemesFilePath  = ''

    [List[UIThemeDefinition]]$AllThemes
    [List[UIThemeDefinition]]$DarkThemes
    [List[UIThemeDefinition]]$LightThemes
    [UIThemeDefinition]$ActiveTheme
    [String]$ActiveThemeName
    [String]$ActiveCustomThemePath
    [PBConfigService]$ConfigService
    [String]$ConfigDirectory
    [String]$ConfigFilePath
    [String]$LastError
    [ScriptBlock]$OnThemeChanged

    UIThemeService() {
        $this.Initialize('')
    }

    UIThemeService(
        [String]$ConfigDirectory
    ) {
        $this.Initialize($ConfigDirectory)
    }

    UIThemeService(
        [PBConfigService]$ConfigService
    ) {
        $this.InitializeWithConfig($ConfigService)
    }

    [Void]Initialize(
        [String]$ConfigDirectory
    ) {
        [String]$TargetDir = $ConfigDirectory

        If(($null -EQ $TargetDir) -OR ($TargetDir.Trim().Length -EQ 0)) {
            $TargetDir = [UIThemeService]::ConfigDirectoryOverride
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

        $this.AllThemes             = [List[UIThemeDefinition]]::new()
        $this.DarkThemes            = [List[UIThemeDefinition]]::new()
        $this.LightThemes           = [List[UIThemeDefinition]]::new()
        $this.ActiveTheme           = $null
        $this.ActiveThemeName       = [UIThemeService]::DefaultThemeName
        $this.ActiveCustomThemePath = ''
        $this.ConfigService         = $ResolvedConfig
        $this.ConfigDirectory       = $ResolvedConfig.ConfigDirectory
        $this.ConfigFilePath        = $ResolvedConfig.ConfigFilePath
        $this.LastError             = ''
        $this.OnThemeChanged        = $null

        $this.LoadEmbeddedThemes()

        [UIThemeDefinition]$DefaultDef = $this.FindBuiltInTheme([UIThemeService]::DefaultThemeName)

        If($null -NE $DefaultDef) {
            $this.ActiveTheme = $DefaultDef
        }
    }

    [Void]LoadEmbeddedThemes() {
        $this.AllThemes.Clear()
        $this.DarkThemes.Clear()
        $this.LightThemes.Clear()

        [String]$JsonPath = [UIThemeService]::EmbeddedThemesFilePath

        If(($null -EQ $JsonPath) -OR ($JsonPath.Trim().Length -EQ 0) -OR ([File]::Exists($JsonPath) -EQ $false)) {
            [String]$Candidate = [Path]::Combine($PSScriptRoot, 'Themes.json')

            If([File]::Exists($Candidate) -EQ $true) {
                $JsonPath = $Candidate
            }
        }

        If(($null -EQ $JsonPath) -OR ($JsonPath.Trim().Length -EQ 0) -OR ([File]::Exists($JsonPath) -EQ $false)) {
            $this.LastError = 'Embedded Themes.json catalog not found.'

            Return
        }

        Try {
            [String]$RawJson = [File]::ReadAllText($JsonPath, [Encoding]::UTF8)
            [Object]$Parsed  = $RawJson | ConvertFrom-Json -ErrorAction Stop

            Foreach($Item in @($Parsed)) {
                [UIThemeDefinition]$Def = [UIThemeDefinition]::FromJsonObject($Item, '', $JsonPath, $false)
                $this.AllThemes.Add($Def)

                If($Def.Variant -EQ 'light') {
                    $this.LightThemes.Add($Def)
                } Else {
                    $this.DarkThemes.Add($Def)
                }
            }
        } Catch {
            $this.LastError = "Failed to load embedded themes: $($_.Exception.Message)"
        }
    }

    [UIThemeDefinition]FindBuiltInTheme(
        [String]$Name
    ) {
        If(($null -EQ $Name) -OR ($Name.Trim().Length -EQ 0)) {
            Return $null
        }

        [String]$Trimmed = $Name.Trim()

        Foreach($ThemeDef in $this.AllThemes) {
            If([String]::Equals($ThemeDef.Name, $Trimmed, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                Return $ThemeDef
            }
        }

        Return $null
    }

    [UIThemeDefinition]LoadThemeFromFile(
        [String]$FilePath
    ) {
        $this.LastError = ''

        If(($null -EQ $FilePath) -OR ($FilePath.Trim().Length -EQ 0)) {
            $this.LastError = 'Theme file path cannot be empty.'

            Return $null
        }

        [String]$ResolvedPath = ''

        Try {
            [String]$Candidate = $FilePath.Trim()

            If([Path]::IsPathRooted($Candidate) -EQ $false) {
                $Candidate = [Path]::Combine((Get-Location).Path, $Candidate)
            }

            $ResolvedPath = [Path]::GetFullPath($Candidate)
        } Catch {
            $this.LastError = "Invalid theme path '$($FilePath)'."

            Return $null
        }

        If([File]::Exists($ResolvedPath) -EQ $false) {
            $this.LastError = "Theme file not found: '$($ResolvedPath)'."

            Return $null
        }

        Try {
            [String]$RawJson = [File]::ReadAllText($ResolvedPath, [Encoding]::UTF8)
            [Object]$Parsed  = $RawJson | ConvertFrom-Json -ErrorAction Stop

            If($null -EQ $Parsed) {
                $this.LastError = "Theme file '$($ResolvedPath)' is empty."

                Return $null
            }

            [Object]$TargetObj = $Parsed

            If($Parsed -IS [Array]) {
                If($Parsed.Length -EQ 0) {
                    $this.LastError = "Theme file '$($ResolvedPath)' contains an empty array."

                    Return $null
                }

                $TargetObj = $Parsed[0]
            }

            [String]$FallbackName = [Path]::GetFileNameWithoutExtension($ResolvedPath)

            Return [UIThemeDefinition]::FromJsonObject($TargetObj, $FallbackName, $ResolvedPath, $true)
        } Catch {
            $this.LastError = "Failed to parse theme file '$($ResolvedPath)': $($_.Exception.Message)"

            Return $null
        }
    }

    [Void]ApplyPaletteToColorLibrary(
        [UIThemeDefinition]$Theme
    ) {
        If($null -EQ $Theme) {
            Return
        }

        If($Theme.IsBuiltInDefault -EQ $true) {
            [ColorLibrary]::ResetSemanticDefaults()

            Return
        }

        [TrueColor]$Bg           = $Theme.Background
        [TrueColor]$Fg           = $Theme.Foreground
        [TrueColor]$Dim          = [TrueColor]::Blend($Bg, $Fg, 0.38)
        [TrueColor]$Muted        = [TrueColor]::Blend($Bg, $Fg, 0.58)
        [TrueColor]$BorderActive = [TrueColor]::Blend($Bg, $Fg, 0.80)

        [TrueColor]$Red     = [TrueColor]::EnsureContrast($Theme.Palette[1], $Bg, $Fg, 3.0)
        [TrueColor]$Green   = [TrueColor]::EnsureContrast($Theme.Palette[2], $Bg, $Fg, 3.0)
        [TrueColor]$Yellow  = [TrueColor]::EnsureContrast($Theme.Palette[3], $Bg, $Fg, 3.0)
        [TrueColor]$Blue    = [TrueColor]::EnsureContrast($Theme.Palette[4], $Bg, $Fg, 3.0)
        [TrueColor]$Magenta = [TrueColor]::EnsureContrast($Theme.Palette[5], $Bg, $Fg, 3.0)
        [TrueColor]$Cyan    = [TrueColor]::EnsureContrast($Theme.Palette[6], $Bg, $Fg, 3.0)
        [TrueColor]$Orange  = [TrueColor]::EnsureContrast(([TrueColor]::Blend($Red, $Yellow, 0.50)), $Bg, $Fg, 3.0)
        [TrueColor]$Mint    = [TrueColor]::EnsureContrast(([TrueColor]::Blend($Green, $Cyan, 0.50)), $Bg, $Fg, 3.0)

        [ColorLibrary]::ThemeBackground.CopyFrom($Bg)
        [ColorLibrary]::WindowBorderActiveColor.CopyFrom($BorderActive)
        [ColorLibrary]::WindowBorderInactiveColor.CopyFrom($Dim)
        [ColorLibrary]::TextActiveColor.CopyFrom($Fg)
        [ColorLibrary]::TextInactiveColor.CopyFrom($Dim)
        [ColorLibrary]::TextColor.CopyFrom($Fg)

        [ColorLibrary]::UICheckboxHasFocus.CopyFrom($Mint)
        [ColorLibrary]::UICheckboxChecked.CopyFrom($Green)
        [ColorLibrary]::UICheckboxInactiveColor.CopyFrom($Dim)
        [ColorLibrary]::UICheckboxActive.CopyFrom($Fg)

        [ColorLibrary]::UIChevronActive.CopyFrom($Fg)
        [ColorLibrary]::UIChevronInactive.CopyFrom($Dim)
        [ColorLibrary]::UIChevronHasFocus.CopyFrom($Mint)

        [ColorLibrary]::UILabelActive.CopyFrom($Fg)
        [ColorLibrary]::UILabelInactive.CopyFrom($Dim)

        [ColorLibrary]::UITextInputActive.CopyFrom($Fg)
        [ColorLibrary]::UITextInputInactive.CopyFrom($Dim)
        [ColorLibrary]::UITextInputHasFocus.CopyFrom($Mint)
        [ColorLibrary]::UITextInputPlaceholder.CopyFrom($Muted)
        [ColorLibrary]::UITextInputCursor.CopyFrom($Yellow)

        [ColorLibrary]::UIButtonActive.CopyFrom($Fg)
        [ColorLibrary]::UIButtonInactive.CopyFrom($Dim)
        [ColorLibrary]::UIButtonHasFocus.CopyFrom($Mint)
        [ColorLibrary]::UIButtonBracketActive.CopyFrom($Cyan)
        [ColorLibrary]::UIButtonBracketHasFocus.CopyFrom($Yellow)

        [ColorLibrary]::UIRadioButtonActive.CopyFrom($Fg)
        [ColorLibrary]::UIRadioButtonInactive.CopyFrom($Dim)
        [ColorLibrary]::UIRadioButtonHasFocus.CopyFrom($Mint)
        [ColorLibrary]::UIRadioButtonSelected.CopyFrom($Green)

        [ColorLibrary]::UIListItemActive.CopyFrom($Fg)
        [ColorLibrary]::UIListItemInactive.CopyFrom($Dim)
        [ColorLibrary]::UIListItemSelected.CopyFrom($Yellow)
        [ColorLibrary]::UIListItemHasFocus.CopyFrom($Mint)

        [ColorLibrary]::UINumberSpinnerActive.CopyFrom($Fg)
        [ColorLibrary]::UINumberSpinnerInactive.CopyFrom($Dim)
        [ColorLibrary]::UINumberSpinnerHasFocus.CopyFrom($Mint)
        [ColorLibrary]::UINumberSpinnerValueModified.CopyFrom($Green)

        [ColorLibrary]::UIProgressBarFilled.CopyFrom($Green)
        [ColorLibrary]::UIProgressBarEmpty.CopyFrom($Dim)
        [ColorLibrary]::UIProgressBarInactive.CopyFrom($Dim)
        [ColorLibrary]::UIProgressBarBorder.CopyFrom($Fg)
        [ColorLibrary]::UIProgressBarText.CopyFrom($Fg)

        [ColorLibrary]::UITabActive.CopyFrom($Fg)
        [ColorLibrary]::UITabInactive.CopyFrom($Dim)
        [ColorLibrary]::UITabSelected.CopyFrom($Yellow)
        [ColorLibrary]::UITabHasFocus.CopyFrom($Mint)
        [ColorLibrary]::UITabBorderActive.CopyFrom($BorderActive)
        [ColorLibrary]::UITabBorderSelected.CopyFrom($Cyan)
        [ColorLibrary]::UITabBorderHasFocus.CopyFrom($Yellow)

        [ColorLibrary]::BoomboxBorderFocused.CopyFrom($Cyan)
        [ColorLibrary]::BoomboxStatusPlaying.CopyFrom($Green)
        [ColorLibrary]::BoomboxStatusPaused.CopyFrom($Yellow)
        [ColorLibrary]::BoomboxStatusStopped.CopyFrom($Muted)
        [ColorLibrary]::BoomboxStatusError.CopyFrom($Red)
        [ColorLibrary]::BoomboxDirEntry.CopyFrom($Cyan)
        [ColorLibrary]::BoomboxParentDirEntry.CopyFrom($Orange)
        [ColorLibrary]::BoomboxPlaylistFileEntry.CopyFrom($Magenta)
        [ColorLibrary]::BoomboxMediaFileEntry.CopyFrom($Fg)
        [ColorLibrary]::BoomboxNowPlayingEntry.CopyFrom($Green)
        [ColorLibrary]::BoomboxVolumeSafe.CopyFrom($Green)
        [ColorLibrary]::BoomboxVolumeHigh.CopyFrom($Yellow)
        [ColorLibrary]::BoomboxVolumeMuted.CopyFrom($Red)
        [ColorLibrary]::BoomboxScrubberFilled.CopyFrom($Cyan)
        [ColorLibrary]::BoomboxModalBorder.CopyFrom($Yellow)
        [ColorLibrary]::BoomboxFooterHint.CopyFrom($Muted)
        [ColorLibrary]::BoomboxFooterStatus.CopyFrom($Cyan)
        [ColorLibrary]::BoomboxFooterError.CopyFrom($Red)
        [ColorLibrary]::BoomboxSpinnerActive.CopyFrom($Green)

        [ColorLibrary]::BoomboxEqActive.CopyFrom($Mint)
        [ColorLibrary]::BoomboxEqInactive.CopyFrom($Muted)
        [ColorLibrary]::BoomboxEqBypassed.CopyFrom($Yellow)
        [ColorLibrary]::BoomboxEqSliderPos.CopyFrom($Cyan)
        [ColorLibrary]::BoomboxEqSliderNeg.CopyFrom($Orange)
        [ColorLibrary]::BoomboxEqSliderZero.CopyFrom($Fg)
        [ColorLibrary]::BoomboxEqSliderTrack.CopyFrom($Dim)
        [ColorLibrary]::BoomboxEqSliderFocused.CopyFrom($Yellow)

        [ColorLibrary]::BoomboxVizTrackLabel.CopyFrom($Fg)
        [ColorLibrary]::BoomboxVizHint.CopyFrom($Muted)
        [ColorLibrary]::BoomboxVizPeakCap.CopyFrom($Fg)
        [ColorLibrary]::BoomboxVizAxis.CopyFrom($Dim)

        [ColorLibrary]::BoomboxWarningBorder.CopyFrom($Yellow)
        [ColorLibrary]::BoomboxWarningTitle.CopyFrom($Yellow)
        [ColorLibrary]::BoomboxWarningText.CopyFrom($Fg)
        [ColorLibrary]::BoomboxWarningDimOk.CopyFrom($Green)
        [ColorLibrary]::BoomboxWarningDimBad.CopyFrom($Red)

        [ColorLibrary]::BoomboxVizSpectrumGradient[0].CopyFrom($Blue)
        [ColorLibrary]::BoomboxVizSpectrumGradient[1].CopyFrom($Cyan)
        [ColorLibrary]::BoomboxVizSpectrumGradient[2].CopyFrom($Mint)
        [ColorLibrary]::BoomboxVizSpectrumGradient[3].CopyFrom($Green)
        [ColorLibrary]::BoomboxVizSpectrumGradient[4].CopyFrom(([TrueColor]::Blend($Green, $Yellow, 0.50)))
        [ColorLibrary]::BoomboxVizSpectrumGradient[5].CopyFrom($Yellow)
        [ColorLibrary]::BoomboxVizSpectrumGradient[6].CopyFrom($Orange)
        [ColorLibrary]::BoomboxVizSpectrumGradient[7].CopyFrom($Red)

        [ColorLibrary]::BoomboxVizMirrorGradient[0].CopyFrom($Blue)
        [ColorLibrary]::BoomboxVizMirrorGradient[1].CopyFrom($Cyan)
        [ColorLibrary]::BoomboxVizMirrorGradient[2].CopyFrom($Mint)
        [ColorLibrary]::BoomboxVizMirrorGradient[3].CopyFrom(([TrueColor]::Blend($Blue, $Magenta, 0.45)))
        [ColorLibrary]::BoomboxVizMirrorGradient[4].CopyFrom($Magenta)
        [ColorLibrary]::BoomboxVizMirrorGradient[5].CopyFrom(([TrueColor]::Blend($Magenta, $Red, 0.40)))
        [ColorLibrary]::BoomboxVizMirrorGradient[6].CopyFrom(([TrueColor]::Blend($Magenta, $Red, 0.70)))
        [ColorLibrary]::BoomboxVizMirrorGradient[7].CopyFrom($Red)

        [ColorLibrary]::BoomboxVizScopeGradient[0].CopyFrom($Cyan)
        [ColorLibrary]::BoomboxVizScopeGradient[1].CopyFrom($Mint)
        [ColorLibrary]::BoomboxVizScopeGradient[2].CopyFrom($Green)
        [ColorLibrary]::BoomboxVizScopeGradient[3].CopyFrom($Yellow)

        [ColorLibrary]::BoomboxVizRadialGradient[0].CopyFrom(([TrueColor]::Blend($Bg, $Blue, 0.65)))
        [ColorLibrary]::BoomboxVizRadialGradient[1].CopyFrom($Blue)
        [ColorLibrary]::BoomboxVizRadialGradient[2].CopyFrom($Cyan)
        [ColorLibrary]::BoomboxVizRadialGradient[3].CopyFrom($Mint)
        [ColorLibrary]::BoomboxVizRadialGradient[4].CopyFrom($Yellow)
        [ColorLibrary]::BoomboxVizRadialGradient[5].CopyFrom($Orange)
        [ColorLibrary]::BoomboxVizRadialGradient[6].CopyFrom($Magenta)
        [ColorLibrary]::BoomboxVizRadialGradient[7].CopyFrom($Fg)

        [ColorLibrary]::BoomboxVizWaterfallGradient[0].CopyFrom($Bg)
        [ColorLibrary]::BoomboxVizWaterfallGradient[1].CopyFrom(([TrueColor]::Blend($Bg, $Blue, 0.35)))
        [ColorLibrary]::BoomboxVizWaterfallGradient[2].CopyFrom(([TrueColor]::Blend($Bg, $Blue, 0.68)))
        [ColorLibrary]::BoomboxVizWaterfallGradient[3].CopyFrom($Blue)
        [ColorLibrary]::BoomboxVizWaterfallGradient[4].CopyFrom($Cyan)
        [ColorLibrary]::BoomboxVizWaterfallGradient[5].CopyFrom($Mint)
        [ColorLibrary]::BoomboxVizWaterfallGradient[6].CopyFrom($Yellow)
        [ColorLibrary]::BoomboxVizWaterfallGradient[7].CopyFrom($Orange)
        [ColorLibrary]::BoomboxVizWaterfallGradient[8].CopyFrom($Red)
    }

    [Void]ApplyTheme(
        [UIThemeDefinition]$Theme,
        [Boolean]$Persist
    ) {
        If($null -EQ $Theme) {
            Return
        }

        $this.ApplyPaletteToColorLibrary($Theme)

        $this.ActiveTheme           = $Theme
        $this.ActiveThemeName       = $Theme.Name
        $this.ActiveCustomThemePath = ($Theme.IsCustom -EQ $true) ? $Theme.SourceFilePath : ''

        If($Persist -EQ $true) {
            $null = $this.Save()
        }

        If($null -NE $this.OnThemeChanged) {
            $this.OnThemeChanged.Invoke($this)
        }
    }

    [Boolean]ApplyThemeByNameOrPath(
        [String]$NameOrPath,
        [Boolean]$Persist
    ) {
        $this.LastError = ''

        If(($null -EQ $NameOrPath) -OR ($NameOrPath.Trim().Length -EQ 0)) {
            $this.LastError = 'Theme name or path cannot be empty.'

            Return $false
        }

        [String]$Trimmed                  = $NameOrPath.Trim()
        [UIThemeDefinition]$BuiltInMatch = $this.FindBuiltInTheme($Trimmed)

        If($null -NE $BuiltInMatch) {
            $this.ApplyTheme($BuiltInMatch, $Persist)

            Return $true
        }

        [String]$ResolvedFile = $Trimmed

        If([Path]::IsPathRooted($ResolvedFile) -EQ $false) {
            $ResolvedFile = [Path]::Combine((Get-Location).Path, $ResolvedFile)
        }

        If(([File]::Exists($ResolvedFile) -EQ $true) -OR ($Trimmed.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase) -EQ $true)) {
            [UIThemeDefinition]$CustomDef = $this.LoadThemeFromFile($Trimmed)

            If($null -NE $CustomDef) {
                $this.ApplyTheme($CustomDef, $Persist)

                Return $true
            }

            Return $false
        }

        $this.LastError = "Theme '$($Trimmed)' not found. Falling back to '$($this.ActiveThemeName)'."

        Return $false
    }

    [Void]Load() {
        $this.LastError = ''

        [UIThemeDefinition]$DefaultDef = $this.FindBuiltInTheme([UIThemeService]::DefaultThemeName)

        If($this.ConfigService.IsLoaded -EQ $false) {
            $this.ConfigService.Load()
        }

        If($this.ConfigService.LastError.Length -GT 0) {
            $this.LastError = $this.ConfigService.LastError
        }

        [String]$SavedCustomPath = $this.ConfigService.ThemeCustomThemePath
        [String]$SavedThemeName  = $this.ConfigService.ThemeActiveTheme

        If(($SavedCustomPath.Length -GT 0) -AND ([File]::Exists($SavedCustomPath) -EQ $true)) {
            [UIThemeDefinition]$CustomDef = $this.LoadThemeFromFile($SavedCustomPath)

            If($null -NE $CustomDef) {
                $this.ApplyTheme($CustomDef, $false)

                Return
            }
        }

        If($SavedThemeName.Length -GT 0) {
            [UIThemeDefinition]$BuiltInDef = $this.FindBuiltInTheme($SavedThemeName)

            If($null -NE $BuiltInDef) {
                $this.ApplyTheme($BuiltInDef, $false)

                Return
            }
        }

        If($null -NE $DefaultDef) {
            $this.ApplyTheme($DefaultDef, $false)
        }
    }

    [Boolean]Save() {
        $this.ConfigService.SetThemeSection($this.ActiveThemeName, $this.ActiveCustomThemePath)

        [Boolean]$Saved = $this.ConfigService.Save()

        If($Saved -EQ $false) {
            $this.LastError = $this.ConfigService.LastError
        }

        Return $Saved
    }
}
