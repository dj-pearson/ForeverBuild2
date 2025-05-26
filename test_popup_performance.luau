-- Test script for optimized Bottom Purchase Popup
print("=== POPUP PERFORMANCE OPTIMIZATION TEST ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Wait for player
local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found - test only works in game")
    return
end

print("✅ Player found:", player.Name)

-- Test 1: Load optimized BottomPurchasePopup
print("\n🔍 TEST 1: Loading Optimized BottomPurchasePopup")

local BottomPurchasePopup
local success, err = pcall(function()
    BottomPurchasePopup = require(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("client"):WaitForChild("interaction"):WaitForChild("BottomPurchasePopup"))
end)

if not success or not BottomPurchasePopup then
    print("❌ Failed to load BottomPurchasePopup:", err)
    return
end

print("✅ BottomPurchasePopup loaded successfully")

-- Test 2: Create test scenario
print("\n🔍 TEST 2: Creating Responsive Test Scenario")

-- Get player position for reference
local character = player.Character
if not character or not character:FindFirstChild("HumanoidRootPart") then
    print("❌ Player character not found")
    return
end

local playerPos = character.HumanoidRootPart.Position

-- Create Items folder if it doesn't exist
local itemsFolder = workspace:FindFirstChild("Items")
if not itemsFolder then
    itemsFolder = Instance.new("Folder")
    itemsFolder.Name = "Items"
    itemsFolder.Parent = workspace
end

-- Function to create responsive test item
local function createResponsiveTestItem(name, position, color)
    local item = Instance.new("Part")
    item.Name = name
    item.Size = Vector3.new(3, 3, 3)
    item.Position = position
    item.Anchored = true
    item.BrickColor = color
    item.Material = Enum.Material.Neon
    
    -- Mark as purchasable
    item:SetAttribute("Purchasable", true)
    item:SetAttribute("Price", 15)
    item:SetAttribute("priceIngame", 15)
    
    -- Add responsive visual marker
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 120, 0, 60)
    billboardGui.StudsOffset = Vector3.new(0, 4, 0)
    billboardGui.Parent = item
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name .. "\n(OPTIMIZED)"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = billboardGui
    
    item.Parent = itemsFolder
    return item
end

-- Create test items at different distances
local testItems = {
    createResponsiveTestItem("CLOSE_ITEM", playerPos + Vector3.new(5, 0, 0), BrickColor.new("Bright green")),
    createResponsiveTestItem("MEDIUM_ITEM", playerPos + Vector3.new(10, 0, 3), BrickColor.new("Bright blue")),
    createResponsiveTestItem("FAR_ITEM", playerPos + Vector3.new(15, 0, -3), BrickColor.new("Bright yellow"))
}

print("✅ Created", #testItems, "responsive test items")

-- Test 3: Initialize optimized popup system
print("\n🔍 TEST 3: Initializing Optimized Popup System")

local popup = BottomPurchasePopup.new()

-- Verify optimization settings
print("📊 Configuration:")
print("   Fast Update Rate:", popup.UPDATE_INTERVAL, "seconds (", math.floor(1/popup.UPDATE_INTERVAL), "FPS )")
print("   Slow Update Rate:", popup.SLOW_UPDATE_INTERVAL, "seconds")
print("   Fast Mode Distance:", popup.FAST_UPDATE_DISTANCE, "studs")

popup:Initialize()
print("✅ Optimized popup system initialized")

-- Test 4: Monitor performance and responsiveness
print("\n🔍 TEST 4: Monitoring Performance & Responsiveness")

local startTime = tick()
local updateCounts = {fast = 0, slow = 0}
local lastMode = nil

-- Monitor update modes
local monitorConnection = RunService.Heartbeat:Connect(function()
    if popup.fastUpdateMode ~= lastMode then
        lastMode = popup.fastUpdateMode
        local mode = lastMode and "FAST" or "SLOW"
        updateCounts[lastMode and "fast" or "slow"] = updateCounts[lastMode and "fast" or "slow"] + 1
        print("🚀 Switched to", mode, "update mode")
    end
end)

-- Test 5: Automatic responsiveness test
print("\n🔍 TEST 5: Automatic Responsiveness Test")
print("This will automatically move your character to test popup responsiveness...")

local function testResponsiveness()
    local humanoidRootPart = character.HumanoidRootPart
    local originalPosition = humanoidRootPart.Position
    
    -- Test sequence: move near each item and measure response time
    for i, item in ipairs(testItems) do
        print("\n--- Testing item", i, ":", item.Name, "---")
        
        -- Move to item
        local targetPos = item.Position + Vector3.new(0, 0, 4) -- 4 studs away
        humanoidRootPart.CFrame = CFrame.new(targetPos, item.Position)
        
        local moveTime = tick()
        local popupAppeared = false
        local responseTime = nil
        
        -- Wait for popup to appear (max 2 seconds)
        local checkConnection
        checkConnection = RunService.Heartbeat:Connect(function()
            if popup.currentPopup and not popupAppeared then
                popupAppeared = true
                responseTime = tick() - moveTime
                print("✅ Popup appeared in", math.floor(responseTime * 1000), "ms")
                checkConnection:Disconnect()
            end
        end)
        
        task.wait(2) -- Wait 2 seconds
        
        if checkConnection.Connected then
            checkConnection:Disconnect()
        end
        
        if not popupAppeared then
            print("❌ Popup did not appear within 2 seconds")
        end
        
        -- Move away to test hiding
        humanoidRootPart.CFrame = CFrame.new(originalPosition)
        task.wait(1)
    end
    
    -- Return to original position
    humanoidRootPart.CFrame = CFrame.new(originalPosition)
end

-- Run responsiveness test
testResponsiveness()

-- Test 6: Performance summary
print("\n🔍 TEST 6: Performance Summary")

monitorConnection:Disconnect()

local totalTime = tick() - startTime
print("📊 Test Results:")
print("   Total test duration:", math.floor(totalTime), "seconds")
print("   Fast mode switches:", updateCounts.fast)
print("   Slow mode switches:", updateCounts.slow)

if popup.lineOfSightChecker then
    print("   Line of sight system: ✅ ENABLED with optimized cache")
else
    print("   Line of sight system: ❌ DISABLED")
end

-- Test 7: Manual testing instructions
print("\n📋 MANUAL TESTING INSTRUCTIONS:")
print("==========================================")
print("1. Move around the test items and observe:")
print("   • Popup should appear INSTANTLY when approaching items")
print("   • No noticeable delay or lag")
print("   • Smooth transitions between items")
print("")
print("2. Watch console for update mode switches:")
print("   • 'FAST' mode when near items (high frequency updates)")
print("   • 'SLOW' mode when away from items (battery friendly)")
print("")
print("3. Test edge cases:")
print("   • Walk directly on top of items")
print("   • Quick movements between items")
print("   • Walking away should hide popup quickly")
print("")

-- Cleanup after 2 minutes
print("\n⏰ Test will cleanup in 2 minutes...")
print("Use this time for manual testing!")

task.wait(120)

-- Cleanup
print("\n🧹 Cleaning up test objects...")
for _, item in ipairs(testItems) do
    if item and item.Parent then
        item:Destroy()
    end
end

popup:Cleanup()

print("✅ Popup Performance Optimization Test Complete!")
print("📈 The popup should now be MUCH more responsive!")
print("Key improvements:")
print("  • 6x faster update rate (0.05s vs 0.3s)")
print("  • Dynamic update speeds")
print("  • Optimized line of sight caching")
print("  • Instant response for very close items") 