-- Diagnostic Script for Purchase Dialog System
-- Run this in Roblox Studio Command Bar to diagnose why automatic purchase dialogs aren't showing

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game.Workspace

print("=== PURCHASE DIALOG SYSTEM DIAGNOSTIC ===")

-- Check 1: Workspace.Items exists and has glow items
print("\n1. CHECKING WORKSPACE.ITEMS...")
local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    print("✓ Workspace.Items exists")
    
    local function countGlowItems(parent, path)
        path = path or ""
        local count = 0
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Model") or item:IsA("Part") then
                if string.find(string.lower(item.Name), "glow") then
                    count = count + 1
                    print("  Found glow item:", item.Name, "at", path == "" and "root" or path)
                    print("    Interactable:", item:GetAttribute("Interactable"))
                    print("    Purchasable:", item:GetAttribute("Purchasable"))
                    print("    Price:", item:GetAttribute("Price"))
                    print("    ItemID:", item:GetAttribute("ItemID"))
                end
            elseif item:IsA("Folder") then
                local newPath = path == "" and item.Name or (path .. "/" .. item.Name)
                count = count + countGlowItems(item, newPath)
            end
        end
        return count
    end
    
    local glowCount = countGlowItems(workspaceItems)
    print("✓ Found", glowCount, "glow items in Workspace.Items")
else
    print("✗ Workspace.Items does not exist!")
    return
end

-- Check 2: ReplicatedStorage.shared module
print("\n2. CHECKING SHARED MODULE...")
local shared = ReplicatedStorage:FindFirstChild("shared")
if shared then
    print("✓ ReplicatedStorage.shared exists")
    local success, SharedModule = pcall(require, shared)
    if success then
        print("✓ SharedModule loads successfully")
        if SharedModule.Constants then
            print("✓ Constants available")
        else
            print("✗ Constants missing from SharedModule")
        end
    else
        print("✗ Failed to require SharedModule:", SharedModule)
    end
else
    print("✗ ReplicatedStorage.shared does not exist!")
end

-- Check 3: Remote events/functions
print("\n3. CHECKING REMOTE EVENTS...")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
    print("✓ Remotes folder exists")
    
    local requiredRemotes = {"GetItemData", "PurchaseItem", "IsItemAffordable", "InteractWithItem"}
    for _, remoteName in ipairs(requiredRemotes) do
        local remote = remotes:FindFirstChild(remoteName)
        if remote then
            print("✓", remoteName, "exists (", remote.ClassName, ")")
        else
            print("✗", remoteName, "missing!")
        end
    end
else
    print("✗ Remotes folder does not exist!")
end

-- Check 4: ItemInteractionClient system
print("\n4. CHECKING CLIENT INTERACTION SYSTEM...")
local player = Players.LocalPlayer
if player then
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        print("✓ PlayerGui exists")
        
        -- Check if ItemInteractionClient is running
        local interactionGuis = {}
        for _, gui in ipairs(playerGui:GetChildren()) do
            if string.find(gui.Name, "Interaction") or string.find(gui.Name, "Catalog") then
                table.insert(interactionGuis, gui.Name)
            end
        end
        
        if #interactionGuis > 0 then
            print("✓ Found interaction GUIs:", table.concat(interactionGuis, ", "))
        else
            print("? No interaction GUIs found in PlayerGui")
        end
    end
else
    print("✗ LocalPlayer not available (run this in game, not studio)")
end

-- Check 5: Test proximity detection manually
print("\n5. TESTING PROXIMITY DETECTION...")
if workspaceItems then
    local function findFirstGlowItem(parent)
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Model") or item:IsA("Part") then
                if string.find(string.lower(item.Name), "glow") then
                    return item
                end
            elseif item:IsA("Folder") then
                local found = findFirstGlowItem(item)
                if found then return found end
            end
        end
        return nil
    end
    
    local testItem = findFirstGlowItem(workspaceItems)
    if testItem then
        print("✓ Test item found:", testItem.Name)
        print("  Full path:", testItem:GetFullName())
        print("  IsDescendantOf Workspace.Items:", testItem:IsDescendantOf(workspaceItems))
        
        -- Test the IsStoreItem logic
        local itemsFolder = workspace:FindFirstChild("Items")
        local isStoreItem = itemsFolder and testItem:IsDescendantOf(itemsFolder)
        print("  IsStoreItem result:", isStoreItem)
    else
        print("✗ No glow items found for testing")
    end
end

-- Check 6: Look for interaction system modules
print("\n6. CHECKING INTERACTION SYSTEM MODULES...")
local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if StarterPlayerScripts then
    local function findInteractionScripts(parent, path)
        path = path or ""
        for _, script in ipairs(parent:GetChildren()) do
            if script:IsA("LocalScript") or script:IsA("ModuleScript") then
                if string.find(string.lower(script.Name), "interaction") then
                    print("  Found:", script.Name, "at", path == "" and "root" or path)
                end
            elseif script:IsA("Folder") then
                local newPath = path == "" and script.Name or (path .. "/" .. script.Name)
                findInteractionScripts(script, newPath)
            end
        end
    end
    
    print("Searching StarterPlayerScripts for interaction modules...")
    findInteractionScripts(StarterPlayerScripts)
end

print("\n=== DIAGNOSTIC COMPLETE ===")
print("\nIf any items show ✗ or issues, those need to be fixed for automatic purchase dialogs to work.")
print("The most common issues are:")
print("1. Missing or incorrectly configured remote events")
print("2. ItemInteractionClient not running or not initialized") 
print("3. Missing ShowCatalogUI function in the client")
print("4. Proximity detection not working due to missing character/camera references") 