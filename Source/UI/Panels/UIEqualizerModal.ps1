using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI EQUALIZER MODAL
#
# CENTERED 10-BAND ISO GRAPHIC EQUALIZER MODAL WITH PREAMP SLIDER, ON/OFF
# TOGGLE, BUILT-IN AND CUSTOM NAMED PRESETS, AND INLINE PRESET SAVING.
#
###############################################################################

Class UIEqualizerModal : UIPanel {
    [UIButton]$ToggleEqButton
    [UIButton]$PresetButton
    [UIButton]$SavePresetButton
    [UIButton]$DeletePresetButton
    [UIButton]$FlatButton
    [UIButton]$CloseButton
    [UILabel]$StatusLineLabel
    [UILabel]$DividerRuleLabel
    [UILabel]$SavePromptLabel
    [UITextInput]$PresetNameInput
    [UIButton]$ConfirmSaveButton
    [UIButton]$CancelSaveButton
    [UIVerticalSlider]$PreampSlider
    [UIVerticalSlider[]]$BandSliders
    [UILabel]$HintLabel
    [Boolean]$IsNamingPreset
    [Boolean]$NamingRowClearDirty
    [Int]$LastFocusedSliderKey
    [Int]$NamingFocusSlot
    [String]$InlineStatusOverride
    [ScriptBlock]$OnToggleEq
    [ScriptBlock]$OnCyclePreset
    [ScriptBlock]$OnPreampChanged
    [ScriptBlock]$OnBandChanged
    [ScriptBlock]$OnSavePreset
    [ScriptBlock]$OnDeletePreset
    [ScriptBlock]$OnResetFlat
    [ScriptBlock]$OnCloseRequested

    UIEqualizerModal(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) : base() {
        [Int]$ModalWidth  = [Math]::Clamp(($LayoutWidth - 2), 76, 78)
        [Int]$ModalHeight = 16
        [Int]$TopRow      = [Math]::Max(3, [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2))
        [Int]$LeftCol     = [Math]::Max(2, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))

        $this.LeftTop     = [ATCoordinates]::new($TopRow, $LeftCol)
        $this.RightBottom = [ATCoordinates]::new(($TopRow + $ModalHeight), ($LeftCol + $ModalWidth))

        $this.UpdateDimensions()
        $this.SetupTitle('Equalizer (10-Band ISO)', [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)

        $this.IsNamingPreset       = $false
        $this.NamingRowClearDirty  = $false
        $this.LastFocusedSliderKey = 11
        $this.NamingFocusSlot      = 0
        $this.InlineStatusOverride = ''
        $this.OnToggleEq           = $null
        $this.OnCyclePreset        = $null
        $this.OnPreampChanged      = $null
        $this.OnBandChanged        = $null
        $this.OnSavePreset         = $null
        $this.OnDeletePreset       = $null
        $this.OnResetFlat          = $null
        $this.OnCloseRequested     = $null

        [UIEqualizerModal]$SelfModal = $this
        [Int]$InnerWidth             = [Math]::Max(20, ($this.Width - 4))
        [Int]$ControlRow             = $TopRow + 1
        [Int]$StatusRow              = $TopRow + 2
        [Int]$DividerRow             = $TopRow + 3
        [Int]$SliderTopRow           = $TopRow + 4
        [Int]$HintRow                = $TopRow + 15

        $this.ToggleEqButton = [UIButton]::new('EQ: Off', [ATCoordinates]::new($ControlRow, ($LeftCol + 2)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnToggleEq) {
                $SelfModal.OnToggleEq.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.PresetButton = [UIButton]::new($this.FormatPresetButtonLabel('Flat'), [ATCoordinates]::new($ControlRow, ($LeftCol + 14)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnCyclePreset) {
                $SelfModal.OnCyclePreset.Invoke(1)
            }
        }.GetNewClosure())

        $this.SavePresetButton = [UIButton]::new('Save', [ATCoordinates]::new($ControlRow, ($LeftCol + 37)), {
            Param(
                [Context]$ActionContext
            )

            $SelfModal.EnterNamingMode('', $ActionContext)
        }.GetNewClosure())

        $this.DeletePresetButton = [UIButton]::new('Del', [ATCoordinates]::new($ControlRow, ($LeftCol + 46)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnDeletePreset) {
                $SelfModal.OnDeletePreset.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.FlatButton = [UIButton]::new('Flat', [ATCoordinates]::new($ControlRow, ($LeftCol + 54)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnResetFlat) {
                $SelfModal.OnResetFlat.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.CloseButton = [UIButton]::new('Close', [ATCoordinates]::new($ControlRow, ($LeftCol + 63)), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfModal.OnCloseRequested) {
                $SelfModal.OnCloseRequested.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.StatusLineLabel = [UILabel]::new(
            'Preset: Flat (Built-in)',
            [ATCoordinates]::new($StatusRow, ($LeftCol + 2)),
            [ColorLibrary]::BoomboxFooterStatus,
            $InnerWidth
        )

        [String]$RuleText     = ([String][Char]0x2500) * ($this.Width - 1)
        $this.DividerRuleLabel = [UILabel]::new(
            $RuleText,
            [ATCoordinates]::new($DividerRow, ($LeftCol + 1)),
            [ColorLibrary]::BoomboxEqSliderTrack,
            ($this.Width - 1)
        )

        # INLINE CUSTOM PRESET NAME INPUT CONTROLS
        $this.SavePromptLabel = [UILabel]::new(
            'Save preset:',
            [ATCoordinates]::new($StatusRow, ($LeftCol + 2)),
            [ColorLibrary]::BoomboxModalBorder,
            12
        )

        $this.PresetNameInput = [UITextInput]::new(
            'Enter custom preset name...',
            [ATCoordinates]::new($StatusRow, ($LeftCol + 15)),
            32,
            '',
            28
        )
        $this.PresetNameInput.OnSubmit = {
            Param(
                [Context]$SubmitContext
            )

            $SelfModal.SubmitNamingPreset($SubmitContext)
        }.GetNewClosure()

        $this.ConfirmSaveButton = [UIButton]::new('OK', [ATCoordinates]::new($StatusRow, ($LeftCol + 48)), {
            Param(
                [Context]$ActionContext
            )

            $SelfModal.SubmitNamingPreset($ActionContext)
        }.GetNewClosure())

        $this.CancelSaveButton = [UIButton]::new('Cancel', [ATCoordinates]::new($StatusRow, ($LeftCol + 55)), {
            Param(
                [Context]$ActionContext
            )

            $SelfModal.ExitNamingMode($ActionContext, 'Cancelled preset save.')
        }.GetNewClosure())

        # LEFT DB SCALE AND VERTICAL DIVIDER COLUMN
        $this.UiElementListing[30] = [UILabel]::new('+12', [ATCoordinates]::new(($SliderTopRow + 1), ($LeftCol + 2)), [ColorLibrary]::BoomboxFooterHint, 3)
        $this.UiElementListing[31] = [UILabel]::new(' +6', [ATCoordinates]::new(($SliderTopRow + 3), ($LeftCol + 2)), [ColorLibrary]::BoomboxFooterHint, 3)
        $this.UiElementListing[32] = [UILabel]::new('  0', [ATCoordinates]::new(($SliderTopRow + 5), ($LeftCol + 2)), [ColorLibrary]::BoomboxEqSliderZero, 3)
        $this.UiElementListing[33] = [UILabel]::new(' -6', [ATCoordinates]::new(($SliderTopRow + 7), ($LeftCol + 2)), [ColorLibrary]::BoomboxFooterHint, 3)
        $this.UiElementListing[34] = [UILabel]::new('-12', [ATCoordinates]::new(($SliderTopRow + 9), ($LeftCol + 2)), [ColorLibrary]::BoomboxFooterHint, 3)

        For([Int]$DivIdx = 0; $DivIdx -LT 11; $DivIdx++) {
            $this.UiElementListing[(35 + $DivIdx)] = [UILabel]::new(
                "`u{2502}",
                [ATCoordinates]::new(($SliderTopRow + $DivIdx), ($LeftCol + 12)),
                [ColorLibrary]::BoomboxEqSliderTrack,
                1
            )
        }

        # PREAMP SLIDER (KEY 10) AND 10 ISO FREQUENCY BAND SLIDERS (KEYS 11..20)
        $this.PreampSlider = [UIVerticalSlider]::new('Pre', [ATCoordinates]::new($SliderTopRow, ($LeftCol + 6)), 0, -12, 12, 1)
        $this.PreampSlider.OnValueChanged = {
            Param(
                [UIVerticalSlider]$Slider
            )

            If($null -NE $SelfModal.OnPreampChanged) {
                $SelfModal.OnPreampChanged.Invoke($Slider.CurrentValue)
            }
        }.GetNewClosure()

        $this.BandSliders = [UIVerticalSlider[]]::new([MMEqualizerService]::BandCount)

        For([Int]$BIdx = 0; $BIdx -LT [MMEqualizerService]::BandCount; $BIdx++) {
            [Int]$CaptureIdx    = $BIdx
            [String]$BandLabel  = [MMEqualizerService]::BandLabels[$BIdx]
            [Int]$BandCol       = $LeftCol + 14 + ($BIdx * 6)
            [UIVerticalSlider]$Slider = [UIVerticalSlider]::new($BandLabel, [ATCoordinates]::new($SliderTopRow, $BandCol), 0, -12, 12, 1)

            $Slider.OnValueChanged = {
                Param(
                    [UIVerticalSlider]$ChangedSlider
                )

                If($null -NE $SelfModal.OnBandChanged) {
                    $SelfModal.OnBandChanged.Invoke($CaptureIdx, $ChangedSlider.CurrentValue)
                }
            }.GetNewClosure()

            $this.BandSliders[$BIdx]          = $Slider
            $this.UiElementListing[(11 + $BIdx)] = $Slider
        }

        $this.HintLabel = [UILabel]::new(
            '[</>] Band [^/v] +/-1dB [0] Zero [T] EQ [P] Preset [S] Save [X] Del [Esc]',
            [ATCoordinates]::new($HintRow, ($LeftCol + 2)),
            [ColorLibrary]::BoomboxFooterHint,
            $InnerWidth
        )

        $this.UiElementListing[1]  = $this.ToggleEqButton
        $this.UiElementListing[2]  = $this.PresetButton
        $this.UiElementListing[3]  = $this.SavePresetButton
        $this.UiElementListing[4]  = $this.DeletePresetButton
        $this.UiElementListing[5]  = $this.FlatButton
        $this.UiElementListing[6]  = $this.CloseButton
        $this.UiElementListing[7]  = $this.StatusLineLabel
        $this.UiElementListing[8]  = $this.DividerRuleLabel
        $this.UiElementListing[10] = $this.PreampSlider
        $this.UiElementListing[50] = $this.HintLabel
    }

    [String]FormatPresetButtonLabel(
        [String]$PresetName
    ) {
        [String]$SafeName = ($null -EQ $PresetName) ? 'Flat' : $PresetName
        [String]$Clipped  = Format-TruncatedText $SafeName 14

        Return "< $($Clipped.PadRight(14, ' ')) >"
    }

    [Void]SetInlineStatus(
        [String]$Message,
        [Boolean]$IsError
    ) {
        $this.InlineStatusOverride = ($null -EQ $Message) ? '' : $Message

        $this.StatusLineLabel.SetActiveColor(($IsError -EQ $true) ? [ColorLibrary]::BoomboxFooterError : [ColorLibrary]::BoomboxFooterStatus)
        $this.StatusLineLabel.SetText($this.InlineStatusOverride)
    }

    [Void]SyncFromService(
        [MMEqualizerService]$EqService
    ) {
        If($null -EQ $EqService) {
            Return
        }

        $this.ToggleEqButton.SetLabel(($EqService.Enabled -EQ $true) ? 'EQ: On ' : 'EQ: Off')
        $this.PresetButton.SetLabel($this.FormatPresetButtonLabel($EqService.ActivePresetName))

        $this.PreampSlider.SetValueSilent($EqService.PreampDb)
        $this.PreampSlider.SetEqEnabled($EqService.Enabled)

        For([Int]$Idx = 0; $Idx -LT [MMEqualizerService]::BandCount; $Idx++) {
            $this.BandSliders[$Idx].SetValueSilent($EqService.BandGainsDb[$Idx])
            $this.BandSliders[$Idx].SetEqEnabled($EqService.Enabled)
        }

        If(($this.IsNamingPreset -EQ $false) -AND ($this.InlineStatusOverride.Length -EQ 0)) {
            [String]$StateToken = ($EqService.Enabled -EQ $true) ? 'ON' : 'OFF'
            [String]$KindToken  = 'Custom (unsaved)'

            If($EqService.IsActivePresetDeletable() -EQ $true) {
                $KindToken = 'User Preset'
            } Elseif($EqService.IsBuiltInPresetName($EqService.ActivePresetName) -EQ $true -AND ($EqService.ActivePresetName -NE [MMEqualizerService]::CustomPresetName)) {
                $KindToken = 'Built-in Preset'
            }

            $this.StatusLineLabel.SetActiveColor([ColorLibrary]::BoomboxFooterStatus)
            $this.StatusLineLabel.SetText("EQ: $($StateToken)  |  Preset: $($EqService.ActivePresetName) ($($KindToken))")
        }
    }

    [Void]EnterNamingMode(
        [String]$InitialName,
        [Context]$Context
    ) {
        $this.IsNamingPreset       = $true
        $this.NamingRowClearDirty  = $true
        $this.NamingFocusSlot      = 0
        $this.InlineStatusOverride = ''

        $this.UnfocusAllElements($Context)

        $this.SavePromptLabel.Activate($Context)
        $this.PresetNameInput.Activate($Context)
        $this.ConfirmSaveButton.Activate($Context)
        $this.CancelSaveButton.Activate($Context)

        $this.PresetNameInput.SetTextAndMoveEnd($InitialName)
        $this.PresetNameInput.Focus($Context)

        $this.SavePromptLabel.Dirty   = $true
        $this.PresetNameInput.Dirty   = $true
        $this.ConfirmSaveButton.Dirty = $true
        $this.CancelSaveButton.Dirty  = $true

        $this.HintLabel.SetActiveColor([ColorLibrary]::BoomboxFooterHint)
        $this.HintLabel.SetText('[Enter] Save Preset  [Tab] Next Control  [Esc] Cancel')
    }

    [Void]ExitNamingMode(
        [Context]$Context,
        [String]$StatusMsg
    ) {
        $this.IsNamingPreset      = $false
        $this.NamingRowClearDirty = $true

        If($this.PresetNameInput.IsFocused() -EQ $true) {
            $this.PresetNameInput.Unfocus($Context)
        }

        If($this.ConfirmSaveButton.IsFocused() -EQ $true) {
            $this.ConfirmSaveButton.Unfocus($Context)
        }

        If($this.CancelSaveButton.IsFocused() -EQ $true) {
            $this.CancelSaveButton.Unfocus($Context)
        }

        $this.SavePromptLabel.Deactivate($Context)
        $this.PresetNameInput.Deactivate($Context)
        $this.ConfirmSaveButton.Deactivate($Context)
        $this.CancelSaveButton.Deactivate($Context)

        $this.HintLabel.SetActiveColor([ColorLibrary]::BoomboxFooterHint)
        $this.HintLabel.SetText('[</>] Band [^/v] +/-1dB [0] Zero [T] EQ [P] Preset [S] Save [X] Del [Esc]')
        $this.StatusLineLabel.Dirty = $true

        If(($null -NE $StatusMsg) -AND ($StatusMsg.Length -GT 0)) {
            $this.SetInlineStatus($StatusMsg, $false)
        }

        [Int]$TargetFocus = (($this.LastFocusedSliderKey -GE 10) -AND ($this.LastFocusedSliderKey -LE 20)) ? $this.LastFocusedSliderKey : 11
        $this.FocusElementByKey($TargetFocus, $Context)
    }

    [Void]SubmitNamingPreset(
        [Context]$Context
    ) {
        [String]$EnteredName = $this.PresetNameInput.Text.Trim()

        If($null -NE $this.OnSavePreset) {
            [Object[]]$ResultArr = $this.OnSavePreset.Invoke($EnteredName)
            [Object]$RawFirst    = (($null -NE $ResultArr) -AND ($ResultArr.Count -GT 0)) ? $ResultArr[0] : $null
            [Hashtable]$Result   = ($null -NE $RawFirst) ? ($RawFirst -AS [Hashtable]) : @{ Success = $false; Message = 'Save failed.' }

            If(($null -NE $Result) -AND ($Result.Success -EQ $true)) {
                $this.ExitNamingMode($Context, $Result.Message)
            } Else {
                [String]$ErrText = (($null -NE $Result) -AND ($Result.ContainsKey('Message') -EQ $true)) ? [String]$Result.Message : 'Save failed.'

                $this.HintLabel.SetActiveColor([ColorLibrary]::BoomboxFooterError)
                $this.HintLabel.SetText($ErrText)
                $this.PresetNameInput.SetTextAndMoveEnd($EnteredName)
            }
        }
    }

    [Void]UpdateNamingFocus(
        [Int]$Direction,
        [Context]$Context
    ) {
        [Int]$NextSlot = ($this.NamingFocusSlot + $Direction + 3) % 3

        If($this.PresetNameInput.IsFocused() -EQ $true) {
            $this.PresetNameInput.Unfocus($Context)
        }

        If($this.ConfirmSaveButton.IsFocused() -EQ $true) {
            $this.ConfirmSaveButton.Unfocus($Context)
        }

        If($this.CancelSaveButton.IsFocused() -EQ $true) {
            $this.CancelSaveButton.Unfocus($Context)
        }

        $this.NamingFocusSlot = $NextSlot

        Switch($NextSlot) {
            0 {
                $this.PresetNameInput.Focus($Context)
                Break
            }

            1 {
                $this.ConfirmSaveButton.Focus($Context)
                Break
            }

            2 {
                $this.CancelSaveButton.Focus($Context)
                Break
            }
        }
    }

    [Boolean]HandleModalKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context,
        [MMEqualizerService]$EqService
    ) {
        If($this.IsNamingPreset -EQ $true) {
            If($KeyInfo.Key -EQ [ConsoleKey]::Escape) {
                $this.ExitNamingMode($Context, 'Preset save cancelled.')
                $this.SyncFromService($EqService)

                Return $true
            }

            If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
                [Int]$Dir = (($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift) ? -1 : 1
                $this.UpdateNamingFocus($Dir, $Context)

                Return $true
            }

            Switch($this.NamingFocusSlot) {
                0 {
                    $this.PresetNameInput.HandleKey($KeyInfo, $Context)
                    Break
                }

                1 {
                    $this.ConfirmSaveButton.HandleKey($KeyInfo, $Context)
                    Break
                }

                2 {
                    $this.CancelSaveButton.HandleKey($KeyInfo, $Context)
                    Break
                }
            }

            Return $true
        }

        If(($KeyInfo.Key -EQ [ConsoleKey]::E) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Escape)) {
            If($null -NE $this.OnCloseRequested) {
                $this.OnCloseRequested.Invoke($Context)
            }

            Return $false
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::T) {
            $this.InlineStatusOverride = ''

            If($null -NE $this.OnToggleEq) {
                $this.OnToggleEq.Invoke($Context)
            }

            Return $true
        }

        If(($KeyInfo.Key -EQ [ConsoleKey]::P) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Oem4) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Oem6)) {
            $this.InlineStatusOverride = ''
            [Int]$Dir = (($KeyInfo.Key -EQ [ConsoleKey]::Oem4) -OR (($KeyInfo.Key -EQ [ConsoleKey]::P) -AND (($KeyInfo.Modifiers -BAND [ConsoleModifiers]::Shift) -EQ [ConsoleModifiers]::Shift))) ? -1 : 1

            If($null -NE $this.OnCyclePreset) {
                $this.OnCyclePreset.Invoke($Dir)
            }

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::S) {
            [String]$Prefill = (($null -NE $EqService) -AND ($EqService.IsActivePresetDeletable() -EQ $true)) ? $EqService.ActivePresetName : ''
            $this.EnterNamingMode($Prefill, $Context)

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::X) {
            If($null -NE $this.OnDeletePreset) {
                $this.OnDeletePreset.Invoke($Context)
            }

            Return $true
        }

        If($KeyInfo.Key -EQ [ConsoleKey]::F) {
            $this.InlineStatusOverride = ''

            If($null -NE $this.OnResetFlat) {
                $this.OnResetFlat.Invoke($Context)
            }

            Return $true
        }

        [Int]$CurKey = $this.ActiveIndex

        If($KeyInfo.Key -EQ [ConsoleKey]::Tab) {
            If(($CurKey -GE 10) -AND ($CurKey -LE 20)) {
                $this.LastFocusedSliderKey = $CurKey
                $this.FocusElementByKey(1, $Context)
            } Else {
                [Int]$RestoreSlider = (($this.LastFocusedSliderKey -GE 10) -AND ($this.LastFocusedSliderKey -LE 20)) ? $this.LastFocusedSliderKey : 11
                $this.FocusElementByKey($RestoreSlider, $Context)
            }

            Return $true
        }

        If(($CurKey -GE 10) -AND ($CurKey -LE 20)) {
            If($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) {
                [Int]$PrevSlider           = ($CurKey -EQ 10) ? 20 : ($CurKey - 1)
                $this.LastFocusedSliderKey = $PrevSlider
                $this.FocusElementByKey($PrevSlider, $Context)

                Return $true
            }

            If($KeyInfo.Key -EQ [ConsoleKey]::RightArrow) {
                [Int]$NextSlider           = ($CurKey -EQ 20) ? 10 : ($CurKey + 1)
                $this.LastFocusedSliderKey = $NextSlider
                $this.FocusElementByKey($NextSlider, $Context)

                Return $true
            }

            $this.InlineStatusOverride = ''
            [UIVerticalSlider]$Slider  = $this.UiElementListing[$CurKey] -AS [UIVerticalSlider]

            If($null -NE $Slider) {
                $Slider.HandleKey($KeyInfo)
            }

            Return $true
        }

        If(($CurKey -GE 1) -AND ($CurKey -LE 6)) {
            If($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) {
                [Int]$PrevBtn = ($CurKey -EQ 1) ? 6 : ($CurKey - 1)
                $this.FocusElementByKey($PrevBtn, $Context)

                Return $true
            }

            If($KeyInfo.Key -EQ [ConsoleKey]::RightArrow) {
                [Int]$NextBtn = ($CurKey -EQ 6) ? 1 : ($CurKey + 1)
                $this.FocusElementByKey($NextBtn, $Context)

                Return $true
            }

            If($KeyInfo.Key -EQ [ConsoleKey]::DownArrow) {
                [Int]$RestoreSlider = (($this.LastFocusedSliderKey -GE 10) -AND ($this.LastFocusedSliderKey -LE 20)) ? $this.LastFocusedSliderKey : 11
                $this.FocusElementByKey($RestoreSlider, $Context)

                Return $true
            }

            [UIButton]$Btn = $this.UiElementListing[$CurKey] -AS [UIButton]

            If($null -NE $Btn) {
                $Btn.HandleKey($KeyInfo, $Context)
            }

            Return $true
        }

        Return $true
    }

    [Void]SetAllElementsDirty() {
        ([UIPanel]$this).SetAllElementsDirty()

        $this.SavePromptLabel.Dirty   = $true
        $this.PresetNameInput.Dirty   = $true
        $this.ConfirmSaveButton.Dirty = $true
        $this.CancelSaveButton.Dirty  = $true
    }

    [Void]Draw() {
        If($this.Width -GE 1) {
            ([UIContainer]$this).Draw()
        }

        If($this.NamingRowClearDirty -EQ $true) {
            [Int]$StatusRow   = $this.LeftTop.Row.Value + 2
            [Int]$StartCol    = $this.LeftTop.Column.Value + 1
            [String]$ClearTxt = ' ' * [Math]::Max(1, ($this.Width - 1))
            [ATString]$ClrRow = [ATString]@{
                Prefix = [ATStringPrefix]@{
                    Coordinates = [ATCoordinates]::new($StatusRow, $StartCol)
                }
                UserData   = $ClearTxt
                UseATReset = $true
            }

            Write-Host "$($ClrRow.ToAnsiControlSequenceString())" -NoNewline

            $this.NamingRowClearDirty = $false
        }

        Foreach($Key in $this.GetSortedElementKeys()) {
            If(($Key -EQ 7) -AND ($this.IsNamingPreset -EQ $true)) {
                Continue
            }

            [UIBase]$UiElement = $this.UiElementListing[$Key] -AS [UIBase]

            If($null -NE $UiElement) {
                $UiElement.Draw()
            }
        }

        If($this.IsNamingPreset -EQ $true) {
            $this.SavePromptLabel.Draw()
            $this.PresetNameInput.Draw()
            $this.ConfirmSaveButton.Draw()
            $this.CancelSaveButton.Draw()
        }

        $this.Dirty = $false
    }
}
