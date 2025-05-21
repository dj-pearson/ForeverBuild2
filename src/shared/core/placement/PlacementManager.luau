-- PlacementManager.luau
-- Manages the placement, recall, and persistence of items in the world

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration
local PLACED_ITEMS_FOLDER_NAME = "World_Items" -- Use the existing World_Items folder
local MAX_PLACEMENT_DISTANCE = 20
local GRID_SIZE = 1 -- For grid snapping

-- Attempt to require UniqueItemIdAssigner
local UniqueItemIdAssigner
if RunService:IsServer() then
    local success, result = pcall(function()
        return require(game:GetService("ServerScriptService").server.UniqueItemIdAssigner)
    end)
    if success then
        UniqueItemIdAssigner = result
        print("PlacementManager: Successfully required UniqueItemIdAssigner")
    else
        warn("PlacementManager: Failed to require UniqueItemIdAssigner:", result)
    end
end

local PlacementManager = {}
PlacementManager.__index = PlacementManager

-- Initialize the PlacementManager
function PlacementManager.new(sharedModule)
    print("--- PLACEMENT MANAGER .new() CALLED ---") -- TOP LEVEL MARKER
    local self = setmetatable({}, PlacementManager)
    
    self.shared = sharedModule
    self.Constants = sharedModule.Constants
    
    -- Ensure CURRENCY and INGAME are initialized to prevent errors
    if not self.Constants then
        self.Constants = {}
    end
    if not self.Constants.CURRENCY then
        self.Constants.CURRENCY = {}
    end
    if not self.Constants.CURRENCY.INGAME then
        self.Constants.CURRENCY.INGAME = "coins" -- Default currency name
    end
    
    self.remotes = {}
    
    -- Add a lookup table for numeric/generic item IDs to template names
    self.itemTemplateMap = {
        ["item_1"] = "Grass_Cube",
        ["item_2"] = "Stone_Cube",
        ["item_3"] = "Wood_Plank",
        ["item_4"] = "Wood_Cube",
        ["item_5"] = "Brick_Cube",
        ["item_6"] = "Water_Cube",
        ["item_7"] = "Glass_Cube",
        ["item_8"] = "Sand_Cube",
        ["item_9"] = "Concrete_Cube",
        ["item_10"] = "Metal_Cube"
    }
    
    -- Setup the world folder for placed items
    if RunService:IsClient() then -- MODIFIED: Check IsClient first
        -- Client-side properties
        self.previewItem = nil
        self.isPlacing = false
        self.selectedItem = nil
        
        -- Cache remote events on the client
        print("--- PLACEMENT MANAGER CLIENT CONSTRUCTOR REACHED (IsClient == true) ---") -- MARKER
        self:CacheRemoteEvents()
    else -- Assume server if not client
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
    end
    
    return self
end

-- Initialize the PlacementManager
function PlacementManager:Initialize()
    if RunService:IsClient() then return false end
    
    print("PlacementManager: Initialize called")
    
    -- Set up remote events for placement system
    self:SetupRemoteEvents()
    
    -- Connect player events for saving
    local success, err = pcall(function()
        self:ConnectPlayerEvents()
    end)

    if not success then
        warn("[PlacementManager] Failed to connect player events: " .. tostring(err))
    end
    
    -- Load world data from DataStore
    task.spawn(function()
        task.wait(2) -- Give DataService time to initialize
        self:LoadWorldData()
    end)
    
    print("PlacementManager: Initialization completed")
    return true
end

function PlacementManager:ConnectPlayerEvents()
    print("[PlacementManager] ConnectPlayerEvents method called. Player events should now be connected.")
    
    -- TODO: Implement or verify the actual player event connection logic here.
    -- This might involve connecting to Players.PlayerAdded, Players.PlayerRemoving,
    -- or setting up other player-specific event listeners.
    -- Example:
    -- local PlayersService = game:GetService("Players")
    -- if PlayersService then
    --     self._playerAddedConn = PlayersService.PlayerAdded:Connect(function(player)
    --         print("[PlacementManager] PlayerAdded: " .. player.Name)
    --         -- self:OnPlayerAdded(player) -- Call your specific handler
    --     end)
    --     self._playerRemovingConn = PlayersService.PlayerRemoving:Connect(function(player)
    --         print("[PlacementManager] PlayerRemoving: " .. player.Name)
    --         -- self:OnPlayerRemoving(player) -- Call your specific handler
    --     end)
    -- else
    --     warn("[PlacementManager] Players service not available for ConnectPlayerEvents.")
    -- end
end

-- Helper: Recursively search for a template in a folder and its subfolders
local function findTemplateRecursive(folder, itemId)
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == itemId then
            return child
        elseif child:IsA("Folder") then
            local found = findTemplateRecursive(child, itemId)
            if found then return found end
        end
    end
    return nil
end

