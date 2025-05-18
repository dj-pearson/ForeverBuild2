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
local PLACED_ITEMS_FOLDER_NAME = "PlacedItems"
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
        self.worldFolder = Workspace:FindFirstChild(PLACED_ITEMS_FOLDER_NAME)
        if not self.worldFolder then
            self.worldFolder = Instance.new("Folder")
            self.worldFolder.Name = PLACED_ITEMS_FOLDER_NAME
            self.worldFolder.Parent = Workspace
        end
        
        -- Keep track of placed items by player
        self.placedItemsByPlayer = {}
    else
        -- Client-side properties
        self.previewItem = nil
        self.isPlacing = false
        self.selectedItem = nil
    end
    
    return self
end

-- Server: Place an item in the world and persist it
function PlacementManager:PlaceItem(player, itemId, position, rotation)
    if not isServer then return false end
    
    local playerData = self:GetPlayerData(player)
    if not playerData or not playerData.inventory then
        warn("PlacementManager: Player data not found for", player.Name)
        return false
    end
    
    -- Check if the player has this item in their inventory
    local hasItem = false
    for _, item in pairs(playerData.inventory) do
        if item.id == itemId or item.name == itemId then
            hasItem = true
            break
        end
    end
    
    if not hasItem then
        warn("PlacementManager: Player", player.Name, "does not have item", itemId)
        return false
    end
    
    -- Get the item template
    local itemData = self:GetItemData(itemId)
    if not itemData then
        warn("PlacementManager: Failed to get item data for", itemId)
        return false
    end
    
    -- Create the item in the world
    local item = self:CreateWorldItem(itemId, position, rotation)
    if not item then
        warn("PlacementManager: Failed to create world item for", itemId)
        return false
    end
    
    -- Set ownership
    item:SetAttribute("owner", player.UserId)
    item:SetAttribute("placed_time", os.time())
    
    -- Add to player's placed items
    if not self.placedItemsByPlayer[player.UserId] then
        self.placedItemsByPlayer[player.UserId] = {}
    end
    table.insert(self.placedItemsByPlayer[player.UserId], {
        id = itemId,
        position = position,
        rotation = rotation,
        instanceId = item.Name
    })
    
    -- Remove from inventory
    local removeSuccess = self:RemoveFromInventory(player, itemId)
    if not removeSuccess then
        warn("PlacementManager: Failed to remove item from inventory for", player.Name, itemId)
        -- Continue anyway, but log it
    end
    
    -- Save world data
    self:SaveWorldData()
    
    -- Notify client of successful placement
    if self.remotes.ItemPlaced then
        self.remotes.ItemPlaced:FireClient(player, itemId, item.Name)
    end
    
    print("PlacementManager: Item", itemId, "placed successfully by", player.Name)
    return true, item
end

-- Server: Remove an item from the player's inventory
function PlacementManager:RemoveFromInventory(player, itemId)
    if not isServer then return false end
    
    local success = false
    local InventoryManager = self.shared.InventoryManager
    
    if InventoryManager then
        success = InventoryManager:RemoveItem(player, itemId, 1)
    else
        -- Fallback to ItemPurchaseHandler
        local ItemPurchaseHandler = self.shared.ItemPurchaseHandler
        if ItemPurchaseHandler then
            success = ItemPurchaseHandler:RemoveFromInventory(player, itemId, 1)
        end
    end
    
    return success
end

-- Server: Get item data from Constants
function PlacementManager:GetItemData(itemId)
    if not self.Constants or not self.Constants.ITEMS then
        warn("PlacementManager: Constants.ITEMS not available")
        return nil
    end
    
    -- Try direct lookup
    if self.Constants.ITEMS[itemId] then
        return self.Constants.ITEMS[itemId]
    end
    
    -- Try case-insensitive lookup
    for key, data in pairs(self.Constants.ITEMS) do
        if key:lower() == itemId:lower() then
            return data
        end
    end
    
    warn("PlacementManager: Item not found in Constants:", itemId)
    return nil
end

