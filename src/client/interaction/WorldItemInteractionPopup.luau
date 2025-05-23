-- WorldItemInteractionPopup.luau
-- Interaction popup system for placed world items (matches bottom purchase popup style)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Safely require SharedModule for Constants
local SharedModule
local success = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
end)

if not success then
    warn("WorldItemInteractionPopup: Could not load SharedModule, using fallback")
    SharedModule = {
        Constants = {
            ITEM_ACTIONS = {
                destroy = { cost = 4, label = "Destroy", icon = "🗑️" },
                clone = { cost = 5, label = "Clone", icon = "📋" },
                rotate = { cost = 0, label = "Rotate", icon = "🔄" },
                recall = { cost = 1, label = "Recall", icon = "↩️" },
                move = { cost = 3, label = "Move", icon = "🚚" }
            }
        }
    }
end

local WorldItemInteractionPopup = {}
WorldItemInteractionPopup.__index = WorldItemInteractionPopup

function WorldItemInteractionPopup.new()
    local self = setmetatable({}, WorldItemInteractionPopup)
    
    -- State
    self.currentPopup = nil
    self.currentTarget = nil
    
    return self
end

function WorldItemInteractionPopup:CreateInteractionPopup(target)
    local itemName = target.Name:gsub("_", " ")
    local itemId = target:GetAttribute("itemId") or target.Name
    local instanceId = target:GetAttribute("instanceId")
    
    -- Remove existing popup
    if self.currentPopup then
        self.currentPopup:Destroy()
        self.currentPopup = nil
    end
    
    -- Create popup container
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WorldItemInteractionPopup"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main popup frame (similar style to purchase popup but taller for actions)
    local popupFrame = Instance.new("Frame")
    popupFrame.Size = UDim2.new(0, 320, 0, 220) -- Taller for action buttons
    popupFrame.Position = UDim2.new(0.5, -160, 0.5, -110) -- Center of screen
    popupFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    popupFrame.BorderSizePixel = 0
    popupFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = popupFrame
    
    -- Subtle border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = popupFrame
    
    -- Header with item name and close button
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    header.BorderSizePixel = 0
    header.Parent = popupFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    
    -- Fix rounded corners on header (only top corners)
    local headerBottomCover = Instance.new("Frame")
    headerBottomCover.Size = UDim2.new(1, 0, 0, 8)
    headerBottomCover.Position = UDim2.new(0, 0, 1, -8)
    headerBottomCover.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    headerBottomCover.BorderSizePixel = 0
    headerBottomCover.Parent = header
    
    -- Item name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -50, 1, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = header
    
    -- Close button (X)
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Content area for action buttons
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = popupFrame
    
    -- Create action buttons
    self:CreateActionButtons(contentFrame, target)
    
    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        self:HidePopup()
    end)
    
    -- Smooth scale-in animation
    popupFrame.Size = UDim2.new(0, 0, 0, 0)
    popupFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local scaleIn = TweenService:Create(popupFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 220),
        Position = UDim2.new(0.5, -160, 0.5, -110)
    })
    scaleIn:Play()
    
    self.currentPopup = screenGui
    self.currentTarget = target
    print("WorldItemInteractionPopup: Showing interaction popup for", itemName)
end

function WorldItemInteractionPopup:CreateActionButtons(parent, target)
    local Constants = SharedModule.Constants
    local actions = Constants.ITEM_ACTIONS or {}
    
    -- Create a list layout
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = parent
    
    -- Define action order (matching your screenshot)
    local actionOrder = {"destroy", "clone", "rotate", "recall", "move"}
    
    for i, actionKey in ipairs(actionOrder) do
        local actionData = actions[actionKey]
        if actionData then
            self:CreateActionButton(parent, actionKey, actionData, i, target)
        end
    end
end

function WorldItemInteractionPopup:CreateActionButton(parent, actionKey, actionData, layoutOrder, target)
    local cost = actionData.cost or 0
    local label = actionData.label or actionKey
    local icon = actionData.icon or "🔧"
    
    -- Action button
    local actionButton = Instance.new("TextButton")
    actionButton.Size = UDim2.new(1, 0, 0, 30)
    actionButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    actionButton.Text = string.format("%s %s (Cost: %d)", icon, label, cost)
    actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionButton.TextSize = 14
    actionButton.Font = Enum.Font.Gotham
    actionButton.LayoutOrder = layoutOrder
    actionButton.Parent = parent
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = actionButton
    
    -- Hover effect
    actionButton.MouseEnter:Connect(function()
        local hoverTween = TweenService:Create(actionButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        })
        hoverTween:Play()
    end)
    
    actionButton.MouseLeave:Connect(function()
        local leaveTween = TweenService:Create(actionButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        })
        leaveTween:Play()
    end)
    
    -- Button click handler
    actionButton.MouseButton1Click:Connect(function()
        print("WorldItemInteractionPopup: Performing action", actionKey, "on", target.Name)
        self:PerformAction(target, actionKey, cost)
    end)
end

function WorldItemInteractionPopup:PerformAction(target, actionKey, cost)
    local instanceId = target:GetAttribute("instanceId")
    if not instanceId then
        warn("WorldItemInteractionPopup: Target missing instanceId attribute")
        return
    end
    
    -- Find the appropriate remote event
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        warn("WorldItemInteractionPopup: Remotes folder not found")
        return
    end
    
    -- Map action keys to remote event names
    local remoteMap = {
        destroy = "RequestDestroyItem",
        clone = "RequestCloneItem", 
        rotate = "RequestRotateItem",
        recall = "RequestRecallItem",
        move = "RequestMoveItem"
    }
    
    local remoteName = remoteMap[actionKey]
    if not remoteName then
        warn("WorldItemInteractionPopup: No remote mapping for action", actionKey)
        return
    end
    
    local remoteEvent = remotes:FindFirstChild(remoteName)
    if not remoteEvent then
        warn("WorldItemInteractionPopup: Remote event not found:", remoteName)
        return
    end
    
    -- Fire the remote event with the instance ID
    print("WorldItemInteractionPopup: Firing", remoteName, "with instanceId:", instanceId)
    remoteEvent:FireServer(instanceId)
    
    -- Hide popup after action
    self:HidePopup()
end

function WorldItemInteractionPopup:HidePopup()
    if self.currentPopup then
        local popupFrame = self.currentPopup:FindFirstChild("Frame")
        if popupFrame then
            local scaleOut = TweenService:Create(popupFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0)
            })
            scaleOut:Play()
            scaleOut.Completed:Connect(function()
                self.currentPopup:Destroy()
                self.currentPopup = nil
            end)
        else
            self.currentPopup:Destroy()
            self.currentPopup = nil
        end
    end
    self.currentTarget = nil
end

function WorldItemInteractionPopup:Show(target)
    if target then
        self:CreateInteractionPopup(target)
    end
end

function WorldItemInteractionPopup:Hide()
    self:HidePopup()
end

return WorldItemInteractionPopup 