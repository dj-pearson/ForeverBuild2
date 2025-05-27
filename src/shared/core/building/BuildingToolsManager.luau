-- BuildingToolsManager.luau
-- Advanced building tools and placement systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local IS_CLIENT = RunService:IsClient()
local IS_SERVER = RunService:IsServer()

local BuildingToolsManager = {}
BuildingToolsManager.__index = BuildingToolsManager

-- Building configuration
local BUILDING_CONFIG = {
    GRID_SIZE = 2, -- Default grid snap size in studs
    ROTATION_SNAP = 15, -- Default rotation snap in degrees
    PRECISION_MODE_GRID = 0.25, -- Fine grid size for precision mode
    MAX_SELECTION_DISTANCE = 200, -- Maximum distance for selection
    PLACEMENT_PREVIEW_TRANSPARENCY = 0.5,
    
    -- Advanced placement modes
    PLACEMENT_MODES = {
        FREE = "free", -- Free placement
        GRID = "grid", -- Snap to grid
        SURFACE = "surface", -- Snap to surfaces
        ALIGN = "align", -- Align to nearby objects
        PRECISION = "precision" -- High precision mode
    },
    
    -- Selection modes
    SELECTION_MODES = {
        SINGLE = "single",
        MULTIPLE = "multiple",
        BOX = "box", -- Box selection
        LASSO = "lasso" -- Freeform selection
    }
}

function BuildingToolsManager.new()
    local self = setmetatable({}, BuildingToolsManager)
    
    if IS_CLIENT then
        -- Client-side state
        self.isActive = false
        self.currentMode = BUILDING_CONFIG.PLACEMENT_MODES.GRID
        self.selectionMode = BUILDING_CONFIG.SELECTION_MODES.SINGLE
        self.selectedItems = {}
        self.previewModels = {}
        self.gridSize = BUILDING_CONFIG.GRID_SIZE
        self.rotationSnap = BUILDING_CONFIG.ROTATION_SNAP
        self.isPrecisionMode = false
        
        -- UI state
        self.toolsUI = nil
        self.gridVisualization = nil
        self.selectionBox = nil
        
        -- Copy/paste system
        self.copiedItems = {}
        
        -- Box selection state
        self.isBoxSelecting = false
        self.boxSelectionStart = nil
        
        -- Input tracking
        self.mouse = Players.LocalPlayer:GetMouse()
        self.camera = workspace.CurrentCamera
        self.connections = {}
    end
    
    return self
end

-- Initialize the building tools system
function BuildingToolsManager:Initialize()
    if IS_CLIENT then
        self:SetupUI()
        self:SetupInputHandling()
        self:SetupGridVisualization()
        print("BuildingToolsManager: Client initialized")
    end
end

-- Set up the building tools UI
function BuildingToolsManager:SetupUI()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Check if UI already exists
    local existingUI = playerGui:FindFirstChild("BuildingToolsUI")
    if existingUI then
        existingUI:Destroy()
    end
    
    -- Create main UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BuildingToolsUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Tools panel
    local toolsPanel = Instance.new("Frame")
    toolsPanel.Name = "ToolsPanel"
    toolsPanel.Size = UDim2.new(0, 300, 0, 400)
    toolsPanel.Position = UDim2.new(0, 20, 0.5, -200)
    toolsPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    toolsPanel.BorderSizePixel = 0
    toolsPanel.Visible = false
    toolsPanel.Parent = screenGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toolsPanel
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = toolsPanel
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔧 Building Tools"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:ToggleTools()
    end)
    
    -- Content area
    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -60)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.CanvasSize = UDim2.new(0, 0, 0, 800)
    content.Parent = toolsPanel
    
    -- Create tool sections
    self:CreateModeSection(content)
    self:CreateSelectionSection(content)
    self:CreatePrecisionSection(content)
    self:CreateGridSection(content)
    self:CreateActionsSection(content)
    
    -- Toggle button (always visible)
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 120, 0, 40)
    toggleButton.Position = UDim2.new(0, 20, 1, -60)
    toggleButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    toggleButton.Text = "🔧 Tools"
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextSize = 16
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleButton
    
    toggleButton.MouseButton1Click:Connect(function()
        self:ToggleTools()
    end)
    
    self.toolsUI = screenGui
    print("BuildingToolsManager: UI created")
end

