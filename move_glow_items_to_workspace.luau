-- Move Glow Items to Workspace for Automatic Purchase Dialogs
-- Run this script in Roblox Studio to move glow items from ServerStorage.Items to Workspace.Items
-- This will make them behave like Water_Cube with automatic purchase dialogs (no [E] Interact required)

local Workspace = game.Workspace
local ServerStorage = game:GetService("ServerStorage")

print("=== MOVING GLOW ITEMS TO WORKSPACE FOR AUTOMATIC PURCHASE DIALOGS ===")

-- Find or create Workspace.Items folder
local workspaceItems = Workspace:FindFirstChild("Items")
if not workspaceItems then
    workspaceItems = Instance.new("Folder")
    workspaceItems.Name = "Items"
    workspaceItems.Parent = Workspace
    print("Created Workspace.Items folder")
end

-- Function to recursively find glow items
local function findGlowItems(parent, foundItems, path)
    foundItems = foundItems or {}
    path = path or ""
    
    for _, item in ipairs(parent:GetChildren()) do
        if item:IsA("Model") or item:IsA("Part") then
            -- Check if this is a glow item
            local isGlowItem = string.find(string.lower(item.Name), "glow")
            if isGlowItem then
                table.insert(foundItems, {item = item, path = path})
            end
        elseif item:IsA("Folder") then
            local newPath = path == "" and item.Name or (path .. "/" .. item.Name)
            findGlowItems(item, foundItems, newPath)
        end
    end
    
    return foundItems
end

-- Function to create folder structure in workspace
local function createFolderStructure(parent, path)
    if path == "" then return parent end
    
    local folders = string.split(path, "/")
    local current = parent
    
    for _, folderName in ipairs(folders) do
        local folder = current:FindFirstChild(folderName)
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = folderName
            folder.Parent = current
        end
        current = folder
    end
    
    return current
end

-- Find all glow items in ServerStorage.Items
local serverStorageItems = ServerStorage:FindFirstChild("Items")
if not serverStorageItems then
    print("No ServerStorage.Items folder found")
    return
end

local glowItems = findGlowItems(serverStorageItems)
print("Found", #glowItems, "glow items in ServerStorage.Items")

-- Move each glow item to Workspace.Items
local movedCount = 0
for _, itemData in ipairs(glowItems) do
    local item = itemData.item
    local path = itemData.path
    
    -- Create the same folder structure in Workspace.Items
    local targetFolder = createFolderStructure(workspaceItems, path)
    
    -- Clone the item to workspace (don't move, keep original for backup)
    local clonedItem = item:Clone()
    clonedItem.Parent = targetFolder
    
    -- Ensure all purchase attributes are set
    clonedItem:SetAttribute("Interactable", true)
    clonedItem:SetAttribute("ItemID", item.Name)
    clonedItem:SetAttribute("Purchasable", true)
    clonedItem:SetAttribute("Price", 75)
    clonedItem:SetAttribute("CurrencyType", "Coins")
    clonedItem:SetAttribute("Description", "A glowing " .. item.Name:gsub("_", " "):lower() .. " that illuminates your world.")
    clonedItem:SetAttribute("priceIngame", 75)
    clonedItem:SetAttribute("priceRobux", 5)
    clonedItem:SetAttribute("Type", "catalog")
    clonedItem:SetAttribute("Tier", "Glow")
    
    movedCount = movedCount + 1
    print("Moved", item.Name, "to", path == "" and "Workspace.Items" or ("Workspace.Items/" .. path))
end

print("\n=== MOVE COMPLETE ===")
print("Moved", movedCount, "glow items to Workspace.Items")
print("Glow items should now show automatic purchase dialogs like Water_Cube!")
print("Players can walk up to them and see the purchase dialog without pressing E")

-- Create a helpful sign
local sign = Instance.new("Part")
sign.Name = "GlowItemsSign"
sign.Size = Vector3.new(8, 4, 0.5)
sign.Position = Vector3.new(0, 10, -20)
sign.Material = Enum.Material.Neon
sign.Color = Color3.fromRGB(255, 255, 100)
sign.Anchored = true
sign.CanCollide = false
sign.Parent = workspaceItems

local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.Parent = sign

local signText = Instance.new("TextLabel")
signText.Size = UDim2.new(1, 0, 1, 0)
signText.BackgroundTransparency = 1
signText.Text = "GLOW ITEMS\nAUTO-PURCHASE ENABLED\nWalk close to items!"
signText.TextColor3 = Color3.fromRGB(0, 0, 0)
signText.TextSize = 24
signText.Font = Enum.Font.GothamBold
signText.TextScaled = true
signText.Parent = signGui

print("✓ Added informational sign")
print("✓ Run the game and test - glow items should now show purchase dialogs automatically!") 