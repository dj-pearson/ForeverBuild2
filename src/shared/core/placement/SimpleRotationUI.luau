-- SimpleRotationUI.luau
-- Cross-platform rotation interface for item placement
-- Works on PC, Mobile, Tablet, and Console

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local SimpleRotationUI = {}
SimpleRotationUI.__index = SimpleRotationUI

function SimpleRotationUI.new()
    local self = setmetatable({}, SimpleRotationUI)
    
    -- State
    self.isActive = false
    self.currentRotation = 0
    self.rotationStep = 45 -- 45 degree increments for simplicity
    self.targetItem = nil
    
    -- UI elements
    self.screenGui = nil
    self.mainFrame = nil
    self.rotationDisplay = nil
    
    -- Callbacks
    self.onRotationChanged = nil
    self.onConfirm = nil
    self.onCancel = nil
    
    -- Input connections
    self.connections = {}
    
    return self
end

-- Show the rotation UI
function SimpleRotationUI:Show(item, onRotationChanged, onConfirm, onCancel)
    if self.isActive then
        self:Hide()
    end
    
    self.isActive = true
    self.targetItem = item
    self.onRotationChanged = onRotationChanged
    self.onConfirm = onConfirm
    self.onCancel = onCancel
    
    -- Get current rotation from item if possible
    if item then
        if item:IsA("Model") and item.PrimaryPart then
            local _, currentY, _ = item.PrimaryPart.CFrame:ToEulerAnglesXYZ()
            self.currentRotation = math.deg(currentY)
        elseif item:IsA("BasePart") then
            local _, currentY, _ = item.CFrame:ToEulerAnglesXYZ()
            self.currentRotation = math.deg(currentY)
        end
    end
    
    self:_CreateUI()
    self:_SetupInput()
    self:_UpdateDisplay()
    
    print("🔄 Simple Rotation UI: Activated")
end

-- Hide the rotation UI
function SimpleRotationUI:Hide()
    if not self.isActive then return end
    
    self.isActive = false
    self.targetItem = nil
    
    -- Clean up UI
    if self.screenGui then
        self.screenGui:Destroy()
        self.screenGui = nil
        self.mainFrame = nil
        self.rotationDisplay = nil
    end
    
    -- Disconnect input
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    print("🔄 Simple Rotation UI: Hidden")
end

-- Rotate by specified degrees
function SimpleRotationUI:Rotate(degrees)
    if not self.isActive then return end
    
    self.currentRotation = (self.currentRotation + degrees) % 360
    self:_UpdateDisplay()
    
    -- Apply rotation to item
    if self.targetItem and self.onRotationChanged then
        self.onRotationChanged(self.targetItem, self.currentRotation)
    end
    
    -- Add visual feedback
    self:_ShowRotationFeedback(degrees)
end

-- Set absolute rotation
function SimpleRotationUI:SetRotation(degrees)
    if not self.isActive then return end
    
    self.currentRotation = degrees % 360
    self:_UpdateDisplay()
    
    if self.targetItem and self.onRotationChanged then
        self.onRotationChanged(self.targetItem, self.currentRotation)
    end
end

-- Get current rotation
function SimpleRotationUI:GetRotation()
    return self.currentRotation
end

-- Confirm rotation
function SimpleRotationUI:Confirm()
    if not self.isActive then return end
    
    local finalRotation = self.currentRotation
    local item = self.targetItem
    local callback = self.onConfirm
    
    self:Hide()
    
    if callback then
        callback(item, finalRotation)
    end
end

-- Cancel rotation
function SimpleRotationUI:Cancel()
    if not self.isActive then return end
    
    local item = self.targetItem
    local callback = self.onCancel
    
    self:Hide()
    
    if callback then
        callback(item)
    end
end

