-- EnhancedPurchaseIntegration.luau
-- Integration script to connect Enhanced Purchase System with existing proximity detection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Import the Enhanced Purchase System
local EnhancedPurchaseSystem = require(script.Parent:WaitForChild("EnhancedPurchaseSystem"))

-- Initialize the system
local purchaseSystem = EnhancedPurchaseSystem.new()

-- Configuration
local INTEGRATION_CONFIG = {
    maxProximityDistance = 15, -- studs
    checkInterval = 0.1, -- seconds
    debugMode = false
}

-- State tracking
local currentNearbyItem = nil
local lastProximityCheck = 0
local isSystemActive = true

-- Integration functions
local Integration = {}

function Integration.Initialize()
    print("🔄 Enhanced Purchase Integration starting...")
    
    -- Start proximity monitoring
    RunService.Heartbeat:Connect(function()
        if not isSystemActive then return end
        
        local currentTime = tick()
        if currentTime - lastProximityCheck >= INTEGRATION_CONFIG.checkInterval then
            Integration.CheckProximity()
            lastProximityCheck = currentTime
        end
    end)
    
    print("✅ Enhanced Purchase Integration initialized")
end

function Integration.CheckProximity()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local nearestItem = nil
    local nearestDistance = math.huge
    
    -- Find all purchasable items in the workspace
    local purchasableItems = Integration.FindPurchasableItems()
    
    for _, item in ipairs(purchasableItems) do
        local itemPosition = Integration.GetItemPosition(item)
        if itemPosition then
            local distance = (playerPosition - itemPosition).Magnitude
            
            if distance <= INTEGRATION_CONFIG.maxProximityDistance and distance < nearestDistance then
                nearestDistance = distance
                nearestItem = item
            end
        end
    end
    
    -- Handle proximity changes
    if nearestItem ~= currentNearbyItem then
        if currentNearbyItem then
            -- Player moved away from item
            Integration.OnItemProximityExit(currentNearbyItem)
        end
        
        if nearestItem then
            -- Player approached new item
            Integration.OnItemProximityEnter(nearestItem)
        end
        
        currentNearbyItem = nearestItem
    end
end

function Integration.FindPurchasableItems()
    local items = {}
    
    -- Method 1: Look for items with "Purchasable" tag
    local CollectionService = game:GetService("CollectionService")
    if CollectionService then
        local taggedItems = CollectionService:GetTagged("Purchasable")
        for _, item in ipairs(taggedItems) do
            table.insert(items, item)
        end
    end
    
    -- Method 2: Look for items with specific naming patterns
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") then
            -- Check for items in your world items folder structure
            if obj.Parent and (
                obj.Parent.Name:lower():find("world") or 
                obj.Parent.Name:lower():find("shop") or
                obj.Parent.Name:lower():find("item") or
                obj.Parent.Name:lower():find("purchase")
            ) then
                if Integration.IsValidPurchasableItem(obj) then
                    table.insert(items, obj)
                end
            end
            
            -- Check for items with purchase-related attributes or children
            if obj:GetAttribute("Purchasable") or 
               obj:FindFirstChild("PurchaseData") or
               obj:FindFirstChild("ItemData") then
                table.insert(items, obj)
            end
        end
    end
    
    -- Method 3: Look in specific world items folder (adjust path as needed)
    local worldItemsFolder = workspace:FindFirstChild("WorldItems") or 
                           workspace:FindFirstChild("Items") or
                           workspace:FindFirstChild("PlacedItems")
    
    if worldItemsFolder then
        for _, item in ipairs(worldItemsFolder:GetChildren()) do
            if Integration.IsValidPurchasableItem(item) then
                table.insert(items, item)
            end
        end
    end
    
    return items
end

function Integration.IsValidPurchasableItem(obj)
    -- Check if object is a valid purchasable item
    if not obj or not obj.Parent then return false end
    
    -- Must be a Model or Part
    if not (obj:IsA("Model") or obj:IsA("Part")) then return false end
    
    -- Check for purchase data
    local hasItemData = obj:FindFirstChild("ItemData") or 
                       obj:GetAttribute("ItemName") or
                       obj:GetAttribute("ItemPrice") or
                       obj:GetAttribute("Purchasable")
    
    -- Check for specific naming patterns that indicate purchasable items
    local nameIndicatesPurchasable = obj.Name:lower():find("wall") or
                                   obj.Name:lower():find("brick") or
                                   obj.Name:lower():find("item") or
                                   obj.Name:lower():find("deco")
    
    return hasItemData or nameIndicatesPurchasable
end

