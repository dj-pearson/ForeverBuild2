-- BlueprintManager.luau
-- Comprehensive blueprint system for saving, sharing, and loading building designs

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local BlueprintManager = {}
BlueprintManager.__index = BlueprintManager

-- Blueprint system configuration
local BLUEPRINT_CONFIG = {
    MAX_BLUEPRINT_SIZE = 100, -- Maximum number of items in a blueprint
    MAX_BLUEPRINT_DIMENSION = 200, -- Maximum dimension in any axis (studs)
    COMPRESSION_ENABLED = true,
    BLUEPRINT_FORMAT_VERSION = "1.0",
    
    -- Blueprint categories
    CATEGORIES = {
        BUILDINGS = "buildings",
        DECORATIONS = "decorations", 
        VEHICLES = "vehicles",
        FURNITURE = "furniture",
        LANDSCAPES = "landscapes",
        CONTRAPTIONS = "contraptions",
        OTHER = "other"
    },
    
    -- Sharing permissions
    SHARING = {
        PRIVATE = "private", -- Only creator can access
        FRIENDS = "friends", -- Creator and friends
        GUILD = "guild", -- Guild members only
        PUBLIC = "public" -- Everyone can access
    },
    
    -- Blueprint quality ratings
    QUALITY = {
        DRAFT = 1,
        GOOD = 2,
        GREAT = 3,
        EXCELLENT = 4,
        MASTERPIECE = 5
    }
}

function BlueprintManager.new()
    local self = setmetatable({}, BlueprintManager)
    
    if IS_SERVER then
        -- Server-side data
        self.blueprints = {} -- All blueprints by ID
        self.playerBlueprints = {} -- Player's blueprints by userId
        self.publicBlueprints = {} -- Public blueprints
        self.featuredBlueprints = {} -- Featured/promoted blueprints
        self.blueprintCategories = {} -- Blueprints organized by category
        self.connections = {}
        
        -- Blueprint marketplace data
        self.blueprintMarketplace = {
            featured = {},
            trending = {},
            recent = {},
            popular = {}
        }
        
    elseif IS_CLIENT then
        -- Client-side data
        self.localBlueprints = {} -- Player's local blueprints
        self.downloadedBlueprints = {} -- Downloaded public blueprints
        self.blueprintPreview = nil -- Current blueprint being previewed
        self.isPlacingBlueprint = false
        self.previewModels = {}
        self.connections = {}
    end
    
    return self
end

-- Initialize the blueprint system
function BlueprintManager:Initialize()
    if IS_SERVER then
        self:SetupServerSide()
        print("BlueprintManager: Server initialized")
    elseif IS_CLIENT then
        self:SetupClientSide()
        print("BlueprintManager: Client initialized")
    end
end

-- Server-side setup
function BlueprintManager:SetupServerSide()
    -- Set up remote events
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    -- Create blueprint remote events
    self:CreateRemoteEvents(remotes)
    
    -- Track player connections
    self.connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerBlueprints(player)
    end)
    
    self.connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerBlueprints(player)
    end)
    
    -- Initialize existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:InitializePlayerBlueprints(player)
    end
end

-- Create remote events for blueprint features
function BlueprintManager:CreateRemoteEvents(remotes)
    local remoteEvents = {
        -- Blueprint creation and management
        "CreateBlueprint",
        "SaveBlueprint", 
        "LoadBlueprint",
        "DeleteBlueprint",
        "UpdateBlueprintMetadata",
        
        -- Blueprint sharing
        "ShareBlueprint",
        "GetSharedBlueprints",
        "DownloadBlueprint",
        "RateBlueprint",
        "CommentOnBlueprint",
        
        -- Blueprint marketplace
        "GetFeaturedBlueprints",
        "GetBlueprintsByCategory",
        "SearchBlueprints",
        "GetPlayerBlueprints",
        
        -- Blueprint placement
        "PreviewBlueprint",
        "PlaceBlueprint",
        "CancelBlueprintPlacement",
        
        -- General updates
        "UpdateBlueprintData",
        "RequestBlueprintInfo"
    }
    
    for _, eventName in ipairs(remoteEvents) do
        if not remotes:FindFirstChild(eventName) then
            local remoteEvent = Instance.new("RemoteEvent")
            remoteEvent.Name = eventName
            remoteEvent.Parent = remotes
            
            -- Connect to appropriate handler
            remoteEvent.OnServerEvent:Connect(function(player, ...)
                self:HandleRemoteEvent(eventName, player, ...)
            end)
        end
    end
    
    -- Request function for getting blueprint data
    if not remotes:FindFirstChild("GetBlueprintData") then
        local requestFunc = Instance.new("RemoteFunction")
        requestFunc.Name = "GetBlueprintData"
        requestFunc.Parent = remotes
        
        requestFunc.OnServerInvoke = function(player, dataType, ...)
            return self:GetBlueprintData(player, dataType, ...)
        end
    end
