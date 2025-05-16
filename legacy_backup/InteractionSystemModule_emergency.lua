local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- This is a minimal emergency fallback InteractionSystem
-- It provides only the essential functionality needed to get the game running
-- Insert this script directly into the client folder if other methods fail

print("🛠️ EMERGENCY FALLBACK INTERACTION SYSTEM LOADING 🛠️")

local InteractionSystem = {}
InteractionSystem.__index = InteractionSystem

-- Create a minimal implementation that won't error
function InteractionSystem.new()
    local self = setmetatable({}, InteractionSystem)
    self.player = Players.LocalPlayer
    self.currentTarget = nil
    self.initialized = false
    
    -- Make sure Remotes folder exists
    self.remoteEvents = ReplicatedStorage:FindFirstChild("Remotes")
    if not self.remoteEvents then
        self.remoteEvents = Instance.new("Folder")
        self.remoteEvents.Name = "Remotes"
        self.remoteEvents.Parent = ReplicatedStorage
        warn("[EMERGENCY] Created missing Remotes folder")
    end
    
    print("📡 Emergency InteractionSystem instance created")
    return self
end

function InteractionSystem:Initialize()
    print("📡 Emergency InteractionSystem initializing...")
    
    if self.initialized then
        print("📡 Emergency InteractionSystem already initialized")
        return
    end
    
    -- Create minimal player notification system
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if playerGui then
        local notificationUI = Instance.new("ScreenGui")
        notificationUI.Name = "EmergencyNotifications"
        notificationUI.ResetOnSpawn = false
        notificationUI.Parent = playerGui
        
        local frame = Instance.new("Frame")
        frame.Name = "MessageFrame"
        frame.Size = UDim2.new(0, 400, 0, 100)
        frame.Position = UDim2.new(0.5, -200, 0.1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.Parent = notificationUI
        
        local message = Instance.new("TextLabel")
        message.Name = "Message"
        message.Size = UDim2.new(1, -20, 1, -20)
        message.Position = UDim2.new(0, 10, 0, 10)
        message.BackgroundTransparency = 1
        message.TextColor3 = Color3.fromRGB(255, 255, 255)
        message.TextSize = 18
        message.Font = Enum.Font.Gotham
        message.Text = "Emergency Mode: Interaction System Limited"
        message.TextWrapped = true
        message.Parent = frame
        
        local button = Instance.new("TextButton")
        button.Name = "CloseButton"
        button.Size = UDim2.new(0, 30, 0, 30)
        button.Position = UDim2.new(1, -30, 0, 0)
        button.BackgroundTransparency = 1
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 18
        button.Font = Enum.Font.GothamBold
        button.Text = "X"
        button.Parent = frame
        
        button.MouseButton1Click:Connect(function()
            frame.Visible = false
        end)
        
        self.notificationUI = notificationUI
        self.messageFrame = frame
        self.messageLabel = message
    end
    
    -- Show emergency notification
    self:ShowEmergencyMessage("Emergency Mode: Limited interaction functionality available", 5)
    
    self.initialized = true
    print("📡 Emergency InteractionSystem initialized")
    return true
end

function InteractionSystem:ShowEmergencyMessage(text, duration)
    if not self.messageFrame or not self.messageLabel then return end
    
    self.messageLabel.Text = text
    self.messageFrame.Visible = true
    
    -- Auto-hide after duration seconds
    if duration then
        task.delay(duration, function()
            if self.messageFrame then
                self.messageFrame.Visible = false
            end
        end)
    end
end

-- Basic method stubs that won't error
function InteractionSystem:SetupMouseHandling()
    print("📡 Emergency InteractionSystem: SetupMouseHandling called")
end

function InteractionSystem:SetupEventHandlers()
    print("📡 Emergency InteractionSystem: SetupEventHandlers called")
end

function InteractionSystem:UpdateCurrentTarget()
    -- Intentionally empty to avoid errors
end

function InteractionSystem:CreateUI()
    print("📡 Emergency InteractionSystem: CreateUI called")
    -- This is just a stub
end

function InteractionSystem:AttemptInteraction()
    self:ShowEmergencyMessage("Interactions are limited in emergency mode", 3)
end

function InteractionSystem:GetAvailableInteractions()
    return {"examine"}
end

function InteractionSystem:ShowInteractionMenu()
    self:ShowEmergencyMessage("Interaction menu unavailable in emergency mode", 3)
end

function InteractionSystem:PerformInteraction()
    self:ShowEmergencyMessage("Interactions unavailable in emergency mode", 3)
end

function InteractionSystem:Cleanup()
    if self.notificationUI then
        self.notificationUI:Destroy()
    end
end

return InteractionSystem
