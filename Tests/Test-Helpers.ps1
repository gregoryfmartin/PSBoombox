using namespace System
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest

Function New-TestWavFile {
    Param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,

        [Int]$DurationMs = 450,

        [Int]$SampleRate = 22050,

        [Int]$Channels = 1,

        [Int]$BitsPerSample = 16,

        [Double]$FrequencyHz = 0.0,

        [Int]$ActiveChannel = -1
    )

    [Int]$BytesPerSample = [Int]($BitsPerSample / 8)
    [Int]$BlockAlign     = $Channels * $BytesPerSample
    [Int]$ByteRate       = $SampleRate * $BlockAlign
    [Int]$SampleCount    = [Math]::Max(1, [Int][Math]::Floor(($SampleRate * $DurationMs) / 1000.0))
    [Int]$DataSize       = $SampleCount * $BlockAlign
    [Int]$RiffChunkSize  = 36 + $DataSize
    [Byte[]]$Bytes       = [Byte[]]::new(44 + $DataSize)

    [Encoding]::ASCII.GetBytes('RIFF').CopyTo($Bytes, 0)
    [BitConverter]::GetBytes([UInt32]$RiffChunkSize).CopyTo($Bytes, 4)
    [Encoding]::ASCII.GetBytes('WAVE').CopyTo($Bytes, 8)
    [Encoding]::ASCII.GetBytes('fmt ').CopyTo($Bytes, 12)
    [BitConverter]::GetBytes([UInt32]16).CopyTo($Bytes, 16)
    [BitConverter]::GetBytes([UInt16]1).CopyTo($Bytes, 20)
    [BitConverter]::GetBytes([UInt16]$Channels).CopyTo($Bytes, 22)
    [BitConverter]::GetBytes([UInt32]$SampleRate).CopyTo($Bytes, 24)
    [BitConverter]::GetBytes([UInt32]$ByteRate).CopyTo($Bytes, 28)
    [BitConverter]::GetBytes([UInt16]$BlockAlign).CopyTo($Bytes, 32)
    [BitConverter]::GetBytes([UInt16]$BitsPerSample).CopyTo($Bytes, 34)
    [Encoding]::ASCII.GetBytes('data').CopyTo($Bytes, 36)
    [BitConverter]::GetBytes([UInt32]$DataSize).CopyTo($Bytes, 40)

    If($FrequencyHz -GT 0.0) {
        For([Int]$Frame = 0; $Frame -LT $SampleCount; $Frame++) {
            [Double]$Tone = 0.45 * [Math]::Sin((2.0 * [Math]::PI * $FrequencyHz * $Frame) / [Double]$SampleRate)

            For([Int]$Ch = 0; $Ch -LT $Channels; $Ch++) {
                [Double]$SampleVal = (($ActiveChannel -GE 0) -AND ($Ch -NE $ActiveChannel)) ? 0.0 : $Tone
                [Int]$Offset       = 44 + ($Frame * $BlockAlign) + ($Ch * $BytesPerSample)

                If($BitsPerSample -EQ 16) {
                    [Int16]$Val16      = [Int16][Math]::Round($SampleVal * 32767.0)
                    $Bytes[$Offset]     = [Byte]($Val16 -BAND 0xFF)
                    $Bytes[$Offset + 1] = [Byte](($Val16 -SHR 8) -BAND 0xFF)
                } Elseif($BitsPerSample -EQ 24) {
                    [Int]$Val24        = [Int][Math]::Round($SampleVal * 8388607.0)
                    $Bytes[$Offset]     = [Byte]($Val24 -BAND 0xFF)
                    $Bytes[$Offset + 1] = [Byte](($Val24 -SHR 8) -BAND 0xFF)
                    $Bytes[$Offset + 2] = [Byte](($Val24 -SHR 16) -BAND 0xFF)
                }
            }
        }
    }

    [File]::WriteAllBytes($FilePath, $Bytes)
}

