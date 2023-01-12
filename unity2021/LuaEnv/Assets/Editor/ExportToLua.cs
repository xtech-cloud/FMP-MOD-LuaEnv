using System.Collections.Generic;
using System;
using XLua;
using UnityEngine;

public static class ExportToLua
{
    [CSharpCallLua]
    public static List<Type> CSharpCallLua = new List<Type>()
    {
        typeof(XTC.FMP.MOD.LuaEnv.LIB.Unity.APIProxy),
        typeof(XTC.FMP.MOD.LuaEnv.LIB.Unity.ArchiveReaderProxy),
        typeof(XTC.FMP.MOD.LuaEnv.LIB.Unity.CounterSequence),
    };


    [LuaCallCSharp]
    public static List<Type> modules = new List<Type>()
    {
    };
}
