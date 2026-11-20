using namespace System
using namespace System.Management.Automation

Set-StrictMode -Version Latest





###############################################################################
#
# JANITOR
#
# PERFORMS RUNTIME ENVIRONMENT, OS, EDITION, AND CONSOLE BUFFER CHECKS.
#
###############################################################################

Class Janitor {
    [SemanticVersion]$CurrentAppVersion
    [SemanticVersion]$CurrentPSVersion
    [String]$CurrentPSEdition
    [String]$CurrentOS
    [Boolean]$RunningOnWindows

    Janitor(
        [Hashtable]$PSVersionInfo
    ) {
        $this.CurrentAppVersion = [SemanticVersion]::new(0, 1, 0)
        $this.CurrentPSVersion  = $PSVersionInfo.PSVersion
        $this.CurrentPSEdition  = ($null -NE $PSVersionInfo.PSEdition) ? [String]$PSVersionInfo.PSEdition : ''
        $this.CurrentOS         = ($PSVersionInfo.ContainsKey('OS') -EQ $true -AND ($null -NE $PSVersionInfo.OS)) ? [String]$PSVersionInfo.OS : ''
        $this.RunningOnWindows  = [Environment]::OSVersion.Platform -EQ [PlatformID]::Win32NT
    }

    [Boolean]PerformSystemSetupChecks(
        [ContextBroadcaster]$ContextBroadcaster
    ) {
        [Boolean]$OsOk      = $this.CheckOS($ContextBroadcaster)
        [Boolean]$EditionOk = $this.CheckPSEdition($ContextBroadcaster)

        $this.CheckPSVersion($ContextBroadcaster)

        Return ($OsOk -AND $EditionOk)
    }

    [Void]PerformRegularChecks(
        [ContextBroadcaster]$ContextBroadcaster,
        [BufferSpecDefinition]$Bsd
    ) {
        $this.CheckBufferWidth($ContextBroadcaster, $Bsd)
        $this.CheckBufferHeight($ContextBroadcaster, $Bsd)
    }

    [Boolean]CheckPSEdition(
        [ContextBroadcaster]$ContextBroadcaster
    ) {
        If($this.CurrentPSEdition -NE 'Core') {
            If($null -NE $ContextBroadcaster) {
                $ContextBroadcaster.Broadcast(
                    [CustomEvents]::BadPSEdition,
                    $this,
                    [Context]::new(@{
                        Janitor = $this
                    })
                )
            }

            Return $false
        }

        Return $true
    }

    [Void]CheckPSVersion(
        [ContextBroadcaster]$ContextBroadcaster
    ) {
        Return
    }

    [Boolean]CheckOS(
        [ContextBroadcaster]$ContextBroadcaster
    ) {
        If($this.RunningOnWindows -EQ $false) {
            If($null -NE $ContextBroadcaster) {
                $ContextBroadcaster.Broadcast(
                    [CustomEvents]::UnsupportedOS,
                    $this,
                    [Context]::new(@{
                        Janitor = $this
                    })
                )
            }

            Return $false
        }

        Return $true
    }

    [Void]CheckBufferWidth(
        [ContextBroadcaster]$ContextBroadcaster,
        [BufferSpecDefinition]$Bsd
    ) {
        If(($null -EQ $ContextBroadcaster) -OR ($null -EQ $Bsd)) {
            Return
        }

        If([Console]::IsOutputRedirected -EQ $true) {
            Return
        }

        If([Console]::WindowWidth -LT $Bsd.BufferMinWidth.Value) {
            $ContextBroadcaster.Broadcast(
                [CustomEvents]::BufferWidthTooSmall,
                $this,
                [Context]::new(@{
                    Janitor         = $this
                    UserBufferWidth = [Console]::WindowWidth
                })
            )
        }
    }

    [Void]CheckBufferHeight(
        [ContextBroadcaster]$ContextBroadcaster,
        [BufferSpecDefinition]$Bsd
    ) {
        If(($null -EQ $ContextBroadcaster) -OR ($null -EQ $Bsd)) {
            Return
        }

        If([Console]::IsOutputRedirected -EQ $true) {
            Return
        }

        If([Console]::WindowHeight -LT $Bsd.BufferMinHeight.Value) {
            $ContextBroadcaster.Broadcast(
                [CustomEvents]::BufferHeightTooSmall,
                $this,
                [Context]::new(@{
                    Janitor          = $this
                    UserBufferHeight = [Console]::WindowHeight
                })
            )
        }
    }
}
