-- PlacementTracker.luau
-- Comprehensive system to track all player-placed objects for development planning

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTracker = {}
PlacementTracker.__index = PlacementTracker

-- DataStores for different aspects of tracking
local PlacedObjectsStore = DataStoreService:GetDataStore("PlacedObjects_v2")
local RegionDataStore = DataStoreService:GetDataStore("RegionOccupancy_v1")
local DevelopmentZonesStore = DataStoreService:GetDataStore("DevelopmentZones_v1")

function PlacementTracker.new()
    local self = setmetatable({}, PlacementTracker)
    
    self.placedObjects = {} -- Runtime cache
    self.occupiedRegions = {} -- Grid-based occupancy
    self.developmentZones = {} -- Protected areas for future development
    self.gridSize = 20 -- Each grid cell is 20x20 studs
    
    self:LoadExistingPlacements()
    self:LoadDevelopmentZones()
    
    return self
end

-- Convert world position to grid coordinates
function PlacementTracker:WorldToGrid(position)
    return {
        x = math.floor(position.X / self.gridSize),
        z = math.floor(position.Z / self.gridSize)
    }
end

-- Convert grid coordinates to world position
function PlacementTracker:GridToWorld(gridX, gridZ)
    return Vector3.new(
        gridX * self.gridSize + self.gridSize/2,
        0,
        gridZ * self.gridSize + self.gridSize/2
    )
end

-- Track a newly placed object
function PlacementTracker:TrackPlacement(player, objectInstance, itemData)
    local placementId = player.UserId .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    
    local placementData = {
        PlacementId = placementId,
        PlayerId = player.UserId,
        PlayerName = player.Name,
        Position = {
            X = objectInstance.Position.X,
            Y = objectInstance.Position.Y,
            Z = objectInstance.Position.Z
        },
        Rotation = {
            X = objectInstance.Rotation.X,
            Y = objectInstance.Rotation.Y,
            Z = objectInstance.Rotation.Z
        },
        ItemId = itemData.ItemId or objectInstance:GetAttribute("ItemId"),
        ItemName = itemData.Name or objectInstance.Name,
        Size = {
            X = objectInstance.Size.X,
            Y = objectInstance.Size.Y,
            Z = objectInstance.Size.Z
        },
        Timestamp = os.time(),
        DatePlaced = os.date("%Y-%m-%d %H:%M:%S"),
        ServerVersion = "1.0" -- Track which version this was placed in
    }
    
    -- Add placement ID to the object for future reference
    objectInstance:SetAttribute("PlacementId", placementId)
    objectInstance:SetAttribute("PlacedBy", player.UserId)
    objectInstance:SetAttribute("PlacedTimestamp", os.time())
    
    -- Update runtime cache
    self.placedObjects[placementId] = placementData
    
    -- Update grid occupancy
    local gridPos = self:WorldToGrid(objectInstance.Position)
    local gridKey = gridPos.x .. "," .. gridPos.z
    if not self.occupiedRegions[gridKey] then
        self.occupiedRegions[gridKey] = {}
    end
    table.insert(self.occupiedRegions[gridKey], placementId)
    
    -- Save to DataStore
    local success, error = pcall(function()
        PlacedObjectsStore:SetAsync(placementId, placementData)
    end)
    
    if not success then
        warn("Failed to save placement data:", error)
    end
    
    print("📍 Tracked placement:", placementId, "by", player.Name, "at", objectInstance.Position)
    return placementId
end

