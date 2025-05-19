-- InventoryItemHandler.client.luau
-- Handles recalling items from inventory and connecting with the placement system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
        local placementModule = shared:FindFirstChild("core")
        
        if placementModule then
            placementModule = placementModule:FindFirstChild("placement")
            if placementModule then
                placementModule = placementModule:FindFirstChild("PlacementManager")
            end
        end
        
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
        
        -- Create PlacementManager
        if placement then
            sharedModule.PlacementManager = placement.new(sharedModule)
            -- Setup remote events instead of calling Initialize
            sharedModule.PlacementManager:SetupRemoteEvents()
            print("InventoryItemHandler: Created PlacementManager and set up remote events")
        else
            warn("InventoryItemHandler: Failed to create PlacementManager")
            return false
        end
    end
    
    print("InventoryItemHandler: PlacementManager is ready")
    
    -- Connect to inventory UI completion
    if sharedModule.InventoryUI and sharedModule.InventoryUI.Show then
        local originalShow = sharedModule.InventoryUI.Show
        sharedModule.InventoryUI.Show = function(...)
            print("InventoryItemHandler: InventoryUI.Show intercepted and called")
            return originalShow(...)
        end
        
        local originalToggle = sharedModule.InventoryUI.Toggle
        sharedModule.InventoryUI.Toggle = function(...)
            print("InventoryItemHandler: InventoryUI.Toggle intercepted and called")
            
            -- Fix state before toggling
            local player = game.Players.LocalPlayer
            local playerGui = player:WaitForChild("PlayerGui")
            local inventoryScreenGui = playerGui:FindFirstChild("InventoryUI")
            local inventoryFrame = inventoryScreenGui and inventoryScreenGui:FindFirstChild("InventoryFrame")
            
            if inventoryFrame then
                -- Update the isVisible state to match reality
                sharedModule.InventoryUI._isVisible = inventoryFrame.Visible
                print("InventoryItemHandler: Fixed InventoryUI._isVisible to match actual state:", inventoryFrame.Visible)
            end
            
            return originalToggle(...)
        end
        
        print("InventoryItemHandler: Hooked InventoryUI methods for debugging")
    end
    
    -- Manually try to add button connection
    task.spawn(function()
        wait(2) -- Wait for UI to be ready
        local player = game.Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")
        local buttonUI = playerGui:FindFirstChild("InventoryButtonUI")
        
        if buttonUI then
            local button = buttonUI:FindFirstChild("InventoryButton")
            if button then
                print("InventoryItemHandler: Found inventory button, adding additional backup connection")
                
                button.MouseButton1Click:Connect(function()
                    print("InventoryItemHandler: Inventory button clicked (from backup handler)")
                    if sharedModule.InventoryUI then
                        print("InventoryItemHandler: Calling InventoryUI.Toggle directly")
                        sharedModule.InventoryUI.Toggle()
                    end
                end)
            end
        end
    end)
    
    return true, sharedModule
end

-- Fix player movement issues
local function fixPlayerMovement(character)
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Reset states to enable movement
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        
        -- Add extra diagnostic attributes to track movement state
        humanoid:SetAttribute("LastMovementFix", os.time())
        humanoid:SetAttribute("IsMovementFixed", true)
        
        print("InventoryItemHandler: Fixed movement for character")
        
        -- Set up heartbeat connection to ensure movement stays enabled
        local movementChecked = false
        local movementConnection
        
        movementConnection = RunService.Heartbeat:Connect(function()
            if movementChecked then return end
            movementChecked = true
            
            -- Check if walkspeed is too low
            if humanoid.WalkSpeed < 10 then
                print("InventoryItemHandler: Low WalkSpeed detected, fixing")
                humanoid.WalkSpeed = 16
            end
            
            -- Check if in a bad state
            if humanoid:GetState() == Enum.HumanoidStateType.Physics or 
               humanoid:GetState() == Enum.HumanoidStateType.Seated then
                print("InventoryItemHandler: Bad state detected, fixing")
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            
            task.delay(1, function()
                movementChecked = false
            end)
        end)
        
        -- Make sure to disconnect if character removed
        character.AncestryChanged:Connect(function(_, parent)
            if not parent and movementConnection then
                movementConnection:Disconnect()
                movementConnection = nil
            end
        end)
    end
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
        
        -- Check in both World_Items AND PlacedItems folders
        local worldItems = workspace:FindFirstChild("World_Items")
        local placedItems = workspace:FindFirstChild("PlacedItems")
        local itemFolders = {}
        
        if worldItems and worldItems:FindFirstChild("Placed") then
            table.insert(itemFolders, worldItems.Placed)
        end
        
        if placedItems then
            table.insert(itemFolders, placedItems)
        end
        
        if #itemFolders == 0 then
            hoveredItem = nil
            button.Visible = false
            return
        end
        
        raycastParams.FilterDescendantsInstances = itemFolders
        
        local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)
        if raycastResult then
            -- Check if we hit a placed item and traverse up to find parent in folder
            local item = raycastResult.Instance
            
            -- Find the parent that's directly under one of our item folders
            while item do
                local parent = item.Parent
                for _, folder in ipairs(itemFolders) do
                    if parent == folder then
                        -- Found direct child of an items folder
                        if item:GetAttribute("owner") == player.UserId or 
                          (typeof(item:GetAttribute("owner")) == "string" and item:GetAttribute("owner") == tostring(player.UserId)) then
                            hoveredItem = item
                            button.Visible = true
                            return
                        end
                        break
                    end
                end
                
                -- Move up one level
                if item.Parent ~= workspace then
                    item = item.Parent
                else
                    break
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
                    -- Fix character movement before recall
                    fixPlayerMovement(player.Character)
                    
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
    return true
