-- PlacementCore.luau
-- Main orchestrator for the placement system, using modular components
-- Maintains the existing PlacementManager API for backward compatibility

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Import our modules
local ItemTemplateManager = require(script.Parent.modules.ItemTemplateManager)
local PreviewManager = require(script.Parent.modules.PreviewManager)
local PlacementValidator = require(script.Parent.modules.PlacementValidator)
local ItemDataManager = require(script.Parent.modules.ItemDataManager)
local RemoteEventManager = require(script.Parent.modules.RemoteEventManager)
local MovementManager = require(script.Parent.modules.MovementManager)

local PlacementCore = {}
PlacementCore.__index = PlacementCore

function PlacementCore.new(sharedModule)
    local self = setmetatable({}, PlacementCore)
    
    print("--- PLACEMENT CORE .new() CALLED ---")
    
    -- Initialize modular components
    self.itemTemplateManager = ItemTemplateManager.new()
    self.previewManager = PreviewManager.new(self.itemTemplateManager)
    self.validator = PlacementValidator.new()
    self.itemDataManager = ItemDataManager.new(sharedModule)
    self.remoteEventManager = RemoteEventManager.new()
    self.movementManager = MovementManager.new(self.validator, self.remoteEventManager)
    
    -- Store shared module reference
    self.sharedModule = sharedModule
    
    -- State tracking
    self.isPlacing = false
    self.selectedItem = nil
    self.currentPlacementAngleX = 0
    self.currentPlacementAngleY = 0
    self.currentPlacementAngleZ = 0
    self.currentAngleY = 0 -- For backward compatibility
    
    -- Client-specific initialization
    if RunService:IsClient() then
        print("--- PLACEMENT CORE CLIENT CONSTRUCTOR REACHED (IsClient == true) ---")
        
        -- Additional client state
        self.isMovingExistingItem = false
        self.itemBeingMovedInstance = nil
        self.currentMoveCost = 0
        self.isTransitioningFromRotation = false
        
        -- Input and movement connections
        self.inputConnections = {}
        self.movementConnections = {}
        
        -- Cache remote events
        self:CacheRemoteEvents()
    end
    
    -- Server-specific initialization
    if RunService:IsServer() then
        -- Server state
        self.ItemsByOwner = {}
        
        -- Initialize remote events
        self:_SetupRemoteEvents()
    end
    
    return self
end

-- BACKWARD COMPATIBILITY METHODS --
-- These methods maintain the existing PlacementManager API

function PlacementCore:GetItemTemplate(itemId)
    return self.itemTemplateManager:GetItemTemplate(itemId)
end

function PlacementCore:StartPlacing(itemId, existingPreviewItem)
    if RunService:IsServer() then return false end
    
    -- Clear any existing hand items first
    self:ClearItemFromHand()
    self:ResetPlacementState()
    
    print("PlacementCore: Client StartPlacing for item:", itemId)
    
    -- Store the selected item
    self.selectedItem = itemId
    self.isPlacing = true
    
    -- Create or use existing preview item
    local previewItem = existingPreviewItem
    if not previewItem then
        previewItem = self.previewManager:CreatePreviewItem(itemId)
    end
    
    if not previewItem then
        warn("PlacementCore: Failed to create preview item for", itemId)
        self:ResetPlacementState()
        return false
    end
    
    -- Set the preview item
    self.previewManager:SetPreviewItem(previewItem)
    
    -- Set up placement controls
    self:_ActivatePlacementControls()
    
    return true
end

function PlacementCore:ShowItemInHand(itemId)
    if RunService:IsServer() then return false end
    
    local onPlaceCallback = function(selectedItemId)
        self:StartPlacing(selectedItemId)
    end
    
    local onCancelCallback = function()
        print("PlacementCore: Hand item placement cancelled")
    end
    
    return self.previewManager:ShowItemInHand(itemId, onPlaceCallback, onCancelCallback)
end

function PlacementCore:ClearItemFromHand()
    if RunService:IsServer() then return end
    self.previewManager:ClearItemInHand()
end

function PlacementCore:ResetPlacementState()
    if RunService:IsServer() then return end
    
    print("PlacementCore: Resetting placement state")
    
    -- Clear placement state
    self.isPlacing = false
    self.selectedItem = nil
    self.isMovingExistingItem = false
    self.itemBeingMovedInstance = nil
    self.currentMoveCost = 0
    self.isTransitioningFromRotation = false
    
    -- Reset angles
    self.currentPlacementAngleX = 0
    self.currentPlacementAngleY = 0
    self.currentPlacementAngleZ = 0
    self.currentAngleY = 0
    
    -- Clear preview items
    self.previewManager:ClearAll()
    
    -- Disconnect input/movement connections
    self:_DisconnectPlacementControls()
end

