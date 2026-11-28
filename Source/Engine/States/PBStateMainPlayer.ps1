using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE MAIN PLAYER
#
# PRIMARY INTERACTIVE TUI SCREEN MANAGING PLAYBACK CONTROLS, DIRECTORY BROWSER,
# PLAYLIST PANEL, KEYBOARD ROUTING, AND SYNCHRONIZED ANSI RENDERING.
#
###############################################################################

Class PBStateMainPlayer : SMState {
    PBStateMainPlayer() : base('PBStateMainPlayer') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            $Core.EnterAlternateScreen()

            $Core.IsSuspendedForResize = $false
            $Core.PendingScreenClear   = $true

            $Core.PlaybackPanel.Activate($Context)
            $Core.DirectoryPanel.Activate($Context)
            $Core.PlaylistPanel.Activate($Context)
            $Core.FooterPanel.Activate($Context)

            $Core.PlaybackPanel.SetAllElementsDirty()
            $Core.DirectoryPanel.SetAllElementsDirty()
            $Core.PlaylistPanel.SetAllElementsDirty()
            $Core.FooterPanel.SetAllElementsDirty()

            [BoomboxFocusZone]$StartZone = ($Core.AutoFocusPlaylistOnStart -EQ $true) ? [BoomboxFocusZone]::Playlist : $Core.ActiveFocusZone
            $Core.AutoFocusPlaylistOnStart = $false

            $Core.SetFocusZone($StartZone, $Context)
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [PBStateMainPlayer]$SelfState      = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                     = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                 = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]
            [List[ConsoleKeyInfo]]$ChildKeys   = [List[ConsoleKeyInfo]]::new()
            [Boolean]$DidTransition            = $false

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    If(($KeyInfo.Key -EQ [ConsoleKey]::Q) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Escape)) {
                        $Core.AppState.Trigger('Quit', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If(($KeyInfo.Key -EQ [ConsoleKey]::G) -OR ($KeyInfo.Key -EQ [ConsoleKey]::F2)) {
                        $Core.AppState.Trigger('OpenDirectoryPrompt', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::W) {
                        $Core.AppState.Trigger('OpenSavePlaylistPrompt', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::E) {
                        $Core.AppState.Trigger('OpenEqualizer', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::T) {
                        $Core.AppState.Trigger('OpenThemeSelector', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::F1) {
                        $Core.AppState.Trigger('OpenHelp', $Context)
                        $DidTransition = $true

                        Break
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::V) {
                        $Core.TryOpenVisualizer($Context)

                        If($Core.AppState.CurrentState -NE 'PBStateMainPlayer') {
                            $DidTransition = $true

                            Break
                        }

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
                        [Boolean]$Reverse = (($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift)
                        $Core.CycleFocusZone($Reverse, $Context)

                        Continue
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

                    If($KeyInfo.Key -EQ [ConsoleKey]::B) {
                        $Core.ToggleNotifications()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::Spacebar) {
                        [UIBase]$FocusedControl = $Core.PlaybackPanel.GetFocusedElement()

                        If(($Core.ActiveFocusZone -EQ [BoomboxFocusZone]::PlaybackControls) -AND ($FocusedControl -IS [UIButton])) {
                            $ChildKeys.Add($KeyInfo)
                        } Else {
                            $Core.TogglePlayPause()
                        }

                        Continue
                    }

                    If($Core.ActiveFocusZone -EQ [BoomboxFocusZone]::DirectoryBrowser) {
                        If($KeyInfo.Key -EQ [ConsoleKey]::Backspace) {
                            $Core.NavigateDirectoryUp()

                            Continue
                        }

                        If($KeyInfo.Key -EQ [ConsoleKey]::A) {
                            $Core.AddSelectedDirectoryTrackToPlaylist()

                            Continue
                        }

                        $ChildKeys.Add($KeyInfo)

                        Continue
                    }

                    If($Core.ActiveFocusZone -EQ [BoomboxFocusZone]::Playlist) {
                        If(($KeyInfo.Key -EQ [ConsoleKey]::Delete) -OR ($KeyInfo.Key -EQ [ConsoleKey]::X)) {
                            $Core.RemoveSelectedPlaylistTrack()

                            Continue
                        }

                        If($KeyInfo.Key -EQ [ConsoleKey]::C) {
                            $Core.ClearPlaylist()

                            Continue
                        }

                        If(($KeyInfo.Key -EQ [ConsoleKey]::U) -OR (($KeyInfo.Key -EQ [ConsoleKey]::UpArrow) -AND (($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift))) {
                            $Core.MoveSelectedPlaylistTrackUp()

                            Continue
                        }

                        If(($KeyInfo.Key -EQ [ConsoleKey]::J) -OR (($KeyInfo.Key -EQ [ConsoleKey]::DownArrow) -AND (($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift))) {
                            $Core.MoveSelectedPlaylistTrackDown()

                            Continue
                        }

                        $ChildKeys.Add($KeyInfo)

                        Continue
                    }

                    If($Core.ActiveFocusZone -EQ [BoomboxFocusZone]::PlaybackControls) {
                        If($Core.PlaybackPanel.HandleZoneNavigationKey($KeyInfo, $Context) -EQ $false) {
                            $ChildKeys.Add($KeyInfo)
                        }

                        Continue
                    }
                }
            }

            If($DidTransition -EQ $true) {
                Return
            }

            $Core.MediaPlayer.Update($DeltaTime)
            $Core.PlaybackPanel.SyncFromPlayer($Core.MediaPlayer, $Core.Playlist)

            [List[ConsoleKeyInfo]]$EmptyKeys = [List[ConsoleKeyInfo]]::new()

            If($Core.ActiveFocusZone -EQ [BoomboxFocusZone]::PlaybackControls) {
                $Context.References[[SMState]::ContextKeysPressed] = $ChildKeys
                $Core.PlaybackPanel.Update($Context)
                $Context.References[[SMState]::ContextKeysPressed] = $EmptyKeys
                $Core.DirectoryPanel.Update($Context)
                $Core.PlaylistPanel.Update($Context)
            } Elseif($Core.ActiveFocusZone -EQ [BoomboxFocusZone]::DirectoryBrowser) {
                $Context.References[[SMState]::ContextKeysPressed] = $ChildKeys
                $Core.DirectoryPanel.Update($Context)
                $Context.References[[SMState]::ContextKeysPressed] = $EmptyKeys
                $Core.PlaybackPanel.Update($Context)
                $Core.PlaylistPanel.Update($Context)
            } Else {
                $Context.References[[SMState]::ContextKeysPressed] = $ChildKeys
                $Core.PlaylistPanel.Update($Context)
                $Context.References[[SMState]::ContextKeysPressed] = $EmptyKeys
                $Core.PlaybackPanel.Update($Context)
                $Core.DirectoryPanel.Update($Context)
            }

            $Core.FooterPanel.Update($Context)

            If($null -NE $KeysPressed) {
                $Context.References[[SMState]::ContextKeysPressed] = $KeysPressed
            }

            Write-Host "$([ATControlSequences]::DrawOptimizeOn)" -NoNewline

            If($Core.PendingScreenClear -EQ $true) {
                If([Console]::IsOutputRedirected -EQ $false) {
                    Write-Host "$([ATControlSequences]::GenerateThemeClearScreenString())" -NoNewline
                }

                $Core.PendingScreenClear = $false
            }

            $Core.PlaybackPanel.Draw()
            $Core.DirectoryPanel.Draw()
            $Core.PlaylistPanel.Draw()
            $Core.FooterPanel.Draw()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline
        }
    }
}
