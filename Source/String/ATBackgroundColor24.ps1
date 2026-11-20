using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# AT BACKGROUND COLOR 24
#
# A SYMBOLIC ENCAPSULATION OF CONSOLE COLOR 24 TO BE USED SPECIFICALLY FOR
# BACKGROUND COLOR APPLICATIONS.
#
###############################################################################

Class ATBackgroundColor24 {
    [TrueColor]$Color

    ATBackgroundColor24(
        [TrueColor]$Color
    ) {
        $this.Color = $Color
    }

    [String]ToAnsiControlSequenceString() {
        Return [ATControlSequences]::GenerateBG24String($this.Color)
    }

    Hidden Static [ATBackgroundColor24]op_Implicit(
        [TrueColor]$Color
    ) {
        Return [ATBackgroundColor24]::new($Color)
    }
}
