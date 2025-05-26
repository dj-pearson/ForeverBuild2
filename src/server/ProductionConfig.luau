-- ProductionConfig.luau
-- Production configuration and environment management

local ProductionConfig = {}

-- Environment detection
ProductionConfig.Environment = {
    DEVELOPMENT = "development",
    STAGING = "staging", 
    PRODUCTION = "production"
}

-- Get current environment (you can set this based on your deployment)
function ProductionConfig.GetEnvironment()
    -- In a real deployment, this could check game universe ID, place ID, or other identifiers
    local gameId = game.GameId
    local placeId = game.PlaceId
    
    -- Configure these IDs for your actual game
    if placeId == 0 then -- Studio
        return ProductionConfig.Environment.DEVELOPMENT
    elseif placeId == 103099385437670 then -- Your staging place ID
        return ProductionConfig.Environment.STAGING  
    else -- Your production place ID
        return ProductionConfig.Environment.PRODUCTION
    end
end

-- Admin user configuration
ProductionConfig.AdminUsers = {
    [ProductionConfig.Environment.DEVELOPMENT] = {
        7768610061, -- Your developer user ID
     -- Another developer
        -- Add test admin IDs here
    },
    [ProductionConfig.Environment.STAGING] = {
        7768610061, -- Your main admin ID
        -- Add staging admin IDs here  
    },
    [ProductionConfig.Environment.PRODUCTION] = {
        7768610061, -- Your main admin ID
        -- Add production admin IDs here
        -- Be very careful with this list!
    }
}

-- Performance configuration by environment
ProductionConfig.Performance = {
    [ProductionConfig.Environment.DEVELOPMENT] = {
        maxPlacedObjects = 100,
        memoryWarningThreshold = 500, -- MB
        memoryCriticalThreshold = 800,
        backupInterval = 300, -- 5 minutes
        healthCheckInterval = 30,
        debugMode = true,
        verboseLogging = true
    },
    [ProductionConfig.Environment.STAGING] = {
        maxPlacedObjects = 500,
        memoryWarningThreshold = 600,
        memoryCriticalThreshold = 900,
        backupInterval = 120, -- 2 minutes  
        healthCheckInterval = 60,
        debugMode = true,
        verboseLogging = false
    },
    [ProductionConfig.Environment.PRODUCTION] = {
        maxPlacedObjects = 2000,
        memoryWarningThreshold = 800,
        memoryCriticalThreshold = 1200,
        backupInterval = 60, -- 1 minute
        healthCheckInterval = 60,
        debugMode = false,
        verboseLogging = false
    }
}

-- Security configuration  
ProductionConfig.Security = {
    [ProductionConfig.Environment.DEVELOPMENT] = {
        rateLimitEnabled = false,
        exploitDetectionEnabled = true,
        strictValidation = false,
        banEnabled = false -- Don't ban in dev
    },
    [ProductionConfig.Environment.STAGING] = {
        rateLimitEnabled = true,
        exploitDetectionEnabled = true,
        strictValidation = true,
        banEnabled = false -- Don't ban in staging
    },
    [ProductionConfig.Environment.PRODUCTION] = {
        rateLimitEnabled = true,
        exploitDetectionEnabled = true,
        strictValidation = true,
        banEnabled = true -- Full security in production
    }
}

-- Analytics configuration
ProductionConfig.Analytics = {
    [ProductionConfig.Environment.DEVELOPMENT] = {
        enabled = false,
        trackPlayers = false,
        trackPerformance = true,
        trackErrors = true
    },
    [ProductionConfig.Environment.STAGING] = {
        enabled = true,
        trackPlayers = true,
        trackPerformance = true,
        trackErrors = true
    },
    [ProductionConfig.Environment.PRODUCTION] = {
        enabled = true,
        trackPlayers = true,
        trackPerformance = true,
        trackErrors = true
    }
}

