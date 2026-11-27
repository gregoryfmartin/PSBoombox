using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE NOTICE MODAL
#
# MODAL ALERT STATE DISPLAYING INFORMATIONAL DIALOGS (SUCH AS MIDI VISUALIZER
# NOTICE) OVER DIMMED BACKGROUND PANELS.
#
###############################################################################

Class PBStateNoticeModal : SMState {
    PBStateNoticeModal() : base('PBStateNoticeModal') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            If($Core.IsSuspendedForResize -EQ $true) {
                $Core.IsSuspendedForResize           = $false
                $Core.PendingScreenClear             = $true
                $Core.NoticeModal.InteriorClearDirty = $true

                $Core.PlaybackPanel.SetAllElementsDirty()
                $Core.DirectoryPanel.SetAllElementsDirty()
                $Core.PlaylistPanel.SetAllElementsDirty()
                $Core.FooterPanel.SetAllElementsDirty()
                $Core.NoticeModal.SetAllElementsDirty()

                Return
            }

            $Core.EnterAlternateScreen()
            $Core.PlaybackPanel.UnfocusAllElements($Context)
            $Core.DirectoryPanel.UnfocusAllElements($Context)
            $Core.PlaylistPanel.UnfocusAllElements($Context)

            $Core.PlaybackPanel.Deactivate($Context)
            $Core.DirectoryPanel.Deactivate($Context)
            $Core.PlaylistPanel.Deactivate($Context)
            $Core.FooterPanel.Activate($Context)

            $Core.SyncAllPanelsFromState()
            $Core.PlaybackPanel.SetAllElementsDirty()
            $Core.DirectoryPanel.SetAllElementsDirty()
            $Core.PlaylistPanel.SetAllElementsDirty()

            $Core.NoticeModal.OnDismiss = {
                Param(
                    [Context]$DismissContext
                )

                [ScriptBlock]$AfterCallback      = $Core.NoticeModal.OnAfterDismiss
                $Core.NoticeModal.OnAfterDismiss = $null
                $Core.NoticeModal.AllowQuit      = $false

                If($null -NE $AfterCallback) {
                    $AfterCallback.Invoke($DismissContext)
                }

                $Core.FooterPanel.SetStatus('Ready')
                $Core.AppState.Trigger('CloseNoticeModal', [Context]::new(@{ [SMState]::ContextBoomboxCore = $Core }))
            }.GetNewClosure()

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
            $Core.NoticeModal.ClearInterior()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline

            $Core.NoticeModal.Activate($Context)
            $Core.NoticeModal.SetAllElementsDirty()
            $Core.NoticeModal.FocusElementByKey(3, $Context)

            If($Core.NoticeModal.AllowQuit -EQ $true) {
                $Core.FooterPanel.SetStatus('Press [Q] to quit, or Enter/Space/Esc to continue')
            } Else {
                $Core.FooterPanel.SetStatus('Press Enter, Space, or Esc to dismiss')
            }
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

            $Core.NoticeModal.UnfocusAllElements($Context)
            $Core.NoticeModal.Deactivate($Context)
            $Core.NoticeModal.ClearBoundingBox()

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

            [PBStateNoticeModal]$SelfState     = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                     = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                 = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]
            [List[ConsoleKeyInfo]]$ModalKeys   = [List[ConsoleKeyInfo]]::new()

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    If(($Core.NoticeModal.AllowQuit -EQ $true) -AND ($KeyInfo.Key -EQ [ConsoleKey]::Q)) {
                        $Core.NoticeModal.OnAfterDismiss = $null
                        $Core.NoticeModal.AllowQuit      = $false

                        $Core.AppState.Trigger('Quit', $Context)

                        Return
                    }

                    If(($KeyInfo.Key -EQ [ConsoleKey]::Escape) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Enter) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Spacebar)) {
                        If($null -NE $Core.NoticeModal.OnDismiss) {
                            $Core.NoticeModal.OnDismiss.Invoke($Context)
                        } Else {
                            $Core.FooterPanel.SetStatus('Ready')
                            $Core.AppState.Trigger('CloseNoticeModal', $Context)
                        }

                        Return
                    }

                    $ModalKeys.Add($KeyInfo)
                }
            }

            $Core.MediaPlayer.Update($DeltaTime)
            $Context.References[[SMState]::ContextKeysPressed] = $ModalKeys
            $Core.NoticeModal.Update($Context)
            $Core.FooterPanel.Update($Context)

            If($null -NE $KeysPressed) {
                $Context.References[[SMState]::ContextKeysPressed] = $KeysPressed
            }

            If($Core.AppState.CurrentState -NE 'PBStateNoticeModal') {
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
            $Core.NoticeModal.Draw()
            $Core.FooterPanel.Draw()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline
        }
    }
}
