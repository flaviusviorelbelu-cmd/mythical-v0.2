-- BuildingInteractionHandler (ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Debug logging
local DEBUG = true
local function debugPrint(...)
	if DEBUG then
		print("[BuildingHandler]", ...)
	end
end

-- Require modules
local DataManager = require(game.ServerScriptService:WaitForChild("DataManager"))
local ShopManager = require(game.ServerScriptService:WaitForChild("ShopManager"))

-- Create RemoteEvent if it doesn't exist
local function createRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
		debugPrint("Created RemoteEvent:", name)
	end
	return event
end

local OpenShop = createRemoteEvent("OpenShop")
local ShowFeedback = createRemoteEvent("ShowFeedback")

-- Create hover UI for buildings
local function createHoverUI(part, text, buildingType)
	-- Remove existing GUI
	local existingGui = part:FindFirstChild("BillboardGui")
	if existingGui then
		existingGui:Destroy()
	end

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "BillboardGui"
	billboardGui.Adornee = part
	billboardGui.Size = UDim2.new(6, 0, 2, 0)
	billboardGui.StudsOffset = Vector3.new(0, 4, 0)
	billboardGui.LightInfluence = 0
	billboardGui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.Parent = billboardGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	-- Add glow effect
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 2
	stroke.Parent = label

	debugPrint("Created hover UI for:", buildingType)
end

-- Create building interaction
local function createBuildingInteraction(part, buildingType)
	-- Remove existing ClickDetector
	local existingClick = part:FindFirstChild("ClickDetector")
	if existingClick then
		existingClick:Destroy()
	end

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 50
	clickDetector.Parent = part

	-- Create hover UI
	local shopEmojis = {
		SeedShop = "??",
		AnimalShop = "??",
		GearShop = "??",
		CraftingStation = "??"
	}

	local emoji = shopEmojis[buildingType] or "??"
	createHoverUI(part, emoji .. " " .. buildingType:gsub("([A-Z])", " %1"):gsub("^%s+", "") .. "\n?? Click to Enter", buildingType)

	-- Handle clicks
	clickDetector.MouseClick:Connect(function(player)
		debugPrint("Player", player.Name, "clicked", buildingType, "at", part.Name)

		-- Visual feedback
		local originalColor = part.Color
		part.Color = Color3.fromRGB(255, 255, 0)
		wait(0.1)
		part.Color = originalColor

		-- Fire shop open event
		OpenShop:FireClient(player, buildingType)

		-- Send feedback
		ShowFeedback:FireClient(player, "Opening " .. buildingType .. "...", "info")
	end)

	debugPrint("Added interaction to:", buildingType, "part:", part.Name)
end

-- Enhanced building search
local function findBuilding(name)
	-- Search in multiple locations
	local searchLocations = {
		Workspace,
		Workspace:FindFirstChild("Buildings"),
		Workspace:FindFirstChild("Shops"),
		Workspace:FindFirstChild("Structures")
	}

	for _, location in pairs(searchLocations) do
		if location then
			-- Direct search
			local building = location:FindFirstChild(name)
			if building then
				return building
			end

			-- Recursive search
			local function searchRecursive(parent)
				for _, child in pairs(parent:GetChildren()) do
					if child.Name == name then
						return child
					end
					local found = searchRecursive(child)
					if found then
						return found
					end
				end
				return nil
			end

			local found = searchRecursive(location)
			if found then
				return found
			end
		end
	end

	return nil
end

-- Setup all buildings
local function setupBuildings()
	debugPrint("Setting up building interactions...")

	local buildingConfigs = {
		{name = "SeedShop", type = "SeedShop"},
		{name = "AnimalShop", type = "AnimalShop"},
		{name = "GearShop", type = "GearShop"},
		{name = "CraftingStation", type = "CraftingStation"},
		-- Alternative names
		{name = "Seed Shop", type = "SeedShop"},
		{name = "Animal Shop", type = "AnimalShop"},
		{name = "Gear Shop", type = "GearShop"},
		{name = "Crafting Station", type = "CraftingStation"}
	}

	for _, config in pairs(buildingConfigs) do
		local building = findBuilding(config.name)
		if building then
			-- Ensure it's a BasePart
			local part = building
			if not building:IsA("BasePart") then
				part = building:FindFirstChild("Main") or building:FindFirstChildOfClass("BasePart")
			end

			if part and part:IsA("BasePart") then
				createBuildingInteraction(part, config.type)

				-- Visual enhancement
				part.Material = Enum.Material.ForceField
				part.Color = Color3.fromRGB(100, 200, 255)

				debugPrint("Successfully setup:", config.name)
			else
				debugPrint("Found building but no valid part:", config.name)
			end
		else
			debugPrint("Could not find building:", config.name)
		end
	end
end

-- Initialize buildings with delay
spawn(function()
	wait(5) -- Wait for map generation
	setupBuildings()

	-- Retry every 10 seconds for missing buildings
	while true do
		wait(10)
		local buildingNames = {"SeedShop", "AnimalShop", "GearShop", "CraftingStation"}
		local missingBuildings = {}

		for _, name in pairs(buildingNames) do
			if not findBuilding(name) then
				table.insert(missingBuildings, name)
			end
		end

		if #missingBuildings > 0 then
			debugPrint("Retrying setup for missing buildings:", table.concat(missingBuildings, ", "))
			setupBuildings()
		else
			debugPrint("All buildings found and setup!")
			break
		end
	end
end)

debugPrint("Building Interaction Handler loaded successfully!")

-- Export for other scripts
return {
	setupBuildings = setupBuildings,
	findBuilding = findBuilding
}
