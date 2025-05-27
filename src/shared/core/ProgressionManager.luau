-- ProgressionManager.luau
-- Handles XP progression, leveling, and rewards for players

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IS_SERVER = RunService:IsServer()

local ProgressionManager = {}
ProgressionManager.__index = ProgressionManager

-- XP Configuration
local XP_CONFIG = {
    MAX_LEVEL = 50,
    TOTAL_ITEMS_TO_MAX = 5000, -- Total items needed to reach level 50
    
    -- XP Sources
    XP_SOURCES = {
        PLACE_ITEM = 1.0, -- Base XP per item placed
        COMPLETE_BUILD = 25, -- Bonus XP for completing builds
        COLLABORATE = 50, -- XP for collaborative projects
        TEACH_PLAYER = 30, -- XP for helping new players
        WIN_COMPETITION = 100, -- XP for winning building competitions
        DAILY_LOGIN = 10, -- Daily login bonus XP
    },
    
    -- Reward Configuration
    REWARDS = {
        DISCOUNT_PER_LEVEL = 1, -- 1% discount per level (50% max at level 50)
        MAX_DISCOUNT = 50, -- Maximum discount percentage
    }
}

-- Security and rate limiting configuration
local SECURITY_CONFIG = {
    MAX_XP_PER_MINUTE = 200, -- Maximum XP a player can earn per minute
    MAX_ITEMS_PER_MINUTE = 100, -- Maximum items a player can place per minute
    SUSPICIOUS_XP_THRESHOLD = 500, -- XP amount that triggers admin notification
    DATA_VALIDATION_ENABLED = true,
    RATE_LIMIT_ENABLED = true
}

-- Performance and reliability configuration
local PERFORMANCE_CONFIG = {
    SAVE_BATCH_SIZE = 10, -- Maximum number of saves to batch together
    SAVE_INTERVAL = 300, -- Auto-save every 5 minutes
    CACHE_CLEANUP_INTERVAL = 600, -- Clean up disconnected players every 10 minutes
    BACKUP_ENABLED = true,
    BACKUP_INTERVAL = 3600, -- Backup every hour
    METRICS_ENABLED = true
}

-- Achievement definitions
local ACHIEVEMENTS = {
    FIRST_ITEM = {
        id = "first_item",
        name = "First Steps",
        description = "Place your first item",
        requirement = { type = "items_placed", value = 1 },
        reward = { xp = 10 },
        icon = "🎯"
    },
    ITEM_MILESTONE_10 = {
        id = "item_milestone_10",
        name = "Builder",
        description = "Place 10 items",
        requirement = { type = "items_placed", value = 10 },
        reward = { xp = 25 },
        icon = "🔨"
    },
    ITEM_MILESTONE_50 = {
        id = "item_milestone_50",
        name = "Architect",
        description = "Place 50 items",
        requirement = { type = "items_placed", value = 50 },
        reward = { xp = 50 },
        icon = "🏗️"
    },
    ITEM_MILESTONE_100 = {
        id = "item_milestone_100",
        name = "Master Builder",
        description = "Place 100 items",
        requirement = { type = "items_placed", value = 100 },
        reward = { xp = 100 },
        icon = "👷"
    },
    ITEM_MILESTONE_500 = {
        id = "item_milestone_500",
        name = "Construction Expert",
        description = "Place 500 items",
        requirement = { type = "items_placed", value = 500 },
        reward = { xp = 250 },
        icon = "🏭"
    },
    LEVEL_MILESTONE_10 = {
        id = "level_milestone_10",
        name = "Rising Star",
        description = "Reach level 10",
        requirement = { type = "level", value = 10 },
        reward = { xp = 50 },
        icon = "⭐"
    },
    LEVEL_MILESTONE_25 = {
        id = "level_milestone_25",
        name = "Veteran Builder",
        description = "Reach level 25",
        requirement = { type = "level", value = 25 },
        reward = { xp = 100 },
        icon = "🌟"
    },
    LEVEL_MILESTONE_50 = {
        id = "level_milestone_50",
        name = "Legendary Builder",
        description = "Reach maximum level",
        requirement = { type = "level", value = 50 },
        reward = { xp = 200 },
        icon = "👑"
    },
    DAILY_STREAK_7 = {
        id = "daily_streak_7",
        name = "Dedicated",
        description = "Login for 7 consecutive days",
        requirement = { type = "daily_streak", value = 7 },
        reward = { xp = 75 },
        icon = "📅"
    }
}

-- Calculate XP required for a specific level using exponential curve
-- Front-loaded: easier in the beginning, much harder at the end
local function calculateXPForLevel(level)
    if level <= 1 then return 0 end
    
    -- Use exponential growth with higher exponent for back-loading difficulty
    -- Base formula: XP = base * (level^exponent)
    local base = 15 -- Starting requirement
    local exponent = 2.3 -- Exponential growth factor
    
    -- Scale factor to reach exactly 5000 items at level 50
    local scaleFactor = XP_CONFIG.TOTAL_ITEMS_TO_MAX / (base * (XP_CONFIG.MAX_LEVEL ^ exponent))
    
    return math.floor(base * scaleFactor * (level ^ exponent))
end

-- Pre-calculate XP requirements for all levels
local LEVEL_XP_REQUIREMENTS = {}
local CUMULATIVE_XP_REQUIREMENTS = {}

