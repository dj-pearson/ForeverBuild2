-- RemoteEventManager.luau
-- Handles remote event setup and communication for placement system

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEventManager = {}
RemoteEventManager.__index = RemoteEventManager

function RemoteEventManager.new()
    local self = setmetatable({}, RemoteEventManager)
    
    -- Cache for remote events
    self.cachedRemotes = {}
    
    -- Event connections for cleanup
    self.eventConnections = {}
    
    -- Get or create remotes folder
    self.remotesFolder = self:_GetOrCreateRemotesFolder()
    
    return self
end

-- Get or create the remotes folder
function RemoteEventManager:_GetOrCreateRemotesFolder()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        if RunService:IsServer() then
            remotes = Instance.new("Folder")
            remotes.Name = "Remotes"
            remotes.Parent = ReplicatedStorage
        else
            -- Client should wait for server to create it
            remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        end
    end
    return remotes
end

-- Server: Setup all remote events
function RemoteEventManager:SetupRemoteEvents()
    if RunService:IsClient() then
        warn("RemoteEventManager: SetupRemoteEvents should only be called on server")
        return false
    end
    
    print("RemoteEventManager: Setting up remote events")
    
    local expectedEvents = {
        -- Placement events
        "PlaceItem",
        "ItemPlaced", 
        "RecallItem",
        "ItemRecalled",
        "UpdateItem",
        "ItemUpdated",
        "DeleteItem", 
        "ItemDeleted",
        
        -- Additional placement events
        "RequestCloneItem",
        "RequestDestroyItem",
        "CloneItem",
        "DestroyItem",
        "MoveItem",
        "ItemMoved",
        "RotateItem",
        "ItemRotated"
    }
    
    for _, eventName in ipairs(expectedEvents) do
        local event = self.remotesFolder:FindFirstChild(eventName)
        if not event then
            event = Instance.new("RemoteEvent")
            event.Name = eventName
            event.Parent = self.remotesFolder
            print("RemoteEventManager: Created remote event:", eventName)
        else
            print("RemoteEventManager: Using existing remote event:", eventName)
        end
        
        self.cachedRemotes[eventName] = event
    end
    
    print("RemoteEventManager: Remote events setup completed")
    return true
end

-- Client: Cache remote events for use
function RemoteEventManager:CacheRemoteEvents()
    if RunService:IsServer() then
        warn("RemoteEventManager: CacheRemoteEvents should only be called on client")
        return false
    end
    
    print("RemoteEventManager: Caching remote events --- MARKER ---")
    
    if not self.remotesFolder then
        warn("RemoteEventManager: Remotes folder not found")
        return false
    end
    
    print("RemoteEventManager: Remotes folder found immediately.")
    
    local expectedEvents = {
        "PlaceItem", "ItemPlaced", "RecallItem", "ItemRecalled",
        "UpdateItem", "ItemUpdated", "DeleteItem", "ItemDeleted",
        "RequestCloneItem", "RequestDestroyItem", "CloneItem", "DestroyItem",
        "MoveItem", "ItemMoved", "RotateItem", "ItemRotated"
    }
    
    for _, eventName in ipairs(expectedEvents) do
        local event = self.remotesFolder:FindFirstChild(eventName)
        if event then
            self.cachedRemotes[eventName] = event
            print("RemoteEventManager: Successfully cached remote event:", eventName)
        else
            -- Some events might not exist yet, wait for them
            local foundEvent = self.remotesFolder:WaitForChild(eventName, 5)
            if foundEvent then
                self.cachedRemotes[eventName] = foundEvent
                print("RemoteEventManager: Found event after wait:", eventName)
            else
                warn("RemoteEventManager: Failed to find remote event:", eventName)
            end
        end
    end
    
    print("RemoteEventManager: CacheRemoteEvents - All expected remote events appear to be cached.")
    return true
end

