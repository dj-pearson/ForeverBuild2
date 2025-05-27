-- PlacementManager_Core.luau
-- Manages the placement, recall, and persistence of items in the world

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Import utility functions
local PlacementUtils = require(script.Parent.Placement_Utils)

-- Import SimpleRotationUI for cross-platform rotation
local SimpleRotationUI = require(script.Parent.SimpleRotationUI)
-- Import PlacementControlsUI for clear placement instructions
local PlacementControlsUI = require(script.Parent.PlacementControlsUI)

-- Import SecurityValidator for enterprise-level security
local SecurityValidator
local securityValidator
local success, result = pcall(function()
    return require(ReplicatedStorage.src.shared.security.SecurityValidator)
end)
if success then
    SecurityValidator = result
    securityValidator = SecurityValidator.new()
    print("PlacementManager_Core: SecurityValidator loaded successfully")
else
    warn("PlacementManager_Core: Failed to load SecurityValidator:", result)
end

-- Import ExploitDetector for anti-exploit protection
local ExploitDetector
local exploitDetector
if RunService:IsServer() then
    local exploitSuccess, exploitResult = pcall(function()
        return require(ReplicatedStorage.src.shared.security.ExploitDetector)
    end)
    if exploitSuccess then
        ExploitDetector = exploitResult
        exploitDetector = ExploitDetector.new()
        exploitDetector:Initialize()
        print("PlacementManager_Core: ExploitDetector loaded successfully")
    else
        warn("PlacementManager_Core: Failed to load ExploitDetector:", exploitResult)
    end
end

-- Attempt to require RotationControlsUI (Client-Only)
local RotationControlsUI
if RunService:IsClient() then
    local successRotationUI, resultRotationUI = pcall(function()
        return require(script.Parent.Parent.ui.RotationControlsUI)
    end)
    if successRotationUI then
        RotationControlsUI = resultRotationUI
        print("PlacementManager_Core: Successfully required RotationControlsUI")
    else
        warn("PlacementManager_Core: Failed to require RotationControlsUI:", resultRotationUI)
    end
end

-- Configuration
local PLACED_ITEMS_FOLDER_NAME = "World_Items"
local _MAX_PLACEMENT_DISTANCE = 20

-- Attempt to require UniqueItemIdAssigner
local UniqueItemIdAssigner
if RunService:IsServer() then
    local success, result = pcall(function()
        return require(game:GetService("ServerScriptService").server.UniqueItemIdAssigner)
    end)
    if success then
        UniqueItemIdAssigner = result
        print("PlacementManager_Core: Successfully required UniqueItemIdAssigner")
    else
        warn("PlacementManager_Core: Failed to require UniqueItemIdAssigner:", result)
    end
end

local PlacementManager_Core = {}
PlacementManager_Core.__index = PlacementManager_Core

function PlacementManager_Core.new(sharedModule)
    print("--- PLACEMENT MANAGER CORE .new() CALLED ---")
    local self = setmetatable({}, PlacementManager_Core)
    
    self.shared = sharedModule
    self.Constants = sharedModule.Constants
    
    if not self.Constants then self.Constants = {} end
    if not self.Constants.CURRENCY then self.Constants.CURRENCY = {} end
    if not self.Constants.CURRENCY.INGAME then self.Constants.CURRENCY.INGAME = "coins" end
    
    self.remotes = {}
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
    
    if RunService:IsClient() then
        -- CLIENT-ONLY INITIALIZATION
        self.previewItem = nil
        self.isPlacing = false
        self.selectedItem = nil
        self.isMovingExistingItem = false
        self.itemBeingMovedInstance = nil
        self.currentMoveCost = 0
        self.isTransitioningFromRotation = false
        self.currentAngleY = 0
        self.lastUpdatePlacementTime = 0
        self.updatePlacementInterval = 0.05
        self.lastSnappedPosition = nil
        self.positionChangeTolerance = 0.1
        self.isRotatingItem = false
        self.itemToRotate = nil
        self.rotationCost = 0
        self.currentRotationInput = CFrame.new()
        self.basePreviewCFrame = CFrame.new()
        self.rotationSensitivityMouse = 0.01
        self.rotationSensitivityKeys = math.rad(5)
        self.rotationRenderSteppedConnection = nil
        self.rotationMouseConfirmConnection = nil
        self.rotationKeyboardConfirmConnection = nil
        self.rotationCancelConnection = nil
        self.rotationInputChangedConnection = nil
        self.rotationInputBeganConnection = nil
        if RotationControlsUI then
            self.rotationControlsUI = RotationControlsUI.new()
            if not self.rotationControlsUI then warn("PlacementManager_Core: Failed to instantiate RotationControlsUI") end
        end
        self.simpleRotationUI = SimpleRotationUI.new()
        self.placementControlsUI = PlacementControlsUI.new()
        print("--- PLACEMENT MANAGER CORE CLIENT CONSTRUCTOR REACHED ---")
        self:CacheRemoteEvents()
    else
        -- SERVER-ONLY INITIALIZATION
        local success_uid, result_uid = pcall(function() -- Renamed variables to avoid conflict
            return require(game:GetService("ServerScriptService").server.UniqueItemIdAssigner)
        end)
        if success_uid then
            self.UniqueItemIdAssigner = result_uid
            UniqueItemIdAssigner = result_uid 
        else
            warn("PlacementManager_Core.new: Failed to require UniqueItemIdAssigner:", result_uid)
        end

        self.worldFolder = Workspace:FindFirstChild(PLACED_ITEMS_FOLDER_NAME)
        if not self.worldFolder then
            self.worldFolder = Instance.new("Folder")
            self.worldFolder.Name = PLACED_ITEMS_FOLDER_NAME
            self.worldFolder.Parent = Workspace
        end
        self.staticFolder = self.worldFolder:FindFirstChild("Static")
        if not self.staticFolder then
            self.staticFolder = Instance.new("Folder")
            self.staticFolder.Name = "Static"
            self.staticFolder.Parent = self.worldFolder
        end
        self.placedFolder = self.worldFolder:FindFirstChild("Placed")
        if not self.placedFolder then
            self.placedFolder = Instance.new("Folder")
            self.placedFolder.Name = "Placed"
            self.placedFolder.Parent = self.worldFolder
        end
        self.legacyPlacedFolder = Workspace:FindFirstChild("PlacedItems")
        
        self.placedItemsByPlayer = {}
        self.ItemsByUniqueId = {}
        self.ItemsByInstanceId = {}
        self.ItemsByOwner = {}
        self.worldFolder:SetAttribute("PlacementManagerTrackingEnabled", true)
        self.worldFolder:SetAttribute("PlacementManagerInitTime", os.time())
    end
    return self
end

function PlacementManager_Core:Initialize()
    if RunService:IsClient() then return false end
    print("PlacementManager_Core: Initialize called")
    self:SetupRemoteEvents()
    local success_pe, err_pe = pcall(function() self:ConnectPlayerEvents() end) -- Renamed variables
    if not success_pe then warn("[PlacementManager_Core] Failed to connect player events: " .. tostring(err_pe)) end
    task.spawn(function() task.wait(2); self:LoadWorldData() end)
    print("PlacementManager_Core: Initialization completed")
    return true
end

function PlacementManager_Core:ConnectPlayerEvents()
    print("[PlacementManager_Core] ConnectPlayerEvents method called.")
end

-- DELEGATE TO PlacementUtils for these functions
function PlacementManager_Core:GetItemTemplate(itemId)
    return PlacementUtils.GetItemTemplate(self, itemId)
end

function PlacementManager_Core:FindItemByInstanceId(instanceId)
    return PlacementUtils.FindItemByInstanceId(self, instanceId)
end

function PlacementManager_Core:GetPlayerData(player)
    return PlacementUtils.GetPlayerData(self, player)
end

function PlacementManager_Core:RemoveFromInventory(player, itemId, quantity)
    return PlacementUtils.RemoveFromInventory(self, player, itemId, quantity)
end

function PlacementManager_Core:GetItemData(itemId)
    return PlacementUtils.GetItemData(self, itemId)
end

