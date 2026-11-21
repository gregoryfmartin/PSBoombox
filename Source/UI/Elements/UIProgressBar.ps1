using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI PROGRESS BAR
#
# A HORIZONTAL PROGRESS BAR ELEMENT WITH OPTIONAL BOUND CLAMPABLEINT,
# CUSTOM PREFIX/SUFFIX LABELS, AND NUMERIC READOUT.
#
###############################################################################

Class UIProgressBar : UIBase {
    Static [Int]$DefaultBarWidth = 10
    Static [String]$FilledGlyph  = "`u{2588}"
    Static [String]$EmptyGlyph   = "`u{2591}"
    Static [String]$LeftBorder   = '['
    Static [String]$RightBorder  = ']'

    [Int]$BarWidth
    [Int]$CurrentValue
    [Int]$MinValue
    [Int]$MaxValue
    [Boolean]$ShowNumericText
    [Int]$MaxRenderedLength
    [String]$CustomPrefixText
    [String]$CustomSuffixText
    [ClampableInt]$BoundValue
    [TrueColor]$FilledColor
    [TrueColor]$BorderColorOverride
    [ATCoordinates]$DrawCoordinates

    UIProgressBar() : base() {
        $this.Initialize(
            [ATCoordinates]::new(1, 1),
            0,
            0,
            100,
            [UIProgressBar]::DefaultBarWidth,
            $true,
            [ColorLibrary]::UIProgressBarFilled
        )
    }

    UIProgressBar(
        [ATCoordinates]$DrawCoordinates,
        [ClampableInt]$BoundValue
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            0,
            0,
            100,
            [UIProgressBar]::DefaultBarWidth,
            $true,
            [ColorLibrary]::UIProgressBarFilled
        )

        $this.BindValue($BoundValue)
    }

    UIProgressBar(
        [ATCoordinates]$DrawCoordinates,
        [ClampableInt]$BoundValue,
        [Int]$BarWidth
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            0,
            0,
            100,
            $BarWidth,
            $true,
            [ColorLibrary]::UIProgressBarFilled
        )

        $this.BindValue($BoundValue)
    }

    UIProgressBar(
        [ATCoordinates]$DrawCoordinates,
        [ClampableInt]$BoundValue,
        [Int]$BarWidth,
        [Boolean]$ShowNumericText
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            0,
            0,
            100,
            $BarWidth,
            $ShowNumericText,
            [ColorLibrary]::UIProgressBarFilled
        )

        $this.BindValue($BoundValue)
    }

    UIProgressBar(
        [ATCoordinates]$DrawCoordinates,
        [Int]$CurrentValue,
        [Int]$MinValue,
        [Int]$MaxValue,
        [Int]$BarWidth
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            $CurrentValue,
            $MinValue,
            $MaxValue,
            $BarWidth,
            $true,
            [ColorLibrary]::UIProgressBarFilled
        )
    }

    UIProgressBar(
        [ATCoordinates]$DrawCoordinates,
        [ClampableInt]$BoundValue,
        [Int]$BarWidth,
        [Boolean]$ShowNumericText,
        [TrueColor]$FilledColor
    ) : base() {
        $this.Initialize(
            $DrawCoordinates,
            0,
            0,
            100,
            $BarWidth,
            $ShowNumericText,
            $FilledColor
        )

        $this.BindValue($BoundValue)
    }

    [Void]Initialize(
        [ATCoordinates]$DrawCoordinates,
        [Int]$CurrentValue,
        [Int]$MinValue,
        [Int]$MaxValue,
        [Int]$BarWidth,
        [Boolean]$ShowNumericText,
        [TrueColor]$FilledColor
    ) {
        [Int]$SafeMin   = $MinValue
        [Int]$SafeMax   = ($MaxValue -LT $SafeMin) ? $SafeMin : $MaxValue
        [Int]$SafeValue = [Math]::Clamp($CurrentValue, $SafeMin, $SafeMax)

        $this.DrawCoordinates        = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.BarWidth               = [Math]::Max(1, $BarWidth)
        $this.MinValue               = $SafeMin
        $this.MaxValue               = $SafeMax
        $this.CurrentValue           = $SafeValue
        $this.ShowNumericText        = $ShowNumericText
        $this.MaxRenderedLength      = 0
        $this.CustomPrefixText       = ''
        $this.CustomSuffixText       = ''
        $this.BoundValue             = $null
        $this.FilledColor            = ($null -EQ $FilledColor) ? [ColorLibrary]::UIProgressBarFilled : $FilledColor
        $this.BorderColorOverride    = $null
        $this.UseATReset             = $true
        $this.Dirty                  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIProgressBarInactive)

        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIProgressBarInactive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIProgressBarBorder)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIProgressBar]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::BoomboxBorderFocused)
                $SelfElement.Dirty                  = $true
            }
        })
    }

    [Void]BindValue(
        [ClampableInt]$BoundValue
    ) {
        $this.BoundValue = $BoundValue

        If($null -NE $BoundValue) {
            $this.MinValue     = $BoundValue.Floor
            $this.MaxValue     = $BoundValue.Ceiling
            $this.CurrentValue = [Math]::Clamp($BoundValue.Value, $this.MinValue, $this.MaxValue)
        } Else {
            $this.MinValue     = 0
            $this.MaxValue     = 100
            $this.CurrentValue = 0
        }

        $this.Dirty = $true
    }

    [Void]SetValue(
        [Int]$NewValue
    ) {
        [Int]$Clamped = [Math]::Clamp($NewValue, $this.MinValue, $this.MaxValue)

        If(($null -NE $this.BoundValue) -AND ($this.BoundValue.Value -NE $Clamped)) {
            $this.BoundValue.SetValue($Clamped)
        }

        If($Clamped -NE $this.CurrentValue) {
            $this.CurrentValue = $Clamped
            $this.Dirty        = $true
        }
    }

    [Void]SetLayout(
        [ATCoordinates]$DrawCoordinates,
        [Int]$BarWidth
    ) {
        $this.DrawCoordinates   = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.BarWidth          = [Math]::Max(1, $BarWidth)
        $this.MaxRenderedLength = 0
        $this.Dirty             = $true
    }

    [Void]SetCustomLabels(
        [String]$PrefixText,
        [String]$SuffixText
    ) {
        [String]$SafePrefix = ($null -EQ $PrefixText) ? '' : $PrefixText
        [String]$SafeSuffix = ($null -EQ $SuffixText) ? '' : $SuffixText

        If(($this.CustomPrefixText -NE $SafePrefix) -OR ($this.CustomSuffixText -NE $SafeSuffix)) {
            $this.CustomPrefixText = $SafePrefix
            $this.CustomSuffixText = $SafeSuffix
            $this.Dirty            = $true
        }
    }

    [Double]GetRatio() {
        If($this.MaxValue -LE $this.MinValue) {
            Return 0.0
        }

        [Double]$Ratio = ([Double]($this.CurrentValue - $this.MinValue)) / ([Double]($this.MaxValue - $this.MinValue))

        Return [Math]::Clamp($Ratio, 0.0, 1.0)
    }

    [Int]GetFilledCellCount() {
        [Int]$FilledCount = [Int][Math]::Round($this.GetRatio() * $this.BarWidth)

        Return [Math]::Clamp($FilledCount, 0, $this.BarWidth)
    }

    [Void]Update(
        [Context]$Context
    ) {
        ([UIBase]$this).Update($Context)

        If($this.IsActive() -EQ $true) {
            If(($null -NE $this.BoundValue) -AND ($this.BoundValue.Value -NE $this.CurrentValue)) {
                $this.SetValue($this.BoundValue.Value)
            }
        }
    }

    [ATString]CreateSegment(
        [TrueColor]$Color,
        [ATCoordinates]$Coordinates,
        [String]$Content
    ) {
        Return [ATString]@{
            Prefix = [ATStringPrefix]@{
                ForegroundColor = [ATForegroundColor24]::new($Color)
                Coordinates     = $Coordinates
            }
            UserData   = "$($Content)"
            UseATReset = $true
        }
    }

    [String]ToAnsiControlSequenceString() {
        [Boolean]$Active        = $this.IsActive()
        [TrueColor]$BorderColor = [ColorLibrary]::UIProgressBarInactive

        If($Active -EQ $true) {
            $BorderColor = ($null -NE $this.BorderColorOverride) ? $this.BorderColorOverride : (($this.IsFocused() -EQ $true) ? [ColorLibrary]::BoomboxBorderFocused : [ColorLibrary]::UIProgressBarBorder)
        }

        [TrueColor]$FillColor  = ($Active -EQ $true) ? $this.FilledColor : [ColorLibrary]::UIProgressBarInactive
        [TrueColor]$EmptyColor = ($Active -EQ $true) ? [ColorLibrary]::UIProgressBarEmpty : [ColorLibrary]::UIProgressBarInactive
        [TrueColor]$TextColor  = ($Active -EQ $true) ? [ColorLibrary]::UIProgressBarText : [ColorLibrary]::UIProgressBarInactive
        [Int]$FilledCount      = $this.GetFilledCellCount()
        [Int]$EmptyCount       = $this.BarWidth - $FilledCount
        [String]$PrefixText    = ($null -NE $this.CustomPrefixText) ? $this.CustomPrefixText : ''
        [String]$SuffixText    = ''

        If(($null -NE $this.CustomSuffixText) -AND ($this.CustomSuffixText.Length -GT 0)) {
            $SuffixText = $this.CustomSuffixText
        } Elseif($this.ShowNumericText -EQ $true) {
            $SuffixText = " $($this.CurrentValue)/$($this.MaxValue)"
        }

        [Int]$RenderedLength = $PrefixText.Length + 2 + $this.BarWidth + $SuffixText.Length

        If($RenderedLength -GT $this.MaxRenderedLength) {
            $this.MaxRenderedLength = $RenderedLength
        }

        [Int]$PadCount             = $this.MaxRenderedLength - $RenderedLength
        [String]$TrailingPadding   = ($PadCount -GT 0) ? (' ' * $PadCount) : ''
        [ATCoordinatesNone]$NoCo   = [ATCoordinatesNone]::new()
        [ATStringComposite]$Result = [ATStringComposite]::new()

        If($PrefixText.Length -GT 0) {
            $Result.CompositeActual.Add(
                $this.CreateSegment(
                    $TextColor,
                    [ATCoordinates]::new($this.DrawCoordinates),
                    $PrefixText
                )
            )
            $Result.CompositeActual.Add(
                $this.CreateSegment(
                    $BorderColor,
                    $NoCo,
                    [UIProgressBar]::LeftBorder
                )
            )
        } Else {
            $Result.CompositeActual.Add(
                $this.CreateSegment(
                    $BorderColor,
                    [ATCoordinates]::new($this.DrawCoordinates),
                    [UIProgressBar]::LeftBorder
                )
            )
        }

        If($FilledCount -GT 0) {
            $Result.CompositeActual.Add(
                $this.CreateSegment(
                    $FillColor,
                    $NoCo,
                    ([UIProgressBar]::FilledGlyph * $FilledCount)
                )
            )
        }

        If($EmptyCount -GT 0) {
            $Result.CompositeActual.Add(
                $this.CreateSegment(
                    $EmptyColor,
                    $NoCo,
                    ([UIProgressBar]::EmptyGlyph * $EmptyCount)
                )
            )
        }

        $Result.CompositeActual.Add(
            $this.CreateSegment(
                $BorderColor,
                $NoCo,
                [UIProgressBar]::RightBorder
            )
        )

        If(($SuffixText.Length -GT 0) -OR ($TrailingPadding.Length -GT 0)) {
            $Result.CompositeActual.Add(
                $this.CreateSegment(
                    $TextColor,
                    $NoCo,
                    "$($SuffixText)$($TrailingPadding)"
                )
            )
        }

        Return "$($Result.ToAnsiControlSequenceString())"
    }
}
