-- SHARED_MODULE_STRUCTURE_FIX.lua
-- This script specifically fixes the structure of the shared module in ReplicatedStorage
-- to allow proper requiring

print("========== SHARED MODULE STRUCTURE FIX ==========")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- First, analyze what's wrong with the current shared module
local sharedFolder = ReplicatedStorage:FindFirstChild("shared")
if not sharedFolder then
    print("ERROR: 'shared' folder not found in ReplicatedStorage")
    print("Creating new shared structure...")
    
    -- Create the shared folder
    sharedFolder = Instance.new("Folder")
    sharedFolder.Name = "shared"
    sharedFolder.Parent = ReplicatedStorage
    print("Created shared folder")
else
    print("Found shared folder at: " .. sharedFolder:GetFullName())
    
    -- Check if it's a Folder (should be) or a ModuleScript (should not be)
    if sharedFolder:IsA("ModuleScript") then
        print("ERROR: 'shared' is already a ModuleScript but still fails to load")
        print("Backing up and recreating...")
        sharedFolder.Name = "shared_backup_" .. os.time()
        print("Renamed problematic shared ModuleScript to " .. sharedFolder.Name)
        
        -- Create new shared folder
        sharedFolder = Instance.new("Folder")
        sharedFolder.Name = "shared"
        sharedFolder.Parent = ReplicatedStorage
    end
end

-- Now create the init.luau module script inside the shared folder
local initModule = sharedFolder:FindFirstChild("init")
if initModule then
    print("Found existing init module, checking if it's properly configured...")
    
    if not initModule:IsA("ModuleScript") then
        print("ERROR: init is not a ModuleScript (it's a " .. initModule.ClassName .. ")")
        initModule.Name = "init_backup_" .. os.time()
        print("Renamed to " .. initModule.Name)
        
        -- Create new init ModuleScript
        initModule = nil
    else
        -- Check if we can require it
        local success, result = pcall(function()
            return require(initModule)
        end)
        
        if not success then
            print("ERROR: init ModuleScript fails to load: " .. tostring(result))
            initModule.Name = "init_broken_" .. os.time()
            print("Renamed to " .. initModule.Name)
            initModule = nil
        else
            print("Existing init ModuleScript loads successfully! No changes needed.")
        end
    end
end

-- Create a new init ModuleScript if needed
if not initModule then
    print("Creating new init ModuleScript...")
    
    local newInit = Instance.new("ModuleScript")
    newInit.Name = "init"
    newInit.Source = [[
-- init.luau (fixed)
-- This module is loaded when someone does require(ReplicatedStorage.shared)

local SharedModule = {}

-- References to core modules
SharedModule.Constants = nil
SharedModule.GameManager = nil
SharedModule.LazyLoadModules = nil
SharedModule.PurchaseDialog = nil
SharedModule.InventoryUI = nil
SharedModule.PlacedItemDialog = nil
SharedModule.CurrencyUI = nil
SharedModule.InteractionManager = nil

-- Initialize function that loads required modules
function SharedModule.Init()
    print("SharedModule.Init called - initializing core modules")
    
    -- Load Constants
    local constantsModule = script.Parent.core and script.Parent.core:FindFirstChild("Constants")
    if constantsModule then
        local success, result = pcall(function()
            return require(constantsModule)
        end)
        
        if success then
            SharedModule.Constants = result
            print("Loaded Constants module")
        else
            warn("Failed to load Constants:", result)
            -- Create fallback Constants
            SharedModule.Constants = {
                CURRENCY_TYPES = {"Coins", "Gems"},
                DEFAULT_CURRENCY = "Coins",
                INTERACTION_DISTANCE = 10,
                PLACEMENT_GRID_SIZE = 1
            }
            print("Created Constants fallback")
        end
    else
        warn("Constants module not found")
        -- Create fallback Constants
        SharedModule.Constants = {
            CURRENCY_TYPES = {"Coins", "Gems"},
            DEFAULT_CURRENCY = "Coins",
            INTERACTION_DISTANCE = 10,
            PLACEMENT_GRID_SIZE = 1
        }
        print("Created Constants fallback")
    end
    
    -- Load other core modules when needed
    
    return true
end

-- Return the module
return SharedModule
]]
    newInit.Parent = sharedFolder
    print("Created new init ModuleScript")
end

-- Make sure there's a core folder
local coreFolder = sharedFolder:FindFirstChild("core")
if not coreFolder then
    print("Core folder missing, creating...")
    coreFolder = Instance.new("Folder")
    coreFolder.Name = "core"
    coreFolder.Parent = sharedFolder
    
    -- Create minimal Constants
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
    print("Created minimal Constants module")
    
    -- Create minimal LazyLoadModules
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
    print("Created minimal LazyLoadModules module")
else
    print("Core folder exists at " .. coreFolder:GetFullName())
end

-- Test the fix
print("\nTesting if shared module can now be required...")
local success, result = pcall(function()
    return require(ReplicatedStorage.shared)
end)

if success then
    print("SUCCESS! Shared module can now be required properly")
    
    -- Try initialization
    if typeof(result.Init) == "function" then
        local initSuccess, initResult = pcall(result.Init)
        if initSuccess then
            print("Shared module initialization successful")
        else
            print("Shared module initialization failed:", initResult)
        end
    else
        print("WARNING: Shared module has no Init function")
    end
else
    print("ERROR: Shared module still cannot be required:", result)
    print("This may require manual investigation of the module structure")
end

print("\n===== ADDITIONAL STEPS TO TRY IF ISSUES PERSIST =====")
print("1. Check if inits.luau is properly set up in studio")
print("2. Make sure your Rojo project correctly maps the shared folder")
print("3. In Rojo, ensure that 'shared' is mapped as a Folder, not a ModuleScript")
print("4. Run the EXECUTE_ALL_FIXES.lua script for a more comprehensive fix")

print("\n========== SHARED MODULE STRUCTURE FIX COMPLETE ==========")
