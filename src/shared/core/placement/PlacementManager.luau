-- PlacementManager.luau
-- Manages the placement, recall, and persistence of items in the world

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Import SimpleRotationUI for cross-platform rotation
local SimpleRotationUI = require(script.Parent.SimpleRotationUI)
-- Import PlacementControlsUI for clear placement instructions
local PlacementControlsUI = require(script.Parent.PlacementControlsUI)

-- Attempt to require RotationControlsUI (Client-Only)
local RotationControlsUI
if RunService:IsClient() then
    local successRotationUI, resultRotationUI = pcall(function()
        return require(script.Parent.Parent.ui.RotationControlsUI) -- Assuming path from PlacementManager to RotationControlsUI
    end)
    if successRotationUI then
        RotationControlsUI = resultRotationUI
        print("PlacementManager: Successfully required RotationControlsUI")
    else
        warn("PlacementManager: Failed to require RotationControlsUI:", resultRotationUI)
    end
end

-- Configuration
local PLACED_ITEMS_FOLDER_NAME = "World_Items" -- Use the existing World_Items folder
local _MAX_PLACEMENT_DISTANCE = 20 -- MAX_PLACEMENT_DISTANCE is never used; prefix with '_' to silence

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
        self.isMovingExistingItem = false -- NEW: True if player is moving an already placed item
        self.itemBeingMovedInstance = nil -- NEW: Stores the actual world instance being moved
        self.currentMoveCost = 0          -- NEW: Stores the cost for the current move operation
        self.isTransitioningFromRotation = false -- NEW: True if placing after rotation
        self.currentAngleY = 0 -- INITIALIZE self.currentAngleY

        -- Performance optimization variables to prevent bouncing
        self.lastUpdatePlacementTime = 0
        self.updatePlacementInterval = 0.05 -- 20 FPS max (50ms between updates) - more aggressive throttling
        self.lastSnappedPosition = nil
        self.positionChangeTolerance = 0.1 -- Only update if position changes by more than 0.1 studs

        -- NEW: State variables for Rotation Workflow
        self.isRotatingItem = false
        self.itemToRotate = nil -- Will be the previewItem during rotation phase
        self.rotationCost = 0
        self.currentRotationInput = CFrame.new() -- Stores the accumulated rotation for the preview
        self.basePreviewCFrame = CFrame.new() -- Stores the CFrame of the preview *before* mouse/keyboard rotation is applied
        self.rotationSensitivityMouse = 0.01 -- Radians per mouse pixel delta
        self.rotationSensitivityKeys = math.rad(5) -- Radians per key press
        
        -- Connections for rotation
        self.rotationRenderSteppedConnection = nil
        self.rotationMouseConfirmConnection = nil
        self.rotationKeyboardConfirmConnection = nil
        self.rotationCancelConnection = nil
        self.rotationInputChangedConnection = nil -- For mouse-based rotation
        self.rotationInputBeganConnection = nil   -- For key-based rotation commands (confirm, cancel, axis rotate)
        
        -- NEW: Instantiate RotationControlsUI
        if RotationControlsUI then
            self.rotationControlsUI = RotationControlsUI.new()
            if not self.rotationControlsUI then
                warn("PlacementManager: Failed to instantiate RotationControlsUI")
            end
        end
        
        -- Initialize simple rotation UI
        self.simpleRotationUI = SimpleRotationUI.new()
        
        -- Initialize placement controls UI
        self.placementControlsUI = PlacementControlsUI.new()
        
        -- Cache remote events on the client
        print("--- PLACEMENT MANAGER CLIENT CONSTRUCTOR REACHED (IsClient == true) ---") -- MARKER
        self:CacheRemoteEvents()
    else -- Assume server if not client
        -- Initialize UniqueItemIdAssigner module on server
        local success, result = pcall(function()
            return require(game:GetService("ServerScriptService").server.UniqueItemIdAssigner)
        end)
        
        if success then
            print("PlacementManager.new: Successfully required UniqueItemIdAssigner")
            -- Store the module in self
            self.UniqueItemIdAssigner = result
            -- Also set the global module variable for backward compatibility
            UniqueItemIdAssigner = result
        else
            warn("PlacementManager.new: Failed to require UniqueItemIdAssigner:", result)
            -- The fallback to ServerStorage was incorrect and has been removed.
            warn("PlacementManager.new: Could not find UniqueItemIdAssigner module via ServerScriptService.server.UniqueItemIdAssigner")
        end

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
        
        -- Initialize tracking tables
        self.ItemsByUniqueId = {}
        self.ItemsByInstanceId = {}
        self.ItemsByOwner = {} -- ADDED THIS LINE
        
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
        -- PRIMARY: Check for exact ItemId attribute match (preserves numeric IDs)
        local childItemId = child:GetAttribute("ItemId")
        if childItemId == itemId then
            return child
        end
        
        -- SECONDARY: Check lowercase itemId for compatibility  
        local childItemIdLower = child:GetAttribute("itemId")
        if childItemIdLower == itemId then
            return child
        end
        
        -- TERTIARY: Handle string/number conversion for cross-compatibility
        if type(itemId) == "number" and type(childItemId) == "string" then
            if tonumber(childItemId) == itemId then
                return child
            end
        elseif type(itemId) == "string" and type(childItemId) == "number" then
            if tostring(childItemId) == itemId then
                return child
            end
        end
        
        -- QUATERNARY: Same for lowercase itemId
        if type(itemId) == "number" and type(childItemIdLower) == "string" then
            if tonumber(childItemIdLower) == itemId then
                return child
            end
        elseif type(itemId) == "string" and type(childItemIdLower) == "number" then
            if tostring(childItemIdLower) == itemId then
                return child
            end
        end
        
        -- FALLBACK: Name matching for legacy compatibility
        if child.Name == tostring(itemId) then
            return child
        end
        
        -- Recursively search subfolders
        if child:IsA("Folder") then
            local found = findTemplateRecursive(child, itemId)
            if found then return found end
        end
    end
    return nil
end