-- Server: Place an item in the world and persist it
function PlacementManager_Core:PlaceItem(player, itemId, position, normal, rotationData, additionalAttributes)
    if RunService:IsClient() then return false end
    print("PlacementManager_Core: PlaceItem called by", player.Name, "for item", itemId)
    
    -- 🛡️ EXPLOIT DETECTION - Track placement action for anti-exploit monitoring
    if exploitDetector then
        exploitDetector:RecordAction(player, "PLACE_ITEM", {
            itemId = itemId,
            position = position,
            timestamp = tick()
        })
    end
    
    -- 🔒 SECURITY VALIDATION - Enterprise-level input validation
    if securityValidator then
        -- Validate itemId as string
        local itemValidation = securityValidator:ValidateString(itemId, "ItemId", {maxLength = 50})
        if not itemValidation.success then
            warn("🚨 SECURITY: Invalid itemId from", player.Name, ":", itemValidation.error)
            return false, "Invalid item identifier"
        end
        
        -- Validate position as Vector3
        local positionValidation = securityValidator:ValidatePosition(position, player)
        if not positionValidation.success then
            warn("🚨 SECURITY: Invalid position from", player.Name, ":", positionValidation.error)
            -- Record potential teleportation exploit
            if exploitDetector then
                exploitDetector:RecordViolation(player, "INVALID_INPUT", {
                    reason = "Invalid placement position",
                    position = position,
                    error = positionValidation.error
                })
            end
            return false, "Invalid placement position"
        end
        position = positionValidation.data.position
        
        -- Validate rotation data if provided
        if rotationData then
            local rotationValidation = securityValidator:ValidateRotation(rotationData)
            if not rotationValidation.success then
                warn("🚨 SECURITY: Invalid rotation from", player.Name, ":", rotationValidation.error)
                return false, "Invalid rotation data"
            end
            rotationData = rotationValidation.data.rotation
        end
        
        -- Validate additional attributes if provided
        if additionalAttributes then
            local attributeValidation = securityValidator:ValidateTable(additionalAttributes, "AdditionalAttributes", {maxDepth = 3})
            if not attributeValidation.success then
                warn("🚨 SECURITY: Invalid attributes from", player.Name, ":", attributeValidation.error)
                return false, "Invalid item attributes"
            end
            additionalAttributes = attributeValidation.data.table
        end
        
        print("✅ SECURITY: Placement validation passed for", player.Name, "placing", itemId)
    else
        warn("⚠️ SECURITY: SecurityValidator not available for placement validation")
    end
    
    local normalizedItemId = itemId:gsub(" ", "_")
    local playerData = self:GetPlayerData(player)
    if not playerData then warn("PlacementManager_Core: No player data for", player.Name); return false end
    
    local hasItem = false
    if playerData.inventory then
        for _, item_data in ipairs(playerData.inventory) do -- Renamed item to item_data
            if (item_data.id and (item_data.id == itemId or item_data.id == normalizedItemId)) or 
               (item_data.name and (item_data.name == itemId or item_data.name == normalizedItemId)) then
                hasItem = true; break
            end
        end
    end
    if not hasItem then warn("PlacementManager_Core: Player", player.Name, "not have", itemId); return false end
    
    local template = self:GetItemTemplate(normalizedItemId)
    local placedItem
    if template then
        placedItem = template:Clone()
    else
        placedItem = Instance.new("Part")
        placedItem.Name = normalizedItemId .. "_" .. player.UserId .. "_" .. os.time()
        placedItem.Size = Vector3.new(2, 2, 2)
        placedItem.Anchored = true; placedItem.CanCollide = true
        placedItem.BrickColor = BrickColor.new("Medium stone grey"); placedItem.Material = Enum.Material.Concrete
    end
    
    local instanceId = string.format("%s_%d_%d", normalizedItemId, player and player.UserId or 0, os.time())
    placedItem.Name = instanceId
    placedItem:SetAttribute("itemId", itemId)
    placedItem:SetAttribute("instanceId", instanceId)
    placedItem:SetAttribute("owner", player.UserId)
    placedItem:SetAttribute("placedTime", os.time())
    placedItem:SetAttribute("persistent", true)
    placedItem:SetAttribute("rotationX", rotationData.X or 0)
    placedItem:SetAttribute("rotationY", rotationData.Y or 0)
    placedItem:SetAttribute("rotationZ", rotationData.Z or 0)
    
    local itemDef = self.Constants and self.Constants.ITEMS and self.Constants.ITEMS[normalizedItemId]
    if itemDef and itemDef.priceIngame then
        placedItem:SetAttribute("priceIngame", itemDef.priceIngame)
    else
        placedItem:SetAttribute("priceIngame", 0)
    end

    if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then
        UniqueItemIdAssigner.assignIdToNewItem(placedItem)
    end
    
    local rotationCFrame = CFrame.Angles(math.rad(rotationData.X or 0), math.rad(rotationData.Y or 0), math.rad(rotationData.Z or 0))
    if placedItem:IsA("Model") and placedItem.PrimaryPart then
        placedItem:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        for _, part_in_model in pairs(placedItem:GetDescendants()) do if part_in_model:IsA("BasePart") then part_in_model.Anchored = true; part_in_model.CanCollide = true end end -- Renamed part
    elseif placedItem:IsA("BasePart") then
        placedItem.CFrame = CFrame.new(position) * rotationCFrame
        placedItem.Anchored = true; placedItem.CanCollide = true
    end
    
    placedItem.Parent = self.placedFolder
    if not self.placedItemsByPlayer[player.UserId] then self.placedItemsByPlayer[player.UserId] = {} end
    table.insert(self.placedItemsByPlayer[player.UserId], instanceId)
    self:RemoveFromInventory(player, normalizedItemId, 1)
    
    if self.remotes.ItemPlaced then self.remotes.ItemPlaced:FireClient(player, normalizedItemId, instanceId) end
    if self.progressionManager and self.progressionManager.OnItemPlaced then self.progressionManager:OnItemPlaced(player, normalizedItemId) end
    
    task.spawn(function() self:SaveWorldData() end)
    return true, placedItem
end

-- Server: Create an item in the world (Simplified version of the original for brevity, full logic will be moved later)
function PlacementManager_Core:CreateWorldItem(itemId, position, rotation)
    if RunService:IsClient() then return nil end
    local normalizedItemId = itemId:gsub(" ", "_")
    local template = self:GetItemTemplate(normalizedItemId)
    local world_item -- Renamed item to world_item
    if template then world_item = template:Clone() 
    else 
        world_item = Instance.new("Part"); world_item.Name = normalizedItemId
        world_item.Size = Vector3.new(2,2,2); world_item.Anchored = true; world_item.CanCollide = true
    end 

    local instanceId = normalizedItemId .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    world_item.Name = instanceId
    local itemHeight = 2 
    if world_item:IsA("BasePart") then itemHeight = world_item.Size.Y
    elseif world_item:IsA("Model") and world_item.PrimaryPart then itemHeight = world_item.PrimaryPart.Size.Y end
    local adjustedPosition = Vector3.new(position.X, position.Y + (itemHeight/2), position.Z)
    if world_item:IsA("Model") and world_item.PrimaryPart then world_item:SetPrimaryPartCFrame(CFrame.new(adjustedPosition) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z))
    else world_item.CFrame = CFrame.new(adjustedPosition) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z) end
    
    if world_item:IsA("Model") then for _, part_in_model in ipairs(world_item:GetDescendants()) do if part_in_model:IsA("BasePart") then part_in_model.Anchored = true; part_in_model.CanCollide = true end end -- Renamed part
    elseif world_item:IsA("BasePart") then world_item.Anchored = true; world_item.CanCollide = true end
    
    world_item:SetAttribute("item_type", normalizedItemId); world_item:SetAttribute("placed_at", os.time())
    if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then UniqueItemIdAssigner.assignIdToNewItem(world_item) end
    world_item.Parent = self.placedFolder
    return world_item
end

-- Server: Save world data to DataStore
function PlacementManager_Core:SaveWorldData()
    if RunService:IsClient() then return false end
    local DataService = self.shared and self.shared.DataService
    if not DataService then warn("PlacementManager_Core: DataService not available for saving"); return false end
    
    local worldData = {}
    for playerId, items_list in pairs(self.placedItemsByPlayer or {}) do -- Renamed items to items_list
        for _, instanceId in ipairs(items_list) do
            local item_instance = self:FindItemByInstanceId(instanceId) -- Renamed item to item_instance
            if item_instance then
                table.insert(worldData, {
                    instanceId = instanceId, itemId = item_instance:GetAttribute("itemId"), owner = item_instance:GetAttribute("owner") or tonumber(playerId),
                    position = if item_instance:IsA("Model") and item_instance.PrimaryPart then {X=item_instance.PrimaryPart.Position.X, Y=item_instance.PrimaryPart.Position.Y, Z=item_instance.PrimaryPart.Position.Z} else {X=item_instance.Position.X, Y=item_instance.Position.Y, Z=item_instance.Position.Z},
                    rotation = if item_instance:IsA("Model") and item_instance.PrimaryPart then {X=item_instance.PrimaryPart.Orientation.X, Y=item_instance.PrimaryPart.Orientation.Y, Z=item_instance.PrimaryPart.Orientation.Z} else {X=item_instance.Orientation.X, Y=item_instance.Orientation.Y, Z=item_instance.Orientation.Z},
                    placedTime = item_instance:GetAttribute("placedTime") or os.time(), priceIngame = item_instance:GetAttribute("priceIngame") or 0
                })
            end
        end
    end
    if self.placedFolder then
        for _, item_in_folder in ipairs(self.placedFolder:GetChildren()) do -- Renamed item to item_in_folder
            local instanceId = item_in_folder:GetAttribute("instanceId")
            if instanceId then
                local found = false; for _, existingItem in ipairs(worldData) do if existingItem.instanceId == instanceId then found = true; break end end
                if not found then
                    table.insert(worldData, {
                        instanceId = instanceId, itemId = item_in_folder:GetAttribute("itemId"), owner = item_in_folder:GetAttribute("owner"),
                        position = if item_in_folder:IsA("Model") and item_in_folder.PrimaryPart then {X=item_in_folder.PrimaryPart.Position.X, Y=item_in_folder.PrimaryPart.Position.Y, Z=item_in_folder.PrimaryPart.Position.Z} else {X=item_in_folder.Position.X, Y=item_in_folder.Position.Y, Z=item_in_folder.Position.Z},
                        rotation = if item_in_folder:IsA("Model") and item_in_folder.PrimaryPart then {X=item_in_folder.PrimaryPart.Orientation.X, Y=item_in_folder.PrimaryPart.Orientation.Y, Z=item_in_folder.PrimaryPart.Orientation.Z} else {X=item_in_folder.Orientation.X, Y=item_in_folder.Orientation.Y, Z=item_in_folder.Orientation.Z},
                        placedTime = item_in_folder:GetAttribute("placedTime") or os.time(), priceIngame = item_in_folder:GetAttribute("priceIngame") or 0
                    })
                end
            end
        end
    end
    local success_save = DataService:SaveData("WorldPlacedItems", worldData) -- Renamed success
    if success_save then print("PlacementManager_Core: World data saved") else warn("PlacementManager_Core: Failed to save world data") end
    return success_save
