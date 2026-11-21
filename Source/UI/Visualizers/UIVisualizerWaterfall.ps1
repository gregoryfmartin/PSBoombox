using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER WATERFALL
#
# SCROLLING SPECTROGRAM HEAT MAP USING PAIRED HALF-BLOCKS FOR 2X VERTICAL
# RESOLUTION ACROSS TIME AND FREQUENCY.
#
###############################################################################

Class UIVisualizerWaterfall : UIVisualizerBase {
    [Object]$NativeRenderer
    [Int[]]$PackedPalette

    UIVisualizerWaterfall() : base('Spectrogram Waterfall') {
        $this.NativeRenderer = [MMEqualizerEngineNative]::CreateVisualizerRenderer()

        $this.RefreshPalette()
    }

    [Void]RefreshPalette() {
        $this.PackedPalette = [UIVisualizerCanvas]::PackPalette([ColorLibrary]::BoomboxVizWaterfallGradient)
    }

    [Void]Reset() {
        $this.NativeRenderer.Reset()
    }

    [Void]RenderFrame(
        [UIVisualizerCanvas]$Canvas,
        [Single[]]$Spectrum,
        [Single[]]$Waveform,
        [Single[]]$Metrics,
        [Double]$DeltaTime
    ) {
        If(($null -EQ $Canvas) -OR ($null -EQ $Spectrum) -OR ($Spectrum.Length -EQ 0)) {
            Return
        }

        $this.NativeRenderer.RenderWaterfall(
            $Canvas.NativeCanvas,
            $Spectrum,
            $this.PackedPalette
        )
    }
}
