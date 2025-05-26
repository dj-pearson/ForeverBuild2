-- RotationController.luau
-- Handles rotation functionality for items during placement and for placed items

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local RotationController = {}
RotationController.__index = RotationController

function RotationController.new()
    local self = setmetatable({}, RotationController)
    
    -- Rotation state
    self.isRotating = false
    self.targetItem = nil
    self.baseRotation = 0 -- Base Y rotation in degrees
    self.rotationStep = 15 -- Degrees per rotation step
    self.maxRotation = 360 -- Maximum rotation
    
    -- Input connections
    self.inputConnection = nil
    self.renderConnection = nil
    
    -- Visual feedback
    self.rotationUI = nil
    
    return self
end

-- Start rotating an item (preview or placed)
function RotationController:StartRotation(item, onConfirm, onCancel)
    if self.isRotating then
        self:StopRotation()
    end
    
    if not item then
        warn("RotationController: No item provided for rotation")
        return false
    end
    
    self.isRotating = true
    self.targetItem = item
    self.onConfirm = onConfirm
    self.onCancel = onCancel
    
    -- Store initial rotation
    if item:IsA("Model") and item.PrimaryPart then
        local _, currentY, _ = item.PrimaryPart.CFrame:ToEulerAnglesXYZ()
        self.baseRotation = math.deg(currentY)
    elseif item:IsA("BasePart") then
        local _, currentY, _ = item.CFrame:ToEulerAnglesXYZ()
        self.baseRotation = math.deg(currentY)
    end
    
    -- Set up input handling
    self:_SetupInputHandling()
    
    -- Show rotation UI
    self:_ShowRotationUI()
    
    print("🔄 RotationController: Started rotation for", item.Name)
    return true
end

-- Stop rotation and clean up
function RotationController:StopRotation()
    if not self.isRotating then return end
    
    self.isRotating = false
    self.targetItem = nil
    self.onConfirm = nil
    self.onCancel = nil
    
    -- Clean up connections
    if self.inputConnection then
        self.inputConnection:Disconnect()
        self.inputConnection = nil
    end
    
    if self.renderConnection then
        self.renderConnection:Disconnect()
        self.renderConnection = nil
    end
    
    -- Hide UI
    self:_HideRotationUI()
    
    print("🔄 RotationController: Stopped rotation")
end

-- Rotate item by specified degrees
function RotationController:RotateBy(degrees)
    if not self.isRotating or not self.targetItem then return end
    
    self.baseRotation = (self.baseRotation + degrees) % 360
    self:_ApplyRotation()
end

-- Set absolute rotation in degrees
function RotationController:SetRotation(degrees)
    if not self.isRotating or not self.targetItem then return end
    
    self.baseRotation = degrees % 360
    self:_ApplyRotation()
end

-- Get current rotation in degrees
function RotationController:GetRotation()
    return self.baseRotation
end

-- Confirm current rotation
function RotationController:ConfirmRotation()
    if not self.isRotating then return end
    
    local finalRotation = self.baseRotation
    local item = self.targetItem
    local callback = self.onConfirm
    
    self:StopRotation()
    
    if callback then
        callback(item, finalRotation)
    end
    
    print("✅ RotationController: Confirmed rotation at", finalRotation, "degrees")
end

-- Cancel rotation and restore original
function RotationController:CancelRotation()
    if not self.isRotating then return end
    
    local item = self.targetItem
    local callback = self.onCancel
    
    -- Restore original rotation
    if item then
        local originalRotationRad = math.rad(0) -- Could store original rotation if needed
        self:_ApplyRotationRadians(originalRotationRad)
    end
    
    self:StopRotation()
    
    if callback then
        callback(item)
    end
    
    print("❌ RotationController: Cancelled rotation")
end

-- Private: Apply current rotation to item
function RotationController:_ApplyRotation()
    if not self.targetItem then return end
    
    local rotationRadians = math.rad(self.baseRotation)
    self:_ApplyRotationRadians(rotationRadians)
end

