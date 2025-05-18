-- InventoryItemHandler.client.luau
-- Handles recalling items from inventory and connecting with the placement system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)

print("InventoryItemHandler: Starting initialization")

-- Load required modules
local function initialize()
    local success, sharedModule = pcall(function()
        return require(shared)
    end)
    
    if not success then
        warn("InventoryItemHandler: Failed to load SharedModule:", sharedModule)
        return false
    end
    
    print("InventoryItemHandler: SharedModule loaded")
    
    -- Wait for InventoryUI to be available
    if not sharedModule.InventoryUI then
        print("InventoryItemHandler: Waiting for InventoryUI to be available")
        for i = 1, 10 do
            if sharedModule.InventoryUI then break end
            task.wait(0.5)
        end
    end
    
    if not sharedModule.InventoryUI then
        warn("InventoryItemHandler: InventoryUI not found in SharedModule after waiting")
        return false
    end
    
    print("InventoryItemHandler: InventoryUI module found")
    
    -- Create PlacementManager if needed
    if not sharedModule.PlacementManager then
        print("InventoryItemHandler: PlacementManager not found in SharedModule, creating it")
        
        -- Try to require PlacementManager
        local placement
        local placementModule = shared:FindFirstChild("core"):FindFirstChild("placement"):FindFirstChild("PlacementManager")
        
        if placementModule then
            local success, result = pcall(function()
                return require(placementModule)
            end)
            
            if success then
                placement = result
                print("InventoryItemHandler: Successfully required PlacementManager module")
            else
                warn("InventoryItemHandler: Failed to require PlacementManager:", result)
                return false
            end
        else
            warn("InventoryItemHandler: PlacementManager module not found")
            return false
        end
        
        -- Create and initialize PlacementManager
        if placement then
            sharedModule.PlacementManager = placement.new(sharedModule)
            sharedModule.PlacementManager:Initialize()
            print("InventoryItemHandler: Created and initialized PlacementManager")
        else
            warn("InventoryItemHandler: Failed to create PlacementManager")
            return false
        end
    end
    
    print("InventoryItemHandler: PlacementManager is ready")
    
    return true, sharedModule
end

-- Setup UI for recalling items from the world back to inventory
local function setupWorldItemRecall(sharedModule)
    local PlacementManager = sharedModule.PlacementManager
    
    -- Create the recall button (for placed items)
    local gui = Instance.new("ScreenGui")
    gui.Name = "WorldItemRecallUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    
    local button = Instance.new("TextButton")
    button.Name = "RecallButton"
    button.Size = UDim2.new(0, 120, 0, 40)
    button.Position = UDim2.new(0.5, -60, 1, -110) -- Above inventory button
    button.BackgroundColor3 = Color3.fromRGB(70, 70, 120)
    button.Font = Enum.Font.GothamBold
    button.Text = "Recall Item"
    button.TextSize = 18
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Visible = false -- Start hidden
    button.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    -- Track what item we're looking at
    local hoveredItem = nil
    
    -- Mouse update function
    local function updateHoveredItem()
        local mouse = player:GetMouse()
        
        -- Cast ray from mouse
        local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Include
        
        -- Only check placed items
        local itemsFolder = workspace:FindFirstChild("PlacedItems")
        if not itemsFolder then
            hoveredItem = nil
            button.Visible = false
            return
        end
        
        raycastParams.FilterDescendantsInstances = {itemsFolder}
        
        local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)
        if raycastResult then
            -- Check if we hit a placed item
            local item = raycastResult.Instance
            while item and item.Parent ~= itemsFolder do
                item = item.Parent
            end
            
            if item then
                -- Check if the player owns this item
                local ownerId = item:GetAttribute("owner")
                if ownerId == player.UserId then
                    hoveredItem = item
                    button.Visible = true
                    return
                end
            end
        end
        
        -- No valid item found
        hoveredItem = nil
        button.Visible = false
    end
    
    -- Connect mouse movement
    game:GetService("RunService").RenderStepped:Connect(updateHoveredItem)
    
    -- Connect recall button click
    button.MouseButton1Click:Connect(function()
        if hoveredItem then
            print("InventoryItemHandler: Recalling world item:", hoveredItem.Name)
            
            -- Fire server to recall the item
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                local recallItemRemote = remotes:FindFirstChild("RecallItem")
                if recallItemRemote then
                    recallItemRemote:FireServer(hoveredItem.Name)
                    
                    -- Hide the button
                    button.Visible = false
                    hoveredItem = nil
                else
                    warn("InventoryItemHandler: RecallItem remote not found")
                end
            else
                warn("InventoryItemHandler: Remotes folder not found")
            end
        end
    end)
    
    print("InventoryItemHandler: Setup world item recall UI")
