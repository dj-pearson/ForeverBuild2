-- DisableDefaultLeaderboardClient.luau
-- Client-side script to disable default Roblox leaderboard and create minimal HUD

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Disable the default Roblox leaderboard
local success, error = pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

if success then
    print("DisableDefaultLeaderboardClient: Default leaderboard disabled successfully")
else
    warn("DisableDefaultLeaderboardClient: Failed to disable default leaderboard:", error)
end

-- Create a minimal HUD for essential stats
local function createMinimalHUD()
    -- Create minimal stats display
    local hudGui = Instance.new("ScreenGui")
    hudGui.Name = "MinimalStatsHUD"
    hudGui.ResetOnSpawn = false
    hudGui.Parent = playerGui
    
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(0, 200, 0, 100)
    statsFrame.Position = UDim2.new(1, -220, 0, 20)
    statsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = hudGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = statsFrame
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Padding = UDim.new(0, 5)
    layout.Parent = statsFrame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingAll = UDim.new(0, 10)
    padding.Parent = statsFrame
    
    -- Cash display
    local cashLabel = Instance.new("TextLabel")
    cashLabel.Name = "CashLabel"
    cashLabel.Size = UDim2.new(1, 0, 0, 20)
    cashLabel.BackgroundTransparency = 1
    cashLabel.Text = "💰 $0"
    cashLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    cashLabel.TextSize = 16
    cashLabel.Font = Enum.Font.GothamBold
    cashLabel.TextXAlignment = Enum.TextXAlignment.Left
    cashLabel.Parent = statsFrame
    
    -- Level display
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel" 
    levelLabel.Size = UDim2.new(1, 0, 0, 20)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "⭐ Level 1"
    levelLabel.TextColor3 = Color3.fromRGB(100, 149, 237)
    levelLabel.TextSize = 14
    levelLabel.Font = Enum.Font.Gotham
    levelLabel.TextXAlignment = Enum.TextXAlignment.Left
    levelLabel.Parent = statsFrame
    
    -- Items placed today
    local itemsLabel = Instance.new("TextLabel")
    itemsLabel.Name = "ItemsLabel"
    itemsLabel.Size = UDim2.new(1, 0, 0, 20)
    itemsLabel.BackgroundTransparency = 1
    itemsLabel.Text = "🔨 0 items today"
    itemsLabel.TextColor3 = Color3.fromRGB(40, 167, 69)
    itemsLabel.TextSize = 14
    itemsLabel.Font = Enum.Font.Gotham
    itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemsLabel.Parent = statsFrame
    
    -- Leaderboard shortcut hint
    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "HintLabel"
    hintLabel.Size = UDim2.new(1, 0, 0, 15)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "Ctrl+L for leaderboards"
    hintLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    hintLabel.TextSize = 10
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.Parent = statsFrame
    
    return {cashLabel = cashLabel, levelLabel = levelLabel, itemsLabel = itemsLabel}
end

-- Wait for player to fully load
player.CharacterAdded:Wait()
task.wait(2)

local hudElements = createMinimalHUD()
print("DisableDefaultLeaderboardClient: Minimal HUD created")

-- Update stats periodically
task.spawn(function()
    while player.Parent and hudElements.cashLabel.Parent do
        task.wait(5) -- Update every 5 seconds
        
        -- Get player data from existing systems
        local success, playerData = pcall(function()
            -- Try to get data from ForeverBuild systems
            local currencyManager = _G.ForeverBuildSystems and _G.ForeverBuildSystems.CurrencyManager
            local xpManager = _G.ForeverBuildSystems and _G.ForeverBuildSystems.XPManager
            local leaderboardManager = _G.ForeverBuildSystems and _G.ForeverBuildSystems.LeaderboardManager
            
            local cash = 0
            local level = 1
            local dailyItems = 0
            
            -- Get cash from currency manager or from existing UI
            if currencyManager and currencyManager.GetPlayerCurrency then
                cash = currencyManager:GetPlayerCurrency(player) or 0
            else
                -- Fallback: try to get from existing currency UI
                local existingCurrencyUI = playerGui:FindFirstChild("CurrencyUI")
                if existingCurrencyUI then
                    local balanceLabel = existingCurrencyUI:FindFirstChild("BalanceLabel", true)
                    if balanceLabel and balanceLabel.Text then
                        local balanceText = balanceLabel.Text:match("%d+")
                        cash = tonumber(balanceText) or 0
                    end
                end
            end
            
            -- Get level from XP manager
            if xpManager and xpManager.GetPlayerLevel then
                level = xpManager:GetPlayerLevel(player) or 1
            end
            
            -- Get today's items placed count
            if leaderboardManager and leaderboardManager.GetPlayerStat then
                local playerStats = leaderboardManager:GetPlayerStat(player, "ItemsPlaced")
                if playerStats and playerStats.dailyCount then
                    dailyItems = playerStats.dailyCount
                end
            end
            
            return {cash = cash, level = level, dailyItems = dailyItems}
        end)
        
        if success and playerData and hudElements.cashLabel.Parent then
            -- Format cash with K/M notation
            local cashText = "💰 $" .. (playerData.cash >= 1000000 and string.format("%.1fM", playerData.cash/1000000) or
                                       playerData.cash >= 1000 and string.format("%.1fK", playerData.cash/1000) or
                                       tostring(playerData.cash))
            hudElements.cashLabel.Text = cashText
            hudElements.levelLabel.Text = "⭐ Level " .. playerData.level
            hudElements.itemsLabel.Text = "🔨 " .. playerData.dailyItems .. " items today"
        end
    end
end)

print("DisableDefaultLeaderboardClient: Hybrid leaderboard system initialized") 