-- CatalogItemUI.luau
-- UI module for displaying catalog item information and purchase options

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Import shared modules with fallback
print("CatalogItemUI: Attempting to require shared module")
local SharedModule
local Constants

local success, errorMessage = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared", 5))
    Constants = SharedModule.Constants
    return true
end)

if not success then
    warn("CatalogItemUI: Failed to require SharedModule:", errorMessage)
    print("CatalogItemUI: Creating minimal SharedModule fallback")
    -- Create minimal fallback for Constants
    Constants = {
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        },
        CURRENCY = {
            INGAME = "Coins",
            ROBUX = "Robux"
        }
    }
    SharedModule = {
        Constants = Constants
    }
else
    print("CatalogItemUI: Successfully required SharedModule")
end

local CatalogItemUI = {}
CatalogItemUI.__index = CatalogItemUI

function CatalogItemUI.new()
    local self = setmetatable({}, CatalogItemUI)
    
    -- UI elements
    self.gui = nil
    self.frame = nil
    self.connections = {}
    
    -- Current state
    self.currentItem = nil
    self.purchaseQuantity = 1
    
    -- Remote events/functions
    self.remotes = {}
    
    return self
end

function CatalogItemUI:Initialize()
    -- Cache remote events/functions
    self:SetupRemotes()
    
    -- Create UI
    self:CreateUI()
    
    return self
end

function CatalogItemUI:SetupRemotes()
    -- Get the Remotes folder
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not remotesFolder then
        warn("Remotes folder not found - catalog UI functionality may be limited")
        return
    end
    
    -- Cache remote functions
    self:CacheRemote(remotesFolder, "GetItemData")
    self:CacheRemote(remotesFolder, "IsItemAffordable")
    
    -- Cache remote events
    self:CacheRemote(remotesFolder, "PurchaseItem")
    self:CacheRemote(remotesFolder, "NotifyPlayer")
end

function CatalogItemUI:CacheRemote(parent, name)
    local remote = parent:FindFirstChild(name)
    if remote then
        self.remotes[name] = remote
    else
        warn("Remote '" .. name .. "' not found")
    end
end

