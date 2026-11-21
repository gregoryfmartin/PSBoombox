using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI PATH INPUT MODAL
#
# REUSABLE CENTERED MODAL OVERLAY FOR DIRECTORY NAVIGATION AND PLAYLIST SAVE
# PROMPTS.
#
###############################################################################

Class UIPathInputModal : UIPanel {
    [UILabel]$PromptLabel
    [UITextInput]$PathInput
    [UILabel]$ErrorLabel
    [UIButton]$ConfirmButton
    [UIButton]$CancelButton
    [ScriptBlock]$OnConfirm
    [ScriptBlock]$OnCancel

    UIPathInputModal(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) : base() {
        [Int]$ModalWidth  = [Math]::Clamp(($LayoutWidth - 10), 56, 78)
        [Int]$ModalHeight = 8
        [Int]$TopRow      = [Math]::Max(3, [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2))
        [Int]$LeftCol     = [Math]::Max(3, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))

        $this.LeftTop     = [ATCoordinates]::new($TopRow, $LeftCol)
        $this.RightBottom = [ATCoordinates]::new(($TopRow + $ModalHeight), ($LeftCol + $ModalWidth))

        $this.UpdateDimensions()
        $this.SetupTitle('Path Input', [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)

        [UIPathInputModal]$SelfModal = $this
        [Int]$InnerWidth             = [Math]::Max(20, ($this.Width - 4))
        [Int]$InputVisibleWidth      = [Math]::Max(16, ($this.Width - 8))

        $this.PromptLabel = [UILabel]::new(
            'Enter path:',
            [ATCoordinates]::new(($TopRow + 2), ($LeftCol + 2)),
            [ColorLibrary]::TextActiveColor,
            $InnerWidth
        )

        $this.PathInput = [UITextInput]::new(
            'Enter full or relative path...',
            [ATCoordinates]::new(($TopRow + 3), ($LeftCol + 2)),
            260,
            '',
            $InputVisibleWidth
        )
        $this.PathInput.OnSubmit = {
            Param(
                [Context]$SubmitContext
            )

            If($null -NE $SelfModal.OnConfirm) {
                $SelfModal.OnConfirm.Invoke($SelfModal.PathInput.Text, $SubmitContext)
            }
        }.GetNewClosure()

        $this.ErrorLabel = [UILabel]::new(
            '',
            [ATCoordinates]::new(($TopRow + 5), ($LeftCol + 2)),
            [ColorLibrary]::BoomboxFooterError,
            $InnerWidth
        )

        $this.ConfirmButton = [UIButton]::new(
            'OK',
            [ATCoordinates]::new(($TopRow + 6), ($LeftCol + 2)),
            {
                Param(
                    [Context]$ActionContext
                )

                If($null -NE $SelfModal.OnConfirm) {
                    $SelfModal.OnConfirm.Invoke($SelfModal.PathInput.Text, $ActionContext)
                }
            }.GetNewClosure()
        )

        $this.CancelButton = [UIButton]::new(
            'Cancel',
            [ATCoordinates]::new(($TopRow + 6), ($LeftCol + 12)),
            {
                Param(
                    [Context]$ActionContext
                )

                If($null -NE $SelfModal.OnCancel) {
                    $SelfModal.OnCancel.Invoke($ActionContext)
                }
            }.GetNewClosure()
        )

        $this.UiElementListing[0] = $this.PromptLabel
        $this.UiElementListing[1] = $this.PathInput
        $this.UiElementListing[2] = $this.ErrorLabel
        $this.UiElementListing[3] = $this.ConfirmButton
        $this.UiElementListing[4] = $this.CancelButton
    }

    [Void]Resize(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) {
        [Int]$ModalWidth  = [Math]::Clamp(($LayoutWidth - 10), 56, 78)
        [Int]$ModalHeight = 8
        [Int]$TopRow      = [Math]::Max(3, [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2))
        [Int]$LeftCol     = [Math]::Max(3, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))

        $this.SetBounds([ATCoordinates]::new($TopRow, $LeftCol), [ATCoordinates]::new(($TopRow + $ModalHeight), ($LeftCol + $ModalWidth)))

        [Int]$InnerWidth        = [Math]::Max(20, ($this.Width - 4))
        [Int]$InputVisibleWidth = [Math]::Max(16, ($this.Width - 8))

        $this.PromptLabel.SetLayout([ATCoordinates]::new(($TopRow + 2), ($LeftCol + 2)), $InnerWidth)
        $this.PathInput.SetLayout([ATCoordinates]::new(($TopRow + 3), ($LeftCol + 2)), $InputVisibleWidth)
        $this.ErrorLabel.SetLayout([ATCoordinates]::new(($TopRow + 5), ($LeftCol + 2)), $InnerWidth)
        $this.ConfirmButton.SetCoordinates([ATCoordinates]::new(($TopRow + 6), ($LeftCol + 2)))
        $this.CancelButton.SetCoordinates([ATCoordinates]::new(($TopRow + 6), ($LeftCol + 12)))

        $this.InteriorClearDirty = $true

        $this.SetAllElementsDirty()
    }

    [Void]Configure(
        [String]$Title,
        [String]$PromptText,
        [String]$InitialValue,
        [String]$ConfirmLabel
    ) {
        $this.SetupTitle($Title, [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)
        $this.PromptLabel.SetText($PromptText)
        $this.PathInput.SetTextAndMoveEnd($InitialValue)
        $this.ErrorLabel.SetText('')
        $this.ConfirmButton.SetLabel($ConfirmLabel)
        $this.SetAllElementsDirty()
    }

    [Void]SetError(
        [String]$ErrorText
    ) {
        $this.ErrorLabel.SetText($ErrorText)

        $this.ErrorLabel.Dirty = $true
    }
}
