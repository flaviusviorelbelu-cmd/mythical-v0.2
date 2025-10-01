-- FixedInventoryUtils.lua - Enhanced Inventory Management System
-- A robust, schema-driven inventory helper with safe mutations, per-player locking,
-- defaults, migration, and optional client notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryUtil = {}

---------------------------------------------------------------------
-- Enhanced Configuration and Schema
---------------------------------------------------------------------

-- Canonical inventory schema for seeds and harvested crops
local DEFAULT_SEED_TYPES = {
	stellar_seed = true,
	basic_seed = true,
	cosmic_seed = true,
}

-- Harvested crop types (mirrors seed types for this farming system)
local DEFAULT_HARVEST_TYPES = {
	stellar_seed = true,
	basic_seed = true,
	cosmic_seed = true,
}

-- Enhanced default prices for selling crops
local DEFAULT_CROP_PRICES = {
	stellar_seed = 15,
	basic_seed = 8,
	cosmic_seed = 25,
}

-- Enhanced default prices for buying seeds
local DEFAULT_SEED_PRICES = {
	stellar_seed = 60,
	basic_seed = 30,
	cosmic_seed = 120,
}

-- Schema versioning for future migrations
local CURRENT_SCHEMA_VERSION = 2

---------------------------------------------------------------------
-- Enhanced Internal Utilities
---------------------------------------------------------------------

local function sanitizeKey(name)
	if typeof(name) ~= "string" then
		return ""
	end
	-- Normalize to lowercase snake_case
	local s = name:gsub("%s+", "_"):gsub("%W", "_"):lower()
	return s
end

local function deepCopy(tbl)
	if typeof(tbl) ~= "table" then 
		return tbl 
	end
	
	local res = {}
	for k, v in pairs(tbl) do
		if typeof(v) == "table" then
			res[k] = deepCopy(v)
		else
			res[k] = v
		end
	end
	return res
end

local function safeNumber(n, fallback)
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return fallback or 0
	end
	return n
end

local function clampNonNegative(n)
	n = safeNumber(n, 0)
	if n < 0 then 
		return 0 
	end
	return n
end

-- Enhanced validation function
local function validateInventoryStructure(inv)
	if typeof(inv) ~= "table" then
		return false, "Inventory is not a table"
	end
	
	if typeof(inv.seeds) ~= "table" then
		return false, "Seeds inventory is not a table"
	end
	
	if typeof(inv.harvested) ~= "table" then
		return false, "Harvested inventory is not a table"
	end
	
	return true, "Valid"
end

---------------------------------------------------------------------
-- Enhanced Structure Ensurance and Migration
---------------------------------------------------------------------

-- Ensure that playerData.inventory exists with proper structure
function InventoryUtil.EnsureStructure(playerData)
	playerData = playerData or {}

	-- Create base inventory container
	playerData.inventory = playerData.inventory or {}
	local inv = playerData.inventory

	inv.seeds = inv.seeds or {}
	inv.harvested = inv.harvested or {}

	-- Ensure default keys exist for seeds and harvested with safe values
	for key in pairs(DEFAULT_SEED_TYPES) do
		if inv.seeds[key] == nil then
			inv.seeds[key] = 0
		else
			inv.seeds[key] = clampNonNegative(inv.seeds[key])
		end
	end
	
	for key in pairs(DEFAULT_HARVEST_TYPES) do
		if inv.harvested[key] == nil then
			inv.harvested[key] = 0
		else
			inv.harvested[key] = clampNonNegative(inv.harvested[key])
		end
	end

	-- Schema version tracking
	inv._schemaVersion = CURRENT_SCHEMA_VERSION

	print("[InventoryUtil] ✅ Ensured inventory structure for player data")
	return playerData
end

