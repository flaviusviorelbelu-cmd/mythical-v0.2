-- FixedRemoteEventHandler.lua - Enhanced Remote Event Management
print("[RemoteEventHandler] Starting Enhanced RemoteEventHandler v5.0...")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Module loading with retry mechanism
local modules = {}
local moduleLoadStatus = {}

-- Define required modules
local requiredModules = {
	"DataManager",
	"GardenSystem",
	"ShopManager",
	"EggManager",
	"PetInventoryManager"
}

-- Enhanced module loading function
local function loadModule(moduleName)
	local attempts = 0
	local maxAttempts = 10
	
	while attempts < maxAttempts and not modules[moduleName] do
		local success, result = pcall(function()
			return require(ServerScriptService:WaitForChild(moduleName, 2))
		end)
		
		if success then
			modules[moduleName] = result
			moduleLoadStatus[moduleName] = true
			print("[RemoteEventHandler] ✅ Loaded module:", moduleName)
			break
		else
			attempts = attempts + 1
			if attempts % 3 == 0 then -- Log every 3 attempts
				print("[RemoteEventHandler] ⏳ Still waiting for module:", moduleName, "(attempt", attempts, ")")
			end
			wait(1)
		end
	end
	
	if not modules[moduleName] then
		warn("[RemoteEventHandler] ❌ Failed to load module:", moduleName)
		moduleLoadStatus[moduleName] = false
	end
end

-- Load all required modules
local function loadAllModules()
	print("[RemoteEventHandler] Loading required modules...")
	
	for _, moduleName in ipairs(requiredModules) do
		spawn(function()
			loadModule(moduleName)
		end)
	end
	
	-- Wait for critical modules
	local startTime = tick()
	while tick() - startTime < 30 do -- 30 second timeout
		if modules.DataManager and modules.GardenSystem then
			print("[RemoteEventHandler] ✅ Critical modules loaded")
			break
		end
		wait(0.5)
	end
end

-- Start loading modules
loadAllModules()

-- Remote Events and Functions Storage
local remoteEvents = {}
local remoteFunctions = {}

-- Complete event and function lists
local eventNames = {
	-- Garden System
	"BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent",
	"PlotDataChanged", "ShowPlotOptionsEvent", "RequestInventoryUpdate",
	-- Pet System
	"BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets",
	-- UI System
	"ShowFeedback", "RequestDataUpdate"
}

local functionNames = {
	"GetPlayerStats", "GetGardenPlots", "GetPetData", "GetShopData"
}

-- Enhanced remote object creation
local function createRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		remoteEvents[name] = existing
		print("[RemoteEventHandler] ♾️ Using existing RemoteEvent:", name)
		return existing
	end
	
	if existing and not existing:IsA("RemoteEvent") then
		existing:Destroy()
	end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = ReplicatedStorage
	remoteEvents[name] = remoteEvent
	print("[RemoteEventHandler] ✅ Created RemoteEvent:", name)
	return remoteEvent
end

local function createRemoteFunction(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		remoteFunctions[name] = existing
		print("[RemoteEventHandler] ♾️ Using existing RemoteFunction:", name)
		return existing
	end
	
	if existing and not existing:IsA("RemoteFunction") then
		existing:Destroy()
	end

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = ReplicatedStorage
	remoteFunctions[name] = remoteFunction
	print("[RemoteEventHandler] ✅ Created RemoteFunction:", name)
	return remoteFunction
end

-- Create all remote objects
for _, name in ipairs(eventNames) do
	createRemoteEvent(name)
end

for _, name in ipairs(functionNames) do
	createRemoteFunction(name)
end

-- === ENHANCED GARDEN SYSTEM HANDLERS ===

-- Enhanced Plant Seed Handler
local function handlePlantSeed(player, plotId, seedType)
	print("[RemoteEventHandler] 🌱 PlantSeedEvent:", player.Name, "plot", plotId, "seed", seedType)

	if not modules.DataManager or not modules.GardenSystem then
		warn("[RemoteEventHandler] ❌ Required modules not loaded for planting")
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "System not ready, please try again", "error")
		end
		return
	end

	-- Validate parameters
	if not plotId or not seedType then
		warn("[RemoteEventHandler] ❌ Invalid parameters for planting")
		return
	end

	local playerData = modules.DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.seeds then
		warn("[RemoteEventHandler] ❌ No seed inventory found")
		return
	end

	local currentSeeds = playerData.inventory.seeds[seedType] or 0
	if currentSeeds <= 0 then
		print("[RemoteEventHandler] ⚠️  Player has no", seedType)
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "You don't have any " .. seedType:gsub("_", " "), "error")
		end
		return
	end

	-- Try to plant the seed
	local success, message = modules.GardenSystem.plantSeed(player, plotId, seedType)

	if success then
		-- Consume the seed from inventory
		playerData.inventory.seeds[seedType] = currentSeeds - 1
		modules.DataManager.SavePlayerData(player, playerData)

		print("[RemoteEventHandler] ✅ Successfully planted", seedType, "in plot", plotId)

		-- Send success feedback
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Successfully planted " .. seedType:gsub("_", " ") .. "!", "success")
		end
		
		-- Update client inventory
		if remoteEvents.RequestInventoryUpdate then
			remoteEvents.RequestInventoryUpdate:FireClient(player)
		end
	else
		warn("[RemoteEventHandler] ❌ Failed to plant seed:", message)
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Failed to plant: " .. (message or "Unknown error"), "error")
		end
	end