-- Data storage configuration
ProductionConfig.DataStore = {
    [ProductionConfig.Environment.DEVELOPMENT] = {
        prefix = "DEV_",
        backupStores = 1, -- Minimal backups in dev
        compressionEnabled = false
    },
    [ProductionConfig.Environment.STAGING] = {
        prefix = "STAGING_",
        backupStores = 2,
        compressionEnabled = true
    },
    [ProductionConfig.Environment.PRODUCTION] = {
        prefix = "PROD_",
        backupStores = 5, -- Multiple backup stores in production
        compressionEnabled = true
    }
}

-- Get configuration for current environment
function ProductionConfig.GetConfig()
    local env = ProductionConfig.GetEnvironment()
    
    return {
        environment = env,
        admins = ProductionConfig.AdminUsers[env] or {},
        performance = ProductionConfig.Performance[env],
        security = ProductionConfig.Security[env], 
        analytics = ProductionConfig.Analytics[env],
        dataStore = ProductionConfig.DataStore[env]
    }
end

-- Get admin users for current environment
function ProductionConfig.GetAdminUsers()
    local env = ProductionConfig.GetEnvironment()
    return ProductionConfig.AdminUsers[env] or {}
end

-- Check if user is admin in current environment
function ProductionConfig.IsAdmin(userId)
    local admins = ProductionConfig.GetAdminUsers()
    for _, adminId in ipairs(admins) do
        if userId == adminId then
            return true
        end
    end
    return false
end

-- Get performance settings for current environment
function ProductionConfig.GetPerformanceConfig()
    local env = ProductionConfig.GetEnvironment()
    return ProductionConfig.Performance[env]
end

-- Get security settings for current environment
function ProductionConfig.GetSecurityConfig()
    local env = ProductionConfig.GetEnvironment()
    return ProductionConfig.Security[env]
end

-- Log configuration on startup
function ProductionConfig.LogStartupConfig()
    local config = ProductionConfig.GetConfig()
    
    print("🌍 PRODUCTION CONFIG LOADED")
    print("Environment:", config.environment)
    print("Admin Count:", #config.admins)
    print("Max Objects:", config.performance.maxPlacedObjects)
    print("Memory Limit:", config.performance.memoryCriticalThreshold, "MB")
    print("Security Level:", config.security.strictValidation and "STRICT" or "RELAXED")
    print("Analytics:", config.analytics.enabled and "ENABLED" or "DISABLED")
    print("Debug Mode:", config.performance.debugMode and "ON" or "OFF")
end

-- Emergency configuration override (for critical situations)
ProductionConfig.EmergencyOverrides = {
    disableNewPlacements = false,
    enableEmergencyMode = false,
    maxConcurrentPlayers = nil, -- nil = no limit
    forceLowPerformanceMode = false
}

function ProductionConfig.SetEmergencyOverride(setting, value)
    if ProductionConfig.EmergencyOverrides[setting] ~= nil then
        ProductionConfig.EmergencyOverrides[setting] = value
        warn("🚨 EMERGENCY OVERRIDE SET:", setting, "=", tostring(value))
        return true
    end
    return false
end

function ProductionConfig.GetEmergencyOverrides()
    return ProductionConfig.EmergencyOverrides
end

-- Environment-specific feature flags
ProductionConfig.FeatureFlags = {
    [ProductionConfig.Environment.DEVELOPMENT] = {
        newItemSystem = true,
        experimentalFeatures = true,
        advancedDebugging = true
    },
    [ProductionConfig.Environment.STAGING] = {
        newItemSystem = true,
        experimentalFeatures = false,
        advancedDebugging = false
    },
    [ProductionConfig.Environment.PRODUCTION] = {
        newItemSystem = false, -- Disable new features until tested
        experimentalFeatures = false,
        advancedDebugging = false
    }
}

function ProductionConfig.IsFeatureEnabled(featureName)
    local env = ProductionConfig.GetEnvironment()
    local flags = ProductionConfig.FeatureFlags[env]
    return flags and flags[featureName] == true
end

return ProductionConfig 