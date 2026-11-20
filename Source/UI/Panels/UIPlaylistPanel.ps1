using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI PLAYLIST PANEL
#
# BOTTOM-RIGHT PANEL DISPLAYING QUEUED TRACKS, ACTIVE PLAYING MARKER, AND
# PLAYLIST TITLE/COUNT.
#
###############################################################################

Class UIPlaylistPanel : UIPanel {
    [UIList]$PlaylistList
    [Int]$ListDisplayWidth

    UIPlaylistPanel(
        [Int]$TopRow,
        [Int]$BottomRow,
        [Int]$LeftCol,
        [Int]$RightCol
    ) : base() {
        $this.LeftTop     = [ATCoordinates]::new($TopRow, $LeftCol)
        $this.RightBottom = [ATCoordinates]::new($BottomRow, $RightCol)

        $this.UpdateDimensions()
        $this.SetupTitle('Playlist (0)', [ColorLibrary]::TextActiveColor)

        [Int]$VisibleRows      = [Math]::Max(3, ($this.Height - 1))
        $this.ListDisplayWidth = [Math]::Max(10, ($this.Width - 3))
        $this.PlaylistList     = [UIList]::new(
            [ATCoordinates]::new(($TopRow + 1), ($LeftCol + 2)),
            $null,
            $VisibleRows
        )
        $this.PlaylistList.SetMaxDisplayWidth($this.ListDisplayWidth)

        $this.UiElementListing[0] = $this.PlaylistList
    }

    [Int]GetSelectedTrackIndex() {
        Return $this.PlaylistList.SelectedIndex
    }

    [Void]SyncFromPlaylist(
        [MMPlaylist]$Playlist,
        [Int]$DesiredSelectionIndex
    ) {
        If($null -EQ $Playlist) {
            Return
        }

        [Int]$TrackCount   = $Playlist.Tracks.Count
        [String]$TitleName = ($Playlist.PlaylistName.Length -GT 0) ? "Playlist: $($Playlist.PlaylistName) ($($TrackCount))" : "Playlist ($($TrackCount))"

        $this.SetupTitle($TitleName, [ColorLibrary]::TextActiveColor)
        $this.PlaylistList.ClearItems()

        For([Int]$Idx = 0; $Idx -LT $TrackCount; $Idx++) {
            [MMTrackInfo]$Track    = $Playlist.Tracks[$Idx]
            [String]$NumberStr     = ($Idx + 1).ToString('00')
            [String]$LabelText     = "$($NumberStr). $($Track.DisplayName)"
            [UIListItem]$Item      = [UIListItem]::new($LabelText, [ATCoordinates]::new(1, 1), $Track)
            [Boolean]$IsNowPlaying = ($Idx -EQ $Playlist.CurrentIndex)

            $Item.SetPlaying($IsNowPlaying)
            $this.PlaylistList.AddItem($Item)
        }

        If($TrackCount -GT 0) {
            [Int]$TargetIdx = ($DesiredSelectionIndex -GE 0) ? [Math]::Clamp($DesiredSelectionIndex, 0, ($TrackCount - 1)) : (($Playlist.CurrentIndex -GE 0) ? $Playlist.CurrentIndex : 0)
            $this.PlaylistList.SelectIndex($TargetIdx)
        }

        $this.PlaylistList.ViewportBlankDirty = $true
        $this.Dirty                           = $true
    }

    [Void]UpdatePlayingIndex(
        [Int]$PlayingIndex
    ) {
        For([Int]$Idx = 0; $Idx -LT $this.PlaylistList.Items.Count; $Idx++) {
            $this.PlaylistList.Items[$Idx].SetPlaying(($Idx -EQ $PlayingIndex))
        }
    }
}
