-- ConflictResolver.luau
-- System to handle conflicts between player placements and development plans

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local ConflictResolver = {}
ConflictResolver.__index = ConflictResolver

function ConflictResolver.new(placementTracker, gameManager)
    local self = setmetatable({}, ConflictResolver)
    
    self.placementTracker = placementTracker
    self.gameManager = gameManager
    self.compensationRates = {
        BASIC = 1.0,      -- 100% refund
        LEVEL_1 = 1.1,    -- 110% refund (bonus for inconvenience)
        LEVEL_2 = 1.2,    -- 120% refund
        RARE = 1.5,       -- 150% refund
        EXCLUSIVE = 2.0   -- 200% refund
    }
    
    return self
end

-- Strategy 1: Object Relocation
function ConflictResolver:RelocateObject(placementId, conflictReason)
    local placement = self.placementTracker.placedObjects[placementId]
    if not placement then
        warn("Cannot relocate: Placement not found:", placementId)
        return false
    end
    
    -- Find the actual object in workspace
    local objectInstance = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:GetAttribute("PlacementId") == placementId then
            objectInstance = obj
            break
        end
    end
    
    if not objectInstance then
        warn("Cannot relocate: Object not found in workspace:", placementId)
        return false
    end
    
    -- Find nearest safe position
    local originalPos = Vector3.new(placement.Position.X, placement.Position.Y, placement.Position.Z)
    local newPosition = self:FindNearestSafePosition(originalPos, objectInstance.Size)
    
    if newPosition then
        -- Move the object
        objectInstance.Position = newPosition
        
        -- Update tracking data
        placement.Position = {X = newPosition.X, Y = newPosition.Y, Z = newPosition.Z}
        placement.DateRelocated = os.date("%Y-%m-%d %H:%M:%S")
        placement.RelocationReason = conflictReason
        
        -- Update grid occupancy
        self.placementTracker:TrackPlacement(
            Players:GetPlayerByUserId(placement.PlayerId) or {UserId = placement.PlayerId, Name = placement.PlayerName},
            objectInstance,
            {ItemId = placement.ItemId, Name = placement.ItemName}
        )
        
        -- Notify player
        self:NotifyPlayerOfRelocation(placement.PlayerId, placement.ItemName, originalPos, newPosition, conflictReason)
        
        print("✅ Relocated object:", placement.ItemName, "from", originalPos, "to", newPosition)
        return true
    else
        warn("❌ Could not find safe relocation position for:", placement.ItemName)
        return false
    end
end

-- Strategy 2: Player Compensation
function ConflictResolver:CompensatePlayer(placementId, compensationType)
    local placement = self.placementTracker.placedObjects[placementId]
    if not placement then
        warn("Cannot compensate: Placement not found:", placementId)
        return false
    end
    
    -- Calculate compensation amount
    local baseValue = self:GetItemValue(placement.ItemName, placement.ItemId)
    local tier = self:GetItemTier(placement.ItemName)
    local multiplier = self.compensationRates[tier] or 1.0
    
    local compensationAmount = math.floor(baseValue * multiplier)
    
    -- Additional compensation based on how long they owned it
    local daysOwned = math.floor((os.time() - placement.Timestamp) / 86400)
    local timeBonus = math.min(daysOwned * 2, 50) -- Up to 50 coin bonus for long ownership
    
    local totalCompensation = compensationAmount + timeBonus
    
    -- Give compensation to player
    local player = Players:GetPlayerByUserId(placement.PlayerId)
    if player then
        -- Player is online - give directly
        if self.gameManager and self.gameManager:GivePlayerCoins(player, totalCompensation) then
            self:NotifyPlayerOfCompensation(placement.PlayerId, placement.ItemName, totalCompensation, compensationType)
            print("💰 Compensated online player:", placement.PlayerName, totalCompensation, "coins")
            return true
        end
    else
        -- Player is offline - store compensation for next login
        self:StoreOfflineCompensation(placement.PlayerId, placement.PlayerName, placement.ItemName, totalCompensation, compensationType)
        print("📫 Stored offline compensation for:", placement.PlayerName, totalCompensation, "coins")
        return true
    end
    
    return false
end

-- Strategy 3: Protected Zone Enforcement
function ConflictResolver:EnforceProtectedZone(zoneName)
    local zone = self.placementTracker.developmentZones[zoneName]
    if not zone or not zone.active then
        warn("Cannot enforce: Zone not found or inactive:", zoneName)
        return false
    end
    
    -- Get all conflicts in this zone
    local minPoint = Vector3.new(zone.minPoint.X, zone.minPoint.Y, zone.minPoint.Z)
    local maxPoint = Vector3.new(zone.maxPoint.X, zone.maxPoint.Y, zone.maxPoint.Z)
    local conflictReport = self.placementTracker:CheckDevelopmentConflicts(zoneName, minPoint, maxPoint)
    
    print("🚧 Enforcing protected zone:", zoneName)
    print("   Found", conflictReport.totalConflicts, "conflicting objects")
    
    local resolvedCount = 0
    local compensatedCount = 0
    local failedCount = 0
    
    for _, conflict in ipairs(conflictReport.conflicts) do
        -- Try relocation first
        if self:RelocateObject(conflict.placementId, "Development zone enforcement: " .. zone.plannedFeature) then
            resolvedCount = resolvedCount + 1
        else
            -- If relocation fails, compensate and remove
            if self:CompensatePlayer(conflict.placementId, "Removal for development") then
                -- Remove the object
                self:RemoveObject(conflict.placementId)
                compensatedCount = compensatedCount + 1
            else
                failedCount = failedCount + 1
            end
        end
    end
    
    print("📊 Zone enforcement complete:")
    print("   Relocated:", resolvedCount)
    print("   Compensated & Removed:", compensatedCount)
    print("   Failed:", failedCount)
    
    return {
        total = conflictReport.totalConflicts,
        relocated = resolvedCount,
        compensated = compensatedCount,
        failed = failedCount
    }