end

-- Client-side setup
function BlueprintManager:SetupClientSide()
    -- Connect to blueprint updates
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    
    local updateEvent = remotes:WaitForChild("UpdateBlueprintData")
    self.connections.updateReceived = updateEvent.OnClientEvent:Connect(function(blueprintData)
        self:ProcessBlueprintUpdate(blueprintData)
    end)
    
    -- Request initial blueprint data
    task.wait(1)
    self:RequestBlueprintData()
end

-- Handle remote events
function BlueprintManager:HandleRemoteEvent(eventName, player, ...)
    local args = {...}
    
    if eventName == "CreateBlueprint" then
        self:CreateBlueprintFromSelection(player, args[1], args[2], args[3]) -- name, category, metadata
    elseif eventName == "SaveBlueprint" then
        self:SaveBlueprint(player, args[1]) -- blueprintData
    elseif eventName == "LoadBlueprint" then
        self:LoadBlueprint(player, args[1]) -- blueprintId
    elseif eventName == "DeleteBlueprint" then
        self:DeleteBlueprint(player, args[1]) -- blueprintId
    elseif eventName == "ShareBlueprint" then
        self:ShareBlueprint(player, args[1], args[2]) -- blueprintId, shareLevel
    elseif eventName == "PlaceBlueprint" then
        self:PlaceBlueprint(player, args[1], args[2], args[3]) -- blueprintId, position, rotation
    elseif eventName == "RateBlueprint" then
        self:RateBlueprint(player, args[1], args[2]) -- blueprintId, rating
    -- Add more event handlers as needed
    end
end

-- Blueprint Creation System
function BlueprintManager:CreateBlueprintFromSelection(player, name, category, metadata)
    if not IS_SERVER then return end
    
    -- Get BuildingToolsManager to access selected items
    local buildingTools = _G.ForeverBuildSystems and _G.ForeverBuildSystems.BuildingToolsManager
    if not buildingTools then
        self:SendError(player, "Building tools not available")
        return
    end
    
    -- This would need to be adapted to work with server-side selection
    -- For now, we'll assume we receive the selected items data directly
    local selectedItems = metadata.selectedItems or {}
    
    if #selectedItems == 0 then
        self:SendError(player, "No items selected for blueprint")
        return
    end
    
    if #selectedItems > BLUEPRINT_CONFIG.MAX_BLUEPRINT_SIZE then
        self:SendError(player, "Too many items selected (max " .. BLUEPRINT_CONFIG.MAX_BLUEPRINT_SIZE .. ")")
        return
    end
    
    -- Calculate blueprint center and bounds
    local blueprintData = self:ProcessSelectedItems(selectedItems)
    if not blueprintData then
        self:SendError(player, "Failed to process selected items")
        return
    end
    
    -- Create blueprint object
    local blueprint = {
        id = HttpService:GenerateGUID(false),
        name = name,
        category = category or BLUEPRINT_CONFIG.CATEGORIES.OTHER,
        creator = {
            userId = player.UserId,
            username = player.Name,
            displayName = player.DisplayName
        },
        created = os.time(),
        modified = os.time(),
        version = BLUEPRINT_CONFIG.BLUEPRINT_FORMAT_VERSION,
        
        -- Blueprint data
        items = blueprintData.items,
        bounds = blueprintData.bounds,
        center = blueprintData.center,
        itemCount = #blueprintData.items,
        
        -- Metadata
        description = metadata.description or "",
        tags = metadata.tags or {},
        difficulty = metadata.difficulty or "medium",
        estimatedTime = metadata.estimatedTime or "unknown",
        
        -- Sharing and rating
        shareLevel = BLUEPRINT_CONFIG.SHARING.PRIVATE,
        rating = 0,
        ratingCount = 0,
        downloadCount = 0,
        
        -- Requirements
        requiredItems = blueprintData.requiredItems,
        totalCost = blueprintData.totalCost
    }
    
    -- Validate blueprint size
    if not self:ValidateBlueprintSize(blueprint) then
        self:SendError(player, "Blueprint exceeds maximum size limits")
        return
    end
    
    -- Store blueprint
    self.blueprints[blueprint.id] = blueprint
    
    -- Add to player's blueprints
    if not self.playerBlueprints[player.UserId] then
        self.playerBlueprints[player.UserId] = {}
    end
    table.insert(self.playerBlueprints[player.UserId], blueprint.id)
    
    -- Award XP for blueprint creation
    self:AwardBlueprintXP(player, "blueprint_created", 25)
    
    -- Send success response
    self:SendBlueprintUpdate(player, "BlueprintCreated", blueprint)
    
    print("BlueprintManager: Created blueprint", blueprint.name, "by", player.Name)
    return blueprint
