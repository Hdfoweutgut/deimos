local tools = require("../modules/tools")
local npc_mgr = require("../modules/npc_mgr")
local rmts_mgr = require("../modules/rmts_mgr")
local config = require("../modules/config").config.scr_settings
local cache = require("../modules/cache")

local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local Level = workspace:WaitForChild("Level", math.huge)
local GroundItems = Level:WaitForChild("GroundItems", math.huge)
local GroundBags = Level:WaitForChild("GroundBags", math.huge)
local Geometry = Level:WaitForChild("Geometry", math.huge)
local Glass = Level:WaitForChild("Glass", math.huge)
local Triggers = Level:WaitForChild("Triggers", math.huge)

local EmulateInput; EmulateInput = {
	StartHold = function(Key)
		VirtualInputManager:SendKeyEvent(true, Key, false, game.Workspace)
        EmulateInput.CurrentKeyHolding = Key
	end,
	StopHold = function(Key)
		VirtualInputManager:SendKeyEvent(false, Key, false, game.Workspace)
        EmulateInput.CurrentKeyHolding = nil
	end,
	Hold = function(Key, HoldTime)
        EmulateInput.CurrentKeyHolding = Key
		VirtualInputManager:SendKeyEvent(true, Key, false, game.Workspace)
		task.wait(HoldTime)
		VirtualInputManager:SendKeyEvent(false, Key, false, game.Workspace)
        EmulateInput.CurrentKeyHolding = nil
	end,
	Press = function(Key)
        EmulateInput.CurrentKeyHolding = Key
		VirtualInputManager:SendKeyEvent(true, Key, false, game.Workspace)
		task.wait(0.1)
		VirtualInputManager:SendKeyEvent(false, Key, false, game.Workspace)
        EmulateInput.CurrentKeyHolding = nil
	end,
    Kill = function()
        if EmulateInput.CurrentKeyHolding ~= nil then
            EmulateInput.StopHold(EmulateInput.CurrentKeyHolding)
            EmulateInput.CurrentKeyHolding = nil
        end
    end,
    CurrentKeyHolding = nil
}

local af_util; af_util = {}

af_util.initted = false
af_util.last_interaction_time = 0
af_util.stick_connection = nil
af_util.stick_npc_connection = nil
af_util.textbox_focused = false
af_util.scenario_thread = nil
af_util.interaction_updated = true
af_util.last_interact_state = false
af_util.interacting = false
af_util.action_completed = false
af_util.bound = nil
af_util.current_bound = 1

local Camera = nil
local Interact = nil
local ObjectName = nil
local ObjectTip1 = nil
local ObjectTip2 = nil
local CanMove = nil

af_util.checks = {
    ArmorCheck = function()
        local Armor = af_util.Loadout:WaitForChild(tostring(af_util.Loadout.Value)):WaitForChild("Armor", math.huge)
        while Armor.Value == nil do task.wait() end

        if Armor.Value ~= "" then
            return false, "ConditionError: please remove armor from loadout to autofarm this mission."
        end

        return true, nil
    end,

    ItemCheck = function(...)
        local required_items = {...}
        local items = {}

        local Gear = af_util.Loadout:WaitForChild(tostring(af_util.Loadout.Value)):WaitForChild("Gear", math.huge)
        for _, item in ipairs(Gear:GetChildren()) do
            table.insert(items, item.Name)
        end

        for _, item in ipairs(required_items) do
            if not table.find(items, item) then
                return false, "ConditionError: "..item.." required to autofarm this mission."
            end
        end

        return true, nil
    end,

    WeaponCheck = function()
        local visible_weps = {"480 MCS", "CBR-C", "CH-A", "F57", "MM20", "S97", "Sawblade", "Thumper"}
        local CurrentLoadout = af_util.Loadout:WaitForChild(tostring(af_util.Loadout.Value))
        local found_suppressed = false

        for _, wep_pos in ipairs({"Primary", "Secondary"}) do
            local wep = CurrentLoadout:WaitForChild(wep_pos)
            while wep.Value == nil do task.wait() end
            if wep.Value == 0 then
                continue
            elseif wep.Value == -1 then 
                found_suppressed = true; 
                continue 
            end

            wep = af_util.Armory:WaitForChild("Slot"..tostring(wep.Value))
            if table.find(visible_weps, wep.Value) then
                return false, "ConditionError: only pistols are allowed in autofarm."
            end

            local mods = wep:WaitForChild("Mods", math.huge)
            while mods.Value == nil do task.wait() end
            if string.find(mods.Value, "Barrel_Suppressor") then
                found_suppressed = true
            end
        end

        if found_suppressed == false then
            return false, "ConditionError: please suppress at least one of weapons in your current loadout."
        end

        return true, nil
    end,

    ClassCheck = function(required_classes)
        local character_data = tools.unjsonify(af_util.character.Value)
        local needed_amt = #required_classes

        for _, perk in ipairs(character_data.PRK) do
            if string.find(perk, "Base") then
                for _, class in ipairs(required_classes) do
                    if string.find(perk:lower(), class:lower()) then
                        needed_amt -= 1
                        if needed_amt == 0 then return true, nil end
                        
                        continue
                    end
                end
            end
        end

        local c_error = "ConditionError: "
        if needed_amt > 0 then
            for _, class in ipairs(required_classes) do 
                c_error ..= class..", "
            end
        end
        c_error = string.gsub(c_error, ", $", "").." class(es) required to autofarm this mission."

        return false, c_error
    end
}

af_util.Init = function(cmds, ValidateCommand)
    local PlayerData = LocalPlayer:WaitForChild("PlayerData", math.huge)
    af_util.Loadout = PlayerData:WaitForChild("Loadout", math.huge)
    while af_util.Loadout.Value == nil do task.wait() end

    af_util.Armory = PlayerData:WaitForChild("Armory", math.huge)

    local character = PlayerData:WaitForChild("Character", math.huge)
    while character.Value == nil do task.wait() end
    af_util.character = character:WaitForChild("Char"..tostring(character.Value))
    while af_util.character == nil do task.wait() end

    for check, args in pairs(af_util.conditions[game.PlaceId]) do
        local success, response = check(unpack(args))
        if success == false then return response end
    end

    af_util.PressReadyButton()

    Camera = workspace.CurrentCamera
    Interact = PlayerGui:WaitForChild("Weapons", math.huge):WaitForChild("WeaponGui", math.huge):WaitForChild("Interact", math.huge)
    ObjectName = Interact:WaitForChild("ObjectName", math.huge)
    ObjectTip1 = Interact:WaitForChild("ObjectTip", math.huge)
    ObjectTip2 = Interact:WaitForChild("ObjectTip2", math.huge)
    CanMove = LocalPlayer:WaitForChild("Status", math.huge):WaitForChild("Inputs", math.huge):WaitForChild("CanMove", math.huge)
    af_util.cmds = cmds
    af_util.ValidateCommand = ValidateCommand
    af_util.mouse = LocalPlayer:GetMouse()
    af_util.character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    af_util.hrp = af_util.character:WaitForChild("HumanoidRootPart", math.huge)
    af_util.humanoid = af_util.character:WaitForChild("Humanoid", math.huge)
    af_util.spots = af_util.spots[game.PlaceId]
    af_util.platform = af_util.GetPlatform()
    af_util.interact_ignore_list = {af_util.character, Camera, Triggers:WaitForChild("VisionFiltered", math.huge)}

    local LoudStage = ReplicatedStorage:WaitForChild("GameState", math.huge):WaitForChild("Stage", math.huge)
    af_util.loud_listener = LoudStage:GetPropertyChangedSignal("Value"):Once(function()
        if config.af_loud_behaviour == "reset" then
            af_util.health_listener:Disconnect()
            af_util.humanoid.Health = -1
            af_util.PressReplayButton()
        else
            af_util.ValidateCommand("autofarm", "autofarm")
        end
    end)

    af_util.health_listener = af_util.humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if af_util.humanoid.Health <= 0 then
            if af_util.loud_listener ~= nil and af_util.loud_listener.Connected == true then
                af_util.loud_listener:Disconnect()
            end
            af_util.health_listener:Disconnect()
            af_util.PressReplayButton()
        end
    end)

    af_util.target = PlayerGui:WaitForChild("Weapons", math.huge):WaitForChild("WeaponScript", math.huge):WaitForChild("InteractionTarget", math.huge)

    return nil
end

af_util.StickObjectToCamera = function(object, rotation, custom_x, custom_y, custom_z)
    if rotation == nil then rotation = CFrame.Angles(0, 0, 0) end
    af_util.UnstickObjectFromCamera()

    object.CanCollide = false

    af_util.obj_init_pos = object.CFrame
    af_util.sticked_obj = object

    local test = object.Size.Z / 2
    local offset = CFrame.new(custom_x or 0, object.Size.Y / 2 - 0.1 + (custom_y or 0), custom_z or (-test - 0.5))
    af_util.stick_connection = RunService.PreRender:Connect(function()
        object.CFrame = Camera.CFrame * rotation * offset
    end)
end

af_util.UnstickObjectFromCamera = function()
    if af_util.stick_connection ~= nil and af_util.stick_connection.Connected == true then
        af_util.stick_connection:Disconnect()
    end

    af_util.stick_connection = nil

    if af_util.sticked_obj ~= nil then
        af_util.sticked_obj.CFrame = af_util.obj_init_pos
        af_util.sticked_obj = nil 
        af_util.obj_init_pos = nil
    end
end

