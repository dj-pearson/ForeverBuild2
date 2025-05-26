--[[
    AddNameAttributeScript.lua - Enhanced with Unique ItemId Assignment
    This script traverses both Workspace.Items and ServerStorage.Items and assigns attributes:
    - ItemId: Unique numeric ID (preserved if exists, assigned if missing)
    - name: Parent folder name
    - item: Model name or default
    - assetId: From Constants.ITEMS if matching, otherwise default
    - tier: From Constants.ITEMS if matching, otherwise 'BASIC'
    - priceIngame: From Constants.ITEMS if matching, otherwise default by tier
    - priceRobux: From Constants.ITEMS if matching, otherwise default by tier
    - description: From Constants.ITEMS if matching, otherwise 'No description available.'
]]

local Constants = require(game:GetService("ReplicatedStorage").shared.core.Constants)

-- Debug function to print pricing information
local function debugPricing(modelName, itemData, finalIngamePrice, finalRobuxPrice)
    print("🔍 PRICING DEBUG for " .. modelName .. ":")
    print("  Found in Constants.ITEMS:", itemData ~= nil)
    if itemData then
        print("  Raw price field:", itemData.price)
        print("  Raw priceIngame field:", itemData.priceIngame)
        if itemData.tier then
            print("  Item tier:", itemData.tier)
            if Constants.ITEM_PRICES and Constants.ITEM_PRICES[itemData.tier] then
                print("  Tier pricing:", Constants.ITEM_PRICES[itemData.tier])
            end
        end
    end
    print("  Final INGAME price:", finalIngamePrice)
    print("  Final ROBUX price:", finalRobuxPrice)
    print("")
end

-- Enhanced pricing logic that follows the same logic as the game systems
local function getItemPricing(modelName)
    local itemData = Constants.ITEMS[modelName]
    local ingamePrice = 5  -- Default fallback
    local robuxPrice = 5   -- Default fallback
    
    if itemData then
        -- PRIORITY 1: Use direct price table (new format)
        if itemData.price and type(itemData.price) == "table" then
            ingamePrice = itemData.price.INGAME or 5
            robuxPrice = itemData.price.ROBUX or 5
        -- PRIORITY 2: Use direct price number (old format)
        elseif itemData.price and type(itemData.price) == "number" then
            ingamePrice = itemData.price
            robuxPrice = itemData.price
        -- PRIORITY 3: Use individual priceIngame field
        elseif itemData.priceIngame and type(itemData.priceIngame) == "number" then
            ingamePrice = itemData.priceIngame
            robuxPrice = itemData.priceIngame  -- Use same for both if only one specified
        -- PRIORITY 4: Use tier-based pricing
        elseif itemData.tier and Constants.ITEM_PRICES and Constants.ITEM_PRICES[itemData.tier] then
            local tierPricing = Constants.ITEM_PRICES[itemData.tier]
            ingamePrice = tierPricing.INGAME or 5
            robuxPrice = tierPricing.ROBUX or 5
        end
    else
        -- Item not found in Constants.ITEMS - determine tier from name and use tier pricing
        local tier = "BASIC"  -- Default
        local lowerName = modelName:lower()
        
        if lowerName:find("glow") or lowerName:find("basic") then
            tier = "BASIC"
        elseif lowerName:find("level_1") or lowerName:find("level1") then
            tier = "LEVEL_1"
        elseif lowerName:find("level_2") or lowerName:find("level2") then
            tier = "LEVEL_2"
        elseif lowerName:find("level_3") or lowerName:find("level3") then
            tier = "LEVEL_3"
        elseif lowerName:find("level_4") or lowerName:find("level4") then
            tier = "LEVEL_4"
        elseif lowerName:find("rare") then
            tier = "RARE"
        elseif lowerName:find("exclusive") then
            tier = "EXCLUSIVE"
        elseif lowerName:find("weapon") then
            tier = "WEAPONS"
        elseif lowerName:find("free") then
            tier = "FREE_ITEMS"
        end
        
        if Constants.ITEM_PRICES and Constants.ITEM_PRICES[tier] then
            local tierPricing = Constants.ITEM_PRICES[tier]
            ingamePrice = tierPricing.INGAME or 5
            robuxPrice = tierPricing.ROBUX or 5
        end
    end
    
    -- Debug output
    debugPricing(modelName, itemData, ingamePrice, robuxPrice)
    
    return ingamePrice, robuxPrice, itemData
