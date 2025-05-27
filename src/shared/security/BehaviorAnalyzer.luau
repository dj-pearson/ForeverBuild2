-- BehaviorAnalyzer.luau
-- Advanced behavioral analysis system for detecting sophisticated exploits
-- Uses pattern recognition and anomaly detection algorithms

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local BehaviorAnalyzer = {}
BehaviorAnalyzer.__index = BehaviorAnalyzer

-- Configuration
local CONFIG = {
    -- Analysis intervals
    MICRO_ANALYSIS_INTERVAL = 1, -- Real-time analysis (1 second)
    MACRO_ANALYSIS_INTERVAL = 30, -- Pattern analysis (30 seconds)
    PROFILE_UPDATE_INTERVAL = 300, -- Profile updates (5 minutes)
    
    -- Thresholds
    ANOMALY_THRESHOLD = 0.7, -- Anomaly score threshold (0-1)
    PATTERN_CONFIDENCE_THRESHOLD = 0.8, -- Pattern confidence threshold
    RISK_SCORE_THRESHOLD = 0.6, -- Risk score threshold
    
    -- Learning parameters
    LEARNING_RATE = 0.1, -- How quickly to adapt to new patterns
    MEMORY_DECAY = 0.95, -- How quickly old patterns fade
    MIN_SAMPLES = 10, -- Minimum samples for pattern recognition
    
    -- Feature weights
    FEATURE_WEIGHTS = {
        actionFrequency = 0.25,
        timingConsistency = 0.20,
        spatialPatterns = 0.15,
        sequencePatterns = 0.15,
        velocityPatterns = 0.10,
        interactionPatterns = 0.10,
        sessionPatterns = 0.05
    },
    
    DEBUG_MODE = false
}

-- Player behavior categories
local BEHAVIOR_CATEGORIES = {
    NORMAL = "NORMAL",
    SUSPICIOUS = "SUSPICIOUS", 
    BOT_LIKE = "BOT_LIKE",
    EXPLOIT_ATTEMPT = "EXPLOIT_ATTEMPT",
    ADVANCED_EXPLOIT = "ADVANCED_EXPLOIT"
}

function BehaviorAnalyzer.new()
    local self = setmetatable({}, BehaviorAnalyzer)
    
    -- Player profiles
    self.playerProfiles = {}
    
    -- Behavioral patterns database
    self.knownPatterns = {
        normal = {},
        suspicious = {},
        exploit = {}
    }
    
    -- Real-time analysis data
    self.realtimeData = {}
    
    -- Statistics
    self.stats = {
        profilesCreated = 0,
        anomaliesDetected = 0,
        patternsLearned = 0,
        falsePositives = 0,
        truePositives = 0
    }
    
    -- Connections
    self.connections = {}
    
    return self
end

function BehaviorAnalyzer:Initialize()
    print("[BehaviorAnalyzer] Initializing advanced behavioral analysis...")
    
    -- Setup player tracking
    self:SetupPlayerTracking()
    
    -- Start analysis loops
    self:StartMicroAnalysis()
    self:StartMacroAnalysis()
    self:StartProfileUpdates()
    
    -- Load known patterns
    self:LoadKnownPatterns()
    
    print("[BehaviorAnalyzer] Advanced behavioral analysis initialized")
    return true
end

function BehaviorAnalyzer:SetupPlayerTracking()
    -- Track existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:CreatePlayerProfile(player)
    end
    
    -- Track new players
    local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        self:CreatePlayerProfile(player)
    end)
    table.insert(self.connections, playerAddedConnection)
    
    -- Clean up when players leave
    local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        self:ArchivePlayerProfile(player)
    end)
    table.insert(self.connections, playerRemovingConnection)
end

