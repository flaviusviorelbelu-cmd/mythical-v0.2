-- Main Game Manager (ServerScriptService/GameManager)
local GameManager      = {}
local Players          = game:GetService("Players")
local DataManager      = require(script.Parent.DataManager)
local GardenSystem     = require(script.Parent.GardenSystem)
local PlayerGardenManager = require(script.Parent.PlayerGardenManager)

-- Add this function to GameManager.lua
local function resetPlayerAppearance(player)
	if player.Character then
		-- Ensure normal R15 humanoid
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.RigType = Enum.HumanoidRigType.R15
		end

		-- Remove any plugin-added scripts
		for _, obj in pairs(player.Character:GetDescendants()) do
			if obj:IsA("Script") and obj.Name:match("Plugin") then
				obj:Destroy()
			end
		end
	end
end

-- Call this in your OnPlayerAdded function
function GameManager.OnPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		wait(1) -- Give time for character to fully load
		resetPlayerAppearance(player)
	end)
	-- Load player and pet data (DataManager handles all caching/first-time logic)
	DataManager.LoadPlayerData(player)
	DataManager.LoadPetData(player)

	-- Initialize their garden
	GardenSystem.InitializePlayerGarden(player)
end

-- Called when a player is leaving
function GameManager.OnPlayerRemoving(player)
	-- Ensure data is saved
	DataManager.SavePlayerData(player)
	DataManager.SavePetData(player)
end

-- Connect player events
Players.PlayerAdded:Connect(GameManager.OnPlayerAdded)
Players.PlayerRemoving:Connect(GameManager.OnPlayerRemoving)

return GameManager
