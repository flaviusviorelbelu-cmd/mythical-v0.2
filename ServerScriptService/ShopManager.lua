--ShopManager.lua
-- Optimized ShopManager Module (ServerScriptService.ShopManager)
-- Enhanced with debugging, better error handling, and comprehensive shop system

local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local Players              = game:GetService("Players")

local DEBUG_MODE = true
local function debugLog(message, level)
	level = level or "INFO"
	if DEBUG_MODE then
		print("[ShopManager] [" .. level .. "] " .. tostring(message))
	end
end

-- Safe module loading
local function safeRequire(moduleName)
	local success, module = pcall(function()
		return require(game.ServerScriptService:WaitForChild(moduleName, 10))
	end)
	if not success then
		debugLog("Failed to load module: " .. moduleName, "ERROR")
		return nil
	end
	debugLog("Successfully loaded module: " .. moduleName)
	return module
end

-- Load required modules
local DataManager         = safeRequire("DataManager")
local EggManager          = safeRequire("EggManager")
local PetAbilityManager   = safeRequire("PetAbilityManager")

local ShopManager = {}

-- Enhanced shop configuration with validation
local SEED_PRICES = {
	carrot    = {price=5,  category="basic",  unlockLevel=1,  description="Fast-growing orange vegetables"},
	potato    = {price=7,  category="basic",  unlockLevel=1,  description="Hearty root vegetables"},
	wheat     = {price=3,  category="basic",  unlockLevel=1,  description="Basic grain crop"},
	moonberry = {price=12, category="lunar",  unlockLevel=5,  description="Sweet berries under moonlight"},
	stardust  = {price=8,  category="lunar",  unlockLevel=3,  description="Seeds infused with cosmic dust"},
	solar     = {price=6,  category="lunar",  unlockLevel=2,  description="Radiant seeds warmed by solar flares"},
	nebula    = {price=15, category="cosmic", unlockLevel=10, description="Swirling nebular energy"},
	cosmic    = {price=10, category="cosmic", unlockLevel=8,  description="Mystical seeds charged by the cosmos"},
	asteroid  = {price=20, category="cosmic", unlockLevel=15, description="Forged in asteroid impacts"},
}

local PLANT_SELL_PRICES = {
	carrot    = {price=8,  baseYield=2},
	potato    = {price=12, baseYield=3},
	wheat     = {price=6,  baseYield=4},
	moonberry = {price=20, baseYield=2},
	stardust  = {price=14, baseYield=3},
	solar     = {price=11, baseYield=3},
	nebula    = {price=25, baseYield=2},
	cosmic    = {price=18, baseYield=3},
	asteroid  = {price=35, baseYield=1},
}

local TOOL_PRICES = {
	basicWateringCan = {price=50,  category="tools",       description="Waters plants manually"},
	autoWateringCan  = {price=200, category="tools",       description="Waters plants automatically"},
	fertilizer       = {price=10,  category="consumable",  description="Speeds up plant growth"},
	petFood          = {price=15,  category="consumable",  description="Feed your pets to gain XP"},
}

-- Validate transaction parameters
local function validateTransaction(player, itemType, quantity, price)
	if not player or not player.UserId then
		return false, "Invalid player"
	end
	if type(itemType) ~= "string" or itemType == "" then
		return false, "Invalid item type"
	end
	if type(quantity) ~= "number" or quantity <= 0 or quantity ~= math.floor(quantity) then
		return false, "Invalid quantity"
	end
	if type(price) ~= "number" or price < 0 then
		return false, "Invalid price"
	end
	return true, "Valid"
end

-- Buy an egg
function ShopManager.BuyEgg(player, eggType)
	debugLog("Processing egg purchase - Player: " .. player.Name .. ", Type: " .. tostring(eggType))
	if not EggManager or type(EggManager.BuyEgg) ~= "function" then
		debugLog("EggManager.BuyEgg not available", "ERROR")
		return false, "Egg system unavailable"
	end
	local success, result = pcall(EggManager.BuyEgg, player, eggType)
	if not success then
		debugLog("Error in EggManager.BuyEgg: "..tostring(result), "ERROR")
		return false, "Error processing egg purchase"
	end
	if result then
		debugLog("Egg purchase successful for " .. player.Name)
		return true, "Egg purchased successfully!"
	else
		debugLog("Egg purchase failed for " .. player.Name, "WARN")
		return false, "Not enough coins or invalid egg type"
	end
