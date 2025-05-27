-- SystemConfig.luau
-- Centralized configuration for all game systems
-- Single source of truth for system settings, paths, and behavior

local SystemConfig = {}

-- Global system settings
SystemConfig.GLOBAL = {
    DEBUG_MODE = false,
    HEALTH_CHECK_INTERVAL = 30,
    MAX_RETRY_ATTEMPTS = 3,
    RETRY_DELAY = 1,
    FALLBACK_TIMEOUT = 5,
    PERFORMANCE_MONITORING = true
}

-- Interaction system configuration
SystemConfig.INTERACTION = {
    -- System hierarchy (order matters - first available system is used)
    PRIMARY_SYSTEM = "InteractionManager",
    FALLBACK_SYSTEMS = {"ItemInteractionClient"},
    
    -- Behavior settings
    MAX_DISTANCE = 10,
    CHECK_INTERVAL = 0.5,
    UI_FADE_TIME = 0.3,
    INTERACTION_COOLDOWN = 0.1,
    
    -- Paths
    MODULE_PATH = "src.client.interaction",
    LEGACY_PATH = "src.client.interaction.legacy",
    
    -- Feature flags
    ENABLE_PROXIMITY_UI = true,
    ENABLE_CLICK_INTERACTIONS = true,
    ENABLE_TOUCH_INTERACTIONS = true,
    
    -- Performance settings
    MAX_TRACKED_ITEMS = 100,
    CLEANUP_INTERVAL = 60
}

-- Currency system configuration
SystemConfig.CURRENCY = {
    -- System hierarchy
    PRIMARY_SYSTEM = "CurrencyManager",
    FALLBACK_SYSTEMS = {"SharedCurrencyUI", "LegacyCurrencyUI"},
    
    -- UI settings
    UPDATE_ANIMATION_TIME = 0.5,
    PURCHASE_MENU_FADE_TIME = 0.3,
    NOTIFICATION_DURATION = 3,
    
    -- Paths
    MODULE_PATH = "src.client.Currency",
    SHARED_PATH = "src.shared.core.ui",
    ECONOMY_PATH = "src.shared.core.economy",
    
    -- Feature flags
    ENABLE_ROBUX_PURCHASES = true,
    ENABLE_COIN_PURCHASES = true,
    ENABLE_PURCHASE_HISTORY = true,
    ENABLE_BALANCE_NOTIFICATIONS = true,
    
    -- Business logic
    MIN_PURCHASE_AMOUNT = 1,
    MAX_PURCHASE_AMOUNT = 10000,
    PURCHASE_CONFIRMATION_THRESHOLD = 100
}

-- Inventory system configuration
SystemConfig.INVENTORY = {
    -- System hierarchy
    PRIMARY_SYSTEM = "InventoryManager",
    FALLBACK_SYSTEMS = {"InventoryUI"},
    
    -- UI settings
    GRID_SIZE = 6,
    ITEM_ICON_SIZE = 64,
    ANIMATION_SPEED = 0.3,
    SEARCH_DEBOUNCE_TIME = 0.5,
    
    -- Paths
    MODULE_PATH = "src.client.Inventory",
    SHARED_PATH = "src.shared.core.ui",
    
    -- Feature flags
    ENABLE_SEARCH = true,
    ENABLE_SORTING = true,
    ENABLE_CATEGORIES = true,
    ENABLE_ITEM_PREVIEW = true,
    
    -- Performance settings
    MAX_ITEMS_PER_PAGE = 36,
    LAZY_LOAD_THRESHOLD = 50,
    CACHE_ITEM_ICONS = true
}

