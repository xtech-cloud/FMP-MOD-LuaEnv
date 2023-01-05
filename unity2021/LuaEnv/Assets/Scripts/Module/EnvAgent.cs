using System.Collections;
using System.Collections.Generic;
using System.IO;
using XLua;
using XTC.FMP.LIB.MVCS;
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
        public Logger logger { get; set; }
        public UnityEngine.GameObject slotUI { get; set; }
        public UnityEngine.GameObject slotWorld { get; set; }

        private XLua.LuaEnv luaEnv_;
        private LuaTable envTable_;
        private RootLua rootLua_;
        private bool isRunning = false;

        public Dictionary<string, byte[]> codes_ = new Dictionary<string, byte[]>();

        public void Initialize()
        {
            luaEnv_ = new XLua.LuaEnv();
            LuaTable metatable = luaEnv_.NewTable();
            metatable.Set("__index", luaEnv_.Global);
            envTable_ = luaEnv_.NewTable();
            envTable_.SetMetaTable(metatable);
            metatable.Dispose();
            luaEnv_.Global.Set<string, Logger>("G_LOGGER", logger);
            luaEnv_.Global.Set<string, UnityEngine.GameObject>("G_SLOT_UI", slotUI);
            luaEnv_.Global.Set<string, UnityEngine.GameObject>("G_SLOT_WORLD", slotWorld);
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

        public void LoadArchive(string _uri)
        {
            if (_uri.EndsWith("/"))
            {
                // 从本地文件中读取所有lua脚本文件
                foreach (string file in Directory.GetFiles(_uri))
                {
                    if (!file.EndsWith(".lua"))
                        continue;

                    string filename = Path.GetFileNameWithoutExtension(file);
                    codes_[filename] = File.ReadAllBytes(file);
                }
            }
            else
            {
                // 从Archive中读取所有lua脚本文件
                FileReader reader = new FileReader();
                try
                {
                    reader.Open(_uri);
                    // 读取归档类所有lua文件
                    foreach (string entry in reader.entries)
                    {
                        if (!entry.EndsWith(".lua"))
                            continue;

                        string filename = Path.GetFileNameWithoutExtension(entry);
                        codes_[filename] = reader.Read(entry);
                    }
                    reader.Close();
                }
                catch (System.Exception ex)
                {
                    reader.Close();
                    logger.Exception(ex);
                }
            }

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

        private byte[] archiveLoader(ref string _module)
        {
            byte[] code;
            codes_.TryGetValue(_module, out code);
            return code;
        }
    }

}
