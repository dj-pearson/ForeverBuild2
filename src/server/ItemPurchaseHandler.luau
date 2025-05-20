-- Consolidated ItemPurchaseHandler module that includes AdminCurrencyManager functionality
-- This handles server-side item purchases, inventory management, and admin currency operations

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

-- Setup data store for player data
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- Import shared modules with fallback
print("[ItemPurchaseHandler] Attempting to require shared module")
local SharedModule
local Constants

local success, errorMessage = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared", 5))
    Constants = SharedModule.Constants
    return true
end)

if not success then    warn("[ItemPurchaseHandler] Failed to require SharedModule:", errorMessage)
    print("[ItemPurchaseHandler] Creating minimal SharedModule fallback")
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
        },
        ADMIN_IDS = {
            3246397734, -- Default Roblox test account ID
            7768610061  -- Your actual user ID (Xdjpearsonx)
        }
    }
    SharedModule = {
        Constants = Constants
    }
else
    print("[ItemPurchaseHandler] Successfully required SharedModule")
      -- Ensure admin IDs exist in Constants
    if not Constants.ADMIN_IDS then
        print("[ItemPurchaseHandler] Creating ADMIN_IDS table in Constants")
        Constants.ADMIN_IDS = {
            3246397734, -- Default Roblox test account ID
            7768610061  -- Your actual user ID (Xdjpearsonx)
        }
    end
end

-- Remote events
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseItemEvent = remotes:FindFirstChild("PurchaseItem") 
local addToInventoryEvent = remotes:FindFirstChild("AddToInventory")
local updateBalanceEvent = remotes:FindFirstChild("UpdateBalance")
local purchaseResultEvent = remotes:FindFirstChild("PurchaseResult")

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

if not purchaseResultEvent then
    purchaseResultEvent = Instance.new("RemoteEvent")
    purchaseResultEvent.Name = "PurchaseResult"
    purchaseResultEvent.Parent = remotes
    print("[ItemPurchaseHandler] Created PurchaseResult RemoteEvent")
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

-- Store remotes reference
ItemPurchaseHandler.remotes = remotes

-- Initialize player data
local playerData = {}

-- Track players that already have command handlers set up
local playersWithCommandHandlers = {}

-- Function to get or create player data
function ItemPurchaseHandler:GetPlayerData(player)
    print("[ItemPurchaseHandler] GetPlayerData called for", player.Name)
    
    -- Make sure player exists
    if not player or not player.Parent then
        warn("[ItemPurchaseHandler] Invalid player in GetPlayerData")
        return nil
    end
    
    -- Get the player's data
    local success, playerDataResult = pcall(function()
        return self:LoadPlayerData(player)
    end)
    
    if success and playerDataResult then
        -- Ensure inventory exists
        if not playerDataResult.inventory then
            playerDataResult.inventory = {}
        end
        
        -- Add mock items for testing in studio if inventory is empty
        if #playerDataResult.inventory == 0 and game:GetService("RunService"):IsStudio() then
            print("[ItemPurchaseHandler] Adding test items to empty inventory in Studio")
            
            -- Add some test items
            local testItems = {
                { id = "Grass_Cube", name = "Grass Cube", quantity = 5 },
                { id = "Stone_Cube", name = "Stone Cube", quantity = 5 },
                { id = "Wood_Plank", name = "Wood Plank", quantity = 5 },
                { id = "Brick_Cube", name = "Brick Cube", quantity = 5 },
                { id = "Water_Cube", name = "Water Cube", quantity = 3 },
                { id = "Glass_Cube", name = "Glass Cube", quantity = 3 }
            }
            
            for _, item in ipairs(testItems) do
                table.insert(playerDataResult.inventory, item)
            end
        end
        
        return playerDataResult
    else
        warn("[ItemPurchaseHandler] Failed to get player data:", playerDataResult)
        return nil
    end
end

