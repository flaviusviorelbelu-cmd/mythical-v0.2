-- Game Configurations (ModuleScript in ReplicatedStorage)
local GameConfig = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService"):GetDataStore("PlayerData")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Create ReplicatedStorage structure
local RemoteEvents = Instance.new("Folder")
RemoteEvents.Name = "RemoteEvents"
RemoteEvents.Parent = ReplicatedStorage

local RemoteFunctions = Instance.new("Folder")
RemoteFunctions.Name = "RemoteFunctions"
RemoteFunctions.Parent = ReplicatedStorage

-- Create Remote Events for client-server communication
local plantSeedEvent = Instance.new("RemoteEvent")
plantSeedEvent.Name = "PlantSeedEvent"
plantSeedEvent.Parent = RemoteEvents

local harvestPlantEvent = Instance.new("RemoteEvent")
harvestPlantEvent.Name = "HarvestPlantEvent"
harvestPlantEvent.Parent = RemoteEvents

local buySeedEvent = Instance.new("RemoteEvent")
buySeedEvent.Name = "BuySeedEvent"
buySeedEvent.Parent = RemoteEvents

local sellPlantsEvent = Instance.new("RemoteEvent")
sellPlantsEvent.Name = "SellPlantsEvent"
sellPlantsEvent.Parent = RemoteEvents

-- After existing RemoteEvents:
local showPlotOptions = Instance.new("RemoteEvent")
showPlotOptions.Name = "ShowPlotOptionsEvent"
showPlotOptions.Parent = ReplicatedStorage.RemoteEvents

-- Create Remote Function for data requests
local getPlayerDataFunction = Instance.new("RemoteFunction")
getPlayerDataFunction.Name = "GetPlayerDataFunction"
getPlayerDataFunction.Parent = RemoteFunctions


-- Seed Configuration
GameConfig.Seeds = {
	basic_seed = {
		name = "Magic Wheat",
		cost = 10,
		growTime = 30, -- seconds
		coinReward = 15,
		expReward = 5,
		unlockLevel = 1,
		tier = "basic"
	},
	stellar_seed = {
		name = "Stellar Corn",
		cost = 50,
		growTime = 120,
		coinReward = 80,
		expReward = 15,
		unlockLevel = 5,
		tier = "stellar"
	},
	cosmic_seed = {
		name = "Cosmic Berries",
		cost = 200,
		growTime = 300,
		coinReward = 350,
		expReward = 35,
		unlockLevel = 15,
		tier = "cosmic"
	},
	divine_seed = {
		name = "Divine Crystals",
		cost = 1000,
		growTime = 600,
		coinReward = 1800,
		expReward = 100,
		unlockLevel = 30,
		tier = "divine"
	}
}

print("Game Config initialized successfully!")
return GameConfig
