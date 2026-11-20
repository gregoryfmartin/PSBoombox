using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest





###############################################################################
#
# MM DIRECTORY SERVICE
#
# NAVIGATES FILESYSTEM DIRECTORIES AND ENUMERATES SUBDIRECTORIES, PLAYLISTS,
# AND SUPPORTED AUDIO MEDIA FILES.
#
###############################################################################

Class MMDirectoryService {
    Static [String[]]$NativeAudioExtensions       = @('.mp3', '.wav', '.wma', '.flac', '.m4a', '.aac', '.mka', '.weba')
    Static [String[]]$MidiAudioExtensions         = @('.mid', '.midi')
    Static [String[]]$SupportedAudioExtensions    = @('.mp3', '.wav', '.wma', '.flac', '.m4a', '.aac', '.mka', '.weba', '.mid', '.midi')
    Static [String[]]$SupportedPlaylistExtensions = @('.m3u', '.m3u8', '.pls', '.wpl')

    [String]$CurrentPath
    [List[MMDirectoryEntry]]$Entries
    [String]$LastError

    MMDirectoryService() {
        $this.CurrentPath = ''
        $this.Entries     = [List[MMDirectoryEntry]]::new()
        $this.LastError   = ''
    }

    MMDirectoryService(
        [String]$InitialPath
    ) {
        $this.CurrentPath = ''
        $this.Entries     = [List[MMDirectoryEntry]]::new()
        $this.LastError   = ''

        $this.LoadDirectory($InitialPath) | Out-Null
    }

    Static [Boolean]IsSupportedAudioFile(
        [String]$FilePath
    ) {
        If(($null -EQ $FilePath) -OR ($FilePath.Length -EQ 0)) {
            Return $false
        }

        [String]$Ext = [Path]::GetExtension($FilePath).ToLowerInvariant()

        Return ($Ext -IN [MMDirectoryService]::SupportedAudioExtensions)
    }

    Static [Boolean]IsSupportedPlaylistFile(
        [String]$FilePath
    ) {
        If(($null -EQ $FilePath) -OR ($FilePath.Length -EQ 0)) {
            Return $false
        }

        [String]$Ext = [Path]::GetExtension($FilePath).ToLowerInvariant()

        Return ($Ext -IN [MMDirectoryService]::SupportedPlaylistExtensions)
    }

    [Boolean]LoadDirectory(
        [String]$TargetPath
    ) {
        $this.LastError = ''

        If(($null -EQ $TargetPath) -OR ($TargetPath.Trim().Length -EQ 0)) {
            $this.LastError = 'Directory path cannot be empty.'

            Return $false
        }

        [String]$ResolvedPath = ''

        Try {
            [String]$Candidate = $TargetPath.Trim()

            If([Path]::IsPathRooted($Candidate) -EQ $false) {
                [String]$BaseDir = ($this.CurrentPath.Length -GT 0) ? $this.CurrentPath : (Get-Location).Path
                $Candidate       = [Path]::Combine($BaseDir, $Candidate)
            }

            $ResolvedPath = [Path]::GetFullPath($Candidate)
        } Catch {
            $this.LastError = "Invalid directory path: $($_.Exception.Message)"

            Return $false
        }

        If([Directory]::Exists($ResolvedPath) -EQ $false) {
            $this.LastError = "Directory not found: $($ResolvedPath)"

            Return $false
        }

        [List[MMDirectoryEntry]]$NewEntries = [List[MMDirectoryEntry]]::new()

        Try {
            [DirectoryInfo]$DirInfo    = [DirectoryInfo]::new($ResolvedPath)
            [DirectoryInfo]$ParentInfo = $DirInfo.Parent

            If($null -NE $ParentInfo) {
                $NewEntries.Add(
                    [MMDirectoryEntry]::new(
                        [DirectoryEntryType]::ParentDirectory,
                        '..',
                        $ParentInfo.FullName
                    )
                )
            }

            [List[DirectoryInfo]]$SubDirs = [List[DirectoryInfo]]::new()

            Foreach($SubDir in $DirInfo.GetDirectories()) {
                $SubDirs.Add($SubDir)
            }

            $SubDirs.Sort({
                Param(
                    [DirectoryInfo]$Left,
                    [DirectoryInfo]$Right
                )

                Return [StringComparer]::OrdinalIgnoreCase.Compare($Left.Name, $Right.Name)
            })

            Foreach($SubDir in $SubDirs) {
                $NewEntries.Add(
                    [MMDirectoryEntry]::new(
                        [DirectoryEntryType]::Directory,
                        $SubDir.Name,
                        $SubDir.FullName
                    )
                )
            }

            [List[FileInfo]]$PlaylistFiles = [List[FileInfo]]::new()
            [List[FileInfo]]$MediaFiles    = [List[FileInfo]]::new()

            Foreach($FileItem in $DirInfo.GetFiles()) {
                If([MMDirectoryService]::IsSupportedPlaylistFile($FileItem.FullName) -EQ $true) {
                    $PlaylistFiles.Add($FileItem)
                } Elseif([MMDirectoryService]::IsSupportedAudioFile($FileItem.FullName) -EQ $true) {
                    $MediaFiles.Add($FileItem)
                }
            }

            [Comparison[FileInfo]]$FileSorter = {
                Param(
                    [FileInfo]$Left,
                    [FileInfo]$Right
                )

                Return [StringComparer]::OrdinalIgnoreCase.Compare($Left.Name, $Right.Name)
            }

            $PlaylistFiles.Sort($FileSorter)
            $MediaFiles.Sort($FileSorter)

            Foreach($PlFile in $PlaylistFiles) {
                $NewEntries.Add(
                    [MMDirectoryEntry]::new(
                        [DirectoryEntryType]::PlaylistFile,
                        $PlFile.Name,
                        $PlFile.FullName
                    )
                )
            }

            Foreach($AudioFile in $MediaFiles) {
                $NewEntries.Add(
                    [MMDirectoryEntry]::new(
                        [DirectoryEntryType]::MediaFile,
                        $AudioFile.Name,
                        $AudioFile.FullName
                    )
                )
            }
        } Catch {
            $this.LastError = "Unable to read directory '$($ResolvedPath)': $($_.Exception.Message)"

            Return $false
        }

        $this.CurrentPath = $ResolvedPath
        $this.Entries     = $NewEntries

        Return $true
    }

    [Boolean]NavigateUp() {
        If($this.CurrentPath.Length -EQ 0) {
            Return $false
        }

        [DirectoryInfo]$ParentInfo = [Directory]::GetParent($this.CurrentPath)

        If($null -EQ $ParentInfo) {
            $this.LastError = 'Already at drive root.'

            Return $false
        }

        Return $this.LoadDirectory($ParentInfo.FullName)
    }

    [Boolean]Refresh() {
        If($this.CurrentPath.Length -EQ 0) {
            Return $false
        }

        Return $this.LoadDirectory($this.CurrentPath)
    }

    [Int]GetMediaFileCount() {
        [Int]$Count = 0

        Foreach($Entry in $this.Entries) {
            If($Entry.EntryType -EQ [DirectoryEntryType]::MediaFile) {
                $Count++
            }
        }

        Return $Count
    }

    [List[MMTrackInfo]]GetMediaTracksInCurrentDirectory() {
        [List[MMTrackInfo]]$Tracks = [List[MMTrackInfo]]::new()

        Foreach($Entry in $this.Entries) {
            If($Entry.EntryType -EQ [DirectoryEntryType]::MediaFile) {
                $Tracks.Add([MMTrackInfo]::new($Entry.FullPath))
            }
        }

        Return $Tracks
    }
}