end

-- Process selected items into blueprint data
function BlueprintManager:ProcessSelectedItems(selectedItems)
    local items = {}
    local requiredItems = {}
    local totalCost = 0
    
    -- Calculate center position
    local centerPosition = Vector3.new(0, 0, 0)
    local validItems = 0
    
    for _, item in ipairs(selectedItems) do
        if item and item.Position then
            centerPosition = centerPosition + item.Position
            validItems = validItems + 1
        end
    end
    
    if validItems == 0 then return nil end
    centerPosition = centerPosition / validItems
    
    -- Calculate bounds
    local minBounds = Vector3.new(math.huge, math.huge, math.huge)
    local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)
    
    -- Process each item
    for _, item in ipairs(selectedItems) do
        if item and item:IsA("BasePart") then
            -- Store item data relative to center
            local itemData = {
                className = item.ClassName,
                name = item.Name,
                size = item.Size,
                material = item.Material.Name,
                color = {item.Color.R, item.Color.G, item.Color.B},
                transparency = item.Transparency,
                canCollide = item.CanCollide,
                shape = item.Shape and item.Shape.Name or "Block",
                
                -- Position relative to center
                relativePosition = item.Position - centerPosition,
                rotation = {item.Rotation.X, item.Rotation.Y, item.Rotation.Z},
                
                -- Item identification
                itemId = item:GetAttribute("itemId") or "unknown",
                instanceId = item:GetAttribute("instanceId"),
                
                -- Custom attributes
                attributes = {}
            }
            
            -- Copy custom attributes
            for _, attribute in ipairs(item:GetAttributes()) do
                if attribute ~= "itemId" and attribute ~= "instanceId" then
                    itemData.attributes[attribute] = item:GetAttribute(attribute)
                end
            end
            
            table.insert(items, itemData)
            
            -- Track required items
            local itemId = itemData.itemId
            if not requiredItems[itemId] then
                requiredItems[itemId] = 0
            end
            requiredItems[itemId] = requiredItems[itemId] + 1
            
            -- Calculate bounds
            local itemMin = item.Position - item.Size/2
            local itemMax = item.Position + item.Size/2
            
            minBounds = Vector3.new(
                math.min(minBounds.X, itemMin.X),
                math.min(minBounds.Y, itemMin.Y),
                math.min(minBounds.Z, itemMin.Z)
            )
            maxBounds = Vector3.new(
                math.max(maxBounds.X, itemMax.X),
                math.max(maxBounds.Y, itemMax.Y),
                math.max(maxBounds.Z, itemMax.Z)
            )
        end
    end
    
    return {
        items = items,
        center = centerPosition,
        bounds = {
            min = minBounds,
            max = maxBounds,
            size = maxBounds - minBounds
        },
        requiredItems = requiredItems,
        totalCost = totalCost
    }
end

-- Validate blueprint size constraints
function BlueprintManager:ValidateBlueprintSize(blueprint)
    if blueprint.itemCount > BLUEPRINT_CONFIG.MAX_BLUEPRINT_SIZE then
        return false
    end
    
    local size = blueprint.bounds.size
    if size.X > BLUEPRINT_CONFIG.MAX_BLUEPRINT_DIMENSION or
       size.Y > BLUEPRINT_CONFIG.MAX_BLUEPRINT_DIMENSION or
       size.Z > BLUEPRINT_CONFIG.MAX_BLUEPRINT_DIMENSION then
        return false
    end
    
    return true
end

