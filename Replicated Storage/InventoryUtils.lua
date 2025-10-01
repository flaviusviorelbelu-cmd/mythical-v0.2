-- InventoryUtil.lua
-- A robust, schema-driven inventory helper with safe mutations, per-player locking,
-- defaults, migration, and optional client notifications.
-- Author: your project
-- Usage: local Inv = require(ServerScriptService.InventoryUtil)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtil = {}

---------------------------------------------------------------------
-- Configuration and Schema
---------------------------------------------------------------------

-- Canonical inventory schema for seeds and harvested crops.
-- Keys are the canonical IDs used everywhere in code and saves.
local DEFAULT_SEED_TYPES = {
	stellar_seed = true,
	basic_seed = true,
	cosmic_seed = true,
}

-- For simplicity, harvested keys mirror seed keys in this project.
-- If you prefer different keys (e.g., "stellar_corn"), adjust here and in your UI.
local DEFAULT_HARVEST_TYPES = {
	stellar_seed = true,
	basic_seed = true,
	cosmic_seed = true,
}

-- Optional default prices for selling crops (used by SellHarvest).
-- You can override per call.
local DEFAULT_CROP_PRICES = {
	stellar_seed = 10,
	basic_seed = 5,
	cosmic_seed = 20,
}

-- Optional default prices for buying seeds (used by BuySeeds).
-- You can override per call.
local DEFAULT_SEED_PRICES = {
	stellar_seed = 50,
	basic_seed = 25,
	cosmic_seed = 100,
}

-- Inventory schema versioning to support migrations if you add new items later.
local CURRENT_SCHEMA_VERSION = 1

---------------------------------------------------------------------
-- Internal Utilities
---------------------------------------------------------------------

local function sanitizeKey(name: string?): string
	if typeof(name) ~= "string" then
		return ""
	end
	-- normalize to lowercase snake_case
	local s = name:gsub("%s+", "_"):gsub("%W", "_"):lower()
	return s
end

local function deepCopy(tbl)
	if typeof(tbl) ~= "table" then return tbl end
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
	if n < 0 then return 0 end
	return n
end

---------------------------------------------------------------------
-- Structure Ensurance and Migration
---------------------------------------------------------------------

-- Ensure that playerData.inventory exists with seeds and harvested tables,
-- with all default keys present and non-negative numbers.
function InventoryUtil.EnsureStructure(playerData: table)
	playerData = playerData or {}

	-- Create base inventory container
	playerData.inventory = playerData.inventory or {}
	local inv = playerData.inventory

	inv.seeds = inv.seeds or {}
	inv.harvested = inv.harvested or {}

	-- Ensure default keys exist for seeds and harvested
	for key in pairs(DEFAULT_SEED_TYPES) do
		inv.seeds[key] = clampNonNegative(inv.seeds[key] or 0)
	end
	for key in pairs(DEFAULT_HARVEST_TYPES) do
		inv.harvested[key] = clampNonNegative(inv.harvested[key] or 0)
	end

	-- If schema versioning is tracked, ensure it exists
	inv._schemaVersion = clampNonNegative(inv._schemaVersion or CURRENT_SCHEMA_VERSION)

	return playerData
end

-- Migrate inventory to CURRENT_SCHEMA_VERSION (placeholder for future growth).
function InventoryUtil.MigrateInventory(inv: table)
	if typeof(inv) ~= "table" then return end
	inv.seeds = inv.seeds or {}
	inv.harvested = inv.harvested or {}

	-- Add any newly added default keys gracefully
	for key in pairs(DEFAULT_SEED_TYPES) do
		if inv.seeds[key] == nil then inv.seeds[key] = 0 end
	end
	for key in pairs(DEFAULT_HARVEST_TYPES) do
		if inv.harvested[key] == nil then inv.harvested[key] = 0 end
	end

	-- Bump version if needed
	inv._schemaVersion = CURRENT_SCHEMA_VERSION
end

