local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Parent.Constants)

local ItemManager = {}
ItemManager.__index = ItemManager

function ItemManager.new()
    local self = setmetatable({}, ItemManager)
    self.items = {}
    self.adminUsers = {} -- List of user IDs that are admins
    return self
end

function ItemManager:Initialize()
    print("ItemManager initialized")
    self:LoadItems()
end

function ItemManager:LoadItems()
    -- Try to load items from Structure.txt in GameData
    local success, items = pcall(function()
        -- Look for Structure.txt in multiple possible locations
        local structureFile
        
        -- Try in ReplicatedStorage.GameData
        if ReplicatedStorage:FindFirstChild("GameData") and 
           ReplicatedStorage.GameData:FindFirstChild("Structure.txt") then
            structureFile = ReplicatedStorage.GameData.Structure.txt
        end
        
        -- Try in ServerStorage.GameData if not found
        if not structureFile and game:GetService("ServerStorage"):FindFirstChild("GameData") and
           game:GetService("ServerStorage").GameData:FindFirstChild("Structure.txt") then
            structureFile = game:GetService("ServerStorage").GameData.Structure.txt
        end
        
        -- Try at workspace root
        if not structureFile and workspace:FindFirstChild("Structure.txt") then
            structureFile = workspace.Structure.txt
        end
        
        if structureFile then
            print("Found Structure.txt, loading items...")
            return self:ParseItemsFromStructure(structureFile.Value)
        else
            error("Structure.txt not found")
        end
    end)
    
    if not success then
        print("Warning: Failed to load items from Structure.txt: " .. tostring(items))
        print("Using fallback item definitions")
        -- Fallback to default items
        self.items = {
            {
                id = "cube_red",
                name = "Red Cube",
                price = 100,
                model = nil -- TODO: Load model
            },
            {
                id = "cube_blue",
                name = "Blue Cube",
                price = 150,
                model = nil -- TODO: Load model
            }
        }
    else
        self.items = items
        print("Successfully loaded " .. #self.items .. " items from Structure.txt")
    end
end

function ItemManager:ParseItemsFromStructure(structureText)
    local items = {}
    local inItemSection = false
    
    -- Simple parser to extract item information from Structure.txt
    for line in string.gmatch(structureText, "[^\r\n]+") do
        if string.match(line, "^%s*%[Items%]%s*$") then
            inItemSection = true
        elseif inItemSection and string.match(line, "^%s*%[") then
            inItemSection = false
        elseif inItemSection then
            -- Parse item entry, expected format: id=name,price
            local id, details = string.match(line, "^%s*([%w_]+)%s*=%s*(.+)")
            if id and details then
                local name, price = string.match(details, "^(.+),(%d+)$")
                if name and price then
                    table.insert(items, {
                        id = id,
                        name = name,
                        price = tonumber(price),
                        model = nil -- Will be loaded later
                    })
                end
            end
        end
    end
    
    return items
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
    -- Fallback to old logic if not found
    local item = self:GetItemData(itemId)
    return item and item.price or nil
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

return ItemManager
