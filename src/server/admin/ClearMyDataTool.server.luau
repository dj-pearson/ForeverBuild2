-- src/server/admin/ClearMyDataTool.server.luau
print("DEBUG: ClearMyDataTool.server.luau SCRIPT STARTED") -- VERY FIRST LINE DEBUG

-- WARNING: This script is for debugging purposes and performs destructive data operations.
-- Use with caution. This tool is now command-based and only activates when called via chat.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemPurchaseHandler = nil
print("DEBUG: Attempting to require ItemPurchaseHandler...")
local successIPH, resultIPH = pcall(require, ServerScriptService.server.ItemPurchaseHandler)
if successIPH then
    ItemPurchaseHandler = resultIPH
    print("DEBUG: ItemPurchaseHandler required successfully.")
else
    warn("ClearMyDataTool: Failed to require ItemPurchaseHandler:", resultIPH)
end

local SharedModule = nil
local DataService = nil
print("DEBUG: Attempting to require SharedModule...")
local successSM, resultSM = pcall(require, ReplicatedStorage.shared)
if successSM then
    SharedModule = resultSM
    print("DEBUG: SharedModule required successfully.")
    if SharedModule and SharedModule.DataService then
        DataService = SharedModule.DataService
        print("ClearMyDataTool: Successfully got DataService from SharedModule.DataService.")
    elseif _G.DataService then
        DataService = _G.DataService
        print("ClearMyDataTool: Successfully got DataService from _G.DataService.")
    else
        warn("ClearMyDataTool: DataService not found in SharedModule.DataService or _G.DataService initially.")
    end
else
    warn("ClearMyDataTool: Failed to require SharedModule:", resultSM)
end

-- _G.CurrencyManager should be set by server/inits.server.luau

