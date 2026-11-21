using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI THEME DEFINITION
#
# REPRESENTS A GOGH-FORMAT COLOR SCHEME PALETTE WITH 16 ANSI COLORS,
# BACKGROUND, FOREGROUND, CURSOR, AND DARK/LIGHT VARIANT METADATA.
#
###############################################################################

Class UIThemeDefinition {
    [String]$Name
    [String]$Variant
    [Boolean]$IsBuiltInDefault
    [Boolean]$IsCustom
    [String]$SourceFilePath
    [TrueColor]$Background
    [TrueColor]$Foreground
    [TrueColor]$Cursor
    [TrueColor[]]$Palette

    UIThemeDefinition() {
        $this.Name             = 'PSBoombox Default'
        $this.Variant          = 'dark'
        $this.IsBuiltInDefault = $true
        $this.IsCustom         = $false
        $this.SourceFilePath   = ''
        $this.Background       = [ColorLibrary]::ThemeBackground
        $this.Foreground       = [ColorLibrary]::TextActiveColor
        $this.Cursor           = [ColorLibrary]::BoomboxModalBorder
        $this.Palette          = [TrueColor[]]::new(16)
    }

    Static [UIThemeDefinition]FromJsonObject(
        [Object]$JsonObj,
        [String]$FallbackName,
        [String]$SourcePath,
        [Boolean]$IsCustom
    ) {
        If($null -EQ $JsonObj) {
            Throw [ArgumentException]::new('Theme JSON object cannot be null.')
        }

        [String]$BgHex = ($null -NE $JsonObj.PSObject.Properties['background']) ? [String]$JsonObj.background : ''
        [String]$FgHex = ($null -NE $JsonObj.PSObject.Properties['foreground']) ? [String]$JsonObj.foreground : ''

        If(($BgHex.Trim().Length -EQ 0) -OR ($FgHex.Trim().Length -EQ 0)) {
            Throw [ArgumentException]::new('Gogh theme JSON must define background and foreground hex colors.')
        }

        [UIThemeDefinition]$Def = [UIThemeDefinition]::new()
        $Def.Background         = [TrueColor]::FromHex($BgHex)
        $Def.Foreground         = [TrueColor]::FromHex($FgHex)

        [String]$CursorHex = ($null -NE $JsonObj.PSObject.Properties['cursor']) ? [String]$JsonObj.cursor : ''
        $Def.Cursor        = ($CursorHex.Trim().Length -GT 0) ? [TrueColor]::FromHex($CursorHex) : [TrueColor]::FromHex($FgHex)

        [TrueColor[]]$Colors = [TrueColor[]]::new(16)

        For([Int]$Idx = 1; $Idx -LE 8; $Idx++) {
            [String]$Key = "color_$($Idx.ToString('00'))"

            If($null -EQ $JsonObj.PSObject.Properties[$Key]) {
                Throw [ArgumentException]::new("Gogh theme JSON is missing required field '$($Key)'.")
            }

            $Colors[$Idx - 1] = [TrueColor]::FromHex([String]$JsonObj.$Key)
        }

        For([Int]$Idx = 9; $Idx -LE 16; $Idx++) {
            [String]$Key = "color_$($Idx.ToString('00'))"

            If(($null -NE $JsonObj.PSObject.Properties[$Key]) -AND (([String]$JsonObj.$Key).Trim().Length -GT 0)) {
                $Colors[$Idx - 1] = [TrueColor]::FromHex([String]$JsonObj.$Key)
            } Else {
                $Colors[$Idx - 1] = [TrueColor]::FromHex(([String]$JsonObj."color_$(($Idx - 8).ToString('00'))"))
            }
        }

        $Def.Palette = $Colors

        [String]$RawName = ($null -NE $JsonObj.PSObject.Properties['name']) ? ([String]$JsonObj.name).Trim() : ''

        If($RawName.Length -GT 0) {
            $Def.Name = $RawName
        } Elseif(($null -NE $FallbackName) -AND ($FallbackName.Trim().Length -GT 0)) {
            $Def.Name = $FallbackName.Trim()
        } Else {
            $Def.Name = 'Custom Theme'
        }

        [String]$RawVariant = ($null -NE $JsonObj.PSObject.Properties['variant']) ? ([String]$JsonObj.variant).Trim().ToLowerInvariant() : ''

        If(($RawVariant -EQ 'dark') -OR ($RawVariant -EQ 'light')) {
            $Def.Variant = $RawVariant
        } Else {
            [Double]$BgLum = [TrueColor]::GetRelativeLuminance($Def.Background)
            $Def.Variant   = ($BgLum -GE 0.45) ? 'light' : 'dark'
        }

        $Def.SourceFilePath   = ($null -EQ $SourcePath) ? '' : $SourcePath
        $Def.IsCustom         = $IsCustom
        $Def.IsBuiltInDefault = ($IsCustom -EQ $false) -AND ([String]::Equals($Def.Name, 'PSBoombox Default', [StringComparison]::OrdinalIgnoreCase) -EQ $true)

        Return $Def
    }
}
