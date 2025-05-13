--[[
    Shared Module - ForeverBuild2
    
    This is the main entry point for all shared modules.
    When requiring this module, you'll get access to all sub-modules.
    
    This version uses LazyLoadModules to prevent circular dependencies.
]]

local SharedModule = {}

-- First load the LazyLoadModules helper
local LazyLoadModules = require(script.core.LazyLoadModules)

-- Load essential modules first
SharedModule.Constants = require(script.core.Constants)

-- Use lazy loading for potentially circular modules
LazyLoadModules.register("GameManager", script.core.GameManager)
LazyLoadModules.register("UI", script.core.ui)
LazyLoadModules.register("Interaction", script.core.interaction)
LazyLoadModules.register("Placement", script.core.placement)
LazyLoadModules.register("Inventory", script.core.inventory)
LazyLoadModules.register("Economy", script.core.economy)

-- Create properties that will trigger lazy loading when accessed
SharedModule.GameManager = LazyLoadModules.GameManager
SharedModule.UI = LazyLoadModules.UI
SharedModule.Interaction = LazyLoadModules.Interaction
SharedModule.Placement = LazyLoadModules.Placement
SharedModule.Inventory = LazyLoadModules.Inventory
SharedModule.Economy = LazyLoadModules.Economy

function SharedModule.Init()
    print("Initializing SharedModule...")

    -- Initialize Constants module since it's directly required
    if SharedModule.Constants.Init then 
        SharedModule.Constants.Init() 
    end
    
    -- Other modules will be initialized only when needed
    -- This prevents circular dependency issues
    print("SharedModule initialized successfully!")
end

return SharedModule