-- Server: Create an item in the world
function PlacementManager:CreateWorldItem(itemId, position, rotation)
    if not isServer then return nil end
    
    print("PlacementManager: Creating world item for:", itemId)
    
    -- Look for templates in multiple possible locations
    local template
    
    -- 1. Check in ReplicatedStorage.ItemTemplates
    local itemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if itemTemplates then
        -- Try exact match first
        template = itemTemplates:FindFirstChild(itemId)
        
        if template then
            print("PlacementManager: Found exact template match in ItemTemplates:", itemId)
        end
    end
    
    -- 2. If no match, check ServerStorage.Items if it exists
    if not template then
        local serverItems = game:GetService("ServerStorage"):FindFirstChild("Items")
        if serverItems then
            template = serverItems:FindFirstChild(itemId)
            
            if template then
                print("PlacementManager: Found template in ServerStorage.Items:", itemId)
            end
        end
    end
    
    -- 3. Try suffix match - check if the item is actually a cube
    if not template and not itemId:lower():find("cube") and not itemId:lower():find("_cube") then
        -- Try appending "_Cube" to the itemId
        local cubeId = itemId .. "_Cube"
        
        if itemTemplates then
            template = itemTemplates:FindFirstChild(cubeId)
            if template then
                print("PlacementManager: Found template by appending _Cube:", cubeId)
            end
        end
    end
    
    -- 4. If still no match, try with normalized name
    if not template and itemTemplates then
        local normalizedName = itemId:gsub("_", ""):lower()
        for _, item in ipairs(itemTemplates:GetChildren()) do
            if item.Name:gsub("_", ""):lower() == normalizedName then
                template = item
                print("PlacementManager: Found normalized match for", itemId, "using", item.Name)
                break
            end
        end
    end
    
    -- 5. If still no template, try with partial match
    if not template and itemTemplates then
        local itemIdLower = itemId:lower()
        for _, item in ipairs(itemTemplates:GetChildren()) do
            if item.Name:lower():find(itemIdLower) or itemIdLower:find(item.Name:lower()) then
                template = item
                print("PlacementManager: Found partial match for", itemId, "using", item.Name)
                break
            end
        end
    end
    
    -- 6. Special case for common building materials
    if not template and itemTemplates then
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
                template = itemTemplates:FindFirstChild(case[2])
                if template then
                    print("PlacementManager: Using special case", case[2], "for", itemId)
                    break
                end
            end
        end
    end
    
    -- If no template found, create a basic cube with appropriate appearance
    if not template then
        print("PlacementManager: No template found for", itemId, "- creating basic cube")
        template = Instance.new("Part")
        template.Name = itemId
        template.Size = Vector3.new(2, 2, 2)
        template.Anchored = true
        template.CanCollide = true
        
        -- Set color based on item type
        if itemId:lower():find("water") or itemId:lower():find("blue") then
            template.BrickColor = BrickColor.new("Bright blue")
            template.Transparency = 0.3
            template.Material = Enum.Material.Water
        elseif itemId:lower():find("fire") or itemId:lower():find("lava") then
            template.BrickColor = BrickColor.new("Bright red")
            template.Material = Enum.Material.Neon
        elseif itemId:lower():find("grass") or itemId:lower():find("green") then
            template.BrickColor = BrickColor.new("Bright green")
            template.Material = Enum.Material.Grass
        elseif itemId:lower():find("sand") or itemId:lower():find("yellow") or itemId:lower():find("earth") then
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
            template.Transparency = 0.5
            template.Material = Enum.Material.Glass
        else
            template.BrickColor = BrickColor.new("Medium stone grey")
            template.Material = Enum.Material.Concrete
        end
    end
    
    -- Clone the template
    local item = template:Clone()
    print("PlacementManager: Creating world item from template:", template.Name)
    
    -- Generate a unique ID for this instance
    local instanceId = itemId .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
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
    item:SetAttribute("item_type", itemId)
    item:SetAttribute("placed_at", os.time())
    
    -- Add to world folder
    item.Parent = self.worldFolder
    
    return item
end

-- Server: Get player data from appropriate manager
function PlacementManager:GetPlayerData(player)
    if not isServer then return nil end
    
    local InventoryManager = self.shared.InventoryManager
    if InventoryManager and InventoryManager.GetPlayerData then
        return InventoryManager:GetPlayerData(player)
    end
    
    -- Fallback to ItemPurchaseHandler
    local ItemPurchaseHandler = self.shared.ItemPurchaseHandler
    if ItemPurchaseHandler and ItemPurchaseHandler.GetPlayerData then
        return ItemPurchaseHandler:GetPlayerData(player)
    end
    
    warn("PlacementManager: Could not find a way to get player data")
    return nil
