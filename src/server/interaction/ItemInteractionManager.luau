-- ItemInteractionManager.luau
-- Server-side module for handling item interactions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Import shared modules with fallback
print("ItemInteractionManager: Attempting to require shared module")
local SharedModule
local Constants

local success, errorMessage = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared", 5))
    Constants = SharedModule.Constants
    return true
end)

if not success then
    warn("ItemInteractionManager: Failed to require SharedModule:", errorMessage)
    print("ItemInteractionManager: Creating minimal SharedModule fallback")
    -- Create minimal fallback for Constants
    Constants = {
        ITEM_ACTIONS = {
            clone = { cost = 100 },
            move = { cost = 10 },
            rotate = { cost = 5 },
            destroy = { cost = 20 }
        },
        CURRENCY = {
            INGAME = "Coins",
            ROBUX = "Robux",
            STARTING_CURRENCY = 100
        }
    }
    SharedModule = {
        Constants = Constants
    }
else
    print("ItemInteractionManager: Successfully required SharedModule")
end

local ItemInteractionManager = {}
ItemInteractionManager.__index = ItemInteractionManager

function ItemInteractionManager.new()
    local self = setmetatable({}, ItemInteractionManager)
    
    -- Remote events/functions
    self.remotes = {}
    
    -- Player data storage (would use DataStore in production)
    self.playerData = {}
    
    -- Item registry
    self.itemRegistry = {}
    
    return self
end

function ItemInteractionManager:Initialize()
    print("ItemInteractionManager initializing...")
    
    -- Cache remote events/functions
    self:SetupRemotes()
    
    -- Register event handlers
    self:RegisterHandlers()
    
    -- Register catalog items from workspace
    self:RegisterCatalogItems()
    
    -- Register placed world items
    self:RegisterWorldItems()
    
    print("ItemInteractionManager initialized successfully")
    return true
end

function ItemInteractionManager:SetupRemotes()
    -- Get the Remotes folder
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not remotesFolder then
        warn("Remotes folder not found - creating one")
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Create remote functions if they don't exist
    self:EnsureRemoteFunction(remotesFolder, "GetItemCatalog")
    self:EnsureRemoteFunction(remotesFolder, "GetItemData")
    self:EnsureRemoteFunction(remotesFolder, "GetAvailableInteractions")
    self:EnsureRemoteFunction(remotesFolder, "IsItemAffordable")
    
    -- Create remote events if they don't exist
    self:EnsureRemoteEvent(remotesFolder, "PurchaseItem")
    self:EnsureRemoteEvent(remotesFolder, "PlaceItem")
    self:EnsureRemoteEvent(remotesFolder, "MoveItem")
    self:EnsureRemoteEvent(remotesFolder, "RotateItem")
    self:EnsureRemoteEvent(remotesFolder, "CloneItem")
    self:EnsureRemoteEvent(remotesFolder, "DestroyItem")
    self:EnsureRemoteEvent(remotesFolder, "NotifyPlayer")
    
    -- Cache remote functions
    self:CacheRemoteFunction(remotesFolder, "GetItemCatalog")
    self:CacheRemoteFunction(remotesFolder, "GetItemData") 
    self:CacheRemoteFunction(remotesFolder, "GetAvailableInteractions")
    self:CacheRemoteFunction(remotesFolder, "IsItemAffordable")
    
    -- Cache remote events
    self:CacheRemoteEvent(remotesFolder, "PurchaseItem")
    self:CacheRemoteEvent(remotesFolder, "PlaceItem")
    self:CacheRemoteEvent(remotesFolder, "MoveItem")
    self:CacheRemoteEvent(remotesFolder, "RotateItem")
    self:CacheRemoteEvent(remotesFolder, "CloneItem")
    self:CacheRemoteEvent(remotesFolder, "DestroyItem")
    self:CacheRemoteEvent(remotesFolder, "NotifyPlayer")
end

function ItemInteractionManager:EnsureRemoteFunction(parent, name)
    if not parent:FindFirstChild(name) then
        local remoteFunc = Instance.new("RemoteFunction")
        remoteFunc.Name = name
        remoteFunc.Parent = parent
        print("Created RemoteFunction: " .. name)
    end
