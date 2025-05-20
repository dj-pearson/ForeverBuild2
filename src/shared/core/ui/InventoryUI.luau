-- InventoryUI.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Constants = require(script.Parent.Parent.Constants)

local InventoryUI = {}
InventoryUI._isVisible = false
InventoryUI._buttonConnection = nil -- Store the button connection

-- UI Constants
local INVENTORY_SIZE = UDim2.new(0, 600, 0, 400)
local INVENTORY_POSITION = UDim2.new(0.5, -300, 0.5, -200)
local ANIMATION_DURATION = 0.3
local ITEM_SIZE = UDim2.new(0, 100, 0, 120)
local ITEMS_PER_ROW = 5
local ITEM_PADDING = 10

-- Create the inventory UI
local function createInventory()
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
    if not inventoryScreenGui then
        inventoryScreenGui = Instance.new("ScreenGui")
        inventoryScreenGui.Name = "InventoryUI"
        inventoryScreenGui.ResetOnSpawn = false
        inventoryScreenGui.Parent = playerGui
    end
    
    -- First check if the main frame already exists
    local existingInventory = inventoryScreenGui:FindFirstChild("InventoryFrame")
    if existingInventory then
        print("Found existing inventory frame, removing it")
        existingInventory:Destroy()
    end
    
    local inventory = Instance.new("Frame")
    inventory.Name = "InventoryFrame" -- Changed from "InventoryUI" to avoid confusion
    inventory.Size = UDim2.new(0, 600, 0, 400)
    inventory.Position = UDim2.new(0.5, -300, 0.5, -200) -- Center of screen
    inventory.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    inventory.BorderSizePixel = 0
    inventory.Visible = false
    inventory.Parent = inventoryScreenGui
    
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
    
    -- Items container
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
    
    -- No items message
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
    noItemsLabel.Visible = false
    noItemsLabel.Parent = inventory
    
    return inventory
end

-- Create an item button
local function createItemButton(itemName, itemData, quantity)
    quantity = quantity or 1
    local button = Instance.new("TextButton")
    button.Name = itemName
    button.Size = ITEM_SIZE
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.AutoButtonColor = false
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Item icon (placeholder)
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -20, 0, 60)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundTransparency = 1
    -- Use icon from Constants.ITEMS if available
    local iconId = (Constants.ITEMS[itemName] and Constants.ITEMS[itemName].icon) or itemData.icon or "rbxassetid://6034973115"
    icon.Image = iconId
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
    
    -- Count badge
    if quantity > 1 then
        -- Quantity background
        local countBg = Instance.new("Frame")
        countBg.Name = "CountBadge"
        countBg.Size = UDim2.new(0, 36, 0, 24)
        countBg.Position = UDim2.new(1, -40, 0, 5)
        countBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        countBg.BorderSizePixel = 0
        countBg.ZIndex = 2
        countBg.Parent = button
        
        local countCorner = Instance.new("UICorner")
        countCorner.CornerRadius = UDim.new(0, 12)
        countCorner.Parent = countBg
        
        -- Quantity text
        local quantityLabel = Instance.new("TextLabel")
        quantityLabel.Name = "Quantity"
        quantityLabel.Size = UDim2.new(1, 0, 1, 0)
        quantityLabel.BackgroundTransparency = 1
        quantityLabel.Font = Enum.Font.GothamBold
        quantityLabel.Text = tostring(quantity)
        quantityLabel.TextSize = 14
        quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        quantityLabel.ZIndex = 3
        quantityLabel.Parent = countBg
    end
    
    -- Item description/count
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -20, 0, 20)
    description.Position = UDim2.new(0, 10, 0, 100)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.Gotham
    if quantity > 1 then
        description.Text = "Quantity: " .. quantity
    else
        description.Text = itemData.description or ""
    end
    description.TextSize = 12
    description.TextColor3 = Color3.fromRGB(200, 200, 200)
    description.TextTruncate = Enum.TextTruncate.AtEnd
    description.Parent = button
    
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

