local gui_util = require("../modules/gui_util")
local cmds_mgr = require("../modules/cmds_mgr")
local cache = require("../modules/cache")
local config = require("../modules/config")
local places = require("../modules/places")

local ms_data, objassist_mgr, npc_mgr = nil, nil, nil

if places.place_group == "mission" then
	ms_data = require("../modules/ms_data")
	objassist_mgr = require("../modules/objassist_mgr")
	npc_mgr = require("../modules/npc_mgr")
end

local gui_size = gui_util.gui_holder.AbsoluteSize

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

if places.place_group == "mission" then 
	GameState = ReplicatedStorage:WaitForChild("GameState", math.huge)
    start_time = GameState:WaitForChild("Start", math.huge)
end

local terminal = {}

terminal.cmds_default_args = {"kill", "bring", "hide", "void"}
terminal.commands_holder = nil
terminal.cmds_text_size = (gui_size.X + gui_size.Y) / 220.54
terminal.last_cmd_input = nil
terminal.last_cmd_tip = nil
terminal.terminal_label = nil
terminal.terminal_background = nil
terminal.tips_container = nil
terminal.tip_base = nil
terminal.on_input_end = nil
terminal.matched_word = nil
terminal.generated_tips = {}
terminal.selected_tip = 1

terminal.Render = function()
	local terminal_label = Instance.new("CanvasGroup")
	terminal_label.ZIndex = 11
	terminal_label.BorderSizePixel = 0
	terminal_label.BackgroundColor3 = Color3.fromRGB(21, 22, 26)
	terminal_label.Size = UDim2.fromScale(0.20855, 0.02160000056028366)
	terminal_label.Position = UDim2.fromScale(0.7586, 0.31019)
	terminal_label.Name = "terminal_label"
	terminal_label.Visible = false
	terminal_label.Parent = gui_util.gui_holder

	terminal.terminal_label = terminal_label

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0.24, 0)
	UICorner.Parent = terminal_label

	local dragon_image = Instance.new("ImageLabel")
	dragon_image.ZIndex = 12
	dragon_image.BorderSizePixel = 0
	dragon_image.SliceScale = 0
	dragon_image.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dragon_image.ImageColor3 = Color3.fromRGB(10, 11, 15)
	dragon_image.Image = "http://www.roblox.com/asset/?id=18444439483"
	dragon_image.Size = UDim2.fromScale(0.6, 7.64)
	dragon_image.BackgroundTransparency = 1
	dragon_image.Name = "dragon_image"
	dragon_image.Position = UDim2.fromScale(-0.08497, -2.69136)
	dragon_image.Parent = terminal_label

	local terminal_directory = Instance.new("TextLabel")
	terminal_directory.TextWrapped = true
	terminal_directory.ZIndex = 12
	terminal_directory.TextScaled = true
	terminal_directory.BackgroundTransparency = 1
	terminal_directory.Size = UDim2.fromScale(1, 1)
	terminal_directory.Text = "root@kali: ~/roblox/entrypoint"
	terminal_directory.Name = "terminal_directory"
	terminal_directory.TextColor3 = Color3.fromRGB(255, 255, 255)
	terminal_directory.FontFace = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	terminal_directory.Parent = terminal_label

	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingTop = UDim.new(0.28026, 0)
	UIPadding.PaddingBottom = UDim.new(0.28026, 0)
	UIPadding.Parent = terminal_directory

	local left_corner = Instance.new("Frame")
	left_corner.ZIndex = 12
	left_corner.BorderSizePixel = 0
	left_corner.BackgroundColor3 = Color3.fromRGB(21, 22, 26)
	left_corner.Size = UDim2.fromScale(0.025, 0.4)
	left_corner.Position = UDim2.fromScale(0, 0.6)
	left_corner.Name = "left_corner"
	left_corner.Parent = terminal_label

	local right_corner = left_corner:Clone()
	right_corner.Position = UDim2.fromScale(0.975, 0.6)
	right_corner.Name = "right_corner"
	right_corner.Parent = terminal_label

	local function AddLabelWindowButton(image_color, image, pos)
		local window_button = Instance.new("ImageLabel")
		window_button.BorderSizePixel = 0
		window_button.ZIndex = 12
		window_button.BackgroundTransparency = 1
		window_button.Image = image
		window_button.ImageColor3 = image_color
		window_button.Size = UDim2.fromScale(0.02249, 0.36033)
		window_button.Position = pos
		window_button.Parent = terminal_label
	end

	AddLabelWindowButton(Color3.fromRGB(255, 255, 255), "http://www.roblox.com/asset/?id=18469798055", UDim2.fromScale(0.96, 0.34015))
	AddLabelWindowButton(Color3.fromRGB(255, 255, 255), "http://www.roblox.com/asset/?id=18469928258", UDim2.fromScale(0.93, 0.34))
	AddLabelWindowButton(Color3.fromRGB(201, 201, 201), "http://www.roblox.com/asset/?id=18469803005", UDim2.fromScale(0.9, 0.42))

	local terminal_icon = Instance.new("ImageLabel")
	terminal_icon.ZIndex = 12
	terminal_icon.BorderSizePixel = 0
	terminal_icon.BackgroundTransparency = 1
	terminal_icon.ImageColor3 = Color3.fromRGB(176, 176, 176)
	terminal_icon.Image = "http://www.roblox.com/asset/?id=18453717387"
	terminal_icon.Size = UDim2.fromScale(0.04248, 0.68063)
	terminal_icon.Name = "terminal_icon"
	terminal_icon.Position = UDim2.fromScale(0.015, 0.16015)
	terminal_icon.Parent = terminal_label

	local settings_button = Instance.new("Frame")
	settings_button.ZIndex = 12
	settings_button.BorderSizePixel = 0
	settings_button.BackgroundColor3 = Color3.fromRGB(40, 43, 53)
	settings_button.Size = UDim2.fromScale(0.03998, 0.64059)
	settings_button.Position = UDim2.fromScale(0.82207, 0.20019)
	settings_button.Name = "settings"
	settings_button.Parent = terminal_label

	local UIStroke = Instance.new("UIStroke")
	UIStroke.Thickness = 0.75
	UIStroke.Parent = settings_button

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0.2, 0)
	UICorner.Parent = settings_button

	local settings_button_image = Instance.new("ImageLabel")
	settings_button_image.ZIndex = 13
	settings_button_image.BackgroundTransparency = 1
	settings_button_image.BorderSizePixel = 0
	settings_button_image.Image = "http://www.roblox.com/asset/?id=18457358643"
	settings_button_image.Size = UDim2.fromScale(0.75, 0.75)
	settings_button.Rotation = 90
	settings_button_image.Position = UDim2.fromScale(0.125, 0.125)
	settings_button_image.Parent = settings_button

	local search_button = settings_button:Clone()
	search_button.Position = UDim2.fromScale(0.77, 0.20019)

	search_button.ImageLabel.Image = "http://www.roblox.com/asset/?id=18457354288"
	search_button.ImageLabel.Rotation = 0
	search_button.ImageLabel.Position = UDim2.fromScale(0.125, 0.125)

	search_button.Parent = terminal_label

	local terminal_background = Instance.new("Frame")
	terminal_background.BorderSizePixel = 0
	terminal_background.BackgroundColor3 = Color3.fromRGB(25, 26, 31)
	terminal_background.Size = UDim2.fromScale(0.20879, 0.3959999978542328)
	terminal_background.Position = UDim2.fromScale(0.75836, 0.31019)
	terminal_background.Name = "terminal_background"
	terminal_background.BackgroundTransparency = 0.05
	terminal_background.ZIndex = 10
	terminal_background.Visible = false
	terminal_background.Parent = gui_util.gui_holder

	terminal.terminal_background = terminal_background

	local container_holder = Instance.new("Frame")
	container_holder.Size = UDim2.fromScale(0.104, 0.087)
	container_holder.BackgroundColor3 = Color3.fromRGB(29, 29, 34)
	container_holder.ZIndex = 14
	container_holder.BorderSizePixel = 1
	container_holder.BorderColor3 = Color3.fromRGB(106, 106, 106)
	container_holder.Visible = false
	container_holder.AnchorPoint = Vector2.new(0, 0.4)
	container_holder.Parent = gui_util.gui_holder

	local tips_container = Instance.new("ScrollingFrame")
	tips_container.BackgroundTransparency = 1
	tips_container.Size = UDim2.fromScale(1, 1)
	tips_container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tips_container.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	tips_container.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	tips_container.ScrollBarThickness = 2
	tips_container.ScrollingDirection = Enum.ScrollingDirection.Y
	tips_container.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	tips_container.ZIndex = 15
	tips_container.BorderSizePixel = 0
	tips_container.CanvasSize = UDim2.fromScale(0, 1)
	tips_container.Parent = container_holder

	terminal.tips_container = tips_container

	local tip_base = Instance.new("Frame")
	tip_base.Size = UDim2.fromScale(1, 0.2)
	tip_base.BackgroundColor3 = Color3.fromRGB(29, 29, 34)
	tip_base.ZIndex = 16
	tip_base.Visible = false
	tip_base.BorderSizePixel = 0
	tip_base.Parent = terminal_background

	terminal.tip_base = tip_base
	
	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingBottom = UDim.new(0.2, 0)
	UIPadding.PaddingLeft = UDim.new(0.025, 0)
	UIPadding.PaddingTop = UDim.new(0.2, 0)
	UIPadding.Parent = tip_base

	local TextLabel = gui_util.GetUbuntuText("")
	TextLabel.Size = UDim2.fromScale(0.975, 1)
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.ZIndex = 17
	TextLabel.Parent = tip_base

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.Parent = tips_container

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0.0133)
	UICorner.Parent = terminal_background

	local commands_holder = Instance.new("ScrollingFrame")
	commands_holder.BorderSizePixel = 0
	commands_holder.Active = true
	commands_holder.ScrollingDirection = Enum.ScrollingDirection.Y
	commands_holder.BackgroundTransparency = 1
	commands_holder.CanvasSize = UDim2.fromScale(0, 1)
	commands_holder.Name = "commands_holder"
	commands_holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	commands_holder.Size = UDim2.fromScale(0.9609, 0.89884)
	commands_holder.Position = UDim2.fromScale(0.02496, 0.07546)
	commands_holder.ScrollBarThickness = 2
	commands_holder.ZIndex = 11
	commands_holder.Parent = terminal_background

	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingRight = UDim.new(0.03, 0)
	UIPadding.Parent = commands_holder

	terminal.commands_holder = commands_holder

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.Padding = UDim.new(0.015, 0)
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Parent = commands_holder
end