function Integration.GetItemPosition(item)
    if not item then return nil end
    
    if item:IsA("Model") then
        local primaryPart = item.PrimaryPart or item:FindFirstChildOfClass("Part")
        return primaryPart and primaryPart.Position
    elseif item:IsA("Part") then
        return item.Position
    end
    
    return nil
end

function Integration.OnItemProximityEnter(item)
    if INTEGRATION_CONFIG.debugMode then
        print("🎯 Player approached item:", item.Name)
    end
    
    local itemData = Integration.ExtractItemData(item)
    if itemData then
        purchaseSystem:OnItemProximity(itemData)
    end
end

function Integration.OnItemProximityExit(item)
    if INTEGRATION_CONFIG.debugMode then
        print("🚶 Player moved away from item:", item.Name)
    end
    
    purchaseSystem:OnItemProximityExit()
end

function Integration.ExtractItemData(item)
    if not item then return nil end
    
    local itemData = {}
    
    -- Try to get data from ItemData child object
    local itemDataObj = item:FindFirstChild("ItemData")
    if itemDataObj then
        itemData.name = itemDataObj:GetAttribute("Name") or item.Name
        itemData.price = itemDataObj:GetAttribute("Price") or itemDataObj:GetAttribute("Cost")
        itemData.description = itemDataObj:GetAttribute("Description")
        itemData.category = itemDataObj:GetAttribute("Category")
    else
        -- Fallback to object attributes
        itemData.name = item:GetAttribute("ItemName") or item.Name
        itemData.price = item:GetAttribute("ItemPrice") or item:GetAttribute("Price") or item:GetAttribute("Cost")
        itemData.description = item:GetAttribute("Description")
        itemData.category = item:GetAttribute("Category")
    end
    
    -- Try to extract from object name (for items like "Red Brick Wall")
    if not itemData.price then
        itemData.price = Integration.ExtractPriceFromName(item.Name)
    end
    
    -- Default price if none found
    if not itemData.price or itemData.price <= 0 then
        itemData.price = Integration.GetDefaultPrice(item.Name)
    end
    
    -- Ensure price is in the correct format
    if typeof(itemData.price) == "number" then
        itemData.price = {INGAME = itemData.price}
    end
    
    -- Store reference to the actual item
    itemData.itemObject = item
    itemData.position = Integration.GetItemPosition(item)
    
    return itemData
end

function Integration.ExtractPriceFromName(itemName)
    -- Try to extract price from patterns in item names
    local patterns = {
        "(%d+) coin", "(%d+) coins",
        "(%d+) cash", "(%d+) money",
        "%$(%d+)", "price: (%d+)"
    }
    
    local lowerName = itemName:lower()
    for _, pattern in ipairs(patterns) do
        local price = lowerName:match(pattern)
        if price then
            return tonumber(price)
        end
    end
    
    return nil
end

function Integration.GetDefaultPrice(itemName)
    -- Default pricing based on item type
    local lowerName = itemName:lower()
    
    if lowerName:find("wall") then
        return 50
    elseif lowerName:find("brick") then
        return 25
    elseif lowerName:find("window") then
        return 75
    elseif lowerName:find("door") then
        return 100
    elseif lowerName:find("roof") then
        return 40
    elseif lowerName:find("floor") then
        return 30
    else
        return 50 -- Default price
    end
end

-- Configuration functions
function Integration.SetProximityDistance(distance)
    INTEGRATION_CONFIG.maxProximityDistance = distance
end

function Integration.SetCheckInterval(interval)
    INTEGRATION_CONFIG.checkInterval = interval
end

function Integration.EnableDebugMode(enabled)
    INTEGRATION_CONFIG.debugMode = enabled
end

function Integration.SetActive(active)
    isSystemActive = active
    if not active then
        -- Hide any current prompts
        purchaseSystem:OnItemProximityExit()
        currentNearbyItem = nil
    end
end

-- Integration with existing purchase events
local function setupPurchaseEventIntegration()
    -- Listen for successful purchases to update nearby items
    local purchaseSuccessEvent = ReplicatedStorage:FindFirstChild("PurchaseSuccess")
    if purchaseSuccessEvent then
        purchaseSuccessEvent.OnClientEvent:Connect(function(itemData)
            -- Refresh proximity check after purchase
            spawn(function()
                wait(0.1)
                Integration.CheckProximity()
            end)
        end)
    end
end

-- Initialize everything
spawn(function()
    wait(1) -- Allow other systems to load
    Integration.Initialize()
    setupPurchaseEventIntegration()
end)

-- Export the integration module
_G.EnhancedPurchaseIntegration = Integration

return Integration 