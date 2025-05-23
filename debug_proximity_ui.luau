-- Debug Proximity UI System
print("=== DEBUGGING PROXIMITY UI SYSTEM ===")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Check if ItemInteractionClient exists and is initialized
local function checkItemInteractionClient()
    print("\n🔍 CHECKING ITEMINTERACTIONCLIENT:")
    
    -- Check if it exists in the expected locations
    local clientScript = player.PlayerScripts:FindFirstChild("client")
    if clientScript then
        local interactionFolder = clientScript:FindFirstChild("interaction")
        if interactionFolder then
            local clientModule = interactionFolder:FindFirstChild("ItemInteractionClient")
            if clientModule then
                print("✅ Found ItemInteractionClient module")
                
                -- Try to require it
                local success, result = pcall(function()
                    return require(clientModule)
                end)
                
                if success then
                    print("✅ Successfully required ItemInteractionClient")
                    return result
                else
                    print("❌ Failed to require ItemInteractionClient:", result)
                end
            else
                print("❌ ItemInteractionClient module not found")
            end
        else
            print("❌ interaction folder not found")
        end
    else
        print("❌ client script folder not found")
    end
    
    return nil
end

-- Check what items exist in the world
local function checkWorldItems()
    print("\n📦 CHECKING WORLD ITEMS:")
    
    local worldItems = workspace:FindFirstChild("World_Items")
    if worldItems then
        local placed = worldItems:FindFirstChild("Placed")
        if placed then
            print("✅ Found World_Items.Placed folder")
            local count = 0
            for _, item in pairs(placed:GetChildren()) do
                if item:IsA("Model") then
                    count = count + 1
                    local itemId = item:GetAttribute("itemId")
                    local instanceId = item:GetAttribute("instanceId")
                    print(string.format("  📋 %s - itemId: %s, instanceId: %s", 
                        item.Name, tostring(itemId), tostring(instanceId)))
                end
            end
            print(string.format("Total world items: %d", count))
        else
            print("❌ Placed folder not found")
        end
    else
        print("❌ World_Items folder not found")
    end
end

-- Test manual proximity detection
local function testManualProximityDetection()
    print("\n🎯 TESTING MANUAL PROXIMITY DETECTION:")
    
    local character = player.Character
    if not character then
        print("❌ No character found")
        return
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        print("❌ No HumanoidRootPart found")
        return
    end
    
    print("✅ Character position:", hrp.Position)
    
    -- Check what we're currently pointing at
    local target = mouse.Target
    if target then
        print("✅ Mouse target:", target:GetFullName())
        
        -- Try to get interactable from target
        local ItemInteractionClient = checkItemInteractionClient()
        if ItemInteractionClient then
            local instance = ItemInteractionClient.new()
            local interactable = instance:GetInteractableFromPart(target)
            if interactable then
                print("✅ Found interactable:", interactable:GetFullName())
                
                -- Check distance
                local objectPos
                if interactable:IsA("Model") and interactable.PrimaryPart then
                    objectPos = interactable.PrimaryPart.Position
                elseif interactable:IsA("Part") then
                    objectPos = interactable.Position
                end
                
                if objectPos then
                    local distance = (hrp.Position - objectPos).Magnitude
                    print(string.format("📏 Distance to object: %.2f units", distance))
                    print(string.format("📏 Max interaction distance: %d units", instance.maxInteractionDistance or 10))
                    
                    if distance <= (instance.maxInteractionDistance or 10) then
                        print("✅ Object is within interaction range")
                    else
                        print("❌ Object is too far away")
                    end
                end
            else
                print("❌ No interactable found from target")
            end
        end
    else
        print("❌ No mouse target")
    end
end

-- Check if proximity UI exists
local function checkProximityUI()
    print("\n🖼️ CHECKING PROXIMITY UI:")
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        -- Look for any proximity UI instances
        local found = false
        for _, gui in pairs(playerGui:GetDescendants()) do
            if gui.Name == "ProximityInteractUI" then
                print("✅ Found ProximityUI:", gui:GetFullName())
                print("   Enabled:", gui.Enabled)
                print("   Visible:", gui.Visible)
                found = true
            end
        end
        
        if not found then
            print("❌ No ProximityUI found in PlayerGui")
        end
        
        -- Also check for any items with ProximityUI children
        for _, item in pairs(workspace:GetDescendants()) do
            if item.Name == "ProximityUI" then
                print("✅ Found ProximityUI attached to:", item.Parent and item.Parent:GetFullName() or "unknown")
            end
        end
    else
        print("❌ PlayerGui not found")
    end
end

-- Run all checks
checkItemInteractionClient()
checkWorldItems()
testManualProximityDetection()
checkProximityUI()

print("\n🔄 CONTINUOUS MONITORING:")
print("Watch the output below as you move around and point at objects...")

-- Set up continuous monitoring
local connection
connection = RunService.Heartbeat:Connect(function()
    local target = mouse.Target
    if target then
        local worldItems = workspace:FindFirstChild("World_Items")
        if worldItems then
            local placed = worldItems:FindFirstChild("Placed")
            if placed and target:IsDescendantOf(placed) then
                print("🎯 Pointing at world item:", target:GetFullName())
                
                -- Check character distance
                local character = player.Character
                if character then
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local distance = (hrp.Position - target.Position).Magnitude
                        print(string.format("📏 Distance: %.2f", distance))
                    end
                end
            end
        end
    end
    
    -- Stop after 30 seconds to avoid spam
    task.wait(1)
end)

task.delay(30, function()
    connection:Disconnect()
    print("🛑 Monitoring stopped after 30 seconds")
end) 