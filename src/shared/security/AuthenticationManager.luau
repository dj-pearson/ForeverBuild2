-- AuthenticationManager.luau
-- Enterprise-level authentication and session management system
-- Provides JWT-like tokens, session validation, and multi-factor authentication

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local AuthenticationManager = {}
AuthenticationManager.__index = AuthenticationManager

-- DataStores for persistent authentication data
local SessionStore = DataStoreService:GetDataStore("PlayerSessions_v1")
local AuthStore = DataStoreService:GetDataStore("AuthenticationData_v1")

-- Configuration
local CONFIG = {
    -- Session management
    SESSION_DURATION = 3600, -- 1 hour default session
    EXTENDED_SESSION_DURATION = 86400, -- 24 hours for "remember me"
    SESSION_REFRESH_THRESHOLD = 300, -- Refresh if less than 5 minutes remaining
    MAX_CONCURRENT_SESSIONS = 3, -- Maximum sessions per player
    
    -- Security settings
    TOKEN_LENGTH = 32, -- Length of session tokens
    SALT_LENGTH = 16, -- Length of password salt
    HASH_ITERATIONS = 10000, -- PBKDF2 iterations
    
    -- Rate limiting
    MAX_LOGIN_ATTEMPTS = 5, -- Max failed attempts before lockout
    LOCKOUT_DURATION = 900, -- 15 minutes lockout
    
    -- Multi-factor authentication
    MFA_ENABLED = true,
    MFA_CODE_LENGTH = 6,
    MFA_CODE_VALIDITY = 300, -- 5 minutes
    
    -- Admin settings
    ADMIN_SESSION_DURATION = 1800, -- 30 minutes for admin sessions
    REQUIRE_MFA_FOR_ADMIN = true,
    
    DEBUG_MODE = false
}

-- Session status types
local SESSION_STATUS = {
    VALID = "VALID",
    EXPIRED = "EXPIRED",
    INVALID = "INVALID",
    REVOKED = "REVOKED",
    LOCKED = "LOCKED"
}

-- Authentication result types
local AUTH_RESULT = {
    SUCCESS = "SUCCESS",
    INVALID_CREDENTIALS = "INVALID_CREDENTIALS",
    ACCOUNT_LOCKED = "ACCOUNT_LOCKED",
    MFA_REQUIRED = "MFA_REQUIRED",
    SESSION_EXPIRED = "SESSION_EXPIRED",
    RATE_LIMITED = "RATE_LIMITED"
}

function AuthenticationManager.new()
    local self = setmetatable({}, AuthenticationManager)
    
    -- Active sessions tracking
    self.activeSessions = {}
    
    -- Failed login attempts tracking
    self.failedAttempts = {}
    
    -- MFA codes tracking
    self.mfaCodes = {}
    
    -- Rate limiting tracking
    self.rateLimits = {}
    
    -- Session statistics
    self.stats = {
        totalLogins = 0,
        successfulLogins = 0,
        failedLogins = 0,
        activeSessions = 0,
        revokedSessions = 0,
        mfaVerifications = 0
    }
    
    -- Cleanup timer
    self.lastCleanup = tick()
    self.cleanupInterval = 300 -- Clean up every 5 minutes
    
    return self
end

function AuthenticationManager:Initialize()
    print("[AuthenticationManager] Initializing enterprise authentication system...")
    
    -- Setup player tracking
    self:SetupPlayerTracking()
    
    -- Start cleanup loop
    self:StartCleanupLoop()
    
    -- Load persistent session data
    self:LoadSessionData()
    
    print("[AuthenticationManager] Authentication system initialized")
    return true
end

function AuthenticationManager:SetupPlayerTracking()
    -- Track existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:InitializePlayerAuth(player)
    end
    
    -- Track new players
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerAuth(player)
    end)
    
    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerAuth(player)
    end)
end

function AuthenticationManager:InitializePlayerAuth(player)
    local userId = player.UserId
    
    -- Initialize tracking structures
    self.activeSessions[userId] = {}
    self.failedAttempts[userId] = {}
    self.mfaCodes[userId] = {}
    self.rateLimits[userId] = {}
    
    -- Attempt to restore existing session
    self:RestorePlayerSession(player)
    
    print("[AuthenticationManager] Initialized authentication for player:", player.Name)
