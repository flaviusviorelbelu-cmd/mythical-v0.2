-- CleanDataManager.lua - Error-Free Version
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataManager = {}

-- Configuration
local CONFIG = {
	DATASTORE_VERSION = "PlayerData_v6",
	PET_DATASTORE_VERSION = "PetData_v6",
	SAVE_INTERVAL = 30,
	MAX_RETRIES = 3,
	RETRY_DELAY = 1
}

-- DataStore initialization
local PlayerStore, PetStore
local storeInitialized = false

-- Initialize DataStores
local function initializeDataStores()
	local success1, result1 = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.DATASTORE_VERSION)
	end)
	
	local success2, result2 = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.PET_DATASTORE_VERSION)
	end)
	
	if success1 and success2 then
		PlayerStore = result1
		PetStore = result2
		storeInitialized = true
		print("[DataManager] ✅ DataStores initialized successfully")
		return true
	else
		warn("[DataManager] ❌ Failed to initialize DataStores")
		return false
	end
end

-- Initialize
initializeDataStores()

-- Data caches
local playerDataCache = {}
local petDataCache = {}

-- Create default player data
local function createDefaultPlayerData()
	return {
		coins = 1000,
		gems = 50,
		level = 1,
		experience = 0,
		inventory = {
			seeds = {
				basic_seed = 20,
				stellar_seed = 10,
				cosmic_seed = 5
			},
			harvested = {
				basic_seed = 0,
				stellar_seed = 0,
				cosmic_seed = 0
			}
		},
		stats = {
			eggsHatched = 0,
			cropsHarvested = 0,
			totalPlaytime = 0
		},
		settings = {
			musicVolume = 0.5,
			sfxVolume = 0.7,
			notifications = true
		},
		lastLogin = os.time(),
		createdAt = os.time(),
		version = CONFIG.DATASTORE_VERSION
	}
end

-- Safe DataStore operations
local function safeDataStoreCall(operation, key, data)
	if not storeInitialized then
		warn("[DataManager] DataStores not initialized")
		return nil
	end

	for attempt = 1, CONFIG.MAX_RETRIES do
		local success, result = pcall(function()
			if operation == "GetAsync" then
				return PlayerStore:GetAsync(key)
			elseif operation == "SetAsync" then
				return PlayerStore:SetAsync(key, data)
			elseif operation == "GetPetAsync" then
				return PetStore:GetAsync(key)
			elseif operation == "SetPetAsync" then
				return PetStore:SetAsync(key, data)
			end
		end)

		if success then
			return result
		else
			warn("[DataManager] Attempt", attempt, "failed:", result)
			if attempt < CONFIG.MAX_RETRIES then
				wait(CONFIG.RETRY_DELAY)
			end
		end
	end

	return nil
end

-- Data validation
local function validatePlayerData(data)
	if type(data) ~= "table" then return false end
	
	-- Check required fields
	local required = {"coins", "gems", "level", "inventory"}
	for _, field in ipairs(required) do
		if data[field] == nil then
			return false
		end
	end
	
	return true
end

-- === PLAYER DATA APIs ===
function DataManager.LoadPlayerData(player)
	local key = tostring(player.UserId)
	print("[DataManager] 📥 Loading data for:", player.Name)

	local rawData = safeDataStoreCall("GetAsync", key)
	local data = rawData or createDefaultPlayerData()

	-- Ensure data structure
	if not data.inventory then
		data.inventory = {seeds = {}, harvested = {}}
	end
	if not data.inventory.seeds then
		data.inventory.seeds = {}
	end
	if not data.inventory.harvested then
		data.inventory.harvested = {}
	end

	-- Ensure default seeds exist
	local defaultSeeds = {"basic_seed", "stellar_seed", "cosmic_seed"}
	for _, seedType in ipairs(defaultSeeds) do
		if not data.inventory.seeds[seedType] then
			data.inventory.seeds[seedType] = 0
		end
		if not data.inventory.harvested[seedType] then
			data.inventory.harvested[seedType] = 0
		end
	end

	data.lastLogin = os.time()
	playerDataCache[key] = data
	
	print("[DataManager] ✅ Data loaded - Coins:", data.coins, "Level:", data.level)
	return data