local function initializeLevelRequirements()
    LEVEL_XP_REQUIREMENTS[1] = 0
    CUMULATIVE_XP_REQUIREMENTS[1] = 0
    
    for level = 2, XP_CONFIG.MAX_LEVEL + 1 do
        LEVEL_XP_REQUIREMENTS[level] = calculateXPForLevel(level)
        CUMULATIVE_XP_REQUIREMENTS[level] = CUMULATIVE_XP_REQUIREMENTS[level - 1] + LEVEL_XP_REQUIREMENTS[level]
    end
    
    -- Debug: Print level progression
    print("=== XP PROGRESSION TABLE ===")
    for level = 1, math.min(XP_CONFIG.MAX_LEVEL, 10) do
        local required = LEVEL_XP_REQUIREMENTS[level]
        local cumulative = CUMULATIVE_XP_REQUIREMENTS[level]
        print(string.format("Level %d: %d XP needed (Total: %d)", level, required, cumulative))
    end
    
    -- Print higher levels to show exponential growth
    local checkLevels = {20, 30, 40, 45, 48, 49, 50}
    for _, level in ipairs(checkLevels) do
        if level <= XP_CONFIG.MAX_LEVEL then
            local required = LEVEL_XP_REQUIREMENTS[level]
            local cumulative = CUMULATIVE_XP_REQUIREMENTS[level]
            print(string.format("Level %d: %d XP needed (Total: %d)", level, required, cumulative))
        end
    end
    
    print(string.format("Total XP for max level (%d): %d", XP_CONFIG.MAX_LEVEL, CUMULATIVE_XP_REQUIREMENTS[XP_CONFIG.MAX_LEVEL]))
    print("===============================")
end

-- Initialize the XP requirements table
initializeLevelRequirements()

function ProgressionManager.new()
    local self = setmetatable({}, ProgressionManager)
    
    if IS_SERVER then
        self.playerProgression = {} -- Cache for player progression data
        self.dataService = nil -- Will be set during initialization
        self.remotes = {} -- Remote events for UI communication
        
        -- Security tracking
        self.rateLimits = {} -- Track rate limits per player
        self.suspiciousActivity = {} -- Track suspicious activity
        
        -- Performance tracking
        self.saveQueue = {} -- Queue for batched saves
        self.metrics = { -- System metrics
            totalXPAwarded = 0,
            totalLevelUps = 0,
            totalAchievements = 0,
            averageSessionTime = 0,
            activeUsers = 0
        }
        
        -- Backup data
        self.backupData = {}
    end
    
    return self
end

-- Initialize the ProgressionManager
function ProgressionManager:Initialize(sharedModule)
    print("ProgressionManager: Initializing...")
    
    if IS_SERVER then
        -- Get reference to DataService
        if sharedModule and sharedModule.DataService then
            self.dataService = sharedModule.DataService
            print("ProgressionManager: DataService reference obtained")
        else
            warn("ProgressionManager: DataService not found in sharedModule")
        end
        
        -- Set up remote events for UI communication
        self:SetupRemoteEvents()
        
        -- Set up player handling
        self:SetupPlayerHandling()
        
        -- Start background processes
        self:StartBackgroundProcesses()
    end
    
    print("ProgressionManager: Initialization complete")
    return self
end

-- Set up remote events for client-server communication
function ProgressionManager:SetupRemoteEvents()
    if not IS_SERVER then return end
    
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Helper function to create remote events
    local function getOrCreateRemoteEvent(name)
        local event = remotesFolder:FindFirstChild(name)
        if not event then
            event = Instance.new("RemoteEvent")
            event.Name = name
            event.Parent = remotesFolder
            print("ProgressionManager: Created RemoteEvent:", name)
        end
        return event
    end
    
    -- Create remote events for progression UI
    self.remotes.UpdateProgression = getOrCreateRemoteEvent("UpdateProgression")
    self.remotes.RequestProgression = getOrCreateRemoteEvent("RequestProgression")
    
    -- Connect RequestProgression handler
    self.remotes.RequestProgression.OnServerEvent:Connect(function(player)
        self:SendProgressionUpdate(player)
    end)
    
    print("ProgressionManager: Remote events setup complete")
end

-- Send progression update to client
function ProgressionManager:SendProgressionUpdate(player)
    if not IS_SERVER or not self.remotes.UpdateProgression then return end
    
    local progressionData = self:GetPlayerProgression(player)
    if progressionData then
        self.remotes.UpdateProgression:FireClient(player, progressionData)
        print(string.format("ProgressionManager: Sent progression update to %s", player.Name))
    end
end

-- Send progression update to all clients (for admin commands)
function ProgressionManager:SendProgressionUpdateToAll(targetPlayer)
    if not IS_SERVER or not self.remotes.UpdateProgression then return end
    
    local progressionData = self:GetPlayerProgression(targetPlayer)
    if progressionData then
        self.remotes.UpdateProgression:FireAllClients(progressionData)
        print(string.format("ProgressionManager: Sent progression update to all clients for %s", targetPlayer.Name))
    end
end

-- Set up player event handling
function ProgressionManager:SetupPlayerHandling()
    if not IS_SERVER then return end
    
    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerProgression(player)
    end)
    
    -- Handle players leaving
    Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerProgression(player)
    end)
    
    -- Handle existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:InitializePlayerProgression(player)
    end
    
    print("ProgressionManager: Player handling setup complete")
end

-- Initialize progression data for a player
function ProgressionManager:InitializePlayerProgression(player)
    if not IS_SERVER then return end
    
    local userId = player.UserId
    
    -- Initialize with default values
    self.playerProgression[userId] = {
        level = 1,
        totalXP = 0,
        currentLevelXP = 0,
        itemsPlaced = 0,
        lastLoginTime = os.time(),
        achievements = {},
        rewards = {
            discountLevel = 1
        },
        isLoading = true,
        isLoaded = false
    }
    
    -- Load from DataStore
    self:LoadPlayerProgression(player)
