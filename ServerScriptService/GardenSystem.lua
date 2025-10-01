-- FixedGardenSystem_v2_Complete.lua - Complete Garden System with Auto Garden Creation
local GardenSystem = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DEBUG_MODE = true

-- Debug logger
local function debugLog(msg, lvl)
	if DEBUG_MODE then
		print("[GardenSystem][" .. (lvl or "INFO") .. "] " .. msg)
	end
end

-- Configuration
local PLOT_SIZE = Vector3.new(3.5, 0.2, 3.5)
local PLOTS_PER_PLAYER = 9
local PLOT_SPACING = 5
local GROWTH_TIME = 30 -- seconds for testing

-- Storage
local playerGardens = {} -- userId -> gardenData
local playerPlots = {}   -- userId -> {plotIndex -> plotData}
local plotTimers = {}    -- timers for plant growth

-- Seed and crop configurations
local SEED_CONFIG = {
	basic_seed = {
		name = "Magic Wheat",
		cost = 10,
		growTime = 30,
		cropType = "magic_wheat",
		color = Color3.fromRGB(255, 255, 0)
	},
	stellar_seed = {
		name = "Stellar Corn",
		cost = 50,
		growTime = 60,
		cropType = "stellar_corn",
		color = Color3.fromRGB(255, 200, 0)
	},
	cosmic_seed = {
		name = "Cosmic Berries",
		cost = 200,
		growTime = 120,
		cropType = "cosmic_berries",
		color = Color3.fromRGB(200, 0, 255)
	}
}

local CROP_CONFIG = {
	magic_wheat = { sellPrice = 15, expReward = 5 },
	stellar_corn = { sellPrice = 80, expReward = 15 },
	cosmic_berries = { sellPrice = 350, expReward = 35 }
}

-- Require DataManager safely
local DataManager
spawn(function()
	local success, result = pcall(function()
		return require(script.Parent:WaitForChild("DataManager", 10))
	end)
	if success then
		DataManager = result
		debugLog("DataManager loaded successfully")
	else
		warn("[GardenSystem] Failed to load DataManager:", result)
	end
end)

-- === VALIDATION FUNCTIONS ===
function GardenSystem.IsValidSeed(seedType)
	return SEED_CONFIG[seedType] ~= nil
end

function GardenSystem.IsValidCrop(cropType)
	return CROP_CONFIG[cropType] ~= nil
end

-- === GARDEN POSITION CALCULATION ===
function GardenSystem.GetPlayerGardenPosition(userId)
	-- Position players in circle around spawn (0,0,0)
	local angle = math.rad((userId % 12) * 30)
	local radius = 50 -- Closer to spawn for easier access
	return Vector3.new(
		math.cos(angle) * radius,
		6,
		math.sin(angle) * radius
	)
end

-- === GARDEN CREATION ===
function GardenSystem.InitializePlayerGarden(player)
	local userId = player.UserId
	local playerName = player.Name

	if playerGardens[userId] then
		debugLog("Garden already exists for " .. playerName, "WARN")
		return playerGardens[userId]
	end

	-- Create garden data structure
	local gardenData = {
		owner = player,
		centerPos = GardenSystem.GetPlayerGardenPosition(userId),
		model = nil,
		lastUpdated = os.time()
	}

	playerGardens[userId] = gardenData
	playerPlots[userId] = {}

	-- Create physical garden
	local gardenModel = Instance.new("Model")
	gardenModel.Name = playerName .. "_Garden"
	gardenModel.Parent = workspace
	gardenData.model = gardenModel

	local gardenCenter = gardenData.centerPos
	debugLog("Creating garden at position: " .. tostring(gardenCenter))

	-- Create 9 plots in 3x3 grid
	for row = 1, 3 do
		for col = 1, 3 do
			local plotIndex = (row - 1) * 3 + col
			local plot = GardenSystem.CreatePlot(player, plotIndex, gardenCenter, row, col)
			plot.part.Parent = gardenModel
			playerPlots[userId][plotIndex] = plot
			debugLog("Created plot " .. plotIndex .. " at position: " .. tostring(plot.part.Position))
		end
	end

	-- Add decorations
	GardenSystem.AddChest(gardenCenter, gardenModel)
	GardenSystem.AddFence(gardenCenter, gardenModel)
	GardenSystem.CreatePlayerNameplate(player, gardenCenter, gardenModel)

	debugLog("Created complete garden for player: " .. playerName .. " with " .. PLOTS_PER_PLAYER .. " plots")
	return gardenData
end