-- Private: Apply rotation in radians
function RotationController:_ApplyRotationRadians(rotationY)
    if not self.targetItem then return end
    
    local item = self.targetItem
    local currentPosition
    
    if item:IsA("Model") and item.PrimaryPart then
        currentPosition = item.PrimaryPart.Position
        item:SetPrimaryPartCFrame(CFrame.new(currentPosition) * CFrame.Angles(0, rotationY, 0))
    elseif item:IsA("BasePart") then
        currentPosition = item.Position
        item.CFrame = CFrame.new(currentPosition) * CFrame.Angles(0, rotationY, 0)
    end
end

-- Private: Setup input handling for rotation
function RotationController:_SetupInputHandling()
    self.inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isRotating then return end
        
        if input.KeyCode == Enum.KeyCode.R then
            -- R key: Rotate 15 degrees clockwise
            self:RotateBy(self.rotationStep)
            
        elseif input.KeyCode == Enum.KeyCode.T then
            -- T key: Rotate 15 degrees counter-clockwise
            self:RotateBy(-self.rotationStep)
            
        elseif input.KeyCode == Enum.KeyCode.LeftShift then
            -- Shift + R/T for fine rotation (5 degrees)
            -- This will be handled in combination with R/T
            
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click: Confirm rotation
            self:ConfirmRotation()
            
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or Escape: Cancel rotation
            self:CancelRotation()
        end
    end)
    
    -- Handle scroll wheel for rotation
    local scrollConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isRotating then return end
        
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local rotationAmount = input.Position.Z * self.rotationStep
            self:RotateBy(rotationAmount)
        end
    end)
    
    -- Store scroll connection for cleanup
    self.scrollConnection = scrollConnection
end

-- Private: Show rotation UI
function RotationController:_ShowRotationUI()
    local player = Players.LocalPlayer
    if not player then return end
    
    -- Create simple rotation UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RotationControlsUI"
    screenGui.Parent = player.PlayerGui
    
    -- Main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.5, -150, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔄 ROTATION MODE"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.TextStrokeTransparency = 0
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.Font = Enum.Font.SourceSansBold
    title.Parent = frame
    
    -- Instructions
    local instructions = Instance.new("TextLabel")
    instructions.Size = UDim2.new(1, 0, 0, 40)
    instructions.Position = UDim2.new(0, 0, 0, 30)
    instructions.BackgroundTransparency = 1
    instructions.Text = "R/T: Rotate • Scroll: Rotate • Click: Confirm • Right-click/ESC: Cancel"
    instructions.TextColor3 = Color3.fromRGB(200, 200, 200)
    instructions.TextSize = 12
    instructions.TextWrapped = true
    instructions.Font = Enum.Font.SourceSans
    instructions.Parent = frame
    
    -- Rotation display
    local rotationDisplay = Instance.new("TextLabel")
    rotationDisplay.Size = UDim2.new(1, 0, 0, 30)
    rotationDisplay.Position = UDim2.new(0, 0, 0, 70)
    rotationDisplay.BackgroundTransparency = 1
    rotationDisplay.Text = "Rotation: 0°"
    rotationDisplay.TextColor3 = Color3.fromRGB(100, 255, 100)
    rotationDisplay.TextSize = 14
    rotationDisplay.Font = Enum.Font.SourceSansBold
    rotationDisplay.Parent = frame
    
    self.rotationUI = screenGui
    self.rotationDisplay = rotationDisplay
    
    -- Update rotation display in real-time
    self.renderConnection = RunService.Heartbeat:Connect(function()
        if self.rotationDisplay and self.isRotating then
            self.rotationDisplay.Text = string.format("Rotation: %.1f°", self.baseRotation)
        end
    end)
end

-- Private: Hide rotation UI
function RotationController:_HideRotationUI()
    if self.rotationUI then
        self.rotationUI:Destroy()
        self.rotationUI = nil
        self.rotationDisplay = nil
    end
    
    if self.scrollConnection then
        self.scrollConnection:Disconnect()
        self.scrollConnection = nil
    end
end

-- Check if currently rotating
function RotationController:IsRotating()
    return self.isRotating
end

-- Get target item being rotated
function RotationController:GetTargetItem()
    return self.targetItem
end

return RotationController 