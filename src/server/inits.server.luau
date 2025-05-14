--[[
    Server Initialization Module - ForeverBuild2
    
    This is the main entry point for server-side logic.
    It initializes all necessary server components and services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

print("Server initialization script starting...")

-- Create Remotes folder if it doesn't exist
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
    
    -- Create necessary RemoteEvents and RemoteFunctions
    local function createRemote(name, remoteType)
        local remote = Instance.new(remoteType)
        remote.Name = name
        remote.Parent = Remotes
        return remote
    end
    
    -- Create standard remotes
    createRemote("BuyItem", "RemoteEvent")
    createRemote("GetInventory", "RemoteFunction")
    createRemote("PlaceItem", "RemoteEvent")
    createRemote("InteractWithItem", "RemoteEvent")
    createRemote("GetAvailableInteractions", "RemoteFunction") -- Added missing remote function
    createRemote("CloneItem", "RemoteEvent") -- Added missing remote event
    createRemote("PickupItem", "RemoteEvent") -- Added missing remote event
    createRemote("AddToInventory", "RemoteEvent") -- Added missing remote event
    createRemote("GetItemData", "RemoteFunction") -- Added missing remote function
    createRemote("ApplyItemEffect", "RemoteEvent") -- Added missing remote event
    createRemote("ShowItemDescription", "RemoteEvent")
    createRemote("NotifyPlayer", "RemoteEvent")
    
    print("Created standard remote events and functions")
end

-- Initialize shared module with error handling
print("server.inits: Attempting to require shared module")
local SharedModule
local success, errorMessage = pcall(function()
    local shared = ReplicatedStorage:WaitForChild("shared", 10)
    print("server.inits: Found shared module at " .. shared:GetFullName())
    SharedModule = require(shared)
    return true
end)

if not success then
    warn("server.inits: Failed to require SharedModule:", errorMessage)
    SharedModule = {}
else
    print("server.inits: Successfully required SharedModule")
    
    if SharedModule.Init then
        local initSuccess, initError = pcall(function()
            SharedModule.Init() -- Ensure all shared systems are initialized
        end)
    
        if not initSuccess then
            warn("server.inits: Failed to initialize SharedModule:", initError)
        else
            print("server.inits: SharedModule initialized successfully")
        end
    end
end

-- Initialize server managers with error handling
print("server.inits: Initializing server managers")
local GameManager, InventoryManager, CurrencyManager, PlacementManager, InteractionManager

-- GameManager
if SharedModule.GameManager and SharedModule.GameManager.new then
    local gmSuccess, gmResult = pcall(function()
        return SharedModule.GameManager.new()
    end)
    
    if gmSuccess and gmResult then
        GameManager = gmResult
        print("server.inits: Successfully created GameManager instance")
    else
        warn("server.inits: Failed to create GameManager instance:", gmResult)
    end
else
    warn("server.inits: GameManager module not available")
end

-- InventoryManager
if SharedModule.InventoryManager and SharedModule.InventoryManager.new then
    local imSuccess, imResult = pcall(function()
        return SharedModule.InventoryManager.new()
    end)
    
    if imSuccess and imResult then
        InventoryManager = imResult
        print("server.inits: Successfully created InventoryManager instance")
    else
        warn("server.inits: Failed to create InventoryManager instance:", imResult)
    end
else
    warn("server.inits: InventoryManager module not available")
end

-- CurrencyManager
if SharedModule.CurrencyManager and SharedModule.CurrencyManager.new then
    local cmSuccess, cmResult = pcall(function()
        return SharedModule.CurrencyManager.new()
    end)
    
    if cmSuccess and cmResult then
        CurrencyManager = cmResult
        print("server.inits: Successfully created CurrencyManager instance")
    else
        warn("server.inits: Failed to create CurrencyManager instance:", cmResult)
    end
else
    warn("server.inits: CurrencyManager module not available")
end

-- PlacementManager
if SharedModule.PlacementManager and SharedModule.PlacementManager.new then
    local pmSuccess, pmResult = pcall(function()
        return SharedModule.PlacementManager.new()
    end)
    
    if pmSuccess and pmResult then
        PlacementManager = pmResult
        print("server.inits: Successfully created PlacementManager instance")
    else
        warn("server.inits: Failed to create PlacementManager instance:", pmResult)
    end
else
    warn("server.inits: PlacementManager module not available")
end

-- InteractionManager
if SharedModule.InteractionManager and SharedModule.InteractionManager.new then
    local imSuccess, imResult = pcall(function()
        return SharedModule.InteractionManager.new()
    end)
    
    if imSuccess and imResult then
        InteractionManager = imResult
        print("server.inits: Successfully created InteractionManager instance")
        
        -- Initialize interaction manager
        if InteractionManager.Initialize then
            InteractionManager:Initialize()
        end
    else
        warn("server.inits: Failed to create InteractionManager instance:", imResult)
    end
else
    warn("server.inits: InteractionManager module not available")
end

-- Setup Remote Function Handlers
-- GetInventory
local getInventoryRemote = Remotes:FindFirstChild("GetInventory")
if getInventoryRemote and InventoryManager then
    getInventoryRemote.OnServerInvoke = function(player)
        return InventoryManager:GetPlayerInventory(player)
    end
end

-- GetItemData
local getItemDataRemote = Remotes:FindFirstChild("GetItemData")
if getItemDataRemote then
    getItemDataRemote.OnServerInvoke = function(_, itemId)
        return SharedModule.Constants.ITEMS[itemId] or {}
    end
end

-- GetAvailableInteractions
local getAvailableInteractionsRemote = Remotes:FindFirstChild("GetAvailableInteractions")
if getAvailableInteractionsRemote and InteractionManager then
    getAvailableInteractionsRemote.OnServerInvoke = function(player, itemData)
        -- Return a default list of interactions if not defined specifically
        return {"examine", "pickup"}
    end
end

-- Setup Remote Event Handlers
-- BuyItem
local buyItemRemote = Remotes:FindFirstChild("BuyItem")
if buyItemRemote and GameManager then
    buyItemRemote.OnServerEvent:Connect(function(player, itemId)
        if not GameManager.HandleItemPurchase then
            warn("server.inits: GameManager.HandleItemPurchase function not found")
            return
        end
        
        local success = GameManager:HandleItemPurchase(player, itemId)
        if success then
            -- Notify player of successful purchase
            Remotes.NotifyPlayer:FireClient(player, "Successfully purchased " .. itemId)
        else
            -- Notify player of failed purchase
            Remotes.NotifyPlayer:FireClient(player, "Failed to purchase " .. itemId)
        end
    end)
end

-- PlaceItem
local placeItemRemote = Remotes:FindFirstChild("PlaceItem")
if placeItemRemote and PlacementManager then
    placeItemRemote.OnServerEvent:Connect(function(player, itemId, position, rotation)
        if not PlacementManager.PlaceItem then
            warn("server.inits: PlacementManager.PlaceItem function not found")
            return
        end
        
        local success = PlacementManager:PlaceItem(player, itemId, position, rotation)
        if success then
            Remotes.NotifyPlayer:FireClient(player, "Successfully placed " .. itemId)
        else
            Remotes.NotifyPlayer:FireClient(player, "Failed to place " .. itemId)
        end
    end)
end

-- InteractWithItem
local interactItemRemote = Remotes:FindFirstChild("InteractWithItem")
if interactItemRemote and InteractionManager then
    interactItemRemote.OnServerEvent:Connect(function(player, itemData, interactionType)
        if not InteractionManager.HandleInteraction then
            warn("server.inits: InteractionManager.HandleInteraction function not found")
            return
        end
        
        local success = InteractionManager:HandleInteraction(player, itemData.id, interactionType, itemData)
        if not success then
            Remotes.NotifyPlayer:FireClient(player, "Failed to " .. interactionType .. " " .. itemData.id)
        end
    end)
end

-- PickupItem
local pickupItemRemote = Remotes:FindFirstChild("PickupItem")
if pickupItemRemote and InventoryManager then
    pickupItemRemote.OnServerEvent:Connect(function(player, itemId)
        if not InventoryManager.AddItemToInventory then
            warn("server.inits: InventoryManager.AddItemToInventory function not found")
            return
        end
        
        local success = InventoryManager:AddItemToInventory(player, itemId)
        if success then
            Remotes.NotifyPlayer:FireClient(player, "Picked up " .. itemId)
        else
            Remotes.NotifyPlayer:FireClient(player, "Failed to pick up " .. itemId)
        end
    end)
end

-- AddToInventory
local addToInventoryRemote = Remotes:FindFirstChild("AddToInventory")
if addToInventoryRemote and InventoryManager then
    addToInventoryRemote.OnServerEvent:Connect(function(player, itemId)
        if not InventoryManager.AddItemToInventory then
            warn("server.inits: InventoryManager.AddItemToInventory function not found")
            return
        end
        
        InventoryManager:AddItemToInventory(player, itemId)
    end)
end

-- CloneItem
local cloneItemRemote = Remotes:FindFirstChild("CloneItem")
if cloneItemRemote and PlacementManager then
    cloneItemRemote.OnServerEvent:Connect(function(player, itemId)
        if not PlacementManager.CloneItem then
            print("Creating dummy CloneItem handler")
            Remotes.NotifyPlayer:FireClient(player, "Cloning not implemented yet")
            return
        end
        
        local success = PlacementManager:CloneItem(player, itemId)
        if success then
            Remotes.NotifyPlayer:FireClient(player, "Cloned " .. itemId)
        else
            Remotes.NotifyPlayer:FireClient(player, "Failed to clone " .. itemId)
        end
    end)
end

-- Player events
Players.PlayerAdded:Connect(function(player)
    print("Player joining:", player.Name)
    
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    
    -- Initialize player data
    if GameManager and GameManager.InitializePlayerData then
        GameManager:InitializePlayerData(player)
    end
    
    -- Initialize player currency
    if CurrencyManager and CurrencyManager.InitializePlayerCurrency then
        CurrencyManager:InitializePlayerCurrency(player)
    end
    
    -- Initialize player inventory
    if InventoryManager and InventoryManager.InitializePlayerInventory then
        InventoryManager:InitializePlayerInventory(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    print("Player leaving:", player.Name)
    
    -- Save player data before they leave
    if GameManager and GameManager.SavePlayerData then
        GameManager:SavePlayerData(player)
    end
    
    if InventoryManager and InventoryManager.SavePlayerInventory then
        InventoryManager:SavePlayerInventory(player)
    end
    
    if CurrencyManager and CurrencyManager.SavePlayerCurrency then
        CurrencyManager:SavePlayerCurrency(player)
    end
end)

print("Server initialization completed successfully")
