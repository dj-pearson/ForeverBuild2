local ItemManager = {}
ItemManager.__index = ItemManager

function ItemManager.new()
    local self = setmetatable({}, ItemManager)
    return self
end

function ItemManager:Initialize()
    return true
end

function ItemManager:Update()
end

return ItemManager 