using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE PLAYLIST SAVE PROMPT
#
# MODAL STATE FOR SAVING THE ACTIVE PLAYLIST TO .M3U, .M3U8, .PLS, OR .WPL.
#
###############################################################################

Class PBStatePlaylistSavePrompt : SMState {
    PBStatePlaylistSavePrompt() : base('PBStatePlaylistSavePrompt') {
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

            [String]$DefaultPath = ($Core.Playlist.SourceFilePath.Length -GT 0) ? $Core.Playlist.SourceFilePath : [Path]::Combine($Core.DirectoryService.CurrentPath, 'playlist.m3u8')

            $Core.PathModal.Configure(
                'Save Playlist',
                'Save path (.m3u, .m3u8, .pls, .wpl):',
                $DefaultPath,
                'Save'
            )

            $Core.PathModal.OnConfirm = {
                Param(
                    [String]$EnteredPath,
                    [Context]$ConfirmContext
                )

                [Hashtable]$SaveResult = [MMPlaylistFileService]::SavePlaylist($EnteredPath, $Core.Playlist.Tracks)

                If($SaveResult.Success -EQ $true) {
                    $Core.Playlist.PlaylistName   = [Path]::GetFileNameWithoutExtension($SaveResult.SavedPath)
                    $Core.Playlist.SourceFilePath = $SaveResult.SavedPath

                    $null = $Core.DirectoryService.Refresh()

                    $Core.DirectoryPanel.SyncFromService($Core.DirectoryService, $Core.GetCurrentPlayingPath())
                    $Core.PlaylistPanel.SyncFromPlaylist($Core.Playlist, $Core.PlaylistPanel.GetSelectedTrackIndex())
                    $Core.FooterPanel.SetStatus("Saved $($SaveResult.TrackCount) tracks to '$($SaveResult.SavedPath)'")
                    $Core.AppState.Trigger('CloseSavePlaylistPrompt', [Context]::new(@{ [SMState]::ContextBoomboxCore = $Core }))
                } Else {
                    $Core.PathModal.SetError($SaveResult.ErrorMessage)
                }
            }.GetNewClosure()

            $Core.PathModal.OnCancel = {
                Param(
                    [Context]$CancelContext
                )

                $Core.FooterPanel.SetStatus('Playlist save cancelled')
                $Core.AppState.Trigger('CloseSavePlaylistPrompt', [Context]::new(@{ [SMState]::ContextBoomboxCore = $Core }))
            }.GetNewClosure()

            $Core.PathModal.Activate($Context)
            $Core.PathModal.ClearInterior()
            $Core.PathModal.FocusElementByKey(1, $Context)
            $Core.FooterPanel.SetStatus('Enter playlist file path and press Enter')
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

            [PBStatePlaylistSavePrompt]$SelfState = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                         = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                     = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed     = $Context.References[[SMState]::ContextKeysPressed]
            [List[ConsoleKeyInfo]]$ModalKeys       = [List[ConsoleKeyInfo]]::new()

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    If($KeyInfo.Key -EQ [ConsoleKey]::Escape) {
                        $Core.FooterPanel.SetStatus('Playlist save cancelled')
                        $Core.AppState.Trigger('CloseSavePlaylistPrompt', $Context)

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

            If($Core.AppState.CurrentState -NE 'PBStatePlaylistSavePrompt') {
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
