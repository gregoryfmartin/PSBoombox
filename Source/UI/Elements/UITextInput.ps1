using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI TEXT INPUT
#
# A SINGLE-LINE TEXT INPUT FIELD WITH CURSOR MOVEMENT, HORIZONTAL VIEWPORT
# SCROLLING, PLACEHOLDER DISPLAY, AND SUBMIT/CHANGE CALLBACKS.
#
###############################################################################

Class UITextInput : UIBase {
    Static [Int]$DefaultMaxLength = 16
    Static [String]$CursorGlyph   = '_'
    Static [String]$LeftBracket   = '['
    Static [String]$RightBracket  = ']'

    [Int]$MaxLength
    [Int]$VisibleWidth
    [Int]$ScrollOffset
    [Int]$CursorIndex
    [String]$Text
    [String]$Placeholder
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnSubmit
    [ScriptBlock]$OnChange

    UITextInput() : base() {
        $this.Initialize(
            '',
            [ATCoordinates]::new(1, 1),
            [UITextInput]::DefaultMaxLength,
            '',
            0
        )
    }

    UITextInput(
        [String]$Placeholder
    ) : base() {
        $this.Initialize(
            $Placeholder,
            [ATCoordinates]::new(1, 1),
            [UITextInput]::DefaultMaxLength,
            '',
            0
        )
    }

    UITextInput(
        [String]$Placeholder,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $Placeholder,
            $DrawCoordinates,
            [UITextInput]::DefaultMaxLength,
            '',
            0
        )
    }

    UITextInput(
        [String]$Placeholder,
        [ATCoordinates]$DrawCoordinates,
        [Int]$MaxLength
    ) : base() {
        $this.Initialize(
            $Placeholder,
            $DrawCoordinates,
            $MaxLength,
            '',
            0
        )
    }

    UITextInput(
        [String]$Placeholder,
        [ATCoordinates]$DrawCoordinates,
        [Int]$MaxLength,
        [String]$InitialText
    ) : base() {
        $this.Initialize(
            $Placeholder,
            $DrawCoordinates,
            $MaxLength,
            $InitialText,
            0
        )
    }

    UITextInput(
        [String]$Placeholder,
        [ATCoordinates]$DrawCoordinates,
        [Int]$MaxLength,
        [String]$InitialText,
        [Int]$VisibleWidth
    ) : base() {
        $this.Initialize(
            $Placeholder,
            $DrawCoordinates,
            $MaxLength,
            $InitialText,
            $VisibleWidth
        )
    }

    [Void]Initialize(
        [String]$Placeholder,
        [ATCoordinates]$DrawCoordinates,
        [Int]$MaxLength,
        [String]$InitialText,
        [Int]$VisibleWidth
    ) {
        [String]$SafePlaceholder = ($null -EQ $Placeholder) ? '' : $Placeholder
        [String]$SafeInitialText = ($null -EQ $InitialText) ? '' : $InitialText
        [Int]$SafeMaxLength      = [Math]::Max(1, $MaxLength)
        [Int]$SafeVisibleWidth   = ($VisibleWidth -GT 0) ? [Math]::Clamp($VisibleWidth, 4, $SafeMaxLength) : $SafeMaxLength

        If($SafeInitialText.Length -GT $SafeMaxLength) {
            $SafeInitialText = $SafeInitialText.Substring(0, $SafeMaxLength)
        }

        $this.Placeholder            = $SafePlaceholder
        $this.DrawCoordinates        = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.MaxLength              = $SafeMaxLength
        $this.VisibleWidth           = $SafeVisibleWidth
        $this.ScrollOffset           = 0
        $this.Text                   = $SafeInitialText
        $this.CursorIndex            = $SafeInitialText.Length
        $this.OnSubmit               = $null
        $this.OnChange               = $null
        $this.UseATReset             = $true
        $this.Dirty                  = $true
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UITextInputInactive)

        $this.SetBlankSize($this.GetEffectiveVisibleWidth() + 4)
        $this.SyncScrollOffset()
        $this.SetupStates()
    }

    [Int]GetEffectiveVisibleWidth() {
        If($this.VisibleWidth -GT 0) {
            Return [Math]::Clamp($this.VisibleWidth, 1, $this.MaxLength)
        }

        Return $this.MaxLength
    }

    [Void]SyncScrollOffset() {
        [Int]$EffectiveWidth = $this.GetEffectiveVisibleWidth()
        [Int]$SafeCursor     = [Math]::Clamp($this.CursorIndex, 0, $this.Text.Length)

        If($SafeCursor -LT $this.ScrollOffset) {
            $this.ScrollOffset = $SafeCursor
        } Elseif($SafeCursor -GE ($this.ScrollOffset + $EffectiveWidth)) {
            $this.ScrollOffset = $SafeCursor - $EffectiveWidth + 1
        }

        [Int]$MaxOffset    = [Math]::Max(0, ($this.Text.Length - $EffectiveWidth + 1))
        $this.ScrollOffset = [Math]::Clamp($this.ScrollOffset, 0, $MaxOffset)
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITextInput]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UITextInputInactive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITextInput]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UITextInputActive)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UITextInput]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UITextInputHasFocus)
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UITextInput]$SelfElement          = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                If($null -NE $KeysPressed) {
                    Foreach($KeyInfo in $KeysPressed) {
                        $SelfElement.HandleKey($KeyInfo, $Context)
                    }
                }
            }
        })
    }

    [Void]SetVisibleWidth(
        [Int]$Width
    ) {
        $this.VisibleWidth = ($Width -GT 0) ? [Math]::Clamp($Width, 4, $this.MaxLength) : $this.MaxLength

        $this.SetBlankSize($this.GetEffectiveVisibleWidth() + 4)
        $this.SyncScrollOffset()

        $this.Dirty = $true
    }

    [Void]SetText(
        [String]$NewText
    ) {
        [String]$Normalized = ($null -EQ $NewText) ? '' : $NewText

        If($Normalized.Length -GT $this.MaxLength) {
            $Normalized = $Normalized.Substring(0, $this.MaxLength)
        }

        $this.Text        = $Normalized
        $this.CursorIndex = [Math]::Clamp($this.CursorIndex, 0, $this.Text.Length)

        $this.SyncScrollOffset()

        $this.Dirty = $true

        If($null -NE $this.OnChange) {
            $this.OnChange.Invoke($this)
        }
    }

    [Void]SetTextAndMoveEnd(
        [String]$NewText
    ) {
        [String]$Normalized = ($null -EQ $NewText) ? '' : $NewText

        If($Normalized.Length -GT $this.MaxLength) {
            $Normalized = $Normalized.Substring(0, $this.MaxLength)
        }

        $this.Text        = $Normalized
        $this.CursorIndex = $this.Text.Length

        $this.SyncScrollOffset()

        $this.Dirty = $true
    }

    [Void]AppendChar(
        [Char]$Character
    ) {
        If($this.Text.Length -LT $this.MaxLength) {
            $this.Text = $this.Text.Insert($this.CursorIndex, "$($Character)")
            $this.CursorIndex++
            $this.SyncScrollOffset()

            $this.Dirty = $true

            If($null -NE $this.OnChange) {
                $this.OnChange.Invoke($this)
            }
        }
    }

    [Void]Backspace() {
        If(($this.CursorIndex -GT 0) -AND ($this.Text.Length -GT 0)) {
            $this.Text = $this.Text.Remove($this.CursorIndex - 1, 1)
            $this.CursorIndex--
            $this.SyncScrollOffset()

            $this.Dirty = $true

            If($null -NE $this.OnChange) {
                $this.OnChange.Invoke($this)
            }
        }
    }

    [Void]DeleteChar() {
        If($this.CursorIndex -LT $this.Text.Length) {
            $this.Text = $this.Text.Remove($this.CursorIndex, 1)
            $this.SyncScrollOffset()

            $this.Dirty = $true

            If($null -NE $this.OnChange) {
                $this.OnChange.Invoke($this)
            }
        }
    }

    [Void]MoveCursorLeft() {
        If($this.CursorIndex -GT 0) {
            $this.CursorIndex--
            $this.SyncScrollOffset()

            $this.Dirty = $true
        }
    }

    [Void]MoveCursorRight() {
        If($this.CursorIndex -LT $this.Text.Length) {
            $this.CursorIndex++
            $this.SyncScrollOffset()

            $this.Dirty = $true
        }
    }

    [Void]Clear() {
        $this.CursorIndex  = 0
        $this.ScrollOffset = 0

        $this.SetText('')
    }

    [Void]Submit(
        [Context]$Context
    ) {
        If($null -NE $this.OnSubmit) {
            $this.OnSubmit.Invoke($Context)
        }
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        Switch($KeyInfo.Key) {
            ([ConsoleKey]::Enter) {
                $this.Submit($Context)

                Break
            }

            ([ConsoleKey]::Backspace) {
                $this.Backspace()

                Break
            }

            ([ConsoleKey]::Delete) {
                $this.DeleteChar()

                Break
            }

            ([ConsoleKey]::LeftArrow) {
                $this.MoveCursorLeft()

                Break
            }

            ([ConsoleKey]::RightArrow) {
                $this.MoveCursorRight()

                Break
            }

            ([ConsoleKey]::Home) {
                If($this.CursorIndex -NE 0) {
                    $this.CursorIndex = 0
                    $this.SyncScrollOffset()

                    $this.Dirty = $true
                }

                Break
            }

            ([ConsoleKey]::End) {
                If($this.CursorIndex -NE $this.Text.Length) {
                    $this.CursorIndex = $this.Text.Length
                    $this.SyncScrollOffset()

                    $this.Dirty = $true
                }

                Break
            }

            Default {
                If([Char]::IsControl($KeyInfo.KeyChar) -EQ $false) {
                    $this.AppendChar($KeyInfo.KeyChar)
                }

                Break
            }
        }
    }

    [ATString]CreateSegment(
        [ATForegroundColor24]$Color,
        [ATDecoration]$Decorations,
        [ATCoordinates]$Coordinates,
        [String]$Content
    ) {
        Return [ATString]@{
            Prefix = [ATStringPrefix]@{
                ForegroundColor = $Color
                Decorations     = $Decorations
                Coordinates     = $Coordinates
            }
            UserData   = "$($Content)"
            UseATReset = $true
        }
    }

    [String]ToAnsiControlSequenceString() {
        [ATStringComposite]$Composite = [ATStringComposite]::new()
        [ATDecorationNone]$NoDecor    = [ATDecorationNone]::new()
        [ATCoordinatesNone]$NoCoords  = [ATCoordinatesNone]::new()
        [Int]$EffectiveWidth          = $this.GetEffectiveVisibleWidth()

        $this.SyncScrollOffset()

        $Composite.CompositeActual.Add(
            $this.CreateSegment(
                $this.Prefix.ForegroundColor,
                $NoDecor,
                [ATCoordinates]::new($this.DrawCoordinates),
                "$([UITextInput]::LeftBracket) "
            )
        )

        If(($this.Text.Length -EQ 0) -AND ($this.IsFocused() -EQ $false)) {
            [String]$DisplayPlaceholder = ($this.Placeholder.Length -GT $EffectiveWidth) ? $this.Placeholder.Substring(0, $EffectiveWidth) : $this.Placeholder
            [String]$PaddedPlaceholder  = $DisplayPlaceholder.PadRight($EffectiveWidth, ' ')

            $Composite.CompositeActual.Add(
                $this.CreateSegment(
                    [ATForegroundColor24]::new([ColorLibrary]::UITextInputPlaceholder),
                    $NoDecor,
                    $NoCoords,
                    $PaddedPlaceholder
                )
            )
        } Elseif($this.IsFocused() -EQ $false) {
            [Int]$SliceLen       = [Math]::Min($EffectiveWidth, $this.Text.Length)
            [String]$VisibleText = ($SliceLen -GT 0) ? $this.Text.Substring(0, $SliceLen) : ''
            [String]$PaddedText  = $VisibleText.PadRight($EffectiveWidth, ' ')

            $Composite.CompositeActual.Add(
                $this.CreateSegment(
                    $this.Prefix.ForegroundColor,
                    $NoDecor,
                    $NoCoords,
                    $PaddedText
                )
            )
        } Else {
            [Int]$SafeCursor                  = [Math]::Clamp($this.CursorIndex, 0, $this.Text.Length)
            [Int]$Available                   = [Math]::Max(0, ($this.Text.Length - $this.ScrollOffset))
            [Int]$SliceLen                    = [Math]::Min($EffectiveWidth, $Available)
            [String]$VisibleSlice             = ($SliceLen -GT 0) ? $this.Text.Substring($this.ScrollOffset, $SliceLen) : ''
            [Int]$CursorInView                = [Math]::Clamp(($SafeCursor - $this.ScrollOffset), 0, $EffectiveWidth)
            [ATForegroundColor24]$CursorColor = [ATForegroundColor24]::new([ColorLibrary]::UITextInputCursor)

            If($CursorInView -LT $VisibleSlice.Length) {
                If($CursorInView -GT 0) {
                    $Composite.CompositeActual.Add(
                        $this.CreateSegment(
                            $this.Prefix.ForegroundColor,
                            $NoDecor,
                            $NoCoords,
                            $VisibleSlice.Substring(0, $CursorInView)
                        )
                    )
                }

                $Composite.CompositeActual.Add(
                    $this.CreateSegment(
                        $CursorColor,
                        [ATDecoration]@{
                            Underline = $true
                        },
                        $NoCoords,
                        $VisibleSlice.Substring($CursorInView, 1)
                    )
                )

                [String]$AfterText = ($CursorInView + 1 -LT $VisibleSlice.Length) ? $VisibleSlice.Substring($CursorInView + 1) : ''
                [Int]$PadCount     = [Math]::Max(0, ($EffectiveWidth - $VisibleSlice.Length))
                [String]$Trailing  = "$($AfterText)$(' ' * $PadCount)"

                If($Trailing.Length -GT 0) {
                    $Composite.CompositeActual.Add(
                        $this.CreateSegment(
                            $this.Prefix.ForegroundColor,
                            $NoDecor,
                            $NoCoords,
                            $Trailing
                        )
                    )
                }
            } Elseif($CursorInView -LT $EffectiveWidth) {
                If($VisibleSlice.Length -GT 0) {
                    $Composite.CompositeActual.Add(
                        $this.CreateSegment(
                            $this.Prefix.ForegroundColor,
                            $NoDecor,
                            $NoCoords,
                            $VisibleSlice
                        )
                    )
                }

                $Composite.CompositeActual.Add(
                    $this.CreateSegment(
                        $CursorColor,
                        $NoDecor,
                        $NoCoords,
                        [UITextInput]::CursorGlyph
                    )
                )

                [Int]$PadCount = [Math]::Max(0, ($EffectiveWidth - $VisibleSlice.Length - 1))

                If($PadCount -GT 0) {
                    $Composite.CompositeActual.Add(
                        $this.CreateSegment(
                            $this.Prefix.ForegroundColor,
                            $NoDecor,
                            $NoCoords,
                            (' ' * $PadCount)
                        )
                    )
                }
            } Else {
                $Composite.CompositeActual.Add(
                    $this.CreateSegment(
                        $this.Prefix.ForegroundColor,
                        $NoDecor,
                        $NoCoords,
                        $VisibleSlice
                    )
                )
            }
        }

        $Composite.CompositeActual.Add(
            $this.CreateSegment(
                $this.Prefix.ForegroundColor,
                $NoDecor,
                $NoCoords,
                " $([UITextInput]::RightBracket)"
            )
        )

        Return "$($Composite.ToAnsiControlSequenceString())"
    }
}
