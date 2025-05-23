-- Test Improved Proximity Interaction System
print("=== TESTING IMPROVED PROXIMITY INTERACTION ===")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Wait for systems to initialize
task.wait(3)

-- Check if ItemInteractionClient is available
local itemClient = _G.ItemInteractionClient
if itemClient then
    print("✅ Found ItemInteractionClient in _G")
    print("   proximityEnabled:", itemClient.proximityEnabled)
    print("   maxInteractionDistance:", itemClient.maxInteractionDistance)
else
    print("❌ ItemInteractionClient not found in _G")
    return
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
                elseif item:IsA("Part") then
                    print(string.format("  🧊 %s at position %s", 
                        item.Name, tostring(item.Position)))
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

-- Test the FindNearestInteractableItem function
local function testNearestItemFunction()
    print("\n🔍 TESTING NEAREST ITEM FUNCTION:")
    
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
    
    print("✅ Player position:", hrp.Position)
    
    -- Test the function
    local nearestItem = itemClient:FindNearestInteractableItem()
    if nearestItem then
        local itemPos
        if nearestItem:IsA("Model") and nearestItem.PrimaryPart then
            itemPos = nearestItem.PrimaryPart.Position
        elseif nearestItem:IsA("Part") then
            itemPos = nearestItem.Position
        else
            itemPos = nearestItem:GetModelCFrame().Position
        end
        
        local distance = (hrp.Position - itemPos).Magnitude
        print(string.format("✅ Nearest item: %s (distance: %.2f)", nearestItem.Name, distance))
    else
        print("❌ No items found within range")
    end
end

testNearestItemFunction()

print("\n🎮 INTERACTION TEST:")
print("Instructions:")
print("1. Walk near a placed world item (Glass_Cube, Brick_Cube, etc.)")
print("2. You should see '[E] Interact' appear above the item")
print("3. Press E WITHOUT pointing your mouse at the item")
print("4. The action menu should still open!")
print("5. This proves the proximity-based interaction is working")

-- Monitor E key presses to show when the system is working
local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E then
        print("\n⌨️ E KEY PRESSED!")
        
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                print("   Player position:", hrp.Position)
                
                -- Check what the nearest item function finds
                local nearestItem = itemClient:FindNearestInteractableItem()
                if nearestItem then
                    print("   ✅ Nearest item found:", nearestItem.Name)
                else
                    print("   ❌ No nearby items (too far or none exist)")
                end
                
                -- Check current target (mouse-based)
                if itemClient.currentTarget then
                    print("   🎯 Current target (mouse):", itemClient.currentTarget.Name)
                else
                    print("   🎯 No current target (mouse not pointing at item)")
                end
            end
        end
    end
end)

-- Stop monitoring after 2 minutes
task.delay(120, function()
    connection:Disconnect()
    print("🛑 Monitoring stopped after 2 minutes")
end) 