-- ItemInteractionClient.luau
-- Client-side module for interacting with catalog items and placed world items

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Import shared modules with fallback
print("ItemInteractionClient: Attempting to require shared module")
local SharedModule
local Constants

local success, errorMessage = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared", 5))
    Constants = SharedModule.Constants
    return true
end)

if not success then
    warn("ItemInteractionClient: Failed to require SharedModule:", errorMessage)
    print("ItemInteractionClient: Creating minimal SharedModule fallback")
    -- Create minimal fallback for Constants
    Constants = {
        INTERACTION_DISTANCE = 10,
        ITEM_ACTIONS = {
            clone = { cost = 100 },
            move = { cost = 10 },
            rotate = { cost = 5 },
            destroy = { cost = 20 }
        },
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        }
    }
    SharedModule = {
        Constants = Constants,
        GameManager = nil,
        LazyLoadModules = {
            register = function() return true end,
            require = function() return nil end
        }
    }
else
    print("ItemInteractionClient: Successfully required SharedModule")
end

local ItemInteractionClient = {}
ItemInteractionClient.__index = ItemInteractionClient

function ItemInteractionClient.new()
    local self = setmetatable({}, ItemInteractionClient)
    
    -- Remote events/functions
    self.remotes = {}
    
    -- UI elements
    self.catalogUI = nil
    self.worldItemUI = nil
    self.inventoryUI = nil
    self.proximityUI = nil
    self.notificationUI = nil
    
    -- State tracking
    self.currentTarget = nil
    self.isInteracting = false
    self.maxInteractionDistance = 10 -- Units
    self.proximityEnabled = true
    
    -- Connection tracking for cleanup
    self.connections = {}
    
    return self
end

function ItemInteractionClient:Initialize()
    print("ItemInteractionClient initializing...")
    
    -- Cache remote events/functions
    self:SetupRemotes()
    
    -- Create UI components
    self:SetupUI()
    
    -- Set up input handling
    self:SetupInputHandling()
    
    -- Set up mouse movement tracking
    self:SetupMouseTracking()
    
    -- Add notification to show system is ready
    self:ShowNotification("Interaction system ready! Press E to interact with objects.")
    
    print("ItemInteractionClient initialized successfully")
    return true
end

function ItemInteractionClient:SetupRemotes()
    -- Get the Remotes folder
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not remotesFolder then
        warn("Remotes folder not found - some functionality may be limited")
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Cache remote functions
    self:CacheRemoteFunction(remotesFolder, "GetItemCatalog")
    self:CacheRemoteFunction(remotesFolder, "GetItemData")
    self:CacheRemoteFunction(remotesFolder, "GetAvailableInteractions")
    self:CacheRemoteFunction(remotesFolder, "GetInventory")
    self:CacheRemoteFunction(remotesFolder, "IsItemAffordable")
    
    -- Cache remote events
    self:CacheRemoteEvent(remotesFolder, "PurchaseItem")
    self:CacheRemoteEvent(remotesFolder, "PlaceItem")
    self:CacheRemoteEvent(remotesFolder, "ChangeItemColor")
    self:CacheRemoteEvent(remotesFolder, "AddToInventory")
    self:CacheRemoteEvent(remotesFolder, "RemoveFromInventory")
    self:CacheRemoteEvent(remotesFolder, "NotifyPlayer")

    -- New Item Action Request Events
    self:CacheRemoteEvent(remotesFolder, "RequestCloneItem")
    self:CacheRemoteEvent(remotesFolder, "RequestMoveItem")
    self:CacheRemoteEvent(remotesFolder, "RequestRecallItem")
    self:CacheRemoteEvent(remotesFolder, "RequestDestroyItem")
    self:CacheRemoteEvent(remotesFolder, "RequestRotateItem")
    
    -- Connect to notifications
    if self.remotes.NotifyPlayer then
        self.remotes.NotifyPlayer.OnClientEvent:Connect(function(message)
            self:ShowNotification(message)
        end)
    end
end

function ItemInteractionClient:CacheRemoteFunction(parent, name)
    local remoteFunc = parent:FindFirstChild(name)
    if remoteFunc and remoteFunc:IsA("RemoteFunction") then
        self.remotes[name] = remoteFunc
    else
        warn("Remote function '" .. name .. "' not found")
    end
end

