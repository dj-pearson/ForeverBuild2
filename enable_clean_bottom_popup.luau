-- Enable Clean Bottom Popup System
-- This removes all problematic scripts and enables only the small, unobtrusive bottom popup

local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

print("=== CLEANING UP PURCHASE POPUP SYSTEM ===")

if not StarterPlayerScripts then
    print("✗ StarterPlayerScripts not found!")
    return
end

-- Remove ALL problematic purchase dialog scripts
local scriptsToRemove = {
    "AutoPurchaseDialogHandler",
    "SimplePurchaseDialogHandler", 
    "SmallBottomPurchasePopup"
}

for _, scriptName in ipairs(scriptsToRemove) do
    local script = StarterPlayerScripts:FindFirstChild(scriptName)
    if script then
        script:Destroy()
        print("✓ Removed", scriptName)
    end
end

-- Create the FINAL clean bottom popup system
local newScript = Instance.new("LocalScript")
newScript.Name = "CleanBottomPurchasePopup"
newScript.Parent = StarterPlayerScripts

newScript.Source = [[
-- Clean Bottom Purchase Popup - Just like Rare_Sofa popup in the user's screenshot
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("CleanBottomPurchasePopup: Starting...")

-- Configuration
local PROXIMITY_DISTANCE = 8
local UPDATE_INTERVAL = 0.3
local lastUpdate = 0

-- State
local currentStoreItem = nil
local currentPopup = nil

-- Create the small bottom popup (exact style from user's screenshot)
local function createBottomPurchasePopup(item)
    local itemName = item.Name:gsub("_", " ")
    local price = item:GetAttribute("Price") or item:GetAttribute("priceIngame") or 75
    local robuxPrice = item:GetAttribute("priceRobux") or 5
    
    -- Remove existing popup
    if currentPopup then
        currentPopup:Destroy()
        currentPopup = nil
    end
    
    -- Create popup container
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BottomPurchasePopup"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main popup frame (small and unobtrusive)
    local popupFrame = Instance.new("Frame")
    popupFrame.Size = UDim2.new(0, 320, 0, 100)
    popupFrame.Position = UDim2.new(0.5, -160, 1, -120) -- Bottom center
    popupFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    popupFrame.BorderSizePixel = 0
    popupFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = popupFrame
    
    -- Subtle border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = popupFrame
    
    -- Item name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 25)
    nameLabel.Position = UDim2.new(0, 5, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Parent = popupFrame
    
    -- Price label (matches screenshot style)
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, -10, 0, 15)
    priceLabel.Position = UDim2.new(0, 5, 0, 30)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = string.format("Price: 💰%d Coins or 💎%d Robux", price, robuxPrice)
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLabel.TextSize = 12
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.TextXAlignment = Enum.TextXAlignment.Center
    priceLabel.Parent = popupFrame
    
    -- Button container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -20, 0, 35)
    buttonContainer.Position = UDim2.new(0, 10, 0, 55)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = popupFrame
    
    -- Coins button (yellow like in screenshot)
    local coinsButton = Instance.new("TextButton")
    coinsButton.Size = UDim2.new(0.48, 0, 1, 0)
    coinsButton.Position = UDim2.new(0, 0, 0, 0)
    coinsButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    coinsButton.Text = string.format("💰 Buy with %d Coins", price)
    coinsButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    coinsButton.TextSize = 11
    coinsButton.Font = Enum.Font.GothamBold
    coinsButton.Parent = buttonContainer
    
    local coinsCorner = Instance.new("UICorner")
    coinsCorner.CornerRadius = UDim.new(0, 6)
    coinsCorner.Parent = coinsButton
    
    -- Robux button (green like in screenshot)
    local robuxButton = Instance.new("TextButton")
    robuxButton.Size = UDim2.new(0.48, 0, 1, 0)
    robuxButton.Position = UDim2.new(0.52, 0, 0, 0)
    robuxButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
    robuxButton.Text = string.format("💎 Buy with %d Robux", robuxPrice)
    robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxButton.TextSize = 11
    robuxButton.Font = Enum.Font.GothamBold
    robuxButton.Parent = buttonContainer
    
    local robuxCorner = Instance.new("UICorner")
    robuxCorner.CornerRadius = UDim.new(0, 6)
    robuxCorner.Parent = robuxButton
    
    -- Button click handlers
    coinsButton.MouseButton1Click:Connect(function()
        print("Purchasing", item.Name, "with", price, "coins")
        local purchaseEvent = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("PurchaseItem")
        if purchaseEvent then
            purchaseEvent:FireServer(item.Name, 1, "INGAME")
        end
        
        -- Hide popup after purchase
        if currentPopup then
            currentPopup:Destroy()
            currentPopup = nil
            currentStoreItem = nil
        end
    end)
    
    robuxButton.MouseButton1Click:Connect(function()
        print("Purchasing", item.Name, "with", robuxPrice, "Robux")
        local purchaseEvent = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("PurchaseItem")
        if purchaseEvent then
            purchaseEvent:FireServer(item.Name, 1, "ROBUX")
        end
        
        -- Hide popup after purchase
        if currentPopup then
            currentPopup:Destroy()
            currentPopup = nil
            currentStoreItem = nil
        end
    end)
    
    -- Smooth slide-in animation
    popupFrame.Position = UDim2.new(0.5, -160, 1, 20) -- Start below screen
    local slideIn = TweenService:Create(popupFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 1, -120)
    })
    slideIn:Play()
    
    currentPopup = screenGui
    print("CleanBottomPurchasePopup: Showing popup for", item.Name)