function BehaviorAnalyzer:CreatePlayerProfile(player)
    local userId = player.UserId
    
    self.playerProfiles[userId] = {
        player = player,
        joinTime = tick(),
        
        -- Behavioral features
        features = {
            actionFrequency = {},
            timingPatterns = {},
            spatialMovement = {},
            interactionSequences = {},
            velocityProfile = {},
            sessionBehavior = {}
        },
        
        -- Analysis results
        riskScore = 0,
        anomalyScore = 0,
        behaviorCategory = BEHAVIOR_CATEGORIES.NORMAL,
        confidence = 0,
        
        -- Learning data
        baselineEstablished = false,
        sampleCount = 0,
        adaptationRate = CONFIG.LEARNING_RATE,
        
        -- Historical data
        sessionHistory = {},
        violationHistory = {},
        
        -- Real-time tracking
        lastAnalysis = 0,
        currentSession = {
            startTime = tick(),
            actions = {},
            movements = {},
            interactions = {}
        }
    }
    
    self.realtimeData[userId] = {
        actionBuffer = {},
        movementBuffer = {},
        timingBuffer = {},
        lastUpdate = tick()
    }
    
    self.stats.profilesCreated = self.stats.profilesCreated + 1
    
    if CONFIG.DEBUG_MODE then
        print("[BehaviorAnalyzer] Created profile for player:", player.Name)
    end
end

function BehaviorAnalyzer:StartMicroAnalysis()
    local microConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        for userId, profile in pairs(self.playerProfiles) do
            if currentTime - profile.lastAnalysis >= CONFIG.MICRO_ANALYSIS_INTERVAL then
                self:PerformMicroAnalysis(profile)
                profile.lastAnalysis = currentTime
            end
        end
    end)
    
    table.insert(self.connections, microConnection)
    
    if CONFIG.DEBUG_MODE then
        print("[BehaviorAnalyzer] Micro-analysis started")
    end
end

function BehaviorAnalyzer:PerformMicroAnalysis(profile)
    local player = profile.player
    if not player or not player.Parent then return end
    
    local userId = player.UserId
    local realtimeData = self.realtimeData[userId]
    if not realtimeData then return end
    
    -- Analyze recent actions
    local actionAnomalyScore = self:AnalyzeActionPatterns(profile, realtimeData)
    local timingAnomalyScore = self:AnalyzeTimingPatterns(profile, realtimeData)
    local movementAnomalyScore = self:AnalyzeMovementPatterns(profile, realtimeData)
    
    -- Calculate weighted anomaly score
    local totalAnomalyScore = (
        actionAnomalyScore * CONFIG.FEATURE_WEIGHTS.actionFrequency +
        timingAnomalyScore * CONFIG.FEATURE_WEIGHTS.timingConsistency +
        movementAnomalyScore * CONFIG.FEATURE_WEIGHTS.spatialPatterns
    )
    
    -- Update profile
    profile.anomalyScore = totalAnomalyScore
    
    -- Check for immediate threats
    if totalAnomalyScore > CONFIG.ANOMALY_THRESHOLD then
        self:HandleAnomalyDetection(player, totalAnomalyScore, {
            actionScore = actionAnomalyScore,
            timingScore = timingAnomalyScore,
            movementScore = movementAnomalyScore
        })
    end
end

function BehaviorAnalyzer:AnalyzeActionPatterns(profile, realtimeData)
    local actionBuffer = realtimeData.actionBuffer
    if #actionBuffer < CONFIG.MIN_SAMPLES then
        return 0 -- Not enough data
    end
    
    -- Calculate action frequency
    local currentTime = tick()
    local recentActions = {}
    
    for _, action in ipairs(actionBuffer) do
        if currentTime - action.timestamp <= 10 then -- Last 10 seconds
            table.insert(recentActions, action)
        end
    end
    
    local actionFrequency = #recentActions / 10 -- Actions per second
    
    -- Compare to baseline
    local baseline = profile.features.actionFrequency.baseline or 1
    local deviation = math.abs(actionFrequency - baseline) / baseline
    
    -- Check for suspicious patterns
    local suspiciousScore = 0
    
    -- Pattern 1: Extremely high frequency
    if actionFrequency > baseline * 5 then
        suspiciousScore = suspiciousScore + 0.4
    end
    
    -- Pattern 2: Perfect consistency (bot-like)
    local timeDiffs = {}
    for i = 2, #recentActions do
        table.insert(timeDiffs, recentActions[i].timestamp - recentActions[i-1].timestamp)
    end
    
    if #timeDiffs > 5 then
        local variance = self:CalculateVariance(timeDiffs)
        if variance < 0.001 then -- Very low variance
            suspiciousScore = suspiciousScore + 0.3
        end
    end
    
    -- Pattern 3: Identical action sequences
    local sequenceRepeats = self:DetectSequenceRepeats(recentActions)
    if sequenceRepeats > 3 then
        suspiciousScore = suspiciousScore + 0.2
    end
    
    return math.min(suspiciousScore, 1)