-- Placement system configuration
SystemConfig.PLACEMENT = {
    -- System settings
    MAX_PLACEMENT_DISTANCE = 20,
    PLACEMENT_GRID_SIZE = 1,
    ROTATION_SNAP_ANGLE = 45,
    
    -- UI settings
    PREVIEW_TRANSPARENCY = 0.5,
    VALID_COLOR = Color3.fromRGB(0, 255, 0),
    INVALID_COLOR = Color3.fromRGB(255, 0, 0),
    
    -- Paths
    MODULE_PATH = "src.shared.core.placement",
    
    -- Feature flags
    ENABLE_GRID_SNAPPING = true,
    ENABLE_ROTATION = true,
    ENABLE_COLLISION_CHECKING = true,
    ENABLE_TERRAIN_ADAPTATION = true,
    
    -- Performance settings
    COLLISION_CHECK_FREQUENCY = 0.1,
    MAX_PLACED_ITEMS = 1000
}

-- Data management configuration
SystemConfig.DATA = {
    -- Backup settings
    BACKUP_INTERVAL = 300, -- 5 minutes
    MAX_BACKUP_VERSIONS = 10,
    COMPRESSION_ENABLED = true,
    
    -- DataStore settings
    RETRY_ATTEMPTS = 3,
    RETRY_DELAY = 2,
    BATCH_SIZE = 50,
    
    -- Feature flags
    ENABLE_AUTO_BACKUP = true,
    ENABLE_DATA_VALIDATION = true,
    ENABLE_CORRUPTION_RECOVERY = true
}

-- UI theme configuration
SystemConfig.UI_THEME = {
    -- Colors
    PRIMARY_COLOR = Color3.fromRGB(0, 170, 255),
    SECONDARY_COLOR = Color3.fromRGB(40, 40, 40),
    BACKGROUND_COLOR = Color3.fromRGB(25, 25, 25),
    TEXT_COLOR = Color3.fromRGB(255, 255, 255),
    SUCCESS_COLOR = Color3.fromRGB(0, 200, 0),
    WARNING_COLOR = Color3.fromRGB(255, 200, 0),
    ERROR_COLOR = Color3.fromRGB(255, 50, 50),
    
    -- Fonts
    PRIMARY_FONT = Enum.Font.GothamBold,
    SECONDARY_FONT = Enum.Font.Gotham,
    MONOSPACE_FONT = Enum.Font.RobotoMono,
    
    -- Sizes
    HEADER_TEXT_SIZE = 24,
    BODY_TEXT_SIZE = 16,
    CAPTION_TEXT_SIZE = 12,
    
    -- Spacing
    PADDING_SMALL = 8,
    PADDING_MEDIUM = 16,
    PADDING_LARGE = 24,
    
    -- Animation
    TWEEN_TIME = 0.3,
    EASE_STYLE = Enum.EasingStyle.Quad,
    EASE_DIRECTION = Enum.EasingDirection.Out
}

-- Performance monitoring configuration
SystemConfig.PERFORMANCE = {
    -- Monitoring settings
    ENABLE_FPS_MONITORING = true,
    ENABLE_MEMORY_MONITORING = true,
    ENABLE_NETWORK_MONITORING = true,
    
    -- Thresholds
    MIN_FPS_THRESHOLD = 30,
    MAX_MEMORY_THRESHOLD = 500, -- MB
    MAX_NETWORK_LATENCY = 200, -- ms
    
    -- Reporting
    REPORT_INTERVAL = 60,
    MAX_PERFORMANCE_LOGS = 100
}

-- Development and debugging configuration
SystemConfig.DEBUG = {
    -- Debug levels
    LEVEL_NONE = 0,
    LEVEL_ERROR = 1,
    LEVEL_WARNING = 2,
    LEVEL_INFO = 3,
    LEVEL_VERBOSE = 4,
    
    -- Current debug level (change this to control logging)
    CURRENT_LEVEL = 2, -- WARNING level by default
    
    -- Feature flags for debugging
    ENABLE_SYSTEM_PROFILING = false,
    ENABLE_CALL_TRACING = false,
    ENABLE_PERFORMANCE_OVERLAY = false,
    ENABLE_ERROR_NOTIFICATIONS = true,
    
    -- Debug UI settings
    OVERLAY_POSITION = UDim2.new(0, 10, 0, 10),
    OVERLAY_SIZE = UDim2.new(0, 300, 0, 200),
    LOG_HISTORY_SIZE = 50
}