end

function ItemInteractionManager:EnsureRemoteEvent(parent, name)
    if not parent:FindFirstChild(name) then
        local remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = name
        remoteEvent.Parent = parent
        print("Created RemoteEvent: " .. name)
    end
end

function ItemInteractionManager:CacheRemoteFunction(parent, name)
    local remoteFunc = parent:FindFirstChild(name)
    if remoteFunc and remoteFunc:IsA("RemoteFunction") then
        self.remotes[name] = remoteFunc
    else
        warn("Remote function '" .. name .. "' not found or not a RemoteFunction")
    end
end

function ItemInteractionManager:CacheRemoteEvent(parent, name)
    local remoteEvent = parent:FindFirstChild(name)
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        self.remotes[name] = remoteEvent
    else
        warn("Remote event '" .. name .. "' not found or not a RemoteEvent")
    end
end

function ItemInteractionManager:RegisterHandlers()
    -- Handle remote function calls
    if self.remotes.GetItemCatalog then
        self.remotes.GetItemCatalog.OnServerInvoke = function(player)
            return self:GetItemCatalog()
        end
    end
    
    if self.remotes.GetItemData then
        self.remotes.GetItemData.OnServerInvoke = function(player, itemId)
            return self:GetItemData(itemId)
        end
    end
    
    if self.remotes.GetAvailableInteractions then
        self.remotes.GetAvailableInteractions.OnServerInvoke = function(player, itemId)
            return self:GetAvailableInteractions(player, itemId)
        end
    end
    
    if self.remotes.IsItemAffordable then
        self.remotes.IsItemAffordable.OnServerInvoke = function(player, itemId, actionType)
            return self:IsItemAffordable(player, itemId, actionType)
        end
    end
    
    -- Handle remote events
    if self.remotes.PurchaseItem then
        self.remotes.PurchaseItem.OnServerEvent:Connect(function(player, itemId, currencyType)
            self:PurchaseItem(player, itemId, currencyType)
        end)
    end
    
    if self.remotes.PlaceItem then
        self.remotes.PlaceItem.OnServerEvent:Connect(function(player, itemId, position, rotation)
            self:PlaceItem(player, itemId, position, rotation)
        end)
    end
    
    if self.remotes.MoveItem then
        self.remotes.MoveItem.OnServerEvent:Connect(function(player, itemId, newPosition)
            self:MoveItem(player, itemId, newPosition)
        end)
    end
    
    if self.remotes.RotateItem then
        self.remotes.RotateItem.OnServerEvent:Connect(function(player, itemId, newRotation)
            self:RotateItem(player, itemId, newRotation)
        end)
    end
    
    if self.remotes.CloneItem then
        self.remotes.CloneItem.OnServerEvent:Connect(function(player, instanceId, clientSentCost)
            self:CloneItem(player, instanceId, clientSentCost)
        end)
    end
    
    if self.remotes.DestroyItem then
        self.remotes.DestroyItem.OnServerEvent:Connect(function(player, instanceId, clientSentCost)
            self:DestroyItem(player, instanceId, clientSentCost)
        end)
    end
end

