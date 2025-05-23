-- GridSnapSystem.luau - Professional Grid Snapping for Item Placement
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local GridSnapSystem = {}
GridSnapSystem.__index = GridSnapSystem

function GridSnapSystem.new()
    local self = setmetatable({}, GridSnapSystem)
    
    -- Grid settings
    self.enabled = false -- Start disabled, user can enable with G
    self.gridSize = 4 -- Default grid size in studs
    self.availableGridSizes = {1, 2, 4, 8, 16}
    self.currentGridSizeIndex = 3 -- Points to gridSize 4
    
    -- Visual settings
    self.gridRange = 50 -- How far to draw grid lines
    self.gridLines = {}
    self.gridFolder = nil
    self.gridVisual = false
    self.lastGridCenter = nil
    
    -- UI elements
    self.statusUI = nil
    
    -- Collision settings
    self.collisionEnabled = true
    self.overlapTolerance = 0.5 -- Studs
    
    -- Surface snapping
    self.surfaceSnapEnabled = true
    self.surfaceSnapDistance = 2 -- Maximum distance to snap to surface
    
    -- Performance optimization
    self.lastUpdateTime = 0
    self.updateInterval = 0.05 -- Only update every 50ms (20 FPS) to prevent vibration
    self.lastSnappedPosition = nil
    self.positionTolerance = 0.1 -- Don't update if position change is tiny
    
    -- Services
    self.Players = game:GetService("Players")
    self.UserInputService = game:GetService("UserInputService")
    
    print("GridSnapSystem: Initialized with default 4-stud grid")
    return self
end

function GridSnapSystem:Initialize()
    self:CreateStatusUI()
    self:SetupInputHandling()
    self:CreateGridFolder()
    print("GridSnapSystem: Ready! Press G to toggle, Shift+G to cycle grid sizes")
    return true
end

function GridSnapSystem:CreateStatusUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create grid status UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GridSnapUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Name = "GridStatus"
    frame.Size = UDim2.new(0, 200, 0, 80)
    frame.Position = UDim2.new(0, 10, 0, 200)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = screenGui
    
    -- Corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Status text
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -16, 0, 25)
    statusLabel.Position = UDim2.new(0, 8, 0, 5)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Grid Snap: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.Parent = frame
    
    -- Grid size text
    local gridSizeLabel = Instance.new("TextLabel")
    gridSizeLabel.Name = "GridSizeLabel"
    gridSizeLabel.Size = UDim2.new(1, -16, 0, 20)
    gridSizeLabel.Position = UDim2.new(0, 8, 0, 30)
    gridSizeLabel.BackgroundTransparency = 1
    gridSizeLabel.Text = "Grid Size: 4 studs"
    gridSizeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    gridSizeLabel.TextScaled = true
    gridSizeLabel.Font = Enum.Font.Gotham
    gridSizeLabel.Parent = frame
    
    -- Controls text
    local controlsLabel = Instance.new("TextLabel")
    controlsLabel.Name = "ControlsLabel"
    controlsLabel.Size = UDim2.new(1, -16, 0, 15)
    controlsLabel.Position = UDim2.new(0, 8, 0, 55)
    controlsLabel.BackgroundTransparency = 1
    controlsLabel.Text = "G: Toggle | Shift+G: Size"
    controlsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    controlsLabel.TextScaled = true
    controlsLabel.Font = Enum.Font.Gotham
    controlsLabel.Parent = frame
    
    self.statusUI = frame
end

function GridSnapSystem:SetupInputHandling()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.G then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                -- Shift+G: Cycle grid sizes
                self:CycleGridSize()
            else
                -- G: Toggle grid snap
                self:ToggleGridSnap()
            end
        end
    end)
end

function GridSnapSystem:CreateGridFolder()
    -- Clean up existing grid
    if self.gridFolder then
        self.gridFolder:Destroy()
    end
    
    local folder = Instance.new("Folder")
    folder.Name = "GridSnapLines"
    folder.Parent = Workspace
    self.gridFolder = folder
