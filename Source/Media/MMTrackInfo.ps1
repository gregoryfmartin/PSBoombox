using namespace System
using namespace System.IO

Set-StrictMode -Version Latest





###############################################################################
#
# MM TRACK INFO
#
# REPRESENTS A SINGLE AUDIO TRACK IN THE DIRECTORY BROWSER OR PLAYLIST.
#
###############################################################################

Class MMTrackInfo {
    [String]$FullPath
    [String]$FileName
    [String]$DisplayName
    [String]$Extension
    [Int]$DurationMs

    MMTrackInfo() {
        $this.FullPath    = ''
        $this.FileName    = ''
        $this.DisplayName = ''
        $this.Extension   = ''
        $this.DurationMs  = 0
    }

    MMTrackInfo(
        [String]$FullPath
    ) {
        $this.Initialize(
            $FullPath,
            '',
            0
        )
    }

    MMTrackInfo(
        [String]$FullPath,
        [String]$DisplayName,
        [Int]$DurationMs
    ) {
        $this.Initialize(
            $FullPath,
            $DisplayName,
            $DurationMs
        )
    }

    [Void]Initialize(
        [String]$FullPath,
        [String]$DisplayName,
        [Int]$DurationMs
    ) {
        [String]$SafePath  = ($null -EQ $FullPath) ? '' : $FullPath
        [String]$SafeName  = ($SafePath.Length -GT 0) ? [Path]::GetFileName($SafePath) : ''
        [String]$SafeExt   = ($SafePath.Length -GT 0) ? [Path]::GetExtension($SafePath).ToLowerInvariant() : ''
        [String]$SafeLabel = (($null -NE $DisplayName) -AND ($DisplayName.Trim().Length -GT 0)) ? $DisplayName.Trim() : $SafeName

        $this.FullPath    = $SafePath
        $this.FileName    = $SafeName
        $this.DisplayName = $SafeLabel
        $this.Extension   = $SafeExt
        $this.DurationMs  = [Math]::Max(0, $DurationMs)
    }
}