---------------------------------------------------------------------
-- Getters and Mutators (Pure Inventory Ops on a table)
---------------------------------------------------------------------

-- Returns the current count for a seed/crop key.
function InventoryUtil.GetCount(inv: table, category: "seeds" | "harvested", key: string): number
	if typeof(inv) ~= "table" then return 0 end
	local cat = inv[category]
	if typeof(cat) ~= "table" then return 0 end
	key = sanitizeKey(key)
	return clampNonNegative(cat[key] or 0)
end

-- Sets a count for a given key to a non-negative value.
function InventoryUtil.SetCount(inv: table, category: "seeds" | "harvested", key: string, value: number)
	if typeof(inv) ~= "table" then return false end
	inv[category] = inv[category] or {}
	key = sanitizeKey(key)
	inv[category][key] = clampNonNegative(value)
	return true
end

-- Adds delta to a key (can be negative), clamped to non-negative result. Returns new count.
function InventoryUtil.Add(inv: table, category: "seeds" | "harvested", key: string, delta: number): number
	if typeof(inv) ~= "table" then return 0 end
	inv[category] = inv[category] or {}
	key = sanitizeKey(key)
	local current = clampNonNegative(inv[category][key] or 0)
	local newValue = clampNonNegative(current + safeNumber(delta, 0))
	inv[category][key] = newValue
	return newValue
end

-- Attempts to remove amount from a key. Returns success, newCount.
function InventoryUtil.Take(inv: table, category: "seeds" | "harvested", key: string, amount: number): (boolean, number)
	amount = clampNonNegative(amount)
	local have = InventoryUtil.GetCount(inv, category, key)
	if have >= amount then
		return true, InventoryUtil.Add(inv, category, key, -amount)
	end
	return false, have
end

-- Returns a summarized shallow copy safe for sending to clients.
-- Optionally filter out zero-count entries for compactness.
function InventoryUtil.ToClientView(inv: table, filterZeros: boolean?): table
	local out = { seeds = {}, harvested = {}, _schemaVersion = inv and inv._schemaVersion or CURRENT_SCHEMA_VERSION }
	if typeof(inv) ~= "table" then return out end

	for k, v in pairs(inv.seeds or {}) do
		if not filterZeros or v > 0 then out.seeds[k] = clampNonNegative(v) end
	end
	for k, v in pairs(inv.harvested or {}) do
		if not filterZeros or v > 0 then out.harvested[k] = clampNonNegative(v) end
	end
	return out
end

---------------------------------------------------------------------
-- High-level Domain Helpers (Seeds, Planting, Harvest, Selling)
---------------------------------------------------------------------

-- Adds seeds of a given type. Negative quantity is ignored.
function InventoryUtil.AddSeeds(inv: table, seedType: string, quantity: number)
	seedType = sanitizeKey(seedType)
	if not DEFAULT_SEED_TYPES[seedType] then
		return false, "Unknown seed type"
	end
	quantity = clampNonNegative(quantity)
	InventoryUtil.Add(inv, "seeds", seedType, quantity)
	return true
end

-- Tries to consume seeds for planting. Returns true if consumed.
function InventoryUtil.ConsumeSeedForPlant(inv: table, seedType: string)
	seedType = sanitizeKey(seedType)
	if not DEFAULT_SEED_TYPES[seedType] then
		return false, "Unknown seed type"
	end
	local ok = select(1, InventoryUtil.Take(inv, "seeds", seedType, 1))
	if not ok then
		return false, "No seeds available"
	end
	return true
end

-- Adds harvested crop(s) by type (mirrors seedType in this project).
function InventoryUtil.AddHarvest(inv: table, cropType: string, quantity: number)
	cropType = sanitizeKey(cropType)
	if not DEFAULT_HARVEST_TYPES[cropType] then
		return false, "Unknown crop type"
	end
	quantity = clampNonNegative(quantity)
	InventoryUtil.Add(inv, "harvested", cropType, quantity)
	return true
