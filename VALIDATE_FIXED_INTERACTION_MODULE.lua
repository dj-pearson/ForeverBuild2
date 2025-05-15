-- VALIDATE_FIXED_INTERACTION_MODULE.lua
-- This script validates the fixed interaction module installation
-- Run this script in the Command Bar of Roblox Studio

-- Check if the fixed module exists
local fixedModule = game.Players.LocalPlayer.PlayerScripts.client.interaction:FindFirstChild("InteractionSystemModule_fixed")
if not fixedModule then
    warn("ERROR: InteractionSystemModule_fixed not found!")
    return
end

print("✓ InteractionSystemModule_fixed found")

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

-- Check if highlighting works
local worldItems = workspace:FindFirstChild("World_Items")
if not worldItems then
    print("! World_Items folder not found, can't test highlighting")
else
    print("! Testing highlighting functionality...")
    print("! Please approach an interactable object to see if highlighting works")
end

print("✓ Validation complete - the fixed interaction module appears to be properly installed")
print("! If you still experience issues, please check the output log for any errors from InteractionSystemModule_fixed")