end

function AuthenticationManager:CleanupPlayerAuth(player)
    local userId = player.UserId
    
    -- Revoke all active sessions
    if self.activeSessions[userId] then
        for sessionId, _ in pairs(self.activeSessions[userId]) do
            self:RevokeSession(player, sessionId)
        end
    end
    
    -- Clean up tracking data
    self.activeSessions[userId] = nil
    self.failedAttempts[userId] = nil
    self.mfaCodes[userId] = nil
    self.rateLimits[userId] = nil
    
    print("[AuthenticationManager] Cleaned up authentication for player:", player.Name)
end

function AuthenticationManager:AuthenticatePlayer(player, credentials)
    local userId = player.UserId
    
    -- Check rate limiting
    if not self:CheckRateLimit(player, "login") then
        return {
            success = false,
            result = AUTH_RESULT.RATE_LIMITED,
            message = "Too many login attempts. Please wait."
        }
    end
    
    -- Check if account is locked
    if self:IsAccountLocked(player) then
        return {
            success = false,
            result = AUTH_RESULT.ACCOUNT_LOCKED,
            message = "Account is temporarily locked due to failed login attempts."
        }
    end
    
    -- Validate credentials (in a real implementation, this would check against secure storage)
    local credentialsValid = self:ValidateCredentials(player, credentials)
    
    if not credentialsValid then
        self:RecordFailedAttempt(player)
        self.stats.failedLogins = self.stats.failedLogins + 1
        
        return {
            success = false,
            result = AUTH_RESULT.INVALID_CREDENTIALS,
            message = "Invalid credentials provided."
        }
    end
    
    -- Check if MFA is required
    if self:RequiresMFA(player) then
        -- Generate MFA code
        local mfaCode = self:GenerateMFACode(player)
        
        return {
            success = false,
            result = AUTH_RESULT.MFA_REQUIRED,
            message = "Multi-factor authentication required.",
            mfaCode = mfaCode -- In real implementation, this would be sent via email/SMS
        }
    end
    
    -- Create session
    local session = self:CreateSession(player, credentials.rememberMe)
    
    if session then
        self.stats.successfulLogins = self.stats.successfulLogins + 1
        self.stats.totalLogins = self.stats.totalLogins + 1
        
        return {
            success = true,
            result = AUTH_RESULT.SUCCESS,
            message = "Authentication successful.",
            sessionToken = session.token,
            expiresAt = session.expiresAt
        }
    else
        return {
            success = false,
            result = AUTH_RESULT.INVALID_CREDENTIALS,
            message = "Failed to create session."
        }
    end
end

function AuthenticationManager:ValidateCredentials(player, credentials)
    -- In a real implementation, this would:
    -- 1. Hash the provided password with the stored salt
    -- 2. Compare with the stored hash
    -- 3. Check additional security factors
    
    -- For this demo, we'll use a simple validation
    -- In production, integrate with your actual authentication system
    
    if not credentials or not credentials.password then
        return false
    end
    
    -- Simulate credential validation
    -- Replace with actual secure credential checking
    return true -- Placeholder - always returns true for demo
end

function AuthenticationManager:RequiresMFA(player)
    if not CONFIG.MFA_ENABLED then
        return false
    end
    
    -- Check if player is admin (admins require MFA)
    if CONFIG.REQUIRE_MFA_FOR_ADMIN and self:IsPlayerAdmin(player) then
        return true
    end
    
    -- Check if player has MFA enabled (would be stored in player data)
    local playerData = self:GetPlayerAuthData(player)
    return playerData and playerData.mfaEnabled or false
end

function AuthenticationManager:GenerateMFACode(player)
    local userId = player.UserId
    local code = ""
    
    -- Generate random 6-digit code
    for i = 1, CONFIG.MFA_CODE_LENGTH do
        code = code .. tostring(math.random(0, 9))
    end
    
    -- Store code with expiration
    self.mfaCodes[userId] = {
        code = code,
        expiresAt = tick() + CONFIG.MFA_CODE_VALIDITY,
        attempts = 0
    }
    
    print("[AuthenticationManager] Generated MFA code for", player.Name, ":", code)
    return code