-- Private: Create the UI
function SimpleRotationUI:_CreateUI()
    local player = Players.LocalPlayer
    if not player then return end
    
    -- Create ScreenGui
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "SimpleRotationUI"
    self.screenGui.DisplayOrder = 100
    self.screenGui.ResetOnSpawn = false
    self.screenGui.Parent = player.PlayerGui
    
    -- Main container frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "MainFrame"
    self.mainFrame.Size = UDim2.new(0, 300, 0, 120)
    self.mainFrame.Position = UDim2.new(0.5, -150, 0.8, -60)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.mainFrame.BackgroundTransparency = 0.1
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = self.screenGui
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.mainFrame
    
    -- Drop shadow effect
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, -2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = self.mainFrame.ZIndex - 1
    shadow.Parent = self.mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🔄 ROTATE ITEM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.TextStrokeTransparency = 0.5
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = self.mainFrame
    
    -- Rotation display
    self.rotationDisplay = Instance.new("TextLabel")
    self.rotationDisplay.Name = "RotationDisplay"
    self.rotationDisplay.Size = UDim2.new(1, 0, 0, 30)
    self.rotationDisplay.Position = UDim2.new(0, 0, 0, 30)
    self.rotationDisplay.BackgroundTransparency = 1
    self.rotationDisplay.Text = "0°"
    self.rotationDisplay.TextColor3 = Color3.fromRGB(100, 255, 100)
    self.rotationDisplay.TextSize = 20
    self.rotationDisplay.Font = Enum.Font.SourceSansBold
    self.rotationDisplay.TextXAlignment = Enum.TextXAlignment.Center
    self.rotationDisplay.Parent = self.mainFrame
    
    -- Button container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(1, -20, 0, 30)
    buttonContainer.Position = UDim2.new(0, 10, 0, 65)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = self.mainFrame
    
    -- Create buttons
    self:_CreateRotationButtons(buttonContainer)
    self:_CreateActionButtons(buttonContainer)
end

-- Private: Create rotation buttons
function SimpleRotationUI:_CreateRotationButtons(parent)
    -- Left rotate button (Counter-clockwise)
    local leftButton = self:_CreateButton("⟲", UDim2.new(0, 0, 0, 0), UDim2.new(0, 50, 1, 0), parent)
    leftButton.MouseButton1Click:Connect(function()
        self:Rotate(-self.rotationStep)
    end)
    
    -- Quick left (small rotation)
    local quickLeftButton = self:_CreateButton("◀", UDim2.new(0, 55, 0, 0), UDim2.new(0, 30, 1, 0), parent)
    quickLeftButton.MouseButton1Click:Connect(function()
        self:Rotate(-15) -- Smaller rotation
    end)
    
    -- Reset button
    local resetButton = self:_CreateButton("⌂", UDim2.new(0.5, -15, 0, 0), UDim2.new(0, 30, 1, 0), parent)
    resetButton.MouseButton1Click:Connect(function()
        self:SetRotation(0)
    end)
    
    -- Quick right (small rotation)
    local quickRightButton = self:_CreateButton("▶", UDim2.new(1, -85, 0, 0), UDim2.new(0, 30, 1, 0), parent)
    quickRightButton.MouseButton1Click:Connect(function()
        self:Rotate(15) -- Smaller rotation
    end)
    
    -- Right rotate button (Clockwise)
    local rightButton = self:_CreateButton("⟳", UDim2.new(1, -50, 0, 0), UDim2.new(0, 50, 1, 0), parent)
    rightButton.MouseButton1Click:Connect(function()
        self:Rotate(self.rotationStep)
    end)
end

-- Private: Create action buttons (Confirm/Cancel)
function SimpleRotationUI:_CreateActionButtons(parent)
    -- Cancel button
    local cancelButton = self:_CreateButton("✖", UDim2.new(0, 0, 1, 5), UDim2.new(0, 60, 0, 25), parent)
    cancelButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    cancelButton.MouseButton1Click:Connect(function()
        self:Cancel()
    end)
    
    -- Confirm button
    local confirmButton = self:_CreateButton("✓", UDim2.new(1, -60, 1, 5), UDim2.new(0, 60, 0, 25), parent)
    confirmButton.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
    confirmButton.MouseButton1Click:Connect(function()
        self:Confirm()
    end)
