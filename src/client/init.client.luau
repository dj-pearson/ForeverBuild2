local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Add debug print to confirm script is running
print("Client script starting...")

-- Wait for remotes to exist before initializing shared module
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    warn("Failed to find Remotes folder in ReplicatedStorage. Server may not be initialized yet.")
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

-- Safely require the LazyLoadModules helper first
local success, LazyLoadModules = pcall(function()
    return require(ReplicatedStorage.shared.core.LazyLoadModules)
end)

if not success then
    warn("Failed to require LazyLoadModules: ", LazyLoadModules)
    LazyLoadModules = {
        register = function() end,
        require = function() return {} end
    }
end

-- Register modules that might cause circular dependencies
LazyLoadModules.register("SharedModule", ReplicatedStorage.shared)
LazyLoadModules.register("UI", ReplicatedStorage.shared.core.ui)
LazyLoadModules.register("GameManager", ReplicatedStorage.shared.core.GameManager)
LazyLoadModules.register("Constants", ReplicatedStorage.shared.core.Constants)

-- Initialize all shared modules with consistent error handling
local function safeRequire(path)
    local success, result = pcall(function()
        return require(path)
    end)
    
    if not success then
        warn("Failed to require module at path: ", path)
        warn("Error: ", result)
        return {}
    end
    
    return result
end

-- Safely initialize SharedModule
local SharedModule = require(ReplicatedStorage.shared)
if SharedModule.Init then
    local success, errorMsg = pcall(function()
        SharedModule.Init() -- Ensure all shared systems are initialized
    end)

    if not success then
        warn("Failed to initialize SharedModule: ", errorMsg)
    end
end

-- Set up proper OOP initialization for UI components with safe require
-- Get UI modules directly from SharedModule since we've initialized it
local UI = {
    PurchaseDialog = SharedModule.PurchaseDialog,
    InventoryUI = SharedModule.InventoryUI,
    CurrencyUI = SharedModule.CurrencyUI,
    PlacedItemDialog = SharedModule.PlacedItemDialog
}

-- Create UI instances with proper error handling
local function safeInitialize(module, name)
    if not module then
        warn("Module " .. name .. " is nil")
        return nil
    end
    
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
local inventoryUI = safeInitialize(SharedModule.InventoryUI, "InventoryUI")
local purchaseDialog = safeInitialize(SharedModule.PurchaseDialog, "PurchaseDialog")
local currencyUI = safeInitialize(SharedModule.CurrencyUI, "CurrencyUI")
local placedItemDialog = safeInitialize(SharedModule.PlacedItemDialog, "PlacedItemDialog")

-- Load client-specific InteractionSystem
local InteractionSystem = safeRequire(script.Parent.interaction.InteractionSystem)

-- Initialize interaction system with OOP approach and error handling
if InteractionSystem and InteractionSystem.new then
    local interactionSystem = InteractionSystem.new()
    local success, errorMsg = pcall(function()
        interactionSystem:Initialize()
    end)
    
    if not success then
        warn("Failed to initialize InteractionSystem: ", errorMsg)
    end
else
    warn("InteractionSystem module is missing or invalid")
end

print("Client initialized successfully")
