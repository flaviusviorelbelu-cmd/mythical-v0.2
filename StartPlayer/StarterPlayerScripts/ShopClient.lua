-- ShopClient.lua (StarterPlayerScripts)
-- Shop interface for buying seeds and eggs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[ShopClient] Initializing shop system...")

-- Wait for remote events
local remoteEvents = {}
local remoteFunctions = {}

spawn(function()
	remoteEvents.BuySeedEvent = ReplicatedStorage:WaitForChild("BuySeedEvent")
	remoteEvents.BuyEgg = ReplicatedStorage:WaitForChild("BuyEgg")
	remoteEvents.ShowFeedback = ReplicatedStorage:WaitForChild("ShowFeedback")
	remoteFunctions.GetPlayerStats = ReplicatedStorage:WaitForChild("GetPlayerStats")
	remoteFunctions.GetShopData = ReplicatedStorage:WaitForChild("GetShopData")
end)

-- Shop UI variables
local shopGui = nil
local isShopOpen = false

-- Seed shop data
local SEED_SHOP = {
	basic_seed = {name = "Magic Wheat", cost = 10, icon = "??"},
	stellar_seed = {name = "Stellar Corn", cost = 50, icon = "??"},
	cosmic_seed = {name = "Cosmic Berries", cost = 200, icon = "??"}
}

-- Egg shop data  
local EGG_SHOP = {
	basic_egg = {name = "Basic Egg", cost = 100, icon = "??"},
	rare_egg = {name = "Rare Egg", cost = 500, icon = "??"},
	legendary_egg = {name = "Legendary Egg", cost = 2000, icon = "??"}
}

