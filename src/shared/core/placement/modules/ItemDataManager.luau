-- ItemDataManager.luau
-- Handles world data save/load operations for placed items

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ItemDataManager = {}
ItemDataManager.__index = ItemDataManager

function ItemDataManager.new(sharedModule)
    local self = setmetatable({}, ItemDataManager)
    
    self.sharedModule = sharedModule
    self.placedItemsByPlayer = {}
    
    -- Get placement folder reference
    self.placedFolder = self:_GetOrCreatePlacedFolder()
    
    return self
end

-- Get or create the World_Items/Placed folder
function ItemDataManager:_GetOrCreatePlacedFolder()
    local worldItems = Workspace:FindFirstChild("World_Items")
    if not worldItems then
        worldItems = Instance.new("Folder")
        worldItems.Name = "World_Items"
        worldItems.Parent = Workspace
    end
    
    local placedFolder = worldItems:FindFirstChild("Placed")
    if not placedFolder then
        placedFolder = Instance.new("Folder")
        placedFolder.Name = "Placed"
        placedFolder.Parent = worldItems
    end
    
    return placedFolder
end

-- Save world data to DataStore
function ItemDataManager:SaveWorldData()
    if RunService:IsClient() then 
        warn("ItemDataManager: SaveWorldData should only be called on server")
        return false 
    end
    
    print("ItemDataManager: Saving world data...")
    
    -- Get DataService
    local DataService = _G.DataService or (self.sharedModule and self.sharedModule.DataService)
    if not DataService then
        warn("ItemDataManager: DataService not available for saving")
        return false
    end
    
    -- Collect all placed items data
    local itemsData = {}
    
    if self.placedFolder then
        for _, item in ipairs(self.placedFolder:GetChildren()) do
            if item:IsA("Model") or item:IsA("BasePart") then
                local itemData = self:_SerializeItem(item)
                if itemData then
                    table.insert(itemsData, itemData)
                end
            end
        end
    end
    
    print("ItemDataManager: Collected", #itemsData, "items for saving")
    
    -- Save to DataStore
    local success, result = pcall(function()
        return DataService:SaveData("WorldPlacedItems", itemsData)
    end)
    
    if success and result then
        print("ItemDataManager: Successfully saved world data")
        return true
    else
        warn("ItemDataManager: Failed to save world data:", tostring(result))
        return false
    end
end

-- Load world data from DataStore
function ItemDataManager:LoadWorldData(itemTemplateManager)
    if RunService:IsClient() then 
        warn("ItemDataManager: LoadWorldData should only be called on server")
        return false 
    end
    
    print("ItemDataManager: Loading world data...")
    
    -- Get DataService
    local DataService = _G.DataService or (self.sharedModule and self.sharedModule.DataService)
    if not DataService then
        warn("ItemDataManager: DataService not available for loading")
        return false
    end
    
    -- Load from DataStore
    local success, itemsData = pcall(function()
        return DataService:LoadData("WorldPlacedItems") or {}
    end)
    
    if not success then
        warn("ItemDataManager: Failed to load world data:", tostring(itemsData))
        return false
    end
    
    print("ItemDataManager: Loaded", #itemsData, "items from storage")
    
    -- Clear existing items
    self:_ClearPlacedItems()
    
    -- Restore items
    local itemsRestored = 0
    for _, itemData in ipairs(itemsData) do
        if self:_RestoreItem(itemData, itemTemplateManager) then
            itemsRestored = itemsRestored + 1
        end
    end
    
    print("ItemDataManager: Successfully restored", itemsRestored, "world items")
    return true
end

-- Serialize an item for storage
function ItemDataManager:_SerializeItem(item)
    if not item then return nil end
    
    local itemData = {
        itemId = item:GetAttribute("itemId") or item:GetAttribute("item") or item.Name,
        instanceId = item:GetAttribute("instanceId") or item.Name,
        owner = item:GetAttribute("owner"),
        placedTime = item:GetAttribute("placedTime") or os.time(),
        persistent = item:GetAttribute("persistent")
    }
    
    -- Get position and rotation
    if item:IsA("Model") and item.PrimaryPart then
        local cf = item:GetPrimaryPartCFrame()
        itemData.position = {cf.Position.X, cf.Position.Y, cf.Position.Z}
        local rx, ry, rz = cf:ToEulerAnglesXYZ()
        itemData.rotation = {math.deg(rx), math.deg(ry), math.deg(rz)}
    elseif item:IsA("BasePart") then
        local cf = item.CFrame
        itemData.position = {cf.Position.X, cf.Position.Y, cf.Position.Z}
        local rx, ry, rz = cf:ToEulerAnglesXYZ()
        itemData.rotation = {math.deg(rx), math.deg(ry), math.deg(rz)}
    else
        warn("ItemDataManager: Unknown item type for serialization:", item.ClassName)
        return nil
    end
    
    -- Add to player's placed items list
    local ownerId = itemData.owner
    if ownerId then
        if not self.placedItemsByPlayer[ownerId] then
            self.placedItemsByPlayer[ownerId] = {}
        end
        if not table.find(self.placedItemsByPlayer[ownerId], itemData.instanceId) then
            table.insert(self.placedItemsByPlayer[ownerId], itemData.instanceId)
        end
    end
    
    return itemData
end

-- Restore an item from stored data
function ItemDataManager:_RestoreItem(itemData, itemTemplateManager)
    if not itemData or not itemData.itemId then
        warn("ItemDataManager: Invalid item data for restoration")
        return false
    end
    
    print("ItemDataManager: Restoring item:", itemData.itemId, "InstanceID:", itemData.instanceId)
    
    -- Get the item template
    local template = itemTemplateManager:GetItemTemplate(itemData.itemId)
    if not template then
        warn("ItemDataManager: Failed to find template for item:", itemData.itemId)
        return false
    end
    
    -- Clone the template
    local placedItem = itemTemplateManager:CloneTemplate(template, itemData.instanceId)
    if not placedItem then
        warn("ItemDataManager: Failed to clone template for:", itemData.itemId)
        return false
    end
    
    -- Apply item data attributes
    self:_ApplyItemAttributes(placedItem, itemData)
    
    -- Set position and rotation
    local position = Vector3.new(itemData.position[1], itemData.position[2], itemData.position[3])
    local rotation = Vector3.new(itemData.rotation[1], itemData.rotation[2], itemData.rotation[3])
    
    if placedItem:IsA("Model") and placedItem.PrimaryPart then
        placedItem:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.fromEulerAnglesXYZ(
            math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)
        ))
        
        -- Set all parts to anchored
        for _, part in pairs(placedItem:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = true
            end
        end
    elseif placedItem:IsA("BasePart") then
        placedItem.CFrame = CFrame.new(position) * CFrame.fromEulerAnglesXYZ(
            math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)
        )
        placedItem.Anchored = true
        placedItem.CanCollide = true
    end
    
    -- Parent to placed folder
    placedItem.Parent = self.placedFolder
    
    -- Add to tracking
    local ownerId = itemData.owner
    if ownerId then
        if not self.placedItemsByPlayer[ownerId] then
            self.placedItemsByPlayer[ownerId] = {}
        end
        if not table.find(self.placedItemsByPlayer[ownerId], itemData.instanceId) then
            table.insert(self.placedItemsByPlayer[ownerId], itemData.instanceId)
        end
    end
    
    print("ItemDataManager: Successfully restored item:", itemData.instanceId)
    return true