end

-- Server: Load world data from DataStore (Simplified, full logic to be moved)
function PlacementManager_Core:LoadWorldData()
    if RunService:IsClient() then return false end
    local DataService = self.shared and self.shared.DataService
    if not DataService then warn("PlacementManager_Core: DataService not available for loading"); return false end
    
    local worldData = DataService:GetData("WorldPlacedItems")
    if not worldData or type(worldData) ~= "table" or #worldData == 0 then print("PlacementManager_Core: No world data"); return false end
    
    local itemsPlaced = 0
    for _, itemData in ipairs(worldData) do
        if itemData.itemId and itemData.position then
            local template = self:GetItemTemplate(itemData.itemId)
            if template then
                local placedItem = template:Clone()
                placedItem.Name = string.format("%s_%s_%s", itemData.itemId, itemData.owner or "unknown", itemData.placedTime or os.time())
                local itemDef = self.Constants and self.Constants.ITEMS and self.Constants.ITEMS[itemData.itemId]
                local loadedItemId = itemData.itemId
                if not loadedItemId and itemData.instanceId then local basePart = itemData.instanceId:match("^(.*)_([^_]+)_[^_]+$"); if basePart then loadedItemId = basePart end end

                placedItem:SetAttribute("instanceId", itemData.instanceId)
                placedItem:SetAttribute("itemId", loadedItemId)
                placedItem:SetAttribute("owner", itemData.owner)
                placedItem:SetAttribute("placedTime", itemData.placedTime or os.time())
                placedItem:SetAttribute("persistent", true)
                if itemDef then
                    placedItem:SetAttribute("priceIngame", itemDef.priceIngame); placedItem:SetAttribute("tier", itemDef.tier)
                    placedItem:SetAttribute("description", itemDef.description); placedItem:SetAttribute("name", itemDef.name)
                else
                    placedItem:SetAttribute("priceIngame", itemData.priceIngame or 0)
                end
                if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then
                    if placedItem:GetAttribute("UniqueItemId") == nil then UniqueItemIdAssigner.assignIdToNewItem(placedItem) end
                end
                local posVec = Vector3.new(itemData.position.X or 0, itemData.position.Y or 0, itemData.position.Z or 0)
                local rotVec = Vector3.new(itemData.rotation.X or 0, itemData.rotation.Y or 0, itemData.rotation.Z or 0)
                
                if placedItem:IsA("Model") and placedItem.PrimaryPart then
                    placedItem:SetPrimaryPartCFrame(CFrame.new(posVec) * CFrame.fromEulerAnglesXYZ(math.rad(rotVec.X), math.rad(rotVec.Y), math.rad(rotVec.Z)))
                    for _, part_in_model in pairs(placedItem:GetDescendants()) do if part_in_model:IsA("BasePart") then part_in_model.Anchored = true; part_in_model.CanCollide = true end end -- Renamed part
                elseif placedItem:IsA("BasePart") then
                    placedItem.CFrame = CFrame.new(posVec) * CFrame.fromEulerAnglesXYZ(math.rad(rotVec.X), math.rad(rotVec.Y), math.rad(rotVec.Z))
                    placedItem.Anchored = true; placedItem.CanCollide = true
                end
                placedItem.Parent = self.placedFolder
                local ownerId = itemData.owner
                if ownerId then
                    if not self.placedItemsByPlayer[ownerId] then self.placedItemsByPlayer[ownerId] = {} end
                    table.insert(self.placedItemsByPlayer[ownerId], itemData.instanceId)
                end
                itemsPlaced = itemsPlaced + 1
            end
        end
    end
    print("PlacementManager_Core: Spawned " .. itemsPlaced .. " world items")
    return true
end

-- Server: Delete an item from the world
function PlacementManager_Core:DeleteItem(player, instanceId)
    if RunService:IsClient() then return false end
    local item_to_delete = self:FindItemByInstanceId(instanceId) -- Renamed item
    if not item_to_delete then warn("PlacementManager_Core:DeleteItem - Item '" .. tostring(instanceId) .. "' not found"); return false end
    local ownerId = item_to_delete:GetAttribute("owner")
    local isAdmin = player:GetAttribute("IsAdmin") or false
    if ownerId and ownerId ~= player.UserId and not isAdmin then warn("PlacementManager_Core:DeleteItem - Player not owner and not admin"); return false end
    
    if self.placedItemsByPlayer and ownerId and self.placedItemsByPlayer[ownerId] then
        local instanceIdAttribute = item_to_delete:GetAttribute("instanceId")
        for i, id_in_list in ipairs(self.placedItemsByPlayer[ownerId]) do
            if id_in_list == instanceIdAttribute then table.remove(self.placedItemsByPlayer[ownerId], i); break end
        end
    end
    if self.ItemsByUniqueId then local uniqueItemId = item_to_delete:GetAttribute("UniqueItemId"); if uniqueItemId then self.ItemsByUniqueId[uniqueItemId] = nil end end
    local itemInstanceId_attr = item_to_delete:GetAttribute("instanceId"); if itemInstanceId_attr and self.ItemsByInstanceId then self.ItemsByInstanceId[itemInstanceId_attr] = nil end -- Renamed itemInstanceId
    
    item_to_delete:Destroy()
    if self.remotes and self.remotes.ItemDeleted then self.remotes.ItemDeleted:FireClient(player, instanceId) end
    task.spawn(function() self:SaveWorldData() end)
    return true
end

-- Server: Update an item's position or rotation
function PlacementManager_Core:UpdateItem(player, instanceId, position, rotation)
    if RunService:IsClient() then return false end
    local item_to_update = self:FindItemByInstanceId(instanceId) -- Renamed item
    if not item_to_update then warn("PlacementManager_Core: Cannot update - item not found:", instanceId); return false end
    local ownerId = item_to_update:GetAttribute("owner")
    if ownerId ~= player.UserId then
        local isAdmin = player:GetAttribute("IsAdmin") or false
        if not isAdmin then warn("PlacementManager_Core: Player does not own item"); return false end
    end
    if position then
        local rotationCFrame
        if typeof(rotation) == "Vector3" then rotationCFrame = CFrame.fromEulerAnglesXYZ(math.rad(rotation.X or 0), math.rad(rotation.Y or 0), math.rad(rotation.Z or 0))
        else rotationCFrame = CFrame.Angles(0, math.rad(rotation or 0), 0) end
        if item_to_update:IsA("Model") and item_to_update.PrimaryPart then item_to_update:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        elseif item_to_update:IsA("BasePart") then item_to_update.CFrame = CFrame.new(position) * rotationCFrame end
        item_to_update:SetAttribute("lastModified", os.time())
        if self.remotes.ItemUpdated then self.remotes.ItemUpdated:FireClient(player, instanceId, position, rotation) end
        task.spawn(function() self:SaveWorldData() end)
        return true
    end
    return false
end

-- Client-side methods will be moved to separate modules later or further refactored.
-- For now, they are kept here but simplified for brevity.