-- Load player data from DataStore or create new data if none exists
function ItemPurchaseHandler:LoadPlayerData(player)
    debugLog("LoadPlayerData called for:", player.Name)
    
    -- Check if we already have data in memory
    if playerData[player.UserId] then
        debugLog("Using cached data for:", player.Name)
        return playerData[player.UserId]
    end
    
    -- Try to load data from DataStore
    local success, result = pcall(function()
        return playerDataStore:GetAsync("Player_" .. player.UserId)
    end)
    
    local data
        
    if success and result then
        debugLog("Loaded data from DataStore for:", player.Name)
        data = result
    else
        debugLog("Creating new data for:", player.Name)
        -- Create new data with default values
        data = {
            currency = Constants.CURRENCY.STARTING_CURRENCY or 100,
            inventory = {}
        }
    end
    
    -- Cache the data
    playerData[player.UserId] = data
    
    return data
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
    if not data then
        warn("[ItemPurchaseHandler] UpdateClientBalance: Failed to get player data for", player.Name)
        return
    end
    
    -- Fire event to update client UI
    if updateBalanceEvent then
        updateBalanceEvent:FireClient(player, data.currency)
        print("💰 [ItemPurchaseHandler] CURRENCY UPDATE for " .. player.Name .. ": " .. data.currency .. " coins")
    else
        warn("[ItemPurchaseHandler] UpdateBalanceEvent is nil, cannot update currency UI")
    end
end

-- Check if player is an admin
function ItemPurchaseHandler:IsAdmin(player)
    -- Hardcoded admin IDs for emergency use
    local hardcodedAdmins = {
        3246397734, -- Default Roblox test account ID
        7768610061  -- Your actual user ID (Xdjpearsonx)
    }
    
    -- Check using hardcoded admin IDs first (for emergency access)
    for _, adminId in ipairs(hardcodedAdmins) do
        if player and player.UserId and adminId == player.UserId then
            print("[ItemPurchaseHandler] IsAdmin: Direct match found with hardcoded ID! PlayerID:", player.UserId)
            return true
        end
    end
    
    -- Check using Constants admin IDs if available
    if Constants and Constants.ADMIN_IDS then
        for _, adminId in ipairs(Constants.ADMIN_IDS) do
            if player and player.UserId and adminId == player.UserId then
                print("[ItemPurchaseHandler] IsAdmin: Match found in Constants.ADMIN_IDS! PlayerID:", player.UserId)
                return true
            end
        end
    else
        print("[ItemPurchaseHandler] IsAdmin: Constants.ADMIN_IDS is nil or not a table")
    end
    
    -- Check by Name
    if Constants and Constants.isAdminPlayerName and player and player.Name then
        if Constants.isAdminPlayerName(player.Name) then
            return true
        end
    end
    
    return false
end

-- Add currency to all admin accounts
function ItemPurchaseHandler:AddCurrencyToAdmins(amount)
    amount = amount or 1000000 -- Default to 1 million
    
    print("[ItemPurchaseHandler] AddCurrencyToAdmins called with amount:", amount)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if self:IsAdmin(player) then
            print("[ItemPurchaseHandler] Adding currency to admin:", player.Name)
            local playerData = self:GetPlayerData(player)
            
            if playerData then
                local oldCurrency = playerData.currency or 0
                playerData.currency = oldCurrency + amount
                print("[ItemPurchaseHandler] Currency update for " .. player.Name .. ": " .. oldCurrency .. " -> " .. playerData.currency)
                self:SavePlayerData(player)
                self:UpdateClientBalance(player)
                print("[ItemPurchaseHandler] Added " .. amount .. " coins to admin account: " .. player.Name)
            end
        end
    end
end