-- Get all objects in a specific region
function PlacementTracker:GetObjectsInRegion(minPoint, maxPoint)
    local objectsInRegion = {}
    
    -- Convert region bounds to grid coordinates
    local minGrid = self:WorldToGrid(minPoint)
    local maxGrid = self:WorldToGrid(maxPoint)
    
    -- Check all grid cells in the region
    for x = minGrid.x, maxGrid.x do
        for z = minGrid.z, maxGrid.z do
            local gridKey = x .. "," .. z
            if self.occupiedRegions[gridKey] then
                for _, placementId in ipairs(self.occupiedRegions[gridKey]) do
                    local placement = self.placedObjects[placementId]
                    if placement then
                        -- Double-check if object is actually in the region
                        local pos = Vector3.new(placement.Position.X, placement.Position.Y, placement.Position.Z)
                        if pos.X >= minPoint.X and pos.X <= maxPoint.X and
                           pos.Z >= minPoint.Z and pos.Z <= maxPoint.Z then
                            table.insert(objectsInRegion, {
                                placementId = placementId,
                                data = placement,
                                worldObject = workspace:FindFirstChild(placement.ItemName) -- Try to find actual object
                            })
                        end
                    end
                end
            end
        end
    end
    
    return objectsInRegion
end

-- Check if a region conflicts with development plans
function PlacementTracker:CheckDevelopmentConflicts(regionName, minPoint, maxPoint)
    local conflicts = self:GetObjectsInRegion(minPoint, maxPoint)
    
    print("🔍 Development Conflict Check for", regionName)
    print("   Region:", minPoint, "to", maxPoint)
    print("   Objects found:", #conflicts)
    
    local conflictReport = {
        regionName = regionName,
        totalConflicts = #conflicts,
        conflicts = {},
        playerSummary = {}
    }
    
    for _, conflict in ipairs(conflicts) do
        local data = conflict.data
        local playerName = data.PlayerName
        
        -- Add to detailed conflicts
        table.insert(conflictReport.conflicts, {
            placementId = data.PlacementId,
            playerName = playerName,
            playerId = data.PlayerId,
            itemName = data.ItemName,
            position = data.Position,
            datePlaced = data.DatePlaced,
            daysSincePlaced = math.floor((os.time() - data.Timestamp) / 86400)
        })
        
        -- Update player summary
        if not conflictReport.playerSummary[playerName] then
            conflictReport.playerSummary[playerName] = {
                playerId = data.PlayerId,
                objectCount = 0,
                items = {}
            }
        end
        conflictReport.playerSummary[playerName].objectCount = conflictReport.playerSummary[playerName].objectCount + 1
        table.insert(conflictReport.playerSummary[playerName].items, data.ItemName)
    end
    
    return conflictReport
end

-- Define a development zone (protected area for future building)
function PlacementTracker:DefineDevelopmentZone(zoneName, minPoint, maxPoint, plannedFeature)
    local zoneData = {
        zoneName = zoneName,
        minPoint = {X = minPoint.X, Y = minPoint.Y, Z = minPoint.Z},
        maxPoint = {X = maxPoint.X, Y = maxPoint.Y, Z = maxPoint.Z},
        plannedFeature = plannedFeature or "Future Development",
        dateCreated = os.date("%Y-%m-%d %H:%M:%S"),
        active = true
    }
    
    self.developmentZones[zoneName] = zoneData
    
    -- Save to DataStore
    local success, error = pcall(function()
        DevelopmentZonesStore:SetAsync(zoneName, zoneData)
    end)
    
    if success then
        print("🏗️ Created development zone:", zoneName, "for", plannedFeature)
    else
        warn("Failed to save development zone:", error)
    end
    
    return zoneData
end

-- Check if placement would conflict with development zones
function PlacementTracker:IsInDevelopmentZone(position)
    for zoneName, zone in pairs(self.developmentZones) do
        if zone.active and
           position.X >= zone.minPoint.X and position.X <= zone.maxPoint.X and
           position.Z >= zone.minPoint.Z and position.Z <= zone.maxPoint.Z then
            return true, zoneName, zone.plannedFeature
        end
    end
    return false
end

-- Generate comprehensive development report
function PlacementTracker:GenerateDevelopmentReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        totalPlacements = 0,
        activeZones = 0,
        playerStats = {},
        densityMap = {},
        recommendations = {}
    }
    
    -- Count total placements and analyze by player
    for placementId, data in pairs(self.placedObjects) do
        report.totalPlacements = report.totalPlacements + 1
        
        local playerName = data.PlayerName
        if not report.playerStats[playerName] then
            report.playerStats[playerName] = {
                playerId = data.PlayerId,
                totalPlacements = 0,
                firstPlacement = data.Timestamp,
                lastPlacement = data.Timestamp,
                items = {}
            }
        end
        
        local playerStats = report.playerStats[playerName]
        playerStats.totalPlacements = playerStats.totalPlacements + 1
        playerStats.firstPlacement = math.min(playerStats.firstPlacement, data.Timestamp)
        playerStats.lastPlacement = math.max(playerStats.lastPlacement, data.Timestamp)
        
        if not playerStats.items[data.ItemName] then
            playerStats.items[data.ItemName] = 0
        end
        playerStats.items[data.ItemName] = playerStats.items[data.ItemName] + 1
    end
    
    -- Count active development zones
    for zoneName, zone in pairs(self.developmentZones) do
        if zone.active then
            report.activeZones = report.activeZones + 1
        end
    end
    
    -- Generate density map
    for gridKey, placements in pairs(self.occupiedRegions) do
        local x, z = gridKey:match("([^,]+),([^,]+)")
        local density = #placements
        if density > 0 then
            report.densityMap[gridKey] = {
                gridX = tonumber(x),
                gridZ = tonumber(z),
                objectCount = density,
                worldCenter = self:GridToWorld(tonumber(x), tonumber(z))
            }
        end
    end
    
    return report
