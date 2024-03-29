﻿using System;
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
        public MyConfig.Style style { get; set; }
        public string archiveUri { get; set; }

        private XLua.LuaEnv luaEnv_;
        private LuaTable envTable_;
        private RootLua rootLua_;
        private ArchiveReaderProxy archiveReaderProxy_;
        private APIProxy apiProxy_ { get; set; }
        private bool isRunning = false;

        public Dictionary<string, byte[]> codes_ = new Dictionary<string, byte[]>();

        private CoroutineRunner coroutineRunner_ = null;

        public void Initialize()
        {
            coroutineRunner_ = (new GameObject("CoroutineRunner")).AddComponent<CoroutineRunner>();

            archiveReaderProxy_ = new ArchiveReaderProxy();
            archiveReaderProxy_.logger = logger;
            APIProxy.Options options = new APIProxy.Options();
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
            luaEnv_.Global.Set<string, CoroutineRunner>("G_RUNNER_COROUTINE", coroutineRunner_);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_PRIMARY", style.standardColor.primary);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_SECONDARY", style.standardColor.secondary);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_SUCCESS", style.standardColor.success);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_DANGER", style.standardColor.danger);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_WARNING", style.standardColor.warning);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_INFO", style.standardColor.info);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_LIGHT", style.standardColor.light);
            luaEnv_.Global.Set<string, string>("G_STANDARDCOLOR_DARK", style.standardColor.dark);
            luaEnv_.AddLoader(archiveLoader);
        }

        public void Release()
        {
            if (null != coroutineRunner_)
            {
                GameObject.Destroy(coroutineRunner_.gameObject);
                coroutineRunner_ = null;
            }
            if (null != rootLua_)
            {
                rootLua_.Run = null;
                rootLua_.Update = null;
                rootLua_.Stop = null;
                rootLua_.HandleEvent = null;
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
                if (luaEnv_ != null)
                    luaEnv_.Tick();
                if (null == rootLua_ || null == rootLua_.Update)
                    continue;
                rootLua_.Update();
                yield return new UnityEngine.WaitForEndOfFrame();
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

            if (null != rootLua_.Run)
                rootLua_.Run();
            isRunning = true;
        }

        public void Stop()
        {
            isRunning = false;
            if (null != rootLua_ && null != rootLua_.Stop)
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
