-- FixedGardenClient_v2.lua - Enhanced Garden Client with Visual Updates
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local INTERACTION_DISTANCE = 10
local playerInventory = {
	seeds = {
		stellar_seed = 0,
		basic_seed = 0,
		cosmic_seed = 0
	}
}

print("[GardenClient] Initializing enhanced garden system v2...")

-- Wait for remote objects
local remoteEvents = {}
local remoteFunctions = {}

local function waitForRemoteObject(objectType, objectName, timeout)
	local startTime = tick()
	timeout = timeout or 10

	repeat
		local obj = ReplicatedStorage:FindFirstChild(objectName)
		if obj and obj:IsA(objectType) then
			return obj
		end
		wait(0.1)
	until tick() - startTime > timeout

	warn("[GardenClient] Failed to find " .. objectType .. ": " .. objectName)
	return nil
end

-- Load remote objects with enhanced error handling
local function loadRemoteObjects()
	print("[GardenClient] Loading remote objects...")

	-- Remote Events
	remoteEvents.BuySeedEvent = waitForRemoteObject("RemoteEvent", "BuySeedEvent")
	remoteEvents.PlantSeedEvent = waitForRemoteObject("RemoteEvent", "PlantSeedEvent")
	remoteEvents.HarvestPlantEvent = waitForRemoteObject("RemoteEvent", "HarvestPlantEvent")
	remoteEvents.SellPlantEvent = waitForRemoteObject("RemoteEvent", "SellPlantEvent")
	remoteEvents.RequestInventoryUpdate = waitForRemoteObject("RemoteEvent", "RequestInventoryUpdate")
	remoteEvents.PlotDataChanged = waitForRemoteObject("RemoteEvent", "PlotDataChanged")
	remoteEvents.ShowPlotOptionsEvent = waitForRemoteObject("RemoteEvent", "ShowPlotOptionsEvent")

	-- Remote Functions
	remoteFunctions.GetPlayerStats = waitForRemoteObject("RemoteFunction", "GetPlayerStats")
	remoteFunctions.GetGardenPlots = waitForRemoteObject("RemoteFunction", "GetGardenPlots")

	print("[GardenClient] Remote objects loaded successfully!")
	return true
end

-- Enhanced inventory update with force refresh
local function updateInventoryData(forceRefresh)
	if forceRefresh or not remoteFunctions.GetPlayerStats then
		print("[GardenClient] Force refreshing inventory data...")
		if not loadRemoteObjects() then
			warn("[GardenClient] Failed to load remote objects for inventory update")
			return false
		end
	end

	local success, result = pcall(function()
		return remoteFunctions.GetPlayerStats:InvokeServer()
	end)

	if success and result then
		print("[GardenClient] Received fresh stats from server")

		if result.inventory and result.inventory.seeds then
			playerInventory.seeds = result.inventory.seeds
			print("[GardenClient] Updated inventory:")
			for seedType, count in pairs(playerInventory.seeds) do
				print("  " .. seedType .. " = " .. count)
			end
			return true
		else
			warn("[GardenClient] Invalid inventory data received")
		end
	else
		warn("[GardenClient] Failed to get player stats:", result)
	end

	return false
end

