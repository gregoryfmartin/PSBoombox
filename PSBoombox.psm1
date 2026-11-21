using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# PSBOOMBOX MODULE LOADER
#
# DOT-SOURCES ALL MODULE COMPONENTS IN STRICT DEPENDENCY ORDER.
#
###############################################################################

[String]$Script:DirEnums        = "$($PSScriptRoot)/Source/Enums"
[String]$Script:DirEvents       = "$($PSScriptRoot)/Source/Events"
[String]$Script:DirUtil         = "$($PSScriptRoot)/Source/Util"
[String]$Script:DirStateMachine = "$($PSScriptRoot)/Source/StateMachine"
[String]$Script:DirColor        = "$($PSScriptRoot)/Source/Color"
[String]$Script:DirString       = "$($PSScriptRoot)/Source/String"
[String]$Script:DirMedia        = "$($PSScriptRoot)/Source/Media"
[String]$Script:DirUi           = "$($PSScriptRoot)/Source/UI"
[String]$Script:DirEngine       = "$($PSScriptRoot)/Source/Engine"
[String]$Script:DirPublic       = "$($PSScriptRoot)/Public"

# LOAD ENUMS
Foreach($EnumFile in (Get-ChildItem -Path $Script:DirEnums -Filter '*.ps1' | Sort-Object Name)) {
    . $EnumFile.FullName
}

# LOAD EVENTS AND UTILITIES
. "$($Script:DirEvents)/CustomEvents.ps1"
. "$($Script:DirUtil)/Context.ps1"
. "$($Script:DirUtil)/ContextBroadcaster.ps1"
. "$($Script:DirUtil)/ClampableInt.ps1"
. "$($Script:DirUtil)/BufferSpecDefinition.ps1"
. "$($Script:DirUtil)/Janitor.ps1"
. "$($Script:DirUtil)/Functions.ps1"

# LOAD STATE MACHINES
. "$($Script:DirStateMachine)/SMState.ps1"
. "$($Script:DirStateMachine)/SMTransition.ps1"
. "$($Script:DirStateMachine)/SMStateMachine.ps1"
. "$($Script:DirStateMachine)/SMUiStateMachine.ps1"
. "$($Script:DirStateMachine)/SMPlaybackStateMachine.ps1"

# LOAD COLOR AND STRING SUPPORT
. "$($Script:DirColor)/ColorChannel.ps1"
. "$($Script:DirColor)/TrueColor.ps1"
. "$($Script:DirColor)/UIThemeDefinition.ps1"
. "$($Script:DirColor)/UIThemeService.ps1"
[UIThemeService]::EmbeddedThemesFilePath = "$($Script:DirColor)/Themes.json"
. "$($Script:DirString)/ATControlSequences.ps1"
. "$($Script:DirString)/ATDecoration.ps1"
. "$($Script:DirString)/ATDecorationNone.ps1"
. "$($Script:DirString)/ATCoordinates.ps1"
. "$($Script:DirString)/ATCoordinatesDefault.ps1"
. "$($Script:DirString)/ATCoordinatesNone.ps1"
. "$($Script:DirString)/ATBackgroundColor24.ps1"
. "$($Script:DirString)/ATBackgroundColor24None.ps1"
. "$($Script:DirString)/ATForegroundColor24.ps1"
. "$($Script:DirString)/ATForegroundColor24None.ps1"
. "$($Script:DirString)/ATStringPrefix.ps1"
. "$($Script:DirString)/ATStringPrefixNone.ps1"
. "$($Script:DirString)/ATString.ps1"
. "$($Script:DirString)/ATStringNone.ps1"
. "$($Script:DirString)/ATStringComposite.ps1"
. "$($Script:DirString)/StringAnimator.ps1"

