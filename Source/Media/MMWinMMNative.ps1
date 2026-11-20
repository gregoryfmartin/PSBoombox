using namespace System
using namespace System.Reflection
using namespace System.Reflection.Emit
using namespace System.Runtime.InteropServices
using namespace System.Text

Set-StrictMode -Version Latest





###############################################################################
#
# MM WINMM NATIVE
#
# PURE POWERSHELL REFLECTION.EMIT P/INVOKE BINDINGS TO WINDOWS MULTIMEDIA
# LIBRARY (WINMM.DLL) WITH ZERO INLINE C# CODE.
#
###############################################################################

Class MMWinMMNative {
    Static [Type]$NativeWinMMType = $null

    Static [Type]GetNativeType() {
        If($null -NE [MMWinMMNative]::NativeWinMMType) {
            Return [MMWinMMNative]::NativeWinMMType
        }

        [AssemblyName]$AsmName    = [AssemblyName]::new('PSBoomboxWinMM')
        [AssemblyBuilder]$AsmBld  = [AssemblyBuilder]::DefineDynamicAssembly($AsmName, [AssemblyBuilderAccess]::Run)
        [ModuleBuilder]$ModBld    = $AsmBld.DefineDynamicModule('WinMM')
        [TypeAttributes]$TypeAttr = [TypeAttributes]::Public -BOR [TypeAttributes]::Abstract -BOR [TypeAttributes]::Sealed
        [TypeBuilder]$TypeBld     = $ModBld.DefineType('NativeWinMM', $TypeAttr)
        [MethodAttributes]$PAttr  = [MethodAttributes]::Public -BOR [MethodAttributes]::Static -BOR [MethodAttributes]::PinvokeImpl

        [MethodBuilder]$MciSendMethod = $TypeBld.DefinePInvokeMethod(
            'mciSendStringW',
            'winmm.dll',
            $PAttr,
            [CallingConventions]::Standard,
            [UInt32],
            [Type[]]@([String], [StringBuilder], [UInt32], [IntPtr]),
            [CallingConvention]::Winapi,
            [CharSet]::Unicode
        )
        $MciSendMethod.SetImplementationFlags($MciSendMethod.GetMethodImplementationFlags() -BOR [MethodImplAttributes]::PreserveSig)

        [MethodBuilder]$MciErrMethod = $TypeBld.DefinePInvokeMethod(
            'mciGetErrorStringW',
            'winmm.dll',
            $PAttr,
            [CallingConventions]::Standard,
            [Boolean],
            [Type[]]@([UInt32], [StringBuilder], [UInt32]),
            [CallingConvention]::Winapi,
            [CharSet]::Unicode
        )
        $MciErrMethod.SetImplementationFlags($MciErrMethod.GetMethodImplementationFlags() -BOR [MethodImplAttributes]::PreserveSig)

        [MethodBuilder]$GetVolMethod = $TypeBld.DefinePInvokeMethod(
            'waveOutGetVolume',
            'winmm.dll',
            $PAttr,
            [CallingConventions]::Standard,
            [UInt32],
            [Type[]]@([IntPtr], [UInt32].MakeByRefType()),
            [CallingConvention]::Winapi,
            [CharSet]::Auto
        )
        $GetVolMethod.SetImplementationFlags($GetVolMethod.GetMethodImplementationFlags() -BOR [MethodImplAttributes]::PreserveSig)

        [MethodBuilder]$SetVolMethod = $TypeBld.DefinePInvokeMethod(
            'waveOutSetVolume',
            'winmm.dll',
            $PAttr,
            [CallingConventions]::Standard,
            [UInt32],
            [Type[]]@([IntPtr], [UInt32]),
            [CallingConvention]::Winapi,
            [CharSet]::Auto
        )
        $SetVolMethod.SetImplementationFlags($SetVolMethod.GetMethodImplementationFlags() -BOR [MethodImplAttributes]::PreserveSig)

        [MethodBuilder]$ShortPathMethod = $TypeBld.DefinePInvokeMethod(
            'GetShortPathNameW',
            'kernel32.dll',
            $PAttr,
            [CallingConventions]::Standard,
            [UInt32],
            [Type[]]@([String], [StringBuilder], [UInt32]),
            [CallingConvention]::Winapi,
            [CharSet]::Unicode
        )
        $ShortPathMethod.SetImplementationFlags($ShortPathMethod.GetMethodImplementationFlags() -BOR [MethodImplAttributes]::PreserveSig)

        [MMWinMMNative]::NativeWinMMType = $TypeBld.CreateType()

        Return [MMWinMMNative]::NativeWinMMType
    }

    Static [String]GetErrorMessage(
        [UInt32]$ErrorCode
    ) {
        If($ErrorCode -EQ [UInt32]0) {
            Return ''
        }

        [Type]$NativeType          = [MMWinMMNative]::GetNativeType()
        [StringBuilder]$ErrBuilder = [StringBuilder]::new(512)
        [Boolean]$Success          = $NativeType::mciGetErrorStringW($ErrorCode, $ErrBuilder, [UInt32]$ErrBuilder.Capacity)

        If($Success -EQ $true) {
            Return $ErrBuilder.ToString().Trim()
        }

        Return "MCI error code $($ErrorCode)"
    }

    Static [Hashtable]SendCommand(
        [String]$Command
    ) {
        If(($null -EQ $Command) -OR ($Command.Length -EQ 0)) {
            Return @{
                Success      = $false
                ErrorCode    = [UInt32]1
                Output       = ''
                ErrorMessage = 'Empty MCI command.'
            }
        }

        [Type]$NativeType          = [MMWinMMNative]::GetNativeType()
        [StringBuilder]$OutBuilder = [StringBuilder]::new(512)
        [UInt32]$ReturnCode        = $NativeType::mciSendStringW($Command, $OutBuilder, [UInt32]$OutBuilder.Capacity, [IntPtr]::Zero)
        [Boolean]$Succeeded        = ($ReturnCode -EQ [UInt32]0)
        [String]$ErrorText         = ($Succeeded -EQ $true) ? '' : [MMWinMMNative]::GetErrorMessage($ReturnCode)

        Return @{
            Success      = $Succeeded
            ErrorCode    = $ReturnCode
            Output       = $OutBuilder.ToString().Trim()
            ErrorMessage = $ErrorText
        }
    }

    Static [UInt32]GetRawWaveVolume() {
        [Type]$NativeType = [MMWinMMNative]::GetNativeType()
        [UInt32]$RawVol   = [UInt32]0
        [UInt32]$Result   = $NativeType::waveOutGetVolume([IntPtr]::Zero, [Ref]$RawVol)

        If($Result -NE [UInt32]0) {
            Return [UInt32]0xFFFFFFFF
        }

        Return $RawVol
    }

    Static [Boolean]SetRawWaveVolume(
        [UInt32]$RawVolume
    ) {
        [Type]$NativeType = [MMWinMMNative]::GetNativeType()
        [UInt32]$Result   = $NativeType::waveOutSetVolume([IntPtr]::Zero, $RawVolume)

        Return ($Result -EQ [UInt32]0)
    }

    Static [Int]GetWaveVolumePercent() {
        [UInt32]$RawVolume = [MMWinMMNative]::GetRawWaveVolume()
        [UInt32]$LowWord   = $RawVolume -BAND [UInt32]0xFFFF
        [Int]$Percent      = [Int][Math]::Round(([Double]$LowWord / 65535.0) * 100.0)

        Return [Math]::Clamp($Percent, 0, 100)
    }

    Static [Boolean]SetWaveVolumePercent(
        [Int]$Percent
    ) {
        [Int]$Clamped    = [Math]::Clamp($Percent, 0, 100)
        [UInt32]$Channel = [UInt32][Math]::Round(([Double]$Clamped / 100.0) * 65535.0)
        [UInt64]$Packed  = ([UInt64]$Channel -SHL 16) -BOR [UInt64]$Channel
        [UInt32]$RawVol  = [UInt32]$Packed

        Return [MMWinMMNative]::SetRawWaveVolume($RawVol)
    }

    Static [String]GetShortPath(
        [String]$LongPath
    ) {
        If(($null -EQ $LongPath) -OR ($LongPath.Length -EQ 0)) {
            Return ''
        }

        [Type]$NativeType          = [MMWinMMNative]::GetNativeType()
        [StringBuilder]$OutBuilder = [StringBuilder]::new(512)
        [UInt32]$ResultLen         = $NativeType::GetShortPathNameW($LongPath, $OutBuilder, [UInt32]$OutBuilder.Capacity)

        If(($ResultLen -GT [UInt32]0) -AND ($ResultLen -LT [UInt32]$OutBuilder.Capacity)) {
            Return $OutBuilder.ToString()
        }

        Return $LongPath
    }
}