function ItemInteractionClient:CacheRemoteEvent(parent, name)
    local remoteEvent = parent:FindFirstChild(name)
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        self.remotes[name] = remoteEvent
    else
        warn("Remote event '" .. name .. "' not found")
    end
end

function ItemInteractionClient:SetupUI()
    -- Create notification UI
    self:CreateNotificationUI()
    
    -- Create proximity UI for highlighting interactable objects
    self:CreateProximityUI()
    
    -- Load the catalog UI, inventory UI and world item UI modules
    -- These would typically be loaded from the SharedModule
    self:LoadUIModules()

    -- Initialize PlacedItemDialog and set up its action handler
    local PlacedItemDialog = SharedModule.PlacedItemDialog -- Assuming it's loaded via SharedModule
    if PlacedItemDialog and PlacedItemDialog.Initialize then
        local playerGui = player:WaitForChild("PlayerGui")
        local screenGui = playerGui:FindFirstChild("PlacedItemDialogUI") 
        if not screenGui then
            screenGui = Instance.new("ScreenGui")
            screenGui.Name = "PlacedItemDialogUI" 
            screenGui.Parent = playerGui
        end
        PlacedItemDialog.Initialize(screenGui)

        PlacedItemDialog.OnActionSelected = function(itemId, actionKey, itemInstance, actualCost)
            print(string.format("ItemInteractionClient: PlacedItemDialog.OnActionSelected - ItemID: %s, ActionKey: %s, Cost: %d", 
                tostring(itemId), tostring(actionKey), actualCost))

            local instanceId = itemInstance and itemInstance:GetAttribute("instanceId")
            if not instanceId then
                warn("ItemInteractionClient: Cannot perform action - itemInstance is nil or missing instanceId attribute.")
                self:ShowNotification("Error: Could not identify the selected item.", "Error")
                return
            end

            -- Placeholder for client-side currency check - replace with actual currency check
            local currentPlayerCurrency = 10000 -- TODO: Get this from CurrencyManager or GameManager
            if currentPlayerCurrency < actualCost then
                self:ShowNotification(string.format("Not enough coins for %s (Cost: %d)", Constants.ITEM_ACTIONS[actionKey].name, actualCost), "Error")
                return
            end

            if actionKey == "clone" and self.remotes.RequestCloneItem then
                -- For clone, we'd ideally also need a target position from the player.
                -- For now, server can place it nearby or require a second step.
                self:ShowNotification(string.format("Requesting clone for %s...", itemInstance.Name), "Info")
                self.remotes.RequestCloneItem:FireServer(instanceId, actualCost)
            elseif actionKey == "move" and self.remotes.RequestMoveItem then
                -- Move would require a new placement system interaction
                self:ShowNotification("Move action selected. (Full implementation pending placement system integration)", "Info")
                -- self.remotes.RequestMoveItem:FireServer(instanceId, actualCost, newPosition, newRotation) 
            elseif actionKey == "recall" and self.remotes.RequestRecallItem then
                self:ShowNotification(string.format("Requesting recall for %s...", itemInstance.Name), "Info")
                self.remotes.RequestRecallItem:FireServer(instanceId, actualCost)
            elseif actionKey == "destroy" and self.remotes.RequestDestroyItem then
                self:ShowNotification(string.format("Requesting destroy for %s...", itemInstance.Name), "Info")
                self.remotes.RequestDestroyItem:FireServer(instanceId, actualCost)
            elseif actionKey == "rotate" and self.remotes.RequestRotateItem then
                 -- Rotate might also need a sub-UI for direction/angle
                self:ShowNotification("Rotate action selected. (Full implementation pending)", "Info")
                -- self.remotes.RequestRotateItem:FireServer(instanceId, actualCost, rotationParameters)
            else
                warn("ItemInteractionClient: Unknown or unhandled actionKey:", actionKey)
                self:ShowNotification("Unknown action: " .. actionKey, "Error")
            end
        end
    else
        warn("ItemInteractionClient: PlacedItemDialog module not found or not initialized correctly in SharedModule.")
    end
end

