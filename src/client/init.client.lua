local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Add debug print to confirm script is running
print("Client script starting...")

-- Load core modules
local SharedModule = require(ReplicatedStorage.shared)

-- Initialize all shared modules with consistent error handling
local success, errorMsg = pcall(function()
	SharedModule.Init() -- Ensure all shared systems are initialized
end)

if not success then
	warn("Failed to initialize SharedModule: ", errorMsg)
end

-- Set up proper OOP initialization for UI components
local UI = require(ReplicatedStorage.shared.core.ui)

-- Create UI instances with proper error handling
local function safeInitialize(module, name)
	local success, result = pcall(function()
		if typeof(module) == "table" and module.new then
			-- OOP style initialization
			local instance = module.new()
			instance:Initialize()
			return instance
		elseif typeof(module) == "table" and module.Initialize then
			-- Functional style initialization
			module.Initialize(Players.LocalPlayer.PlayerGui)
			return module
		else
			warn("Module " .. name .. " doesn't have proper initialization method")
			return nil
		end
	end)

	if not success then
		warn("Failed to initialize " .. name .. ": ", result)
		return nil
	end

	return result
end

-- Initialize UI components with error handling
local inventoryUI = safeInitialize(UI.InventoryUI, "InventoryUI")
local purchaseDialog = safeInitialize(UI.PurchaseDialog, "PurchaseDialog")
local currencyUI = safeInitialize(UI.CurrencyUI, "CurrencyUI")
local placedItemDialog = safeInitialize(UI.PlacedItemDialog, "PlacedItemDialog")

-- The interaction module is a child of this script
local InteractionSystem = require(script.interaction.InteractionSystem)

-- Initialize interaction system with OOP approach
local interactionSystem = InteractionSystem.new()
interactionSystem:Initialize()

print("Client initialized successfully")