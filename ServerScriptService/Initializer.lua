-- Initializer.lua - Final Fixed Version
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

print("[Initializer] Starting game initialization...")

-- Initialize core systems in correct order (ONLY ModuleScripts can be required)
local GameManager = require(ServerScriptService.GameManager)
local DataManager = require(ServerScriptService.DataManager)
local MagicalRealm = require(ServerScriptService.MagicalRealm)
local GardenSystem = require(ServerScriptService.GardenSystem)
local ShopManager = require(ServerScriptService.ShopManager)
local PlayerGardenManager = require(ServerScriptService.PlayerGardenManager)

-- NOTE: RemoteEventHandler and BuildingInteractionHandler are Scripts, not ModuleScripts
-- They run automatically and don't need to be required

-- Initialize the magical realm first
MagicalRealm.CreateWorld()
wait(3) -- Give extra time for buildings to spawn and Scripts to initialize

print("[Initializer] All systems initialized successfully!")

-- Handle player connections (Fixed capitalization)
local function onPlayerAdded(player)
	print("[Initializer] Player joined:", player.Name)
	GameManager.OnPlayerAdded(player)

	-- Make sure garden is created
	spawn(function()
		wait(2)
		GardenSystem.InitializePlayerGarden(player)
	end)
end

local function onPlayerRemoving(player)
	print("[Initializer] Player leaving:", player.Name)
	GameManager.OnPlayerRemoving(player)  -- Capitalized function name
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

print("[Initializer] Initialization complete!")