function ItemInteractionClient:CreateNotificationUI()
    -- Create notification UI for displaying messages to the player
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui for notifications
    self.notificationUI = Instance.new("ScreenGui")
    self.notificationUI.Name = "InteractionNotifications"
    self.notificationUI.ResetOnSpawn = false
    self.notificationUI.Parent = playerGui
    
    -- Create a container for notifications
    local container = Instance.new("Frame")
    container.Name = "NotificationContainer"
    container.Size = UDim2.new(0, 300, 0, 200)
    container.Position = UDim2.new(1, -320, 0, 20)
    container.BackgroundTransparency = 1
    container.Parent = self.notificationUI
    
    -- Add UI list layout for stacking notifications
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = container
end

function ItemInteractionClient:CreateProximityUI()
    -- Create a billboard gui template for highlighting interactable objects
    self.proximityUI = Instance.new("BillboardGui")
    self.proximityUI.Name = "ProximityInteractUI"
    self.proximityUI.Size = UDim2.new(0, 220, 0, 60)
    self.proximityUI.StudsOffset = Vector3.new(0, 3, 0)
    self.proximityUI.AlwaysOnTop = true
    self.proximityUI.Enabled = false
    
    -- Add background frame
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Parent = self.proximityUI
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = bg
    
    -- Add stroke for visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 2
    stroke.Parent = bg
    
    -- Add text label
    local label = Instance.new("TextLabel")
    label.Name = "Title"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 22
    label.Font = Enum.Font.GothamBold
    label.Text = "[E] Interact"
    label.Parent = bg
end

function ItemInteractionClient:LoadUIModules()
    -- Create the catalog UI
    local CatalogItemUI = require(script.Parent:WaitForChild("CatalogItemUI"))
    self.catalogUI = CatalogItemUI.new()
    self.catalogUI:Initialize()
    
    -- Create the world item UI
    self:CreateWorldItemUI()
    
    -- Define UI show functions
    self.ShowCatalogUI = function(itemName)
        self.catalogUI:Show(itemName)
    end
    
    self.ShowWorldItemUI = function(itemGuid)
        self:ShowInteractionUI(itemGuid)
    end
    
    self.ShowInventoryUI = function()
        self:ShowNotification("Opening inventory...")
        -- This would be implemented with a separate inventory UI module
    end
end

-- Create UI for interacting with placed world items (This function becomes largely OBSOLETE)
-- We keep it for now in case any part is reused, but PlacedItemDialog takes over its main role.
function ItemInteractionClient:CreateWorldItemUI()
    print("ItemInteractionClient: CreateWorldItemUI is now mostly handled by PlacedItemDialog. This function can be deprecated.")
end

-- This function becomes OBSOLETE as PlacedItemDialog handles its own UI creation and button logic.
function ItemInteractionClient:ShowInteractionUI(itemGuid)
    print("ItemInteractionClient: ShowInteractionUI is DEPRECATED. Use PlacedItemDialog.Show(...) directly.")
    -- ... (original content of ShowInteractionUI - can be removed) ...
    -- As a quick redirect for now, though this isn't ideal:
    local targetItem = nil -- We need to get the actual item instance here based on itemGuid
    -- This is problematic because itemGuid might not be enough to get the instance directly here.
    -- The calling code in InteractWithWorldItem should pass the instance.
    -- For now, this will likely not work correctly until InteractWithWorldItem is fully refactored.
    if self.currentTarget and self.currentTarget:GetAttribute("guid") == itemGuid then
        targetItem = self.currentTarget
    end

    if targetItem then
        local itemId = targetItem:GetAttribute("itemId") or targetItem.Name
        local itemName = (Constants.ITEMS[itemId] and Constants.ITEMS[itemId].name) or itemId
        SharedModule.PlacedItemDialog.Show(itemId, itemName, targetItem)
    else
        warn("ItemInteractionClient: Deprecated ShowInteractionUI called without a valid target for itemGuid:", itemGuid)
    end
end

function ItemInteractionClient:HideInteractionUI()
    -- This would now call PlacedItemDialog.Hide() if that was the active UI.
    -- If other custom UIs were managed by this, they'd be hidden here.
    SharedModule.PlacedItemDialog.Hide() 
    -- self.worldItemUI.Enabled = false -- If self.worldItemUI was a separate container
    -- self.currentItemGuid = nil
    print("ItemInteractionClient: HideInteractionUI called, now defers to PlacedItemDialog.Hide()")
end

