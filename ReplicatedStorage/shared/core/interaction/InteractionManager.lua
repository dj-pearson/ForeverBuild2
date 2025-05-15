local InteractionManager = {}
InteractionManager.__index = InteractionManager

function InteractionManager.new()
    local self = setmetatable({}, InteractionManager)
    return self
end

function InteractionManager:Initialize()
    return true
end

function InteractionManager:Update()
end

return InteractionManager 