-- FixedInventoryClient_v2.lua - Complete Inventory with Harvest Display
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[InventoryClient] Initializing enhanced inventory system v2...")

-- Wait for remote objects
local remoteEvents = {}
local remoteFunctions = {}

local function waitForRemote(name, objectType, timeout)
	local startTime = tick()
	timeout = timeout or 10

	repeat
		local obj = ReplicatedStorage:FindFirstChild(name)
		if obj and obj:IsA(objectType) then
			return obj
		end
		wait(0.1)
	until tick() - startTime > timeout

	warn("[InventoryClient] Failed to find " .. objectType .. ": " .. name)
	return nil
end

-- Load remote objects
local function loadRemoteObjects()
	remoteEvents.RequestInventoryUpdate = waitForRemote("RequestInventoryUpdate", "RemoteEvent")
	remoteEvents.SellPlantEvent = waitForRemote("SellPlantEvent", "RemoteEvent") 
	remoteEvents.ShowFeedback = waitForRemote("ShowFeedback", "RemoteEvent")
	remoteFunctions.GetPlayerStats = waitForRemote("GetPlayerStats", "RemoteFunction")

	return true
end

-- Enhanced player inventory with harvested items
local playerInventory = {
	seeds = {
		stellar_seed = 0,
		basic_seed = 0,
		cosmic_seed = 0
	},
	harvested = {
		stellar_seed = 0,
		basic_seed = 0,
		cosmic_seed = 0
	}
}

-- Update inventory from server
local function updateInventoryFromServer()
	if not remoteFunctions.GetPlayerStats then
		warn("[InventoryClient] GetPlayerStats not available")
		return false
	end

	local success, stats = pcall(function()
		return remoteFunctions.GetPlayerStats:InvokeServer()
	end)

	if success and stats then
		print("[InventoryClient] Received stats from server")

		if stats.inventory then
			if stats.inventory.seeds then
				playerInventory.seeds = stats.inventory.seeds
				print("[InventoryClient] Updating seed inventory:")
				for seedType, count in pairs(playerInventory.seeds) do
					print("[InventoryClient]    " .. seedType .. " = " .. count)
				end
			end

			if stats.inventory.harvested then
				playerInventory.harvested = stats.inventory.harvested
				print("[InventoryClient] Updating harvested inventory:")
				for cropType, count in pairs(playerInventory.harvested) do
					print("[InventoryClient]    " .. cropType .. " = " .. count)
				end
			end

			print("[InventoryClient] Inventory updated successfully!")
			return true
		end
	else
		warn("[InventoryClient] Failed to get inventory data:", stats)
	end

	return false
end

