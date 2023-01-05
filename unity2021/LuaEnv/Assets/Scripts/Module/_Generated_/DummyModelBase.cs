
//*************************************************************************************
//   !!! Generated by the fmp-cli 1.70.0.  DO NOT EDIT!
//*************************************************************************************

using System;
using LibMVCS = XTC.FMP.LIB.MVCS;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    /// <summary>
    /// 虚拟数据基类
    /// </summary>
    public class DummyModelBase : LibMVCS.Model
    {
        public const string NAME = "XTC.FMP.MOD.LuaEnv.LIB.Unity.DummyModel";
        public MyRuntime runtime { get; set; }

        /// <summary>
        /// 虚拟状态基类
        /// </summary>
        public class DummyStatusBase : LibMVCS.Model.Status
        {
            public const string NAME = "XTC.FMP.MOD.LuaEnv.LIB.Unity.DummyStatus";
        }

        public DummyModelBase(string _uid) : base(_uid)
        {
        }

        protected override void preSetup()
        {
            LibMVCS.Error err;
            status_ = spawnStatus<DummyModel.DummyStatus>(DummyStatusBase.NAME, out err);
            if(!LibMVCS.Error.IsOK(err))
            {
                getLogger().Error(err.getMessage());
            }
        }

        protected override void postDismantle()
        {
            LibMVCS.Error err;
            killStatus(DummyStatusBase.NAME, out err);
            if(!LibMVCS.Error.IsOK(err))
            {
                getLogger().Error(err.getMessage());
            }
        }
    }
}
