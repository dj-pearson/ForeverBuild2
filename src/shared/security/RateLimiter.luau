-- RateLimiter.luau
-- Enterprise-level rate limiting system with sliding windows and adaptive throttling
-- Prevents abuse and ensures fair resource usage across all endpoints

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- Configuration for different endpoint types
local RATE_LIMITS = {
    -- Critical operations (placement, purchases)
    CRITICAL = {
        maxRequests = 5,
        windowSeconds = 10,
        burstLimit = 2,
        cooldownSeconds = 30
    },
    
    -- Standard operations (interactions, inventory)
    STANDARD = {
        maxRequests = 15,
        windowSeconds = 10,
        burstLimit = 5,
        cooldownSeconds = 5
    },
    
    -- High frequency operations (UI updates, queries)
    HIGH_FREQUENCY = {
        maxRequests = 50,
        windowSeconds = 10,
        burstLimit = 10,
        cooldownSeconds = 1
    },
    
    -- Admin operations
    ADMIN = {
        maxRequests = 100,
        windowSeconds = 10,
        burstLimit = 20,
        cooldownSeconds = 0
    }
}

-- Endpoint classifications
local ENDPOINT_TYPES = {
    -- Critical endpoints
    ["PlaceItem"] = "CRITICAL",
    ["PurchaseItem"] = "CRITICAL",
    ["DeleteItem"] = "CRITICAL",
    ["ProcessCurrencyPurchase"] = "CRITICAL",
    
    -- Standard endpoints
    ["InteractWithItem"] = "STANDARD",
    ["UseItem"] = "STANDARD",
    ["CollectItem"] = "STANDARD",
    ["RecallItem"] = "STANDARD",
    ["UpdateItem"] = "STANDARD",
    ["OnItemClicked"] = "STANDARD",
    ["OnItemAdded"] = "STANDARD",
    
    -- High frequency endpoints
    ["GetInventory"] = "HIGH_FREQUENCY",
    ["UpdateBalance"] = "HIGH_FREQUENCY",
    ["GetPlayerData"] = "HIGH_FREQUENCY",
    ["ValidateInput"] = "HIGH_FREQUENCY"
}

function RateLimiter.new()
    local self = setmetatable({}, RateLimiter)
    
    -- Player request tracking
    self.playerRequests = {}
    
    -- Endpoint statistics
    self.endpointStats = {}
    
    -- Violation tracking
    self.violations = {}
    
    -- Adaptive throttling data
    self.adaptiveThrottling = {}
    
    -- Global statistics
    self.globalStats = {
        totalRequests = 0,
        blockedRequests = 0,
        violationsDetected = 0,
        adaptiveAdjustments = 0
    }
    
    -- Cleanup timer
    self.lastCleanup = tick()
    self.cleanupInterval = 60 -- Clean up old data every minute
    
    return self
end

function RateLimiter:Initialize()
    print("[RateLimiter] Initializing enterprise rate limiting system...")
    
    -- Setup player tracking
    self:SetupPlayerTracking()
    
    -- Start cleanup loop
    self:StartCleanupLoop()
    
    -- Initialize endpoint statistics
    for endpoint, _ in pairs(ENDPOINT_TYPES) do
        self.endpointStats[endpoint] = {
            totalRequests = 0,
            blockedRequests = 0,
            averageResponseTime = 0,
            lastRequest = 0
        }
    end
    
    print("[RateLimiter] Rate limiting system initialized")
    return true
end

function RateLimiter:SetupPlayerTracking()
    -- Track existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:InitializePlayerTracking(player)
    end
    
    -- Track new players
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerTracking(player)
    end)
    
    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerTracking(player)
    end)
end

function RateLimiter:InitializePlayerTracking(player)
    local userId = player.UserId
    
    self.playerRequests[userId] = {}
    self.violations[userId] = {}
    self.adaptiveThrottling[userId] = {
        violationCount = 0,
        throttleMultiplier = 1.0,
        lastViolation = 0,
        trustScore = 1.0
    }
    
    print("[RateLimiter] Initialized tracking for player:", player.Name)
