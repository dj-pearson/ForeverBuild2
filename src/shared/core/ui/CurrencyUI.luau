--[[
    CurrencyUI Module - ForeverBuild2
    
    NOTE: This is the original CurrencyUI implementation.
    Previously we tried to forward to the client implementation but that caused path issues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- CRITICAL FIX: Use the correct path to Constants
local Constants = require(script.Parent.Parent.Constants) -- Reverted to direct path

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

-- Helper function to get color from Constants, with fallback
local function getColor(name, fallbackColor)
    return (Constants.UI and Constants.UI.Colors and Constants.UI.Colors[name]) or fallbackColor or Color3.fromRGB(255,0,255) -- Magenta fallback for missing
end

-- Helper function to get font from Constants, with fallback
local function getFont(name, fallbackFontEnum)
    local fontInfo = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts[name])
    return fontInfo and fontInfo.Font or fallbackFontEnum or Enum.Font.SourceSans
end

-- Helper function to get font size from Constants
local function getFontSize(name, fallbackSize)
    local fontInfo = (Constants.UI and Constants.UI.Fonts and Constants.UI.Fonts[name])
    return fontInfo and fontInfo.Size or fallbackSize or 14
end

-- Helper function to get metric from Constants
local function getMetric(name, fallbackValue)
    return (Constants.UI and Constants.UI.Metrics and Constants.UI.Metrics[name]) or fallbackValue
end

-- Initialize a new CurrencyUI
function CurrencyUI.new()
    local self = setmetatable({}, CurrencyUI)
    self.ui = nil
    self.purchaseDialog = nil -- Keep track of the purchase dialog
    return self
end

-- Initialize the CurrencyUI
function CurrencyUI:Initialize()
    self:CreateUI() -- Sets balance text to "0" initially by default in CreateUI

    -- Change BalanceText to "---"
    if self.ui then
        local mainFrame = self.ui:FindFirstChild("MainCurrencyFrame") -- Assuming self.ui is the ScreenGui
        if mainFrame then
            local balanceText = mainFrame:FindFirstChild("BalanceText")
            if balanceText then
                balanceText.Text = "---" -- Or "Loading..."
            end
        end
    end
    
    self:SetupEventHandlers() -- This connects to UpdateBalance for future updates

    -- NEW: Proactively request initial balance
    -- ReplicatedStorage and Constants are available as upvalues

    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotes then
        local getMyBalanceFunc = remotes:FindFirstChild("GetMyBalance") -- NEW RemoteFunction
        if getMyBalanceFunc and getMyBalanceFunc:IsA("RemoteFunction") then
            local success, currentBalance = pcall(function()
                return getMyBalanceFunc:InvokeServer()
            end)
            if success and type(currentBalance) == "number" then
                self:UpdateBalance(currentBalance)
            else
                warn("CurrencyUI: Failed to invoke GetMyBalance or received invalid balance. Error/Result:", currentBalance)
                self:UpdateBalance(Constants.CURRENCY.STARTING_COINS) -- Fallback to 200 if call fails
            end
        else
            warn("CurrencyUI: GetMyBalance RemoteFunction not found or not a RemoteFunction. UI might show default.")
            self:UpdateBalance(Constants.CURRENCY.STARTING_COINS) -- Fallback to 200 if remote not found
        end
    else
        warn("CurrencyUI: Remotes folder not found for initial balance fetch.")
         self:UpdateBalance(Constants.CURRENCY.STARTING_COINS) -- Fallback to 200
    end
end

-- Create UI
function CurrencyUI:CreateUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("CurrencyUIScreen") -- More specific name
    if screenGui then screenGui:Destroy() end -- Clear old UI for refresh

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CurrencyUIScreen"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- Main frame for currency display
    local frame = Instance.new("Frame")
    frame.Name = "MainCurrencyFrame"
    frame.Size = UDim2.new(0, 220, 0, 40) -- Slightly adjusted size
    frame.Position = UDim2.new(0.5, -110, 0, 15) -- Top center, bit lower
    frame.BackgroundColor3 = getColor("BackgroundSecondary", Color3.fromRGB(44,44,46))
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = getMetric("CornerRadiusMedium", UDim.new(0,8))
    corner.Parent = frame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = getMetric("PaddingMedium", UDim.new(0,10))
    padding.PaddingRight = getMetric("PaddingSmall", UDim.new(0,5)) -- Less padding on right due to button
    padding.PaddingTop = getMetric("PaddingSmall", UDim.new(0,5))
    padding.PaddingBottom = getMetric("PaddingSmall", UDim.new(0,5))
    padding.Parent = frame

    -- Coin Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "CoinIcon"
    icon.Size = getMetric("IconSizeMedium", UDim2.new(0,24,0,24))
    icon.Position = UDim2.new(0, 0, 0.5, -icon.Size.Y.Offset / 2) -- Centered vertically with padding
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://6034973115" -- Placeholder coin icon
    icon.Parent = frame

    -- Balance Text
    local balance = Instance.new("TextLabel")
    balance.Name = "BalanceText"
    balance.Size = UDim2.new(1, -icon.Size.X.Offset - getMetric("PaddingMedium").Offset - 50, 1, 0) -- Fill available space minus icon and button
    balance.Position = UDim2.new(0, icon.Size.X.Offset + getMetric("PaddingSmall").Offset, 0, 0)
    balance.BackgroundTransparency = 1
    balance.Font = getFont("BodyBold", Enum.Font.GothamBold)
    balance.TextSize = getFontSize("BodyBold", 16)
    balance.TextColor3 = getColor("TextPrimary", Color3.fromRGB(245,245,245))
    balance.TextXAlignment = Enum.TextXAlignment.Left
    balance.TextYAlignment = Enum.TextYAlignment.Center
    balance.Text = "0"
    balance.Parent = frame

    -- Purchase Button ("+")
    local purchaseBtn = Instance.new("TextButton")
    purchaseBtn.Name = "PurchaseCurrencyButton"
    purchaseBtn.Size = UDim2.new(0, 30, 0, 30) -- Square button
    purchaseBtn.Position = UDim2.new(1, -purchaseBtn.Size.X.Offset - getMetric("PaddingSmall").Offset, 0.5, -purchaseBtn.Size.Y.Offset/2)
    
    local purchaseBtnStyle = Constants.UI.ButtonStyles.Accent
    purchaseBtn.BackgroundColor3 = getColor(purchaseBtnStyle.BackgroundColor, getColor("ThemeAccent"))
    purchaseBtn.Font = getFont("Button", Enum.Font.GothamBold)
    purchaseBtn.TextSize = getFontSize("Button", 20) -- Larger for "+"
    purchaseBtn.TextColor3 = getColor(purchaseBtnStyle.TextColor, getColor("TextOnAccent"))
    purchaseBtn.Text = "+"
    purchaseBtn.BorderSizePixel = 0
    purchaseBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = getMetric("CornerRadiusSmall", UDim.new(0,4))
    btnCorner.Parent = purchaseBtn

    purchaseBtn.MouseButton1Click:Connect(function()
        self:ShowPurchaseMenu()
    end)

    self.ui = screenGui
    return screenGui
end

-- Set up event handlers
function CurrencyUI:SetupEventHandlers()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes and remotes:FindFirstChild("UpdateBalance") then
        remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
            self:UpdateBalance(newBalance)
        end)
    else
        warn("CurrencyUI: Could not find UpdateBalance remote event initially.")
        task.delay(2, function() -- Shorter delay
            remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("UpdateBalance") then
                remotes.UpdateBalance.OnClientEvent:Connect(function(balance)
                    self:UpdateBalance(balance)
                end)
                print("CurrencyUI: Successfully connected to UpdateBalance after delay.")
            else
                warn("CurrencyUI: Still could not find UpdateBalance remote event after delay.")
            end
        end)
    end
