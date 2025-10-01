-- MagicalRealm.lua - Updated with Shop Buildings
local MagicalRealm = {}
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local workspace = game:GetService("Workspace")

print("[MagicalRealm][INFO] MagicalRealm module loaded")

-- Configuration
local WORLD_CONFIG = {
	MAIN_ISLAND_SIZE = Vector3.new(512, 12, 512),
	MAIN_ISLAND_POSITION = Vector3.new(0, 0, 0),
	SHOP_POSITIONS = {
		SeedShop = Vector3.new(-40, 12, -40),
		AnimalShop = Vector3.new(40, 12, -40),
		GearShop = Vector3.new(-40, 12, 40),
		CraftingStation = Vector3.new(40, 12, 40)
	}
}

-- Create the main floating island
local function createMainIsland()
	print("[MagicalRealm][INFO] Creating main island...")

	-- Main island base
	local island = Instance.new("Part")
	island.Name = "MainIsland"
	island.Size = WORLD_CONFIG.MAIN_ISLAND_SIZE
	island.Position = WORLD_CONFIG.MAIN_ISLAND_POSITION
	island.Material = Enum.Material.Grass
	island.BrickColor = BrickColor.new("Bright green")
	island.Anchored = true
	island.CanCollide = true
	island.Parent = workspace

	-- Add some texture to the island
	local texture = Instance.new("Texture")
	texture.Texture = "rbxasset://textures/terrain/grass.png"
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = 20
	texture.StudsPerTileV = 20
	texture.Parent = island

	return island
end

-- Create shop buildings
local function createShopBuilding(name, position, color)
	print("[MagicalRealm][INFO] Creating shop building:", name)

	-- Main building structure
	local building = Instance.new("Part")
	building.Name = name
	building.Size = Vector3.new(20, 15, 20)
	building.Position = position
	building.Material = Enum.Material.Brick
	building.BrickColor = BrickColor.new(color or "Bright blue")
	building.Anchored = true
	building.CanCollide = true
	building.Parent = workspace

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(24, 2, 24)
	roof.Position = position + Vector3.new(0, 8.5, 0)
	roof.Material = Enum.Material.Wood
	roof.BrickColor = BrickColor.new("Really red")
	roof.Anchored = true
	roof.CanCollide = false
	roof.Parent = building

	-- Door
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size = Vector3.new(1, 8, 4)
	door.Position = position + Vector3.new(0, -3.5, -10)
	door.Material = Enum.Material.Wood
	door.BrickColor = BrickColor.new("Brown")
	door.Anchored = true
	door.CanCollide = false
	door.Parent = building

	-- Shop sign
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(0.5, 4, 8)
	sign.Position = position + Vector3.new(0, 3, -10.5)
	sign.Material = Enum.Material.Wood
	sign.BrickColor = BrickColor.new("Really black")
	sign.Anchored = true
	sign.CanCollide = false
	sign.Parent = building

	-- Sign text
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = sign

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = name:gsub("Shop", " Shop"):gsub("Station", " Station")
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.Fantasy
	textLabel.Parent = surfaceGui

	-- Click detector for interaction
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 20
	clickDetector.Parent = building

	-- Glowing effect
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 1
	pointLight.Color = Color3.fromRGB(100, 200, 255)
	pointLight.Range = 30
	pointLight.Parent = building

	return building
end

-- Create decorative elements
local function createMagicalElements()
	print("[MagicalRealm][INFO] Creating magical elements...")

	-- Floating crystals around the island
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local distance = 120
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		local y = math.random(20, 50)

		local crystal = Instance.new("Part")
		crystal.Name = "FloatingCrystal" .. i
		crystal.Size = Vector3.new(4, 8, 4)
		crystal.Position = Vector3.new(x, y, z)
		crystal.Material = Enum.Material.Neon
		crystal.BrickColor = BrickColor.new("Bright blue")
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.Parent = workspace

		-- Rotation animation
		local rotationTween = TweenService:Create(
			crystal,
			TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{CFrame = crystal.CFrame * CFrame.Angles(0, math.pi * 2, 0)}
		)
		rotationTween:Play()

		-- Glowing effect
		local pointLight = Instance.new("PointLight")
		pointLight.Brightness = 2
		pointLight.Color = Color3.fromRGB(100, 200, 255)
		pointLight.Range = 20
		pointLight.Parent = crystal
	end

	-- Magical trees on the island
	for i = 1, 12 do
		local x = math.random(-80, 80)
		local z = math.random(-80, 80)

		-- Tree trunk
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk" .. i
		trunk.Size = Vector3.new(3, 12, 3)
		trunk.Position = Vector3.new(x, 16, z)
		trunk.Material = Enum.Material.Wood
		trunk.BrickColor = BrickColor.new("Brown")
		trunk.Anchored = true
		trunk.Parent = workspace

		-- Tree leaves (glowing)
		local leaves = Instance.new("Part")
		leaves.Name = "TreeLeaves" .. i
		leaves.Size = Vector3.new(12, 8, 12)
		leaves.Position = Vector3.new(x, 24, z)
		leaves.Material = Enum.Material.Neon
		leaves.BrickColor = BrickColor.new("Bright green")
		leaves.Anchored = true
		leaves.CanCollide = false
		leaves.Parent = workspace

		-- Magical glow
		local pointLight = Instance.new("PointLight")
		pointLight.Brightness = 1
		pointLight.Color = Color3.fromRGB(50, 255, 50)
		pointLight.Range = 15
		pointLight.Parent = leaves
	end
end

-- Create ambient lighting
local function setupLighting()
	print("[MagicalRealm][INFO] Setting up magical lighting...")

	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(50, 50, 100)
	lighting.Brightness = 0.5
	lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 50)
	lighting.ColorShift_Top = Color3.fromRGB(100, 100, 255)
	lighting.FogColor = Color3.fromRGB(100, 150, 255)
	lighting.FogEnd = 500
	lighting.FogStart = 100
end

-- Main world creation function
function MagicalRealm.CreateWorld()
	print("[MagicalRealm][INFO] Creating magical world...")

	-- Create main island
	local mainIsland = createMainIsland()

	-- Create shop buildings with the exact names BuildingInteractionHandler expects
	createShopBuilding("SeedShop", WORLD_CONFIG.SHOP_POSITIONS.SeedShop, "Bright green")
	createShopBuilding("AnimalShop", WORLD_CONFIG.SHOP_POSITIONS.AnimalShop, "Bright orange")
	createShopBuilding("GearShop", WORLD_CONFIG.SHOP_POSITIONS.GearShop, "Bright red")
	createShopBuilding("CraftingStation", WORLD_CONFIG.SHOP_POSITIONS.CraftingStation, "Bright yellow")

	-- Create magical elements
	createMagicalElements()

	-- Setup lighting
	setupLighting()

	print("[MagicalRealm][INFO] Magical world created successfully!")
	return mainIsland
end

-- Get shop building by name
function MagicalRealm.GetShopBuilding(shopName)
	return workspace:FindFirstChild(shopName)
end

-- Get all shop buildings
function MagicalRealm.GetAllShopBuildings()
	return {
		SeedShop = workspace:FindFirstChild("SeedShop"),
		AnimalShop = workspace:FindFirstChild("AnimalShop"),
		GearShop = workspace:FindFirstChild("GearShop"),
		CraftingStation = workspace:FindFirstChild("CraftingStation")
	}
end

return MagicalRealm


