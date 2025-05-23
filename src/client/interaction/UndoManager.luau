-- UndoManager.luau
-- Manages undo operations for player actions with a 5-second time window

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local UndoManager = {}
UndoManager.__index = UndoManager

-- Constants
local UNDO_TIME_LIMIT = 5 -- seconds
local MAX_UNDO_ACTIONS = 3 -- Maximum actions that can be undone

function UndoManager.new()
    local self = setmetatable({}, UndoManager)
    
    -- Action tracking
    self.actionHistory = {} -- Array of recent actions
    self.undoUI = nil
    self.isUndoing = false
    
    -- Remote events for undo operations
    self.remotes = {}
    
    -- Connection tracking
    self.connections = {}
    
    return self
end

function UndoManager:Initialize()
    print("UndoManager: Initializing...")
    
    -- Cache remote events
    self:SetupRemotes()
    
    -- Create undo UI
    self:CreateUndoUI()
    
    -- Setup input handling
    self:SetupInputHandling()
    
    -- Start cleanup timer for expired actions
    self:StartCleanupTimer()
    
    print("UndoManager: Initialized successfully")
    return true
end

function UndoManager:SetupRemotes()
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not remotesFolder then
        warn("UndoManager: Remotes folder not found")
        return
    end
    
    -- Cache existing remotes for undo operations
    -- Include both legacy names and new "Request" prefixed names
    local remoteNames = {
        "PlaceItem", "DestroyItem", "RequestDestroyItem", 
        "MoveItem", "RequestMoveItem", "RotateItem", "RequestRotateItem", 
        "CloneItem", "RequestCloneItem", "RecallItem", "RequestRecallItem"
    }
    
    for _, name in ipairs(remoteNames) do
        local remote = remotesFolder:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            self.remotes[name] = remote
            print(string.format("UndoManager: Cached remote event: %s", name))
        end
    end
    
    -- For undo operations, prioritize "Request" versions but fall back to legacy versions
    if not self.remotes.DestroyItem and self.remotes.RequestDestroyItem then
        self.remotes.DestroyItem = self.remotes.RequestDestroyItem
        print("UndoManager: Using RequestDestroyItem as DestroyItem for undo")
    end
    
    if not self.remotes.MoveItem and self.remotes.RequestMoveItem then
        self.remotes.MoveItem = self.remotes.RequestMoveItem
        print("UndoManager: Using RequestMoveItem as MoveItem for undo")
    end
    
    print("UndoManager: Remote events cached")
end

function UndoManager:CreateUndoUI()
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui for undo notifications
    self.undoUI = Instance.new("ScreenGui")
    self.undoUI.Name = "UndoManagerUI"
    self.undoUI.ResetOnSpawn = false
    self.undoUI.Parent = playerGui
    
    -- Create undo notification frame (initially hidden)
    local notification = Instance.new("Frame")
    notification.Name = "UndoNotification"
    notification.Size = UDim2.new(0, 300, 0, 80)
    notification.Position = UDim2.new(0.5, -150, 0, 20)
    notification.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    notification.BackgroundTransparency = 0.1
    notification.BorderSizePixel = 0
    notification.Visible = false
    notification.Parent = self.undoUI
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    -- Add stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 200, 255)
    stroke.Thickness = 2
    stroke.Parent = notification
    
    -- Add undo icon/text
    local undoLabel = Instance.new("TextLabel")
    undoLabel.Name = "UndoLabel"
    undoLabel.Size = UDim2.new(0.7, 0, 1, 0)
    undoLabel.Position = UDim2.new(0, 10, 0, 0)
    undoLabel.BackgroundTransparency = 1
    undoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    undoLabel.TextSize = 16
    undoLabel.Font = Enum.Font.GothamBold
    undoLabel.Text = "Press Ctrl+Z to Undo"
    undoLabel.TextXAlignment = Enum.TextXAlignment.Left
    undoLabel.Parent = notification
    
    -- Add countdown timer
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(0.3, -10, 1, 0)
    timerLabel.Position = UDim2.new(0.7, 0, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    timerLabel.TextSize = 18
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.Text = "5s"
    timerLabel.TextXAlignment = Enum.TextXAlignment.Right
    timerLabel.Parent = notification
    
    print("UndoManager: UI created")
end

function UndoManager:SetupInputHandling()
    -- Handle Ctrl+Z for undo
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Check for Ctrl+Z (PC) or specific mobile gesture
        if input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:TryUndo()
        end
    end)
    
    table.insert(self.connections, inputConnection)