-- Add a function to explicitly add an item to a player's inventory
function ItemPurchaseHandler:AddToInventory(player, itemId, amount)
    if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
        warn("[ItemPurchaseHandler] AddToInventory - Invalid player")
        return false
    end
    
    if not itemId or typeof(itemId) ~= "string" then
        warn("[ItemPurchaseHandler] AddToInventory - Invalid itemId")
        return false
    end
    
    amount = amount or 1
    
    -- Get player data
    local playerData = self:GetPlayerData(player)
    if not playerData then
        warn("[ItemPurchaseHandler] AddToInventory - No player data for", player.Name)
        return false
    end
    
    -- Add item to inventory
    if not playerData.inventory then
        playerData.inventory = {}
    end
    
    -- Check if item exists in inventory, if so increment quantity
    local itemExists = false
    for _, item in pairs(playerData.inventory) do
        if item.name == itemId or item.id == itemId then
            -- If dictionary-style has quantity
            if item.quantity then
                item.quantity = item.quantity + amount
            end
            itemExists = true
            break
        end
    end
    
    -- If item doesn't exist, add it
    if not itemExists then
        -- Create a new item
        local newItem = {
            id = itemId,
            name = itemId,
            quantity = amount
        }
        
        -- Add to inventory
        table.insert(playerData.inventory, newItem)
    end
    
    -- Save player data
    self:SavePlayerData(player)
    
    -- Notify client of item added
    local remotes = self.remotes or ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local addToInventoryEvent = remotes:FindFirstChild("AddToInventory")
        if addToInventoryEvent then
            addToInventoryEvent:FireClient(player, {
                name = itemId,
                quantity = amount
            })
        end
    end
    
    print("[ItemPurchaseHandler] Added", amount, "x", itemId, "to", player.Name, "'s inventory")
    return true
end

-- Add a function to explicitly remove an item from a player's inventory
function ItemPurchaseHandler:RemoveFromInventory(player, itemId, amount)
    if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Invalid player")
        return false
    end
    
    if not itemId or typeof(itemId) ~= "string" then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Invalid itemId")
        return false
    end
    
    amount = amount or 1
    
    -- Get player data
    local playerData = self:GetPlayerData(player)
    if not playerData then
        warn("[ItemPurchaseHandler] RemoveFromInventory - No player data for", player.Name)
        return false
    end
    
    -- Check if inventory exists
    if not playerData.inventory then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Player has no inventory")
        return false
    end
    
    -- Find the item to remove
    local itemIndex = nil
    local foundItem = nil
    
    for i, item in pairs(playerData.inventory) do
        if item.name == itemId or item.id == itemId then
            itemIndex = i
            foundItem = item
            break
        end
    end
    
    if not foundItem then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Item", itemId, "not found in inventory")
        return false
    end
    
    -- Handle quantity if dictionary style inventory
    if foundItem.quantity then
        if foundItem.quantity <= amount then
            -- Remove the entire item
            table.remove(playerData.inventory, itemIndex)
        else
            -- Reduce quantity
            foundItem.quantity = foundItem.quantity - amount
        end
    else
        -- Array-style inventory, just remove the item
        table.remove(playerData.inventory, itemIndex)
    end
    
    -- Save player data
    self:SavePlayerData(player)
    
    print("[ItemPurchaseHandler] Removed", amount, "x", itemId, "from", player.Name, "'s inventory")
    return true
end

-- Process in-game currency purchase
function ItemPurchaseHandler:ProcessCurrencyPurchase(player, item, price)
    local data = self:GetPlayerData(player)
    if not data then
        warn("[ItemPurchaseHandler] ProcessCurrencyPurchase: Failed to get player data for", player.Name)
        return false, "Failed to access player data"
    end
    
    print("[ItemPurchaseHandler] ProcessCurrencyPurchase - Player:", player.Name, "Item:", item.Name, "Price:", price, "Current Currency:", data.currency)
    
    -- Check if player is an admin for free purchases
    if self:IsAdmin(player) then
        print("[ItemPurchaseHandler] Admin detected: Free purchase granted for " .. player.Name)
          -- Add the item to the player's inventory without charging
        self:AddToInventory(player, item.Name)
        
        -- Save the data
        self:SavePlayerData(player)
        
        return true, "Admin free purchase of " .. tostring(item.Name)
    end
    
    -- Check if player can afford the item
    if data.currency < price then
        print("[ItemPurchaseHandler] Purchase failed: Not enough currency. Has:", data.currency, "Needs:", price)
        return false, "Not enough " .. Constants.CURRENCY.INGAME .. " to purchase this item."
    end
    
    -- Deduct the cost
    data.currency = data.currency - price
    print("[ItemPurchaseHandler] Purchase successful! New currency balance:", data.currency)
    
    -- Add the item to the player's inventory
    self:AddToInventory(player, item.Name)
    
    -- Save the data after purchase
    self:SavePlayerData(player)
    
    -- Update client UI with new balance
    self:UpdateClientBalance(player)
    
    return true, "Successfully purchased " .. tostring(item.Name) .. " for " .. tostring(price) .. " " .. tostring(Constants.CURRENCY.INGAME)
