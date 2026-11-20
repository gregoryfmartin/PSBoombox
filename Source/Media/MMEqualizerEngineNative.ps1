using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# MM EQUALIZER ENGINE NATIVE
#
# SCOPED C# AUDIO ENGINE PROVIDING WINDOWS MEDIA FOUNDATION DECODING,
# REAL-TIME 10-BAND ISO BIQUAD EQUALIZATION + PREAMP + SOFT LIMITER, AND
# RING-BUFFERED WINMM WAVEOUT STREAMING.
#
###############################################################################

If($null -EQ ('PSBoombox.NativeAudioEngine' -AS [Type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
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

            for (int f = 0; f < frameCount; f++) {
                int baseIdx = f * chCount;
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

                    x *= gainVol;
                    if (x > 0.9) {
                        x = 0.9 + (0.1 * Math.Tanh((x - 0.9) / 0.1));
                    } else if (x < -0.9) {
                        x = -0.9 - (0.1 * Math.Tanh(((-x) - 0.9) / 0.1));
                    }
                    samples[baseIdx + c] = (float)x;
                }
            }
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

    public sealed class NativeAudioEngine : IDisposable {
        private static readonly Guid MF_MT_MAJOR_TYPE = new Guid("48eba18e-f8c9-4687-bf11-0a74c9f96a8f");
        private static readonly Guid MF_MT_SUBTYPE = new Guid("f7e34c9a-42e8-4714-b74b-cb29d72c35e5");
        private static readonly Guid MFMediaType_Audio = new Guid("73647561-0000-0010-8000-00aa00389b71");
        private static readonly Guid MFAudioFormat_Float = new Guid("00000003-0000-0010-8000-00aa00389b71");
        private static readonly Guid MF_MT_AUDIO_NUM_CHANNELS = new Guid("37e48bf5-645e-4c5b-89de-ada9e29b696a");
        private static readonly Guid MF_MT_AUDIO_SAMPLES_PER_SECOND = new Guid("5faeeae7-0290-4c31-9e8a-c534f68d9dba");
        private static readonly Guid MF_PD_DURATION = new Guid("6c990d33-bb8e-477a-8598-0d5d96fcd88a");

        private const int MF_SOURCE_READER_ALL_STREAMS = unchecked((int)0xFFFFFFFE);
        private const int MF_SOURCE_READER_FIRST_AUDIO_STREAM = unchecked((int)0xFFFFFFFD);
        private const int MF_SOURCE_READER_MEDIASOURCE = unchecked((int)0xFFFFFFFF);
        private const int MF_SOURCE_READERF_ENDOFSTREAM = 0x00000002;
        private const uint MF_SDK_VERSION = 0x00020070;
        private const uint WAVE_MAPPER = unchecked((uint)-1);
        private const uint CALLBACK_EVENT = 0x00050000;
        private const uint WHDR_DONE = 0x00000001;
        private const int BufferCount = 4;

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
        }

        private readonly EqualizerDsp _dsp = new EqualizerDsp();
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
        private int _framesPerBuffer = 1764;
        private bool _endOfStream;
        private long _seekBaseMs;
        private long _completedFrames;
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
                    int waitMs = (_isPlaying && !_isPaused) ? 15 : 100;
                    WaitHandle.WaitAny(waitHandles, waitMs);
                }
            }

            if (_mfStarted) {
                NativeImports.MFShutdown();
                _mfStarted = false;
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
            IMFAttributes targetType = null;
            IMFAttributes actualType = null;

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

                hr = NativeImports.MFCreateMediaType(out targetType);
                if (hr < 0 || targetType == null) {
                    errorMsg = string.Format("MFCreateMediaType failed (0x{0:X8}).", hr);
                    return false;
                }

                Guid majorType = MFMediaType_Audio;
                Guid subType = MFAudioFormat_Float;
                targetType.SetGUID(MF_MT_MAJOR_TYPE, ref majorType);
                targetType.SetGUID(MF_MT_SUBTYPE, ref subType);

                hr = reader.SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, IntPtr.Zero, targetType);
                if (hr < 0) {
                    errorMsg = string.Format("SetCurrentMediaType(Float) failed (0x{0:X8}).", hr);
                    return false;
                }

                hr = reader.GetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, out actualType);
                if (hr < 0 || actualType == null) {
                    errorMsg = string.Format("GetCurrentMediaType failed (0x{0:X8}).", hr);
                    return false;
                }

                uint channels = 2;
                uint sampleRate = 44100;
                actualType.GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, out channels);
                actualType.GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, out sampleRate);

                _sourceChannels = Math.Max(1, (int)channels);
                _outputChannels = (_sourceChannels == 1) ? 1 : 2;
                _sampleRate = Math.Max(8000, (int)sampleRate);
                _framesPerBuffer = Math.Max(256, _sampleRate / 25);

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

                _pendingFloatOffset = 0;
                _pendingFloatCount = 0;
                _endOfStream = false;
                _seekBaseMs = 0;
                _completedFrames = 0;
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
                if (actualType != null) Marshal.ReleaseComObject(actualType);
                if (targetType != null) Marshal.ReleaseComObject(targetType);
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
            _needsFlushOnResume = false;
            _positionMs = 0;
            _hasTrackEnded = false;
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
            _pendingFloatOffset = 0;
            _pendingFloatCount = 0;
            _endOfStream = false;
            _hasTrackEnded = false;
            _seekBaseMs = clampedMs;
            _completedFrames = 0;
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
                                anyInFlight = true;
                            } else {
                                NativeImports.waveOutUnprepareHeader(_hWaveOut, slot.HdrPtr, (uint)hdrSize);
                                slot.Prepared = false;
                                slot.InFlight = false;
                            }
                        }
                    }
                }
            }

            if (_endOfStream && !anyInFlight) {
                if (_durationMs > 0) {
                    _positionMs = _durationMs;
                }
                _isPlaying = false;
                _hasTrackEnded = true;
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
                        if (mediaBuf.Lock(out dataPtr, out maxLen, out curLen) >= 0 && curLen >= 4) {
                            try {
                                int floatCount = (int)(curLen / 4);
                                float[] rawFloats = new float[floatCount];
                                Marshal.Copy(dataPtr, rawFloats, 0, floatCount);

                                int frames = floatCount / _sourceChannels;
                                int normalizedCount = frames * _outputChannels;
                                if (_pendingFloat.Length < normalizedCount) {
                                    _pendingFloat = new float[normalizedCount];
                                }

                                if (_sourceChannels == _outputChannels) {
                                    Array.Copy(rawFloats, 0, _pendingFloat, 0, normalizedCount);
                                } else {
                                    // DOWNMIX MULTICHANNEL (>2) TO STEREO SAFELY
                                    for (int f = 0; f < frames; f++) {
                                        int srcBase = f * _sourceChannels;
                                        float left = rawFloats[srcBase];
                                        float right = (_sourceChannels >= 2) ? rawFloats[srcBase + 1] : left;
                                        _pendingFloat[(f * 2)] = left;
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
            _dsp.ProcessInterleavedFloat(_dspWorkBuffer, framesRead, _outputChannels, vol, _isMuted);

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
}
'@ -Language CSharp
}





###############################################################################
#
# MM EQUALIZER ENGINE BRIDGE
#
# POWERSHELL FACTORY AND TEST HELPER WRAPPER FOR PSBOOMBOX.NATIVEAUDIOENGINE
# AND PSBOOMBOX.EQUALIZERDSP.
#
###############################################################################

Class MMEqualizerEngineNative {
    Static [Object]CreateEngine() {
        [Type]$EngineType = 'PSBoombox.NativeAudioEngine' -AS [Type]

        Return $EngineType::new()
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
}
