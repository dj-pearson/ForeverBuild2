-- Test Torch Placement Script
-- This script tests if the Torch item can be found and used for placement

print("=== TESTING TORCH PLACEMENT ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found - test only works in game")
    return
end

print("✅ Player found:", player.Name)

-- Test 1: Check if Torch exists in workspace
print("\n🔍 TEST 1: Checking if Torch exists in workspace")
local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    local level1Folder = workspaceItems:FindFirstChild("Level_1")
    if level1Folder then
        local torch = level1Folder:FindFirstChild("Torch")
        if torch then
            print("✅ Found Torch at:", torch:GetFullName())
            print("   Torch type:", torch.ClassName)
            if torch:IsA("Model") then
                print("   Torch children:", #torch:GetChildren())
                print("   Has PrimaryPart:", torch.PrimaryPart and "YES" or "NO")
                if torch.PrimaryPart then
                    print("   PrimaryPart name:", torch.PrimaryPart.Name)
                end
            end
        else
            print("❌ Torch not found in Level_1 folder")
        end
    else
        print("❌ Level_1 folder not found")
    end
else
    print("❌ Workspace.Items folder not found")
end

-- Test 2: Test PlacementManager template finding
print("\n🔍 TEST 2: Testing PlacementManager template finding")

-- Try to load PlacementManager
local SharedModule
local PlacementManager

local success, err = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
    PlacementManager = SharedModule.PlacementManager
end)

if success and PlacementManager then
    print("✅ PlacementManager loaded successfully")
    
    -- Create a new PlacementManager instance (client-side)
    local placementInstance = PlacementManager.new()
    if placementInstance then
        print("✅ PlacementManager instance created")
        
        -- Test GetItemTemplate for Torch
        print("\n--- Testing GetItemTemplate for 'Torch' ---")
        local torchTemplate = placementInstance:GetItemTemplate("Torch")
        if torchTemplate then
            print("✅ Found Torch template:", torchTemplate:GetFullName())
            print("   Template type:", torchTemplate.ClassName)
            if torchTemplate:IsA("Model") then
                print("   Template children:", #torchTemplate:GetChildren())
            end
        else
            print("❌ Torch template not found")
        end
        
        -- Test other items for comparison
        print("\n--- Testing GetItemTemplate for 'Grass_Cube' ---")
        local grassTemplate = placementInstance:GetItemTemplate("Grass_Cube")
        if grassTemplate then
            print("✅ Found Grass_Cube template:", grassTemplate:GetFullName())
        else
            print("❌ Grass_Cube template not found")
        end
        
    else
        print("❌ Failed to create PlacementManager instance")
    end
else
    print("❌ Failed to load PlacementManager:", err)
end

-- Test 3: Test inventory interaction
print("\n🔍 TEST 3: Testing inventory interaction with Torch")

-- Check if player has Torch in inventory
local character = player.Character
if character then
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        print("✅ Player character ready for testing")
        
        -- Try to get inventory
        local GetInventory = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("GetInventory")
        if GetInventory then
            local success, result = pcall(function()
                return GetInventory:InvokeServer()
            end)
            
            if success and result and result.items then
                print("✅ Got inventory with", #result.items, "items")
                
                -- Check if Torch is in inventory
                local hasTorch = false
                for _, item in ipairs(result.items) do
                    if item.itemId == "Torch" or item.name == "Torch" then
                        hasTorch = true
                        print("✅ Found Torch in inventory:", item.name or item.itemId)
                        break
                    end
                end
                
                if not hasTorch then
                    print("ℹ️ Torch not in inventory - this is normal if you haven't purchased it yet")
                end
            else
                print("⚠️ Could not get inventory:", result)
            end
        else
            print("❌ GetInventory RemoteFunction not found")
        end
        
    else
        print("❌ HumanoidRootPart not found")
    end
else
    print("❌ Player character not found")
end

-- Test 4: Manual template search simulation
print("\n🔍 TEST 4: Manual template search simulation")

local function findTemplateRecursive(folder, itemId)
    for _, child in ipairs(folder:GetChildren()) do
        -- First check if this item has an ItemId attribute that matches
        if child:GetAttribute("ItemId") == itemId or child:GetAttribute("itemId") == itemId then
            return child
        end
        -- Fallback to name matching for backward compatibility
        if child.Name == itemId then
            return child
        end
        -- Recursively search subfolders
        if child:IsA("Folder") then
            local found = findTemplateRecursive(child, itemId)
            if found then return found end
        end
    end
    return nil
end

print("--- Simulating PlacementManager search order for 'Torch' ---")

-- 1. Check ReplicatedStorage.ItemTemplates
local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
local foundTemplate = nil

if repTemplates then
    foundTemplate = repTemplates:FindFirstChild("Torch")
    if foundTemplate then
        print("1. ✅ Found in ReplicatedStorage.ItemTemplates")
    else
        print("1. ❌ Not found in ReplicatedStorage.ItemTemplates")
    end
else
    print("1. ❌ ReplicatedStorage.ItemTemplates not found")
end

-- 2. Check Workspace.Items (recursive)
if not foundTemplate and workspaceItems then
    foundTemplate = findTemplateRecursive(workspaceItems, "Torch")
    if foundTemplate then
        print("2. ✅ Found in Workspace.Items:", foundTemplate:GetFullName())
    else
        print("2. ❌ Not found in Workspace.Items")
    end
end

-- 3. Check ServerStorage.Items (won't work on client, but simulate)
if not foundTemplate then
    print("3. ❌ Cannot check ServerStorage.Items from client (normal)")
end

if foundTemplate then
    print("\n🎉 SUCCESS: Torch template found and should work for placement!")
else
    print("\n💥 FAILURE: Torch template not found - needs investigation")
end

print("\n=== TORCH PLACEMENT TEST COMPLETE ===") 