# LOAD WINDOWS MULTIMEDIA AND DOMAIN LAYER
. "$($Script:DirMedia)/MMWinMMNative.ps1"
. "$($Script:DirMedia)/MMEqualizerEngineNative.ps1"
. "$($Script:DirMedia)/MMEqualizerPreset.ps1"
. "$($Script:DirMedia)/MMEqualizerService.ps1"
. "$($Script:DirMedia)/MMTrackInfo.ps1"
. "$($Script:DirMedia)/MMDirectoryEntry.ps1"
. "$($Script:DirMedia)/MMDirectoryService.ps1"
. "$($Script:DirMedia)/MMPlaylist.ps1"
. "$($Script:DirMedia)/MMPlaylistFileService.ps1"
. "$($Script:DirMedia)/MMMediaPlayer.ps1"

# LOAD UI FRAMEWORK, ELEMENTS, AND PANELS
. "$($Script:DirUi)/UIElementBehavior.ps1"
. "$($Script:DirUi)/UIBase.ps1"
. "$($Script:DirUi)/UIContainer.ps1"
. "$($Script:DirUi)/Elements/UILabel.ps1"
. "$($Script:DirUi)/Elements/UICheckbox.ps1"
. "$($Script:DirUi)/Elements/UIRadioButton.ps1"
. "$($Script:DirUi)/Elements/UIChevron.ps1"
. "$($Script:DirUi)/Elements/UICellSpinner.ps1"
. "$($Script:DirUi)/Elements/UITextInput.ps1"
. "$($Script:DirUi)/Elements/UIButton.ps1"
. "$($Script:DirUi)/Elements/UIListItem.ps1"
. "$($Script:DirUi)/Elements/UIList.ps1"
. "$($Script:DirUi)/Elements/UIMenuItem.ps1"
. "$($Script:DirUi)/Elements/UIMenu.ps1"
. "$($Script:DirUi)/Elements/UINumberSpinner.ps1"
. "$($Script:DirUi)/Elements/UIVerticalSlider.ps1"
. "$($Script:DirUi)/Elements/UIProgressBar.ps1"
. "$($Script:DirUi)/Elements/UIVolumeControl.ps1"
. "$($Script:DirUi)/Elements/UITrackProgressBar.ps1"
. "$($Script:DirUi)/UIPanel.ps1"
. "$($Script:DirUi)/Elements/UITab.ps1"
. "$($Script:DirUi)/Elements/UITabGroup.ps1"
. "$($Script:DirUi)/UITabContainer.ps1"
. "$($Script:DirUi)/Panels/UIPlaybackControlPanel.ps1"
. "$($Script:DirUi)/Panels/UIDirectoryBrowserPanel.ps1"
. "$($Script:DirUi)/Panels/UIPlaylistPanel.ps1"
. "$($Script:DirUi)/Panels/UIPathInputModal.ps1"
. "$($Script:DirUi)/Panels/UIEqualizerModal.ps1"
. "$($Script:DirUi)/Panels/UIThemeModal.ps1"
. "$($Script:DirUi)/Panels/UINoticeModal.ps1"
. "$($Script:DirUi)/Panels/UIStatusFooterPanel.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerCanvas.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerBase.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerSpectrum.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerMirror.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerOscilloscope.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerRadialPulse.ps1"
. "$($Script:DirUi)/Visualizers/UIVisualizerWaterfall.ps1"

# LOAD ENGINE CORE AND APPLICATION STATES
. "$($Script:DirEngine)/AppCore.ps1"
. "$($Script:DirEngine)/States/PBStateInit.ps1"
. "$($Script:DirEngine)/States/PBStateMainPlayer.ps1"
. "$($Script:DirEngine)/States/PBStateDirectoryPrompt.ps1"
. "$($Script:DirEngine)/States/PBStatePlaylistSavePrompt.ps1"
. "$($Script:DirEngine)/States/PBStateEqualizer.ps1"
. "$($Script:DirEngine)/States/PBStateThemeSelector.ps1"
. "$($Script:DirEngine)/States/PBStateNoticeModal.ps1"
. "$($Script:DirEngine)/States/PBStateVisualizer.ps1"
. "$($Script:DirEngine)/States/PBStateBufferTooSmall.ps1"
. "$($Script:DirEngine)/States/PBStateShutdown.ps1"
. "$($Script:DirEngine)/BoomboxCore.ps1"

# LOAD PUBLIC COMMANDS
. "$($Script:DirPublic)/Start-PSBoombox.ps1"