end

-- Add a ProcessPurchase function that expects an itemId (string)
function ItemPurchaseHandler:ProcessPurchase(player, itemId)
    local itemDefinition = nil
    local price = 10 -- Default price

    if SharedModule and SharedModule.Constants and SharedModule.Constants.ITEMS and SharedModule.Constants.ITEMS[itemId] then
        itemDefinition = SharedModule.Constants.ITEMS[itemId]
        if typeof(itemDefinition) == "table" then
            price = itemDefinition.Price or itemDefinition.price or price -- Check for Price (capital P) or price (lowercase p)
        else
            -- If itemDefinition is not a table, it might be a direct price or something else.
            -- For now, we assume it implies the default price if not a table with a price field.
            print("[ItemPurchaseHandler] Warning: Item definition for ''' .. itemId .. ''' in Constants.ITEMS is not a table. Using default price.")
        end
    else
        print("[ItemPurchaseHandler] Warning: Item ''' .. itemId .. ''' not found in Constants.ITEMS. Using default price and name.")
    end

    -- Construct an item object to pass, ensuring Name is always the itemId string
    local itemToProcess = {
        Name = itemId, -- Always use the simple string itemId as the Name
        id = itemId,
        Price = price -- Store the determined price
    }

    return self:ProcessCurrencyPurchase(player, itemToProcess, price)
end

