using namespace System
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest

Function New-TestWavFile {
    Param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,

        [Int]$DurationMs = 450,

        [Int]$SampleRate = 22050
    )

    [Int]$Channels      = 1
    [Int]$BitsPerSample = 16
    [Int]$ByteRate      = $SampleRate * $Channels * ($BitsPerSample / 8)
    [Int]$BlockAlign    = $Channels * ($BitsPerSample / 8)
    [Int]$SampleCount   = [Math]::Max(1, [Int][Math]::Floor(($SampleRate * $DurationMs) / 1000.0))
    [Int]$DataSize      = $SampleCount * $BlockAlign
    [Int]$RiffChunkSize = 36 + $DataSize
    [Byte[]]$Bytes      = [Byte[]]::new(44 + $DataSize)

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

    [File]::WriteAllBytes($FilePath, $Bytes)
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
