using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# MM DIRECTORY ENTRY
#
# REPRESENTS ONE ITEM INSIDE A DIRECTORY LISTING (PARENT, FOLDER, PLAYLIST, OR
# MEDIA FILE).
#
###############################################################################

Class MMDirectoryEntry {
    Static [String]$PlaylistGlyph = "`u{2261}"
    Static [String]$MediaGlyph    = "`u{266A}"

    [DirectoryEntryType]$EntryType
    [String]$Name
    [String]$FullPath
    [String]$DisplayLabel

    MMDirectoryEntry() {
        $this.EntryType    = [DirectoryEntryType]::MediaFile
        $this.Name         = ''
        $this.FullPath     = ''
        $this.DisplayLabel = ''
    }

    MMDirectoryEntry(
        [DirectoryEntryType]$EntryType,
        [String]$Name,
        [String]$FullPath
    ) {
        $this.EntryType = $EntryType
        $this.Name      = ($null -EQ $Name) ? '' : $Name
        $this.FullPath  = ($null -EQ $FullPath) ? '' : $FullPath

        $this.BuildDisplayLabel()
    }

    [Void]BuildDisplayLabel() {
        Switch($this.EntryType) {
            ([DirectoryEntryType]::ParentDirectory) {
                $this.DisplayLabel = '.. (Parent Directory)'

                Break
            }

            ([DirectoryEntryType]::Directory) {
                $this.DisplayLabel = "[DIR] $($this.Name)"

                Break
            }

            ([DirectoryEntryType]::PlaylistFile) {
                $this.DisplayLabel = "$([MMDirectoryEntry]::PlaylistGlyph) $($this.Name)"

                Break
            }

            Default {
                $this.DisplayLabel = "$([MMDirectoryEntry]::MediaGlyph) $($this.Name)"

                Break
            }
        }
    }
}
