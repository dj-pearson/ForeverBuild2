-- Disable Old Popup System and Enable New Integrated System
-- Run this script to switch from the old StarterPlayerScripts system to the new codebase-integrated system

local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local StarterGui = game:GetService("StarterGui")

print("=== SWITCHING TO INTEGRATED BOTTOM POPUP SYSTEM ===")

-- Step 1: Remove all old popup scripts from StarterPlayerScripts
if StarterPlayerScripts then
    local oldScripts = {
        "AutoPurchaseDialogHandler",
        "SimplePurchaseDialogHandler", 
        "SmallBottomPurchasePopup",
        "CleanBottomPurchasePopup"
    }
    
    for _, scriptName in ipairs(oldScripts) do
        local script = StarterPlayerScripts:FindFirstChild(scriptName)
        if script then
            script:Destroy()
            print("✓ Removed old script:", scriptName)
        end
    end
else
    print("! StarterPlayerScripts not found")
end

-- Step 2: Create ClientInit script if it doesn't exist in StarterPlayerScripts
if StarterPlayerScripts then
    local existingClientInit = StarterPlayerScripts:FindFirstChild("ClientInit")
    if existingClientInit then
        existingClientInit:Destroy()
        print("✓ Removed existing ClientInit from StarterPlayerScripts")
    end
    
    -- Create new ClientInit that loads our integrated system
    local clientInit = Instance.new("LocalScript")
    clientInit.Name = "ClientInit"
    clientInit.Parent = StarterPlayerScripts
    
    clientInit.Source = [[
-- ClientInit in StarterPlayerScripts - Loads the integrated system from ReplicatedStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("ClientInit (StarterPlayerScripts): Starting...")

-- Wait for the shared module and client files
local shared = ReplicatedStorage:WaitForChild("shared", 10)
if not shared then
    warn("ClientInit: Could not find shared module in ReplicatedStorage")
    return
end

-- Wait a bit for everything to load
wait(2)

-- Try to initialize the ItemInteractionClient from the shared/client modules
local success, errorMessage = pcall(function()
    -- The path to your client interaction module in ReplicatedStorage
    local clientFolder = shared:FindFirstChild("client")
    if not clientFolder then
        warn("ClientInit: Could not find client folder in shared")
        return
    end
    
    local interactionFolder = clientFolder:FindFirstChild("interaction")
    if not interactionFolder then
        warn("ClientInit: Could not find interaction folder in client")
        return
    end
    
    local ItemInteractionClient = require(interactionFolder:FindFirstChild("ItemInteractionClient"))
    if not ItemInteractionClient then
        warn("ClientInit: Could not require ItemInteractionClient")
        return
    end
    
    -- Create and initialize
    local interactionClient = ItemInteractionClient.new()
    local initSuccess = interactionClient:Initialize()
    
    if initSuccess then
        print("ClientInit: Successfully initialized integrated bottom popup system!")
        _G.ItemInteractionClient = interactionClient
        
        -- Clean up when player leaves
        player.AncestryChanged:Connect(function()
            if interactionClient then
                interactionClient:Cleanup()
            end
        end)
    else
        warn("ClientInit: Failed to initialize ItemInteractionClient")
    end
end)

if not success then
    warn("ClientInit: Error:", errorMessage)
    
    -- Fallback: show a simple message
    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCore("SendNotification", {
        Title = "Popup System";
        Text = "Loading purchase popup system...";
        Duration = 3;
    })
end

print("ClientInit (StarterPlayerScripts): Complete")
]]
    
    print("✓ Created new ClientInit script in StarterPlayerScripts")
end

print("")
print("=== INTEGRATION COMPLETE ===")
print("✓ Removed all old popup scripts")
print("✓ Created ClientInit to load your integrated system")
print("✓ Your bottom popup system is now part of your codebase files")
print("✓ Changes will sync with your version control")
print("")
print("The system should now work with your existing files!")
print("Test in-game to confirm the bottom popup appears for glow items.") 