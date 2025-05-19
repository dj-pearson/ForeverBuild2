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
    
    print("Created standard remote events and functions")
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
        CurrencyManager = cmResult
        print("server.init: Successfully created CurrencyManager instance")
    else
        warn("server.init: Failed to create CurrencyManager instance:", cmResult)
    end
else
    warn("server.init: CurrencyManager module not available")
end

-- Load PlacementManager
PlacementManager = nil
local function initPlacementManager()
    print("server.init: Initializing PlacementManager...")
    
    -- Check if PlacementManager is already available in SharedModule
    if SharedModule.PlacementManager then
        print("server.init: Using existing PlacementManager from SharedModule")
        PlacementManager = SharedModule.PlacementManager
        return true
    end
    
    -- Try multiple paths to find the PlacementManager module
    local placementModule
    
    -- Try from ReplicatedStorage
    local success = pcall(function()
        placementModule = ReplicatedStorage.shared.core.placement.PlacementManager
        print("server.init: Found PlacementManager at", placementModule:GetFullName())
    end)
    
    if not success or not placementModule then
        -- Try relative path from script
        success = pcall(function()
            local sharedFolder = script.Parent.Parent:FindFirstChild("shared")
            if sharedFolder then
                local corePath = sharedFolder:FindFirstChild("core")
                if corePath then
                    local placementPath = corePath:FindFirstChild("placement")
                    if placementPath then
                        placementModule = placementPath:FindFirstChild("PlacementManager")
                        if placementModule then
                            print("server.init: Found PlacementManager at relative path", placementModule:GetFullName())
                        end
                    end
                end
            end
        end)
    end
    
    if not placementModule then
        warn("server.init: PlacementManager module not found in any expected location")
        return false
    end
    
    -- Try to require the module
    local moduleFunc
    success, moduleFunc = pcall(function()
        return require(placementModule)
    end)
    
    if not success or not moduleFunc then
        warn("server.init: Failed to require PlacementManager:", moduleFunc)
        return false
    end
    
    -- Create and initialize the PlacementManager
    print("server.init: Creating new PlacementManager instance")
    local newInstance
    success, newInstance = pcall(function()
        return moduleFunc.new(SharedModule)
    end)
    
    if not success or not newInstance then
        warn("server.init: Failed to create PlacementManager instance:", newInstance)
        return false
    end
    
    PlacementManager = newInstance
    
    -- Initialize the PlacementManager
    success = pcall(function()
        PlacementManager:Initialize()
    end)
    
    if not success then
        warn("server.init: Failed to initialize PlacementManager")
        return false
    end
    
    -- Register with SharedModule
    SharedModule.PlacementManager = PlacementManager
    
    print("server.init: PlacementManager initialized successfully")
    return true
end

-- Add after other manager initializations, before remote setup
local placementManagerSuccess = initPlacementManager()
if placementManagerSuccess then
    print("server.init: Successfully created PlacementManager instance")
else
    warn("server.init: PlacementManager initialization failed")
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
    purchaseItemRemote.OnServerEvent:Connect(function(player, itemId, quantity)
        print("server.init: PurchaseItem remote event called by", player.Name, "for item", itemId, "quantity:", quantity or 1)
        
        quantity = quantity or 1
        
        if not ItemPurchaseHandler.AddToInventory then
            warn("server.init: ItemPurchaseHandler.AddToInventory function not found")
            return
        end
        
        -- Get item data
        local itemData = {}
        if SharedModule and SharedModule.Constants and SharedModule.Constants.ITEMS then
            itemData = SharedModule.Constants.ITEMS[itemId] or { Name = itemId, Price = 10 }
        else
            itemData = { Name = itemId, Price = 10 }
        end
        
        -- Process the purchase
        local success, message = ItemPurchaseHandler:ProcessCurrencyPurchase(player, itemData, itemData.Price or 10)
        
        -- Notify player of purchase result
        local notifyRemote = Remotes:FindFirstChild("NotifyPlayer")
        if notifyRemote then
            notifyRemote:FireClient(player, message or (success and "Item purchased!" or "Purchase failed!"))
        end
        
        print("server.init: PurchaseItem result for player", player.Name, ":", success, message)
    end)
    
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

