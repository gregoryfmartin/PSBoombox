using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# BOOMBOX CORE
#
# APPLICATION CORE COORDINATING MEDIA SERVICES, PANELS, FOCUS ZONES, AND
# APPLICATION STATES FOR PSBOOMBOX.
#
###############################################################################

Class BoomboxCore : AppCore {
    [String]$InitialPath
    [String]$InitialPlaylistPath
    [Int]$LayoutWidth
    [Int]$LayoutHeight
    [MMDirectoryService]$DirectoryService
    [MMPlaylist]$Playlist
    [MMMediaPlayer]$MediaPlayer
    [UIPlaybackControlPanel]$PlaybackPanel
    [UIDirectoryBrowserPanel]$DirectoryPanel
    [UIPlaylistPanel]$PlaylistPanel
    [UIPathInputModal]$PathModal
    [UIStatusFooterPanel]$FooterPanel
    [BoomboxFocusZone]$ActiveFocusZone
    [Boolean]$AutoFocusPlaylistOnStart
    [String]$PendingStartupStatus
    [Boolean]$PendingStartupError

    BoomboxCore() : base() {
        $this.InitializeCore((Get-Location).Path, '')
    }

    BoomboxCore(
        [String]$InitialPath
    ) : base() {
        $this.InitializeCore($InitialPath, '')
    }

    BoomboxCore(
        [String]$InitialPath,
        [String]$InitialPlaylistPath
    ) : base() {
        $this.InitializeCore($InitialPath, $InitialPlaylistPath)
    }

    [Void]InitializeCore(
        [String]$InitialPath,
        [String]$InitialPlaylistPath
    ) {
        $this.InitialPath              = (($null -NE $InitialPath) -AND ($InitialPath.Length -GT 0)) ? $InitialPath : (Get-Location).Path
        $this.InitialPlaylistPath      = ($null -EQ $InitialPlaylistPath) ? '' : $InitialPlaylistPath
        $this.DirectoryService         = [MMDirectoryService]::new()
        $this.Playlist                 = [MMPlaylist]::new()
        $this.MediaPlayer              = [MMMediaPlayer]::new()
        $this.ActiveFocusZone          = [BoomboxFocusZone]::DirectoryBrowser
        $this.AutoFocusPlaylistOnStart = $false
        $this.PendingStartupStatus     = 'Ready'
        $this.PendingStartupError      = $false

        $this.ComputeLayoutBounds()
        $this.InitializeUiComponents()
    }

    [Void]ComputeLayoutBounds() {
        If([Console]::IsOutputRedirected -EQ $false) {
            $this.LayoutWidth  = [Math]::Clamp([Console]::WindowWidth, 80, 160)
            $this.LayoutHeight = [Math]::Clamp([Console]::WindowHeight, 24, 50)
        } Else {
            $this.LayoutWidth  = 100
            $this.LayoutHeight = 28
        }

        [ATCoordinates]::SetBounds(($this.LayoutHeight + 4), ($this.LayoutWidth + 4))
    }

    [Void]InitializeUiComponents() {
        [Int]$BottomTopRow  = 6
        [Int]$BottomEndRow  = $this.LayoutHeight - 2
        [Int]$LeftPaneWidth = [Int][Math]::Floor($this.LayoutWidth / 2)

        $this.PlaybackPanel  = [UIPlaybackControlPanel]::new($this.LayoutWidth)
        $this.DirectoryPanel = [UIDirectoryBrowserPanel]::new($BottomTopRow, $BottomEndRow, 1, $LeftPaneWidth)
        $this.PlaylistPanel  = [UIPlaylistPanel]::new($BottomTopRow, $BottomEndRow, ($LeftPaneWidth + 1), $this.LayoutWidth)
        $this.PathModal      = [UIPathInputModal]::new($this.LayoutWidth, $this.LayoutHeight)
        $this.FooterPanel    = [UIStatusFooterPanel]::new(($this.LayoutHeight - 1), $this.LayoutWidth)

        [BoomboxCore]$SelfCore = $this

        $this.PlaybackPanel.OnPrevClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.PlayPreviousTrack()
        }.GetNewClosure()

        $this.PlaybackPanel.OnPlayPauseClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.TogglePlayPause()
        }.GetNewClosure()

        $this.PlaybackPanel.OnStopClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.StopPlayback()
        }.GetNewClosure()

        $this.PlaybackPanel.OnNextClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.PlayNextTrack($true)
        }.GetNewClosure()

        $this.PlaybackPanel.OnRepeatClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.CycleRepeatMode()
        }.GetNewClosure()

        $this.PlaybackPanel.OnShuffleClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.ToggleShuffle()
        }.GetNewClosure()

        $this.PlaybackPanel.Scrubber.OnSeekRequested = {
            Param(
                [Int]$DeltaMs
            )

            $SelfCore.SeekRelative($DeltaMs)
        }.GetNewClosure()

        $this.PlaybackPanel.VolumeControl.OnVolumeChanged = {
            Param(
                [Int]$NewPercent
            )

            $SelfCore.SetVolume($NewPercent)
        }.GetNewClosure()

        $this.PlaybackPanel.VolumeControl.OnMuteToggled = {
            Param(
                [Boolean]$Muted
            )

            $SelfCore.SetMuted($Muted)
        }.GetNewClosure()

        $this.DirectoryPanel.DirectoryList.OnActivate = {
            Param(
                [UIList]$SourceList,
                [Context]$ActionContext
            )

            $SelfCore.ActivateSelectedDirectoryEntry()
        }.GetNewClosure()

        $this.PlaylistPanel.PlaylistList.OnActivate = {
            Param(
                [UIList]$SourceList,
                [Context]$ActionContext
            )

            $SelfCore.PlaySelectedPlaylistItem()
        }.GetNewClosure()

        $this.MediaPlayer.OnTrackEnded = {
            Param(
                [MMMediaPlayer]$Player
            )

            $SelfCore.HandleTrackEnded()
        }.GetNewClosure()

        $this.MediaPlayer.OnError = {
            Param(
                [String]$ErrorMsg
            )

            $SelfCore.FooterPanel.SetError($ErrorMsg)
        }.GetNewClosure()
    }

    [Void]InitializeStates() {
        $this.AppState = [SMStateMachine]::new('PBStateInit')

        $this.AppState.AddStates(@(
            [PBStateInit]::new(),
            [PBStateMainPlayer]::new(),
            [PBStateDirectoryPrompt]::new(),
            [PBStatePlaylistSavePrompt]::new(),
            [PBStateShutdown]::new()
        ))

        $this.AppState.AddTransitions(@(
            [SMTransition]::new('PBStateInit', 'Ready', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateInit', 'FatalError', 'PBStateShutdown'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenDirectoryPrompt', 'PBStateDirectoryPrompt'),
            [SMTransition]::new('PBStateDirectoryPrompt', 'CloseDirectoryPrompt', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenSavePlaylistPrompt', 'PBStatePlaylistSavePrompt'),
            [SMTransition]::new('PBStatePlaylistSavePrompt', 'CloseSavePlaylistPrompt', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'Quit', 'PBStateShutdown')
        ))
    }

    [String]GetCurrentPlayingPath() {
        If(($null -NE $this.MediaPlayer.CurrentTrack) -AND ($this.MediaPlayer.IsStopped() -EQ $false)) {
            Return $this.MediaPlayer.CurrentTrack.FullPath
        }

        Return ''
    }

    [Void]SyncAllPanelsFromState() {
        [String]$PlayingPath = $this.GetCurrentPlayingPath()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.DirectoryPanel.UpdatePlayingMarker($PlayingPath)
        $this.PlaylistPanel.UpdatePlayingIndex($this.Playlist.CurrentIndex)
    }

    [Void]SetFocusZone(
        [BoomboxFocusZone]$Zone,
        [Context]$Context
    ) {
        $this.PlaybackPanel.UnfocusAllElements($Context)
        $this.DirectoryPanel.UnfocusAllElements($Context)
        $this.PlaylistPanel.UnfocusAllElements($Context)

        $this.PlaybackPanel.SetFocusedBorderHighlight($false)
        $this.DirectoryPanel.SetFocusedBorderHighlight($false)
        $this.PlaylistPanel.SetFocusedBorderHighlight($false)

        $this.ActiveFocusZone = $Zone

        Switch($Zone) {
            ([BoomboxFocusZone]::DirectoryBrowser) {
                $this.DirectoryPanel.SetFocusedBorderHighlight($true)
                $this.DirectoryPanel.FocusFirst($Context)

                Break
            }

            ([BoomboxFocusZone]::Playlist) {
                $this.PlaylistPanel.SetFocusedBorderHighlight($true)
                $this.PlaylistPanel.FocusFirst($Context)

                Break
            }

            ([BoomboxFocusZone]::PlaybackControls) {
                $this.PlaybackPanel.SetFocusedBorderHighlight($true)
                $this.PlaybackPanel.FocusElementByKey(12, $Context)

                Break
            }
        }
    }

    [Void]CycleFocusZone(
        [Boolean]$Reverse,
        [Context]$Context
    ) {
        [BoomboxFocusZone]$NextZone = [BoomboxFocusZone]::DirectoryBrowser

        If($Reverse -EQ $false) {
            Switch($this.ActiveFocusZone) {
                ([BoomboxFocusZone]::DirectoryBrowser) {
                    $NextZone = [BoomboxFocusZone]::Playlist

                    Break
                }

                ([BoomboxFocusZone]::Playlist) {
                    $NextZone = [BoomboxFocusZone]::PlaybackControls

                    Break
                }

                Default {
                    $NextZone = [BoomboxFocusZone]::DirectoryBrowser

                    Break
                }
            }
        } Else {
            Switch($this.ActiveFocusZone) {
                ([BoomboxFocusZone]::DirectoryBrowser) {
                    $NextZone = [BoomboxFocusZone]::PlaybackControls

                    Break
                }

                ([BoomboxFocusZone]::PlaybackControls) {
                    $NextZone = [BoomboxFocusZone]::Playlist

                    Break
                }

                Default {
                    $NextZone = [BoomboxFocusZone]::DirectoryBrowser

                    Break
                }
            }
        }

        $this.SetFocusZone($NextZone, $Context)
    }

    [Void]PlayTrack(
        [MMTrackInfo]$Track
    ) {
        If($null -EQ $Track) {
            Return
        }

        If($this.MediaPlayer.LoadAndPlay($Track) -EQ $true) {
            $this.FooterPanel.SetStatus("Playing `"$($Track.DisplayName)`"")
        }

        $this.SyncAllPanelsFromState()
    }

    [Void]PlaySelectedPlaylistItem() {
        [Int]$SelectedIdx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If($SelectedIdx -LT 0) {
            Return
        }

        [MMTrackInfo]$Track = $this.Playlist.SelectIndex($SelectedIdx)

        If($null -NE $Track) {
            $this.PlayTrack($Track)
        }
    }

    [Void]TogglePlayPause() {
        If(($this.MediaPlayer.IsPlaying() -EQ $false) -AND ($this.MediaPlayer.IsPaused() -EQ $false)) {
            [MMTrackInfo]$TargetTrack = $this.Playlist.GetCurrentTrack()

            If(($null -EQ $TargetTrack) -AND ($this.Playlist.Tracks.Count -GT 0)) {
                $TargetTrack = $this.Playlist.SelectIndex(0)
            }

            If($null -NE $TargetTrack) {
                $this.PlayTrack($TargetTrack)
            } Else {
                $this.FooterPanel.SetStatus('Playlist is empty. Select a track first.')
            }

            Return
        }

        If($this.MediaPlayer.TogglePlayPause() -EQ $true) {
            [String]$Verb      = ($this.MediaPlayer.IsPlaying() -EQ $true) ? 'Resumed' : 'Paused'
            [String]$TrackName = ($null -NE $this.MediaPlayer.CurrentTrack) ? $this.MediaPlayer.CurrentTrack.DisplayName : 'track'

            $this.FooterPanel.SetStatus("$($Verb) `"$($TrackName)`"")
            $this.SyncAllPanelsFromState()
        }
    }

    [Void]StopPlayback() {
        $this.MediaPlayer.Stop()
        $this.FooterPanel.SetStatus('Playback stopped')
        $this.SyncAllPanelsFromState()
    }

    [Void]PlayNextTrack(
        [Boolean]$IsManual
    ) {
        [MMTrackInfo]$NextTrack = $this.Playlist.AdvanceNext($IsManual)

        If($null -NE $NextTrack) {
            $this.PlayTrack($NextTrack)
            $this.PlaylistPanel.PlaylistList.SelectIndex($this.Playlist.CurrentIndex)
        } Else {
            $this.StopPlayback()
            $this.FooterPanel.SetStatus('Reached end of playlist')
        }
    }

    [Void]PlayPreviousTrack() {
        [MMTrackInfo]$PrevTrack = $this.Playlist.AdvancePrevious()

        If($null -NE $PrevTrack) {
            $this.PlayTrack($PrevTrack)
            $this.PlaylistPanel.PlaylistList.SelectIndex($this.Playlist.CurrentIndex)
        } Else {
            $this.FooterPanel.SetStatus('Playlist is empty')
        }
    }

    [Void]HandleTrackEnded() {
        $this.PlayNextTrack($false)
    }

    [Void]SeekRelative(
        [Int]$DeltaMs
    ) {
        If($this.MediaPlayer.SeekRelative($DeltaMs) -EQ $true) {
            $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
            $this.FooterPanel.SetStatus("Seeked to $(Format-Duration $this.MediaPlayer.PositionMs)")
        }
    }

    [Void]SetVolume(
        [Int]$Percent
    ) {
        $this.MediaPlayer.SetVolume($Percent)
        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus("Volume: $($this.MediaPlayer.Volume.Value)%")
    }

    [Void]AdjustVolume(
        [Int]$Delta
    ) {
        $this.MediaPlayer.AdjustVolume($Delta)
        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus("Volume: $($this.MediaPlayer.Volume.Value)%")
    }

    [Void]SetMuted(
        [Boolean]$Muted
    ) {
        If($this.MediaPlayer.IsMuted -NE $Muted) {
            $null = $this.MediaPlayer.ToggleMute()
        }

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus(($this.MediaPlayer.IsMuted -EQ $true) ? 'Audio muted' : "Audio unmuted ($($this.MediaPlayer.Volume.Value)%)")
    }

    [Void]ToggleMute() {
        [Boolean]$Muted = $this.MediaPlayer.ToggleMute()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus(($Muted -EQ $true) ? 'Audio muted' : "Audio unmuted ($($this.MediaPlayer.Volume.Value)%)")
    }

    [Void]CycleRepeatMode() {
        [RepeatMode]$Mode = $this.Playlist.CycleRepeatMode()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus("Repeat mode: $($Mode)")
    }

    [Void]ToggleShuffle() {
        [Boolean]$Enabled = $this.Playlist.ToggleShuffle()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus(($Enabled -EQ $true) ? 'Shuffle: On' : 'Shuffle: Off')
    }

    [Void]ActivateSelectedDirectoryEntry() {
        [MMDirectoryEntry]$Entry = $this.DirectoryPanel.GetSelectedEntry()

        If($null -EQ $Entry) {
            Return
        }

        Switch($Entry.EntryType) {
            ([DirectoryEntryType]::ParentDirectory) {
                $this.NavigateDirectory($Entry.FullPath)

                Break
            }

            ([DirectoryEntryType]::Directory) {
                $this.NavigateDirectory($Entry.FullPath)

                Break
            }

            ([DirectoryEntryType]::PlaylistFile) {
                $this.LoadPlaylistFile($Entry.FullPath)

                Break
            }

            Default {
                [MMTrackInfo]$Track = [MMTrackInfo]::new($Entry.FullPath)
                [Int]$ExistingIdx  = $this.Playlist.FindTrackIndexByPath($Track.FullPath)

                If($ExistingIdx -GE 0) {
                    $null = $this.Playlist.SelectIndex($ExistingIdx)
                } Else {
                    $this.Playlist.AddTrack($Track)
                    $null = $this.Playlist.SelectIndex($this.Playlist.Tracks.Count - 1)
                }

                $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $this.Playlist.CurrentIndex)
                $this.PlayTrack($Track)

                Break
            }
        }
    }

    [Void]NavigateDirectory(
        [String]$TargetPath
    ) {
        If($this.DirectoryService.LoadDirectory($TargetPath) -EQ $true) {
            $this.DirectoryPanel.SyncFromService($this.DirectoryService, $this.GetCurrentPlayingPath())
            $this.FooterPanel.SetStatus("Directory: $($this.DirectoryService.CurrentPath)")
        } Else {
            $this.FooterPanel.SetError($this.DirectoryService.LastError)
        }
    }

    [Void]NavigateDirectoryUp() {
        If($this.DirectoryService.NavigateUp() -EQ $true) {
            $this.DirectoryPanel.SyncFromService($this.DirectoryService, $this.GetCurrentPlayingPath())
            $this.FooterPanel.SetStatus("Directory: $($this.DirectoryService.CurrentPath)")
        } Else {
            $this.FooterPanel.SetError($this.DirectoryService.LastError)
        }
    }

    [Void]AddSelectedDirectoryTrackToPlaylist() {
        [MMDirectoryEntry]$Entry = $this.DirectoryPanel.GetSelectedEntry()

        If(($null -EQ $Entry) -OR ($Entry.EntryType -NE [DirectoryEntryType]::MediaFile)) {
            $this.FooterPanel.SetStatus('Select an audio file to add to the playlist.')

            Return
        }

        [MMTrackInfo]$Track = [MMTrackInfo]::new($Entry.FullPath)
        $this.Playlist.AddTrack($Track)
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, ($this.Playlist.Tracks.Count - 1))
        $this.FooterPanel.SetStatus("Added `"$($Track.DisplayName)`" to playlist")
    }

    [Void]AddAllDirectoryTracksToPlaylist() {
        [List[MMTrackInfo]]$DirTracks = $this.DirectoryService.GetMediaTracksInCurrentDirectory()

        If($DirTracks.Count -EQ 0) {
            $this.FooterPanel.SetStatus('No supported media files in current directory.')

            Return
        }

        $this.Playlist.AddTracks($DirTracks)
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, ($this.Playlist.Tracks.Count - 1))
        $this.FooterPanel.SetStatus("Added $($DirTracks.Count) tracks from directory")
    }

    [Void]LoadPlaylistFile(
        [String]$PlaylistPath
    ) {
        [Hashtable]$LoadResult = [MMPlaylistFileService]::LoadPlaylist($PlaylistPath)

        If($LoadResult.Success -EQ $false) {
            $this.FooterPanel.SetError($LoadResult.ErrorMessage)

            Return
        }

        $this.Playlist.LoadTracks($LoadResult.Tracks, $LoadResult.PlaylistName, $LoadResult.SourcePath)
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, 0)
        $this.SyncAllPanelsFromState()

        [String]$StatusMsg = "Loaded '$($LoadResult.PlaylistName)' ($($LoadResult.Tracks.Count) tracks)"

        If($LoadResult.SkippedCount -GT 0) {
            $StatusMsg += ", skipped $($LoadResult.SkippedCount) missing"
        }

        $this.FooterPanel.SetStatus($StatusMsg)
    }

    [Void]RemoveSelectedPlaylistTrack() {
        [Int]$Idx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If($Idx -LT 0) {
            Return
        }

        [Boolean]$WasPlaying = ($Idx -EQ $this.Playlist.CurrentIndex)
        [String]$RemovedName = $this.Playlist.Tracks[$Idx].DisplayName

        If($this.Playlist.RemoveAt($Idx) -EQ $true) {
            If($WasPlaying -EQ $true) {
                $this.MediaPlayer.Stop()
            }

            [Int]$NextSelection = [Math]::Min($Idx, ($this.Playlist.Tracks.Count - 1))

            $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $NextSelection)
            $this.SyncAllPanelsFromState()
            $this.FooterPanel.SetStatus("Removed `"$($RemovedName)`"")
        }
    }

    [Void]MoveSelectedPlaylistTrackUp() {
        [Int]$Idx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If($Idx -LE 0) {
            Return
        }

        [Int]$NewIdx = $this.Playlist.MoveUp($Idx)

        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $NewIdx)
        $this.FooterPanel.SetStatus('Moved track up')
    }

    [Void]MoveSelectedPlaylistTrackDown() {
        [Int]$Idx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If(($Idx -LT 0) -OR ($Idx -GE ($this.Playlist.Tracks.Count - 1))) {
            Return
        }

        [Int]$NewIdx = $this.Playlist.MoveDown($Idx)

        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $NewIdx)
        $this.FooterPanel.SetStatus('Moved track down')
    }

    [Void]ClearPlaylist() {
        $this.MediaPlayer.Stop()
        $this.Playlist.Clear()
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, -1)
        $this.SyncAllPanelsFromState()
        $this.FooterPanel.SetStatus('Cleared playlist')
    }

    [Void]Cleanup() {
        If($null -NE $this.MediaPlayer) {
            $this.MediaPlayer.Dispose()
        }

        ([AppCore]$this).Cleanup()
    }
}