terminal.checks = {
	PlaceCheck = function(name, flags)
		if flags.req_place_type ~= nil then
			local current = places.place_group

			local required = flags.req_place_type
			if required == "any" then 
				return true, nil 
			end

			if current ~= required then
				return false, "ConditionError: command \""..name.."\" can be executed only in the "..required.."."
			end
		end
		
		return true, nil
	end,

	UNCCompatibilityCheck = function(name, flags)
		if flags.required_funcs ~= nil then
			for _, func in ipairs(flags.required_funcs) do
				if func ~= nil then continue end
				return false, "IntegrityError: "..(getexecutorname and getexecutorname() or "your executor").." can't execute command \""..name.."\"."
			end
		end

		return true, nil
	end,

	MissingArgsCheck = function(args, flags)
		local req_args = flags.args
		if req_args == nil then return true, nil end

		local missing = "MissingArgsError: make sure you entered value(s) for "
		local found_missing = false

		for index, arg_flags in ipairs(req_args) do
			if req_args[index].name ~= "npc_group" and args[index] == nil then 
				if arg_flags.required ~= true then continue end
				
				missing = missing..arg_flags.name..", "
				found_missing = true
			end
		end

		if found_missing == true then
			missing = string.sub(missing, 0, -3).." arg(s)."
			return false, missing
		else
			return true, nil
		end
	end,

	TypesMismatchCheck = function(args, flags)
		local req_args = flags.args
		if req_args == nil then return true, nil end

		local types = "TypeMismatchError: "
		local found_types = false

		for index, arg_flags in ipairs(req_args) do
			if req_args[index].name == "npc_group" or (req_args[index].required == false and args[index] == nil) then continue end

			if arg_flags.type == "number" and tonumber(args[index]) == nil then
				found_types = true
				types = types..arg_flags.name.." should be a number, "
			elseif arg_flags.type == "text" and tonumber(args[index]) ~= nil then
				found_types = true
				types = types..arg_flags.name.." should be a text, "
			end
		end

		if found_types == true then
			types = string.sub(types, 0, -3).."."
			return false, types
		else
			return true, nil
		end
	end,

	BossCheck = function(name, flags)
		if ms_data ~= nil and table.find({"killboss"}, name) and flags.boss_required == true and ms_data.current.kill_boss == nil then
			return false, "ConditionError: command \""..name.."\" works only in missions with bosses (gunships, SWAT vans, Onyx Unit)."
		end

		return true, nil
	end,

	ObjassistCheck = function(flags)
		if objassist_mgr ~= nil and flags.objassist_required == true and objassist_mgr[game.PlaceId] == nil then
			return false, "LookupError: objective assistance for this mission doesn't exists."
		end

		return true, nil
	end,

	MissionStartedCheck = function(name, flags)
		if flags.before_mission_start == true and start_time.Value ~= 0 then
        	return false,  "ConditionError: command \""..name.."\" can be executed only before the mission start."
    	end

		return true, nil
	end,

	TeamsExistenceCheck = function(args, flags)
		if npc_mgr == nil then return true, nil end 

		local req_args = flags.args
		if req_args == nil then return true, nil end

		local last_index = #req_args
		if req_args[last_index].name == "npc_group" then
			if args[last_index] == nil then
				return false, "MissingArgsError: you need to enter one or more npc groups for this command."
			end

			local found_team = false 
			local wrong_team = "WrongTeamWarning: team(s) "
			
			for index = last_index, #args, 1 do
				local team_aliase = args[index]

				if team_aliase == "sp" and flags.sp_allowed == false then
					terminal.SendResponse({
						response_text = "ConditionWarning: this command doesn't works with snipers.",
						timestamp = true
					})
				end

				if npc_mgr.aliases[team_aliase] == nil then
					found_team = true
					wrong_team = wrong_team..team_aliase..", "
				end
			end

			if found_team == true then
				wrong_team = string.sub(wrong_team, 0, -3).." doesn't exists."
				terminal.SendResponse({
					response_text = wrong_team,
					timestamp = true
				})
			end
		end

		return true, nil
	end
}

