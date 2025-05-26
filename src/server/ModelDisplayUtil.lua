-- ModelDisplayUtil.lua
-- A utility script to display and track models in the workspace

local ModelDisplayUtil = {}

-- Configuration
local ENABLE_DETAILED_LOGGING = false -- Set to true for debug mode
local MAX_ITEMS_TO_LOG = 50 -- Limit how many items to log in detail
local LOG_ONLY_IMPORTANT = true -- Only log items with special attributes

-- Constants
local CHECK_INTERVAL = 10 -- How often to check for missing models (in seconds)
local STATIC_MODELS_MAP = {} -- Maps model names to their original instances
local TRACKED_MODELS = {} -- Keeps track of all models being monitored
local RESTORE_COUNT = 0 -- Counter for how many models have been restored

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Function to recursively display all models in a folder
function ModelDisplayUtil:DisplayModels(startFolder, indent)
    indent = indent or 0
    startFolder = startFolder or workspace
    
    local indentStr = string.rep("  ", indent)
    
    if ENABLE_DETAILED_LOGGING then
        print(indentStr .. "📁 " .. startFolder.Name .. " (" .. startFolder.ClassName .. ")")
    end
    
    -- Track models and their properties
    local models = {}
    local totalItems = 0
    local importantItems = 0
    
    -- Sort children by type and name
    local folders = {}
    local modelItems = {}
    local otherItems = {}
    
    for _, item in pairs(startFolder:GetChildren()) do
        totalItems = totalItems + 1
        if item:IsA("Folder") then
            table.insert(folders, item)
        elseif item:IsA("Model") then
            table.insert(modelItems, item)
        else
            table.insert(otherItems, item)
        end
    end
    
    -- Process folders first
    table.sort(folders, function(a, b) return a.Name < b.Name end)
    for _, folder in ipairs(folders) do
        self:DisplayModels(folder, indent + 1)
    end
    
    -- Process models with smart logging
    table.sort(modelItems, function(a, b) return a.Name < b.Name end)
    local loggedModels = 0
    
    for _, model in ipairs(modelItems) do
        local attributes = ""
        local hasImportantAttributes = false
        
        for name, value in pairs(model:GetAttributes()) do
            attributes = attributes .. "[" .. name .. "=" .. tostring(value) .. "] "
            if name:find("item") or name:find("price") or name:find("secondary") then
                hasImportantAttributes = true
                importantItems = importantItems + 1
            end
        end
        
        local partCount = 0
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BasePart") then
                partCount = partCount + 1
            end
        end
        
        local modelInfo = {
            name = model.Name,
            className = model.ClassName,
            partCount = partCount,
            attributes = attributes,
            position = model:GetPivot().Position
        }
        
        -- Only log if: detailed logging enabled, has important attributes, or under limit
        local shouldLog = ENABLE_DETAILED_LOGGING or 
                         (LOG_ONLY_IMPORTANT and hasImportantAttributes) or 
                         loggedModels < MAX_ITEMS_TO_LOG
        
        if shouldLog then
            print(indentStr .. "  📋 " .. model.Name .. " (" .. partCount .. " parts) " .. attributes)
            loggedModels = loggedModels + 1
        end
        
        table.insert(models, modelInfo)
    end
    
    -- Process other items with smart logging
    table.sort(otherItems, function(a, b) return a.Name < b.Name end)
    local loggedOthers = 0
    local groupedOthers = {}
    
    for _, item in ipairs(otherItems) do
        if item:IsA("BasePart") then
            local className = item.ClassName
            if not groupedOthers[className] then
                groupedOthers[className] = {count = 0, examples = {}}
            end
            groupedOthers[className].count = groupedOthers[className].count + 1
            if #groupedOthers[className].examples < 3 then
                table.insert(groupedOthers[className].examples, item.Name)
            end
        elseif ENABLE_DETAILED_LOGGING and loggedOthers < MAX_ITEMS_TO_LOG then
            print(indentStr .. "  ❓ " .. item.Name .. " (" .. item.ClassName .. ")")
            loggedOthers = loggedOthers + 1
        end
    end
    
    -- Show grouped summary for parts
    for className, info in pairs(groupedOthers) do
        if info.count > 1 then
            local examples = table.concat(info.examples, ", ")
            if #info.examples < info.count then
                examples = examples .. ", ..."
            end
            print(indentStr .. "  ▶ 🧊 " .. className .. " (" .. info.count .. " items): " .. examples)
        elseif info.count == 1 then
            print(indentStr .. "  🧊 " .. info.examples[1] .. " (" .. className .. ")")
        end
    end
    
    -- Summary for this folder
    if not ENABLE_DETAILED_LOGGING and (totalItems > 20 or importantItems > 0) then
        print(indentStr .. "📁 " .. startFolder.Name .. " - Total: " .. totalItems .. " items, Important: " .. importantItems .. " items")
    end
    
    return models
