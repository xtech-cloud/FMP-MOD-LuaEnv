

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using LibMVCS = XTC.FMP.LIB.MVCS;
using XTC.FMP.MOD.LuaEnv.LIB.Proto;
using XTC.FMP.MOD.LuaEnv.LIB.MVCS;
using System.IO;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{


    public class UiReference
    {
    }

    /// <summary>
    /// 实例类
    /// </summary>
    public class MyInstance : MyInstanceBase
    {
        private EnvAgent envAgent_ = null;
        private UiReference uiReference_ = new UiReference();

        public MyInstance(string _uid, string _style, MyConfig _config, MyCatalog _catalog, LibMVCS.Logger _logger, Dictionary<string, LibMVCS.Any> _settings, MyEntryBase _entry, MonoBehaviour _mono, GameObject _rootAttachments)
            : base(_uid, _style, _config, _catalog, _logger, _settings, _entry, _mono, _rootAttachments)
        {
        }

        /// <summary>
        /// 当被创建时
        /// </summary>
        /// <remarks>
        /// 可用于加载主题目录的数据
        /// </remarks>
        public void HandleCreated()
        {
        }

        /// <summary>
        /// 当被删除时
        /// </summary>
        public void HandleDeleted()
        {
        }

        /// <summary>
        /// 当被打开时
        /// </summary>
        /// <remarks>
        /// 可用于加载内容目录的数据
        /// </remarks>
        public void HandleOpened(string _source, string _uri)
        {

            rootUI.gameObject.SetActive(true);
            rootWorld.gameObject.SetActive(true);

            open(_source, _uri);
        }

        /// <summary>
        /// 当被关闭时
        /// </summary>
        public void HandleClosed()
        {
            rootUI.gameObject.SetActive(false);
            rootWorld.gameObject.SetActive(false);
            mono_.StartCoroutine(close());
        }

        private void open(string _source, string _uri)
        {
            logger_.Trace("************* LuaEnvAgent is created ************");
            // 创建lua环境
            envAgent_ = new EnvAgent();
            envAgent_.logger = logger_;
            envAgent_.slotUI = rootUI;
            envAgent_.slotWorld = rootWorld;
            envAgent_.mainFont = settings_["font.main"].AsObject() as Font;
            envAgent_.archiveUri = Path.Combine(settings_["path.assets"].AsString(), _uri);
            envAgent_.style = style_;

            envAgent_.Initialize();
            envAgent_.Run();

            mono_.StartCoroutine(envAgent_.Update());
        }

        private IEnumerator close()
        {
            envAgent_.Stop();
            yield return new WaitForEndOfFrame();
            envAgent_.Release();
            envAgent_ = null;
            logger_.Trace("************* LuaEnvAgent is destroied ************");
        }
    }
}
