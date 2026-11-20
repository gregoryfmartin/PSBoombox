using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI ELEMENT BEHAVIOR
#
# ENCAPSULATES COMMON BEHAVIOR FOR UI ELEMENTS.
#
# CAN HAVE FOCUS
#   FLAG INDICATING THAT THIS ELEMENT CAN BE FOCUSED ON, IN OTHER WORDS, CAN
#   THIS ELEMENT RECEIVE INPUT.
#
# GROUP IDENTIFIER
#   SPECIFIES A "GROUP" THE ELEMENT BELONGS TO. THIS REALLY ONLY HAS MEANING
#   FOR RADIO BUTTONS.
#
###############################################################################

Class UIElementBehavior {
    [Boolean]$CanHaveFocus
    [String]$GroupIdentifier

    UIElementBehavior() {
        $this.CanHaveFocus    = $false
        $this.GroupIdentifier = ''
    }
}