end

function UndoManager:StartCleanupTimer()
    -- Clean up expired actions every second
    local cleanupConnection = RunService.Heartbeat:Connect(function()
        self:CleanupExpiredActions()
        self:UpdateUndoNotification()
    end)
    
    table.insert(self.connections, cleanupConnection)
end

function UndoManager:RecordAction(actionType, actionData)
    if self.isUndoing then
        return -- Don't record actions while undoing
    end
    
    local action = {
        type = actionType,
        data = actionData,
        timestamp = tick(),
        id = math.random(100000, 999999) -- Unique ID for tracking
    }
    
    -- Add to history (newest first)
    table.insert(self.actionHistory, 1, action)
    
    -- Limit history size
    while #self.actionHistory > MAX_UNDO_ACTIONS do
        table.remove(self.actionHistory)
    end
    
    print(string.format("UndoManager: Recorded %s action (ID: %d)", actionType, action.id))
    
    -- Show undo notification
    self:ShowUndoNotification(actionType)
end

function UndoManager:ShowUndoNotification(actionType)
    local notification = self.undoUI:FindFirstChild("UndoNotification")
    if not notification then return end
    
    local undoLabel = notification:FindFirstChild("UndoLabel")
    if undoLabel then
        undoLabel.Text = string.format("Press Ctrl+Z to Undo '%s'", actionType)
    end
    
    -- Show with animation
    notification.Visible = true
    notification.Position = UDim2.new(0.5, -150, 0, -100)
    
    local tween = TweenService:Create(
        notification,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -150, 0, 20)}
    )
    tween:Play()
end

function UndoManager:UpdateUndoNotification()
    local notification = self.undoUI:FindFirstChild("UndoNotification")
    if not notification or not notification.Visible then return end
    
    local latestAction = self.actionHistory[1]
    if not latestAction then
        self:HideUndoNotification()
        return
    end
    
    local timeLeft = UNDO_TIME_LIMIT - (tick() - latestAction.timestamp)
    
    if timeLeft <= 0 then
        self:HideUndoNotification()
        return
    end
    
    -- Update timer display
    local timerLabel = notification:FindFirstChild("TimerLabel")
    if timerLabel then
        timerLabel.Text = string.format("%.1fs", timeLeft)
        
        -- Color change as time runs out
        if timeLeft <= 2 then
            timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red
        elseif timeLeft <= 3 then
            timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Orange
        else
            timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
        end
    end
end

function UndoManager:HideUndoNotification()
    local notification = self.undoUI:FindFirstChild("UndoNotification")
    if not notification then return end
    
    local tween = TweenService:Create(
        notification,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -150, 0, -100)}
    )
    tween:Play()
    
    tween.Completed:Connect(function()
        notification.Visible = false
    end)
end

function UndoManager:CleanupExpiredActions()
    local currentTime = tick()
    
    -- Remove actions older than UNDO_TIME_LIMIT
    for i = #self.actionHistory, 1, -1 do
        local action = self.actionHistory[i]
        if currentTime - action.timestamp > UNDO_TIME_LIMIT then
            table.remove(self.actionHistory, i)
        end
    end
end