-- Enhanced migration with better error handling
function InventoryUtil.MigrateInventory(inv)
	if typeof(inv) ~= "table" then 
		warn("[InventoryUtil] ⚠️ Cannot migrate: inventory is not a table")
		return 
	end
	
	inv.seeds = inv.seeds or {}
	inv.harvested = inv.harvested or {}

	-- Handle legacy 'crops' field migration
	if inv.crops and not next(inv.harvested) then
		print("[InventoryUtil] 🔄 Migrating legacy 'crops' to 'harvested'")
		for cropType, amount in pairs(inv.crops) do
			inv.harvested[cropType] = clampNonNegative(amount)
		end
		-- Clear legacy field
		inv.crops = nil
	end

	-- Add any newly added default keys gracefully
	for key in pairs(DEFAULT_SEED_TYPES) do
		if inv.seeds[key] == nil then 
			inv.seeds[key] = 0 
		end
	end
	
	for key in pairs(DEFAULT_HARVEST_TYPES) do
		if inv.harvested[key] == nil then 
			inv.harvested[key] = 0 
		end
	end

	-- Clean up any invalid entries
	for key, value in pairs(inv.seeds) do
		inv.seeds[key] = clampNonNegative(value)
	end
	
	for key, value in pairs(inv.harvested) do
		inv.harvested[key] = clampNonNegative(value)
	end

	-- Update schema version
	inv._schemaVersion = CURRENT_SCHEMA_VERSION
	print("[InventoryUtil] ✅ Migrated inventory to schema version", CURRENT_SCHEMA_VERSION)
end

---------------------------------------------------------------------
-- Enhanced Getters and Mutators
---------------------------------------------------------------------

-- Returns the current count for a seed/crop key with validation
function InventoryUtil.GetCount(inv, category, key)
	if typeof(inv) ~= "table" then 
		warn("[InventoryUtil] ⚠️ GetCount: inventory is not a table")
		return 0 
	end
	
	local cat = inv[category]
	if typeof(cat) ~= "table" then 
		warn("[InventoryUtil] ⚠️ GetCount: category '" .. tostring(category) .. "' is not a table")
		return 0 
	end
	
	key = sanitizeKey(key)
	return clampNonNegative(cat[key] or 0)
end

-- Sets a count for a given key with validation
function InventoryUtil.SetCount(inv, category, key, value)
	if typeof(inv) ~= "table" then 
		warn("[InventoryUtil] ⚠️ SetCount: inventory is not a table")
		return false 
	end
	
	inv[category] = inv[category] or {}
	key = sanitizeKey(key)
	inv[category][key] = clampNonNegative(value)
	
	print("[InventoryUtil] 📝 Set", category, key, "to", inv[category][key])
	return true
end

-- Adds delta to a key with enhanced logging
function InventoryUtil.Add(inv, category, key, delta)
	if typeof(inv) ~= "table" then 
		warn("[InventoryUtil] ⚠️ Add: inventory is not a table")
		return 0 
	end
	
	inv[category] = inv[category] or {}
	key = sanitizeKey(key)
	
	local current = clampNonNegative(inv[category][key] or 0)
	local newValue = clampNonNegative(current + safeNumber(delta, 0))
	inv[category][key] = newValue
	
	if delta > 0 then
		print("[InventoryUtil] ➕ Added", delta, "to", category, key, "(new total:", newValue, ")")
	elseif delta < 0 then
		print("[InventoryUtil] ➖ Removed", math.abs(delta), "from", category, key, "(new total:", newValue, ")")
	end
	
	return newValue
end

-- Enhanced Take function with better error reporting
function InventoryUtil.Take(inv, category, key, amount)
	amount = clampNonNegative(amount)
	local have = InventoryUtil.GetCount(inv, category, key)
	
	if have >= amount then
		local newCount = InventoryUtil.Add(inv, category, key, -amount)
		print("[InventoryUtil] ✅ Successfully took", amount, "from", category, key)
		return true, newCount
	else
		print("[InventoryUtil] ❌ Cannot take", amount, "from", category, key, "(only have", have, ")")
		return false, have
	end
end

