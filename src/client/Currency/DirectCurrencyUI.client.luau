print("--- DirectCurrencyUI.client.luau: MODIFIED TO FIX FORMATTING AND SET TO DISABLED ---")
local ENABLE_THIS_UI = false -- Setting to false to disable this UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if not ENABLE_THIS_UI then
    print("DirectCurrencyUI: Disabled via ENABLE_THIS_UI flag")
    script:Destroy()
    return
end

-- Create the UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CurrencyDirectUI" -- Renamed to avoid conflict with SharedModule.CurrencyUI
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 50)
frame.Position = UDim2.new(0.5, -110, 0, 20) -- Center top
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.ZIndex = 10 -- Ensure it's reasonably high
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -20, 1, 0)
label.Position = UDim2.new(0, 10, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 22
label.Font = Enum.Font.GothamBold
label.Text = "Coins: --" -- Initial text before first update
label.TextXAlignment = Enum.TextXAlignment.Center
label.ZIndex = 11
label.Parent = frame

-- Listen for balance updates
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15) -- Increased timeout

if not remotesFolder then
    warn("DirectCurrencyUI: Remotes folder not found after 15 seconds. UI will not update.")
    return
end

local updateBalanceEvent = remotesFolder:FindFirstChild("UpdateBalance")

if updateBalanceEvent and updateBalanceEvent:IsA("RemoteEvent") then
    updateBalanceEvent.OnClientEvent:Connect(function(newBalance)
        if typeof(newBalance) == "number" then
            label.Text = "Coins: " .. tostring(newBalance) -- Changed from string.format
        else
            label.Text = "Coins: Error"
            warn("DirectCurrencyUI: Received non-number for newBalance:", newBalance)
        end
    end)
    print("DirectCurrencyUI: Connected to UpdateBalance event.")
else
    warn("DirectCurrencyUI: UpdateBalance RemoteEvent not found or not a RemoteEvent. UI will not update.")
end

-- Removed initial balance request via GetBalance:InvokeServer()
print("DirectCurrencyUI: Setup complete. Waiting for UpdateBalance event for initial display.") 