-- Enhanced plot visual update system
local function updatePlotVisual(plotId, plotData)
	print("[GardenClient] Updating visual for plot " .. plotId .. " with data:", plotData)

	local plotModel = workspace:FindFirstChild(player.Name .. "_Plot_" .. plotId)
	if not plotModel then
		warn("[GardenClient] Could not find plot model:", player.Name .. "_Plot_" .. plotId)
		return
	end

	-- Clear existing visual elements
	for _, child in pairs(plotModel:GetChildren()) do
		if child.Name == "Seedling" or child.Name == "Plant" or child.Name == "ReadyHarvest" then
			child:Destroy()
		end
	end

	-- Update plot appearance based on state
	local plotPart = plotModel:FindFirstChild("Plot") or plotModel:FindFirstChildOfClass("Part")
	if plotPart then
		if plotData.state == "Empty" then
			plotPart.Color = Color3.new(0.6, 0.4, 0.2) -- Brown soil
			plotPart.Material = Enum.Material.Ground

		elseif plotData.state == "Planted" then
			plotPart.Color = Color3.new(0.4, 0.3, 0.1) -- Dark muddy soil
			plotPart.Material = Enum.Material.Ground

			-- Add seedling visual
			local seedling = Instance.new("Part")
			seedling.Name = "Seedling"
			seedling.Size = Vector3.new(0.5, 0.5, 0.5)
			seedling.Color = Color3.new(0.2, 0.7, 0.2) -- Green
			seedling.Material = Enum.Material.Leaf
			seedling.Shape = Enum.PartType.Ball
			seedling.CanCollide = false
			seedling.Anchored = true
			seedling.Position = plotPart.Position + Vector3.new(0, plotPart.Size.Y/2 + 0.25, 0)
			seedling.Parent = plotModel

			print("[GardenClient] Added seedling to plot " .. plotId)

		elseif plotData.state == "ReadyToHarvest" then
			plotPart.Color = Color3.new(0.3, 0.6, 0.2) -- Rich green soil
			plotPart.Material = Enum.Material.Grass

			-- Add mature plant visual
			local plant = Instance.new("Part")
			plant.Name = "ReadyHarvest"
			plant.Size = Vector3.new(1, 2, 1)
			plant.Color = Color3.new(0.1, 0.8, 0.1) -- Bright green
			plant.Material = Enum.Material.Leaf
			plant.CanCollide = false
			plant.Anchored = true
			plant.Position = plotPart.Position + Vector3.new(0, plotPart.Size.Y/2 + 1, 0)
			plant.Parent = plotModel

			-- Add glowing effect for ready harvest
			local light = Instance.new("PointLight")
			light.Color = Color3.new(1, 1, 0) -- Yellow glow
			light.Brightness = 1
			light.Range = 5
			light.Parent = plant

			print("[GardenClient] Added mature plant to plot " .. plotId)
		end
	end
end

