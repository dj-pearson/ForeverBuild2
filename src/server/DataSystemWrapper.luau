-- DataSystemWrapper.luau
-- Smart routing wrapper for the unified data management system
-- Inherits from BaseSystemWrapper for consistency and better functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import the standardized base wrapper and configuration
local BaseSystemWrapper = require(ReplicatedStorage.src.shared.core.BaseSystemWrapper)
local SystemConfig = require(ReplicatedStorage.src.shared.core.SystemConfig)

local DataSystemWrapper = setmetatable({}, BaseSystemWrapper)
DataSystemWrapper.__index = DataSystemWrapper

-- Get data-specific configuration
local DATA_CONFIG = SystemConfig.Utils.GetSystemConfig("DATA")

-- Global instance for easy access
local globalInstance = nil

-- Create new data system wrapper instance
function DataSystemWrapper.new()
    if globalInstance then
        return globalInstance
    end
    
    local self = BaseSystemWrapper.new("DataSystem", {
        HEALTH_CHECK_INTERVAL = DATA_CONFIG.HEALTH_CHECK_INTERVAL or 60,
        DEBUG_MODE = SystemConfig.GLOBAL.DEBUG_MODE,
        MAX_RETRY_ATTEMPTS = SystemConfig.GLOBAL.MAX_RETRY_ATTEMPTS,
        RETRY_DELAY = SystemConfig.GLOBAL.RETRY_DELAY
    })
    
    -- Set up data-specific metatable
    setmetatable(self, DataSystemWrapper)
    
    -- Data-specific properties
    self.backupQueue = {}
    self.lastBackupTime = 0
    self.dataStats = {
        totalBackups = 0,
        successfulBackups = 0,
        failedBackups = 0,
        lastBackupSize = 0
    }
    
    -- Store as global instance
    globalInstance = self
    
    return self
end

-- Load the primary data system (DataBackupSystem)
function DataSystemWrapper:LoadPrimarySystem()
    local primarySystem = self:SafeRequire(script.Parent.DataBackupSystem, "DataBackupSystem")
    
    if primarySystem and typeof(primarySystem.new) == "function" then
        local instance = primarySystem.new()
        if instance and instance.Initialize and instance:Initialize() then
            self.systemState.primarySystem = instance
            
            print("[DataSystemWrapper] Primary DataBackupSystem loaded successfully")
            return true
        else
            warn("[DataSystemWrapper] Primary system initialization failed")
        end
    end
    
    return false
end

-- Load fallback systems for backward compatibility
function DataSystemWrapper:LoadFallbackSystems()
    local fallbacks = {}
    
    -- Load fallback systems based on configuration
    for _, fallbackName in ipairs(DATA_CONFIG.FALLBACK_SYSTEMS) do
        if fallbackName == "SystemManager" then
            -- Try SystemManager
            local fallbackSystem = self:SafeRequire(script.Parent.SystemManager, "SystemManager")
            if fallbackSystem and typeof(fallbackSystem.new) == "function" then
                local instance = fallbackSystem.new()
                if instance then
                    fallbacks.systemManager = instance
                    print("[DataSystemWrapper] Loaded SystemManager fallback")
                end
            end
        elseif fallbackName == "GameHealthMonitor" then
            -- Try GameHealthMonitor
            local fallbackSystem = self:SafeRequire(script.Parent.GameHealthMonitor, "GameHealthMonitor")
            if fallbackSystem and typeof(fallbackSystem.new) == "function" then
                local instance = fallbackSystem.new()
                if instance then
                    fallbacks.gameHealthMonitor = instance
                    print("[DataSystemWrapper] Loaded GameHealthMonitor fallback")
                end
            end
        end
    end
    
    -- If no configured fallbacks work, try the minimal fallback
    if self:CountTable(fallbacks) == 0 then
        fallbacks.minimalFallback = self:CreateMinimalFallback()
        print("[DataSystemWrapper] Created minimal fallback system")
    end
    
    self.systemState.fallbackSystems = fallbacks
    print(string.format("[DataSystemWrapper] Loaded %d fallback systems", self:CountTable(fallbacks)))
end

-- Create minimal fallback system
function DataSystemWrapper:CreateMinimalFallback()
    return {
        new = function()
            return {
                Initialize = function(self)
                    print("[MinimalDataSystem] Minimal system active - limited functionality")
                    return true
                end,
                
                BackupData = function(self, dataType, data)
                    print("[MinimalDataSystem] BackupData requested for:", dataType, "- minimal mode")
                    return false, "Data system is in minimal mode"
                end,
                
                RestoreData = function(self, dataType, version)
                    print("[MinimalDataSystem] RestoreData requested for:", dataType, "version:", version)
                    return nil, "Data system is in minimal mode"
                end,
                
                GetBackupHistory = function(self, dataType)
                    print("[MinimalDataSystem] GetBackupHistory requested for:", dataType)
                    return {}
                end,
                
                ValidateData = function(self, data)
                    print("[MinimalDataSystem] ValidateData requested - minimal mode")
                    return true -- Always pass validation in minimal mode
                end,
                
                GetDataStats = function(self)
                    return {
                        totalBackups = 0,
                        successfulBackups = 0,
                        failedBackups = 0,
                        lastBackupTime = 0,
                        systemStatus = "minimal"
                    }
                end,
                
                Cleanup = function(self)
                    print("[MinimalDataSystem] Cleanup called")
                end
            }
        end
    }
end

