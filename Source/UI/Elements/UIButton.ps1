using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI BUTTON
#
# A FOCUSABLE ACTION BUTTON ELEMENT RENDERED AS BRACKETED TEXT.
#
###############################################################################

Class UIButton : UIBase {
    Static [String]$LeftBracket  = '['
    Static [String]$RightBracket = ']'

    [String]$LabelText
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$Action
    [Int]$MaxRenderedLength

    UIButton() : base() {
        $this.Initialize(
            '',
            [ATCoordinates]::new(1, 1),
            $null
        )
    }

    UIButton(
        [String]$LabelText
    ) : base() {
        $this.Initialize(
            $LabelText,
            [ATCoordinates]::new(1, 1),
            $null
        )
    }

    UIButton(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $null
        )
    }

    UIButton(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [ScriptBlock]$Action
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $Action
        )
    }

    [Void]Initialize(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [ScriptBlock]$Action
    ) {
        $this.DrawCoordinates        = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.Action                 = $Action
        $this.MaxRenderedLength      = 0
        $this.UseATReset             = $true
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIButtonInactive)
        $this.Prefix.Decorations     = [ATDecorationNone]::new()

        $this.SetLabel($LabelText)
        $this.SetupStates()
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIButtonInactive)
                $SelfElement.Prefix.Decorations     = [ATDecorationNone]::new()
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIButtonActive)
                $SelfElement.Prefix.Decorations     = [ATDecorationNone]::new()
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIButtonHasFocus)
                $SelfElement.Prefix.Decorations     = [ATDecoration]@{
                    Italic = $true
                }
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UIButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.Decorations = [ATDecorationNone]::new()
                $SelfElement.Dirty              = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UIButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMState]::ContextKeysPressed) -EQ $true)) {
                    [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                    If($null -NE $KeysPressed) {
                        Foreach($KeyInfo in $KeysPressed) {
                            $SelfElement.HandleKey($KeyInfo, $Context)
                        }
                    }
                }
            }
        })
    }

    [Void]SetLabel(
        [String]$LabelText
    ) {
        [String]$ResolvedLabel = ($null -EQ $LabelText) ? '' : $LabelText
        [Int]$RenderedLength   = "$([UIButton]::LeftBracket) $($ResolvedLabel) $([UIButton]::RightBracket)".Length

        If($this.LabelText -EQ $ResolvedLabel) {
            Return
        }

        $this.LabelText = $ResolvedLabel

        If($RenderedLength -GT $this.MaxRenderedLength) {
            $this.MaxRenderedLength = $RenderedLength

            $this.SetBlankSize($this.MaxRenderedLength)
        }

        If($this.LabelText.Length -EQ 0) {
            $this.UserData = ''
        } Else {
            $this.SetUserData($this.LabelText)
        }

        $this.Dirty = $true
    }

    [Void]Invoke(
        [Context]$Context
    ) {
        If($null -NE $this.Action) {
            $this.Action.Invoke($Context)
        }
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        If(($KeyInfo.Key -EQ [ConsoleKey]::Enter) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Spacebar)) {
            $this.Invoke($Context)
        }
    }

    [String]ToAnsiControlSequenceString() {
        [ATStringComposite]$Composite = [ATStringComposite]::new()
        [String]$LeftText             = "$([UIButton]::LeftBracket) "
        [String]$RightText            = " $([UIButton]::RightBracket)"
        [Int]$RenderedLength          = $LeftText.Length + $this.LabelText.Length + $RightText.Length
        [TrueColor]$BracketColor      = [ColorLibrary]::UIButtonInactive

        If($this.IsFocused() -EQ $true) {
            $BracketColor = [ColorLibrary]::UIButtonBracketHasFocus
        } Elseif($this.IsActive() -EQ $true) {
            $BracketColor = [ColorLibrary]::UIButtonBracketActive
        }

        If($this.MaxRenderedLength -GT $RenderedLength) {
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
                    ForegroundColor = [ATForegroundColor24]::new($BracketColor)
                    Coordinates     = $this.DrawCoordinates
                }
                UserData   = "$($LeftText)"
                UseATReset = $true
            }
        )

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = $this.Prefix.ForegroundColor
                    Decorations     = $this.Prefix.Decorations
                }
                UserData   = "$($this.LabelText)"
                UseATReset = $true
            }
        )

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new($BracketColor)
                }
                UserData   = "$($RightText)"
                UseATReset = $true
            }
        )

        Return "$($Composite.ToAnsiControlSequenceString())"
    }
}
