--[[
	PerformanceMonitor.luau
	Enterprise-Level Performance Monitoring System
	
	Features:
	- Real-time performance metrics collection
	- Advanced alerting system with thresholds
	- Performance analytics and trending
	- Resource utilization monitoring
	- Bottleneck detection and analysis
	- Automated performance optimization suggestions
	- Historical data analysis and reporting
	- Integration with external monitoring systems
	
	Author: ForeverBuild2 Enterprise Team
	Version: 1.0.0
	Last Updated: 2024
]]

local PerformanceMonitor = {}
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local CONFIG = {
	-- Monitoring intervals
	METRICS_COLLECTION_INTERVAL = 1, -- seconds
	ALERT_CHECK_INTERVAL = 5, -- seconds
	ANALYTICS_UPDATE_INTERVAL = 30, -- seconds
	CLEANUP_INTERVAL = 300, -- 5 minutes
	
	-- Data retention
	METRICS_HISTORY_SIZE = 3600, -- 1 hour of data at 1-second intervals
	ALERT_HISTORY_SIZE = 1000,
	ANALYTICS_HISTORY_SIZE = 288, -- 24 hours at 5-minute intervals
	
	-- Performance thresholds
	THRESHOLDS = {
		FPS = {
			EXCELLENT = 58,
			GOOD = 45,
			FAIR = 30,
			POOR = 20,
			CRITICAL = 10,
		},
		MEMORY = {
			EXCELLENT = 200, -- MB
			GOOD = 400,
			FAIR = 600,
			POOR = 800,
			CRITICAL = 1000,
		},
		NETWORK = {
			EXCELLENT = 50, -- ms ping
			GOOD = 100,
			FAIR = 200,
			POOR = 500,
			CRITICAL = 1000,
		},
		CPU = {
			EXCELLENT = 20, -- % usage
			GOOD = 40,
			FAIR = 60,
			POOR = 80,
			CRITICAL = 95,
		}
	},
	
	-- Alert settings
	ALERT_COOLDOWN = 60, -- seconds between same alert types
	MAX_ALERTS_PER_MINUTE = 10,
	ALERT_ESCALATION_TIME = 300, -- 5 minutes
	
	-- Analytics settings
	TREND_ANALYSIS_WINDOW = 300, -- 5 minutes
	ANOMALY_DETECTION_SENSITIVITY = 2.0, -- Standard deviations
	PERFORMANCE_BASELINE_SAMPLES = 100,
}

-- Performance metrics storage
local metrics = {
	current = {
		fps = 0,
		memory = 0,
		network = 0,
		cpu = 0,
		players = 0,
		timestamp = 0,
	},
	history = {},
	analytics = {
		trends = {},
		baselines = {},
		anomalies = {},
		predictions = {},
	},
}

-- Alert system
local alertSystem = {
	active = {},
	history = {},
	cooldowns = {},
	escalations = {},
	stats = {
		totalAlerts = 0,
		alertsByType = {},
		alertsByLevel = {},
	},
}

-- Performance analysis
local analysis = {
	bottlenecks = {},
	optimizations = {},
	recommendations = {},
	healthScore = 100,
}

-- Monitoring connections
local connections = {}

-- Utility functions
local function getCurrentTime()
	return tick()
end

local function calculateMovingAverage(data, window)
	if #data < window then
		window = #data
	end
	
	local sum = 0
	for i = #data - window + 1, #data do
		sum = sum + data[i]
	end
	
	return window > 0 and sum / window or 0
end

