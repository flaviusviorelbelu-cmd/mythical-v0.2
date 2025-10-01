-- FixedRemoteEventHandler_v4.lua - Complete Harvest System Integration
print("[RemoteEventHandler] Starting RemoteEventHandler v4.0...")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryUtils = require(game.ReplicatedStorage.InventoryUtils)

-- Wait for and load modules
local DataManager
local GardenSystem

local function loadModules()
	local success, result = pcall(function()
		DataManager = require(ServerScriptService.DataManager)
		return DataManager
	end)

	if success then
		print("[RemoteEventHandler] DataManager loaded successfully")
	else
		warn("[RemoteEventHandler] Failed to load DataManager:", result)
	end

	local gardenSuccess, gardenResult = pcall(function()
		GardenSystem = require(ServerScriptService.GardenSystem)
		return GardenSystem
	end)

	if gardenSuccess then
		print("[RemoteEventHandler] GardenSystem loaded successfully")
	else
		warn("[RemoteEventHandler] Failed to load GardenSystem:", gardenResult)
	end
end

-- Load modules with delay
spawn(function()
	wait(1)
	loadModules()
end)

-- Remote Events and Functions Storage
local remoteEvents = {}
local remoteFunctions = {}

-- Event and Function Lists
local eventNames = {
	"BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets", "ShowFeedback",
	"BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent",
	"RequestInventoryUpdate", "PlotDataChanged", "ShowPlotOptionsEvent"
}

local functionNames = {
	"GetPetData", "GetPlayerStats", "GetShopData", "GetGardenPlots"
}

-- Create Remote Events
local function createRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		if existing:IsA("RemoteEvent") then
			remoteEvents[name] = existing
			print("[RemoteEventHandler] Using existing RemoteEvent: " .. name)
			return existing
		else
			existing:Destroy()
		end
	end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = ReplicatedStorage
	remoteEvents[name] = remoteEvent
	print("[RemoteEventHandler] Created RemoteEvent: " .. name)
	return remoteEvent
end

