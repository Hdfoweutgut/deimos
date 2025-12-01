local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")

local cache = require("../modules/cache")
local places = require("../modules/places")
local gui_util = require("../modules/gui_util")

local GameState = nil
local Difficulty = nil

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local tools = {}

tools.emulate_input = {
	StartHold = function(Key)
		VirtualInputManager:SendKeyEvent(true, Key, false, game.Workspace)
	end,
	StopHold = function(Key)
		VirtualInputManager:SendKeyEvent(false, Key, false, game.Workspace)
	end,
	Hold = function(Key, HoldTime)
		VirtualInputManager:SendKeyEvent(true, Key, false, game.Workspace)
		task.wait(HoldTime)
		VirtualInputManager:SendKeyEvent(false, Key, false, game.Workspace)
	end,
	Press = function(Key)
		VirtualInputManager:SendKeyEvent(true, Key, false, game.Workspace)
		task.wait(0.005)
		VirtualInputManager:SendKeyEvent(false, Key, false, game.Workspace)
	end,
}

if places.place_group == "mission" then
	GameState = ReplicatedStorage:WaitForChild("GameState", math.huge)
	Difficulty = GameState:WaitForChild("Difficulty", math.huge).Value
	
	tools.FireBullet = nil

	tools.PlayerHit = nil
	tools.register_hit = nil
	tools.WeaponKey = nil
	tools.FirstTimeNoKey = true
	tools.ClearWeaponKey = nil

	task.spawn(function()
		local Weapons = PlayerGui:WaitForChild("Weapons", math.huge)
		local BulletLocal = getsenv(Weapons:WaitForChild("BulletLocal", math.huge))

		while BulletLocal.l1l == nil do task.wait() end
		tools.register_hit = BulletLocal.l1l

		while BulletLocal.PlayerHitRemote == nil do task.wait() end
		tools.PlayerHit = BulletLocal.PlayerHitRemote

		local WeaponKey = require(Weapons:WaitForChild("WeaponKey", math.huge))
		tools.WeaponKey = WeaponKey
		tools.ClearWeaponKey = WeaponKey.ClearWeaponKey

		local cloned = clonefunction(WeaponKey.ClearWeaponKey)

		WeaponKey.ClearWeaponKey = function()
			if not cache.flags.teamheal and not cache.flags.spkill and (not cache.flags.killaura or (cache.flags.killaura == true and cache.killaura_mode ~= 2)) then
				--
				cloned()
			end
		end

		--hookfunction(WeaponKey.ClearWeaponKey, function() end)

		--[[if not WeaponKey.Key then
			WeaponKey.Key = cache.GetRemote("GenerateWeaponKey"):InvokeServer()
			--WeaponKey.SetWeaponKey(WeaponKey.StartFetch(), 10000)
		end]]--

		task.spawn(function()
			while true and task.wait(0.1) do
				--
				--
				if not cache.weaponkey_cmds.teamheal and not cache.weaponkey_cmds.spkill and (not cache.flags.killaura or (cache.flags.killaura == true and cache.killaura_mode ~= 2)) then
					continue
				end
				if WeaponKey.Key == nil then
					--
					while WeaponKey.Key == nil and task.wait(0.1) do
						WeaponKey.Key = cache.GetRemote("GenerateWeaponKey"):InvokeServer()
					end
				end
			end
		end)
	end)
end

tools.StopTask = function(task_to_cancel)
	if task_to_cancel ~= nil then
		
		local status = coroutine.status(task_to_cancel)
		
		if status == "dead" then return end
		if status ~= "suspended" then
			
			coroutine.yield(task_to_cancel)
			
		end
		
		coroutine.close(task_to_cancel)
		
		task_to_cancel = nil
	end
end

tools.ClearTableTask = function(t, task_name)
	if t[task_name] ~= nil then
		local status = coroutine.status(t[task_name])
		if status == "dead" then return end
		if status ~= "suspended" then
			coroutine.yield(t[task_name])
		end
		coroutine.close(t[task_name])
		t[task_name] = nil
	end
end

tools.ClearTableConn = function(t, conn_name)
	if t[conn_name] ~= nil then
		t[conn_name]:Disconnect()
		t[conn_name] = nil
	end
end

tools.CreatePendingTask = function(func)
	local pending_task = coroutine.create(func)
	coroutine.resume(pending_task)
	return pending_task
end

tools.WaitWithCancel = function(parent, child_name, timeout, current_task)
	local child = parent:WaitForChild(child_name, timeout)

	if child == nil then
		tools.StopTask(current_task)
        return nil
	else
		return child
	end
end

tools.AsyncWait = function(parent, child_name, timeout, func, ...)
    local args = {...}

    if parent:FindFirstChild(child_name) then
        func(unpack(args))
    else
        task.spawn(function()
            local child = parent:WaitForChild(child_name, timeout)
            if child ~= nil then
                func(unpack(args))
            end
        end)
    end
end

