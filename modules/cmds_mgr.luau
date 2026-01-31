local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local NetworkSettings = settings():GetService("NetworkSettings")
local TeleportService = game:GetService("TeleportService")

local FogEnd = nil

local GameState = nil
local start_time = nil
local Difficulty = nil

local Loadout = ReplicatedStorage:WaitForChild("Loadout", math.huge)
local Shop = Loadout:WaitForChild("Shop", math.huge)

local LocalPlayer = Players.LocalPlayer
local PlayerData = LocalPlayer:WaitForChild("PlayerData", math.huge)
local Armory = PlayerData:WaitForChild("Armory", math.huge)
local PlayerGui = LocalPlayer.PlayerGui
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local Status = LocalPlayer:WaitForChild("Status", math.huge)
local Ammo = Status:WaitForChild("Ammo", math.huge)

local Tools = Status:WaitForChild('Tools')

local Level = nil
local Glass = nil
local Geometry = nil
local Triggers = nil
local Doors = nil
local GroundItems = nil
local GroundWeps = nil

local Flags = nil
local Armed = nil

local places = require("../modules/places")
local tools = require("../modules/tools")
local cache = require("../modules/cache")
local teleport = require("../modules/teleport")
local scr_settings = require("../modules/scr_settings")

local esp_mgr = nil
local npc_mgr = nil
local obj_mgr = nil
local ms_data = nil
local music = nil
local rmts_mgr = nil
local objassist_mgr = nil
local lobby = nil

local GetRemote = nil

if places.place_group == "mission" then
    FogEnd = Lighting.FogEnd

    local events = ReplicatedStorage:WaitForChild("Events", math.huge)
    local debug_mode = events:WaitForChild("DebugMode", math.huge)
    while debug_mode == nil or debug_mode.Parent == nil do task.wait() end
    debug_mode:Destroy()

    GameState = ReplicatedStorage:WaitForChild("GameState", math.huge)
    start_time = GameState:WaitForChild("Start", math.huge)
    Difficulty = GameState:WaitForChild("Difficulty", math.huge).Value

    Level = workspace:WaitForChild("Level", math.huge)
    Glass = Level:WaitForChild("Glass", math.huge)
    Geometry = Level:WaitForChild("Geometry", math.huge)
    Triggers = Level:WaitForChild("Triggers", math.huge)
    Doors = Geometry:WaitForChild("Doors", math.huge)
    GroundItems = Level:WaitForChild("GroundItems", math.huge)
    GroundWeps = Level:WaitForChild("GroundWeps", math.huge)

    Flags = Level:WaitForChild("Flags", math.huge):WaitForChild(LocalPlayer.Name)
    Armed = Flags:WaitForChild("Armed", math.huge)

    npc_mgr = require("../modules/npc_mgr")
    obj_mgr = require("../modules/obj_mgr")
    ms_data = require("../modules/ms_data")
    music = require("../modules/music")
    rmts_mgr = require("../modules/rmts_mgr.luau")
    objassist_mgr = require("../modules/objassist_mgr")
    esp_mgr = require("../modules/esp_mgr")

    GetRemote = rmts_mgr.GetRemote
end

if places.place_group == "lobby" then
    lobby = require("../modules/lobby")
end

local cmds_mgr = {}

cmds_mgr.flags = {
    esp = false,
    noclip = false,
    killaura = false,
    rmshields = false,
    loud = false,
    instagrab = false,
    nofog = false,
    gesp = false,
    spkill = false,
    loopws = false,
    loopjp = false,
    infjump = false,
    infammo = false,
    loopitem = false,
    loopwep = false,
    loopbag = false,
    noflash = false,
    opendoors = false,
    ctrlcheck = false,
    lag = false,
    telekinesis = false,
    snaketouch = false,
    unlockengi = false,
    strweps = false, 
    gmweps = false,
    gclearance = false,
    teamheal = false,
    tower = false,
    orbit = false,
    killboss = false,
    disarm = false,
    autofarm = false,
    unlockstash = false
}

cmds_mgr.conns = {
    loopws = nil,
    loopjp = nil,
    infjump = {},
    infammo = {},
    loopbag = nil,
    loopwep = nil,
    loopitem = nil,
    noflash = {},
    opendoors = {},
    telekinesis = nil,
    ctrlcheck = nil,
    teamheal = {}
}

local flags = cmds_mgr.flags
local conns = cmds_mgr.conns

cache.flags = flags
cache.conns = conns

cmds_mgr.IsCommandExists = function(cmd)
    for _, data in ipairs(cmds_mgr.cmds) do
        if data.name == cmd then
            return true
        end
    end

    return false
end

cmds_mgr.GetMatchedCommands = function(cmd_part)
    local matches = {}
    local exact_match = false

    for _, data in ipairs(cmds_mgr.cmds) do
        if data.name == cmd_part then
            exact_match = true
            continue
        end

        if string.find(data.name, "^"..cmd_part) then
            table.insert(matches, data.name)
        end
    end

    return matches, exact_match
end

cmds_mgr.GetCmdData = function(cmd)
    for _, data in ipairs(cmds_mgr.cmds) do
        if data.name == cmd then
            return data 
        end
    end

    return nil
end

cmds_mgr.GetCmdFlag = function(cmd)
    for command, flag in pairs(cmds_mgr.flags) do
        if cmd == command then
            return flag
        end
    end

    return nil
end

Players.PlayerDisconnecting:Connect(function(player)
    if player.Name ~= LocalPlayer.Name then return end
    NetworkSettings.IncomingReplicationLag = 0
end)