end

-- Connect inventory item click to placement system
local function setupInventoryItemInteraction(sharedModule)
    local InventoryUI = sharedModule.InventoryUI
    local PlacementManager = sharedModule.PlacementManager
    
    -- Set up the OnItemSelected callback in InventoryUI
    InventoryUI.OnItemSelected = function(itemName)
        print("InventoryItemHandler: Item selected from inventory:", itemName)
        
        -- First ensure player can move if they got stuck
        local player = Players.LocalPlayer
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid.WalkSpeed = 16
            end
        end
        
        -- Create a simple recall dialog
        local dialog = Instance.new("ScreenGui")
        dialog.Name = "RecallDialog"
        dialog.ResetOnSpawn = false
        dialog.Parent = player:WaitForChild("PlayerGui")
        
        -- Background frame
        local frame = Instance.new("Frame")
        frame.Name = "Container"
        frame.Size = UDim2.new(0, 300, 0, 200)
        frame.Position = UDim2.new(0.5, -150, 0.5, -100)
        frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        frame.BorderSizePixel = 0
        frame.Parent = dialog
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        -- Title
        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, 0, 0, 40)
        title.Position = UDim2.new(0, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "Recall Item"
        title.TextSize = 24
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Parent = frame
        
        -- Item info
        local itemInfo = Instance.new("TextLabel")
        itemInfo.Name = "ItemInfo"
        itemInfo.Size = UDim2.new(1, -40, 0, 60)
        itemInfo.Position = UDim2.new(0, 20, 0, 50)
        itemInfo.BackgroundTransparency = 1
        itemInfo.Font = Enum.Font.Gotham
        itemInfo.Text = "Selected: " .. itemName
        itemInfo.TextSize = 18
        itemInfo.TextColor3 = Color3.new(1, 1, 1)
        itemInfo.TextWrapped = true
        itemInfo.Parent = frame
        
        -- Buttons
        local recallButton = Instance.new("TextButton")
        recallButton.Name = "RecallButton"
        recallButton.Size = UDim2.new(0, 120, 0, 40)
        recallButton.Position = UDim2.new(0.25, -60, 1, -60)
        recallButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        recallButton.Font = Enum.Font.GothamBold
        recallButton.Text = "Recall"
        recallButton.TextSize = 18
        recallButton.TextColor3 = Color3.new(1, 1, 1)
        recallButton.Parent = frame
        
        local cancelButton = Instance.new("TextButton")
        cancelButton.Name = "CancelButton"
        cancelButton.Size = UDim2.new(0, 120, 0, 40)
        cancelButton.Position = UDim2.new(0.75, -60, 1, -60)
        cancelButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        cancelButton.Font = Enum.Font.GothamBold
        cancelButton.Text = "Cancel"
        cancelButton.TextSize = 18
        cancelButton.TextColor3 = Color3.new(1, 1, 1)
        cancelButton.Parent = frame
        
        local buttonCorner1 = Instance.new("UICorner")
        buttonCorner1.CornerRadius = UDim.new(0, 8)
        buttonCorner1.Parent = recallButton
        
        local buttonCorner2 = Instance.new("UICorner")
        buttonCorner2.CornerRadius = UDim.new(0, 8)
        buttonCorner2.Parent = cancelButton
        
        -- Connect buttons
        recallButton.MouseButton1Click:Connect(function()
            print("InventoryItemHandler: Recall button clicked")
            
            -- Hide inventory
            InventoryUI.Hide()
            
            -- Close dialog
            dialog:Destroy()
            
            -- Start recalling item
            PlacementManager:RecallItemFromInventory(itemName)
        end)
        
        cancelButton.MouseButton1Click:Connect(function()
            print("InventoryItemHandler: Cancelled recall")
            dialog:Destroy()
        end)
    end
    
    -- After setting up the item interaction, ensure we fix any existing movement issues
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Reset humanoid to ensure movement works
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        humanoid.WalkSpeed = 16
    end
    
    print("InventoryItemHandler: Connected inventory item interaction")
    
    -- Setup world item recall UI
    setupWorldItemRecall(sharedModule)
end

-- Create necessary templates folder if it doesn't exist
local function setupItemTemplates()
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if not templates then
        templates = Instance.new("Folder")
        templates.Name = "ItemTemplates"
        templates.Parent = ReplicatedStorage
        
        -- Create some basic templates for testing
        local items = {
            { name = "Grass_Cube", color = BrickColor.new("Bright green"), transparency = 0 },
            { name = "Stone_Cube", color = BrickColor.new("Medium stone grey"), transparency = 0 },
            { name = "Wood_Plank", color = BrickColor.new("Brown"), transparency = 0 },
            { name = "Water_Cube", color = BrickColor.new("Bright blue"), transparency = 0.3 },
            { name = "Fire_Cube", color = BrickColor.new("Bright red"), transparency = 0 },
            { name = "Brick_Cube", color = BrickColor.new("Brick red"), transparency = 0 },
            { name = "Sand_Cube", color = BrickColor.new("Brick yellow"), transparency = 0 },
            { name = "Concrete_Cube", color = BrickColor.new("Institutional white"), transparency = 0 },
            { name = "Metal_Cube", color = BrickColor.new("Medium grey"), transparency = 0 },
            { name = "Glass_Cube", color = BrickColor.new("Toothpaste"), transparency = 0.5 }
        }
        
        for _, itemInfo in ipairs(items) do
            local part = Instance.new("Part")
            part.Name = itemInfo.name
            part.Size = Vector3.new(2, 2, 2)
            part.Anchored = true
            part.CanCollide = true
            part.BrickColor = itemInfo.color
            part.Transparency = itemInfo.transparency
            
            -- Create a StudsPerTileU/V material if it's a buildable material
            if itemInfo.name:find("Brick") or 
               itemInfo.name:find("Stone") or 
               itemInfo.name:find("Wood") or
               itemInfo.name:find("Concrete") then
                part.Material = Enum.Material.Concrete
                part.MaterialVariant = ""
            elseif itemInfo.name:find("Glass") then
                part.Material = Enum.Material.Glass
            elseif itemInfo.name:find("Water") then
                part.Material = Enum.Material.Water
            elseif itemInfo.name:find("Fire") then
                part.Material = Enum.Material.Neon
            elseif itemInfo.name:find("Grass") then
                part.Material = Enum.Material.Grass
            elseif itemInfo.name:find("Sand") then
                part.Material = Enum.Material.Sand
            elseif itemInfo.name:find("Metal") then
                part.Material = Enum.Material.Metal
            end
            
            -- Also create a shorthand version without the _Cube suffix for convenience
            local shortName = itemInfo.name:gsub("_Cube", "")
            if shortName ~= itemInfo.name then
                local shortPart = part:Clone()
                shortPart.Name = shortName
                shortPart.Parent = templates
            end
            
            part.Parent = templates
            
            -- print debug info about created template
            print("Created template: " .. part.Name .. " (" .. tostring(part.BrickColor) .. ", transparency=" .. tostring(part.Transparency) .. ")")
        end
        
        print("InventoryItemHandler: Created " .. #templates:GetChildren() .. " item templates")
    end
    
    return templates
end

-- Run initialization
local success, sharedModule = initialize()
if success then
    print("InventoryItemHandler: Successfully initialized")
    
    -- Setup item templates
    setupItemTemplates()
    
    -- Setup inventory interactions
    setupInventoryItemInteraction(sharedModule)
else
    warn("InventoryItemHandler: Failed to initialize")
end 