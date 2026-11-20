using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# MM PLAYLIST
#
# MANAGES AN ORDERED LIST OF MEDIA TRACKS, ACTIVE PLAYBACK CURSOR, REPEAT
# MODES, AND SHUFFLE NAVIGATION.
#
###############################################################################

Class MMPlaylist {
    [String]$PlaylistName
    [String]$SourceFilePath
    [List[MMTrackInfo]]$Tracks
    [Int]$CurrentIndex
    [RepeatMode]$RepeatMode
    [Boolean]$ShuffleEnabled
    [Random]$Rng

    MMPlaylist() {
        $this.PlaylistName   = ''
        $this.SourceFilePath = ''
        $this.Tracks         = [List[MMTrackInfo]]::new()
        $this.CurrentIndex   = -1
        $this.RepeatMode     = [RepeatMode]::Off
        $this.ShuffleEnabled = $false
        $this.Rng            = [Random]::new()
    }

    [Void]AddTrack(
        [MMTrackInfo]$Track
    ) {
        If($null -EQ $Track) {
            Return
        }

        $this.Tracks.Add($Track)
    }

    [Void]AddTracks(
        [List[MMTrackInfo]]$TrackList
    ) {
        If($null -EQ $TrackList) {
            Return
        }

        Foreach($Track in $TrackList) {
            If($null -NE $Track) {
                $this.Tracks.Add($Track)
            }
        }
    }

    [Void]LoadTracks(
        [List[MMTrackInfo]]$TrackList,
        [String]$PlaylistName,
        [String]$SourceFilePath
    ) {
        $this.Tracks.Clear()

        $this.CurrentIndex   = -1
        $this.PlaylistName   = ($null -EQ $PlaylistName) ? '' : $PlaylistName
        $this.SourceFilePath = ($null -EQ $SourceFilePath) ? '' : $SourceFilePath

        $this.AddTracks($TrackList)
    }

    [Boolean]RemoveAt(
        [Int]$Index
    ) {
        If(($Index -LT 0) -OR ($Index -GE $this.Tracks.Count)) {
            Return $false
        }

        $this.Tracks.RemoveAt($Index)

        If($this.Tracks.Count -EQ 0) {
            $this.CurrentIndex = -1
        } Elseif($Index -EQ $this.CurrentIndex) {
            $this.CurrentIndex = -1
        } Elseif($Index -LT $this.CurrentIndex) {
            $this.CurrentIndex--
        }

        Return $true
    }

    [Void]Clear() {
        $this.Tracks.Clear()

        $this.CurrentIndex   = -1
        $this.PlaylistName   = ''
        $this.SourceFilePath = ''
    }

    [Int]MoveUp(
        [Int]$Index
    ) {
        If(($Index -LE 0) -OR ($Index -GE $this.Tracks.Count)) {
            Return $Index
        }

        [MMTrackInfo]$Temp        = $this.Tracks[$Index - 1]
        $this.Tracks[$Index - 1]  = $this.Tracks[$Index]
        $this.Tracks[$Index]      = $Temp

        If($this.CurrentIndex -EQ $Index) {
            $this.CurrentIndex = $Index - 1
        } Elseif($this.CurrentIndex -EQ ($Index - 1)) {
            $this.CurrentIndex = $Index
        }

        Return ($Index - 1)
    }

    [Int]MoveDown(
        [Int]$Index
    ) {
        If(($Index -LT 0) -OR ($Index -GE ($this.Tracks.Count - 1))) {
            Return $Index
        }

        [MMTrackInfo]$Temp        = $this.Tracks[$Index + 1]
        $this.Tracks[$Index + 1]  = $this.Tracks[$Index]
        $this.Tracks[$Index]      = $Temp

        If($this.CurrentIndex -EQ $Index) {
            $this.CurrentIndex = $Index + 1
        } Elseif($this.CurrentIndex -EQ ($Index + 1)) {
            $this.CurrentIndex = $Index
        }

        Return ($Index + 1)
    }

    [MMTrackInfo]SelectIndex(
        [Int]$Index
    ) {
        If(($Index -LT 0) -OR ($Index -GE $this.Tracks.Count)) {
            $this.CurrentIndex = -1

            Return $null
        }

        $this.CurrentIndex = $Index

        Return $this.Tracks[$Index]
    }

    [MMTrackInfo]GetCurrentTrack() {
        If(($this.CurrentIndex -GE 0) -AND ($this.CurrentIndex -LT $this.Tracks.Count)) {
            Return $this.Tracks[$this.CurrentIndex]
        }

        Return $null
    }

    [Int]FindTrackIndexByPath(
        [String]$FullPath
    ) {
        If(($null -EQ $FullPath) -OR ($FullPath.Length -EQ 0)) {
            Return -1
        }

        For([Int]$Idx = 0; $Idx -LT $this.Tracks.Count; $Idx++) {
            If([String]::Equals($this.Tracks[$Idx].FullPath, $FullPath, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                Return $Idx
            }
        }

        Return -1
    }

    [MMTrackInfo]AdvanceNext(
        [Boolean]$IsManual
    ) {
        If($this.Tracks.Count -EQ 0) {
            $this.CurrentIndex = -1

            Return $null
        }

        If(($IsManual -EQ $false) -AND ($this.RepeatMode -EQ [RepeatMode]::Track)) {
            If(($this.CurrentIndex -GE 0) -AND ($this.CurrentIndex -LT $this.Tracks.Count)) {
                Return $this.Tracks[$this.CurrentIndex]
            }
        }

        If($this.ShuffleEnabled -EQ $true) {
            If($this.Tracks.Count -EQ 1) {
                If(($IsManual -EQ $true) -OR ($this.RepeatMode -NE [RepeatMode]::Off)) {
                    $this.CurrentIndex = 0

                    Return $this.Tracks[0]
                }

                $this.CurrentIndex = -1

                Return $null
            }

            [Int]$NextRandom = $this.Rng.Next(0, $this.Tracks.Count)

            While($NextRandom -EQ $this.CurrentIndex) {
                $NextRandom = $this.Rng.Next(0, $this.Tracks.Count)
            }

            $this.CurrentIndex = $NextRandom

            Return $this.Tracks[$NextRandom]
        }

        [Int]$NextIndex = ($this.CurrentIndex -LT 0) ? 0 : ($this.CurrentIndex + 1)

        If($NextIndex -GE $this.Tracks.Count) {
            If(($this.RepeatMode -EQ [RepeatMode]::Playlist) -OR (($IsManual -EQ $true) -AND ($this.RepeatMode -EQ [RepeatMode]::Track))) {
                $NextIndex = 0
            } Else {
                Return $null
            }
        }

        $this.CurrentIndex = $NextIndex

        Return $this.Tracks[$NextIndex]
    }

    [MMTrackInfo]AdvancePrevious() {
        If($this.Tracks.Count -EQ 0) {
            $this.CurrentIndex = -1

            Return $null
        }

        If($this.ShuffleEnabled -EQ $true) {
            Return $this.AdvanceNext($true)
        }

        [Int]$PrevIndex = ($this.CurrentIndex -LE 0) ? ($this.Tracks.Count - 1) : ($this.CurrentIndex - 1)

        $this.CurrentIndex = $PrevIndex

        Return $this.Tracks[$PrevIndex]
    }

    [RepeatMode]CycleRepeatMode() {
        Switch($this.RepeatMode) {
            ([RepeatMode]::Off) {
                $this.RepeatMode = [RepeatMode]::Playlist

                Break
            }

            ([RepeatMode]::Playlist) {
                $this.RepeatMode = [RepeatMode]::Track

                Break
            }

            Default {
                $this.RepeatMode = [RepeatMode]::Off

                Break
            }
        }

        Return $this.RepeatMode
    }

    [Boolean]ToggleShuffle() {
        $this.ShuffleEnabled = ($this.ShuffleEnabled -EQ $false)

        Return $this.ShuffleEnabled
    }
}
