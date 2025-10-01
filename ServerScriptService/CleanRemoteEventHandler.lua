-- CleanRemoteEventHandler.lua - Error-Free Remote Event Management
print("[RemoteEventHandler] Starting Clean RemoteEventHandler...")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module loading
local DataManager
local GardenSystem

-- Safe module loading with fallback
local function loadModule(moduleName)
	local success, result = pcall(function()
		return require(ServerScriptService:WaitForChild(moduleName, 5))
	end)
	
	if success then
		print("[RemoteEventHandler] ✅ Loaded:", moduleName)
		return result
	else
		warn("[RemoteEventHandler] ❌ Failed to load:", moduleName, result)
		return nil
	end
end

-- Load modules
spawn(function()
	wait(1) -- Allow other scripts to initialize
	DataManager = loadModule("CleanDataManager")
	GardenSystem = loadModule("CleanGardenSystem")
	print("[RemoteEventHandler] Module loading complete")
end)

-- Remote Events Storage
local remoteEvents = {}
local remoteFunctions = {}

-- Event names
local eventNames = {
	"BuySeeds", "PlantSeed", "HarvestPlant", "SellCrops",
	"ShowFeedback", "RequestInventoryUpdate", "PlotDataChanged",
	"ShowPlotOptions", "BuyEgg", "EquipPet"
}

local functionNames = {
	"GetPlayerStats", "GetGardenPlots", "GetPetData"
}

-- Create Remote Events
local function createRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		remoteEvents[name] = existing
		print("[RemoteEventHandler] Using existing:", name)
		return existing
	end
	
	if existing then existing:Destroy() end

	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	remoteEvents[name] = event
	print("[RemoteEventHandler] Created:", name)
	return event
end

-- Create Remote Functions
local function createRemoteFunction(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		remoteFunctions[name] = existing
		print("[RemoteEventHandler] Using existing function:", name)
		return existing
	end
	
	if existing then existing:Destroy() end

	local func = Instance.new("RemoteFunction")
	func.Name = name
	func.Parent = ReplicatedStorage
	remoteFunctions[name] = func
	print("[RemoteEventHandler] Created function:", name)
	return func
end

-- Create all remote objects
for _, name in ipairs(eventNames) do
	createRemoteEvent(name)
end

for _, name in ipairs(functionNames) do
	createRemoteFunction(name)
end

-- === EVENT HANDLERS ===

-- Handle Buy Seeds
local function handleBuySeeds(player, seedType, quantity)
	print("[RemoteEventHandler] 🌱 BuySeeds:", player.Name, seedType, quantity)
	
	if not DataManager then
		warn("[RemoteEventHandler] DataManager not loaded")
		return
	end
	
	-- Validate inputs
	quantity = math.max(1, tonumber(quantity) or 1)
	local validSeeds = {"basic_seed", "stellar_seed", "cosmic_seed"}
	local isValid = false
	for _, valid in ipairs(validSeeds) do
		if seedType == valid then
			isValid = true
			break
		end
	end
	
	if not isValid then
		warn("[RemoteEventHandler] Invalid seed type:", seedType)
		return
	end
	
	-- Seed prices
	local prices = {
		basic_seed = 25,
		stellar_seed = 50,
		cosmic_seed = 100
	}
	
	local totalCost = (prices[seedType] or 50) * quantity
	
	-- Get player data
	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		warn("[RemoteEventHandler] No player data")
		return
	end
	
	-- Check if player has enough coins
	if (playerData.coins or 0) < totalCost then
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Not enough coins! Need " .. totalCost, "error")
		end
		return
	end
	
	-- Process purchase
	playerData.coins = playerData.coins - totalCost
	playerData.inventory.seeds[seedType] = (playerData.inventory.seeds[seedType] or 0) + quantity
	
	-- Save data
	DataManager.SavePlayerData(player, playerData)
	
	-- Send feedback
	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback:FireClient(player, "Bought " .. quantity .. " " .. seedType:gsub("_", " ") .. "!", "success")
	end
	
	if remoteEvents.RequestInventoryUpdate then
		remoteEvents.RequestInventoryUpdate:FireClient(player)
	end
	
	print("[RemoteEventHandler] ✅ Purchase successful:", quantity, seedType, "for", totalCost, "coins")
end

-- Handle Plant Seed
local function handlePlantSeed(player, plotId, seedType)
	print("[RemoteEventHandler] 🌱 PlantSeed:", player.Name, "plot", plotId, "seed", seedType)
	
	if not DataManager or not GardenSystem then
		warn("[RemoteEventHandler] Required modules not loaded")
		return
	end
	
	-- Get player data
	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.seeds then
		warn("[RemoteEventHandler] Invalid player data")
		return
	end
	
	-- Check if player has the seed
	local seedCount = playerData.inventory.seeds[seedType] or 0
	if seedCount <= 0 then
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "You don't have any " .. seedType:gsub("_", " ") .. "!", "error")
		end
		return
	end
	
	-- Try to plant
	local success, message = GardenSystem.PlantSeed(player, plotId, seedType)
	
	if success then
		-- Deduct seed from inventory
		playerData.inventory.seeds[seedType] = seedCount - 1
		DataManager.SavePlayerData(player, playerData)
		
		-- Send success feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Successfully planted " .. seedType:gsub("_", " ") .. "!", "success")
		end
		
		if remoteEvents.RequestInventoryUpdate then
			remoteEvents.RequestInventoryUpdate:FireClient(player)
		end
		
		print("[RemoteEventHandler] ✅ Planting successful")
	else
		-- Send error feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Failed to plant: " .. (message or "Unknown error"), "error")
		end
		
		print("[RemoteEventHandler] ❌ Planting failed:", message)
	end
