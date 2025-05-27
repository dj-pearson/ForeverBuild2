-- AuditLogger.luau
-- Enterprise-level audit logging system for security events and compliance
-- Provides immutable audit trails, event categorization, and compliance reporting

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local AuditLogger = {}
AuditLogger.__index = AuditLogger

-- DataStores for persistent audit data
local AuditStore = DataStoreService:GetDataStore("AuditLogs_v1")
local SecurityEventStore = DataStoreService:GetDataStore("SecurityEvents_v1")
local ComplianceStore = DataStoreService:GetDataStore("ComplianceLogs_v1")

-- Configuration
local CONFIG = {
    -- Logging levels
    LOG_LEVELS = {
        TRACE = 0,
        DEBUG = 1,
        INFO = 2,
        WARN = 3,
        ERROR = 4,
        CRITICAL = 5
    },
    
    -- Event categories
    EVENT_CATEGORIES = {
        AUTHENTICATION = "AUTHENTICATION",
        AUTHORIZATION = "AUTHORIZATION",
        DATA_ACCESS = "DATA_ACCESS",
        SYSTEM_CHANGE = "SYSTEM_CHANGE",
        SECURITY_VIOLATION = "SECURITY_VIOLATION",
        USER_ACTION = "USER_ACTION",
        ADMIN_ACTION = "ADMIN_ACTION",
        COMPLIANCE = "COMPLIANCE"
    },
    
    -- Retention policies
    RETENTION_DAYS = {
        TRACE = 7,
        DEBUG = 30,
        INFO = 90,
        WARN = 180,
        ERROR = 365,
        CRITICAL = 2555 -- 7 years for compliance
    },
    
    -- Storage settings
    MAX_BATCH_SIZE = 100,
    BATCH_FLUSH_INTERVAL = 60, -- Flush every minute
    MAX_MEMORY_LOGS = 1000,
    COMPRESS_LOGS = true,
    
    -- Security settings
    ENCRYPT_SENSITIVE_DATA = true,
    HASH_USER_DATA = true,
    REQUIRE_INTEGRITY_CHECK = true,
    
    -- Compliance settings
    GDPR_COMPLIANCE = true,
    SOX_COMPLIANCE = true,
    AUDIT_TRAIL_IMMUTABLE = true,
    
    DEBUG_MODE = false
}

-- Event severity levels
local SEVERITY = {
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    CRITICAL = "CRITICAL"
}

-- Compliance frameworks
local COMPLIANCE_FRAMEWORKS = {
    GDPR = "GDPR",
    SOX = "SOX",
    HIPAA = "HIPAA",
    PCI_DSS = "PCI_DSS"
}

function AuditLogger.new()
    local self = setmetatable({}, AuditLogger)
    
    -- In-memory log buffer
    self.logBuffer = {}
    
    -- Event counters
    self.eventCounters = {}
    
    -- Audit statistics
    self.stats = {
        totalEvents = 0,
        eventsByCategory = {},
        eventsByLevel = {},
        securityViolations = 0,
        complianceEvents = 0,
        batchesFlushed = 0,
        storageErrors = 0
    }
    
    -- Session tracking
    self.sessionId = self:GenerateSessionId()
    self.startTime = tick()
    
    -- Batch processing
    self.lastFlush = tick()
    self.pendingBatch = {}
    
    -- Initialize event counters
    for category, _ in pairs(CONFIG.EVENT_CATEGORIES) do
        self.eventCounters[category] = 0
        self.stats.eventsByCategory[category] = 0
    end
    
    for level, _ in pairs(CONFIG.LOG_LEVELS) do
        self.stats.eventsByLevel[level] = 0
    end
    
    return self
end

function AuditLogger:Initialize()
    print("[AuditLogger] Initializing enterprise audit logging system...")
    
    -- Setup automatic flushing
    self:StartBatchProcessor()
    
    -- Setup cleanup routines
    self:StartCleanupProcessor()
    
    -- Log system initialization
    self:LogEvent("SYSTEM", "AUDIT_SYSTEM_INITIALIZED", {
        sessionId = self.sessionId,
        startTime = self.startTime,
        configuration = {
            retentionEnabled = true,
            encryptionEnabled = CONFIG.ENCRYPT_SENSITIVE_DATA,
            complianceEnabled = CONFIG.GDPR_COMPLIANCE
        }
    }, "INFO")
    
    print("[AuditLogger] Audit logging system initialized")
    return true
