-- PlacementManager.luau
-- Manages the placement, recall, and persistence of items in the world

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

local PlacementManager = {}
PlacementManager.__index = PlacementManager

-- Configuration
local PLACED_ITEMS_FOLDER_NAME = "World_Items" -- Use the existing World_Items folder
local MAX_PLACEMENT_DISTANCE = 20
local GRID_SIZE = 1 -- For grid snapping

-- Initialize the PlacementManager
function PlacementManager.new(sharedModule)
    local self = setmetatable({}, PlacementManager)
    
    self.shared = sharedModule
    self.Constants = sharedModule.Constants
    self.remotes = {}
    
    -- Setup the world folder for placed items
    if isServer then
        -- First look for the main World_Items folder
        self.worldFolder = Workspace:FindFirstChild(PLACED_ITEMS_FOLDER_NAME)
        if not self.worldFolder then
            print("PlacementManager: Creating World_Items folder")
            self.worldFolder = Instance.new("Folder")
            self.worldFolder.Name = PLACED_ITEMS_FOLDER_NAME
            self.worldFolder.Parent = Workspace
        end
        
        -- Set up subfolders for different item types
        self.staticFolder = self.worldFolder:FindFirstChild("Static")
        if not self.staticFolder then
            print("PlacementManager: Creating Static folder")
            self.staticFolder = Instance.new("Folder")
            self.staticFolder.Name = "Static"
            self.staticFolder.Parent = self.worldFolder
        end
        
        self.placedFolder = self.worldFolder:FindFirstChild("Placed")
        if not self.placedFolder then
            print("PlacementManager: Creating Placed folder")
            self.placedFolder = Instance.new("Folder")
            self.placedFolder.Name = "Placed"
            self.placedFolder.Parent = self.worldFolder
        end
        
        -- Also look for legacy PlacedItems folder for backward compatibility
        self.legacyPlacedFolder = Workspace:FindFirstChild("PlacedItems")
        if not self.legacyPlacedFolder then
            print("PlacementManager: No legacy PlacedItems folder found, will use World_Items/Placed")
        else
            print("PlacementManager: Found legacy PlacedItems folder, will monitor both")
        end
        
        -- Keep track of placed items by player
        self.placedItemsByPlayer = {}
        
        -- Setup tracking attributes
        self.worldFolder:SetAttribute("PlacementManagerTrackingEnabled", true)
        self.worldFolder:SetAttribute("PlacementManagerInitTime", os.time())
        
        -- Note: The following initialization is now moved to the Initialize method:
        -- - ConnectPlayerEvents()
        -- - LoadWorldData()
    else
        -- Client-side properties
        self.previewItem = nil
        self.isPlacing = false
        self.selectedItem = nil
    end
    
    return self
end

-- Initialize the PlacementManager
function PlacementManager:Initialize()
    if not isServer then return false end
    
    print("PlacementManager: Initialize called")
    
    -- Set up remote events for placement system
    self:SetupRemoteEvents()
    
    -- Connect player events for saving
    self:ConnectPlayerEvents()
    
    -- Load world data from DataStore
    task.spawn(function()
        task.wait(2) -- Give DataService time to initialize
        self:LoadWorldData()
    end)
    
    print("PlacementManager: Initialization completed")
    return true
end

