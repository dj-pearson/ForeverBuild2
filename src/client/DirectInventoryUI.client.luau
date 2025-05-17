local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Configuration
local ENABLE_THIS_UI = true -- Set to true to use this UI

-- Only proceed if this UI is enabled
if not ENABLE_THIS_UI then
    print("DirectInventoryUI: Disabled via ENABLE_THIS_UI flag")
    return
end

local TweenService = game:GetService("TweenService")

-- Constants
local ANIMATION_DURATION = 0.3
local ITEM_SIZE = UDim2.new(0, 100, 0, 120)
local ITEMS_PER_ROW = 5
local ITEM_PADDING = 10

-- Variables to store UI references
local inventoryUI
local currentInventory = {}

print("DirectInventoryUI: Starting initialization")

local function createInventoryUI()
    print("DirectInventoryUI: Creating standalone inventory UI...")
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Check if InventoryUI already exists
    local existingUI = playerGui:FindFirstChild("InventoryUI")
    if existingUI then
        print("DirectInventoryUI: InventoryUI already exists, removing it")
        existingUI:Destroy()
    end
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InventoryUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create main frame
    local inventory = Instance.new("Frame")
    inventory.Name = "InventoryFrame"
    inventory.Size = UDim2.new(0, 600, 0, 400)
    inventory.Position = UDim2.new(0.5, -300, 0.5, -200) -- Center of screen
    inventory.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    inventory.BorderSizePixel = 0
    inventory.Visible = false
    inventory.Parent = screenGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = inventory
    
    -- Add shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = inventory
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = inventory
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Inventory"
    title.TextSize = 24
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local currency = Instance.new("TextLabel")
    currency.Name = "Currency"
    currency.Size = UDim2.new(0, 100, 1, 0)
    currency.Position = UDim2.new(1, -120, 0, 0)
    currency.BackgroundTransparency = 1
    currency.Font = Enum.Font.GothamBold
    currency.Text = "0"
    currency.TextSize = 20
    currency.TextColor3 = Color3.fromRGB(255, 215, 0)
    currency.TextXAlignment = Enum.TextXAlignment.Right
    currency.Parent = titleBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.TextSize = 18
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Items container with scrolling
    local itemsContainer = Instance.new("ScrollingFrame")
    itemsContainer.Name = "ItemsContainer"
    itemsContainer.Size = UDim2.new(1, -40, 1, -70)
    itemsContainer.Position = UDim2.new(0, 20, 0, 60)
    itemsContainer.BackgroundTransparency = 1
    itemsContainer.BorderSizePixel = 0
    itemsContainer.ScrollBarThickness = 6
    itemsContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    itemsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    itemsContainer.Parent = inventory
    
    -- Create grid layout
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = ITEM_SIZE
    gridLayout.CellPadding = UDim2.new(0, ITEM_PADDING, 0, ITEM_PADDING)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = itemsContainer
    
    -- No items message (shown when inventory is empty)
    local noItemsLabel = Instance.new("TextLabel")
    noItemsLabel.Name = "NoItemsLabel"
    noItemsLabel.Size = UDim2.new(1, 0, 0, 40)
    noItemsLabel.Position = UDim2.new(0, 0, 0, 100)
    noItemsLabel.BackgroundTransparency = 1
    noItemsLabel.Font = Enum.Font.Gotham
    noItemsLabel.Text = "Your inventory is empty. Purchase items to see them here."
    noItemsLabel.TextSize = 16
    noItemsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    noItemsLabel.TextWrapped = true
    noItemsLabel.Parent = inventory
    
    print("DirectInventoryUI: Successfully created inventory UI")
    return screenGui
end

-- Function to create an item button
local function createItemButton(itemName, itemData)
    local button = Instance.new("TextButton")
    button.Name = itemName
    button.Size = ITEM_SIZE
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.AutoButtonColor = false
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Item icon (using a standard image as fallback)
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -20, 0, 60)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://6034973115" -- Default coin icon as fallback
    icon.Parent = button
    
    -- Item name
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -20, 0, 20)
    name.Position = UDim2.new(0, 10, 0, 80)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.Text = itemName
    name.TextSize = 14
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Parent = button
    
    -- Tier label
    local tierLabel = Instance.new("TextLabel")
    tierLabel.Name = "Tier"
    tierLabel.Size = UDim2.new(1, -20, 0, 20)
    tierLabel.Position = UDim2.new(0, 10, 0, 100)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Font = Enum.Font.Gotham
    tierLabel.Text = itemData.tier or "BASIC"
    tierLabel.TextSize = 14
    tierLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    tierLabel.Parent = button
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        }):Play()
    end)
    
    return button
