-- test_enhanced_purchase_system.luau
-- Test script for the Enhanced Purchase System

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

print("🧪 Testing Enhanced Purchase System...")

-- Test function to create a sample purchasable item
local function createTestItem()
    local testItem = Instance.new("Part")
    testItem.Name = "Red Brick Wall"
    testItem.Size = Vector3.new(4, 8, 1)
    testItem.Material = Enum.Material.Brick
    testItem.BrickColor = BrickColor.new("Bright red")
    testItem.Anchored = true
    
    -- Place it near the player
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        testItem.Position = player.Character.HumanoidRootPart.Position + Vector3.new(10, 0, 0)
    else
        testItem.Position = Vector3.new(0, 5, 0)
    end
    
    testItem.Parent = workspace
    
    -- Add purchase data
    testItem:SetAttribute("Purchasable", true)
    testItem:SetAttribute("ItemName", "Red Brick Wall")
    testItem:SetAttribute("ItemPrice", 50)
    testItem:SetAttribute("Category", "Walls")
    testItem:SetAttribute("Description", "A sturdy red brick wall for building")
    
    print("✅ Created test item:", testItem.Name, "at position:", testItem.Position)
    return testItem
end

-- Create multiple test items
local function createMultipleTestItems()
    local items = {}
    local itemTypes = {
        {name = "Blue Window", price = 75, color = "Bright blue"},
        {name = "Green Door", price = 100, color = "Bright green"},
        {name = "Yellow Roof Tile", price = 40, color = "Bright yellow"},
        {name = "Purple Floor", price = 30, color = "Bright violet"}
    }
    
    for i, itemData in ipairs(itemTypes) do
        local item = Instance.new("Part")
        item.Name = itemData.name
        item.Size = Vector3.new(4, 4, 1)
        item.Material = Enum.Material.Plastic
        item.BrickColor = BrickColor.new(itemData.color)
        item.Anchored = true
        
        -- Position items in a line
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            item.Position = player.Character.HumanoidRootPart.Position + Vector3.new(5 * i, 0, 5)
        else
            item.Position = Vector3.new(5 * i, 5, 5)
        end
        
        item.Parent = workspace
        
        -- Add purchase data
        item:SetAttribute("Purchasable", true)
        item:SetAttribute("ItemName", itemData.name)
        item:SetAttribute("ItemPrice", itemData.price)
        item:SetAttribute("Category", "Building")
        
        table.insert(items, item)
        print("✅ Created test item:", item.Name, "- Price:", itemData.price)
    end
    
    return items
end

-- Test currency display
local function testCurrencyDisplay()
    -- Try to find existing currency system
    local currentCoins = 0
    
    -- Check leaderstats
    if player:FindFirstChild("leaderstats") then
        local coinsValue = player.leaderstats:FindFirstChild("Coins") or 
                          player.leaderstats:FindFirstChild("Cash") or 
                          player.leaderstats:FindFirstChild("Money")
        if coinsValue then
            currentCoins = coinsValue.Value
            print("💰 Found player currency:", currentCoins, "coins")
        end
    end
    
    if currentCoins == 0 then
        print("⚠️ No currency found - Enhanced Purchase System will use fallback values")
    end
    
    return currentCoins
end

-- Test the integration
local function testIntegration()
    local success, integration = pcall(function()
        return require(game.StarterPlayer.StarterPlayerScripts.interaction.EnhancedPurchaseIntegration)
    end)
    
    if success then
        print("✅ Enhanced Purchase Integration loaded successfully")
        
        -- Enable debug mode for testing
        integration.EnableDebugMode(true)
        integration.SetProximityDistance(20) -- Larger range for testing
        
        return integration
    else
        warn("❌ Failed to load Enhanced Purchase Integration:", integration)
        return nil
    end
end

-- Run tests
local function runTests()
    print("\n=== Enhanced Purchase System Test ===")
    
    -- Test 1: Create test items
    print("\n📦 Test 1: Creating test items...")
    local testItem = createTestItem()
    local multipleItems = createMultipleTestItems()
    
    -- Test 2: Check currency
    print("\n💰 Test 2: Testing currency display...")
    local currentCoins = testCurrencyDisplay()
    
    -- Test 3: Test integration
    print("\n🔧 Test 3: Testing integration...")
    local integration = testIntegration()
    
    -- Test 4: Instructions for manual testing
    print("\n📋 Test 4: Manual testing instructions...")
    print("1. Walk near the test items (red wall, blue window, etc.)")
    print("2. You should see an '[E] Purchase' prompt appear at the top")
    print("3. Press 'E' to attempt purchase")
    print("4. If you don't have enough coins, a 'Get More Coins' popup should appear")
    print("5. Test with different items to verify pricing")
    
    -- Test 5: Cleanup function
    print("\n🧹 Test 5: Cleanup function ready...")
    local function cleanup()
        if testItem then testItem:Destroy() end
        for _, item in ipairs(multipleItems) do
            if item then item:Destroy() end
        end
        print("✅ Test items cleaned up")
    end
    
    -- Auto cleanup after 60 seconds
    spawn(function()
        wait(60)
        print("⏰ Auto-cleanup in 10 seconds...")
        wait(10)
        cleanup()
    end)
    
    -- Store cleanup function globally for manual cleanup
    _G.CleanupPurchaseTest = cleanup
    
    print("\n✅ All tests completed!")
    print("💡 To manually clean up test items, run: _G.CleanupPurchaseTest()")
    print("🎮 Now test by walking near the items and pressing 'E'!")
end

-- Wait a moment for character to load, then run tests
spawn(function()
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    wait(2) -- Additional wait for systems to load
    
    runTests()
end)

print("🔄 Enhanced Purchase System test script loaded. Tests will begin shortly...")

-- Monitor for errors and provide troubleshooting
local function monitorErrors()
    local errorCount = 0
    local lastError = ""
    
    game:GetService("LogService").MessageOut:Connect(function(message, messageType)
        if messageType == Enum.MessageType.MessageError and 
           message:find("Enhanced") then
            errorCount = errorCount + 1
            lastError = message
            
            if errorCount <= 3 then -- Don't spam
                warn("🔧 Enhanced Purchase System Error:", message)
                print("💡 Troubleshooting tips:")
                print("- Ensure scripts are placed in correct locations")
                print("- Check that ReplicatedStorage has required RemoteEvents")
                print("- Verify player has currency system")
            end
        end
    end)
end

monitorErrors() 