end

-- Load player progression data
function ProgressionManager:LoadPlayerProgression(player)
    if not IS_SERVER or not self.dataService then return end
    
    local userId = player.UserId
    local progressionData = self.dataService:LoadData("PlayerProgression", tostring(userId))
    
    if progressionData then
        -- Validate loaded data
        if not self:ValidateProgressionData(progressionData) then
            warn("ProgressionManager: Invalid progression data for", player.Name, "- resetting to defaults")
            progressionData = nil
        end
    end
    
    if progressionData then
        -- Merge loaded data with defaults
        local playerData = self.playerProgression[userId]
        playerData.level = progressionData.level or 1
        playerData.totalXP = progressionData.totalXP or 0
        playerData.currentLevelXP = progressionData.currentLevelXP or 0
        playerData.itemsPlaced = progressionData.itemsPlaced or 0
        playerData.lastLoginTime = progressionData.lastLoginTime or os.time()
        playerData.achievements = progressionData.achievements or {}
        playerData.rewards = progressionData.rewards or { discountLevel = 1 }
        
        print(string.format("ProgressionManager: Loaded progression for %s - Level %d, %d XP, %d items placed", 
            player.Name, playerData.level, playerData.totalXP, playerData.itemsPlaced))
    else
        print(string.format("ProgressionManager: New player %s, starting at level 1", player.Name))
    end
    
    -- Update loading flags
    self.playerProgression[userId].isLoading = false
    self.playerProgression[userId].isLoaded = true
    
    -- Update reward level to match current level
    self:UpdatePlayerRewards(player)
    
    -- Check for daily login bonus
    self:CheckDailyLoginBonus(player)
    
    -- Send initial progression update to client
    task.wait(1) -- Small delay to ensure client is ready
    self:SendProgressionUpdate(player)
end

-- Check and award daily login bonus
function ProgressionManager:CheckDailyLoginBonus(player)
    if not IS_SERVER then return end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return end
    
    local currentTime = os.time()
    local lastLoginTime = playerData.lastLoginTime or 0
    
    -- Check if 24 hours have passed since last login (86400 seconds = 24 hours)
    local timeSinceLastLogin = currentTime - lastLoginTime
    if timeSinceLastLogin >= 86400 then -- 24 hours
        -- Award daily login bonus
        self:AwardXP(player, XP_CONFIG.XP_SOURCES.DAILY_LOGIN, "daily_login")
        
        -- Update last login time
        playerData.lastLoginTime = currentTime
        
        -- Send notification to player
        local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        if remotesFolder then
            local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
            if notifyRemote then
                notifyRemote:FireClient(player, string.format("Daily login bonus! +%d XP earned!", XP_CONFIG.XP_SOURCES.DAILY_LOGIN), "DailyBonus")
            end
        end
        
        print(string.format("ProgressionManager: Awarded daily login bonus to %s (+%d XP)", player.Name, XP_CONFIG.XP_SOURCES.DAILY_LOGIN))
    else
        -- Update login time for next check
        playerData.lastLoginTime = currentTime
    end
end

-- Award XP for completing builds
function ProgressionManager:OnBuildCompleted(player, buildData)
    if not IS_SERVER then return end
    
    self:AwardXP(player, XP_CONFIG.XP_SOURCES.COMPLETE_BUILD, "build_completion")
    
    -- Send notification
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
        if notifyRemote then
            notifyRemote:FireClient(player, string.format("Build completed! +%d XP earned!", XP_CONFIG.XP_SOURCES.COMPLETE_BUILD), "BuildComplete")
        end
    end
end

-- Award XP for collaboration
function ProgressionManager:OnCollaboration(player, collaborationType)
    if not IS_SERVER then return end
    
    self:AwardXP(player, XP_CONFIG.XP_SOURCES.COLLABORATE, "collaboration")
    
    -- Send notification
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
        if notifyRemote then
            notifyRemote:FireClient(player, string.format("Great collaboration! +%d XP earned!", XP_CONFIG.XP_SOURCES.COLLABORATE), "Collaboration")
        end
    end
end

-- Award XP for teaching another player
function ProgressionManager:OnTeachPlayer(player, studentPlayer)
    if not IS_SERVER then return end
    
    self:AwardXP(player, XP_CONFIG.XP_SOURCES.TEACH_PLAYER, "teaching")
    
    -- Send notification
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
        if notifyRemote then
            notifyRemote:FireClient(player, string.format("Thanks for helping a new player! +%d XP earned!", XP_CONFIG.XP_SOURCES.TEACH_PLAYER), "Teaching")
        end
    end
end

-- Award XP for winning competitions
function ProgressionManager:OnCompetitionWin(player, competitionType)
    if not IS_SERVER then return end
    
    self:AwardXP(player, XP_CONFIG.XP_SOURCES.WIN_COMPETITION, "competition_win")
    
    -- Send notification
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
        if notifyRemote then
            notifyRemote:FireClient(player, string.format("🏆 Competition winner! +%d XP earned!", XP_CONFIG.XP_SOURCES.WIN_COMPETITION), "CompetitionWin")
        end
    end
end