end

-- Function to update inventory display
local function updateInventory(inventory, currency)
    if not inventoryUI then
        print("DirectInventoryUI: inventoryUI is nil in updateInventory")
        return
    end
    
    local mainFrame = inventoryUI:FindFirstChild("InventoryFrame")
    if not mainFrame then
        print("DirectInventoryUI: mainFrame is nil in updateInventory")
        return
    end
    
    -- Update currency display
    local currencyLabel = mainFrame.TitleBar:FindFirstChild("Currency")
    if currencyLabel then
        currencyLabel.Text = tostring(currency or 0)
    else
        print("DirectInventoryUI: currencyLabel not found in updateInventory")
    end
    
    -- Update visibility of no items message
    local noItemsLabel = mainFrame:FindFirstChild("NoItemsLabel")
    if noItemsLabel then
        noItemsLabel.Visible = #inventory == 0
        print("DirectInventoryUI: No items label visibility set to", noItemsLabel.Visible)
    else
        print("DirectInventoryUI: noItemsLabel not found in updateInventory")
    end
    
    -- Clear existing items
    local container = mainFrame:FindFirstChild("ItemsContainer")
    if not container then
        print("DirectInventoryUI: container is nil in updateInventory")
        return
    end
    
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add items
    local itemCount = 0
    for _, item in ipairs(inventory) do
        local itemData = {
            name = item.name,
            tier = item.tier or "BASIC"
        }
        
        print("DirectInventoryUI: Adding item to display:", item.name, "Tier:", itemData.tier)
        
        local button = createItemButton(item.name, itemData)
        button.Parent = container
        
        itemCount = itemCount + 1
    end
    
    -- Update canvas size
    local rows = math.ceil(itemCount / ITEMS_PER_ROW)
    container.CanvasSize = UDim2.new(0, 0, 0, rows * (ITEM_SIZE.Y.Offset + ITEM_PADDING) + ITEM_PADDING)
    
    print("DirectInventoryUI: Updated inventory with " .. itemCount .. " items")
end

-- Function to show inventory
local function showInventory()
    if not inventoryUI then
        inventoryUI = createInventoryUI()
    end
    
    local mainFrame = inventoryUI:FindFirstChild("InventoryFrame")
    if not mainFrame then
        print("DirectInventoryUI: mainFrame is nil in showInventory")
        return
    end
    
    -- Get inventory data from server
    local getInventoryFunc = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("GetInventory")
    if getInventoryFunc then
        print("DirectInventoryUI: Calling GetInventory RemoteFunction...")
        
        local success, result = pcall(function()
            return getInventoryFunc:InvokeServer()
        end)
        
        if success then
            print("DirectInventoryUI: GetInventory RemoteFunction result:", result)
            
            -- Check if the result is a table
            if typeof(result) == "table" then
                print("DirectInventoryUI: GetInventory returned data - Items:", 
                    result.inventory and #result.inventory or 0, 
                    "Currency:", result.currency)
                
                currentInventory = result
                updateInventory(result.inventory or {}, result.currency or 0)
            else
                warn("DirectInventoryUI: GetInventory returned non-table result:", typeof(result))
                -- Show empty inventory as fallback
                updateInventory({}, 0)
            end
        else
            warn("DirectInventoryUI: Failed to get inventory data from server:", result)
            -- Show empty inventory as fallback
            updateInventory({}, 0)
        end
    else
        warn("DirectInventoryUI: GetInventory RemoteFunction not found")
        -- Show empty inventory as fallback
        updateInventory({}, 0)
    end
    
    -- Show UI with animation
    mainFrame.Visible = true
    mainFrame.BackgroundTransparency = 1
    
    local showTween = TweenService:Create(mainFrame, TweenInfo.new(ANIMATION_DURATION), {
        BackgroundTransparency = 0
    })
    showTween:Play()
    
    print("DirectInventoryUI: Inventory UI shown")
