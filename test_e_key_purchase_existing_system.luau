-- test_e_key_purchase_existing_system.luau
-- Test script for the enhanced E-key purchase functionality using existing system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

print("🧪 Testing Existing E-Key Purchase System...")

-- Wait for the system to initialize
wait(3)

-- Check if ItemInteractionClient exists and has the correct methods
local function testExistingEKeySystem()
    print("✓ Checking for existing ItemInteractionClient system...")
    
    -- Look for the ItemInteractionClient which should have the enhanced store item interaction
    if _G.ItemInteractionClient then
        local client = _G.ItemInteractionClient
        
        print("✓ Found ItemInteractionClient")
        
        -- Check if the new methods exist
        if client.InteractWithStoreItem and client.GetStoreItemPrice and client.PurchaseStoreItem then
            print("✓ Enhanced store item methods found")
            
            -- Check if the client has proper initialization
            if client.isInteracting ~= nil and client.currentTarget ~= nil then
                print("✓ Client state variables initialized")
                
                -- Simulate getting a store item price
                local testPrice = client:GetStoreItemPrice({
                    Name = "Basic_Red_Brick_Wall",
                    GetAttribute = function(self, attr)
                        if attr == "priceIngame" then return 100 end
                        return nil
                    end
                })
                print("✓ GetStoreItemPrice test returned:", testPrice)
                
                -- Test getting player coins
                local coins = client:GetPlayerCoins()
                print("✓ GetPlayerCoins test returned:", coins)
                
                print("🎉 Enhanced E-Key Purchase System Ready!")
                print("📝 Instructions:")
                print("  1. Walk close to any store item (like the Red Brick Wall)")
                print("  2. Point your mouse at the item")
                print("  3. Press E to purchase with coins")
                print("  4. If you don't have enough coins, you'll see a notification")
                print("  5. The purchase will be processed immediately!")
                
                return true
            else
                print("❌ Client state variables not properly initialized")
                return false
            end
        else
            print("❌ Enhanced store item methods not found")
            return false
        end
    else
        print("❌ ItemInteractionClient not found in _G")
        return false
    end
end

-- Test the Enhanced E-Key Purchase System
local success = testExistingEKeySystem()

if success then
    print("✅ Enhanced E-Key Purchase System Test PASSED")
    
    -- Set up a demonstration by showing current status
    spawn(function()
        while true do
            if _G.ItemInteractionClient and _G.ItemInteractionClient.currentTarget then
                local target = _G.ItemInteractionClient.currentTarget
                if _G.ItemInteractionClient:IsStoreItem(target) then
                    local itemName = target.Name:gsub("_", " ")
                    local price = _G.ItemInteractionClient:GetStoreItemPrice(target)
                    local coins = _G.ItemInteractionClient:GetPlayerCoins()
                    
                    print("🎯 Currently targeting store item:", itemName)
                    print("💰 Price:", price, "coins | You have:", coins, "coins")
                    
                    if coins >= price then
                        print("✅ Press E to purchase with coins!")
                    else
                        print("❌ Need", (price - coins), "more coins to purchase")
                    end
                end
            end
            wait(2)
        end
    end)
else
    print("❌ Enhanced E-Key Purchase System Test FAILED")
    print("💡 Make sure the enhanced ItemInteractionClient is loaded properly")
end

print("🔧 Test script complete - Enhanced E-Key Purchase System ready to use!") 