function PlacementManager_Core:StartPlacing(itemId, existingPreviewItem)
    if RunService:IsServer() then return false end
    self:ClearItemFromHand(); self:ResetPlacementState()
    self.isPlacing = true; self.selectedItem = itemId
    local previewItem = self:CreatePreviewItem(itemId)
    if not previewItem then self.isPlacing = false; self.selectedItem = nil; return false end
    self.previewItem = previewItem
    self.currentPlacementRotationX = 0; self.currentPlacementRotationY = 0; self.currentPlacementRotationZ = 0
    
    if self.placementControlsUI then self.placementControlsUI:Show(itemId, function() self:_ShowRotationUI() end, function() end, function() self:ClearItemFromHand() end) end
    
    local movementConnection; movementConnection = RunService.RenderStepped:Connect(function()
        if not self.isPlacing or not self.previewItem then 
            if movementConnection then movementConnection:Disconnect(); movementConnection = nil; end
            if self.placementControlsUI then self.placementControlsUI:Hide() end
            return 
        end
        self:UpdatePlacementPreview()
    end)
    
    local userInputService = game:GetService("UserInputService")
    local inputConnection, scrollConnection, gamepadConnection -- These will store the connections
    inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if self.simpleRotationUI and self.simpleRotationUI:IsActive() then return end
        
        if self.isPlacing and self.previewItem then
            local isShift = userInputService:IsKeyDown(Enum.KeyCode.LeftShift) or userInputService:IsKeyDown(Enum.KeyCode.RightShift)
            local isCtrl = userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if input.KeyCode == Enum.KeyCode.Q then 
                if isCtrl then self:_DirectRotateAxis("Z", -45) elseif isShift then self:_DirectRotateAxis("X", -45) else self:_DirectRotateAxis("Y", -45) end
                return
            elseif input.KeyCode == Enum.KeyCode.E then 
                if isCtrl then self:_DirectRotateAxis("Z", 45) elseif isShift then self:_DirectRotateAxis("X", 45) else self:_DirectRotateAxis("Y", 45) end
                return
            elseif input.KeyCode == Enum.KeyCode.Space then 
                self:_ShowRotationUI()
                return 
            end
        end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if self.isPlacing and self.previewItem then
                local pos, orient; 
                if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then 
                    pos = self.previewItem.PrimaryPart.Position; orient = self.previewItem.PrimaryPart.Orientation 
                else 
                    pos = self.previewItem.Position; orient = self.previewItem.Orientation 
                end
                local normal = Vector3.new(0,1,0)
                local rotData = {X = self.currentPlacementRotationX or 0, Y = self.currentPlacementRotationY or self.currentPlacementRotation or orient.Y or 0, Z = self.currentPlacementRotationZ or 0}
                if self.remotes and self.remotes.RequestPlaceItem then self.remotes.RequestPlaceItem:FireServer(self.selectedItem, pos, normal, rotData) end
                self:ClearItemFromHand(); 
                if inputConnection then inputConnection:Disconnect(); inputConnection=nil; end
                if scrollConnection then scrollConnection:Disconnect(); scrollConnection=nil; end
                if gamepadConnection then gamepadConnection:Disconnect(); gamepadConnection=nil; end
                if movementConnection then movementConnection:Disconnect(); movementConnection=nil; end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            self:ClearItemFromHand(); 
            if self.placementControlsUI then self.placementControlsUI:Hide() end; 
            if inputConnection then inputConnection:Disconnect(); inputConnection=nil; end
            if scrollConnection then scrollConnection:Disconnect(); scrollConnection=nil; end
            if gamepadConnection then gamepadConnection:Disconnect(); gamepadConnection=nil; end
            if movementConnection then movementConnection:Disconnect(); movementConnection=nil; end
        end
    end)
    return true
end

function PlacementManager_Core:RotatePlacedItem(placedItem)
    if RunService:IsServer() then return false end
    if not placedItem then return false end
    local instanceId = placedItem:GetAttribute("instanceId") or placedItem.Name
    local originalRot = 0
    if placedItem:IsA("Model") and placedItem.PrimaryPart then 
        local _,y,_ = placedItem.PrimaryPart.CFrame:ToEulerAnglesXYZ(); originalRot = math.deg(y) 
    elseif placedItem:IsA("BasePart") then 
        local _,y,_ = placedItem.CFrame:ToEulerAnglesXYZ(); originalRot = math.deg(y) 
    end
    if self.simpleRotationUI then 
        self.simpleRotationUI:Show(placedItem, 
            function(item_arg, rot) self:_ApplyRotationToItem(item_arg, rot) end, 
            function(item_arg, finalRot) if self.remotes and self.remotes.RequestRotateItem then self.remotes.RequestRotateItem:FireServer(instanceId, finalRot) end end, 
            function(item_arg) if item_arg then self:_ApplyRotationToItem(item_arg, originalRot) end end)
        return true 
    end
    return false
end

function PlacementManager_Core:CreatePreviewItem(itemId)
    if RunService:IsServer() then return nil end
    local normalizedItemId = itemId:gsub(" ", "_")
    local template = self:GetItemTemplate(normalizedItemId); if not template then return nil end
    local previewItem = template:Clone(); previewItem.Name = "Preview_" .. normalizedItemId
    if previewItem:IsA("Model") then 
        for _,p_part in ipairs(previewItem:GetDescendants()) do -- Renamed p to p_part
            if p_part:IsA("BasePart") then p_part.Transparency=math.min(0.8,p_part.Transparency+0.5); p_part.CanCollide=false; p_part.Anchored=true; p_part:SetAttribute("is_preview",true) end
        end
    elseif previewItem:IsA("BasePart") then 
        previewItem.Transparency=math.min(0.8,previewItem.Transparency+0.5); previewItem.CanCollide=false; previewItem.Anchored=true; previewItem:SetAttribute("is_preview",true) 
    end
    local hl = Instance.new("Highlight"); hl.FillTransparency=0.5; hl.OutlineTransparency=0; hl.FillColor=Color3.fromRGB(0,255,0); hl.OutlineColor=Color3.fromRGB(0,255,0); hl.Parent=previewItem
    previewItem.Parent = Workspace
    local plr = Players.LocalPlayer; 
    if plr and plr.Character then 
        local cam=Workspace.CurrentCamera; local mouse=plr:GetMouse(); local ray=cam:ViewportPointToRay(mouse.X,mouse.Y); 
        local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={previewItem,plr.Character}; 
        local res=Workspace:Raycast(ray.Origin,ray.Direction*1000,params)
        if res then 
            local initPos=res.Position+res.Normal*2; 
            if previewItem:IsA("Model") and previewItem.PrimaryPart then previewItem:SetPrimaryPartCFrame(CFrame.new(initPos)) 
            elseif previewItem:IsA("BasePart") then previewItem.CFrame=CFrame.new(initPos) 
            end
        else 
            local hrp=plr.Character:FindFirstChild("HumanoidRootPart"); 
            if hrp then 
                local fbPos=hrp.Position+hrp.CFrame.LookVector*10; 
                if previewItem:IsA("Model") and previewItem.PrimaryPart then previewItem:SetPrimaryPartCFrame(CFrame.new(fbPos)) 
                elseif previewItem:IsA("BasePart") then previewItem.CFrame=CFrame.new(fbPos) 
                end 
            end 
        end
    end
    return previewItem
end