end

-- PHASE 1: Collect all existing ItemId values to find the highest number
local function collectExistingItemIds(folder)
    local existingIds = {}
    local maxId = 0
    
    local function scanFolder(currentFolder)
        for _, child in ipairs(currentFolder:GetChildren()) do
            if child:IsA("Model") then
                local existingItemId = child:GetAttribute("ItemId")
                if existingItemId then
                    -- Convert to number if it's a string representation of a number
                    local numericId = tonumber(existingItemId)
                    if numericId then
                        existingIds[numericId] = true
                        maxId = math.max(maxId, numericId)
                        print("Found existing ItemId:", numericId, "on model:", child.Name)
                    else
                        print("Found non-numeric ItemId:", existingItemId, "on model:", child.Name)
                    end
                end
            elseif child:IsA("Folder") then
                scanFolder(child)
            end
        end
    end
    
    scanFolder(folder)
    return existingIds, maxId
end

-- PHASE 2: Process models and assign attributes with unique ItemIds
local function processFolder(folder, folderName, existingIds, nextAvailableId)
    local totalProcessed = 0
    local totalUpdated = 0
    local idsAssigned = 0

    local function processModels(currentFolder, currentFolderName)
        for _, child in ipairs(currentFolder:GetChildren()) do
            if child:IsA("Model") then
                totalProcessed = totalProcessed + 1
                local modelName = child.Name
                
                -- Get enhanced pricing information
                local ingamePrice, robuxPrice, itemData = getItemPricing(modelName)

                -- UNIQUE ITEMID ASSIGNMENT LOGIC
                local currentItemId = child:GetAttribute("ItemId")
                
                if currentItemId == nil then
                    -- No ItemId attribute - assign new unique numeric ID
                    while existingIds[nextAvailableId] do
                        nextAvailableId = nextAvailableId + 1
                    end
                    child:SetAttribute("ItemId", nextAvailableId)
                    existingIds[nextAvailableId] = true
                    print("✅ Assigned NEW ItemId:", nextAvailableId, "to model:", modelName)
                    idsAssigned = idsAssigned + 1
                    nextAvailableId = nextAvailableId + 1
                    
                elseif currentItemId == "" or currentItemId == 0 then
                    -- ItemId exists but has empty/zero value - assign new unique numeric ID
                    while existingIds[nextAvailableId] do
                        nextAvailableId = nextAvailableId + 1
                    end
                    child:SetAttribute("ItemId", nextAvailableId)
                    existingIds[nextAvailableId] = true
                    print("✅ Assigned NEW ItemId:", nextAvailableId, "to model with empty ItemId:", modelName)
                    idsAssigned = idsAssigned + 1
                    nextAvailableId = nextAvailableId + 1
                    
                else
                    -- ItemId exists with a value - preserve it
                    print("🛡️ PRESERVED existing ItemId:", currentItemId, "for model:", modelName)
                end

                -- Assign other attributes (only if they don't exist to preserve existing values)
                if not child:GetAttribute("name") then
                    child:SetAttribute("name", currentFolderName)
                end
                if not child:GetAttribute("item") then
                    child:SetAttribute("item", modelName)
                end
                
                -- Enhanced attribute assignment using proper pricing logic
                if not child:GetAttribute("assetId") then
                    local assetId = (itemData and itemData.icon) or "rbxassetid://3284930147"
                    child:SetAttribute("assetId", assetId)
                end
                
                if not child:GetAttribute("tier") then
                    local tier = (itemData and itemData.tier) or "BASIC"
                    child:SetAttribute("tier", tier)
                end
                
                if not child:GetAttribute("priceIngame") then
                    child:SetAttribute("priceIngame", ingamePrice)
                end
                
                if not child:GetAttribute("priceRobux") then
                    child:SetAttribute("priceRobux", robuxPrice)
                end
                
                if not child:GetAttribute("description") then
                    local description = (itemData and itemData.description) or "No description available."
                    child:SetAttribute("description", description)
                end

                totalUpdated = totalUpdated + 1
                print("✅ Updated model: " .. modelName .. " in folder: " .. currentFolderName)
                print("   📊 Pricing: " .. ingamePrice .. " coins, " .. robuxPrice .. " Robux")
            elseif child:IsA("Folder") then
                processModels(child, child.Name)
            end
        end
    end

    processModels(folder, folderName)
    return totalProcessed, totalUpdated, idsAssigned, nextAvailableId
end

print("=== STARTING UNIQUE ITEMID ASSIGNMENT SYSTEM ===")
print("📋 Constants.ITEMS available:", Constants.ITEMS ~= nil)
print("📋 Constants.ITEM_PRICES available:", Constants.ITEM_PRICES ~= nil)

-- Show available pricing tiers
if Constants.ITEM_PRICES then
    print("📊 Available pricing tiers:")
    for tier, pricing in pairs(Constants.ITEM_PRICES) do
        print("   " .. tier .. ": " .. pricing.INGAME .. " coins, " .. pricing.ROBUX .. " Robux")
    end
end

local workspaceItems = game.Workspace:FindFirstChild("Items")
local serverStorageItems = game:GetService("ServerStorage"):FindFirstChild("Items")

if not workspaceItems and not serverStorageItems then
    error("Could not find Items folder in Workspace or ServerStorage")
    return
end

-- PHASE 1: Collect all existing ItemIds from both locations
print("\n🔍 PHASE 1: Scanning for existing ItemIds...")
local allExistingIds = {}
local globalMaxId = 0

if workspaceItems then
    local wsIds, wsMaxId = collectExistingItemIds(workspaceItems)
    for id, _ in pairs(wsIds) do
        allExistingIds[id] = true
    end
    globalMaxId = math.max(globalMaxId, wsMaxId)
    print("Workspace.Items scan complete. Max ID found:", wsMaxId)
end

if serverStorageItems then
    local ssIds, ssMaxId = collectExistingItemIds(serverStorageItems)
    for id, _ in pairs(ssIds) do
        allExistingIds[id] = true
    end
    globalMaxId = math.max(globalMaxId, ssMaxId)
    print("ServerStorage.Items scan complete. Max ID found:", ssMaxId)
end

-- Determine starting point for new IDs
local nextAvailableId = math.max(globalMaxId + 1, 1) -- Start from 1 if no existing IDs found
print("🎯 Starting new ItemId assignments from:", nextAvailableId)

local uniqueIds = 0
for _ in pairs(allExistingIds) do uniqueIds = uniqueIds + 1 end
print("📊 Total existing ItemIds found:", uniqueIds)

-- PHASE 2: Process and assign new ItemIds where needed
print("\n🔧 PHASE 2: Processing models and assigning ItemIds...")

local totalProcessed = 0
local totalUpdated = 0
local totalIdsAssigned = 0

if workspaceItems then
    print("\n--- Processing Workspace.Items ---")
    local processed, updated, idsAssigned, newNextId = processFolder(workspaceItems, "Workspace.Items", allExistingIds, nextAvailableId)
    totalProcessed = totalProcessed + processed
    totalUpdated = totalUpdated + updated
    totalIdsAssigned = totalIdsAssigned + idsAssigned
    nextAvailableId = newNextId
end

if serverStorageItems then
    print("\n--- Processing ServerStorage.Items ---")
    local processed, updated, idsAssigned, newNextId = processFolder(serverStorageItems, "ServerStorage.Items", allExistingIds, nextAvailableId)
    totalProcessed = totalProcessed + processed
    totalUpdated = totalUpdated + updated
    totalIdsAssigned = totalIdsAssigned + idsAssigned
    nextAvailableId = newNextId
end

print("\n=== UNIQUE ITEMID ASSIGNMENT COMPLETE ===")
print("📊 SUMMARY:")
print("Total models processed: " .. totalProcessed)
print("Total models updated: " .. totalUpdated)
print("New ItemIds assigned: " .. totalIdsAssigned)
print("Next available ItemId: " .. (nextAvailableId - 1))
print("🎯 Your numeric ItemId system is now ready for variations!")
print("   Example: Torch_Red = 131, Torch_Blue = 132, Torch_Green = 133")
print("🔧 Pricing accurately reflects Constants.ITEMS and tier-based pricing") 