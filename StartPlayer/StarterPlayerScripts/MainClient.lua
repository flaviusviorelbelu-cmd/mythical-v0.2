-- FixedMainClient_Complete.lua (StarterPlayerScripts)
-- COMPLETE VERSION with full UI implementation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[MainClient] Initializing COMPLETE FIXED version for player:", player.Name)

-- Connection state tracking
local connectionState = {
	remotesLoaded = false,
	dataLoaded = false,
	uiCreated = false
}

-- Enhanced remote event/function loading with retry mechanism
local remoteEvents = {}
local remoteFunctions = {}
local CONNECTION_TIMEOUT = 30 -- seconds
local RETRY_DELAY = 1 -- seconds

-- All remote names
local REMOTE_EVENTS = {
	-- Pet System
	"BuyEgg", "EquipPet", "UnequipPet", "SellPet", "FusePets", "ShowFeedback",
	-- Garden System
	"BuySeedEvent", "PlantSeedEvent", "HarvestPlantEvent", "SellPlantEvent", 
	"RequestInventoryUpdate", "PlotDataChanged", "ShowPlotOptionsEvent"
}

local REMOTE_FUNCTIONS = {
	"GetPetData", "GetPlayerStats", "GetShopData", "GetGardenPlots"
}

-- Enhanced remote loading with timeout and retry
local function loadRemoteObjects()
	local startTime = tick()
	local loadedEvents = {}
	local loadedFunctions = {}

	print("[MainClient] Starting enhanced remote object loading...")

	-- Load RemoteEvents
	spawn(function()
		for _, eventName in ipairs(REMOTE_EVENTS) do
			spawn(function()
				local attempts = 0
				local maxAttempts = CONNECTION_TIMEOUT / RETRY_DELAY

				while attempts < maxAttempts and not loadedEvents[eventName] do
					local success, remote = pcall(function()
						return ReplicatedStorage:WaitForChild(eventName, RETRY_DELAY)
					end)

					if success and remote then
						remoteEvents[eventName] = remote
						loadedEvents[eventName] = true
						print("[MainClient] ? Loaded RemoteEvent:", eventName)
					else
						attempts = attempts + 1
						if attempts % 5 == 0 then -- Log every 5 attempts
							print("[MainClient] ? Still waiting for RemoteEvent:", eventName, "(attempt", attempts, "/", maxAttempts, ")")
						end
					end
				end

				if not loadedEvents[eventName] then
					warn("[MainClient] ? Failed to load RemoteEvent:", eventName, "after", maxAttempts, "attempts")
				end
			end)
		end
	end)

	-- Load RemoteFunctions
	spawn(function()
		for _, funcName in ipairs(REMOTE_FUNCTIONS) do
			spawn(function()
				local attempts = 0
				local maxAttempts = CONNECTION_TIMEOUT / RETRY_DELAY

				while attempts < maxAttempts and not loadedFunctions[funcName] do
					local success, remote = pcall(function()
						return ReplicatedStorage:WaitForChild(funcName, RETRY_DELAY)
					end)

					if success and remote then
						remoteFunctions[funcName] = remote
						loadedFunctions[funcName] = true
						print("[MainClient] ? Loaded RemoteFunction:", funcName)
					else
						attempts = attempts + 1
						if attempts % 5 == 0 then
							print("[MainClient] ? Still waiting for RemoteFunction:", funcName, "(attempt", attempts, "/", maxAttempts, ")")
						end
					end
				end

				if not loadedFunctions[funcName] then
					warn("[MainClient] ? Failed to load RemoteFunction:", funcName, "after", maxAttempts, "attempts")
				end
			end)
		end
	end)

	-- Wait for all to load or timeout
	spawn(function()
		while tick() - startTime < CONNECTION_TIMEOUT do
			local eventsLoaded = 0
			local functionsLoaded = 0

			for _, eventName in ipairs(REMOTE_EVENTS) do
				if loadedEvents[eventName] then
					eventsLoaded = eventsLoaded + 1
				end
			end

			for _, funcName in ipairs(REMOTE_FUNCTIONS) do
				if loadedFunctions[funcName] then
					functionsLoaded = functionsLoaded + 1
				end
			end

			if eventsLoaded == #REMOTE_EVENTS and functionsLoaded == #REMOTE_FUNCTIONS then
				connectionState.remotesLoaded = true
				print("[MainClient] ?? All remote objects loaded successfully!")
				break
			end

			wait(0.5)
		end

		if not connectionState.remotesLoaded then
			warn("[MainClient] ??  Remote loading timeout - some features may not work")
			connectionState.remotesLoaded = true -- Continue anyway
		end
	end)
