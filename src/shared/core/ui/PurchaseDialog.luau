-- PurchaseDialog.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Constants)

local PurchaseDialog = {}

-- UI Constants are now in Constants.lua

-- Create the dialog UI
local function createDialog(parent)
    local dialog = Instance.new("Frame")
    dialog.Name = "PurchaseDialog"
    dialog.Size = UDim2.new(0, 400, 0, 350) -- Adjusted height for new title bar and spacing
    dialog.Position = UDim2.new(0.5, -200, 0.5, -175) -- Adjusted for new size
    dialog.BackgroundColor3 = Constants.UI.Colors.BackgroundSecondary -- Updated (was Background)
    dialog.BorderSizePixel = 0
    dialog.Visible = false
    dialog.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = dialog
    
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Constants.UI.Colors.BackgroundPrimary -- Updated (was Text, using a dark shadow)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = dialog

    -- TitleBar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Constants.UI.Colors.ThemePrimary -- Updated (was Text, now using a theme color)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = dialog

    local titleBarCorner = Instance.new("UICorner") -- Apply corner to top part of dialog only
    titleBarCorner.CornerRadius = UDim.new(0,8)
    titleBarCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 1, 0) -- Padding inside title bar
    title.Position = UDim2.new(0, 10, 0, 0) -- Padding
    title.BackgroundTransparency = 1
    title.Font = Constants.UI.Fonts.Title.Font -- Updated
    title.TextSize = Constants.UI.Fonts.Title.Size -- Updated
    title.TextColor3 = Constants.UI.Colors.TextOnPrimary -- Updated (was Background)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Item info
    local itemInfo = Instance.new("TextLabel")
    itemInfo.Name = "ItemInfo"
    itemInfo.Size = UDim2.new(1, -40, 0, 60)
    itemInfo.Position = UDim2.new(0, 20, 0, 60) -- Below title bar
    itemInfo.BackgroundTransparency = 1
    itemInfo.Font = Constants.UI.Fonts.Default.Font -- Updated
    itemInfo.TextSize = Constants.UI.Fonts.Default.Size -- Updated
    itemInfo.TextColor3 = Constants.UI.Colors.TextPrimary -- Updated (was Text)
    itemInfo.TextWrapped = true
    itemInfo.TextYAlignment = Enum.TextYAlignment.Top
    itemInfo.Parent = dialog
    
    -- Price
    local price = Instance.new("TextLabel")
    price.Name = "Price"
    price.Size = UDim2.new(1, -40, 0, 30)
    price.Position = UDim2.new(0, 20, 0, 130) -- Below item info
    price.BackgroundTransparency = 1
    price.Font = Constants.UI.Fonts.Button.Font -- Updated
    price.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    price.TextColor3 = Constants.UI.Colors.ThemeAccent -- Updated (was Accent)
    price.TextXAlignment = Enum.TextXAlignment.Left
    price.Parent = dialog
    
    -- Quantity selector
    local quantityFrame = Instance.new("Frame")
    quantityFrame.Name = "QuantityFrame"
    quantityFrame.Size = UDim2.new(1, -40, 0, 40)
    quantityFrame.Position = UDim2.new(0, 20, 0, 170) -- Below price
    quantityFrame.BackgroundTransparency = 1
    quantityFrame.Parent = dialog
    
    local minusButton = Instance.new("TextButton")
    minusButton.Name = "MinusButton"
    minusButton.Size = UDim2.new(0, 40, 1, 0)
    minusButton.Position = UDim2.new(0, 0, 0, 0)
    minusButton.BackgroundColor3 = Constants.UI.Colors.BackgroundTertiary -- Updated (was Text)
    minusButton.Font = Constants.UI.Fonts.Button.Font -- Updated
    minusButton.Text = "-"
    minusButton.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    minusButton.TextColor3 = Constants.UI.Colors.TextPrimary -- Updated (was Background)
    minusButton.Parent = quantityFrame
    
    local quantityLabel = Instance.new("TextLabel")
    quantityLabel.Name = "Quantity"
    quantityLabel.Size = UDim2.new(1, -100, 1, 0) -- Space between buttons
    quantityLabel.Position = UDim2.new(0, 50, 0, 0)
    quantityLabel.BackgroundTransparency = 1
    quantityLabel.Font = Constants.UI.Fonts.Button.Font -- Updated
    quantityLabel.Text = "1"
    quantityLabel.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    quantityLabel.TextColor3 = Constants.UI.Colors.TextPrimary -- Updated (was Text)
    quantityLabel.TextXAlignment = Enum.TextXAlignment.Center
    quantityLabel.Parent = quantityFrame
    
    local plusButton = Instance.new("TextButton")
    plusButton.Name = "PlusButton"
    plusButton.Size = UDim2.new(0, 40, 1, 0)
    plusButton.Position = UDim2.new(1, -40, 0, 0)
    plusButton.BackgroundColor3 = Constants.UI.Colors.BackgroundTertiary -- Updated (was Text)
    plusButton.Font = Constants.UI.Fonts.Button.Font -- Updated
    plusButton.Text = "+"
    plusButton.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    plusButton.TextColor3 = Constants.UI.Colors.TextPrimary -- Updated (was Background)
    plusButton.Parent = quantityFrame
    
    local btnCorner = Instance.new("UICorner") btnCorner.CornerRadius = UDim.new(0,4) btnCorner.Parent = minusButton
    local plsBtnCorner = btnCorner:Clone() plsBtnCorner.Parent = plusButton

    -- Hover for +/- buttons
    local function setupButtonHover(button, hoverColor)
        local originalColor = button.BackgroundColor3
        button.MouseEnter:Connect(function() TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), {BackgroundColor3 = hoverColor}):Play() end)
        button.MouseLeave:Connect(function() TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), {BackgroundColor3 = originalColor}):Play() end)
    end
    setupButtonHover(minusButton, Constants.UI.Colors.ThemePrimary) -- Updated (was Primary)
    setupButtonHover(plusButton, Constants.UI.Colors.ThemePrimary) -- Updated (was Primary)

    -- Buttons Frame
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Size = UDim2.new(1, -40, 0, 50) -- Increased height for better touch
    buttonFrame.Position = UDim2.new(0, 20, 1, -70) -- At the bottom
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = dialog
    
    local cancelButton = Instance.new("TextButton")
    cancelButton.Name = "CancelButton"
    cancelButton.Size = UDim2.new(0.5, -5, 1, 0) -- Half width with padding
    cancelButton.Position = UDim2.new(0, 0, 0, 0)
    cancelButton.BackgroundColor3 = Constants.UI.Colors.BackgroundTertiary -- Updated (was Text)
    cancelButton.Font = Constants.UI.Fonts.Button.Font -- Updated
    cancelButton.Text = "Cancel"
    cancelButton.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    cancelButton.TextColor3 = Constants.UI.Colors.TextPrimary -- Updated (was Background)
    cancelButton.Parent = buttonFrame
    setupButtonHover(cancelButton, Constants.UI.Colors.ThemeSecondary) -- Updated (was Secondary)

    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0.5, -5, 1, 0) -- Half width with padding
    purchaseButton.Position = UDim2.new(0.5, 5, 0, 0)
    purchaseButton.BackgroundColor3 = Constants.UI.Colors[Constants.UI.ButtonStyles.Primary.BackgroundColor] -- This should be correct if ButtonStyles.Primary.BackgroundColor is "ThemePrimary"
    purchaseButton.Font = Constants.UI.Fonts.Button.Font -- Updated
    purchaseButton.Text = "Purchase"
    purchaseButton.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    purchaseButton.TextColor3 = Constants.UI.Colors[Constants.UI.ButtonStyles.Primary.TextColor] -- Updated (was Background, now TextOnPrimary)
    purchaseButton.Parent = buttonFrame
    setupButtonHover(purchaseButton, Constants.UI.ButtonStyles.Primary.HoverBackgroundColor) -- Updated (was HoverColor)

    local cancelCorner = btnCorner:Clone() cancelCorner.Parent = cancelButton
    local purchaseCorner = btnCorner:Clone() purchaseCorner.Parent = purchaseButton
    
    return dialog
