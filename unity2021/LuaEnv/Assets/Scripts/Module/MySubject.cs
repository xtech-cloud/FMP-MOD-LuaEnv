
namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    public class MySubject : MySubjectBase
    {
        /// <summary>
        /// Ƕ��
        /// </summary>
        /// <remarks>
        /// ��������ص�slot��
        /// </remarks>
        /// <example>
        /// var data = new Dictionary<string, object>();
        /// data["uid"] = "default";
        /// data["style"] = "default";
        /// data["uiSlot"] = a instance of UnityEngine.GameObejct;
        /// data["worldSlot"] = a instance of UnityEngine.GameObejct;
        /// model.Publish(/XTC/LuaEnv/Inlay, data);
        /// </example>
        public const string Inlay = "/XTC/LuaEnv/Inlay";

        /// <summary>
        /// ˢ������
        /// </summary>
        /// <example>
        /// var data = new Dictionary<string, object>();
        /// data["uid"] = "default";
        /// data["source"] = "assloud://";
        /// data["uri"] = "bundle/_resource/1.lsa";
        /// model.Publish(/XTC/LuaEnv/Refresh, data);
        /// </example>
        public const string Refresh = "/XTC/LuaEnv/Refresh";

    }
}
