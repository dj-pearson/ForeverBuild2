local ENABLE_THIS_UI = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CurrencyUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 50)
frame.Position = UDim2.new(0.5, -110, 0, 20) -- Center top
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.ZIndex = 10
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
label.Text = "Coins: 0"
label.TextXAlignment = Enum.TextXAlignment.Center
label.ZIndex = 11
label.Parent = frame

-- Listen for balance updates
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateBalance = remotes:WaitForChild("UpdateBalance")

updateBalance.OnClientEvent:Connect(function(newBalance)
    label.Text = "Coins: " .. tostring(newBalance)
end)

-- Initial balance request
local getBalance = remotes:WaitForChild("GetBalance")
local initialBalance = getBalance:InvokeServer()
label.Text = "Coins: " .. tostring(initialBalance) 