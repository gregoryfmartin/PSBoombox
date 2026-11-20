# PSBoombox

A **100% pure native PowerShell** text-based media player for Windows, featuring a 24-bit TrueColor terminal user interface (TUI), multi-layer finite state machine architecture, playlist file support, and direct Windows Multimedia (`winmm.dll`) audio playback.

![PSBoombox Main Player](Docs/Screenshots/main-player.png)

---

## Features

- **100% Pure Native PowerShell Audio Engine**: Calls Windows Multimedia APIs (`mciSendStringW`, `mciGetErrorStringW`, `waveOutGetVolume`, `waveOutSetVolume` in `winmm.dll`) and `GetShortPathNameW` (`kernel32.dll`) directly via `System.Reflection.Emit` (`DefinePInvokeMethod`) with zero inline C# (`Add-Type`), zero external executables, and zero third-party assemblies.
- **24-Bit TrueColor Synchronized TUI**: Renders rounded box-drawing borders (`╭─╮│╰─╯`), color-coded browser entries, a seekable track progress scrubber, an animated braille activity spinner, and synchronized terminal frame updates (`\e[?2026h` / `\e[?2026l`).
- **Integrated Directory & Playlist Workflow**: Launch directly into your current working directory, automatically queue any supported media files found there, browse folders, append tracks, reorder playlists, toggle repeat/shuffle, and save or load playlists on the fly.
- **Resilient MP3 & Path Handling**: Automatically bypasses Windows DirectShow/MCI initialization failures caused by large ID3v2 tags or embedded album art (MCI error `277`) via pure PowerShell MPEG frame-sync detection, and resolves DOS 8.3 short paths / temp staging for deep paths (MCI error `268`), cleaning up temporary files on stop and exit.
- **Three-Layer Finite State Machine Design**: Separates application screens (`PBState*`), audio playback lifecycle (`SMPlaybackStateMachine`), and individual UI element focus/activation (`SMUiElementStateMachine`).

---

## System & Software Requirements

| Requirement | Specification |
| --- | --- |
| **Operating System** | **Windows 10 / Windows 11** (`Win32NT`). Windows-only — validated at startup. |
| **PowerShell** | **PowerShell Core 7.0+** (`pwsh`, `Core` edition). Windows PowerShell 5.1 is not supported. |
| **Terminal Emulator** | VT/ANSI terminal with **24-bit TrueColor**, **Unicode** glyph support, and synchronized rendering (**Windows Terminal** with `Cascadia Mono` or `Consolas` recommended). |
| **Terminal Size** | Minimum **80 × 24** cells. Layout scales dynamically from `80 × 24` up to `160 × 50` cells. |
| **Audio Output** | Standard Windows audio output device compatible with Windows MCI (`winmm.dll`). |
| **Dependencies** | **None.** Self-contained pure native PowerShell module. |

---

## Installation & Module Loading

Clone or download the repository to a local directory, then import the module manifest in PowerShell 7 (`pwsh`):

```powershell
Import-Module .\PSBoombox.psd1 -Force
```

To install `PSBoombox` so it can be imported by name from any directory, copy the repository folder into a directory on your `$env:PSModulePath` (for example, `$HOME\Documents\PowerShell\Modules\PSBoombox`):

```powershell
Import-Module PSBoombox
```

---

## Invocation

`PSBoombox` exports a single public cmdlet: `Start-PSBoombox`.

### Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `-Path` | `[String]` | Current Working Directory | Optional starting directory displayed in the Directory Browser pane (relative or rooted paths supported). |
| `-Playlist` | `[String]` | Empty (`''`) | Optional path to a `.m3u`, `.m3u8`, `.pls`, or `.wpl` playlist file to load on startup. |

### Startup Behavior

- **`Start-PSBoombox`** *(no arguments)*: Opens the Directory Browser in the current working directory (`CWD`), starts with an empty playlist, and automatically appends any supported audio files located in `CWD`.
- **`Start-PSBoombox -Path 'C:\Music'`**: Starts the Directory Browser in `C:\Music` and auto-populates the playlist with any supported audio files found there.
- **`Start-PSBoombox -Playlist '.\Favorites.m3u8'`**: Loads tracks from the specified playlist file on startup (bypassing CWD auto-population) and focuses the Playlist pane automatically when tracks are loaded.

