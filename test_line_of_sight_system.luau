-- Test script for Line of Sight Detection System
print("=== LINE OF SIGHT DETECTION SYSTEM TEST ===")

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

-- Test 1: Load LineOfSightChecker
print("\n🔍 TEST 1: Loading LineOfSightChecker Module")

local LineOfSightChecker
local success, err = pcall(function()
    LineOfSightChecker = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("interaction"):WaitForChild("LineOfSightChecker"))
end)

if not success or not LineOfSightChecker then
    print("❌ Failed to load LineOfSightChecker:", err)
    return
end

print("✅ LineOfSightChecker loaded successfully")

-- Initialize the checker
local checker = LineOfSightChecker:Init()
print("✅ LineOfSightChecker initialized")

-- Test 2: Check BottomPurchasePopup Integration
print("\n🔍 TEST 2: Checking BottomPurchasePopup Integration")

local purchasePopup
local popupSuccess, popupErr = pcall(function()
    -- Try to find BottomPurchasePopup in the correct location
    local BottomPurchasePopup = require(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("client"):WaitForChild("interaction"):WaitForChild("BottomPurchasePopup"))
    purchasePopup = BottomPurchasePopup.new()
end)

if popupSuccess and purchasePopup then
    print("✅ BottomPurchasePopup integration successful")
    if purchasePopup.lineOfSightChecker then
        print("✅ Line of sight checking is enabled in purchase system")
    else
        print("⚠️ Line of sight checking not enabled in purchase system")
    end
else
    print("❌ Failed to load BottomPurchasePopup:", popupErr)
end

-- Test 3: Create Test Scenario
print("\n🔍 TEST 3: Creating Test Scenario")

-- Get player position for reference
local character = player.Character
if not character or not character:FindFirstChild("HumanoidRootPart") then
    print("❌ Player character not found")
    return
end

local playerPos = character.HumanoidRootPart.Position

-- Function to create test items
local function createTestItem(name, position, shouldHaveObstacle)
    local item = Instance.new("Part")
    item.Name = name
    item.Size = Vector3.new(2, 2, 2)
    item.Position = position
    item.Anchored = true
    item.BrickColor = BrickColor.new("Bright blue")
    
    -- Mark as purchasable
    item:SetAttribute("Purchasable", true)
    item:SetAttribute("Price", 10)
    item:SetAttribute("priceIngame", 10)
    
    -- Add visual marker
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 100, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.Parent = item
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = billboardGui
    
    item.Parent = workspace
    
    -- Create obstacle if requested
    if shouldHaveObstacle then
        local wall = Instance.new("Part")
        wall.Name = name .. "_Wall"
        wall.Size = Vector3.new(8, 8, 1)
        wall.Position = playerPos + (position - playerPos).Unit * ((position - playerPos).Magnitude / 2)
        wall.Anchored = true
        wall.BrickColor = BrickColor.new("Dark stone grey")
        wall.Material = Enum.Material.Concrete
        wall.Parent = workspace
        
        -- Add label to wall
        local wallGui = Instance.new("BillboardGui")
        wallGui.Size = UDim2.new(0, 100, 0, 30)
        wallGui.Parent = wall
        
        local wallLabel = Instance.new("TextLabel")
        wallLabel.Size = UDim2.new(1, 0, 1, 0)
        wallLabel.BackgroundTransparency = 1
        wallLabel.Text = "WALL"
        wallLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        wallLabel.TextStrokeTransparency = 0
        wallLabel.Font = Enum.Font.GothamBold
        wallLabel.TextScaled = true
        wallLabel.Parent = wallGui
        
        return item, wall
    end
    
    return item
end

-- Create test scenarios
local testItems = {}

-- Scenario 1: Item with clear line of sight
local clearItem = createTestItem("CLEAR_ITEM", playerPos + Vector3.new(8, 0, 0), false)
table.insert(testItems, {item = clearItem, shouldBeVisible = true, description = "Clear line of sight"})

-- Scenario 2: Item behind wall
local blockedItem, wall1 = createTestItem("BLOCKED_ITEM", playerPos + Vector3.new(-8, 0, 0), true)
table.insert(testItems, {item = blockedItem, shouldBeVisible = false, description = "Behind wall", wall = wall1})

-- Scenario 3: Item above with floor obstacle
local aboveItem = createTestItem("ABOVE_ITEM", playerPos + Vector3.new(0, 12, 0), false)
local floor = Instance.new("Part")
floor.Name = "Floor_Obstacle"
floor.Size = Vector3.new(10, 1, 10)
floor.Position = playerPos + Vector3.new(0, 6, 0)
floor.Anchored = true
floor.BrickColor = BrickColor.new("Brown")
floor.Material = Enum.Material.Wood
floor.Parent = workspace
table.insert(testItems, {item = aboveItem, shouldBeVisible = false, description = "Above with floor obstacle", wall = floor})

-- Scenario 4: Item far away (should fail distance check)
local farItem = createTestItem("FAR_ITEM", playerPos + Vector3.new(25, 0, 0), false)
table.insert(testItems, {item = farItem, shouldBeVisible = false, description = "Too far away"})