-- === PLOT CREATION ===
function GardenSystem.CreatePlot(player, plotIndex, centerPos, row, col)
	-- Calculate plot position in 3x3 grid
	local offsetX = (col - 2) * PLOT_SPACING
	local offsetZ = (row - 2) * PLOT_SPACING
	local plotPos = centerPos + Vector3.new(offsetX, 0, offsetZ)

	-- Create plot base
	local plotBase = Instance.new("Part")
	plotBase.Name = player.Name .. "_Plot_" .. plotIndex
	plotBase.Size = PLOT_SIZE
	plotBase.Position = plotPos
	plotBase.Anchored = true
	plotBase.Material = Enum.Material.Ground
	plotBase.BrickColor = BrickColor.new("Brown")
	plotBase.TopSurface = Enum.SurfaceType.Smooth

	-- Create plot border
	local border = Instance.new("Part")
	border.Name = "PlotBorder"
	border.Size = Vector3.new(PLOT_SIZE.X + 0.5, 0.5, PLOT_SIZE.Z + 0.5)
	border.Position = plotPos + Vector3.new(0, 0.5, 0)
	border.Anchored = true
	border.Material = Enum.Material.Wood
	border.BrickColor = BrickColor.new("Dark brown")
	border.CanCollide = false
	border.Transparency = 0.3
	border.Parent = plotBase

	-- Create status indicator
	local statusIndicator = Instance.new("Part")
	statusIndicator.Name = "StatusIndicator"
	statusIndicator.Size = Vector3.new(1, 0.2, 1)
	statusIndicator.Position = plotPos + Vector3.new(0.5, 0.5, 0.5)
	statusIndicator.Anchored = true
	statusIndicator.Material = Enum.Material.Neon
	statusIndicator.BrickColor = BrickColor.new("Lime green")
	statusIndicator.Shape = Enum.PartType.Cylinder
	statusIndicator.CanCollide = false
	statusIndicator.Parent = plotBase

	-- Create click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 50
	clickDetector.Parent = plotBase

	-- Plot data structure
	local plotData = {
		part = plotBase,
		indicator = statusIndicator,
		clickDetector = clickDetector,
		owner = player,
		plotIndex = plotIndex,
		seedType = nil,
		plantTime = nil,
		growthStage = 0,
		isReady = false,
		cropModel = nil,
		state = "Empty"
	}

	-- Connect click event
	clickDetector.MouseClick:Connect(function(clickingPlayer)
		GardenSystem.HandlePlotClick(clickingPlayer, plotData)
	end)

	return plotData
end

-- === DECORATIVE ELEMENTS ===
function GardenSystem.AddFence(centerPos, parentModel)
	local length = PLOT_SPACING * 4
	local thickness = 0.4
	local height = 2

	local fenceOffsets = {
		{Vector3.new(0, 0, length/2), Vector3.new(length, height, thickness)},
		{Vector3.new(0, 0, -length/2), Vector3.new(length, height, thickness)},
		{Vector3.new(length/2, 0, 0), Vector3.new(thickness, height, length)},
		{Vector3.new(-length/2, 0, 0), Vector3.new(thickness, height, length)}
	}

	for i, offset in ipairs(fenceOffsets) do
		local fence = Instance.new("Part")
		fence.Name = "Fence" .. i
		fence.Size = offset[2]
		fence.Position = centerPos + offset[1] + Vector3.new(0, height/2, 0)
		fence.Anchored = true
		fence.Material = Enum.Material.Wood
		fence.BrickColor = BrickColor.new("Burgundy")
		fence.Parent = parentModel
	end
end

function GardenSystem.AddChest(centerPos, parentModel)
	local chest = Instance.new("Part")
	chest.Name = "Chest"
	chest.Size = Vector3.new(2.2, 1.6, 1.2)
	chest.Position = centerPos + Vector3.new(-(PLOT_SPACING * 2), 1, 0)
	chest.Anchored = true
	chest.Material = Enum.Material.Wood
	chest.BrickColor = BrickColor.new("Dark orange")
	chest.Parent = parentModel

	-- Add click detector for chest interaction
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = "ChestInteraction"
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = chest

	return chest
end

function GardenSystem.CreatePlayerNameplate(player, centerPos, parentModel)
	local nameplate = Instance.new("Part")
	nameplate.Name = player.Name .. "_Nameplate"
	nameplate.Size = Vector3.new(10, 1, 3)
	nameplate.Position = centerPos + Vector3.new(0, 15, 0)
	nameplate.Anchored = true
	nameplate.CanCollide = false
	nameplate.Transparency = 1
	nameplate.Parent = parentModel

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = nameplate

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = player.Name .. "'s Magical Garden"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.Fantasy
	textLabel.Parent = gui

	-- Floating animation
	local floatTween = TweenService:Create(
		nameplate,
		TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Position = centerPos + Vector3.new(0, 18, 0)}
	)
	floatTween:Play()