end

-- Server: Save world data to DataStore
function PlacementManager:SaveWorldData()
    if not isServer then return false end
    
    local DataService = self.shared.DataService
    if not DataService then
        warn("PlacementManager: DataService not available for saving world data")
        return false
    end
    
    -- Collect all placed items data
    local worldData = {}
    for playerId, items in pairs(self.placedItemsByPlayer) do
        for _, item in ipairs(items) do
            table.insert(worldData, {
                id = item.id,
                position = {
                    x = item.position.X,
                    y = item.position.Y, 
                    z = item.position.Z
                },
                rotation = {
                    x = item.rotation.X,
                    y = item.rotation.Y,
                    z = item.rotation.Z
                },
                owner = playerId,
                instanceId = item.instanceId
            })
        end
    end
    
    -- Save using DataService
    local success = DataService:SaveData("WorldData", worldData)
    if success then
        print("PlacementManager: World data saved successfully")
    else
        warn("PlacementManager: Failed to save world data")
    end
    
    return success
end

-- Server: Load world data from DataStore
function PlacementManager:LoadWorldData()
    if not isServer then return false end
    
    local DataService = self.shared.DataService
    if not DataService then
        warn("PlacementManager: DataService not available for loading world data")
        return false
    end
    
    -- Load world data
    local worldData = DataService:LoadData("WorldData")
    if not worldData then
        print("PlacementManager: No world data available to load")
        return false
    end
    
    -- Clear existing world
    self.worldFolder:ClearAllChildren()
    self.placedItemsByPlayer = {}
    
    -- Recreate all items
    for _, itemData in ipairs(worldData) do
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
        
        local item = self:CreateWorldItem(itemData.id, position, rotation)
        if item then
            item:SetAttribute("owner", itemData.owner)
            item.Name = itemData.instanceId or (itemData.id .. "_" .. os.time() .. "_" .. math.random(1000, 9999))
            
            -- Track in placedItemsByPlayer
            if not self.placedItemsByPlayer[itemData.owner] then
                self.placedItemsByPlayer[itemData.owner] = {}
            end
            
            table.insert(self.placedItemsByPlayer[itemData.owner], {
                id = itemData.id,
                position = position,
                rotation = rotation,
                instanceId = item.Name
            })
        end
    end
    
    print("PlacementManager: World data loaded successfully")
    return true
end