function CatalogItemUI:CreateUI()
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "CatalogItemUI"
    self.gui.ResetOnSpawn = false
    self.gui.Enabled = false
    self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.gui.Parent = playerGui
    
    -- Create main frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "MainFrame"
    self.frame.Size = UDim2.new(0, 400, 0, 500)
    self.frame.Position = UDim2.new(0.5, -200, 0.5, -250)
    self.frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    self.frame.BorderSizePixel = 0
    self.frame.Parent = self.gui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.frame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    -- Title text
    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -20, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextSize = 24
    titleText.Font = Enum.Font.GothamBold
    titleText.Text = "Item Catalog"
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 20
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    -- Connect close button
    closeButton.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    
    -- Item info container
    local infoContainer = Instance.new("Frame")
    infoContainer.Name = "InfoContainer"
    infoContainer.Size = UDim2.new(1, -40, 1, -160)
    infoContainer.Position = UDim2.new(0, 20, 0, 70)
    infoContainer.BackgroundTransparency = 1
    infoContainer.Parent = self.frame
    
    -- Item icon
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 120, 0, 120)
    iconFrame.Position = UDim2.new(0, 0, 0, 0)
    iconFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = infoContainer
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = iconFrame
    
    local itemIcon = Instance.new("ImageLabel")
    itemIcon.Name = "ItemIcon"
    itemIcon.Size = UDim2.new(1, -20, 1, -20)
    itemIcon.Position = UDim2.new(0, 10, 0, 10)
    itemIcon.BackgroundTransparency = 1
    itemIcon.Image = "rbxassetid://3284930147" -- Default icon
    itemIcon.Parent = iconFrame
    
    -- Item details
    local detailsFrame = Instance.new("Frame")
    detailsFrame.Name = "DetailsFrame"
    detailsFrame.Size = UDim2.new(1, -140, 0, 120)
    detailsFrame.Position = UDim2.new(0, 140, 0, 0)
    detailsFrame.BackgroundTransparency = 1
    detailsFrame.Parent = infoContainer
    
    -- Item name
    local itemName = Instance.new("TextLabel")
    itemName.Name = "ItemName"
    itemName.Size = UDim2.new(1, 0, 0, 30)
    itemName.BackgroundTransparency = 1
    itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemName.TextSize = 22
    itemName.Font = Enum.Font.GothamBold
    itemName.Text = "Item Name"
    itemName.TextXAlignment = Enum.TextXAlignment.Left
    itemName.Parent = detailsFrame
    
    -- Item description
    local itemDescription = Instance.new("TextLabel")
    itemDescription.Name = "ItemDescription"
    itemDescription.Size = UDim2.new(1, 0, 0, 60)
    itemDescription.Position = UDim2.new(0, 0, 0, 30)
    itemDescription.BackgroundTransparency = 1
    itemDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemDescription.TextSize = 16
    itemDescription.Font = Enum.Font.Gotham
    itemDescription.Text = "Item description goes here. This will show details about the selected item."
    itemDescription.TextXAlignment = Enum.TextXAlignment.Left
    itemDescription.TextYAlignment = Enum.TextYAlignment.Top
    itemDescription.TextWrapped = true
    itemDescription.Parent = detailsFrame
    
    -- Item price
    local priceFrame = Instance.new("Frame")
    priceFrame.Name = "PriceFrame"
    priceFrame.Size = UDim2.new(0, 120, 0, 30)
    priceFrame.Position = UDim2.new(0, 0, 0, 90)
    priceFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    priceFrame.BorderSizePixel = 0
    priceFrame.Parent = detailsFrame
    
    local priceCorner = Instance.new("UICorner")
    priceCorner.CornerRadius = UDim.new(0, 6)
    priceCorner.Parent = priceFrame
    
    local priceIcon = Instance.new("ImageLabel")
    priceIcon.Name = "PriceIcon"
    priceIcon.Size = UDim2.new(0, 20, 0, 20)
    priceIcon.Position = UDim2.new(0, 5, 0, 5)
    priceIcon.BackgroundTransparency = 1
    priceIcon.Image = "rbxassetid://3282628069" -- Coin icon
    priceIcon.Parent = priceFrame
    
    local priceText = Instance.new("TextLabel")
    priceText.Name = "PriceText"
    priceText.Size = UDim2.new(1, -30, 1, 0)
    priceText.Position = UDim2.new(0, 30, 0, 0)
    priceText.BackgroundTransparency = 1
    priceText.TextColor3 = Color3.fromRGB(255, 255, 255)
    priceText.TextSize = 16
    priceText.Font = Enum.Font.GothamBold
    priceText.Text = "5 Coins"
    priceText.TextXAlignment = Enum.TextXAlignment.Left
    priceText.Parent = priceFrame
    
    -- Quantity selector
    local quantityFrame = Instance.new("Frame")
    quantityFrame.Name = "QuantityFrame"
    quantityFrame.Size = UDim2.new(1, 0, 0, 50)
    quantityFrame.Position = UDim2.new(0, 0, 1, -180)
    quantityFrame.BackgroundTransparency = 1
    quantityFrame.Parent = self.frame
    
    local quantityLabel = Instance.new("TextLabel")
    quantityLabel.Name = "QuantityLabel"
    quantityLabel.Size = UDim2.new(0, 100, 0, 50)
    quantityLabel.BackgroundTransparency = 1
    quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    quantityLabel.TextSize = 18
    quantityLabel.Font = Enum.Font.Gotham
    quantityLabel.Text = "Quantity:"
    quantityLabel.TextXAlignment = Enum.TextXAlignment.Left
    quantityLabel.Parent = quantityFrame
    
    -- Minus button
    local minusButton = Instance.new("TextButton")
    minusButton.Name = "MinusButton"
    minusButton.Size = UDim2.new(0, 40, 0, 40)
    minusButton.Position = UDim2.new(0, 120, 0, 5)
    minusButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    minusButton.BorderSizePixel = 0
    minusButton.Text = "-"
    minusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusButton.TextSize = 24
    minusButton.Font = Enum.Font.GothamBold
    minusButton.Parent = quantityFrame
    
    local minusCorner = Instance.new("UICorner")
    minusCorner.CornerRadius = UDim.new(0, 8)
    minusCorner.Parent = minusButton
    
    -- Quantity input
    local quantityInput = Instance.new("TextBox")
    quantityInput.Name = "QuantityInput"
    quantityInput.Size = UDim2.new(0, 80, 0, 40)
    quantityInput.Position = UDim2.new(0, 170, 0, 5)
    quantityInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    quantityInput.BorderSizePixel = 0
    quantityInput.Text = "1"
    quantityInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    quantityInput.TextSize = 18
    quantityInput.Font = Enum.Font.GothamBold
    quantityInput.Parent = quantityFrame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = quantityInput
    
    -- Plus button
    local plusButton = Instance.new("TextButton")
    plusButton.Name = "PlusButton"
    plusButton.Size = UDim2.new(0, 40, 0, 40)
    plusButton.Position = UDim2.new(0, 260, 0, 5)
    plusButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    plusButton.BorderSizePixel = 0
    plusButton.Text = "+"
    plusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusButton.TextSize = 24
    plusButton.Font = Enum.Font.GothamBold
    plusButton.Parent = quantityFrame
    
    local plusCorner = Instance.new("UICorner")
    plusCorner.CornerRadius = UDim.new(0, 8)
    plusCorner.Parent = plusButton
    
    -- Connect quantity buttons
    minusButton.MouseButton1Click:Connect(function()
        self:ChangeQuantity(-1)
    end)
    
    plusButton.MouseButton1Click:Connect(function()
        self:ChangeQuantity(1)
    end)
    
    quantityInput.FocusLost:Connect(function(enterPressed)
        self:UpdateQuantity(quantityInput.Text)
    end)
    
    -- Total price
    local totalPriceFrame = Instance.new("Frame")
    totalPriceFrame.Name = "TotalPriceFrame"
    totalPriceFrame.Size = UDim2.new(0, 180, 0, 40)
    totalPriceFrame.Position = UDim2.new(0, 20, 1, -120)
    totalPriceFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    totalPriceFrame.BorderSizePixel = 0
    totalPriceFrame.Parent = self.frame
    
    local totalPriceCorner = Instance.new("UICorner")
    totalPriceCorner.CornerRadius = UDim.new(0, 6)
    totalPriceCorner.Parent = totalPriceFrame
    
    local totalPriceLabel = Instance.new("TextLabel")
    totalPriceLabel.Name = "TotalPriceLabel"
    totalPriceLabel.Size = UDim2.new(0, 80, 1, 0)
    totalPriceLabel.BackgroundTransparency = 1
    totalPriceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    totalPriceLabel.TextSize = 16
    totalPriceLabel.Font = Enum.Font.Gotham
    totalPriceLabel.Text = "Total Price:"
    totalPriceLabel.TextXAlignment = Enum.TextXAlignment.Left
    totalPriceLabel.Parent = totalPriceFrame
    
    local totalPriceText = Instance.new("TextLabel")
    totalPriceText.Name = "TotalPriceText"
    totalPriceText.Size = UDim2.new(0, 80, 1, 0)
    totalPriceText.Position = UDim2.new(0, 90, 0, 0)
    totalPriceText.BackgroundTransparency = 1
    totalPriceText.TextColor3 = Color3.fromRGB(255, 255, 255)
    totalPriceText.TextSize = 18
    totalPriceText.Font = Enum.Font.GothamBold
    totalPriceText.Text = "5 Coins"
    totalPriceText.TextXAlignment = Enum.TextXAlignment.Right
    totalPriceText.Parent = totalPriceFrame
    
    -- Purchase buttons
    local purchaseCoinsButton = Instance.new("TextButton")
    purchaseCoinsButton.Name = "PurchaseCoinsButton"
    purchaseCoinsButton.Size = UDim2.new(0, 180, 0, 50)
    purchaseCoinsButton.Position = UDim2.new(0, 20, 1, -60)
    purchaseCoinsButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    purchaseCoinsButton.BorderSizePixel = 0
    purchaseCoinsButton.Text = "Buy with Coins"
    purchaseCoinsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseCoinsButton.TextSize = 18
    purchaseCoinsButton.Font = Enum.Font.GothamBold
    purchaseCoinsButton.Parent = self.frame
    
    local purchaseCoinsCorner = Instance.new("UICorner")
    purchaseCoinsCorner.CornerRadius = UDim.new(0, 8)
    purchaseCoinsCorner.Parent = purchaseCoinsButton
    
    local purchaseRobuxButton = Instance.new("TextButton")
    purchaseRobuxButton.Name = "PurchaseRobuxButton"
    purchaseRobuxButton.Size = UDim2.new(0, 180, 0, 50)
    purchaseRobuxButton.Position = UDim2.new(0, 210, 1, -60)
    purchaseRobuxButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    purchaseRobuxButton.BorderSizePixel = 0
    purchaseRobuxButton.Text = "Buy with Robux"
    purchaseRobuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseRobuxButton.TextSize = 18
    purchaseRobuxButton.Font = Enum.Font.GothamBold
    purchaseRobuxButton.Parent = self.frame
    
    local purchaseRobuxCorner = Instance.new("UICorner")
    purchaseRobuxCorner.CornerRadius = UDim.new(0, 8)
    purchaseRobuxCorner.Parent = purchaseRobuxButton
    
    -- Connect purchase buttons
    purchaseCoinsButton.MouseButton1Click:Connect(function()
        self:PurchaseItem("INGAME")
    end)
    
    purchaseRobuxButton.MouseButton1Click:Connect(function()
        self:PurchaseItem("ROBUX")
    end)
    
    -- Add help text at the bottom
    local helpText = Instance.new("TextLabel")
    helpText.Name = "HelpText"
    helpText.Size = UDim2.new(1, -40, 0, 20)
    helpText.Position = UDim2.new(0, 20, 1, -20)
    helpText.BackgroundTransparency = 1
    helpText.TextColor3 = Color3.fromRGB(150, 150, 150)
    helpText.TextSize = 14
    helpText.Font = Enum.Font.Gotham
    helpText.Text = "Items will be added to your inventory after purchase."
    helpText.TextXAlignment = Enum.TextXAlignment.Center
    helpText.Parent = self.frame
