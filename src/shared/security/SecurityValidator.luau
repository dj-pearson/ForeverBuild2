-- SecurityValidator.luau
-- Enterprise-level input validation and sanitization system
-- Prevents injection attacks, data corruption, and exploit attempts

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local SecurityValidator = {}
SecurityValidator.__index = SecurityValidator

-- Security configuration
local SECURITY_CONFIG = {
    MAX_STRING_LENGTH = 1000,
    MAX_ARRAY_SIZE = 100,
    MAX_OBJECT_DEPTH = 10,
    ALLOWED_CHARACTERS = "[%w%s%-%_%.%,%!%?]", -- Alphanumeric, spaces, basic punctuation
    BLOCKED_PATTERNS = {
        "script", "require", "loadstring", "getfenv", "setfenv",
        "debug", "coroutine", "io", "os", "package",
        "<script", "javascript:", "vbscript:", "onload", "onerror",
        "eval(", "setTimeout", "setInterval", "Function(",
        "DROP TABLE", "DELETE FROM", "INSERT INTO", "UPDATE SET",
        "../", "..\\", "/etc/", "C:\\", "cmd.exe", "powershell"
    },
    RATE_LIMITS = {
        VALIDATION_REQUESTS = {max = 100, window = 60}, -- 100 validations per minute
        FAILED_VALIDATIONS = {max = 10, window = 60}     -- 10 failures per minute
    }
}

-- Rate limiting tracking
local rateLimitTracking = {}

function SecurityValidator.new()
    local self = setmetatable({}, SecurityValidator)
    
    -- Validation statistics
    self.stats = {
        totalValidations = 0,
        successfulValidations = 0,
        failedValidations = 0,
        blockedAttempts = 0,
        suspiciousPatterns = {}
    }
    
    -- Initialize rate limiting cleanup
    self:StartRateLimitCleanup()
    
    return self
end

-- Core validation functions
function SecurityValidator:ValidateItemData(itemData, player)
    local startTime = tick()
    self.stats.totalValidations = self.stats.totalValidations + 1
    
    -- Rate limiting check
    if not self:CheckRateLimit(player, "VALIDATION_REQUESTS") then
        self:RecordSuspiciousActivity(player, "RATE_LIMIT_EXCEEDED", "Too many validation requests")
        return {
            success = false,
            error = "Rate limit exceeded",
            errorCode = "RATE_LIMIT"
        }
    end
    
    -- Basic structure validation
    local structureResult = self:ValidateStructure(itemData, "ItemData")
    if not structureResult.success then
        self:RecordFailedValidation(player, "STRUCTURE", structureResult.error)
        return structureResult
    end
    
    -- Required fields validation
    local requiredFields = {"ItemId", "Name"}
    for _, field in ipairs(requiredFields) do
        if not itemData[field] then
            self:RecordFailedValidation(player, "MISSING_FIELD", "Missing required field: " .. field)
            return {
                success = false,
                error = "Missing required field: " .. field,
                errorCode = "MISSING_FIELD"
            }
        end
    end
    
    -- ItemId validation
    local itemIdResult = self:ValidateItemId(itemData.ItemId)
    if not itemIdResult.success then
        self:RecordFailedValidation(player, "INVALID_ITEM_ID", itemIdResult.error)
        return itemIdResult
    end
    
    -- Name validation
    local nameResult = self:ValidateString(itemData.Name, "ItemName", {maxLength = 100})
    if not nameResult.success then
        self:RecordFailedValidation(player, "INVALID_NAME", nameResult.error)
        return nameResult
    end
    
    -- Optional fields validation
    if itemData.Description then
        local descResult = self:ValidateString(itemData.Description, "Description", {maxLength = 500})
        if not descResult.success then
            self:RecordFailedValidation(player, "INVALID_DESCRIPTION", descResult.error)
            return descResult
        end
    end
    
    if itemData.Properties then
        local propsResult = self:ValidateProperties(itemData.Properties)
        if not propsResult.success then
            self:RecordFailedValidation(player, "INVALID_PROPERTIES", propsResult.error)
            return propsResult
        end
    end
    
    -- Sanitize the data
    local sanitizedData = self:SanitizeItemData(itemData)
    
    self.stats.successfulValidations = self.stats.successfulValidations + 1
    
    return {
        success = true,
        data = sanitizedData,
        validationTime = tick() - startTime
    }
end

