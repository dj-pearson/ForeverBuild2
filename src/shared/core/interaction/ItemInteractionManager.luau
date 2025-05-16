-- ItemInteractionManager.luau
-- Handles two types of interactions: 
-- 1. Store interactions (purchasing items from the item catalog)
-- 2. World item interactions (interacting with placed items in the world)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Parent.Constants)

local ItemInteractionManager = {}
ItemInteractionManager.__index = ItemInteractionManager

function ItemInteractionManager.new()
    local self = setmetatable({}, ItemInteractionManager)
    
    -- Tables to track item data
    self.itemCatalog = {}       -- Store items available for purchase
    self.placedItems = {}       -- Items placed in the world
    self.playerInventories = {} -- Player inventories
    
    -- Remote events/functions
    self.remotes = {}
    
    return self
end

function ItemInteractionManager:Initialize()
    print("ItemInteractionManager initializing...")
    
    -- Initialize item catalog from Constants
    self:InitializeItemCatalog()
    
    -- Create remote events/functions if they don't exist
    self:SetupRemotes()
    
    -- Connect remote events
    self:ConnectRemoteEvents()
    
    -- Handle player joining/leaving
    self:SetupPlayerEvents()
    
    print("ItemInteractionManager initialized successfully")
    return true
end

function ItemInteractionManager:InitializeItemCatalog()
    -- Load all items from Constants
    for itemName, itemData in pairs(Constants.ITEMS) do
        self.itemCatalog[itemName] = {
            name = itemName,
            icon = itemData.icon,
            description = itemData.description,
            tier = itemData.tier,
            price = itemData.price
        }
    end
    
    print("Item catalog initialized with " .. self:CountTableItems(self.itemCatalog) .. " items")
end

function ItemInteractionManager:SetupRemotes()
    -- Create Remotes folder if it doesn't exist
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Create RemoteFunctions
    self:CreateRemoteFunction(remotesFolder, "GetItemCatalog")
    self:CreateRemoteFunction(remotesFolder, "GetItemData")
    self:CreateRemoteFunction(remotesFolder, "GetAvailableInteractions")
    self:CreateRemoteFunction(remotesFolder, "GetInventory")
    self:CreateRemoteFunction(remotesFolder, "IsItemAffordable")
    
    -- Create RemoteEvents
    self:CreateRemoteEvent(remotesFolder, "PurchaseItem")
    self:CreateRemoteEvent(remotesFolder, "PlaceItem")
    self:CreateRemoteEvent(remotesFolder, "MoveItem")
    self:CreateRemoteEvent(remotesFolder, "RotateItem")
    self:CreateRemoteEvent(remotesFolder, "CloneItem")
    self:CreateRemoteEvent(remotesFolder, "DestroyItem")
    self:CreateRemoteEvent(remotesFolder, "ChangeItemColor")
    self:CreateRemoteEvent(remotesFolder, "AddToInventory")
    self:CreateRemoteEvent(remotesFolder, "RemoveFromInventory")
    self:CreateRemoteEvent(remotesFolder, "NotifyPlayer")
    
    print("Remote events/functions created successfully")
end

function ItemInteractionManager:CreateRemoteFunction(parent, name)
    local existing = parent:FindFirstChild(name)
    if not existing then
        local remoteFunc = Instance.new("RemoteFunction")
        remoteFunc.Name = name
        remoteFunc.Parent = parent
        self.remotes[name] = remoteFunc
    else
        self.remotes[name] = existing
    end
end

function ItemInteractionManager:CreateRemoteEvent(parent, name)
    local existing = parent:FindFirstChild(name)
    if not existing then
        local remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = name
        remoteEvent.Parent = parent
        self.remotes[name] = remoteEvent
    else
        self.remotes[name] = existing
    end
end

