-- Fix Small Bottom Popup for Purchase Dialogs
-- This replaces the large modal with a small bottom-center popup that doesn't block the view

local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

print("=== FIXING PURCHASE DIALOG TO SMALL BOTTOM POPUP ===")

if not StarterPlayerScripts then
    print("✗ StarterPlayerScripts not found!")
    return
end

-- Remove existing problematic handler
local existingScript = StarterPlayerScripts:FindFirstChild("SimplePurchaseDialogHandler")
if existingScript then
    existingScript:Destroy()
    print("✓ Removed existing SimplePurchaseDialogHandler")
end

-- Create new small popup handler
local newScript = Instance.new("LocalScript")
newScript.Name = "SmallBottomPurchasePopup"
newScript.Parent = StarterPlayerScripts

newScript.Source = [[
-- Small Bottom Purchase Popup - Unobtrusive and allows free movement
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("SmallBottomPurchasePopup: Starting...")

-- Configuration
local PROXIMITY_DISTANCE = 8
local UPDATE_INTERVAL = 0.3
local lastUpdate = 0

-- State
local currentStoreItem = nil
local currentPopup = nil

-- Create small bottom popup that doesn't block the view
local function createSmallPurchasePopup(item)
    local itemName = item.Name:gsub("_", " ")
    local price = item:GetAttribute("Price") or item:GetAttribute("priceIngame") or 75
    local robuxPrice = item:GetAttribute("priceRobux") or 5
    
    -- Remove existing popup
    if currentPopup then
        currentPopup:Destroy()
        currentPopup = nil
    end
    
    -- Create small popup container
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SmallPurchasePopup"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Small popup frame at bottom center
    local popupFrame = Instance.new("Frame")
    popupFrame.Size = UDim2.new(0, 340, 0, 85)
    popupFrame.Position = UDim2.new(0.5, -170, 1, -100) -- Bottom center, slightly above bottom
    popupFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    popupFrame.BorderSizePixel = 0
    popupFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = popupFrame
    
    -- Subtle drop shadow effect
    popupFrame.BorderSizePixel = 1
    popupFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    
    -- Item name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Parent = popupFrame
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, -10, 0, 15)
    priceLabel.Position = UDim2.new(0, 5, 0, 25)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = string.format("%d Coins or %d Robux", price, robuxPrice)
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLabel.TextSize = 12
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.TextXAlignment = Enum.TextXAlignment.Center
    priceLabel.Parent = popupFrame
    
    -- Button container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -10, 0, 30)
    buttonContainer.Position = UDim2.new(0, 5, 0, 45)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = popupFrame
    
    -- Coins button
    local coinsButton = Instance.new("TextButton")
    coinsButton.Size = UDim2.new(0.48, 0, 1, 0)
    coinsButton.Position = UDim2.new(0, 0, 0, 0)
    coinsButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    coinsButton.Text = string.format("%d Coins", price)
    coinsButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    coinsButton.TextSize = 12
    coinsButton.Font = Enum.Font.GothamBold
    coinsButton.Parent = buttonContainer
    
    local coinsCorner = Instance.new("UICorner")
    coinsCorner.CornerRadius = UDim.new(0, 4)
    coinsCorner.Parent = coinsButton
    
    -- Robux button
    local robuxButton = Instance.new("TextButton")
    robuxButton.Size = UDim2.new(0.48, 0, 1, 0)
    robuxButton.Position = UDim2.new(0.52, 0, 0, 0)
    robuxButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    robuxButton.Text = string.format("%d Robux", robuxPrice)
    robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxButton.TextSize = 12
    robuxButton.Font = Enum.Font.GothamBold
    robuxButton.Parent = buttonContainer
    
    local robuxCorner = Instance.new("UICorner")
    robuxCorner.CornerRadius = UDim.new(0, 4)
    robuxCorner.Parent = robuxButton
    
    -- Button hover effects
    local function createHoverEffect(button, normalColor, hoverColor)
        local isHovering = false
        
        button.MouseEnter:Connect(function()
            isHovering = true
            local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor})
            tween:Play()
        end)
        
        button.MouseLeave:Connect(function()
            isHovering = false
            local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = normalColor})
            tween:Play()
        end)
    end
    
    createHoverEffect(coinsButton, Color3.fromRGB(255, 193, 7), Color3.fromRGB(255, 215, 50))
    createHoverEffect(robuxButton, Color3.fromRGB(0, 162, 255), Color3.fromRGB(30, 180, 255))
    
    -- Button handlers
    coinsButton.MouseButton1Click:Connect(function()
        print("Purchasing", item.Name, "with coins")
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
        print("Purchasing", item.Name, "with Robux")
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
    popupFrame.Position = UDim2.new(0.5, -170, 1, 20) -- Start below screen
    local slideIn = TweenService:Create(popupFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -170, 1, -100)
    })
    slideIn:Play()
    
    currentPopup = screenGui
    print("SmallBottomPurchasePopup: Showing popup for", item.Name)
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
    
    -- Scan workspace for purchasable items
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
                        -- Use GetPivot for models without PrimaryPart
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
            elseif item:IsA("Folder") and item.Name ~= "PlayerScripts" then
                scanForItems(item)
            end
        end
    end
    
    scanForItems(workspace)
    
    -- Handle popup changes
    if closestItem ~= currentStoreItem then
        -- Hide current popup if exists
        if currentPopup then
            -- Smooth slide-out animation
            local popupFrame = currentPopup:FindFirstChild("Frame")
            if popupFrame then
                local slideOut = TweenService:Create(popupFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, -170, 1, 20)
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
            wait(0.1) -- Small delay for smooth transition
            createSmallPurchasePopup(currentStoreItem)
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

print("SmallBottomPurchasePopup: Ready! Non-intrusive popup system active.")
]]

print("✓ Created small bottom popup system")
print("")
print("=== SMALL POPUP FEATURES ===")
print("✓ Small popup at bottom center")
print("✓ Doesn't block the view")
print("✓ Players can move freely")
print("✓ Smooth slide-in/slide-out animations")
print("✓ Automatically disappears when walking away")
print("✓ Hover effects on buttons")
print("✓ Fixed MouseButton1Click error")
print("")
print("Run this script to get the unobtrusive popup you wanted!") 