-- CleanInitializer.lua - Simple and Error-Free Game Initialization
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Initializer] 🚀 Starting Clean Game Initialization...")

-- System status tracking
local systemStatus = {
	dataManager = false,
	gardenSystem = false,
	remoteEventHandler = false,
	magicalRealm = false
}

-- Loaded modules storage
local loadedModules = {}

-- Safe module loading function
local function safeLoadModule(moduleName, displayName)
	local success, result = pcall(function()
		return require(ServerScriptService:WaitForChild(moduleName, 10))
	end)
	
	if success then
		loadedModules[displayName] = result
		systemStatus[displayName] = true
		print("[Initializer] ✅ Successfully loaded:", displayName)
		return result
	else
		warn("[Initializer] ❌ Failed to load", displayName, ":", result)
		systemStatus[displayName] = false
		return nil
	end
end

-- Load core modules
local function loadCoreModules()
	print("[Initializer] Loading core modules...")
	
	-- Load clean modules
	safeLoadModule("CleanDataManager", "dataManager")
	safeLoadModule("CleanGardenSystem", "gardenSystem")
	
	-- Load other existing modules if they exist
	local optionalModules = {
		{"GameManager", "gameManager"},
		{"MagicalRealm", "magicalRealm"},
		{"ShopManager", "shopManager"}
	}
	
	for _, moduleInfo in ipairs(optionalModules) do
		local moduleName, displayName = moduleInfo[1], moduleInfo[2]
		local moduleObject = ServerScriptService:FindFirstChild(moduleName)
		if moduleObject then
			safeLoadModule(moduleName, displayName)
		else
			print("[Initializer] ⚠️  Optional module not found:", moduleName)
		end
	end
	
	-- Note: CleanRemoteEventHandler is a Script, not a ModuleScript
	local remoteHandler = ServerScriptService:FindFirstChild("CleanRemoteEventHandler")
	if remoteHandler then
		systemStatus.remoteEventHandler = true
		print("[Initializer] ✅ CleanRemoteEventHandler script found")
	else
		warn("[Initializer] ❌ CleanRemoteEventHandler script not found")
	end
end

-- Initialize the magical world if available
local function initializeMagicalRealm()
	if loadedModules.magicalRealm and loadedModules.magicalRealm.CreateWorld then
		print("[Initializer] 🌍 Creating magical realm...")
		spawn(function()
			local success, error = pcall(function()
				loadedModules.magicalRealm.CreateWorld()
			end)
			
			if success then
				print("[Initializer] ✅ Magical realm created successfully")
			else
				warn("[Initializer] ❌ Failed to create magical realm:", error)
			end
		end)
		wait(2) -- Give world creation time
	else
		print("[Initializer] ⚠️  MagicalRealm not available, skipping world creation")
	end
end

-- Handle player connections
local function setupPlayerEvents()
	local function onPlayerAdded(player)
		print("[Initializer] 🎮 Player joined:", player.Name)
		
		-- Initialize player data
		if loadedModules.dataManager then
			spawn(function()
				loadedModules.dataManager.LoadPlayerData(player)
			end)
		end
		
		-- Initialize player garden
		if loadedModules.gardenSystem then
			spawn(function()
				wait(3) -- Give character time to load
				loadedModules.gardenSystem.InitializePlayerGarden(player)
			end)
		end
		
		-- Call GameManager if available
		if loadedModules.gameManager and loadedModules.gameManager.OnPlayerAdded then
			spawn(function()
				loadedModules.gameManager.OnPlayerAdded(player)
			end)
		end
	end

	local function onPlayerRemoving(player)
		print("[Initializer] 👋 Player leaving:", player.Name)
		
		-- Save player data
		if loadedModules.dataManager then
			local playerData = loadedModules.dataManager.GetPlayerData(player)
			if playerData then
				loadedModules.dataManager.SavePlayerData(player, playerData)
			end
		end
		
		-- Call GameManager if available
		if loadedModules.gameManager and loadedModules.gameManager.OnPlayerRemoving then
			loadedModules.gameManager.OnPlayerRemoving(player)
		end
	end

	-- Connect events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle existing players
	for _, player in pairs(Players:GetPlayers()) do
		spawn(function()
			onPlayerAdded(player)
		end)
	end
	
	print("[Initializer] ✅ Player event handlers setup complete")
end

-- Main initialization sequence
local function initialize()
	print("[Initializer] Starting main initialization sequence...")
	
	-- Step 1: Load all modules
	loadCoreModules()
	
	-- Step 2: Wait for critical modules
	local attempts = 0
	local maxAttempts = 30 -- 30 seconds max wait
	
	while attempts < maxAttempts do
		if systemStatus.dataManager and systemStatus.gardenSystem then
			print("[Initializer] ✅ Critical modules loaded successfully")
			break
		else
			attempts = attempts + 1
			if attempts % 10 == 0 then -- Log every 10 seconds
				print("[Initializer] ⏳ Waiting for critical modules... (" .. attempts .. "/" .. maxAttempts .. ")")
			end
			wait(1)
		end
	end
	
	if not (systemStatus.dataManager and systemStatus.gardenSystem) then
		error("[Initializer] ❌ Critical modules failed to load - cannot continue")
	end
	
	-- Step 3: Initialize world
	initializeMagicalRealm()
	
	-- Step 4: Setup player events
	setupPlayerEvents()
	
	-- Step 5: Final status check
	spawn(function()
		wait(5) -- Give everything time to settle
		
		print("[Initializer] 📊 Final System Status Report:")
		local allSystemsGood = true
		
		for systemName, status in pairs(systemStatus) do
			local statusIcon = status and "✅" or "❌"
			print("  ", statusIcon, systemName, ":", status and "Ready" or "Failed")
			
			if systemName == "dataManager" or systemName == "gardenSystem" then
				if not status then
					allSystemsGood = false
				end
			end
		end
		
		if allSystemsGood then
			print("[Initializer] 🎉 Game initialization completed successfully!")
		else
			warn("[Initializer] ⚠️  Some critical systems failed - game may not function properly")
		end
		
		print("[Initializer] Game is ready for players!")
	end)
	
	return true
end

-- Graceful shutdown handling
game:BindToClose(function()
	print("[Initializer] 🛑 Server shutting down...")
	
	-- Save all player data
	if loadedModules.dataManager then
		for _, player in pairs(Players:GetPlayers()) do
			spawn(function()
				local playerData = loadedModules.dataManager.GetPlayerData(player)
				if playerData then
					loadedModules.dataManager.SavePlayerData(player, playerData)
				end
			end)
		end
	end
	
	-- Give time for saves to complete
	wait(3)
	print("[Initializer] 💾 Shutdown procedures complete")
end)

-- Start the initialization process
spawn(function()
	local success, error = pcall(initialize)
	
	if success then
		print("[Initializer] ✅ Clean initialization completed successfully!")
	else
		error("[Initializer] ❌ Initialization failed: " .. tostring(error))
	end
end)

-- Global status interface for debugging
_G.CleanGameStatus = {
	GetSystemStatus = function()
		return systemStatus
	end,
	GetLoadedModules = function()
		return loadedModules
	end,
	IsGameReady = function()
		return systemStatus.dataManager and systemStatus.gardenSystem
	end,
	PrintStatus = function()
		print("[CleanGameStatus] Current System Status:")
		for name, status in pairs(systemStatus) do
			print("  ", name, ":", status and "✅ Ready" or "❌ Failed")
		end
	end
}

print("[Initializer] 📋 Clean Initializer loaded and starting...")