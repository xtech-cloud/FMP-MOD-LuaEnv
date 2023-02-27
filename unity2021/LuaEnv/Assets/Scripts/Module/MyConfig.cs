
using System.Xml.Serialization;

namespace XTC.FMP.MOD.LuaEnv.LIB.Unity
{
    /// <summary>
    /// 配置类
    /// </summary>
    public class MyConfig : MyConfigBase
    {
        public class StandardColor
        {
            [XmlAttribute("primary")]
            public string primary { get; set; } = "";
            [XmlAttribute("secondary")]
            public string secondary { get; set; } = "";
            [XmlAttribute("success")]
            public string success { get; set; } = "";
            [XmlAttribute("danger")]
            public string danger { get; set; } = "";
            [XmlAttribute("warning")]
            public string warning { get; set; } = "";
            [XmlAttribute("info")]
            public string info { get; set; } = "";
            [XmlAttribute("light")]
            public string light { get; set; } = "";
            [XmlAttribute("dark")]
            public string dark { get; set; } = "";
        }

        public class Style
        {
            [XmlAttribute("name")]
            public string name { get; set; } = "";

            [XmlElement("StandardColor")]
            public StandardColor standardColor { get; set; } = new StandardColor();
        }


        [XmlArray("Styles"), XmlArrayItem("Style")]
        public Style[] styles { get; set; } = new Style[0];
    }
}

