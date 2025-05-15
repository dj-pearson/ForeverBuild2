local InventoryManager = {}
InventoryManager.__index = InventoryManager

function InventoryManager.new()
    local self = setmetatable({}, InventoryManager)
    return self
end

function InventoryManager:Initialize()
    return true
end

function InventoryManager:Update()
end

return InventoryManager 