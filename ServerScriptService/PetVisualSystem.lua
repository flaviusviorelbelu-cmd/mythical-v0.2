-- PetVisualSystem.lua (ServerScriptService)
-- Handles 3D pet models, animations, and visual effects

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(script.Parent:WaitForChild("PetConfig"))
local PetInventoryManager = require(script.Parent:WaitForChild("PetInventoryManager"))

local PetVisualSystem = {}

-- Configuration
local CONFIG = {
	PET_FOLLOW_DISTANCE = 5,
	PET_HEIGHT_OFFSET = 2,
	PET_ANIMATION_SPEED = 1,
	MAX_PETS_VISIBLE = 3,
	UPDATE_INTERVAL = 0.1,
	DEBUG_MODE = true
}

-- Active pet models tracking
local activePetModels = {} -- player -> {slotIndex -> model}
local petAnimations = {} -- model -> {tweens}
local lastUpdate = 0

-- Debug logging
local function debugLog(message, level)
	if CONFIG.DEBUG_MODE then
		level = level or "INFO"
		print(string.format("[PetVisualSystem][%s] %s", level, tostring(message)))
	end
end

-- Create a basic pet model (placeholder - replace with actual models)
local function createBasicPetModel(pet)
	local model = Instance.new("Model")
	model.Name = pet.name .. "_" .. pet.id

	-- Main body part
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Material = Enum.Material.Neon
	body.Size = Vector3.new(2, 2, 2)
	body.Color = PetConfig.GetRarityColor(pet.rarity)
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	-- Add glow effect based on rarity
	local light = Instance.new("PointLight")
	light.Parent = body
	light.Color = PetConfig.GetRarityColor(pet.rarity)
	light.Brightness = pet.rarity == "Legendary" and 2 or 1
	light.Range = pet.rarity == "Legendary" and 15 or 8

	-- Add name tag
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 200, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.Text = pet.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = billboardGui

	-- Store pet data in model
	model:SetAttribute("PetId", pet.id)
	model:SetAttribute("PetRarity", pet.rarity)
	model:SetAttribute("PetLevel", pet.level or 1)

	return model
end

-- Position pet relative to player
local function positionPetNearPlayer(petModel, player, slotIndex)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local playerPosition = player.Character.HumanoidRootPart.Position
	local offset = Vector3.new(
		(slotIndex - 2) * 4, -- Spread pets horizontally
		CONFIG.PET_HEIGHT_OFFSET,
		-CONFIG.PET_FOLLOW_DISTANCE
	)

	-- Rotate offset based on player's facing direction
	local playerRotation = player.Character.HumanoidRootPart.CFrame
	local worldOffset = playerRotation:VectorToWorldSpace(offset)

	return playerPosition + worldOffset
end

-- Create floating animation for pet
local function createPetAnimations(petModel)
	local body = petModel:FindFirstChild("Body")
	if not body then return end

	local animations = {}

	-- Floating animation
	local floatTween = TweenService:Create(body,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Position = body.Position + Vector3.new(0, 1, 0)}
	)
	floatTween:Play()
	table.insert(animations, floatTween)

	-- Rotation animation
	local spinTween = TweenService:Create(body,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{Rotation = Vector3.new(0, 360, 0)}
	)
	spinTween:Play()
	table.insert(animations, spinTween)

	-- Pulse animation for legendary pets
	local rarity = petModel:GetAttribute("PetRarity")
	if rarity == "Legendary" then
		local pulseTween = TweenService:Create(body,
			TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, -1, true),
			{Size = body.Size * 1.2}
		)
		pulseTween:Play()
		table.insert(animations, pulseTween)
	end

	petAnimations[petModel] = animations
end

-- Clean up pet animations
local function cleanupPetAnimations(petModel)
	local animations = petAnimations[petModel]
	if animations then
		for _, tween in ipairs(animations) do
			if tween then
				tween:Cancel()
			end
		end
		petAnimations[petModel] = nil
	end
end

-- Spawn pet model for player
function PetVisualSystem.SpawnPet(player, pet, slotIndex)
	if not player or not pet or slotIndex < 1 or slotIndex > CONFIG.MAX_PETS_VISIBLE then
		return false
	end

	-- Remove existing pet in this slot
	PetVisualSystem.DespawnPet(player, slotIndex)

	-- Create pet model
	local petModel = createBasicPetModel(pet)
	if not petModel then
		debugLog("Failed to create pet model for " .. pet.name, "ERROR")
		return false
	end

	-- Find player's garden or use workspace
	local gardenId = _G.getPlayerGarden and _G.getPlayerGarden(player)
	local gardenFolder = gardenId and workspace:FindFirstChild("PlayerGarden_" .. gardenId)

	if gardenFolder then
		local animalArea = gardenFolder:FindFirstChild("AnimalArea")
		if not animalArea then
			animalArea = Instance.new("Folder")
			animalArea.Name = "AnimalArea"
			animalArea.Parent = gardenFolder
		end
		petModel.Parent = animalArea
	else
		petModel.Parent = workspace
	end

	-- Position pet
	local position = positionPetNearPlayer(petModel, player, slotIndex)
	if position then
		petModel:MoveTo(position)
	end

	-- Create animations
	createPetAnimations(petModel)

	-- Store reference
	if not activePetModels[player] then
		activePetModels[player] = {}
	end
	activePetModels[player][slotIndex] = petModel

	debugLog(string.format("Spawned pet %s for player %s in slot %d", pet.name, player.Name, slotIndex))
	return true