end

-- Load existing placements from DataStore
function PlacementTracker:LoadExistingPlacements()
    print("📂 Loading existing placements...")
    
    -- In a real implementation, you'd want to paginate through the DataStore
    -- For now, we'll scan workspace for objects with placement attributes
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            local placementId = obj:GetAttribute("PlacementId")
            local playerId = obj:GetAttribute("PlacedBy")
            local timestamp = obj:GetAttribute("PlacedTimestamp")
            
            if placementId and playerId and timestamp then
                -- Reconstruct placement data from object
                local placementData = {
                    PlacementId = placementId,
                    PlayerId = playerId,
                    PlayerName = "Unknown", -- Would need to look up
                    Position = {X = obj.Position.X, Y = obj.Position.Y, Z = obj.Position.Z},
                    Rotation = {X = obj.Rotation.X, Y = obj.Rotation.Y, Z = obj.Rotation.Z},
                    ItemId = obj:GetAttribute("ItemId"),
                    ItemName = obj.Name,
                    Size = {X = obj.Size.X, Y = obj.Size.Y, Z = obj.Size.Z},
                    Timestamp = timestamp,
                    DatePlaced = os.date("%Y-%m-%d %H:%M:%S", timestamp),
                    ServerVersion = "Unknown"
                }
                
                self.placedObjects[placementId] = placementData
                
                -- Update grid occupancy
                local gridPos = self:WorldToGrid(obj.Position)
                local gridKey = gridPos.x .. "," .. gridPos.z
                if not self.occupiedRegions[gridKey] then
                    self.occupiedRegions[gridKey] = {}
                end
                table.insert(self.occupiedRegions[gridKey], placementId)
            end
        end
    end
    
    print("📊 Loaded", #self.placedObjects, "existing placements")
end

-- Load development zones from DataStore
function PlacementTracker:LoadDevelopmentZones()
    print("🏗️ Loading development zones...")
    -- Implementation would load from DevelopmentZonesStore
    -- For now, create some example zones
    
    -- Example: Reserve area for future town center
    self:DefineDevelopmentZone("TownCenter", 
        Vector3.new(-100, 0, -100), 
        Vector3.new(100, 50, 100), 
        "Town Center with shops and services")
    
    -- Example: Reserve road corridors
    self:DefineDevelopmentZone("MainRoad", 
        Vector3.new(-500, 0, -10), 
        Vector3.new(500, 10, 10), 
        "Main road connecting spawn to town")
end

return PlacementTracker 