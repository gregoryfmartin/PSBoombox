using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI PANEL
#
# A SPECIALIZATION OF UI CONTAINER INTENDED TO HOUSE UI ELEMENTS AND MANAGE
# FOCUS FLOW.
#
###############################################################################

Class UIPanel : UIContainer {
    [Int]$ActiveIndex
    [Boolean]$InteriorClearDirty
    [Hashtable]$UiElementListing

    UIPanel() : base() {
        $this.ActiveIndex        = 0
        $this.InteriorClearDirty = $false
        $this.UiElementListing   = @{}
    }

    UIPanel(
        [Hashtable]$UiElementListing
    ) : base() {
        $this.ActiveIndex        = 0
        $this.InteriorClearDirty = $false
        $this.UiElementListing   = ($null -EQ $UiElementListing) ? @{} : $UiElementListing
    }

    [List[Int]]GetSortedElementKeys() {
        [List[Int]]$Keys = [List[Int]]::new()

        Foreach($Key in $this.UiElementListing.Keys) {
            $Keys.Add([Int]$Key)
        }

        $Keys.Sort()

        Return $Keys
    }

    [List[Int]]GetFocusableElementKeys() {
        [List[Int]]$FocusableKeys = [List[Int]]::new()

        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$Element = $this.UiElementListing[$Key] -AS [UIBase]

            If(($null -NE $Element) -AND ($null -NE $Element.Behavior) -AND ($Element.Behavior.CanHaveFocus -EQ $true)) {
                $FocusableKeys.Add($Key)
            }
        }

        Return $FocusableKeys
    }

    [UIBase]GetFocusedElement() {
        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$Child = $this.UiElementListing[$Key] -AS [UIBase]

            If(($null -NE $Child) -AND ($Child.IsFocused() -EQ $true)) {
                Return $Child
            }
        }

        Return $null
    }

    [Void]UnfocusAllElements(
        [Context]$Context
    ) {
        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$Child = $this.UiElementListing[$Key] -AS [UIBase]

            If(($null -NE $Child) -AND ($Child.IsFocused() -EQ $true)) {
                $Child.Unfocus($Context)
            }
        }
    }

    [Void]FocusElementByKey(
        [Int]$Key,
        [Context]$Context
    ) {
        Foreach($ChildKey in $this.GetSortedElementKeys()) {
            [UIBase]$Child = $this.UiElementListing[$ChildKey] -AS [UIBase]

            If(($null -NE $Child) -AND ($ChildKey -NE $Key) -AND ($Child.IsFocused() -EQ $true)) {
                $Child.Unfocus($Context)
            }
        }

        $this.ActiveIndex = $Key

        If($this.UiElementListing.ContainsKey($Key) -EQ $true) {
            [UIBase]$Target = $this.UiElementListing[$Key] -AS [UIBase]

            If($null -NE $Target) {
                If(($this.IsActive() -EQ $true) -AND ($Target.IsActive() -EQ $false)) {
                    $Target.Activate($Context)
                }

                If(($Target.IsActive() -EQ $true) -AND ($Target.Behavior.CanHaveFocus -EQ $true) -AND ($Target.IsFocused() -EQ $false)) {
                    $Target.Focus($Context)
                }
            }
        }
    }

    [Void]FocusFirst(
        [Context]$Context
    ) {
        [List[Int]]$FocusableKeys = $this.GetFocusableElementKeys()

        If($FocusableKeys.Count -GT 0) {
            $this.FocusElementByKey($FocusableKeys[0], $Context)
        }
    }

    [Void]FocusNext(
        [Context]$Context
    ) {
        [List[Int]]$FocusableKeys = $this.GetFocusableElementKeys()

        If($FocusableKeys.Count -EQ 0) {
            Return
        }

        [Int]$CurrentPos = $FocusableKeys.IndexOf($this.ActiveIndex)
        [Int]$NextPos    = ($CurrentPos -LT 0) ? 0 : (($CurrentPos + 1) % $FocusableKeys.Count)

        $this.FocusElementByKey($FocusableKeys[$NextPos], $Context)
    }

    [Void]FocusPrevious(
        [Context]$Context
    ) {
        [List[Int]]$FocusableKeys = $this.GetFocusableElementKeys()

        If($FocusableKeys.Count -EQ 0) {
            Return
        }

        [Int]$CurrentPos = $FocusableKeys.IndexOf($this.ActiveIndex)
        [Int]$PrevPos    = ($CurrentPos -LE 0) ? ($FocusableKeys.Count - 1) : ($CurrentPos - 1)

        $this.FocusElementByKey($FocusableKeys[$PrevPos], $Context)
    }

    [Void]SelectRadioGroupMember(
        [UIRadioButton]$SelectedRadio
    ) {
        If($null -EQ $SelectedRadio) {
            Return
        }

        $SelectedRadio.Select()

        [String]$GroupId = $SelectedRadio.Behavior.GroupIdentifier

        If(($null -NE $GroupId) -AND ($GroupId.Length -GT 0)) {
            Foreach($Element in $this.UiElementListing.Values) {
                If($Element -IS [UIRadioButton]) {
                    [UIRadioButton]$Peer = $Element -AS [UIRadioButton]

                    If(($Peer.Behavior.GroupIdentifier -EQ $GroupId) -AND ([Object]::ReferenceEquals($Peer, $SelectedRadio) -EQ $false)) {
                        $Peer.Deselect()
                    }
                }
            }
        }
    }

    [UIRadioButton]GetSelectedRadioGroupMember(
        [String]$GroupIdentifier
    ) {
        If(($null -EQ $GroupIdentifier) -OR ($GroupIdentifier.Length -EQ 0)) {
            Return $null
        }

        Foreach($Key in $this.GetSortedElementKeys()) {
            [Object]$Element = $this.UiElementListing[$Key]

            If($Element -IS [UIRadioButton]) {
                [UIRadioButton]$Radio = $Element -AS [UIRadioButton]

                If(($Radio.Behavior.GroupIdentifier -EQ $GroupIdentifier) -AND ($Radio.State -EQ [UIRadioButtonState]::Selected)) {
                    Return $Radio
                }
            }
        }

        Return $null
    }

    [Void]SetAllElementsDirty() {
        $this.Dirty = $true

        If($this.Width -GE 1) {
            $this.SetAllDirty()
        }

        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$UiElement = $this.UiElementListing[$Key] -AS [UIBase]

            If($null -EQ $UiElement) {
                Continue
            }

            If($UiElement -IS [UIList]) {
                [UIList]$ListElement            = $UiElement -AS [UIList]
                $ListElement.ViewportBlankDirty = $true

                Foreach($ListItem in $ListElement.Items) {
                    $ListItem.Dirty = $true
                }

                $ListElement.Dirty = $true
            } Elseif($UiElement -IS [UINumberSpinner]) {
                [UINumberSpinner]$SpinnerElement = $UiElement -AS [UINumberSpinner]
                $SpinnerElement.LeftChevron.Dirty  = $true
                $SpinnerElement.RightChevron.Dirty = $true
                $SpinnerElement.Dirty              = $true
            } Elseif($UiElement -IS [UIVolumeControl]) {
                [UIVolumeControl]$VolElement = $UiElement -AS [UIVolumeControl]
                $VolElement.VolumeBar.Dirty  = $true
                $VolElement.Dirty            = $true
            } Elseif($UiElement -IS [UITrackProgressBar]) {
                [UITrackProgressBar]$ScrubElement = $UiElement -AS [UITrackProgressBar]
                $ScrubElement.ProgressBar.Dirty    = $true
                $ScrubElement.Dirty                = $true
            } Elseif($UiElement -IS [UIPanel]) {
                ($UiElement -AS [UIPanel]).SetAllElementsDirty()
            } Elseif($UiElement -IS [UIContainer]) {
                ($UiElement -AS [UIContainer]).SetAllDirty()
                $UiElement.Dirty = $true
            } Else {
                $UiElement.Dirty = $true
            }
        }
    }

    [Void]ClearInterior() {
        ([UIContainer]$this).ClearInterior()
        $this.SetAllElementsDirty()
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIContainer]$this).Update($Context)

        If($this.IsActive() -EQ $true) {
            Foreach($Key in $this.GetSortedElementKeys()) {
                [UIBase]$UiElement = $this.UiElementListing[$Key] -AS [UIBase]

                If($null -NE $UiElement) {
                    $UiElement.Update($Context)
                }
            }
        }
    }

    [Void]Draw() {
        If($this.Width -GE 1) {
            ([UIContainer]$this).Draw()
        }

        If($this.InteriorClearDirty -EQ $true) {
            ([UIContainer]$this).ClearInterior()

            $this.InteriorClearDirty = $false
        }

        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$UiElement = $this.UiElementListing[$Key] -AS [UIBase]

            If($null -NE $UiElement) {
                $UiElement.Draw()
            }
        }

        $this.Dirty = $false
    }

    [Void]Activate(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $false) {
            ([UIContainer]$this).Activate($Context)
        }

        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$UiElement = $this.UiElementListing[$Key] -AS [UIBase]

            If(($null -NE $UiElement) -AND ($UiElement.IsActive() -EQ $false)) {
                $UiElement.Activate($Context)
            }
        }
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $true) {
            ([UIContainer]$this).Deactivate($Context)
        }

        Foreach($Key in $this.GetSortedElementKeys()) {
            [UIBase]$UiElement = $this.UiElementListing[$Key] -AS [UIBase]

            If(($null -NE $UiElement) -AND ($UiElement.IsActive() -EQ $true)) {
                $UiElement.Deactivate($Context)
            }
        }
    }
}
