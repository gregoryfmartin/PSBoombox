using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI TAB GROUP
#
# ORDERS AND MANAGES HORIZONTAL LAYOUT, SELECTION, FOCUS, AND KEYBOARD
# NAVIGATION ACROSS A COLLECTION OF UITAB ELEMENTS.
#
###############################################################################

Class UITabGroup : UIBase {
    Static [Int]$DefaultTabSpacing = 1

    [Int]$SelectedIndex
    [Int]$TabSpacing
    [List[UITab]]$Tabs
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnTabChanged

    UITabGroup() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            $null,
            [UITabGroup]::DefaultTabSpacing
        )
    }

    UITabGroup(
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $null,
            [UITabGroup]::DefaultTabSpacing
        )
    }

    UITabGroup(
        [ATCoordinates]$DrawCoordinates,
        [UITab[]]$Tabs
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $Tabs,
            [UITabGroup]::DefaultTabSpacing
        )
    }

    UITabGroup(
        [ATCoordinates]$DrawCoordinates,
        [UITab[]]$Tabs,
        [Int]$TabSpacing
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $Tabs,
            $TabSpacing
        )
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [UITab[]]$Tabs,
        [Int]$TabSpacing
    ) {
        $this.SelectedIndex         = -1
        $this.TabSpacing            = ($TabSpacing -GE 0) ? $TabSpacing : [UITabGroup]::DefaultTabSpacing
        $this.Tabs                  = [List[UITab]]::new()
        $this.DrawCoordinates       = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.OnTabChanged          = $null
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true

        $this.SetupStates()

        If($null -NE $Tabs) {
            Foreach($Tab in $Tabs) {
                If($null -NE $Tab) {
                    $this.AddTab($Tab)
                }
            }
        }
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITabGroup]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty       = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITabGroup]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty       = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITabGroup]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty       = $true
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UITabGroup]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty       = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UITabGroup]$SelfElement           = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                If($null -NE $KeysPressed) {
                    Foreach($KeyInfo in $KeysPressed) {
                        $SelfElement.HandleKey($KeyInfo)
                    }
                }
            }
        })
    }

    [Void]AddTab(
        [UITab]$Tab
    ) {
        If($null -EQ $Tab) {
            Return
        }

        If(($this.IsActive() -EQ $true) -AND ($Tab.IsActive() -EQ $false)) {
            $Tab.Activate($null)
        }

        $this.Tabs.Add($Tab)

        If($this.Tabs.Count -EQ 1) {
            $this.SelectIndex(0)
        }

        $this.LayoutTabs()
    }

    [UITab]AddTab(
        [String]$LabelText
    ) {
        [UITab]$Tab = [UITab]::new($LabelText)

        $this.AddTab($Tab)

        Return $Tab
    }

    [UITab]AddTab(
        [String]$LabelText,
        [UIPanel]$ContentPanel
    ) {
        [UITab]$Tab = [UITab]::new($LabelText, $ContentPanel)

        $this.AddTab($Tab)

        Return $Tab
    }

    [Void]ClearTabs() {
        $this.Tabs.Clear()

        $this.SelectedIndex = -1
        $this.Dirty         = $true
    }

    [Void]LayoutTabs() {
        [Int]$CurrentColumn = $this.DrawCoordinates.Column.Value
        [Int]$Row           = $this.DrawCoordinates.Row.Value

        Foreach($Tab in $this.Tabs) {
            $Tab.DrawCoordinates = [ATCoordinates]::new($Row, $CurrentColumn)
            $Tab.Dirty           = $true
            $CurrentColumn      += ($Tab.GetRenderedWidth() + $this.TabSpacing)
        }

        $this.Dirty = $true
    }

    [Void]SelectIndex(
        [Int]$Index
    ) {
        If($this.Tabs.Count -EQ 0) {
            $this.SelectedIndex = -1

            Return
        }

        [Int]$ClampedIndex = [Math]::Clamp($Index, 0, ($this.Tabs.Count - 1))
        [Boolean]$Changed  = ($ClampedIndex -NE $this.SelectedIndex)

        If(($this.SelectedIndex -GE 0) -AND ($this.SelectedIndex -LT $this.Tabs.Count) -AND ($Changed -EQ $true)) {
            [UITab]$PreviousTab = $this.Tabs[$this.SelectedIndex]

            If($PreviousTab.IsFocused() -EQ $true) {
                $PreviousTab.Unfocus($null)
            }

            $PreviousTab.SetSelected($false)
        }

        $this.SelectedIndex = $ClampedIndex

        [UITab]$SelectedTab = $this.Tabs[$ClampedIndex]

        If($Changed -EQ $true) {
            $SelectedTab.SetSelected($true)
        } Else {
            $SelectedTab.ApplyVisuals()
        }

        If(($this.IsFocused() -EQ $true) -AND ($SelectedTab.IsActive() -EQ $true) -AND ($SelectedTab.IsFocused() -EQ $false)) {
            $SelectedTab.Focus($null)
        }

        $this.Dirty = $true

        If(($Changed -EQ $true) -AND ($null -NE $this.OnTabChanged)) {
            $this.OnTabChanged.Invoke($this)
        }
    }

    [Void]SelectNext() {
        If($this.Tabs.Count -EQ 0) {
            Return
        }

        [Int]$NextIndex = ($this.SelectedIndex -LT 0) ? 0 : (($this.SelectedIndex + 1) % $this.Tabs.Count)

        $this.SelectIndex($NextIndex)
    }

    [Void]SelectPrevious() {
        If($this.Tabs.Count -EQ 0) {
            Return
        }

        [Int]$PreviousIndex = ($this.SelectedIndex -LE 0) ? ($this.Tabs.Count - 1) : ($this.SelectedIndex - 1)

        $this.SelectIndex($PreviousIndex)
    }

    [UITab]GetSelectedTab() {
        If(($this.SelectedIndex -GE 0) -AND ($this.SelectedIndex -LT $this.Tabs.Count)) {
            Return $this.Tabs[$this.SelectedIndex]
        }

        Return $null
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::LeftArrow) {
                $this.SelectPrevious()

                Break
            }

            ([ConsoleKey]::RightArrow) {
                $this.SelectNext()

                Break
            }

            Default {
                # NO ACTION FOR OTHER KEYS
            }
        }
    }

    [Void]Activate(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $false) {
            ([UIBase]$this).Activate($Context)
        }

        Foreach($Tab in $this.Tabs) {
            If($Tab.IsActive() -EQ $false) {
                $Tab.Activate($Context)
            }
        }

        If(($this.SelectedIndex -LT 0) -AND ($this.Tabs.Count -GT 0)) {
            $this.SelectIndex(0)
        }

        $this.Dirty = $true
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $true) {
            ([UIBase]$this).Deactivate($Context)
        }

        Foreach($Tab in $this.Tabs) {
            If($Tab.IsActive() -EQ $true) {
                $Tab.Deactivate($Context)
            }
        }

        $this.Dirty = $true
    }

    [Void]Focus(
        [Context]$Context
    ) {
        If(($this.IsActive() -EQ $true) -AND ($this.IsFocused() -EQ $false)) {
            ([UIBase]$this).Focus($Context)
        }

        If($this.IsFocused() -EQ $true) {
            [UITab]$SelectedTab = $this.GetSelectedTab()

            If(($null -NE $SelectedTab) -AND ($SelectedTab.IsActive() -EQ $true) -AND ($SelectedTab.IsFocused() -EQ $false)) {
                $SelectedTab.Focus($Context)
            }
        }

        $this.Dirty = $true
    }

    [Void]Unfocus(
        [Context]$Context
    ) {
        If($this.IsFocused() -EQ $true) {
            ([UIBase]$this).Unfocus($Context)
        }

        Foreach($Tab in $this.Tabs) {
            If($Tab.IsFocused() -EQ $true) {
                $Tab.Unfocus($Context)
            }
        }

        $this.Dirty = $true
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)

        If($this.IsActive() -EQ $true) {
            Foreach($Tab in $this.Tabs) {
                $Tab.Update($Context)
            }
        }
    }

    [String]ToAnsiControlSequenceString() {
        [String]$Composite = ''

        Foreach($Tab in $this.Tabs) {
            $Composite += $Tab.ToAnsiControlSequenceString()
        }

        Return "$($Composite)"
    }

    [Void]Draw() {
        Foreach($Tab in $this.Tabs) {
            $Tab.Draw()
        }

        $this.Dirty = $false
    }
}