function _G.ClearMyDataAndWorldItems(player)
    print(string.format("DEBUG: _G.ClearMyDataAndWorldItems CALLED for player: %s", player and player.Name or "NIL PLAYER"))
    if not player or not player:IsA("Player") then
        warn("ClearMyDataTool: Invalid player object provided.")
        return
    end

    if not ItemPurchaseHandler then
        warn("ClearMyDataTool: ItemPurchaseHandler is not available. Cannot clear inventory.")
        -- Optionally, allow other parts of the clear to proceed
    end
    
    if not _G.CurrencyManager then
        warn("ClearMyDataTool: _G.CurrencyManager is not available. Cannot reset currency.")
        -- Optionally, allow other parts of the clear to proceed
    end

    local playerName = player.Name
    local userId = player.UserId
    print(string.format("ClearMyDataTool: Starting data clearing for player %s (ID: %s)", playerName, userId))

    -- 1. Clear Workspace.World_Items.Placed (live items)
    print("DEBUG: Attempting to find Workspace.World_Items...")
    local worldItemsFolder = Workspace:FindFirstChild("World_Items")
    if worldItemsFolder then
        print("DEBUG: Found Workspace.World_Items. Attempting to find Placed folder...")
        local placedFolder = worldItemsFolder:FindFirstChild("Placed")
        if placedFolder then
            print("ClearMyDataTool: Clearing all children from Workspace.World_Items.Placed...")
            placedFolder:ClearAllChildren()
            print("ClearMyDataTool: Workspace.World_Items.Placed cleared (live instances).")
        else
            print("ClearMyDataTool: Workspace.World_Items.Placed folder NOT found.")
        end
    else
        print("ClearMyDataTool: Workspace.World_Items folder NOT found.")
    end

    -- 1.5. Clear Player's Placed Item Data from GLOBAL DataStore via DataService
    if DataService then
        print(string.format("ClearMyDataTool: Attempting to clear player\'s items from GLOBAL WorldPlacedItems DataStore for player %s...", playerName))
        local globalWorldDataKey = "WorldPlacedItems" -- Matches PlacementManager\'s global key
        
        local currentGlobalWorldData = DataService:GetData(globalWorldDataKey)

        if not currentGlobalWorldData or type(currentGlobalWorldData) ~= "table" then
            print(string.format("ClearMyDataTool: No existing global world data found for key \'%s\' or data is invalid. Nothing to filter for player items.", globalWorldDataKey))
        else
            print(string.format("ClearMyDataTool: Loaded %d items from global \'%s\'. Filtering for player %s (ID: %s)...", #currentGlobalWorldData, globalWorldDataKey, playerName, userId))
            local filteredWorldData = {}
            local itemsRemovedCount = 0
            for _, itemData in ipairs(currentGlobalWorldData) do
                if itemData and itemData.owner == userId then
                    itemsRemovedCount = itemsRemovedCount + 1
                    print(string.format("ClearMyDataTool: Removing item owned by player: InstanceID \'%s\', ItemID \'%s\'", tostring(itemData.instanceId), tostring(itemData.itemId)))
                else
                    table.insert(filteredWorldData, itemData)
                end
            end

            if itemsRemovedCount > 0 then
                print(string.format("ClearMyDataTool: Removed %d items for player %s. Saving %d items back to \'%s\'.", itemsRemovedCount, playerName, #filteredWorldData, globalWorldDataKey))
                local saveSuccess = DataService:SaveData(globalWorldDataKey, filteredWorldData)
                if saveSuccess then
                    print(string.format("ClearMyDataTool: Successfully saved filtered \'%s\' (removed %d items for player %s).", globalWorldDataKey, itemsRemovedCount, playerName))
                else
                    warn(string.format("ClearMyDataTool: Failed to save filtered \'%s\' after removing items for player %s.", globalWorldDataKey, playerName))
                end
            else
                print(string.format("ClearMyDataTool: No items owned by player %s found in global \'%s\'. No changes made to this DataStore key.", playerName, globalWorldDataKey))
            end
        end
    else
         warn("ClearMyDataTool: DataService not available, cannot clear player items from global WorldPlacedItems DataStore.")
    end
    
    -- COMMENTED OUT: Old attempt to clear a per-player key which PlacementManager does not use for loading its main list.
    --[[
    print(string.format("ClearMyDataTool: Attempting to clear WorldPlacedItems DataStore for player %s...", playerName))
    local playerDataStoreName = "PlayerData" 
    local worldDataKey = "WorldPlacedItems_" .. tostring(userId) 
    
    local dsInstance = game:GetService("DataStoreService"):GetDataStore(playerDataStoreName)
    local successDS, errDS = pcall(function()
        dsInstance:SetAsync(worldDataKey, {})
        print(string.format("ClearMyDataTool: Successfully cleared/reset %s in DataStore %s for player %s.", worldDataKey, playerDataStoreName, playerName))
    end)
    if not successDS then
        warn(string.format("ClearMyDataTool: Error clearing %s for player %s: %s", worldDataKey, playerName, errDS))
    end
    ]]

    -- 2. Clear player\'s inventory
    if ItemPurchaseHandler then
        print(string.format("ClearMyDataTool: Attempting to clear inventory for %s...", playerName))
        local playerData = ItemPurchaseHandler:GetPlayerData(player, true) 
        if playerData then
            playerData.inventory = {}
            playerData.currency = 0 
            
            local saved = ItemPurchaseHandler:SavePlayerData(player, playerData)
            print(string.format("ClearMyDataTool: ItemPurchaseHandler:SavePlayerData returned: %s (type: %s)", tostring(saved), type(saved))) -- DEBUG
            if saved then -- Reverted to check for truthiness, not strict true
                print(string.format("ClearMyDataTool: Player inventory for %s cleared and data appears saved.", playerName))
                if ItemPurchaseHandler.remotes and ItemPurchaseHandler.remotes.InventoryUpdated then
                    ItemPurchaseHandler.remotes.InventoryUpdated:FireClient(player, {}, 0)
                    print(string.format("ClearMyDataTool: Fired InventoryUpdated event to client %s.", playerName))
                else
                    warn("ClearMyDataTool: Could not find ItemPurchaseHandler.remotes.InventoryUpdated to notify client.")
                end
            else
                warn(string.format("ClearMyDataTool: Failed to save cleared inventory data for %s via ItemPurchaseHandler.", playerName))
            end
        else
            warn(string.format("ClearMyDataTool: Could not retrieve playerData for %s to clear inventory.", playerName))
        end
    else
        warn("ClearMyDataTool: ItemPurchaseHandler not available, cannot clear inventory.")
    end

    -- 3. Reset player\'s currency using CurrencyManager
    if _G.CurrencyManager then
        print(string.format("ClearMyDataTool: Attempting to reset currency for %s via CurrencyManager...", playerName))
        local currentBalance = _G.CurrencyManager:GetBalance(player)
        if currentBalance then
            _G.CurrencyManager:RemoveCurrency(player, currentBalance) 
        end
        
        local newCurrencyAmount = 1000
        _G.CurrencyManager:AddCurrency(player, newCurrencyAmount)
        print(string.format("ClearMyDataTool: Currency reset to %d for %s via CurrencyManager.", newCurrencyAmount, playerName))
    else
        warn("ClearMyDataTool: _G.CurrencyManager not available, cannot reset currency.")
    end

    print(string.format("ClearMyDataTool: Data clearing process for %s completed.", playerName))
end

-- Chat Command System
local chatCommands = {
    ["/clearmydata"] = function(player, args)
        print(string.format("ClearMyDataTool: Processing /clearmydata command for %s", player.Name))
        
        -- Wait for critical services to be available
        local waitedTime = 0
        while (not _G.CurrencyManager or not DataService) and waitedTime < 10 do
            if not _G.CurrencyManager then 
                print("ClearMyDataTool: Waiting for _G.CurrencyManager...")
                -- Try to get it from global first
                if _G.CurrencyManager then 
                    break 
                end
            end
            if not DataService then 
                print("ClearMyDataTool: Waiting for DataService...")
                -- Try to re-fetch DataService
                if SharedModule and SharedModule.DataService then
                    DataService = SharedModule.DataService
                    print("ClearMyDataTool: Got DataService from SharedModule.DataService.")
                elseif _G.DataService then
                    DataService = _G.DataService
                    print("ClearMyDataTool: Got DataService from _G.DataService.")
                end
            end
            task.wait(1)
            waitedTime = waitedTime + 1
        end

        if not _G.CurrencyManager then
            warn("ClearMyDataTool: _G.CurrencyManager not available. Aborting clear.")
            return
        end
        if not DataService then
            warn("ClearMyDataTool: DataService not available. Aborting clear.")
            return 
        end

        print(string.format("ClearMyDataTool: Executing clear data command for %s", player.Name))
        _G.ClearMyDataAndWorldItems(player)
    end,
    
    ["/cleardata"] = function(player, args)
        -- Same as /clearmydata but with confirmation
        if #args == 0 then
            print(string.format("ClearMyDataTool: %s used /cleardata without confirmation. Use '/cleardata confirm' to proceed.", player.Name))
            return
        end
        
        if string.lower(args[1]) == "confirm" then
            chatCommands["/clearmydata"](player, {})
        else
            print(string.format("ClearMyDataTool: %s used /cleardata with invalid argument. Use '/cleardata confirm' to proceed.", player.Name))
        end
    end
}

-- Function to handle chat commands
local function onPlayerChatted(player, message)
    local messageLower = string.lower(message)
    local words = {}
    for word in messageLower:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 0 then return end
    
    local command = words[1]
    local args = {}
    for i = 2, #words do
        table.insert(args, words[i])
    end
    
    if chatCommands[command] then
        print(string.format("ClearMyDataTool: Player %s executed command: %s", player.Name, command))
        chatCommands[command](player, args)
    end
end

-- Set up chat command listeners
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        onPlayerChatted(player, message)
    end)
end)

-- Handle already connected players
for _, player in pairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        onPlayerChatted(player, message)
    end)
end

print("ClearMyDataTool.server.luau loaded in COMMAND MODE.")
print("Available commands:")
print("  /clearmydata - Clear your data immediately")
print("  /cleardata confirm - Clear your data with confirmation")
print("Tool is now dormant and will only activate when commands are used.") 