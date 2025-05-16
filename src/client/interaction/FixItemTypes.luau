--[[
    FixItemTypes.luau
    Patches the InteractionSystemModule_new to add missing item types
]]

local module = {}

-- This function will be called to apply the fix
function module.applyFix()
    print("Applying fix for missing item types...")
    
    -- Get player reference for admin checks
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local localPlayerId = localPlayer and localPlayer.UserId or 0
    
    -- First locate the InteractionSystemModule_new
    local InteractionSystemModule = nil
    
    -- Try to find in the same folder
    local success, result = pcall(function()
        local script = script
        if script.Parent:FindFirstChild("InteractionSystemModule_new") then
            return require(script.Parent.InteractionSystemModule_new)
        end
        return nil
    end)
    
    if success and result then
        InteractionSystemModule = result
        print("Found InteractionSystemModule_new, applying fix")
        
        -- Helper function to ensure price is in the correct format
        local function ensurePriceFormat(price)
            if typeof(price) == "number" then
                return { INGAME = price, ROBUX = price }
            elseif typeof(price) == "table" and not price.INGAME then
                -- Try to guess the structure from what's available
                if price.ingame or price.Ingame or price.InGame then
                    return { 
                        INGAME = price.ingame or price.Ingame or price.InGame,
                        ROBUX = price.robux or price.Robux or 10
                    }
                else
                    -- Default values
                    return { INGAME = 10, ROBUX = 10 }
                end
            end
            -- Already correct format or unknown, return as is
            return price
        end
        
        -- Helper function to check if player is an admin
        local function isAdmin(playerId, Constants)
            if not playerId or not Constants then return false end
            
            -- Check if ADMIN_IDS exists in Constants
            if not Constants.ADMIN_IDS then 
                -- Add admin IDs to Constants if missing
                Constants.ADMIN_IDS = { 7768610061 } -- Main admin ID
                print("Added ADMIN_IDS to Constants")
            end
            
            -- Check if player ID is in admin list
            for _, adminId in ipairs(Constants.ADMIN_IDS) do
                if playerId == adminId then
                    return true
                end
            end
            
            return false
        end
        
        -- Patch the ShowInteractionUI function if it exists to handle different price formats
        if typeof(InteractionSystemModule.ShowInteractionUI) == "function" then
            local originalShowInteractionUI = InteractionSystemModule.ShowInteractionUI
            
            InteractionSystemModule.ShowInteractionUI = function(item, ...)
                -- Make sure item exists
                if not item then
                    return originalShowInteractionUI(item, ...)
                end
                
                -- Get Constants reference
                local Constants = nil
                pcall(function()
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local shared = ReplicatedStorage:FindFirstChild("shared")
                    if shared then
                        Constants = require(shared).Constants
                    end
                end)
                
                -- Check and fix price structure before passing to original function
                if item and typeof(item) == "table" and item.price then
                    -- Save the original price for non-admins
                    local originalPrice = item.price
                    
                    -- Format the price properly
                    item.price = ensurePriceFormat(item.price)
                    
                    -- If player is an admin, set price to 0
                    if isAdmin(localPlayerId, Constants) then
                        print("Admin detected! Setting price to 0 for: " .. (item.name or "Unknown Item"))
                        item.originalPrice = item.price -- Store original price
                        item.price = { INGAME = 0, ROBUX = 0 } -- Free for admins
                    end
                end
                
                return originalShowInteractionUI(item, ...)
            end
            
            print("Successfully patched ShowInteractionUI function to handle price formats and admin checks")
        end
        
        -- Also fix the Update function which might be dealing with price information
        if typeof(InteractionSystemModule.Update) == "function" then
            local originalUpdate = InteractionSystemModule.Update
            
            InteractionSystemModule.Update = function(...)
                return originalUpdate(...)
            end
            
            print("Successfully patched Update function")
        end
        
        -- Check if there's a purchase function that needs admin logic
        if typeof(InteractionSystemModule.PurchaseItem) == "function" then
            local originalPurchaseItem = InteractionSystemModule.PurchaseItem
            
            InteractionSystemModule.PurchaseItem = function(item, ...)
                if item then
                    -- Get Constants reference
                    local Constants = nil
                    pcall(function()
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local shared = ReplicatedStorage:FindFirstChild("shared")
                        if shared then
                            Constants = require(shared).Constants
                        end
                    end)
                    
                    -- If player is an admin, set price to 0 for the purchase
                    if isAdmin(localPlayerId, Constants) and item.price then
                        local originalPrice = item.price
                        item.price = { INGAME = 0, ROBUX = 0 } -- Free for admins
                        local result = originalPurchaseItem(item, ...)
                        item.price = originalPrice -- Restore original price
                        return result
                    end
                end
                
                return originalPurchaseItem(item, ...)
            end
            
            print("Successfully patched PurchaseItem function for admin free items")
        end
        
        -- Check if the GetItemInfo function exists
        if typeof(InteractionSystemModule.GetItemInfo) == "function" then
            -- Create a wrapper around the original function
            local originalGetItemInfo = InteractionSystemModule.GetItemInfo
            
            -- Replace with our safer version
            InteractionSystemModule.GetItemInfo = function(itemType, ...)
                -- Create a default item structure with all necessary fields
                local defaultItem = {
                    name = "Unknown Item",
                    price = { INGAME = 10, ROBUX = 10 },
                    description = "Generated item information",
                    tier = "BASIC", -- Add tier information
                    category = "Basic", -- Add category
                    interactions = {"examine", "pick up", "place"}, -- Basic interactions
                    icon = "rbxassetid://3284930147", -- Default icon
                    properties = {} -- Empty properties table
                }
                
                -- Default values to return if itemType is nil or not found
                if not itemType then
                    warn("GetItemInfo called with nil itemType")
                    return defaultItem
                end
                
                -- Handle case where itemType is a table (e.g. an item instance)
                local itemTypeString = itemType
                local originalItem = itemType
                
                if typeof(itemType) == "table" then
                    warn("GetItemInfo received a table instead of string for itemType: " .. tostring(itemType))
                    
                    -- Check if item has a price field and ensure it's correctly formatted
                    if itemType.price then
                        itemType.price = ensurePriceFormat(itemType.price)
                    end
                    
                    -- Try multiple approaches to identify the item
                    
                    -- First check if it's a Roblox instance with attributes
                    if typeof(itemType) == "Instance" then
                        -- Check for name attribute first (new system)
                        local nameAttribute = itemType:GetAttribute("name")
                        if nameAttribute and typeof(nameAttribute) == "string" then
                            itemTypeString = nameAttribute
                            print("Using 'name' attribute for item identification: " .. itemTypeString)
                            
                        -- Then check for item attribute (old system)
                        elseif itemType:GetAttribute("item") and typeof(itemType:GetAttribute("item")) == "string" then
                            itemTypeString = itemType:GetAttribute("item")
                            print("Using 'item' attribute for item identification: " .. itemTypeString)
                            
                        -- If it's an Instance with a Name property, try to normalize it to match structure format
                        elseif itemType.Name then
                            -- Convert to expected format (lowercase with underscores)
                            local normalizedName = itemType.Name:lower():gsub(" ", "_")
                            print("Normalized model name from '" .. itemType.Name .. "' to '" .. normalizedName .. "'")
                            itemTypeString = normalizedName
                            
                            -- Try to find the parent folder name to use as category prefix if needed
                            if itemType.Parent and itemType.Parent:IsA("Folder") then
                                local category = itemType.Parent.Name:lower()
                                -- If the name doesn't already include the category, prepend it
                                if not normalizedName:find(category:lower()) then
                                    if category ~= "basic" then -- Don't prefix basic items
                                        itemTypeString = category:lower() .. "_" .. normalizedName
                                        print("Added category prefix: " .. itemTypeString)
                                    end
                                end
                                
                                -- Store the category for later use in the default item
                                defaultItem.category = itemType.Parent.Name
                                
                                -- Try to determine tier based on parent folder
                                local tierMap = {
                                    ["Basic"] = "BASIC",
                                    ["Level_1"] = "LEVEL_1",
                                    ["Level_2"] = "LEVEL_2", 
                                    ["Rare"] = "RARE",
                                    ["Exclusive"] = "EXCLUSIVE",
                                    ["Weapons"] = "WEAPONS",
                                    ["Free_items"] = "FREE_ITEMS",
                                    ["Random_Drop"] = "RARE_DROP"
                                }
                                
                                if tierMap[itemType.Parent.Name] then
                                    defaultItem.tier = tierMap[itemType.Parent.Name]
                                    print("Set item tier to " .. defaultItem.tier .. " based on parent folder")
                                end
                            end
                        end
                    end
                    
                    -- If still no success, try other properties
                    if itemTypeString == originalItem then
                        if itemType.Name then
                            itemTypeString = itemType.Name
                        elseif itemType.Type then
                            itemTypeString = itemType.Type
                        elseif itemType.ItemType then
                            itemTypeString = itemType.ItemType
                        else
                            -- Last resort: use a consistent ID for the same object
                            -- This helps avoid creating multiple random entries for the same item
                            local hash = tostring(originalItem):match("table: 0x([%w]+)")
                            local id = hash and hash:sub(-4) or tostring(math.random(1000, 9999))
                            itemTypeString = "Unknown_Item_" .. id
                        end
                        print("Converted table itemType to string: " .. itemTypeString)
                    end
                end
                
                -- Get a reference to Constants
                local Constants = nil
                local success, result = pcall(function()
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local shared = ReplicatedStorage:FindFirstChild("shared")
                    if shared then
                        local sharedModule = require(shared)
                        if sharedModule and sharedModule.Constants then
                            return sharedModule.Constants
                        end
                    end
                    return nil
                end)
                
                if success and result then
                    Constants = result
                    
                    -- Ensure ADMIN_IDS exists in Constants
                    if not Constants.ADMIN_IDS then
                        Constants.ADMIN_IDS = { 7768610061 } -- Main admin ID
                        print("Added ADMIN_IDS to Constants")
                    end
                    
                    -- Patch all existing Constants.ITEMS entries to have proper price format
                    if Constants.ITEMS then
                        print("Ensuring all Constants.ITEMS have proper price structure")
                        for k, v in pairs(Constants.ITEMS) do
                            if v.price then
                                v.price = ensurePriceFormat(v.price)
                            end
                        end
                    end
                end
                
                -- Try multiple ways to find the item in Constants
                local found = false
                if Constants and Constants.ITEMS then
                    -- Check exact match first
                    if Constants.ITEMS[itemTypeString] then
                        found = true
                    else
                        -- Try case-insensitive match
                        for key, _ in pairs(Constants.ITEMS) do
                            if key:lower() == itemTypeString:lower() then
                                itemTypeString = key
                                found = true
                                break
                            end
                        end
                        
                        -- Try partial match as last resort
                        if not found then
                            for key, _ in pairs(Constants.ITEMS) do
                                if key:lower():find(itemTypeString:lower()) or itemTypeString:lower():find(key:lower()) then
                                    print("Found partial match: " .. key .. " for " .. itemTypeString)
                                    itemTypeString = key
                                    found = true
                                    break
                                end
                            end
                        end
                    end
                end
                
                -- Make sure tier information exists in Constants
                if Constants and not Constants.ITEM_PRICES then
                    Constants.ITEM_PRICES = {
                        BASIC = { INGAME = 5, ROBUX = 5 },
                        LEVEL_1 = { INGAME = 10, ROBUX = 10 },
                        LEVEL_2 = { INGAME = 25, ROBUX = 25 },
                        RARE = { INGAME = 100, ROBUX = 100 },
                        EXCLUSIVE = { INGAME = 1000, ROBUX = 1000 },
                        WEAPONS = { INGAME = 500, ROBUX = 500 },
                        RARE_DROP = { INGAME = 800, ROBUX = 800 },
                        FREE_ITEMS = { INGAME = 0, ROBUX = 0 }
                    }
                    print("Created fallback ITEM_PRICES in Constants")
                end
                
                -- Ensure Constants.ITEMS exists and has the requested item
                if Constants and Constants.ITEMS and Constants.ITEMS[itemTypeString] then
                    -- Ensure the price field is properly formatted
                    if Constants.ITEMS[itemTypeString].price then
                        Constants.ITEMS[itemTypeString].price = ensurePriceFormat(Constants.ITEMS[itemTypeString].price)
                    end
                    
                    -- The item exists, call original function with original parameters
                    local result = originalGetItemInfo(itemType, ...)
                    
                    -- Double check result has proper price structure
                    if result and result.price then
                        result.price = ensurePriceFormat(result.price)
                        
                        -- If player is an admin, set price to 0
                        if isAdmin(localPlayerId, Constants) then
                            result.originalPrice = result.price  -- Save original price for reference
                            result.price = { INGAME = 0, ROBUX = 0 }  -- Free for admins
                        end
                    end
                    
                    return result
                else
                    -- Item doesn't exist, return a default
                    warn("Missing item type in Constants.ITEMS: " .. tostring(itemTypeString))
                    
                    -- Add it to Constants.ITEMS if possible to prevent future errors
                    if Constants and not Constants.ITEMS then
                        Constants.ITEMS = {}
                    end
                    
                    if Constants and Constants.ITEMS then
                        local displayName = typeof(itemTypeString) == "string" 
                            and itemTypeString:gsub("_", " ") 
                            or "Unknown Item"
                            
                        defaultItem.name = displayName
                        
                        -- If player is an admin, set price to 0
                        if isAdmin(localPlayerId, Constants) then
                            defaultItem.originalPrice = defaultItem.price  -- Save original price
                            defaultItem.price = { INGAME = 0, ROBUX = 0 }  -- Free for admins
                        end
                        
                        Constants.ITEMS[itemTypeString] = defaultItem
                        print("Added missing item type to Constants.ITEMS: " .. tostring(itemTypeString))
                    end
                    
                    -- Set item display name
                    if typeof(itemTypeString) == "string" then
                        defaultItem.name = itemTypeString:gsub("_", " ")
                    end
                    
                    return defaultItem
                end
            end
            
            print("Successfully patched GetItemInfo function")
            return true
        else
            warn("Could not find GetItemInfo function in InteractionSystemModule_new")
        end
    else
        warn("Failed to find InteractionSystemModule_new:", result)
    end
    
    return false
end

-- Create a utility function to fix an item's price format
function module.ensurePriceFormat(price)
    if typeof(price) == "number" then
        return { INGAME = price, ROBUX = price }
    elseif typeof(price) == "table" and not price.INGAME then
        if price.ingame or price.Ingame or price.InGame then
            return { 
                INGAME = price.ingame or price.Ingame or price.InGame,
                ROBUX = price.robux or price.Robux or 10
            }
        end
        return { INGAME = 10, ROBUX = 10 }
    end
    return price  -- Already in correct format
end

-- Check if player is an admin
function module.isAdmin(userId)
    if not userId then return false end
    
    -- Get Constants
    local Constants = nil
    pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local shared = ReplicatedStorage:FindFirstChild("shared")
        if shared then
            Constants = require(shared).Constants
        end
    end)
    
    if Constants and Constants.ADMIN_IDS then
        for _, adminId in ipairs(Constants.ADMIN_IDS) do
            if userId == adminId then
                return true
            end
        end
    end
    
    return false
end

-- Auto-apply fix when this module is required
local success, result = pcall(module.applyFix)
if not success then
    warn("Failed to apply fix for item types:", result)
end

return module 