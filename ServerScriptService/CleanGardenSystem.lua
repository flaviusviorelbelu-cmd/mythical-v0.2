-- CleanGardenSystem.lua - Error-Free Garden Management
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GardenSystem = {}

-- Garden configuration
local GARDEN_CONFIG = {
	PLOT_SIZE = Vector3.new(4, 1, 4),
	PLOT_SPACING = 6,
	PLOTS_PER_ROW = 3,
	MAX_PLOTS = 9,
	GROW_TIME = {
		basic_seed = 30,     -- 30 seconds
		stellar_seed = 45,   -- 45 seconds
		cosmic_seed = 60     -- 60 seconds
	},
	CROP_YIELDS = {
		basic_seed = 1,
		stellar_seed = 2,
		cosmic_seed = 3
	}
}

-- Active gardens storage
local playerGardens = {}
local plotData = {}

-- Utility functions
local function createPlotKey(userId, plotId)
	return tostring(userId) .. "_" .. tostring(plotId)
end

local function isValidSeedType(seedType)
	local validTypes = {"basic_seed", "stellar_seed", "cosmic_seed"}
	for _, valid in ipairs(validTypes) do
		if seedType == valid then
			return true
		end
	end
	return false
end

-- Create visual plot
local function createPlot(position, plotId, playerId)
	local plot = Instance.new("Part")
	plot.Name = "Plot_" .. plotId
	plot.Size = GARDEN_CONFIG.PLOT_SIZE
	plot.Position = position
	plot.Anchored = true
	plot.Material = Enum.Material.Ground
	plot.Color = Color3.fromRGB(101, 67, 33) -- Brown soil
	plot.Shape = Enum.PartType.Block
	
	-- Add attributes
	plot:SetAttribute("plotId", plotId)
	plot:SetAttribute("playerId", playerId)
	plot:SetAttribute("planted", false)
	plot:SetAttribute("seedType", "")
	plot:SetAttribute("plantTime", 0)
	plot:SetAttribute("ready", false)
	
	-- Create click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 20
	clickDetector.Parent = plot
	
	-- Handle plot clicks
	clickDetector.MouseClick:Connect(function(player)
		if player.UserId ~= playerId then
			return -- Only owner can interact
		end
		
		local plotKey = createPlotKey(playerId, plotId)
		local plotInfo = plotData[plotKey]
		
		if not plotInfo then
			print("[GardenSystem] No plot data found for:", plotKey)
			return
		end
		
		-- Fire plot options event to client
		local showOptionsEvent = ReplicatedStorage:FindFirstChild("ShowPlotOptionsEvent")
		if showOptionsEvent then
			showOptionsEvent:FireClient(player, plotId, plotInfo)
		end
	end)
	
	return plot
end

-- Create plant visual
local function createPlantVisual(plot, seedType, isReady)
	-- Remove existing plant
	local existingPlant = plot:FindFirstChild("Plant")
	if existingPlant then
		existingPlant:Destroy()
	end
	
	local plant = Instance.new("Part")
	plant.Name = "Plant"
	plant.Size = Vector3.new(1, isReady and 3 or 1.5, 1)
	plant.Position = plot.Position + Vector3.new(0, plant.Size.Y/2 + 0.5, 0)
	plant.Anchored = true
	plant.CanCollide = false
	plant.Shape = Enum.PartType.Block
	plant.Material = Enum.Material.Grass
	
	-- Set color based on seed type and readiness
	local colors = {
		basic_seed = isReady and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(0, 150, 0),
		stellar_seed = isReady and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(200, 200, 0),
		cosmic_seed = isReady and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(150, 0, 150)
	}
	
	plant.Color = colors[seedType] or Color3.fromRGB(0, 255, 0)
	plant.Parent = plot
	
	-- Add ready indicator
	if isReady then
		local sparkle = Instance.new("PointLight")
		sparkle.Brightness = 2
		sparkle.Color = plant.Color
		sparkle.Range = 10
		sparkle.Parent = plant
		
		-- Tween the light for effect
		local tween = TweenService:Create(
			sparkle,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Brightness = 0.5}
		)
		tween:Play()
	end
