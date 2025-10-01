-- PetConfig.lua (ServerScriptService)
-- Configuration for all pet types, rarities, and abilities

local PetConfig = {}

-- Pet definitions organized by rarity
local PetsByRarity = {
	Common = {
		{
			id = "stardust_bunny",
			name = "Stardust Bunny",
			description = "Increases plant growth speed by 10%",
			abilities = {
				{type = "growth_speed", value = 1.1, passive = true}
			},
			sellValue = 50,
			modelId = "rbxasset://models/pets/bunny.rbxm" -- Placeholder
		},
		{
			id = "cosmic_mouse",
			name = "Cosmic Mouse", 
			description = "Finds extra seeds (5% chance per harvest)",
			abilities = {
				{type = "seed_bonus", value = 0.05, passive = true}
			},
			sellValue = 45,
			modelId = "rbxasset://models/pets/mouse.rbxm"
		},
		{
			id = "moon_worm",
			name = "Moon Worm",
			description = "Provides natural fertilizer every 5 minutes",
			abilities = {
				{type = "fertilizer_gen", value = 300, passive = false, cooldown = 300}
			},
			sellValue = 40,
			modelId = "rbxasset://models/pets/worm.rbxm"
		}
	},
	Uncommon = {
		{
			id = "nebula_cat",
			name = "Nebula Cat",
			description = "Increases harvest yield by 15%",
			abilities = {
				{type = "harvest_yield", value = 1.15, passive = true}
			},
			sellValue = 150,
			modelId = "rbxasset://models/pets/cat.rbxm"
		},
		{
			id = "solar_puppy",
			name = "Solar Puppy",
			description = "Automatically waters plants every 10 minutes",
			abilities = {
				{type = "auto_water", value = 600, passive = false, cooldown = 600}
			},
			sellValue = 140,
			modelId = "rbxasset://models/pets/puppy.rbxm"
		},
		{
			id = "meteor_hamster",
			name = "Meteor Hamster",
			description = "Doubles coin drops from selling crops",
			abilities = {
				{type = "coin_multiplier", value = 2.0, passive = true}
			},
			sellValue = 160,
			modelId = "rbxasset://models/pets/hamster.rbxm"
		}
	},
	Rare = {
		{
			id = "galaxy_wolf",
			name = "Galaxy Wolf",
			description = "Increases XP gain by 25%",
			abilities = {
				{type = "xp_multiplier", value = 1.25, passive = true}
			},
			sellValue = 400,
			modelId = "rbxasset://models/pets/wolf.rbxm"
		},
		{
			id = "starlight_phoenix",
			name = "Starlight Phoenix",
			description = "Prevents plant diseases and pests",
			abilities = {
				{type = "disease_immunity", value = 1.0, passive = true}
			},
			sellValue = 450,
			modelId = "rbxasset://models/pets/phoenix.rbxm"
		},
		{
			id = "comet_dragon",
			name = "Comet Dragon",
			description = "Can harvest multiple plots at once",
			abilities = {
				{type = "multi_harvest", value = 3, passive = false, cooldown = 1800}
			},
			sellValue = 500,
			modelId = "rbxasset://models/pets/dragon.rbxm"
		}
	},
	Epic = {
		{
			id = "void_panther",
			name = "Void Panther",
			description = "Triples rare plant spawn chances",
			abilities = {
				{type = "rare_plant_chance", value = 3.0, passive = true}
			},
			sellValue = 1200,
			modelId = "rbxasset://models/pets/panther.rbxm"
		},
		{
			id = "aurora_bear",
			name = "Aurora Bear",
			description = "Generates premium currency over time",
			abilities = {
				{type = "gem_generation", value = 1, passive = false, cooldown = 3600}
			},
			sellValue = 1500,
			modelId = "rbxasset://models/pets/bear.rbxm"
		},
		{
			id = "quantum_fox",
			name = "Quantum Fox",
			description = "Can duplicate harvested crops (20% chance)",
			abilities = {
				{type = "crop_duplication", value = 0.20, passive = true}
			},
			sellValue = 1300,
			modelId = "rbxasset://models/pets/fox.rbxm"
		}
	},
	Legendary = {
		{
			id = "cosmic_guardian",
			name = "Cosmic Guardian",
			description = "Provides all basic pet benefits",
			abilities = {
				{type = "growth_speed", value = 1.1, passive = true},
				{type = "harvest_yield", value = 1.15, passive = true},
				{type = "coin_multiplier", value = 1.5, passive = true},
				{type = "xp_multiplier", value = 1.25, passive = true}
			},
			sellValue = 5000,
			modelId = "rbxasset://models/pets/guardian.rbxm"
		},
		{
			id = "celestial_deity",
			name = "Celestial Deity",
			description = "Multiplies ALL farm income by 2x",
			abilities = {
				{type = "income_multiplier", value = 2.0, passive = true}
			},
			sellValue = 8000,
			modelId = "rbxasset://models/pets/deity.rbxm"
		},
		{
			id = "universe_spirit",
			name = "Universe Spirit",
			description = "Unlocks secret plant varieties",
			abilities = {
				{type = "unlock_secrets", value = 1.0, passive = true},
				{type = "growth_speed", value = 1.2, passive = true}
			},
			sellValue = 10000,
			modelId = "rbxasset://models/pets/spirit.rbxm"
		}
	}
}

-- Get pets by rarity
function PetConfig.GetPetsByRarity(rarity)
	return PetsByRarity[rarity] or {}
end

-- Get all pets
function PetConfig.GetAllPets()
	local allPets = {}
	for rarity, pets in pairs(PetsByRarity) do
		for _, pet in ipairs(pets) do
			local petCopy = {}
			for k, v in pairs(pet) do
				petCopy[k] = v
			end
			petCopy.rarity = rarity
			table.insert(allPets, petCopy)
		end
	end
	return allPets
end

-- Get specific pet by ID
function PetConfig.GetPetById(petId)
	for rarity, pets in pairs(PetsByRarity) do
		for _, pet in ipairs(pets) do
			if pet.id == petId then
				local petCopy = {}
				for k, v in pairs(pet) do
					petCopy[k] = v
				end
				petCopy.rarity = rarity
				return petCopy
			end
		end
	end
	return nil
end

-- Get pet sell value by rarity
function PetConfig.GetBaseSellValue(rarity)
	local values = {
		Common = 50,
		Uncommon = 150,
		Rare = 400,
		Epic = 1200,
		Legendary = 5000
	}
	return values[rarity] or 50
end

-- Get rarity color for UI
function PetConfig.GetRarityColor(rarity)
	local colors = {
		Common = Color3.fromRGB(150, 150, 150),    -- Gray
		Uncommon = Color3.fromRGB(0, 255, 0),      -- Green  
		Rare = Color3.fromRGB(0, 100, 255),        -- Blue
		Epic = Color3.fromRGB(160, 32, 240),       -- Purple
		Legendary = Color3.fromRGB(255, 215, 0)    -- Gold
	}
	return colors[rarity] or colors.Common
end

-- Validate pet data structure
function PetConfig.ValidatePet(pet)
	if not pet or type(pet) ~= "table" then return false end
	if not pet.id or not pet.name or not pet.abilities then return false end
	if not pet.sellValue or type(pet.sellValue) ~= "number" then return false end
	return true
end

return PetConfig