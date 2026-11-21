using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI NOTICE MODAL
#
# CENTERED MODAL DIALOG FOR INFORMATIONAL ALERTS SUCH AS MIDI VISUALIZER
# NOTICE, DISMISSIBLE VIA ENTER, SPACE, OR ESCAPE.
#
###############################################################################

Class UINoticeModal : UIPanel {
    [UILabel[]]$MessageLabels
    [UIButton]$OkButton
    [ScriptBlock]$OnDismiss

    UINoticeModal(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) : base() {
        [Int]$ModalWidth  = [Math]::Clamp(($LayoutWidth - 10), 56, 72)
        [Int]$ModalHeight = 7
        [Int]$TopRow      = [Math]::Max(3, [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2))
        [Int]$LeftCol     = [Math]::Max(3, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))

        $this.LeftTop     = [ATCoordinates]::new($TopRow, $LeftCol)
        $this.RightBottom = [ATCoordinates]::new(($TopRow + $ModalHeight), ($LeftCol + $ModalWidth))
        $this.OnDismiss   = $null

        $this.UpdateDimensions()
        $this.SetupTitle('Notice', [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)

        [UINoticeModal]$SelfModal = $this
        [Int]$InnerWidth          = [Math]::Max(20, ($this.Width - 4))
        $this.MessageLabels       = [UILabel[]]::new(3)

        For([Int]$Idx = 0; $Idx -LT 3; $Idx++) {
            [TrueColor]$LineColor   = ($Idx -EQ 0) ? [ColorLibrary]::TextActiveColor : [ColorLibrary]::BoomboxFooterHint
            [UILabel]$LineLabel     = [UILabel]::new(
                '',
                [ATCoordinates]::new(($TopRow + 2 + $Idx), ($LeftCol + 2)),
                $LineColor,
                $InnerWidth
            )
            $this.MessageLabels[$Idx] = $LineLabel
            $this.UiElementListing[$Idx] = $LineLabel
        }

        $this.OkButton = [UIButton]::new(
            'OK',
            [ATCoordinates]::new(($TopRow + 5), ($LeftCol + 2)),
            {
                Param(
                    [Context]$ActionContext
                )

                If($null -NE $SelfModal.OnDismiss) {
                    $SelfModal.OnDismiss.Invoke($ActionContext)
                }
            }.GetNewClosure()
        )

        $this.UiElementListing[3] = $this.OkButton
    }

    [Void]Resize(
        [Int]$LayoutWidth,
        [Int]$LayoutHeight
    ) {
        [Int]$ModalWidth  = [Math]::Clamp(($LayoutWidth - 10), 56, 72)
        [Int]$ModalHeight = 7
        [Int]$TopRow      = [Math]::Max(3, [Int][Math]::Floor(($LayoutHeight - $ModalHeight) / 2))
        [Int]$LeftCol     = [Math]::Max(3, [Int][Math]::Floor(($LayoutWidth - $ModalWidth) / 2))

        $this.SetBounds([ATCoordinates]::new($TopRow, $LeftCol), [ATCoordinates]::new(($TopRow + $ModalHeight), ($LeftCol + $ModalWidth)))

        [Int]$InnerWidth = [Math]::Max(20, ($this.Width - 4))

        For([Int]$Idx = 0; $Idx -LT 3; $Idx++) {
            $this.MessageLabels[$Idx].SetLayout([ATCoordinates]::new(($TopRow + 2 + $Idx), ($LeftCol + 2)), $InnerWidth)
        }

        $this.OkButton.SetCoordinates([ATCoordinates]::new(($TopRow + 5), ($LeftCol + 2)))

        $this.InteriorClearDirty = $true

        $this.SetAllElementsDirty()
    }

    [Void]Configure(
        [String]$Title,
        [String[]]$Lines,
        [String]$ButtonLabel
    ) {
        $this.SetupTitle($Title, [ColorLibrary]::BoomboxModalBorder)
        $this.SetBorderColor([ColorLibrary]::BoomboxModalBorder)

        For([Int]$Idx = 0; $Idx -LT 3; $Idx++) {
            [String]$Text = (($null -NE $Lines) -AND ($Idx -LT $Lines.Length)) ? $Lines[$Idx] : ''
            $this.MessageLabels[$Idx].SetText($Text)
        }

        [String]$ResolvedLabel = (($null -NE $ButtonLabel) -AND ($ButtonLabel.Length -GT 0)) ? $ButtonLabel : 'OK'
        $this.OkButton.SetLabel($ResolvedLabel)
        $this.SetAllElementsDirty()
    }
}
