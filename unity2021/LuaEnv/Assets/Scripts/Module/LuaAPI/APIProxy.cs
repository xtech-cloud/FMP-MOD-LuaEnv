using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    public class APIProxy
    {
        public class Options
        {
            public ArchiveReaderProxy archiveReaderProxy;
        }

        public ArchiveReaderProxy archiveReader { get; private set; }
        public CounterSequence preReadSequence { get; private set; }

        public APIProxy(Options _options)
        {
            archiveReader = _options.archiveReaderProxy;
            preReadSequence = new CounterSequence(0);
        }
    }

    public static class APIProxyExport
    {
        [LuaCallCSharp]
        public static List<Type> LuaCallCSharp
        {
            get
            {
                return new List<Type>() {
                        typeof(WaitForSeconds),
                        typeof(WaitForEndOfFrame), 
                };
            }
        }
    }
}