-- Server: Recall an item from the world back to inventory
function PlacementManager:RecallItem(player, instanceId)
    if not isServer then return false end
    
    -- Find the item in the world
    local item = self.worldFolder:FindFirstChild(instanceId)
    if not item then
        warn("PlacementManager: Item not found for recall:", instanceId)
        return false
    end
    
    -- Check ownership
    local ownerId = item:GetAttribute("owner")
    if ownerId ~= player.UserId then
        warn("PlacementManager: Player", player.Name, "does not own item", instanceId)
        return false
    end
    
    -- Get the item type
    local itemType = item:GetAttribute("item_type")
    if not itemType then
        warn("PlacementManager: Item", instanceId, "has no item_type attribute")
        return false
    end
    
    -- Add to player's inventory
    local success = self:AddToInventory(player, itemType)
    if not success then
        warn("PlacementManager: Failed to add item", itemType, "to inventory for", player.Name)
        return false
    end
    
    -- Remove item from world
    item:Destroy()
    
    -- Remove from placedItemsByPlayer
    if self.placedItemsByPlayer[player.UserId] then
        for i, placedItem in ipairs(self.placedItemsByPlayer[player.UserId]) do
            if placedItem.instanceId == instanceId then
                table.remove(self.placedItemsByPlayer[player.UserId], i)
                break
            end
        end
    end
    
    -- Save world data
    self:SaveWorldData()
    
    -- Notify client
    if self.remotes.ItemRecalled then
        self.remotes.ItemRecalled:FireClient(player, itemType, instanceId)
    end
    
    print("PlacementManager: Item", instanceId, "recalled successfully by", player.Name)
    return true
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
        elseif itemId:lower():find("sand") or itemId:lower():find("yellow") or itemId:lower():find("earth") then
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
    end
    
    -- Clear any existing equipped item
    for _, child in ipairs(equipSlot:GetChildren()) do
        child:Destroy()
    end
    
    -- Find template
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    local template
    
    if templates then
        -- Try exact match first
        template = templates:FindFirstChild(itemId)
        
        -- If no template found, try with partial match
        if not template then
            local itemIdLower = itemId:lower()
            for _, item in ipairs(templates:GetChildren()) do
                if item.Name:lower():find(itemIdLower) or itemIdLower:find(item.Name:lower()) then
                    template = item
                    print("PlacementManager: Found partial match for", itemId, "using", item.Name)
                    break
                end
            end
        end
    end
    
    -- Create a basic item if no template
    if not template then
        print("PlacementManager: No template found for", itemId, "- creating basic item")
        template = Instance.new("Part")
        template.Size = Vector3.new(1, 1, 1)
        template.CanCollide = false
        
        -- Set color based on item type
        if itemId:lower():find("water") then
            template.BrickColor = BrickColor.new("Bright blue")
        elseif itemId:lower():find("fire") then
            template.BrickColor = BrickColor.new("Bright red")
        elseif itemId:lower():find("grass") then
            template.BrickColor = BrickColor.new("Bright green")
        elseif itemId:lower():find("sand") or itemId:lower():find("earth") then
            template.BrickColor = BrickColor.new("Brick yellow")
        elseif itemId:lower():find("wood") then
            template.BrickColor = BrickColor.new("Brown")
        elseif itemId:lower():find("brick") then
            template.BrickColor = BrickColor.new("Brick red")
        else
            template.BrickColor = BrickColor.new("Medium stone grey")
        end
    else
        template = template:Clone()
    end
    
    -- Setup item for hand
    if template:IsA("Model") then
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
            end
            
            -- Weld to hand
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = rightHand
            weld.Part1 = template.PrimaryPart
            weld.Parent = template.PrimaryPart
            
            template:SetPrimaryPartCFrame(equipSlot.WorldCFrame)
        end
    elseif template:IsA("BasePart") then
        -- Scale down if needed
        if template.Size.Magnitude > 2 then
            local scale = 2 / template.Size.Magnitude
            template.Size = template.Size * scale
        end
        
        -- Weld to hand
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = rightHand
        weld.Part1 = template
        weld.Parent = template
        
        template.CFrame = equipSlot.WorldCFrame
    end
    
    template.Parent = equipSlot
    
    -- Make sure the Humanoid can still move
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Ensure the humanoid is not stuck in a certain animation state
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        -- Set a reasonable walk speed
        humanoid.WalkSpeed = 16
    end
    
    return template
end

-- Client: Recall item from inventory to hand
function PlacementManager:RecallItemFromInventory(itemId)
    if isServer then return end
    
    print("PlacementManager: Recalling item", itemId, "from inventory")
    
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
        end
    end
    
    -- Show item in hand
    local itemInHand = self:ShowItemInHand(itemId)
    if not itemInHand then
        warn("PlacementManager: Failed to show item in hand")
        return
    end
    
    -- Start placement mode
    self:StartPlacing(itemId)
    
    -- Connect to Humanoid state change to ensure movement
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local stateChangeConnection
            stateChangeConnection = humanoid.StateChanged:Connect(function(oldState, newState)
                if newState == Enum.HumanoidStateType.Physics then
                    -- If physics state is applied (which stops movement), change back to GettingUp
                    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
                
                -- Disconnect after a few seconds to avoid constantly overriding states
                task.delay(5, function()
                    if stateChangeConnection then
                        stateChangeConnection:Disconnect()
                        stateChangeConnection = nil
                    end
                end)
            end)
        end
    end
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

-- Initialize the placement system
function PlacementManager:Initialize()
    print("PlacementManager: Initializing...")
    
    -- Setup remote events
    self:SetupRemoteEvents()
    
    -- Load world data on server
    if isServer then
        task.spawn(function()
            wait(1) -- Wait for game to fully load
            self:LoadWorldData()
        end)
    end
    
    print("PlacementManager: Initialization complete")
    return self
end

return PlacementManager
