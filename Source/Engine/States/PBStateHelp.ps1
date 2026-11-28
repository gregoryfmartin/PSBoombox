using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE HELP
#
# MODAL STATE DISPLAYING THE TABBED KEYBOARD SHORTCUT HELP DIALOG OVER THE
# MAIN PLAYER SCREEN WHILE PLAYBACK CONTINUES SMOOTHLY.
#
###############################################################################

Class PBStateHelp : SMState {
    PBStateHelp() : base('PBStateHelp') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            If($Core.IsSuspendedForResize -EQ $true) {
                $Core.IsSuspendedForResize = $false
                $Core.PendingScreenClear   = $true

                $Core.PlaybackPanel.SetAllElementsDirty()
                $Core.DirectoryPanel.SetAllElementsDirty()
                $Core.PlaylistPanel.SetAllElementsDirty()
                $Core.FooterPanel.SetAllElementsDirty()
                $Core.HelpModal.MarkAllDirtyForThemeChange()

                Return
            }

            $Core.PlaybackPanel.UnfocusAllElements($Context)
            $Core.DirectoryPanel.UnfocusAllElements($Context)
            $Core.PlaylistPanel.UnfocusAllElements($Context)

            $Core.PlaybackPanel.SetFocusedBorderHighlight($false)
            $Core.DirectoryPanel.SetFocusedBorderHighlight($false)
            $Core.PlaylistPanel.SetFocusedBorderHighlight($false)

            $Core.PlaybackPanel.SetAllElementsDirty()
            $Core.DirectoryPanel.SetAllElementsDirty()
            $Core.PlaylistPanel.SetAllElementsDirty()

            $Core.PendingScreenClear = $true

            $Core.HelpModal.OpenHelp($Context)
            $Core.FooterPanel.SetStatus('Help')
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            If($Core.IsSuspendedForResize -EQ $true) {
                Return
            }

            $Core.HelpModal.Deactivate($Context)
            $Core.HelpModal.ClearBoundingBox()

            $Core.PendingScreenClear = $true

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

            [PBStateHelp]$SelfState            = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                     = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                 = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    [Boolean]$StayOpen = $Core.HelpModal.HandleModalKey($KeyInfo, $Context)

                    If(($StayOpen -EQ $false) -OR ($Core.AppState.CurrentState -NE 'PBStateHelp')) {
                        Return
                    }
                }
            }

            $Core.MediaPlayer.Update($DeltaTime)
            $Core.PlaybackPanel.SyncFromPlayer($Core.MediaPlayer, $Core.Playlist)

            [List[ConsoleKeyInfo]]$EmptyKeys                  = [List[ConsoleKeyInfo]]::new()
            $Context.References[[SMState]::ContextKeysPressed] = $EmptyKeys

            $Core.HelpModal.Update($Context)
            $Core.FooterPanel.Update($Context)

            If($null -NE $KeysPressed) {
                $Context.References[[SMState]::ContextKeysPressed] = $KeysPressed
            }

            If($Core.AppState.CurrentState -NE 'PBStateHelp') {
                Return
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
            $Core.HelpModal.Draw()
            $Core.FooterPanel.Draw()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline
        }
    }
}