-- Connect server-side event handlers
function RemoteEventManager:ConnectServerHandlers(handlers)
    if RunService:IsClient() then
        warn("RemoteEventManager: ConnectServerHandlers should only be called on server")
        return false
    end
    
    if not handlers then
        warn("RemoteEventManager: No handlers provided")
        return false
    end
    
    -- Connect placement handlers
    if handlers.onPlaceItem and self.cachedRemotes.PlaceItem then
        local connection = self.cachedRemotes.PlaceItem.OnServerEvent:Connect(handlers.onPlaceItem)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected PlaceItem handler")
    end
    
    if handlers.onRecallItem and self.cachedRemotes.RecallItem then
        local connection = self.cachedRemotes.RecallItem.OnServerEvent:Connect(handlers.onRecallItem)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected RecallItem handler")
    end
    
    if handlers.onUpdateItem and self.cachedRemotes.UpdateItem then
        local connection = self.cachedRemotes.UpdateItem.OnServerEvent:Connect(handlers.onUpdateItem)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected UpdateItem handler")
    end
    
    if handlers.onDeleteItem and self.cachedRemotes.DeleteItem then
        local connection = self.cachedRemotes.DeleteItem.OnServerEvent:Connect(handlers.onDeleteItem)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected DeleteItem handler")
    end
    
    if handlers.onMoveItem and self.cachedRemotes.MoveItem then
        local connection = self.cachedRemotes.MoveItem.OnServerEvent:Connect(handlers.onMoveItem)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected MoveItem handler")
    end
    
    if handlers.onRotateItem and self.cachedRemotes.RotateItem then
        local connection = self.cachedRemotes.RotateItem.OnServerEvent:Connect(handlers.onRotateItem)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected RotateItem handler")
    end
    
    print("RemoteEventManager: Server handlers connected")
    return true
end

-- Connect client-side event handlers
function RemoteEventManager:ConnectClientHandlers(handlers)
    if RunService:IsServer() then
        warn("RemoteEventManager: ConnectClientHandlers should only be called on client")
        return false
    end
    
    if not handlers then
        warn("RemoteEventManager: No handlers provided")
        return false
    end
    
    -- Connect response handlers
    if handlers.onItemPlaced and self.cachedRemotes.ItemPlaced then
        local connection = self.cachedRemotes.ItemPlaced.OnClientEvent:Connect(handlers.onItemPlaced)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected ItemPlaced handler")
    end
    
    if handlers.onItemRecalled and self.cachedRemotes.ItemRecalled then
        local connection = self.cachedRemotes.ItemRecalled.OnClientEvent:Connect(handlers.onItemRecalled)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected ItemRecalled handler")
    end
    
    if handlers.onItemUpdated and self.cachedRemotes.ItemUpdated then
        local connection = self.cachedRemotes.ItemUpdated.OnClientEvent:Connect(handlers.onItemUpdated)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected ItemUpdated handler")
    end
    
    if handlers.onItemDeleted and self.cachedRemotes.ItemDeleted then
        local connection = self.cachedRemotes.ItemDeleted.OnClientEvent:Connect(handlers.onItemDeleted)
        table.insert(self.eventConnections, connection)
        print("RemoteEventManager: Connected ItemDeleted handler")
    end
    
    print("RemoteEventManager: Client handlers connected")
    return true
end

-- Fire a remote event from client to server
function RemoteEventManager:FireServer(eventName, ...)
    if RunService:IsServer() then
        warn("RemoteEventManager: FireServer should only be called on client")
        return false
    end
    
    local event = self.cachedRemotes[eventName]
    if not event then
        warn("RemoteEventManager: Remote event not found:", eventName)
        return false
    end
    
    event:FireServer(...)
    print("RemoteEventManager: Fired", eventName, "to server")
    return true
end

-- Fire a remote event from server to client(s)
function RemoteEventManager:FireClient(eventName, player, ...)
    if RunService:IsClient() then
        warn("RemoteEventManager: FireClient should only be called on server")
        return false
    end
    
    local event = self.cachedRemotes[eventName]
    if not event then
        warn("RemoteEventManager: Remote event not found:", eventName)
        return false
    end
    
    if player then
        event:FireClient(player, ...)
        print("RemoteEventManager: Fired", eventName, "to client:", player.Name)
    else
        event:FireAllClients(...)
        print("RemoteEventManager: Fired", eventName, "to all clients")
    end
    
    return true