-- Create shop UI
local function createShopUI()
	if shopGui then shopGui:Destroy() end

	-- Main shop GUI
	shopGui = Instance.new("ScreenGui")
	shopGui.Name = "ShopGui"
	shopGui.Parent = playerGui

	-- Background frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopFrame"
	mainFrame.Size = UDim2.new(0, 800, 0, 600)
	mainFrame.Position = UDim2.new(0.5, -400, 0.5, -300)
	mainFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = shopGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 15)
	frameCorner.Parent = mainFrame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 60)
	titleBar.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 15)
	titleCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -120, 1, 0)
	titleLabel.Position = UDim2.new(0, 20, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "?? Magical Shop"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = titleBar

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 80, 1, -10)
	closeButton.Position = UDim2.new(1, -90, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	closeButton.Text = "? Close"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.BorderSizePixel = 0
	closeButton.Parent = titleBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		_G.ShopClient.ToggleShop()
	end)

	-- Tab buttons
	local tabFrame = Instance.new("Frame")
	tabFrame.Size = UDim2.new(1, -20, 0, 50)
	tabFrame.Position = UDim2.new(0, 10, 0, 70)
	tabFrame.BackgroundTransparency = 1
	tabFrame.Parent = mainFrame

	local seedTabButton = Instance.new("TextButton")
	seedTabButton.Size = UDim2.new(0.5, -5, 1, 0)
	seedTabButton.Position = UDim2.new(0, 0, 0, 0)
	seedTabButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	seedTabButton.Text = "?? Seeds"
	seedTabButton.TextColor3 = Color3.new(1, 1, 1)
	seedTabButton.TextScaled = true
	seedTabButton.Font = Enum.Font.GothamBold
	seedTabButton.BorderSizePixel = 0
	seedTabButton.Parent = tabFrame

	local seedTabCorner = Instance.new("UICorner")
	seedTabCorner.CornerRadius = UDim.new(0, 8)
	seedTabCorner.Parent = seedTabButton

	local eggTabButton = Instance.new("TextButton")
	eggTabButton.Size = UDim2.new(0.5, -5, 1, 0)
	eggTabButton.Position = UDim2.new(0.5, 5, 0, 0)
	eggTabButton.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
	eggTabButton.Text = "?? Eggs"
	eggTabButton.TextColor3 = Color3.new(1, 1, 1)
	eggTabButton.TextScaled = true
	eggTabButton.Font = Enum.Font.GothamBold
	eggTabButton.BorderSizePixel = 0
	eggTabButton.Parent = tabFrame

	local eggTabCorner = Instance.new("UICorner")
	eggTabCorner.CornerRadius = UDim.new(0, 8)
	eggTabCorner.Parent = eggTabButton

	-- Content frame
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Size = UDim2.new(1, -20, 1, -140)
	contentFrame.Position = UDim2.new(0, 10, 0, 130)
	contentFrame.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 8
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 12)
	contentCorner.Parent = contentFrame

	-- Create seed shop
	local function createSeedShop()
		contentFrame:ClearAllChildren()

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 10)
		listLayout.Parent = contentFrame

		for seedType, seedData in pairs(SEED_SHOP) do
			local itemFrame = Instance.new("Frame")
			itemFrame.Size = UDim2.new(1, -20, 0, 80)
			itemFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
			itemFrame.BorderSizePixel = 0
			itemFrame.Parent = contentFrame

			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 10)
			itemCorner.Parent = itemFrame

			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(0, 60, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = seedData.icon
			iconLabel.TextScaled = true
			iconLabel.Parent = itemFrame

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0, 200, 1, -20)
			nameLabel.Position = UDim2.new(0, 70, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = seedData.name
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = itemFrame

			local priceLabel = Instance.new("TextLabel")
			priceLabel.Size = UDim2.new(0, 200, 0, 20)
			priceLabel.Position = UDim2.new(0, 70, 1, -25)
			priceLabel.BackgroundTransparency = 1
			priceLabel.Text = "?? " .. seedData.cost .. " coins"
			priceLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
			priceLabel.TextScaled = true
			priceLabel.Font = Enum.Font.Gotham
			priceLabel.TextXAlignment = Enum.TextXAlignment.Left
			priceLabel.Parent = itemFrame

			local buyButton = Instance.new("TextButton")
			buyButton.Size = UDim2.new(0, 100, 0, 40)
			buyButton.Position = UDim2.new(1, -110, 0.5, -20)
			buyButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			buyButton.Text = "Buy"
			buyButton.TextColor3 = Color3.new(1, 1, 1)
			buyButton.TextScaled = true
			buyButton.Font = Enum.Font.GothamBold
			buyButton.BorderSizePixel = 0
			buyButton.Parent = itemFrame

			local buyCorner = Instance.new("UICorner")
			buyCorner.CornerRadius = UDim.new(0, 8)
			buyCorner.Parent = buyButton

			buyButton.MouseButton1Click:Connect(function()
				print("[ShopClient] Buying seed:", seedType)
				if remoteEvents.BuySeedEvent then
					remoteEvents.BuySeedEvent:FireServer(seedType, 1)
				end
			end)
		end

		contentFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end

	-- Create egg shop (similar structure)
	local function createEggShop()
		contentFrame:ClearAllChildren()

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 10)
		listLayout.Parent = contentFrame

		for eggType, eggData in pairs(EGG_SHOP) do
			local itemFrame = Instance.new("Frame")
			itemFrame.Size = UDim2.new(1, -20, 0, 80)
			itemFrame.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
			itemFrame.BorderSizePixel = 0
			itemFrame.Parent = contentFrame

			local itemCorner = Instance.new("UICorner")
			itemCorner.CornerRadius = UDim.new(0, 10)
			itemCorner.Parent = itemFrame

			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(0, 60, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = eggData.icon
			iconLabel.TextScaled = true
			iconLabel.Parent = itemFrame

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0, 200, 1, -20)
			nameLabel.Position = UDim2.new(0, 70, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = eggData.name
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = itemFrame

			local priceLabel = Instance.new("TextLabel")
			priceLabel.Size = UDim2.new(0, 200, 0, 20)
			priceLabel.Position = UDim2.new(0, 70, 1, -25)
			priceLabel.BackgroundTransparency = 1
			priceLabel.Text = "?? " .. eggData.cost .. " coins"
			priceLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
			priceLabel.TextScaled = true
			priceLabel.Font = Enum.Font.Gotham
			priceLabel.TextXAlignment = Enum.TextXAlignment.Left
			priceLabel.Parent = itemFrame

			local buyButton = Instance.new("TextButton")
			buyButton.Size = UDim2.new(0, 100, 0, 40)
			buyButton.Position = UDim2.new(1, -110, 0.5, -20)
			buyButton.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
			buyButton.Text = "Buy"
			buyButton.TextColor3 = Color3.new(1, 1, 1)
			buyButton.TextScaled = true
			buyButton.Font = Enum.Font.GothamBold
			buyButton.BorderSizePixel = 0
			buyButton.Parent = itemFrame

			local buyCorner = Instance.new("UICorner")
			buyCorner.CornerRadius = UDim.new(0, 8)
			buyCorner.Parent = buyButton

			buyButton.MouseButton1Click:Connect(function()
				print("[ShopClient] Buying egg:", eggType)
				if remoteEvents.BuyEgg then
					remoteEvents.BuyEgg:FireServer(eggType)
				end
			end)
		end

		contentFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end

	-- Tab button events
	seedTabButton.MouseButton1Click:Connect(createSeedShop)
	eggTabButton.MouseButton1Click:Connect(createEggShop)

	-- Start with seed shop
	createSeedShop()

	-- Animation
	mainFrame.Position = UDim2.new(0.5, -400, 1, 0)
	local openTween = TweenService:Create(
		mainFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -400, 0.5, -300)}
	)
	openTween:Play()
end

-- === PUBLIC FUNCTIONS ===
_G.ShopClient = {
	ToggleShop = function()
		if isShopOpen then
			-- Close shop
			if shopGui then
				local mainFrame = shopGui:FindFirstChild("ShopFrame")
				if mainFrame then
					local closeTween = TweenService:Create(
						mainFrame,
						TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
						{Position = UDim2.new(0.5, -400, 1, 0)}
					)
					closeTween:Play()
					closeTween.Completed:Connect(function()
						shopGui:Destroy()
						shopGui = nil
					end)
				end
			end
			isShopOpen = false
			print("[ShopClient] Shop closed")
		else
			-- Open shop
			createShopUI()
			isShopOpen = true
			print("[ShopClient] Shop opened")
		end
	end
}

print("[ShopClient] Shop system initialized!")

