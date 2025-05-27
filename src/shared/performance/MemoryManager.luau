--[[
	MemoryManager.luau
	Enterprise-Level Memory Management System
	
	Features:
	- Predictive memory management with ML-like algorithms
	- Smart garbage collection with adaptive scheduling
	- Memory leak detection and prevention
	- Real-time memory monitoring and optimization
	- Memory pool management for high-frequency allocations
	- Automatic cleanup and resource management
	- Performance analytics and reporting
	
	Author: ForeverBuild2 Enterprise Team
	Version: 1.0.0
	Last Updated: 2024
]]

local MemoryManager = {}
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local CONFIG = {
	-- Memory thresholds (in MB)
	MEMORY_WARNING_THRESHOLD = 512,
	MEMORY_CRITICAL_THRESHOLD = 768,
	MEMORY_EMERGENCY_THRESHOLD = 1024,
	
	-- Garbage collection settings
	GC_INTERVAL_NORMAL = 30, -- seconds
	GC_INTERVAL_HIGH_LOAD = 15, -- seconds
	GC_INTERVAL_CRITICAL = 5, -- seconds
	
	-- Memory pool settings
	POOL_INITIAL_SIZE = 100,
	POOL_MAX_SIZE = 1000,
	POOL_GROWTH_FACTOR = 1.5,
	
	-- Monitoring settings
	MONITORING_INTERVAL = 1, -- seconds
	HISTORY_RETENTION = 300, -- 5 minutes of history
	LEAK_DETECTION_THRESHOLD = 50, -- MB growth without cleanup
	
	-- Prediction settings
	PREDICTION_WINDOW = 60, -- seconds
	PREDICTION_SAMPLES = 30,
	TREND_ANALYSIS_WINDOW = 180, -- 3 minutes
}

-- Memory tracking data
local memoryData = {
	currentUsage = 0,
	peakUsage = 0,
	history = {},
	leakSuspects = {},
	pools = {},
	allocations = {},
	gcStats = {
		totalCollections = 0,
		totalTimeSpent = 0,
		lastCollection = 0,
		averageCollectionTime = 0,
	},
	predictions = {
		nextPeak = 0,
		timeToThreshold = 0,
		growthRate = 0,
		trend = "STABLE", -- STABLE, GROWING, DECLINING, VOLATILE
	},
}

-- Memory pools for different object types
local memoryPools = {
	vectors = {},
	tables = {},
	strings = {},
	instances = {},
	connections = {},
}

-- Active monitoring connections
local connections = {}

-- Utility functions
local function getCurrentMemoryUsage()
	local stats = game:GetService("Stats")
	local memoryStats = stats:FindFirstChild("MemoryUsage")
	if memoryStats then
		local totalMemory = 0
		for _, child in pairs(memoryStats:GetChildren()) do
			if child:IsA("NumberValue") then
				totalMemory = totalMemory + child.Value
			end
		end
		return totalMemory / (1024 * 1024) -- Convert to MB
	end
	return 0
end

local function calculateMovingAverage(data, window)
	if #data < window then
		window = #data
	end
	
	local sum = 0
	for i = #data - window + 1, #data do
		sum = sum + data[i].usage
	end
	
	return window > 0 and sum / window or 0
end

local function detectMemoryTrend(history)
	if #history < 10 then
		return "STABLE"
	end
	
	local recentAvg = calculateMovingAverage(history, 10)
	local olderAvg = calculateMovingAverage(history, 30)
	
	local difference = recentAvg - olderAvg
	local percentChange = math.abs(difference) / olderAvg * 100
	
	if percentChange < 5 then
		return "STABLE"
	elseif difference > 0 then
		if percentChange > 20 then
			return "VOLATILE"
		else
			return "GROWING"
		end
	else
		return "DECLINING"
	end
end