-- Get an item template from ReplicatedStorage or other sources
function PlacementManager:GetItemTemplate(itemId)
    print("PlacementManager: Getting template for item:", itemId)
    
    if RunService:IsClient() then
        -- Client-side: Enhanced template search
        print("PlacementManager (Client): Searching for template:", itemId)
        
        -- 1. First check ReplicatedStorage.ItemTemplates (for basic parts)
        local templatesFolder = ReplicatedStorage:FindFirstChild("ItemTemplates")
        if templatesFolder then
            local template = templatesFolder:FindFirstChild(itemId)
            if template then
                print("PlacementManager (Client): Found template in ReplicatedStorage.ItemTemplates:", itemId)
                return template
            end
            -- Try normalized name on client too
            local normalizedItemIdClient = itemId:gsub(" ", "_")
            if normalizedItemIdClient ~= itemId then
                template = templatesFolder:FindFirstChild(normalizedItemIdClient)
                if template then
                    print("PlacementManager (Client): Found normalized template in ReplicatedStorage.ItemTemplates:", normalizedItemIdClient)
                    return template
                end
            end
        end
        
        -- 2. Check Workspace.Items (for actual models like Torch)
        local workspaceItems = Workspace:FindFirstChild("Items")
        if workspaceItems then
            local wsTemplate = findTemplateRecursive(workspaceItems, itemId)
            if wsTemplate then
                print("PlacementManager (Client): Found template in Workspace.Items (recursive):", itemId)
                return wsTemplate
            end
        end
        
        -- 3. Check ServerStorage.Items (for backup/duplicates)
        local serverItems = game:GetService("ServerStorage"):FindFirstChild("Items")
        if serverItems then
            local ssTemplate = findTemplateRecursive(serverItems, itemId)
            if ssTemplate then
                print("PlacementManager (Client): Found template in ServerStorage.Items (recursive):", itemId)
                return ssTemplate
            end
        end
        
        -- 4. Try mapped numeric ID if nothing found
        if self.itemTemplateMap and self.itemTemplateMap[itemId] then
            local mappedTemplateName = self.itemTemplateMap[itemId]
            print("PlacementManager (Client): Mapped numeric ID", itemId, "to template name:", mappedTemplateName)
            if templatesFolder then -- Re-check templatesFolder as it might have been nil
                local mappedTemplate = templatesFolder:FindFirstChild(mappedTemplateName)
                if mappedTemplate then
                     print("PlacementManager (Client): Found mapped template in ReplicatedStorage.ItemTemplates:", mappedTemplateName)
                    return mappedTemplate
                end
            end
        end

        warn("PlacementManager (Client): Template not found anywhere for:", itemId)
        return nil
    end

    -- Server-side logic (original broader search)
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

    -- 3. Fallback to ReplicatedStorage.ItemTemplates (initial check)
    local initialTemplatesFolder = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if initialTemplatesFolder then
        local template = initialTemplatesFolder:FindFirstChild(itemId)
        if template then
            print("PlacementManager: Found template in ReplicatedStorage.ItemTemplates (initial check):", itemId)
            return template
        end
    end
    
    -- Check if this is a numeric item ID that needs to be mapped to a template name
    if self.itemTemplateMap and self.itemTemplateMap[itemId] then
        local mappedTemplateName = self.itemTemplateMap[itemId]
        print("PlacementManager: Mapped numeric ID", itemId, "to template name:", mappedTemplateName)
        itemId = mappedTemplateName -- Update itemId to the mapped name for further checks
    end
    
    -- Normalize the itemId (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- First check in ReplicatedStorage.ItemTemplates (this variable is for the current scope)
    local currentItemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates") -- Renamed to avoid shadowing (original line 356)
    if not currentItemTemplates then
        -- Try to create templates folder on server if missing
        if RunService:IsServer() then
            print("PlacementManager: ItemTemplates folder not found, creating it")
            currentItemTemplates = Instance.new("Folder")
            currentItemTemplates.Name = "ItemTemplates"
            currentItemTemplates.Parent = ReplicatedStorage
            
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
                part.Parent = currentItemTemplates -- Use renamed variable
                
                print("PlacementManager: Created template:", info.name)
            end
        else
            warn("PlacementManager: ItemTemplates folder not found")
            return nil
        end
    end
    
    -- Debug info
    print("PlacementManager: Available templates in ItemTemplates folder:")
    for _, templateInLoop in ipairs(currentItemTemplates:GetChildren()) do -- Use renamed variable
        print("  -", templateInLoop.Name)
    end
    
    -- Try direct match first with normalizedItemId
    local template = currentItemTemplates:FindFirstChild(normalizedItemId) -- Use renamed variable
    if template then
        print("PlacementManager: Found exact template match:", normalizedItemId)
        return template
    end
    
    -- Try with original (possibly unnormalized or unmapped) itemId if different
    if normalizedItemId ~= itemId then
        template = currentItemTemplates:FindFirstChild(itemId) -- Use renamed variable
        if template then
            print("PlacementManager: Found template using original itemId:", itemId)
            return template
        end
    end
    
    -- Special case for Wood_Cube - if Wood_Plank exists, create Wood_Cube from it
    if normalizedItemId == "Wood_Cube" then
        local woodPlank = currentItemTemplates:FindFirstChild("Wood_Plank") -- Use renamed variable
        if woodPlank then
            print("PlacementManager: Creating Wood_Cube from Wood_Plank")
            local woodCube = woodPlank:Clone()
            woodCube.Name = "Wood_Cube"
            woodCube.Parent = currentItemTemplates -- Use renamed variable
            return woodCube
        end
    end
    
    -- Try with suffix variations (with and without _Cube)
    local tryWithCube = normalizedItemId
    if not normalizedItemId:lower():find("_cube$") then
        tryWithCube = normalizedItemId .. "_Cube"
    end
    
    template = currentItemTemplates:FindFirstChild(tryWithCube) -- Use renamed variable
    if template then
        print("PlacementManager: Found template with _Cube suffix:", tryWithCube)
        return template
    end
    
    -- Try without the _Cube suffix
    if normalizedItemId:lower():find("_cube$") then
        local tryWithoutCube = normalizedItemId:gsub("_Cube$", ""):gsub("_cube$", "") -- Handle both cases
        template = currentItemTemplates:FindFirstChild(tryWithoutCube) -- Use renamed variable
        if template then
            print("PlacementManager: Found template without _Cube suffix:", tryWithoutCube)
            return template
        end
    end
    
    -- Try case-insensitive lookup
    for _, potentialTemplate in ipairs(currentItemTemplates:GetChildren()) do -- Use renamed variable
        if potentialTemplate.Name:lower() == normalizedItemId:lower() or
           potentialTemplate.Name:lower() == itemId:lower() then -- Check against original itemId too
            print("PlacementManager: Found template using case-insensitive match:", potentialTemplate.Name)
            return potentialTemplate
        end
    end
    
    -- Try to find a template with a similar name as a last resort
    for _, potentialTemplate in ipairs(currentItemTemplates:GetChildren()) do -- Use renamed variable
        if potentialTemplate.Name:lower():find(normalizedItemId:lower(), 1, true) or -- Use plain find
           normalizedItemId:lower():find(potentialTemplate.Name:lower(), 1, true) then
            print("PlacementManager: Found template with similar name:", potentialTemplate.Name)
            return potentialTemplate
        end
    end
    
    -- If all else fails, create a basic template
    print("PlacementManager: No template found for " .. normalizedItemId .. " - creating basic preview")
    
    -- Check if this looks like a numeric ID (item_X format)
    local numericIdMatch = normalizedItemId:match("^item_(%d+)$") -- More specific match
    if numericIdMatch then
        print("PlacementManager: ⚠️ Item appears to be a numeric ID (item_" .. numericIdMatch .. "). Consider adding it to the itemTemplateMap.")
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
        newTemplate.BrickColor = BrickColor.new("Reddish brown") -- Was "Brick red", more standard is "Reddish brown"
        newTemplate.Material = Enum.Material.Brick
    else
        newTemplate.BrickColor = BrickColor.new("Medium stone grey")
        newTemplate.Material = Enum.Material.Concrete
    end
    
    newTemplate.Parent = currentItemTemplates -- Use renamed variable
    print("PlacementManager: Created new template:", normalizedItemId)
    return newTemplate
end

-- Server: Place an item in the world and persist it
function PlacementManager:PlaceItem(player, itemId, position, normal, rotationData, additionalAttributes)
    if RunService:IsClient() then return false end
    
    print("PlacementManager: PlaceItem called by", player.Name, "for item", itemId)
    print("📍 SERVER RECEIVED POSITION:", position)
    print("🔄 SERVER RECEIVED NORMAL:", normal)
    print("📐 SERVER RECEIVED ROTATION DATA:", rotationData)
    
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
    local instanceId
    -- Create a fallback ID using timestamp and player ID
    local timestamp = os.time()
    local playerId = player and player.UserId or 0
    instanceId = string.format("%s_%d_%d", normalizedItemId, playerId, timestamp)
    print("PlacementManager: Using fallback instanceId generation:", instanceId)
    
    placedItem.Name = instanceId -- Set the item's actual name to the instanceId
    
    -- Set core attributes
    placedItem:SetAttribute("itemId", itemId)
    placedItem:SetAttribute("instanceId", instanceId)
    placedItem:SetAttribute("owner", player.UserId)
    placedItem:SetAttribute("placedTime", os.time())
    placedItem:SetAttribute("persistent", true)
    
    -- Store rotation data as attributes for later retrieval
    placedItem:SetAttribute("rotationX", rotationData.X or 0)
    placedItem:SetAttribute("rotationY", rotationData.Y or 0)
    placedItem:SetAttribute("rotationZ", rotationData.Z or 0)
    
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
    
    -- Position and anchor the item with multi-axis rotation support
    if placedItem:IsA("Model") and placedItem.PrimaryPart then
        -- Apply multi-axis rotation using rotationData
        local rotationCFrame = CFrame.Angles(
            math.rad(rotationData.X or 0), -- X-axis (pitch)
            math.rad(rotationData.Y or 0), -- Y-axis (yaw)
            math.rad(rotationData.Z or 0)  -- Z-axis (roll)
        )
        
        placedItem:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        print("📐 APPLIED MULTI-AXIS ROTATION TO MODEL: X=" .. (rotationData.X or 0) .. "°, Y=" .. (rotationData.Y or 0) .. "°, Z=" .. (rotationData.Z or 0) .. "°")
        
        -- Set all parts to anchored
        for _, part in pairs(placedItem:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = true
            end
        end
    elseif placedItem:IsA("BasePart") then
        -- Apply multi-axis rotation using rotationData
        local rotationCFrame = CFrame.Angles(
            math.rad(rotationData.X or 0), -- X-axis (pitch)
            math.rad(rotationData.Y or 0), -- Y-axis (yaw)
            math.rad(rotationData.Z or 0)  -- Z-axis (roll)
        )
        
        placedItem.CFrame = CFrame.new(position) * rotationCFrame
        placedItem.Anchored = true
        placedItem.CanCollide = true
        print("📐 APPLIED MULTI-AXIS ROTATION TO PART: X=" .. (rotationData.X or 0) .. "°, Y=" .. (rotationData.Y or 0) .. "°, Z=" .. (rotationData.Z or 0) .. "°")
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
    
    -- Award XP for item placement
    if self.progressionManager and self.progressionManager.OnItemPlaced then
        self.progressionManager:OnItemPlaced(player, normalizedItemId)
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
        warn("FindItemByInstanceId called with nil instanceId")
        return nil
    end

    print(string.format("FindItemByInstanceId: Looking for item with instanceId '%s'", instanceId))

    -- Get all possible folders where items might be stored
    local possibleFolders = {}
    
    -- Check World_Items/Placed (standard)
    local worldItems = workspace:FindFirstChild("World_Items")
    if worldItems and worldItems:FindFirstChild("Placed") then
        table.insert(possibleFolders, worldItems.Placed)
        print(string.format("FindItemByInstanceId: Added World_Items/Placed folder to search: %s", worldItems.Placed:GetFullName()))
    end
    
    -- Check self.placedFolder (set in constructor)
    if self.placedFolder then
        -- Only add if it's different from what we already added
        if not worldItems or self.placedFolder ~= worldItems.Placed then
            table.insert(possibleFolders, self.placedFolder)
            print(string.format("FindItemByInstanceId: Added self.placedFolder to search: %s", self.placedFolder:GetFullName()))
        end
    end
    
    -- Check legacy PlacedItems folder
    local legacyFolder = workspace:FindFirstChild("PlacedItems")
    if legacyFolder then
        table.insert(possibleFolders, legacyFolder)
        print(string.format("FindItemByInstanceId: Added legacy PlacedItems folder to search: %s", legacyFolder:GetFullName()))
    end
    
    -- First try: direct lookup in all folders by Name
    for _, folder in ipairs(possibleFolders) do
        local item = folder:FindFirstChild(instanceId)
        if item then
            print(string.format("FindItemByInstanceId: Found item by name: %s", item:GetFullName()))
            return item
        end
    end
    
    -- Second try: search by instanceId attribute
    for _, folder in ipairs(possibleFolders) do
        for _, item in ipairs(folder:GetChildren()) do
            local itemInstanceId = item:GetAttribute("instanceId")
            if itemInstanceId and itemInstanceId == instanceId then
                print(string.format("FindItemByInstanceId: Found item by instanceId attribute: %s", item:GetFullName()))
                return item
            end
        end
    end
    
    -- Third try: search by UniqueItemId attribute
    for _, folder in ipairs(possibleFolders) do
        for _, item in ipairs(folder:GetChildren()) do
            local uniqueId = item:GetAttribute("UniqueItemId")
            if uniqueId and tostring(uniqueId) == instanceId then
                print(string.format("FindItemByInstanceId: Found item by UniqueItemId attribute: %s", item:GetFullName()))
                return item
            end
        end
    end
    
    warn(string.format("FindItemByInstanceId: Item with instanceId '%s' not found", instanceId))
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
    
    -- Try with ItemPurchaseHandler.luau in ServerScriptService
    local success1, result1 = pcall(function()
        return require(game:GetService("ServerScriptService").server.ItemPurchaseHandler) -- Path is correct
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
                return require(game:GetService("ServerScriptService").server.ItemPurchaseHandler) -- Corrected path
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
        -- Try to find InventoryManager in ReplicatedStorage.shared.core.inventory
        local success, result = pcall(function()
            return require(game:GetService("ReplicatedStorage").shared.core.inventory.InventoryManager) -- Corrected path
        end)
        
        if success then
            InventoryManager = result
            print("PlacementManager: Found InventoryManager in ReplicatedStorage.shared.core.inventory")
        else
            warn("PlacementManager: Failed to require InventoryManager from ReplicatedStorage.shared.core.inventory:", result)
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
    
    print(string.format("PlacementManager:DeleteItem - Starting deletion of item '%s' for player '%s'", tostring(instanceId), player.Name))
    
    -- Find the item by instanceId
    local item = self:FindItemByInstanceId(instanceId)
    if not item then
        warn(string.format("PlacementManager:DeleteItem - Item '%s' not found", tostring(instanceId)))
        return false
    end
    
    print(string.format("PlacementManager:DeleteItem - Found item: %s at %s", item.Name, item:GetFullName()))
    
    -- Check if player owns the item (or is an admin)
    local ownerId = item:GetAttribute("owner")
    local isAdmin = player:GetAttribute("IsAdmin") or false
    
    if ownerId and ownerId ~= player.UserId and not isAdmin then
        warn(string.format("PlacementManager:DeleteItem - Player '%s' (ID: %s) does not own item (owner: %s) and is not admin", player.Name, player.UserId, tostring(ownerId)))
        return false
    end
    
    -- Dump item attributes for debugging
    print("PlacementManager:DeleteItem - Item attributes:")
    for name, value in pairs(item:GetAttributes()) do
        print(string.format("  %s = %s", name, tostring(value)))
    end
    
    -- Remove from tracking tables
    if self.placedItemsByPlayer and ownerId and self.placedItemsByPlayer[ownerId] then
        local instanceIdAttribute = item:GetAttribute("instanceId")
        local found = false
        for i, id_in_list in ipairs(self.placedItemsByPlayer[ownerId]) do
            if id_in_list == instanceIdAttribute then
                table.remove(self.placedItemsByPlayer[ownerId], i)
                print(string.format("PlacementManager:DeleteItem - Removed instanceId '%s' from placedItemsByPlayer for ownerId %s.", instanceIdAttribute, tostring(ownerId)))
                found = true
                break
            end
        end
        if not found then
            print(string.format("PlacementManager:DeleteItem - WARNING: instanceId '%s' not found in placedItemsByPlayer for ownerId %s", instanceIdAttribute, tostring(ownerId)))
        end
    else
        print(string.format("PlacementManager:DeleteItem - WARNING: Cannot track deletion in placedItemsByPlayer. ownerId: %s, self.placedItemsByPlayer: %s", tostring(ownerId), tostring(self.placedItemsByPlayer ~= nil)))
    end
    
    -- Also remove from any lookup tables we maintain
    if self.ItemsByUniqueId then
        local uniqueItemId = item:GetAttribute("UniqueItemId")
        if uniqueItemId then
            self.ItemsByUniqueId[uniqueItemId] = nil
            print(string.format("PlacementManager:DeleteItem - Removed from ItemsByUniqueId lookup: %s", tostring(uniqueItemId)))
        end
    end
    
    -- Remove from InstanceId lookup
    local itemInstanceId = item:GetAttribute("instanceId")
    if itemInstanceId and self.ItemsByInstanceId then
        self.ItemsByInstanceId[itemInstanceId] = nil
        print(string.format("PlacementManager:DeleteItem - Removed from ItemsByInstanceId lookup: %s", itemInstanceId))
    end
    
    -- Destroy the item
    print(string.format("PlacementManager:DeleteItem - Destroying item: %s", item:GetFullName()))
    item:Destroy()
    
    -- Notify the client
    if self.remotes and self.remotes.ItemDeleted then
        print(string.format("PlacementManager:DeleteItem - Firing ItemDeleted event to client for player %s, instanceId %s", player.Name, instanceId))
        self.remotes.ItemDeleted:FireClient(player, instanceId)
    else
        print("PlacementManager:DeleteItem - WARNING: self.remotes.ItemDeleted is nil, cannot notify client!")
    end
    
    -- Save world data after deletion (non-blocking)
    print("PlacementManager:DeleteItem - Spawning task to save world data...")
    task.spawn(function()
        self:SaveWorldData()
    end)
    
    print(string.format("PlacementManager:DeleteItem - Successfully deleted item '%s'", instanceId))
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
function PlacementManager:StartPlacing(itemId, existingPreviewItem)
    if RunService:IsServer() then return false end
    
    self:ClearItemFromHand() -- ADDED: Explicitly clear hand item first
    self:ResetPlacementState() -- Ensure clean state

    print("PlacementManager: Client StartPlacing for item:", itemId)

    -- Clear any existing preview item (ResetPlacementState should handle this, but good to be sure)
    -- self:ClearItemFromHand() -- ClearItemFromHand is called by ResetPlacementState
    
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
    
            -- Initialize rotation (multi-axis support)
        self.currentPlacementRotation = 0 -- Y-axis (yaw) - backward compatibility
        self.currentPlacementRotationX = 0 -- X-axis (pitch) - up/down tilt
        self.currentPlacementRotationY = 0 -- Y-axis (yaw) - left/right rotation
        self.currentPlacementRotationZ = 0 -- Z-axis (roll) - spinning
    
    -- Setup placement controls callbacks
    local onRotate = function()
        self:_ShowRotationUI()
    end
    
    local onPlace = function()
        -- Place functionality is handled by the mouse click
        -- This is just for UI consistency
    end
    
    local onCancel = function()
        self:ClearItemFromHand()
    end
    
    -- Show placement controls UI
    if self.placementControlsUI then
        self.placementControlsUI:Show(itemId, onRotate, onPlace, onCancel)
    end
    
    -- Start the placement preview update loop
    local movementConnection
    movementConnection = RunService.RenderStepped:Connect(function()
        if not self.isPlacing or not self.previewItem then
            if movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
            -- Hide controls UI when placement ends
            if self.placementControlsUI then
                self.placementControlsUI:Hide()
            end
            return
        end
        
        self:UpdatePlacementPreview()
    end)
    
    -- Setup input to place the item on click
    local userInputService = game:GetService("UserInputService")
    local inputConnection, scrollConnection, gamepadConnection
    
    inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Handle rotation UI if active
        if self.simpleRotationUI and self.simpleRotationUI:IsActive() then
            -- Simple rotation UI will handle its own input
            return
        end
        
        -- Direct rotation controls during placement (multi-axis support)
        if self.isPlacing and self.previewItem then
            local isShiftHeld = userInputService:IsKeyDown(Enum.KeyCode.LeftShift) or userInputService:IsKeyDown(Enum.KeyCode.RightShift)
            local isCtrlHeld = userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(Enum.KeyCode.RightControl)
            
            if input.KeyCode == Enum.KeyCode.Q then
                if isCtrlHeld then
                    -- Ctrl+Q: Roll left (Z-axis)
                    self:_DirectRotateAxis("Z", -45)
                elseif isShiftHeld then
                    -- Shift+Q: Pitch down (X-axis)
                    self:_DirectRotateAxis("X", -45)
                else
                    -- Q: Yaw left (Y-axis)
                    self:_DirectRotateAxis("Y", -45)
                end
                return
            elseif input.KeyCode == Enum.KeyCode.E then
                if isCtrlHeld then
                    -- Ctrl+E: Roll right (Z-axis)
                    self:_DirectRotateAxis("Z", 45)
                elseif isShiftHeld then
                    -- Shift+E: Pitch up (X-axis)
                    self:_DirectRotateAxis("X", 45)
                else
                    -- E: Yaw right (Y-axis)
                    self:_DirectRotateAxis("Y", 45)
                end
                return
            elseif input.KeyCode == Enum.KeyCode.Space then
                -- Space: Show fine rotation UI
                self:_ShowRotationUI()
                return
            end
        end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left-click to place
            if self.isPlacing and self.previewItem then
                -- Get current position and rotation
                local position, orientation
                if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
                    position = self.previewItem.PrimaryPart.Position
                    orientation = self.previewItem.PrimaryPart.Orientation
                else
                    position = self.previewItem.Position
                    orientation = self.previewItem.Orientation
                end
                
                -- Convert orientation to parameters expected by server
                local normal = Vector3.new(0, 1, 0) -- Default surface normal (pointing up)
                local currentAngleY = self.currentPlacementRotation or orientation.Y or 0 -- Use stored rotation from rotation mode, or fallback to current orientation
                
                -- Request server to place the item
                print("PlacementManager: StartPlacing - About to fire RequestPlaceItem. self.remotes.RequestPlaceItem is:", self.remotes and self.remotes.RequestPlaceItem or "nil_remotes_or_requestplaceitem") -- MARKER
                print("📍 CLIENT PLACING AT POSITION:", position)
                print("🔄 CLIENT PLACING WITH ORIENTATION:", orientation)
                print("🔄 CLIENT SENDING NORMAL:", normal)
                -- Send multi-axis rotation data
                local rotationData = {
                    X = self.currentPlacementRotationX or 0,
                    Y = self.currentPlacementRotationY or self.currentPlacementRotation or currentAngleY or 0,
                    Z = self.currentPlacementRotationZ or 0
                }
                print("📐 CLIENT SENDING MULTI-AXIS ROTATION:", rotationData)
                if self.remotes and self.remotes.RequestPlaceItem then
                    self.remotes.RequestPlaceItem:FireServer(self.selectedItem, position, normal, rotationData)
                    print("PlacementManager: Requested server to place item:", self.selectedItem)
                else
                    warn("PlacementManager: Cannot place item - remote event not found. self.remotes table:", self.remotes, "self.remotes.RequestPlaceItem:", self.remotes and self.remotes.RequestPlaceItem or "nil") -- MARKER
                end
                
                -- Clean up
                self:ClearItemFromHand()
                self.isPlacing = false
                -- Clear all rotation values
                self.currentPlacementRotation = nil
                self.currentPlacementRotationX = 0
                self.currentPlacementRotationY = 0
                self.currentPlacementRotationZ = 0
                
                -- Disconnect all input handlers
                if inputConnection then
                    inputConnection:Disconnect()
                    inputConnection = nil
                end
                
                if scrollConnection then
                    scrollConnection:Disconnect()
                    scrollConnection = nil
                end
                
                if gamepadConnection then
                    gamepadConnection:Disconnect()
                    gamepadConnection = nil
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
            
            -- Disconnect all input handlers
            if inputConnection then
                inputConnection:Disconnect()
                inputConnection = nil
            end
            
            if scrollConnection then
                scrollConnection:Disconnect()
                scrollConnection = nil
            end
            
            if gamepadConnection then
                gamepadConnection:Disconnect()
                gamepadConnection = nil
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

-- Client: Start rotation mode for a placed item
function PlacementManager:RotatePlacedItem(placedItem)
    if RunService:IsServer() then return false end
    
    if not placedItem then
        warn("PlacementManager: No item provided for rotation")
        return false
    end
    
    print("🔄 PlacementManager: Starting rotation for placed item:", placedItem.Name)
    
    -- Get the instanceId for server communication
    local instanceId = placedItem:GetAttribute("instanceId") or placedItem.Name
    
    -- Store original rotation for cancel functionality
    local originalRotation = 0
    if placedItem:IsA("Model") and placedItem.PrimaryPart then
        local _, currentY, _ = placedItem.PrimaryPart.CFrame:ToEulerAnglesXYZ()
        originalRotation = math.deg(currentY)
    elseif placedItem:IsA("BasePart") then
        local _, currentY, _ = placedItem.CFrame:ToEulerAnglesXYZ()
        originalRotation = math.deg(currentY)
    end
    
    local onRotationChanged = function(item, rotation)
        -- Apply rotation to placed item in real-time
        self:_ApplyRotationToItem(item, rotation)
    end
    
    local onConfirm = function(item, finalRotation)
        print("✅ PlacementManager: Placed item rotation confirmed at", finalRotation, "degrees")
        
        -- Send rotation update to server
        if self.remotes and self.remotes.RequestRotateItem then
            self.remotes.RequestRotateItem:FireServer(instanceId, finalRotation)
            print("PlacementManager: Sent rotation request to server for", instanceId)
        else
            warn("PlacementManager: RequestRotateItem remote not available")
        end
    end
    
    local onCancel = function(item)
        print("❌ PlacementManager: Placed item rotation cancelled")
        -- Restore original rotation
        if item then
            self:_ApplyRotationToItem(item, originalRotation)
        end
    end
    
    -- Show the simple rotation UI
    if self.simpleRotationUI then
        self.simpleRotationUI:Show(placedItem, onRotationChanged, onConfirm, onCancel)
        return true
    else
        warn("PlacementManager: SimpleRotationUI not available")
        return false
    end
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
    
    -- Give the preview item an initial position (where the player is looking)
    local player = Players.LocalPlayer
    if player and player.Character then
        local camera = Workspace.CurrentCamera
        local mouse = player:GetMouse()
        
        -- Initial position setup - place it where the player is looking
        local viewportMouseRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {previewItem, player.Character}
        
        local raycastResult = Workspace:Raycast(viewportMouseRay.Origin, viewportMouseRay.Direction * 1000, raycastParams)
        if raycastResult then
            local initialPosition = raycastResult.Position + raycastResult.Normal * 2
            print("📍 PREVIEW ITEM INITIAL POSITION:", initialPosition)
            if previewItem:IsA("Model") and previewItem.PrimaryPart then
                previewItem:SetPrimaryPartCFrame(CFrame.new(initialPosition))
            elseif previewItem:IsA("BasePart") then
                previewItem.CFrame = CFrame.new(initialPosition)
            end
        else
            -- Fallback: place in front of player
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                local fallbackPosition = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 10
                print("📍 PREVIEW ITEM FALLBACK POSITION:", fallbackPosition)
                if previewItem:IsA("Model") and previewItem.PrimaryPart then
                    previewItem:SetPrimaryPartCFrame(CFrame.new(fallbackPosition))
                elseif previewItem:IsA("BasePart") then
                    previewItem.CFrame = CFrame.new(fallbackPosition)
                end
            end
        end
    end
    
    return previewItem
end

-- Client: Update the placement preview
function PlacementManager:UpdatePlacementPreview()
    if RunService:IsServer() then return end
    if not self.previewItem then return end
    if not (self.isPlacing or self.isMovingExistingItem) then return end

    -- PERFORMANCE THROTTLING: Prevent bouncing by limiting update frequency
    local currentTime = tick()
    if currentTime - self.lastUpdatePlacementTime < self.updatePlacementInterval then
        return -- Skip this update to prevent bouncing
    end

    -- Early basic setup checks
    local player = Players.LocalPlayer
    if not player or not player.Character then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local mouse = player:GetMouse()
    
    -- Get initial hit position quickly for position change check
    local viewportMouseRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local rayOrigin = viewportMouseRay.Origin
    local rayDirection = viewportMouseRay.Direction

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterInstances = {self.previewItem}
    if player.Character then table.insert(filterInstances, player.Character) end
    if self.itemBeingMovedInstance and self.isMovingExistingItem then
        table.insert(filterInstances, self.itemBeingMovedInstance)
    end
    raycastParams.FilterDescendantsInstances = filterInstances
    raycastParams.IgnoreWater = false

    local raycastResult = Workspace:Raycast(rayOrigin, rayDirection * 1000, raycastParams)
    local hitPosition = raycastResult and raycastResult.Position or (rayOrigin + rayDirection * 100)

    -- EARLY POSITION CHANGE CHECK: Skip expensive calculations if position hasn't changed much
    if self.lastSnappedPosition then
        local positionDelta = (hitPosition - self.lastSnappedPosition).Magnitude
        if positionDelta < self.positionChangeTolerance then
            return -- Skip update if position hasn't changed enough to prevent micro-bouncing
        end
    end

    -- Now we can update the timestamp since we're doing real work
    self.lastUpdatePlacementTime = currentTime

    -- Initialize angle variables without excessive logging
    self.currentPlacementAngleX = tonumber(self.currentPlacementAngleX) or 0
    self.currentPlacementAngleY = tonumber(self.currentPlacementAngleY) or 0
    self.currentPlacementAngleZ = tonumber(self.currentPlacementAngleZ) or 0

    local targetNormal = raycastResult and raycastResult.Normal or Vector3.new(0, 1, 0)
    local newPosition
    local newOrientation

    -- Get item size for placement calculations
    local _itemSize = Vector3.new(4, 4, 4) -- Default size, prefixed with _
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
        _itemSize = self.previewItem.PrimaryPart.Size
    elseif self.previewItem:IsA("BasePart") then
        _itemSize = self.previewItem.Size
    end

    if self.isMovingExistingItem and self.isTransitioningFromRotation and self.previewItem then
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
            newOrientation = self.previewItem:GetPrimaryPartCFrame() - self.previewItem:GetPrimaryPartCFrame().Position
        elseif self.previewItem:IsA("BasePart") then
            newOrientation = self.previewItem.CFrame - self.previewItem.CFrame.Position
        else
            newOrientation = CFrame.Angles(0, math.rad(self.currentAngleY), 0) -- Fallback
        end
        
        local itemSizeY = 0
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then itemSizeY = self.previewItem.PrimaryPart.Size.Y
        elseif self.previewItem:IsA("BasePart") then itemSizeY = self.previewItem.Size.Y end
        
        -- Ensure targetNormal is a valid Vector3 before using it
        if typeof(targetNormal) == "Vector3" then
            local basePosition = hitPosition + targetNormal * (itemSizeY / 2)
            
            newPosition = basePosition
        else
            -- Fallback if targetNormal is somehow not a Vector3
            newPosition = hitPosition
        end

    else
        newOrientation = CFrame.Angles(0, math.rad(self.currentAngleY), 0)

        local itemSizeY = 0
        if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then itemSizeY = self.previewItem.PrimaryPart.Size.Y
        elseif self.previewItem:IsA("BasePart") then itemSizeY = self.previewItem.Size.Y end


            -- Ensure targetNormal is a valid Vector3 before using it for complex CFrame math
            if typeof(targetNormal) == "Vector3" and targetNormal.Magnitude > 0.001 then
                local upVector = targetNormal
                local currentYRotationCFrame = CFrame.Angles(0, math.rad(self.currentAngleY), 0)
                local rightVector = currentYRotationCFrame.RightVector:Cross(upVector).Unit
                local lookVector = upVector:Cross(rightVector).Unit
                
                if rightVector.Magnitude < 0.001 or lookVector.Magnitude < 0.001 then 
                    newOrientation = CFrame.Angles(0, math.rad(self.currentAngleY), 0)
                else
                    newOrientation = CFrame.fromMatrix(Vector3.new(), rightVector, upVector, lookVector)
                end
                
                local basePosition = hitPosition + targetNormal * (itemSizeY / 2)
                
                newPosition = basePosition
            else
                -- Fallback if targetNormal is invalid
                newOrientation = CFrame.Angles(0, math.rad(self.currentAngleY), 0)
                newPosition = hitPosition
            end
    end

    -- Final position assignment and CFrame update
    self.lastSnappedPosition = newPosition
    
    -- Apply rotation angles - use multi-axis rotation system
    local rotationAngles = CFrame.Angles(
        math.rad(self.currentPlacementRotationX or self.currentPlacementAngleX or 0), -- X-axis (pitch)
        math.rad(self.currentPlacementRotationY or self.currentPlacementRotation or 0), -- Y-axis (yaw)
        math.rad(self.currentPlacementRotationZ or self.currentPlacementAngleZ or 0)  -- Z-axis (roll)
    )
    
    local newCFrame = CFrame.new(newPosition) * newOrientation * rotationAngles

    -- Debug: Only log occasionally to avoid spam (every 20 updates)
    if not self.debugUpdateCounter then self.debugUpdateCounter = 0 end
    self.debugUpdateCounter = self.debugUpdateCounter + 1
    if self.debugUpdateCounter % 20 == 0 then
        print("🔄 PREVIEW UPDATE - Position:", newPosition, "HitPos:", hitPosition)
    end

    if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
        self.previewItem:SetPrimaryPartCFrame(newCFrame)
    elseif self.previewItem:IsA("BasePart") then
        self.previewItem.CFrame = newCFrame
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
            -- Right click or Escape: Return to inventory
            self:ClearItemFromHand()
            
            -- Hide placement controls UI
            if self.placementControlsUI then
                self.placementControlsUI:Hide()
            end
            
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
    
    -- Add scroll wheel support for multi-axis rotation
    scrollConnection = userInputService.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isPlacing or not self.previewItem then return end
        
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local isShiftHeld = userInputService:IsKeyDown(Enum.KeyCode.LeftShift) or userInputService:IsKeyDown(Enum.KeyCode.RightShift)
            local isCtrlHeld = userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(Enum.KeyCode.RightControl)
            
            -- Scroll wheel: Rotate by 45 degrees (up = positive, down = negative)
            local scrollDirection = input.Position.Z > 0 and 45 or -45
            
            if isCtrlHeld then
                -- Ctrl+Scroll: Roll (Z-axis)
                self:_DirectRotateAxis("Z", scrollDirection)
                print("🖱️ Scroll wheel roll (Z):", scrollDirection, "degrees")
            elseif isShiftHeld then
                -- Shift+Scroll: Pitch (X-axis)
                self:_DirectRotateAxis("X", scrollDirection)
                print("🖱️ Scroll wheel pitch (X):", scrollDirection, "degrees")
            else
                -- Normal Scroll: Yaw (Y-axis)
                self:_DirectRotateAxis("Y", scrollDirection)
                print("🖱️ Scroll wheel yaw (Y):", scrollDirection, "degrees")
            end
        end
    end)
    
    -- Add gamepad support for multi-axis rotation
    gamepadConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isPlacing or not self.previewItem then return end
        
        -- Check for trigger presses (for modifier functionality)
        local isLeftTriggerHeld = userInputService:IsKeyDown(Enum.KeyCode.ButtonL2)
        local isRightTriggerHeld = userInputService:IsKeyDown(Enum.KeyCode.ButtonR2)
        
        if input.KeyCode == Enum.KeyCode.ButtonL1 then
            -- Left bumper with modifiers
            if isLeftTriggerHeld then
                -- L2+L1: Roll left (Z-axis)
                self:_DirectRotateAxis("Z", -45)
                print("🎮 L2+L1: Roll left (Z) -45 degrees")
            elseif isRightTriggerHeld then
                -- R2+L1: Pitch down (X-axis)
                self:_DirectRotateAxis("X", -45)
                print("🎮 R2+L1: Pitch down (X) -45 degrees")
            else
                -- L1 alone: Yaw left (Y-axis)
                self:_DirectRotateAxis("Y", -45)
                print("🎮 L1: Yaw left (Y) -45 degrees")
            end
        elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
            -- Right bumper with modifiers
            if isLeftTriggerHeld then
                -- L2+R1: Roll right (Z-axis)
                self:_DirectRotateAxis("Z", 45)
                print("🎮 L2+R1: Roll right (Z) 45 degrees")
            elseif isRightTriggerHeld then
                -- R2+R1: Pitch up (X-axis)
                self:_DirectRotateAxis("X", 45)
                print("🎮 R2+R1: Pitch up (X) 45 degrees")
            else
                -- R1 alone: Yaw right (Y-axis)
                self:_DirectRotateAxis("Y", 45)
                print("🎮 R1: Yaw right (Y) 45 degrees")
            end
        elseif input.KeyCode == Enum.KeyCode.ButtonY then
            -- Y button: Show fine rotation UI
            self:_ShowRotationUI()
            print("🎮 Y button: showing rotation UI")
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
    
    -- Hide placement controls UI
    if self.placementControlsUI then
        self.placementControlsUI:Hide()
    end
    
    -- Hide rotation UI if active
    if self.simpleRotationUI and self.simpleRotationUI:IsActive() then
        self.simpleRotationUI:Hide()
    end
    
    self.isPlacing = false
    self.selectedItem = nil
    self.currentPlacementRotation = nil
end

-- Setup remote events for client-server communication
function PlacementManager:SetupRemoteEvents()
    print("PlacementManager: Setting up remote events...")
    self.remotes = self.remotes or {} -- Ensure self.remotes is initialized

    if RunService:IsClient() then
        -- Client-side: Get existing events
        local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
        if not remotesFolder then
            warn("PlacementManager (Client): Remotes folder not found!")
            return
        end
        
        -- Helper function to get remote events
        local function getRemoteEvent(name)
            return remotesFolder:WaitForChild(name, 5)
        end
        
        self.remotes.ItemPlaced = getRemoteEvent("ItemPlaced")
        self.remotes.ItemRecalled = getRemoteEvent("ItemRecalled")
        self.remotes.ItemUpdated = getRemoteEvent("ItemUpdated")
        self.remotes.ItemDeleted = getRemoteEvent("ItemDeleted")
        self.remotes.RequestPlaceItem = getRemoteEvent("RequestPlaceItem")
        self.remotes.RequestRecallItem = getRemoteEvent("RequestRecallItem")
        self.remotes.RequestMoveItem = getRemoteEvent("RequestMoveItem") -- NEW
        self.remotes.ConfirmMoveItem = getRemoteEvent("ConfirmMoveItem") -- NEW
        self.remotes.CancelMoveItem = getRemoteEvent("CancelMoveItem")   -- NEW
        self.remotes.RequestRotateItem = getRemoteEvent("RequestRotateItem") -- NEW
        self.remotes.ConfirmRotation = getRemoteEvent("ConfirmRotation")     -- NEW
        self.remotes.CancelRotation = getRemoteEvent("CancelRotation")       -- NEW
        self.remotes.UpdateRotationInput = getRemoteEvent("UpdateRotationInput") -- NEW

        print("PlacementManager (Client): Remote events cached.")
        if not self.remotes.RequestPlaceItem then
            warn("PlacementManager (Client): RequestPlaceItem remote not found!")
        end

    else -- Server-side: Create events
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotesFolder then
            remotesFolder = Instance.new("Folder")
            remotesFolder.Name = "Remotes"
            remotesFolder.Parent = ReplicatedStorage
        end
        
        -- Helper function to get or create remote events
        local function getOrCreateRemoteEvent(name)
            local event = remotesFolder:FindFirstChild(name)
            if not event then
            event = Instance.new("RemoteEvent")
            event.Name = name
                event.Parent = remotesFolder
                print("PlacementManager: Created RemoteEvent:", name)
            end
        return event
    end
    
        self.remotes.ItemPlaced = getOrCreateRemoteEvent("ItemPlaced")
        self.remotes.ItemRecalled = getOrCreateRemoteEvent("ItemRecalled")
        self.remotes.ItemUpdated = getOrCreateRemoteEvent("ItemUpdated")
        self.remotes.ItemDeleted = getOrCreateRemoteEvent("ItemDeleted")
        self.remotes.RequestPlaceItem = getOrCreateRemoteEvent("RequestPlaceItem")
        self.remotes.RequestRecallItem = getOrCreateRemoteEvent("RequestRecallItem")
        self.remotes.RequestMoveItem = getOrCreateRemoteEvent("RequestMoveItem") -- NEW
        self.remotes.ConfirmMoveItem = getOrCreateRemoteEvent("ConfirmMoveItem") -- NEW
        self.remotes.CancelMoveItem = getOrCreateRemoteEvent("CancelMoveItem")   -- NEW
        self.remotes.RequestRotateItem = getOrCreateRemoteEvent("RequestRotateItem") -- NEW
        self.remotes.ConfirmRotation = getOrCreateRemoteEvent("ConfirmRotation")     -- NEW
        self.remotes.CancelRotation = getOrCreateRemoteEvent("CancelRotation")       -- NEW
        self.remotes.UpdateRotationInput = getOrCreateRemoteEvent("UpdateRotationInput") -- NEW
        
        print("PlacementManager (Server): Remote events created.")
        
        -- Connect server-side handlers
        if self.remotes.RequestPlaceItem then
            self.remotes.RequestPlaceItem.OnServerEvent:Connect(function(player, itemId, position, normal, rotationData, additionalAttributes)
                print("PlacementManager: Received RequestPlaceItem from", player.Name)
                print("📐 SERVER RECEIVED ROTATION DATA:", rotationData)
                
                -- Handle both old format (single Y angle) and new format (multi-axis)
                local finalRotation
                if typeof(rotationData) == "table" then
                    -- New multi-axis format
                    finalRotation = rotationData
                elseif typeof(rotationData) == "number" then
                    -- Old single Y-axis format (backward compatibility)
                    finalRotation = {X = 0, Y = rotationData, Z = 0}
                else
                    -- Fallback
                    finalRotation = {X = 0, Y = 0, Z = 0}
                end
                
                self:PlaceItem(player, itemId, position, normal, finalRotation, additionalAttributes)
            end)
        else
            warn("PlacementManager (Server): RequestPlaceItem remote not found, cannot connect handler.")
        end

        if self.remotes.RequestRecallItem then
            self.remotes.RequestRecallItem.OnServerEvent:Connect(function(player, instanceId)
                print("PlacementManager: Received RequestRecallItem from", player.Name)
            self:RecallItem(player, instanceId)
        end)
    end
    
        if self.remotes.RequestMoveItem then
            self.remotes.RequestMoveItem.OnServerEvent:Connect(function(player, instanceId)
                print("PlacementManager: Received RequestMoveItem from", player.Name, "for instanceId:", instanceId)
                self:HandleRequestMoveItem(player, instanceId)
        end)
    end
    
        if self.remotes.ConfirmMoveItem then
            self.remotes.ConfirmMoveItem.OnServerEvent:Connect(function(player, instanceId, newPosition, newRotationY)
                print("PlacementManager: Received ConfirmMoveItem from", player.Name, "for instanceId:", instanceId)
                self:HandleConfirmMoveItem(player, instanceId, newPosition, newRotationY)
        end)
    end
    
        if self.remotes.CancelMoveItem then
            self.remotes.CancelMoveItem.OnServerEvent:Connect(function(player, instanceId)
                print("PlacementManager: Received CancelMoveItem from", player.Name, "for instanceId:", instanceId)
                self:HandleCancelMoveItem(player, instanceId)
        end)
    end
    
        if self.remotes.RequestRotateItem then
            self.remotes.RequestRotateItem.OnServerEvent:Connect(function(player, instanceId, rotationDegrees)
                print("PlacementManager: Received RequestRotateItem from", player.Name, "for instanceId:", instanceId, "rotation:", rotationDegrees)
                self:HandleRotateItemRequest(player, instanceId, rotationDegrees)
        end)
    end
    
        if self.remotes.ConfirmRotation then
             self.remotes.ConfirmRotation.OnServerEvent:Connect(function(player, itemId, position, finalAngleY)
                print("PlacementManager: Received ConfirmRotation from", player.Name, "for item:", itemId, "angle:", finalAngleY)
                -- This is where the item would actually be placed after rotation is confirmed.
                -- The PlaceItem function already handles currentAngleY, so this might be redundant
                -- or needs to integrate with a specific rotation workflow state.
                -- For now, let's assume PlaceItem is called by client after rotation.
        end)
    end
    
        if self.remotes.CancelRotation then
            self.remotes.CancelRotation.OnServerEvent:Connect(function(player)
                print("PlacementManager: Received CancelRotation from", player.Name)
                -- Server-side cleanup if any for a cancelled rotation
        end)
    end
    
        if self.remotes.UpdateRotationInput then
            self.remotes.UpdateRotationInput.OnServerEvent:Connect(function(player, rotationDelta)
                 print("PlacementManager: Received UpdateRotationInput from", player.Name)
                -- Server typically doesn't need live rotation updates for previews.
                -- This might be for logging or server-side validation if strict checks are needed.
            end)
        end
    end
    print("PlacementManager: Remote event setup complete.")
end

-- (Client) Cancel the rotation workflow
function PlacementManager:CancelRotationWorkflow()
    if RunService:IsServer() then return end
    if not self.isRotatingItem then return end

    print("PlacementManager: Canceling rotation workflow.")

    self.isRotatingItem = false

    -- Disconnect rotation-specific input listeners
    if self.rotationRenderSteppedConnection then
        self.rotationRenderSteppedConnection:Disconnect()
        self.rotationRenderSteppedConnection = nil
    end
    if self.rotationMouseConfirmConnection then
        self.rotationMouseConfirmConnection:Disconnect()
        self.rotationMouseConfirmConnection = nil
    end
    if self.rotationKeyboardConfirmConnection then
        self.rotationKeyboardConfirmConnection:Disconnect()
        self.rotationKeyboardConfirmConnection = nil
    end
    if self.rotationCancelConnection then
        self.rotationCancelConnection:Disconnect()
        self.rotationCancelConnection = nil
    end
    if self.rotationInputChangedConnection then
        self.rotationInputChangedConnection:Disconnect()
        self.rotationInputChangedConnection = nil
    end
    if self.rotationInputBeganConnection then
        self.rotationInputBeganConnection:Disconnect()
        self.rotationInputBeganConnection = nil
    end

    -- Restore preview item if it was changed (e.g., color)
    if self.itemToRotate and self.itemToRotate:IsA("BasePart") then
        -- Assuming original color/material was stored or can be reset
        -- For simplicity, just ensure it's visible if it was made transparent
        self.itemToRotate.Transparency = self.Constants.PLACEMENT.PREVIEW_TRANSPARENCY or 0.5
    end
    
    -- If there was an item being moved, restore its preview to the last valid placement position
    if self.isMovingExistingItem and self.itemBeingMovedInstance and self.previewItem then
        print("PlacementManager: Restoring preview for moved item after rotation cancellation.")
        -- Reset the preview item to its state before rotation started
        self.previewItem.CFrame = self.basePreviewCFrame -- Restore pre-rotation CFrame
        self:UpdatePlacementPreview(Players.LocalPlayer, Players.LocalPlayer:GetMouse()) -- Refresh preview based on mouse
    elseif self.previewItem then
        -- If it was a new item placement, simply destroy the preview or hide it
        print("PlacementManager: Destroying preview item after new item rotation cancellation.")
        self.previewItem:Destroy()
        self.previewItem = nil
    end

    self.itemToRotate = nil
    self.isPlacing = false -- Exit placing mode if rotation was part of initial placement

    -- Hide Rotation UI
    if self.rotationControlsUI and self.rotationControlsUI.SetVisible then
        self.rotationControlsUI:SetVisible(false)
    end
    
    -- Notify server if necessary (e.g., to unlock an item if rotation had a cost implication)
    if self.remotes.CancelRotation then
        self.remotes.CancelRotation:FireServer()
    end

    print("PlacementManager: Rotation workflow cancelled.")
end

-- NOTE: Duplicate UpdatePlacementPreview function removed to avoid conflicts

-- Client: Check for collision with other objects
function PlacementManager:_CheckCollision(item)
    if RunService:IsServer() then return false end
    if not item then return false end
    
    -- Get the item's bounding box
    local itemCFrame
    local itemSize
    
    if item:IsA("Model") then
        if item.PrimaryPart then
            itemCFrame = item:GetPrimaryPartCFrame()
            itemSize = item:GetExtentsSize()
        else
            -- Fallback for models without PrimaryPart
            local parts = {}
            for _, child in ipairs(item:GetChildren()) do
                if child:IsA("BasePart") then
                    table.insert(parts, child)
        end
    end
            if #parts > 0 then
                itemCFrame = parts[1].CFrame
                itemSize = parts[1].Size
            else
                return false -- No parts to check
            end
        end
    elseif item:IsA("BasePart") then
        itemCFrame = item.CFrame
        itemSize = item.Size
    else
        return false -- Unknown item type
    end
    
    -- Create a slightly smaller region for overlap testing
    local checkSize = itemSize * 0.9 -- Slightly smaller to avoid edge cases
    local region = Region3.new(
        itemCFrame.Position - checkSize/2,
        itemCFrame.Position + checkSize/2
    )
    
    -- Use raycasting for collision detection instead of ReadVoxels
    local player = Players.LocalPlayer
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterInstances = {item}
    if player and player.Character then
        table.insert(filterInstances, player.Character)
    end
    -- Exclude other preview items
    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name:find("Preview_") or child:GetAttribute("is_preview") then
            table.insert(filterInstances, child)
        end
    end
    raycastParams.FilterDescendantsInstances = filterInstances
    
    -- Cast rays from the center of the item in multiple directions
    local directions = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 1, 0), Vector3.new(0, -1, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)
    }
    
    for _, direction in ipairs(directions) do
        local rayResult = Workspace:Raycast(
            itemCFrame.Position,
            direction * (itemSize.Magnitude / 2 + 1),
            raycastParams
        )
        
        if rayResult then
            -- Check if the hit part belongs to a placed item
            local hitPart = rayResult.Instance
            if hitPart and hitPart.Parent then
                -- Check if this is a placed item (not terrain or static world objects)
                if hitPart.Parent.Name:find("_7768610061_") or -- Player-placed items
                   hitPart:GetAttribute("PlacedItem") or
                   hitPart:GetAttribute("InstanceId") then
                    return true, hitPart
                end
            end
        end
    end
    
    return false
