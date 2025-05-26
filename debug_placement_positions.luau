-- Debug script to check placement positions and visibility
print("=== PLACEMENT POSITION DEBUG ===")

local Workspace = game:GetService("Workspace")

-- Check if there are placed items in the world
local worldItems = Workspace:FindFirstChild("World_Items")
if worldItems then
    local placedItems = worldItems:FindFirstChild("Placed")
    if placedItems then
        print("Found placed items folder:", placedItems:GetFullName())
        print("Number of placed items:", #placedItems:GetChildren())
        
        for i, item in ipairs(placedItems:GetChildren()) do
            print("\n--- ITEM", i, "---")
            print("Name:", item.Name)
            print("Type:", item.ClassName)
            
            if item:IsA("Model") then
                if item.PrimaryPart then
                    print("Position:", item.PrimaryPart.Position)
                    print("Size:", item.PrimaryPart.Size)
                    print("Material:", item.PrimaryPart.Material.Name)
                    print("Transparency:", item.PrimaryPart.Transparency)
                    print("CanCollide:", item.PrimaryPart.CanCollide)
                    print("Anchored:", item.PrimaryPart.Anchored)
                else
                    print("Model has no PrimaryPart")
                    local parts = {}
                    for _, child in ipairs(item:GetChildren()) do
                        if child:IsA("BasePart") then
                            table.insert(parts, child)
                        end
                    end
                    if #parts > 0 then
                        print("First part position:", parts[1].Position)
                        print("First part size:", parts[1].Size)
                        print("First part material:", parts[1].Material.Name)
                        print("First part transparency:", parts[1].Transparency)
                    end
                end
            elseif item:IsA("BasePart") then
                print("Position:", item.Position)
                print("Size:", item.Size)
                print("Material:", item.Material.Name)
                print("Transparency:", item.Transparency)
                print("CanCollide:", item.CanCollide)
                print("Anchored:", item.Anchored)
            end
            
            -- Check attributes
            print("Attributes:")
            for attributeName, attributeValue in pairs(item:GetAttributes()) do
                print("  " .. attributeName .. ":", attributeValue)
            end
            
            -- Check if item is at origin (might be a bug)
            local position
            if item:IsA("Model") and item.PrimaryPart then
                position = item.PrimaryPart.Position
            elseif item:IsA("BasePart") then
                position = item.Position
            end
            
            if position then
                local distance = position.Magnitude
                if distance < 1 then
                    print("⚠️  WARNING: Item is very close to origin (0,0,0)!")
                end
                
                if position.Y < -100 then
                    print("⚠️  WARNING: Item is placed very low (Y < -100)!")
                end
                
                if position.Y > 1000 then
                    print("⚠️  WARNING: Item is placed very high (Y > 1000)!")
                end
            end
        end
    else
        print("❌ No Placed folder found in World_Items")
    end
else
    print("❌ No World_Items folder found in Workspace")
end

-- Also check the legacy PlacedItems folder
local legacyPlacedItems = Workspace:FindFirstChild("PlacedItems")
if legacyPlacedItems then
    print("\n=== LEGACY PLACED ITEMS ===")
    print("Number of legacy placed items:", #legacyPlacedItems:GetChildren())
    
    for i, item in ipairs(legacyPlacedItems:GetChildren()) do
        print("Legacy item", i, ":", item.Name)
        if item:IsA("BasePart") then
            print("  Position:", item.Position)
        elseif item:IsA("Model") and item.PrimaryPart then
            print("  Position:", item.PrimaryPart.Position)
        end
    end
end

-- Check player's camera position for reference
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
    print("\n=== PLAYER REFERENCE ===")
    print("Player position:", player.Character.HumanoidRootPart.Position)
    
    local camera = Workspace.CurrentCamera
    if camera then
        print("Camera position:", camera.CFrame.Position)
        print("Camera look direction:", camera.CFrame.LookVector)
    end
end

print("\n=== DIAGNOSIS ===")
print("If items are placed but not visible, check:")
print("1. Items might be at (0,0,0) origin")
print("2. Items might be underground (negative Y)")
print("3. Items might be too far away")
print("4. Items might be transparent")
print("5. Items might be too small to see")
print("6. Player might be looking in wrong direction") 