function ItemInteractionManager:RegisterCatalogItems()
    -- Find and register all catalog items from multiple locations (recursively)
    local count = 0
    
    -- Recursive function to register items from a folder
    local function registerCatalogItemsRecursive(parent, path, source)
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Model") or item:IsA("Part") then
                local itemId = item:GetAttribute("ItemID") or item.Name
                self.itemRegistry[itemId] = {
                    instance = item,
                    name = item.Name,
                    type = "catalog",
                    purchasable = true,
                    path = path and (path .. "/" .. item.Name) or item.Name,  -- Store folder path for organization
                    source = source  -- Track where the item was found
                }
                count = count + 1
                print("ItemInteractionManager: Registered catalog item:", itemId, "at path:", path and (path .. "/" .. item.Name) or item.Name, "from", source)
            elseif item:IsA("Folder") then
                -- Recursively search folders
                local newPath = path and (path .. "/" .. item.Name) or item.Name
                registerCatalogItemsRecursive(item, newPath, source)
            end
        end
    end
    
    -- 1. Check Workspace.Items first
    local workspaceItems = workspace:FindFirstChild("Items")
    if workspaceItems then
        print("ItemInteractionManager: Scanning Workspace.Items for catalog items...")
        registerCatalogItemsRecursive(workspaceItems, nil, "Workspace.Items")
    else
        print("ItemInteractionManager: Workspace.Items folder not found")
    end
    
    -- 2. Check ServerStorage.Items (where glow items likely are)
    if game:GetService("RunService"):IsServer() then
        local serverStorageItems = game:GetService("ServerStorage"):FindFirstChild("Items")
        if serverStorageItems then
            print("ItemInteractionManager: Scanning ServerStorage.Items for catalog items...")
            registerCatalogItemsRecursive(serverStorageItems, nil, "ServerStorage.Items")
        else
            print("ItemInteractionManager: ServerStorage.Items folder not found")
        end
    end
    
    -- 3. Check ReplicatedStorage.Items as fallback
    local replicatedStorageItems = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
    if replicatedStorageItems then
        print("ItemInteractionManager: Scanning ReplicatedStorage.Items for catalog items...")
        registerCatalogItemsRecursive(replicatedStorageItems, nil, "ReplicatedStorage.Items")
    end
    
    print("Registered " .. count .. " catalog items (including items in subfolders from multiple sources)")
end

function ItemInteractionManager:RegisterWorldItems()
    -- Find and register all placed world items
    local worldItems = workspace:FindFirstChild("World_Items")
    if not worldItems then
        warn("World_Items folder not found in workspace")
        return
    end
    
    -- Register all placed items
    local count = 0
    local function registerItemsRecursive(parent)
        for _, item in ipairs(parent:GetChildren()) do
            if (item:IsA("Model") or item:IsA("Part")) and not item:GetAttribute("Registered") then
                local itemId = item:GetAttribute("ItemID") or HttpService:GenerateGUID(false)
                item:SetAttribute("ItemID", itemId)
                item:SetAttribute("Registered", true)
                
                self.itemRegistry[itemId] = {
                    instance = item,
                    name = item.Name,
                    type = "world",
                    owner = item:GetAttribute("Owner") or 0, -- Default to nobody
                    canMove = true,
                    canRotate = true,
                    canClone = true,
                    canDestroy = true
                }
                count = count + 1
            end
            
            if #item:GetChildren() > 0 then
                registerItemsRecursive(item)
            end
        end
    end
    
    registerItemsRecursive(worldItems)
    print("Registered " .. count .. " world items")
end

-- Get catalog items for UI
function ItemInteractionManager:GetItemCatalog()
    local catalog = {}
    
    for id, item in pairs(self.itemRegistry) do
        if item.type == "catalog" and item.purchasable then
            table.insert(catalog, {
                id = id,
                name = item.name,
                description = item.instance:GetAttribute("Description") or "A buildable item",
                price = item.instance:GetAttribute("Price") or 10,
                currencyType = item.instance:GetAttribute("CurrencyType") or Constants.CURRENCY.INGAME
            })
        end
    end
    
    return catalog
end

-- Get detailed data for a specific item
function ItemInteractionManager:GetItemData(itemId)
    if not self.itemRegistry[itemId] then
        return {
            success = false,
            message = "Item not found"
        }
    end
    
    local item = self.itemRegistry[itemId]
    
    return {
        success = true,
        id = itemId,
        name = item.name,
        description = item.instance:GetAttribute("Description") or "A buildable item",
        price = item.instance:GetAttribute("Price") or 10,
        currencyType = item.instance:GetAttribute("CurrencyType") or Constants.CURRENCY.INGAME,
        type = item.type
    }
end

