-- AnalyticsSystem.luau
-- Comprehensive analytics and monitoring system

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AnalyticsSystem = {}
AnalyticsSystem.__index = AnalyticsSystem

-- DataStores
local AnalyticsStore = DataStoreService:GetDataStore("Analytics_v1")
local PlayerMetricsStore = DataStoreService:GetDataStore("PlayerMetrics_v1")
local EconomyStore = DataStoreService:GetDataStore("EconomyMetrics_v1")

function AnalyticsSystem.new(placementTracker, gameManager)
    local self = setmetatable({}, AnalyticsSystem)
    
    self.placementTracker = placementTracker
    self.gameManager = gameManager
    
    -- Real-time metrics
    self.sessionMetrics = {
        startTime = os.time(),
        peakPlayers = 0,
        totalPlacements = 0,
        totalPurchases = 0,
        economyTransactions = {},
        performanceMetrics = {},
        errorCounts = {}
    }
    
    -- Player behavior tracking
    self.playerSessions = {}
    self.playerMetrics = {}
    
    -- Economic tracking
    self.economyMetrics = {
        totalCoinsGenerated = 0,
        totalCoinsSpent = 0,
        itemPriceHistory = {},
        popularItems = {},
        inflationRate = 0
    }
    
    self:Initialize()
    return self
end

function AnalyticsSystem:Initialize()
    -- Start metrics collection
    self:StartPerformanceMonitoring()
    self:StartPlayerTracking()
    self:StartEconomicTracking()
    
    -- Periodic data saves
    spawn(function()
        while true do
            wait(300) -- Save every 5 minutes
            self:SaveSessionMetrics()
        end
    end)
    
    print("📊 Analytics system initialized")
end

-- Performance Monitoring
function AnalyticsSystem:StartPerformanceMonitoring()
    -- Monitor FPS and memory usage
    spawn(function()
        while true do
            wait(60) -- Check every minute
            
            local stats = game:GetService("Stats")
            local fps = math.floor(1 / RunService.Heartbeat:Wait())
            local memory = stats:GetTotalMemoryUsageMb()
            
            local perfData = {
                timestamp = os.time(),
                fps = fps,
                memory = memory,
                players = #Players:GetPlayers(),
                objects = self:CountWorldObjects()
            }
            
            table.insert(self.sessionMetrics.performanceMetrics, perfData)
            
            -- Keep only last 24 hours of data
            if #self.sessionMetrics.performanceMetrics > 1440 then -- 24 hours * 60 minutes
                table.remove(self.sessionMetrics.performanceMetrics, 1)
            end
            
            -- Check for performance issues
            if fps < 30 or memory > 1000 then
                self:AlertPerformanceIssue(perfData)
            end
        end
    end)
end