af_util.GetInteractableObject = function()
    local HitPart, HitPosition = workspace:FindPartOnRayWithIgnoreList(Ray.new(Camera.CFrame.Position, Camera.CFrame.LookVector * 7.5), af_util.interact_ignore_list)
   
    if HitPart and HitPart.Parent and (HitPosition - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 8 then
        if (HitPart.Parent:FindFirstChild("Interact") and HitPart.Parent.Interact.Value) or HitPart.Parent:FindFirstChild("Data") then
            return HitPart.Parent
        else
            return nil
        end
    end

    return nil
end

af_util.CompareInteractableObjs = function(object)
    local current = af_util.GetInteractableObject()

    if object == nil or current == nil or object:IsDescendantOf(current) == false then 
        return false
    else
        return true
    end
end

af_util.NpcInteract = function(args)
    local object_tip = (args.tip_type == nil or args.tip_type == 1) and ObjectTip1 or ObjectTip2

    
    af_util.StickNpcToCamera(args.npc)

    
    while tick() - af_util.last_interaction_time <= 0.25 do
        task.wait()
    end

    
    while ObjectName.Text ~= args.npc_name do task.wait() end

    local action, key = nil, nil
    while action == nil or key == nil do
        action, key = string.match(object_tip.Text, "^(%a+).*%[(%u)")
        RunService.RenderStepped:Wait()
    end

    
    key = Enum.KeyCode[key]

    
    af_util.WaitForNoFocusedTextboxes()

    if action == "Hit" then
                
        while Interact:FindFirstChild("RingO") == nil do
            EmulateInput.Press(key)
        end
        
        Interact.RingO:Destroy()
        
    elseif action == "Hold" then
        while CanMove.Value == true and not Interact:FindFirstChild("RingO") do
            
            EmulateInput.StartHold(key)
            

            task.wait(0.5)

            if CanMove.Value == false then
                
                break
            else
                
                EmulateInput.StopHold(key)
            end
        end

        
        Interact:WaitForChild("RingO", math.huge):Destroy()
        
        EmulateInput.StopHold(key)
        
    end

    af_util.UnstickNpcFromCamera()
end

af_util.NpcInteractt = function(args)
    local object_tip = (args.tip_type == nil or args.tip_type == 1) and ObjectTip1 or ObjectTip2

    
    af_util.StickNpcToCamera(args.npc)

    
    while tick() - af_util.last_interaction_time <= 0.25 do
        task.wait()
    end

    
    while ObjectName.Text ~= args.npc_name do task.wait() end

    local action, key = nil, nil
    while action == nil or key == nil do
        action, key = string.match(object_tip.Text, "^(%a+).*%[(%u)")
        RunService.RenderStepped:Wait()
    end

    
    key = Enum.KeyCode[key]

    
    af_util.WaitForNoFocusedTextboxes()

    local data = npc_mgr.npcs_data.all.npcs[args.npc]

    local interaction_loop, hooks = nil, nil
    
    local stop_loop = function()
        af_util.UnstickNpcFromCamera()

        for _, hook in ipairs(hooks) do
            if hook.Connected == true then
                hook:Disconnect()
            end
        end
        
        
        local success, response = pcall(function()
            tools.StopTask(interaction_loop)
        end)
        
        

        EmulateInput.Kill()
    end

    hooks = {
        data.interact:GetPropertyChangedSignal("Value"):Connect(function()
            
            if data.interact.Value == false then
                
                stop_loop()
            end
        end)
    }

    

    interaction_loop = tools.CreatePendingTask(function()
        while true do
            if action == "Hit" then
                
                while Interact:FindFirstChild("RingO") == nil do
                    EmulateInput.Press(key)
                end
                
                Interact.RingO:Destroy()
                
            elseif action == "Hold" then
                while CanMove.Value == true and not Interact:FindFirstChild("RingO") do
                    
                    EmulateInput.StartHold(key)
                    

                    task.wait(0.5)

                    if CanMove.Value == false then
                        
                        break
                    else
                        
                        EmulateInput.StopHold(key)
                    end
                end

                
                Interact:WaitForChild("RingO", math.huge):Destroy()
                
                EmulateInput.StopHold(key)
                
            end

            if args.no_interact_validation == true then
                
                stop_loop()
            end
        end
    end)

    
    while coroutine.status(interaction_loop) ~= "dead" do task.wait() end

    
    af_util.UnstickNpcFromCamera()
end

af_util.ObjectInteract = function(args)
    local object_tip = (args.tip_type == nil or args.tip_type == 1) and ObjectTip1 or ObjectTip2

    local initial_trans = args.object.Transparency
    args.object.Transparency = 1
    local parent = args.object.Parent
    local parent_of_parent = parent.Parent

    local interact = parent:WaitForChild("Interact", math.huge)
    local interact2 = parent:FindFirstChild("Interact2")

    while tick() - af_util.last_interaction_time <= 0.25 do
        task.wait()
    end

    local interaction_loop, hooks = nil, nil
    
    local stop_loop = function()
        af_util.UnstickObjectFromCamera()

        for _, hook in ipairs(hooks) do
            if hook.Connected == true then
                hook:Disconnect()
            end
        end

        tools.StopTask(interaction_loop)

        EmulateInput.Kill()
    end

    hooks = {
        interact:GetPropertyChangedSignal("Value"):Connect(function()
            if interact.Value == false then
                stop_loop()
            end
        end),

        (interact2 ~= nil and interact2:GetPropertyChangedSignal("Value"):Connect(function()
            if interact2.Value == false then
                stop_loop()
            end
        end) or nil),

        parent:GetPropertyChangedSignal("Parent"):Connect(function()
            stop_loop()
        end),

        args.object:GetPropertyChangedSignal("Parent"):Connect(function()
            stop_loop()
        end)
    }
    
    interaction_loop = tools.CreatePendingTask(function()
        while true do
            af_util.StickObjectToCamera(args.object, args.object_rotation, args.rot_x, args.rot_y, args.rot_z)

            while ObjectName.Text ~= args.object_name do task.wait() end

            if args.object_tip ~= nil then
                while object_tip.Text ~= args.object_tip do task.wait() end
            end

            local action, key = nil, nil
            while action == nil or key == nil do
                action, key = string.match(object_tip.Text, "^(%a+).*%[(%u)")
                RunService.RenderStepped:Wait()
            end

            key = Enum.KeyCode[key]

            while tick() - af_util.last_interaction_time <= 0.25 do
                task.wait()
            end
            
            af_util.WaitForNoFocusedTextboxes()

            if action == "Hit" then
                while Interact:FindFirstChild("RingO") == nil do
                    EmulateInput.Press(key)
                end
                af_util.UnstickObjectFromCamera()
                
                Interact.RingO:Destroy()
            elseif action == "Hold" then
                while CanMove.Value == true and not Interact:FindFirstChild("RingO") do
                    EmulateInput.StartHold(key)
                    
                    task.wait(0.5)
                    
                    if CanMove.Value == false then
                        break
                    else
                        EmulateInput.StopHold(key)
                    end
                end

                Interact:WaitForChild("RingO", math.huge):Destroy()
                af_util.UnstickObjectFromCamera()
                EmulateInput.StopHold(key)
            end


            if args.no_interact_validation == true then
                stop_loop()
            end
        end
    end)

    while coroutine.status(interaction_loop) ~= "dead" do task.wait() end

    af_util.UnstickObjectFromCamera()

    args.object.Transparency = initial_trans
end

af_util.ObjectasfgInteract = function(args)
    local object_tip = (args.tip_type == nil or args.tip_type == 1) and ObjectTip1 or ObjectTip2
    local interact = args.object.Parent.Interact

    
    while tick() - af_util.last_interaction_time <= 0.25 do
        task.wait()
    end

    
    af_util.StickObjectToCamera(args.object, args.object_rotation, args.rot_x, args.rot_z)

    local completed = false
    while completed == false and args.object ~= nil and interact.Value == true do
        local interact_attempt; interact_attempt = tools.CreatePendingTask(function()
            
            while af_util.CompareInteractableObjs(args.object) == false and args.object ~= nil and interact.Value == true do task.wait() end

            
            local conn; conn = RunService.RenderStepped:Connect(function()
                if af_util.CompareInteractableObjs(args.object) == false then
                    
                    conn:Disconnect()
                    af_util.UnstickObjectFromCamera()
                    EmulateInput.Kill()
                    tools.StopTask(interact_attempt)
                end
            end)
            

            while af_util.target.Value == false do task.wait() end
            while ObjectName.Text ~= args.object_name do task.wait() end

            

            local action, key = nil, nil
            while action == nil or key == nil do
                action, key = string.match(object_tip.Text, "^(%a+).*%[(%u)")
                RunService.RenderStepped:Wait()
            end

            key = Enum.KeyCode[key]

            

            af_util.WaitForNoFocusedTextboxes()

            

            if action == "Hit" then
                
                while Interact:FindFirstChild("RingO") == nil do
                    EmulateInput.Press(key)
                end
                if conn.Connected == true then conn:Disconnect() end
                
                Interact.RingO:Destroy()
                
            elseif action == "Hold" then
                while CanMove.Value == true and not Interact:FindFirstChild("RingO") do
                    
                    EmulateInput.StartHold(key)
                    

                    task.wait(0.5)

                    if CanMove.Value == false then
                        
                        break
                    else
                        
                        EmulateInput.StopHold(key)
                    end
                end

                Interact:WaitForChild("RingO", math.huge):Destroy()
                if conn.Connected == true then conn:Disconnect() end
                EmulateInput.StopHold(key)
                
            end

            af_util.UnstickObjectFromCamera()
            

            
            while af_util.CompareInteractableObjs(args.object) == true do task.wait() end

            
            completed = true
            af_util.last_interaction_time = tick()
        end)

        while coroutine.status(interact_attempt) ~= "dead" and args.object ~= nil and interact.Value == true do task.wait() end
        
        task.wait()
    end
end

af_util.ObjectttInteract = function(args)
    --[[
        ARGS

        tip_type
        object_name
        object
        object_rotation
        rot_x
        rot_z
    ]]

    local object_tip = (args.tip_type == nil or args.tip_type == 1) and ObjectTip1 or ObjectTip2
    
    while tick() - af_util.last_interaction_time <= 0.25 do
        task.wait()
    end
    

    af_util.StickObjectToCamera(args.object, args.object_rotation, args.rot_x, args.rot_z)
    

    local completed = false

    while completed == false do
        local interact_attempt; interact_attempt = tools.CreatePendingTask(function()
            local hooks
            
            local function kill_attempt()
                
            end

            hooks = {
                af_util.target:GetPropertyChangedSignal("Value"):Connect(function()
                    if af_util.target.Value == false then
                        EmulateInput.Kill()
                        
                        for _, hook in ipairs(hooks) do
                            if hook.Connected == true then hook:Disconnect() end
                        end
                        tools.StopTask(interact_attempt)
                    end
                end),

                ObjectName:GetPropertyChangedSignal("Text"):Connect(function()
                    if ObjectName.Text ~= args.object_name then
                        EmulateInput.Kill()
                        
                        for _, hook in ipairs(hooks) do
                            if hook.Connected == true then hook:Disconnect() end
                        end
                        tools.StopTask(interact_attempt)
                    end
                end),

                object_tip:GetPropertyChangedSignal("Text"):Connect(function()
                    local action, key = string.match(object_tip.Text, "^(%a+).*%[(%u)")
                    
                    if (action == nil or key == nil) and not string.find(object_tip.Text, "...") then
                        EmulateInput.Kill()
                        
                        for _, hook in ipairs(hooks) do
                            if hook.Connected == true then hook:Disconnect() end
                        end
                        tools.StopTask(interact_attempt)
                    end
                end),

                UserInputService.TextBoxFocused:Connect(function()
                    EmulateInput.Kill()
                    
                    for _, hook in ipairs(hooks) do
                        if hook.Connected == true then hook:Disconnect() end
                    end
                    tools.StopTask(interact_attempt)
                end)
            }

            

            while af_util.target.Value == false do task.wait() end
            while ObjectName.Text ~= args.object_name do task.wait() end

            

            local action, key = nil, nil
            while action == nil or key == nil do
                action, key = string.match(object_tip.Text, "^(%a+).*%[(%u)")
                RunService.RenderStepped:Wait()
            end

            key = Enum.KeyCode[key]

            

            af_util.WaitForNoFocusedTextboxes()

            

            if action == "Hit" then
                
                while Interact:FindFirstChild("RingO") == nil do
                    EmulateInput.Press(key)
                end
                Interact.RingO:Destroy()
                
            elseif action == "Hold" then
                while CanMove.Value == true and not Interact:FindFirstChild("RingO") do
                    
                    EmulateInput.StartHold(key)
                    

                    task.wait(0.5)

                    if CanMove.Value == false then
                        
                        break
                    else
                        
                        EmulateInput.StopHold(key)
                    end
                end

                Interact:WaitForChild("RingO", math.huge):Destroy()
                EmulateInput.StopHold(key)
                
            end

            for _, hook in ipairs(hooks) do
                if hook.Connected == true then hook:Disconnect() end
            end

            af_util.UnstickObjectFromCamera()

            while af_util.target.Value == true do task.wait() end

            
            completed = true
            af_util.last_interaction_time = tick()
        end)

        while coroutine.status(interact_attempt) ~= "dead" do task.wait() end

        task.wait()
    end
end

af_util.ObjecttInteract = function(name, tip_type, wait_for_hide)
    if tip_type == nil then tip_type = 1 end
    local tip = tip_type == 1 and ObjectTip1 or ObjectTip2

    while tick() - af_util.last_interaction_time <= 0.25 do
        task.wait()
    end

    while af_util.target.Value == false do 
        while ObjectName.Text ~= name or string.find(tip.Text, "%[") == nil do task.wait() end
        task.wait()
    end

    --[[
    
    while tick() - af_util.last_interaction_time <= 0.25 or af_util.target.Value == false do
        task.wait()
    end
    

    
    while ObjectName.Text ~= name do task.wait() end
    
    
    while string.find(tip.Text, "%[") == nil do
        task.wait()
    end]]--

    local action, key = nil, nil

    while action == nil or key == nil do
        action, key = string.match(tip.Text, "^(%a+).*%[(%u)")
        RunService.RenderStepped:Wait()
    end

    key = Enum.KeyCode[key]

    
    af_util.WaitForNoFocusedTextboxes()

    if action == "Hit" then
        
        while Interact:FindFirstChild("RingO") == nil do
            EmulateInput.Press(key)
        end
        
        
        Interact:WaitForChild("RingO", math.huge):Destroy()
        
        RunService.RenderStepped:Wait()
    elseif action == "Hold" then
        while CanMove.Value == true and not Interact:FindFirstChild("RingO") do
            if CanMove.Value == true then
                
                EmulateInput.StartHold(key)
            else
                
            end

            task.wait(0.5)

            if CanMove.Value == false then 
                
            end
                
            
            EmulateInput.StopHold(key)
        end
        
        Interact:WaitForChild("RingO", math.huge):Destroy()
        RunService.RenderStepped:Wait()
        
        EmulateInput.StopHold(key)
        task.wait()
        
    end

    --[[if wait_for_hide == nil or wait_for_hide == true then
        
        while ObjectName.Text == name do task.wait() end
        RunService.RenderStepped:Wait()
        
    end]]--

    if wait_for_hide == nil or wait_for_hide == true then
        while af_util.target.Value == true and ObjectName.Text == name do task.wait() end
    end

    af_util.last_interaction_time = tick()
end

af_util.StickNpcToCamera = function(npc)
    af_util.stick_npc_connection = RunService.RenderStepped:Connect(function()
        npc_mgr.MoveNPC(npc, (af_util.hrp.CFrame * CFrame.new(0, 1, -2)).Position)
    end)
end

af_util.UnstickNpcFromCamera = function()
    af_util.stick_npc_connection:Disconnect()
    RunService.RenderStepped:Wait()
end

af_util.SwitchCameraSubject = function(object, camera_cframe)
    Camera.CameraSubject = object
    Camera.CFrame = camera_cframe
end

af_util.ResetCameraSubject = function()
    Camera.CameraSubject = af_util.humanoid
end

af_util.RotateCamera = function(rotation)
    Camera.CFrame = rotation
end

af_util.WaitForNoFocusedTextboxes = function()
    while UserInputService:GetFocusedTextBox() ~= nil do 
        task.wait()
    end
end

af_util.PressGuiButton = function(button)
    --
    af_util.WaitForNoFocusedTextboxes()

    GuiService.SelectedObject = button
    task.wait(0.25)
    EmulateInput.Press(Enum.KeyCode.Return)
    task.wait(0.25)
    GuiService.SelectedObject = nil
end

af_util.PressReadyButton = function()
    if game.PlaceId == 4768829954 then
        while not PlayerGui:FindFirstChild("ReadyGui") do
            rmts_mgr.GetRemote("MethodVote"):FireServer(1)
            task.wait(1)
        end
    end

    local ReadyGui = PlayerGui:WaitForChild("ReadyGui", math.huge)
    local Loadout = ReadyGui:WaitForChild("Loadout", math.huge)

    while Loadout.Position.Y.Scale < 0.49 do task.wait() end

    local FailureAuthentication = ReadyGui:WaitForChild("FailureAuthentication", math.huge)
    local FA_Ready = FailureAuthentication:WaitForChild("Ready", math.huge)
    local Player1 = Loadout:WaitForChild("Player1", math.huge)
    local ReadyButton = Loadout:WaitForChild("Ready", math.huge)

    while Player1.BackgroundColor3 ~= Color3.new(0, 0.5, 0) do
        af_util.PressGuiButton(ReadyButton)
        task.wait(1)
        if FailureAuthentication.Position.Y.Scale < 1.25 then
            while Player1.BackgroundColor3 ~= Color3.new(0, 0.5, 0) do
                af_util.PressGuiButton(FA_Ready)
            end
        end
    end
end

af_util.PressReplayButton = function()
    local CloseScreen = PlayerGui:WaitForChild("SpectateGui", math.huge):WaitForChild("CloseScreen", math.huge)
    local ReplayButton = CloseScreen:WaitForChild("VoteReplay", math.huge)
    --local VoteCount = CloseScreen:WaitForChild("VoteCount", math.huge)
    while CloseScreen.Position.X.Scale < 0.49 do task.wait() end
    --[[local Votes = game:GetService("ReplicatedStorage"):WaitForChild("GameState", math.huge):WaitForChild("Vote", math.huge):WaitForChild("Votes", math.huge)
    Votes:GetPropertyChangedSignal("Value"):Connect(function()
        if Votes.Value == 0 then
            task.wait(3)
            af_util.PressGuiButton(ReplayButton)
        end
    end)
    af_util.PressGuiButton(ReplayButton)

    local StartTime = tick()
    local VoteCount = PlayerGui:FindFirstChild("VoteCount", true)
    while tonumber(string.sub(VoteCount.Text, 3, 3)) ~= #Players:GetChildren() and tick() - StartTime < 5 do
        task.wait() 
    end
    local CloseScreen = PlayerGui:FindFirstChild("CloseScreen", true)
    local VoteReplayButton = PlayerGui:FindFirstChild("VoteReplay", true)

    while CloseScreen.Position.X.Scale < 0.49 do task.wait() end
    while tonumber(string.sub(VoteCount.Text, 1, 1)) ~= #Players:GetChildren() and task.wait(0.5) do
        AFUtil.PressGuiButton(VoteReplayButton, 1.4, 1.5)
    end

    VoteCount:GetPropertyChangedSignal("Text"):Connect(function()
        while tonumber(string.sub(VoteCount.Text, 1, 1)) ~= #Players:GetChildren() and task.wait(0.5) do
            AFUtil.PressGuiButton(VoteReplayButton, 1.4, 1.5)
        end
    end)]]--

    while ReplayButton.BackgroundColor3 ~= Color3.new(0.5, 0.5, 0.5) do
        af_util.PressGuiButton(ReplayButton)
    end

    ReplayButton:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
        task.wait(1)
        while ReplayButton.BackgroundColor3 ~= Color3.new(0.5, 0.5, 0.5) do
            af_util.PressGuiButton(ReplayButton)
        end
    end)
end

af_util.TweenObject = function(object, pos, required_time)
    local info = TweenInfo.new(required_time, Enum.EasingStyle.Linear)
    local goals = {CFrame = CFrame.new(pos)}
    local tween = TweenService:Create(object, info, goals)
    
    tween:Play()
    tween.Completed:Wait()
end

af_util.GetPlatform = function()
    local platform = workspace:FindFirstChild("Platform")

    if not platform then
        platform = Instance.new("Part")
        platform.Size = Vector3.new(4, 0.5, 4)
        platform.Anchored = true
        platform.Transparency = 1
        platform.Parent = workspace
    end

    return platform
end

af_util.MovePlayerByRoute = function(start, stop)
    local direction = (start - stop) < 0 and "in" or "back"
    local step = direction == "in" and 1 or -1

    --
    while af_util.spots == nil do task.wait() end
    
    for i = start, stop, step do
        if i == stop then break end

        --
        while af_util.spots[i] == nil or af_util.spots[i + step] == nil do task.wait() end

        local current_spot = af_util.spots[i]
        local next_spot = af_util.spots[i + step]

        local ping = tools.GetPing() / 2
        local required_time = (current_spot.pos - next_spot.pos).Magnitude / (35 * (direction == "in" and current_spot.mul or next_spot.mul))

        if ping > required_time then
            required_time = ping
        end
        
        af_util.hrp.Anchored = false
        task.spawn(function()
            af_util.TweenObject(af_util.hrp, next_spot.pos, required_time)
        end)
        af_util.TweenObject(af_util.platform, next_spot.pos - Vector3.new(0, 2.25, 0), required_time)

        --af_util.hrp.Anchored = true
    end
end

af_util.SkipRoutePart = function(from, to, mul)
    from = af_util.spots[from]
    to = af_util.spots[to]

    local ping = tools.GetPing() / 2
    local required_time = (from.pos - to.pos).Magnitude / (35 * mul)  

    if ping > required_time then
        required_time = ping
    end

    task.spawn(function()
        af_util.TweenObject(af_util.hrp, to.pos, required_time)
    end)
    af_util.TweenObject(af_util.platform, to.pos - Vector3.new(0, 2.5, 0), required_time)
end

af_util.ThrowBag = function()
    af_util.WaitForNoFocusedTextboxes()

    local Tools = LocalPlayer:WaitForChild("Status", math.huge):WaitForChild("Tools", math.huge)
    while Tools:FindFirstChild("Bag") do
        EmulateInput.Press(Enum.KeyCode.G)
    end
end

af_util.OpenDoor = function(door)
    --if door:FindFirstChild("OpenDoor") ~= nil then return end

    

    if door:FindFirstChild("OpenDoor") then
        
    end

    while door:FindFirstChild("OpenDoor") == nil do
        
        af_util.ObjectInteract({
            object_name = "Door", 
            object = door.Center,
        })
    end

    --door:WaitForChild("OpenDoor", math.huge)
end

af_util.PullGunOut = function()
    local GunOut = PlayerGui:WaitForChild("Weapons", math.huge):WaitForChild("WeaponScript", math.huge):WaitForChild("GunOut", math.huge)
    while GunOut.Value == false do
        EmulateInput.Press(Enum.KeyCode.One)
        task.wait(1.5)
    end
end

af_util.HideGun = function()
    local GunOut = PlayerGui:WaitForChild("Weapons", math.huge):WaitForChild("WeaponScript", math.huge):WaitForChild("GunOut", math.huge)
    if GunOut.Value == true then
        EmulateInput.Press(Enum.KeyCode.One)
    end