-- Create placement mode section
function BuildingToolsManager:CreateModeSection(parent)
    local section = self:CreateSection(parent, "Placement Mode", 0)
    
    local modeButtons = {}
    local buttonData = {
        {mode = "GRID", text = "📐 Grid", desc = "Snap to grid"},
        {mode = "FREE", text = "🎯 Free", desc = "Free placement"},
        {mode = "SURFACE", text = "📌 Surface", desc = "Snap to surfaces"},
        {mode = "ALIGN", text = "📏 Align", desc = "Align to objects"},
        {mode = "PRECISION", text = "🔬 Precision", desc = "High precision"}
    }
    
    for i, data in ipairs(buttonData) do
        local button = self:CreateModeButton(section, data.text, data.desc, (i-1) * 60)
        button.MouseButton1Click:Connect(function()
            self:SetPlacementMode(BUILDING_CONFIG.PLACEMENT_MODES[data.mode])
            self:UpdateModeButtons(modeButtons, button)
        end)
        modeButtons[data.mode] = button
    end
    
    -- Set default selection
    self:UpdateModeButtons(modeButtons, modeButtons.GRID)
end

-- Create selection tools section
function BuildingToolsManager:CreateSelectionSection(parent)
    local section = self:CreateSection(parent, "Selection Tools", 320)
    
    local selectionButtons = {}
    local buttonData = {
        {mode = "SINGLE", text = "👆 Single", desc = "Select one item"},
        {mode = "MULTIPLE", text = "👋 Multiple", desc = "Select multiple"},
        {mode = "BOX", text = "📦 Box", desc = "Box selection"},
        {mode = "LASSO", text = "🎯 Lasso", desc = "Freeform selection"}
    }
    
    for i, data in ipairs(buttonData) do
        local button = self:CreateModeButton(section, data.text, data.desc, (i-1) * 60)
        button.MouseButton1Click:Connect(function()
            self:SetSelectionMode(BUILDING_CONFIG.SELECTION_MODES[data.mode])
            self:UpdateModeButtons(selectionButtons, button)
        end)
        selectionButtons[data.mode] = button
    end
    
    -- Clear selection button
    local clearButton = self:CreateActionButton(section, "🗑️ Clear Selection", "Clear all selected items", 240)
    clearButton.MouseButton1Click:Connect(function()
        self:ClearSelection()
    end)
    
    self:UpdateModeButtons(selectionButtons, selectionButtons.SINGLE)
end

-- Create precision tools section
function BuildingToolsManager:CreatePrecisionSection(parent)
    local section = self:CreateSection(parent, "Precision Tools", 580)
    
    -- Precision mode toggle
    local precisionToggle = self:CreateToggleButton(section, "🔬 Precision Mode", "Enable high precision placement", 0)
    precisionToggle.MouseButton1Click:Connect(function()
        self:TogglePrecisionMode()
        precisionToggle.BackgroundColor3 = self.isPrecisionMode and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
    end)
    
    -- Grid size slider
    local gridLabel = Instance.new("TextLabel")
    gridLabel.Name = "GridLabel"
    gridLabel.Size = UDim2.new(1, -20, 0, 20)
    gridLabel.Position = UDim2.new(0, 10, 0, 50)
    gridLabel.BackgroundTransparency = 1
    gridLabel.Text = "Grid Size: " .. self.gridSize .. " studs"
    gridLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    gridLabel.TextSize = 14
    gridLabel.Font = Enum.Font.Gotham
    gridLabel.TextXAlignment = Enum.TextXAlignment.Left
    gridLabel.Parent = section
    
    -- Rotation snap slider
    local rotationLabel = Instance.new("TextLabel")
    rotationLabel.Name = "RotationLabel"
    rotationLabel.Size = UDim2.new(1, -20, 0, 20)
    rotationLabel.Position = UDim2.new(0, 10, 0, 80)
    rotationLabel.BackgroundTransparency = 1
    rotationLabel.Text = "Rotation Snap: " .. self.rotationSnap .. "°"
    rotationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    rotationLabel.TextSize = 14
    rotationLabel.Font = Enum.Font.Gotham
    rotationLabel.TextXAlignment = Enum.TextXAlignment.Left
    rotationLabel.Parent = section
end

