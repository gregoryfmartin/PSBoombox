using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# SM PLAYBACK STOPPED
#
###############################################################################

Class SMPlaybackStopped : SMState {
    SMPlaybackStopped() : base('SMPlaybackStopped') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackStopped_OnEnter', $Context)
            }
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackStopped_OnExit', $Context)
            }
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackStopped_OnUpdate', $Context)
            }
        }
    }
}





###############################################################################
#
# SM PLAYBACK LOADING
#
###############################################################################

Class SMPlaybackLoading : SMState {
    SMPlaybackLoading() : base('SMPlaybackLoading') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackLoading_OnEnter', $Context)
            }
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackLoading_OnExit', $Context)
            }
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackLoading_OnUpdate', $Context)
            }
        }
    }
}





###############################################################################
#
# SM PLAYBACK PLAYING
#
###############################################################################

Class SMPlaybackPlaying : SMState {
    SMPlaybackPlaying() : base('SMPlaybackPlaying') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackPlaying_OnEnter', $Context)
            }
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackPlaying_OnExit', $Context)
            }
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackPlaying_OnUpdate', $Context)
            }
        }
    }
}





###############################################################################
#
# SM PLAYBACK PAUSED
#
###############################################################################

Class SMPlaybackPaused : SMState {
    SMPlaybackPaused() : base('SMPlaybackPaused') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackPaused_OnEnter', $Context)
            }
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackPaused_OnExit', $Context)
            }
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackPaused_OnUpdate', $Context)
            }
        }
    }
}





###############################################################################
#
# SM PLAYBACK ERROR
#
###############################################################################

Class SMPlaybackError : SMState {
    SMPlaybackError() : base('SMPlaybackError') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackError_OnEnter', $Context)
            }
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackError_OnExit', $Context)
            }
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            If(($null -NE $Context) -AND ($Context.References.ContainsKey([SMPlaybackStateMachine]::ContextMediaPlayer) -EQ $true)) {
                $Context.References[[SMPlaybackStateMachine]::ContextMediaPlayer].Publish('SMPlaybackError_OnUpdate', $Context)
            }
        }
    }
}





###############################################################################
#
# SM PLAYBACK STATE MACHINE
#
# A FINITE STATE MACHINE CONTROLLING AUDIO PLAYBACK LIFECYCLE STATES.
#
###############################################################################

Class SMPlaybackStateMachine : SMStateMachine {
    Static [String]$ContextMediaPlayer   = 'MediaPlayer'
    Static [String]$TransitionLoad       = 'Load'
    Static [String]$TransitionPlayReady  = 'PlayReady'
    Static [String]$TransitionLoadFailed = 'LoadFailed'
    Static [String]$TransitionPause      = 'Pause'
    Static [String]$TransitionResume     = 'Resume'
    Static [String]$TransitionStop       = 'Stop'
    Static [String]$TransitionTrackEnded = 'TrackEnded'
    Static [String]$TransitionReset      = 'Reset'
    Static [String]$StateStopped         = 'SMPlaybackStopped'
    Static [String]$StateLoading         = 'SMPlaybackLoading'
    Static [String]$StatePlaying         = 'SMPlaybackPlaying'
    Static [String]$StatePaused          = 'SMPlaybackPaused'
    Static [String]$StateError           = 'SMPlaybackError'

    SMPlaybackStateMachine() : base('SMPlaybackStopped') {
        $this.AddStates(@(
            [SMPlaybackStopped]::new(),
            [SMPlaybackLoading]::new(),
            [SMPlaybackPlaying]::new(),
            [SMPlaybackPaused]::new(),
            [SMPlaybackError]::new()
        ))

        $this.AddTransitions(@(
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateStopped,
                [SMPlaybackStateMachine]::TransitionLoad,
                [SMPlaybackStateMachine]::StateLoading
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateLoading,
                [SMPlaybackStateMachine]::TransitionPlayReady,
                [SMPlaybackStateMachine]::StatePlaying
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateLoading,
                [SMPlaybackStateMachine]::TransitionLoadFailed,
                [SMPlaybackStateMachine]::StateError
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateLoading,
                [SMPlaybackStateMachine]::TransitionStop,
                [SMPlaybackStateMachine]::StateStopped
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePlaying,
                [SMPlaybackStateMachine]::TransitionPause,
                [SMPlaybackStateMachine]::StatePaused
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePlaying,
                [SMPlaybackStateMachine]::TransitionStop,
                [SMPlaybackStateMachine]::StateStopped
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePlaying,
                [SMPlaybackStateMachine]::TransitionTrackEnded,
                [SMPlaybackStateMachine]::StateStopped
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePlaying,
                [SMPlaybackStateMachine]::TransitionLoad,
                [SMPlaybackStateMachine]::StateLoading
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePlaying,
                [SMPlaybackStateMachine]::TransitionLoadFailed,
                [SMPlaybackStateMachine]::StateError
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePaused,
                [SMPlaybackStateMachine]::TransitionResume,
                [SMPlaybackStateMachine]::StatePlaying
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePaused,
                [SMPlaybackStateMachine]::TransitionStop,
                [SMPlaybackStateMachine]::StateStopped
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePaused,
                [SMPlaybackStateMachine]::TransitionLoad,
                [SMPlaybackStateMachine]::StateLoading
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StatePaused,
                [SMPlaybackStateMachine]::TransitionLoadFailed,
                [SMPlaybackStateMachine]::StateError
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateError,
                [SMPlaybackStateMachine]::TransitionLoad,
                [SMPlaybackStateMachine]::StateLoading
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateError,
                [SMPlaybackStateMachine]::TransitionReset,
                [SMPlaybackStateMachine]::StateStopped
            ),
            [SMTransition]::new(
                [SMPlaybackStateMachine]::StateError,
                [SMPlaybackStateMachine]::TransitionStop,
                [SMPlaybackStateMachine]::StateStopped
            )
        ))
    }

    [PlaybackState]GetPlaybackState() {
        Switch($this.CurrentState) {
            ([SMPlaybackStateMachine]::StateLoading) {
                Return [PlaybackState]::Loading
            }

            ([SMPlaybackStateMachine]::StatePlaying) {
                Return [PlaybackState]::Playing
            }

            ([SMPlaybackStateMachine]::StatePaused) {
                Return [PlaybackState]::Paused
            }

            ([SMPlaybackStateMachine]::StateError) {
                Return [PlaybackState]::Error
            }

            Default {
                Return [PlaybackState]::Stopped
            }
        }

        Return [PlaybackState]::Stopped
    }
}
