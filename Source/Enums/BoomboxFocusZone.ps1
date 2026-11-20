using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# BOOMBOX FOCUS ZONE
#
# IDENTIFIES WHICH PRIMARY PANEL HAS KEYBOARD FOCUS IN THE MAIN PLAYER SCREEN.
#
###############################################################################

Enum BoomboxFocusZone {
    DirectoryBrowser
    Playlist
    PlaybackControls
}
