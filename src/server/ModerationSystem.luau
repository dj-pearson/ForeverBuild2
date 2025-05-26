-- ModerationSystem.luau
-- Anti-griefing and content moderation system

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ModerationSystem = {}
ModerationSystem.__index = ModerationSystem

-- DataStores
local ModerationStore = DataStoreService:GetDataStore("ModerationData_v1")
local PlayerReportsStore = DataStoreService:GetDataStore("PlayerReports_v1")

function ModerationSystem.new(placementTracker)
    local self = setmetatable({}, ModerationSystem)
    
    self.placementTracker = placementTracker
    self.reportedObjects = {}
    self.playerViolations = {}
    self.autoModerationRules = {
        maxObjectsPerMinute = 10,  -- Rate limiting
        maxObjectsInRadius = 20,   -- Density limiting
        maxSameItemType = 5,       -- Spam prevention
        checkRadius = 50           -- Area to check for violations
    }
    
    self.violationTypes = {
        SPAM_PLACEMENT = {severity = 2, action = "warning"},
        INAPPROPRIATE_BUILD = {severity = 3, action = "remove"},
        BLOCKING_PATHS = {severity = 2, action = "relocate"},
        OFFENSIVE_ARRANGEMENT = {severity = 4, action = "ban"},
        EXPLOITING = {severity = 5, action = "ban"}
    }
    
    self:Initialize()
    return self
end

function ModerationSystem:Initialize()
    -- Load existing moderation data
    self:LoadModerationData()
    
    -- Start periodic checks
    RunService.Heartbeat:Connect(function()
        self:PerformAutoModeration()
    end)
    
    print("🛡️ Moderation system initialized")
end

-- Check placement for violations
function ModerationSystem:CheckPlacement(player, objectInstance, itemData)
    local violations = {}
    local playerPosition = objectInstance.Position
    
    -- 1. Rate limiting check
    local recentPlacements = self:GetRecentPlacements(player, 60) -- Last minute
    if #recentPlacements >= self.autoModerationRules.maxObjectsPerMinute then
        table.insert(violations, {
            type = "SPAM_PLACEMENT",
            message = "Too many objects placed in a short time",
            severity = self.violationTypes.SPAM_PLACEMENT.severity
        })
    end
    
    -- 2. Density check
    local nearbyObjects = self:GetObjectsInRadius(playerPosition, self.autoModerationRules.checkRadius)
    if #nearbyObjects >= self.autoModerationRules.maxObjectsInRadius then
        table.insert(violations, {
            type = "SPAM_PLACEMENT",
            message = "Too many objects in a small area",
            severity = self.violationTypes.SPAM_PLACEMENT.severity
        })
    end
    
    -- 3. Same item spam check
    local sameItemCount = 0
    for _, obj in ipairs(nearbyObjects) do
        if obj.Name == itemData.Name then
            sameItemCount = sameItemCount + 1
        end
    end
    
    if sameItemCount >= self.autoModerationRules.maxSameItemType then
        table.insert(violations, {
            type = "SPAM_PLACEMENT",
            message = "Too many of the same item type in area",
            severity = self.violationTypes.SPAM_PLACEMENT.severity
        })
    end
    
    -- 4. Path blocking check (if you have paths defined)
    if self:IsBlockingPath(playerPosition) then
        table.insert(violations, {
            type = "BLOCKING_PATHS",
            message = "Object blocks important pathways",
            severity = self.violationTypes.BLOCKING_PATHS.severity
        })
    end
    
    -- Process violations
    if #violations > 0 then
        return self:HandleViolations(player, objectInstance, violations)
    end
    
    return true -- Placement allowed
end

-- Handle player reports
function ModerationSystem:ReportObject(reportingPlayer, targetObjectId, reason)
    local reportData = {
        reportingPlayerId = reportingPlayer.UserId,
        reportingPlayerName = reportingPlayer.Name,
        targetObjectId = targetObjectId,
        reason = reason,
        timestamp = os.time(),
        status = "PENDING",
        reviewedBy = nil,
        action = nil
    }
    
    local reportId = "REPORT_" .. os.time() .. "_" .. math.random(1000, 9999)
    
    -- Save report
    local success, error = pcall(function()
        PlayerReportsStore:SetAsync(reportId, reportData)
    end)
    
    if success then
        -- Add to runtime cache
        self.reportedObjects[targetObjectId] = self.reportedObjects[targetObjectId] or {}
        table.insert(self.reportedObjects[targetObjectId], reportData)
        
        -- Auto-moderate if object has multiple reports
        if #self.reportedObjects[targetObjectId] >= 3 then
            self:AutoModerateReportedObject(targetObjectId)
        end
        
        print("📝 Report filed:", reportId, "by", reportingPlayer.Name)
        return reportId
    else
        warn("Failed to save report:", error)
        return nil
    end
end

-- Auto-moderate highly reported objects
function ModerationSystem:AutoModerateReportedObject(objectId)
    local reports = self.reportedObjects[objectId]
    if not reports or #reports < 3 then return end
    
    -- Find the object
    local targetObject = self:FindObjectByPlacementId(objectId)
    if not targetObject then return end
    
    -- Temporarily hide object pending review
    targetObject.Transparency = 0.8
    targetObject.CanCollide = false
    
    -- Add warning sign
    local warning = Instance.new("BillboardGui")
    warning.Name = "ModerationWarning"
    warning.Size = UDim2.new(0, 200, 0, 50)
    warning.StudsOffset = Vector3.new(0, 5, 0)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    label.Text = "⚠️ UNDER REVIEW"
    label.TextColor3 = Color3.fromRGB(0, 0, 0)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = warning
    
    warning.Parent = targetObject
    
    print("⚠️ Auto-moderated object:", objectId, "due to multiple reports")
