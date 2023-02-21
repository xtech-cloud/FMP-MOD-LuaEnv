local util = require 'xlua.util'
local app = require 'app'

local function run()
    G_LOGGER:Info("-- PhotoAlbum 6.0.0 --")
    G_LOGGER:Info("lua root.Run ...")
    app.Run()
end

local function update()
    app.Update()
end

local function stop()
    G_LOGGER:Info("lua root.Stop ...")
    app.Stop()
    -- util.print_func_ref_by_csharp()
end

local function handleEvent(_event, _data)
    G_LOGGER:Info(_event)
end

root = {
    Run = run,
    Update = update,
    Stop = stop,
    HandleEvent = handleEvent,
}