end

local currentItemName_PurchaseDialog -- Module level variable to hold current item name for ShowError
local originalItemInfoColor_PurchaseDialog -- Module level variable to hold original text color

-- Initialize the dialog
function PurchaseDialog.Initialize(parent)
    local dialog = createDialog(parent)
    local quantity = 1
    -- local currentItem = nil -- Handled by currentItemName_PurchaseDialog
    local onPurchaseCallback = nil -- Renamed for clarity
    
    originalItemInfoColor_PurchaseDialog = Constants.UI.Colors.TextPrimary -- Store default color (was Text)

    local function updatePriceDisplay()
        if not currentItemName_PurchaseDialog then return end
        local itemData = Constants.ITEMS[currentItemName_PurchaseDialog]
        if not itemData then return end
        
        local totalPrice = itemData.price * quantity
        dialog.Price.Text = string.format("Price: %d", totalPrice)
    end
    
    local function updateQuantityDisplay(newQuantity)
        quantity = math.max(1, math.min(99, newQuantity)) -- Clamp quantity
        dialog.QuantityFrame.Quantity.Text = tostring(quantity)
        updatePriceDisplay()
    end
    
    dialog.QuantityFrame.MinusButton.MouseButton1Click:Connect(function() updateQuantityDisplay(quantity - 1) end)
    dialog.QuantityFrame.PlusButton.MouseButton1Click:Connect(function() updateQuantityDisplay(quantity + 1) end)
    
    dialog.ButtonFrame.PurchaseButton.MouseButton1Click:Connect(function()
        if onPurchaseCallback then
            onPurchaseCallback(currentItemName_PurchaseDialog, quantity) -- Pass item name and quantity
        end
        PurchaseDialog.Hide()
    end)
    
    dialog.ButtonFrame.CancelButton.MouseButton1Click:Connect(function() PurchaseDialog.Hide() end)
    
    PurchaseDialog._dialog = dialog
    PurchaseDialog._updateQuantityDisplay = updateQuantityDisplay -- Expose for Show
    PurchaseDialog._onPurchaseCallback = nil -- Store callback at module level
