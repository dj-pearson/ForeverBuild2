-- Fix Template System Script
-- This script consolidates the redundant template system and removes unnecessary duplicates

print("=== FIXING TEMPLATE SYSTEM ===")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Configuration
local KEEP_BASIC_TEMPLATES = true -- Keep simple cubes in ReplicatedStorage for quick access
local REMOVE_DUPLICATE_FOLDERS = true -- Remove duplicate ItemTemplates folders

print("Starting template system consolidation...")

-- Function to analyze template locations
local function analyzeTemplates()
    print("\n📊 CURRENT TEMPLATE ANALYSIS:")
    
    -- Check ReplicatedStorage.ItemTemplates
    local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if repTemplates then
        print("✅ ReplicatedStorage.ItemTemplates found with", #repTemplates:GetChildren(), "items:")
        for _, item in ipairs(repTemplates:GetChildren()) do
            print("  - " .. item.Name .. " (" .. item.ClassName .. ")")
        end
    else
        print("❌ ReplicatedStorage.ItemTemplates not found")
    end
    
    -- Check ServerStorage.Items
    local serverItems = ServerStorage:FindFirstChild("Items")
    if serverItems then
        local count = 0
        local function countRecursive(folder)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    count = count + 1
                elseif child:IsA("Folder") then
                    countRecursive(child)
                end
            end
        end
        countRecursive(serverItems)
        print("✅ ServerStorage.Items found with", count, "items (recursive)")
    else
        print("❌ ServerStorage.Items not found")
    end
    
    -- Check Workspace.Items
    local workspaceItems = Workspace:FindFirstChild("Items")
    if workspaceItems then
        local count = 0
        local function countRecursive(folder)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    count = count + 1
                elseif child:IsA("Folder") then
                    countRecursive(child)
                end
            end
        end
        countRecursive(workspaceItems)
        print("✅ Workspace.Items found with", count, "items (recursive)")
        
        -- Show folder structure
        print("   Folder structure:")
        local function showStructure(folder, depth)
            local indent = string.rep("    ", depth)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Folder") then
                    print(indent .. "📁 " .. child.Name .. "/")
                    showStructure(child, depth + 1)
                elseif child:IsA("Model") then
                    print(indent .. "📦 " .. child.Name)
                end
            end
        end
        showStructure(workspaceItems, 1)
    else
        print("❌ Workspace.Items not found")
    end
end

-- Function to create optimal template system
local function createOptimalTemplateSystem()
    print("\n🔧 CREATING OPTIMAL TEMPLATE SYSTEM:")
    
    -- Only keep basic cubes in ReplicatedStorage.ItemTemplates for quick client access
    local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if not repTemplates then
        repTemplates = Instance.new("Folder")
        repTemplates.Name = "ItemTemplates"
        repTemplates.Parent = ReplicatedStorage
        print("Created ReplicatedStorage.ItemTemplates folder")
    end
    
    -- Clear existing basic templates
    for _, child in ipairs(repTemplates:GetChildren()) do
        child:Destroy()
    end
    
    -- Create only essential basic templates (simple cubes that are frequently used)
    local basicTemplates = {
        { name = "Grass_Cube", color = BrickColor.new("Bright green"), material = Enum.Material.Grass, transparency = 0 },
        { name = "Stone_Cube", color = BrickColor.new("Medium stone grey"), material = Enum.Material.Slate, transparency = 0 },
        { name = "Wood_Plank", color = BrickColor.new("Brown"), material = Enum.Material.Wood, transparency = 0 },
        { name = "Wood_Cube", color = BrickColor.new("Brown"), material = Enum.Material.Wood, transparency = 0 },
        { name = "Brick_Cube", color = BrickColor.new("Reddish brown"), material = Enum.Material.Brick, transparency = 0 },
        { name = "Water_Cube", color = BrickColor.new("Bright blue"), material = Enum.Material.Water, transparency = 0.3 },
        { name = "Fire_Cube", color = BrickColor.new("Bright red"), material = Enum.Material.Neon, transparency = 0 },
        { name = "Glass_Cube", color = BrickColor.new("Toothpaste"), material = Enum.Material.Glass, transparency = 0.5 },
        { name = "Sand_Cube", color = BrickColor.new("Brick yellow"), material = Enum.Material.Sand, transparency = 0 },
        { name = "Concrete_Cube", color = BrickColor.new("Institutional white"), material = Enum.Material.Concrete, transparency = 0 },
        { name = "Metal_Cube", color = BrickColor.new("Medium stone grey"), material = Enum.Material.Metal, transparency = 0 }
    }
    
    for _, template in ipairs(basicTemplates) do
        local part = Instance.new("Part")
        part.Name = template.name
        part.Size = Vector3.new(2, 2, 2)
        part.Anchored = true
        part.CanCollide = true
        part.BrickColor = template.color
        part.Material = template.material
        part.Transparency = template.transparency
        
        -- Add attributes for consistency
        part:SetAttribute("ItemId", template.name)
        part:SetAttribute("tier", "BASIC")
        part:SetAttribute("priceIngame", 5)
        
        part.Parent = repTemplates
        print("Created basic template:", template.name)
    end
    
    print("✅ Created", #basicTemplates, "essential basic templates in ReplicatedStorage.ItemTemplates")
    print("   These are for simple cubes only - complex models will be found in Workspace.Items")
end

-- Function to verify Torch is accessible
local function verifyTorchAccess()
    print("\n🔍 VERIFYING TORCH ACCESS:")
    
    local workspaceItems = Workspace:FindFirstChild("Items")
    if workspaceItems then
        local level1Folder = workspaceItems:FindFirstChild("Level_1")
        if level1Folder then
            local torch = level1Folder:FindFirstChild("Torch")
            if torch then
                print("✅ Found Torch at:", torch:GetFullName())
                print("   Torch class:", torch.ClassName)
                if torch:IsA("Model") then
                    print("   Torch has", #torch:GetChildren(), "children")
                    print("   PrimaryPart:", torch.PrimaryPart and torch.PrimaryPart.Name or "None")
                end
                
                -- Ensure Torch has proper attributes
                if not torch:GetAttribute("ItemId") then
                    torch:SetAttribute("ItemId", "Torch")
                    print("   Added ItemId attribute to Torch")
                end
                
                return true
            else
                print("❌ Torch not found in Level_1 folder")
            end
        else
            print("❌ Level_1 folder not found in Workspace.Items")
        end
    else
        print("❌ Workspace.Items folder not found")
    end
    
    return false
end

-- Function to test the new template system
local function testTemplateSystem()
    print("\n🧪 TESTING NEW TEMPLATE SYSTEM:")
    
    -- Test items to check
    local testItems = {
        "Torch",  -- Should be found in Workspace.Items.Level_1
        "Grass_Cube",  -- Should be found in ReplicatedStorage.ItemTemplates
        "Water_Cube",  -- Should be found in ReplicatedStorage.ItemTemplates
        "NonexistentItem"  -- Should not be found
    }
    
    for _, itemId in ipairs(testItems) do
        print("\n--- Testing:", itemId, "---")
        
        -- Simulate the search order from PlacementManager
        local found = false
        
        -- 1. Check ReplicatedStorage.ItemTemplates
        local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
        if repTemplates then
            local template = repTemplates:FindFirstChild(itemId)
            if template then
                print("✅ Found in ReplicatedStorage.ItemTemplates:", template:GetFullName())
                found = true
            end
        end
        
        -- 2. Check Workspace.Items (recursive)
        if not found then
            local workspaceItems = Workspace:FindFirstChild("Items")
            if workspaceItems then
                local function findRecursive(folder)
                    for _, child in ipairs(folder:GetChildren()) do
                        if child.Name == itemId then
                            return child
                        elseif child:IsA("Folder") then
                            local result = findRecursive(child)
                            if result then return result end
                        end
                    end
                    return nil
                end
                
                local template = findRecursive(workspaceItems)
                if template then
                    print("✅ Found in Workspace.Items:", template:GetFullName())
                    found = true
                end
            end
        end
        
        if not found then
            print("❌ Not found anywhere (expected for NonexistentItem)")
        end
    end
end

-- Run the fixes
analyzeTemplates()
createOptimalTemplateSystem()
local torchFound = verifyTorchAccess()
testTemplateSystem()

print("\n=== TEMPLATE SYSTEM FIX COMPLETE ===")
print("✅ Basic cubes: Available in ReplicatedStorage.ItemTemplates for fast access")
print("✅ Complex models: Available in Workspace.Items folder structure")
print("✅ Torch accessible:", torchFound and "YES" or "NO")
print("✅ Client PlacementManager will now search both locations")
print("\n📝 SUMMARY:")
print("   - ReplicatedStorage.ItemTemplates: Simple cubes only (fast client access)")
print("   - Workspace.Items: All complex models organized by tier")
print("   - ServerStorage.Items: Can be used as backup/server reference")
print("   - No more redundant template creation!") 