end

-- Enhanced Harvest Handler
local function handleHarvestPlant(player, plotId)
	print("[RemoteEventHandler] 🌾 HarvestPlantEvent:", player.Name, "plot", plotId)

	if not modules.DataManager or not modules.GardenSystem then
		warn("[RemoteEventHandler] ❌ Required modules not loaded for harvesting")
		return
	end

	local success, cropType = modules.GardenSystem.harvestPlant(player, plotId)

	if success and cropType then
		local playerData = modules.DataManager.GetPlayerData(player)
		if playerData then
			-- Ensure harvested inventory exists
			if not playerData.inventory.harvested then
				playerData.inventory.harvested = {}
			end

			-- Add the harvested crop
			local currentCrops = playerData.inventory.harvested[cropType] or 0
			playerData.inventory.harvested[cropType] = currentCrops + 1

			-- Update stats
			if not playerData.stats then playerData.stats = {} end
			playerData.stats.cropsHarvested = (playerData.stats.cropsHarvested or 0) + 1

			modules.DataManager.SavePlayerData(player, playerData)

			print("[RemoteEventHandler] ✅ Successfully harvested", cropType, "from plot", plotId)

			-- Send success feedback
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Harvested " .. cropType:gsub("_", " ") .. "! Check your inventory.", "success")
			end

			-- Update client
			if remoteEvents.RequestInventoryUpdate then
				remoteEvents.RequestInventoryUpdate:FireClient(player)
			end
		else
			warn("[RemoteEventHandler] ❌ Could not get player data for harvest")
		end
	else
		print("[RemoteEventHandler] ⚠️  Nothing to harvest on plot", plotId)
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Nothing to harvest or plant not ready!", "warning")
		end
	end
end

-- Enhanced Sell Crops Handler
local function handleSellPlant(player, cropType, amount)
	print("[RemoteEventHandler] 🪙 SellPlantEvent:", player.Name, "selling", amount, "x", cropType)

	if not modules.DataManager then
		warn("[RemoteEventHandler] ❌ DataManager not loaded for selling")
		return
	end

	-- Validate parameters
	amount = tonumber(amount) or 1
	if amount <= 0 then
		return
	end

	local playerData = modules.DataManager.GetPlayerData(player)
	if not playerData or not playerData.inventory or not playerData.inventory.harvested then
		warn("[RemoteEventHandler] ❌ No harvested inventory found")
		return
	end

	local currentCrops = playerData.inventory.harvested[cropType] or 0
	if currentCrops < amount then
		print("[RemoteEventHandler] ⚠️  Not enough crops to sell")
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Not enough " .. cropType:gsub("_", " ") .. " to sell!", "error")
		end
		return
	end

	-- Enhanced crop prices
	local cropPrices = {
		stellar_seed = 15,
		basic_seed = 8,
		cosmic_seed = 25
	}

	local pricePerCrop = cropPrices[cropType] or 10
	local totalEarned = pricePerCrop * amount

	-- Process sale
	playerData.inventory.harvested[cropType] = currentCrops - amount
	playerData.coins = (playerData.coins or 0) + totalEarned

	modules.DataManager.SavePlayerData(player, playerData)

	print("[RemoteEventHandler] ✅ Sold", amount, "x", cropType, "for", totalEarned, "coins")

	-- Send success feedback
	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback:FireClient(player, "Sold " .. amount .. "x " .. cropType:gsub("_", " ") .. " for " .. totalEarned .. " coins!", "success")
	end
	
	-- Update client
	if remoteEvents.RequestInventoryUpdate then
		remoteEvents.RequestInventoryUpdate:FireClient(player)
	end
end

