using namespace System
using namespace System.IO

Set-StrictMode -Version Latest





<#
.SYNOPSIS
Asserts the state of a Context.
#>
Function Confirm-Context {
    Param(
        [Context]$Context
    )

    If($null -EQ $Context) {
        [ContextBroadcaster]::StaticBroadcast(
            "$([CustomEvents]::BadContext)",
            $null,
            $null
        )
    }
}





<#
.SYNOPSIS
Formats a duration in milliseconds as MM:SS or H:MM:SS.
#>
Function Format-Duration {
    Param(
        [Int]$Milliseconds
    )

    If($Milliseconds -LE 0) {
        Return '00:00'
    }

    [Int]$TotalSeconds = [Int][Math]::Floor($Milliseconds / 1000.0)
    [Int]$Hours        = [Int][Math]::Floor($TotalSeconds / 3600.0)
    [Int]$Minutes      = [Int][Math]::Floor(($TotalSeconds % 3600) / 60.0)
    [Int]$Seconds      = $TotalSeconds % 60

    If($Hours -GT 0) {
        Return "$($Hours):$($Minutes.ToString('00')):$($Seconds.ToString('00'))"
    }

    Return "$($Minutes.ToString('00')):$($Seconds.ToString('00'))"
}





<#
.SYNOPSIS
Truncates text to fit within MaxWidth characters, appending an ellipsis when clipped.
#>
Function Format-TruncatedText {
    Param(
        [String]$Text,
        [Int]$MaxWidth
    )

    [String]$SafeText = ($null -EQ $Text) ? '' : $Text

    If($MaxWidth -LE 0) {
        Return ''
    }

    If($SafeText.Length -LE $MaxWidth) {
        Return $SafeText
    }

    If($MaxWidth -LE 3) {
        Return $SafeText.Substring(0, $MaxWidth)
    }

    [Int]$KeepLength = $MaxWidth - 3

    Return "$($SafeText.Substring(0, $KeepLength))..."
}





<#
.SYNOPSIS
Compacts a directory path by preserving the root/drive letter and leaf folder name.
#>
Function Format-CompactDirectoryPath {
    Param(
        [String]$DirectoryPath
    )

    If(($null -EQ $DirectoryPath) -OR ($DirectoryPath.Trim().Length -EQ 0)) {
        Return ''
    }

    [String]$Trimmed = $DirectoryPath.Trim()
    [String]$Root    = ''

    Try {
        $Root = [Path]::GetPathRoot($Trimmed)
    } Catch {
        Return $Trimmed
    }

    If(($null -EQ $Root) -OR ($Root.Length -EQ 0)) {
        Return $Trimmed
    }

    [String]$Remainder      = $Trimmed.Substring($Root.Length)
    [String]$CleanRoot      = $Root.Replace('/', '\')
    [String]$NormalizedRoot = ($CleanRoot.EndsWith('\') -EQ $true) ? $CleanRoot : "$($CleanRoot)\"
    [Char[]]$Separators     = [Char[]]@('\', '/')
    [String[]]$Segments     = $Remainder.Split($Separators, [StringSplitOptions]::RemoveEmptyEntries)

    If($Segments.Length -EQ 0) {
        Return $NormalizedRoot
    }

    If($Segments.Length -EQ 1) {
        Return "$($NormalizedRoot)$($Segments[0])"
    }

    Return "$($NormalizedRoot)..\$($Segments[$Segments.Length - 1])"
}