end

-- Private: Create a button with consistent styling
function SimpleRotationUI:_CreateButton(text, position, size, parent)
    local button = Instance.new("TextButton")
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 16
    button.Font = Enum.Font.SourceSansBold
    button.TextStrokeTransparency = 0.5
    button.Parent = parent
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(90, 90, 90)})
        tween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 70, 70)})
        tween:Play()
    end)
    
    -- Click feedback
    button.MouseButton1Down:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.05), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)})
        tween:Play()
    end)
    
    button.MouseButton1Up:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(90, 90, 90)})
        tween:Play()
    end)
    
    return button
end

-- Private: Setup input handling
function SimpleRotationUI:_SetupInput()
    -- Keyboard shortcuts (for PC users)
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isActive then return end
        
        if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left then
            -- Q or Left Arrow: Rotate left
            self:Rotate(-self.rotationStep)
        elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Right then
            -- E or Right Arrow: Rotate right
            self:Rotate(self.rotationStep)
        elseif input.KeyCode == Enum.KeyCode.R then
            -- R: Reset rotation
            self:SetRotation(0)
        elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space then
            -- Enter or Space: Confirm
            self:Confirm()
        elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
            -- Escape or Backspace: Cancel
            self:Cancel()
        end
    end)
    
    table.insert(self.connections, inputConnection)
    
    -- Touch/Gamepad support - scroll wheel for rotation
    if UserInputService.TouchEnabled or UserInputService.GamepadEnabled then
        local scrollConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
            if gameProcessed or not self.isActive then return end
            
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local direction = input.Position.Z > 0 and 1 or -1
                self:Rotate(direction * 15) -- Smaller increments for scroll
            end
        end)
        
        table.insert(self.connections, scrollConnection)
    end
end

-- Private: Update the rotation display
function SimpleRotationUI:_UpdateDisplay()
    if not self.rotationDisplay then return end
    
    -- Format rotation nicely
    local displayRotation = math.floor(self.currentRotation + 0.5) % 360
    self.rotationDisplay.Text = string.format("%d°", displayRotation)
    
    -- Color code the rotation
    if displayRotation == 0 then
        self.rotationDisplay.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green for 0°
    elseif displayRotation % 90 == 0 then
        self.rotationDisplay.TextColor3 = Color3.fromRGB(100, 200, 255) -- Blue for 90° increments
    else
        self.rotationDisplay.TextColor3 = Color3.fromRGB(255, 255, 100) -- Yellow for other angles
    end
end

-- Private: Show visual feedback for rotation
function SimpleRotationUI:_ShowRotationFeedback(degrees)
    if not self.rotationDisplay then return end
    
    -- Create a temporary feedback label
    local feedback = Instance.new("TextLabel")
    feedback.Size = UDim2.new(0, 60, 0, 20)
    feedback.Position = UDim2.new(0.5, -30, 0.5, -10)
    feedback.BackgroundTransparency = 1
    feedback.Text = (degrees > 0 and "+" or "") .. degrees .. "°"
    feedback.TextColor3 = degrees > 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    feedback.TextSize = 14
    feedback.Font = Enum.Font.SourceSansBold
    feedback.TextStrokeTransparency = 0
    feedback.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    feedback.TextXAlignment = Enum.TextXAlignment.Center
    feedback.Parent = self.rotationDisplay
    
    -- Animate the feedback
    local tween1 = TweenService:Create(feedback, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -30, 0.5, -25),
        TextTransparency = 0.7
    })
    
    local tween2 = TweenService:Create(feedback, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        TextTransparency = 1
    })
    
    tween1:Play()
    tween1.Completed:Connect(function()
        tween2:Play()
        tween2.Completed:Connect(function()
            feedback:Destroy()
        end)
    end)
end

-- Check if UI is currently active
function SimpleRotationUI:IsActive()
    return self.isActive
end

return SimpleRotationUI 