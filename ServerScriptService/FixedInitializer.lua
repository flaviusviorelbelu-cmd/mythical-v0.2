-- FixedInitializer.lua - Comprehensive Game Startup Handler
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Initializer] Starting enhanced game initialization...")

-- System initialization flags
local systemsReady = {
	dataManager = false,
	gameManager = false,
	gardenSystem = false,
	shopManager = false,
	remoteEvents = false,
	magicalRealm = false
}

-- Enhanced module loading with error handling
local modules = {}

local function safeRequire(modulePath, moduleName)
	local success, result = pcall(function()
		return require(modulePath)
	end)
	
	if success then
		modules[moduleName] = result
		systemsReady[moduleName] = true
		print("[Initializer] ✅ Successfully loaded:", moduleName)
		return result
	else
		warn("[Initializer] ❌ Failed to load", moduleName, ":", result)
		systemsReady[moduleName] = false
		return nil
	end
end

-- Load all core modules
local function loadCoreModules()
	print("[Initializer] Loading core modules...")
	
	-- Load modules in dependency order
	safeRequire(ServerScriptService.DataManager, "dataManager")
	safeRequire(ServerScriptService.GameManager, "gameManager")  
	safeRequire(ServerScriptService.GardenSystem, "gardenSystem")
	safeRequire(ServerScriptService.ShopManager, "shopManager")
	safeRequire(ServerScriptService.PlayerGardenManager, "playerGardenManager")
	safeRequire(ServerScriptService.MagicalRealm, "magicalRealm")
	
	-- Wait for Scripts to initialize (they can't be required)
	wait(2)
	systemsReady.remoteEvents = true -- RemoteEventHandler is a Script
	
	return true
end

-- Create the magical world
local function initializeMagicalRealm()
	if modules.magicalRealm then
		local success, result = pcall(function()
			modules.magicalRealm.CreateWorld()
		end)
		
		if success then
			print("[Initializer] ✅ Magical realm created successfully")
			return true
		else
			warn("[Initializer] ❌ Failed to create magical realm:", result)
			return false
		end
	end
	return false
end

-- Setup player event handlers
local function setupPlayerEvents()
	local function onPlayerAdded(player)
		print("[Initializer] 🎮 Player joined:", player.Name)
		
		-- Wait for systems to be ready
		local attempts = 0
		while (not systemsReady.dataManager or not systemsReady.gardenSystem) and attempts < 50 do
			wait(0.1)
			attempts = attempts + 1
		end
		
		if systemsReady.dataManager and modules.gameManager then
			spawn(function()
				modules.gameManager.OnPlayerAdded(player)
			end)
		end
		
		if systemsReady.gardenSystem and modules.gardenSystem then
			spawn(function()
				wait(1) -- Give character time to load
				modules.gardenSystem.InitializePlayerGarden(player)
			end)
		end
	end

	local function onPlayerRemoving(player)
		print("[Initializer] 👋 Player leaving:", player.Name)
		
		if systemsReady.dataManager and modules.gameManager then
			modules.gameManager.OnPlayerRemoving(player)
		end
	end

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
	print("[Initializer] 🚀 Starting main initialization sequence...")
	
	-- Step 1: Load all modules
	local modulesLoaded = loadCoreModules()
	if not modulesLoaded then
		warn("[Initializer] ❌ Critical: Core modules failed to load")
		return false
	end
	
	-- Step 2: Create magical realm
	spawn(function()
		wait(1) -- Give a moment for everything to settle
		initializeMagicalRealm()
	end)
	
	-- Step 3: Setup player events
	setupPlayerEvents()
	
	-- Step 4: System health check
	spawn(function()
		wait(5) -- Give systems time to fully initialize
		
		local allSystemsReady = true
		for systemName, ready in pairs(systemsReady) do
			if not ready then
				warn("[Initializer] ⚠️  System not ready:", systemName)
				allSystemsReady = false
			end
		end
		
		if allSystemsReady then
			print("[Initializer] 🎉 All systems initialized successfully!")
		else
			warn("[Initializer] ⚠️  Some systems failed to initialize")
		end
		
		-- Print system status
		print("[Initializer] 📊 System Status:")
		for systemName, ready in pairs(systemsReady) do
			print("  ", systemName, ":", ready and "✅" or "❌")
		end
	end)
	
	return true
end

-- Graceful shutdown handler
game:BindToClose(function()
	print("[Initializer] 🛑 Server shutting down...")
	
	-- Save all player data
	if systemsReady.dataManager and modules.gameManager then
		for _, player in pairs(Players:GetPlayers()) do
			spawn(function()
				modules.gameManager.OnPlayerRemoving(player)
			end)
		end
	end
	
	-- Give time for saves to complete
	wait(2)
	print("[Initializer] 💾 Shutdown save complete")
end)

-- Start initialization
spawn(function()
	local success = initialize()
	if success then
		print("[Initializer] 🚀 Game initialization completed successfully!")
	else
		warn("[Initializer] 💥 Game initialization failed!")
	end
end)

-- Expose global status checker
_G.SystemStatus = {
	GetStatus = function()
		return systemsReady
	end,
	GetModules = function()
		return modules
	end,
	IsReady = function()
		for _, ready in pairs(systemsReady) do
			if not ready then return false end
		end
		return true
	end
}

print("[Initializer] 📋 Enhanced initializer loaded and starting...")