end

function DataManager.GetPlayerData(player)
	local key = tostring(player.UserId)
	local data = playerDataCache[key]

	if not data then
		data = DataManager.LoadPlayerData(player)
	end

	return data
end

function DataManager.SavePlayerData(player, data)
	local key = tostring(player.UserId)
	local dataToSave = data or playerDataCache[key]

	if not dataToSave then
		warn("[DataManager] No data to save for:", player.Name)
		return false
	end

	if not validatePlayerData(dataToSave) then
		warn("[DataManager] Invalid data structure for:", player.Name)
		return false
	end

	playerDataCache[key] = dataToSave

	-- Async save
	spawn(function()
		local success = safeDataStoreCall("SetAsync", key, dataToSave)
		if success then
			print("[DataManager] 💾 Saved data for:", player.Name)
		else
			warn("[DataManager] Save failed for:", player.Name)
		end
	end)

	return true
end

-- === PET DATA APIs ===
function DataManager.LoadPetData(player)
	local key = tostring(player.UserId)
	local data = safeDataStoreCall("GetPetAsync", key) or {
		activePets = {},
		storedPets = {},
		nextPetId = 1,
		maxPetSlots = 3
	}
	
	petDataCache[key] = data
	return data
end

function DataManager.GetPetData(player)
	local key = tostring(player.UserId)
	return petDataCache[key] or DataManager.LoadPetData(player)
end

function DataManager.SavePetData(player, data)
	local key = tostring(player.UserId)
	local dataToSave = data or petDataCache[key]

	if dataToSave then
		petDataCache[key] = dataToSave
		spawn(function()
			safeDataStoreCall("SetPetAsync", key, dataToSave)
		end)
	end
end

-- === UTILITY FUNCTIONS ===
function DataManager.AddCoins(player, amount)
	local data = DataManager.GetPlayerData(player)
	data.coins = math.max(0, (data.coins or 0) + amount)
	DataManager.SavePlayerData(player, data)
	print("[DataManager] 🪙 Added", amount, "coins to", player.Name)
end

function DataManager.SpendCoins(player, amount)
	local data = DataManager.GetPlayerData(player)
	if (data.coins or 0) >= amount then
		data.coins = data.coins - amount
		DataManager.SavePlayerData(player, data)
		return true
	end
	return false
end

function DataManager.AddGems(player, amount)
	local data = DataManager.GetPlayerData(player)
	data.gems = math.max(0, (data.gems or 0) + amount)
	DataManager.SavePlayerData(player, data)
end

function DataManager.HasEnoughCoins(player, amount)
	local data = DataManager.GetPlayerData(player)
	return (data.coins or 0) >= amount
end

-- === CLEANUP ===
local function onPlayerRemoving(player)
	local key = tostring(player.UserId)
	print("[DataManager] 👋 Saving data for leaving player:", player.Name)

	-- Force save
	local playerData = playerDataCache[key]
	local petData = petDataCache[key]

	if playerData then
		safeDataStoreCall("SetAsync", key, playerData)
	end
	if petData then
		safeDataStoreCall("SetPetAsync", key, petData)
	end

	-- Clean cache
	playerDataCache[key] = nil
	petDataCache[key] = nil
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Graceful shutdown
game:BindToClose(function()
	print("[DataManager] 🛑 Server shutting down - saving all data")
	
	for key, data in pairs(playerDataCache) do
		safeDataStoreCall("SetAsync", key, data)
	end
	for key, data in pairs(petDataCache) do
		safeDataStoreCall("SetPetAsync", key, data)
	end
	
	wait(2)
	print("[DataManager] Shutdown complete")
end)

print("[DataManager] ✅ Clean DataManager loaded - Version:", CONFIG.DATASTORE_VERSION)
return DataManager