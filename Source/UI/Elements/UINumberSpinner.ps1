using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI NUMBER SPINNER
#
# A NUMERIC SPINNER CONTROL COMPOSING LEFT AND RIGHT CHEVRONS WITH A BOUND OR
# UNBOUND INTEGER VALUE.
#
###############################################################################

Class UINumberSpinner : UIBase {
    Static [Int]$DefaultDigitWidth = 3
    Static [Int]$DefaultStep       = 1
    Static [Int]$DefaultMinValue   = 0
    Static [Int]$DefaultMaxValue   = 999

    [Int]$CurrentValue
    [Int]$InitialBaseValue
    [Int]$MinValue
    [Int]$MaxValue
    [Int]$Step
    [Int]$DigitWidth
    [ClampableInt]$BoundValue
    [UIChevron]$LeftChevron
    [UIChevron]$RightChevron
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnValueChanged

    UINumberSpinner() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            0,
            [UINumberSpinner]::DefaultMinValue,
            [UINumberSpinner]::DefaultMaxValue,
            [UINumberSpinner]::DefaultStep
        )
    }

    UINumberSpinner(
        [ATCoordinates]$DrawCoordinates,
        [ClampableInt]$BoundValue
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            0,
            [UINumberSpinner]::DefaultMinValue,
            [UINumberSpinner]::DefaultMaxValue,
            [UINumberSpinner]::DefaultStep
        )

        $this.BindValue($BoundValue)
    }

    UINumberSpinner(
        [ATCoordinates]$DrawCoordinates,
        [ClampableInt]$BoundValue,
        [Int]$Step
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            0,
            [UINumberSpinner]::DefaultMinValue,
            [UINumberSpinner]::DefaultMaxValue,
            $Step
        )

        $this.BindValue($BoundValue)
    }

    UINumberSpinner(
        [ATCoordinates]$DrawCoordinates,
        [Int]$InitialValue,
        [Int]$MinValue,
        [Int]$MaxValue,
        [Int]$Step
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $InitialValue,
            $MinValue,
            $MaxValue,
            $Step
        )
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [Int]$InitialValue,
        [Int]$MinValue,
        [Int]$MaxValue,
        [Int]$Step
    ) {
        [Int]$SafeMin   = $MinValue
        [Int]$SafeMax   = ($MaxValue -LT $SafeMin) ? $SafeMin : $MaxValue
        [Int]$SafeStep  = [Math]::Max(1, $Step)
        [Int]$SafeValue = [Math]::Clamp($InitialValue, $SafeMin, $SafeMax)

        $this.DrawCoordinates        = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.MinValue               = $SafeMin
        $this.MaxValue               = $SafeMax
        $this.Step                   = $SafeStep
        $this.CurrentValue           = $SafeValue
        $this.InitialBaseValue       = $SafeValue
        $this.BoundValue             = $null
        $this.OnValueChanged         = $null
        $this.DigitWidth             = [Math]::Max(1, [Math]::Max($SafeMin.ToString().Length, $SafeMax.ToString().Length))
        $this.UseATReset             = $true
        $this.Dirty                  = $true
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UINumberSpinnerInactive)

        [ATCoordinates]$LeftCoords  = [ATCoordinates]::new($this.DrawCoordinates)
        [ATCoordinates]$RightCoords = [ATCoordinates]::new(
            $this.DrawCoordinates.Row.Value,
            ($this.DrawCoordinates.Column.Value + 1 + (1 + $this.DigitWidth + 1))
        )

        $this.LeftChevron                        = [UIChevron]::new([UIChevronOrientation]::Left, $LeftCoords)
        $this.RightChevron                       = [UIChevron]::new([UIChevronOrientation]::Right, $RightCoords)
        $this.LeftChevron.Behavior.CanHaveFocus  = $true
        $this.RightChevron.Behavior.CanHaveFocus = $true

        $this.UpdateValueRenderState()
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UINumberSpinner]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.Decorations     = [ATDecorationNone]::new()
                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UINumberSpinnerInactive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UINumberSpinner]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.Decorations     = [ATDecorationNone]::new()
                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new($SelfElement.GetValueColor())
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UINumberSpinner]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new($SelfElement.GetValueColor())
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UINumberSpinner]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.Decorations = [ATDecorationNone]::new()
                $SelfElement.Dirty              = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UINumberSpinner]$SelfElement      = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                If($null -NE $KeysPressed) {
                    Foreach($KeyInfo in $KeysPressed) {
                        $SelfElement.HandleKey($KeyInfo)
                    }
                }
            }
        })
    }

    [Void]BindValue(
        [ClampableInt]$BoundValue
    ) {
        $this.BoundValue = $BoundValue

        If($null -NE $BoundValue) {
            $this.MinValue         = $BoundValue.Floor
            $this.MaxValue         = $BoundValue.Ceiling
            $this.DigitWidth       = [Math]::Max(1, [Math]::Max($this.MinValue.ToString().Length, $this.MaxValue.ToString().Length))
            $this.CurrentValue     = [Math]::Clamp($BoundValue.Value, $this.MinValue, $this.MaxValue)
            $this.InitialBaseValue = $this.CurrentValue
        } Else {
            $this.MinValue         = [UINumberSpinner]::DefaultMinValue
            $this.MaxValue         = [UINumberSpinner]::DefaultMaxValue
            $this.DigitWidth       = [UINumberSpinner]::DefaultDigitWidth
            $this.CurrentValue     = [Math]::Clamp(0, $this.MinValue, $this.MaxValue)
            $this.InitialBaseValue = $this.CurrentValue
        }

        $this.UpdateValueRenderState()

        $this.LeftChevron.Dirty  = $true
        $this.RightChevron.Dirty = $true
        $this.Dirty              = $true
    }

    [Void]SetValue(
        [Int]$NewValue
    ) {
        [Int]$Clamped = [Math]::Clamp($NewValue, $this.MinValue, $this.MaxValue)

        If(($null -NE $this.BoundValue) -AND ($this.BoundValue.Value -NE $Clamped)) {
            $this.BoundValue.SetValue($Clamped)
        }

        If($Clamped -EQ $this.CurrentValue) {
            Return
        }

        $this.CurrentValue = $Clamped

        $this.UpdateValueRenderState()

        $this.Dirty = $true

        If($null -NE $this.OnValueChanged) {
            $this.OnValueChanged.Invoke($this)
        }
    }

    [Void]Increment() {
        $this.SetValue($this.CurrentValue + $this.Step)
    }

    [Void]Decrement() {
        $this.SetValue($this.CurrentValue - $this.Step)
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::LeftArrow) {
                $this.Decrement()

                Break
            }

            ([ConsoleKey]::RightArrow) {
                $this.Increment()

                Break
            }

            Default {
                # IGNORE OTHER KEYS
                Break
            }
        }
    }

    [String]FormatValueString() {
        If($this.CurrentValue -LT 0) {
            [Int]$PadWidth = [Math]::Max(1, ($this.DigitWidth - 1))

            Return "-$([Math]::Abs($this.CurrentValue).ToString().PadLeft($PadWidth, '0'))"
        }

        Return "$($this.CurrentValue.ToString().PadLeft($this.DigitWidth, '0'))"
    }

    [TrueColor]GetValueColor() {
        If($this.IsActive() -EQ $false) {
            Return [ColorLibrary]::UINumberSpinnerInactive
        }

        If($this.CurrentValue -NE $this.InitialBaseValue) {
            Return [ColorLibrary]::UINumberSpinnerValueModified
        }

        If($this.IsFocused() -EQ $true) {
            Return [ColorLibrary]::UINumberSpinnerHasFocus
        }

        Return [ColorLibrary]::UINumberSpinnerActive
    }

    [Void]UpdateValueRenderState() {
        [ATCoordinates]$RightCoords = [ATCoordinates]::new(
            $this.DrawCoordinates.Row.Value,
            ($this.DrawCoordinates.Column.Value + 1 + (1 + $this.DigitWidth + 1))
        )

        $this.LeftChevron.DrawCoordinates  = [ATCoordinates]::new($this.DrawCoordinates)
        $this.RightChevron.DrawCoordinates = $RightCoords
        $this.Prefix.Coordinates           = [ATCoordinates]::new(
            $this.DrawCoordinates.Row.Value,
            ($this.DrawCoordinates.Column.Value + 2)
        )
        $this.Prefix.ForegroundColor       = [ATForegroundColor24]::new($this.GetValueColor())

        $this.SetBlankSize($this.DigitWidth)
        $this.SetUserData($this.FormatValueString())
    }

    [Void]Activate(
        [Context]$Context
    ) {
        ([UIBase]$this).Activate($Context)
        $this.LeftChevron.Activate($Context)
        $this.RightChevron.Activate($Context)
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        ([UIBase]$this).Deactivate($Context)
        $this.LeftChevron.Deactivate($Context)
        $this.RightChevron.Deactivate($Context)
    }

    [Void]Focus(
        [Context]$Context
    ) {
        ([UIBase]$this).Focus($Context)

        If($this.Behavior.CanHaveFocus -EQ $true) {
            $this.LeftChevron.Focus($Context)
            $this.RightChevron.Focus($Context)
        }
    }

    [Void]Unfocus(
        [Context]$Context
    ) {
        ([UIBase]$this).Unfocus($Context)
        $this.LeftChevron.Unfocus($Context)
        $this.RightChevron.Unfocus($Context)
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)

        If($this.IsActive() -EQ $true) {
            If(($null -NE $this.BoundValue) -AND ($this.BoundValue.Value -NE $this.CurrentValue)) {
                $this.SetValue($this.BoundValue.Value)
            }
        }

        $this.LeftChevron.Update($Context)
        $this.RightChevron.Update($Context)
    }

    [String]ToAnsiControlSequenceString() {
        $this.UpdateValueRenderState()

        Return "$($this.LeftChevron.ToAnsiControlSequenceString())$(([UIBase]$this).ToAnsiControlSequenceString())$($this.RightChevron.ToAnsiControlSequenceString())"
    }

    [Void]Draw() {
        $this.LeftChevron.Draw()

        If($this.Dirty -EQ $true) {
            $this.UpdateValueRenderState()

            Write-Host "$(([UIBase]$this).ToAnsiControlSequenceString())" -NoNewline

            $this.Dirty = $false
        }

        $this.RightChevron.Draw()
    }
}