end

-- Initialize player garden
function GardenSystem.InitializePlayerGarden(player)
	local userId = player.UserId
	local gardenKey = "Garden_" .. userId
	
	print("[GardenSystem] 🌱 Initializing garden for:", player.Name)
	
	-- Remove existing garden
	local existingGarden = Workspace:FindFirstChild(gardenKey)
	if existingGarden then
		existingGarden:Destroy()
	end
	
	-- Create garden folder
	local gardenFolder = Instance.new("Folder")
	gardenFolder.Name = gardenKey
	gardenFolder.Parent = Workspace
	
	-- Calculate garden position (offset by player index)
	local playerIndex = 0
	for _, p in pairs(Players:GetPlayers()) do
		if p.UserId == userId then
			break
		end
		playerIndex = playerIndex + 1
	end
	
	local basePosition = Vector3.new(playerIndex * 30, 5, 0)
	
	-- Create plots
	local plots = {}
	for i = 1, GARDEN_CONFIG.MAX_PLOTS do
		local row = math.floor((i - 1) / GARDEN_CONFIG.PLOTS_PER_ROW)
		local col = (i - 1) % GARDEN_CONFIG.PLOTS_PER_ROW
		
		local plotPosition = basePosition + Vector3.new(
			col * GARDEN_CONFIG.PLOT_SPACING,
			0,
			row * GARDEN_CONFIG.PLOT_SPACING
		)
		
		local plot = createPlot(plotPosition, i, userId)
		plot.Parent = gardenFolder
		plots[i] = plot
		
		-- Initialize plot data
		local plotKey = createPlotKey(userId, i)
		plotData[plotKey] = {
			plotId = i,
			playerId = userId,
			planted = false,
			seedType = nil,
			plantTime = 0,
			ready = false
		}
	end
	
	playerGardens[userId] = {
		plots = plots,
		gardenFolder = gardenFolder
	}
	
	print("[GardenSystem] ✅ Garden created with", GARDEN_CONFIG.MAX_PLOTS, "plots for:", player.Name)
end

-- Plant seed in plot
function GardenSystem.PlantSeed(player, plotId, seedType)
	local userId = player.UserId
	local plotKey = createPlotKey(userId, plotId)
	
	print("[GardenSystem] 🌱 Attempting to plant", seedType, "in plot", plotId, "for:", player.Name)
	
	-- Validate inputs
	if not plotId or not seedType then
		warn("[GardenSystem] Invalid parameters")
		return false, "Invalid parameters"
	end
	
	if not isValidSeedType(seedType) then
		warn("[GardenSystem] Invalid seed type:", seedType)
		return false, "Invalid seed type"
	end
	
	-- Check if plot exists
	local plotInfo = plotData[plotKey]
	if not plotInfo then
		warn("[GardenSystem] Plot not found:", plotKey)
		return false, "Plot not found"
	end
	
	-- Check if plot is already planted
	if plotInfo.planted then
		warn("[GardenSystem] Plot already planted")
		return false, "Plot already has something planted"
	end
	
	-- Get the actual plot object
	local garden = playerGardens[userId]
	if not garden or not garden.plots[plotId] then
		warn("[GardenSystem] Plot object not found")
		return false, "Plot object not found"
	end
	
	local plot = garden.plots[plotId]
	
	-- Plant the seed
	local currentTime = tick()
	plotInfo.planted = true
	plotInfo.seedType = seedType
	plotInfo.plantTime = currentTime
	plotInfo.ready = false
	
	-- Update plot attributes
	plot:SetAttribute("planted", true)
	plot:SetAttribute("seedType", seedType)
	plot:SetAttribute("plantTime", currentTime)
	plot:SetAttribute("ready", false)
	
	-- Create plant visual
	createePlantVisual(plot, seedType, false)
	
	-- Schedule growth
	local growTime = GARDEN_CONFIG.GROW_TIME[seedType] or 30
	spawn(function()
		wait(growTime)
		
		-- Check if plot still exists and is planted
		local currentPlotInfo = plotData[plotKey]
		if currentPlotInfo and currentPlotInfo.planted and currentPlotInfo.seedType == seedType then
			currentPlotInfo.ready = true
			plot:SetAttribute("ready", true)
			
			-- Update visual
			createePlantVisual(plot, seedType, true)
			
			print("[GardenSystem] 🌾 Crop ready for harvest:", seedType, "plot", plotId)
		end
	end)
	
	print("[GardenSystem] ✅ Successfully planted", seedType, "in plot", plotId)
	return true, "Successfully planted"
