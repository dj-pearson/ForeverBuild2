-- LazyLoadModules.lua
-- This module provides a simple way to lazy-load modules to avoid circular dependencies

local LazyLoadModules = {}
local loadedModules = {}

-- Helper to safely require a module only when needed
function LazyLoadModules.require(path)
    -- Check if we already loaded this module
    if loadedModules[path] then
        return loadedModules[path]
    end
    
    -- Try to load the module
    local success, result = pcall(function()
        return require(path)
    end)
    
    if success then
        -- Cache the result for future calls
        loadedModules[path] = result
        return result
    else
        warn("Failed to require module at path: ", path)
        warn("Error: ", result)
        return {}
    end
end

-- Register modules that might have circular dependencies for later loading
function LazyLoadModules.register(moduleName, path)
    -- Create a proxy for lazy loading
    LazyLoadModules[moduleName] = setmetatable({}, {
        __index = function(_, key)
            local module = LazyLoadModules.require(path)
            return module[key]
        end,
        
        __call = function(_, ...)
            local module = LazyLoadModules.require(path)
            return module(...)
        end
    })
end

return LazyLoadModules
