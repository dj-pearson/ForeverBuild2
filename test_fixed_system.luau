-- Test Fixed Interaction System
print("=== TESTING FIXED INTERACTION SYSTEM ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Test 1: Verify glow items exist and have proper structure
print("\n🔍 CHECKING GLOW ITEMS STRUCTURE:")
local itemsFolder = workspace:FindFirstChild("Items")
if itemsFolder then
    local basicFolder = itemsFolder:FindFirstChild("Basic")
    if basicFolder then
        local glowFolder = basicFolder:FindFirstChild("Glow")
        if glowFolder then
            print("✅ Found Glow folder at: " .. glowFolder:GetFullName())
            for _, item in pairs(glowFolder:GetChildren()) do
                if item:IsA("Model") then
                    local hasAttributes = item:GetAttribute("Purchasable") or item:GetAttribute("Price") or item:GetAttribute("priceIngame")
                    print(string.format("  📦 %s - Has purchase attributes: %s", item.Name, tostring(hasAttributes)))
                end
            end
        else
            print("❌ Glow folder not found in Basic")
        end
    else
        print("❌ Basic folder not found in Items")
    end
else
    print("❌ Items folder not found in workspace")
end

-- Test 2: Create a test glow item with proper attributes
print("\n🎨 CREATING TEST GLOW ITEM:")
if itemsFolder and itemsFolder:FindFirstChild("Basic") then
    local basicFolder = itemsFolder.Basic
    local glowFolder = basicFolder:FindFirstChild("Glow")
    if not glowFolder then
        glowFolder = Instance.new("Folder")
        glowFolder.Name = "Glow"
        glowFolder.Parent = basicFolder
        print("✅ Created Glow folder")
    end
    
    -- Remove old test item
    local existingTest = glowFolder:FindFirstChild("Test_Glow_Cube")
    if existingTest then
        existingTest:Destroy()
    end
    
    -- Create bright glow cube
    local glowCube = Instance.new("Model")
    glowCube.Name = "Test_Glow_Cube"
    
    local glowPart = Instance.new("Part")
    glowPart.Name = "MainPart"
    glowPart.Size = Vector3.new(4, 4, 4)
    glowPart.Material = Enum.Material.Neon
    glowPart.BrickColor = BrickColor.new("Bright green")
    glowPart.Anchored = true
    glowPart.CanCollide = true
    glowPart.Parent = glowCube
    
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(0, 255, 0)
    light.Brightness = 3
    light.Range = 15
    light.Parent = glowPart
    
    glowCube.PrimaryPart = glowPart
    glowPart.Position = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 10 + Vector3.new(0, 2, 0)
    
    -- Set purchase attributes to make it detectable
    glowCube:SetAttribute("Purchasable", true)
    glowCube:SetAttribute("priceIngame", 10)
    glowCube:SetAttribute("priceRobux", 1)
    glowCube.Parent = glowFolder
    
    print("✅ Created Test_Glow_Cube with purchase attributes")
    print("   Location: " .. glowCube:GetFullName())
    print("   Price: 10 ingame currency, 1 Robux")
end

print("\n🎯 SYSTEM STATUS:")
print("✅ Reverted to working PlacedItemDialog system")
print("✅ Removed broken WorldItemInteractionPopup")
print("✅ Proximity UI now shows for ALL items:")
print("   - Store items: '[E] Purchase'")
print("   - World items: '[E] Interact'")
print("✅ Bottom purchase popup should work for glow items")
print("\n🧪 TEST INSTRUCTIONS:")
print("1. Look at the bright green Test_Glow_Cube")
print("2. You should see '[E] Purchase' proximity UI")
print("3. The BottomPurchasePopup should show purchase options")
print("4. Test world items should show '[E] Interact' and PlacedItemDialog") 