function PlacementManager_Core:UpdatePlacementPreview() -- Simplified
    if RunService:IsServer() or not self.previewItem or not (self.isPlacing or self.isMovingExistingItem) then return end
    local currentTime = tick(); if currentTime - self.lastUpdatePlacementTime < self.updatePlacementInterval then return end
    local player = Players.LocalPlayer; if not player or not player.Character then return end
    local camera = Workspace.CurrentCamera; if not camera then return end; local mouse = player:GetMouse()
    local viewportMouseRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new(); raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterInstances = {self.previewItem}; if player.Character then table.insert(filterInstances, player.Character) end
    if self.itemBeingMovedInstance and self.isMovingExistingItem then table.insert(filterInstances, self.itemBeingMovedInstance) end
    raycastParams.FilterDescendantsInstances = filterInstances; raycastParams.IgnoreWater = false
    local raycastResult = Workspace:Raycast(viewportMouseRay.Origin, viewportMouseRay.Direction * 1000, raycastParams)
    local hitPosition = raycastResult and raycastResult.Position or (viewportMouseRay.Origin + viewportMouseRay.Direction * 100)
    if self.lastSnappedPosition and (hitPosition - self.lastSnappedPosition).Magnitude < self.positionChangeTolerance then return end
    self.lastUpdatePlacementTime = currentTime
    self.currentPlacementAngleX = tonumber(self.currentPlacementAngleX) or 0; self.currentPlacementAngleY = tonumber(self.currentPlacementAngleY) or 0; self.currentPlacementAngleZ = tonumber(self.currentPlacementAngleZ) or 0
    local targetNormal = raycastResult and raycastResult.Normal or Vector3.new(0,1,0)
    local newPosition; local newOrientation
    local itemSizeY = 0; if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then itemSizeY = self.previewItem.PrimaryPart.Size.Y elseif self.previewItem:IsA("BasePart") then itemSizeY = self.previewItem.Size.Y end
    
    if self.isMovingExistingItem and self.isTransitioningFromRotation and self.previewItem then
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then newOrientation = self.previewItem:GetPrimaryPartCFrame() - self.previewItem:GetPrimaryPartCFrame().Position
        elseif self.previewItem:IsA("BasePart") then newOrientation = self.previewItem.CFrame - self.previewItem.CFrame.Position
        else newOrientation = CFrame.Angles(0, math.rad(self.currentAngleY or 0), 0) end
        if typeof(targetNormal) == "Vector3" then newPosition = hitPosition + targetNormal * (itemSizeY/2) else newPosition = hitPosition end
    else
        newOrientation = CFrame.Angles(0, math.rad(self.currentAngleY or 0), 0)
        if typeof(targetNormal) == "Vector3" and targetNormal.Magnitude > 0.001 then
            local up_vec = targetNormal; local yRot = CFrame.Angles(0,math.rad(self.currentAngleY or 0),0); local right_vec=yRot.RightVector:Cross(up_vec).Unit; local look_vec=up_vec:Cross(right_vec).Unit -- Renamed up, right, look
            if right_vec.Magnitude < 0.001 or look_vec.Magnitude < 0.001 then 
                newOrientation = CFrame.Angles(0,math.rad(self.currentAngleY or 0),0) 
            else 
                newOrientation = CFrame.fromMatrix(Vector3.new(),right_vec,up_vec,look_vec) 
            end
            newPosition = hitPosition + targetNormal * (itemSizeY/2)
        else 
            newOrientation = CFrame.Angles(0,math.rad(self.currentAngleY or 0),0); 
            newPosition = hitPosition 
        end
    end
    self.lastSnappedPosition = newPosition
    local rotationAngles = CFrame.Angles(math.rad(self.currentPlacementRotationX or 0), math.rad(self.currentPlacementRotationY or self.currentPlacementRotation or 0), math.rad(self.currentPlacementRotationZ or 0))
    local newCFrame = CFrame.new(newPosition) * newOrientation * rotationAngles
    if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then self.previewItem:SetPrimaryPartCFrame(newCFrame) elseif self.previewItem:IsA("BasePart") then self.previewItem.CFrame = newCFrame end
end

function PlacementManager_Core:ShowItemInHand(itemId) -- Simplified
    if RunService:IsServer() then return false end; self:ClearItemFromHand()
    local normId = itemId:gsub(" ", "_"); local template = self:GetItemTemplate(normId); if not template then return false end
    local displayItem = template:Clone(); displayItem.Name = "HandItem_" .. normId
    if displayItem:IsA("Model") then for _,p_part in ipairs(displayItem:GetDescendants()) do if p_part:IsA("BasePart") then p_part.Transparency=math.max(0,p_part.Transparency-0.2);p_part.CanCollide=false;p_part.Anchored=true;p_part:SetAttribute("is_hand_item",true) end end -- Renamed p
    elseif displayItem:IsA("BasePart") then displayItem.Transparency=math.max(0,displayItem.Transparency-0.2);displayItem.CanCollide=false;displayItem.Anchored=true;displayItem:SetAttribute("is_hand_item",true) end
    local hl=Instance.new("Highlight");hl.FillTransparency=0.3;hl.OutlineTransparency=0;hl.FillColor=Color3.fromRGB(255,215,0);hl.OutlineColor=Color3.fromRGB(255,215,0);hl.Parent=displayItem
    displayItem.Parent = Workspace; self.handItem=displayItem; self.handItemId=normId
    local plr=Players.LocalPlayer; local char=plr.Character or plr.CharacterAdded:Wait(); local hrp=char:WaitForChild("HumanoidRootPart")
    local moveConn; moveConn=RunService.RenderStepped:Connect(function() 
        if not self.handItem then if moveConn then moveConn:Disconnect(); moveConn = nil; end return end; 
        local offset=hrp.CFrame.LookVector*3; local pos=hrp.Position+offset;pos=Vector3.new(pos.X,pos.Y+1,pos.Z); 
        local rot_angle=tick()%(2*math.pi); local rotCF=CFrame.Angles(0,rot_angle,0); -- Renamed rot to rot_angle
        if self.handItem:IsA("Model") and self.handItem.PrimaryPart then self.handItem:SetPrimaryPartCFrame(CFrame.new(pos)*rotCF) 
        else self.handItem.CFrame=CFrame.new(pos)*rotCF 
        end 
    end)
    local uis_service=game:GetService("UserInputService"); local inputConn, scrollConn, gamepadConn; -- Renamed uis
    inputConn=uis_service.InputBegan:Connect(function(inp,gp) 
        if gp then return end; 
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then 
            self:StartPlacing(self.handItemId); 
            if inputConn then inputConn:Disconnect(); inputConn=nil; end; 
            if moveConn then moveConn:Disconnect(); moveConn=nil; end; 
            self.handItem=nil;self.handItemId=nil 
        elseif inp.UserInputType==Enum.UserInputType.MouseButton2 or inp.KeyCode==Enum.KeyCode.Escape then 
            self:ClearItemFromHand(); 
            if self.placementControlsUI then self.placementControlsUI:Hide() end; 
            if inputConn then inputConn:Disconnect(); inputConn=nil; end; 
            if moveConn then moveConn:Disconnect(); moveConn=nil; end 
        end 
    end)
    scrollConn = uis_service.InputChanged:Connect(function(input_arg,gp) -- Renamed input to input_arg
        if gp or not self.isPlacing or not self.previewItem then return end; 
        if input_arg.UserInputType==Enum.UserInputType.MouseWheel then 
            local s_held=uis_service:IsKeyDown(Enum.KeyCode.LeftShift)or uis_service:IsKeyDown(Enum.KeyCode.RightShift); -- Renamed s to s_held
            local c_held=uis_service:IsKeyDown(Enum.KeyCode.LeftControl)or uis_service:IsKeyDown(Enum.KeyCode.RightControl); -- Renamed c to c_held
            local d_scroll=input_arg.Position.Z>0 and 45 or -45;  -- Renamed d to d_scroll
            if c_held then self:_DirectRotateAxis("Z",d_scroll) 
            elseif s_held then self:_DirectRotateAxis("X",d_scroll) 
            else self:_DirectRotateAxis("Y",d_scroll) 
            end 
        end 
    end)
    gamepadConn = uis_service.InputBegan:Connect(function(input_arg,gp) -- Renamed input to input_arg
        if gp or not self.isPlacing or not self.previewItem then return end; 
        local lt_held=uis_service:IsKeyDown(Enum.KeyCode.ButtonL2);local rt_held=uis_service:IsKeyDown(Enum.KeyCode.ButtonR2); -- Renamed lt, rt
        if input_arg.KeyCode==Enum.KeyCode.ButtonL1 then 
            if lt_held then self:_DirectRotateAxis("Z",-45) 
            elseif rt_held then self:_DirectRotateAxis("X",-45) 
            else self:_DirectRotateAxis("Y",-45) 
            end 
        elseif input_arg.KeyCode==Enum.KeyCode.ButtonR1 then 
            if lt_held then self:_DirectRotateAxis("Z",45) 
            elseif rt_held then self:_DirectRotateAxis("X",45) 
            else self:_DirectRotateAxis("Y",45) 
            end 
        elseif input_arg.KeyCode==Enum.KeyCode.ButtonY then 
            self:_ShowRotationUI() 
        end 
    end)
    return true
end

function PlacementManager_Core:RecallItemFromInventory(itemId) -- Simplified
    if RunService:IsServer() then return false end
    local normId=itemId:gsub(" ","_")
    if not self:ShowItemInHand(normId) then return false end
    local msg="Left-click to place "..normId.." or right-click to cancel"
    local UIM=self.shared and self.shared.UIManager
    if UIM and UIM.ShowNotification then 
        UIM:ShowNotification(msg,5) 
    else 
        local sg=Instance.new("ScreenGui");sg.Name="PlacementNotification"
        local tl=Instance.new("TextLabel");tl.Size=UDim2.new(0,400,0,50);tl.Position=UDim2.new(0.5,-200,0.8,0);tl.BackgroundColor3=Color3.fromRGB(0,0,0);tl.BackgroundTransparency=0.5;tl.TextColor3=Color3.fromRGB(255,255,255);tl.TextSize=18;tl.Text=msg;tl.Parent=sg
        task.spawn(function()task.wait(5);sg:Destroy()end)
        sg.Parent=Players.LocalPlayer.PlayerGui 
    end
    return true
end

function PlacementManager_Core:ClearItemFromHand()
    if RunService:IsServer() then return end
    if self.handItem then self.handItem:Destroy(); self.handItem=nil; self.handItemId=nil end
    if self.previewItem then self.previewItem:Destroy(); self.previewItem=nil end
    if self.placementControlsUI then self.placementControlsUI:Hide() end
    if self.simpleRotationUI and self.simpleRotationUI:IsActive() then self.simpleRotationUI:Hide() end
    self.isPlacing=false; self.selectedItem=nil; self.currentPlacementRotation=nil