-- Get available interactions for an item
function ItemInteractionManager:GetAvailableInteractions(player, itemId)
    if not self.itemRegistry[itemId] then
        return {
            success = false,
            message = "Item not found"
        }
    end
    
    local item = self.itemRegistry[itemId]
    local interactions = {}
    
    if item.type == "catalog" then
        -- Catalog items can be purchased
        table.insert(interactions, "purchase")
        table.insert(interactions, "examine")
    else
        -- World items can be modified
        if item.canMove then table.insert(interactions, "move") end
        if item.canRotate then table.insert(interactions, "rotate") end
        if item.canClone then table.insert(interactions, "clone") end
        if item.canDestroy then table.insert(interactions, "destroy") end
    end
    
    return {
        success = true,
        interactions = interactions
    }
end

-- Check if player can afford an item or action
function ItemInteractionManager:IsItemAffordable(player, itemId, actionType)
    -- Get player data
    local playerData = self:GetPlayerData(player)
    
    if actionType == "purchase" then
        -- Check if player can afford to purchase the item
        if not self.itemRegistry[itemId] then
            return {
                success = false,
                message = "Item not found"
            }
        end
        
        local item = self.itemRegistry[itemId]
        local price = item.instance:GetAttribute("Price") or 10
        local currencyType = item.instance:GetAttribute("CurrencyType") or Constants.CURRENCY.INGAME
        
        if currencyType == Constants.CURRENCY.INGAME then
            -- Check in-game currency
            return {
                success = playerData.currency >= price,
                message = playerData.currency >= price and "You can afford this item" or "Not enough " .. Constants.CURRENCY.INGAME,
                currency = playerData.currency,
                price = price
            }
        else
            -- Robux purchases are handled by MarketplaceService
            return {
                success = true,
                message = "Robux purchases are handled by MarketplaceService",
                price = price
            }
        end
    else
        -- Check if player can afford to perform the action
        local actionCost = Constants.ITEM_ACTIONS[actionType] and Constants.ITEM_ACTIONS[actionType].cost or 0
        
        return {
            success = playerData.currency >= actionCost,
            message = playerData.currency >= actionCost and "You can afford this action" or "Not enough " .. Constants.CURRENCY.INGAME,
            currency = playerData.currency,
            price = actionCost
        }
    end
end

-- Purchase an item
function ItemInteractionManager:PurchaseItem(player, itemId, currencyType)
    -- Get player data
    local playerData = self:GetPlayerData(player)
    
    if not self.itemRegistry[itemId] then
        self:NotifyPlayer(player, "Item not found")
        return
    end
    
    local item = self.itemRegistry[itemId]
    local price = item.instance:GetAttribute("Price") or 10
    
    if currencyType == Constants.CURRENCY.INGAME then
        -- Check if player can afford the item
        if playerData.currency < price then
            self:NotifyPlayer(player, "Not enough " .. Constants.CURRENCY.INGAME)
            return
        end
        
        -- Deduct the cost
        playerData.currency = playerData.currency - price
        
        -- Clone the item to the player's inventory (or handle as needed)
        -- In a real game, you'd add this to a player's DataStore-backed inventory
        
        self:NotifyPlayer(player, "Successfully purchased " .. item.name)
    else
        -- For Robux purchases, we'd use MarketplaceService
        -- This would be implemented elsewhere
        self:NotifyPlayer(player, "Robux purchases are handled separately")
    end
end

-- Get player data
function ItemInteractionManager:GetPlayerData(player)
    if not self.playerData[player.UserId] then
        -- Initialize player data
        self.playerData[player.UserId] = {
            currency = Constants.CURRENCY.STARTING_CURRENCY,
            inventory = {}
        }
    end
    
    return self.playerData[player.UserId]
end

-- Notify player
function ItemInteractionManager:NotifyPlayer(player, message)
    if self.remotes.NotifyPlayer then
        self.remotes.NotifyPlayer:FireClient(player, message)
    else
        warn("NotifyPlayer remote event not found")
    end
end

-- World item interactions
function ItemInteractionManager:MoveItem(player, itemId, newPosition)
    self:ProcessItemAction(player, itemId, "move", function(item)
        item.instance:SetPrimaryPartCFrame(CFrame.new(newPosition))
        return true
    end)
end

