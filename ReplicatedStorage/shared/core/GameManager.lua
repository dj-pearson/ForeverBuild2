local GameManager = {}
GameManager.__index = GameManager

function GameManager.new()
    local self = setmetatable({}, GameManager)
    return self
end

function GameManager:Initialize()
    return true
end

function GameManager:Update()
end

return GameManager 