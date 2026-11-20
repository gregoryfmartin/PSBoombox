using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# WINDOW BORDER PART DIRTY
#
# WINDOW BORDERS ARE DRAWN AS FOUR PIECES, EACH PIECE BEING A COMPOSITION OF
# PARTS WITH AN INDEPENDENT DIRTY FLAG.
#
###############################################################################

Enum WindowBorderPartDirty {
    Top
    Bottom
    Left
    Right
}