-- Save player progression data (with batching)
function ProgressionManager:SavePlayerProgression(player, skipQueue)
    if not IS_SERVER or not self.dataService then return end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return end
    
    -- Add to save queue instead of immediate save (unless skipQueue is true)
    if not skipQueue then
        -- Check if already in queue
        for _, queuedSave in ipairs(self.saveQueue) do
            if queuedSave.userId == userId then
                return -- Already queued
            end
        end
        
        table.insert(self.saveQueue, {
            player = player,
            userId = userId,
            timestamp = tick()
        })
        return
    end
    
    -- Immediate save (used by queue processor and critical saves)
    local success = self.dataService:SaveData("PlayerProgression", tostring(userId), {
        level = playerData.level,
        totalXP = playerData.totalXP,
        currentLevelXP = playerData.currentLevelXP,
        itemsPlaced = playerData.itemsPlaced,
        lastLoginTime = playerData.lastLoginTime,
        achievements = playerData.achievements,
        rewards = playerData.rewards
    })
    
    if success then
        playerData.lastSaveTime = tick()
        print(string.format("ProgressionManager: Saved progression for %s", player.Name))
    else
        warn(string.format("ProgressionManager: Failed to save progression for %s", player.Name))
        
        -- Re-queue failed save for retry
        table.insert(self.saveQueue, {
            player = player,
            userId = userId,
            timestamp = tick(),
            retryCount = (playerData.retryCount or 0) + 1
        })
    end
end

-- Validate progression data format
function ProgressionManager:ValidateProgressionData(data)
    if not SECURITY_CONFIG.DATA_VALIDATION_ENABLED then return true end
    
    if not data or type(data) ~= "table" then return false end
    
    -- Validate required fields and types
    if type(data.level) ~= "number" or data.level < 1 or data.level > XP_CONFIG.MAX_LEVEL then
        return false
    end
    
    if type(data.totalXP) ~= "number" or data.totalXP < 0 then
        return false
    end
    
    if type(data.currentLevelXP) ~= "number" or data.currentLevelXP < 0 then
        return false
    end
    
    if type(data.itemsPlaced) ~= "number" or data.itemsPlaced < 0 then
        return false
    end
    
    -- Validate XP consistency
    local expectedMinXP = CUMULATIVE_XP_REQUIREMENTS[data.level] or 0
    local expectedMaxXP = CUMULATIVE_XP_REQUIREMENTS[data.level + 1] or expectedMinXP + 1000
    
    if data.totalXP < expectedMinXP or data.totalXP > expectedMaxXP then
        warn("ProgressionManager: Invalid XP for level", data.level, "- Expected:", expectedMinXP, "-", expectedMaxXP, "Got:", data.totalXP)
        return false
    end
    
    return true
end

-- Check rate limits for player actions
function ProgressionManager:CheckRateLimit(player, action)
    if not SECURITY_CONFIG.RATE_LIMIT_ENABLED then return true end
    
    local userId = player.UserId
    local currentTime = tick()
    
    -- Initialize rate limit tracking for player
    if not self.rateLimits[userId] then
        self.rateLimits[userId] = {
            xpGained = {},
            itemsPlaced = {},
            lastReset = currentTime
        }
    end
    
    local limits = self.rateLimits[userId]
    
    -- Reset counters every minute
    if currentTime - limits.lastReset > 60 then
        limits.xpGained = {}
        limits.itemsPlaced = {}
        limits.lastReset = currentTime
    end
    
    -- Check specific rate limits
    if action == "xp_gain" then
        local xpThisMinute = 0
        for _, xpTime in ipairs(limits.xpGained) do
            if currentTime - xpTime.time < 60 then
                xpThisMinute = xpThisMinute + xpTime.amount
            end
        end
        
        if xpThisMinute > SECURITY_CONFIG.MAX_XP_PER_MINUTE then
            self:LogSuspiciousActivity(player, "excessive_xp_gain", {xpThisMinute = xpThisMinute})
            return false
        end
    elseif action == "item_placement" then
        local itemsThisMinute = 0
        for _, itemTime in ipairs(limits.itemsPlaced) do
            if currentTime - itemTime < 60 then
                itemsThisMinute = itemsThisMinute + 1
            end
        end
        
        if itemsThisMinute > SECURITY_CONFIG.MAX_ITEMS_PER_MINUTE then
            self:LogSuspiciousActivity(player, "excessive_item_placement", {itemsThisMinute = itemsThisMinute})
            return false
        end
    end
    
    return true
end

-- Log suspicious activity for admin review
function ProgressionManager:LogSuspiciousActivity(player, activityType, data)
    local userId = player.UserId
    local timestamp = os.time()
    
    if not self.suspiciousActivity[userId] then
        self.suspiciousActivity[userId] = {}
    end
    
    table.insert(self.suspiciousActivity[userId], {
        type = activityType,
        timestamp = timestamp,
        data = data
    })
    
    -- Alert admins to suspicious activity
    warn(string.format("SUSPICIOUS ACTIVITY: Player %s (%d) - %s at %s", 
        player.Name, userId, activityType, os.date("%X", timestamp)))
    
    -- TODO: Send notification to admin systems
end

-- Update rate limit tracking
function ProgressionManager:UpdateRateLimit(player, action, data)
    if not SECURITY_CONFIG.RATE_LIMIT_ENABLED then return end
    
    local userId = player.UserId
    local currentTime = tick()
    
    if not self.rateLimits[userId] then return end
    
    if action == "xp_gain" then
        table.insert(self.rateLimits[userId].xpGained, {
            time = currentTime,
            amount = data.amount or 0
        })
    elseif action == "item_placement" then
        table.insert(self.rateLimits[userId].itemsPlaced, currentTime)
    end
end

