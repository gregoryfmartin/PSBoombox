using namespace System
using namespace System.Collections.Generic

Set-StrictMode -Version Latest





###############################################################################
#
# PB STATE BUFFER TOO SMALL
#
# WARNING OVERLAY STATE ENTERED WHEN THE CONSOLE VIEWPORT IS SMALLER THAN THE
# MINIMUM REQUIRED DIMENSIONS, KEEPING PLAYBACK AND GLOBAL HOTKEYS ACTIVE.
#
###############################################################################

Class PBStateBufferTooSmall : SMState {
    [Int]$LastDrawnWidth
    [Int]$LastDrawnHeight
    [Boolean]$NeedsRedraw

    PBStateBufferTooSmall() : base('PBStateBufferTooSmall') {
        $this.LastDrawnWidth  = -1
        $this.LastDrawnHeight = -1
        $this.NeedsRedraw     = $true

        $this.OnEnter = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [PBStateBufferTooSmall]$SelfState = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                   = $Context.References[[SMState]::ContextBoomboxCore]

            $Core.EnterAlternateScreen()

            $SelfState.LastDrawnWidth  = -1
            $SelfState.LastDrawnHeight = -1
            $SelfState.NeedsRedraw     = $true
            $Core.PendingScreenClear   = $true
        }

        $this.OnExit = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context
        }

        $this.OnUpdate = {
            Param(
                [Context]$Context
            )

            Confirm-Context $Context

            [PBStateBufferTooSmall]$SelfState  = $Context.References[[SMState]::ContextSelfState]
            [AppCore]$Core                     = $Context.References[[SMState]::ContextBoomboxCore]
            [Double]$DeltaTime                 = $Context.References[[SMState]::ContextDeltaTime]
            [List[ConsoleKeyInfo]]$KeysPressed = $Context.References[[SMState]::ContextKeysPressed]

            If($null -NE $KeysPressed) {
                Foreach($KeyInfo in $KeysPressed) {
                    If($KeyInfo.Key -EQ [ConsoleKey]::Q) {
                        $Core.IsSuspendedForResize = $false
                        $Core.AppState.Trigger('Quit', $Context)

                        Return
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::Spacebar) {
                        $Core.TogglePlayPause()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::N) {
                        $Core.PlayNextTrack($true)

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::P) {
                        $Core.PlayPreviousTrack()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::S) {
                        $Core.StopPlayback()

                        Continue
                    }

                    If(($KeyInfo.Key -EQ [ConsoleKey]::Add) -OR ($KeyInfo.Key -EQ [ConsoleKey]::OemPlus)) {
                        $Core.AdjustVolume(5)

                        Continue
                    }

                    If(($KeyInfo.Key -EQ [ConsoleKey]::Subtract) -OR ($KeyInfo.Key -EQ [ConsoleKey]::OemMinus)) {
                        $Core.AdjustVolume(-5)

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::M) {
                        $Core.ToggleMute()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::R) {
                        $Core.CycleRepeatMode()

                        Continue
                    }

                    If($KeyInfo.Key -EQ [ConsoleKey]::H) {
                        $Core.ToggleShuffle()

                        Continue
                    }
                }
            }

            $Core.MediaPlayer.Update($DeltaTime)

            If(($SelfState.NeedsRedraw -EQ $true) -OR ($SelfState.LastDrawnWidth -NE $Core.LastViewportWidth) -OR ($SelfState.LastDrawnHeight -NE $Core.LastViewportHeight)) {
                [Int]$MinW          = $Core.BufferSpec.BufferMinWidth.Value
                [Int]$MinH          = $Core.BufferSpec.BufferMinHeight.Value
                [String]$WarningAnsi = $SelfState.BuildWarningAnsi($Core.LastViewportWidth, $Core.LastViewportHeight, $MinW, $MinH)

                Write-Host "$([ATControlSequences]::DrawOptimizeOn)" -NoNewline

                If([Console]::IsOutputRedirected -EQ $false) {
                    Write-Host "$([ATControlSequences]::GenerateThemeClearScreenString())" -NoNewline
                }

                If($WarningAnsi.Length -GT 0) {
                    Write-Host $WarningAnsi -NoNewline
                }

                Write-Host "$([ATControlSequences]::DrawOptimizeOff)" -NoNewline

                $SelfState.LastDrawnWidth  = $Core.LastViewportWidth
                $SelfState.LastDrawnHeight = $Core.LastViewportHeight
                $SelfState.NeedsRedraw     = $false
                $Core.PendingScreenClear   = $false
            }
        }
    }

    [String]CreatePositionedText(
        [Int]$Row,
        [Int]$Col,
        [String]$Text,
        [TrueColor]$Color,
        [Int]$ViewportWidth,
        [Int]$ViewportHeight
    ) {
        If(($Row -LT 1) -OR ($Row -GT $ViewportHeight) -OR ($Col -LT 1) -OR ($Col -GT $ViewportWidth) -OR ($null -EQ $Text) -OR ($Text.Length -EQ 0)) {
            Return ''
        }

        [Int]$MaxChars = ($Row -EQ $ViewportHeight) ? [Math]::Max(0, ($ViewportWidth - $Col)) : [Math]::Max(0, ($ViewportWidth - $Col + 1))

        If($MaxChars -LE 0) {
            Return ''
        }

        [String]$SafeText = ($Text.Length -GT $MaxChars) ? $Text.Substring(0, $MaxChars) : $Text
        [ATString]$Segment = [ATString]@{
            Prefix = [ATStringPrefix]@{
                ForegroundColor = [ATForegroundColor24]::new($Color)
                Coordinates     = [ATCoordinates]::new($Row, $Col)
            }
            UserData   = "$($SafeText)"
            UseATReset = $true
        }

        Return "$($Segment.ToAnsiControlSequenceString())"
    }

    [String]BuildWarningAnsi(
        [Int]$ViewportWidth,
        [Int]$ViewportHeight,
        [Int]$MinWidth,
        [Int]$MinHeight
    ) {
        If(($ViewportWidth -LE 0) -OR ($ViewportHeight -LE 0)) {
            Return ''
        }

        [String]$Output = ''

        # TIER 1: CENTERED BOXED WARNING
        If(($ViewportWidth -GE 38) -AND ($ViewportHeight -GE 9)) {
            [Int]$BoxWidth  = [Math]::Min(54, ($ViewportWidth - 2))
            [Int]$BoxHeight = 9
            [Int]$TopRow    = [Math]::Clamp(([Int][Math]::Floor(($ViewportHeight - $BoxHeight) / 2) + 1), 1, ($ViewportHeight - $BoxHeight + 1))
            [Int]$LeftCol   = [Math]::Clamp(([Int][Math]::Floor(($ViewportWidth - $BoxWidth) / 2) + 1), 1, ($ViewportWidth - $BoxWidth + 1))

            If((($TopRow + $BoxHeight - 1) -EQ $ViewportHeight) -AND (($LeftCol + $BoxWidth - 1) -EQ $ViewportWidth)) {
                $BoxWidth--
            }

            [Int]$BottomRow  = $TopRow + $BoxHeight - 1
            [Int]$RightCol   = $LeftCol + $BoxWidth - 1
            [Int]$DashCount  = [Math]::Max(1, ($BoxWidth - 2))
            [Int]$InnerWidth = [Math]::Max(1, ($BoxWidth - 4))
            [String]$HBar    = [String][UIContainer]::WindowDesignRounded[[WindowBorderPart]::Top]
            [String]$VBar    = [String][UIContainer]::WindowDesignRounded[[WindowBorderPart]::Left]
            [String]$TopLine = "$([UIContainer]::WindowDesignRounded[[WindowBorderPart]::LeftTop])$($HBar * $DashCount)$([UIContainer]::WindowDesignRounded[[WindowBorderPart]::RightTop])"
            [String]$BotLine = "$([UIContainer]::WindowDesignRounded[[WindowBorderPart]::LeftBottom])$($HBar * $DashCount)$([UIContainer]::WindowDesignRounded[[WindowBorderPart]::RightBottom])"

            $Output += $this.CreatePositionedText($TopRow, $LeftCol, $TopLine, [ColorLibrary]::BoomboxWarningBorder, $ViewportWidth, $ViewportHeight)

            [String]$TitleText = Format-TruncatedText ' Terminal Too Small ' ([Math]::Max(1, ($BoxWidth - 4)))
            $Output           += $this.CreatePositionedText($TopRow, ($LeftCol + 2), $TitleText, [ColorLibrary]::BoomboxWarningTitle, $ViewportWidth, $ViewportHeight)

            For([Int]$RowIdx = ($TopRow + 1); $RowIdx -LT $BottomRow; $RowIdx++) {
                $Output += $this.CreatePositionedText($RowIdx, $LeftCol, $VBar, [ColorLibrary]::BoomboxWarningBorder, $ViewportWidth, $ViewportHeight)
                $Output += $this.CreatePositionedText($RowIdx, $RightCol, $VBar, [ColorLibrary]::BoomboxWarningBorder, $ViewportWidth, $ViewportHeight)
            }

            $Output += $this.CreatePositionedText($BottomRow, $LeftCol, $BotLine, [ColorLibrary]::BoomboxWarningBorder, $ViewportWidth, $ViewportHeight)

            [Int]$ContentCol     = $LeftCol + 2
            [Int]$MaxContentCol  = $RightCol - 2
            [String]$PromptLine  = Format-TruncatedText 'Resize window or pane to continue.' $InnerWidth
            [String]$MinLine     = Format-TruncatedText "Minimum : $($MinWidth) x $($MinHeight)" $InnerWidth
            [String]$HintLine    = Format-TruncatedText 'Playback active | [Spc] [N/P] [+/-] [M] [Q] Quit' $InnerWidth

            $Output += $this.CreatePositionedText(($TopRow + 2), $ContentCol, $PromptLine, [ColorLibrary]::BoomboxWarningText, $ViewportWidth, $ViewportHeight)

            [String]$PrefixCur = 'Current : '
            [String]$WidthStr  = "$($ViewportWidth)"
            [String]$SepStr    = ' x '
            [String]$HeightStr = "$($ViewportHeight)"
            [TrueColor]$WColor = ($ViewportWidth -LT $MinWidth) ? [ColorLibrary]::BoomboxWarningDimBad : [ColorLibrary]::BoomboxWarningDimOk
            [TrueColor]$HColor = ($ViewportHeight -LT $MinHeight) ? [ColorLibrary]::BoomboxWarningDimBad : [ColorLibrary]::BoomboxWarningDimOk
            [Int]$CurCol       = $ContentCol
            [Int]$BoxMaxWidth  = $MaxContentCol + 1

            If(($PrefixCur.Length + $WidthStr.Length + $SepStr.Length + $HeightStr.Length) -LE $InnerWidth) {
                $Output += $this.CreatePositionedText(($TopRow + 4), $CurCol, $PrefixCur, [ColorLibrary]::BoomboxWarningText, $BoxMaxWidth, $ViewportHeight)
                $CurCol += $PrefixCur.Length
                $Output += $this.CreatePositionedText(($TopRow + 4), $CurCol, $WidthStr, $WColor, $BoxMaxWidth, $ViewportHeight)
                $CurCol += $WidthStr.Length
                $Output += $this.CreatePositionedText(($TopRow + 4), $CurCol, $SepStr, [ColorLibrary]::BoomboxWarningText, $BoxMaxWidth, $ViewportHeight)
                $CurCol += $SepStr.Length
                $Output += $this.CreatePositionedText(($TopRow + 4), $CurCol, $HeightStr, $HColor, $BoxMaxWidth, $ViewportHeight)
            } Else {
                [String]$CurFallback = Format-TruncatedText "$($PrefixCur)$($WidthStr)$($SepStr)$($HeightStr)" $InnerWidth
                $Output             += $this.CreatePositionedText(($TopRow + 4), $ContentCol, $CurFallback, [ColorLibrary]::BoomboxWarningDimBad, $ViewportWidth, $ViewportHeight)
            }

            $Output += $this.CreatePositionedText(($TopRow + 5), $ContentCol, $MinLine, [ColorLibrary]::BoomboxWarningText, $ViewportWidth, $ViewportHeight)
            $Output += $this.CreatePositionedText(($TopRow + 7), $ContentCol, $HintLine, [ColorLibrary]::BoomboxFooterHint, $ViewportWidth, $ViewportHeight)

            Return $Output
        }

        # TIER 2: COMPACT BORDERLESS WARNING
        If(($ViewportWidth -GE 14) -AND ($ViewportHeight -GE 3)) {
            [Int]$SafeMaxCols     = [Math]::Max(1, ($ViewportWidth - 1))
            [List[String]]$Texts  = [List[String]]::new()
            [List[TrueColor]]$Clrs = [List[TrueColor]]::new()

            $Texts.Add((Format-TruncatedText 'Window Too Small' $SafeMaxCols))
            $Clrs.Add([ColorLibrary]::BoomboxWarningTitle)

            $Texts.Add((Format-TruncatedText "$($ViewportWidth)x$($ViewportHeight) < $($MinWidth)x$($MinHeight)" $SafeMaxCols))
            $Clrs.Add([ColorLibrary]::BoomboxWarningDimBad)

            $Texts.Add((Format-TruncatedText 'Resize or [Q] Quit' $SafeMaxCols))
            $Clrs.Add([ColorLibrary]::BoomboxFooterHint)

            If($ViewportHeight -GE 5) {
                $Texts.Add((Format-TruncatedText '[Spc] Play [N/P] [+/-] [M]' $SafeMaxCols))
                $Clrs.Add([ColorLibrary]::BoomboxFooterHint)
            }

            [Int]$StartRow = [Math]::Max(1, ([Int][Math]::Floor(($ViewportHeight - $Texts.Count) / 2) + 1))

            For([Int]$Idx = 0; $Idx -LT $Texts.Count; $Idx++) {
                [Int]$Row    = $StartRow + $Idx
                [String]$Txt = $Texts[$Idx]
                [Int]$Col    = [Math]::Max(1, ([Int][Math]::Floor(($SafeMaxCols - $Txt.Length) / 2) + 1))

                $Output += $this.CreatePositionedText($Row, $Col, $Txt, $Clrs[$Idx], $ViewportWidth, $ViewportHeight)
            }

            Return $Output
        }

        # TIER 3: ULTRA-TINY FALLBACK
        [Int]$TinyMaxCols = [Math]::Max(0, ($ViewportWidth - 1))

        If($TinyMaxCols -LE 0) {
            Return ''
        }

        [String]$TinyText = Format-TruncatedText "$($ViewportWidth)x$($ViewportHeight)<$($MinWidth)x$($MinHeight)" $TinyMaxCols

        Return $this.CreatePositionedText(1, 1, $TinyText, [ColorLibrary]::BoomboxWarningDimBad, $ViewportWidth, $ViewportHeight)
    }
}