terminal.GroupSameWords = function(words_table)
	local same = {}
	
	for _, word in ipairs(words_table) do
		if not same[word] then
			same[word] = 1
		else
			same[word] += 1
		end
	end
	
	local finished = {}
	
	for word, amount in pairs(same) do
		table.insert(
			finished, 
			amount > 1 and word.." ("..tostring(amount).."x)" or word
		)
	end
	
	return finished
end

terminal.GetLastInputCmdArgs = function(str)
	return string.match(str, ", *(%a[^,]*)$") or string.match(str, "^[^,]+$")
end

terminal.GetArgs = function(last_input_cmd_args)
	local copy = table.clone(last_input_cmd_args)
	table.remove(copy, 1)

	return copy
end

terminal.ParseCmdArgs = function(str)
	local splitted = string.split(str, " ")
	
	for index, value in ipairs(splitted) do
		if value == "" then
			table.remove(splitted, index)
		end
	end
	
	return splitted
end

terminal.GenerateTipButton = function(text)
	local tip = terminal.tip_base:Clone()
	tip.TextLabel.Text = text
	tip.Visible = true
	
	return tip
end

terminal.ShowTipList = function()
	terminal.tips_container.Parent.Visible = true
end

terminal.HideTipList = function()
	terminal.tips_container.Parent.Visible = false
