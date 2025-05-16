--[[
    FixItemTypes.luau
    Patches the InteractionSystemModule_new to add missing item types
]]

local module = {}

-- This function will be called to apply the fix
function module.applyFix()
    print("Applying fix for missing item types...")
    
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
        
        -- Check if the GetItemInfo function exists
        if typeof(InteractionSystemModule.GetItemInfo) == "function" then
            -- Create a wrapper around the original function
            local originalGetItemInfo = InteractionSystemModule.GetItemInfo
            
            -- Replace with our safer version
            InteractionSystemModule.GetItemInfo = function(itemType, ...)
                -- Default values to return if itemType is nil or not found
                if not itemType then
                    warn("GetItemInfo called with nil itemType")
                    return {
                        name = "Unknown Item",
                        price = { INGAME = 10, ROBUX = 10 },
                        description = "Missing item information"
                    }
                end
                
                -- Handle case where itemType is a table (e.g. an item instance)
                local itemTypeString = itemType
                if typeof(itemType) == "table" then
                    warn("GetItemInfo received a table instead of string for itemType: " .. tostring(itemType))
                    -- Try to extract a usable string identifier from the table
                    
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
                        end
                    end
                    
                    -- Fallbacks if attributes didn't work
                    if itemTypeString == itemType then
                        if itemType.Name then
                            itemTypeString = itemType.Name
                        elseif itemType.Type then
                            itemTypeString = itemType.Type
                        elseif itemType.ItemType then
                            itemTypeString = itemType.ItemType
                        else
                            itemTypeString = "Unknown_Item_" .. tostring(math.random(1000, 9999))
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
                end
                
                -- Ensure Constants.ITEMS exists and has the requested item
                if Constants and Constants.ITEMS and Constants.ITEMS[itemTypeString] then
                    -- The item exists, call original function with original parameters
                    -- to maintain compatibility with the rest of the system
                    return originalGetItemInfo(itemType, ...)
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
                            
                        Constants.ITEMS[itemTypeString] = {
                            name = displayName,
                            price = { INGAME = 10, ROBUX = 10 },
                            description = "Generated item information"
                        }
                        print("Added missing item type to Constants.ITEMS: " .. tostring(itemTypeString))
                    end
                    
                    -- Return a default
                    local displayName = typeof(itemTypeString) == "string" 
                        and itemTypeString:gsub("_", " ") 
                        or "Unknown Item"
                        
                    return {
                        name = displayName,
                        price = { INGAME = 10, ROBUX = 10 },
                        description = "Generated item information"
                    }
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

-- Auto-apply fix when this module is required
local success, result = pcall(module.applyFix)
if not success then
    warn("Failed to apply fix for item types:", result)
end

return module 