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
        Assert-False ([Regex]::IsMatch($RawText, '\bAdd-Type\b')) "$($CodeFile.Name) must not use Add-Type / inline C#"
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
                Assert-True ($StagedLargePath.Length -GT 0) 'Large ID3v2 MP3 should use staged temp file'
                Assert-True ([File]::Exists($StagedLargePath)) 'Staged temp file should exist during playback'
                Assert-True ($Player.IsPlaying()) 'Large ID3v2 MP3 should be Playing'
                Assert-True ($Player.DurationMs -GT 0) "Large ID3v2 MP3 DurationMs should be > 0, got $($Player.DurationMs)"
                Assert-True ($Player.Pause()) 'Large ID3v2 MP3 Pause should succeed'
                Assert-True ($Player.Seek(200)) 'Large ID3v2 MP3 Seek should succeed'
                Assert-True ($Player.Resume()) 'Large ID3v2 MP3 Resume should succeed'
                $Player.Stop()
                Assert-False ([File]::Exists($StagedLargePath)) 'Stop() must delete staged temp file'

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

            $Core.EnqueueSyntheticKey([ConsoleKeyInfo]::new([Char]'q', [ConsoleKey]::Q, $false, $false, $false))
            $Core.Logic(0.033)
            Assert-Equal $Core.AppState.CurrentState 'PBStateShutdown' 'Q transitions to Shutdown'
            Assert-False $Core.IsRunning 'IsRunning should be false on Shutdown'

            $Core.Cleanup()
        } Finally {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
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