-- Enhanced client view with better filtering
function InventoryUtil.ToClientView(inv, filterZeros)
	local out = {
		seeds = {}, 
		harvested = {}, 
		_schemaVersion = inv and inv._schemaVersion or CURRENT_SCHEMA_VERSION
	}
	
	if typeof(inv) ~= "table" then 
		warn("[InventoryUtil] ⚠️ ToClientView: inventory is not a table")
		return out 
	end

	-- Process seeds
	for k, v in pairs(inv.seeds or {}) do
		v = clampNonNegative(v)
		if not filterZeros or v > 0 then 
			out.seeds[k] = v 
		end
	end
	
	-- Process harvested
	for k, v in pairs(inv.harvested or {}) do
		v = clampNonNegative(v)
		if not filterZeros or v > 0 then 
			out.harvested[k] = v 
		end
	end
	
	return out
end

---------------------------------------------------------------------
-- Enhanced Domain Helpers
---------------------------------------------------------------------

-- Enhanced seed adding with validation
function InventoryUtil.AddSeeds(inv, seedType, quantity)
	seedType = sanitizeKey(seedType)
	
	if not DEFAULT_SEED_TYPES[seedType] then
		warn("[InventoryUtil] ❌ Unknown seed type:", seedType)
		return false, "Unknown seed type: " .. seedType
	end
	
	quantity = clampNonNegative(quantity)
	if quantity == 0 then
		return false, "Invalid quantity: must be greater than 0"
	end
	
	InventoryUtil.Add(inv, "seeds", seedType, quantity)
	print("[InventoryUtil] 🌱 Added", quantity, "seeds of type", seedType)
	return true
end

-- Enhanced seed consumption with validation
function InventoryUtil.ConsumeSeedForPlant(inv, seedType)
	seedType = sanitizeKey(seedType)
	
	if not DEFAULT_SEED_TYPES[seedType] then
		return false, "Unknown seed type: " .. seedType
	end
	
	local ok, newCount = InventoryUtil.Take(inv, "seeds", seedType, 1)
	if not ok then
		return false, "No " .. seedType .. " seeds available"
	end
	
	print("[InventoryUtil] 🌱 Consumed 1", seedType, "seed for planting")
	return true
end

-- Enhanced harvest adding
function InventoryUtil.AddHarvest(inv, cropType, quantity)
	cropType = sanitizeKey(cropType)
	
	if not DEFAULT_HARVEST_TYPES[cropType] then
		warn("[InventoryUtil] ❌ Unknown crop type:", cropType)
		return false, "Unknown crop type: " .. cropType
	end
	
	quantity = clampNonNegative(quantity)
	if quantity == 0 then
		return false, "Invalid quantity: must be greater than 0"
	end
	
	InventoryUtil.Add(inv, "harvested", cropType, quantity)
	print("[InventoryUtil] 🌾 Added", quantity, "harvested", cropType)
	return true
end

-- Enhanced selling with better error handling
function InventoryUtil.SellHarvest(inv, cropType, amount, priceTable)
	cropType = sanitizeKey(cropType)
	
	if not DEFAULT_HARVEST_TYPES[cropType] then
		return false, 0, 0, "Unknown crop type: " .. cropType
	end
	
	amount = clampNonNegative(amount)
	if amount == 0 then
		return false, 0, 0, "Amount must be greater than 0"
	end
	
	local have = InventoryUtil.GetCount(inv, "harvested", cropType)
	if have <= 0 then
		return false, 0, 0, "No " .. cropType .. " to sell"
	end
	
	local toSell = math.min(have, amount)
	local prices = priceTable or DEFAULT_CROP_PRICES
	local pricePer = clampNonNegative(prices[cropType] or 0)
	
	if pricePer == 0 then
		warn("[InventoryUtil] ⚠️ No price set for", cropType)
		return false, 0, 0, "No price set for " .. cropType
	end
	
	local coins = toSell * pricePer
	InventoryUtil.Add(inv, "harvested", cropType, -toSell)
	
	print("[InventoryUtil] 💰 Sold", toSell, cropType, "for", coins, "coins")
	return true, toSell, coins
end

---------------------------------------------------------------------
-- Enhanced Atomic Update System
---------------------------------------------------------------------

-- Per-player locks to prevent concurrent modifications
local Locks = {}

