-- PetClient.lua (StarterPlayerScripts)  
_G.PetClient = {
	TogglePetMenu = function()
		print("[PetClient] Pet system coming soon!")
		if _G.MainClient then
			_G.MainClient.ShowFeedback("Pet system coming soon!", "info")
		end
	end
}