end

function GridSnapSystem:ToggleGridSnap()
    self.enabled = not self.enabled
    
    -- Update UI
    if self.statusUI then
        local statusLabel = self.statusUI:FindFirstChild("StatusLabel")
        if statusLabel then
            statusLabel.Text = "Grid Snap: " .. (self.enabled and "ON" or "OFF")
            statusLabel.TextColor3 = self.enabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        end
    end
    
    -- Show/hide grid visual if it was visible
    if not self.enabled then
        self:HideGrid()
    end
    
    print("GridSnapSystem: Grid snap " .. (self.enabled and "enabled" or "disabled"))
end

function GridSnapSystem:CycleGridSize()
    self.currentGridSizeIndex = self.currentGridSizeIndex + 1
    if self.currentGridSizeIndex > #self.availableGridSizes then
        self.currentGridSizeIndex = 1
    end
    
    self.gridSize = self.availableGridSizes[self.currentGridSizeIndex]
    
    -- Update UI
    if self.statusUI then
        local gridSizeLabel = self.statusUI:FindFirstChild("GridSizeLabel")
        if gridSizeLabel then
            gridSizeLabel.Text = "Grid Size: " .. self.gridSize .. " studs"
        end
    end
    
    -- Refresh grid visual if it's showing
    if self.gridVisual then
        self:ShowGrid(self.lastGridCenter or Vector3.new(0, 0, 0))
    end
    
    print("GridSnapSystem: Grid size changed to " .. self.gridSize .. " studs")
end

function GridSnapSystem:SnapToGrid(position)
    if not self.enabled then
        return position
    end
    
    local gridSize = self.gridSize
    local snappedX = math.round(position.X / gridSize) * gridSize
    local snappedY = math.round(position.Y / gridSize) * gridSize
    local snappedZ = math.round(position.Z / gridSize) * gridSize
    
    return Vector3.new(snappedX, snappedY, snappedZ)
end

function GridSnapSystem:ShowGrid(centerPosition)
    if not self.enabled then return end
    
    -- Throttle updates to prevent vibration
    local currentTime = tick()
    if currentTime - self.lastUpdateTime < self.updateInterval then
        return -- Skip this update
    end
    
    -- Check if position has changed significantly
    if self.lastGridCenter then
        local distance = (centerPosition - self.lastGridCenter).Magnitude
        if distance < self.positionTolerance then
            return -- Position hasn't changed enough to warrant update
        end
    end
    
    self.lastUpdateTime = currentTime
    self:HideGrid()
    self.gridVisual = true
    self.lastGridCenter = centerPosition
    
    local gridSize = self.gridSize
    local range = self.gridRange
    
    -- Create grid lines
    local centerSnapped = self:SnapToGrid(centerPosition)
    
    -- X-axis lines (running along Z)
    for x = centerSnapped.X - range, centerSnapped.X + range, gridSize do
        local line = self:CreateGridLine(
            Vector3.new(x, centerSnapped.Y, centerSnapped.Z - range),
            Vector3.new(x, centerSnapped.Y, centerSnapped.Z + range)
        )
        table.insert(self.gridLines, line)
    end
    
    -- Z-axis lines (running along X)
    for z = centerSnapped.Z - range, centerSnapped.Z + range, gridSize do
        local line = self:CreateGridLine(
            Vector3.new(centerSnapped.X - range, centerSnapped.Y, z),
            Vector3.new(centerSnapped.X + range, centerSnapped.Y, z)
        )
        table.insert(self.gridLines, line)
    end
    
    -- Show status UI
    if self.statusUI then
        self.statusUI.Visible = true
        
        -- Auto-hide after 3 seconds if not placing
        task.delay(3, function()
            if not self.gridVisual then
                self.statusUI.Visible = false
            end
        end)
    end
end

