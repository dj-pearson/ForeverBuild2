-- Fix Automatic Purchase Dialogs
-- Run this script in Roblox Studio to ensure automatic purchase dialogs work for items in Workspace.Items

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game.Workspace
local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

print("=== FIXING AUTOMATIC PURCHASE DIALOG SYSTEM ===")

-- Step 1: Ensure all glow items in Workspace.Items have correct attributes
print("\n1. UPDATING GLOW ITEM ATTRIBUTES...")
local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    local function fixGlowItems(parent, path)
        path = path or ""
        local count = 0
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Model") or item:IsA("Part") then
                if string.find(string.lower(item.Name), "glow") then
                    -- Set all required attributes for automatic purchase dialogs
                    item:SetAttribute("Interactable", true)
                    item:SetAttribute("ItemID", item.Name)
                    item:SetAttribute("Purchasable", true)
                    item:SetAttribute("Price", 75)
                    item:SetAttribute("CurrencyType", "Coins")
                    item:SetAttribute("Description", "A glowing " .. item.Name:gsub("_", " "):lower() .. " that illuminates your world.")
                    item:SetAttribute("priceIngame", 75)
                    item:SetAttribute("priceRobux", 5)
                    item:SetAttribute("Type", "catalog")
                    item:SetAttribute("Tier", "Glow")
                    
                    count = count + 1
                    print("  Fixed:", item.Name, "at", path == "" and "root" or path)
                end
            elseif item:IsA("Folder") then
                local newPath = path == "" and item.Name or (path .. "/" .. item.Name)
                count = count + fixGlowItems(item, newPath)
            end
        end
        return count
    end
    
    local fixedCount = fixGlowItems(workspaceItems)
    print("✓ Fixed", fixedCount, "glow items")
else
    print("✗ Workspace.Items not found!")
    return
end

-- Step 2: Create/fix the automatic purchase detection script
print("\n2. CREATING AUTOMATIC PURCHASE DETECTION SCRIPT...")

if not StarterPlayerScripts then
    print("✗ StarterPlayerScripts not found!")
    return
end

-- Create the LocalScript that handles automatic purchase dialogs
local autoDialogScript = StarterPlayerScripts:FindFirstChild("AutoPurchaseDialogHandler")
if autoDialogScript then
    autoDialogScript:Destroy()
    print("  Removed existing AutoPurchaseDialogHandler")
end

autoDialogScript = Instance.new("LocalScript")
autoDialogScript.Name = "AutoPurchaseDialogHandler"
autoDialogScript.Parent = StarterPlayerScripts