function ItemInteractionManager:ConnectRemoteEvents()
    -- Set up remote function handlers
    self.remotes.GetItemCatalog.OnServerInvoke = function(player)
        return self:GetItemCatalog()
    end
    
    self.remotes.GetItemData.OnServerInvoke = function(player, itemName)
        return self:GetItemData(itemName)
    end
    
    self.remotes.GetAvailableInteractions.OnServerInvoke = function(player, itemGuid)
        return self:GetAvailableInteractions(player, itemGuid)
    end
    
    self.remotes.GetInventory.OnServerInvoke = function(player)
        return self:GetPlayerInventory(player)
    end
    
    self.remotes.IsItemAffordable.OnServerInvoke = function(player, itemName, quantity)
        return self:IsItemAffordable(player, itemName, quantity or 1)
    end
    
    -- Connect remote events
    self.remotes.PurchaseItem.OnServerEvent:Connect(function(player, itemName, quantity, currencyType)
        self:HandlePurchaseItem(player, itemName, quantity, currencyType)
    end)
    
    self.remotes.PlaceItem.OnServerEvent:Connect(function(player, itemName, position, rotation)
        self:HandlePlaceItem(player, itemName, position, rotation)
    end)
    
    self.remotes.MoveItem.OnServerEvent:Connect(function(player, itemGuid, newPosition)
        self:HandleMoveItem(player, itemGuid, newPosition)
    end)
    
    self.remotes.RotateItem.OnServerEvent:Connect(function(player, itemGuid, newRotation)
        self:HandleRotateItem(player, itemGuid, newRotation)
    end)
    
    self.remotes.CloneItem.OnServerEvent:Connect(function(player, itemGuid, newPosition)
        self:HandleCloneItem(player, itemGuid, newPosition)
    end)
    
    self.remotes.DestroyItem.OnServerEvent:Connect(function(player, itemGuid)
        self:HandleDestroyItem(player, itemGuid)
    end)
    
    self.remotes.ChangeItemColor.OnServerEvent:Connect(function(player, itemGuid, newColor)
        self:HandleChangeItemColor(player, itemGuid, newColor)
    end)
    
    self.remotes.AddToInventory.OnServerEvent:Connect(function(player, itemName)
        self:AddItemToInventory(player, itemName)
    end)
    
    self.remotes.RemoveFromInventory.OnServerEvent:Connect(function(player, itemName)
        self:RemoveItemFromInventory(player, itemName)
    end)
    
    print("Remote events/functions connected successfully")
end

function ItemInteractionManager:SetupPlayerEvents()
    -- Handle player joining
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerData(player)
    end)
    
    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerData(player)
        self.playerInventories[player.UserId] = nil -- Clear from memory
    end)
    
    -- Initialize data for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:InitializePlayerData(player)
    end
end

function ItemInteractionManager:InitializePlayerData(player)
    -- Create inventory for player
    if not self.playerInventories[player.UserId] then
        -- Here we would load from DataStore, but for now initialize with starting currency
        self.playerInventories[player.UserId] = {
            currency = Constants.CURRENCY.STARTING_CURRENCY,
            items = {}
        }
    end
end

function ItemInteractionManager:SavePlayerData(player)
    -- Save player data to DataStore
    -- This would use DataStoreService but is omitted for this example
end

-- STORE INTERACTION METHODS

function ItemInteractionManager:GetItemCatalog()
    return self.itemCatalog
end

function ItemInteractionManager:GetItemData(itemName)
    return self.itemCatalog[itemName]
end

function ItemInteractionManager:GetPlayerInventory(player)
    return self.playerInventories[player.UserId]
end

function ItemInteractionManager:IsItemAffordable(player, itemName, quantity)
    local inventory = self.playerInventories[player.UserId]
    if not inventory then return false end
    
    local itemData = self.itemCatalog[itemName]
    if not itemData then return false end
    
    -- Check if player has enough currency
    local totalCost = itemData.price.INGAME * quantity
    return inventory.currency >= totalCost
end

