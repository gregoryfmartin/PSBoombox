using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# FINITE STATE MACHINE IMPLEMENTATION
#
# SMSTATEMACHINE
#
# THE STATE MACHINE DEFINITION.
#
###############################################################################

Class SMStateMachine {
    [String]$CurrentState
    [Dictionary[String, SMState]]$States
    [List[SMTransition]]$Transitions

    SMStateMachine(
        [String]$InitialState
    ) {
        $this.CurrentState = $InitialState
        $this.States       = [Dictionary[String, SMState]]::new()
        $this.Transitions  = [List[SMTransition]]::new()
    }

    [Void]AddState(
        [SMState]$State
    ) {
        $this.States[$State.Name] = $State
    }

    [Void]AddStates(
        [SMState[]]$States
    ) {
        Foreach($State in $States) {
            $this.States[$State.Name] = $State
        }
    }

    [Void]AddTransition(
        [SMTransition]$Transition
    ) {
        $this.Transitions.Add($Transition)
    }

    [Void]AddTransitions(
        [SMTransition[]]$Transitions
    ) {
        Foreach($Transition in $Transitions) {
            $this.Transitions.Add($Transition)
        }
    }

    [Void]Update(
        [Context]$Context
    ) {
        [SMState]$CurrentStateObject = $this.States[$this.CurrentState]

        If(($null -NE $CurrentStateObject) -AND ($null -NE $CurrentStateObject.OnUpdate)) {
            If($null -NE $Context) {
                $Context.References[[SMState]::ContextSelfState] = $CurrentStateObject
            }

            $CurrentStateObject.OnUpdate.Invoke(@($Context))
        }
    }

    [Void]Trigger(
        [String]$StateEvent,
        [Context]$Context
    ) {
        # FIND A VALID TRANSITION FOR THE CURRENT STATE AND EVENT
        [SMTransition]$ValidTransition = $null

        Foreach($Transition in $this.Transitions) {
            If(($Transition.FromState -EQ $this.CurrentState) -AND ($Transition.UserEvent -EQ $StateEvent)) {
                $ValidTransition = $Transition

                Break
            }
        }

        # HANDLE INVALID EVENTS
        If($null -EQ $ValidTransition) {
            Write-Warning "Event '$($StateEvent)' is not valid for current state '$($this.CurrentState)'."

            Return
        }

        [String]$NextStateName    = $ValidTransition.ToState
        [SMState]$CurrentStateObj = $this.States[$this.CurrentState]
        [SMState]$NextStateObj    = $this.States[$NextStateName]

        # STEP 1: EXECUTE ONEXIT FOR THE CURRENT STATE
        If(($null -NE $CurrentStateObj) -AND ($null -NE $CurrentStateObj.OnExit)) {
            If($null -NE $Context) {
                $Context.References[[SMState]::ContextSelfState] = $CurrentStateObj
            }

            $CurrentStateObj.OnExit.Invoke($Context)
        }

        # STEP 2: EXECUTE TRANSITION SPECIFIC ACTION (IF ANY)
        If($null -NE $ValidTransition.Action) {
            $ValidTransition.Action.Invoke($Context)
        }

        # STEP 3: CHANGE THE CURRENT STATE
        $this.CurrentState = $NextStateName

        # STEP 4: EXECUTE ONENTER FOR THE NEW STATE
        If(($null -NE $NextStateObj) -AND ($null -NE $NextStateObj.OnEnter)) {
            If($null -NE $Context) {
                $Context.References[[SMState]::ContextSelfState] = $NextStateObj
            }

            $NextStateObj.OnEnter.Invoke($Context)
        }
    }
}