-- Get an item template from ReplicatedStorage or other sources
function PlacementManager:GetItemTemplate(itemId)
    print("PlacementManager: Getting template for item:", itemId)
    
    -- Normalize the itemId (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- First check in ReplicatedStorage.ItemTemplates
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if not templates then
        -- Try to create templates folder on server if missing
        if isServer then
            print("PlacementManager: ItemTemplates folder not found, creating it")
            templates = Instance.new("Folder")
            templates.Name = "ItemTemplates"
            templates.Parent = ReplicatedStorage
            
            -- Create basic templates
            local basicTemplates = {
                { name = "Grass_Cube", color = "Bright green", material = "Grass" },
                { name = "Stone_Cube", color = "Medium stone grey", material = "Slate" },
                { name = "Wood_Plank", color = "Brown", material = "Wood" },
                { name = "Wood_Cube", color = "Brown", material = "Wood" },
                { name = "Brick_Cube", color = "Brick red", material = "Brick" },
                { name = "Water_Cube", color = "Bright blue", material = "Water", transparency = 0.3 },
                { name = "Glass_Cube", color = "Toothpaste", material = "Glass", transparency = 0.5 }
            }
            
            for _, info in ipairs(basicTemplates) do
                local part = Instance.new("Part")
                part.Name = info.name
                part.Size = Vector3.new(2, 2, 2)
                part.Anchored = true
                part.CanCollide = true
                part.BrickColor = BrickColor.new(info.color)
                part.Material = Enum.Material[info.material]
                if info.transparency then
                    part.Transparency = info.transparency
                end
                part.Parent = templates
                
                print("PlacementManager: Created template:", info.name)
            end
        else
            warn("PlacementManager: ItemTemplates folder not found")
            return nil
        end
    end
    
    -- Debug info
    print("PlacementManager: Available templates in ItemTemplates folder:")
    for _, template in ipairs(templates:GetChildren()) do
        print("  -", template.Name)
    end
    
    -- Try direct match first
    local template = templates:FindFirstChild(normalizedItemId)
    if template then
        print("PlacementManager: Found exact template match:", normalizedItemId)
        return template
    end
    
    -- Try with original itemId
    if normalizedItemId ~= itemId then
        template = templates:FindFirstChild(itemId)
        if template then
            print("PlacementManager: Found template using original itemId:", itemId)
            return template
        end
    end
    
    -- Special case for Wood_Cube - if Wood_Plank exists, create Wood_Cube from it
    if normalizedItemId == "Wood_Cube" then
        local woodPlank = templates:FindFirstChild("Wood_Plank")
        if woodPlank then
            print("PlacementManager: Creating Wood_Cube from Wood_Plank")
            local woodCube = woodPlank:Clone()
            woodCube.Name = "Wood_Cube"
            woodCube.Parent = templates
            return woodCube
        end
    end
    
    -- Try with suffix variations (with and without _Cube)
    local tryWithCube = normalizedItemId
    if not normalizedItemId:lower():find("_cube$") then
        tryWithCube = normalizedItemId .. "_Cube"
    end
    
    template = templates:FindFirstChild(tryWithCube)
    if template then
        print("PlacementManager: Found template with _Cube suffix:", tryWithCube)
        return template
    end
    
    -- Try without the _Cube suffix
    if normalizedItemId:lower():find("_cube$") then
        local tryWithoutCube = normalizedItemId:gsub("_Cube$", "")
        template = templates:FindFirstChild(tryWithoutCube)
        if template then
            print("PlacementManager: Found template without _Cube suffix:", tryWithoutCube)
            return template
        end
    end
    
    -- Try case-insensitive lookup
    for _, potentialTemplate in ipairs(templates:GetChildren()) do
        if potentialTemplate.Name:lower() == normalizedItemId:lower() or
           potentialTemplate.Name:lower() == itemId:lower() then
            print("PlacementManager: Found template using case-insensitive match:", potentialTemplate.Name)
            return potentialTemplate
        end
    end
    
    -- Try to find a template with a similar name as a last resort
    for _, potentialTemplate in ipairs(templates:GetChildren()) do
        if potentialTemplate.Name:lower():find(normalizedItemId:lower()) or
           normalizedItemId:lower():find(potentialTemplate.Name:lower()) then
            print("PlacementManager: Found template with similar name:", potentialTemplate.Name)
            return potentialTemplate
        end
    end
    
    -- If all else fails, create a basic template
    print("PlacementManager: No template found, creating basic template for:", normalizedItemId)
    local newTemplate = Instance.new("Part")
    newTemplate.Name = normalizedItemId
    newTemplate.Size = Vector3.new(2, 2, 2)
    newTemplate.Anchored = true
    newTemplate.CanCollide = true
    
    -- Set appropriate appearance
    if normalizedItemId:lower():find("wood") then
        newTemplate.BrickColor = BrickColor.new("Brown")
        newTemplate.Material = Enum.Material.Wood
    elseif normalizedItemId:lower():find("grass") then
        newTemplate.BrickColor = BrickColor.new("Bright green")
        newTemplate.Material = Enum.Material.Grass
    elseif normalizedItemId:lower():find("stone") then
        newTemplate.BrickColor = BrickColor.new("Medium stone grey")
        newTemplate.Material = Enum.Material.Slate
    elseif normalizedItemId:lower():find("water") then
        newTemplate.BrickColor = BrickColor.new("Bright blue")
        newTemplate.Material = Enum.Material.Water
        newTemplate.Transparency = 0.3
    elseif normalizedItemId:lower():find("glass") then
        newTemplate.BrickColor = BrickColor.new("Toothpaste")
        newTemplate.Material = Enum.Material.Glass
        newTemplate.Transparency = 0.5
    elseif normalizedItemId:lower():find("brick") then
        newTemplate.BrickColor = BrickColor.new("Brick red")
        newTemplate.Material = Enum.Material.Brick
    else
        newTemplate.BrickColor = BrickColor.new("Medium stone grey")
        newTemplate.Material = Enum.Material.Concrete
    end
    
    newTemplate.Parent = templates
    print("PlacementManager: Created new template:", normalizedItemId)
    return newTemplate
end

-- Server: Place an item in the world and persist it
function PlacementManager:PlaceItem(player, itemId, position, rotation)
    if not isServer then return false end
    
    print("PlacementManager: PlaceItem called by", player.Name, "for item", itemId)
    
    -- Normalize item name (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- Validate player data
    local playerData = self:GetPlayerData(player)
    if not playerData then
        warn("PlacementManager: No player data found for", player.Name)
        return false
    end
    
    -- Check if player has the item in inventory
    local hasItem = false
    if playerData.inventory then
        for _, item in ipairs(playerData.inventory) do
            if (item.id and (item.id == itemId or item.id == normalizedItemId)) or 
               (item.name and (item.name == itemId or item.name == normalizedItemId)) then
                hasItem = true
                break
            end
        end
    end
    
    if not hasItem then
        warn("PlacementManager: Player", player.Name, "does not have item", itemId, "in inventory")
        return false
    end
    
    -- Get the item template
    local template = self:GetItemTemplate(normalizedItemId)
    if not template then
        warn("PlacementManager: Failed to find template for", normalizedItemId)
        return false
    end
    
    -- Log template properties for debugging
    print("PlacementManager: Template found for", normalizedItemId)
    if template:IsA("BasePart") then
        print("  - BrickColor:", template.BrickColor.Name)
        print("  - Material:", template.Material.Name)
        print("  - Transparency:", template.Transparency)
    end
    
    -- Clone the template for placement
    local placedItem = template:Clone()
    placedItem.Name = normalizedItemId .. "_" .. player.UserId .. "_" .. os.time()
    
    -- Explicitly set appearance properties based on item type
    if placedItem:IsA("BasePart") then
        -- Ensure correct appearance for specific item types
        if normalizedItemId:lower():find("wood") then
            placedItem.BrickColor = BrickColor.new("Brown")
            placedItem.Material = Enum.Material.Wood
            placedItem.Transparency = 0
        elseif normalizedItemId:lower():find("grass") then
            placedItem.BrickColor = BrickColor.new("Bright green")
            placedItem.Material = Enum.Material.Grass
            placedItem.Transparency = 0
        elseif normalizedItemId:lower():find("stone") then
            placedItem.BrickColor = BrickColor.new("Medium stone grey")
            placedItem.Material = Enum.Material.Slate
            placedItem.Transparency = 0
        elseif normalizedItemId:lower():find("water") then
            placedItem.BrickColor = BrickColor.new("Bright blue")
            placedItem.Material = Enum.Material.Water
            placedItem.Transparency = 0.3
        elseif normalizedItemId:lower():find("glass") then
            placedItem.BrickColor = BrickColor.new("Toothpaste")
            placedItem.Material = Enum.Material.Glass
            placedItem.Transparency = 0.5
        elseif normalizedItemId:lower():find("brick") then
            placedItem.BrickColor = BrickColor.new("Brick red")
            placedItem.Material = Enum.Material.Brick
            placedItem.Transparency = 0
        end
        
        -- Log the actual appearance after setting properties
        print("PlacementManager: Placed item appearance:")
        print("  - BrickColor:", placedItem.BrickColor.Name)
        print("  - Material:", placedItem.Material.Name)
        print("  - Transparency:", placedItem.Transparency)
    end
    
    -- Generate a unique instance ID
    local instanceId = normalizedItemId .. "_" .. player.UserId .. "_" .. tostring(os.time())
    placedItem:SetAttribute("instanceId", instanceId)
    placedItem:SetAttribute("itemId", normalizedItemId)
    placedItem:SetAttribute("owner", player.UserId)
    placedItem:SetAttribute("placedTime", os.time())
    placedItem:SetAttribute("persistent", true)
    
    -- Position and anchor the item
    if placedItem:IsA("Model") and placedItem.PrimaryPart then
        -- Handle rotation properly - rotation can be a Vector3 or a number
        local rotationCFrame
        if typeof(rotation) == "Vector3" then
            -- Use rotation directly as Euler angles
            rotationCFrame = CFrame.fromEulerAnglesXYZ(
                math.rad(rotation.X or 0),
                math.rad(rotation.Y or 0),
                math.rad(rotation.Z or 0)
            )
        else
            -- Use rotation as Y-axis rotation
            rotationCFrame = CFrame.Angles(0, math.rad(rotation or 0), 0)
        end
        
        placedItem:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        
        -- Set all parts to anchored
        for _, part in pairs(placedItem:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = true
            end
        end
    elseif placedItem:IsA("BasePart") then
        -- Handle rotation properly - rotation can be a Vector3 or a number
        local rotationCFrame
        if typeof(rotation) == "Vector3" then
            -- Use rotation directly as Euler angles
            rotationCFrame = CFrame.fromEulerAnglesXYZ(
                math.rad(rotation.X or 0),
                math.rad(rotation.Y or 0),
                math.rad(rotation.Z or 0)
            )
        else
            -- Use rotation as Y-axis rotation
            rotationCFrame = CFrame.Angles(0, math.rad(rotation or 0), 0)
        end
        
        placedItem.CFrame = CFrame.new(position) * rotationCFrame
        placedItem.Anchored = true
        placedItem.CanCollide = true
    end
    
    -- Parent to the placed items folder
    placedItem.Parent = self.placedFolder
    
    -- Add to player's placed items list
    if not self.placedItemsByPlayer[player.UserId] then
        self.placedItemsByPlayer[player.UserId] = {}
    end
    table.insert(self.placedItemsByPlayer[player.UserId], instanceId)
    
    -- Remove from inventory
    self:RemoveFromInventory(player, normalizedItemId)
    
    -- Notify the client
    if self.remotes.ItemPlaced then
        self.remotes.ItemPlaced:FireClient(player, normalizedItemId, instanceId)
        print("PlacementManager: Notified client of placed item:", normalizedItemId)
    end
    
    -- Save world data after placement
    task.spawn(function()
        self:SaveWorldData()
    end)
    
    return true, placedItem
end

-- Server: Remove an item from the player's inventory
function PlacementManager:RemoveFromInventory(player, itemId)
    if not isServer then return false end
    
    print("PlacementManager: Attempting to remove", itemId, "from inventory of", player.Name)
    
    -- Find the server ItemPurchaseHandler
    local ItemPurchaseHandler = nil
    
    -- Try with ItemPurchaseHandler.lua in ServerScriptService
    local success1, result1 = pcall(function()
        return require(game:GetService("ServerScriptService").server.ItemPurchaseHandler)
    end)
    
    if success1 then
        ItemPurchaseHandler = result1
    else
        -- Try direct path lookup
        local serverFolder = game:GetService("ServerScriptService"):FindFirstChild("server")
        if serverFolder then
            local itemPurchaseModule = serverFolder:FindFirstChild("ItemPurchaseHandler")
            if itemPurchaseModule then
                local success2, result2 = pcall(function()
                    return require(itemPurchaseModule)
                end)
                if success2 then
                    ItemPurchaseHandler = result2
                end
            end
        end
        
        -- Try loading from server folder directly
        if not ItemPurchaseHandler then
            local success3, result3 = pcall(function()
                return require(game:GetService("ServerScriptService").ItemPurchaseHandler)
            end)
            if success3 then
                ItemPurchaseHandler = result3
            end
        end
    end
    
    -- 1. Try the direct ItemPurchaseHandler first (most reliable method)
    if ItemPurchaseHandler and ItemPurchaseHandler.RemoveFromInventory then
        local success, result = pcall(function()
            return ItemPurchaseHandler:RemoveFromInventory(player, itemId, 1)
        end)
        
        if success and result then
            print("PlacementManager: Successfully removed item using ItemPurchaseHandler directly")
    return true
        end
    end
    
    -- 2. Try with ItemPurchaseHandler through SharedModule
    if self.shared and self.shared.ItemPurchaseHandler and 
       self.shared.ItemPurchaseHandler.RemoveFromInventory then
        local success, result = pcall(function()
            return self.shared.ItemPurchaseHandler:RemoveFromInventory(player, itemId, 1)
        end)
        
        if success and result then
            print("PlacementManager: Successfully removed item using SharedModule.ItemPurchaseHandler")
            return true
        end
    end
    
    -- 3. Try with InventoryManager if available
    local InventoryManager = self.shared and self.shared.InventoryManager
    if InventoryManager and InventoryManager.RemoveItem then
        local success, result = pcall(function()
            return InventoryManager:RemoveItem(player, itemId, 1)
        end)
        
        if success and result then
            print("PlacementManager: Successfully removed item using InventoryManager")
    return true
        end
    end
    
    -- 4. Last resort - manually update player data
    local playerData = self:GetPlayerData(player)
    if playerData and playerData.inventory then
        local normalizedItemId = itemId:gsub(" ", "_")
        local found = false
        
        for i, item in ipairs(playerData.inventory) do
            if (item.id and (item.id == itemId or item.id == normalizedItemId)) or
               (item.name and (item.name == itemId or item.name == normalizedItemId)) then
                
                local currentCount = item.count or 1
                if currentCount <= 1 then
                    table.remove(playerData.inventory, i)
                else
                    item.count = currentCount - 1
                end
                
                found = true
                print("PlacementManager: Manually removed item from player data")
                
                -- Save the updated player data
                if ItemPurchaseHandler and ItemPurchaseHandler.SavePlayerData then
                    ItemPurchaseHandler:SavePlayerData(player, playerData)
                end
                
            break
        end
    end
    
        if found then
            -- Still fire the remote event so the client is notified
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("RemoveFromInventory") then
                pcall(function()
                    remotes.RemoveFromInventory:FireClient(player, itemId, 1)
                end)
            end
    return true
        end
    end
    
    -- 5. RemoteEvent as absolute last resort
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes and remotes:FindFirstChild("RemoveFromInventory") then
        pcall(function()
            remotes.RemoveFromInventory:FireClient(player, itemId, 1)
        end)
        print("PlacementManager: Sent RemoveFromInventory event to client")
        return true
    end
    
    warn("PlacementManager: Failed to remove item from inventory")
    return false
end

-- Server: Get item data from Constants
function PlacementManager:GetItemData(itemId)
    if not self.Constants then
        warn("PlacementManager: Constants not available, creating fallback")
        self.Constants = {
            ITEMS = {}
        }
    end
    
    if not self.Constants.ITEMS then
        warn("PlacementManager: Constants.ITEMS not available, creating fallback")
        self.Constants.ITEMS = {}
        
        -- Add basic items to Constants.ITEMS as fallback
        local basicItems = {"Grass_Cube", "Stone_Cube", "Brick_Cube", "Wood_Cube", "Glass_Cube", "Water_Cube"}
        for _, itemName in ipairs(basicItems) do
            self.Constants.ITEMS[itemName] = {
                name = itemName,
                price = {INGAME = 10, ROBUX = 10},
                description = "A basic building block",
                tier = "BASIC",
                category = "Building"
            }
        end
    end
    
    -- Normalize the item ID (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- Try direct lookup with original ID
    if self.Constants.ITEMS[itemId] then
        return self.Constants.ITEMS[itemId]
    end
    
    -- Try with normalized ID
    if normalizedItemId ~= itemId and self.Constants.ITEMS[normalizedItemId] then
        print("PlacementManager: Found item using normalized ID:", normalizedItemId)
        return self.Constants.ITEMS[normalizedItemId]
    end
    
    -- Try case-insensitive lookup with both original and normalized IDs
    for key, data in pairs(self.Constants.ITEMS) do
        if key:lower() == itemId:lower() or key:lower() == normalizedItemId:lower() then
            print("PlacementManager: Found item using case-insensitive match:", key)
            return data
        end
    end
    
    -- Try with suffix variations (with and without _Cube)
    local tryWithCube = normalizedItemId
    if not normalizedItemId:lower():find("_cube$") then
        tryWithCube = normalizedItemId .. "_Cube"
    end
    
    if self.Constants.ITEMS[tryWithCube] then
        print("PlacementManager: Found item by adding _Cube suffix:", tryWithCube)
        return self.Constants.ITEMS[tryWithCube]
    end
    
    for key, data in pairs(self.Constants.ITEMS) do
        if key:lower() == tryWithCube:lower() then
            print("PlacementManager: Found item using case-insensitive match with _Cube suffix:", key)
            return data
        end
    end
    
    -- Last resort: Create an item entry for this ID
    print("PlacementManager: Creating fallback item data for:", normalizedItemId)
    local newItemData = {
        name = normalizedItemId,
        price = {INGAME = 10, ROBUX = 10},
        description = "A building item",
        tier = "BASIC",
        category = "Building"
    }
    
    -- Save to Constants for future use
    self.Constants.ITEMS[normalizedItemId] = newItemData
    
    return newItemData
end

-- Server: Create an item in the world
function PlacementManager:CreateWorldItem(itemId, position, rotation)
    if not isServer then return nil end
    
    print("PlacementManager: Creating world item for:", itemId)
    
    -- Normalize item name (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- First try to get the template through our GetItemTemplate method
    local template = self:GetItemTemplate(normalizedItemId)
    
    -- If template found through GetItemTemplate, use it directly
    if template then
        print("PlacementManager: Found template through GetItemTemplate:", template.Name)
    else
        -- Fallback code - try other methods to find template
        print("PlacementManager: GetItemTemplate failed, trying fallback methods...")
        
        -- 1. Check in ReplicatedStorage.ItemTemplates
        local itemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
        if itemTemplates then
            -- Try exact match first
            template = itemTemplates:FindFirstChild(normalizedItemId)
            
            if template then
                print("PlacementManager: Found exact template match in ItemTemplates:", normalizedItemId)
            end
        end
        
        -- 2. If no match, check ServerStorage.Items if it exists
        if not template then
            local serverItems = game:GetService("ServerStorage"):FindFirstChild("Items")
            if serverItems then
                template = serverItems:FindFirstChild(normalizedItemId)
                
                if template then
                    print("PlacementManager: Found template in ServerStorage.Items:", normalizedItemId)
                end
            end
        end
        
        -- 3. Try suffix match - check if the item is actually a cube
        if not template and not normalizedItemId:lower():find("cube") and not normalizedItemId:lower():find("_cube") then
            -- Try appending "_Cube" to the itemId
            local cubeId = normalizedItemId .. "_Cube"
            
            if itemTemplates then
                template = itemTemplates:FindFirstChild(cubeId)
                if template then
                    print("PlacementManager: Found template by appending _Cube:", cubeId)
                end
            end
        end
        
        -- 4. Special case for Wood_Cube - if Wood_Plank exists, create Wood_Cube from it
        if not template and normalizedItemId == "Wood_Cube" and itemTemplates then
            local woodPlank = itemTemplates:FindFirstChild("Wood_Plank")
            if woodPlank then
                print("PlacementManager: Creating Wood_Cube from Wood_Plank")
                template = woodPlank:Clone()
                template.Name = "Wood_Cube"
                template.Parent = itemTemplates
            end
        end
        
        -- 5. If still no match, try with normalized name
        if not template and itemTemplates then
            local normalizedName = normalizedItemId:gsub("_", ""):lower()
            for _, item in ipairs(itemTemplates:GetChildren()) do
                if item.Name:gsub("_", ""):lower() == normalizedName then
                    template = item
                    print("PlacementManager: Found normalized match for", normalizedItemId, "using", item.Name)
                    break
                end
            end
        end
    end
    
    -- If no template found, create a basic cube with appropriate appearance
    if not template then
        print("PlacementManager: No template found for", normalizedItemId, "- creating basic cube")
        template = Instance.new("Part")
        template.Name = normalizedItemId
        template.Size = Vector3.new(2, 2, 2)
        template.Anchored = true
        template.CanCollide = true
        
        -- Set color based on item type
        if normalizedItemId:lower():find("water") then
            template.BrickColor = BrickColor.new("Bright blue")
            template.Transparency = 0.3
            template.Material = Enum.Material.Water
        elseif normalizedItemId:lower():find("fire") or normalizedItemId:lower():find("lava") then
            template.BrickColor = BrickColor.new("Bright red")
            template.Material = Enum.Material.Neon
        elseif normalizedItemId:lower():find("grass") then
            template.BrickColor = BrickColor.new("Bright green")
            template.Material = Enum.Material.Grass
        elseif normalizedItemId:lower():find("sand") then
            template.BrickColor = BrickColor.new("Brick yellow")
            template.Material = Enum.Material.Sand
        elseif normalizedItemId:lower():find("wood") then
            template.BrickColor = BrickColor.new("Brown")
            template.Material = Enum.Material.Wood
        elseif normalizedItemId:lower():find("brick") then
            template.BrickColor = BrickColor.new("Brick red")
            template.Material = Enum.Material.Brick
        elseif normalizedItemId:lower():find("glass") then
            template.BrickColor = BrickColor.new("Institutional white")
            template.Transparency = 0.5
            template.Material = Enum.Material.Glass
        else
            template.BrickColor = BrickColor.new("Medium stone grey")
            template.Material = Enum.Material.Concrete
        end
    end
    
    -- Store template properties for debugging
    print("PlacementManager: Template properties before cloning:")
    if template:IsA("BasePart") then
        print("  - BrickColor:", template.BrickColor.Name)
        print("  - Material:", template.Material.Name)
        print("  - Transparency:", template.Transparency)
    end
    
    -- Clone the template exactly, preserving all properties
    local item = template:Clone()
    print("PlacementManager: Created world item from template:", template.Name)
    
    -- Make sure appearance properties are explicitly set rather than relying on cloning
    if item:IsA("BasePart") then
        if template:IsA("BasePart") then
            item.BrickColor = template.BrickColor
            item.Material = template.Material
            item.Transparency = template.Transparency
        end
        
        -- Force specific appearance for certain types as a safeguard
        if normalizedItemId:lower():find("wood") then
            item.BrickColor = BrickColor.new("Brown")
            item.Material = Enum.Material.Wood
        elseif normalizedItemId:lower():find("grass") then
            item.BrickColor = BrickColor.new("Bright green")
            item.Material = Enum.Material.Grass
        elseif normalizedItemId:lower():find("water") then
            item.BrickColor = BrickColor.new("Bright blue")
            item.Transparency = 0.3
            item.Material = Enum.Material.Water
        end
        
        print("PlacementManager: Item appearance after cloning:")
        print("  - BrickColor:", item.BrickColor.Name)
        print("  - Material:", item.Material.Name)
        print("  - Transparency:", item.Transparency)
    end
    
    -- Generate a unique ID for this instance
    local instanceId = normalizedItemId .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    item.Name = instanceId
    
    -- Calculate item height to adjust position
    local itemHeight = 2 -- Default height
    if item:IsA("BasePart") then
        itemHeight = item.Size.Y
    elseif item:IsA("Model") and item.PrimaryPart then
        itemHeight = item.PrimaryPart.Size.Y
    end
    
    -- Adjust Y position to place bottom of item at surface level
    local adjustedPosition = Vector3.new(
        position.X,
        position.Y + (itemHeight/2),
        position.Z
    )
    
    -- Position and orient the item
    if item:IsA("Model") and item.PrimaryPart then
        item:SetPrimaryPartCFrame(CFrame.new(adjustedPosition) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z))
    else
        item.CFrame = CFrame.new(adjustedPosition) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z)
    end
    
    -- Make sure it's anchored and can collide
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = true
            end
        end
    elseif item:IsA("BasePart") then
        item.Anchored = true
        item.CanCollide = true
    end
    
    -- Add attributes for tracking
    item:SetAttribute("item_type", normalizedItemId)
    item:SetAttribute("placed_at", os.time())
    
    -- Add to world folder
    item.Parent = self.worldFolder
    
    return item
end

-- Server: Get player data from appropriate manager
function PlacementManager:GetPlayerData(player)
    if not isServer then return nil end
    
    -- Try multiple ways to get player data for better compatibility
    
    -- First try ItemPurchaseHandler directly with GetPlayerDataForPlacement method
    local ItemPurchaseHandler

    -- Try to find the ItemPurchaseHandler in different possible locations
    local success1, errorMsg1 = pcall(function()
        -- Try to find it in ServerScriptService first
        return require(game:GetService("ServerScriptService"):WaitForChild("server").ItemPurchaseHandler)
    end)
    
    if success1 then
        ItemPurchaseHandler = errorMsg1 -- pcall returns the value in the error position if successful
    else
        -- Try another approach - look for it directly in the game hierarchy
        local serverScript = game:GetService("ServerScriptService"):FindFirstChild("server")
        if serverScript then
            local handler = serverScript:FindFirstChild("ItemPurchaseHandler")
            if handler then
                local success2, result2 = pcall(function()
                    return require(handler)
                end)
                if success2 then
                    ItemPurchaseHandler = result2
                end
            end
        end
    end
    
    -- If we found the handler, try to use it
    if ItemPurchaseHandler then
        -- Try the new dedicated method for placement first
        if ItemPurchaseHandler.GetPlayerDataForPlacement then
            local getSuccess, result = pcall(function()
                return ItemPurchaseHandler:GetPlayerDataForPlacement(player)
            end)
            
            if getSuccess and result then
                print("PlacementManager: Got player data using GetPlayerDataForPlacement")
                return result
            end
        end
        
        -- Fall back to regular GetPlayerData if needed
        if ItemPurchaseHandler.GetPlayerData then
            local getSuccess, result = pcall(function()
                return ItemPurchaseHandler:GetPlayerData(player)
            end)
            
            if getSuccess and result then
                print("PlacementManager: Got player data from ItemPurchaseHandler directly")
                return result
            end
        end
    end
    
    -- Try using ItemPurchaseHandler through SharedModule
    if self.shared and self.shared.ItemPurchaseHandler then
        local success, result = pcall(function()
            return self.shared.ItemPurchaseHandler:GetPlayerData(player)
        end)
        
        if success and result then
            print("PlacementManager: Got player data from SharedModule.ItemPurchaseHandler")
            return result
        end
    end
    
    -- Try using InventoryManager
    local InventoryManager = self.shared and self.shared.InventoryManager
    if InventoryManager and InventoryManager.GetPlayerData then
        local success, result = pcall(function()
            return InventoryManager:GetPlayerData(player)
        end)
        
        if success and result then
            print("PlacementManager: Got player data from InventoryManager")
            return result
        end
    end
    
    -- If all else fails, try getting inventory directly from player
    if player:FindFirstChild("PlayerData") and player.PlayerData:FindFirstChild("Inventory") then
        print("PlacementManager: Using PlayerData.Inventory directly")
        return { inventory = player.PlayerData.Inventory.Value }
    end
    
    -- Last resort - create a mock inventory with all items for testing
    warn("PlacementManager: Could not find a way to get player data - using mock data for testing")
    
    -- Return a mock inventory with basic items for testing purposes
    local mockInventory = {}
    
    -- Add all template items to mock inventory
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if templates then
        for _, template in ipairs(templates:GetChildren()) do
            table.insert(mockInventory, {
                id = template.Name,
                name = template.Name,
                count = 10
            })
        end
    end
    
    -- Add some default items
    for _, itemName in ipairs({"Grass_Cube", "Stone_Cube", "Wood_Plank", "Brick_Cube"}) do
        table.insert(mockInventory, {
            id = itemName,
            name = itemName,
            count = 5
        })
    end
    
    return { 
        inventory = mockInventory,
        mock = true  -- Flag to indicate this is mock data
    }
end

-- Server: Save world data to DataStore
function PlacementManager:SaveWorldData()
    if not isServer then return false end
    
    print("PlacementManager: Saving world data...")
    
    local DataService = self.shared and self.shared.DataService
    if not DataService then
        warn("PlacementManager: DataService not available for saving world data")
        return false
    end
    
    -- Collect all placed items data
    local worldData = {}
    
    -- First check for items in the placedItemsByPlayer tracking table
    for playerId, items in pairs(self.placedItemsByPlayer or {}) do
        for _, instanceId in ipairs(items) do
            -- Try to find the item in the world
            local item = self:FindItemByInstanceId(instanceId)
            if item then
                local itemPosition = item:IsA("Model") and item:GetPrimaryPartCFrame().Position or item.Position
                local itemRotation = item:IsA("Model") and item:GetPrimaryPartCFrame().Rotation or item.Rotation
                
                table.insert(worldData, {
                    id = item:GetAttribute("itemId") or item.Name:gsub("_%d+_%d+$", ""),
                    position = {
                        x = itemPosition.X,
                        y = itemPosition.Y, 
                        z = itemPosition.Z
                    },
                    rotation = {
                        x = itemRotation and itemRotation.X or 0,
                        y = itemRotation and itemRotation.Y or 0,
                        z = itemRotation and itemRotation.Z or 0
                    },
                    owner = playerId,
                    instanceId = instanceId
                })
            end
        end
    end
    
    -- Additionally, scan the Placed folder directly to catch any items that might not be in the tracking table
    if self.placedFolder then
        for _, item in ipairs(self.placedFolder:GetChildren()) do
            -- Skip items we've already processed from placedItemsByPlayer
            local instanceId = item:GetAttribute("instanceId")
            if not instanceId then
                instanceId = item.Name -- Use name as fallback
            end
            
            -- Check if this item is already in our worldData
            local alreadyIncluded = false
            for _, existingItem in ipairs(worldData) do
                if existingItem.instanceId == instanceId then
                    alreadyIncluded = true
                    break
                end
            end
            
            if not alreadyIncluded then
                local itemPosition = item:IsA("Model") and item:GetPrimaryPartCFrame().Position or item.Position
                local itemRotation = item:IsA("Model") and item:GetPrimaryPartCFrame().Rotation or item.Rotation
                local itemId = item:GetAttribute("itemId") or item.Name:gsub("_%d+_%d+$", "")
                local ownerId = item:GetAttribute("owner") or 0
                
                table.insert(worldData, {
                    id = itemId,
                    position = {
                        x = itemPosition.X,
                        y = itemPosition.Y, 
                        z = itemPosition.Z
                    },
                    rotation = {
                        x = itemRotation and itemRotation.X or 0,
                        y = itemRotation and itemRotation.Y or 0,
                        z = itemRotation and itemRotation.Z or 0
                    },
                    owner = ownerId,
                    instanceId = instanceId
                })
            end
        end
    end
    
    print("PlacementManager: Saving " .. #worldData .. " placed items")
    
    -- Save using DataService
    local success = DataService:SaveData("WorldPlacedItems", worldData)
    if success then
        print("PlacementManager: World data saved successfully")
    else
        warn("PlacementManager: Failed to save world data")
    end
    
    return success
end

-- Helper method to find an item by its instanceId
function PlacementManager:FindItemByInstanceId(instanceId)
    if not isServer then return nil end
    
    -- Look in the placed folder
    if self.placedFolder then
        for _, item in ipairs(self.placedFolder:GetChildren()) do
            if item:GetAttribute("instanceId") == instanceId or item.Name == instanceId then
                return item
            end
        end
    end
    
    -- Look in legacy folder if it exists
    if self.legacyPlacedFolder then
        for _, item in ipairs(self.legacyPlacedFolder:GetChildren()) do
            if item:GetAttribute("instanceId") == instanceId or item.Name == instanceId then
                return item
            end
        end
    end
    
    -- Look in the main world folder as a last resort
    if self.worldFolder then
        for _, item in ipairs(self.worldFolder:GetChildren()) do
            if not item:IsA("Folder") and (item:GetAttribute("instanceId") == instanceId or item.Name == instanceId) then
                return item
            end
        end
    end
    
    return nil
end

-- Server: Load world data from DataStore
function PlacementManager:LoadWorldData()
    if not isServer then return false end
    
    local DataService = self.shared and self.shared.DataService
    if not DataService then
        warn("PlacementManager: DataService not available for loading world data")
        return false
    end
    
    -- Load world data
    local worldData = DataService:LoadData("WorldPlacedItems")
    if not worldData or type(worldData) ~= "table" or #worldData == 0 then
        print("PlacementManager: No world data available to load")
        return false
    end
    
    print("PlacementManager: Loading " .. #worldData .. " placed items")
    
    -- Clear existing items from tracking but not from the world
    self.placedItemsByPlayer = {}
    
    -- Recreate all items
    local itemsCreated = 0
    for _, itemData in ipairs(worldData) do
        if not itemData.id then
            warn("PlacementManager: Item data missing ID, skipping")
            continue
        end
        
        local position = Vector3.new(
            itemData.position.x,
            itemData.position.y,
            itemData.position.z
        )
        
        local rotation = Vector3.new(
            itemData.rotation.x,
            itemData.rotation.y,
            itemData.rotation.z
        )
        
        -- Create the item template first
        local normalizedItemId = itemData.id:gsub(" ", "_")
        local template = self:GetItemTemplate(normalizedItemId)
        
        if not template then
            warn("PlacementManager: Template not found for item: " .. normalizedItemId)
            continue
        end
        
        -- Clone the template
        local item = template:Clone()
        if not item then
            warn("PlacementManager: Failed to clone template for item: " .. normalizedItemId)
            continue
        end
        
        -- Set up appearance properties from template
        if item:IsA("BasePart") and template:IsA("BasePart") then
            item.BrickColor = template.BrickColor
            item.Material = template.Material
            item.Transparency = template.Transparency
        end
        
        -- Generate a unique ID for this instance if needed
        local instanceId = itemData.instanceId or (normalizedItemId .. "_" .. os.time() .. "_" .. math.random(1000, 9999))
        item.Name = instanceId
        
        -- Position and orient the item EXACTLY at the saved position
        if item:IsA("Model") and item.PrimaryPart then
            item:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z))
        else
            item.CFrame = CFrame.new(position) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z)
        end
        
        -- Make sure it's anchored and can collide
        if item:IsA("Model") then
            for _, part in ipairs(item:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = true
                end
            end
        elseif item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = true
        end
        
        -- Set attributes
        item:SetAttribute("owner", itemData.owner)
        item:SetAttribute("instanceId", instanceId)
        item:SetAttribute("itemId", itemData.id)
        item:SetAttribute("placedTime", itemData.placedTime or os.time())
        item:SetAttribute("persistent", true)
        item:SetAttribute("item_type", normalizedItemId)
        item:SetAttribute("placed_at", itemData.placedTime or os.time())
        
        -- Ensure proper parenting
        item.Parent = self.placedFolder
        
        -- Track in placedItemsByPlayer
        local owner = itemData.owner or 0
        if not self.placedItemsByPlayer[owner] then
            self.placedItemsByPlayer[owner] = {}
        end
        
        table.insert(self.placedItemsByPlayer[owner], instanceId)
        itemsCreated = itemsCreated + 1
    end
    
    print("PlacementManager: Successfully loaded " .. itemsCreated .. " items")
    return true
end

-- Connect to player leaving event
function PlacementManager:ConnectPlayerEvents()
    if not isServer then return end
    
    -- Connect to PlayerRemoving event to save data when players leave
    game.Players.PlayerRemoving:Connect(function(player)
        print("PlacementManager: Player leaving:", player.Name)
        
        -- Save world data when a player leaves
        self:SaveWorldData()
    end)
    
    -- Also connect to game closing event
    game:BindToClose(function()
        print("PlacementManager: Game closing, saving world data")
        self:SaveWorldData()
    end)
    
    print("PlacementManager: Connected to player events")
end

-- Server: Recall a placed item back to the player's inventory
function PlacementManager:RecallItem(player, instanceId)
    if not isServer then return false end
    
    print("PlacementManager: RecallItem called for", player.Name, "instanceId:", instanceId)
    
    -- Try to find the item in the Placed folder
    local placedItem
    
    -- Check in World_Items/Placed first
    if self.worldFolder and self.placedFolder then
        for _, item in ipairs(self.placedFolder:GetChildren()) do
            if item:GetAttribute("instanceId") == instanceId then
                placedItem = item
                break
            end
        end
    end
    
    -- If not found, check in legacy PlacedItems folder
    if not placedItem and self.legacyPlacedFolder then
        for _, item in ipairs(self.legacyPlacedFolder:GetChildren()) do
            if item:GetAttribute("instanceId") == instanceId then
                placedItem = item
                break
            end
        end
    end
    
    if not placedItem then
        warn("PlacementManager: Placed item not found with instanceId", instanceId)
        return false
    end
    
    -- Get the item ID to add back to inventory
    local itemId = placedItem:GetAttribute("itemId")
    if not itemId then
        -- Try to determine the item ID from the item name (strip player ID and timestamp)
        local itemName = placedItem.Name
        itemId = itemName:gsub("_" .. player.UserId .. "_.*$", "")
        print("PlacementManager: Determined itemId from name:", itemId)
    end
    
    -- Add the item back to the player's inventory
    local success = false
    
    -- Try to add the item to inventory using ItemPurchaseHandler
    local ItemPurchaseHandler
    pcall(function()
        ItemPurchaseHandler = require(game:GetService("ServerScriptService").server.ItemPurchaseHandler)
    end)
    
    if ItemPurchaseHandler and ItemPurchaseHandler.AddItemToInventory then
        success = ItemPurchaseHandler:AddItemToInventory(player, itemId)
        print("PlacementManager: Added item", itemId, "to player's inventory:", success)
    else
        -- Fallback: Try with the shared ItemPurchaseHandler
        if self.shared and self.shared.ItemPurchaseHandler and self.shared.ItemPurchaseHandler.AddItemToInventory then
            success = self.shared.ItemPurchaseHandler:AddItemToInventory(player, itemId)
            print("PlacementManager: Added item", itemId, "to player's inventory using shared module:", success)
        else
            -- Last resort: Fire a remote event to handle this on the client
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("AddToInventory") then
                remotes.AddToInventory:FireClient(player, {name = itemId, id = itemId, count = 1})
                print("PlacementManager: Fired AddToInventory event to client")
                success = true
            end
        end
    end
    
    if success then
        -- Store the item data before removing it
        local itemData = {
            name = placedItem.Name,
            position = placedItem:IsA("Model") and placedItem:GetPrimaryPartCFrame().Position or placedItem.Position,
            itemId = itemId,
            instanceId = instanceId
        }
        
        -- Remove the placed item
        placedItem:Destroy()
        
        -- Log the recall
        print("PlacementManager: Successfully recalled item", itemId, "for player", player.Name)
        
        -- Notify player
        local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if Remotes and Remotes:FindFirstChild("ItemRecalled") then
            Remotes.ItemRecalled:FireClient(player, itemData)
    end
    
    return true
    else
        warn("PlacementManager: Failed to add item to inventory")
        return false
    end
end

-- Server: Add an item to inventory
function PlacementManager:AddToInventory(player, itemId)
    if not isServer then return false end
    
    local success = false
    local InventoryManager = self.shared.InventoryManager
    
    if InventoryManager then
        success = InventoryManager:AddItem(player, itemId, 1)
    else
        -- Fallback to ItemPurchaseHandler
        local ItemPurchaseHandler = self.shared.ItemPurchaseHandler
        if ItemPurchaseHandler then
            success = ItemPurchaseHandler:AddToInventory(player, itemId, 1)
        end
    end
    
    return success
end

-- Client: Start placing an item
function PlacementManager:StartPlacing(itemId)
    if isServer then return end
    
    print("PlacementManager: Starting placement of item", itemId)
    
    -- Stop any current placement
    self:StopPlacing()
    
    -- Get item data
    local itemData = self:GetItemData(itemId)
    if not itemData then
        warn("PlacementManager: No item data found for", itemId)
        return
    end
    
    -- Create a preview item
    self.previewItem = self:CreatePreviewItem(itemId)
    if not self.previewItem then
        warn("PlacementManager: Failed to create preview for", itemId)
        return
    end
    
    -- Store selected item info
    self.selectedItem = {
        id = itemId,
        data = itemData
    }
    
    -- Set placing state
    self.isPlacing = true
    
    -- Connect update function
    self.placementConnection = RunService.RenderStepped:Connect(function()
        self:UpdatePlacementPreview()
    end)
    
    -- Connect input events
    self:ConnectPlacementInputs()
end

-- Client: Create a preview item for placement
function PlacementManager:CreatePreviewItem(itemId)
    if isServer then return nil end
    
    print("PlacementManager: Creating preview item for:", itemId)
    
    -- Try to find template
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    local template
    
    if templates then
        -- Try exact match first
        template = templates:FindFirstChild(itemId)
        
        if template then
            print("PlacementManager: Found exact template match for preview:", itemId)
        else
            -- If no template found, try with partial match
            local itemIdLower = itemId:lower()
            for _, item in ipairs(templates:GetChildren()) do
                if item.Name:lower():find(itemIdLower) or itemIdLower:find(item.Name:lower()) then
                    template = item
                    print("PlacementManager: Found partial match for preview:", itemId, "using", item.Name)
            break
                end
        end
    end
    
        -- Special case for common building materials
        if not template then
            local specialCases = {
                {"brick", "Brick_Cube"},
                {"grass", "Grass_Cube"},
                {"stone", "Stone_Cube"},
                {"wood", "Wood_Plank"},
                {"water", "Water_Cube"},
                {"fire", "Fire_Cube"},
                {"sand", "Sand_Cube"},
                {"concrete", "Concrete_Cube"},
                {"metal", "Metal_Cube"},
                {"glass", "Glass_Cube"}
            }
            
            for _, case in ipairs(specialCases) do
                if itemId:lower():find(case[1]) then
                    template = templates:FindFirstChild(case[2])
                    if template then
                        print("PlacementManager: Using special case", case[2], "for preview of", itemId)
                        break
                    end
                end
            end
        end
    end
    
    -- If no template, create a basic cube
    if not template then
        print("PlacementManager: No template found for", itemId, "- creating basic preview")
        template = Instance.new("Part")
        template.Name = itemId .. "_Preview"
        template.Size = Vector3.new(2, 2, 2)
        template.Transparency = 0.5
        template.CanCollide = false
        template.Anchored = true
        
        -- Set color based on item type
        if itemId:lower():find("water") or itemId:lower():find("blue") then
            template.BrickColor = BrickColor.new("Bright blue")
            template.Transparency = 0.7
            template.Material = Enum.Material.Water
        elseif itemId:lower():find("fire") or itemId:lower():find("lava") then
            template.BrickColor = BrickColor.new("Bright red")
            template.Material = Enum.Material.Neon
        elseif itemId:lower():find("grass") or itemId:lower():find("green") then
            template.BrickColor = BrickColor.new("Bright green")
            template.Material = Enum.Material.Grass
        elseif itemId:lower():find("sand") or itemId:lower():find("earth") then
            template.BrickColor = BrickColor.new("Brick yellow")
            template.Material = Enum.Material.Sand
        elseif itemId:lower():find("wood") or itemId:lower():find("brown") then
            template.BrickColor = BrickColor.new("Brown")
            template.Material = Enum.Material.Wood
        elseif itemId:lower():find("brick") or itemId:lower():find("red") then
            template.BrickColor = BrickColor.new("Brick red")
            template.Material = Enum.Material.Brick
        elseif itemId:lower():find("glass") or itemId:lower():find("transparent") then
            template.BrickColor = BrickColor.new("Institutional white")
            template.Transparency = 0.7
            template.Material = Enum.Material.Glass
        else
            template.BrickColor = BrickColor.new("Medium stone grey")
            template.Material = Enum.Material.Concrete
        end
    else
        template = template:Clone()
    end
    
    -- Make semi-transparent for preview
    if template:IsA("Model") then
        for _, part in ipairs(template:GetDescendants()) do
            if part:IsA("BasePart") then
                local originalTransparency = part.Transparency
                part.Transparency = math.min(0.5 + originalTransparency, 0.9) -- Add transparency but keep relative differences
                part.CanCollide = false
                part.Anchored = true
                
                -- Add outline effect
                local highlight = Instance.new("Highlight")
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = Color3.new(0, 1, 0)
                highlight.Parent = part
            end
        end
    elseif template:IsA("BasePart") then
        local originalTransparency = template.Transparency
        template.Transparency = math.min(0.5 + originalTransparency, 0.9)
        template.CanCollide = false
        template.Anchored = true
        
        -- Add outline effect
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.new(0, 1, 0)
        highlight.Parent = template
    end
    
    -- Store the original template name to ensure we create the right item on placement
    template:SetAttribute("originalTemplate", itemId)
    
    template.Parent = Workspace
    
    return template
end

-- Client: Update the placement preview position
function PlacementManager:UpdatePlacementPreview()
    if isServer or not self.isPlacing or not self.previewItem then return end
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    
    -- Cast ray from mouse position
    local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {self.previewItem}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
    if raycastResult then
        local hitPosition = raycastResult.Position
        
        -- Apply grid snapping
        local snappedPosition = Vector3.new(
            math.floor(hitPosition.X / GRID_SIZE + 0.5) * GRID_SIZE,
            math.floor(hitPosition.Y / GRID_SIZE + 0.5) * GRID_SIZE,
            math.floor(hitPosition.Z / GRID_SIZE + 0.5) * GRID_SIZE
        )
        
        -- Ensure Y position is at least half the height of the item above the surface
        local itemHeight = 2 -- Default height for standard cubes
        if self.previewItem:IsA("BasePart") then
            itemHeight = self.previewItem.Size.Y
        elseif self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
            itemHeight = self.previewItem.PrimaryPart.Size.Y
        end
        
        -- Adjust Y position to place bottom of item at surface level
        snappedPosition = Vector3.new(
            snappedPosition.X,
            snappedPosition.Y + (itemHeight/2),
            snappedPosition.Z
        )
        
        -- Check distance from player
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local rootPart = character.HumanoidRootPart
            local distance = (rootPart.Position - snappedPosition).Magnitude
            
            -- Update preview color based on valid placement
            local isValidPlacement = distance <= MAX_PLACEMENT_DISTANCE
            
            -- Update highlight color
            if self.previewItem:IsA("Model") then
                for _, part in ipairs(self.previewItem:GetDescendants()) do
                    if part:IsA("BasePart") then
                        for _, highlight in ipairs(part:GetChildren()) do
                            if highlight:IsA("Highlight") then
                                highlight.OutlineColor = isValidPlacement and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
                            end
                        end
                    end
                end
            elseif self.previewItem:IsA("BasePart") then
                for _, highlight in ipairs(self.previewItem:GetChildren()) do
                    if highlight:IsA("Highlight") then
                        highlight.OutlineColor = isValidPlacement and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
                    end
                end
            end
            
            -- Position the preview
            if self.previewItem:IsA("Model") then
                if self.previewItem.PrimaryPart then
                    self.previewItem:SetPrimaryPartCFrame(CFrame.new(snappedPosition))
                else
                    -- If no primary part, move all parts
                    local refPart = self.previewItem:FindFirstChildWhichIsA("BasePart")
                    if refPart then
                        local offset = snappedPosition - refPart.Position
                        for _, part in ipairs(self.previewItem:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Position = part.Position + offset
                            end
                        end
                    end
                end
            else
                self.previewItem.CFrame = CFrame.new(snappedPosition)
            end
        end
    end
end

-- Client: Connect placement input events
function PlacementManager:ConnectPlacementInputs()
    if isServer then return end
    
    local UserInputService = game:GetService("UserInputService")
    
    -- Disconnect any existing connections
    if self.inputBeganConnection then
        self.inputBeganConnection:Disconnect()
        self.inputBeganConnection = nil
    end
    
    -- Connect to input
    self.inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click to place
            self:ConfirmPlacement()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or ESC to cancel
            self:CancelPlacement()
        elseif input.KeyCode == Enum.KeyCode.R then
            -- R to rotate
            self:RotatePreview()
        end
    end)
end

-- Client: Confirm placement
function PlacementManager:ConfirmPlacement()
    if isServer or not self.isPlacing or not self.previewItem or not self.selectedItem then return end
    
    local player = Players.LocalPlayer
    
    -- Check distance from player
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local rootPart = character.HumanoidRootPart
        local position
        local rotation = Vector3.new(0, 0, 0)
        
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
            position = self.previewItem.PrimaryPart.Position
            rotation = self.previewItem.PrimaryPart.Orientation
        else
            position = self.previewItem.Position
            rotation = self.previewItem.Orientation
        end
        
        local distance = (rootPart.Position - position).Magnitude
        
        if distance <= MAX_PLACEMENT_DISTANCE then
            -- Get original template name if available
            local originalTemplate = self.previewItem:GetAttribute("originalTemplate")
            local itemToPlace = originalTemplate or self.selectedItem.id
            
            -- Send place request to server
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                local placeItemRemote = remotes:FindFirstChild("PlaceItem")
                if placeItemRemote then
                    print("PlacementManager: Sending PlaceItem request for", itemToPlace)
                    placeItemRemote:FireServer(itemToPlace, position, rotation)
                    
                    -- Immediately clear the item from hand to provide visual feedback
                    self:ClearItemFromHand()
                    
                    -- Stop placing mode
                    self.isPlacing = false
                    
                    -- Disconnect update
                    if self.placementConnection then
                        self.placementConnection:Disconnect()
                        self.placementConnection = nil
                    end
                    
                    -- Disconnect input
                    if self.inputBeganConnection then
                        self.inputBeganConnection:Disconnect()
                        self.inputBeganConnection = nil
                    end
                    
                    -- Clean up preview
                    if self.previewItem then
                        self.previewItem:Destroy()
                        self.previewItem = nil
                    end
                    
                    -- Restore player movement
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                        humanoid.WalkSpeed = 16
                    end
                    
                    return
                end
            end
            
            warn("PlacementManager: PlaceItem remote event not found")
        else
            print("PlacementManager: Too far to place item")
        end
    end
end

-- Client: Cancel placement
function PlacementManager:CancelPlacement()
    if isServer then return end
    
    -- Return item to inventory
    if self.selectedItem then
        print("PlacementManager: Cancelled placement, returning", self.selectedItem.id, "to inventory")
    end
    
    -- Stop placing
    self:StopPlacing()
    
    -- Fire event to notify server the item should remain in inventory
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes and self.selectedItem then
        local cancelPlacementRemote = remotes:FindFirstChild("CancelPlacement")
        if cancelPlacementRemote then
            cancelPlacementRemote:FireServer(self.selectedItem.id)
        end
    end
end

-- Client: Rotate preview
function PlacementManager:RotatePreview()
    if isServer or not self.isPlacing or not self.previewItem then return end
    
    -- Rotate by 90 degrees around Y axis
    if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
        local currentCFrame = self.previewItem.PrimaryPart.CFrame
        self.previewItem:SetPrimaryPartCFrame(currentCFrame * CFrame.Angles(0, math.rad(90), 0))
    else
        local currentCFrame = self.previewItem.CFrame
        self.previewItem.CFrame = currentCFrame * CFrame.Angles(0, math.rad(90), 0)
    end
end

-- Client: Stop placing
function PlacementManager:StopPlacing()
    if isServer then return end
    
    self.isPlacing = false
    
    -- Disconnect update
    if self.placementConnection then
        self.placementConnection:Disconnect()
        self.placementConnection = nil
    end
    
    -- Disconnect input
    if self.inputBeganConnection then
        self.inputBeganConnection:Disconnect()
        self.inputBeganConnection = nil
    end
    
    -- Clean up preview
    if self.previewItem then
        self.previewItem:Destroy()
        self.previewItem = nil
    end
    
    self.selectedItem = nil
end

-- Connect to RemoteEvents
function PlacementManager:SetupRemoteEvents()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("PlacementManager: Creating Remotes folder")
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    -- Required remotes
    local remoteEvents = {
        "PlaceItem",
        "RecallItem",
        "CancelPlacement",
        "ItemPlaced",
        "ItemRecalled"
    }
    
    for _, eventName in ipairs(remoteEvents) do
        local remote = remotes:FindFirstChild(eventName)
        if not remote then
            if isServer then
                print("PlacementManager: Creating RemoteEvent:", eventName)
                remote = Instance.new("RemoteEvent")
                remote.Name = eventName
                remote.Parent = remotes
            else
                print("PlacementManager: Waiting for RemoteEvent:", eventName)
                remote = remotes:WaitForChild(eventName, 10)
            end
        end
        
        if remote then
            self.remotes[eventName] = remote
        else
            warn("PlacementManager: Failed to find or create RemoteEvent:", eventName)
        end
    end
    
    -- Connect server-side event handlers
    if isServer then
        if self.remotes.PlaceItem then
            self.remotes.PlaceItem.OnServerEvent:Connect(function(player, itemId, position, rotation)
                local success, placedItem = self:PlaceItem(player, itemId, position, rotation)
                print("PlacementManager: PlaceItem result for", player.Name, ":", success)
            end)
        end
        
        if self.remotes.RecallItem then
            self.remotes.RecallItem.OnServerEvent:Connect(function(player, instanceId)
                self:RecallItem(player, instanceId)
            end)
        end
        
        if self.remotes.CancelPlacement then
            -- Nothing to do when placement is cancelled - item remains in inventory
            self.remotes.CancelPlacement.OnServerEvent:Connect(function(player, itemId)
                print("PlacementManager: Player", player.Name, "cancelled placement of", itemId)
            end)
        end
    else
        -- Client-side handlers for ItemPlaced and ItemRecalled
        if self.remotes.ItemPlaced then
            self.remotes.ItemPlaced.OnClientEvent:Connect(function(itemId, instanceId)
                print("PlacementManager: Item placed successfully:", itemId, instanceId)
                -- Clear item from hand when server confirms placement
                self:ClearItemFromHand()
            end)
        end
        
        if self.remotes.ItemRecalled then
            self.remotes.ItemRecalled.OnClientEvent:Connect(function(itemId, instanceId)
                print("PlacementManager: Item recalled successfully:", itemId, instanceId)
            end)
        end
    end
    
    print("PlacementManager: Remote events setup completed")
end

-- Client: Show the item in the player's hand
function PlacementManager:ShowItemInHand(itemId)
    if isServer then return end
    
    print("PlacementManager: Showing item in hand:", itemId)
    
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then
        warn("PlacementManager: No character found")
        return
    end
    
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not rightHand then
        warn("PlacementManager: No right hand/arm found")
        return
    end
    
    -- Find or create equipment slot
    local equipSlot = rightHand:FindFirstChild("EquipSlot")
    if not equipSlot then
        equipSlot = Instance.new("Attachment")
        equipSlot.Name = "EquipSlot"
        equipSlot.Position = Vector3.new(0, -0.5, 0)
        equipSlot.Parent = rightHand
        print("PlacementManager: Created EquipSlot attachment on", rightHand.Name)
    end
    
    -- Clear any existing equipped item
    for _, child in ipairs(equipSlot:GetChildren()) do
        child:Destroy()
    end
    
    -- Normalize item name (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    print("PlacementManager: Normalized item name:", normalizedItemId)
    
    -- Try multiple approaches to find template
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    local template
    
    if templates then
        -- Try several name variants to find the template
        local possibleNames = {
            normalizedItemId,
            itemId,
            normalizedItemId:gsub("_Cube", ""),
            itemId:gsub("_Cube", ""),
            normalizedItemId .. "_Cube",
            itemId .. "_Cube"
        }
        
        -- Try each possible name
        for _, name in ipairs(possibleNames) do
            template = templates:FindFirstChild(name)
            if template then
                print("PlacementManager: Found template using name variant:", name)
                break
            end
        end
        
        -- If still no template, try case-insensitive search
        if not template then
            local itemIdLower = normalizedItemId:lower()
            for _, item in ipairs(templates:GetChildren()) do
                if item.Name:lower():find(itemIdLower) or itemIdLower:find(item.Name:lower()) then
                    template = item
                    print("PlacementManager: Found partial match for", normalizedItemId, "using", item.Name)
                    break
                end
            end
        end
    else
        warn("PlacementManager: ItemTemplates folder not found in ReplicatedStorage")
    end
    
    -- Create a basic item if no template
    if not template then
        print("PlacementManager: No template found for", normalizedItemId, "- creating basic item")
        template = Instance.new("Part")
        template.Size = Vector3.new(1, 1, 1)
        template.CanCollide = false
        template.Name = normalizedItemId
        
        -- Set color based on item type
        if normalizedItemId:lower():find("water") then
            template.BrickColor = BrickColor.new("Bright blue")
            template.Material = Enum.Material.Water
            template.Transparency = 0.3
        elseif normalizedItemId:lower():find("fire") then
            template.BrickColor = BrickColor.new("Bright red")
            template.Material = Enum.Material.Neon
        elseif normalizedItemId:lower():find("grass") then
            template.BrickColor = BrickColor.new("Bright green")
            template.Material = Enum.Material.Grass
        elseif normalizedItemId:lower():find("sand") or normalizedItemId:lower():find("earth") then
            template.BrickColor = BrickColor.new("Brick yellow")
            template.Material = Enum.Material.Sand
        elseif normalizedItemId:lower():find("wood") then
            template.BrickColor = BrickColor.new("Brown")
            template.Material = Enum.Material.Wood
        elseif normalizedItemId:lower():find("brick") then
            template.BrickColor = BrickColor.new("Brick red")
            template.Material = Enum.Material.Brick
        elseif normalizedItemId:lower():find("glass") then
            template.BrickColor = BrickColor.new("Institutional white")
            template.Material = Enum.Material.Glass
            template.Transparency = 0.5
        else
            template.BrickColor = BrickColor.new("Medium stone grey")
            template.Material = Enum.Material.Concrete
        end
    else
        print("PlacementManager: Using template:", template.Name, "for item:", normalizedItemId)
        template = template:Clone()
    end
    
    -- Setup item for hand
    if template:IsA("Model") then
        print("PlacementManager: Setting up model for hand placement")
        template.PrimaryPart = template.PrimaryPart or template:FindFirstChildWhichIsA("BasePart")
        if template.PrimaryPart then
            -- Scale down if needed
            local size = template.PrimaryPart.Size
            if size.Magnitude > 2 then
                local scale = 2 / size.Magnitude
                for _, part in pairs(template:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Size = part.Size * scale
                    end
                end
                print("PlacementManager: Scaled down model by factor of", scale)
            end
            
            -- Make sure all parts are not colliding and are CanTouch to avoid physics issues
            for _, part in pairs(template:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.CanTouch = true
                    part.Anchored = false
                    
                    -- Add highlight to make it more visible
                    local highlight = Instance.new("Highlight")
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Color3.new(1, 1, 0)
                    highlight.Parent = part
                end
            end
            
            -- Weld to hand
            local weld = Instance.new("WeldConstraint")
            weld.Name = "HandWeld"
            weld.Part0 = rightHand
            weld.Part1 = template.PrimaryPart
            weld.Parent = template.PrimaryPart
            
            -- Set custom attribute for debugging
            template:SetAttribute("held_by_player", true)
            template:SetAttribute("held_time", os.time())
            template:SetAttribute("item_id", normalizedItemId)
            
            -- Position template at hand
            template:SetPrimaryPartCFrame(equipSlot.WorldCFrame)
            
            -- Parent to equipment slot to maintain hierarchy
            template.Parent = equipSlot
            
            -- Print debug info
            print("PlacementManager: Item model placed in hand successfully:", template.Name)
        else
            warn("PlacementManager: Model has no PrimaryPart and no BaseParts were found")
        end
    elseif template:IsA("BasePart") then
        print("PlacementManager: Setting up part for hand placement")
        -- Scale down if needed
        if template.Size.Magnitude > 2 then
            local scale = 2 / template.Size.Magnitude
            template.Size = template.Size * scale
            print("PlacementManager: Scaled down part by factor of", scale)
        end
        
        -- Setup properties to avoid physics issues
        template.CanCollide = false
        template.CanTouch = true
        template.Anchored = false
        
        -- Add highlight to make it more visible
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.new(1, 1, 0)
        highlight.Parent = template
        
        -- Set custom attribute for debugging
        template:SetAttribute("held_by_player", true)
        template:SetAttribute("held_time", os.time())
        template:SetAttribute("item_id", normalizedItemId)
        
        -- Weld to hand
        local weld = Instance.new("WeldConstraint")
        weld.Name = "HandWeld" 
        weld.Part0 = rightHand
        weld.Part1 = template
        weld.Parent = template
        
        -- Position template at hand
        template.CFrame = equipSlot.WorldCFrame
        
        -- Parent to equipment slot to maintain hierarchy
        template.Parent = equipSlot
        
        -- Print debug info
        print("PlacementManager: Item part placed in hand successfully:", template.Name)
    end
    
    -- Check after a short delay to make sure the item is visible
    task.delay(0.5, function()
        if not template or not template.Parent then
            print("PlacementManager: Item disappeared from hand, attempting to recreate")
            self:ShowItemInHand(itemId)
            return
        end
        
        -- Ensure the character can move
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            humanoid.WalkSpeed = 16
        end
    end)
    
    -- Set up movement state checker to prevent character from getting stuck in physics state
    local movementConnection
    movementConnection = RunService.Heartbeat:Connect(function()
        if not character or not character.Parent then
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
            return
        end
                
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Check if walkspeed is too low or in physics state
            if humanoid.WalkSpeed < 10 or humanoid:GetState() == Enum.HumanoidStateType.Physics then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid.WalkSpeed = 16
            end
        end
    end)
    
    -- Make sure to disconnect if the player stops placing (to avoid unnecessary processing)
    task.delay(60, function()
        if movementConnection then
            movementConnection:Disconnect()
            movementConnection = nil
        end
    end)
    
    return template
end

-- Client: Recall item from inventory to hand
function PlacementManager:RecallItemFromInventory(itemId)
    if isServer then return end
    
    print("PlacementManager: Recalling item", itemId, "from inventory")
    
    -- Normalize item name - replace spaces with underscores
    local normalizedItemId = itemId:gsub(" ", "_")
    print("PlacementManager: Normalized item name from", itemId, "to", normalizedItemId)
    
    -- Fix player movement by ensuring Humanoid state is reset first
    local player = Players.LocalPlayer
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Reset humanoid state to allow movement
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            -- Ensure WalkSpeed is set properly
            humanoid.WalkSpeed = 16
            
            -- Force walk mode to make sure character can move
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
        end
    end
    
    -- Show item in hand using normalized ID    
    local itemInHand = self:ShowItemInHand(normalizedItemId)
    if not itemInHand then
        warn("PlacementManager: Failed to show item in hand")
        -- Try with original ID as fallback
        itemInHand = self:ShowItemInHand(itemId)
        if not itemInHand then
            return
        end
    end
        
    -- Start placement mode with normalized ID
    self:StartPlacing(normalizedItemId)
    
    -- Use RunService to continuously ensure the player can move
    local movementConnection
    movementConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not character or not character.Parent then
            -- Character was removed, disconnect
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
            return
        end
                
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Ensure WalkSpeed is maintained
            if humanoid.WalkSpeed < 16 then
                humanoid.WalkSpeed = 16
            end
                        
            -- Force walk mode to keep character mobile
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
                        
            -- If in a state that prevents movement, change it
            local currentState = humanoid:GetState()
            if currentState == Enum.HumanoidStateType.Physics or
               currentState == Enum.HumanoidStateType.Seated or
               currentState == Enum.HumanoidStateType.PlatformStanding or
               currentState == Enum.HumanoidStateType.Swimming or
               currentState == Enum.HumanoidStateType.Ragdoll then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                -- Force the character into walking state after getting up
                task.delay(0.1, function()
                    if humanoid and humanoid.Parent then
                        humanoid:ChangeState(Enum.HumanoidStateType.Walking)
                    end
                end)
            end
        end
    end)
    
    -- Disconnect after placement or if canceled
    task.spawn(function()
        while self.isPlacing do
            task.wait(0.1)
        end
        if movementConnection then
            movementConnection:Disconnect()
            movementConnection = nil
        end
    end)
end

-- Client: Clear item from hand
function PlacementManager:ClearItemFromHand()
    if isServer then return end
    
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then return end
    
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not rightHand then return end
    
    local equipSlot = rightHand:FindFirstChild("EquipSlot")
    if equipSlot then
        for _, child in ipairs(equipSlot:GetChildren()) do
            child:Destroy()
        end
    end
    
    -- Make sure the Humanoid can still move
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

return PlacementManager

