--[[
    Server Initialization Module - ForeverBuild2
    
    This is the main entry point for server-side logic.
    It initializes all necessary server components and services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
    
    -- Create standard remotes - EVENTS
    createRemote("BuyItem", "RemoteEvent")
    createRemote("PlaceItem", "RemoteEvent")
    createRemote("InteractWithItem", "RemoteEvent")
    createRemote("CloneItem", "RemoteEvent")
    createRemote("PickupItem", "RemoteEvent")
    createRemote("AddToInventory", "RemoteEvent")
    createRemote("ApplyItemEffect", "RemoteEvent")
    createRemote("ShowItemDescription", "RemoteEvent")
    createRemote("NotifyPlayer", "RemoteEvent")
    createRemote("MoveItem", "RemoteEvent")
    createRemote("RotateItem", "RemoteEvent")
    createRemote("DestroyItem", "RemoteEvent")
    createRemote("ChangeItemColor", "RemoteEvent")
    createRemote("RemoveFromInventory", "RemoteEvent")
    createRemote("PurchaseItem", "RemoteEvent")
    createRemote("UpdateBalance", "RemoteEvent")
    createRemote("ConfirmItemMove", "RemoteEvent")
    createRemote("RequestMoveItem", "RemoteEvent")
    
    -- Create placement system remotes
    createRemote("RecallItem", "RemoteEvent")
    createRemote("CancelPlacement", "RemoteEvent")
    createRemote("ItemPlaced", "RemoteEvent")
    createRemote("ItemRecalled", "RemoteEvent")
    
    -- Create standard remotes - FUNCTIONS
    createRemote("GetInventory", "RemoteFunction")
    createRemote("GetAvailableInteractions", "RemoteFunction")
    createRemote("GetItemData", "RemoteFunction")
    createRemote("GetItemCatalog", "RemoteFunction")
    createRemote("IsItemAffordable", "RemoteFunction")
    createRemote("GetMyBalance", "RemoteFunction")
    
    print("Created standard remote events and functions")
end

-- Define utility functions for remotes EARLIER
local function getOrCreateRemoteEvent(name, parent)
    local event = parent:FindFirstChild(name)
    if not event or not event:IsA("RemoteEvent") then
        if event then event:Destroy() end -- Remove if wrong type
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = parent
        print(string.format("server.init: Created new RemoteEvent: %s in %s", name, parent:GetFullName()))
    else
        print(string.format("server.init: Using existing RemoteEvent: %s in %s", name, parent:GetFullName()))
    end
    return event
end

local function getOrCreateRemoteFunction(name, parent)
    local functionRemote = parent:FindFirstChild(name)
    if not functionRemote or not functionRemote:IsA("RemoteFunction") then
        if functionRemote then functionRemote:Destroy() end -- Remove if wrong type
        functionRemote = Instance.new("RemoteFunction")
        functionRemote.Name = name
        functionRemote.Parent = parent
        print(string.format("server.init: Created new RemoteFunction: %s in %s", name, parent:GetFullName()))
    else
        print(string.format("server.init: Using existing RemoteFunction: %s in %s", name, parent:GetFullName()))
    end
    return functionRemote
end

-- Initialize shared module with error handling
print("server.init: Attempting to require shared module")
local SharedModule
local success, errorMessage = pcall(function()
    local shared = ReplicatedStorage:WaitForChild("shared", 10)
    print("server.init: Found shared module at " .. shared:GetFullName())
    SharedModule = require(shared)
    return true
end)

if not success then
    warn("server.init: Failed to require SharedModule:", errorMessage)
    SharedModule = {}
else
    print("server.init: Successfully required SharedModule")
    
    if SharedModule.Init then
        local initSuccess, initError = pcall(function()
            SharedModule.Init() -- Ensure all shared systems are initialized
        end)
    
        if not initSuccess then
            warn("server.init: Failed to initialize SharedModule:", initError)
        else
            print("server.init: SharedModule initialized successfully")
        end
    end
end

-- Load DataService
local DataService
local function initDataService()
    print("server.init: Initializing DataService...")
    
    -- Check if DataService is already available in SharedModule
    if SharedModule.DataService then
        print("server.init: Using existing DataService from SharedModule")
        DataService = SharedModule.DataService
        return true
    end
    
    -- Try to require the DataService module
    local success, result
    
    -- First attempt with absolute path
    success, result = pcall(function()
        return require(ReplicatedStorage.shared.core.DataService)
    end)
    
    -- Try alternative path if first attempt failed
    if not success then
        print("server.init: First DataService path failed, trying alternative path...")
        success, result = pcall(function()
            if script and script.Parent and script.Parent.Parent then
                local corePath = script.Parent.Parent:FindFirstChild("shared")
                if corePath then
                    local dataServiceModule = corePath:FindFirstChild("core")
                    if dataServiceModule then
                        dataServiceModule = dataServiceModule:FindFirstChild("DataService")
                        if dataServiceModule then
                            return require(dataServiceModule)
                        end
                    end
                end
            end
            return nil
        end)
    end
    
    -- Create mock DataService if couldn't load
    if not success or not result then
        print("server.init: Creating basic mock DataService")
        -- Create a basic mock DataService
        result = {
            new = function()
                local mockDS = {
                    dataStore = {},
                    
                    SaveData = function(self, key, value)
                        self.dataStore[key] = value
                        return true
                    end,
                    
                    LoadData = function(self, key)
                        return self.dataStore[key]
                    end,
                    
                    Initialize = function(self, sharedModule)
                        print("Mock DataService initialized")
                        return self
                    end
                }
                return mockDS
            end
        }
        success = true
    end
    
    if success and result then
        -- Create and initialize the DataService
        print("server.init: Creating new DataService instance")
        DataService = result.new()
        DataService:Initialize(SharedModule)
        
        -- Register with SharedModule
        SharedModule.DataService = DataService
        
        print("server.init: DataService initialized successfully")
        return true
    else
        warn("server.init: Failed to create DataService")
        return false
    end
end

-- Helper function to process item action requests with costs
local function processItemActionRequest(player, instanceId, actionKey, remotes, sharedModule, itemPurchaseHandler, placementManager, actionSpecificLogic)
    local Constants = sharedModule.Constants
    local NotifyPlayer = remotes.NotifyPlayer

    print(string.format("server.init: processItemActionRequest - Player: %s, Action: %s, InstanceID: %s", player.Name, actionKey, tostring(instanceId)))

    -- 1. Get Item Instance
    local worldItemsFolder = Workspace:FindFirstChild("World_Items")
    if not worldItemsFolder then
        warn("server.init: World_Items folder not found.")
        NotifyPlayer:FireClient(player, "Error: World item storage not found.")
        return false, nil -- Indicate failure, no specific message from action logic
    end
    local placedFolder = worldItemsFolder:FindFirstChild("Placed")
    if not placedFolder then
        warn("server.init: World_Items/Placed folder not found.")
        NotifyPlayer:FireClient(player, "Error: Placed item storage not found.")
        return false, nil
    end

    local itemInstance = nil
    
    -- First check if PlacementManager has a dedicated function to find items
    if placementManager and placementManager.FindItemByInstanceId then
        print(string.format("server.init: processItemActionRequest - Using PlacementManager.FindItemByInstanceId to find '%s'", instanceId))
        itemInstance = placementManager:FindItemByInstanceId(instanceId)
        if itemInstance then
            print(string.format("server.init: processItemActionRequest - PlacementManager.FindItemByInstanceId found item: %s", itemInstance:GetFullName()))
        else
            print("server.init: processItemActionRequest - PlacementManager.FindItemByInstanceId did not find the item, falling back to manual search")
        end
    end
    
    -- If not found through PlacementManager, do a manual search
    if not itemInstance then
        -- Primary search: Iterate through children and check the "instanceId" attribute.
        if placedFolder then
            print(string.format("server.init: processItemActionRequest - Looking for item with instanceId '%s' in %s (%d children)", 
                instanceId, placedFolder:GetFullName(), #placedFolder:GetChildren()))
                
            for _, child in ipairs(placedFolder:GetChildren()) do
                local idAttribute = child:GetAttribute("instanceId")
                if idAttribute and idAttribute == instanceId then
                    itemInstance = child
                    print(string.format("server.init: processItemActionRequest - Found item '%s' by instanceId attribute", child.Name))
                    break
                end
            end
        end

        -- Search by UniqueItemId if instanceId is not found
        if not itemInstance then
            print("server.init: processItemActionRequest - Trying to find by UniqueItemId attribute")
            for _, child in ipairs(placedFolder:GetChildren()) do
                local uniqueId = child:GetAttribute("UniqueItemId")
                if uniqueId and tostring(uniqueId) == instanceId then
                    itemInstance = child
                    print(string.format("server.init: processItemActionRequest - Found item '%s' by UniqueItemId attribute", child.Name))
                    break
                end
            end
        end

        -- Search by name as last resort
        if not itemInstance then
            -- Primary attribute search failed, log this and attempt fallback.
            local primarySearchFailedMsg = string.format("server.init: processItemActionRequest (%s) - Primary lookup: Could not find item by instanceId attribute '%s'.", actionKey, instanceId)
            
            -- Fallback search: Try to find by name (original behavior).
            if placedFolder then
                itemInstance = placedFolder:FindFirstChild(instanceId)
            end

            if not itemInstance then
                warn(primarySearchFailedMsg .. " Fallback lookup by name also failed. Item not found.")
                NotifyPlayer:FireClient(player, "Error: Could not find the specified item.")
                return false, nil
            else
                -- Found by name (fallback), but not by attribute. This is worth noting.
                warn(primarySearchFailedMsg .. string.format(" Found by name '%s' (fallback). This might indicate inconsistent item naming or attribute setting.", instanceId))
            end
        end
    end

    if not itemInstance then
        warn(string.format("server.init: processItemActionRequest (%s) - Item not found: %s", actionKey, instanceId))
        NotifyPlayer:FireClient(player, "Error: Could not find the specified item (final check).")
        return false, nil
    end

    print(string.format("server.init: processItemActionRequest - Found item: %s at %s", itemInstance.Name, itemInstance:GetFullName()))

    -- 2. Get itemId and priceIngame from attributes
    local originalItemId = itemInstance:GetAttribute("ItemId") -- Try "ItemId" first
    if not originalItemId then
        originalItemId = itemInstance:GetAttribute("itemId") -- Fallback to "itemId"
    end
    local priceIngame = itemInstance:GetAttribute("priceIngame")

    print(string.format("server.init: processItemActionRequest - Item attributes: originalItemId=%s, priceIngame=%s", 
        tostring(originalItemId), tostring(priceIngame)))

    if not originalItemId or type(priceIngame) ~= "number" then
        warn(string.format("server.init: processItemActionRequest (%s) - Missing ItemId/itemId or invalid priceIngame attribute on instance: %s. ItemID: %s, PriceIngame: %s", actionKey, instanceId, tostring(originalItemId), tostring(priceIngame)))
        NotifyPlayer:FireClient(player, "Error: Item information is incomplete for this action.")
        return false, nil
    end

    -- 3. Calculate Action Cost
    local actionInfo = Constants.ITEM_ACTIONS[actionKey:lower()] -- actionKey should be "clone", "move" etc.
    if not actionInfo then
        warn(string.format("server.init: processItemActionRequest (%s) - Action '%s' not defined in Constants.ITEM_ACTIONS.", actionKey, actionKey:lower()))
        NotifyPlayer:FireClient(player, "Error: This action (" .. actionKey .. ") is not configured correctly.")
        return false, nil
    end
    local actualCost = math.ceil(priceIngame * (actionInfo.costMultiplier or 0))

    local actionDisplayName = actionInfo.name or actionKey:sub(1,1):upper()..actionKey:sub(2) -- Use defined name or capitalize actionKey

    -- 4. Currency Check & Deduction
    if not itemPurchaseHandler then
        warn(string.format("server.init: processItemActionRequest (%s) - ItemPurchaseHandler not available.", actionKey))
        NotifyPlayer:FireClient(player, "Error: Currency service is currently unavailable.")
        return false, nil
    end

    local playerData = itemPurchaseHandler:GetPlayerData(player)
    if not playerData then
        NotifyPlayer:FireClient(player, "Error: Unable to retrieve your player data.")
        return false, nil
    end

    if playerData.currency < actualCost then
        NotifyPlayer:FireClient(player, string.format("You need %d %s for %s. You currently have %d.", actualCost, (Constants.CURRENCY.INGAME or "coins"), actionDisplayName, playerData.currency))
        return false, nil
    end

    if actualCost > 0 then
        playerData.currency = playerData.currency - actualCost
        itemPurchaseHandler:SavePlayerData(player)
        itemPurchaseHandler:UpdateClientBalance(player)
        NotifyPlayer:FireClient(player, string.format("Charged %d %s for %s.", actualCost, (Constants.CURRENCY.INGAME or "coins"), actionDisplayName))
    else
        NotifyPlayer:FireClient(player, string.format("%s is free for this item.", actionDisplayName))
    end

    -- 5. Call action-specific logic
    if actionSpecificLogic then
        local successCall, resultFromLogic = pcall(function()
            return actionSpecificLogic(player, itemInstance, actualCost, originalId) -- Must return {success=bool, message=string}
        end)

        if not successCall or not resultFromLogic or type(resultFromLogic) ~= "table" then
            warn(string.format("server.init: processItemActionRequest (%s) - Error or invalid return from actionSpecificLogic: %s", actionKey, tostring(resultFromLogic)))
            if actualCost > 0 then -- REFUND if charged
                playerData.currency = playerData.currency + actualCost
                itemPurchaseHandler:SavePlayerData(player)
                itemPurchaseHandler:UpdateClientBalance(player)
                NotifyPlayer:FireClient(player, string.format("%s failed. Cost of %d %s refunded.", actionDisplayName, actualCost, (Constants.CURRENCY.INGAME or "coins")))
            else
                 NotifyPlayer:FireClient(player, string.format("An error occurred while processing %s.", actionDisplayName))
            end
            return false, nil -- No specific message from a failed/malformed actionSpecificLogic
        end
        
        -- actionSpecificLogic executed, resultFromLogic is its return {success, message}
        if resultFromLogic.message and resultFromLogic.message ~= "" then NotifyPlayer:FireClient(player, resultFromLogic.message) end

        if not resultFromLogic.success and actualCost > 0 then -- If action failed AND cost was deducted, refund
            -- Check if already refunded by a more specific error message
            if not (resultFromLogic.message and string.find(resultFromLogic.message:lower(), "refunded")) then
                playerData.currency = playerData.currency + actualCost
                itemPurchaseHandler:SavePlayerData(player)
                itemPurchaseHandler:UpdateClientBalance(player)
                NotifyPlayer:FireClient(player, string.format("%s failed. Cost of %d %s refunded.", actionDisplayName, actualCost, (Constants.CURRENCY.INGAME or "coins")))
            end
        end
        return resultFromLogic.success, resultFromLogic.message
    else
        warn(string.format("server.init: processItemActionRequest (%s) - No actionSpecificLogic provided.", actionKey))
        if actualCost > 0 then -- REFUND if charged
            playerData.currency = playerData.currency + actualCost
            itemPurchaseHandler:SavePlayerData(player)
            itemPurchaseHandler:UpdateClientBalance(player)
            NotifyPlayer:FireClient(player, string.format("Action '%s' not implemented. Cost refunded.", actionDisplayName))
        else
             NotifyPlayer:FireClient(player, string.format("Action '%s' is not implemented.", actionDisplayName))
        end
        return false, nil
    end
end

-- Add after SharedModule initialization but before other managers
local dataServiceSuccess = initDataService()
if dataServiceSuccess then
    print("server.init: Successfully created DataService instance")
else
    warn("server.init: DataService initialization failed")
end

-- Initialize server managers with error handling
print("server.init: Initializing server managers")
local GameManager, InventoryManager, CurrencyManager, PlacementManager, InteractionManager

-- GameManager
if SharedModule.GameManager and SharedModule.GameManager.new then
    local gmSuccess, gmResult = pcall(function()
        return SharedModule.GameManager.new()
    end)
    
    if gmSuccess and gmResult then
        GameManager = gmResult
        print("server.init: Successfully created GameManager instance")
    else
        warn("server.init: Failed to create GameManager instance:", gmResult)
    end
else
    warn("server.init: GameManager module not available")
end

-- InventoryManager
if SharedModule.InventoryManager and SharedModule.InventoryManager.new then
    local imSuccess, imResult = pcall(function()
        return SharedModule.InventoryManager.new()
    end)
    
    if imSuccess and imResult then
        InventoryManager = imResult
        print("server.init: Successfully created InventoryManager instance")
    else
        warn("server.init: Failed to create InventoryManager instance:", imResult)
    end
else
    warn("server.init: InventoryManager module not available")
end

-- CurrencyManager
if SharedModule.CurrencyManager and SharedModule.CurrencyManager.new then
    local cmSuccess, cmResult = pcall(function()
        return SharedModule.CurrencyManager.new()
    end)
    
    if cmSuccess and cmResult then
        CurrencyManager = cmResult -- This is a local variable
        _G.CurrencyManager = CurrencyManager -- Make the instance globally accessible
        print("server.init: Successfully created CurrencyManager instance and assigned to _G.CurrencyManager")
        
        -- Initialize the CurrencyManager instance now, so it processes existing players
        if _G.CurrencyManager.Initialize then
            local initCmSuccess, initCmError = pcall(function()
                _G.CurrencyManager:Initialize(SharedModule, DataService, Remotes, Players) -- Corrected: IPH removed from here
                _G.CurrencyManager:SetupPlayerHandling(Players:GetPlayers(), itemPurchaseHandler) -- Corrected: IPH added here
            end)
            if initCmSuccess then
                print("server.init: Explicitly initialized _G.CurrencyManager instance.")
            else
                warn("server.init: Failed to explicitly initialize _G.CurrencyManager instance:", initCmError)
            end
        else
            warn("server.init: _G.CurrencyManager.Initialize method not found after instance creation!")
        end
    else
        warn("server.init: Failed to create CurrencyManager instance:", cmResult)
    end
else
    warn("server.init: CurrencyManager module not available")
end

-- Load PlacementManager (Define initPlacementManager before the wait block)
local PlacementManager -- Keep this variable accessible for later use
local function initPlacementManager()
    print("server.init: Initializing PlacementManager (function defined)...")

    if SharedModule.PlacementManager and type(SharedModule.PlacementManager) == "table" and SharedModule.PlacementManager.new then
        print("server.init: Found PlacementManager module in SharedModule. Attempting to create new instance.")
        local newInstance_Success, newInstance_Result = pcall(function()
            return SharedModule.PlacementManager.new(SharedModule) -- Call .new()
        end)

        if not newInstance_Success or not newInstance_Result then
            warn("server.init: Failed to create PlacementManager instance from SharedModule.PlacementManager.new():", tostring(newInstance_Result))
            return false, nil
        end
        
        PlacementManager = newInstance_Result -- Assign to the outer scope PlacementManager variable
        print("server.init: Successfully created PlacementManager instance via SharedModule.PlacementManager.new()")

    else
        warn("server.init: PlacementManager module (or its .new method) not found in SharedModule or is not a table. Attempting fallback...")
        -- Fallback to trying to require it directly
        local placementModulePath
        local pathSuccess = pcall(function()
            placementModulePath = ReplicatedStorage.shared.core.placement.PlacementManager
            print("server.init: (Fallback) Found PlacementManager path at", placementModulePath:GetFullName())
        end)

        if not pathSuccess or not placementModulePath then
            warn("server.init: (Fallback) PlacementManager module path not found in ReplicatedStorage.")
            return false, nil
        end

        local moduleFunc_Success, moduleFunc_Result = pcall(function()
            return require(placementModulePath)
        end)

        if not moduleFunc_Success or not moduleFunc_Result then
            warn("server.init: (Fallback) Failed to require PlacementManager:", tostring(moduleFunc_Result))
            return false, nil
        end

        print("server.init: (Fallback) Creating new PlacementManager instance")
        local fallbackInstance_Success, fallbackInstance_Result = pcall(function()
            return moduleFunc_Result.new(SharedModule)
        end)

        if not fallbackInstance_Success or not fallbackInstance_Result then
            warn("server.init: (Fallback) Failed to create PlacementManager instance:", tostring(fallbackInstance_Result))
            return false, nil
        end
        PlacementManager = fallbackInstance_Result -- Assign to the outer scope PlacementManager variable
    end
    
    -- Initialize the PlacementManager instance
    if PlacementManager and PlacementManager.Initialize then
        local initSuccess, initError = pcall(function()
            PlacementManager:Initialize()
        end)
        
        if not initSuccess then
            warn(string.format("server.init: Failed to initialize PlacementManager instance. Error: %s", tostring(initError)))
            return false, PlacementManager -- Return the partially initialized manager for debugging if needed
        end
        print("server.init: PlacementManager instance initialized successfully")
        return true, PlacementManager -- Return success and the instance
    else
        warn("server.init: PlacementManager instance available but Initialize method not found.")
        return false, PlacementManager
    end
end

-- Wait for Data Clearing if it's in progress
if _G.IsClearingData == true then
    print("server.init: Detected _G.IsClearingData = true. Waiting for data clear to complete...")
    local waitTime = 0
    local maxWaitTime = 20 -- Max seconds to wait
    while not _G.DataClearComplete and waitTime < maxWaitTime do
        task.wait(1)
        waitTime = waitTime + 1
        print(string.format("server.init: Waiting for _G.DataClearComplete... (%d/%d seconds)", waitTime, maxWaitTime))
    end
    if _G.DataClearComplete then
        print("server.init: _G.DataClearComplete is true. Proceeding with PlacementManager initialization.")
    else
        warn("server.init: Timed out waiting for _G.DataClearComplete. Proceeding with PlacementManager initialization anyway.")
    end
else
    print("server.init: _G.IsClearingData is not true. Proceeding with PlacementManager initialization directly.")
end

-- Initialize PlacementManager
print("server.init: Initializing PlacementManager (actual call)...")
-- local PlacementManager -- This was already declared before initPlacementManager function
local placementManagerInstance -- This will hold the instance returned by initPlacementManager
local placementManagerSuccess
placementManagerSuccess, placementManagerInstance = initPlacementManager() -- Call the function

if placementManagerSuccess and placementManagerInstance then
    PlacementManager = placementManagerInstance -- Ensure the module-scoped PlacementManager is the instance
    print("server.init: Successfully created and initialized PlacementManager instance")
else
    warn("server.init: PlacementManager initialization failed or instance not returned correctly.")
    -- If placementManagerInstance was returned even on failure, assign it for potential debugging
    if placementManagerInstance then PlacementManager = placementManagerInstance end
end

-- InteractionManager
if SharedModule.InteractionManager and SharedModule.InteractionManager.new then
    local imSuccess, imResult = pcall(function()
        return SharedModule.InteractionManager.new()
    end)
    
    if imSuccess and imResult then
        InteractionManager = imResult
        print("server.init: Successfully created InteractionManager instance")
        
        -- Initialize interaction manager
        if InteractionManager.Initialize then
            InteractionManager:Initialize()
        end
    else
        warn("server.init: Failed to create InteractionManager instance:", imResult)
    end
else
    warn("server.init: InteractionManager module not available in SharedModule, trying local version")
    
    -- Try loading our local ItemInteractionManager instead
    local success, moduleOrError = pcall(function()
        return require(script.Parent.interaction.ItemInteractionManager)
    end)
    
    if success and moduleOrError then
        local localSuccess, localResult = pcall(function()
            return moduleOrError.new()
        end)
        
        if localSuccess and localResult then
            InteractionManager = localResult
            print("server.init: Successfully created local ItemInteractionManager instance")
            
            -- Initialize interaction manager
            if InteractionManager.Initialize then
                InteractionManager:Initialize()
            end
        else
            warn("server.init: Failed to create local ItemInteractionManager instance:", localResult)
        end
    else
        warn("server.init: Failed to require local ItemInteractionManager:", moduleOrError)
    end
end

-- Initialize ItemPurchaseHandler
local ItemPurchaseHandlerPath = script.Parent:WaitForChild("ItemPurchaseHandler")
local success, ItemPurchaseHandler = pcall(require, ItemPurchaseHandlerPath)

if not success then
    warn("server.init: Failed to load ItemPurchaseHandler. Error: ", tostring(ItemPurchaseHandler))
else
    print("server.init: Successfully loaded ItemPurchaseHandler module")
    
    local initSuccess, errorMsg = pcall(function()
        ItemPurchaseHandler:Initialize() -- Initialize the purchase handler
    end)
    
    if not initSuccess then
        warn("server.init: Failed to initialize ItemPurchaseHandler: ", errorMsg)
    else
        print("server.init: ItemPurchaseHandler initialized successfully")
    end
end

-- NEW SYNCHRONIZATION LOGIC
if _G.CurrencyManager and ItemPurchaseHandler and ItemPurchaseHandler.GetPlayerData and game:GetService("Players") then
    print("server.init: Attempting to synchronize CurrencyManager with ItemPurchaseHandler balances for existing players...")
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        local processPlayer = true
        local cmPlayerBalance = _G.CurrencyManager.playerBalances and _G.CurrencyManager.playerBalances[player.UserId]

        if not cmPlayerBalance then
            if _G.CurrencyManager.OnPlayerJoined then
                print(string.format("server.init: CurrencyManager has no balance entry for %s during sync. Attempting OnPlayerJoined.", player.Name))
                local pcallSuccess, pcallErr = pcall(function() _G.CurrencyManager:OnPlayerJoined(player) end)
                if not pcallSuccess then
                    warn(string.format("server.init: Error calling OnPlayerJoined for %s: %s", player.Name, tostring(pcallErr)))
                end
                cmPlayerBalance = _G.CurrencyManager.playerBalances and _G.CurrencyManager.playerBalances[player.UserId] -- Re-check
            else
                print(string.format("server.init: CurrencyManager has no balance entry for %s and no OnPlayerJoined method. Skipping.", player.Name))
                processPlayer = false
            end
        end
        
        if processPlayer and not cmPlayerBalance then 
            print(string.format("server.init: CurrencyManager still has no balance entry for %s after OnPlayerJoined attempt. Skipping sync for this player.", player.Name))
            processPlayer = false
        end

        if processPlayer then
            local iphPlayerData_success, iphPlayerData = pcall(function() return ItemPurchaseHandler:GetPlayerData(player) end)

            if iphPlayerData_success and iphPlayerData and typeof(iphPlayerData.currency) == "number" then 
                if cmPlayerBalance.currency ~= iphPlayerData.currency then
                    print(string.format("server.init: Syncing CurrencyManager balance for %s. Was: %s, IPH reports: %s. Updating CM and client.", 
                        player.Name, 
                        tostring(cmPlayerBalance.currency), 
                        tostring(iphPlayerData.currency)))
                    cmPlayerBalance.currency = iphPlayerData.currency
                    cmPlayerBalance.isLoaded = true 
                    _G.CurrencyManager:UpdatePlayerBalance(player) 
                else
                    print(string.format("server.init: Balances for %s already in sync (CM: %s, IPH: %s). No update needed.", 
                        player.Name, 
                        tostring(cmPlayerBalance.currency), 
                        tostring(iphPlayerData.currency)))
                end
            elseif not iphPlayerData_success then
                warn(string.format("server.init: Error calling ItemPurchaseHandler:GetPlayerData for %s during sync: %s", player.Name, tostring(iphPlayerData))) 
            else
                local currencyValue = iphPlayerData and iphPlayerData.currency
                warn(string.format("server.init: ItemPurchaseHandler:GetPlayerData for %s returned no data, no currency field, or currency is not a number. Currency value: %s, Type: %s", player.Name, tostring(currencyValue), typeof(currencyValue)))
            end
        end 
    end
    print("server.init: Synchronization attempt complete.")
else
    if not _G.CurrencyManager then warn("server.init: Sync abort: _G.CurrencyManager not available.") end
    if not ItemPurchaseHandler then warn("server.init: Sync abort: ItemPurchaseHandler not available.") end
    if not (ItemPurchaseHandler and ItemPurchaseHandler.GetPlayerData) then warn("server.init: Sync abort: ItemPurchaseHandler.GetPlayerData not available.") end
    if not game:GetService("Players") then warn("server.init: Sync abort: game:GetService(\"Players\") not available.") end
end

-- Setup Remote Function Handlers
-- GetInventory
local getInventoryRemote = Remotes:FindFirstChild("GetInventory")
if getInventoryRemote then
    getInventoryRemote.OnServerInvoke = function(player)
        print("GetInventory RemoteFunction called by player:", player.Name)
        
        -- Always use ItemPurchaseHandler if available
        if ItemPurchaseHandler and ItemPurchaseHandler.GetPlayerInventory then
            local success, result = pcall(function()
                return ItemPurchaseHandler:GetPlayerInventory(player)
            end)
            
            if success then
                -- Debug log the result before returning
                print("GetInventory result for", player.Name, ":", 
                    "success=", result.success, 
                    "items=", result.inventory and #result.inventory or 0, 
                    "currency=", result.currency)
                
                -- Return the result directly
                return result
            else
                warn("Error in GetPlayerInventory:", result)
            end
        else
            warn("ItemPurchaseHandler or GetPlayerInventory not available")
        end
        
        -- If we get here, something went wrong - return a basic response
        return {
            success = true,
            inventory = {},
            currency = 100,
            message = "Default fallback response"
        }
    end
end

-- GetItemData
local getItemDataRemote = Remotes:FindFirstChild("GetItemData")
if getItemDataRemote then
    getItemDataRemote.OnServerInvoke = function(_, itemId)
        return SharedModule.Constants.ITEMS[itemId] or {}
    end
end

-- GetMyBalance - NEW HANDLER
local getMyBalanceFunc = Remotes:FindFirstChild("GetMyBalance")
if getMyBalanceFunc then
    getMyBalanceFunc.OnServerInvoke = function(player)
        if _G.CurrencyManager and typeof(_G.CurrencyManager.GetBalance) == "function" then
            local balance = _G.CurrencyManager:GetBalance(player) -- Use the instance from _G
            print(string.format("GetMyBalance invoked by %s (using _G.CurrencyManager), returning balance: %s", player.Name, tostring(balance)))
            return balance
        else
            warn("GetMyBalance: _G.CurrencyManager instance or GetBalance method not found.")
            -- Fallback, though ideally the instance should always be available
            local SharedModule = game:GetService("ReplicatedStorage"):FindFirstChild("shared")
            if SharedModule then
                local CM_Module = SharedModule:FindFirstChild("core"):FindFirstChild("economy"):FindFirstChild("CurrencyManager")
                if CM_Module then
                    -- This is a best-effort guess if _G fails, assumes module has an active instance or static method
                    -- This path is not ideal and indicates a setup issue if reached.
                    local CurrencyManager_Actual_Instance = CM_Module -- This is still not the instance.
                    -- For this fallback to potentially work, we'd need a known way to get the instance.
                    -- This highlights the importance of _G.CurrencyManager being correctly populated and accessible.
                end
            end
            return 0 
        end
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
            warn("server.init: GameManager.HandleItemPurchase function not found")
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
    -- Remove the duplicate handler since PlacementManager already handles this event
    -- placeItemRemote.OnServerEvent:Connect(function(player, itemId, position, rotation)
    --     if not PlacementManager.PlaceItem then
    --         warn("server.init: PlacementManager.PlaceItem function not found")
    --         return
    --     end
    --     
    --     local success = PlacementManager:PlaceItem(player, itemId, position, rotation)
    --     print("server.init: PlaceItem result for player", player.Name, ":", success)
    -- end)
    
    print("server.init: PlaceItem remote event already handled by PlacementManager module")
end

-- PurchaseItem
local purchaseItemRemote = Remotes:FindFirstChild("PurchaseItem")
if purchaseItemRemote and ItemPurchaseHandler then
    print("server.init: Connected PurchaseItem remote event handler")
end

-- InteractWithItem
local interactItemRemote = Remotes:FindFirstChild("InteractWithItem")
if interactItemRemote and InteractionManager then
    interactItemRemote.OnServerEvent:Connect(function(player, itemData, interactionType)
        if not InteractionManager.HandleInteraction then
            warn("server.init: InteractionManager.HandleInteraction function not found")
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
            warn("server.init: InventoryManager.AddItemToInventory function not found")
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

-- Ensure the older, potentially non-prefixed remotes are also available if anything still uses them
-- Though the goal is to standardize on the 'Request' prefix for these client-initiated actions
local cloneItemRemote = getOrCreateRemoteEvent("CloneItem", Remotes)
local moveItemRemote = getOrCreateRemoteEvent("MoveItem", Remotes)
-- getOrCreateRemoteEvent("RecallItem", Remotes) -- This one is explicitly handled by PlacementManager and its event is created there, and also connected above (line 585)
local destroyItemRemote = getOrCreateRemoteEvent("DestroyItem", Remotes)
local rotateItemRemote = getOrCreateRemoteEvent("RotateItem", Remotes)

-- Connect handlers for legacy remotes to ensure they work the same as the Request prefixed ones
if cloneItemRemote then
    -- cloneItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost)
    --     print(string.format("--- SERVER INIT: LEGACY CloneItem RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
    --     processItemActionRequest(player, instanceId, "clone", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
    --         function(p, inst, cost, originalId)
    --             if PlacementManager and PlacementManager.HandleCloneItemRequest then
    --                 return PlacementManager:HandleCloneItemRequest(p, inst, cost, originalId)
    --             end
    --             return {success = false, message = "Clone service is currently unavailable."}
    --         end
    --     )
    -- end)
    print("server.init: Legacy CloneItem remote event handler temporarily COMMENTED OUT due to missing processItemActionRequest")
end

if destroyItemRemote then
    -- destroyItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost)
    --     print(string.format("--- SERVER INIT: LEGACY DestroyItem RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
    --     processItemActionRequest(player, instanceId, "destroy", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
    --         function(p, inst, cost, originalId)
    --             if PlacementManager and PlacementManager.HandleDestroyItemRequest then
    --                 return PlacementManager:HandleDestroyItemRequest(p, inst, cost, originalId)
    --             end
    --             return {success = false, message = "Destroy service is currently unavailable."}
    --         end
    --     )
    -- end)
    print("server.init: Legacy DestroyItem remote event handler temporarily COMMENTED OUT due to missing processItemActionRequest")
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

-- Add a new RemoteEvent for RecallItem
local recallItemRemote = Remotes:FindFirstChild("RecallItem")
if recallItemRemote and PlacementManager then
    -- recallItemRemote.OnServerEvent:Connect(function(player, instanceId)
    --     print(string.format("--- SERVER INIT: RecallItem (Standard) RECEIVED from %s for instanceId: %s ---", player.Name, tostring(instanceId)))
    --     processItemActionRequest(player, instanceId, "recall", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
    --         function(p, inst, cost, originalItemId) -- p is player, inst is itemInstance
    --             if PlacementManager and PlacementManager.HandleCostedRecallItemRequest then
    --                 return PlacementManager:HandleCostedRecallItemRequest(p, inst, cost, originalItemId) 
    --             end
    --             return {success = false, message = "Recall (standard) service is currently unavailable."}
    --         end
    --     )
    -- end)
    print("server.init: RecallItem remote event (standard) handler temporarily COMMENTED OUT due to missing processItemActionRequest. Recall is now directly handled in PlacementManager._SetupRemoteEvents")
end

print("Server initialization completed successfully")

-- Ensure PlacedItems folder exists in Workspace
local placedItemsFolder = Workspace:FindFirstChild("PlacedItems")
if not placedItemsFolder then
    placedItemsFolder = Instance.new("Folder")
    placedItemsFolder.Name = "PlacedItems"
    placedItemsFolder.Parent = Workspace
    print("Created PlacedItems folder in Workspace")
end

-- ItemTemplates are now managed by the fix_template_system script
-- This reduces redundancy and prevents multiple template creation
local itemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
if itemTemplates then
    print("Server init: ItemTemplates folder exists with " .. #itemTemplates:GetChildren() .. " items")
else
    print("Server init: ItemTemplates folder not found - run fix_template_system.luau to create it")
end

-- Placeholder handlers for new item action requests
local requestCloneItemRemote = getOrCreateRemoteEvent("RequestCloneItem", Remotes)
local requestMoveItemRemote = getOrCreateRemoteEvent("RequestMoveItem", Remotes)
local requestRecallItemRemote = getOrCreateRemoteEvent("RequestRecallItem", Remotes) -- Note: This is for COSTED recall
local requestDestroyItemRemote = getOrCreateRemoteEvent("RequestDestroyItem", Remotes)
local requestRotateItemRemote = getOrCreateRemoteEvent("RequestRotateItem", Remotes)

if requestCloneItemRemote then
    requestCloneItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost)
        print(string.format("--- SERVER INIT: RequestCloneItem RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
        processItemActionRequest(player, instanceId, "clone", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
            function(p, inst, cost, originalId) -- This is actionSpecificLogic
                if PlacementManager and PlacementManager.HandleCloneItemRequest then
                    return PlacementManager:HandleCloneItemRequest(p, inst, cost, originalId) -- Must return {success=bool, message=string}
                end
                return {success = false, message = "Clone service is currently unavailable."}
            end
        )
    end)
    print("server.init: Connected RequestCloneItem remote event")
end

if requestMoveItemRemote then
    requestMoveItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost, newPosition, newRotation)
        print(string.format("--- SERVER INIT: RequestMoveItem RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
        processItemActionRequest(player, instanceId, "move", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
            function(p, inst, cost, originalId)
                if PlacementManager and PlacementManager.HandleMoveItemRequest then
                    -- TODO: Pass newPosition, newRotation to HandleMoveItemRequest when implemented
                    return PlacementManager:HandleMoveItemRequest(p, inst, cost, originalId, newPosition, newRotation)
                end
                return {success = false, message = "Move service is currently unavailable."}
            end
        )
    end)
    print("server.init: Connected RequestMoveItem remote event")
end

-- IMPORTANT: This is a NEW remote for recalling with a cost. The existing "RecallItem" is used by InventoryItemHandler for free recalls.
if requestRecallItemRemote then 
    requestRecallItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost)
        print(string.format("--- SERVER INIT: RequestRecallItem (COSTED) RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
        processItemActionRequest(player, instanceId, "recall", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
            function(p, inst, cost, originalId)
                if PlacementManager and PlacementManager.HandleCostedRecallItemRequest then
                    return PlacementManager:HandleCostedRecallItemRequest(p, inst, cost, originalId)
                end
                return {success = false, message = "Costed recall service is currently unavailable."}
            end
        )
    end)
    print("server.init: Connected RequestRecallItem (COSTED) remote event")
end

if requestDestroyItemRemote then
    requestDestroyItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost)
        print(string.format("--- SERVER INIT: RequestDestroyItem RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
        processItemActionRequest(player, instanceId, "destroy", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
            function(p, inst, cost, originalId)
                if PlacementManager and PlacementManager.HandleDestroyItemRequest then
                    return PlacementManager:HandleDestroyItemRequest(p, inst, cost, originalId)
                end
                return {success = false, message = "Destroy service is currently unavailable."}
            end
        )
    end)
    print("server.init: Connected RequestDestroyItem remote event")
end

if requestRotateItemRemote then
    requestRotateItemRemote.OnServerEvent:Connect(function(player, instanceId, clientCalculatedCost, rotationParameters) 
        print(string.format("--- SERVER INIT: RequestRotateItem RECEIVED from %s for instanceId: %s, clientCost: %s ---", player.Name, tostring(instanceId), tostring(clientCalculatedCost)))
        processItemActionRequest(player, instanceId, "rotate", Remotes, SharedModule, ItemPurchaseHandler, PlacementManager,
            function(p, inst, cost, originalId)
                if PlacementManager and PlacementManager.HandleRotateItemRequest then
                    -- TODO: Pass rotationParameters when implemented
                    return PlacementManager:HandleRotateItemRequest(p, inst, cost, originalId, rotationParameters)
                end
                return {success = false, message = "Rotate service is currently unavailable."}
            end
        )
    end)
    print("server.init: Connected RequestRotateItem remote event")
end

-- Ensure the older, potentially non-prefixed remotes are also available if anything still uses them
-- Though the goal is to standardize on the 'Request' prefix for these client-initiated actions
getOrCreateRemoteEvent("CloneItem", Remotes)
getOrCreateRemoteEvent("MoveItem", Remotes)
-- getOrCreateRemoteEvent("RecallItem", Remotes) -- This one is explicitly handled by PlacementManager and its event is created there, and also connected above (line 585)
getOrCreateRemoteEvent("DestroyItem", Remotes)
getOrCreateRemoteEvent("RotateItem", Remotes)

-- Setup remote event/function handlers that need direct access to initialized managers
local getInventoryFunc = Remotes:FindFirstChild("GetInventory")
if getInventoryFunc then
    getInventoryFunc.OnServerInvoke = function(player)
        -- Implementation for GetInventory (likely uses ItemPurchaseHandler or InventoryManager)
        -- This part seems to already exist in your logs for ItemPurchaseHandler
        if ItemPurchaseHandler and ItemPurchaseHandler.GetPlayerData then
            local data = ItemPurchaseHandler:GetPlayerData(player)
            if data and data.inventory and data.currency then -- Make sure structure is as expected
                print(string.format("GetInventory result for %s : success=true items=%d currency=%d", player.Name, #data.inventory, data.currency))
                return true, data.inventory, data.currency
            else
                warn(string.format("GetInventory: Player data or expected fields missing for %s", player.Name))
                return false, nil, nil
            end
        else
            warn("GetInventory: ItemPurchaseHandler or GetPlayerData not available")
            return false, nil, nil
        end
    end
end