-- Player Behavior Tracking
function AnalyticsSystem:StartPlayerTracking()
    Players.PlayerAdded:Connect(function(player)
        self:StartPlayerSession(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:EndPlayerSession(player)
    end)
end

function AnalyticsSystem:StartPlayerSession(player)
    local sessionData = {
        playerId = player.UserId,
        playerName = player.Name,
        sessionStart = os.time(),
        placements = 0,
        purchases = 0,
        coinsSpent = 0,
        coinsEarned = 0,
        interactions = 0,
        timeInGame = 0
    }
    
    self.playerSessions[player.UserId] = sessionData
    
    -- Update peak players
    local currentPlayers = #Players:GetPlayers()
    if currentPlayers > self.sessionMetrics.peakPlayers then
        self.sessionMetrics.peakPlayers = currentPlayers
    end
    
    print("📈 Started tracking session for:", player.Name)
end

function AnalyticsSystem:EndPlayerSession(player)
    local sessionData = self.playerSessions[player.UserId]
    if not sessionData then return end
    
    sessionData.timeInGame = os.time() - sessionData.sessionStart
    
    -- Calculate engagement metrics
    local engagement = self:CalculateEngagement(sessionData)
    sessionData.engagementScore = engagement
    
    -- Save session data
    self:SavePlayerSession(sessionData)
    
    -- Update player lifetime metrics
    self:UpdatePlayerLifetimeMetrics(player.UserId, sessionData)
    
    self.playerSessions[player.UserId] = nil
    
    print("📉 Ended tracking session for:", player.Name, "Engagement:", engagement)
end

-- Track specific events
function AnalyticsSystem:TrackPlacement(player, itemData, position)
    -- Update session metrics
    if self.playerSessions[player.UserId] then
        self.playerSessions[player.UserId].placements = self.playerSessions[player.UserId].placements + 1
    end
    
    self.sessionMetrics.totalPlacements = self.sessionMetrics.totalPlacements + 1
    
    -- Track item popularity
    local itemName = itemData.Name or itemData.ItemId
    self.economyMetrics.popularItems[itemName] = (self.economyMetrics.popularItems[itemName] or 0) + 1
    
    -- Geographic analytics
    self:TrackGeographicPlacement(position, itemName)
    
    print("📍 Tracked placement:", itemName, "by", player.Name)
end

function AnalyticsSystem:TrackPurchase(player, itemId, price, currency)
    -- Update session metrics
    if self.playerSessions[player.UserId] then
        local session = self.playerSessions[player.UserId]
        session.purchases = session.purchases + 1
        
        if currency == "INGAME" then
            session.coinsSpent = session.coinsSpent + price
        end
    end
    
    self.sessionMetrics.totalPurchases = self.sessionMetrics.totalPurchases + 1
    
    -- Economic tracking
    if currency == "INGAME" then
        self.economyMetrics.totalCoinsSpent = self.economyMetrics.totalCoinsSpent + price
    end
    
    -- Track price history
    if not self.economyMetrics.itemPriceHistory[itemId] then
        self.economyMetrics.itemPriceHistory[itemId] = {}
    end
    
    table.insert(self.economyMetrics.itemPriceHistory[itemId], {
        timestamp = os.time(),
        price = price,
        currency = currency
    })
    
    print("💰 Tracked purchase:", itemId, price, currency, "by", player.Name)
end

function AnalyticsSystem:TrackEconomicEvent(eventType, amount, playerId)
    local event = {
        type = eventType,
        amount = amount,
        playerId = playerId,
        timestamp = os.time()
    }
    
    table.insert(self.sessionMetrics.economyTransactions, event)
    
    if eventType == "COINS_GENERATED" then
        self.economyMetrics.totalCoinsGenerated = self.economyMetrics.totalCoinsGenerated + amount
    elseif eventType == "COINS_SPENT" then
        self.economyMetrics.totalCoinsSpent = self.economyMetrics.totalCoinsSpent + amount
    end
end

-- Economic Analysis
function AnalyticsSystem:StartEconomicTracking()
    spawn(function()
        while true do
            wait(3600) -- Analyze every hour
            self:AnalyzeEconomicTrends()
        end
    end)
end

function AnalyticsSystem:AnalyzeEconomicTrends()
    -- Calculate inflation rate
    local hoursAgo = os.time() - 3600
    local recentTransactions = {}
    
    for _, transaction in ipairs(self.sessionMetrics.economyTransactions) do
        if transaction.timestamp >= hoursAgo then
            table.insert(recentTransactions, transaction)
        end
    end
    
    -- Calculate coin velocity and inflation
    local coinsGenerated = 0
    local coinsSpent = 0
    
    for _, transaction in ipairs(recentTransactions) do
        if transaction.type == "COINS_GENERATED" then
            coinsGenerated = coinsGenerated + transaction.amount
        elseif transaction.type == "COINS_SPENT" then
            coinsSpent = coinsSpent + transaction.amount
        end
    end
    
    local velocity = coinsSpent / math.max(1, coinsGenerated)
    self.economyMetrics.inflationRate = (velocity - 1) * 100
    
    print("💹 Economic analysis - Velocity:", velocity, "Inflation:", self.economyMetrics.inflationRate .. "%")
end

-- Geographic Analytics
function AnalyticsSystem:TrackGeographicPlacement(position, itemName)
    -- Divide world into regions for analysis
    local regionX = math.floor(position.X / 100) * 100
    local regionZ = math.floor(position.Z / 100) * 100
    local regionKey = regionX .. "," .. regionZ
    
    if not self.sessionMetrics.regionActivity then
        self.sessionMetrics.regionActivity = {}
    end
    
    if not self.sessionMetrics.regionActivity[regionKey] then
        self.sessionMetrics.regionActivity[regionKey] = {
            placements = 0,
            items = {},
            centerPosition = {X = regionX, Z = regionZ}
        }
    end
    
    local region = self.sessionMetrics.regionActivity[regionKey]
    region.placements = region.placements + 1
    region.items[itemName] = (region.items[itemName] or 0) + 1
end

-- Utility Functions
function AnalyticsSystem:CalculateEngagement(sessionData)
    local timeWeight = math.min(sessionData.timeInGame / 1800, 1) -- Max weight at 30 minutes
    local actionWeight = (sessionData.placements + sessionData.purchases) / 10
    local spendingWeight = sessionData.coinsSpent / 100
    
    return math.min((timeWeight + actionWeight + spendingWeight) * 100, 100)
end

function AnalyticsSystem:CountWorldObjects()
    local count = 0
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            count = count + 1
        end
    end
    return count
end

function AnalyticsSystem:AlertPerformanceIssue(perfData)
    warn("⚠️ PERFORMANCE ALERT:")
    warn("   FPS:", perfData.fps)
    warn("   Memory:", perfData.memory, "MB")
    warn("   Players:", perfData.players)
    warn("   Objects:", perfData.objects)
    
    -- You could send this to external monitoring service
end

-- Data Persistence
function AnalyticsSystem:SaveSessionMetrics()
    local sessionSummary = {
        timestamp = os.time(),
        duration = os.time() - self.sessionMetrics.startTime,
        peakPlayers = self.sessionMetrics.peakPlayers,
        totalPlacements = self.sessionMetrics.totalPlacements,
        totalPurchases = self.sessionMetrics.totalPurchases,
        economySummary = {
            coinsGenerated = self.economyMetrics.totalCoinsGenerated,
            coinsSpent = self.economyMetrics.totalCoinsSpent,
            inflationRate = self.economyMetrics.inflationRate
        }
    }
    
    pcall(function()
        local sessionKey = "SESSION_" .. os.date("%Y%m%d_%H%M%S")
        AnalyticsStore:SetAsync(sessionKey, sessionSummary)
    end)
    
    print("💾 Saved session metrics")
end

function AnalyticsSystem:SavePlayerSession(sessionData)
    pcall(function()
        local sessionKey = "PLAYER_SESSION_" .. sessionData.playerId .. "_" .. sessionData.sessionStart
        PlayerMetricsStore:SetAsync(sessionKey, sessionData)
    end)
end

function AnalyticsSystem:UpdatePlayerLifetimeMetrics(playerId, sessionData)
    -- This would update cumulative player statistics
    print("📈 Updated lifetime metrics for player:", playerId)
end

-- Reporting Functions
function AnalyticsSystem:GenerateGameHealthReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        uptime = os.time() - self.sessionMetrics.startTime,
        currentPlayers = #Players:GetPlayers(),
        peakPlayers = self.sessionMetrics.peakPlayers,
        totalObjects = self:CountWorldObjects(),
        economicHealth = {
            coinsInCirculation = self.economyMetrics.totalCoinsGenerated - self.economyMetrics.totalCoinsSpent,
            inflationRate = self.economyMetrics.inflationRate,
            transactionVolume = #self.sessionMetrics.economyTransactions
        },
        popularItems = self:GetTopItems(5),
        performanceStatus = self:GetPerformanceStatus()
    }
    
    return report