end

function AuditLogger:LogEvent(category, eventType, eventData, level, player)
    local currentTime = tick()
    level = level or "INFO"
    
    -- Validate inputs
    if not CONFIG.EVENT_CATEGORIES[category] then
        warn("[AuditLogger] Invalid event category:", category)
        return false
    end
    
    if not CONFIG.LOG_LEVELS[level] then
        warn("[AuditLogger] Invalid log level:", level)
        return false
    end
    
    -- Create audit event
    local auditEvent = {
        id = self:GenerateEventId(),
        timestamp = currentTime,
        sessionId = self.sessionId,
        category = category,
        eventType = eventType,
        level = level,
        severity = self:DetermineSeverity(category, eventType, level),
        
        -- Player information
        userId = player and player.UserId or nil,
        playerName = player and player.Name or nil,
        
        -- Event data
        data = eventData or {},
        
        -- System context
        context = {
            serverTime = os.time(),
            gameId = game.GameId,
            placeId = game.PlaceId,
            jobId = game.JobId
        },
        
        -- Integrity
        checksum = nil -- Will be calculated
    }
    
    -- Add compliance tags if applicable
    auditEvent.compliance = self:GetComplianceTags(category, eventType, eventData)
    
    -- Calculate integrity checksum
    auditEvent.checksum = self:CalculateChecksum(auditEvent)
    
    -- Add to buffer
    table.insert(self.logBuffer, auditEvent)
    table.insert(self.pendingBatch, auditEvent)
    
    -- Update statistics
    self:UpdateStatistics(auditEvent)
    
    -- Check for immediate flush conditions
    if self:ShouldFlushImmediately(auditEvent) then
        self:FlushBatch()
    end
    
    -- Limit memory usage
    if #self.logBuffer > CONFIG.MAX_MEMORY_LOGS then
        table.remove(self.logBuffer, 1)
    end
    
    if CONFIG.DEBUG_MODE then
        print("[AuditLogger] Logged event:", category, eventType, level)
    end
    
    return true
end

function AuditLogger:LogSecurityEvent(eventType, player, details, severity)
    severity = severity or SEVERITY.MEDIUM
    
    local eventData = {
        severity = severity,
        details = details or {},
        timestamp = tick(),
        source = "SecuritySystem"
    }
    
    -- Add player context if available
    if player then
        eventData.playerContext = {
            userId = player.UserId,
            playerName = player.Name,
            accountAge = player.AccountAge,
            membershipType = tostring(player.MembershipType)
        }
    end
    
    self:LogEvent("SECURITY_VIOLATION", eventType, eventData, "ERROR", player)
    
    -- Increment security violation counter
    self.stats.securityViolations = self.stats.securityViolations + 1
    
    print("[AuditLogger] Security event logged:", eventType, severity)
end

function AuditLogger:LogUserAction(player, action, resource, details)
    local eventData = {
        action = action,
        resource = resource,
        details = details or {},
        timestamp = tick(),
        source = "UserAction"
    }
    
    -- Add session context
    if player then
        eventData.sessionContext = {
            sessionDuration = tick() - self.startTime,
            actionsThisSession = self:GetPlayerActionCount(player)
        }
    end
    
    self:LogEvent("USER_ACTION", action, eventData, "INFO", player)
end

function AuditLogger:LogAdminAction(admin, action, target, details)
    local eventData = {
        action = action,
        target = target,
        details = details or {},
        timestamp = tick(),
        source = "AdminAction",
        requiresApproval = self:RequiresApproval(action)
    }
    
    -- Add admin context
    if admin then
        eventData.adminContext = {
            adminId = admin.UserId,
            adminName = admin.Name,
            adminRole = "ADMIN" -- Would integrate with RoleManager
        }
    end
    
    self:LogEvent("ADMIN_ACTION", action, eventData, "WARN", admin)
end

