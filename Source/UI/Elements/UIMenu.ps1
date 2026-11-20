using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI MENU
#
# AN INTERACTIVE VERTICAL MENU DERIVED FROM UILIST THAT INVOKES THE SELECTED
# UIMENUITEM ACTION ON ENTER OR SPACEBAR.
#
###############################################################################

Class UIMenu : UIList {
    UIMenu() : base() {}

    UIMenu(
        [ATCoordinates]$DrawCoordinates
    ) : base($DrawCoordinates) {}

    UIMenu(
        [ATCoordinates]$DrawCoordinates,
        [Hashtable[]]$MenuData
    ) : base($DrawCoordinates) {
        $this.InitializeMenuItems($MenuData)
    }

    UIMenu(
        [ATCoordinates]$DrawCoordinates,
        [UIMenuItem[]]$MenuItems
    ) : base($DrawCoordinates) {
        If($null -NE $MenuItems) {
            Foreach($MenuItem in $MenuItems) {
                $this.AddMenuItem($MenuItem)
            }
        }
    }

    [Void]InitializeMenuItems(
        [Hashtable[]]$MenuData
    ) {
        $this.ClearItems()

        If($null -EQ $MenuData) {
            Return
        }

        Foreach($Entry in $MenuData) {
            If($null -EQ $Entry) {
                Continue
            }

            [String]$LabelText    = (($Entry.ContainsKey('Label') -EQ $true) -AND ($null -NE $Entry['Label'])) ? [String]$Entry['Label'] : ''
            [ScriptBlock]$Action  = ($Entry.ContainsKey('Action') -EQ $true) ? ($Entry['Action'] -AS [ScriptBlock]) : $null
            [UIMenuItem]$MenuItem = [UIMenuItem]::new($LabelText, $Action)

            If(($Entry.ContainsKey('Enabled') -EQ $true) -AND ($null -NE $Entry['Enabled'])) {
                $MenuItem.SetEnabled([Boolean]$Entry['Enabled'])
            }

            $this.AddMenuItem($MenuItem)
        }
    }

    [Void]AddMenuItem(
        [String]$LabelText,
        [ScriptBlock]$Action
    ) {
        [UIMenuItem]$MenuItem = [UIMenuItem]::new($LabelText, $Action)

        $this.AddMenuItem($MenuItem)
    }

    [Void]AddMenuItem(
        [UIMenuItem]$MenuItem
    ) {
        If($null -NE $MenuItem) {
            $this.AddItem($MenuItem)
        }
    }

    [Void]InvokeSelected(
        [Context]$Context
    ) {
        [UIListItem]$Selected = $this.GetSelectedItem()

        If(($null -NE $Selected) -AND ($Selected -IS [UIMenuItem])) {
            ($Selected -AS [UIMenuItem]).Invoke($Context)
        }
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::Enter) {
                $this.InvokeSelected($Context)

                Break
            }

            ([ConsoleKey]::Spacebar) {
                $this.InvokeSelected($Context)

                Break
            }

            Default {
                ([UIList]$this).HandleKey($KeyInfo, $Context)
            }
        }
    }
}