end

-- Despawn pet model
function PetVisualSystem.DespawnPet(player, slotIndex)
	if not activePetModels[player] or not activePetModels[player][slotIndex] then
		return false
	end

	local petModel = activePetModels[player][slotIndex]
	cleanupPetAnimations(petModel)

	if petModel and petModel.Parent then
		petModel:Destroy()
	end

	activePetModels[player][slotIndex] = nil
	return true
end

-- Update all active pets for a player
function PetVisualSystem.UpdatePlayerPets(player)
	local activePets = PetInventoryManager.GetActivePets(player)

	-- Despawn pets that are no longer active
	if activePetModels[player] then
		for slotIndex, petModel in pairs(activePetModels[player]) do
			if not activePets[slotIndex] then
				PetVisualSystem.DespawnPet(player, slotIndex)
			end
		end
	end

	-- Spawn new active pets
	for slotIndex, pet in pairs(activePets) do
		if slotIndex >= 1 and slotIndex <= CONFIG.MAX_PETS_VISIBLE then
			if not activePetModels[player] or not activePetModels[player][slotIndex] then
				PetVisualSystem.SpawnPet(player, pet, slotIndex)
			end
		end
	end
end

-- Update pet positions to follow player
function PetVisualSystem.UpdatePetPositions(player)
	if not activePetModels[player] then return end

	for slotIndex, petModel in pairs(activePetModels[player]) do
		if petModel and petModel.Parent then
			local targetPosition = positionPetNearPlayer(petModel, player, slotIndex)
			if targetPosition then
				-- Smooth movement
				local body = petModel:FindFirstChild("Body")
				if body then
					local currentPosition = body.Position
					local newPosition = currentPosition:Lerp(targetPosition, 0.1)
					body.Position = newPosition
				end
			end
		end
	end
end

-- Get active pet models for player
function PetVisualSystem.GetPlayerPetModels(player)
	return activePetModels[player] or {}
end

-- Handle special pet abilities visually (e.g., fertilizer generation)
function PetVisualSystem.TriggerPetAbilityEffect(player, petId, abilityType)
	if not activePetModels[player] then return end

	-- Find pet model by ID
	for slotIndex, petModel in pairs(activePetModels[player]) do
		if petModel:GetAttribute("PetId") == petId then
			local body = petModel:FindFirstChild("Body")
			if body then
				-- Create ability effect based on type
				if abilityType == "fertilizer_gen" then
					-- Green sparkle effect
					local sparkle = TweenService:Create(body,
						TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{Color = Color3.fromRGB(0, 255, 0)}
					)
					sparkle:Play()
					sparkle.Completed:Connect(function()
						TweenService:Create(body, TweenInfo.new(0.5), 
							{Color = PetConfig.GetRarityColor(petModel:GetAttribute("PetRarity"))}):Play()
					end)
				elseif abilityType == "auto_water" then
					-- Blue water effect
					local waterEffect = TweenService:Create(body,
						TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{Size = body.Size * 1.5, Color = Color3.fromRGB(0, 150, 255)}
					)
					waterEffect:Play()
					waterEffect.Completed:Connect(function()
						TweenService:Create(body, TweenInfo.new(0.5),
							{Size = Vector3.new(2, 2, 2), Color = PetConfig.GetRarityColor(petModel:GetAttribute("PetRarity"))}):Play()
					end)
				end
			end
			break
		end
	end
end

-- Main update loop
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate < CONFIG.UPDATE_INTERVAL then
		return
	end
	lastUpdate = now

	-- Update positions for all players
	for player, _ in pairs(activePetModels) do
		if player and player.Parent then
			PetVisualSystem.UpdatePetPositions(player)
		end
	end
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	if activePetModels[player] then
		for slotIndex, petModel in pairs(activePetModels[player]) do
			cleanupPetAnimations(petModel)
			if petModel and petModel.Parent then
				petModel:Destroy()
			end
		end
		activePetModels[player] = nil
	end
	debugLog("Cleaned up pet models for leaving player: " .. player.Name)
end)

-- Initialize pets when player joins
Players.PlayerAdded:Connect(function(player)
	-- Wait a bit for player data to load
	wait(2)
	PetVisualSystem.UpdatePlayerPets(player)
end)

debugLog("PetVisualSystem initialized")
return PetVisualSystem