end

-- Handle Harvest Plant
local function handleHarvestPlant(player, plotId)
	print("[RemoteEventHandler] 🌾 HarvestPlant:", player.Name, "plot", plotId)
	
	if not DataManager or not GardenSystem then
		warn("[RemoteEventHandler] Required modules not loaded")
		return
	end
	
	-- Try to harvest
	local success, cropType, quantity = GardenSystem.HarvestPlant(player, plotId)
	
	if success and cropType then
		-- Get player data
		local playerData = DataManager.GetPlayerData(player)
		if playerData then
			-- Add harvested crops
			local harvestAmount = quantity or 1
			playerData.inventory.harvested[cropType] = (playerData.inventory.harvested[cropType] or 0) + harvestAmount
			
			-- Update stats
			playerData.stats.cropsHarvested = (playerData.stats.cropsHarvested or 0) + harvestAmount
			
			-- Save data
			DataManager.SavePlayerData(player, playerData)
			
			-- Send feedback
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Harvested " .. harvestAmount .. " " .. cropType:gsub("_", " ") .. "!", "success")
			end
			
			if remoteEvents.RequestInventoryUpdate then
				remoteEvents.RequestInventoryUpdate:FireClient(player)
			end
			
			print("[RemoteEventHandler] ✅ Harvest successful:", harvestAmount, cropType)
		end
	else
		-- Send error feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Nothing to harvest or crop not ready!", "warning")
		end
		
		print("[RemoteEventHandler] ⚠️  Harvest failed for plot", plotId)
	end
end

-- Handle Sell Crops
local function handleSellCrops(player, cropType, amount)
	print("[RemoteEventHandler] 💰 SellCrops:", player.Name, cropType, amount)
	
	if not DataManager then
		warn("[RemoteEventHandler] DataManager not loaded")
		return
	end
	
	amount = math.max(1, tonumber(amount) or 1)
	
	-- Get player data
	local playerData = DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.harvested then
		warn("[RemoteEventHandler] Invalid player data")
		return
	end
	
	-- Check if player has crops
	local cropCount = playerData.inventory.harvested[cropType] or 0
	if cropCount < amount then
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Not enough " .. cropType:gsub("_", " ") .. " to sell!", "error")
		end
		return
	end
	
	-- Crop prices
	local prices = {
		basic_seed = 10,
		stellar_seed = 20,
		cosmic_seed = 40
	}
	
	local totalEarned = (prices[cropType] or 10) * amount
	
	-- Process sale
	playerData.inventory.harvested[cropType] = cropCount - amount
	playerData.coins = (playerData.coins or 0) + totalEarned
	
	-- Save data
	DataManager.SavePlayerData(player, playerData)
	
	-- Send feedback
	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback:FireClient(player, "Sold " .. amount .. " " .. cropType:gsub("_", " ") .. " for " .. totalEarned .. " coins!", "success")
	end
	
	if remoteEvents.RequestInventoryUpdate then
		remoteEvents.RequestInventoryUpdate:FireClient(player)
	end
	
	print("[RemoteEventHandler] ✅ Sale successful:", amount, cropType, "for", totalEarned, "coins")