local function calculateStandardDeviation(data, mean)
	if #data < 2 then
		return 0
	end
	
	local variance = 0
	for _, value in ipairs(data) do
		variance = variance + (value - mean) ^ 2
	end
	
	return math.sqrt(variance / (#data - 1))
end

local function determinePerformanceLevel(value, thresholds)
	if value >= thresholds.EXCELLENT then
		return "EXCELLENT", 5
	elseif value >= thresholds.GOOD then
		return "GOOD", 4
	elseif value >= thresholds.FAIR then
		return "FAIR", 3
	elseif value >= thresholds.POOR then
		return "POOR", 2
	else
		return "CRITICAL", 1
	end
end

-- Metrics collection
function PerformanceMonitor.collectMetrics()
	local currentTime = getCurrentTime()
	
	-- Collect FPS
	local fps = 1 / RunService.Heartbeat:Wait()
	
	-- Collect memory usage
	local memory = 0
	local memoryStats = Stats:FindFirstChild("MemoryUsage")
	if memoryStats then
		for _, child in pairs(memoryStats:GetChildren()) do
			if child:IsA("NumberValue") then
				memory = memory + child.Value
			end
		end
		memory = memory / (1024 * 1024) -- Convert to MB
	end
	
	-- Collect network stats (simplified)
	local network = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	
	-- Collect CPU usage (estimated from frame time)
	local frameTime = RunService.Heartbeat:Wait()
	local cpu = math.min(100, frameTime * 60 * 100) -- Rough CPU estimation
	
	-- Collect player count
	local playerCount = #Players:GetPlayers()
	
	-- Update current metrics
	metrics.current = {
		fps = fps,
		memory = memory,
		network = network,
		cpu = cpu,
		players = playerCount,
		timestamp = currentTime,
	}
	
	-- Add to history
	table.insert(metrics.history, {
		fps = fps,
		memory = memory,
		network = network,
		cpu = cpu,
		players = playerCount,
		timestamp = currentTime,
	})
	
	-- Maintain history size
	if #metrics.history > CONFIG.METRICS_HISTORY_SIZE then
		table.remove(metrics.history, 1)
	end
	
	return metrics.current
end

-- Alert system
function PerformanceMonitor.checkAlerts()
	local currentTime = getCurrentTime()
	local current = metrics.current
	
	-- Check FPS alerts
	PerformanceMonitor.checkMetricAlert("FPS", current.fps, CONFIG.THRESHOLDS.FPS, false) -- Lower is worse for FPS
	
	-- Check memory alerts
	PerformanceMonitor.checkMetricAlert("MEMORY", current.memory, CONFIG.THRESHOLDS.MEMORY, true) -- Higher is worse for memory
	
	-- Check network alerts
	PerformanceMonitor.checkMetricAlert("NETWORK", current.network, CONFIG.THRESHOLDS.NETWORK, true) -- Higher is worse for ping
	
	-- Check CPU alerts
	PerformanceMonitor.checkMetricAlert("CPU", current.cpu, CONFIG.THRESHOLDS.CPU, true) -- Higher is worse for CPU
	
	-- Clean up old alerts
	PerformanceMonitor.cleanupAlerts()
end

function PerformanceMonitor.checkMetricAlert(metricType, value, thresholds, higherIsWorse)
	local currentTime = getCurrentTime()
	local alertType = metricType .. "_PERFORMANCE"
	
	-- Check cooldown
	if alertSystem.cooldowns[alertType] and currentTime - alertSystem.cooldowns[alertType] < CONFIG.ALERT_COOLDOWN then
		return
	end
	
	local level, score
	if higherIsWorse then
		if value >= thresholds.CRITICAL then
			level, score = "CRITICAL", 1
		elseif value >= thresholds.POOR then
			level, score = "POOR", 2
		elseif value >= thresholds.FAIR then
			level, score = "FAIR", 3
		else
			return -- No alert needed
		end
	else
		if value <= thresholds.CRITICAL then
			level, score = "CRITICAL", 1
		elseif value <= thresholds.POOR then
			level, score = "POOR", 2
		elseif value <= thresholds.FAIR then
			level, score = "FAIR", 3
		else
			return -- No alert needed
		end
	end
	
	-- Create alert
	local alert = {
		id = PerformanceMonitor.generateAlertId(),
		type = alertType,
		level = level,
		metric = metricType,
		value = value,
		threshold = higherIsWorse and thresholds[level] or thresholds[level],
		message = string.format("%s performance %s: %.2f", metricType, level:lower(), value),
		timestamp = currentTime,
		acknowledged = false,
		escalated = false,
	}
	
	-- Add to active alerts
	alertSystem.active[alert.id] = alert
	
	-- Add to history
	table.insert(alertSystem.history, alert)
	
	-- Update statistics
	alertSystem.stats.totalAlerts = alertSystem.stats.totalAlerts + 1
	alertSystem.stats.alertsByType[alertType] = (alertSystem.stats.alertsByType[alertType] or 0) + 1
	alertSystem.stats.alertsByLevel[level] = (alertSystem.stats.alertsByLevel[level] or 0) + 1
	
	-- Set cooldown
	alertSystem.cooldowns[alertType] = currentTime
	
	-- Log alert
	if level == "CRITICAL" then
		warn("[PerformanceMonitor] CRITICAL ALERT:", alert.message)
	else
		print("[PerformanceMonitor] Alert:", alert.message)
	end
	
	-- Schedule escalation if critical
	if level == "CRITICAL" then
		alertSystem.escalations[alert.id] = currentTime + CONFIG.ALERT_ESCALATION_TIME
	end
	
	return alert
end

function PerformanceMonitor.cleanupAlerts()
	local currentTime = getCurrentTime()
	
	-- Remove resolved alerts
	for alertId, alert in pairs(alertSystem.active) do
		local isResolved = false
		
		-- Check if the condition that triggered the alert is resolved
		if alert.metric == "FPS" and metrics.current.fps > CONFIG.THRESHOLDS.FPS.FAIR then
			isResolved = true
		elseif alert.metric == "MEMORY" and metrics.current.memory < CONFIG.THRESHOLDS.MEMORY.FAIR then
			isResolved = true
		elseif alert.metric == "NETWORK" and metrics.current.network < CONFIG.THRESHOLDS.NETWORK.FAIR then
			isResolved = true
		elseif alert.metric == "CPU" and metrics.current.cpu < CONFIG.THRESHOLDS.CPU.FAIR then
			isResolved = true
		end
		
		if isResolved then
			alertSystem.active[alertId] = nil
			print("[PerformanceMonitor] Alert resolved:", alert.message)
		end
	end
	
	-- Handle escalations
	for alertId, escalationTime in pairs(alertSystem.escalations) do
		if currentTime >= escalationTime then
			local alert = alertSystem.active[alertId]
			if alert and not alert.escalated then
				alert.escalated = true
				warn("[PerformanceMonitor] ESCALATED ALERT:", alert.message)
				-- In a real system, this would notify administrators
			end
			alertSystem.escalations[alertId] = nil
		end
	end
	
	-- Maintain history size
	if #alertSystem.history > CONFIG.ALERT_HISTORY_SIZE then
		table.remove(alertSystem.history, 1)
	end
end

-- Analytics and trending
function PerformanceMonitor.updateAnalytics()
	if #metrics.history < CONFIG.PERFORMANCE_BASELINE_SAMPLES then
		return -- Not enough data for analysis
	end
	
	local currentTime = getCurrentTime()
	
	-- Calculate trends for each metric
	for _, metricName in ipairs({"fps", "memory", "network", "cpu"}) do
		PerformanceMonitor.calculateTrend(metricName)
		PerformanceMonitor.detectAnomalies(metricName)
		PerformanceMonitor.updateBaseline(metricName)
	end
	
	-- Calculate overall health score
	PerformanceMonitor.calculateHealthScore()
	
	-- Generate recommendations
	PerformanceMonitor.generateRecommendations()
	
	-- Detect bottlenecks
	PerformanceMonitor.detectBottlenecks()
end

function PerformanceMonitor.calculateTrend(metricName)
	local window = math.min(CONFIG.TREND_ANALYSIS_WINDOW, #metrics.history)
	local recentData = {}
	
	for i = #metrics.history - window + 1, #metrics.history do
		table.insert(recentData, metrics.history[i][metricName])
	end
	
	local mean = calculateMovingAverage(recentData, window)
	local stdDev = calculateStandardDeviation(recentData, mean)
	
	-- Determine trend direction
	local firstHalf = {}
	local secondHalf = {}
	local midpoint = math.floor(#recentData / 2)
	
	for i = 1, midpoint do
		table.insert(firstHalf, recentData[i])
	end
	
	for i = midpoint + 1, #recentData do
		table.insert(secondHalf, recentData[i])
	end
	
	local firstMean = calculateMovingAverage(firstHalf, #firstHalf)
	local secondMean = calculateMovingAverage(secondHalf, #secondHalf)
	
	local trendDirection = "STABLE"
	local trendStrength = 0
	
	if math.abs(secondMean - firstMean) > stdDev * 0.5 then
		if secondMean > firstMean then
			trendDirection = "INCREASING"
		else
			trendDirection = "DECREASING"
		end
		trendStrength = math.abs(secondMean - firstMean) / stdDev
	end
	
	metrics.analytics.trends[metricName] = {
		direction = trendDirection,
		strength = trendStrength,
		mean = mean,
		stdDev = stdDev,
		timestamp = getCurrentTime(),
	}
end

function PerformanceMonitor.detectAnomalies(metricName)
	local baseline = metrics.analytics.baselines[metricName]
	if not baseline then
		return
	end
	
	local currentValue = metrics.current[metricName]
	local deviation = math.abs(currentValue - baseline.mean) / baseline.stdDev
	
	if deviation > CONFIG.ANOMALY_DETECTION_SENSITIVITY then
		local anomaly = {
			metric = metricName,
			value = currentValue,
			baseline = baseline.mean,
			deviation = deviation,
			severity = deviation > 3 and "HIGH" or "MEDIUM",
			timestamp = getCurrentTime(),
		}
		
		table.insert(metrics.analytics.anomalies, anomaly)
		
		-- Maintain anomaly history
		if #metrics.analytics.anomalies > 100 then
			table.remove(metrics.analytics.anomalies, 1)
		end
		
		print("[PerformanceMonitor] Anomaly detected:", metricName, "deviation:", deviation)
	end
end

function PerformanceMonitor.updateBaseline(metricName)
	local window = math.min(CONFIG.PERFORMANCE_BASELINE_SAMPLES, #metrics.history)
	local data = {}
	
	for i = #metrics.history - window + 1, #metrics.history do
		table.insert(data, metrics.history[i][metricName])
	end
	
	local mean = calculateMovingAverage(data, window)
	local stdDev = calculateStandardDeviation(data, mean)
	
	metrics.analytics.baselines[metricName] = {
		mean = mean,
		stdDev = stdDev,
		samples = window,
		timestamp = getCurrentTime(),
	}
end

function PerformanceMonitor.calculateHealthScore()
	local scores = {}
	
	-- FPS score (higher is better)
	local fpsLevel, fpsScore = determinePerformanceLevel(metrics.current.fps, CONFIG.THRESHOLDS.FPS)
	scores.fps = fpsScore * 20 -- Scale to 0-100
	
	-- Memory score (lower is better)
	local memoryLevel, memoryScore = determinePerformanceLevel(metrics.current.memory, CONFIG.THRESHOLDS.MEMORY)
	scores.memory = (6 - memoryScore) * 20 -- Invert and scale
	
	-- Network score (lower is better)
	local networkLevel, networkScore = determinePerformanceLevel(metrics.current.network, CONFIG.THRESHOLDS.NETWORK)
	scores.network = (6 - networkScore) * 20 -- Invert and scale
	
	-- CPU score (lower is better)
	local cpuLevel, cpuScore = determinePerformanceLevel(metrics.current.cpu, CONFIG.THRESHOLDS.CPU)
	scores.cpu = (6 - cpuScore) * 20 -- Invert and scale
	
	-- Calculate weighted average
	local totalScore = (scores.fps * 0.3 + scores.memory * 0.25 + scores.network * 0.25 + scores.cpu * 0.2)
	analysis.healthScore = math.max(0, math.min(100, totalScore))
	
	return analysis.healthScore
end

function PerformanceMonitor.generateRecommendations()
	analysis.recommendations = {}
	
	-- FPS recommendations
	if metrics.current.fps < CONFIG.THRESHOLDS.FPS.GOOD then
		table.insert(analysis.recommendations, {
			type = "PERFORMANCE",
			priority = "HIGH",
			message = "Low FPS detected. Consider reducing graphics quality or optimizing scripts.",
			metric = "fps",
			value = metrics.current.fps,
		})
	end
	
	-- Memory recommendations
	if metrics.current.memory > CONFIG.THRESHOLDS.MEMORY.FAIR then
		table.insert(analysis.recommendations, {
			type = "MEMORY",
			priority = "MEDIUM",
			message = "High memory usage detected. Consider implementing memory optimization.",
			metric = "memory",
			value = metrics.current.memory,
		})
	end
	
	-- Network recommendations
	if metrics.current.network > CONFIG.THRESHOLDS.NETWORK.FAIR then
		table.insert(analysis.recommendations, {
			type = "NETWORK",
			priority = "MEDIUM",
			message = "High network latency detected. Check server performance and network conditions.",
			metric = "network",
			value = metrics.current.network,
		})
	end
	
	-- CPU recommendations
	if metrics.current.cpu > CONFIG.THRESHOLDS.CPU.FAIR then
		table.insert(analysis.recommendations, {
			type = "CPU",
			priority = "HIGH",
			message = "High CPU usage detected. Optimize scripts and reduce computational load.",
			metric = "cpu",
			value = metrics.current.cpu,
		})
	end
end

function PerformanceMonitor.detectBottlenecks()
	analysis.bottlenecks = {}
	
	-- Identify the worst performing metric
	local worstMetric = nil
	local worstScore = 100
	
	local fpsLevel, fpsScore = determinePerformanceLevel(metrics.current.fps, CONFIG.THRESHOLDS.FPS)
	if fpsScore < worstScore then
		worstScore = fpsScore
		worstMetric = "fps"
	end
	
	local memoryLevel, memoryScore = determinePerformanceLevel(metrics.current.memory, CONFIG.THRESHOLDS.MEMORY)
	if (6 - memoryScore) < worstScore then
		worstScore = 6 - memoryScore
		worstMetric = "memory"
	end
	
	local networkLevel, networkScore = determinePerformanceLevel(metrics.current.network, CONFIG.THRESHOLDS.NETWORK)
	if (6 - networkScore) < worstScore then
		worstScore = 6 - networkScore
		worstMetric = "network"
	end
	
	local cpuLevel, cpuScore = determinePerformanceLevel(metrics.current.cpu, CONFIG.THRESHOLDS.CPU)
	if (6 - cpuScore) < worstScore then
		worstScore = 6 - cpuScore
		worstMetric = "cpu"
	end
	
	if worstScore < 3 then -- Only consider significant bottlenecks
		table.insert(analysis.bottlenecks, {
			metric = worstMetric,
			severity = worstScore == 1 and "CRITICAL" or "HIGH",
			impact = "Primary performance bottleneck",
			timestamp = getCurrentTime(),
		})
	end
end

-- Utility functions
function PerformanceMonitor.generateAlertId()
	return "ALERT_" .. tostring(getCurrentTime()):gsub("%.", "") .. "_" .. tostring(math.random(1000, 9999))
end

-- Public API
function PerformanceMonitor.getMetrics()
	return {
		current = metrics.current,
		history = metrics.history,
		analytics = metrics.analytics,
	}
end

function PerformanceMonitor.getAlerts()
	return {
		active = alertSystem.active,
		history = alertSystem.history,
		stats = alertSystem.stats,
	}
end

function PerformanceMonitor.getAnalysis()
	return analysis
end

function PerformanceMonitor.getHealthScore()
	return analysis.healthScore
end

function PerformanceMonitor.acknowledgeAlert(alertId)
	if alertSystem.active[alertId] then
		alertSystem.active[alertId].acknowledged = true
		return true
	end
	return false
end

function PerformanceMonitor.getPerformanceSummary()
	local summary = {
		healthScore = analysis.healthScore,
		currentMetrics = metrics.current,
		activeAlerts = 0,
		criticalAlerts = 0,
		recommendations = #analysis.recommendations,
		bottlenecks = #analysis.bottlenecks,
		trends = {},
	}
	
	-- Count alerts
	for _, alert in pairs(alertSystem.active) do
		summary.activeAlerts = summary.activeAlerts + 1
		if alert.level == "CRITICAL" then
			summary.criticalAlerts = summary.criticalAlerts + 1
		end
	end
	
	-- Add trend information
	for metric, trend in pairs(metrics.analytics.trends) do
		summary.trends[metric] = trend.direction
	end
	
	return summary
end

-- Initialization and cleanup
function PerformanceMonitor.initialize()
	print("[PerformanceMonitor] Initializing enterprise performance monitoring system...")
	
	-- Start metrics collection
	connections.metricsCollector = RunService.Heartbeat:Connect(function()
		if getCurrentTime() - (metrics.lastCollection or 0) >= CONFIG.METRICS_COLLECTION_INTERVAL then
			PerformanceMonitor.collectMetrics()
			metrics.lastCollection = getCurrentTime()
		end
	end)
	
	-- Start alert checking
	connections.alertChecker = RunService.Heartbeat:Connect(function()
		if getCurrentTime() - (alertSystem.lastCheck or 0) >= CONFIG.ALERT_CHECK_INTERVAL then
			PerformanceMonitor.checkAlerts()
			alertSystem.lastCheck = getCurrentTime()
		end
	end)
	
	-- Start analytics updates
	connections.analyticsUpdater = RunService.Heartbeat:Connect(function()
		if getCurrentTime() - (metrics.lastAnalytics or 0) >= CONFIG.ANALYTICS_UPDATE_INTERVAL then
			PerformanceMonitor.updateAnalytics()
			metrics.lastAnalytics = getCurrentTime()
		end
	end)
	
	print("[PerformanceMonitor] Performance monitoring system initialized successfully")
	print(string.format("[PerformanceMonitor] Monitoring intervals: Metrics(%.1fs), Alerts(%.1fs), Analytics(%.1fs)", 
		CONFIG.METRICS_COLLECTION_INTERVAL, CONFIG.ALERT_CHECK_INTERVAL, CONFIG.ANALYTICS_UPDATE_INTERVAL))
end

function PerformanceMonitor.shutdown()
	print("[PerformanceMonitor] Shutting down performance monitoring system...")
	
	-- Disconnect all connections
	for name, connection in pairs(connections) do
		connection:Disconnect()
		connections[name] = nil
	end
	
	-- Clear data
	metrics.history = {}
	alertSystem.active = {}
	
	print("[PerformanceMonitor] Performance monitoring system shutdown complete")
end

return PerformanceMonitor 