end

af_util.Aim = function()
    rmts_mgr.GetRemote("SetAnim"):Fire("AimPosition", 1, 1, 0)
end

af_util.InterrogateNpc = function(npc)
    af_util.PullGunOut()
    af_util.Aim()

    local data = npc_mgr.npcs_data.all.npcs[npc]

    af_util.StickNpcToCamera(npc)

    af_util.ObjectInteract(data.interact:WaitForChild("ObjectName", math.huge).Value, 2)

    af_util.UnstickNpcFromCamera()

    af_util.HideGun()
end

af_util.TpToEscapeZone = function(escape_zone_pos)
    while true do
        af_util.hrp.CFrame = CFrame.new(escape_zone_pos)
        task.wait(0.05)
        af_util.hrp.Anchored = true
        task.wait(0.05)
        af_util.hrp.Anchored = false
        task.wait(0.05)
    end
end

af_util.FireTrigger = function(trigger)
    local saved_position = trigger.Position

    while trigger.Parent ~= nil do
        trigger.Position = af_util.hrp.Position
        task.wait(0.005)
        trigger.Position = saved_position
        --trigger.CFrame = af_util.hrp.CFrame
    end
end

af_util.HasScenario = function()
    return af_util.scenarios[game.PlaceId] ~= nil
end

af_util.PlayScenario = function()
    af_util.scenario_thread = tools.CreatePendingTask(af_util.scenarios[game.PlaceId])
    return af_util.scenario_thread
end

af_util.StopScenario = function()
    tools.ClearTableConn(af_util, "loud_listener")
    tools.ClearTableConn(af_util, "health_listener")
    tools.ClearTableTask(af_util, "scenario_thread")
end

