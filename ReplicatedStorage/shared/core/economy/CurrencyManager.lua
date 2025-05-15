local CurrencyManager = {}
CurrencyManager.__index = CurrencyManager

function CurrencyManager.new()
    local self = setmetatable({}, CurrencyManager)
    return self
end

function CurrencyManager:Initialize()
    return true
end

function CurrencyManager:Update()
end

return CurrencyManager 