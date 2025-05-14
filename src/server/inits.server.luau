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
local GameManager, InventoryManager, CurrencyManager, PlacementManager

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

-- Setup remote event handlers
if Remotes:FindFirstChild("BuyItem") and CurrencyManager then
    Remotes.BuyItem.OnServerEvent:Connect(function(player, itemId)
        if CurrencyManager.ProcessPurchase then
            CurrencyManager:ProcessPurchase(player, itemId)
        else
            warn("CurrencyManager.ProcessPurchase method not found")
        end
    end)
end

if Remotes:FindFirstChild("GetInventory") and InventoryManager then
    Remotes.GetInventory.OnServerInvoke = function(player)
        if InventoryManager.GetPlayerInventory then
            return InventoryManager:GetPlayerInventory(player)
        else
            warn("InventoryManager.GetPlayerInventory method not found")
            return {}
        end
    end
end

if Remotes:FindFirstChild("PlaceItem") and PlacementManager then
    Remotes.PlaceItem.OnServerEvent:Connect(function(player, itemId, position, rotation)
        if PlacementManager.PlaceItem then
            PlacementManager:PlaceItem(player, itemId, position, rotation)
        else
            warn("PlacementManager.PlaceItem method not found")
        end
    end)
end

if Remotes:FindFirstChild("InteractWithItem") and GameManager then
    Remotes.InteractWithItem.OnServerEvent:Connect(function(player, itemId, action)
        if GameManager.HandleInteraction then
            GameManager:HandleInteraction(player, itemId, action)
        else
            warn("GameManager.HandleInteraction method not found")
        end
    end)
end

-- Player join/leave handling
Players.PlayerAdded:Connect(function(player)
    print("Player joined: " .. player.Name)
    
    -- Initialize player data
    if InventoryManager and InventoryManager.InitializePlayerData then
        InventoryManager:InitializePlayerData(player)
    end
    
    if CurrencyManager and CurrencyManager.InitializePlayerCurrency then
        CurrencyManager:InitializePlayerCurrency(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    print("Player leaving: " .. player.Name)
    
    -- Save player data
    if InventoryManager and InventoryManager.SavePlayerData then
        InventoryManager:SavePlayerData(player)
    end
    
    if CurrencyManager and CurrencyManager.SavePlayerCurrency then
        CurrencyManager:SavePlayerCurrency(player)
    end
end)

print("Server initialization completed successfully") 