end

-- Apply stored attributes to an item
function ItemDataManager:_ApplyItemAttributes(item, itemData)
    -- Set core attributes
    item:SetAttribute("itemId", itemData.itemId)
    item:SetAttribute("instanceId", itemData.instanceId)
    item:SetAttribute("owner", itemData.owner)
    item:SetAttribute("placedTime", itemData.placedTime)
    item:SetAttribute("persistent", itemData.persistent)
    
    -- Apply item metadata from Constants if available
    local Constants = self.sharedModule and self.sharedModule.Constants
    if Constants and Constants.ITEMS and Constants.ITEMS[itemData.itemId] then
        local itemInfo = Constants.ITEMS[itemData.itemId]
        
        item:SetAttribute("tier", itemInfo.tier)
        item:SetAttribute("priceIngame", itemInfo.price and itemInfo.price.INGAME)
        item:SetAttribute("priceRobux", itemInfo.price and itemInfo.price.ROBUX)
        item:SetAttribute("name", itemInfo.name)
        item:SetAttribute("description", itemInfo.description)
        item:SetAttribute("assetId", itemInfo.assetId)
        
        print("ItemDataManager: Applied attributes from Constants for:", itemData.itemId)
    end
end

-- Clear all placed items from the world
function ItemDataManager:_ClearPlacedItems()
    if self.placedFolder then
        for _, child in ipairs(self.placedFolder:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                child:Destroy()
            end
        end
    end
    
    self.placedItemsByPlayer = {}
    print("ItemDataManager: Cleared all placed items")
end

-- Get player's placed items
function ItemDataManager:GetPlayerPlacedItems(player)
    local userId = tostring(player.UserId)
    return self.placedItemsByPlayer[userId] or {}
end

-- Add item to player's tracking
function ItemDataManager:AddPlayerPlacedItem(player, instanceId)
    local userId = tostring(player.UserId)
    if not self.placedItemsByPlayer[userId] then
        self.placedItemsByPlayer[userId] = {}
    end
    
    if not table.find(self.placedItemsByPlayer[userId], instanceId) then
        table.insert(self.placedItemsByPlayer[userId], instanceId)
    end
end

-- Remove item from player's tracking
function ItemDataManager:RemovePlayerPlacedItem(player, instanceId)
    local userId = tostring(player.UserId)
    local playerItems = self.placedItemsByPlayer[userId]
    
    if playerItems then
        local index = table.find(playerItems, instanceId)
        if index then
            table.remove(playerItems, index)
        end
    end
end

-- Create item data for a newly placed item
function ItemDataManager:CreatePlacedItemData(itemId, instanceId, position, rotation, player)
    return {
        itemId = itemId,
        instanceId = instanceId,
        owner = tostring(player.UserId),
        placedTime = os.time(),
        persistent = true,
        position = {position.X, position.Y, position.Z},
        rotation = {rotation.X, rotation.Y, rotation.Z}
    }
end

-- Get statistics about placed items
function ItemDataManager:GetStatistics()
    local totalItems = 0
    local playerCounts = {}
    
    for playerId, items in pairs(self.placedItemsByPlayer) do
        local count = #items
        totalItems = totalItems + count
        playerCounts[playerId] = count
    end
    
    return {
        totalItems = totalItems,
        playerCounts = playerCounts,
        uniquePlayers = 0
    }
end

return ItemDataManager 