-- HandleInteraction is also largely superseded by PlacedItemDialog.OnActionSelected
-- We might keep it if there are other interaction pathways.
function ItemInteractionClient:HandleInteraction(itemGuid, interaction)
    print(string.format("ItemInteractionClient: HandleInteraction (itemGuid: %s, interaction: %s) - Likely DEPRECATED", tostring(itemGuid), tostring(interaction)))
    -- This logic is now primarily within PlacedItemDialog.OnActionSelected
    -- ... (original content - can be significantly reduced or removed) ...
end

function ItemInteractionClient:SetupInputHandling()
    -- Handle E key for interaction
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            self:TryInteract()
        elseif input.KeyCode == Enum.KeyCode.I then
            self:ShowInventoryUI()
        end
    end)
    table.insert(self.connections, inputConnection)
    
    -- Handle mobile touch input
    local touchConnection = UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
        if gameProcessed then return end
        
        -- Use the first touch position
        local touchPosition = touchPositions[1]
        if touchPosition then
            -- If we have a current target, interact with it
            if self.currentTarget then
                self:TryInteract()
            else
                -- Otherwise, try to find a target based on touch position
                local camera = workspace.CurrentCamera
                local ray = camera:ScreenPointToRay(touchPosition.X, touchPosition.Y)
                
                -- Set up raycast parameters
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {player.Character}
                
                -- Cast ray
                local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 50, raycastParams)
                if raycastResult and raycastResult.Instance then
                    local target = self:GetInteractableFromPart(raycastResult.Instance)
                    if target then
                        self.currentTarget = target
                        self:ShowProximityUI(target)
                        self:TryInteract()
                    end
                end
            end
        end
    end)
    table.insert(self.connections, touchConnection)
    
    -- Handle cleanup when player leaves
    player.AncestryChanged:Connect(function()
        self:Cleanup()
    end)
end

function ItemInteractionClient:SetupMouseTracking()
    -- Update target on mouse movement
    local mouseConnection = RunService.RenderStepped:Connect(function()
        self:UpdateCurrentTarget()
    end)
    table.insert(self.connections, mouseConnection)
end

function ItemInteractionClient:UpdateCurrentTarget()
    -- Don't update if we're already interacting
    if self.isInteracting then return end
    
    -- Get character and humanoid root part
    local character = player.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Check if we're pointing at an interactable object
    local target = mouse.Target
    if target then
        print(string.format("--- DBG:UpdateCurrentTarget() - mouse.Target: %s (Class: %s) ---", target:GetFullName(), target.ClassName))
    else
        print("--- DBG:UpdateCurrentTarget() - mouse.Target is NIL ---")
    end
    
    if not target then
        -- Hide UI and clear target if we're not pointing at anything
        if self.currentTarget then
            self:HideProximityUI()
            self.currentTarget = nil
        end
        return
    end
    
    -- Check if we're pointing at an interactable object
    local interactable = self:GetInteractableFromPart(target)
    if interactable then
        print(string.format("--- DBG:UpdateCurrentTarget() - GetInteractableFromPart returned: %s ---", interactable:GetFullName()))
    else
        print("--- DBG:UpdateCurrentTarget() - GetInteractableFromPart returned NIL for target: " .. target:GetFullName())
    end

    if not interactable then
        -- Hide UI and clear target if we're not pointing at an interactable
        if self.currentTarget then
            self:HideProximityUI()
            self.currentTarget = nil
        end
        return
    end
    
    -- Check distance to the object
    local objectPosition = interactable.PrimaryPart and interactable.PrimaryPart.Position or interactable:GetModelCFrame().Position
    local distance = (hrp.Position - objectPosition).Magnitude
    print(string.format("--- DBG:UpdateCurrentTarget() - Interactable: %s, Distance: %.2f ---", interactable.Name, distance))
    
    if distance > self.maxInteractionDistance then
        -- Hide UI and clear target if we're too far away
        if self.currentTarget then
            self:HideProximityUI()
            self.currentTarget = nil
        end
        return
    end
    
    -- Set new target and show UI
    if interactable ~= self.currentTarget then
        self.currentTarget = interactable
        self:ShowProximityUI(interactable)
    end
end

