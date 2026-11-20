using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# CONTEXT
#
# ENCAPSULATES SHARED REFERENCES PASSED ACROSS STATE MACHINE AND UI CALLBACKS.
#
###############################################################################

Class Context {
    [Hashtable]$References

    Context() {
        $this.References = @{}
    }

    Context(
        [Hashtable]$References
    ) {
        $this.References = ($null -EQ $References) ? @{} : $References
    }
}
