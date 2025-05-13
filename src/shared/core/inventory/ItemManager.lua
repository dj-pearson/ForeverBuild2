local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Constants = require(script.Parent.Parent.Constants)

local ItemManager = {}
ItemManager.__index = ItemManager

function ItemManager.new()
    local self = setmetatable({}, ItemManager)
    self.items = {}
    self.categories = {}
    self.properties = {}
    self.tiers = {}
    self.tierAssignments = {}
    self.interactions = {}
    self.adminUsers = {} -- List of user IDs that are admins
    return self
end

function ItemManager:Initialize()
    print("Initializing ItemManager...")
    local success = self:LoadItems()
    if success then
        print("ItemManager successfully loaded " .. #self.items .. " items")
    else
        warn("ItemManager failed to load items properly, using fallback data")
    end
end

function ItemManager:LoadItems()
    -- Try to load items from Structure.txt in GameData
    local success, result = pcall(function()
        -- Look for Structure.txt in multiple possible locations
        local structureFile
        local structureText = ""
        
        -- Try in ReplicatedStorage.GameData
        if ReplicatedStorage:FindFirstChild("GameData") and 
           ReplicatedStorage.GameData:FindFirstChild("Structure") then
            structureFile = ReplicatedStorage.GameData.Structure
            structureText = structureFile.Value
            print("Found Structure.txt in ReplicatedStorage.GameData")
        end
        
        -- Try in ServerStorage.GameData if not found
        if not structureFile and ServerStorage:FindFirstChild("GameData") and
           ServerStorage.GameData:FindFirstChild("Structure") then
            structureFile = ServerStorage.GameData.Structure
            structureText = structureFile.Value
            print("Found Structure.txt in ServerStorage.GameData")
        end
        
        -- Try at workspace root
        if not structureFile and workspace:FindFirstChild("Structure") then
            structureFile = workspace.Structure
            structureText = structureFile.Value
            print("Found Structure.txt in workspace")
        end
        
        if not structureText or structureText == "" then            -- If we can't find it in game, try to load from file directly
            local scriptPath = script:GetFullName()
            local basePath = string.match(scriptPath, "^(.*[/\\])") or ""
            
            -- Try direct reference
            local structureModule = require(script.Parent.Parent.Parent.Parent.Structure)
            if structureModule then
                structureText = structureModule
                print("Found Structure via module require")
            end
            
            if not structureText or structureText == "" then
                error("Structure.txt not found or empty")
                return false
            end
        end
        
        if structureText and structureText ~= "" then
            self:ParseStructureData(structureText)
            return true
        else
            error("Structure.txt not found or empty")
            return false
        end
    end)
    
    if not success then
        warn("Failed to load items from Structure.txt: " .. tostring(result))
        -- Fallback to default items
        self:LoadDefaultItems()
        return false
    end
    
    return true
end

function ItemManager:LoadDefaultItems()
    print("Using fallback item definitions")
    self.items = {
        {
            id = "brick_cube",
            name = "Brick Cube",
            price = 100,
            model = nil
        },
        {
            id = "wood_cube",
            name = "Wood Cube",
            price = 150,
            model = nil
        },
        {
            id = "stone_cube",
            name = "Stone Cube",
            price = 175,
            model = nil
        },
        {
            id = "glass_cube",
            name = "Glass Cube",
            price = 200,
            model = nil
        }
    }
    
    -- Setup minimal categories
    self.categories = {
        basic = {"brick_cube", "wood_cube", "stone_cube", "glass_cube"}
    }
end

function ItemManager:ParseStructureData(structureText)
    local currentSection = nil
    
    -- Reset data structures
    self.items = {}
    self.categories = {}
    self.properties = {}
    self.tiers = {}
    self.tierAssignments = {}
    self.interactions = {}
    
    -- Create a table to quickly lookup items by ID
    local itemsById = {}
    
    -- Parse the structure file line by line
    for line in string.gmatch(structureText, "[^\r\n]+") do
        -- Skip empty lines and comments
        if line:match("^%s*$") or line:match("^%s*#") then
            -- Skip this line (empty or comment)
        
        -- Check for section headers
        elseif line:match("^%s*%[(.+)%]%s*$") then
            currentSection = line:match("^%s*%[(.+)%]%s*$")
            print("Parsing section: " .. currentSection)
            
        -- Process items
        elseif currentSection == "Items" then
            local id, details = line:match("^%s*([%w_]+)%s*=%s*(.+)")
            if id and details then
                local name, price = details:match("^(.+),(%d+)$")
                if name and price then
                    local item = {
                        id = id,
                        name = name,
                        price = tonumber(price),
                        model = nil -- Will be loaded later
                    }
                    table.insert(self.items, item)
                    itemsById[id] = item
                    print("Added item: " .. id .. " = " .. name .. ", " .. price)
                end
            end
            
        -- Process categories
        elseif currentSection == "Categories" then
            local categoryName, items = line:match("^%s*([%w_]+)%s*=%s*(.+)")
            if categoryName and items then
                self.categories[categoryName] = {}
                for itemId in string.gmatch(items, "([^,]+)") do
                    itemId = itemId:match("^%s*(.-)%s*$") -- Trim whitespace
                    table.insert(self.categories[categoryName], itemId)
                end
                print("Added category: " .. categoryName .. " with " .. #self.categories[categoryName] .. " items")
            end
            
        -- Process properties
        elseif currentSection == "Properties" then
            local itemId, propString = line:match("^%s*([%w_]+)%s*=%s*(.+)")
            if itemId and propString then
                self.properties[itemId] = {}
                for prop in string.gmatch(propString, "([^,]+)") do
                    local key, value = prop:match("([^:]+):(.+)")
                    if key and value then
                        key = key:match("^%s*(.-)%s*$") -- Trim whitespace
                        value = value:match("^%s*(.-)%s*$") -- Trim whitespace
                        self.properties[itemId][key] = value
                    end
                end
                print("Added properties for: " .. itemId)
            end
            
        -- Process tiers
        elseif currentSection == "Tiers" then
            local tierName, price = line:match("^%s*([%w_]+)%s*=%s*(%d+)")
            if tierName and price then
                self.tiers[tierName] = tonumber(price)
                print("Added tier: " .. tierName .. " = " .. price)
            end
            
        -- Process tier assignments
        elseif currentSection == "TierAssignments" then
            local tierName, items = line:match("^%s*([%w_]+)%s*=%s*(.+)")
            if tierName and items then
                self.tierAssignments[tierName] = {}
                for itemId in string.gmatch(items, "([^,]+)") do
                    itemId = itemId:match("^%s*(.-)%s*$") -- Trim whitespace
                    table.insert(self.tierAssignments[tierName], itemId)
                end
                print("Added tier assignment: " .. tierName .. " with " .. #self.tierAssignments[tierName] .. " items")
            end
            
        -- Process interactions
        elseif currentSection == "Interactions" then
            local itemId, interactions = line:match("^%s*([%w_]+)%s*=%s*(.+)")
            if itemId and interactions then
                self.interactions[itemId] = {}
                for interaction in string.gmatch(interactions, "([^,]+)") do
                    interaction = interaction:match("^%s*(.-)%s*$") -- Trim whitespace
                    table.insert(self.interactions[itemId], interaction)
                end
                print("Added interactions for: " .. itemId)
            end
        end
    end
    
    -- Apply properties to items
    for itemId, props in pairs(self.properties) do
        local item = itemsById[itemId]
        if item then
            for key, value in pairs(props) do
                item[key] = value
            end
        end
    end
    
    print("Structure parsing complete")
    print("Items: " .. #self.items)
    
    local categoriesCount = 0
    for _ in pairs(self.categories) do
        categoriesCount = categoriesCount + 1
    end
    print("Categories: " .. categoriesCount)
    
    return true
end

function ItemManager:IsAdmin(player)
    return self.adminUsers[player.UserId] == true
end

function ItemManager:IsItemFree(itemId, player)
    -- Use the new pricing logic
    local price = self:GetActionPrice(itemId, Constants.ITEM_ACTIONS.BUY, player)
    return price == 0
end

function ItemManager:GetActionPrice(itemId, action, player)
    -- First check tier-based pricing
    for tierName, items in pairs(self.tierAssignments) do
        for _, id in ipairs(items) do
            if id == itemId then
                return self.tiers[tierName] or 0
            end
        end
    end
    
    -- Look for the item model in Workspace > Items
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        for _, model in ipairs(itemsFolder:GetChildren()) do
            if model:IsA("Model") and model:GetAttribute("item") and model.Name == itemId then
                local tier = model:GetAttribute("item")
                local price = Constants.ITEM_PRICING[tier]
                if price then
                    return price
                end
            end
        end
    end
    
    -- Fallback to item's direct price
    local item = self:GetItemData(itemId)
    return item and item.price or 0
end

function ItemManager:GetItemData(itemId)
    for _, item in ipairs(self.items) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

function ItemManager:GetItemModel(itemId)
    local item = self:GetItemData(itemId)
    return item and item.model
end

function ItemManager:GetItemsByCategory(categoryName)
    local category = self.categories[categoryName]
    if not category then
        return {}
    end
    
    local items = {}
    for _, itemId in ipairs(category) do
        local item = self:GetItemData(itemId)
        if item then
            table.insert(items, item)
        end
    end
    
    return items
end

function ItemManager:GetItemInteractions(itemId)
    return self.interactions[itemId] or {"examine"}
end

function ItemManager:GetAllCategories()
    local result = {}
    for categoryName, _ in pairs(self.categories) do
        table.insert(result, categoryName)
    end
    return result
end

return ItemManager
