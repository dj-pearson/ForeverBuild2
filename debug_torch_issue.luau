-- Debug Torch Template Issue
-- This script will diagnose and fix the Torch template issue seen in the output

print("=== DEBUGGING TORCH TEMPLATE ISSUE ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Only run on client for now
if not RunService:IsClient() then
    print("❌ This debug script is for client-side only")
    return
end

local player = Players.LocalPlayer
if not player then
    print("❌ LocalPlayer not found")
    return
end

print("✅ Running on client for player:", player.Name)

-- 1. Check current template system state
print("\n🔍 CHECKING CURRENT TEMPLATE SYSTEM STATE:")

local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
if repTemplates then
    print("✅ ReplicatedStorage.ItemTemplates found with", #repTemplates:GetChildren(), "items")
    for _, item in ipairs(repTemplates:GetChildren()) do
        print("  - " .. item.Name)
    end
else
    print("❌ ReplicatedStorage.ItemTemplates not found")
end

local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    print("✅ Workspace.Items found")
    
    -- Check if Torch exists in Level_1
    local level1 = workspaceItems:FindFirstChild("Level_1")
    if level1 then
        local torch = level1:FindFirstChild("Torch")
        if torch then
            print("✅ Found Torch at:", torch:GetFullName())
            print("  Class:", torch.ClassName)
            print("  ItemId attribute:", torch:GetAttribute("ItemId"))
            print("  itemId attribute:", torch:GetAttribute("itemId"))
            
            if torch:IsA("Model") then
                print("  PrimaryPart:", torch.PrimaryPart and torch.PrimaryPart.Name or "NONE")
                print("  Children count:", #torch:GetChildren())
            end
        else
            print("❌ Torch not found in Level_1")
        end
    else
        print("❌ Level_1 folder not found")
    end
else
    print("❌ Workspace.Items not found")
end

-- 2. Test PlacementManager's GetItemTemplate
print("\n🔍 TESTING PLACEMENTMANAGER GETITEMTEMPLATE:")

local function testPlacementManager()
    local SharedModule
    local success, err = pcall(function()
        SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
    end)
    
    if not success then
        print("❌ Failed to load SharedModule:", err)
        return
    end
    
    local PlacementManager = SharedModule.PlacementManager
    if not PlacementManager then
        print("❌ PlacementManager not found in SharedModule")
        return
    end
    
    -- Create instance
    local placementInstance = PlacementManager.new()
    if not placementInstance then
        print("❌ Failed to create PlacementManager instance")
        return
    end
    
    print("✅ PlacementManager instance created")
    
    -- Test GetItemTemplate for Torch
    print("\n--- Testing GetItemTemplate('Torch') ---")
    local torchTemplate = placementInstance:GetItemTemplate("Torch")
    
    if torchTemplate then
        print("✅ SUCCESS: Found Torch template!")
        print("  Template location:", torchTemplate:GetFullName())
        print("  Template class:", torchTemplate.ClassName)
    else
        print("❌ FAILED: Torch template not found")
        
        -- Let's manually test the search logic
        print("\n--- Manual search simulation ---")
        
        -- 1. Check ReplicatedStorage.ItemTemplates
        local repTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
        if repTemplates then
            local template = repTemplates:FindFirstChild("Torch")
            if template then
                print("1. ✅ Found in ReplicatedStorage.ItemTemplates")
            else
                print("1. ❌ Not found in ReplicatedStorage.ItemTemplates")
            end
        else
            print("1. ❌ ReplicatedStorage.ItemTemplates not found")
        end
        
        -- 2. Check Workspace.Items recursively
        local workspaceItems = Workspace:FindFirstChild("Items")
        if workspaceItems then
            local function findRecursive(folder, itemId)
                for _, child in ipairs(folder:GetChildren()) do
                    -- Check ItemId attribute first
                    if child:GetAttribute("ItemId") == itemId or child:GetAttribute("itemId") == itemId then
                        return child
                    end
                    -- Check name
                    if child.Name == itemId then
                        return child
                    end
                    -- Recursive search
                    if child:IsA("Folder") then
                        local found = findRecursive(child, itemId)
                        if found then return found end
                    end
                end
                return nil
            end
            
            local found = findRecursive(workspaceItems, "Torch")
            if found then
                print("2. ✅ Found in Workspace.Items:", found:GetFullName())
            else
                print("2. ❌ Not found in Workspace.Items")
            end
        else
            print("2. ❌ Workspace.Items not found")
        end
    end
end

testPlacementManager()

-- 3. Potential fix: Ensure Torch has proper attributes
print("\n🔧 APPLYING POTENTIAL FIX:")

local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    local level1 = workspaceItems:FindFirstChild("Level_1")
    if level1 then
        local torch = level1:FindFirstChild("Torch")
        if torch then
            -- Ensure proper attributes
            if not torch:GetAttribute("ItemId") then
                torch:SetAttribute("ItemId", "Torch")
                print("✅ Added ItemId attribute to Torch")
            end
            
            if not torch:GetAttribute("itemId") then
                torch:SetAttribute("itemId", "Torch")
                print("✅ Added itemId attribute to Torch")
            end
            
            -- For Models, ensure PrimaryPart
            if torch:IsA("Model") and not torch.PrimaryPart then
                for _, child in ipairs(torch:GetDescendants()) do
                    if child:IsA("BasePart") then
                        torch.PrimaryPart = child
                        print("✅ Set PrimaryPart for Torch to:", child.Name)
                        break
                    end
                end
            end
            
            print("✅ Torch should now be findable by PlacementManager")
        end
    end
end

-- 4. Test again after fix
print("\n🧪 TESTING AFTER FIX:")
testPlacementManager()

print("\n=== DEBUG COMPLETE ===")
print("If Torch is still not found, check the PlacementManager search logic implementation.") 