end

-- Client: Update preview visual feedback for collision detection
function PlacementManager:_UpdatePreviewCollisionFeedback(hasCollision, collidingObject)
    if RunService:IsServer() then return end
    if not self.previewItem then return end
    
    -- Find existing highlight
    local highlight = self.previewItem:FindFirstChildOfClass("Highlight")
    
    if hasCollision then
        -- Show red highlight for collision
        if highlight then
            highlight.FillColor = Color3.fromRGB(255, 100, 100) -- Red fill
            highlight.OutlineColor = Color3.fromRGB(255, 0, 0) -- Red outline
            highlight.FillTransparency = 0.3
            highlight.OutlineTransparency = 0
        end
        
        -- Optional: Add collision warning text or effect
        if collidingObject then
            print("Collision detected with", collidingObject.Name or "unknown object")
        end
    else
        -- Show green highlight for valid placement
        if highlight then
            highlight.FillColor = Color3.fromRGB(100, 255, 100) -- Green fill
            highlight.OutlineColor = Color3.fromRGB(0, 255, 0) -- Green outline
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
        end
    end
end

-- Cache remote events on client-side
function PlacementManager:CacheRemoteEvents()
    if RunService:IsServer() then 
        warn("PlacementManager: CacheRemoteEvents should only be called on client")
        return false
    end
    
    print("PlacementManager: Caching remote events --- MARKER ---")
    
    self.remotes = self.remotes or {} -- Ensure self.remotes is initialized
    
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotesFolder then
        warn("PlacementManager (Client): Remotes folder not found!")
        return false
    end
    
    print("PlacementManager: Remotes folder found immediately.")
    
    -- Helper function to get remote events with wait
    local function getRemoteEvent(name)
        local event = remotesFolder:FindFirstChild(name)
        if event then
            print("PlacementManager: Found remote event immediately:", name)
            return event
        else
            print("PlacementManager: Waiting for remote event:", name)
            local foundEvent = remotesFolder:WaitForChild(name, 5)
            if foundEvent then
                print("PlacementManager: Found remote event after wait:", name)
                return foundEvent
            else
                warn("PlacementManager: Failed to find remote event:", name)
                return nil
            end
        end
    end
    
    -- Cache all expected remote events
    local expectedEvents = {
        "ItemPlaced", "ItemRecalled", "ItemUpdated", "ItemDeleted",
        "RequestPlaceItem", "RequestRecallItem", "RequestMoveItem", 
        "ConfirmMoveItem", "CancelMoveItem", "RequestRotateItem", 
        "ConfirmRotation", "CancelRotation", "UpdateRotationInput"
    }
    
    for _, eventName in ipairs(expectedEvents) do
        local event = getRemoteEvent(eventName)
        if event then
            self.remotes[eventName] = event
            print("PlacementManager: Successfully cached remote event:", eventName)
    end
