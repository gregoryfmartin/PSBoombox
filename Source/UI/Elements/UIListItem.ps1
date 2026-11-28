using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI LIST ITEM
#
# REPRESENTS A SINGLE SELECTABLE ROW WITHIN A UILIST OR UIMENU, WITH OPTIONAL
# PLAYING INDICATOR, CUSTOM ACTIVE COLOR, AND DISPLAY WIDTH TRUNCATION.
#
###############################################################################

Class UIListItem : UIBase {
    Static [String]$PlayingIndicator = "`u{25B6}"

    [String]$LabelText
    [Object]$Tag
    [Boolean]$IsSelected
    [Boolean]$IsPlaying
    [Int]$MaxDisplayWidth
    [TrueColor]$CustomActiveColor
    [ATCoordinates]$DrawCoordinates

    UIListItem() : base() {
        $this.Initialize(
            '',
            [ATCoordinates]::new(1, 1),
            $null
        )
    }

    UIListItem(
        [String]$LabelText
    ) : base() {
        $this.Initialize(
            $LabelText,
            [ATCoordinates]::new(1, 1),
            $null
        )
    }

    UIListItem(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $null
        )
    }

    UIListItem(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [Object]$Tag
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $Tag
        )
    }

    [Void]Initialize(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [Object]$Tag
    ) {
        $this.LabelText             = ($null -EQ $LabelText) ? '' : $LabelText
        $this.Tag                   = $Tag
        $this.IsSelected            = $false
        $this.IsPlaying             = $false
        $this.MaxDisplayWidth       = 0
        $this.CustomActiveColor     = $null
        $this.DrawCoordinates       = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.UseATReset            = $true
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true

        $this.SetupStates()
        $this.ApplyVisuals()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIListItem]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIListItem]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIListItem]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
        })
    }

    [Void]SetSelected(
        [Boolean]$Selected
    ) {
        $this.IsSelected = $Selected

        $this.ApplyVisuals()
    }

    [Void]SetPlaying(
        [Boolean]$Playing
    ) {
        If($this.IsPlaying -NE $Playing) {
            $this.IsPlaying = $Playing

            $this.ApplyVisuals()
        }
    }

    [Void]SetCustomActiveColor(
        [TrueColor]$Color
    ) {
        $this.CustomActiveColor = $Color

        $this.ApplyVisuals()
    }

    [Void]SetLabel(
        [String]$LabelText
    ) {
        $this.LabelText = ($null -EQ $LabelText) ? '' : $LabelText

        $this.ApplyVisuals()
    }

    [TrueColor]ResolveForegroundColor() {
        If($this.IsActive() -EQ $false) {
            Return [ColorLibrary]::UIListItemInactive
        }

        [TrueColor]$BaseFg = [ColorLibrary]::UIListItemActive

        If($this.IsPlaying -EQ $true) {
            $BaseFg = [ColorLibrary]::BoomboxNowPlayingEntry
        } Elseif($null -NE $this.CustomActiveColor) {
            $BaseFg = $this.CustomActiveColor
        } Elseif(($this.IsSelected -EQ $true) -AND ($this.IsFocused() -EQ $true)) {
            $BaseFg = [ColorLibrary]::UIListItemSelected
        }

        If($this.IsSelected -EQ $true) {
            [TrueColor]$HighlightBg = ($this.IsFocused() -EQ $true) ? [ColorLibrary]::UIListItemSelectedBg : [ColorLibrary]::UIListItemSelectedUnfocusedBg

            Return [TrueColor]::EnsureContrast($BaseFg, $HighlightBg, [ColorLibrary]::TextActiveColor, 4.5)
        }

        Return $BaseFg
    }

    [ATBackgroundColor24]ResolveBackgroundColor() {
        If(($this.IsActive() -EQ $true) -AND ($this.IsSelected -EQ $true)) {
            If($this.IsFocused() -EQ $true) {
                Return [ATBackgroundColor24]::new([ColorLibrary]::UIListItemSelectedBg)
            }

            Return [ATBackgroundColor24]::new([ColorLibrary]::UIListItemSelectedUnfocusedBg)
        }

        Return [ATBackgroundColor24None]::new()
    }

    [String]BuildPrefixGlyph() {
        If($this.IsPlaying -EQ $true) {
            Return "$([UIListItem]::PlayingIndicator) "
        }

        Return ''
    }

    [Void]RefreshColors() {
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new($this.ResolveForegroundColor())
        $this.Prefix.BackgroundColor = $this.ResolveBackgroundColor()
    }

    [Void]ApplyVisuals() {
        $this.RefreshColors()

        [String]$PrefixGlyph = $this.BuildPrefixGlyph()
        [String]$DisplayText = "$($PrefixGlyph)$($this.LabelText)"

        If($this.MaxDisplayWidth -GT 0) {
            [String]$Clipped = Format-TruncatedText $DisplayText $this.MaxDisplayWidth
            $this.UserData   = $Clipped.PadRight($this.MaxDisplayWidth, ' ')
            $this.SetBlankSize($this.MaxDisplayWidth)
        } Else {
            $this.SetUserData($DisplayText)
        }

        $this.Dirty = $true
    }

    [String]ToAnsiControlSequenceString() {
        $this.RefreshColors()
        $this.Prefix.Coordinates = [ATCoordinates]::new($this.DrawCoordinates)

        Return "$(([UIBase]$this).ToAnsiControlSequenceString())"
    }
}