end

function CatalogItemUI:Show(itemName)
    -- Get item data from server
    local itemData
    pcall(function()
        if self.remotes.GetItemData then
            itemData = self.remotes.GetItemData:InvokeServer(itemName)
        end
    end)
    
    if not itemData then
        -- Use fallback data if server call fails
        itemData = {
            name = itemName,
            description = "No description available.",
            price = {INGAME = 5, ROBUX = 5},
            icon = "rbxassetid://3284930147"
        }
    end
    
    -- Set current item
    self.currentItem = itemName
    
    -- Reset quantity
    self.purchaseQuantity = 1
    
    -- Update UI
    self:UpdateUI(itemData)
    
    -- Show the UI
    self.gui.Enabled = true
    
    -- Animate in
    self.frame.Position = UDim2.new(0.5, -200, 0.6, -250)
    self.frame.BackgroundTransparency = 1
    
    -- Find all TextLabels and Buttons
    for _, obj in ipairs(self.frame:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("Frame") then
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                obj.TextTransparency = 1
            end
            if obj:IsA("Frame") or obj:IsA("TextButton") then
                obj.BackgroundTransparency = 1
            end
        end
    end
    
    -- Animate in
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local frameTween = TweenService:Create(self.frame, tweenInfo, {
        Position = UDim2.new(0.5, -200, 0.5, -250),
        BackgroundTransparency = 0
    })
    frameTween:Play()
    
    -- Fade in all elements
    for _, obj in ipairs(self.frame:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("Frame") then
            local transparency = 0
            if obj:IsA("Frame") and (obj.Name == "InfoContainer" or obj.Name == "QuantityFrame") then
                transparency = 1 -- Keep some frames transparent
            end
            
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                TweenService:Create(obj, tweenInfo, {TextTransparency = 0}):Play()
            end
            
            if (obj:IsA("Frame") or obj:IsA("TextButton")) and obj.BackgroundTransparency == 1 then
                TweenService:Create(obj, tweenInfo, {BackgroundTransparency = transparency}):Play()
            end
        end
    end
end

function CatalogItemUI:Hide()
    -- Don't do anything if not shown
    if not self.gui.Enabled then
        return
    end
    
    -- Animate out
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local frameTween = TweenService:Create(self.frame, tweenInfo, {
        Position = UDim2.new(0.5, -200, 0.6, -250),
        BackgroundTransparency = 1
    })
    frameTween:Play()
    
    -- Fade out all elements
    for _, obj in ipairs(self.frame:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            TweenService:Create(obj, tweenInfo, {TextTransparency = 1}):Play()
        end
        
        if obj:IsA("Frame") or obj:IsA("TextButton") then
            TweenService:Create(obj, tweenInfo, {BackgroundTransparency = 1}):Play()
        end
    end
    
    -- Disable after animation
    task.delay(0.3, function()
        self.gui.Enabled = false
    end)
end

function CatalogItemUI:UpdateUI(itemData)
    -- Get references to UI elements
    local itemIcon = self.frame:FindFirstChild("InfoContainer", true):FindFirstChild("IconFrame", true):FindFirstChild("ItemIcon", true)
    local itemName = self.frame:FindFirstChild("InfoContainer", true):FindFirstChild("DetailsFrame", true):FindFirstChild("ItemName", true)
    local itemDescription = self.frame:FindFirstChild("InfoContainer", true):FindFirstChild("DetailsFrame", true):FindFirstChild("ItemDescription", true)
    local priceText = self.frame:FindFirstChild("InfoContainer", true):FindFirstChild("DetailsFrame", true):FindFirstChild("PriceFrame", true):FindFirstChild("PriceText", true)
    local quantityInput = self.frame:FindFirstChild("QuantityFrame", true):FindFirstChild("QuantityInput", true)
    local totalPriceText = self.frame:FindFirstChild("TotalPriceFrame", true):FindFirstChild("TotalPriceText", true)
    
    -- Update UI with item data
    if itemIcon then
        itemIcon.Image = itemData.icon
    end
    
    if itemName then
        itemName.Text = itemData.name:gsub("_", " ")
    end
    
    if itemDescription then
        itemDescription.Text = itemData.description
    end
    
    if priceText then
        priceText.Text = tostring(itemData.price.INGAME) .. " Coins"
    end
    
    if quantityInput then
        quantityInput.Text = tostring(self.purchaseQuantity)
    end
    
    if totalPriceText then
        totalPriceText.Text = tostring(itemData.price.INGAME * self.purchaseQuantity) .. " Coins"
    end
    
    -- Update purchase buttons
    local purchaseCoinsButton = self.frame:FindFirstChild("PurchaseCoinsButton", true)
    local purchaseRobuxButton = self.frame:FindFirstChild("PurchaseRobuxButton", true)
    
    if purchaseCoinsButton then
        purchaseCoinsButton.Text = "Buy with Coins (" .. tostring(itemData.price.INGAME * self.purchaseQuantity) .. ")"
    end
    
    if purchaseRobuxButton then
        purchaseRobuxButton.Text = "Buy with Robux (" .. tostring(itemData.price.ROBUX * self.purchaseQuantity) .. ")"
    end
end

function CatalogItemUI:ChangeQuantity(delta)
    -- Update quantity
    local newQuantity = self.purchaseQuantity + delta
    
    -- Clamp to valid range (1-99)
    newQuantity = math.clamp(newQuantity, 1, 99)
    
    -- Update if changed
    if newQuantity ~= self.purchaseQuantity then
        self.purchaseQuantity = newQuantity
        
        -- Update UI
        local quantityInput = self.frame:FindFirstChild("QuantityInput", true)
        if quantityInput then
            quantityInput.Text = tostring(self.purchaseQuantity)
        end
        
        -- Update total price
        self:UpdateTotalPrice()
    end
end

function CatalogItemUI:UpdateQuantity(text)
    -- Parse quantity
    local quantity = tonumber(text)
    
    -- Validate
    if not quantity or quantity < 1 then
        quantity = 1
    elseif quantity > 99 then
        quantity = 99
    end
    
    -- Update quantity
    self.purchaseQuantity = quantity
    
    -- Update UI
    local quantityInput = self.frame:FindFirstChild("QuantityInput", true)
    if quantityInput then
        quantityInput.Text = tostring(self.purchaseQuantity)
    end
    
    -- Update total price
    self:UpdateTotalPrice()
end

function CatalogItemUI:UpdateTotalPrice()
    -- Get item data
    local itemData
    pcall(function()
        if self.remotes.GetItemData then
            itemData = self.remotes.GetItemData:InvokeServer(self.currentItem)
        end
    end)
    
    if not itemData then
        return
    end
    
    -- Calculate total price
    local totalPrice = itemData.price.INGAME * self.purchaseQuantity
    
    -- Update UI
    local totalPriceText = self.frame:FindFirstChild("TotalPriceText", true)
    if totalPriceText then
        totalPriceText.Text = tostring(totalPrice) .. " Coins"
    end
    
    -- Update purchase buttons
    local purchaseCoinsButton = self.frame:FindFirstChild("PurchaseCoinsButton", true)
    local purchaseRobuxButton = self.frame:FindFirstChild("PurchaseRobuxButton", true)
    
    if purchaseCoinsButton then
        purchaseCoinsButton.Text = "Buy with Coins (" .. tostring(totalPrice) .. ")"
    end
    
    if purchaseRobuxButton then
        purchaseRobuxButton.Text = "Buy with Robux (" .. tostring(itemData.price.ROBUX * self.purchaseQuantity) .. ")"
    end
end

function CatalogItemUI:PurchaseItem(currencyType)
    -- Check if can afford
    local canAfford = true
    pcall(function()
        if self.remotes.IsItemAffordable then
            canAfford = self.remotes.IsItemAffordable:InvokeServer(self.currentItem, self.purchaseQuantity)
        end
    end)
    
    if not canAfford and currencyType == "INGAME" then
        -- Show not enough coins message
        if self.remotes.NotifyPlayer then
            self.remotes.NotifyPlayer:FireClient(player, "You don't have enough coins to purchase this item.")
        end
        return
    end
    
    -- Send purchase request to server
    pcall(function()
        if self.remotes.PurchaseItem then
            self.remotes.PurchaseItem:FireServer(self.currentItem, self.purchaseQuantity, currencyType)
        end
    end)
    
    -- Hide UI
    self:Hide()
end

function CatalogItemUI:Destroy()
    -- Destroy UI
    if self.gui then
        self.gui:Destroy()
        self.gui = nil
    end
    
    -- Clear connections
    for _, connection in ipairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
end

return CatalogItemUI 