using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# BUFFER SPEC DEFINITION
#
# DEFINES MINIMUM CONSOLE BUFFER DIMENSIONS FOR PSBOOMBOX.
#
###############################################################################

Class BufferSpecDefinition {
    [ClampableInt]$BufferMinWidth
    [ClampableInt]$BufferMinHeight

    BufferSpecDefinition() {
        $this.BufferMinWidth  = [ClampableInt]::new(80, 80, 160)
        $this.BufferMinHeight = [ClampableInt]::new(24, 24, 60)
    }
}
