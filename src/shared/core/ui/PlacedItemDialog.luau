-- PlacedItemDialog.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Constants)

local PlacedItemDialog = {}

-- UI Constants are now in Constants.lua
local currentItemInstance = nil -- Store the actual item instance

-- Create the dialog UI
local function createDialog(parent)
    local dialog = Instance.new("Frame")
    dialog.Name = "PlacedItemDialog"
    dialog.Size = UDim2.new(0, 300, 0, 400) -- Retaining size for now, can be moved to Constants.UI.Dialog.Size
    dialog.Position = UDim2.new(0.5, -150, 0.5, -200) -- Retaining pos, can be moved to Constants.UI.Dialog.Position
    dialog.BackgroundColor3 = Constants.UI.Colors.BackgroundPrimary -- Updated
    dialog.BorderSizePixel = 0
    dialog.Visible = false
    dialog.Parent = parent
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = dialog
    
    -- Add shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Constants.UI.Colors.BackgroundSecondary -- Updated
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = dialog
    
    -- Title bar (using TextLabel as a container)
    local titleBar = Instance.new("TextLabel") -- Changed from Frame to TextLabel for simplicity if it's just text
    titleBar.Name = "Title"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Constants.UI.Colors.ThemePrimary -- Updated
    titleBar.BorderSizePixel = 0
    titleBar.Font = Constants.UI.Fonts.Title.Font -- Updated
    titleBar.Text = "Item Actions" -- Default text
    titleBar.TextSize = Constants.UI.Fonts.Title.Size -- Updated
    titleBar.TextColor3 = Constants.UI.Colors.TextOnPrimary -- Updated
    titleBar.TextXAlignment = Enum.TextXAlignment.Center -- Centered title text
    titleBar.Parent = dialog
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0.5, -15) -- Centered vertically in title bar
    closeButton.BackgroundColor3 = Constants.UI.Colors.Error -- Updated
    closeButton.Font = Constants.UI.Fonts.Button.Font -- Updated
    closeButton.Text = "X"
    closeButton.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    closeButton.TextColor3 = Constants.UI.Colors.TextOnPrimary -- Updated
    closeButton.Parent = titleBar -- Parented to titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Actions container
    local actionsContainer = Instance.new("Frame")
    actionsContainer.Name = "ActionsContainer"
    actionsContainer.Size = UDim2.new(1, -40, 1, -70) -- Adjusted for padding
    actionsContainer.Position = UDim2.new(0, 20, 0, 60) -- Positioned below title
    actionsContainer.BackgroundTransparency = 1
    actionsContainer.Parent = dialog
    
    -- Action buttons will be populated by Show()
    
    return dialog
end

-- Initialize the dialog
function PlacedItemDialog.Initialize(parent)
    local dialog = createDialog(parent)
    
    PlacedItemDialog._dialog = dialog 
    PlacedItemDialog._currentItemId = nil 
    PlacedItemDialog._currentItemInstance = nil -- Added to store the instance

    -- Set up close button
    dialog.Title.CloseButton.MouseButton1Click:Connect(function()
        PlacedItemDialog.Hide()
    end)
    
    -- Action buttons are now connected in Show() after creation
end

