-- ItemPurchaseHandler.lua
-- Handles server-side processing of item purchases

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

-- Setup data store for player data
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- Import shared modules with fallback
print("ItemPurchaseHandler: Attempting to require shared module")
local SharedModule
local Constants

local success, errorMessage = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared", 5))
    Constants = SharedModule.Constants
    return true
end)

if not success then
    warn("ItemPurchaseHandler: Failed to require SharedModule:", errorMessage)
    print("ItemPurchaseHandler: Creating minimal SharedModule fallback")
    -- Create minimal fallback for Constants
    Constants = {
        CURRENCY = {
            INGAME = "Coins",
            ROBUX = "Robux",
            STARTING_CURRENCY = 100,
            PRODUCTS = {
                {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 3285357280}
            }
        },
        TIER_PRODUCTS = {
            BASIC = {id = "tier_basic", assetId = 3285357280, robux = 5}
        }
    }
    SharedModule = {
        Constants = Constants
    }
else
    print("ItemPurchaseHandler: Successfully required SharedModule")
end

-- Remote events
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseItemEvent = remotes:FindFirstChild("PurchaseItem") 
local addToInventoryEvent = remotes:FindFirstChild("AddToInventory")
local updateBalanceEvent = remotes:FindFirstChild("UpdateBalance")

-- Create remote events if they don't exist
if not purchaseItemEvent then
    purchaseItemEvent = Instance.new("RemoteEvent")
    purchaseItemEvent.Name = "PurchaseItem"
    purchaseItemEvent.Parent = remotes
end

if not addToInventoryEvent then
    addToInventoryEvent = Instance.new("RemoteEvent")
    addToInventoryEvent.Name = "AddToInventory"
    addToInventoryEvent.Parent = remotes
end

if not updateBalanceEvent then
    updateBalanceEvent = Instance.new("RemoteEvent")
    updateBalanceEvent.Name = "UpdateBalance"
    updateBalanceEvent.Parent = remotes
end

-- Debug settings
local DEBUG_MODE = true
local function debugLog(...)
    if DEBUG_MODE then
        print("[ItemPurchaseHandler]", ...)
    end
end

-- Module table
local ItemPurchaseHandler = {}

-- Initialize player data
local playerData = {}