function GridSnapSystem:CreateGridLine(startPos, endPos)
    local distance = (endPos - startPos).Magnitude
    local centerPos = startPos:Lerp(endPos, 0.5)
    
    local part = Instance.new("Part")
    part.Name = "GridLine"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.Size = Vector3.new(0.1, 0.1, distance)
    part.CFrame = CFrame.lookAt(centerPos, endPos)
    part.BrickColor = BrickColor.new("Bright blue")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.7
    part.Parent = self.gridFolder
    
    return part
end

function GridSnapSystem:HideGrid()
    -- Clear existing grid lines
    for _, line in pairs(self.gridLines) do
        if line and line.Parent then
            line:Destroy()
        end
    end
    self.gridLines = {}
    self.gridVisual = false
    
    -- Hide status UI after a delay
    if self.statusUI then
        task.delay(1, function()
            if not self.gridVisual then
                self.statusUI.Visible = false
            end
        end)
    end
end

function GridSnapSystem:CheckCollision(position, size, excludeInstance)
    if not self.collisionEnabled then
        return false, nil
    end
    
    -- Simple collision check using raycasting from center in multiple directions
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local filterList = {self.gridFolder}
    if excludeInstance then
        table.insert(filterList, excludeInstance)
    end
    raycastParams.FilterDescendantsInstances = filterList
    
    -- Cast rays in multiple directions to detect overlaps
    local directions = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 1, 0), Vector3.new(0, -1, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)
    }
    
    for _, direction in pairs(directions) do
        local rayDistance = size.Magnitude/2 + self.overlapTolerance
        local result = Workspace:Raycast(position, direction * rayDistance, raycastParams)
        if result then
            -- Check if hit object is a placed item (has instanceId attribute)
            local hitPart = result.Instance
            if hitPart then
                -- Check the part itself
                if hitPart:GetAttribute("instanceId") then
                    return true, hitPart
                end
                -- Check parent (for models)
                if hitPart.Parent and hitPart.Parent:GetAttribute("instanceId") then
                    return true, hitPart.Parent
                end
                -- Check if it's in the World_Items.Placed folder
                local parent = hitPart.Parent
                while parent and parent ~= Workspace do
                    if parent.Name == "Placed" and parent.Parent and parent.Parent.Name == "World_Items" then
                        return true, hitPart
                    end
                    parent = parent.Parent
                end
            end
        end
    end
    
    return false, nil
end

function GridSnapSystem:GetSurfaceSnapPosition(originalPosition, itemSize)
    if not self.surfaceSnapEnabled then
        return originalPosition
    end
    
    -- Cast ray downward to find surface
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {self.gridFolder}
    
    local rayOrigin = originalPosition + Vector3.new(0, itemSize.Y/2 + self.surfaceSnapDistance, 0)
    local rayDirection = Vector3.new(0, -(itemSize.Y + self.surfaceSnapDistance * 2), 0)
    
    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if result then
        -- Snap to surface
        local surfaceY = result.Position.Y + itemSize.Y/2
        return Vector3.new(originalPosition.X, surfaceY, originalPosition.Z)
    end
    
    return originalPosition
end

function GridSnapSystem:ProcessPlacement(position, rotation, itemSize, excludeInstance)
    if not self.enabled then
        return position, rotation, false, nil
    end
    
    -- Step 1: Snap to grid
    local snappedPosition = self:SnapToGrid(position)
    
    -- Step 2: Apply surface snapping
    snappedPosition = self:GetSurfaceSnapPosition(snappedPosition, itemSize)
    
    -- Step 3: Check for collisions (less frequently for performance)
    local hasCollision, collidingObject = false, nil
    if self.collisionEnabled then
        hasCollision, collidingObject = self:CheckCollision(snappedPosition, itemSize, excludeInstance)
    end
    
    -- Step 4: Show grid visual (throttled)
    self:ShowGrid(snappedPosition)
    
    -- Cache the last snapped position for smoothing
    self.lastSnappedPosition = snappedPosition
    
    return snappedPosition, rotation, hasCollision, collidingObject
end

-- Make available globally
_G.GridSnapSystem = GridSnapSystem

return GridSnapSystem 