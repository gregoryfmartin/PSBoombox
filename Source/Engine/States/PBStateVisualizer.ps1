using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE VISUALIZER
#
# FULL-BUFFER REAL-TIME AUDIO VISUALIZER SCREEN WITH FORWARD-ONLY TAB CYCLING,
# BOTTOM-LEFT TRACK LABEL, INSTRUCTIONS ROW, AND ACTIVE GLOBAL MEDIA KEYS.
#
###############################################################################

Class PBStateVisualizer : SMState {
    PBStateVisualizer() : base('PBStateVisualizer') {
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
            $Core.FooterPanel.Deactivate($Context)

            If([Console]::IsOutputRedirected -EQ $false) {
                Clear-Host
            }

            $Core.VisualizerCanvas.InvalidateAll()
            $Core.SetTargetFps(60)

            [UIVisualizerBase]$ActiveViz = $Core.GetActiveVisualizer()

            If($null -NE $ActiveViz) {
                $ActiveViz.Reset()
            }

            $Core.VisualizerTrackLabel.Activate($Context)
            $Core.VisualizerHintLabel.Activate($Context)
            $Core.SyncVisualizerTrackLabel()

            $Core.VisualizerTrackLabel.Dirty = $true
            $Core.VisualizerHintLabel.Dirty  = $true
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            $Core.SetTargetFps(30)
            $Core.VisualizerTrackLabel.Deactivate($Context)
            $Core.VisualizerHintLabel.Deactivate($Context)

            If([Console]::IsOutputRedirected -EQ $false) {
                Clear-Host
            } Else {
                $Core.VisualizerCanvas.ClearScreenBuffer()
            }

            $Core.PlaybackPanel.SetAllElementsDirty()
            $Core.DirectoryPanel.SetAllElementsDirty()
            $Core.PlaylistPanel.SetAllElementsDirty()
            $Core.FooterPanel.SetAllElementsDirty()
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [PBStateVisualizer]$SelfState      = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                     = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                 = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]
            [Boolean]$DidTransition            = $false

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    If($KeyInfo.Key -EQ [ConsoleKey]::Q) {
                        $Core.AppState.Trigger('Quit', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::V) {
                        $Core.FooterPanel.SetStatus('Returned to Playlist Mode')
                        $Core.AppState.Trigger('CloseVisualizer', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
                        If(($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -NE [ConsoleModifiers]::Shift) {
                            $Core.CycleVisualizerForward()
                        }

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::Spacebar) {
                        $Core.TogglePlayPause()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::N) {
                        $Core.PlayNextTrack($true)

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::P) {
                        $Core.PlayPreviousTrack()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::S) {
                        $Core.StopPlayback()
                        $Core.AppState.Trigger('CloseVisualizer', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If(($KeyInfo.Key -EQ [ConsoleKey]::Add) -OR ($KeyInfo.Key -EQ [ConsoleKey]::OemPlus)) {
                        $Core.AdjustVolume(5)

                        Continue
                    }

                    If(($KeyInfo.Key -EQ [ConsoleKey]::Subtract) -OR ($KeyInfo.Key -EQ [ConsoleKey]::OemMinus)) {
                        $Core.AdjustVolume(-5)

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::M) {
                        $Core.ToggleMute()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::R) {
                        $Core.CycleRepeatMode()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::H) {
                        $Core.ToggleShuffle()

                        Continue
                    }
                }
            }

            If($DidTransition -EQ $true) {
                Return
            }

            $Core.MediaPlayer.Update($DeltaTime)

            If($Core.MediaPlayer.IsStopped() -EQ $true) {
                $Core.FooterPanel.SetStatus('Playback stopped. Returned to Playlist Mode.')
                $Core.AppState.Trigger('CloseVisualizer', $Context)

                Return
            }

            If($Core.MediaPlayer.IsEqualizerBypassedForCurrentTrack() -EQ $true) {
                $Core.OpenMidiVisualizerNotice($Context, 'VisualizerToNoticeModal')

                Return
            }

            $Core.SyncVisualizerTrackLabel()

            [List[ConsoleKeyInfo]]$EmptyKeys                  = [List[ConsoleKeyInfo]]::new()
            $Context.References[[SMState]::ContextKeysPressed] = $EmptyKeys

            $Core.VisualizerTrackLabel.Update($Context)
            $Core.VisualizerHintLabel.Update($Context)

            If($null -NE $KeysPressed) {
                $Context.References[[SMState]::ContextKeysPressed] = $KeysPressed
            }

            If($Core.AppState.CurrentState -NE 'PBStateVisualizer') {
                Return
            }

            [UIVisualizerBase]$ActiveViz = $Core.GetActiveVisualizer()

            If($null -NE $ActiveViz) {
                [Int]$SpecBins      = [Math]::Max(32, $Core.VisualizerCanvas.Width)
                [Int]$WaveCount     = [Math]::Max(64, ($Core.VisualizerCanvas.Width * 2))
                [Single[]]$Spectrum = $Core.MediaPlayer.GetSpectrumSnapshot($SpecBins)
                [Single[]]$Waveform = $Core.MediaPlayer.GetWaveformSnapshot($WaveCount)
                [Single[]]$Metrics  = $Core.MediaPlayer.GetAudioMetrics()

                $ActiveViz.RenderFrame($Core.VisualizerCanvas, $Spectrum, $Waveform, $Metrics, $DeltaTime)
            }

            [String]$TrailingAnsi = ''

            If($Core.VisualizerTrackLabel.Dirty -EQ $true) {
                $TrailingAnsi                     += $Core.VisualizerTrackLabel.ToAnsiControlSequenceString()
                $Core.VisualizerTrackLabel.Dirty   = $false
            }

            If($Core.VisualizerHintLabel.Dirty -EQ $true) {
                $TrailingAnsi                    += $Core.VisualizerHintLabel.ToAnsiControlSequenceString()
                $Core.VisualizerHintLabel.Dirty   = $false
            }

            $Core.VisualizerCanvas.DrawFrame($true, $TrailingAnsi)
        }
    }
}