end

-- Enhanced player data with better defaults
local playerData = {
	coins = 500,
	gems = 5,
	level = 1,
	experience = 0,
	inventory = {seeds = {}, crops = {}, eggs = {}},
	pets = {},
	activePets = {},
	lastUpdate = 0
}

-- Enhanced feedback system
local function showFeedback(message, messageType, duration)
	messageType = messageType or "info"
	duration = duration or 3

	-- Prevent spam by checking for existing feedback
	local existing = playerGui:FindFirstChild("FeedbackMessage")
	if existing then
		existing:Destroy()
	end

	local feedbackGui = Instance.new("ScreenGui")
	feedbackGui.Name = "FeedbackMessage"
	feedbackGui.ResetOnSpawn = false
	feedbackGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 400, 0, 80)
	frame.Position = UDim2.new(0.5, -200, 0, -100)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = feedbackGui

	-- Enhanced colors and styling
	local colors = {
		success = Color3.fromRGB(46, 204, 113),
		error = Color3.fromRGB(231, 76, 60),
		warning = Color3.fromRGB(241, 196, 15),
		info = Color3.fromRGB(52, 152, 219)
	}
	frame.BackgroundColor3 = colors[messageType] or colors.info

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -20, 1, 0)
	textLabel.Position = UDim2.new(0, 10, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame

	-- Enhanced animations
	local tweenIn = TweenService:Create(
		frame,
		TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -200, 0, 50)}
	)
	tweenIn:Play()

	-- Auto-dismiss
	spawn(function()
		wait(duration)
		if feedbackGui and feedbackGui.Parent then
			local tweenOut = TweenService:Create(
				frame,
				TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{Position = UDim2.new(0.5, -200, 0, -100), BackgroundTransparency = 1}
			)
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if feedbackGui and feedbackGui.Parent then
					feedbackGui:Destroy()
				end
			end)
		end
	end)
end

-- Create inventory frame directly in MainClient
local function createInventoryFrame(mainUI)
	local inventoryFrame = Instance.new("ScrollingFrame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.new(0.8, 0, 0.7, 0)
	inventoryFrame.Position = UDim2.new(0.1, 0, 0.15, 0)
	inventoryFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	inventoryFrame.BorderSizePixel = 2
	inventoryFrame.BorderColor3 = Color3.new(0.3, 0.6, 0.3)
	inventoryFrame.ScrollBarThickness = 10
	inventoryFrame.Visible = false
	inventoryFrame.Parent = mainUI

	-- Add title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 5)
	title.BackgroundColor3 = Color3.new(0.2, 0.4, 0.2)
	title.Text = "?? Inventory"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = inventoryFrame

	-- Create close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.new(0.8, 0.3, 0.3)
	closeButton.Text = "?"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = inventoryFrame

	closeButton.MouseButton1Click:Connect(function()
		inventoryFrame.Visible = false
		print("[MainClient] Inventory closed via X button")
	end)

	return inventoryFrame
end

