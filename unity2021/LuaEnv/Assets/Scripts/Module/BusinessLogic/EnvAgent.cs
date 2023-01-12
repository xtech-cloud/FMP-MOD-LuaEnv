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
        public System.Action<string, object> HandleEvent = null;
    }


    public class EnvAgent
    {

        public LibMVCS.Logger logger { get; set; }
        public GameObject slotUI { get; set; }
        public GameObject slotWorld { get; set; }
        public Font mainFont { get; set; }
        public string archiveUri { get; set; }

        private XLua.LuaEnv luaEnv_;
        private LuaTable envTable_;
        private RootLua rootLua_;
        private ArchiveReaderProxy archiveReaderProxy_;
        private APIProxy apiProxy_ { get; set; }
        private bool isRunning = false;

        public Dictionary<string, byte[]> codes_ = new Dictionary<string, byte[]>();

        public void Initialize()
        {
            archiveReaderProxy_ = new ArchiveReaderProxy();
            archiveReaderProxy_.logger = logger;
            APIProxy.Options options= new APIProxy.Options();
            options.archiveReaderProxy = archiveReaderProxy_;
            apiProxy_ = new APIProxy(options);

            luaEnv_ = new XLua.LuaEnv();
            LuaTable metatable = luaEnv_.NewTable();
            metatable.Set("__index", luaEnv_.Global);
            envTable_ = luaEnv_.NewTable();
            envTable_.SetMetaTable(metatable);
            metatable.Dispose();
            luaEnv_.Global.Set<string, LibMVCS.Logger>("G_LOGGER", logger);
            luaEnv_.Global.Set<string, UnityEngine.GameObject>("G_SLOT_UI", slotUI);
            luaEnv_.Global.Set<string, UnityEngine.GameObject>("G_SLOT_WORLD", slotWorld);
            luaEnv_.Global.Set<string, APIProxy>("G_API_PROXY", apiProxy_);
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
                rootLua_.HandleEvent = null;
                rootLua_ = null;
            }
            //luaEnv_.DoString("local util = require 'xlua.util'\r\nutil.print_func_ref_by_csharp()");
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
            codes_ = archiveReaderProxy_.ReadAllScripts();

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
            rootLua_.Stop();
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
