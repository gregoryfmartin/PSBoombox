using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI LIST
#
# A SCROLLABLE VERTICAL LIST OF SELECTABLE UILISTITEM ELEMENTS WITH
# VIEWPORT BLANK-ROW CLEARING, PAGING KEYS, AND ITEM ACTIVATION SUPPORT.
#
###############################################################################

Class UIList : UIBase {
    Static [Int]$DefaultVisibleItemCount = 10

    [Int]$SelectedIndex
    [Int]$ViewportOffset
    [Int]$VisibleItemCount
    [Int]$MaxItemWidth
    [Int]$MaxDisplayWidth
    [Boolean]$ViewportBlankDirty
    [List[UIListItem]]$Items
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnSelectionChanged
    [ScriptBlock]$OnActivate

    UIList() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            $null,
            [UIList]::DefaultVisibleItemCount
        )
    }

    UIList(
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $null,
            [UIList]::DefaultVisibleItemCount
        )
    }

    UIList(
        [ATCoordinates]$DrawCoordinates,
        [String[]]$Labels
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $Labels,
            [UIList]::DefaultVisibleItemCount
        )
    }

    UIList(
        [ATCoordinates]$DrawCoordinates,
        [String[]]$Labels,
        [Int]$VisibleItemCount
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $Labels,
            $VisibleItemCount
        )
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [String[]]$Labels,
        [Int]$VisibleItemCount
    ) {
        $this.SelectedIndex         = -1
        $this.ViewportOffset        = 0
        $this.VisibleItemCount      = ($VisibleItemCount -GT 0) ? $VisibleItemCount : [UIList]::DefaultVisibleItemCount
        $this.MaxItemWidth          = 0
        $this.MaxDisplayWidth       = 0
        $this.ViewportBlankDirty    = $true
        $this.Items                 = [List[UIListItem]]::new()
        $this.DrawCoordinates       = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.OnSelectionChanged    = $null
        $this.OnActivate            = $null
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true

        $this.SetupStates()

        If($null -NE $Labels) {
            $this.SetItems($Labels)
        }
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIList]$SelfElement            = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.ViewportBlankDirty = $true
                $SelfElement.Dirty              = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIList]$SelfElement            = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.ViewportBlankDirty = $true
                $SelfElement.Dirty              = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIList]$SelfElement            = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.ViewportBlankDirty = $true
                $SelfElement.Dirty              = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UIList]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMState]::ContextKeysPressed) -EQ $true)) {
                    [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                    If($null -NE $KeysPressed) {
                        Foreach($KeyInfo in $KeysPressed) {
                            $SelfElement.HandleKey($KeyInfo, $Context)
                        }
                    }
                }
            }
        })
    }

    [Void]SetMaxDisplayWidth(
        [Int]$Width
    ) {
        $this.MaxDisplayWidth = [Math]::Max(0, $Width)

        Foreach($Item in $this.Items) {
            $Item.MaxDisplayWidth = $this.MaxDisplayWidth
        }

        $this.LayoutItems()

        $this.ViewportBlankDirty = $true
        $this.Dirty              = $true
    }

    [Void]SetLayout(
        [ATCoordinates]$DrawCoordinates,
        [Int]$VisibleItemCount,
        [Int]$MaxDisplayWidth
    ) {
        $this.DrawCoordinates  = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.VisibleItemCount = ($VisibleItemCount -GT 0) ? $VisibleItemCount : [UIList]::DefaultVisibleItemCount
        $this.MaxDisplayWidth  = [Math]::Max(0, $MaxDisplayWidth)

        Foreach($Item in $this.Items) {
            $Item.MaxDisplayWidth = $this.MaxDisplayWidth
        }

        $this.LayoutItems()

        $this.ViewportBlankDirty = $true
        $this.Dirty              = $true
    }

    [Void]AddItem(
        [UIListItem]$Item
    ) {
        If($null -EQ $Item) {
            Return
        }

        $Item.MaxDisplayWidth = $this.MaxDisplayWidth

        $this.Items.Add($Item)

        If($Item.LabelText.Length -GT $this.MaxItemWidth) {
            $this.MaxItemWidth = $Item.LabelText.Length
        }

        If($this.IsActive() -EQ $true) {
            If($Item.IsActive() -EQ $false) {
                $Item.Activate($null)
            }

            If(($this.IsFocused() -EQ $true) -AND ($Item.IsFocused() -EQ $false)) {
                $Item.Focus($null)
            }
        }

        If($this.SelectedIndex -LT 0) {
            $this.SelectedIndex = 0

            $Item.SetSelected($true)
        }

        $this.LayoutItems()

        $this.ViewportBlankDirty = $true
        $this.Dirty              = $true
    }

    [Void]AddItem(
        [String]$LabelText
    ) {
        [UIListItem]$Item = [UIListItem]::new($LabelText)

        $this.AddItem($Item)
    }

    [Void]ClearItems() {
        $this.Items.Clear()

        $this.SelectedIndex      = -1
        $this.ViewportOffset     = 0
        $this.MaxItemWidth       = 0
        $this.ViewportBlankDirty = $true
        $this.Dirty              = $true
    }

    [Void]SetItems(
        [String[]]$Labels
    ) {
        $this.ClearItems()

        If($null -NE $Labels) {
            Foreach($Label in $Labels) {
                $this.AddItem($Label)
            }
        }
    }

    [Int]GetVisibleEndIndex() {
        If($this.Items.Count -EQ 0) {
            Return -1
        }

        [Int]$EffectiveVisibleCount = [Math]::Max(1, $this.VisibleItemCount)

        Return [Math]::Min(($this.Items.Count - 1), ($this.ViewportOffset + $EffectiveVisibleCount - 1))
    }

    [Void]LayoutItems() {
        If($this.Items.Count -EQ 0) {
            $this.ViewportOffset     = 0
            $this.ViewportBlankDirty = $true

            Return
        }

        [Int]$ComputedMaxWidth = 0

        Foreach($Item in $this.Items) {
            If($Item.LabelText.Length -GT $ComputedMaxWidth) {
                $ComputedMaxWidth = $Item.LabelText.Length
            }
        }

        $this.MaxItemWidth = $ComputedMaxWidth

        [Int]$EffectiveVisibleCount = [Math]::Max(1, $this.VisibleItemCount)

        If($this.SelectedIndex -GE 0) {
            If($this.SelectedIndex -LT $this.ViewportOffset) {
                $this.ViewportOffset = $this.SelectedIndex
            } Elseif($this.SelectedIndex -GE ($this.ViewportOffset + $EffectiveVisibleCount)) {
                $this.ViewportOffset = $this.SelectedIndex - $EffectiveVisibleCount + 1
            }
        }

        [Int]$MaxOffset      = [Math]::Max(0, ($this.Items.Count - $EffectiveVisibleCount))
        $this.ViewportOffset = [Math]::Clamp($this.ViewportOffset, 0, $MaxOffset)
        [Int]$EndIdx         = $this.GetVisibleEndIndex()

        For([Int]$Idx = $this.ViewportOffset; $Idx -LE $EndIdx; $Idx++) {
            [UIListItem]$VisibleItem     = $this.Items[$Idx]
            [Int]$VisualRow              = $this.DrawCoordinates.Row.Value + ($Idx - $this.ViewportOffset)
            $VisibleItem.DrawCoordinates = [ATCoordinates]::new($VisualRow, $this.DrawCoordinates.Column.Value)
            $VisibleItem.MaxDisplayWidth = $this.MaxDisplayWidth

            If($this.MaxDisplayWidth -GT 0) {
                $VisibleItem.ApplyVisuals()
            } Else {
                $VisibleItem.SetBlankSize($this.MaxItemWidth + 2)
                $VisibleItem.Dirty = $true
            }
        }

        $this.ViewportBlankDirty = $true
    }

    [Void]SelectIndex(
        [Int]$Index
    ) {
        If($this.Items.Count -EQ 0) {
            $this.SelectedIndex = -1

            Return
        }

        [Int]$PreviousIndex = $this.SelectedIndex
        [Int]$TargetIndex   = [Math]::Clamp($Index, 0, ($this.Items.Count - 1))

        If(($PreviousIndex -GE 0) -AND ($PreviousIndex -LT $this.Items.Count) -AND ($PreviousIndex -NE $TargetIndex)) {
            $this.Items[$PreviousIndex].SetSelected($false)
        }

        $this.SelectedIndex = $TargetIndex

        $this.Items[$TargetIndex].SetSelected($true)
        $this.LayoutItems()

        $this.Dirty = $true

        If(($TargetIndex -NE $PreviousIndex) -AND ($null -NE $this.OnSelectionChanged)) {
            $this.OnSelectionChanged.Invoke($this)
        }
    }

    [Void]MoveUp() {
        If($this.Items.Count -EQ 0) {
            Return
        }

        [Int]$NextIndex = ($this.SelectedIndex -LE 0) ? ($this.Items.Count - 1) : ($this.SelectedIndex - 1)

        $this.SelectIndex($NextIndex)
    }

    [Void]MoveDown() {
        If($this.Items.Count -EQ 0) {
            Return
        }

        [Int]$NextIndex = (($this.SelectedIndex -LT 0) -OR ($this.SelectedIndex -GE ($this.Items.Count - 1))) ? 0 : ($this.SelectedIndex + 1)

        $this.SelectIndex($NextIndex)
    }

    [Void]MovePageUp() {
        If($this.Items.Count -EQ 0) {
            Return
        }

        [Int]$Step      = [Math]::Max(1, $this.VisibleItemCount)
        [Int]$NextIndex = [Math]::Max(0, ($this.SelectedIndex - $Step))

        $this.SelectIndex($NextIndex)
    }

    [Void]MovePageDown() {
        If($this.Items.Count -EQ 0) {
            Return
        }

        [Int]$Step      = [Math]::Max(1, $this.VisibleItemCount)
        [Int]$NextIndex = [Math]::Min(($this.Items.Count - 1), ([Math]::Max(0, $this.SelectedIndex) + $Step))

        $this.SelectIndex($NextIndex)
    }

    [Void]MoveHome() {
        If($this.Items.Count -GT 0) {
            $this.SelectIndex(0)
        }
    }

    [Void]MoveEnd() {
        If($this.Items.Count -GT 0) {
            $this.SelectIndex($this.Items.Count - 1)
        }
    }

    [UIListItem]GetSelectedItem() {
        If(($this.SelectedIndex -GE 0) -AND ($this.SelectedIndex -LT $this.Items.Count)) {
            Return $this.Items[$this.SelectedIndex]
        }

        Return $null
    }

    [String]GetSelectedLabel() {
        [UIListItem]$Selected = $this.GetSelectedItem()

        If($null -NE $Selected) {
            Return $Selected.LabelText
        }

        Return ''
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        $this.HandleKey($KeyInfo, $null)
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                If(($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -NE [ConsoleModifiers]::Shift) {
                    $this.MoveUp()
                }

                Break
            }

            ([ConsoleKey]::DownArrow) {
                If(($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -NE [ConsoleModifiers]::Shift) {
                    $this.MoveDown()
                }

                Break
            }

            ([ConsoleKey]::PageUp) {
                $this.MovePageUp()

                Break
            }

            ([ConsoleKey]::PageDown) {
                $this.MovePageDown()

                Break
            }

            ([ConsoleKey]::Home) {
                $this.MoveHome()

                Break
            }

            ([ConsoleKey]::End) {
                $this.MoveEnd()

                Break
            }

            ([ConsoleKey]::Enter) {
                If($null -NE $this.OnActivate) {
                    $this.OnActivate.Invoke($this, $Context)
                }

                Break
            }

            Default {
                # IGNORE UNHANDLED KEYS
            }
        }
    }

    [Void]Activate(
        [Context]$Context
    ) {
        ([UIBase]$this).Activate($Context)

        Foreach($Item in $this.Items) {
            If($Item.IsActive() -EQ $false) {
                $Item.Activate($Context)
            }
        }

        $this.LayoutItems()

        $this.ViewportBlankDirty = $true
        $this.Dirty              = $true
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        ([UIBase]$this).Deactivate($Context)

        Foreach($Item in $this.Items) {
            If($Item.IsActive() -EQ $true) {
                $Item.Deactivate($Context)
            }
        }

        $this.ViewportBlankDirty = $true
        $this.Dirty              = $true
    }

    [Void]Focus(
        [Context]$Context
    ) {
        ([UIBase]$this).Focus($Context)

        If($this.IsFocused() -EQ $true) {
            Foreach($Item in $this.Items) {
                If(($Item.IsActive() -EQ $true) -AND ($Item.IsFocused() -EQ $false)) {
                    $Item.Focus($Context)
                }
            }
        }

        $this.Dirty = $true
    }

    [Void]Unfocus(
        [Context]$Context
    ) {
        ([UIBase]$this).Unfocus($Context)

        Foreach($Item in $this.Items) {
            If($Item.IsFocused() -EQ $true) {
                $Item.Unfocus($Context)
            }
        }

        $this.Dirty = $true
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)

        If($this.IsActive() -EQ $true) {
            Foreach($Item in $this.Items) {
                $Item.Update($Context)
            }
        }
    }

    [String]BuildUnusedRowsBlankString(
        [Int]$DrawnCount
    ) {
        [Int]$EffectiveVisibleCount = [Math]::Max(1, $this.VisibleItemCount)

        If($DrawnCount -GE $EffectiveVisibleCount) {
            Return ''
        }

        [Int]$ClearWidth             = ($this.MaxDisplayWidth -GT 0) ? $this.MaxDisplayWidth : [Math]::Max(4, ($this.MaxItemWidth + 2))
        [String]$BlankRow            = ' ' * $ClearWidth
        [ATStringComposite]$Blanks   = [ATStringComposite]::new()

        For([Int]$SlotIdx = $DrawnCount; $SlotIdx -LT $EffectiveVisibleCount; $SlotIdx++) {
            $Blanks.CompositeActual.Add(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        Coordinates = [ATCoordinates]::new(($this.DrawCoordinates.Row.Value + $SlotIdx), $this.DrawCoordinates.Column.Value)
                    }
                    UserData   = "$($BlankRow)"
                    UseATReset = $true
                }
            )
        }

        Return "$($Blanks.ToAnsiControlSequenceString())"
    }

    [String]ToAnsiControlSequenceString() {
        [String]$Composite = ''
        [Int]$EndIdx       = $this.GetVisibleEndIndex()
        [Int]$DrawnCount   = 0

        If(($this.Items.Count -GT 0) -AND ($EndIdx -GE $this.ViewportOffset)) {
            For([Int]$Idx = $this.ViewportOffset; $Idx -LE $EndIdx; $Idx++) {
                $Composite += $this.Items[$Idx].ToAnsiControlSequenceString()
                $DrawnCount++
            }
        }

        $Composite += $this.BuildUnusedRowsBlankString($DrawnCount)

        Return "$($Composite)"
    }

    [Void]Draw() {
        [Int]$EndIdx     = $this.GetVisibleEndIndex()
        [Int]$DrawnCount = 0

        If(($this.Items.Count -GT 0) -AND ($EndIdx -GE $this.ViewportOffset)) {
            For([Int]$Idx = $this.ViewportOffset; $Idx -LE $EndIdx; $Idx++) {
                $this.Items[$Idx].Draw()
                $DrawnCount++
            }
        }

        If($this.ViewportBlankDirty -EQ $true) {
            [String]$ClearOutput = $this.BuildUnusedRowsBlankString($DrawnCount)

            If($ClearOutput.Length -GT 0) {
                Write-Host "$($ClearOutput)" -NoNewline
            }

            $this.ViewportBlankDirty = $false
        }

        $this.Dirty = $false
    }
}
