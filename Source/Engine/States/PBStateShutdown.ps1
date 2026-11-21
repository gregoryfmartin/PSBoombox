using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE SHUTDOWN
#
# CLEANUP STATE DISPOSING AUDIO RESOURCES, RESTORING TERMINAL STATE, AND
# TERMINATING THE APPLICATION LOOP.
#
###############################################################################

Class PBStateShutdown : SMState {
    PBStateShutdown() : base('PBStateShutdown') {
        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]

            $Core.MediaPlayer.Dispose()

            If($Core.AltScreenActive -EQ $true) {
                $Core.ExitAlternateScreen()
            } Elseif([Console]::IsOutputRedirected -EQ $false) {
                Write-Host "$([ATControlSequences]::ModifierReset)$([ATControlSequences]::CursorShow)" -NoNewline
            }

            $Core.IsRunning = $false
        }

        $this.OnExit = $null

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [AppCore]$Core = $Context.References[[SMState]::ContextBoomboxCore]
            $Core.IsRunning    = $false
        }
    }
}
