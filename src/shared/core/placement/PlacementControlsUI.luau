-- PlacementControlsUI.luau
-- Shows clear controls during item placement in bottom left corner
-- Works across all platforms and shows all available actions

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local PlacementControlsUI = {}
PlacementControlsUI.__index = PlacementControlsUI

function PlacementControlsUI.new()
    local self = setmetatable({}, PlacementControlsUI)
    
    -- State
    self.isActive = false
    self.screenGui = nil
    self.mainFrame = nil
    self.controlsList = nil
    
    -- Callbacks
    self.onRotate = nil
    self.onPlace = nil
    self.onCancel = nil
    
    -- Input connections
    self.connections = {}
    
    return self
end

-- Show the placement controls UI
function PlacementControlsUI:Show(itemName, onRotate, onPlace, onCancel)
    if self.isActive then
        self:Hide()
    end
    
    self.isActive = true
    self.onRotate = onRotate
    self.onPlace = onPlace
    self.onCancel = onCancel
    
    self:_CreateUI(itemName)
    self:_SetupInput()
    
    print("🎮 Placement Controls: Activated for", itemName)
end

-- Hide the controls UI
function PlacementControlsUI:Hide()
    if not self.isActive then return end
    
    self.isActive = false
    
    -- Clean up UI with fade out
    if self.screenGui then
        local fadeOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.2), {
            Position = UDim2.new(0, -20, 1, -10),
            BackgroundTransparency = 1
        })
        
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            self.screenGui:Destroy()
            self.screenGui = nil
            self.mainFrame = nil
            self.controlsList = nil
        end)
    end
    
    -- Disconnect input
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    print("🎮 Placement Controls: Hidden")
end

-- Update the item name in the UI
function PlacementControlsUI:UpdateItemName(itemName)
    if not self.isActive or not self.mainFrame then return end
    
    local titleLabel = self.mainFrame:FindFirstChild("ItemTitle")
    if titleLabel then
        titleLabel.Text = "Placing: " .. itemName
    end
end

-- Private: Create the UI
function PlacementControlsUI:_CreateUI(itemName)
    local player = Players.LocalPlayer
    if not player then return end
    
    -- Create ScreenGui
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "PlacementControlsUI"
    self.screenGui.DisplayOrder = 50
    self.screenGui.ResetOnSpawn = false
    self.screenGui.Parent = player.PlayerGui
    
    -- Main container frame (bottom left)
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "MainFrame"
    self.mainFrame.Size = UDim2.new(0, 280, 0, 215)
    self.mainFrame.Position = UDim2.new(0, 20, 1, -200)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    self.mainFrame.BackgroundTransparency = 0.15
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = self.screenGui
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.mainFrame
    
    -- Drop shadow
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 6, 1, 6)
    shadow.Position = UDim2.new(0, -3, 0, 3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6
    shadow.BorderSizePixel = 0
    shadow.ZIndex = self.mainFrame.ZIndex - 1
    shadow.Parent = self.mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Item title
    local itemTitle = Instance.new("TextLabel")
    itemTitle.Name = "ItemTitle"
    itemTitle.Size = UDim2.new(1, -20, 0, 25)
    itemTitle.Position = UDim2.new(0, 10, 0, 8)
    itemTitle.BackgroundTransparency = 1
    itemTitle.Text = "Placing: " .. itemName
    itemTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
    itemTitle.TextSize = 14
    itemTitle.TextStrokeTransparency = 0.5
    itemTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    itemTitle.Font = Enum.Font.SourceSansBold
    itemTitle.TextXAlignment = Enum.TextXAlignment.Left
    itemTitle.Parent = self.mainFrame
    
    -- Controls title
    local controlsTitle = Instance.new("TextLabel")
    controlsTitle.Name = "ControlsTitle"
    controlsTitle.Size = UDim2.new(1, -20, 0, 20)
    controlsTitle.Position = UDim2.new(0, 10, 0, 35)
    controlsTitle.BackgroundTransparency = 1
    controlsTitle.Text = "🎮 CONTROLS:"
    controlsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    controlsTitle.TextSize = 12
    controlsTitle.Font = Enum.Font.SourceSansBold
    controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
    controlsTitle.Parent = self.mainFrame
    
    -- Controls list container
    self.controlsList = Instance.new("Frame")
    self.controlsList.Name = "ControlsList"
    self.controlsList.Size = UDim2.new(1, -20, 0, 150)
    self.controlsList.Position = UDim2.new(0, 10, 0, 60)
    self.controlsList.BackgroundTransparency = 1
    self.controlsList.Parent = self.mainFrame
    
    -- Create control entries
    self:_CreateControlEntries()
    
    -- Animate in
    self.mainFrame.Position = UDim2.new(0, -300, 1, -200)
    local slideIn = TweenService:Create(self.mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 20, 1, -200)
    })
    slideIn:Play()