-- Show the dialog
function PlacedItemDialog.Show(itemId, itemName, itemInstance) -- Added itemInstance
    local dialog = PlacedItemDialog._dialog
    if not dialog then return end
    
    PlacedItemDialog._currentItemId = itemId
    PlacedItemDialog._currentItemInstance = itemInstance -- Store the instance
    dialog.Title.Text = itemName or "Item Actions"

    local actionsContainer = dialog.ActionsContainer
    actionsContainer:ClearAllChildren() -- Clear previous buttons

    local itemBasePrice = 0
    if itemInstance then
        local price = itemInstance:GetAttribute("priceIngame")
        if type(price) == "number" then
            itemBasePrice = price
        else
            warn("PlacedItemDialog: itemInstance '" .. (itemInstance and itemInstance.Name or "nil") .. "' does not have a valid number 'priceIngame' attribute. Defaulting action costs to 0 or base multiplier.")
        end
    else
        warn("PlacedItemDialog: itemInstance is nil. Cannot determine item base price for actions.")
    end

    local buttonHeight = Constants.UI.Metrics.PaddingExtraLarge.Offset * 2.5 -- Example: 50
    local buttonPadding = Constants.UI.Metrics.PaddingSmall.Offset -- Example: 10
    local yOffset = 0

    for actionKey, actionData in pairs(Constants.ITEM_ACTIONS) do
        local actualCost = 0
        if itemBasePrice > 0 and actionData.costMultiplier then
            actualCost = math.floor(itemBasePrice * actionData.costMultiplier)
        elseif actionData.costMultiplier then -- If item has no price, but action has a multiplier (e.g. free item, but action still costs *something* based on a theoretical 0)
            actualCost = math.floor(0 * actionData.costMultiplier) -- Will be 0, but explicit
        end

        local button = Instance.new("TextButton")
        button.Name = actionData.name -- Use the display name
        button.Size = UDim2.new(1, 0, 0, buttonHeight)
        button.Position = UDim2.new(0, 0, 0, yOffset)
        yOffset = yOffset + buttonHeight + buttonPadding

        local styleDef = Constants.UI.ButtonStyles[actionData.styleKey or "Secondary"] -- Default to Secondary if no styleKey
        if type(actionData.style) == "table" then -- Inline style override
            styleDef = actionData.style
        end
        
        -- Determine BackgroundColor
        if type(styleDef.BackgroundColor) == "string" then
            button.BackgroundColor3 = Constants.UI.Colors[styleDef.BackgroundColor] or Constants.UI.Colors.BackgroundSecondary
        elseif type(styleDef.BackgroundColor) == "table" and styleDef.BackgroundColor.r then -- Check if it's a Color3-like table
             button.BackgroundColor3 = Color3.fromRGB(styleDef.BackgroundColor.r, styleDef.BackgroundColor.g, styleDef.BackgroundColor.b)
        else
            button.BackgroundColor3 = styleDef.BackgroundColor or Constants.UI.Colors.BackgroundSecondary -- Direct Color3 or fallback
        end

        -- Determine TextColor
        if type(styleDef.TextColor) == "string" then
            button.TextColor3 = Constants.UI.Colors[styleDef.TextColor] or Constants.UI.Colors.TextPrimary
        else
            button.TextColor3 = styleDef.TextColor or Constants.UI.Colors.TextPrimary -- Direct Color3 or fallback
        end
        
        button.Font = Constants.UI.Fonts.Button.Font
        button.TextSize = Constants.UI.Fonts.Button.Size
        button.Text = string.format("%s (Cost: %d)", actionData.name, actualCost)
        button.Parent = actionsContainer
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = Constants.UI.Metrics.CornerRadiusSmall
        buttonCorner.Parent = button
        
        -- Hover effect (simplified, assuming ButtonStyles define HoverBackgroundColor as Color3)
        local originalColor = button.BackgroundColor3
        local hoverColor = styleDef.HoverBackgroundColor or originalColor -- Fallback to original if no hover defined

        if hoverColor and originalColor then
            button.MouseEnter:Connect(function()
                TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), {BackgroundColor3 = hoverColor}):Play()
            end)
            button.MouseLeave:Connect(function()
                TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), {BackgroundColor3 = originalColor}):Play()
            end)
        end

        button.MouseButton1Click:Connect(function()
            if PlacedItemDialog.OnActionSelected and PlacedItemDialog._currentItemId then
                PlacedItemDialog.OnActionSelected(PlacedItemDialog._currentItemId, actionKey, PlacedItemDialog._currentItemInstance, actualCost) -- Pass actionKey, instance and actualCost
            end
            PlacedItemDialog.Hide()
        end)
    end
    
    -- Adjust dialog height based on number of buttons
    local numActions = 0
    for _ in pairs(Constants.ITEM_ACTIONS) do numActions = numActions + 1 end
    local totalButtonSpace = numActions * buttonHeight + (math.max(0, numActions - 1) * buttonPadding)
    local titleBarHeight = dialog.Title.AbsoluteSize.Y
    local dialogPadding = dialog.ActionsContainer.Position.Y.Offset + Constants.UI.Metrics.PaddingMedium.Offset -- Top padding of container + bottom padding for dialog
    
    dialog.Size = UDim2.new(dialog.Size.X.Scale, dialog.Size.X.Offset, 0, titleBarHeight + totalButtonSpace + dialogPadding)
    dialog.Position = UDim2.new(0.5, -dialog.AbsoluteSize.X / 2, 0.5, -dialog.AbsoluteSize.Y / 2) -- Recenter

    dialog.Visible = true
    dialog.BackgroundTransparency = 1 
    
    local showTween = TweenService:Create(dialog, TweenInfo.new(Constants.UI.DIALOG_ANIMATION_DURATION), {
        BackgroundTransparency = 0 -- Fade to normal background transparency
    })
    showTween:Play()
end

-- Hide the dialog
function PlacedItemDialog.Hide()
    local dialog = PlacedItemDialog._dialog
    if not dialog then return end
    
    local hideTween = TweenService:Create(dialog, TweenInfo.new(Constants.UI.DIALOG_ANIMATION_DURATION), {
        BackgroundTransparency = 1
    })
    
    hideTween.Completed:Connect(function()
        dialog.Visible = false
        PlacedItemDialog._currentItemId = nil 
        PlacedItemDialog._currentItemInstance = nil -- Clear instance
    end)
    
    hideTween:Play()
end

return PlacedItemDialog
