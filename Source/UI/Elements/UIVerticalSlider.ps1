using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI VERTICAL SLIDER
#
# A FOCUSABLE VERTICAL FADER BAR FOR EQUALIZER PREAMP AND FREQUENCY BANDS
# SUPPORTING +/-12 DB GAIN IN 1 DB STEPS.
#
###############################################################################

Class UIVerticalSlider : UIBase {
    Static [Int]$DefaultMinValue   = -12
    Static [Int]$DefaultMaxValue   = 12
    Static [Int]$DefaultStep       = 1
    Static [Int]$DefaultColumnWidth = 5
    Static [Int]$DefaultBarHeight  = 9
    Static [String]$FilledGlyph    = "`u{2588}"
    Static [String]$CenterGlyph    = "`u{2500}"
    Static [String]$TrackGlyph     = "`u{2502}"

    [String]$Label
    [Int]$MinValue
    [Int]$MaxValue
    [Int]$Step
    [Int]$CurrentValue
    [Int]$ColumnWidth
    [Int]$BarHeight
    [Boolean]$EqEnabled
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnValueChanged

    UIVerticalSlider() : base() {
        $this.Initialize('Band', [ATCoordinates]::new(1, 1), 0, -12, 12, 1)
    }

    UIVerticalSlider(
        [String]$Label,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize($Label, $DrawCoordinates, 0, -12, 12, 1)
    }

    UIVerticalSlider(
        [String]$Label,
        [ATCoordinates]$DrawCoordinates,
        [Int]$InitialValue,
        [Int]$MinValue,
        [Int]$MaxValue,
        [Int]$Step
    ) : base() {
        $this.Initialize($Label, $DrawCoordinates, $InitialValue, $MinValue, $MaxValue, $Step)
    }

    [Void]Initialize(
        [String]$Label,
        [ATCoordinates]$DrawCoordinates,
        [Int]$InitialValue,
        [Int]$MinValue,
        [Int]$MaxValue,
        [Int]$Step
    ) {
        [Int]$SafeMin            = $MinValue
        [Int]$SafeMax            = ($MaxValue -LT $SafeMin) ? $SafeMin : $MaxValue
        [Int]$SafeVal            = [Math]::Clamp($InitialValue, $SafeMin, $SafeMax)

        $this.Label                 = ($null -EQ $Label) ? '' : $Label
        $this.DrawCoordinates       = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.MinValue              = $SafeMin
        $this.MaxValue              = $SafeMax
        $this.Step                  = [Math]::Max(1, $Step)
        $this.CurrentValue          = $SafeVal
        $this.ColumnWidth           = [UIVerticalSlider]::DefaultColumnWidth
        $this.BarHeight             = [UIVerticalSlider]::DefaultBarHeight
        $this.EqEnabled             = $true
        $this.OnValueChanged        = $null
        $this.UseATReset            = $true
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true

        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIVerticalSlider]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty             = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIVerticalSlider]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty             = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIVerticalSlider]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty             = $true
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UIVerticalSlider]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty             = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UIVerticalSlider]$SelfElement    = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                If($null -NE $KeysPressed) {
                    Foreach($KeyInfo in $KeysPressed) {
                        $SelfElement.HandleKey($KeyInfo)
                    }
                }
            }
        })
    }

    [Void]SetValue(
        [Int]$NewValue
    ) {
        [Int]$Clamped = [Math]::Clamp($NewValue, $this.MinValue, $this.MaxValue)

        If($Clamped -NE $this.CurrentValue) {
            $this.CurrentValue = $Clamped
            $this.Dirty        = $true

            If($null -NE $this.OnValueChanged) {
                $this.OnValueChanged.Invoke($this)
            }
        }
    }

    [Void]SetValueSilent(
        [Int]$NewValue
    ) {
        [Int]$Clamped = [Math]::Clamp($NewValue, $this.MinValue, $this.MaxValue)

        If($Clamped -NE $this.CurrentValue) {
            $this.CurrentValue = $Clamped
            $this.Dirty        = $true
        }
    }

    [Void]SetEqEnabled(
        [Boolean]$Enabled
    ) {
        If($this.EqEnabled -NE $Enabled) {
            $this.EqEnabled = $Enabled
            $this.Dirty     = $true
        }
    }

    [Void]AdjustValue(
        [Int]$Delta
    ) {
        $this.SetValue($this.CurrentValue + $Delta)
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.AdjustValue($this.Step)

                Break
            }

            ([ConsoleKey]::DownArrow) {
                $this.AdjustValue(-$this.Step)

                Break
            }

            ([ConsoleKey]::PageUp) {
                $this.AdjustValue($this.Step * 3)

                Break
            }

            ([ConsoleKey]::PageDown) {
                $this.AdjustValue(-($this.Step * 3))

                Break
            }

            ([ConsoleKey]::Home) {
                $this.SetValue($this.MaxValue)

                Break
            }

            ([ConsoleKey]::End) {
                $this.SetValue($this.MinValue)

                Break
            }

            ([ConsoleKey]::D0) {
                $this.SetValue(0)

                Break
            }

            ([ConsoleKey]::NumPad0) {
                $this.SetValue(0)

                Break
            }

            ([ConsoleKey]::Delete) {
                $this.SetValue(0)

                Break
            }

            Default {
                # IGNORE OTHER KEYS
                Break
            }
        }
    }

    [String]CenterText(
        [String]$Text,
        [Int]$Width
    ) {
        [String]$Clipped = ($Text.Length -GT $Width) ? $Text.Substring(0, $Width) : $Text
        [Int]$TotalPad   = $Width - $Clipped.Length
        [Int]$LeftPad    = [Int][Math]::Floor($TotalPad / 2.0)
        [Int]$RightPad   = $TotalPad - $LeftPad

        Return "$(' ' * $LeftPad)$($Clipped)$(' ' * $RightPad)"
    }

    [String]FormatDbReadout() {
        If($this.CurrentValue -GT 0) {
            Return "+$($this.CurrentValue)"
        }

        Return "$($this.CurrentValue)"
    }

    [String]ToAnsiControlSequenceString() {
        [ATStringComposite]$Composite = [ATStringComposite]::new()
        [Int]$StartRow                = $this.DrawCoordinates.Row.Value
        [Int]$StartCol                = $this.DrawCoordinates.Column.Value
        [Boolean]$Active              = $this.IsActive()
        [Boolean]$Focused             = $this.IsFocused()

        [TrueColor]$ValueColor = [ColorLibrary]::BoomboxEqSliderTrack
        [TrueColor]$LabelColor = [ColorLibrary]::BoomboxEqSliderTrack

        If($Active -EQ $true) {
            If($Focused -EQ $true) {
                $ValueColor = [ColorLibrary]::BoomboxEqSliderFocused
                $LabelColor = [ColorLibrary]::BoomboxEqSliderFocused
            } Elseif($this.EqEnabled -EQ $false) {
                $ValueColor = [ColorLibrary]::SlateGrey
                $LabelColor = [ColorLibrary]::UILabelActive
            } Elseif($this.CurrentValue -GT 0) {
                $ValueColor = [ColorLibrary]::BoomboxEqSliderPos
                $LabelColor = [ColorLibrary]::UILabelActive
            } Elseif($this.CurrentValue -LT 0) {
                $ValueColor = [ColorLibrary]::BoomboxEqSliderNeg
                $LabelColor = [ColorLibrary]::UILabelActive
            } Else {
                $ValueColor = [ColorLibrary]::BoomboxEqSliderZero
                $LabelColor = [ColorLibrary]::UILabelActive
            }
        }

        # TOP ROW: NUMERIC DB VALUE
        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new($ValueColor)
                    Coordinates     = [ATCoordinates]::new($StartRow, $StartCol)
                }
                UserData   = $this.CenterText($this.FormatDbReadout(), $this.ColumnWidth)
                UseATReset = $true
            }
        )

        # ROWS +1..+9: VERTICAL FADER BAR (ROWS 0..3 POSITIVE, ROW 4 ZERO LINE, ROWS 5..8 NEGATIVE)
        [Int]$PosCells = ($this.CurrentValue -GT 0) ? [Int][Math]::Ceiling(([Double]$this.CurrentValue / [Double]$this.MaxValue) * 4.0) : 0
        [Int]$NegCells = ($this.CurrentValue -LT 0) ? [Int][Math]::Ceiling(([Double][Math]::Abs($this.CurrentValue) / [Double][Math]::Abs($this.MinValue)) * 4.0) : 0

        [String]$BarGlyph = [UIVerticalSlider]::FilledGlyph * 3
        [String]$RailCell = "  $([UIVerticalSlider]::TrackGlyph)  "
        [String]$ZeroCell = " $([UIVerticalSlider]::CenterGlyph * 3) "
        [String]$FillCell = " $($BarGlyph) "

        For([Int]$BarRow = 0; $BarRow -LT $this.BarHeight; $BarRow++) {
            [Int]$DrawRow       = $StartRow + 1 + $BarRow
            [String]$RowText    = $RailCell
            [TrueColor]$RowClr  = [ColorLibrary]::BoomboxEqSliderTrack

            If($BarRow -LT 4) {
                [Int]$RowLevel = 4 - $BarRow

                If($PosCells -GE $RowLevel) {
                    $RowText = $FillCell

                    If($Active -EQ $false) {
                        $RowClr = [ColorLibrary]::BoomboxEqSliderTrack
                    } Elseif($Focused -EQ $true) {
                        $RowClr = ($PosCells -EQ $RowLevel) ? [ColorLibrary]::BoomboxEqSliderFocused : [ColorLibrary]::BoomboxEqSliderPos
                    } Else {
                        $RowClr = ($this.EqEnabled -EQ $true) ? [ColorLibrary]::BoomboxEqSliderPos : [ColorLibrary]::BoomboxEqSliderTrack
                    }
                }
            } Elseif($BarRow -EQ 4) {
                If($this.CurrentValue -EQ 0) {
                    $RowText = ($Focused -EQ $true) ? $FillCell : $ZeroCell

                    If($Active -EQ $false) {
                        $RowClr = [ColorLibrary]::BoomboxEqSliderTrack
                    } Elseif($Focused -EQ $true) {
                        $RowClr = [ColorLibrary]::BoomboxEqSliderFocused
                    } Else {
                        $RowClr = ($this.EqEnabled -EQ $true) ? [ColorLibrary]::BoomboxEqSliderZero : [ColorLibrary]::BoomboxEqSliderTrack
                    }
                } Else {
                    $RowText = $ZeroCell
                    $RowClr  = ($Active -EQ $true) ? [ColorLibrary]::BoomboxEqSliderTrack : [ColorLibrary]::UIButtonInactive
                }
            } Else {
                [Int]$RowDepth = $BarRow - 4

                If($NegCells -GE $RowDepth) {
                    $RowText = $FillCell

                    If($Active -EQ $false) {
                        $RowClr = [ColorLibrary]::BoomboxEqSliderTrack
                    } Elseif($Focused -EQ $true) {
                        $RowClr = ($NegCells -EQ $RowDepth) ? [ColorLibrary]::BoomboxEqSliderFocused : [ColorLibrary]::BoomboxEqSliderNeg
                    } Else {
                        $RowClr = ($this.EqEnabled -EQ $true) ? [ColorLibrary]::BoomboxEqSliderNeg : [ColorLibrary]::BoomboxEqSliderTrack
                    }
                }
            }

            $Composite.CompositeActual.Add(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = [ATForegroundColor24]::new($RowClr)
                        Coordinates     = [ATCoordinates]::new($DrawRow, $StartCol)
                    }
                    UserData   = $RowText
                    UseATReset = $true
                }
            )
        }

        # BOTTOM ROW: BAND LABEL
        [ATDecoration]$LabelDecor = ($Focused -EQ $true) ? ([ATDecoration]@{ Italic = $true }) : ([ATDecorationNone]::new())
        [String]$PaddedLabel      = $this.CenterText($this.Label, $this.ColumnWidth)

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new($LabelColor)
                    Decorations     = $LabelDecor
                    Coordinates     = [ATCoordinates]::new(($StartRow + 10), $StartCol)
                }
                UserData   = $PaddedLabel
                UseATReset = $true
            }
        )

        Return "$($Composite.ToAnsiControlSequenceString())"
    }
}