af_util.scenarios = {
    [3200010305] = function() -- The Blacksite
        af_util.ValidateCommand("void all, opendoors", "autofarm")

        local Doors = Geometry:WaitForChild("Doors", math.huge):GetChildren()
        local AllTriggers = Triggers:GetChildren()

        af_util.MovePlayerByRoute(1, 10)
        af_util.ValidateCommand("void all", "autofarm")

        local scrambler = AllTriggers[40]:WaitForChild("HalfTrigger", math.huge)
        af_util.ObjectInteract({
            object = scrambler,
            object_name = "Door"
        })
        af_util.ValidateCommand("void all", "autofarm")
        af_util.OpenDoor(Doors[1])
        af_util.MovePlayerByRoute(10, 13)
        af_util.OpenDoor(Doors[21])
        af_util.MovePlayerByRoute(13, 26)
        af_util.OpenDoor(Doors[4])
        af_util.MovePlayerByRoute(26, 29)
        af_util.MovePlayerByRoute(29, 32)
        af_util.OpenDoor(Doors[22])

        local killed_guards = false
        rmts_mgr.GetRemote("ClearStage").OnClientEvent:Once(function()
            killed_guards = true
        end)
        af_util.ValidateCommand("void all, getitem drill", "autofarm")
        while killed_guards == false do task.wait() end

        af_util.MovePlayerByRoute(32, 37)

        local cells_data = {
            ["A"] = {
                drill = nil,
                panel = nil,
                triggers_area = Vector3.new(-60.943, 8.716, 67.282),
                checked = false
            },
            ["B"] = {
                drill = nil,
                panel = nil,
                triggers_area = Vector3.new(-35.982, 18.717, 24.057),
                checked = false
            },
            ["C"] = {
                drill = nil,
                panel = nil,
                triggers_area = Vector3.new(14.018, 8.715, 24.056),
                checked = false
            },
            ["D"] = {
                drill = nil,
                panel = nil,
                triggers_area = Vector3.new(28.944, 8.715, 49.017),
                checked = false
            },
        }
        
        tools.ChildCounter(4, Geometry, function(obj)
            if obj.Name ~= "CellScreen" then return false end

            local ObjectName = obj:WaitForChild("Interact", math.huge):WaitForChild("ObjectName", math.huge).Value
            local PanelLetter = string.sub(ObjectName, 6, 6)
            cells_data[PanelLetter].panel = obj.Screen

            return true
        end)

        tools.ChildCounter(4, Triggers, function(trigger)
            if trigger.Name ~= "Drill" then return false end

            local HalfTrigger = trigger:WaitForChild("HalfTrigger", 2)
            if not HalfTrigger then return false end

            for letter, data in pairs(cells_data) do
                if tools.ComparePositions(data.triggers_area, HalfTrigger.Position, 2) == true then
                    data.drill = HalfTrigger
                    return true
                end
            end

            return false
        end)

        local cell_letter = nil
        local windows_left = 4

        local finished = false

        local rose_search, conn = nil, nil 
        
        rose_search = tools.CreatePendingTask(function()
            for letter, data in pairs(cells_data) do
                data.checked = true

                af_util.ObjectInteract({
                    object = data.drill,
                    object_name = "Window"
                })

                windows_left -= 1
                if windows_left == 1 then 
                    finished = true
                    if conn.Connected == true then
                        conn:Disconnect()
                    end
                    break 
                end
            end
        end)

        conn = Geometry.ChildAdded:Connect(function(child)
            if child.Name == "RoseCellModel" then
                tools.StopTask(rose_search)
                EmulateInput.Kill()
                conn:Disconnect()
                finished = true
            end
        end)

        while finished == false do task.wait() end

        local daisy_cell_model = Geometry:FindFirstChild("RoseCellModel")
        local cutscene_trigger = nil
        if daisy_cell_model ~= nil then
            cutscene_trigger = daisy_cell_model:WaitForChild("CutsceneTrigger", math.huge)
            
            for _, obj in ipairs(Geometry:GetChildren()) do
                if obj.Name ~= "Part" or not obj:FindFirstChild("SurfaceGui") or tools.ComparePositions(cutscene_trigger.Position, obj.Position, 5) == false then
                    continue
                end

                cell_letter = obj.SurfaceGui.TextLabel.Text
                break
            end
        else
            for letter, data in pairs(cells_data) do
                if data.checked == true then continue end
                cell_letter = letter
                break
            end
        end

        af_util.ObjectInteract({
            object = cells_data[cell_letter].panel,
            object_name = "Cell "..cell_letter.." Control",
            object_rotation = CFrame.Angles(math.rad(90), 0, math.rad(180)),
            rot_x = 0,
            rot_y = 2,
            rot_z = 0
        })

        af_util.MovePlayerByRoute(37, 34)
        af_util.SkipRoutePart(34, 38, 1)

        local cutscene_trigger = Geometry:WaitForChild("RoseCellModel", math.huge):WaitForChild("CutsceneTrigger", math.huge)
        af_util.FireTrigger(cutscene_trigger)

        while npc_mgr.npcs_data.allies.count < 1 do task.wait() end
        local daisy = npc_mgr.GetNpcsFromTeamByAmt("a", 1)
        npc_mgr.MoveNPC(daisy, Vector3.new(-10.699, 16.325, 56.001))

        for _, obj in ipairs(Geometry:GetChildren()) do
            if obj.Name ~= "ExitDoor" or tools.ComparePositions(obj.Base.Position, Vector3.new(-1.8, 7.503, 29.899), 7) == false then continue end
            while obj.Base.Rotation.Y < -20 do task.wait() end
            break
        end

        af_util.MovePlayerByRoute(38, 41)
        af_util.OpenDoor(Doors[7])
        af_util.MovePlayerByRoute(41, 53)
        af_util.OpenDoor(Doors[8])
        af_util.MovePlayerByRoute(53, 57)

        task.spawn(function()
            local find_trigger = Triggers:WaitForChild("FindTrigger", math.huge)
            af_util.FireTrigger(find_trigger)
        end)

        local panel = Geometry.BlastDoorPanel.Screen
        af_util.ObjectInteract({
            object = panel,
            object_name = "Blast Door",
            object_rotation = CFrame.Angles(math.rad(90), 0, 0),
            rot_x = 0,
            rot_y = -1,
            rot_z = 0
        })

        while npc_mgr.npcs_data.specials.count < 1 do task.wait() end
        local ryan_rossling = npc_mgr.GetNpcsFromTeamByAmt("s", 1)

        af_util.PullGunOut()
        af_util.Aim()

        af_util.NpcInteract({
            npc = ryan_rossling,
            npc_name = "SC Commander",
            tip_type = 2,
            no_interact_validation = true
        })

        af_util.ValidateCommand("kill s, void g", "autofarm")

        for _, obj in ipairs(Geometry:GetChildren()) do
            if obj.ClassName ~= "Model" or not string.find(obj.Name, "Room") or not obj:FindFirstChild("Computer") then
                continue
            end
            
            local computer = obj.Computer.Screen

            for _, door in ipairs(Doors) do
                if not door:FindFirstChild("Center") then continue end

                local distance = (door.Center.Position - computer.Position).Magnitude
                if distance > 23 and distance < 24 then
                    af_util.OpenDoor(door)
                    break
                end
            end

            af_util.ObjectInteract({
                object = computer,
                object_name = "Computer"
            })

            break
        end

        npc_mgr.MoveNPC(daisy, Vector3.new(-111.077, 28.722, -44.797))

        task.spawn(function()
            af_util.TpToEscapeZone(Vector3.new(-93.21, 30.356, -126.656))
        end)

        af_util.PressReplayButton()

        --[[local CutsceneTrigger = Geometry.RoseCellModel:WaitForChild("CutsceneTrigger", math.huge)
        if panel_teleported == false then
            for _, data in pairs(cells_data) do
                if tools.ComparePositions(data.triggers_area, CutsceneTrigger.Position, 5) == true then
                    data.panel.PrimaryPart = data.panel.Screen
                    data.panel:SetPrimaryPartCFrame(CFrame.new(Vector3.new(-9.792, 8.367, 66.436)) * CFrame.Angles(0, 0, math.rad(-90)))
                    break
                end
            end
        end

        local listener; listener = rmts_mgr.GetRemote("ChangeStageTarget").OnClientEvent:Connect(function(_, stage_num, _, _)
            if stage_num ~= 3 then return end
            listener:Disconnect()

            tools.FireTouchTrigger(CutsceneTrigger)
        end)]]--
    end,
    [2625195454] = function() -- The Deposit
        af_util.ValidateCommand("void all", "autofarm")

        local plr_count = #Players:GetPlayers()
        if plr_count > 1 then
            task.spawn(function()
                af_util.MovePlayerByRoute(1, 2)
                af_util.MovePlayerByRoute(2, 1)
            end)
        end

        local manager_pc = Geometry:WaitForChild("ManagerComputer", math.huge):WaitForChild("Screen", math.huge)
        manager_pc.Parent:WaitForChild("Interact", math.huge):WaitForChild("Time", math.huge).Value = 2.5

        local acc_pc = nil
        
        af_util.ObjectInteract({
            object = manager_pc,
            object_name = "Computer"
        })

        for _, computer in ipairs(Geometry:WaitForChild("AccComputers", math.huge):GetChildren()) do
            if computer:FindFirstChild("Interact") == nil then continue end

            acc_pc = computer.Screen

            af_util.ObjectInteract({
                object = acc_pc,
                object_name = "Computer"
            })
        end

        local safe_door = Geometry:WaitForChild("Safe", math.huge):WaitForChild("SafeDoor", math.huge):WaitForChild("Base", math.huge)
        for _, trigger in ipairs(Triggers:GetChildren()) do
            if trigger.Name == "Safecrack" and trigger:FindFirstChild("HalfTrigger") and tools.ComparePositions(safe_door.Position, trigger.HalfTrigger.Position, 3) == true then
                af_util.ObjectInteract({
                    object = trigger.HalfTrigger,
                    object_name = "Safe"
                })

                break
            end
        end

        GroundItems:WaitForChild("KeycardRed", math.huge):WaitForChild("Data", math.huge)
        while GroundItems:FindFirstChild("KeycardRed") and task.wait(0.1) do
            af_util.ValidateCommand("getitem keycardred", "autofarm")
        end

        af_util.ObjectInteract({
            object = manager_pc,
            object_name = "Computer"
        })
        
        local vault_keypad = Geometry:WaitForChild("VaultKeypad", math.huge):WaitForChild("Union", math.huge)
        vault_keypad.Parent:WaitForChild("Interact", math.huge):WaitForChild("Time", math.huge).Value = 2

        af_util.ObjectInteract({
            object = vault_keypad,
            object_name = "Keypad"
        })

        local BoxLoc = nil

        local listener = rmts_mgr.GetRemote("ChangeStageTarget").OnClientEvent:Connect(function(_, stage_num, _, obj)
            if stage_num ~= 4 then return end
            BoxLoc = obj
        end)

        local listener2 = rmts_mgr.GetRemote("AddStage").OnClientEvent:Connect(function(_, stage_num, _, obj)
            if stage_num ~= 4 then return end
            BoxLoc = obj
        end)

        af_util.ObjectInteract({
            object = acc_pc,
            object_name = "Computer"
        })

        while BoxLoc == nil do task.wait() end

        listener:Disconnect()
        listener2:Disconnect()

        local drill = tools.ChildCounter(1, Level.Triggers, function(trigger)
            if trigger.Name ~= "Drill" then return false end
            local HalfTrigger = trigger:FindFirstChild("HalfTrigger")
            if not HalfTrigger then return false end

            if tools.ComparePositions(BoxLoc.Position, HalfTrigger.Position, 50) == true then
                return true
            end

            return false
        end)[1].HalfTrigger

        task.spawn(function()
            af_util.ObjectInteract({
                object = drill,
                object_name = "Deposit Box"
            })
        end)

        af_util.MovePlayerByRoute(1, 2)

        GroundItems:WaitForChild("PhoenixStash", math.huge):WaitForChild("Data", math.huge)
        while GroundItems:FindFirstChild("PhoenixStash") and task.wait(0.1) do
            af_util.ValidateCommand("getitem phoenixstash", "autofarm")
        end

        af_util.PressReplayButton()
    end,
    [2797881676] = function() -- The Financier
        af_util.ValidateCommand("hide g", "autofarm")
        local ryan_rossling = npc_mgr.GetNpcsFromTeamByAmt("s", 1)
        npc_mgr.MoveNPC(ryan_rossling, Vector3.new(-39.9, 6, 39.2))

        task.spawn(function()
            af_util.MovePlayerByRoute(1, 7)
        end)

        --[[local power_boxes = {}

        for _, obj in ipairs(Geometry:GetChildren()) do
            if obj.Name ~= "PowerBox" then continue end

            table.insert(power_boxes, obj)

            af_util.StickObjectToCamera(obj:WaitForChild("PowerDoor", math.huge):WaitForChild("Union", math.huge), CFrame.Angles(0, 0, 0))
            af_util.ObjectInteract("Power Box")
            af_util.UnstickObjectFromCamera()
        end

        for _, power_box in ipairs(power_boxes) do
            local case = power_box:WaitForChild("Case", math.huge)
            case:WaitForChild("Interact", math.huge):WaitForChild("Time", math.huge).Value = 5
            
            af_util.StickObjectToCamera(case:WaitForChild("BasePart", math.huge), CFrame.Angles(0, 0, 0))
            af_util.ObjectInteract("Power Box")
            af_util.UnstickObjectFromCamera()
        end]]--

        local cases = {
            [1] = {
                pos = Vector3.new(-39.9, 6, 39.2),
                func_in = function()
                    af_util.SkipRoutePart(6, 10, 1)
                end,
                func_out = function()
                    af_util.SkipRoutePart(10, 6, 1)
                    af_util.MovePlayerByRoute(6, 1)
                end
            },
            [2] = {
                pos = Vector3.new(-41.6, 5.8, -9.5),
                func_in = function()
                    af_util.SkipRoutePart(6, 11, 1)
                    af_util.MovePlayerByRoute(11, 12)
                    af_util.SkipRoutePart(12, 15, 1)
                    af_util.MovePlayerByRoute(15, 17)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(17, 15)
                    af_util.SkipRoutePart(15, 12, 1)
                    af_util.MovePlayerByRoute(12, 11, 1)
                    af_util.SkipRoutePart(11, 6, 1)
                    af_util.MovePlayerByRoute(6, 1)
                end
            },
            [3] = {
                pos = Vector3.new(-73.1, 6, 39.8),
                func_in = function()
                    af_util.SkipRoutePart(6, 11, 1)
                    af_util.MovePlayerByRoute(11, 14)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(14, 11)
                    af_util.SkipRoutePart(11, 6, 1)
                    af_util.MovePlayerByRoute(6, 1)
                end
            },
            [4] = {
                pos = Vector3.new(-76.4, 6, 9.5),
                func_in = function()
                    af_util.SkipRoutePart(6, 11, 1)
                    af_util.MovePlayerByRoute(11, 13)
                    af_util.SkipRoutePart(13, 18, 1)
                    af_util.MovePlayerByRoute(18, 19)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(19, 18)
                    af_util.SkipRoutePart(18, 13, 1)
                    af_util.MovePlayerByRoute(13, 11)
                    af_util.SkipRoutePart(11, 6, 1)
                    af_util.MovePlayerByRoute(6, 1)
                end
            },
            [5] = {
                pos = Vector3.new(-22.6, 6, 20.5),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 5)
                    af_util.SkipRoutePart(5, 8, 1)
                    af_util.MovePlayerByRoute(8, 9)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(9, 8)
                    af_util.SkipRoutePart(8, 5, 1)
                    af_util.MovePlayerByRoute(5, 1)
                end
            },
            [6] = {
                pos = Vector3.new(-38.7, 6, -21.2),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 3)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(3, 1)
                end
            },
            [7] = {
                pos = Vector3.new(-40.5, 5.6, -40.2),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 2)
                    af_util.SkipRoutePart(2, 20, 1)
                    af_util.MovePlayerByRoute(20, 21)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(21, 20)
                    af_util.SkipRoutePart(20, 2, 1)
                    af_util.MovePlayerByRoute(2, 1)
                end
            },
            [8] = {
                pos = Vector3.new(-43.3, 6, -21.8),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 2)
                    af_util.SkipRoutePart(2, 22, 1)
                    af_util.MovePlayerByRoute(22, 23)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(23, 22)
                    af_util.SkipRoutePart(22, 2, 1)
                    af_util.MovePlayerByRoute(2, 1)
                end
            },
            [9] = {
                pos = Vector3.new(-22.9, 16, -39.4),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 4)
                    af_util.SkipRoutePart(4, 25, 1)
                    af_util.MovePlayerByRoute(25, 29)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(29, 25)
                    af_util.SkipRoutePart(25, 4, 1)
                    af_util.MovePlayerByRoute(4, 1)
                end
            },
            [10] = {
                pos = Vector3.new(-42.7, 16, -40.4),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 4)
                    af_util.SkipRoutePart(4, 25, 1)
                    af_util.MovePlayerByRoute(25, 27)
                    af_util.SkipRoutePart(27, 30, 1)
                    af_util.MovePlayerByRoute(30, 32)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(32, 30)
                    af_util.SkipRoutePart(30, 27, 1)
                    af_util.MovePlayerByRoute(27, 25)
                    af_util.SkipRoutePart(25, 4, 1)
                    af_util.MovePlayerByRoute(4, 1)
                end
            },
            [11] = {
                pos = Vector3.new(-23.7, 16, -47.2),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 4)
                    af_util.SkipRoutePart(4, 25, 1)
                    af_util.MovePlayerByRoute(25, 27)
                    af_util.SkipRoutePart(27, 30, 1)
                    af_util.MovePlayerByRoute(30, 31)
                    af_util.SkipRoutePart(31, 33, 1)
                    af_util.MovePlayerByRoute(33, 35)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(35, 33)
                    af_util.SkipRoutePart(33, 31, 1)
                    af_util.MovePlayerByRoute(31, 30)
                    af_util.SkipRoutePart(30, 27, 1)
                    af_util.MovePlayerByRoute(27, 25)
                    af_util.SkipRoutePart(25, 4, 1)
                    af_util.MovePlayerByRoute(4, 1)
                end
            },
            [12] = {
                pos = Vector3.new(-60.3, 16.4, 1.2),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 4)
                    af_util.SkipRoutePart(4, 25, 1)
                    af_util.MovePlayerByRoute(25, 27)
                    af_util.SkipRoutePart(27, 36, 1)
                    af_util.MovePlayerByRoute(36, 39)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(39, 36)
                    af_util.SkipRoutePart(36, 27, 1)
                    af_util.MovePlayerByRoute(27, 25)
                    af_util.SkipRoutePart(25, 4, 1)
                    af_util.MovePlayerByRoute(4, 1)
                end
            },
            [13] = {
                pos = Vector3.new(-55.5, 18.755, 24.2),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 4)
                    af_util.SkipRoutePart(4, 25, 1)
                    af_util.MovePlayerByRoute(25, 27)
                    af_util.SkipRoutePart(27, 36, 1)
                    af_util.MovePlayerByRoute(36, 37)
                    af_util.SkipRoutePart(37, 40, 1.5)
                    af_util.MovePlayerByRoute(40, 44)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(44, 40)
                    af_util.SkipRoutePart(40, 37, 1.5)
                    af_util.MovePlayerByRoute(37, 36)
                    af_util.SkipRoutePart(36, 27, 1)
                    af_util.MovePlayerByRoute(27, 25)
                    af_util.SkipRoutePart(25, 4, 1)
                    af_util.MovePlayerByRoute(4, 1)
                end
            },
            [14] = {
                pos = Vector3.new(-55.5, 18.755, 35.8),
                func_in = function()
                    af_util.MovePlayerByRoute(6, 4)
                    af_util.SkipRoutePart(4, 25, 1)
                    af_util.MovePlayerByRoute(25, 27)
                    af_util.SkipRoutePart(27, 36, 1)
                    af_util.MovePlayerByRoute(36, 37)
                    af_util.SkipRoutePart(37, 40, 1.5)
                    af_util.MovePlayerByRoute(40, 45)
                end,
                func_out = function()
                    af_util.MovePlayerByRoute(45, 40)
                    af_util.SkipRoutePart(40, 37, 1.5)
                    af_util.MovePlayerByRoute(37, 36)
                    af_util.SkipRoutePart(36, 27, 1)
                    af_util.MovePlayerByRoute(27, 25)
                    af_util.SkipRoutePart(25, 4, 1)
                    af_util.MovePlayerByRoute(4, 1)
                end
            }
        }

        rmts_mgr.GetRemote("ChangeStageTarget").OnClientEvent:Connect(function(...)
            local args = {...}

            if not args[4] or args[4].Name ~= "Part" then return end
            
            local safe_pos = args[4].Position

            for _, case in ipairs(cases) do
                if tools.ComparePositions(case.pos, safe_pos, 3) == true then
                    
                    EmulateInput.Press(Enum.KeyCode.LeftControl)

                    
                    case.func_in()
                    

                    for _, trigger in ipairs(Triggers:GetChildren()) do
                        if trigger.Name ~= "Photo" or tools.ComparePositions(trigger.Base.Position, safe_pos, 1) == false then
                            continue 
                        end

                        af_util.ObjectInteract({
                            object = trigger.Base,
                            object_name = "Photograph",
                            object_rotation = CFrame.Angles(math.rad(180), 0, 0),
                            rot_x = 0,
                            rot_z = 2
                        })

                        break
                    end

                    local safecrack = Triggers:WaitForChild("Safecrack", math.huge)
                    task.spawn(function()
                        af_util.ObjectInteract({
                            object = safecrack.HalfTrigger,
                            object_name = "Safe"
                        })

                        GroundItems:WaitForChild("HardDrive", math.huge):WaitForChild("Data", math.huge)
                        while GroundItems:FindFirstChild("HardDrive") and task.wait(0.1) do
                            af_util.ValidateCommand("getitem harddrive", "autofarm")
                        end
                    end)

                    case.func_out()

                    af_util.hrp.Anchored = false

                    af_util.PressReplayButton()
                    
                    break
                end
            end
        end)

        af_util.PullGunOut()
        
        for _, obj in ipairs(Level.Actors.ESP.cams:GetChildren()) do
            if obj.Name ~= "ExteriorCam" or tools.ComparePositions(obj.Body.Position, Vector3.new(-33.102, 21.76, 15.603), 10) == false then 
                continue 
            end

            

            tools.SimulateShoot(obj.Body, 100)
        end

        af_util.Aim()

        
        af_util.NpcInteract({
            npc = ryan_rossling,
            npc_name = "Ryan",
            tip_type = 2,
            no_interact_validation = true
        })
        

        
        af_util.ValidateCommand("kill s", "autofarm")

        
        af_util.MovePlayerByRoute(7, 6)
    end,
    [3590667014] = function() -- lakehouse
        local part = Instance.new("Part")
        part.Anchored = true
        part.Size = Vector3.new(8, 20, 8)
        part.Transparency = 1
        part.Position = Vector3.new(51.06, -40.5, -212.99)
        part.Parent = workspace

        af_util.ValidateCommand("void w, hide g s, opendoors", "autofarm")
        af_util.ValidateCommand("instagrab", "autofarm")
        local Doors = Geometry.Doors:GetChildren()
        local Objects = Geometry:GetChildren()

        local pc = nil
        local server = nil

        rmts_mgr.GetRemote("AddStage").OnClientEvent:Connect(function(...)
            local args = {...}

            if args[3] == "Access the computer" then
                pc = args[4]
            elseif args[3] == "Take the server and evac" then
                server = args[4]
            end
        end)

        af_util.MovePlayerByRoute(1, 2)
        af_util.OpenDoor(Doors[17])
        af_util.MovePlayerByRoute(2, 5)
        af_util.OpenDoor(Doors[10])
        af_util.MovePlayerByRoute(5, 7)

        af_util.RotateCamera(CFrame.Angles(0, 0, 0))

        local door_cases = {
            {
                pos = Vector3.new(13.610014915466309, 20.100048065185547, -60.53999710083008),
                func_in = function(door_interact)
                    
                    af_util.SkipRoutePart(7, 9, 1)
                    af_util.MovePlayerByRoute(9, 11)
                    af_util.ObjectInteract({
                        object = door_interact,
                        object_name = "Heavy Security Door",
                        object_rotation = CFrame.Angles(0, math.rad(90), 0),
                        rot_x = 2,
                        rot_z = 0
                    })
                    af_util.MovePlayerByRoute(11, 16)
                    af_util.SkipRoutePart(16, 26, 1)
                end
            },
            {
                pos = Vector3.new(60.5100212097168, 20.500080108642578, -36.640071868896484),
                func_in = function(door_interact)
                    af_util.MovePlayerByRoute(7, 8)
                    af_util.ObjectInteract({
                        object = door_interact,
                        object_name = "Heavy Security Door",
                        object_rotation = CFrame.Angles(0, math.rad(90), 0),
                        rot_x = 2,
                        rot_z = 0
                    })
                    af_util.SkipRoutePart(8, 17, 0.5)
                    af_util.MovePlayerByRoute(17, 26, 1)
                end
            }
        }

        for _, obj in ipairs(Objects) do
            if not obj:FindFirstChild("Escape") then continue end

            for _, case in ipairs(door_cases) do
                if tools.ComparePositions(case.pos, obj.C4Dmg.Position, 3) == true then
                    case.func_in(obj.Escape.Base)
                end
            end
        end

        local pc_cases = {
            {
                pos = Vector3.new(68.694, 6.105, -20.432),
                pc_spot = 30,
                room_center_spot = 29,
                func_in = function()
                    af_util.MovePlayerByRoute(26, 30)
                end
            },
            {
                pos = Vector3.new(11.968, 6.105, -81.274),
                pc_spot = 33,
                room_center_spot = 32,
                func_in = function()
                    af_util.SkipRoutePart(26, 31, 1)
                    af_util.MovePlayerByRoute(31, 33)
                end
            },
            {
                pos = Vector3.new(3.026, 4.105, 14.552),
                pc_spot = 37,
                room_center_spot = 36,
                func_in = function()
                    af_util.SkipRoutePart(26, 34, 1)
                    af_util.MovePlayerByRoute(34, 37)
                end
            }
        }

        while pc == nil do task.wait() end

        for _, case in ipairs(pc_cases) do
            if tools.ComparePositions(case.pos, pc.Position, 3) == true then
                task.spawn(case.func_in)

                af_util.ObjectInteract({
                    object = pc,
                    object_name = "Computer",
                    object_rotation = CFrame.Angles(0, math.rad(90), 0),
                    rot_x = 1,
                    rot_z = 0
                })

                af_util.MovePlayerByRoute(case.pc_spot, case.room_center_spot)

                af_util.ThrowBag()

                while server == nil do task.wait() end

                server = server.Parent.Parent
                local server_base = server.Base
                local server_pickup = server.ServerPickup.Base
                local pos = server_base.Position + (server_base.CFrame.LookVector * Vector3.new(0,0,4)) + Vector3.new(0,3,0)
                af_util.TweenObject(af_util.hrp, pos, 0.25)

                af_util.ObjectInteract({
                    object = server_pickup,
                    object_name = "Server"
                })
            end
        end

        task.spawn(function()
            af_util.TpToEscapeZone(Vector3.new(51.06, -5.3, -212.99))
        end)
        af_util.PressReplayButton()
    end,
    [2951213182] = function() -- withdrawal
        af_util.ValidateCommand("void g w c, hide s, metdetect", "autofarm")
        af_util.ValidateCommand("opendoors", "autofarm")
        af_util.ValidateCommand("instagrab", "autofarm")
        --[[
        workspace.Level.Geometry.OpenableWindow.Trig.Trig
        workspace.Level.Geometry.Doors:GetChildren()[13]
        workspace.Level.Geometry.Doors:GetChildren()[10]
        workspace.Level.Geometry.Doors:GetChildren()[9]
        workspace.Level.Geometry.ServerRoom.FindTrigger
        workspace.Level.Geometry.ServerRoom.Computer.Center
        local cen = workspace.Level.Geometry.ServerRoom.Computer.Center
        local cen2 = workspace.Level.Geometry.Doors:GetChildren()[18].Center
        
        workspace.Level.Geometry.Doors:GetChildren()[21]
        workspace.Level.Geometry.Doors:GetChildren()[15]
        workspace.Level.Geometry.Doors:GetChildren()[16]
        --]]
        local Window = Geometry:WaitForChild("OpenableWindow", math.huge):WaitForChild("Trig", math.huge):WaitForChild("Trig", math.huge)
        --[[af_util.StickObjectToCamera(Window, CFrame.Angles(0, 0, 0))
        af_util.ObjectInteract("Window")
        af_util.UnstickObjectFromCamera()]]--
        af_util.ObjectInteract({
            object = Window,
            object_name = "Window"
        })

        local Doors = Geometry.Doors:GetChildren()

        local ServerRoom = Geometry:WaitForChild("ServerRoom", math.huge)

        local Computer = ServerRoom:WaitForChild("Computer", math.huge)
        Computer:WaitForChild("Interact", math.huge):WaitForChild("Time", math.huge).Value = 9
        Computer = Computer:WaitForChild("Center", math.huge)

        local ServerRoomDoor = nil
        for _, door in ipairs(Doors) do
            local distance = (door.Center.Position - Computer.Position).Magnitude
            if distance > 20 and distance < 21 then
                ServerRoomDoor = door
                break
            end
        end

        local FindTrigger = ServerRoom:WaitForChild("FindTrigger", math.huge)
        af_util.FireTrigger(FindTrigger)
        af_util.OpenDoor(ServerRoomDoor)

        
        af_util.OpenDoor(Doors[21])

        af_util.MovePlayerByRoute(1, 5)

        
        af_util.OpenDoor(Doors[13])

        af_util.MovePlayerByRoute(5, 9)

        --[[for _, index in ipairs({9, 10, 15, 16, 21}) do
            
            af_util.OpenDoor(Doors[index])
            task.wait()
        end]]--

        af_util.PullGunOut()
        af_util.Aim()

        local manager = npc_mgr.GetNpcsFromTeamByAmt("s", 1)
        af_util.StickNpcToCamera(manager)

        task.spawn(function()
            af_util.ObjectInteract({
                object = Computer,
                object_name = "Computer"
            })
            --[[af_util.StickObjectToCamera(Computer, CFrame.Angles(0, 0, 0))
            af_util.ObjectInteract("Computer")
            af_util.UnstickObjectFromCamera()]]--
        end)

        af_util.MovePlayerByRoute(9, 17)
        
        af_util.UnstickNpcFromCamera()

        local seats_pos = {
            Vector3.new(-30.024, 14.501, 101.836),
            Vector3.new(-43.197, 14.501, 100.975),
            Vector3.new(-5.364, 2.501, 109.087),
            Vector3.new(-21.604, 2.501, 122.407),
            Vector3.new(-30.696, 2.501, 115.854),
            Vector3.new(-33.267, 2.501, 123.188),
            Vector3.new(-43.233, 2.501, 116.711),
            Vector3.new(-16.386, 2.501, 102.584),
            Vector3.new(-32.326, 2.501, 102.674)
        }

        task.spawn(function()
            local workers = npc_mgr.GetNpcsFromTeamByAmt("w", 9)
            for _, worker in ipairs(workers) do
                local data = npc_mgr.npcs_data.all.npcs[worker]
                for _, pos in ipairs(seats_pos) do
                    if data and data.hrp and tools.ComparePositions(data.hrp.Position, pos, 3) == true then
                        npc_mgr.MoveNPC(manager, pos)
                        while data.humanoid and data.humanoid.Health > 0 do task.wait() end
                        break
                    end
                end
            end

            npc_mgr.MoveNPC(manager, Vector3.new(12.31, 3.224, 89.559))
        end)

        
        af_util.MovePlayerByRoute(17, 20)
        
        rmts_mgr.GetRemote("ClearStage").OnClientEvent:Wait()
        while af_util.stick_connection ~= nil do task.wait() end
        
        af_util.OpenDoor(Doors[10])
        af_util.MovePlayerByRoute(20, 23)
        af_util.OpenDoor(Doors[9])
        af_util.MovePlayerByRoute(23, 25)
        af_util.SkipRoutePart(25, 41, 1)

        while af_util.stick_connection ~= nil do task.wait() end

        local power_box = tools.WaitForChildWithIndex(Geometry, 1229)

        local door = power_box:WaitForChild("PowerDoor", math.huge):WaitForChild("Union", math.huge)
        af_util.ObjectInteract({
            object = door,
            object_name = "Power Box"
        })
        --[[af_util.StickObjectToCamera(door, CFrame.Angles(0, 0, 0))
        af_util.ObjectInteract("Power Box")
        af_util.UnstickObjectFromCamera()]]--

        local interact_area = power_box:WaitForChild("InteractArea", math.huge):WaitForChild("Part", math.huge)
        interact_area.Name = "InteractArea "
        interact_area.Parent:WaitForChild("Interact", math.huge):WaitForChild("Time", math.huge).Value = 4
        af_util.ObjectInteract({
            object = interact_area,
            object_name = "Power Box"
        })
        --[[af_util.StickObjectToCamera(interact_area, CFrame.Angles(0, 0, 0))
        af_util.ObjectInteract("Power Box")
        af_util.UnstickObjectFromCamera()]]--

        task.spawn(function()
            af_util.SkipRoutePart(41, 25, 1)
            af_util.MovePlayerByRoute(25, 28)
        end)

        interact_area = power_box:WaitForChild("InteractArea", math.huge):WaitForChild("Part", math.huge)
        interact_area.Parent:WaitForChild("Interact", math.huge):WaitForChild("Time", math.huge).Value = 8
        af_util.ObjectInteract({
            object = interact_area,
            object_name = "Power Box"
        })
        --[[af_util.StickObjectToCamera(interact_area, CFrame.Angles(0, 0, 0))
        af_util.ObjectInteract("Power Box")
        af_util.UnstickObjectFromCamera()]]--

        --npc_mgr.MoveNPC(manager, Vector3.new(47.21, 3.224, 52.059))
        --npc_mgr.WaitForExactNpcPos(manager, Vector3.new(47.21, 3.224, 52.059), 0.005)

        af_util.NpcInteractt({
            npc = manager,
            npc_name = "Manager"
        })

        af_util.ThrowBag()

        af_util.MovePlayerByRoute(28, 29)

        --npc_mgr.MoveNPC(manager, Vector3.new(40.41, 3.224, 41.859))

        local vault_door = Geometry.VaultDoor2:GetChildren()[11]
        while vault_door.Rotation.Y < -50 do task.wait() end

        af_util.MovePlayerByRoute(29, 31)
        af_util.OpenDoor(Doors[15])
        af_util.MovePlayerByRoute(31, 32)

        --workspace.Level.Geometry.VaultDoor2:GetChildren()[11]
        --0, 24.590999603271484, 0
        --0, -90, 0

        af_util.ValidateCommand("kill s", "autofarm")

        local Tools = LocalPlayer:WaitForChild("Status", math.huge):WaitForChild("Tools", math.huge)

        for i = 1, 2, 1 do
            if i == 2 then
                af_util.SkipRoutePart(32, 33, 1)
                af_util.OpenDoor(Doors[16])
                af_util.MovePlayerByRoute(33, 34, 1)
            end

            for _, bag in ipairs(GroundBags:GetChildren()) do
                if bag.Name ~= "Cash" or tools.ComparePositions(bag.Base.Position, af_util.hrp.Position, 10) == false then continue end

                af_util.RotateCamera(CFrame.Angles(0, math.rad(-90), 0))

                while true do
                    
                    af_util.ObjectInteract({
                        object = bag.Base,
                        object_name = "Cash"
                    })
                    

                    if Tools:WaitForChild("Bag", 3) ~= nil then break end
                    
                end

                af_util.RotateCamera(CFrame.Angles(0, math.rad(90), 0))

                af_util.ThrowBag()

                --task.wait(0.25)
            end
        end

        af_util.ValidateCommand("loopbag", "autofarm")

        af_util.MovePlayerByRoute(34, 33)
        af_util.SkipRoutePart(33, 30, 1)
        af_util.MovePlayerByRoute(30, 29)
        af_util.SkipRoutePart(29, 27, 1)
        af_util.SkipRoutePart(27, 35, 1)
        af_util.MovePlayerByRoute(35, 36)

        for _, obj in ipairs(Geometry:GetChildren()) do
            if obj.Name ~= "FireDoor" or not obj:FindFirstChild("AccessDoorScript") then continue end

            af_util.ObjectInteract({
                object = obj.OpenTrig.Part,
                object_name = "Access Door"
            })

            break 
        end

        af_util.MovePlayerByRoute(36, 38)

        af_util.RotateCamera(CFrame.Angles(0, 0, 0))

        af_util.ValidateCommand("loopbag", "autofarm")
        Camera.CFrame = CFrame.Angles(math.rad(-30), 0, 0)

        for _, bag in ipairs(GroundBags:GetChildren()) do
            if bag.Name ~= "Bag" or not bag:FindFirstChild("SealedBag") then continue end

            af_util.ObjectInteract({
                object = bag.Base,
                object_name = "Cash"
            })

            af_util.ThrowBag()
        end

        af_util.MovePlayerByRoute(38, 40)

        af_util.PressReplayButton()
    end,
    [4518266946] = function() -- scientist
        local Doors = workspace.Level.Geometry.Doors:GetChildren()

        task.spawn(function()
            while npc_mgr.GetNpcsFromTeamByAmt("w", 1) == nil do task.wait() end
            local keycard_holder = npc_mgr.GetNpcsFromTeamByAmt("w", 1)
            npc_mgr.MoveNPC(keycard_holder, Vector3.new(-30.687, -6.576, 4.363))
            npc_mgr.WaitForExactNpcPos(keycard_holder, Vector3.new(-30.687, -6.576, 4.363), 0.005)
            npc_mgr.WaitForRadioCallEnd(keycard_holder)
            af_util.ValidateCommand("kill w", "autofarm")
        end)

        af_util.ValidateCommand("hide g s, opendoors, esp", "autofarm")
        if #Players:GetPlayers() > 1 then
            af_util.MovePlayerByRoute(1, 4)
            af_util.MovePlayerByRoute(4, 3)
            af_util.SkipRoutePart(3, 5, 1.5)
        else
            af_util.MovePlayerByRoute(1, 2)
            af_util.SkipRoutePart(2, 5, 1.5)
        end
        af_util.MovePlayerByRoute(5, 8)
        af_util.OpenDoor(Doors[12])
        af_util.MovePlayerByRoute(8, 13)

        GroundItems:WaitForChild("KeycardHS", math.huge):WaitForChild("Data", math.huge)
        while GroundItems:FindFirstChild("KeycardHS") and task.wait(0.1) do
            af_util.ValidateCommand("getitem keycardhs", "autofarm")
        end
        
        local keypad = Geometry.HighSecurityKeypad
        af_util.ObjectInteract({
            object_name = "Keycard Reader", 
            object = keypad.Base, 
        })

        af_util.OpenDoor(Doors[19])
        af_util.OpenDoor(Doors[18])
        
        local guards = npc_mgr.GetNpcsFromTeamByAmt("g", 10)
        for _, guard in pairs(guards) do
            if tools.ComparePositions(npc_mgr.aliases.g[guard].hrp.Position, Vector3.new(-28.200138092041016, -6.556028366088867, 26.499916076660156), 5) == true then
                npc_mgr.KillNPC(guard)
                break
            end
        end

        af_util.MovePlayerByRoute(13, 8)
        af_util.SkipRoutePart(8, 14, 1.5)
        af_util.MovePlayerByRoute(14, 15)

        rmts_mgr.GetRemote("AddStage").OnClientEvent:Connect(function(...)
            local args = {...}
            if args[3] == "Breach and clear the control room" then
                local falcon = npc_mgr.GetNpcsFromTeamByAmt("s", 1)
                table.insert(guards, falcon)
                for _, guard in ipairs(guards) do
                    npc_mgr.WaitForRadioCallEnd(guard)
                end
                af_util.ValidateCommand("void g s", "autofarm")
            elseif args[3] == "Escape" then
                af_util.MovePlayerByRoute(15, 17)
                af_util.hrp.Anchored = false
                af_util.PressReplayButton()
            end
        end)
    end, 
    [4661507759] = function() -- scrs
        af_util.ValidateCommand("hide g w, metdetect, opendoors", "autofarm")
        local agents = npc_mgr.GetNpcsFromTeamByAmt("s", 2)
        for _, agent in ipairs(agents) do
            npc_mgr.MoveNPC(agent, Vector3.new(60.4, 4.599, 160.5))
        end
        local plr_count = #Players:GetPlayers()
        if plr_count > 1 then
            af_util.MovePlayerByRoute(1, 4)
        else
            af_util.SkipRoutePart(1, 4, 1)
            rmts_mgr.GetRemote("NewObjective").OnClientEvent:Wait()
        end
        af_util.ValidateCommand("void g, kill s", "autofarm")
        if plr_count > 1 then
            af_util.MovePlayerByRoute(4, 11)
        else
            af_util.MovePlayerByRoute(4, 6)
            af_util.SkipRoutePart(6, 8, 1)
            af_util.MovePlayerByRoute(8, 11)
        end
        af_util.ValidateCommand("void w", "autofarm")

        task.spawn(function()
            GroundItems:WaitForChild("USB", math.huge):WaitForChild("Data", math.huge)
            while GroundItems:FindFirstChild("USB") and task.wait(0.1) do
                af_util.ValidateCommand("getitem usb", "autofarm")
            end
        end)
        
        local Doors = Geometry.Doors:GetChildren()
        af_util.OpenDoor(Doors[2])
        af_util.MovePlayerByRoute(11, 13)
        af_util.OpenDoor(Doors[8])
        af_util.MovePlayerByRoute(13, 15)
        af_util.OpenDoor(Doors[16])
        af_util.MovePlayerByRoute(15, 17)
        af_util.OpenDoor(Doors[39])
        af_util.MovePlayerByRoute(17, 19)
        af_util.OpenDoor(Doors[34])
        af_util.MovePlayerByRoute(19, 20)
        af_util.SkipRoutePart(20, 47, 0.5)

        local objects = Geometry:GetChildren()

        local first_pc = objects[1680].Computer.Screen
        local second_pc = objects[1684].Computer.Screen
        local third_pc = objects[1682].Computer.Screen

        af_util.ObjectInteract({
            object = first_pc,
            object_name = "Computer"
        })

        af_util.SkipRoutePart(47, 20, 0.5)
        af_util.MovePlayerByRoute(20, 16)
        af_util.SkipRoutePart(16, 21, 1)

        rmts_mgr.GetRemote("SetStageName").OnClientEvent:Wait()

        local analyst_pc = nil

        local listener; listener = Geometry.DescendantAdded:Connect(function(obj)
            if obj.Name ~= "ObjectTip" then return end
            while obj.Value == nil or obj.Value == "" do task.wait() end
            if obj.Value ~= "Hold [F] to authorize" then return end

            analyst_pc = obj.Parent.Parent.Base
            listener:Disconnect()
        end)

        while analyst_pc == nil do task.wait() end
        local pc_table_pos = analyst_pc.Parent.Parent.WorldPivot.Position

        local cases = {
            {
                pos = Vector3.new(92.028, 3.55, 210.901),
                func_in = function()
                    af_util.MovePlayerByRoute(21, 22)
                end,
                func_off = function()
                    af_util.MovePlayerByRoute(22, 21)
                end
            },
            {
                pos = Vector3.new(92.027, 3.55, 226.701),
                func_in = function()
                    af_util.SkipRoutePart(21, 23, 1)
                end,
                func_off = function()
                    af_util.SkipRoutePart(23, 21, 1)
                end
            },
            {
                pos = Vector3.new(91.988, 3.55, 243.616),
                func_in = function()
                    af_util.SkipRoutePart(21, 24, 1)
                end,
                func_off = function()
                    af_util.SkipRoutePart(24, 21, 1)
                end
            },
            {
                pos = Vector3.new(73.027, 3.55, 226.9),
                func_in = function()
                    af_util.SkipRoutePart(21, 25, 1)
                end,
                func_off = function()
                    af_util.SkipRoutePart(25, 21, 1)
                end
            },
            {
                pos = Vector3.new(118.195, 3.55, 261.477),
                func_in = function()
                    af_util.SkipRoutePart(21, 24, 1)
                    af_util.SkipRoutePart(24, 26, 1)
                end,
                func_off = function()
                    af_util.SkipRoutePart(26, 24, 1)
                    af_util.SkipRoutePart(24, 21, 1)
                end
            },
            {
                pos = Vector3.new(134.815, 3.55, 278.091),
                func_in = function()
                    af_util.SkipRoutePart(21, 24, 1)
                    af_util.SkipRoutePart(24, 26, 1)
                    af_util.MovePlayerByRoute(26, 27)
                end,
                func_off = function()
                    af_util.MovePlayerByRoute(27, 26)
                    af_util.SkipRoutePart(26, 24, 1)
                    af_util.SkipRoutePart(24, 21, 1)
                end
            },
            {
                pos = Vector3.new(92.027, 3.55, 286.101),
                func_in = function()
                    af_util.SkipRoutePart(21, 24, 1)
                    af_util.SkipRoutePart(24, 26, 1)
                    af_util.SkipRoutePart(26, 28, 1)
                    af_util.MovePlayerByRoute(28, 29)
                end,
                func_off = function()
                    af_util.MovePlayerByRoute(29, 28)
                    af_util.SkipRoutePart(28, 26, 1)
                    af_util.SkipRoutePart(26, 24, 1)
                    af_util.SkipRoutePart(24, 21, 1)
                end
            },
            {
                pos = Vector3.new(-46.973, 1.55, 219.7),
                func_in = function()
                    af_util.SkipRoutePart(21, 25, 1)
                    af_util.SkipRoutePart(25, 30, 1)
                    EmulateInput.Press(Enum.KeyCode.LeftControl)
                    af_util.OpenDoor(Doors[11])
                    af_util.MovePlayerByRoute(30, 34)
                end,
                func_off = function()
                    af_util.MovePlayerByRoute(34, 31)
                end
            },
            {
                pos = Vector3.new(-60.363, 1.55, 219.688),
                func_in = function()
                    af_util.SkipRoutePart(21, 25, 1)
                    af_util.SkipRoutePart(25, 30, 1)
                    EmulateInput.Press(Enum.KeyCode.LeftControl)
                    af_util.OpenDoor(Doors[11])
                    af_util.MovePlayerByRoute(30, 33)
                    af_util.SkipRoutePart(33, 35, 1)
                end,
                func_off = function()
                    af_util.SkipRoutePart(35, 33, 1)
                    af_util.MovePlayerByRoute(33, 31)
                end
            }
        }

        EmulateInput.Press(Enum.KeyCode.LeftControl)

        local matched_index = nil

        for index, case in ipairs(cases) do
            if tools.ComparePositions(pc_table_pos, case.pos, 5) == false then continue end

            matched_index = index
            case.func_in()

            af_util.ObjectInteract({
                object = analyst_pc,
                object_name = "Computer"
            })

            case.func_off()

            break
        end

        if matched_index ~= 8 and matched_index ~= 9 then
            af_util.SkipRoutePart(21, 25, 1)
            EmulateInput.Press(Enum.KeyCode.LeftControl)
            af_util.SkipRoutePart(25, 30, 1)
            af_util.OpenDoor(Doors[11])
            --task.wait(5)
            af_util.hrp.Anchored = false
            af_util.MovePlayerByRoute(30, 31)
        end

        af_util.SkipRoutePart(31, 36, 1)
        af_util.MovePlayerByRoute(36, 37)
        af_util.OpenDoor(Doors[37])
        af_util.MovePlayerByRoute(37, 39)

        af_util.ObjectInteract({
            object = second_pc,
            object_name = "Computer"
        })

        af_util.MovePlayerByRoute(39, 36)
        af_util.SkipRoutePart(36, 31, 1)
        af_util.SkipRoutePart(31, 40, 1)
        af_util.OpenDoor(Doors[30])
        af_util.MovePlayerByRoute(40, 44)
        af_util.OpenDoor(Doors[32])
        af_util.MovePlayerByRoute(44, 46)

        af_util.ObjectInteract({
            object = third_pc,
            object_name = "Computer"
        })

        local interact = third_pc.parent:WaitForChild("Interact", math.huge)
        interact:GetPropertyChangedSignal("Parent"):Wait()

        af_util.ObjectInteract({
            object = third_pc,
            object_name = "Computer"
        })

        af_util.MovePlayerByRoute(46, 40)
        af_util.SkipRoutePart(40, 31, 1)
        af_util.SkipRoutePart(31, 36, 1)
        af_util.SkipRoutePart(36, 48, 1)
        af_util.MovePlayerByRoute(48, 49)
        Camera.CFrame = CFrame.Angles(math.rad(-30), 0, 0)
        af_util.OpenDoor(Doors[14])
        af_util.MovePlayerByRoute(49, 52)
        af_util.OpenDoor(Doors[45])
        af_util.MovePlayerByRoute(52, 54)
        af_util.OpenDoor(Doors[1])
        af_util.MovePlayerByRoute(54, 55)
        af_util.SkipRoutePart(55, 6, 1.5)
        af_util.MovePlayerByRoute(6, 5)
        af_util.SkipRoutePart(5, 56, 1)

        af_util.PressReplayButton()
    end,
    [4768829954] = function() -- black dusk
        af_util.ValidateCommand("void all, opendoors", "autofarm")
        af_util.ValidateCommand("getitem thermitecan", "autofarm")
        task.spawn(function()
            local thermite = Triggers:WaitForChild("ThermiteCan", math.huge):WaitForChild("Effects", math.huge)
            af_util.ObjectInteract({
                object = thermite,
                object_name = "Thermite Target"
            })
        end)
        af_util.MovePlayerByRoute(1, 4)
        while Geometry.EntranceDoor.Base.Position.Y < 39.2 do task.wait() end
        af_util.MovePlayerByRoute(4, 11)

        local Doors = Geometry.Doors:GetChildren()

        af_util.OpenDoor(Doors[11])
        af_util.MovePlayerByRoute(11, 15)
        af_util.OpenDoor(Doors[6])
        af_util.MovePlayerByRoute(15, 17)
        af_util.OpenDoor(Doors[5])
        af_util.MovePlayerByRoute(17, 19)

        local box = Geometry.BombBox.Lid.Base
        af_util.ObjectInteract({
            object = box,
            object_name = "Bomb Crate",
            object_rotation = CFrame.Angles(math.rad(90), 0, 0),
            rot_x = 0,
            rot_y = -1,
            rot_z = 0
        })

        tools.ChildCounter(8, GroundItems, function(obj)
            return obj.Name == "BlackDuskBomb"
        end)

        af_util.ValidateCommand("getitem blackduskbomb 2", "autofarm")

        local bomb_spots = tools.ChildCounter(6, Geometry, function(obj)
            return obj.Name == "BlackDuskBomb"
        end)

        local PlantBomb = function()
            for _, bomb in ipairs(bomb_spots) do
                local base = bomb:FindFirstChild("Base")

                if base == nil then
                elseif tools.ComparePositions(base.Position, af_util.hrp.Position, 10) == false then
                end

                if base == nil or tools.ComparePositions(base.Position, af_util.hrp.Position, 10) == false then continue end

                af_util.ObjectInteract({
                    object = base,
                    object_name = "Bomb"
                })

                break
            end
        end
        
        af_util.MovePlayerByRoute(19, 17)
        af_util.SkipRoutePart(17, 20, 1)
        af_util.MovePlayerByRoute(20, 21)

        local panel, panel_door, panel_text = nil, nil, nil

        for _, obj in ipairs(Geometry:GetChildren()) do
            if obj.Name == "PanelDoor" and tools.ComparePositions(obj.SlideDoor.Base.Position, Vector3.new(-9.502, 42.503, 126.499), 3) == true then
                panel_door = obj.SlideDoor.Base
            elseif 
                obj.Name == "Model" and 
                obj:FindFirstChild("Screen") and 
                tools.ComparePositions(obj.Screen.Position, Vector3.new(-10.025, 42.701, 130.24), 3) == true and 
                obj.Screen.Interface.BG.TextLabel.Text == "Open"
            then
                panel = obj.Screen
                panel_text = obj.Screen.Interface.BG.TextLabel
            end
        end

        if panel ~= nil then
            af_util.RotateCamera(CFrame.Angles(0, math.rad(90), 0))

            task.spawn(function()
                af_util.ObjectInteract({
                    object = panel,
                    object_name = "Door",
                    object_rotation = CFrame.Angles(math.rad(90), 0, 0),
                    rot_x = 0,
                    rot_y = -1,
                    rot_z = 0
                })
            end)

            while panel_door.Position.Y < 47.7 and panel_text.Text == "Open" and RunService.RenderStepped:Wait() do
                af_util.hrp.CFrame = CFrame.new(-16.262, 41.326, 126.594)
            end
        end

        af_util.MovePlayerByRoute(20, 26)
        af_util.OpenDoor(Doors[32])
        af_util.MovePlayerByRoute(26, 28)

        PlantBomb()

        af_util.MovePlayerByRoute(28, 31)

        PlantBomb()

        task.spawn(function()
            af_util.ValidateCommand("getitem blackduskbomb 2", "autofarm")
        end)

        af_util.MovePlayerByRoute(31, 26)
        af_util.SkipRoutePart(26, 32, 1)
        af_util.MovePlayerByRoute(32, 36)
        af_util.OpenDoor(Doors[15])
        af_util.MovePlayerByRoute(36, 37)
        af_util.OpenDoor(Doors[14])
        af_util.MovePlayerByRoute(37, 41)
        af_util.OpenDoor(Doors[2])
        af_util.MovePlayerByRoute(41, 44)

        PlantBomb()

        af_util.MovePlayerByRoute(44, 46)

        PlantBomb()

        task.spawn(function()
            af_util.ValidateCommand("getitem blackduskbomb 2", "autofarm")
        end)

        af_util.MovePlayerByRoute(46, 36)
        af_util.SkipRoutePart(36, 7, 1)
        af_util.MovePlayerByRoute(7, 10)
        af_util.SkipRoutePart(10, 47, 1)
        af_util.MovePlayerByRoute(47, 48)

        while Geometry.VaultDoor.Center.Rotation.Y < -45 do task.wait() end

        af_util.MovePlayerByRoute(48, 50)

        PlantBomb()

        af_util.MovePlayerByRoute(50, 51)

        PlantBomb()

        task.spawn(function()
            af_util.ValidateCommand("getitem blackduskbomb 2", "autofarm")

            bomb_spots = tools.ChildCounter(8, Geometry, function(obj)
                return obj.Name == "BlackDuskBomb"
            end)
        end)

        af_util.MovePlayerByRoute(51, 47)
        af_util.SkipRoutePart(47, 10, 1)
        af_util.MovePlayerByRoute(10, 9)
        af_util.SkipRoutePart(9, 52, 1)
        af_util.MovePlayerByRoute(52, 56)
        af_util.OpenDoor(Doors[29])
        af_util.MovePlayerByRoute(56, 58)
        af_util.OpenDoor(Doors[30])
        af_util.MovePlayerByRoute(58, 61)

        PlantBomb()

        af_util.MovePlayerByRoute(61, 64)

        PlantBomb()

        task.spawn(function()
            af_util.TpToEscapeZone(Vector3.new(8.862, 31.325, -19.537))
        end)

        af_util.PressReplayButton()

        --workspace.Level.Geometry:GetChildren()[2245]
        --workspace.Level.Geometry:GetChildren()[2245].Screen
    end
}

