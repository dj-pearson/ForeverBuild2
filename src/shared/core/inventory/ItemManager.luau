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
    -- We'll use hardcoded items to avoid dependency on Structure.txt
    print("Loading default items...")
    self:LoadDefaultItems()
    return true
end

function ItemManager:LoadDefaultItems()
    print("Using default item definitions")
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
        },
        {
            id = "glow_red_cube",
            name = "Red Glowing Cube",
            price = 300,
            model = nil
        },
        {
            id = "trampoline",
            name = "Trampoline",
            price = 750,
            model = nil
        }
    }
    
    -- Setup minimal categories
    self.categories = {
        basic = {"brick_cube", "wood_cube", "stone_cube", "glass_cube"},
        glow = {"glow_red_cube"},
        interactive = {"trampoline"}
    }
    
    -- Setup some basic interactions
    self.interactions = {
        trampoline = {"jump", "examine"}
    }
    
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