-- Environment-specific configurations
SystemConfig.ENVIRONMENT = {
    DEVELOPMENT = {
        DEBUG_MODE = true,
        HEALTH_CHECK_INTERVAL = 10,
        ENABLE_ALL_FEATURES = true,
        MOCK_PURCHASES = true
    },
    
    TESTING = {
        DEBUG_MODE = true,
        HEALTH_CHECK_INTERVAL = 5,
        ENABLE_ALL_FEATURES = true,
        MOCK_PURCHASES = true,
        ACCELERATED_TIMERS = true
    },
    
    PRODUCTION = {
        DEBUG_MODE = false,
        HEALTH_CHECK_INTERVAL = 30,
        ENABLE_ALL_FEATURES = true,
        MOCK_PURCHASES = false,
        PERFORMANCE_MONITORING = true
    }
}

-- Helper functions for configuration management
SystemConfig.Utils = {}

-- Get configuration for a specific system
function SystemConfig.Utils.GetSystemConfig(systemName)
    local config = SystemConfig[systemName:upper()]
    if not config then
        warn("SystemConfig: No configuration found for system:", systemName)
        return {}
    end
    return config
end

-- Merge configurations (useful for overrides)
function SystemConfig.Utils.MergeConfigs(baseConfig, overrideConfig)
    local merged = {}
    
    -- Copy base config
    for key, value in pairs(baseConfig) do
        if type(value) == "table" then
            merged[key] = SystemConfig.Utils.MergeConfigs(value, {})
        else
            merged[key] = value
        end
    end
    
    -- Apply overrides
    for key, value in pairs(overrideConfig) do
        if type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = SystemConfig.Utils.MergeConfigs(merged[key], value)
        else
            merged[key] = value
        end
    end
    
    return merged
end

-- Get environment-specific configuration
function SystemConfig.Utils.GetEnvironmentConfig()
    -- Determine environment (you can customize this logic)
    local environment = "PRODUCTION" -- Default
    
    if game:GetService("RunService"):IsStudio() then
        environment = "DEVELOPMENT"
    elseif game.PlaceId == 0 then -- Test place
        environment = "TESTING"
    end
    
    return SystemConfig.ENVIRONMENT[environment] or SystemConfig.ENVIRONMENT.PRODUCTION
end

-- Apply environment-specific overrides to global config
function SystemConfig.Utils.ApplyEnvironmentOverrides()
    local envConfig = SystemConfig.Utils.GetEnvironmentConfig()
    SystemConfig.GLOBAL = SystemConfig.Utils.MergeConfigs(SystemConfig.GLOBAL, envConfig)
end

-- Validate configuration values
function SystemConfig.Utils.ValidateConfig(config, schema)
    -- Basic validation - can be expanded
    for key, expectedType in pairs(schema) do
        local value = config[key]
        if value ~= nil and type(value) ~= expectedType then
            warn(string.format("SystemConfig: Invalid type for %s. Expected %s, got %s", 
                key, expectedType, type(value)))
            return false
        end
    end
    return true
end

-- Get a configuration value with fallback
function SystemConfig.Utils.GetConfigValue(systemName, key, fallback)
    local systemConfig = SystemConfig.Utils.GetSystemConfig(systemName)
    local value = systemConfig[key]
    
    if value ~= nil then
        return value
    end
    
    -- Check global config
    value = SystemConfig.GLOBAL[key]
    if value ~= nil then
        return value
    end
    
    -- Return fallback
    return fallback
end

-- Debug function to print all configurations
function SystemConfig.Utils.PrintAllConfigs()
    print("=== SystemConfig Debug Output ===")
    for systemName, config in pairs(SystemConfig) do
        if type(config) == "table" and systemName ~= "Utils" then
            print(string.format("[%s]", systemName))
            for key, value in pairs(config) do
                print(string.format("  %s = %s", key, tostring(value)))
            end
            print()
        end
    end
end

-- Initialize environment-specific settings
SystemConfig.Utils.ApplyEnvironmentOverrides()

return SystemConfig 