end

-- Function to hide inventory
local function hideInventory()
    if not inventoryUI then return end
    
    local mainFrame = inventoryUI:FindFirstChild("InventoryFrame")
    if not mainFrame then return end
    
    local hideTween = TweenService:Create(mainFrame, TweenInfo.new(ANIMATION_DURATION), {
        BackgroundTransparency = 1
    })
    
    hideTween.Completed:Connect(function()
        mainFrame.Visible = false
    end)
    
    hideTween:Play()
    
    print("DirectInventoryUI: Inventory UI hidden")
end

-- Connect to AddToInventory event to update UI when items are added
local function setupEventHandling()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("DirectInventoryUI: Remotes folder not found, waiting...")
        task.delay(1, setupEventHandling)
        return
    end
    
    local addToInventoryEvent = remotes:FindFirstChild("AddToInventory")
    if addToInventoryEvent then
        print("DirectInventoryUI: Found AddToInventory event, connecting...")
        
        addToInventoryEvent.OnClientEvent:Connect(function(item)
            print("DirectInventoryUI: Item added to inventory:", item.name)
            
            -- Re-fetch the entire inventory to ensure we have the latest data
            local getInventoryFunc = remotes:FindFirstChild("GetInventory")
            if getInventoryFunc then
                local success, result = pcall(function()
                    return getInventoryFunc:InvokeServer()
                end)
                
                if success and result then
                    print("DirectInventoryUI: Updated inventory after item added:", 
                        result.inventory and #result.inventory or 0, 
                        "items, Currency:", result.currency)
                    
                    currentInventory = result
                    -- Only update if UI is visible
                    if inventoryUI and inventoryUI.InventoryFrame.Visible then
                        updateInventory(result.inventory or {}, result.currency or 0)
                    end
                else
                    warn("DirectInventoryUI: Failed to refresh inventory after item added:", result)
                end
            else
                warn("DirectInventoryUI: GetInventory RemoteFunction not found when trying to refresh")
            end
        end)
        
        print("DirectInventoryUI: Successfully connected to AddToInventory event")
    else
        print("DirectInventoryUI: AddToInventory event not found, will retry in 1 second")
        task.delay(1, setupEventHandling)
    end
end

-- Create inventory button
local function createInventoryButton()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Check if button already exists
    local existingButton = playerGui:FindFirstChild("InventoryButtonUI")
    if existingButton then
        print("DirectInventoryUI: Inventory button already exists")
        return existingButton
    end
    
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "InventoryButtonUI"
    buttonGui.ResetOnSpawn = false
    buttonGui.Parent = playerGui
    
    local button = Instance.new("TextButton")
    button.Name = "InventoryButton"
    button.Size = UDim2.new(0, 120, 0, 40)
    button.Position = UDim2.new(0.5, -60, 1, -60) -- Bottom center
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.Font = Enum.Font.GothamBold
    button.Text = "Inventory"
    button.TextSize = 18
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Parent = buttonGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    -- Add button glow effect on hover
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Transparency = 1
    stroke.Parent = button
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        }):Play()
        
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        }):Play()
        
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 1
        }):Play()
    end)
    
    button.MouseButton1Click:Connect(function()
        showInventory()
    end)
    
    print("DirectInventoryUI: Created inventory button")
    return buttonGui
end

-- Initialize everything
print("DirectInventoryUI: Initializing...")
setupEventHandling()
local buttonUI = createInventoryButton()

-- Create the actual inventory UI (but don't show it yet)
inventoryUI = createInventoryUI()

-- Set up close button handling
local mainFrame = inventoryUI:FindFirstChild("InventoryFrame")
if mainFrame then
    local closeButton = mainFrame.TitleBar.CloseButton
    if closeButton then
        closeButton.MouseButton1Click:Connect(hideInventory)
    else
        warn("DirectInventoryUI: Close button not found")
    end
else
    warn("DirectInventoryUI: Main frame not found")
end

print("DirectInventoryUI: Initialization complete") 