end

-- === REMOTE FUNCTIONS ===

-- Get Player Stats
local function getPlayerStats(player)
	if not DataManager then
		return {
			coins = 0,
			gems = 0,
			level = 1,
			inventory = {seeds = {}, harvested = {}}
		}
	end
	
	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		return {
			coins = 0,
			gems = 0,
			level = 1,
			inventory = {seeds = {}, harvested = {}}
		}
	end
	
	print("[RemoteEventHandler] 📊 GetPlayerStats:", player.Name, "- Coins:", playerData.coins)
	
	return {
		coins = playerData.coins or 0,
		gems = playerData.gems or 0,
		level = playerData.level or 1,
		experience = playerData.experience or 0,
		stats = playerData.stats or {},
		inventory = playerData.inventory or {seeds = {}, harvested = {}}
	}
end

-- Get Garden Plots
local function getGardenPlots(player)
	if not GardenSystem then
		return {}
	end
	
	local success, result = pcall(function()
		return GardenSystem.GetGardenData(player)
	end)
	
	return success and result or {}
end

-- === SETUP EVENT HANDLERS ===

local function setupEventHandlers()
	print("[RemoteEventHandler] Setting up event handlers...")
	
	-- Garden events
	if remoteEvents.BuySeeds then
		remoteEvents.BuySeeds.OnServerEvent:Connect(handleBuySeeds)
	end
	
	if remoteEvents.PlantSeed then
		remoteEvents.PlantSeed.OnServerEvent:Connect(handlePlantSeed)
	end
	
	if remoteEvents.HarvestPlant then
		remoteEvents.HarvestPlant.OnServerEvent:Connect(handleHarvestPlant)
	end
	
	if remoteEvents.SellCrops then
		remoteEvents.SellCrops.OnServerEvent:Connect(handleSellCrops)
	end
	
	-- Placeholder pet events
	if remoteEvents.BuyEgg then
		remoteEvents.BuyEgg.OnServerEvent:Connect(function(player, eggType)
			print("[RemoteEventHandler] 🥚 BuyEgg:", player.Name, eggType)
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Pet system coming soon!", "info")
			end
		end)
	end
	
	print("[RemoteEventHandler] ✅ Event handlers setup complete")
end

-- Setup Remote Functions
local function setupRemoteFunctions()
	print("[RemoteEventHandler] Setting up remote functions...")
	
	if remoteFunctions.GetPlayerStats then
		remoteFunctions.GetPlayerStats.OnServerInvoke = getPlayerStats
	end
	
	if remoteFunctions.GetGardenPlots then
		remoteFunctions.GetGardenPlots.OnServerInvoke = getGardenPlots
	end
	
	if remoteFunctions.GetPetData then
		remoteFunctions.GetPetData.OnServerInvoke = function(player)
			if DataManager then
				return DataManager.GetPetData(player)
			else
				return {}
			end
		end
	end
	
	print("[RemoteEventHandler] ✅ Remote functions setup complete")
end

-- Initialize player garden when they join
local function onPlayerAdded(player)
	print("[RemoteEventHandler] 🎮 Player joined:", player.Name)
	
	spawn(function()
		wait(3) -- Give time for character to load
		if GardenSystem then
			GardenSystem.InitializePlayerGarden(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Initialize everything
spawn(function()
	wait(2) -- Allow modules to load
	setupEventHandlers()
	setupRemoteFunctions()
	print("[RemoteEventHandler] ✅ Clean RemoteEventHandler initialized successfully!")
end)

print("[RemoteEventHandler] Clean RemoteEventHandler loaded and starting...")