-- PetAbilityManager.lua (ServerScriptService)
-- Handles pet abilities, bonuses, and their effects on farming

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local PetInventoryManager = require(script.Parent:WaitForChild("PetInventoryManager"))
local PetVisualSystem = require(script.Parent:WaitForChild("PetVisualSystem"))

local PetAbilityManager = {}

-- Configuration
local CONFIG = {
	ABILITY_CHECK_INTERVAL = 30, -- seconds
	DEBUG_MODE = true
}

-- Active abilities tracking
local activeAbilities = {} -- player -> {abilityType -> {pets with this ability}}
local abilityCooldowns = {} -- player -> petId -> abilityType -> nextUseTime
local lastAbilityCheck = 0

-- Debug logging
local function debugLog(message, level)
	if CONFIG.DEBUG_MODE then
		level = level or "INFO"
		print(string.format("[PetAbilityManager][%s] %s", level, tostring(message)))
	end
end

-- Initialize ability tracking for player
local function initializePlayerAbilities(player)
	if not activeAbilities[player] then
		activeAbilities[player] = {}
	end
	if not abilityCooldowns[player] then
		abilityCooldowns[player] = {}
	end
end

-- Update active abilities for a player based on their equipped pets
function PetAbilityManager.UpdatePlayerAbilities(player)
	initializePlayerAbilities(player)

	-- Clear current abilities
	activeAbilities[player] = {}

	-- Get active pets and their abilities
	local activePets = PetInventoryManager.GetActivePets(player)

	for slotIndex, pet in pairs(activePets) do
		if pet and pet.abilities then
			for _, ability in ipairs(pet.abilities) do
				local abilityType = ability.type

				-- Initialize ability type if not exists
				if not activeAbilities[player][abilityType] then
					activeAbilities[player][abilityType] = {}
				end

				-- Add pet to this ability type
				table.insert(activeAbilities[player][abilityType], {
					pet = pet,
					ability = ability,
					slotIndex = slotIndex
				})
			end
		end
	end

	debugLog(string.format("Updated abilities for player %s", player.Name))
end

-- Get multiplier for a specific ability type
function PetAbilityManager.GetAbilityMultiplier(player, abilityType)
	initializePlayerAbilities(player)

	local multiplier = 1.0
	local abilities = activeAbilities[player][abilityType]

	if abilities then
		for _, abilityData in ipairs(abilities) do
			if abilityData.ability.passive then
				-- Apply passive multiplier
				if abilityType == "growth_speed" or abilityType == "harvest_yield" or 
					abilityType == "coin_multiplier" or abilityType == "xp_multiplier" or
					abilityType == "income_multiplier" then
					multiplier = multiplier * abilityData.ability.value
				elseif abilityType == "crop_duplication" or abilityType == "seed_bonus" or
					abilityType == "rare_plant_chance" then
					-- These are probability-based, not multiplicative
					multiplier = math.max(multiplier, abilityData.ability.value)
				end
			end
		end
	end

	return multiplier
end

-- Check if player has a specific ability
function PetAbilityManager.HasAbility(player, abilityType)
	initializePlayerAbilities(player)
	local abilities = activeAbilities[player][abilityType]
	return abilities and #abilities > 0
end

-- Get chance-based bonus (for duplication, extra seeds, etc.)
function PetAbilityManager.GetChanceBonus(player, abilityType)
	initializePlayerAbilities(player)

	local chance = 0
	local abilities = activeAbilities[player][abilityType]

	if abilities then
		for _, abilityData in ipairs(abilities) do
			if abilityData.ability.passive then
				chance = chance + abilityData.ability.value
			end
		end
	end

	return math.min(chance, 1.0) -- Cap at 100%
end

-- Trigger active ability if off cooldown
function PetAbilityManager.TriggerActiveAbility(player, abilityType)
	initializePlayerAbilities(player)

	local abilities = activeAbilities[player][abilityType]
	if not abilities then return false end

	local currentTime = os.time()
	local triggered = false

	for _, abilityData in ipairs(abilities) do
		if not abilityData.ability.passive then
			local petId = abilityData.pet.id
			local cooldown = abilityData.ability.cooldown or 0

			-- Initialize cooldown tracking
			if not abilityCooldowns[player][petId] then
				abilityCooldowns[player][petId] = {}
			end

			local nextUseTime = abilityCooldowns[player][petId][abilityType] or 0

			if currentTime >= nextUseTime then
				-- Trigger ability
				if abilityType == "fertilizer_gen" then
					PetAbilityManager.ApplyFertilizerGeneration(player, abilityData)
				elseif abilityType == "auto_water" then
					PetAbilityManager.ApplyAutoWatering(player, abilityData)
				elseif abilityType == "multi_harvest" then
					PetAbilityManager.ApplyMultiHarvest(player, abilityData)
				elseif abilityType == "gem_generation" then
					PetAbilityManager.ApplyGemGeneration(player, abilityData)
				end

				-- Set cooldown
				abilityCooldowns[player][petId][abilityType] = currentTime + cooldown
				triggered = true

				-- Trigger visual effect
				PetVisualSystem.TriggerPetAbilityEffect(player, petId, abilityType)

				debugLog(string.format("Triggered %s ability for player %s", abilityType, player.Name))
			end
		end
	end

	return triggered