end

-- Sells harvested items. Returns success, amountSold, coinsEarned.
function InventoryUtil.SellHarvest(inv: table, cropType: string, amount: number, priceTable: table?)
	cropType = sanitizeKey(cropType)
	if not DEFAULT_HARVEST_TYPES[cropType] then
		return false, 0, 0, "Unknown crop type"
	end
	amount = clampNonNegative(amount)
	if amount == 0 then
		return false, 0, 0, "Amount must be > 0"
	end
	local have = InventoryUtil.GetCount(inv, "harvested", cropType)
	if have <= 0 then
		return false, 0, 0, "No harvested items to sell"
	end
	local toSell = math.min(have, amount)
	local prices = priceTable or DEFAULT_CROP_PRICES
	local pricePer = clampNonNegative(prices[cropType] or 0)
	local coins = toSell * pricePer
	InventoryUtil.Add(inv, "harvested", cropType, -toSell)
	return true, toSell, coins
end

---------------------------------------------------------------------
-- Atomic Update Helpers with Per-Player Locking
---------------------------------------------------------------------

-- Very simple per-player lock to avoid concurrent mutations on the same player data.
local Locks = {}  -- [userId] = lockCount

local function acquireLock(userId: number, timeoutSec: number?): boolean
	timeoutSec = timeoutSec or 5
	local start = os.clock()
	while Locks[userId] do
		if os.clock() - start > timeoutSec then
			return false
		end
		task.wait(0.03)
	end
	Locks[userId] = true
	return true
end

local function releaseLock(userId: number)
	Locks[userId] = nil
end

-- Runs a safe, atomic inventory update against DataManager with lock + save.
-- Parameters:
--   player: Player
--   DataManager: module with GetPlayerData(player) and SavePlayerData(player, data)
--   updateFn: function(inv, playerData) -> ok:boolean, err?:string, coinsDelta?:number
--   opts: { notifyEvent: RemoteEvent? } optional event to ping client (RequestInventoryUpdate)
-- Returns ok:boolean, err?:string
function InventoryUtil.AtomicUpdate(player: Player, DataManager: any, updateFn: (any, any)->(boolean, string?, number?), opts: table?)
	if not player or not DataManager then
		return false, "Missing player or DataManager"
	end
	local userId = player.UserId
	if not acquireLock(userId, 6) then
		return false, "Busy, please try again"
	end

	local ok, err
	local coinsDelta = 0

	-- pcall the whole sequence to avoid losing the lock on error
	local success, pErr = pcall(function()
		local data = DataManager.GetPlayerData(player)
		if not data then
			ok = false
			err = "No player data"
			return
		end

		InventoryUtil.EnsureStructure(data)

		local inv = data.inventory
		local uOk, uErr, delta = updateFn(inv, data)
		if not uOk then
			ok, err = false, uErr or "Update failed"
			return
		end

		coinsDelta = clampNonNegative(delta or 0)
		if coinsDelta ~= 0 then
			data.coins = clampNonNegative(safeNumber(data.coins or 0, 0) + coinsDelta)
		end

		-- Save once after mutation
		DataManager.SavePlayerData(player, data)
		ok, err = true, nil

		-- Optionally notify client to refresh its inventory UI
		if opts and opts.notifyEvent then
			opts.notifyEvent:FireClient(player)
		end
	end)

	releaseLock(userId)

	if not success then
		return false, tostring(pErr)
	end
	return ok, err
end

---------------------------------------------------------------------
-- High-level Endpoints that wrap AtomicUpdate for common flows
---------------------------------------------------------------------

