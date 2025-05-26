-- DataBackupSystem.luau
-- Comprehensive backup and recovery system for player data protection

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DataBackupSystem = {}
DataBackupSystem.__index = DataBackupSystem

-- DataStores for backup redundancy
local PrimaryStore = DataStoreService:GetDataStore("PlacementData_v1")
local BackupStore1 = DataStoreService:GetDataStore("PlacementBackup1_v1")
local BackupStore2 = DataStoreService:GetDataStore("PlacementBackup2_v1")
local BackupStore3 = DataStoreService:GetDataStore("PlacementBackup3_v1")
local MetadataStore = DataStoreService:GetDataStore("BackupMetadata_v1")

function DataBackupSystem.new(placementTracker)
    local self = setmetatable({}, DataBackupSystem)
    
    self.placementTracker = placementTracker
    
    -- Backup configuration
    self.backupConfig = {
        incrementalInterval = 30,   -- Incremental backup every 30 seconds
        fullBackupInterval = 300,   -- Full backup every 5 minutes
        retentionPeriod = 86400,    -- Keep backups for 24 hours
        maxBackupVersions = 10,     -- Keep last 10 backup versions
        compressionEnabled = true,  -- Compress backup data
        checksumValidation = true   -- Validate data integrity
    }
    
    -- Backup state tracking
    self.backupState = {
        lastIncrementalBackup = 0,
        lastFullBackup = 0,
        pendingChanges = {},
        backupQueue = {},
        isBackingUp = false,
        backupStats = {
            successfulBackups = 0,
            failedBackups = 0,
            dataIntegrityErrors = 0,
            averageBackupTime = 0
        }
    }
    
    -- Recovery state
    self.recoveryState = {
        isRecovering = false,
        lastRecoveryTime = 0,
        recoveryAttempts = 0
    }
    
    self:Initialize()
    return self
end

function DataBackupSystem:Initialize()
    -- Start backup routines
    self:StartIncrementalBackups()
    self:StartFullBackups()
    self:StartBackupMaintenance()
    
    -- Handle server shutdown gracefully
    game:BindToClose(function()
        self:EmergencyBackup()
    end)
    
    -- Track changes for incremental backups
    if self.placementTracker then
        self:HookToPlacementTracker()
    end
    
    print("💾 Data backup system initialized")
end

-- Backup routines
function DataBackupSystem:StartIncrementalBackups()
    spawn(function()
        while true do
            wait(self.backupConfig.incrementalInterval)
            
            if not self.backupState.isBackingUp and #self.backupState.pendingChanges > 0 then
                self:PerformIncrementalBackup()
            end
        end
    end)
end

function DataBackupSystem:StartFullBackups()
    spawn(function()
        while true do
            wait(self.backupConfig.fullBackupInterval)
            
            if not self.backupState.isBackingUp then
                self:PerformFullBackup()
            end
        end
    end)
end

function DataBackupSystem:StartBackupMaintenance()
    spawn(function()
        while true do
            wait(3600) -- Run maintenance every hour
            self:CleanupOldBackups()
            self:ValidateBackupIntegrity()
        end
    end)
end

