-- EXECUTE_ALL_FIXES.lua
-- This script will orchestrate all fixes in the correct order
-- Run this in the command bar in Roblox Studio

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer") 
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("========== EXECUTING ALL FIXES ==========")

-- Create required folders if they don't exist
if not ReplicatedStorage:FindFirstChild("Remotes") then
    local remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
    print("Created missing Remotes folder")
end

-- Create critical remote objects in the Remotes folder
local function createRemote(name, remoteType)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes:FindFirstChild(name) then
        local remote
        if remoteType == "RemoteFunction" then
            remote = Instance.new("RemoteFunction")
        else
            remote = Instance.new("RemoteEvent")
        end
        remote.Name = name
        remote.Parent = remotes
        print("Created " .. remoteType .. ": " .. name)
    end
end

-- Create critical remotes
print("Creating critical remotes...")
local remotesToCreate = {
    {name = "GetAvailableInteractions", type = "RemoteFunction"},
    {name = "CloneItem", type = "RemoteEvent"},
    {name = "PickupItem", type = "RemoteEvent"},
    {name = "AddToInventory", type = "RemoteEvent"},
    {name = "GetItemData", type = "RemoteFunction"},
    {name = "ApplyItemEffect", type = "RemoteEvent"},
    {name = "BuyItem", type = "RemoteEvent"},
    {name = "GetInventory", type = "RemoteFunction"},
    {name = "PlaceItem", type = "RemoteEvent"},
    {name = "InteractWithItem", type = "RemoteEvent"},
    {name = "NotifyPlayer", type = "RemoteEvent"}
}

for _, remoteInfo in ipairs(remotesToCreate) do
    createRemote(remoteInfo.name, remoteInfo.type)
end