function ItemInteractionManager:RotateItem(player, itemId, newRotation)
    self:ProcessItemAction(player, itemId, "rotate", function(item)
        local currentPos = item.instance:GetPrimaryPartCFrame().Position
        item.instance:SetPrimaryPartCFrame(CFrame.new(currentPos) * CFrame.Angles(0, math.rad(newRotation), 0))
        return true
    end)
end

function ItemInteractionManager:CloneItem(player, instanceId, clientSentCost)
    self:ProcessItemAction(player, instanceId, "clone", clientSentCost, function(item)
        local clone = item.instance:Clone()
        clone:SetAttribute("ItemID", HttpService:GenerateGUID(false))
        clone:SetAttribute("Owner", player.UserId)
        clone.Parent = workspace.World_Items
        
        -- Register the new item
        self.itemRegistry[clone:GetAttribute("ItemID")] = {
            instance = clone,
            name = clone.Name,
            type = "world",
            owner = player.UserId,
            canMove = true,
            canRotate = true,
            canClone = true,
            canDestroy = true
        }
        
        return true
    end)
end

function ItemInteractionManager:DestroyItem(player, instanceId, clientSentCost)
    self:ProcessItemAction(player, instanceId, "destroy", clientSentCost, function(item)
        -- Remove from registry
        self.itemRegistry[instanceId] = nil -- Ensure we use instanceId here
        
        -- Destroy the instance
        item.instance:Destroy()
        return true
    end)
end

function ItemInteractionManager:ProcessItemAction(player, instanceId, actionType, clientSentCost, actionFunc)
    -- Get player data
    local playerData = self:GetPlayerData(player)
    
    if not self.itemRegistry[instanceId] then
        self:NotifyPlayer(player, "Item not found")
        return
    end
    
    local item = self.itemRegistry[instanceId]
    
    -- Check if player can perform this action on this item
    if item.type ~= "world" then
        self:NotifyPlayer(player, "This action can only be performed on world items")
        return
    end
    
    -- Check if action is allowed for this item
    local actionProperty = "can" .. actionType:sub(1,1):upper() .. actionType:sub(2)
    if not item[actionProperty] then
        self:NotifyPlayer(player, "This item cannot be " .. actionType .. "d")
        return
    end
    
    -- Check if player owns the item or is an admin
    if item.owner ~= player.UserId and not self:IsAdmin(player) then
        self:NotifyPlayer(player, "You do not own this item")
        return
    end
    
    -- Validate clientSentCost against server-defined cost
    local serverDefinedCost = Constants.ITEM_ACTIONS[actionType] and Constants.ITEM_ACTIONS[actionType].cost or 0
    if clientSentCost ~= serverDefinedCost then
        local message = string.format("Cost mismatch for %s. Client proposed %d, server expects %d.", actionType, clientSentCost, serverDefinedCost)
        self:NotifyPlayer(player, message)
        warn(string.format("Player %s (%d): %s for item %s.", player.Name, player.UserId, message, instanceId))
        return -- Stop processing if costs don't align
    end
    
    -- Check if player can afford the action (using server-defined cost)
    if playerData.currency < serverDefinedCost then
        self:NotifyPlayer(player, "Not enough " .. Constants.CURRENCY.INGAME .. string.format(" (Need %d, Have %d)", serverDefinedCost, playerData.currency))
        return
    end
    
    -- Perform the action
    local success = actionFunc(item)
    
    if success then
        -- Deduct the server-defined cost
        playerData.currency = playerData.currency - serverDefinedCost
        self:NotifyPlayer(player, "Successfully " .. actionType .. "d the item")
    else
        self:NotifyPlayer(player, "Failed to " .. actionType .. " the item")
    end
end

-- Check if player is an admin
function ItemInteractionManager:IsAdmin(player)
    -- Check if Constants.ADMIN_IDS exists and contains the player's UserId
    if Constants.ADMIN_IDS then
        for _, adminId in ipairs(Constants.ADMIN_IDS) do
            if adminId == player.UserId then
                return true
            end
        end
    end
    
    return false
end

return ItemInteractionManager