local function acquireLock(userId, timeoutSec)
	timeoutSec = timeoutSec or 5
	local start = os.clock()
	
	while Locks[userId] do
		if os.clock() - start > timeoutSec then
			warn("[InventoryUtil] ⏰ Lock timeout for user", userId)
			return false
		end
		task.wait(0.03)
	end
	
	Locks[userId] = true
	print("[InventoryUtil] 🔒 Acquired lock for user", userId)
	return true
end

local function releaseLock(userId)
	Locks[userId] = nil
	print("[InventoryUtil] 🔓 Released lock for user", userId)
end

-- Enhanced atomic update with better error handling
function InventoryUtil.AtomicUpdate(player, DataManager, updateFn, opts)
	if not player or not DataManager then
		warn("[InventoryUtil] ❌ Missing player or DataManager")
		return false, "Missing required parameters"
	end
	
	local userId = player.UserId
	if not acquireLock(userId, 6) then
		return false, "System busy, please try again"
	end

	local ok, err = false, "Unknown error"
	local coinsDelta = 0

	-- Protected execution to ensure lock release
	local success, pErr = pcall(function()
		local data = DataManager.GetPlayerData(player)
		if not data then
			ok, err = false, "No player data available"
			return
		end

		InventoryUtil.EnsureStructure(data)
		
		-- Validate inventory structure before update
		local isValid, validationErr = validateInventoryStructure(data.inventory)
		if not isValid then
			ok, err = false, "Invalid inventory structure: " .. validationErr
			return
		end

		local inv = data.inventory
		local uOk, uErr, delta = updateFn(inv, data)
		
		if not uOk then
			ok, err = false, uErr or "Update function failed"
			return
		end

		coinsDelta = clampNonNegative(delta or 0)
		if coinsDelta ~= 0 then
			local currentCoins = safeNumber(data.coins, 0)
			data.coins = clampNonNegative(currentCoins + coinsDelta)
			print("[InventoryUtil] 💰 Coins changed by", coinsDelta, "(new total:", data.coins, ")")
		end

		-- Save the updated data
		local saveSuccess = DataManager.SavePlayerData(player, data)
		if not saveSuccess then
			ok, err = false, "Failed to save player data"
			return
		end

		ok, err = true, nil

		-- Optional client notification
		if opts and opts.notifyEvent then
			spawn(function()
				opts.notifyEvent:FireClient(player)
			end)
		end
	end)

	releaseLock(userId)

	if not success then
		warn("[InventoryUtil] ❌ Atomic update failed:", pErr)
		return false, tostring(pErr)
	end
	
	return ok, err
end

---------------------------------------------------------------------
-- Enhanced High-level Endpoints
---------------------------------------------------------------------

-- Enhanced seed buying with better validation
function InventoryUtil.BuySeeds(player, DataManager, seedType, quantity, seedPrices, notifyEvent)
	seedType = sanitizeKey(seedType)
	quantity = clampNonNegative(quantity)
	
	local prices = seedPrices or DEFAULT_SEED_PRICES
	local pricePer = clampNonNegative(prices[seedType] or 0)
	
	if pricePer == 0 then
		return false, "Unknown seed type or price not set"
	end
	
	if quantity == 0 then
		return false, "Invalid quantity: must be greater than 0"
	end
	
	local totalCost = pricePer * quantity
	
	print("[InventoryUtil] 🛒 Attempting to buy", quantity, seedType, "for", totalCost, "coins")

	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, data)
		local coins = clampNonNegative(safeNumber(data.coins, 0))
		if coins < totalCost then
			return false, "Not enough coins (need " .. totalCost .. ", have " .. coins .. ")"
		end
		
		local success, reason = InventoryUtil.AddSeeds(inv, seedType, quantity)
		if not success then
			return false, reason
		end
		
		-- Negative delta reduces coins
		return true, nil, -totalCost
	end, { notifyEvent = notifyEvent })
end