end

-- Apply fertilizer generation ability
function PetAbilityManager.ApplyFertilizerGeneration(player, abilityData)
	local playerData = DataManager.GetPlayerData(player)
	if playerData then
		if not playerData.inventory.fertilizers then
			playerData.inventory.fertilizers = {}
		end
		playerData.inventory.fertilizers.basic = (playerData.inventory.fertilizers.basic or 0) + 1
		DataManager.SavePlayerData(player, playerData)

		-- Notify player
		local showFeedback = ReplicatedStorage:FindFirstChild("ShowFeedback")
		if showFeedback then
			showFeedback:FireClient(player, "?? " .. abilityData.pet.name .. " generated fertilizer!", "info")
		end
	end
end

-- Apply auto-watering ability
function PetAbilityManager.ApplyAutoWatering(player, abilityData)
	-- This would interact with your plant growing system
	-- For now, just notify the player
	local showFeedback = ReplicatedStorage:FindFirstChild("ShowFeedback")
	if showFeedback then
		showFeedback:FireClient(player, "?? " .. abilityData.pet.name .. " watered your plants!", "info")
	end

	-- TODO: Actually water plants in player's garden
	debugLog("Auto-watering triggered for " .. player.Name)
end

-- Apply multi-harvest ability
function PetAbilityManager.ApplyMultiHarvest(player, abilityData)
	local harvestCount = abilityData.ability.value or 3

	-- Notify player
	local showFeedback = ReplicatedStorage:FindFirstChild("ShowFeedback")
	if showFeedback then
		showFeedback:FireClient(player, "?? " .. abilityData.pet.name .. " can harvest " .. harvestCount .. " plots at once!", "success")
	end

	-- TODO: Implement actual multi-harvest logic
	debugLog("Multi-harvest activated for " .. player.Name)
end

-- Apply gem generation ability
function PetAbilityManager.ApplyGemGeneration(player, abilityData)
	local gemAmount = abilityData.ability.value or 1

	DataManager.AddGems(player, gemAmount)

	-- Notify player
	local showFeedback = ReplicatedStorage:FindFirstChild("ShowFeedback")
	if showFeedback then
		showFeedback:FireClient(player, "?? " .. abilityData.pet.name .. " generated " .. gemAmount .. " gems!", "success")
	end
end

-- Apply growth speed bonus to plant
function PetAbilityManager.ApplyGrowthSpeedBonus(player, originalGrowTime)
	local multiplier = PetAbilityManager.GetAbilityMultiplier(player, "growth_speed")
	return originalGrowTime / multiplier -- Faster growth = less time
end

-- Apply harvest yield bonus
function PetAbilityManager.ApplyHarvestYieldBonus(player, originalYield)
	local multiplier = PetAbilityManager.GetAbilityMultiplier(player, "harvest_yield")
	return math.floor(originalYield * multiplier)
end

-- Apply coin multiplier bonus
function PetAbilityManager.ApplyCoinMultiplier(player, originalCoins)
	local multiplier = PetAbilityManager.GetAbilityMultiplier(player, "coin_multiplier")
	local incomeMultiplier = PetAbilityManager.GetAbilityMultiplier(player, "income_multiplier")
	return math.floor(originalCoins * multiplier * incomeMultiplier)
end

-- Apply XP multiplier bonus
function PetAbilityManager.ApplyXPMultiplier(player, originalXP)
	local multiplier = PetAbilityManager.GetAbilityMultiplier(player, "xp_multiplier")
	return math.floor(originalXP * multiplier)
end

-- Check for crop duplication chance
function PetAbilityManager.CheckCropDuplication(player, cropAmount)
	local chance = PetAbilityManager.GetChanceBonus(player, "crop_duplication")

	local duplicatedAmount = 0
	for i = 1, cropAmount do
		if math.random() < chance then
			duplicatedAmount = duplicatedAmount + 1
		end
	end

	if duplicatedAmount > 0 then
		local showFeedback = ReplicatedStorage:FindFirstChild("ShowFeedback")
		if showFeedback then
			showFeedback:FireClient(player, "? Crops duplicated! +" .. duplicatedAmount, "success")
		end
	end

	return duplicatedAmount
end

-- Main update loop for active abilities
RunService.Heartbeat:Connect(function()
	local currentTime = os.time()
	if currentTime - lastAbilityCheck < CONFIG.ABILITY_CHECK_INTERVAL then
		return
	end
	lastAbilityCheck = currentTime

	-- Check and trigger active abilities for all players
	for player, _ in pairs(activeAbilities) do
		if player and player.Parent then
			-- Auto-trigger abilities that should run automatically
			PetAbilityManager.TriggerActiveAbility(player, "fertilizer_gen")
			PetAbilityManager.TriggerActiveAbility(player, "auto_water")
			PetAbilityManager.TriggerActiveAbility(player, "gem_generation")
		end
	end
end)

-- Initialize abilities when player joins
Players.PlayerAdded:Connect(function(player)
	wait(3) -- Wait for data to load
	PetAbilityManager.UpdatePlayerAbilities(player)
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	activeAbilities[player] = nil
	abilityCooldowns[player] = nil
	debugLog("Cleaned up abilities for leaving player: " .. player.Name)
end)

debugLog("PetAbilityManager initialized")
return PetAbilityManager
