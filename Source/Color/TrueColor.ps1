using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# TRUE COLOR SUPPORT
#
###############################################################################

Class TrueColor {
    [ColorChannel]$Red
    [ColorChannel]$Green
    [ColorChannel]$Blue

    TrueColor() {
        $this.Red   = [ColorChannel]::new()
        $this.Green = [ColorChannel]::new()
        $this.Blue  = [ColorChannel]::new()
    }

    TrueColor(
        [ColorChannel]$Red,
        [ColorChannel]$Green,
        [ColorChannel]$Blue
    ) {
        If(($null -EQ $Red) -OR
            ($null -EQ $Green) -OR
            ($null -EQ $Blue)) {
            $this.Red   = [ColorChannel]::new()
            $this.Green = [ColorChannel]::new()
            $this.Blue  = [ColorChannel]::new()
        } Else {
            $this.Red   = $Red
            $this.Green = $Green
            $this.Blue  = $Blue
        }
    }

    TrueColor(
        [Int]$Hex
    ) {
        $this.Red   = [ColorChannel]::new(($Hex -SHR 16) -BAND 0xFF)
        $this.Green = [ColorChannel]::new(($Hex -SHR 8) -BAND 0xFF)
        $this.Blue  = [ColorChannel]::new($Hex -BAND 0xFF)
    }

    TrueColor(
        [TrueColor]$Source
    ) {
        If($null -EQ $Source) {
            $this.Red   = [ColorChannel]::new()
            $this.Green = [ColorChannel]::new()
            $this.Blue  = [ColorChannel]::new()
        } Else {
            $this.Red   = [ColorChannel]::new($Source.Red.Value)
            $this.Green = [ColorChannel]::new($Source.Green.Value)
            $this.Blue  = [ColorChannel]::new($Source.Blue.Value)
        }
    }

    [Void]CopyFrom(
        [TrueColor]$Source
    ) {
        If($null -EQ $Source) {
            Return
        }

        $this.Red.SetValue($Source.Red.Value)
        $this.Green.SetValue($Source.Green.Value)
        $this.Blue.SetValue($Source.Blue.Value)
    }

    [String]ToHexString() {
        Return "#$($this.Red.Value.ToString('X2'))$($this.Green.Value.ToString('X2'))$($this.Blue.Value.ToString('X2'))"
    }

    Static [TrueColor]FromHex(
        [String]$HexString
    ) {
        If($null -EQ $HexString) {
            Throw [ArgumentException]::new('Hex color string cannot be null.')
        }

        [String]$Cleaned = $HexString.Trim()

        If($Cleaned.StartsWith('#') -EQ $true) {
            $Cleaned = $Cleaned.Substring(1)
        } Elseif($Cleaned.StartsWith('0x', [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
            $Cleaned = $Cleaned.Substring(2)
        }

        If(($Cleaned -MATCH '^[0-9A-Fa-f]{6}$') -EQ $false) {
            Throw [ArgumentException]::new("Invalid 24-bit hex color '$($HexString)'.")
        }

        Return [TrueColor]::new([Convert]::ToInt32($Cleaned, 16))
    }

    Static [TrueColor]Blend(
        [TrueColor]$FromColor,
        [TrueColor]$ToColor,
        [Double]$Factor
    ) {
        If(($null -EQ $FromColor) -OR ($null -EQ $ToColor)) {
            Return [TrueColor]::new()
        }

        [Double]$T = [Math]::Clamp($Factor, 0.0, 1.0)
        [Int]$R    = [Int][Math]::Round($FromColor.Red.Value + (($ToColor.Red.Value - $FromColor.Red.Value) * $T))
        [Int]$G    = [Int][Math]::Round($FromColor.Green.Value + (($ToColor.Green.Value - $FromColor.Green.Value) * $T))
        [Int]$B    = [Int][Math]::Round($FromColor.Blue.Value + (($ToColor.Blue.Value - $FromColor.Blue.Value) * $T))

        Return [TrueColor]::new(
            [ColorChannel]::new($R),
            [ColorChannel]::new($G),
            [ColorChannel]::new($B)
        )
    }

    Static [Double]GetRelativeLuminance(
        [TrueColor]$Color
    ) {
        If($null -EQ $Color) {
            Return 0.0
        }

        [Double]$SR   = [Double]$Color.Red.Value / 255.0
        [Double]$SG   = [Double]$Color.Green.Value / 255.0
        [Double]$SB   = [Double]$Color.Blue.Value / 255.0
        [Double]$LinR = ($SR -LE 0.03928) ? ($SR / 12.92) : [Math]::Pow((($SR + 0.055) / 1.055), 2.4)
        [Double]$LinG = ($SG -LE 0.03928) ? ($SG / 12.92) : [Math]::Pow((($SG + 0.055) / 1.055), 2.4)
        [Double]$LinB = ($SB -LE 0.03928) ? ($SB / 12.92) : [Math]::Pow((($SB + 0.055) / 1.055), 2.4)

        Return (0.2126 * $LinR) + (0.7152 * $LinG) + (0.0722 * $LinB)
    }

    Static [Double]GetContrastRatio(
        [TrueColor]$ColorA,
        [TrueColor]$ColorB
    ) {
        [Double]$LumA = [TrueColor]::GetRelativeLuminance($ColorA)
        [Double]$LumB = [TrueColor]::GetRelativeLuminance($ColorB)
        [Double]$MaxL = [Math]::Max($LumA, $LumB)
        [Double]$MinL = [Math]::Min($LumA, $LumB)

        Return (($MaxL + 0.05) / ($MinL + 0.05))
    }

    Static [TrueColor]EnsureContrast(
        [TrueColor]$Foreground,
        [TrueColor]$Background,
        [TrueColor]$Anchor,
        [Double]$MinRatio
    ) {
        If($null -EQ $Foreground) {
            Return [TrueColor]::new($Anchor)
        }

        If(($null -EQ $Background) -OR ($null -EQ $Anchor)) {
            Return [TrueColor]::new($Foreground)
        }

        If([TrueColor]::GetContrastRatio($Foreground, $Background) -GE $MinRatio) {
            Return [TrueColor]::new($Foreground)
        }

        For([Int]$Step = 1; $Step -LE 10; $Step++) {
            [Double]$Factor       = [Double]$Step * 0.1
            [TrueColor]$Candidate = [TrueColor]::Blend($Foreground, $Anchor, $Factor)

            If([TrueColor]::GetContrastRatio($Candidate, $Background) -GE $MinRatio) {
                Return $Candidate
            }
        }

        Return [TrueColor]::new($Anchor)
    }
}

Class ColorLibrary {
    Static [TrueColor]$IndianRed                    = [TrueColor]::new(0xCD5C5C)
    Static [TrueColor]$Crimson                      = [TrueColor]::new(0xDC143C)
    Static [TrueColor]$LightCoral                   = [TrueColor]::new(0xF08080)
    Static [TrueColor]$Red                          = [TrueColor]::new(0xFF0000)
    Static [TrueColor]$Salmon                       = [TrueColor]::new(0xFA8072)
    Static [TrueColor]$FireBrick                    = [TrueColor]::new(0xB22222)
    Static [TrueColor]$DarkSalmon                   = [TrueColor]::new(0xE9967A)
    Static [TrueColor]$DarkRed                      = [TrueColor]::new(0x8B0000)
    Static [TrueColor]$Pink                         = [TrueColor]::new(0xFFC0CB)
    Static [TrueColor]$MediumVioletRed              = [TrueColor]::new(0xC71585)
    Static [TrueColor]$LightPink                    = [TrueColor]::new(0xFFB6C1)
    Static [TrueColor]$PaleVioletRed                = [TrueColor]::new(0xDB7093)
    Static [TrueColor]$HotPink                      = [TrueColor]::new(0xFF69B4)
    Static [TrueColor]$DeepPink                     = [TrueColor]::new(0xFF1493)
    Static [TrueColor]$LightSalmon                  = [TrueColor]::new(0xFFA07A)
    Static [TrueColor]$DarkOrange                   = [TrueColor]::new(0xFF8C00)
    Static [TrueColor]$Coral                        = [TrueColor]::new(0xFF7F50)
    Static [TrueColor]$Orange                       = [TrueColor]::new(0xFFA500)
    Static [TrueColor]$Tomato                       = [TrueColor]::new(0xFF6347)
    Static [TrueColor]$Gold                         = [TrueColor]::new(0xFFD700)
    Static [TrueColor]$OrangeRed                    = [TrueColor]::new(0xFF4500)
    Static [TrueColor]$Yellow                       = [TrueColor]::new(0xFFFF00)
    Static [TrueColor]$LightYellow                  = [TrueColor]::new(0xFFFFE0)
    Static [TrueColor]$PapayaWhip                   = [TrueColor]::new(0xFFEFD5)
    Static [TrueColor]$LemonChiffon                 = [TrueColor]::new(0xFFFACD)
    Static [TrueColor]$Moccasin                     = [TrueColor]::new(0xFFE4B5)
    Static [TrueColor]$LightGoldenrodYellow         = [TrueColor]::new(0xFAFAD2)
    Static [TrueColor]$PeachPuff                    = [TrueColor]::new(0xFFDAB9)
    Static [TrueColor]$PaleGoldenrod                = [TrueColor]::new(0xEEE8AA)
    Static [TrueColor]$Khaki                        = [TrueColor]::new(0xF0E68C)
    Static [TrueColor]$DarkKhaki                    = [TrueColor]::new(0xBDB76B)
    Static [TrueColor]$Lavender                     = [TrueColor]::new(0xE6E6FA)
    Static [TrueColor]$MediumOrchid                 = [TrueColor]::new(0xBA55D3)
    Static [TrueColor]$Thistle                      = [TrueColor]::new(0xD8BFD8)
    Static [TrueColor]$Plum                         = [TrueColor]::new(0xDDA0DD)
    Static [TrueColor]$DarkViolet                   = [TrueColor]::new(0x9400D3)
    Static [TrueColor]$Violet                       = [TrueColor]::new(0xEE82EE)
    Static [TrueColor]$BlueViolet                   = [TrueColor]::new(0x8A2BE2)
    Static [TrueColor]$Orchid                       = [TrueColor]::new(0xDA70D6)
    Static [TrueColor]$MediumPurple                 = [TrueColor]::new(0x9370DB)
    Static [TrueColor]$Magenta                      = [TrueColor]::new(0xFF00FF)
    Static [TrueColor]$Fuchsia                      = [TrueColor]::new(0xFF00FF)
    Static [TrueColor]$SlateBlue                    = [TrueColor]::new(0x6A5ACD)
    Static [TrueColor]$MediumSlateBlue              = [TrueColor]::new(0x7B68EE)
    Static [TrueColor]$DarkSlateBlue                = [TrueColor]::new(0x483D8B)
    Static [TrueColor]$Purple                       = [TrueColor]::new(0x800080)
    Static [TrueColor]$Indigo                       = [TrueColor]::new(0x4B0082)
    Static [TrueColor]$GreenYellow                  = [TrueColor]::new(0xADFF2F)
    Static [TrueColor]$SeaGreen                     = [TrueColor]::new(0x2E8B57)
    Static [TrueColor]$Chartreuse                   = [TrueColor]::new(0x7FFF00)
    Static [TrueColor]$ForestGreen                  = [TrueColor]::new(0x228B22)
    Static [TrueColor]$LawnGreen                    = [TrueColor]::new(0x7CFC00)
    Static [TrueColor]$Green                        = [TrueColor]::new(0x008000)
    Static [TrueColor]$Lime                         = [TrueColor]::new(0x00FF00)
    Static [TrueColor]$DarkGreen                    = [TrueColor]::new(0x006400)
    Static [TrueColor]$LimeGreen                    = [TrueColor]::new(0x32CD32)
    Static [TrueColor]$YellowGreen                  = [TrueColor]::new(0x9ACD32)
    Static [TrueColor]$PaleGreen                    = [TrueColor]::new(0x98FB98)
    Static [TrueColor]$OliveDrab                    = [TrueColor]::new(0x6B8E23)
    Static [TrueColor]$LightGreen                   = [TrueColor]::new(0x90EE90)
    Static [TrueColor]$Olive                        = [TrueColor]::new(0x808000)
    Static [TrueColor]$MediumSpringGreen            = [TrueColor]::new(0x00FA9A)
    Static [TrueColor]$DarkOliveGreen               = [TrueColor]::new(0x556B2F)
    Static [TrueColor]$SpringGreen                  = [TrueColor]::new(0x00FF7F)
    Static [TrueColor]$MediumAquamarine             = [TrueColor]::new(0x66CDAA)
    Static [TrueColor]$MediumSeaGreen               = [TrueColor]::new(0x3CB371)
    Static [TrueColor]$DarkSeaGreen                 = [TrueColor]::new(0x8FBC8F)
    Static [TrueColor]$LightSeaGreen                = [TrueColor]::new(0x20B2AA)
    Static [TrueColor]$DarkCyan                     = [TrueColor]::new(0x008B8B)
    Static [TrueColor]$Teal                         = [TrueColor]::new(0x008080)
    Static [TrueColor]$Aqua                         = [TrueColor]::new(0x00FFFF)
    Static [TrueColor]$Cyan                         = [TrueColor]::new(0x00FFFF)
    Static [TrueColor]$SkyBlue                      = [TrueColor]::new(0x87CEEB)
    Static [TrueColor]$LightCyan                    = [TrueColor]::new(0xE0FFFF)
    Static [TrueColor]$LightSkyBlue                 = [TrueColor]::new(0x87CEFA)
    Static [TrueColor]$PaleTurquoise                = [TrueColor]::new(0xAFEEEE)
    Static [TrueColor]$DeepSkyBlue                  = [TrueColor]::new(0x00BFFF)
    Static [TrueColor]$Aquamarine                   = [TrueColor]::new(0x7FFFD4)
    Static [TrueColor]$DodgerBlue                   = [TrueColor]::new(0x1E90FF)
    Static [TrueColor]$Turquoise                    = [TrueColor]::new(0x40E0D0)
    Static [TrueColor]$CornflowerBlue               = [TrueColor]::new(0x6495ED)
    Static [TrueColor]$MediumTurquoise              = [TrueColor]::new(0x48D1CC)
    Static [TrueColor]$RoyalBlue                    = [TrueColor]::new(0x4169E1)
    Static [TrueColor]$DarkTurquoise                = [TrueColor]::new(0x00CED1)
    Static [TrueColor]$Blue                         = [TrueColor]::new(0x0000FF)
    Static [TrueColor]$CadetBlue                    = [TrueColor]::new(0x5F9EA0)
    Static [TrueColor]$MediumBlue                   = [TrueColor]::new(0x0000CD)
    Static [TrueColor]$SteelBlue                    = [TrueColor]::new(0x4682B4)
    Static [TrueColor]$DarkBlue                     = [TrueColor]::new(0x00008B)
    Static [TrueColor]$LightSteelBlue               = [TrueColor]::new(0xB0C4DE)
    Static [TrueColor]$Navy                         = [TrueColor]::new(0x000080)
    Static [TrueColor]$PowderBlue                   = [TrueColor]::new(0xB0E0E6)
    Static [TrueColor]$MidnightBlue                 = [TrueColor]::new(0x191970)
    Static [TrueColor]$LightBlue                    = [TrueColor]::new(0xADD8E6)
    Static [TrueColor]$Cornsilk                     = [TrueColor]::new(0xFFF8DC)
    Static [TrueColor]$RosyBrown                    = [TrueColor]::new(0xBC8F8F)
    Static [TrueColor]$BlanchedAlmond               = [TrueColor]::new(0xFFEBCD)
    Static [TrueColor]$SandyBrown                   = [TrueColor]::new(0xF4A460)
    Static [TrueColor]$Bisque                       = [TrueColor]::new(0xFFE4C4)
    Static [TrueColor]$Goldenrod                    = [TrueColor]::new(0xDAA520)
    Static [TrueColor]$NavajoWhite                  = [TrueColor]::new(0xFFDEAD)
    Static [TrueColor]$DarkGoldenrod                = [TrueColor]::new(0xB8860B)
    Static [TrueColor]$Wheat                        = [TrueColor]::new(0xF5DEB3)
    Static [TrueColor]$Peru                         = [TrueColor]::new(0xCD853F)
    Static [TrueColor]$BurlyWood                    = [TrueColor]::new(0xDEB887)
    Static [TrueColor]$Chocolate                    = [TrueColor]::new(0xD2691E)
    Static [TrueColor]$Tan                          = [TrueColor]::new(0xD2B48C)
    Static [TrueColor]$SaddleBrown                  = [TrueColor]::new(0x8B4513)
    Static [TrueColor]$Sienna                       = [TrueColor]::new(0xA0522D)
    Static [TrueColor]$Maroon                       = [TrueColor]::new(0x800000)
    Static [TrueColor]$Brown                        = [TrueColor]::new(0xA52A2A)
    Static [TrueColor]$White                        = [TrueColor]::new(0xFFFFFF)
    Static [TrueColor]$Gainsboro                    = [TrueColor]::new(0xDCDCDC)
    Static [TrueColor]$Snow                         = [TrueColor]::new(0xFFFAFA)
    Static [TrueColor]$LightGrey                    = [TrueColor]::new(0xD3D3D3)
    Static [TrueColor]$Honeydew                     = [TrueColor]::new(0xF0FFF0)
    Static [TrueColor]$Silver                       = [TrueColor]::new(0xC0C0C0)
    Static [TrueColor]$MintCream                    = [TrueColor]::new(0xF5FFFA)
    Static [TrueColor]$DarkGrey                     = [TrueColor]::new(0xA9A9A9)
    Static [TrueColor]$Azure                        = [TrueColor]::new(0xF0FFFF)
    Static [TrueColor]$Grey                         = [TrueColor]::new(0x808080)
    Static [TrueColor]$AliceBlue                    = [TrueColor]::new(0xF0F8FF)
    Static [TrueColor]$DimGrey                      = [TrueColor]::new(0x696969)
    Static [TrueColor]$GhostWhite                   = [TrueColor]::new(0xF8F8FF)
    Static [TrueColor]$LightSlateGrey               = [TrueColor]::new(0x778899)
    Static [TrueColor]$WhiteSmoke                   = [TrueColor]::new(0xF5F5F5)
    Static [TrueColor]$SlateGrey                    = [TrueColor]::new(0x708090)
    Static [TrueColor]$Seashell                     = [TrueColor]::new(0xFFF5EE)
    Static [TrueColor]$DarkSlateGrey                = [TrueColor]::new(0x2F4F4F)
    Static [TrueColor]$Beige                        = [TrueColor]::new(0xF5F5DC)
    Static [TrueColor]$Black                        = [TrueColor]::new(0x000000)
    Static [TrueColor]$OldLace                      = [TrueColor]::new(0xFDF5E6)
    Static [TrueColor]$FloralWhite                  = [TrueColor]::new(0xFFFAF0)
    Static [TrueColor]$Ivory                        = [TrueColor]::new(0xFFFFF0)
    Static [TrueColor]$AntiqueWhite                 = [TrueColor]::new(0xFAEBD7)
    Static [TrueColor]$Linen                        = [TrueColor]::new(0xFAF0E6)
    Static [TrueColor]$LavenderBlush                = [TrueColor]::new(0xFFF0F5)
    Static [TrueColor]$AppleRedLight                = [TrueColor]::new(0xFF383C)
    Static [TrueColor]$AppleRedDark                 = [TrueColor]::new(0xFF4245)
    Static [TrueColor]$AppleOrangeLight             = [TrueColor]::new(0xFF8D28)
    Static [TrueColor]$AppleOrangeDark              = [TrueColor]::new(0xFF9230)
    Static [TrueColor]$AppleYellowLight             = [TrueColor]::new(0xFFCC00)
    Static [TrueColor]$AppleYellowDark              = [TrueColor]::new(0xFFD600)
    Static [TrueColor]$AppleGreenLight              = [TrueColor]::new(0x34C759)
    Static [TrueColor]$AppleGreenDark               = [TrueColor]::new(0x30D158)
    Static [TrueColor]$AppleMintLight               = [TrueColor]::new(0x00C8B3)
    Static [TrueColor]$AppleMintDark                = [TrueColor]::new(0x00DAC3)
    Static [TrueColor]$AppleTealLight               = [TrueColor]::new(0x00C3D0)
    Static [TrueColor]$AppleTealDark                = [TrueColor]::new(0x00D2E0)
    Static [TrueColor]$AppleCyanLight               = [TrueColor]::new(0x00C0E8)
    Static [TrueColor]$AppleCyanDark                = [TrueColor]::new(0x3CD3FE)
    Static [TrueColor]$AppleBlueLight               = [TrueColor]::new(0x0088FF)
    Static [TrueColor]$AppleBlueDark                = [TrueColor]::new(0x0091FF)
    Static [TrueColor]$AppleIndigoLight             = [TrueColor]::new(0x6155F5)
    Static [TrueColor]$AppleIndigoDark              = [TrueColor]::new(0x6D7CFF)
    Static [TrueColor]$ApplePurpleLight             = [TrueColor]::new(0xCB30E0)
    Static [TrueColor]$ApplePurpleDark              = [TrueColor]::new(0xDB34F2)
    Static [TrueColor]$ApplePinkLight               = [TrueColor]::new(0xFF2D55)
    Static [TrueColor]$ApplePinkDark                = [TrueColor]::new(0xFF375F)
    Static [TrueColor]$AppleBrownLight              = [TrueColor]::new(0xAC7F5E)
    Static [TrueColor]$AppleBrownDark               = [TrueColor]::new(0xB78A66)
    Static [TrueColor]$MistyRose                    = [TrueColor]::new(0xFFE4E1)
    Static [TrueColor]$ThemeBackground              = [TrueColor]::new(0x0C0C0C)
    Static [Boolean]$UseThemeBackground            = $true
    Static [TrueColor]$WindowBorderActiveColor      = [TrueColor]::new([ColorLibrary]::Ivory)
    Static [TrueColor]$WindowBorderInactiveColor    = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$TextActiveColor              = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$TextInactiveColor            = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$TextColor                    = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UICheckboxHasFocus           = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UICheckboxChecked            = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$UICheckboxInactiveColor      = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UICheckboxActive             = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIChevronActive              = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIChevronInactive            = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UIChevronHasFocus            = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UILabelActive                = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UILabelInactive              = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UITextInputActive            = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UITextInputInactive          = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UITextInputHasFocus          = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UITextInputPlaceholder       = [TrueColor]::new([ColorLibrary]::SlateGrey)
    Static [TrueColor]$UITextInputCursor            = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$UIButtonActive               = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIButtonInactive             = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UIButtonHasFocus             = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UIButtonBracketActive        = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$UIButtonBracketHasFocus      = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$UIRadioButtonActive          = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIRadioButtonInactive        = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UIRadioButtonHasFocus        = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UIRadioButtonSelected        = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$UIListItemActive              = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIListItemInactive            = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UIListItemSelected            = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIListItemSelectedBg          = [TrueColor]::Blend([TrueColor]::new(0x0C0C0C), [ColorLibrary]::AppleCyanLight, 0.28)
    Static [TrueColor]$UIListItemSelectedUnfocusedBg = [TrueColor]::Blend([TrueColor]::new(0x0C0C0C), [ColorLibrary]::GhostWhite, 0.14)
    Static [TrueColor]$UIListItemHasFocus            = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UIListScrollIndicator         = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$UINumberSpinnerActive        = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UINumberSpinnerInactive      = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UINumberSpinnerHasFocus      = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UINumberSpinnerValueModified = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$UIProgressBarFilled          = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$UIProgressBarEmpty           = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UIProgressBarInactive        = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UIProgressBarBorder          = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UIProgressBarText            = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UITabActive                  = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$UITabInactive                = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$UITabSelected                = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$UITabHasFocus                = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$UITabBorderActive            = [TrueColor]::new([ColorLibrary]::Ivory)
    Static [TrueColor]$UITabBorderSelected          = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$UITabBorderHasFocus          = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxBorderFocused         = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$BoomboxStatusPlaying         = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$BoomboxStatusPaused          = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxStatusStopped         = [TrueColor]::new([ColorLibrary]::SlateGrey)
    Static [TrueColor]$BoomboxStatusError           = [TrueColor]::new([ColorLibrary]::AppleRedLight)
    Static [TrueColor]$BoomboxDirEntry              = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$BoomboxParentDirEntry        = [TrueColor]::new([ColorLibrary]::AppleOrangeLight)
    Static [TrueColor]$BoomboxPlaylistFileEntry     = [TrueColor]::new([ColorLibrary]::ApplePurpleLight)
    Static [TrueColor]$BoomboxMediaFileEntry        = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$BoomboxNowPlayingEntry       = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$BoomboxVolumeSafe            = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$BoomboxVolumeHigh            = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxVolumeMuted           = [TrueColor]::new([ColorLibrary]::AppleRedLight)
    Static [TrueColor]$BoomboxScrubberFilled        = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$BoomboxModalBorder           = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxFooterHint            = [TrueColor]::new([ColorLibrary]::LightSlateGrey)
    Static [TrueColor]$BoomboxFooterStatus          = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$BoomboxFooterError           = [TrueColor]::new([ColorLibrary]::AppleRedLight)
    Static [TrueColor]$BoomboxSpinnerActive         = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$BoomboxEqActive              = [TrueColor]::new([ColorLibrary]::AppleMintLight)
    Static [TrueColor]$BoomboxEqInactive            = [TrueColor]::new([ColorLibrary]::SlateGrey)
    Static [TrueColor]$BoomboxEqBypassed            = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxEqSliderPos           = [TrueColor]::new([ColorLibrary]::AppleCyanLight)
    Static [TrueColor]$BoomboxEqSliderNeg           = [TrueColor]::new([ColorLibrary]::AppleOrangeLight)
    Static [TrueColor]$BoomboxEqSliderZero          = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$BoomboxEqSliderTrack         = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$BoomboxEqSliderFocused       = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxVizTrackLabel           = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$BoomboxVizHint                 = [TrueColor]::new([ColorLibrary]::LightSlateGrey)
    Static [TrueColor]$BoomboxVizPeakCap              = [TrueColor]::new([ColorLibrary]::White)
    Static [TrueColor]$BoomboxVizAxis                 = [TrueColor]::new([ColorLibrary]::DarkSlateGrey)
    Static [TrueColor]$BoomboxWarningBorder           = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxWarningTitle            = [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    Static [TrueColor]$BoomboxWarningText             = [TrueColor]::new([ColorLibrary]::GhostWhite)
    Static [TrueColor]$BoomboxWarningDimOk            = [TrueColor]::new([ColorLibrary]::AppleGreenLight)
    Static [TrueColor]$BoomboxWarningDimBad           = [TrueColor]::new([ColorLibrary]::AppleRedLight)
    Static [TrueColor[]]$BoomboxVizSpectrumGradient  = @(
        [TrueColor]::new([ColorLibrary]::DeepSkyBlue),
        [TrueColor]::new([ColorLibrary]::AppleCyanLight),
        [TrueColor]::new([ColorLibrary]::AppleMintLight),
        [TrueColor]::new([ColorLibrary]::AppleGreenLight),
        [TrueColor]::new([ColorLibrary]::YellowGreen),
        [TrueColor]::new([ColorLibrary]::AppleYellowLight),
        [TrueColor]::new([ColorLibrary]::AppleOrangeLight),
        [TrueColor]::new([ColorLibrary]::AppleRedLight)
    )
    Static [TrueColor[]]$BoomboxVizMirrorGradient    = @(
        [TrueColor]::new([ColorLibrary]::AppleBlueLight),
        [TrueColor]::new([ColorLibrary]::AppleCyanLight),
        [TrueColor]::new([ColorLibrary]::AppleMintLight),
        [TrueColor]::new([ColorLibrary]::AppleIndigoLight),
        [TrueColor]::new([ColorLibrary]::ApplePurpleLight),
        [TrueColor]::new([ColorLibrary]::MediumOrchid),
        [TrueColor]::new([ColorLibrary]::ApplePinkLight),
        [TrueColor]::new([ColorLibrary]::HotPink)
    )
    Static [TrueColor[]]$BoomboxVizScopeGradient     = @(
        [TrueColor]::new([ColorLibrary]::AppleCyanLight),
        [TrueColor]::new([ColorLibrary]::AppleMintLight),
        [TrueColor]::new([ColorLibrary]::AppleGreenLight),
        [TrueColor]::new([ColorLibrary]::AppleYellowLight)
    )
    Static [TrueColor[]]$BoomboxVizRadialGradient    = @(
        [TrueColor]::new([ColorLibrary]::AppleIndigoDark),
        [TrueColor]::new([ColorLibrary]::AppleBlueLight),
        [TrueColor]::new([ColorLibrary]::AppleCyanLight),
        [TrueColor]::new([ColorLibrary]::AppleMintLight),
        [TrueColor]::new([ColorLibrary]::AppleYellowLight),
        [TrueColor]::new([ColorLibrary]::AppleOrangeLight),
        [TrueColor]::new([ColorLibrary]::ApplePinkLight),
        [TrueColor]::new([ColorLibrary]::White)
    )
    Static [TrueColor[]]$BoomboxVizWaterfallGradient = @(
        [TrueColor]::new([ColorLibrary]::Black),
        [TrueColor]::new([ColorLibrary]::MidnightBlue),
        [TrueColor]::new([ColorLibrary]::DarkSlateBlue),
        [TrueColor]::new([ColorLibrary]::AppleBlueLight),
        [TrueColor]::new([ColorLibrary]::AppleCyanLight),
        [TrueColor]::new([ColorLibrary]::AppleMintLight),
        [TrueColor]::new([ColorLibrary]::AppleYellowLight),
        [TrueColor]::new([ColorLibrary]::AppleOrangeLight),
        [TrueColor]::new([ColorLibrary]::AppleRedLight)
    )

    Static [Void]ResetSemanticDefaults() {
        [ColorLibrary]::ThemeBackground.CopyFrom([TrueColor]::new(0x0C0C0C))
        [ColorLibrary]::WindowBorderActiveColor.CopyFrom([ColorLibrary]::Ivory)
        [ColorLibrary]::WindowBorderInactiveColor.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::TextActiveColor.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::TextInactiveColor.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::TextColor.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UICheckboxHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UICheckboxChecked.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::UICheckboxInactiveColor.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UICheckboxActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIChevronActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIChevronInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UIChevronHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UILabelActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UILabelInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UITextInputActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UITextInputInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UITextInputHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UITextInputPlaceholder.CopyFrom([ColorLibrary]::SlateGrey)
        [ColorLibrary]::UITextInputCursor.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::UIButtonActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIButtonInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UIButtonHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UIButtonBracketActive.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::UIButtonBracketHasFocus.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::UIRadioButtonActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIRadioButtonInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UIRadioButtonHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UIRadioButtonSelected.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::UIListItemActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIListItemInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UIListItemSelected.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIListItemSelectedBg.CopyFrom(([TrueColor]::Blend([TrueColor]::new(0x0C0C0C), [ColorLibrary]::AppleCyanLight, 0.28)))
        [ColorLibrary]::UIListItemSelectedUnfocusedBg.CopyFrom(([TrueColor]::Blend([TrueColor]::new(0x0C0C0C), [ColorLibrary]::GhostWhite, 0.14)))
        [ColorLibrary]::UIListItemHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UIListScrollIndicator.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::UINumberSpinnerActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UINumberSpinnerInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UINumberSpinnerHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UINumberSpinnerValueModified.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::UIProgressBarFilled.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::UIProgressBarEmpty.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UIProgressBarInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UIProgressBarBorder.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UIProgressBarText.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UITabActive.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::UITabInactive.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::UITabSelected.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::UITabHasFocus.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::UITabBorderActive.CopyFrom([ColorLibrary]::Ivory)
        [ColorLibrary]::UITabBorderSelected.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::UITabBorderHasFocus.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxBorderFocused.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxStatusPlaying.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxStatusPaused.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxStatusStopped.CopyFrom([ColorLibrary]::SlateGrey)
        [ColorLibrary]::BoomboxStatusError.CopyFrom([ColorLibrary]::AppleRedLight)
        [ColorLibrary]::BoomboxDirEntry.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxParentDirEntry.CopyFrom([ColorLibrary]::AppleOrangeLight)
        [ColorLibrary]::BoomboxPlaylistFileEntry.CopyFrom([ColorLibrary]::ApplePurpleLight)
        [ColorLibrary]::BoomboxMediaFileEntry.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::BoomboxNowPlayingEntry.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxVolumeSafe.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxVolumeHigh.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxVolumeMuted.CopyFrom([ColorLibrary]::AppleRedLight)
        [ColorLibrary]::BoomboxScrubberFilled.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxModalBorder.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxFooterHint.CopyFrom([ColorLibrary]::LightSlateGrey)
        [ColorLibrary]::BoomboxFooterStatus.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxFooterError.CopyFrom([ColorLibrary]::AppleRedLight)
        [ColorLibrary]::BoomboxSpinnerActive.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxEqActive.CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::BoomboxEqInactive.CopyFrom([ColorLibrary]::SlateGrey)
        [ColorLibrary]::BoomboxEqBypassed.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxEqSliderPos.CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxEqSliderNeg.CopyFrom([ColorLibrary]::AppleOrangeLight)
        [ColorLibrary]::BoomboxEqSliderZero.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::BoomboxEqSliderTrack.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::BoomboxEqSliderFocused.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxVizTrackLabel.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::BoomboxVizHint.CopyFrom([ColorLibrary]::LightSlateGrey)
        [ColorLibrary]::BoomboxVizPeakCap.CopyFrom([ColorLibrary]::White)
        [ColorLibrary]::BoomboxVizAxis.CopyFrom([ColorLibrary]::DarkSlateGrey)
        [ColorLibrary]::BoomboxWarningBorder.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxWarningTitle.CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxWarningText.CopyFrom([ColorLibrary]::GhostWhite)
        [ColorLibrary]::BoomboxWarningDimOk.CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxWarningDimBad.CopyFrom([ColorLibrary]::AppleRedLight)

        [ColorLibrary]::BoomboxVizSpectrumGradient[0].CopyFrom([ColorLibrary]::DeepSkyBlue)
        [ColorLibrary]::BoomboxVizSpectrumGradient[1].CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxVizSpectrumGradient[2].CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::BoomboxVizSpectrumGradient[3].CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxVizSpectrumGradient[4].CopyFrom([ColorLibrary]::YellowGreen)
        [ColorLibrary]::BoomboxVizSpectrumGradient[5].CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxVizSpectrumGradient[6].CopyFrom([ColorLibrary]::AppleOrangeLight)
        [ColorLibrary]::BoomboxVizSpectrumGradient[7].CopyFrom([ColorLibrary]::AppleRedLight)

        [ColorLibrary]::BoomboxVizMirrorGradient[0].CopyFrom([ColorLibrary]::AppleBlueLight)
        [ColorLibrary]::BoomboxVizMirrorGradient[1].CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxVizMirrorGradient[2].CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::BoomboxVizMirrorGradient[3].CopyFrom([ColorLibrary]::AppleIndigoLight)
        [ColorLibrary]::BoomboxVizMirrorGradient[4].CopyFrom([ColorLibrary]::ApplePurpleLight)
        [ColorLibrary]::BoomboxVizMirrorGradient[5].CopyFrom([ColorLibrary]::MediumOrchid)
        [ColorLibrary]::BoomboxVizMirrorGradient[6].CopyFrom([ColorLibrary]::ApplePinkLight)
        [ColorLibrary]::BoomboxVizMirrorGradient[7].CopyFrom([ColorLibrary]::HotPink)

        [ColorLibrary]::BoomboxVizScopeGradient[0].CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxVizScopeGradient[1].CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::BoomboxVizScopeGradient[2].CopyFrom([ColorLibrary]::AppleGreenLight)
        [ColorLibrary]::BoomboxVizScopeGradient[3].CopyFrom([ColorLibrary]::AppleYellowLight)

        [ColorLibrary]::BoomboxVizRadialGradient[0].CopyFrom([ColorLibrary]::AppleIndigoDark)
        [ColorLibrary]::BoomboxVizRadialGradient[1].CopyFrom([ColorLibrary]::AppleBlueLight)
        [ColorLibrary]::BoomboxVizRadialGradient[2].CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxVizRadialGradient[3].CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::BoomboxVizRadialGradient[4].CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxVizRadialGradient[5].CopyFrom([ColorLibrary]::AppleOrangeLight)
        [ColorLibrary]::BoomboxVizRadialGradient[6].CopyFrom([ColorLibrary]::ApplePinkLight)
        [ColorLibrary]::BoomboxVizRadialGradient[7].CopyFrom([ColorLibrary]::White)

        [ColorLibrary]::BoomboxVizWaterfallGradient[0].CopyFrom([ColorLibrary]::Black)
        [ColorLibrary]::BoomboxVizWaterfallGradient[1].CopyFrom([ColorLibrary]::MidnightBlue)
        [ColorLibrary]::BoomboxVizWaterfallGradient[2].CopyFrom([ColorLibrary]::DarkSlateBlue)
        [ColorLibrary]::BoomboxVizWaterfallGradient[3].CopyFrom([ColorLibrary]::AppleBlueLight)
        [ColorLibrary]::BoomboxVizWaterfallGradient[4].CopyFrom([ColorLibrary]::AppleCyanLight)
        [ColorLibrary]::BoomboxVizWaterfallGradient[5].CopyFrom([ColorLibrary]::AppleMintLight)
        [ColorLibrary]::BoomboxVizWaterfallGradient[6].CopyFrom([ColorLibrary]::AppleYellowLight)
        [ColorLibrary]::BoomboxVizWaterfallGradient[7].CopyFrom([ColorLibrary]::AppleOrangeLight)
        [ColorLibrary]::BoomboxVizWaterfallGradient[8].CopyFrom([ColorLibrary]::AppleRedLight)
    }

    Static [TrueColor]GetRandom() {
        Return [TrueColor]::new(
            [ColorChannel]::new((Get-Random -Minimum 1 -Maximum 255)),
            [ColorChannel]::new((Get-Random -Minimum 1 -Maximum 255)),
            [ColorChannel]::new((Get-Random -Minimum 1 -Maximum 255))
        )
    }
}
