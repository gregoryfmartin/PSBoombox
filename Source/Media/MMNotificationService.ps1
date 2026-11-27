using namespace System
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Threading

Set-StrictMode -Version Latest





###############################################################################
#
# MM NOTIFICATION SERVICE
#
# OPTIONAL, OPT-IN BURNTTOAST DESKTOP NOTIFICATION SERVICE USING AN UP-FRONT
# DEDICATED BACKGROUND RUNSPACE WITH LATEST-WINS DEBOUNCE COALESCING.
#
###############################################################################

Class MMNotificationService {
    Static [String]$DefaultIconPath  = ''
    Static [String]$UniqueIdentifier = 'PSBoombox_NowPlaying'
    Static [Int]$DefaultDebounceMs   = 200

    [Boolean]$IsModuleLoaded
    [String]$LoadedModulePath
    [Boolean]$IsEnabled
    [Boolean]$IsHeadless
    [Boolean]$IsInitialized
    [Boolean]$IsDisposed
    [String]$IconPath
    [Int]$DebounceMs
    [String]$LastNotifiedTrackPath
    [Object]$SyncLock
    [Hashtable]$SharedState
    [AutoResetEvent]$WakeEvent
    [Runspace]$WorkerRunspace
    [PowerShell]$WorkerPowerShell
    [IAsyncResult]$WorkerAsyncResult
    [ScriptBlock]$DispatchOverride

    MMNotificationService() {
        $this.IsModuleLoaded        = $false
        $this.LoadedModulePath      = ''
        $this.IsEnabled             = $false
        $this.IsHeadless            = $false
        $this.IsInitialized         = $false
        $this.IsDisposed            = $false
        $this.IconPath              = [MMNotificationService]::DefaultIconPath
        $this.DebounceMs            = [MMNotificationService]::DefaultDebounceMs
        $this.LastNotifiedTrackPath = ''
        $this.SyncLock              = [Object]::new()
        $this.SharedState           = $null
        $this.WakeEvent             = $null
        $this.WorkerRunspace        = $null
        $this.WorkerPowerShell      = $null
        $this.WorkerAsyncResult     = $null
        $this.DispatchOverride      = $null
    }

    [Void]Initialize(
        [Boolean]$IsHeadlessMode
    ) {
        [PSModuleInfo]$LoadedModule = Get-Module -Name 'BurntToast' | Select-Object -First 1
        [String]$ResolvedPath       = ''

        If($null -NE $LoadedModule) {
            If(($null -NE $LoadedModule.Path) -AND ($LoadedModule.Path.Length -GT 0) -AND ([File]::Exists($LoadedModule.Path) -EQ $true)) {
                $ResolvedPath = $LoadedModule.Path
            } Elseif(($null -NE $LoadedModule.ModuleBase) -AND ($LoadedModule.ModuleBase.Length -GT 0)) {
                [String]$ManifestCandidate = [Path]::Combine($LoadedModule.ModuleBase, 'BurntToast.psd1')

                If([File]::Exists($ManifestCandidate) -EQ $true) {
                    $ResolvedPath = $ManifestCandidate
                } Else {
                    $ResolvedPath = $LoadedModule.ModuleBase
                }
            }
        }

        $this.InitializeWithModulePath($ResolvedPath, $IsHeadlessMode)
    }

    [Void]InitializeWithModulePath(
        [String]$ModulePath,
        [Boolean]$IsHeadlessMode
    ) {
        If($this.IsInitialized -EQ $true) {
            Return
        }

        $this.IsHeadless    = $IsHeadlessMode
        $this.IsInitialized = $true

        If($this.IconPath.Length -EQ 0) {
            $this.IconPath = [MMNotificationService]::DefaultIconPath
        }

        If(($null -EQ $ModulePath) -OR ($ModulePath.Trim().Length -EQ 0)) {
            $this.IsModuleLoaded   = $false
            $this.LoadedModulePath = ''

            Return
        }

        $this.IsModuleLoaded   = $true
        $this.LoadedModulePath = $ModulePath.Trim()

        If(($IsHeadlessMode -EQ $true) -OR ($null -NE $this.DispatchOverride)) {
            Return
        }

        $this.StartWorkerRunspace()
    }

    [Void]StartWorkerRunspace() {
        $this.WakeEvent   = [AutoResetEvent]::new($false)
        $this.SharedState = [Hashtable]::Synchronized(@{
            PendingAction           = 'None'
            PendingTrackName        = ''
            PendingSequence         = [Int64]0
            HasPendingOrActiveToast = $false
            HasActiveToast          = $false
            DebounceMs              = $this.DebounceMs
            IconPath                = $this.IconPath
            UniqueId                = [MMNotificationService]::UniqueIdentifier
            ModulePath              = $this.LoadedModulePath
            WorkerReady             = $false
            WorkerFailed            = $false
        })

        $this.WorkerRunspace = [RunspaceFactory]::CreateRunspace()
        $this.WorkerRunspace.Open()
        $this.WorkerRunspace.SessionStateProxy.SetVariable('SharedState', $this.SharedState)
        $this.WorkerRunspace.SessionStateProxy.SetVariable('SyncLock', $this.SyncLock)
        $this.WorkerRunspace.SessionStateProxy.SetVariable('WakeEvent', $this.WakeEvent)

        $this.WorkerPowerShell          = [PowerShell]::Create()
        $this.WorkerPowerShell.Runspace = $this.WorkerRunspace

        $null = $this.WorkerPowerShell.AddScript({
            Set-StrictMode -Version Latest

            [String]$ModPath  = [String]$SharedState['ModulePath']
            [String]$UniqueId = [String]$SharedState['UniqueId']

            Try {
                Import-Module -Name $ModPath -DisableNameChecking -ErrorAction Stop
                $SharedState['WorkerReady'] = $true
            } Catch {
                $SharedState['WorkerFailed'] = $true

                Return
            }

            [ScriptBlock]$RemoveActiveToast = {
                Param(
                    [String]$TargetId
                )

                Try {
                    [System.Management.Automation.CommandInfo]$RemoveCmd = Get-Command -Name 'Remove-BTNotification' -ErrorAction SilentlyContinue

                    If($null -NE $RemoveCmd) {
                        If($RemoveCmd.Parameters.ContainsKey('UniqueIdentifier') -EQ $true) {
                            Remove-BTNotification -UniqueIdentifier $TargetId -ErrorAction SilentlyContinue
                        } Elseif(($RemoveCmd.Parameters.ContainsKey('Tag') -EQ $true) -AND ($RemoveCmd.Parameters.ContainsKey('Group') -EQ $true)) {
                            Remove-BTNotification -Tag $TargetId -Group $TargetId -ErrorAction SilentlyContinue
                        } Else {
                            Remove-BTNotification -ErrorAction SilentlyContinue
                        }
                    } Else {
                        [Type]$CompatType = 'Microsoft.Toolkit.Uwp.Notifications.ToastNotificationManagerCompat' -AS [Type]

                        If($null -NE $CompatType) {
                            $CompatType::History.Remove($TargetId, $TargetId)
                        }
                    }
                } Catch {
                    # IGNORE TOAST REMOVAL ERRORS
                }
            }

            While($true) {
                [String]$Action    = 'None'
                [Int64]$Seq        = 0
                [String]$TrackName = ''

                [System.Threading.Monitor]::Enter($SyncLock)

                Try {
                    $Action    = [String]$SharedState['PendingAction']
                    $Seq       = [Int64]$SharedState['PendingSequence']
                    $TrackName = [String]$SharedState['PendingTrackName']
                } Finally {
                    [System.Threading.Monitor]::Exit($SyncLock)
                }

                If($Action -EQ 'None') {
                    $null = $WakeEvent.WaitOne()

                    Continue
                }

                If($Action -EQ 'Shutdown') {
                    If([Boolean]$SharedState['HasActiveToast'] -EQ $true) {
                        & $RemoveActiveToast $UniqueId
                        $SharedState['HasActiveToast'] = $false
                    }

                    Break
                }

                If($Action -EQ 'Dismiss') {
                    [System.Threading.Monitor]::Enter($SyncLock)

                    Try {
                        If([Int64]$SharedState['PendingSequence'] -EQ $Seq) {
                            $SharedState['PendingAction']           = 'None'
                            $SharedState['HasPendingOrActiveToast'] = $false
                        }
                    } Finally {
                        [System.Threading.Monitor]::Exit($SyncLock)
                    }

                    If([Boolean]$SharedState['HasActiveToast'] -EQ $true) {
                        & $RemoveActiveToast $UniqueId
                        $SharedState['HasActiveToast'] = $false
                    }

                    Continue
                }

                If($Action -EQ 'Notify') {
                    [Int]$WaitMs = [Int]$SharedState['DebounceMs']

                    While($WaitMs -GT 0) {
                        $null = $WakeEvent.WaitOne($WaitMs)

                        [String]$CurAction = 'None'
                        [Int64]$CurSeq     = 0
                        [String]$CurTrack  = ''

                        [System.Threading.Monitor]::Enter($SyncLock)

                        Try {
                            $CurAction = [String]$SharedState['PendingAction']
                            $CurSeq    = [Int64]$SharedState['PendingSequence']
                            $CurTrack  = [String]$SharedState['PendingTrackName']
                        } Finally {
                            [System.Threading.Monitor]::Exit($SyncLock)
                        }

                        If($CurAction -NE 'Notify') {
                            $Action = $CurAction

                            Break
                        }

                        If($CurSeq -EQ $Seq) {
                            Break
                        }

                        $Seq       = $CurSeq
                        $TrackName = $CurTrack
                    }

                    If($Action -NE 'Notify') {
                        Continue
                    }

                    [Boolean]$ShouldDispatch = $false

                    [System.Threading.Monitor]::Enter($SyncLock)

                    Try {
                        If(([String]$SharedState['PendingAction'] -EQ 'Notify') -AND ([Int64]$SharedState['PendingSequence'] -EQ $Seq)) {
                            $SharedState['PendingAction'] = 'None'
                            $ShouldDispatch               = $true
                        }
                    } Finally {
                        [System.Threading.Monitor]::Exit($SyncLock)
                    }

                    If($ShouldDispatch -EQ $false) {
                        Continue
                    }

                    [String]$IconFile       = [String]$SharedState['IconPath']
                    [Hashtable]$ToastParams = @{
                        Text             = @('PSBoombox', 'Now Playing', $TrackName)
                        Silent           = $true
                        UniqueIdentifier = $UniqueId
                    }

                    If(($IconFile.Length -GT 0) -AND ([System.IO.File]::Exists($IconFile) -EQ $true)) {
                        $ToastParams['AppLogo'] = $IconFile
                    }

                    Try {
                        New-BurntToastNotification @ToastParams -ErrorAction Stop
                        $SharedState['HasActiveToast'] = $true
                    } Catch {
                        # IGNORE TOAST DISPATCH ERRORS
                    }
                }
            }
        })

        $this.WorkerAsyncResult = $this.WorkerPowerShell.BeginInvoke()
    }

    [Hashtable]ToggleEnabled(
        [String]$CurrentPlayingPath
    ) {
        If($this.IsModuleLoaded -EQ $false) {
            $this.IsEnabled = $false

            Return @{
                Changed = $false
                Enabled = $false
                Message = 'BurntToast notifications unavailable (module not imported in session)'
            }
        }

        $this.IsEnabled = (-NOT $this.IsEnabled)

        If($this.IsEnabled -EQ $true) {
            $this.LastNotifiedTrackPath = ($null -EQ $CurrentPlayingPath) ? '' : $CurrentPlayingPath

            Return @{
                Changed = $true
                Enabled = $true
                Message = 'BurntToast notifications: On'
            }
        } Else {
            $this.DismissNotification()

            Return @{
                Changed = $true
                Enabled = $false
                Message = 'BurntToast notifications: Off'
            }
        }
    }

    [Void]NotifyTrackChange(
        [MMTrackInfo]$Track
    ) {
        If(($null -EQ $Track) -OR ($this.IsEnabled -EQ $false) -OR ($this.IsModuleLoaded -EQ $false) -OR ($this.IsDisposed -EQ $true)) {
            Return
        }

        [String]$TrackPath = ($null -EQ $Track.FullPath) ? '' : $Track.FullPath

        If(($TrackPath.Length -GT 0) -AND ($this.LastNotifiedTrackPath.Length -GT 0) -AND ([String]::Equals($TrackPath, $this.LastNotifiedTrackPath, [StringComparison]::OrdinalIgnoreCase) -EQ $true)) {
            Return
        }

        $this.LastNotifiedTrackPath = $TrackPath

        [String]$TrackName = (($null -NE $Track.DisplayName) -AND ($Track.DisplayName.Trim().Length -GT 0)) ? $Track.DisplayName.Trim() : $Track.FileName

        If($null -NE $this.DispatchOverride) {
            $null = $this.DispatchOverride.Invoke(
                'Notify',
                $TrackName,
                @{
                    UniqueIdentifier = [MMNotificationService]::UniqueIdentifier
                    Silent           = $true
                    IconPath         = $this.IconPath
                    Lines            = @('PSBoombox', 'Now Playing', $TrackName)
                }
            )

            Return
        }

        If(($null -EQ $this.SharedState) -OR ($null -EQ $this.WakeEvent)) {
            Return
        }

        [Monitor]::Enter($this.SyncLock)

        Try {
            $this.SharedState['PendingAction']           = 'Notify'
            $this.SharedState['PendingTrackName']        = $TrackName
            $this.SharedState['PendingSequence']         = ([Int64]$this.SharedState['PendingSequence']) + 1
            $this.SharedState['HasPendingOrActiveToast'] = $true
        } Finally {
            [Monitor]::Exit($this.SyncLock)
        }

        $null = $this.WakeEvent.Set()
    }

    [Void]DismissNotification() {
        $this.LastNotifiedTrackPath = ''

        If($this.IsDisposed -EQ $true) {
            Return
        }

        If($null -NE $this.DispatchOverride) {
            $null = $this.DispatchOverride.Invoke(
                'Dismiss',
                '',
                @{
                    UniqueIdentifier = [MMNotificationService]::UniqueIdentifier
                }
            )

            Return
        }

        If(($null -EQ $this.SharedState) -OR ($null -EQ $this.WakeEvent)) {
            Return
        }

        [Boolean]$ShouldSignal = $false

        [Monitor]::Enter($this.SyncLock)

        Try {
            If(([Boolean]$this.SharedState['HasPendingOrActiveToast'] -EQ $true) -OR ([Boolean]$this.SharedState['HasActiveToast'] -EQ $true) -OR ([String]$this.SharedState['PendingAction'] -EQ 'Notify')) {
                $this.SharedState['PendingAction']    = 'Dismiss'
                $this.SharedState['PendingTrackName'] = ''
                $this.SharedState['PendingSequence']  = ([Int64]$this.SharedState['PendingSequence']) + 1
                $ShouldSignal                         = $true
            }
        } Finally {
            [Monitor]::Exit($this.SyncLock)
        }

        If($ShouldSignal -EQ $true) {
            $null = $this.WakeEvent.Set()
        }
    }

    [Void]Dispose() {
        If($this.IsDisposed -EQ $true) {
            Return
        }

        $this.IsDisposed            = $true
        $this.IsEnabled             = $false
        $this.LastNotifiedTrackPath = ''

        If($null -NE $this.DispatchOverride) {
            $null = $this.DispatchOverride.Invoke(
                'Dispose',
                '',
                @{
                    UniqueIdentifier = [MMNotificationService]::UniqueIdentifier
                }
            )
        }

        If(($null -NE $this.SharedState) -AND ($null -NE $this.WakeEvent)) {
            [Monitor]::Enter($this.SyncLock)

            Try {
                $this.SharedState['PendingAction']    = 'Shutdown'
                $this.SharedState['PendingTrackName'] = ''
                $this.SharedState['PendingSequence']  = ([Int64]$this.SharedState['PendingSequence']) + 1
            } Finally {
                [Monitor]::Exit($this.SyncLock)
            }

            $null = $this.WakeEvent.Set()
        }

        If(($null -NE $this.WorkerAsyncResult) -AND ($null -NE $this.WorkerAsyncResult.AsyncWaitHandle)) {
            Try {
                $null = $this.WorkerAsyncResult.AsyncWaitHandle.WaitOne(1500)
            } Catch {
                # IGNORE WAIT ERRORS ON SHUTDOWN
            }
        }

        If($null -NE $this.WorkerPowerShell) {
            Try {
                $this.WorkerPowerShell.Stop()
            } Catch {
                # IGNORE STOP ERRORS ON DISPOSE
            }

            Try {
                $this.WorkerPowerShell.Dispose()
            } Catch {
                # IGNORE DISPOSE ERRORS ON DISPOSE
            }

            $this.WorkerPowerShell = $null
        }

        If($null -NE $this.WorkerRunspace) {
            Try {
                $this.WorkerRunspace.Close()
            } Catch {
                # IGNORE CLOSE ERRORS ON DISPOSE
            }

            Try {
                $this.WorkerRunspace.Dispose()
            } Catch {
                # IGNORE DISPOSE ERRORS ON DISPOSE
            }

            $this.WorkerRunspace = $null
        }

        If($null -NE $this.WakeEvent) {
            Try {
                $this.WakeEvent.Dispose()
            } Catch {
                # IGNORE WAKE EVENT DISPOSE ERRORS
            }

            $this.WakeEvent = $null
        }

        $this.WorkerAsyncResult = $null
        $this.SharedState       = $null
    }
}