end

function RateLimiter:CleanupPlayerTracking(player)
    local userId = player.UserId
    
    self.playerRequests[userId] = nil
    self.violations[userId] = nil
    self.adaptiveThrottling[userId] = nil
    
    print("[RateLimiter] Cleaned up tracking for player:", player.Name)
end

function RateLimiter:CheckRateLimit(player, endpoint, requestData)
    if not player or not endpoint then
        return false, "Invalid request parameters"
    end
    
    local userId = player.UserId
    local currentTime = tick()
    
    -- Initialize player tracking if not exists
    if not self.playerRequests[userId] then
        self:InitializePlayerTracking(player)
    end
    
    -- Get endpoint type and limits
    local endpointType = ENDPOINT_TYPES[endpoint] or "STANDARD"
    local limits = RATE_LIMITS[endpointType]
    
    -- Check if player is admin (admins get special treatment)
    local isAdmin = self:IsPlayerAdmin(player)
    if isAdmin then
        limits = RATE_LIMITS.ADMIN
    end
    
    -- Apply adaptive throttling
    local adaptiveData = self.adaptiveThrottling[userId]
    if adaptiveData and adaptiveData.throttleMultiplier > 1.0 then
        limits = self:ApplyAdaptiveThrottling(limits, adaptiveData)
    end
    
    -- Check sliding window rate limit
    local allowed, reason = self:CheckSlidingWindow(userId, endpoint, limits, currentTime)
    
    -- Update statistics
    self:UpdateStatistics(endpoint, allowed, currentTime)
    
    if not allowed then
        -- Record violation
        self:RecordViolation(player, endpoint, reason, requestData)
        
        -- Update adaptive throttling
        self:UpdateAdaptiveThrottling(userId, currentTime)
        
        return false, reason
    end
    
    -- Record successful request
    self:RecordRequest(userId, endpoint, currentTime)
    
    return true, "Request allowed"
end