-- AddToInventory
local addToInventoryRemote = Remotes:FindFirstChild("AddToInventory")
if addToInventoryRemote and InventoryManager then
    addToInventoryRemote.OnServerEvent:Connect(function(player, itemId)
        if not InventoryManager.AddItemToInventory then
            warn("server.init: InventoryManager.AddItemToInventory function not found")
            return
        end
        
        InventoryManager:AddItemToInventory(player, itemId)
    end)
end

-- CloneItem
local cloneItemRemote = Remotes:FindFirstChild("CloneItem")
if cloneItemRemote and PlacementManager then
    cloneItemRemote.OnServerEvent:Connect(function(player, itemId)
        if not PlacementManager.CloneItem then
            print("Creating dummy CloneItem handler")
            Remotes.NotifyPlayer:FireClient(player, "Cloning not implemented yet")
            return
        end
        
        local success = PlacementManager:CloneItem(player, itemId)
        if success then
            Remotes.NotifyPlayer:FireClient(player, "Cloned " .. itemId)
        else
            Remotes.NotifyPlayer:FireClient(player, "Failed to clone " .. itemId)
        end
    end)
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
    recallItemRemote.OnServerEvent:Connect(function(player, instanceId)
        if not PlacementManager.RecallItem then
            warn("server.init: PlacementManager.RecallItem function not found")
            return
        end
        
        local success = PlacementManager:RecallItem(player, instanceId)
        print("server.init: RecallItem result for player", player.Name, ":", success)
    end)
    
    print("server.init: Connected RecallItem remote event")
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

-- Ensure ItemTemplates folder exists and contains all required templates
local function setupItemTemplates()
    local itemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if not itemTemplates then
        itemTemplates = Instance.new("Folder")
        itemTemplates.Name = "ItemTemplates"
        itemTemplates.Parent = ReplicatedStorage
        
        -- Create some basic templates for testing
        local items = {
            { name = "Grass_Cube", color = BrickColor.new("Bright green"), transparency = 0, material = Enum.Material.Grass },
            { name = "Stone_Cube", color = BrickColor.new("Medium stone grey"), transparency = 0, material = Enum.Material.Slate },
            { name = "Wood_Plank", color = BrickColor.new("Brown"), transparency = 0, material = Enum.Material.Wood },
            { name = "Water_Cube", color = BrickColor.new("Bright blue"), transparency = 0.3, material = Enum.Material.Water },
            { name = "Fire_Cube", color = BrickColor.new("Bright red"), transparency = 0, material = Enum.Material.Neon },
            { name = "Brick_Cube", color = BrickColor.new("Brick red"), transparency = 0, material = Enum.Material.Brick },
            { name = "Sand_Cube", color = BrickColor.new("Brick yellow"), transparency = 0, material = Enum.Material.Sand },
            { name = "Concrete_Cube", color = BrickColor.new("Institutional white"), transparency = 0, material = Enum.Material.Concrete },
            { name = "Metal_Cube", color = BrickColor.new("Medium grey"), transparency = 0, material = Enum.Material.Metal },
            { name = "Glass_Cube", color = BrickColor.new("Toothpaste"), transparency = 0.5, material = Enum.Material.Glass }
        }
        
        for _, itemInfo in ipairs(items) do
            local part = Instance.new("Part")
            part.Name = itemInfo.name
            part.Size = Vector3.new(2, 2, 2)
            part.Anchored = true
            part.CanCollide = true
            part.BrickColor = itemInfo.color
            part.Transparency = itemInfo.transparency
            part.Material = itemInfo.material
            
            -- Also create a shorthand version without the _Cube suffix for convenience
            local shortName = itemInfo.name:gsub("_Cube", "")
            if shortName ~= itemInfo.name then
                local shortPart = part:Clone()
                shortPart.Name = shortName
                shortPart.Parent = itemTemplates
            end
            
            part.Parent = itemTemplates
            
            print("Created template: " .. part.Name .. " (" .. tostring(part.BrickColor) .. ", transparency=" .. tostring(part.Transparency) .. ")")
        end
        
        print("Server init: Created " .. #itemTemplates:GetChildren() .. " item templates")
    else
        print("Server init: ItemTemplates folder already exists with " .. #itemTemplates:GetChildren() .. " items")
    end
    
    return itemTemplates
end

-- Call the setup function to ensure templates exist
setupItemTemplates()