end

terminal.ClearTipList = function()
	for _, obj in ipairs(terminal.tips_container:GetChildren()) do
		if obj.ClassName == "UIListLayout" then continue end
		obj:Destroy()
	end

	terminal.generated_tips = {}
	terminal.selected_tip = 1
end

terminal.BuildTipList = function(tips)
	terminal.ClearTipList()

	for _, tip_text in ipairs(tips) do
		local tip = terminal.GenerateTipButton(tip_text)
		table.insert(terminal.generated_tips, tip)
		tip.Parent = terminal.tips_container
	end

	RunService.RenderStepped:Wait()
end

terminal.UpdateTipListPos = function()
	local x_pos = terminal.last_cmd_input.AbsolutePosition.X + terminal.last_cmd_input.TextBounds.X + 5
	local y_pos = terminal.last_cmd_input.AbsolutePosition.Y - 5

	terminal.tips_container.Parent.Position = UDim2.fromOffset(x_pos, y_pos)
end

terminal.SelectTip = function(direction)
	if #terminal.generated_tips == 0 then return end

	local tip_y_size = terminal.generated_tips[1].AbsoluteSize.Y

	terminal.generated_tips[terminal.selected_tip].BackgroundColor3 = Color3.fromRGB(29, 29, 34)

	if direction == "down" and terminal.selected_tip < #terminal.generated_tips then
		terminal.selected_tip += 1
		--terminal.tips_container.CanvasPosition = Vector2.new(0, (terminal.selected_tip <= 5 and 0 or (terminal.selected_tip - 5) * tip_y_size))
	elseif direction == "up" and terminal.selected_tip > 1 then
		terminal.selected_tip -= 1
		--terminal.tips_container.CanvasPosition = Vector2.new(0, (terminal.selected_tip > 5 and terminal.selected_tip * tip_y_size or 0))
	end

	terminal.tips_container.CanvasPosition = Vector2.new(0, (terminal.selected_tip <= 5 and 0 or (terminal.selected_tip - 5) * tip_y_size))

	terminal.generated_tips[terminal.selected_tip].BackgroundColor3 = Color3.fromRGB(45, 58, 95)
end

terminal.GenerateArgTip = function(arg_data)
	return arg_data.name..": "..(arg_data.type == "number" and "num" or "text")..(arg_data.required == true and "" or "?")..(arg_data.multiple == true and "+" or "") 
end