af_util.spots = {
    [3200010305] = { -- blacksite
        [1] = {pos = Vector3.new(100.27120208740234, 7.1239800453186035, -1.0548720359802246), mul = 1},
        [2] = {pos = Vector3.new(104.56007385253906, 7.023995876312256, 5.229642868041992), mul = 0.5},
        [3] = {pos = Vector3.new(104.56007385253906, 7.023995876312256, -7.670356750488281), mul = 0.25},
        [4] = {pos = Vector3.new(100.36007690429688, 7.023995876312256, -6.870350360870361), mul = 1},
        [5] = {pos = Vector3.new(100.36007690429688, 26.823997497558594, -6.870350360870361), mul = 1},
        [6] = {pos = Vector3.new(95.3599624633789, 24.324024200439453, 7.629767894744873), mul = 1},
        [7] = {pos = Vector3.new(95.3599624633789, 24.324024200439453, 31.329769134521484), mul = 1},
        [8] = {pos = Vector3.new(95.3599624633789, 24.324024200439453, 43.929771423339844), mul = 1},
        [9] = {pos = Vector3.new(95.52032470703125, 19.923952102661133, 57.30582046508789), mul = 1},
        [10] = {pos = Vector3.new(136.39999389648438, 19.923952102661133, 65.49972534179688), mul = 1},
        [11] = {pos = Vector3.new(136.39999389648438, 19.923952102661133, 74.19972229003906), mul = 1},
        [12] = {pos = Vector3.new(159.89956665039062, 19.923206329345703, 83.00039672851562), mul = 1},
        [13] = {pos = Vector3.new(159.89956665039062, 19.923206329345703, 94.20039367675781), mul = 1},
        [14] = {pos = Vector3.new(159.89956665039062, 19.923206329345703, 99.70039367675781), mul = 1},
        [15] = {pos = Vector3.new(174.9989013671875, 19.922157287597656, 108.50076293945312), mul = 1},
        [16] = {pos = Vector3.new(174.9989013671875, 19.922157287597656, 158.30076599121094), mul = 1},
        [17] = {pos = Vector3.new(97.4989013671875, 19.922157287597656, 158.30076599121094), mul = 1},
        [18] = {pos = Vector3.new(97.4989013671875, 19.922157287597656, 138.60076904296875), mul = 1},
        [19] = {pos = Vector3.new(92.79890441894531, 23.022157669067383, 138.60076904296875), mul = 1},
        [20] = {pos = Vector3.new(86.79890441894531, 23.022157669067383, 138.60076904296875), mul = 1},
        [21] = {pos = Vector3.new(86.79890441894531, 38.82215881347656, 138.60076904296875), mul = 1},
        [22] = {pos = Vector3.new(90.7872085571289, 37.72395706176758, 137.96646118164062), mul = 1},
        [23] = {pos = Vector3.new(103.0991439819336, 35.12327575683594, 120.49982452392578), mul = 1},
        [24] = {pos = Vector3.new(115.8991470336914, 35.12327575683594, 120.49982452392578), mul = 1},
        [25] = {pos = Vector3.new(125.99911499023438, 35.12327575683594, 135.99984741210938), mul = 1},
        [26] = {pos = Vector3.new(132.49856567382812, 35.121917724609375, 127.30058288574219), mul = 1},
        [27] = {pos = Vector3.new(132.49856567382812, 35.121917724609375, 112.50057983398438), mul = 1},
        [28] = {pos = Vector3.new(132.49856567382812, 20.02191734313965, 112.50057983398438), mul = 1},
        [29] = {pos = Vector3.new(132.49856567382812, 21.921916961669922, 99.20057678222656), mul = 1},
        [30] = {pos = Vector3.new(37.498565673828125, 21.921916961669922, 99.20057678222656), mul = 1},
        [31] = {pos = Vector3.new(37.498565673828125, 6.421916961669922, 101.50057983398438), mul = 1},
        [32] = {pos = Vector3.new(37.498565673828125, 6.421916961669922, 86.10057830810547), mul = 1},
        [33] = {pos = Vector3.new(37.498565673828125, 6.421916961669922, 77.30057525634766), mul = 1},
        [34] = {pos = Vector3.new(18.700159072875977, 6.324803352355957, 69.79914093017578), mul = 1},
        [35] = {pos = Vector3.new(0.01956939697265625, 18.450918197631836, 67.76422119140625), mul = 1},
        [36] = {pos = Vector3.new(-4.380430698394775, 18.450918197631836, 67.76422119140625), mul = 1},
        [37] = {pos = Vector3.new(-11.08043098449707, 19.65091896057129, 67.76422119140625), mul = 1},
        [38] = {pos = Vector3.new(-0.19896507263183594, 6.325926780700684, 28.598907470703125), mul = 1},
        [39] = {pos = Vector3.new(-10.898964881896973, 6.325926780700684, 28.598907470703125), mul = 1},
        [40] = {pos = Vector3.new(-16.198965072631836, 6.325926780700684, -10.901092529296875), mul = 1},
        [41] = {pos = Vector3.new(-18.498964309692383, 6.325926780700684, -10.901092529296875), mul = 1},
        [42] = {pos = Vector3.new(-25.898963928222656, 6.325926780700684, -10.901092529296875), mul = 1},
        [43] = {pos = Vector3.new(-30.68463706970215, 7.727260112762451, -16.935766220092773), mul = 1},
        [44] = {pos = Vector3.new(-42.60002136230469, 15.722034454345703, -17.299205780029297), mul = 1},
        [45] = {pos = Vector3.new(-47.80002212524414, 15.722034454345703, -17.299205780029297), mul = 1},
        [46] = {pos = Vector3.new(-47.80002212524414, 15.722034454345703, -6.09920597076416), mul = 1},
        [47] = {pos = Vector3.new(-44.000022888183594, 15.722034454345703, -6.09920597076416), mul = 1},
        [48] = {pos = Vector3.new(-33.79994583129883, 23.223936080932617, -5.698215007781982), mul = 1},
        [49] = {pos = Vector3.new(-26.1999454498291, 23.223936080932617, -5.698215007781982), mul = 1},
        [50] = {pos = Vector3.new(-26.1999454498291, 23.223936080932617, -16.89821434020996), mul = 1},
        [51] = {pos = Vector3.new(-31.799945831298828, 23.223936080932617, -16.89821434020996), mul = 1},
        [52] = {pos = Vector3.new(-42.79994583129883, 31.323936462402344, -16.89821434020996), mul = 1},
        [53] = {pos = Vector3.new(-53.0999870300293, 29.123981475830078, -16.200279235839844), mul = 1},
        [54] = {pos = Vector3.new(-74.59998321533203, 29.123981475830078, -16.200279235839844), mul = 1},
        [55] = {pos = Vector3.new(-82.74490356445312, 36.52397155761719, -3.3553991317749023), mul = 1},
        [56] = {pos = Vector3.new(-105.61097717285156, 32.5240364074707, 39.11674499511719), mul = 1},
        [57] = {pos = Vector3.new(-111.29741668701172, 28.722042083740234, 48.697139739990234), mul = 1},
    },
    [2625195454] = { -- deposit
        [1] = {pos = Vector3.new(201.8429412841797, 188.32394409179688, 109.56322479248047), mul = 2},
        [2] = {pos = Vector3.new(182.30999755859375, 188.44398498535156, 63.570228576660156), mul = 1},
    },
    [2797881676] = { -- financier
        [1] = {pos = Vector3.new(-8.287199020385742, 4.323972225189209, -29.836877822875977), mul = 1},
        [2] = {pos = Vector3.new(-33.51278305053711, 4.323999881744385, -30.499374389648438), mul = 0.5},
        [3] = {pos = Vector3.new(-33.62016677856445, 4.323971748352051, -21.149919509887695), mul = 1},
        [4] = {pos = Vector3.new(-31.99999237060547, 4.323999881744385, -7.800000190734863), mul = 1},
        [5] = {pos = Vector3.new(-32.18719482421875, 4.323972225189209, 14.163124084472656), mul = 1},
        [6] = {pos = Vector3.new(-32.18719482421875, 4.323972225189209, 33.86312484741211), mul = 1},
        [7] = {pos = Vector3.new(-32.18719482421875, 4.323972225189209, 39.96312713623047), mul = 1},
        [8] = {pos = Vector3.new(-22.78720474243164, 4.323972225189209, 13.363125801086426), mul = 0.5},
        [9] = {pos = Vector3.new(-22.887208938598633, 4.323971748352051, 17.563125610351562), mul = 1},
        [10] = {pos = Vector3.new(-36.20086669921875, 4.323972225189209, 39.163124084472656), mul = 1},
        [11] = {pos = Vector3.new(-39.01280212402344, 7.350924491882324, 24.763126373291016), mul = 1},
        [12] = {pos = Vector3.new(-43.71280288696289, 7.350924491882324, 24.763126373291016), mul = 1},
        [13] = {pos = Vector3.new(-68.91280364990234, 7.350924491882324, 24.763126373291016), mul = 1},
        [14] = {pos = Vector3.new(-70.16341400146484, 4.323971748352051, 40.80072784423828), mul = 1},
        [15] = {pos = Vector3.new(-43.08719253540039, 5.423971176147461, 7.746218681335449), mul = 1},
        [16] = {pos = Vector3.new(-47.68719482421875, 4.323971271514893, -0.33687496185302734), mul = 1},
        [17] = {pos = Vector3.new(-41.712799072265625, 4.323972225189209, -6.536874294281006), mul = 1},
        [18] = {pos = Vector3.new(-64.9871826171875, 2.999264717102051, 3.5462164878845215), mul = 1},
        [19] = {pos = Vector3.new(-76.4585952758789, 2.9993627071380615, 6.5634026527404785), mul = 1},
        [20] = {pos = Vector3.new(-28.69997787475586, 4.723962306976318, -40.4002685546875), mul = 0.5},
        [21] = {pos = Vector3.new(-37.11280059814453, 4.323971748352051, -40.153785705566406), mul = 1},
        [22] = {pos = Vector3.new(-38.5, 4.323972225189209, -30.400270462036133), mul = 1},
        [23] = {pos = Vector3.new(-41.98719024658203, 4.323972225189209, -28.636873245239258), mul = 1},
        [24] = {pos = Vector3.new(-48.4202995300293, 4.323971748352051, -24.894174575805664), mul = 1},
        [25] = {pos = Vector3.new(-25.900001525878906, 3.623972177505493, -9.50027084350586), mul = 0.5},
        [26] = {pos = Vector3.new(-26.079824447631836, 16.223968505859375, -25.24994468688965), mul = 1},
        [27] = {pos = Vector3.new(-29.599998474121094, 14.723970413208008, -30.00029182434082), mul = 1},
        [28] = {pos = Vector3.new(-15.499999046325684, 14.723970413208008, -32.50028991699219), mul = 1},
        [29] = {pos = Vector3.new(-19.19999885559082, 14.723970413208008, -39.300270080566406), mul = 1},
        [30] = {pos = Vector3.new(-35.900054931640625, 14.723970413208008, -32.800270080566406), mul = 1},
        [31] = {pos = Vector3.new(-35.80005645751953, 14.723970413208008, -41.00027084350586), mul = 1},
        [32] = {pos = Vector3.new(-38.78725814819336, 14.723970413208008, -40.23687744140625), mul = 1},
        [33] = {pos = Vector3.new(-32.297950744628906, 14.723974227905273, -54.405521392822266), mul = 1},
        [34] = {pos = Vector3.new(-21.89794921875, 14.723974227905273, -54.405521392822266), mul = 0.75},
        [35] = {pos = Vector3.new(-23.79996681213379, 14.723974227905273, -50.400272369384766), mul = 1},
        [36] = {pos = Vector3.new(-39.299190521240234, 13.399361610412598, -25.59900665283203), mul = 1},
        [37] = {pos = Vector3.new(-39.49921798706055, 13.399360656738281, -8.400278091430664), mul = 1},
        [38] = {pos = Vector3.new(-52.600006103515625, 13.399361610412598, -3.0002779960632324), mul = 0.75},
        [39] = {pos = Vector3.new(-57.20000457763672, 13.399166107177734, 1.5997238159179688), mul = 1},
        [40] = {pos = Vector3.new(-39.99557113647461, 13.69998550415039, 16.298934936523438), mul = 0.5},
        [41] = {pos = Vector3.new(-40.09998321533203, 15.950002670288086, 17.800004959106445), mul = 1},
        [42] = {pos = Vector3.new(-49.79999542236328, 15.954999923706055, 17.599998474121094), mul = 1},
        [43] = {pos = Vector3.new(-59.779823303222656, 15.954363822937012, 17.599292755126953), mul = 0.8},
        [44] = {pos = Vector3.new(-59.79999923706055, 19.57897186279297, 22.299724578857422), mul = 1},
        [45] = {pos = Vector3.new(-59.28429412841797, 19.523988723754883, 36.69968032836914), mul = 1},
    },
    [2951213182] = { -- withdrawal
        [1] = {pos = Vector3.new(-20.376602172851562, 2.8240902423858643, 8.322555541992188), mul = 1},
        [2] = {pos = Vector3.new(-25.58940315246582, 16.8240909576416, 22.159160614013672), mul = 1},
        [3] = {pos = Vector3.new(-5.889402389526367, 18.224090576171875, 22.159160614013672), mul = 0.75},
        [4] = {pos = Vector3.new(-5.889402389526367, 18.224090576171875, 28.359159469604492), mul = 1},
        [5] = {pos = Vector3.new(-5.902793884277344, 15.624086380004883, 35.005706787109375), mul = 1},
        [6] = {pos = Vector3.new(-5.989996910095215, 15.624088287353516, 40.75921630859375), mul = 0.5},
        [7] = {pos = Vector3.new(3.410003662109375, 15.624088287353516, 40.75921630859375), mul = 1},
        [8] = {pos = Vector3.new(3.410003662109375, 15.624088287353516, 31.359216690063477), mul = 1},
        [9] = {pos = Vector3.new(16.910003662109375, 15.624088287353516, 33.75921630859375), mul = 1},
        [10] = {pos = Vector3.new(12.610004425048828, 19.02408790588379, 42.55921936035156), mul = 1},
        [11] = {pos = Vector3.new(12.110004425048828, 19.02408790588379, 46.05921936035156), mul = 1},
        [12] = {pos = Vector3.new(12.110004425048828, 19.52408790588379, 50.55921936035156), mul = 1},
        [13] = {pos = Vector3.new(15.110004425048828, 19.52408790588379, 57.55921936035156), mul = 1},
        [14] = {pos = Vector3.new(15.110004425048828, 19.52408790588379, 55.85921859741211), mul = 1},
        [15] = {pos = Vector3.new(28.610004425048828, 19.52408790588379, 55.85921859741211), mul = 1},
        [16] = {pos = Vector3.new(33.61000442504883, 19.52408790588379, 66.95922088623047), mul = 1},
        [17] = {pos = Vector3.new(2.610053539276123, 15.224071502685547, 64.65916442871094), mul = 1},
        [18] = {pos = Vector3.new(4.510053634643555, 15.224071502685547, 95.95916748046875), mul = 1},
        [19] = {pos = Vector3.new(27.009967803955078, 13.900097846984863, 97.65949249267578), mul = 1},
        [20] = {pos = Vector3.new(15.010010719299316, 14.300114631652832, 90.30952453613281), mul = 1},
        [21] = {pos = Vector3.new(15.022769927978516, 15.224071502685547, 84.2225570678711), mul = 1},
        [22] = {pos = Vector3.new(26.92276954650879, 17.324071884155273, 84.2225570678711), mul = 1},
        [23] = {pos = Vector3.new(26.92276954650879, 3.224071502685547, 82.92255401611328), mul = 1},
        [24] = {pos = Vector3.new(26.92276954650879, 3.224071502685547, 95.7225570678711), mul = 1},
        [25] = {pos = Vector3.new(14.422769546508789, 3.224071502685547, 99.32255554199219), mul = 1},
        [26] = {pos = Vector3.new(14.422769546508789, 3.224071502685547, 82.62255859375), mul = 1},
        [27] = {pos = Vector3.new(14.422769546508789, 3.224071502685547, 52.62255859375), mul = 1},
        [28] = {pos = Vector3.new(42.510009765625, 3.424130439758301, 42.45921325683594), mul = 1},
        [29] = {pos = Vector3.new(50.622772216796875, 3.2239999771118164, 52.62255859375), mul = 1},
        [30] = {pos = Vector3.new(65.62277221679688, 3.224071502685547, 52.62255859375), mul = 1},
        [31] = {pos = Vector3.new(75.8227767944336, 3.224071502685547, 44.12255859375), mul = 1},
        [32] = {pos = Vector3.new(75.11015319824219, 3.2240805625915527, 36.55918884277344), mul = 1},
        [33] = {pos = Vector3.new(76.01010131835938, 3.824079990386963, 61.65922927856445), mul = 1},
        [34] = {pos = Vector3.new(76.01010131835938, 3.824079990386963, 67.5592269897461), mul = 1},
        [35] = {pos = Vector3.new(14.610137939453125, 3.224104881286621, 28.459197998046875), mul = 1},
        [36] = {pos = Vector3.new(-12.48968505859375, 3.424070358276367, 27.359214782714844), mul = 1},
        [37] = {pos = Vector3.new(-36.78968811035156, 3.424070358276367, 27.359214782714844), mul = 1},
        [38] = {pos = Vector3.new(-33.24726486206055, 2.9540624618530273, 18.207504272460938), mul = 1},
        [39] = {pos = Vector3.new(-25.42828941345215, 2.9539999961853027, 19.722532272338867), mul = 1},
        [40] = {pos = Vector3.new(-26.594999313354492, 2.9539999961853027, 9.664999961853027), mul = 1},
        [41] = {pos = Vector3.new(-14.689868927001953, 3.224031448364258, 96.05950927734375), mul = 1},
    },
    [3590667014] = { -- lakehouse
        [1] = {pos = Vector3.new(183.24636840820312, 20.02405548095703, 32.411048889160156), mul = 1},
        [2] = {pos = Vector3.new(112.33644104003906, 17.92400550842285, 13.36788558959961), mul = 1},
        [3] = {pos = Vector3.new(104.03643798828125, 17.92400550842285, 13.36788558959961), mul = 1},
        [4] = {pos = Vector3.new(94.84717559814453, 19.824005126953125, -24.993865966796875), mul = 1},
        [5] = {pos = Vector3.new(73.26007080078125, 19.324045181274414, -24.1402530670166), mul = 1},
        [6] = {pos = Vector3.new(62.860069274902344, 19.324045181274414, -24.1402530670166), mul = 0.75},
        [7] = {pos = Vector3.new(55.260013580322266, 19.324010848999023, -34.54026794433594), mul = 1},
        [8] = {pos = Vector3.new(58.76006317138672, 19.324010848999023, -36.140262603759766), mul = 0.75},
        [9] = {pos = Vector3.new(35.96007537841797, 18.92400360107422, -47.14023208618164), mul = 1},
        [10] = {pos = Vector3.new(26.104358673095703, 23.89590835571289, -53.136043548583984), mul = 1},
        [11] = {pos = Vector3.new(14.939842224121094, 18.92400360107422, -60.48987579345703), mul = 0.75},
        [12] = {pos = Vector3.new(7.439842224121094, 18.92400360107422, -60.48987579345703), mul = 1},
        [13] = {pos = Vector3.new(7.439842224121094, 20.42400360107422, -52.68987274169922), mul = 0.5},
        [14] = {pos = Vector3.new(7.48015022277832, 6.624006271362305, -37.18989944458008), mul = 0.5},
        [15] = {pos = Vector3.new(7.759973526000977, 5.324004173278809, -30.74024772644043), mul = 1},
        [16] = {pos = Vector3.new(32.45997619628906, 5.324004173278809, -30.74024772644043), mul = 1},
        [17] = {pos = Vector3.new(66.46000671386719, 19.324005126953125, -36.44024658203125), mul = 1},
        [18] = {pos = Vector3.new(66.46000671386719, 20.324005126953125, -43.2402458190918), mul = 0.5},
        [19] = {pos = Vector3.new(66.04721069335938, 14.024006843566895, -50.776859283447266), mul = 1},
        [20] = {pos = Vector3.new(66.04721069335938, 14.024006843566895, -56.67686080932617), mul = 1},
        [21] = {pos = Vector3.new(58.547210693359375, 14.024006843566895, -56.67686080932617), mul = 1},
        [22] = {pos = Vector3.new(58.547210693359375, 14.024006843566895, -47.97686004638672), mul = 0.5},
        [23] = {pos = Vector3.new(57.7801628112793, 7.323978900909424, -39.28989791870117), mul = 0.5},
        [24] = {pos = Vector3.new(57.7801628112793, 5.7239789962768555, -35.08989715576172), mul = 1},
        [25] = {pos = Vector3.new(39.6801643371582, 5.7239789962768555, -35.08989715576172), mul = 1},
        [26] = {pos = Vector3.new(36.160011291503906, 5.324006080627441, -32.940242767333984), mul = 1},
        [27] = {pos = Vector3.new(47.760009765625, 9.324006080627441, -32.940242767333984), mul = 1},
        [28] = {pos = Vector3.new(47.760009765625, 5.324006080627441, -13.940242767333984), mul = 1},
        [29] = {pos = Vector3.new(64.86000061035156, 5.323999881744385, -5.940000057220459), mul = 1},
        [30] = {pos = Vector3.new(68.86001586914062, 5.323975563049316, -17.640270233154297), mul = 1},
        [31] = {pos = Vector3.new(31.047210693359375, 5.32400369644165, -56.69375228881836), mul = 1},
        [32] = {pos = Vector3.new(26.459999084472656, 5.323999881744385, -77.44000244140625), mul = 1},
        [33] = {pos = Vector3.new(15.260000228881836, 5.323999881744385, -81.63999938964844), mul = 1},
        [34] = {pos = Vector3.new(35.46000671386719, 6.924003601074219, -24.040267944335938), mul = 1},
        [35] = {pos = Vector3.new(33.060001373291016, 3.3239998817443848, -10.24027156829834), mul = 1},
        [36] = {pos = Vector3.new(6.860000133514404, 3.3239998817443848, 0.05999999865889549), mul = 1},
        [37] = {pos = Vector3.new(2.359999895095825, 3.3239998817443848, 11.760000228881836), mul = 1},
    },
    [4518266946] = { -- scientist
        [1] = {pos = Vector3.new(-76.73486328125, 9.63321590423584, 130.3460235595703), mul = 2},
        [2] = {pos = Vector3.new(-94.63982391357422, 19.170907974243164, 121.25968170166016), mul = 2},
        [3] = {pos = Vector3.new(-77.20426177978516, 8.757187843322754, 102.62760162353516), mul = 0.75},
        [4] = {pos = Vector3.new(-64.28557586669922, 8.757189750671387, 108.20255279541016), mul = 0.75},
        [5] = {pos = Vector3.new(-35.784244537353516, 11.33156967163086, 63.37843322753906), mul = 0.8},
        [6] = {pos = Vector3.new(-16.241209030151367, 3.549454689025879, 36.78435516357422), mul = 0.75},
        [7] = {pos = Vector3.new(-10.363006591796875, 3.5494532585144043, 29.34404182434082), mul = 1},
        [8] = {pos = Vector3.new(-9.025506973266602, 3.5494532585144043, 25.887413024902344), mul = 0.5},
        [9] = {pos = Vector3.new(-3.2393150329589844, 3.5494532585144043, 25.887413024902344), mul = 0.5},
        [10] = {pos = Vector3.new(-3.2393155097961426, 3.5494532585144043, 19.540287017822266), mul = 0.25},
        [11] = {pos = Vector3.new(-3.23931622505188, -5.793325901031494, 8.457051277160645), mul = 0.8},
        [12] = {pos = Vector3.new(-12.221589088439941, -6.350544452667236, 5.795297622680664), mul = 1},
        [13] = {pos = Vector3.new(-14.009870529174805, -6.350544452667236, 13.908618927001953), mul = 1},
        [14] = {pos = Vector3.new(-12.471277236938477, 3.5494532585144043, 1.3570528030395508), mul = 1},
        [15] = {pos = Vector3.new(-24.00069236755371, 3.3239731788635254, -17.400672912597656), mul = 1},
        [16] = {pos = Vector3.new(-8.799992561340332, 3.40397310256958, -8.300275802612305), mul = 1},
        [17] = {pos = Vector3.new(-8.799992561340332, 3.40397310256958, -61.000274658203125), mul = 1},
    },
    [4661507759] = { -- scrs
        [1] = {pos = Vector3.new(-0.08665180206298828, 3.4179999828338623, 59.51341247558594), mul = 0.1},
        [2] = {pos = Vector3.new(3.1011276245117188, 3.4179999828338623, 64.85079956054688), mul = 0.05},
        [3] = {pos = Vector3.new(-7.998997211456299, 3.4179999828338623, 64.75076293945312), mul = 1},
        [4] = {pos = Vector3.new(-5.198997497558594, 3.4179999828338623, 59.650753021240234), mul = 0.75},
        [5] = {pos = Vector3.new(-13.886655807495117, 3.4179999828338623, 59.41339874267578), mul = 1},
        [6] = {pos = Vector3.new(-13.986652374267578, 3.4176435470581055, 96.21340942382812), mul = 1},
        [7] = {pos = Vector3.new(15.015506744384766, 3.4171371459960938, 90.04719543457031), mul = 1},
        [8] = {pos = Vector3.new(8.713348388671875, 7.6176438331604, 97.51341247558594), mul = 1},
        [9] = {pos = Vector3.new(27.40035057067871, 6.513165473937988, 115.50180053710938), mul = 1},
        [10] = {pos = Vector3.new(28.401498794555664, 3.4202451705932617, 141.00003051757812), mul = 1},
        [11] = {pos = Vector3.new(32.80149841308594, 3.4202451705932617, 140.50003051757812), mul = 1},
        [12] = {pos = Vector3.new(71.60182189941406, 3.4213924407958984, 146.20095825195312), mul = 1},
        [13] = {pos = Vector3.new(70.78154754638672, 3.4213924407958984, 158.20706176757812), mul = 1},
        [14] = {pos = Vector3.new(69.50186157226562, 3.4213919639587402, 182.30096435546875), mul = 1},
        [15] = {pos = Vector3.new(66.08905029296875, 3.4213919639587402, 198.7643585205078), mul = 1},
        [16] = {pos = Vector3.new(66.08905029296875, 3.4213919639587402, 206.96437072753906), mul = 1},
        [17] = {pos = Vector3.new(83.019775390625, 3.421963691711426, 205.64663696289062), mul = 0.5},
        [18] = {pos = Vector3.new(83.019775390625, 3.421963691711426, 197.046630859375), mul = 1},
        [19] = {pos = Vector3.new(104.69931030273438, 3.421097755432129, 196.59677124023438), mul = 1},
        [20] = {pos = Vector3.new(114.29931640625, 3.421097755432129, 196.29676818847656), mul = 0.5},
        [21] = {pos = Vector3.new(73.85930633544922, 8.32669448852539, 210.13768005371094), mul = 1},
        [22] = {pos = Vector3.new(91.6292495727539, 8.326876640319824, 211.17166137695312), mul = 1},
        [23] = {pos = Vector3.new(91.94760131835938, 8.121856689453125, 227.0793914794922), mul = 1},
        [24] = {pos = Vector3.new(92.0675277709961, 8.121856689453125, 243.83746337890625), mul = 1},
        [25] = {pos = Vector3.new(72.94763946533203, 8.326889038085938, 226.84840393066406), mul = 0.5},
        [26] = {pos = Vector3.new(118.06645202636719, 8.121856689453125, 261.1764831542969), mul = 1},
        [27] = {pos = Vector3.new(134.82803344726562, 8.121857643127441, 278.32525634765625), mul = 1},
        [28] = {pos = Vector3.new(100.44023895263672, 8.121856689453125, 286.6924743652344), mul = 1},
        [29] = {pos = Vector3.new(92.04023742675781, 8.121856689453125, 286.6924743652344), mul = 1},
        [30] = {pos = Vector3.new(35.98731994628906, 3.4221549034118652, 233.16355895996094), mul = 1},
        [31] = {pos = Vector3.new(-24.79959487915039, 3.4235422611236572, 233.4996795654297), mul = 1},
        [32] = {pos = Vector3.new(-32.79958724975586, 3.4235422611236572, 234.09971618652344), mul = 1},
        [33] = {pos = Vector3.new(-47.10136413574219, 6.421858787536621, 228.60009765625), mul = 1},
        [34] = {pos = Vector3.new(-46.7885627746582, 6.121858596801758, 219.8634796142578), mul = 1},
        [35] = {pos = Vector3.new(-60.16203689575195, 6.1218581199646, 219.98919677734375), mul = 1},
        [36] = {pos = Vector3.new(-24.79959487915039, 3.423578977584839, 203.4996795654297), mul = 1},
        [37] = {pos = Vector3.new(-12.999592781066895, 3.4235410690307617, 203.3997039794922), mul = 1},
        [38] = {pos = Vector3.new(1.500406265258789, 3.4235799312591553, 203.0996856689453), mul = 0.5},
        [39] = {pos = Vector3.new(1.500406265258789, 3.4235613346099854, 218.19969177246094), mul = 1},
        [40] = {pos = Vector3.new(-25.419763565063477, 3.42354154586792, 240.15008544921875), mul = 1},
        [41] = {pos = Vector3.new(-25.419763565063477, 3.42354154586792, 245.05007934570312), mul = 1.5},
        [42] = {pos = Vector3.new(-3.5867271423339844, 9.175957679748535, 278.7655029296875), mul = 1.5},
        [43] = {pos = Vector3.new(37.920658111572266, 3.424191474914551, 326.2522277832031), mul = 1.5},
        [44] = {pos = Vector3.new(72.5016860961914, 3.424191474914551, 327.8966369628906), mul = 1},
        [45] = {pos = Vector3.new(82.1016845703125, 3.42419171333313, 327.8966369628906), mul = 0.5},
        [46] = {pos = Vector3.new(82.1016845703125, 3.4242093563079834, 313.0966491699219), mul = 1},
        [47] = {pos = Vector3.new(114.20018005371094, 3.4262051582336426, 180.69705200195312), mul = 1},
        [48] = {pos = Vector3.new(-24.58679962158203, 3.42354154586792, 178.54617309570312), mul = 1},
        [49] = {pos = Vector3.new(-32.89958190917969, 3.42354154586792, 178.4997100830078), mul = 1},
        [50] = {pos = Vector3.new(-40.4996223449707, 3.423995018005371, 178.19940185546875), mul = 1},
        [51] = {pos = Vector3.new(-48.799625396728516, 3.423995018005371, 162.59939575195312), mul = 1},
        [52] = {pos = Vector3.new(-52.49962615966797, 3.423995018005371, 162.59939575195312), mul = 0.75},
        [53] = {pos = Vector3.new(-66.19962310791016, 3.423995018005371, 162.59939575195312), mul = 1},
        [54] = {pos = Vector3.new(-66.19962310791016, 3.423995018005371, 155.7993927001953), mul = 1.5},
        [55] = {pos = Vector3.new(-66.19962310791016, 3.423995018005371, 91.5993881225586), mul = 1.5},
        [56] = {pos = Vector3.new(-21.19700050354004, 3.4179999828338623, 56.83100128173828), mul = 1},
    },
    [4768829954] = { -- black dusk
        [1] = {pos = Vector3.new(8.862091064453125, 31.32532501220703, -19.537464141845703), mul = 1},
        [2] = {pos = Vector3.new(23.872684478759766, 35.4140739440918, -12.599403381347656), mul = 0.75},
        [3] = {pos = Vector3.new(-1.8278121948242188, 35.60242462158203, -12.59943962097168), mul = 1},
        [4] = {pos = Vector3.new(11.289063453674316, 31.32532501220703, -12.906108856201172), mul = 1},
        [5] = {pos = Vector3.new(12.113168716430664, 31.82419204711914, 8.762553215026855), mul = 1},
        [6] = {pos = Vector3.new(18.38567352294922, 29.324810028076172, 60.06352615356445), mul = 1},
        [7] = {pos = Vector3.new(38.38567352294922, 29.324810028076172, 63.263526916503906), mul = 1},
        [8] = {pos = Vector3.new(24.797271728515625, 29.325000762939453, 114.3995361328125), mul = 1},
        [9] = {pos = Vector3.new(30.684471130371094, 29.322532653808594, 134.26266479492188), mul = 1},
        [10] = {pos = Vector3.new(52.896827697753906, 29.32316780090332, 136.70028686523438), mul = 1},
        [11] = {pos = Vector3.new(55.79678726196289, 29.323169708251953, 127.60029602050781), mul = 1},
        [12] = {pos = Vector3.new(55.79678726196289, 29.323169708251953, 124.30029296875), mul = 1},
        [13] = {pos = Vector3.new(69.197509765625, 30.324899673461914, 112.6011962890625), mul = 1},
        [14] = {pos = Vector3.new(69.19720458984375, 42.92485809326172, 95.7009506225586), mul = 1},
        [15] = {pos = Vector3.new(48.897464752197266, 41.3237190246582, 117.90019226074219), mul = 1},
        [16] = {pos = Vector3.new(41.397464752197266, 41.3237190246582, 117.90019226074219), mul = 1},
        [17] = {pos = Vector3.new(35.597023010253906, 41.32489776611328, 132.6994171142578), mul = 1},
        [18] = {pos = Vector3.new(35.58388900756836, 41.32529067993164, 140.84620666503906), mul = 1},
        [19] = {pos = Vector3.new(38.40949249267578, 41.32529067993164, 158.26312255859375), mul = 1},
        [20] = {pos = Vector3.new(31.38421630859375, 41.32489776611328, 129.5628204345703), mul = 1},
        [21] = {pos = Vector3.new(-7.515785217285156, 41.32489776611328, 126.46282196044922), mul = 1},
        [22] = {pos = Vector3.new(-27.91578483581543, 42.22489929199219, 126.46282196044922), mul = 1},
        [23] = {pos = Vector3.new(-43.58904266357422, 31.126079559326172, 127.16256713867188), mul = 1},
        [24] = {pos = Vector3.new(-67.50209045410156, 34.92390823364258, 125.40982818603516), mul = 1},
        [25] = {pos = Vector3.new(-100.41846466064453, 31.227235794067383, 108.30266571044922), mul = 1},
        [26] = {pos = Vector3.new(-104.51847076416016, 29.32723617553711, 106.60266876220703), mul = 1},
        [27] = {pos = Vector3.new(-119.61846923828125, 29.32723617553711, 106.60266876220703), mul = 1},
        [28] = {pos = Vector3.new(-119.61846923828125, 29.32723617553711, 95.30266571044922), mul = 1},
        [29] = {pos = Vector3.new(-119.61846923828125, 29.32723617553711, 87.20266723632812), mul = 1},
        [30] = {pos = Vector3.new(-97.71503448486328, 17.328388214111328, 90.54534912109375), mul = 1},
        [31] = {pos = Vector3.new(-91.21503448486328, 17.328388214111328, 90.54534912109375), mul = 1},
        [32] = {pos = Vector3.new(-80.0875015258789, 29.327239990234375, 97.36045837402344), mul = 1},
        [33] = {pos = Vector3.new(-17.102447509765625, 29.32192039489746, 87.39837646484375), mul = 1},
        [34] = {pos = Vector3.new(-17.102447509765625, 29.32192039489746, 61.59837341308594), mul = 1},
        [35] = {pos = Vector3.new(30.897552490234375, 29.32192039489746, 61.59837341308594), mul = 1},
        [36] = {pos = Vector3.new(108.50064086914062, 29.326398849487305, 74.29632568359375), mul = 1},
        [37] = {pos = Vector3.new(143.31143188476562, 29.326568603515625, 74.16506958007812), mul = 1},
        [38] = {pos = Vector3.new(152.11143493652344, 29.326568603515625, 74.16506958007812), mul = 1},
        [39] = {pos = Vector3.new(152.11143493652344, 29.326568603515625, 84.26506805419922), mul = 1},
        [40] = {pos = Vector3.new(171.41143798828125, 29.326568603515625, 84.26506805419922), mul = 1},
        [41] = {pos = Vector3.new(171.41143798828125, 29.326568603515625, 80.56507110595703), mul = 1},
        [42] = {pos = Vector3.new(171.41143798828125, 29.326568603515625, 74.46507263183594), mul = 1},
        [43] = {pos = Vector3.new(179.63385009765625, 29.328054428100586, 69.3034896850586), mul = 1},
        [44] = {pos = Vector3.new(177.7988739013672, 29.328052520751953, 63.00281524658203), mul = 1},
        [45] = {pos = Vector3.new(177.7988739013672, 29.328052520751953, 46.70281219482422), mul = 1},
        [46] = {pos = Vector3.new(164.1988525390625, 29.328052520751953, 44.40281677246094), mul = 1},
        [47] = {pos = Vector3.new(50.59536361694336, 31.51506805419922, 204.40025329589844), mul = 1},
        [48] = {pos = Vector3.new(53.51300811767578, 17.31850814819336, 240.75027465820312), mul = 1},
        [49] = {pos = Vector3.new(48.7928352355957, 17.318504333496094, 247.29995727539062), mul = 1},
        [50] = {pos = Vector3.new(56.89283752441406, 17.318504333496094, 273.89996337890625), mul = 1},
        [51] = {pos = Vector3.new(41.99283981323242, 17.318504333496094, 273.89996337890625), mul = 1},
        [52] = {pos = Vector3.new(14.297271728515625, 29.32253646850586, 121.39926147460938), mul = 1},
        [53] = {pos = Vector3.new(-1.6027288436889648, 29.32253646850586, 121.39926147460938), mul = 1},
        [54] = {pos = Vector3.new(-9.602697372436523, 29.322534561157227, 114.99925994873047), mul = 1},
        [55] = {pos = Vector3.new(-17.002696990966797, 29.322534561157227, 114.99925994873047), mul = 1},
        [56] = {pos = Vector3.new(-17.802696228027344, 29.322534561157227, 55.99925994873047), mul = 1},
        [57] = {pos = Vector3.new(-38.09202194213867, 32.40471649169922, 36.55138397216797), mul = 1},
        [58] = {pos = Vector3.new(-38.613094329833984, 31.32659339904785, 10.944046020507812), mul = 1},
        [59] = {pos = Vector3.new(-38.613094329833984, 31.32659339904785, -3.0559539794921875), mul = 1},
        [60] = {pos = Vector3.new(-37.899925231933594, 44.42582321166992, 1.9007432460784912), mul = 1},
        [61] = {pos = Vector3.new(-35.78945541381836, 41.32499694824219, 27.404634475708008), mul = 1},
        [62] = {pos = Vector3.new(-7.451181411743164, 41.424991607666016, 56.890472412109375), mul = 1},
        [63] = {pos = Vector3.new(27.19883155822754, 41.32737350463867, 64.9992446899414), mul = 1},
        [64] = {pos = Vector3.new(51.399654388427734, 41.32699966430664, 37.00054168701172), mul = 1},
    }
}