-- Get an item template from ReplicatedStorage or other sources
function PlacementManager:GetItemTemplate(itemId)
    print("PlacementManager: Getting template for item:", itemId)
    
    -- 1. Check ServerStorage.Items (recursively)
    local serverItems = game:GetService("ServerStorage"):FindFirstChild("Items")
    if serverItems then
        local ssTemplate = findTemplateRecursive(serverItems, itemId)
        if ssTemplate then
            print("PlacementManager: Found template in ServerStorage.Items (recursive):", itemId)
            return ssTemplate
        end
    end

    -- 2. Check Workspace.Items (recursively)
    local workspaceItems = game:GetService("Workspace"):FindFirstChild("Items")
    if workspaceItems then
        local wsTemplate = findTemplateRecursive(workspaceItems, itemId)
        if wsTemplate then
            print("PlacementManager: Found template in Workspace.Items (recursive):", itemId)
            return wsTemplate
        end
    end

    -- 3. Fallback to ReplicatedStorage.ItemTemplates
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if templates then
        local template = templates:FindFirstChild(itemId)
        if template then
            print("PlacementManager: Found template in ReplicatedStorage.ItemTemplates:", itemId)
            return template
        end
    end
    
    -- Check if this is a numeric item ID that needs to be mapped to a template name
    if self.itemTemplateMap and self.itemTemplateMap[itemId] then
        local mappedTemplate = self.itemTemplateMap[itemId]
        print("PlacementManager: Mapped numeric ID", itemId, "to template name:", mappedTemplate)
        itemId = mappedTemplate
    end
    
    -- Normalize the itemId (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- First check in ReplicatedStorage.ItemTemplates
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if not templates then
        -- Try to create templates folder on server if missing
        if RunService:IsServer() then
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
    print("PlacementManager: No template found for " .. normalizedItemId .. " - creating basic preview")
    
    -- Check if this looks like a numeric ID (item_X format)
    local numericId = normalizedItemId:match("item_(%d+)")
    if numericId then
        print("PlacementManager: ⚠️ Item appears to be a numeric ID (item_" .. numericId .. "). Consider adding it to the itemTemplateMap.")
    end
    
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
        newTemplate.BrickColor = BrickColor.new("Reddish brown")
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
    if RunService:IsClient() then return false end
    
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
    local placedItem
    if template then
        placedItem = template:Clone()
        print("PLACEMENT: Cloned template:", template.Name, "->", placedItem.Name)
        if placedItem:IsA("BasePart") then
            print("  - BrickColor:", placedItem.BrickColor.Name)
            print("  - Material:", placedItem.Material.Name)
            print("  - Transparency:", placedItem.Transparency)
        end
    else
        -- Fallback: create a generic block only if template is missing
        placedItem = Instance.new("Part")
        placedItem.Name = normalizedItemId .. "_" .. player.UserId .. "_" .. os.time()
        placedItem.Size = Vector3.new(2, 2, 2)
        placedItem.Anchored = true
        placedItem.CanCollide = true
        placedItem.BrickColor = BrickColor.new("Medium stone grey")
        placedItem.Material = Enum.Material.Concrete
        placedItem.Transparency = 0
        print("PLACEMENT: Created generic fallback block for:", normalizedItemId)
    end
    
    -- Generate a unique instance ID
    local instanceId = normalizedItemId .. "_" .. player.UserId .. "_" .. tostring(os.time())
    placedItem:SetAttribute("instanceId", instanceId)
    placedItem:SetAttribute("itemId", normalizedItemId)
    placedItem:SetAttribute("owner", player.UserId)
    placedItem:SetAttribute("placedTime", os.time())
    placedItem:SetAttribute("persistent", true)
    
    -- Get item definition to set priceIngame attribute
    local itemDef = self.Constants and self.Constants.ITEMS and self.Constants.ITEMS[normalizedItemId]
    if itemDef and itemDef.priceIngame then
        placedItem:SetAttribute("priceIngame", itemDef.priceIngame)
        print("PlacementManager: Set priceIngame attribute to:", itemDef.priceIngame, "for item:", normalizedItemId)
    else
        placedItem:SetAttribute("priceIngame", 0) -- Default to 0 if not found
        warn("PlacementManager: Could not find priceIngame for", normalizedItemId, "in Constants.ITEMS. Defaulting to 0.")
    end

    -- Assign UniqueItemId if the assigner is available
    if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then
        UniqueItemIdAssigner.assignIdToNewItem(placedItem)
    end
    
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
    print("Parenting placed item", placedItem.Name, "to", placedItem.Parent and placedItem.Parent:GetFullName() or "nil")
    
    -- Add to player's placed items list
    if not self.placedItemsByPlayer[player.UserId] then
        self.placedItemsByPlayer[player.UserId] = {}
    end
    table.insert(self.placedItemsByPlayer[player.UserId], instanceId)
    
    -- Remove from inventory (only 1 item, not the whole stack)
    self:RemoveFromInventory(player, normalizedItemId, 1)
    
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

-- Server: Create an item in the world
function PlacementManager:CreateWorldItem(itemId, position, rotation)
    if RunService:IsClient() then return nil end
    
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
            template.BrickColor = BrickColor.new("Reddish brown")
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
        template = template:Clone()
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

    -- Assign UniqueItemId if the assigner is available
    if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then
        UniqueItemIdAssigner.assignIdToNewItem(item)
    end
    
    -- Add to world folder
    item.Parent = self.placedFolder
    print("Parenting placed item", item.Name, "to", item.Parent and item.Parent:GetFullName() or "nil")
    
    return item
end

-- Find an item by its instanceId
function PlacementManager:FindItemByInstanceId(instanceId)
    if not instanceId then
        warn("PlacementManager: Cannot find item with nil instanceId")
        return nil
    end
    
    -- Check if we have a placed items folder to search
    if not self.placedFolder then
        if RunService:IsServer() then
            -- Create the folder if it doesn't exist on the server
            self.placedFolder = game.Workspace:FindFirstChild("PlacedItems") or Instance.new("Folder")
            self.placedFolder.Name = "PlacedItems"
            self.placedFolder.Parent = game.Workspace
        else
            warn("PlacementManager: No placedFolder available to search")
            return nil
        end
    end
    
    -- Search through all children in the placed folder
    for _, item in ipairs(self.placedFolder:GetChildren()) do
        if item:GetAttribute("instanceId") == instanceId then
            return item
        end
    end
    
    -- If we reach here, the item wasn't found
    return nil
end

-- Server: Get player data from appropriate manager
function PlacementManager:GetPlayerData(player)
    if RunService:IsClient() then return nil end
    
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
    if RunService:IsClient() then return false end
    
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
            local item = self:FindItemByInstanceId(instanceId)
            
            if item then
                local itemData = {
                    instanceId = instanceId,
                    itemId = item:GetAttribute("itemId"),
                    owner = item:GetAttribute("owner") or tonumber(playerId),
                    -- MODIFIED: Store position as a table
                    position = if item:IsA("Model") and item.PrimaryPart then { X = item.PrimaryPart.Position.X, Y = item.PrimaryPart.Position.Y, Z = item.PrimaryPart.Position.Z } else { X = item.Position.X, Y = item.Position.Y, Z = item.Position.Z },
                    -- MODIFIED: Store rotation as a table
                    rotation = if item:IsA("Model") and item.PrimaryPart then { X = item.PrimaryPart.Orientation.X, Y = item.PrimaryPart.Orientation.Y, Z = item.PrimaryPart.Orientation.Z } else { X = item.Orientation.X, Y = item.Orientation.Y, Z = item.Orientation.Z },
                    placedTime = item:GetAttribute("placedTime") or os.time(),
                    priceIngame = item:GetAttribute("priceIngame") or 0 -- Added priceIngame
                }
                
                table.insert(worldData, itemData)
            end
        end
    end
    
    -- Additionally, scan the Placed folder directly to catch any items that might not be in the tracking table
    if self.placedFolder then
        for _, item in ipairs(self.placedFolder:GetChildren()) do
            local instanceId = item:GetAttribute("instanceId")
            
            -- Only add items not already in the list
            if instanceId then
                local found = false
                for _, existingItem in ipairs(worldData) do
                    if existingItem.instanceId == instanceId then
                        found = true
                        break
                    end
                end
                
                if not found then
                    local itemData = {
                        instanceId = instanceId,
                        itemId = item:GetAttribute("itemId"),
                        owner = item:GetAttribute("owner"),
                        -- MODIFIED: Store position as a table
                        position = if item:IsA("Model") and item.PrimaryPart then { X = item.PrimaryPart.Position.X, Y = item.PrimaryPart.Position.Y, Z = item.PrimaryPart.Position.Z } else { X = item.Position.X, Y = item.Position.Y, Z = item.Position.Z },
                        -- MODIFIED: Store rotation as a table
                        rotation = if item:IsA("Model") and item.PrimaryPart then { X = item.PrimaryPart.Orientation.X, Y = item.PrimaryPart.Orientation.Y, Z = item.PrimaryPart.Orientation.Z } else { X = item.Orientation.X, Y = item.Orientation.Y, Z = item.Orientation.Z },
                        placedTime = item:GetAttribute("placedTime") or os.time(),
                        priceIngame = item:GetAttribute("priceIngame") or 0 -- Added priceIngame
                    }
                    
                    table.insert(worldData, itemData)
                end
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

-- Server: Load world data from DataStore
function PlacementManager:LoadWorldData()
    if RunService:IsClient() then return false end
    
    print("PlacementManager: Loading world data...")
    
    local DataService = self.shared and self.shared.DataService
    if not DataService then
        warn("PlacementManager: DataService not available for loading world data")
        return false
    end
    
    -- Load world data from DataService
    local worldData = DataService:GetData("WorldPlacedItems")
    if not worldData or type(worldData) ~= "table" or #worldData == 0 then
        print("PlacementManager: No world data found or empty data")
        return false
    end
    
    print("PlacementManager: Loaded " .. #worldData .. " placed items from storage")
    
    -- Process and spawn each item
    local itemsPlaced = 0
    for _, itemData in ipairs(worldData) do
        if itemData.itemId and itemData.position then
            -- Get the item template
            local template = self:GetItemTemplate(itemData.itemId)
            if template then
                -- Clone the template for placement
                local placedItem = template:Clone()
                -- Ensure the name is unique but consistent if possible for debugging
                local baseName = itemData.itemId
                local ownerSuffix = itemData.owner or "unknown"
                local timeSuffix = itemData.placedTime or os.time() -- Use stored placedTime if available
                placedItem.Name = string.format("%s_%s_%s", baseName, ownerSuffix, timeSuffix)
                
                print(string.format("PlacementManager:LoadWorldData: Processing loaded item. Original itemId: %s, instanceId from data: %s", itemData.itemId, itemData.instanceId))

                -- Get the definitive item definition from Constants
                local itemDef = self.Constants and self.Constants.ITEMS and self.Constants.ITEMS[itemData.itemId]

                if not itemDef then
                    warn(string.format("PlacementManager:LoadWorldData: No item definition found in Constants.ITEMS for itemId: %s. InstanceId: %s. Using stored/default values.", itemData.itemId, itemData.instanceId))
                end

                -- Attempt to derive itemId if it\'s nil from loaded data
                local loadedItemId = itemData.itemId
                if not loadedItemId and itemData.instanceId then
                    -- Try to derive from instanceId (e.g., "Fire_Cube_userid_time")
                    -- Regex: captures characters before the first underscore, then matches an underscore, 
                    -- then captures characters before the next underscore, then matches an underscore,
                    -- then captures the rest. We want the first part.
                    -- More robust: capture up to the last two underscore-separated parts.
                    local basePart = itemData.instanceId:match("^(.*)_([^_]+)_[^_]+$")
                    if basePart then
                        print(string.format("PlacementManager:LoadWorldData: itemId was nil for instanceId \'%s\'. Derived base \'%s\' as itemId.", itemData.instanceId, basePart))
                        loadedItemId = basePart
                    else
                        warn(string.format("PlacementManager:LoadWorldData: itemId was nil for instanceId \'%s\' and could not be derived reliably.", itemData.instanceId))
                    end
                end
                if not loadedItemId then
                     warn(string.format("PlacementManager:LoadWorldData: itemId remains nil for instanceId \'%s\'. This item may not function correctly.", itemData.instanceId))
                end

                -- Set attributes, prioritizing Constants definition
                placedItem:SetAttribute("instanceId", itemData.instanceId) -- This MUST come from saved data
                placedItem:SetAttribute("itemId", loadedItemId) -- This also MUST come from saved data (or derived if was nil)
                placedItem:SetAttribute("owner", itemData.owner) -- This also MUST come from saved data
                placedItem:SetAttribute("placedTime", itemData.placedTime or os.time())
                placedItem:SetAttribute("persistent", true) -- All loaded items are persistent

                -- Refresh attributes from Constants if definition exists
                if itemDef then
                    placedItem:SetAttribute("priceIngame", itemDef.priceIngame)
                    placedItem:SetAttribute("tier", itemDef.tier)
                    placedItem:SetAttribute("description", itemDef.description)
                    placedItem:SetAttribute("name", itemDef.name) -- The display name
                    -- Any other attributes defined in Constants.ITEMS[itemId] can be set here
                    print(string.format("PlacementManager:LoadWorldData: Updated attributes for %s from Constants: priceIngame=%s, tier=%s", itemData.itemId, itemDef.priceIngame, itemDef.tier))
                else
                    -- Fallback for items not in current Constants (e.g., old items)
                    -- Try to use stored price, or default to 0 if not present
                    placedItem:SetAttribute("priceIngame", itemData.priceIngame or 0) 
                    warn(string.format("PlacementManager:LoadWorldData: Using stored priceIngame %s for %s as itemDef was not found.", tostring(itemData.priceIngame or 0), itemData.itemId))
                end

                -- Assign UniqueItemId if the assigner is available AND it wasn\'t already loaded
                -- (The UniqueItemIdAssigner\'s initial scan should handle items already in Workspace.Items)
                -- However, for items loaded *by this function*, we ensure they get an ID if they don\'t have one.
                if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then
                    if placedItem:GetAttribute("UniqueItemId") == nil then
                         UniqueItemIdAssigner.assignIdToNewItem(placedItem)
                         print(string.format("PlacementManager:LoadWorldData: Assigned UniqueItemId to loaded item \'%s\' (InstanceID: %s) as it was missing.", placedItem.Name, itemData.instanceId))
                    else
                        print(string.format("PlacementManager:LoadWorldData: Loaded item \'%s\' (InstanceID: %s) already has UniqueItemId: %s.", placedItem.Name, itemData.instanceId, tostring(placedItem:GetAttribute("UniqueItemId"))))
                    end
                end
                
                -- Convert position from table to Vector3 if needed
                local position = itemData.position
                -- MODIFIED: Always convert from table format
                local posVec = Vector3.new(position.X or position.x or 0, position.Y or position.y or 0, position.Z or position.z or 0)
                
                -- Convert rotation from table to Vector3 if needed
                local rotation = itemData.rotation or {X=0, Y=0, Z=0} -- Ensure rotation table exists
                -- MODIFIED: Always convert from table format
                local rotVec = Vector3.new(rotation.X or rotation.x or 0, rotation.Y or rotation.y or 0, rotation.Z or rotation.z or 0)
                
                -- Position and anchor the item
                if placedItem:IsA("Model") and placedItem.PrimaryPart then
                    placedItem:SetPrimaryPartCFrame(CFrame.new(posVec) * CFrame.fromEulerAnglesXYZ(
                        math.rad(rotVec.X), 
                        math.rad(rotVec.Y), 
                        math.rad(rotVec.Z)
                    ))
                    
                    -- Set all parts to anchored
                    for _, part in pairs(placedItem:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored = true
                            part.CanCollide = true
                        end
                    end
                elseif placedItem:IsA("BasePart") then
                    placedItem.CFrame = CFrame.new(posVec) * CFrame.fromEulerAnglesXYZ(
                        math.rad(rotVec.X), 
                        math.rad(rotVec.Y), 
                        math.rad(rotVec.Z)
                    )
                    placedItem.Anchored = true
                    placedItem.CanCollide = true
                end
                
                -- Parent to the placed items folder
                placedItem.Parent = self.placedFolder
                print("Parenting placed item", placedItem.Name, "to", placedItem.Parent and placedItem.Parent:GetFullName() or "nil")
                
                -- Add to player's placed items list
                local ownerId = itemData.owner
                if ownerId then
                    if not self.placedItemsByPlayer[ownerId] then
                        self.placedItemsByPlayer[ownerId] = {}
                    end
                    table.insert(self.placedItemsByPlayer[ownerId], itemData.instanceId)
                end
                
                itemsPlaced = itemsPlaced + 1
            else
                warn("PlacementManager: Failed to find template for item:", itemData.itemId)
            end
        end
    end
    
    print("PlacementManager: Successfully spawned " .. itemsPlaced .. " world items")
    return true
end

-- Server: Remove an item from the player's inventory
function PlacementManager:RemoveFromInventory(player, itemId, quantity)
    if RunService:IsClient() then return false end
    
    quantity = quantity or 1  -- Default to 1 if not specified
    print("PlacementManager: Attempting to remove", quantity, "x", itemId, "from inventory of", player.Name)
    
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
            return ItemPurchaseHandler:RemoveFromInventory(player, itemId, quantity)
        end)
        
        if success and result then
            print("PlacementManager: Successfully removed", quantity, "x", itemId, "using ItemPurchaseHandler directly")
    return true
        end
    end
    
    -- 2. Try with ItemPurchaseHandler through SharedModule
    if self.shared and self.shared.ItemPurchaseHandler and 
       self.shared.ItemPurchaseHandler.RemoveFromInventory then
        local success, result = pcall(function()
            return self.shared.ItemPurchaseHandler:RemoveFromInventory(player, itemId, quantity)
        end)
        
        if success and result then
            print("PlacementManager: Successfully removed", quantity, "x", itemId, "using SharedModule.ItemPurchaseHandler")
            return true
        end
    end
    
    -- 3. Try with InventoryManager if available
    local InventoryManager = self.shared and self.shared.InventoryManager
    if not InventoryManager then
        -- Try to find InventoryManager in ServerStorage or other locations
        local success, result = pcall(function()
            return require(game:GetService("ServerStorage").server.InventoryManager)
        end)
        
        if success then
            InventoryManager = result
            print("PlacementManager: Found InventoryManager in ServerStorage")
        end
    end
    
    if InventoryManager and InventoryManager.RemoveItem then
        local success, result = pcall(function()
            return InventoryManager:RemoveItem(player, itemId, quantity)
        end)
        
        if success and result then
            print("PlacementManager: Successfully removed", quantity, "x", itemId, "using InventoryManager")
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
                
                -- Check if the item uses count or quantity property
                local currentCount = item.quantity or item.count or 1
                
                if currentCount <= quantity then
                    -- Remove the entire item
                    table.remove(playerData.inventory, i)
                    print("PlacementManager: Manually removed entire item from inventory (had", currentCount, "items)")
                else
                    -- Reduce quantity
                    if item.quantity ~= nil then
                        item.quantity = currentCount - quantity
                        print("PlacementManager: Reduced item.quantity from", currentCount, "to", item.quantity)
                    elseif item.count ~= nil then
                        item.count = currentCount - quantity
                        print("PlacementManager: Reduced item.count from", currentCount, "to", item.count)
                    end
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
    -- This function can be called by both server and client, so no specific IsServer/IsClient check at the start
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

-- Server: Delete an item from the world
function PlacementManager:DeleteItem(player, instanceId)
    if RunService:IsClient() then return false end
    
    print("PlacementManager: Deleting item", instanceId, "for player", player.Name)
    
    -- Find the item by instanceId
    local item = self:FindItemByInstanceId(instanceId)
    if not item then
        warn("PlacementManager: Cannot delete - item not found:", instanceId)
        return false
    end
    
    -- Check if player owns the item (or is an admin)
    local ownerId = item:GetAttribute("owner")
    local isAdmin = player:GetAttribute("IsAdmin") or false
    
    if ownerId ~= player.UserId and not isAdmin then
        warn("PlacementManager: Player", player.Name, "does not own item and is not admin")
        return false
    end
    
    -- Remove from the actual owner's placed items list
    if ownerId and self.placedItemsByPlayer and self.placedItemsByPlayer[ownerId] then
        for i, id_in_list in ipairs(self.placedItemsByPlayer[ownerId]) do
            if id_in_list == instanceId then
                table.remove(self.placedItemsByPlayer[ownerId], i)
                print(string.format("PlacementManager: Removed instanceId %s from placedItemsByPlayer for ownerId %s.", instanceId, tostring(ownerId)))
                break
            end
        end
    end
    
    -- Destroy the item
    item:Destroy()
    
    -- Notify the client
    if self.remotes.ItemDeleted then
        self.remotes.ItemDeleted:FireClient(player, instanceId)
    end
    
    -- Save world data after deletion (non-blocking)
    task.spawn(function()
        self:SaveWorldData()
    end)
    
    return true
end

-- Server: Update an item's position or rotation
function PlacementManager:UpdateItem(player, instanceId, position, rotation)
    if RunService:IsClient() then return false end
    
    print("PlacementManager: Updating item", instanceId, "for player", player.Name)
    
    -- Find the item
    local item = self:FindItemByInstanceId(instanceId)
    if not item then
        warn("PlacementManager: Cannot update - item not found:", instanceId)
        return false
    end
    
    -- Check ownership
    local ownerId = item:GetAttribute("owner")
    if ownerId ~= player.UserId then
        -- Check if player is an admin (admins can modify any item)
        local isAdmin = player:GetAttribute("IsAdmin") or false
        
        if not isAdmin then
            warn("PlacementManager: Player", player.Name, "does not own this item")
            return false
        end
    end
    
    -- Update position and rotation
    if position then
        if item:IsA("Model") and item.PrimaryPart then
            local rotationCFrame
            if typeof(rotation) == "Vector3" then
                rotationCFrame = CFrame.fromEulerAnglesXYZ(
                    math.rad(rotation.X or 0),
                    math.rad(rotation.Y or 0),
                    math.rad(rotation.Z or 0)
                )
            else
                rotationCFrame = CFrame.Angles(0, math.rad(rotation or 0), 0)
            end
            
            item:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        elseif item:IsA("BasePart") then
            local rotationCFrame
            if typeof(rotation) == "Vector3" then
                rotationCFrame = CFrame.fromEulerAnglesXYZ(
                    math.rad(rotation.X or 0),
                    math.rad(rotation.Y or 0),
                    math.rad(rotation.Z or 0)
                )
            else
                rotationCFrame = CFrame.Angles(0, math.rad(rotation or 0), 0)
            end
            
            item.CFrame = CFrame.new(position) * rotationCFrame
        end
        
        -- Update last modified timestamp
        item:SetAttribute("lastModified", os.time())
        
        -- Notify the client
        if self.remotes.ItemUpdated then
            self.remotes.ItemUpdated:FireClient(player, instanceId, position, rotation)
        end
        
        -- Save world data after update
        task.spawn(function()
            self:SaveWorldData()
        end)
        
        return true
    end
    
    return false
end

-- Client: Start the item placement process
function PlacementManager:StartPlacing(itemId)
    if RunService:IsServer() then return false end
    
    print("PlacementManager: Client StartPlacing for item:", itemId) -- MARKER
    
    -- Clear any existing preview item
    self:ClearItemFromHand()
    
    -- Set placing state
    self.isPlacing = true
    self.selectedItem = itemId
    
    -- Create the preview item
    local previewItem = self:CreatePreviewItem(itemId)
    if not previewItem then
        warn("PlacementManager: Failed to create preview item for", itemId)
        self.isPlacing = false
        self.selectedItem = nil
        return false
    end
    
    self.previewItem = previewItem
    
    -- Start the placement preview update loop
    local movementConnection
    movementConnection = RunService.RenderStepped:Connect(function()
        if not self.isPlacing or not self.previewItem then
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
            return
        end
        
        self:UpdatePlacementPreview()
    end)
    
    -- Setup input to place the item on click
    local userInputService = game:GetService("UserInputService")
    local inputConnection
    
    inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left-click to place
            if self.isPlacing and self.previewItem then
                -- Get current position and rotation
                local position, rotation
                if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
                    position = self.previewItem.PrimaryPart.Position
                    rotation = self.previewItem.PrimaryPart.Orientation
                else
                    position = self.previewItem.Position
                    rotation = self.previewItem.Orientation
                end
                
                -- Request server to place the item
                print("PlacementManager: StartPlacing - About to fire PlaceItem. self.remotes.PlaceItem is:", self.remotes and self.remotes.PlaceItem or "nil_remotes_or_placeitem") -- MARKER
                if self.remotes and self.remotes.PlaceItem then
                    self.remotes.PlaceItem:FireServer(self.selectedItem, position, rotation)
                    print("PlacementManager: Requested server to place item:", self.selectedItem)
                else
                    warn("PlacementManager: Cannot place item - remote event not found. self.remotes table:", self.remotes, "self.remotes.PlaceItem:", self.remotes and self.remotes.PlaceItem or "nil") -- MARKER
                end
                
                -- Clean up
                self:ClearItemFromHand()
                self.isPlacing = false
                
                -- Disconnect the input handler
                if inputConnection then
                    inputConnection:Disconnect()
                    inputConnection = nil
                end
                
                -- Disconnect the movement handler
                if movementConnection then
                    movementConnection:Disconnect()
                    movementConnection = nil
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right-click or Escape to cancel
            self:ClearItemFromHand()
            self.isPlacing = false
            
            -- Disconnect the input handler
            if inputConnection then
                inputConnection:Disconnect()
                inputConnection = nil
            end
            
            -- Disconnect the movement handler
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
        end
    end)
    
    return true
end

-- Client: Create a preview item for placement
function PlacementManager:CreatePreviewItem(itemId)
    if RunService:IsServer() then return nil end
    
    print("PlacementManager: Creating preview item for:", itemId)
    
    -- Normalize the item ID
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- First try to get the template
    local template = self:GetItemTemplate(normalizedItemId)
    if not template then
        warn("PlacementManager: Failed to find template for", normalizedItemId)
        return nil
    end
    
    -- Clone the template for preview
    local previewItem = template:Clone()
    previewItem.Name = "Preview_" .. normalizedItemId
    
    -- Make preview translucent and disable collision
    if previewItem:IsA("Model") then
        for _, part in ipairs(previewItem:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = math.min(0.8, part.Transparency + 0.5)
                part.CanCollide = false
                part.Anchored = true
                
                -- Set custom attribute for debugging
                part:SetAttribute("is_preview", true)
            end
        end
    elseif previewItem:IsA("BasePart") then
        previewItem.Transparency = math.min(0.8, previewItem.Transparency + 0.5)
        previewItem.CanCollide = false
        previewItem.Anchored = true
        
        -- Set custom attribute for debugging
        previewItem:SetAttribute("is_preview", true)
    end
    
    -- Create a highlight effect for better visibility
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green fill
    highlight.OutlineColor = Color3.fromRGB(0, 255, 0) -- Green outline
    highlight.Parent = previewItem
    
    -- Add preview to workspace
    previewItem.Parent = Workspace
    
    return previewItem
end

-- Client: Update the preview item position and appearance based on mouse position
function PlacementManager:UpdatePlacementPreview()
    if RunService:IsServer() or not self.isPlacing or not self.previewItem then return end
    
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    
    -- Raycast to find the surface
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {self.previewItem}
    
    local cameraPosition = Workspace.CurrentCamera.CFrame.Position
    local mouseDirection = mouse.UnitRay.Direction * MAX_PLACEMENT_DISTANCE
    local raycastResult = Workspace:Raycast(cameraPosition, mouseDirection, raycastParams)
    
    -- If no surface was hit, show out of range indicator
    if not raycastResult then
        -- Set preview to max distance along ray
        local maxDistancePosition = cameraPosition + (mouseDirection.Unit * MAX_PLACEMENT_DISTANCE)
        
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
            self.previewItem:SetPrimaryPartCFrame(CFrame.new(maxDistancePosition))
        else
            self.previewItem.CFrame = CFrame.new(maxDistancePosition)
        end
        
        -- Change highlight color to red to indicate out of range
        local highlight = self.previewItem:FindFirstChildOfClass("Highlight")
        if highlight then
            highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red
            highlight.OutlineColor = Color3.fromRGB(255, 0, 0) -- Red
        end
        
        return
    end
    
    -- Surface hit, determine placement position
    local hitPosition = raycastResult.Position
    local hitNormal = raycastResult.Normal
    
    -- Create rotation based on surface normal
    local surfaceRotation = CFrame.fromMatrix(Vector3.new(), hitNormal:Cross(Vector3.new(0, 1, 0)), hitNormal)
    
    -- Apply grid snapping if enabled
    local snappedPosition = hitPosition
    if GRID_SIZE > 0 then
        snappedPosition = Vector3.new(
            math.floor(hitPosition.X / GRID_SIZE + 0.5) * GRID_SIZE,
            hitPosition.Y,
            math.floor(hitPosition.Z / GRID_SIZE + 0.5) * GRID_SIZE
        )
    end
    
    -- Calculate item height to adjust position
    local itemHeight = 2 -- Default height
    if self.previewItem:IsA("BasePart") then
        itemHeight = self.previewItem.Size.Y
    elseif self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
        itemHeight = self.previewItem.PrimaryPart.Size.Y
    end
    
    -- Adjust Y position to place bottom of item at surface level
    local adjustedPosition = Vector3.new(
        snappedPosition.X,
        snappedPosition.Y + (itemHeight/2),
        snappedPosition.Z
    )
    
    -- Position the preview item
    if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
        self.previewItem:SetPrimaryPartCFrame(CFrame.new(adjustedPosition) * surfaceRotation)
    else
        self.previewItem.CFrame = CFrame.new(adjustedPosition) * surfaceRotation
    end
    
    -- Update highlight color based on placement validity
    local canPlace = true -- Add placement validation logic here
    
    local highlight = self.previewItem:FindFirstChildOfClass("Highlight")
    if highlight then
        if canPlace then
            highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green
            highlight.OutlineColor = Color3.fromRGB(0, 255, 0) -- Green
        else
            highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red
            highlight.OutlineColor = Color3.fromRGB(255, 0, 0) -- Red
        end
    end
end

-- Client: Show an item in the player's hand for inspection
function PlacementManager:ShowItemInHand(itemId)
    if RunService:IsServer() then return false end
    
    print("PlacementManager: Showing item in hand:", itemId)
    
    -- Clear any existing item in hand
    self:ClearItemFromHand()
    
    -- Get the item template
    local normalizedItemId = itemId:gsub(" ", "_")
    local template = self:GetItemTemplate(normalizedItemId)
    if not template then
        warn("PlacementManager: Failed to find template for", normalizedItemId)
        return false
    end
    
    -- Clone the template for display
    local displayItem = template:Clone()
    displayItem.Name = "HandItem_" .. normalizedItemId
    
    -- Adjust transparency and other properties for better hand visualization
    if displayItem:IsA("Model") then
        for _, part in ipairs(displayItem:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = math.max(0, part.Transparency - 0.2) -- Make slightly more visible
                part.CanCollide = false
                part.Anchored = true
                part:SetAttribute("is_hand_item", true)
            end
        end
    elseif displayItem:IsA("BasePart") then
        displayItem.Transparency = math.max(0, displayItem.Transparency - 0.2)
        displayItem.CanCollide = false
        displayItem.Anchored = true
        displayItem:SetAttribute("is_hand_item", true)
    end
    
    -- Add a highlight effect for better visibility
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(255, 215, 0) -- Gold fill
    highlight.OutlineColor = Color3.fromRGB(255, 215, 0) -- Gold outline
    highlight.Parent = displayItem
    
    -- Add to workspace
    displayItem.Parent = Workspace
    
    -- Store reference
    self.handItem = displayItem
    self.handItemId = normalizedItemId
    
    -- Position the item in front of the player
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Connect movement to update hand item position
    local movementConnection
    movementConnection = RunService.RenderStepped:Connect(function()
        if not self.handItem then
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
            return
        end
        
        -- Position in front of the player
        local offset = humanoidRootPart.CFrame.LookVector * 3
        local position = humanoidRootPart.Position + offset
        position = Vector3.new(position.X, position.Y + 1, position.Z) -- Adjust height
        
        -- Rotate the item slowly
        local rotationAngle = tick() % (2 * math.pi) -- Slow continuous rotation
        local rotationCFrame = CFrame.Angles(0, rotationAngle, 0)
        
        if self.handItem:IsA("Model") and self.handItem.PrimaryPart then
            self.handItem:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        else
            self.handItem.CFrame = CFrame.new(position) * rotationCFrame
        end
    end)
    
    -- Setup input handler for interaction
    local userInputService = game:GetService("UserInputService")
    local inputConnection
    
    inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click to place
            self:StartPlacing(self.handItemId)
            
            -- Disconnect the input handler
            if inputConnection then
                inputConnection:Disconnect()
                inputConnection = nil
            end
            
            -- Disconnect the movement handler
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
            
            -- Clear the hand item (StartPlacing will create a preview)
            self.handItem = nil
            self.handItemId = nil
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or Escape to close
            self:ClearItemFromHand()
            
            -- Disconnect the input handler
            if inputConnection then
                inputConnection:Disconnect()
                inputConnection = nil
            end
            
            -- Disconnect the movement handler
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
        end
    end)
    
    return true
end

-- Client: Recall an item from inventory to show in hand
function PlacementManager:RecallItemFromInventory(itemId)
    if RunService:IsServer() then return false end
    
    print("PlacementManager: Recalling item from inventory:", itemId)
    
    -- Check if the item is in the player's inventory
    local player = Players.LocalPlayer
    
    -- Normalize the item ID
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- Try to show the item in hand first
    local success = self:ShowItemInHand(normalizedItemId)
    if not success then
        warn("PlacementManager: Failed to show item in hand:", normalizedItemId)
        return false
    end
    
    -- Notify user that they can now place the item
    local message = "Left-click to place " .. normalizedItemId .. " or right-click to cancel"
    
    -- Check if we have a UI notification system
    local UIManager = self.shared and self.shared.UIManager
    if UIManager and UIManager.ShowNotification then
        UIManager:ShowNotification(message, 5)
    else
        -- Fallback to direct GUI message
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PlacementNotification"
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0, 400, 0, 50)
        textLabel.Position = UDim2.new(0.5, -200, 0.8, 0)
        textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.BackgroundTransparency = 0.5
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextSize = 18
        textLabel.Text = message
        textLabel.Parent = screenGui
        
        -- Auto-cleanup after 5 seconds
        task.spawn(function()
            task.wait(5)
            screenGui:Destroy()
        end)
        
        -- Add to player's GUI
        screenGui.Parent = player.PlayerGui
    end
    
    return true
end

-- Client: Clear any displayed item from hand
function PlacementManager:ClearItemFromHand()
    if RunService:IsServer() then return end
    
    if self.handItem then
        print("PlacementManager: Clearing item from hand:", self.handItem.Name)
        self.handItem:Destroy()
        self.handItem = nil
        self.handItemId = nil
    end
    
    if self.previewItem then
        print("PlacementManager: Clearing preview item:", self.previewItem.Name)
        self.previewItem:Destroy()
        self.previewItem = nil
    end
    
    self.isPlacing = false
    self.selectedItem = nil
end

-- Setup remote events for client-server communication
function PlacementManager:SetupRemoteEvents()
    print("PlacementManager: Setting up remote events")
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    -- Create remote events for placement system if they don't exist
    local events = {
        "PlaceItem",       -- Client -> Server: Request to place an item
        "ItemPlaced",      -- Server -> Client: Notify that an item was placed
        "RecallItem",      -- Client -> Server: Request to recall an item
        "ItemRecalled",    -- Server -> Client: Notify that an item was recalled
        "UpdateItem",      -- Client -> Server: Update item properties (position, etc.)
        "ItemUpdated",     -- Server -> Client: Notify that an item was updated
        "DeleteItem",      -- Client -> Server: Request to delete an item
        "ItemDeleted"      -- Server -> Client: Notify that an item was deleted
    }
    
    self.remotes = {}
    
    for _, eventName in ipairs(events) do
        local event = remotes:FindFirstChild(eventName)
        if not event then
            event = Instance.new("RemoteEvent")
            event.Name = eventName
            event.Parent = remotes
            print("PlacementManager: Created remote event:", eventName)
        else
            print("PlacementManager: Using existing remote event:", eventName)
        end
        
        self.remotes[eventName] = event
    end
    
    if RunService:IsServer() then
        -- Connect server-side event handlers
        self.remotes.PlaceItem.OnServerEvent:Connect(function(player, itemId, position, rotation)
            self:PlaceItem(player, itemId, position, rotation)
        end)
        
        self.remotes.UpdateItem.OnServerEvent:Connect(function(player, instanceId, position, rotation)
            self:UpdateItem(player, instanceId, position, rotation)
        end)
        
        self.remotes.DeleteItem.OnServerEvent:Connect(function(player, instanceId)
            self:DeleteItem(player, instanceId)
        end)
    else
        -- Connect client-side event handlers
        self.remotes.ItemPlaced.OnClientEvent:Connect(function(itemId, instanceId)
            print("PlacementManager: Received ItemPlaced event for", itemId)
            -- Update UI or other client-side state as needed
        end)
        
        self.remotes.ItemRecalled.OnClientEvent:Connect(function(itemId)
            print("PlacementManager: Received ItemRecalled event for", itemId)
            -- Update UI or other client-side state as needed
        end)
        
        self.remotes.ItemUpdated.OnClientEvent:Connect(function(instanceId, position, rotation)
            print("PlacementManager: Received ItemUpdated event for", instanceId)
            -- Update UI or other client-side state as needed
        end)
        
        self.remotes.ItemDeleted.OnClientEvent:Connect(function(instanceId)
            print("PlacementManager: Received ItemDeleted event for", instanceId)
            -- Update UI or other client-side state as needed
        end)
    end
    
    print("PlacementManager: Remote events setup completed")
end

-- Client: Cache remote events
function PlacementManager:CacheRemoteEvents()
    if RunService:IsServer() then return end
    
    print("PlacementManager: Caching remote events --- MARKER ---") -- MARKER
    
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        warn("PlacementManager: Remotes folder not found initially during CacheRemoteEvents. Waiting...") -- MARKER
        remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10) -- Wait up to 10 seconds
        if not remotesFolder then
            warn("PlacementManager: Remotes folder STILL not found after WaitForChild(10). Cannot cache remotes.") -- MARKER
            return false
        end
        print("PlacementManager: Remotes folder found after WaitForChild.") -- MARKER
    else
        print("PlacementManager: Remotes folder found immediately.") -- MARKER
    end
    
    -- Cache all required remote events
    local events = {
        "PlaceItem",
        "ItemPlaced",
        "RecallItem",
        "ItemRecalled",
        "UpdateItem",
        "ItemUpdated",
        "DeleteItem",
        "ItemDeleted"
    }
    
    self.remotes = self.remotes or {} -- Ensure self.remotes is initialized (should be by .new)
    local allEventsCached = true

    for _, eventName in ipairs(events) do
        local event = remotesFolder:FindFirstChild(eventName)
        if not event then
            warn("PlacementManager: Event '"..eventName.."' not found initially in Remotes folder. Waiting for it (5s)...") -- MARKER
            event = remotesFolder:WaitForChild(eventName, 5) -- Wait up to 5 seconds for the specific event
            if not event then
                warn("PlacementManager: FAILED to find remote event after wait: " .. eventName) -- MARKER
                allEventsCached = false
            else
                print("PlacementManager: Found event '"..eventName.."' after WaitForChild.") -- MARKER
            end
        end

        if event and event:IsA("RemoteEvent") then
            self.remotes[eventName] = event
            print("PlacementManager: Successfully cached remote event: " .. eventName) -- MARKER
        elseif event then
            warn("PlacementManager: Found instance named '"..eventName.."' but it's not a RemoteEvent. Type: "..event:GetFullName() .. " is a " .. event.ClassName) -- MARKER
            allEventsCached = false
        else
            -- This case is covered by the "FAILED to find" warning above if WaitForChild also failed
            if not remotesFolder:FindFirstChild(eventName) then -- Double check if it really failed
                 allEventsCached = false
            end
        end
    end
    
    if not allEventsCached then
        warn("PlacementManager: CacheRemoteEvents - Not all remote events were cached successfully.") -- MARKER
    else
        print("PlacementManager: CacheRemoteEvents - All expected remote events appear to be cached.") -- MARKER
    end
    return allEventsCached
end

-- Placeholder for handling a CLONE item request (server-side)
function PlacementManager:HandleCloneItemRequest(player, itemInstance, cost, originalItemId)
    print(string.format("PlacementManager:HandleCloneItemRequest CALLED for item: %s by player %s (cost: %s, originalId: %s)", tostring(itemInstance and itemInstance.Name), tostring(player and player.Name), tostring(cost), tostring(originalItemId)))
    
    if not itemInstance or not itemInstance.Parent then
        return {success = false, message = "Original item not found or invalid."}
    end

    local template = self:GetItemTemplate(originalItemId)
    if not template then
        return {success = false, message = string.format("Template for '%s' not found.", tostring(originalItemId))}
    end

    local newItem = template:Clone()
    local newInstanceId = originalItemId .. "_" .. player.UserId .. "_" .. tostring(os.time()) .. "_clone"
    
    newItem:SetAttribute("instanceId", newInstanceId)
    newItem:SetAttribute("itemId", originalItemId) 
    newItem:SetAttribute("owner", player.UserId)
    newItem:SetAttribute("creator", player.UserId) 
    newItem:SetAttribute("IsPlaced", true)
    
    local itemInfo = self.Constants.ITEMS[originalItemId]
    if itemInfo then
        for k, v in pairs(itemInfo) do
            if k ~= "func" and k ~= "script" and k~="OnPlaced" and k~="OnRemoved" and k~="OnCloned" then
                newItem:SetAttribute(k, v)
            end
        end
    end
    
    newItem.Parent = self.WorldItemsPlacedFolder
    self:_trackItem(newItem, player.UserId)
    
    if itemInfo and itemInfo.OnCloned then
        pcall(itemInfo.OnCloned, newItem, player, itemInstance)
    end

    self:SaveWorldData()
    
    local final_s_originalItemId = tostring(originalItemId)
    local final_s_cost = tostring(cost)
    local final_s_newInstanceId = tostring(newInstanceId)
    
    local currency_for_message_clone
    local raw_ingame_currency_value = self.Constants.CURRENCY.INGAME
    print(string.format("HandleCloneItemRequest DEBUG: raw_ingame_currency_value is '%s' (type: %s)", tostring(raw_ingame_currency_value), type(raw_ingame_currency_value)))

    if type(raw_ingame_currency_value) == "string" and raw_ingame_currency_value ~= "" then
        currency_for_message_clone = raw_ingame_currency_value
    else
        currency_for_message_clone = "coins" -- Default
    end
    print(string.format("HandleCloneItemRequest DEBUG: currency_for_message_clone decided as '%s'", currency_for_message_clone))

    local message = string.format("Item %s cloned for %s %s. New item ID: %s", final_s_originalItemId, final_s_cost, currency_for_message_clone, final_s_newInstanceId)
    print("HandleCloneItemRequest DEBUG: Success message prepared: " .. message)
    return {success = true, message = message, newItemInstanceId = newInstanceId, newItem = newItem}
end

-- Placeholder for handling a MOVE item request (server-side)
function PlacementManager:HandleMoveItemRequest(player, itemInstance, cost, originalItemId, newPosition, newRotation)
    print(string.format("PlacementManager:HandleMoveItemRequest called for item: %s by player %s (cost: %s, originalId: %s)", itemInstance.Name, player.Name, tostring(cost), originalItemId))
    
    if not itemInstance or not itemInstance.Parent then
        return {success = false, message = "Item to move not found or invalid."}
    end

    if not newPosition or not newRotation then
        return {success = false, message = string.format("Move action for %s requires new position/rotation data from client. (Not fully implemented client-side)", originalItemId)}
    end

    local ownerId = itemInstance:GetAttribute("owner")
    if ownerId ~= player.UserId and not (player:GetAttribute("IsAdmin") == true) then
        return {success = false, message = "You do not own this item."}
    end

    local finalPosition = newPosition
    if type(newPosition) == "table" then
        finalPosition = Vector3.new(newPosition.X or 0, newPosition.Y or 0, newPosition.Z or 0)
    end

    local finalRotation = newRotation 
    if type(newRotation) == "table" then 
        finalRotation = Vector3.new(newRotation.X or 0, newRotation.Y or 0, newRotation.Z or 0)
    end

    local success, updateMessage
    if itemInstance:IsA("Model") and itemInstance.PrimaryPart then
        local cfRotation
        if typeof(finalRotation) == "Vector3" then
            cfRotation = CFrame.fromEulerAnglesXYZ(math.rad(finalRotation.X), math.rad(finalRotation.Y), math.rad(finalRotation.Z))
        else 
            cfRotation = finalRotation 
        end
        itemInstance:SetPrimaryPartCFrame(CFrame.new(finalPosition) * cfRotation)
        success = true
    elseif itemInstance:IsA("BasePart") then
        local cfRotation
        if typeof(finalRotation) == "Vector3" then
            cfRotation = CFrame.fromEulerAnglesXYZ(math.rad(finalRotation.X), math.rad(finalRotation.Y), math.rad(finalRotation.Z))
        else 
            cfRotation = finalRotation
        end
        itemInstance.CFrame = CFrame.new(finalPosition) * cfRotation
        success = true
    else
        success = false
        updateMessage = "Item is not a Model or BasePart."
    end
    
    if success then
        itemInstance:SetAttribute("lastModified", os.time())
        self:SaveWorldData()
        return {success = true, message = string.format("Item %s moved for %s %s.", originalItemId, cost, self.Constants.CURRENCY.INGAME or "coins")}
    else
        return {success = false, message = updateMessage or string.format("Failed to move %s.", originalItemId)}
    end
end

-- Placeholder for handling a COSTED RECALL item request (server-side)
function PlacementManager:HandleCostedRecallItemRequest(player, itemInstance, cost, originalItemId)
    print(string.format("PlacementManager:HandleCostedRecallItemRequest CALLED for item: %s by player %s (cost: %s, originalItemId: %s)", tostring(itemInstance and itemInstance.Name), tostring(player and player.Name), tostring(cost), tostring(originalItemId)))

    if not itemInstance or not itemInstance.Parent then
        return {success = false, message = "Item to recall not found or invalid."}
    end

    if not originalItemId then 
        return {success = false, message = "Cannot recall item: Original ItemID is missing."}
    end

    -- 1. Add item back to inventory
    local ItemPurchaseHandler = self.shared and self.shared.ItemPurchaseHandler
    if not ItemPurchaseHandler then
        local successRequire, requiredModule = pcall(require, ServerScriptService.ItemPurchaseHandler)
        if successRequire then ItemPurchaseHandler = requiredModule end
    end

    if ItemPurchaseHandler then
        print("HandleCostedRecallItemRequest DEBUG: Attempting to add item to inventory via ItemPurchaseHandler: ", originalItemId)
        local successAdd, resultAdd = pcall(ItemPurchaseHandler.AddToInventory, ItemPurchaseHandler, player, originalItemId, 1)
        if not successAdd or not resultAdd then
            local errMessage = resultAdd or "Unknown error adding item to inventory."
            print("HandleCostedRecallItemRequest WARNING: Failed to add item to inventory via ItemPurchaseHandler: " .. tostring(errMessage))
            -- Proceeding with recall even if inventory add fails, but this is a warning.
        else
            print("HandleCostedRecallItemRequest DEBUG: Successfully added item to inventory via ItemPurchaseHandler.")
        end
    else
        warn("HandleCostedRecallItemRequest WARNING: ItemPurchaseHandler module not found. Cannot add item to inventory.")
        -- Decide if this is a fatal error for recall. For now, let's allow recall to proceed.
        -- return {success = false, message = "System error: ItemPurchaseHandler not available."}
    end
    
    -- 2. Remove item from world (using existing DeleteItem logic but without cost/refund)
    local uniqueItemId = itemInstance:GetAttribute("UniqueItemId")
    if uniqueItemId then
        self.ItemsByUniqueId[uniqueItemId] = nil
    end
    local ownerId = itemInstance:GetAttribute("owner")
    if ownerId and self.ItemsByOwner[ownerId] then
        local items = self.ItemsByOwner[ownerId]
        for i, id in ipairs(items) do
            if id == uniqueItemId then
                table.remove(items, i)
                break
            end
        end
    end
    local instanceId = itemInstance:GetAttribute("instanceId")
    if instanceId then
         self.ItemsByInstanceId[instanceId] = nil
    end
    
    itemInstance:Destroy()
    self:SaveWorldData() 
    print(string.format("PlacementManager:HandleCostedRecallItemRequest - Item %s (InstanceID: %s) destroyed and removed from tracking.", tostring(originalItemId), tostring(instanceId)))

    local final_s_originalItemId_recall = tostring(originalItemId)
    local final_s_cost_recall = tostring(cost)

    local currency_for_message_recall
    local raw_ingame_currency_value_recall = self.Constants.CURRENCY.INGAME
    print(string.format("HandleCostedRecallItemRequest DEBUG: raw_ingame_currency_value_recall is '%s' (type: %s)", tostring(raw_ingame_currency_value_recall), type(raw_ingame_currency_value_recall)))

    if type(raw_ingame_currency_value_recall) == "string" and raw_ingame_currency_value_recall ~= "" then
        currency_for_message_recall = raw_ingame_currency_value_recall
    else
        currency_for_message_recall = "coins" -- Default
    end
    print(string.format("HandleCostedRecallItemRequest DEBUG: currency_for_message_recall decided as '%s'", currency_for_message_recall))
    
    local message_recall = string.format("Item %s recalled for %s %s. Added back to inventory.", final_s_originalItemId_recall, final_s_cost_recall, currency_for_message_recall)
    print("HandleCostedRecallItemRequest DEBUG: Success message prepared: " .. message_recall)
    return {success = true, message = message_recall, recalledItemId = originalItemId}
end

-- Placeholder for handling a DESTROY item request (server-side)
function PlacementManager:HandleDestroyItemRequest(player, itemInstance, cost, originalItemId)
    -- Log entry point and initial parameters
    local pName = (player and player.Name) or "UnknownPlayer"
    local iName = (itemInstance and itemInstance.Name) or "UnknownItemInstance"
    local cValue = cost or "UnknownCost"
    local oItemId = originalItemId or "UnknownOriginalItemId"
    print(string.format("PlacementManager:HandleDestroyItemRequest ENTERED. Player: %s, ItemInstance Name: %s, Cost: %s, OriginalItemId: %s", tostring(pName), tostring(iName), tostring(cValue), tostring(oItemId)))

    if not itemInstance or not itemInstance.Parent then
        print("PlacementManager:HandleDestroyItemRequest - itemInstance or parent is nil. Returning error.")
        return {success = false, message = "Item to destroy not found or invalid."}
    end
    
    print("PlacementManager:HandleDestroyItemRequest - Proceeding to DeleteItem.")
    local instanceIdToDel = (itemInstance and itemInstance:GetAttribute("instanceId")) or (itemInstance and itemInstance.Name) or "UnknownInstanceIdForDelete"
    print(string.format("PlacementManager:HandleDestroyItemRequest - Calling DeleteItem with Player: %s, InstanceID: %s", tostring(pName), tostring(instanceIdToDel)))
    
    local success = self:DeleteItem(player, instanceIdToDel)
    print(string.format("PlacementManager:HandleDestroyItemRequest - DeleteItem returned: %s", tostring(success)))

    if success then
        print("PlacementManager:HandleDestroyItemRequest - DeleteItem was successful.")
        local currencyName = "coins" -- Default currency name
        if self.Constants and self.Constants.CURRENCY and self.Constants.CURRENCY.INGAME then
            currencyName = self.Constants.CURRENCY.INGAME
            if currencyName == nil then
                print("PlacementManager:HandleDestroyItemRequest - WARNING: self.Constants.CURRENCY.INGAME was nil, falling back to 'coins'.")
                currencyName = "coins"
            end
        else
            print("PlacementManager:HandleDestroyItemRequest - self.Constants.CURRENCY.INGAME not found, using default 'coins'.")
        end
        
        -- Values for the success message
        local msg_originalItemId = tostring(originalItemId or "NilOriginalId")
        local msg_cost = tostring(cost or "NilCost")
        local msg_currencyName = tostring(currencyName or "NilCurrency")

        print(string.format("PlacementManager:HandleDestroyItemRequest - Formatting success message with: originalItemId='%s', cost='%s', currencyName='%s'", msg_originalItemId, msg_cost, msg_currencyName))
        local successMessage = string.format("Item %s destroyed. You were charged %s %s.", msg_originalItemId, msg_cost, msg_currencyName)
        print(string.format("PlacementManager:HandleDestroyItemRequest - Success message created: %s", successMessage))
        return {success = true, message = successMessage}
    else
        print("PlacementManager:HandleDestroyItemRequest - DeleteItem failed.")
        local msg_originalItemId_fail = tostring(originalItemId or "NilOriginalIdForFailMsg")
        print(string.format("PlacementManager:HandleDestroyItemRequest - Formatting fail message with: originalItemId='%s'", msg_originalItemId_fail))
        local failMessage = string.format("Failed to destroy %s.", msg_originalItemId_fail)
        print(string.format("PlacementManager:HandleDestroyItemRequest - Fail message created: %s", failMessage))
        return {success = false, message = failMessage}
    end
end

-- Placeholder for handling a ROTATE item request (server-side)
function PlacementManager:HandleRotateItemRequest(player, itemInstance, cost, originalItemId, rotationParameters)
    print(string.format("PlacementManager:HandleRotateItemRequest called for item: %s by player %s (cost: %s, originalId: %s)", itemInstance.Name, player.Name, tostring(cost), originalItemId))
    if rotationParameters then print("  Rotation Parameters:", rotationParameters) end
    
    if not itemInstance or not itemInstance.Parent then
        return {success = false, message = "Item to rotate not found or invalid."}
    end

    if not rotationParameters or type(rotationParameters) ~= "table" or not rotationParameters.axis or not rotationParameters.degrees then
        return {success = false, message = "Rotation parameters (axis, degrees) missing or invalid."}
    end

    local axis = string.lower(tostring(rotationParameters.axis))
    local degrees = tonumber(rotationParameters.degrees)

    if not degrees or (axis ~= "x" and axis ~= "y" and axis ~= "z") then
        return {success = false, message = "Invalid rotation axis or degrees."}
    end

    local currentCFrame
    if itemInstance:IsA("Model") and itemInstance.PrimaryPart then
        currentCFrame = itemInstance.PrimaryPart.CFrame
    elseif itemInstance:IsA("BasePart") then
        currentCFrame = itemInstance.CFrame
    else
        return {success = false, message = "Item is not a Model or BasePart."}
    end
    
    local rotationCFrame
    if axis == "x" then
        rotationCFrame = CFrame.Angles(math.rad(degrees), 0, 0)
    elseif axis == "y" then
        rotationCFrame = CFrame.Angles(0, math.rad(degrees), 0)
    else -- axis == "z"
        rotationCFrame = CFrame.Angles(0, 0, math.rad(degrees))
    end
    
    local newCFrame = currentCFrame * rotationCFrame

    if itemInstance:IsA("Model") and itemInstance.PrimaryPart then
        itemInstance:SetPrimaryPartCFrame(newCFrame)
    elseif itemInstance:IsA("BasePart") then
        itemInstance.CFrame = newCFrame
    end

    itemInstance:SetAttribute("lastModified", os.time())
    self:SaveWorldData()
    
    return {success = true, message = string.format("Item %s rotated around %s-axis by %s degrees for %s %s.", originalItemId, axis:upper(), degrees, cost, self.Constants.CURRENCY.INGAME or "coins")}
end

return PlacementManager