-- Consume seed for planting
function InventoryUtil.ConsumeSeedToPlant(player, DataManager, seedType, notifyEvent)
	seedType = sanitizeKey(seedType)
	
	print("[InventoryUtil] 🌱 Attempting to consume", seedType, "for planting")
	
	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, _data)
		local ok, reason = InventoryUtil.ConsumeSeedForPlant(inv, seedType)
		if not ok then
			return false, reason
		end
		return true
	end, { notifyEvent = notifyEvent })
end

-- Add harvested crops
function InventoryUtil.AddHarvested(player, DataManager, cropType, quantity, notifyEvent)
	cropType = sanitizeKey(cropType)
	quantity = clampNonNegative(quantity)
	
	print("[InventoryUtil] 🌾 Attempting to add", quantity, "harvested", cropType)

	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, _data)
		local ok, reason = InventoryUtil.AddHarvest(inv, cropType, quantity)
		if not ok then
			return false, reason
		end
		return true
	end, { notifyEvent = notifyEvent })
end

-- Sell harvested crops
function InventoryUtil.SellHarvested(player, DataManager, cropType, amount, priceTable, notifyEvent)
	cropType = sanitizeKey(cropType)
	amount = clampNonNegative(amount)
	
	print("[InventoryUtil] 💰 Attempting to sell", amount, cropType)

	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, _data)
		local ok, sold, coins, reason = InventoryUtil.SellHarvest(inv, cropType, amount, priceTable or DEFAULT_CROP_PRICES)
		if not ok then
			return false, reason
		end
		-- Positive delta adds coins
		return true, nil, coins
	end, { notifyEvent = notifyEvent })
end

---------------------------------------------------------------------
-- Enhanced Player Stats and Schema Access
---------------------------------------------------------------------

-- Build enhanced player stats payload
function InventoryUtil.BuildPlayerStatsPayload(playerData, filterZeros)
	playerData = InventoryUtil.EnsureStructure(playerData)
	
	return {
		coins = clampNonNegative(safeNumber(playerData.coins, 0)),
		gems = clampNonNegative(safeNumber(playerData.gems, 0)),
		level = math.max(1, clampNonNegative(safeNumber(playerData.level, 1))),
		experience = clampNonNegative(safeNumber(playerData.experience, 0)),
		stats = playerData.stats or {},
		inventory = InventoryUtil.ToClientView(playerData.inventory, filterZeros),
		schemaVersion = CURRENT_SCHEMA_VERSION
	}
end

-- Schema access functions
function InventoryUtil.GetDefaultSeedTypes()
	return deepCopy(DEFAULT_SEED_TYPES)
end

function InventoryUtil.GetDefaultHarvestTypes()
	return deepCopy(DEFAULT_HARVEST_TYPES)
end

function InventoryUtil.GetDefaultSeedPrices()
	return deepCopy(DEFAULT_SEED_PRICES)
end

function InventoryUtil.GetDefaultCropPrices()
	return deepCopy(DEFAULT_CROP_PRICES)
end

function InventoryUtil.GetSchemaVersion()
	return CURRENT_SCHEMA_VERSION
end

-- Debug and utility functions
function InventoryUtil.DebugInventory(inv)
	print("[InventoryUtil] 📊 Debug Inventory:")
	print("  Schema Version:", inv._schemaVersion or "Unknown")
	print("  Seeds:")
	for k, v in pairs(inv.seeds or {}) do
		if v > 0 then
			print("    ", k, "=", v)
		end
	end
	print("  Harvested:")
	for k, v in pairs(inv.harvested or {}) do
		if v > 0 then
			print("    ", k, "=", v)
		end
	end
end

-- Global status for debugging
_G.InventoryUtilStatus = {
	GetVersion = function()
		return CURRENT_SCHEMA_VERSION
	end,
	GetDefaultSeedTypes = InventoryUtil.GetDefaultSeedTypes,
	GetActiveLocks = function()
		return deepCopy(Locks)
	end,
	DebugInventory = InventoryUtil.DebugInventory
}

print("[InventoryUtil] ✅ Enhanced InventoryUtils loaded - Schema Version:", CURRENT_SCHEMA_VERSION)

return InventoryUtil