### Examples

```powershell
# Start in the current working directory (auto-adds any media files in CWD)
Start-PSBoombox

# Start in a specific music folder
Start-PSBoombox -Path 'D:\Audio\Synthwave'

# Start with a saved playlist loaded
Start-PSBoombox -Playlist '.\Playlists\LateNight.m3u8'

# Browse one folder while pre-loading a playlist from elsewhere
Start-PSBoombox -Path 'D:\Audio' -Playlist 'D:\Playlists\Favorites.pls'
```

---

## Supported Formats

### Audio Formats (Windows MCI)

| Extension | Format | Notes |
| --- | --- | --- |
| `.mp3` | MPEG Audio Layer III | Supports pure PowerShell ID3v2/embedded-artwork skipping & staging on MCI error `277` |
| `.wav` | RIFF WAVE PCM | Direct Windows MCI playback |
| `.wma` | Windows Media Audio | Played via Windows MCI |
| `.mid`, `.midi` | Standard MIDI | Played via Windows MCI |

### Playlist Formats

| Extension | Format | Notes |
| --- | --- | --- |
| `.m3u` | M3U Playlist | Reads and writes `#EXTM3U` / `#EXTINF` entries |
| `.m3u8` | UTF-8 M3U Playlist | Default extension when saving without an extension; writes UTF-8 (without BOM) |
| `.pls` | PLS Playlist | Reads and writes `[playlist]` INI `FileN` / `TitleN` / `LengthN` entries |
| `.wpl` | Windows Media Player Playlist | Reads and writes SMIL XML `<media src="..." />` entries |

Playlist loading resolves relative track paths against the playlist file's directory, supports `file:///` URIs, ignores network stream URLs, and skips missing files while displaying the skipped count in the status bar.

---

## Usage Guide

### Interface Overview

The TUI divides the terminal into four coordinated regions plus centered modal overlays:

1. **Playback Controls (Top Panel, Rows 1–5)**: Displays the active track title, state badge (`[STOPPED]`, `[LOADING]`, `[PLAYING]`, `[PAUSED]`, `[ERROR]`), animated braille activity indicator, seekable track progress bar (`MM:SS`), transport buttons (`|<`, `> Play`/`|| Pse`, `Stop`, `>|`, `Rpt:Off|All|One`, `Shf:Off|On`), and volume/mute indicator (`VOL`/`MUT`).
2. **Directory Browser (Bottom-Left Panel)**: Shows the current path and media file count in the title bar (`Dir: <path> (<count>)`), color-coded by entry type:
   - `.. (Parent Directory)` *(orange)*
   - `[DIR] <Folder>` *(cyan)*
   - `≡ <Playlist>` *(purple)*
   - `♪ <Audio File>` *(white; turns green with `▶` when playing, yellow with `❱` when selected)*
3. **Playlist (Bottom-Right Panel)**: Shows the active playlist name (when loaded/saved) and track count, with `01.` zero-padded track numbering and a green `▶` marker on the active track.
4. **Status & Hint Footer (Bottom Two Rows)**: Displays the latest action status or error message on row 1 and quick keybinding hints on row 2.

---

### Browsing Directories & Building a Playlist

- Use `Up` / `Down` (`PageUp` / `PageDown` / `Home` / `End`) in the **Directory Browser** to highlight items.
- Press `Enter` on `[DIR]` or `.. (Parent Directory)` (or `Backspace` anywhere in the Directory Browser) to change folders.
- Press `Enter` on a playlist entry (`≡ Favorites.pls`) to load it into the **Playlist** pane.
- Press `Enter` on an audio file (`♪ Midnight Drive.mp3`) to add it to the playlist (if not already queued) and start playback immediately.
- Press `A` to append the highlighted audio file to the playlist without interrupting playback, or `Shift+A` to append every supported audio file in the current directory.
- Press `Tab` to move focus to the **Playlist** pane to play (`Enter`), reorder (`U`/`Shift+Up`, `J`/`Shift+Down`), remove (`Delete`/`X`), or clear (`C`) tracks.

---

### Controlling Playback, Seeking & Volume

![Playback Controls Focused](Docs/Screenshots/playback-controls.png)

