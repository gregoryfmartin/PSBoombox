using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE DIRECTORY PROMPT
#
# MODAL STATE FOR NAVIGATING DIRECTLY TO A TARGET FILESYSTEM DIRECTORY.
#
###############################################################################

Class PBStateDirectoryPrompt : SMState {
    PBStateDirectoryPrompt() : base('PBStateDirectoryPrompt') {
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

            $Core.PathModal.Configure(
                'Go to Directory',
                'Enter directory path (Esc to cancel):',
                $Core.DirectoryService.CurrentPath,
                'Go'
            )

            $Core.PathModal.OnConfirm = {
                Param(
                    [String]$EnteredPath,
                    [Context]$ConfirmContext
                )

                If($Core.DirectoryService.LoadDirectory($EnteredPath) -EQ $true) {
                    $Core.DirectoryPanel.SyncFromService($Core.DirectoryService, $Core.GetCurrentPlayingPath())
                    $Core.FooterPanel.SetStatus("Directory: $($Core.DirectoryService.CurrentPath)")
                    $Core.AppState.Trigger('CloseDirectoryPrompt', [Context]::new(@{ [SMState]::ContextBoomboxCore = $Core }))
                } Else {
                    $Core.PathModal.SetError($Core.DirectoryService.LastError)
                }
            }.GetNewClosure()

            $Core.PathModal.OnCancel = {
                Param(
                    [Context]$CancelContext
                )

                $Core.FooterPanel.SetStatus('Directory navigation cancelled')
                $Core.AppState.Trigger('CloseDirectoryPrompt', [Context]::new(@{ [SMState]::ContextBoomboxCore = $Core }))
            }.GetNewClosure()

            $Core.PathModal.Activate($Context)
            $Core.PathModal.ClearInterior()
            $Core.PathModal.FocusElementByKey(1, $Context)
            $Core.FooterPanel.SetStatus('Enter target directory path and press Enter')
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            $Core.PathModal.UnfocusAllElements($Context)
            $Core.PathModal.Deactivate($Context)
            $Core.PathModal.ClearBoundingBox()

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

            [PBStateDirectoryPrompt]$SelfState = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                      = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                  = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed  = $Context.References[[SMState]::ContextKeysPressed]
            [List[ConsoleKeyInfo]]$ModalKeys    = [List[ConsoleKeyInfo]]::new()

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    If($KeyInfo.Key -EQ [ConsoleKey]::Escape) {
                        $Core.FooterPanel.SetStatus('Directory navigation cancelled')
                        $Core.AppState.Trigger('CloseDirectoryPrompt', $Context)

                        Return
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
                        If(($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift) {
                            $Core.PathModal.FocusPrevious($Context)
                        } Else {
                            $Core.PathModal.FocusNext($Context)
                        }

                        Continue
                    }

                    $ModalKeys.Add($KeyInfo)
                }
            }

            $Core.MediaPlayer.Update($DeltaTime)
            $Context.References[[SMState]::ContextKeysPressed] = $ModalKeys
            $Core.PathModal.Update($Context)
            $Core.FooterPanel.Update($Context)

            If($null -NE $KeysPressed) {
                $Context.References[[SMState]::ContextKeysPressed] = $KeysPressed
            }

            If($Core.AppState.CurrentState -NE 'PBStateDirectoryPrompt') {
                Return
            }

            Write-Host "$([ATControlSequences]::DrawOptimizeOn)" -NoNewline
            $Core.PlaybackPanel.Draw()
            $Core.DirectoryPanel.Draw()
            $Core.PlaylistPanel.Draw()
            $Core.PathModal.Draw()
            $Core.FooterPanel.Draw()
            Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline
        }
    }
}
