-- src/server/admin/ClearMyDataTool.server.luau
print("DEBUG: ClearMyDataTool.server.luau SCRIPT STARTED") -- VERY FIRST LINE DEBUG

-- WARNING: This script is for debugging purposes and performs destructive data operations.
-- Use with caution. It's recommended to disable or remove this script after use.

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

print("ClearMyDataTool.server.luau loaded. Auto-execution block will attempt to run.") 

-- [[[ TEMPORARY AUTO-EXECUTION CODE - REMOVE AFTER ONE USE ]]]
_G.IsClearingData = false -- Initialize the flag
_G.DataClearComplete = false -- Initialize the flag

local function autoClearData()
    _G.IsClearingData = true -- Set flag to true when auto-clear starts
    print("DEBUG: autoClearData() function called. _G.IsClearingData SET TO TRUE")
    local targetPlayerName = "Xdjpearsonx"

    local waitedTime = 0
    while (not _G.CurrencyManager or not DataService) and waitedTime < 12 do -- Slightly longer wait
        if not _G.CurrencyManager then print("DEBUG: Waiting for _G.CurrencyManager...") end
        if not DataService then 
            print("DEBUG: Waiting for DataService...")
            -- Try to re-fetch DataService on each wait iteration
            if SharedModule and SharedModule.DataService then
                DataService = SharedModule.DataService
                print("ClearMyDataTool (wait loop): Got DataService from SharedModule.DataService.")
            elseif _G.DataService then
                DataService = _G.DataService
                print("ClearMyDataTool (wait loop): Got DataService from _G.DataService.")
            end
        end
        task.wait(1)
        waitedTime = waitedTime + 1
    end

    if not _G.CurrencyManager then
        warn("ClearMyDataTool: _G.CurrencyManager did not become available after wait. Aborting auto-clear.")
        return
    end
    if not DataService then
        warn("ClearMyDataTool: DataService (via SharedModule) did not become available after wait. Aborting auto-clear as it is critical for world items.")
        return 
    end
    print("DEBUG: _G.CurrencyManager and DataService are available.")

    local player = Players:FindFirstChild(targetPlayerName)
    if player then
        print(string.format("ClearMyDataTool: Player %s found by auto-clear. Running _G.ClearMyDataAndWorldItems.", targetPlayerName))
        _G.ClearMyDataAndWorldItems(player)
        _G.DataClearComplete = true -- Set flag to true when done
        print("DEBUG: _G.ClearMyDataAndWorldItems completed for found player. _G.DataClearComplete SET TO TRUE")
    else
        print(string.format("ClearMyDataTool: Player %s not found yet by auto-clear. Waiting for PlayerAdded.", targetPlayerName))
        local connection
        connection = Players.PlayerAdded:Connect(function(joinedPlayer)
            if joinedPlayer.Name == targetPlayerName then
                print(string.format("ClearMyDataTool: Player %s joined. Ensuring critical modules are ready again...", targetPlayerName))
                -- Re-check critical modules on PlayerAdded, though they should be ready if the initial wait passed.
                local waitedTimeJoin = 0
                while (not _G.CurrencyManager or not DataService) and waitedTimeJoin < 5 do
                    if not _G.CurrencyManager then print("DEBUG: (PlayerAdded) Waiting for _G.CurrencyManager...") end
                    if not DataService then 
                        print("DEBUG: (PlayerAdded) Waiting for DataService...")
                        if SharedModule and SharedModule.DataService then
                            DataService = SharedModule.DataService
                            print("ClearMyDataTool (PlayerAdded wait loop): Got DataService from SharedModule.DataService.")
                        elseif _G.DataService then
                            DataService = _G.DataService
                            print("ClearMyDataTool (PlayerAdded wait loop): Got DataService from _G.DataService.")
                        end
                    end
                    task.wait(1)
                    waitedTimeJoin = waitedTimeJoin + 1
                end

                if not _G.CurrencyManager or not DataService then
                     warn("ClearMyDataTool: (PlayerAdded) Critical modules (_G.CurrencyManager or DataService) not ready. Aborting clear for joined player.")
                     if connection then connection:Disconnect() end
                     return
                end
                print(string.format("ClearMyDataTool: Player %s joined. Running _G.ClearMyDataAndWorldItems from PlayerAdded.", targetPlayerName))
                _G.ClearMyDataAndWorldItems(joinedPlayer)
                _G.DataClearComplete = true -- Set flag to true when done
                print("DEBUG: _G.ClearMyDataAndWorldItems completed for joined player. _G.DataClearComplete SET TO TRUE")
                if connection then connection:Disconnect() end
            end
        end)
    end
end

task.wait(0.1) -- Shorten this wait significantly
print("DEBUG: Starting autoClearData after initial wait.")
autoClearData()
-- [[[ END TEMPORARY AUTO-EXECUTION CODE ]]] 