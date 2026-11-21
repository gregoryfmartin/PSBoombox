using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER SPECTRUM
#
# CLASSIC LOGARITHMIC VERTICAL FFT SPECTRUM ANALYZER WITH 8-LEVEL BLOCKS,
# TRUECOLOR GRADIENT, AND GRAVITY-FALLING PEAK-HOLD CAPS.
#
###############################################################################

Class UIVisualizerSpectrum : UIVisualizerBase {
    [Object]$NativeRenderer
    [Int[]]$PackedPalette
    [Int]$PackedPeakColor

    UIVisualizerSpectrum() : base('Spectrum Analyzer') {
        $this.NativeRenderer = [MMEqualizerEngineNative]::CreateVisualizerRenderer()

        $this.RefreshPalette()
    }

    [Void]RefreshPalette() {
        $this.PackedPalette   = [UIVisualizerCanvas]::PackPalette([ColorLibrary]::BoomboxVizSpectrumGradient)
        $this.PackedPeakColor = [UIVisualizerCanvas]::PackColor([ColorLibrary]::BoomboxVizPeakCap)
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

        $this.NativeRenderer.RenderSpectrum(
            $Canvas.NativeCanvas,
            $Spectrum,
            $DeltaTime,
            $this.PackedPalette,
            $this.PackedPeakColor
        )
    }
}
