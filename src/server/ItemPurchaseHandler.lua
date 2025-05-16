-- ItemPurchaseHandler.lua
-- Handles server-side processing of item purchases

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

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

-- Debug settings
local DEBUG_MODE = false
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
    if not playerData[player.UserId] then
        -- Initialize data
        playerData[player.UserId] = {
            currency = Constants.CURRENCY.STARTING_CURRENCY,
            inventory = {}
        }
        
        -- You would typically load this from DataStore in a real implementation
    end
    
    return playerData[player.UserId]
end

-- Process in-game currency purchase
function ItemPurchaseHandler:ProcessCurrencyPurchase(player, item, price)
    local data = self:GetPlayerData(player)
    
    -- Check if player can afford the item
    if data.currency < price then
        return false, "Not enough " .. Constants.CURRENCY.INGAME .. " to purchase this item."
    end
    
    -- Deduct the cost
    data.currency = data.currency - price
    
    -- Add the item to the player's inventory
    self:AddItemToInventory(player, item)
    
    return true, "Successfully purchased " .. item.Name .. " for " .. price .. " " .. Constants.CURRENCY.INGAME
end

-- Process Robux purchase (Developer Product)
function ItemPurchaseHandler:ProcessRobuxPurchase(player, item, productId)
    -- This would be handled through MarketplaceService.ProcessReceipt
    -- For now, we'll simulate this process
    
    -- Add the item to the player's inventory
    self:AddItemToInventory(player, item)
    
    return true, "Successfully purchased " .. item.Name .. " with Robux"
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
        
        -- Grant some generic reward for now
        -- You'll need to implement a proper system to track which item a player intended to buy
        
        -- Return that the purchase was successful
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- Otherwise try to match with currency products
    for _, product in ipairs(Constants.CURRENCY.PRODUCTS) do
        if product.assetId == productId then
            -- Add coins to player account
            local data = ItemPurchaseHandler:GetPlayerData(player)
            data.currency = data.currency + (product.coins + product.bonusCoins)
            
            debugLog("Added", product.coins + product.bonusCoins, "coins to", player.Name)
            
            -- Return that the purchase was successful
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    
    -- Product not recognized
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Initialize the handler
function ItemPurchaseHandler:Initialize()
    -- Set up MarketplaceService callback
    MarketplaceService.ProcessReceipt = processReceipt
    
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
            local productId = receiptInfo and receiptInfo.ProductId
            success, message = self:ProcessRobuxPurchase(player, item, productId)
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