end

-- === FARMING FUNCTIONALITY ===
function GardenSystem.PlantSeed(player, plotIndex, seedType)
	local userId = player.UserId
	local plots = playerPlots[userId]

	if not plots or not plots[plotIndex] then
		debugLog("Plot not found: " .. plotIndex .. " for user " .. userId, "ERROR")
		return false, "Plot not found"
	end

	local plotData = plots[plotIndex]
	if plotData.seedType then
		return false, "Plot already occupied"
	end

	local seedConfig = SEED_CONFIG[seedType]
	if not seedConfig then
		return false, "Invalid seed type"
	end

	-- Plant the seed
	plotData.seedType = seedType
	plotData.plantTime = tick()
	plotData.growthStage = 1
	plotData.isReady = false
	plotData.state = "Planted"

	-- Update visuals
	plotData.indicator.BrickColor = BrickColor.new("Yellow")
	GardenSystem.CreateCropVisual(plotData, seedConfig)
	GardenSystem.StartGrowthTimer(plotData, seedConfig)

	debugLog("Planted " .. seedConfig.name .. " in plot " .. plotIndex)

	-- Notify client about the change
	local plotDataChanged = ReplicatedStorage:FindFirstChild("PlotDataChanged")
	if plotDataChanged then
		plotDataChanged:FireClient(player, plotIndex, {
			state = "Planted",
			cropType = seedType,
			plotId = plotIndex
		})
	end

	return true, "Seed planted successfully"
end

function GardenSystem.Harvest(player, plotIndex)
	local userId = player.UserId
	local plots = playerPlots[userId]
	if not plots or not plots[plotIndex] then
		return false, nil, 0, "Plot not found"
	end

	local plotData = plots[plotIndex]
	if not plotData.isReady or not plotData.seedType then
		return false, nil, 0, "Plot not ready for harvest"
	end

	local seedConfig = SEED_CONFIG[plotData.seedType]
	local cropType = seedConfig.cropType
	local quantity = 1

	-- Clear plot
	plotData.seedType = nil
	plotData.plantTime = nil
	plotData.growthStage = 0
	plotData.isReady = false
	plotData.state = "Empty"

	-- Update visuals
	plotData.indicator.BrickColor = BrickColor.new("Lime green")
	if plotData.cropModel then
		plotData.cropModel:Destroy()
		plotData.cropModel = nil
	end

	-- Add to player inventory
	if DataManager then
		local playerData = DataManager.GetPlayerData(player)
		if playerData then
			playerData.inventory = playerData.inventory or {}
			playerData.inventory.crops = playerData.inventory.crops or {}
			playerData.inventory.crops[cropType] = (playerData.inventory.crops[cropType] or 0) + quantity
			DataManager.SavePlayerData(player, playerData)
		end
	end

	-- Notify client
	local plotDataChanged = ReplicatedStorage:FindFirstChild("PlotDataChanged")
	if plotDataChanged then
		plotDataChanged:FireClient(player, plotIndex, {
			state = "Empty",
			cropType = nil,
			plotId = plotIndex
		})
	end

	return true, cropType, quantity, "Harvest successful"
end

-- === VISUAL EFFECTS ===
function GardenSystem.CreateCropVisual(plotData, seedConfig)
	if plotData.cropModel then
		plotData.cropModel:Destroy()
	end

	local crop = Instance.new("Part")
	crop.Name = "Crop_" .. seedConfig.name:gsub(" ", "_")
	crop.Size = Vector3.new(1, 0.5, 1)
	crop.Position = plotData.part.Position + Vector3.new(0, 0.5, 0)
	crop.Anchored = true
	crop.Material = Enum.Material.Grass
	crop.Color = seedConfig.color
	crop.Shape = Enum.PartType.Cylinder
	crop.CanCollide = false
	crop.Parent = plotData.part

	plotData.cropModel = crop

	-- Growth animation
	local growTween = TweenService:Create(
		crop,
		TweenInfo.new(2, Enum.EasingStyle.Elastic),
		{Size = Vector3.new(2, 1, 2)}
	)
	growTween:Play()
end