-- Enhanced Buy Seeds Handler
local function handleBuySeeds(player, seedType, quantity)
	print("[RemoteEventHandler] 🌱 BuySeedEvent:", player.Name, "buying", quantity, "x", seedType)

	if not modules.DataManager then
		warn("[RemoteEventHandler] ❌ DataManager not loaded for buying seeds")
		return
	end

	-- Validate parameters
	quantity = tonumber(quantity) or 1
	if quantity <= 0 then
		return
	end

	-- Enhanced seed prices
	local seedPrices = {
		stellar_seed = 60,
		basic_seed = 30,
		cosmic_seed = 120
	}

	local pricePerSeed = seedPrices[seedType] or 50
	local totalCost = pricePerSeed * quantity

	local playerData = modules.DataManager.GetPlayerData(player)
	if not playerData then
		return
	end

	if (playerData.coins or 0) < totalCost then
		print("[RemoteEventHandler] ⚠️  Not enough coins for purchase")
		if remoteEvents.ShowFeedback then
			remoteEvents.ShowFeedback:FireClient(player, "Not enough coins! Need " .. totalCost .. " coins.", "error")
		end
		return
	end

	-- Ensure inventory structure
	if not playerData.inventory then
		playerData.inventory = {seeds = {}, harvested = {}}
	end
	if not playerData.inventory.seeds then
		playerData.inventory.seeds = {}
	end

	-- Process purchase
	playerData.coins = playerData.coins - totalCost
	playerData.inventory.seeds[seedType] = (playerData.inventory.seeds[seedType] or 0) + quantity

	modules.DataManager.SavePlayerData(player, playerData)

	print("[RemoteEventHandler] ✅ Successfully bought", quantity, "x", seedType, "for", totalCost, "coins")

	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback:FireClient(player, "Bought " .. quantity .. "x " .. seedType:gsub("_", " ") .. "!", "success")
	end
	
	-- Update client
	if remoteEvents.RequestInventoryUpdate then
		remoteEvents.RequestInventoryUpdate:FireClient(player)
	end
end

-- === REMOTE FUNCTION HANDLERS ===

-- Enhanced Get Player Stats
local function getPlayerStats(player)
	if not modules.DataManager then
		warn("[RemoteEventHandler] ❌ DataManager not available for GetPlayerStats")
		return {
			coins = 0,
			gems = 0,
			level = 1,
			inventory = {seeds = {}, harvested = {}}
		}
	end

	local playerData = modules.DataManager.GetPlayerData(player)
	if not playerData then
		return {
			coins = 0,
			gems = 0,
			level = 1,
			inventory = {seeds = {}, harvested = {}}
		}
	end

	-- Ensure inventory structure
	if not playerData.inventory then
		playerData.inventory = {seeds = {}, harvested = {}}
	end
	if not playerData.inventory.seeds then
		playerData.inventory.seeds = {}
	end
	if not playerData.inventory.harvested then
		playerData.inventory.harvested = {}
	end

	-- Ensure default seed types
	local defaultSeeds = {"stellar_seed", "basic_seed", "cosmic_seed"}
	for _, seedType in ipairs(defaultSeeds) do
		if not playerData.inventory.seeds[seedType] then
			playerData.inventory.seeds[seedType] = 0
		end
		if not playerData.inventory.harvested[seedType] then
			playerData.inventory.harvested[seedType] = 0
		end
	end

	print("[RemoteEventHandler] 📊 GetPlayerStats for:", player.Name, "- Coins:", playerData.coins)

	return {
		coins = playerData.coins or 0,
		gems = playerData.gems or 5,
		level = playerData.level or 1,
		experience = playerData.experience or 0,
		stats = playerData.stats or {},
		inventory = playerData.inventory
	}
end

-- Enhanced Get Garden Plots
local function getGardenPlots(player)
	if not modules.GardenSystem then
		return {}
	end
	
	local success, result = pcall(function()
		return modules.GardenSystem.getGardenData(player)
	end)
	
	if success then
		return result or {}
	else
		warn("[RemoteEventHandler] ❌ Failed to get garden data:", result)
		return {}
	end
end

-- === EVENT HANDLER SETUP ===