function ItemInteractionClient:GetInteractableFromPart(part)
    -- DEBUG PRINT ADDED
    print(string.format("--- DBG:GetInteractableFromPart() - Called with part: %s (Class: %s) ---", part:GetFullName(), part.ClassName))

    -- First check if it's in the Items folder (store catalog item)
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and part:IsDescendantOf(itemsFolder) then
        print("--- DBG:GetInteractableFromPart() - Checking as STORE item ---") -- DEBUG
        local ancestor = part
        while ancestor and ancestor.Parent ~= itemsFolder and not ancestor:IsDescendantOf(itemsFolder) do 
            ancestor = ancestor.Parent
        end
        print(string.format("--- DBG:GetInteractableFromPart() - Store item ancestor loop (original). Ancestor: %s ---", ancestor and ancestor:GetFullName() or "nil")) -- DEBUG
        
        if ancestor and ancestor:IsA("Model") and ancestor.PrimaryPart then
            print(string.format("--- DBG:GetInteractableFromPart() - Found STORE item model: %s ---", ancestor:GetFullName())) -- DEBUG
            return ancestor
        end
    end
    
    -- Next check if it's in the World_Items folder (placed item)
    local worldFolder = workspace:FindFirstChild("World_Items")
    if worldFolder and part:IsDescendantOf(worldFolder) then
        print("--- DBG:GetInteractableFromPart() - Checking as WORLD item (part is descendant of World_Items) ---") -- DEBUG
        local placedFolder = worldFolder:FindFirstChild("Placed") -- Get the "Placed" subfolder
        if not placedFolder then
            print("--- DBG:GetInteractableFromPart() - 'Placed' subfolder NOT FOUND in World_Items. Returning nil. ---") -- DEBUG
            return nil
        end

        local ancestor = part
        -- Corrected loop condition:
        -- Stop when the ancestor's parent IS the 'Placed' folder.
        -- This means 'ancestor' itself is the item model directly under 'Placed'.
        while ancestor and ancestor.Parent ~= placedFolder do
            if not ancestor.Parent or ancestor.Parent == workspace or ancestor.Parent == worldFolder then -- Added worldFolder to safety break
                print("--- DBG:GetInteractableFromPart() - World item ancestor loop (corrected) - SAFETY BREAK, ancestor became: " .. (ancestor and ancestor.Name or "nil")) -- DEBUG
                ancestor = nil
                break
            end
            ancestor = ancestor.Parent
        end
        -- MORE DETAILED DEBUGGING FOR WORLD ITEM ANCESTOR
        print(string.format("--- DBG:GetInteractableFromPart() - World item ANCESTOR after loop: %s ---", ancestor and ancestor:GetFullName() or "nil")) -- DEBUG

        if ancestor then
            print(string.format("--- DBG:GetInteractableFromPart() - Ancestor ClassName: %s, IsA('Model'): %s, PrimaryPart: %s ---",
                ancestor.ClassName,
                tostring(ancestor:IsA("Model")),
                ancestor.PrimaryPart and ancestor.PrimaryPart:GetFullName() or "NIL"
            )) -- DEBUG
        end
        
        -- Check if it's a model with a primary part
        if ancestor and ancestor:IsA("Model") then -- REMOVED PrimaryPart check
            print(string.format("--- DBG:GetInteractableFromPart() - Found WORLD item model: %s (PrimaryPart check removed) ---", ancestor:GetFullName())) -- DEBUG
            return ancestor
        else
            if ancestor then
                print(string.format("--- DBG:GetInteractableFromPart() - World item ancestor (%s) is NOT a model or lacks PrimaryPart. IsA('Model'): %s, Has PrimaryPart: %s ---", ancestor:GetFullName(), tostring(ancestor:IsA("Model")), tostring(ancestor.PrimaryPart ~= nil))) -- DEBUG
            else
                 print("--- DBG:GetInteractableFromPart() - World item ancestor is nil after loop. ---") -- DEBUG
            end
        end
    end
    
    print(string.format("--- DBG:GetInteractableFromPart() - Returning NIL for part: %s ---", part:GetFullName())) -- DEBUG
    return nil
end

function ItemInteractionClient:ShowProximityUI(target)
    -- Don't show if proximity UI is disabled
    if not self.proximityEnabled then return end
    
    -- Clone the proximity UI template
    local ui = self.proximityUI:Clone()
    
    -- Update the UI based on the target type
    local isStoreItem = self:IsStoreItem(target)
    local label = ui:FindFirstChild("Title", true)
    
    if label then
        if isStoreItem then
            -- Store item UI
            local itemName = target.Name:gsub("_", " ")
            label.Text = "[E] View " .. itemName
        else
            -- World item UI
            label.Text = "[E] Interact"
        end
    end
    
    -- Attach to target and show
    ui.Adornee = target
    ui.Enabled = true
    ui.Parent = player.PlayerGui
    
    -- Store reference for cleanup
    if target:FindFirstChild("ProximityUI") then
        target:FindFirstChild("ProximityUI"):Destroy()
    end
    ui.Name = "ProximityUI"
    ui.Parent = target