end

    -- Verify critical events
    if not self.remotes.RequestPlaceItem then
        warn("PlacementManager (Client): Critical RequestPlaceItem remote not found!")
        return false
    end
    
    print("PlacementManager: CacheRemoteEvents completed successfully")
    return true
end

-- Reset placement state and clear any previews/hand items
function PlacementManager:ResetPlacementState()
    if RunService:IsServer() then return end
    
    print("PlacementManager: Resetting placement state")
    
    -- Clear placement state
    self.isPlacing = false
    self.selectedItem = nil
    self.isMovingExistingItem = false
    self.itemBeingMovedInstance = nil
    self.currentMoveCost = 0
    self.isTransitioningFromRotation = false
    
    -- Reset angles
    self.currentPlacementAngleX = 0
    self.currentPlacementAngleY = 0
    self.currentPlacementAngleZ = 0
    self.currentAngleY = 0
    
    -- Clear preview item
    if self.previewItem then
        self.previewItem:Destroy()
        self.previewItem = nil
    end
    
    -- Clear hand item
    if self.handItem then
        self.handItem:Destroy()
        self.handItem = nil
        self.handItemId = nil
    end
    
    -- Disconnect any active movement connections
    if self.movementConnections then
        for _, connection in pairs(self.movementConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        self.movementConnections = {}
    end
    
    -- Disconnect input connections
    if self.inputConnections then
        for _, connection in pairs(self.inputConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        self.inputConnections = {}
    end
    
    -- Reset rotation state
    self.isRotatingItem = false
    self.itemToRotate = nil
    self.rotationCost = 0
    self.currentRotationInput = CFrame.new()
    self.basePreviewCFrame = CFrame.new()
    
    -- Disconnect rotation connections
    if self.rotationRenderSteppedConnection then
        self.rotationRenderSteppedConnection:Disconnect()
        self.rotationRenderSteppedConnection = nil
    end
    if self.rotationMouseConfirmConnection then
        self.rotationMouseConfirmConnection:Disconnect()
        self.rotationMouseConfirmConnection = nil
    end
    if self.rotationKeyboardConfirmConnection then
        self.rotationKeyboardConfirmConnection:Disconnect()
        self.rotationKeyboardConfirmConnection = nil
    end
    if self.rotationCancelConnection then
        self.rotationCancelConnection:Disconnect()
        self.rotationCancelConnection = nil
    end
    if self.rotationInputChangedConnection then
        self.rotationInputChangedConnection:Disconnect()
        self.rotationInputChangedConnection = nil
    end
    if self.rotationInputBeganConnection then
        self.rotationInputBeganConnection:Disconnect()
        self.rotationInputBeganConnection = nil
    end
    
    -- Hide Rotation UI if it exists
    if RotationControlsUI and RotationControlsUI.SetVisible then
        RotationControlsUI:SetVisible(false)
    end
end

-- Server: Handle rotation request for a placed item
function PlacementManager:HandleRotateItemRequest(player, instanceId, rotationDegrees)
    if RunService:IsClient() then return false end
    
    print("PlacementManager: HandleRotateItemRequest called for", instanceId, "rotation:", rotationDegrees)
    
    -- Find the placed item by instanceId
    local placedItem = self:FindItemByInstanceId(instanceId)
    if not placedItem then
        warn("PlacementManager: Placed item not found with instanceId:", instanceId)
        return false
    end
    
    -- Check if player owns the item
    local owner = placedItem:GetAttribute("owner") or placedItem:GetAttribute("playerId")
    if owner ~= player.UserId then
        warn("PlacementManager: Player", player.Name, "cannot rotate item owned by", owner)
        return false
    end
    
    print("PlacementManager: Rotating item", placedItem.Name, "to", rotationDegrees, "degrees for player", player.Name)
    
    -- Apply rotation to the item
    local success = self:RotateItemToAngle(placedItem, rotationDegrees)
    if success then
        -- Update the stored rotation attribute
        placedItem:SetAttribute("rotation", rotationDegrees)
        placedItem:SetAttribute("lastModified", os.time())
        
        -- Notify client of successful rotation
        if self.remotes.ItemUpdated then
            local position = placedItem:IsA("Model") and placedItem.PrimaryPart and placedItem.PrimaryPart.Position or placedItem.Position
            self.remotes.ItemUpdated:FireClient(player, instanceId, position, rotationDegrees)
        end
        
        -- Save world data
        task.spawn(function()
            self:SaveWorldData()
        end)
        
        print("✅ PlacementManager: Successfully rotated item", instanceId, "to", rotationDegrees, "degrees")
        return true
    else
        warn("PlacementManager: Failed to rotate item", instanceId)
        return false
    end
end

-- Server: Rotate an item to a specific angle in degrees
function PlacementManager:RotateItemToAngle(item, angleDegrees)
    if RunService:IsClient() then return false end
    if not item then return false end
    
    local angleRadians = math.rad(angleDegrees)
    local success = false
    
    if item:IsA("Model") and item.PrimaryPart then
        local currentPosition = item.PrimaryPart.Position
        local newCFrame = CFrame.new(currentPosition) * CFrame.Angles(0, angleRadians, 0)
        
        local pcallSuccess, result = pcall(function()
            item:SetPrimaryPartCFrame(newCFrame)
        end)
        
        if pcallSuccess then
            success = true
            print("PlacementManager: Rotated model", item.Name, "to", angleDegrees, "degrees")
        else
            warn("PlacementManager: Error rotating model:", result)
        end
        
    elseif item:IsA("BasePart") then
        local currentPosition = item.Position
        local newCFrame = CFrame.new(currentPosition) * CFrame.Angles(0, angleRadians, 0)
        
        local pcallSuccess, result = pcall(function()
            item.CFrame = newCFrame
        end)
        
        if pcallSuccess then
            success = true
            print("PlacementManager: Rotated part", item.Name, "to", angleDegrees, "degrees")
        else
            warn("PlacementManager: Error rotating part:", result)
        end
    else
        warn("PlacementManager: Unknown item type for rotation:", item.ClassName)
    end
    
    return success
end

-- Helper: Apply rotation to an item (client-side for previews) - Multi-axis support
function PlacementManager:_ApplyRotationToItem(item, angleDegrees)
    if RunService:IsServer() then return end
    if not item then return end
    
    -- For backward compatibility, if only one angle is provided, apply it to Y-axis
    local rotationX = self.currentPlacementRotationX or 0
    local rotationY = angleDegrees or self.currentPlacementRotationY or self.currentPlacementRotation or 0
    local rotationZ = self.currentPlacementRotationZ or 0
    
    self:_ApplyMultiAxisRotation(item, rotationX, rotationY, rotationZ)
end

-- Helper: Apply multi-axis rotation to an item
function PlacementManager:_ApplyMultiAxisRotation(item, rotationX, rotationY, rotationZ)
    if RunService:IsServer() then return end
    if not item then return end
    
    local rotationXRad = math.rad(rotationX or 0)
    local rotationYRad = math.rad(rotationY or 0) 
    local rotationZRad = math.rad(rotationZ or 0)
    
    if item:IsA("Model") and item.PrimaryPart then
        local currentPosition = item.PrimaryPart.Position
        -- Apply rotation around all three axes (X=Pitch, Y=Yaw, Z=Roll)
        local newCFrame = CFrame.new(currentPosition) * CFrame.Angles(rotationXRad, rotationYRad, rotationZRad)
        item:SetPrimaryPartCFrame(newCFrame)
    elseif item:IsA("BasePart") then
        local currentPosition = item.Position
        -- Apply rotation around all three axes (X=Pitch, Y=Yaw, Z=Roll)
        local newCFrame = CFrame.new(currentPosition) * CFrame.Angles(rotationXRad, rotationYRad, rotationZRad)
        item.CFrame = newCFrame
    end
    
    print("🔄 Applied multi-axis rotation: X=" .. rotationX .. "°, Y=" .. rotationY .. "°, Z=" .. rotationZ .. "° to", item.Name)
end

-- Private: Direct rotation during placement (no UI) - Backward compatibility
function PlacementManager:_DirectRotate(degrees)
    if RunService:IsServer() then return end
    if not self.isPlacing or not self.previewItem then return end
    
    -- Update Y-axis rotation for backward compatibility
    self:_DirectRotateAxis("Y", degrees)
end

-- Private: Direct rotation on specific axis during placement (no UI)
function PlacementManager:_DirectRotateAxis(axis, degrees)
    if RunService:IsServer() then return end
    if not self.isPlacing or not self.previewItem then return end
    
    -- Update rotation for specified axis
    if axis == "X" then
        self.currentPlacementRotationX = (self.currentPlacementRotationX or 0) + degrees
        -- Normalize to -360 to 360 range for pitch
        while self.currentPlacementRotationX >= 360 do
            self.currentPlacementRotationX = self.currentPlacementRotationX - 360
        end
        while self.currentPlacementRotationX < -360 do
            self.currentPlacementRotationX = self.currentPlacementRotationX + 360
        end
    elseif axis == "Y" then
        self.currentPlacementRotationY = (self.currentPlacementRotationY or 0) + degrees
        self.currentPlacementRotation = self.currentPlacementRotationY -- Backward compatibility
        -- Normalize to 0-360 range for yaw
        while self.currentPlacementRotationY >= 360 do
            self.currentPlacementRotationY = self.currentPlacementRotationY - 360
        end
        while self.currentPlacementRotationY < 0 do
            self.currentPlacementRotationY = self.currentPlacementRotationY + 360
        end
        self.currentPlacementRotation = self.currentPlacementRotationY
    elseif axis == "Z" then
        self.currentPlacementRotationZ = (self.currentPlacementRotationZ or 0) + degrees
        -- Normalize to -360 to 360 range for roll
        while self.currentPlacementRotationZ >= 360 do
            self.currentPlacementRotationZ = self.currentPlacementRotationZ - 360
        end
        while self.currentPlacementRotationZ < -360 do
            self.currentPlacementRotationZ = self.currentPlacementRotationZ + 360
        end
    end
    
    -- Apply rotation to preview item
    self:_ApplyMultiAxisRotation(self.previewItem, 
        self.currentPlacementRotationX or 0,
        self.currentPlacementRotationY or 0, 
        self.currentPlacementRotationZ or 0)
    
    print("🔄 Direct " .. axis .. "-axis rotation:", degrees, "degrees (Total: X=" .. (self.currentPlacementRotationX or 0) .. "°, Y=" .. (self.currentPlacementRotationY or 0) .. "°, Z=" .. (self.currentPlacementRotationZ or 0) .. "°)")
end

-- Private: Show rotation UI for current preview item (fine control)
function PlacementManager:_ShowRotationUI()
    if RunService:IsServer() then return end
    if not self.isPlacing or not self.previewItem then return end
    
    print("🔄 PlacementManager: Showing fine rotation UI for preview item")
    
    local onRotationChanged = function(item, rotation)
        -- Apply rotation to preview item in real-time
        self:_ApplyRotationToItem(item, rotation)
        self.currentPlacementRotation = rotation
    end
    
    local onConfirm = function(item, finalRotation)
        print("✅ PlacementManager: Rotation confirmed at", finalRotation, "degrees")
        self.currentPlacementRotation = finalRotation
        -- Continue with placement after rotation is confirmed
    end
    
    local onCancel = function(item)
        print("❌ PlacementManager: Rotation cancelled")
        local originalRotation = self.currentPlacementRotation or 0
        -- Reset item to current rotation (not 0)
        if item then
            self:_ApplyRotationToItem(item, originalRotation)
        end
    end
    
    -- Show the simple rotation UI
    if self.simpleRotationUI then
        self.simpleRotationUI:Show(self.previewItem, onRotationChanged, onConfirm, onCancel)
    end
end

return PlacementManager