-- Enhanced seed display creation
local function createSeedDisplay(parentFrame)
	print("[InventoryClient] Creating enhanced seed display...")

	-- Clear existing seed items
	for _, child in pairs(parentFrame:GetChildren()) do
		if child.Name:find("SeedItem") or child.Name:find("HarvestItem") then
			child:Destroy()
		end
	end

	local yOffset = 0

	-- Create Seeds Section
	local seedsTitle = Instance.new("TextLabel")
	seedsTitle.Name = "SeedsTitle"
	seedsTitle.Size = UDim2.new(1, -20, 0, 30)
	seedsTitle.Position = UDim2.new(0, 10, 0, yOffset)
	seedsTitle.BackgroundColor3 = Color3.new(0.2, 0.4, 0.2)
	seedsTitle.Text = "?? Seeds"
	seedsTitle.TextColor3 = Color3.new(1, 1, 1)
	seedsTitle.TextScaled = true
	seedsTitle.Font = Enum.Font.GothamBold
	seedsTitle.Parent = parentFrame
	yOffset = yOffset + 35

	-- Display seeds
	for seedType, count in pairs(playerInventory.seeds) do
		local seedFrame = Instance.new("Frame")
		seedFrame.Name = "SeedItem_" .. seedType
		seedFrame.Size = UDim2.new(1, -20, 0, 40)
		seedFrame.Position = UDim2.new(0, 10, 0, yOffset)
		seedFrame.BackgroundColor3 = Color3.new(0.1, 0.3, 0.1)
		seedFrame.BorderSizePixel = 1
		seedFrame.BorderColor3 = Color3.new(0.3, 0.5, 0.3)
		seedFrame.Parent = parentFrame

		local seedLabel = Instance.new("TextLabel")
		seedLabel.Size = UDim2.new(0.7, 0, 1, 0)
		seedLabel.Position = UDim2.new(0, 10, 0, 0)
		seedLabel.BackgroundTransparency = 1
		seedLabel.Text = "?? " .. seedType:gsub("_", " "):gsub("(%a)(%w*)", function(a,b) return string.upper(a)..b end)
		seedLabel.TextColor3 = Color3.new(1, 1, 1)
		seedLabel.TextScaled = true
		seedLabel.Font = Enum.Font.Gotham
		seedLabel.TextXAlignment = Enum.TextXAlignment.Left
		seedLabel.Parent = seedFrame

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0.3, -10, 1, 0)
		countLabel.Position = UDim2.new(0.7, 0, 0, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "x" .. count
		countLabel.TextColor3 = count > 0 and Color3.new(0.8, 1, 0.8) or Color3.new(0.5, 0.5, 0.5)
		countLabel.TextScaled = true
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.Parent = seedFrame

		print("[InventoryClient] Created display for: " .. seedType .. " count: " .. count)
		yOffset = yOffset + 45
	end

	-- Create Harvested Section
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
	harvestedTitle.Parent = parentFrame
	yOffset = yOffset + 35

	-- Display harvested items
	local hasHarvestedItems = false
	for cropType, count in pairs(playerInventory.harvested) do
		if count > 0 then
			hasHarvestedItems = true

			local harvestFrame = Instance.new("Frame")
			harvestFrame.Name = "HarvestItem_" .. cropType
			harvestFrame.Size = UDim2.new(1, -20, 0, 50)
			harvestFrame.Position = UDim2.new(0, 10, 0, yOffset)
			harvestFrame.BackgroundColor3 = Color3.new(0.3, 0.2, 0.1)
			harvestFrame.BorderSizePixel = 1
			harvestFrame.BorderColor3 = Color3.new(0.6, 0.4, 0.2)
			harvestFrame.Parent = parentFrame

			local cropLabel = Instance.new("TextLabel")
			cropLabel.Size = UDim2.new(0.5, 0, 1, 0)
			cropLabel.Position = UDim2.new(0, 10, 0, 0)
			cropLabel.BackgroundTransparency = 1
			cropLabel.Text = "?? " .. cropType:gsub("_", " "):gsub("(%a)(%w*)", function(a,b) return string.upper(a)..b end)
			cropLabel.TextColor3 = Color3.new(1, 1, 1)
			cropLabel.TextScaled = true
			cropLabel.Font = Enum.Font.Gotham
			cropLabel.TextXAlignment = Enum.TextXAlignment.Left
			cropLabel.Parent = harvestFrame

			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(0.2, 0, 1, 0)
			countLabel.Position = UDim2.new(0.5, 0, 0, 0)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = "x" .. count
			countLabel.TextColor3 = Color3.new(1, 1, 0.5)
			countLabel.TextScaled = true
			countLabel.Font = Enum.Font.GothamBold
			countLabel.TextXAlignment = Enum.TextXAlignment.Center
			countLabel.Parent = harvestFrame

			local sellButton = Instance.new("TextButton")
			sellButton.Size = UDim2.new(0.25, -5, 0.8, 0)
			sellButton.Position = UDim2.new(0.75, 0, 0.1, 0)
			sellButton.BackgroundColor3 = Color3.new(0.8, 0.6, 0.2)
			sellButton.Text = "Sell All"
			sellButton.TextColor3 = Color3.new(1, 1, 1)
			sellButton.TextScaled = true
			sellButton.Font = Enum.Font.GothamBold
			sellButton.Parent = harvestFrame

			-- Add sell functionality
			sellButton.MouseButton1Click:Connect(function()
				if remoteEvents.SellPlantEvent and count > 0 then
					print("[InventoryClient] Selling " .. count .. "x " .. cropType)
					remoteEvents.SellPlantEvent:FireServer(cropType, count)

					-- Update local inventory immediately
					playerInventory.harvested[cropType] = 0

					-- Refresh display after a brief delay
					wait(0.5)
					updateInventoryFromServer()
					refreshOpenInventory()
				end
			end)

			yOffset = yOffset + 55
		end
	end

	if not hasHarvestedItems then
		local noHarvestLabel = Instance.new("TextLabel")
		noHarvestLabel.Name = "NoHarvestLabel"
		noHarvestLabel.Size = UDim2.new(1, -20, 0, 40)
		noHarvestLabel.Position = UDim2.new(0, 10, 0, yOffset)
		noHarvestLabel.BackgroundTransparency = 1
		noHarvestLabel.Text = "No crops harvested yet.\nPlant and grow crops to harvest!"
		noHarvestLabel.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		noHarvestLabel.TextScaled = true
		noHarvestLabel.Font = Enum.Font.Gotham
		noHarvestLabel.Parent = parentFrame
		yOffset = yOffset + 45
	end

	-- Update scrolling frame canvas size
	parentFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
end

-- Refresh open inventory UI
function refreshOpenInventory()
	local mainUI = playerGui:FindFirstChild("MainUI")
	if mainUI then
		local inventoryFrame = mainUI:FindFirstChild("InventoryFrame")
		if inventoryFrame and inventoryFrame.Visible then
			print("[InventoryClient] Refreshing open inventory UI")
			createSeedDisplay(inventoryFrame)
		end
	end
end

-- Main inventory creation function (called by MainClient)
function createInventoryUI(mainFrame)
	local inventoryFrame = Instance.new("ScrollingFrame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.new(0.8, 0, 0.7, 0)
	inventoryFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
	inventoryFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	inventoryFrame.BorderSizePixel = 2
	inventoryFrame.BorderColor3 = Color3.new(0.3, 0.6, 0.3)
	inventoryFrame.ScrollBarThickness = 10
	inventoryFrame.Visible = false
	inventoryFrame.Parent = mainFrame

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
		print("[InventoryClient] Inventory closed")
	end)

	return inventoryFrame
end

-- Function to show/hide inventory (called by MainClient)
function toggleInventory()
	local mainUI = playerGui:FindFirstChild("MainUI")
	if not mainUI then return end

	local inventoryFrame = mainUI:FindFirstChild("InventoryFrame")
	if not inventoryFrame then return end

	if inventoryFrame.Visible then
		inventoryFrame.Visible = false
		print("[InventoryClient] Inventory closed")
	else
		print("[InventoryClient] Updating inventory from server...")
		updateInventoryFromServer()
		createSeedDisplay(inventoryFrame)
		inventoryFrame.Visible = true
		print("[InventoryClient] Inventory opened")
	end
end

-- Listen for inventory update requests
local function setupInventoryListener()
	if remoteEvents.RequestInventoryUpdate then
		remoteEvents.RequestInventoryUpdate.OnClientEvent:Connect(function()
			print("[InventoryClient] Received inventory update request")
			updateInventoryFromServer()
			refreshOpenInventory()
		end)
	end
end

-- Initialize the inventory system
local function initializeInventorySystem()
	if not loadRemoteObjects() then
		warn("[InventoryClient] Failed to load remote objects")
		return false
	end

	setupInventoryListener()
	updateInventoryFromServer()

	return true
end

-- Make functions global for MainClient
_G.InventoryClient = {
	createInventoryUI = createInventoryUI,
	toggleInventory = toggleInventory,
	updateInventory = updateInventoryFromServer,
	refreshInventory = refreshOpenInventory
}

-- Initialize
spawn(function()
	wait(2)
	if initializeInventorySystem() then
		print("[InventoryClient] Enhanced inventory system v2 initialized!")
	else
		warn("[InventoryClient] Failed to initialize inventory system")
	end
end)
