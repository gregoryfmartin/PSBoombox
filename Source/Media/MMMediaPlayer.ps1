using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest





###############################################################################
#
# MM MEDIA PLAYER
#
# HIGH-LEVEL AUDIO PLAYBACK CONTROLLER WRAPPING WINDOWS MULTIMEDIA (WINMM) MCI
# COMMANDS AND DRIVEN BY SMPLAYBACKSTATEMACHINE.
#
###############################################################################

Class MMMediaPlayer {
    [SMPlaybackStateMachine]$PlaybackStateMachine
    [Dictionary[String, List[ScriptBlock]]]$StateEvents
    [String]$MciAlias
    [MMTrackInfo]$CurrentTrack
    [Int]$PositionMs
    [Int]$DurationMs
    [ClampableInt]$Volume
    [Boolean]$IsMuted
    [Boolean]$HasOpenAlias
    [Boolean]$UsesWaveOutFallback
    [Boolean]$HasSavedWaveVolume
    [UInt32]$OriginalWaveVolume
    [Double]$PollTimer
    [Double]$PollIntervalSeconds
    [String]$LastError
    [String]$StagedTempFilePath
    [Int]$StageSequence
    [MMEqualizerService]$EqualizerService
    [Object]$NativeEngine
    [Boolean]$UsesNativeEngine
    [ScriptBlock]$OnStateChanged
    [ScriptBlock]$OnTrackEnded
    [ScriptBlock]$OnError

    MMMediaPlayer() {
        $this.PlaybackStateMachine = [SMPlaybackStateMachine]::new()
        $this.StateEvents          = [Dictionary[String, List[ScriptBlock]]]::new()
        $this.MciAlias             = 'psb_audio'
        $this.CurrentTrack         = $null
        $this.PositionMs           = 0
        $this.DurationMs           = 0
        $this.Volume               = [ClampableInt]::new(70, 0, 100)
        $this.IsMuted              = $false
        $this.HasOpenAlias         = $false
        $this.UsesWaveOutFallback  = $false
        $this.HasSavedWaveVolume   = $false
        $this.OriginalWaveVolume   = [UInt32]0
        $this.PollTimer            = 0.0
        $this.PollIntervalSeconds  = 0.2
        $this.LastError            = ''
        $this.StagedTempFilePath   = ''
        $this.StageSequence        = 0
        $this.EqualizerService     = $null
        $this.NativeEngine         = [MMEqualizerEngineNative]::CreateEngine()
        $this.UsesNativeEngine     = $false
        $this.OnStateChanged       = $null
        $this.OnTrackEnded         = $null
        $this.OnError              = $null
    }

    [Context]PrepareContext() {
        Return [Context]::new(@{
            [SMPlaybackStateMachine]::ContextMediaPlayer = $this
        })
    }

    [Void]Subscribe(
        [String]$EventName,
        [ScriptBlock]$Action
    ) {
        If($this.StateEvents.ContainsKey($EventName) -EQ $false) {
            $this.StateEvents[$EventName] = [List[ScriptBlock]]::new()
        }

        $this.StateEvents[$EventName].Add($Action)
    }

    [Void]Publish(
        [String]$EventName,
        [Context]$Context
    ) {
        If($this.StateEvents.ContainsKey($EventName) -EQ $true) {
            Foreach($Action in $this.StateEvents[$EventName]) {
                $Action.Invoke($Context)
            }
        }
    }

    [PlaybackState]GetPlaybackState() {
        Return $this.PlaybackStateMachine.GetPlaybackState()
    }

    [Boolean]IsPlaying() {
        Return ($this.PlaybackStateMachine.CurrentState -EQ [SMPlaybackStateMachine]::StatePlaying)
    }

    [Boolean]IsPaused() {
        Return ($this.PlaybackStateMachine.CurrentState -EQ [SMPlaybackStateMachine]::StatePaused)
    }

    [Boolean]IsStopped() {
        Return ($this.PlaybackStateMachine.CurrentState -EQ [SMPlaybackStateMachine]::StateStopped)
    }

    [Void]NotifyStateChanged() {
        If($null -NE $this.OnStateChanged) {
            $this.OnStateChanged.Invoke($this)
        }
    }

    [Void]CleanupStagedFile() {
        If($this.StagedTempFilePath.Length -GT 0) {
            Try {
                If([File]::Exists($this.StagedTempFilePath) -EQ $true) {
                    [File]::Delete($this.StagedTempFilePath)
                }
            } Catch {
                # IGNORE TEMP FILE CLEANUP ERRORS
            }

            $this.StagedTempFilePath = ''
        }
    }

    [Boolean]IsValidMpegFrameHeader(
        [Byte[]]$Buffer,
        [Int]$Offset
    ) {
        If(($null -EQ $Buffer) -OR ($Offset -LT 0) -OR (($Offset + 4) -GT $Buffer.Length)) {
            Return $false
        }

        If(($Buffer[$Offset] -NE 0xFF) -OR (($Buffer[$Offset + 1] -BAND 0xE0) -NE 0xE0)) {
            Return $false
        }

        [Int]$VersionBits = ($Buffer[$Offset + 1] -SHR 3) -BAND 0x03
        [Int]$LayerBits   = ($Buffer[$Offset + 1] -SHR 1) -BAND 0x03
        [Int]$BitrateIdx  = ($Buffer[$Offset + 2] -SHR 4) -BAND 0x0F
        [Int]$SampleIdx   = ($Buffer[$Offset + 2] -SHR 2) -BAND 0x03

        If(($VersionBits -EQ 1) -OR ($LayerBits -EQ 0) -OR ($BitrateIdx -EQ 0) -OR ($BitrateIdx -EQ 15) -OR ($SampleIdx -EQ 3)) {
            Return $false
        }

        Return $true
    }

    [Int]ComputeMpegFrameLength(
        [Byte[]]$Buffer,
        [Int]$Offset
    ) {
        If($this.IsValidMpegFrameHeader($Buffer, $Offset) -EQ $false) {
            Return 0
        }

        [Int]$VersionBits = ($Buffer[$Offset + 1] -SHR 3) -BAND 0x03
        [Int]$LayerBits   = ($Buffer[$Offset + 1] -SHR 1) -BAND 0x03
        [Int]$BitrateIdx  = ($Buffer[$Offset + 2] -SHR 4) -BAND 0x0F
        [Int]$SampleIdx   = ($Buffer[$Offset + 2] -SHR 2) -BAND 0x03
        [Int]$Padding     = ($Buffer[$Offset + 2] -SHR 1) -BAND 0x01
        [Int]$BitrateKbps = 0

        If($VersionBits -EQ 3) {
            Switch($LayerBits) {
                3 {
                    [Int[]]$Mpeg1L1 = @(0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0)
                    $BitrateKbps    = $Mpeg1L1[$BitrateIdx]

                    Break
                }

                2 {
                    [Int[]]$Mpeg1L2 = @(0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0)
                    $BitrateKbps    = $Mpeg1L2[$BitrateIdx]

                    Break
                }

                1 {
                    [Int[]]$Mpeg1L3 = @(0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0)
                    $BitrateKbps    = $Mpeg1L3[$BitrateIdx]

                    Break
                }
            }
        } Else {
            If($LayerBits -EQ 3) {
                [Int[]]$Mpeg2L1 = @(0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0)
                $BitrateKbps    = $Mpeg2L1[$BitrateIdx]
            } Else {
                [Int[]]$Mpeg2L23 = @(0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0)
                $BitrateKbps     = $Mpeg2L23[$BitrateIdx]
            }
        }

        If($BitrateKbps -LE 0) {
            Return 0
        }

        [Int]$SampleRate = 0

        Switch($VersionBits) {
            3 {
                [Int[]]$RatesV1 = @(44100, 48000, 32000)
                $SampleRate     = $RatesV1[$SampleIdx]

                Break
            }

            2 {
                [Int[]]$RatesV2 = @(22050, 24000, 16000)
                $SampleRate     = $RatesV2[$SampleIdx]

                Break
            }

            0 {
                [Int[]]$RatesV25 = @(11025, 12000, 8000)
                $SampleRate      = $RatesV25[$SampleIdx]

                Break
            }
        }

        If($SampleRate -LE 0) {
            Return 0
        }

        [Int]$BitrateBps = $BitrateKbps * 1000

        If($LayerBits -EQ 3) {
            Return ([Int][Math]::Floor((12 * $BitrateBps) / $SampleRate) + $Padding) * 4
        }

        [Int]$Coeff = (($LayerBits -EQ 1) -AND ($VersionBits -NE 3)) ? 72 : 144

        Return [Int][Math]::Floor(($Coeff * $BitrateBps) / $SampleRate) + $Padding
    }

    [Int64]FindFirstMpegAudioOffset(
        [FileStream]$Stream
    ) {
        If(($null -EQ $Stream) -OR ($Stream.Length -LE 10)) {
            Return [Int64]0
        }

        [Int64]$BaseOffset = [Int64]0
        [Byte[]]$Id3Header = [Byte[]]::new(10)

        # SKIP ONE OR MORE LEADING ID3V2 TAGS SO DIRECTSHOW MPEG SPLITTER DOES NOT FAIL WITH ERROR 277
        While(($BaseOffset + 10) -LE $Stream.Length) {
            $Stream.Position = $BaseOffset
            [Int]$ReadHdr    = $Stream.Read($Id3Header, 0, 10)

            If($ReadHdr -LT 10) {
                Break
            }

            [Boolean]$HasId3Magic = ($Id3Header[0] -EQ 0x49) -AND ($Id3Header[1] -EQ 0x44) -AND ($Id3Header[2] -EQ 0x33)
            [Boolean]$ValidSync   = ($Id3Header[6] -LT 0x80) -AND ($Id3Header[7] -LT 0x80) -AND ($Id3Header[8] -LT 0x80) -AND ($Id3Header[9] -LT 0x80)

            If(($HasId3Magic -EQ $false) -OR ($ValidSync -EQ $false)) {
                Break
            }

            [Int64]$TagBodySize = ([Int64]$Id3Header[6] -SHL 21) -BOR ([Int64]$Id3Header[7] -SHL 14) -BOR ([Int64]$Id3Header[8] -SHL 7) -BOR [Int64]$Id3Header[9]
            [Int64]$FooterSize  = (($Id3Header[5] -BAND 0x10) -NE 0) ? [Int64]10 : [Int64]0
            $BaseOffset        += ([Int64]10 + $TagBodySize + $FooterSize)
        }

        If($BaseOffset -GE $Stream.Length) {
            Return [Int64]0
        }

        [Int]$MaxScanBytes = [Int][Math]::Min([Int64]262144, ($Stream.Length - $BaseOffset))

        If($MaxScanBytes -LT 4) {
            Return $BaseOffset
        }

        [Byte[]]$ScanBuf = [Byte[]]::new($MaxScanBytes)
        $Stream.Position = $BaseOffset
        [Int]$BytesRead  = $Stream.Read($ScanBuf, 0, $MaxScanBytes)

        If($BytesRead -LT 4) {
            Return $BaseOffset
        }

        [Int]$SearchLimit = $BytesRead - 4

        # PASS 1: LOCATE TWO CONSECUTIVE VALID MPEG FRAMES WITH MATCHING VERSION/LAYER
        For([Int]$Pos = 0; $Pos -LE $SearchLimit; $Pos++) {
            If($this.IsValidMpegFrameHeader($ScanBuf, $Pos) -EQ $false) {
                Continue
            }

            [Int]$FrameLen = $this.ComputeMpegFrameLength($ScanBuf, $Pos)

            If(($FrameLen -GE 24) -AND (($Pos + $FrameLen + 4) -LE $BytesRead)) {
                If($this.IsValidMpegFrameHeader($ScanBuf, ($Pos + $FrameLen)) -EQ $true) {
                    If(($ScanBuf[$Pos + 1] -BAND 0x1E) -EQ ($ScanBuf[$Pos + $FrameLen + 1] -BAND 0x1E)) {
                        Return ($BaseOffset + [Int64]$Pos)
                    }
                }
            }
        }

        # PASS 2: FALLBACK TO FIRST VALID SINGLE MPEG FRAME HEADER
        For([Int]$Pos = 0; $Pos -LE $SearchLimit; $Pos++) {
            If($this.IsValidMpegFrameHeader($ScanBuf, $Pos) -EQ $true) {
                Return ($BaseOffset + [Int64]$Pos)
            }
        }

        Return $BaseOffset
    }

    [String]CreateStagedPlaybackFile(
        [String]$SourcePath,
        [Boolean]$StripMpegHeaders
    ) {
        $this.CleanupStagedFile()
        $this.StageSequence++

        [String]$Ext      = [Path]::GetExtension($SourcePath).ToLowerInvariant()
        [String]$SafeExt  = ($Ext.Length -GT 0) ? $Ext : '.mp3'
        [Int]$ProcessId   = [Environment]::ProcessId
        [String]$TempPath = [Path]::Combine([Path]::GetTempPath(), "psb_$($ProcessId)_$($this.StageSequence)$($SafeExt)")

        [FileStream]$SourceStream = $null
        [FileStream]$DestStream   = $null

        Try {
            $SourceStream        = [FileStream]::new($SourcePath, [FileMode]::Open, [FileAccess]::Read, [FileShare]::ReadWrite)
            [Int64]$StartOffset  = [Int64]0

            If($StripMpegHeaders -EQ $true) {
                $StartOffset = $this.FindFirstMpegAudioOffset($SourceStream)
            }

            If(($StartOffset -LT 0) -OR ($StartOffset -GE $SourceStream.Length)) {
                $StartOffset = [Int64]0
            }

            $SourceStream.Position = $StartOffset
            $DestStream            = [FileStream]::new($TempPath, [FileMode]::Create, [FileAccess]::Write, [FileShare]::None)
            $SourceStream.CopyTo($DestStream, 65536)
        } Finally {
            If($null -NE $DestStream) {
                $DestStream.Dispose()
            }

            If($null -NE $SourceStream) {
                $SourceStream.Dispose()
            }
        }

        $this.StagedTempFilePath = $TempPath

        Return [MMWinMMNative]::GetShortPath($TempPath)
    }

    [Boolean]ShouldUseNativeEngine(
        [MMTrackInfo]$Track
    ) {
        If($null -EQ $Track) {
            Return $false
        }

        Return ($Track.Extension -IN @('.mp3', '.wav', '.wma'))
    }

    [Boolean]IsEqualizerBypassedForCurrentTrack() {
        Return (($null -NE $this.CurrentTrack) -AND ($this.UsesNativeEngine -EQ $false) -AND ($this.IsStopped() -EQ $false))
    }

    [Void]ApplyEqualizerFromService() {
        If(($null -NE $this.NativeEngine) -AND ($null -NE $this.EqualizerService)) {
            $this.NativeEngine.SetEqualizerState(
                $this.EqualizerService.Enabled,
                [Double]$this.EqualizerService.PreampDb,
                $this.EqualizerService.GetBandGainsAsDoubleArray()
            )
        }
    }

    [Void]CloseCurrentAlias() {
        If($this.UsesNativeEngine -EQ $true) {
            If($null -NE $this.NativeEngine) {
                $this.NativeEngine.Stop()
            }

            $this.UsesNativeEngine = $false
            $this.HasOpenAlias     = $false
        } Elseif($this.HasOpenAlias -EQ $true) {
            $null = [MMWinMMNative]::SendCommand("stop $($this.MciAlias)")
            $null = [MMWinMMNative]::SendCommand("close $($this.MciAlias)")

            $this.HasOpenAlias = $false
        }

        $this.CleanupStagedFile()
    }

    [Boolean]LoadAndPlay(
        [MMTrackInfo]$Track
    ) {
        If(($null -EQ $Track) -OR ([File]::Exists($Track.FullPath) -EQ $false)) {
            $this.LastError = ($null -NE $Track) ? "Track file not found: $($Track.FullPath)" : 'No track specified.'

            If($this.PlaybackStateMachine.CurrentState -NE [SMPlaybackStateMachine]::StateStopped) {
                $this.CloseCurrentAlias()

                If($this.PlaybackStateMachine.CurrentState -NE [SMPlaybackStateMachine]::StateError) {
                    $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionLoadFailed, $this.PrepareContext())
                }
            }

            $this.NotifyStateChanged()

            If($null -NE $this.OnError) {
                $this.OnError.Invoke($this.LastError)
            }

            Return $false
        }

        $this.CloseCurrentAlias()

        $this.LastError    = ''
        $this.CurrentTrack = $Track
        $this.PositionMs   = 0
        $this.DurationMs   = 0
        $this.PollTimer    = 0.0

        [Context]$Ctx = $this.PrepareContext()

        $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionLoad, $Ctx)

        If(($this.ShouldUseNativeEngine($Track) -EQ $true) -AND ($null -NE $this.NativeEngine)) {
            $this.NativeEngine.SetVolume($this.Volume.Value, $this.IsMuted)
            $this.ApplyEqualizerFromService()

            [Boolean]$NativeOpened = $this.NativeEngine.LoadAndPlay($Track.FullPath)

            If(($NativeOpened -EQ $false) -AND ($Track.Extension -EQ '.mp3')) {
                Try {
                    [String]$StagedMp3Path = $this.CreateStagedPlaybackFile($Track.FullPath, $true)
                    $NativeOpened          = $this.NativeEngine.LoadAndPlay($StagedMp3Path)
                } Catch {
                    # FALL THROUGH TO SHORT PATH RETRY
                }
            }

            If(($NativeOpened -EQ $false) -AND ($Track.FullPath.Length -GT 120)) {
                [String]$ShortPath = [MMWinMMNative]::GetShortPath($Track.FullPath)

                If(($ShortPath.Length -GT 0) -AND ($ShortPath -NE $Track.FullPath)) {
                    $NativeOpened = $this.NativeEngine.LoadAndPlay($ShortPath)
                }
            }

            If($NativeOpened -EQ $false) {
                $this.CleanupStagedFile()

                [String]$NativeErr = $this.NativeEngine.LastError
                $this.LastError    = "Unable to open '$($Track.FileName)': $($NativeErr)"

                $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionLoadFailed, $Ctx)
                $this.NotifyStateChanged()

                If($null -NE $this.OnError) {
                    $this.OnError.Invoke($this.LastError)
                }

                Return $false
            }

            $this.UsesNativeEngine    = $true
            $this.HasOpenAlias        = $true
            $this.UsesWaveOutFallback = $false
            $this.DurationMs          = [Math]::Max(0, $this.NativeEngine.DurationMs)
            $Track.DurationMs         = $this.DurationMs

            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionPlayReady, $Ctx)
            $this.NotifyStateChanged()

            Return $true
        }

        [String]$OpenTargetPath = ($Track.FullPath.Length -GT 120) ? [MMWinMMNative]::GetShortPath($Track.FullPath) : $Track.FullPath
        [String]$QuotedPath     = "`"$($OpenTargetPath)`""
        [Hashtable]$OpenResult  = [MMWinMMNative]::SendCommand("open $($QuotedPath) type mpegvideo alias $($this.MciAlias)")

        If(($OpenResult.Success -EQ $false) -AND ($Track.Extension -EQ '.mp3')) {
            Try {
                [String]$StagedMp3Path = $this.CreateStagedPlaybackFile($Track.FullPath, $true)
                $OpenResult            = [MMWinMMNative]::SendCommand("open `"$($StagedMp3Path)`" type mpegvideo alias $($this.MciAlias)")
            } Catch {
                # FALL THROUGH TO NEXT RETRY STRATEGY
            }
        }

        If(($OpenResult.Success -EQ $false) -AND (($OpenResult.ErrorCode -EQ [UInt32]268) -OR ($OpenTargetPath.Length -GT 120))) {
            Try {
                [String]$StagedRawPath = $this.CreateStagedPlaybackFile($Track.FullPath, $false)
                $OpenResult            = [MMWinMMNative]::SendCommand("open `"$($StagedRawPath)`" type mpegvideo alias $($this.MciAlias)")

                If($OpenResult.Success -EQ $false) {
                    $OpenResult = [MMWinMMNative]::SendCommand("open `"$($StagedRawPath)`" alias $($this.MciAlias)")
                }
            } Catch {
                # FALL THROUGH TO DEFAULT DEVICE RETRY
            }
        }

        If($OpenResult.Success -EQ $false) {
            $OpenResult = [MMWinMMNative]::SendCommand("open $($QuotedPath) alias $($this.MciAlias)")
        }

        If($OpenResult.Success -EQ $false) {
            $this.CleanupStagedFile()

            $this.LastError = "Unable to open '$($Track.FileName)': $($OpenResult.ErrorMessage)"

            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionLoadFailed, $Ctx)
            $this.NotifyStateChanged()

            If($null -NE $this.OnError) {
                $this.OnError.Invoke($this.LastError)
            }

            Return $false
        }

        $this.UsesNativeEngine    = $false
        $this.HasOpenAlias        = $true
        $this.UsesWaveOutFallback = $false

        $null = [MMWinMMNative]::SendCommand("set $($this.MciAlias) time format milliseconds")

        [Hashtable]$LengthResult = [MMWinMMNative]::SendCommand("status $($this.MciAlias) length")

        If($LengthResult.Success -EQ $true) {
            [Int]$ParsedLen = 0

            If([Int]::TryParse($LengthResult.Output, [Ref]$ParsedLen) -EQ $true) {
                $this.DurationMs  = [Math]::Max(0, $ParsedLen)
                $Track.DurationMs = $this.DurationMs
            }
        }

        $this.ApplyAudioVolume()

        [Hashtable]$PlayResult = [MMWinMMNative]::SendCommand("play $($this.MciAlias)")

        If($PlayResult.Success -EQ $false) {
            $this.LastError = "Unable to play '$($Track.FileName)': $($PlayResult.ErrorMessage)"

            $this.CloseCurrentAlias()
            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionLoadFailed, $Ctx)
            $this.NotifyStateChanged()

            If($null -NE $this.OnError) {
                $this.OnError.Invoke($this.LastError)
            }

            Return $false
        }

        $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionPlayReady, $Ctx)
        $this.NotifyStateChanged()

        Return $true
    }

    [Boolean]Pause() {
        If($this.IsPlaying() -EQ $false) {
            Return $false
        }

        If(($this.UsesNativeEngine -EQ $true) -AND ($null -NE $this.NativeEngine)) {
            $this.PositionMs = [Math]::Max(0, $this.NativeEngine.PositionMs)

            If($this.NativeEngine.Pause() -EQ $false) {
                $this.LastError = 'Pause failed on native audio engine.'

                Return $false
            }

            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionPause, $this.PrepareContext())
            $this.NotifyStateChanged()

            Return $true
        }

        [Hashtable]$PosResult = [MMWinMMNative]::SendCommand("status $($this.MciAlias) position")

        If($PosResult.Success -EQ $true) {
            [Int]$ParsedPos = 0

            If([Int]::TryParse($PosResult.Output, [Ref]$ParsedPos) -EQ $true) {
                $this.PositionMs = [Math]::Max(0, $ParsedPos)
            }
        }

        [Hashtable]$PauseResult = [MMWinMMNative]::SendCommand("pause $($this.MciAlias)")

        If($PauseResult.Success -EQ $false) {
            $this.LastError = "Pause failed: $($PauseResult.ErrorMessage)"

            Return $false
        }

        $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionPause, $this.PrepareContext())
        $this.NotifyStateChanged()

        Return $true
    }

    [Boolean]Resume() {
        If($this.IsPaused() -EQ $false) {
            Return $false
        }

        If(($this.UsesNativeEngine -EQ $true) -AND ($null -NE $this.NativeEngine)) {
            If($this.NativeEngine.Resume() -EQ $false) {
                $this.LastError = 'Resume failed on native audio engine.'

                Return $false
            }

            $this.NativeEngine.SetVolume($this.Volume.Value, $this.IsMuted)
            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionResume, $this.PrepareContext())
            $this.NotifyStateChanged()

            Return $true
        }

        [Hashtable]$ResumeResult = [MMWinMMNative]::SendCommand("resume $($this.MciAlias)")

        If($ResumeResult.Success -EQ $false) {
            $ResumeResult = [MMWinMMNative]::SendCommand("play $($this.MciAlias) from $($this.PositionMs)")
        }

        If($ResumeResult.Success -EQ $false) {
            $this.LastError = "Resume failed: $($ResumeResult.ErrorMessage)"

            Return $false
        }

        $this.ApplyAudioVolume()
        $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionResume, $this.PrepareContext())
        $this.NotifyStateChanged()

        Return $true
    }

    [Boolean]Play() {
        If($this.IsPaused() -EQ $true) {
            Return $this.Resume()
        }

        If($null -NE $this.CurrentTrack) {
            Return $this.LoadAndPlay($this.CurrentTrack)
        }

        Return $false
    }

    [Boolean]TogglePlayPause() {
        If($this.IsPlaying() -EQ $true) {
            Return $this.Pause()
        }

        If($this.IsPaused() -EQ $true) {
            Return $this.Resume()
        }

        If($null -NE $this.CurrentTrack) {
            Return $this.LoadAndPlay($this.CurrentTrack)
        }

        Return $false
    }

    [Void]Stop() {
        $this.CloseCurrentAlias()

        $this.PositionMs = 0

        If($this.PlaybackStateMachine.CurrentState -NE [SMPlaybackStateMachine]::StateStopped) {
            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionStop, $this.PrepareContext())
        }

        $this.NotifyStateChanged()
    }

    [Boolean]Seek(
        [Int]$TargetMs
    ) {
        If($this.HasOpenAlias -EQ $false) {
            Return $false
        }

        [Int]$SafeTarget = ($this.DurationMs -GT 0) ? [Math]::Clamp($TargetMs, 0, $this.DurationMs) : [Math]::Max(0, $TargetMs)

        If(($this.UsesNativeEngine -EQ $true) -AND ($null -NE $this.NativeEngine)) {
            If($this.NativeEngine.Seek($SafeTarget) -EQ $false) {
                Return $false
            }

            $this.PositionMs = $SafeTarget

            Return $true
        }

        If($this.IsPlaying() -EQ $true) {
            [Hashtable]$PlayFromResult = [MMWinMMNative]::SendCommand("play $($this.MciAlias) from $($SafeTarget)")

            If($PlayFromResult.Success -EQ $false) {
                Return $false
            }
        } Elseif($this.IsPaused() -EQ $true) {
            [Hashtable]$SeekResult = [MMWinMMNative]::SendCommand("seek $($this.MciAlias) to $($SafeTarget)")

            If($SeekResult.Success -EQ $false) {
                Return $false
            }
        } Else {
            Return $false
        }

        $this.PositionMs = $SafeTarget

        Return $true
    }

    [Boolean]SeekRelative(
        [Int]$DeltaMs
    ) {
        Return $this.Seek($this.PositionMs + $DeltaMs)
    }

    [Void]ApplyAudioVolume() {
        [Int]$EffectivePercent = ($this.IsMuted -EQ $true) ? 0 : $this.Volume.Value

        If($null -NE $this.NativeEngine) {
            $this.NativeEngine.SetVolume($this.Volume.Value, $this.IsMuted)
        }

        If($this.UsesNativeEngine -EQ $true) {
            Return
        }

        If($this.HasOpenAlias -EQ $true) {
            [Int]$MciVolume            = $EffectivePercent * 10
            [Hashtable]$VolCmdResult   = [MMWinMMNative]::SendCommand("setaudio $($this.MciAlias) volume to $($MciVolume)")
            [String]$AudioToggleCmd    = ($this.IsMuted -EQ $true) ? "setaudio $($this.MciAlias) off" : "setaudio $($this.MciAlias) on"
            [Hashtable]$MuteCmdResult  = [MMWinMMNative]::SendCommand($AudioToggleCmd)

            If(($VolCmdResult.Success -EQ $true) -AND ($MuteCmdResult.Success -EQ $true)) {
                Return
            }

            $this.UsesWaveOutFallback = $true
        } Else {
            Return
        }

        If($this.HasSavedWaveVolume -EQ $false) {
            $this.OriginalWaveVolume = [MMWinMMNative]::GetRawWaveVolume()
            $this.HasSavedWaveVolume = $true
        }

        $null = [MMWinMMNative]::SetWaveVolumePercent($EffectivePercent)
    }

    [Void]SetVolume(
        [Int]$Percent
    ) {
        $this.Volume.SetValue($Percent)
        $this.ApplyAudioVolume()
        $this.NotifyStateChanged()
    }

    [Void]AdjustVolume(
        [Int]$Delta
    ) {
        $this.SetVolume($this.Volume.Value + $Delta)
    }

    [Boolean]ToggleMute() {
        $this.IsMuted = ($this.IsMuted -EQ $false)

        $this.ApplyAudioVolume()
        $this.NotifyStateChanged()

        Return $this.IsMuted
    }

    [Void]Update(
        [Double]$DeltaTime
    ) {
        If(($this.IsPlaying() -EQ $false) -OR ($this.HasOpenAlias -EQ $false)) {
            Return
        }

        If(($this.UsesNativeEngine -EQ $true) -AND ($null -NE $this.NativeEngine)) {
            [Int]$CurPos     = $this.NativeEngine.PositionMs
            $this.PositionMs = ($this.DurationMs -GT 0) ? [Math]::Clamp($CurPos, 0, $this.DurationMs) : [Math]::Max(0, $CurPos)

            If($this.NativeEngine.HasTrackEnded -EQ $true) {
                $this.CloseCurrentAlias()

                If($this.DurationMs -GT 0) {
                    $this.PositionMs = $this.DurationMs
                }

                $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionTrackEnded, $this.PrepareContext())
                $this.NotifyStateChanged()

                If($null -NE $this.OnTrackEnded) {
                    $this.OnTrackEnded.Invoke($this)
                }
            }

            Return
        }

        $this.PollTimer += $DeltaTime

        If($this.PollTimer -LT $this.PollIntervalSeconds) {
            Return
        }

        $this.PollTimer = 0.0

        [Hashtable]$PosResult = [MMWinMMNative]::SendCommand("status $($this.MciAlias) position")

        If($PosResult.Success -EQ $true) {
            [Int]$ParsedPos = 0

            If([Int]::TryParse($PosResult.Output, [Ref]$ParsedPos) -EQ $true) {
                $this.PositionMs = ($this.DurationMs -GT 0) ? [Math]::Clamp($ParsedPos, 0, $this.DurationMs) : [Math]::Max(0, $ParsedPos)
            }
        }

        [Hashtable]$ModeResult = [MMWinMMNative]::SendCommand("status $($this.MciAlias) mode")
        [Boolean]$HasEnded     = $false

        If(($ModeResult.Success -EQ $true) -AND ([String]::Equals($ModeResult.Output, 'stopped', [StringComparison]::OrdinalIgnoreCase) -EQ $true)) {
            $HasEnded = $true
        } Elseif(($this.DurationMs -GT 0) -AND ($this.PositionMs -GE $this.DurationMs)) {
            $HasEnded = $true
        }

        If($HasEnded -EQ $true) {
            $this.CloseCurrentAlias()

            If($this.DurationMs -GT 0) {
                $this.PositionMs = $this.DurationMs
            }

            $this.PlaybackStateMachine.Trigger([SMPlaybackStateMachine]::TransitionTrackEnded, $this.PrepareContext())
            $this.NotifyStateChanged()

            If($null -NE $this.OnTrackEnded) {
                $this.OnTrackEnded.Invoke($this)
            }
        }
    }

    [Void]Dispose() {
        $this.CloseCurrentAlias()

        If($null -NE $this.NativeEngine) {
            $this.NativeEngine.Dispose()
            $this.NativeEngine = $null
        }

        $this.CleanupStagedFile()

        If($this.HasSavedWaveVolume -EQ $true) {
            $null                    = [MMWinMMNative]::SetRawWaveVolume($this.OriginalWaveVolume)
            $this.HasSavedWaveVolume = $false
        }
    }
}