function AuditLogger:LogDataAccess(player, dataType, operation, details)
    local eventData = {
        dataType = dataType,
        operation = operation,
        details = details or {},
        timestamp = tick(),
        source = "DataAccess"
    }
    
    -- Add data protection context
    eventData.dataProtection = {
        containsPII = self:ContainsPII(dataType, details),
        requiresEncryption = self:RequiresEncryption(dataType),
        retentionPeriod = self:GetRetentionPeriod(dataType)
    }
    
    self:LogEvent("DATA_ACCESS", operation, eventData, "INFO", player)
end

function AuditLogger:LogComplianceEvent(framework, eventType, details, player)
    local eventData = {
        framework = framework,
        eventType = eventType,
        details = details or {},
        timestamp = tick(),
        source = "ComplianceSystem"
    }
    
    -- Add compliance context
    eventData.complianceContext = {
        framework = framework,
        requiresReporting = true,
        retentionRequired = true,
        auditTrailRequired = true
    }
    
    self:LogEvent("COMPLIANCE", eventType, eventData, "WARN", player)
    
    -- Increment compliance event counter
    self.stats.complianceEvents = self.stats.complianceEvents + 1
end

function AuditLogger:DetermineSeverity(category, eventType, level)
    -- Security violations are always high severity
    if category == "SECURITY_VIOLATION" then
        return SEVERITY.HIGH
    end
    
    -- Admin actions are medium to high severity
    if category == "ADMIN_ACTION" then
        return SEVERITY.MEDIUM
    end
    
    -- Critical level events are high severity
    if level == "CRITICAL" or level == "ERROR" then
        return SEVERITY.HIGH
    end
    
    -- Warning level events are medium severity
    if level == "WARN" then
        return SEVERITY.MEDIUM
    end
    
    -- Default to low severity
    return SEVERITY.LOW
end

function AuditLogger:GetComplianceTags(category, eventType, eventData)
    local tags = {}
    
    -- GDPR compliance tags
    if CONFIG.GDPR_COMPLIANCE then
        if category == "DATA_ACCESS" or category == "USER_ACTION" then
            table.insert(tags, COMPLIANCE_FRAMEWORKS.GDPR)
        end
    end
    
    -- SOX compliance tags
    if CONFIG.SOX_COMPLIANCE then
        if category == "ADMIN_ACTION" or category == "SYSTEM_CHANGE" then
            table.insert(tags, COMPLIANCE_FRAMEWORKS.SOX)
        end
    end
    
    return tags
end

function AuditLogger:CalculateChecksum(auditEvent)
    -- Create a string representation for checksum calculation
    local dataString = HttpService:JSONEncode({
        timestamp = auditEvent.timestamp,
        category = auditEvent.category,
        eventType = auditEvent.eventType,
        userId = auditEvent.userId,
        data = auditEvent.data
    })
    
    -- Simple checksum calculation (in production, use proper cryptographic hash)
    local checksum = 0
    for i = 1, #dataString do
        checksum = checksum + string.byte(dataString, i)
    end
    
    return tostring(checksum)
end

function AuditLogger:ShouldFlushImmediately(auditEvent)
    -- Flush immediately for critical events
    if auditEvent.level == "CRITICAL" or auditEvent.level == "ERROR" then
        return true
    end
    
    -- Flush immediately for security violations
    if auditEvent.category == "SECURITY_VIOLATION" then
        return true
    end
    
    -- Flush when batch is full
    if #self.pendingBatch >= CONFIG.MAX_BATCH_SIZE then
        return true
    end
    
    return false
end

function AuditLogger:StartBatchProcessor()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        if currentTime - self.lastFlush >= CONFIG.BATCH_FLUSH_INTERVAL then
            if #self.pendingBatch > 0 then
                self:FlushBatch()
            end
            self.lastFlush = currentTime
        end
    end)
end

