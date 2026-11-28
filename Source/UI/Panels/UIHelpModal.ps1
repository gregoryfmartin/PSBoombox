using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI HELP MODAL
#
# CENTERED TABBED HELP MODAL RENDERING READ-ONLY SCROLLABLE SHORTCUT PAGES
# WITH TOP PADDING, SECTION HEADERS, AND RIGHT-EDGE SCROLL INDICATORS.
#
###############################################################################

Class UIHelpModal : UITabContainer {
    Static [String]$ScrollUpGlyph   = "`u{25B2}"
    Static [String]$ScrollDownGlyph = "`u{25BC}"

    [List[UIPanel]]$TabPanels
    [List[List[Hashtable]]]$TabRows
    [List[Int]]$TabScrollOffsets
    [Int]$ContentTopRow
    [Int]$ContentCol
    [Int]$InnerWidth
    [Int]$VisibleRows
    [Boolean]$ContentDirty
    [ScriptBlock]$OnCloseRequested

    UIHelpModal(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) : base() {
        $this.TabPanels        = [List[UIPanel]]::new()
        $this.TabRows          = [List[List[Hashtable]]]::new()
        $this.TabScrollOffsets = [List[Int]]::new()
        $this.ContentDirty     = $true
        $this.OnCloseRequested = $null

        [Hashtable]$Bounds  = $this.ComputeModalBounds($LayoutWidth, $LayoutHeight)
        $this.ContentTopRow = $Bounds.ContentTopRow
        $this.ContentCol    = $Bounds.ContentCol
        $this.InnerWidth    = $Bounds.InnerWidth
        $this.VisibleRows   = $Bounds.VisibleRows

        $this.SetBounds(
            [ATCoordinates]::new($Bounds.TopRow, $Bounds.LeftCol),
            [ATCoordinates]::new($Bounds.BottomRow, $Bounds.RightCol)
        )
        $this.SetupTitle('Help', [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)

        $this.BuildHelpTab('Global', @(
            [UIHelpModal]::MakeShortcutRow('F1', 'Open this Help dialog (Main mode)'),
            [UIHelpModal]::MakeShortcutRow('Tab / Shift+Tab', 'Cycle focus pane (Dir / Playlist / Controls)'),
            [UIHelpModal]::MakeShortcutRow('Space', 'Toggle Play / Pause (or press focused button)'),
            [UIHelpModal]::MakeShortcutRow('N / P', 'Play Next / Previous track'),
            [UIHelpModal]::MakeShortcutRow('S', 'Stop playback'),
            [UIHelpModal]::MakeShortcutRow('R', 'Cycle Repeat mode (Off / All / One)'),
            [UIHelpModal]::MakeShortcutRow('H', 'Toggle Shuffle (Off / On)'),
            [UIHelpModal]::MakeShortcutRow('+ / -', 'Increase / decrease volume by 5%'),
            [UIHelpModal]::MakeShortcutRow('M', 'Toggle Mute'),
            [UIHelpModal]::MakeShortcutRow('B', 'Toggle BurntToast notifications (persisted)'),
            [UIHelpModal]::MakeShortcutRow('E', 'Open Equalizer (10-Band ISO) modal'),
            [UIHelpModal]::MakeShortcutRow('V', 'Enter Visualizer Mode (non-MIDI playing track)'),
            [UIHelpModal]::MakeShortcutRow('T', 'Open Themes selector modal (Dark / Light)'),
            [UIHelpModal]::MakeShortcutRow('G / F2', 'Open Go to Directory modal'),
            [UIHelpModal]::MakeShortcutRow('W', 'Open Save Playlist modal'),
            [UIHelpModal]::MakeShortcutRow('Q / Esc', 'Quit PSBoombox cleanly')
        ), $Bounds)

        $this.BuildHelpTab('Playback', @(
            [UIHelpModal]::MakeHeaderRow('Directory Browser'),
            [UIHelpModal]::MakeIndentedShortcutRow('Up / Down', 'Move selection up / down (wraps)'),
            [UIHelpModal]::MakeIndentedShortcutRow('PgUp / PgDn', 'Scroll one page up / down'),
            [UIHelpModal]::MakeIndentedShortcutRow('Home / End', 'Jump to first / last entry'),
            [UIHelpModal]::MakeIndentedShortcutRow('Enter', 'Open folder, load playlist, or play track'),
            [UIHelpModal]::MakeIndentedShortcutRow('Backspace', 'Navigate to parent directory'),
            [UIHelpModal]::MakeIndentedShortcutRow('A', 'Add selected file or folder tracks to playlist'),
            [UIHelpModal]::MakeBlankRow(),
            [UIHelpModal]::MakeHeaderRow('Playlist Pane'),
            [UIHelpModal]::MakeIndentedShortcutRow('Enter', 'Play selected track'),
            [UIHelpModal]::MakeIndentedShortcutRow('U / Shift+Up', 'Move selected track up'),
            [UIHelpModal]::MakeIndentedShortcutRow('J / Shift+Down', 'Move selected track down'),
            [UIHelpModal]::MakeIndentedShortcutRow('Delete / X', 'Remove selected track from playlist'),
            [UIHelpModal]::MakeIndentedShortcutRow('C', 'Clear playlist and stop playback'),
            [UIHelpModal]::MakeBlankRow(),
            [UIHelpModal]::MakeHeaderRow('Playback Controls'),
            [UIHelpModal]::MakeIndentedShortcutRow('Left / Right', 'Move across transport buttons & volume'),
            [UIHelpModal]::MakeIndentedShortcutRow('Up / Down', 'Move to scrubber / return to transport'),
            [UIHelpModal]::MakeIndentedShortcutRow('Left / Right', 'Seek -5s / +5s (when scrubber focused)'),
            [UIHelpModal]::MakeIndentedShortcutRow('Up / Down', 'Adjust volume +/-5% (when VOL focused)'),
            [UIHelpModal]::MakeBlankRow(),
            [UIHelpModal]::MakeHeaderRow('Path Modals (G / F2 / W)'),
            [UIHelpModal]::MakeIndentedShortcutRow('Tab / Shift+Tab', 'Cycle Path Input, Confirm, and Cancel'),
            [UIHelpModal]::MakeIndentedShortcutRow('Enter / Esc', 'Submit path or cancel modal')
        ), $Bounds)

        $this.BuildHelpTab('Viz', @(
            [UIHelpModal]::MakeShortcutRow('Tab', 'Cycle forward to next visualizer'),
            [UIHelpModal]::MakeShortcutRow('V', 'Exit Visualizer Mode back to Main mode'),
            [UIHelpModal]::MakeShortcutRow('Space', 'Toggle Play / Pause'),
            [UIHelpModal]::MakeShortcutRow('N / P', 'Play Next / Previous track'),
            [UIHelpModal]::MakeShortcutRow('S', 'Stop playback and return to Main mode'),
            [UIHelpModal]::MakeShortcutRow('+ / -', 'Increase / decrease volume by 5%'),
            [UIHelpModal]::MakeShortcutRow('M', 'Toggle Mute'),
            [UIHelpModal]::MakeShortcutRow('R / H', 'Cycle Repeat mode / Toggle Shuffle'),
            [UIHelpModal]::MakeShortcutRow('B', 'Toggle BurntToast notifications'),
            [UIHelpModal]::MakeShortcutRow('Q', 'Quit PSBoombox cleanly')
        ), $Bounds)

        $this.BuildHelpTab('EQ', @(
            [UIHelpModal]::MakeShortcutRow('Tab / Shift+Tab', 'Switch focus between Faders and Top Buttons'),
            [UIHelpModal]::MakeShortcutRow('Left / Right', 'Select slider band or navigate top buttons'),
            [UIHelpModal]::MakeShortcutRow('Up / Down', 'Adjust focused slider by +/-1 dB'),
            [UIHelpModal]::MakeShortcutRow('PgUp / PgDn', 'Adjust focused slider by +/-3 dB'),
            [UIHelpModal]::MakeShortcutRow('Home / End', 'Jump focused slider to +12 dB / -12 dB'),
            [UIHelpModal]::MakeShortcutRow('0 / Delete', 'Reset focused slider to 0 dB'),
            [UIHelpModal]::MakeShortcutRow('T', 'Toggle Equalizer On / Off (persisted)'),
            [UIHelpModal]::MakeShortcutRow('P / Shift+P', 'Cycle forward / backward through presets'),
            [UIHelpModal]::MakeShortcutRow('] / [', 'Alternate preset cycle forward / backward'),
            [UIHelpModal]::MakeShortcutRow('S', 'Save current curve as custom named preset'),
            [UIHelpModal]::MakeShortcutRow('X', 'Delete active custom user preset'),
            [UIHelpModal]::MakeShortcutRow('F', 'Reset all bands to Flat (0 dB)'),
            [UIHelpModal]::MakeShortcutRow('E / Esc', 'Close Equalizer modal')
        ), $Bounds)

        $this.BuildHelpTab('Themes', @(
            [UIHelpModal]::MakeShortcutRow('Left / Right', 'Switch between Dark and Light tabs'),
            [UIHelpModal]::MakeShortcutRow('Up / Down', 'Browse and live-preview themes'),
            [UIHelpModal]::MakeShortcutRow('PgUp / PgDn', 'Scroll theme list one page'),
            [UIHelpModal]::MakeShortcutRow('Home / End', 'Jump to first / last theme in tab'),
            [UIHelpModal]::MakeShortcutRow('Tab / Shift+Tab', 'Cycle focus: Tabs, Theme List, Apply, Cancel'),
            [UIHelpModal]::MakeShortcutRow('Enter', 'Apply selected theme and persist to config'),
            [UIHelpModal]::MakeShortcutRow('Esc', 'Cancel and revert to previous theme')
        ), $Bounds)
    }

    Static [Hashtable]MakeHeaderRow(
        [String]$Title
    ) {
        Return @{
            Kind        = 'Header'
            Title       = ($null -EQ $Title) ? '' : $Title
            Key         = ''
            Description = ''
            Indent      = 0
        }
    }

    Static [Hashtable]MakeBlankRow() {
        Return @{
            Kind        = 'Blank'
            Title       = ''
            Key         = ''
            Description = ''
            Indent      = 0
        }
    }

    Static [Hashtable]MakeShortcutRow(
        [String]$KeyText,
        [String]$Description
    ) {
        Return @{
            Kind        = 'Shortcut'
            Title       = ''
            Key         = ($null -EQ $KeyText) ? '' : $KeyText
            Description = ($null -EQ $Description) ? '' : $Description
            Indent      = 0
        }
    }

    Static [Hashtable]MakeIndentedShortcutRow(
        [String]$KeyText,
        [String]$Description
    ) {
        Return @{
            Kind        = 'Shortcut'
            Title       = ''
            Key         = ($null -EQ $KeyText) ? '' : $KeyText
            Description = ($null -EQ $Description) ? '' : $Description
            Indent      = 2
        }
    }

    [Void]BuildHelpTab(
        [String]$TabTitle,
        [Hashtable[]]$Rows,
        [Hashtable]$Bounds
    ) {
        [UIPanel]$Panel                 = [UIPanel]::new()
        [List[Hashtable]]$RowCollection = [List[Hashtable]]::new()

        If($null -NE $Rows) {
            Foreach($RowObj in $Rows) {
                If($null -NE $RowObj) {
                    $RowCollection.Add($RowObj)
                }
            }
        }

        $this.TabPanels.Add($Panel)
        $this.TabRows.Add($RowCollection)
        $this.TabScrollOffsets.Add(0)

        $null = $this.AddTab($TabTitle, $Panel)
    }

    [Hashtable]ComputeModalBounds(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) {
        [Int]$ModalWidth        = [Math]::Clamp(($LayoutWidth - 6), 68, 76)
        [Int]$ModalHeight       = [Math]::Clamp(($LayoutHeight - 6), 15, 18)
        [Int]$MaxTopRow         = [Math]::Max(4, ($LayoutHeight - 2 - $ModalHeight))
        [Int]$RawTopRow         = [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2)
        [Int]$TopRow            = [Math]::Clamp($RawTopRow, 4, $MaxTopRow)
        [Int]$LeftCol           = [Math]::Max(2, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))
        [Int]$BottomRow         = $TopRow + $ModalHeight
        [Int]$RightCol          = $LeftCol + $ModalWidth
        [Int]$CalcInnerWidth    = [Math]::Max(20, ($ModalWidth - 3))
        [Int]$CalcContentTopRow = $TopRow + 2
        [Int]$CalcVisibleRows   = [Math]::Max(6, ($ModalHeight - 3))

        Return @{
            Width         = $ModalWidth
            Height        = $ModalHeight
            TopRow        = $TopRow
            LeftCol       = $LeftCol
            BottomRow     = $BottomRow
            RightCol      = $RightCol
            InnerWidth    = $CalcInnerWidth
            ContentTopRow = $CalcContentTopRow
            ContentCol    = ($LeftCol + 2)
            VisibleRows   = $CalcVisibleRows
        }
    }

    [Void]Resize(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) {
        [Hashtable]$Bounds  = $this.ComputeModalBounds($LayoutWidth, $LayoutHeight)
        $this.ContentTopRow = $Bounds.ContentTopRow
        $this.ContentCol    = $Bounds.ContentCol
        $this.InnerWidth    = $Bounds.InnerWidth
        $this.VisibleRows   = $Bounds.VisibleRows

        ([UITabContainer]$this).Resize(
            [ATCoordinates]::new($Bounds.TopRow, $Bounds.LeftCol),
            [ATCoordinates]::new($Bounds.BottomRow, $Bounds.RightCol)
        )

        For([Int]$Idx = 0; $Idx -LT $this.TabRows.Count; $Idx++) {
            [Int]$MaxOff = [Math]::Max(0, ($this.TabRows[$Idx].Count - $this.VisibleRows))
            $this.TabScrollOffsets[$Idx] = [Math]::Clamp($this.TabScrollOffsets[$Idx], 0, $MaxOff)
        }

        $this.MarkAllDirtyForThemeChange()
    }

    [List[Hashtable]]GetActiveRows() {
        If(($this.ActivePageIndex -GE 0) -AND ($this.ActivePageIndex -LT $this.TabRows.Count)) {
            Return $this.TabRows[$this.ActivePageIndex]
        }

        Return [List[Hashtable]]::new()
    }

    [Int]GetActiveScrollOffset() {
        If(($this.ActivePageIndex -GE 0) -AND ($this.ActivePageIndex -LT $this.TabScrollOffsets.Count)) {
            Return $this.TabScrollOffsets[$this.ActivePageIndex]
        }

        Return 0
    }

    [Int]GetActiveMaxScrollOffset() {
        [List[Hashtable]]$Rows = $this.GetActiveRows()

        Return [Math]::Max(0, ($Rows.Count - $this.VisibleRows))
    }

    [Boolean]ActivePageHasOverflow() {
        [List[Hashtable]]$Rows = $this.GetActiveRows()

        Return ($Rows.Count -GT $this.VisibleRows)
    }

    [Boolean]ActivePageCanScrollUp() {
        Return ($this.GetActiveScrollOffset() -GT 0)
    }

    [Boolean]ActivePageCanScrollDown() {
        [List[Hashtable]]$Rows = $this.GetActiveRows()

        Return (($this.GetActiveScrollOffset() + $this.VisibleRows) -LT $Rows.Count)
    }

    [Void]ScrollActivePage(
        [Int]$Delta
    ) {
        If(($this.ActivePageIndex -LT 0) -OR ($this.ActivePageIndex -GE $this.TabScrollOffsets.Count)) {
            Return
        }

        [Int]$Current = $this.TabScrollOffsets[$this.ActivePageIndex]
        [Int]$MaxOff  = $this.GetActiveMaxScrollOffset()
        [Int]$Next    = [Math]::Clamp(($Current + $Delta), 0, $MaxOff)

        If($Next -NE $Current) {
            $this.TabScrollOffsets[$this.ActivePageIndex] = $Next
            $this.ContentDirty                            = $true
        }
    }

    [Void]JumpActivePageTo(
        [Int]$TargetOffset
    ) {
        If(($this.ActivePageIndex -LT 0) -OR ($this.ActivePageIndex -GE $this.TabScrollOffsets.Count)) {
            Return
        }

        [Int]$Current = $this.TabScrollOffsets[$this.ActivePageIndex]
        [Int]$MaxOff  = $this.GetActiveMaxScrollOffset()
        [Int]$Next    = [Math]::Clamp($TargetOffset, 0, $MaxOff)

        If($Next -NE $Current) {
            $this.TabScrollOffsets[$this.ActivePageIndex] = $Next
            $this.ContentDirty                            = $true
        }
    }

    [Void]OpenHelp(
        [Context]$Context
    ) {
        For([Int]$Idx = 0; $Idx -LT $this.TabScrollOffsets.Count; $Idx++) {
            $this.TabScrollOffsets[$Idx] = 0
        }

        $this.SelectTab(0, $Context)
        $this.Activate($Context)
        $this.FocusFirst($Context)
        $this.MarkAllDirtyForThemeChange()
    }

    [Void]MarkAllDirtyForThemeChange() {
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)
        $this.SetupTitle('Help', [ColorLibrary]::BoomboxModalBorder)

        $this.InteriorDirty = $true
        $this.ContentDirty  = $true

        $this.SetAllDirty()
    }

    [Boolean]HandleModalKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        If(($KeyInfo.Key -EQ [ConsoleKey]::Escape) -OR ($KeyInfo.Key -EQ [ConsoleKey]::F1)) {
            If($null -NE $this.OnCloseRequested) {
                $this.OnCloseRequested.Invoke($Context)
            }

            Return $false
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
            If(($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift) {
                $this.SelectPreviousTab($Context)
            } Else {
                $this.SelectNextTab($Context)
            }

            $this.FocusFirst($Context)
            $this.ContentDirty = $true

            Return $true
        }

        If(($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) -OR ($KeyInfo.Key -EQ [ConsoleKey]::RightArrow)) {
            If($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) {
                $this.SelectPreviousTab($Context)
            } Else {
                $this.SelectNextTab($Context)
            }

            $this.FocusFirst($Context)
            $this.ContentDirty = $true

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::UpArrow) {
            $this.ScrollActivePage(-1)

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::DownArrow) {
            $this.ScrollActivePage(1)

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::PageUp) {
            $this.ScrollActivePage(-$this.VisibleRows)

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::PageDown) {
            $this.ScrollActivePage($this.VisibleRows)

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::Home) {
            $this.JumpActivePageTo(0)

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::End) {
            $this.JumpActivePageTo($this.GetActiveMaxScrollOffset())

            Return $true
        }

        Return $true
    }

    [String]BuildActivePageContentAnsi() {
        [List[Hashtable]]$Rows       = $this.GetActiveRows()
        [Int]$ScrollOffset           = $this.GetActiveScrollOffset()
        [Boolean]$HasOverflow        = $this.ActivePageHasOverflow()
        [Boolean]$ShowUp             = $this.ActivePageCanScrollUp()
        [Boolean]$ShowDown           = $this.ActivePageCanScrollDown()
        [Boolean]$HasGutter          = ($HasOverflow -EQ $true) -AND ($this.InnerWidth -GT 4)
        [Int]$ContentWidth           = ($HasGutter -EQ $true) ? ($this.InnerWidth - 2) : $this.InnerWidth
        [Int]$GutterCol              = $this.ContentCol + $this.InnerWidth - 2
        [String]$RuleChar            = [String][Char]0x2500
        [ATStringComposite]$Output   = [ATStringComposite]::new()

        For([Int]$Slot = 0; $Slot -LT $this.VisibleRows; $Slot++) {
            [Int]$RowCoord = $this.ContentTopRow + $Slot
            [Int]$DataIdx  = $ScrollOffset + $Slot

            If($DataIdx -GE $Rows.Count) {
                $Output.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            Coordinates = [ATCoordinates]::new($RowCoord, $this.ContentCol)
                        }
                        UserData   = (' ' * $ContentWidth)
                        UseATReset = $true
                    }
                )
            } Else {
                [Hashtable]$RowObj = $Rows[$DataIdx]
                [String]$Kind      = [String]$RowObj.Kind

                If($Kind -EQ 'Blank') {
                    $Output.CompositeActual.Add(
                        [ATString]@{
                            Prefix = [ATStringPrefix]@{
                                Coordinates = [ATCoordinates]::new($RowCoord, $this.ContentCol)
                            }
                            UserData   = (' ' * $ContentWidth)
                            UseATReset = $true
                        }
                    )
                } Elseif($Kind -EQ 'Header') {
                    [String]$TitleText  = [String]$RowObj.Title
                    [String]$HeaderBase = "$($RuleChar)$($RuleChar) $($TitleText) "
                    [Int]$PadLen        = [Math]::Max(0, ($ContentWidth - $HeaderBase.Length))
                    [String]$HeaderLine = Format-TruncatedText "$($HeaderBase)$($RuleChar * $PadLen)" $ContentWidth

                    $Output.CompositeActual.Add(
                        [ATString]@{
                            Prefix = [ATStringPrefix]@{
                                ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::BoomboxModalBorder)
                                Coordinates     = [ATCoordinates]::new($RowCoord, $this.ContentCol)
                            }
                            UserData   = "$($HeaderLine.PadRight($ContentWidth, ' '))"
                            UseATReset = $true
                        }
                    )
                } Else {
                    [Int]$Indent      = [Int]$RowObj.Indent
                    [Int]$KeyColWidth = 18
                    [String]$KeyPad   = ((' ' * $Indent) + [String]$RowObj.Key).PadRight(($Indent + $KeyColWidth), ' ') + ' '

                    If($KeyPad.Length -GE $ContentWidth) {
                        $KeyPad = Format-TruncatedText $KeyPad $ContentWidth
                    }

                    [Int]$DescWidth  = [Math]::Max(0, ($ContentWidth - $KeyPad.Length))
                    [String]$DescPad = ($DescWidth -GT 0) ? (Format-TruncatedText ([String]$RowObj.Description) $DescWidth).PadRight($DescWidth, ' ') : ''

                    $Output.CompositeActual.Add(
                        [ATString]@{
                            Prefix = [ATStringPrefix]@{
                                ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::BoomboxFooterStatus)
                                Coordinates     = [ATCoordinates]::new($RowCoord, $this.ContentCol)
                            }
                            UserData   = "$($KeyPad)"
                            UseATReset = $true
                        }
                    )

                    If($DescPad.Length -GT 0) {
                        $Output.CompositeActual.Add(
                            [ATString]@{
                                Prefix = [ATStringPrefix]@{
                                    ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::TextActiveColor)
                                    Coordinates     = [ATCoordinates]::new($RowCoord, ($this.ContentCol + $KeyPad.Length))
                                }
                                UserData   = "$($DescPad)"
                                UseATReset = $true
                            }
                        )
                    }
                }
            }

            If($HasGutter -EQ $true) {
                [String]$GutterGlyph = '  '

                If(($Slot -EQ 0) -AND ($ShowUp -EQ $true)) {
                    $GutterGlyph = " $([UIHelpModal]::ScrollUpGlyph)"
                } Elseif(($Slot -EQ ($this.VisibleRows - 1)) -AND ($ShowDown -EQ $true)) {
                    $GutterGlyph = " $([UIHelpModal]::ScrollDownGlyph)"
                }

                $Output.CompositeActual.Add(
                    [ATString]@{
                        Prefix = [ATStringPrefix]@{
                            ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIListScrollIndicator)
                            Coordinates     = [ATCoordinates]::new($RowCoord, $GutterCol)
                        }
                        UserData   = "$($GutterGlyph)"
                        UseATReset = $true
                    }
                )
            }
        }

        Return "$($Output.ToAnsiControlSequenceString())"
    }

    [Void]Draw() {
        [Boolean]$NeedContentDraw = ($this.InteriorDirty -EQ $true) -OR ($this.Dirty -EQ $true) -OR ($this.ContentDirty -EQ $true)

        ([UITabContainer]$this).Draw()

        If($NeedContentDraw -EQ $false) {
            Return
        }

        [String]$PageAnsi = $this.BuildActivePageContentAnsi()

        If($PageAnsi.Length -GT 0) {
            Write-Host "$($PageAnsi)" -NoNewline
        }

        $this.ContentDirty = $false
    }
}