Press `Tab` (or `Shift+Tab`) to cycle focus to the top **PSBoombox** panel (highlighted with a cyan border):

- **Transport Row**: Use `Left` / `Right` to move between `|<`, `> Play` / `|| Pse`, `Stop`, `>|`, `Rpt:*`, `Shf:*`, and `VOL`. Press `Enter` or `Space` to trigger the focused button.
- **Track Scrubber**: Press `Up` from any transport button to highlight the progress bar, then use `Left` / `Right` to seek backward or forward in **5-second** steps. Press `Down` to return to the transport row.
- **Volume Control**: Move focus to `VOL` and press `Up` / `Down` (or press `+`, `-`, `M` globally from any pane) to adjust volume in **5%** increments or toggle mute (`MUT`). The bar renders green up to 80%, amber above 80%, and red when muted. If MCI per-alias volume commands are unavailable for a given format, `PSBoombox` falls back to Windows wave output volume and restores your original system wave level cleanly on exit.

---

### Jumping Directly to a Directory

![Go to Directory Modal](Docs/Screenshots/directory-prompt.png)

Press `G` or `F2` from anywhere in the main screen to open the centered **Go to Directory** modal:

- Type or edit any absolute or relative directory path (up to 260 characters with horizontal scrolling).
- Press `Enter` (or `Tab` to `[ Go ]`) to load the directory, or press `Esc` to cancel.
- Invalid or nonexistent paths report an inline error inside the modal without discarding your input.

---

### Saving Playlists

![Save Playlist Modal](Docs/Screenshots/save-playlist.png)

Press `W` at any time on the main screen to open the **Save Playlist** modal:

- Pre-fills the path using your active playlist's source path or `<CurrentDir>\playlist.m3u8`.
- Enter a filename ending in `.m3u`, `.m3u8`, `.pls`, or `.wpl` (omitting an extension defaults to `.m3u8`).
- Press `Enter` (or select `[ Save ]`) to write the playlist to disk and immediately refresh the Directory Browser listing.

---

## Keyboard Shortcuts

### Global Shortcuts (Main Screen)

| Key | Action |
| --- | --- |
| `Tab` / `Shift+Tab` | Cycle focus pane (`Directory Browser` ↔ `Playlist` ↔ `Playback Controls`) |
| `Space` | Toggle Play / Pause *(when focused on a Playback Control button, activates that button)* |
| `N` / `P` | Play Next / Previous track |
| `S` | Stop playback |
| `R` | Cycle Repeat mode (`Off` → `Playlist` (`Rpt:All`) → `Track` (`Rpt:One`)) |
| `H` | Toggle Shuffle (`Off` / `On`) |
| `+` / `-` | Increase / decrease volume by 5% |
| `M` | Toggle Mute |
| `G` / `F2` | Open **Go to Directory** modal |
| `W` | Open **Save Playlist** modal |
| `Q` / `Esc` | Quit PSBoombox cleanly |

### Directory Browser (`Tab` → Left Pane)

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move selection up / down (wraps around) |
| `PageUp` / `PageDown` | Scroll one page up / down |
| `Home` / `End` | Jump to first / last entry |
| `Enter` | Open folder, load playlist file, or add & play audio track |
| `Backspace` | Navigate to parent directory |
| `A` | Add highlighted audio file to playlist |
| `Shift+A` | Add all supported audio files in current directory to playlist |

### Playlist Pane (`Tab` → Right Pane)

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move selection up / down |
| `PageUp` / `PageDown` | Scroll one page up / down |
| `Home` / `End` | Jump to first / last track |
| `Enter` | Play selected track |
| `U` / `Shift+Up` | Move selected track up |
| `J` / `Shift+Down` | Move selected track down |
| `Delete` / `X` | Remove selected track from playlist |
| `C` | Clear entire playlist and stop playback |

### Playback Controls (`Tab` → Top Pane)

| Focus Row / Control | Key | Action |
| --- | --- | --- |
| Transport Row (`|<` .. `VOL`) | `Left` / `Right` | Cycle focus across buttons and Volume control |
| Transport Buttons (`|<` .. `Shf:*`) | `Up` | Move focus up to the Track Scrubber |
| Transport Buttons (`|<` .. `Shf:*`) | `Enter` / `Space` | Activate focused button |
| Track Scrubber | `Left` / `Right` | Seek backward / forward by 5 seconds |
| Track Scrubber | `Down` | Move focus down to `[ > Play ]` / `[ || Pse ]` |
| Volume Control (`VOL`) | `Up` / `Down` | Adjust volume by ±5% *(M mutes)* |

