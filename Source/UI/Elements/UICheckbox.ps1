using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UICHECKBOX
#
###############################################################################

Class UICheckbox : UIBase {
    Static [String]$UnicodeBoxUnchecked = "`u{2610}"
    Static [String]$UnicodeBoxChecked   = "`u{2611}"

    [UICheckboxState]$State
    [ATCoordinates]$DrawCoordinates

    UICheckbox() : base() {
        $this.State                  = [UICheckboxState]::Unchecked
        $this.DrawCoordinates        = [ATCoordinates]::new(1, 1)
        $this.Dirty                  = $true
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UICheckboxInactiveColor)
        $this.SetupStates()
    }

    UICheckbox(
        [String]$LabelText
    ) : base() {
        $this.Dirty                  = $true
        $this.State                  = [UICheckboxState]::Unchecked
        $this.DrawCoordinates        = [ATCoordinates]::new(1, 1)
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UICheckboxInactiveColor)
        $this.SetUserData($LabelText)
        $this.SetupStates()
    }

    UICheckbox(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Dirty                  = $true
        $this.State                  = [UICheckboxState]::Unchecked
        $this.DrawCoordinates        = $DrawCoordinates
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UICheckboxInactiveColor)
        $this.SetUserData($LabelText)
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UICheckbox]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UICheckboxInactiveColor)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UICheckbox]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UICheckboxActive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UICheckbox]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UICheckboxHasFocus)
                $SelfElement.Prefix.Decorations     = [ATDecoration]@{
                    Italic = $true
                }
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UICheckbox]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.Decorations = [ATDecorationNone]::new()
                $SelfElement.Dirty              = $true
            }
        })
    }

    [Void]ToggleCheckbox() {
        Switch($this.State) {
            ([UICheckboxState]::Unchecked) {
                $this.State = [UICheckboxState]::Checked

                Break
            }

            ([UICheckboxState]::Checked) {
                $this.State = [UICheckboxState]::Unchecked

                Break
            }

            Default {
                # DO NOTHING
            }
        }

        $this.Dirty = $true
    }

    [String]ToAnsiControlSequenceString() {
        [ATStringComposite]$Composite = [ATStringComposite]::new()

        Switch($this.State) {
            ([UICheckboxState]::Unchecked) {
                $Composite.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            ForegroundColor = ($this.IsActive() -EQ $true) ? [ColorLibrary]::TextColor : [ColorLibrary]::UICheckboxInactiveColor
                            Coordinates     = $this.DrawCoordinates
                        }
                        UserData   = "$([UICheckbox]::UnicodeBoxUnchecked) "
                        UseATReset = $true
                    }
                )

                Break
            }

            ([UICheckboxState]::Checked) {
                $Composite.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            ForegroundColor = ($this.IsActive() -EQ $true) ? [ColorLibrary]::UICheckboxChecked : [ColorLibrary]::UICheckboxInactiveColor
                            Coordinates     = $this.DrawCoordinates
                        }
                        UserData   = "$([UICheckbox]::UnicodeBoxChecked) "
                        UseATReset = $true
                    }
                )

                Break
            }

            Default {
                $Composite.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            ForegroundColor = ($this.IsActive() -EQ $true) ? [ColorLibrary]::TextColor : [ColorLibrary]::UICheckboxInactiveColor
                            Coordinates     = $this.DrawCoordinates
                        }
                        UserData   = "$([UICheckbox]::UnicodeBoxUnchecked) "
                        UseATReset = $true
                    }
                )

                Break
            }
        }

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = $this.Prefix.ForegroundColor
                    Decorations     = $this.Prefix.Decorations
                }
                UserData   = "$($this.UserData)"
                UseATReset = $true
            }
        )

        Return "$($Composite.ToAnsiControlSequenceString())"
    }
}
