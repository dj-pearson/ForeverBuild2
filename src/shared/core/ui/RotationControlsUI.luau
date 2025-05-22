-- RotationControlsUI.luau
-- Manages the display of rotation control instructions.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RotationControlsUI = {}
RotationControlsUI.__index = RotationControlsUI

function RotationControlsUI.new()
    local self = setmetatable({}, RotationControlsUI)

    self.player = Players.LocalPlayer
    if not self.player then
        warn("RotationControlsUI: Player not found at instantiation time.")
        return nil -- Cannot proceed without player
    end
    self.playerGui = self.player:WaitForChild("PlayerGui")

    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "RotationControlsScreenGui"
    self.screenGui.ResetOnSpawn = false
    self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.screenGui.DisplayOrder = 1000 -- High display order to be on top
    self.screenGui.Enabled = false -- Initially hidden

    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "RotationInstructionsFrame"
    self.mainFrame.Size = UDim2.new(0, 280, 0, 140) -- Adjusted size for more text
    self.mainFrame.Position = UDim2.new(0, 15, 1, -155) -- Bottom-left corner (15px padding from left, 15px from bottom)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    self.mainFrame.BackgroundTransparency = 0.15
    self.mainFrame.BorderSizePixel = 1
    self.mainFrame.BorderColor3 = Color3.fromRGB(80, 80, 85)
    self.mainFrame.Parent = self.screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.mainFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = self.mainFrame

    self.titleLabel = Instance.new("TextLabel")
    self.titleLabel.Name = "Title"
    self.titleLabel.Size = UDim2.new(1, 0, 0, 20)
    self.titleLabel.Text = "Rotation Controls"
    self.titleLabel.Font = Enum.Font.GothamBold
    self.titleLabel.TextSize = 18
    self.titleLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    self.titleLabel.BackgroundTransparency = 1
    self.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.titleLabel.Parent = self.mainFrame

    self.instructionsLabel = Instance.new("TextLabel")
    self.instructionsLabel.Name = "Instructions"
    self.instructionsLabel.Size = UDim2.new(1, 0, 1, -30) -- Fill remaining space, accounting for title and padding
    self.instructionsLabel.Position = UDim2.new(0, 0, 0, 25) -- Position below title
    self.instructionsLabel.Text = "" -- Will be set by platform
    self.instructionsLabel.Font = Enum.Font.Gotham
    self.instructionsLabel.TextSize = 14
    self.instructionsLabel.TextColor3 = Color3.fromRGB(200, 205, 210)
    self.instructionsLabel.BackgroundTransparency = 1
    self.instructionsLabel.TextWrapped = true
    self.instructionsLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.instructionsLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.instructionsLabel.LineHeight = 1.2
    self.instructionsLabel.Parent = self.mainFrame
    
    self.screenGui.Parent = self.playerGui -- Parent at the end to ensure PlayerGui is ready

    return self
end

function RotationControlsUI:GetPlatformType()
    -- More robust platform detection
    if UserInputService.GamepadEnabled then
        local gamepads = UserInputService:GetConnectedGamepads()
        if #gamepads > 0 then
            return "Gamepad"
        end
    end
    if UserInputService.TouchEnabled then -- Check TouchEnabled before MouseEnabled as some devices have both
        return "Touch"
    end
    if UserInputService.MouseEnabled then -- Assume KeyboardMouse if mouse is enabled and not primarily touch/gamepad
        return "KeyboardMouse"
    end
    return "KeyboardMouse" -- Fallback
end

function RotationControlsUI:ShowInstructions()
    if not self.screenGui then return end -- Guard against destroyed UI

    local platform = self:GetPlatformType()
    local instructions = ""

    if platform == "KeyboardMouse" then
        instructions = "Rotate:\n" ..
                       "  Q/E : Yaw (Turn Left/Right)\n" ..
                       "  R/F : Pitch (Tilt Up/Down)\n" ..
                       "  Z/X : Roll (Spin Left/Right)\n\n" ..
                       "Confirm: Left Mouse / Enter\n" ..
                       "Cancel: Right Mouse / Escape"
    elseif platform == "Gamepad" then
        instructions = "Rotate:\n" ..
                       "  Left Stick : Yaw/Pitch\n" ..
                       "  Right Stick : Roll / Fine Tune\n" .. -- Example mapping
                       "  (D-Pad might also work)\n\n" ..
                       "Confirm: A Button (or X on PS)\n" .. -- Common confirm buttons
                       "Cancel: B Button (or O on PS)"   -- Common cancel buttons
    elseif platform == "Touch" then
        instructions = "Rotate: Use On-Screen Controls\n" ..
                       "  (Specific gestures TBD)\n\n" ..
                       "Confirm: ✅ (Tap Button)\n" .. 
                       "Cancel: ❌ (Tap Button)"
    else
        instructions = "Controls not defined for this platform."
    end
    
    self.instructionsLabel.Text = instructions
    self.screenGui.Enabled = true
    print("RotationControlsUI: Shown for platform - " .. platform)
end

function RotationControlsUI:HideInstructions()
    if not self.screenGui then return end
    self.screenGui.Enabled = false
    print("RotationControlsUI: Hidden")
end

function RotationControlsUI:Destroy()
    if self.screenGui then
        self.screenGui:Destroy()
        self.screenGui = nil
        self.player = nil
        self.playerGui = nil
        print("RotationControlsUI destroyed.")
    end
end

return RotationControlsUI 