print("✅ Created", #testItems, "test scenarios")

-- Test 4: Test Line of Sight Detection
print("\n🔍 TEST 4: Testing Line of Sight Detection")

checker:SetDebugMode(true) -- Enable debug visualization

for i, testCase in ipairs(testItems) do
    print("\n--- Test Case", i, ":", testCase.description, "---")
    
    local result = checker:HasLineOfSight(player, testCase.item)
    local expected = testCase.shouldBeVisible
    
    if result == expected then
        print("✅ PASS:", testCase.description)
        print("   Expected:", expected and "VISIBLE" or "BLOCKED")
        print("   Actual:", result and "VISIBLE" or "BLOCKED")
    else
        print("❌ FAIL:", testCase.description)
        print("   Expected:", expected and "VISIBLE" or "BLOCKED")
        print("   Actual:", result and "VISIBLE" or "BLOCKED")
    end
    
    -- Wait a moment between tests to see debug rays
    task.wait(2)
end

-- Test 5: Configuration Testing
print("\n🔍 TEST 5: Testing Configuration Options")

-- Test different distance settings
print("Testing distance configuration...")
checker:SetMaxDistance(5) -- Very short distance
local result1 = checker:HasLineOfSight(player, clearItem)
print("Short distance (5 studs):", result1 and "VISIBLE" or "BLOCKED")

checker:SetMaxDistance(20) -- Longer distance
local result2 = checker:HasLineOfSight(player, clearItem)
print("Long distance (20 studs):", result2 and "VISIBLE" or "BLOCKED")

-- Test transparency settings
print("Testing transparency configuration...")
checker:SetTransparentPartsBlock(false) -- Transparent parts don't block
local transparentWall = Instance.new("Part")
transparentWall.Name = "TransparentWall"
transparentWall.Size = Vector3.new(8, 8, 1)
transparentWall.Position = playerPos + Vector3.new(0, 0, 6)
transparentWall.Anchored = true
transparentWall.Transparency = 0.9
transparentWall.BrickColor = BrickColor.new("Bright red")
transparentWall.Parent = workspace

local transparentItem = createTestItem("TRANSPARENT_TEST", playerPos + Vector3.new(0, 0, 10), false)
local result3 = checker:HasLineOfSight(player, transparentItem)
print("Through transparent wall:", result3 and "VISIBLE" or "BLOCKED")

-- Test 6: Performance Test
print("\n🔍 TEST 6: Performance Testing")

local startTime = tick()
local iterations = 100

for i = 1, iterations do
    checker:HasLineOfSight(player, clearItem)
end

local endTime = tick()
local totalTime = endTime - startTime
local avgTime = totalTime / iterations

print("Performance Test Results:")
print("  Total time for", iterations, "checks:", math.floor(totalTime * 1000 + 0.5), "ms")
print("  Average time per check:", math.floor(avgTime * 1000 + 0.5), "ms")

if avgTime < 0.01 then
    print("✅ Performance: EXCELLENT (< 10ms per check)")
elseif avgTime < 0.02 then
    print("✅ Performance: GOOD (< 20ms per check)")
else
    print("⚠️ Performance: SLOW (> 20ms per check)")
end

-- Test 7: Integration Test with Purchase System
print("\n🔍 TEST 7: Integration Test with Purchase System")

if purchasePopup then
    print("Testing purchase popup with line of sight...")
    
    -- Create Items folder if it doesn't exist
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        itemsFolder = Instance.new("Folder")
        itemsFolder.Name = "Items"
        itemsFolder.Parent = workspace
    end
    
    -- Move test items to Items folder
    clearItem.Parent = itemsFolder
    blockedItem.Parent = itemsFolder
    
    print("Move close to CLEAR_ITEM to test purchase popup (should appear)")
    print("Move close to BLOCKED_ITEM to test purchase popup (should NOT appear)")
    
    -- Enable purchase popup
    purchasePopup:Initialize()
    
    print("Purchase popup system is now active - test by moving around!")
end

-- Instructions for manual testing
print("\n📋 MANUAL TESTING INSTRUCTIONS:")
print("==========================================")
print("1. Move around the test area and observe:")
print("   • CLEAR_ITEM: Should show purchase prompt when close")
print("   • BLOCKED_ITEM: Should NOT show prompt (blocked by wall)")
print("   • ABOVE_ITEM: Should NOT show prompt (blocked by floor)")
print("   • FAR_ITEM: Should NOT show prompt (too far)")
print("")
print("2. Watch for debug rays (green = clear, red = blocked)")
print("3. Check console for line of sight messages")
print("4. Verify purchase prompts only appear for visible items")
print("")

-- Cleanup after 3 minutes
print("\n⏰ Test objects will be cleaned up in 3 minutes...")
task.wait(180)

-- Cleanup
print("\n🧹 Cleaning up test objects...")
for _, testCase in ipairs(testItems) do
    if testCase.item and testCase.item.Parent then
        testCase.item:Destroy()
    end
    if testCase.wall and testCase.wall.Parent then
        testCase.wall:Destroy()
    end
end

if transparentWall and transparentWall.Parent then
    transparentWall:Destroy()
end

if transparentItem and transparentItem.Parent then
    transparentItem:Destroy()
end

if purchasePopup then
    purchasePopup:Cleanup()
end

checker:SetDebugMode(false)

print("✅ Line of Sight Detection System Test Complete!")
print("All test objects have been cleaned up.") 