-- Update placement preview (simplified version of the massive original function)
function PlacementCore:UpdatePlacementPreview()
    if RunService:IsServer() then return end
    
    local previewItem = self.previewManager:GetPreviewItem()
    if not previewItem then return end
    
    if not (self.isPlacing or self.isMovingExistingItem) then return end
    
    -- Early nil check and conversion for angles
    self.currentPlacementAngleX = tonumber(self.currentPlacementAngleX) or 0
    self.currentPlacementAngleY = tonumber(self.currentPlacementAngleY) or 0
    self.currentPlacementAngleZ = tonumber(self.currentPlacementAngleZ) or 0
    
    -- Get mouse position via raycasting
    local camera = Workspace.CurrentCamera
    local mouse = Players.LocalPlayer:GetMouse()
    
    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {previewItem}
    
    local raycastResult = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
    
    if not raycastResult then return end
    
    local hitPosition = raycastResult.Position
    local surfaceNormal = raycastResult.Normal
    
    -- Calculate target position
    local targetPosition = hitPosition + surfaceNormal * 2
    
    -- Create rotation CFrame
    local currentRotation = CFrame.Angles(
        math.rad(self.currentPlacementAngleX),
        math.rad(self.currentPlacementAngleY),
        math.rad(self.currentPlacementAngleZ)
    )
    
    -- Update preview position
    self.previewManager:UpdatePreviewPosition(targetPosition, currentRotation)
end

-- Simplified input setup
function PlacementCore:_ActivatePlacementControls()
    if RunService:IsServer() then return end
    
    self:_DisconnectPlacementControls()
    
    -- Connect input for placement
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click to place
            self:_HandlePlaceAttempt()
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or Escape to cancel
            self:ResetPlacementState()
        end
    end)
    
    -- Connect movement for preview updates
    local movementConnection = RunService.RenderStepped:Connect(function()
        self:UpdatePlacementPreview()
    end)
    
    table.insert(self.inputConnections, inputConnection)
    table.insert(self.movementConnections, movementConnection)
end

function PlacementCore:_DisconnectPlacementControls()
    for _, connection in ipairs(self.inputConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    for _, connection in ipairs(self.movementConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    self.inputConnections = {}
    self.movementConnections = {}
end

function PlacementCore:_HandlePlaceAttempt()
    if not self.selectedItem then return end
    
    -- Get placement position from preview
    local previewItem = self.previewManager:GetPreviewItem()
    if not previewItem then return end
    
    local targetPosition
    local targetOrientation
    
    if previewItem:IsA("Model") and previewItem.PrimaryPart then
        local cf = previewItem:GetPrimaryPartCFrame()
        targetPosition = cf.Position
        targetOrientation = cf - cf.Position
    elseif previewItem:IsA("BasePart") then
        local cf = previewItem.CFrame
        targetPosition = cf.Position
        targetOrientation = cf - cf.Position
    else
        warn("PlacementCore: Unable to get placement position from preview")
        return
    end
    
    -- Fire placement event to server
    local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local placeItemEvent = remotes:FindFirstChild("PlaceItem")
        if placeItemEvent then
            placeItemEvent:FireServer(self.selectedItem, targetPosition, targetOrientation)
            print("PlacementCore: Fired PlaceItem event for", self.selectedItem)
        end
    end
    
    -- Reset placement state
    self:ResetPlacementState()
end

-- REMOTE EVENT HANDLING --

function PlacementCore:CacheRemoteEvents()
    if RunService:IsServer() then return end
    
    print("PlacementCore: Caching remote events --- MARKER ---")
    
    -- Implementation simplified - just store the cached events
    self.cachedRemotes = {}
    
    local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotes then
        print("PlacementCore: Remotes folder found immediately.")
        
        local expectedEvents = {
            "PlaceItem", "ItemPlaced", "RecallItem", "ItemRecalled",
            "UpdateItem", "ItemUpdated", "DeleteItem", "ItemDeleted"
        }
        
        for _, eventName in ipairs(expectedEvents) do
            local event = remotes:FindFirstChild(eventName)
            if event then
                self.cachedRemotes[eventName] = event
                print("PlacementCore: Successfully cached remote event:", eventName)
            end
        end
    end
end

function PlacementCore:_SetupRemoteEvents()
    if RunService:IsClient() then return end
    
    print("PlacementCore: Setting up remote events")
    
    -- This would be implemented to handle server-side remote events
    -- For now, we'll defer to the existing implementation
end

-- PLACEHOLDER METHODS FOR COMPATIBILITY --
-- These maintain the existing API but defer complex functionality

function PlacementCore:Initialize(sharedModule, placedItemsFolder)
    print("PlacementCore: Initialize called")
    
    self.sharedModule = sharedModule
    
    if RunService:IsServer() then
        -- Server initialization
        self:_SetupRemoteEvents()
        -- Add other server setup as needed
    end
    
    print("PlacementCore: Initialization completed")
    return true
end

-- Movement methods (simplified stubs for now)
function PlacementCore:InitiateMoveOperation(itemInstance, cost)
    print("PlacementCore: InitiateMoveOperation called (stub)")
    return false
end

function PlacementCore:HandleCostedRecallItemRequest(player, instanceId, cost, originalItemId)
    print("PlacementCore: HandleCostedRecallItemRequest called (stub)")
    return false
end

-- Data methods (stubs)
function PlacementCore:SaveWorldData()
    print("PlacementCore: SaveWorldData called (stub)")
    return true
end

function PlacementCore:LoadWorldData()
    print("PlacementCore: LoadWorldData called (stub)")
    return true
end

return PlacementCore 