-- Function to get or create player data
function ItemPurchaseHandler:GetPlayerData(player)
    debugLog("GetPlayerData called for player:", player.Name, "UserId:", player.UserId)
    
    -- Initialize data if it doesn't exist yet
    if not playerData[player.UserId] then
        debugLog("Creating new player data for:", player.Name)
        -- Initialize data with defaults
        playerData[player.UserId] = {
            currency = Constants.CURRENCY.STARTING_CURRENCY,
            inventory = {}
        }
        
        -- Try to load from DataStore
        local success, result = pcall(function()
            return playerDataStore:GetAsync("Player_" .. player.UserId)
        end)
        
        if success and result then
            -- Use loaded data
            debugLog("Loaded player data from DataStore for:", player.Name)
            playerData[player.UserId] = result
        else
            -- Use default data
            print("Using default player data for " .. player.Name)
        end
        
        -- Ensure the inventory is a table even if loaded data was corrupted
        if type(playerData[player.UserId].inventory) ~= "table" then
            debugLog("Resetting corrupted inventory for:", player.Name)
            playerData[player.UserId].inventory = {}
        end
    end
    
    -- Debug output
    local pd = playerData[player.UserId]
    debugLog("Returning player data for:", player.Name, "Currency:", pd.currency, "Inventory items:", #pd.inventory)
    
    return playerData[player.UserId]
end

-- Save player data
function ItemPurchaseHandler:SavePlayerData(player)
    debugLog("SavePlayerData called for:", player.Name)
    local data = playerData[player.UserId]
    if not data then
        debugLog("No data to save for:", player.Name)
        return
    end
    
    -- Debug the data before saving
    debugLog("Saving data for:", player.Name, "Currency:", data.currency, "Inventory count:", #data.inventory)
    
    local success, errorMessage = pcall(function()
        playerDataStore:SetAsync("Player_" .. player.UserId, data)
    end)
    
    if success then
        print("Saved player data for " .. player.Name)
    else
        warn("Failed to save player data for " .. player.Name .. ": " .. errorMessage)
    end
end

-- Update client UI with current balance
function ItemPurchaseHandler:UpdateClientBalance(player)
    local data = self:GetPlayerData(player)
    
    -- Fire event to update client UI
    if updateBalanceEvent then
        updateBalanceEvent:FireClient(player, data.currency)
        print("💰 CURRENCY UPDATE for " .. player.Name .. ": " .. data.currency .. " coins")
    else
        warn("UpdateBalanceEvent is nil, cannot update currency UI")
    end
end

-- Process in-game currency purchase
function ItemPurchaseHandler:ProcessCurrencyPurchase(player, item, price)
    local data = self:GetPlayerData(player)
    
    print("ProcessCurrencyPurchase - Player:", player.Name, "Item:", item.Name, "Price:", price, "Current Currency:", data.currency)
    
    -- Check if player is an admin for free purchases
    if self:IsAdmin(player) then
        print("Admin detected: Free purchase granted for " .. player.Name)
        
        -- Add the item to the player's inventory without charging
        self:AddItemToInventory(player, item)
        
        -- Save the data
        self:SavePlayerData(player)
        
        return true, "Admin free purchase of " .. item.Name
    end
    
    -- Check if player can afford the item
    if data.currency < price then
        print("Purchase failed: Not enough currency. Has:", data.currency, "Needs:", price)
        return false, "Not enough " .. Constants.CURRENCY.INGAME .. " to purchase this item."
    end
    
    -- Deduct the cost
    data.currency = data.currency - price
    print("Purchase successful! New currency balance:", data.currency)
    
    -- Add the item to the player's inventory
    self:AddItemToInventory(player, item)
    
    -- Re-log the player data to verify inventory was added
    debugLog("After purchase - Player:", player.Name, "Currency:", data.currency, "Inventory items:", #data.inventory)
    
    -- Save the data after purchase
    self:SavePlayerData(player)
    
    -- Update client UI with new balance
    self:UpdateClientBalance(player)
    
    return true, "Successfully purchased " .. item.Name .. " for " .. price .. " " .. Constants.CURRENCY.INGAME
end

-- Process Robux purchase (Developer Product)
function ItemPurchaseHandler:ProcessRobuxPurchase(player, item, productId)
    -- This would be handled through MarketplaceService.ProcessReceipt
    -- For now, we'll simulate this process
    
    -- Check if player is an admin for free purchases
    if self:IsAdmin(player) then
        print("Admin detected: Free Robux purchase granted for " .. player.Name)
        
        -- Add the item to the player's inventory without charging
        self:AddItemToInventory(player, item)
        
        -- Save the data
        self:SavePlayerData(player)
        
        return true, "Admin free purchase of " .. item.Name
    end
    
    -- Add the item to the player's inventory
    self:AddItemToInventory(player, item)
    
    -- Save the data after purchase
    self:SavePlayerData(player)
    
    return true, "Successfully purchased " .. item.Name .. " with Robux"
end

-- Check if player is an admin
function ItemPurchaseHandler:IsAdmin(player)
    -- Check if Constants.ADMIN_IDS exists and contains the player's UserId
    if Constants.ADMIN_IDS then
        for _, adminId in ipairs(Constants.ADMIN_IDS) do
            if player and player.UserId and adminId == player.UserId then
                return true
            end
        end
    end
    
    return false
end

-- Add an item to player's inventory
function ItemPurchaseHandler:AddItemToInventory(player, item)
    local data = self:GetPlayerData(player)
    
    -- Create an inventory item entry
    local inventoryItem = {
        name = item.Name,
        id = item:GetAttribute("ItemID") or "item_" .. tostring(#data.inventory + 1),
        tier = self:GetItemTier(item.Name)
    }
    
    -- Add to inventory
    table.insert(data.inventory, inventoryItem)
    
    -- Debug log the inventory state after adding item
    debugLog("INVENTORY UPDATE - Added item:", inventoryItem.name)
    debugLog("INVENTORY UPDATE - New count:", #data.inventory)
    
    -- Notify client
    addToInventoryEvent:FireClient(player, inventoryItem)
    
    debugLog("Added " .. item.Name .. " to " .. player.Name .. "'s inventory")
    
    -- Remove the item from the workspace if needed
    -- item:Destroy()  -- Uncomment if you want to remove purchased items
end

-- Get item tier based on item name or folder
function ItemPurchaseHandler:GetItemTier(itemName)
    -- Same logic as client-side to determine tier
    local cleanName = itemName:gsub("[_]", ""):lower()
    
    if cleanName:find("basic") then
        return "BASIC"
    elseif cleanName:find("level1") then
        return "LEVEL_1"
    elseif cleanName:find("level2") then
        return "LEVEL_2"
    elseif cleanName:find("secondary") then
        return "SECONDARY"
    elseif cleanName:find("rare") and cleanName:find("drop") then
        return "RARE_DROP"
    elseif cleanName:find("rare") then
        return "RARE"
    elseif cleanName:find("exclusive") then
        return "EXCLUSIVE"
    elseif cleanName:find("weapon") then
        return "WEAPONS"
    elseif cleanName:find("free") then
        return "FREE_ITEMS"
    end
    
    return "BASIC"
end

-- Handle MarketplaceService.ProcessReceipt
local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player likely left the game
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Find the corresponding product
    local productId = receiptInfo.ProductId
    local matchingTier = nil
    
    -- Ensure Constants.TIER_PRODUCTS exists
    if not Constants.TIER_PRODUCTS then
        warn("Constants.TIER_PRODUCTS is nil in processReceipt, creating fallback")
        Constants.TIER_PRODUCTS = {
            BASIC = {id = "tier_basic", assetId = 3284930147, robux = 5},
            LEVEL_1 = {id = "tier_level1", assetId = 3284930700, robux = 10},
            LEVEL_2 = {id = "tier_level2", assetId = 3284930700, robux = 25}
        }
    end
    
    -- Find which tier this product belongs to
    for tier, productInfo in pairs(Constants.TIER_PRODUCTS) do
        if productInfo.assetId == productId then
            matchingTier = tier
            break
        end
    end
    
    if matchingTier then
        -- Note: In a real implementation, you would need to find which specific item
        -- the player was trying to purchase with Robux, using a queue system or similar
        debugLog("Product purchased for tier:", matchingTier)
        
        -- Give player some currency as a temporary implementation
        local data = ItemPurchaseHandler:GetPlayerData(player)
        local tierValue = 0
        
        -- Calculate reward based on tier
        if matchingTier == "BASIC" then
            tierValue = 50
        elseif matchingTier == "LEVEL_1" then
            tierValue = 100
        elseif matchingTier == "LEVEL_2" then
            tierValue = 250
        elseif matchingTier == "RARE" then
            tierValue = 500
        else
            tierValue = 100 -- Default reward
        end
        
        data.currency = data.currency + tierValue
        debugLog("Added", tierValue, "coins to", player.Name, "for tier product:", matchingTier)
        
        -- Save player data after purchase
        ItemPurchaseHandler:SavePlayerData(player)
        
        -- Update client UI with new balance
        ItemPurchaseHandler:UpdateClientBalance(player)
        
        -- Return that the purchase was successful
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- Otherwise try to match with currency products
    if not Constants.CURRENCY.PRODUCTS then
        Constants.CURRENCY.PRODUCTS = {
            {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 1472807192}
        }
    end
    
    for _, product in ipairs(Constants.CURRENCY.PRODUCTS) do
        if product.assetId == productId then
            -- Add coins to player account
            local data = ItemPurchaseHandler:GetPlayerData(player)
            data.currency = data.currency + (product.coins + (product.bonusCoins or 0))
            
            debugLog("Added", product.coins + (product.bonusCoins or 0), "coins to", player.Name)
            
            -- Save player data after purchase
            ItemPurchaseHandler:SavePlayerData(player)
            
            -- Update client UI with new balance
            ItemPurchaseHandler:UpdateClientBalance(player)
            
            -- Return that the purchase was successful
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    
    -- Product not recognized
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Get player inventory
function ItemPurchaseHandler:GetPlayerInventory(player)
    debugLog("GetPlayerInventory called for:", player.Name)
    
    local data = self:GetPlayerData(player)
    
    if not data then
        debugLog("No data found for player:", player.Name)
        return {
            success = false,
            message = "Could not load player data",
            inventory = {},
            currency = 0
        }
    end
    
    -- Debug output to help diagnose issues
    debugLog("Raw player data:", data)
    debugLog("Player UserId:", player.UserId)
    debugLog("Inventory count:", #data.inventory)
    debugLog("Currency:", data.currency)
    
    -- Make sure inventory is a table
    if type(data.inventory) ~= "table" then
        debugLog("Inventory is not a table, creating empty inventory")
        data.inventory = {}
    end
    
    -- Validate and fix inventory items if needed
    local validatedInventory = {}
    for i, item in ipairs(data.inventory) do
        -- Check if the item has the required fields
        if type(item) == "table" and item.name then
            -- Make sure all required fields exist
            local validItem = {
                name = item.name,
                id = item.id or ("item_" .. i),
                tier = item.tier or self:GetItemTier(item.name)
            }
            table.insert(validatedInventory, validItem)
            debugLog("Validated inventory item:", validItem.name, "ID:", validItem.id, "Tier:", validItem.tier)
        else
            debugLog("Skipping invalid inventory item at index", i, ":", item)
        end
    end
    
    print("Getting inventory for " .. player.Name .. ": " .. #validatedInventory .. " items, " .. data.currency .. " currency")
    
    return {
        success = true,
        inventory = validatedInventory,
        currency = data.currency
    }
end

-- Initialize the handler
function ItemPurchaseHandler:Initialize()
    -- Set up MarketplaceService callback
    MarketplaceService.ProcessReceipt = processReceipt
    
    -- Connect player join event to send initial balance
    Players.PlayerAdded:Connect(function(player)
        -- Load player data
        local data = self:GetPlayerData(player)
        
        -- Send initial balance to client
        self:UpdateClientBalance(player)
        
        print("Sent initial balance to " .. player.Name .. ": " .. data.currency)
    end)
    
    -- Connect player leave event to save data
    Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerData(player)
    end)
    
    -- Handle purchase events from clients
    purchaseItemEvent.OnServerEvent:Connect(function(player, item, currencyType, price)
        if not player or not item then return end
        
        local success, message
        
        -- Process the purchase based on currency type
        if currencyType == "INGAME" then
            success, message = self:ProcessCurrencyPurchase(player, item, price)
        elseif currencyType == "ROBUX" then
            -- This would normally go through MarketplaceService.ProcessReceipt
            -- But we can also handle it here for developer products
            local tier = self:GetItemTier(item.Name)
            local productInfo = Constants.TIER_PRODUCTS[tier]
            
            if productInfo then
                success, message = self:ProcessRobuxPurchase(player, item, productInfo.assetId)
            else
                success, message = false, "No product information found for this item."
            end
        else
            success, message = false, "Invalid currency type"
        end
        
        -- Notify the client of the result
        purchaseItemEvent:FireClient(player, success, message, {
            name = item.Name,
            price = price,
            currencyType = currencyType
        })
    end)
    
    debugLog("ItemPurchaseHandler initialized")
end

return ItemPurchaseHandler
