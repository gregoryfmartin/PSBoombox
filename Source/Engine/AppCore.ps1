using namespace System
using namespace System.Collections.Concurrent
using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Threading

Set-StrictMode -Version Latest





###############################################################################
#
# APP CORE
#
# ENGINE CORE PROVIDING THE FRAME LOOP, DELTA-TIME TIMING, INPUT RUNSPACE,
# AND STATE MACHINE EXECUTION.
#
###############################################################################

Class AppCore {
    [Boolean]$IsRunning
    [Boolean]$IsHeadlessMode
    [Boolean]$AltScreenActive
    [BufferSpecDefinition]$BufferSpec
    [ContextBroadcaster]$ContextBroadcaster
    [Janitor]$Janitor
    [Int]$TargetFps
    [Double]$TargetFrameTime
    [Boolean]$HighResTimerActive
    [Stopwatch]$Sw
    [Double]$LastTime
    [SMStateMachine]$AppState
    [ConcurrentQueue[ConsoleKeyInfo]]$InputQueue
    [Runspace]$InputRunspace
    [PowerShell]$InputPowerShell

    AppCore() {
        $this.IsRunning          = $true
        $this.IsHeadlessMode     = ([Console]::IsInputRedirected -EQ $true) -OR ([Console]::IsOutputRedirected -EQ $true)
        $this.AltScreenActive    = $false
        $this.TargetFps          = 30
        $this.TargetFrameTime    = 1.0 / $this.TargetFps
        $this.HighResTimerActive = $false
        $this.Sw                 = [Stopwatch]::new()
        $this.LastTime           = 0.0
        $this.BufferSpec         = [BufferSpecDefinition]::new()
        $this.Janitor            = [Janitor]::new($Global:PSVersionTable)
        $this.ContextBroadcaster = [ContextBroadcaster]::new()
        $this.InputQueue         = [ConcurrentQueue[ConsoleKeyInfo]]::new()
        $this.InputRunspace      = $null
        $this.InputPowerShell    = $null
        $this.AppState           = $null
    }

    [Void]InitializeStates() {}

    [Void]BeforeStateUpdate(
        [Context]$Context
    ) {}

    [Void]EnterAlternateScreen() {
        If(($this.IsHeadlessMode -EQ $false) -AND ([Console]::IsOutputRedirected -EQ $false) -AND ($this.AltScreenActive -EQ $false)) {
            Write-Host "$([ATControlSequences]::AltScreenEnter)$([ATControlSequences]::CursorHide)$([ATControlSequences]::GenerateThemeClearScreenString())" -NoNewline
            $this.AltScreenActive = $true
        }
    }

    [Void]ExitAlternateScreen() {
        If(($this.AltScreenActive -EQ $true) -AND ([Console]::IsOutputRedirected -EQ $false)) {
            Write-Host "$([ATControlSequences]::ModifierReset)$([ATControlSequences]::CursorShow)$([ATControlSequences]::AltScreenExit)" -NoNewline
            $this.AltScreenActive = $false
        }
    }

    [Void]SetTargetFps(
        [Int]$Fps
    ) {
        [Int]$Clamped         = [Math]::Clamp($Fps, 10, 120)
        $this.TargetFps       = $Clamped
        $this.TargetFrameTime = 1.0 / [Double]$Clamped

        If($this.IsHeadlessMode -EQ $false) {
            If(($Clamped -GE 50) -AND ($this.HighResTimerActive -EQ $false)) {
                $this.HighResTimerActive = [MMWinMMNative]::BeginHighResTimer([UInt32]1)
            } Elseif(($Clamped -LT 50) -AND ($this.HighResTimerActive -EQ $true)) {
                $null                    = [MMWinMMNative]::EndHighResTimer([UInt32]1)
                $this.HighResTimerActive = $false
            }
        }
    }

    [Void]EnqueueSyntheticKey(
        [ConsoleKeyInfo]$KeyInfo
    ) {
        $this.InputQueue.Enqueue($KeyInfo)
    }

    [Void]Setup() {
        If($this.IsHeadlessMode -EQ $false) {
            $this.InputRunspace = [RunspaceFactory]::CreateRunspace()
            $this.InputRunspace.Open()
            $this.InputRunspace.SessionStateProxy.SetVariable('InputQueue', $this.InputQueue)

            $this.InputPowerShell = [PowerShell]::Create().AddScript({
                While($true) {
                    If([Console]::KeyAvailable -EQ $true) {
                        $InputQueue.Enqueue([Console]::ReadKey($true))
                    }

                    Start-Sleep -Milliseconds 8
                }
            })
            $this.InputPowerShell.Runspace = $this.InputRunspace
            $null                          = $this.InputPowerShell.BeginInvoke()

            $this.EnterAlternateScreen()
        }

        $this.InitializeStates()

        If($null -EQ $this.AppState) {
            Write-Warning 'No App State Machine was initialized!'

            $this.IsRunning = $false
        }

        $this.Sw.Start()
    }

    [Void]Logic(
        [Double]$DeltaTime
    ) {
        [List[ConsoleKeyInfo]]$KeysPressedThisFrame = [List[ConsoleKeyInfo]]::new()
        [ConsoleKeyInfo]$KeyInfo                    = [ConsoleKeyInfo]::new([Char]' ', [ConsoleKey]::None, $false, $false, $false)

        While($this.InputQueue.TryDequeue([Ref]$KeyInfo) -EQ $true) {
            $KeysPressedThisFrame.Add($KeyInfo)
        }

        [Context]$FrameContext = [Context]::new(@{
            [SMState]::ContextDeltaTime   = $DeltaTime
            [SMState]::ContextKeysPressed = $KeysPressedThisFrame
            [SMState]::ContextBoomboxCore = $this
        })

        $this.BeforeStateUpdate($FrameContext)

        If($null -NE $this.AppState) {
            $this.AppState.Update($FrameContext)
        }
    }

    [Void]Run() {
        Try {
            $this.Setup()

            [Double]$NextFrameTarget = $this.Sw.Elapsed.TotalSeconds

            While($this.IsRunning -EQ $true) {
                [Double]$CurrentTime = $this.Sw.Elapsed.TotalSeconds
                [Double]$Dt          = $CurrentTime - $this.LastTime
                $this.LastTime       = $CurrentTime

                $this.Logic($Dt)

                $NextFrameTarget      += $this.TargetFrameTime
                [Double]$NowAfterWork  = $this.Sw.Elapsed.TotalSeconds

                If($NextFrameTarget -LT $NowAfterWork) {
                    $NextFrameTarget = $NowAfterWork
                }

                [Double]$RemainingSeconds = $NextFrameTarget - $NowAfterWork

                If($RemainingSeconds -GT 0.0) {
                    If($this.TargetFps -GE 50) {
                        [Int]$SleepMs = [Int][Math]::Floor(($RemainingSeconds - 0.002) * 1000.0)

                        If($SleepMs -GE 1) {
                            [Thread]::Sleep($SleepMs)
                        }

                        While(($this.Sw.Elapsed.TotalSeconds -LT $NextFrameTarget) -AND ($this.IsRunning -EQ $true)) {
                            [Thread]::SpinWait(64)
                        }
                    } Else {
                        [Int]$SleepMs = [Int][Math]::Floor($RemainingSeconds * 1000.0)

                        If($SleepMs -GE 1) {
                            [Thread]::Sleep($SleepMs)
                        }
                    }
                }
            }
        } Finally {
            $this.Cleanup()
        }
    }

    [Void]Cleanup() {
        If($this.HighResTimerActive -EQ $true) {
            Try {
                $null = [MMWinMMNative]::EndHighResTimer([UInt32]1)
            } Catch {
                # IGNORE TIMER RESTORE ERRORS ON DISPOSE
            }

            $this.HighResTimerActive = $false
        }

        If($null -NE $this.InputPowerShell) {
            Try {
                $this.InputPowerShell.Stop()
            } Catch {
                # IGNORE STOP ERRORS ON DISPOSE
            }

            $this.InputPowerShell.Dispose()
            $this.InputPowerShell = $null
        }

        If($null -NE $this.InputRunspace) {
            Try {
                $this.InputRunspace.Close()
            } Catch {
                # IGNORE CLOSE ERRORS ON DISPOSE
            }

            $this.InputRunspace.Dispose()
            $this.InputRunspace = $null
        }

        If($null -NE $this.Sw) {
            $this.Sw.Stop()
        }

        If($this.AltScreenActive -EQ $true) {
            $this.ExitAlternateScreen()
        } Elseif([Console]::IsOutputRedirected -EQ $false) {
            Write-Host "$([ATControlSequences]::ModifierReset)$([ATControlSequences]::CursorShow)" -NoNewline
        }
    }
}