-- Award XP to a player (with security checks and metrics)
function ProgressionManager:AwardXP(player, xpAmount, source)
    if not IS_SERVER then return false end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then
        warn(string.format("ProgressionManager: Cannot award XP to %s - data not loaded", player.Name))
        return false
    end
    
    if playerData.level >= XP_CONFIG.MAX_LEVEL then
        print(string.format("ProgressionManager: %s is already at max level (%d)", player.Name, XP_CONFIG.MAX_LEVEL))
        return false
    end
    
    -- Security checks
    if xpAmount > SECURITY_CONFIG.SUSPICIOUS_XP_THRESHOLD then
        self:LogSuspiciousActivity(player, "large_xp_award", {amount = xpAmount, source = source})
    end
    
    if not self:CheckRateLimit(player, "xp_gain") then
        warn(string.format("ProgressionManager: Rate limit exceeded for %s - XP award blocked", player.Name))
        return false
    end
    
    -- Update rate limit tracking
    self:UpdateRateLimit(player, "xp_gain", {amount = xpAmount})
    
    -- Add XP
    playerData.totalXP = playerData.totalXP + xpAmount
    playerData.currentLevelXP = playerData.currentLevelXP + xpAmount
    
    -- Update metrics
    self.metrics.totalXPAwarded = self.metrics.totalXPAwarded + xpAmount
    
    print(string.format("ProgressionManager: Awarded %d XP to %s for %s (Total: %d)", 
        xpAmount, player.Name, source or "unknown", playerData.totalXP))
    
    -- Check for level up
    self:CheckLevelUp(player)
    
    -- Send progression update to client
    self:SendProgressionUpdate(player)
    
    -- Queue save (non-blocking)
    self:SavePlayerProgression(player)
    
    return true
end

-- Check if player should level up (with metrics)
function ProgressionManager:CheckLevelUp(player)
    if not IS_SERVER then return end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData then return end
    
    local oldLevel = playerData.level
    local requiredXP = LEVEL_XP_REQUIREMENTS[oldLevel + 1]
    local leveledUp = false
    
    -- Check if player has enough XP to level up
    while playerData.currentLevelXP >= requiredXP and playerData.level < XP_CONFIG.MAX_LEVEL do
        -- Level up!
        playerData.level = playerData.level + 1
        playerData.currentLevelXP = playerData.currentLevelXP - requiredXP
        leveledUp = true
        
        -- Update metrics
        self.metrics.totalLevelUps = self.metrics.totalLevelUps + 1
        
        print(string.format("🎉 LEVEL UP! %s reached level %d", player.Name, playerData.level))
        
        -- Update rewards
        self:UpdatePlayerRewards(player)
        
        -- Notify other systems about level up
        self:OnPlayerLevelUp(player, oldLevel, playerData.level)
        
        -- Send level up notification to client
        self:SendLevelUpNotification(player, oldLevel, playerData.level)
        
        -- Get next level requirement
        if playerData.level < XP_CONFIG.MAX_LEVEL then
            requiredXP = LEVEL_XP_REQUIREMENTS[playerData.level + 1]
        else
            -- Max level reached
            playerData.currentLevelXP = 0
            print(string.format("🏆 %s reached MAX LEVEL (%d)!", player.Name, XP_CONFIG.MAX_LEVEL))
            break
        end
        
        oldLevel = playerData.level
    end
    
    -- Force save on level up
    if leveledUp then
        self:SavePlayerProgression(player, true) -- Skip queue for immediate save
    end
end

-- Send level up notification to client
function ProgressionManager:SendLevelUpNotification(player, oldLevel, newLevel)
    if not IS_SERVER then return end
    
    -- Create or get notification remote
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then return end
    
    local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
    if notifyRemote then
        local message = string.format("🎉 LEVEL UP! You reached level %d! (+%d%% discount)", newLevel, newLevel)
        notifyRemote:FireClient(player, message, "LevelUp")
    end
end

-- Update player rewards based on level
function ProgressionManager:UpdatePlayerRewards(player)
    if not IS_SERVER then return end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData then return end
    
    -- Update discount level
    playerData.rewards.discountLevel = math.min(playerData.level, XP_CONFIG.MAX_LEVEL)
    
    print(string.format("ProgressionManager: Updated rewards for %s - Discount level: %d (%d%% discount)", 
        player.Name, playerData.rewards.discountLevel, self:GetPlayerDiscount(player)))
end

-- Get player's current discount percentage
function ProgressionManager:GetPlayerDiscount(player)
    if not player then return 0 end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return 0 end
    
    local discountPercent = math.min(
        playerData.rewards.discountLevel * XP_CONFIG.REWARDS.DISCOUNT_PER_LEVEL,
        XP_CONFIG.REWARDS.MAX_DISCOUNT
    )
    
    return discountPercent
end

-- Get player's progression information
function ProgressionManager:GetPlayerProgression(player)
    if not player then return nil end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData then return nil end
    
    local xpForNextLevel = 0
    if playerData.level < XP_CONFIG.MAX_LEVEL then
        xpForNextLevel = LEVEL_XP_REQUIREMENTS[playerData.level + 1]
    end
    
    return {
        level = playerData.level,
        totalXP = playerData.totalXP,
        currentLevelXP = playerData.currentLevelXP,
        xpForNextLevel = xpForNextLevel,
        itemsPlaced = playerData.itemsPlaced,
        discountPercent = self:GetPlayerDiscount(player),
        isMaxLevel = playerData.level >= XP_CONFIG.MAX_LEVEL,
        achievements = playerData.achievements or {}
    }
end