-- Blueprint Placement System
function BlueprintManager:PlaceBlueprint(player, blueprintId, position, rotation)
    if not IS_SERVER then return end
    
    local blueprint = self.blueprints[blueprintId]
    if not blueprint then
        self:SendError(player, "Blueprint not found")
        return
    end
    
    -- Check if player has required items
    if not self:CheckRequiredItems(player, blueprint) then
        self:SendError(player, "Insufficient items to place blueprint")
        return
    end
    
    -- Validate placement position
    if not self:ValidatePlacementPosition(position, blueprint) then
        self:SendError(player, "Invalid placement position")
        return
    end
    
    local placedItems = {}
    local rotationCFrame = CFrame.Angles(rotation.X or 0, rotation.Y or 0, rotation.Z or 0)
    
    -- Place each item in the blueprint
    for _, itemData in ipairs(blueprint.items) do
        local worldPosition = position + rotationCFrame * itemData.relativePosition
        local worldRotation = Vector3.new(
            (itemData.rotation[1] or 0) + (rotation.X or 0),
            (itemData.rotation[2] or 0) + (rotation.Y or 0),
            (itemData.rotation[3] or 0) + (rotation.Z or 0)
        )
        
        local placedItem = self:CreateItemFromBlueprintData(itemData, worldPosition, worldRotation)
        if placedItem then
            -- Set ownership and blueprint metadata
            placedItem:SetAttribute("blueprintId", blueprintId)
            placedItem:SetAttribute("blueprintPart", true)
            placedItem:SetAttribute("owner", player.UserId)
            
            table.insert(placedItems, placedItem)
        end
    end
    
    -- Remove items from inventory
    self:ConsumeRequiredItems(player, blueprint)
    
    -- Award XP for blueprint placement
    self:AwardBlueprintXP(player, "blueprint_placed", 15)
    
    -- Update blueprint statistics
    blueprint.downloadCount = (blueprint.downloadCount or 0) + 1
    
    -- Send success response
    self:SendBlueprintUpdate(player, "BlueprintPlaced", {
        blueprintId = blueprintId,
        itemsPlaced = #placedItems,
        position = position
    })
    
    print("BlueprintManager: Placed blueprint", blueprint.name, "for", player.Name)
    return placedItems
end

-- Create item from blueprint data
function BlueprintManager:CreateItemFromBlueprintData(itemData, position, rotation)
    local success, item = pcall(function()
        local newItem = Instance.new(itemData.className)
        
        if newItem:IsA("BasePart") then
            newItem.Size = itemData.size
            newItem.Material = Enum.Material[itemData.material] or Enum.Material.Plastic
            newItem.Color = Color3.new(itemData.color[1], itemData.color[2], itemData.color[3])
            newItem.Transparency = itemData.transparency or 0
            newItem.CanCollide = itemData.canCollide
            newItem.Shape = Enum.PartType[itemData.shape] or Enum.PartType.Block
            newItem.Anchored = true
            
            -- Set position and rotation
            newItem.Position = position
            newItem.Rotation = rotation
            
            -- Apply custom attributes
            for attrName, attrValue in pairs(itemData.attributes) do
                newItem:SetAttribute(attrName, attrValue)
            end
            
            -- Set item identification
            newItem:SetAttribute("itemId", itemData.itemId)
            newItem.Name = itemData.name or (itemData.itemId .. "_blueprint")
            
            newItem.Parent = workspace:FindFirstChild("World_Items") or workspace
        end
        
        return newItem
    end)
    
    if success then
        return item
    else
        warn("BlueprintManager: Failed to create item from blueprint data:", itemData.className)
        return nil
    end
end

-- Blueprint Sharing System
function BlueprintManager:ShareBlueprint(player, blueprintId, shareLevel)
    if not IS_SERVER then return end
    
    local blueprint = self.blueprints[blueprintId]
    if not blueprint then
        self:SendError(player, "Blueprint not found")
        return
    end
    
    -- Check ownership
    if blueprint.creator.userId ~= player.UserId then
        self:SendError(player, "You don't own this blueprint")
        return
    end
    
    -- Update share level
    blueprint.shareLevel = shareLevel
    blueprint.modified = os.time()
    
    -- Add to public blueprints if public
    if shareLevel == BLUEPRINT_CONFIG.SHARING.PUBLIC then
        self.publicBlueprints[blueprintId] = blueprint
        
        -- Award XP for sharing
        self:AwardBlueprintXP(player, "blueprint_shared", 10)
    else
        -- Remove from public if changing from public
        self.publicBlueprints[blueprintId] = nil
    end
    
    -- Organize by category
    local category = blueprint.category
    if not self.blueprintCategories[category] then
        self.blueprintCategories[category] = {}
    end
    
    if shareLevel == BLUEPRINT_CONFIG.SHARING.PUBLIC then
        self.blueprintCategories[category][blueprintId] = blueprint
    else
        self.blueprintCategories[category][blueprintId] = nil
    end
    
    self:SendBlueprintUpdate(player, "BlueprintShared", {
        blueprintId = blueprintId,
        shareLevel = shareLevel
    })
    
    print("BlueprintManager: Blueprint", blueprint.name, "shared at level", shareLevel)
