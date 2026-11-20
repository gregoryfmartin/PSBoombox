using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI TAB CONTAINER
#
# MARRIES A UITABGROUP (ALIGNED TO THE TOP OR BOTTOM BORDER) WITH THE UIPANEL
# CONTENT PAGE ASSOCIATED WITH EACH UITAB INSIDE A SHARED CONTAINER BORDER.
#
###############################################################################

Class UITabContainer : UIContainer {
    [Int]$ActivePageIndex
    [Boolean]$InteriorDirty
    [Boolean]$TabGroupFocused
    [UITabAlignment]$TabAlignment
    [UITabGroup]$TabGroup

    UITabContainer() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            [ATCoordinates]::new(10, 40),
            [UITabAlignment]::Top
        )
    }

    UITabContainer(
        [ATCoordinates]$LeftTop,
        [ATCoordinates]$RightBottom
    ) : base() {
        $this.Initialize(
            $LeftTop,
            $RightBottom,
            [UITabAlignment]::Top
        )
    }

    UITabContainer(
        [ATCoordinates]$LeftTop,
        [ATCoordinates]$RightBottom,
        [UITabAlignment]$TabAlignment
    ) : base() {
        $this.Initialize(
            $LeftTop,
            $RightBottom,
            $TabAlignment
        )
    }

    [Void]Initialize(
        [ATCoordinates]$LeftTop,
        [ATCoordinates]$RightBottom,
        [UITabAlignment]$TabAlignment
    ) {
        $this.LeftTop               = ($null -EQ $LeftTop) ? [ATCoordinates]::new(1, 1) : $LeftTop
        $this.RightBottom           = ($null -EQ $RightBottom) ? [ATCoordinates]::new(10, 40) : $RightBottom
        $this.TabAlignment          = ($TabAlignment -EQ [UITabAlignment]::None) ? [UITabAlignment]::Top : $TabAlignment
        $this.TabGroup              = [UITabGroup]::new()
        $this.ActivePageIndex       = -1
        $this.InteriorDirty         = $true
        $this.TabGroupFocused       = $false
        $this.Behavior.CanHaveFocus = $true

        $this.UpdateDimensions()

        [UITabContainer]$SelfContainer = $this
        $this.TabGroup.OnTabChanged    = {
            Param(
                [UITabGroup]$ChangedGroup
            )

            $SelfContainer.SyncActivePage($null)
        }.GetNewClosure()

        $this.UpdateTabGroupCoordinates()
    }

    [Void]SetupTitle(
        [String]$Title,
        [TrueColor]$Color
    ) {
        ([UIContainer]$this).SetupTitle($Title, $Color)

        $this.UpdateTabGroupCoordinates()
    }

    [Void]UpdateTabGroupCoordinates() {
        [Int]$TargetRow    = ($this.TabAlignment -EQ [UITabAlignment]::Bottom) ? $this.RightBottom.Row.Value : $this.LeftTop.Row.Value
        [Int]$TargetColumn = $this.LeftTop.Column.Value + 2

        If(($this.TabAlignment -EQ [UITabAlignment]::Top) -AND ($this.UseTitle -EQ $true) -AND ($this.Title.Length -GT 0)) {
            $TargetColumn = $this.LeftTop.Column.Value + $this.Title.Length + 4
        }

        $this.TabGroup.DrawCoordinates = [ATCoordinates]::new($TargetRow, $TargetColumn)

        $this.TabGroup.LayoutTabs()
    }

    [Void]SetTabAlignment(
        [UITabAlignment]$Alignment
    ) {
        If($Alignment -EQ [UITabAlignment]::None) {
            Return
        }

        $this.TabAlignment = $Alignment

        $this.UpdateTabGroupCoordinates()
        $this.SetAllDirty()
    }

    [Void]AddTab(
        [UITab]$Tab
    ) {
        If($null -EQ $Tab) {
            Return
        }

        $this.TabGroup.AddTab($Tab)
        $this.UpdateTabGroupCoordinates()
        $this.SyncActivePage($null)
    }

    [UITab]AddTab(
        [String]$LabelText,
        [UIPanel]$ContentPanel
    ) {
        [UITab]$Tab = $this.TabGroup.AddTab($LabelText, $ContentPanel)

        $this.UpdateTabGroupCoordinates()
        $this.SyncActivePage($null)

        Return $Tab
    }

    [UIPanel]GetActiveContentPanel() {
        [UITab]$SelectedTab = $this.TabGroup.GetSelectedTab()

        If($null -NE $SelectedTab) {
            Return $SelectedTab.ContentPanel
        }

        Return $null
    }

    [Void]SyncActivePage(
        [Context]$Context
    ) {
        [Int]$DesiredIndex = $this.TabGroup.SelectedIndex

        If($DesiredIndex -EQ $this.ActivePageIndex) {
            [UIPanel]$CurrentPanel = $this.GetActiveContentPanel()

            If(($null -NE $CurrentPanel) -AND ($this.IsActive() -EQ $true) -AND ($CurrentPanel.IsActive() -EQ $false)) {
                $CurrentPanel.Activate($Context)
                $CurrentPanel.SetAllElementsDirty()
            }

            Return
        }

        If(($this.ActivePageIndex -GE 0) -AND ($this.ActivePageIndex -LT $this.TabGroup.Tabs.Count)) {
            [UIPanel]$PreviousPanel = $this.TabGroup.Tabs[$this.ActivePageIndex].ContentPanel

            If($null -NE $PreviousPanel) {
                [UIBase]$FocusedChild = $PreviousPanel.GetFocusedElement()

                If($null -NE $FocusedChild) {
                    $FocusedChild.Unfocus($Context)
                }

                If($PreviousPanel.IsActive() -EQ $true) {
                    $PreviousPanel.Deactivate($Context)
                }
            }
        }

        $this.ActivePageIndex = $DesiredIndex
        $this.InteriorDirty   = $true

        $this.SetAllDirty()

        [UIPanel]$NewPanel = $this.GetActiveContentPanel()

        If($null -NE $NewPanel) {
            If($this.IsActive() -EQ $true) {
                If($NewPanel.IsActive() -EQ $false) {
                    $NewPanel.Activate($Context)
                }

                $NewPanel.SetAllElementsDirty()
            }
        }
    }

    [Void]SelectTab(
        [Int]$Index,
        [Context]$Context
    ) {
        $this.TabGroup.SelectIndex($Index)
        $this.SyncActivePage($Context)
    }

    [Void]SelectNextTab(
        [Context]$Context
    ) {
        $this.TabGroup.SelectNext()
        $this.SyncActivePage($Context)
    }

    [Void]SelectPreviousTab(
        [Context]$Context
    ) {
        $this.TabGroup.SelectPrevious()
        $this.SyncActivePage($Context)
    }

    [Void]UnfocusActiveContent(
        [Context]$Context
    ) {
        [UIPanel]$ActivePanel = $this.GetActiveContentPanel()

        If($null -NE $ActivePanel) {
            [UIBase]$FocusedChild = $ActivePanel.GetFocusedElement()

            If($null -NE $FocusedChild) {
                $FocusedChild.Unfocus($Context)
            }
        }
    }

    [Void]FocusFirst(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $false) {
            Return
        }

        $this.UnfocusActiveContent($Context)

        $this.TabGroupFocused = $true

        If($this.TabGroup.IsFocused() -EQ $false) {
            $this.TabGroup.Focus($Context)
        }
    }

    [Void]FocusNext(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $false) {
            Return
        }

        [UIPanel]$ActivePanel      = $this.GetActiveContentPanel()
        [List[Int]]$FocusableKeys = ($null -NE $ActivePanel) ? $ActivePanel.GetFocusableElementKeys() : [List[Int]]::new()

        If($this.TabGroupFocused -EQ $true) {
            If($FocusableKeys.Count -GT 0) {
                If($this.TabGroup.IsFocused() -EQ $true) {
                    $this.TabGroup.Unfocus($Context)
                }

                $this.TabGroupFocused = $false

                $ActivePanel.FocusFirst($Context)
            } Elseif($this.TabGroup.IsFocused() -EQ $false) {
                $this.TabGroup.Focus($Context)
            }

            Return
        }

        If($FocusableKeys.Count -EQ 0) {
            $this.FocusFirst($Context)

            Return
        }

        [UIBase]$FocusedChild = $ActivePanel.GetFocusedElement()

        If($null -EQ $FocusedChild) {
            $ActivePanel.FocusFirst($Context)

            Return
        }

        [Int]$CurrentPos = $FocusableKeys.IndexOf($ActivePanel.ActiveIndex)

        If($CurrentPos -GE ($FocusableKeys.Count - 1)) {
            $this.FocusFirst($Context)
        } Else {
            $ActivePanel.FocusNext($Context)
        }
    }

    [Void]FocusPrevious(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $false) {
            Return
        }

        [UIPanel]$ActivePanel      = $this.GetActiveContentPanel()
        [List[Int]]$FocusableKeys = ($null -NE $ActivePanel) ? $ActivePanel.GetFocusableElementKeys() : [List[Int]]::new()

        If($this.TabGroupFocused -EQ $true) {
            If($FocusableKeys.Count -GT 0) {
                If($this.TabGroup.IsFocused() -EQ $true) {
                    $this.TabGroup.Unfocus($Context)
                }

                $this.TabGroupFocused = $false

                $ActivePanel.FocusElementByKey($FocusableKeys[$FocusableKeys.Count - 1], $Context)
            } Elseif($this.TabGroup.IsFocused() -EQ $false) {
                $this.TabGroup.Focus($Context)
            }

            Return
        }

        If($FocusableKeys.Count -EQ 0) {
            $this.FocusFirst($Context)

            Return
        }

        [UIBase]$FocusedChild = $ActivePanel.GetFocusedElement()

        If($null -EQ $FocusedChild) {
            $ActivePanel.FocusElementByKey($FocusableKeys[$FocusableKeys.Count - 1], $Context)

            Return
        }

        [Int]$CurrentPos = $FocusableKeys.IndexOf($ActivePanel.ActiveIndex)

        If($CurrentPos -LE 0) {
            $this.FocusFirst($Context)
        } Else {
            $ActivePanel.FocusPrevious($Context)
        }
    }

    [Void]SetAllDirty() {
        ([UIContainer]$this).SetAllDirty()

        $this.TabGroup.Dirty = $true

        Foreach($Tab in $this.TabGroup.Tabs) {
            $Tab.Dirty = $true
        }

        [UIPanel]$ActivePanel = $this.GetActiveContentPanel()

        If($null -NE $ActivePanel) {
            $ActivePanel.SetAllElementsDirty()
        }
    }

    [Void]Activate(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $false) {
            ([UIContainer]$this).Activate($Context)
        }

        $this.TabGroup.Activate($Context)

        [UIPanel]$ActivePanel = $this.GetActiveContentPanel()

        If(($null -NE $ActivePanel) -AND ($ActivePanel.IsActive() -EQ $false)) {
            $ActivePanel.Activate($Context)
        }

        $this.InteriorDirty = $true

        $this.SetAllDirty()
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        $this.UnfocusActiveContent($Context)

        $this.TabGroupFocused = $false

        If($this.TabGroup.IsFocused() -EQ $true) {
            $this.TabGroup.Unfocus($Context)
        }

        If($this.TabGroup.IsActive() -EQ $true) {
            $this.TabGroup.Deactivate($Context)
        }

        Foreach($Tab in $this.TabGroup.Tabs) {
            If(($null -NE $Tab.ContentPanel) -AND ($Tab.ContentPanel.IsActive() -EQ $true)) {
                $Tab.ContentPanel.Deactivate($Context)
            }
        }

        If($this.IsActive() -EQ $true) {
            ([UIContainer]$this).Deactivate($Context)
        }

        $this.SetAllDirty()
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIContainer]$this).Update($Context)

        If($this.IsActive() -EQ $true) {
            $this.TabGroup.Update($Context)
            $this.SyncActivePage($Context)

            [UIPanel]$ActivePanel = $this.GetActiveContentPanel()

            If(($null -NE $ActivePanel) -AND ($ActivePanel.IsActive() -EQ $true)) {
                $ActivePanel.Update($Context)
            }
        }
    }

    [Void]Draw() {
        If(($this.InteriorDirty -EQ $true) -AND ($this.Width -GT 1) -AND ($this.Height -GT 1)) {
            ([UIContainer]$this).ClearInterior()

            $this.InteriorDirty = $false
        }

        ([UIContainer]$this).Draw()
        $this.TabGroup.Draw()

        [UIPanel]$ActivePanel = $this.GetActiveContentPanel()

        If($null -NE $ActivePanel) {
            $ActivePanel.Draw()
        }

        $this.Dirty = $false
    }
}