-- Initialize the inventory UI
function InventoryUI.Initialize(parent)
    print("InventoryUI.Initialize called")
    local inventory = createInventory()
    
    -- Verify we can locate this inventory frame later
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
    local inventoryFrame = inventoryScreenGui and inventoryScreenGui:FindFirstChild("InventoryFrame")
    
    if not inventoryFrame then
        warn("InventoryUI.Initialize: Failed to verify inventory frame was created properly")
    else
        print("InventoryUI.Initialize: Successfully verified inventory frame exists")
    end
    
    -- Set up close button
    inventory.TitleBar.CloseButton.MouseButton1Click:Connect(function()
        InventoryUI.Hide()
    end)
    
    -- Store inventory reference
    InventoryUI._inventory = inventory
    print("InventoryUI.Initialize: Stored inventory reference")
    
    -- Create or update inventory button
    InventoryUI.CreateButton()
    
    -- Connect to AddToInventory event
    InventoryUI.SetupEventHandling()
    
    -- Register this module with SharedModule
    local success, sharedModule = pcall(function()
        return require(ReplicatedStorage:WaitForChild("shared", 5))
    end)
    
    if success and sharedModule then
        -- Add this module to the SharedModule directly
        sharedModule.InventoryUI = InventoryUI
        print("InventoryUI: Successfully registered with SharedModule")
    end
    
    print("InventoryUI.Initialize completed")
    return inventory
end

-- Create or update inventory button
function InventoryUI.CreateButton()
    local player = Players.LocalPlayer
    if not player then return end
    
    local playerGui = player:WaitForChild("PlayerGui")
    local existingButton = playerGui:FindFirstChild("InventoryButtonUI")
    
    -- Don't create a new button if one already exists
    if existingButton then 
        -- Just update the click handler
        local button = existingButton:FindFirstChild("InventoryButton")
        if button then
            -- Disconnect previous connection if it exists
            if InventoryUI._buttonConnection then
                InventoryUI._buttonConnection:Disconnect()
                InventoryUI._buttonConnection = nil
            end
            
            -- Create new connection
            InventoryUI._buttonConnection = button.MouseButton1Click:Connect(function()
                InventoryUI.Toggle()
            end)
        end
        return
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
    
    -- Store the connection
    InventoryUI._buttonConnection = button.MouseButton1Click:Connect(function()
        InventoryUI.Toggle()
    end)
    
    print("InventoryUI: Created inventory button")
    return buttonGui
end

-- Connect to AddToInventory event
function InventoryUI.SetupEventHandling()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("InventoryUI: Remotes folder not found, waiting...")
        task.delay(1, InventoryUI.SetupEventHandling)
        return
    end
    
    local addToInventoryEvent = remotes:FindFirstChild("AddToInventory")
    if addToInventoryEvent then
        print("InventoryUI: Found AddToInventory event, connecting...")
        
        addToInventoryEvent.OnClientEvent:Connect(function(item)
            print("InventoryUI: Item added to inventory:", item.name)
            
            -- Re-fetch the entire inventory to ensure we have the latest data
            InventoryUI.RefreshInventory()
        end)
        
        print("InventoryUI: Successfully connected to AddToInventory event")
    else
        print("InventoryUI: AddToInventory event not found, will retry in 1 second")
        task.delay(1, InventoryUI.SetupEventHandling)
    end
end

-- Refresh inventory data from server
function InventoryUI.RefreshInventory()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    
    local getInventoryFunc = remotes:FindFirstChild("GetInventory")
    if getInventoryFunc then
        local success, result = pcall(function()
            return getInventoryFunc:InvokeServer()
        end)
        
        if success and result then
            local itemCount = 0
            if result.inventory then
                if typeof(result.inventory) == "table" then
                    -- Count items in either array or dictionary format
                    if #result.inventory > 0 then
                        itemCount = #result.inventory
                    else
                        for _, quantity in pairs(result.inventory) do
                            if quantity > 0 then
                                itemCount = itemCount + 1
                            end
                        end
                    end
                end
            end
            
            print("InventoryUI: Retrieved inventory data:", 
                itemCount, "items, Currency:", result.currency)
            
            InventoryUI.UpdateInventory(result.inventory or {}, result.currency or 0)
        else
            warn("InventoryUI: Failed to get inventory data:", result)
        end
    else
        warn("InventoryUI: GetInventory RemoteFunction not found")
    end