af_util.conditions = {
    [3200010305] = { -- blacksite
        [af_util.checks.ItemCheck] = {"KeycardScrambler"},
        [af_util.checks.ClassCheck] = {{"hacker"}}
    },
    [2625195454] = { -- deposit
        [af_util.checks.ItemCheck] = {"Drill"},
        [af_util.checks.ClassCheck] = {{"thief", "hacker"}}
    },
    [2797881676] = { -- financier
        [af_util.checks.ArmorCheck] = {},
        [af_util.checks.WeaponCheck] = {},
    },
    [2951213182] = { -- withdrawal
        [af_util.checks.ArmorCheck] = {},
        [af_util.checks.WeaponCheck] = {},
    },
    [3590667014] = { -- lakehouse
    
    },
    [4518266946] = { -- scientist
        [af_util.checks.ArmorCheck] = {},
        [af_util.checks.WeaponCheck] = {},
    },
    [4661507759] = { -- scrs

    },
    [4768829954] = { -- black dusk

    }
}

af_util.bounds = {
    [2625195454] = { -- deposit
        [1] = {
            spots = {
                Vector3.new(211.03, 186.5, 115),
                Vector3.new(210.03, 186.5, 56),
                Vector3.new(167.03, 186.5, 56),
                Vector3.new(167.03, 186.5, 94)
            },
            region = {
                position = CFrame.new(189.53, 191.8, 85),
                size = Vector3.new(45, 11.6, 62)
            }
        }
    }
}


return af_util