end

-- Private: Create individual control entries
function PlacementControlsUI:_CreateControlEntries()
    if not self.controlsList then return end
    
    -- Detect platform for appropriate controls
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isConsole = UserInputService.GamepadEnabled
    
    -- Control entries data
    local controls = {
        {
            icon = "🖱️",
            key = "LEFT CLICK",
            action = "Place Item",
            color = Color3.fromRGB(100, 255, 100)
        },
        {
            icon = "🔄",
            key = isMobile and "SCROLL/TAP" or (isConsole and "L1/R1" or "Q&E"),
            action = "Yaw (Left/Right)",
            color = Color3.fromRGB(255, 200, 100)
        },
        {
            icon = "🔺",
            key = isMobile and "SHIFT+SCROLL" or (isConsole and "R2+L1/R1" or "SHIFT+Q&E"),
            action = "Pitch (Up/Down)",
            color = Color3.fromRGB(255, 150, 100)
        },
        {
            icon = "🌀",
            key = isMobile and "CTRL+SCROLL" or (isConsole and "L2+L1/R1" or "CTRL+Q&E"),
            action = "Roll (Spin)",
            color = Color3.fromRGB(255, 100, 150)
        },
        {
            icon = "🎛️",
            key = isMobile and "TAP FINE" or "SPACE",
            action = "Fine Rotation UI",
            color = Color3.fromRGB(100, 255, 255)
        },
        {
            icon = "📦",
            key = isMobile and "TAP CANCEL" or "RIGHT CLICK",
            action = "Return to Inventory",
            color = Color3.fromRGB(255, 100, 100)
        }
    }
    
    -- Add console-specific controls
    if isConsole then
        controls[1].key = "A BUTTON"
        controls[2].key = "LB/RB BUMPERS"
        controls[3].key = "Y BUTTON"
        controls[4].key = "B BUTTON"
    end
    
    -- Create control entries
    for i, control in ipairs(controls) do
        local yPos = (i - 1) * 35
        
        -- Background for each control
        local controlBg = Instance.new("Frame")
        controlBg.Name = "Control" .. i
        controlBg.Size = UDim2.new(1, 0, 0, 30)
        controlBg.Position = UDim2.new(0, 0, 0, yPos)
        controlBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        controlBg.BackgroundTransparency = 0.3
        controlBg.BorderSizePixel = 0
        controlBg.Parent = self.controlsList
        
        local controlCorner = Instance.new("UICorner")
        controlCorner.CornerRadius = UDim.new(0, 6)
        controlCorner.Parent = controlBg
        
        -- Icon
        local iconLabel = Instance.new("TextLabel")
        iconLabel.Size = UDim2.new(0, 25, 1, 0)
        iconLabel.Position = UDim2.new(0, 5, 0, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = control.icon
        iconLabel.TextColor3 = control.color
        iconLabel.TextSize = 16
        iconLabel.Font = Enum.Font.SourceSansBold
        iconLabel.TextXAlignment = Enum.TextXAlignment.Center
        iconLabel.TextYAlignment = Enum.TextYAlignment.Center
        iconLabel.Parent = controlBg
        
        -- Key/Button
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(0, 80, 1, 0)
        keyLabel.Position = UDim2.new(0, 35, 0, 0)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Text = control.key
        keyLabel.TextColor3 = control.color
        keyLabel.TextSize = 10
        keyLabel.Font = Enum.Font.SourceSansBold
        keyLabel.TextXAlignment = Enum.TextXAlignment.Left
        keyLabel.TextYAlignment = Enum.TextYAlignment.Center
        keyLabel.Parent = controlBg
        
        -- Action description
        local actionLabel = Instance.new("TextLabel")
        actionLabel.Size = UDim2.new(1, -120, 1, 0)
        actionLabel.Position = UDim2.new(0, 120, 0, 0)
        actionLabel.BackgroundTransparency = 1
        actionLabel.Text = control.action
        actionLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        actionLabel.TextSize = 10
        actionLabel.Font = Enum.Font.SourceSans
        actionLabel.TextXAlignment = Enum.TextXAlignment.Left
        actionLabel.TextYAlignment = Enum.TextYAlignment.Center
        actionLabel.Parent = controlBg
        
        -- Add hover effect for interactive controls
        if i == 3 then -- Fine rotation UI button
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 1, 0)
            button.Position = UDim2.new(0, 0, 0, 0)
            button.BackgroundTransparency = 1
            button.Text = ""
            button.Parent = controlBg
            
            button.MouseButton1Click:Connect(function()
                if self.onRotate then
                    self.onRotate()
                end
            end)
            
            button.MouseEnter:Connect(function()
                local tween = TweenService:Create(controlBg, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(40, 60, 60)
                })
                tween:Play()
            end)
            
            button.MouseLeave:Connect(function()
                local tween = TweenService:Create(controlBg, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                })
                tween:Play()
            end)
        elseif i == 4 then -- Cancel button
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 1, 0)
            button.Position = UDim2.new(0, 0, 0, 0)
            button.BackgroundTransparency = 1
            button.Text = ""
            button.Parent = controlBg
            
            button.MouseButton1Click:Connect(function()
                if self.onCancel then
                    self.onCancel()
                end
            end)
            
            button.MouseEnter:Connect(function()
                local tween = TweenService:Create(controlBg, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(60, 40, 40)
                })
                tween:Play()
            end)
            
            button.MouseLeave:Connect(function()
                local tween = TweenService:Create(controlBg, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                })
                tween:Play()
            end)
        end
    end
