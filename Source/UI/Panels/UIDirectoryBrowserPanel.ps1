using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI DIRECTORY BROWSER PANEL
#
# BOTTOM-LEFT PANEL DISPLAYING THE CURRENT DIRECTORY PATH, SUBDIRECTORIES,
# PLAYLIST FILES, AND SUPPORTED AUDIO FILES.
#
###############################################################################

Class UIDirectoryBrowserPanel : UIPanel {
    [UIList]$DirectoryList
    [Int]$ListDisplayWidth
    [String]$LastRenderedPath

    UIDirectoryBrowserPanel(
        [Int]$TopRow,
        [Int]$BottomRow,
        [Int]$LeftCol,
        [Int]$RightCol
    ) : base() {
        $this.LeftTop          = [ATCoordinates]::new($TopRow, $LeftCol)
        $this.RightBottom      = [ATCoordinates]::new($BottomRow, $RightCol)
        $this.LastRenderedPath = ''

        $this.UpdateDimensions()
        $this.SetupTitle('Directory', [ColorLibrary]::TextActiveColor)

        [Int]$VisibleRows       = [Math]::Max(3, ($this.Height - 1))
        $this.ListDisplayWidth  = [Math]::Max(10, ($this.Width - 3))
        $this.DirectoryList     = [UIList]::new(
            [ATCoordinates]::new(($TopRow + 1), ($LeftCol + 2)),
            $null,
            $VisibleRows
        )
        $this.DirectoryList.SetMaxDisplayWidth($this.ListDisplayWidth)

        $this.UiElementListing[0] = $this.DirectoryList
    }

    [MMDirectoryEntry]GetSelectedEntry() {
        [UIListItem]$SelectedItem = $this.DirectoryList.GetSelectedItem()

        If($null -NE $SelectedItem) {
            Return ($SelectedItem.Tag -AS [MMDirectoryEntry])
        }

        Return $null
    }

    [Void]SyncFromService(
        [MMDirectoryService]$DirService,
        [String]$PlayingTrackPath
    ) {
        If($null -EQ $DirService) {
            Return
        }

        [Int]$PreviousIndex   = $this.DirectoryList.SelectedIndex
        [Int]$MediaCount      = $DirService.GetMediaFileCount()
        [Int]$MaxTitlePathLen = [Math]::Max(8, ($this.Width - 22))
        [String]$ClippedPath  = Format-TruncatedText $DirService.CurrentPath $MaxTitlePathLen

        $this.SetupTitle("Dir: $($ClippedPath) ($($MediaCount))", [ColorLibrary]::TextActiveColor)
        $this.DirectoryList.ClearItems()

        Foreach($Entry in $DirService.Entries) {
            [UIListItem]$Item = [UIListItem]::new($Entry.DisplayLabel, [ATCoordinates]::new(1, 1), $Entry)

            Switch($Entry.EntryType) {
                ([DirectoryEntryType]::ParentDirectory) {
                    $Item.SetCustomActiveColor([ColorLibrary]::BoomboxParentDirEntry)

                    Break
                }

                ([DirectoryEntryType]::Directory) {
                    $Item.SetCustomActiveColor([ColorLibrary]::BoomboxDirEntry)

                    Break
                }

                ([DirectoryEntryType]::PlaylistFile) {
                    $Item.SetCustomActiveColor([ColorLibrary]::BoomboxPlaylistFileEntry)

                    Break
                }

                Default {
                    $Item.SetCustomActiveColor([ColorLibrary]::BoomboxMediaFileEntry)

                    If(($null -NE $PlayingTrackPath) -AND ($PlayingTrackPath.Length -GT 0) -AND ([String]::Equals($Entry.FullPath, $PlayingTrackPath, [StringComparison]::OrdinalIgnoreCase) -EQ $true)) {
                        $Item.SetPlaying($true)
                    }

                    Break
                }
            }

            $this.DirectoryList.AddItem($Item)
        }

        If($this.DirectoryList.Items.Count -GT 0) {
            [Boolean]$SamePath = [String]::Equals($DirService.CurrentPath, $this.LastRenderedPath, [StringComparison]::OrdinalIgnoreCase)
            [Int]$RestoredIdx  = (($SamePath -EQ $true) -AND ($PreviousIndex -GE 0)) ? [Math]::Clamp($PreviousIndex, 0, ($this.DirectoryList.Items.Count - 1)) : 0
            $this.DirectoryList.SelectIndex($RestoredIdx)
        }

        $this.LastRenderedPath                 = $DirService.CurrentPath
        $this.DirectoryList.ViewportBlankDirty = $true
        $this.Dirty                            = $true
    }

    [Void]UpdatePlayingMarker(
        [String]$PlayingTrackPath
    ) {
        Foreach($Item in $this.DirectoryList.Items) {
            [MMDirectoryEntry]$Entry = $Item.Tag -AS [MMDirectoryEntry]

            If(($null -NE $Entry) -AND ($Entry.EntryType -EQ [DirectoryEntryType]::MediaFile)) {
                [Boolean]$MatchesPlaying = ($null -NE $PlayingTrackPath) -AND ($PlayingTrackPath.Length -GT 0) -AND ([String]::Equals($Entry.FullPath, $PlayingTrackPath, [StringComparison]::OrdinalIgnoreCase) -EQ $true)
                $Item.SetPlaying($MatchesPlaying)
            }
        }
    }
}