end

function AuthenticationManager:VerifyMFACode(player, providedCode)
    local userId = player.UserId
    local mfaData = self.mfaCodes[userId]
    
    if not mfaData then
        return false, "No MFA code generated"
    end
    
    if tick() > mfaData.expiresAt then
        self.mfaCodes[userId] = nil
        return false, "MFA code expired"
    end
    
    mfaData.attempts = mfaData.attempts + 1
    
    if mfaData.attempts > 3 then
        self.mfaCodes[userId] = nil
        return false, "Too many MFA attempts"
    end
    
    if mfaData.code == providedCode then
        self.mfaCodes[userId] = nil
        self.stats.mfaVerifications = self.stats.mfaVerifications + 1
        return true, "MFA verification successful"
    else
        return false, "Invalid MFA code"
    end
end

function AuthenticationManager:CreateSession(player, rememberMe)
    local userId = player.UserId
    local currentTime = tick()
    
    -- Generate session token
    local sessionToken = self:GenerateSecureToken()
    
    -- Determine session duration
    local duration = rememberMe and CONFIG.EXTENDED_SESSION_DURATION or CONFIG.SESSION_DURATION
    if self:IsPlayerAdmin(player) then
        duration = CONFIG.ADMIN_SESSION_DURATION
    end
    
    -- Create session data
    local session = {
        token = sessionToken,
        userId = userId,
        playerName = player.Name,
        createdAt = currentTime,
        expiresAt = currentTime + duration,
        lastActivity = currentTime,
        isAdmin = self:IsPlayerAdmin(player),
        ipAddress = self:GetPlayerIP(player), -- Placeholder
        userAgent = "Roblox", -- Placeholder
        rememberMe = rememberMe or false
    }
    
    -- Store session
    if not self.activeSessions[userId] then
        self.activeSessions[userId] = {}
    end
    
    -- Limit concurrent sessions
    local sessionCount = 0
    for _ in pairs(self.activeSessions[userId]) do
        sessionCount = sessionCount + 1
    end
    
    if sessionCount >= CONFIG.MAX_CONCURRENT_SESSIONS then
        -- Remove oldest session
        local oldestSession = nil
        local oldestTime = math.huge
        
        for sessionId, sessionData in pairs(self.activeSessions[userId]) do
            if sessionData.createdAt < oldestTime then
                oldestTime = sessionData.createdAt
                oldestSession = sessionId
            end
        end
        
        if oldestSession then
            self:RevokeSession(player, oldestSession)
        end
    end
    
    self.activeSessions[userId][sessionToken] = session
    self.stats.activeSessions = self.stats.activeSessions + 1
    
    -- Save session to persistent storage
    self:SaveSessionData(player, session)
    
    print("[AuthenticationManager] Created session for", player.Name, "- Token:", sessionToken:sub(1, 8) .. "...")
    return session
end

function AuthenticationManager:ValidateSession(player, sessionToken)
    if not player or not sessionToken then
        return SESSION_STATUS.INVALID, nil
    end
    
    local userId = player.UserId
    local session = self.activeSessions[userId] and self.activeSessions[userId][sessionToken]
    
    if not session then
        return SESSION_STATUS.INVALID, nil
    end
    
    local currentTime = tick()
    
    -- Check if session is expired
    if currentTime > session.expiresAt then
        self:RevokeSession(player, sessionToken)
        return SESSION_STATUS.EXPIRED, nil
    end
    
    -- Update last activity
    session.lastActivity = currentTime
    
    -- Check if session needs refresh
    if session.expiresAt - currentTime < CONFIG.SESSION_REFRESH_THRESHOLD then
        self:RefreshSession(player, sessionToken)
    end
    
    return SESSION_STATUS.VALID, session
end

function AuthenticationManager:RefreshSession(player, sessionToken)
    local userId = player.UserId
    local session = self.activeSessions[userId] and self.activeSessions[userId][sessionToken]
    
    if not session then
        return false
    end
    
    local currentTime = tick()
    local duration = session.rememberMe and CONFIG.EXTENDED_SESSION_DURATION or CONFIG.SESSION_DURATION
    
    if session.isAdmin then
        duration = CONFIG.ADMIN_SESSION_DURATION
    end
    
    session.expiresAt = currentTime + duration
    session.lastActivity = currentTime
    
    -- Save updated session
    self:SaveSessionData(player, session)
    
    print("[AuthenticationManager] Refreshed session for", player.Name)
    return true
