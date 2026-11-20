using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# DIRECTORY ENTRY TYPE
#
# CLASSIFIES ITEMS DISPLAYED IN THE DIRECTORY BROWSER LIST.
#
###############################################################################

Enum DirectoryEntryType {
    ParentDirectory
    Directory
    PlaylistFile
    MediaFile
}