end

function ItemInteractionClient:HideProximityUI()
    -- Remove proximity UI from current target
    if self.currentTarget and self.currentTarget:FindFirstChild("ProximityUI") then
        self.currentTarget:FindFirstChild("ProximityUI"):Destroy()
    end
end

function ItemInteractionClient:TryInteract()
    print("--- ItemInteractionClient:TryInteract() CALLED ---") -- DEBUG
    -- Don't interact if we're already interacting
    if self.isInteracting then 
        print("--- ItemInteractionClient:TryInteract() - Already interacting, returning. ---") -- DEBUG
        return 
    end
    
    -- Need a valid target to interact with
    if not self.currentTarget then 
        print("--- ItemInteractionClient:TryInteract() - No currentTarget, returning. ---") -- DEBUG
        return 
    end
    
    print(string.format("--- ItemInteractionClient:TryInteract() - currentTarget: %s ---", self.currentTarget:GetFullName())) -- DEBUG

    -- Set interacting flag
    self.isInteracting = true
    
    -- Hide proximity UI
    self:HideProximityUI()
    
    -- Determine interaction type
    local isStoreItem = self:IsStoreItem(self.currentTarget)
    
    if isStoreItem then
        -- Handle store item interaction
        -- local itemName = self.currentTarget.Name:gsub("_", " ") -- Corrected potential error if Name is not a string
        local itemName = self.currentTarget.Name
        if type(itemName) == "string" then
            itemName = itemName:gsub("_", " ")
        end
        self:InteractWithStoreItem(self.currentTarget)
    else
        -- Handle world item interaction
        print("--- ItemInteractionClient:TryInteract() - Target is a WORLD item. Calling InteractWithWorldItem. ---") -- DEBUG
        self:InteractWithWorldItem(self.currentTarget) -- This will now call PlacedItemDialog.Show
    end
    
    -- Clear flags and target after short delay
    task.delay(0.2, function()
        self.isInteracting = false
        -- self.currentTarget = nil -- Don't clear currentTarget here, PlacedItemDialog might still need it or hide might clear it.
    end)
end

function ItemInteractionClient:IsStoreItem(target)
    -- Check if the target is in the Items folder (store catalog item)
    local itemsFolder = workspace:FindFirstChild("Items")
    return itemsFolder and target:IsDescendantOf(itemsFolder)
end

function ItemInteractionClient:InteractWithStoreItem(target)
    -- Get the item name
    local itemName = target.Name
    
    -- Check if the item is in the catalog
    local itemData
    local success, result = pcall(function() -- Wrapped pcall for safety
        if self.remotes.GetItemData then
            return self.remotes.GetItemData:InvokeServer(itemName)
        end
        return nil
    end)
    
    if not success or not result then
        self:ShowNotification("Error: Item data not found or error fetching. " .. (success == false and tostring(result) or ""), "Error")
        return
    end
    itemData = result
    
    -- Show catalog UI for this item
    if self.ShowCatalogUI then -- Check if function exists
        self:ShowCatalogUI(itemName)
    else
        warn("ItemInteractionClient: self.ShowCatalogUI is not defined.")
    end
end