tools.ComparePositions = function(pos1, pos2, inaccuracy)
    return
        (pos1.X > pos2.X - inaccuracy and pos1.X < pos2.X + inaccuracy) and
        (pos1.Y > pos2.Y - inaccuracy and pos1.Y < pos2.Y + inaccuracy) and
        (pos1.Z > pos2.Z - inaccuracy and pos1.Z < pos2.Z + inaccuracy)
end

tools.Proxy = function(t, func1, func2)
	local meta = {}
	
	meta.__index = function(_, i)
		if func1 ~= nil then func1(t, i) end
		return t[i]
	end	

	meta.__newindex = function(_, i, v)
		if func2 ~= nil then func2(t, i, v) end
		t[i] = v
	end

	local proxy = setmetatable({}, meta)
	return proxy
end

tools.jsonify = function(t)
    return HttpService:JSONEncode(t)
end

tools.unjsonify = function(json)
    return HttpService:JSONDecode(json)
end

tools.GetDictLen = function(dict)
	local len = 0
	for _, _ in pairs(dict) do
		len += 1
	end
	return len
end

tools.AddAlignP = function(attachment, parent)
	local AlignPosition = Instance.new("AlignPosition")
	AlignPosition.Enabled = false
	AlignPosition.Attachment0 = attachment
	AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	AlignPosition.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	AlignPosition.MaxAxesForce = Vector3.new(2500000, 2500000, 2500000)
	AlignPosition.Responsiveness = 200
	AlignPosition.Parent = parent

	return AlignPosition
end

tools.AddAlignO = function(attachment, parent)
	local AlignOrientation = Instance.new("AlignOrientation")
	AlignOrientation.Enabled = false
	AlignOrientation.Attachment0 = attachment
	AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrientation.MaxTorque = 2500000
	AlignOrientation.Responsiveness = 200
	AlignOrientation.CFrame = CFrame.Angles(0, math.rad(math.random(0, 180)), 0)
	AlignOrientation.Parent = parent

	return AlignOrientation
end

tools.WaitForChildren = function(parent, ...)
	local children = {...}
	local count = #children

	for _, part in ipairs(parent:GetChildren()) do
		local index = table.find(children, part.Name)
		if index == nil then continue end
		children[index] = part
		count -= 1
		if count == 0 then
			return children
		end
	end
	
	if count > 0 then
		local listener; listener = parent.ChildAdded:Connect(function(part)
			local index = table.find(children, part.Name)
			if index == nil then return end
			
			children[index] = part
			count -= 1
			if count == 0 then listener:Disconnect() end
		end)

		while count > 0 do task.wait() end
	end

	return children
end

tools.IncreaseSimulationRadius = function()
	local SimulationRadiusFunc = nil

	if sethiddenproperty ~= nil and gethiddenproperty ~= nil then
		SimulationRadiusFunc = function() 
			repeat 
				task.wait(0.1) 
			until pcall(function() gethiddenproperty(LocalPlayer, "SimulationRadius") end) ~= false 
			sethiddenproperty(LocalPlayer, "SimulationRadius", 2500)
		end
	elseif setsimulationradius ~= nil then
		SimulationRadiusFunc = function() 
			setsimulationradius(2500, 5000) 
		end
	end

	RunService.RenderStepped:Connect(function()
		LocalPlayer.MaximumSimulationRadius = 5000
		SimulationRadiusFunc()
	end)
end

tools.RoundNumber = function(num, decimal_places)
	local integral, fractional = math.modf(num)
	fractional = string.sub(tostring(fractional), 1, 2 + (decimal_places or 2))
	return integral + tonumber(fractional)
end

tools.WaitForChildWithIndex = function(parent, index)
	local children = parent:GetChildren()
	local count = #children
	
	if count >= index then 
		return children[index]
	else
		local listener; listener = parent.ChildAdded:Connect(function(child)
			table.insert(children, child)
			count += 1
		end)

		while count < index do task.wait(0.25) end

		listener:Disconnect()

		return children[index]
	end
end

tools.SimulateShoot = function(Object, Damage)
	if tools.FireBullet == nil then
		if hookmetamethod ~= nil and getsenv ~= nil and checkcaller ~= nil and getnamecallmethod ~= nil then
			tools.FireBullet = cache.GetRemote("FireBullet")
		else
			tools.FireBullet = PlayerGui:WaitForChild("Weapons", math.huge):WaitForChild("BulletLocal", math.huge):WaitForChild("FireBullet", math.huge)
		end
	end

	if typeof(tools.FireBullet) == "Instance" then
		tools.FireBullet:Fire(Object.Position, Object.Position, Vector3.new(0, -0.0000000000001, 0), Damage, 100, 100, 100, 100)
		task.wait(1)
	else
		while tools.WeaponKey.Key == nil do
			task.wait()
		end

		tools.FireBullet:FireServer(Object.Position, Object.Position, Vector3.new(0, -0.0000000000001, 0), Damage, 100, 100, 100, 100)
	end
