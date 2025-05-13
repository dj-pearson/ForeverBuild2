--[[
    Shared Module - ForeverBuild2
    
    This is the main entry point for all shared modules.
    When requiring this module, you'll get access to all sub-modules.
    
    FIXED VERSION: Uses deferred loading to prevent stack overflow
]]

local SharedModule = {}

-- Only load Constants immediately since it has no dependencies
local ConstantsModulePath = script.core.Constants
local constSuccess, Constants = pcall(function()
	return require(ConstantsModulePath)
end)

if not constSuccess or Constants == nil then
	warn("CRITICAL: Failed to load Constants module from path: ", tostring(ConstantsModulePath), ". Error: ", constSuccess and "Constants module returned nil" or tostring(Constants))
	Constants = {} -- Fallback to prevent further errors
end
SharedModule.Constants = Constants

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

local CoreModulePath = script.core
local coreLoadSuccess, Core = pcall(function()
	return require(CoreModulePath)
end)

if not coreLoadSuccess or Core == nil then
	warn("CRITICAL: Failed to load Core module from path: ", tostring(CoreModulePath), ". Error: ", coreLoadSuccess and "Core module returned nil" or tostring(Core))
	Core = {} -- Fallback to prevent further errors
else
	print("Core module loaded successfully. Contents:", Core)
end

-- Expose Core directly
SharedModule.Core = Core

-- Use metatables for lazy loading
SharedModule = setmetatable(SharedModule, {
	__index = function(self, key)
		local coreModule = Core[key]
		if coreModule ~= nil then
			return coreModule
		else
			-- Only warn if the key is one of the expected module names to avoid noise
			local expectedModules = {"GameManager", "CurrencyManager", "InteractionManager", "InventoryManager", "ItemManager", "PlacementManager", "PurchaseDialog", "InventoryUI", "CurrencyUI", "PlacedItemDialog", "LazyLoadModules", "InteractionSystem"}
			local isExpected = false
			for _, modName in ipairs(expectedModules) do
				if key == modName then
					isExpected = true
					break
				end
			end
			if isExpected then
				warn("SharedModule: Module '", key, "' not found or is nil in Core. Check if '", key, "' is correctly defined and returned in shared/core/init.luau and that the module file itself loads without errors.")
				-- You can print the Core table here for more detailed debugging if needed:
				-- print("Current Core table:", Core)
			end
			return nil
		end
	end
})

function SharedModule.Init()
	print("Initializing SharedModule with deferred loading...")
	
	-- Initialize Constants immediately since it's directly loaded
	if SharedModule.Constants and SharedModule.Constants.Initialize then 
		SharedModule.Constants.Initialize()
	end
	
	-- Other modules will be initialized only when they're accessed
	print("SharedModule initialized - other modules will load on demand")
	
	return true
end

return SharedModule
