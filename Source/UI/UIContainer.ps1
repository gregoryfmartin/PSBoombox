using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI CONTAINER
#
# PLACES A MEASURED BOX-DRAWING BORDER WITH AN OPTIONAL TITLE ON THE TERMINAL
# BUFFER AT SPECIFIC COORDINATES.
#
###############################################################################

Class UIContainer : UIBase {
    Static [Hashtable]$WindowDesignRounded = @{
        [WindowBorderPart]::LeftTop     = '╭'
        [WindowBorderPart]::Top         = '─'
        [WindowBorderPart]::RightTop    = '╮'
        [WindowBorderPart]::Left        = '│'
        [WindowBorderPart]::Right       = '│'
        [WindowBorderPart]::LeftBottom  = '╰'
        [WindowBorderPart]::Bottom      = '─'
        [WindowBorderPart]::RightBottom = '╯'
    }

    Static [Hashtable]$WindowDesignSquare = @{
        [WindowBorderPart]::LeftTop     = '┌'
        [WindowBorderPart]::Top         = '─'
        [WindowBorderPart]::RightTop    = '┐'
        [WindowBorderPart]::Left        = '│'
        [WindowBorderPart]::Right       = '│'
        [WindowBorderPart]::LeftBottom  = '└'
        [WindowBorderPart]::Bottom      = '─'
        [WindowBorderPart]::RightBottom = '┘'
    }

    [Int]$Width
    [Int]$Height
    [Boolean]$UseTitle
    [Boolean]$TitleDirty
    [Boolean]$ComplexTitle
    [Boolean[]]$BorderDrawDirty
    [ATCoordinates]$LeftTop
    [ATCoordinates]$RightBottom
    [TrueColor]$TitleColor
    [TrueColor]$ActiveBorderColor
    [TrueColor[]]$BorderDrawColors
    [String]$Title
    [Hashtable]$CurrentWindowDesigns

    UIContainer() : base() {
        $this.LeftTop           = [ATCoordinatesNone]::new()
        $this.RightBottom       = [ATCoordinatesNone]::new()
        $this.ActiveBorderColor = [ColorLibrary]::WindowBorderActiveColor
        $this.BorderDrawColors  = [TrueColor[]](
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor,
            [ColorLibrary]::WindowBorderActiveColor
        )
        $this.BorderDrawDirty = [Boolean[]](
            $true,
            $true,
            $true,
            $true
        )
        $this.Title                = ''
        $this.UseTitle             = $false
        $this.TitleDirty           = $false
        $this.ComplexTitle         = $false
        $this.TitleColor           = [ColorLibrary]::TextColor
        $this.CurrentWindowDesigns = [UIContainer]::WindowDesignRounded

        $this.Subscribe(@{
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIContainer]$Self     = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $Self.BorderDrawColors = [TrueColor[]](
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor,
                    $Self.ActiveBorderColor
                )
                $Self.TitleColor = [ColorLibrary]::TextActiveColor
                $Self.SetAllDirty()
            }
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIContainer]$Self     = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $Self.BorderDrawColors = [TrueColor[]](
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor,
                    [ColorLibrary]::WindowBorderInactiveColor
                )
                $Self.TitleColor = [ColorLibrary]::TextInactiveColor
                $Self.SetAllDirty()
            }
        })
    }

    [Void]UpdateDimensions() {
        $this.Width  = $this.RightBottom.Column.Value - $this.LeftTop.Column.Value
        $this.Height = $this.RightBottom.Row.Value - $this.LeftTop.Row.Value
    }

    [Void]SetupTitle(
        [String]$Title,
        [TrueColor]$Color
    ) {
        $this.UseTitle                                      = $true
        $this.TitleDirty                                    = $true
        $this.Title                                         = ($null -EQ $Title) ? '' : $Title
        $this.TitleColor                                    = ($null -EQ $Color) ? [ColorLibrary]::TextColor : $Color
        $this.BorderDrawDirty[[WindowBorderPartDirty]::Top] = $true
    }

    [Void]SetAllDirty() {
        $this.BorderDrawDirty = [Boolean[]]@(
            $true,
            $true,
            $true,
            $true
        )

        If($this.UseTitle -EQ $true) {
            $this.TitleDirty = $true
        }
    }

    [Void]SetBorderColor(
        [TrueColor]$Color
    ) {
        If($null -EQ $Color) {
            Return
        }

        $this.ActiveBorderColor = $Color

        If($this.IsActive() -EQ $true) {
            $this.BorderDrawColors = [TrueColor[]](
                $Color,
                $Color,
                $Color,
                $Color,
                $Color,
                $Color,
                $Color,
                $Color
            )
            $this.SetAllDirty()
        }
    }

    [Void]SetBorderColors(
        [TrueColor[]]$Colors
    ) {
        If($this.IsActive() -EQ $true) {
            $this.BorderDrawColors = $Colors
            $this.SetAllDirty()
        }
    }

    [Void]SetFocusedBorderHighlight(
        [Boolean]$IsZoneFocused
    ) {
        [TrueColor]$TargetColor = ($IsZoneFocused -EQ $true) ? [ColorLibrary]::BoomboxBorderFocused : [ColorLibrary]::WindowBorderActiveColor

        $this.SetBorderColor($TargetColor)
    }

    [Void]ClearInterior() {
        If(($this.Width -LE 1) -OR ($this.Height -LE 1)) {
            Return
        }

        [ATStringComposite]$ClearLines = [ATStringComposite]::new()
        [String]$BlankRow              = ' ' * ($this.Width - 1)
        [Int]$StartRow                 = $this.LeftTop.Row.Value + 1
        [Int]$EndRow                   = $this.RightBottom.Row.Value - 1
        [Int]$StartColumn              = $this.LeftTop.Column.Value + 1

        For([Int]$RowIdx = $StartRow; $RowIdx -LE $EndRow; $RowIdx++) {
            $ClearLines.CompositeActual.Add(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        Coordinates = [ATCoordinates]::new($RowIdx, $StartColumn)
                    }
                    UserData   = "$($BlankRow)"
                    UseATReset = $true
                }
            )
        }

        [String]$Payload = $ClearLines.ToAnsiControlSequenceString()

        If($Payload.Length -GT 0) {
            Write-Host "$($Payload)" -NoNewline
        }
    }

    [Void]ClearBoundingBox() {
        If(($this.Width -LT 1) -OR ($this.Height -LT 1)) {
            Return
        }

        [ATStringComposite]$ClearLines = [ATStringComposite]::new()
        [String]$BlankRow              = ' ' * ($this.Width + 1)
        [Int]$StartRow                 = $this.LeftTop.Row.Value
        [Int]$EndRow                   = $this.RightBottom.Row.Value
        [Int]$StartColumn              = $this.LeftTop.Column.Value

        For([Int]$RowIdx = $StartRow; $RowIdx -LE $EndRow; $RowIdx++) {
            $ClearLines.CompositeActual.Add(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        Coordinates = [ATCoordinates]::new($RowIdx, $StartColumn)
                    }
                    UserData   = "$($BlankRow)"
                    UseATReset = $true
                }
            )
        }

        [String]$Payload = $ClearLines.ToAnsiControlSequenceString()

        If($Payload.Length -GT 0) {
            Write-Host "$($Payload)" -NoNewline
        }
    }

    [Void]Draw() {
        [ATStringComposite]$BorderTop    = [ATStringComposite]::new()
        [ATStringComposite]$BorderBottom = [ATStringComposite]::new()
        [ATStringComposite]$BorderLeft   = [ATStringComposite]::new()
        [ATStringComposite]$BorderRight  = [ATStringComposite]::new()
        [ATString]$ATTitle               = [ATStringNone]::new()

        If($this.BorderDrawDirty[[WindowBorderPartDirty]::Top] -EQ $true) {
            $BorderTop = [ATStringComposite]::new(@(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::LeftTop]
                        Coordinates     = $this.LeftTop
                    }
                    UserData = "$($this.CurrentWindowDesigns[[WindowBorderPart]::LeftTop])"
                },
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::Top]
                    }
                    UserData = "$($this.CurrentWindowDesigns[[WindowBorderPart]::Top] * ($this.Width - 1))"
                },
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::RightTop]
                    }
                    UserData   = "$($this.CurrentWindowDesigns[[WindowBorderPart]::RightTop])"
                    UseATReset = $true
                }
            ))
            $this.BorderDrawDirty[[WindowBorderPartDirty]::Top] = $false
        }

        If($this.BorderDrawDirty[[WindowBorderPartDirty]::Bottom] -EQ $true) {
            $BorderBottom = [ATStringComposite]::new(@(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::LeftBottom]
                        Coordinates     = [ATCoordinates]::new($this.RightBottom.Row, $this.LeftTop.Column)
                    }
                    UserData = "$($this.CurrentWindowDesigns[[WindowBorderPart]::LeftBottom])"
                },
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::Bottom]
                    }
                    UserData = "$($this.CurrentWindowDesigns[[WindowBorderPart]::Bottom] * ($this.Width - 1))"
                },
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::RightBottom]
                    }
                    UserData   = "$($this.CurrentWindowDesigns[[WindowBorderPart]::RightBottom])"
                    UseATReset = $true
                }
            ))
            $this.BorderDrawDirty[[WindowBorderPartDirty]::Bottom] = $false
        }

        If($this.BorderDrawDirty[[WindowBorderPartDirty]::Left] -EQ $true) {
            [Int]$StartRow = $this.LeftTop.Row.Value + 1
            [Int]$EndRow   = $this.RightBottom.Row.Value - 1

            For([Int]$RowIdx = $StartRow; $RowIdx -LE $EndRow; $RowIdx++) {
                $BorderLeft.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::Left]
                            Coordinates     = [ATCoordinates]::new($RowIdx, $this.LeftTop.Column.Value)
                        }
                        UserData   = "$($this.CurrentWindowDesigns[[WindowBorderPart]::Left])"
                        UseATReset = $true
                    }
                )
            }

            $this.BorderDrawDirty[[WindowBorderPartDirty]::Left] = $false
        }

        If($this.BorderDrawDirty[[WindowBorderPartDirty]::Right] -EQ $true) {
            [Int]$StartRow = $this.LeftTop.Row.Value + 1
            [Int]$EndRow   = $this.RightBottom.Row.Value - 1

            For([Int]$RowIdx = $StartRow; $RowIdx -LE $EndRow; $RowIdx++) {
                $BorderRight.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            ForegroundColor = $this.BorderDrawColors[[WindowBorderPart]::Right]
                            Coordinates     = [ATCoordinates]::new($RowIdx, $this.RightBottom.Column.Value)
                        }
                        UserData   = "$($this.CurrentWindowDesigns[[WindowBorderPart]::Right])"
                        UseATReset = $true
                    }
                )
            }

            $this.BorderDrawDirty[[WindowBorderPartDirty]::Right] = $false
        }

        [String]$BorderComposite = "$($BorderTop.ToAnsiControlSequenceString())$($BorderBottom.ToAnsiControlSequenceString())$($BorderLeft.ToAnsiControlSequenceString())$($BorderRight.ToAnsiControlSequenceString())"

        If($BorderComposite.Length -GT 0) {
            Write-Host "$($BorderComposite)" -NoNewline
        }

        If($this.UseTitle -EQ $true) {
            If($this.TitleDirty -EQ $true) {
                [Int]$MaxTitleLen     = [Math]::Max(1, ($this.Width - 6))
                [String]$ClippedTitle = Format-TruncatedText $this.Title $MaxTitleLen
                $ATTitle              = [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = $this.TitleColor
                        Coordinates     = [ATCoordinates]::new($this.LeftTop.Row.Value, $this.LeftTop.Column.Value + 2)
                    }
                    UserData   = " $($ClippedTitle) "
                    UseATReset = $true
                }

                Write-Host "$($ATTitle.ToAnsiControlSequenceString())" -NoNewline
                $this.TitleDirty = $false
            }
        }
    }
}
