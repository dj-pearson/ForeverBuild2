-- Fix Torch Template Issue
-- This script ensures Torch can be found by PlacementManager

print("=== FIXING TORCH TEMPLATE ISSUE ===")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- 1. Ensure Torch has proper attributes in Workspace.Items.Level_1
local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    local level1 = workspaceItems:FindFirstChild("Level_1")
    if level1 then
        local torch = level1:FindFirstChild("Torch")
        if torch then
            print("✅ Found Torch at:", torch:GetFullName())
            
            -- Add ItemId attributes if missing
            if not torch:GetAttribute("ItemId") then
                torch:SetAttribute("ItemId", "Torch")
                print("✅ Added ItemId attribute")
            end
            
            if not torch:GetAttribute("itemId") then
                torch:SetAttribute("itemId", "Torch")
                print("✅ Added itemId attribute")
            end
            
            -- Ensure Model has PrimaryPart
            if torch:IsA("Model") and not torch.PrimaryPart then
                for _, child in ipairs(torch:GetDescendants()) do
                    if child:IsA("BasePart") then
                        torch.PrimaryPart = child
                        print("✅ Set PrimaryPart to:", child.Name)
                        break
                    end
                end
            end
            
            print("✅ Torch template is now properly configured")
        else
            print("❌ Torch not found in Level_1 - creating basic template")
            
            -- Create a basic Torch model if it doesn't exist
            local torchModel = Instance.new("Model")
            torchModel.Name = "Torch"
            torchModel:SetAttribute("ItemId", "Torch")
            torchModel:SetAttribute("itemId", "Torch")
            torchModel:SetAttribute("tier", "Level_1")
            torchModel:SetAttribute("priceIngame", 5)
            
            -- Create torch parts
            local handle = Instance.new("Part")
            handle.Name = "Handle"
            handle.Size = Vector3.new(0.5, 3, 0.5)
            handle.BrickColor = BrickColor.new("Brown")
            handle.Material = Enum.Material.Wood
            handle.Anchored = true
            handle.Parent = torchModel
            
            local flame = Instance.new("Part")
            flame.Name = "Flame"
            flame.Size = Vector3.new(1, 1, 1)
            flame.BrickColor = BrickColor.new("Bright red")
            flame.Material = Enum.Material.Neon
            flame.Shape = Enum.PartType.Ball
            flame.Anchored = true
            flame.CFrame = handle.CFrame + Vector3.new(0, 2, 0)
            flame.Parent = torchModel
            
            -- Add light
            local light = Instance.new("PointLight")
            light.Brightness = 2
            light.Range = 10
            light.Color = Color3.new(1, 0.5, 0)
            light.Parent = flame
            
            torchModel.PrimaryPart = handle
            torchModel.Parent = level1
            
            print("✅ Created basic Torch template")
        end
    else
        print("❌ Level_1 folder not found")
    end
else
    print("❌ Workspace.Items not found")
end

-- 2. Optionally add Torch to ReplicatedStorage.ItemTemplates for faster access
local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
if repTemplates and not repTemplates:FindFirstChild("Torch") then
    local workspaceTorch = workspaceItems and workspaceItems:FindFirstChild("Level_1") and workspaceItems.Level_1:FindFirstChild("Torch")
    if workspaceTorch then
        local torchCopy = workspaceTorch:Clone()
        torchCopy.Parent = repTemplates
        print("✅ Added Torch copy to ReplicatedStorage.ItemTemplates for faster access")
    end
end

print("=== TORCH TEMPLATE FIX COMPLETE ===")
print("Torch should now be findable by PlacementManager on both client and server") 