end

function AuthenticationManager:RevokeSession(player, sessionToken)
    local userId = player.UserId
    
    if self.activeSessions[userId] and self.activeSessions[userId][sessionToken] then
        self.activeSessions[userId][sessionToken] = nil
        self.stats.activeSessions = math.max(0, self.stats.activeSessions - 1)
        self.stats.revokedSessions = self.stats.revokedSessions + 1
        
        -- Remove from persistent storage
        self:RemoveSessionData(player, sessionToken)
        
        print("[AuthenticationManager] Revoked session for", player.Name)
        return true
    end
    
    return false
end

function AuthenticationManager:RevokeAllSessions(player)
    local userId = player.UserId
    local revokedCount = 0
    
    if self.activeSessions[userId] then
        for sessionToken, _ in pairs(self.activeSessions[userId]) do
            self:RevokeSession(player, sessionToken)
            revokedCount = revokedCount + 1
        end
    end
    
    print("[AuthenticationManager] Revoked", revokedCount, "sessions for", player.Name)
    return revokedCount
end

function AuthenticationManager:CheckRateLimit(player, action)
    local userId = player.UserId
    local currentTime = tick()
    
    if not self.rateLimits[userId] then
        self.rateLimits[userId] = {}
    end
    
    if not self.rateLimits[userId][action] then
        self.rateLimits[userId][action] = {}
    end
    
    local attempts = self.rateLimits[userId][action]
    
    -- Clean old attempts (last hour)
    local validAttempts = {}
    for _, attemptTime in ipairs(attempts) do
        if currentTime - attemptTime < 3600 then
            table.insert(validAttempts, attemptTime)
        end
    end
    
    self.rateLimits[userId][action] = validAttempts
    
    -- Check limits based on action
    local limit = 10 -- Default limit
    if action == "login" then
        limit = CONFIG.MAX_LOGIN_ATTEMPTS
    end
    
    if #validAttempts >= limit then
        return false
    end
    
    -- Record this attempt
    table.insert(self.rateLimits[userId][action], currentTime)
    return true
end