end

function PlacementManager_Core:SetupRemoteEvents()
    self.remotes = self.remotes or {}
    
    if RunService:IsClient() then
        -- CLIENT: Wait for and cache remote events
        local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
        if not remotesFolder then 
            warn("PlacementManager_Core: Remotes folder not found on client")
            return 
        end
        
        local function getEv(name) 
            local event = remotesFolder:WaitForChild(name, 5)
            if not event then warn("PlacementManager_Core: Failed to find remote event:", name) end
            return event
        end
        
        self.remotes.ItemPlaced = getEv("ItemPlaced")
        self.remotes.ItemRecalled = getEv("ItemRecalled")
        self.remotes.ItemUpdated = getEv("ItemUpdated")
        self.remotes.ItemDeleted = getEv("ItemDeleted")
        self.remotes.RequestPlaceItem = getEv("RequestPlaceItem")
        self.remotes.RequestRecallItem = getEv("RequestRecallItem")
        self.remotes.RequestMoveItem = getEv("RequestMoveItem")
        self.remotes.ConfirmMoveItem = getEv("ConfirmMoveItem")
        self.remotes.CancelMoveItem = getEv("CancelMoveItem")
        self.remotes.RequestRotateItem = getEv("RequestRotateItem")
        self.remotes.ConfirmRotation = getEv("ConfirmRotation")
        self.remotes.CancelRotation = getEv("CancelRotation")
        self.remotes.UpdateRotationInput = getEv("UpdateRotationInput")
        
        print("PlacementManager_Core: Client remote events cached")
    else
        -- SERVER: Create remote events and connect handlers
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotesFolder then 
            remotesFolder = Instance.new("Folder")
            remotesFolder.Name = "Remotes"
            remotesFolder.Parent = ReplicatedStorage
        end
        
        local function getOrCreateEvent(name) 
            local ev = remotesFolder:FindFirstChild(name)
            if not ev then 
                ev = Instance.new("RemoteEvent")
                ev.Name = name
                ev.Parent = remotesFolder
                print("PlacementManager_Core: Created remote event:", name)
            end
            return ev
        end
        
        self.remotes.ItemPlaced = getOrCreateEvent("ItemPlaced")
        self.remotes.ItemRecalled = getOrCreateEvent("ItemRecalled")
        self.remotes.ItemUpdated = getOrCreateEvent("ItemUpdated")
        self.remotes.ItemDeleted = getOrCreateEvent("ItemDeleted")
        self.remotes.RequestPlaceItem = getOrCreateEvent("RequestPlaceItem")
        self.remotes.RequestRecallItem = getOrCreateEvent("RequestRecallItem")
        self.remotes.RequestMoveItem = getOrCreateEvent("RequestMoveItem")
        self.remotes.ConfirmMoveItem = getOrCreateEvent("ConfirmMoveItem")
        self.remotes.CancelMoveItem = getOrCreateEvent("CancelMoveItem")
        self.remotes.RequestRotateItem = getOrCreateEvent("RequestRotateItem")
        self.remotes.ConfirmRotation = getOrCreateEvent("ConfirmRotation")
        self.remotes.CancelRotation = getOrCreateEvent("CancelRotation")
        self.remotes.UpdateRotationInput = getOrCreateEvent("UpdateRotationInput")
        
        -- Connect server event handlers
        self:_ConnectServerEventHandlers()
        
        print("PlacementManager_Core: Server remote events setup complete")
    end
end

function PlacementManager_Core:_ConnectServerEventHandlers()
    -- Separate method for server event handler connections
    if self.remotes.RequestPlaceItem then 
        self.remotes.RequestPlaceItem.OnServerEvent:Connect(function(player, itemId, position, normal, rotationData) 
            local finalRot
            if typeof(rotationData) == "table" then 
                finalRot = rotationData 
            elseif typeof(rotationData) == "number" then 
                finalRot = {X = 0, Y = rotationData, Z = 0} 
            else 
                finalRot = {X = 0, Y = 0, Z = 0} 
            end
            self:PlaceItem(player, itemId, position, normal, finalRot) 
        end) 
    end
    
    if self.remotes.RequestRecallItem then 
        self.remotes.RequestRecallItem.OnServerEvent:Connect(function(player, instanceId) 
            self:RecallItem(player, instanceId) 
        end) 
    end
    
    if self.remotes.RequestMoveItem then 
        self.remotes.RequestMoveItem.OnServerEvent:Connect(function(player, instanceId) 
            self:HandleRequestMoveItem(player, instanceId) 
        end) 
    end
    
    if self.remotes.ConfirmMoveItem then 
        self.remotes.ConfirmMoveItem.OnServerEvent:Connect(function(player, instanceId, newPosition, newRotationY) 
            self:HandleConfirmMoveItem(player, instanceId, newPosition, newRotationY) 
        end) 
    end
    
    if self.remotes.CancelMoveItem then 
        self.remotes.CancelMoveItem.OnServerEvent:Connect(function(player, instanceId) 
            self:HandleCancelMoveItem(player, instanceId) 
        end) 
    end
    
    if self.remotes.RequestRotateItem then 
        self.remotes.RequestRotateItem.OnServerEvent:Connect(function(player, instanceId, rotationDegrees) 
            self:HandleRotateItemRequest(player, instanceId, rotationDegrees) 
        end) 
    end
end

function PlacementManager_Core:CancelRotationWorkflow() -- Simplified
    if RunService:IsServer() or not self.isRotatingItem then return end; self.isRotatingItem=false
    if self.rotationRenderSteppedConnection then self.rotationRenderSteppedConnection:Disconnect(); self.rotationRenderSteppedConnection=nil end
    if self.rotationMouseConfirmConnection then self.rotationMouseConfirmConnection:Disconnect(); self.rotationMouseConfirmConnection=nil end
    if self.rotationKeyboardConfirmConnection then self.rotationKeyboardConfirmConnection:Disconnect(); self.rotationKeyboardConfirmConnection=nil end
    if self.rotationCancelConnection then self.rotationCancelConnection:Disconnect(); self.rotationCancelConnection=nil end
    if self.rotationInputChangedConnection then self.rotationInputChangedConnection:Disconnect(); self.rotationInputChangedConnection=nil end
    if self.rotationInputBeganConnection then self.rotationInputBeganConnection:Disconnect(); self.rotationInputBeganConnection=nil end
    if self.itemToRotate and self.itemToRotate:IsA("BasePart") then self.itemToRotate.Transparency = (self.Constants.PLACEMENT and self.Constants.PLACEMENT.PREVIEW_TRANSPARENCY) or 0.5 end
    if self.isMovingExistingItem and self.itemBeingMovedInstance and self.previewItem then 
        self.previewItem.CFrame = self.basePreviewCFrame; self:UpdatePlacementPreview(Players.LocalPlayer, Players.LocalPlayer:GetMouse()) 
    elseif self.previewItem then 
        self.previewItem:Destroy(); self.previewItem=nil 
    end
    self.itemToRotate=nil; self.isPlacing=false
    if self.rotationControlsUI and self.rotationControlsUI.SetVisible then self.rotationControlsUI:SetVisible(false) end
    if self.remotes.CancelRotation then self.remotes.CancelRotation:FireServer() end
end

function PlacementManager_Core:_CheckCollision(item_arg) -- Simplified
    if RunService:IsServer() or not item_arg then return false end
    local itemCF,itemSize;
    if item_arg:IsA("Model") then 
        if item_arg.PrimaryPart then itemCF=item_arg:GetPrimaryPartCFrame();itemSize=item_arg:GetExtentsSize() 
        else 
            local parts={}; for _,child_part in ipairs(item_arg:GetChildren()) do if child_part:IsA("BasePart") then table.insert(parts,child_part) end end; -- Renamed c
            if #parts>0 then itemCF=parts[1].CFrame;itemSize=parts[1].Size else return false end 
        end
    elseif item_arg:IsA("BasePart") then itemCF=item_arg.CFrame;itemSize=item_arg.Size 
    else return false 
    end
    local plr=Players.LocalPlayer; local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; 
    local filter_list={item_arg}; if plr and plr.Character then table.insert(filter_list,plr.Character) end; -- Renamed filter
    for _,child_item in ipairs(Workspace:GetChildren()) do if child_item.Name:find("Preview_") or child_item:GetAttribute("is_preview") then table.insert(filter_list,child_item) end end; -- Renamed c
    params.FilterDescendantsInstances=filter_list
    local dirs={Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(0,1,0),Vector3.new(0,-1,0),Vector3.new(0,0,1),Vector3.new(0,0,-1)}
    for _,d_vec in ipairs(dirs) do -- Renamed d
        local res=Workspace:Raycast(itemCF.Position,d_vec*(itemSize.Magnitude/2+1),params); 
        if res then 
            local hit_part=res.Instance; -- Renamed hit
            if hit_part and hit_part.Parent and (hit_part.Parent.Name:find("_" .. tostring(plr.UserId) .. "_") or hit_part:GetAttribute("PlacedItem") or hit_part:GetAttribute("InstanceId")) then return true,hit_part end 
        end 
    end
    return false