terminal.SendResponse = function(args)
	local MessageHolder = Instance.new("Frame")
	MessageHolder.Size = UDim2.fromScale(1, args.custom_y or 0.035)
	MessageHolder.ZIndex = 12
	MessageHolder.BackgroundTransparency = 1
	MessageHolder.Name = "response_holder"
	MessageHolder.AutomaticSize = Enum.AutomaticSize.Y
	MessageHolder.Parent = terminal.commands_holder

	local UISizeConstraint = Instance.new("UISizeConstraint")
	UISizeConstraint.MaxSize = Vector2.new(tonumber("inf"), 240)
	UISizeConstraint.Parent = MessageHolder

	local ResponseMessage = Instance.new("TextLabel")
	ResponseMessage.TextScaled = true
	ResponseMessage.LineHeight = 1.2
	ResponseMessage.ZIndex = 2
	ResponseMessage.BorderSizePixel = 0
	ResponseMessage.TextXAlignment = Enum.TextXAlignment.Left
	ResponseMessage.TextYAlignment = Enum.TextYAlignment.Top
	ResponseMessage.TextSize = terminal.cmds_text_size
	ResponseMessage.FontFace = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	ResponseMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
	ResponseMessage.BackgroundTransparency = 1
	ResponseMessage.RichText = true
	ResponseMessage.Size = UDim2.fromScale(1, 1)
	ResponseMessage.BorderColor3 = Color3.fromRGB(0, 0, 0)
	ResponseMessage.Text = (args.timestamp == true and os.date("%X").." - " or "")..args.response_text
	ResponseMessage.AutomaticSize = Enum.AutomaticSize.Y
	ResponseMessage.Name = "response"
	ResponseMessage.ZIndex = 12
	ResponseMessage.Parent = MessageHolder

	local UITextSizeConstraint = Instance.new("UITextSizeConstraint")
	UITextSizeConstraint.MaxTextSize = 13
	UITextSizeConstraint.Parent = ResponseMessage

	return ResponseMessage
end

