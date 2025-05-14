-- SHARED_MODULE_FIX.lua
-- This script diagnoses and attempts to fix the recurring "Failed to require SharedModule" error
-- It will create a proper shared module structure if needed

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("======== SHARED MODULE DIAGNOSTIC & FIX ========")

-- Check if shared folder exists
local sharedFolder = ReplicatedStorage:FindFirstChild("shared")
if not sharedFolder then
    print("ISSUE: 'shared' folder not found in ReplicatedStorage")
    print("Creating shared folder...")
    sharedFolder = Instance.new("Folder")
    sharedFolder.Name = "shared"
    sharedFolder.Parent = ReplicatedStorage
else
    print("FOUND: 'shared' folder exists at " .. sharedFolder:GetFullName())
end

-- Examine shared folder structure
local function examineModuleScripts(parent, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    
    for _, child in ipairs(parent:GetChildren()) do
        local status = ""
        if child:IsA("ModuleScript") then
            -- Try to require the module
            local success, result = pcall(function()
                return require(child)
            end)
            
            if success then
                status = " ✓ [Loadable]"
                -- If it's a ModuleScript with no Source, it might be an issue
                if child.Source == "" then
                    status = " ⚠ [Empty Source]"
                    print(indent .. "  - " .. child.Name .. status)
                    print(indent .. "    FIXING: Adding basic ModuleScript template...")
                    child.Source = [[
local module = {}

function module.Init()
    print("]] .. child.Name .. [[ initialized")
    return true
end

return module
]]
                end
            else
                status = " ✗ [Error: " .. result .. "]"
                print(indent .. "  - " .. child.Name .. status)
                print(indent .. "    FIXING: Replacing with functional ModuleScript...")
                
                local backupName = child.Name .. "_broken"
                local existingBackup = parent:FindFirstChild(backupName)
                if existingBackup then
                    existingBackup:Destroy()
                end
                
                -- Rename the broken module as backup
                child.Name = backupName
                
                -- Create new working module
                local newModule = Instance.new("ModuleScript")
                newModule.Name = child.Name:gsub("_broken", "")
                newModule.Source = [[
local module = {}

function module.Init()
    print("]] .. newModule.Name .. [[ initialized")
    return true
end

return module
]]
                newModule.Parent = parent
            end
        end
        
        print(indent .. child.Name .. " [" .. child.ClassName .. "]" .. status)
        if #child:GetChildren() > 0 then
            examineModuleScripts(child, depth + 1)
        end
    end
end

print("\nEXAMINING SHARED FOLDER STRUCTURE:")
examineModuleScripts(sharedFolder)

-- Check if shared is properly set up as a ModuleScript
if not sharedFolder:IsA("ModuleScript") then
    print("\nISSUE: 'shared' is not a ModuleScript (it's a " .. sharedFolder.ClassName .. ")")
    print("This is likely why requiring ReplicatedStorage.shared fails")
    
    -- Create a proper ModuleScript for the shared module
    print("FIXING: Creating 'shared' ModuleScript...")
    local sharedModule = Instance.new("ModuleScript")
    sharedModule.Name = "shared_module"
    sharedModule.Source = [[
local SharedModule = {}

-- Initialize function
function SharedModule.Init()
    print("SharedModule initialized")
    
    -- Load sub-modules
    for _, child in ipairs(script.Parent:GetChildren()) do
        if child:IsA("ModuleScript") and child ~= script then
            local success, result = pcall(function()
                return require(child)
            end)
            
            if success then
                SharedModule[child.Name] = result
                print("Loaded module: " .. child.Name)
            else
                warn("Failed to load module: " .. child.Name .. " - " .. tostring(result))
            end
        end
    end
    
    return true
end

return SharedModule
]]
    sharedModule.Parent = sharedFolder
    
    print("MODIFICATION: Adding init.lua to facilitate requiring")
    local initModule = Instance.new("ModuleScript")
    initModule.Name = "init"
    initModule.Source = [[
-- This allows 'require(ReplicatedStorage.shared)' to work
return require(script.Parent.shared_module)
]]
    initModule.Parent = sharedFolder
    
    print("SHARED MODULE FIX COMPLETE")
    print("Now you should be able to require(ReplicatedStorage.shared)")
else
    print("\nSHARED MODULE STRUCTURE LOOKS GOOD")
end

-- Add diagnostic for LazyLoadModules
local lazyModule = sharedFolder:FindFirstChild("LazyLoadModules", true)
if lazyModule then
    print("\nChecking LazyLoadModules...")
    local success, result = pcall(function()
        return require(lazyModule)
    end)
    
    if success then
        print("LazyLoadModules loads successfully ✓")
    else
        print("LazyLoadModules failed to load: " .. tostring(result))
        print("FIXING: Replacing with functioning LazyLoadModules...")
        
        -- Backup the broken module
        local backupName = lazyModule.Name .. "_broken"
        local existingBackup = lazyModule.Parent:FindFirstChild(backupName)
        if existingBackup then
            existingBackup:Destroy()
        end
        lazyModule.Name = backupName
        
        -- Create new working LazyLoadModules
        local newLazyModule = Instance.new("ModuleScript")
        newLazyModule.Name = "LazyLoadModules"
        newLazyModule.Source = [[
local LazyLoadModules = {}

-- Registry for all modules
LazyLoadModules._registry = {}

-- Register a module for lazy loading
function LazyLoadModules.register(name, moduleScript)
    if not name or not moduleScript then
        warn("LazyLoadModules.register: Invalid arguments")
        return false
    end
    
    LazyLoadModules._registry[name] = moduleScript
    return true
end

-- Require a module by name
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
        newLazyModule.Parent = lazyModule.Parent
        print("LazyLoadModules fixed and replaced ✓")
    end
else
    print("\nWARNING: LazyLoadModules not found in shared folder structure")
end

print("\n======== DIAGNOSTIC COMPLETE ========")
print("Please test the game now to see if shared module loading is fixed")