-- Fix shared module
local function runSharedModuleFix()
    print("\nFixing shared module structure...")
    
    -- Get or create shared folder
    local shared = ReplicatedStorage:FindFirstChild("shared")
    if not shared then
        shared = Instance.new("Folder")
        shared.Name = "shared"
        shared.Parent = ReplicatedStorage
        print("Created shared folder")
    end
    
    -- Create init module if it doesn't exist
    local initModule = shared:FindFirstChild("init")
    if not initModule or not initModule:IsA("ModuleScript") then
        if initModule then
            initModule.Name = "init_old"
        end
        
        local newInit = Instance.new("ModuleScript")
        newInit.Name = "init"
        newInit.Source = [[
-- Fixed shared module initialization
local SharedModule = {}

-- References to all core modules
SharedModule.Constants = nil
SharedModule.GameManager = nil
SharedModule.LazyLoadModules = nil
SharedModule.PurchaseDialog = nil
SharedModule.InventoryUI = nil
SharedModule.PlacedItemDialog = nil
SharedModule.CurrencyUI = nil
SharedModule.InteractionManager = nil

-- Cache for loaded modules to prevent duplicate loading
local moduleCache = {}

-- Helper function to safely load modules
local function safeRequire(path, moduleName)
    if moduleCache[moduleName] then
        return moduleCache[moduleName]
    end
    
    if not path then
        warn("Invalid path for module:", moduleName)
        return nil
    end
    
    local success, result = pcall(function()
        return require(path)
    end)
    
    if not success then
        warn("Failed to load module:", moduleName, "-", tostring(result))
        return nil
    end
    
    moduleCache[moduleName] = result
    return result
end

-- Load core modules
local function loadCoreModules()
    local coreFolder = script.Parent:FindFirstChild("core")
    if not coreFolder then
        warn("Core folder not found")
        return false
    end
    
    -- Load Constants
    local constants = coreFolder:FindFirstChild("Constants")
    if constants then
        SharedModule.Constants = safeRequire(constants, "Constants")
    end
    
    -- Load LazyLoadModules
    local lazyLoad = coreFolder:FindFirstChild("LazyLoadModules")
    if lazyLoad then
        SharedModule.LazyLoadModules = safeRequire(lazyLoad, "LazyLoadModules")
    end
    
    -- Load other core modules
    local moduleNames = {
        GameManager = "GameManager",
        
        -- UI modules
        CurrencyUI = "ui/CurrencyUI",
        InventoryUI = "ui/InventoryUI",
        PlacedItemDialog = "ui/PlacedItemDialog",
        PurchaseDialog = "ui/PurchaseDialog",
        
        -- Other modules
        InteractionManager = "interaction/InteractionManager"
    }
    
    for key, path in pairs(moduleNames) do
        local pathParts = string.split(path, "/")
        local currentFolder = coreFolder
        
        -- Navigate through path parts
        for i = 1, #pathParts - 1 do
            currentFolder = currentFolder:FindFirstChild(pathParts[i])
            if not currentFolder then
                break
            end
        end
        
        if currentFolder then
            local module = currentFolder:FindFirstChild(pathParts[#pathParts])
            if module then
                SharedModule[key] = safeRequire(module, key)
            end
        end
    end
    
    return true
end

-- Initialize function
function SharedModule.Init()
    print("Initializing fixed SharedModule...")
    
    -- Load all core modules
    loadCoreModules()
    
    -- Initialize LazyLoadModules if missing
    if not SharedModule.LazyLoadModules then
        SharedModule.LazyLoadModules = {
            _registry = {},
            register = function(name, moduleScript)
                SharedModule.LazyLoadModules._registry[name] = moduleScript
                return true
            end,
            require = function(name)
                local moduleScript = SharedModule.LazyLoadModules._registry[name]
                if not moduleScript then return nil end
                
                return safeRequire(moduleScript, name)
            end
        }
        print("Created LazyLoadModules fallback")
    end
    
    -- Register modules for lazy loading
    local coreFolder = script.Parent:FindFirstChild("core")
    if coreFolder then
        for _, child in ipairs(coreFolder:GetChildren()) do
            if child:IsA("ModuleScript") then
                SharedModule.LazyLoadModules.register(child.Name, child)
            end
        end
    end
    
    return true
end

return SharedModule
]]
        newInit.Parent = shared
        print("Created fixed init module")
    end
    
    -- Make sure core folder exists
    local coreFolder = shared:FindFirstChild("core")
    if not coreFolder then
        coreFolder = Instance.new("Folder")
        coreFolder.Name = "core"
        coreFolder.Parent = shared
        print("Created core folder")
    end
    
    -- Ensure LazyLoadModules exists
    local lazyLoad = coreFolder:FindFirstChild("LazyLoadModules")
    if not lazyLoad then
        lazyLoad = Instance.new("ModuleScript")
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
    print("Registered module: " .. name)
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
        print("Created LazyLoadModules")
    end
    
    -- Ensure Constants exists
    local constants = coreFolder:FindFirstChild("Constants")
    if not constants then
        constants = Instance.new("ModuleScript")
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
        print("Created Constants")
    end
    
    -- Make sure UI folder exists
    local uiFolder = coreFolder:FindFirstChild("ui")
    if not uiFolder then
        uiFolder = Instance.new("Folder")
        uiFolder.Name = "ui"
        uiFolder.Parent = coreFolder
        print("Created UI folder")
    end
    
    print("Shared module structure fixed")
end

-- Run the fixes
runSharedModuleFix()

-- Run diagnostic to verify fixes
print("\nRunning diagnostic to verify fixes...")
local success, result = pcall(function()
    return require(ReplicatedStorage.shared)
end)

if success then
    print("✓ Shared module can be required successfully!")
    
    -- Try initialization
    local initSuccess, initResult = pcall(function()
        return result.Init()
    end)
    
    if initSuccess then
        print("✓ Shared module initialized successfully!")
    else
        warn("✗ Shared module initialization failed:", initResult)
    end
else
    warn("✗ Failed to require shared module:", result)
end

-- List fixed components
print("\nFix Summary:")
print("✓ Created missing remotes")
print("✓ Fixed shared module structure")
print("✓ Added critical modules with fallbacks")

print("\nNext Steps:")
print("1. Run the game to test if the interaction system works")
print("2. If issues persist, run COMPREHENSIVE_DIAGNOSTIC.lua")
print("3. Check client_core.luau for errors")

print("========== FIX EXECUTION COMPLETE ==========")