end

-- Check for nearby purchasable items
local function checkForNearbyItems()
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local playerPosition = humanoidRootPart.Position
    local closestItem = nil
    local closestDistance = PROXIMITY_DISTANCE
    
    -- Scan Items folder for purchasable items (including glow items in subfolders)
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        local function scanForItems(parent)
            for _, item in ipairs(parent:GetChildren()) do
                if item:IsA("Model") or item:IsA("Part") then
                    -- Check if item has purchase attributes
                    if item:GetAttribute("Purchasable") or item:GetAttribute("Price") or item:GetAttribute("priceIngame") then
                        local itemPosition
                        
                        -- Get position safely
                        if item:IsA("Model") and item.PrimaryPart then
                            itemPosition = item.PrimaryPart.Position
                        elseif item:IsA("Model") then
                            itemPosition = item:GetPivot().Position
                        elseif item:IsA("Part") then
                            itemPosition = item.Position
                        end
                        
                        if itemPosition then
                            local distance = (itemPosition - playerPosition).Magnitude
                            
                            if distance < closestDistance then
                                closestDistance = distance
                                closestItem = item
                            end
                        end
                    end
                elseif item:IsA("Folder") then
                    scanForItems(item) -- Recursive scan for glow items
                end
            end
        end
        
        scanForItems(itemsFolder)
    end
    
    -- Handle popup changes
    if closestItem ~= currentStoreItem then
        -- Hide current popup
        if currentPopup then
            local popupFrame = currentPopup:FindFirstChild("Frame")
            if popupFrame then
                local slideOut = TweenService:Create(popupFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, -160, 1, 20)
                })
                slideOut:Play()
                slideOut.Completed:Connect(function()
                    currentPopup:Destroy()
                    currentPopup = nil
                end)
            else
                currentPopup:Destroy()
                currentPopup = nil
            end
        end
        
        currentStoreItem = closestItem
        
        -- Show new popup if we have an item
        if currentStoreItem then
            task.wait(0.1) -- Small delay for smooth transition
            createBottomPurchasePopup(currentStoreItem)
        end
    end
end

-- Main update loop
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastUpdate >= UPDATE_INTERVAL then
        lastUpdate = now
        checkForNearbyItems()
    end
end)

print("CleanBottomPurchasePopup: Ready! Small unobtrusive popup system active.")
]]

print("✓ Created CleanBottomPurchasePopup script")
print("")
print("=== FINAL SOLUTION ===")
print("✓ Removed all problematic '[E] View' proximity popups")
print("✓ Enabled small bottom popup like Rare_Sofa in your screenshot")
print("✓ Works for glow items in subfolders (Basic > Glow)")
print("✓ Players can move freely without UI clutter")
print("✓ Automatic proximity detection")
print("✓ Smooth animations")
print("")
print("Your purchase system should now work perfectly with no screen clutter!") 