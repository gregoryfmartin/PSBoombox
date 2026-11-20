using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE EQUALIZER
#
# MODAL STATE FOR TUNING THE 10-BAND ISO EQUALIZER, PREAMP, BUILT-IN PRESETS,
# AND CUSTOM USER PRESETS.
#
###############################################################################

Class PBStateEqualizer : SMState {
    PBStateEqualizer() : base('PBStateEqualizer') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            $Core.PlaybackPanel.UnfocusAllElements($Context)
            $Core.DirectoryPanel.UnfocusAllElements($Context)
            $Core.PlaylistPanel.UnfocusAllElements($Context)

            $Core.PlaybackPanel.Deactivate($Context)
            $Core.DirectoryPanel.Deactivate($Context)
            $Core.PlaylistPanel.Deactivate($Context)

            Write-Host "$([ATControlSequences]::DrawOptimizeOn)" -NoNewline
            $Core.PlaybackPanel.Draw()
            $Core.DirectoryPanel.Draw()
            $Core.PlaylistPanel.Draw()
            $Core.EqualizerModal.ClearInterior()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline

            $Core.EqualizerModal.InlineStatusOverride = ''
            $Core.EqualizerModal.IsNamingPreset       = $false
            $Core.EqualizerModal.SyncFromService($Core.EqualizerService)
            $Core.EqualizerModal.Activate($Context)
            $Core.EqualizerModal.SetAllElementsDirty()
            $Core.EqualizerModal.FocusElementByKey(11, $Context)
            $Core.FooterPanel.SetStatus('Equalizer: adjust bands with Arrow keys or press T to toggle On/Off')
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            If($Core.EqualizerModal.IsNamingPreset -EQ $true) {
                $Core.EqualizerModal.IsNamingPreset = $false

                If($Core.EqualizerModal.PresetNameInput.IsFocused() -EQ $true) {
                    $Core.EqualizerModal.PresetNameInput.Unfocus($Context)
                }

                If($Core.EqualizerModal.ConfirmSaveButton.IsFocused() -EQ $true) {
                    $Core.EqualizerModal.ConfirmSaveButton.Unfocus($Context)
                }

                If($Core.EqualizerModal.CancelSaveButton.IsFocused() -EQ $true) {
                    $Core.EqualizerModal.CancelSaveButton.Unfocus($Context)
                }

                $Core.EqualizerModal.SavePromptLabel.Deactivate($Context)
                $Core.EqualizerModal.PresetNameInput.Deactivate($Context)
                $Core.EqualizerModal.ConfirmSaveButton.Deactivate($Context)
                $Core.EqualizerModal.CancelSaveButton.Deactivate($Context)
            }

            $Core.EqualizerModal.UnfocusAllElements($Context)
            $Core.EqualizerModal.Deactivate($Context)
            $Core.EqualizerModal.ClearBoundingBox()

            $Core.PlaybackPanel.SetAllElementsDirty()
            $Core.DirectoryPanel.SetAllElementsDirty()
            $Core.PlaylistPanel.SetAllElementsDirty()
            $Core.FooterPanel.SetAllElementsDirty()
            $Core.SyncAllPanelsFromState()
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [PBStateEqualizer]$SelfState       = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                     = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                 = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    [Boolean]$StayOpen = $Core.EqualizerModal.HandleModalKey($KeyInfo, $Context, $Core.EqualizerService)

                    If(($StayOpen -EQ $false) -OR ($Core.AppState.CurrentState -NE 'PBStateEqualizer')) {
                        Return
                    }
                }
            }

            $Core.MediaPlayer.Update($DeltaTime)
            $Core.EqualizerModal.SyncFromService($Core.EqualizerService)

            [List[ConsoleKeyInfo]]$EmptyKeys                  = [List[ConsoleKeyInfo]]::new()
            $Context.References[[SMState]::ContextKeysPressed] = $EmptyKeys

            $Core.EqualizerModal.Update($Context)
            $Core.FooterPanel.Update($Context)

            If($null -NE $KeysPressed) {
                $Context.References[[SMState]::ContextKeysPressed] = $KeysPressed
            }

            If($Core.AppState.CurrentState -NE 'PBStateEqualizer') {
                Return
            }

            Write-Host "$([ATControlSequences]::DrawOptimizeOn)" -NoNewline
            $Core.PlaybackPanel.Draw()
            $Core.DirectoryPanel.Draw()
            $Core.PlaylistPanel.Draw()
            $Core.EqualizerModal.Draw()
            $Core.FooterPanel.Draw()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline
        }
    }
}
