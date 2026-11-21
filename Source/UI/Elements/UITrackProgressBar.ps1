using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI TRACK PROGRESS BAR
#
# A FOCUSABLE TRACK PROGRESS SCRUBBER DISPLAYING ELAPSED AND TOTAL TIME AROUND
# A UIPROGRESSBAR AND SUPPORTING SEEKING VIA LEFT/RIGHT KEYS.
#
###############################################################################

Class UITrackProgressBar : UIBase {
    Static [Int]$DefaultSeekStepMs = 5000

    [Int]$PositionMs
    [Int]$DurationMs
    [Int]$BarWidth
    [Int]$SeekStepMs
    [UIProgressBar]$ProgressBar
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnSeekRequested

    UITrackProgressBar() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            30
        )
    }

    UITrackProgressBar(
        [ATCoordinates]$DrawCoordinates,
        [Int]$BarWidth
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $BarWidth
        )
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [Int]$BarWidth
    ) {
        [ATCoordinates]$SafeCoords = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        [Int]$SafeBarWidth         = [Math]::Max(8, $BarWidth)

        $this.DrawCoordinates       = $SafeCoords
        $this.BarWidth              = $SafeBarWidth
        $this.PositionMs            = 0
        $this.DurationMs            = 0
        $this.SeekStepMs            = [UITrackProgressBar]::DefaultSeekStepMs
        $this.OnSeekRequested       = $null
        $this.UseATReset            = $true
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true
        $this.ProgressBar           = [UIProgressBar]::new(
            $SafeCoords,
            0,
            0,
            1000,
            $SafeBarWidth
        )
        $this.ProgressBar.ShowNumericText = $false
        $this.ProgressBar.FilledColor     = [ColorLibrary]::BoomboxScrubberFilled

        $this.SyncRenderState()
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITrackProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITrackProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITrackProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UITrackProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UITrackProgressBar]$SelfElement   = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                If($null -NE $KeysPressed) {
                    Foreach($KeyInfo in $KeysPressed) {
                        $SelfElement.HandleKey($KeyInfo)
                    }
                }
            }
        })
    }

    [Void]SetProgress(
        [Int]$PositionMs,
        [Int]$DurationMs
    ) {
        [Int]$SafeDuration = [Math]::Max(0, $DurationMs)
        [Int]$SafePosition = ($SafeDuration -GT 0) ? [Math]::Clamp($PositionMs, 0, $SafeDuration) : [Math]::Max(0, $PositionMs)

        If(($this.PositionMs -NE $SafePosition) -OR ($this.DurationMs -NE $SafeDuration)) {
            $this.PositionMs = $SafePosition
            $this.DurationMs = $SafeDuration

            $this.SyncRenderState()
        }
    }

    [Void]SetBarWidth(
        [Int]$BarWidth
    ) {
        [Int]$SafeWidth = [Math]::Max(8, $BarWidth)

        If($this.BarWidth -NE $SafeWidth) {
            $this.BarWidth                      = $SafeWidth
            $this.ProgressBar.BarWidth          = $SafeWidth
            $this.ProgressBar.MaxRenderedLength = 0

            $this.SyncRenderState()
        }
    }

    [Void]SetLayout(
        [ATCoordinates]$DrawCoordinates,
        [Int]$BarWidth
    ) {
        $this.DrawCoordinates = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.BarWidth        = [Math]::Max(8, $BarWidth)

        $this.ProgressBar.SetLayout($this.DrawCoordinates, $this.BarWidth)
        $this.SyncRenderState()
    }

    [Void]SyncRenderState() {
        [String]$ElapsedText = "$(Format-Duration $this.PositionMs) "
        [String]$TotalText   = " $(Format-Duration $this.DurationMs)"
        [Int]$ScaledValue    = 0

        If($this.DurationMs -GT 0) {
            $ScaledValue = [Int][Math]::Clamp([Math]::Round(([Double]$this.PositionMs / [Double]$this.DurationMs) * 1000.0), 0, 1000)
        }

        $this.ProgressBar.DrawCoordinates = [ATCoordinates]::new($this.DrawCoordinates)

        $this.ProgressBar.SetValue($ScaledValue)
        $this.ProgressBar.SetCustomLabels($ElapsedText, $TotalText)

        $this.ProgressBar.Dirty = $true
        $this.Dirty             = $true
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::LeftArrow) {
                If($null -NE $this.OnSeekRequested) {
                    $this.OnSeekRequested.Invoke(-$this.SeekStepMs)
                }

                Break
            }

            ([ConsoleKey]::RightArrow) {
                If($null -NE $this.OnSeekRequested) {
                    $this.OnSeekRequested.Invoke($this.SeekStepMs)
                }

                Break
            }

            Default {
                # IGNORE OTHER KEYS
                Break
            }
        }
    }

    [Void]Activate(
        [Context]$Context
    ) {
        ([UIBase]$this).Activate($Context)
        $this.ProgressBar.Activate($Context)
        $this.SyncRenderState()
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        ([UIBase]$this).Deactivate($Context)
        $this.ProgressBar.Deactivate($Context)
        $this.SyncRenderState()
    }

    [Void]Focus(
        [Context]$Context
    ) {
        ([UIBase]$this).Focus($Context)

        If($this.Behavior.CanHaveFocus -EQ $true) {
            $this.ProgressBar.Focus($Context)
            $this.SyncRenderState()
        }
    }

    [Void]Unfocus(
        [Context]$Context
    ) {
        ([UIBase]$this).Unfocus($Context)
        $this.ProgressBar.Unfocus($Context)
        $this.SyncRenderState()
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)
        $this.ProgressBar.Update($Context)
    }

    [String]ToAnsiControlSequenceString() {
        Return "$($this.ProgressBar.ToAnsiControlSequenceString())"
    }

    [Void]Draw() {
        $this.ProgressBar.Draw()

        $this.Dirty = $false
    }
}
