using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI CHEVRON
#
###############################################################################

Class UIChevron : UIBase {
    Static [String]$UnicodeChevronRight = "`u{276F}"
    Static [String]$UnicodeChevronLeft  = "`u{276E}"

    [UIChevronOrientation]$Orientation
    [ATCoordinates]$DrawCoordinates

    UIChevron() : base() {
        $this.Dirty                  = $true
        $this.UseATReset             = $true
        $this.Orientation            = [UIChevronOrientation]::Left
        $this.DrawCoordinates        = [ATCoordinates]::new(1, 1)
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIChevronInactive)
        $this.SetupStates()
    }

    UIChevron(
        [UIChevronOrientation]$Orientation,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Dirty                  = $true
        $this.UseATReset             = $true
        $this.Orientation            = $Orientation
        $this.DrawCoordinates        = $DrawCoordinates
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIChevronInactive)
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIChevron]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIChevronInactive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIChevron]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIChevronActive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIChevron]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIChevronHasFocus)
                $SelfElement.Dirty                  = $true
            }
        })
    }

    [String]ToAnsiControlSequenceString() {
        $this.Prefix.Coordinates = [ATCoordinates]::new($this.DrawCoordinates)

        Switch($this.Orientation) {
            ([UIChevronOrientation]::Left) {
                $this.SetUserData("$([UIChevron]::UnicodeChevronLeft)")

                Break
            }

            ([UIChevronOrientation]::Right) {
                $this.SetUserData("$([UIChevron]::UnicodeChevronRight)")

                Break
            }

            Default {
                $this.SetUserData("$([UIChevron]::UnicodeChevronLeft)")

                Break
            }
        }

        Return "$(([UIBase]$this).ToAnsiControlSequenceString())"
    }
}
