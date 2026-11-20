using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text
using namespace System.Xml

Set-StrictMode -Version Latest





###############################################################################
#
# MM PLAYLIST FILE SERVICE
#
# NATIVE POWERSHELL READER AND WRITER FOR COMMON PLAYLIST FORMATS:
# .M3U, .M3U8, .PLS, AND .WPL.
#
###############################################################################

Class MMPlaylistFileService {
    Static [String[]]$SupportedExtensions = @('.m3u', '.m3u8', '.pls', '.wpl')

    Static [String]ResolveEntryPath(
        [String]$BaseDirectory,
        [String]$RawEntry
    ) {
        If(($null -EQ $RawEntry) -OR ($RawEntry.Trim().Length -EQ 0)) {
            Return ''
        }

        [String]$Trimmed = $RawEntry.Trim().Trim('"')

        If($Trimmed -MATCH '^file:///') {
            Try {
                [Uri]$FileUri = [Uri]::new($Trimmed)

                Return $FileUri.LocalPath
            } Catch {
                Return ''
            }
        }

        If($Trimmed -MATCH '^[A-Za-z][A-Za-z0-9+.-]*://') {
            # IGNORE NETWORK STREAM URLS IN LOCAL FILE PLAYLISTS
            Return ''
        }

        Try {
            If([Path]::IsPathRooted($Trimmed) -EQ $true) {
                Return [Path]::GetFullPath($Trimmed)
            }

            Return [Path]::GetFullPath([Path]::Combine($BaseDirectory, $Trimmed))
        } Catch {
            Return ''
        }
    }

    Static [Hashtable]LoadPlaylist(
        [String]$PlaylistPath
    ) {
        If(($null -EQ $PlaylistPath) -OR ($PlaylistPath.Trim().Length -EQ 0)) {
            Return @{
                Success      = $false
                Tracks       = [List[MMTrackInfo]]::new()
                SkippedCount = 0
                PlaylistName = ''
                SourcePath   = ''
                ErrorMessage = 'Playlist file path cannot be empty.'
            }
        }

        [String]$ResolvedPath = ''

        Try {
            [String]$Candidate = $PlaylistPath.Trim()

            If([Path]::IsPathRooted($Candidate) -EQ $false) {
                $Candidate = [Path]::Combine((Get-Location).Path, $Candidate)
            }

            $ResolvedPath = [Path]::GetFullPath($Candidate)
        } Catch {
            Return @{
                Success      = $false
                Tracks       = [List[MMTrackInfo]]::new()
                SkippedCount = 0
                PlaylistName = ''
                SourcePath   = ''
                ErrorMessage = "Invalid playlist path: $($_.Exception.Message)"
            }
        }

        If([File]::Exists($ResolvedPath) -EQ $false) {
            Return @{
                Success      = $false
                Tracks       = [List[MMTrackInfo]]::new()
                SkippedCount = 0
                PlaylistName = ''
                SourcePath   = $ResolvedPath
                ErrorMessage = "Playlist file not found: $($ResolvedPath)"
            }
        }

        [String]$Ext = [Path]::GetExtension($ResolvedPath).ToLowerInvariant()

        If(($Ext -IN [MMPlaylistFileService]::SupportedExtensions) -EQ $false) {
            Return @{
                Success      = $false
                Tracks       = [List[MMTrackInfo]]::new()
                SkippedCount = 0
                PlaylistName = ''
                SourcePath   = $ResolvedPath
                ErrorMessage = "Unsupported playlist format '$($Ext)'. Expected .m3u, .m3u8, .pls, or .wpl."
            }
        }

        [String]$BaseDirectory       = [Path]::GetDirectoryName($ResolvedPath)
        [String]$PlaylistName        = [Path]::GetFileNameWithoutExtension($ResolvedPath)
        [List[MMTrackInfo]]$Tracks   = [List[MMTrackInfo]]::new()
        [Int]$SkippedCount           = 0

        Try {
            If(($Ext -EQ '.m3u') -OR ($Ext -EQ '.m3u8')) {
                [Encoding]$ReadEncoding = ($Ext -EQ '.m3u8') ? [Encoding]::UTF8 : [UTF8Encoding]::new($false)
                [String[]]$Lines        = [File]::ReadAllLines($ResolvedPath, $ReadEncoding)
                [String]$PendingTitle   = ''
                [Int]$PendingDurationMs = 0

                Foreach($RawLine in $Lines) {
                    [String]$Line = $RawLine.Trim()

                    If($Line.Length -EQ 0) {
                        Continue
                    }

                    If($Line.StartsWith('#EXTINF:', [StringComparison]::OrdinalIgnoreCase) -EQ $true) {
                        [String]$Meta     = $Line.Substring(8)
                        [Int]$CommaIndex  = $Meta.IndexOf(',')

                        If($CommaIndex -GE 0) {
                            [String]$SecStr  = $Meta.Substring(0, $CommaIndex).Trim()
                            [Int]$ParsedSec  = 0

                            If([Int]::TryParse($SecStr, [Ref]$ParsedSec) -EQ $true -AND ($ParsedSec -GT 0)) {
                                $PendingDurationMs = $ParsedSec * 1000
                            }

                            $PendingTitle = $Meta.Substring($CommaIndex + 1).Trim()
                        }

                        Continue
                    }

                    If($Line.StartsWith('#') -EQ $true) {
                        Continue
                    }

                    [String]$ResolvedTrack = [MMPlaylistFileService]::ResolveEntryPath($BaseDirectory, $Line)

                    If(($ResolvedTrack.Length -GT 0) -AND ([File]::Exists($ResolvedTrack) -EQ $true)) {
                        $Tracks.Add([MMTrackInfo]::new($ResolvedTrack, $PendingTitle, $PendingDurationMs))
                    } Else {
                        $SkippedCount++
                    }

                    $PendingTitle      = ''
                    $PendingDurationMs = 0
                }
            } Elseif($Ext -EQ '.pls') {
                [String[]]$Lines                      = [File]::ReadAllLines($ResolvedPath, [Encoding]::UTF8)
                [Dictionary[Int, String]]$FileMap     = [Dictionary[Int, String]]::new()
                [Dictionary[Int, String]]$TitleMap    = [Dictionary[Int, String]]::new()
                [Dictionary[Int, Int]]$LengthMap      = [Dictionary[Int, Int]]::new()

                Foreach($RawLine in $Lines) {
                    [String]$Line = $RawLine.Trim()

                    If(($Line.Length -EQ 0) -OR ($Line.StartsWith(';') -EQ $true) -OR ($Line.StartsWith('#') -EQ $true) -OR ($Line.StartsWith('[') -EQ $true)) {
                        Continue
                    }

                    If($Line -MATCH '^(?i)File(\d+)=(.+)$') {
                        [Int]$SlotIdx = [Int]$Matches[1]
                        $FileMap[$SlotIdx] = $Matches[2].Trim()
                    } Elseif($Line -MATCH '^(?i)Title(\d+)=(.*)$') {
                        [Int]$SlotIdx = [Int]$Matches[1]
                        $TitleMap[$SlotIdx] = $Matches[2].Trim()
                    } Elseif($Line -MATCH '^(?i)Length(\d+)=(-?\d+)$') {
                        [Int]$SlotIdx = [Int]$Matches[1]
                        [Int]$Secs    = [Int]$Matches[2]
                        $LengthMap[$SlotIdx] = ($Secs -GT 0) ? ($Secs * 1000) : 0
                    }
                }

                [List[Int]]$SortedKeys = [List[Int]]::new($FileMap.Keys)
                $SortedKeys.Sort()

                Foreach($KeyIdx in $SortedKeys) {
                    [String]$ResolvedTrack = [MMPlaylistFileService]::ResolveEntryPath($BaseDirectory, $FileMap[$KeyIdx])

                    If(($ResolvedTrack.Length -GT 0) -AND ([File]::Exists($ResolvedTrack) -EQ $true)) {
                        [String]$Title   = ($TitleMap.ContainsKey($KeyIdx) -EQ $true) ? $TitleMap[$KeyIdx] : ''
                        [Int]$DurationMs = ($LengthMap.ContainsKey($KeyIdx) -EQ $true) ? $LengthMap[$KeyIdx] : 0

                        $Tracks.Add([MMTrackInfo]::new($ResolvedTrack, $Title, $DurationMs))
                    } Else {
                        $SkippedCount++
                    }
                }
            } Elseif($Ext -EQ '.wpl') {
                [XmlDocument]$XmlDoc = [XmlDocument]::new()
                $XmlDoc.Load($ResolvedPath)

                [XmlNodeList]$MediaNodes = $XmlDoc.SelectNodes("//*[local-name()='media']")

                If($null -NE $MediaNodes) {
                    Foreach($Node in $MediaNodes) {
                        [XmlElement]$Elem = $Node -AS [XmlElement]

                        If($null -EQ $Elem) {
                            Continue
                        }

                        [String]$SrcAttr       = $Elem.GetAttribute('src')
                        [String]$ResolvedTrack = [MMPlaylistFileService]::ResolveEntryPath($BaseDirectory, $SrcAttr)

                        If(($ResolvedTrack.Length -GT 0) -AND ([File]::Exists($ResolvedTrack) -EQ $true)) {
                            $Tracks.Add([MMTrackInfo]::new($ResolvedTrack))
                        } Else {
                            $SkippedCount++
                        }
                    }
                }
            }
        } Catch {
            Return @{
                Success      = $false
                Tracks       = [List[MMTrackInfo]]::new()
                SkippedCount = $SkippedCount
                PlaylistName = $PlaylistName
                SourcePath   = $ResolvedPath
                ErrorMessage = "Failed to parse playlist '$($ResolvedPath)': $($_.Exception.Message)"
            }
        }

        Return @{
            Success      = $true
            Tracks       = $Tracks
            SkippedCount = $SkippedCount
            PlaylistName = $PlaylistName
            SourcePath   = $ResolvedPath
            ErrorMessage = ''
        }
    }

    Static [Hashtable]SavePlaylist(
        [String]$TargetPath,
        [List[MMTrackInfo]]$Tracks
    ) {
        If(($null -EQ $TargetPath) -OR ($TargetPath.Trim().Length -EQ 0)) {
            Return @{
                Success      = $false
                SavedPath    = ''
                TrackCount   = 0
                ErrorMessage = 'Save file path cannot be empty.'
            }
        }

        [String]$FinalPath = ''

        Try {
            [String]$Candidate = $TargetPath.Trim()

            If([Path]::IsPathRooted($Candidate) -EQ $false) {
                $Candidate = [Path]::Combine((Get-Location).Path, $Candidate)
            }

            If([Path]::GetExtension($Candidate).Length -EQ 0) {
                $Candidate += '.m3u8'
            }

            $FinalPath = [Path]::GetFullPath($Candidate)
        } Catch {
            Return @{
                Success      = $false
                SavedPath    = ''
                TrackCount   = 0
                ErrorMessage = "Invalid save path: $($_.Exception.Message)"
            }
        }

        [String]$Ext       = [Path]::GetExtension($FinalPath).ToLowerInvariant()
        [String]$ParentDir = [Path]::GetDirectoryName($FinalPath)

        If(($Ext -IN [MMPlaylistFileService]::SupportedExtensions) -EQ $false) {
            Return @{
                Success      = $false
                SavedPath    = $FinalPath
                TrackCount   = 0
                ErrorMessage = "Unsupported format '$($Ext)'. Use .m3u, .m3u8, .pls, or .wpl."
            }
        }

        If([Directory]::Exists($ParentDir) -EQ $false) {
            Return @{
                Success      = $false
                SavedPath    = $FinalPath
                TrackCount   = 0
                ErrorMessage = "Target directory does not exist: $($ParentDir)"
            }
        }

        [List[MMTrackInfo]]$SafeTracks = ($null -EQ $Tracks) ? [List[MMTrackInfo]]::new() : $Tracks

        Try {
            [UTF8Encoding]$Utf8NoBom = [UTF8Encoding]::new($false)

            If(($Ext -EQ '.m3u') -OR ($Ext -EQ '.m3u8')) {
                [List[String]]$OutputLines = [List[String]]::new()
                $OutputLines.Add('#EXTM3U')

                Foreach($Track in $SafeTracks) {
                    [Int]$Seconds = ($Track.DurationMs -GT 0) ? [Int][Math]::Floor($Track.DurationMs / 1000.0) : -1
                    $OutputLines.Add("#EXTINF:$($Seconds),$($Track.DisplayName)")
                    $OutputLines.Add($Track.FullPath)
                }

                [File]::WriteAllLines($FinalPath, $OutputLines.ToArray(), $Utf8NoBom)
            } Elseif($Ext -EQ '.pls') {
                [List[String]]$OutputLines = [List[String]]::new()
                $OutputLines.Add('[playlist]')

                For([Int]$Idx = 0; $Idx -LT $SafeTracks.Count; $Idx++) {
                    [MMTrackInfo]$Track = $SafeTracks[$Idx]
                    [Int]$Num           = $Idx + 1
                    [Int]$Seconds       = ($Track.DurationMs -GT 0) ? [Int][Math]::Floor($Track.DurationMs / 1000.0) : -1

                    $OutputLines.Add("File$($Num)=$($Track.FullPath)")
                    $OutputLines.Add("Title$($Num)=$($Track.DisplayName)")
                    $OutputLines.Add("Length$($Num)=$($Seconds)")
                }

                $OutputLines.Add("NumberOfEntries=$($SafeTracks.Count)")
                $OutputLines.Add('Version=2')

                [File]::WriteAllLines($FinalPath, $OutputLines.ToArray(), $Utf8NoBom)
            } Elseif($Ext -EQ '.wpl') {
                [XmlDocument]$XmlDoc   = [XmlDocument]::new()
                [XmlNode]$PiNode       = $XmlDoc.CreateProcessingInstruction('wpl', 'version="1.0"')
                $null                  = $XmlDoc.AppendChild($PiNode)
                [XmlElement]$SmilElem  = $XmlDoc.CreateElement('smil')
                [XmlElement]$HeadElem  = $XmlDoc.CreateElement('head')
                [XmlElement]$TitleElem = $XmlDoc.CreateElement('title')
                [XmlElement]$BodyElem  = $XmlDoc.CreateElement('body')
                [XmlElement]$SeqElem   = $XmlDoc.CreateElement('seq')

                $TitleElem.InnerText = [Path]::GetFileNameWithoutExtension($FinalPath)
                $null                = $HeadElem.AppendChild($TitleElem)

                Foreach($Track in $SafeTracks) {
                    [XmlElement]$MediaElem = $XmlDoc.CreateElement('media')
                    $MediaElem.SetAttribute('src', $Track.FullPath)
                    $null = $SeqElem.AppendChild($MediaElem)
                }

                $null = $BodyElem.AppendChild($SeqElem)
                $null = $SmilElem.AppendChild($HeadElem)
                $null = $SmilElem.AppendChild($BodyElem)
                $null = $XmlDoc.AppendChild($SmilElem)

                $XmlDoc.Save($FinalPath)
            }
        } Catch {
            Return @{
                Success      = $false
                SavedPath    = $FinalPath
                TrackCount   = 0
                ErrorMessage = "Failed to save playlist: $($_.Exception.Message)"
            }
        }

        Return @{
            Success      = $true
            SavedPath    = $FinalPath
            TrackCount   = $SafeTracks.Count
            ErrorMessage = ''
        }
    }
}
