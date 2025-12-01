local gui_util = require("../modules/gui_util")
local config = require("../modules/config")

local scr_settings = {}

scr_settings.window = nil
scr_settings.settings = config.config.scr_settings

scr_settings.Render = function()
    scr_settings.window = gui_util.CreateWindow("root@kali: /terminal/settings")
    scr_settings.window.Position = UDim2.fromScale(0.067, 0.101)
    gui_util.MakeWindowDraggable(scr_settings.window)

    local content_holder = gui_util.AddContentHolder(scr_settings.window)
    gui_util.SetContentEnv(content_holder)

    gui_util.AddSection("Terminal")

    gui_util.CreateToggle("Send responses caused by startup commands", function(is_enabled)
        scr_settings.settings.no_startup_response = is_enabled
        config.Save()
    end)

    gui_util.AddSection("Autofarm")

    local dropdown = gui_util.CreateDropdown("Behaviour when loud starts")
    dropdown.SetChoice(scr_settings.settings.af_loud_behaviour)

    for _, action in ipairs({"reset", "turn off autofarm"}) do
        gui_util.AddDropdownOption(dropdown, action, function()
            scr_settings.settings.af_loud_behaviour = action
            config.Save()
        end)
    end

    local dropdown = gui_util.CreateDropdown("Behaviour when the action takes too long")
    dropdown.SetChoice(scr_settings.settings.af_time_exceed_behaviour)

    for _, action in ipairs({"reset", "turn off autofarm"}) do
        gui_util.AddDropdownOption(dropdown, action, function()
            scr_settings.settings.af_time_exceed_behaviour = action
            config.Save()
        end)
    end
end

return scr_settings