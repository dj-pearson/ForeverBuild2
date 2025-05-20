-- ADAPT_INTERACTION_MODULE_TO_ITEMS.lua
-- This script modifies the interaction system to work with the existing Items folder
-- Run this script in the Command Bar of Roblox Studio after installing the fixed module

print("====== ADAPTING INTERACTION MODULE TO ITEMS FOLDER ======")
print("This script will modify the interaction system to work with your Items folder.")

-- Check if the InteractionSystemModule is available
if not _G.InteractionSystem then
    warn("InteractionSystemModule not found in _G. Please run INSTALL_FIXED_INTERACTION_MODULE_ROBLOX_UPDATED.lua first.")
    return
end

-- Store the original getClosestInteractable function
local originalGetClosestInteractable = _G.InteractionSystem.getClosestInteractable

-- Override the getClosestInteractable function to check Items folder
_G.InteractionSystem.getClosestInteractable = function()
    -- First try the original function to maintain compatibility
    local originalResult = originalGetClosestInteractable()
    if originalResult then
        return originalResult
    end
    
    -- If no result from original function, check the Items folder
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local characterPosition = character.HumanoidRootPart.Position
    local MAX_INTERACTION_DISTANCE = 10 -- Same as in the original module
    local closestItem = nil
    local closestDistance = MAX_INTERACTION_DISTANCE
    
    -- Function to scan for nearby items
    local function scanFolder(folder)
        for _, item in pairs(folder:GetChildren()) do
            -- Check if it's a Model or BasePart
            if item:IsA("Model") or item:IsA("BasePart") then
                -- Calculate position
                local position = nil
                if item:IsA("Model") then
                    if item.PrimaryPart then
                        position = item.PrimaryPart.Position
                    else
                        -- Try to find a part to use
                        for _, part in pairs(item:GetDescendants()) do
                            if part:IsA("BasePart") then
                                position = part.Position
                                break
                            end
                        end
                    end
                else
                    position = item.Position
                end
                
                -- Check distance if position was found
                if position then
                    local distance = (characterPosition - position).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestItem = item
                    end
                end
            end
            
            -- Recursively check children folders
            if #item:GetChildren() > 0 and item:IsA("Folder") then
                scanFolder(item)
            end
        end
    end
    
    -- Start scanning the Items folder
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        scanFolder(itemsFolder)
    end
    
    return closestItem
end

-- Override the isInteractable function to work with Items
_G.InteractionSystem.isInteractable = function(object)
    -- Check original method (with Interactable attribute)
    if object:GetAttribute("Interactable") == true then
        return true
    end
    
    -- Check if item is in Items folder or a descendant
    local current = object
    while current and current ~= workspace do
        if current.Name == "Items" and current.Parent == workspace then
            return true
        end
        current = current.Parent
    end
    
    -- Not found in Items folder
    return false
end

-- Override the interact function to handle items without specific attributes
local originalInteract = _G.InteractionSystem.interact
_G.InteractionSystem.interact = function(object)
    -- If the item has the interaction attributes, use the original function
    if object:GetAttribute("Interactable") == true and object:GetAttribute("InteractionType") then
        return originalInteract(object)
    end
    
    -- For items in the Items folder without attributes, display UI for interaction
    print("Interacting with item:", object:GetFullName())
    
    -- Create a simple UI to demonstrate the interaction
    local player = game.Players.LocalPlayer
    
    -- Check for existing UI and remove it
    if player.PlayerGui:FindFirstChild("ItemInteractionUI") then
        player.PlayerGui.ItemInteractionUI:Destroy()
    end
    
    -- Create a UI for interaction
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ItemInteractionUI"
    screenGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 200)
    frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Text = "Interact with " .. object.Name
    title.Parent = frame
    
    -- Add buttons for different interaction types
    local buyButton = Instance.new("TextButton")
    buyButton.Position = UDim2.new(0.5, -100, 0.4, 0)
    buyButton.Size = UDim2.new(0, 200, 0, 40)
    buyButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    buyButton.TextSize = 16
    buyButton.Font = Enum.Font.GothamSemibold
    buyButton.Text = "Buy (100 coins)"
    buyButton.Parent = frame
    
    buyButton.MouseButton1Click:Connect(function()
        print("Player wants to buy", object.Name)
        -- Here you would add your purchase logic
        screenGui:Destroy()
    end)
    
    local customizeButton = Instance.new("TextButton")
    customizeButton.Position = UDim2.new(0.5, -100, 0.6, 0)
    customizeButton.Size = UDim2.new(0, 200, 0, 40)
    customizeButton.BackgroundColor3 = Color3.fromRGB(70, 150, 70)
    customizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    customizeButton.TextSize = 16
    customizeButton.Font = Enum.Font.GothamSemibold
    customizeButton.Text = "Customize"
    customizeButton.Parent = frame
    
    customizeButton.MouseButton1Click:Connect(function()
        print("Player wants to customize", object.Name)
        -- Here you would add your customize logic
        screenGui:Destroy()
    end)
    
    local closeButton = Instance.new("TextButton")
    closeButton.Position = UDim2.new(1, -30, 0, 5)
    closeButton.Size = UDim2.new(0, 25, 0, 25)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 14
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.Parent = frame
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    screenGui.Parent = player.PlayerGui
end

print("Modified interaction system to work with Items folder.")
print("Now you can interact with items in the Items folder without moving them.")
print("To test:")
print("1. Play the game")
print("2. Approach an item in the Items folder")
print("3. Press E to interact with it")
print("\nIf you need to revert to the original behavior, just reload the module with INSTALL_FIXED_INTERACTION_MODULE_ROBLOX_UPDATED.lua")
