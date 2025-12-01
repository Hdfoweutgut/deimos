local gui_util = require("../modules/gui_util")
local cache = require("../modules/cache")
local config = require("../modules/config")
local terminal = require("../modules/terminal")

local UserInputService = game:GetService("UserInputService")

local startup_config = config.config.startup_cmds

local startup = {}

local cmds_count = 0

startup.InitCommandInput = function(cmd)
    local cmd_index = nil

    if cmd ~= nil then
        cmd_index = table.find(startup_config, cmd)
        if cmd_index == 0 then
            cmd_index = -1
        end
    else
        cmd_index = -1
    end

    local input; input = gui_util.CreateClickableInput("Command", "command", 
        function(command)
            if cmd_index == -1 then
                table.insert(startup_config, command)
                cmd_index = table.find(startup_config, command)
            else
                startup_config[cmd_index] = command
            end

            config.Save()
        end,
        function()
            if cmd_index ~= -1 then
                table.remove(startup_config, cmd_index)
            end

            input.holder:Destroy()

            config.Save()
        end
    )

    if cmd ~= nil then
        input:ChangeText(cmd)
    end
end

startup.Render = function()
    local window = gui_util.CreateWindow("root@kali: /terminal/startup")
    window.Position = UDim2.fromScale(0.453, 0.509)
    cache.startup_window = window
    gui_util.MakeWindowDraggable(window)
    local content_holder = gui_util.AddContentHolder(window)
    gui_util.SetContentEnv(content_holder)

    gui_util.AddSection("Set Startup Commands")

    gui_util.CreateButton("Add New Command", "+ Add New", startup.InitCommandInput)

    for _, cmd in ipairs(startup_config) do
        startup.InitCommandInput(cmd)
        task.spawn(terminal.ValidateCommand, cmd, "startup")
    end
end

return startup