end

-- Handle violations
function ModerationSystem:HandleViolations(player, objectInstance, violations)
    local totalSeverity = 0
    local worstViolation = nil
    
    for _, violation in ipairs(violations) do
        totalSeverity = totalSeverity + violation.severity
        if not worstViolation or violation.severity > worstViolation.severity then
            worstViolation = violation
        end
    end
    
    -- Record violation
    self:RecordPlayerViolation(player, violations)
    
    -- Determine action based on severity
    if totalSeverity >= 10 then
        -- Severe violation - deny placement
        self:NotifyPlayer(player, "❌ Placement denied: " .. worstViolation.message)
        return false
    elseif totalSeverity >= 5 then
        -- Warning level - allow but warn
        self:NotifyPlayer(player, "⚠️ Warning: " .. worstViolation.message)
        return true
    else
        -- Minor violation - just log
        print("⚠️ Minor violation by", player.Name, ":", worstViolation.message)
        return true
    end
end

-- Record player violation for tracking repeat offenders
function ModerationSystem:RecordPlayerViolation(player, violations)
    if not self.playerViolations[player.UserId] then
        self.playerViolations[player.UserId] = {
            playerId = player.UserId,
            playerName = player.Name,
            violations = {},
            totalSeverity = 0,
            lastViolation = 0
        }
    end
    
    local playerRecord = self.playerViolations[player.UserId]
    
    for _, violation in ipairs(violations) do
        table.insert(playerRecord.violations, {
            type = violation.type,
            message = violation.message,
            severity = violation.severity,
            timestamp = os.time()
        })
        
        playerRecord.totalSeverity = playerRecord.totalSeverity + violation.severity
        playerRecord.lastViolation = os.time()
    end
    
    -- Check if player needs escalated punishment
    if playerRecord.totalSeverity >= 20 then
        self:EscalatePlayerPunishment(player, playerRecord)
    end
    
    -- Save to DataStore
    pcall(function()
        ModerationStore:SetAsync("PLAYER_" .. player.UserId, playerRecord)
    end)
end

-- Escalate punishment for repeat offenders
function ModerationSystem:EscalatePlayerPunishment(player, playerRecord)
    if playerRecord.totalSeverity >= 50 then
        -- Permanent ban
        player:Kick("You have been permanently banned for repeated violations.")
        print("🔨 BANNED player:", player.Name, "for severe violations")
    elseif playerRecord.totalSeverity >= 30 then
        -- Temporary ban (would need external system)
        player:Kick("You have been temporarily banned. Violations: " .. playerRecord.totalSeverity)
        print("⏰ TEMP BANNED player:", player.Name, "for repeated violations")
    elseif playerRecord.totalSeverity >= 20 then
        -- Placement restrictions
        self:NotifyPlayer(player, "🚫 Your placement privileges have been limited due to violations.")
        print("🚫 RESTRICTED player:", player.Name, "placement privileges")
    end
end

-- Utility functions
function ModerationSystem:GetRecentPlacements(player, timeWindow)
    local recent = {}
    local cutoff = os.time() - timeWindow
    
    for placementId, data in pairs(self.placementTracker.placedObjects) do
        if data.PlayerId == player.UserId and data.Timestamp >= cutoff then
            table.insert(recent, data)
        end
    end
    
    return recent
end

function ModerationSystem:GetObjectsInRadius(position, radius)
    local objects = {}
    
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            local distance = (obj.Position - position).Magnitude
            if distance <= radius then
                table.insert(objects, obj)
            end
        end
    end
    
    return objects
end

function ModerationSystem:IsBlockingPath(position)
    -- Implement path checking logic based on your world design
    -- For now, check if it's in a development zone
    if self.placementTracker then
        local inZone, zoneName = self.placementTracker:IsInDevelopmentZone(position)
        return inZone
    end
    return false
end

function ModerationSystem:FindObjectByPlacementId(placementId)
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") == placementId then
            return obj
        end
    end
    return nil
end

function ModerationSystem:NotifyPlayer(player, message)
    -- Implement your notification system here
    print("📢 Notifying", player.Name, ":", message)
    
    -- Example: Send to chat or GUI
    -- game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
    --     Text = message,
    --     Color = Color3.fromRGB(255, 200, 0)
    -- })
end

function ModerationSystem:LoadModerationData()
    -- Load existing player violation records
    print("📂 Loading moderation data...")
    -- Implementation would load from DataStore
end

function ModerationSystem:PerformAutoModeration()
    -- Periodic checks for ongoing violations
    -- This would run less frequently than every heartbeat in practice
    if math.random(1, 1800) == 1 then -- ~Every 30 seconds at 60 FPS
        self:CheckForOngoingViolations()
    end
end

function ModerationSystem:CheckForOngoingViolations()
    -- Check for patterns that develop over time
    -- e.g., players slowly building inappropriate structures
    print("🔍 Performing periodic moderation check...")
end

-- Generate moderation report
function ModerationSystem:GenerateModerationReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        totalReports = 0,
        activeViolators = 0,
        pendingReviews = 0,
        autoActions = 0
    }
    
    -- Count reports
    for objectId, reports in pairs(self.reportedObjects) do
        report.totalReports = report.totalReports + #reports
        
        local hasPending = false
        for _, reportData in ipairs(reports) do
            if reportData.status == "PENDING" then
                hasPending = true
                break
            end
        end
        if hasPending then
            report.pendingReviews = report.pendingReviews + 1
        end
    end
    
    -- Count violators
    for playerId, playerRecord in pairs(self.playerViolations) do
        if playerRecord.totalSeverity > 0 then
            report.activeViolators = report.activeViolators + 1
        end
    end
    
    return report
end

return ModerationSystem 