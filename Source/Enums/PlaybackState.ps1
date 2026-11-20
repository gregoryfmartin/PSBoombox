using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# PLAYBACK STATE
#
# REPRESENTS THE HIGH-LEVEL PLAYBACK STATUS OF THE MEDIA ENGINE.
#
###############################################################################

Enum PlaybackState {
    Stopped
    Loading
    Playing
    Paused
    Error
}
