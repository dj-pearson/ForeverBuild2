-- Place Glow Items in World as Catalog Displays
-- Run this script in Roblox Studio to place glow items where players can interact with them

local Workspace = game.Workspace
local ServerStorage = game:GetService("ServerStorage")

print("=== PLACING GLOW ITEMS IN WORLD ===")

-- Find or create a catalog display area
local catalogArea = Workspace:FindFirstChild("CatalogDisplays")
if not catalogArea then
    catalogArea = Instance.new("Folder")
    catalogArea.Name = "CatalogDisplays"
    catalogArea.Parent = Workspace
    print("Created CatalogDisplays folder")
end

-- Starting position for placing items
local startPosition = Vector3.new(50, 5, 50)  -- Adjust this to where you want the catalog
local itemSpacing = 8  -- Distance between items
local itemsPerRow = 5  -- How many items per row

-- Function to recursively find glow items
local function findGlowItems(parent, foundItems)
    foundItems = foundItems or {}
    
    for _, item in ipairs(parent:GetChildren()) do
        if item:IsA("Model") or item:IsA("Part") then
            -- Check if this is a glow item
            local isGlowItem = string.find(string.lower(item.Name), "glow")
            if isGlowItem then
                table.insert(foundItems, item)
            end
        elseif item:IsA("Folder") then
            findGlowItems(item, foundItems)
        end
    end
    
    return foundItems
end

-- Find all glow items from multiple locations
local allGlowItems = {}

-- Check Workspace.Items
local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    print("Scanning Workspace.Items for glow items...")
    findGlowItems(workspaceItems, allGlowItems)
end

-- Check ServerStorage.Items
local serverStorageItems = ServerStorage:FindFirstChild("Items")
if serverStorageItems then
    print("Scanning ServerStorage.Items for glow items...")
    findGlowItems(serverStorageItems, allGlowItems)
end

print("Found", #allGlowItems, "glow items to place")

-- Place each glow item in the world
local placedCount = 0
for i, originalItem in ipairs(allGlowItems) do
    -- Calculate position
    local row = math.floor((i - 1) / itemsPerRow)
    local col = (i - 1) % itemsPerRow
    local position = startPosition + Vector3.new(col * itemSpacing, 0, row * itemSpacing)
    
    -- Clone the item for display
    local displayItem = originalItem:Clone()
    displayItem.Name = originalItem.Name .. "_Display"
    
    -- Position the item
    if displayItem:IsA("Model") then
        if displayItem.PrimaryPart then
            displayItem:SetPrimaryPartCFrame(CFrame.new(position))
        else
            local firstPart = displayItem:FindFirstChildOfClass("Part")
            if firstPart then
                displayItem.PrimaryPart = firstPart
                displayItem:SetPrimaryPartCFrame(CFrame.new(position))
            end
        end
    elseif displayItem:IsA("Part") then
        displayItem.CFrame = CFrame.new(position)
    end
    
    -- Ensure all interaction attributes are set
    displayItem:SetAttribute("Interactable", true)
    displayItem:SetAttribute("ItemID", originalItem.Name)
    displayItem:SetAttribute("Purchasable", true)
    displayItem:SetAttribute("Price", 75)
    displayItem:SetAttribute("CurrencyType", "Coins")
    displayItem:SetAttribute("Description", "A glowing " .. originalItem.Name:gsub("_", " "):lower() .. " that illuminates your world.")
    displayItem:SetAttribute("priceIngame", 75)
    displayItem:SetAttribute("priceRobux", 5)
    displayItem:SetAttribute("Type", "catalog")
    displayItem:SetAttribute("Tier", "Glow")
    
    -- Add a floating display platform
    local platform = Instance.new("Part")
    platform.Name = "DisplayPlatform"
    platform.Size = Vector3.new(6, 0.5, 6)
    platform.Position = position - Vector3.new(0, 2, 0)
    platform.Material = Enum.Material.Neon
    platform.Color = Color3.fromRGB(100, 100, 255)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Shape = Enum.PartType.Cylinder
    platform.Parent = catalogArea
    
    -- Add platform corner
    local platformCorner = Instance.new("SpecialMesh")
    platformCorner.MeshType = Enum.MeshType.Cylinder
    platformCorner.Parent = platform
    
    -- Add a label above the item
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 4, 0)
    billboardGui.Parent = displayItem
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = billboardGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = originalItem.Name:gsub("_", " ") .. "\n75 Coins"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = frame
    
    -- Make the item glow/stand out
    if displayItem:IsA("Model") then
        for _, part in ipairs(displayItem:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Add a highlight
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(255, 255, 100)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
                highlight.FillTransparency = 0.8
                highlight.OutlineTransparency = 0.5
                highlight.Parent = part
            end
        end
    elseif displayItem:IsA("BasePart") then
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(255, 255, 100)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        highlight.FillTransparency = 0.8
        highlight.OutlineTransparency = 0.5
        highlight.Parent = displayItem
    end
    
    -- Parent to catalog area
    displayItem.Parent = catalogArea
    
    placedCount = placedCount + 1
    print("Placed", displayItem.Name, "at position", position)
end

print("\n=== PLACEMENT COMPLETE ===")
print("Placed", placedCount, "glow items in the catalog display area")
print("Items are positioned starting at", startPosition)
print("Players can now walk up to these items and see the purchase UI")

-- Create a spawn point near the catalog
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(4, 1, 4)
spawnLocation.Position = startPosition - Vector3.new(0, 0, 15)
spawnLocation.BrickColor = BrickColor.new("Bright blue")
spawnLocation.Material = Enum.Material.Neon
spawnLocation.Anchored = true
spawnLocation.CanCollide = true
spawnLocation.Parent = catalogArea

local spawnLabel = Instance.new("SurfaceGui")
spawnLabel.Face = Enum.NormalId.Top
spawnLabel.Parent = spawnLocation

local spawnText = Instance.new("TextLabel")
spawnText.Size = UDim2.new(1, 0, 1, 0)
spawnText.BackgroundTransparency = 1
spawnText.Text = "CATALOG AREA"
spawnText.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnText.TextSize = 48
spawnText.Font = Enum.Font.GothamBold
spawnText.TextScaled = true
spawnText.Parent = spawnLabel

print("✓ Added spawn point near catalog area")
print("✓ Glow items should now show purchase UI when approached!") 