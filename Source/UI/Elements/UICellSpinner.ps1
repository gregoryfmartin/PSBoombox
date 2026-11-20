using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI CELL SPINNER
#
# A SPINNER THAT OCCUPIES A SINGLE BUFFER CELL.
#
###############################################################################

Class UICellSpinner : UIBase {
    [StringAnimator]$Animator
    [Double]$AnimationSpeedScalar
    [ATCoordinates]$DrawCoordinates
    [TrueColor]$ActiveColor
    [Boolean]$Spinning

    UICellSpinner() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            10,
            [ColorLibrary]::BoomboxSpinnerActive
        )
    }

    UICellSpinner(
        [Int]$Fps,
        [TrueColor]$ForegroundColor
    ) : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            $Fps,
            $ForegroundColor
        )
    }

    UICellSpinner(
        [ATCoordinates]$DrawCoordinates,
        [Int]$Fps,
        [TrueColor]$ForegroundColor
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $Fps,
            $ForegroundColor
        )
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [Int]$Fps,
        [TrueColor]$ForegroundColor
    ) {
        [TrueColor]$ResolvedColor = ($null -EQ $ForegroundColor) ? [ColorLibrary]::BoomboxSpinnerActive : $ForegroundColor
        $this.DrawCoordinates     = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.ActiveColor         = $ResolvedColor
        $this.Spinning            = $false
        $this.Animator            = [StringAnimator]::new(
            @(
                "`u{280B}",
                "`u{2819}",
                "`u{2839}",
                "`u{2838}",
                "`u{283C}",
                "`u{2834}",
                "`u{2826}",
                "`u{2827}",
                "`u{2807}",
                "`u{280F}"
            ),
            $Fps
        )
        $this.AnimationSpeedScalar   = 1.0
        $this.UseATReset             = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new($ResolvedColor)
        $this.SetUserData(' ')
        $this.Dirty = $true

        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UICellSpinner]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UILabelInactive)
                $SelfElement.SetUserData(' ')
                $SelfElement.Dirty = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UICellSpinner]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new($SelfElement.ActiveColor)
                $SelfElement.RefreshFrame()
            }
        })
    }

    [Void]SetSpinning(
        [Boolean]$IsSpinning
    ) {
        If($this.Spinning -NE $IsSpinning) {
            $this.Spinning = $IsSpinning

            $this.RefreshFrame()
        }
    }

    [Void]RefreshFrame() {
        If(($this.IsActive() -EQ $true) -AND ($this.Spinning -EQ $true)) {
            $this.SetUserData("$($this.Animator.GetCurrentFrame())")
        } Else {
            $this.SetUserData(' ')
        }

        $this.Dirty = $true
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)

        If(($this.IsActive() -EQ $true) -AND ($this.Spinning -EQ $true) -AND ($null -NE $Context) -AND ($Context.References.ContainsKey([SMState]::ContextDeltaTime) -EQ $true)) {
            [Double]$DeltaTime     = $Context.References[[SMState]::ContextDeltaTime]
            [Int]$PreviousFrameIdx = $this.Animator.CurrentFrameIndex

            $this.Animator.Update($DeltaTime * $this.AnimationSpeedScalar)

            If($this.Animator.CurrentFrameIndex -NE $PreviousFrameIdx) {
                $this.SetUserData("$($this.Animator.GetCurrentFrame())")
                $this.Dirty = $true
            }
        }
    }

    [String]ToAnsiControlSequenceString() {
        $this.Prefix.Coordinates = [ATCoordinates]::new($this.DrawCoordinates)

        Return "$(([UIBase]$this).ToAnsiControlSequenceString())"
    }
}
