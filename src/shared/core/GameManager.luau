local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.shared.core.Constants)

-- Determine if we're on the server
local IS_SERVER = RunService:IsServer()

-- Create GameManager as proper OOP class
local GameManager = {}
GameManager.__index = GameManager

function GameManager.new()
    local self = setmetatable({}, GameManager)
    
    -- Shared properties for both server and client
    -- Use WaitForChild with a timeout to prevent infinite yield
    self.remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not self.remotes then
        warn("GameManager: Failed to find Remotes folder. Creating one.")
        if not ReplicatedStorage:FindFirstChild("Remotes") then
            local remotes = Instance.new("Folder")
            remotes.Name = "Remotes"
            remotes.Parent = ReplicatedStorage
            self.remotes = remotes
        else
            self.remotes = ReplicatedStorage.Remotes
        end
    end
    
    self.constants = Constants
    
    if IS_SERVER then
        self.playerData = {}
        
        -- Initialize DataStores on server
        local DataStoreService = game:GetService("DataStoreService")
        self.PlayerCurrencyStore = DataStoreService:GetDataStore("PlayerCurrency")
        self.PlayerInventoryStore = DataStoreService:GetDataStore("PlayerInventory")
        self.PlacedItemsStore = DataStoreService:GetDataStore("PlacedItems")
    end
    
    return self
end

