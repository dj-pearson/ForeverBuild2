-- InventoryUI.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Constants)

local InventoryUI = {}

-- UI Constants are now in Constants.lua

-- Create the inventory UI
local function createInventory(parent)
    local inventory = Instance.new("Frame")
    inventory.Name = "InventoryUI"
    inventory.Size = UDim2.new(0, 600, 0, 400) -- Retaining size for now, can be moved to Constants
    inventory.Position = UDim2.new(0.5, -300, 0.5, -200) -- Retaining position for now, can be moved to Constants
    inventory.BackgroundColor3 = Constants.UI.Colors.Background -- Updated
    inventory.BorderSizePixel = 0
    inventory.Visible = false
    inventory.Parent = parent
    
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
    shadow.ImageColor3 = Constants.UI.Colors.Text -- Updated (or a darker variant)
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
    titleBar.BackgroundColor3 = Constants.UI.Colors.Text -- Updated
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
    title.Font = Constants.UI.Fonts.Title.Font -- Updated
    title.Text = "Inventory"
    title.TextSize = Constants.UI.Fonts.Title.Size -- Updated
    title.TextColor3 = Constants.UI.Colors.Background -- Updated
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local currency = Instance.new("TextLabel")
    currency.Name = "Currency"
    currency.Size = UDim2.new(0, 100, 1, 0)
    currency.Position = UDim2.new(1, -120, 0, 0)
    currency.BackgroundTransparency = 1
    currency.Font = Constants.UI.Fonts.Default.Font -- Updated
    currency.Text = "0"
    currency.TextSize = Constants.UI.Fonts.Default.Size -- Updated
    currency.TextColor3 = Constants.UI.Colors.Accent -- Updated
    currency.TextXAlignment = Enum.TextXAlignment.Right
    currency.Parent = titleBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Constants.UI.Colors.Error -- Updated
    closeButton.Font = Constants.UI.Fonts.Button.Font -- Updated
    closeButton.Text = "X"
    closeButton.TextSize = Constants.UI.Fonts.Button.Size -- Updated
    closeButton.TextColor3 = Constants.UI.Colors.Background -- Updated
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
    gridLayout.CellSize = UDim2.new(0, 100, 0, 120) -- Retaining size for now, can be moved to Constants
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10) -- Retaining padding for now, can be moved to Constants
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = itemsContainer
    
    return inventory
end

-- Create an item button
local function createItemButton(itemName, itemData, quantity)
    local button = Instance.new("TextButton")
    button.Name = itemName
    button.Size = UDim2.new(0, 100, 0, 120) -- Retaining size for now, can be moved to Constants
    button.BackgroundColor3 = Constants.UI.Colors.Text -- Updated (or a lighter shade from Constants)
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
    icon.Image = itemData.icon or "rbxassetid://0" -- Replace with actual icon
    icon.Parent = button
    
    -- Item name
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -20, 0, 20)
    name.Position = UDim2.new(0, 10, 0, 80)
    name.BackgroundTransparency = 1
    name.Font = Constants.UI.Fonts.Default.Font -- Updated
    name.Text = itemName
    name.TextSize = 14 -- Consider adjusting or making a constant
    name.TextColor3 = Constants.UI.Colors.Background -- Updated
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Parent = button
    
    -- Quantity
    local quantityLabel = Instance.new("TextLabel")
    quantityLabel.Name = "Quantity"
    quantityLabel.Size = UDim2.new(1, -20, 0, 20)
    quantityLabel.Position = UDim2.new(0, 10, 0, 100)
    quantityLabel.BackgroundTransparency = 1
    quantityLabel.Font = Constants.UI.Fonts.Default.Font -- Updated
    quantityLabel.Text = "x" .. quantity
    quantityLabel.TextSize = 14 -- Consider adjusting or making a constant
    quantityLabel.TextColor3 = Constants.UI.Colors.Secondary -- Updated
    quantityLabel.Parent = button
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), { -- Updated
            BackgroundColor3 = Constants.UI.Colors.Primary -- Example hover color, adjust as needed
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(Constants.UI.BUTTON_HOVER_DURATION), { -- Updated
            BackgroundColor3 = Constants.UI.Colors.Text -- Back to original item button color
        }):Play()
    end)
    
    return button
end

-- Initialize the inventory UI
function InventoryUI.Initialize(parent)
    local inventory = createInventory(parent)
    
    -- Set up close button
    inventory.TitleBar.CloseButton.MouseButton1Click:Connect(function()
        InventoryUI.Hide()
    end)
    
    -- Store inventory reference
    InventoryUI._inventory = inventory
end

-- Update inventory display
function InventoryUI.UpdateInventory(inventoryData, currencyAmount) -- Renamed for clarity
    local ui = InventoryUI._inventory
    if not ui then return end
    
    -- Update currency
    ui.TitleBar.Currency.Text = tostring(currencyAmount or 0)
    
    -- Clear existing items
    local container = ui.ItemsContainer
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add items
    local itemCount = 0
    for itemName, quantity in pairs(inventoryData) do
        if quantity > 0 then
            local itemData = Constants.ITEMS[itemName]
            if itemData then
                local button = createItemButton(itemName, itemData, quantity)
                button.Parent = container
                
                -- Set up click handler
                button.MouseButton1Click:Connect(function()
                    if InventoryUI.OnItemSelected then
                        InventoryUI.OnItemSelected(itemName)
                    end
                end)
                
                itemCount = itemCount + 1
            end
        end
    end
    
    -- Update canvas size
    -- Consider moving ITEM_SIZE and ITEM_PADDING to Constants.UI if they are to be standardized
    local itemSizeY = 120 -- Placeholder, ideally from Constants.UI.Item.Size.Y
    local itemPadding = 10 -- Placeholder, ideally from Constants.UI.Item.Padding
    local itemsPerRow = 5 -- Placeholder, ideally from Constants.UI.Inventory.ItemsPerRow
    local rows = math.ceil(itemCount / itemsPerRow)
    container.CanvasSize = UDim2.new(0, 0, 0, rows * (itemSizeY + itemPadding) + itemPadding)
end

-- Show the inventory
function InventoryUI.Show()
    local inventory = InventoryUI._inventory
    if not inventory then return end
    
    inventory.Visible = true
    inventory.BackgroundTransparency = 1 -- Start fully transparent for fade-in
    
    local showTween = TweenService:Create(inventory, TweenInfo.new(Constants.UI.DIALOG_ANIMATION_DURATION), { -- Updated
        BackgroundTransparency = 0 -- Fade to opaque (original visibility was 0)
    })
    showTween:Play()
end

-- Hide the inventory
function InventoryUI.Hide()
    local inventory = InventoryUI._inventory
    if not inventory then return end
    
    local hideTween = TweenService:Create(inventory, TweenInfo.new(Constants.UI.DIALOG_ANIMATION_DURATION), { -- Updated
        BackgroundTransparency = 1
    })
    
    hideTween.Completed:Connect(function()
        inventory.Visible = false
    end)
    
    hideTween:Play()
end

return InventoryUI
