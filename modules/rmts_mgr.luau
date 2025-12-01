local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events", math.huge)
local GetRemote = Events:WaitForChild("GetKey", math.huge)

local tools = require("../modules/tools")
local cache = require("../modules/cache")
local places = require("../modules/places")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local Status = LocalPlayer:WaitForChild("Status", math.huge)
local Scripts = Status:WaitForChild("Scripts", math.huge)

local wep = ReplicatedStorage.Weapons.Data.UP9

local rmts_mgr = {}
    
rmts_mgr.remotes = {}
    
rmts_mgr.FireBullet = nil
rmts_mgr.FireBulletDmg = nil

rmts_mgr.GetRemote = function(remote_name)
    while rmts_mgr.remotes[remote_name] == nil do
        task.wait()
    end

    return rmts_mgr.remotes[remote_name]
end

cache.GetRemote = rmts_mgr.GetRemote

if places.place_group == "mission" then
    if game.PlaceId == 4768829954 then
        rmts_mgr.remotes["MethodVote"] = ReplicatedStorage:WaitForChild("MethodVote", math.huge)
    end

    task.spawn(function()
        local Weapons = PlayerGui:WaitForChild("Weapons", math.huge)
        local WeaponScript = Weapons:WaitForChild("WeaponScript", math.huge)
        rmts_mgr.remotes["TryPickup"] = WeaponScript:WaitForChild("TryPickup", math.huge)
    end)

    if getsenv ~= nil and hookmetamethod ~= nil and getnamecallmethod ~= nil and checkcaller ~= nil then
        task.spawn(function()
            local Weapons = PlayerGui:WaitForChild("Weapons", math.huge)

            local PingLocation = Weapons:WaitForChild("WeaponGui", math.huge):WaitForChild("PingLocation", math.huge)
            local env = getsenv(PingLocation)

            while env.procPing == nil do task.wait() end

            rmts_mgr.remotes["PingLocation"] = debug.getupvalue(env.procPing, 2)

            local WeaponScript = Weapons:WaitForChild("WeaponScript", math.huge)
            local env = getsenv(WeaponScript)

            while env.equipWeapon == nil or env.getModdedStats == nil do task.wait() end

            local old = clonefunction(env.getModdedStats)

            env.getModdedStats = function(arg)
                local modded_stats = old(arg)

                if rmts_mgr.FireBulletDmg == 250 then
                    for _, stat in ipairs({"FireRate", "FireDelay", "ReloadSpeed"}) do
                        modded_stats[stat] = 0
                    end

                    modded_stats["FireType"] = 1
                    modded_stats["Type"] = "SMG"
                    
                    for _, stat in ipairs({"MagazineSize", "MagSize"}) do
                        modded_stats[stat] = 1000000000000000000
                    end

                    for _, stat in ipairs({
                        "SpreadAimMin", 
                        "SpreadAimMax", 
                        "SpreadAimMovMin", 
                        "SpreadAimMovMax", 
                        "SpreadHipMin", 
                        "SpreadHipMax", 
                        "SpreadAimMax",
                        "SpreadHipMovMin",
                        "SpreadHipMovMax",
                        "SpreadDecrease",
                        "SpreadIncrease",
                        "RecoilXMin",
                        "RecoilXSpread",
                        "RecoilUp",
                        "RecoilDecrease",
                        "RecoilFirstShot",
                        "RecoilCam",
                        "RecoilCamTm"
                    }) do
                        modded_stats[stat] = 0.00000000001
                    end
                end

                return modded_stats
            end

            local equipWeapon = env.equipWeapon

            local scr_remotes = debug.getupvalue(equipWeapon, 4)

            for remote_name, remote_table in pairs(scr_remotes) do
                rmts_mgr.remotes[remote_name] = remote_table
            end

            local BulletLocal = Weapons:WaitForChild("BulletLocal", math.huge)
            local env = getsenv(BulletLocal)
            while env.FireBulletRemote == nil do task.wait() end

            local FireBullet = env.FireBulletRemote
            local FireBulletObj = BulletLocal:WaitForChild("FireBullet", math.huge)
            
            rmts_mgr.remotes["FireBullet"] = FireBullet

            local mt = getrawmetatable(game)

            local old = mt.__namecall

            setreadonly(mt, false)

            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()

                if self == FireBulletObj and method == "Fire" and rmts_mgr.FireBulletDmg ~= nil then
                    local args = {...}
                    args[4] = rmts_mgr.FireBulletDmg
                    return old(self, unpack(args))
                end

                return old(self, ...)
            end

            setreadonly(mt, true)
        end)

        if debug ~= nil and debug.getupvalue ~= nil then
            task.spawn(function()
                local scr = PlayerGui:WaitForChild("InventoryGui", math.huge):WaitForChild("InvScript", math.huge)
                local env = getsenv(scr)
        
                while env.stopItemDrag == nil do task.wait() end
        
                rmts_mgr.remotes["AuthItemMove"] = debug.getupvalue(env.stopItemDrag, 18)
            end)
        end
    end

    task.spawn(function()
        local Animate = PlayerGui:WaitForChild("Animate", math.huge)

        for _, remote in ipairs(tools.WaitForChildren(Animate, "SetAnim", "SetLean", "SetShoulders", "SetWeight", "UpdateInputs")) do
            rmts_mgr.remotes[remote.Name] = remote
        end
    end)

    task.spawn(function()
        pcall(function()
            local InventoryValidation = require(game:GetService("ReplicatedStorage"):WaitForChild("Loadout", math.huge):WaitForChild("InventoryValidation", math.huge))
            local Hash = InventoryValidation.Hash

            for normal_name, for_hash_name in pairs({
                ["GenerateWeaponKey"] = "GenerateWeaponKey_7zU",
                ["AmmoReplicate"] = "AmmoReplicate_8Z1",
                ["AmmoReplicateAkimbo"] = "AmmoReplicateAkimbo_av7",
                ["FireGrenade"] = "FireGrenade_1Gs"
            }) do
                local name_hash = Hash(for_hash_name)
                local remote_table = rmts_mgr.GetRemote(name_hash)
                rmts_mgr.remotes[name_hash] = nil
                rmts_mgr.remotes[normal_name] = remote_table 
            end
        end)
    end)

    task.spawn(function()
        local GameState = ReplicatedStorage:WaitForChild("GameState", math.huge)
        local SetGameDifficulty = GameState:WaitForChild("SetGameDifficulty", math.huge)
        rmts_mgr.remotes["SetGameDifficulty"] = SetGameDifficulty

        local Weapons = ReplicatedStorage:WaitForChild("Weapons", math.huge)
        local Objectives = Weapons:WaitForChild("Objectives", math.huge)
        
        for _, remote in ipairs(tools.WaitForChildren(Objectives, "ChangeStageTarget", "AddStage")) do
            rmts_mgr.remotes[remote.Name] = remote
        end
    end)
