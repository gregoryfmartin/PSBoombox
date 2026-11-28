using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI THEME MODAL
#
# CENTERED TABBED MODAL DIALOG ORGANIZING DARK AND LIGHT COLOR THEMES INTO
# UITAB PAGES WITH IMMEDIATE LIVE PREVIEW, SWATCH STRIP, AND APPLY/CANCEL.
#
###############################################################################

Class UIThemeModal : UITabContainer {
    [UIPanel]$DarkPanel
    [UIList]$DarkList
    [UIButton]$DarkApplyButton
    [UIButton]$DarkCancelButton
    [UIPanel]$LightPanel
    [UIList]$LightList
    [UIButton]$LightApplyButton
    [UIButton]$LightCancelButton
    [Boolean]$SuppressPreviewEvents
    [Boolean]$SwatchInfoDirty
    [ScriptBlock]$OnThemePreview
    [ScriptBlock]$OnThemeApply
    [ScriptBlock]$OnThemeCancel

    UIThemeModal(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) : base() {
        $this.SuppressPreviewEvents = $false
        $this.SwatchInfoDirty       = $true
        $this.OnThemePreview        = $null
        $this.OnThemeApply          = $null
        $this.OnThemeCancel         = $null

        [Hashtable]$Bounds = $this.ComputeModalBounds($LayoutWidth, $LayoutHeight)

        $this.SetBounds(
            [ATCoordinates]::new($Bounds.TopRow, $Bounds.LeftCol),
            [ATCoordinates]::new($Bounds.BottomRow, $Bounds.RightCol)
        )
        $this.SetupTitle('Themes', [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)

        [UIThemeModal]$SelfModal = $this
        [Int]$InnerWidth         = $Bounds.InnerWidth
        [Int]$ListStartRow       = $Bounds.TopRow + 1
        [Int]$ContentCol         = $Bounds.LeftCol + 2
        [Int]$ButtonRow          = $Bounds.TopRow + 13

        $this.DarkPanel = [UIPanel]::new()
        $this.DarkList  = [UIList]::new([ATCoordinates]::new($ListStartRow, $ContentCol), $null, 10)
        $this.DarkList.SetMaxDisplayWidth($InnerWidth)
        $this.DarkList.OnSelectionChanged = {
            Param(
                [UIList]$SourceList
            )

            $SelfModal.TriggerPreviewForCurrentSelection()
        }.GetNewClosure()
        $this.DarkList.OnActivate = {
            Param(
                [UIList]$SourceList,
                [Context]$ActionContext
            )

            [UIThemeDefinition]$Chosen = $SelfModal.GetSelectedTheme()

            If(($null -NE $Chosen) -AND ($null -NE $SelfModal.OnThemeApply)) {
                $SelfModal.OnThemeApply.Invoke($Chosen)
            }
        }.GetNewClosure()

        $this.DarkApplyButton = [UIButton]::new('Apply', [ATCoordinates]::new($ButtonRow, $ContentCol), {
            Param(
                [Context]$ActionContext
            )

            [UIThemeDefinition]$Chosen = $SelfModal.GetSelectedTheme()

            If(($null -NE $Chosen) -AND ($null -NE $SelfModal.OnThemeApply)) {
                $SelfModal.OnThemeApply.Invoke($Chosen)
            }
        }.GetNewClosure())

        $this.DarkCancelButton = [UIButton]::new('Cancel', [ATCoordinates]::new($ButtonRow, ($ContentCol + 12)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnThemeCancel) {
                $SelfModal.OnThemeCancel.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.DarkPanel.UiElementListing[0] = $this.DarkList
        $this.DarkPanel.UiElementListing[1] = $this.DarkApplyButton
        $this.DarkPanel.UiElementListing[2] = $this.DarkCancelButton

        $this.LightPanel = [UIPanel]::new()
        $this.LightList  = [UIList]::new([ATCoordinates]::new($ListStartRow, $ContentCol), $null, 10)
        $this.LightList.SetMaxDisplayWidth($InnerWidth)
        $this.LightList.OnSelectionChanged = {
            Param(
                [UIList]$SourceList
            )

            $SelfModal.TriggerPreviewForCurrentSelection()
        }.GetNewClosure()
        $this.LightList.OnActivate = {
            Param(
                [UIList]$SourceList,
                [Context]$ActionContext
            )

            [UIThemeDefinition]$Chosen = $SelfModal.GetSelectedTheme()

            If(($null -NE $Chosen) -AND ($null -NE $SelfModal.OnThemeApply)) {
                $SelfModal.OnThemeApply.Invoke($Chosen)
            }
        }.GetNewClosure()

        $this.LightApplyButton = [UIButton]::new('Apply', [ATCoordinates]::new($ButtonRow, $ContentCol), {
            Param(
                [Context]$ActionContext
            )

            [UIThemeDefinition]$Chosen = $SelfModal.GetSelectedTheme()

            If(($null -NE $Chosen) -AND ($null -NE $SelfModal.OnThemeApply)) {
                $SelfModal.OnThemeApply.Invoke($Chosen)
            }
        }.GetNewClosure())

        $this.LightCancelButton = [UIButton]::new('Cancel', [ATCoordinates]::new($ButtonRow, ($ContentCol + 12)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnThemeCancel) {
                $SelfModal.OnThemeCancel.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.LightPanel.UiElementListing[0] = $this.LightList
        $this.LightPanel.UiElementListing[1] = $this.LightApplyButton
        $this.LightPanel.UiElementListing[2] = $this.LightCancelButton

        $this.OnPageChanged = {
            Param(
                [UITabContainer]$ChangedContainer
            )

            $SelfModal.TriggerPreviewForCurrentSelection()
        }.GetNewClosure()

        $null = $this.AddTab('Dark', $this.DarkPanel)
        $null = $this.AddTab('Light', $this.LightPanel)
    }

    [Hashtable]ComputeModalBounds(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) {
        [Int]$ModalWidth  = [Math]::Clamp(($LayoutWidth - 14), 58, 66)
        [Int]$ModalHeight = 14
        [Int]$MaxTopRow   = [Math]::Max(6, ($LayoutHeight - 2 - $ModalHeight))
        [Int]$RawTopRow   = [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2)
        [Int]$TopRow      = [Math]::Clamp($RawTopRow, 6, $MaxTopRow)
        [Int]$LeftCol     = [Math]::Max(2, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))

        Return @{
            Width      = $ModalWidth
            Height     = $ModalHeight
            TopRow     = $TopRow
            LeftCol    = $LeftCol
            BottomRow  = ($TopRow + $ModalHeight)
            RightCol   = ($LeftCol + $ModalWidth)
            InnerWidth = [Math]::Max(20, ($ModalWidth - 3))
        }
    }

    [Void]Resize(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) {
        [Hashtable]$Bounds = $this.ComputeModalBounds($LayoutWidth, $LayoutHeight)

        ([UITabContainer]$this).Resize(
            [ATCoordinates]::new($Bounds.TopRow, $Bounds.LeftCol),
            [ATCoordinates]::new($Bounds.BottomRow, $Bounds.RightCol)
        )

        [Int]$InnerWidth   = $Bounds.InnerWidth
        [Int]$ListStartRow = $Bounds.TopRow + 1
        [Int]$ContentCol   = $Bounds.LeftCol + 2
        [Int]$ButtonRow    = $Bounds.TopRow + 13

        $this.DarkList.SetLayout([ATCoordinates]::new($ListStartRow, $ContentCol), 10, $InnerWidth)
        $this.DarkApplyButton.SetCoordinates([ATCoordinates]::new($ButtonRow, $ContentCol))
        $this.DarkCancelButton.SetCoordinates([ATCoordinates]::new($ButtonRow, ($ContentCol + 12)))

        $this.LightList.SetLayout([ATCoordinates]::new($ListStartRow, $ContentCol), 10, $InnerWidth)
        $this.LightApplyButton.SetCoordinates([ATCoordinates]::new($ButtonRow, $ContentCol))
        $this.LightCancelButton.SetCoordinates([ATCoordinates]::new($ButtonRow, ($ContentCol + 12)))

        $this.MarkAllDirtyForThemeChange()
    }

    [Void]PopulateFromService(
        [UIThemeService]$ThemeService
    ) {
        If($null -EQ $ThemeService) {
            Return
        }

        [Boolean]$PrevSuppress      = $this.SuppressPreviewEvents
        $this.SuppressPreviewEvents = $true

        $this.DarkList.ClearItems()

        Foreach($ThemeDef in $ThemeService.DarkThemes) {
            [UIListItem]$Item = [UIListItem]::new($ThemeDef.Name, [ATCoordinates]::new(1, 1), $ThemeDef)
            $this.DarkList.AddItem($Item)
        }

        $this.LightList.ClearItems()

        Foreach($ThemeDef in $ThemeService.LightThemes) {
            [UIListItem]$Item = [UIListItem]::new($ThemeDef.Name, [ATCoordinates]::new(1, 1), $ThemeDef)
            $this.LightList.AddItem($Item)
        }

        $this.SuppressPreviewEvents = $PrevSuppress
    }

    [Void]OpenForTheme(
        [UIThemeService]$ThemeService,
        [UIThemeDefinition]$CurrentTheme,
        [Context]$Context
    ) {
        $this.SuppressPreviewEvents = $true

        $this.PopulateFromService($ThemeService)

        [Int]$TargetTabIdx  = 0
        [Int]$TargetItemIdx = 0

        If($null -NE $CurrentTheme) {
            If($CurrentTheme.Variant -EQ 'light') {
                For([Int]$Idx = 0; $Idx -LT $this.LightList.Items.Count; $Idx++) {
                    If([String]::Equals($this.LightList.Items[$Idx].LabelText, $CurrentTheme.Name, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                        $TargetTabIdx  = 1
                        $TargetItemIdx = $Idx

                        Break
                    }
                }
            } Else {
                For([Int]$Idx = 0; $Idx -LT $this.DarkList.Items.Count; $Idx++) {
                    If([String]::Equals($this.DarkList.Items[$Idx].LabelText, $CurrentTheme.Name, [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                        $TargetTabIdx  = 0
                        $TargetItemIdx = $Idx

                        Break
                    }
                }
            }
        }

        If($TargetTabIdx -EQ 1) {
            $this.LightList.SelectIndex($TargetItemIdx)
        } Else {
            $this.DarkList.SelectIndex($TargetItemIdx)
        }

        $this.SelectTab($TargetTabIdx, $Context)
        $this.Activate($Context)

        $this.TabGroupFocused = $false

        If($this.TabGroup.IsFocused() -EQ $true) {
            $this.TabGroup.Unfocus($Context)
        }

        [UIPanel]$ActivePanel = $this.GetActiveContentPanel()

        If($null -NE $ActivePanel) {
            $ActivePanel.FocusElementByKey(0, $Context)
        }

        $this.SuppressPreviewEvents = $false

        $this.MarkAllDirtyForThemeChange()
    }

    [UIList]GetActiveList() {
        If($this.ActivePageIndex -EQ 1) {
            Return $this.LightList
        }

        Return $this.DarkList
    }

    [UIThemeDefinition]GetSelectedTheme() {
        [UIList]$ActiveList       = $this.GetActiveList()
        [UIListItem]$SelectedItem = $ActiveList.GetSelectedItem()

        If($null -NE $SelectedItem) {
            Return ($SelectedItem.Tag -AS [UIThemeDefinition])
        }

        Return $null
    }

    [Void]TriggerPreviewForCurrentSelection() {
        $this.SwatchInfoDirty = $true

        If($this.SuppressPreviewEvents -EQ $true) {
            Return
        }

        [UIThemeDefinition]$SelectedTheme = $this.GetSelectedTheme()

        If(($null -NE $SelectedTheme) -AND ($null -NE $this.OnThemePreview)) {
            $this.OnThemePreview.Invoke($SelectedTheme)
        }
    }

    [Void]MarkAllDirtyForThemeChange() {
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)
        $this.SetupTitle('Themes', [ColorLibrary]::BoomboxModalBorder)

        $this.InteriorDirty                = $true
        $this.SwatchInfoDirty              = $true
        $this.DarkList.ViewportBlankDirty  = $true
        $this.LightList.ViewportBlankDirty = $true

        $this.SetAllDirty()
    }

    [Boolean]HandleModalKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        If($KeyInfo.Key -EQ [ConsoleKey]::Escape) {
            If($null -NE $this.OnThemeCancel) {
                $this.OnThemeCancel.Invoke($Context)
            }

            Return $false
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
            If(($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift) {
                $this.FocusPrevious($Context)
            } Else {
                $this.FocusNext($Context)
            }

            Return $true
        }

        [UIPanel]$ActivePanel = $this.GetActiveContentPanel()
        [Int]$ActiveKey       = ($null -NE $ActivePanel) ? $ActivePanel.ActiveIndex : 0

        If(($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) -OR ($KeyInfo.Key -EQ [ConsoleKey]::RightArrow)) {
            If(($this.TabGroupFocused -EQ $false) -AND (($ActiveKey -EQ 1) -OR ($ActiveKey -EQ 2)) -AND ($null -NE $ActivePanel)) {
                [Int]$NextBtnKey = ($ActiveKey -EQ 1) ? 2 : 1
                $ActivePanel.FocusElementByKey($NextBtnKey, $Context)

                Return $true
            }

            [Boolean]$KeepListFocus = ($this.TabGroupFocused -EQ $false)

            If($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) {
                $this.SelectPreviousTab($Context)
            } Else {
                $this.SelectNextTab($Context)
            }

            If($KeepListFocus -EQ $true) {
                [UIPanel]$NewPanel = $this.GetActiveContentPanel()

                If($null -NE $NewPanel) {
                    $this.TabGroupFocused = $false

                    If($this.TabGroup.IsFocused() -EQ $true) {
                        $this.TabGroup.Unfocus($Context)
                    }

                    $NewPanel.FocusElementByKey(0, $Context)
                }
            } Else {
                $this.FocusFirst($Context)
            }

            Return $true
        }

        If(($KeyInfo.Key -EQ [ConsoleKey]::UpArrow) -OR ($KeyInfo.Key -EQ [ConsoleKey]::DownArrow) -OR ($KeyInfo.Key -EQ [ConsoleKey]::PageUp) -OR ($KeyInfo.Key -EQ [ConsoleKey]::PageDown) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Home) -OR ($KeyInfo.Key -EQ [ConsoleKey]::End)) {
            If($this.TabGroupFocused -EQ $true) {
                If($KeyInfo.Key -EQ [ConsoleKey]::DownArrow) {
                    $this.FocusNext($Context)
                }

                Return $true
            }

            If($ActiveKey -EQ 0) {
                $this.GetActiveList().HandleKey($KeyInfo, $Context)
            } Elseif(($KeyInfo.Key -EQ [ConsoleKey]::UpArrow) -AND ($null -NE $ActivePanel)) {
                $ActivePanel.FocusElementByKey(0, $Context)
            }

            Return $true
        }

        If(($KeyInfo.Key -EQ [ConsoleKey]::Enter) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Spacebar)) {
            If(($this.TabGroupFocused -EQ $false) -AND ($ActiveKey -EQ 2)) {
                If($null -NE $this.OnThemeCancel) {
                    $this.OnThemeCancel.Invoke($Context)
                }

                Return $false
            }

            If(($KeyInfo.Key -EQ [ConsoleKey]::Enter) -OR (($this.TabGroupFocused -EQ $false) -AND ($ActiveKey -EQ 1))) {
                [UIThemeDefinition]$Chosen = $this.GetSelectedTheme()

                If(($null -NE $Chosen) -AND ($null -NE $this.OnThemeApply)) {
                    $this.OnThemeApply.Invoke($Chosen)
                }

                Return $false
            }
        }

        Return $true
    }

    [Void]Draw() {
        [Boolean]$NeedMetaDraw = ($this.InteriorDirty -EQ $true) -OR ($this.Dirty -EQ $true) -OR ($this.SwatchInfoDirty -EQ $true)

        ([UITabContainer]$this).Draw()

        If($NeedMetaDraw -EQ $false) {
            Return
        }

        [Int]$SwatchRow  = $this.LeftTop.Row.Value + 11
        [Int]$InfoRow    = $this.LeftTop.Row.Value + 12
        [Int]$StartCol   = $this.LeftTop.Column.Value + 2
        [Int]$InnerWidth = [Math]::Max(20, ($this.Width - 3))

        [ATStringComposite]$SwatchLine = [ATStringComposite]::new()
        $SwatchLine.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::BoomboxFooterHint)
                    Coordinates     = [ATCoordinates]::new($SwatchRow, $StartCol)
                }
                UserData   = 'Palette: '
                UseATReset = $true
            }
        )

        [TrueColor[]]$SampleColors = @(
            [ColorLibrary]::BoomboxStatusError,
            [ColorLibrary]::BoomboxStatusPlaying,
            [ColorLibrary]::BoomboxModalBorder,
            [ColorLibrary]::BoomboxBorderFocused,
            [ColorLibrary]::BoomboxPlaylistFileEntry,
            [ColorLibrary]::BoomboxParentDirEntry,
            [ColorLibrary]::TextActiveColor
        )

        Foreach($Sample in $SampleColors) {
            $SwatchLine.CompositeActual.Add(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        ForegroundColor = [ATForegroundColor24]::new($Sample)
                    }
                    UserData   = "`u{2588}`u{2588} "
                    UseATReset = $true
                }
            )
        }

        [String]$HexSummary     = "BG:$([ColorLibrary]::ThemeBackground.ToHexString()) FG:$([ColorLibrary]::TextActiveColor.ToHexString())"
        [Int]$RemainingForHex   = [Math]::Max(0, ($InnerWidth - 9 - ($SampleColors.Length * 3)))
        [String]$ClippedHex     = Format-TruncatedText $HexSummary $RemainingForHex
        [String]$PaddedHex      = $ClippedHex.PadRight($RemainingForHex, ' ')

        $SwatchLine.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::BoomboxFooterHint)
                }
                UserData   = "$($PaddedHex)"
                UseATReset = $true
            }
        )

        [UIThemeDefinition]$Selected = $this.GetSelectedTheme()
        [String]$VariantLabel        = ($this.ActivePageIndex -EQ 1) ? 'Light' : 'Dark'
        [String]$ThemeTitle          = ($null -NE $Selected) ? $Selected.Name : 'None'
        [String]$InfoRaw             = "Preview: $($ThemeTitle) ($($VariantLabel))"
        [String]$InfoPadded          = (Format-TruncatedText $InfoRaw $InnerWidth).PadRight($InnerWidth, ' ')

        [ATString]$InfoSegment = [ATString]@{
            Prefix = [ATStringPrefix]@{
                ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::BoomboxFooterStatus)
                Coordinates     = [ATCoordinates]::new($InfoRow, $StartCol)
            }
            UserData   = "$($InfoPadded)"
            UseATReset = $true
        }

        Write-Host "$($SwatchLine.ToAnsiControlSequenceString())$($InfoSegment.ToAnsiControlSequenceString())" -NoNewline

        $this.SwatchInfoDirty = $false
    }
}