-- Track item placement for XP (with security checks)
function ProgressionManager:OnItemPlaced(player, itemId)
    if not IS_SERVER then return end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return end
    
    -- Check rate limit for item placement
    if not self:CheckRateLimit(player, "item_placement") then
        warn(string.format("ProgressionManager: Rate limit exceeded for %s - item placement blocked", player.Name))
        return
    end
    
    -- Update rate limit tracking
    self:UpdateRateLimit(player, "item_placement", {})
    
    -- Increment items placed counter
    playerData.itemsPlaced = playerData.itemsPlaced + 1
    
    -- Award XP
    self:AwardXP(player, XP_CONFIG.XP_SOURCES.PLACE_ITEM, "item_placement")
    
    -- Check achievements
    self:CheckAchievements(player)
    
    print(string.format("ProgressionManager: %s placed item %s (Total items: %d)", 
        player.Name, itemId, playerData.itemsPlaced))
end

-- Handle level up events (for notifications, achievements, etc.)
function ProgressionManager:OnPlayerLevelUp(player, oldLevel, newLevel)
    -- This can be extended for achievements, notifications, etc.
    print(string.format("ProgressionManager: Processing level up for %s: %d -> %d", player.Name, oldLevel, newLevel))
    
    -- Check for level-based achievements
    self:CheckAchievements(player)
end

-- Check achievements for a player (with metrics)
function ProgressionManager:CheckAchievements(player)
    if not IS_SERVER then return end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return end
    
    local unlockedAchievements = {}
    
    for achievementId, achievement in pairs(ACHIEVEMENTS) do
        -- Skip if already unlocked
        if playerData.achievements[achievementId] then
            continue
        end
        
        local isUnlocked = false
        
        -- Check achievement requirements
        if achievement.requirement.type == "items_placed" then
            isUnlocked = playerData.itemsPlaced >= achievement.requirement.value
        elseif achievement.requirement.type == "level" then
            isUnlocked = playerData.level >= achievement.requirement.value
        elseif achievement.requirement.type == "daily_streak" then
            -- TODO: Implement daily streak tracking
            isUnlocked = false
        end
        
        if isUnlocked then
            -- Unlock achievement
            playerData.achievements[achievementId] = {
                unlockedAt = os.time(),
                name = achievement.name,
                description = achievement.description,
                icon = achievement.icon
            }
            
            -- Award XP reward
            if achievement.reward and achievement.reward.xp then
                playerData.totalXP = playerData.totalXP + achievement.reward.xp
                playerData.currentLevelXP = playerData.currentLevelXP + achievement.reward.xp
            end
            
            table.insert(unlockedAchievements, achievement)
            
            -- Update metrics
            self.metrics.totalAchievements = self.metrics.totalAchievements + 1
            
            print(string.format("ProgressionManager: %s unlocked achievement '%s' (+%d XP)", 
                player.Name, achievement.name, achievement.reward.xp or 0))
        end
    end
    
    -- Send achievement notifications
    if #unlockedAchievements > 0 then
        self:SendAchievementNotifications(player, unlockedAchievements)
        
        -- Check for level ups after achievement XP
        self:CheckLevelUp(player)
        
        -- Update client
        self:SendProgressionUpdate(player)
        
        -- Force save on achievement unlock
        self:SavePlayerProgression(player, true)
    end
end

-- Send achievement notifications to client
function ProgressionManager:SendAchievementNotifications(player, achievements)
    if not IS_SERVER then return end
    
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then return end
    
    local notifyRemote = remotesFolder:FindFirstChild("NotifyPlayer")
    if not notifyRemote then return end
    
    for _, achievement in ipairs(achievements) do
        local message = string.format("%s Achievement Unlocked: %s - %s (+%d XP)", 
            achievement.icon, achievement.name, achievement.description, achievement.reward.xp or 0)
        notifyRemote:FireClient(player, message, "Achievement")
        
        task.wait(0.5) -- Small delay between multiple achievements
    end
end

-- Get player achievements
function ProgressionManager:GetPlayerAchievements(player)
    if not player then return {} end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData then return {} end
    
    return playerData.achievements or {}
end

-- Get XP configuration (for UI and other systems)
function ProgressionManager:GetXPConfig()
    return {
        MAX_LEVEL = XP_CONFIG.MAX_LEVEL,
        XP_SOURCES = XP_CONFIG.XP_SOURCES,
        REWARDS = XP_CONFIG.REWARDS,
        LEVEL_REQUIREMENTS = LEVEL_XP_REQUIREMENTS
    }
end

-- Administrative function to award XP (for testing/events)
function ProgressionManager:AdminAwardXP(player, amount, reason)
    if not IS_SERVER then return false end
    
    return self:AwardXP(player, amount, reason or "admin_award")
end

-- Administrative function to set player level (for testing)
function ProgressionManager:AdminSetLevel(player, level)
    if not IS_SERVER then return false end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return false end
    
    level = math.max(1, math.min(level, XP_CONFIG.MAX_LEVEL))
    
    -- Calculate required XP for target level
    local requiredXP = CUMULATIVE_XP_REQUIREMENTS[level] or 0
    
    -- Set player data
    playerData.level = level
    playerData.totalXP = requiredXP
    playerData.currentLevelXP = 0
    
    -- Update rewards
    self:UpdatePlayerRewards(player)
    
    -- Send progression update to client
    self:SendProgressionUpdate(player)
    
    print(string.format("ProgressionManager: Admin set %s to level %d", player.Name, level))
    
    return true
end

