using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# BOOMBOX CORE
#
# APPLICATION CORE COORDINATING MEDIA SERVICES, PANELS, FOCUS ZONES, AND
# APPLICATION STATES FOR PSBOOMBOX.
#
###############################################################################

Class BoomboxCore : AppCore {
    [String]$InitialPath
    [String]$InitialPlaylistPath
    [String]$InitialTheme
    [Int]$LayoutWidth
    [Int]$LayoutHeight
    [Int]$LastViewportWidth
    [Int]$LastViewportHeight
    [Int]$SimulatedViewportWidth
    [Int]$SimulatedViewportHeight
    [Boolean]$IsBufferTooSmall
    [Boolean]$IsSuspendedForResize
    [Boolean]$PendingScreenClear
    [String]$SuspendedStateName
    [MMDirectoryService]$DirectoryService
    [MMPlaylist]$Playlist
    [MMMediaPlayer]$MediaPlayer
    [MMEqualizerService]$EqualizerService
    [MMNotificationService]$NotificationService
    [UIThemeService]$ThemeService
    [UIPlaybackControlPanel]$PlaybackPanel
    [UIDirectoryBrowserPanel]$DirectoryPanel
    [UIPlaylistPanel]$PlaylistPanel
    [UIPathInputModal]$PathModal
    [UIEqualizerModal]$EqualizerModal
    [UIThemeModal]$ThemeModal
    [UINoticeModal]$NoticeModal
    [UIVisualizerCanvas]$VisualizerCanvas
    [List[UIVisualizerBase]]$Visualizers
    [Int]$ActiveVisualizerIndex
    [UILabel]$VisualizerTrackLabel
    [UILabel]$VisualizerHintLabel
    [UIStatusFooterPanel]$FooterPanel
    [BoomboxFocusZone]$ActiveFocusZone
    [Boolean]$AutoFocusPlaylistOnStart
    [String]$PendingStartupStatus
    [Boolean]$PendingStartupError

    BoomboxCore() : base() {
        $this.InitializeCore((Get-Location).Path, '', '')
    }

    BoomboxCore(
        [String]$InitialPath
    ) : base() {
        $this.InitializeCore($InitialPath, '', '')
    }

    BoomboxCore(
        [String]$InitialPath,
        [String]$InitialPlaylistPath
    ) : base() {
        $this.InitializeCore($InitialPath, $InitialPlaylistPath, '')
    }

    BoomboxCore(
        [String]$InitialPath,
        [String]$InitialPlaylistPath,
        [String]$InitialTheme
    ) : base() {
        $this.InitializeCore($InitialPath, $InitialPlaylistPath, $InitialTheme)
    }

    [Void]InitializeCore(
        [String]$InitialPath,
        [String]$InitialPlaylistPath,
        [String]$InitialTheme
    ) {
        $this.InitialPath                  = (($null -NE $InitialPath) -AND ($InitialPath.Length -GT 0)) ? $InitialPath : (Get-Location).Path
        $this.InitialPlaylistPath          = ($null -EQ $InitialPlaylistPath) ? '' : $InitialPlaylistPath
        $this.InitialTheme                 = ($null -EQ $InitialTheme) ? '' : $InitialTheme
        $this.LastViewportWidth            = 0
        $this.LastViewportHeight           = 0
        $this.SimulatedViewportWidth       = 0
        $this.SimulatedViewportHeight      = 0
        $this.IsBufferTooSmall             = $false
        $this.IsSuspendedForResize         = $false
        $this.PendingScreenClear           = $false
        $this.SuspendedStateName           = ''
        $this.DirectoryService             = [MMDirectoryService]::new()
        $this.Playlist                     = [MMPlaylist]::new()
        $this.EqualizerService             = [MMEqualizerService]::new()
        $this.NotificationService          = [MMNotificationService]::new()
        $this.ThemeService                 = [UIThemeService]::new()
        $this.MediaPlayer                  = [MMMediaPlayer]::new()
        $this.MediaPlayer.EqualizerService = $this.EqualizerService
        $this.ActiveFocusZone              = [BoomboxFocusZone]::DirectoryBrowser
        $this.AutoFocusPlaylistOnStart     = $false
        $this.PendingStartupStatus         = 'Ready'
        $this.PendingStartupError          = $false

        $this.ComputeLayoutBounds()
        $this.InitializeUiComponents()
    }

    [Void]SetSimulatedViewport(
        [Int]$Width,
        [Int]$Height
    ) {
        $this.SimulatedViewportWidth  = $Width
        $this.SimulatedViewportHeight = $Height
    }

    [Hashtable]GetViewportDimensions() {
        If(($this.SimulatedViewportWidth -GT 0) -AND ($this.SimulatedViewportHeight -GT 0)) {
            Return @{
                Width  = $this.SimulatedViewportWidth
                Height = $this.SimulatedViewportHeight
            }
        }

        If([Console]::IsOutputRedirected -EQ $false) {
            Try {
                [Int]$WinW = [Console]::WindowWidth
                [Int]$WinH = [Console]::WindowHeight

                If(($WinW -GT 0) -AND ($WinH -GT 0)) {
                    Return @{
                        Width  = $WinW
                        Height = $WinH
                    }
                }
            } Catch {
                # FALL BACK TO LAST KNOWN VIEWPORT DIMENSIONS DURING LIVE RESIZE
            }

            If(($this.LastViewportWidth -GT 0) -AND ($this.LastViewportHeight -GT 0)) {
                Return @{
                    Width  = $this.LastViewportWidth
                    Height = $this.LastViewportHeight
                }
            }
        }

        Return @{
            Width  = 100
            Height = 28
        }
    }

    [Void]ComputeLayoutBounds() {
        [Hashtable]$Dims         = $this.GetViewportDimensions()
        $this.LastViewportWidth  = $Dims.Width
        $this.LastViewportHeight = $Dims.Height
        $this.IsBufferTooSmall   = $this.Janitor.IsViewportBelowMinimum($Dims.Width, $Dims.Height, $this.BufferSpec)
        $this.LayoutWidth        = [Math]::Max($this.BufferSpec.BufferMinWidth.Value, $Dims.Width)
        $this.LayoutHeight       = [Math]::Max($this.BufferSpec.BufferMinHeight.Value, $Dims.Height)

        [ATCoordinates]::SetBounds(($this.LayoutHeight + 4), ($this.LayoutWidth + 4))
    }

    [Void]ResizeUiComponents() {
        [Int]$BottomTopRow  = 6
        [Int]$BottomEndRow  = $this.LayoutHeight - 2
        [Int]$LeftPaneWidth = [Int][Math]::Floor($this.LayoutWidth / 2)

        $this.PlaybackPanel.Resize($this.LayoutWidth)
        $this.DirectoryPanel.Resize($BottomTopRow, $BottomEndRow, 1, $LeftPaneWidth)
        $this.PlaylistPanel.Resize($BottomTopRow, $BottomEndRow, ($LeftPaneWidth + 1), $this.LayoutWidth)
        $this.PathModal.Resize($this.LayoutWidth, $this.LayoutHeight)
        $this.EqualizerModal.Resize($this.LayoutWidth, $this.LayoutHeight)
        $this.ThemeModal.Resize($this.LayoutWidth, $this.LayoutHeight)
        $this.NoticeModal.Resize($this.LayoutWidth, $this.LayoutHeight)
        $this.VisualizerCanvas.Initialize($this.LayoutWidth, [Math]::Max(6, ($this.LayoutHeight - 2)), 1, 1)
        $this.VisualizerTrackLabel.SetLayout([ATCoordinates]::new(($this.LayoutHeight - 1), 2), [Math]::Max(20, ($this.LayoutWidth - 2)))
        $this.VisualizerHintLabel.SetLayout([ATCoordinates]::new($this.LayoutHeight, 2), [Math]::Max(20, ($this.LayoutWidth - 2)))
        $this.FooterPanel.Resize(($this.LayoutHeight - 1), $this.LayoutWidth)
        $this.SyncAllPanelsFromState()
        $this.SyncVisualizerTrackLabel()
    }

    [Void]ApplyViewportLayout(
        [Int]$Width,
        [Int]$Height
    ) {
        $this.LastViewportWidth  = $Width
        $this.LastViewportHeight = $Height
        $this.LayoutWidth        = [Math]::Max($this.BufferSpec.BufferMinWidth.Value, $Width)
        $this.LayoutHeight       = [Math]::Max($this.BufferSpec.BufferMinHeight.Value, $Height)

        [ATCoordinates]::SetBounds(($this.LayoutHeight + 4), ($this.LayoutWidth + 4))
        $this.ResizeUiComponents()

        $this.PendingScreenClear = $true
    }

    [Void]BeforeStateUpdate(
        [Context]$Context
    ) {
        $this.CheckAndHandleViewportResize($Context)
    }

    [Void]CheckAndHandleViewportResize(
        [Context]$Context
    ) {
        If(($null -EQ $this.AppState) -OR ($this.AppState.CurrentState -EQ 'PBStateShutdown')) {
            Return
        }

        [Hashtable]$Dims   = $this.GetViewportDimensions()
        [Int]$CurW         = $Dims.Width
        [Int]$CurH         = $Dims.Height
        [Boolean]$TooSmall = $this.Janitor.IsViewportBelowMinimum($CurW, $CurH, $this.BufferSpec)

        If($this.AppState.CurrentState -EQ 'PBStateInit') {
            $this.LastViewportWidth  = $CurW
            $this.LastViewportHeight = $CurH
            $this.IsBufferTooSmall   = $TooSmall

            If(($TooSmall -EQ $false) -AND (($CurW -NE $this.LayoutWidth) -OR ($CurH -NE $this.LayoutHeight))) {
                $this.ApplyViewportLayout($CurW, $CurH)
            }

            Return
        }

        If($TooSmall -EQ $true) {
            $this.LastViewportWidth  = $CurW
            $this.LastViewportHeight = $CurH
            $this.IsBufferTooSmall   = $true

            If($this.AppState.CurrentState -NE 'PBStateBufferTooSmall') {
                $this.SuspendedStateName   = $this.AppState.CurrentState
                $this.IsSuspendedForResize = $true
                $this.PendingScreenClear   = $true

                $this.AppState.Trigger('BufferTooSmall', $Context)
            }

            Return
        }

        If($this.AppState.CurrentState -EQ 'PBStateBufferTooSmall') {
            $this.IsBufferTooSmall = $false

            $this.ApplyViewportLayout($CurW, $CurH)

            [String]$TargetState = ($this.SuspendedStateName.Length -GT 0) ? $this.SuspendedStateName : 'PBStateMainPlayer'

            If($TargetState -EQ 'PBStateVisualizer') {
                If($this.MediaPlayer.IsStopped() -EQ $true) {
                    $this.IsSuspendedForResize = $false

                    $this.VisualizerTrackLabel.Deactivate($Context)
                    $this.VisualizerHintLabel.Deactivate($Context)
                    $this.FooterPanel.SetStatus('Playback stopped. Returned to Playlist Mode.')
                    $this.AppState.Trigger('Resume_PBStateMainPlayer', $Context)

                    Return
                } Elseif($this.MediaPlayer.IsEqualizerBypassedForCurrentTrack() -EQ $true) {
                    $this.IsSuspendedForResize = $false

                    $this.VisualizerTrackLabel.Deactivate($Context)
                    $this.VisualizerHintLabel.Deactivate($Context)
                    $this.OpenMidiVisualizerNotice($Context, 'Resume_PBStateNoticeModal')

                    Return
                }
            }

            $this.AppState.Trigger("Resume_$($TargetState)", $Context)

            Return
        }

        $this.LastViewportWidth  = $CurW
        $this.LastViewportHeight = $CurH
        $this.IsBufferTooSmall   = $false

        If(($CurW -NE $this.LayoutWidth) -OR ($CurH -NE $this.LayoutHeight)) {
            $this.ApplyViewportLayout($CurW, $CurH)
        }
    }

    [Void]InitializeUiComponents() {
        [Int]$BottomTopRow  = 6
        [Int]$BottomEndRow  = $this.LayoutHeight - 2
        [Int]$LeftPaneWidth = [Int][Math]::Floor($this.LayoutWidth / 2)

        $this.PlaybackPanel        = [UIPlaybackControlPanel]::new($this.LayoutWidth)
        $this.DirectoryPanel       = [UIDirectoryBrowserPanel]::new($BottomTopRow, $BottomEndRow, 1, $LeftPaneWidth)
        $this.PlaylistPanel        = [UIPlaylistPanel]::new($BottomTopRow, $BottomEndRow, ($LeftPaneWidth + 1), $this.LayoutWidth)
        $this.PathModal            = [UIPathInputModal]::new($this.LayoutWidth, $this.LayoutHeight)
        $this.EqualizerModal       = [UIEqualizerModal]::new($this.LayoutWidth, $this.LayoutHeight)
        $this.ThemeModal           = [UIThemeModal]::new($this.LayoutWidth, $this.LayoutHeight)
        $this.NoticeModal          = [UINoticeModal]::new($this.LayoutWidth, $this.LayoutHeight)
        $this.VisualizerCanvas     = [UIVisualizerCanvas]::new($this.LayoutWidth, [Math]::Max(6, ($this.LayoutHeight - 2)), 1, 1)
        $this.Visualizers          = [List[UIVisualizerBase]]::new()
        $this.Visualizers.Add([UIVisualizerSpectrum]::new())
        $this.Visualizers.Add([UIVisualizerMirror]::new())
        $this.Visualizers.Add([UIVisualizerOscilloscope]::new())
        $this.Visualizers.Add([UIVisualizerRadialPulse]::new())
        $this.Visualizers.Add([UIVisualizerWaterfall]::new())
        $this.ActiveVisualizerIndex = 0
        $this.VisualizerTrackLabel  = [UILabel]::new('', [ATCoordinates]::new(($this.LayoutHeight - 1), 2), [ColorLibrary]::BoomboxVizTrackLabel, [Math]::Max(20, ($this.LayoutWidth - 2)))
        $this.VisualizerHintLabel   = [UILabel]::new('[Tab] Next Viz [V] Exit [Spc] Play/Pause [N/P] Track [+/-] Vol [M] Mute [B] Toast', [ATCoordinates]::new($this.LayoutHeight, 2), [ColorLibrary]::BoomboxVizHint, [Math]::Max(20, ($this.LayoutWidth - 2)))
        $this.FooterPanel           = [UIStatusFooterPanel]::new(($this.LayoutHeight - 1), $this.LayoutWidth)

        [BoomboxCore]$SelfCore = $this

        $this.PlaybackPanel.OnPrevClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.PlayPreviousTrack()
        }.GetNewClosure()

        $this.PlaybackPanel.OnPlayPauseClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.TogglePlayPause()
        }.GetNewClosure()

        $this.PlaybackPanel.OnStopClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.StopPlayback()
        }.GetNewClosure()

        $this.PlaybackPanel.OnNextClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.PlayNextTrack($true)
        }.GetNewClosure()

        $this.PlaybackPanel.OnRepeatClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.CycleRepeatMode()
        }.GetNewClosure()

        $this.PlaybackPanel.OnShuffleClicked = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.ToggleShuffle()
        }.GetNewClosure()

        $this.PlaybackPanel.Scrubber.OnSeekRequested = {
            Param(
                [Int]$DeltaMs
            )

            $SelfCore.SeekRelative($DeltaMs)
        }.GetNewClosure()

        $this.PlaybackPanel.VolumeControl.OnVolumeChanged = {
            Param(
                [Int]$NewPercent
            )

            $SelfCore.SetVolume($NewPercent)
        }.GetNewClosure()

        $this.PlaybackPanel.VolumeControl.OnMuteToggled = {
            Param(
                [Boolean]$Muted
            )

            $SelfCore.SetMuted($Muted)
        }.GetNewClosure()

        $this.DirectoryPanel.DirectoryList.OnActivate = {
            Param(
                [UIList]$SourceList,
                [Context]$ActionContext
            )

            $SelfCore.ActivateSelectedDirectoryEntry()
        }.GetNewClosure()

        $this.PlaylistPanel.PlaylistList.OnActivate = {
            Param(
                [UIList]$SourceList,
                [Context]$ActionContext
            )

            $SelfCore.PlaySelectedPlaylistItem()
        }.GetNewClosure()

        $this.MediaPlayer.OnTrackEnded = {
            Param(
                [MMMediaPlayer]$Player
            )

            $SelfCore.HandleTrackEnded()
        }.GetNewClosure()

        $this.MediaPlayer.OnError = {
            Param(
                [String]$ErrorMsg
            )

            $SelfCore.FooterPanel.SetError($ErrorMsg)
        }.GetNewClosure()

        $this.EqualizerService.OnEqualizerChanged = {
            Param(
                [MMEqualizerService]$EqService
            )

            $SelfCore.MediaPlayer.ApplyEqualizerFromService()
            $SelfCore.PlaybackPanel.SyncFromPlayer($SelfCore.MediaPlayer, $SelfCore.Playlist)
        }.GetNewClosure()

        $this.EqualizerModal.OnToggleEq = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.ToggleEqualizer()
        }.GetNewClosure()

        $this.EqualizerModal.OnCyclePreset = {
            Param(
                [Int]$Direction
            )

            $SelfCore.CycleEqualizerPreset($Direction)
        }.GetNewClosure()

        $this.EqualizerModal.OnPreampChanged = {
            Param(
                [Int]$GainDb
            )

            $SelfCore.SetEqualizerPreamp($GainDb)
        }.GetNewClosure()

        $this.EqualizerModal.OnBandChanged = {
            Param(
                [Int]$BandIndex,
                [Int]$GainDb
            )

            $SelfCore.SetEqualizerBand($BandIndex, $GainDb)
        }.GetNewClosure()

        $this.EqualizerModal.OnSavePreset = {
            Param(
                [String]$PresetName
            )

            Return $SelfCore.SaveEqualizerUserPreset($PresetName)
        }.GetNewClosure()

        $this.EqualizerModal.OnDeletePreset = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.DeleteActiveEqualizerPreset()
        }.GetNewClosure()

        $this.EqualizerModal.OnResetFlat = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.ResetEqualizerFlat()
        }.GetNewClosure()

        $this.EqualizerModal.OnCloseRequested = {
            Param(
                [Context]$ActionContext
            )

            $SelfCore.AppState.Trigger('CloseEqualizer', [Context]::new(@{ [SMState]::ContextBoomboxCore = $SelfCore }))
        }.GetNewClosure()

        $this.ThemeService.OnThemeChanged = {
            Param(
                [UIThemeService]$ChangedService
            )

            $SelfCore.RefreshAllForThemeChange()
        }.GetNewClosure()

        $this.ThemeModal.OnThemePreview = {
            Param(
                [UIThemeDefinition]$PreviewTheme
            )

            If($null -NE $PreviewTheme) {
                $SelfCore.ThemeService.ApplyTheme($PreviewTheme, $false)
                $SelfCore.FooterPanel.SetStatus("Theme preview: $($PreviewTheme.Name) (Enter to apply, Esc to cancel)")
            }
        }.GetNewClosure()

        $this.ThemeModal.OnThemeApply = {
            Param(
                [UIThemeDefinition]$SelectedTheme
            )

            If($null -NE $SelectedTheme) {
                $SelfCore.ThemeService.ApplyTheme($SelectedTheme, $true)
                $SelfCore.FooterPanel.SetStatus("Theme applied: $($SelectedTheme.Name)")
            }

            $SelfCore.AppState.Trigger('CloseThemeSelector', [Context]::new(@{ [SMState]::ContextBoomboxCore = $SelfCore }))
        }.GetNewClosure()

        $this.ThemeModal.OnThemeCancel = {
            Param(
                [Context]$CancelContext
            )

            [PBStateThemeSelector]$ThemeState = $SelfCore.AppState.States['PBStateThemeSelector'] -AS [PBStateThemeSelector]

            If(($null -NE $ThemeState) -AND ($null -NE $ThemeState.OriginalTheme)) {
                $SelfCore.ThemeService.ApplyTheme($ThemeState.OriginalTheme, $false)
            }

            $SelfCore.FooterPanel.SetStatus("Theme change cancelled ($($SelfCore.ThemeService.ActiveThemeName))")
            $SelfCore.AppState.Trigger('CloseThemeSelector', [Context]::new(@{ [SMState]::ContextBoomboxCore = $SelfCore }))
        }.GetNewClosure()
    }

    [Void]RefreshAllForThemeChange() {
        [TrueColor]$CanvasBg = ([ColorLibrary]::UseThemeBackground -EQ $true) ? [ColorLibrary]::ThemeBackground : $null

        $this.VisualizerCanvas.SetBackgroundColor($CanvasBg)

        Foreach($Viz in $this.Visualizers) {
            If($null -NE $Viz) {
                $Viz.RefreshPalette()
            }
        }

        $this.SyncAllPanelsFromState()
        $this.PlaybackPanel.SetAllElementsDirty()
        $this.DirectoryPanel.SetAllElementsDirty()
        $this.PlaylistPanel.SetAllElementsDirty()
        $this.PathModal.SetAllElementsDirty()
        $this.EqualizerModal.SetAllElementsDirty()
        $this.ThemeModal.MarkAllDirtyForThemeChange()
        $this.NoticeModal.SetAllElementsDirty()
        $this.FooterPanel.SetAllElementsDirty()

        $this.VisualizerTrackLabel.Dirty = $true
        $this.VisualizerHintLabel.Dirty  = $true
        $this.PendingScreenClear         = $true
    }

    [Void]InitializeStates() {
        $this.AppState = [SMStateMachine]::new('PBStateInit')

        $this.AppState.AddStates(@(
            [PBStateInit]::new(),
            [PBStateMainPlayer]::new(),
            [PBStateDirectoryPrompt]::new(),
            [PBStatePlaylistSavePrompt]::new(),
            [PBStateEqualizer]::new(),
            [PBStateThemeSelector]::new(),
            [PBStateNoticeModal]::new(),
            [PBStateVisualizer]::new(),
            [PBStateBufferTooSmall]::new(),
            [PBStateShutdown]::new()
        ))

        $this.AppState.AddTransitions(@(
            [SMTransition]::new('PBStateInit', 'Ready', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateInit', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateInit', 'FatalError', 'PBStateShutdown'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenDirectoryPrompt', 'PBStateDirectoryPrompt'),
            [SMTransition]::new('PBStateDirectoryPrompt', 'CloseDirectoryPrompt', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenSavePlaylistPrompt', 'PBStatePlaylistSavePrompt'),
            [SMTransition]::new('PBStatePlaylistSavePrompt', 'CloseSavePlaylistPrompt', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenEqualizer', 'PBStateEqualizer'),
            [SMTransition]::new('PBStateEqualizer', 'CloseEqualizer', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenThemeSelector', 'PBStateThemeSelector'),
            [SMTransition]::new('PBStateThemeSelector', 'CloseThemeSelector', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenNoticeModal', 'PBStateNoticeModal'),
            [SMTransition]::new('PBStateNoticeModal', 'CloseNoticeModal', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateMainPlayer', 'OpenVisualizer', 'PBStateVisualizer'),
            [SMTransition]::new('PBStateVisualizer', 'CloseVisualizer', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateVisualizer', 'VisualizerToNoticeModal', 'PBStateNoticeModal'),
            [SMTransition]::new('PBStateVisualizer', 'Quit', 'PBStateShutdown'),
            [SMTransition]::new('PBStateMainPlayer', 'Quit', 'PBStateShutdown'),
            [SMTransition]::new('PBStateMainPlayer', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateDirectoryPrompt', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStatePlaylistSavePrompt', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateEqualizer', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateThemeSelector', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateNoticeModal', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateVisualizer', 'BufferTooSmall', 'PBStateBufferTooSmall'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStateMainPlayer', 'PBStateMainPlayer'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStateDirectoryPrompt', 'PBStateDirectoryPrompt'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStatePlaylistSavePrompt', 'PBStatePlaylistSavePrompt'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStateEqualizer', 'PBStateEqualizer'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStateThemeSelector', 'PBStateThemeSelector'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStateNoticeModal', 'PBStateNoticeModal'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Resume_PBStateVisualizer', 'PBStateVisualizer'),
            [SMTransition]::new('PBStateBufferTooSmall', 'Quit', 'PBStateShutdown')
        ))
    }

    [String]GetCurrentPlayingPath() {
        If(($null -NE $this.MediaPlayer.CurrentTrack) -AND ($this.MediaPlayer.IsStopped() -EQ $false)) {
            Return $this.MediaPlayer.CurrentTrack.FullPath
        }

        Return ''
    }

    [Void]SyncAllPanelsFromState() {
        [String]$PlayingPath = $this.GetCurrentPlayingPath()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.DirectoryPanel.UpdatePlayingMarker($PlayingPath)
        $this.PlaylistPanel.UpdatePlayingIndex($this.Playlist.CurrentIndex)
    }

    [Void]SetFocusZone(
        [BoomboxFocusZone]$Zone,
        [Context]$Context
    ) {
        $this.PlaybackPanel.UnfocusAllElements($Context)
        $this.DirectoryPanel.UnfocusAllElements($Context)
        $this.PlaylistPanel.UnfocusAllElements($Context)

        $this.PlaybackPanel.SetFocusedBorderHighlight($false)
        $this.DirectoryPanel.SetFocusedBorderHighlight($false)
        $this.PlaylistPanel.SetFocusedBorderHighlight($false)

        $this.ActiveFocusZone = $Zone

        Switch($Zone) {
            ([BoomboxFocusZone]::DirectoryBrowser) {
                $this.DirectoryPanel.SetFocusedBorderHighlight($true)
                $this.DirectoryPanel.FocusFirst($Context)

                Break
            }

            ([BoomboxFocusZone]::Playlist) {
                $this.PlaylistPanel.SetFocusedBorderHighlight($true)
                $this.PlaylistPanel.FocusFirst($Context)

                Break
            }

            ([BoomboxFocusZone]::PlaybackControls) {
                $this.PlaybackPanel.SetFocusedBorderHighlight($true)
                $this.PlaybackPanel.FocusElementByKey(12, $Context)

                Break
            }
        }
    }

    [Void]CycleFocusZone(
        [Boolean]$Reverse,
        [Context]$Context
    ) {
        [BoomboxFocusZone]$NextZone = [BoomboxFocusZone]::DirectoryBrowser

        If($Reverse -EQ $false) {
            Switch($this.ActiveFocusZone) {
                ([BoomboxFocusZone]::DirectoryBrowser) {
                    $NextZone = [BoomboxFocusZone]::Playlist

                    Break
                }

                ([BoomboxFocusZone]::Playlist) {
                    $NextZone = [BoomboxFocusZone]::PlaybackControls

                    Break
                }

                Default {
                    $NextZone = [BoomboxFocusZone]::DirectoryBrowser

                    Break
                }
            }
        } Else {
            Switch($this.ActiveFocusZone) {
                ([BoomboxFocusZone]::DirectoryBrowser) {
                    $NextZone = [BoomboxFocusZone]::PlaybackControls

                    Break
                }

                ([BoomboxFocusZone]::PlaybackControls) {
                    $NextZone = [BoomboxFocusZone]::Playlist

                    Break
                }

                Default {
                    $NextZone = [BoomboxFocusZone]::DirectoryBrowser

                    Break
                }
            }
        }

        $this.SetFocusZone($NextZone, $Context)
    }

    [Void]PlayTrack(
        [MMTrackInfo]$Track
    ) {
        If($null -EQ $Track) {
            Return
        }

        If($this.MediaPlayer.LoadAndPlay($Track) -EQ $true) {
            $this.FooterPanel.SetStatus("Playing `"$($Track.DisplayName)`"")
            $this.NotificationService.NotifyTrackChange($Track)
        }

        $this.SyncAllPanelsFromState()
    }

    [Void]PlaySelectedPlaylistItem() {
        [Int]$SelectedIdx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If($SelectedIdx -LT 0) {
            Return
        }

        [MMTrackInfo]$Track = $this.Playlist.SelectIndex($SelectedIdx)

        If($null -NE $Track) {
            $this.PlayTrack($Track)
        }
    }

    [Void]TogglePlayPause() {
        If(($this.MediaPlayer.IsPlaying() -EQ $false) -AND ($this.MediaPlayer.IsPaused() -EQ $false)) {
            [MMTrackInfo]$TargetTrack = $this.Playlist.GetCurrentTrack()

            If(($null -EQ $TargetTrack) -AND ($this.Playlist.Tracks.Count -GT 0)) {
                $TargetTrack = $this.Playlist.SelectIndex(0)
            }

            If($null -NE $TargetTrack) {
                $this.PlayTrack($TargetTrack)
            } Else {
                $this.FooterPanel.SetStatus('Playlist is empty. Select a track first.')
            }

            Return
        }

        If($this.MediaPlayer.TogglePlayPause() -EQ $true) {
            [String]$Verb      = ($this.MediaPlayer.IsPlaying() -EQ $true) ? 'Resumed' : 'Paused'
            [String]$TrackName = ($null -NE $this.MediaPlayer.CurrentTrack) ? $this.MediaPlayer.CurrentTrack.DisplayName : 'track'

            $this.FooterPanel.SetStatus("$($Verb) `"$($TrackName)`"")
            $this.SyncAllPanelsFromState()
        }
    }

    [Void]StopPlayback() {
        $this.MediaPlayer.Stop()
        $this.NotificationService.DismissNotification()
        $this.FooterPanel.SetStatus('Playback stopped')
        $this.SyncAllPanelsFromState()
    }

    [Void]PlayNextTrack(
        [Boolean]$IsManual
    ) {
        [MMTrackInfo]$NextTrack = $this.Playlist.AdvanceNext($IsManual)

        If($null -NE $NextTrack) {
            $this.PlayTrack($NextTrack)
            $this.PlaylistPanel.PlaylistList.SelectIndex($this.Playlist.CurrentIndex)
        } Else {
            $this.StopPlayback()
            $this.FooterPanel.SetStatus('Reached end of playlist')
        }
    }

    [Void]PlayPreviousTrack() {
        [MMTrackInfo]$PrevTrack = $this.Playlist.AdvancePrevious()

        If($null -NE $PrevTrack) {
            $this.PlayTrack($PrevTrack)
            $this.PlaylistPanel.PlaylistList.SelectIndex($this.Playlist.CurrentIndex)
        } Else {
            $this.FooterPanel.SetStatus('Playlist is empty')
        }
    }

    [Void]HandleTrackEnded() {
        $this.PlayNextTrack($false)
    }

    [Void]SeekRelative(
        [Int]$DeltaMs
    ) {
        If($this.MediaPlayer.SeekRelative($DeltaMs) -EQ $true) {
            $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
            $this.FooterPanel.SetStatus("Seeked to $(Format-Duration $this.MediaPlayer.PositionMs)")
        }
    }

    [Void]SetVolume(
        [Int]$Percent
    ) {
        $this.MediaPlayer.SetVolume($Percent)
        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus("Volume: $($this.MediaPlayer.Volume.Value)%")
    }

    [Void]AdjustVolume(
        [Int]$Delta
    ) {
        $this.MediaPlayer.AdjustVolume($Delta)
        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus("Volume: $($this.MediaPlayer.Volume.Value)%")
    }

    [Void]SetMuted(
        [Boolean]$Muted
    ) {
        If($this.MediaPlayer.IsMuted -NE $Muted) {
            $null = $this.MediaPlayer.ToggleMute()
        }

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus(($this.MediaPlayer.IsMuted -EQ $true) ? 'Audio muted' : "Audio unmuted ($($this.MediaPlayer.Volume.Value)%)")
    }

    [Void]ToggleMute() {
        [Boolean]$Muted = $this.MediaPlayer.ToggleMute()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus(($Muted -EQ $true) ? 'Audio muted' : "Audio unmuted ($($this.MediaPlayer.Volume.Value)%)")
    }

    [Void]CycleRepeatMode() {
        [RepeatMode]$Mode = $this.Playlist.CycleRepeatMode()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus("Repeat mode: $($Mode)")
    }

    [Void]ToggleShuffle() {
        [Boolean]$Enabled = $this.Playlist.ToggleShuffle()

        $this.PlaybackPanel.SyncFromPlayer($this.MediaPlayer, $this.Playlist)
        $this.FooterPanel.SetStatus(($Enabled -EQ $true) ? 'Shuffle: On' : 'Shuffle: Off')
    }

    [Void]ToggleNotifications() {
        [Hashtable]$Result = $this.NotificationService.ToggleEnabled($this.GetCurrentPlayingPath())

        $this.FooterPanel.SetStatus($Result.Message)
    }

    [Void]ToggleEqualizer() {
        [Boolean]$Enabled = $this.EqualizerService.ToggleEnabled()

        $this.EqualizerModal.InlineStatusOverride = ''
        $this.EqualizerModal.SyncFromService($this.EqualizerService)
        $this.FooterPanel.SetStatus(($Enabled -EQ $true) ? "Equalizer: On ($($this.EqualizerService.ActivePresetName))" : 'Equalizer: Off')
    }

    [Void]CycleEqualizerPreset(
        [Int]$Direction
    ) {
        [String]$NewPreset = $this.EqualizerService.CyclePreset($Direction)

        $this.EqualizerModal.InlineStatusOverride = ''
        $this.EqualizerModal.SyncFromService($this.EqualizerService)
        $this.FooterPanel.SetStatus("Equalizer preset: $($NewPreset)")
    }

    [Void]SetEqualizerPreamp(
        [Int]$GainDb
    ) {
        $this.EqualizerService.SetPreampDb($GainDb)

        $this.EqualizerModal.InlineStatusOverride = ''
        $this.EqualizerModal.SyncFromService($this.EqualizerService)
        $this.FooterPanel.SetStatus("Equalizer Preamp: $($this.EqualizerService.PreampDb) dB (Custom)")
    }

    [Void]SetEqualizerBand(
        [Int]$BandIndex,
        [Int]$GainDb
    ) {
        $this.EqualizerService.SetBandGainDb($BandIndex, $GainDb)

        [String]$Label = [MMEqualizerService]::BandLabels[$BandIndex]

        $this.EqualizerModal.InlineStatusOverride = ''
        $this.EqualizerModal.SyncFromService($this.EqualizerService)
        $this.FooterPanel.SetStatus("Equalizer $($Label) Hz: $($this.EqualizerService.BandGainsDb[$BandIndex]) dB (Custom)")
    }

    [Hashtable]SaveEqualizerUserPreset(
        [String]$PresetName
    ) {
        [Hashtable]$SaveResult = $this.EqualizerService.SaveUserPreset($PresetName)

        If($SaveResult.Success -EQ $true) {
            $this.FooterPanel.SetStatus($SaveResult.Message)
        } Else {
            $this.FooterPanel.SetError($SaveResult.Message)
        }

        Return $SaveResult
    }

    [Void]DeleteActiveEqualizerPreset() {
        [Hashtable]$DelResult = $this.EqualizerService.DeleteUserPreset($this.EqualizerService.ActivePresetName)

        If($DelResult.Success -EQ $true) {
            $this.EqualizerModal.SetInlineStatus($DelResult.Message, $false)
            $this.EqualizerModal.SyncFromService($this.EqualizerService)
            $this.FooterPanel.SetStatus($DelResult.Message)
        } Else {
            $this.EqualizerModal.SetInlineStatus($DelResult.Message, $true)
            $this.FooterPanel.SetStatus($DelResult.Message)
        }
    }

    [Void]ResetEqualizerFlat() {
        $this.EqualizerService.ResetToFlat()

        $this.EqualizerModal.InlineStatusOverride = ''
        $this.EqualizerModal.SyncFromService($this.EqualizerService)
        $this.FooterPanel.SetStatus('Equalizer reset to Flat')
    }

    [Void]ActivateSelectedDirectoryEntry() {
        [MMDirectoryEntry]$Entry = $this.DirectoryPanel.GetSelectedEntry()

        If($null -EQ $Entry) {
            Return
        }

        Switch($Entry.EntryType) {
            ([DirectoryEntryType]::ParentDirectory) {
                $this.NavigateDirectory($Entry.FullPath)

                Break
            }

            ([DirectoryEntryType]::Directory) {
                $this.NavigateDirectory($Entry.FullPath)

                Break
            }

            ([DirectoryEntryType]::PlaylistFile) {
                $this.LoadPlaylistFile($Entry.FullPath)

                Break
            }

            Default {
                [MMTrackInfo]$Track = [MMTrackInfo]::new($Entry.FullPath)
                [Int]$ExistingIdx  = $this.Playlist.FindTrackIndexByPath($Track.FullPath)

                If($ExistingIdx -GE 0) {
                    $null = $this.Playlist.SelectIndex($ExistingIdx)
                } Else {
                    $this.Playlist.AddTrack($Track)
                    $null = $this.Playlist.SelectIndex($this.Playlist.Tracks.Count - 1)
                }

                $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $this.Playlist.CurrentIndex)
                $this.PlayTrack($Track)

                Break
            }
        }
    }

    [Void]NavigateDirectory(
        [String]$TargetPath
    ) {
        If($this.DirectoryService.LoadDirectory($TargetPath) -EQ $true) {
            $this.DirectoryPanel.SyncFromService($this.DirectoryService, $this.GetCurrentPlayingPath())
            $this.FooterPanel.SetStatus("Directory: $($this.DirectoryService.CurrentPath)")
        } Else {
            $this.FooterPanel.SetError($this.DirectoryService.LastError)
        }
    }

    [Void]NavigateDirectoryUp() {
        If($this.DirectoryService.NavigateUp() -EQ $true) {
            $this.DirectoryPanel.SyncFromService($this.DirectoryService, $this.GetCurrentPlayingPath())
            $this.FooterPanel.SetStatus("Directory: $($this.DirectoryService.CurrentPath)")
        } Else {
            $this.FooterPanel.SetError($this.DirectoryService.LastError)
        }
    }

    [Void]AddSelectedDirectoryTrackToPlaylist() {
        [MMDirectoryEntry]$Entry = $this.DirectoryPanel.GetSelectedEntry()

        If($null -EQ $Entry) {
            $this.FooterPanel.SetStatus('Select an audio file or directory to add to the playlist.')

            Return
        }

        If($Entry.EntryType -EQ [DirectoryEntryType]::Directory) {
            [List[MMTrackInfo]]$SubDirTracks = $this.DirectoryService.GetMediaTracksInDirectory($Entry.FullPath)

            If($this.DirectoryService.LastError.Length -GT 0) {
                $this.FooterPanel.SetError($this.DirectoryService.LastError)

                Return
            }

            If($SubDirTracks.Count -EQ 0) {
                $this.FooterPanel.SetStatus("No supported media files in `"$($Entry.Name)`".")

                Return
            }

            $this.Playlist.AddTracks($SubDirTracks)
            $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, ($this.Playlist.Tracks.Count - 1))

            [String]$TrackWord = ($SubDirTracks.Count -EQ 1) ? 'track' : 'tracks'

            $this.FooterPanel.SetStatus("Added $($SubDirTracks.Count) $($TrackWord) from `"$($Entry.Name)`"")

            Return
        }

        If($Entry.EntryType -NE [DirectoryEntryType]::MediaFile) {
            $this.FooterPanel.SetStatus('Select an audio file or directory to add to the playlist.')

            Return
        }

        [MMTrackInfo]$Track = [MMTrackInfo]::new($Entry.FullPath)
        $this.Playlist.AddTrack($Track)
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, ($this.Playlist.Tracks.Count - 1))
        $this.FooterPanel.SetStatus("Added `"$($Track.DisplayName)`" to playlist")
    }

    [Void]LoadPlaylistFile(
        [String]$PlaylistPath
    ) {
        [Hashtable]$LoadResult = [MMPlaylistFileService]::LoadPlaylist($PlaylistPath)

        If($LoadResult.Success -EQ $false) {
            $this.FooterPanel.SetError($LoadResult.ErrorMessage)

            Return
        }

        $this.Playlist.LoadTracks($LoadResult.Tracks, $LoadResult.PlaylistName, $LoadResult.SourcePath)
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, 0)
        $this.SyncAllPanelsFromState()

        [String]$StatusMsg = "Loaded '$($LoadResult.PlaylistName)' ($($LoadResult.Tracks.Count) tracks)"

        If($LoadResult.SkippedCount -GT 0) {
            $StatusMsg += ", skipped $($LoadResult.SkippedCount) missing"
        }

        $this.FooterPanel.SetStatus($StatusMsg)
    }

    [Void]RemoveSelectedPlaylistTrack() {
        [Int]$Idx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If($Idx -LT 0) {
            Return
        }

        [Boolean]$WasPlaying = ($Idx -EQ $this.Playlist.CurrentIndex)
        [String]$RemovedName = $this.Playlist.Tracks[$Idx].DisplayName

        If($this.Playlist.RemoveAt($Idx) -EQ $true) {
            If($WasPlaying -EQ $true) {
                $this.MediaPlayer.Stop()
                $this.NotificationService.DismissNotification()
            }

            [Int]$NextSelection = [Math]::Min($Idx, ($this.Playlist.Tracks.Count - 1))

            $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $NextSelection)
            $this.SyncAllPanelsFromState()
            $this.FooterPanel.SetStatus("Removed `"$($RemovedName)`"")
        }
    }

    [Void]MoveSelectedPlaylistTrackUp() {
        [Int]$Idx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If($Idx -LE 0) {
            Return
        }

        [Int]$NewIdx = $this.Playlist.MoveUp($Idx)

        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $NewIdx)
        $this.FooterPanel.SetStatus('Moved track up')
    }

    [Void]MoveSelectedPlaylistTrackDown() {
        [Int]$Idx = $this.PlaylistPanel.GetSelectedTrackIndex()

        If(($Idx -LT 0) -OR ($Idx -GE ($this.Playlist.Tracks.Count - 1))) {
            Return
        }

        [Int]$NewIdx = $this.Playlist.MoveDown($Idx)

        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, $NewIdx)
        $this.FooterPanel.SetStatus('Moved track down')
    }

    [Void]ClearPlaylist() {
        $this.MediaPlayer.Stop()
        $this.NotificationService.DismissNotification()
        $this.Playlist.Clear()
        $this.PlaylistPanel.SyncFromPlaylist($this.Playlist, -1)
        $this.SyncAllPanelsFromState()
        $this.FooterPanel.SetStatus('Cleared playlist')
    }

    [UIVisualizerBase]GetActiveVisualizer() {
        If(($this.Visualizers.Count -EQ 0) -OR ($this.ActiveVisualizerIndex -LT 0) -OR ($this.ActiveVisualizerIndex -GE $this.Visualizers.Count)) {
            Return $null
        }

        Return $this.Visualizers[$this.ActiveVisualizerIndex]
    }

    [Void]CycleVisualizerForward() {
        If($this.Visualizers.Count -EQ 0) {
            Return
        }

        $this.ActiveVisualizerIndex = ($this.ActiveVisualizerIndex + 1) % $this.Visualizers.Count

        $this.VisualizerCanvas.InvalidateAll()

        [UIVisualizerBase]$ActiveViz = $this.GetActiveVisualizer()

        If($null -NE $ActiveViz) {
            $ActiveViz.Reset()
        }
    }

    [Void]SyncVisualizerTrackLabel() {
        [MMTrackInfo]$Track = $this.MediaPlayer.CurrentTrack
        [String]$TrackTitle = ($null -NE $Track) ? $Track.DisplayName : ''

        If($this.VisualizerTrackLabel.UserData.TrimEnd() -NE (Format-TruncatedText $TrackTitle $this.VisualizerTrackLabel.MaxWidth)) {
            $this.VisualizerTrackLabel.SetText($TrackTitle)
        }
    }

    [Void]OpenMidiVisualizerNotice(
        [Context]$Context,
        [String]$TransitionName
    ) {
        $this.NoticeModal.Configure(
            'Visualizer Unavailable',
            @(
                'Visualizer Mode cannot be used during MIDI playback.',
                'MIDI files are synthesized via Windows MCI and do not',
                'produce decodable PCM audio buffers.'
            ),
            'OK'
        )
        $this.AppState.Trigger($TransitionName, $Context)
    }

    [Void]TryOpenVisualizer(
        [Context]$Context
    ) {
        If($this.MediaPlayer.IsPlaying() -EQ $false) {
            $this.FooterPanel.SetStatus('Start playing an audio track to enter Visualizer Mode.')

            Return
        }

        If($this.MediaPlayer.IsEqualizerBypassedForCurrentTrack() -EQ $true) {
            $this.OpenMidiVisualizerNotice($Context, 'OpenNoticeModal')

            Return
        }

        $this.AppState.Trigger('OpenVisualizer', $Context)
    }

    [Void]Cleanup() {
        If($null -NE $this.NotificationService) {
            $this.NotificationService.Dispose()
        }

        If($null -NE $this.MediaPlayer) {
            $this.MediaPlayer.Dispose()
        }

        ([AppCore]$this).Cleanup()
    }
}