function RateLimiter:CheckSlidingWindow(userId, endpoint, limits, currentTime)
    local playerRequests = self.playerRequests[userId]
    if not playerRequests[endpoint] then
        playerRequests[endpoint] = {}
    end
    
    local endpointRequests = playerRequests[endpoint]
    
    -- Clean up old requests outside the window
    local windowStart = currentTime - limits.windowSeconds
    local validRequests = {}
    
    for _, requestTime in ipairs(endpointRequests) do
        if requestTime > windowStart then
            table.insert(validRequests, requestTime)
        end
    end
    
    playerRequests[endpoint] = validRequests
    
    -- Check if we're within limits
    local requestCount = #validRequests
    
    -- Check burst limit (requests in last second)
    local burstCount = 0
    local burstWindow = currentTime - 1
    for _, requestTime in ipairs(validRequests) do
        if requestTime > burstWindow then
            burstCount = burstCount + 1
        end
    end
    
    -- Check cooldown (minimum time between requests)
    if #validRequests > 0 and limits.cooldownSeconds > 0 then
        local lastRequest = validRequests[#validRequests]
        if currentTime - lastRequest < limits.cooldownSeconds then
            return false, string.format("Cooldown active. Wait %.1f seconds", 
                limits.cooldownSeconds - (currentTime - lastRequest))
        end
    end
    
    -- Check burst limit
    if burstCount >= limits.burstLimit then
        return false, string.format("Burst limit exceeded (%d/%d requests in 1 second)", 
            burstCount, limits.burstLimit)
    end
    
    -- Check window limit
    if requestCount >= limits.maxRequests then
        return false, string.format("Rate limit exceeded (%d/%d requests in %d seconds)", 
            requestCount, limits.maxRequests, limits.windowSeconds)
    end
    
    return true, "Within limits"
end

function RateLimiter:ApplyAdaptiveThrottling(baseLimits, adaptiveData)
    local throttledLimits = {}
    
    for key, value in pairs(baseLimits) do
        if key == "maxRequests" or key == "burstLimit" then
            -- Reduce limits based on throttle multiplier
            throttledLimits[key] = math.max(1, math.floor(value / adaptiveData.throttleMultiplier))
        elseif key == "windowSeconds" or key == "cooldownSeconds" then
            -- Increase time windows
            throttledLimits[key] = value * adaptiveData.throttleMultiplier
        else
            throttledLimits[key] = value
        end
    end
    
    return throttledLimits
end

function RateLimiter:UpdateAdaptiveThrottling(userId, currentTime)
    local adaptiveData = self.adaptiveThrottling[userId]
    if not adaptiveData then return end
    
    adaptiveData.violationCount = adaptiveData.violationCount + 1
    adaptiveData.lastViolation = currentTime
    
    -- Increase throttle multiplier based on violations
    if adaptiveData.violationCount >= 3 then
        adaptiveData.throttleMultiplier = math.min(5.0, adaptiveData.throttleMultiplier * 1.5)
        adaptiveData.trustScore = math.max(0.1, adaptiveData.trustScore * 0.8)
        
        self.globalStats.adaptiveAdjustments = self.globalStats.adaptiveAdjustments + 1
        
        print(string.format("[RateLimiter] Adaptive throttling increased for user %d: multiplier %.2f, trust %.2f", 
            userId, adaptiveData.throttleMultiplier, adaptiveData.trustScore))
    end
end

function RateLimiter:RecordRequest(userId, endpoint, currentTime)
    local playerRequests = self.playerRequests[userId]
    if not playerRequests[endpoint] then
        playerRequests[endpoint] = {}
    end
    
    table.insert(playerRequests[endpoint], currentTime)
    
    -- Update global statistics
    self.globalStats.totalRequests = self.globalStats.totalRequests + 1
    
    -- Update endpoint statistics
    local stats = self.endpointStats[endpoint]
    if stats then
        stats.totalRequests = stats.totalRequests + 1
        stats.lastRequest = currentTime
    end
end

function RateLimiter:RecordViolation(player, endpoint, reason, requestData)
    local userId = player.UserId
    
    if not self.violations[userId] then
        self.violations[userId] = {}
    end
    
    local violation = {
        endpoint = endpoint,
        reason = reason,
        timestamp = tick(),
        requestData = requestData,
        playerName = player.Name
    }
    
    table.insert(self.violations[userId], violation)
    
    -- Update global statistics
    self.globalStats.blockedRequests = self.globalStats.blockedRequests + 1
    self.globalStats.violationsDetected = self.globalStats.violationsDetected + 1
    
    -- Update endpoint statistics
    local stats = self.endpointStats[endpoint]
    if stats then
        stats.blockedRequests = stats.blockedRequests + 1
    end
    
    -- Log violation
    warn(string.format("🚫 RATE LIMIT: Player %s (%d) - %s: %s", 
        player.Name, userId, endpoint, reason))
end

function RateLimiter:UpdateStatistics(endpoint, allowed, currentTime)
    local stats = self.endpointStats[endpoint]
    if not stats then return end
    
    if allowed then
        -- Update average response time (simplified)
        local responseTime = tick() - currentTime
        if stats.averageResponseTime == 0 then
            stats.averageResponseTime = responseTime
        else
            stats.averageResponseTime = (stats.averageResponseTime * 0.9) + (responseTime * 0.1)
        end
    end
end

function RateLimiter:StartCleanupLoop()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        if currentTime - self.lastCleanup >= self.cleanupInterval then
            self:PerformCleanup(currentTime)
            self.lastCleanup = currentTime
        end
    end)
end

