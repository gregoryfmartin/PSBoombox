using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER RADIAL PULSE
#
# ASPECT-CORRECTED EXPANDING CONCENTRIC RINGS AND ANGULAR STARBURST DRIVEN BY
# LIVE BASS, MID, AND TREBLE ENERGIES.
#
###############################################################################

Class UIVisualizerRadialPulse : UIVisualizerBase {
    [Object]$NativeRenderer
    [Int[]]$PackedPalette

    UIVisualizerRadialPulse() : base('Radial Pulse') {
        $this.NativeRenderer = [MMEqualizerEngineNative]::CreateVisualizerRenderer()
        $this.PackedPalette  = [UIVisualizerCanvas]::PackPalette([ColorLibrary]::BoomboxVizRadialGradient)
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
        If($null -EQ $Canvas) {
            Return
        }

        $this.NativeRenderer.RenderRadialPulse(
            $Canvas.NativeCanvas,
            $Spectrum,
            $Metrics,
            $DeltaTime,
            $this.PackedPalette
        )
    }
}