end

-- Show the dialog
function PurchaseDialog.Show(itemName, callback)
    local dialog = PurchaseDialog._dialog
    if not dialog then return end
    
    local itemData = Constants.ITEMS[itemName]
    if not itemData then 
        print("Error: Item data not found for", itemName)
        return 
    end
    
    currentItemName_PurchaseDialog = itemName
    PurchaseDialog._onPurchaseCallback = callback -- Store the callback

    dialog.Title.Text = itemName
    dialog.ItemInfo.Text = itemData.description or "No description available"
    dialog.ItemInfo.TextColor3 = originalItemInfoColor_PurchaseDialog -- Reset to default color
    
    if PurchaseDialog._updateQuantityDisplay then PurchaseDialog._updateQuantityDisplay(1) end -- Reset quantity and update price
    
    dialog.Visible = true
    dialog.BackgroundTransparency = 1
    local showTween = TweenService:Create(dialog, TweenInfo.new(Constants.UI.DIALOG_ANIMATION_DURATION), { BackgroundTransparency = 0 })
    showTween:Play()
end

-- Hide the dialog
function PurchaseDialog.Hide()
    local dialog = PurchaseDialog._dialog
    if not dialog or not dialog.Visible then return end -- Added check for visibility
    
    local hideTween = TweenService:Create(dialog, TweenInfo.new(Constants.UI.DIALOG_ANIMATION_DURATION), { BackgroundTransparency = 1 })
    hideTween.Completed:Connect(function()
        if dialog then dialog.Visible = false end -- Ensure dialog still exists
        currentItemName_PurchaseDialog = nil -- Clear current item when hidden
        PurchaseDialog._onPurchaseCallback = nil -- Clear callback
    end)
    hideTween:Play()
end

-- Show error message
function PurchaseDialog.ShowError(message)
    local dialog = PurchaseDialog._dialog
    if not dialog then return end
    
    dialog.ItemInfo.Text = "Error: " .. message
    dialog.ItemInfo.TextColor3 = Constants.UI.Colors.Error -- Updated
    
    task.delay(Constants.UI.ERROR_DISPLAY_DURATION, function() -- Updated
        if dialog and dialog.ItemInfo and currentItemName_PurchaseDialog then -- Check if dialog still exists and showing an item
            local itemData = Constants.ITEMS[currentItemName_PurchaseDialog]
            if itemData then 
                dialog.ItemInfo.Text = itemData.description or "No description available"
            else
                 dialog.ItemInfo.Text = ""
            end
dialog.ItemInfo.TextColor3 = originalItemInfoColor_PurchaseDialog -- Reset to default color
        elseif dialog and dialog.ItemInfo then -- Dialog is open but no specific item (e.g. general error)
            dialog.ItemInfo.Text = "" -- Clear error or set to a generic message
            dialog.ItemInfo.TextColor3 = originalItemInfoColor_PurchaseDialog -- Reset to default color
        end
    end)
end

return PurchaseDialog
