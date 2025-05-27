-- BlueprintClientSetup.luau
-- Client-side initialization and setup for the Blueprint system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Wait for shared modules
local SharedModules = ReplicatedStorage:WaitForChild("Shared")
local BlueprintManager = require(SharedModules.core.blueprint.BlueprintManager)
local BlueprintUI = require(SharedModules.core.blueprint.BlueprintUI)

local BlueprintClientSetup = {}

-- Client configuration
local CLIENT_CONFIG = {
    NOTIFICATION_DURATION = 5,
    BLUEPRINT_PREVIEW_TRANSPARENCY = 0.5,
    KEYBOARD_SHORTCUTS = {
        TOGGLE_BLUEPRINT_UI = {Enum.KeyCode.B, Enum.KeyCode.LeftControl}, -- Ctrl+B
        QUICK_SAVE_BLUEPRINT = {Enum.KeyCode.S, Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift}, -- Ctrl+Shift+S
        PLACE_LAST_BLUEPRINT = {Enum.KeyCode.V, Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift} -- Ctrl+Shift+V
    }
}

function BlueprintClientSetup.Initialize()
    print("BlueprintClientSetup: Initializing client-side blueprint system...")
    
    -- Initialize the blueprint manager (client-side)
    local blueprintManager = BlueprintManager.new()
    
    -- Initialize the blueprint UI
    local blueprintUI = BlueprintUI.new(blueprintManager)
    
    -- Set up integrations
    BlueprintClientSetup.SetupKeyboardShortcuts(blueprintManager, blueprintUI)
    BlueprintClientSetup.SetupNotificationSystem(blueprintManager)
    BlueprintClientSetup.SetupBuildingToolsIntegration(blueprintManager, blueprintUI)
    BlueprintClientSetup.SetupXPIntegration(blueprintManager)
    
    -- Set up blueprint preview system
    BlueprintClientSetup.SetupBlueprintPreview(blueprintManager)
    
    print("BlueprintClientSetup: Client initialization complete!")
    
    return {
        blueprintManager = blueprintManager,
        blueprintUI = blueprintUI
    }
end

function BlueprintClientSetup.SetupKeyboardShortcuts(blueprintManager, blueprintUI)
    -- Set up keyboard shortcuts for blueprint system
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Toggle Blueprint UI (Ctrl+B)
        if input.KeyCode == Enum.KeyCode.B and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            blueprintUI:Toggle()
            BlueprintClientSetup.ShowNotification("Blueprint Workshop " .. (blueprintUI.isVisible and "opened" or "closed"), "info")
        end
        
        -- Quick Save Blueprint (Ctrl+Shift+S)
        if input.KeyCode == Enum.KeyCode.S and 
           UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 
           UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            BlueprintClientSetup.QuickSaveBlueprint(blueprintManager)
        end
        
        -- Place Last Blueprint (Ctrl+Shift+V)
        if input.KeyCode == Enum.KeyCode.V and 
           UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 
           UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            BlueprintClientSetup.PlaceLastBlueprint(blueprintManager)
        end
    end)
    
    print("BlueprintClientSetup: Keyboard shortcuts configured")
end