function SecurityValidator:ValidatePosition(position, player)
    local startTime = tick()
    
    -- Rate limiting check
    if not self:CheckRateLimit(player, "VALIDATION_REQUESTS") then
        return {
            success = false,
            error = "Rate limit exceeded",
            errorCode = "RATE_LIMIT"
        }
    end
    
    -- Type validation
    if typeof(position) ~= "Vector3" then
        self:RecordFailedValidation(player, "INVALID_TYPE", "Position must be Vector3")
        return {
            success = false,
            error = "Position must be Vector3",
            errorCode = "INVALID_TYPE"
        }
    end
    
    -- NaN and infinity checks
    if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
        self:RecordFailedValidation(player, "NAN_VALUES", "Position contains NaN values")
        return {
            success = false,
            error = "Position contains invalid values",
            errorCode = "INVALID_VALUES"
        }
    end
    
    if math.abs(position.X) == math.huge or math.abs(position.Y) == math.huge or math.abs(position.Z) == math.huge then
        self:RecordFailedValidation(player, "INFINITE_VALUES", "Position contains infinite values")
        return {
            success = false,
            error = "Position contains invalid values",
            errorCode = "INVALID_VALUES"
        }
    end
    
    -- World bounds validation
    local bounds = {
        minX = -10000, maxX = 10000,
        minY = -1000, maxY = 10000,
        minZ = -10000, maxZ = 10000
    }
    
    if position.X < bounds.minX or position.X > bounds.maxX or
       position.Y < bounds.minY or position.Y > bounds.maxY or
       position.Z < bounds.minZ or position.Z > bounds.maxZ then
        self:RecordFailedValidation(player, "OUT_OF_BOUNDS", "Position outside world bounds")
        return {
            success = false,
            error = "Position outside allowed bounds",
            errorCode = "OUT_OF_BOUNDS"
        }
    end
    
    -- Player proximity validation (prevent teleportation exploits)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local playerPos = player.Character.HumanoidRootPart.Position
        local distance = (position - playerPos).Magnitude
        
        if distance > 500 then -- Max 500 studs from player
            self:RecordSuspiciousActivity(player, "TELEPORTATION_ATTEMPT", "Position too far from player: " .. distance)
            return {
                success = false,
                error = "Position too far from player",
                errorCode = "TELEPORTATION_ATTEMPT"
            }
        end
    end
    
    return {
        success = true,
        data = position,
        validationTime = tick() - startTime
    }
end

function SecurityValidator:ValidateCurrency(amount, currencyType, player)
    -- Rate limiting check
    if not self:CheckRateLimit(player, "VALIDATION_REQUESTS") then
        return {
            success = false,
            error = "Rate limit exceeded",
            errorCode = "RATE_LIMIT"
        }
    end
    
    -- Type validation
    if typeof(amount) ~= "number" then
        self:RecordFailedValidation(player, "INVALID_TYPE", "Currency amount must be number")
        return {
            success = false,
            error = "Currency amount must be a number",
            errorCode = "INVALID_TYPE"
        }
    end
    
    -- Range validation
    if amount < 0 then
        self:RecordFailedValidation(player, "NEGATIVE_CURRENCY", "Currency amount cannot be negative")
        return {
            success = false,
            error = "Currency amount cannot be negative",
            errorCode = "NEGATIVE_CURRENCY"
        }
    end
    
    if amount > 999999999 then -- 1 billion max
        self:RecordSuspiciousActivity(player, "EXCESSIVE_CURRENCY", "Currency amount too large: " .. amount)
        return {
            success = false,
            error = "Currency amount too large",
            errorCode = "EXCESSIVE_CURRENCY"
        }
    end
    
    -- Currency type validation
    local validCurrencyTypes = {"INGAME", "ROBUX", "COINS", "GEMS"}
    if currencyType and not table.find(validCurrencyTypes, currencyType) then
        self:RecordFailedValidation(player, "INVALID_CURRENCY_TYPE", "Invalid currency type: " .. tostring(currencyType))
        return {
            success = false,
            error = "Invalid currency type",
            errorCode = "INVALID_CURRENCY_TYPE"
        }
    end
    
    return {
        success = true,
        data = {
            amount = math.floor(amount), -- Ensure integer
            currencyType = currencyType or "INGAME"
        }
    }
end

-- Helper validation functions
function SecurityValidator:ValidateStructure(data, dataType)
    if typeof(data) ~= "table" then
        return {
            success = false,
            error = dataType .. " must be a table",
            errorCode = "INVALID_TYPE"
        }
    end
    
    -- Check object depth to prevent stack overflow
    local depth = self:GetTableDepth(data)
    if depth > SECURITY_CONFIG.MAX_OBJECT_DEPTH then
        return {
            success = false,
            error = "Object structure too deep",
            errorCode = "EXCESSIVE_DEPTH"
        }
    end
    
    -- Check table size
    local size = 0
    for _ in pairs(data) do
        size = size + 1
        if size > SECURITY_CONFIG.MAX_ARRAY_SIZE then
            return {
                success = false,
                error = "Object too large",
                errorCode = "EXCESSIVE_SIZE"
            }
        end
    end
    
    return {success = true}