end

-- Private: Setup input handling
function PlacementControlsUI:_SetupInput()
    -- Keyboard input
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isActive then return end
        
        if input.KeyCode == Enum.KeyCode.Space then
            -- Space: Trigger rotation
            if self.onRotate then
                self.onRotate()
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click: Place item (handled by placement manager)
            if self.onPlace then
                self.onPlace()
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or Escape: Cancel/Return to inventory
            if self.onCancel then
                self.onCancel()
            end
        end
    end)
    
    table.insert(self.connections, inputConnection)
    
    -- Gamepad support
    if UserInputService.GamepadEnabled then
        local gamepadConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not self.isActive then return end
            
            if input.KeyCode == Enum.KeyCode.ButtonA then
                -- A button: Place item
                if self.onPlace then
                    self.onPlace()
                end
            elseif input.KeyCode == Enum.KeyCode.ButtonY then
                -- Y button: Rotate
                if self.onRotate then
                    self.onRotate()
                end
            elseif input.KeyCode == Enum.KeyCode.ButtonB then
                -- B button: Cancel
                if self.onCancel then
                    self.onCancel()
                end
            end
        end)
        
        table.insert(self.connections, gamepadConnection)
    end
end

-- Check if UI is currently active
function PlacementControlsUI:IsActive()
    return self.isActive
end

-- Pulse a specific control to highlight it
function PlacementControlsUI:PulseControl(controlIndex)
    if not self.controlsList then return end
    
    local control = self.controlsList:FindFirstChild("Control" .. controlIndex)
    if control then
        local originalColor = control.BackgroundColor3
        local pulse = TweenService:Create(control, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {
            BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        })
        pulse:Play()
        pulse.Completed:Connect(function()
            control.BackgroundColor3 = originalColor
        end)
    end
end

return PlacementControlsUI 