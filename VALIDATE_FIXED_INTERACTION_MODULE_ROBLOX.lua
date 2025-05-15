-- VALIDATE_FIXED_INTERACTION_MODULE_ROBLOX.lua
-- This script validates the fixed interaction module installation in Roblox
-- Run this script in the Command Bar of Roblox Studio

print("Starting validation of fixed InteractionSystemModule...")

-- Function to find the interaction module
local function findFixedModule()
    local player = game.Players.LocalPlayer
    if not player then
        warn("ERROR: No LocalPlayer found. Make sure you're in Play mode.")
        return nil
    end
    
    print("Looking for fixed module in PlayerScripts for player:", player.Name)
    
    -- Search recursively through PlayerScripts
    local function searchForModule(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == "InteractionSystemModule_fixed" then
                return child
            end
            
            if #child:GetChildren() > 0 then
                local result = searchForModule(child)
                if result then return result end
            end
        end
        return nil
    end
    
    local result = searchForModule(player.PlayerScripts)
    return result
end

-- Find the module
local fixedModule = findFixedModule()
if not fixedModule then
    warn("ERROR: InteractionSystemModule_fixed not found anywhere in PlayerScripts!")
    return
end

print("✓ Found InteractionSystemModule_fixed at:", fixedModule:GetFullName())

-- Try to require the module
local success, module = pcall(function()
    return require(fixedModule)
end)

if not success then
    warn("ERROR: Failed to require InteractionSystemModule_fixed:", module)
    return
end

print("✓ InteractionSystemModule_fixed loaded successfully")

-- Check if the module has the required methods
local requiredMethods = {
    "init",
    "update",
    "getClosestInteractable",
    "interact",
    "isInteractable",
    "showPrompt",
    "hidePrompt",
    "setupInput",
    "cleanup"
}

for _, methodName in ipairs(requiredMethods) do
    if type(module[methodName]) ~= "function" then
        warn("ERROR: Missing required method:", methodName)
        return
    end
end

print("✓ All required methods are present")

-- Check if the module is active in _G
if _G.InteractionSystem == module then
    print("✓ Module is currently active in global context")
else
    print("! Module is not currently set as the active InteractionSystem in global context")
end

-- Check ReplicatedStorage paths
print("Checking ReplicatedStorage structure...")
if ReplicatedStorage:FindFirstChild("shared") then
    print("✓ Found ReplicatedStorage.shared")
else
    print("! Missing ReplicatedStorage.shared folder")
end

-- Check if highlighting works
local worldItems = workspace:FindFirstChild("World_Items")
if not worldItems then
    print("! World_Items folder not found in workspace, can't test highlighting")
else
    print("! Testing highlighting functionality...")
    print("! Please approach an interactable object to see if highlighting works")
    
    -- Count interactable objects
    local count = 0
    local function countInteractables(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:GetAttribute("Interactable") then
                count = count + 1
                print("  Found interactable object:", child:GetFullName())
            end
            
            if #child:GetChildren() > 0 then
                countInteractables(child)
            end
        end
    end
    
    countInteractables(worldItems)
    print("  Total interactable objects found:", count)
end

print("✓ Validation complete - the fixed interaction module appears to be properly installed")
print("! If you still experience issues, please check the output log for any errors from InteractionSystemModule_fixed")
