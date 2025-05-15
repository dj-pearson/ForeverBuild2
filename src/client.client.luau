-- filepath: c:\Users\dpearson\OneDrive\Documents\ForeverBuild\ForeverBuild\ForeverBuild2\src\client\inits.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Add debug print to confirm script is running
print("Client initialization script starting...")

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
else
    -- Register modules that might cause circular dependencies
    LazyLoadModules.register("SharedModule", ReplicatedStorage.shared)
    LazyLoadModules.register("UI", ReplicatedStorage.shared.core.ui)
    LazyLoadModules.register("GameManager", ReplicatedStorage.shared.core.GameManager)
    LazyLoadModules.register("Constants", ReplicatedStorage.shared.core.Constants)
    LazyLoadModules.register("PurchaseDialog", ReplicatedStorage.shared.core.ui.PurchaseDialog)
    LazyLoadModules.register("InventoryUI", ReplicatedStorage.shared.core.ui.InventoryUI)
    LazyLoadModules.register("PlacedItemDialog", ReplicatedStorage.shared.core.ui.PlacedItemDialog)
end

-- Initialize shared module with error handling
local SharedModule
local success, errorMessage = pcall(function()
    local shared = ReplicatedStorage:WaitForChild("shared", 10)
    print("Found shared module at " .. shared:GetFullName())
    SharedModule = require(shared)
    return true
end)

if not success then
    warn("Failed to require SharedModule: ", errorMessage)
    SharedModule = {}
else
    print("Successfully required SharedModule")
    
    if SharedModule.Init then
        local initSuccess, errorMsg = pcall(function()
            SharedModule.Init() -- Ensure all shared systems are initialized
        end)
    
        if not initSuccess then
            warn("Failed to initialize SharedModule: ", errorMsg)
        else
            print("SharedModule initialized successfully")
        end
    end
end

-- Load client_core module which contains the main client logic
local clientCoreModuleScript = script.Parent:WaitForChild("client_core", 10)
if not clientCoreModuleScript then
    warn("Could not find the 'client_core' ModuleScript after 10 seconds.")
    return
end

print("Found client_core ModuleScript: " .. clientCoreModuleScript:GetFullName())

-- Require the ModuleScript
local success, clientCoreAPI = pcall(require, clientCoreModuleScript)
if not success then
    warn("Failed to load client_core ModuleScript. Error: ", tostring(clientCoreAPI))
    return
end

print("client_core ModuleScript loaded successfully")

-- Initialize UI components with error handling
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

-- Initialize CurrencyUI only (other UIs are handled by client_core)
local currencyUI = safeInitialize(SharedModule.CurrencyUI, "CurrencyUI")

print("Client initialization completed successfully")