-- Set up global API functions specific to data system
function DataSystemWrapper:SetupGlobalAPI()
    -- Call parent setup first
    BaseSystemWrapper.SetupGlobalAPI(self)
    
    -- Add data-specific API functions
    self.globalAPI.BackupData = function(dataType, data)
        local success, result = self:RouteCall("BackupData", dataType, data)
        if success then
            self.dataStats.totalBackups = self.dataStats.totalBackups + 1
            self.dataStats.successfulBackups = self.dataStats.successfulBackups + 1
            self.lastBackupTime = os.time()
            if data and type(data) == "table" then
                self.dataStats.lastBackupSize = #data
            end
        else
            self.dataStats.failedBackups = self.dataStats.failedBackups + 1
        end
        return success, result
    end
    
    self.globalAPI.RestoreData = function(dataType, version)
        return self:RouteCall("RestoreData", dataType, version)
    end
    
    self.globalAPI.GetBackupHistory = function(dataType)
        return self:RouteCall("GetBackupHistory", dataType)
    end
    
    self.globalAPI.ValidateData = function(data)
        return self:RouteCall("ValidateData", data)
    end
    
    self.globalAPI.GetDataStats = function()
        local systemStats = self:RouteCall("GetDataStats") or {}
        -- Merge with our wrapper stats
        for key, value in pairs(self.dataStats) do
            systemStats[key] = value
        end
        systemStats.lastBackupTime = self.lastBackupTime
        return systemStats
    end
    
    self.globalAPI.QueueBackup = function(dataType, data)
        table.insert(self.backupQueue, {
            dataType = dataType,
            data = data,
            timestamp = os.time()
        })
        return true
    end
    
    self.globalAPI.ProcessBackupQueue = function()
        local processed = 0
        local failed = 0
        
        for i = #self.backupQueue, 1, -1 do
            local backup = self.backupQueue[i]
            local success = self.globalAPI.BackupData(backup.dataType, backup.data)
            
            if success then
                processed = processed + 1
                table.remove(self.backupQueue, i)
            else
                failed = failed + 1
            end
        end
        
        return processed, failed
    end
    
    self.globalAPI.GetBackupQueueSize = function()
        return #self.backupQueue
    end
    
    print("[DataSystemWrapper] Data-specific global API configured")
end

-- Check if primary system is healthy (data-specific checks)
function DataSystemWrapper:CheckPrimarySystemHealth()
    if not self.systemState.primarySystem then
        return false
    end
    
    -- Check if the system is still active
    if self.systemState.primarySystem.isActive == false then
        return false
    end
    
    -- Check if DataStore services are available
    local DataStoreService = game:GetService("DataStoreService")
    if not DataStoreService then
        return false
    end
    
    -- Check if we can access DataStores (basic test)
    local success = pcall(function()
        local testStore = DataStoreService:GetDataStore("HealthCheck")
        return testStore ~= nil
    end)
    
    if not success then
        return false
    end
    
    return true
end

-- Data-specific callback handling
function DataSystemWrapper:OnDataBackup(dataType, success, size)
    if self.config.DEBUG_MODE then
        print("[DataSystemWrapper] Data backup:", dataType, "success:", success, "size:", size)
    end
    
    -- Could add global backup tracking here
end

-- Global functions for easy access (backward compatibility)
function DataSystemWrapper.Initialize()
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance:Initialize()
end

function DataSystemWrapper.GetGlobalInstance()
    if not globalInstance then
        globalInstance = DataSystemWrapper.new()
        globalInstance:Initialize()
    end
    return globalInstance
end

function DataSystemWrapper.BackupData(dataType, data)
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.BackupData(dataType, data)
end

function DataSystemWrapper.RestoreData(dataType, version)
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.RestoreData(dataType, version)
end

function DataSystemWrapper.GetBackupHistory(dataType)
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetBackupHistory(dataType)
end

function DataSystemWrapper.ValidateData(data)
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ValidateData(data)
end

function DataSystemWrapper.GetDataStats()
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetDataStats()
end

function DataSystemWrapper.QueueBackup(dataType, data)
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.QueueBackup(dataType, data)
end

function DataSystemWrapper.ProcessBackupQueue()
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ProcessBackupQueue()
end

function DataSystemWrapper.GetBackupQueueSize()
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetBackupQueueSize()
end

function DataSystemWrapper.GetSystemStatus()
    local instance = DataSystemWrapper.GetGlobalInstance()
    return instance:GetSystemStatus()
end

-- Utility function to check system health
function DataSystemWrapper.CheckSystemHealth()
    local instance = DataSystemWrapper.GetGlobalInstance()
    local status = instance:GetSystemStatus()
    
    return {
        unifiedAvailable = status.activeSystem == "primary",
        legacyAvailable = status.availableSystems.fallbacks > 0,
        healthStatus = status.healthStatus,
        activeSystem = status.activeSystem,
        totalBackups = instance.dataStats.totalBackups,
        successfulBackups = instance.dataStats.successfulBackups,
        failedBackups = instance.dataStats.failedBackups,
        backupQueueSize = #instance.backupQueue,
        lastBackupTime = instance.lastBackupTime,
        recommendedAction = status.healthStatus == "failed" and "Restart required" or "System operational"
    }
end

-- Backward compatibility aliases
DataSystemWrapper.Backup = DataSystemWrapper.BackupData
DataSystemWrapper.Restore = DataSystemWrapper.RestoreData
DataSystemWrapper.Validate = DataSystemWrapper.ValidateData

return DataSystemWrapper 