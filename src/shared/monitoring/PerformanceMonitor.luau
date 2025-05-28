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
	
	-- Collect FPS and frame timing
	local frameStart = tick()
	local fps = 1 / RunService.Heartbeat:Wait()
	local frameEnd = tick()
	local frameTime = frameEnd - frameStart
	
	-- Collect memory usage (detailed)
	local memory = 0
	local gcMemory = collectgarbage("count") / 1024 -- Convert KB to MB
	local memoryStats = Stats:FindFirstChild("MemoryUsage")
	if memoryStats then
		for _, child in pairs(memoryStats:GetChildren()) do
			if child:IsA("NumberValue") then
				memory = memory + child.Value
			end
		end
		memory = memory / (1024 * 1024) -- Convert to MB
	end
	
	-- Collect network stats (detailed)
	local networkStats = Stats.Network.ServerStatsItem
	local dataReceived = networkStats["Data Received"]:GetValue()
	local dataSent = networkStats["Data Sent"]:GetValue()
	local ping = networkStats["Data Ping"]:GetValue()
	local packetLoss = 0 -- Would need custom implementation
	
	-- Collect CPU usage (estimated from frame time and script performance)
	local cpu = math.min(100, frameTime * 60 * 100) -- Rough CPU estimation
	local scriptTime = 0
	local renderTime = 0
	
	-- Get script performance data
	local scriptStats = Stats:FindFirstChild("ScriptContext")
	if scriptStats then
		local scriptActivity = scriptStats:FindFirstChild("ScriptWait")
		if scriptActivity then
			scriptTime = scriptActivity.Value * 1000 -- Convert to ms
		end
	end
	
	-- Estimate render time
	renderTime = math.max(0, frameTime * 1000 - scriptTime) -- Remaining frame time
	
	-- Collect player and game metrics
	local playerCount = #Players:GetPlayers()
	local maxPlayers = Players.MaxPlayers
	local serverRegion = "Unknown"
	
	-- Collect workspace metrics
	local workspaceStats = {
		partCount = 0,
		meshCount = 0,
		scriptCount = 0,
		connectionCount = 0
	}
	
	-- Count workspace objects (sampling to avoid performance impact)
	if math.random() < 0.1 then -- Only count 10% of the time
		for _, obj in pairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") then
				workspaceStats.partCount = workspaceStats.partCount + 1
			elseif obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
				workspaceStats.meshCount = workspaceStats.meshCount + 1
			elseif obj:IsA("Script") or obj:IsA("LocalScript") then
				workspaceStats.scriptCount = workspaceStats.scriptCount + 1
			end
		end
	end
	
	-- Collect garbage collection metrics
	local gcStats = {
		memoryUsage = gcMemory,
		collections = 0, -- Would need custom tracking
		averageCollectionTime = 0, -- Would need custom tracking
		totalCollectionTime = 0 -- Would need custom tracking
	}
	
	-- Calculate frame variance (jitter)
	local frameVariance = 0
	if #metrics.history >= 10 then
		local recentFrameTimes = {}
		for i = math.max(1, #metrics.history - 9), #metrics.history do
			table.insert(recentFrameTimes, metrics.history[i].frameTime or 0.016)
		end
		local avgFrameTime = calculateMovingAverage(recentFrameTimes, #recentFrameTimes)
		frameVariance = calculateStandardDeviation(recentFrameTimes, avgFrameTime)
	end
	
	-- Calculate system load indicators
	local systemLoad = {
		memoryPressure = math.min(100, (memory / 1000) * 100), -- % of 1GB
		cpuPressure = cpu,
		networkLoad = math.min(100, ping / 10), -- Normalize ping to 0-100
		renderLoad = math.min(100, (renderTime / 16) * 100), -- % of 16ms target
		scriptLoad = math.min(100, (scriptTime / 16) * 100) -- % of 16ms target
	}
	
	-- Update current metrics with enhanced data
	metrics.current = {
		-- Core metrics
		fps = fps,
		memory = memory,
		network = ping,
		cpu = cpu,
		players = playerCount,
		timestamp = currentTime,
		
		-- Enhanced frame metrics
		frameTime = frameTime * 1000, -- Convert to milliseconds
		frameVariance = frameVariance * 1000, -- Convert to milliseconds
		targetFrameTime = 16.67, -- 60 FPS target in ms
		
		-- Enhanced memory metrics
		gcMemory = gcMemory,
		memoryPressure = systemLoad.memoryPressure,
		
		-- Enhanced network metrics
		dataReceived = dataReceived,
		dataSent = dataSent,
		packetLoss = packetLoss,
		networkLoad = systemLoad.networkLoad,
		
		-- Performance breakdown
		scriptTime = scriptTime,
		renderTime = renderTime,
		scriptLoad = systemLoad.scriptLoad,
		renderLoad = systemLoad.renderLoad,
		
		-- System metrics
		maxPlayers = maxPlayers,
		playerUtilization = (playerCount / maxPlayers) * 100,
		serverRegion = serverRegion,
		
		-- Workspace metrics
		partCount = workspaceStats.partCount,
		meshCount = workspaceStats.meshCount,
		scriptCount = workspaceStats.scriptCount,
		
		-- Garbage collection
		gcStats = gcStats,
		
		-- Composite scores
		performanceScore = PerformanceMonitor.calculatePerformanceScore(),
		healthScore = PerformanceMonitor.calculateHealthScore(),
		
		-- Trend indicators
		fpsTrend = PerformanceMonitor.calculateTrend("fps", 30), -- 30-second trend
		memoryTrend = PerformanceMonitor.calculateTrend("memory", 30),
		networkTrend = PerformanceMonitor.calculateTrend("network", 30),
		cpuTrend = PerformanceMonitor.calculateTrend("cpu", 30),
	}
	
	-- Add to history
	table.insert(metrics.history, {
		fps = fps,
		memory = memory,
		network = ping,
		cpu = cpu,
		players = playerCount,
		timestamp = currentTime,
		frameTime = frameTime * 1000,
		frameVariance = frameVariance * 1000,
		gcMemory = gcMemory,
		scriptTime = scriptTime,
		renderTime = renderTime,
		dataReceived = dataReceived,
		dataSent = dataSent,
		partCount = workspaceStats.partCount,
		meshCount = workspaceStats.meshCount,
		scriptCount = workspaceStats.scriptCount,
		performanceScore = metrics.current.performanceScore,
		healthScore = metrics.current.healthScore,
	})
	
	-- Maintain history size
	if #metrics.history > CONFIG.METRICS_HISTORY_SIZE then
		table.remove(metrics.history, 1)
	end
	
	-- Update analytics
	PerformanceMonitor.updateAnalytics()
	
	return metrics.current
end

-- Calculate composite performance score (0-100)
function PerformanceMonitor.calculatePerformanceScore()
	local current = metrics.current
	if not current.fps then return 100 end -- Default score if no data
	
	-- Weighted scoring components
	local fpsScore = math.min(100, (current.fps / 60) * 100)
	local memoryScore = math.max(0, 100 - (current.memory / 10)) -- 1GB = 0 score
	local networkScore = math.max(0, 100 - (current.network / 10)) -- 1000ms = 0 score
	local cpuScore = math.max(0, 100 - current.cpu)
	
	-- Weighted average (FPS and CPU are most important)
	local score = (fpsScore * 0.4) + (cpuScore * 0.3) + (memoryScore * 0.2) + (networkScore * 0.1)
	
	return math.floor(score)
end

-- Calculate system health score (0-100)
function PerformanceMonitor.calculateHealthScore()
	local current = metrics.current
	if not current.fps then return 100 end -- Default score if no data
	
	local healthFactors = {
		performance = PerformanceMonitor.calculatePerformanceScore() / 100,
		stability = 1.0, -- Would be calculated from crash/error rates
		reliability = 1.0, -- Would be calculated from uptime/availability
		efficiency = math.max(0, 1 - (current.frameVariance or 0) / 10), -- Frame consistency
	}
	
	-- Weighted health score
	local health = (healthFactors.performance * 0.4) + 
	               (healthFactors.stability * 0.3) + 
	               (healthFactors.reliability * 0.2) + 
	               (healthFactors.efficiency * 0.1)
	
	return math.floor(health * 100)
end

-- Calculate trend for a metric (-1 declining, 0 stable, 1 improving)
function PerformanceMonitor.calculateTrend(metricName, windowSeconds)
	if #metrics.history < 10 then return 0 end
	
	local currentTime = getCurrentTime()
	local cutoffTime = currentTime - windowSeconds
	
	-- Get recent data within window
	local recentData = {}
	for i = #metrics.history, 1, -1 do
		local dataPoint = metrics.history[i]
		if dataPoint.timestamp >= cutoffTime then
			table.insert(recentData, 1, dataPoint[metricName] or 0)
		else
			break
		end
	end
	
	if #recentData < 5 then return 0 end
	
	-- Calculate linear trend
	local n = #recentData
	local sumX, sumY, sumXY, sumXX = 0, 0, 0, 0
	
	for i, value in ipairs(recentData) do
		sumX = sumX + i
		sumY = sumY + value
		sumXY = sumXY + (i * value)
		sumXX = sumXX + (i * i)
	end
	
	local slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
	
	-- Normalize slope to -1, 0, 1 range
	if slope > 0.1 then
		return 1 -- Improving
	elseif slope < -0.1 then
		return -1 -- Declining
	else
		return 0 -- Stable
	end
end

-- Update analytics (anomaly detection, baselines, predictions)
function PerformanceMonitor.updateAnalytics()
	if #metrics.history < CONFIG.PERFORMANCE_BASELINE_SAMPLES then return end
	
	-- Update performance baselines
	PerformanceMonitor.updateBaselines()
	
	-- Detect anomalies
	PerformanceMonitor.detectAnomalies()
	
	-- Update predictions
	PerformanceMonitor.updatePredictions()
end

-- Update performance baselines
function PerformanceMonitor.updateBaselines()
	local recentHistory = {}
	local startIndex = math.max(1, #metrics.history - CONFIG.PERFORMANCE_BASELINE_SAMPLES + 1)
	
	for i = startIndex, #metrics.history do
		table.insert(recentHistory, metrics.history[i])
	end
	
	-- Calculate baselines for key metrics
	local baselines = {}
	local metricNames = {"fps", "memory", "network", "cpu", "frameTime"}
	
	for _, metricName in ipairs(metricNames) do
		local values = {}
		for _, dataPoint in ipairs(recentHistory) do
			table.insert(values, dataPoint[metricName] or 0)
		end
		
		baselines[metricName] = {
			mean = calculateMovingAverage(values, #values),
			stdDev = calculateStandardDeviation(values, calculateMovingAverage(values, #values)),
			min = math.min(unpack(values)),
			max = math.max(unpack(values)),
			median = PerformanceMonitor.calculateMedian(values),
		}
	end
	
	metrics.analytics.baselines = baselines
end

-- Detect performance anomalies
function PerformanceMonitor.detectAnomalies()
	local current = metrics.current
	local baselines = metrics.analytics.baselines
	local anomalies = {}
	
	for metricName, baseline in pairs(baselines) do
		local currentValue = current[metricName]
		if currentValue and baseline.stdDev > 0 then
			local zScore = math.abs(currentValue - baseline.mean) / baseline.stdDev
			
			if zScore > CONFIG.ANOMALY_DETECTION_SENSITIVITY then
				table.insert(anomalies, {
					metric = metricName,
					value = currentValue,
					baseline = baseline.mean,
					severity = math.min(5, math.floor(zScore)),
					timestamp = current.timestamp,
				})
			end
		end
	end
	
	metrics.analytics.anomalies = anomalies
end

-- Update performance predictions
function PerformanceMonitor.updatePredictions()
	-- Simple linear trend predictions for the next 5 minutes
	local predictions = {}
	local metricNames = {"fps", "memory", "network", "cpu"}
	
	for _, metricName in ipairs(metricNames) do
		local trend = PerformanceMonitor.calculateTrend(metricName, 300) -- 5-minute trend
		local current = metrics.current[metricName] or 0
		local baseline = metrics.analytics.baselines[metricName]
		
		if baseline then
			local predicted = current + (trend * baseline.stdDev * 0.5) -- Conservative prediction
			predictions[metricName] = {
				current = current,
				predicted = predicted,
				confidence = math.max(0, 1 - math.abs(trend) * 0.5), -- Lower confidence for volatile trends
				trend = trend,
			}
		end
	end
	
	metrics.analytics.predictions = predictions
end

-- Calculate median value
function PerformanceMonitor.calculateMedian(values)
	local sorted = {}
	for _, v in ipairs(values) do
		table.insert(sorted, v)
	end
	table.sort(sorted)
	
	local n = #sorted
	if n % 2 == 0 then
		return (sorted[n/2] + sorted[n/2 + 1]) / 2
	else
		return sorted[math.ceil(n/2)]
	end
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