function ItemInteractionManager:HandlePurchaseItem(player, itemName, quantity, currencyType)
    currencyType = currencyType or "INGAME" -- Default to in-game currency
    quantity = quantity or 1 -- Default to 1 item
    
    local inventory = self.playerInventories[player.UserId]
    if not inventory then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Player inventory not found")
        return false
    end
    
    local itemData = self.itemCatalog[itemName]
    if not itemData then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found in catalog")
        return false
    end
    
    -- Check if using in-game currency or Robux
    if currencyType == "INGAME" then
        -- Check if player can afford the item
        local totalCost = itemData.price.INGAME * quantity
        if inventory.currency < totalCost then
            self.remotes.NotifyPlayer:FireClient(player, "Error: Not enough coins")
            return false
        end
        
        -- Deduct cost and add item to inventory
        inventory.currency = inventory.currency - totalCost
        
        -- Add items to inventory
        for i = 1, quantity do
            self:AddItemToInventory(player, itemName)
        end
        
        self.remotes.NotifyPlayer:FireClient(player, "Purchased " .. quantity .. " " .. itemName)
        return true
    elseif currencyType == "ROBUX" then
        -- For Robux purchases, we would integrate with Developer Products
        -- This is simplified for the example
        self.remotes.NotifyPlayer:FireClient(player, "Robux purchases would be handled through Developer Products")
        return false
    end
    
    return false
end

function ItemInteractionManager:AddItemToInventory(player, itemName)
    local inventory = self.playerInventories[player.UserId]
    if not inventory then return false end
    
    -- Check if item exists in catalog
    if not self.itemCatalog[itemName] then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found in catalog")
        return false
    end
    
    -- Add item to inventory
    table.insert(inventory.items, {
        name = itemName,
        guid = self:GenerateGUID()
    })
    
    return true
end

function ItemInteractionManager:RemoveItemFromInventory(player, itemGuid)
    local inventory = self.playerInventories[player.UserId]
    if not inventory then return false end
    
    -- Find and remove item by GUID
    for i, item in ipairs(inventory.items) do
        if item.guid == itemGuid then
            table.remove(inventory.items, i)
            return true
        end
    end
    
    return false
end

-- WORLD ITEM INTERACTION METHODS

function ItemInteractionManager:GetAvailableInteractions(player, itemGuid)
    -- Get item from placed items
    local placedItem = self:GetPlacedItemByGuid(itemGuid)
    if not placedItem then
        return {"examine"} -- Default interaction
    end
    
    -- Different items might have different available interactions
    local itemName = placedItem.name
    
    -- Base interactions available for all items
    local interactions = {"move", "rotate", "clone", "destroy"}
    
    -- Add item-specific interactions based on item type
    local itemData = self.itemCatalog[itemName]
    if itemData then
        if itemName:lower():find("cube") then
            table.insert(interactions, "changeColor")
        end
        
        if itemName:lower():find("gear") then
            table.insert(interactions, "spin")
        end
        
        if itemName:lower():find("portal") then
            table.insert(interactions, "teleport")
        end
    end
    
    return interactions
end

function ItemInteractionManager:HandlePlaceItem(player, itemName, position, rotation)
    -- Check if player has item in inventory
    local inventory = self.playerInventories[player.UserId]
    if not inventory then return false end
    
    -- Find item in inventory
    local itemIndex = nil
    local itemGuid = nil
    
    for i, item in ipairs(inventory.items) do
        if item.name == itemName then
            itemIndex = i
            itemGuid = item.guid
            break
        end
    end
    
    if not itemIndex then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found in inventory")
        return false
    end
    
    -- Remove from inventory
    table.remove(inventory.items, itemIndex)
    
    -- Get template item from Items folder
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Items folder not found")
        return false
    end
    
    -- Find folder containing the item based on tier
    local itemData = self.itemCatalog[itemName]
    if not itemData then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item data not found")
        return false
    end
    
    -- Format item name for folder search (convert from 'brick_cube' to 'Brick_Cube')
    local formattedItemName = itemName:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end):gsub(" ", "_")
    
    -- Find template item
    local templateItem
    for _, folder in ipairs(itemsFolder:GetChildren()) do
        templateItem = folder:FindFirstChild(formattedItemName)
        if templateItem then break end
    end
    
    if not templateItem then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item template not found")
        return false
    end
    
    -- Clone the item
    local newItem = templateItem:Clone()
    newItem:SetAttribute("guid", itemGuid or self:GenerateGUID())
    newItem:SetAttribute("owner", player.UserId)
    newItem:SetAttribute("placedBy", player.Name)
    
    -- Move to World_Items folder
    local worldFolder = workspace:FindFirstChild("World_Items")
    if not worldFolder then
        worldFolder = Instance.new("Folder")
        worldFolder.Name = "World_Items"
        worldFolder.Parent = workspace
    end
    
    -- Position and rotate the item
    newItem:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(0, rotation, 0))
    newItem.Parent = worldFolder
    
    -- Track the placed item
    self.placedItems[newItem:GetAttribute("guid")] = {
        model = newItem,
        name = itemName,
        owner = player.UserId,
        position = position,
        rotation = rotation
    }
    
    self.remotes.NotifyPlayer:FireClient(player, "Item placed successfully")
    return true