-- Update inventory display
local function updateInventoryDisplay(inventoryFrame)
	-- Clear existing items
	for _, child in pairs(inventoryFrame:GetChildren()) do
		if child.Name:find("Item") then
			child:Destroy()
		end
	end

	local yOffset = 50

	-- Seeds section
	local seedsTitle = Instance.new("TextLabel")
	seedsTitle.Name = "SeedsTitle"
	seedsTitle.Size = UDim2.new(1, -20, 0, 30)
	seedsTitle.Position = UDim2.new(0, 10, 0, yOffset)
	seedsTitle.BackgroundColor3 = Color3.new(0.2, 0.4, 0.2)
	seedsTitle.Text = "?? Seeds"
	seedsTitle.TextColor3 = Color3.new(1, 1, 1)
	seedsTitle.TextScaled = true
	seedsTitle.Font = Enum.Font.GothamBold
	seedsTitle.Parent = inventoryFrame
	yOffset = yOffset + 35

	-- Add seed items
	local seeds = {
		{type = "stellar_seed", name = "Stellar Corn", count = playerData.inventory and playerData.inventory.seeds and playerData.inventory.seeds.stellar_seed or 0},
		{type = "basic_seed", name = "Magic Wheat", count = playerData.inventory and playerData.inventory.seeds and playerData.inventory.seeds.basic_seed or 0},
		{type = "cosmic_seed", name = "Cosmic Berries", count = playerData.inventory and playerData.inventory.seeds and playerData.inventory.seeds.cosmic_seed or 0}
	}

	for _, seed in ipairs(seeds) do
		local seedItem = Instance.new("Frame")
		seedItem.Name = "SeedItem_" .. seed.type
		seedItem.Size = UDim2.new(1, -20, 0, 40)
		seedItem.Position = UDim2.new(0, 10, 0, yOffset)
		seedItem.BackgroundColor3 = Color3.new(0.1, 0.3, 0.1)
		seedItem.BorderSizePixel = 1
		seedItem.BorderColor3 = Color3.new(0.3, 0.5, 0.3)
		seedItem.Parent = inventoryFrame

		local seedLabel = Instance.new("TextLabel")
		seedLabel.Size = UDim2.new(0.7, 0, 1, 0)
		seedLabel.Position = UDim2.new(0, 10, 0, 0)
		seedLabel.BackgroundTransparency = 1
		seedLabel.Text = "?? " .. seed.name
		seedLabel.TextColor3 = Color3.new(1, 1, 1)
		seedLabel.TextScaled = true
		seedLabel.Font = Enum.Font.Gotham
		seedLabel.TextXAlignment = Enum.TextXAlignment.Left
		seedLabel.Parent = seedItem

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0.3, -10, 1, 0)
		countLabel.Position = UDim2.new(0.7, 0, 0, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "x" .. seed.count
		countLabel.TextColor3 = seed.count > 0 and Color3.new(0.8, 1, 0.8) or Color3.new(0.5, 0.5, 0.5)
		countLabel.TextScaled = true
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.Parent = seedItem

		yOffset = yOffset + 45
	end

	-- Harvested section
	yOffset = yOffset + 10
	local harvestedTitle = Instance.new("TextLabel")
	harvestedTitle.Name = "HarvestedTitle"
	harvestedTitle.Size = UDim2.new(1, -20, 0, 30)
	harvestedTitle.Position = UDim2.new(0, 10, 0, yOffset)
	harvestedTitle.BackgroundColor3 = Color3.new(0.4, 0.3, 0.1)
	harvestedTitle.Text = "?? Harvested Crops"
	harvestedTitle.TextColor3 = Color3.new(1, 1, 1)
	harvestedTitle.TextScaled = true
	harvestedTitle.Font = Enum.Font.GothamBold
	harvestedTitle.Parent = inventoryFrame
	yOffset = yOffset + 35

	-- Check for harvested items
	local hasHarvested = false
	if playerData.inventory and playerData.inventory.harvested then
		for cropType, count in pairs(playerData.inventory.harvested) do
			if count > 0 then
				hasHarvested = true

				local harvestItem = Instance.new("Frame")
				harvestItem.Name = "HarvestItem_" .. cropType
				harvestItem.Size = UDim2.new(1, -20, 0, 50)
				harvestItem.Position = UDim2.new(0, 10, 0, yOffset)
				harvestItem.BackgroundColor3 = Color3.new(0.3, 0.2, 0.1)
				harvestItem.BorderSizePixel = 1
				harvestItem.BorderColor3 = Color3.new(0.6, 0.4, 0.2)
				harvestItem.Parent = inventoryFrame

				local cropLabel = Instance.new("TextLabel")
				cropLabel.Size = UDim2.new(0.5, 0, 1, 0)
				cropLabel.Position = UDim2.new(0, 10, 0, 0)
				cropLabel.BackgroundTransparency = 1
				cropLabel.Text = "?? " .. cropType:gsub("_", " "):gsub("(%a)(%w*)", function(a,b) return string.upper(a)..b end)
				cropLabel.TextColor3 = Color3.new(1, 1, 1)
				cropLabel.TextScaled = true
				cropLabel.Font = Enum.Font.Gotham
				cropLabel.TextXAlignment = Enum.TextXAlignment.Left
				cropLabel.Parent = harvestItem

				local countLabel = Instance.new("TextLabel")
				countLabel.Size = UDim2.new(0.2, 0, 1, 0)
				countLabel.Position = UDim2.new(0.5, 0, 0, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "x" .. count
				countLabel.TextColor3 = Color3.new(1, 1, 0.5)
				countLabel.TextScaled = true
				countLabel.Font = Enum.Font.GothamBold
				countLabel.TextXAlignment = Enum.TextXAlignment.Center
				countLabel.Parent = harvestItem

				local sellButton = Instance.new("TextButton")
				sellButton.Size = UDim2.new(0.25, -5, 0.8, 0)
				sellButton.Position = UDim2.new(0.75, 0, 0.1, 0)
				sellButton.BackgroundColor3 = Color3.new(0.8, 0.6, 0.2)
				sellButton.Text = "Sell All"
				sellButton.TextColor3 = Color3.new(1, 1, 1)
				sellButton.TextScaled = true
				sellButton.Font = Enum.Font.GothamBold
				sellButton.Parent = harvestItem

				-- Add sell functionality
				sellButton.MouseButton1Click:Connect(function()
					if remoteEvents.SellPlantEvent then
						print("[MainClient] Selling " .. count .. "x " .. cropType)
						remoteEvents.SellPlantEvent:FireServer(cropType, count)
						showFeedback("Selling " .. cropType .. "...", "info")

						-- Refresh after selling
						wait(1)
						updatePlayerData()
						if inventoryFrame.Visible then
							updateInventoryDisplay(inventoryFrame)
						end
					end
				end)

				yOffset = yOffset + 55
			end
		end
	end

	if not hasHarvested then
		local noHarvestLabel = Instance.new("TextLabel")
		noHarvestLabel.Name = "NoHarvestLabel"
		noHarvestLabel.Size = UDim2.new(1, -20, 0, 40)
		noHarvestLabel.Position = UDim2.new(0, 10, 0, yOffset)
		noHarvestLabel.BackgroundTransparency = 1
		noHarvestLabel.Text = "No crops harvested yet.\nPlant and grow crops to harvest!"
		noHarvestLabel.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		noHarvestLabel.TextScaled = true
		noHarvestLabel.Font = Enum.Font.Gotham
		noHarvestLabel.Parent = inventoryFrame
		yOffset = yOffset + 45
	end

	-- Update canvas size
	inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)

	print("[MainClient] Updated inventory display")
end


-- Enhanced data management with retry logic
local function updatePlayerData()
	if not connectionState.remotesLoaded or not remoteFunctions.GetPlayerStats then
		print("[MainClient] ? Skipping data update - remotes not ready")
		return false
	end

	spawn(function()
		local maxRetries = 3
		local retryDelay = 2

		for attempt = 1, maxRetries do
			local success, stats = pcall(function()
				return remoteFunctions.GetPlayerStats:InvokeServer()
			end)

			if success and stats then
				-- Update local data
				playerData.coins = stats.coins or playerData.coins
				playerData.gems = stats.gems or playerData.gems
				playerData.level = stats.level or playerData.level
				playerData.experience = stats.experience or playerData.experience
				playerData.lastUpdate = tick()

				-- Merge inventory data
				if stats.inventory then
					playerData.inventory.seeds = stats.inventory.seeds or playerData.inventory.seeds
					playerData.inventory.crops = stats.inventory.crops or playerData.inventory.crops
					playerData.inventory.eggs = stats.inventory.eggs or playerData.inventory.eggs
				end

				connectionState.dataLoaded = true
				print("[MainClient] ? Data updated successfully - Coins:", playerData.coins, "Level:", playerData.level)

				-- Update UI
				if _G.MainClient then
					_G.MainClient.UpdateStatsDisplay()
				end

				return
			else
				print("[MainClient] ? Data update attempt", attempt, "/", maxRetries, "failed:", stats or "unknown error")
				if attempt < maxRetries then
					wait(retryDelay)
				else
					warn("[MainClient] ??  All data update attempts failed - using cached data")
					if _G.MainClient then
						_G.MainClient.UpdateStatsDisplay()
					end
				end
			end
		end
	end)
end

-- COMPLETE UI creation function
local function createMainUI()
	if connectionState.uiCreated then
		print("[MainClient] UI already created, skipping...")
		return
	end

	print("[MainClient] Creating complete main UI...")

	-- Remove any existing UI first
	local existingUI = playerGui:FindFirstChild("MainGameUI")
	if existingUI then
		existingUI:Destroy()
	end

	-- Main UI Container
	local mainUI = Instance.new("ScreenGui")
	mainUI.Name = "MainGameUI"
	mainUI.ResetOnSpawn = false
	mainUI.Parent = playerGui

	-- Connection status indicator
	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "ConnectionStatus"
	statusFrame.Size = UDim2.new(0, 200, 0, 30)
	statusFrame.Position = UDim2.new(1, -210, 0, 10)
	statusFrame.BackgroundColor3 = connectionState.remotesLoaded and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(241, 196, 15)
	statusFrame.BorderSizePixel = 0
	statusFrame.Parent = mainUI

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 15)
	statusCorner.Parent = statusFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -10, 1, 0)
	statusLabel.Position = UDim2.new(0, 5, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = connectionState.remotesLoaded and "?? Connected" or "?? Connecting..."
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Parent = statusFrame

	-- Top Stats Bar
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(1, 0, 0, 60)
	statsFrame.Position = UDim2.new(0, 0, 0, 45)
	statsFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = mainUI

	-- Coins Display
	local coinsFrame = Instance.new("Frame")
	coinsFrame.Name = "CoinsFrame"
	coinsFrame.Size = UDim2.new(0, 150, 1, -10)
	coinsFrame.Position = UDim2.new(0, 10, 0, 5)
	coinsFrame.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
	coinsFrame.BorderSizePixel = 0
	coinsFrame.Parent = statsFrame

	local coinsCorner = Instance.new("UICorner")
	coinsCorner.CornerRadius = UDim.new(0, 8)
	coinsCorner.Parent = coinsFrame

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(1, -20, 1, 0)
	coinsLabel.Position = UDim2.new(0, 10, 0, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "?? " .. tostring(playerData.coins)
	coinsLabel.TextColor3 = Color3.new(1, 1, 1)
	coinsLabel.TextScaled = true
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Parent = coinsFrame

	-- Gems Display
	local gemsFrame = Instance.new("Frame")
	gemsFrame.Name = "GemsFrame"
	gemsFrame.Size = UDim2.new(0, 150, 1, -10)
	gemsFrame.Position = UDim2.new(0, 170, 0, 5)
	gemsFrame.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
	gemsFrame.BorderSizePixel = 0
	gemsFrame.Parent = statsFrame

	local gemsCorner = Instance.new("UICorner")
	gemsCorner.CornerRadius = UDim.new(0, 8)
	gemsCorner.Parent = gemsFrame

	local gemsLabel = Instance.new("TextLabel")
	gemsLabel.Name = "GemsLabel"
	gemsLabel.Size = UDim2.new(1, -20, 1, 0)
	gemsLabel.Position = UDim2.new(0, 10, 0, 0)
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.Text = "?? " .. tostring(playerData.gems)
	gemsLabel.TextColor3 = Color3.new(1, 1, 1)
	gemsLabel.TextScaled = true
	gemsLabel.Font = Enum.Font.GothamBold
	gemsLabel.Parent = gemsFrame

	-- Level Display
	local levelFrame = Instance.new("Frame")
	levelFrame.Name = "LevelFrame"
	levelFrame.Size = UDim2.new(0, 120, 1, -10)
	levelFrame.Position = UDim2.new(0, 330, 0, 5)
	levelFrame.BackgroundColor3 = Color3.fromRGB(26, 188, 156)
	levelFrame.BorderSizePixel = 0
	levelFrame.Parent = statsFrame

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 8)
	levelCorner.Parent = levelFrame

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, -20, 1, 0)
	levelLabel.Position = UDim2.new(0, 10, 0, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "? Level " .. tostring(playerData.level)
	levelLabel.TextColor3 = Color3.new(1, 1, 1)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = levelFrame

	-- Bottom Menu Buttons
	local menuFrame = Instance.new("Frame")
	menuFrame.Name = "MenuFrame"
	menuFrame.Size = UDim2.new(1, 0, 0, 80)
	menuFrame.Position = UDim2.new(0, 0, 1, -80)
	menuFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	menuFrame.BorderSizePixel = 0
	menuFrame.Parent = mainUI

	-- Menu buttons
	local buttons = {
		{name = "Shop", color = Color3.fromRGB(46, 204, 113), icon = "??"},
		{name = "Inventory", color = Color3.fromRGB(52, 152, 219), icon = "??"},
		{name = "Pets", color = Color3.fromRGB(155, 89, 182), icon = "??"},
		{name = "Garden", color = Color3.fromRGB(230, 126, 34), icon = "??"}
	}

	for i, buttonData in ipairs(buttons) do
		local button = Instance.new("TextButton")
		button.Name = buttonData.name .. "Button"
		button.Size = UDim2.new(0.25, -10, 1, -10)
		button.Position = UDim2.new((i-1) * 0.25, 5, 0, 5)
		button.BackgroundColor3 = buttonData.color
		button.BorderSizePixel = 0
		button.Text = buttonData.icon .. " " .. buttonData.name
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		button.Parent = menuFrame

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button

		-- Button click handlers
		button.MouseButton1Click:Connect(function()
			print("[MainClient] " .. buttonData.name .. " button clicked!")
			showFeedback(buttonData.name .. " menu clicked! ??", "info")
			if _G.MainClient then
				_G.MainClient.ToggleMenu(buttonData.name)
			end
		end)

		-- Button hover effects
		button.MouseEnter:Connect(function()
			local hoverTween = TweenService:Create(
				button,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{Size = UDim2.new(0.25, -5, 1, -5)}
			)
			hoverTween:Play()
		end)

		button.MouseLeave:Connect(function()
			local unhoverTween = TweenService:Create(
				button,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{Size = UDim2.new(0.25, -10, 1, -10)}
			)
			unhoverTween:Play()
		end)
	end

	connectionState.uiCreated = true
	print("[MainClient] ? Complete UI created successfully with", #buttons, "menu buttons")
	return mainUI
end

-- Global client interface
_G.MainClient = {
	-- Enhanced status display update
	UpdateStatsDisplay = function()
		local mainUI = playerGui:FindFirstChild("MainGameUI")
		if not mainUI then
			print("[MainClient] MainGameUI not found for stats update")
			return
		end

		local statsFrame = mainUI:FindFirstChild("StatsFrame")
		if statsFrame then
			-- Update coins
			local coinsFrame = statsFrame:FindFirstChild("CoinsFrame")
			if coinsFrame and coinsFrame:FindFirstChild("CoinsLabel") then
				coinsFrame.CoinsLabel.Text = "?? " .. tostring(playerData.coins)
			end

			-- Update gems
			local gemsFrame = statsFrame:FindFirstChild("GemsFrame")
			if gemsFrame and gemsFrame:FindFirstChild("GemsLabel") then
				gemsFrame.GemsLabel.Text = "?? " .. tostring(playerData.gems)
			end

			-- Update level
			local levelFrame = statsFrame:FindFirstChild("LevelFrame")
			if levelFrame and levelFrame:FindFirstChild("LevelLabel") then
				levelFrame.LevelLabel.Text = "? Level " .. tostring(playerData.level)
			end

			print("[MainClient] ? UI stats updated - Coins:", playerData.coins, "Gems:", playerData.gems, "Level:", playerData.level)
		end

		-- Update connection status
		local statusFrame = mainUI:FindFirstChild("ConnectionStatus")
		if statusFrame and statusFrame:FindFirstChild("StatusLabel") then
			if connectionState.dataLoaded then
				statusFrame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
				statusFrame.StatusLabel.Text = "?? Connected"
			else
				statusFrame.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
				statusFrame.StatusLabel.Text = "?? Syncing..."
			end
		end
	end,

	-- Enhanced Toggle menu with direct inventory handling
	ToggleMenu = function(menuName)
		print("[MainClient] Toggling", menuName, "menu")

		if menuName == "Shop" then
			if _G.ShopClient then
				_G.ShopClient.ToggleShop()
			else
				showFeedback("Shop system not available", "warning")
			end
		elseif menuName == "Inventory" then
			-- ? FIXED: Handle inventory directly in MainClient
			local mainUI = playerGui:FindFirstChild("MainGameUI")
			if mainUI then
				local inventoryFrame = mainUI:FindFirstChild("InventoryFrame")
				if not inventoryFrame then
					-- Create inventory frame if it doesn't exist
					inventoryFrame = createInventoryFrame(mainUI)
				end

				if inventoryFrame.Visible then
					inventoryFrame.Visible = false
					print("[MainClient] Inventory closed")
				else
					-- Update inventory data before showing
					updateInventoryDisplay(inventoryFrame)
					inventoryFrame.Visible = true
					print("[MainClient] Inventory opened")
				end
			else
				showFeedback("UI not ready", "warning")
			end
		elseif menuName == "Pets" then
			if _G.PetClient then
				_G.PetClient.TogglePetMenu()
			else
				showFeedback("Pet system not available", "warning")
			end
		elseif menuName == "Garden" then
			if _G.GardenClient then
				_G.GardenClient.ToggleGardenMenu()
			else
				showFeedback("Garden system not available", "warning")
			end
		end
	end,


	-- Get current data
	GetPlayerData = function()
		return playerData
	end,

	-- Enhanced feedback
	ShowFeedback = showFeedback,

	-- Force data refresh
	RefreshData = updatePlayerData,

	-- Connection status
	GetConnectionStatus = function()
		return connectionState
	end,

	-- Force UI recreation
	RecreateUI = function()
		connectionState.uiCreated = false
		createMainUI()
		updatePlayerData()
	end
}

-- Enhanced initialization sequence
spawn(function()
	print("[MainClient] ?? Starting complete enhanced initialization...")

	-- Wait for character
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	print("[MainClient] ? Character loaded")

	-- Load remote objects
	loadRemoteObjects()

	-- Wait for remotes to be ready
	while not connectionState.remotesLoaded do
		wait(0.5)
	end

	-- Create UI
	createMainUI()

	-- Load initial data
	updatePlayerData()

	-- Set up feedback handler
	if remoteEvents.ShowFeedback then
		remoteEvents.ShowFeedback.OnClientEvent:Connect(function(message, messageType)
			showFeedback(message, messageType)
		end)
		print("[MainClient] ? Feedback handler connected")
	end

	-- Set up periodic data refresh
	spawn(function()
		while player.Parent do
			wait(15) -- Refresh every 15 seconds
			updatePlayerData()
		end
	end)

	print("[MainClient] ?? Complete enhanced initialization finished!")
	showFeedback("Welcome to Mythical Realm, " .. player.Name .. "! ??", "success", 4)
end)

-- Debug commands
if game.Players.LocalPlayer.Name == "deiandario" then -- Your username
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.F1 then
			_G.MainClient.RecreateUI()
			showFeedback("UI Recreated! ??", "info")
		elseif input.KeyCode == Enum.KeyCode.F2 then
			_G.MainClient.RefreshData()
			showFeedback("Data Refreshed! ??", "info")
		elseif input.KeyCode == Enum.KeyCode.F3 then
			print("[MainClient] Debug Info:")
			print("  Connection State:", connectionState)
			print("  Player Data:", playerData)
			print("  Remote Events:", #remoteEvents, "loaded")
			print("  Remote Functions:", #remoteFunctions, "loaded")
			showFeedback("Debug info printed to console! ??", "info")
		end
	end)
end

print("[MainClient] ? COMPLETE FIXED MainClient loaded successfully!")