function BlueprintClientSetup.SetupNotificationSystem(blueprintManager)
    -- Create notification system for blueprint events
    local notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "BlueprintNotifications"
    notificationGui.ResetOnSpawn = false
    notificationGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local notificationFrame = Instance.new("Frame")
    notificationFrame.Name = "NotificationContainer"
    notificationFrame.Size = UDim2.new(0, 300, 1, 0)
    notificationFrame.Position = UDim2.new(1, -320, 0, 20)
    notificationFrame.BackgroundTransparency = 1
    notificationFrame.Parent = notificationGui
    
    local notificationLayout = Instance.new("UIListLayout")
    notificationLayout.FillDirection = Enum.FillDirection.Vertical
    notificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    notificationLayout.Padding = UDim.new(0, 10)
    notificationLayout.Parent = notificationFrame
    
    -- Store references for notification system
    BlueprintClientSetup.notificationGui = notificationGui
    BlueprintClientSetup.notificationFrame = notificationFrame
    
    -- Connect to blueprint manager events
    if blueprintManager.events then
        blueprintManager.events.BlueprintCreated:Connect(function(blueprintData)
            BlueprintClientSetup.ShowNotification("Blueprint '" .. blueprintData.name .. "' created successfully! 📐", "success")
        end)
        
        blueprintManager.events.BlueprintSaved:Connect(function(blueprintData)
            BlueprintClientSetup.ShowNotification("Blueprint '" .. blueprintData.name .. "' saved! 💾", "success")
        end)
        
        blueprintManager.events.BlueprintLoaded:Connect(function(blueprintData)
            BlueprintClientSetup.ShowNotification("Blueprint '" .. blueprintData.name .. "' loaded! 📋", "info")
        end)
        
        blueprintManager.events.BlueprintPlaced:Connect(function(blueprintData)
            BlueprintClientSetup.ShowNotification("Blueprint '" .. blueprintData.name .. "' placed! ✨", "success")
        end)
        
        blueprintManager.events.BlueprintError:Connect(function(errorMessage)
            BlueprintClientSetup.ShowNotification("Blueprint Error: " .. errorMessage, "error")
        end)
    end
    
    print("BlueprintClientSetup: Notification system configured")
end

function BlueprintClientSetup.ShowNotification(message, notificationType)
    if not BlueprintClientSetup.notificationFrame then return end
    
    local colors = {
        success = Color3.fromRGB(40, 167, 69),
        error = Color3.fromRGB(220, 53, 69),
        warning = Color3.fromRGB(255, 193, 7),
        info = Color3.fromRGB(100, 149, 237)
    }
    
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(1, 0, 0, 60)
    notification.BackgroundColor3 = colors[notificationType] or colors.info
    notification.BorderSizePixel = 0
    notification.Parent = BlueprintClientSetup.notificationFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, -10)
    textLabel.Position = UDim2.new(0, 10, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = message
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextWrapped = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = notification
    
    -- Animate in
    notification.Position = UDim2.new(1, 50, 0, 0)
    local tweenService = game:GetService("TweenService")
    local slideIn = tweenService:Create(notification,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 0, 0)}
    )
    slideIn:Play()
    
    -- Auto-remove after duration
    task.spawn(function()
        task.wait(CLIENT_CONFIG.NOTIFICATION_DURATION)
        
        local slideOut = tweenService:Create(notification,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 50, 0, 0)}
        )
        slideOut:Play()
        
        slideOut.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
end

function BlueprintClientSetup.SetupBuildingToolsIntegration(blueprintManager, blueprintUI)
    -- Integration with existing building tools system
    local buildingToolsManager = _G.BuildingToolsManager
    if buildingToolsManager then
        print("BlueprintClientSetup: Integrating with BuildingToolsManager")
        
        -- Add blueprint creation button to building tools
        if buildingToolsManager.AddCustomTool then
            buildingToolsManager:AddCustomTool({
                name = "Create Blueprint",
                icon = "📐",
                description = "Create a blueprint from selected items",
                callback = function()
                    BlueprintClientSetup.CreateBlueprintFromSelection(blueprintManager, buildingToolsManager)
                end
            })
        end
        
        -- Add blueprint placement mode
        if buildingToolsManager.AddPlacementMode then
            buildingToolsManager:AddPlacementMode({
                name = "Blueprint Placement",
                icon = "📋",
                description = "Place blueprints in the world",
                callback = function()
                    blueprintUI:Show()
                    blueprintUI:SwitchTab("MY_BLUEPRINTS")
                end
            })
        end
    else
        print("BlueprintClientSetup: BuildingToolsManager not found, skipping integration")
    end
end

