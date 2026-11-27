using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE INIT
#
# STARTUP STATE THAT VERIFIES THE WINDOWS ENVIRONMENT, READS THE STARTING
# DIRECTORY, AND INITIALIZES THE PLAYLIST FROM -PLAYLIST OR CWD MEDIA FILES.
#
###############################################################################

Class PBStateInit : SMState {
    PBStateInit() : base('PBStateInit') {
        $this.OnEnter = $null
        $this.OnExit  = $null

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            If($Core.Janitor.PerformSystemSetupChecks($Core.ContextBroadcaster) -EQ $false) {
                $Core.PendingStartupStatus = 'PSBoombox requires Windows and PowerShell 7+ (Core).'
                $Core.PendingStartupError  = $true

                $Core.AppState.Trigger('FatalError', $Context)

                Return
            }

            [Boolean]$DirLoaded = $Core.DirectoryService.LoadDirectory($Core.InitialPath)

            If($DirLoaded -EQ $false) {
                [String]$FallbackPath = (Get-Location).Path
                $null                 = $Core.DirectoryService.LoadDirectory($FallbackPath)
                $Core.PendingStartupStatus = "Invalid path '$($Core.InitialPath)', fell back to CWD."
                $Core.PendingStartupError  = $true
            }

            If(($null -NE $Core.InitialPlaylistPath) -AND ($Core.InitialPlaylistPath.Trim().Length -GT 0)) {
                [Hashtable]$PlResult = [MMPlaylistFileService]::LoadPlaylist($Core.InitialPlaylistPath)

                If($PlResult.Success -EQ $true) {
                    $Core.Playlist.LoadTracks($PlResult.Tracks, $PlResult.PlaylistName, $PlResult.SourcePath)

                    $Core.AutoFocusPlaylistOnStart = ($Core.Playlist.Tracks.Count -GT 0)
                    $Core.PendingStartupStatus     = "Loaded playlist '$($PlResult.PlaylistName)' ($($PlResult.Tracks.Count) tracks)"

                    If($PlResult.SkippedCount -GT 0) {
                        $Core.PendingStartupStatus += ", skipped $($PlResult.SkippedCount) missing"
                    }
                } Else {
                    $Core.PendingStartupStatus = $PlResult.ErrorMessage
                    $Core.PendingStartupError  = $true
                }
            } Else {
                # START WITH AN EMPTY PLAYLIST AND AUTO-POPULATE ANY MEDIA FILES IN CWD
                $Core.Playlist.Clear()

                [List[MMTrackInfo]]$CwdTracks = $Core.DirectoryService.GetMediaTracksInCurrentDirectory()

                If($CwdTracks.Count -GT 0) {
                    $Core.Playlist.AddTracks($CwdTracks)
                    $Core.PendingStartupStatus = "Loaded $($CwdTracks.Count) media file(s) from CWD"
                } Elseif($Core.PendingStartupError -EQ $false) {
                    $Core.PendingStartupStatus = 'Ready (empty playlist - navigate to a media folder)'
                }
            }

            $Core.ThemeService.Load()

            If(($null -NE $Core.InitialTheme) -AND ($Core.InitialTheme.Trim().Length -GT 0)) {
                [Boolean]$ThemeApplied = $Core.ThemeService.ApplyThemeByNameOrPath($Core.InitialTheme, $false)

                If($ThemeApplied -EQ $false) {
                    $Core.PendingStartupStatus = $Core.ThemeService.LastError
                    $Core.PendingStartupError  = $true
                }
            }

            $Core.EqualizerService.Load()
            $Core.MediaPlayer.ApplyEqualizerFromService()
            $Core.NotificationService.Initialize($Core.IsHeadlessMode)

            $Core.DirectoryPanel.SyncFromService($Core.DirectoryService, '')
            $Core.PlaylistPanel.SyncFromPlaylist($Core.Playlist, 0)
            $Core.PlaybackPanel.SyncFromPlayer($Core.MediaPlayer, $Core.Playlist)

            If($Core.PendingStartupError -EQ $true) {
                $Core.FooterPanel.SetError($Core.PendingStartupStatus)
            } Else {
                $Core.FooterPanel.SetStatus($Core.PendingStartupStatus)
            }

            If($Core.IsBufferTooSmall -EQ $true) {
                $Core.SuspendedStateName   = 'PBStateMainPlayer'
                $Core.IsSuspendedForResize = $false
                $Core.AppState.Trigger('BufferTooSmall', $Context)
            } Else {
                $Core.AppState.Trigger('Ready', $Context)
            }
        }
    }
}
