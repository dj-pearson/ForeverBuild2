--[[
    TEST_INTERACTION_SYSTEM.lua
    
    This script will test the InteractionSystemModule functionality.
    Run this script in the Command Bar in Roblox Studio.
]]

print("Starting Interaction System test...")

-- Locate the module
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local interactionModule = nil
local modulePath = "src/client/interaction/InteractionSystemModule"

-- First try to require it directly
local success, result = pcall(function()
    return require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("LazyLoadModules"))
end)

if success then
    print("LazyLoadModules found, trying to load InteractionSystem")
    local LazyLoadModules = result
    
    -- Register and then require the interaction module
    pcall(function()
        LazyLoadModules.register("InteractionSystem", game.ReplicatedStorage.src.client.interaction.InteractionSystemModule)
    end)
    
    success, interactionModule = pcall(function()
        return LazyLoadModules.require("InteractionSystem")
    end)
    
    if success and interactionModule then
        print("Successfully loaded InteractionSystem via LazyLoadModules")
    else
        print("Failed to load via LazyLoadModules, trying direct require")
    end
end

-- If LazyLoadModules approach failed, try direct require
if not interactionModule then
    -- Try to find the module
    local paths = {
        workspace.src,
        ReplicatedStorage.src,
        game.ServerStorage.src,
        game.ServerScriptService.src,
        workspace,
        ReplicatedStorage,
        game.ServerStorage,
        game.ServerScriptService
    }
    
    local moduleScript = nil
    
    for _, path in ipairs(paths) do
        if path then
            -- Try to find the module in client/interaction
            pcall(function()
                moduleScript = path.client.interaction.InteractionSystemModule
            end)
            
            if not moduleScript then
                -- Try to find the module in src/client/interaction
                pcall(function()
                    moduleScript = path.src.client.interaction.InteractionSystemModule
                end)
            end
            
            if moduleScript and moduleScript:IsA("ModuleScript") then
                print("Found InteractionSystemModule at: " .. moduleScript:GetFullName())
                break
            else
                moduleScript = nil
            end
        end
    end
    
    if moduleScript then
        success, interactionModule = pcall(function()
            return require(moduleScript)
        end)
        
        if success then
            print("Successfully required InteractionSystemModule directly")
        else
            warn("Failed to require module:", result)
        end
    end
end

if not interactionModule then
    warn("Could not find or load InteractionSystemModule")
    return
end

-- Create a new instance of the InteractionSystem
local interactionSystem = interactionModule.new()
print("Created new InteractionSystem instance")

-- Initialize the interaction system
local initSuccess = interactionSystem:Initialize()
if not initSuccess then
    warn("Failed to initialize InteractionSystem")
    return
end
print("InteractionSystem initialized successfully")

-- Test creating a simple item in the workspace
print("Creating test item in workspace...")
local testItem = Instance.new("Part")
testItem.Name = "TestItem"
testItem.Size = Vector3.new(4, 1, 4)
testItem.Position = Vector3.new(0, 5, 0)
testItem.Anchored = true
testItem.BrickColor = BrickColor.new("Bright blue")

-- Convert to a Model so we can add attributes
local testModel = Instance.new("Model")
testModel.Name = "TestInteractionItem"
testModel:SetAttribute("item", true)
testItem.Parent = testModel
testModel.PrimaryPart = testItem
testModel.Parent = workspace

print("Test item created. You should see a blue platform that can be interacted with.")
print("Move your mouse over it and press E to test interaction.")

-- Create remotes if they don't exist
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
    print("Created Remotes folder")
end

-- Create test remotes for interaction
local remoteNames = {
    { name = "InteractWithItem", class = "RemoteEvent" },
    { name = "PickupItem", class = "RemoteEvent" },
    { name = "CloneItem", class = "RemoteEvent" },
    { name = "GetAvailableInteractions", class = "RemoteFunction" },
    { name = "GetItemData", class = "RemoteFunction" }
}

for _, remoteInfo in ipairs(remoteNames) do
    local existing = remotes:FindFirstChild(remoteInfo.name)
    if not existing then
        local remote = Instance.new(remoteInfo.class)
        remote.Name = remoteInfo.name
        remote.Parent = remotes
        print("Created " .. remoteInfo.name)
    end
end

-- Setup test functions for the remotes
local getAvailableInteractions = remotes:FindFirstChild("GetAvailableInteractions")
if getAvailableInteractions and getAvailableInteractions:IsA("RemoteFunction") then
    getAvailableInteractions.OnServerInvoke = function(player, itemId)
        print("GetAvailableInteractions called for", itemId)
        return {"examine", "clone", "pickup"}
    end
    print("Set up GetAvailableInteractions handler")
end

local getItemData = remotes:FindFirstChild("GetItemData")
if getItemData and getItemData:IsA("RemoteFunction") then
    getItemData.OnServerInvoke = function(player, itemId)
        print("GetItemData called for", itemId)
        return {
            name = "Test " .. itemId,
            description = "This is a test item created for interaction system testing. It has a detailed description to show text wrapping.",
            price = { INGAME = 500 }
        }
    end
    print("Set up GetItemData handler")
end

local interactWithItem = remotes:FindFirstChild("InteractWithItem")
if interactWithItem and interactWithItem:IsA("RemoteEvent") then
    interactWithItem.OnServerEvent:Connect(function(player, itemId, action)
        print("InteractWithItem called: Player", player.Name, "Item", itemId, "Action", action)
    end)
    print("Set up InteractWithItem handler")
end

local pickupItem = remotes:FindFirstChild("PickupItem")
if pickupItem and pickupItem:IsA("RemoteEvent") then
    pickupItem.OnServerEvent:Connect(function(player, itemId)
        print("PickupItem called: Player", player.Name, "Item", itemId)
    end)
    print("Set up PickupItem handler")
end

local cloneItem = remotes:FindFirstChild("CloneItem")
if cloneItem and cloneItem:IsA("RemoteEvent") then
    cloneItem.OnServerEvent:Connect(function(player, itemId)
        print("CloneItem called: Player", player.Name, "Item", itemId)
        
        -- Create a clone of the item
        local original = workspace:FindFirstChild(itemId, true)
        if original and original:IsA("Model") then
            local clone = original:Clone()
            clone.Name = itemId .. "_Clone"
            
            -- Position the clone next to the original
            if clone.PrimaryPart then
                clone:SetPrimaryPartCFrame(original.PrimaryPart.CFrame * CFrame.new(6, 0, 0))
            end
            
            clone.Parent = workspace
            print("Successfully cloned item:", itemId)
        end
    end)
    print("Set up CloneItem handler")
end

print("Test setup complete! Try interacting with the blue test item by moving your mouse over it and pressing E.")
print("You should see interaction UI appear when hovering, and be able to examine or clone the item.")
print("Check the output panel to see when remote events and functions are called.")
