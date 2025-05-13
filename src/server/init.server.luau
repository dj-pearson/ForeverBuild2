local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Create Remotes folder if it doesn't exist
if not ReplicatedStorage:FindFirstChild("Remotes") then
    local remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
    
    -- Create common remote events
    local updateBalance = Instance.new("RemoteEvent")
    updateBalance.Name = "UpdateBalance"
    updateBalance.Parent = remotes
    
    local getInventory = Instance.new("RemoteFunction")
    getInventory.Name = "GetInventory"
    getInventory.Parent = remotes
    
    local buyItem = Instance.new("RemoteEvent")
    buyItem.Name = "BuyItem"
    buyItem.Parent = remotes
    
    local placeItem = Instance.new("RemoteEvent")
    placeItem.Name = "PlaceItem"
    placeItem.Parent = remotes
    
    local interactWithItem = Instance.new("RemoteEvent")
    interactWithItem.Name = "InteractWithItem"
    interactWithItem.Parent = remotes
end

local SharedModule = require(ReplicatedStorage.shared)
-- Initialize the shared module
SharedModule.Init()

local GameManagerModule = SharedModule.GameManager
local CurrencyManagerModule = SharedModule.CurrencyManager
local InteractionManagerModule = SharedModule.InteractionManager

-- Create manager instances with consistent approach
local gameManager = GameManagerModule.new()
local currencyManager = CurrencyManagerModule.new()
local interactionManager = InteractionManagerModule.new()

-- Initialize all managers
gameManager:Initialize()
currencyManager:Initialize()
interactionManager:Initialize()

-- Create Remotes folder if it doesn't exist
if not ReplicatedStorage:FindFirstChild("Remotes") then
    local remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

-- Create remote events and functions
local remotes = ReplicatedStorage.Remotes
local events = {
    "BuyItem",
    "PlaceItem",
    "MoveItem",
    "RotateItem",
    "ChangeColor",
    "RemoveItem",
    "InteractWithItem",
    "AddToInventory",
    "ApplyItemEffect",
    "ShowItemDescription",
    "NotifyPlayer",
    "UpdateBalance"
}

local functions = {
    "GetInventory",
    "GetItemData",
    "GetAvailableInteractions"
}

-- Create RemoteEvents
for _, eventName in ipairs(events) do
    if not remotes:FindFirstChild(eventName) then
        local event = Instance.new("RemoteEvent")
        event.Name = eventName
        event.Parent = remotes
    end
end

-- Create RemoteFunctions
for _, functionName in ipairs(functions) do
    if not remotes:FindFirstChild(functionName) then
        local func = Instance.new("RemoteFunction")
        func.Name = functionName
        func.Parent = remotes
    end
end

-- Setup event handlers
remotes.BuyItem.OnServerEvent:Connect(function(player, itemId)
    gameManager:HandleBuyItem(player, itemId)
end)

remotes.PlaceItem.OnServerEvent:Connect(function(player, itemId, position, rotation)
    gameManager:HandlePlaceItem(player, itemId, position, rotation)
end)

remotes.MoveItem.OnServerEvent:Connect(function(player, itemId, newPosition)
    gameManager:HandleMoveItem(player, itemId, newPosition)
end)

remotes.RotateItem.OnServerEvent:Connect(function(player, itemId, newRotation)
    gameManager:HandleRotateItem(player, itemId, newRotation)
end)

remotes.ChangeColor.OnServerEvent:Connect(function(player, itemId, newColor)
    gameManager:HandleChangeColor(player, itemId, newColor)
end)

remotes.RemoveItem.OnServerEvent:Connect(function(player, itemId)
    gameManager:HandleRemoveItem(player, itemId)
end)

remotes.GetInventory.OnServerInvoke = function(player)
    return gameManager:GetPlayerInventory(player)
end

remotes.GetItemData.OnServerInvoke = function(player, itemId)
    return gameManager:GetItemData(itemId)
end

remotes.InteractWithItem.OnServerEvent:Connect(function(player, placedItem, interactionType)
    local placement = gameManager:GetItemPlacement(placedItem.id)
    if not placement then return end
    local success = interactionManager:HandleInteraction(player, placedItem.id, interactionType, placement)
    if not success and remotes.NotifyPlayer then
        remotes.NotifyPlayer:FireClient(player, "Cannot interact with this item!")
    end
end)

remotes.GetAvailableInteractions.OnServerInvoke = function(player, placedItem)
    local placement = gameManager:GetItemPlacement(placedItem.id)
    if not placement then return {} end
    local itemData = gameManager:GetItemData(placedItem.id)
    if not itemData then return {} end
    local interactions = {"examine"}
    if not placement.locked then
        table.insert(interactions, "pickup")
    end
    if itemData.useEffect then
        table.insert(interactions, "use")
    end
    if itemData.customInteractions then
        for _, interaction in ipairs(itemData.customInteractions) do
            table.insert(interactions, interaction)
        end
    end
    return interactions
end

remotes.AddToInventory.OnServerEvent:Connect(function(player, itemId)
    gameManager:AddToInventory(player, itemId)
end)

remotes.ApplyItemEffect.OnServerEvent:Connect(function(player, itemId, placement)
    gameManager:ApplyItemEffect(player, itemId, placement)
end)

-- Add PickupItem RemoteEvent
if not remotes:FindFirstChild("PickupItem") then
    local pickupItem = Instance.new("RemoteEvent")
    pickupItem.Name = "PickupItem"
    pickupItem.Parent = remotes
end

-- Handle item pickup requests
remotes.PickupItem.OnServerEvent:Connect(function(player, itemName)
    -- Admin check
    local isAdmin = false
    for _, adminId in ipairs(SharedModule.Constants.ADMIN_IDS) do
        if player.UserId == adminId then
            isAdmin = true
            break
        end
    end
    local itemData = SharedModule.Constants.ITEMS[itemName]
    if not itemData then
        remotes.NotifyPlayer:FireClient(player, "Item not found.")
        return
    end
    -- Find the item in Workspace.Items
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        remotes.NotifyPlayer:FireClient(player, "No items folder in workspace.")
        return
    end
    local itemModel = itemsFolder:FindFirstChild(itemName)
    if not itemModel then
        remotes.NotifyPlayer:FireClient(player, "Item not found in world.")
        return
    end
    -- If not admin, check currency
    if not isAdmin then
        local playerData = gameManager.playerData[player.UserId]
        local price = itemData.price and itemData.price.INGAME or 0
        if not playerData or playerData.currency < price then
            remotes.NotifyPlayer:FireClient(player, "Not enough currency to pick up this item.")
            return
        end
        -- Deduct currency
        playerData.currency = playerData.currency - price
        gameManager:savePlayerData(player)
        remotes.UpdateBalance:FireClient(player, playerData.currency)
    end
    -- Add to inventory
    gameManager:AddToInventory(player, itemName)
    -- Remove from world
    itemModel:Destroy()
    remotes.NotifyPlayer:FireClient(player, "Picked up " .. itemName .. "!")
end)

-- Add CloneItem RemoteEvent
if not remotes:FindFirstChild("CloneItem") then
    local cloneItem = Instance.new("RemoteEvent")
    cloneItem.Name = "CloneItem"
    cloneItem.Parent = remotes
end

-- Handle item cloning requests
remotes.CloneItem.OnServerEvent:Connect(function(player, itemId)
    local result = gameManager:HandleCloneItem(player, itemId)
    remotes.NotifyPlayer:FireClient(player, result.message)
    if result.success then
        remotes.UpdateBalance:FireClient(player, gameManager.playerData[player.UserId].currency)
    end
end)

print("Server initialized successfully")