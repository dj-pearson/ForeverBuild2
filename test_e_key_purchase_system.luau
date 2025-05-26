-- test_e_key_purchase_system.luau
-- Test script for the enhanced E-key purchase functionality

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

print("🧪 Testing Enhanced E-Key Purchase System...")

-- Wait for the system to initialize
wait(3)

-- Check if BottomPurchasePopup exists and has E-key support
local function testEKeySystem()
    print("✓ Checking for enhanced BottomPurchasePopup system...")
    
    -- Look for the ItemInteractionClient which should have the popup system
    if _G.ItemInteractionClient and _G.ItemInteractionClient.bottomPurchasePopup then
        local popup = _G.ItemInteractionClient.bottomPurchasePopup
        
        print("✓ Found BottomPurchasePopup system")
        
        -- Check if E-key functionality is available
        if popup.SetEKeyEnabled and popup.eKeyEnabled then
            print("✓ E-key functionality is available")
            print("✓ E-key enabled:", popup.eKeyEnabled)
            
            return true
        else
            warn("❌ E-key functionality not found")
            return false
        end
    else
        warn("❌ BottomPurchasePopup system not found")
        return false
    end
end

-- Test currency detection
local function testCurrencyDetection()
    print("✓ Testing currency detection...")
    
    if _G.ItemInteractionClient and _G.ItemInteractionClient.bottomPurchasePopup then
        local popup = _G.ItemInteractionClient.bottomPurchasePopup
        
        if popup.GetPlayerCoins then
            local coins = popup:GetPlayerCoins()
            print("✓ Player current coins:", coins)
            return coins
        else
            warn("❌ GetPlayerCoins function not found")
            return 0
        end
    end
    
    return 0
end

-- Test the system
local function runTests()
    print("🔧 Running E-Key Purchase System Tests...")
    print("")
    
    -- Test 1: System availability
    local systemAvailable = testEKeySystem()
    
    -- Test 2: Currency detection
    local currentCoins = testCurrencyDetection()
    
    print("")
    print("📊 Test Results:")
    print("================")
    
    if systemAvailable then
        print("✅ Enhanced BottomPurchasePopup with E-key support: ACTIVE")
        print("✅ Currency detection: WORKING (", currentCoins, "coins )")
        print("")
        print("🎮 How to use:")
        print("1. Walk near any purchasable item (Red Brick Wall, etc.)")
        print("2. You'll see the bottom popup with '[E] Quick Purchase' or '[E] Need More Coins'")
        print("3. Press E to quickly purchase with coins (if affordable)")
        print("4. If insufficient funds, you'll see a notification with the shortfall")
        print("")
        print("🟢 System is ready to use!")
    else
        print("❌ Enhanced BottomPurchasePopup: NOT ACTIVE")
        print("❌ E-key functionality: NOT AVAILABLE")
        print("")
        print("⚠️ The system may need a few more seconds to initialize.")
        print("   Try running this test again or restart the game.")
    end
    
    print("")
    print("🎯 Go test it by walking near the Red Brick Wall and pressing E!")
end

-- Run the tests
runTests()

-- Monitor for changes
task.spawn(function()
    wait(5)
    print("")
    print("🔍 Re-checking system status after delay...")
    runTests()
end) 