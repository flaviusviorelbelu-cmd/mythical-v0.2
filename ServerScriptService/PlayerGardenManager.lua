-- PlayerGardenManager.lua (ServerScriptService)
-- Simplified wrapper that delegates to the main GardenSystem

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerGardenManager = {}

local DEBUG_MODE = true

-- Debug logging
local function debugLog(message, level)
	level = level or "INFO"
	if DEBUG_MODE then
		print("[PlayerGardenManager] [" .. level .. "] " .. message)
	end
end

-- Wait for GardenSystem to load
local GardenSystem
spawn(function()
	GardenSystem = require(script.Parent:WaitForChild("GardenSystem"))
	debugLog("GardenSystem loaded successfully")
end)

-- Safe require for DataManager
local DataManager
spawn(function()
	DataManager = require(script.Parent:WaitForChild("DataManager"))
end)

-- Track garden assignments for compatibility
local gardenAssignments = {}  -- gardenId -> userId
local playerGardens = {}      -- userId -> gardenId

-- Configuration
local GARDEN_CONFIG = {
	maxGardens = 12,  -- Increased to handle more players
	plotsPerGarden = 9,
	plotGrowthTime = 180,
	maxGrowthStages = 3,
}

-- === GARDEN ASSIGNMENT (For compatibility with existing code) ===
function PlayerGardenManager.AssignGarden(player)
	if not player or not player.UserId then
		debugLog("Invalid player for assignment", "ERROR")
		return nil
	end

	debugLog("Assigning garden to " .. player.Name)

	-- Check if player already has a garden assigned
	if playerGardens[player.UserId] then
		return playerGardens[player.UserId]
	end

	-- Try to restore from saved data
	if DataManager then
		local pdata = DataManager.GetPlayerData(player)
		if pdata and pdata.assignedGarden and pdata.assignedGarden > 0 then
			local gid = pdata.assignedGarden
			if not gardenAssignments[gid] or gardenAssignments[gid] == player.UserId then
				gardenAssignments[gid] = player.UserId
				playerGardens[player.UserId] = gid
				debugLog("Restored garden " .. gid .. " for " .. player.Name)
				return gid
			end
		end
	end

	-- Find an available garden ID
	for gid = 1, GARDEN_CONFIG.maxGardens do
		if not gardenAssignments[gid] then
			gardenAssignments[gid] = player.UserId
			playerGardens[player.UserId] = gid

			-- Save to player data
			if DataManager then
				local pdata = DataManager.GetPlayerData(player)
				if pdata then
					pdata.assignedGarden = gid
					DataManager.SavePlayerData(player, pdata)
				end
			end

			debugLog("Assigned garden " .. gid .. " to " .. player.Name)
			return gid
		end
	end

	debugLog("No gardens available", "ERROR")
	return nil
end

function PlayerGardenManager.GetPlayerGarden(player)
	if not player or not player.UserId then return nil end
	return playerGardens[player.UserId] or PlayerGardenManager.AssignGarden(player)
end

-- === FARMING OPERATIONS (Delegate to GardenSystem) ===
function PlayerGardenManager.PlantSeed(player, plotIndex, seedType)
	if not GardenSystem then
		return false, "Garden system not ready"
	end

	return GardenSystem.PlantSeed(player, plotIndex, seedType)
end

function PlayerGardenManager.HarvestPlant(player, plotIndex)
	if not GardenSystem then
		return false, "Garden system not ready"
	end

	return GardenSystem.Harvest(player, plotIndex)
end

function PlayerGardenManager.GetPlayerPlots(player)
	if not GardenSystem then
		return {}
	end

	return GardenSystem.GetPlayerPlots(player)
end

-- === PLAYER LIFECYCLE ===
function PlayerGardenManager.CleanupPlayer(player)
	local userId = player.UserId

	-- Clean up assignments
	local gardenId = playerGardens[userId]
	if gardenId then
		gardenAssignments[gardenId] = nil
	end
	playerGardens[userId] = nil

	debugLog("Cleaned up garden data for " .. player.Name)
end

-- Connect to player events
Players.PlayerRemoving:Connect(PlayerGardenManager.CleanupPlayer)

-- Auto-assign gardens when players join
Players.PlayerAdded:Connect(function(player)
	-- Wait a bit for everything to load
	task.wait(2)

	local gardenId = PlayerGardenManager.AssignGarden(player)
	if gardenId then
		debugLog("Auto-assigned garden " .. gardenId .. " to " .. player.Name .. " on join")

		-- Trigger garden creation through GardenSystem
		if GardenSystem then
			GardenSystem.InitializePlayerGarden(player)
		end

		-- Trigger UI update if available
		local updateEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerData")
		if updateEvent and DataManager then
			local playerData = DataManager.GetPlayerData(player)
			if playerData then
				updateEvent:FireClient(player, playerData)
			end
		end
	else
		debugLog("Failed to assign garden to " .. player.Name, "ERROR")
	end
end)

-- Export for compatibility
_G.PlayerGardenManager = PlayerGardenManager
debugLog("PlayerGardenManager loaded successfully")
return PlayerGardenManager