-- Initialize the handler
function ItemPurchaseHandler:Initialize()
    -- Set up MarketplaceService callback
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
        
        -- Process product purchase
        -- Add implementation as needed
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- Connect player join event to send initial balance
    Players.PlayerAdded:Connect(function(player)
        -- Load player data
        local data = self:GetPlayerData(player)
        
        -- Send initial balance to client
        self:UpdateClientBalance(player)
        
        if data then
            print("[ItemPurchaseHandler] Sent initial balance to " .. player.Name .. ": " .. data.currency)
        else
            print("[ItemPurchaseHandler] Initial player data load failed for " .. player.Name)
        end
        
        -- Set up chat commands for this player
        self:SetupAdminCommands(player)
    end)
    
    -- Connect player leave event to save data
    Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerData(player)
        -- Remove from tracking table to avoid memory leaks
        if playersWithCommandHandlers[player.UserId] then
            playersWithCommandHandlers[player.UserId] = nil
            print("[ItemPurchaseHandler] Removed player from command handler tracking:", player.Name)
        end
    end)
    
    -- Connect existing players (in case the script is being reloaded)
    for _, player in ipairs(Players:GetPlayers()) do
        self:SetupAdminCommands(player)
    end
    
    -- Connect Remote Events for inventory operations
    if purchaseItemEvent then
        purchaseItemEvent.OnServerEvent:Connect(function(player, itemArg)
            print("[ItemPurchaseHandler] PurchaseItem event received from", player.Name, "for item", tostring(itemArg))
            
            local simpleItemId = itemArg -- Default to itemArg if it's already a simple name
            
            if typeof(itemArg) == "Instance" then
                simpleItemId = itemArg.Name -- If it's an instance, just use its Name
            elseif typeof(itemArg) == "string" then
                -- Extract the base name from a path string like "Workspace.Items.Basic.Grass_Cube"
                local pathParts = string.split(itemArg, ".") -- Use string.split
                simpleItemId = pathParts[#pathParts] -- Get the last part
            elseif typeof(itemArg) == "table" and itemArg.id then
                simpleItemId = itemArg.id -- If it's a table with an id, use that
            else
                warn("[ItemPurchaseHandler] Could not determine simple item ID from itemArg:", itemArg)
                if purchaseResultEvent then
                     purchaseResultEvent:FireClient(player, false, "Invalid item data received by server.")
                end
                return -- Stop processing if we can't get a valid ID
            end

            print("[ItemPurchaseHandler] Extracted simpleItemId:", simpleItemId)
            local success, message = ItemPurchaseHandler:ProcessPurchase(player, simpleItemId)
            
            -- Notify the client of the purchase result
            if purchaseResultEvent then
                purchaseResultEvent:FireClient(player, success, message)
            else
                warn("[ItemPurchaseHandler] PurchaseResult RemoteEvent still not found after attempting to create.")
            end
        end)
        print("[ItemPurchaseHandler] Connected PurchaseItem event")
    end
    
    if addToInventoryEvent then
        addToInventoryEvent.OnServerEvent:Connect(function(player, itemData)
            print("[ItemPurchaseHandler] AddToInventory event received from", player.Name)
            local itemId = typeof(itemData) == "table" and itemData.id or itemData
            local quantity = typeof(itemData) == "table" and itemData.quantity or 1
            self:AddToInventory(player, itemId, quantity)
        end)
        print("[ItemPurchaseHandler] Connected AddToInventory event")
    end
    
    -- Set up GetInventory RemoteFunction if it doesn't exist
    local getInventoryFunction = remotes:FindFirstChild("GetInventory")
    if not getInventoryFunction then
        getInventoryFunction = Instance.new("RemoteFunction")
        getInventoryFunction.Name = "GetInventory"
        getInventoryFunction.Parent = remotes
        print("[ItemPurchaseHandler] Created GetInventory RemoteFunction")
    end
    
    -- Connect GetInventory function
    getInventoryFunction.OnServerInvoke = function(player)
        print("GetInventory RemoteFunction called by player:", player.Name)
        return self:GetPlayerInventory(player)
    end
    
    print("[ItemPurchaseHandler] Module initialized successfully")
end

-- Chat command handler for admin currency
function ItemPurchaseHandler:SetupAdminCommands(player)
    -- Check if this player already has command handlers set up
    if playersWithCommandHandlers[player.UserId] then
        print("[ItemPurchaseHandler] Player already has command handlers set up:", player.Name)
        return
    end
    
    -- Mark this player as having command handlers
    playersWithCommandHandlers[player.UserId] = true
    print("[ItemPurchaseHandler] Setting up command handlers for player:", player.Name)
    
    -- Connect the chat event
    player.Chatted:Connect(function(message)
        if message:lower() == "/addadmincurrency" then
            print("[ItemPurchaseHandler] Command triggered by player:", player.Name, "with ID:", player.UserId)
            
            -- Check if player is an admin
            local isAdmin = self:IsAdmin(player)
            print("[ItemPurchaseHandler] isAdmin result:", isAdmin)
            
            if isAdmin then
                self:AddCurrencyToAdmins(1000000)
                print("[ItemPurchaseHandler] Admin currency command executed by: " .. player.Name)
            else
                print("[ItemPurchaseHandler] Non-admin player attempted to use admin command: " .. player.Name)
            end
        end
    end)
end

-- Add this function to support GetInventory RemoteFunction
function ItemPurchaseHandler:GetPlayerInventory(player)
    local data = self:GetPlayerData(player)
    if data then
        -- Map inventory to use 'count' for quantity
        local inventory = {}
        for _, item in ipairs(data.inventory or {}) do
            local newItem = {}
            for k, v in pairs(item) do
                newItem[k] = v
            end
            -- Map 'quantity' to 'count' for UI compatibility
            if newItem.quantity then
                newItem.count = newItem.quantity
            end
            table.insert(inventory, newItem)
        end
        return {
            success = true,
            inventory = inventory,
            currency = data.currency or 0,
            message = "Inventory and currency fetched successfully"
        }
    else
        return {
            success = false,
            inventory = {},
            currency = 0,
            message = "Failed to fetch player data"
        }
    end
end

-- Initialize the handler when the module is loaded
ItemPurchaseHandler:Initialize()

return ItemPurchaseHandler