-- The script content
autoDialogScript.Source = [[
-- AutoPurchaseDialogHandler - Handles automatic purchase dialogs for store items
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("AutoPurchaseDialogHandler: Starting...")

-- Configuration
local PROXIMITY_DISTANCE = 10
local UPDATE_INTERVAL = 0.5
local lastUpdate = 0

-- State
local currentStoreItem = nil
local currentDialog = nil

-- Simple purchase dialog creation
local function createPurchaseDialog(item)
    local itemName = item.Name:gsub("_", " ")
    local price = item:GetAttribute("Price") or 75
    local description = item:GetAttribute("Description") or "A purchasable item"
    
    -- Remove existing dialog
    if currentDialog then
        currentDialog:Destroy()
        currentDialog = nil
    end
    
    -- Create new dialog
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoPurchaseDialog"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui
    
    -- Dialog frame
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 400, 0, 300)
    dialog.Position = UDim2.new(0.5, -200, 0.5, -150)
    dialog.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dialog.BorderSizePixel = 0
    dialog.Parent = overlay
    
    -- Dialog corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = dialog
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = itemName
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = dialog
    
    -- Description
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 80)
    desc.Position = UDim2.new(0, 10, 0, 60)
    desc.BackgroundTransparency = 1
    desc.Text = description
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.TextSize = 16
    desc.Font = Enum.Font.Gotham
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Parent = dialog
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, -20, 0, 30)
    priceLabel.Position = UDim2.new(0, 10, 0, 150)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = string.format("Price: %d Coins or 5 Robux", price)
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLabel.TextSize = 18
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.Parent = dialog
    
    -- Coins button
    local coinsButton = Instance.new("TextButton")
    coinsButton.Size = UDim2.new(0.4, 0, 0, 40)
    coinsButton.Position = UDim2.new(0.05, 0, 0, 200)
    coinsButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    coinsButton.Text = string.format("Buy with %d Coins", price)
    coinsButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    coinsButton.TextSize = 16
    coinsButton.Font = Enum.Font.GothamBold
    coinsButton.Parent = dialog
    
    local coinsCorner = Instance.new("UICorner")
    coinsCorner.CornerRadius = UDim.new(0, 6)
    coinsCorner.Parent = coinsButton
    
    -- Robux button
    local robuxButton = Instance.new("TextButton")
    robuxButton.Size = UDim2.new(0.4, 0, 0, 40)
    robuxButton.Position = UDim2.new(0.55, 0, 0, 200)
    robuxButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    robuxButton.Text = "Buy with 5 Robux"
    robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxButton.TextSize = 16
    robuxButton.Font = Enum.Font.GothamBold
    robuxButton.Parent = dialog
    
    local robuxCorner = Instance.new("UICorner")
    robuxCorner.CornerRadius = UDim.new(0, 6)
    robuxCorner.Parent = robuxButton
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = dialog
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    -- Button handlers
    local function closePurchaseDialog()
        screenGui:Destroy()
        currentDialog = nil
    end
    
    closeButton.MouseButton1Click:Connect(closePurchaseDialog)
    overlay.MouseButton1Click:Connect(closePurchaseDialog)
    
    coinsButton.MouseButton1Click:Connect(function()
        print("Attempting to purchase", item.Name, "with coins")
        -- Fire purchase request to server
        local purchaseEvent = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("PurchaseItem")
        if purchaseEvent then
            purchaseEvent:FireServer(item.Name, 1, "INGAME")
        end
        closePurchaseDialog()
    end)
    
    robuxButton.MouseButton1Click:Connect(function()
        print("Attempting to purchase", item.Name, "with Robux")
        -- Fire purchase request to server
        local purchaseEvent = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("PurchaseItem")
        if purchaseEvent then
            purchaseEvent:FireServer(item.Name, 1, "ROBUX")
        end
        closePurchaseDialog()
    end)
    
    currentDialog = screenGui
    print("AutoPurchaseDialogHandler: Showing purchase dialog for", item.Name)
end

-- Check for nearby store items
local function checkForStoreItems()
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local playerPosition = humanoidRootPart.Position
    
    -- Find Workspace.Items
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then return end
    
    -- Find closest store item
    local closestItem = nil
    local closestDistance = PROXIMITY_DISTANCE
    
    local function scanForItems(parent)
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Model") or item:IsA("Part") then
                if item:GetAttribute("Purchasable") or item:GetAttribute("Price") then
                    local itemPosition = item:GetPivot().Position
                    local distance = (itemPosition - playerPosition).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestItem = item
                    end
                end
            elseif item:IsA("Folder") then
                scanForItems(item)
            end
        end
    end
    
    scanForItems(itemsFolder)
    
    -- Handle item changes
    if closestItem ~= currentStoreItem then
        if currentDialog then
            currentDialog:Destroy()
            currentDialog = nil
        end
        
        currentStoreItem = closestItem
        
        if currentStoreItem then
            createPurchaseDialog(currentStoreItem)
        end
    end
end

-- Main update loop
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastUpdate >= UPDATE_INTERVAL then
        lastUpdate = now
        checkForStoreItems()
    end
end)

print("AutoPurchaseDialogHandler: Ready!")
]]

print("✓ Created AutoPurchaseDialogHandler script")

-- Step 3: Ensure required remote events exist
print("\n3. ENSURING REMOTE EVENTS EXIST...")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
    print("  Created Remotes folder")
end

local requiredRemotes = {
    {name = "PurchaseItem", type = "RemoteEvent"},
    {name = "GetItemData", type = "RemoteFunction"},
    {name = "IsItemAffordable", type = "RemoteFunction"}
}

for _, remoteInfo in ipairs(requiredRemotes) do
    local remote = remotes:FindFirstChild(remoteInfo.name)
    if not remote then
        if remoteInfo.type == "RemoteEvent" then
            remote = Instance.new("RemoteEvent")
        else
            remote = Instance.new("RemoteFunction")
        end
        remote.Name = remoteInfo.name
        remote.Parent = remotes
        print("  Created", remoteInfo.name, "(" .. remoteInfo.type .. ")")
    else
        print("  ✓", remoteInfo.name, "already exists")
    end
end

print("\n=== FIX COMPLETE ===")
print("✓ All components are now set up for automatic purchase dialogs")
print("✓ Test by running the game and walking close to glow items in Workspace.Items")
print("✓ Purchase dialogs should appear automatically without pressing any keys") 