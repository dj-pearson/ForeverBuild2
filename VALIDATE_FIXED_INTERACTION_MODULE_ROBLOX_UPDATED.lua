-- VALIDATE_FIXED_INTERACTION_MODULE_ROBLOX_UPDATED.lua
-- This script validates the fixed interaction module installation in Roblox
-- Run this script in the Command Bar of Roblox Studio after running the installation script

print("Starting validation of fixed InteractionSystemModule...")

-- Function to find the fixed module in ANY location
local function findFixedModuleAnywhere()
    -- First check global variable
    if _G.InteractionSystem then
        print("Found InteractionSystem in _G global variable")
        return true, _G.InteractionSystem, "global variable"
    end
    
    -- Check common locations
    local locations = {
        -- Check in PlayerScripts directly
        {
            path = game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerScripts,
            name = "PlayerScripts root"
        },
        -- Check in client folder
        {
            path = game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerScripts and 
                   game.Players.LocalPlayer.PlayerScripts:FindFirstChild("client"),
            name = "PlayerScripts.client"
        },
        -- Check in interaction folder
        {
            path = game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerScripts and 
                   game.Players.LocalPlayer.PlayerScripts:FindFirstChild("client") and
                   game.Players.LocalPlayer.PlayerScripts.client:FindFirstChild("interaction"),
            name = "PlayerScripts.client.interaction"
        },
        -- Check in StarterPlayerScripts
        {
            path = game.StarterPlayer and game.StarterPlayer.StarterPlayerScripts and
                   game.StarterPlayer.StarterPlayerScripts:FindFirstChild("client") and
                   game.StarterPlayer.StarterPlayerScripts.client:FindFirstChild("interaction"),
            name = "StarterPlayerScripts.client.interaction"
        }
    }
    
    -- Check each location
    for _, location in ipairs(locations) do
        if location.path then
            local module = location.path:FindFirstChild("InteractionSystemModule_fixed")
            if module then
                print("Found InteractionSystemModule_fixed at:", module:GetFullName())
                
                -- Try to require it
                local success, result = pcall(function()
                    return require(module)
                end)
                
                if success then
                    print("Successfully required module from:", location.name)
                    return true, result, module:GetFullName()
                else
                    warn("Found module at " .. location.name .. " but failed to require it:", result)
                end
            end
        end
    end
    
    -- Additional search - recursive through all PlayerScripts
    local function searchRecursively(parent, indent)
        if not parent then return false, nil end
        indent = indent or 0
        
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == "InteractionSystemModule_fixed" then
                print(string.rep("  ", indent) .. "Found module at:", child:GetFullName())
                
                -- Try to require it
                local success, result = pcall(function()
                    return require(child)
                end)
                
                if success then
                    print("Successfully required module from recursive search")
                    return true, result, child:GetFullName()
                else
                    warn("Found module but failed to require it:", result)
                end
            end
            
            if #child:GetChildren() > 0 then
                local found, module, path = searchRecursively(child, indent + 1)
                if found then
                    return true, module, path
                end
            end
        end
        
        return false, nil
    end
    
    if game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerScripts then
        local found, module, path = searchRecursively(game.Players.LocalPlayer.PlayerScripts)
        if found then
            return true, module, path
        end
    end
    
    return false, nil
end

-- Find the module
local moduleFound, module, modulePath = findFixedModuleAnywhere()

if not moduleFound then
    warn("ERROR: InteractionSystemModule_fixed not found anywhere!")
    
    -- Provide detailed structure information to help debugging
    print("\nCurrent game structure:")
    
    -- Check StarterPlayerScripts
    if game.StarterPlayer and game.StarterPlayer.StarterPlayerScripts then
        print("StarterPlayerScripts contents:")
        for _, child in pairs(game.StarterPlayer.StarterPlayerScripts:GetChildren()) do
            print("  -", child.Name, "[" .. child.ClassName .. "]")
            
            if child.Name == "client" and #child:GetChildren() > 0 then
                for _, subchild in pairs(child:GetChildren()) do
                    print("    -", subchild.Name, "[" .. subchild.ClassName .. "]")
                    
                    if subchild.Name == "interaction" and #subchild:GetChildren() > 0 then
                        for _, module in pairs(subchild:GetChildren()) do
                            print("      -", module.Name, "[" .. module.ClassName .. "]")
                        end
                    end
                end
            end
        end
    else
        print("StarterPlayerScripts not found or empty")
    end
    
    -- Check PlayerScripts
    if game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerScripts then
        print("\nPlayerScripts contents:")
        for _, child in pairs(game.Players.LocalPlayer.PlayerScripts:GetChildren()) do
            print("  -", child.Name, "[" .. child.ClassName .. "]")
            
            if child.Name == "client" and #child:GetChildren() > 0 then
                for _, subchild in pairs(child:GetChildren()) do
                    print("    -", subchild.Name, "[" .. subchild.ClassName .. "]")
                    
                    if subchild.Name == "interaction" and #subchild:GetChildren() > 0 then
                        for _, module in pairs(subchild:GetChildren()) do
                            print("      -", module.Name, "[" .. module.ClassName .. "]")
                        end
                    end
                end
            end
        end
    else
        print("PlayerScripts not found or empty")
    end
    
    return
end

print("✓ InteractionSystemModule_fixed found and loaded successfully from:", modulePath)

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
    if _G.InteractionSystem then
        print("  There is a different InteractionSystem in the global context")
    else
        print("  No InteractionSystem found in the global context")
        print("  Setting module as global _G.InteractionSystem")
        _G.InteractionSystem = module
    end
end

-- Check ReplicatedStorage paths
print("Checking ReplicatedStorage structure...")
if game:GetService("ReplicatedStorage"):FindFirstChild("shared") then
    print("✓ Found ReplicatedStorage.shared")
else
    print("! Missing ReplicatedStorage.shared folder - this may cause issues with SharedModule loading")
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
                
                -- Additional check for PrimaryPart
                if not child:FindFirstChild("PrimaryPart") then
                    warn("  ! This object has no PrimaryPart, which may cause errors")
                end
            end
            
            if #child:GetChildren() > 0 then
                countInteractables(child)
            end
        end
    end
    
    countInteractables(worldItems)
    print("  Total interactable objects found:", count)
    
    if count == 0 then
        print("  No interactable objects found. You need to add the Interactable attribute to objects.")
        print("  Example: in Roblox Studio, select an object, add an attribute named 'Interactable' of type bool, set to true")
    end
end

print("✓ Validation complete - the fixed interaction module appears to be properly installed")
print("! If you still experience issues, check the output logs and make sure objects have:")
print("  1. The 'Interactable' attribute set to true")
print("  2. A PrimaryPart assigned (for models)")
print("  3. Are located in the Workspace.World_Items folder")
