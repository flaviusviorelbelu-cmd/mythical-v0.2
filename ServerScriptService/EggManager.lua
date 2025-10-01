-- EggManager.lua (ServerScriptService) - Replacement ModuleScript
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local EggConfig        = require(script.Parent:WaitForChild("EggConfig"))
local PetConfig        = require(script.Parent:WaitForChild("PetConfig"))
local DataManager        = require(script.Parent:WaitForChild("DataManager"))
local PetInventory     = require(script.Parent:WaitForChild("PetInventoryManager"))

local EggManager = {}
local pendingEggs = {}

function EggManager.BuyEgg(player, eggType)
	local cfg = EggConfig.GetEggConfig(eggType)
	local pd  = DataManager.GetPlayerData(player)
	if not cfg or pd.coins < cfg.cost then return false end

	pd.coins = pd.coins - cfg.cost
	DataManager.SavePlayerData(player)

	local hatchTime = os.time() + cfg.hatchTime
	local model = EggManager.CreateEggModel(player, eggType)
	pendingEggs[model] = { player=player, cfg=cfg, hatchTime=hatchTime }
	return true
end

function EggManager.CreateEggModel(player, eggType)
	local cfg = EggConfig.GetEggConfig(eggType)
	local model = Instance.new("Model", workspace)
	local part  = Instance.new("Part", model)
	part.Name = "Egg"; part.Color = cfg.color; part.Anchored = true
	part.Position = player.Character and player.Character.PrimaryPart.Position + Vector3.new(0,5,0) or Vector3.new(0,5,0)
	return model
end

local function hatch(model, info)
	local roll = math.random(100)
	local rarity = EggConfig.GetRarityFromRoll(info.cfg.name, roll)
	local candidates = PetConfig.GetPetsByRarity(rarity)
	local pet = candidates[math.random(#candidates)]
	PetInventory.AddPet(info.player, pet)
	DataManager.UpdatePlayerStats(info.player, "eggsHatched", 1)
	if rarity == "Legendary" then
		DataManager.UpdatePlayerStats(info.player, "legendaryHatched", 1)
	end
	model:Destroy()
end

RunService.Heartbeat:Connect(function()
	for model, info in pairs(pendingEggs) do
		if os.time() >= info.hatchTime then
			hatch(model, info)
			pendingEggs[model] = nil
		end
	end
end)

function EggManager.GetPendingEggCount()
	local c = 0 for _ in pairs(pendingEggs) do c=c+1 end return c
end

function EggManager.GetPlayerEggCount(player)
	local count=0
	for _,info in pairs(pendingEggs) do
		if info.player==player then count+=1 end
	end
	return count
end


return EggManager