terminal.CreateCmdInput = function()
	local InputHolder = Instance.new("Frame")
	InputHolder.BorderSizePixel = 0
	InputHolder.Size = UDim2.fromScale(1, 0.035)
	InputHolder.Position = UDim2.fromScale(0.60678, 0)
	InputHolder.BackgroundTransparency = 1
	InputHolder.ZIndex = 12
	InputHolder.LayoutOrder = 1
	InputHolder.Name = "input_holder"
	InputHolder.Parent = terminal.commands_holder

	local Username = Instance.new("TextLabel")
	Username.ZIndex = 2
	Username.BorderSizePixel = 0
	Username.TextXAlignment = Enum.TextXAlignment.Left
	Username.TextYAlignment = Enum.TextYAlignment.Top
	Username.TextScaled = true
	Username.FontFace = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	Username.TextColor3 = Color3.fromRGB(255, 255, 255)
	Username.BackgroundTransparency = 1
	Username.RichText = true
	Username.Size = UDim2.fromScale(0.16, 1)
	Username.BorderColor3 = Color3.fromRGB(0, 0, 0)
	Username.Text = [[<font color="rgb(115, 178, 255)">root@kali</font>:]]
	Username.ZIndex = 13
	Username.Name = "username"
	Username.Parent = InputHolder

	local CommandInput = Instance.new("TextBox", InputHolder)
	CommandInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	CommandInput.BorderSizePixel = 0
	CommandInput.TextXAlignment = Enum.TextXAlignment.Left
	CommandInput.TextYAlignment = Enum.TextYAlignment.Top
	CommandInput.FontFace = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	CommandInput.RichText = true
	CommandInput.ClearTextOnFocus = false
	CommandInput.ClipsDescendants = false
	CommandInput.TextScaled = true
	CommandInput.Size = UDim2.fromScale(0.83393, 1)
	CommandInput.BorderColor3 = Color3.fromRGB(0, 0, 0)
	CommandInput.BackgroundTransparency = 1
	CommandInput.Text = ""
	CommandInput.Name = "command_input"
	CommandInput.LayoutOrder = 1
	CommandInput.ZIndex = 13

	local UITextSizeConstraint = Instance.new("UITextSizeConstraint")
	UITextSizeConstraint.MinTextSize = 13
	UITextSizeConstraint.Parent = CommandInput

	local CommandTip = Instance.new("TextLabel", CommandInput)
	CommandTip.TextColor3 = Color3.fromRGB(100, 100, 100)
	CommandTip.BorderSizePixel = 0
	CommandTip.TextXAlignment = Enum.TextXAlignment.Left
	CommandTip.TextSize = terminal.cmds_text_size
	CommandTip.TextYAlignment = Enum.TextYAlignment.Top
	CommandTip.FontFace = Font.new([[rbxasset://fonts/families/Ubuntu.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	CommandTip.RichText = true
	CommandTip.ClipsDescendants = true
	CommandTip.Size = UDim2.fromScale(1, 1)
	CommandTip.BorderColor3 = Color3.fromRGB(0, 0, 0)
	CommandTip.BackgroundTransparency = 1
	CommandTip.Text = ""
	CommandTip.ZIndex = 12

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.FillDirection = Enum.FillDirection.Horizontal
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Parent = InputHolder

	terminal.last_cmd_input = CommandInput
	terminal.last_cmd_tip = CommandTip

	return CommandInput, CommandTip
end

terminal.ValidateCommand = function(input, source)
	for _, cmd_with_args in ipairs(string.split(input, ",")) do
		--local cmd_with_args = terminal.GetLastInputCmdArgs(input)
		--if not cmd_with_args then return end

		local parsed = terminal.ParseCmdArgs(cmd_with_args)

		local args = terminal.GetArgs(parsed)
		local cmd = parsed[1]

		local cmd_data = cmds_mgr.GetCmdData(cmd)
		if cmd_data == nil then
			terminal.SendResponse({
				response_text = "LookupError: command \""..cmd.."\" doesn't exists.",
				timestamp = true
			})

			return
		end

		local cmd_flag = cmds_mgr.GetCmdFlag(cmd)
		if source == "autofarm" and cmd_flag == true then return end

		if source ~= "autofarm" and (cmd_flag == nil or cmd_flag == false) then
			if cmds_mgr.GetCmdFlag("autofarm") == true and cmd_data.checks.af_compatible ~= true then
				terminal.SendResponse({
					response_text = "ConditionError: command \""..cmd.."\" can't be executed during autofarm.",
					timestamp = true
				})

				return
			end

			cmd_data = cmd_data.checks
			local checks = terminal.checks

			for _, check in ipairs({"PlaceCheck", "UNCCompatibilityCheck", "BossCheck", "MissionStartedCheck"}) do
				local success, response = checks[check](cmd, cmd_data)
				if response ~= nil and (source ~= "startup" or (source == "startup" and config.config.scr_settings.startup_response == true)) then 
					terminal.SendResponse({response_text = response, timestamp = true}) 
				end
				if success == false then return end
			end

			for _, check in ipairs({"MissingArgsCheck", "TypesMismatchCheck"}) do
				local success, response = checks[check](args, cmd_data)
				if response ~= nil and (source ~= "startup" or (source == "startup" and config.config.scr_settings.startup_response == true)) then 
					terminal.SendResponse({response_text = response, timestamp = true}) 
				end
				if success == false then return end
			end

			local success, response = checks.ObjassistCheck(cmd_data)
			if response ~= nil and (source ~= "startup" or (source == "startup" and config.config.scr_settings.startup_response == true)) then 
				terminal.SendResponse({response_text = response, timestamp = true}) 
			end
			if success == false then return end

			local success, response = checks.TeamsExistenceCheck(args, cmd_data)
			if response ~= nil and (source ~= "startup" or (source == "startup" and config.config.scr_settings.startup_response == true)) then 
				terminal.SendResponse({response_text = response, timestamp = true}) 
			end
			if success == false then return end
		end
			
		local command_response = cmds_mgr.cmds(cmd, source, unpack(args))
		--if source == "autofarm" or source == "startup" then return end

		if command_response ~= nil then
			if source ~= "autofarm" and source ~= "startup" then
				terminal.SendResponse({response_text = command_response, timestamp = false})
			end
		end
	end
end

terminal.ScrollOnContentSizeChange = function()
	local cmds_holder = terminal.commands_holder
	cmds_holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if cmds_holder.UIListLayout.AbsoluteContentSize.Y > cmds_holder.AbsoluteSize.Y then
			cmds_holder.CanvasPosition = Vector2.new(0, 1000000)
			cmds_holder.UIListLayout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
		else
			cmds_holder.CanvasPosition = Vector2.new(0, 0)
		end
	end)
end

terminal.SetCmdsHolderPos = function()
	local cmds_holder = terminal.commands_holder
	if cmds_holder.UIListLayout.AbsoluteContentSize.Y > cmds_holder.AbsoluteSize.Y then
		cmds_holder.CanvasPosition = Vector2.new(0, 1000000)
		cmds_holder.UIListLayout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
	else
		cmds_holder.CanvasPosition = Vector2.new(0, 0)
	end
end

terminal.LastInputIsWriteable = function()
	return terminal.last_cmd_input and terminal.last_cmd_input.Text == ""
end

terminal.FocusLastInput = function()
	terminal.last_cmd_input:CaptureFocus()
end

terminal.Show = function()
	terminal.terminal_label.Visible = true 
	terminal.terminal_background.Visible = true
end

terminal.Hide = function()
	terminal.terminal_label.Visible = false 
	terminal.terminal_background.Visible = false
end

terminal.ListenForInputEnd = function()
	local last_cmd_input = terminal.last_cmd_input
	local conn; conn = last_cmd_input.FocusLost:Connect(function()
		terminal.HideTipList()

		terminal.Hide()

		if last_cmd_input.Text ~= "" then
			conn:Disconnect()
			last_cmd_input.TextEditable = false
			last_cmd_input.Parent.LayoutOrder = 0
			terminal.ValidateCommand(last_cmd_input.Text, "terminal")
		end

		terminal.last_cmd_tip.Text = ""
	end)
end

terminal.RemoveSemicolon = function()
	if string.find(terminal.last_cmd_input.Text, ";") then
		terminal.last_cmd_input.Text = string.gsub(terminal.last_cmd_input.Text, ";", "")
	end
end

terminal.Open = function()
	terminal.Show()

	if terminal.LastInputIsWriteable() == true then
		terminal.FocusLastInput()
	else
		terminal.CreateCmdInput()
		terminal.FocusLastInput()
		terminal.ListenForInputEnd()
	end

	terminal.SetCmdsHolderPos()

	terminal.last_cmd_input:GetPropertyChangedSignal("Text"):Connect(function()
		terminal.RemoveSemicolon()

		local cmd_tip = terminal.last_cmd_tip
		local cmd_input = terminal.last_cmd_input

		if cmd_input.Text == "" then 
			cmd_tip.Text = "" 
			terminal.HideTipList()

			return 
		end

		local cmd_with_args = terminal.GetLastInputCmdArgs(cmd_input.Text)
		if cmd_with_args == nil then terminal.HideTipList(); cmd_tip.Text = ""; return end

		local parsed = terminal.ParseCmdArgs(cmd_with_args)
		if parsed then
			local cmd_name_matches, exact_match = cmds_mgr.GetMatchedCommands(parsed[1])
			
			if #parsed == 1 then
				cmd_tip.Text = ""

				if #cmd_name_matches == 0 then 
					terminal.HideTipList()
				elseif string.match(cmd_input.Text, " $") == nil then
					terminal.BuildTipList(cmd_name_matches)

					terminal.SelectTip("up")
					terminal.UpdateTipListPos()
					terminal.ShowTipList()
				end
			end

			if exact_match == true and string.match(cmd_input.Text, " $") ~= nil then
				local cmd_data = cmds_mgr.GetCmdData(parsed[1])
				if cmd_data == nil or cmd_data.checks == nil or cmd_data.checks.args == nil then 
					terminal.HideTipList() 

					cmd_tip.Text = ""

					return 
				end

				cmd_tip.Text = ""

				for _, word in ipairs(parsed) do
					cmd_tip.Text ..= word.." "
				end

				local cmd_data_args = cmd_data.checks.args
				local expected_arg = cmd_data_args[#parsed] or (cmd_data_args[#cmd_data_args].multiple == true and cmd_data_args[#cmd_data_args] or nil)

				if expected_arg ~= nil then
					cmd_tip.Text ..= terminal.GenerateArgTip(expected_arg).." "
				end

				if expected_arg == nil or expected_arg.tip_gen == nil then 
					terminal.HideTipList()
					--cmd_tip.Text = ""
					return 
				end

				local args = terminal.GetArgs(parsed)
				local tips = expected_arg.tip_gen(args)
				if tips == nil or #tips == 0 then
					terminal.HideTipList()
					return
				end
				tips = terminal.GroupSameWords(tips)

				terminal.BuildTipList(tips)
				terminal.SelectTip("up")
				terminal.UpdateTipListPos()
				terminal.ShowTipList()

				--[[for index = #parsed, #cmd_data.checks.args, 1 do
					cmd_tip.Text = cmd_tip.Text..terminal.GenerateArgTip(cmd_data.checks.args[index]).." "
				end]]--
			end
		else
			cmd_tip.Text = ""
			terminal.HideTipList()
			return
		end

		--[[
		local last_word = string.match(cmd_input.Text, "^%l+$") or string.match(cmd_input.Text, ", ?(%l+)$")
		if last_word == nil then cmd_tip.Text = ""; return end

		for _, cmd_data in ipairs(cmds_mgr.cmds) do
			local start, str_end = nil, nil
			start, str_end = string.find(cmd_data.name, last_word)
			if start ~= 1 then 
				terminal.matched_word = nil
				continue 
			else
				terminal.matched_word = cmd_data.name
			end

			if str_end == string.len(cmd_data.name) then 
				cmd_tip.Text = ""
				local _, match_end = string.find(cmd_input.Text, cmd_data.name)

				local args_count = 0
				local args = string.sub(cmd_input.Text, match_end)
				for _ in string.gmatch(args, " ([%l%d]+)") do
					args_count += 1
				end
				if args_count == 0 then args_count = 1 end

				local part = cmd_data.name
				if args_count < 5 and cmd_data.checks ~= nil then
					if cmd_data.checks[1] ~= nil then
						for index = args_count, 4, 1 do
							local arg_data = cmd_data.checks[index]
							if arg_data == nil then break end
							part = part.." "..arg_data.name..": "..(arg_data.type == "number" and "num" or "text")..(arg_data.required == true and "" or "?")
						end
						
						if table.find({"godmode", "teamkill", "teamheal"}, cmd_data.name) then
							part = part.."+"
						end
					end

					if cmd_data.checks.npcs ~= nil then
						part = part.." npc_group: text+"
					end

					cmd_tip.Text = string.gsub(cmd_input.Text, "%l+$", "")..part
				else
					cmd_tip.Text = ""
					return
				end
			else
				cmd_tip.Text = string.gsub(cmd_input.Text, "%l+$", "")..cmd_data.name
			end
			return
		end

		cmd_tip.Text = ""--]]
	end)
end

terminal.IsInputEndsWithSpace = function()
	return string.match(terminal.last_cmd_input.Text, " $") ~= nil 
end

terminal.ApplyAutocomplete = function()
	local cmd_input = terminal.last_cmd_input
	local last_word = string.match(cmd_input.Text, "^%l+$") or string.match(cmd_input.Text, ", ?(%l+)$")
	if last_word == nil then return end
	cmd_input.Text = string.gsub(cmd_input.Text, "%l+$", "")..terminal.matched_word
	cmd_input.CursorPosition = 10000
end

terminal.ApplySelectedTip = function()
	local selected_tip = terminal.generated_tips[terminal.selected_tip].TextLabel.Text
	selected_tip = string.match(selected_tip, "[%a%-%d_]+")
	terminal.ClearTipList()

	if terminal.IsInputEndsWithSpace() == true then
		terminal.last_cmd_input.Text ..= selected_tip.." "
	else
		terminal.last_cmd_input.Text = string.gsub(terminal.last_cmd_input.Text, "%a+$", selected_tip.." ")
	end

	terminal.last_cmd_input.CursorPosition = 10000
end

terminal.Init = function()
    terminal.Render()

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Semicolon and UserInputService:GetFocusedTextBox() == nil and (terminal.last_cmd_input == nil or terminal.last_cmd_input:IsFocused() == false) then
			terminal.Open()
		--elseif input.KeyCode == Enum.KeyCode.LeftAlt and terminal.last_cmd_input ~= nil and terminal.last_cmd_input:IsFocused() and terminal.matched_word ~= nil then
		--	terminal.ApplyAutocomplete()
		elseif terminal.last_cmd_input ~= nil and terminal.last_cmd_input:IsFocused() and #terminal.generated_tips > 0 then
			if input.KeyCode == Enum.KeyCode.Up then
				while UserInputService:IsKeyDown(Enum.KeyCode.Up) == true do
					terminal.SelectTip("up") 
					task.wait(0.125)
				end
			elseif input.KeyCode == Enum.KeyCode.Down then
				while UserInputService:IsKeyDown(Enum.KeyCode.Down) == true do
					terminal.SelectTip("down") 
					task.wait(0.125)
				end
			elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.LeftAlt then
				terminal.ApplySelectedTip()
			end
		end
	end)

	terminal.ScrollOnContentSizeChange()

	cache.SendResponse = terminal.SendResponse
	cache.ValidateCommand = terminal.ValidateCommand
	cache.commands_holder = terminal.commands_holder

	local welcome_message = nil

	if config.config.first_time == true then
		welcome_message = "<b>INFO</b>: Welcome <i>"..LocalPlayer.Name.."</i> ! Thanks for buying the the key and supporting this script! Type <i>help</i> for a list of commands, <i>keybinds</i> to bind a commands to the keys. If you will have any problems, contact rawparmesan in Discord."
		config.config.first_time = false
		config.Save()
	else
		welcome_message = "<b>INFO</b>: Welcome back, <i>"..LocalPlayer.Name.."</i> ! Type <i>help</i> for a list of commands, <i>keybinds</i> to bind a commands to the keys."
	end

	welcome_message = welcome_message.."<br /><br /><b>SERVER INFO</b>:<br />Server ID: "..game.JobId.."<br />Place ID: "..game.PlaceId.."<br />Place Version: "..game.PlaceVersion.."<br />Place Name: N/A"

	if #config.config.startup_cmds > 0 then
		welcome_message = welcome_message.."<br/><br/>"..os.date("%X").." - startup module sent a request to the core to execute the following command(s): "
		for _, cmd in ipairs(config.config.startup_cmds) do
			welcome_message = welcome_message..cmd..", "
		end
		welcome_message = string.sub(welcome_message, 1, -3)
		welcome_message = welcome_message.."."
	end

	local response_text = terminal.SendResponse({response_text = welcome_message, timestamp = false})
	response_text.Parent.LayoutOrder = -1
	response_text.Name = "welcome_message"

	task.spawn(function()
		response_text.Text = string.gsub(response_text.Text, "N/A", MarketplaceService:GetProductInfo(game.PlaceId).Name)
	end)

	--[[local UITextSizeConstraint = Instance.new("UITextSizeConstraint")
	UITextSizeConstraint.MaxTextSize = 13
	UITextSizeConstraint.Parent = response_text

	local response_holder = response_text.Parent
	response_holder.AutomaticSize = Enum.AutomaticSize.Y
	
	local UISizeConstraint = Instance.new("UISizeConstraint")
	UISizeConstraint.MaxSize = Vector2.new(tonumber("inf"), 240)
	UISizeConstraint.Parent = response_holder]]--
end

return terminal