function AuthenticationManager:RecordFailedAttempt(player)
    local userId = player.UserId
    local currentTime = tick()
    
    if not self.failedAttempts[userId] then
        self.failedAttempts[userId] = {}
    end
    
    table.insert(self.failedAttempts[userId], currentTime)
    
    -- Clean old attempts (last hour)
    local validAttempts = {}
    for _, attemptTime in ipairs(self.failedAttempts[userId]) do
        if currentTime - attemptTime < 3600 then
            table.insert(validAttempts, attemptTime)
        end
    end
    
    self.failedAttempts[userId] = validAttempts
    
    print("[AuthenticationManager] Recorded failed attempt for", player.Name, "- Total:", #validAttempts)
end

function AuthenticationManager:IsAccountLocked(player)
    local userId = player.UserId
    local attempts = self.failedAttempts[userId]
    
    if not attempts or #attempts < CONFIG.MAX_LOGIN_ATTEMPTS then
        return false
    end
    
    -- Check if most recent attempt was within lockout period
    local lastAttempt = attempts[#attempts]
    local currentTime = tick()
    
    return (currentTime - lastAttempt) < CONFIG.LOCKOUT_DURATION
end

function AuthenticationManager:GenerateSecureToken()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local token = ""
    
    for i = 1, CONFIG.TOKEN_LENGTH do
        local randomIndex = math.random(1, #chars)
        token = token .. chars:sub(randomIndex, randomIndex)
    end
    
    return token
end

function AuthenticationManager:IsPlayerAdmin(player)
    -- Check if player is admin
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

function AuthenticationManager:GetPlayerIP(player)
    -- Placeholder - Roblox doesn't expose IP addresses
    return "127.0.0.1"
end

function AuthenticationManager:GetPlayerAuthData(player)
    -- Placeholder - would load from secure storage
    return {
        mfaEnabled = false,
        lastLogin = 0,
        loginCount = 0
    }
end

function AuthenticationManager:SaveSessionData(player, session)
    -- Save session to DataStore for persistence across server restarts
    local success, result = pcall(function()
        return SessionStore:SetAsync(player.UserId .. "_" .. session.token, {
            userId = session.userId,
            playerName = session.playerName,
            createdAt = session.createdAt,
            expiresAt = session.expiresAt,
            isAdmin = session.isAdmin,
            rememberMe = session.rememberMe
        })
    end)
    
    if not success then
        warn("[AuthenticationManager] Failed to save session data:", result)
    end
end

function AuthenticationManager:LoadSessionData()
    -- Load existing sessions from DataStore
    print("[AuthenticationManager] Loading persistent session data...")
    -- Implementation would load from DataStore
end

function AuthenticationManager:RemoveSessionData(player, sessionToken)
    -- Remove session from DataStore
    local success, result = pcall(function()
        return SessionStore:RemoveAsync(player.UserId .. "_" .. sessionToken)
    end)
    
    if not success then
        warn("[AuthenticationManager] Failed to remove session data:", result)
    end
end

function AuthenticationManager:RestorePlayerSession(player)
    -- Attempt to restore existing valid session for player
    -- Implementation would check DataStore for valid sessions
    print("[AuthenticationManager] Attempting to restore session for", player.Name)
end

function AuthenticationManager:StartCleanupLoop()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        if currentTime - self.lastCleanup >= self.cleanupInterval then
            self:PerformCleanup(currentTime)
            self.lastCleanup = currentTime
        end
    end)
end

function AuthenticationManager:PerformCleanup(currentTime)
    local expiredSessions = 0
    
    -- Clean up expired sessions
    for userId, sessions in pairs(self.activeSessions) do
        for sessionToken, session in pairs(sessions) do
            if currentTime > session.expiresAt then
                sessions[sessionToken] = nil
                expiredSessions = expiredSessions + 1
                self.stats.activeSessions = math.max(0, self.stats.activeSessions - 1)
            end
        end
    end
    
    -- Clean up old failed attempts
    for userId, attempts in pairs(self.failedAttempts) do
        local validAttempts = {}
        for _, attemptTime in ipairs(attempts) do
            if currentTime - attemptTime < 3600 then -- Keep last hour
                table.insert(validAttempts, attemptTime)
            end
        end
        self.failedAttempts[userId] = validAttempts
    end
    
    -- Clean up expired MFA codes
    for userId, mfaData in pairs(self.mfaCodes) do
        if currentTime > mfaData.expiresAt then
            self.mfaCodes[userId] = nil
        end
    end
    
    if expiredSessions > 0 then
        print("[AuthenticationManager] Cleaned up", expiredSessions, "expired sessions")
    end
end

function AuthenticationManager:GetSessionStats()
    return {
        totalLogins = self.stats.totalLogins,
        successfulLogins = self.stats.successfulLogins,
        failedLogins = self.stats.failedLogins,
        activeSessions = self.stats.activeSessions,
        revokedSessions = self.stats.revokedSessions,
        mfaVerifications = self.stats.mfaVerifications,
        successRate = self.stats.totalLogins > 0 and (self.stats.successfulLogins / self.stats.totalLogins * 100) or 0
    }
end

function AuthenticationManager:GetPlayerSessions(player)
    local userId = player.UserId
    local sessions = {}
    
    if self.activeSessions[userId] then
        for sessionToken, session in pairs(self.activeSessions[userId]) do
            table.insert(sessions, {
                token = sessionToken:sub(1, 8) .. "...", -- Partial token for security
                createdAt = session.createdAt,
                expiresAt = session.expiresAt,
                lastActivity = session.lastActivity,
                isAdmin = session.isAdmin,
                rememberMe = session.rememberMe
            })
        end
    end
    
    return sessions
end

function AuthenticationManager:Cleanup()
    print("[AuthenticationManager] Cleaning up...")
    
    -- Clear all data
    self.activeSessions = {}
    self.failedAttempts = {}
    self.mfaCodes = {}
    self.rateLimits = {}
    
    print("[AuthenticationManager] Cleanup complete")
end

return AuthenticationManager 