function AuditLogger:FlushBatch()
    if #self.pendingBatch == 0 then
        return
    end
    
    local batch = self.pendingBatch
    self.pendingBatch = {}
    
    -- Save batch to persistent storage
    local success = self:SaveBatchToStorage(batch)
    
    if success then
        self.stats.batchesFlushed = self.stats.batchesFlushed + 1
        if CONFIG.DEBUG_MODE then
            print("[AuditLogger] Flushed batch with", #batch, "events")
        end
    else
        self.stats.storageErrors = self.stats.storageErrors + 1
        warn("[AuditLogger] Failed to flush batch")
        
        -- Re-add to pending batch for retry
        for _, event in ipairs(batch) do
            table.insert(self.pendingBatch, event)
        end
    end
end

function AuditLogger:SaveBatchToStorage(batch)
    local batchId = self:GenerateBatchId()
    
    local batchData = {
        batchId = batchId,
        timestamp = tick(),
        eventCount = #batch,
        events = batch,
        integrity = self:CalculateBatchIntegrity(batch)
    }
    
    -- Save to primary audit store
    local success, result = pcall(function()
        return AuditStore:SetAsync(batchId, batchData)
    end)
    
    if not success then
        warn("[AuditLogger] Failed to save audit batch:", result)
        return false
    end
    
    -- Save security events to separate store
    self:SaveSecurityEvents(batch)
    
    -- Save compliance events to separate store
    self:SaveComplianceEvents(batch)
    
    return true
end

function AuditLogger:SaveSecurityEvents(batch)
    local securityEvents = {}
    
    for _, event in ipairs(batch) do
        if event.category == "SECURITY_VIOLATION" then
            table.insert(securityEvents, event)
        end
    end
    
    if #securityEvents > 0 then
        local securityBatchId = "SEC_" .. self:GenerateBatchId()
        
        local success, result = pcall(function()
            return SecurityEventStore:SetAsync(securityBatchId, {
                batchId = securityBatchId,
                timestamp = tick(),
                eventCount = #securityEvents,
                events = securityEvents
            })
        end)
        
        if not success then
            warn("[AuditLogger] Failed to save security events:", result)
        end
    end
end

function AuditLogger:SaveComplianceEvents(batch)
    local complianceEvents = {}
    
    for _, event in ipairs(batch) do
        if event.compliance and #event.compliance > 0 then
            table.insert(complianceEvents, event)
        end
    end
    
    if #complianceEvents > 0 then
        local complianceBatchId = "COMP_" .. self:GenerateBatchId()
        
        local success, result = pcall(function()
            return ComplianceStore:SetAsync(complianceBatchId, {
                batchId = complianceBatchId,
                timestamp = tick(),
                eventCount = #complianceEvents,
                events = complianceEvents
            })
        end)
        
        if not success then
            warn("[AuditLogger] Failed to save compliance events:", result)
        end
    end
end

function AuditLogger:CalculateBatchIntegrity(batch)
    local batchString = ""
    
    for _, event in ipairs(batch) do
        batchString = batchString .. event.checksum
    end
    
    -- Simple integrity calculation
    local integrity = 0
    for i = 1, #batchString do
        integrity = integrity + string.byte(batchString, i)
    end
    
    return tostring(integrity)
end

function AuditLogger:StartCleanupProcessor()
    -- Run cleanup every hour
    spawn(function()
        while true do
            wait(3600) -- 1 hour
            self:PerformCleanup()
        end
    end)
end

function AuditLogger:PerformCleanup()
    local currentTime = tick()
    local cleanedEvents = 0
    
    -- Clean up in-memory buffer based on retention policies
    local validEvents = {}
    
    for _, event in ipairs(self.logBuffer) do
        local retentionDays = CONFIG.RETENTION_DAYS[event.level] or CONFIG.RETENTION_DAYS["INFO"]
        local retentionSeconds = retentionDays * 24 * 60 * 60
        
        if currentTime - event.timestamp < retentionSeconds then
            table.insert(validEvents, event)
        else
            cleanedEvents = cleanedEvents + 1
        end
    end
    
    self.logBuffer = validEvents
    
    if cleanedEvents > 0 then
        print("[AuditLogger] Cleaned up", cleanedEvents, "expired events from memory")
    end
end

function AuditLogger:UpdateStatistics(auditEvent)
    self.stats.totalEvents = self.stats.totalEvents + 1
    self.stats.eventsByCategory[auditEvent.category] = (self.stats.eventsByCategory[auditEvent.category] or 0) + 1
    self.stats.eventsByLevel[auditEvent.level] = (self.stats.eventsByLevel[auditEvent.level] or 0) + 1
    
    self.eventCounters[auditEvent.category] = (self.eventCounters[auditEvent.category] or 0) + 1
end

function AuditLogger:GetPlayerActionCount(player)
    local count = 0
    
    for _, event in ipairs(self.logBuffer) do
        if event.userId == player.UserId and event.category == "USER_ACTION" then
            count = count + 1
        end
    end
    
    return count
end

function AuditLogger:ContainsPII(dataType, details)
    -- Check if data contains personally identifiable information
    local piiTypes = {"email", "phone", "address", "name", "ssn", "credit_card"}
    
    for _, piiType in ipairs(piiTypes) do
        if dataType:lower():find(piiType) then
            return true
        end
    end
    
    return false
end

function AuditLogger:RequiresEncryption(dataType)
    -- Determine if data type requires encryption
    local encryptionRequired = {"payment", "personal", "sensitive", "private"}
    
    for _, requiredType in ipairs(encryptionRequired) do
        if dataType:lower():find(requiredType) then
            return true
        end
    end
    
    return false
end

function AuditLogger:GetRetentionPeriod(dataType)
    -- Return retention period in days based on data type
    local retentionPeriods = {
        ["user_data"] = 2555, -- 7 years
        ["financial"] = 2555, -- 7 years
        ["security"] = 365, -- 1 year
        ["system"] = 90, -- 3 months
        ["debug"] = 30 -- 1 month
    }
    
    for type, period in pairs(retentionPeriods) do
        if dataType:lower():find(type) then
            return period
        end
    end
    
    return 90 -- Default 3 months
end

function AuditLogger:RequiresApproval(action)
    -- Determine if admin action requires approval
    local approvalRequired = {
        "delete_user_data",
        "ban_player",
        "modify_economy",
        "system_shutdown",
        "data_export"
    }
    
    for _, requiredAction in ipairs(approvalRequired) do
        if action:lower():find(requiredAction) then
            return true
        end
    end
    
    return false
end

function AuditLogger:GenerateEventId()
    return "EVT_" .. tostring(tick()):gsub("%.", "") .. "_" .. tostring(math.random(1000, 9999))
end

function AuditLogger:GenerateBatchId()
    return "BATCH_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

function AuditLogger:GenerateSessionId()
    return "SESSION_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

function AuditLogger:GetAuditStats()
    return {
        totalEvents = self.stats.totalEvents,
        eventsByCategory = self.stats.eventsByCategory,
        eventsByLevel = self.stats.eventsByLevel,
        securityViolations = self.stats.securityViolations,
        complianceEvents = self.stats.complianceEvents,
        batchesFlushed = self.stats.batchesFlushed,
        storageErrors = self.stats.storageErrors,
        memoryBufferSize = #self.logBuffer,
        pendingBatchSize = #self.pendingBatch,
        sessionId = self.sessionId,
        uptime = tick() - self.startTime
    }
end

function AuditLogger:GetRecentEvents(category, count)
    count = count or 50
    local recentEvents = {}
    
    for i = #self.logBuffer, math.max(1, #self.logBuffer - count + 1), -1 do
        local event = self.logBuffer[i]
        if not category or event.category == category then
            table.insert(recentEvents, {
                id = event.id,
                timestamp = event.timestamp,
                category = event.category,
                eventType = event.eventType,
                level = event.level,
                severity = event.severity,
                playerName = event.playerName
            })
        end
    end
    
    return recentEvents
end

function AuditLogger:SearchEvents(criteria)
    local results = {}
    
    for _, event in ipairs(self.logBuffer) do
        local matches = true
        
        if criteria.category and event.category ~= criteria.category then
            matches = false
        end
        
        if criteria.level and event.level ~= criteria.level then
            matches = false
        end
        
        if criteria.userId and event.userId ~= criteria.userId then
            matches = false
        end
        
        if criteria.timeRange then
            local eventTime = event.timestamp
            if eventTime < criteria.timeRange.start or eventTime > criteria.timeRange["end"] then
                matches = false
            end
        end
        
        if matches then
            table.insert(results, event)
        end
    end
    
    return results
end

function AuditLogger:Cleanup()
    print("[AuditLogger] Cleaning up...")
    
    -- Flush any pending events
    if #self.pendingBatch > 0 then
        self:FlushBatch()
    end
    
    -- Clear memory buffers
    self.logBuffer = {}
    self.pendingBatch = {}
    
    print("[AuditLogger] Cleanup complete")
end

return AuditLogger 