-- Administrative function to reset player progression (for testing)
function ProgressionManager:AdminResetProgression(player)
    if not IS_SERVER then return false end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData then return false end
    
    -- Reset to defaults
    playerData.level = 1
    playerData.totalXP = 0
    playerData.currentLevelXP = 0
    playerData.itemsPlaced = 0
    playerData.achievements = {}
    playerData.rewards = { discountLevel = 1 }
    
    -- Update rewards
    self:UpdatePlayerRewards(player)
    
    -- Send progression update to client
    self:SendProgressionUpdate(player)
    
    -- Save data
    self:SavePlayerProgression(player)
    
    print(string.format("ProgressionManager: Admin reset progression for %s", player.Name))
    
    return true
end

-- Administrative function to simulate item placements (for testing)
function ProgressionManager:AdminSimulateItems(player, itemCount)
    if not IS_SERVER then return false end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return false end
    
    itemCount = math.max(1, math.min(itemCount, 1000)) -- Limit to reasonable amount
    
    for i = 1, itemCount do
        self:OnItemPlaced(player, "test_item_" .. i)
        task.wait(0.01) -- Small delay to prevent lag
    end
    
    print(string.format("ProgressionManager: Admin simulated %d item placements for %s", itemCount, player.Name))
    
    return true
end

-- Administrative function to list all achievements (for testing)
function ProgressionManager:AdminListAchievements()
    if not IS_SERVER then return end
    
    print("=== ACHIEVEMENT LIST ===")
    for id, achievement in pairs(ACHIEVEMENTS) do
        print(string.format("%s %s - %s (Requirement: %s %d, Reward: %d XP)", 
            achievement.icon, achievement.name, achievement.description,
            achievement.requirement.type, achievement.requirement.value,
            achievement.reward.xp or 0))
    end
    print("========================")
end

-- Administrative function to unlock specific achievement (for testing)
function ProgressionManager:AdminUnlockAchievement(player, achievementId)
    if not IS_SERVER then return false end
    
    local userId = player.UserId
    local playerData = self.playerProgression[userId]
    
    if not playerData or not playerData.isLoaded then return false end
    
    local achievement = ACHIEVEMENTS[achievementId]
    if not achievement then
        warn("Achievement not found:", achievementId)
        return false
    end
    
    -- Check if already unlocked
    if playerData.achievements[achievementId] then
        print("Achievement already unlocked for", player.Name)
        return false
    end
    
    -- Unlock achievement
    playerData.achievements[achievementId] = {
        unlockedAt = os.time(),
        name = achievement.name,
        description = achievement.description,
        icon = achievement.icon
    }
    
    -- Award XP reward
    if achievement.reward and achievement.reward.xp then
        self:AwardXP(player, achievement.reward.xp, "admin_achievement")
    end
    
    -- Send notification
    self:SendAchievementNotifications(player, {achievement})
    
    print(string.format("ProgressionManager: Admin unlocked achievement '%s' for %s", achievement.name, player.Name))
    
    return true
end

-- Console command setup (for development)
function ProgressionManager:SetupConsoleCommands()
    if not IS_SERVER then return end
    
    -- Example usage in server console:
    -- _G.ProgressionManager:AdminAwardXP(game.Players.PlayerName, 100, "test")
    -- _G.ProgressionManager:AdminSetLevel(game.Players.PlayerName, 10)
    -- _G.ProgressionManager:AdminSimulateItems(game.Players.PlayerName, 50)
    -- _G.ProgressionManager:AdminResetProgression(game.Players.PlayerName)
    -- _G.ProgressionManager:AdminListAchievements()
    -- _G.ProgressionManager:AdminUnlockAchievement(game.Players.PlayerName, "FIRST_ITEM")
    -- _G.ProgressionManager:AdminGetSystemHealth()
    -- _G.ProgressionManager:GetSystemMetrics()
    
    print("ProgressionManager: Console commands available via _G.ProgressionManager:")
    print("  Player Commands:")
    print("    :AdminAwardXP(player, amount, reason)")
    print("    :AdminSetLevel(player, level)")
    print("    :AdminSimulateItems(player, itemCount)")
    print("    :AdminResetProgression(player)")
    print("    :AdminUnlockAchievement(player, achievementId)")
    print("    :GetPlayerProgression(player)")
    print("    :GetPlayerDiscount(player)")
    print("  System Commands:")
    print("    :AdminGetSystemHealth()")
    print("    :GetSystemMetrics()")
    print("    :AdminListAchievements()")
    print("    :CreateBackup()")
    print("    :ProcessSaveQueue()")
end

-- Start background maintenance processes
function ProgressionManager:StartBackgroundProcesses()
    if not IS_SERVER then return end
    
    -- Auto-save process
    task.spawn(function()
        while true do
            task.wait(PERFORMANCE_CONFIG.SAVE_INTERVAL)
            self:ProcessSaveQueue()
        end
    end)
    
    -- Cache cleanup process
    task.spawn(function()
        while true do
            task.wait(PERFORMANCE_CONFIG.CACHE_CLEANUP_INTERVAL)
            self:CleanupDisconnectedPlayers()
        end
    end)
    
    -- Backup process
    if PERFORMANCE_CONFIG.BACKUP_ENABLED then
        task.spawn(function()
            while true do
                task.wait(PERFORMANCE_CONFIG.BACKUP_INTERVAL)
                self:CreateBackup()
            end
        end)
    end
    
    -- Metrics collection
    if PERFORMANCE_CONFIG.METRICS_ENABLED then
        task.spawn(function()
            while true do
                task.wait(60) -- Update metrics every minute
                self:UpdateMetrics()
            end
        end)
    end
    
    print("ProgressionManager: Background processes started")