-- Buy seeds with coins.
-- seedType: string, quantity: number, seedPrices: table? -> ok, err
function InventoryUtil.BuySeeds(player: Player, DataManager: any, seedType: string, quantity: number, seedPrices: table?, notifyEvent: RemoteEvent?)
	seedType = sanitizeKey(seedType)
	quantity = clampNonNegative(quantity)
	local prices = seedPrices or DEFAULT_SEED_PRICES
	local pricePer = clampNonNegative(prices[seedType] or 0)
	if pricePer == 0 then
		return false, "Unknown seed type"
	end
	local totalCost = pricePer * quantity
	if totalCost <= 0 or quantity == 0 then
		return false, "Invalid quantity"
	end

	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, data)
		local coins = clampNonNegative(safeNumber(data.coins or 0, 0))
		if coins < totalCost then
			return false, "Not enough coins"
		end
		InventoryUtil.AddSeeds(inv, seedType, quantity)
		-- Negative delta reduces coins inside AtomicUpdate
		return true, nil, -totalCost
	end, { notifyEvent = notifyEvent })
end

-- Consume one seed to plant. Just decrements seed; your garden logic handles plot state separately.
function InventoryUtil.ConsumeSeedToPlant(player: Player, DataManager: any, seedType: string, notifyEvent: RemoteEvent?)
	seedType = sanitizeKey(seedType)
	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, _data)
		local ok, reason = InventoryUtil.ConsumeSeedForPlant(inv, seedType)
		if not ok then
			return false, reason or "No seeds available"
		end
		return true
	end, { notifyEvent = notifyEvent })
end

-- Add harvested crop(s) after successful harvest.
function InventoryUtil.AddHarvested(player: Player, DataManager: any, cropType: string, quantity: number, notifyEvent: RemoteEvent?)
	cropType = sanitizeKey(cropType)
	quantity = clampNonNegative(quantity)

	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, _data)
		local ok, reason = InventoryUtil.AddHarvest(inv, cropType, quantity)
		if not ok then
			return false, reason
		end
		return true
	end, { notifyEvent = notifyEvent })
end

-- Sell harvested crops for coins using provided or default prices.
function InventoryUtil.SellHarvested(player: Player, DataManager: any, cropType: string, amount: number, priceTable: table?, notifyEvent: RemoteEvent?)
	cropType = sanitizeKey(cropType)
	amount = clampNonNegative(amount)

	return InventoryUtil.AtomicUpdate(player, DataManager, function(inv, _data)
		local ok, sold, coins, reason = InventoryUtil.SellHarvest(inv, cropType, amount, priceTable or DEFAULT_CROP_PRICES)
		if not ok then
			return false, reason
		end
		-- Positive delta adds coins inside AtomicUpdate
		return true, nil, coins
	end, { notifyEvent = notifyEvent })
end

---------------------------------------------------------------------
-- Convenience: Build a consistent stats payload for clients
---------------------------------------------------------------------

-- Returns a consistent player stats object including inventory view.
function InventoryUtil.BuildPlayerStatsPayload(playerData: table, filterZeros: boolean?): table
	playerData = InventoryUtil.EnsureStructure(playerData)
	return {
		coins = clampNonNegative(safeNumber(playerData.coins or 0, 0)),
		gems = clampNonNegative(safeNumber(playerData.gems or 0, 0)),
		level = clampNonNegative(safeNumber(playerData.level or 1, 1)),
		inventory = InventoryUtil.ToClientView(playerData.inventory, filterZeros),
	}
end

---------------------------------------------------------------------
-- Expose schema so other modules can introspect allowed keys
---------------------------------------------------------------------

function InventoryUtil.GetDefaultSeedTypes()
	local t = {}
	for k in pairs(DEFAULT_SEED_TYPES) do t[k] = true end
	return t
end

function InventoryUtil.GetDefaultHarvestTypes()
	local t = {}
	for k in pairs(DEFAULT_HARVEST_TYPES) do t[k] = true end
	return t
end

function InventoryUtil.GetDefaultSeedPrices()
	return deepCopy(DEFAULT_SEED_PRICES)
end

function InventoryUtil.GetDefaultCropPrices()
	return deepCopy(DEFAULT_CROP_PRICES)
end

return InventoryUtil