end

-- Blueprint marketplace and discovery
function BlueprintManager:GetFeaturedBlueprints()
    local featured = {}
    
    -- Get top-rated public blueprints
    local sortedBlueprints = {}
    for id, blueprint in pairs(self.publicBlueprints) do
        table.insert(sortedBlueprints, blueprint)
    end
    
    table.sort(sortedBlueprints, function(a, b)
        return (a.rating or 0) > (b.rating or 0)
    end)
    
    -- Take top 10
    for i = 1, math.min(10, #sortedBlueprints) do
        table.insert(featured, sortedBlueprints[i])
    end
    
    return featured
end

function BlueprintManager:SearchBlueprints(query, category, sortBy)
    local results = {}
    
    for id, blueprint in pairs(self.publicBlueprints) do
        local matches = false
        
        -- Check name match
        if blueprint.name:lower():find(query:lower()) then
            matches = true
        end
        
        -- Check description match
        if blueprint.description:lower():find(query:lower()) then
            matches = true
        end
        
        -- Check tags match
        for _, tag in ipairs(blueprint.tags) do
            if tag:lower():find(query:lower()) then
                matches = true
                break
            end
        end
        
        -- Check category filter
        if category and blueprint.category ~= category then
            matches = false
        end
        
        if matches then
            table.insert(results, blueprint)
        end
    end
    
    -- Sort results
    if sortBy == "rating" then
        table.sort(results, function(a, b) return (a.rating or 0) > (b.rating or 0) end)
    elseif sortBy == "downloads" then
        table.sort(results, function(a, b) return (a.downloadCount or 0) > (b.downloadCount or 0) end)
    elseif sortBy == "recent" then
        table.sort(results, function(a, b) return (a.created or 0) > (b.created or 0) end)
    end
    
    return results
end

-- Helper functions
function BlueprintManager:CheckRequiredItems(player, blueprint)
    -- Get player inventory
    local playerData = self:GetPlayerInventory(player)
    if not playerData or not playerData.inventory then
        return false
    end
    
    -- Check each required item
    for itemId, requiredCount in pairs(blueprint.requiredItems) do
        local hasCount = 0
        
        for _, item in ipairs(playerData.inventory) do
            if item.id == itemId or item.name == itemId then
                hasCount = hasCount + (item.count or item.quantity or 1)
            end
        end
        
        if hasCount < requiredCount then
            return false
        end
    end
    
    return true
end

function BlueprintManager:GetPlayerInventory(player)
    -- Integration with existing inventory system
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.InventoryManager then
        local inventoryManager = _G.ForeverBuildSystems.InventoryManager
        return inventoryManager:GetPlayerData(player)
    end
    
    -- Fallback implementation
    return nil
end

function BlueprintManager:ConsumeRequiredItems(player, blueprint)
    -- Integration with existing inventory system to remove items
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.PlacementManager then
        local placementManager = _G.ForeverBuildSystems.PlacementManager
        
        for itemId, count in pairs(blueprint.requiredItems) do
            placementManager:RemoveFromInventory(player, itemId, count)
        end
    end
end

function BlueprintManager:AwardBlueprintXP(player, source, amount)
    -- Integration with XP system
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.XPManager then
        local xpManager = _G.ForeverBuildSystems.XPManager
        xpManager:AwardXP(player, amount, "blueprint_" .. source)
    end
end

function BlueprintManager:ValidatePlacementPosition(position, blueprint)
    -- Basic validation - check if area is clear
    local size = blueprint.bounds.size
    local region = Region3.new(
        position - size/2,
        position + size/2
    )
    
    -- Expand region slightly to avoid floating point errors
    region = region:ExpandToGrid(4)
    
    -- Check if area is relatively clear
    local parts = workspace:ReadVoxels(region, 4)
    -- This is a simplified check - in practice you'd want more sophisticated collision detection
    
    return true -- For now, allow all placements
end

-- Communication utilities
function BlueprintManager:SendError(player, message)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateEvent = remotes:FindFirstChild("UpdateBlueprintData")
        if updateEvent then
            updateEvent:FireClient(player, {
                Type = "Error",
                Message = message
            })
        end
    end
end

function BlueprintManager:SendBlueprintUpdate(player, eventType, data)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateEvent = remotes:FindFirstChild("UpdateBlueprintData")
        if updateEvent then
            updateEvent:FireClient(player, {
                Type = eventType,
                Data = data
            })
        end
    end
end

-- Get blueprint data for client requests
function BlueprintManager:GetBlueprintData(player, dataType, ...)
    if not IS_SERVER then return {} end
    
    local args = {...}
    
    if dataType == "playerBlueprints" then
        local playerBlueprints = {}
        local playerIds = self.playerBlueprints[player.UserId] or {}
        
        for _, blueprintId in ipairs(playerIds) do
            local blueprint = self.blueprints[blueprintId]
            if blueprint then
                table.insert(playerBlueprints, blueprint)
            end
        end
        
        return playerBlueprints
        
    elseif dataType == "publicBlueprints" then
        local publicList = {}
        for id, blueprint in pairs(self.publicBlueprints) do
            table.insert(publicList, blueprint)
        end
        return publicList
        
    elseif dataType == "featuredBlueprints" then
        return self:GetFeaturedBlueprints()
        
    elseif dataType == "categoryBlueprints" then
        local category = args[1]
        return self.blueprintCategories[category] or {}
        
    elseif dataType == "searchBlueprints" then
        local query, category, sortBy = args[1], args[2], args[3]
        return self:SearchBlueprints(query, category, sortBy)
    end
    
    return {}
end

-- Client-side functions
function BlueprintManager:ProcessBlueprintUpdate(blueprintData)
    if not IS_CLIENT then return end
    
    -- Update local data and UI
    if blueprintData.Type == "BlueprintCreated" then
        self:AddLocalBlueprint(blueprintData.Data)
    elseif blueprintData.Type == "BlueprintPlaced" then
        self:OnBlueprintPlaced(blueprintData.Data)
    elseif blueprintData.Type == "Error" then
        self:ShowError(blueprintData.Message)
    end
    
    -- Update UI if available
    if self.ui then
        self.ui:UpdateBlueprintData(blueprintData)
    end
end

function BlueprintManager:AddLocalBlueprint(blueprint)
    if not IS_CLIENT then return end
    
    table.insert(self.localBlueprints, blueprint)
    print("BlueprintManager: Added local blueprint:", blueprint.name)
end

function BlueprintManager:ShowError(message)
    if not IS_CLIENT then return end
    
    -- Show error notification
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.SocialManager then
        local socialManager = _G.ForeverBuildSystems.SocialManager
        if socialManager.ShowNotification then
            socialManager.ShowNotification("Blueprint Error", message, "error")
        end
    end
end

function BlueprintManager:RequestBlueprintData()
    if not IS_CLIENT then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local requestFunc = remotes:FindFirstChild("GetBlueprintData")
        if requestFunc then
            -- Request different types of blueprint data
            local dataTypes = {"playerBlueprints", "featuredBlueprints"}
            for _, dataType in ipairs(dataTypes) do
                task.spawn(function()
                    local success, result = pcall(function()
                        return requestFunc:InvokeServer(dataType)
                    end)
                    
                    if success and result then
                        self:ProcessBlueprintUpdate({
                            Type = "Initial" .. dataType,
                            Data = result
                        })
                    end
                end)
            end
        end
    end
end

-- Initialize player blueprints
function BlueprintManager:InitializePlayerBlueprints(player)
    if not IS_SERVER then return end
    
    if not self.playerBlueprints[player.UserId] then
        self.playerBlueprints[player.UserId] = {}
    end
    
    print("BlueprintManager: Initialized blueprints for", player.Name)
end

-- Save player blueprints (called on disconnect)
function BlueprintManager:SavePlayerBlueprints(player)
    if not IS_SERVER then return end
    
    -- In a full implementation, this would save to DataStore
    print("BlueprintManager: Saved blueprints for", player.Name)
end

-- Cleanup
function BlueprintManager:Cleanup()
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    if self.ui then
        self.ui:Destroy()
    end
    
    print("BlueprintManager: Cleaned up")
end

return BlueprintManager 