-- PlacedItemDialog.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Constants)

local PlacedItemDialog = {}

-- UI Constants are now in Constants.lua

-- Create the dialog UI
local function createDialog(parent)
    local dialog = Instance.new("Frame")
    dialog.Name = "PlacedItemDialog"
    dialog.Size = UDim2.new(0, 300, 0, 400) -- Retaining size for now, can be moved to Constants.UI.Dialog.Size
    dialog.Position = UDim2.new(0.5, -150, 0.5, -200) -- Retaining pos, can be moved to Constants.UI.Dialog.Position
    dialog.BackgroundColor3 = Constants.UI.Colors.Background -- Updated
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
    shadow.ImageColor3 = Constants.UI.Colors.Text -- Updated
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
    titleBar.BackgroundColor3 = Constants.UI.Colors.Text -- Updated
    titleBar.BorderSizePixel = 0
    titleBar.Font = Constants.UI.Fonts.Title.Font -- Updated
    titleBar.Text = "Item Actions" -- Default text
    titleBar.TextSize = Constants.UI.Fonts.Title.Size -- Updated
    titleBar.TextColor3 = Constants.UI.Colors.Background -- Updated
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
    closeButton.TextColor3 = Constants.UI.Colors.Background -- Updated
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
    
    -- Define actions with new styling strategy
    local itemActions = {
        { name = "Clone", style = Constants.UI.ButtonStyles.Secondary, costKey = "clone" },
        { name = "Move", style = Constants.UI.ButtonStyles.Primary, costKey = "move" },
        { name = "Rotate", style = { BackgroundColor = "Accent", TextColor = "Background", HoverColor = Constants.UI.Colors.Primary }, costKey = "rotate" }, -- Custom style for Accent
        { name = "Destroy", style = { BackgroundColor = "Error", TextColor = "Background", HoverColor = Color3.fromRGB(192, 57, 43) }, costKey = "destroy" } -- Custom style for Error
    }
    
    local buttonHeight = 50 -- Can be moved to Constants.UI.Button.Height
    local buttonPadding = 10 -- Can be moved to Constants.UI.Button.Padding

    for i, actionData in ipairs(itemActions) do
        local cost = Constants.ITEM_ACTIONS[actionData.costKey] and Constants.ITEM_ACTIONS[actionData.costKey].cost or 0
        local button = Instance.new("TextButton")
        button.Name = actionData.name
        button.Size = UDim2.new(1, 0, 0, buttonHeight)
        button.Position = UDim2.new(0, 0, 0, (i-1) * (buttonHeight + buttonPadding))
        
        local style = actionData.style
        button.BackgroundColor3 = Constants.UI.Colors[style.BackgroundColor]
        button.TextColor3 = Constants.UI.Colors[style.TextColor]
        button.Font = Constants.UI.Fonts.Button.Font
        button.TextSize = Constants.UI.Fonts.Button.Size
        button.Text = string.format("%s (%d)", actionData.name, cost)
        button.Parent = actionsContainer
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = button
        
        -- Hover effect
        local originalColor = button.BackgroundColor3
        local hoverColor = style.HoverColor
        if type(hoverColor) == "string" then -- if hovercolor is a key for Constants.UI.Colors
             hoverColor = Constants.UI.Colors[hoverColor]
        end

        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), {
                BackgroundColor3 = hoverColor
            }):Play()
        end)
        
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), {
                BackgroundColor3 = originalColor
            }):Play()
        end)
    end
    
    return dialog
end

-- Initialize the dialog
function PlacedItemDialog.Initialize(parent)
    local dialog = createDialog(parent)
    local currentItemId = nil -- Moved this inside Initialize to keep it local to the instance scope if multiple dialogs were ever needed
    
    PlacedItemDialog._dialog = dialog -- Keep static reference for module functions
    PlacedItemDialog._currentItemId = nil -- Store currentItemId at module level for Show/Hide

    -- Set up close button
    dialog.Title.CloseButton.MouseButton1Click:Connect(function()
        PlacedItemDialog.Hide()
    end)
    
    -- Set up action buttons
    for _, button in ipairs(dialog.ActionsContainer:GetChildren()) do
        if button:IsA("TextButton") then
            button.MouseButton1Click:Connect(function()
                if PlacedItemDialog.OnActionSelected and PlacedItemDialog._currentItemId then
                    PlacedItemDialog.OnActionSelected(PlacedItemDialog._currentItemId, button.Name:lower())
                end
                PlacedItemDialog.Hide()
            end)
        end
    end
end

-- Show the dialog
function PlacedItemDialog.Show(itemId, itemName)
    local dialog = PlacedItemDialog._dialog
    if not dialog then return end
    
    PlacedItemDialog._currentItemId = itemId -- Use module-level storage
    dialog.Title.Text = itemName or "Item Actions" -- Title TextLabel's Text property
    
    -- Show dialog with animation
    dialog.Visible = true
    dialog.BackgroundTransparency = 1 -- Start fully transparent
    
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
        PlacedItemDialog._currentItemId = nil -- Clear itemID when hidden
    end)
    
    hideTween:Play()
end

return PlacedItemDialog
