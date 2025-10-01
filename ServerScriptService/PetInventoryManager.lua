-- PetInventoryManager.lua (ServerScriptService)
-- Manages pet storage, active slots, trading, fusion, and selling

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local PetConfig = require(script.Parent:WaitForChild("PetConfig"))

local PetInventoryManager = {}

-- Pet ID counter cache
local playerPetIdCounters = {}

-- Load pet data and initialize pet ID counter
local function initializePetData(player)
	local petData = DataManager.LoadPetData(player)
	local userId = tostring(player.UserId)
	playerPetIdCounters[userId] = petData.nextPetId or 1
	return petData
end

-- Generate unique pet ID for player
local function generatePetId(player)
	local userId = tostring(player.UserId)
	if not playerPetIdCounters[userId] then
		playerPetIdCounters[userId] = 1
	end
	local id = playerPetIdCounters[userId]
	playerPetIdCounters[userId] = id + 1
	return id
end

-- Add a new pet to player's inventory
function PetInventoryManager.AddPet(player, petTemplate)
	if not PetConfig.ValidatePet(petTemplate) then
		return false
	end

	local petData = initializePetData(player)
	local petId = generatePetId(player)

	-- Create pet instance
	local petInstance = {
		id = petId,
		templateId = petTemplate.id,
		name = petTemplate.name,
		rarity = petTemplate.rarity,
		abilities = petTemplate.abilities,
		dateObtained = os.time(),
		level = 1,
		experience = 0,
		sellValue = petTemplate.sellValue
	}

	-- Add to storage
	table.insert(petData.storedPets, petInstance)
	petData.nextPetId = playerPetIdCounters[tostring(player.UserId)]

	-- Try to auto-equip if there's an empty active slot
	for i = 1, 3 do
		if not petData.activePets[i] then
			petData.activePets[i] = petId
			break
		end
	end

	-- Update stats
	DataManager.UpdatePlayerStats(player, "petsOwned", 1)

	-- Save data
	DataManager.SavePetData()(player, petData)

	return petId
end

-- Get all pet data for a player
function PetInventoryManager.GetPlayerPets(player)
	return initializePetData(player)
end

-- Get specific pet by ID
function PetInventoryManager.GetPetById(player, petId)
	local petData = initializePetData(player)

	for _, pet in ipairs(petData.storedPets) do
		if pet.id == petId then
			return pet
		end
	end

	return nil
end

-- Get active pets
function PetInventoryManager.GetActivePets(player)
	local petData = initializePetData(player)
	local activePets = {}

	for i = 1, 3 do
		local petId = petData.activePets[i]
		if petId then
			local pet = PetInventoryManager.GetPetById(player, petId)
			if pet then
				activePets[i] = pet
			else
				-- Clean up invalid reference
				petData.activePets[i] = nil
				DataManager.SavePetData(player, petData)
			end
		end
	end

	return activePets
end

-- Equip pet to active slot
function PetInventoryManager.EquipPet(player, petId, slot)
	if slot < 1 or slot > 3 then return false end

	local petData = initializePetData(player)
	local pet = PetInventoryManager.GetPetById(player, petId)

	if not pet then return false end

	-- Unequip any pet currently in this slot
	petData.activePets[slot] = petId

	-- Remove from other slots if already equipped
	for i = 1, 3 do
		if i ~= slot and petData.activePets[i] == petId then
			petData.activePets[i] = nil
		end
	end

	DataManager.SavePetData(player, petData)
	return true
end

-- Unequip pet from active slot
function PetInventoryManager.UnequipPet(player, slot)
	if slot < 1 or slot > 3 then return false end

	local petData = initializePetData(player)
	petData.activePets[slot] = nil

	DataManager.SavePetData(player, petData)
	return true
end

-- Sell pet for coins
function PetInventoryManager.SellPet(player, petId)
	local petData = initializePetData(player)
	local pet = PetInventoryManager.GetPetById(player, petId)

	if not pet then return false end

	-- Calculate sell value (base value + level bonus)
	local sellValue = pet.sellValue + (pet.level - 1) * 10

	-- Remove from active slots
	for i = 1, 3 do
		if petData.activePets[i] == petId then
			petData.activePets[i] = nil
		end
	end

	-- Remove from storage
	for i, storedPet in ipairs(petData.storedPets) do
		if storedPet.id == petId then
			table.remove(petData.storedPets, i)
			break
		end
	end

	-- Give coins to player
	DataManager.AddCoins(player, sellValue)
	DataManager.UpdatePlayerStats(player, "petsOwned", -1)

	-- Save data
	DataManager.SavePetData(player, petData)

	-- Notify player
	ReplicatedStorage:FindFirstChild("ShowFeedback"):FireClient(player,
		string.format("Sold %s for %d coins!", pet.name, sellValue), "success")

	return true
end

-- Fuse two pets to create a stronger version
function PetInventoryManager.FusePets(player, petId1, petId2)
	local petData = initializePetData(player)
	local pet1 = PetInventoryManager.GetPetById(player, petId1)
	local pet2 = PetInventoryManager.GetPetById(player, petId2)

	if not pet1 or not pet2 then return false end
	if pet1.templateId ~= pet2.templateId then return false end -- Must be same pet type

	-- Create fused pet (higher level, enhanced abilities)
	local fusedLevel = math.max(pet1.level, pet2.level) + 1
	local fusedPet = {
		id = generatePetId(player),
		templateId = pet1.templateId,
		name = pet1.name .. " ?",
		rarity = pet1.rarity,
		abilities = pet1.abilities, -- Could enhance abilities here
		dateObtained = os.time(),
		level = fusedLevel,
		experience = 0,
		sellValue = pet1.sellValue * 2,
		fused = true
	}

	-- Remove original pets
	PetInventoryManager.RemovePetById(player, petId1)
	PetInventoryManager.RemovePetById(player, petId2)

	-- Add fused pet
	table.insert(petData.storedPets, fusedPet)
	petData.nextPetId = playerPetIdCounters[tostring(player.UserId)]

	-- Save data
	DataManager.SavePetData(player, petData)

	-- Notify player
	ReplicatedStorage:FindFirstChild("ShowFeedback"):FireClient(player,
		string.format("Fused into %s (Level %d)!", fusedPet.name, fusedPet.level), "success")

	return fusedPet.id
end

-- Remove pet by ID (internal function)
function PetInventoryManager.RemovePetById(player, petId)
	local petData = initializePetData(player)

	-- Remove from active slots
	for i = 1, 3 do
		if petData.activePets[i] == petId then
			petData.activePets[i] = nil
		end
	end

	-- Remove from storage
	for i, pet in ipairs(petData.storedPets) do
		if pet.id == petId then
			table.remove(petData.storedPets, i)
			return true
		end
	end

	return false
end

-- Get inventory statistics
function PetInventoryManager.GetInventoryStats(player)
	local petData = initializePetData(player)
	local stats = {
		totalPets = #petData.storedPets,
		activePets = 0,
		rarityCount = {
			Common = 0,
			Uncommon = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0
		}
	}

	-- Count active pets
	for i = 1, 3 do
		if petData.activePets[i] then
			stats.activePets = stats.activePets + 1
		end
	end

	-- Count by rarity
	for _, pet in ipairs(petData.storedPets) do
		if stats.rarityCount[pet.rarity] then
			stats.rarityCount[pet.rarity] = stats.rarityCount[pet.rarity] + 1
		end
	end

	return stats
end

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	local userId = tostring(player.UserId)
	playerPetIdCounters[userId] = nil
end)

return PetInventoryManager