-- Enhanced harvest UI update
local function updateHarvestUI()
	print("[GardenClient] Updating harvest UI...")

	-- Get current garden plots data
	if not remoteFunctions.GetGardenPlots then
		warn("[GardenClient] GetGardenPlots not available")
		return
	end

	local success, plotsData = pcall(function()
		return remoteFunctions.GetGardenPlots:InvokeServer()
	end)

	if not success or not plotsData then
		warn("[GardenClient] Failed to get garden plots data")
		return
	end

	-- Find main UI and harvest section
	local mainUI = playerGui:FindFirstChild("MainUI")
	if not mainUI then
		warn("[GardenClient] MainUI not found")
		return
	end

	local inventoryFrame = mainUI:FindFirstChild("InventoryFrame")
	if not inventoryFrame then
		warn("[GardenClient] InventoryFrame not found")
		return
	end

	local harvestSection = inventoryFrame:FindFirstChild("HarvestSection")
	if not harvestSection then
		-- Create harvest section if it doesn't exist
		harvestSection = Instance.new("ScrollingFrame")
		harvestSection.Name = "HarvestSection"
		harvestSection.Size = UDim2.new(1, -20, 0.3, 0)
		harvestSection.Position = UDim2.new(0, 10, 0.65, 0)
		harvestSection.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
		harvestSection.BorderSizePixel = 1
		harvestSection.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
		harvestSection.ScrollBarThickness = 8
		harvestSection.Parent = inventoryFrame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 30)
		title.Position = UDim2.new(0, 0, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = "?? Ready to Harvest"
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = harvestSection
	end

	-- Clear existing harvest items
	for _, child in pairs(harvestSection:GetChildren()) do
		if child.Name ~= "Title" and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	-- Add list layout if missing
	if not harvestSection:FindFirstChild("UIListLayout") then
		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 5)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = harvestSection
	end

	-- Add ready-to-harvest items
	local harvestCount = 0
	for plotId, plotData in pairs(plotsData) do
		if plotData.state == "ReadyToHarvest" then
			harvestCount = harvestCount + 1

			local harvestItem = Instance.new("Frame")
			harvestItem.Name = "HarvestItem_" .. plotId
			harvestItem.Size = UDim2.new(1, -10, 0, 50)
			harvestItem.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
			harvestItem.BorderSizePixel = 1
			harvestItem.BorderColor3 = Color3.new(0.4, 0.8, 0.4)
			harvestItem.LayoutOrder = plotId
			harvestItem.Parent = harvestSection

			local cropLabel = Instance.new("TextLabel")
			cropLabel.Size = UDim2.new(0.7, 0, 1, 0)
			cropLabel.Position = UDim2.new(0, 5, 0, 0)
			cropLabel.BackgroundTransparency = 1
			cropLabel.Text = "?? " .. (plotData.cropType or "Unknown") .. " (Plot " .. plotId .. ")"
			cropLabel.TextColor3 = Color3.new(1, 1, 1)
			cropLabel.TextScaled = true
			cropLabel.Font = Enum.Font.Gotham
			cropLabel.TextXAlignment = Enum.TextXAlignment.Left
			cropLabel.Parent = harvestItem

			local harvestButton = Instance.new("TextButton")
			harvestButton.Size = UDim2.new(0.25, -5, 0.8, 0)
			harvestButton.Position = UDim2.new(0.75, 0, 0.1, 0)
			harvestButton.BackgroundColor3 = Color3.new(0.8, 0.6, 0.2)
			harvestButton.Text = "Harvest"
			harvestButton.TextColor3 = Color3.new(1, 1, 1)
			harvestButton.TextScaled = true
			harvestButton.Font = Enum.Font.GothamBold
			harvestButton.Parent = harvestItem

			-- Add harvest button functionality
			harvestButton.MouseButton1Click:Connect(function()
				if remoteEvents.HarvestPlantEvent then
					print("[GardenClient] Harvesting plot " .. plotId)
					remoteEvents.HarvestPlantEvent:FireServer(plotId)
				else
					warn("[GardenClient] HarvestPlantEvent not available")
				end
			end)
		end
	end

	print("[GardenClient] Updated harvest UI with " .. harvestCount .. " items")
end

