-- Test Placed World Item (Should show Action Menu)
print("=== CREATING PLACED WORLD ITEM FOR ACTION MENU ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Get/create World_Items folder structure
local worldItemsFolder = workspace:FindFirstChild("World_Items")
if not worldItemsFolder then
    worldItemsFolder = Instance.new("Folder")
    worldItemsFolder.Name = "World_Items"
    worldItemsFolder.Parent = workspace
    print("✅ Created World_Items folder")
end

local placedFolder = worldItemsFolder:FindFirstChild("Placed")
if not placedFolder then
    placedFolder = Instance.new("Folder")
    placedFolder.Name = "Placed"
    placedFolder.Parent = worldItemsFolder
    print("✅ Created Placed folder")
end

-- Remove old test item
local existingTest = placedFolder:FindFirstChild("Test_Action_Menu_Cube")
if existingTest then
    existingTest:Destroy()
end

-- Create bright purple cube for action menu testing
local actionCube = Instance.new("Model")
actionCube.Name = "Test_Action_Menu_Cube"

local actionPart = Instance.new("Part")
actionPart.Name = "MainPart"
actionPart.Size = Vector3.new(6, 6, 6)
actionPart.Material = Enum.Material.Neon
actionPart.BrickColor = BrickColor.new("Bright violet")
actionPart.Anchored = true
actionPart.CanCollide = true
actionPart.Parent = actionCube

local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(255, 0, 255)
light.Brightness = 3
light.Range = 15
light.Parent = actionPart

actionCube.PrimaryPart = actionPart
actionPart.Position = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 12 + Vector3.new(-6, 3, 0)

-- Set WORLD ITEM attributes (not store item attributes)
actionCube:SetAttribute("itemId", "Fire_Cube")  -- What type of item this originally was
actionCube:SetAttribute("instanceId", "test_action_" .. math.floor(tick()))  -- Unique ID for actions
actionCube:SetAttribute("persistent", true)
actionCube:SetAttribute("priceIngame", 5)  -- Base price for calculating action costs
actionCube.Parent = placedFolder

print("✅ Created Test_Action_Menu_Cube in World_Items.Placed")
print("   Location: " .. actionCube:GetFullName())
print("   ItemID: " .. actionCube:GetAttribute("itemId"))
print("   InstanceID: " .. actionCube:GetAttribute("instanceId"))
print("\n🎯 EXPECTED BEHAVIOR:")
print("1. Look at the bright purple cube")
print("2. Should show '[E] Interact' proximity UI") 
print("3. Press E to see ACTION MENU with:")
print("   - Destroy (Cost: X)")
print("   - Clone (Cost: X)")
print("   - Rotate (Cost: X)")
print("   - Recall (Cost: X)")
print("   - Move (Cost: X)")

-- Also create a store item for comparison
local itemsFolder = workspace:FindFirstChild("Items")
if itemsFolder then
    local basicFolder = itemsFolder:FindFirstChild("Basic")
    if basicFolder then
        local glowFolder = basicFolder:FindFirstChild("Glow")
        if not glowFolder then
            glowFolder = Instance.new("Folder")
            glowFolder.Name = "Glow"
            glowFolder.Parent = basicFolder
        end
        
        -- Remove old test store item
        local existingStore = glowFolder:FindFirstChild("Test_Store_Glow_Cube")
        if existingStore then
            existingStore:Destroy()
        end
        
        -- Create store item
        local storeCube = Instance.new("Model")
        storeCube.Name = "Test_Store_Glow_Cube"
        
        local storePart = Instance.new("Part")
        storePart.Name = "MainPart"
        storePart.Size = Vector3.new(4, 4, 4)
        storePart.Material = Enum.Material.Neon
        storePart.BrickColor = BrickColor.new("Bright green")
        storePart.Anchored = true
        storePart.CanCollide = true
        storePart.Parent = storeCube
        
        local storeLight = Instance.new("PointLight")
        storeLight.Color = Color3.fromRGB(0, 255, 0)
        storeLight.Brightness = 3
        storeLight.Range = 15
        storeLight.Parent = storePart
        
        storeCube.PrimaryPart = storePart
        storePart.Position = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 12 + Vector3.new(6, 3, 0)
        
        -- Set STORE ITEM attributes
        storeCube:SetAttribute("Purchasable", true)
        storeCube:SetAttribute("priceIngame", 10)
        storeCube:SetAttribute("priceRobux", 1)
        storeCube.Parent = glowFolder
        
        print("\n✅ Also created Test_Store_Glow_Cube for comparison")
        print("   Should show '[E] Purchase' and BottomPurchasePopup")
    end
end 