end

function PlacementManager_Core:_UpdatePreviewCollisionFeedback(hasCollision, collidingObject) -- Simplified
    if RunService:IsServer() or not self.previewItem then return end
    local hl=self.previewItem:FindFirstChildOfClass("Highlight")
    if hl then 
        if hasCollision then hl.FillColor=Color3.fromRGB(255,100,100);hl.OutlineColor=Color3.fromRGB(255,0,0);hl.FillTransparency=0.3;hl.OutlineTransparency=0 
        else hl.FillColor=Color3.fromRGB(100,255,100);hl.OutlineColor=Color3.fromRGB(0,255,0);hl.FillTransparency=0.5;hl.OutlineTransparency=0 
        end 
    end
end

function PlacementManager_Core:CacheRemoteEvents() -- Simplified
    if RunService:IsServer() then return false end
    self.remotes=self.remotes or {}; 
    local remotesFolder=ReplicatedStorage:WaitForChild("Remotes",10); if not remotesFolder then return false end
    local function getEv(name) 
        local ev_found=remotesFolder:FindFirstChild(name); -- Renamed ev
        if ev_found then return ev_found 
        else 
            local fev=remotesFolder:WaitForChild(name,5); 
            if fev then return fev else return nil end 
        end 
    end
    local evs={"ItemPlaced","ItemRecalled","ItemUpdated","ItemDeleted","RequestPlaceItem","RequestRecallItem","RequestMoveItem","ConfirmMoveItem","CancelMoveItem","RequestRotateItem","ConfirmRotation","CancelRotation","UpdateRotationInput"}; 
    for _,eN in ipairs(evs) do local event_instance=getEv(eN); if event_instance then self.remotes[eN]=event_instance end end -- Renamed e
    if not self.remotes.RequestPlaceItem then return false end; return true
end

function PlacementManager_Core:ResetPlacementState() -- Simplified
    if RunService:IsServer() then return end
    self.isPlacing=false;self.selectedItem=nil;self.isMovingExistingItem=false;self.itemBeingMovedInstance=nil;self.currentMoveCost=0;self.isTransitioningFromRotation=false;self.currentPlacementAngleX=0;self.currentPlacementAngleY=0;self.currentPlacementAngleZ=0;self.currentAngleY=0
    if self.previewItem then self.previewItem:Destroy();self.previewItem=nil end
    if self.handItem then self.handItem:Destroy();self.handItem=nil;self.handItemId=nil end
    if self.movementConnections then for _,conn in pairs(self.movementConnections) do if conn then conn:Disconnect() end end; self.movementConnections={} end -- Renamed c
    if self.inputConnections then for _,conn in pairs(self.inputConnections) do if conn then conn:Disconnect() end end; self.inputConnections={} end -- Renamed c
    self.isRotatingItem=false;self.itemToRotate=nil;self.rotationCost=0;self.currentRotationInput=CFrame.new();self.basePreviewCFrame=CFrame.new()
    if self.rotationRenderSteppedConnection then self.rotationRenderSteppedConnection:Disconnect();self.rotationRenderSteppedConnection=nil end
    if self.rotationMouseConfirmConnection then self.rotationMouseConfirmConnection:Disconnect();self.rotationMouseConfirmConnection=nil end
    if self.rotationKeyboardConfirmConnection then self.rotationKeyboardConfirmConnection:Disconnect();self.rotationKeyboardConfirmConnection=nil end
    if self.rotationCancelConnection then self.rotationCancelConnection:Disconnect();self.rotationCancelConnection=nil end
    if self.rotationInputChangedConnection then self.rotationInputChangedConnection:Disconnect();self.rotationInputChangedConnection=nil end
    if self.rotationInputBeganConnection then self.rotationInputBeganConnection:Disconnect();self.rotationInputBeganConnection=nil end
    if RotationControlsUI and RotationControlsUI.SetVisible then RotationControlsUI:SetVisible(false) end
end

function PlacementManager_Core:HandleRotateItemRequest(player, instanceId, rotationDegrees) -- Simplified
    if RunService:IsClient() then return false end
    local item_to_rotate=self:FindItemByInstanceId(instanceId); if not item_to_rotate then return false end; -- Renamed item
    local owner=item_to_rotate:GetAttribute("owner")or item_to_rotate:GetAttribute("playerId"); 
    if owner~=player.UserId then return false end
    if self:RotateItemToAngle(item_to_rotate,rotationDegrees) then 
        item_to_rotate:SetAttribute("rotation",rotationDegrees);item_to_rotate:SetAttribute("lastModified",os.time()); 
        if self.remotes.ItemUpdated then 
            local pos=item_to_rotate:IsA("Model")and item_to_rotate.PrimaryPart and item_to_rotate.PrimaryPart.Position or item_to_rotate.Position; 
            self.remotes.ItemUpdated:FireClient(player,instanceId,pos,rotationDegrees) 
        end; 
        task.spawn(function()self:SaveWorldData()end); 
        return true 
    else 
        return false 
    end
end

function PlacementManager_Core:RotateItemToAngle(item_to_rotate, angleDegrees) -- Simplified & renamed item
    if RunService:IsClient() or not item_to_rotate then return false end
    local rad=math.rad(angleDegrees); local suc=false
    if item_to_rotate:IsA("Model") and item_to_rotate.PrimaryPart then 
        local p_pos=item_to_rotate.PrimaryPart.Position; local cf=CFrame.new(p_pos)*CFrame.Angles(0,rad,0); -- Renamed p
        local s_ok,r_err=pcall(function() item_to_rotate:SetPrimaryPartCFrame(cf) end); if s_ok then suc=true end -- Renamed s, r
    elseif item_to_rotate:IsA("BasePart") then 
        local p_pos=item_to_rotate.Position; local cf=CFrame.new(p_pos)*CFrame.Angles(0,rad,0);  -- Renamed p
        local s_ok,r_err=pcall(function() item_to_rotate.CFrame=cf end); if s_ok then suc=true end -- Corrected: removed extra ')' before 'end', ensured space
    end
    return suc
end

function PlacementManager_Core:_ApplyRotationToItem(item_to_rotate, angleDegrees) -- Simplified & renamed item
    if RunService:IsServer() or not item_to_rotate then return end
    local x_rot=self.currentPlacementRotationX or 0; -- Renamed x
    local y_rot=angleDegrees or self.currentPlacementRotationY or self.currentPlacementRotation or 0; -- Renamed y
    local z_rot=self.currentPlacementRotationZ or 0; -- Renamed z
    self:_ApplyMultiAxisRotation(item_to_rotate,x_rot,y_rot,z_rot)
end

function PlacementManager_Core:_ApplyMultiAxisRotation(item_to_rotate, rotX, rotY, rotZ) -- Simplified & renamed item
    if RunService:IsServer() or not item_to_rotate then return end
    local xR=math.rad(rotX or 0); local yR=math.rad(rotY or 0); local zR=math.rad(rotZ or 0)
    if item_to_rotate:IsA("Model") and item_to_rotate.PrimaryPart then 
        local p_pos=item_to_rotate.PrimaryPart.Position; local cf=CFrame.new(p_pos)*CFrame.Angles(xR,yR,zR); item_to_rotate:SetPrimaryPartCFrame(cf) -- Renamed p
    elseif item_to_rotate:IsA("BasePart") then 
        local p_pos=item_to_rotate.Position; local cf=CFrame.new(p_pos)*CFrame.Angles(xR,yR,zR); item_to_rotate.CFrame=cf -- Renamed p
    end
end

function PlacementManager_Core:_DirectRotate(degrees) 
    if RunService:IsServer() or not self.isPlacing or not self.previewItem then return end; 
    self:_DirectRotateAxis("Y", degrees) 
end

function PlacementManager_Core:_DirectRotateAxis(axis, degrees) -- Simplified
    if RunService:IsServer() or not self.isPlacing or not self.previewItem then return end
    if axis=="X" then 
        self.currentPlacementRotationX=(self.currentPlacementRotationX or 0)+degrees; 
        while self.currentPlacementRotationX>=360 do self.currentPlacementRotationX-=360 end; 
        while self.currentPlacementRotationX<-360 do self.currentPlacementRotationX+=360 end
    elseif axis=="Y" then 
        self.currentPlacementRotationY=(self.currentPlacementRotationY or 0)+degrees; 
        self.currentPlacementRotation=self.currentPlacementRotationY; 
        while self.currentPlacementRotationY>=360 do self.currentPlacementRotationY-=360 end; 
        while self.currentPlacementRotationY<0 do self.currentPlacementRotationY+=360 end; 
        self.currentPlacementRotation=self.currentPlacementRotationY
    elseif axis=="Z" then 
        self.currentPlacementRotationZ=(self.currentPlacementRotationZ or 0)+degrees; 
        while self.currentPlacementRotationZ>=360 do self.currentPlacementRotationZ-=360 end; 
        while self.currentPlacementRotationZ<-360 do self.currentPlacementRotationZ+=360 end 
    end
    self:_ApplyMultiAxisRotation(self.previewItem, self.currentPlacementRotationX or 0, self.currentPlacementRotationY or 0, self.currentPlacementRotationZ or 0)