end

-- Buy a seed
function ShopManager.BuySeed(player, seedType, quantity)
	quantity = quantity or 1
	debugLog("Processing seed purchase - Player: " .. player.Name .. ", Seed: " .. seedType .. ", Quantity: " .. quantity)
	if not DataManager or type(DataManager.GetPlayerData) ~= "function" then
		debugLog("DataManager not available", "ERROR")
		return false, "Data system unavailable"
	end
	local playerData = DataManager.GetPlayerData(player)
	if not playerData then
		return false, "Player data not found"
	end
	local cfg = SEED_PRICES[seedType]
	if not cfg then
		return false, "Invalid seed type"
	end
	if playerData.level < cfg.unlockLevel then
		return false, "Requires level " .. cfg.unlockLevel
	end
	local total = cfg.price * quantity
	local ok, err = validateTransaction(player, seedType, quantity, total)
	if not ok then
		return false, err
	end
	if playerData.coins < total then
		return false, "Not enough coins. Need " .. total .. ", have " .. playerData.coins
	end
	playerData.coins = playerData.coins - total
	playerData.seeds = playerData.seeds or {}
	playerData.seeds[seedType] = (playerData.seeds[seedType] or 0) + quantity
	playerData.stats = playerData.stats or {}
	playerData.stats.totalSeedsPurchased = (playerData.stats.totalSeedsPurchased or 0) + quantity
	playerData.stats.totalCoinsSpent = (playerData.stats.totalCoinsSpent or 0) + total
	if not DataManager.SavePlayerData(player, playerData) then
		return false, "Failed to save purchase"
	end
	debugLog("Seed purchase complete for " .. player.Name)
	spawn(function()
		local fb = ReplicatedStorage:FindFirstChild("ShowFeedback")
		if fb then fb:FireClient(player, "Bought "..quantity.."x "..seedType.." seeds for "..total.." coins!", "success") end
	end)
	return true, "Successfully bought "..quantity.."x "..seedType.." seeds"
end

-- Sell harvested crops
function ShopManager.SellHarvest(player, plantType, quantity)
	quantity = quantity or 1
	debugLog("Processing harvest sale - Player: " .. player.Name .. ", Plant: " .. plantType .. ", Quantity: " .. quantity)
	if not DataManager or type(DataManager.GetPlayerData) ~= "function" then
		return false, "Data system unavailable"
	end
	local pd = DataManager.GetPlayerData(player)
	if not pd then
		return false, "Player data not found"
	end
	pd.harvest = pd.harvest or {}
	local owned = pd.harvest[plantType] or 0
	if owned < quantity then
		return false, "Not enough "..plantType.." to sell (have "..owned..")"
	end
	local cfg = PLANT_SELL_PRICES[plantType]
	if not cfg then
		return false, "Cannot sell "..plantType
	end
	local total = cfg.price * quantity
	if PetAbilityManager and PetAbilityManager.ApplyCoinBonus then
		total = PetAbilityManager.ApplyCoinBonus(player, total)
	end
	local ok, err = validateTransaction(player, plantType, quantity, total)
	if not ok then
		return false, err
	end
	pd.harvest[plantType] = owned - quantity
	pd.coins = (pd.coins or 0) + total
	pd.stats = pd.stats or {}
	pd.stats.totalPlantsSold = (pd.stats.totalPlantsSold or 0) + quantity
	pd.stats.totalCoinsEarned = (pd.stats.totalCoinsEarned or 0) + total
	if not DataManager.SavePlayerData(player, pd) then
		return false, "Failed to save sale"
	end
	spawn(function()
		local fb = ReplicatedStorage:FindFirstChild("ShowFeedback")
		if fb then fb:FireClient(player, "Sold "..quantity.."x "..plantType.." for "..total.." coins!", "success") end
	end)
	return true, "Sold "..quantity.." "..plantType.." for "..total.." coins"
end

