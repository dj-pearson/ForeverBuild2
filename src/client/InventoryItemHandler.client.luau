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
    
    -- Get the PlacementManager module table from SharedModule
    local PlacementManagerModule = sharedModule.PlacementManager
    
    if PlacementManagerModule and type(PlacementManagerModule) == "table" and PlacementManagerModule.new then
        print("InventoryItemHandler: PlacementManager module found in SharedModule. Creating new client instance.")
        -- Create a new instance for this handler
        local pmInstance = PlacementManagerModule.new(sharedModule)
        
        -- It's crucial that the client calls CacheRemoteEvents on its instance
        -- SetupRemoteEvents is server-side, CacheRemoteEvents is for client
        if pmInstance.CacheRemoteEvents then 
            pmInstance:CacheRemoteEvents() 
            print("InventoryItemHandler: Called CacheRemoteEvents on new PlacementManager instance.")
        else
            warn("InventoryItemHandler: Newly created PlacementManager instance does NOT have CacheRemoteEvents method!")
        end

        -- Store this specific instance for use within InventoryItemHandler if needed, 
        -- or ensure it's passed to where it's used. 
        -- For now, we assume the main purpose is that its .new() and CacheRemoteEvents get called.
        -- If other functions in this file need to call PlacementManager methods, they should use pmInstance.
        sharedModule.PlacementManagerClientInstance = pmInstance -- Or a more specific local variable

    else
        warn("InventoryItemHandler: PlacementManager module (or its .new method) not found in SharedModule or is not a table. Placement will likely fail.")
        return false
    end
    
    print("InventoryItemHandler: PlacementManager initialization logic executed.")
    
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
    local PlacementManager = sharedModule.PlacementManagerClientInstance
    
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
    
    -- Track what item we're selecting
    local selectedItem = nil
    local selectedHighlight = nil
    
    -- Helper to clear selection
    local function clearSelection()
        if selectedHighlight then
            selectedHighlight:Destroy()
            selectedHighlight = nil
        end
        selectedItem = nil
        button.Visible = false
    end
    
    -- Mouse click handler to select world items
    local userInputService = game:GetService("UserInputService")
    userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = player:GetMouse()
            local target = mouse.Target
            if not target then
                clearSelection()
                return
            end
            -- Traverse up to find a placed item with instanceId
            local item = target
            while item and item ~= workspace do
                if item:GetAttribute("instanceId") and (item:GetAttribute("owner") == player.UserId or tostring(item:GetAttribute("owner")) == tostring(player.UserId)) then
                    -- Select this item
                    selectedItem = item
                    button.Visible = true
                    -- Add highlight
                    if selectedHighlight then selectedHighlight:Destroy() end
                    selectedHighlight = Instance.new("Highlight")
                    selectedHighlight.FillColor = Color3.fromRGB(255, 255, 0)
                    selectedHighlight.OutlineColor = Color3.fromRGB(255, 255, 0)
                    selectedHighlight.FillTransparency = 0.5
                    selectedHighlight.OutlineTransparency = 0
                    selectedHighlight.Adornee = item
                    selectedHighlight.Parent = item
                    return
                end
                item = item.Parent
            end
            -- If clicked elsewhere, clear selection
            clearSelection()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            -- Right click to clear selection
            clearSelection()
        end
    end)
    
    -- Connect recall button click
    button.MouseButton1Click:Connect(function()
        if selectedItem then
            print("InventoryItemHandler: Recalling world item:", selectedItem.Name)
            local instanceId = selectedItem:GetAttribute("instanceId")
            if not instanceId then
                warn("InventoryItemHandler: Selected item has no instanceId!")
                return
            end
            -- Fire server to recall the item
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                local recallItemRemote = remotes:FindFirstChild("RecallItem")
                if recallItemRemote then
                    fixPlayerMovement(player.Character)
                    recallItemRemote:FireServer(instanceId)
                    -- Hide the button and clear selection
                    clearSelection()
                else
                    warn("InventoryItemHandler: RecallItem remote not found")
                end
            else
                warn("InventoryItemHandler: Remotes folder not found")
            end
        end
    end)
    
    print("InventoryItemHandler: Setup world item recall UI (click-to-select)")
    return true
end

-- Connect inventory item click to placement system
local function setupInventoryItemInteraction(sharedModule)
    local InventoryUI = sharedModule.InventoryUI
    local PlacementManager = sharedModule.PlacementManagerClientInstance
    
    print("InventoryItemHandler: Setting up inventory item interaction...")
    print("InventoryUI available:", InventoryUI ~= nil)
    print("PlacementManager available:", PlacementManager ~= nil)
    
    if not InventoryUI then
        warn("InventoryItemHandler: InventoryUI is nil - cannot set up interaction")
        return false
    end
    
    if not PlacementManager then
        warn("InventoryItemHandler: PlacementManager is nil - cannot set up interaction")
        return false
    end
    
    -- Set up the OnItemSelected callback in InventoryUI
    InventoryUI.OnItemSelected = function(itemName, itemData)
        print("InventoryItemHandler: Item selected from inventory:", itemName)
        print("InventoryItemHandler: Item data:", itemData)
        
        -- First ensure player can move if they got stuck
        fixPlayerMovement(player.Character)
        
        -- Get item count if available
        local itemCount = itemData and itemData.count or 1
        print("InventoryItemHandler: Item count:", itemCount)
        
        -- Normalize the item name (replace spaces with underscores)
        local normalizedItemName = itemName:gsub(" ", "_")
        print("InventoryItemHandler: Normalized item name:", normalizedItemName)
        
        -- Use ShowItemInHand for consistent behavior
        if PlacementManager and PlacementManager.ShowItemInHand then
            print("InventoryItemHandler: Calling ShowItemInHand...")
            local success = PlacementManager:ShowItemInHand(normalizedItemName)
            if success then
                print("InventoryItemHandler: Successfully showed item in hand")
            else
                warn("InventoryItemHandler: ShowItemInHand failed")
            end
        else
            warn("InventoryItemHandler: PlacementManager.ShowItemInHand not available")
            print("InventoryItemHandler: Available methods:")
            if PlacementManager then
                for k, v in pairs(PlacementManager) do
                    if type(v) == "function" then
                        print("  -", k, "(function)")
                    end
                end
            end
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
            { name = "Brick_Cube", color = BrickColor.new("Reddish brown"), transparency = 0, material = Enum.Material.Brick },
            { name = "Sand_Cube", color = BrickColor.new("Brick yellow"), transparency = 0, material = Enum.Material.Sand },
            { name = "Concrete_Cube", color = BrickColor.new("Institutional white"), transparency = 0, material = Enum.Material.Concrete },
            { name = "Metal_Cube", color = BrickColor.new("Medium stone grey"), transparency = 0, material = Enum.Material.Metal },
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
    -- setupWorldItemRecall(sharedModule) -- COMMENTED OUT TO PREVENT CONFLICT
else
    warn("InventoryItemHandler: Failed to initialize")
end 