end

-- Update inventory display
function InventoryUI.UpdateInventory(inventory, currency)
    local ui = InventoryUI._inventory
    if not ui then
        warn("InventoryUI: UI not found. Call Initialize first.")
        return
    end
    
    -- Update currency display
    local currencyLabel = ui.TitleBar:FindFirstChild("Currency")
    if currencyLabel then
        currencyLabel.Text = tostring(currency or 0)
    end
    
    -- Get the container
    local container = ui:FindFirstChild("ItemsContainer")
    if not container then
        warn("InventoryUI: ItemsContainer not found")
        return
    end
    
    -- Clear existing items
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("UIGridLayout") then
            child:Destroy()
        end
    end
    
    -- Create grid layout
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = ITEM_SIZE
    gridLayout.CellPadding = UDim2.new(0, ITEM_PADDING, 0, ITEM_PADDING)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = container
    
    -- Constants for UI layout
    local itemCount = 0
    
    -- Add items to container
    if inventory then
        if typeof(inventory) == "table" then
            for _, item in ipairs(inventory) do
                -- Ensure the item has an id or name
                local itemName = item.id or item.name
                if itemName then
                    -- Get item quantity (count), fallback to quantity, default to 1 if not specified
                    local quantity = item.count or item.quantity or 1
                    -- Skip if quantity is 0
                    if quantity <= 0 then
                        continue
                    end
                    -- Clean up display name
                    local displayName = itemName
                    displayName = displayName:gsub("_", " ")
                    displayName = displayName:gsub("Cube", "")
                    displayName = displayName:gsub("  ", " ")
                    displayName = displayName:gsub("^%s+", "")
                    displayName = displayName:gsub("%s+$", "")
                    -- Capitalize first letter of each word
                    displayName = displayName:gsub("(%a)([%w_']*)", function(first, rest)
                        return first:upper() .. rest:lower()
                    end)
                    -- Get item info (icon, tier, etc.)
                    local icon = (Constants.ITEMS[itemName] and Constants.ITEMS[itemName].icon) or item.icon or nil
                    local itemInfo = {
                        icon = icon,
                        tier = item.tier or "COMMON"
                    }
                    -- Create the button and add it to the container
                    local button = createItemButton(displayName, itemInfo, quantity)
                    button.Parent = container
                    -- Store the original itemName for use in callbacks
                    button:SetAttribute("originalItemName", itemName)
                    -- Set up click handler
                    button.MouseButton1Click:Connect(function()
                        if InventoryUI.OnItemSelected then
                            -- Pass the original item ID and the count to the callback
                            local itemData = {
                                id = itemName,
                                name = itemName,
                                displayName = displayName,
                                count = quantity
                            }
                            -- Hide the inventory UI after selecting an item
                            InventoryUI.Hide()
                            -- Call the callback with a slight delay to ensure UI is hidden first
                            task.delay(0.1, function()
                                InventoryUI.OnItemSelected(itemName, itemData)
                            end)
                        end
                    end)
                    itemCount = itemCount + 1
                end
            end
        end
    end
    
    -- Show/hide no items message
    local noItemsLabel = ui:FindFirstChild("NoItemsLabel")
    if noItemsLabel then
        noItemsLabel.Visible = (itemCount == 0)
    end
    
    -- Update canvas size
    local rows = math.ceil(itemCount / ITEMS_PER_ROW)
    container.CanvasSize = UDim2.new(0, 0, 0, rows * (ITEM_SIZE.Y.Offset + ITEM_PADDING) + ITEM_PADDING)
    
    print("InventoryUI: Updated inventory with", itemCount, "items")
end