end

function PlacementManager_Core:_ShowRotationUI() -- Simplified
    if RunService:IsServer() or not self.isPlacing or not self.previewItem then return end
    local onCh=function(it,r_angle) self:_ApplyRotationToItem(it,r_angle); self.currentPlacementRotation=r_angle end; -- Renamed r
    local onCf=function(it,fR_angle) self.currentPlacementRotation=fR_angle end; -- Renamed fR
    local onCc=function(it) local oR_angle=self.currentPlacementRotation or 0; if it then self:_ApplyRotationToItem(it,oR_angle) end end; -- Renamed oR
    if self.simpleRotationUI then self.simpleRotationUI:Show(self.previewItem,onCh,onCf,onCc) end
end

-- Placeholder for functions that will be moved out or fully implemented in core
function PlacementManager_Core:RecallItem(player, instanceId)
    -- This logic will be more complex and involve PlacementUtils, cost checks (via processItemActionRequest), etc.
    print(string.format("PlacementManager_Core:RecallItem (placeholder) called for player %s, instanceId %s", player.Name, tostring(instanceId)))
    -- Example: Get item, add to inventory (via ItemPurchaseHandler or similar), destroy world object, notify client.
end

function PlacementManager_Core:HandleRequestMoveItem(player, instanceId)
    print(string.format("PlacementManager_Core:HandleRequestMoveItem (placeholder) for %s, item %s", player.Name, instanceId))
end

function PlacementManager_Core:HandleConfirmMoveItem(player, instanceId, newPosition, newRotationY)
    print(string.format("PlacementManager_Core:HandleConfirmMoveItem (placeholder) for %s, item %s", player.Name, instanceId))
end

function PlacementManager_Core:HandleCancelMoveItem(player, instanceId)
     print(string.format("PlacementManager_Core:HandleCancelMoveItem (placeholder) for %s, item %s", player.Name, instanceId))
end

-- HandleCloneItemRequest, HandleCostedRecallItemRequest, HandleDestroyItemRequest will be added here
-- They will call the relevant functions in PlacementUtils or their own specific logic modules

function PlacementManager_Core:HandleCloneItemRequest(player, itemInstance, cost, originalItemId)
    print(string.format("PlacementManager_Core:HandleCloneItemRequest CALLED for item: %s by player %s (cost: %s, originalId: %s)", tostring(itemInstance and itemInstance.Name), tostring(player and player.Name), tostring(cost), tostring(originalItemId)))
    if not itemInstance or not itemInstance.Parent then return {success = false, message = "Original item not found or invalid."} end
    local template = self:GetItemTemplate(originalItemId); if not template then return {success = false, message = string.format("Template for '%s' not found.", tostring(originalItemId))} end
    local newItem = template:Clone(); local newInstanceId = originalItemId .. "_" .. player.UserId .. "_" .. tostring(os.time()) .. "_clone"
    newItem:SetAttribute("instanceId", newInstanceId); newItem:SetAttribute("itemId", originalItemId); newItem:SetAttribute("owner", player.UserId); newItem:SetAttribute("placedTime", os.time()); newItem:SetAttribute("persistent", true)
    local itemDef = self.Constants and self.Constants.ITEMS and self.Constants.ITEMS[originalItemId]; if itemDef and itemDef.priceIngame then newItem:SetAttribute("priceIngame", itemDef.priceIngame) else newItem:SetAttribute("priceIngame", 0) end
    if UniqueItemIdAssigner and UniqueItemIdAssigner.assignIdToNewItem then UniqueItemIdAssigner.assignIdToNewItem(newItem) end
    local parentFolder = self.placedFolder or Workspace:FindFirstChild("World_Items"):FindFirstChild("Placed"); if not parentFolder then warn("No placedFolder!"); return {success=false, message="Storage error"} end
    newItem.Parent = parentFolder; local pos = itemInstance.Position + Vector3.new(2,0,0) -- Offset clone slightly
    if newItem:IsA("Model") and newItem.PrimaryPart then newItem:SetPrimaryPartCFrame(CFrame.new(pos)) elseif newItem:IsA("BasePart") then newItem.CFrame = CFrame.new(pos) end
    if not self.placedItemsByPlayer[player.UserId] then self.placedItemsByPlayer[player.UserId] = {} end; table.insert(self.placedItemsByPlayer[player.UserId], newInstanceId)
    self:SaveWorldData()
    local currency_name_to_use; local raw_currency_ingame = self.Constants.CURRENCY.INGAME
    if type(raw_currency_ingame) == "string" and raw_currency_ingame ~= "" then currency_name_to_use = raw_currency_ingame else currency_name_to_use = "coins" end
    local message = string.format("Item %s cloned for %s %s. New item ID: %s", tostring(originalItemId), tostring(cost), currency_name_to_use, tostring(newInstanceId))
    return {success = true, message = message}
end

function PlacementManager_Core:HandleCostedRecallItemRequest(player, itemInstance, cost, originalItemId)
    print(string.format("PlacementManager_Core:HandleCostedRecallItemRequest called for item: %s by player %s (cost: %s, originalItemId: %s)", itemInstance.Name, player.Name, tostring(cost), originalItemId))
    if not itemInstance or not itemInstance.Parent then return {success = false, message = "Item to recall not found or invalid."} end
    if not originalItemId then return {success = false, message = "Cannot recall item: Original ItemID is missing."} end
    local ItemPurchaseHandler = self.shared and self.shared.ItemPurchaseHandler; 
    if not ItemPurchaseHandler then 
        local s_iph,r_iph=pcall(function() return require(game:GetService("ServerScriptService").server.ItemPurchaseHandler) end); -- Renamed s,r
        if s_iph then ItemPurchaseHandler=r_iph else warn("Failed to get IPH"); return {success=false, message="Inventory service error."} end 
    end
    local addSuccess, addMsg = ItemPurchaseHandler:AddToPlayerInventory(player, originalItemId, 1)
    if not addSuccess then return {success = false, message = addMsg or "Failed to add item back to inventory."} end
    itemInstance:Destroy()
    local ownerId = player.UserId; 
    if self.placedItemsByPlayer and self.placedItemsByPlayer[ownerId] then 
        local instId = itemInstance:GetAttribute("instanceId"); 
        for i,id_in_list in ipairs(self.placedItemsByPlayer[ownerId]) do 
            if id_in_list == instId then table.remove(self.placedItemsByPlayer[ownerId],i); break end 
        end 
    end
    self:SaveWorldData()
    local currency_name_to_use_recall; local raw_currency_ingame_recall = self.Constants.CURRENCY.INGAME
    if type(raw_currency_ingame_recall) == "string" and raw_currency_ingame_recall ~= "" then currency_name_to_use_recall = raw_currency_ingame_recall else currency_name_to_use_recall = "coins" end
    local message = string.format("Item %s (ID: %s) recalled for %s %s. Added to inventory.", tostring(originalItemId), tostring(itemInstance:GetAttribute("instanceId")), tostring(cost), currency_name_to_use_recall)
    return {success = true, message = message}
end

function PlacementManager_Core:HandleDestroyItemRequest(player, itemInstance, cost, originalItemId)
    print(string.format("PlacementManager_Core:HandleDestroyItemRequest called for item: %s by player %s (cost: %s, originalItemId: %s)", itemInstance.Name, player.Name, tostring(cost), originalItemId))
    if not itemInstance or not itemInstance.Parent then return {success = false, message = "Item to destroy not found or invalid."} end
    local deleteSuccess = self:DeleteItem(player, itemInstance:GetAttribute("instanceId")) -- DeleteItem uses instanceId
    if not deleteSuccess then return {success = false, message = "Failed to destroy item from world."} end
    local currency_name_to_use_destroy; local raw_currency_ingame_destroy = self.Constants.CURRENCY.INGAME
    if type(raw_currency_ingame_destroy) == "string" and raw_currency_ingame_destroy ~= "" then currency_name_to_use_destroy = raw_currency_ingame_destroy else currency_name_to_use_destroy = "coins" end
    local message = string.format("Item %s (ID: %s) destroyed for %s %s.", tostring(originalItemId), tostring(itemInstance:GetAttribute("instanceId")), tostring(cost), currency_name_to_use_destroy)
    return {success = true, message = message}
end

return PlacementManager_Core 