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

        [String]$IsolatedEqConfigDir = Join-Path ([Path]::GetTempPath()) "PSBoombox_EqCfgTest_$([Guid]::NewGuid().ToString('N'))"
        [MMEqualizerService]::ConfigDirectoryOverride = $IsolatedEqConfigDir

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
            Assert-True ([File]::Exists((Join-Path $CfgTemp 'equalizer.json'))) 'equalizer.json must be written to disk'

            [MMEqualizerService]$Svc2 = [MMEqualizerService]::new($CfgTemp)
            $Svc2.Load()
            Assert-True $Svc2.Enabled 'Persisted Enabled=true must load on startup'
            Assert-Equal $Svc2.ActivePresetName 'Studio Cans' 'Persisted ActivePreset must load on startup'
            Assert-Equal $Svc2.BandGainsDb[1] 12 'Persisted band gains must load cleanly'
            Assert-True ($Svc2.IsActivePresetDeletable()) 'Custom preset should be marked deletable'

            [String]$PrevOverride = [MMEqualizerService]::ConfigDirectoryOverride
            [MMEqualizerService]::ConfigDirectoryOverride = $CfgTemp
            [String]$EmptyMediaDir = Join-Path $CfgTemp 'EmptyDir'
            $null = New-Item -Path $EmptyMediaDir -ItemType Directory -Force
            [BoomboxCore]$RestartCore = [BoomboxCore]::new($EmptyMediaDir, '')
            $RestartCore.InitializeStates()
            $RestartCore.Logic(0.016)
            Assert-True $RestartCore.EqualizerService.Enabled 'Fresh BoomboxCore startup must load Enabled=true from equalizer.json'
            Assert-Equal $RestartCore.EqualizerService.ActivePresetName 'Studio Cans' 'Fresh BoomboxCore startup must restore saved custom preset'
            $RestartCore.Cleanup()
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
        } Finally {
            [MMEqualizerService]::ConfigDirectoryOverride = ''
            If([Directory]::Exists($IsolatedEqConfigDir) -EQ $true) {
                Remove-Item -Path $IsolatedEqConfigDir -Recurse -Force -ErrorAction SilentlyContinue
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
