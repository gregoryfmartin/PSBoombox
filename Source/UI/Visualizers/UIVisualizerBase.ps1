using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER BASE
#
# ABSTRACT BASE CLASS FOR REAL-TIME AUDIO VISUALIZERS AND PALETTE MAPPING.
#
###############################################################################

Class UIVisualizerBase {
    [String]$Name

    UIVisualizerBase() {
        $this.Name = 'Visualizer'
    }

    UIVisualizerBase(
        [String]$Name
    ) {
        $this.Name = ($null -EQ $Name) ? 'Visualizer' : $Name
    }

    [Void]Reset() {}

    [Void]RefreshPalette() {}

    [Void]RenderFrame(
        [UIVisualizerCanvas]$Canvas,
        [Single[]]$Spectrum,
        [Single[]]$Waveform,
        [Single[]]$Metrics,
        [Double]$DeltaTime
    ) {}

    Static [TrueColor]PickPaletteColor(
        [TrueColor[]]$Palette,
        [Double]$NormalizedValue
    ) {
        If(($null -EQ $Palette) -OR ($Palette.Length -EQ 0)) {
            Return [ColorLibrary]::TextActiveColor
        }

        [Double]$Clamped = [Math]::Clamp($NormalizedValue, 0.0, 1.0)
        [Int]$LastIdx    = $Palette.Length - 1
        [Int]$TargetIdx  = [Int][Math]::Clamp([Math]::Round($Clamped * $LastIdx), 0, $LastIdx)

        Return $Palette[$TargetIdx]
    }
}
