-- CLIENT_SHARED_MODULE_FIX.lua
-- This script will run in a LocalScript to fix shared module loading issues
-- Place this inside a StarterPlayerScripts folder to ensure it runs on all clients

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("======== CLIENT SHARED MODULE FIX ========")

-- Wait for ReplicatedStorage to be ready
local function waitForReplicatedStorage()
    local startTime = tick()
    local timeout = 10 -- seconds
    
    while not ReplicatedStorage and (tick() - startTime) < timeout do
        wait(0.1)
    end
    
    if not ReplicatedStorage then
        warn("Failed to get ReplicatedStorage service after waiting", timeout, "seconds")
        return false
    end
    
    return true
end

-- Function to create a copy of the shared module structure
local function repairSharedModule()
    -- Wait for shared folder
    local sharedFolder = ReplicatedStorage:WaitForChild("shared", 10)
    if not sharedFolder then
        print("CRITICAL: Shared folder not found in ReplicatedStorage after 10 seconds")
        -- Create it if missing
        sharedFolder = Instance.new("Folder")
        sharedFolder.Name = "shared"
        sharedFolder.Parent = ReplicatedStorage
        print("Created missing 'shared' folder")
    else
        print("Found shared folder at", sharedFolder:GetFullName())
    end
    
    -- Check if we need to create an init module
    local initModule = sharedFolder:FindFirstChild("init")
    if not initModule or not initModule:IsA("ModuleScript") then
        if initModule then
            -- Backup existing but incorrect init
            local backupName = "init_backup_" .. os.time()
            initModule.Name = backupName
            print("Renamed incorrect init to", backupName)
        end
        
        -- Create proper init ModuleScript
        initModule = Instance.new("ModuleScript")
        initModule.Name = "init"
        initModule.Source = [[
-- Client fix for shared module loading
local module = {}

function module.Init()
    print("SharedModule initialized through client fix")
    return true
end

-- Load all submodules
for _, child in ipairs(script.Parent:GetChildren()) do
    if child:IsA("ModuleScript") and child ~= script then
        local success, result = pcall(function()
            return require(child)
        end)
        
        if success then
            module[child.Name] = result
            print("Successfully loaded module:", child.Name)
        else
            warn("Failed to load module:", child.Name, "Error:", result)
            -- Create empty module to prevent errors
            module[child.Name] = {}
        end
    end
end

return module
]]
        initModule.Parent = sharedFolder
        print("Created proper init ModuleScript")
    else
        print("Found init ModuleScript, checking if it works...")
        -- Test if the module loads correctly
        local success, result = pcall(function()
            return require(initModule)
        end)
        
        if success then
            print("Init module loads successfully!")
        else
            print("Init module fails to load, replacing with working version...")
            -- Backup the broken module
            local backupName = "init_backup_" .. os.time()
            initModule.Name = backupName
            
            -- Create new working init module
            local newInit = Instance.new("ModuleScript")
            newInit.Name = "init"
            newInit.Source = [[
-- Client fix for shared module loading (replacement)
local module = {}

function module.Init()
    print("SharedModule initialized through client fix (replacement)")
    return true
end

-- Load all submodules with extra safety
for _, child in ipairs(script.Parent:GetChildren()) do
    if child:IsA("ModuleScript") and child ~= script then
        local success, result = pcall(function()
            return require(child)
        end)
        
        if success and result then
            module[child.Name] = result
            print("Successfully loaded module:", child.Name)
        else
            warn("Failed to load module:", child.Name, "Error:", tostring(result))
            -- Create empty module to prevent errors
            module[child.Name] = {}
        end
    end
end

-- Critical fallback modules
if not module.Constants then
    module.Constants = {
        CURRENCY_TYPES = {"Coins", "Gems"},
        DEFAULT_CURRENCY = "Coins",
        INTERACTION_DISTANCE = 10,
        PLACEMENT_GRID_SIZE = 1
    }
    print("Created Constants fallback")
end

if not module.LazyLoadModules then
    module.LazyLoadModules = {
        _registry = {},
        register = function(name, moduleScript)
            module.LazyLoadModules._registry[name] = moduleScript
            return true
        end,
        require = function(name)
            local moduleScript = module.LazyLoadModules._registry[name]
            if not moduleScript then return nil end
            
            local success, result = pcall(function()
                return require(moduleScript)
            end)
            
            return success and result or nil
        end
    }
    print("Created LazyLoadModules fallback")
end

return module
]]
            newInit.Parent = sharedFolder
            print("Created replacement init module")
        end
    end
    
    -- Check if core folder exists
    local coreFolder = sharedFolder:FindFirstChild("core")
    if not coreFolder then
        print("Core folder missing, creating...")
        coreFolder = Instance.new("Folder")
        coreFolder.Name = "core"
        coreFolder.Parent = sharedFolder
        
        -- Create minimal Constants module as fallback
        local constants = Instance.new("ModuleScript")
        constants.Name = "Constants"
        constants.Source = [[
local Constants = {
    CURRENCY_TYPES = {"Coins", "Gems"},
    DEFAULT_CURRENCY = "Coins",
    INTERACTION_DISTANCE = 10,
    PLACEMENT_GRID_SIZE = 1
}

function Constants.Initialize()
    print("Constants initialized")
    return true
end

return Constants
]]
        constants.Parent = coreFolder
        
        -- Create minimal LazyLoadModules as fallback
        local lazyLoad = Instance.new("ModuleScript")
        lazyLoad.Name = "LazyLoadModules"
        lazyLoad.Source = [[
local LazyLoadModules = {
    _registry = {}
}

function LazyLoadModules.register(name, moduleScript)
    if not name or not moduleScript then
        warn("LazyLoadModules.register: Invalid arguments")
        return false
    end
    
    LazyLoadModules._registry[name] = moduleScript
    return true
end

function LazyLoadModules.require(name)
    if not name then
        warn("LazyLoadModules.require: Name is required")
        return nil
    end
    
    local moduleScript = LazyLoadModules._registry[name]
    if not moduleScript then
        warn("LazyLoadModules.require: Module not registered: " .. name)
        return nil
    end
    
    local success, result = pcall(function()
        return require(moduleScript)
    end)
    
    if success then
        return result
    else
        warn("LazyLoadModules.require: Failed to require module " .. name .. ": " .. tostring(result))
        return nil
    end
end

return LazyLoadModules
]]
        lazyLoad.Parent = coreFolder
        print("Created minimal core modules")
    else
        print("Core folder exists at", coreFolder:GetFullName())
    end
    
    print("Shared module structure repaired successfully")
    return true
end

-- Main code
if waitForReplicatedStorage() then
    print("Starting shared module repair process...")
    local success = repairSharedModule()
    if success then
        print("Shared module structure fixed successfully!")
    else
        warn("Failed to completely fix shared module structure")
    end
else
    warn("Critical error: Could not access ReplicatedStorage")
end

print("======== CLIENT SHARED MODULE FIX COMPLETE ========")