cmds_mgr.cmds = {
    {
        name = "esp",
        mode = "mission",
        desc = "esp\n\ncall: esp\ncommand type: switch, invisible, reversible\n\ndescription: allows you to see npcs, items, weapons and some mission objects through the walls.",
        usage_example = "esp",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            for _, esp in ipairs(esp_mgr.data.esps) do
                esp[esp.ClassName == "Highlight" and "Enabled" or "Visible"] = is_enabled
            end
        end
    },
    {
        name = "noclip",
        mode = "mission",
        desc = "noclip\n\ncall: noclip\ncommand type: switch, visible, reversible\n\ndescription: makes your character invisible for physical objects, what allows you to walk through them.",
        usage_example = "noclip",
        required_parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "HeadM", "Hat", "HeadCollision", "HeadCollision"},
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, ...)
            is_enabled = not is_enabled
            for _, body_part in ipairs({...}) do
                body_part.CanCollide = is_enabled
            end
        end
    },
    {
        name = "loopws",
        mode = "mission",
        desc = "loopws\n\ncall: loopws <walkspeed: number>\ncommand type: switch, visible, reversible\n\ndescription: changes your character's walk speed to the one you specified in the <walkspeed> argument. Reuse returns the default speed (16).",
        usage_example = "loopws 50\n\nloopws",
        required_parts = {"Humanoid"},
        checks = {
            args = {
                [1] = {name = "walkspeed", required = true, type = "number"},
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled, humanoid, walkspeed)
            if is_enabled then
                humanoid.WalkSpeed = tonumber(walkspeed)
                conns.loopws = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    humanoid.WalkSpeed = walkspeed
                end)
            else
                humanoid.WalkSpeed = 16
            end
        end
    },
    {
        name = "loopjp",
        mode = "mission",
        desc = "loopjp\n\ncall: loopjp <jumppower: number>\ncommand type: switch, visible, reversible\n\ndescription: changes your character's jump power to the one you specified in the <jumppower> argument. Reuse returns the default jump power (50).",
        usage_example = "loopjp 100\n\loopjp",
        required_parts = {"Humanoid"},
        checks = {
            args = {
                [1] = {name = "jumppower", required = true, type = "number"},
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled, humanoid, jumppower)
            if is_enabled == true then
                conns.loopjp = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
                    humanoid.JumpPower = jumppower
                end)
            end
        end
    },
    {
        name = "infjump",
        mode = "mission",
        desc = "infjump\n\ncall: infjump\ncommand type: switch, visible, reversible\n\ndescription: this command allows you to jump by pushing off the air, you can hold down space to fly this way. Reuse disables this feature.",
        usage_example = "infjump",
        required_parts = {"Humanoid"},
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled, humanoid)
            if is_enabled == true then
                local holding_space = false

                conns.infjump[1] = UserInputService.InputBegan:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space and UserInputService:GetFocusedTextBox() == nil then
                        holding_space = true

                        while holding_space == true and RunService.RenderStepped:Wait() do
                            humanoid:ChangeState("Jumping")
                        end
                    end
                end)

                conns.infjump[2] = UserInputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space and UserInputService:GetFocusedTextBox() == nil then
                        holding_space = false
                    end
                end)
            end
        end
    },
    {
        name = "infammo",
        mode = "mission",
        desc = "infammo\n\ncall: infammo\ncommand type: switch, visible, irreversible\n\ndescription: gives you 1000000000000000000 ammo for all ammo types except 40mm Grenade (Thumper) and disables ammo spending. Reuse turns on ammo spending, but doesn't returns ammo to default values.",
        usage_example = "infammo",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            if is_enabled == true then
                for _, ammo_type in ipairs(Ammo:GetChildren()) do
                    if ammo_type.Name == "40mm Grenade" then continue end
                    ammo_type.Value = 1000000000000000000

                    local listener = ammo_type:GetPropertyChangedSignal("Value"):Connect(function()
                        ammo_type.Value = 1000000000000000000
                    end)

                    table.insert(conns.infammo, listener)
                end
            end
        end
    },
    {
        name = "killaura",
        mode = "mission",
        desc = "killaura\n\ncall: killaura\ncommand type: switch, visible, irreversible, network ownership dependent\n\ndescription: kills every npc in the mission, automatically kills all spawning npcs. Reuse disables this feature.",
        usage_example = "killaura",
        checks = {
            args = {
                [1] = {name = "mode", required = false, type = "number", tip_gen = function(_)
                    return {"1", "2"}
                end},
            },
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, mode)
            if is_enabled == true then
                mode = tonumber(mode)
                for npc, data in pairs(npc_mgr.npcs_data.all.npcs) do
                    if mode == 2 then
                        cache.killaura_mode = 2
                        if data.team == "enemies" then
                            --task.spawn(function()
                                while data and data.humanoid and data.humanoid.Health > 0 do
                                    tools.SimulateKnifeHit(data.humanoid, data.hrp, 1000)
                                    --task.wait(0.25)
                                end
                            --end)
                        else
                            tools.SimulateKnifeHit(data.humanoid, data.hrp, 1000)
                        end
                    else
                        cache.killaura_mode = 1
                        if data.team == "snipers" then continue end
                        npc_mgr.KillNPC(npc)
                    end
                end
            else
                if mode == 2 and Armed.Value == false and tools.ClearWeaponKey ~= nil then
                    tools.ClearWeaponKey()
                end
            end
        end
    },
    {
        name = "kill",
        mode = "mission",
        desc = "kill\n\ncall: kill <npc_group: text>+\ncommand type: one time, visible, irreversible, network ownership dependent\n\ndescription: kills every npc of selected group(s).",
        usage_example = "kill w g s c\nkill a\nkill all",
        checks = {
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
            sp_allowed = false,
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(...)
            local count = 0
            for _, group in ipairs({...}) do
                if group == "sp" then continue end
                local group_npcs = npc_mgr.aliases[group]
                if group_npcs == nil then continue end
                for npc, _ in pairs(group_npcs) do
                    npc_mgr.KillNPC(npc)
                    count += 1
                end
            end
            return "kill: successfully killed "..tostring(count).." npcs."
        end 
    },
    {
        name = "bring",
        mode = "mission",
        desc = "bring\n\ncall: bring <npc_group: text>+\ncommand type: one time, visible, reversible, network ownership dependent\n\ndescription: brings every npc of selected group(s) to the position of your character.",
        usage_example = "bring w g s c\nbring a\nbring all",
        required_parts = {"HumanoidRootPart"},
        checks = {
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
            sp_allowed = false,
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(hrp, ...)
            local count = 0
            for _, group in ipairs({...}) do
                if group == "sp" then continue end
                local group_npcs = npc_mgr.aliases[group]
                if group_npcs == nil then continue end
                for npc, _ in pairs(group_npcs) do
                    npc_mgr.MoveNPC(npc, hrp.Position)
                    count += 1
                end
            end
            return "bring: successfully brought "..tostring(count).." npcs."
        end
    },
    {
        name = "hide",
        mode = "mission",
        desc = "hide\n\ncall: hide <npc_group: text>+\ncommand type: one time, visible, reversible, network ownership dependent\n\ndescription: hides every npc of selected group(s) to the place they can't get out. The place depends on the mission in which you are executing this command.",
        usage_example = "hide w g s c\nhide a\nhide all",
        checks = {
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
            sp_allowed = false,
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(...)
            local count = 0
            for _, group in ipairs({...}) do
                if group == "sp" then continue end
                local group_npcs = npc_mgr.aliases[group]
                if group_npcs == nil then continue end
                for npc, _ in pairs(group_npcs) do
                    npc_mgr.HideNPC(npc)
                    count += 1
                end
            end
            return "hide: successfully hid "..tostring(count).." npcs."
        end
    },
    {
        name = "void",
        mode = "mission",
        desc = "void\n\ncall: void <npc_group: text>+\ncommand type: one time, visible, irreversible, network ownership dependent\n\ndescription: throws every npc of selected group(s) to the void. This command can be used to kill npcs without losing the \"no kills\" bonus.",
        usage_example = "hide w g s c\nhide a\nhide all",
        checks = {
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
            sp_allowed = false,
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(...)
            local count = 0
            for _, group in ipairs({...}) do
                if group == "sp" then continue end
                local group_npcs = npc_mgr.aliases[group]
                if group_npcs == nil then continue end
                for npc, data in pairs(group_npcs) do
                    npc_mgr.MoveNPC(npc, Vector3.new(data.hrp.Position.X, -2.5e6, data.hrp.Position.Z))
                    count += 1
                end
            end
            return "void: successfully threw to the void "..tostring(count).." npcs."
        end
    },
    {
        name = "raykill",
        mode = "mission",
        desc = "raykill\n\ncall: raykill\ncommand type: one time, visible, irreversible, network ownership dependent\n\ndescription: kills the npc that the center of your screen is pointing at.",
        usage_example = "raykill",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            local npc = npc_mgr.GetNPCOnRay()
            if not npc then return end

            local data = npc_mgr.npcs_data.all.npcs[npc]
            if data.team == "snipers" then return end

            npc_mgr.KillNPC(npc)
        end
    },
    {
        name = "raybring",
        mode = "mission",
        desc = "raybring\n\ncall: raybring\ncommand type: one time, visible, reversible, network ownership dependent\n\ndescription: brings the npc that the center of your screen is pointing at to the position of your character.",
        usage_example = "raybring",
        required_parts = {"HumanoidRootPart"},
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(hrp)
            local npc = npc_mgr.GetNPCOnRay()
            if not npc then return end
            
            local data = npc_mgr.npcs_data.all.npcs[npc]
            if data.team == "snipers" then return end

            npc_mgr.MoveNPC(npc, hrp.Position)
        end
    },
    {
        name = "rayhide",
        mode = "mission",
        desc = "rayhide\n\ncall: rayhide\ncommand type: one time, visible, reversible, network ownership dependent\n\ndescription: hides the npc that the center of your screen is pointing at to the place it can't get out. The place depends on the mission in which you are executing this command.",
        usage_example = "rayhide",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            local npc = npc_mgr.GetNPCOnRay()
            if not npc then return end

            local data = npc_mgr.npcs_data.all.npcs[npc]
            if data.team == "snipers" then return end

            npc_mgr.HideNPC(npc)
        end
    },
    {
        name = "rayvoid",
        mode = "mission",
        desc = "rayvoid\n\ncall: rayvoid\ncommand type: one time, visible, irreversible, network ownership dependent\n\ndescription: throws to the void the npc that the center of your screen is pointing at.",
        usage_example = "rayvoid",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            local npc = npc_mgr.GetNPCOnRay()
            if not npc then return end
            
            local data = npc_mgr.npcs_data.all.npcs[npc]
            if data.team == "snipers" then return end

            npc_mgr.MoveNPC(npc, Vector3.new(data.hrp.Position.X, -2.5e6, data.hrp.Position.Z))
        end
    },
    {
        name = "loopitem",
        mode = "mission",
        desc = "loopitem\n\ncall: loopitem\ncommand type: switch, visible, reversible, network ownership dependent\n\ndescription: sticks all not frozen item to your character. Reuse disables this feature.",
        usage_example = "loopitem",
        required_parts = {"HumanoidRootPart"},
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, hrp)
            if is_enabled == true then
                conns.loopitem = RunService.RenderStepped:Connect(function()
                    for _, data in pairs(obj_mgr.items) do
                        data.align_p.Position = hrp.Position
                    end
                end)
            end

            for obj, data in pairs(obj_mgr.items) do
                if data.base.Anchored == true then continue end
                obj_mgr.NoclipOBJ(obj, not is_enabled)
                data.align_o.Enabled = is_enabled
                data.align_p.Enabled = is_enabled
            end
        end
    },
    {
        name = "loopwep",
        mode = "mission",
        desc = "loopwep\n\ncall: loopwep\ncommand type: switch, visible, reversible, network ownership dependent\n\ndescription: sticks all not frozen weapons to your character. Reuse disables this feature.",
        usage_example = "loopwep",
        required_parts = {"HumanoidRootPart"},
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, hrp)
            if is_enabled == true then
                conns.loopwep = RunService.RenderStepped:Connect(function()
                    for _, data in pairs(obj_mgr.weapons) do
                        data.align_p.Position = hrp.Position
                    end
                end)
            end

            for obj, data in pairs(obj_mgr.weapons) do
                if data.base.Anchored == true then continue end
                obj_mgr.NoclipOBJ(obj, not is_enabled)
                data.align_o.Enabled = is_enabled
                data.align_p.Enabled = is_enabled
            end
        end
    },
    {
        name = "loopbag",
        mode = "mission",
        desc = "loopbag\n\ncall: loopbag\ncommand type: switch, visible, reversible, network ownership dependent\n\ndescription: sticks all not frozen bags to your character. Reuse disables this feature.",
        usage_example = "loopbag",
        required_parts = {"HumanoidRootPart"},
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, hrp)
            if is_enabled == true then
                conns.loopbag = RunService.RenderStepped:Connect(function()
                    for _, data in pairs(obj_mgr.bags) do
                        data.align_p.Position = hrp.Position
                    end
                end)
            end

            for obj, data in pairs(obj_mgr.bags) do
                if data.base.Anchored == true then continue end
                obj_mgr.NoclipOBJ(obj, not is_enabled)
                data.align_o.Enabled = is_enabled
                data.align_p.Enabled = is_enabled
            end
        end
    },
    {
        name = "rmshields",
        mode = "mission",
        desc = "rmshields\n\ncall: rmshields\ncommand type: switch, invisible, reversible\n\ndescription: removes the shields of enemies and all spawning enemies. Reuse doesn't returns back the shields of spawned enemies, but stops removing shileds of spawning enemies.",
        usage_example = "rmshields",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            if is_enabled then
                for npc, _ in pairs(npc_mgr.npcs_data.enemies.npcs) do
                    task.spawn(function()
                        local shield = npc:WaitForChild("S97Shield", 3)
                        if shield == nil then return end
                        shield:Destroy()
                    end)
                end
            end
        end
    },
    {
        name = "noflash",
        mode = "mission",
        desc = "noflash\n\ncall: noflash\ncommand type: switch, invisible, reversible\n\ndescription: removes the temporary blindness effect of exploding flashbangs. Reuse disables this feature.",
        usage_example = "noflash",
        required_parts = {"Humanoid"},
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled, humanoid)
            local flashbang = PlayerGui:WaitForChild("Weapons", math.huge):WaitForChild("WeaponGui", math.huge):WaitForChild("Flashbang", math.huge)
            tools.WaitForChildWithIndex(Camera, 4)
            if is_enabled == true then
                flashbang.Visible = false

                Camera = workspace.CurrentCamera

                tools.ChildCounter(4, Camera, function(effect)
                    if not table.find({"Blur", "ColorCorrection"}, effect.Name) then return false end
                    
                    effect.Enabled = false
                    local listener = effect:GetPropertyChangedSignal("Enabled"):Connect(function()
                        effect.Enabled = false
                    end)

                    table.insert(conns.noflash, listener)

                    return true
                end)

                local death_listener = humanoid.HealthChanged:Connect(function(health)
                    if tostring(health) == "nan" then return end

                    if health <= 0 then
                        flashbang.Visible = true

                        tools.ChildCounter(4, Camera, function(effect)
                            if not table.find({"Blur", "ColorCorrection"}, effect.Name) then return false end
                            
                            effect.Enabled = true

                            return true
                        end)
                    end
                end)

                table.insert(conns.noflash, death_listener)
            else
                flashbang.Visible = true

                tools.ChildCounter(4, Camera, function(effect)
                    if not table.find({"Blur", "ColorCorrection"}, effect.Name) then return false end
                    
                    effect.Enabled = true

                    return true
                end)
            end
        end
    },
    {
        name = "killboss",
        mode = "mission",
        desc = "killboss\n\ncall: killboss\ncommand type: one time, visible, irreversible\n\ndescription: deals a huge damage to the boss (SWAT vans, helicopters, Onyx Unit) as soon as it spawns. ",
        usage_example = "killboss",
        checks = {
            boss_required = true, 
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            if is_enabled == true then
                cache.complex_cmds.killboss = tools.CreatePendingTask(ms_data.current.kill_boss)
            else
                tools.ClearTableTask(cache.complex_cmds, "killboss")
            end
        end
    },
    {
        name = "godmode",
        mode = "mission",
        desc = "godmode\n\ncall: godmode <teammate_name: text>?+\ncommand type: one time, visible, reversible\n\ndescription: gives the full immunity to any type and strength of damage to teammate(s). To remove godmode from their character, they must use medkit. They must also use the medkit before completing the mission, otherwise the game will count this as their death.",
        usage_example = "godmode averydumbcheese\ngodmode",
        requires_char = true,
        checks = {
            args = {
                [1] = {name = "teammate_name", required = false, type = "text", multiple = true, tip_gen = function(_)
                    local names = {}

                    for _, player in ipairs(Players:GetChildren()) do
                        if player.Name == LocalPlayer.Name then continue end
                        table.insert(names, player.Name)
                    end

                    return names
                end}
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(_, ...)
            if not ReplicatedStorage:FindFirstChild("FriendlyFire") then
                return "godmode works only in Elite+ missions."
            end

            local teammate_names = {...}
            if #teammate_names ~= 0 then
                for index, name in ipairs(teammate_names) do
                    teammate_names[index] = tools.PlayerDataByName(name)
                end
            else
                teammate_names = obj_mgr.players
            end

            for player, data in pairs(teammate_names) do
                if player == LocalPlayer or data.head_collision == nil then continue end

                while cache.shoot_cooldown == true do
                    task.wait()
                end

                cache.shoot_cooldown = true
                if getsenv ~= nil and clonefunction ~= nil then
                    tools.SimulateKnifeHit(data.humanoid, data.head_collision, 0/0)
                else
                    tools.SimulateShoot(data.head_collision, 0/0)
                end
                cache.shoot_cooldown = false
            end
        end
    },
    {
        name = "teamkill",
        mode = "mission",
        desc = "teamkill\n\ncall: teamkill <teammate_name: text>?+\ncommand type: one time, visible, irreversible\n\ndescription: instantly kills your teammate(s).",
        usage_example = "teamkill averydumbcheese\nteamkill",
        requires_char = true,
        checks = {
            args = {
                [1] = {name = "teammate_name", required = false, type = "text", multiple = true, tip_gen = function(_)
                    local names = {}

                    for _, player in ipairs(Players:GetChildren()) do
                        if player.Name == LocalPlayer.Name then continue end
                        table.insert(names, player.Name)
                    end

                    return names
                end}
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(_, ...)
            if not ReplicatedStorage:FindFirstChild("FriendlyFire") then 
                return "teamkill works only on Elite+ missions."
            end

            local teammate_names = {...}
            if #teammate_names ~= 0 then
                for index, name in ipairs(teammate_names) do
                    teammate_names[index] = tools.PlayerDataByName(name)
                end
            else
                teammate_names = obj_mgr.players
            end

            for player, data in pairs(teammate_names) do
                if player == LocalPlayer or data.head_collision == nil then continue end

                while cache.shoot_cooldown == true do
                    task.wait()
                end

                cache.shoot_cooldown = true
                while data.humanoid.Health > 0 and task.wait() do
                    if getsenv ~= nil and clonefunction ~= nil then
                        tools.SimulateKnifeHit(data.humanoid, data.head_collision, 1000)
                        task.wait(0.05)
                    else
                        tools.SimulateShoot(data.head_collision, 1000)
                    end
                end
                cache.shoot_cooldown = false
            end
        end
    },
    {
        name = "teamheal",
        mode = "mission",
        desc = "teamheal\n\ncall: teamheal <teammate_name: text>?+\ncommand type: switch, visible, reversible\n\ndescription: constantly fully heals your teammate(s). Reuse disables this feature.",
        usage_example = "teamheal averydumbcheese\nteamheal",
        requires_char = true,
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            --if not ReplicatedStorage:FindFirstChild("FriendlyFire") then return end
            cache.weaponkey_cmds.teamheal = is_enabled
            
            if is_enabled == true then
                local teammate_names = obj_mgr.players

                while is_enabled == true and RunService.RenderStepped:Wait() do
                    for player, data in pairs(teammate_names) do
                        if data.humanoid == nil or data.head_collision == nil then continue end

                        local damage = tools.CalculateDamage(data, player)
                        damage = -damage

                        if damage > -0.1 then continue end

                        if getsenv ~= nil and clonefunction ~= nil then
                            tools.SimulateKnifeHit(data.humanoid, data.head_collision, damage)
                        else
                            tools.SimulateShoot(data.head_collision, damage)
                        end
                    end

                    task.wait(tools.GetPing() + 0.15)
                end
            end
        end
    },
    {
        name = "opendoors",
        mode = "mission",
        desc = "opendoors\n\ncall: opendoors\ncommand type: switch, visible, reversible\n\ndescription: unlocks all doors, allowing you to open them without using any tools. This command also unlocks basement door in Lakehouse and fire door at spawn in Withdrawal. Reuse locks all unlocked doors.",
        usage_example = "opendoors",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled)
            if ms_data.current.get_door_unlocker then
                local unlocker = ms_data.current.get_door_unlocker()
                unlocker.Value = is_enabled
            end

            if is_enabled == true then
                for LockDir, _ in pairs(obj_mgr.lock_dirs) do
                    LockDir.Value = 0

                    local listener; listener = LockDir:GetPropertyChangedSignal("Value"):Connect(function()
                        LockDir.Value = 0
                    end)

                    table.insert(conns.opendoors, listener)
                end 
            else
                for LockDir, OrigValue in pairs(obj_mgr.lock_dirs) do
                    LockDir.Value = OrigValue
                end
            end
        end
    },
    {
        name = "loud",
        mode = "mission",
        desc = "loud\n\ncall: loud\ncommand type: switch, visible, reversible\n\ndescription: throws all enemies and all spawning enemies to the space, what means the next wave won't start for a very long time. Reuse disables this feature, but doesn't returns enemies from the space if there's any.",
        usage_example = "loud",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            if is_enabled == true then
                for npc, _ in pairs(npc_mgr.npcs_data.enemies.npcs) do
                    npc_mgr.MoveNPC(npc, Vector3.new(1e12, 1e12, 1e12))
                end
            end
        end
    },
    {
        name = "metdetect",
        mode = "mission",
        desc = "metdetect\n\ncall: metdetect\ncommand type: one time, visible, irreversible\n\ndescription: allows you to pass through metal detectors with weapons.",
        usage_example = "metdetect",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function()
            for _, obj in ipairs(Glass:GetChildren()) do
                if table.find({"MetalDetectorPart1", "MetalDetectorPart2", "MetalDetectorPart3"}, obj.Name) then
                    obj:Destroy() 
                end
            end

            for _, trigger in ipairs(Triggers:GetChildren()) do
                if trigger.Name == "Detector" then
                    trigger:Destroy()
                end
            end

            return "metdetect: removed metal detectors triggers."
        end
    },
    {
        name = "objassist",
        mode = "mission",
        desc = "objassist\n\ncall: objassist\ncommand type: one time, invisible, irreversible, can be executed only before mission start\n\ndescription: changes the position and properties of objects in such a way as to speed up and facilitate the passage of the mission.",
        usage_example = "objassist",
        requires_char = true,
        checks = {
            before_mission_start = true,
            objassist_required = true,
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            if objassist_mgr[game.PlaceId] then
                task.spawn(objassist_mgr[game.PlaceId])
                return "objassist: initializing objective assistance..."
            end
        end
    },
    {
        name = "telekinesis",
        mode = "mission",
        desc = "telekinesis\n\ncall: telekinesis\ncommand type: switch, visible, reversible\n\ndescription: allows you to carry and throw npcs.\nControls:\n\tRight mouse button hold: starts holding the npc that the center of your screen is pointing at\n\tF key: throw npc that you're holding\n\tT key: change the collision of npc you're holding. Reuse disables this feature.",
        usage_example = "telekinesis",
        required_parts = {"HumanoidRootPart"},
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, hrp)
            if is_enabled == true then
                local holding = false

                conns.telekinesis = Mouse.Button2Down:Connect(function()
                    local npc = npc_mgr.GetNPCOnRay()
                    if not npc then return end
                    local data = npc_mgr.npcs_data.all.npcs[npc]
                    if data.team == "snipers" then return end

                    local distance = (data.hrp.Position - hrp.Position).Magnitude
                    local thrown = false
                    local can_collide = true

                    local wheel_forward = Mouse.WheelForward:Connect(function()
                        distance += 2
                    end)

                    local wheel_backward = Mouse.WheelBackward:Connect(function()
                        distance = distance < 2 and 0 or distance - 2
                    end)

                    local input_began = UserInputService.InputBegan:Connect(function(input)
                        if UserInputService:GetFocusedTextBox() == nil then
                            if input.KeyCode == Enum.KeyCode.F then
                                thrown = true
                            elseif input.KeyCode == Enum.KeyCode.T then
                                can_collide = not can_collide
                                npc_mgr.NoclipNPC(data, can_collide)
                            end
                        end
                    end)

                    local input_ended = Mouse.Button2Up:Connect(function()
                        holding = false
                    end)

                    data.align_p.Enabled = true
                    data.align_o.Enabled = false

                    while data.anti_fall == nil do task.wait() end
                    data.anti_fall:Disconnect()
                    data.anti_fall = nil

                    holding = true

                    while holding == true and thrown == false and RunService.RenderStepped:Wait() do
                        data.align_p.Position = Mouse.Origin.Position + (Camera.CFrame.LookVector * distance)
                    end

                    wheel_backward:Disconnect()
                    wheel_forward:Disconnect()
                    input_began:Disconnect()
                    input_ended:Disconnect()

                    data.align_p.Enabled = false
                    data.align_o.Enabled = false

                    npc_mgr.NoclipNPC(data, true)

                    if thrown == true then
                        data.hrp:ApplyImpulse(Mouse.Hit.LookVector * 7500)
                        
                        while data.humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown do
                            data.humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
                            task.wait(0.1)
                        end

                        local got_up = false

                        local listener = data.humanoid.GettingUp:Connect(function()
                            got_up = true
                        end)

                        while got_up == false and holding == false do task.wait() end
                        listener:Disconnect()
                    end

                    data.anti_fall = data.humanoid.FallingDown:Connect(function()
                        data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end)
                end)
            end
        end
    },
    {
        name = "getitem",
        mode = "mission",
        desc = "getitem\n\ncall: getitem <item_name: text> <quantity: number>?\ncommand type: one time, visible, reversible\n\ndescription: pickups the selected item at any distance from it. If <quantity> wasn't specified, pickups 1 item by default.",
        usage_example = "getitem usb\ngetitem thermitecan 2",
        requires_char = true,
        checks = {
            args = {
                [1] = {name = "item_name", required = true, type = "text", tip_gen = function(_)
                    local items = {}

                    for _, item in ipairs(GroundItems:GetChildren()) do
                        table.insert(items, string.lower(item.Name))
                    end

                    return items
                end},
                [2] = {name = "quantity", required = false, type = "number"},
            },
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(_, item_name, quantity)
            local count = 0
            item_name = string.lower(item_name)
            quantity = quantity == nil and 1 or tonumber(quantity)

            for item, _ in pairs(obj_mgr.items) do
                if string.lower(item.Name) ~= item_name then continue end
                local data = item:FindFirstChild("Data")
                if data == nil then continue end

                GetRemote("TryPickup"):Invoke(data)
                quantity -= 1
                count += 1
                if quantity == 0 then return end
            end

            return "getitem: successfully got "..tostring(count)..item_name.."(s)"
        end
    },
    {
        name = "instagrab",
        mode = "mission",
        desc = "instagrab\n\ncall: instagrab\ncommand type: one time, visible, reversible\n\ndescription: changes the time of picking up some objects like cash, gold or servers to 0. Reuse returns these values to their default ones.",
        usage_example = "instagrab",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled)
            if ms_data.current.instagrab then
                ms_data.current.instagrab(is_enabled)
            end
        end
    },
    {
        name = "breakback",
        mode = "mission",
        desc = "breakback\n\ncall: breakback <force: number>\ncommand type: one time, visible, reversible\n\ndescription: breaks your back with the specified force.",
        usage_example = "breakback 20",
        requires_char = true,
        checks = {
            args = {
                [1] = {name = "force", required = true, type = "number"}
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(_, force)
            GetRemote("SetLean"):Fire(tonumber(force))
        end
    },
    {
        name = "breakshoulders",
        mode = "mission",
        desc = "breakshoulders\n\ncall: breakshoulders <force: number>\ncommand type: one time, visible, reversible\n\ndescription: breaks your shoulders with the specified force.",
        usage_example = "breakshoulders 20",
        requires_char = true,
        checks = {
            args = {
                [1] = {name = "force", required = true, type = "number"}
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(_, force)
            GetRemote("SetShoulders"):Fire(tonumber(force), 0.17)
        end
    },
    {
        name = "breakarms",
        mode = "mission",
        desc = "breakarms\n\ncall: breakarms <mode: number (1 or 2)> <force: number>\ncommand type: one time, visible, reversible\n\ndescription: breaks your arms with the specified mode and force.",
        usage_example = "breakarms 1 20\nbreakarms 2 20",
        requires_char = true,
        checks = {
            args = {
                [1] = {name = "mode", required = true, type = "number", tip_gen = function(_)
                    return {"1", "2"}
                end},
                [2] = {name = "power", required = true, type = "number"},
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(_, mode, force)
            mode = tonumber(mode)

            if mode == 1 then
                GetRemote("SetAnim"):Fire("HipPosition", 1, tonumber(force), 0.15)
            elseif mode == 2 then
                GetRemote("SetWeight"):Fire(tonumber(force), 0.15)
            end
        end
    },
    {
        name = "nofog",
        mode = "mission",
        desc = "nofog\n\ncall: nofog\ncommand type: one time, invisible, reversible\n\ndescription: removes fog. Reuse returns back the fog.",
        usage_example = "nofog",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            Lighting.FogEnd = is_enabled == true and 1e5 or FogEnd
        end
    },
    {
        name = "facecam",
        mode = "mission",
        desc = "facecam\n\ncall: facecam\ncommand type: one time, visible, reversible\n\ndescription: places the microcam to the position and rotation of your head, if you have one in your inventory.",
        usage_example = "facecam",
        required_parts = {"HeadM"},
        checks = {
            required_funcs = {getsenv},
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(head_m)
            local microcam = Tools:FindFirstChild("Microcam", true)
            if not microcam then return "facecam: you need a microcam in your inventory for this command to work." end

            local pos = Camera.CFrame.Position + Camera.CFrame.LookVector * 1.5
            GetRemote("PlaceExplosive"):InvokeServer("Microcam", CFrame.new(pos, pos + Camera.CFrame.LookVector) * CFrame.Angles(math.rad(-90), 0, 0), head_m, microcam)
        end
    },
    {
        name = "free",
        mode = "mission",
        desc = "free\n\ncall: free\ncommand type: one time, visible, reversible\n\ndescription: stops all physic operations performed on npcs, items, bags and weapons.",
        usage_example = "free",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            local count = 0

            for _, group in ipairs({npc_mgr.npcs_data.all.npcs, obj_mgr.bags, obj_mgr.items, obj_mgr.weapons}) do
                for _, data in pairs(group) do
                    data.align_p.Enabled = false
                    data.align_o.Enabled = false
                    count += 1
                end
            end

            for _, cmd in ipairs({"loopwep", "loopbag", "loopitem"}) do
                if conns[cmd] ~= nil then
                    cache.ValidateCommand(cmd, "terminal")
                end
            end

            return "free: stopped physical operations performed on weapons, bags, items and "..tostring(count).." npcs."
        end
    },
    {
        name = "hiddenui",
        mode = "mission",
        desc = "hiddenui\n\ncall: hiddenui\ncommand type: one time, invisible, irreversible\n\ndescription: cancels all changes that occur due to the \"hidden ui\" challenge.",
        usage_example = "hiddenui",
        requires_char = true,
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function()
            --[[for _, gui in ipairs({"CharModel", "Objectives", "MainPlayer"}) do
                WeaponGui:WaitForChild(gui, math.huge).Visible = true
            end

            WeaponGui:WaitForChild("Clock", math.huge).TextTransparency = 0

            PlayerWeapons:WaitForChild("TeamGui", math.huge):WaitForChild("Team", math.huge).Visible = false]]--

            return "not implemented"
        end
    },
    {
        name = "gesp",
        mode = "mission",
        desc = "gesp\n\ncall: gesp <npc_group: text>+\ncommand type: switch, visible, reversible\n\ndescription: pings all npcs of selected npc group(s). Reuse disables this feature.",
        usage_example = "gesp all\ngesp g s",
        checks = {
            required_funcs = {getsenv},
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a", "sp"}
                end}
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled, ...)
            while flags.gesp == true do
                for _, group in ipairs({...}) do
                    local group_npcs = npc_mgr.aliases[group]
                    if group_npcs == nil then continue end
                    for npc, _ in pairs(group_npcs) do
                        GetRemote("SpotEnemy"):FireServer(npc)
                    end
                end

                task.wait(0.5)
            end
        end
    },
    {
        name = "ctrlcheck",
        mode = "mission",
        desc = "ctrlcheck\n\ncall: ctrlcheck\ncommand type: switch, invisible, reversible\n\ndescription: releases red rays to the npcs you can't control at the moment. Reuse disables this feature.",
        usage_example = "ctrlcheck",
        required_parts = {"HumanoidRootPart"},
        checks = {
            required_funcs = {isnetworkowner},
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled, hrp)
            if is_enabled == true then
                hrp:WaitForChild("Attachment", math.huge)

                conns.ctrlcheck = RunService.RenderStepped:Connect(function()
                    for _, data in pairs(npc_mgr.npcs_data.all.npcs) do
                        if data.team == "snipers" then continue end
                        data.beam.Enabled = not isnetworkowner(data.hrp)
                    end
                end)
            else
                for _, data in pairs(npc_mgr.npcs_data.all.npcs) do
                    if data.team == "snipers" then continue end
                    data.beam.Enabled = false
                end
            end
        end
    },
    {
        name = "buyweapon",
        mode = "mission",
        desc = "buyweapon\n\ncall: buyweapon <weapon_name: text>\ncommand type: one time, visible, irreversible\n\ndescription: buys the selected weapon.",
        usage_example = "buyweapon raven\nbuyweapon Thumper",
        checks = {
            args = {
                [1] = {name = "weapon_name", required = true, type = "text", tip_gen = function(_)
                    return {"480_MCS", "CBR-C", "CH-A", "F57", "K45", "MM20", "Raven", "S97", "Sawblade", "Thumper", "UP9"}
                end}
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(weapon_name)
            weapon_name = string.lower(weapon_name)
            weapon_name = string.gsub(weapon_name, "_", " ")

            for _, weapon in ipairs(Shop:GetChildren()) do
                if string.lower(weapon.Name) == weapon_name then
                    GetRemote("BuyWeapon"):InvokeServer(weapon)
                    break
                end
            end
        end
    },
    {
        name = "buyattachment",
        mode = "mission", -- "weapon_slot: num att_group: txt att_name: txt"
        desc = "buyattachment\n\ncall: buyattachment <weapon_slot: number> <att_group: text> <att_name: text>\ncommand type: one time, visible, irreversible\n\ndescription: buys and sets the attachment of the specified attachment name in the attachment group to the specified weapon from the \"Manage Weapons\" panel. You can also buy attachments that cannot be placed on specific weapons like suppressor for Thumper or Sawblade. ",
        usage_example = "buyattachment 2 Tactical Canted Sights\nbuyattachment 5 Barrel Suppressor",
        checks = {
            args = {
                [1] = {name = "weapon_pos", required = true, type = "number", tip_gen = function(_)
                    if not LocalPlayer:FindFirstChild("PlayerData") or not LocalPlayer.PlayerData:FindFirstChild("Armory") then return nil end

                    local weapons = {}

                    for _, weapon in ipairs(LocalPlayer.PlayerData.Armory:GetChildren()) do
                        if weapon:FindFirstChild("Mods") == nil then continue end
                        table.insert(
                            weapons,
                            string.match(weapon.Name, "%d+").." ("..weapon.Value..")"
                        )
                    end

                    return weapons
                end},
                [2] = {name = "att_group", required = true, type = "text", tip_gen = function(_)
                    return {"Sight", "Barrel", "Tactical", "Grip", "Magazine", "Stock", "Frame"}
                end},
                [3] = {name = "att_name", required = true, type = "text", tip_gen = function(args)
                    local group = args[2]
                    
                    local attachments = {
                        ["Sight"] = {"Iron_Sights", "Mini_Sight", "Delta_Sight", "Glow_Sight", "Ring_Sight", "Red_Dot", "TG3X", "T4XS", "LS6X"},
                        ["Barrel"] = {"Suppressor", "Flash Hider", "Muzzle Brake", "Duckbill", "Choke"},
                        ["Tactical"] = {"Flashlight", "Laser", "Canted_Sights"},
                        ["Grip"] = {"Folding_Grip", "Ergo_Grip", "Angled_Grip", "Stubby_Grip"},
                        ["Magazine"] = {"Normal Magazine", "Short Magazine"},
                        ["Stock"] = {"Normal_Stock", "Short_Grip", "No_Stock", "Full_Stock", "Stock"},
                        ["Frame"] = {"Chrome", "Matte", "Steel", "Gold", "Split_Gold"}
                    }
                    
                    return attachments[group]
                end},
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(weapon_slot, att_group, att_name)
            att_name = string.gsub(att_name, "_", " ")

            local slot = Armory:WaitForChild("Slot"..weapon_slot, 5)
            if not slot then
                
            end

            local internal_str = att_group.."_"..att_name.."|"

            GetRemote("BuyAttachment"):InvokeServer(slot, internal_str)
        end
    },
    {
        name = "setattachment",
        mode = "mission",
        desc = "setattachment\n\ncall: setattachment <weapon_slot: number> <att_group: text> <att_name: text>\ncommand type: one time, visible, irreversible\n\ndescription: sets the attachment of the specified attachment name in the attachment group to the specified weapon from the \"Manage Weapons\" panel.",
        usage_example = "setattachment 2 Tactical Canted Sights\nsetattachment 5 Barrel Suppressor",
        checks = {
            args = {
                [1] = {name = "weapon_pos", required = true, type = "number", tip_gen = function(_)
                    if not LocalPlayer:FindFirstChild("PlayerData") or not LocalPlayer.PlayerData:FindFirstChild("Armory") then return nil end

                    local weapons = {}

                    for _, weapon in ipairs(LocalPlayer.PlayerData.Armory:GetChildren()) do
                        if weapon:FindFirstChild("Mods") == nil then continue end
                        table.insert(
                            weapons,
                            string.match(weapon.Name, "%d+").." ("..weapon.Value..")"
                        )
                    end

                    return weapons
                end},
                [2] = {name = "att_group", required = true, type = "text", tip_gen = function(_)
                    return {"Sight", "Barrel", "Tactical", "Grip", "Magazine", "Stock", "Frame"}
                end},
                [3] = {name = "att_name", required = true, type = "text", tip_gen = function(args)
                    local group = args[2]
                    
                    local attachments = {
                        ["Sight"] = {"Iron_Sights", "Mini_Sight", "Delta_Sight", "Glow_Sight", "Ring_Sight", "Red_Dot", "TG3X", "T4XS", "LS6X"},
                        ["Barrel"] = {"Suppressor", "Flash Hider", "Muzzle Brake", "Duckbill", "Choke"},
                        ["Tactical"] = {"Flashlight", "Laser", "Canted_Sights"},
                        ["Grip"] = {"Folding_Grip", "Ergo_Grip", "Angled_Grip", "Stubby_Grip"},
                        ["Magazine"] = {"Normal Magazine", "Short Magazine"},
                        ["Stock"] = {"Normal_Stock", "Short_Grip", "No_Stock", "Full_Stock", "Stock"},
                        ["Frame"] = {"Chrome", "Matte", "Steel", "Gold", "Split_Gold"}
                    }
                    
                    return attachments[group]
                end},
            },
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(weapon_slot, att_group, att_name)
            att_name = string.gsub(att_name, "_", " ")

            local slot = Armory:WaitForChild("Slot"..weapon_slot, 5)
            if not slot then
                
            end

            local internal_str = att_group.."_"..att_name.."|"

            GetRemote("SetAttachment"):InvokeServer(slot, internal_str)
        end
    },
    {
        name = "tower",
        required_parts = {"HumanoidRootPart"},
        desc = "tower\n\ncall: tower <npc_group: text>+\ncommand type: switch, visible, reversible, network ownership dependent\n\ndescription: builds a tower made of npcs of the specified group(s) on your head. Works only with npcs who aren't sitting at the moment. Reuse disables this feature.",
        usage_example = "tower g s c\ntower",
        checks = {
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
            sp_allowed = false,
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, hrp, ...)
            if is_enabled == true then
                if flags.orbit == true then
                    cache.ValidateCommand("orbit", "terminal")
                end

                local height = 8
                for _, group in ipairs({...}) do
                    local group_npcs = npc_mgr.aliases[group]
                    if group_npcs == nil then continue end
                    for npc, data in pairs(group_npcs) do
                        if data.humanoid.Sit == true then continue end

                        npc_mgr.NoclipNPC(data, false)
                        data.align_p.Enabled = true
                        data.align_o.Enabled = true

                        cache.npcs_in_tower[npc] = height
                        height += 4
                    end
                end

                while flags.tower == true and RunService.RenderStepped:Wait() do
                    for npc, curr_height in pairs(cache.npcs_in_tower) do
                        local data = npc_mgr.npcs_data.all.npcs[npc]
                        if not data or not data.align_p then continue end
                        data.align_p.Position = hrp.Position + Vector3.new(0, curr_height, 0)
                    end
                end
            else
                for npc, _ in pairs(cache.npcs_in_tower) do
                    local data = npc_mgr.npcs_data.all.npcs[npc]
                    if not data or not data.align_p or not data.align_o then continue end

                    npc_mgr.NoclipNPC(data, true)

                    data.align_p.Enabled = false
                    data.align_o.Enabled = false

                    cache.npcs_in_tower = {}
                end
            end
        end
    },
    {
        name = "orbit",
        required_parts = {"HumanoidRootPart"},
        desc = "orbit\n\ncall: orbit <npc_group: text>+\ncommand type: switch, visible, reversible, network ownership dependent\n\ndescription: creates an orbit made of npcs of the specified group(s) with a specified rotation speed and radius (distance) around your character. Works only with npcs who aren't sitting at the moment. Reuse disables this feature.",
        usage_example = "orbit 20 10 a e w\norbit 0 20 e",
        checks = {
            sp_allowed = false,
            args = {
                [1] = {name = "speed", required = true, type = "number"},
                [2] = {name = "distance", required = true, type = "number"},
                [3] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled, hrp, speed, distance, ...)
            if is_enabled == true then
                if flags.tower == true then
                    cache.ValidateCommand("tower", "terminal")
                end
                local rotation = 0
                speed = tonumber(speed)
                distance = tonumber(distance)

                for _, group in ipairs({...}) do
                    local group_npcs = npc_mgr.aliases[group]
                    if group_npcs == nil then continue end
                    for npc, data in pairs(group_npcs) do
                        if data.humanoid.Sit == true then continue end

                        npc_mgr.NoclipNPC(data, false)
                        data.align_p.Enabled = true
                        data.align_o.Enabled = true

                        cache.npcs_in_orbit[npc] = 0
                    end
                end

                local count = tools.GetDictLen(cache.npcs_in_orbit)
                local delta = 360 / count

                for npc, _ in pairs(cache.npcs_in_orbit) do
                    cache.npcs_in_orbit[npc] += rotation
                    rotation += delta
                end

                while flags.orbit == true and RunService.RenderStepped:Wait() do
                    for npc, curr_rotation in pairs(cache.npcs_in_orbit) do
                        local data = npc_mgr.npcs_data.all.npcs[npc]
                        if not data or not data.align_p or not data.align_o then continue end
     
                        data.align_p.Position = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(curr_rotation), 0) * CFrame.new(distance, 0, 0).Position
                        data.align_o.CFrame = CFrame.new(hrp.Position, data.hrp.Position) 
                        cache.npcs_in_orbit[npc] += speed
                    end
                end
            else
                for npc, _ in pairs(cache.npcs_in_orbit) do
                    local data = npc_mgr.npcs_data.all.npcs[npc]
                    if not data or not data.align_p or not data.align_o then continue end

                    npc_mgr.NoclipNPC(data, true)

                    data.align_p.Enabled = false
                    data.align_o.Enabled = false

                    cache.npcs_in_orbit = {}
                end
            end
        end
    },
    {
        name = "snake",
        mode = "mission",
        desc = "snake\n\ncall: snake <npc_group: text>+\ncommand type: one time, visible, irreversible\n\ndescription: puts npcs of the specified group(s) on the ground. They still will be able to move around in this position. This command may take some time to turn all specified npcs to snakes",
        usage_example = "snake w g s c\nsnake all\nsnake",
        checks = {
            required_funcs = {getsenv},
            sp_allowed = true,
            req_place_type = "mission",
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a", "sp"}
                end}
            },
            af_compatible = false,
        },
        func = function(...)
            for _, group in ipairs({...}) do
                local group_npcs = npc_mgr.aliases[group]
                if group_npcs == nil then continue end
                for npc, data in pairs(group_npcs) do
                    if data.snaked == true then continue end

                    for count = 1, 2, 1 do
                        if npc and data.character and data.interact then
                            GetRemote("StartInteraction"):FireServer(npc.Character.Interact, npc.Character)            
                            GetRemote("TriggerInteraction"):InvokeServer(npc.Character.Interact)
                            task.wait(0.2)
                        end
                    end

                    data.snaked = true
                end
            end
        end
    },
    {
        name = "lockinteract",
        mode = "mission",
        desc = "lockinteract\n\ncall: lockinteract\ncommand type: one time, visible, reversible\n\ndescription: locks any interactions with any objects for your teammates. This command may take some time to lock interaction with all objects.",
        usage_example = "lockinteract",
        checks = {
            required_funcs = {getsenv},
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            if cache.complex_cmds.unlockinteract ~= nil then
                tools.ClearTableTask(cache.complex_cmds, "unlockinteract")
            end

            if cache.complex_cmds.lockinteract ~= nil then
                cache.complex_cmds.lockinteract = tools.CreatePendingTask(function()
                    for _, obj in ipairs(Level:GetDescendants()) do
                        if obj.Name == "Interact" then
                            GetRemote("StartInteraction"):FireServer(obj.Parent, obj)
                            GetRemote("ReserveUse"):InvokeServer(obj)
                            table.insert(cache.locked_interacts, obj)
                            task.wait(0.05)
                        end
                    end
                end)
            end
        end
    },
    {
        name = "unlockinteract",
        mode = "mission",
        desc = "unlockinteract\n\ncall: unlockinteract\ncommand type: one time, visible, reversible\n\ndescription: unlocks interactions with objects for your teammates which has been locked by lockinteract command. This command may take some time to unlock interaction for all objects with locked interaction",
        usage_example = "unlockinteract",
        checks = {
            required_funcs = {getsenv},
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            if cache.complex_cmds.lockinteract ~= nil then
                tools.ClearTableTask(cache.complex_cmds, "lockinteract")
            end

            if cache.complex_cmds.unlockinteract == nil then
                cache.complex_cmds.unlockinteract = tools.CreatePendingTask(function()
                    for _, interact in ipairs(cache.locked_interacts:GetChildren()) do
                        GetRemote("ReleaseUse"):InvokeServer(interact)
                        task.wait(0.05)
                    end
                end)
            end
        end
    },
    {
        name = "spkill",
        mode = "mission",
        desc = "spkill\n\ncall: spkill\ncommand type: switch, visible, reversible\n\ndescription: automatically kills all snipers and all spawning snipers. Reuse disables this feature.",
        usage_example = "spkill",
        checks = {
            required_funcs = {getsenv},
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            cache.weaponkey_cmds.spkill = is_enabled

            if is_enabled == true then
                for _, data in pairs(npc_mgr.npcs_data.snipers.npcs) do
                    task.spawn(function()
                        while data and data.humanoid and data.humanoid.Health > 0 do
                            tools.SimulateKnifeHit(data.humanoid, data.hrp, 1000) 
                            task.wait(0.1)
                        end
                    end)
                end
            else
                if Armed.Value == false and tools.ClearWeaponKey ~= nil then
                    tools.ClearWeaponKey()
                end
            end
        end
    },
    {
        name = "gclearance",
        mode = "mission",
        desc = "gclearance\n\ncall: gclearance\ncommand type: switch, visible, reversible\n\ndescription: allows you to unlock any chip doors without the disguise needed for them. Reuse disables this feature.",
        usage_example = "gclearance",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            for _, door in ipairs(Doors:GetChildren()) do
                if door:FindFirstChild("ChipReader") then
                    local interact = door.ChipReader.Interact
                    if interact:FindFirstChild("DisguiseNeeded") then
                        interact.DisguiseNeeded:Destroy()
                    end
                end
            end
        end
    },
    {
        name = "music",
        desc = "music\n\ncall: music\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which allows you to change mission soundtracks.",
        usage_example = "music",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function()
            music.window.Visible = not music.window.Visible
        end
    },
    {
        name = "lobby",
        desc = "lobby\n\ncall: lobby\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which allows you to create impossible lobbies.",
        usage_example = "lobby",
        checks = {
            req_place_type = "lobby",
            af_compatible = true,
        },
        func = function()
            lobby.window.Visible = not lobby.window.Visible
        end 
    },
    {
        name = "help",
        desc = "help\n\ncall: help\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which shows you descriptions and usage examples for all existing commands in the script.",
        usage_example = "help",
        checks = {
            req_place_type = "any",
            af_compatible = true,
        },
        func = function()
            local window = cache.help_window
            window.Visible = not window.Visible
        end
    },
    {
        name = "keybinds",
        desc = "keybinds\n\ncall: keybinds\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which allows you to assign commands to be executed when certain keys are pressed.",
        usage_example = "keybinds",
        checks = {
            req_place_type = "any",
            af_compatible = true,
        },
        func = function()
            local window = cache.keybinds_window
            window.Visible = not window.Visible
        end
    },
    {
        name = "teleport",
        desc = "teleport\n\ncall: teleport\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which allows you to teleport to different places.",
        usage_example = "teleport",
        checks = {
            req_place_type = "any",
            af_compatible = true,
        },
        func = function()
            teleport.window.Visible = not teleport.window.Visible
        end
    },
    {
        name = "settings",
        desc = "settings\n\ncall: settings\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which allows you to change script behaviour.",
        usage_example = "settings",
        checks = {
            req_place_type = "any",
            af_compatible = false,
        },
        func = function()
            scr_settings.window.Visible = not scr_settings.window.Visible
        end
    },
    {
        name = "startup",
        desc = "startup\n\ncall: startup\ncommand type: switch, invisible, reversible\n\ndescription: opens a gui which allows you to assign commands to be executed as soon as the script is executed.",
        usage_example = "startup",
        checks = {
            req_place_type = "any",
            af_compatible = true,
        },
        func = function()
            local window = cache.startup_window
            window.Visible = not window.Visible
        end
    },
    {
        name = "snaketouch",
        desc = "snaketouch\n\ncall: snaketouch\ncommand type: switch, visible, reversible\n\ndescription: allows you to put npcs on the ground that you interact with pressing the [F] key. To put npc on the ground, interact with it, then wait ~1 second and interact with it again. Reuse disables this feature, but doesn't return npcs that are lying on the ground to their normal state.",
        usage_example = "snaketouch",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled)
            if is_enabled == true then
                for _, data in pairs(npc_mgr.npcs_data.all.npcs) do
                    data.active.Value = true
                end
            end
        end
    },
    {
        name = "unlockengi",
        desc = "unlockengi\n\ncall: unlockengi\ncommand type: switch, visible, reversible\n\ndescription: allows you to bypass chip reader and door sensors without having the Engineer class. Reuse disables this feature.",
        usage_example = "unlockengi",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            local name = is_enabled == true and "ReqEngineer " or "ReqEngineer"

            for _, req_engineer in ipairs(obj_mgr.engineers) do
                req_engineer.Name = name
            end
        end
    },
    {
        name = "strweps",
        desc = "strweps\n\ncall: strweps\ncommand type: switch, visible, reversible\n\ndescription: significantly increases the bullet damage from your weapons. Reuse disables this feature.",
        usage_example = "strweps",
        checks = {
            required_funcs = {hookmetamethod, getnamecallmethod, checkcaller},
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled)
            if is_enabled == true then
                if cmds_mgr.flags.gmweps == true then
                    cache.ValidateCommand("gmweps", "terminal")
                end

                rmts_mgr.FireBulletDmg = 250
            else
                rmts_mgr.FireBulletDmg = nil
            end
        end
    },
    {
        name = "gmweps",
        desc = "gmweps\n\ncall: gmweps\ncommand type: switch, visible, irreversible\n\ndescription: the bullets from your weapons will give godmode to anyone they hit. Reuse disables this feature.",
        usage_example = "gmweps",
        checks = {
            required_funcs = {hookmetamethod, getnamecallmethod, checkcaller},
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function(is_enabled)
            if is_enabled == true then
                if cmds_mgr.flags.strweps == true then
                    cache.ValidateCommand("strweps", "terminal")
                end

                rmts_mgr.FireBulletDmg = tonumber("nan")
            else
                rmts_mgr.FireBulletDmg = nil
            end
        end
    },
    {
        name = "stealitem",
        desc = "stealitem\n\ncall: stealitem <player_name: text> <item_name: text> <quantity: number?>\ncommand type: one time, visible, reversible\n\ndescription: transfers the specified items in the specified amount to your inventory from the victim's inventory. Items that don't fit into your inventory will be thrown to the ground. If <item_name> = \"all\", then all items will be stolen from victim's inventory.",
        usage_example = "stealitem averydumbcheese microcam 6\nstealitem averydumbcheese all",
        checks = {
            required_funcs = {debug, debug.getupvalue, getsenv},
            req_place_type = "mission",
            args = {
                [1] = {name = "player_name", required = true, type = "text", tip_gen = function(_)
                    local players = {}

                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Name ~= LocalPlayer.Name then
                            table.insert(
                                players,
                                player.Name == player.DisplayName and player.Name or player.Name.." ("..player.DisplayName..")"
                            )
                        end
                    end

                    return players
                end},
                [2] = {name = "item_name", required = true, type = "text", tip_gen = function(args)
                    local items = {}

                    local player_data = tools.PlayerDataByName(args[1])
                    if player_data == nil then return nil end

                    table.insert(items, "all")

                    for _, tool in ipairs(player_data.tools:GetDescendants()) do
                        if tool:FindFirstChild("ExpectedLoc") ~= nil then
                            table.insert(items, tool.Name)
                        end
                    end

                    return items
                end},
                [3] = {name = "quantity", required = false, type = "number"},
            },
        },
        requires_char = true,
        af_compatible = false,
        func = function(_, player_name, item_name, quantity)
            item_name = string.lower(item_name)
            if item_name == "all" or quantity == "all" then quantity = 666 end
            quantity = tonumber(quantity) or 1

            local data = tools.PlayerDataByName(player_name)
            if not data then return end

            for _, obj in ipairs(data.tools:GetDescendants()) do
                if (item_name ~= "all" and obj.Name:lower() ~= item_name) or obj:FindFirstChild("Location") == nil then continue end

                GetRemote("AuthItemMove"):InvokeServer(obj, obj.Parent, GroundItems, 0)
                while obj.Parent.ClassName ~= "Model" do task.wait() end
                GetRemote("TryPickup"):Invoke(obj)
                
                quantity -= 1

                if quantity == 0 then break end
            end
        end
    },
    {
        name = "dropitem",
        desc = "dropitem\n\ncall: dropitem <player_name: text> <item_name: text> <quantity: number?>\ncommand type: one time, visible, reversible\n\ndescription: throws to the ground the specified items in the specified amount from the victim's inventory. If <item_name> = \"all\", then all items will be thrown out from victim's inventory.",
        usage_example = "dropitem averydumbcheese microcam 6\ndropitem averydumbcheese all",
        checks = {
            required_funcs = {debug, debug.getupvalue, getsenv},
            req_place_type = "mission",
            args = {
                [1] = {name = "player_name", required = true, type = "text", tip_gen = function(_)
                    local players = {}

                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Name ~= LocalPlayer.Name then
                            table.insert(
                                players,
                                player.Name == player.DisplayName and player.Name or player.Name.." ("..player.DisplayName..")"
                            )
                        end
                    end

                    return players
                end},
                [2] = {name = "item_name", required = true, type = "text", tip_gen = function(args)
                    local items = {}

                    local player_data = tools.PlayerDataByName(args[1])
                    if player_data == nil then return nil end

                    table.insert(items, "all")

                    for _, tool in ipairs(player_data.tools:GetDescendants()) do
                        if tool:FindFirstChild("ExpectedLoc") ~= nil then
                            table.insert(items, tool.Name)
                        end
                    end

                    return items
                end},
                [3] = {name = "quantity", required = false, type = "number"},
            },
        },
        requires_char = true,
        af_compatible = true,
        func = function(_, player_name, item_name, quantity)
            quantity = tonumber(quantity) or 1
            item_name = string.lower(item_name)
            if item_name == "all" then quantity = 666 end

            local data = tools.PlayerDataByName(player_name)
            if not data then return "dropitem: make sure that you have entered the player's name correctly." end

            for _, obj in ipairs(data.tools:GetDescendants()) do
                if obj:FindFirstChild("Location") == nil or (item_name ~= "all" and obj.Name:lower() ~= item_name) then continue end

                GetRemote("AuthItemMove"):InvokeServer(obj, obj.Parent, GroundItems, 0)
                
                quantity -= 1

                if quantity == 0 then break end
            end
        end
    },
    {
        name = "stealwep",
        desc = "stealwep\n\ncall: stealwep <player_name: text> <item_name: text> <quantity: number?>\ncommand type: one time, visible, reversible\n\ndescription: throws to the ground the specified weapons in the specified amount from the victim's inventory. If <wep_name> = \"all\", then all weapons will be thrown out from victim's inventory.",
        usage_example = "stealwep averydumbcheese raven\nstealwep averydumbcheese up9 2",
        checks = {
            args = {
                [1] = {name = "player_name", required = true, type = "text", tip_gen = function(_)
                    local players = {}

                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Name ~= LocalPlayer.Name then
                            table.insert(
                                players,
                                player.Name == player.DisplayName and player.Name or player.Name.." ("..player.DisplayName..")"
                            )
                        end
                    end

                    return players
                end},
                [2] = {name = "wep_name", required = true, type = "text", tip_gen = function(args)
                    local items = {}

                    table.insert(items, "all")

                    local player_data = tools.PlayerDataByName(args[1])
                    if player_data == nil then return nil end

                    for _, tool in ipairs(player_data.weapons:GetDescendants()) do
                        if tool:FindFirstChild("AmmoLoaded") ~= nil then
                            table.insert(items, tool.Name)
                        end
                    end

                    return items
                end},
                [3] = {name = "quantity", required = false, type = "number"},
            },
            required_funcs = {debug, debug.getupvalue, getsenv},
            req_place_type = "mission",
            af_compatible = true,
        },
        requires_char = true,
        func = function(_, player_name, wep_name, quantity)
            quantity = tonumber(quantity) or 1
            wep_name = string.lower(wep_name)
            if wep_name == "all" then quantity = 666 end

            local data = tools.PlayerDataByName(player_name)
            if not data then return "stealwep: make sure that you have entered the player's name correctly." end

            local function internal(obj)
                if obj:FindFirstChild("AmmoLoaded") == nil or (wep_name ~= "all" and obj.Name:lower() ~= wep_name) then return false end

                GetRemote("AuthItemMove"):InvokeServer(obj, obj.Parent, GroundWeps)

                quantity -= 1

                if quantity == 0 then return true end

                return false
            end

            for _, obj in ipairs(data.weapons:GetChildren()) do
                if internal(obj) == true then return end
            end

            if data.tools:FindFirstChild("Bag") then
                for _, obj in ipairs(data.tools.Bag:GetChildren()) do
                    if internal(obj) == true then return end
                end
            end
        end
    },
    {
        name = "disarm",
        desc = "disarm\n\ncall: stealwep <npc_group: text>+\ncommand type: switch, visible, irreversible\n\ndescription: removes weapons from npcs of specified group(s) who aren't holding weapons at the moment. Reuse disables this feature, but doesn't return weapons to those npcs from whom they were removed.",
        usage_example = "disarm g e\ndisarm all",
        checks = {
            required_funcs = {debug, debug.getupvalue, getsenv},
            req_place_type = "mission",
            sp_allowed = true,
            args = {
                [1] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"g", "s", "all", "e", "a"}
                end}
            },
            af_compatible = true,
        },
        requires_char = true,
        func = function(is_enabled, _, ...)
            if is_enabled == true then
                local function internal(data)
                    while data.weapon.Value ~= nil and data.weapon.Value.Parent ~= nil do
                        GetRemote("AuthItemMove"):InvokeServer(data.weapon.Value, data.weapon.Value.Parent, nil)
                        task.wait(0.05)
                    end
                end

                for _, group in ipairs({...}) do
                    if group == "c" then continue end
                    local group_npcs = npc_mgr.aliases[group]
                    if group_npcs == nil then continue end
                    table.insert(cache.disarm, group_npcs)
                    for _, data in pairs(group_npcs) do
                        if data.weapon.Value == nil then
                            data.weapon:GetPropertyChangedSignal("Value"):Connect(function()
                                if data.weapon.Value ~= nil then
                                    task.spawn(internal, data)
                                end
                            end)
                        else
                            task.spawn(internal, data)
                        end
                    end
                end
            else
                cache.disarm = {}
            end
        end
    },
    {
        name = "invtrap",
        desc = "invtrap\n\ncall: invtrap <player_name: text> <item_name: text>?\ncommand type: one time, visible, irreversible\n\ndescription: breaks the victim's inventory in such a way that when it opens it, it won't be able to close it and, accordingly, won't be able to move. This command requires an item. First, it searches for items in the victim's inventory, and if none are found, it takes an item with the name specified in <item_name> from your character's inventory.",
        usage_example = "invtrap averydumbcheese microcam\ninvtrap averydumbcheese thermitecan\ninvtrap averydumbcheese",
        checks = {
            required_funcs = {debug, debug.getupvalue, getsenv},
            req_place_type = "mission",
            args = {
                [1] = {name = "player_name", required = true, type = "text", tip_gen = function(_)
                    local players = {}

                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Name ~= LocalPlayer.Name then
                            table.insert(
                                players,
                                player.Name == player.DisplayName and player.Name or player.Name.." ("..player.DisplayName..")"
                            )
                        end
                    end

                    return players
                end},
                [2] = {name = "item_name", required = false, type = "text", tip_gen = function(args)
                    local items = {}

                    local player_data = tools.PlayerDataByName(args[1])
                    if player_data == nil then return nil end

                    for _, tool in ipairs(player_data.tools:GetDescendants()) do
                        if tool:FindFirstChild("ExpectedLoc") ~= nil then
                            table.insert(items, tool.Name)
                        end
                    end

                    return items
                end},
            },
        },
        requires_char = true,
        af_compatible = true,
        func = function(_, player_name, item_name)
            local data = tools.PlayerDataByName(player_name)
            if not data then return "invtrap: make sure that you have entered the player's name correctly." end

            item_name = string.lower(item_name)

            local local_data = tools.PlayerDataByName(LocalPlayer.Name)

            for _, item in ipairs(data.tools.Held:GetChildren()) do
                GetRemote("AuthItemMove"):InvokeServer(item, data.tools.Held, data.tools.Held, tonumber("nan"))
                return
            end

            if data.tools:FindFirstChild("Bag") then
                for _, item in ipairs(data.tools.Bag:GetChildren()) do
                    GetRemote("AuthItemMove"):InvokeServer(item, data.tools.Bag, data.tools.Bag, tonumber("nan"))
                    return
                end
            end

            for _, obj in ipairs(local_data:GetDescendants()) do
                if obj.Name == "ExpectedLoc" then
                    GetRemote("AuthItemMove"):InvokeServer(obj.Parent, obj.Parent.Parent, data.tools.Held, tonumber("nan"))
                    return
                end
            end
        end
    },
    {
        name = "stealnpcwep",
        desc = "stealnpcwep\n\ncall: stealnpcwep <wep_name: text> <amount: number>\ncommand type: one time, visible, irreversible\n\ndescription: steals the weapons in the specified amount from npcs of the specified group(s). Names of weapons that can be stolen: 870 MCS, CZ75, F57, MP7, RFB-C, Raven, S97Shield, Sawblade, SwatSniper, UP9Shield.",
        usage_example = "stealnpcwep SwatSniper 25 all\nstealnpcwep CZ75 50 g w s",
        checks = {
            required_funcs = {debug, debug.getupvalue, getsenv},
            req_place_type = "mission",
            sp_allowed = true,
            args = {
                [1] = {name = "wep_name", required = true, type = "text", tip_gen = function(_)
                    return {"all", "870_MCS", "CZ75", "F57", "MP7", "RFB-C", "Raven", "S97Shield", "Sawblade", "SwatSniper", "UP9Shield"}
                end},
                [2] = {name = "amount", required = true, type = "number"},
                [3] = {name = "npc_group", required = true, type = "text", multiple = true, tip_gen = function(_)
                    return {"w", "g", "s", "c", "all", "e", "a"}
                end}
            },
        },
        requires_char = true,
        af_compatible = false,
        func = function(_, wep_name, amount, ...)
            amount = tonumber(amount) or 1
            wep_name = string.lower(wep_name)
            wep_name = string.gsub(wep_name, "_", " ")

            for _, group in ipairs({...}) do
                local group_npcs = npc_mgr.aliases[group]
                if group_npcs == nil then continue end
                for _, data in pairs(group_npcs) do
                    if data.status == nil or data.status:FindFirstChild("Weapons") == nil then continue end
                    if wep_name == "all" then
                        for _, weapon in ipairs(data.status.Weapons:GetChildren()) do
                            GetRemote("AuthItemMove"):InvokeServer(weapon, weapon.Parent, GroundWeps, 0)
                            amount -= 1
                            if amount == 0 then return end
                        end 
                    else
                        for _, weapon in ipairs(data.status.Weapons:GetChildren()) do
                            if weapon.Name:lower() ~= wep_name then continue end
                            GetRemote("AuthItemMove"):InvokeServer(weapon, weapon.Parent, GroundWeps, 0)
                            amount -= 1
                            if amount == 0 then return end
                        end
                    end
                end
            end
        end
    },
    {
        name = "setdiff",
        desc = "setdiff\n\ncall: setdiff <difficulty: number>\ncommand type: one time, visible, irreversible\n\ndescription: if you got to the mission using the teleport model with difficulty 0 or created a lobby using the lobby module with difficulty 0, the game won't know which difficulty to use, and this command sets the desired difficulty.",
        usage_example = "setdiff 1\nsetdiff 5",
        checks = {
            req_place_type = "mission",
            args = {
                [1] = {name = "difficulty", required = true, type = "number", tip_gen = function(_)
                    return {"1", "2", "3", "4", "5"}
                end}
            },
            af_compatible = false,
        },
        func = function(difficulty)
            difficulty = tonumber(difficulty)
            if difficulty == nil or (difficulty < 1 or difficulty > 5) then
                return "difficulty must be an integer in the range from 1 to 5 inclusive."
            end
            GetRemote("SetGameDifficulty"):InvokeServer(difficulty)
        end
    },
    {
        name = "reset",
        desc = "reset\n\ncall: reset\ncommand type: one time, visible, irreversible\n\ndescription: resets your character.",
        usage_example = "reset",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        required_parts = {"Humanoid"},
        func = function(humanoid)
            humanoid.Health = -1
        end
    },
    {
        name = "rejoin",
        desc = "rejoin\n\ncall: rejoin\ncommand type: one time, visible, irreversible\n\ndescription: rejoins the current mission and sets the specified difficulty after teleporting.",
        usage_example = "rejoin 1\nrejoin 5",
        checks = {
            req_place_type = "mission",
            args = {
                [1] = {name = "difficulty", required = true, type = "number", tip_gen = function(_)
                    return {"1", "2", "3", "4", "5"}
                end}
            },
            af_compatible = true,
        },
        func = function(difficulty)
            difficulty = tonumber(difficulty)
            if difficulty == nil or (difficulty < 1 or difficulty > 5) then
                return "difficulty must be an integer in the range from 1 to 5 inclusive."
            end
            TeleportService:Teleport(game.PlaceId, LocalPlayer, {Difficulty = difficulty})
        end
    },
    {
        name = "clear",
        desc = "clear\n\ncall: clear\ncommand type: one time, invisible, irreversible\n\ndescription: clears the terminal command output.",
        usage_example = "clear",
        checks = {
            req_place_type = "any",
            af_compatible = true,
        },
        func = function()
            for _, obj in ipairs(cache.commands_holder:GetChildren()) do
                if obj.Name == "welcome_message" or (obj.ClassName ~= "Frame" and obj.ClassName ~= "TextLabel") then continue end
                obj:Destroy()
            end
        end
    },
    {
        name = "version",
        desc = "version\n\ncall: version\ncommand type: one time, invisible, irreversible\n\ndescription: prints the script version.",
        usage_example = "version",
        checks = {
            req_place_type = "any",
            af_compatible = true,
        },
        func = function()
            return "Deimos v2.0.2"
        end
    },
    {
        name = "autofarm",
        desc = "autofarm\n\ncall: autofarm\ncommand type: one time, visible, irreversible, can be executed only before mission start\n\ndescription: autofarms the mission you're in now. Works only with story missions.",
        usage_example = "autofarm",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            local af_util = require("../modules/af_util")

            if is_enabled == true then
                if af_util.HasScenario() == true then
                    local response = af_util.Init(cmds_mgr.cmds, cache.ValidateCommand)
                    if response ~= nil then
                        cache.ValidateCommand("autofarm", "terminal")
                        return response
                    end
                    
                    af_util.PlayScenario()
                else
                    return "autofarm scenario doesn't exists for this mission."
                end
            else
                af_util.StopScenario()
            end
        end
    },
    {
        name = "bdtploop",
        desc = "bdtploop\n\ncall: bdtploop\ncommand type: one time, visible, irreversible\n\ndescription: on Blacksite, activates the teleport trigger of the camera operator room. This command must be executed before any of the players enter the prison room to work properly.",
        usage_example = "bdtploop",
        checks = {
            req_place_type = "mission",
            af_compatible = false,
        },
        func = function()
            if game.PlaceId == 3200010305 then
                local trigger = Triggers:FindFirstChild("CatchupTrigger")
                if trigger == nil then
                    return "this command can be executed only before someone entered the prison room."
                end

                tools.FireTouchTrigger(trigger)
            else
                return "this command works only in Blacksite mission."
            end
        end
    },
    {
        name = "unlockstash",
        desc = "unlockstash\n\ncall: unlockstash\ncommand type: switch, invisible, reversible\n\ndescription: allows you to stash any bags into dumpsters, chests, cabinets and closets. Reuse disables this feature.",
        usage_example = "unlockstash",
        checks = {
            req_place_type = "mission",
            af_compatible = true,
        },
        func = function(is_enabled)
            for _, stasher in ipairs(obj_mgr.stashers) do
                stasher.Name = is_enabled and "BodyStash " or "BodyStash"
            end
        end
    }
}

setmetatable(cmds_mgr.cmds, {
    __call = function(t, name, source, ...)
        local input_args = {...}

        for _, cmd_data in ipairs(cmds_mgr.cmds) do
            if cmd_data.name ~= name then continue end

            if cmd_data.pending ~= nil and coroutine.status(cmd_data.pending) ~= "dead" then
                tools.ClearTableTask(cmd_data, "pending")
                cmd_data.pending = nil
            end

            local args = {}

            local flags = cmds_mgr.flags
            local conns = cmds_mgr.conns

            local flag = flags[cmd_data.name]
            if flag ~= nil then
                if flag == true then
                    local conn = conns[cmd_data.name]
                    if conn ~= nil then
                        if typeof(conn) == "table" then
                            for _, v in ipairs(conn) do
                                v:Disconnect()
                                conns[cmd_data.name] = {}
                            end
                        else
                            conns[cmd_data.name]:Disconnect()
                            conns[cmd_data.name] = nil
                        end
                    end
                end

                flags[cmd_data.name] = not flags[cmd_data.name]
                flag = flags[cmd_data.name]

                table.insert(args, flag)
            end
            
            local ended = false

            if flag ~= nil and source == "terminal" then
                cache.SendResponse({
                    response_text = name..": "..(flag == true and "on" or "off"),
                    timestamp = false
                })
            end

            local wait_task = coroutine.create(function()
                if cmd_data.requires_char == true then
                    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    table.insert(args, character)
                elseif cmd_data.required_parts ~= nil then
                    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    local required_parts = tools.WaitForChildren(character, table.unpack(table.clone(cmd_data.required_parts)))

                    for _, part in ipairs(required_parts) do
                        table.insert(args, part)
                    end
                end   

                ended = true
            end)

            cmd_data.pending = wait_task
            coroutine.resume(wait_task)

            while cmd_data.pending ~= nil and ended == false do task.wait() end

            if cmd_data.pending ~= nil then
                for _, arg in ipairs(input_args) do
                    table.insert(args, arg)
                end

                local response = cmd_data.func(unpack(args))
                return response
            end
        end

        return nil
    end
})


return cmds_mgr
