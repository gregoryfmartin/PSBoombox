using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# AT STRING NONE
#
# AN ABSTRACTION OF AT STRING INTENDED TO IMPLY NO AT STRING BE USED.
#
###############################################################################

Class ATStringNone : ATString {
    ATStringNone() : base() {}

    [String]ToAnsiControlSequenceString() {
        Return ''
    }
}
