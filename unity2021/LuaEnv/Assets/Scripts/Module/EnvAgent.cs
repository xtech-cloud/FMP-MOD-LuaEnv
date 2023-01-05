using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using XLua;
using LibMVCS = XTC.FMP.LIB.MVCS;
using XTC.oelArchive;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    public class RootLua
    {
        public System.Action Run = null;
        public System.Action Update = null;
        public System.Action Stop = null;
        public System.Action<object> HandleEvent = null;
    }


    public class EnvAgent
    {
        public class ArchiveReaderProxy
        {
            public EnvAgent agent { get; set; }

            private FileReader reader_;

            public void Open(string _uri)
            {
                if (_uri.EndsWith("/"))
                {
                    // 从本地文件中读取所有lua脚本文件
                    foreach (string file in Directory.GetFiles(_uri))
                    {
                        if (!file.EndsWith(".lua"))
                            continue;

                        string filename = Path.GetFileNameWithoutExtension(file);
                        agent.codes_[filename] = File.ReadAllBytes(file);
                    }
                }
                else
                {
                    reader_ = new FileReader();
                    // 从Archive中读取所有lua脚本文件
                    try
                    {
                        reader_.Open(_uri);
                        // 读取归档类所有lua文件
                        foreach (string entry in reader_.entries)
                        {
                            if (!entry.EndsWith(".lua"))
                                continue;

                            string filename = Path.GetFileNameWithoutExtension(entry);
                            agent.codes_[filename] = reader_.Read(entry);

                        }
                    }
                    catch (System.Exception ex)
                    {
                        agent.logger.Exception(ex);
                    }
                }
            }

            public void Close()
            {
                if (null != reader_)
                {
                    reader_.Close();
                    reader_ = null;
                }
            }

            public byte[] Read(string _entry)
            {
                if (null == reader_)
                {
                    return File.ReadAllBytes(Path.Combine(agent.archiveUri, _entry));
                }
                else
                {
                    return reader_.Read(_entry);
                }
            }
        }

        public LibMVCS.Logger logger { get; set; }
        public GameObject slotUI { get; set; }
        public GameObject slotWorld { get; set; }
        public Font mainFont { get; set; }
        public ObjectsPool contentObjectsPool { get; set; }
        public string archiveUri { get; set; }

        private XLua.LuaEnv luaEnv_;
        private LuaTable envTable_;
        private RootLua rootLua_;
        private ArchiveReaderProxy archiveReaderProxy_;
        private bool isRunning = false;

        public Dictionary<string, byte[]> codes_ = new Dictionary<string, byte[]>();

        public void Initialize()
        {
            archiveReaderProxy_ = new ArchiveReaderProxy();
            archiveReaderProxy_.agent = this;

            luaEnv_ = new XLua.LuaEnv();
            LuaTable metatable = luaEnv_.NewTable();
            metatable.Set("__index", luaEnv_.Global);
            envTable_ = luaEnv_.NewTable();
            envTable_.SetMetaTable(metatable);
            metatable.Dispose();
            luaEnv_.Global.Set<string, LibMVCS.Logger>("G_LOGGER", logger);
            luaEnv_.Global.Set<string, UnityEngine.GameObject>("G_SLOT_UI", slotUI);
            luaEnv_.Global.Set<string, UnityEngine.GameObject>("G_SLOT_WORLD", slotWorld);
            luaEnv_.Global.Set<string, ObjectsPool>("G_OBJECTSPOOL_CONTENT", contentObjectsPool);
            luaEnv_.Global.Set<string, ArchiveReaderProxy>("G_ARCHIVE_READER", archiveReaderProxy_);
            luaEnv_.Global.Set<string, Font>("G_FONT_MAIN", mainFont);
            luaEnv_.AddLoader(archiveLoader);
        }

        public void Release()
        {
            isRunning = false;
            if (null != rootLua_)
            {
                rootLua_.Run = null;
                rootLua_.Update = null;
                rootLua_.Stop = null;
                rootLua_ = null;
            }
            envTable_.Dispose();
            envTable_ = null;
            luaEnv_.Dispose();
            luaEnv_ = null;
            archiveReaderProxy_ = null;
            codes_.Clear();
        }

        public IEnumerator Update()
        {
            while (isRunning)
            {
                yield return new UnityEngine.WaitForEndOfFrame();
                if (null == rootLua_ || null == rootLua_.Update)
                    continue;
                rootLua_.Update();
            }
        }

        public void Run()
        {
            archiveReaderProxy_.Open(archiveUri);

            try
            {
                luaEnv_.DoString("require('root')", "LuaBehaviour", envTable_);
                rootLua_ = envTable_.Get<RootLua>("root");
            }
            catch (System.Exception ex)
            {
                logger.Exception(ex);
            }

            if (null == rootLua_)
            {
                logger.Error("rootLua is null");
                return;
            }

            if (null == rootLua_.Run)
            {
                logger.Error("rootLua.Run is null");
                return;
            }

            rootLua_.Run();
            isRunning = true;
        }

        public void Stop()
        {
            archiveReaderProxy_.Close();
        }

        private byte[] archiveLoader(ref string _module)
        {
            byte[] code;
            codes_.TryGetValue(_module, out code);
            return code;
        }
    }

}
