using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UIBASE
#
# THE BASE COMPONENT FOR ALL USER INTERFACE OBJECTS.
#
###############################################################################

Class UIBase : ATString {
    [String]$Blank
    [Boolean]$Dirty
    [UIElementBehavior]$Behavior
    [SMUiElementStateMachine]$BaseStateMachine
    [Dictionary[String, List[ScriptBlock]]]$StateEvents

    UIBase() : base() {
        $this.Dirty            = $false
        $this.Blank            = ' '
        $this.Prefix           = [ATStringPrefix]::new()
        $this.Behavior         = [UIElementBehavior]::new()
        $this.StateEvents      = [Dictionary[String, List[ScriptBlock]]]::new()
        $this.BaseStateMachine = [SMUiElementStateMachine]::new()

        $this.Subscribe(@{
            'SMUiElementInit_OnUpdate' = {
                Param(
                    [Context]$Context
                )

                [UIBase]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]

                $SelfElement.BaseStateMachine.Trigger([SMUiElementStateMachine]::TransitionReady, $Context)
            }
            'SMUiElementInactive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIBase]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty   = $true
            }
            'SMUiElementActive_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIBase]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty   = $true
            }
            'SMUiElementFocused_OnEnter' = {
                Param(
                    [Context]$Context
                )

                [UIBase]$SelfElement = $Context.References[[SMUiElementStateMachine]::ContextSelfElement]
                $SelfElement.Dirty   = $true
            }
        })
    }

    [Context]PrepareContext(
        [Context]$Context
    ) {
        If($null -EQ $Context) {
            $Context = [Context]::new()
        }

        $Context.References[[SMUiElementStateMachine]::ContextSelfElement] = $this

        Return $Context
    }

    [Boolean]IsActive() {
        Return (
            ($this.BaseStateMachine.CurrentState -EQ [SMUiElementStateMachine]::StateActive) -OR
            ($this.BaseStateMachine.CurrentState -EQ [SMUiElementStateMachine]::StateFocused)
        )
    }

    [Boolean]IsFocused() {
        Return ($this.BaseStateMachine.CurrentState -EQ [SMUiElementStateMachine]::StateFocused)
    }

    [Void]Activate(
        [Context]$Context
    ) {
        $this.BaseStateMachine.Trigger([SMUiElementStateMachine]::TransitionActivate, $this.PrepareContext($Context))
    }

    [Void]Deactivate(
        [Context]$Context
    ) {
        $this.BaseStateMachine.Trigger([SMUiElementStateMachine]::TransitionDeactivate, $this.PrepareContext($Context))
    }

    [Void]Focus(
        [Context]$Context
    ) {
        If($this.Behavior.CanHaveFocus -EQ $true) {
            $this.BaseStateMachine.Trigger([SMUiElementStateMachine]::TransitionFocus, $this.PrepareContext($Context))
        }
    }

    [Void]Unfocus(
        [Context]$Context
    ) {
        $this.BaseStateMachine.Trigger([SMUiElementStateMachine]::TransitionUnfocus, $this.PrepareContext($Context))
    }

    [Void]Deinit(
        [Context]$Context
    ) {
        $this.BaseStateMachine.Trigger([SMUiElementStateMachine]::TransitionDeinit, $this.PrepareContext($Context))
    }

    [Void]ToggleFocus(
        [Context]$Context
    ) {
        If($this.IsFocused() -EQ $true) {
            $this.Unfocus($Context)
        } Elseif($this.IsActive() -EQ $true) {
            $this.Focus($Context)
        }
    }

    [Void]ToggleActive(
        [Context]$Context
    ) {
        If($this.IsActive() -EQ $true) {
            $this.Deactivate($Context)
        } Else {
            $this.Activate($Context)
        }
    }

    [Void]Subscribe(
        [String]$EventName,
        [ScriptBlock]$Action
    ) {
        If($this.StateEvents.ContainsKey($EventName) -EQ $false) {
            $this.StateEvents[$EventName] = [List[ScriptBlock]]::new()
        }

        $this.StateEvents[$EventName].Add($Action)
    }

    [Void]Subscribe(
        [Hashtable]$SubListing
    ) {
        Foreach($Sub in $SubListing.GetEnumerator()) {
            If($this.StateEvents.ContainsKey($Sub.Key) -EQ $false) {
                $this.StateEvents[$Sub.Key] = [List[ScriptBlock]]::new()
            }

            $this.StateEvents[$Sub.Key].Add($Sub.Value)
        }
    }

    [Void]Publish(
        [String]$EventName,
        [Context]$Context
    ) {
        If($this.StateEvents.ContainsKey($EventName) -EQ $true) {
            Foreach($Action in $this.StateEvents[$EventName]) {
                $Action.Invoke($Context)
            }
        }
    }

    [Void]Update(
        [Context]$Context
    ) {
        $this.BaseStateMachine.Update($this.PrepareContext($Context))
    }

    [Void]SetUserData(
        [String]$UserData
    ) {
        If(($null -NE $UserData) -AND ($UserData.Length -GT 0)) {
            If($this.Blank.Length -LT $UserData.Length) {
                $this.SetBlankSize($UserData.Length)
            }

            $this.UserData = $UserData
        }
    }

    [Void]SetBlankSize(
        [Int]$Size
    ) {
        If($Size -LE 0) {
            $this.Blank = ' '
        } Else {
            $this.Blank = ' ' * $Size
        }
    }

    [String]ToAnsiControlSequenceString() {
        Return "$($this.Prefix.Coordinates.ToAnsiControlSequenceString())$([ATControlSequences]::GenerateThemeBgString())$($this.Blank)$(([ATString]$this).ToAnsiControlSequenceString())"
    }

    [Void]Draw() {
        If($this.Dirty -EQ $true) {
            Write-Host "$($this.ToAnsiControlSequenceString())" -NoNewline

            $this.Dirty = $false
        }
    }
}
