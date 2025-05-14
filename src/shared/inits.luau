--[[
    Shared Module - ForeverBuild2
    
    This is the main entry point for all shared modules.
    When requiring this module, you'll get access to all sub-modules.
    
    FIXED VERSION: Ensures module loading works correctly and provides fallbacks
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
        return nil  -- Return nil instead of empty table to be more explicit about failure
    end
    
    print("Attempting to require:", moduleName, "at path:", path:GetFullName())
    
    local success, result = pcall(function()
        return require(path)
    end)
    
    if not success then
        warn("Failed to load module:", moduleName, "-", tostring(result))
        return nil  -- Return nil instead of empty table to be more explicit about failure
    end
    
    print("Successfully loaded module:", moduleName)
    moduleCache[moduleName] = result
    return result
end

-- References to all core modules
SharedModule.Constants = nil
SharedModule.GameManager = nil
SharedModule.LazyLoadModules = nil
SharedModule.PurchaseDialog = nil
SharedModule.InventoryUI = nil
SharedModule.PlacedItemDialog = nil
SharedModule.CurrencyUI = nil
SharedModule.InteractionManager = nil

-- Only load Constants immediately since it has no dependencies
local ConstantsPath = script.Parent.core and script.Parent.core:FindFirstChild("Constants")
if ConstantsPath then
    print("Constants path:", ConstantsPath:GetFullName())
    SharedModule.Constants = safeRequire(ConstantsPath, "Constants")
else
    warn("Constants module not found at expected path")
    -- Create a minimal Constants fallback
    SharedModule.Constants = {
        CURRENCY_TYPES = {"Coins", "Gems"},
        DEFAULT_CURRENCY = "Coins",
        INTERACTION_DISTANCE = 10,
        PLACEMENT_GRID_SIZE = 1,
        -- Add other constants as needed
    }
    print("Created Constants fallback")
end

-- Load core modules directly
local Core = {}

-- Define explicit paths for all core modules
local modulePaths = {
    -- Core modules
    GameManager = script.Parent.core and script.Parent.core:FindFirstChild("GameManager"),
    
    -- Interaction
    InteractionManager = script.Parent.core and script.Parent.core:FindFirstChild("interaction") and 
                         script.Parent.core.interaction:FindFirstChild("InteractionManager"),
    
    -- Inventory
    InventoryManager = script.Parent.core and script.Parent.core:FindFirstChild("inventory") and 
                       script.Parent.core.inventory:FindFirstChild("InventoryManager"),
    ItemManager = script.Parent.core and script.Parent.core:FindFirstChild("inventory") and 
                  script.Parent.core.inventory:FindFirstChild("ItemManager"),
    
    -- Placement
    PlacementManager = script.Parent.core and script.Parent.core:FindFirstChild("placement") and 
                       script.Parent.core.placement:FindFirstChild("PlacementManager"),
    
    -- Economy
    CurrencyManager = script.Parent.core and script.Parent.core:FindFirstChild("economy") and 
                      script.Parent.core.economy:FindFirstChild("CurrencyManager"),
    
    -- UI
    PurchaseDialog = script.Parent.core and script.Parent.core:FindFirstChild("ui") and 
                     script.Parent.core.ui:FindFirstChild("PurchaseDialog"),
    InventoryUI = script.Parent.core and script.Parent.core:FindFirstChild("ui") and 
                  script.Parent.core.ui:FindFirstChild("InventoryUI"),
    CurrencyUI = script.Parent.core and script.Parent.core:FindFirstChild("ui") and 
                 script.Parent.core.ui:FindFirstChild("CurrencyUI"),
    PlacedItemDialog = script.Parent.core and script.Parent.core:FindFirstChild("ui") and 
                       script.Parent.core.ui:FindFirstChild("PlacedItemDialog"),
    
    -- Utilities
    LazyLoadModules = script.Parent.core and script.Parent.core:FindFirstChild("LazyLoadModules")
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
    
    -- Initialize LazyLoadModules if available
    if not SharedModule.LazyLoadModules then
        print("Creating LazyLoadModules fallback since it failed to load")
        -- Create fallback implementation
        SharedModule.LazyLoadModules = {
            _registry = {},
            register = function(name, moduleScript)
                if not name or not moduleScript then
                    warn("LazyLoadModules.register: Invalid arguments")
                    return false
                end
                
                SharedModule.LazyLoadModules._registry[name] = moduleScript
                return true
            end,
            require = function(name)
                if not name then
                    warn("LazyLoadModules.require: Name is required")
                    return nil
                end
                
                local moduleScript = SharedModule.LazyLoadModules._registry[name]
                if not moduleScript then
                    warn("LazyLoadModules.require: Module not registered: " .. name)
                    return nil
                end
                
                local success, result = pcall(function()
                    return require(moduleScript)
                end)
                
                if success then
                    return result
                else
                    warn("LazyLoadModules.require: Failed to require module " .. name .. ": " .. tostring(result))
                    return nil
                end
            end
        }
    end
    
    -- Register all modules in LazyLoadModules for on-demand loading
    print("Registering modules with LazyLoadModules...")
    for name, path in pairs(modulePaths) do
        if path then
            local success = SharedModule.LazyLoadModules.register(name, path)
            if success then
                print("  - Registered " .. name .. " for lazy loading")
            end
        end
    end
    
    -- Other modules will be initialized only when they're accessed
    print("SharedModule initialized - other modules will load on demand")
    
    return true
end

return SharedModule