end

-- Function to clone a model and prepare it for tracking
function ModelDisplayUtil:CloneAndTrack(model)
    -- Create a deep clone with all properties
    local modelClone = model:Clone()
    
    -- Store important information for tracking
    local trackingInfo = {
        originalName = model.Name,
        originalParent = model.Parent.Name,
        lastSeen = os.time(),
        position = model:GetPivot().Position,
        clone = modelClone
    }
    
    -- Add to tracked models
    TRACKED_MODELS[model:GetFullName()] = trackingInfo
    
    return modelClone
end

-- Function to capture all static models
function ModelDisplayUtil:CaptureStaticModels()
    local worldItems = workspace:FindFirstChild("World_Items")
    if not worldItems then
        print("ModelDisplayUtil: World_Items folder not found, creating it")
        worldItems = Instance.new("Folder")
        worldItems.Name = "World_Items"
        worldItems.Parent = workspace
    end
    
    local static = worldItems:FindFirstChild("Static")
    if not static then
        print("ModelDisplayUtil: Static folder not found, creating it")
        static = Instance.new("Folder")
        static.Name = "Static"
        static.Parent = worldItems
    end
    
    print("ModelDisplayUtil: Capturing all static models...")
    local modelCount = 0
    
    -- Process all items in the Static folder
    for _, model in pairs(static:GetChildren()) do
        -- Only track models and parts
        if model:IsA("Model") or model:IsA("BasePart") then
            local clone = self:CloneAndTrack(model)
            STATIC_MODELS_MAP[model.Name] = clone
            modelCount = modelCount + 1
            
            -- Set attribute for visibility tracking
            model:SetAttribute("ModelDisplayUtil_Tracked", true)
            model:SetAttribute("ModelDisplayUtil_LastSeen", os.time())
        end
    end
    
    print("ModelDisplayUtil: Captured " .. modelCount .. " static models for tracking")
    return modelCount
end

-- Function to restore missing models
function ModelDisplayUtil:RestoreMissingModels()
    local worldItems = workspace:FindFirstChild("World_Items")
    if not worldItems then return 0 end
    
    local static = worldItems:FindFirstChild("Static")
    if not static then return 0 end
    
    local restoredCount = 0
    
    -- Check each tracked model to see if it's missing
    for fullName, info in pairs(TRACKED_MODELS) do
        local modelName = info.originalName
        
        -- Check if the model exists in the appropriate folder
        local modelExists = false
        for _, child in pairs(static:GetChildren()) do
            if child.Name == modelName then
                -- Update last seen time
                child:SetAttribute("ModelDisplayUtil_LastSeen", os.time())
                info.lastSeen = os.time()
                modelExists = true
                break
            end
        end
        
        -- If model is missing, restore it
        if not modelExists then
            print("ModelDisplayUtil: Restoring missing model: " .. modelName)
            
            -- Clone from our saved reference
            local restoredModel = info.clone:Clone()
            restoredModel.Name = modelName
            
            -- Set visibility tracking attributes
            restoredModel:SetAttribute("ModelDisplayUtil_Tracked", true)
            restoredModel:SetAttribute("ModelDisplayUtil_LastSeen", os.time())
            restoredModel:SetAttribute("ModelDisplayUtil_Restored", true)
            restoredModel:SetAttribute("ModelDisplayUtil_RestoredTime", os.time())
            
            -- Position at the original location
            if restoredModel:IsA("Model") and restoredModel.PrimaryPart then
                restoredModel:SetPrimaryPartCFrame(CFrame.new(info.position))
            elseif restoredModel:IsA("BasePart") then
                restoredModel.Position = info.position
            end
            
            -- Parent to the appropriate folder
            restoredModel.Parent = static
            
            restoredCount = restoredCount + 1
            RESTORE_COUNT = RESTORE_COUNT + 1
        end
    end
    
    if restoredCount > 0 then
        print("ModelDisplayUtil: Restored " .. restoredCount .. " missing models")
    end
    
    return restoredCount
end