end

-- Update balance display
function CurrencyUI:UpdateBalance(balance)
    if not self.ui then warn("CurrencyUI:UpdateBalance - UI not found!") return end
    local mainFrame = self.ui:FindFirstChild("MainCurrencyFrame")
    if not mainFrame then warn("CurrencyUI:UpdateBalance - MainCurrencyFrame not found!") return end
    local balanceLabel = mainFrame:FindFirstChild("BalanceText")
    if not balanceLabel then warn("CurrencyUI:UpdateBalance - BalanceText label not found!") return end
    
    balanceLabel.Text = tostring(balance)
    -- print("💰 SHARED UI UPDATED: Currency balance is now " .. balance) -- Keep for debug if needed
end

-- Show purchase menu
function CurrencyUI:ShowPurchaseMenu()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    if self.purchaseDialog and self.purchaseDialog.Parent then
        self.purchaseDialog:Destroy() -- Destroy if already open
    end

    local dialog = Instance.new("Frame")
    dialog.Name = "PurchaseCurrencyDialog"
    dialog.Size = UDim2.new(0, 450, 0, 400) -- Slightly wider
    dialog.Position = UDim2.new(0.5, -dialog.Size.X.Offset / 2, 0.5, -dialog.Size.Y.Offset / 2)
    dialog.BackgroundColor3 = getColor("BackgroundPrimary", Color3.fromRGB(28,28,30))
    dialog.BorderSizePixel = getMetric("BorderThickness", 1)
    dialog.BorderColor3 = getColor("Border", Color3.fromRGB(70,70,72))
    dialog.Visible = true
    dialog.ZIndex = 100 -- High ZIndex for modals
    dialog.Parent = self.ui -- Parent to the screenGui

    self.purchaseDialog = dialog -- Store reference

    local corner = Instance.new("UICorner")
    corner.CornerRadius = getMetric("CornerRadiusLarge", UDim.new(0,12))
    corner.Parent = dialog
    
    local dialogPadding = Instance.new("UIPadding")
    dialogPadding.PaddingTop = getMetric("PaddingLarge", UDim.new(0,15))
    dialogPadding.PaddingBottom = getMetric("PaddingLarge", UDim.new(0,15))
    dialogPadding.PaddingLeft = getMetric("PaddingLarge", UDim.new(0,15))
    dialogPadding.PaddingRight = getMetric("PaddingLarge", UDim.new(0,15))
    dialogPadding.Parent = dialog

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "DialogTitle"
    title.Size = UDim2.new(1, 0, 0, getFontSize("Title", 20) + getMetric("PaddingSmall").Offset)
    title.Position = UDim2.new(0, 0, 0, 0) -- Padding handled by parent
    title.BackgroundTransparency = 1
    title.Font = getFont("Title", Enum.Font.GothamBold)
    title.TextSize = getFontSize("Title", 20)
    title.TextColor3 = getColor("TextPrimary", Color3.fromRGB(245,245,245))
    title.Text = "Get More Coins"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = dialog

    -- Close Button
    local closeBtnStyle = Constants.UI.ButtonStyles.Quiet
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseDialogButton"
    closeBtn.Size = UDim2.new(0, 32, 0, 32) -- Icon-like size
    closeBtn.Position = UDim2.new(1, -closeBtn.Size.X.Offset - getMetric("PaddingSmall").Offset, 0, getMetric("PaddingSmall").Offset) -- Top right within padding
    closeBtn.BackgroundColor3 = getColor(closeBtnStyle.BackgroundColor, Color3.new(0,0,0))
    closeBtn.BackgroundTransparency = closeBtnStyle.BackgroundTransparency or 1
    closeBtn.Font = getFont("Button") -- Using a generic large X or icon font later
    closeBtn.TextSize = getFontSize("Button", 24) -- For a larger 'X'
    closeBtn.TextColor3 = getColor(closeBtnStyle.TextColor, getColor("TextSecondary"))
    closeBtn.Text = "✕" -- Unicode multiplication sign
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = dialog.ZIndex + 1
    closeBtn.Parent = dialog
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = getMetric("CornerRadiusMedium")
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        dialog:Destroy()
        self.purchaseDialog = nil
    end)

    -- Scrolling Frame for Products
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Name = "ProductList"
    scrollingFrame.Size = UDim2.new(1, 0, 1, -title.Size.Y.Offset - getMetric("PaddingMedium").Offset) 
    scrollingFrame.Position = UDim2.new(0, 0, 0, title.Size.Y.Offset + getMetric("PaddingMedium").Offset)
    scrollingFrame.BackgroundColor3 = getColor("BackgroundPrimary") -- Match dialog background
    scrollingFrame.BackgroundTransparency = 0 -- Or 1 if items have their own opaque backgrounds
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollingFrame.ScrollBarThickness = getMetric("PaddingSmall").Offset / 1.5
    scrollingFrame.ScrollBarImageColor3 = getColor("Border")
    scrollingFrame.Parent = dialog

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = getMetric("PaddingMedium", UDim.new(0,10))
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = scrollingFrame

    local totalContentHeight = 0
    local itemHeight = 85 -- Adjusted item height for new style

    if Constants.CURRENCY and Constants.CURRENCY.PRODUCTS and #Constants.CURRENCY.PRODUCTS > 0 then
        for i, productInfo in ipairs(Constants.CURRENCY.PRODUCTS) do
            local itemFrame = Instance.new("Frame")
            itemFrame.Name = productInfo.id or "ProductItemFrame" .. i
            itemFrame.Size = UDim2.new(1, 0, 0, itemHeight) -- Full width of scrolling frame
            itemFrame.BackgroundColor3 = getColor("BackgroundSecondary", Color3.fromRGB(44,44,46))
            itemFrame.BorderSizePixel = 0
            itemFrame.LayoutOrder = i
            itemFrame.Parent = scrollingFrame

            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = getMetric("CornerRadiusMedium", UDim.new(0,8))
            itemCorner.Parent = itemFrame
            
            local itemPadding = Instance.new("UIPadding")
            itemPadding.PaddingTop = getMetric("PaddingMedium")
            itemPadding.PaddingBottom = getMetric("PaddingMedium")
            itemPadding.PaddingLeft = getMetric("PaddingMedium")
            itemPadding.PaddingRight = getMetric("PaddingMedium")
            itemPadding.Parent = itemFrame

            -- Product Name (Larger)
            local productName = Instance.new("TextLabel")
            productName.Name = "ProductNameText"
            productName.Size = UDim2.new(0.65, 0, 0, getFontSize("Subtitle", 16) + 4) -- Adjusted size & space
            productName.Position = UDim2.new(0, 0, 0, 0)
            productName.BackgroundTransparency = 1
            productName.Font = getFont("Subtitle", Enum.Font.GothamMedium)
            productName.TextSize = getFontSize("Subtitle", 16)
            productName.TextColor3 = getColor("TextPrimary", Color3.fromRGB(245,245,245))
            productName.Text = productInfo.name or "Unknown Product"
            productName.TextXAlignment = Enum.TextXAlignment.Left
            productName.TextYAlignment = Enum.TextYAlignment.Top
            productName.Parent = itemFrame

            -- Product Description (Smaller, below name)
            local productDesc = Instance.new("TextLabel")
            productDesc.Name = "ProductDescriptionText"
            productDesc.Size = UDim2.new(0.65, 0, 0, getFontSize("Body", 14) * 2 + 4) -- Allow for two lines
            productDesc.Position = UDim2.new(0, 0, 0, productName.Size.Y.Offset + getMetric("PaddingTiny").Offset)
            productDesc.BackgroundTransparency = 1
            productDesc.Font = getFont("Body", Enum.Font.Gotham)
            productDesc.TextSize = getFontSize("Body", 14)
            productDesc.TextColor3 = getColor("TextSecondary", Color3.fromRGB(180,180,180))
            productDesc.Text = productInfo.description or ""
            productDesc.TextWrapped = true
            productDesc.TextXAlignment = Enum.TextXAlignment.Left
            productDesc.TextYAlignment = Enum.TextYAlignment.Top
            productDesc.Parent = itemFrame

            -- Robux Price (Below description)
            local robuxPrice = Instance.new("TextLabel")
            robuxPrice.Name = "RobuxPriceText"
            robuxPrice.Size = UDim2.new(0.65, 0, 0, getFontSize("BodyBold", 14) + 4)
            robuxPrice.Position = UDim2.new(0, 0, 1, -robuxPrice.Size.Y.Offset) -- Anchored to bottom of left column
            robuxPrice.BackgroundTransparency = 1
            robuxPrice.Font = getFont("BodyBold", Enum.Font.GothamBold)
            robuxPrice.TextSize = getFontSize("BodyBold", 14)
            robuxPrice.TextColor3 = getColor("ThemeAccent", Color3.fromRGB(255,193,7)) -- Accent for price
            robuxPrice.Text = "R$ " .. tostring(productInfo.robux or 0)
            robuxPrice.TextXAlignment = Enum.TextXAlignment.Left
            robuxPrice.TextYAlignment = Enum.TextYAlignment.Bottom
            robuxPrice.Parent = itemFrame
            
            -- Buy Button (Right side)
            local buyBtnStyle = Constants.UI.ButtonStyles.Primary
            local buyButton = Instance.new("TextButton")
            buyButton.Name = "BuyProductButton"
            buyButton.Size = UDim2.new(0.3, 0, 0, 36) -- Relative width, fixed height
            buyButton.AnchorPoint = Vector2.new(1, 0.5) -- Anchor to its own right-center for easier positioning
            buyButton.Position = UDim2.new(1, 0, 0.5, 0) -- Position anchor to parent's right-center. Parent padding will provide offset.
            buyButton.BackgroundColor3 = getColor(buyBtnStyle.BackgroundColor, getColor("ThemePrimary"))
            buyButton.Font = getFont("Button", Enum.Font.GothamBold)
            buyButton.TextSize = getFontSize("Button", 15)
            buyButton.TextColor3 = getColor(buyBtnStyle.TextColor, getColor("TextOnPrimary"))
            buyButton.Text = "BUY"
            buyButton.Parent = itemFrame

            local buyBtnItemCorner = Instance.new("UICorner")
            buyBtnItemCorner.CornerRadius = getMetric("CornerRadiusSmall", UDim.new(0,4))
            buyBtnItemCorner.Parent = buyButton
            
            buyButton.MouseButton1Click:Connect(function()
                if MarketplaceService and productInfo.assetId then
                    local successCall, errCall = pcall(function()
                        MarketplaceService:PromptProductPurchase(player, productInfo.assetId)
                    end)
                    if not successCall then
                        warn("Error calling PromptProductPurchase:", errCall)
                    end
                else
                    warn("MarketplaceService not available or product assetId missing for", productInfo.name)
                end
            end)
            totalContentHeight = totalContentHeight + itemHeight + listLayout.Padding.Offset
        end
        if #Constants.CURRENCY.PRODUCTS > 0 then -- Remove last padding if items exist
            totalContentHeight = totalContentHeight - listLayout.Padding.Offset
        end
    else
        local noProductsLabel = Instance.new("TextLabel")
        noProductsLabel.Name = "NoProductsLabel"
        noProductsLabel.Size = UDim2.new(1, 0, 0, 50)
        noProductsLabel.Position = UDim2.new(0, 0, 0, getMetric("PaddingLarge").Offset)
        noProductsLabel.BackgroundTransparency = 1
        noProductsLabel.Font = getFont("Body", Enum.Font.Gotham)
        noProductsLabel.TextSize = getFontSize("Body", 14)
        noProductsLabel.TextColor3 = getColor("TextSecondary", Color3.fromRGB(180,180,180))
        noProductsLabel.TextWrapped = true
        noProductsLabel.Text = "No currency products are currently available. Please check back later!"
        noProductsLabel.TextXAlignment = Enum.TextXAlignment.Center
        noProductsLabel.TextYAlignment = Enum.TextYAlignment.Center
        noProductsLabel.Parent = scrollingFrame
        totalContentHeight = 50 + listLayout.Padding.Offset * 2
    end
    
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, totalContentHeight)
end

return CurrencyUI
