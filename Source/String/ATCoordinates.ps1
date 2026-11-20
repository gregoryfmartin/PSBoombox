using namespace System
using namespace System.Management.Automation.Host

Set-StrictMode -Version Latest





###############################################################################
#
# AT COORDINATES
#
# A SYMBOLIC ENCAPSULATION OF A COORDINATE PAIR IN ROW,COLUMN (Y,X) ORDER.
#
###############################################################################

Class ATCoordinates {
    Static [Int]$MaxRow    = 200
    Static [Int]$MaxColumn = 300

    [ClampableInt]$Row
    [ClampableInt]$Column

    ATCoordinates() {
        $this.Row    = [ClampableInt]::new(1, 1, [ATCoordinates]::MaxRow)
        $this.Column = [ClampableInt]::new(1, 1, [ATCoordinates]::MaxColumn)
    }

    ATCoordinates(
        [Int]$Row,
        [Int]$Column
    ) {
        $this.Row    = [ClampableInt]::new($Row, 1, [ATCoordinates]::MaxRow)
        $this.Column = [ClampableInt]::new($Column, 1, [ATCoordinates]::MaxColumn)
    }

    ATCoordinates(
        [Coordinates]$AutomationCoordinates
    ) {
        $this.Row    = [ClampableInt]::new($AutomationCoordinates.Y, 1, [ATCoordinates]::MaxRow)
        $this.Column = [ClampableInt]::new($AutomationCoordinates.X, 1, [ATCoordinates]::MaxColumn)
    }

    ATCoordinates(
        [ATCoordinates]$CopyFrom
    ) {
        $this.Row    = [ClampableInt]::new($CopyFrom.Row.Value, $CopyFrom.Row.Floor, $CopyFrom.Row.Ceiling)
        $this.Column = [ClampableInt]::new($CopyFrom.Column.Value, $CopyFrom.Column.Floor, $CopyFrom.Column.Ceiling)
    }

    Static [Void]SetBounds(
        [Int]$MaxRow,
        [Int]$MaxColumn
    ) {
        [ATCoordinates]::MaxRow    = [Math]::Max(24, $MaxRow)
        [ATCoordinates]::MaxColumn = [Math]::Max(80, $MaxColumn)
    }

    [String]ToAnsiControlSequenceString() {
        Return "$([ATControlSequences]::GenerateCoordinateString($this.Row, $this.Column))"
    }

    [Coordinates]ToAutomationCoordinates() {
        Return [Coordinates]::new($this.Column, $this.Row)
    }
}
