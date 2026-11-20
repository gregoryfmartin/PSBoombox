using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# MM EQUALIZER PRESET
#
# REPRESENTS A NAMED 10-BAND ISO GRAPHIC EQUALIZER PROFILE WITH PREAMP GAIN.
#
###############################################################################

Class MMEqualizerPreset {
    Static [Int]$BandCount = 10
    Static [Int]$MinGainDb = -12
    Static [Int]$MaxGainDb = 12

    [String]$Name
    [Int]$PreampDb
    [Int[]]$BandGainsDb
    [Boolean]$IsBuiltIn

    MMEqualizerPreset() {
        $this.Initialize('', 0, @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0), $false)
    }

    MMEqualizerPreset(
        [String]$Name,
        [Int]$PreampDb,
        [Int[]]$BandGainsDb,
        [Boolean]$IsBuiltIn
    ) {
        $this.Initialize($Name, $PreampDb, $BandGainsDb, $IsBuiltIn)
    }

    Static [Int[]]NormalizeBands(
        [Int[]]$RawBands
    ) {
        [Int[]]$Normalized = [Int[]]::new([MMEqualizerPreset]::BandCount)

        For([Int]$Idx = 0; $Idx -LT [MMEqualizerPreset]::BandCount; $Idx++) {
            [Int]$Val        = (($null -NE $RawBands) -AND ($Idx -LT $RawBands.Length)) ? $RawBands[$Idx] : 0
            $Normalized[$Idx] = [Math]::Clamp($Val, [MMEqualizerPreset]::MinGainDb, [MMEqualizerPreset]::MaxGainDb)
        }

        Return $Normalized
    }

    [Void]Initialize(
        [String]$Name,
        [Int]$PreampDb,
        [Int[]]$BandGainsDb,
        [Boolean]$IsBuiltIn
    ) {
        $this.Name        = ($null -EQ $Name) ? '' : $Name.Trim()
        $this.PreampDb    = [Math]::Clamp($PreampDb, [MMEqualizerPreset]::MinGainDb, [MMEqualizerPreset]::MaxGainDb)
        $this.BandGainsDb = [MMEqualizerPreset]::NormalizeBands($BandGainsDb)
        $this.IsBuiltIn   = $IsBuiltIn
    }

    [MMEqualizerPreset]Clone() {
        Return [MMEqualizerPreset]::new($this.Name, $this.PreampDb, $this.BandGainsDb, $this.IsBuiltIn)
    }

    [Boolean]MatchesValues(
        [Int]$PreampDb,
        [Int[]]$Bands
    ) {
        If($this.PreampDb -NE $PreampDb) {
            Return $false
        }

        [Int[]]$Normalized = [MMEqualizerPreset]::NormalizeBands($Bands)

        For([Int]$Idx = 0; $Idx -LT [MMEqualizerPreset]::BandCount; $Idx++) {
            If($this.BandGainsDb[$Idx] -NE $Normalized[$Idx]) {
                Return $false
            }
        }

        Return $true
    }
}
