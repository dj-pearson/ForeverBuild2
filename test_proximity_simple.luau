-- Simple Proximity UI Test (No HttpService)
print("=== TESTING PROXIMITY UI SYSTEM ===")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Wait a moment for systems to initialize
task.wait(2)

-- Check if ItemInteractionClient is available
local itemClient = _G.ItemInteractionClient
if itemClient then
    print("✅ Found ItemInteractionClient in _G")
    print("   proximityEnabled:", itemClient.proximityEnabled)
    print("   maxInteractionDistance:", itemClient.maxInteractionDistance)
else
    print("❌ ItemInteractionClient not found in _G")
end

-- Check world items
local function checkWorldItems()
    print("\n📦 CHECKING WORLD ITEMS:")
    
    local worldItems = workspace:FindFirstChild("World_Items")
    if worldItems then
        local placed = worldItems:FindFirstChild("Placed")
        if placed then
            print("✅ Found World_Items.Placed folder")
            for _, item in pairs(placed:GetChildren()) do
                if item:IsA("Model") then
                    print(string.format("  📋 %s at position %s", 
                        item.Name, tostring(item.PrimaryPart and item.PrimaryPart.Position or "unknown")))
                end
            end
        else
            print("❌ Placed folder not found")
        end
    else
        print("❌ World_Items folder not found")
    end
end

checkWorldItems()

-- Monitor for proximity UI appearing
print("\n🔄 MONITORING FOR PROXIMITY UI:")
print("Walk near the placed items and watch for proximity UI...")

local connection
local checkCount = 0
connection = RunService.Heartbeat:Connect(function()
    checkCount = checkCount + 1
    
    -- Only check every 30 frames (about twice per second)
    if checkCount % 30 == 0 then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in pairs(playerGui:GetDescendants()) do
                if gui.Name == "ProximityInteractUI" and gui.Enabled then
                    print("🎯 PROXIMITY UI DETECTED! Found active ProximityInteractUI")
                    local label = gui:FindFirstChild("Title", true)
                    if label then
                        print("   Text:", label.Text)
                    end
                end
            end
        end
        
        -- Also check for billboard GUIs on world items
        local worldItems = workspace:FindFirstChild("World_Items")
        if worldItems then
            local placed = worldItems:FindFirstChild("Placed")
            if placed then
                for _, item in pairs(placed:GetChildren()) do
                    if item:IsA("Model") then
                        for _, child in pairs(item:GetDescendants()) do
                            if child.Name == "ProximityInteractUI" and child.Enabled then
                                print("🎯 FOUND PROXIMITY UI ON ITEM:", item.Name)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Stop monitoring after 60 seconds
task.delay(60, function()
    connection:Disconnect()
    print("🛑 Monitoring stopped after 60 seconds")
end) 