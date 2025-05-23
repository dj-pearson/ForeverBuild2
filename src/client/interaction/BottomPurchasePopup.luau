-- BottomPurchasePopup.luau
-- Clean bottom purchase popup system that matches the user's existing UI style

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BottomPurchasePopup = {}
BottomPurchasePopup.__index = BottomPurchasePopup

function BottomPurchasePopup.new()
    local self = setmetatable({}, BottomPurchasePopup)
    
    -- Configuration
    self.PROXIMITY_DISTANCE = 8
    self.UPDATE_INTERVAL = 0.3
    self.lastUpdate = 0
    
    -- State
    self.currentStoreItem = nil
    self.currentPopup = nil
    self.enabled = true
    
    -- Connection tracking
    self.connections = {}
    
    return self
end

function BottomPurchasePopup:Initialize()
    print("BottomPurchasePopup: Initializing...")
    
    -- Start the main update loop
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - self.lastUpdate >= self.UPDATE_INTERVAL then
            self.lastUpdate = now
            self:CheckForNearbyItems()
        end
    end)
    table.insert(self.connections, heartbeatConnection)
    
    print("BottomPurchasePopup: Ready! Small unobtrusive popup system active.")
    return true
end

function BottomPurchasePopup:CreateBottomPurchasePopup(item)
    local itemName = item.Name:gsub("_", " ")
    local price = item:GetAttribute("Price") or item:GetAttribute("priceIngame") or 75
    local robuxPrice = item:GetAttribute("priceRobux") or 5
    
    -- Remove existing popup
    if self.currentPopup then
        self.currentPopup:Destroy()
        self.currentPopup = nil
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
        print("BottomPurchasePopup: Purchasing", item.Name, "with", price, "coins")
        self:PurchaseItem(item.Name, "INGAME")
    end)
    
    robuxButton.MouseButton1Click:Connect(function()
        print("BottomPurchasePopup: Purchasing", item.Name, "with", robuxPrice, "Robux")
        self:PurchaseItem(item.Name, "ROBUX")
    end)
    
    -- Smooth slide-in animation
    popupFrame.Position = UDim2.new(0.5, -160, 1, 20) -- Start below screen
    local slideIn = TweenService:Create(popupFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 1, -120)
    })
    slideIn:Play()
    
    self.currentPopup = screenGui
    print("BottomPurchasePopup: Showing popup for", item.Name)
end

function BottomPurchasePopup:PurchaseItem(itemName, currencyType)
    local purchaseEvent = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("PurchaseItem")
    if purchaseEvent then
        purchaseEvent:FireServer(itemName, 1, currencyType)
    else
        warn("BottomPurchasePopup: PurchaseItem remote event not found")
    end
    
    -- Hide popup after purchase
    self:HidePopup()
end

function BottomPurchasePopup:HidePopup()
    if self.currentPopup then
        local popupFrame = self.currentPopup:FindFirstChild("Frame")
        if popupFrame then
            local slideOut = TweenService:Create(popupFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -160, 1, 20)
            })
            slideOut:Play()
            slideOut.Completed:Connect(function()
                self.currentPopup:Destroy()
                self.currentPopup = nil
            end)
        else
            self.currentPopup:Destroy()
            self.currentPopup = nil
        end
    end
    self.currentStoreItem = nil
end

function BottomPurchasePopup:CheckForNearbyItems()
    if not self.enabled then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local playerPosition = humanoidRootPart.Position
    local closestItem = nil
    local closestDistance = self.PROXIMITY_DISTANCE
    
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
    if closestItem ~= self.currentStoreItem then
        -- Hide current popup
        if self.currentPopup then
            self:HidePopup()
        end
        
        self.currentStoreItem = closestItem
        
        -- Show new popup if we have an item
        if self.currentStoreItem then
            task.wait(0.1) -- Small delay for smooth transition
            self:CreateBottomPurchasePopup(self.currentStoreItem)
        end
    end
end

function BottomPurchasePopup:SetEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self:HidePopup()
    end
end

function BottomPurchasePopup:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Hide popup
    self:HidePopup()
    
    print("BottomPurchasePopup: Cleaned up successfully")
end

return BottomPurchasePopup 