function UndoManager:TryUndo()
    if self.isUndoing then
        print("UndoManager: Already undoing, please wait...")
        return
    end
    
    local latestAction = self.actionHistory[1]
    if not latestAction then
        print("UndoManager: No actions to undo")
        return
    end
    
    local timeElapsed = tick() - latestAction.timestamp
    if timeElapsed > UNDO_TIME_LIMIT then
        print("UndoManager: Action too old to undo")
        self:CleanupExpiredActions()
        return
    end
    
    print(string.format("UndoManager: Undoing %s action (ID: %d)", latestAction.type, latestAction.id))
    
    self.isUndoing = true
    
    -- Perform the undo based on action type
    local success = self:PerformUndo(latestAction)
    
    if success then
        -- Remove the action from history
        table.remove(self.actionHistory, 1)
        self:HideUndoNotification()
        
        -- Show undo success notification
        self:ShowSuccessNotification("Action undone successfully!")
    else
        self:ShowErrorNotification("Failed to undo action")
    end
    
    -- Reset undo flag after delay
    task.delay(0.5, function()
        self.isUndoing = false
    end)
end

function UndoManager:PerformUndo(action)
    local actionType = action.type
    local data = action.data
    
    if actionType == "place" then
        -- Undo place = destroy the placed item
        if data.instanceId and self.remotes.DestroyItem then
            self.remotes.DestroyItem:FireServer(data.instanceId, 0) -- No cost for undo
            return true
        end
        
    elseif actionType == "destroy" then
        -- Undo destroy = recreate the item
        if data.itemId and data.position and data.rotation and self.remotes.PlaceItem then
            -- Note: This is complex because we need to restore the exact item
            -- For now, place a new instance of the same item type
            self.remotes.PlaceItem:FireServer(data.itemId, data.position, data.rotation)
            return true
        end
        
    elseif actionType == "move" then
        -- Undo move = move back to original position
        if data.instanceId and data.originalPosition and self.remotes.MoveItem then
            self.remotes.MoveItem:FireServer(data.instanceId, data.originalPosition, 0) -- No cost for undo
            return true
        end
        
    elseif actionType == "rotate" then
        -- Undo rotate = rotate back to original rotation
        if data.instanceId and data.originalRotation and self.remotes.RotateItem then
            self.remotes.RotateItem:FireServer(data.instanceId, data.originalRotation, 0) -- No cost for undo
            return true
        end
        
    elseif actionType == "clone" then
        -- Undo clone = destroy the cloned item (if it was placed immediately)
        if data.clonedInstanceId and self.remotes.DestroyItem then
            self.remotes.DestroyItem:FireServer(data.clonedInstanceId, 0) -- No cost for undo
            return true
        end
    end
    
    warn(string.format("UndoManager: Don't know how to undo action type '%s'", actionType))
    return false
end

function UndoManager:ShowSuccessNotification(message)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    self:CreateTemporaryNotification(message, Color3.fromRGB(100, 255, 100), 2)
end

function UndoManager:ShowErrorNotification(message)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    self:CreateTemporaryNotification(message, Color3.fromRGB(255, 100, 100), 3)
end

function UndoManager:CreateTemporaryNotification(message, color, duration)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Create temporary notification
    local tempNotification = Instance.new("Frame")
    tempNotification.Size = UDim2.new(0, 250, 0, 40)
    tempNotification.Position = UDim2.new(0.5, -125, 0, 80)
    tempNotification.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    tempNotification.BackgroundTransparency = 0.1
    tempNotification.BorderSizePixel = 0
    tempNotification.Parent = self.undoUI
    
    -- Styling
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = tempNotification
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Parent = tempNotification
    
    -- Text
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.Text = message
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = tempNotification
    
    -- Animate and remove
    task.delay(duration, function()
        local fadeOut = TweenService:Create(
            tempNotification,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}
        )
        local fadeOutText = TweenService:Create(
            label,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {TextTransparency = 1}
        )
        
        fadeOut:Play()
        fadeOutText:Play()
        
        fadeOut.Completed:Connect(function()
            tempNotification:Destroy()
        end)
    end)
end

function UndoManager:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Remove UI
    if self.undoUI then
        self.undoUI:Destroy()
        self.undoUI = nil
    end
    
    print("UndoManager: Cleaned up successfully")
end

return UndoManager 