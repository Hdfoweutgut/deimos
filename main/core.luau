-- Deimos v2 by @rawparmesan

if game.GameId ~= 324740177 then
    error("Deimos is a script for Entry Point only!")
end

local genv = getgenv()
local is_running = genv.deimos
if is_running == nil or is_running == false then
    genv.deimos = true
else
    error("Deimos is already running!")
end

local start_time = tick()

local gui_util = require("../modules/gui_util")
local places = require("../modules/places")
local tools = require("../modules/tools")
local config = require("../modules/config")
local scr_settings = require("../modules/scr_settings")
scr_settings.Render()

if places.place_group == "mission" then
    task.spawn(function()
        local esp_mgr = require("../modules/esp_mgr")
        esp_mgr.AddNPCsESP()
        esp_mgr.AddCamsESP()
        esp_mgr.AddPlayersESP()
    end)

    local Level = game.Workspace:WaitForChild("Level")
    local Actors = Level:WaitForChild("Actors")

    local ms_data = require("../modules/ms_data")
    if ms_data.current.objects_esp then
        task.spawn(ms_data.current.objects_esp)
    end

    local info_panel = require("../modules/info_panel")
    info_panel.Render()

    local npc_mgr = require("../modules/npc_mgr")

    for _, npc in ipairs(Actors:GetChildren()) do
        task.spawn(npc_mgr.SortNPC, npc)
    end
    Actors.ChildAdded:Connect(npc_mgr.SortNPC)

    npc_mgr.TorsosNoclipLoop()

    tools.IncreaseSimulationRadius()

    local music = require("../modules/music")
    task.spawn(music.Render)
end

if places.place_group == "lobby" then
    local lobby = require("../modules/lobby")
    task.spawn(lobby.Render)
end

local teleport = require("../modules/teleport")
task.spawn(teleport.Render)

local terminal = require("../modules/terminal")
task.spawn(terminal.Init)

local help = require("../modules/help")
task.spawn(help.Render)

local keybinds = require("../modules/keybinds")
task.spawn(keybinds.Render)

local startup = require("../modules/startup")
task.spawn(startup.Render)

gui_util.ScaleElements()
gui_util.gui_holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(gui_util.ScaleElements)

queueonteleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/deimos-script/deimos-v2/refs/heads/main/compiled.luau"))()]])

local end_time = tools.RoundNumber(tick() - start_time, 4)

print("Deimos v2.0.0 successfully loaded in ~"..tostring(end_time).."s ("..tostring(tools.RoundNumber(end_time * 1000)).."ms)")