end

function SecurityValidator:ValidateString(str, fieldName, options)
    options = options or {}
    local maxLength = options.maxLength or SECURITY_CONFIG.MAX_STRING_LENGTH
    
    if typeof(str) ~= "string" then
        return {
            success = false,
            error = fieldName .. " must be a string",
            errorCode = "INVALID_TYPE"
        }
    end
    
    if #str == 0 then
        return {
            success = false,
            error = fieldName .. " cannot be empty",
            errorCode = "EMPTY_STRING"
        }
    end
    
    if #str > maxLength then
        return {
            success = false,
            error = fieldName .. " too long (max " .. maxLength .. " characters)",
            errorCode = "STRING_TOO_LONG"
        }
    end
    
    -- Check for blocked patterns
    local lowerStr = string.lower(str)
    for _, pattern in ipairs(SECURITY_CONFIG.BLOCKED_PATTERNS) do
        if string.find(lowerStr, string.lower(pattern), 1, true) then
            return {
                success = false,
                error = fieldName .. " contains blocked content",
                errorCode = "BLOCKED_CONTENT"
            }
        end
    end
    
    -- Character validation (allow only safe characters)
    if not options.allowUnsafeChars and not string.match(str, "^" .. SECURITY_CONFIG.ALLOWED_CHARACTERS .. "*$") then
        return {
            success = false,
            error = fieldName .. " contains invalid characters",
            errorCode = "INVALID_CHARACTERS"
        }
    end
    
    return {success = true}
end

function SecurityValidator:ValidateItemId(itemId)
    if typeof(itemId) ~= "number" then
        return {
            success = false,
            error = "ItemId must be a number",
            errorCode = "INVALID_TYPE"
        }
    end
    
    if itemId <= 0 or itemId > 999999 then
        return {
            success = false,
            error = "ItemId out of valid range",
            errorCode = "INVALID_RANGE"
        }
    end
    
    if itemId ~= math.floor(itemId) then
        return {
            success = false,
            error = "ItemId must be an integer",
            errorCode = "NOT_INTEGER"
        }
    end
    
    return {success = true}
end

function SecurityValidator:ValidateProperties(properties)
    if typeof(properties) ~= "table" then
        return {
            success = false,
            error = "Properties must be a table",
            errorCode = "INVALID_TYPE"
        }
    end
    
    -- Validate each property
    for key, value in pairs(properties) do
        -- Key validation
        local keyResult = self:ValidateString(key, "Property key", {maxLength = 50})
        if not keyResult.success then
            return keyResult
        end
        
        -- Value validation (basic types only)
        local valueType = typeof(value)
        if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
            return {
                success = false,
                error = "Property values must be string, number, or boolean",
                errorCode = "INVALID_PROPERTY_TYPE"
            }
        end
        
        if valueType == "string" then
            local valueResult = self:ValidateString(value, "Property value", {maxLength = 200})
            if not valueResult.success then
                return valueResult
            end
        end
    end
    
    return {success = true}
end

-- Data sanitization
function SecurityValidator:SanitizeItemData(itemData)
    local sanitized = {}
    
    -- Sanitize basic fields
    sanitized.ItemId = math.floor(itemData.ItemId)
    sanitized.Name = self:SanitizeString(itemData.Name)
    
    if itemData.Description then
        sanitized.Description = self:SanitizeString(itemData.Description)
    end
    
    if itemData.Properties then
        sanitized.Properties = self:SanitizeProperties(itemData.Properties)
    end
    
    -- Copy other safe fields
    local safeFields = {"Tier", "Category", "Rarity", "Level"}
    for _, field in ipairs(safeFields) do
        if itemData[field] then
            sanitized[field] = itemData[field]
        end
    end
    
    return sanitized
end

function SecurityValidator:SanitizeString(str)
    -- Remove potentially dangerous characters
    local sanitized = string.gsub(str, "[<>\"'&]", "")
    
    -- Trim whitespace
    sanitized = string.match(sanitized, "^%s*(.-)%s*$")
    
    return sanitized
end

function SecurityValidator:SanitizeProperties(properties)
    local sanitized = {}
    
    for key, value in pairs(properties) do
        local sanitizedKey = self:SanitizeString(key)
        
        if typeof(value) == "string" then
            sanitized[sanitizedKey] = self:SanitizeString(value)
        else
            sanitized[sanitizedKey] = value
        end
    end
    
    return sanitized
end

