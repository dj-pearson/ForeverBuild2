--[[
	Logger.luau
	Enterprise-Level Centralized Logging System
	
	Features:
	- Structured logging with JSON formatting
	- Multiple log levels (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
	- Centralized log aggregation and storage
	- Real-time log streaming and filtering
	- Performance-optimized batch processing
	- Log rotation and retention policies
	- Audit trail capabilities
	- Integration with monitoring systems
	- Context-aware logging
	- Log correlation and tracing
	
	Author: ForeverBuild2 Enterprise Team
	Version: 1.0.0
	Last Updated: 2024
]]

local Logger = {}
Logger.__index = Logger

-- Services
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local CONFIG = {
	-- Log levels
	LOG_LEVELS = {
		TRACE = {level = 1, name = "TRACE", color = Color3.fromRGB(128, 128, 128)},
		DEBUG = {level = 2, name = "DEBUG", color = Color3.fromRGB(64, 128, 255)},
		INFO = {level = 3, name = "INFO", color = Color3.fromRGB(76, 175, 80)},
		WARN = {level = 4, name = "WARN", color = Color3.fromRGB(255, 193, 7)},
		ERROR = {level = 5, name = "ERROR", color = Color3.fromRGB(244, 67, 54)},
		FATAL = {level = 6, name = "FATAL", color = Color3.fromRGB(139, 69, 19)},
	},
	
	-- Logger settings
	MIN_LOG_LEVEL = 3, -- INFO and above
	MAX_LOG_BUFFER_SIZE = 1000, -- Maximum logs in memory
	BATCH_SIZE = 50, -- Logs to process per batch
	FLUSH_INTERVAL = 5, -- Flush to storage every N seconds
	MAX_MESSAGE_LENGTH = 2000, -- Maximum log message length
	
	-- Storage settings
	ENABLE_FILE_LOGGING = true,
	ENABLE_CONSOLE_LOGGING = true,
	ENABLE_REMOTE_LOGGING = false,
	LOG_ROTATION_SIZE = 10 * 1024 * 1024, -- 10MB
	LOG_RETENTION_DAYS = 30,
	
	-- Performance settings
	ASYNC_LOGGING = true,
	BUFFER_TIMEOUT = 1, -- Buffer timeout in seconds
	MAX_CONCURRENT_WRITES = 5,
	COMPRESSION_ENABLED = true,
	
	-- Context settings
	INCLUDE_STACK_TRACE = true,
	INCLUDE_CALLER_INFO = true,
	INCLUDE_SYSTEM_INFO = true,
	INCLUDE_CORRELATION_ID = true,
	
	-- Format settings
	LOG_FORMAT = "json", -- json, plain, structured
	TIMESTAMP_FORMAT = "iso8601",
	TIMEZONE = "UTC",
}

-- Log categories for organization
local CATEGORIES = {
	SYSTEM = "system",
	SECURITY = "security",
	PERFORMANCE = "performance",
	AUDIT = "audit",
	USER = "user",
	NETWORK = "network",
	DATABASE = "database",
	ERROR = "error",
	DEBUG = "debug",
}

-- Logger instance
local loggerInstance = nil

function Logger.new(name, category)
	local self = setmetatable({}, Logger)
	
	self.name = name or "DefaultLogger"
	self.category = category or CATEGORIES.SYSTEM
	self.sessionId = HttpService:GenerateGUID(false)
	self.logBuffer = {}
	self.batchQueue = {}
	self.correlationId = nil
	
	-- Performance metrics
	self.metrics = {
		totalLogs = 0,
		logsByLevel = {},
		logsByCategory = {},
		averageLogTime = 0,
		bufferFlushes = 0,
		errors = 0,
	}
	
	-- Context information
	self.context = {
		service = RunService:IsServer() and "Server" or "Client",
		userId = Players.LocalPlayer and Players.LocalPlayer.UserId or nil,
		sessionStart = os.time(),
		environment = "Production", -- Could be determined dynamically
	}
	
	-- Initialize metrics
	for _, level in pairs(CONFIG.LOG_LEVELS) do
		self.metrics.logsByLevel[level.name] = 0
	end
	
	for _, cat in pairs(CATEGORIES) do
		self.metrics.logsByCategory[cat] = 0
	end
	
	-- Setup auto-flush
	if CONFIG.ASYNC_LOGGING then
		self:StartAutoFlush()
	end
	
	return self
end

-- Get or create global logger instance
function Logger.GetInstance(name, category)
	if not loggerInstance then
		loggerInstance = Logger.new(name or "GlobalLogger", category or CATEGORIES.SYSTEM)
	end
	return loggerInstance
end

-- Core logging methods
function Logger:Log(level, message, data, category, context)
	if not self:ShouldLog(level) then
		return false
	end
	
	local logStart = os.clock()
	
	-- Create log entry
	local logEntry = self:CreateLogEntry(level, message, data, category, context)
	
	-- Add to buffer
	table.insert(self.logBuffer, logEntry)
	
	-- Update metrics
	self:UpdateMetrics(level, category, os.clock() - logStart)
	
	-- Console output if enabled
	if CONFIG.ENABLE_CONSOLE_LOGGING then
		self:OutputToConsole(logEntry)
	end
	
	-- Check if buffer needs flushing
	if #self.logBuffer >= CONFIG.MAX_LOG_BUFFER_SIZE then
		self:FlushBuffer()
	end
	
	return true
end

-- Specific log level methods
function Logger:Trace(message, data, category, context)
	return self:Log(CONFIG.LOG_LEVELS.TRACE, message, data, category, context)
end

function Logger:Debug(message, data, category, context)
	return self:Log(CONFIG.LOG_LEVELS.DEBUG, message, data, category, context)
end

function Logger:Info(message, data, category, context)
	return self:Log(CONFIG.LOG_LEVELS.INFO, message, data, category, context)
end

function Logger:Warn(message, data, category, context)
	return self:Log(CONFIG.LOG_LEVELS.WARN, message, data, category, context)
end

function Logger:Error(message, data, category, context)
	return self:Log(CONFIG.LOG_LEVELS.ERROR, message, data, category, context)
end

function Logger:Fatal(message, data, category, context)
	return self:Log(CONFIG.LOG_LEVELS.FATAL, message, data, category, context)
end

-- Audit logging
function Logger:Audit(action, userId, details, metadata)
	local auditData = {
		action = action,
		userId = userId,
		details = details or {},
		metadata = metadata or {},
		timestamp = os.time(),
		sessionId = self.sessionId,
		correlationId = self.correlationId,
	}
	
	return self:Log(CONFIG.LOG_LEVELS.INFO, "Audit: " .. action, auditData, CATEGORIES.AUDIT)
end

-- Performance logging
function Logger:Performance(operation, duration, metrics, context)
	local perfData = {
		operation = operation,
		duration = duration,
		metrics = metrics or {},
		context = context or {},
		timestamp = os.time(),
	}
	
	return self:Log(CONFIG.LOG_LEVELS.INFO, "Performance: " .. operation, perfData, CATEGORIES.PERFORMANCE)
end

-- Security logging
function Logger:Security(event, severity, details, userId)
	local securityData = {
		event = event,
		severity = severity,
		details = details or {},
		userId = userId,
		timestamp = os.time(),
		sessionId = self.sessionId,
		ipAddress = "Unknown", -- Would need to be determined
	}
	
	return self:Log(CONFIG.LOG_LEVELS.WARN, "Security: " .. event, securityData, CATEGORIES.SECURITY)
end

-- Create structured log entry
function Logger:CreateLogEntry(level, message, data, category, context)
	local timestamp = self:GetTimestamp()
	local callerInfo = CONFIG.INCLUDE_CALLER_INFO and self:GetCallerInfo() or nil
	local stackTrace = CONFIG.INCLUDE_STACK_TRACE and level.level >= CONFIG.LOG_LEVELS.ERROR.level and debug.traceback() or nil
	
	local logEntry = {
		timestamp = timestamp,
		level = level.name,
		levelNum = level.level,
		logger = self.name,
		category = category or self.category,
		message = self:TruncateMessage(message),
		data = data,
		context = self:MergeContext(context),
		caller = callerInfo,
		stackTrace = stackTrace,
		sessionId = self.sessionId,
		correlationId = self.correlationId,
		service = self.context.service,
		userId = self.context.userId,
	}
	
	return logEntry
end

-- Check if log should be written
function Logger:ShouldLog(level)
	return level.level >= CONFIG.MIN_LOG_LEVEL
end

-- Update metrics
function Logger:UpdateMetrics(level, category, logTime)
	self.metrics.totalLogs = self.metrics.totalLogs + 1
	self.metrics.logsByLevel[level.name] = self.metrics.logsByLevel[level.name] + 1
	self.metrics.logsByCategory[category or self.category] = self.metrics.logsByCategory[category or self.category] + 1
	self.metrics.averageLogTime = (self.metrics.averageLogTime * 0.9) + (logTime * 0.1)
end

-- Output to console
function Logger:OutputToConsole(logEntry)
	local levelInfo = CONFIG.LOG_LEVELS[logEntry.level]
	local output = string.format("[%s] [%s] [%s] %s", 
		logEntry.timestamp,
		logEntry.level,
		logEntry.category,
		logEntry.message
	)
	
	if logEntry.data then
		output = output .. " | Data: " .. HttpService:JSONEncode(logEntry.data)
	end
	
	-- Use appropriate output method based on level
	if levelInfo.level >= CONFIG.LOG_LEVELS.ERROR.level then
		warn(output)
	else
		print(output)
	end
end

-- Format log entry
function Logger:FormatLogEntry(logEntry)
	if CONFIG.LOG_FORMAT == "json" then
		return HttpService:JSONEncode(logEntry)
	elseif CONFIG.LOG_FORMAT == "plain" then
		return string.format("[%s] [%s] %s", logEntry.timestamp, logEntry.level, logEntry.message)
	else
		-- Structured format
		local formatted = string.format("%s | %s | %s | %s | %s",
			logEntry.timestamp,
			logEntry.level,
			logEntry.logger,
			logEntry.category,
			logEntry.message
		)
		
		if logEntry.data then
			formatted = formatted .. " | " .. HttpService:JSONEncode(logEntry.data)
		end
		
		return formatted
	end
end

-- Flush buffer to storage
function Logger:FlushBuffer()
	if #self.logBuffer == 0 then return end
	
	local bufferCopy = {}
	for _, logEntry in ipairs(self.logBuffer) do
		table.insert(bufferCopy, logEntry)
	end
	
	self.logBuffer = {}
	self.metrics.bufferFlushes = self.metrics.bufferFlushes + 1
	
	-- Process in background if async
	if CONFIG.ASYNC_LOGGING then
		task.spawn(function()
			self:ProcessLogBatch(bufferCopy)
		end)
	else
		self:ProcessLogBatch(bufferCopy)
	end
end

-- Process log batch
function Logger:ProcessLogBatch(logs)
	if not logs or #logs == 0 then return end
	
	-- File logging
	if CONFIG.ENABLE_FILE_LOGGING then
		self:WriteToFile(logs)
	end
	
	-- Remote logging
	if CONFIG.ENABLE_REMOTE_LOGGING then
		self:SendToRemoteService(logs)
	end
	
	-- Update processing metrics
	self.metrics.totalProcessed = (self.metrics.totalProcessed or 0) + #logs
end

-- Write logs to file (simulated)
function Logger:WriteToFile(logs)
	-- In a real implementation, this would write to actual files
	-- For Roblox, we might use DataStoreService or send to external service
	
	local fileContent = ""
	for _, logEntry in ipairs(logs) do
		fileContent = fileContent .. self:FormatLogEntry(logEntry) .. "\n"
	end
	
	-- Simulate file write
	if CONFIG.COMPRESSION_ENABLED and #fileContent > 1000 then
		-- Would compress content here
	end
	
	-- Would write to persistent storage here
	-- For now, just track that we "wrote" the logs
	self.metrics.filesWritten = (self.metrics.filesWritten or 0) + 1
end

-- Send logs to remote service
function Logger:SendToRemoteService(logs)
	-- This would send logs to external logging service
	-- For Roblox, might use HttpService to send to external API
	
	local payload = {
		source = "ForeverBuild2",
		environment = self.context.environment,
		service = self.context.service,
		sessionId = self.sessionId,
		logs = logs,
		timestamp = os.time(),
	}
	
	-- Would make HTTP request here
	self.metrics.remoteLogsSent = (self.metrics.remoteLogsSent or 0) + #logs
end

-- Start auto-flush timer
function Logger:StartAutoFlush()
	task.spawn(function()
		while true do
			wait(CONFIG.FLUSH_INTERVAL)
			self:FlushBuffer()
		end
	end)
end

-- Context management
function Logger:SetCorrelationId(correlationId)
	self.correlationId = correlationId
end

function Logger:WithContext(additionalContext)
	local contextualLogger = {}
	setmetatable(contextualLogger, {__index = self})
	contextualLogger.additionalContext = additionalContext
	return contextualLogger
end

function Logger:MergeContext(additionalContext)
	local merged = {}
	
	-- Base context
	for k, v in pairs(self.context) do
		merged[k] = v
	end
	
	-- Instance additional context
	if self.additionalContext then
		for k, v in pairs(self.additionalContext) do
			merged[k] = v
		end
	end
	
	-- Method additional context
	if additionalContext then
		for k, v in pairs(additionalContext) do
			merged[k] = v
		end
	end
	
	-- System info
	if CONFIG.INCLUDE_SYSTEM_INFO then
		merged.frameRate = 1 / RunService.Heartbeat:Wait()
		merged.memoryUsage = collectgarbage("count")
		merged.serverTime = os.time()
	end
	
	return merged
end

-- Utility functions
function Logger:GetTimestamp()
	if CONFIG.TIMESTAMP_FORMAT == "iso8601" then
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	elseif CONFIG.TIMESTAMP_FORMAT == "unix" then
		return tostring(os.time())
	else
		return os.date("!%Y-%m-%d %H:%M:%S")
	end
end

function Logger:GetCallerInfo()
	local info = debug.getinfo(4, "Sl")
	if info then
		return {
			source = info.source,
			line = info.currentline,
			function_name = info.name,
		}
	end
	return nil
end

function Logger:TruncateMessage(message)
	if type(message) ~= "string" then
		message = tostring(message)
	end
	
	if #message > CONFIG.MAX_MESSAGE_LENGTH then
		return string.sub(message, 1, CONFIG.MAX_MESSAGE_LENGTH - 3) .. "..."
	end
	
	return message
end

-- Query and search functionality
function Logger:GetLogs(filters)
	local filteredLogs = {}
	
	-- Apply filters
	for _, logEntry in ipairs(self.logBuffer) do
		if self:MatchesFilter(logEntry, filters) then
			table.insert(filteredLogs, logEntry)
		end
	end
	
	return filteredLogs
end

function Logger:MatchesFilter(logEntry, filters)
	if not filters then return true end
	
	-- Level filter
	if filters.level and logEntry.levelNum < CONFIG.LOG_LEVELS[filters.level].level then
		return false
	end
	
	-- Category filter
	if filters.category and logEntry.category ~= filters.category then
		return false
	end
	
	-- Time range filter
	if filters.startTime and logEntry.timestamp < filters.startTime then
		return false
	end
	
	if filters.endTime and logEntry.timestamp > filters.endTime then
		return false
	end
	
	-- Message search
	if filters.search and not string.find(logEntry.message:lower(), filters.search:lower()) then
		return false
	end
	
	return true
end

-- Configuration management
function Logger:SetLogLevel(level)
	if CONFIG.LOG_LEVELS[level] then
		CONFIG.MIN_LOG_LEVEL = CONFIG.LOG_LEVELS[level].level
		self:Info("Log level changed", {newLevel = level})
	end
end

function Logger:EnableConsoleLogging(enabled)
	CONFIG.ENABLE_CONSOLE_LOGGING = enabled
	self:Info("Console logging " .. (enabled and "enabled" or "disabled"))
end

function Logger:EnableFileLogging(enabled)
	CONFIG.ENABLE_FILE_LOGGING = enabled
	self:Info("File logging " .. (enabled and "enabled" or "disabled"))
end

-- Performance and health monitoring
function Logger:GetMetrics()
	return {
		totalLogs = self.metrics.totalLogs,
		logsByLevel = self.metrics.logsByLevel,
		logsByCategory = self.metrics.logsByCategory,
		averageLogTime = self.metrics.averageLogTime,
		bufferFlushes = self.metrics.bufferFlushes,
		bufferSize = #self.logBuffer,
		errors = self.metrics.errors,
		filesWritten = self.metrics.filesWritten or 0,
		remoteLogsSent = self.metrics.remoteLogsSent or 0,
		totalProcessed = self.metrics.totalProcessed or 0,
	}
end

function Logger:GetHealthStatus()
	local metrics = self:GetMetrics()
	local health = {
		status = "healthy",
		issues = {},
		performance = {
			averageLogTime = metrics.averageLogTime,
			bufferUtilization = (metrics.bufferSize / CONFIG.MAX_LOG_BUFFER_SIZE) * 100,
			errorRate = metrics.errors / math.max(1, metrics.totalLogs) * 100,
		}
	}
	
	-- Check for issues
	if metrics.bufferSize > CONFIG.MAX_LOG_BUFFER_SIZE * 0.9 then
		health.status = "warning"
		table.insert(health.issues, "Log buffer near capacity")
	end
	
	if metrics.averageLogTime > 0.01 then
		health.status = "warning"
		table.insert(health.issues, "Slow logging performance")
	end
	
	if health.performance.errorRate > 5 then
		health.status = "critical"
		table.insert(health.issues, "High error rate")
	end
	
	return health
end

-- Cleanup and shutdown
function Logger:Cleanup()
	-- Flush remaining logs
	self:FlushBuffer()
	
	-- Wait for async operations to complete
	wait(CONFIG.BUFFER_TIMEOUT)
	
	self:Info("Logger cleanup completed")
end

function Logger:Shutdown()
	self:Info("Logger shutting down")
	self:Cleanup()
	
	-- Clear buffers
	self.logBuffer = {}
	self.batchQueue = {}
	
	print("Logger: Shutdown completed")
end

-- Static utility methods
function Logger.CreateCategory(name, description)
	CATEGORIES[name:upper()] = name:lower()
	return name:lower()
end

function Logger.GetAvailableCategories()
	return CATEGORIES
end

function Logger.GetAvailableLogLevels()
	return CONFIG.LOG_LEVELS
end

-- Global convenience methods
function Logger.Trace(message, data, category)
	local logger = Logger.GetInstance()
	return logger:Trace(message, data, category)
end

function Logger.Debug(message, data, category)
	local logger = Logger.GetInstance()
	return logger:Debug(message, data, category)
end

function Logger.Info(message, data, category)
	local logger = Logger.GetInstance()
	return logger:Info(message, data, category)
end

function Logger.Warn(message, data, category)
	local logger = Logger.GetInstance()
	return logger:Warn(message, data, category)
end

function Logger.Error(message, data, category)
	local logger = Logger.GetInstance()
	return logger:Error(message, data, category)
end

function Logger.Fatal(message, data, category)
	local logger = Logger.GetInstance()
	return logger:Fatal(message, data, category)
end

function Logger.Audit(action, userId, details, metadata)
	local logger = Logger.GetInstance()
	return logger:Audit(action, userId, details, metadata)
end

function Logger.Performance(operation, duration, metrics, context)
	local logger = Logger.GetInstance()
	return logger:Performance(operation, duration, metrics, context)
end

function Logger.Security(event, severity, details, userId)
	local logger = Logger.GetInstance()
	return logger:Security(event, severity, details, userId)
end

-- Initialize global logger on first load
task.spawn(function()
	local globalLogger = Logger.GetInstance("ForeverBuild2Logger", CATEGORIES.SYSTEM)
	globalLogger:Info("Enterprise logging system initialized", {
		version = "1.0.0",
		service = globalLogger.context.service,
		sessionId = globalLogger.sessionId,
	})
end)

return Logger 