end

function BehaviorAnalyzer:AnalyzeTimingPatterns(profile, realtimeData)
    local timingBuffer = realtimeData.timingBuffer
    if #timingBuffer < CONFIG.MIN_SAMPLES then
        return 0
    end
    
    -- Analyze timing consistency
    local intervals = {}
    for i = 2, #timingBuffer do
        table.insert(intervals, timingBuffer[i] - timingBuffer[i-1])
    end
    
    if #intervals < 5 then return 0 end
    
    local mean = self:CalculateMean(intervals)
    local variance = self:CalculateVariance(intervals)
    local stdDev = math.sqrt(variance)
    
    -- Calculate coefficient of variation
    local cv = stdDev / mean
    
    -- Suspicious if timing is too consistent (bot-like) or too erratic
    local suspiciousScore = 0
    
    if cv < 0.1 then -- Too consistent
        suspiciousScore = 0.6
    elseif cv > 2.0 then -- Too erratic
        suspiciousScore = 0.4
    end
    
    return suspiciousScore
end

function BehaviorAnalyzer:AnalyzeMovementPatterns(profile, realtimeData)
    local movementBuffer = realtimeData.movementBuffer
    if #movementBuffer < CONFIG.MIN_SAMPLES then
        return 0
    end
    
    local suspiciousScore = 0
    
    -- Analyze movement for teleportation patterns
    for i = 2, #movementBuffer do
        local distance = (movementBuffer[i].position - movementBuffer[i-1].position).Magnitude
        local timeDiff = movementBuffer[i].timestamp - movementBuffer[i-1].timestamp
        
        if timeDiff > 0 then
            local speed = distance / timeDiff
            
            -- Check for impossible speeds
            if speed > 100 then -- 100 studs/second threshold
                suspiciousScore = suspiciousScore + 0.2
            end
        end
    end
    
    -- Analyze movement patterns for bot-like behavior
    local directions = {}
    for i = 2, #movementBuffer do
        local direction = (movementBuffer[i].position - movementBuffer[i-1].position).Unit
        table.insert(directions, direction)
    end
    
    -- Check for repetitive movement patterns
    if #directions > 10 then
        local repetitiveScore = self:DetectRepetitiveMovement(directions)
        suspiciousScore = suspiciousScore + repetitiveScore * 0.3
    end
    
    return math.min(suspiciousScore, 1)
end

function BehaviorAnalyzer:StartMacroAnalysis()
    local macroConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        for userId, profile in pairs(self.playerProfiles) do
            if currentTime - (profile.lastMacroAnalysis or 0) >= CONFIG.MACRO_ANALYSIS_INTERVAL then
                self:PerformMacroAnalysis(profile)
                profile.lastMacroAnalysis = currentTime
            end
        end
    end)
    
    table.insert(self.connections, macroConnection)
end

