--[[
    Shared Module - ForeverBuild2
    
    This is the main entry point for all shared modules.
    When requiring this module, you'll get access to all sub-modules.
    
    FIXED VERSION: Uses deferred loading to prevent stack overflow
]]

local SharedModule = {}

-- Only load Constants immediately since it has no dependencies
SharedModule.Constants = require(script.core.Constants)

-- Create module loaders for other modules to avoid circular dependencies
local moduleCache = {}
local function getModule(name, path)
    if moduleCache[name] then
        return moduleCache[name]
    end
    
    local success, result = pcall(function()
        return require(path)
    end)
    
    if success then
        moduleCache[name] = result
        return result
    else
        warn("Failed to load module: " .. name .. " - " .. tostring(result))
        return {}
    end
end

-- Use metatables for lazy loading
SharedModule = setmetatable(SharedModule, {
    __index = function(self, key)
        if key == "GameManager" then
            return getModule("GameManager", script.core.GameManager)
        elseif key == "UI" then
            return getModule("UI", script.core.ui)
        elseif key == "Interaction" then
            return getModule("Interaction", script.core.interaction)
        elseif key == "Placement" then
            return getModule("Placement", script.core.placement)
        elseif key == "Inventory" then
            return getModule("Inventory", script.core.inventory)
        elseif key == "Economy" then
            return getModule("Economy", script.core.economy)
        end
        return nil
    end
})

function SharedModule.Init()
    print("Initializing SharedModule with deferred loading...")
    
    -- Initialize Constants immediately since it's directly loaded
    if SharedModule.Constants.Initialize then 
        SharedModule.Constants.Initialize()
    end
    
    -- Other modules will be initialized only when they're accessed
    print("SharedModule initialized - other modules will load on demand")
    
    return true
end

return SharedModule