end

-- Fire a remote event from server to all clients
function RemoteEventManager:FireAllClients(eventName, ...)
    return self:FireClient(eventName, nil, ...)
end

-- Get a cached remote event
function RemoteEventManager:GetRemote(eventName)
    return self.cachedRemotes[eventName]
end

-- Check if a remote event is available
function RemoteEventManager:HasRemote(eventName)
    return self.cachedRemotes[eventName] ~= nil
end

-- Disconnect all event connections
function RemoteEventManager:Disconnect()
    for _, connection in ipairs(self.eventConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    self.eventConnections = {}
    print("RemoteEventManager: Disconnected all event connections")
end

-- Get statistics about cached remotes
function RemoteEventManager:GetRemoteStatistics()
    local stats = {
        totalCached = 0,
        eventNames = {},
        missingEvents = {}
    }
    
    for eventName, event in pairs(self.cachedRemotes) do
        stats.totalCached = stats.totalCached + 1
        table.insert(stats.eventNames, eventName)
    end
    
    -- Check for expected events that might be missing
    local expectedEvents = {
        "PlaceItem", "ItemPlaced", "RecallItem", "ItemRecalled",
        "UpdateItem", "ItemUpdated", "DeleteItem", "ItemDeleted"
    }
    
    for _, eventName in ipairs(expectedEvents) do
        if not self.cachedRemotes[eventName] then
            table.insert(stats.missingEvents, eventName)
        end
    end
    
    return stats
end

-- Create default server handlers
function RemoteEventManager:CreateDefaultServerHandlers(placementCore)
    return {
        onPlaceItem = function(player, itemId, position, orientation)
            print("RemoteEventManager: PlaceItem received from", player.Name, "for", itemId)
            -- This would connect to PlacementCore's placement logic
            if placementCore and placementCore.HandlePlaceItemRequest then
                placementCore:HandlePlaceItemRequest(player, itemId, position, orientation)
            end
        end,
        
        onRecallItem = function(player, instanceId)
            print("RemoteEventManager: RecallItem received from", player.Name, "for", instanceId)
            if placementCore and placementCore.HandleRecallItemRequest then
                placementCore:HandleRecallItemRequest(player, instanceId)
            end
        end,
        
        onMoveItem = function(player, instanceId, newPosition)
            print("RemoteEventManager: MoveItem received from", player.Name, "for", instanceId)
            if placementCore and placementCore.HandleMoveItemRequest then
                placementCore:HandleMoveItemRequest(player, instanceId, newPosition)
            end
        end,
        
        onRotateItem = function(player, instanceId, rotation)
            print("RemoteEventManager: RotateItem received from", player.Name, "for", instanceId)
            if placementCore and placementCore.HandleRotateItemRequest then
                placementCore:HandleRotateItemRequest(player, instanceId, rotation)
            end
        end
    }
end

-- Create default client handlers
function RemoteEventManager:CreateDefaultClientHandlers(placementCore)
    return {
        onItemPlaced = function(success, message, itemData)
            print("RemoteEventManager: ItemPlaced response:", success, message)
            if placementCore and placementCore.OnItemPlaced then
                placementCore:OnItemPlaced(success, message, itemData)
            end
        end,
        
        onItemRecalled = function(success, message, instanceId)
            print("RemoteEventManager: ItemRecalled response:", success, message)
            if placementCore and placementCore.OnItemRecalled then
                placementCore:OnItemRecalled(success, message, instanceId)
            end
        end,
        
        onItemUpdated = function(instanceId, updateData)
            print("RemoteEventManager: ItemUpdated notification for:", instanceId)
            if placementCore and placementCore.OnItemUpdated then
                placementCore:OnItemUpdated(instanceId, updateData)
            end
        end
    }
end

return RemoteEventManager 