Function New-TestFlacFile {
    Param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,

        [Int]$FrameCount = 50,

        [Double]$FrequencyHz = 440.0
    )

    [Int]$BlockSize       = 1024
    [Int]$SampleRate      = 44100
    [Int64]$TotalSamples  = [Int64]$FrameCount * [Int64]$BlockSize
    [MemoryStream]$Stream = [MemoryStream]::new()

    Try {
        # FLAC STREAM MAGIC + LAST METADATA BLOCK (STREAMINFO, 34 BYTES)
        $Stream.Write([Byte[]]@(0x66, 0x4C, 0x61, 0x43), 0, 4)
        $Stream.Write([Byte[]]@(0x80, 0x00, 0x00, 0x22), 0, 4)

        [Byte[]]$StreamInfo = [Byte[]]::new(34)
        $StreamInfo[0] = 0x04; $StreamInfo[1] = 0x00
        $StreamInfo[2] = 0x04; $StreamInfo[3] = 0x00

        [UInt64]$InfoBits = (([UInt64]$SampleRate) -SHL 44) -BOR (([UInt64]0) -SHL 41) -BOR (([UInt64]15) -SHL 36) -BOR ([UInt64]$TotalSamples)
        For([Int]$I = 0; $I -LT 8; $I++) {
            $StreamInfo[10 + $I] = [Byte](($InfoBits -SHR (56 - (8 * $I))) -BAND 0xFF)
        }
        $Stream.Write($StreamInfo, 0, 34)

        For([Int]$FrameIdx = 0; $FrameIdx -LT $FrameCount; $FrameIdx++) {
            [System.Collections.Generic.List[Byte]]$FrameBytes = [System.Collections.Generic.List[Byte]]::new(2064)

            # FRAME HEADER: SYNC 0xFFF8, BLOCKSIZE 1024 + 44100HZ (0xA9), MONO 16-BIT (0x08)
            $FrameBytes.Add(0xFF)
            $FrameBytes.Add(0xF8)
            $FrameBytes.Add(0xA9)
            $FrameBytes.Add(0x08)

            If($FrameIdx -LT 128) {
                $FrameBytes.Add([Byte]$FrameIdx)
            } Else {
                $FrameBytes.Add([Byte](0xC0 -BOR (($FrameIdx -SHR 6) -BAND 0x1F)))
                $FrameBytes.Add([Byte](0x80 -BOR ($FrameIdx -BAND 0x3F)))
            }

            # CRC-8 OVER FRAME HEADER (POLY 0x07, INIT 0)
            [Int]$Crc8 = 0
            Foreach($Hb in $FrameBytes) {
                $Crc8 = $Crc8 -BXOR [Int]$Hb
                For([Int]$Bit = 0; $Bit -LT 8; $Bit++) {
                    If(($Crc8 -BAND 0x80) -NE 0) {
                        $Crc8 = (($Crc8 -SHL 1) -BXOR 0x07) -BAND 0xFF
                    } Else {
                        $Crc8 = ($Crc8 -SHL 1) -BAND 0xFF
                    }
                }
            }
            $FrameBytes.Add([Byte]$Crc8)

            # VERBATIM SUBFRAME HEADER (0x02) + 1024 BIG-ENDIAN 16-BIT PCM SAMPLES
            $FrameBytes.Add(0x02)
            For([Int]$S = 0; $S -LT $BlockSize; $S++) {
                [Int64]$SampleIndex = ([Int64]$FrameIdx * [Int64]$BlockSize) + [Int64]$S
                [Int16]$Pcm16       = [Int16][Math]::Round(0.45 * 32767.0 * [Math]::Sin((2.0 * [Math]::PI * $FrequencyHz * [Double]$SampleIndex) / [Double]$SampleRate))
                $FrameBytes.Add([Byte](($Pcm16 -SHR 8) -BAND 0xFF))
                $FrameBytes.Add([Byte]($Pcm16 -BAND 0xFF))
            }

            # CRC-16 OVER FULL FRAME (POLY 0x8005, INIT 0)
            [Int]$Crc16 = 0
            Foreach($Fb in $FrameBytes) {
                $Crc16 = $Crc16 -BXOR ([Int]$Fb -SHL 8)
                For([Int]$Bit = 0; $Bit -LT 8; $Bit++) {
                    If(($Crc16 -BAND 0x8000) -NE 0) {
                        $Crc16 = (($Crc16 -SHL 1) -BXOR 0x8005) -BAND 0xFFFF
                    } Else {
                        $Crc16 = ($Crc16 -SHL 1) -BAND 0xFFFF
                    }
                }
            }
            $FrameBytes.Add([Byte](($Crc16 -SHR 8) -BAND 0xFF))
            $FrameBytes.Add([Byte]($Crc16 -BAND 0xFF))

            [Byte[]]$OutFrame = $FrameBytes.ToArray()
            $Stream.Write($OutFrame, 0, $OutFrame.Length)
        }

        [File]::WriteAllBytes($FilePath, $Stream.ToArray())
    } Finally {
        $Stream.Dispose()
    }
}