-- Monitor World_Items folder to keep items from disappearing
function ModelDisplayUtil:MonitorWorldItems()
    local worldItems = workspace:FindFirstChild("World_Items")
    if not worldItems then
        print("ModelDisplayUtil: World_Items folder not found, creating it")
        worldItems = Instance.new("Folder")
        worldItems.Name = "World_Items"
        worldItems.Parent = workspace
    end
    
    -- Set up subfolders if needed
    local static = worldItems:FindFirstChild("Static")
    if not static then
        print("ModelDisplayUtil: Static folder not found, creating it")
        static = Instance.new("Folder")
        static.Name = "Static"
        static.Parent = worldItems
    end
    
    local placed = worldItems:FindFirstChild("Placed")
    if not placed then
        print("ModelDisplayUtil: Placed folder not found, creating it")
        placed = Instance.new("Folder")
        placed.Name = "Placed"
        placed.Parent = worldItems
    end
    
    -- Capture all static models
    self:CaptureStaticModels()
    
    -- Start the heartbeat to regularly check for missing models
    local lastCheckTime = 0
    
    RunService.Heartbeat:Connect(function()
        local currentTime = os.time()
        
        -- Only check every CHECK_INTERVAL seconds
        if currentTime - lastCheckTime >= CHECK_INTERVAL then
            self:RestoreMissingModels()
            lastCheckTime = currentTime
        end
    end)
    
    print("ModelDisplayUtil: Now monitoring World_Items folder")
    
    -- Display the initial state
    print("\n=== INITIAL WORLD ITEMS STRUCTURE ===")
    self:DisplayModels(worldItems)
    print("=====================================\n")
    
    return STATIC_MODELS_MAP
end

-- Function to toggle logging modes
function ModelDisplayUtil:SetLoggingMode(detailed, maxItems, onlyImportant)
    ENABLE_DETAILED_LOGGING = detailed or false
    MAX_ITEMS_TO_LOG = maxItems or 50
    LOG_ONLY_IMPORTANT = onlyImportant ~= false -- Default to true
    
    print("ModelDisplayUtil: Logging mode updated - Detailed: " .. tostring(ENABLE_DETAILED_LOGGING) .. 
          ", Max items: " .. MAX_ITEMS_TO_LOG .. 
          ", Only important: " .. tostring(LOG_ONLY_IMPORTANT))
end

-- Initialize the utility
function ModelDisplayUtil:Initialize()
    print("ModelDisplayUtil: Initializing...")
    
    -- Create a command to manually display models
    local displayCommand = Instance.new("BindableFunction")
    displayCommand.Name = "DisplayModels"
    displayCommand.Parent = game:GetService("ReplicatedStorage")
    
    displayCommand.OnInvoke = function(target)
        local targetFolder = workspace
        if target and target ~= "" then
            targetFolder = workspace:FindFirstChild(target)
            if not targetFolder then
                print("ModelDisplayUtil: Target folder not found:", target)
                return "Folder not found"
            end
        end
        
        print("\n=== MODEL DISPLAY ===")
        self:DisplayModels(targetFolder)
        print("====================\n")
        
        return "Display complete"
    end
    
    -- Create a command to manually restore models
    local restoreCommand = Instance.new("BindableFunction")
    restoreCommand.Name = "RestoreModels"
    restoreCommand.Parent = game:GetService("ReplicatedStorage")
    
    restoreCommand.OnInvoke = function()
        local count = self:RestoreMissingModels()
        return "Restored " .. count .. " models"
    end
    
    -- Create a command to show restoration stats
    local statsCommand = Instance.new("BindableFunction")
    statsCommand.Name = "ModelDisplayStats"
    statsCommand.Parent = game:GetService("ReplicatedStorage")
    
    statsCommand.OnInvoke = function()
        return "Tracked models: " .. #TRACKED_MODELS .. ", Total restorations: " .. RESTORE_COUNT
    end
    
    -- Create a command to control logging
    local loggingCommand = Instance.new("BindableFunction")
    loggingCommand.Name = "ModelDisplayLogging"
    loggingCommand.Parent = game:GetService("ReplicatedStorage")
    
    loggingCommand.OnInvoke = function(mode)
        if mode == "detailed" then
            self:SetLoggingMode(true, 200, false)
            return "Enabled detailed logging"
        elseif mode == "quiet" then
            self:SetLoggingMode(false, 10, true)
            return "Enabled quiet mode"
        elseif mode == "silent" then
            self:SetLoggingMode(false, 0, true)
            return "Enabled silent mode"
        else
            return "Current mode - Detailed: " .. tostring(ENABLE_DETAILED_LOGGING) .. 
                   ", Max items: " .. MAX_ITEMS_TO_LOG .. 
                   ", Only important: " .. tostring(LOG_ONLY_IMPORTANT)
        end
    end
    
    -- Start monitoring world items
    self:MonitorWorldItems()
    
    print("ModelDisplayUtil: Initialization complete (Performance optimized)")
end

return ModelDisplayUtil 