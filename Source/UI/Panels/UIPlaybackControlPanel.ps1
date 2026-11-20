using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# UI PLAYBACK CONTROL PANEL
#
# TOP FULL-WIDTH PANEL HOUSING NOW-PLAYING METADATA, STATUS BADGE, ACTIVITY
# SPINNER, TRACK PROGRESS SCRUBBER, TRANSPORT BUTTONS, AND VOLUME CONTROL.
#
###############################################################################

Class UIPlaybackControlPanel : UIPanel {
    [UILabel]$TrackPrefixLabel
    [UILabel]$TrackValueLabel
    [UILabel]$EqBadgeLabel
    [UILabel]$StatusBadgeLabel
    [UICellSpinner]$Spinner
    [UILabel]$TimePrefixLabel
    [UITrackProgressBar]$Scrubber
    [UIButton]$PrevButton
    [UIButton]$PlayPauseButton
    [UIButton]$StopButton
    [UIButton]$NextButton
    [UIButton]$RepeatButton
    [UIButton]$ShuffleButton
    [UIVolumeControl]$VolumeControl
    [ScriptBlock]$OnPrevClicked
    [ScriptBlock]$OnPlayPauseClicked
    [ScriptBlock]$OnStopClicked
    [ScriptBlock]$OnNextClicked
    [ScriptBlock]$OnRepeatClicked
    [ScriptBlock]$OnShuffleClicked

    UIPlaybackControlPanel(
        [Int]$LayoutWidth
    ) : base() {
        [Int]$SafeWidth = [Math]::Max(80, $LayoutWidth)

        $this.LeftTop     = [ATCoordinates]::new(1, 1)
        $this.RightBottom = [ATCoordinates]::new(5, $SafeWidth)

        $this.UpdateDimensions()
        $this.SetupTitle('PSBoombox', [ColorLibrary]::TextActiveColor)

        [UIPlaybackControlPanel]$SelfPanel = $this

        $this.TrackPrefixLabel = [UILabel]::new('Track : ', [ATCoordinates]::new(2, 3), [ColorLibrary]::TextColor)
        $this.TrackValueLabel  = [UILabel]::new('(No track loaded)', [ATCoordinates]::new(2, 11), [ColorLibrary]::BoomboxMediaFileEntry, ($SafeWidth - 39))
        $this.EqBadgeLabel     = [UILabel]::new('     [EQ:Off]', [ATCoordinates]::new(2, ($SafeWidth - 27)), [ColorLibrary]::BoomboxEqInactive, 13)
        $this.StatusBadgeLabel = [UILabel]::new('[STOPPED]', [ATCoordinates]::new(2, ($SafeWidth - 13)), [ColorLibrary]::BoomboxStatusStopped, 9)
        $this.Spinner          = [UICellSpinner]::new([ATCoordinates]::new(2, ($SafeWidth - 2)), 10, [ColorLibrary]::BoomboxSpinnerActive)
        $this.TimePrefixLabel  = [UILabel]::new('Time  : ', [ATCoordinates]::new(3, 3), [ColorLibrary]::TextColor)

        [Int]$ScrubberWidth = [Math]::Max(12, ($SafeWidth - 28))
        $this.Scrubber      = [UITrackProgressBar]::new([ATCoordinates]::new(3, 11), $ScrubberWidth)

        $this.PrevButton = [UIButton]::new('|<', [ATCoordinates]::new(4, 3), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfPanel.OnPrevClicked) {
                $SelfPanel.OnPrevClicked.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.PlayPauseButton = [UIButton]::new('> Play', [ATCoordinates]::new(4, 10), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfPanel.OnPlayPauseClicked) {
                $SelfPanel.OnPlayPauseClicked.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.StopButton = [UIButton]::new('Stop', [ATCoordinates]::new(4, 21), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfPanel.OnStopClicked) {
                $SelfPanel.OnStopClicked.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.NextButton = [UIButton]::new('>|', [ATCoordinates]::new(4, 30), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfPanel.OnNextClicked) {
                $SelfPanel.OnNextClicked.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.RepeatButton = [UIButton]::new('Rpt:Off', [ATCoordinates]::new(4, 37), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfPanel.OnRepeatClicked) {
                $SelfPanel.OnRepeatClicked.Invoke($ActionContext)
            }
        }.GetNewClosure())

        $this.ShuffleButton = [UIButton]::new('Shf:Off', [ATCoordinates]::new(4, 49), {
            Param(
                [Context]$ActionContext
            )

            If($null -NE $SelfPanel.OnShuffleClicked) {
                $SelfPanel.OnShuffleClicked.Invoke($ActionContext)
            }
        }.GetNewClosure())

        [Int]$VolBarWidth   = ($SafeWidth -GE 92) ? 10 : 6
        [Int]$VolCol        = [Math]::Max(61, ($SafeWidth - ($VolBarWidth + 11)))
        $this.VolumeControl = [UIVolumeControl]::new([ATCoordinates]::new(4, $VolCol), 70, 5, $VolBarWidth)

        $this.UiElementListing[0]  = $this.TrackPrefixLabel
        $this.UiElementListing[1]  = $this.TrackValueLabel
        $this.UiElementListing[2]  = $this.EqBadgeLabel
        $this.UiElementListing[3]  = $this.StatusBadgeLabel
        $this.UiElementListing[4]  = $this.Spinner
        $this.UiElementListing[5]  = $this.TimePrefixLabel
        $this.UiElementListing[10] = $this.Scrubber
        $this.UiElementListing[11] = $this.PrevButton
        $this.UiElementListing[12] = $this.PlayPauseButton
        $this.UiElementListing[13] = $this.StopButton
        $this.UiElementListing[14] = $this.NextButton
        $this.UiElementListing[15] = $this.RepeatButton
        $this.UiElementListing[16] = $this.ShuffleButton
        $this.UiElementListing[17] = $this.VolumeControl
    }

    [Boolean]HandleZoneNavigationKey(
        [ConsoleKeyInfo]$KeyInfo,
        [Context]$Context
    ) {
        [Int]$KeyIndex = $this.ActiveIndex

        If($KeyIndex -EQ 10) {
            If($KeyInfo.Key -EQ [ConsoleKey]::DownArrow) {
                $this.FocusElementByKey(12, $Context)

                Return $true
            }

            Return $false
        }

        If(($KeyIndex -GE 11) -AND ($KeyIndex -LE 17)) {
            If($KeyInfo.Key -EQ [ConsoleKey]::LeftArrow) {
                [Int]$PrevKey = ($KeyIndex -EQ 11) ? 17 : ($KeyIndex - 1)
                $this.FocusElementByKey($PrevKey, $Context)

                Return $true
            }

            If($KeyInfo.Key -EQ [ConsoleKey]::RightArrow) {
                [Int]$NextKey = ($KeyIndex -EQ 17) ? 11 : ($KeyIndex + 1)
                $this.FocusElementByKey($NextKey, $Context)

                Return $true
            }

            If(($KeyInfo.Key -EQ [ConsoleKey]::UpArrow) -AND ($KeyIndex -NE 17)) {
                $this.FocusElementByKey(10, $Context)

                Return $true
            }
        }

        Return $false
    }

    [Void]SyncFromPlayer(
        [MMMediaPlayer]$Player,
        [MMPlaylist]$Playlist
    ) {
        If($null -EQ $Player) {
            Return
        }

        [MMTrackInfo]$Track = $Player.CurrentTrack
        [String]$TrackTitle = ($null -NE $Track) ? $Track.DisplayName : '(No track loaded)'

        If($this.TrackValueLabel.UserData.TrimEnd() -NE (Format-TruncatedText $TrackTitle $this.TrackValueLabel.MaxWidth)) {
            $this.TrackValueLabel.SetText($TrackTitle)
        }

        [PlaybackState]$State     = $Player.GetPlaybackState()
        [String]$BadgeText       = '[STOPPED]'
        [TrueColor]$BadgeColor   = [ColorLibrary]::BoomboxStatusStopped
        [String]$PlayBtnText     = '> Play'
        [Boolean]$ShouldSpin     = $false

        Switch($State) {
            ([PlaybackState]::Playing) {
                $BadgeText   = '[PLAYING]'
                $BadgeColor  = [ColorLibrary]::BoomboxStatusPlaying
                $PlayBtnText = '|| Pse'
                $ShouldSpin  = $true

                Break
            }

            ([PlaybackState]::Paused) {
                $BadgeText   = '[PAUSED] '
                $BadgeColor  = [ColorLibrary]::BoomboxStatusPaused
                $PlayBtnText = '> Play'

                Break
            }

            ([PlaybackState]::Loading) {
                $BadgeText   = '[LOADING]'
                $BadgeColor  = [ColorLibrary]::BoomboxStatusPaused
                $PlayBtnText = '> Play'

                Break
            }

            ([PlaybackState]::Error) {
                $BadgeText   = '[ERROR]  '
                $BadgeColor  = [ColorLibrary]::BoomboxStatusError
                $PlayBtnText = '> Play'

                Break
            }

            Default {
                $BadgeText   = '[STOPPED]'
                $BadgeColor  = [ColorLibrary]::BoomboxStatusStopped
                $PlayBtnText = '> Play'

                Break
            }
        }

        If($this.StatusBadgeLabel.UserData -NE $BadgeText) {
            $this.StatusBadgeLabel.SetText($BadgeText)
        }

        If([Object]::ReferenceEquals($this.StatusBadgeLabel.ActiveColor, $BadgeColor) -EQ $false) {
            $this.StatusBadgeLabel.SetActiveColor($BadgeColor)
        }

        $this.Spinner.SetSpinning($ShouldSpin)
        $this.PlayPauseButton.SetLabel($PlayBtnText)
        $this.Scrubber.SetProgress($Player.PositionMs, $Player.DurationMs)
        $this.VolumeControl.SyncFromState($Player.Volume.Value, $Player.IsMuted)

        [MMEqualizerService]$EqSvc = $Player.EqualizerService
        [String]$RawEqBadge        = '[EQ:Off]'
        [TrueColor]$EqColor        = [ColorLibrary]::BoomboxEqInactive

        If(($null -NE $EqSvc) -AND ($EqSvc.Enabled -EQ $true)) {
            If($Player.IsEqualizerBypassedForCurrentTrack() -EQ $true) {
                $RawEqBadge = '[EQ:MIDI]'
                $EqColor    = [ColorLibrary]::BoomboxEqBypassed
            } Else {
                [String]$ShortPreset = Format-TruncatedText $EqSvc.ActivePresetName 8
                $RawEqBadge          = "[EQ:$($ShortPreset)]"
                $EqColor             = [ColorLibrary]::BoomboxEqActive
            }
        }

        [String]$PaddedEqBadge = $RawEqBadge.PadLeft(13, ' ')

        If($this.EqBadgeLabel.UserData -NE $PaddedEqBadge) {
            $this.EqBadgeLabel.SetText($PaddedEqBadge)
        }

        If([Object]::ReferenceEquals($this.EqBadgeLabel.ActiveColor, $EqColor) -EQ $false) {
            $this.EqBadgeLabel.SetActiveColor($EqColor)
        }

        If($null -NE $Playlist) {
            [String]$RepeatLabel = 'Rpt:Off'

            Switch($Playlist.RepeatMode) {
                ([RepeatMode]::Playlist) {
                    $RepeatLabel = 'Rpt:All'

                    Break
                }

                ([RepeatMode]::Track) {
                    $RepeatLabel = 'Rpt:One'

                    Break
                }

                Default {
                    $RepeatLabel = 'Rpt:Off'

                    Break
                }
            }

            [String]$ShuffleLabel = ($Playlist.ShuffleEnabled -EQ $true) ? 'Shf:On' : 'Shf:Off'

            $this.RepeatButton.SetLabel($RepeatLabel)
            $this.ShuffleButton.SetLabel($ShuffleLabel)
        }
    }
}