function BlueprintClientSetup.CreateBlueprintFromSelection(blueprintManager, buildingToolsManager)
    if not buildingToolsManager or not buildingToolsManager.selectedItems then
        BlueprintClientSetup.ShowNotification("No items selected for blueprint creation", "warning")
        return
    end
    
    local selectedItems = buildingToolsManager.selectedItems
    if #selectedItems == 0 then
        BlueprintClientSetup.ShowNotification("Please select items first using building tools", "warning")
        return
    end
    
    -- Convert selected items to blueprint format
    local blueprintItems = {}
    local centerPosition = Vector3.new(0, 0, 0)
    
    -- Calculate center position
    for _, item in ipairs(selectedItems) do
        if item.PrimaryPart then
            centerPosition = centerPosition + item.PrimaryPart.Position
        end
    end
    centerPosition = centerPosition / #selectedItems
    
    -- Create relative positions
    for _, item in ipairs(selectedItems) do
        if item.PrimaryPart then
            local relativePosition = item.PrimaryPart.Position - centerPosition
            local rotation = item.PrimaryPart.Rotation
            
            table.insert(blueprintItems, {
                itemId = item.Name,
                position = relativePosition,
                rotation = rotation,
                properties = BlueprintClientSetup.ExtractItemProperties(item)
            })
        end
    end
    
    -- Create blueprint data
    local blueprintData = {
        name = "New Blueprint " .. os.date("%H:%M"),
        description = "Created from " .. #blueprintItems .. " selected items",
        category = "custom",
        tags = {"custom", "player-made"},
        items = blueprintItems,
        creatorId = LocalPlayer.UserId,
        creatorName = LocalPlayer.Name,
        isPublic = false
    }
    
    -- Save the blueprint
    if blueprintManager.CreateBlueprint then
        blueprintManager:CreateBlueprint(blueprintData)
        BlueprintClientSetup.ShowNotification("Blueprint created with " .. #blueprintItems .. " items!", "success")
    end
end

function BlueprintClientSetup.ExtractItemProperties(item)
    -- Extract relevant properties from an item for blueprint storage
    local properties = {}
    
    if item.PrimaryPart then
        properties.material = item.PrimaryPart.Material.Name
        properties.color = {
            r = item.PrimaryPart.Color.R,
            g = item.PrimaryPart.Color.G,
            b = item.PrimaryPart.Color.B
        }
        properties.size = {
            x = item.PrimaryPart.Size.X,
            y = item.PrimaryPart.Size.Y,
            z = item.PrimaryPart.Size.Z
        }
    end
    
    return properties
end

function BlueprintClientSetup.SetupXPIntegration(blueprintManager)
    -- Integration with XP system for blueprint-related achievements
    local xpManager = _G.XPManager
    if xpManager then
        print("BlueprintClientSetup: Integrating with XP system")
        
        -- Listen for blueprint milestones
        if blueprintManager.events then
            blueprintManager.events.BlueprintCreated:Connect(function(blueprintData)
                -- Check for blueprint creation milestones
                local playerBlueprints = blueprintManager:GetPlayerBlueprints(LocalPlayer)
                if playerBlueprints then
                    local count = #playerBlueprints
                    if count == 1 then
                        BlueprintClientSetup.ShowNotification("🎉 First Blueprint Created! Welcome to the Blueprint Workshop!", "success")
                    elseif count == 5 then
                        BlueprintClientSetup.ShowNotification("🎉 5 Blueprints Created! You're becoming a master builder!", "success")
                    elseif count == 10 then
                        BlueprintClientSetup.ShowNotification("🎉 10 Blueprints Created! Blueprint Architect unlocked!", "success")
                    end
                end
            end)
        end
    end
end

function BlueprintClientSetup.SetupBlueprintPreview(blueprintManager)
    -- Set up blueprint preview system for placement
    local previewFolder = Instance.new("Folder")
    previewFolder.Name = "BlueprintPreview"
    previewFolder.Parent = workspace
    
    BlueprintClientSetup.previewFolder = previewFolder
    
    -- Mouse tracking for blueprint placement
    local mouse = LocalPlayer:GetMouse()
    BlueprintClientSetup.mouse = mouse
    
    print("BlueprintClientSetup: Blueprint preview system configured")
end

function BlueprintClientSetup.QuickSaveBlueprint(blueprintManager)
    -- Quick save functionality for current selection
    local buildingToolsManager = _G.BuildingToolsManager
    if buildingToolsManager and buildingToolsManager.selectedItems and #buildingToolsManager.selectedItems > 0 then
        BlueprintClientSetup.CreateBlueprintFromSelection(blueprintManager, buildingToolsManager)
    else
        BlueprintClientSetup.ShowNotification("No items selected for quick save", "warning")
    end
end

function BlueprintClientSetup.PlaceLastBlueprint(blueprintManager)
    -- Place the last created or used blueprint
    if blueprintManager.lastBlueprint then
        local blueprint = blueprintManager.lastBlueprint
        BlueprintClientSetup.ShowNotification("Placing blueprint: " .. blueprint.name, "info")
        
        -- Start blueprint placement mode
        BlueprintClientSetup.StartBlueprintPlacement(blueprint)
    else
        BlueprintClientSetup.ShowNotification("No recent blueprint to place", "warning")
    end
end

function BlueprintClientSetup.StartBlueprintPlacement(blueprint)
    -- Start interactive blueprint placement
    if not blueprint or not blueprint.items then return end
    
    BlueprintClientSetup.ShowNotification("Click to place blueprint. Press ESC to cancel.", "info")
    
    -- Create preview
    BlueprintClientSetup.CreateBlueprintPreview(blueprint)
    
    -- Set up placement interaction
    local connection
    connection = BlueprintClientSetup.mouse.Button1Down:Connect(function()
        local hitPos = BlueprintClientSetup.mouse.Hit.Position
        BlueprintClientSetup.PlaceBlueprintAt(blueprint, hitPos)
        BlueprintClientSetup.ClearBlueprintPreview()
        connection:Disconnect()
    end)
    
    -- ESC to cancel
    local escConnection
    escConnection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            BlueprintClientSetup.ClearBlueprintPreview()
            BlueprintClientSetup.ShowNotification("Blueprint placement cancelled", "info")
            connection:Disconnect()
            escConnection:Disconnect()
        end
    end)
