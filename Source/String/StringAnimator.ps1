using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# STRING ANIMATOR
#
# DRIVES FRAME-BY-FRAME STRING ANIMATIONS BASED ON ELAPSED DELTA TIME.
#
###############################################################################

Class StringAnimator {
    [String[]]$Frames
    [Double]$FrameDuration
    [Double]$Timer
    [Int]$CurrentFrameIndex

    StringAnimator() {
        $this.Frames            = @()
        $this.FrameDuration     = 0.0
        $this.Timer             = 0.0
        $this.CurrentFrameIndex = 0
    }

    StringAnimator(
        [String[]]$Frames,
        [Int]$Fps
    ) {
        $this.Frames            = $Frames
        $this.FrameDuration     = ($Fps -GT 0) ? (1.0 / $Fps) : 0.0
        $this.Timer             = 0.0
        $this.CurrentFrameIndex = 0
    }

    [Void]Update(
        [Double]$Dt
    ) {
        If(($this.FrameDuration -LE 0.0) -OR ($this.Frames.Length -EQ 0)) {
            Return
        }

        $this.Timer += $Dt

        If($this.Timer -GE $this.FrameDuration) {
            $this.Timer             = 0.0
            $this.CurrentFrameIndex = ($this.CurrentFrameIndex + 1) % $this.Frames.Length
        }
    }

    [String]GetCurrentFrame() {
        If($this.Frames.Length -EQ 0) {
            Return ''
        }

        Return "$($this.Frames[$this.CurrentFrameIndex])"
    }
}