function GardenSystem.StartGrowthTimer(plotData, seedConfig)
	local timerKey = plotData.owner.Name .. "_" .. plotData.plotIndex

	-- Clean up existing timer
	if plotTimers[timerKey] then
		plotTimers[timerKey]:Disconnect()
	end

	plotTimers[timerKey] = task.delay(seedConfig.growTime, function()
		-- Crop is ready!
		plotData.isReady = true
		plotData.growthStage = 3
		plotData.state = "ReadyToHarvest"

		-- Update visual indicators
		plotData.indicator.BrickColor = BrickColor.new("Bright green")

		if plotData.cropModel then
			plotData.cropModel.Material = Enum.Material.Neon
			plotData.cropModel.Color = Color3.fromRGB(255, 215, 0)

			-- Add glowing effect
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 255, 0)
			light.Brightness = 2
			light.Range = 10
			light.Parent = plotData.cropModel
		end

		debugLog("Crop ready for harvest in plot " .. plotData.plotIndex)

		-- Notify client
		local plotDataChanged = ReplicatedStorage:FindFirstChild("PlotDataChanged")
		if plotDataChanged then
			plotDataChanged:FireClient(plotData.owner, plotData.plotIndex, {
				state = "ReadyToHarvest",
				cropType = plotData.seedType,
				plotId = plotData.plotIndex
			})
		end

		plotTimers[timerKey] = nil
	end)
end

-- === INTERACTION HANDLING ===
function GardenSystem.HandlePlotClick(clickingPlayer, plotData)
	if clickingPlayer ~= plotData.owner then
		return
	end

	debugLog("Plot clicked by: " .. clickingPlayer.Name .. ", Plot: " .. plotData.plotIndex)

	if plotData.seedType == nil then
		debugLog("Empty plot - ready for planting")
	elseif plotData.isReady then
		local success, cropType, quantity, message = GardenSystem.Harvest(clickingPlayer, plotData.plotIndex)
		if success then
			debugLog("Harvested: " .. cropType .. " x" .. quantity)
			-- Send feedback to client
			local showFeedback = ReplicatedStorage:FindFirstChild("ShowFeedback")
			if showFeedback then
				showFeedback:FireClient(clickingPlayer, "Harvested " .. cropType .. "!", "success")
			end
		else
			debugLog("Harvest failed: " .. message, "ERROR")
		end
	else
		local timeLeft = GardenSystem.GetGrowTimeLeft(plotData)
		debugLog("Still growing... Time left: " .. timeLeft .. " seconds")
	end
end

function GardenSystem.GetGrowTimeLeft(plotData)
	local seedConfig = SEED_CONFIG[plotData.seedType]
	if not plotData.plantTime or not seedConfig then
		return 0
	end

	local elapsed = tick() - plotData.plantTime
	local timeLeft = math.max(0, seedConfig.growTime - elapsed)
	return math.floor(timeLeft)
end

-- === DATA ACCESS FUNCTIONS ===
function GardenSystem.GetPlayerPlots(player)
	local userId = player.UserId
	local plots = playerPlots[userId]

	if not plots then
		-- Auto-create garden if it doesn't exist
		debugLog("Auto-creating garden for " .. player.Name)
		GardenSystem.InitializePlayerGarden(player)
		plots = playerPlots[userId]
	end

	-- Convert to simple format for client
	local plotsData = {}
	for plotIndex, plotData in pairs(plots or {}) do
		plotsData[plotIndex] = {
			state = plotData.state or "Empty",
			cropType = plotData.seedType,
			plotId = plotIndex,
			isReady = plotData.isReady or false
		}
	end

	return plotsData
end

function GardenSystem.GetInventory(player)
	if not DataManager then return {} end
	local playerData = DataManager.GetPlayerData(player)
	return playerData and playerData.inventory or {}
end

-- === PLAYER CONNECTION HANDLING ===
local function onPlayerAdded(player)
	debugLog("Player joined: " .. player.Name .. ", creating garden...")

	-- Wait a moment for other systems to initialize
	task.wait(2)

	-- Create garden
	GardenSystem.InitializePlayerGarden(player)
end

local function onPlayerRemoving(player)
	local userId = player.UserId

	-- Clean up timers
	for timerKey, timer in pairs(plotTimers) do
		if string.find(timerKey, player.Name .. "_") then
			timer:Disconnect()
			plotTimers[timerKey] = nil
		end
	end

	-- Clean up garden model
	if playerGardens[userId] and playerGardens[userId].model then
		playerGardens[userId].model:Destroy()
	end

	-- Clean up data
	playerGardens[userId] = nil
	playerPlots[userId] = nil

	debugLog("Cleaned up garden for: " .. player.Name)
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

debugLog("Enhanced GardenSystem v2 Complete loaded successfully")
return GardenSystem