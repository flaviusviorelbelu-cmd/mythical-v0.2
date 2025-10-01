-- FixedDataManager.lua (ServerScriptService) - Enhanced with better error handling
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local InventoryUtils = require(game.ReplicatedStorage.InventoryUtils)

local DataManager = {}

-- Enhanced configuration
local CONFIG = {
	DATASTORE_VERSION = "PlayerData_v4", -- Updated version for fixes
	PET_DATASTORE_VERSION = "PetData_v4",
	SAVE_INTERVAL = 30, -- seconds
	MAX_RETRIES = 5,
	RETRY_DELAY = 2,
	TIMEOUT = 10
}

-- DataStores with error handling
local PlayerStore, PetStore
local storeInitialized = false

-- Initialize DataStores safely
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
		print("[DataManager] DataStores initialized successfully")
		return true
	else
		warn("[DataManager] Failed to initialize DataStores:", result1 or "Unknown error", result2 or "Unknown error")
		return false
	end
end

-- Initialize stores
initializeDataStores()

-- Caches
local playerDataCache = {}
local petDataCache = {}
local saveQueue = {}
local lastSaveAttempt = {}

-- Enhanced default structures
local function defaultPlayerData()
	return {
		coins = 500,
		gems = 5,
		level = 1,
		experience = 0,
		stats = {
			eggsHatched = 0,
			legendaryHatched = 0,
			cropsHarvested = 0,
			totalPlaytime = 0
		},
		inventory = {
			seeds = {
				basic_seed = 0,
				stellar_seed = 0,
				cosmic_seed = 0
			},
			crops = {},
			fertilizers = {},
			eggs = {}
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

-- In DataManager.lua where you create a new profile
local InventoryUtil = require(game.ReplicatedStorage.InventoryUtils)

local function createNewProfile()
	local data = {
		coins = 0,
		gems = 5,
		level = 1,
		inventory = {
			seeds = {},      -- will be filled with defaults
			harvested = {},  -- will be filled with defaults
		}
	}
	InventoryUtil.EnsureStructure(data)
	return data
end


-- When creating new player data
function DataManager.CreatePlayerData(player)
	return {
		coins = 500,
		gems = 5,
		level = 1,
		inventory = InventoryUtils.CreateEmptyInventory()  -- ? Safe initialization
	}
end


local function defaultPetData()
	return {
		activePets = {nil, nil, nil},
		storedPets = {},
		nextPetId = 1,
		maxPetSlots = 3,
		version = CONFIG.PET_DATASTORE_VERSION
	}
end

-- Enhanced safe DataStore operations
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
			warn("[DataManager] DataStore operation failed (attempt " .. attempt .. "/" .. CONFIG.MAX_RETRIES .. "):", result)
			if attempt < CONFIG.MAX_RETRIES then
				wait(CONFIG.RETRY_DELAY)
			end
		end
	end

	warn("[DataManager] All DataStore attempts failed for operation:", operation, "key:", key)
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

	-- Validate inventory structure
	if type(data.inventory) ~= "table" then return false end
	if type(data.inventory.seeds) ~= "table" then return false end

	return true
end

-- Migrate old data format to new format
local function migratePlayerData(data)
	if not data or type(data) ~= "table" then
		return defaultPlayerData()
	end

	-- Ensure all required fields exist
	local newData = defaultPlayerData()

	-- Migrate existing fields
	for key, defaultValue in pairs(newData) do
		if data[key] ~= nil then
			newData[key] = data[key]
		end
	end

	-- Special migration for inventory
	if data.inventory then
		if data.inventory.seeds then
			for seedType, amount in pairs(data.inventory.seeds) do
				newData.inventory.seeds[seedType] = amount
			end
		end
		newData.inventory.crops = data.inventory.crops or {}
		newData.inventory.eggs = data.inventory.eggs or {}
	end

	newData.version = CONFIG.DATASTORE_VERSION
	print("[DataManager] Migrated player data to version", CONFIG.DATASTORE_VERSION)
	return newData
end

-- === PLAYER DATA APIs ===
function DataManager.LoadPlayerData(player)
	local key = tostring(player.UserId)
	print("[DataManager] Loading data for player:", player.Name, "(" .. key .. ")")

	local rawData = safeDataStoreCall("GetAsync", key)
	local data = rawData and migratePlayerData(rawData) or defaultPlayerData()

	-- Update last login
	data.lastLogin = os.time()

	playerDataCache[key] = data
	print("[DataManager] Player data loaded - Coins:", data.coins, "Level:", data.level)
	return data
end

function DataManager.GetPlayerData(player)
	local key = tostring(player.UserId)
	local data = playerDataCache[key]

	if not data then
		warn("[DataManager] No cached data for player:", player.Name, "- loading defaults")
		data = defaultPlayerData()
		playerDataCache[key] = data
	end
	-- ? Always ensure inventory is safe
	data.inventory = InventoryUtils.InitializeInventory(data.inventory)
	return data
end

function DataManager.SavePlayerData(player, data)
	local key = tostring(player.UserId)

	-- Use provided data or cached data
	local dataToSave = data or playerDataCache[key]
	if not dataToSave then
		warn("[DataManager] No data to save for player:", player.Name)
		return false
	end

	-- Validate data before saving
	if not validatePlayerData(dataToSave) then
		warn("[DataManager] Invalid data structure for player:", player.Name, "- not saving")
		return false
	end

	-- Update cache
	playerDataCache[key] = dataToSave

	-- Add to save queue
	saveQueue[key] = {
		data = dataToSave,
		timestamp = tick(),
		player = player
	}

	print("[DataManager] Queued save for player:", player.Name)
	return true
end

-- === PET DATA APIs ===
function DataManager.LoadPetData(player)
	local key = tostring(player.UserId)
	print("[DataManager] Loading pet data for player:", player.Name)

	local rawData = safeDataStoreCall("GetPetAsync", key)
	local data = rawData or defaultPetData()

	petDataCache[key] = data
	return data
end

function DataManager.GetPetData(player)
	local key = tostring(player.UserId)
	return petDataCache[key] or defaultPetData()
end

function DataManager.SavePetData(player, data)
	local key = tostring(player.UserId)
	local dataToSave = data or petDataCache[key]

	if dataToSave then
		petDataCache[key] = dataToSave
		-- Immediate save for pet data
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
	print("[DataManager] Added", amount, "coins to", player.Name, "(new total:", data.coins, ")")
end

function DataManager.AddGems(player, amount)
	local data = DataManager.GetPlayerData(player)
	data.gems = math.max(0, (data.gems or 0) + amount)
	DataManager.SavePlayerData(player, data)
	print("[DataManager] Added", amount, "gems to", player.Name, "(new total:", data.gems, ")")
end

function DataManager.UpdatePlayerStats(player, stat, increment)
	local data = DataManager.GetPlayerData(player)
	data.stats = data.stats or {}
	data.stats[stat] = (data.stats[stat] or 0) + increment
	DataManager.SavePlayerData(player, data)
end

function DataManager.HasEnoughCoins(player, amount)
	local data = DataManager.GetPlayerData(player)
	return (data.coins or 0) >= amount
end

function DataManager.HasEnoughGems(player, amount)
	local data = DataManager.GetPlayerData(player)
	return (data.gems or 0) >= amount
end

-- === ENHANCED SAVE SYSTEM ===
local function processSaveQueue()
	for key, saveData in pairs(saveQueue) do
		local player = saveData.player
		local data = saveData.data
		local timestamp = saveData.timestamp

		-- Prevent too frequent saves (rate limiting)
		local lastSave = lastSaveAttempt[key] or 0
		if tick() - lastSave < 5 then -- Minimum 5 seconds between saves
			continue
		end

		lastSaveAttempt[key] = tick()

		spawn(function()
			local success = safeDataStoreCall("SetAsync", key, data)
			if success then
				print("[DataManager] Successfully saved data for:", player.Name)
				saveQueue[key] = nil -- Remove from queue on success
			else
				warn("[DataManager] Failed to save data for:", player.Name, "- will retry")
				-- Keep in queue for retry, but update timestamp to prevent spam
				saveQueue[key].timestamp = tick() + 30 -- Retry in 30 seconds
			end
		end)
	end
end

-- Periodic save processing
local saveConnection
saveConnection = RunService.Heartbeat:Connect(function()
	-- Process save queue every few seconds
	local currentTime = tick()
	if not DataManager.lastSaveProcess or currentTime - DataManager.lastSaveProcess > CONFIG.SAVE_INTERVAL then
		DataManager.lastSaveProcess = currentTime
		processSaveQueue()
	end
end)

-- === PLAYER CONNECTION HANDLING ===
local function onPlayerAdded(player)
	print("[DataManager] Player joined:", player.Name)
	DataManager.LoadPlayerData(player)
	DataManager.LoadPetData(player)
end

local function onPlayerRemoving(player)
	local key = tostring(player.UserId)
	print("[DataManager] Player leaving:", player.Name, "- saving data")

	-- Force immediate save
	local playerData = playerDataCache[key]
	local petData = petDataCache[key]

	if playerData then
		safeDataStoreCall("SetAsync", key, playerData)
	end

	if petData then
		safeDataStoreCall("SetPetAsync", key, petData)
	end

	-- Clean up cache
	playerDataCache[key] = nil
	petDataCache[key] = nil
	saveQueue[key] = nil
	lastSaveAttempt[key] = nil

	print("[DataManager] Cleanup complete for:", player.Name)
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Graceful shutdown handling
game:BindToClose(function()
	print("[DataManager] Server shutting down - saving all player data")

	-- Save all cached data immediately
	for key, data in pairs(playerDataCache) do
		spawn(function()
			safeDataStoreCall("SetAsync", key, data)
		end)
	end

	for key, data in pairs(petDataCache) do
		spawn(function()
			safeDataStoreCall("SetPetAsync", key, data)
		end)
	end

	-- Wait for saves to complete
	wait(3)

	if saveConnection then
		saveConnection:Disconnect()
	end

	print("[DataManager] Shutdown save complete")
end)

print("[DataManager] Enhanced DataManager loaded successfully - Version:", CONFIG.DATASTORE_VERSION)
return DataManager