-- Create grid visualization section
function BuildingToolsManager:CreateGridSection(parent)
    local section = self:CreateSection(parent, "Grid Settings", 720)
    
    -- Show grid toggle
    local gridToggle = self:CreateToggleButton(section, "🌐 Show Grid", "Display grid visualization", 0)
    gridToggle.MouseButton1Click:Connect(function()
        self:ToggleGridVisualization()
        gridToggle.BackgroundColor3 = self.gridVisualization.Visible and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Create actions section
function BuildingToolsManager:CreateActionsSection(parent)
    local section = self:CreateSection(parent, "Bulk Actions", 800)
    
    local actions = {
        {text = "📋 Copy Selected", desc = "Copy selected items", action = "copy"},
        {text = "📄 Paste", desc = "Paste copied items", action = "paste"},
        {text = "🗑️ Delete Selected", desc = "Delete selected items", action = "delete"},
        {text = "↺ Rotate Selected", desc = "Rotate selected items", action = "rotate"}
    }
    
    for i, actionData in ipairs(actions) do
        local button = self:CreateActionButton(section, actionData.text, actionData.desc, (i-1) * 50)
        button.MouseButton1Click:Connect(function()
            self:ExecuteBulkAction(actionData.action)
        end)
    end
end

-- Helper function to create a section
function BuildingToolsManager:CreateSection(parent, title, yPos)
    local section = Instance.new("Frame")
    section.Name = title .. "Section"
    section.Size = UDim2.new(1, 0, 0, 100)
    section.Position = UDim2.new(0, 0, 0, yPos)
    section.BackgroundTransparency = 1
    section.Parent = parent
    
    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Name = "Title"
    sectionTitle.Size = UDim2.new(1, -20, 0, 25)
    sectionTitle.Position = UDim2.new(0, 10, 0, 0)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Text = title
    sectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    sectionTitle.TextSize = 16
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.Parent = section
    
    return section
end

-- Helper function to create a mode button
function BuildingToolsManager:CreateModeButton(parent, text, description, yPos)
    local button = Instance.new("TextButton")
    button.Name = text .. "Button"
    button.Size = UDim2.new(1, -20, 0, 40)
    button.Position = UDim2.new(0, 10, 0, 30 + yPos)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 14
    button.Font = Enum.Font.Gotham
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        if button.BackgroundColor3 ~= Color3.fromRGB(0, 120, 0) then
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            }):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if button.BackgroundColor3 ~= Color3.fromRGB(0, 120, 0) then
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            }):Play()
        end
    end)
    
    return button
end

-- Helper function to create an action button
function BuildingToolsManager:CreateActionButton(parent, text, description, yPos)
    local button = Instance.new("TextButton")
    button.Name = text .. "Button"
    button.Size = UDim2.new(1, -20, 0, 35)
    button.Position = UDim2.new(0, 10, 0, 30 + yPos)
    button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 12
    button.Font = Enum.Font.Gotham
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(90, 90, 90)
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        }):Play()
    end)
    
    return button
end

-- Helper function to create a toggle button
function BuildingToolsManager:CreateToggleButton(parent, text, description, yPos)
    local button = self:CreateActionButton(parent, text, description, yPos)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    return button
end

-- Update mode button states
function BuildingToolsManager:UpdateModeButtons(buttons, activeButton)
    for _, button in pairs(buttons) do
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    activeButton.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
end

-- Set up input handling
function BuildingToolsManager:SetupInputHandling()
    -- Keyboard shortcuts
    self.connections.keyInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.B then
            self:ToggleTools()
        elseif input.KeyCode == Enum.KeyCode.G then
            self:ToggleGridVisualization()
        elseif input.KeyCode == Enum.KeyCode.C and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:ExecuteBulkAction("copy")
        elseif input.KeyCode == Enum.KeyCode.V and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:ExecuteBulkAction("paste")
        elseif input.KeyCode == Enum.KeyCode.Delete then
            self:ExecuteBulkAction("delete")
        elseif input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:ExecuteBulkAction("rotate")
        elseif input.KeyCode == Enum.KeyCode.A and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:SelectAllItems()
        elseif input.KeyCode == Enum.KeyCode.Escape then
            self:ClearSelection()
        end
    end)
    
    -- Mouse input for selection
    self.connections.mouseInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isActive then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:HandleMouseClick()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self.selectionMode == BUILDING_CONFIG.SELECTION_MODES.BOX then
            local mousePosition = self.mouse.Hit.Position
            self:StartBoxSelection(mousePosition)
        end
    end)
    
    -- Mouse release for box selection
    self.connections.mouseRelease = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and self.isBoxSelecting then
            local mousePosition = self.mouse.Hit.Position
            self:EndBoxSelection(mousePosition)
        end
    end)
    
    print("BuildingToolsManager: Input handling setup")
end