-- Rate limiting
function SecurityValidator:CheckRateLimit(player, limitType)
    if not player then return true end
    
    local userId = player.UserId
    local currentTime = os.time()
    local limit = SECURITY_CONFIG.RATE_LIMITS[limitType]
    
    if not limit then return true end
    
    -- Initialize tracking for player
    if not rateLimitTracking[userId] then
        rateLimitTracking[userId] = {}
    end
    
    if not rateLimitTracking[userId][limitType] then
        rateLimitTracking[userId][limitType] = {}
    end
    
    local requests = rateLimitTracking[userId][limitType]
    
    -- Clean old requests
    for i = #requests, 1, -1 do
        if currentTime - requests[i] > limit.window then
            table.remove(requests, i)
        end
    end
    
    -- Check limit
    if #requests >= limit.max then
        return false
    end
    
    -- Record request
    table.insert(requests, currentTime)
    return true
end

function SecurityValidator:StartRateLimitCleanup()
    spawn(function()
        while true do
            wait(300) -- Clean every 5 minutes
            self:CleanupRateLimitTracking()
        end
    end)
end

function SecurityValidator:CleanupRateLimitTracking()
    local currentTime = os.time()
    local cleaned = 0
    
    for userId, userTracking in pairs(rateLimitTracking) do
        for limitType, requests in pairs(userTracking) do
            local limit = SECURITY_CONFIG.RATE_LIMITS[limitType]
            if limit then
                for i = #requests, 1, -1 do
                    if currentTime - requests[i] > limit.window then
                        table.remove(requests, i)
                        cleaned = cleaned + 1
                    end
                end
            end
        end
        
        -- Remove empty tracking
        local hasData = false
        for _, requests in pairs(userTracking) do
            if #requests > 0 then
                hasData = true
                break
            end
        end
        
        if not hasData then
            rateLimitTracking[userId] = nil
        end
    end
    
    if cleaned > 0 then
        print("SecurityValidator: Cleaned", cleaned, "old rate limit entries")
    end
end

-- Security monitoring
function SecurityValidator:RecordFailedValidation(player, violationType, details)
    self.stats.failedValidations = self.stats.failedValidations + 1
    
    if player then
        -- Check for repeated failures (potential attack)
        if not self:CheckRateLimit(player, "FAILED_VALIDATIONS") then
            self:RecordSuspiciousActivity(player, "REPEATED_FAILURES", "Too many validation failures")
        end
        
        warn("SecurityValidator: Validation failed for", player.Name, "Type:", violationType, "Details:", details)
    end
end

function SecurityValidator:RecordSuspiciousActivity(player, activityType, details)
    self.stats.blockedAttempts = self.stats.blockedAttempts + 1
    
    local activity = {
        timestamp = os.time(),
        player = player and player.Name or "Unknown",
        userId = player and player.UserId or 0,
        activityType = activityType,
        details = details
    }
    
    table.insert(self.stats.suspiciousPatterns, activity)
    
    -- Keep only recent suspicious activities
    if #self.stats.suspiciousPatterns > 100 then
        table.remove(self.stats.suspiciousPatterns, 1)
    end
    
    warn("🚨 SUSPICIOUS ACTIVITY:", activityType, "Player:", activity.player, "Details:", details)
    
    -- Could integrate with external security monitoring here
end

-- Utility functions
function SecurityValidator:GetTableDepth(tbl, depth)
    depth = depth or 0
    local maxDepth = depth
    
    for _, value in pairs(tbl) do
        if typeof(value) == "table" then
            local childDepth = self:GetTableDepth(value, depth + 1)
            maxDepth = math.max(maxDepth, childDepth)
        end
    end
    
    return maxDepth
end

-- Statistics and reporting
function SecurityValidator:GetSecurityStats()
    local successRate = 0
    if self.stats.totalValidations > 0 then
        successRate = (self.stats.successfulValidations / self.stats.totalValidations) * 100
    end
    
    return {
        totalValidations = self.stats.totalValidations,
        successfulValidations = self.stats.successfulValidations,
        failedValidations = self.stats.failedValidations,
        blockedAttempts = self.stats.blockedAttempts,
        successRate = successRate,
        recentSuspiciousActivities = #self.stats.suspiciousPatterns
    }
end

function SecurityValidator:GenerateSecurityReport()
    local stats = self:GetSecurityStats()
    
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        summary = {
            totalValidations = stats.totalValidations,
            successRate = string.format("%.2f%%", stats.successRate),
            blockedAttempts = stats.blockedAttempts,
            suspiciousActivities = stats.recentSuspiciousActivities
        },
        recentThreats = {}
    }
    
    -- Add recent suspicious activities
    local recentCount = math.min(10, #self.stats.suspiciousPatterns)
    for i = #self.stats.suspiciousPatterns - recentCount + 1, #self.stats.suspiciousPatterns do
        if self.stats.suspiciousPatterns[i] then
            table.insert(report.recentThreats, self.stats.suspiciousPatterns[i])
        end
    end
    
    return report
end

return SecurityValidator 