local function predictMemoryUsage(history)
	if #history < CONFIG.PREDICTION_SAMPLES then
		return {
			nextPeak = memoryData.currentUsage,
			timeToThreshold = math.huge,
			growthRate = 0,
			confidence = 0,
		}
	end
	
	-- Linear regression for trend prediction
	local n = math.min(CONFIG.PREDICTION_SAMPLES, #history)
	local sumX, sumY, sumXY, sumX2 = 0, 0, 0, 0
	
	for i = #history - n + 1, #history do
		local x = i - (#history - n)
		local y = history[i].usage
		sumX = sumX + x
		sumY = sumY + y
		sumXY = sumXY + x * y
		sumX2 = sumX2 + x * x
	end
	
	local slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
	local intercept = (sumY - slope * sumX) / n
	
	-- Predict future usage
	local futureTime = CONFIG.PREDICTION_WINDOW
	local predictedUsage = intercept + slope * (n + futureTime)
	
	-- Calculate time to threshold
	local timeToWarning = math.huge
	if slope > 0 then
		timeToWarning = (CONFIG.MEMORY_WARNING_THRESHOLD - memoryData.currentUsage) / slope
	end
	
	-- Calculate confidence based on variance
	local variance = 0
	for i = #history - n + 1, #history do
		local x = i - (#history - n)
		local predicted = intercept + slope * x
		local actual = history[i].usage
		variance = variance + (predicted - actual) ^ 2
	end
	variance = variance / n
	local confidence = math.max(0, 1 - variance / 100) -- Normalize confidence
	
	return {
		nextPeak = math.max(predictedUsage, memoryData.currentUsage),
		timeToThreshold = timeToWarning,
		growthRate = slope,
		confidence = confidence,
	}
end

-- Memory pool management
function MemoryManager.createPool(poolType, initialSize)
	initialSize = initialSize or CONFIG.POOL_INITIAL_SIZE
	
	local pool = {
		type = poolType,
		available = {},
		inUse = {},
		totalCreated = 0,
		totalReused = 0,
		maxSize = CONFIG.POOL_MAX_SIZE,
	}
	
	-- Pre-populate pool based on type
	for i = 1, initialSize do
		local object
		if poolType == "vector" then
			object = Vector3.new(0, 0, 0)
		elseif poolType == "table" then
			object = {}
		elseif poolType == "string" then
			object = ""
		else
			object = {}
		end
		
		table.insert(pool.available, object)
		pool.totalCreated = pool.totalCreated + 1
	end
	
	memoryPools[poolType] = pool
	return pool
end

function MemoryManager.getFromPool(poolType)
	local pool = memoryPools[poolType]
	if not pool then
		pool = MemoryManager.createPool(poolType)
	end
	
	local object
	if #pool.available > 0 then
		object = table.remove(pool.available)
		pool.totalReused = pool.totalReused + 1
	else
		-- Create new object if pool is empty
		if poolType == "vector" then
			object = Vector3.new(0, 0, 0)
		elseif poolType == "table" then
			object = {}
		elseif poolType == "string" then
			object = ""
		else
			object = {}
		end
		pool.totalCreated = pool.totalCreated + 1
	end
	
	pool.inUse[object] = true
	return object
end

function MemoryManager.returnToPool(poolType, object)
	local pool = memoryPools[poolType]
	if not pool or not pool.inUse[object] then
		return false
	end
	
	pool.inUse[object] = nil
	
	-- Clean object before returning to pool
	if poolType == "table" then
		for k in pairs(object) do
			object[k] = nil
		end
	elseif poolType == "vector" then
		-- Vectors are immutable, no cleaning needed
	end
	
	-- Only return to pool if under max size
	if #pool.available < pool.maxSize then
		table.insert(pool.available, object)
	end
	
	return true
end

-- Memory leak detection
function MemoryManager.detectMemoryLeaks()
	local currentTime = tick()
	local currentUsage = memoryData.currentUsage
	
	-- Check for sustained growth without cleanup
	if #memoryData.history >= 60 then -- 1 minute of data
		local oldUsage = memoryData.history[#memoryData.history - 59].usage
		local growth = currentUsage - oldUsage
		
		if growth > CONFIG.LEAK_DETECTION_THRESHOLD then
			local leak = {
				timestamp = currentTime,
				growth = growth,
				duration = 60,
				severity = growth > CONFIG.LEAK_DETECTION_THRESHOLD * 2 and "HIGH" or "MEDIUM",
			}
			
			table.insert(memoryData.leakSuspects, leak)
			
			-- Trigger emergency cleanup if severe
			if leak.severity == "HIGH" then
				MemoryManager.emergencyCleanup()
			end
			
			return leak
		end
	end
	
	return nil
end

-- Smart garbage collection
function MemoryManager.performSmartGC()
	local startTime = tick()
	local beforeUsage = memoryData.currentUsage
	
	-- Determine GC aggressiveness based on memory pressure
	local gcLevel = 1
	if memoryData.currentUsage > CONFIG.MEMORY_CRITICAL_THRESHOLD then
		gcLevel = 3
	elseif memoryData.currentUsage > CONFIG.MEMORY_WARNING_THRESHOLD then
		gcLevel = 2
	end
	
	-- Perform garbage collection
	for i = 1, gcLevel do
		collectgarbage("collect")
		if i < gcLevel then
			wait(0.1) -- Brief pause between aggressive collections
		end
	end
	
	local afterUsage = getCurrentMemoryUsage()
	local collectionTime = tick() - startTime
	local memoryFreed = beforeUsage - afterUsage
	
	-- Update GC statistics
	memoryData.gcStats.totalCollections = memoryData.gcStats.totalCollections + 1
	memoryData.gcStats.totalTimeSpent = memoryData.gcStats.totalTimeSpent + collectionTime
	memoryData.gcStats.lastCollection = tick()
	memoryData.gcStats.averageCollectionTime = memoryData.gcStats.totalTimeSpent / memoryData.gcStats.totalCollections
	
	return {
		memoryFreed = memoryFreed,
		collectionTime = collectionTime,
		gcLevel = gcLevel,
		efficiency = memoryFreed / collectionTime,
	}
end

-- Emergency cleanup procedures
function MemoryManager.emergencyCleanup()
	warn("[MemoryManager] Emergency cleanup initiated - Critical memory usage detected")
	
	-- 1. Force aggressive garbage collection
	for i = 1, 5 do
		collectgarbage("collect")
		wait(0.05)
	end
	
	-- 2. Clear memory pools
	for poolType, pool in pairs(memoryPools) do
		pool.available = {}
		pool.inUse = {}
	end
	
	-- 3. Clear old history data
	if #memoryData.history > 100 then
		local keepCount = 50
		local newHistory = {}
		for i = #memoryData.history - keepCount + 1, #memoryData.history do
			table.insert(newHistory, memoryData.history[i])
		end
		memoryData.history = newHistory
	end
	
	-- 4. Clear old leak suspects
	memoryData.leakSuspects = {}
	
	-- 5. Trigger cleanup events for other systems
	local cleanupEvent = ReplicatedStorage:FindFirstChild("MemoryCleanupEvent")
	if cleanupEvent then
		cleanupEvent:FireAllClients()
	end
	
	warn("[MemoryManager] Emergency cleanup completed")
end

-- Monitoring and analytics
function MemoryManager.updateMemoryStats()
	local currentUsage = getCurrentMemoryUsage()
	local currentTime = tick()
	
	memoryData.currentUsage = currentUsage
	memoryData.peakUsage = math.max(memoryData.peakUsage, currentUsage)
	
	-- Add to history
	table.insert(memoryData.history, {
		timestamp = currentTime,
		usage = currentUsage,
	})
	
	-- Maintain history size
	if #memoryData.history > CONFIG.HISTORY_RETENTION then
		table.remove(memoryData.history, 1)
	end
	
	-- Update predictions
	local prediction = predictMemoryUsage(memoryData.history)
	memoryData.predictions = prediction
	memoryData.predictions.trend = detectMemoryTrend(memoryData.history)
	
	-- Check for memory leaks
	MemoryManager.detectMemoryLeaks()
	
	-- Determine if GC is needed
	local shouldGC = false
	local gcInterval = CONFIG.GC_INTERVAL_NORMAL
	
	if currentUsage > CONFIG.MEMORY_CRITICAL_THRESHOLD then
		shouldGC = true
		gcInterval = CONFIG.GC_INTERVAL_CRITICAL
	elseif currentUsage > CONFIG.MEMORY_WARNING_THRESHOLD then
		shouldGC = true
		gcInterval = CONFIG.GC_INTERVAL_HIGH_LOAD
	elseif currentTime - memoryData.gcStats.lastCollection > CONFIG.GC_INTERVAL_NORMAL then
		shouldGC = true
	end
	
	if shouldGC then
		MemoryManager.performSmartGC()
	end
end

-- Public API
function MemoryManager.getMemoryStats()
	return {
		current = memoryData.currentUsage,
		peak = memoryData.peakUsage,
		predictions = memoryData.predictions,
		gcStats = memoryData.gcStats,
		pools = memoryPools,
		leakSuspects = memoryData.leakSuspects,
		history = memoryData.history,
	}
end

function MemoryManager.getMemoryHealth()
	local usage = memoryData.currentUsage
	local health = "EXCELLENT"
	local score = 100
	
	if usage > CONFIG.MEMORY_EMERGENCY_THRESHOLD then
		health = "CRITICAL"
		score = 10
	elseif usage > CONFIG.MEMORY_CRITICAL_THRESHOLD then
		health = "POOR"
		score = 30
	elseif usage > CONFIG.MEMORY_WARNING_THRESHOLD then
		health = "FAIR"
		score = 60
	elseif usage > CONFIG.MEMORY_WARNING_THRESHOLD * 0.7 then
		health = "GOOD"
		score = 80
	end
	
	-- Adjust score based on trend
	if memoryData.predictions.trend == "GROWING" then
		score = score - 10
	elseif memoryData.predictions.trend == "VOLATILE" then
		score = score - 15
	elseif memoryData.predictions.trend == "DECLINING" then
		score = score + 5
	end
	
	-- Adjust score based on leak suspects
	if #memoryData.leakSuspects > 0 then
		score = score - (#memoryData.leakSuspects * 5)
	end
	
	return {
		health = health,
		score = math.max(0, math.min(100, score)),
		usage = usage,
		trend = memoryData.predictions.trend,
		leakCount = #memoryData.leakSuspects,
	}
end

function MemoryManager.forceGarbageCollection()
	return MemoryManager.performSmartGC()
end

function MemoryManager.clearMemoryPools()
	for poolType, pool in pairs(memoryPools) do
		pool.available = {}
		pool.inUse = {}
	end
end

function MemoryManager.getPoolStats()
	local stats = {}
	for poolType, pool in pairs(memoryPools) do
		stats[poolType] = {
			available = #pool.available,
			inUse = 0,
			totalCreated = pool.totalCreated,
			totalReused = pool.totalReused,
			reuseRate = pool.totalReused / math.max(1, pool.totalCreated) * 100,
		}
		
		for _ in pairs(pool.inUse) do
			stats[poolType].inUse = stats[poolType].inUse + 1
		end
	end
	return stats
end

-- Initialization
function MemoryManager.initialize()
	print("[MemoryManager] Initializing enterprise memory management system...")
	
	-- Create initial memory pools
	MemoryManager.createPool("vector", 50)
	MemoryManager.createPool("table", 100)
	MemoryManager.createPool("string", 25)
	
	-- Start monitoring
	connections.memoryMonitor = RunService.Heartbeat:Connect(function()
		if tick() - (memoryData.lastUpdate or 0) >= CONFIG.MONITORING_INTERVAL then
			MemoryManager.updateMemoryStats()
			memoryData.lastUpdate = tick()
		end
	end)
	
	-- Create cleanup event for emergency situations
	if not ReplicatedStorage:FindFirstChild("MemoryCleanupEvent") then
		local cleanupEvent = Instance.new("RemoteEvent")
		cleanupEvent.Name = "MemoryCleanupEvent"
		cleanupEvent.Parent = ReplicatedStorage
	end
	
	print("[MemoryManager] Memory management system initialized successfully")
	print(string.format("[MemoryManager] Current memory usage: %.2f MB", getCurrentMemoryUsage()))
end

function MemoryManager.shutdown()
	print("[MemoryManager] Shutting down memory management system...")
	
	-- Disconnect all connections
	for name, connection in pairs(connections) do
		connection:Disconnect()
		connections[name] = nil
	end
	
	-- Clear all pools
	MemoryManager.clearMemoryPools()
	
	-- Final garbage collection
	MemoryManager.performSmartGC()
	
	print("[MemoryManager] Memory management system shutdown complete")
end

return MemoryManager 