-- Set up grid visualization
function BuildingToolsManager:SetupGridVisualization()
    local gridFolder = Instance.new("Folder")
    gridFolder.Name = "BuildingGrid"
    gridFolder.Parent = workspace
    
    self.gridVisualization = gridFolder
    self.gridVisualization.Visible = false
    
    print("BuildingToolsManager: Grid visualization setup")
end

-- Toggle building tools UI
function BuildingToolsManager:ToggleTools()
    if not self.toolsUI then return end
    
    local panel = self.toolsUI:FindFirstChild("ToolsPanel")
    if panel then
        panel.Visible = not panel.Visible
        self.isActive = panel.Visible
        
        if self.isActive then
            self:UpdateGridVisualization()
        end
    end
end

-- Set placement mode
function BuildingToolsManager:SetPlacementMode(mode)
    self.currentMode = mode
    print("BuildingToolsManager: Placement mode set to", mode)
    
    -- Update grid visualization based on mode
    if mode == BUILDING_CONFIG.PLACEMENT_MODES.GRID then
        self:ShowGridVisualization()
    else
        self:HideGridVisualization()
    end
end

-- Set selection mode
function BuildingToolsManager:SetSelectionMode(mode)
    self.selectionMode = mode
    print("BuildingToolsManager: Selection mode set to", mode)
    
    -- Clear current selection when changing modes
    self:ClearSelection()
end

-- Toggle precision mode
function BuildingToolsManager:TogglePrecisionMode()
    self.isPrecisionMode = not self.isPrecisionMode
    
    if self.isPrecisionMode then
        self.gridSize = BUILDING_CONFIG.PRECISION_MODE_GRID
        self.rotationSnap = 1
    else
        self.gridSize = BUILDING_CONFIG.GRID_SIZE
        self.rotationSnap = BUILDING_CONFIG.ROTATION_SNAP
    end
    
    print("BuildingToolsManager: Precision mode", self.isPrecisionMode and "enabled" or "disabled")
    self:UpdateGridVisualization()
end

-- Toggle grid visualization
function BuildingToolsManager:ToggleGridVisualization()
    if self.gridVisualization then
        self.gridVisualization.Visible = not self.gridVisualization.Visible
        print("BuildingToolsManager: Grid visualization", self.gridVisualization.Visible and "shown" or "hidden")
    end
end

-- Show grid visualization
function BuildingToolsManager:ShowGridVisualization()
    if self.gridVisualization then
        self.gridVisualization.Visible = true
        self:UpdateGridVisualization()
    end
end

-- Hide grid visualization
function BuildingToolsManager:HideGridVisualization()
    if self.gridVisualization then
        self.gridVisualization.Visible = false
    end
end

-- Update grid visualization
function BuildingToolsManager:UpdateGridVisualization()
    if not self.gridVisualization or not self.gridVisualization.Visible then return end
    
    -- Clear existing grid
    self.gridVisualization:ClearAllChildren()
    
    -- Create new grid lines based on camera position
    local camera = workspace.CurrentCamera
    local cameraPosition = camera.CFrame.Position
    
    local gridRange = 50 -- Grid extends 50 studs in each direction
    local gridSize = self.gridSize
    
    -- Create grid lines
    for x = -gridRange, gridRange, gridSize do
        for z = -gridRange, gridRange, gridSize do
            local position = Vector3.new(
                cameraPosition.X + x,
                cameraPosition.Y - 10, -- Place grid below camera
                cameraPosition.Z + z
            )
            
            -- Create grid point
            local gridPoint = Instance.new("Part")
            gridPoint.Name = "GridPoint"
            gridPoint.Size = Vector3.new(0.1, 0.1, 0.1)
            gridPoint.Position = position
            gridPoint.Material = Enum.Material.Neon
            gridPoint.BrickColor = BrickColor.new("Bright blue")
            gridPoint.Anchored = true
            gridPoint.CanCollide = false
            gridPoint.Transparency = 0.7
            gridPoint.Parent = self.gridVisualization
        end
    end
end

-- Clear current selection
function BuildingToolsManager:ClearSelection()
    for _, item in ipairs(self.selectedItems) do
        if item and item.Parent then
            -- Remove selection highlight
            local highlight = item:FindFirstChild("SelectionHighlight")
            if highlight then
                highlight:Destroy()
            end
        end
    end
    
    self.selectedItems = {}
    print("BuildingToolsManager: Selection cleared")
end

