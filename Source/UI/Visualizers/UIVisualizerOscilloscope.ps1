using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER OSCILLOSCOPE
#
# HIGH-RESOLUTION 2X4 UNICODE BRAILLE TIME-DOMAIN OSCILLOSCOPE WITH SMOOTH
# VERTICAL LINE INTERPOLATION AND BASS-REACTIVE COLORING.
#
###############################################################################

Class UIVisualizerOscilloscope : UIVisualizerBase {
    [Object]$NativeRenderer
    [Int[]]$PackedPalette
    [Int]$PackedAxisColor

    UIVisualizerOscilloscope() : base('Braille Oscilloscope') {
        $this.NativeRenderer = [MMEqualizerEngineNative]::CreateVisualizerRenderer()

        $this.RefreshPalette()
    }

    [Void]RefreshPalette() {
        $this.PackedPalette   = [UIVisualizerCanvas]::PackPalette([ColorLibrary]::BoomboxVizScopeGradient)
        $this.PackedAxisColor = [UIVisualizerCanvas]::PackColor([ColorLibrary]::BoomboxVizAxis)
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
        If(($null -EQ $Canvas) -OR ($null -EQ $Waveform) -OR ($Waveform.Length -EQ 0)) {
            Return
        }

        $this.NativeRenderer.RenderOscilloscope(
            $Canvas.NativeCanvas,
            $Waveform,
            $Metrics,
            $this.PackedPalette,
            $this.PackedAxisColor
        )
    }
}
