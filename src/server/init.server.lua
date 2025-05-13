local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedModule = require(ReplicatedStorage.shared)
local GameManager = SharedModule.GameManager
local CurrencyManager = SharedModule.Economy.CurrencyManager
local InteractionManagerModule = SharedModule.Interaction.Manager
local interactionManager = InteractionManagerModule.new()
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

-- Initialize managers with consistent OOP approach
local currencyManager = CurrencyManager.new()
currencyManager:Initialize()

-- Fix GameManager OOP approach - create instance instead of using module directly
local gameManager = GameManager.new()
gameManager:Initialize()

-- interactionManager is already initialized above using OOP pattern

-- Set up event handlers with gameManager instance
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

print("Server initialized successfully")