-- Enhanced plot interaction with forced refresh
local function createPlotInteractionUI(plotId)
	print("[GardenClient] Creating interaction UI for plot " .. plotId)

	-- Force refresh inventory data before showing UI
	if not updateInventoryData(true) then
		-- Show error message
		local errorGui = Instance.new("ScreenGui")
		errorGui.Name = "ErrorMessage"
		errorGui.Parent = playerGui

		local errorFrame = Instance.new("Frame")
		errorFrame.Size = UDim2.new(0, 300, 0, 100)
		errorFrame.Position = UDim2.new(0.5, -150, 0.5, -50)
		errorFrame.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
		errorFrame.Parent = errorGui

		local errorLabel = Instance.new("TextLabel")
		errorLabel.Size = UDim2.new(1, 0, 1, 0)
		errorLabel.BackgroundTransparency = 1
		errorLabel.Text = "Failed to load inventory data. Please try again."
		errorLabel.TextColor3 = Color3.new(1, 1, 1)
		errorLabel.TextScaled = true
		errorLabel.Font = Enum.Font.GothamBold
		errorLabel.Parent = errorFrame

		game:GetService("Debris"):AddItem(errorGui, 3)
		return
	end

	-- Check if we have any seeds
	local hasSeeds = false
	local availableSeeds = {}

	for seedType, count in pairs(playerInventory.seeds) do
		if count > 0 then
			hasSeeds = true
			availableSeeds[seedType] = count
		end
	end

	if not hasSeeds then
		print("[GardenClient] No seeds available in inventory")

		-- Show "no seeds" message
		local noSeedsGui = Instance.new("ScreenGui")
		noSeedsGui.Name = "NoSeedsMessage"
		noSeedsGui.Parent = playerGui

		local messageFrame = Instance.new("Frame")
		messageFrame.Size = UDim2.new(0, 350, 0, 150)
		messageFrame.Position = UDim2.new(0.5, -175, 0.5, -75)
		messageFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.8)
		messageFrame.Parent = noSeedsGui

		local messageLabel = Instance.new("TextLabel")
		messageLabel.Size = UDim2.new(1, -20, 0.6, 0)
		messageLabel.Position = UDim2.new(0, 10, 0, 10)
		messageLabel.BackgroundTransparency = 1
		messageLabel.Text = "No seeds available!\n\nVisit the Seed Shop to buy some seeds before planting."
		messageLabel.TextColor3 = Color3.new(1, 1, 1)
		messageLabel.TextScaled = true
		messageLabel.Font = Enum.Font.Gotham
		messageLabel.Parent = messageFrame

		local closeButton = Instance.new("TextButton")
		closeButton.Size = UDim2.new(0, 100, 0, 30)
		closeButton.Position = UDim2.new(0.5, -50, 0.75, 0)
		closeButton.BackgroundColor3 = Color3.new(0.6, 0.6, 0.6)
		closeButton.Text = "OK"
		closeButton.TextColor3 = Color3.new(1, 1, 1)
		closeButton.TextScaled = true
		closeButton.Font = Enum.Font.GothamBold
		closeButton.Parent = messageFrame

		closeButton.MouseButton1Click:Connect(function()
			noSeedsGui:Destroy()
		end)

		return
	end

	-- Create seed selection UI
	print("[GardenClient] Creating seed selection UI with available seeds:")
	for seedType, count in pairs(availableSeeds) do
		print("  " .. seedType .. " x" .. count)
	end

	local plantGui = Instance.new("ScreenGui")
	plantGui.Name = "PlantSeedUI"
	plantGui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 400, 0, 300)
	mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
	mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.new(0.3, 0.6, 0.3)
	mainFrame.Parent = plantGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "?? Plant Seeds - Plot " .. plotId
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -20, 1, -80)
	scrollFrame.Position = UDim2.new(0, 10, 0, 45)
	scrollFrame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
	scrollFrame.BorderSizePixel = 1
	scrollFrame.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.Parent = mainFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	-- Add seed buttons
	local buttonCount = 0
	for seedType, count in pairs(availableSeeds) do
		buttonCount = buttonCount + 1

		local seedButton = Instance.new("TextButton")
		seedButton.Size = UDim2.new(1, -10, 0, 50)
		seedButton.BackgroundColor3 = Color3.new(0.2, 0.7, 0.2)
		seedButton.Text = "?? " .. seedType:gsub("_", " "):gsub("(%a)(%w*)", function(a,b) return string.upper(a)..b end) .. " (x" .. count .. ")"
		seedButton.TextColor3 = Color3.new(1, 1, 1)
		seedButton.TextScaled = true
		seedButton.Font = Enum.Font.Gotham
		seedButton.LayoutOrder = buttonCount
		seedButton.Parent = scrollFrame

		seedButton.MouseButton1Click:Connect(function()
			print("[GardenClient] Selected seed: " .. seedType .. " for plot " .. plotId)

			if remoteEvents.PlantSeedEvent then
				remoteEvents.PlantSeedEvent:FireServer(plotId, seedType)
				plantGui:Destroy()

				-- Show planting message
				local plantingGui = Instance.new("ScreenGui")
				plantingGui.Name = "PlantingMessage"
				plantingGui.Parent = playerGui

				local plantingFrame = Instance.new("Frame")
				plantingFrame.Size = UDim2.new(0, 300, 0, 100)
				plantingFrame.Position = UDim2.new(0.5, -150, 0.3, 0)
				plantingFrame.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
				plantingFrame.Parent = plantingGui

				local plantingLabel = Instance.new("TextLabel")
				plantingLabel.Size = UDim2.new(1, 0, 1, 0)
				plantingLabel.BackgroundTransparency = 1
				plantingLabel.Text = "?? Successfully planted " .. seedType:gsub("_", " ") .. "!"
				plantingLabel.TextColor3 = Color3.new(1, 1, 1)
				plantingLabel.TextScaled = true
				plantingLabel.Font = Enum.Font.GothamBold
				plantingLabel.Parent = plantingFrame

				game:GetService("Debris"):AddItem(plantingGui, 3)
			else
				warn("[GardenClient] PlantSeedEvent not available")
			end
		end)
	end

	-- Update scroll frame canvas size
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, buttonCount * 55)

	-- Add close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 80, 0, 30)
	closeButton.Position = UDim2.new(1, -90, 1, -35)
	closeButton.BackgroundColor3 = Color3.new(0.6, 0.3, 0.3)
	closeButton.Text = "Close"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.Gotham
	closeButton.Parent = mainFrame

	closeButton.MouseButton1Click:Connect(function()
		plantGui:Destroy()
	end)
