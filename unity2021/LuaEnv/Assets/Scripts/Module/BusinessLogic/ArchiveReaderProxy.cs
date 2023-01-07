using System.Collections.Generic;
using System.IO;
using UnityEngine;
using LibMVCS = XTC.FMP.LIB.MVCS;
using XTC.oelArchive;
using NLayer;
using System.Linq;
using System.Threading.Tasks;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    /// <summary>
    /// 归档读取器代理类
    /// </summary>
    public class ArchiveReaderProxy
    {
        public LibMVCS.Logger logger { get; set; }
        private string archiveUri { get; set; }

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

        public void Open(string _uri)
        {
            archiveUri = _uri;
            if (!archiveUri.EndsWith("/"))
            {
                reader_ = new FileReader();
            }
        }

        public void Close()
        {
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

            if (archiveUri.EndsWith("/"))
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
                return File.ReadAllBytes(Path.Combine(archiveUri, _entry));
            }
            else
            {
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
                    return null;
                bytes = File.ReadAllBytes(path);
            }
            else
            {
                if (!reader_.entries.Contains(_entry))
                    return null;
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
                    return null;
                bytes = File.ReadAllBytes(path);
            }
            else
            {
                if (!reader_.entries.Contains(_entry))
                    return null;
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
        /// <param name="_onSuccess"></param>
        /// <param name="_onFailure"></param>
        public void PreReadAudioClipAsync(string _entry, System.Action _onSuccess, System.Action _onFailure)
        {
            if (objects_.ContainsKey(_entry))
                return;

            Task.Run(() =>
            {
                byte[] bytes = null;
                if (null == reader_)
                {
                    string path = Path.Combine(archiveUri, _entry);
                    if (!File.Exists(path))
                    {
                        Debug.LogError("!!!!!!");
                        _onFailure();
                        return;
                    }
                    bytes = File.ReadAllBytes(path);
                }
                else
                {
                    if (!reader_.entries.Contains(_entry))
                    {
                        Debug.LogError("!!!!!!");
                        _onFailure();
                        return;
                    }
                    bytes = reader_.Read(_entry);
                }

                Stream memStream = new MemoryStream(bytes);
                var mpegFile = new MpegFile(memStream);
                int lengthSamples = (int)(mpegFile.Length / sizeof(float) / mpegFile.Channels);
                float[] samples = new float[lengthSamples * mpegFile.Channels];
                int readCount = mpegFile.ReadSamples(samples, 0, lengthSamples * mpegFile.Channels);

                // 需要在主线程执行
                UnityMainThreadDispatcher.Instance().Enqueue(() =>
                {
                    AudioClip ac = AudioClip.Create(_entry, lengthSamples, mpegFile.Channels, mpegFile.SampleRate, false);
                    ac.SetData(samples, 0);
                    objects_[_entry] = ac;
                    _onSuccess();
                    printObjectsStatus();
                });
            });
        }

        private void printObjectsStatus()
        {
            logger.Debug("current archive has {0} Objects loaded in memory", objects_.Count);
        }
    }
}
