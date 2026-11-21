using namespace System
using namespace System.IO

Set-StrictMode -Version Latest





<#
.SYNOPSIS
Starts the PSBoombox text-based media player.

.DESCRIPTION
Launches PSBoombox in the terminal. By default, uses the current working
directory (CWD) and automatically adds any supported media files found in CWD
to the playlist (starting empty if none are present). Optionally loads a
playlist file (.m3u, .m3u8, .pls, or .wpl) via -Playlist.

.PARAMETER Path
Optional starting directory path. Defaults to the current working directory.

.PARAMETER Playlist
Optional path to a playlist file (.m3u, .m3u8, .pls, or .wpl) to load at startup.

.PARAMETER Theme
Optional theme name (built-in Gogh preset or 'PSBoombox Default') or path to a custom Gogh-format .json theme file.

.EXAMPLE
Start-PSBoombox

.EXAMPLE
Start-PSBoombox -Path 'C:\Music'

.EXAMPLE
Start-PSBoombox -Playlist '.\Favorites.m3u8'

.EXAMPLE
Start-PSBoombox -Theme 'Catppuccin Latte'
#>
Function Start-PSBoombox {
    Param(
        [String]$Path = '',
        [String]$Playlist = '',
        [String]$Theme = ''
    )

    If([Environment]::OSVersion.Platform -NE [PlatformID]::Win32NT) {
        Throw 'PSBoombox supports Windows only.'
    }

    [String]$ResolvedStartPath = ($Path.Trim().Length -GT 0) ? $Path.Trim() : (Get-Location).Path

    Try {
        If([Path]::IsPathRooted($ResolvedStartPath) -EQ $false) {
            $ResolvedStartPath = [Path]::Combine((Get-Location).Path, $ResolvedStartPath)
        }

        $ResolvedStartPath = [Path]::GetFullPath($ResolvedStartPath)
    } Catch {
        $ResolvedStartPath = (Get-Location).Path
    }

    [String]$ResolvedPlaylistPath = ''

    If($Playlist.Trim().Length -GT 0) {
        [String]$Candidate = $Playlist.Trim()

        If([Path]::IsPathRooted($Candidate) -EQ $false) {
            $Candidate = [Path]::Combine((Get-Location).Path, $Candidate)
        }

        $ResolvedPlaylistPath = [Path]::GetFullPath($Candidate)
    }

    [String]$ResolvedTheme = ''

    If($Theme.Trim().Length -GT 0) {
        [String]$TrimmedTheme = $Theme.Trim()
        [String]$PathProbe    = $TrimmedTheme

        Try {
            If([Path]::IsPathRooted($PathProbe) -EQ $false) {
                $PathProbe = [Path]::Combine((Get-Location).Path, $PathProbe)
            }

            $PathProbe = [Path]::GetFullPath($PathProbe)
        } Catch {
            $PathProbe = ''
        }

        If(($PathProbe.Length -GT 0) -AND (([File]::Exists($PathProbe) -EQ $true) -OR ($TrimmedTheme.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase) -EQ $true))) {
            $ResolvedTheme = $PathProbe
        } Else {
            $ResolvedTheme = $TrimmedTheme
        }
    }

    [BoomboxCore]$Core = [BoomboxCore]::new($ResolvedStartPath, $ResolvedPlaylistPath, $ResolvedTheme)
    $Core.Run()
}