-- Server-only functionality
if IS_SERVER then
    local Players = game:GetService("Players")
    
    -- Helper: skip DataStore in Studio
    function GameManager:canUseDataStore()
        return not RunService:IsStudio()
    end
    
    -- Initialize player data
    function GameManager:initializePlayerData(player)
        self.playerData[player.UserId] = {
            currency = self.constants.CURRENCY.STARTING_CURRENCY,
            inventory = {},
            placedItems = {}
        }
        
        if self:canUseDataStore() then
            local success, result = pcall(function()
                local currency = self.PlayerCurrencyStore:GetAsync(player.UserId)
                local inventory = self.PlayerInventoryStore:GetAsync(player.UserId)
                local placedItems = self.PlacedItemsStore:GetAsync(player.UserId)
                
                if currency then self.playerData[player.UserId].currency = currency end
                if inventory then self.playerData[player.UserId].inventory = inventory end
                if placedItems then self.playerData[player.UserId].placedItems = placedItems end
            end)
            
            if not success then 
                warn("Failed to load data for", player.Name, ":", result) 
            end
        end
    end
    
    -- Save player data
    function GameManager:savePlayerData(player)
        local userId = player.UserId
        if not self.playerData[userId] then return end
        
        if self:canUseDataStore() then
            local success, result = pcall(function()
                self.PlayerCurrencyStore:SetAsync(userId, self.playerData[userId].currency)
                self.PlayerInventoryStore:SetAsync(userId, self.playerData[userId].inventory)
                self.PlacedItemsStore:SetAsync(userId, self.playerData[userId].placedItems)
            end)
            
            if not success then 
                warn("Failed to save data for", player.Name, ":", result) 
            end
        end
    end
    
    -- Update client UI
    function GameManager:updateClientUI(player)
        if self.remotes.UpdateBalance then
            self.remotes.UpdateBalance:FireClient(player, self.playerData[player.UserId].currency)
        end
        -- You can add more remotes for inventory if needed
    end
    
    -- Initialize method
    function GameManager:Initialize()
        print("Initializing GameManager...")
        
        -- Player join/leave events
        Players.PlayerAdded:Connect(function(player)
            self:initializePlayerData(player)
            self:updateClientUI(player)
        end)
        
        Players.PlayerRemoving:Connect(function(player)
            self:savePlayerData(player)
            self.playerData[player.UserId] = nil
        end)
        
        print("GameManager initialized successfully")
    end
    
    -- Purchase logic
    function GameManager:HandleBuyItem(player, itemId)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        local itemData = self.constants.ITEMS[itemId]
        
        if not pdata or not itemData then
            return { success = false, message = "Invalid item or player." }
        end
        
        if pdata.currency < itemData.price then
            return { success = false, message = "Not enough currency." }
        end
        
        pdata.currency = pdata.currency - itemData.price
        pdata.inventory[itemId] = (pdata.inventory[itemId] or 0) + 1
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Purchase successful!" }
    end
    
    -- Placement logic
    function GameManager:HandlePlaceItem(player, itemId, position, rotation)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata or not pdata.inventory[itemId] or pdata.inventory[itemId] <= 0 then
            return { success = false, message = "You do not have this item in your inventory." }
        end
        
        -- Placement validation (stub: always true)
        local validPlacement = true -- TODO: add collision/grid checks
        if not validPlacement then
            return { success = false, message = "Invalid placement location." }
        end
        
        pdata.inventory[itemId] = pdata.inventory[itemId] - 1
        
        -- Add to placedItems
        local placedId = tostring(os.time()) .. tostring(math.random(1000,9999))
        pdata.placedItems[placedId] = { id = itemId, position = position, rotation = rotation }
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Item placed successfully!" }
    end
    
    -- Remove item logic
    function GameManager:HandleRemoveItem(player, itemId)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata or not pdata.placedItems[itemId] then
            return { success = false, message = "You cannot remove this item." }
        end
        
        pdata.placedItems[itemId] = nil
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Item removed successfully!" }
    end
    
    -- Move/Rotate logic
    function GameManager:HandleMoveItem(player, itemId, newPosition)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata or not pdata.placedItems[itemId] then
            return { success = false, message = "You cannot move this item." }
        end
        
        pdata.placedItems[itemId].position = newPosition
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Item moved successfully!" }
    end
    
    function GameManager:HandleRotateItem(player, itemId, newRotation)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata or not pdata.placedItems[itemId] then
            return { success = false, message = "You cannot rotate this item." }
        end
        
        pdata.placedItems[itemId].rotation = newRotation
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Item rotated successfully!" }
    end
    
    function GameManager:HandleChangeColor(player, itemId, newColor)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata or not pdata.placedItems[itemId] then
            return { success = false, message = "You cannot change the color of this item." }
        end
        
        pdata.placedItems[itemId].color = newColor
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Item color changed successfully!" }
    end
    
    function GameManager:GetPlayerInventory(player)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata then
            return { success = false, message = "Player data not found." }
        end
        
        return { success = true, inventory = pdata.inventory, currency = pdata.currency }
    end
    
    function GameManager:GetItemData(itemId)
        return self.constants.ITEMS[itemId]
    end
    
    function GameManager:GetItemPlacement(itemId)
        -- This would check all players' placed items for the specified ID
        -- For simplicity, we're just returning nil for now
        for userId, pdata in pairs(self.playerData) do
            if pdata.placedItems[itemId] then
                return pdata.placedItems[itemId]
            end
        end
        return nil
    end
    
    function GameManager:AddToInventory(player, itemId)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        
        if not pdata then
            return { success = false, message = "Player data not found." }
        end
        
        pdata.inventory[itemId] = (pdata.inventory[itemId] or 0) + 1
        self:savePlayerData(player)
        self:updateClientUI(player)
        
        return { success = true, message = "Item added to inventory!" }
    end
    
    function GameManager:ApplyItemEffect(player, itemId, placement)
        -- Implement item effect logic here
        -- For now, just return success
        return { success = true, message = "Item effect applied!" }
    end
    
    function GameManager:HandleCloneItem(player, itemId)
        local userId = player.UserId
        local pdata = self.playerData[userId]
        if not pdata or not pdata.placedItems[itemId] then
            return { success = false, message = "You cannot clone this item." }
        end
        local itemData = self.constants.ITEMS[pdata.placedItems[itemId].id]
        if not itemData then
            return { success = false, message = "Item data not found." }
        end
        if pdata.currency < itemData.price.INGAME then
            return { success = false, message = "Not enough currency to clone this item." }
        end
        pdata.currency = pdata.currency - itemData.price.INGAME
        pdata.inventory[itemData.id] = (pdata.inventory[itemData.id] or 0) + 1
        self:savePlayerData(player)
        self:updateClientUI(player)
        return { success = true, message = "Item cloned and added to inventory!" }
    end
end

-- Client-only functionality
if not IS_SERVER then
    function GameManager:Initialize()
        print("Initializing GameManager client...")
        -- Client initialization code here
        print("GameManager client initialized successfully")
    end
end

return GameManager