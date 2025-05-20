--[[
    CurrencyUI Module - ForeverBuild2
    
    NOTE: This is the original CurrencyUI implementation.
    Previously we tried to forward to the client implementation but that caused path issues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- CRITICAL FIX: Use the correct path to Constants
local Constants = require(script.Parent.Parent.Constants)

-- Import the client version was causing errors - restore original functionality
local success, ClientCurrencyUI = true, nil -- Just to keep the existing code structure

if not success then
    warn("Failed to require client CurrencyUI module:", ClientCurrencyUI)
    
    -- Create a minimal fallback implementation
    local FallbackCurrencyUI = {}
    FallbackCurrencyUI.__index = FallbackCurrencyUI
    
    -- Initialize a new CurrencyUI
    function FallbackCurrencyUI.new()
        warn("Using fallback CurrencyUI implementation")
        local self = setmetatable({}, FallbackCurrencyUI)
        return self
    end
    
    -- Initialize the CurrencyUI with minimal functionality
    function FallbackCurrencyUI:Initialize()
        warn("Fallback CurrencyUI:Initialize called")
    end
    
    -- Create UI (stub)
    function FallbackCurrencyUI:CreateUI()
        warn("Fallback CurrencyUI:CreateUI called")
    end
    
    -- Set up event handlers (stub)
    function FallbackCurrencyUI:SetupEventHandlers()
        warn("Fallback CurrencyUI:SetupEventHandlers called")
    end
    
    -- Update balance (stub)
    function FallbackCurrencyUI:UpdateBalance()
        warn("Fallback CurrencyUI:UpdateBalance called")
    end
    
    -- We're not going to use the fallback
    -- Instead restore the original implementation
end

-- Original implementation from here:
local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

-- Initialize a new CurrencyUI
function CurrencyUI.new()
    local self = setmetatable({}, CurrencyUI)
    self.ui = nil
    return self
end

-- Initialize the CurrencyUI
function CurrencyUI:Initialize()
    -- Create UI
    self:CreateUI()
    
    -- Set up event handlers
    self:SetupEventHandlers()
    
    -- Initial balance update
    self:UpdateBalance(Constants.CURRENCY.STARTING_COINS)
end

-- Create UI
function CurrencyUI:CreateUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("CurrencyUI")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CurrencyUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
    end
    
    -- Create main frame at top center
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.5, -100, 0, 20) -- Top center
    frame.BackgroundColor3 = Constants.UI_COLORS and Constants.UI_COLORS.SECONDARY or Color3.fromRGB(40,40,40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Add coin icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "CoinIcon"
    icon.Size = UDim2.new(0, 32, 0, 32)
    icon.Position = UDim2.new(0, 10, 0.5, -16)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://6034973115" -- Coin icon
    icon.Parent = frame
    
    -- Add balance text
    local balance = Instance.new("TextLabel")
    balance.Name = "Balance"
    balance.Size = UDim2.new(0, 100, 0, 30)
    balance.Position = UDim2.new(0, 52, 0.5, -15)
    balance.BackgroundTransparency = 1
    balance.Font = Enum.Font.GothamBold
    balance.TextSize = 18
    balance.TextColor3 = Color3.fromRGB(255, 255, 255)
    balance.TextXAlignment = Enum.TextXAlignment.Left
    balance.Text = "0"
    balance.Parent = frame
    
    -- Add purchase button
    local purchaseBtn = Instance.new("TextButton")
    purchaseBtn.Name = "PurchaseButton"
    purchaseBtn.Size = UDim2.new(0, 40, 0, 30)
    purchaseBtn.Position = UDim2.new(1, -50, 0.5, -15)
    purchaseBtn.BackgroundColor3 = Constants.UI_COLORS and Constants.UI_COLORS.PRIMARY or Color3.fromRGB(0, 170, 255)
    purchaseBtn.BorderSizePixel = 0
    purchaseBtn.Font = Enum.Font.GothamBold
    purchaseBtn.TextSize = 18
    purchaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseBtn.Text = "+"
    purchaseBtn.Parent = frame
    
    -- Add rounded corners to button
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = purchaseBtn
    
    -- Add click handler
    purchaseBtn.MouseButton1Click:Connect(function()
        self:ShowPurchaseMenu()
    end)
    
    -- Store UI reference
    self.ui = screenGui
    
    return screenGui
end

-- Set up event handlers
function CurrencyUI:SetupEventHandlers()
    -- Wait for RemoteEvents to be created
    local success, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    
    if success and remotes and remotes:FindFirstChild("UpdateBalance") then
        remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
            self:UpdateBalance(newBalance)
        end)
    else
        warn("CurrencyUI: Could not find UpdateBalance remote event")
        -- Try again later
        task.delay(5, function()
            if ReplicatedStorage:FindFirstChild("Remotes") and 
               ReplicatedStorage.Remotes:FindFirstChild("UpdateBalance") then
                ReplicatedStorage.Remotes.UpdateBalance.OnClientEvent:Connect(function(balance)
                    self:UpdateBalance(balance)
                end)
            end
        end)
    end
end

-- Update balance display
function CurrencyUI:UpdateBalance(balance)
    if not self.ui then 
        warn("CurrencyUI:UpdateBalance - UI not found!")
        return 
    end
    
    local mainFrame = self.ui:FindFirstChild("MainFrame")
    if not mainFrame then 
        warn("CurrencyUI:UpdateBalance - MainFrame not found!")
        return 
    end
    
    local balanceLabel = mainFrame:FindFirstChild("Balance")
    if not balanceLabel then 
        warn("CurrencyUI:UpdateBalance - Balance label not found!")
        return 
    end
    
    balanceLabel.Text = tostring(balance)
    print("💰 SHARED UI UPDATED: Currency balance is now " .. balance)
end

-- Show purchase menu
function CurrencyUI:ShowPurchaseMenu()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    print("[CurrencyUI:ShowPurchaseMenu] Called")
    print("[CurrencyUI:ShowPurchaseMenu] Checking Constants.UI structure:")
    print("  Constants.UI:", Constants.UI)
    if Constants.UI then
        print("  Constants.UI.Colors:", Constants.UI.Colors)
        print("  Constants.UI.Fonts:", Constants.UI.Fonts)
    end

    -- Remove existing dialog if it exists
    local existingDialog = self.ui and self.ui:FindFirstChild("PurchaseCurrencyDialog")
    if existingDialog then
        existingDialog:Destroy()
    end

    local dialog = Instance.new("Frame")
    dialog.Name = "PurchaseCurrencyDialog" -- Changed name for clarity
    dialog.Size = UDim2.new(0, 400, 0, 350) -- Adjusted size
    dialog.Position = UDim2.new(0.5, -200, 0.5, -175) -- Centered
    dialog.BackgroundColor3 = Constants.UI and Constants.UI.Colors.Background or Color3.fromRGB(30, 30, 30)
    dialog.BorderSizePixel = 0
    dialog.Visible = true
    dialog.Parent = self.ui
    dialog.ZIndex = 10 -- Ensure it's on top

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = dialog

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.Title and Constants.UI.Fonts.Title.Font) or Enum.Font.GothamBold
    title.TextSize = 24
    title.TextColor3 = Constants.UI and Constants.UI.Colors.TextPrimary or Color3.fromRGB(255, 255, 255)
    title.Text = "Purchase Currency"
    title.Parent = dialog

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Constants.UI and Constants.UI.Colors.ButtonDanger or Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.Button and Constants.UI.Fonts.Button.Font) or Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.TextColor3 = Constants.UI and Constants.UI.Colors.TextButton or Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "X"
    closeBtn.ZIndex = 11
    closeBtn.Parent = dialog

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 4)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        dialog:Destroy()
    end)

    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Name = "ProductList"
    scrollingFrame.Size = UDim2.new(1, -20, 1, -50) -- Leave space for title and padding
    scrollingFrame.Position = UDim2.new(0, 10, 0, 45)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be updated dynamically
    scrollingFrame.ScrollBarThickness = 6
    scrollingFrame.Parent = dialog

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollingFrame

    local totalContentHeight = 0
    local itemHeight = 100 -- Height of each product item frame

    print("[CurrencyUI:ShowPurchaseMenu] Initial totalContentHeight:", totalContentHeight)

    if Constants.CURRENCY and Constants.CURRENCY.PRODUCTS then
        print("[CurrencyUI:ShowPurchaseMenu] Found Constants.CURRENCY.PRODUCTS with", #Constants.CURRENCY.PRODUCTS, "items.")
        for i, productInfo in ipairs(Constants.CURRENCY.PRODUCTS) do
            print("[CurrencyUI:ShowPurchaseMenu] Processing product:", productInfo.name, productInfo)
            local itemFrame = Instance.new("Frame")
            itemFrame.Name = productInfo.id or "ProductItem" .. i
            itemFrame.Size = UDim2.new(1, 0, 0, itemHeight - 10) -- Minus padding for layout
            itemFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 255) -- Bright blue for testing visibility
            itemFrame.BorderSizePixel = 1
            itemFrame.BorderColor3 = Color3.fromRGB(255,255,0) -- Bright yellow border for testing
            itemFrame.LayoutOrder = i
            itemFrame.Visible = true -- Explicitly set visible
            itemFrame.ZIndex = dialog.ZIndex + 1 -- Ensure itemFrame is above dialog background but below its own content if needed
            itemFrame.Parent = scrollingFrame

            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 8)
            itemCorner.Parent = itemFrame
            
            local itemPadding = Instance.new("UIPadding")
            itemPadding.PaddingTop = UDim.new(0,5)
            itemPadding.PaddingBottom = UDim.new(0,5)
            itemPadding.PaddingLeft = UDim.new(0,10)
            itemPadding.PaddingRight = UDim.new(0,10)
            itemPadding.Parent = itemFrame

            local productName = Instance.new("TextLabel")
            productName.Name = "ProductName"
            productName.Size = UDim2.new(0.7, -10, 0, 25)
            productName.Position = UDim2.new(0, 0, 0, 0)
            productName.BackgroundTransparency = 1
            productName.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.Subtitle and Constants.UI.Fonts.Subtitle.Font) or Enum.Font.GothamBold
            productName.TextSize = 18
            productName.TextColor3 = Color3.fromRGB(255,255,255) -- Bright white for testing
            productName.Text = productInfo.name or "Unknown Product"
            productName.TextXAlignment = Enum.TextXAlignment.Left
            productName.ZIndex = itemFrame.ZIndex + 1 -- Ensure text is above itemFrame
            productName.Parent = itemFrame

            local productDesc = Instance.new("TextLabel")
            productDesc.Name = "ProductDescription"
            productDesc.Size = UDim2.new(1, 0, 0, 40)
            productDesc.Position = UDim2.new(0, 0, 0, 25)
            productDesc.BackgroundTransparency = 1
            productDesc.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.Body and Constants.UI.Fonts.Body.Font) or Enum.Font.Gotham
            productDesc.TextSize = 14
            productDesc.TextColor3 = Color3.fromRGB(220,220,220) -- Light grey for testing
            productDesc.Text = productInfo.description or ""
            productDesc.TextWrapped = true
            productDesc.TextXAlignment = Enum.TextXAlignment.Left
            productDesc.TextYAlignment = Enum.TextYAlignment.Top
            productDesc.ZIndex = itemFrame.ZIndex + 1 -- Ensure text is above itemFrame
            productDesc.Parent = itemFrame

            local robuxPrice = Instance.new("TextLabel")
            robuxPrice.Name = "RobuxPrice"
            robuxPrice.Size = UDim2.new(1, 0, 0, 20)
            robuxPrice.Position = UDim2.new(0, 0, 1, -25) -- Bottom align
            robuxPrice.BackgroundTransparency = 1
            robuxPrice.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.BodyBold and Constants.UI.Fonts.BodyBold.Font) or Enum.Font.GothamBold
            robuxPrice.TextSize = 16
            robuxPrice.TextColor3 = Color3.fromRGB(0,255,0) -- Bright green for testing
            robuxPrice.Text = "R$ " .. tostring(productInfo.robux or 0)
            robuxPrice.TextXAlignment = Enum.TextXAlignment.Left
            robuxPrice.ZIndex = itemFrame.ZIndex + 1 -- Ensure text is above itemFrame
            robuxPrice.Parent = itemFrame
            
            local buyButton = Instance.new("TextButton")
            buyButton.Name = "BuyButton"
            buyButton.Size = UDim2.new(0.25, 0, 0, 30)
            buyButton.Position = UDim2.new(0.75, -5, 0.5, -15) -- Centered on the right side
            buyButton.BackgroundColor3 = Color3.fromRGB(0,170,0) -- Bright green for testing
            buyButton.BorderSizePixel = 0
            buyButton.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.Button and Constants.UI.Fonts.Button.Font) or Enum.Font.GothamBold
            buyButton.TextSize = 16
            buyButton.TextColor3 = Color3.fromRGB(255,255,255) -- Bright white for testing
            buyButton.Text = "Buy"
            buyButton.ZIndex = itemFrame.ZIndex + 2 -- Ensure button is above text and frame
            buyButton.Parent = itemFrame

            local buyBtnCorner = Instance.new("UICorner")
            buyBtnCorner.CornerRadius = UDim.new(0, 6)
            buyBtnCorner.Parent = buyButton
            
            buyButton.MouseButton1Click:Connect(function()
                if MarketplaceService and productInfo.assetId then
                    print("Attempting to prompt purchase for assetId: " .. productInfo.assetId)
                    local success, err = pcall(function()
                        MarketplaceService:PromptProductPurchase(player, productInfo.assetId)
                    end)
                    if not success then
                        warn("Error prompting product purchase:", err)
                    end
                else
                    warn("MarketplaceService not available or product assetId missing for", productInfo.name)
                end
            end)
            totalContentHeight = totalContentHeight + itemHeight
            print("[CurrencyUI:ShowPurchaseMenu] itemFrame created for", productInfo.name, ". New totalContentHeight:", totalContentHeight)
        end
    else
        print("[CurrencyUI:ShowPurchaseMenu] Constants.CURRENCY.PRODUCTS not found or empty.")
        local noProductsLabel = Instance.new("TextLabel")
        noProductsLabel.Name = "NoProducts"
        noProductsLabel.Size = UDim2.new(1, -20, 0, 50)
        noProductsLabel.Position = UDim2.new(0, 10, 0, 10)
        noProductsLabel.BackgroundTransparency = 1
        noProductsLabel.Font = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts.Body and Constants.UI.Fonts.Body.Font) or Enum.Font.Gotham
        noProductsLabel.TextSize = 16
        noProductsLabel.TextColor3 = Constants.UI and Constants.UI.Colors.TextSecondary or Color3.fromRGB(200, 200, 200)
        noProductsLabel.TextWrapped = true
        noProductsLabel.Text = "No currency products are currently available. Please check back later!"
        noProductsLabel.Parent = scrollingFrame
        totalContentHeight = 50
    end
    
    print("[CurrencyUI:ShowPurchaseMenu] Final totalContentHeight before setting CanvasSize:", totalContentHeight)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, totalContentHeight)
    print("[CurrencyUI:ShowPurchaseMenu] Set scrollingFrame.CanvasSize to UDim2.new(0, 0, 0, " .. totalContentHeight .. ")")
end

return CurrencyUI