end

function ItemInteractionManager:HandleMoveItem(player, itemGuid, newPosition)
    -- Get placed item
    local placedItem = self:GetPlacedItemByGuid(itemGuid)
    if not placedItem then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found")
        return false
    end
    
    -- Check if player owns the item or is an admin
    if not self:CanPlayerModifyItem(player, placedItem) then
        self.remotes.NotifyPlayer:FireClient(player, "Error: You do not have permission to move this item")
        return false
    end
    
    -- Check if player has enough currency for the action
    local moveCost = Constants.ITEM_ACTIONS.move.cost
    local inventory = self.playerInventories[player.UserId]
    if not inventory or inventory.currency < moveCost then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Not enough coins to move item")
        return false
    end
    
    -- Deduct cost
    inventory.currency = inventory.currency - moveCost
    
    -- Move the item
    placedItem.position = newPosition
    placedItem.model:SetPrimaryPartCFrame(
        CFrame.new(newPosition) * CFrame.Angles(0, placedItem.rotation or 0, 0)
    )
    
    self.remotes.NotifyPlayer:FireClient(player, "Item moved. Cost: " .. moveCost .. " coins")
    return true
end

function ItemInteractionManager:HandleRotateItem(player, itemGuid, newRotation)
    -- Get placed item
    local placedItem = self:GetPlacedItemByGuid(itemGuid)
    if not placedItem then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found")
        return false
    end
    
    -- Check if player owns the item or is an admin
    if not self:CanPlayerModifyItem(player, placedItem) then
        self.remotes.NotifyPlayer:FireClient(player, "Error: You do not have permission to rotate this item")
        return false
    end
    
    -- Check if player has enough currency for the action
    local rotateCost = Constants.ITEM_ACTIONS.rotate.cost
    local inventory = self.playerInventories[player.UserId]
    if not inventory or inventory.currency < rotateCost then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Not enough coins to rotate item")
        return false
    end
    
    -- Deduct cost
    inventory.currency = inventory.currency - rotateCost
    
    -- Rotate the item
    placedItem.rotation = newRotation
    placedItem.model:SetPrimaryPartCFrame(
        CFrame.new(placedItem.position) * CFrame.Angles(0, newRotation, 0)
    )
    
    self.remotes.NotifyPlayer:FireClient(player, "Item rotated. Cost: " .. rotateCost .. " coins")
    return true
end

function ItemInteractionManager:HandleCloneItem(player, itemGuid, newPosition)
    -- Get placed item
    local placedItem = self:GetPlacedItemByGuid(itemGuid)
    if not placedItem then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found")
        return false
    end
    
    -- Check if player has enough currency for the action
    local cloneCost = Constants.ITEM_ACTIONS.clone.cost
    local inventory = self.playerInventories[player.UserId]
    if not inventory or inventory.currency < cloneCost then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Not enough coins to clone item")
        return false
    end
    
    -- Deduct cost
    inventory.currency = inventory.currency - cloneCost
    
    -- Clone the item
    local newItem = placedItem.model:Clone()
    local newGuid = self:GenerateGUID()
    newItem:SetAttribute("guid", newGuid)
    newItem:SetAttribute("owner", player.UserId)
    newItem:SetAttribute("placedBy", player.Name)
    
    -- Position the cloned item
    newItem:SetPrimaryPartCFrame(
        CFrame.new(newPosition or placedItem.position) * 
        CFrame.Angles(0, placedItem.rotation or 0, 0)
    )
    
    local worldFolder = workspace:FindFirstChild("World_Items")
    newItem.Parent = worldFolder
    
    -- Track the new item
    self.placedItems[newGuid] = {
        model = newItem,
        name = placedItem.name,
        owner = player.UserId,
        position = newPosition or placedItem.position,
        rotation = placedItem.rotation
    }
    
    self.remotes.NotifyPlayer:FireClient(player, "Item cloned. Cost: " .. cloneCost .. " coins")
    return true
