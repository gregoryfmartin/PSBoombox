using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER MIRROR
#
# SYMMETRICAL MIRRORED SPECTRUM RADIATING UPWARD AND DOWNWARD FROM THE CENTER
# HORIZONTAL AXIS.
#
###############################################################################

Class UIVisualizerMirror : UIVisualizerBase {
    [Object]$NativeRenderer
    [Int[]]$PackedPalette
    [Int]$PackedAxisColor

    UIVisualizerMirror() : base('Mirrored Spectrum') {
        $this.NativeRenderer  = [MMEqualizerEngineNative]::CreateVisualizerRenderer()
        $this.PackedPalette   = [UIVisualizerCanvas]::PackPalette([ColorLibrary]::BoomboxVizMirrorGradient)
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
        If(($null -EQ $Canvas) -OR ($null -EQ $Spectrum) -OR ($Spectrum.Length -EQ 0)) {
            Return
        }

        $this.NativeRenderer.RenderMirror(
            $Canvas.NativeCanvas,
            $Spectrum,
            $this.PackedPalette,
            $this.PackedAxisColor
        )
    }
}