-- Create Remote Functions
local function createRemoteFunction(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		if existing:IsA("RemoteFunction") then
			remoteFunctions[name] = existing
			print("[RemoteEventHandler] Using existing RemoteFunction: " .. name)
			return existing
		else
			existing:Destroy()
		end
	end

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = ReplicatedStorage
	remoteFunctions[name] = remoteFunction
	print("[RemoteEventHandler] Created RemoteFunction: " .. name)
	return remoteFunction
end

-- Initialize remote objects
for _, name in ipairs(eventNames) do
	createRemoteEvent(name)
end

for _, name in ipairs(functionNames) do
	createRemoteFunction(name)
end

-- Enhanced Get Player Stats with Harvest Inventory
local function getPlayerStats(player)
	if not DataManager then
		warn("[RemoteEventHandler] DataManager not available for GetPlayerStats")
		return {
			coins = 0,
			gems = 0,
			level = 1,
			inventory = { seeds = {}, harvested = {} }
		}
	end

	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		warn("[RemoteEventHandler] No player data found for:", player.Name)
		return {
			coins = 0,
			gems = 0,
			level = 1,
			inventory = { seeds = {}, harvested = {} }
		}
	end

	-- Ensure inventory structure exists
	if not playerData.inventory then
		playerData.inventory = { seeds = {}, harvested = {} }
	end
	if not playerData.inventory.seeds then
		playerData.inventory.seeds = {}
	end
	if not playerData.inventory.harvested then
		playerData.inventory.harvested = {}
	end

	-- Ensure default seed counts
	local defaultSeeds = {"stellar_seed", "basic_seed", "cosmic_seed"}
	for _, seedType in ipairs(defaultSeeds) do
		if not playerData.inventory.seeds[seedType] then
			playerData.inventory.seeds[seedType] = 0
		end
	end

	-- Ensure default harvested counts  
	local defaultCrops = {"stellar_seed", "basic_seed", "cosmic_seed"}
	for _, cropType in ipairs(defaultCrops) do
		if not playerData.inventory.harvested[cropType] then
			playerData.inventory.harvested[cropType] = 0
		end
	end

	print("[RemoteEventHandler] GetPlayerStats called for: " .. player.Name)

	local seedsInfo = {}
	for seedType, count in pairs(playerData.inventory.seeds) do
		if count > 0 then
			table.insert(seedsInfo, seedType .. "=" .. count)
		end
	end

	local harvestedInfo = {}
	for cropType, count in pairs(playerData.inventory.harvested) do
		if count > 0 then
			table.insert(harvestedInfo, cropType .. "=" .. count)
		end
	end

	local seedsStr = table.concat(seedsInfo, ",")
	local harvestedStr = table.concat(harvestedInfo, ",")

	print("[RemoteEventHandler] Sending stats - Coins: " .. playerData.coins .. 
		" Seeds: " .. (seedsStr ~= "" and seedsStr or "none") .. 
		" Harvested: " .. (harvestedStr ~= "" and harvestedStr or "none"))

	return {
		coins = playerData.coins or 0,
		gems = playerData.gems or 5,
		level = playerData.level or 1,
		inventory = playerData.inventory
	}
end

-- Enhanced Plant Seed Handler
local function handlePlantSeed(player, plotId, seedType)
	print("[RemoteEventHandler] PlantSeedEvent: " .. player.Name .. " plot " .. plotId .. " seed " .. seedType)

	if not DataManager or not GardenSystem then
		warn("[RemoteEventHandler] Required modules not loaded")
		return
	end

	-- Check if player has the seed
	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.seeds then
		warn("[RemoteEventHandler] No seed inventory found for player")
		return
	end

	local currentSeeds = playerData.inventory.seeds[seedType] or 0
	if currentSeeds <= 0 then
		warn("[RemoteEventHandler] Player doesn't have seed: " .. seedType)
		return
	end

	-- Try to plant the seed
	local success, message = GardenSystem.plantSeed(player, plotId, seedType)

	if success then
		-- Consume the seed from inventory
		playerData.inventory.seeds[seedType] = currentSeeds - 1
		DataManager.SavePlayerData(player, playerData)

		print("[RemoteEventHandler] Successfully planted " .. seedType .. " in plot " .. plotId)
		print("[RemoteEventHandler] Remaining seeds: " .. playerData.inventory.seeds[seedType])

		-- Send feedback to player
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Successfully planted " .. seedType:gsub("_", " ") .. "!", "success")
		end
	else
		warn("[RemoteEventHandler] Failed to plant seed: " .. message)

		-- Send error feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Failed to plant: " .. message, "error")
		end
	end
end

-- NEW: Enhanced Harvest Handler
local function handleHarvestPlant(player, plotId)
	print("[RemoteEventHandler] HarvestPlantEvent: " .. player.Name .. " plot " .. plotId)

	if not DataManager or not GardenSystem then
		warn("[RemoteEventHandler] Required modules not loaded")
		return
	end

	-- Try to harvest the plant
	local success, cropType = GardenSystem.harvestPlant(player, plotId)

	if success and cropType then
		-- Add harvested crop to player's inventory
		local playerData = DataManager.GetPlayerData(player)
		if playerData then
			-- Ensure harvested inventory exists
			if not playerData.inventory then
				playerData.inventory = { seeds = {}, harvested = {} }
			end
			if not playerData.inventory.harvested then
				playerData.inventory.harvested = {}
			end

			-- Add the harvested crop
			local currentCrops = playerData.inventory.harvested[cropType] or 0
			playerData.inventory.harvested[cropType] = currentCrops + 1

			-- Save the updated data
			DataManager.SavePlayerData(player, playerData)

			print("[RemoteEventHandler] Successfully harvested " .. cropType .. " from plot " .. plotId)
			print("[RemoteEventHandler] Total " .. cropType .. " harvested: " .. playerData.inventory.harvested[cropType])

			-- Send success feedback
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Harvested " .. cropType:gsub("_", " ") .. "! Check your inventory.", "success")
			end

			-- Force refresh player's UI
			if remoteEvents.RequestInventoryUpdate then
				remoteEvents.RequestInventoryUpdate:FireClient(player)
			end
		else
			warn("[RemoteEventHandler] Could not get player data for harvest")
		end
	else
		warn("[RemoteEventHandler] Failed to harvest: " .. (cropType or "unknown error"))

		-- Send error feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Nothing to harvest or plant not ready!", "error")
		end
	end
end

-- NEW: Sell Harvested Crops Handler
local function handleSellPlant(player, cropType, amount)
	print("[RemoteEventHandler] SellPlantEvent: " .. player.Name .. " selling " .. amount .. "x " .. cropType)

	if not DataManager then
		warn("[RemoteEventHandler] DataManager not loaded")
		return
	end

	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.harvested then
		warn("[RemoteEventHandler] No harvested inventory found")
		return
	end

	local currentCrops = playerData.inventory.harvested[cropType] or 0
	if currentCrops < amount then
		warn("[RemoteEventHandler] Not enough crops to sell")
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Not enough " .. cropType:gsub("_", " ") .. " to sell!", "error")
		end
		return
	end

	-- Calculate sale price (you can adjust these prices)
	local cropPrices = {
		stellar_seed = 10,
		basic_seed = 5,
		cosmic_seed = 20
	}

	local pricePerCrop = cropPrices[cropType] or 5
	local totalEarned = pricePerCrop * amount

	-- Remove crops and add coins
	playerData.inventory.harvested[cropType] = currentCrops - amount
	playerData.coins = (playerData.coins or 0) + totalEarned

	-- Save data
	DataManager.SavePlayerData(player, playerData)

	print("[RemoteEventHandler] Sold " .. amount .. "x " .. cropType .. " for " .. totalEarned .. " coins")

	-- Send success feedback
	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback:FireClient(player, "Sold " .. amount .. "x " .. cropType:gsub("_", " ") .. " for " .. totalEarned .. " coins!", "success")
	end
end

-- Setup Event Handlers
local function setupEventHandlers()
	print("[RemoteEventHandler] Setting up event handlers...")

	-- Plant Seed Event
	if remoteEvents.PlantSeedEvent then
		remoteEvents.PlantSeedEvent.OnServerEvent:Connect(handlePlantSeed)
	end

	-- Harvest Plant Event  
	if remoteEvents.HarvestPlantEvent then
		remoteEvents.HarvestPlantEvent.OnServerEvent:Connect(handleHarvestPlant)
	end

	-- Sell Plant Event
	if remoteEvents.SellPlantEvent then
		remoteEvents.SellPlantEvent.OnServerEvent:Connect(function(player, cropType, amount)
			handleSellPlant(player, cropType, amount or 1)
		end)
	end

	-- Buy Seed Event (existing functionality)
	if remoteEvents.BuySeedEvent then
		remoteEvents.BuySeedEvent.OnServerEvent:Connect(function(player, seedType, quantity)
			print("[RemoteEventHandler] BuySeedEvent: " .. player.Name .. " buying " .. quantity .. "x " .. seedType)

			if not DataManager then
				return
			end

			local seedPrices = {
				stellar_seed = 50,
				basic_seed = 25, 
				cosmic_seed = 100
			}

			local pricePerSeed = seedPrices[seedType] or 50
			local totalCost = pricePerSeed * quantity

			local playerData = DataManager.GetPlayerData(player)
			if playerData and playerData.coins >= totalCost then
				-- Ensure inventory structure
				if not playerData.inventory then
					playerData.inventory = { seeds = {}, harvested = {} }
				end
				if not playerData.inventory.seeds then
					playerData.inventory.seeds = {}
				end

				-- Process purchase
				playerData.coins = playerData.coins - totalCost
				playerData.inventory.seeds[seedType] = (playerData.inventory.seeds[seedType] or 0) + quantity

				DataManager.SavePlayerData(player, playerData)

				print("[RemoteEventHandler] Successfully bought " .. quantity .. "x " .. seedType .. " for " .. totalCost .. " coins")

				if remoteEvents.ShowFeedback then
					remoteEvents.ShowFeedback:FireClient(player, "Bought " .. quantity .. "x " .. seedType:gsub("_", " ") .. "!", "success")
				end
			else
				warn("[RemoteEventHandler] Not enough coins for purchase")
				if remoteEvents.ShowFeedback then
					remoteEvents.ShowFeedback:FireClient(player, "Not enough coins!", "error")
				end
			end
		end)
	end
end

-- Setup Remote Functions
local function setupRemoteFunctions()
	-- Get Player Stats
	if remoteFunctions.GetPlayerStats then
		remoteFunctions.GetPlayerStats.OnServerInvoke = getPlayerStats
	end

	-- Get Garden Plots
	if remoteFunctions.GetGardenPlots then
		remoteFunctions.GetGardenPlots.OnServerInvoke = function(player)
			if not GardenSystem then
				return {}
			end
			return GardenSystem.getGardenData(player)
		end
	end
end

-- Auto-create gardens for players
local function autoCreateGardens()
	print("[RemoteEventHandler] Auto-creating gardens for existing players...")
	for _, player in pairs(Players:GetPlayers()) do
		if GardenSystem then
			GardenSystem.InitializePlayerGarden(player)
			print("[RemoteEventHandler] Auto-created garden for: " .. player.Name)
		end
	end
end

-- Player events
Players.PlayerAdded:Connect(function(player)
	wait(2) -- Give time for other systems to load
	if GardenSystem then
		GardenSystem.InitializePlayerGarden(player)
		print("[RemoteEventHandler] Auto-created garden for new player: " .. player.Name)
	end
end)

-- Initialize everything
spawn(function()
	wait(3) -- Give time for modules to load
	setupEventHandlers()
	setupRemoteFunctions()
	autoCreateGardens()
	print("[RemoteEventHandler] All handlers initialized successfully!")
end)

print("[RemoteEventHandler] Enhanced RemoteEventHandler v4 setup complete!")