-- Buy tools and consumables
function ShopManager.BuyTool(player, toolType, quantity)
	quantity = quantity or 1
	debugLog("Processing tool purchase - Player: " .. player.Name .. ", Tool: " .. toolType .. ", Quantity: " .. quantity)
	if not TOOL_PRICES[toolType] then
		return false, "Invalid tool type"
	end
	local pd = DataManager.GetPlayerData(player)
	if not pd then
		return false, "Player data not found"
	end
	local total = TOOL_PRICES[toolType].price * quantity
	if pd.coins < total then
		return false, "Not enough coins. Need "..total..", have "..pd.coins
	end
	pd.coins = pd.coins - total
	pd.items = pd.items or {}
	pd.items[toolType] = (pd.items[toolType] or 0) + quantity
	DataManager.SavePlayerData(player, pd)
	return true, "Bought "..quantity.."x "..toolType
end

-- Backwards compatibility
function ShopManager.SellPlant(player, plantType, quantity)
	return ShopManager.SellHarvest(player, plantType, quantity)
end

-- UI Price Tables
function ShopManager.GetSeedPrices()
	local t = {}
	for k,v in pairs(SEED_PRICES) do t[k] = v.price end
	return t
end

function ShopManager.GetPlantSellPrices()
	local t = {}
	for k,v in pairs(PLANT_SELL_PRICES) do t[k] = v.price end
	return t
end

-- Get shop data for UI, level-gated
function ShopManager.GetShopData(shopType, playerLevel)
	playerLevel = playerLevel or 1
	debugLog("Fetching shop data for "..shopType.." at level "..playerLevel)
	if shopType == "SeedShop" then
		local items = {}
		for id, cfg in pairs(SEED_PRICES) do
			if playerLevel >= cfg.unlockLevel then
				table.insert(items, {
					id=id, name="?? "..id:gsub("^%l", string.upper).." Seeds",
					price=cfg.price, desc=cfg.description,
					unlockLevel=cfg.unlockLevel, category=cfg.category
				})
			end
		end
		table.sort(items, function(a,b)
			if a.unlockLevel ~= b.unlockLevel then
				return a.unlockLevel < b.unlockLevel
			end
			return a.price < b.price
		end)
		return items

	elseif shopType == "AnimalShop" then
		return {
			{id="Basic",   name="?? Moon Rabbit Egg",  price=100, desc="Common pets"},
			{id="Stellar", name="? Stellar Egg",       price=500, desc="Uncommon pets"},
			{id="Cosmic",  name="?? Cosmic Egg",        price=1000,desc="Rare pets"},
			{id="Divine",  name="? Divine Egg",        price=10000,desc="Legendary pets"}
		}

	elseif shopType == "GearShop" then
		local list = {}
		for id,cfg in pairs(TOOL_PRICES) do
			table.insert(list, {
				id=id, name=id:gsub("([A-Z])"," %1"):gsub("^%l",string.upper),
				price=cfg.price, desc=cfg.description,
				category=cfg.category
			})
		end
		return list

	elseif shopType == "CraftingStation" then
		return {
			{id="upgrade_seeds",    name="?? Upgrade Seeds",    price=100, desc="Upgrade seeds"},
			{id="craft_fertilizer", name="?? Craft Fertilizer", price=50,  desc="Make fertilizer"},
			{id="pet_treats",       name="?? Pet Treats",       price=75,  desc="Special pet food"}
		}
	end

	debugLog("Unknown shop type: "..tostring(shopType), "WARN")
	return {}
end

-- Get shop data for a specific player
function ShopManager.GetShopDataForPlayer(player, shopType)
	local pd = DataManager and DataManager.GetPlayerData(player)
	local lvl = pd and pd.level or 1
	return ShopManager.GetShopData(shopType, lvl)
end

-- Debug functions
function ShopManager.DebugShopConfig()
	debugLog("=== Shop Configuration Debug ===")
	for id,cfg in pairs(SEED_PRICES) do debugLog("Seed "..id..": "..cfg.price.." coins, unlock "..cfg.unlockLevel) end
	for id,cfg in pairs(PLANT_SELL_PRICES) do debugLog("Sell "..id..": "..cfg.price.." coins") end
	for id,cfg in pairs(TOOL_PRICES) do debugLog("Tool "..id..": "..cfg.price.." coins") end
end

_G.debugShopManager = ShopManager.DebugShopConfig

debugLog("ShopManager module loaded successfully!")
return ShopManager
