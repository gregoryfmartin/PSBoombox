using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# AT STRING COMPOSITE
#
# AN AGGREGATE OF AT STRING INSTANCES IN A COLLECTION.
#
###############################################################################

Class ATStringComposite {
    [List[ATString]]$CompositeActual = [List[ATString]]::new()

    ATStringComposite() {
        If($null -EQ $this.CompositeActual) {
            $this.CompositeActual = [List[ATString]]::new()
        }

        $this.CompositeActual.Add([ATStringNone]::new()) | Out-Null
    }

    ATStringComposite(
        [ATString[]]$Components
    ) {
        If($null -EQ $this.CompositeActual) {
            $this.CompositeActual = [List[ATString]]::new()
        }

        Foreach($Component in $Components) {
            $this.CompositeActual.Add($Component) | Out-Null
        }
    }

    ATStringComposite(
        [List[ATString]]$Components
    ) {
        $this.CompositeActual = $Components
    }

    [String]ToAnsiControlSequenceString() {
        [String]$Composite = ''

        Foreach($Component in $this.CompositeActual) {
            $Composite += "$($Component.ToAnsiControlSequenceString())"
        }

        Return "$($Composite)"
    }
}