function RateLimiter:PerformCleanup(currentTime)
    local cleanupAge = 300 -- Clean up data older than 5 minutes
    local cutoffTime = currentTime - cleanupAge
    
    -- Clean up old requests
    for userId, playerRequests in pairs(self.playerRequests) do
        for endpoint, requests in pairs(playerRequests) do
            local validRequests = {}
            for _, requestTime in ipairs(requests) do
                if requestTime > cutoffTime then
                    table.insert(validRequests, requestTime)
                end
            end
            playerRequests[endpoint] = validRequests
        end
    end
    
    -- Clean up old violations
    for userId, violations in pairs(self.violations) do
        local validViolations = {}
        for _, violation in ipairs(violations) do
            if violation.timestamp > cutoffTime then
                table.insert(validViolations, violation)
            end
        end
        self.violations[userId] = validViolations
    end
    
    -- Reset adaptive throttling for players who haven't violated recently
    for userId, adaptiveData in pairs(self.adaptiveThrottling) do
        if currentTime - adaptiveData.lastViolation > 300 then -- 5 minutes
            -- Gradually restore trust and reduce throttling
            adaptiveData.throttleMultiplier = math.max(1.0, adaptiveData.throttleMultiplier * 0.9)
            adaptiveData.trustScore = math.min(1.0, adaptiveData.trustScore * 1.1)
            
            if adaptiveData.throttleMultiplier <= 1.1 then
                adaptiveData.violationCount = 0
                adaptiveData.throttleMultiplier = 1.0
                adaptiveData.trustScore = 1.0
            end
        end
    end
    
    print("[RateLimiter] Cleanup completed - removed old data and restored trust scores")
end

function RateLimiter:IsPlayerAdmin(player)
    -- Check if player is admin (integrate with your admin system)
    local adminIds = {
        3246397734, -- Default Roblox test account ID
        7768610061  -- Your actual user ID (Xdjpearsonx)
    }
    
    for _, adminId in ipairs(adminIds) do
        if player.UserId == adminId then
            return true
        end
    end
    
    return player:GetAttribute("IsAdmin") == true
end

function RateLimiter:GetPlayerStats(player)
    local userId = player.UserId
    
    local playerRequests = self.playerRequests[userId] or {}
    local violations = self.violations[userId] or {}
    local adaptiveData = self.adaptiveThrottling[userId]
    
    local totalRequests = 0
    for _, requests in pairs(playerRequests) do
        totalRequests = totalRequests + #requests
    end
    
    return {
        totalRequests = totalRequests,
        totalViolations = #violations,
        throttleMultiplier = adaptiveData and adaptiveData.throttleMultiplier or 1.0,
        trustScore = adaptiveData and adaptiveData.trustScore or 1.0,
        recentViolations = #violations > 0 and violations[#violations] or nil
    }
end

function RateLimiter:GetEndpointStats(endpoint)
    return self.endpointStats[endpoint] or {
        totalRequests = 0,
        blockedRequests = 0,
        averageResponseTime = 0,
        lastRequest = 0
    }
end

function RateLimiter:GetGlobalStats()
    return {
        totalRequests = self.globalStats.totalRequests,
        blockedRequests = self.globalStats.blockedRequests,
        violationsDetected = self.globalStats.violationsDetected,
        adaptiveAdjustments = self.globalStats.adaptiveAdjustments,
        blockRate = self.globalStats.totalRequests > 0 and 
                   (self.globalStats.blockedRequests / self.globalStats.totalRequests * 100) or 0,
        playersTracked = self:CountTable(self.playerRequests),
        endpointsMonitored = self:CountTable(self.endpointStats)
    }
end

function RateLimiter:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Convenience function for easy integration
function RateLimiter:WrapFunction(originalFunction, endpoint)
    return function(...)
        local args = {...}
        local player = args[1] -- Assume first argument is player
        
        if not player or not player:IsA("Player") then
            return originalFunction(...)
        end
        
        local allowed, reason = self:CheckRateLimit(player, endpoint, {args = args})
        
        if not allowed then
            warn("[RateLimiter] Blocked call to", endpoint, "for", player.Name, ":", reason)
            return false, reason
        end
        
        return originalFunction(...)
    end
end

function RateLimiter:Cleanup()
    print("[RateLimiter] Cleaning up...")
    
    -- Clear all data
    self.playerRequests = {}
    self.violations = {}
    self.adaptiveThrottling = {}
    self.endpointStats = {}
    
    print("[RateLimiter] Cleanup complete")
end

return RateLimiter 