-- Toggle inventory visibility
function InventoryUI.Toggle()
    print("InventoryUI: Toggle called")
    
    -- First check if the UI actually exists in PlayerGui
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui") 
    local inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
    local inventoryFrame = inventoryScreenGui and inventoryScreenGui:FindFirstChild("InventoryFrame")
    
    -- If the inventory doesn't exist at all, create it
    if not inventoryFrame then
        print("InventoryUI: Toggle - inventory frame not found, recreating it")
        InventoryUI.Initialize()
        InventoryUI._isVisible = false -- Ensure we're in the right state
        
        -- Get fresh references after initialization
        inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
        inventoryFrame = inventoryScreenGui and inventoryScreenGui:FindFirstChild("InventoryFrame")
        
        if not inventoryFrame then
            warn("InventoryUI: Failed to create inventory frame")
            return
        end
    end
    
    -- Check actual current state (don't rely on tracked state which might be wrong)
    local actuallyVisible = inventoryFrame.Visible
    print("InventoryUI: Toggle - current visibility state:", actuallyVisible)
    
    -- Update our stored state to match reality
    InventoryUI._isVisible = actuallyVisible
    
    -- Now toggle the state
    if actuallyVisible then
        print("InventoryUI: Toggle - hiding inventory")
        InventoryUI.Hide()
    else
        print("InventoryUI: Toggle - showing inventory")
        -- Force refresh before showing
        InventoryUI.RefreshInventory()
        InventoryUI.Show()
    end
end

-- Show the inventory
function InventoryUI.Show()
    print("InventoryUI: Show function called")
    
    -- Ensure player GUI exists
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Check if the UI already exists
    local inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
    local inventoryFrame = inventoryScreenGui and inventoryScreenGui:FindFirstChild("InventoryFrame")
    
    -- If either the ScreenGui or frame doesn't exist, initialize everything
    if not inventoryScreenGui or not inventoryFrame then
        print("InventoryUI: Inventory UI components missing, creating them")
        InventoryUI.Initialize()
        
        -- Get updated references
        inventoryScreenGui = playerGui:FindFirstChild("InventoryUI") 
        inventoryFrame = inventoryScreenGui and inventoryScreenGui:FindFirstChild("InventoryFrame")
        
        if not inventoryFrame then
            warn("InventoryUI: Failed to create inventory UI")
            return
        end
    end
    
    -- Make sure we also have the reference in our module
    InventoryUI._inventory = inventoryFrame
    
    -- Refresh inventory data before showing
    print("InventoryUI: Refreshing inventory data")
    InventoryUI.RefreshInventory()
    
    -- Show the UI with animation
    print("InventoryUI: Making inventory visible")
    inventoryFrame.Visible = true
    inventoryFrame.BackgroundTransparency = 1
    
    local showTween = TweenService:Create(inventoryFrame, TweenInfo.new(ANIMATION_DURATION), {
        BackgroundTransparency = 0
    })
    showTween:Play()
    
    -- Update visibility state
    InventoryUI._isVisible = true
    print("InventoryUI: Inventory is now visible")
end

-- Hide the inventory
function InventoryUI.Hide()
    print("InventoryUI: Hide function called")
    local inventory = InventoryUI._inventory
    if not inventory then 
        print("InventoryUI: No inventory reference to hide")
        InventoryUI._isVisible = false
        return 
    end
    
    -- Find the actual frame in the player's GUI
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
    
    if inventoryScreenGui then
        local inventoryFrame = inventoryScreenGui:FindFirstChild("InventoryFrame")
        if inventoryFrame then
            print("InventoryUI: Found frame to hide")
            local hideTween = TweenService:Create(inventoryFrame, TweenInfo.new(ANIMATION_DURATION), {
                BackgroundTransparency = 1
            })
            
            hideTween.Completed:Connect(function()
                inventoryFrame.Visible = false
                print("InventoryUI: Frame hidden after tween")
            end)
            
            hideTween:Play()
        else
            print("InventoryUI: Frame not found, but updating visibility state")
        end
    else
        print("InventoryUI: ScreenGui not found, but updating visibility state")
    end
    
    InventoryUI._isVisible = false
    print("InventoryUI: Hide completed")
end

return InventoryUI 