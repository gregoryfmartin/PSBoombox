using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI STATUS FOOTER PANEL
#
# BORDERLESS TWO-LINE FOOTER DISPLAYING STATUS/ERROR MESSAGES AND KEYBINDING
# HINTS AT THE BOTTOM OF THE TERMINAL.
#
###############################################################################

Class UIStatusFooterPanel : UIPanel {
    [UILabel]$StatusLabel
    [UILabel]$HintLabel
    [Int]$MaxTextWidth

    UIStatusFooterPanel(
        [Int]$StartRow,
        [Int]$LayoutWidth
    ) : base() {
        $this.Width        = 0
        $this.Height       = 0
        $this.MaxTextWidth = [Math]::Max(20, ($LayoutWidth - 2))

        $this.StatusLabel = [UILabel]::new(
            'Status: Ready',
            [ATCoordinates]::new($StartRow, 2),
            [ColorLibrary]::BoomboxFooterStatus,
            $this.MaxTextWidth
        )

        [String]$HintText = '[Tab] [Spc] Play [A] Add [G] Dir [W] Save [E] EQ [V] Viz [T] Theme [Q] Quit'
        $this.HintLabel   = [UILabel]::new(
            $HintText,
            [ATCoordinates]::new(($StartRow + 1), 2),
            [ColorLibrary]::BoomboxFooterHint,
            $this.MaxTextWidth
        )

        $this.UiElementListing[0] = $this.StatusLabel
        $this.UiElementListing[1] = $this.HintLabel
    }

    [Void]Resize(
        [Int]$StartRow,
        [Int]$LayoutWidth
    ) {
        $this.MaxTextWidth = [Math]::Max(20, ($LayoutWidth - 2))

        $this.StatusLabel.SetLayout([ATCoordinates]::new($StartRow, 2), $this.MaxTextWidth)
        $this.HintLabel.SetLayout([ATCoordinates]::new(($StartRow + 1), 2), $this.MaxTextWidth)
        $this.SetAllElementsDirty()
    }

    [Void]SetStatus(
        [String]$Message
    ) {
        $this.StatusLabel.SetActiveColor([ColorLibrary]::BoomboxFooterStatus)
        $this.StatusLabel.SetText("Status: $($Message)")
    }

    [Void]SetError(
        [String]$Message
    ) {
        $this.StatusLabel.SetActiveColor([ColorLibrary]::BoomboxFooterError)
        $this.StatusLabel.SetText("Error : $($Message)")
    }

    [Void]SetHint(
        [String]$HintText
    ) {
        $this.HintLabel.SetText($HintText)
    }
}
