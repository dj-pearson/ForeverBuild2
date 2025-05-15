local PlacementManager = {}
PlacementManager.__index = PlacementManager

function PlacementManager.new()
    local self = setmetatable({}, PlacementManager)
    return self
end

function PlacementManager:Initialize()
    return true
end

function PlacementManager:Update()
end

return PlacementManager 