end

-- Find nearest safe position for relocation
function ConflictResolver:FindNearestSafePosition(originalPosition, objectSize)
    local searchRadius = 50 -- Start with 50 stud radius
    local maxRadius = 200   -- Max search radius
    local stepSize = 10     -- Increment radius by this amount
    
    while searchRadius <= maxRadius do
        -- Try positions in a circle around the original
        for angle = 0, 360, 30 do -- Check every 30 degrees
            local radians = math.rad(angle)
            local testPosition = Vector3.new(
                originalPosition.X + math.cos(radians) * searchRadius,
                originalPosition.Y,
                originalPosition.Z + math.sin(radians) * searchRadius
            )
            
            if self:IsPositionSafe(testPosition, objectSize) then
                return testPosition
            end
        end
        
        searchRadius = searchRadius + stepSize
    end
    
    return nil -- No safe position found
end

-- Check if a position is safe for relocation
function ConflictResolver:IsPositionSafe(position, objectSize)
    -- Check if position is in any development zone
    local inZone, zoneName = self.placementTracker:IsInDevelopmentZone(position)
    if inZone then
        return false
    end
    
    -- Check for conflicts with existing objects
    local buffer = 5 -- 5 stud buffer around objects
    local checkMin = Vector3.new(
        position.X - objectSize.X/2 - buffer,
        position.Y - objectSize.Y/2,
        position.Z - objectSize.Z/2 - buffer
    )
    local checkMax = Vector3.new(
        position.X + objectSize.X/2 + buffer,
        position.Y + objectSize.Y/2,
        position.Z + objectSize.Z/2 + buffer
    )
    
    local conflicts = self.placementTracker:GetObjectsInRegion(checkMin, checkMax)
    return #conflicts == 0
end

-- Remove an object from the game
function ConflictResolver:RemoveObject(placementId)
    local placement = self.placementTracker.placedObjects[placementId]
    if not placement then return false end
    
    -- Find and remove the actual object
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:GetAttribute("PlacementId") == placementId then
            obj:Destroy()
            break
        end
    end
    
    -- Remove from tracking
    self.placementTracker.placedObjects[placementId] = nil
    
    print("🗑️ Removed object:", placement.ItemName, "placed by", placement.PlayerName)
    return true
end

-- Get item value for compensation calculation
function ConflictResolver:GetItemValue(itemName, itemId)
    -- This would integrate with your pricing system
    -- For now, return a default based on item name
    local lowerName = itemName:lower()
    
    if lowerName:find("rare") then
        return 100
    elseif lowerName:find("exclusive") then
        return 500
    elseif lowerName:find("level_2") then
        return 25
    elseif lowerName:find("level_1") then
        return 10
    else
        return 5 -- Basic items
    end
end

-- Get item tier for compensation multiplier
function ConflictResolver:GetItemTier(itemName)
    local lowerName = itemName:lower()
    
    if lowerName:find("exclusive") then return "EXCLUSIVE"
    elseif lowerName:find("rare") then return "RARE"
    elseif lowerName:find("level_2") then return "LEVEL_2"
    elseif lowerName:find("level_1") then return "LEVEL_1"
    else return "BASIC" end
end

-- Notify player of relocation
function ConflictResolver:NotifyPlayerOfRelocation(playerId, itemName, oldPos, newPos, reason)
    local player = Players:GetPlayerByUserId(playerId)
    if player then
        -- Send notification to player (you'd implement your notification system here)
        print("📬 Notifying player", player.Name, "of relocation:", itemName)
        
        -- Example: Send remote event to client for UI notification
        -- local notifyEvent = ReplicatedStorage:FindFirstChild("NotifyPlayer")
        -- if notifyEvent then
        --     notifyEvent:FireClient(player, {
        --         type = "relocation",
        --         itemName = itemName,
        --         oldPosition = oldPos,
        --         newPosition = newPos,
        --         reason = reason
        --     })
        -- end
    end
end

-- Notify player of compensation
function ConflictResolver:NotifyPlayerOfCompensation(playerId, itemName, amount, reason)
    local player = Players:GetPlayerByUserId(playerId)
    if player then
        print("📬 Notifying player", player.Name, "of compensation:", amount, "coins for", itemName)
        
        -- Example notification implementation
        -- local notifyEvent = ReplicatedStorage:FindFirstChild("NotifyPlayer")
        -- if notifyEvent then
        --     notifyEvent:FireClient(player, {
        --         type = "compensation",
        --         itemName = itemName,
        --         amount = amount,
        --         reason = reason
        --     })
        -- end
    end
end

-- Store compensation for offline players
function ConflictResolver:StoreOfflineCompensation(playerId, playerName, itemName, amount, reason)
    -- This would integrate with your player data system
    -- For now, just log it
    print("📫 Offline compensation queued:")
    print("   Player:", playerName, "(", playerId, ")")
    print("   Item:", itemName)
    print("   Amount:", amount, "coins")
    print("   Reason:", reason)
    
    -- In a real implementation, you'd save this to a DataStore
    -- to be retrieved when the player next logs in
end

return ConflictResolver 