function BehaviorAnalyzer:PerformMacroAnalysis(profile)
    local player = profile.player
    if not player or not player.Parent then return end
    
    -- Analyze long-term patterns
    local sessionScore = self:AnalyzeSessionBehavior(profile)
    local sequenceScore = self:AnalyzeInteractionSequences(profile)
    local velocityScore = self:AnalyzeVelocityProfile(profile)
    
    -- Calculate overall risk score
    local riskScore = (
        sessionScore * CONFIG.FEATURE_WEIGHTS.sessionPatterns +
        sequenceScore * CONFIG.FEATURE_WEIGHTS.sequencePatterns +
        velocityScore * CONFIG.FEATURE_WEIGHTS.velocityPatterns
    )
    
    profile.riskScore = riskScore
    
    -- Update behavior category
    self:UpdateBehaviorCategory(profile)
    
    -- Learn from this session
    self:UpdateLearningModel(profile)
end

function BehaviorAnalyzer:UpdateBehaviorCategory(profile)
    local riskScore = profile.riskScore
    local anomalyScore = profile.anomalyScore
    
    local combinedScore = (riskScore + anomalyScore) / 2
    
    if combinedScore < 0.2 then
        profile.behaviorCategory = BEHAVIOR_CATEGORIES.NORMAL
        profile.confidence = 1 - combinedScore
    elseif combinedScore < 0.4 then
        profile.behaviorCategory = BEHAVIOR_CATEGORIES.SUSPICIOUS
        profile.confidence = combinedScore
    elseif combinedScore < 0.6 then
        profile.behaviorCategory = BEHAVIOR_CATEGORIES.BOT_LIKE
        profile.confidence = combinedScore
    elseif combinedScore < 0.8 then
        profile.behaviorCategory = BEHAVIOR_CATEGORIES.EXPLOIT_ATTEMPT
        profile.confidence = combinedScore
    else
        profile.behaviorCategory = BEHAVIOR_CATEGORIES.ADVANCED_EXPLOIT
        profile.confidence = combinedScore
    end
end

function BehaviorAnalyzer:RecordAction(player, actionType, actionData)
    local userId = player.UserId
    local realtimeData = self.realtimeData[userId]
    local profile = self.playerProfiles[userId]
    
    if not realtimeData or not profile then return end
    
    local currentTime = tick()
    
    -- Add to action buffer
    table.insert(realtimeData.actionBuffer, {
        type = actionType,
        data = actionData,
        timestamp = currentTime
    })
    
    -- Add to timing buffer
    table.insert(realtimeData.timingBuffer, currentTime)
    
    -- Add to current session
    table.insert(profile.currentSession.actions, {
        type = actionType,
        data = actionData,
        timestamp = currentTime
    })
    
    -- Cleanup old data
    self:CleanupBuffers(realtimeData)
    
    profile.sampleCount = profile.sampleCount + 1
end

function BehaviorAnalyzer:RecordMovement(player, position, velocity)
    local userId = player.UserId
    local realtimeData = self.realtimeData[userId]
    local profile = self.playerProfiles[userId]
    
    if not realtimeData or not profile then return end
    
    local currentTime = tick()
    
    -- Add to movement buffer
    table.insert(realtimeData.movementBuffer, {
        position = position,
        velocity = velocity,
        timestamp = currentTime
    })
    
    -- Add to current session
    table.insert(profile.currentSession.movements, {
        position = position,
        velocity = velocity,
        timestamp = currentTime
    })
    
    -- Cleanup old data
    self:CleanupBuffers(realtimeData)
end

function BehaviorAnalyzer:HandleAnomalyDetection(player, anomalyScore, details)
    local userId = player.UserId
    local profile = self.playerProfiles[userId]
    
    if not profile then return end
    
    -- Record the anomaly
    table.insert(profile.violationHistory, {
        type = "BEHAVIORAL_ANOMALY",
        score = anomalyScore,
        details = details,
        timestamp = tick()
    })
    
    self.stats.anomaliesDetected = self.stats.anomaliesDetected + 1
    
    -- Notify other systems
    local event = {
        player = player,
        anomalyType = "BEHAVIORAL_ANOMALY",
        severity = anomalyScore,
        details = details,
        confidence = profile.confidence
    }
    
    -- You can integrate this with your ExploitDetector here
    warn(string.format("🧠 BEHAVIORAL ANOMALY: Player %s - Score: %.2f", 
        player.Name, anomalyScore))
    
    if CONFIG.DEBUG_MODE then
        print("Anomaly details:", HttpService:JSONEncode(details))
    end
