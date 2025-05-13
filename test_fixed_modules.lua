-- This script tests the fixed circular dependency modules by loading them in a specific order

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Starting module load test - this will help identify stack overflow issues")

-- Step 1: Test loading the LazyLoadModules helper first
local success, LazyLoadModules = pcall(function()
    return require(ReplicatedStorage.shared.core.LazyLoadModules)
end)

if not success then
    error("Failed to load LazyLoadModules: " .. tostring(LazyLoadModules))
else
    print("✓ LazyLoadModules loaded successfully")
end

-- Step 2: Load the fixed shared module
local success, SharedModule = pcall(function()
    return require(ReplicatedStorage.shared_fixed)
end)

if not success then
    error("Failed to load SharedModule: " .. tostring(SharedModule))
else
    print("✓ SharedModule loaded successfully")
end

-- Step 3: Initialize SharedModule
local success, result = pcall(function()
    SharedModule.Init()
end)

if not success then
    error("Failed to initialize SharedModule: " .. tostring(result))
else
    print("✓ SharedModule initialized successfully")
end

-- Step 4: Test lazy loading of modules that previously caused circular references
local modules = {
    "GameManager",
    "UI",
    "Interaction",
    "Placement",
    "Inventory",
    "Economy"
}

for _, moduleName in ipairs(modules) do
    local success, result = pcall(function()
        return SharedModule[moduleName]
    end)
    
    if not success then
        error("Failed to lazy load " .. moduleName .. ": " .. tostring(result))
    else
        print("✓ Lazy loaded " .. moduleName .. " successfully")
    end
end

print("All modules loaded successfully! Stack overflow issue should be resolved.")