end

if places.place_group == "lobby" then
    local lobby_remotes = ReplicatedStorage:WaitForChild("Lobby", math.huge):WaitForChild("Trig", math.huge)

    for _, remote in ipairs(tools.WaitForChildren(lobby_remotes, "CreateLobby", "KickPlayer", "StartGame", "LeaveLobby")) do
        rmts_mgr.remotes[remote.Name] = remote
    end
end

task.spawn(function()
    for _, remote_name in ipairs({"BuyWeapon", "BuyAttachment", "SetAttachment"}) do
        local remote, key = GetRemote:InvokeServer(remote_name)

        if remote.Name == "RemoteEvent" then
            rmts_mgr.remotes[remote_name] = {
                FireServer = function(_, ...)
                    remote:FireServer(key, ...)
                end
            }
        else 
            rmts_mgr.remotes[remote_name] = {
                InvokeServer = function(_, ...)
                    return remote:InvokeServer(key, ...)
                end
            }
        end
    end
end)

task.spawn(function()
    local ObjectivesRemotes = ReplicatedStorage:WaitForChild("Weapons", math.huge):WaitForChild("Objectives", math.huge)
    for _, remote_name in ipairs({"AddStage", "ChangeStageTarget", "NewObjective", "SetStageName", "ClearStage"}) do
        local remote = ObjectivesRemotes:WaitForChild(remote_name)
        rmts_mgr.remotes[remote.Name] = remote
    end
end)

return rmts_mgr