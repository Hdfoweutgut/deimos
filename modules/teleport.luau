local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local gui_util = require("../modules/gui_util")

local teleport = {}

teleport.difficulty = 1
teleport.window = nil

teleport.places = {
    ["Story Missions"] = {
		["The Blacksite"] = 3200010305,
		["The Financier"] = 2797881676,
		["The Deposit"] = 2625195454,
		["The Lakehouse"] = 3590667014,
		["The Withdrawal"] = 2951213182,
		["The Scientist"] = 4518266946,
		["The SCRS"] = 4661507759,
		["The Black Dusk"] = 4768829954, 
	},

	["Expansion Missions"] = {
		["The Auction"] = 4134003540,
		["The Gala"] = 3925577908,
		["The Cache"] = 4388762338,
		["The Setup"] = 5071816792,
		["The Lockup"] = 5188855685,
		["The Score"] = 5862433299,
	},

	["Extras"] = {
		["The Killhouse"] = 2215221144,
		["The Concept"] = 7799530284,
	},

	["Story Cutscenes"] = {
		["Black Dawn"] = 740584350,
		["Halcyon"] = 1789049984,
		["Rose"] = 2677301983,
		["Ashes"] = 4980299165,
		["Critical"] = 3217976952,
		["Dedication"] = 3637958652,
		["Retribution"] = 4582472402,
		["Payoff"] = 2957989822,
		["Jackdaw"] = 4980319824,
		["Epilogue"] = 4980337923,
		["Sunset"] = 4988643789,
	},

	["Expansion Cutscenes"] = {
		["Prelude"] = 5564290777,
		["Take"] = 6214650900,
		["Departure"] = 6214651226,
	},

	["Miscellaneous"] = {
		["Character Creation"] = 1169749759,
		["Shadow War"] = 2981901025,
		["PVP Elmination"] = 1169750464,
		["PVP Deathmatch"] = 2048182775,
		["PVE Arena"] = 2139531728,
		["Halcyon Range"] = 2652896498,
		["Ironman Final"] = 2500111229,
	},
}

teleport.Render = function()
    teleport.window = gui_util.CreateWindow("root@kali: /terminal/teleport")
	teleport.window.Position = UDim2.fromScale(0.067, 0.509)
    gui_util.MakeWindowDraggable(teleport.window)
    local content_holder = gui_util.AddContentHolder(teleport.window)
    gui_util.SetContentEnv(content_holder)
    gui_util.AddSection("Teleport To The Place")

    local Frame = gui_util.AddElementFrame()
    gui_util.AddElementLabel(Frame, "Mission Difficulty (0 - 5)")
    gui_util.AddElementInput(Frame, "0 - 5", function(difficulty)
        teleport.difficulty = tonumber(difficulty)
    end)

    for dropdown_name, dropdown_data in pairs(teleport.places) do
        local dropdown = gui_util.CreateDropdown(dropdown_name)
        for place_name, place_id in pairs(dropdown_data) do
            gui_util.AddDropdownOption(dropdown, place_name, function()
                TeleportService:Teleport(place_id, LocalPlayer, {Difficulty = teleport.difficulty})
            end)
        end
		dropdown.ApplyVerticalFlex()
    end
end

return teleport