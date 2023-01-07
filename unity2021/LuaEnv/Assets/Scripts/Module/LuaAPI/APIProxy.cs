using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

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
}
