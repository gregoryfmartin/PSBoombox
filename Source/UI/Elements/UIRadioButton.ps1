using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI RADIO BUTTON
#
# A FOCUSABLE RADIO BUTTON ELEMENT WITH MUTUALLY EXCLUSIVE GROUP SELECTION.
#
###############################################################################

Class UIRadioButton : UIBase {
    Static [String]$UnicodeRadioUnselected                  = "`u{25CB}"
    Static [String]$UnicodeRadioSelected                    = "`u{25C9}"
    Static [Dictionary[String, List[UIRadioButton]]]$Groups = [Dictionary[String, List[UIRadioButton]]]::new()

    [UIRadioButtonState]$State
    [ATCoordinates]$DrawCoordinates
    [ScriptBlock]$OnSelect

    UIRadioButton() : base() {
        $this.Initialize(
            '',
            [ATCoordinates]::new(1, 1),
            '',
            $false
        )
    }

    UIRadioButton(
        [String]$LabelText
    ) : base() {
        $this.Initialize(
            $LabelText,
            [ATCoordinates]::new(1, 1),
            '',
            $false
        )
    }

    UIRadioButton(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            '',
            $false
        )
    }

    UIRadioButton(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [String]$GroupIdentifier
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $GroupIdentifier,
            $false
        )
    }

    UIRadioButton(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [String]$GroupIdentifier,
        [Boolean]$IsSelected
    ) : base() {
        $this.Initialize(
            $LabelText,
            $DrawCoordinates,
            $GroupIdentifier,
            $IsSelected
        )
    }

    [Void]Initialize(
        [String]$LabelText,
        [ATCoordinates]$DrawCoordinates,
        [String]$GroupIdentifier,
        [Boolean]$IsSelected
    ) {
        If($null -EQ $LabelText) {
            $LabelText = ''
        }

        $this.State                  = [UIRadioButtonState]::Unselected
        $this.DrawCoordinates        = ($null -EQ $DrawCoordinates) ? [ATCoordinates]::new(1, 1) : $DrawCoordinates
        $this.OnSelect               = $null
        $this.Dirty                  = $true
        $this.UseATReset             = $true
        $this.Behavior.CanHaveFocus  = $true
        $this.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIRadioButtonInactive)
        $this.Prefix.Decorations     = [ATDecorationNone]::new()

        If($LabelText.Length -EQ 0) {
            $this.UserData = ''
        } Else {
            $this.SetUserData($LabelText)
        }

        $this.SetupStates()
        $this.SetGroup($GroupIdentifier)

        If($IsSelected -EQ $true) {
            $this.Select()
        }
    }

    [Void]SetupStates() {
        $this.Subscribe(@{
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIRadioButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIRadioButtonInactive)
                $SelfElement.Prefix.Decorations     = [ATDecorationNone]::new()
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIRadioButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIRadioButtonActive)
                $SelfElement.Prefix.Decorations     = [ATDecorationNone]::new()
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIRadioButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.ForegroundColor = [ATForegroundColor24]::new([ColorLibrary]::UIRadioButtonHasFocus)
                $SelfElement.Prefix.Decorations     = [ATDecoration]@{
                    Italic = $true
                }
                $SelfElement.Dirty                  = $true
            }
            'SMUiElementFocused_OnExit' = {
                Param(
                    [Context]$Context
                )

                [UIRadioButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.Prefix.Decorations = [ATDecorationNone]::new()
                $SelfElement.Dirty              = $true
            }
            'SMUiElementFocused_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UIRadioButton]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMState]::ContextKeysPressed) -EQ $true)) {
                    [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

                    If($null -NE $KeysPressed) {
                        Foreach($KeyInfo in $KeysPressed) {
                            $SelfElement.HandleKey($KeyInfo)
                        }
                    }
                }
            }
        })
    }

    [Void]SetGroup(
        [String]$GroupIdentifier
    ) {
        If($null -EQ $GroupIdentifier) {
            $GroupIdentifier = ''
        }

        [String]$PreviousGroup = $this.Behavior.GroupIdentifier

        If(($null -NE $PreviousGroup) -AND ($PreviousGroup.Length -GT 0) -AND ([UIRadioButton]::Groups.ContainsKey($PreviousGroup) -EQ $true)) {
            [List[UIRadioButton]]$OldMembers = [UIRadioButton]::Groups[$PreviousGroup]

            For([Int]$Idx = ($OldMembers.Count - 1); $Idx -GE 0; $Idx--) {
                If([Object]::ReferenceEquals($OldMembers[$Idx], $this) -EQ $true) {
                    $OldMembers.RemoveAt($Idx)
                }
            }

            If($OldMembers.Count -EQ 0) {
                [UIRadioButton]::Groups.Remove($PreviousGroup) | Out-Null
            }
        }

        $this.Behavior.GroupIdentifier = $GroupIdentifier

        If($GroupIdentifier.Length -GT 0) {
            If([UIRadioButton]::Groups.ContainsKey($GroupIdentifier) -EQ $false) {
                [UIRadioButton]::Groups[$GroupIdentifier] = [List[UIRadioButton]]::new()
            }

            [List[UIRadioButton]]$TargetMembers = [UIRadioButton]::Groups[$GroupIdentifier]
            [Boolean]$AlreadyPresent            = $false

            Foreach($Member in $TargetMembers) {
                If([Object]::ReferenceEquals($Member, $this) -EQ $true) {
                    $AlreadyPresent = $true

                    Break
                }
            }

            If($AlreadyPresent -EQ $false) {
                $TargetMembers.Add($this)
            }
        }
    }

    Static [Void]ClearGroups() {
        [UIRadioButton]::Groups.Clear()
    }

    [Void]Select() {
        $this.State      = [UIRadioButtonState]::Selected
        $this.Dirty      = $true
        [String]$GroupId = $this.Behavior.GroupIdentifier

        If(($null -NE $GroupId) -AND ($GroupId.Length -GT 0) -AND ([UIRadioButton]::Groups.ContainsKey($GroupId) -EQ $true)) {
            [List[UIRadioButton]]$Members = [UIRadioButton]::Groups[$GroupId]

            Foreach($Peer in $Members) {
                If([Object]::ReferenceEquals($Peer, $this) -EQ $false) {
                    $Peer.Deselect()
                }
            }
        }

        If($null -NE $this.OnSelect) {
            $this.OnSelect.Invoke($this)
        }
    }

    [Void]Deselect() {
        $this.State = [UIRadioButtonState]::Unselected
        $this.Dirty = $true
    }

    [Void]ToggleRadioButton() {
        $this.Select()
    }

    [Void]HandleKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        If(($KeyInfo.Key -EQ [ConsoleKey]::Spacebar) -OR ($KeyInfo.Key -EQ [ConsoleKey]::Enter)) {
            $this.Select()
        }
    }

    [String]ToAnsiControlSequenceString() {
        [ATStringComposite]$Composite = [ATStringComposite]::new()
        [String]$GlyphText            = "$([UIRadioButton]::UnicodeRadioUnselected) "
        [TrueColor]$GlyphColor        = [ColorLibrary]::UIRadioButtonInactive

        Switch($this.State) {
            ([UIRadioButtonState]::Selected) {
                $GlyphText = "$([UIRadioButton]::UnicodeRadioSelected) "

                If($this.IsActive() -EQ $true) {
                    $GlyphColor = [ColorLibrary]::UIRadioButtonSelected
                }

                Break
            }

            Default {
                $GlyphText = "$([UIRadioButton]::UnicodeRadioUnselected) "

                If($this.IsActive() -EQ $true) {
                    $GlyphColor = [ColorLibrary]::UIRadioButtonActive
                }

                Break
            }
        }

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix     = [ATStringPrefix]@{
                    ForegroundColor = [ATForegroundColor24]::new($GlyphColor)
                    Coordinates     = $this.DrawCoordinates
                }
                UserData   = "$($GlyphText)"
                UseATReset = $true
            }
        )

        $Composite.CompositeActual.Add(
            [ATString]@{
                Prefix     = [ATStringPrefix]@{
                    ForegroundColor = $this.Prefix.ForegroundColor
                    Decorations     = $this.Prefix.Decorations
                }
                UserData   = "$($this.UserData)"
                UseATReset = $true
            }
        )

        Return "$($Composite.ToAnsiControlSequenceString())"
    }
}
