-- EggConfig.lua (ServerScriptService)
-- Configuration for all egg types, costs, and rarity distributions

local EggConfig = {}

-- Egg type definitions with costs and rarity weights
local EggTypes = {
	["basic_lunar"] = {
		name = "Basic Lunar Egg",
		cost = 100,
		hatchTime = 60, -- 1 minute
		color = Color3.fromRGB(200, 230, 255),
		rarityWeights = {
			Common = 80,
			Uncommon = 15,
			Rare = 4,
			Epic = 0.8,
			Legendary = 0.2
		}
	},
	["stellar"] = {
		name = "Stellar Egg",
		cost = 500,
		hatchTime = 180, -- 3 minutes
		color = Color3.fromRGB(255, 215, 100),
		rarityWeights = {
			Common = 60,
			Uncommon = 25,
			Rare = 12,
			Epic = 2.5,
			Legendary = 0.5
		}
	},
	["cosmic"] = {
		name = "Cosmic Egg",
		cost = 2000,
		hatchTime = 300, -- 5 minutes
		color = Color3.fromRGB(150, 100, 255),
		rarityWeights = {
			Common = 40,
			Uncommon = 30,
			Rare = 22,
			Epic = 7,
			Legendary = 1
		}
	},
	["divine"] = {
		name = "Divine Egg",
		cost = 10000,
		hatchTime = 600, -- 10 minutes
		color = Color3.fromRGB(255, 215, 0),
		rarityWeights = {
			Common = 20,
			Uncommon = 25,
			Rare = 30,
			Epic = 20,
			Legendary = 5
		}
	}
}

-- Validate if egg type exists
function EggConfig.IsValidEggType(eggType)
	return EggTypes[eggType] ~= nil
end

-- Get configuration for specific egg type
function EggConfig.GetEggConfig(eggType)
	return EggTypes[eggType]
end

-- Get all available egg types
function EggConfig.GetAllEggTypes()
	local types = {}
	for eggType, _ in pairs(EggTypes) do
		table.insert(types, eggType)
	end
	return types
end

-- Calculate rarity based on roll and egg type
function EggConfig.GetRarityFromRoll(eggType, roll)
	local config = EggTypes[eggType]
	if not config then return "Common" end

	local weights = config.rarityWeights
	local totalWeight = 0

	-- Calculate cumulative weights
	local cumulativeWeights = {}
	for rarity, weight in pairs(weights) do
		totalWeight = totalWeight + weight
		cumulativeWeights[rarity] = totalWeight
	end

	-- Determine rarity based on roll
	local rarityOrder = {"Legendary", "Epic", "Rare", "Uncommon", "Common"}
	for _, rarity in ipairs(rarityOrder) do
		if roll <= cumulativeWeights[rarity] then
			return rarity
		end
	end

	return "Common" -- Fallback
end

-- Get egg shop display data
function EggConfig.GetShopDisplayData()
	local shopData = {}
	for eggType, config in pairs(EggTypes) do
		table.insert(shopData, {
			id = eggType,
			name = config.name,
			cost = config.cost,
			hatchTime = config.hatchTime,
			color = config.color,
			rarities = config.rarityWeights
		})
	end

	-- Sort by cost
	table.sort(shopData, function(a, b) return a.cost < b.cost end)
	return shopData
end

return EggConfig