end

function AnalyticsSystem:GetTopItems(count)
    local itemList = {}
    for itemName, popularity in pairs(self.economyMetrics.popularItems) do
        table.insert(itemList, {name = itemName, count = popularity})
    end
    
    table.sort(itemList, function(a, b) return a.count > b.count end)
    
    local topItems = {}
    for i = 1, math.min(count, #itemList) do
        table.insert(topItems, itemList[i])
    end
    
    return topItems
end

function AnalyticsSystem:GetPerformanceStatus()
    if #self.sessionMetrics.performanceMetrics == 0 then
        return "NO_DATA"
    end
    
    local latest = self.sessionMetrics.performanceMetrics[#self.sessionMetrics.performanceMetrics]
    
    if latest.fps >= 50 and latest.memory <= 500 then
        return "EXCELLENT"
    elseif latest.fps >= 30 and latest.memory <= 800 then
        return "GOOD"
    elseif latest.fps >= 20 and latest.memory <= 1000 then
        return "FAIR"
    else
        return "POOR"
    end
end

-- A/B Testing Support
function AnalyticsSystem:TrackExperiment(playerId, experimentName, variant)
    if not self.sessionMetrics.experiments then
        self.sessionMetrics.experiments = {}
    end
    
    if not self.sessionMetrics.experiments[experimentName] then
        self.sessionMetrics.experiments[experimentName] = {}
    end
    
    self.sessionMetrics.experiments[experimentName][playerId] = variant
    print("🧪 Assigned player", playerId, "to experiment", experimentName, "variant", variant)
end

return AnalyticsSystem 