end

-- Connect inventory item click to placement system
local function setupInventoryItemInteraction(sharedModule)
    local InventoryUI = sharedModule.InventoryUI
    local PlacementManager = sharedModule.PlacementManager
    
    -- Set up the OnItemSelected callback in InventoryUI
    InventoryUI.OnItemSelected = function(itemName, itemData)
        print("InventoryItemHandler: Item selected from inventory:", itemName)
        
        -- First ensure player can move if they got stuck
        fixPlayerMovement(player.Character)
        
        -- Get item count if available
        local itemCount = itemData and itemData.count or 1
        print("InventoryItemHandler: Item count:", itemCount)
        
        -- Normalize the item name (replace spaces with underscores)
        local normalizedItemName = itemName:gsub(" ", "_")
        
        -- Recall the item from inventory to the player's hand
        if PlacementManager and PlacementManager.RecallItemFromInventory then
            PlacementManager:RecallItemFromInventory(normalizedItemName)
        else
            warn("InventoryItemHandler: PlacementManager.RecallItemFromInventory not available")
        end
    end
    
    print("InventoryItemHandler: Set up inventory item interaction with PlacementManager")
    return true
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
            { name = "Grass_Cube", color = BrickColor.new("Bright green"), transparency = 0, material = Enum.Material.Grass },
            { name = "Stone_Cube", color = BrickColor.new("Medium stone grey"), transparency = 0, material = Enum.Material.Slate },
            { name = "Wood_Plank", color = BrickColor.new("Brown"), transparency = 0, material = Enum.Material.Wood },
            { name = "Wood_Cube", color = BrickColor.new("Brown"), transparency = 0, material = Enum.Material.Wood },
            { name = "Water_Cube", color = BrickColor.new("Bright blue"), transparency = 0.3, material = Enum.Material.Water },
            { name = "Fire_Cube", color = BrickColor.new("Bright red"), transparency = 0, material = Enum.Material.Neon },
            { name = "Brick_Cube", color = BrickColor.new("Brick red"), transparency = 0, material = Enum.Material.Brick },
            { name = "Sand_Cube", color = BrickColor.new("Brick yellow"), transparency = 0, material = Enum.Material.Sand },
            { name = "Concrete_Cube", color = BrickColor.new("Institutional white"), transparency = 0, material = Enum.Material.Concrete },
            { name = "Metal_Cube", color = BrickColor.new("Medium grey"), transparency = 0, material = Enum.Material.Metal },
            { name = "Glass_Cube", color = BrickColor.new("Toothpaste"), transparency = 0.5, material = Enum.Material.Glass }
        }
        
        for _, itemInfo in ipairs(items) do
            local part = Instance.new("Part")
            part.Name = itemInfo.name
            part.Size = Vector3.new(2, 2, 2)
            part.Anchored = true
            part.CanCollide = true
            part.BrickColor = itemInfo.color
            part.Transparency = itemInfo.transparency
            part.Material = itemInfo.material
            
            -- Store original properties as attributes to ensure they're preserved
            part:SetAttribute("originalColor", itemInfo.color.Name)
            part:SetAttribute("originalMaterial", itemInfo.material.Name)
            part:SetAttribute("originalTransparency", itemInfo.transparency)
            
            -- Also create a shorthand version without the _Cube suffix for convenience
            local shortName = itemInfo.name:gsub("_Cube", "")
            if shortName ~= itemInfo.name then
                local shortPart = part:Clone()
                shortPart.Name = shortName
                shortPart.Parent = templates
            end
            
            part.Parent = templates
            
            -- Print debug info about created template
            print("Created template: " .. part.Name .. 
                  " (BrickColor=" .. part.BrickColor.Name .. 
                  ", Material=" .. part.Material.Name .. 
                  ", Transparency=" .. tostring(part.Transparency) .. ")")
        end
        
        print("InventoryItemHandler: Created " .. #templates:GetChildren() .. " item templates")
    else
        -- Log existing templates
        print("InventoryItemHandler: Found existing templates:")
        for _, template in ipairs(templates:GetChildren()) do
            if template:IsA("BasePart") then
                print("  - " .. template.Name .. 
                      " (BrickColor=" .. template.BrickColor.Name .. 
                      ", Material=" .. template.Material.Name .. 
                      ", Transparency=" .. tostring(template.Transparency) .. ")")
            else
                print("  - " .. template.Name .. " (Not a BasePart)")
            end
        end
        
        -- Ensure all templates have proper attributes
        for _, template in ipairs(templates:GetChildren()) do
            if template:IsA("BasePart") then
                if not template:GetAttribute("originalColor") then
                    template:SetAttribute("originalColor", template.BrickColor.Name)
                end
                if not template:GetAttribute("originalMaterial") then
                    template:SetAttribute("originalMaterial", template.Material.Name)
                end
                if not template:GetAttribute("originalTransparency") then
                    template:SetAttribute("originalTransparency", template.Transparency)
                end
            end
        end
        
        -- Make sure Wood_Cube exists alongside Wood_Plank
        if templates:FindFirstChild("Wood_Plank") and not templates:FindFirstChild("Wood_Cube") then
            local woodPlank = templates:FindFirstChild("Wood_Plank")
            local woodCube = woodPlank:Clone()
            woodCube.Name = "Wood_Cube"
            
            -- Ensure the wood cube has the right properties
            woodCube.BrickColor = BrickColor.new("Brown")
            woodCube.Material = Enum.Material.Wood
            woodCube.Transparency = 0
            
            -- Set attributes
            woodCube:SetAttribute("originalColor", "Brown")
            woodCube:SetAttribute("originalMaterial", "Wood")
            woodCube:SetAttribute("originalTransparency", 0)
            
            woodCube.Parent = templates
            print("InventoryItemHandler: Created missing Wood_Cube template")
            print("  - Wood_Cube (BrickColor=" .. woodCube.BrickColor.Name .. 
                  ", Material=" .. woodCube.Material.Name .. 
                  ", Transparency=" .. tostring(woodCube.Transparency) .. ")")
        elseif templates:FindFirstChild("Wood_Cube") then
            -- Make sure Wood_Cube has correct properties
            local woodCube = templates:FindFirstChild("Wood_Cube")
            
            -- Update properties if needed
            if woodCube.BrickColor ~= BrickColor.new("Brown") or
               woodCube.Material ~= Enum.Material.Wood then
                woodCube.BrickColor = BrickColor.new("Brown")
                woodCube.Material = Enum.Material.Wood
                woodCube.Transparency = 0
                
                -- Set attributes
                woodCube:SetAttribute("originalColor", "Brown")
                woodCube:SetAttribute("originalMaterial", "Wood")
                woodCube:SetAttribute("originalTransparency", 0)
                
                print("InventoryItemHandler: Fixed properties on existing Wood_Cube template")
                print("  - Wood_Cube (updated to BrickColor=" .. woodCube.BrickColor.Name .. 
                      ", Material=" .. woodCube.Material.Name .. 
                      ", Transparency=" .. tostring(woodCube.Transparency) .. ")")
            end
        end
        
        print("InventoryItemHandler: Found existing ItemTemplates folder with " .. #templates:GetChildren() .. " items")
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
    
    -- Setup world item recall UI
    setupWorldItemRecall(sharedModule)
else
    warn("InventoryItemHandler: Failed to initialize")
end 