### Modal Dialogs (`Go to Directory` / `Save Playlist`)

| Key | Action |
| --- | --- |
| Printable characters | Insert text at cursor (up to 260 characters) |
| `Left` / `Right` / `Home` / `End` | Move text cursor within the input field |
| `Backspace` / `Delete` | Delete character before / at cursor |
| `Tab` / `Shift+Tab` | Cycle focus between Path Input, Confirm button, and `Cancel` |
| `Enter` | Submit modal (or invoke focused button) |
| `Esc` | Cancel modal and return to Main Screen |

---

## Architecture & Project Structure

`PSBoombox` loads its subsystems in strict dependency order inside [`PSBoombox.psm1`](PSBoombox.psm1):

```text
PSBoombox/
├── PSBoombox.psd1                 # Module manifest (PowerShell 7.0 Core, exports Start-PSBoombox)
├── PSBoombox.psm1                 # Ordered module loader
├── Public/
│   └── Start-PSBoombox.ps1        # Public entry command (-Path, -Playlist)
├── Source/
│   ├── Color/ & String/           # 24-bit TrueColor library & AT* ANSI control sequence builders
│   ├── Engine/
│   │   ├── AppCore.ps1            # Frame loop, delta timing, async ConsoleKeyInfo runspace
│   │   ├── BoomboxCore.ps1        # Coordinates panels, media services, focus zones & actions
│   │   └── States/                # PBStateInit, PBStateMainPlayer, PBState*Prompt, PBStateShutdown
│   ├── Enums/ & Events/ & Util/   # Focus zones, repeat/playback enums, Janitor environment checks
│   ├── Media/
│   │   ├── MMWinMMNative.ps1      # Pure Reflection.Emit P/Invoke for winmm.dll & kernel32.dll
│   │   ├── MMMediaPlayer.ps1      # MCI controller, ID3v2 frame-sync MP3 staging, wave volume fallback
│   │   ├── MMDirectoryService.ps1 # Filesystem browsing & audio/playlist enumeration
│   │   ├── MMPlaylist.ps1         # Queue operations, RepeatMode & Shuffle logic
│   │   └── MMPlaylistFileService.ps1 # Reader & writer for .m3u, .m3u8, .pls, and .wpl
│   ├── StateMachine/              # Generic SMStateMachine, SMUiElementStateMachine, SMPlaybackStateMachine
│   └── UI/                        # UIContainer, UIPanel, Elements/*, Panels/* (including UIPathInputModal)
└── Tests/
    ├── Run-PSBoomboxTests.ps1     # Automated unit, integration & pure-native style verification suite
    └── Test-Helpers.ps1           # Synthetic WAV / MP3 generators and assertions
```

---

## Running Tests

Run the automated test suite from the repository root using PowerShell 7 (`pwsh`):

```powershell
pwsh -NoProfile -File .\Tests\Run-PSBoomboxTests.ps1
```

The test harness verifies:
1. Module manifest metadata, `Core` edition enforcement, and `Start-PSBoombox` parameter exports.
2. Coding standard and pure native PowerShell compliance across all files under `Source/` and `Public/` (no `Add-Type`, `Set-StrictMode -Version Latest`, strict `ColorLibrary` usage).
3. UI, Playback, and Application finite state machine transitions.
4. Live Windows MCI playback, pause, resume, seek, volume/mute, and natural end-of-track events.
5. Real-world MP3 playback edge cases including large ID3v2 / album-art padding (MCI error `277`) and deep paths (MCI error `268`) plus temporary staged-file cleanup.
6. Directory browsing, all startup modes (`CWD`, `-Path`, `-Playlist`), and round-trip `.m3u`, `.m3u8`, `.pls`, and `.wpl` serialization.
7. Playlist queue mutations, reordering, repeat modes, and shuffle navigation.
8. Headless engine simulation of focus cycling, directory/save modals, and clean shutdown.
