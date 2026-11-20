using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI VISUALIZER CANVAS
#
# DOUBLE-BUFFERED 24-BIT TRUECOLOR TERMINAL CANVAS BACKED BY NATIVE C# CELL
# BUFFERS AND MINIMAL ANSI DIFF EMISSION FOR 60 FPS VISUALIZATION RENDERING.
#
###############################################################################

Class UIVisualizerCanvas {
    [Int]$Width
    [Int]$Height
    [Int]$TopRow
    [Int]$LeftCol
    [Int]$CellCount
    [Object]$NativeCanvas

    UIVisualizerCanvas() {
        $this.Initialize(100, 26, 1, 1)
    }

    UIVisualizerCanvas(
        [Int]$Width,
        [Int]$Height,
        [Int]$TopRow,
        [Int]$LeftCol
    ) {
        $this.Initialize($Width, $Height, $TopRow, $LeftCol)
    }

    Static [Int]PackColor(
        [TrueColor]$Color
    ) {
        If($null -EQ $Color) {
            Return -1
        }

        Return ((($Color.Red.Value -BAND 0xFF) -SHL 16) -BOR (($Color.Green.Value -BAND 0xFF) -SHL 8) -BOR ($Color.Blue.Value -BAND 0xFF))
    }

    Static [Int[]]PackPalette(
        [TrueColor[]]$Palette
    ) {
        If(($null -EQ $Palette) -OR ($Palette.Length -EQ 0)) {
            Return [Int[]]::new(0)
        }

        [Int[]]$Packed = [Int[]]::new($Palette.Length)

        For([Int]$I = 0; $I -LT $Palette.Length; $I++) {
            $Packed[$I] = [UIVisualizerCanvas]::PackColor($Palette[$I])
        }

        Return $Packed
    }

    [Void]Initialize(
        [Int]$Width,
        [Int]$Height,
        [Int]$TopRow,
        [Int]$LeftCol
    ) {
        If($null -EQ $this.NativeCanvas) {
            $this.NativeCanvas = [MMEqualizerEngineNative]::CreateVisualizerCanvas($Width, $Height, $TopRow, $LeftCol)
        } Else {
            $this.NativeCanvas.Initialize($Width, $Height, $TopRow, $LeftCol)
        }

        $this.Width     = $this.NativeCanvas.Width
        $this.Height    = $this.NativeCanvas.Height
        $this.TopRow    = $this.NativeCanvas.TopRow
        $this.LeftCol   = $this.NativeCanvas.LeftCol
        $this.CellCount = $this.NativeCanvas.CellCount
    }

    [Void]ClearFrame() {
        $this.NativeCanvas.ClearFrame()
    }

    [Void]InvalidateAll() {
        $this.NativeCanvas.InvalidateAll()
    }

    [Void]SetCell(
        [Int]$Row,
        [Int]$Col,
        [Char]$Glyph,
        [TrueColor]$Fg
    ) {
        $this.SetCell($Row, $Col, $Glyph, $Fg, $null)
    }

    [Void]SetCell(
        [Int]$Row,
        [Int]$Col,
        [Char]$Glyph,
        [TrueColor]$Fg,
        [TrueColor]$Bg
    ) {
        $this.NativeCanvas.SetCell(
            $Row,
            $Col,
            $Glyph,
            [UIVisualizerCanvas]::PackColor($Fg),
            [UIVisualizerCanvas]::PackColor($Bg)
        )
    }

    [String]BuildFrameAnsi(
        [Boolean]$WrapSync,
        [String]$TrailingAnsi
    ) {
        [String]$SafeTrailing = ($null -EQ $TrailingAnsi) ? '' : $TrailingAnsi

        Return $this.NativeCanvas.BuildDiffAnsi($WrapSync, $SafeTrailing)
    }

    [Void]DrawFrame(
        [Boolean]$WrapSync,
        [String]$TrailingAnsi
    ) {
        [String]$Payload = $this.BuildFrameAnsi($WrapSync, $TrailingAnsi)

        If($Payload.Length -GT 0) {
            If(([Console]::IsOutputRedirected -EQ $true) -OR ($this.NativeCanvas.WriteConsoleUtf16($Payload) -EQ $false)) {
                Write-Host $Payload -NoNewline
            }
        }
    }

    [Void]Draw() {
        $this.DrawFrame($false, '')
    }

    [Void]ClearScreenBuffer() {
        $this.InvalidateAll()
        $this.Draw()
    }
}