end

function BlueprintClientSetup.CreateBlueprintPreview(blueprint)
    BlueprintClientSetup.ClearBlueprintPreview()
    
    for _, itemData in ipairs(blueprint.items) do
        local previewPart = Instance.new("Part")
        previewPart.Name = "Preview_" .. itemData.itemId
        previewPart.Size = Vector3.new(2, 2, 2) -- Default size
        previewPart.Material = Enum.Material.ForceField
        previewPart.Transparency = CLIENT_CONFIG.BLUEPRINT_PREVIEW_TRANSPARENCY
        previewPart.Color = Color3.fromRGB(100, 149, 237)
        previewPart.CanCollide = false
        previewPart.Anchored = true
        previewPart.Parent = BlueprintClientSetup.previewFolder
        
        -- Update preview position based on mouse
        local updateConnection
        updateConnection = RunService.Heartbeat:Connect(function()
            if BlueprintClientSetup.mouse.Hit then
                local basePosition = BlueprintClientSetup.mouse.Hit.Position
                previewPart.Position = basePosition + itemData.position
            end
        end)
        
        previewPart:SetAttribute("UpdateConnection", updateConnection)
    end
end

function BlueprintClientSetup.ClearBlueprintPreview()
    for _, child in ipairs(BlueprintClientSetup.previewFolder:GetChildren()) do
        local connection = child:GetAttribute("UpdateConnection")
        if connection then
            connection:Disconnect()
        end
        child:Destroy()
    end
end

function BlueprintClientSetup.PlaceBlueprintAt(blueprint, position)
    -- Place blueprint at specified position
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local placeBlueprintRemote = remotes:FindFirstChild("PlaceBlueprint")
        if placeBlueprintRemote then
            placeBlueprintRemote:FireServer(blueprint, position)
            BlueprintClientSetup.ShowNotification("Blueprint '" .. blueprint.name .. "' placed!", "success")
        end
    end
end

-- Initialize when script runs
if RunService:IsClient() then
    local systems = BlueprintClientSetup.Initialize()
    
    -- Store references for other scripts
    _G.BlueprintManager = systems.blueprintManager
    _G.BlueprintUI = systems.blueprintUI
    
    -- Show welcome message
    task.spawn(function()
        task.wait(3)
        BlueprintClientSetup.ShowNotification("📐 Blueprint Workshop ready! Press Ctrl+B to open", "info")
    end)
end

return BlueprintClientSetup 