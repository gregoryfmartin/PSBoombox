using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest

. "$($PSScriptRoot)\Test-Helpers.ps1"

[String]$RepoRoot      = [Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
[String]$ManifestPath  = Join-Path $RepoRoot 'PSBoombox.psd1'
[Int]$PassedCount      = 0
[Int]$FailedCount      = 0
[List[String]]$Errors  = [List[String]]::new()

Function Invoke-TestCase {
    Param(
        [String]$Name,
        [ScriptBlock]$Body
    )

    Try {
        & $Body
        Write-Host "[PASS] $($Name)" -ForegroundColor Green
        $Script:PassedCount++
    } Catch {
        Write-Host "[FAIL] $($Name): $($_.Exception.Message)" -ForegroundColor Red
        $Script:Errors.Add("$($Name): $($_.Exception.Message)")
        $Script:FailedCount++
    }
}

Invoke-TestCase -Name 'Module Manifest and Export Verification' -Body {
    $ManifestInfo = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
    Assert-Equal $ManifestInfo.RootModule 'PSBoombox.psm1' 'RootModule mismatch'
    Assert-Equal $ManifestInfo.CompatiblePSEditions[0] 'Core' 'CompatiblePSEditions must be Core'

    Import-Module $ManifestPath -Force -ErrorAction Stop
    $ModuleObj = Get-Module -Name 'PSBoombox'
    Assert-True ($null -NE $ModuleObj) 'PSBoombox module should be loaded'

    [String[]]$ExportedNames = @($ModuleObj.ExportedFunctions.Keys)
    Assert-Equal $ExportedNames.Count 1 'Exactly one public command must be exported'
    Assert-Equal $ExportedNames[0] 'Start-PSBoombox' 'Exported command must be Start-PSBoombox'

    $CmdInfo = Get-Command -Name 'Start-PSBoombox' -Module 'PSBoombox'
    Assert-True ($CmdInfo.Parameters.ContainsKey('Path') -EQ $true) 'Start-PSBoombox must expose -Path'
    Assert-True ($CmdInfo.Parameters.ContainsKey('Playlist') -EQ $true) 'Start-PSBoombox must expose -Playlist'
    Assert-True ($CmdInfo.Parameters.ContainsKey('Theme') -EQ $true) 'Start-PSBoombox must expose -Theme'
}

Invoke-TestCase -Name 'Style and Pure Native PowerShell Audit' -Body {
    [List[FileInfo]]$CodeFiles = [List[FileInfo]]::new()
    $CodeFiles.AddRange([FileInfo[]](Get-ChildItem -Path (Join-Path $RepoRoot 'Source') -Recurse -Filter '*.ps1'))
    $CodeFiles.AddRange([FileInfo[]](Get-ChildItem -Path (Join-Path $RepoRoot 'Public') -Recurse -Filter '*.ps1'))

    Assert-True ($CodeFiles.Count -GE 40) "Expected at least 40 source files, found $($CodeFiles.Count)"

    Foreach($CodeFile in $CodeFiles) {
        [String[]]$Lines = [File]::ReadAllLines($CodeFile.FullName)
        [String]$RawText = [File]::ReadAllText($CodeFile.FullName)

        Assert-True ($Lines.Length -GE 3) "$($CodeFile.Name) is too short"
        Assert-Equal $Lines[0] 'using namespace System' "$($CodeFile.Name) line 1 must be 'using namespace System'"
        Assert-True ($RawText.Contains('Set-StrictMode -Version Latest') -EQ $true) "$($CodeFile.Name) must enable Set-StrictMode -Version Latest"
        If($CodeFile.Name -NE 'MMEqualizerEngineNative.ps1') {
            Assert-False ([Regex]::IsMatch($RawText, '\bAdd-Type\b')) "$($CodeFile.Name) must not use Add-Type / inline C#"
        }
        Assert-False ([Regex]::IsMatch($RawText, '\[Bool\]')) "$($CodeFile.Name) must use [Boolean] instead of [Bool]"

        If($CodeFile.Name -NE 'TrueColor.ps1') {
            Assert-False ([Regex]::IsMatch($RawText, '\[TrueColor\]::new\(')) "$($CodeFile.Name) must use ColorLibrary instead of raw TrueColor literals"
        }
    }
}

$ModuleScope = Get-Module -Name 'PSBoombox'

If($null -NE $ModuleScope) {
    [ScriptBlock]$ModuleTestRunner = $ModuleScope.NewBoundScriptBlock({
        Param(
            [ScriptBlock]$InvokeCase,
            [String]$TestRoot
        )

        . "$($TestRoot)\Test-Helpers.ps1"

        [String]$IsolatedConfigDir      = Join-Path ([Path]::GetTempPath()) "PSBoombox_AppCfgTest_$([Guid]::NewGuid().ToString('N'))"
        [String]$IsolatedEqConfigDir    = Join-Path ([Path]::GetTempPath()) "PSBoombox_EqCfgTest_$([Guid]::NewGuid().ToString('N'))"
        [String]$IsolatedThemeConfigDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_ThemeCfgTest_$([Guid]::NewGuid().ToString('N'))"
        [PBConfigService]::ConfigDirectoryOverride    = $IsolatedConfigDir
        [MMEqualizerService]::ConfigDirectoryOverride = $IsolatedEqConfigDir
        [UIThemeService]::ConfigDirectoryOverride     = $IsolatedThemeConfigDir

        Try {

    & $InvokeCase -Name 'State Machines (UI, Playback, and Application FSMs)' -Body {
        [UILabel]$Label = [UILabel]::new('Sample', [ATCoordinates]::new(1, 1))
        Assert-Equal $Label.BaseStateMachine.CurrentState ([SMUiElementStateMachine]::StateInit) 'Initial UI state'
        $Label.Update($null)
        Assert-Equal $Label.BaseStateMachine.CurrentState ([SMUiElementStateMachine]::StateInactive) 'Ready transitions to Inactive'
        $Label.Activate($null)
        Assert-True ($Label.IsActive()) 'Label should be Active'

        [UIButton]$Btn = [UIButton]::new('Play', [ATCoordinates]::new(1, 1), $null)
        $Btn.Activate($null)
        $Btn.Focus($null)
        Assert-True ($Btn.IsFocused()) 'Button should be Focused'
        $Btn.Unfocus($null)
        Assert-False ($Btn.IsFocused()) 'Button should be Unfocused'
        $Btn.Deactivate($null)
        Assert-False ($Btn.IsActive()) 'Button should be Inactive'
        $Btn.Deinit($null)
        Assert-Equal $Btn.BaseStateMachine.CurrentState ([SMUiElementStateMachine]::StateDeinit) 'Button should reach Deinit'

        [SMPlaybackStateMachine]$PlaySm = [SMPlaybackStateMachine]::new()
        [Context]$PlayCtx               = [Context]::new()
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Stopped) 'Initial playback state'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionLoad, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Loading) 'Loading state'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionPlayReady, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Playing) 'Playing state'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionPause, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Paused) 'Paused state'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionResume, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Playing) 'Resumed to Playing'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionStop, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Stopped) 'Stopped state'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionLoad, $PlayCtx)
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionLoadFailed, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Error) 'Error state'
        $PlaySm.Trigger([SMPlaybackStateMachine]::TransitionReset, $PlayCtx)
        Assert-Equal ($PlaySm.GetPlaybackState()) ([PlaybackState]::Stopped) 'Reset from Error to Stopped'
    }

    & $InvokeCase -Name 'Windows Multimedia API (winmm.dll) Live MCI Integration' -Body {
        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_AudioTest_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $TempDir -ItemType Directory -Force

        Try {
            [String]$WavOne = Join-Path $TempDir 'track_one.wav'
            [String]$WavTwo = Join-Path $TempDir 'track_two.wav'
            New-TestWavFile -FilePath $WavOne -DurationMs 900
            New-TestWavFile -FilePath $WavTwo -DurationMs 350

            [Hashtable]$SysInfo = [MMWinMMNative]::SendCommand('sysinfo all quantity')
            Assert-True ($SysInfo.Success -EQ $true) "winmm sysinfo failed: $($SysInfo.ErrorMessage)"

            [MMMediaPlayer]$Player  = [MMMediaPlayer]::new()
            [Hashtable]$EndTracker  = @{ Fired = $false }
            $Player.OnTrackEnded    = {
                Param([MMMediaPlayer]$Sender)
                $EndTracker.Fired = $true
            }.GetNewClosure()

            Try {
                [MMTrackInfo]$Track1 = [MMTrackInfo]::new($WavOne)
                [Boolean]$Loaded1    = $Player.LoadAndPlay($Track1)
                Assert-True $Loaded1 "LoadAndPlay failed: $($Player.LastError)"
                Assert-True ($Player.IsPlaying()) 'Player must be Playing'
                Assert-True ($Player.DurationMs -GT 0) "DurationMs must be > 0, got $($Player.DurationMs)"

                Assert-True ($Player.Pause()) 'Pause should succeed'
                Assert-True ($Player.IsPaused()) 'Player must be Paused'

                Assert-True ($Player.Seek(300)) 'Seek while paused should succeed'
                Assert-Equal $Player.PositionMs 300 'PositionMs should reflect seek target'

                Assert-True ($Player.Resume()) 'Resume should succeed'
                Assert-True ($Player.IsPlaying()) 'Player must be Playing after resume'

                $Player.SetVolume(45)
                Assert-Equal $Player.Volume.Value 45 'Volume should be 45'

                [Boolean]$Muted = $Player.ToggleMute()
                Assert-True $Muted 'Mute should be true'
                [Boolean]$Unmuted = $Player.ToggleMute()
                Assert-False $Unmuted 'Mute should be false'

                $Player.Stop()
                Assert-True ($Player.IsStopped()) 'Player must be Stopped'

                [MMTrackInfo]$Track2 = [MMTrackInfo]::new($WavTwo)
                Assert-True ($Player.LoadAndPlay($Track2)) "LoadAndPlay track 2 failed: $($Player.LastError)"

                [Int]$ElapsedWait = 0
                While(($EndTracker.Fired -EQ $false) -AND ($ElapsedWait -LT 2500)) {
                    Start-Sleep -Milliseconds 120
                    $Player.Update(0.25)
                    $ElapsedWait += 120
                }

                Assert-True $EndTracker.Fired 'Natural end-of-track should trigger TrackEnded'
                Assert-True ($Player.IsStopped()) 'Player should transition to Stopped after track ends'
            } Finally {
                $Player.Dispose()
            }
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'MP3 Playback with Large ID3v2 Tags (Error 277) and Long Paths (Error 268)' -Body {
        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_Mp3Test_$([Guid]::NewGuid().ToString('N'))"
        [String]$LongSub = Join-Path $TempDir ('VeryLongNestedAlbumFolder_' + ('L' * 70))
        $null = New-Item -Path $LongSub -ItemType Directory -Force

        Try {
            [String]$PlainMp3    = Join-Path $TempDir 'plain.mp3'
            [String]$LargeId3Mp3 = Join-Path $TempDir 'large_id3_art.mp3'
            [String]$LongPathMp3 = Join-Path $LongSub ('LongTrackNameWithSpaces_' + ('T' * 55) + '.mp3')

            New-TestMp3File -FilePath $PlainMp3 -FrameCount 25
            New-TestMp3File -FilePath $LargeId3Mp3 -FrameCount 30 -Id3PaddingBytes 250000 -ZeroPaddingBytes 128
            New-TestMp3File -FilePath $LongPathMp3 -FrameCount 25

            [MMMediaPlayer]$Player = [MMMediaPlayer]::new()

            Try {
                Assert-True ($Player.LoadAndPlay([MMTrackInfo]::new($PlainMp3))) "Plain MP3 failed: $($Player.LastError)"
                Assert-True ($Player.IsPlaying()) 'Plain MP3 should be Playing'
                Assert-True ($Player.DurationMs -GT 0) "Plain MP3 DurationMs should be > 0, got $($Player.DurationMs)"
                Assert-True ($Player.Pause()) 'Plain MP3 Pause should succeed'
                Assert-True ($Player.Resume()) 'Plain MP3 Resume should succeed'
                $Player.Stop()

                Assert-True ($Player.LoadAndPlay([MMTrackInfo]::new($LargeId3Mp3))) "Large ID3v2 MP3 failed: $($Player.LastError)"
                [String]$StagedLargePath = $Player.StagedTempFilePath
                Assert-True ($Player.IsPlaying()) 'Large ID3v2 MP3 should be Playing'
                Assert-True ($Player.DurationMs -GT 0) "Large ID3v2 MP3 DurationMs should be > 0, got $($Player.DurationMs)"
                Assert-True ($Player.Pause()) 'Large ID3v2 MP3 Pause should succeed'
                Assert-True ($Player.Seek(200)) 'Large ID3v2 MP3 Seek should succeed'
                Assert-True ($Player.Resume()) 'Large ID3v2 MP3 Resume should succeed'
                $Player.Stop()
                If($StagedLargePath.Length -GT 0) {
                    Assert-False ([File]::Exists($StagedLargePath)) 'Stop() must delete staged temp file'
                }

                Assert-True ($Player.LoadAndPlay([MMTrackInfo]::new($LongPathMp3))) "Long-path MP3 failed: $($Player.LastError)"
                [String]$StagedLongPath = $Player.StagedTempFilePath
                Assert-True ($Player.IsPlaying()) 'Long-path MP3 should be Playing'
                $Player.Dispose()

                If($StagedLongPath.Length -GT 0) {
                    Assert-False ([File]::Exists($StagedLongPath)) 'Dispose() must delete staged temp file'
                }
            } Finally {
                $Player.Dispose()
            }
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Directory Service, Startup Modes, and Playlist Formats (.m3u, .m3u8, .pls, .wpl)' -Body {
        [String]$RootTemp  = Join-Path ([Path]::GetTempPath()) "PSBoombox_PlTest_$([Guid]::NewGuid().ToString('N'))"
        [String]$SubDir    = Join-Path $RootTemp 'SubAlbum'
        [String]$EmptyDir  = Join-Path $RootTemp 'EmptyFolder'
        $null = New-Item -Path $SubDir -ItemType Directory -Force
        $null = New-Item -Path $EmptyDir -ItemType Directory -Force

        Try {
            [String]$TrackA = Join-Path $RootTemp 'alpha.wav'
            [String]$TrackB = Join-Path $SubDir 'beta.wav'
            New-TestWavFile -FilePath $TrackA -DurationMs 500
            New-TestWavFile -FilePath $TrackB -DurationMs 750

            [MMDirectoryService]$DirSvc = [MMDirectoryService]::new($RootTemp)
            Assert-Equal $DirSvc.CurrentPath $RootTemp 'Directory current path'
            Assert-Equal ($DirSvc.GetMediaFileCount()) 1 'RootTemp should have 1 media file'
            Assert-True ($DirSvc.LoadDirectory($SubDir)) 'Should navigate into SubAlbum'
            Assert-Equal ($DirSvc.GetMediaFileCount()) 1 'SubAlbum should have 1 media file'
            Assert-True ($DirSvc.NavigateUp()) 'NavigateUp should return to RootTemp'
            Assert-Equal $DirSvc.CurrentPath $RootTemp 'Returned to RootTemp'
            Assert-False ($DirSvc.LoadDirectory((Join-Path $RootTemp 'DoesNotExist'))) 'Invalid directory should return false'

            [List[MMTrackInfo]]$SourceTracks = [List[MMTrackInfo]]::new()
            $SourceTracks.Add([MMTrackInfo]::new($TrackA, 'Alpha Track', 1000))
            $SourceTracks.Add([MMTrackInfo]::new($TrackB, 'Beta Track', 2000))

            Foreach($Ext in @('.m3u', '.m3u8', '.pls', '.wpl')) {
                [String]$SavedFile = Join-Path $RootTemp "test_list$($Ext)"
                [Hashtable]$SaveRes = [MMPlaylistFileService]::SavePlaylist($SavedFile, $SourceTracks)
                Assert-True ($SaveRes.Success -EQ $true) "SavePlaylist ($($Ext)) failed: $($SaveRes.ErrorMessage)"

                [Hashtable]$LoadRes = [MMPlaylistFileService]::LoadPlaylist($SavedFile)
                Assert-True ($LoadRes.Success -EQ $true) "LoadPlaylist ($($Ext)) failed: $($LoadRes.ErrorMessage)"
                Assert-Equal $LoadRes.Tracks.Count 2 "Loaded track count mismatch for $($Ext)"
                Assert-Equal $LoadRes.Tracks[0].FullPath $TrackA "Track 0 path mismatch for $($Ext)"
                Assert-Equal $LoadRes.Tracks[1].FullPath $TrackB "Track 1 path mismatch for $($Ext)"
            }

            [String]$RelM3u = Join-Path $RootTemp 'relative.m3u8'
            [File]::WriteAllLines($RelM3u, @(
                '#EXTM3U',
                '#EXTINF:1,Alpha Rel',
                'alpha.wav',
                'SubAlbum\beta.wav',
                'missing_song.mp3'
            ))
            [Hashtable]$RelRes = [MMPlaylistFileService]::LoadPlaylist($RelM3u)
            Assert-True ($RelRes.Success -EQ $true) 'Relative m3u8 load should succeed'
            Assert-Equal $RelRes.Tracks.Count 2 'Should resolve 2 existing relative tracks'
            Assert-Equal $RelRes.SkippedCount 1 'Should report 1 skipped missing track'

            [BoomboxCore]$EmptyCore = [BoomboxCore]::new($EmptyDir, '')
            $EmptyCore.InitializeStates()
            $EmptyCore.Logic(0.016)
            Assert-Equal $EmptyCore.AppState.CurrentState 'PBStateMainPlayer' 'Empty dir Init transitions to MainPlayer'
            Assert-Equal $EmptyCore.Playlist.Tracks.Count 0 'Empty dir yields empty playlist'
            $EmptyCore.Cleanup()

            [BoomboxCore]$CwdCore = [BoomboxCore]::new($RootTemp, '')
            $CwdCore.InitializeStates()
            $CwdCore.Logic(0.016)
            Assert-Equal $CwdCore.Playlist.Tracks.Count 1 'CWD with media auto-populates playlist'
            Assert-Equal $CwdCore.Playlist.Tracks[0].FullPath $TrackA 'Auto-populated track matches CWD media'
            $CwdCore.Cleanup()

            [BoomboxCore]$PlCore = [BoomboxCore]::new($EmptyDir, $RelM3u)
            $PlCore.InitializeStates()
            $PlCore.Logic(0.016)
            Assert-Equal $PlCore.Playlist.Tracks.Count 2 '-Playlist should load 2 tracks on startup'
            Assert-Equal $PlCore.Playlist.PlaylistName 'relative' 'PlaylistName should match file basename'
            $PlCore.Cleanup()
        } Finally {
            Remove-Item -Path $RootTemp -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Playlist Operations (Add, Remove, Reorder, Repeat, Shuffle)' -Body {
        [MMPlaylist]$Playlist = [MMPlaylist]::new()
        $Playlist.AddTrack([MMTrackInfo]::new('C:\fake\1.mp3', 'One', 1000))
        $Playlist.AddTrack([MMTrackInfo]::new('C:\fake\2.mp3', 'Two', 1000))
        $Playlist.AddTrack([MMTrackInfo]::new('C:\fake\3.mp3', 'Three', 1000))

        $null = $Playlist.SelectIndex(1)
        Assert-Equal $Playlist.GetCurrentTrack().DisplayName 'Two' 'Selected track 1'

        [Int]$MovedIdx = $Playlist.MoveUp(1)
        Assert-Equal $MovedIdx 0 'Moved index should be 0'
        Assert-Equal $Playlist.CurrentIndex 0 'CurrentIndex should follow moved track'
        Assert-Equal $Playlist.Tracks[0].DisplayName 'Two' 'Two is now at index 0'

        Assert-Equal ($Playlist.CycleRepeatMode()) ([RepeatMode]::Playlist) 'Repeat Off -> Playlist'
        $null = $Playlist.SelectIndex(2)
        [MMTrackInfo]$Wrapped = $Playlist.AdvanceNext($false)
        Assert-Equal $Wrapped.DisplayName 'Two' 'Playlist repeat wraps to index 0'

        Assert-Equal ($Playlist.CycleRepeatMode()) ([RepeatMode]::Track) 'Repeat Playlist -> Track'
        [MMTrackInfo]$Repeated = $Playlist.AdvanceNext($false)
        Assert-Equal $Repeated.DisplayName 'Two' 'Track repeat stays on index 0'

        Assert-True ($Playlist.RemoveAt(0)) 'RemoveAt(0) succeeds'
        Assert-Equal $Playlist.Tracks.Count 2 'Track count reduced to 2'
        Assert-Equal $Playlist.CurrentIndex -1 'CurrentIndex resets when playing track removed'
    }

    & $InvokeCase -Name 'TUI Controls and Headless App FSM Simulation' -Body {
        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_UiTest_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $TempDir -ItemType Directory -Force

        Try {
            [String]$LongFile = Join-Path $TempDir ('VeryLongSongName_' + ('X' * 70) + '.wav')
            New-TestWavFile -FilePath $LongFile -DurationMs 300

            [UIList]$TestList = [UIList]::new([ATCoordinates]::new(2, 2), $null, 4)
            $TestList.SetMaxDisplayWidth(24)
            $TestList.Activate($null)
            $TestList.AddItem(('A' * 50))
            $TestList.AddItem('Short')
            Assert-True ($TestList.Items[0].UserData.Length -LE 24) "UIListItem exceeded MaxDisplayWidth: $($TestList.Items[0].UserData.Length)"
            $TestList.ClearItems()
            [String]$BlankAnsi = $TestList.ToAnsiControlSequenceString()
            Assert-True ($BlankAnsi.Length -GT 0) 'Clearing UIList must emit blank clearing sequence'

            [UITextInput]$PathInput = [UITextInput]::new('Path', [ATCoordinates]::new(3, 3), 260, ('C:\' + ('Folder\' * 15)), 20)
            $PathInput.Activate($null)
            $PathInput.Focus($null)
            [String]$InputAnsi = $PathInput.ToAnsiControlSequenceString()
            Assert-True ($InputAnsi.Length -GT 0) 'UITextInput scrolling render should produce ANSI output'

            [BoomboxCore]$Core = [BoomboxCore]::new($TempDir, '')
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Entered MainPlayer'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.ActiveFocusZone ([BoomboxFocusZone]::Playlist) 'Tab switches to Playlist'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.ActiveFocusZone ([BoomboxFocusZone]::PlaybackControls) 'Tab switches to PlaybackControls'

            # TRANSPORT UNICODE GLYPHS AND NON-OVERLAPPING ROW-4 LAYOUT
            Assert-Equal $Core.PlaybackPanel.PrevButton.LabelText "|`u{25C0}" 'PrevButton must use |◀ Unicode glyph'
            Assert-Equal $Core.PlaybackPanel.PlayPauseButton.LabelText "`u{25B6}" 'PlayPauseButton must use ▶ Unicode glyph when stopped'
            Assert-Equal $Core.PlaybackPanel.StopButton.LabelText "`u{25A0}" 'StopButton must use ■ Unicode glyph'
            Assert-Equal $Core.PlaybackPanel.NextButton.LabelText "`u{25B6}|" 'NextButton must use ▶| Unicode glyph'
            Foreach($TestWidth in @(80, 100)) {
                $Core.PlaybackPanel.Resize($TestWidth)
                [UIPlaybackControlPanel]$P = $Core.PlaybackPanel
                Assert-True (($P.PrevButton.DrawCoordinates.Column.Value + $P.PrevButton.MaxRenderedLength) -LE $P.PlayPauseButton.DrawCoordinates.Column.Value) "PrevButton overlaps PlayPauseButton at width $TestWidth"
                Assert-True (($P.PlayPauseButton.DrawCoordinates.Column.Value + $P.PlayPauseButton.MaxRenderedLength) -LE $P.StopButton.DrawCoordinates.Column.Value) "PlayPauseButton overlaps StopButton at width $TestWidth"
                Assert-True (($P.StopButton.DrawCoordinates.Column.Value + $P.StopButton.MaxRenderedLength) -LE $P.NextButton.DrawCoordinates.Column.Value) "StopButton overlaps NextButton at width $TestWidth"
                Assert-True (($P.NextButton.DrawCoordinates.Column.Value + $P.NextButton.MaxRenderedLength) -LE $P.RepeatButton.DrawCoordinates.Column.Value) "NextButton overlaps RepeatButton at width $TestWidth"
                Assert-True (($P.RepeatButton.DrawCoordinates.Column.Value + $P.RepeatButton.MaxRenderedLength) -LE $P.ShuffleButton.DrawCoordinates.Column.Value) "RepeatButton overlaps ShuffleButton at width $TestWidth"
                Assert-True (($P.ShuffleButton.DrawCoordinates.Column.Value + $P.ShuffleButton.MaxRenderedLength) -LE $P.VolumeControl.DrawCoordinates.Column.Value) "ShuffleButton overlaps VolumeControl at width $TestWidth"
            }

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'g', [ConsoleKey]::G, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateDirectoryPrompt' 'G opens DirectoryPrompt'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Escape closes DirectoryPrompt'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'w', [ConsoleKey]::W, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStatePlaylistSavePrompt' 'W opens PlaylistSavePrompt'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]13, [ConsoleKey]::Enter, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Enter saves playlist and returns to MainPlayer'
            Assert-True ([File]::Exists((Join-Path $TempDir 'playlist.m3u8'))) 'Saved playlist.m3u8 must exist on disk'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateEqualizer' 'E opens Equalizer modal'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'t', [ConsoleKey]::T, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::UpArrow, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'s', [ConsoleKey]::S, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'N', [ConsoleKey]::N, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'i', [ConsoleKey]::I, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'g', [ConsoleKey]::G, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'h', [ConsoleKey]::H, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'t', [ConsoleKey]::T, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]13, [ConsoleKey]::Enter, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True $Core.EqualizerService.Enabled 'T inside modal toggles EQ Enabled'
            Assert-Equal $Core.EqualizerService.BandGainsDb[0] 1 'UpArrow increments focused 31 Hz band to +1 dB'
            Assert-Equal $Core.EqualizerService.ActivePresetName 'Night' 'Saving custom preset activates Night'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'E inside Equalizer modal closes back to MainPlayer'
            Assert-True ($Core.PlaybackPanel.EqBadgeLabel.UserData.Trim() -EQ '[EQ:Night]') "Top EQ badge should display '[EQ:Night]' but got '$($Core.PlaybackPanel.EqBadgeLabel.UserData)'"

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'q', [ConsoleKey]::Q, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateShutdown' 'Q transitions to Shutdown'
            Assert-False $Core.IsRunning 'IsRunning should be false on Shutdown'

            $Core.Cleanup()
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Equalizer DSP Frequency Response and Bypass' -Body {
        [Int]$SampleRate = 44100
        [Int]$Frames     = 4410

        [Func[Double, Single[]]]$MakeSine = {
            Param([Double]$FreqHz)
            [Single[]]$Buf = [Single[]]::new($Frames * 2)
            For([Int]$I = 0; $I -LT $Frames; $I++) {
                [Single]$Val = [Single](0.25 * [Math]::Sin((2.0 * [Math]::PI * $FreqHz * $I) / $SampleRate))
                $Buf[($I * 2)]     = $Val
                $Buf[($I * 2) + 1] = $Val
            }
            Return $Buf
        }

        [Func[Single[], Double]]$ComputeRms = {
            Param([Single[]]$Buf)
            [Double]$Sum = 0.0
            [Int]$Start  = [Int]($Buf.Length / 4)
            [Int]$Count  = $Buf.Length - $Start
            For([Int]$I = $Start; $I -LT $Buf.Length; $I++) {
                $Sum += ([Double]$Buf[$I] * [Double]$Buf[$I])
            }
            Return [Math]::Sqrt($Sum / $Count)
        }

        [Single[]]$Sine62 = $MakeSine.Invoke(62.5)
        [Single[]]$Sine4k = $MakeSine.Invoke(4000.0)
        [Double]$Rms62Raw = $ComputeRms.Invoke($Sine62)
        [Double]$Rms4kRaw = $ComputeRms.Invoke($Sine4k)

        [Double[]]$BoostLow = [Double[]]@(0.0, 12.0, 0.0, 0.0, 0.0, 0.0, 0.0, -12.0, 0.0, 0.0)
        [Single[]]$Bypassed = [MMEqualizerEngineNative]::ProcessBufferForTest($Sine62, $SampleRate, 2, $false, 6.0, $BoostLow)
        [Double]$RmsByp     = $ComputeRms.Invoke($Bypassed)
        Assert-True ([Math]::Abs($RmsByp - $Rms62Raw) -LT 0.0001) 'Disabled EQ must bypass signal unchanged'

        [Single[]]$LowOut  = [MMEqualizerEngineNative]::ProcessBufferForTest($Sine62, $SampleRate, 2, $true, 0.0, $BoostLow)
        [Double]$RmsLowOut = $ComputeRms.Invoke($LowOut)
        Assert-True ($RmsLowOut -GT ($Rms62Raw * 2.5)) "62 Hz +12 dB boost must substantially raise RMS ($($RmsLowOut) vs $($Rms62Raw))"

        [Single[]]$HighOut  = [MMEqualizerEngineNative]::ProcessBufferForTest($Sine4k, $SampleRate, 2, $true, 0.0, $BoostLow)
        [Double]$RmsHighOut = $ComputeRms.Invoke($HighOut)
        Assert-True ($RmsHighOut -LT ($Rms4kRaw * 0.45)) "4 kHz -12 dB cut must substantially lower RMS ($($RmsHighOut) vs $($Rms4kRaw))"

        [Single[]]$ClipTest = [Single[]]@(0.95, -0.95, 0.95, -0.95)
        [Double[]]$FlatZero = [Double[]]@(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        [Single[]]$LimOut   = [MMEqualizerEngineNative]::ProcessBufferForTest($ClipTest, $SampleRate, 2, $true, 12.0, $FlatZero)
        Foreach($S in $LimOut) {
            Assert-True (($S -GE -1.0) -AND ($S -LE 1.0)) "Soft limiter must keep samples within [-1, 1], got $($S)"
        }
    }

    & $InvokeCase -Name 'Equalizer Presets and %APPDATA% Persistence' -Body {
        [String]$CfgTemp = Join-Path ([Path]::GetTempPath()) "PSBoombox_EqJson_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $CfgTemp -ItemType Directory -Force

        Try {
            [MMEqualizerService]$Svc1 = [MMEqualizerService]::new($CfgTemp)
            $Svc1.Load()
            Assert-Equal $Svc1.BuiltInPresets.Count 9 'Must provide 9 built-in EQ presets'
            Assert-False $Svc1.Enabled 'Initial EQ Enabled defaults to false'
            Assert-Equal $Svc1.ActivePresetName 'Flat' 'Initial preset defaults to Flat'

            Assert-True ($Svc1.ApplyPreset('Rock')) 'Applying Rock preset should succeed'
            Assert-Equal $Svc1.BandGainsDb[0] 4 'Rock 31 Hz gain should be +4 dB'
            Assert-Equal $Svc1.PreampDb -1 'Rock Preamp should be -1 dB'

            $Svc1.SetBandGainDb(1, 20)
            Assert-Equal $Svc1.BandGainsDb[1] 12 'Band gain must clamp at +12 dB'
            Assert-Equal $Svc1.ActivePresetName 'Custom' 'Manual slider edit switches ActivePreset to Custom'

            [Hashtable]$ReservedRes = $Svc1.SaveUserPreset('Rock')
            Assert-False $ReservedRes.Success 'Saving over built-in preset name must be rejected'

            [Hashtable]$SaveRes = $Svc1.SaveUserPreset('Studio Cans')
            Assert-True $SaveRes.Success "Saving named user preset failed: $($SaveRes.Message)"
            $Svc1.SetEnabled($true)
            Assert-True ([File]::Exists((Join-Path $CfgTemp 'config.json'))) 'config.json must be written to disk'

            [MMEqualizerService]$Svc2 = [MMEqualizerService]::new($CfgTemp)
            $Svc2.Load()
            Assert-True $Svc2.Enabled 'Persisted Enabled=true must load on startup'
            Assert-Equal $Svc2.ActivePresetName 'Studio Cans' 'Persisted ActivePreset must load on startup'
            Assert-Equal $Svc2.BandGainsDb[1] 12 'Persisted band gains must load cleanly'
            Assert-True ($Svc2.IsActivePresetDeletable()) 'Custom preset should be marked deletable'

            [String]$PrevCfgOverride = [PBConfigService]::ConfigDirectoryOverride
            [String]$PrevOverride    = [MMEqualizerService]::ConfigDirectoryOverride
            [PBConfigService]::ConfigDirectoryOverride    = $CfgTemp
            [MMEqualizerService]::ConfigDirectoryOverride = $CfgTemp
            [String]$EmptyMediaDir = Join-Path $CfgTemp 'EmptyDir'
            $null = New-Item -Path $EmptyMediaDir -ItemType Directory -Force
            [BoomboxCore]$RestartCore = [BoomboxCore]::new($EmptyMediaDir, '')
            $RestartCore.InitializeStates()
            $RestartCore.Logic(0.016)
            Assert-True $RestartCore.EqualizerService.Enabled 'Fresh BoomboxCore startup must load Enabled=true from config.json'
            Assert-Equal $RestartCore.EqualizerService.ActivePresetName 'Studio Cans' 'Fresh BoomboxCore startup must restore saved custom preset'
            $RestartCore.Cleanup()
            [PBConfigService]::ConfigDirectoryOverride    = $PrevCfgOverride
            [MMEqualizerService]::ConfigDirectoryOverride = $PrevOverride

            [Hashtable]$DelRes = $Svc2.DeleteUserPreset('Studio Cans')
            Assert-True $DelRes.Success 'Deleting custom preset should succeed'
            Assert-Equal $Svc2.ActivePresetName 'Custom' 'ActivePreset falls back to Custom after deleting active user preset'
        } Finally {
            Remove-Item -Path $CfgTemp -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Visualizer FFT Analysis and Post-EQ Reactivity' -Body {
        [Int]$SampleRate = 44100
        [Int]$Frames     = 2048

        [Func[Double, Single[]]]$MakeTone = {
            Param([Double]$FreqHz)
            [Single[]]$Buf = [Single[]]::new($Frames * 2)
            For([Int]$I = 0; $I -LT $Frames; $I++) {
                [Single]$Val = [Single](0.30 * [Math]::Sin((2.0 * [Math]::PI * $FreqHz * $I) / $SampleRate))
                $Buf[($I * 2)]     = $Val
                $Buf[($I * 2) + 1] = $Val
            }
            Return $Buf
        }

        [Single[]]$BassTone   = $MakeTone.Invoke(100.0)
        [Single[]]$TrebleTone = $MakeTone.Invoke(4000.0)
        [Double[]]$FlatBands  = [Double[]]@(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        [Double[]]$Boost125Hz = [Double[]]@(0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

        [Single[]]$BassSpec = [MMEqualizerEngineNative]::AnalyzeBufferForTest($BassTone, $SampleRate, 2, 16, $false, 0.0, $FlatBands)
        Assert-Equal $BassSpec.Length 16 'Spectrum snapshot must return requested bar count'
        Assert-True ($BassSpec[3] -GT ($BassSpec[12] + 0.3)) "100 Hz bass sine must peak in low bins ($($BassSpec[3]) vs high $($BassSpec[12]))"

        [Single[]]$TrebleSpec = [MMEqualizerEngineNative]::AnalyzeBufferForTest($TrebleTone, $SampleRate, 2, 16, $false, 0.0, $FlatBands)
        Assert-True ($TrebleSpec[12] -GT ($TrebleSpec[2] + 0.3)) "4 kHz treble sine must peak in bin 12 (3.3-4.9 kHz) ($($TrebleSpec[12]) vs low $($TrebleSpec[2]))"

        [Single[]]$EqBoostedSpec = [MMEqualizerEngineNative]::AnalyzeBufferForTest($BassTone, $SampleRate, 2, 16, $true, 0.0, $Boost125Hz)
        Assert-True ($EqBoostedSpec[3] -GT $BassSpec[3]) "Post-EQ +12 dB boost must raise FFT magnitude ($($EqBoostedSpec[3]) vs $($BassSpec[3]))"
    }

    & $InvokeCase -Name 'Visualizer Mode FSM, MIDI Modal, Forward Tab Cycling, and Auto-Exit' -Body {
        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_VizTest_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $TempDir -ItemType Directory -Force

        Try {
            [String]$WavFile = Join-Path $TempDir 'synth_wave.wav'
            [String]$MidFile = Join-Path $TempDir 'synth_midi.mid'
            New-TestWavFile -FilePath $WavFile -DurationMs 2200
            [File]::WriteAllBytes($MidFile, [Byte[]]@(0x4D, 0x54, 0x68, 0x64))

            [BoomboxCore]$Core = [BoomboxCore]::new($TempDir, '')
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Startup must always enter Playlist Mode (PBStateMainPlayer)'

            # PRESSING V WHILE STOPPED STAYS IN MAIN PLAYER WITH STATUS MESSAGE
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'V while stopped must stay in MainPlayer'
            Assert-True ($Core.FooterPanel.StatusLabel.UserData -MATCH 'playing') 'Footer must notify user that a track must be playing'

            # PRESSING V WHILE PLAYING A MIDI TRACK OPENS NOTICE MODAL
            [MMTrackInfo]$MidiTrack = [MMTrackInfo]::new($MidFile)
            $Core.MediaPlayer.CurrentTrack     = $MidiTrack
            $Core.MediaPlayer.UsesNativeEngine = $false
            $Core.MediaPlayer.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionLoad, $Core.MediaPlayer.PrepareContext())
            $Core.MediaPlayer.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionPlayReady, $Core.MediaPlayer.PrepareContext())
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateNoticeModal' 'V during MIDI playback must open notice modal'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]13, [ConsoleKey]::Enter, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Enter dismisses MIDI notice modal back to MainPlayer'

            $Core.MediaPlayer.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionStop, $Core.MediaPlayer.PrepareContext())

            # PLAYING REAL WAV TRACK AND PRESSING V ENTERS VISUALIZER MODE
            $Core.PlayTrack([MMTrackInfo]::new($WavFile))
            Assert-True ($Core.MediaPlayer.IsPlaying()) 'WAV track should be playing before entering Visualizer'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'V during decoded audio playback must enter PBStateVisualizer'
            Assert-Equal ($Core.VisualizerTrackLabel.UserData.TrimEnd()) 'synth_wave.wav' 'Bottom-left track label must show current track name only'
            Assert-False ($Core.VisualizerTrackLabel.UserData.Contains('Spectrum')) 'Track label must not include visualizer name'
            Assert-False ($Core.VisualizerTrackLabel.UserData.Contains('00:00')) 'Track label must not include elapsed time'

            # FORWARD-ONLY TAB CYCLING (0 -> 1 -> 2 -> 3 -> 4 -> 0), SHIFT+TAB IGNORED
            Assert-Equal $Core.Visualizers.Count 5 'Must initialize 5 starter visualizers'
            Assert-Equal $Core.ActiveVisualizerIndex 0 'Visualizer starts at index 0'
            For([Int]$Step = 1; $Step -LE 5; $Step++) {
                $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $false, $false, $false))
                $Core.Logic(0.033)
                [Int]$ExpectedIdx = $Step % 5
                Assert-Equal $Core.ActiveVisualizerIndex $ExpectedIdx "Tab step $($Step) should advance forward to $($ExpectedIdx)"
            }
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $true, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.ActiveVisualizerIndex 0 'Shift+Tab must not reverse cycle in Visualizer Mode'

            # EQ BLOCKED WHILE GLOBAL MEDIA CONTROLS WORK IN VISUALIZER MODE
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'Equalizer must not open from Visualizer Mode'

            [Int]$StartVol = $Core.MediaPlayer.Volume.Value
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'+', [ConsoleKey]::Add, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'m', [ConsoleKey]::M, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.MediaPlayer.Volume.Value ([Math]::Min(100, $StartVol + 5)) 'Volume +5% must work inside Visualizer Mode'
            Assert-True $Core.MediaPlayer.IsMuted 'Mute toggle must work inside Visualizer Mode'

            # PRESSING V EXITS BACK TO MAIN PLAYER; RE-ENTERING + S STOPS AND EXITS TO MAIN PLAYER
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'V in Visualizer Mode must return to MainPlayer'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'V re-enters Visualizer Mode while playing'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'s', [ConsoleKey]::S, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True ($Core.MediaPlayer.IsStopped()) 'S must stop playback'
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Stopping playback inside Visualizer Mode must return to MainPlayer'

            $Core.Cleanup()
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Visualizer 60 FPS Pacing, High-Res Timer, and Native Render Budget' -Body {
        Assert-True ([MMWinMMNative]::BeginHighResTimer([UInt32]1)) 'winmm timeBeginPeriod(1) should succeed'
        Assert-True ([MMWinMMNative]::EndHighResTimer([UInt32]1)) 'winmm timeEndPeriod(1) should succeed'

        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_60FpsTest_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $TempDir -ItemType Directory -Force

        Try {
            [String]$WavFile = Join-Path $TempDir 'pace_test.wav'
            New-TestWavFile -FilePath $WavFile -DurationMs 2000

            [BoomboxCore]$Core = [BoomboxCore]::new($TempDir, '')
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.TargetFps 30 'Main Player must run at 30 FPS'

            $Core.PlayTrack([MMTrackInfo]::new($WavFile))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'Must enter PBStateVisualizer for FPS check'
            Assert-Equal $Core.TargetFps 60 'Visualizer Mode must switch TargetFps to 60'
            Assert-True ($Core.TargetFrameTime -LT 0.017) "Visualizer TargetFrameTime must be < 17 ms, got $($Core.TargetFrameTime)"

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Must return to MainPlayer'
            Assert-Equal $Core.TargetFps 30 'Exiting Visualizer Mode must restore TargetFps to 30'
            $Core.Cleanup()
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }

        [UIVisualizerCanvas]$Canvas = [UIVisualizerCanvas]::new(160, 48, 1, 1)
        [Single[]]$StaticSpec       = [Single[]]::new(160)
        [Single[]]$StaticWave       = [Single[]]::new(320)
        [Single[]]$StaticMetrics    = [Single[]]@(0.55, 0.75, 0.70, 0.45, 0.35)

        For([Int]$I = 0; $I -LT 160; $I++) {
            $StaticSpec[$I] = [Single](0.20 + (0.70 * [Math]::Abs([Math]::Sin($I * 0.25))))
        }

        For([Int]$I = 0; $I -LT 320; $I++) {
            $StaticWave[$I] = [Single](0.70 * [Math]::Sin($I * 0.12))
        }

        [UIVisualizerBase[]]$Visualizers = @(
            [UIVisualizerSpectrum]::new(),
            [UIVisualizerMirror]::new(),
            [UIVisualizerOscilloscope]::new(),
            [UIVisualizerRadialPulse]::new(),
            [UIVisualizerWaterfall]::new()
        )

        [System.Diagnostics.Stopwatch]$Sw = [System.Diagnostics.Stopwatch]::new()

        Foreach($Viz in $Visualizers) {
            $Viz.Reset()
            $Canvas.InvalidateAll()

            # VERIFY SYNCHRONIZED FRAME OUTPUT AND ZERO DIFF ON IDENTICAL STEADY-STATE FRAME
            $Viz.RenderFrame($Canvas, $StaticSpec, $StaticWave, $StaticMetrics, 0.0167)
            [String]$FirstAnsi = $Canvas.BuildFrameAnsi($true, '')
            Assert-True ($FirstAnsi.Contains("`e[?2026h") -AND $FirstAnsi.Contains("`e[?2026l")) "$($Viz.Name) must wrap frame in synchronized update markers"

            [String]$PlainGlyphs = [Regex]::Replace($FirstAnsi, '\x1b\[[0-9;?]*[A-Za-z]', '')

            If($Viz -IS [UIVisualizerSpectrum]) {
                Assert-True ($FirstAnsi.Contains([Char]0x2581)) 'Spectrum Analyzer must emit Unicode peak cap glyph U+2581'
                Assert-False ($PlainGlyphs.Contains('?')) 'Spectrum Analyzer rendered glyphs must not contain replacement question marks'
            } Elseif($Viz -IS [UIVisualizerOscilloscope]) {
                Assert-True ($FirstAnsi -MATCH '[\u2800-\u28FF]') 'Braille Oscilloscope must emit Unicode Braille glyphs U+2800-U+28FF'
                Assert-False ($PlainGlyphs.Contains('?')) 'Braille Oscilloscope rendered glyphs must not contain replacement question marks'
            }

            If($Viz -IS [UIVisualizerWaterfall]) {
                For([Int]$Pre = 0; $Pre -LT 96; $Pre++) {
                    $Viz.RenderFrame($Canvas, $StaticSpec, $StaticWave, $StaticMetrics, 0.0167)
                    $null = $Canvas.BuildFrameAnsi($true, '')
                }
            }

            If(-NOT ($Viz -IS [UIVisualizerRadialPulse])) {
                $Viz.RenderFrame($Canvas, $StaticSpec, $StaticWave, $StaticMetrics, 0.0167)
                [String]$SecondAnsi = $Canvas.BuildFrameAnsi($true, '')
                Assert-Equal $SecondAnsi.Length 0 "$($Viz.Name) unchanged frame must emit 0 diff bytes"
            }

            # BENCHMARK 15 ANIMATED FRAMES AT 160x48 (< 10.0 MS/FRAME BUDGET FOR 60 FPS)
            $Sw.Restart()
            For([Int]$F = 0; $F -LT 15; $F++) {
                For([Int]$I = 0; $I -LT 160; $I++) {
                    $StaticSpec[$I] = [Single](0.15 + (0.75 * [Math]::Abs([Math]::Sin(($I * 0.25) + ($F * 0.25)))))
                }
                For([Int]$I = 0; $I -LT 320; $I++) {
                    $StaticWave[$I] = [Single](0.70 * [Math]::Sin(($I * 0.12) + ($F * 0.40)))
                }
                $Viz.RenderFrame($Canvas, $StaticSpec, $StaticWave, $StaticMetrics, 0.0167)
                $null = $Canvas.BuildFrameAnsi($true, '')
            }
            $Sw.Stop()
            [Double]$AvgMs = $Sw.Elapsed.TotalMilliseconds / 15.0
            Assert-True ($AvgMs -LT 10.0) "$($Viz.Name) at 160x48 averaged $([Math]::Round($AvgMs, 2)) ms/frame (must be < 10.0 ms)"
        }

        Assert-True ($Canvas.NativeCanvas.WriteConsoleUtf16('')) 'WriteConsoleUtf16 must accept empty string safely'

        If([Console]::IsOutputRedirected -EQ $true) {
            Assert-False ($Canvas.NativeCanvas.WriteConsoleUtf16('test')) 'WriteConsoleUtf16 must return false on redirected stdout so Write-Host fallback triggers'
        }

        # VERIFY AUDIOANALYZER FFT VERSION CACHING REUSES UNCHANGED BLOCKS AND INVALIDATES ON PUSHBLOCK
        [Type]$AnalyzerType = 'PSBoombox.AudioAnalyzer' -AS [Type]
        [Object]$Analyzer    = $AnalyzerType::new()
        $Analyzer.Configure(44100)

        [Single[]]$BassPcm = [Single[]]::new(1024)
        For([Int]$I = 0; $I -LT 1024; $I++) {
            $BassPcm[$I] = [Single](0.40 * [Math]::Sin((2.0 * [Math]::PI * 100.0 * $I) / 44100.0))
        }
        $Analyzer.PushBlock($BassPcm, 1024, [Single]0.6, [Single]0.6)

        [Single[]]$SpecA1 = $Analyzer.GetSpectrumSnapshot(32)
        [Single[]]$MetA1  = $Analyzer.GetAudioMetrics()
        Assert-True ($MetA1[2] -GT $MetA1[4]) 'Bass metrics should exceed treble on 100 Hz input'

        [Single[]]$TreblePcm = [Single[]]::new(1024)
        For([Int]$I = 0; $I -LT 1024; $I++) {
            $TreblePcm[$I] = [Single](0.40 * [Math]::Sin((2.0 * [Math]::PI * 4000.0 * $I) / 44100.0))
        }
        $Analyzer.PushBlock($TreblePcm, 1024, [Single]0.6, [Single]0.6)

        [Single[]]$MetA2 = $Analyzer.GetAudioMetrics()
        Assert-True ($MetA2[4] -GT $MetA1[4]) 'Pushing new audio block must invalidate FFT cache and update treble metric'
    }

    & $InvokeCase -Name 'Tier 1 WMF Audio Formats (.flac, .m4a, .aac, .mka, .weba), 24-Bit PCM, and 5.1 Downmix' -Body {
        [String[]]$NativeExts = @('.mp3', '.wav', '.wma', '.flac', '.m4a', '.aac', '.mka', '.weba')
        [String[]]$MidiExts   = @('.mid', '.midi')

        [MMMediaPlayer]$ProbePlayer = [MMMediaPlayer]::new()
        Try {
            Foreach($Ext in $NativeExts) {
                [String]$FakePath = "C:\audio\sample$($Ext)"
                Assert-True ([MMDirectoryService]::IsSupportedAudioFile($FakePath)) "DirectoryService must support $($Ext)"
                Assert-True ($ProbePlayer.ShouldUseNativeEngine([MMTrackInfo]::new($FakePath))) "MediaPlayer must route $($Ext) to NativeAudioEngine"
            }
            Foreach($Ext in $MidiExts) {
                [String]$FakeMidi = "C:\audio\sample$($Ext)"
                Assert-True ([MMDirectoryService]::IsSupportedAudioFile($FakeMidi)) "DirectoryService must support $($Ext)"
                Assert-False ($ProbePlayer.ShouldUseNativeEngine([MMTrackInfo]::new($FakeMidi))) "MediaPlayer must route $($Ext) to MCI"
            }
            Assert-False ([MMDirectoryService]::IsSupportedAudioFile('C:\audio\notes.txt')) 'Unsupported .txt must return false'
            Assert-False ([MMDirectoryService]::IsSupportedAudioFile('C:\audio\track.ogg')) 'Unsupported .ogg must return false'
        } Finally {
            $ProbePlayer.Dispose()
        }

        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_Tier1Test_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $TempDir -ItemType Directory -Force

        Try {
            [String]$FlacFile    = Join-Path $TempDir 'tone_440.flac'
            [String]$Wav24File   = Join-Path $TempDir 'stereo_24bit.wav'
            [String]$Wav51File   = Join-Path $TempDir 'surround_center_only.wav'

            New-TestFlacFile -FilePath $FlacFile -FrameCount 50 -FrequencyHz 440.0
            New-TestWavFile -FilePath $Wav24File -DurationMs 550 -SampleRate 44100 -Channels 2 -BitsPerSample 24 -FrequencyHz 440.0
            New-TestWavFile -FilePath $Wav51File -DurationMs 600 -SampleRate 44100 -Channels 6 -BitsPerSample 16 -FrequencyHz 440.0 -ActiveChannel 2

            Foreach($Ext in @('.m4a', '.aac', '.mka', '.weba')) {
                [File]::WriteAllBytes((Join-Path $TempDir "stub$($Ext)"), [Byte[]]@(0x00, 0x01))
            }

            [MMDirectoryService]$DirSvc = [MMDirectoryService]::new($TempDir)
            Assert-Equal ($DirSvc.GetMediaFileCount()) 7 'DirectoryService must discover .flac, .wav (x2), .m4a, .aac, .mka, and .weba files'

            [MMMediaPlayer]$Player = [MMMediaPlayer]::new()
            Try {
                # 1. LIVE NATIVE WMF FLAC PLAYBACK, SEEKING & POST-EQ FFT ANALYSIS
                Assert-True ($Player.LoadAndPlay([MMTrackInfo]::new($FlacFile))) "FLAC playback failed: $($Player.LastError)"
                Assert-True $Player.UsesNativeEngine 'FLAC must play through NativeAudioEngine'
                Assert-True ($Player.IsPlaying()) 'FLAC player state must be Playing'
                Assert-True ($Player.DurationMs -GT 400) "FLAC DurationMs must be > 400, got $($Player.DurationMs)"
                Assert-True ($Player.Pause()) 'FLAC Pause must succeed'
                Assert-True ($Player.Seek(200)) 'FLAC Seek must succeed'
                Assert-True ($Player.Resume()) 'FLAC Resume must succeed'

                Start-Sleep -Milliseconds 120
                [Single[]]$FlacSpec = $Player.GetSpectrumSnapshot(32)
                Assert-Equal $FlacSpec.Length 32 'FLAC spectrum snapshot length mismatch'
                [Single]$FlacPeak = 0.0
                Foreach($Bin in $FlacSpec) { If($Bin -GT $FlacPeak) { $FlacPeak = $Bin } }
                Assert-True ($FlacPeak -GT 0.1) "FLAC FFT spectrum must show post-EQ energy, got peak $($FlacPeak)"
                $Player.Stop()

                # 2. LIVE 24-BIT STEREO WAV PLAYBACK
                Assert-True ($Player.LoadAndPlay([MMTrackInfo]::new($Wav24File))) "24-bit WAV playback failed: $($Player.LastError)"
                Assert-True ($Player.IsPlaying()) '24-bit WAV should be Playing'
                Start-Sleep -Milliseconds 120
                [Single[]]$Metrics24 = $Player.GetAudioMetrics()
                Assert-True ($Metrics24[0] -GT 0.05) "24-bit WAV must decode non-zero audio, got LeftRms=$($Metrics24[0])"
                $Player.Stop()

                # 3. LIVE 6-CHANNEL (5.1) CENTER-ONLY WAV -> ITU-R STEREO DOWNMIX VERIFICATION
                Assert-True ($Player.LoadAndPlay([MMTrackInfo]::new($Wav51File))) "5.1 WAV playback failed: $($Player.LastError)"
                Assert-True ($Player.IsPlaying()) '5.1 WAV should be Playing'
                Start-Sleep -Milliseconds 120
                [Single[]]$Metrics51 = $Player.GetAudioMetrics()
                Assert-True (($Metrics51[0] -GT 0.05) -AND ($Metrics51[1] -GT 0.05)) "5.1 Center channel downmix must fold audio into L/R RMS (got L=$($Metrics51[0]), R=$($Metrics51[1]))"
                $Player.Stop()
            } Finally {
                $Player.Dispose()
            }
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Dynamic Viewport Resizing, Uncapped Full-Buffer Layout, and Buffer-Too-Small Warning Mode' -Body {
        [String]$TempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_ResizeTest_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $TempDir -ItemType Directory -Force

        Try {
            [String]$LongTrackName = 'VeryLongOrchestralSymphonyTrack_' + ('Z' * 90) + '.wav'
            [String]$WavFile       = Join-Path $TempDir $LongTrackName
            New-TestWavFile -FilePath $WavFile -DurationMs 2500

            # 1. UNCAPPED LARGE VIEWPORT (240x70) CONSUMES FULL BUFFER
            [BoomboxCore]$Core = [BoomboxCore]::new($TempDir, '')
            $Core.SetSimulatedViewport(240, 70)
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Large viewport Init transitions to MainPlayer'
            Assert-Equal $Core.LayoutWidth 240 'LayoutWidth must expand uncapped to 240'
            Assert-Equal $Core.LayoutHeight 70 'LayoutHeight must expand uncapped to 70'
            Assert-True ([ATCoordinates]::MaxColumn -GE 244) 'ATCoordinates MaxColumn must expand for 240-col viewport'
            Assert-True ([ATCoordinates]::MaxRow -GE 74) 'ATCoordinates MaxRow must expand for 70-row viewport'
            Assert-Equal $Core.PlaybackPanel.RightBottom.Column.Value 240 'PlaybackPanel must span full 240 width'
            Assert-Equal $Core.DirectoryPanel.RightBottom.Column.Value 120 'DirectoryPanel must occupy left 120 cols'
            Assert-Equal $Core.PlaylistPanel.LeftTop.Column.Value 121 'PlaylistPanel must start at col 121'
            Assert-Equal $Core.PlaylistPanel.RightBottom.Column.Value 240 'PlaylistPanel must end at col 240'
            Assert-Equal $Core.DirectoryPanel.RightBottom.Row.Value 69 'DirectoryPanel must end at row 69'
            Assert-Equal $Core.FooterPanel.StatusLabel.DrawCoordinates.Row.Value 70 'Footer StatusLabel must sit at row 70'
            Assert-Equal $Core.PlaylistPanel.RightBottom.Row.Value 69 'PlaylistPanel must reclaim row 69'
            Assert-Equal $Core.VisualizerCanvas.Width 240 'VisualizerCanvas must expand uncapped to 240 width'
            Assert-Equal $Core.VisualizerCanvas.Height 69 'VisualizerCanvas must expand to 69 rows'
            Assert-True ($Core.PathModal.Width -LE 78) 'PathModal width remains capped <= 78'
            Assert-True ($Core.EqualizerModal.Width -LE 78) 'EqualizerModal width remains capped <= 78'
            Assert-True ($Core.NoticeModal.Width -LE 72) 'NoticeModal width remains capped <= 72'
            Assert-Equal $Core.PathModal.LeftTop.Column.Value ([Int][Math]::Floor((240 - $Core.PathModal.Width) / 2)) 'PathModal centered horizontally at 240 cols'

            # 2. SHRINK TO 80x24 THEN RE-EXPAND TO 180x50
            $Core.PlayTrack([MMTrackInfo]::new($WavFile))
            $Core.SetSimulatedViewport(80, 24)
            $Core.Logic(0.033)
            Assert-Equal $Core.LayoutWidth 80 'Shrink to 80 width updates LayoutWidth'
            Assert-Equal $Core.LayoutHeight 24 'Shrink to 24 height updates LayoutHeight'
            Assert-Equal $Core.PlaybackPanel.Scrubber.BarWidth 52 'Scrubber bar shrinks to 52 at 80 cols'
            Assert-Equal $Core.PlaybackPanel.Scrubber.ProgressBar.MaxRenderedLength 66 'ProgressBar MaxRenderedLength resets on shrink and recomputes to 66'
            Assert-Equal $Core.PlaybackPanel.VolumeControl.VolumeBar.MaxRenderedLength 13 'VolumeBar MaxRenderedLength resets on shrink and recomputes to 13'
            Assert-True ($Core.PlaybackPanel.TrackValueLabel.UserData.Contains('...')) 'Long track title truncates at 80 cols'

            $Core.SetSimulatedViewport(180, 50)
            $Core.Logic(0.033)
            Assert-Equal $Core.LayoutWidth 180 'Re-expand to 180 updates LayoutWidth'
            Assert-Equal $Core.LayoutHeight 50 'Re-expand to 50 updates LayoutHeight'
            Assert-False ($Core.PlaybackPanel.TrackValueLabel.UserData.Contains('...')) 'Long track title un-truncates from RawText when widened to 180 cols'
            Assert-True ($Core.DirectoryPanel.DirectoryList.VisibleItemCount -GT 20) 'DirectoryList visible row count grows on 50-row terminal'
            Assert-True ($Core.PathModal.InteriorClearDirty -EQ $true) 'Modal InteriorClearDirty marked on resize'

            # 3. WARNING MODE FROM DIRECTORY PROMPT PRESERVING UNSAVED INPUT
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'g', [ConsoleKey]::G, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateDirectoryPrompt' 'Entered DirectoryPrompt'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'x', [ConsoleKey]::X, $false, $false, $false))
            $Core.Logic(0.033)
            [String]$TypedPath = $Core.PathModal.PathInput.Text
            Assert-True ($TypedPath.EndsWith('x')) 'Typed character recorded in PathInput'

            $Core.SetSimulatedViewport(79, 24)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' '79x24 enters PBStateBufferTooSmall'
            Assert-Equal $Core.PathModal.PathInput.Text $TypedPath 'Typed PathInput preserved while suspended in Warning Mode'

            $Core.SetSimulatedViewport(130, 36)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateDirectoryPrompt' 'Restoring 130x36 resumes PBStateDirectoryPrompt'
            Assert-Equal $Core.PathModal.PathInput.Text $TypedPath 'Typed PathInput intact after resume'
            Assert-Equal $Core.PathModal.LeftTop.Column.Value ([Int][Math]::Floor((130 - $Core.PathModal.Width) / 2)) 'PathModal re-centered at 130 cols'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Escape exits DirectoryPrompt back to MainPlayer'

            # 4. WARNING MODE FROM EQUALIZER PRESERVING INLINE PRESET NAMING
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateEqualizer' 'Entered Equalizer modal'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'s', [ConsoleKey]::S, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'R', [ConsoleKey]::R, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'s', [ConsoleKey]::S, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True $Core.EqualizerModal.IsNamingPreset 'Equalizer entered inline naming mode'
            [String]$ExpectedPresetInput = $Core.EqualizerModal.PresetNameInput.Text
            Assert-True ($ExpectedPresetInput.EndsWith('Res')) 'Inline preset naming captured typed suffix'

            $Core.SetSimulatedViewport(80, 23)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' '80x23 enters PBStateBufferTooSmall'

            $Core.SetSimulatedViewport(110, 32)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateEqualizer' 'Restoring 110x32 resumes PBStateEqualizer'
            Assert-True $Core.EqualizerModal.IsNamingPreset 'Inline preset naming mode preserved across Warning Mode'
            Assert-Equal $Core.EqualizerModal.PresetNameInput.Text $ExpectedPresetInput 'Inline preset text preserved across Warning Mode'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Returned from Equalizer to MainPlayer'

            # 5. UNIMPEDED GLOBAL PLAYBACK & VISUALIZER SUSPEND/RESUME IN WARNING MODE
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'Entered Visualizer Mode'
            Assert-Equal $Core.TargetFps 60 'Visualizer Mode runs at 60 FPS'

            [Int]$StartVol = $Core.MediaPlayer.Volume.Value
            $Core.SetSimulatedViewport(50, 15)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' '50x15 enters PBStateBufferTooSmall from Visualizer'
            Assert-Equal $Core.TargetFps 30 'Warning Mode restores 30 FPS'
            Assert-True ($Core.MediaPlayer.IsPlaying()) 'Audio continues playing inside Warning Mode'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'+', [ConsoleKey]::Add, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'m', [ConsoleKey]::M, $false, $false, $false))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]' ', [ConsoleKey]::Spacebar, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.MediaPlayer.Volume.Value ([Math]::Min(100, $StartVol + 5)) 'Volume +5% works inside Warning Mode'
            Assert-True $Core.MediaPlayer.IsMuted 'Mute toggle works inside Warning Mode'
            Assert-True ($Core.MediaPlayer.IsPaused()) 'Space pauses playback inside Warning Mode'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]' ', [ConsoleKey]::Spacebar, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True ($Core.MediaPlayer.IsPlaying()) 'Space resumes playback inside Warning Mode'

            $Core.SetSimulatedViewport(160, 44)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'Restoring 160x44 resumes PBStateVisualizer'
            Assert-Equal $Core.TargetFps 60 'Visualizer TargetFps restored to 60 on resume'
            Assert-Equal $Core.VisualizerCanvas.Width 160 'VisualizerCanvas resized to 160 on resume'
            Assert-Equal $Core.VisualizerCanvas.Height 43 'VisualizerCanvas resized to 43 on resume'

            $Core.SetSimulatedViewport(45, 12)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' 'Re-entered Warning Mode'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'s', [ConsoleKey]::S, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True ($Core.MediaPlayer.IsStopped()) 'Stop works inside Warning Mode'

            $Core.SetSimulatedViewport(100, 30)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Stopping inside Visualizer suspend resumes safely to MainPlayer'

            # 6. WARNING RENDERER TIERS & QUIT FROM WARNING MODE
            [PBStateBufferTooSmall]$WarnState = $Core.AppState.States['PBStateBufferTooSmall'] -AS [PBStateBufferTooSmall]
            [String]$Tier1Ansi = $WarnState.BuildWarningAnsi(60, 18, 80, 24)
            [String]$Tier2Ansi = $WarnState.BuildWarningAnsi(20, 4, 80, 24)
            [String]$Tier3Ansi = $WarnState.BuildWarningAnsi(8, 2, 80, 24)
            [String]$Tiny1x1   = $WarnState.BuildWarningAnsi(1, 1, 80, 24)
            Assert-True ($Tier1Ansi.Contains('Terminal Too Small')) 'Tier 1 warning renders boxed title'
            Assert-True ($Tier2Ansi.Contains('Window Too Small')) 'Tier 2 warning renders compact message'
            Assert-True ($Tier3Ansi.Length -GT 0) 'Tier 3 ultra-tiny warning renders safely'
            Assert-Equal $Tiny1x1 '' '1x1 viewport emits no unsafe output'

            $Core.SetSimulatedViewport(40, 10)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' 'Entered Warning Mode for Quit check'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'q', [ConsoleKey]::Q, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateShutdown' 'Q inside Warning Mode triggers Shutdown'
            Assert-False $Core.IsRunning 'IsRunning is false after Quit from Warning Mode'
            $Core.Cleanup()

            # 7. STARTUP BELOW MINIMUM (60x20) ENTERS WARNING MODE DIRECTLY THEN RECOVERS
            [BoomboxCore]$SmallStartCore = [BoomboxCore]::new($TempDir, '')
            $SmallStartCore.SetSimulatedViewport(60, 20)
            $SmallStartCore.InitializeStates()
            $SmallStartCore.Logic(0.016)
            Assert-Equal $SmallStartCore.AppState.CurrentState 'PBStateBufferTooSmall' 'Startup below 80x24 enters PBStateBufferTooSmall directly'

            $SmallStartCore.SetSimulatedViewport(100, 30)
            $SmallStartCore.Logic(0.033)
            Assert-Equal $SmallStartCore.AppState.CurrentState 'PBStateMainPlayer' 'Growing startup viewport from 60x20 to 100x30 enters PBStateMainPlayer'
            Assert-Equal $SmallStartCore.LayoutWidth 100 'Recovered LayoutWidth is 100'
            Assert-Equal $SmallStartCore.LayoutHeight 30 'Recovered LayoutHeight is 30'
            $SmallStartCore.Cleanup()
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Directory Entry Bulk Add (A Key on [DIR])' -Body {
        [String]$RootTemp    = Join-Path ([Path]::GetTempPath()) "PSBoombox_DirAddTest_$([Guid]::NewGuid().ToString('N'))"
        [String]$SubAlbum    = Join-Path $RootTemp 'SubAlbum'
        [String]$SubNested   = Join-Path $SubAlbum 'Nested'
        [String]$EmptyFolder = Join-Path $RootTemp 'EmptyFolder'
        [String]$DeepOnly    = Join-Path $EmptyFolder 'DeepOnly'
        $null = New-Item -Path $SubNested -ItemType Directory -Force
        $null = New-Item -Path $DeepOnly -ItemType Directory -Force

        Try {
            [String]$RootSong    = Join-Path $RootTemp 'root_song.wav'
            [String]$SubTrackA   = Join-Path $SubAlbum 'a_first.wav'
            [String]$SubTrackB   = Join-Path $SubAlbum 'b_second.wav'
            [String]$SubNotes    = Join-Path $SubAlbum 'notes.txt'
            [String]$NestedTrack = Join-Path $SubNested 'deep.wav'
            [String]$EmptyReadme = Join-Path $EmptyFolder 'readme.txt'
            [String]$HiddenTrack = Join-Path $DeepOnly 'hidden.wav'

            New-TestWavFile -FilePath $RootSong -DurationMs 400
            New-TestWavFile -FilePath $SubTrackA -DurationMs 400
            New-TestWavFile -FilePath $SubTrackB -DurationMs 400
            New-TestWavFile -FilePath $NestedTrack -DurationMs 400
            New-TestWavFile -FilePath $HiddenTrack -DurationMs 400
            [File]::WriteAllText($SubNotes, 'ignore me')
            [File]::WriteAllText($EmptyReadme, 'empty dir')

            # 1. SERVICE ENUMERATION TEST (TOP-LEVEL ONLY, SORTED, NON-MUTATING)
            [MMDirectoryService]$DirSvc = [MMDirectoryService]::new($RootTemp)
            [List[MMTrackInfo]]$SubTracks = $DirSvc.GetMediaTracksInDirectory($SubAlbum)
            Assert-Equal $SubTracks.Count 2 'GetMediaTracksInDirectory must return 2 top-level tracks'
            Assert-Equal $SubTracks[0].FullPath $SubTrackA 'First sorted track must be a_first.wav'
            Assert-Equal $SubTracks[1].FullPath $SubTrackB 'Second sorted track must be b_second.wav'
            Assert-Equal $DirSvc.CurrentPath $RootTemp 'GetMediaTracksInDirectory must not change CurrentPath'

            [List[MMTrackInfo]]$MissingTracks = $DirSvc.GetMediaTracksInDirectory((Join-Path $RootTemp 'DoesNotExist'))
            Assert-Equal $MissingTracks.Count 0 'Missing directory must return 0 tracks'
            Assert-True ($DirSvc.LastError.Length -GT 0) 'Missing directory must populate LastError'

            # 2. KEYBOARD INTERACTION IN MAIN PLAYER
            [BoomboxCore]$Core = [BoomboxCore]::new($RootTemp, '')
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Entered MainPlayer'
            Assert-Equal $Core.ActiveFocusZone ([BoomboxFocusZone]::DirectoryBrowser) 'DirectoryBrowser is initially focused'
            Assert-Equal $Core.Playlist.Tracks.Count 1 'CWD auto-populates root_song.wav'

            # INDEX 0: .. (PARENT DIRECTORY) -> NO-OP WITH HELPFUL STATUS
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'a', [ConsoleKey]::A, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.Playlist.Tracks.Count 1 'Pressing A on ParentDirectory must not add tracks'
            Assert-True ($Core.FooterPanel.StatusLabel.UserData.Contains('Select an audio file or directory')) 'ParentDirectory A status prompt mismatch'

            # INDEX 1: [DIR] EMPTYFOLDER (CONTAINS ONLY TXT + NESTED SUBDIR) -> NO-OP
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::DownArrow, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'a', [ConsoleKey]::A, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.Playlist.Tracks.Count 1 'Pressing A on EmptyFolder must not recurse or add tracks'
            Assert-True ($Core.FooterPanel.StatusLabel.UserData.Contains('No supported media files in "EmptyFolder".')) 'EmptyFolder A status mismatch'

            # INDEX 2: [DIR] SUBALBUM -> APPENDS 2 TOP-LEVEL TRACKS WITHOUT NAVIGATING
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::DownArrow, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'a', [ConsoleKey]::A, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.DirectoryService.CurrentPath $RootTemp 'Pressing A on SubAlbum must not navigate away from RootTemp'
            Assert-Equal $Core.Playlist.Tracks.Count 3 'Pressing A on SubAlbum must append 2 tracks'
            Assert-Equal $Core.Playlist.Tracks[1].FullPath $SubTrackA 'Appended track 1 must be a_first.wav'
            Assert-Equal $Core.Playlist.Tracks[2].FullPath $SubTrackB 'Appended track 2 must be b_second.wav'
            Assert-Equal $Core.PlaylistPanel.PlaylistList.Items.Count 3 'PlaylistPanel must reflect 3 tracks'
            Assert-True ($Core.FooterPanel.StatusLabel.UserData.Contains('Added 2 tracks from "SubAlbum"')) 'SubAlbum A status mismatch'

            # INDEX 3: MEDIAFILE ROOT_SONG.WAV -> APPENDS SINGLE TRACK
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::DownArrow, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'a', [ConsoleKey]::A, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.Playlist.Tracks.Count 4 'Pressing A on MediaFile must append single track'
            Assert-True ($Core.FooterPanel.StatusLabel.UserData.Contains('Added "root_song.wav" to playlist')) 'Single MediaFile A status mismatch'

            $Core.Cleanup()
        } Finally {
            Remove-Item -Path $RootTemp -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Directory Browser Compact Path Title' -Body {
        Assert-Equal (Format-CompactDirectoryPath 'C:\Users\Dave\Music\OST\Disc 1') 'C:\..\Disc 1' 'Deep drive path must middle-truncate to root and leaf'
        Assert-Equal (Format-CompactDirectoryPath 'C:\Users\Dave\Music\OST\Disc 1\') 'C:\..\Disc 1' 'Trailing slash must be ignored cleanly'
        Assert-Equal (Format-CompactDirectoryPath 'C:\Music\OST') 'C:\..\OST' 'Two-level path must collapse first segment'
        Assert-Equal (Format-CompactDirectoryPath 'C:\Music') 'C:\Music' 'Single-level directory must keep full path'
        Assert-Equal (Format-CompactDirectoryPath 'C:\') 'C:\' 'Drive root must remain unchanged'
        Assert-Equal (Format-CompactDirectoryPath '\\Server\Share\Users\OST\Disc 1') '\\Server\Share\..\Disc 1' 'UNC path must preserve share root and leaf'

        [String]$TempRoot = Join-Path ([Path]::GetTempPath()) "PSBoombox_CompactTitle_$([Guid]::NewGuid().ToString('N'))"
        [String]$LeafDir  = Join-Path (Join-Path $TempRoot 'OST') 'Disc 1'
        $null = New-Item -Path $LeafDir -ItemType Directory -Force

        Try {
            New-TestWavFile -FilePath (Join-Path $LeafDir 'theme.wav') -DurationMs 300

            [String]$DriveRoot       = [Path]::GetPathRoot($LeafDir)
            [String]$ExpectedTitle   = "Dir: $($DriveRoot)..\Disc 1 (1)"
            [BoomboxCore]$Core       = [BoomboxCore]::new($LeafDir, '')
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.DirectoryPanel.Title $ExpectedTitle 'DirectoryPanel title must display compact root/leaf format'

            $Core.SetSimulatedViewport(160, 44)
            $Core.Logic(0.033)
            Assert-Equal $Core.DirectoryPanel.Title $ExpectedTitle 'DirectoryPanel title must preserve compact root/leaf format after resize'

            $Core.Cleanup()
        } Finally {
            Remove-Item -Path $TempRoot -Recurse -Force -ErrorAction Stop
        }
    }

    & $InvokeCase -Name 'Theming System (Embedded Gogh JSON, Tabbed Live Preview, Cancel Revert, Visualizer Re-Theming, Persistence, and -Theme)' -Body {
        [String]$ThemeCfgDir  = Join-Path ([Path]::GetTempPath()) "PSBoombox_ThemeSuiteCfg_$([Guid]::NewGuid().ToString('N'))"
        [String]$MediaTempDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_ThemeSuiteMedia_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $ThemeCfgDir -ItemType Directory -Force
        $null = New-Item -Path $MediaTempDir -ItemType Directory -Force

        [String]$PrevCfgOverride   = [PBConfigService]::ConfigDirectoryOverride
        [String]$PrevThemeOverride = [UIThemeService]::ConfigDirectoryOverride
        [PBConfigService]::ConfigDirectoryOverride = $ThemeCfgDir
        [UIThemeService]::ConfigDirectoryOverride  = $ThemeCfgDir

        Try {
            New-TestWavFile -FilePath (Join-Path $MediaTempDir 'palette_song.wav') -DurationMs 800

            # 1. EMBEDDED GOGH JSON CATALOG (PSBOOMBOX DEFAULT + 10 DARK + 10 LIGHT)
            [UIThemeService]$Svc = [UIThemeService]::new($ThemeCfgDir)
            Assert-Equal $Svc.AllThemes.Count 21 'Embedded Themes.json must define 21 themes'
            Assert-Equal $Svc.DarkThemes.Count 11 'Dark tab must have PSBoombox Default + 10 Gogh Dark themes'
            Assert-Equal $Svc.LightThemes.Count 10 'Light tab must have 10 Gogh Light themes'
            Assert-Equal $Svc.DarkThemes[0].Name 'PSBoombox Default' 'First Dark theme must be PSBoombox Default'

            $Svc.Load()
            Assert-Equal $Svc.ActiveThemeName 'PSBoombox Default' 'Initial theme defaults to PSBoombox Default'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#0C0C0C' 'Default background hex must be #0C0C0C'

            # 2. OPTION A BACKGROUND, IN-PLACE CACHED COLOR MUTATION & VISUALIZER PALETTES
            [BoomboxCore]$Core = [BoomboxCore]::new($MediaTempDir, '')
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Entered MainPlayer'

            [UILabel]$CachedTrackLabel = $Core.PlaybackPanel.TrackValueLabel
            [Int]$BeforePeakColor     = ($Core.Visualizers[0] -AS [UIVisualizerSpectrum]).PackedPeakColor
            [Int[]]$BeforeSpecPal     = @((($Core.Visualizers[0] -AS [UIVisualizerSpectrum]).PackedPalette))

            # PRESS T -> OPEN TABBED THEME SELECTOR MODAL
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'t', [ConsoleKey]::T, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateThemeSelector' 'T opens PBStateThemeSelector'
            Assert-True ($Core.ThemeModal -IS [UITabContainer]) 'ThemeModal must inherit UITabContainer'
            Assert-Equal $Core.ThemeModal.TabGroup.Tabs.Count 2 'ThemeModal must have 2 tabs (Dark and Light)'
            Assert-Equal $Core.ThemeModal.ActivePageIndex 0 'Dark tab active initially for PSBoombox Default'
            Assert-True ($null -EQ $Core.ThemeModal.PSObject.Properties['DarkApplyButton']) 'ThemeModal must not expose DarkApplyButton'
            Assert-True ($null -EQ $Core.ThemeModal.PSObject.Properties['DarkCancelButton']) 'ThemeModal must not expose DarkCancelButton'
            Assert-True ($null -EQ $Core.ThemeModal.PSObject.Properties['LightApplyButton']) 'ThemeModal must not expose LightApplyButton'
            Assert-True ($null -EQ $Core.ThemeModal.PSObject.Properties['LightCancelButton']) 'ThemeModal must not expose LightCancelButton'
            Assert-Equal $Core.ThemeModal.DarkPanel.UiElementListing.Count 1 'ThemeModal DarkPanel must only contain DarkList'
            Assert-Equal $Core.ThemeModal.LightPanel.UiElementListing.Count 1 'ThemeModal LightPanel must only contain LightList'
            Assert-Equal $Core.ThemeModal.DarkList.DrawCoordinates.Row.Value ($Core.ThemeModal.LeftTop.Row.Value + 2) 'ThemeModal DarkList must have 1 blank padding row below top border'
            Assert-Equal $Core.ThemeModal.LightList.DrawCoordinates.Row.Value ($Core.ThemeModal.LeftTop.Row.Value + 2) 'ThemeModal LightList must have 1 blank padding row below top border'
            $Core.ThemeModal.Resize(100, 30)
            Assert-Equal $Core.ThemeModal.DarkList.DrawCoordinates.Row.Value ($Core.ThemeModal.LeftTop.Row.Value + 2) 'ThemeModal Resize must preserve 1 blank padding row above DarkList'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True $Core.ThemeModal.TabGroupFocused 'Tab in ThemeModal must move focus to TabGroup'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::DownArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-False $Core.ThemeModal.TabGroupFocused 'DownArrow from TabGroup must return focus to ThemeList'

            # PRESS DOWNARROW -> LIVE PREVIEW CATPPUCCIN MOCHA (#1E1E2E)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::DownArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.ThemeService.ActiveThemeName 'Catppuccin Mocha' 'DownArrow must immediately preview Catppuccin Mocha'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#1E1E2E' 'Background mutates live to #1E1E2E'

            # PRESS RIGHTARROW -> SWITCH TO LIGHT TAB & LIVE PREVIEW CATPPUCCIN LATTE (#EFF1F5)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.ThemeModal.ActivePageIndex 1 'RightArrow switches to Light tab'
            Assert-Equal $Core.ThemeService.ActiveThemeName 'Catppuccin Latte' 'Switching to Light tab must immediately preview Catppuccin Latte'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#EFF1F5' 'Light theme background mutates live to #EFF1F5'
            Assert-Equal $CachedTrackLabel.ActiveColor.ToHexString() '#4C4F69' 'Cached UILabel ActiveColor must mutate in place to #4C4F69'
            Assert-True ($CachedTrackLabel.ToAnsiControlSequenceString().Contains('48;2;239;241;245m')) 'Option A rendering must emit 24-bit theme background escape sequence'
            Assert-Equal $Core.VisualizerCanvas.NativeCanvas.DefaultBgRgb 0xEFF1F5 'VisualizerCanvas DefaultBgRgb must track active ThemeBackground'

            [Int]$LightPeakColor = ($Core.Visualizers[0] -AS [UIVisualizerSpectrum]).PackedPeakColor
            [Int[]]$LightSpecPal = @((($Core.Visualizers[0] -AS [UIVisualizerSpectrum]).PackedPalette))
            Assert-True ($LightPeakColor -NE $BeforePeakColor) 'Visualizer PackedPeakColor must re-theme cleanly'
            Assert-True ($LightSpecPal[0] -NE $BeforeSpecPal[0]) 'Visualizer PackedPalette must re-theme cleanly'

            # VERIFY RESIZE + BUFFER-TOO-SMALL SUSPEND/RESUME WHILE THEME MODAL IS OPEN
            $Core.SetSimulatedViewport(70, 20)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' 'Shrinking below 80x24 suspends PBStateThemeSelector cleanly'
            Assert-Equal $Core.ThemeService.ActiveThemeName 'Catppuccin Latte' 'Preview theme stays active in BufferTooSmall'

            $Core.SetSimulatedViewport(110, 32)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateThemeSelector' 'Growing back >= 80x24 resumes PBStateThemeSelector'

            # PRESS ESCAPE -> REVERT BACK TO PRE-MODAL THEME (PSBOOMBOX DEFAULT)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Escape closes PBStateThemeSelector back to MainPlayer'
            Assert-Equal $Core.ThemeService.ActiveThemeName 'PSBoombox Default' 'Cancel must revert ActiveThemeName back to PSBoombox Default'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#0C0C0C' 'Cancel must revert ThemeBackground back to #0C0C0C'
            Assert-Equal $Core.VisualizerCanvas.NativeCanvas.DefaultBgRgb 0x0C0C0C 'Cancel must revert VisualizerCanvas DefaultBgRgb back to 0x0C0C0C'
            [String]$ThemeSuiteCfgPath = Join-Path $ThemeCfgDir 'config.json'
            Assert-True ([File]::Exists($ThemeSuiteCfgPath)) 'config.json must be auto-created on first launch'
            $CancelCfgJson = [File]::ReadAllText($ThemeSuiteCfgPath) | ConvertFrom-Json
            Assert-Equal $CancelCfgJson.Theme.ActiveTheme 'PSBoombox Default' 'Cancel must not persist previewed theme to config.json'

            # 3. APPLY + PERSISTENCE (T -> LIGHT TAB -> ENTER -> CONFIG.JSON -> FRESH LAUNCH)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'t', [ConsoleKey]::T, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]13, [ConsoleKey]::Enter, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Enter applies selected theme and returns to MainPlayer'
            Assert-Equal $Core.ThemeService.ActiveThemeName 'Catppuccin Latte' 'Applied theme must be Catppuccin Latte'
            Assert-True ([File]::Exists($ThemeSuiteCfgPath)) 'Applying theme must write config.json'
            $ApplyCfgJson = [File]::ReadAllText($ThemeSuiteCfgPath) | ConvertFrom-Json
            Assert-Equal $ApplyCfgJson.Theme.ActiveTheme 'Catppuccin Latte' 'Applying theme must persist Theme.ActiveTheme in config.json'
            $Core.Cleanup()

            # RESET COLOR LIBRARY THEN BOOT A FRESH CORE TO TEST PERSISTENCE
            [ColorLibrary]::ResetSemanticDefaults()
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#0C0C0C' 'ResetSemanticDefaults restores #0C0C0C prior to launch'

            [BoomboxCore]$RestartCore = [BoomboxCore]::new($MediaTempDir, '')
            $RestartCore.InitializeStates()
            $RestartCore.Logic(0.016)
            Assert-Equal $RestartCore.ThemeService.ActiveThemeName 'Catppuccin Latte' 'Fresh BoomboxCore launch must restore persisted theme from config.json'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#EFF1F5' 'Restored Light theme background must be #EFF1F5'
            $RestartCore.Cleanup()

            # 4. -THEME OVERRIDE: BUILT-IN NAME & CUSTOM GOGH JSON FILE + INVALID FALLBACK
            [BoomboxCore]$CliNamedCore = [BoomboxCore]::new($MediaTempDir, '', 'Dracula')
            $CliNamedCore.InitializeStates()
            $CliNamedCore.Logic(0.016)
            Assert-Equal $CliNamedCore.ThemeService.ActiveThemeName 'Dracula' '-Theme named override must apply Dracula on startup'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#282A36' 'Dracula background hex must be #282A36'
            Assert-False $CliNamedCore.PendingStartupError 'Valid -Theme must not raise startup error'
            $CliNamedCore.Cleanup()

            [String]$CustomJsonPath = Join-Path $MediaTempDir 'custom_gogh.json'
            [File]::WriteAllText($CustomJsonPath, @'
{
  "name": "Midnight Teal Custom",
  "background": "#112233",
  "foreground": "#DDEEFF",
  "cursor": "#FFCC66",
  "color_01": "#112233",
  "color_02": "#FF6B6B",
  "color_03": "#6BCB77",
  "color_04": "#FFD93D",
  "color_05": "#4D96FF",
  "color_06": "#C77DFF",
  "color_07": "#4ECDC4",
  "color_08": "#DDEEFF",
  "color_09": "#556677",
  "color_10": "#FF8E8E",
  "color_11": "#8CE99A",
  "color_12": "#FFE066",
  "color_13": "#74C0FC",
  "color_14": "#E599F7",
  "color_15": "#66D9E8",
  "color_16": "#FFFFFF"
}
'@)

            [BoomboxCore]$CustomCore = [BoomboxCore]::new($MediaTempDir, '', $CustomJsonPath)
            $CustomCore.InitializeStates()
            $CustomCore.Logic(0.016)
            Assert-Equal $CustomCore.ThemeService.ActiveThemeName 'Midnight Teal Custom' 'Custom Gogh JSON -Theme must load custom theme name'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#112233' 'Custom Gogh JSON background must be #112233'

            # OPEN MODAL -> PREVIEW ANOTHER -> CANCEL -> MUST REVERT TO CUSTOM GOGH THEME
            $CustomCore.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'t', [ConsoleKey]::T, $false, $false, $false))
            $CustomCore.Logic(0.033)
            $CustomCore.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $CustomCore.Logic(0.033)
            Assert-Equal $CustomCore.ThemeService.ActiveThemeName 'Catppuccin Latte' 'Preview switched away from custom theme'
            $CustomCore.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $CustomCore.Logic(0.033)
            Assert-Equal $CustomCore.ThemeService.ActiveThemeName 'Midnight Teal Custom' 'Cancel must revert back to custom -Theme'
            Assert-Equal ([ColorLibrary]::ThemeBackground.ToHexString()) '#112233' 'Cancel must revert background back to custom #112233'
            $CustomCore.Cleanup()

            [BoomboxCore]$BadThemeCore = [BoomboxCore]::new($MediaTempDir, '', 'NonExistentThemeName')
            $BadThemeCore.InitializeStates()
            $BadThemeCore.Logic(0.016)
            Assert-True $BadThemeCore.PendingStartupError 'Unknown -Theme must set PendingStartupError cleanly'
            Assert-Equal $BadThemeCore.ThemeService.ActiveThemeName 'Catppuccin Latte' 'Unknown -Theme falls back safely to persisted theme'
            $BadThemeCore.Cleanup()
        } Finally {
            [PBConfigService]::ConfigDirectoryOverride = $PrevCfgOverride
            [UIThemeService]::ConfigDirectoryOverride  = $PrevThemeOverride
            [ColorLibrary]::ResetSemanticDefaults()
            Remove-Item -Path $ThemeCfgDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $MediaTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    & $InvokeCase -Name 'BurntToast Notification Service (Opt-In, Hotkey, Rules, and Dedicated Runspace)' -Body {
        # 1. DEFAULT / UNAVAILABLE BEHAVIOR WHEN BURNTTOAST IS NOT LOADED
        [MMNotificationService]$UnavailSvc = [MMNotificationService]::new()
        $UnavailSvc.InitializeWithModulePath('', $false)
        Assert-False $UnavailSvc.IsModuleLoaded 'Unavailable BurntToast must keep IsModuleLoaded false'
        Assert-False $UnavailSvc.IsEnabled 'Notifications must start disabled'
        Assert-True ($null -EQ $UnavailSvc.WorkerRunspace) 'No background runspace should be created when BurntToast is missing'

        [Hashtable]$UnavailToggle = $UnavailSvc.ToggleEnabled('')
        Assert-False $UnavailToggle.Changed 'Toggle must report Changed=false when BurntToast is missing'
        Assert-False $UnavailToggle.Enabled 'Toggle must stay disabled when BurntToast is missing'
        Assert-True ($UnavailToggle.Message.Contains('unavailable')) 'Unavailable toggle message mismatch'

        $UnavailSvc.NotifyTrackChange([MMTrackInfo]::new('C:\Music\ignored.wav'))
        $UnavailSvc.DismissNotification()
        $UnavailSvc.Dispose()

        # 2. DETERMINISTIC STATE RULES VIA DISPATCH OVERRIDE
        [System.Collections.Generic.List[Hashtable]]$Events = [System.Collections.Generic.List[Hashtable]]::new()
        [MMNotificationService]$RuleSvc                     = [MMNotificationService]::new()
        $RuleSvc.DispatchOverride = {
            Param(
                [String]$Action,
                [String]$TrackName,
                [Hashtable]$Meta
            )

            $Events.Add(@{
                Action    = $Action
                TrackName = $TrackName
                Meta      = $Meta
            })
        }.GetNewClosure()
        $RuleSvc.InitializeWithModulePath('C:\Fake\BurntToast.psm1', $true)
        Assert-True $RuleSvc.IsModuleLoaded 'Simulated BurntToast path must set IsModuleLoaded=true'
        Assert-False $RuleSvc.IsEnabled 'Notifications must default to opt-in (disabled)'

        [MMTrackInfo]$TrackA = [MMTrackInfo]::new('C:\Music\alpha.wav')
        [MMTrackInfo]$TrackB = [MMTrackInfo]::new('C:\Music\beta.wav')

        # DISABLED -> NO TOAST
        $RuleSvc.NotifyTrackChange($TrackA)
        Assert-Equal $Events.Count 0 'Opt-in off must not dispatch notifications'

        # TOGGLE ON WHILE TRACK A IS PLAYING -> NO TOAST FOR TOGGLE ITSELF, REPEAT SUPPRESSED
        [Hashtable]$OnRes = $RuleSvc.ToggleEnabled($TrackA.FullPath)
        Assert-True $OnRes.Changed 'Toggle on must succeed'
        Assert-True $OnRes.Enabled 'Toggle on must enable notifications'
        Assert-Equal $Events.Count 0 'Toggling on must not fire an immediate toast'

        $RuleSvc.NotifyTrackChange($TrackA)
        Assert-Equal $Events.Count 0 'Re-notifying already-playing Track A must be suppressed'

        # TRACK A -> TRACK B FIRES NOTIFY WITH EXPECTED PAYLOAD
        $RuleSvc.NotifyTrackChange($TrackB)
        Assert-Equal $Events.Count 1 'Changing to Track B must dispatch 1 Notify'
        Assert-Equal $Events[0].Action 'Notify' 'First dispatched action must be Notify'
        Assert-Equal $Events[0].Meta.Lines.Count 3 'Toast must have 3 lines'
        Assert-Equal $Events[0].Meta.Lines[0] 'PSBoombox' 'Toast line 1 must be PSBoombox'
        Assert-Equal $Events[0].Meta.Lines[1] 'Now Playing' 'Toast line 2 must be Now Playing'
        Assert-Equal $Events[0].Meta.Lines[2] 'beta.wav' 'Toast line 3 must be track name'
        Assert-True $Events[0].Meta.Silent 'Toast must use -Silent'
        Assert-Equal $Events[0].Meta.UniqueIdentifier 'PSBoombox_NowPlaying' 'Toast must use fixed UniqueIdentifier'
        Assert-True ($Events[0].Meta.IconPath.Replace('\', '/').EndsWith('/Assets/BTIcon.png')) 'DefaultIconPath must point to Assets/BTIcon.png'

        # REPEAT-ONE / RE-SELECTION OF TRACK B SUPPRESSED
        $RuleSvc.NotifyTrackChange($TrackB)
        Assert-Equal $Events.Count 1 'Repeat-One or re-selecting Track B must be suppressed'

        # DISMISS CLEARS LAST TRACK SO STARTING TRACK B FROM STOPPED FIRES AGAIN
        $RuleSvc.DismissNotification()
        Assert-Equal $Events.Count 2 'DismissNotification must dispatch Dismiss'
        Assert-Equal $Events[1].Action 'Dismiss' 'Second action must be Dismiss'

        $RuleSvc.NotifyTrackChange($TrackB)
        Assert-Equal $Events.Count 3 'Starting Track B from Stopped state must trigger Notify'
        Assert-Equal $Events[2].Action 'Notify' 'Third action must be Notify'

        # TOGGLE OFF DISMISSES AND SUPPRESSES FUTURE NOTIFICATIONS
        [Hashtable]$OffRes = $RuleSvc.ToggleEnabled($TrackB.FullPath)
        Assert-True $OffRes.Changed 'Toggle off must succeed'
        Assert-False $OffRes.Enabled 'Toggle off must disable notifications'
        Assert-Equal $Events.Count 4 'Toggle off must dispatch Dismiss'
        Assert-Equal $Events[3].Action 'Dismiss' 'Fourth action must be Dismiss'

        $RuleSvc.NotifyTrackChange($TrackA)
        Assert-Equal $Events.Count 4 'Disabled service must suppress track changes'

        $RuleSvc.Dispose()
        Assert-Equal $Events.Count 5 'Dispose must dispatch Dispose'
        Assert-Equal $Events[4].Action 'Dispose' 'Fifth action must be Dispose'
        Assert-True $RuleSvc.IsDisposed 'Service must be marked disposed'

        # 3. BOOMBOXCORE INTEGRATION (B HOTKEY, PLAY/PAUSE, STOP, CLEAR, MODE SWITCH, VISUALIZER)
        [String]$CoreMediaDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_BtCore_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $CoreMediaDir -ItemType Directory -Force

        Try {
            New-TestWavFile -FilePath (Join-Path $CoreMediaDir 'song_one.wav') -DurationMs 1500
            New-TestWavFile -FilePath (Join-Path $CoreMediaDir 'song_two.wav') -DurationMs 1500

            [BoomboxCore]$Core = [BoomboxCore]::new($CoreMediaDir, '')
            [System.Collections.Generic.List[Hashtable]]$CoreEvents = [System.Collections.Generic.List[Hashtable]]::new()
            $Core.NotificationService.DispatchOverride = {
                Param(
                    [String]$Action,
                    [String]$TrackName,
                    [Hashtable]$Meta
                )

                $CoreEvents.Add(@{
                    Action    = $Action
                    TrackName = $TrackName
                    Meta      = $Meta
                })
            }.GetNewClosure()

            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Core must reach PBStateMainPlayer'
            $Core.NotificationService.IsModuleLoaded = $true

            # TOGGLE ON VIA B HOTKEY
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'b', [ConsoleKey]::B, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True $Core.NotificationService.IsEnabled 'Pressing B must enable notifications'
            Assert-True ($Core.FooterPanel.StatusLabel.UserData.Contains('BurntToast notifications: On')) 'Footer must show notifications enabled'
            Assert-Equal $CoreEvents.Count 0 'Toggling B on must not emit a toast'

            # START PLAYBACK FROM STOPPED -> NOTIFY SONG ONE
            $Core.PlayTrack($Core.Playlist.SelectIndex(0))
            Assert-Equal $CoreEvents.Count 1 'Starting song_one must notify'
            Assert-Equal $CoreEvents[0].TrackName 'song_one.wav' 'First track name mismatch'

            # RE-SELECT SAME TRACK -> SUPPRESSED
            $Core.PlayTrack($Core.Playlist.GetCurrentTrack())
            Assert-Equal $CoreEvents.Count 1 'Re-playing current track must be suppressed'

            # PAUSE / RESUME -> NO TOAST OR DISMISS (ALSO VERIFY ▶ / ‖ BUTTON GLYPH TOGGLE)
            $Core.PlaybackPanel.SyncFromPlayer($Core.MediaPlayer, $Core.Playlist)
            Assert-Equal $Core.PlaybackPanel.PlayPauseButton.LabelText "`u{2016}" 'PlayPauseButton must show ‖ Unicode glyph while playing'
            $Core.TogglePlayPause()
            Assert-True ($Core.MediaPlayer.IsPaused()) 'Track should be paused'
            $Core.PlaybackPanel.SyncFromPlayer($Core.MediaPlayer, $Core.Playlist)
            Assert-Equal $Core.PlaybackPanel.PlayPauseButton.LabelText "`u{25B6}" 'PlayPauseButton must show ▶ Unicode glyph when paused'
            $Core.TogglePlayPause()
            Assert-True ($Core.MediaPlayer.IsPlaying()) 'Track should be resumed'
            $Core.PlaybackPanel.SyncFromPlayer($Core.MediaPlayer, $Core.Playlist)
            Assert-Equal $Core.PlaybackPanel.PlayPauseButton.LabelText "`u{2016}" 'PlayPauseButton must return to ‖ Unicode glyph when resumed'
            Assert-Equal $CoreEvents.Count 1 'Pause/Resume must not trigger notifications'

            # MODE CHANGE (EQUALIZER MODAL OPEN/CLOSE) -> NO TOAST OR DISMISS
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateEqualizer' 'E opens Equalizer'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Escape closes Equalizer'
            Assert-Equal $CoreEvents.Count 1 'Mode transitions must not trigger notifications'

            # NEXT TRACK VIA N -> NOTIFY SONG TWO
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'n', [ConsoleKey]::N, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $CoreEvents.Count 2 'Skipping to song_two must notify'
            Assert-Equal $CoreEvents[1].Action 'Notify' 'Next track must emit Notify'
            Assert-Equal $CoreEvents[1].TrackName 'song_two.wav' 'Second track name mismatch'

            # ENTER VISUALIZER AND TOGGLE B OFF THEN ON
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'V enters Visualizer'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'b', [ConsoleKey]::B, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-False $Core.NotificationService.IsEnabled 'Pressing B in Visualizer must toggle notifications off'
            Assert-Equal $CoreEvents.Count 3 'Toggling off in Visualizer must dismiss'
            Assert-Equal $CoreEvents[2].Action 'Dismiss' 'Expected Dismiss on toggle off'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'b', [ConsoleKey]::B, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True $Core.NotificationService.IsEnabled 'Pressing B in Visualizer must toggle notifications back on'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'V returns to MainPlayer'

            # STOP PLAYBACK -> DISMISS, THEN PLAY FROM STOPPED -> NOTIFY AGAIN
            $Core.StopPlayback()
            Assert-Equal $CoreEvents.Count 4 'StopPlayback must emit Dismiss'
            Assert-Equal $CoreEvents[3].Action 'Dismiss' 'Expected Dismiss on stop'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]' ', [ConsoleKey]::Spacebar, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $CoreEvents.Count 5 'Starting from stopped via Spacebar must notify'
            Assert-Equal $CoreEvents[4].Action 'Notify' 'Expected Notify when starting from stopped'

            # CLEAR PLAYLIST -> DISMISS
            $Core.ClearPlaylist()
            Assert-Equal $CoreEvents.Count 6 'ClearPlaylist must emit Dismiss'
            Assert-Equal $CoreEvents[5].Action 'Dismiss' 'Expected Dismiss on playlist clear'

            $Core.Cleanup()
            Assert-Equal $CoreEvents.Count 7 'Cleanup must dispose NotificationService'
            Assert-Equal $CoreEvents[6].Action 'Dispose' 'Expected Dispose on cleanup'
        } Finally {
            Remove-Item -Path $CoreMediaDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 4. REAL DEDICATED BACKGROUND RUNSPACE END-TO-END TEST WITH MOCK BURNTTOAST MODULE
        [String]$MockRoot     = Join-Path ([Path]::GetTempPath()) "PSBoombox_BtRunspace_$([Guid]::NewGuid().ToString('N'))"
        [String]$MockModDir   = Join-Path $MockRoot 'BurntToast'
        [String]$MockModPath  = Join-Path $MockModDir 'BurntToast.psm1'
        [String]$MockLogPath  = Join-Path $MockRoot 'bt_calls.jsonl'
        [String]$MockIconPath = Join-Path $MockRoot 'BTIcon.png'
        $null = New-Item -Path $MockModDir -ItemType Directory -Force
        [File]::WriteAllBytes($MockIconPath, [Byte[]]@(0x89, 0x50, 0x4E, 0x47))

        [String]$MockModuleCode = @"
`$Script:BtLogPath = '$($MockLogPath.Replace("'", "''"))'

Function New-BurntToastNotification {
    Param(
        [String[]]`$Text,
        [Switch]`$Silent,
        [String]`$UniqueIdentifier,
        [String]`$AppLogo
    )

    `$Entry = @{
        Command          = 'New-BurntToastNotification'
        Text             = `$Text
        Silent           = `$Silent.IsPresent
        UniqueIdentifier = `$UniqueIdentifier
        AppLogo          = `$AppLogo
    } | ConvertTo-Json -Compress

    [System.IO.File]::AppendAllText(`$Script:BtLogPath, "`$(`$Entry)`n")
}

Function Remove-BTNotification {
    Param(
        [String]`$UniqueIdentifier
    )

    `$Entry = @{
        Command          = 'Remove-BTNotification'
        UniqueIdentifier = `$UniqueIdentifier
    } | ConvertTo-Json -Compress

    [System.IO.File]::AppendAllText(`$Script:BtLogPath, "`$(`$Entry)`n")
}

Export-ModuleMember -Function 'New-BurntToastNotification', 'Remove-BTNotification'
"@
        [File]::WriteAllText($MockModPath, $MockModuleCode)

        [MMNotificationService]$AsyncSvc = [MMNotificationService]::new()

        Try {
            $AsyncSvc.IconPath   = $MockIconPath
            $AsyncSvc.DebounceMs = 80
            $AsyncSvc.InitializeWithModulePath($MockModPath, $false)

            Assert-True ($null -NE $AsyncSvc.WorkerRunspace) 'Up-front dedicated background runspace must be created'

            # WAIT UP TO 3S FOR UP-FRONT WORKER MODULE IMPORT
            [System.Diagnostics.Stopwatch]$Sw = [System.Diagnostics.Stopwatch]::StartNew()
            While(($AsyncSvc.SharedState['WorkerReady'] -NE $true) -AND ($AsyncSvc.SharedState['WorkerFailed'] -NE $true) -AND ($Sw.ElapsedMilliseconds -LT 3000)) {
                [System.Threading.Thread]::Sleep(15)
            }
            Assert-True ([Boolean]$AsyncSvc.SharedState['WorkerReady']) 'Dedicated background runspace must import BurntToast cleanly'

            $null = $AsyncSvc.ToggleEnabled('')

            # RAPID-SKIP 4 TRACKS -> LATEST-WINS DEBOUNCE MUST ONLY EMIT TRACK 4
            $AsyncSvc.NotifyTrackChange([MMTrackInfo]::new('C:\Music\Track1.wav'))
            $AsyncSvc.NotifyTrackChange([MMTrackInfo]::new('C:\Music\Track2.wav'))
            $AsyncSvc.NotifyTrackChange([MMTrackInfo]::new('C:\Music\Track3.wav'))
            $AsyncSvc.NotifyTrackChange([MMTrackInfo]::new('C:\Music\Track4.wav'))

            $Sw.Restart()
            While((([File]::Exists($MockLogPath) -EQ $false) -OR ([File]::ReadAllLines($MockLogPath).Length -LT 1)) -AND ($Sw.ElapsedMilliseconds -LT 2500)) {
                [System.Threading.Thread]::Sleep(20)
            }
            [System.Threading.Thread]::Sleep(150)

            Assert-True ([File]::Exists($MockLogPath)) 'Mock BurntToast log must exist after debounce'
            [String[]]$Lines1 = [File]::ReadAllLines($MockLogPath)
            Assert-Equal $Lines1.Length 1 'Rapid-skipping 4 tracks must coalesce into exactly 1 toast notification'

            $NotifyObj = $Lines1[0] | ConvertFrom-Json
            Assert-Equal $NotifyObj.Command 'New-BurntToastNotification' 'Expected New-BurntToastNotification call'
            Assert-Equal $NotifyObj.Text.Count 3 'Async toast must have 3 lines'
            Assert-Equal $NotifyObj.Text[0] 'PSBoombox' 'Async toast line 1 mismatch'
            Assert-Equal $NotifyObj.Text[1] 'Now Playing' 'Async toast line 2 must be Now Playing'
            Assert-Equal $NotifyObj.Text[2] 'Track4.wav' 'Async toast line 3 must reflect latest-wins Track4.wav'
            Assert-True ([Boolean]$NotifyObj.Silent) 'Async toast must pass -Silent'
            Assert-Equal $NotifyObj.UniqueIdentifier 'PSBoombox_NowPlaying' 'Async toast must pass -UniqueIdentifier'
            Assert-Equal $NotifyObj.AppLogo $MockIconPath 'Async toast must pass -AppLogo when icon exists'

            # EXPLICIT DISMISS -> REMOVE-BTNOTIFICATION
            $AsyncSvc.DismissNotification()
            $Sw.Restart()
            While(([File]::ReadAllLines($MockLogPath).Length -LT 2) -AND ($Sw.ElapsedMilliseconds -LT 2000)) {
                [System.Threading.Thread]::Sleep(20)
            }

            [String[]]$Lines2 = [File]::ReadAllLines($MockLogPath)
            Assert-Equal $Lines2.Length 2 'DismissNotification must invoke Remove-BTNotification'
            $DismissObj = $Lines2[1] | ConvertFrom-Json
            Assert-Equal $DismissObj.Command 'Remove-BTNotification' 'Expected Remove-BTNotification call on dismiss'
            Assert-Equal $DismissObj.UniqueIdentifier 'PSBoombox_NowPlaying' 'Dismiss must pass UniqueIdentifier'

            # DISPATCH ANOTHER TOAST, THEN VERIFY DISPOSE (QUIT) EXPLICITLY REMOVES IT
            $AsyncSvc.NotifyTrackChange([MMTrackInfo]::new('C:\Music\Track1.wav'))
            $Sw.Restart()
            While(([File]::ReadAllLines($MockLogPath).Length -LT 3) -AND ($Sw.ElapsedMilliseconds -LT 2500)) {
                [System.Threading.Thread]::Sleep(20)
            }

            $AsyncSvc.Dispose()
            Assert-True ($null -EQ $AsyncSvc.WorkerRunspace) 'Dispose must clean up WorkerRunspace'

            [String[]]$Lines3 = [File]::ReadAllLines($MockLogPath)
            Assert-Equal $Lines3.Length 4 'Dispose with active toast must invoke Remove-BTNotification'
            $ShutdownObj = $Lines3[3] | ConvertFrom-Json
            Assert-Equal $ShutdownObj.Command 'Remove-BTNotification' 'Expected Remove-BTNotification on Dispose'
            Assert-Equal $ShutdownObj.UniqueIdentifier 'PSBoombox_NowPlaying' 'Shutdown dismiss must pass UniqueIdentifier'
        } Finally {
            $AsyncSvc.Dispose()
            Remove-Item -Path $MockRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    & $InvokeCase -Name 'Centralized config.json (Auto-Create, Legacy Migration, Malformed Fallback, and Missing BurntToast Startup Modal)' -Body {
        # 1. AUTO-CREATION OF GROUPED CONFIG.JSON ON FIRST LAUNCH
        [String]$AutoDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_CfgAuto_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $AutoDir -ItemType Directory -Force

        Try {
            [PBConfigService]$AutoCfg = [PBConfigService]::new($AutoDir)
            $AutoCfg.Load()

            [String]$AutoFile = Join-Path $AutoDir 'config.json'
            Assert-True ([File]::Exists($AutoFile)) 'config.json must be auto-created on first launch'
            Assert-False $AutoCfg.DidMigrateLegacyFiles 'Fresh directory must not flag legacy migration'

            $AutoParsed = [File]::ReadAllText($AutoFile) | ConvertFrom-Json
            Assert-Equal $AutoParsed.Version 1 'Schema Version must be 1'
            Assert-Equal $AutoParsed.Theme.ActiveTheme 'PSBoombox Default' 'Default Theme.ActiveTheme mismatch'
            Assert-Equal $AutoParsed.Equalizer.ActivePreset 'Flat' 'Default Equalizer.ActivePreset mismatch'
            Assert-False ([Boolean]$AutoParsed.Equalizer.Enabled) 'Default Equalizer.Enabled must be false'
            Assert-Equal $AutoParsed.Equalizer.Bands.Count 10 'Default Equalizer.Bands must have 10 bands'
            Assert-False ([Boolean]$AutoParsed.Notifications.BurntToastEnabled) 'Default Notifications.BurntToastEnabled must be false'
        } Finally {
            Remove-Item -Path $AutoDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 2. DEPRECATED LEGACY MIGRATION (THEME.JSON + EQUALIZER.JSON -> CONFIG.JSON + CLEANUP)
        [String]$MigDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_CfgMig_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $MigDir -ItemType Directory -Force

        Try {
            [String]$LegacyThemePath = Join-Path $MigDir 'theme.json'
            [String]$LegacyEqPath    = Join-Path $MigDir 'equalizer.json'

            [File]::WriteAllText($LegacyThemePath, '{"Version":1,"ActiveTheme":"Catppuccin Mocha","CustomThemePath":""}')
            [File]::WriteAllText($LegacyEqPath, '{"Version":1,"Enabled":true,"ActivePreset":"Legacy Mix","PreampDb":2,"Bands":[1,2,3,0,0,0,-1,-2,3,4],"UserPresets":[{"Name":"Legacy Mix","PreampDb":2,"Bands":[1,2,3,0,0,0,-1,-2,3,4]}]}')

            [PBConfigService]$MigCfg = [PBConfigService]::new($MigDir)
            $MigCfg.Load()

            Assert-True $MigCfg.DidMigrateLegacyFiles 'DidMigrateLegacyFiles must be true after importing legacy files'
            Assert-True ([File]::Exists((Join-Path $MigDir 'config.json'))) 'Migrated config.json must exist'
            Assert-False ([File]::Exists($LegacyThemePath)) 'Legacy theme.json must be removed after migration'
            Assert-False ([File]::Exists($LegacyEqPath)) 'Legacy equalizer.json must be removed after migration'
            Assert-Equal $MigCfg.ThemeActiveTheme 'Catppuccin Mocha' 'Migrated Theme must preserve Catppuccin Mocha'
            Assert-True $MigCfg.EqualizerEnabled 'Migrated Equalizer.Enabled must preserve true'
            Assert-Equal $MigCfg.EqualizerActivePreset 'Legacy Mix' 'Migrated Equalizer.ActivePreset must preserve Legacy Mix'
            Assert-Equal $MigCfg.EqualizerBands[9] 4 'Migrated Equalizer.Bands must preserve values'
            Assert-Equal $MigCfg.EqualizerUserPresets.Count 1 'Migrated Equalizer.UserPresets must preserve custom preset'
            Assert-False $MigCfg.BurntToastEnabled 'Migrated config must default BurntToastEnabled to false'
        } Finally {
            Remove-Item -Path $MigDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 3. MALFORMED JSON & MALFORMED FIELD FALLBACK
        [String]$BadDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_CfgBad_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $BadDir -ItemType Directory -Force

        Try {
            [String]$BadFile    = Join-Path $BadDir 'config.json'
            [String]$BrokenText = '{ "Version": 1, "Theme": { broken json'
            [File]::WriteAllText($BadFile, $BrokenText)

            [PBConfigService]$BrokenCfg = [PBConfigService]::new($BadDir)
            $BrokenCfg.Load()
            Assert-True ($BrokenCfg.LastError.Length -GT 0) 'Broken JSON must record LastError'
            Assert-Equal $BrokenCfg.ThemeActiveTheme 'PSBoombox Default' 'Broken JSON must fall back to default theme'
            Assert-False $BrokenCfg.BurntToastEnabled 'Broken JSON must fall back to BurntToastEnabled=false'
            Assert-Equal ([File]::ReadAllText($BadFile)) $BrokenText 'Broken config.json must not be overwritten on load'

            # PARTIALLY MALFORMED SECTIONS: VALID THEME SURVIVES, INVALID FIELDS FALL BACK CLEANLY
            [File]::WriteAllText($BadFile, '{"Version":1,"Theme":{"ActiveTheme":"Dracula","CustomThemePath":""},"Equalizer":{"Enabled":"bad","PreampDb":"oops","Bands":"not_array"},"Notifications":{"BurntToastEnabled":"notabool"}}')
            [PBConfigService]$PartialCfg = [PBConfigService]::new($BadDir)
            $PartialCfg.Load()
            Assert-Equal $PartialCfg.ThemeActiveTheme 'Dracula' 'Valid Theme section must still load despite malformed sibling fields'
            Assert-False $PartialCfg.EqualizerEnabled 'Malformed Equalizer.Enabled must fall back to false'
            Assert-Equal $PartialCfg.EqualizerPreampDb 0 'Malformed Equalizer.PreampDb must fall back to 0'
            Assert-False $PartialCfg.BurntToastEnabled 'Malformed Notifications.BurntToastEnabled must fall back to false'
        } Finally {
            Remove-Item -Path $BadDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 4. BURNTTOAST TOGGLE PERSISTENCE & NON-CLOBBERING ACROSS SECTIONS
        [String]$PersistDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_BtPersist_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $PersistDir -ItemType Directory -Force

        Try {
            [PBConfigService]$Cfg1 = [PBConfigService]::new($PersistDir)
            $Cfg1.Load()
            $Cfg1.SetThemeSection('Dracula', '')
            $null = $Cfg1.Save()

            [MMNotificationService]$Notif1 = [MMNotificationService]::new($Cfg1)
            $Notif1.InitializeWithModulePath('C:\Fake\BurntToast.psm1', $true)
            [Hashtable]$TogOn = $Notif1.ToggleEnabled('')
            Assert-True $TogOn.Enabled 'ToggleEnabled must turn BurntToast on'

            [PBConfigService]$Cfg2 = [PBConfigService]::new($PersistDir)
            $Cfg2.Load()
            Assert-True $Cfg2.BurntToastEnabled 'BurntToastEnabled=true must persist in config.json'
            Assert-Equal $Cfg2.ThemeActiveTheme 'Dracula' 'Saving BurntToastEnabled must not clobber Theme section'

            [MMNotificationService]$Notif2 = [MMNotificationService]::new($Cfg2)
            $Notif2.InitializeWithModulePath('C:\Fake\BurntToast.psm1', $true)
            Assert-True $Notif2.IsEnabled 'Fresh MMNotificationService must restore IsEnabled=true when BurntToast is loaded'
            Assert-False $Notif2.NeedsMissingModuleNotice 'NeedsMissingModuleNotice must be false when BurntToast is loaded'

            [Hashtable]$TogOff = $Notif2.ToggleEnabled('')
            Assert-False $TogOff.Enabled 'ToggleEnabled must turn BurntToast off'

            [PBConfigService]$Cfg3 = [PBConfigService]::new($PersistDir)
            $Cfg3.Load()
            Assert-False $Cfg3.BurntToastEnabled 'BurntToastEnabled=false must persist in config.json'
        } Finally {
            Remove-Item -Path $PersistDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 5. STARTUP MISSING-BURNTTOAST MODAL (Q PRESERVES SETTING, CONTINUE SILENTLY DISABLES)
        [String]$ModalCfgDir   = Join-Path ([Path]::GetTempPath()) "PSBoombox_BtModalCfg_$([Guid]::NewGuid().ToString('N'))"
        [String]$ModalMediaDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_BtModalMedia_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $ModalCfgDir -ItemType Directory -Force
        $null = New-Item -Path $ModalMediaDir -ItemType Directory -Force

        [String]$PrevAppCfg = [PBConfigService]::ConfigDirectoryOverride
        [PBConfigService]::ConfigDirectoryOverride = $ModalCfgDir

        Try {
            New-TestWavFile -FilePath (Join-Path $ModalMediaDir 'sample.wav') -DurationMs 500
            [File]::WriteAllText((Join-Path $ModalCfgDir 'config.json'), '{"Version":1,"Notifications":{"BurntToastEnabled":true}}')

            # PATH A: USER PRESSES Q ON STARTUP MODAL -> QUITS AND PRESERVES BURNTTOASTENABLED=TRUE
            [BoomboxCore]$QuitCore = [BoomboxCore]::new($ModalMediaDir, '')
            $QuitCore.InitializeStates()
            $QuitCore.Logic(0.016)
            Assert-Equal $QuitCore.AppState.CurrentState 'PBStateNoticeModal' 'Startup with BurntToastEnabled=true and missing module must show PBStateNoticeModal'
            Assert-True $QuitCore.NoticeModal.AllowQuit 'Missing BurntToast startup modal must allow Quit via Q'
            Assert-False $QuitCore.NotificationService.IsEnabled 'Runtime notifications must stay disabled when BurntToast is missing'

            $QuitCore.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'q', [ConsoleKey]::Q, $false, $false, $false))
            $QuitCore.Logic(0.033)
            Assert-Equal $QuitCore.AppState.CurrentState 'PBStateShutdown' 'Pressing Q on startup notice modal must transition to PBStateShutdown'
            $QuitCore.Cleanup()

            $AfterQuitJson = [File]::ReadAllText((Join-Path $ModalCfgDir 'config.json')) | ConvertFrom-Json
            Assert-True ([Boolean]$AfterQuitJson.Notifications.BurntToastEnabled) 'Quitting from startup modal must preserve BurntToastEnabled=true in config.json'

            # PATH B: USER PRESSES ENTER TO CONTINUE -> SILENTLY DISABLES CONFIG SETTING & B STAYS UNAVAILABLE
            [BoomboxCore]$ContCore = [BoomboxCore]::new($ModalMediaDir, '')
            $ContCore.InitializeStates()
            $ContCore.Logic(0.016)
            Assert-Equal $ContCore.AppState.CurrentState 'PBStateNoticeModal' 'Second launch must still show PBStateNoticeModal while BurntToastEnabled=true'

            $ContCore.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]13, [ConsoleKey]::Enter, $false, $false, $false))
            $ContCore.Logic(0.033)
            Assert-Equal $ContCore.AppState.CurrentState 'PBStateMainPlayer' 'Pressing Enter on startup notice modal must continue to PBStateMainPlayer'
            Assert-False $ContCore.NoticeModal.AllowQuit 'AllowQuit must reset after modal dismissal'

            $AfterContJson = [File]::ReadAllText((Join-Path $ModalCfgDir 'config.json')) | ConvertFrom-Json
            Assert-False ([Boolean]$AfterContJson.Notifications.BurntToastEnabled) 'Continuing past startup modal must silently set BurntToastEnabled=false in config.json'

            $ContCore.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'b', [ConsoleKey]::B, $false, $false, $false))
            $ContCore.Logic(0.033)
            Assert-False $ContCore.NotificationService.IsEnabled 'Pressing B afterwards without BurntToast loaded must remain disabled'
            Assert-True ($ContCore.FooterPanel.StatusLabel.UserData.Contains('unavailable')) 'Pressing B afterwards must display standard unavailable message'
            $ContCore.Cleanup()
        } Finally {
            [PBConfigService]::ConfigDirectoryOverride = $PrevAppCfg
            Remove-Item -Path $ModalCfgDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $ModalMediaDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    & $InvokeCase -Name 'Tabbed F1 Help Modal and Reclaimed Hint Rows' -Body {
        [String]$HelpCfgDir   = Join-Path ([Path]::GetTempPath()) "PSBoombox_HelpCfg_$([Guid]::NewGuid().ToString('N'))"
        [String]$HelpMediaDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_HelpTest_$([Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $HelpCfgDir -ItemType Directory -Force
        $null = New-Item -Path $HelpMediaDir -ItemType Directory -Force

        [String]$PrevHelpCfgOverride = [PBConfigService]::ConfigDirectoryOverride
        [PBConfigService]::ConfigDirectoryOverride = $HelpCfgDir

        Try {
            New-TestWavFile -FilePath (Join-Path $HelpMediaDir 'help_track.wav') -DurationMs 1500

            [BoomboxCore]$Core = [BoomboxCore]::new($HelpMediaDir, '')
            $Core.SetSimulatedViewport(80, 24)
            $Core.InitializeStates()
            $Core.Logic(0.016)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Core must reach PBStateMainPlayer'

            # 1. VERIFY HINT REMOVAL & RECLAIMED ROWS ACROSS ALL 4 MODES
            Assert-True ($null -EQ $Core.FooterPanel.PSObject.Properties['HintLabel']) 'UIStatusFooterPanel must not expose HintLabel'
            Assert-True ($null -EQ $Core.PSObject.Properties['VisualizerHintLabel']) 'BoomboxCore must not expose VisualizerHintLabel'
            Assert-Equal $Core.FooterPanel.StatusLabel.DrawCoordinates.Row.Value 24 'Footer StatusLabel must sit at row 24 (LayoutHeight)'
            Assert-Equal $Core.DirectoryPanel.RightBottom.Row.Value 23 'DirectoryPanel must extend to row 23'
            Assert-Equal $Core.PlaylistPanel.RightBottom.Row.Value 23 'PlaylistPanel must extend to row 23'
            Assert-Equal $Core.VisualizerCanvas.Height 23 'VisualizerCanvas must reclaim row to height 23'
            Assert-Equal $Core.VisualizerTrackLabel.DrawCoordinates.Row.Value 24 'VisualizerTrackLabel must sit at row 24'
            Assert-Equal $Core.EqualizerModal.Height 15 'EqualizerModal height must shrink to 15'
            Assert-Equal $Core.ThemeModal.Height 14 'ThemeModal height must shrink to 14'

            # 2. CLEAN NON-INSTRUCTIONAL FOOTER STATUS ON EQUALIZER / THEMES & F1 IGNORED OUTSIDE MAIN
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'e', [ConsoleKey]::E, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateEqualizer' 'E opens Equalizer'
            Assert-Equal $Core.FooterPanel.StatusLabel.UserData.TrimEnd() 'Status: Equalizer' 'Equalizer status must have no instructional text'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::F1, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateEqualizer' 'F1 must not open Help from Equalizer mode'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Escape closes Equalizer'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'t', [ConsoleKey]::T, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateThemeSelector' 'T opens Theme Selector'
            Assert-False ($Core.FooterPanel.StatusLabel.UserData.Contains('Enter to apply')) 'Theme preview status must have no instructional text'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::F1, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateThemeSelector' 'F1 must not open Help from Theme Selector mode'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Escape closes Theme Selector'

            # START TRACK -> ENTER VISUALIZER -> VERIFY F1 IGNORED IN VISUALIZER
            $Core.PlayTrack($Core.Playlist.SelectIndex(0))
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'V opens Visualizer'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::F1, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateVisualizer' 'F1 must not open Help from Visualizer mode'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'v', [ConsoleKey]::V, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'V returns to MainPlayer'

            # 3. H CONTINUES TO TOGGLE SHUFFLE IN MAINPLAYER
            Assert-False $Core.Playlist.ShuffleEnabled 'Shuffle defaults to false'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'h', [ConsoleKey]::H, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-True $Core.Playlist.ShuffleEnabled 'H must still toggle Shuffle On'

            # 4. F1 OPENS TABBED HELP MODAL IN MAINPLAYER, TABS & SCROLL & RESIZE & CLOSE
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::F1, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateHelp' 'F1 must open PBStateHelp from MainPlayer'
            Assert-True ($Core.HelpModal -IS [UITabContainer]) 'HelpModal must inherit UITabContainer'
            Assert-Equal $Core.HelpModal.TabGroup.Tabs.Count 5 'HelpModal must expose 5 tabs'
            Assert-Equal $Core.HelpModal.TabGroup.Tabs[0].LabelText 'Global' 'Tab 0 must be Global'
            Assert-Equal $Core.HelpModal.TabGroup.Tabs[1].LabelText 'Playback' 'Tab 1 must be Playback'
            Assert-Equal $Core.HelpModal.TabGroup.Tabs[2].LabelText 'Viz' 'Tab 2 must be Viz'
            Assert-Equal $Core.HelpModal.TabGroup.Tabs[3].LabelText 'EQ' 'Tab 3 must be EQ'
            Assert-Equal $Core.HelpModal.TabGroup.Tabs[4].LabelText 'Themes' 'Tab 4 must be Themes'
            Assert-Equal $Core.HelpModal.ActivePageIndex 0 'HelpModal must open on Global tab'
            Assert-Equal $Core.HelpModal.ContentTopRow ($Core.HelpModal.LeftTop.Row.Value + 2) 'HelpModal must have 1 blank padding row below top border'
            Assert-True ($null -EQ $Core.HelpModal.PSObject.Properties['CloseButtons']) 'HelpModal must not expose CloseButtons'
            Assert-Equal $Core.HelpModal.GetActiveContentPanel().UiElementListing.Count 0 'HelpModal tab panels must not contain a Close button'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 1 'Tab in HelpModal must advance to next tab when Close button is removed'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Tab, $true, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 0 'Shift+Tab in HelpModal must cycle back to previous tab'
            [UITab]$LastHelpTab = $Core.HelpModal.TabGroup.Tabs[4]
            Assert-True (($LastHelpTab.DrawCoordinates.Column.Value + $LastHelpTab.GetRenderedWidth() - 1) -LT $Core.HelpModal.RightBottom.Column.Value) 'All 5 Help tabs must fit inside 80-col modal width'

            # RIGHTARROW CYCLES ALL 5 TABS AND WRAPS; LEFTARROW WRAPS BACK
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 1 'RightArrow switches to Playback tab'

            # VERIFY PLAYBACK TAB STRUCTURED SECTIONS & READ-ONLY SCROLLING WITH ARROWS
            [System.Collections.Generic.List[Hashtable]]$PbRows = $Core.HelpModal.GetActiveRows()
            Assert-True (($PbRows | Where-Object { $_.Kind -EQ 'Header' }).Count -EQ 4) 'Playback tab must define 4 styled section headers'
            Assert-True (($PbRows | Where-Object { $_.Kind -EQ 'Blank' }).Count -EQ 3) 'Playback tab must separate sections with blank rows'
            Assert-True ($Core.HelpModal.ActivePageHasOverflow()) 'Playback tab must overflow at 80x24'
            Assert-False ($Core.HelpModal.ActivePageCanScrollUp()) 'Playback tab at top cannot scroll up'
            Assert-True ($Core.HelpModal.ActivePageCanScrollDown()) 'Playback tab at top can scroll down'

            [String]$PbTopAnsi = $Core.HelpModal.BuildActivePageContentAnsi()
            Assert-True ($PbTopAnsi.Contains("`u{25BC}")) 'Overflowing Help page at top must render down arrow'
            Assert-False ($PbTopAnsi.Contains("`u{25B2}")) 'Overflowing Help page at top must not render up arrow'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::DownArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal ($Core.HelpModal.GetActiveScrollOffset()) 1 'DownArrow scrolls active Help page down by 1'
            [String]$PbMidAnsi = $Core.HelpModal.BuildActivePageContentAnsi()
            Assert-True ($PbMidAnsi.Contains("`u{25B2}") -AND $PbMidAnsi.Contains("`u{25BC}")) 'Scrolled middle Help page must render both up and down arrows'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::End, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal ($Core.HelpModal.GetActiveScrollOffset()) ($Core.HelpModal.GetActiveMaxScrollOffset()) 'End jumps Help page to bottom'
            [String]$PbEndAnsi = $Core.HelpModal.BuildActivePageContentAnsi()
            Assert-True ($PbEndAnsi.Contains("`u{25B2}")) 'Help page at bottom must render up arrow'
            Assert-False ($PbEndAnsi.Contains("`u{25BC}")) 'Help page at bottom must not render down arrow'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::Home, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal ($Core.HelpModal.GetActiveScrollOffset()) 0 'Home jumps Help page back to top'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 2 'RightArrow switches to Viz tab'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 3 'RightArrow switches to EQ tab'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 4 'RightArrow switches to Themes tab'
            Assert-False ($Core.HelpModal.ActivePageHasOverflow()) 'Themes tab fits without overflow at 80x24'
            [String]$ThemesPageAnsi = $Core.HelpModal.BuildActivePageContentAnsi()
            Assert-False ($ThemesPageAnsi.Contains("`u{25B2}") -OR $ThemesPageAnsi.Contains("`u{25BC}")) 'Non-overflowing Help page must omit scroll arrows'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::RightArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 0 'RightArrow wraps from Themes back to Global'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::LeftArrow, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.HelpModal.ActivePageIndex 4 'LeftArrow wraps from Global back to Themes'

            # BUFFER TOO SMALL SUSPEND / RESUME FOR PBSTATEHELP
            $Core.SetSimulatedViewport(70, 20)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateBufferTooSmall' 'Shrinking below 80x24 suspends PBStateHelp'
            $Core.SetSimulatedViewport(100, 28)
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateHelp' 'Restoring >= 80x24 resumes PBStateHelp'

            # ESC CLOSES HELP; F1 REOPENS AND F1 AGAIN CLOSES HELP
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]27, [ConsoleKey]::Escape, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'Esc closes Help back to MainPlayer'

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::F1, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateHelp' 'F1 reopens Help'
            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]0, [ConsoleKey]::F1, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateMainPlayer' 'F1 inside Help closes back to MainPlayer'

            $Core.Cleanup()
        } Finally {
            [PBConfigService]::ConfigDirectoryOverride = $PrevHelpCfgOverride
            Remove-Item -Path $HelpCfgDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $HelpMediaDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    & $InvokeCase -Name 'List Selection Accent Background Highlight (No Chevron, Focus States, and Theme Adaptation)' -Body {
        Try {
            [ColorLibrary]::ResetSemanticDefaults()

            # 1. NO SELECTION CHEVRON & RECLAIMED 2 COLUMNS ON NON-PLAYING ROWS
            Assert-True ($null -EQ ([UIListItem] -AS [Type]).GetField('SelectionIndicator')) 'UIListItem must no longer define SelectionIndicator'

            [UIList]$TestList = [UIList]::new([ATCoordinates]::new(2, 3), @('alpha.mp3', 'beta.mp3', 'gamma.mp3'), 5)
            $TestList.SetMaxDisplayWidth(24)
            $TestList.Activate($null)
            $TestList.Focus($null)

            [UIListItem]$SelectedItem   = $TestList.Items[0]
            [UIListItem]$UnselectedItem = $TestList.Items[1]

            Assert-False ($SelectedItem.UserData.Contains("`u{2771}")) 'Selected item must not display chevron glyph'
            Assert-True ($SelectedItem.UserData.StartsWith('alpha.mp3')) 'Non-playing selected item must reclaim leading chevron columns'
            Assert-True ($UnselectedItem.UserData.StartsWith('beta.mp3')) 'Non-playing unselected item must reclaim leading chevron columns'

            # 2. PLAYING INDICATOR RETAINED
            $UnselectedItem.SetPlaying($true)
            Assert-True ($UnselectedItem.UserData.StartsWith("`u{25B6} beta.mp3")) 'Playing item must keep playing triangle prefix'

            # 3. FOCUSED VS UNFOCUSED VS UNSELECTED BACKGROUND SEQUENCES
            [String]$FocusedSelBgSeq = [ATBackgroundColor24]::new([ColorLibrary]::UIListItemSelectedBg).ToAnsiControlSequenceString()
            [String]$UnfocSelBgSeq   = [ATBackgroundColor24]::new([ColorLibrary]::UIListItemSelectedUnfocusedBg).ToAnsiControlSequenceString()
            [String]$NormalBgSeq     = [ATControlSequences]::GenerateThemeBgString()

            Assert-True ($SelectedItem.ToAnsiControlSequenceString().Contains($FocusedSelBgSeq)) 'Focused selected item must emit UIListItemSelectedBg'
            Assert-True ($UnselectedItem.ToAnsiControlSequenceString().Contains($NormalBgSeq)) 'Unselected item must emit ThemeBackground'

            $TestList.Unfocus($null)
            Assert-True ($SelectedItem.ToAnsiControlSequenceString().Contains($UnfocSelBgSeq)) 'Unfocused selected item must emit UIListItemSelectedUnfocusedBg'

            # 4. THEME ADAPTATION & CONTRAST ACROSS DARK AND LIGHT THEMES
            [UIThemeService]$ThemeSvc = [UIThemeService]::new()
            $SelectedItem.SetCustomActiveColor([ColorLibrary]::BoomboxDirEntry)
            $TestList.Focus($null)

            Assert-True ($ThemeSvc.ApplyThemeByNameOrPath('Catppuccin Mocha', $false)) 'Catppuccin Mocha theme must apply'
            [String]$DarkSelBgHex = [ColorLibrary]::UIListItemSelectedBg.ToHexString()
            Assert-True ($DarkSelBgHex -NE [ColorLibrary]::ThemeBackground.ToHexString()) 'Dark theme selected bg must differ from ThemeBackground'
            Assert-True (([TrueColor]::GetContrastRatio($SelectedItem.ResolveForegroundColor(), [ColorLibrary]::UIListItemSelectedBg)) -GE 4.5) 'Dark theme custom entry contrast >= 4.5 on selected bg'
            Assert-True (([TrueColor]::GetContrastRatio($UnselectedItem.ResolveForegroundColor(), [ColorLibrary]::ThemeBackground)) -GE 3.0) 'Dark theme playing entry contrast >= 3.0'

            Assert-True ($ThemeSvc.ApplyThemeByNameOrPath('Catppuccin Latte', $false)) 'Catppuccin Latte theme must apply'
            [String]$LightSelBgHex = [ColorLibrary]::UIListItemSelectedBg.ToHexString()
            Assert-True ($LightSelBgHex -NE $DarkSelBgHex) 'Light theme selected bg must adapt away from Dark theme bg'
            Assert-True ($LightSelBgHex -NE [ColorLibrary]::ThemeBackground.ToHexString()) 'Light theme selected bg must differ from Light ThemeBackground'
            Assert-True (([TrueColor]::GetContrastRatio($SelectedItem.ResolveForegroundColor(), [ColorLibrary]::UIListItemSelectedBg)) -GE 4.5) 'Light theme custom entry contrast >= 4.5 on selected bg'
            # 5. ENDEMIC UILIST SCROLL INDICATORS (OVERFLOW VS NON-OVERFLOW)
            Assert-False ($TestList.HasOverflow()) '3-item list in 5-row viewport must not overflow'
            Assert-Equal ($TestList.GetEffectiveItemWidth()) 24 'Non-overflowing UIList preserves full MaxDisplayWidth'
            [String]$NoOverflowAnsi = $TestList.ToAnsiControlSequenceString()
            Assert-False ($NoOverflowAnsi.Contains("`u{25B2}") -OR $NoOverflowAnsi.Contains("`u{25BC}")) 'Non-overflowing UIList must omit scroll arrows'

            [UIList]$OverflowList = [UIList]::new([ATCoordinates]::new(2, 3), @('item1', 'item2', 'item3', 'item4', 'item5', 'item6', 'item7', 'item8'), 4)
            $OverflowList.SetMaxDisplayWidth(24)
            $OverflowList.Activate($null)
            $OverflowList.Focus($null)

            Assert-True ($OverflowList.HasOverflow()) '8-item list in 4-row viewport must overflow'
            Assert-Equal ($OverflowList.GetEffectiveItemWidth()) 22 'Overflowing UIList must reserve 2 cols for right-edge scroll gutter'
            Assert-False ($OverflowList.CanScrollUp()) 'Overflowing UIList at top cannot scroll up'
            Assert-True ($OverflowList.CanScrollDown()) 'Overflowing UIList at top can scroll down'
            [String]$ListTopAnsi = $OverflowList.ToAnsiControlSequenceString()
            Assert-True ($ListTopAnsi.Contains("`u{25BC}")) 'Overflowing UIList at top must emit down arrow'
            Assert-False ($ListTopAnsi.Contains("`u{25B2}")) 'Overflowing UIList at top must not emit up arrow'

            $OverflowList.SelectIndex(5)
            Assert-True ($OverflowList.CanScrollUp()) 'Overflowing UIList in middle can scroll up'
            Assert-True ($OverflowList.CanScrollDown()) 'Overflowing UIList in middle can scroll down'
            [String]$ListMidAnsi = $OverflowList.ToAnsiControlSequenceString()
            Assert-True ($ListMidAnsi.Contains("`u{25B2}") -AND $ListMidAnsi.Contains("`u{25BC}")) 'Overflowing UIList in middle must emit both arrows'

            $OverflowList.MoveEnd()
            Assert-True ($OverflowList.CanScrollUp()) 'Overflowing UIList at bottom can scroll up'
            Assert-False ($OverflowList.CanScrollDown()) 'Overflowing UIList at bottom cannot scroll down'
            [String]$ListEndAnsi = $OverflowList.ToAnsiControlSequenceString()
            Assert-True ($ListEndAnsi.Contains("`u{25B2}")) 'Overflowing UIList at bottom must emit up arrow'
            Assert-False ($ListEndAnsi.Contains("`u{25BC}")) 'Overflowing UIList at bottom must not emit down arrow'
        } Finally {
            [ColorLibrary]::ResetSemanticDefaults()
        }
    }
        } Finally {
            [PBConfigService]::ConfigDirectoryOverride    = ''
            [MMEqualizerService]::ConfigDirectoryOverride = ''
            [UIThemeService]::ConfigDirectoryOverride     = ''
            [ColorLibrary]::ResetSemanticDefaults()
            If([Directory]::Exists($IsolatedConfigDir) -EQ $true) {
                Remove-Item -Path $IsolatedConfigDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            If([Directory]::Exists($IsolatedEqConfigDir) -EQ $true) {
                Remove-Item -Path $IsolatedEqConfigDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            If([Directory]::Exists($IsolatedThemeConfigDir) -EQ $true) {
                Remove-Item -Path $IsolatedThemeConfigDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    })

    & $ModuleTestRunner ${function:Invoke-TestCase} $PSScriptRoot
} Else {
    Write-Host '[SKIP] Remaining test suites skipped because module failed to load.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host "Test Summary: $($PassedCount) passed, $($FailedCount) failed." -ForegroundColor ($FailedCount -EQ 0 ? 'Cyan' : 'Red')

If($FailedCount -GT 0) {
    Foreach($Err in $Errors) {
        Write-Host "  - $($Err)" -ForegroundColor Red
    }

    Exit 1
}

Exit 0
