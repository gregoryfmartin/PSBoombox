using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI LABEL
#
# A TEXT LABEL UI ELEMENT WITH ACTIVE/INACTIVE COLORS AND OPTIONAL MAX WIDTH.
#
###############################################################################

Class UILabel : UIBase {
    [ATCoordinates]$DrawCoordinates
    [TrueColor]$ActiveColor
    [TrueColor]$InactiveColor
    [Int]$MaxWidth

    UILabel() : base() {
        $this.Initialize(
            '',
            [ATCoordinatesNone]::new(),
            [ColorLibrary]::UILabelActive,
            0
        )
    }

    UILabel(
        [String]$LabelText
    ) : base() {
        $this.Initialize(
            $LabelText,
            [ATCoordinates]::new(1, 1),
            [ColorLibrary]::UILabelActive,
            0
        )
    }

    UILabel(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            [ColorLibrary]::UILabelActive,
            0
        )
    }

    UILabel(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [TrueColor]$ActiveColor
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $ActiveColor,
            0
        )
    }

    UILabel(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [TrueColor]$ActiveColor,
        [Int]$MaxWidth
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $ActiveColor,
            $MaxWidth
        )
    }

    [Void]Initialize(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [TrueColor]$ActiveColor,
        [Int]$MaxWidth
    ) {
        $this.DrawCoordinates        = ($null -EQ $DrawCoordinates) ? [ATCoordinatesNone]::new() : $DrawCoordinates
        $this.ActiveColor            = ($null -EQ $ActiveColor) ? [ColorLibrary]::UILabelActive : $ActiveColor
        $this.InactiveColor          = [ColorLibrary]::UILabelInactive
        $this.MaxWidth               = [Math]::Max(0, $MaxWidth)
        $this.UseATReset             = $true
        $this.Dirty                  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new($this.ActiveColor)

        If($this.MaxWidth -GT 0) {
            $this.SetBlankSize($this.MaxWidth)
        }

        $this.SetText($LabelText)
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UILabel]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new($SelfElement.InactiveColor)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UILabel]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new($SelfElement.ActiveColor)
                $SelfElement.Dirty                  = $true
            }
        })
    }

    [Void]SetText(
        [String]$Text
    ) {
        [String]$SafeText = ($null -EQ $Text) ? '' : $Text

        If($this.MaxWidth -GT 0) {
            [String]$Clipped = Format-TruncatedText $SafeText $this.MaxWidth
            $this.UserData   = $Clipped.PadRight($this.MaxWidth, ' ')
            $this.SetBlankSize($this.MaxWidth)
        } Elseif($SafeText.Length -EQ 0) {
            $this.UserData = ''
        } Else {
            $this.SetUserData($SafeText)
        }

        $this.Dirty = $true
    }

    [Void]SetActiveColor(
        [TrueColor]$Color
    ) {
        If($null -EQ $Color) {
            Return
        }

        $this.ActiveColor = $Color

        If(($this.IsActive() -EQ $true) -OR ($this.BaseStateMachine.CurrentState -EQ [SMUiElementStateMachine]::StateInit)) {
            $this.Prefix.ForegroundColor = [ATForegroundColor24]::new($this.ActiveColor)
            $this.Dirty                  = $true
        }
    }

    [String]ToAnsiControlSequenceString() {
        If(($this.DrawCoordinates -IS [ATCoordinatesNone]) -EQ $false) {
            $this.Prefix.Coordinates = [ATCoordinates]::new($this.DrawCoordinates)
        }

        Return "$(([UIBase]$this).ToAnsiControlSequenceString())"
    }
}
