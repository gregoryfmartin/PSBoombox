using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI VOLUME CONTROL
#
# A FOCUSABLE VOLUME BAR AND MUTE CONTROL COMPOSING A CLAMPABLEINT AND A
# UIPROGRESSBAR.
#
###############################################################################

Class UIVolumeControl : UIBase {
    Static [Int]$DefaultVolume   = 70
    Static [Int]$DefaultStep     = 5
    Static [Int]$DefaultBarWidth = 10

    [ClampableInt]$Volume
    [Int]$Step
    [Boolean]$IsMuted
    [UIProgressBar]$VolumeBar
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnVolumeChanged
    [ScriptBlock]$OnMuteToggled

    UIVolumeControl() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            [UIVolumeControl]::DefaultVolume,
            [UIVolumeControl]::DefaultStep,
            [UIVolumeControl]::DefaultBarWidth
        )
    }

    UIVolumeControl(
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            [UIVolumeControl]::DefaultVolume,
            [UIVolumeControl]::DefaultStep,
            [UIVolumeControl]::DefaultBarWidth
        )
    }

    UIVolumeControl(
        [ATCoordinates]$DrawCoordinates,
        [Int]$InitialVolume,
        [Int]$Step,
        [Int]$BarWidth
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $InitialVolume,
            $Step,
            $BarWidth
        )
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [Int]$InitialVolume,
        [Int]$Step,
        [Int]$BarWidth
    ) {
        [ATCoordinates]$SafeCoords = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        [Int]$SafeBarWidth         = [Math]::Max(4, $BarWidth)

        $this.DrawCoordinates       = $SafeCoords
        $this.Volume                = [ClampableInt]::new($InitialVolume, 0, 100)
        $this.Step                  = [Math]::Max(1, $Step)
        $this.IsMuted               = $false
        $this.OnVolumeChanged       = $null
        $this.OnMuteToggled         = $null
        $this.UseATReset            = $true
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true
        $this.VolumeBar             = [UIProgressBar]::new(
            [ATCoordinates]::new($SafeCoords.Row.Value, ($SafeCoords.Column.Value + 4)),
            $this.Volume.Value,
            0,
            100,
            $SafeBarWidth
        )
        $this.VolumeBar.ShowNumericText = $false

        $this.SyncRenderState()
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIVolumeControl]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIVolumeControl]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIVolumeControl]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UIVolumeControl]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.SyncRenderState()
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UIVolumeControl]$SelfElement      = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                If($null -NE $KeysPressed) {
                    Foreach($KeyInfo in $KeysPressed) {
                        $SelfElement.HandleKey($KeyInfo)
                    }
                }
            }
        })
    }

    [Void]SetLayout(
        [ATCoordinates]$DrawCoordinates,
        [Int]$BarWidth
    ) {
        [ATCoordinates]$SafeCoords = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        [Int]$SafeBarWidth         = [Math]::Max(4, $BarWidth)
        $this.DrawCoordinates      = $SafeCoords

        $this.VolumeBar.SetLayout([ATCoordinates]::new($SafeCoords.Row.Value, ($SafeCoords.Column.Value + 4)), $SafeBarWidth)
        $this.SyncRenderState()
    }

    [Void]SetVolume(
        [Int]$Percent
    ) {
        [Int]$Previous = $this.Volume.Value

        $this.Volume.SetValue($Percent)

        If($this.Volume.Value -NE $Previous) {
            $this.SyncRenderState()

            If($null -NE $this.OnVolumeChanged) {
                $this.OnVolumeChanged.Invoke($this.Volume.Value)
            }
        }
    }

    [Void]AdjustVolume(
        [Int]$Delta
    ) {
        $this.SetVolume($this.Volume.Value + $Delta)
    }

    [Void]SetMuted(
        [Boolean]$Muted
    ) {
        If($this.IsMuted -NE $Muted) {
            $this.IsMuted = $Muted

            $this.SyncRenderState()

            If($null -NE $this.OnMuteToggled) {
                $this.OnMuteToggled.Invoke($this.IsMuted)
            }
        }
    }

    [Void]ToggleMute() {
        $this.SetMuted(($this.IsMuted -EQ $false))
    }

    [Void]SyncFromState(
        [Int]$Percent,
        [Boolean]$Muted
    ) {
        [Int]$Clamped = [Math]::Clamp($Percent, 0, 100)

        If(($this.Volume.Value -NE $Clamped) -OR ($this.IsMuted -NE $Muted)) {
            $this.Volume.SetValue($Clamped)

            $this.IsMuted = $Muted

            $this.SyncRenderState()
        }
    }

    [Void]SyncRenderState() {
        [Int]$EffectivePercent = ($this.IsMuted -EQ $true) ? 0 : $this.Volume.Value
        [String]$LabelToken    = ($this.IsMuted -EQ $true) ? 'MUT' : 'VOL'
        [String]$PercentText   = " $($EffectivePercent.ToString().PadLeft(3, ' '))%"
        [TrueColor]$BarColor   = [ColorLibrary]::BoomboxVolumeSafe

        If($this.IsMuted -EQ $true) {
            $BarColor = [ColorLibrary]::BoomboxVolumeMuted
        } Elseif($EffectivePercent -GT 80) {
            $BarColor = [ColorLibrary]::BoomboxVolumeHigh
        }

        $this.VolumeBar.DrawCoordinates = [ATCoordinates]::new($this.DrawCoordinates.Row.Value, ($this.DrawCoordinates.Column.Value + 4))
        $this.VolumeBar.FilledColor     = $BarColor

        $this.VolumeBar.SetValue($EffectivePercent)
        $this.VolumeBar.SetCustomLabels('', $PercentText)

        [TrueColor]$BadgeColor = [ColorLibrary]::UILabelInactive

        If($this.IsFocused() -EQ $true) {
            $BadgeColor = [ColorLibrary]::BoomboxBorderFocused
        } Elseif($this.IsActive() -EQ $true) {
            $BadgeColor = ($this.IsMuted -EQ $true) ? [ColorLibrary]::BoomboxVolumeMuted : [ColorLibrary]::UILabelActive
        }

        $this.Prefix.Coordinates     = [ATCoordinates]::new($this.DrawCoordinates)
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new($BadgeColor)

        $this.SetBlankSize(4)
        $this.SetUserData("$($LabelToken) ")

        $this.VolumeBar.Dirty = $true
        $this.Dirty           = $true
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::Add) {
                $this.AdjustVolume($this.Step)

                Break
            }

            ([ConsoleKey]::OemPlus) {
                $this.AdjustVolume($this.Step)

                Break
            }

            ([ConsoleKey]::Subtract) {
                $this.AdjustVolume(-$this.Step)

                Break
            }

            ([ConsoleKey]::OemMinus) {
                $this.AdjustVolume(-$this.Step)

                Break
            }

            ([ConsoleKey]::UpArrow) {
                $this.AdjustVolume($this.Step)

                Break
            }

            ([ConsoleKey]::DownArrow) {
                $this.AdjustVolume(-$this.Step)

                Break
            }

            ([ConsoleKey]::M) {
                $this.ToggleMute()

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
        $this.VolumeBar.Activate($Context)
        $this.SyncRenderState()
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        ([UIBase]$this).Deactivate($Context)
        $this.VolumeBar.Deactivate($Context)
        $this.SyncRenderState()
    }

    [Void]Focus(
        [Context]$Context
    ) {
        ([UIBase]$this).Focus($Context)

        If($this.Behavior.CanHaveFocus -EQ $true) {
            $this.VolumeBar.Focus($Context)
            $this.SyncRenderState()
        }
    }

    [Void]Unfocus(
        [Context]$Context
    ) {
        ([UIBase]$this).Unfocus($Context)
        $this.VolumeBar.Unfocus($Context)
        $this.SyncRenderState()
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)
        $this.VolumeBar.Update($Context)
    }

    [String]ToAnsiControlSequenceString() {
        Return "$(([UIBase]$this).ToAnsiControlSequenceString())$($this.VolumeBar.ToAnsiControlSequenceString())"
    }

    [Void]Draw() {
        If($this.Dirty -EQ $true) {
            Write-Host "$(([UIBase]$this).ToAnsiControlSequenceString())" -NoNewline

            $this.Dirty = $false
        }

        $this.VolumeBar.Draw()
    }
}
