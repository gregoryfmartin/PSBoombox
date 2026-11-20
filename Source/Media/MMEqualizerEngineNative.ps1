using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# MM EQUALIZER ENGINE NATIVE
#
# SCOPED C# NATIVE SUBSYSTEM PROVIDING:
#   1. WINDOWS MEDIA FOUNDATION DECODING, REAL-TIME 10-BAND ISO BIQUAD EQ +
#      PREAMP + SOFT LIMITER, 1024-PT FFT POST-EQ AUDIO ANALYZER, AND
#      60 HZ RING-BUFFERED WINMM WAVEOUT STREAMING.
#   2. 60 FPS DOUBLE-BUFFERED 24-BIT TRUECOLOR ANSI VISUALIZER CANVAS AND
#      PER-CELL RENDERING KERNELS.
#
###############################################################################

If($null -EQ ('PSBoombox.NativeAudioEngine' -AS [Type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace PSBoombox {
    [StructLayout(LayoutKind.Explicit, Size = 24)]
    internal struct PropVariant {
        [FieldOffset(0)]
        public ushort vt;

        [FieldOffset(8)]
        public long hVal;

        [FieldOffset(8)]
        public ulong uhVal;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WAVEFORMATEX {
        public ushort wFormatTag;
        public ushort nChannels;
        public uint nSamplesPerSec;
        public uint nAvgBytesPerSec;
        public ushort nBlockAlign;
        public ushort wBitsPerSample;
        public ushort cbSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WAVEHDR {
        public IntPtr lpData;
        public uint dwBufferLength;
        public uint dwBytesRecorded;
        public IntPtr dwUser;
        public uint dwFlags;
        public uint dwLoops;
        public IntPtr lpNext;
        public IntPtr reserved;
    }

    [ComImport]
    [Guid("2cd2d921-c447-44a7-a13c-4adabfc247e3")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFAttributes {
        [PreserveSig] int GetItem([In] ref Guid guidKey, IntPtr pValue);
        [PreserveSig] int GetItemType([In] ref Guid guidKey, out int pType);
        [PreserveSig] int CompareItem([In] ref Guid guidKey, IntPtr Value, [MarshalAs(UnmanagedType.Bool)] out bool pbResult);
        [PreserveSig] int Compare(IMFAttributes pTheirs, int MatchType, [MarshalAs(UnmanagedType.Bool)] out bool pbResult);
        [PreserveSig] int GetUINT32([In] ref Guid guidKey, out uint punValue);
        [PreserveSig] int GetUINT64([In] ref Guid guidKey, out ulong punValue);
        [PreserveSig] int GetDouble([In] ref Guid guidKey, out double pfValue);
        [PreserveSig] int GetGUID([In] ref Guid guidKey, out Guid pguidValue);
        [PreserveSig] int GetStringLength([In] ref Guid guidKey, out uint pcchLength);
        [PreserveSig] int GetString([In] ref Guid guidKey, IntPtr pwszValue, uint cchBufSize, out uint pcchLength);
        [PreserveSig] int GetAllocatedString([In] ref Guid guidKey, out IntPtr ppwszValue, out uint pcchLength);
        [PreserveSig] int GetBlobSize([In] ref Guid guidKey, out uint pcbBlobSize);
        [PreserveSig] int GetBlob([In] ref Guid guidKey, IntPtr pBuf, uint cbBufSize, out uint pcbBlobSize);
        [PreserveSig] int GetAllocatedBlob([In] ref Guid guidKey, out IntPtr ppBuf, out uint pcbSize);
        [PreserveSig] int GetUnknown([In] ref Guid guidKey, [In] ref Guid riid, out IntPtr ppv);
        [PreserveSig] int SetItem([In] ref Guid guidKey, IntPtr Value);
        [PreserveSig] int DeleteItem([In] ref Guid guidKey);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32([In] ref Guid guidKey, uint unValue);
        [PreserveSig] int SetUINT64([In] ref Guid guidKey, ulong unValue);
        [PreserveSig] int SetDouble([In] ref Guid guidKey, double fValue);
        [PreserveSig] int SetGUID([In] ref Guid guidKey, [In] ref Guid guidValue);
        [PreserveSig] int SetString([In] ref Guid guidKey, [MarshalAs(UnmanagedType.LPWStr)] string wszValue);
        [PreserveSig] int SetBlob([In] ref Guid guidKey, IntPtr pBuf, uint cbBufSize);
        [PreserveSig] int SetUnknown([In] ref Guid guidKey, [MarshalAs(UnmanagedType.IUnknown)] object pUnknown);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out uint pcItems);
        [PreserveSig] int GetItemByIndex(uint unIndex, out Guid pguidKey, IntPtr pValue);
        [PreserveSig] int CopyAllItems(IMFAttributes pDest);
    }

    [ComImport]
    [Guid("045fa593-8799-42b8-bc8d-8968c6453507")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFMediaBuffer {
        [PreserveSig] int Lock(out IntPtr ppbBuffer, out uint pcbMaxLength, out uint pcbCurrentLength);
        [PreserveSig] int Unlock();
        [PreserveSig] int GetCurrentLength(out uint pcbCurrentLength);
        [PreserveSig] int SetCurrentLength(uint cbCurrentLength);
        [PreserveSig] int GetMaxLength(out uint pcbMaxLength);
    }

    [ComImport]
    [Guid("c40a00f2-b93a-4d80-ae8c-5a1c634f58e4")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFSample {
        [PreserveSig] int GetItem([In] ref Guid guidKey, IntPtr pValue);
        [PreserveSig] int GetItemType([In] ref Guid guidKey, out int pType);
        [PreserveSig] int CompareItem([In] ref Guid guidKey, IntPtr Value, [MarshalAs(UnmanagedType.Bool)] out bool pbResult);
        [PreserveSig] int Compare(IMFAttributes pTheirs, int MatchType, [MarshalAs(UnmanagedType.Bool)] out bool pbResult);
        [PreserveSig] int GetUINT32([In] ref Guid guidKey, out uint punValue);
        [PreserveSig] int GetUINT64([In] ref Guid guidKey, out ulong punValue);
        [PreserveSig] int GetDouble([In] ref Guid guidKey, out double pfValue);
        [PreserveSig] int GetGUID([In] ref Guid guidKey, out Guid pguidValue);
        [PreserveSig] int GetStringLength([In] ref Guid guidKey, out uint pcchLength);
        [PreserveSig] int GetString([In] ref Guid guidKey, IntPtr pwszValue, uint cchBufSize, out uint pcchLength);
        [PreserveSig] int GetAllocatedString([In] ref Guid guidKey, out IntPtr ppwszValue, out uint pcchLength);
        [PreserveSig] int GetBlobSize([In] ref Guid guidKey, out uint pcbBlobSize);
        [PreserveSig] int GetBlob([In] ref Guid guidKey, IntPtr pBuf, uint cbBufSize, out uint pcbBlobSize);
        [PreserveSig] int GetAllocatedBlob([In] ref Guid guidKey, out IntPtr ppBuf, out uint pcbSize);
        [PreserveSig] int GetUnknown([In] ref Guid guidKey, [In] ref Guid riid, out IntPtr ppv);
        [PreserveSig] int SetItem([In] ref Guid guidKey, IntPtr Value);
        [PreserveSig] int DeleteItem([In] ref Guid guidKey);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32([In] ref Guid guidKey, uint unValue);
        [PreserveSig] int SetUINT64([In] ref Guid guidKey, ulong unValue);
        [PreserveSig] int SetDouble([In] ref Guid guidKey, double fValue);
        [PreserveSig] int SetGUID([In] ref Guid guidKey, [In] ref Guid guidValue);
        [PreserveSig] int SetString([In] ref Guid guidKey, [MarshalAs(UnmanagedType.LPWStr)] string wszValue);
        [PreserveSig] int SetBlob([In] ref Guid guidKey, IntPtr pBuf, uint cbBufSize);
        [PreserveSig] int SetUnknown([In] ref Guid guidKey, [MarshalAs(UnmanagedType.IUnknown)] object pUnknown);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out uint pcItems);
        [PreserveSig] int GetItemByIndex(uint unIndex, out Guid pguidKey, IntPtr pValue);
        [PreserveSig] int CopyAllItems(IMFAttributes pDest);
        [PreserveSig] int GetSampleFlags(out uint pdwSampleFlags);
        [PreserveSig] int SetSampleFlags(uint dwSampleFlags);
        [PreserveSig] int GetSampleTime(out long phnsSampleTime);
        [PreserveSig] int SetSampleTime(long hnsSampleTime);
        [PreserveSig] int GetSampleDuration(out long phnsSampleDuration);
        [PreserveSig] int SetSampleDuration(long hnsSampleDuration);
        [PreserveSig] int GetBufferCount(out uint pdwBufferCount);
        [PreserveSig] int GetBufferByIndex(uint dwIndex, out IMFMediaBuffer ppBuffer);
        [PreserveSig] int ConvertToContiguousBuffer(out IMFMediaBuffer ppBuffer);
        [PreserveSig] int AddBuffer(IMFMediaBuffer pBuffer);
        [PreserveSig] int RemoveBufferByIndex(uint dwIndex);
        [PreserveSig] int RemoveAllBuffers();
        [PreserveSig] int GetTotalLength(out uint pcbTotalLength);
        [PreserveSig] int CopyToBuffer(IMFMediaBuffer pBuffer);
    }

    [ComImport]
    [Guid("70ae66f2-c809-4e4f-8915-bdcb406b7993")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMFSourceReader {
        [PreserveSig] int GetStreamSelection(int dwStreamIndex, [MarshalAs(UnmanagedType.Bool)] out bool pfSelected);
        [PreserveSig] int SetStreamSelection(int dwStreamIndex, [MarshalAs(UnmanagedType.Bool)] bool fSelected);
        [PreserveSig] int GetNativeMediaType(int dwStreamIndex, int dwMediaTypeIndex, out IMFAttributes ppMediaType);
        [PreserveSig] int GetCurrentMediaType(int dwStreamIndex, out IMFAttributes ppMediaType);
        [PreserveSig] int SetCurrentMediaType(int dwStreamIndex, IntPtr pdwReserved, IMFAttributes pMediaType);
        [PreserveSig] int SetCurrentPosition([In] ref Guid guidTimeFormat, [In] ref PropVariant varPosition);
        [PreserveSig] int ReadSample(int dwStreamIndex, int dwControlFlags, out int pdwActualStreamIndex, out int pdwStreamFlags, out long pllTimestamp, out IMFSample ppSample);
        [PreserveSig] int Flush(int dwStreamIndex);
        [PreserveSig] int GetServiceForStream(int dwStreamIndex, [In] ref Guid guidService, [In] ref Guid riid, out IntPtr ppvObject);
        [PreserveSig] int GetPresentationAttribute(int dwStreamIndex, [In] ref Guid guidAttribute, out PropVariant pvarAttribute);
    }

    internal static class NativeImports {
        [DllImport("ole32.dll")]
        public static extern int CoInitializeEx(IntPtr pvReserved, uint dwCoInit);

        [DllImport("ole32.dll")]
        public static extern int PropVariantClear(ref PropVariant pvar);

        [DllImport("mfplat.dll")]
        public static extern int MFStartup(uint version, uint dwFlags);

        [DllImport("mfplat.dll")]
        public static extern int MFShutdown();

        [DllImport("mfplat.dll")]
        public static extern int MFCreateMediaType(out IMFAttributes ppMFType);

        [DllImport("mfreadwrite.dll", CharSet = CharSet.Unicode)]
        public static extern int MFCreateSourceReaderFromURL([MarshalAs(UnmanagedType.LPWStr)] string pwszURL, IntPtr pAttributes, out IMFSourceReader ppSourceReader);

        [DllImport("winmm.dll")]
        public static extern uint waveOutOpen(out IntPtr phwo, uint uDeviceID, ref WAVEFORMATEX pwfx, IntPtr dwCallback, IntPtr dwInstance, uint fdwOpen);

        [DllImport("winmm.dll")]
        public static extern uint waveOutPrepareHeader(IntPtr hwo, IntPtr pwh, uint cbwh);

        [DllImport("winmm.dll")]
        public static extern uint waveOutWrite(IntPtr hwo, IntPtr pwh, uint cbwh);

        [DllImport("winmm.dll")]
        public static extern uint waveOutPause(IntPtr hwo);

        [DllImport("winmm.dll")]
        public static extern uint waveOutRestart(IntPtr hwo);

        [DllImport("winmm.dll")]
        public static extern uint waveOutReset(IntPtr hwo);

        [DllImport("winmm.dll")]
        public static extern uint waveOutUnprepareHeader(IntPtr hwo, IntPtr pwh, uint cbwh);

        [DllImport("winmm.dll")]
        public static extern uint waveOutClose(IntPtr hwo);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool WriteConsoleW(
            IntPtr hConsoleOutput,
            [In] char[] lpBuffer,
            uint nNumberOfCharsToWrite,
            out uint lpNumberOfCharsWritten,
            IntPtr lpReserved
        );
    }

    public sealed class EqualizerDsp {
        public const int BandCount = 10;
        private const double BandQ = 1.4142135623730951;

        public static readonly double[] CenterFrequencies = new double[] {
            31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0
        };

        private readonly object _lock = new object();
        private bool _enabled;
        private double _preampDb;
        private readonly double[] _bandGainsDb = new double[BandCount];

        private int _sampleRate = 44100;
        private int _channels = 2;
        private readonly bool[] _bandActive = new bool[BandCount];
        private readonly double[] _b0 = new double[BandCount];
        private readonly double[] _b1 = new double[BandCount];
        private readonly double[] _b2 = new double[BandCount];
        private readonly double[] _a1 = new double[BandCount];
        private readonly double[] _a2 = new double[BandCount];
        private double[,] _z1 = new double[BandCount, 2];
        private double[,] _z2 = new double[BandCount, 2];

        public void ConfigureFormat(int sampleRate, int channels) {
            lock (_lock) {
                _sampleRate = Math.Max(8000, sampleRate);
                _channels = Math.Clamp(channels, 1, 2);
                _z1 = new double[BandCount, _channels];
                _z2 = new double[BandCount, _channels];
                RecomputeCoefficientsLocked();
            }
        }

        public void ResetStates() {
            lock (_lock) {
                Array.Clear(_z1, 0, _z1.Length);
                Array.Clear(_z2, 0, _z2.Length);
            }
        }

        public void SetParameters(bool enabled, double preampDb, double[] bandGainsDb) {
            lock (_lock) {
                _enabled = enabled;
                _preampDb = Math.Clamp(preampDb, -12.0, 12.0);
                for (int i = 0; i < BandCount; i++) {
                    double val = (bandGainsDb != null && i < bandGainsDb.Length) ? bandGainsDb[i] : 0.0;
                    _bandGainsDb[i] = Math.Clamp(val, -12.0, 12.0);
                }
                RecomputeCoefficientsLocked();
            }
        }

        private void RecomputeCoefficientsLocked() {
            double fs = _sampleRate;
            for (int i = 0; i < BandCount; i++) {
                double gainDb = _bandGainsDb[i];
                double fc = CenterFrequencies[i];
                if (Math.Abs(gainDb) < 0.001 || fc >= fs * 0.48) {
                    _bandActive[i] = false;
                    _b0[i] = 1.0;
                    _b1[i] = 0.0;
                    _b2[i] = 0.0;
                    _a1[i] = 0.0;
                    _a2[i] = 0.0;
                    continue;
                }

                // RBJ AUDIO EQ COOKBOOK PEAKING FILTER
                double a = Math.Pow(10.0, gainDb / 40.0);
                double w0 = (2.0 * Math.PI * fc) / fs;
                double cosW0 = Math.Cos(w0);
                double alpha = Math.Sin(w0) / (2.0 * BandQ);

                double b0 = 1.0 + alpha * a;
                double b1 = -2.0 * cosW0;
                double b2 = 1.0 - alpha * a;
                double a0 = 1.0 + alpha / a;
                double a1 = -2.0 * cosW0;
                double a2 = 1.0 - alpha / a;

                _b0[i] = b0 / a0;
                _b1[i] = b1 / a0;
                _b2[i] = b2 / a0;
                _a1[i] = a1 / a0;
                _a2[i] = a2 / a0;
                _bandActive[i] = true;
            }
        }

        public void ProcessInterleavedFloat(float[] samples, int frameCount, int channels, double volumeLinear, bool muted) {
            float dummyLeft;
            float dummyRight;
            ProcessInterleavedFloat(samples, frameCount, channels, volumeLinear, muted, null, out dummyLeft, out dummyRight);
        }

        public void ProcessInterleavedFloat(
            float[] samples,
            int frameCount,
            int channels,
            double volumeLinear,
            bool muted,
            float[] postEqMonoOut,
            out float leftRms,
            out float rightRms
        ) {
            leftRms = 0.0f;
            rightRms = 0.0f;
            if (samples == null || frameCount <= 0) {
                return;
            }

            bool enabled;
            double preampLinear;
            bool[] activeCopy = new bool[BandCount];
            double[] b0 = new double[BandCount];
            double[] b1 = new double[BandCount];
            double[] b2 = new double[BandCount];
            double[] a1 = new double[BandCount];
            double[] a2 = new double[BandCount];

            lock (_lock) {
                enabled = _enabled;
                preampLinear = enabled ? Math.Pow(10.0, _preampDb / 20.0) : 1.0;
                Array.Copy(_bandActive, activeCopy, BandCount);
                Array.Copy(_b0, b0, BandCount);
                Array.Copy(_b1, b1, BandCount);
                Array.Copy(_b2, b2, BandCount);
                Array.Copy(_a1, a1, BandCount);
                Array.Copy(_a2, a2, BandCount);
            }

            double gainVol = muted ? 0.0 : Math.Clamp(volumeLinear, 0.0, 1.0);
            int chCount = Math.Clamp(channels, 1, 2);
            double leftSq = 0.0;
            double rightSq = 0.0;

            for (int f = 0; f < frameCount; f++) {
                int baseIdx = f * chCount;
                double monoSum = 0.0;
                double ch0Pre = 0.0;
                double ch1Pre = 0.0;

                for (int c = 0; c < chCount; c++) {
                    double x = samples[baseIdx + c];
                    if (enabled) {
                        x *= preampLinear;
                        for (int b = 0; b < BandCount; b++) {
                            if (!activeCopy[b]) {
                                continue;
                            }
                            double z1 = _z1[b, c];
                            double z2 = _z2[b, c];
                            double y = (b0[b] * x) + z1;
                            _z1[b, c] = (b1[b] * x) - (a1[b] * y) + z2;
                            _z2[b, c] = (b2[b] * x) - (a2[b] * y);
                            x = y;
                        }
                    }

                    double postEq = SoftClip(x);
                    monoSum += postEq;
                    if (c == 0) {
                        ch0Pre = postEq;
                    } else {
                        ch1Pre = postEq;
                    }

                    double finalOut = SoftClip(postEq * gainVol);
                    samples[baseIdx + c] = (float)finalOut;
                }

                if (postEqMonoOut != null && f < postEqMonoOut.Length) {
                    postEqMonoOut[f] = muted ? 0.0f : (float)(monoSum / chCount);
                }

                if (!muted) {
                    leftSq += ch0Pre * ch0Pre;
                    double rSample = (chCount == 1) ? ch0Pre : ch1Pre;
                    rightSq += rSample * rSample;
                }
            }

            if (!muted) {
                leftRms = (float)Math.Clamp(Math.Sqrt(leftSq / frameCount) * 2.2, 0.0, 1.0);
                rightRms = (float)Math.Clamp(Math.Sqrt(rightSq / frameCount) * 2.2, 0.0, 1.0);
            }
        }

        private static double SoftClip(double x) {
            if (x > 0.9) {
                return 0.9 + (0.1 * Math.Tanh((x - 0.9) / 0.1));
            }
            if (x < -0.9) {
                return -0.9 - (0.1 * Math.Tanh(((-x) - 0.9) / 0.1));
            }
            return x;
        }

        public static float[] ProcessBufferForTest(
            float[] inputSamples,
            int sampleRate,
            int channels,
            bool enabled,
            double preampDb,
            double[] bandGainsDb
        ) {
            float[] copy = new float[inputSamples.Length];
            Array.Copy(inputSamples, copy, inputSamples.Length);
            EqualizerDsp dsp = new EqualizerDsp();
            dsp.ConfigureFormat(sampleRate, channels);
            dsp.SetParameters(enabled, preampDb, bandGainsDb);
            int frameCount = copy.Length / Math.Max(1, channels);
            dsp.ProcessInterleavedFloat(copy, frameCount, channels, 1.0, false);
            return copy;
        }
    }

    public sealed class AudioAnalyzer {
        public const int FftSize = 1024;
        private readonly object _lock = new object();
        private readonly float[] _ring = new float[FftSize];
        private readonly double[] _hann = new double[FftSize];
        private readonly double[] _fftRe = new double[FftSize];
        private readonly double[] _fftIm = new double[FftSize];
        private readonly double[] _binMags = new double[FftSize / 2];
        private int _writePos;
        private int _sampleRate = 44100;
        private float _leftRms;
        private float _rightRms;
        private float _bassSmooth;
        private float _midSmooth;
        private float _trebleSmooth;
        private float[] _smoothedBars = new float[0];
        private long _ringVersion;
        private long _fftVersion = -1;

        public AudioAnalyzer() {
            for (int i = 0; i < FftSize; i++) {
                _hann[i] = 0.5 * (1.0 - Math.Cos((2.0 * Math.PI * i) / (FftSize - 1)));
            }
        }

        public void Configure(int sampleRate) {
            lock (_lock) {
                _sampleRate = Math.Max(8000, sampleRate);
            }
        }

        public void Reset() {
            lock (_lock) {
                Array.Clear(_ring, 0, _ring.Length);
                _writePos = 0;
                _leftRms = 0.0f;
                _rightRms = 0.0f;
                _bassSmooth = 0.0f;
                _midSmooth = 0.0f;
                _trebleSmooth = 0.0f;
                _ringVersion = 0;
                _fftVersion = -1;
                if (_smoothedBars.Length > 0) {
                    Array.Clear(_smoothedBars, 0, _smoothedBars.Length);
                }
            }
        }

        public void PushBlock(float[] monoSamples, int count, float leftRms, float rightRms) {
            if (monoSamples == null || count <= 0) {
                return;
            }
            lock (_lock) {
                int len = Math.Min(count, monoSamples.Length);
                for (int i = 0; i < len; i++) {
                    _ring[_writePos] = monoSamples[i];
                    _writePos = (_writePos + 1) % FftSize;
                }
                _leftRms = leftRms;
                _rightRms = rightRms;
                _ringVersion++;
            }
        }

        private void ComputeFftBinsLocked() {
            if (_fftVersion == _ringVersion) {
                return;
            }
            for (int i = 0; i < FftSize; i++) {
                int srcIdx = (_writePos + i) % FftSize;
                _fftRe[i] = _ring[srcIdx] * _hann[i];
                _fftIm[i] = 0.0;
            }
            RunRadix2Fft(_fftRe, _fftIm);

            int half = FftSize / 2;
            double scale = 4.0 / FftSize;
            for (int k = 0; k < half; k++) {
                double re = _fftRe[k];
                double im = _fftIm[k];
                _binMags[k] = Math.Sqrt((re * re) + (im * im)) * scale;
            }
            _fftVersion = _ringVersion;
        }

        private static void RunRadix2Fft(double[] re, double[] im) {
            int n = FftSize;
            int j = 0;
            for (int i = 0; i < n; i++) {
                if (i < j) {
                    double tr = re[i];
                    re[i] = re[j];
                    re[j] = tr;
                    double ti = im[i];
                    im[i] = im[j];
                    im[j] = ti;
                }
                int m = n >> 1;
                while (m >= 1 && j >= m) {
                    j -= m;
                    m >>= 1;
                }
                j += m;
            }

            for (int step = 2; step <= n; step <<= 1) {
                int halfStep = step >> 1;
                double angle = -2.0 * Math.PI / step;
                double wStepRe = Math.Cos(angle);
                double wStepIm = Math.Sin(angle);

                for (int start = 0; start < n; start += step) {
                    double wRe = 1.0;
                    double wIm = 0.0;
                    for (int k = 0; k < halfStep; k++) {
                        int evenIdx = start + k;
                        int oddIdx = evenIdx + halfStep;
                        double tRe = (wRe * re[oddIdx]) - (wIm * im[oddIdx]);
                        double tIm = (wRe * im[oddIdx]) + (wIm * re[oddIdx]);

                        re[oddIdx] = re[evenIdx] - tRe;
                        im[oddIdx] = im[evenIdx] - tIm;
                        re[evenIdx] += tRe;
                        im[evenIdx] += tIm;

                        double nextWRe = (wRe * wStepRe) - (wIm * wStepIm);
                        wIm = (wRe * wStepIm) + (wIm * wStepRe);
                        wRe = nextWRe;
                    }
                }
            }
        }

        private float[] MapBarsLocked(int barCount) {
            float[] bars = new float[barCount];
            double minFreq = 30.0;
            double maxFreq = Math.Min(16000.0, _sampleRate * 0.48);
            if (maxFreq <= minFreq) {
                maxFreq = minFreq + 100.0;
            }

            double binHz = (double)_sampleRate / FftSize;
            int maxBin = (FftSize / 2) - 1;

            for (int b = 0; b < barCount; b++) {
                double fLow = minFreq * Math.Pow(maxFreq / minFreq, (double)b / barCount);
                double fHigh = minFreq * Math.Pow(maxFreq / minFreq, (double)(b + 1) / barCount);
                int kLow = Math.Clamp((int)Math.Floor(fLow / binHz), 1, maxBin);
                int kHigh = Math.Clamp((int)Math.Ceiling(fHigh / binHz), kLow, maxBin);

                double peak = 0.0;
                for (int k = kLow; k <= kHigh; k++) {
                    if (_binMags[k] > peak) {
                        peak = _binMags[k];
                    }
                }

                double db = 20.0 * Math.Log10(peak + 1e-6);
                float norm = (float)Math.Clamp((db + 54.0) / 54.0, 0.0, 1.0);
                bars[b] = norm;
            }

            return bars;
        }

        public float[] GetSpectrumSnapshot(int barCount) {
            if (barCount <= 0) {
                return new float[0];
            }

            lock (_lock) {
                ComputeFftBinsLocked();
                float[] target = MapBarsLocked(barCount);

                if (_smoothedBars.Length != barCount) {
                    _smoothedBars = new float[barCount];
                }

                for (int i = 0; i < barCount; i++) {
                    float cur = _smoothedBars[i];
                    float nxt = target[i];
                    _smoothedBars[i] = (nxt >= cur)
                        ? (cur + ((nxt - cur) * 0.55f))
                        : (cur + ((nxt - cur) * 0.18f));
                }

                float[] copy = new float[barCount];
                Array.Copy(_smoothedBars, copy, barCount);
                return copy;
            }
        }

        public float[] GetWaveformSnapshot(int sampleCount) {
            if (sampleCount <= 0) {
                return new float[0];
            }

            lock (_lock) {
                float[] outWave = new float[sampleCount];
                int span = Math.Min(512, FftSize);
                int startPos = (_writePos - span + FftSize) % FftSize;

                for (int i = 0; i < sampleCount; i++) {
                    double t = (sampleCount == 1) ? 0.0 : ((double)i / (sampleCount - 1)) * (span - 1);
                    int idx0 = (int)Math.Floor(t);
                    int idx1 = Math.Min(span - 1, idx0 + 1);
                    double frac = t - idx0;

                    float s0 = _ring[(startPos + idx0) % FftSize];
                    float s1 = _ring[(startPos + idx1) % FftSize];
                    outWave[i] = Math.Clamp((float)(s0 + ((s1 - s0) * frac)), -1.0f, 1.0f);
                }

                return outWave;
            }
        }

        public float[] GetAudioMetrics() {
            lock (_lock) {
                ComputeFftBinsLocked();
                double binHz = (double)_sampleRate / FftSize;
                int maxBin = (FftSize / 2) - 1;

                double bassSum = 0.0;
                int bassCnt = 0;
                double midSum = 0.0;
                int midCnt = 0;
                double trebleSum = 0.0;
                int trebleCnt = 0;

                for (int k = 1; k <= maxBin; k++) {
                    double freq = k * binHz;
                    double mag = _binMags[k];
                    if (freq < 250.0) {
                        bassSum += mag * mag;
                        bassCnt++;
                    } else if (freq <= 4000.0) {
                        midSum += mag * mag;
                        midCnt++;
                    } else {
                        trebleSum += mag * mag;
                        trebleCnt++;
                    }
                }

                float bassTarget = (float)Math.Clamp((20.0 * Math.Log10(Math.Sqrt(bassSum / Math.Max(1, bassCnt)) + 1e-6) + 54.0) / 54.0, 0.0, 1.0);
                float midTarget = (float)Math.Clamp((20.0 * Math.Log10(Math.Sqrt(midSum / Math.Max(1, midCnt)) + 1e-6) + 54.0) / 54.0, 0.0, 1.0);
                float trebleTarget = (float)Math.Clamp((20.0 * Math.Log10(Math.Sqrt(trebleSum / Math.Max(1, trebleCnt)) + 1e-6) + 54.0) / 54.0, 0.0, 1.0);

                _bassSmooth = (bassTarget >= _bassSmooth) ? (_bassSmooth + ((bassTarget - _bassSmooth) * 0.52f)) : (_bassSmooth + ((bassTarget - _bassSmooth) * 0.16f));
                _midSmooth = (midTarget >= _midSmooth) ? (_midSmooth + ((midTarget - _midSmooth) * 0.52f)) : (_midSmooth + ((midTarget - _midSmooth) * 0.16f));
                _trebleSmooth = (trebleTarget >= _trebleSmooth) ? (_trebleSmooth + ((trebleTarget - _trebleSmooth) * 0.52f)) : (_trebleSmooth + ((trebleTarget - _trebleSmooth) * 0.16f));

                return new float[] { _leftRms, _rightRms, _bassSmooth, _midSmooth, _trebleSmooth };
            }
        }

        public static float[] AnalyzeBufferForTest(
            float[] inputSamples,
            int sampleRate,
            int channels,
            int barCount,
            bool eqEnabled,
            double preampDb,
            double[] bandGainsDb
        ) {
            if (inputSamples == null || inputSamples.Length == 0 || barCount <= 0) {
                return new float[Math.Max(0, barCount)];
            }

            float[] copy = new float[inputSamples.Length];
            Array.Copy(inputSamples, copy, inputSamples.Length);
            int ch = Math.Max(1, channels);
            int frames = copy.Length / ch;
            float[] mono = new float[frames];
            float dummyL;
            float dummyR;

            EqualizerDsp dsp = new EqualizerDsp();
            dsp.ConfigureFormat(sampleRate, ch);
            dsp.SetParameters(eqEnabled, preampDb, bandGainsDb);
            dsp.ProcessInterleavedFloat(copy, frames, ch, 1.0, false, mono, out dummyL, out dummyR);

            AudioAnalyzer analyzer = new AudioAnalyzer();
            analyzer.Configure(sampleRate);
            analyzer.PushBlock(mono, frames, dummyL, dummyR);
            lock (analyzer._lock) {
                analyzer.ComputeFftBinsLocked();
                return analyzer.MapBarsLocked(barCount);
            }
        }
    }

    public sealed class NativeAudioEngine : IDisposable {
        private static readonly Guid MF_MT_MAJOR_TYPE = new Guid("48eba18e-f8c9-4687-bf11-0a74c9f96a8f");
        private static readonly Guid MF_MT_SUBTYPE = new Guid("f7e34c9a-42e8-4714-b74b-cb29d72c35e5");
        private static readonly Guid MFMediaType_Audio = new Guid("73647561-0000-0010-8000-00aa00389b71");
        private static readonly Guid MFAudioFormat_Float = new Guid("00000003-0000-0010-8000-00aa00389b71");
        private static readonly Guid MFAudioFormat_PCM = new Guid("00000001-0000-0010-8000-00aa00389b71");
        private static readonly Guid MF_MT_AUDIO_NUM_CHANNELS = new Guid("37e48bf5-645e-4c5b-89de-ada9e29b696a");
        private static readonly Guid MF_MT_AUDIO_SAMPLES_PER_SECOND = new Guid("5faeeae7-0290-4c31-9e8a-c534f68d9dba");
        private static readonly Guid MF_MT_AUDIO_BITS_PER_SAMPLE = new Guid("f2deb57f-40fa-4764-aa33-ed4f2d1ff669");
        private static readonly Guid MF_PD_DURATION = new Guid("6c990d33-bb8e-477a-8598-0d5d96fcd88a");

        private const int MF_SOURCE_READER_ALL_STREAMS = unchecked((int)0xFFFFFFFE);
        private const int MF_SOURCE_READER_FIRST_AUDIO_STREAM = unchecked((int)0xFFFFFFFD);
        private const int MF_SOURCE_READER_MEDIASOURCE = unchecked((int)0xFFFFFFFF);
        private const int MF_SOURCE_READERF_ENDOFSTREAM = 0x00000002;
        private const int MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED = 0x00000020;
        private const uint MF_SDK_VERSION = 0x00020070;
        private const uint WAVE_MAPPER = unchecked((uint)-1);
        private const uint CALLBACK_EVENT = 0x00050000;
        private const uint WHDR_DONE = 0x00000001;
        private const int BufferCount = 6;

        private enum CommandType {
            Load,
            Pause,
            Resume,
            Seek,
            Stop,
            Dispose
        }

        private sealed class EngineCommand {
            public CommandType Type;
            public string FilePath;
            public int SeekMs;
            public bool Result;
            public string ErrorMessage;
            public readonly ManualResetEventSlim Done = new ManualResetEventSlim(false);
        }

        private sealed class WaveBufferSlot {
            public byte[] PcmData;
            public GCHandle PcmPin;
            public IntPtr HdrPtr;
            public bool Prepared;
            public bool InFlight;
            public int FramesInBuffer;
            public float[] PostEqMono;
            public int PostEqFrames;
            public float LeftRms;
            public float RightRms;
            public bool AnalysisPushed;
            public long Sequence;
        }

        private readonly EqualizerDsp _dsp = new EqualizerDsp();
        private readonly AudioAnalyzer _analyzer = new AudioAnalyzer();
        private readonly object _cmdLock = new object();
        private readonly Queue<EngineCommand> _cmdQueue = new Queue<EngineCommand>();
        private readonly AutoResetEvent _wakeEvent = new AutoResetEvent(false);
        private readonly AutoResetEvent _waveEvent = new AutoResetEvent(false);
        private readonly Thread _workerThread;

        private volatile bool _disposed;
        private volatile int _durationMs;
        private volatile int _positionMs;
        private volatile bool _isLoaded;
        private volatile bool _isPlaying;
        private volatile bool _isPaused;
        private volatile bool _hasTrackEnded;
        private string _lastError = string.Empty;

        private int _volumePercent = 70;
        private bool _isMuted;

        // WORKER-THREAD ONLY STATE
        private bool _mfStarted;
        private IMFSourceReader _reader;
        private IntPtr _hWaveOut = IntPtr.Zero;
        private WaveBufferSlot[] _slots;
        private int _sourceChannels = 2;
        private int _outputChannels = 2;
        private int _sampleRate = 44100;
        private bool _sourceIsFloat = true;
        private int _sourceBitsPerSample = 32;
        private int _framesPerBuffer = 735;
        private bool _endOfStream;
        private long _seekBaseMs;
        private long _completedFrames;
        private long _nextSlotSequence;
        private bool _needsFlushOnResume;
        private float[] _pendingFloat = new float[0];
        private int _pendingFloatOffset;
        private int _pendingFloatCount;
        private float[] _dspWorkBuffer = new float[4096];

        public NativeAudioEngine() {
            _workerThread = new Thread(WorkerLoop);
            _workerThread.IsBackground = true;
            _workerThread.Name = "PSBoomboxAudioWorker";
            _workerThread.Start();
        }

        public int DurationMs { get { return _durationMs; } }
        public int PositionMs { get { return _positionMs; } }
        public bool IsLoaded { get { return _isLoaded; } }
        public bool IsPlaying { get { return _isPlaying; } }
        public bool IsPaused { get { return _isPaused; } }
        public bool HasTrackEnded { get { return _hasTrackEnded; } }
        public string LastError { get { return _lastError ?? string.Empty; } }

        public void SetVolume(int percent, bool muted) {
            Volatile.Write(ref _volumePercent, Math.Clamp(percent, 0, 100));
            _isMuted = muted;
        }

        public void SetEqualizerState(bool enabled, double preampDb, double[] bandGainsDb) {
            _dsp.SetParameters(enabled, preampDb, bandGainsDb);
        }

        public float[] GetSpectrumSnapshot(int barCount) {
            return _analyzer.GetSpectrumSnapshot(barCount);
        }

        public float[] GetWaveformSnapshot(int sampleCount) {
            return _analyzer.GetWaveformSnapshot(sampleCount);
        }

        public float[] GetAudioMetrics() {
            return _analyzer.GetAudioMetrics();
        }

        public bool LoadAndPlay(string filePath) {
            if (_disposed) {
                _lastError = "Audio engine has been disposed.";
                return false;
            }
            EngineCommand cmd = new EngineCommand { Type = CommandType.Load, FilePath = filePath };
            EnqueueAndWait(cmd, 8000);
            if (!cmd.Result) {
                _lastError = cmd.ErrorMessage ?? "Unable to load track.";
            }
            return cmd.Result;
        }

        public bool Pause() {
            if (_disposed) {
                return false;
            }
            EngineCommand cmd = new EngineCommand { Type = CommandType.Pause };
            EnqueueAndWait(cmd, 3000);
            return cmd.Result;
        }

        public bool Resume() {
            if (_disposed) {
                return false;
            }
            EngineCommand cmd = new EngineCommand { Type = CommandType.Resume };
            EnqueueAndWait(cmd, 3000);
            return cmd.Result;
        }

        public bool Seek(int targetMs) {
            if (_disposed) {
                return false;
            }
            EngineCommand cmd = new EngineCommand { Type = CommandType.Seek, SeekMs = targetMs };
            EnqueueAndWait(cmd, 4000);
            return cmd.Result;
        }

        public void Stop() {
            if (_disposed) {
                return;
            }
            EngineCommand cmd = new EngineCommand { Type = CommandType.Stop };
            EnqueueAndWait(cmd, 3000);
        }

        public void Dispose() {
            if (_disposed) {
                return;
            }
            _disposed = true;
            EngineCommand cmd = new EngineCommand { Type = CommandType.Dispose };
            lock (_cmdLock) {
                _cmdQueue.Enqueue(cmd);
            }
            _wakeEvent.Set();
            if (!_workerThread.Join(3000)) {
                try {
                    cmd.Done.Wait(500);
                } catch {
                    // IGNORE WAIT ERRORS ON SHUTDOWN
                }
            }
            _wakeEvent.Dispose();
            _waveEvent.Dispose();
        }

        private void EnqueueAndWait(EngineCommand cmd, int timeoutMs) {
            lock (_cmdLock) {
                _cmdQueue.Enqueue(cmd);
            }
            _wakeEvent.Set();
            if (!cmd.Done.Wait(timeoutMs)) {
                cmd.Result = false;
                cmd.ErrorMessage = "Audio worker command timed out.";
            }
        }

        private void WorkerLoop() {
            NativeImports.CoInitializeEx(IntPtr.Zero, 0);
            int mfHr = NativeImports.MFStartup(MF_SDK_VERSION, 0);
            _mfStarted = (mfHr >= 0);

            WaitHandle[] waitHandles = new WaitHandle[] { _wakeEvent, _waveEvent };
            bool exitLoop = false;

            while (!exitLoop) {
                EngineCommand cmd = null;
                lock (_cmdLock) {
                    if (_cmdQueue.Count > 0) {
                        cmd = _cmdQueue.Dequeue();
                    }
                }

                if (cmd != null) {
                    switch (cmd.Type) {
                        case CommandType.Load:
                            cmd.Result = ExecuteLoad(cmd.FilePath, out cmd.ErrorMessage);
                            cmd.Done.Set();
                            break;
                        case CommandType.Pause:
                            cmd.Result = ExecutePause();
                            cmd.Done.Set();
                            break;
                        case CommandType.Resume:
                            cmd.Result = ExecuteResume();
                            cmd.Done.Set();
                            break;
                        case CommandType.Seek:
                            cmd.Result = ExecuteSeek(cmd.SeekMs);
                            cmd.Done.Set();
                            break;
                        case CommandType.Stop:
                            ExecuteStop();
                            cmd.Result = true;
                            cmd.Done.Set();
                            break;
                        case CommandType.Dispose:
                            ExecuteStop();
                            cmd.Result = true;
                            cmd.Done.Set();
                            exitLoop = true;
                            break;
                    }
                    continue;
                }

                if (_isPlaying && !_isPaused && _hWaveOut != IntPtr.Zero) {
                    PumpAudioBuffers();
                }

                if (!exitLoop) {
                    int waitMs = (_isPlaying && !_isPaused) ? 8 : 100;
                    WaitHandle.WaitAny(waitHandles, waitMs);
                }
            }

            if (_mfStarted) {
                NativeImports.MFShutdown();
                _mfStarted = false;
            }
        }

        private bool ConfigureReaderOutputType(
            IMFSourceReader reader,
            uint requestedSampleRate,
            out int sourceChannels,
            out int sampleRate,
            out bool isFloat,
            out int bitsPerSample,
            out string errorMsg
        ) {
            sourceChannels = 2;
            sampleRate = 44100;
            isFloat = true;
            bitsPerSample = 32;
            errorMsg = string.Empty;

            bool configured = false;
            int lastHr = 0;

            Guid[] subTypes = new Guid[] { MFAudioFormat_Float, MFAudioFormat_PCM };
            for (int attempt = 0; attempt < subTypes.Length; attempt++) {
                IMFAttributes targetType = null;
                try {
                    int hr = NativeImports.MFCreateMediaType(out targetType);
                    if (hr < 0 || targetType == null) {
                        errorMsg = string.Format("MFCreateMediaType failed (0x{0:X8}).", hr);
                        return false;
                    }

                    Guid majorType = MFMediaType_Audio;
                    Guid subType = subTypes[attempt];
                    targetType.SetGUID(MF_MT_MAJOR_TYPE, ref majorType);
                    targetType.SetGUID(MF_MT_SUBTYPE, ref subType);
                    if (requestedSampleRate > 0) {
                        targetType.SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, requestedSampleRate);
                    }

                    lastHr = reader.SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, IntPtr.Zero, targetType);
                    if (lastHr >= 0) {
                        configured = true;
                        break;
                    }
                } finally {
                    if (targetType != null) Marshal.ReleaseComObject(targetType);
                }
            }

            if (!configured) {
                errorMsg = string.Format("SetCurrentMediaType(Float/PCM) failed (0x{0:X8}).", lastHr);
                return false;
            }

            IMFAttributes actualType = null;
            try {
                int hr = reader.GetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, out actualType);
                if (hr < 0 || actualType == null) {
                    errorMsg = string.Format("GetCurrentMediaType failed (0x{0:X8}).", hr);
                    return false;
                }

                Guid actualSubType = MFAudioFormat_Float;
                if (actualType.GetGUID(MF_MT_SUBTYPE, out actualSubType) >= 0) {
                    isFloat = (actualSubType == MFAudioFormat_Float);
                }

                uint ch = 2;
                uint sr = 44100;
                uint bps = isFloat ? 32u : 16u;
                actualType.GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, out ch);
                actualType.GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, out sr);
                actualType.GetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, out bps);

                sourceChannels = Math.Max(1, (int)ch);
                sampleRate = Math.Max(8000, (int)sr);
                bitsPerSample = (bps == 8 || bps == 16 || bps == 24 || bps == 32) ? (int)bps : (isFloat ? 32 : 16);
                return true;
            } finally {
                if (actualType != null) Marshal.ReleaseComObject(actualType);
            }
        }

        private bool ExecuteLoad(string filePath, out string errorMsg) {
            errorMsg = string.Empty;
            ExecuteStop();

            if (!_mfStarted) {
                errorMsg = "Windows Media Foundation failed to initialize.";
                return false;
            }

            if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) {
                errorMsg = "Audio file not found.";
                return false;
            }

            IMFSourceReader reader = null;

            try {
                int hr = NativeImports.MFCreateSourceReaderFromURL(filePath, IntPtr.Zero, out reader);
                if (hr < 0 || reader == null) {
                    errorMsg = string.Format("MFCreateSourceReaderFromURL failed (0x{0:X8}).", hr);
                    return false;
                }

                reader.SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS, false);
                hr = reader.SetStreamSelection(MF_SOURCE_READER_FIRST_AUDIO_STREAM, true);
                if (hr < 0) {
                    errorMsg = string.Format("No audio stream found (0x{0:X8}).", hr);
                    return false;
                }

                if (!ConfigureReaderOutputType(reader, 0, out _sourceChannels, out _sampleRate, out _sourceIsFloat, out _sourceBitsPerSample, out errorMsg)) {
                    return false;
                }

                _outputChannels = (_sourceChannels == 1) ? 1 : 2;
                _framesPerBuffer = Math.Max(256, _sampleRate / 60);

                int durationMs = 0;
                PropVariant durVar = new PropVariant();
                Guid durationKey = MF_PD_DURATION;
                int durHr = reader.GetPresentationAttribute(MF_SOURCE_READER_MEDIASOURCE, ref durationKey, out durVar);
                if (durHr >= 0) {
                    if (durVar.vt == 21) {
                        durationMs = (int)(durVar.uhVal / 10000UL);
                    } else if (durVar.vt == 20 && durVar.hVal > 0) {
                        durationMs = (int)(durVar.hVal / 10000L);
                    }
                }
                NativeImports.PropVariantClear(ref durVar);

                WAVEFORMATEX wfx = new WAVEFORMATEX {
                    wFormatTag = 1,
                    nChannels = (ushort)_outputChannels,
                    nSamplesPerSec = (uint)_sampleRate,
                    wBitsPerSample = 16,
                    nBlockAlign = (ushort)(_outputChannels * 2),
                    nAvgBytesPerSec = (uint)(_sampleRate * _outputChannels * 2),
                    cbSize = 0
                };

                IntPtr hWave = IntPtr.Zero;
                uint mmRes = NativeImports.waveOutOpen(
                    out hWave,
                    WAVE_MAPPER,
                    ref wfx,
                    _waveEvent.SafeWaitHandle.DangerousGetHandle(),
                    IntPtr.Zero,
                    CALLBACK_EVENT
                );

                if ((mmRes != 0 || hWave == IntPtr.Zero) && _sampleRate != 48000) {
                    string resampleErr;
                    if (ConfigureReaderOutputType(reader, 48000, out _sourceChannels, out _sampleRate, out _sourceIsFloat, out _sourceBitsPerSample, out resampleErr)) {
                        _outputChannels = (_sourceChannels == 1) ? 1 : 2;
                        _framesPerBuffer = Math.Max(256, _sampleRate / 60);
                        wfx.nChannels = (ushort)_outputChannels;
                        wfx.nSamplesPerSec = (uint)_sampleRate;
                        wfx.nBlockAlign = (ushort)(_outputChannels * 2);
                        wfx.nAvgBytesPerSec = (uint)(_sampleRate * _outputChannels * 2);
                        mmRes = NativeImports.waveOutOpen(
                            out hWave,
                            WAVE_MAPPER,
                            ref wfx,
                            _waveEvent.SafeWaitHandle.DangerousGetHandle(),
                            IntPtr.Zero,
                            CALLBACK_EVENT
                        );
                    }
                }

                if (mmRes != 0 || hWave == IntPtr.Zero) {
                    errorMsg = string.Format("waveOutOpen failed (error {0}).", mmRes);
                    return false;
                }

                _reader = reader;
                reader = null;
                _hWaveOut = hWave;

                AllocateWaveSlots();
                _dsp.ConfigureFormat(_sampleRate, _outputChannels);
                _dsp.ResetStates();
                _analyzer.Configure(_sampleRate);
                _analyzer.Reset();

                _pendingFloatOffset = 0;
                _pendingFloatCount = 0;
                _endOfStream = false;
                _seekBaseMs = 0;
                _completedFrames = 0;
                _nextSlotSequence = 0;
                _needsFlushOnResume = false;
                _hasTrackEnded = false;

                _durationMs = durationMs;
                _positionMs = 0;
                _isLoaded = true;
                _isPaused = false;
                _isPlaying = true;
                _lastError = string.Empty;

                PumpAudioBuffers();
                return true;
            } catch (Exception ex) {
                errorMsg = ex.Message;
                ExecuteStop();
                return false;
            } finally {
                if (reader != null) Marshal.ReleaseComObject(reader);
            }
        }

        private void AllocateWaveSlots() {
            int bytesPerSlot = _framesPerBuffer * _outputChannels * 2;
            int hdrSize = Marshal.SizeOf(typeof(WAVEHDR));
            _slots = new WaveBufferSlot[BufferCount];

            for (int i = 0; i < BufferCount; i++) {
                byte[] pcm = new byte[bytesPerSlot];
                GCHandle pin = GCHandle.Alloc(pcm, GCHandleType.Pinned);
                IntPtr hdrPtr = Marshal.AllocHGlobal(hdrSize);
                WAVEHDR hdr = new WAVEHDR {
                    lpData = pin.AddrOfPinnedObject(),
                    dwBufferLength = (uint)bytesPerSlot,
                    dwFlags = WHDR_DONE
                };
                Marshal.StructureToPtr(hdr, hdrPtr, false);

                _slots[i] = new WaveBufferSlot {
                    PcmData = pcm,
                    PcmPin = pin,
                    HdrPtr = hdrPtr,
                    Prepared = false,
                    InFlight = false,
                    FramesInBuffer = 0
                };
            }
        }

        private void ReleaseWaveSlots() {
            if (_slots == null) {
                return;
            }

            int hdrSize = Marshal.SizeOf(typeof(WAVEHDR));
            for (int i = 0; i < _slots.Length; i++) {
                WaveBufferSlot slot = _slots[i];
                if (slot == null) {
                    continue;
                }
                if (slot.Prepared && _hWaveOut != IntPtr.Zero) {
                    NativeImports.waveOutUnprepareHeader(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                    slot.Prepared = false;
                }
                if (slot.HdrPtr != IntPtr.Zero) {
                    Marshal.FreeHGlobal(slot.HdrPtr);
                    slot.HdrPtr = IntPtr.Zero;
                }
                if (slot.PcmPin.IsAllocated) {
                    slot.PcmPin.Free();
                }
            }
            _slots = null;
        }

        private void ExecuteStop() {
            _isPlaying = false;
            _isPaused = false;
            _isLoaded = false;

            if (_hWaveOut != IntPtr.Zero) {
                NativeImports.waveOutReset(_hWaveOut);
                ReleaseWaveSlots();
                NativeImports.waveOutClose(_hWaveOut);
                _hWaveOut = IntPtr.Zero;
            } else {
                ReleaseWaveSlots();
            }

            if (_reader != null) {
                Marshal.ReleaseComObject(_reader);
                _reader = null;
            }

            _pendingFloatOffset = 0;
            _pendingFloatCount = 0;
            _endOfStream = false;
            _seekBaseMs = 0;
            _completedFrames = 0;
            _nextSlotSequence = 0;
            _needsFlushOnResume = false;
            _positionMs = 0;
            _hasTrackEnded = false;
            _analyzer.Reset();
        }

        private bool ExecutePause() {
            if (!_isPlaying || _isPaused || _hWaveOut == IntPtr.Zero) {
                return false;
            }
            uint res = NativeImports.waveOutPause(_hWaveOut);
            if (res != 0) {
                return false;
            }
            _isPaused = true;
            _isPlaying = false;
            return true;
        }

        private bool ExecuteResume() {
            if (!_isPaused || _hWaveOut == IntPtr.Zero) {
                return false;
            }
            uint res = NativeImports.waveOutRestart(_hWaveOut);
            if (res != 0) {
                return false;
            }
            _isPaused = false;
            _isPlaying = true;
            _needsFlushOnResume = false;
            PumpAudioBuffers();
            return true;
        }

        private bool ExecuteSeek(int targetMs) {
            if (_reader == null || _hWaveOut == IntPtr.Zero) {
                return false;
            }

            int clampedMs = (_durationMs > 0) ? Math.Clamp(targetMs, 0, _durationMs) : Math.Max(0, targetMs);
            bool wasPaused = _isPaused;

            NativeImports.waveOutReset(_hWaveOut);
            int hdrSize = Marshal.SizeOf(typeof(WAVEHDR));
            if (_slots != null) {
                for (int i = 0; i < _slots.Length; i++) {
                    WaveBufferSlot slot = _slots[i];
                    if (slot.Prepared) {
                        NativeImports.waveOutUnprepareHeader(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                        slot.Prepared = false;
                    }
                    slot.InFlight = false;
                    slot.FramesInBuffer = 0;
                }
            }

            _reader.Flush(MF_SOURCE_READER_FIRST_AUDIO_STREAM);
            Guid guidNull = Guid.Empty;
            PropVariant posVar = new PropVariant {
                vt = 20,
                hVal = (long)clampedMs * 10000L
            };
            int hr = _reader.SetCurrentPosition(ref guidNull, ref posVar);
            if (hr < 0) {
                return false;
            }

            _dsp.ResetStates();
            _analyzer.Reset();
            _pendingFloatOffset = 0;
            _pendingFloatCount = 0;
            _endOfStream = false;
            _hasTrackEnded = false;
            _seekBaseMs = clampedMs;
            _completedFrames = 0;
            _nextSlotSequence = 0;
            _positionMs = clampedMs;

            if (wasPaused) {
                NativeImports.waveOutPause(_hWaveOut);
                _needsFlushOnResume = true;
            } else {
                _needsFlushOnResume = false;
                PumpAudioBuffers();
            }

            return true;
        }

        private void PumpAudioBuffers() {
            if (_slots == null || _hWaveOut == IntPtr.Zero || _needsFlushOnResume) {
                return;
            }

            int flagsOffset = (int)Marshal.OffsetOf(typeof(WAVEHDR), "dwFlags");
            int hdrSize = Marshal.SizeOf(typeof(WAVEHDR));
            bool anyInFlight = false;
            bool hadActiveBefore = false;
            int completedCountThisPass = 0;

            for (int c = 0; c < _slots.Length; c++) {
                if (_slots[c].InFlight) {
                    hadActiveBefore = true;
                    break;
                }
            }

            for (int i = 0; i < _slots.Length; i++) {
                WaveBufferSlot slot = _slots[i];
                if (slot.InFlight) {
                    uint flags = (uint)Marshal.ReadInt32(slot.HdrPtr, flagsOffset);
                    if ((flags & WHDR_DONE) == 0) {
                        anyInFlight = true;
                        continue;
                    }

                    if (slot.Prepared) {
                        NativeImports.waveOutUnprepareHeader(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                        slot.Prepared = false;
                    }
                    slot.InFlight = false;
                    completedCountThisPass++;
                    _completedFrames += slot.FramesInBuffer;
                    int calcPos = (int)(_seekBaseMs + ((_completedFrames * 1000L) / _sampleRate));
                    _positionMs = (_durationMs > 0) ? Math.Clamp(calcPos, 0, _durationMs) : Math.Max(0, calcPos);
                }

                if (!_endOfStream) {
                    int framesFilled = FillSlotFromDecoder(slot);
                    if (framesFilled > 0) {
                        int byteLen = framesFilled * _outputChannels * 2;
                        WAVEHDR hdr = new WAVEHDR {
                            lpData = slot.PcmPin.AddrOfPinnedObject(),
                            dwBufferLength = (uint)byteLen,
                            dwFlags = 0
                        };
                        Marshal.StructureToPtr(hdr, slot.HdrPtr, false);

                        uint prep = NativeImports.waveOutPrepareHeader(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                        if (prep == 0) {
                            slot.Prepared = true;
                            slot.InFlight = true;
                            slot.FramesInBuffer = framesFilled;
                            uint wr = NativeImports.waveOutWrite(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                            if (wr == 0) {
                                slot.Sequence = ++_nextSlotSequence;
                                anyInFlight = true;
                                if (!hadActiveBefore) {
                                    _analyzer.PushBlock(slot.PostEqMono, slot.PostEqFrames, slot.LeftRms, slot.RightRms);
                                    slot.AnalysisPushed = true;
                                    hadActiveBefore = true;
                                }
                            } else {
                                NativeImports.waveOutUnprepareHeader(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                                slot.Prepared = false;
                                slot.InFlight = false;
                            }
                        }
                    }
                }
            }

            while (completedCountThisPass > 0) {
                WaveBufferSlot oldestUnpushed = null;
                for (int i = 0; i < _slots.Length; i++) {
                    WaveBufferSlot s = _slots[i];
                    if (s.InFlight && !s.AnalysisPushed) {
                        if (oldestUnpushed == null || s.Sequence < oldestUnpushed.Sequence) {
                            oldestUnpushed = s;
                        }
                    }
                }
                if (oldestUnpushed == null) {
                    break;
                }
                _analyzer.PushBlock(oldestUnpushed.PostEqMono, oldestUnpushed.PostEqFrames, oldestUnpushed.LeftRms, oldestUnpushed.RightRms);
                oldestUnpushed.AnalysisPushed = true;
                completedCountThisPass--;
            }

            if (_endOfStream && !anyInFlight) {
                if (_durationMs > 0) {
                    _positionMs = _durationMs;
                }
                _isPlaying = false;
                _hasTrackEnded = true;
            }
        }

        private static float[] DecodeLockedBufferToFloats(IntPtr dataPtr, uint curLen, bool isFloat, int bitsPerSample) {
            if (isFloat) {
                int floatCount = (int)(curLen / 4);
                float[] rawFloats = new float[floatCount];
                Marshal.Copy(dataPtr, rawFloats, 0, floatCount);
                return rawFloats;
            }

            byte[] rawBytes = new byte[curLen];
            Marshal.Copy(dataPtr, rawBytes, 0, (int)curLen);
            int bytesPerSample = Math.Max(1, bitsPerSample / 8);
            int sampleCount = (int)(curLen / bytesPerSample);
            float[] floats = new float[sampleCount];

            if (bitsPerSample == 16) {
                for (int i = 0; i < sampleCount; i++) {
                    int b = i * 2;
                    short s = (short)(rawBytes[b] | (rawBytes[b + 1] << 8));
                    floats[i] = s / 32768.0f;
                }
            } else if (bitsPerSample == 24) {
                for (int i = 0; i < sampleCount; i++) {
                    int b = i * 3;
                    int s = rawBytes[b] | (rawBytes[b + 1] << 8) | (((sbyte)rawBytes[b + 2]) << 16);
                    floats[i] = s / 8388608.0f;
                }
            } else if (bitsPerSample == 32) {
                for (int i = 0; i < sampleCount; i++) {
                    int b = i * 4;
                    int s = rawBytes[b] | (rawBytes[b + 1] << 8) | (rawBytes[b + 2] << 16) | (rawBytes[b + 3] << 24);
                    floats[i] = (float)(s / 2147483648.0);
                }
            } else {
                for (int i = 0; i < sampleCount; i++) {
                    floats[i] = (rawBytes[i] - 128) / 128.0f;
                }
            }

            return floats;
        }

        private static void DownmixFrameToStereo(float[] rawFloats, int srcBase, int sourceChannels, out float left, out float right) {
            const float InvSqrt2 = 0.70710678f;

            if (sourceChannels == 3) {
                // FL, FR, FC
                float fc = rawFloats[srcBase + 2] * InvSqrt2;
                left = (rawFloats[srcBase] + fc) * InvSqrt2;
                right = (rawFloats[srcBase + 1] + fc) * InvSqrt2;
            } else if (sourceChannels == 4) {
                // FL, FR, BL, BR
                left = (rawFloats[srcBase] + (rawFloats[srcBase + 2] * InvSqrt2)) * InvSqrt2;
                right = (rawFloats[srcBase + 1] + (rawFloats[srcBase + 3] * InvSqrt2)) * InvSqrt2;
            } else if (sourceChannels == 5) {
                // FL, FR, FC, BL, BR
                float fc = rawFloats[srcBase + 2] * InvSqrt2;
                left = (rawFloats[srcBase] + fc + (rawFloats[srcBase + 3] * InvSqrt2)) * 0.58f;
                right = (rawFloats[srcBase + 1] + fc + (rawFloats[srcBase + 4] * InvSqrt2)) * 0.58f;
            } else {
                // 5.1 (FL, FR, FC, LFE, BL, BR) + OPTIONAL 7.1 (SL, SR)
                float fc = rawFloats[srcBase + 2] * InvSqrt2;
                float lSur = rawFloats[srcBase + 4] * InvSqrt2;
                float rSur = (sourceChannels >= 6) ? (rawFloats[srcBase + 5] * InvSqrt2) : 0.0f;
                if (sourceChannels >= 8) {
                    lSur += rawFloats[srcBase + 6] * 0.5f;
                    rSur += rawFloats[srcBase + 7] * 0.5f;
                }
                left = (rawFloats[srcBase] + fc + lSur) * 0.58f;
                right = (rawFloats[srcBase + 1] + fc + rSur) * 0.58f;
            }
        }

        private int FillSlotFromDecoder(WaveBufferSlot slot) {
            int neededSamples = _framesPerBuffer * _outputChannels;
            if (_dspWorkBuffer.Length < neededSamples) {
                _dspWorkBuffer = new float[neededSamples];
            }

            int gatheredSamples = 0;

            while (gatheredSamples < neededSamples) {
                int availablePending = _pendingFloatCount - _pendingFloatOffset;
                if (availablePending > 0) {
                    int toCopy = Math.Min(availablePending, neededSamples - gatheredSamples);
                    Array.Copy(_pendingFloat, _pendingFloatOffset, _dspWorkBuffer, gatheredSamples, toCopy);
                    _pendingFloatOffset += toCopy;
                    gatheredSamples += toCopy;
                    continue;
                }

                if (_endOfStream || _reader == null) {
                    break;
                }

                int actualStreamIdx;
                int streamFlags;
                long timestamp;
                IMFSample sample;
                int hr = _reader.ReadSample(
                    MF_SOURCE_READER_FIRST_AUDIO_STREAM,
                    0,
                    out actualStreamIdx,
                    out streamFlags,
                    out timestamp,
                    out sample
                );

                if (hr < 0) {
                    _endOfStream = true;
                    break;
                }

                if ((streamFlags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) != 0 && _reader != null) {
                    IMFAttributes changedType = null;
                    try {
                        if (_reader.GetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, out changedType) >= 0 && changedType != null) {
                            Guid actualSubType = MFAudioFormat_Float;
                            if (changedType.GetGUID(MF_MT_SUBTYPE, out actualSubType) >= 0) {
                                _sourceIsFloat = (actualSubType == MFAudioFormat_Float);
                            }
                            uint ch = (uint)_sourceChannels;
                            uint bps = (uint)_sourceBitsPerSample;
                            changedType.GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, out ch);
                            changedType.GetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, out bps);
                            _sourceChannels = Math.Max(1, (int)ch);
                            _sourceBitsPerSample = (bps == 8 || bps == 16 || bps == 24 || bps == 32) ? (int)bps : (_sourceIsFloat ? 32 : 16);
                        }
                    } finally {
                        if (changedType != null) Marshal.ReleaseComObject(changedType);
                    }
                }

                if ((streamFlags & MF_SOURCE_READERF_ENDOFSTREAM) != 0) {
                    _endOfStream = true;
                }

                if (sample == null) {
                    if (_endOfStream) {
                        break;
                    }
                    continue;
                }

                IMFMediaBuffer mediaBuf = null;
                try {
                    hr = sample.ConvertToContiguousBuffer(out mediaBuf);
                    if (hr >= 0 && mediaBuf != null) {
                        IntPtr dataPtr;
                        uint maxLen;
                        uint curLen;
                        int bytesPerSample = _sourceIsFloat ? 4 : Math.Max(1, _sourceBitsPerSample / 8);
                        if (mediaBuf.Lock(out dataPtr, out maxLen, out curLen) >= 0 && curLen >= (uint)bytesPerSample) {
                            try {
                                float[] rawFloats = DecodeLockedBufferToFloats(dataPtr, curLen, _sourceIsFloat, _sourceBitsPerSample);
                                int sampleCount = rawFloats.Length;
                                int frames = sampleCount / _sourceChannels;
                                int normalizedCount = frames * _outputChannels;
                                if (_pendingFloat.Length < normalizedCount) {
                                    _pendingFloat = new float[normalizedCount];
                                }

                                if (_sourceChannels == _outputChannels) {
                                    Array.Copy(rawFloats, 0, _pendingFloat, 0, normalizedCount);
                                } else if (_sourceChannels == 1 && _outputChannels == 2) {
                                    for (int f = 0; f < frames; f++) {
                                        float mono = rawFloats[f];
                                        _pendingFloat[f * 2] = mono;
                                        _pendingFloat[(f * 2) + 1] = mono;
                                    }
                                } else if (_outputChannels == 1) {
                                    for (int f = 0; f < frames; f++) {
                                        float left;
                                        float right;
                                        DownmixFrameToStereo(rawFloats, f * _sourceChannels, _sourceChannels, out left, out right);
                                        _pendingFloat[f] = (left + right) * 0.5f;
                                    }
                                } else {
                                    for (int f = 0; f < frames; f++) {
                                        float left;
                                        float right;
                                        DownmixFrameToStereo(rawFloats, f * _sourceChannels, _sourceChannels, out left, out right);
                                        _pendingFloat[f * 2] = left;
                                        _pendingFloat[(f * 2) + 1] = right;
                                    }
                                }

                                _pendingFloatOffset = 0;
                                _pendingFloatCount = normalizedCount;
                            } finally {
                                mediaBuf.Unlock();
                            }
                        }
                    }
                } finally {
                    if (mediaBuf != null) Marshal.ReleaseComObject(mediaBuf);
                    Marshal.ReleaseComObject(sample);
                }
            }

            int framesRead = gatheredSamples / _outputChannels;
            if (framesRead <= 0) {
                return 0;
            }

            double vol = Volatile.Read(ref _volumePercent) / 100.0;
            if (slot.PostEqMono == null || slot.PostEqMono.Length < framesRead) {
                slot.PostEqMono = new float[framesRead];
            }
            float leftRms;
            float rightRms;
            _dsp.ProcessInterleavedFloat(_dspWorkBuffer, framesRead, _outputChannels, vol, _isMuted, slot.PostEqMono, out leftRms, out rightRms);
            slot.PostEqFrames = framesRead;
            slot.LeftRms = leftRms;
            slot.RightRms = rightRms;
            slot.AnalysisPushed = false;

            int sampleTotal = framesRead * _outputChannels;
            byte[] pcm = slot.PcmData;
            for (int s = 0; s < sampleTotal; s++) {
                float clamped = Math.Clamp(_dspWorkBuffer[s], -1.0f, 1.0f);
                short pcmVal = (short)Math.Round(clamped * 32767.0f);
                int byteIdx = s * 2;
                pcm[byteIdx] = (byte)(pcmVal & 0xFF);
                pcm[byteIdx + 1] = (byte)((pcmVal >> 8) & 0xFF);
            }

            return framesRead;
        }
    }

    public sealed class NativeVisualizerCanvas {
        private const int STD_OUTPUT_HANDLE = -11;
        private static readonly IntPtr InvalidHandle = new IntPtr(-1);

        public int Width { get; private set; }
        public int Height { get; private set; }
        public int TopRow { get; private set; }
        public int LeftCol { get; private set; }
        public int CellCount { get; private set; }
        public bool ForceFullRedraw;

        internal char[] CurrChar;
        internal int[] CurrFg;
        internal int[] CurrBg;

        private char[] _prevChar;
        private int[] _prevFg;
        private int[] _prevBg;
        private readonly char[] _consoleChunk = new char[16384];
        private readonly StringBuilder _sb = new StringBuilder(16384);
        private readonly Dictionary<int, string> _fgCache = new Dictionary<int, string>();
        private readonly Dictionary<int, string> _bgCache = new Dictionary<int, string>();

        public NativeVisualizerCanvas(int width, int height, int topRow, int leftCol) {
            Initialize(width, height, topRow, leftCol);
        }

        public void Initialize(int width, int height, int topRow, int leftCol) {
            Width = Math.Max(20, width);
            Height = Math.Max(6, height);
            TopRow = Math.Max(1, topRow);
            LeftCol = Math.Max(1, leftCol);
            CellCount = Width * Height;

            CurrChar = new char[CellCount];
            CurrFg = new int[CellCount];
            CurrBg = new int[CellCount];
            _prevChar = new char[CellCount];
            _prevFg = new int[CellCount];
            _prevBg = new int[CellCount];

            Array.Fill(_prevChar, ' ');
            Array.Fill(_prevFg, -1);
            Array.Fill(_prevBg, -1);

            ForceFullRedraw = true;
            ClearFrame();
        }

        public void ClearFrame() {
            Array.Fill(CurrChar, ' ');
            Array.Fill(CurrFg, -1);
            Array.Fill(CurrBg, -1);
        }

        public void InvalidateAll() {
            ForceFullRedraw = true;
            ClearFrame();
        }

        public void SetCell(int row, int col, char glyph, int fgRgb, int bgRgb) {
            if (row < 0 || row >= Height || col < 0 || col >= Width) {
                return;
            }
            int idx = (row * Width) + col;
            CurrChar[idx] = glyph;
            CurrFg[idx] = fgRgb;
            CurrBg[idx] = bgRgb;
        }

        private string GetFgAnsi(int rgb) {
            string cached;
            if (!_fgCache.TryGetValue(rgb, out cached)) {
                int r = (rgb >> 16) & 0xFF;
                int g = (rgb >> 8) & 0xFF;
                int b = rgb & 0xFF;
                cached = "\u001b[38;2;" + r + ";" + g + ";" + b + "m";
                _fgCache[rgb] = cached;
            }
            return cached;
        }

        private string GetBgAnsi(int rgb) {
            string cached;
            if (!_bgCache.TryGetValue(rgb, out cached)) {
                int r = (rgb >> 16) & 0xFF;
                int g = (rgb >> 8) & 0xFF;
                int b = rgb & 0xFF;
                cached = "\u001b[48;2;" + r + ";" + g + ";" + b + "m";
                _bgCache[rgb] = cached;
            }
            return cached;
        }

        public string BuildDiffAnsi(bool wrapSync, string trailingAnsi) {
            _sb.Clear();
            if (wrapSync) {
                _sb.Append("\u001b[?2026h");
            }

            int activeFg = -1;
            int activeBg = -1;
            bool hasModifier = false;
            bool emittedAnything = false;
            bool force = ForceFullRedraw;
            int w = Width;
            int h = Height;

            for (int r = 0; r < h; r++) {
                int rowBase = r * w;
                int lastEmitted = -2;
                int absRow = TopRow + r;

                for (int c = 0; c < w; c++) {
                    int idx = rowBase + c;
                    char ch = CurrChar[idx];
                    int fg = CurrFg[idx];
                    int bg = CurrBg[idx];

                    if (!force && ch == _prevChar[idx] && fg == _prevFg[idx] && bg == _prevBg[idx]) {
                        continue;
                    }

                    emittedAnything = true;

                    if (c != lastEmitted + 1) {
                        _sb.Append("\u001b[").Append(absRow).Append(';').Append(LeftCol + c).Append('H');
                    }

                    if (hasModifier && ((bg == -1 && activeBg != -1) || (fg == -1 && activeFg != -1))) {
                        _sb.Append("\u001b[0m");
                        activeFg = -1;
                        activeBg = -1;
                        hasModifier = false;
                    }

                    if (fg != -1 && fg != activeFg) {
                        _sb.Append(GetFgAnsi(fg));
                        activeFg = fg;
                        hasModifier = true;
                    }

                    if (bg != -1 && bg != activeBg) {
                        _sb.Append(GetBgAnsi(bg));
                        activeBg = bg;
                        hasModifier = true;
                    }

                    _sb.Append(ch);
                    lastEmitted = c;

                    _prevChar[idx] = ch;
                    _prevFg[idx] = fg;
                    _prevBg[idx] = bg;
                }
            }

            if (hasModifier) {
                _sb.Append("\u001b[0m");
            }

            ForceFullRedraw = false;

            if (!string.IsNullOrEmpty(trailingAnsi)) {
                _sb.Append(trailingAnsi);
                emittedAnything = true;
            }

            if (!emittedAnything) {
                return string.Empty;
            }

            if (wrapSync) {
                _sb.Append("\u001b[?2026l");
            }

            return _sb.ToString();
        }

        public bool WriteConsoleUtf16(string text) {
            if (string.IsNullOrEmpty(text)) {
                return true;
            }

            IntPtr hOut = NativeImports.GetStdHandle(STD_OUTPUT_HANDLE);
            if (hOut == IntPtr.Zero || hOut == InvalidHandle) {
                return false;
            }

            int offset = 0;
            int total = text.Length;

            while (offset < total) {
                int chunkLen = Math.Min(_consoleChunk.Length, total - offset);
                text.CopyTo(offset, _consoleChunk, 0, chunkLen);
                uint written;
                if (!NativeImports.WriteConsoleW(hOut, _consoleChunk, (uint)chunkLen, out written, IntPtr.Zero) || written == 0) {
                    return false;
                }
                offset += (int)written;
            }

            return true;
        }
    }

    public sealed class NativeVisualizerRenderer {
        private static readonly char[] SubBlocks = new char[] {
            '\u2581', '\u2582', '\u2583', '\u2584', '\u2585', '\u2586', '\u2587', '\u2588'
        };

        private static readonly char[] DensityGlyphs = new char[] {
            ' ', '\u00B7', '\u2591', '\u2592', '\u2593', '\u2588'
        };

        private static readonly int[] LeftBits = new int[] { 0x01, 0x02, 0x04, 0x40 };
        private static readonly int[] RightBits = new int[] { 0x08, 0x10, 0x20, 0x80 };

        private double[] _peakLevels = Array.Empty<double>();
        private double[] _peakHoldTimers = Array.Empty<double>();
        private int[] _maskBuffer = Array.Empty<int>();
        private int[] _colColors = Array.Empty<int>();

        private double _phase;
        private int _radialW;
        private int _radialH;
        private double[] _cellRadiusNorm = Array.Empty<double>();
        private double[] _cellAngles = Array.Empty<double>();

        private int _wfRows;
        private int _wfCols;
        private int _wfHeadRow;
        private float[] _wfHistory = Array.Empty<float>();

        public void Reset() {
            if (_peakLevels.Length > 0) {
                Array.Clear(_peakLevels, 0, _peakLevels.Length);
            }
            if (_peakHoldTimers.Length > 0) {
                Array.Clear(_peakHoldTimers, 0, _peakHoldTimers.Length);
            }
            if (_maskBuffer.Length > 0) {
                Array.Clear(_maskBuffer, 0, _maskBuffer.Length);
            }
            _phase = 0.0;
            if (_wfHistory.Length > 0) {
                Array.Clear(_wfHistory, 0, _wfHistory.Length);
            }
            _wfHeadRow = 0;
        }

        private static int PickPalette(int[] palette, double normalizedValue) {
            if (palette == null || palette.Length == 0) {
                return 0xFFFFFF;
            }
            double clamped = Math.Clamp(normalizedValue, 0.0, 1.0);
            int lastIdx = palette.Length - 1;
            int targetIdx = Math.Clamp((int)Math.Round(clamped * lastIdx), 0, lastIdx);
            return palette[targetIdx];
        }

        public void RenderSpectrum(NativeVisualizerCanvas canvas, float[] spectrum, double deltaTime, int[] palette, int peakColor) {
            if (canvas == null || spectrum == null || spectrum.Length == 0) {
                return;
            }

            int w = canvas.Width;
            int h = canvas.Height;
            int barWidth = (w >= 60) ? 2 : 1;
            int pitch = barWidth + 1;
            int maxBars = Math.Max(8, (int)Math.Floor((w + 1) / (double)pitch));
            int barCount = Math.Min(maxBars, Math.Max(8, spectrum.Length));
            int totalSpan = (barCount * pitch) - 1;
            int startCol = Math.Max(0, (int)Math.Floor((w - totalSpan) / 2.0));
            double dt = (deltaTime > 0.0) ? Math.Min(deltaTime, 0.1) : (1.0 / 60.0);

            if (_peakLevels.Length != barCount) {
                _peakLevels = new double[barCount];
                _peakHoldTimers = new double[barCount];
            }

            canvas.ClearFrame();
            int safePeakColor = (peakColor >= 0) ? peakColor : 0xFFFFFF;
            double barDenom = Math.Max(1, barCount - 1);
            int specLast = spectrum.Length - 1;

            for (int b = 0; b < barCount; b++) {
                int specIdx = Math.Clamp((int)Math.Floor((b / barDenom) * specLast), 0, specLast);
                double val = Math.Clamp((double)spectrum[specIdx], 0.0, 1.0);
                double units = val * h;

                if (val >= _peakLevels[b]) {
                    _peakLevels[b] = val;
                    _peakHoldTimers[b] = 0.35;
                } else if (_peakHoldTimers[b] > 0.0) {
                    _peakHoldTimers[b] = Math.Max(0.0, _peakHoldTimers[b] - dt);
                } else {
                    _peakLevels[b] = Math.Max(val, _peakLevels[b] - (1.35 * dt));
                }

                int fullRows = (int)Math.Floor(units);
                double frac = units - fullRows;
                int subIdx = (int)Math.Floor(frac * 8.0) - 1;
                int colBase = startCol + (b * pitch);

                for (int r = 0; r < fullRows; r++) {
                    int rowIdx = (h - 1) - r;
                    double heightT = (r + 0.5) / Math.Max(1, h);
                    int clr = PickPalette(palette, heightT);

                    for (int dx = 0; dx < barWidth; dx++) {
                        canvas.SetCell(rowIdx, colBase + dx, '\u2588', clr, -1);
                    }
                }

                if (fullRows < h && subIdx >= 0) {
                    int topRow = (h - 1) - fullRows;
                    double heightT = (fullRows + 0.5) / Math.Max(1, h);
                    int clr = PickPalette(palette, heightT);
                    char tipGlyph = SubBlocks[Math.Clamp(subIdx, 0, 7)];

                    for (int dx = 0; dx < barWidth; dx++) {
                        canvas.SetCell(topRow, colBase + dx, tipGlyph, clr, -1);
                    }
                }

                if (_peakLevels[b] > 0.03) {
                    int peakRow = Math.Clamp((h - 1) - (int)Math.Round(_peakLevels[b] * (h - 1)), 0, h - 1);

                    for (int dx = 0; dx < barWidth; dx++) {
                        canvas.SetCell(peakRow, colBase + dx, '\u2581', safePeakColor, -1);
                    }
                }
            }
        }

        public void RenderMirror(NativeVisualizerCanvas canvas, float[] spectrum, int[] palette, int axisColor) {
            if (canvas == null || spectrum == null || spectrum.Length == 0) {
                return;
            }

            int w = canvas.Width;
            int h = canvas.Height;
            int barWidth = (w >= 60) ? 2 : 1;
            int pitch = barWidth + 1;
            int maxBars = Math.Max(8, (int)Math.Floor((w + 1) / (double)pitch));
            int barCount = Math.Min(maxBars, Math.Max(8, spectrum.Length));
            int totalSpan = (barCount * pitch) - 1;
            int startCol = Math.Max(0, (int)Math.Floor((w - totalSpan) / 2.0));
            int midRow = (int)Math.Floor(h / 2.0);
            double halfH = Math.Max(1.0, h / 2.0);

            canvas.ClearFrame();
            int safeAxis = (axisColor >= 0) ? axisColor : 0x2F4F4F;

            for (int c = 0; c < w; c++) {
                canvas.SetCell(midRow, c, '\u2500', safeAxis, -1);
            }

            double barDenom = Math.Max(1, barCount - 1);
            int specLast = spectrum.Length - 1;

            for (int b = 0; b < barCount; b++) {
                int specIdx = Math.Clamp((int)Math.Floor((b / barDenom) * specLast), 0, specLast);
                double val = Math.Clamp((double)spectrum[specIdx], 0.0, 1.0);
                double span = val * halfH;
                int fullSteps = (int)Math.Floor(span);
                bool half = (span - fullSteps) >= 0.45;
                int colBase = startCol + (b * pitch);

                for (int offset = 0; offset < fullSteps; offset++) {
                    double normDist = (offset + 0.5) / halfH;
                    int clr = PickPalette(palette, normDist);
                    int upRow = midRow - offset;
                    int downRow = midRow + offset;

                    for (int dx = 0; dx < barWidth; dx++) {
                        if (upRow >= 0) {
                            canvas.SetCell(upRow, colBase + dx, '\u2588', clr, -1);
                        }
                        if (downRow < h) {
                            canvas.SetCell(downRow, colBase + dx, '\u2588', clr, -1);
                        }
                    }
                }

                if (half) {
                    double normDist = (fullSteps + 0.5) / halfH;
                    int clr = PickPalette(palette, normDist);
                    int upTip = midRow - fullSteps;
                    int downTip = midRow + fullSteps;

                    for (int dx = 0; dx < barWidth; dx++) {
                        if (upTip >= 0) {
                            canvas.SetCell(upTip, colBase + dx, '\u2584', clr, -1);
                        }
                        if (downTip < h) {
                            canvas.SetCell(downTip, colBase + dx, '\u2580', clr, -1);
                        }
                    }
                }
            }
        }

        public void RenderOscilloscope(NativeVisualizerCanvas canvas, float[] waveform, float[] metrics, int[] palette, int axisColor) {
            if (canvas == null || waveform == null || waveform.Length == 0) {
                return;
            }

            int w = canvas.Width;
            int h = canvas.Height;
            int cellCount = w * h;
            int pixelW = w * 2;
            int pixelH = h * 4;
            double bass = (metrics != null && metrics.Length >= 3) ? metrics[2] : 0.0;

            if (_maskBuffer.Length != cellCount) {
                _maskBuffer = new int[cellCount];
            } else {
                Array.Clear(_maskBuffer, 0, cellCount);
            }

            if (_colColors.Length != w) {
                _colColors = new int[w];
            }

            int baseClr = PickPalette(palette, bass);
            Array.Fill(_colColors, baseClr);

            int prevPy = (int)Math.Floor((pixelH - 1) / 2.0);
            double pxDenom = Math.Max(1, pixelW - 1);
            int waveLast = waveform.Length - 1;

            for (int px = 0; px < pixelW; px++) {
                int waveIdx = Math.Clamp((int)Math.Floor((px / pxDenom) * waveLast), 0, waveLast);
                double sample = Math.Clamp((double)waveform[waveIdx], -1.0, 1.0);
                int py = Math.Clamp((int)Math.Round((1.0 - ((sample + 1.0) * 0.5)) * (pixelH - 1)), 0, pixelH - 1);
                int cellCol = px >> 1;
                int subX = px & 1;

                if (Math.Abs(sample) > 0.25) {
                    _colColors[cellCol] = PickPalette(palette, Math.Min(1.0, (Math.Abs(sample) * 0.7) + (bass * 0.4)));
                }

                if (px == 0) {
                    prevPy = py;
                }

                int yStart = Math.Min(prevPy, py);
                int yEnd = Math.Max(prevPy, py);

                for (int y = yStart; y <= yEnd; y++) {
                    int cellRow = y >> 2;
                    int subY = y & 3;
                    int bit = (subX == 0) ? LeftBits[subY] : RightBits[subY];
                    _maskBuffer[(cellRow * w) + cellCol] |= bit;
                }

                prevPy = py;
            }

            canvas.ClearFrame();
            int midRow = (int)Math.Floor(h / 2.0);
            int safeAxis = (axisColor >= 0) ? axisColor : 0x2F4F4F;

            for (int r = 0; r < h; r++) {
                int rowBase = r * w;
                for (int c = 0; c < w; c++) {
                    int mask = _maskBuffer[rowBase + c];
                    if (mask != 0) {
                        canvas.SetCell(r, c, (char)(0x2800 + mask), _colColors[c], -1);
                    } else if (r == midRow) {
                        canvas.SetCell(r, c, '\u2500', safeAxis, -1);
                    }
                }
            }
        }

        private void EnsureRadialGeometry(int w, int h) {
            if (_radialW == w && _radialH == h) {
                return;
            }

            _radialW = w;
            _radialH = h;
            int total = w * h;
            _cellRadiusNorm = new double[total];
            _cellAngles = new double[total];

            double cx = (w - 1) / 2.0;
            double cy = (h - 1) / 2.0;
            double maxRadius = Math.Max(4.0, Math.Min(cx, cy * 2.0));

            for (int r = 0; r < h; r++) {
                double dy = (r - cy) * 2.0;
                int rBase = r * w;
                for (int c = 0; c < w; c++) {
                    double dx = c - cx;
                    double dist = Math.Sqrt((dx * dx) + (dy * dy));
                    int idx = rBase + c;
                    _cellRadiusNorm[idx] = Math.Min(1.25, dist / maxRadius);
                    _cellAngles[idx] = Math.Atan2(dy, dx);
                }
            }
        }

        public void RenderRadialPulse(NativeVisualizerCanvas canvas, float[] spectrum, float[] metrics, double deltaTime, int[] palette) {
            if (canvas == null) {
                return;
            }

            int w = canvas.Width;
            int h = canvas.Height;
            EnsureRadialGeometry(w, h);

            double bass = (metrics != null && metrics.Length >= 3) ? metrics[2] : 0.0;
            double mid = (metrics != null && metrics.Length >= 4) ? metrics[3] : 0.0;
            double treble = (metrics != null && metrics.Length >= 5) ? metrics[4] : 0.0;
            double dt = (deltaTime > 0.0) ? Math.Min(deltaTime, 0.1) : (1.0 / 60.0);

            _phase += dt * (2.2 + (bass * 6.5));
            int specLen = (spectrum != null) ? spectrum.Length : 0;
            int specLast = Math.Max(0, specLen - 1);

            canvas.ClearFrame();

            int total = w * h;
            double ringFreq = 10.0 + (bass * 6.0);
            double rayPhase = _phase * 0.45;
            double glyphScale = DensityGlyphs.Length - 0.01;

            for (int idx = 0; idx < total; idx++) {
                double rNorm = _cellRadiusNorm[idx];
                if (rNorm > 1.05) {
                    continue;
                }

                double angle = _cellAngles[idx];
                double ring = 0.5 + (0.5 * Math.Sin((rNorm * ringFreq) - _phase));
                double ray = 0.5 + (0.5 * Math.Cos((angle * 8.0) + rayPhase));
                double specE = 0.0;

                if (specLen > 0) {
                    int binIdx = Math.Clamp((int)Math.Floor(rNorm * specLast), 0, specLast);
                    specE = spectrum[binIdx];
                }

                double falloff = Math.Max(0.0, 1.0 - (rNorm * 0.72));
                double energyMix = (rNorm < 0.35)
                    ? (0.4 + (bass * 0.9))
                    : ((rNorm < 0.72) ? (0.25 + (mid * 0.85)) : (0.15 + (treble * 0.9)));
                double intensity = ((ring * 0.55) + (ray * 0.25) + (specE * 0.45)) * energyMix * falloff;
                double clamped = Math.Clamp(intensity, 0.0, 1.0);
                int glyphIdx = (int)Math.Floor(clamped * glyphScale);

                if (glyphIdx <= 0) {
                    continue;
                }

                canvas.CurrChar[idx] = DensityGlyphs[glyphIdx];
                canvas.CurrFg[idx] = PickPalette(palette, clamped);
            }
        }

        public void RenderWaterfall(NativeVisualizerCanvas canvas, float[] spectrum, int[] palette) {
            if (canvas == null || spectrum == null || spectrum.Length == 0) {
                return;
            }

            int w = canvas.Width;
            int h = canvas.Height;
            int pixelH = h * 2;

            if (_wfRows != pixelH || _wfCols != w) {
                _wfRows = pixelH;
                _wfCols = w;
                _wfHeadRow = 0;
                _wfHistory = new float[pixelH * w];
            }

            int writeBase = _wfHeadRow * w;
            int specLast = spectrum.Length - 1;
            double wDenom = Math.Max(1, w - 1);

            for (int c = 0; c < w; c++) {
                int specIdx = Math.Clamp((int)Math.Floor((c / wDenom) * specLast), 0, specLast);
                _wfHistory[writeBase + c] = Math.Clamp(spectrum[specIdx], 0.0f, 1.0f);
            }

            _wfHeadRow = (_wfHeadRow + 1) % pixelH;
            canvas.ClearFrame();

            for (int r = 0; r < h; r++) {
                int topPhys = (_wfHeadRow + (r * 2)) % pixelH;
                int botPhys = (_wfHeadRow + (r * 2) + 1) % pixelH;
                int topBase = topPhys * w;
                int botBase = botPhys * w;

                for (int c = 0; c < w; c++) {
                    double topV = _wfHistory[topBase + c];
                    double botV = _wfHistory[botBase + c];

                    if (topV < 0.04 && botV < 0.04) {
                        continue;
                    }

                    canvas.SetCell(r, c, '\u2580', PickPalette(palette, topV), PickPalette(palette, botV));
                }
            }
        }
    }
}
'@ -Language CSharp
}





###############################################################################
#
# MM EQUALIZER ENGINE BRIDGE
#
# POWERSHELL FACTORY AND TEST HELPER WRAPPER FOR PSBOOMBOX NATIVE CLASSES
# (AUDIO ENGINE, DSP, ANALYZER, AND 60 FPS VISUALIZER CANVAS & RENDERER).
#
###############################################################################

Class MMEqualizerEngineNative {
    Static [Object]CreateEngine() {
        [Type]$EngineType = 'PSBoombox.NativeAudioEngine' -AS [Type]

        Return $EngineType::new()
    }

    Static [Object]CreateVisualizerCanvas(
        [Int]$Width,
        [Int]$Height,
        [Int]$TopRow,
        [Int]$LeftCol
    ) {
        [Type]$CanvasType = 'PSBoombox.NativeVisualizerCanvas' -AS [Type]

        Return $CanvasType::new($Width, $Height, $TopRow, $LeftCol)
    }

    Static [Object]CreateVisualizerRenderer() {
        [Type]$RendererType = 'PSBoombox.NativeVisualizerRenderer' -AS [Type]

        Return $RendererType::new()
    }

    Static [Single[]]ProcessBufferForTest(
        [Single[]]$Samples,
        [Int]$SampleRate,
        [Int]$Channels,
        [Boolean]$Enabled,
        [Double]$PreampDb,
        [Double[]]$BandGainsDb
    ) {
        [Type]$DspType = 'PSBoombox.EqualizerDsp' -AS [Type]

        Return $DspType::ProcessBufferForTest(
            $Samples,
            $SampleRate,
            $Channels,
            $Enabled,
            $PreampDb,
            $BandGainsDb
        )
    }

    Static [Single[]]AnalyzeBufferForTest(
        [Single[]]$Samples,
        [Int]$SampleRate,
        [Int]$Channels,
        [Int]$BarCount,
        [Boolean]$EqEnabled,
        [Double]$PreampDb,
        [Double[]]$BandGainsDb
    ) {
        [Type]$AnalyzerType = 'PSBoombox.AudioAnalyzer' -AS [Type]

        Return $AnalyzerType::AnalyzeBufferForTest(
            $Samples,
            $SampleRate,
            $Channels,
            $BarCount,
            $EqEnabled,
            $PreampDb,
            $BandGainsDb
        )
    }
}
