using System.Collections.Generic;
using System.IO;
using UnityEngine;
using LibMVCS = XTC.FMP.LIB.MVCS;
using XTC.oelArchive;
using NLayer;
using System.Linq;
using System.Threading.Tasks;
using System.Threading;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    /// <summary>
    /// 归档读取器代理类
    /// </summary>
    public class ArchiveReaderProxy
    {
        public class PreReadCallback
        {
            public System.Action onSuccess;
            public System.Action onFailure;
        }

        public LibMVCS.Logger logger { get; set; }
        private string archiveUri { get; set; }

        public PreReadCallback NewPreReadCallback()
        {
            return new PreReadCallback();
        }

        /// <summary>
        /// 加载到内存中的对象
        /// </summary>
        /// <remarks>
        /// key: 文件的entry
        /// </remarks>
        private Dictionary<string, Object> objects_ = new Dictionary<string, Object>();

        /// <summary>
        /// 文件型归档读取器
        /// </summary>
        private FileReader reader_ = null;

        private List<CancellationTokenSource> tokenSourceS_ = new List<CancellationTokenSource>();

        public void Open(string _uri)
        {
            archiveUri = _uri;
            if (!archiveUri.EndsWith("#"))
            {
                reader_ = new FileReader();
                if (!File.Exists(archiveUri))
                    logger.Error("{0} not found ", archiveUri);
            }
            else
            {
                if (!Directory.Exists(archiveUri))
                    logger.Error("{0} not found ", archiveUri);
            }
        }

        public void Close()
        {
            logger.Debug("ready to cancel {0} tasks", tokenSourceS_.Count);
            foreach (var tokenSource in tokenSourceS_)
            {
                tokenSource.Cancel();
            }
            tokenSourceS_.Clear();

            if (null != reader_)
            {
                reader_.Close();
                reader_ = null;
            }
            foreach (var obj in objects_.Values)
            {
                Object.Destroy(obj);
            }
            objects_.Clear();
            printObjectsStatus();
        }

        /// <summary>
        /// 读取归档类所有脚本代码
        /// </summary>
        /// <param name="_uri"></param>
        /// <returns>
        /// </returns>
        public Dictionary<string, byte[]> ReadAllScripts()
        {
            var codes = new Dictionary<string, byte[]>();

            if (archiveUri.EndsWith("#"))
            {
                // 从本地文件中读取所有lua脚本文件
                foreach (string file in Directory.GetFiles(archiveUri))
                {
                    if (!file.EndsWith(".lua"))
                        continue;

                    string filename = Path.GetFileNameWithoutExtension(file);
                    codes[filename] = File.ReadAllBytes(file);
                }
            }
            else
            {
                reader_ = new FileReader();
                // 从Archive中读取所有lua脚本文件
                try
                {
                    reader_.Open(archiveUri);
                    // 读取归档类所有lua文件
                    foreach (string entry in reader_.entries)
                    {
                        if (!entry.EndsWith(".lua"))
                            continue;

                        string filename = Path.GetFileNameWithoutExtension(entry);
                        codes[filename] = reader_.Read(entry);
                    }
                }
                catch (System.Exception ex)
                {
                    logger.Exception(ex);
                }
            }
            return codes;
        }

        /// <summary>
        /// 读取字节
        /// </summary>
        /// <param name="_entry"></param>
        /// <returns></returns>
        public byte[] ReadBytes(string _entry)
        {
            if (null == reader_)
            {
                string path = Path.Combine(archiveUri, _entry);
                if (!File.Exists(path))
                {
                    logger.Error("{0} not found in directory", _entry);
                    return null;
                }
                return File.ReadAllBytes(path);
            }
            else
            {
                if (!reader_.entries.Contains(_entry))
                {
                    logger.Error("{0} not found in archive", _entry);
                    return null;
                }
                return reader_.Read(_entry);
            }
        }

        public Texture2D ReadTexture(string _entry, TextureFormat _textureFormat)
        {
            Object obj = null;
            if (objects_.TryGetValue(_entry, out obj))
            {
                return obj as Texture2D;
            }

            byte[] bytes = null;
            if (null == reader_)
            {
                string path = Path.Combine(archiveUri, _entry);
                if (!File.Exists(path))
                {
                    logger.Error("{0} not found in directory", _entry);
                    return null;
                }
                bytes = File.ReadAllBytes(path);
            }
            else
            {
                if (!reader_.entries.Contains(_entry))
                {
                    logger.Error("{0} not found in archive", _entry);
                    return null;
                }
                bytes = reader_.Read(_entry);
            }

            var texture = new Texture2D(0, 0, _textureFormat, false);
            texture.LoadImage(bytes);
            objects_[_entry] = texture;
            printObjectsStatus();
            return texture;
        }

        public Sprite CreateSprite(Texture2D _texture, Rect _rect, Vector4 _border)
        {
            var sprite = Sprite.Create(_texture, _rect, new Vector2(0.5f, 0.5f), 100, 1, SpriteMeshType.Tight, _border);
            return sprite;
        }

        public AudioClip ReadAudioClip(string _entry)
        {
            Object obj = null;
            if (objects_.TryGetValue(_entry, out obj))
            {
                return obj as AudioClip;
            }

            byte[] bytes = null;
            if (null == reader_)
            {
                string path = Path.Combine(archiveUri, _entry);
                if (!File.Exists(path))
                {
                    logger.Error("{0} not found in directory", _entry);
                    return null;
                }
                bytes = File.ReadAllBytes(path);
            }
            else
            {
                if (!reader_.entries.Contains(_entry))
                {
                    logger.Error("{0} not found in archive", _entry);
                    return null;
                }
                bytes = reader_.Read(_entry);
            }

            Stream memStream = new MemoryStream(bytes);
            var mpegFile = new MpegFile(memStream);
            int lengthSamples = (int)(mpegFile.Length / sizeof(float) / mpegFile.Channels);
            float[] samples = new float[lengthSamples * mpegFile.Channels];
            int readCount = mpegFile.ReadSamples(samples, 0, lengthSamples * mpegFile.Channels);
            AudioClip ac = AudioClip.Create(_entry, lengthSamples, mpegFile.Channels, mpegFile.SampleRate, false);
            ac.SetData(samples, 0);
            objects_[_entry] = ac;
            printObjectsStatus();
            return ac;
        }

        /// <summary>
        /// 异步预读取音频
        /// </summary>
        /// <param name="_entry"></param>
        /// <param name="_callback">回调</param>
        public void PreReadAudioClipAsync(string _entry, PreReadCallback _callback)
        {
            if (objects_.ContainsKey(_entry))
                return;

            System.Action onSuccess = _callback.onSuccess;
            System.Action onFailure = _callback.onFailure;
            string entry = _entry;
            byte[] bytes = null;
            //reader 不是线程安全的，所以不能放在线程中执行
            if (null == reader_)
            {
                string path = Path.Combine(archiveUri, entry);
                if (!File.Exists(path))
                {
                    logger.Error("{0} not found in directory", entry);
                    onFailure();
                    return;
                }
                bytes = File.ReadAllBytes(path);
            }
            else
            {
                if (!reader_.entries.Contains(entry))
                {
                    logger.Error("{0} not found in archive", entry);
                    onFailure();
                    return;
                }
                bytes = reader_.Read(entry);
            }

            bool useStreamMode = false;

            if (useStreamMode)
            {
                Stream memStream = new MemoryStream(bytes);
                var mpegFile = new MpegFile(memStream);
                // sizeof(float) is 4
                // audioClip的样本帧数
                int audioClipLengthSamples = (int)(mpegFile.Length / sizeof(float) / mpegFile.Channels);
                logger.Trace("entry:{0} bytes:{1} mpegFile.Length:{2} mpegFile.Channels:{3} mpegFile.SampleRate:{4} audioClip.lengthSamples:{5}", entry, bytes.Length, mpegFile.Length, mpegFile.Channels, mpegFile.SampleRate, audioClipLengthSamples);

                AudioClip.PCMReaderCallback onRead = (_data) =>
                {
                    //logger.Info("{0}/{1}  {2}/{3} {4}", mpegFile.Position, mpegFile.Length, mpegFile.Time.TotalSeconds, mpegFile.Duration.TotalSeconds, _data.Length);
                    //TODO 处理拖拽进度条时抛出的异常
                    int actualReadCount = mpegFile.ReadSamples(_data, 0, _data.Length);
                };
                // _position的范围为[0, audioClipLengthSamples]
                AudioClip.PCMSetPositionCallback onSetPosition = (_position) =>
                {
                    float percentage = _position / (float)audioClipLengthSamples;
                    if (percentage < 0)
                        percentage = 0f;
                    else if (percentage > 1)
                        percentage = 1.0f;
                    mpegFile.Time = percentage * mpegFile.Duration;
                };
                AudioClip ac = AudioClip.Create(entry, audioClipLengthSamples, mpegFile.Channels, mpegFile.SampleRate, true, onRead, onSetPosition);
                objects_[entry] = ac;
                printObjectsStatus();
                onSuccess();
            }
            else
            {
                // 将耗时间的转换函数放在线程中执行
                CancellationTokenSource tokenSource = new CancellationTokenSource();
                tokenSourceS_.Add(tokenSource);
                Task.Factory.StartNew(() =>
                {
                    int readCount = 0;
                    int lengthSamples = 0;
                    int channels = 0;
                    int sampleRate = 0;
                    float[] samples = null;
                    try
                    {
                        Stream memStream = new MemoryStream(bytes);
                        var mpegFile = new MpegFile(memStream);
                        lengthSamples = (int)(mpegFile.Length / sizeof(float) / mpegFile.Channels);
                        samples = new float[lengthSamples * mpegFile.Channels];
                        channels = mpegFile.Channels;
                        sampleRate = mpegFile.SampleRate;
                        logger.Trace("entry:{0} bytes:{1} mpegFile.Length:{2} mpegFile.Channels:{3} mpegFile.SampleRate:{4}", entry, bytes.Length, mpegFile.Length, mpegFile.Channels, mpegFile.SampleRate);
                        readCount = mpegFile.ReadSamples(samples, 0, lengthSamples * mpegFile.Channels);
                    }
                    catch (System.Exception ex)
                    {
                        logger.Exception(ex);
                        if (tokenSourceS_.Contains(tokenSource))
                            tokenSourceS_.Remove(tokenSource);
                        UnityMainThreadDispatcher.Instance().Enqueue(() =>
                        {
                            onFailure();
                        });
                        return;
                    }

                    if (tokenSource.IsCancellationRequested)
                    {
                        return;
                    }

                    if (tokenSourceS_.Contains(tokenSource))
                        tokenSourceS_.Remove(tokenSource);

                    UnityMainThreadDispatcher.Instance().Enqueue(() =>
                    {
                        if (0 == readCount)
                        {
                            onFailure();
                            return;
                        }

                        AudioClip ac = AudioClip.Create(entry, lengthSamples, channels, sampleRate, false);
                        ac.SetData(samples, 0);
                        objects_[entry] = ac;
                        printObjectsStatus();
                        onSuccess();
                    });
                }, tokenSource.Token);
            }
        }

        private void printObjectsStatus()
        {
            logger.Debug("current archive has {0} Objects loaded in memory", objects_.Count);
        }
    }
}