end

function ItemInteractionManager:HandleDestroyItem(player, itemGuid)
    -- Get placed item
    local placedItem = self:GetPlacedItemByGuid(itemGuid)
    if not placedItem then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found")
        return false
    end
    
    -- Check if player owns the item or is an admin
    if not self:CanPlayerModifyItem(player, placedItem) then
        self.remotes.NotifyPlayer:FireClient(player, "Error: You do not have permission to destroy this item")
        return false
    end
    
    -- Check if player has enough currency for the action
    local destroyCost = Constants.ITEM_ACTIONS.destroy.cost
    local inventory = self.playerInventories[player.UserId]
    if not inventory or inventory.currency < destroyCost then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Not enough coins to destroy item")
        return false
    end
    
    -- Deduct cost
    inventory.currency = inventory.currency - destroyCost
    
    -- Destroy the item
    placedItem.model:Destroy()
    self.placedItems[itemGuid] = nil
    
    self.remotes.NotifyPlayer:FireClient(player, "Item destroyed. Cost: " .. destroyCost .. " coins")
    return true
end

function ItemInteractionManager:HandleChangeItemColor(player, itemGuid, newColor)
    -- Get placed item
    local placedItem = self:GetPlacedItemByGuid(itemGuid)
    if not placedItem then
        self.remotes.NotifyPlayer:FireClient(player, "Error: Item not found")
        return false
    end
    
    -- Check if player owns the item or is an admin
    if not self:CanPlayerModifyItem(player, placedItem) then
        self.remotes.NotifyPlayer:FireClient(player, "Error: You do not have permission to change this item's color")
        return false
    end
    
    -- Set color for all parts
    for _, part in ipairs(placedItem.model:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Convert color name to Color3 value
            part.Color = self:GetColorFromName(newColor)
        end
    end
    
    placedItem.model:SetAttribute("color", newColor)
    self.remotes.NotifyPlayer:FireClient(player, "Item color changed to " .. newColor)
    return true
end

-- UTILITY METHODS

function ItemInteractionManager:GetPlacedItemByGuid(guid)
    return self.placedItems[guid]
end

function ItemInteractionManager:CanPlayerModifyItem(player, placedItem)
    -- Check if player is the owner of the item
    if placedItem.owner == player.UserId then
        return true
    end
    
    -- Check if player is an admin
    for _, adminId in ipairs(Constants.ADMIN_IDS) do
        if player.UserId == adminId then
            return true
        end
    end
    
    return false
end

function ItemInteractionManager:GenerateGUID()
    -- Simple GUID generator for unique IDs
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local guid = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
    return guid
end

function ItemInteractionManager:GetColorFromName(colorName)
    -- Map color names to Color3 values
    local colorMap = {
        ["Red"] = Color3.fromRGB(255, 0, 0),
        ["Green"] = Color3.fromRGB(0, 255, 0),
        ["Blue"] = Color3.fromRGB(0, 0, 255),
        ["Yellow"] = Color3.fromRGB(255, 255, 0),
        ["Purple"] = Color3.fromRGB(128, 0, 128),
        ["White"] = Color3.fromRGB(255, 255, 255),
        ["Black"] = Color3.fromRGB(0, 0, 0),
        ["Gray"] = Color3.fromRGB(128, 128, 128),
        ["Orange"] = Color3.fromRGB(255, 165, 0),
        ["Brown"] = Color3.fromRGB(165, 42, 42),
        ["Pink"] = Color3.fromRGB(255, 192, 203),
        ["Cyan"] = Color3.fromRGB(0, 255, 255)
    }
    
    return colorMap[colorName] or Color3.fromRGB(255, 255, 255) -- Default to white
end

function ItemInteractionManager:CountTableItems(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

return ItemInteractionManager 