end

-- Harvest plant from plot
function GardenSystem.HarvestPlant(player, plotId)
	local userId = player.UserId
	local plotKey = createPlotKey(userId, plotId)
	
	print("[GardenSystem] 🌾 Attempting to harvest plot", plotId, "for:", player.Name)
	
	-- Check if plot exists
	local plotInfo = plotData[plotKey]
	if not plotInfo then
		warn("[GardenSystem] Plot not found:", plotKey)
		return false, nil
	end
	
	-- Check if plot is planted
	if not plotInfo.planted then
		warn("[GardenSystem] Nothing planted in plot:", plotId)
		return false, nil
	end
	
	-- Check if crop is ready
	if not plotInfo.ready then
		warn("[GardenSystem] Crop not ready yet in plot:", plotId)
		return false, nil
	end
	
	local seedType = plotInfo.seedType
	local cropYield = GARDEN_CONFIG.CROP_YIELDS[seedType] or 1
	
	-- Get the actual plot object
	local garden = playerGardens[userId]
	if garden and garden.plots[plotId] then
		local plot = garden.plots[plotId]
		
		-- Remove plant visual
		local plant = plot:FindFirstChild("Plant")
		if plant then
			plant:Destroy()
		end
		
		-- Reset plot attributes
		plot:SetAttribute("planted", false)
		plot:SetAttribute("seedType", "")
		plot:SetAttribute("plantTime", 0)
		plot:SetAttribute("ready", false)
	end
	
	-- Reset plot data
	plotInfo.planted = false
	plotInfo.seedType = nil
	plotInfo.plantTime = 0
	plotInfo.ready = false
	
	print("[GardenSystem] ✅ Successfully harvested", cropYield, "x", seedType, "from plot", plotId)
	return true, seedType, cropYield
end

-- Get garden data for client
function GardenSystem.GetGardenData(player)
	local userId = player.UserId
	local gardenData = {}
	
	for i = 1, GARDEN_CONFIG.MAX_PLOTS do
		local plotKey = createPlotKey(userId, i)
		local plotInfo = plotData[plotKey]
		
		if plotInfo then
			gardenData[i] = {
				plotId = plotInfo.plotId,
				planted = plotInfo.planted,
				seedType = plotInfo.seedType,
				plantTime = plotInfo.plantTime,
				ready = plotInfo.ready,
				timeLeft = plotInfo.planted and not plotInfo.ready and 
							math.max(0, (plotInfo.plantTime + (GARDEN_CONFIG.GROW_TIME[plotInfo.seedType] or 30)) - tick()) or 0
			}
		else
			gardenData[i] = {
				plotId = i,
				planted = false,
				seedType = nil,
				plantTime = 0,
				ready = false,
				timeLeft = 0
			}
		end
	end
	
	return gardenData
end

-- Cleanup when player leaves
local function onPlayerRemoving(player)
	local userId = player.UserId
	
	-- Clean up garden
	local garden = playerGardens[userId]
	if garden and garden.gardenFolder then
		garden.gardenFolder:Destroy()
	end
	playerGardens[userId] = nil
	
	-- Clean up plot data
	for i = 1, GARDEN_CONFIG.MAX_PLOTS do
		local plotKey = createPlotKey(userId, i)
		plotData[plotKey] = nil
	end
	
	print("[GardenSystem] 🧹 Cleaned up garden for:", player.Name)
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[GardenSystem] ✅ Clean GardenSystem loaded successfully")
return GardenSystem