end

tools.SimulateKnifeHit = function(humanoid, part, damage)
	while tools.register_hit == nil or tools.WeaponKey == nil do task.wait() end
	
	--local key = cache.GetRemote("GenerateWeaponKey"):InvokeServer()
	--



	while tools.WeaponKey.Key == nil do
		task.wait()
	end

	--

	local _, hitreg = tools.register_hit()
	tools.PlayerHit:FireServer(humanoid, damage, 25, part, Vector3.new(0, -3, 0), Vector3.new(), 50, hitreg, tools.WeaponKey.Key)
	task.wait(0.05)
end

tools.AddBeam = function(parent, attachment_0)
	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
	}
	beam.LightEmission = 0
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	beam.ZOffset = 0
	beam.Attachment0 = attachment_0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = 0.005
	beam.Width1 = 0.005
	beam.Enabled = false
	beam.Parent = parent

	return beam
end

tools.TimerInText = function(text_holder, left_side, seconds, right_side)
	for sec = seconds, 0, -1 do
		text_holder.Text = left_side.."0:"..(sec > 9 and tostring(sec) or "0"..tostring(sec))..right_side
		task.wait(1)
	end
end

tools.CalculateDamage = function(data, player, damage)
	damage = damage == nil and data.humanoid.MaxHealth - data.humanoid.Health or damage
	local FriendlyFire = ReplicatedStorage:FindFirstChild("FriendlyFire")
	FriendlyFire = (FriendlyFire == nil or player == LocalPlayer) and 1 or FriendlyFire.Value

	local ABL = data.humanoid:FindFirstChild("ArmorBlockLow")
    if ABL == nil then
        local diff_mul = (1.1385 + (0.1485 * (Difficulty - 1)))
        return damage / diff_mul / FriendlyFire
    else
		local armor_mul = (1 - ABL.Value)
        return damage / armor_mul / FriendlyFire
    end
end

tools.PlayerDataByName = function(player_name)
	player_name = string.lower(player_name)

	for player, data in pairs(cache.players_data) do
		local display_name = string.lower(player.DisplayName)
		if string.match(display_name, "^"..player_name) ~= nil then
			return data
		end
	end

	for player, data in pairs(cache.players_data) do
		local real_name = string.lower(player.Name)
		if string.match(real_name, "^"..player_name) ~= nil then
			return data
		end
	end

	return nil
end

tools.ConvertBool = function(value)
	return value == true and "yes" or "no"
end

tools.ComparePositions = function(pos1, pos2, inaccuracy)
	return (pos1 - pos2).Magnitude <= inaccuracy
end

tools.ExactPosBetweenVectors = function(pos1, pos2, required_magnitude, inaccuracy)
	return math.abs((pos1 - pos2).Magnitude - required_magnitude) <= inaccuracy
end

tools.ChildCounter = function(needed_count, parent, func)
	local count = 0
	local children = {}

	for _, obj in ipairs(parent:GetChildren()) do
		if func(obj) == false then continue end
		table.insert(children, obj)
		count += 1 
		if count == needed_count then break end
	end

	if count < needed_count then
		local listener; listener = parent.ChildAdded:Connect(function(obj)
			if func(obj) == false then return end
			table.insert(children, obj)
			count += 1 
			if count == needed_count then listener:Disconnect() end
		end)
	end

	while count ~= needed_count do task.wait() end

	return children
end

tools.FireTouchTrigger = function(trigger)
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	while trigger.Parent ~= nil and task.wait(0.1) do
		firetouchinterest(hrp, trigger, 0)
		wait(0.05)
		firetouchinterest(hrp, trigger, 1)
	end
end

tools.ClickGuiButton = function(button)
	local properties = {
		Position = nil,
		Size = nil,
		Visible = nil,
		Parent = nil,
		Active = nil
	}

	for property, _ in pairs(properties) do
		properties[property] = button[property]
	end

	local button_copy = button:Clone()
	button_copy.Parent = properties.Parent

	button.Visible = true
	button.Position = UDim2.fromOffset(0, 0)
	button.Size = UDim2.fromScale(0.00001, 0.00001)
	button.Active = true
	button.Parent = gui_util.gui_holder

	while button.GuiState ~= Enum.GuiState.Hover do
		GuiService.SelectedObject = button
		task.wait()
	end

	local pressed = false

	local listener; listener = button:GetPropertyChangedSignal("GuiState"):Connect(function()
		if button.GuiState == Enum.GuiState.Press then
			pressed = true
			listener:Disconnect()
		end
	end)

	while pressed == false and GuiService.SelectedObject == button do
		tools.emulate_input.Press(Enum.KeyCode.Return)
	end

	for property, value in pairs(properties) do
		button[property] = value
	end

	button_copy:Destroy()
end

tools.GetPing = function()
	return Stats.PerformanceStats.Ping:GetValue() / 1000
end

return tools