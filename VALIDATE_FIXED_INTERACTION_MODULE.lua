-- VALIDATE_FIXED_INTERACTION_MODULE.lua
-- This script validates that the fixed InteractionSystemModule loads correctly
-- May 14, 2025

local RunService = game:GetService("RunService")

-- Check if we're in Studio
if not RunService:IsStudio() then
    error("This script should only be run in Roblox Studio.")
    return
end

print("========== INTERACTION SYSTEM VALIDATION ==========")
print("Starting validation of the fixed InteractionSystemModule...")

local function validateSyntax()
    print("\n[1/3] Checking for syntax errors in the module file...")
    
    local success, moduleOrError = pcall(function()
        -- Try to load the module
        local module = require(game.ReplicatedStorage.src.client.interaction.InteractionSystemModule)
        return module
    end)
    
    if success then
        print("✓ Module loaded successfully with no syntax errors!")
        return moduleOrError
    else
        warn("✗ Syntax error in module: " .. moduleOrError)
        return nil
    end
end

local function validateInitialization(module)
    print("\n[2/3] Testing module instantiation...")
    
    if not module then
        warn("✗ Cannot test initialization - module failed to load")
        return nil
    end
    
    local success, instanceOrError = pcall(function()
        -- Try to create a new instance of the module
        local instance = module.new()
        return instance
    end)
    
    if success then
        print("✓ Module instantiated successfully!")
        return instanceOrError
    else
        warn("✗ Error instantiating module: " .. instanceOrError)
        return nil
    end
end

local function validateMethods(instance)
    print("\n[3/3] Testing key module methods...")
    
    if not instance then
        warn("✗ Cannot test methods - instance failed to create")
        return false
    end
    
    local methods = {
        "Initialize",
        "CreateUI",
        "SetupInputHandling",
        "UpdateCurrentTarget",
        "ShowInteractionUI",
        "HideInteractionUI",
        "AttemptInteraction"
    }
    
    local allPassed = true
    
    for _, methodName in ipairs(methods) do
        local method = instance[methodName]
        
        if typeof(method) == "function" then
            print("✓ Method '" .. methodName .. "' exists")
        else
            warn("✗ Method '" .. methodName .. "' is missing or not a function")
            allPassed = false
        end
    end
    
    return allPassed
end

-- Run the validation steps
local module = validateSyntax()
local instance = validateInitialization(module)
local methodsValid = validateMethods(instance)

-- Present final results
print("\n========== VALIDATION RESULTS ==========")

if module and instance and methodsValid then
    print("\n✅ ALL VALIDATION TESTS PASSED!")
    print("The InteractionSystemModule has been fixed successfully!")
else
    print("\n❌ VALIDATION FAILED")
    print("Please review the errors above and make additional fixes.")
end

print("\n========== END OF VALIDATION ==========")
