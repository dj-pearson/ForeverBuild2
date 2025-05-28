-- PlacementManager.luau
-- Main module that delegates to the appropriate placement implementation
-- Routes to either the monolithic Core or the new modular system

local RunService = game:GetService("RunService")

-- Configuration: Set to true to use the new modular system, false for legacy monolithic
local USE_MODULAR_SYSTEM = false

local PlacementManager

if USE_MODULAR_SYSTEM then
    -- Use the new modular PlacementCore system
    local success, result = pcall(function()
        return require(game.ReplicatedStorage.shared.core.placement.PlacementCore)
    end)
    
    if success then
        PlacementManager = result
        print("PlacementManager: Using modular PlacementCore system")
    else
        warn("PlacementManager: Failed to load modular system, falling back to Core:", result)
        PlacementManager = require(game.ReplicatedStorage.shared.core.placement.PlacementManager_Core)
    end
else
    -- Use the legacy monolithic system
    local success, result = pcall(function()
        return require(game.ReplicatedStorage.shared.core.placement.PlacementManager_Core)
    end)
    
    if success then
        PlacementManager = result
        print("PlacementManager: Using legacy PlacementManager_Core system")
    else
        error("PlacementManager: Failed to load any placement system: " .. tostring(result))
    end
end

return PlacementManager
