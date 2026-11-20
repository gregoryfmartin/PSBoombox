using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# UI TAB
#
# A FOCUSABLE TAB HEADER ELEMENT RENDERED WITH BOX-DRAWING SIDE BORDERS AND
# ASSOCIATED WITH A BORDERLESS UIPANEL CONTENT PAGE.
#
###############################################################################

Class UITab : UIBase {
    Static [String]$UnselectedLeftBorder  = "`u{2524}"
    Static [String]$UnselectedRightBorder = "`u{251C}"
    Static [String]$SelectedLeftBorder    = "`u{2561}"
    Static [String]$SelectedRightBorder   = "`u{255E}"

    [String]$LabelText
    [Boolean]$IsSelected
    [ATCoordinates]$DrawCoordinates
    [UIPanel]$ContentPanel
    [ScriptBlock]$OnSelect

    UITab() : base() {
        $this.Initialize(
            '',
            [ATCoordinates]::new(1, 1),
            $null
        )
    }

    UITab(
        [String]$LabelText
    ) : base() {
        $this.Initialize(
            $LabelText,
            [ATCoordinates]::new(1, 1),
            $null
        )
    }

    UITab(
        [String]$LabelText,
        [UIPanel]$ContentPanel
    ) : base() {
        $this.Initialize(
            $LabelText,
            [ATCoordinates]::new(1, 1),
            $ContentPanel
        )
    }

    UITab(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [UIPanel]$ContentPanel
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $ContentPanel
        )
    }

    [Void]Initialize(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [UIPanel]$ContentPanel
    ) {
        $this.LabelText             = ($null -EQ $LabelText) ? '' : $LabelText
        $this.IsSelected            = $false
        $this.DrawCoordinates       = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.ContentPanel          = ($null -EQ $ContentPanel) ? [UIPanel]::new() : $ContentPanel
        $this.OnSelect              = $null
        $this.UseATReset            = $true
        $this.Dirty                 = $true
        $this.Behavior.CanHaveFocus = $true

        $this.SetBlankSize($this.GetRenderedWidth())
        $this.SetupStates()
        $this.ApplyVisuals()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITab]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITab]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITab]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UITab]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.ApplyVisuals()
            }
        })
    }

    [Void]SetLabel(
        [String]$LabelText
    ) {
        $this.LabelText = ($null -EQ $LabelText) ? '' : $LabelText

        If($this.Blank.Length -LT $this.GetRenderedWidth()) {
            $this.SetBlankSize($this.GetRenderedWidth())
        }

        $this.ApplyVisuals()
    }

    [Void]SetSelected(
        [Boolean]$Selected
    ) {
        $this.IsSelected = $Selected

        $this.ApplyVisuals()

        If(($Selected -EQ $true) -AND ($null -NE $this.OnSelect)) {
            $this.OnSelect.Invoke($this)
        }
    }

    [Int]GetRenderedWidth() {
        Return ($this.LabelText.Length + 4)
    }

    [TrueColor]ResolveBorderColor() {
        If($this.IsActive() -EQ $false) {
            Return [ColorLibrary]::UITabInactive
        }

        If(($this.IsFocused() -EQ $true) -AND ($this.IsSelected -EQ $true)) {
            Return [ColorLibrary]::UITabBorderHasFocus
        }

        If($this.IsSelected -EQ $true) {
            Return [ColorLibrary]::UITabBorderSelected
        }

        Return [ColorLibrary]::UITabBorderActive
    }

    [Void]ApplyVisuals() {
        [TrueColor]$LabelColor    = [ColorLibrary]::UITabInactive
        [ATDecoration]$Decoration = [ATDecorationNone]::new()

        If($this.IsActive() -EQ $true) {
            If(($this.IsFocused() -EQ $true) -AND ($this.IsSelected -EQ $true)) {
                $LabelColor = [ColorLibrary]::UITabHasFocus
                $Decoration = [ATDecoration]@{
                    Italic = $true
                }
            } Elseif($this.IsSelected -EQ $true) {
                $LabelColor = [ColorLibrary]::UITabSelected
            } Else {
                $LabelColor = [ColorLibrary]::UITabActive
            }
        }

        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new($LabelColor)
        $this.Prefix.Decorations     = $Decoration
        $this.Dirty                  = $true
    }

    [String]ToAnsiControlSequenceString() {
        [ATStringComposite]$Composite = [ATStringComposite]::new()
        [Int]$RenderedWidth           = $this.GetRenderedWidth()
        [TrueColor]$BorderColor       = $this.ResolveBorderColor()
        [String]$LeftBorder           = ($this.IsSelected -EQ $true) ? [UITab]::SelectedLeftBorder : [UITab]::UnselectedLeftBorder
        [String]$RightBorder          = ($this.IsSelected -EQ $true) ? [UITab]::SelectedRightBorder : [UITab]::UnselectedRightBorder

        If($this.Blank.Length -GT $RenderedWidth) {
            $Composite.CompositeActual.Add(
                [ATString]@{
                    Prefix = [ATStringPrefix]@{
                        Coordinates = $this.DrawCoordinates
                    }
                    UserData   = "$($this.Blank)"
                    UseATReset = $true
                }
            )
        }

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new($BorderColor)
                    Coordinates     = $this.DrawCoordinates
                }
                UserData   = "$($LeftBorder)"
                UseATReset = $true
            }
        )

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = $this.Prefix.ForegroundColor
                    Decorations     = $this.Prefix.Decorations
                }
                UserData   = " $($this.LabelText) "
                UseATReset = $true
            }
        )

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new($BorderColor)
                }
                UserData   = "$($RightBorder)"
                UseATReset = $true
            }
        )

        Return "$($Composite.ToAnsiControlSequenceString())"
    }
}