local function setupEventHandlers()
	print("[RemoteEventHandler] 🔧 Setting up event handlers...")

	-- Garden system events
	if remoteEvents.PlantSeedEvent then
		remoteEvents.PlantSeedEvent.OnServerEvent:Connect(handlePlantSeed)
	end

	if remoteEvents.HarvestPlantEvent then
		remoteEvents.HarvestPlantEvent.OnServerEvent:Connect(handleHarvestPlant)
	end

	if remoteEvents.SellPlantEvent then
		remoteEvents.SellPlantEvent.OnServerEvent:Connect(handleSellPlant)
	end

	if remoteEvents.BuySeedEvent then
		remoteEvents.BuySeedEvent.OnServerEvent:Connect(handleBuySeeds)
	end

	-- Pet system events (placeholder for future implementation)
	if remoteEvents.BuyEgg then
		remoteEvents.BuyEgg.OnServerEvent:Connect(function(player, eggType)
			print("[RemoteEventHandler] 🥚 BuyEgg event:", player.Name, eggType)
			-- TODO: Implement egg buying
			if remoteEvents.ShowFeedback then
				remoteEvents.ShowFeedback:FireClient(player, "Egg system coming soon!", "info")
			end
		end)
	end

	print("[RemoteEventHandler] ✅ Event handlers setup complete")
end

-- === REMOTE FUNCTION SETUP ===

local function setupRemoteFunctions()
	print("[RemoteEventHandler] 🔧 Setting up remote functions...")

	-- Get Player Stats
	if remoteFunctions.GetPlayerStats then
		remoteFunctions.GetPlayerStats.OnServerInvoke = getPlayerStats
	end

	-- Get Garden Plots
	if remoteFunctions.GetGardenPlots then
		remoteFunctions.GetGardenPlots.OnServerInvoke = getGardenPlots
	end

	-- Placeholder remote functions
	if remoteFunctions.GetPetData then
		remoteFunctions.GetPetData.OnServerInvoke = function(player)
			if modules.DataManager then
				return modules.DataManager.GetPetData(player)
			else
				return {}
			end
		end
	end

	if remoteFunctions.GetShopData then
		remoteFunctions.GetShopData.OnServerInvoke = function(player)
			-- TODO: Implement shop data
			return {}
		end
	end

	print("[RemoteEventHandler] ✅ Remote functions setup complete")
end

-- === PLAYER CONNECTION HANDLING ===

local function handlePlayerAdded(player)
	print("[RemoteEventHandler] 🎮 Player joined:", player.Name)
	
	-- Initialize player garden after a delay
	spawn(function()
		wait(3) -- Give other systems time to load
		if modules.GardenSystem then
			local success, error = pcall(function()
				modules.GardenSystem.InitializePlayerGarden(player)
			end)
			
			if success then
				print("[RemoteEventHandler] ✅ Garden initialized for:", player.Name)
			else
				warn("[RemoteEventHandler] ❌ Failed to initialize garden for:", player.Name, error)
			end
		end
	end)
end

Players.PlayerAdded:Connect(handlePlayerAdded)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	spawn(function()
		handlePlayerAdded(player)
	end)
end

-- === SYSTEM STATUS MONITORING ===

local function monitorSystemHealth()
	spawn(function()
		while true do
			wait(60) -- Check every minute
			
			local healthReport = {}
			for moduleName, status in pairs(moduleLoadStatus) do
				healthReport[moduleName] = status
			end
			
			-- Log any failed modules
			for moduleName, status in pairs(healthReport) do
				if not status then
					warn("[RemoteEventHandler] ⚠️  Module health check failed:", moduleName)
				end
			end
		end
	end)
end

-- === MAIN INITIALIZATION ===

local function initialize()
	print("[RemoteEventHandler] 🚀 Starting main initialization...")
	
	-- Wait for critical modules to load
	local startTime = tick()
	while tick() - startTime < 30 do -- 30 second timeout
		if moduleLoadStatus.DataManager and moduleLoadStatus.GardenSystem then
			print("[RemoteEventHandler] ✅ Critical modules ready, proceeding with setup")
			break
		end
		wait(0.5)
	end
	
	-- Setup handlers
	setupEventHandlers()
	setupRemoteFunctions()
	
	-- Start health monitoring
	monitorSystemHealth()
	
	print("[RemoteEventHandler] ✅ Initialization complete!")
	
	-- Print status report
	print("[RemoteEventHandler] 📊 System Status Report:")
	for moduleName, status in pairs(moduleLoadStatus) do
		print("  ", moduleName, ":", status and "✅" or "❌")
	end
	print("   RemoteEvents created:", #eventNames)
	print("   RemoteFunctions created:", #functionNames)
end

-- Start initialization with delay
spawn(function()
	wait(2) -- Give other systems time to start
	initialize()
end)

-- Global status interface
_G.RemoteEventHandlerStatus = {
	GetModuleStatus = function()
		return moduleLoadStatus
	end,
	GetLoadedModules = function()
		return modules
	end,
	IsReady = function()
		return moduleLoadStatus.DataManager and moduleLoadStatus.GardenSystem
	end
}

print("[RemoteEventHandler] 🎉 Enhanced RemoteEventHandler v5.0 loaded and initializing...")