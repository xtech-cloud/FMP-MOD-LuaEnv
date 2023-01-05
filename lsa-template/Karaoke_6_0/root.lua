local app = require 'app'

local function run()
    G_LOGGER:Info("lua root.Run ...")
    G_LOGGER:Info(G_SLOT_UI.name)
    G_LOGGER:Info(G_SLOT_WORLD.name)
    app.Run()
end

local function update()
end

local function stop()
    G_LOGGER:Info("lua root.Stop ...")
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