end

-- Utility functions
function BehaviorAnalyzer:CalculateMean(values)
    local sum = 0
    for _, value in ipairs(values) do
        sum = sum + value
    end
    return sum / #values
end

function BehaviorAnalyzer:CalculateVariance(values)
    local mean = self:CalculateMean(values)
    local variance = 0
    
    for _, value in ipairs(values) do
        variance = variance + (value - mean)^2
    end
    
    return variance / #values
end

function BehaviorAnalyzer:DetectSequenceRepeats(actions)
    local sequences = {}
    local repeats = 0
    
    -- Look for repeating sequences of 3+ actions
    for i = 1, #actions - 2 do
        local sequence = {}
        for j = i, math.min(i + 2, #actions) do
            table.insert(sequence, actions[j].type)
        end
        
        local sequenceKey = table.concat(sequence, "-")
        sequences[sequenceKey] = (sequences[sequenceKey] or 0) + 1
        
        if sequences[sequenceKey] > 2 then
            repeats = repeats + 1
        end
    end
    
    return repeats
end

function BehaviorAnalyzer:DetectRepetitiveMovement(directions)
    local patterns = {}
    local repetitiveScore = 0
    
    -- Look for repeating direction patterns
    for i = 1, #directions - 3 do
        local pattern = {}
        for j = i, i + 3 do
            if directions[j] then
                table.insert(pattern, string.format("%.1f,%.1f,%.1f", 
                    directions[j].X, directions[j].Y, directions[j].Z))
            end
        end
        
        local patternKey = table.concat(pattern, "|")
        patterns[patternKey] = (patterns[patternKey] or 0) + 1
        
        if patterns[patternKey] > 2 then
            repetitiveScore = repetitiveScore + 0.1
        end
    end
    
    return math.min(repetitiveScore, 1)
end

function BehaviorAnalyzer:CleanupBuffers(realtimeData)
    local currentTime = tick()
    local maxAge = 60 -- Keep data for 60 seconds
    
    -- Cleanup action buffer
    local newActionBuffer = {}
    for _, action in ipairs(realtimeData.actionBuffer) do
        if currentTime - action.timestamp <= maxAge then
            table.insert(newActionBuffer, action)
        end
    end
    realtimeData.actionBuffer = newActionBuffer
    
    -- Cleanup timing buffer
    local newTimingBuffer = {}
    for _, timestamp in ipairs(realtimeData.timingBuffer) do
        if currentTime - timestamp <= maxAge then
            table.insert(newTimingBuffer, timestamp)
        end
    end
    realtimeData.timingBuffer = newTimingBuffer
    
    -- Cleanup movement buffer
    local newMovementBuffer = {}
    for _, movement in ipairs(realtimeData.movementBuffer) do
        if currentTime - movement.timestamp <= maxAge then
            table.insert(newMovementBuffer, movement)
        end
    end
    realtimeData.movementBuffer = newMovementBuffer
end

function BehaviorAnalyzer:GetPlayerAnalysis(player)
    local userId = player.UserId
    local profile = self.playerProfiles[userId]
    
    if not profile then
        return nil
    end
    
    return {
        riskScore = profile.riskScore,
        anomalyScore = profile.anomalyScore,
        behaviorCategory = profile.behaviorCategory,
        confidence = profile.confidence,
        sampleCount = profile.sampleCount,
        sessionDuration = tick() - profile.currentSession.startTime,
        violationCount = #profile.violationHistory
    }
end

function BehaviorAnalyzer:Cleanup()
    print("[BehaviorAnalyzer] Cleaning up...")
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Archive all profiles
    for userId, profile in pairs(self.playerProfiles) do
        if profile.player then
            self:ArchivePlayerProfile(profile.player)
        end
    end
    
    print("[BehaviorAnalyzer] Cleanup complete")
end

return BehaviorAnalyzer 