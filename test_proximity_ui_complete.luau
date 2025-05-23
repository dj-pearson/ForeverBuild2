-- Test Complete Proximity UI System
print("=== TESTING COMPLETE PROXIMITY UI SYSTEM ===")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Detect current input method
local function getCurrentInputMethod()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile/Tablet"
    elseif UserInputService.GamepadEnabled then
        return "Console/Gamepad"
    else
        return "PC/Keyboard"
    end
end

print("🎮 Current Input Method: " .. getCurrentInputMethod())

-- Create test setup
local worldItemsFolder = workspace:FindFirstChild("World_Items") or Instance.new("Folder")
worldItemsFolder.Name = "World_Items"
worldItemsFolder.Parent = workspace

local placedFolder = worldItemsFolder:FindFirstChild("Placed") or Instance.new("Folder")
placedFolder.Name = "Placed"
placedFolder.Parent = worldItemsFolder

-- Clean up old test items
for _, item in pairs(placedFolder:GetChildren()) do
    if item.Name:find("Test_") then
        item:Destroy()
    end
end

-- Create multiple test items at different distances
local testItems = {
    {name = "Test_Close_Item", distance = 8, color = "Bright red", position = Vector3.new(-4, 2, 0)},
    {name = "Test_Medium_Item", distance = 15, color = "Bright blue", position = Vector3.new(0, 2, 0)},
    {name = "Test_Far_Item", distance = 25, color = "Bright green", position = Vector3.new(4, 2, 0)}
}

for i, itemData in ipairs(testItems) do
    local testItem = Instance.new("Model")
    testItem.Name = itemData.name
    
    local part = Instance.new("Part")
    part.Name = "MainPart"
    part.Size = Vector3.new(4, 4, 4)
    part.Material = Enum.Material.Neon
    part.BrickColor = BrickColor.new(itemData.color)
    part.Anchored = true
    part.CanCollide = true
    part.Parent = testItem
    
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 10
    light.Parent = part
    
    testItem.PrimaryPart = part
    part.Position = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * itemData.distance + itemData.position
    
    -- Set proper world item attributes
    testItem:SetAttribute("itemId", "Test_Cube")
    testItem:SetAttribute("instanceId", "test_" .. i .. "_" .. math.floor(tick()))
    testItem:SetAttribute("persistent", true)
    testItem:SetAttribute("priceIngame", 5)
    testItem.Parent = placedFolder
    
    print(string.format("✅ Created %s at distance %d", itemData.name, itemData.distance))
end

-- Also test store item for comparison
local itemsFolder = workspace:FindFirstChild("Items")
if itemsFolder then
    local basicFolder = itemsFolder:FindFirstChild("Basic") or Instance.new("Folder")
    basicFolder.Name = "Basic"
    basicFolder.Parent = itemsFolder
    
    local existingStore = basicFolder:FindFirstChild("Test_Store_Item")
    if existingStore then existingStore:Destroy() end
    
    local storeItem = Instance.new("Model")
    storeItem.Name = "Test_Store_Item"
    
    local storePart = Instance.new("Part")
    storePart.Name = "MainPart"
    storePart.Size = Vector3.new(3, 3, 3)
    storePart.Material = Enum.Material.Neon
    storePart.BrickColor = BrickColor.new("Bright yellow")
    storePart.Anchored = true
    storePart.CanCollide = true
    storePart.Parent = storeItem
    
    local storeLight = Instance.new("PointLight")
    storeLight.Color = Color3.fromRGB(255, 255, 0)
    storeLight.Brightness = 2
    storeLight.Range = 10
    storeLight.Parent = storePart
    
    storeItem.PrimaryPart = storePart
    storePart.Position = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 12 + Vector3.new(8, 2, 0)
    
    -- Set store item attributes
    storeItem:SetAttribute("Purchasable", true)
    storeItem:SetAttribute("priceIngame", 10)
    storeItem:SetAttribute("priceRobux", 1)
    storeItem.Parent = basicFolder
    
    print("✅ Created Test_Store_Item for comparison")
end

print("\n🎯 EXPECTED BEHAVIOR:")
print("1. Walk close to the RED cube (8 units away)")
print("   → Should show proximity UI above it with device-appropriate text:")
print("   → PC: '[E] Interact'")
print("   → Console: '[X] Interact'") 
print("   → Mobile: '[TAP] Interact'")
print("2. Press the indicated button to see ACTION MENU")
print("3. Walk close to YELLOW cube (store item)")
print("   → Should show '[BUTTON] Purchase' and purchase popup")
print("4. BLUE and GREEN cubes test different distances")

print("\n📏 INTERACTION DISTANCES:")
print("- Red cube: 8 units (should show UI when close)")
print("- Blue cube: 15 units (should show UI when very close)")
print("- Green cube: 25 units (too far - no UI)")
print("- Max interaction distance: 10 units")

print("\n🎨 UI FEATURES:")
print("✅ Enhanced visual design with gradient and glow")
print("✅ Device-appropriate input prompts")
print("✅ Positioned 4 studs above items")
print("✅ Subtle pulsing animation")
print("✅ Better text readability with stroke outline") 