end

-- Main garden setup function
local function setupGardenInteractions()
	local garden = workspace:FindFirstChild(player.Name .. "_Garden")
	if not garden then
		warn("[GardenClient] Garden not found for player: " .. player.Name)
		return
	end

	print("[GardenClient] Found garden: " .. garden.Name)
	print("[GardenClient] Setting up interactions for garden: " .. garden.Name)

	-- Find all plots in the garden
	local plots = {}
	for _, child in pairs(garden:GetChildren()) do
		local plotId = child.Name:match(player.Name .. "_Plot_(%d+)")
		if plotId then
			plots[tonumber(plotId)] = child
			print("[GardenClient] Found plot: " .. child.Name)
		end
	end

	-- Setup click detection for each plot
	for plotId, plotModel in pairs(plots) do
		local clickDetector = plotModel:FindFirstChild("ClickDetector")
		if not clickDetector then
			clickDetector = Instance.new("ClickDetector")
			clickDetector.MaxActivationDistance = INTERACTION_DISTANCE
			clickDetector.Parent = plotModel
		end

		clickDetector.MouseClick:Connect(function(clickingPlayer)
			if clickingPlayer == player then
				print("[GardenClient] Clicked plot " .. plotId)
				createPlotInteractionUI(plotId)
			end
		end)
	end

	print("[GardenClient] Garden interactions setup complete!")
end

-- Initialize the garden client
local function initializeGardenClient()
	print("[GardenClient] Starting initialization...")

	-- Load remote objects
	if not loadRemoteObjects() then
		warn("[GardenClient] Failed to load remote objects")
		return false
	end

	-- Setup plot data change listener
	if remoteEvents.PlotDataChanged then
		remoteEvents.PlotDataChanged.OnClientEvent:Connect(function(plotId, plotData)
			print("[GardenClient] Received plot data change for plot " .. plotId)
			updatePlotVisual(plotId, plotData)
			updateHarvestUI()

			-- Also refresh inventory in case seeds were consumed
			updateInventoryData(true)
		end)
		print("[GardenClient] Plot data change listener setup complete!")
	end

	-- Setup garden interactions
	local character = player.Character or player.CharacterAdded:Wait()
	if character then
		wait(2) -- Give time for garden to load
		setupGardenInteractions()
	end

	player.CharacterAdded:Connect(function(character)
		wait(2)
		setupGardenInteractions()
	end)

	-- Initial inventory update
	updateInventoryData(true)

	print("[GardenClient] Enhanced garden system v2 initialized successfully!")
	return true
end

-- Start the garden client
spawn(function()
	wait(3) -- Give time for other systems to load
	initializeGardenClient()
end)