end

-- Process queued save operations in batches
function ProgressionManager:ProcessSaveQueue()
    if #self.saveQueue == 0 then return end
    
    local processed = 0
    local batchSize = math.min(#self.saveQueue, PERFORMANCE_CONFIG.SAVE_BATCH_SIZE)
    
    for i = 1, batchSize do
        local saveData = table.remove(self.saveQueue, 1)
        if saveData and saveData.player then
            self:SavePlayerProgression(saveData.player, true) -- Skip re-queuing
            processed = processed + 1
        end
    end
    
    if processed > 0 then
        print(string.format("ProgressionManager: Processed %d saves from queue (%d remaining)", processed, #self.saveQueue))
    end
end

-- Clean up data for disconnected players
function ProgressionManager:CleanupDisconnectedPlayers()
    local cleaned = 0
    local currentTime = tick()
    
    for userId, data in pairs(self.playerProgression) do
        -- Check if player is still connected
        local player = Players:GetPlayerByUserId(userId)
        if not player and data.lastSaveTime and (currentTime - data.lastSaveTime) > 300 then -- 5 minutes
            -- Clean up rate limits and suspicious activity for disconnected players
            self.rateLimits[userId] = nil
            if self.suspiciousActivity[userId] and #self.suspiciousActivity[userId] == 0 then
                self.suspiciousActivity[userId] = nil
            end
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        print(string.format("ProgressionManager: Cleaned up data for %d disconnected players", cleaned))
    end
end

-- Create backup of progression data
function ProgressionManager:CreateBackup()
    if not self.dataService then return end
    
    local backupData = {
        timestamp = os.time(),
        playerCount = 0,
        totalData = {}
    }
    
    -- Create backup of all player data
    for userId, data in pairs(self.playerProgression) do
        if data.isLoaded then
            backupData.totalData[tostring(userId)] = {
                level = data.level,
                totalXP = data.totalXP,
                currentLevelXP = data.currentLevelXP,
                itemsPlaced = data.itemsPlaced,
                achievements = data.achievements,
                rewards = data.rewards,
                lastLoginTime = data.lastLoginTime
            }
            backupData.playerCount = backupData.playerCount + 1
        end
    end
    
    -- Save backup
    local backupKey = "ProgressionBackup_" .. os.date("%Y%m%d_%H%M%S")
    local success = self.dataService:SaveData("SystemBackups", backupKey, backupData)
    
    if success then
        print(string.format("ProgressionManager: Created backup '%s' with %d players", backupKey, backupData.playerCount))
        
        -- Keep only last 24 backups (assuming hourly backups = 24 hours)
        self:CleanupOldBackups()
    else
        warn("ProgressionManager: Failed to create backup")
    end
end

-- Clean up old backup files
function ProgressionManager:CleanupOldBackups()
    -- TODO: Implement backup cleanup logic
    -- This would require DataService to support listing keys
end

-- Update system metrics
function ProgressionManager:UpdateMetrics()
    local activeUsers = 0
    local totalSessionTime = 0
    local currentTime = os.time()
    
    for userId, data in pairs(self.playerProgression) do
        local player = Players:GetPlayerByUserId(userId)
        if player and data.isLoaded then
            activeUsers = activeUsers + 1
            if data.lastLoginTime then
                totalSessionTime = totalSessionTime + (currentTime - data.lastLoginTime)
            end
        end
    end
    
    self.metrics.activeUsers = activeUsers
    if activeUsers > 0 then
        self.metrics.averageSessionTime = totalSessionTime / activeUsers
    end
    
    -- Log metrics periodically
    if currentTime % 300 == 0 then -- Every 5 minutes
        print(string.format("ProgressionManager Metrics: Active Users: %d, Avg Session: %.1f min, Total XP: %d, Level Ups: %d, Achievements: %d",
            self.metrics.activeUsers,
            self.metrics.averageSessionTime / 60,
            self.metrics.totalXPAwarded,
            self.metrics.totalLevelUps,
            self.metrics.totalAchievements))
    end
end

-- Get system metrics (for admin monitoring)
function ProgressionManager:GetSystemMetrics()
    if not IS_SERVER then return {} end
    
    return {
        activeUsers = self.metrics.activeUsers,
        totalXPAwarded = self.metrics.totalXPAwarded,
        totalLevelUps = self.metrics.totalLevelUps,
        totalAchievements = self.metrics.totalAchievements,
        averageSessionTime = self.metrics.averageSessionTime,
        saveQueueSize = #self.saveQueue,
        suspiciousActivityCount = #self.suspiciousActivity,
        cacheSize = table.maxn(self.playerProgression) or 0
    }
end

-- Administrative function to get system health
function ProgressionManager:AdminGetSystemHealth()
    if not IS_SERVER then return end
    
    local metrics = self:GetSystemMetrics()
    
    print("=== PROGRESSION SYSTEM HEALTH ===")
    print(string.format("Active Users: %d", metrics.activeUsers))
    print(string.format("Save Queue Size: %d", metrics.saveQueueSize))
    print(string.format("Cache Size: %d entries", metrics.cacheSize))
    print(string.format("Suspicious Activity Reports: %d", metrics.suspiciousActivityCount))
    print(string.format("Total XP Awarded: %d", metrics.totalXPAwarded))
    print(string.format("Total Level Ups: %d", metrics.totalLevelUps))
    print(string.format("Total Achievements: %d", metrics.totalAchievements))
    print(string.format("Average Session Time: %.1f minutes", metrics.averageSessionTime / 60))
    print("===============================")
end

return ProgressionManager 