-- Execute bulk actions on selected items
function BuildingToolsManager:ExecuteBulkAction(action)
    if #self.selectedItems == 0 then
        print("BuildingToolsManager: No items selected for bulk action:", action)
        return
    end
    
    print("BuildingToolsManager: Executing bulk action:", action, "on", #self.selectedItems, "items")
    
    if action == "copy" then
        self:CopySelectedItems()
    elseif action == "paste" then
        self:PasteItems()
    elseif action == "delete" then
        self:DeleteSelectedItems()
    elseif action == "rotate" then
        self:RotateSelectedItems()
    end
end

-- Copy selected items
function BuildingToolsManager:CopySelectedItems()
    if #self.selectedItems == 0 then
        print("BuildingToolsManager: No items selected to copy")
        return
    end
    
    -- Store copied items data
    self.copiedItems = {}
    local centerPosition = self:GetSelectionCenter()
    
    for _, item in ipairs(self.selectedItems) do
        if item and item.Parent then
            local itemData = {
                className = item.ClassName,
                name = item.Name,
                size = item.Size,
                material = item.Material,
                color = item.Color,
                shape = item.Shape,
                transparency = item.Transparency,
                -- Store relative position from selection center
                relativePosition = item.Position - centerPosition,
                rotation = item.Rotation,
                -- Store any special properties
                customProperties = {}
            }
            
            -- Copy custom attributes if any
            for _, attribute in ipairs(item:GetAttributes()) do
                itemData.customProperties[attribute] = item:GetAttribute(attribute)
            end
            
            table.insert(self.copiedItems, itemData)
        end
    end
    
    print("BuildingToolsManager: Copied " .. #self.copiedItems .. " items")
end

-- Paste items
function BuildingToolsManager:PasteItems()
    if not self.copiedItems or #self.copiedItems == 0 then
        print("BuildingToolsManager: No items to paste")
        return
    end
    
    -- Get paste location (mouse position or selection center)
    local pastePosition = self:GetPastePosition()
    if not pastePosition then
        print("BuildingToolsManager: Could not determine paste position")
        return
    end
    
    -- Clear current selection
    self:ClearSelection()
    
    -- Create new items at paste location
    local newItems = {}
    for _, itemData in ipairs(self.copiedItems) do
        local newItem = self:CreateItemFromData(itemData, pastePosition + itemData.relativePosition)
        if newItem then
            table.insert(newItems, newItem)
            table.insert(self.selectedItems, newItem)
            self:AddSelectionHighlight(newItem)
        end
    end
    
    print("BuildingToolsManager: Pasted " .. #newItems .. " items")
end

-- Delete selected items
function BuildingToolsManager:DeleteSelectedItems()
    if #self.selectedItems == 0 then
        print("BuildingToolsManager: No items selected to delete")
        return
    end
    
    local deleteCount = 0
    for _, item in ipairs(self.selectedItems) do
        if item and item.Parent then
            -- Check if item can be deleted (not anchored system objects)
            if item:GetAttribute("CanDelete") ~= false and item.Parent ~= workspace.Terrain then
                item:Destroy()
                deleteCount = deleteCount + 1
            end
        end
    end
    
    -- Clear selection after deletion
    self.selectedItems = {}
    print("BuildingToolsManager: Deleted " .. deleteCount .. " items")
end

-- Rotate selected items
function BuildingToolsManager:RotateSelectedItems()
    if #self.selectedItems == 0 then
        print("BuildingToolsManager: No items selected to rotate")
        return
    end
    
    local rotationCenter = self:GetSelectionCenter()
    local rotationAmount = self.rotationSnap or 15 -- degrees
    
    for _, item in ipairs(self.selectedItems) do
        if item and item.Parent and item:IsA("BasePart") then
            -- Rotate around selection center
            local relativePos = item.Position - rotationCenter
            local rotatedPos = self:RotatePointAround(relativePos, Vector3.new(0, 1, 0), math.rad(rotationAmount))
            
            -- Apply rotation
            item.Position = rotationCenter + rotatedPos
            item.Rotation = item.Rotation + Vector3.new(0, rotationAmount, 0)
        end
    end
    
    print("BuildingToolsManager: Rotated " .. #self.selectedItems .. " items by " .. rotationAmount .. " degrees")
end

-- Snap position to grid
function BuildingToolsManager:SnapToGrid(position)
    local gridSize = self.gridSize
    return Vector3.new(
        math.floor(position.X / gridSize + 0.5) * gridSize,
        math.floor(position.Y / gridSize + 0.5) * gridSize,
        math.floor(position.Z / gridSize + 0.5) * gridSize
    )
end

-- Snap rotation to angle
function BuildingToolsManager:SnapRotation(rotation)
    local snapAngle = self.rotationSnap
    return Vector3.new(
        math.floor(rotation.X / snapAngle + 0.5) * snapAngle,
        math.floor(rotation.Y / snapAngle + 0.5) * snapAngle,
        math.floor(rotation.Z / snapAngle + 0.5) * snapAngle
    )
end

-- Get placement position based on current mode
function BuildingToolsManager:GetPlacementPosition(mousePosition)
    if self.currentMode == BUILDING_CONFIG.PLACEMENT_MODES.GRID then
        return self:SnapToGrid(mousePosition)
    elseif self.currentMode == BUILDING_CONFIG.PLACEMENT_MODES.SURFACE then
        return self:GetSurfaceSnapPosition(mousePosition)
    elseif self.currentMode == BUILDING_CONFIG.PLACEMENT_MODES.ALIGN then
        return self:GetAlignedPosition(mousePosition)
    else
        return mousePosition -- Free placement
    end
end

-- Get surface snap position
function BuildingToolsManager:GetSurfaceSnapPosition(mousePosition)
    if not self.mouse then return mousePosition end
    
    -- Raycast from camera to mouse position
    local camera = workspace.CurrentCamera
    local ray = camera:ScreenPointToRay(self.mouse.X, self.mouse.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {self.gridVisualization}
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if raycastResult then
        local hitPosition = raycastResult.Position
        local hitNormal = raycastResult.Normal
        
        -- Snap to surface with slight offset based on normal
        local snapOffset = hitNormal * 0.5 -- Half stud offset from surface
        local snapPosition = hitPosition + snapOffset
        
        -- Apply grid snapping to the surface-snapped position
        return self:SnapToGrid(snapPosition)
    else
        -- Fallback to regular grid snapping
        return self:SnapToGrid(mousePosition)
    end
end

-- Get aligned position
function BuildingToolsManager:GetAlignedPosition(mousePosition)
    local alignmentDistance = 5 -- Distance to check for nearby objects
    local nearbyParts = {}
    
    -- Find nearby parts to align to
    local region = Region3.new(
        mousePosition - Vector3.new(alignmentDistance, alignmentDistance, alignmentDistance),
        mousePosition + Vector3.new(alignmentDistance, alignmentDistance, alignmentDistance)
    )
    
    -- Get parts in region
    local success, partsInRegion = pcall(function()
        return workspace:ReadVoxels(region, 4)
    end)
    
    if not success then
        -- Fallback: use simple distance check
        for _, part in ipairs(workspace:GetPartBoundsInBox(
            CFrame.new(mousePosition),
            Vector3.new(alignmentDistance * 2, alignmentDistance * 2, alignmentDistance * 2)
        )) do
            if part:IsA("BasePart") and part:GetAttribute("CanAlign") ~= false then
                table.insert(nearbyParts, part)
            end
        end
    else
        -- Use the parts from region reading
        for _, part in ipairs(workspace:GetPartBoundsInBox(
            CFrame.new(mousePosition),
            Vector3.new(alignmentDistance * 2, alignmentDistance * 2, alignmentDistance * 2)
        )) do
            if part:IsA("BasePart") and part:GetAttribute("CanAlign") ~= false then
                table.insert(nearbyParts, part)
            end
        end
    end
    
    if #nearbyParts == 0 then
        return self:SnapToGrid(mousePosition)
    end
    
    -- Find best alignment position
    local bestPosition = mousePosition
    local bestScore = math.huge
    
    for _, part in ipairs(nearbyParts) do
        local partPosition = part.Position
        local partSize = part.Size
        
        -- Check alignment to edges and centers
        local alignmentPoints = {
            -- Face centers
            partPosition + Vector3.new(partSize.X/2, 0, 0), -- Right face
            partPosition - Vector3.new(partSize.X/2, 0, 0), -- Left face
            partPosition + Vector3.new(0, 0, partSize.Z/2), -- Front face
            partPosition - Vector3.new(0, 0, partSize.Z/2), -- Back face
            partPosition + Vector3.new(0, partSize.Y/2, 0), -- Top face
            partPosition - Vector3.new(0, partSize.Y/2, 0), -- Bottom face
            
            -- Corners (simplified - just a few key corners)
            partPosition + Vector3.new(partSize.X/2, 0, partSize.Z/2),
            partPosition + Vector3.new(-partSize.X/2, 0, partSize.Z/2),
            partPosition + Vector3.new(partSize.X/2, 0, -partSize.Z/2),
            partPosition + Vector3.new(-partSize.X/2, 0, -partSize.Z/2),
        }
        
        for _, alignPoint in ipairs(alignmentPoints) do
            local distance = (mousePosition - alignPoint).Magnitude
            if distance < bestScore then
                bestScore = distance
                bestPosition = alignPoint
            end
        end
    end
    
    -- Apply grid snapping to aligned position if within reasonable distance
    if bestScore < alignmentDistance then
        return self:SnapToGrid(bestPosition)
    else
        return self:SnapToGrid(mousePosition)
    end
end

-- Helper functions for bulk operations

-- Get the center position of selected items
function BuildingToolsManager:GetSelectionCenter()
    if #self.selectedItems == 0 then
        return Vector3.new(0, 0, 0)
    end
    
    local totalPosition = Vector3.new(0, 0, 0)
    local validItems = 0
    
    for _, item in ipairs(self.selectedItems) do
        if item and item.Parent and item:IsA("BasePart") then
            totalPosition = totalPosition + item.Position
            validItems = validItems + 1
        end
    end
    
    if validItems > 0 then
        return totalPosition / validItems
    else
        return Vector3.new(0, 0, 0)
    end
end

-- Get paste position (mouse world position)
function BuildingToolsManager:GetPastePosition()
    if not self.mouse then return nil end
    
    -- Use mouse hit position or current camera focus
    local hit = self.mouse.Hit
    if hit then
        return self:GetPlacementPosition(hit.Position)
    else
        -- Fallback to camera position + forward direction
        local camera = workspace.CurrentCamera
        return camera.CFrame.Position + camera.CFrame.LookVector * 20
    end
end

-- Create item from stored data
function BuildingToolsManager:CreateItemFromData(itemData, position)
    local success, newItem = pcall(function()
        local item = Instance.new(itemData.className)
        
        -- Apply basic properties
        if item:IsA("BasePart") then
            item.Size = itemData.size
            item.Position = position
            item.Rotation = itemData.rotation
            item.Material = itemData.material
            item.Color = itemData.color
            item.Shape = itemData.shape or Enum.PartType.Block
            item.Transparency = itemData.transparency or 0
            item.Anchored = true
            item.CanCollide = true
            
            -- Apply custom properties
            for propName, value in pairs(itemData.customProperties) do
                item:SetAttribute(propName, value)
            end
            
            item.Parent = workspace
        end
        
        return item
    end)
    
    if success then
        return newItem
    else
        warn("BuildingToolsManager: Failed to create item from data:", itemData.className)
        return nil
    end
end

-- Rotate a point around an axis
function BuildingToolsManager:RotatePointAround(point, axis, angle)
    -- Simple rotation around Y axis for now
    if axis.Y ~= 0 then
        local cos = math.cos(angle)
        local sin = math.sin(angle)
        return Vector3.new(
            point.X * cos - point.Z * sin,
            point.Y,
            point.X * sin + point.Z * cos
        )
    end
    return point
end

-- Add selection highlight to an item
function BuildingToolsManager:AddSelectionHighlight(item)
    if not item or not item:IsA("BasePart") then return end
    
    -- Remove existing highlight
    local existingHighlight = item:FindFirstChild("SelectionHighlight")
    if existingHighlight then
        existingHighlight:Destroy()
    end
    
    -- Create new highlight
    local highlight = Instance.new("SelectionBox")
    highlight.Name = "SelectionHighlight"
    highlight.Adornee = item
    highlight.Color3 = Color3.fromRGB(0, 162, 255)
    highlight.LineThickness = 0.2
    highlight.Transparency = 0.8
    highlight.Parent = item
end

-- Enhanced item selection with visual feedback
function BuildingToolsManager:SelectItem(item)
    if not item or not item:IsA("BasePart") then return end
    
    -- Check if already selected
    for _, selectedItem in ipairs(self.selectedItems) do
        if selectedItem == item then
            return -- Already selected
        end
    end
    
    -- Add to selection
    table.insert(self.selectedItems, item)
    self:AddSelectionHighlight(item)
    
    print("BuildingToolsManager: Selected item:", item.Name)
end

-- Remove item from selection
function BuildingToolsManager:DeselectItem(item)
    for i, selectedItem in ipairs(self.selectedItems) do
        if selectedItem == item then
            -- Remove highlight
            local highlight = item:FindFirstChild("SelectionHighlight")
            if highlight then
                highlight:Destroy()
            end
            
            -- Remove from selection
            table.remove(self.selectedItems, i)
            print("BuildingToolsManager: Deselected item:", item.Name)
            break
        end
    end
end

-- Box selection functionality
function BuildingToolsManager:StartBoxSelection(startPosition)
    self.boxSelectionStart = startPosition
    self.isBoxSelecting = true
    
    -- Create selection box visual
    if not self.selectionBox then
        self.selectionBox = Instance.new("SelectionBox")
        self.selectionBox.Color3 = Color3.fromRGB(0, 162, 255)
        self.selectionBox.LineThickness = 0.1
        self.selectionBox.Transparency = 0.9
        self.selectionBox.Parent = workspace
    end
end

function BuildingToolsManager:UpdateBoxSelection(currentPosition)
    if not self.isBoxSelecting or not self.boxSelectionStart then return end
    
    -- Update selection box size and position
    -- This would require creating a Part to represent the selection area
    -- For now, we'll implement a simple distance-based selection
end

function BuildingToolsManager:EndBoxSelection(endPosition)
    if not self.isBoxSelecting or not self.boxSelectionStart then return end
    
    self.isBoxSelecting = false
    
    -- Find all items within the selection box
    local minX = math.min(self.boxSelectionStart.X, endPosition.X)
    local maxX = math.max(self.boxSelectionStart.X, endPosition.X)
    local minZ = math.min(self.boxSelectionStart.Z, endPosition.Z)
    local maxZ = math.max(self.boxSelectionStart.Z, endPosition.Z)
    
    -- Clear current selection if not holding Ctrl
    if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        self:ClearSelection()
    end
    
    -- Select items within box
    for _, item in ipairs(workspace:GetPartBoundsInBox(
        CFrame.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2),
        Vector3.new(maxX - minX, 1000, maxZ - minZ)
    )) do
        if item:GetAttribute("CanSelect") ~= false then
            self:SelectItem(item)
        end
    end
    
    -- Clean up selection box
    if self.selectionBox then
        self.selectionBox:Destroy()
        self.selectionBox = nil
    end
    
    self.boxSelectionStart = nil
end

-- Handle mouse click for item selection
function BuildingToolsManager:HandleMouseClick()
    if not self.mouse.Target then return end
    
    local clickedItem = self.mouse.Target
    
    -- Check if item can be selected
    if not clickedItem:IsA("BasePart") or clickedItem:GetAttribute("CanSelect") == false then
        -- Clear selection if clicking on non-selectable object
        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:ClearSelection()
        end
        return
    end
    
    if self.selectionMode == BUILDING_CONFIG.SELECTION_MODES.SINGLE then
        -- Single selection mode
        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:ClearSelection()
        end
        self:SelectItem(clickedItem)
        
    elseif self.selectionMode == BUILDING_CONFIG.SELECTION_MODES.MULTIPLE then
        -- Multiple selection mode
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            -- Toggle selection
            local isSelected = false
            for _, item in ipairs(self.selectedItems) do
                if item == clickedItem then
                    isSelected = true
                    break
                end
            end
            
            if isSelected then
                self:DeselectItem(clickedItem)
            else
                self:SelectItem(clickedItem)
            end
        else
            -- Single select without Ctrl
            self:ClearSelection()
            self:SelectItem(clickedItem)
        end
    end
end

-- Select all selectable items in view
function BuildingToolsManager:SelectAllItems()
    self:ClearSelection()
    
    -- Find all selectable parts in workspace
    local function addSelectableChildren(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child:GetAttribute("CanSelect") ~= false then
                self:SelectItem(child)
            end
            addSelectableChildren(child)
        end
    end
    
    addSelectableChildren(workspace)
    print("BuildingToolsManager: Selected all items (" .. #self.selectedItems .. " total)")
end

-- Cleanup
function BuildingToolsManager:Cleanup()
    -- Disconnect all connections
    for _, connection in pairs(self.connections) do
        connection:Disconnect()
    end
    
    -- Clean up UI
    if self.toolsUI then
        self.toolsUI:Destroy()
    end
    
    -- Clean up grid visualization
    if self.gridVisualization then
        self.gridVisualization:Destroy()
    end
    
    -- Clean up selection box
    if self.selectionBox then
        self.selectionBox:Destroy()
    end
    
    print("BuildingToolsManager: Cleaned up")
end

return BuildingToolsManager 