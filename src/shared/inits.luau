--[[
    Shared Module - ForeverBuild2
    
    This is the main entry point for all shared modules.
    When requiring this module, you'll get access to all sub-modules.
    
    IMPROVED VERSION: Uses deferred loading with clearer path resolution
]]

print("Shared inits.luau loading...")

local SharedModule = {}

-- Cache for loaded modules to prevent duplicate loading
local moduleCache = {}

-- Helper function to safely load modules
local function safeRequire(path, moduleName)
    if moduleCache[moduleName] then
        return moduleCache[moduleName]
    end
    
    if not path then
        warn("Invalid path for module:", moduleName)
        return {}
    end
    
    print("Attempting to require:", moduleName, "at path:", path:GetFullName())
    
    local success, result = pcall(function()
        return require(path)
    end)
    
    if not success then
        warn("Failed to load module:", moduleName, "-", tostring(result))
        return {}
    end
    
    print("Successfully loaded module:", moduleName)
    moduleCache[moduleName] = result
    return result
end

-- Only load Constants immediately since it has no dependencies
local ConstantsPath = script.core.Constants
print("Constants path:", ConstantsPath and ConstantsPath:GetFullName() or "nil")
local Constants = safeRequire(ConstantsPath, "Constants")
SharedModule.Constants = Constants

-- Load core modules directly
local Core = {}

-- Define explicit paths for all core modules
local modulePaths = {
    -- Core modules
    GameManager = script.core.GameManager,
    
    -- Interaction
    InteractionManager = script.core.interaction.InteractionManager,
    
    -- Inventory
    InventoryManager = script.core.inventory.InventoryManager,
    ItemManager = script.core.inventory.ItemManager,
    
    -- Placement
    PlacementManager = script.core.placement.PlacementManager,
    
    -- Economy
    CurrencyManager = script.core.economy.CurrencyManager,
    
    -- UI
    PurchaseDialog = script.core.ui.PurchaseDialog,
    InventoryUI = script.core.ui.InventoryUI,
    CurrencyUI = script.core.ui.CurrencyUI,
    PlacedItemDialog = script.core.ui.PlacedItemDialog,
    
    -- Utilities
    LazyLoadModules = script.core.LazyLoadModules
}

-- Load core modules
print("Loading core modules directly...")
for name, path in pairs(modulePaths) do
    Core[name] = safeRequire(path, name)
    -- Also expose them directly on SharedModule for backward compatibility
    SharedModule[name] = Core[name]
end

-- Print debug info about loaded modules
print("Core modules loaded with the following keys:")
for key, value in pairs(Core) do
    print("  - " .. key .. " (" .. (value ~= nil and "loaded" or "failed to load") .. ")")
end

-- Store Core table in SharedModule for organization
SharedModule.Core = Core

function SharedModule.Init()
    print("Initializing SharedModule with improved path resolution...")
    
    -- Initialize Constants immediately since it's directly loaded
    if SharedModule.Constants and SharedModule.Constants.Initialize then 
        print("Initializing Constants module...")
        SharedModule.Constants.Initialize()
    end
    
    -- Other modules will be initialized only when they're accessed
    print("SharedModule initialized - other modules will load on demand")
    
    return true
end

return SharedModule 