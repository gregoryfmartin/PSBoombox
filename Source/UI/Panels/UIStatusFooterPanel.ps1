using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI STATUS FOOTER PANEL
#
# BORDERLESS SINGLE-LINE FOOTER DISPLAYING STATUS/ERROR MESSAGES AT THE BOTTOM
# OF THE TERMINAL.
#
###############################################################################

Class UIStatusFooterPanel : UIPanel {
    [UILabel]$StatusLabel
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

        $this.UiElementListing[0] = $this.StatusLabel
    }

    [Void]Resize(
        [Int]$StartRow,
        [Int]$LayoutWidth
    ) {
        $this.MaxTextWidth = [Math]::Max(20, ($LayoutWidth - 2))

        $this.StatusLabel.SetLayout([ATCoordinates]::new($StartRow, 2), $this.MaxTextWidth)
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
}