Function New-TestMp3File {
    Param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,

        [Int]$FrameCount = 30,

        [Int]$Id3PaddingBytes = 0,

        [Int]$ZeroPaddingBytes = 0
    )

    [MemoryStream]$Stream = [MemoryStream]::new()

    Try {
        If($Id3PaddingBytes -GT 0) {
            [Byte[]]$Id3Block = [Byte[]]::new(10 + $Id3PaddingBytes)
            $Id3Block[0]      = 0x49
            $Id3Block[1]      = 0x44
            $Id3Block[2]      = 0x33
            $Id3Block[3]      = 3
            $Id3Block[4]      = 0
            $Id3Block[5]      = 0
            $Id3Block[6]      = [Byte](($Id3PaddingBytes -SHR 21) -BAND 0x7F)
            $Id3Block[7]      = [Byte](($Id3PaddingBytes -SHR 14) -BAND 0x7F)
            $Id3Block[8]      = [Byte](($Id3PaddingBytes -SHR 7) -BAND 0x7F)
            $Id3Block[9]      = [Byte]($Id3PaddingBytes -BAND 0x7F)

            If($Id3PaddingBytes -GT 200) {
                # EMBED FAKE MPEG SYNC PATTERN INSIDE TAG PAYLOAD TO VERIFY ID3 PARSER SKIPS FULL TAG
                $Id3Block[100] = 0xFF
                $Id3Block[101] = 0xFB
                $Id3Block[102] = 0x90
                $Id3Block[103] = 0x00
            }

            $Stream.Write($Id3Block, 0, $Id3Block.Length)
        }

        If($ZeroPaddingBytes -GT 0) {
            [Byte[]]$PadBytes = [Byte[]]::new($ZeroPaddingBytes)
            $Stream.Write($PadBytes, 0, $PadBytes.Length)
        }

        [Byte[]]$MpegFrame = [Byte[]]::new(417)
        $MpegFrame[0]      = 0xFF
        $MpegFrame[1]      = 0xFB
        $MpegFrame[2]      = 0x90
        $MpegFrame[3]      = 0x00

        For([Int]$Idx = 0; $Idx -LT $FrameCount; $Idx++) {
            $Stream.Write($MpegFrame, 0, $MpegFrame.Length)
        }

        [File]::WriteAllBytes($FilePath, $Stream.ToArray())
    } Finally {
        $Stream.Dispose()
    }
}

Function Assert-True {
    Param(
        [Boolean]$Condition,
        [String]$Message
    )

    If($Condition -NE $true) {
        Throw "Assertion failed (expected true): $($Message)"
    }
}

Function Assert-False {
    Param(
        [Boolean]$Condition,
        [String]$Message
    )

    If($Condition -NE $false) {
        Throw "Assertion failed (expected false): $($Message)"
    }
}

Function Assert-Equal {
    Param(
        [Object]$Actual,
        [Object]$Expected,
        [String]$Message
    )

    If($Actual -NE $Expected) {
        Throw "Assertion failed ($($Message)): expected '$($Expected)' but got '$($Actual)'."
    }
}