function ItemInteractionClient:InteractWithWorldItem(target)
    print("--- ItemInteractionClient:InteractWithWorldItem() CALLED ---") -- DEBUG
    if not target then
        print("--- ItemInteractionClient:InteractWithWorldItem() - No target, returning. ---") -- DEBUG
        self:ShowNotification("Error: No target item to interact with.", "Error")
        return
    end

    local itemId = target:GetAttribute("itemId") or target.Name -- Prefer itemId attribute
    local itemName = (Constants.ITEMS[itemId] and Constants.ITEMS[itemId].name) or itemId
    local instanceId = target:GetAttribute("instanceId") -- Get instanceId for actions

    print(string.format("--- ItemInteractionClient:InteractWithWorldItem() - Target: %s, ItemID: %s, ItemName: %s, InstanceID: %s ---", target:GetFullName(), tostring(itemId), tostring(itemName), tostring(instanceId))) -- DEBUG

    if not instanceId then
         warn("ItemInteractionClient: Target item " .. target.Name .. " is missing 'instanceId' attribute. Cannot show action dialog.")
         print("--- ItemInteractionClient:InteractWithWorldItem() - MISSING instanceId attribute. ---") -- DEBUG
         self:ShowNotification("Cannot perform actions on this item (missing ID).", "Error")
         return
    end
    
    print(string.format("ItemInteractionClient: Interacting with world item. Name: %s, ItemID: %s, InstanceID: %s", target.Name, itemId, instanceId))

    if SharedModule and SharedModule.PlacedItemDialog and SharedModule.PlacedItemDialog.Show then
        print("--- ItemInteractionClient:InteractWithWorldItem() - SharedModule.PlacedItemDialog.Show IS AVAILABLE. Calling it now... ---") -- DEBUG
        SharedModule.PlacedItemDialog.Show(itemId, itemName, target) -- Pass the actual 'target' instance
        print("--- ItemInteractionClient:InteractWithWorldItem() - AFTER calling SharedModule.PlacedItemDialog.Show. ---") -- DEBUG
    else
        warn("ItemInteractionClient: PlacedItemDialog or its Show method not available via SharedModule.")
        print("--- ItemInteractionClient:InteractWithWorldItem() - PlacedItemDialog.Show IS NOT AVAILABLE. ---") -- DEBUG
        self:ShowNotification("Interaction menu is currently unavailable.", "Error")
        -- Fallback: The old self:ShowWorldItemUI(itemGuid) is deprecated and likely won't work as intended.
        -- local itemGuid = target:GetAttribute("guid") -- old way
        -- if itemGuid then self:ShowWorldItemUI(itemGuid) end
    end
end

function ItemInteractionClient:GetAvailableInteractions(itemGuidOrInstance)
    local itemInstance = nil
    if typeof(itemGuidOrInstance) == "Instance" then
        itemInstance = itemGuidOrInstance
    elseif typeof(itemGuidOrInstance) == "string" then
        -- This path is problematic as we need the instance for price.
        -- We'd have to find the instance by GUID from the world.
        warn("GetAvailableInteractions called with GUID, this is not ideal for dynamic costs.")
    end

    local interactions = {}
    -- This function's role changes. PlacedItemDialog now builds its actions directly from Constants.ITEM_ACTIONS
    -- This function might be used by other systems if they need a list of raw action keys.
    for actionKey, _ in pairs(Constants.ITEM_ACTIONS) do
        table.insert(interactions, actionKey)
    end
    
    print("ItemInteractionClient: GetAvailableInteractions returning: ", table.concat(interactions, ", "))
    return interactions
end

function ItemInteractionClient:ShowNotification(message)
    -- Create a notification UI element
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui or not self.notificationUI then return end
    
    local container = self.notificationUI:FindFirstChild("NotificationContainer")
    if not container then return end
    
    -- Create notification
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(1, 0, 0, 40)
    notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notification.BorderSizePixel = 0
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification
    
    -- Add stroke for visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = notification
    
    -- Add text label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Font = Enum.Font.Gotham
    label.Text = message
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = notification
    
    -- Set layout order for proper stacking
    notification.LayoutOrder = tick() * -1
    notification.Parent = container
    
    -- Animate in
    notification.BackgroundTransparency = 1
    label.TextTransparency = 1
    
    -- Fade in
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    game:GetService("TweenService"):Create(notification, tweenInfo, {BackgroundTransparency = 0.2}):Play()
    game:GetService("TweenService"):Create(label, tweenInfo, {TextTransparency = 0}):Play()
    
    -- Remove after delay
    task.delay(5, function()
        -- Fade out
        game:GetService("TweenService"):Create(notification, tweenInfo, {BackgroundTransparency = 1}):Play()
        game:GetService("TweenService"):Create(label, tweenInfo, {TextTransparency = 1}):Play()
        
        -- Remove after fade out
        task.delay(0.3, function()
            notification:Destroy()
        end)
    end)
end

function ItemInteractionClient:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Remove UIs
    if self.notificationUI then
        self.notificationUI:Destroy()
        self.notificationUI = nil
    end
    
    -- Remove proximity UI from current target
    self:HideProximityUI()
    
    print("ItemInteractionClient cleaned up successfully")
end

return ItemInteractionClient