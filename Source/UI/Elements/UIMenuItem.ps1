using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI MENU ITEM
#
# A UILISTITEM THAT ASSOCIATES AN INVOCABLE ACTION SCRIPTBLOCK AND AN
# ENABLED FLAG WITH A MENU ENTRY.
#
###############################################################################

Class UIMenuItem : UIListItem {
    [ScriptBlock]$Action
    [Boolean]$IsEnabled

    UIMenuItem() : base() {
        $this.Action    = $null
        $this.IsEnabled = $true

        $this.ApplyVisuals()
    }

    UIMenuItem(
        [String]$LabelText,
        [ScriptBlock]$Action
    ) : base($LabelText) {
        $this.Action    = $Action
        $this.IsEnabled = $true

        $this.ApplyVisuals()
    }

    UIMenuItem(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [ScriptBlock]$Action
    ) : base($LabelText, $DrawCoordinates) {
        $this.Action    = $Action
        $this.IsEnabled = $true

        $this.ApplyVisuals()
    }

    [Void]SetEnabled(
        [Boolean]$Enabled
    ) {
        $this.IsEnabled = $Enabled

        $this.ApplyVisuals()
    }

    [TrueColor]ResolveForegroundColor() {
        If($this.IsEnabled -EQ $false) {
            Return [ColorLibrary]::UIListItemInactive
        }

        Return ([UIListItem]$this).ResolveForegroundColor()
    }

    [Void]Invoke(
        [Context]$Context
    ) {
        If(($this.IsEnabled -EQ $true) -AND ($null -NE $this.Action)) {
            $this.Action.Invoke($Context)
        }
    }
}