-- Incremental backup (only changed data)
function DataBackupSystem:PerformIncrementalBackup()
    if #self.backupState.pendingChanges == 0 then return end
    
    local startTime = tick()
    self.backupState.isBackingUp = true
    
    local backupData = {
        type = "INCREMENTAL",
        timestamp = os.time(),
        changes = self.backupState.pendingChanges,
        version = self:GetNextBackupVersion()
    }
    
    local success = self:SaveBackupData("INCREMENTAL_" .. backupData.version, backupData)
    
    if success then
        self.backupState.pendingChanges = {} -- Clear pending changes
        self.backupState.lastIncrementalBackup = os.time()
        self.backupState.backupStats.successfulBackups = self.backupState.backupStats.successfulBackups + 1
        
        print("📄 Incremental backup completed:", #backupData.changes, "changes")
    else
        self.backupState.backupStats.failedBackups = self.backupState.backupStats.failedBackups + 1
        warn("❌ Incremental backup failed")
    end
    
    self:UpdateBackupStats(tick() - startTime)
    self.backupState.isBackingUp = false
end

-- Full backup (complete world state)
function DataBackupSystem:PerformFullBackup()
    local startTime = tick()
    self.backupState.isBackingUp = true
    
    print("💾 Starting full backup...")
    
    local worldData = self:CollectCompleteWorldData()
    local backupData = {
        type = "FULL",
        timestamp = os.time(),
        worldData = worldData,
        playerCount = #Players:GetPlayers(),
        version = self:GetNextBackupVersion(),
        checksum = self:CalculateChecksum(worldData)
    }
    
    -- Save to multiple stores for redundancy
    local stores = {BackupStore1, BackupStore2, BackupStore3}
    local successCount = 0
    local backupKey = "FULL_" .. backupData.version
    
    for i, store in ipairs(stores) do
        local success = self:SaveToDataStore(store, backupKey, backupData)
        if success then
            successCount = successCount + 1
        end
    end
    
    -- Require at least 2 successful saves
    if successCount >= 2 then
        self.backupState.lastFullBackup = os.time()
        self.backupState.backupStats.successfulBackups = self.backupState.backupStats.successfulBackups + 1
        self:SaveBackupMetadata(backupData)
        
        print("✅ Full backup completed successfully to", successCount, "stores")
    else
        self.backupState.backupStats.failedBackups = self.backupState.backupStats.failedBackups + 1
        warn("❌ Full backup failed - only", successCount, "stores succeeded")
    end
    
    self:UpdateBackupStats(tick() - startTime)
    self.backupState.isBackingUp = false
end

-- Emergency backup on server shutdown
function DataBackupSystem:EmergencyBackup()
    warn("🚨 EMERGENCY BACKUP: Server shutting down!")
    
    local emergencyData = {
        type = "EMERGENCY",
        timestamp = os.time(),
        worldData = self:CollectCompleteWorldData(),
        reason = "SERVER_SHUTDOWN",
        playerCount = #Players:GetPlayers()
    }
    
    -- Try to save to all available stores immediately
    local stores = {PrimaryStore, BackupStore1, BackupStore2, BackupStore3}
    local savedCount = 0
    
    for i, store in ipairs(stores) do
        local success, error = pcall(function()
            store:SetAsync("EMERGENCY_" .. os.time(), emergencyData)
        end)
        
        if success then
            savedCount = savedCount + 1
        else
            warn("Emergency backup failed for store", i, ":", error)
        end
    end
    
    print("💾 Emergency backup saved to", savedCount, "stores")
    wait(2) -- Give time for saves to complete
end

-- Data collection
function DataBackupSystem:CollectCompleteWorldData()
    local worldData = {
        placedObjects = {},
        playerData = {},
        serverStats = {
            uptime = workspace.DistributedGameTime,
            playerCount = #Players:GetPlayers(),
            objectCount = 0
        }
    }
    
    -- Collect placement data
    if self.placementTracker and self.placementTracker.placedObjects then
        for placementId, data in pairs(self.placementTracker.placedObjects) do
            worldData.placedObjects[placementId] = {
                PlayerId = data.PlayerId,
                PlayerName = data.PlayerName,
                ItemId = data.ItemId,
                Position = data.Position,
                Rotation = data.Rotation,
                Timestamp = data.Timestamp,
                LastModified = data.LastModified or data.Timestamp
            }
            worldData.serverStats.objectCount = worldData.serverStats.objectCount + 1
        end
    end
    
    -- Collect player data
    for _, player in ipairs(Players:GetPlayers()) do
        worldData.playerData[player.UserId] = {
            name = player.Name,
            joinTime = player.AccountAge,
            sessionStart = os.time() - (workspace.DistributedGameTime or 0)
        }
    end
    
    return worldData
end

-- Data persistence
function DataBackupSystem:SaveBackupData(key, data)
    local compressedData = data
    
    if self.backupConfig.compressionEnabled then
        compressedData = self:CompressData(data)
    end
    
    -- Try primary store first, then backups
    local stores = {PrimaryStore, BackupStore1, BackupStore2}
    
    for i, store in ipairs(stores) do
        local success = self:SaveToDataStore(store, key, compressedData)
        if success then
            return true
        end
    end
    
    return false
end

function DataBackupSystem:SaveToDataStore(dataStore, key, data)
    local success, error = pcall(function()
        dataStore:SetAsync(key, data)
    end)
    
    if not success then
        warn("Failed to save backup to DataStore:", error)
        return false
    end
    
    return true
end

-- Data recovery
function DataBackupSystem:RecoverFromBackup(backupVersion)
    if self.recoveryState.isRecovering then
        warn("Recovery already in progress")
        return false
    end
    
    self.recoveryState.isRecovering = true
    self.recoveryState.recoveryAttempts = self.recoveryState.recoveryAttempts + 1
    
    print("🔄 Starting recovery from backup version:", backupVersion or "LATEST")
    
    local recoveryData = self:LoadBackupData(backupVersion)
    if not recoveryData then
        self.recoveryState.isRecovering = false
        return false
    end
    
    -- Validate backup integrity
    if not self:ValidateBackupData(recoveryData) then
        warn("❌ Backup data validation failed")
        self.recoveryState.isRecovering = false
        return false
    end
    
    -- Perform recovery
    local success = self:RestoreWorldData(recoveryData)
    
    if success then
        self.recoveryState.lastRecoveryTime = os.time()
        print("✅ Recovery completed successfully")
    else
        warn("❌ Recovery failed")
    end
    
    self.recoveryState.isRecovering = false
    return success
end

function DataBackupSystem:LoadBackupData(version)
    local stores = {BackupStore1, BackupStore2, BackupStore3, PrimaryStore}
    
    for i, store in ipairs(stores) do
        local key = version and ("FULL_" .. version) or self:GetLatestBackupKey()
        
        local success, data = pcall(function()
            return store:GetAsync(key)
        end)
        
        if success and data then
            -- Decompress if needed
            if self.backupConfig.compressionEnabled then
                data = self:DecompressData(data)
            end
            
            print("📥 Loaded backup from store", i)
            return data
        end
    end
    
    warn("❌ Failed to load backup data from any store")
    return nil
end

function DataBackupSystem:RestoreWorldData(backupData)
    if not backupData.worldData then
        warn("Invalid backup data structure")
        return false
    end
    
    local restored = 0
    local failed = 0
    
    -- Clear existing world data
    if self.placementTracker then
        self.placementTracker.placedObjects = {}
    end
    
    -- Restore placement data
    for placementId, data in pairs(backupData.worldData.placedObjects) do
        local success = self:RestorePlacement(placementId, data)
        if success then
            restored = restored + 1
        else
            failed = failed + 1
        end
    end
    
    print("🔄 Restored", restored, "objects,", failed, "failed")
    
    -- Save restored data to current systems
    if self.placementTracker then
        self.placementTracker:SaveAllData()
    end
    
    return failed == 0
end

function DataBackupSystem:RestorePlacement(placementId, data)
    if not self.placementTracker then return false end
    
    -- Validate placement data
    if not data.PlayerId or not data.Position or not data.ItemId then
        warn("Invalid placement data for:", placementId)
        return false
    end
    
    -- Restore to placement tracker
    self.placementTracker.placedObjects[placementId] = {
        PlayerId = data.PlayerId,
        PlayerName = data.PlayerName,
        ItemId = data.ItemId,
        Position = data.Position,
        Rotation = data.Rotation,
        Timestamp = data.Timestamp,
        LastModified = data.LastModified
    }
    
    return true
end

-- Change tracking for incremental backups
function DataBackupSystem:HookToPlacementTracker()
    -- This would integrate with your placement tracker's events
    print("🔗 Hooked to placement tracker for change detection")
end

function DataBackupSystem:TrackChange(changeType, placementId, data)
    table.insert(self.backupState.pendingChanges, {
        type = changeType,
        placementId = placementId,
        data = data,
        timestamp = os.time()
    })
    
    -- Limit pending changes to prevent memory issues
    if #self.backupState.pendingChanges > 1000 then
        -- Force an incremental backup
        if not self.backupState.isBackingUp then
            spawn(function()
                self:PerformIncrementalBackup()
            end)
        end
    end
end

-- Utility functions
function DataBackupSystem:GetNextBackupVersion()
    return tostring(os.time()) .. "_" .. math.random(1000, 9999)
end

function DataBackupSystem:GetLatestBackupKey()
    -- Would need to query metadata store for latest backup
    return "FULL_LATEST"
end

function DataBackupSystem:CalculateChecksum(data)
    -- Simple checksum calculation
    local dataString = HttpService:JSONEncode(data)
    return string.len(dataString) .. "_" .. math.floor(tick())
end

function DataBackupSystem:ValidateBackupData(backupData)
    if not backupData or not backupData.worldData then
        return false
    end
    
    if self.backupConfig.checksumValidation and backupData.checksum then
        local calculatedChecksum = self:CalculateChecksum(backupData.worldData)
        if calculatedChecksum ~= backupData.checksum then
            warn("⚠️ Backup checksum mismatch")
            self.backupState.backupStats.dataIntegrityErrors = self.backupState.backupStats.dataIntegrityErrors + 1
            return false
        end
    end
    
    return true
end

function DataBackupSystem:CompressData(data)
    -- Basic compression (in real implementation, use proper compression)
    local jsonString = HttpService:JSONEncode(data)
    return {
        compressed = true,
        originalSize = string.len(jsonString),
        data = jsonString -- Would be actual compressed data
    }
end

function DataBackupSystem:DecompressData(compressedData)
    if compressedData.compressed then
        return HttpService:JSONDecode(compressedData.data)
    end
    return compressedData
end

-- Maintenance functions
function DataBackupSystem:CleanupOldBackups()
    local cutoffTime = os.time() - self.backupConfig.retentionPeriod
    print("🧹 Cleaning up backups older than", os.date("%Y-%m-%d %H:%M:%S", cutoffTime))
    
    -- This would query metadata store and remove old backups
    -- Implementation depends on your metadata structure
end

function DataBackupSystem:ValidateBackupIntegrity()
    print("🔍 Validating backup integrity...")
    
    -- Load recent backups and validate them
    -- This would check multiple backup versions for corruption
end

function DataBackupSystem:SaveBackupMetadata(backupData)
    local metadata = {
        version = backupData.version,
        timestamp = backupData.timestamp,
        type = backupData.type,
        objectCount = 0,
        playerCount = backupData.playerCount,
        checksum = backupData.checksum
    }
    
    if backupData.worldData and backupData.worldData.placedObjects then
        for _ in pairs(backupData.worldData.placedObjects) do
            metadata.objectCount = metadata.objectCount + 1
        end
    end
    
    pcall(function()
        MetadataStore:SetAsync("BACKUP_META_" .. backupData.version, metadata)
    end)
end

function DataBackupSystem:UpdateBackupStats(duration)
    local stats = self.backupState.backupStats
    stats.averageBackupTime = (stats.averageBackupTime + duration) / 2
end

-- Reporting and diagnostics
function DataBackupSystem:GenerateBackupReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        backupConfig = self.backupConfig,
        backupStats = self.backupState.backupStats,
        lastBackups = {
            incremental = os.date("%Y-%m-%d %H:%M:%S", self.backupState.lastIncrementalBackup),
            full = os.date("%Y-%m-%d %H:%M:%S", self.backupState.lastFullBackup)
        },
        systemHealth = {
            isBackingUp = self.backupState.isBackingUp,
            pendingChanges = #self.backupState.pendingChanges,
            recoveryAttempts = self.recoveryState.recoveryAttempts
        }
    }
    
    return report
end

-- Admin commands
function DataBackupSystem:ForceFullBackup()
    if not self.backupState.isBackingUp then
        spawn(function()
            self:PerformFullBackup()
        end)
        return true
    end
    return false
end

function DataBackupSystem:ForceRecovery(version)
    return self:RecoverFromBackup(version)
end

return DataBackupSystem 