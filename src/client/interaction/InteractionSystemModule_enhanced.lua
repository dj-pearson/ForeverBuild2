-- InteractionSystemModule_enhanced.lua
-- Enhanced version with better error handling and fallbacks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

-- Get player and character references
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Module configuration
local DEBUG_VERBOSE = false -- Set to true for detailed logging
local MAX_INTERACTION_DISTANCE = 10
local INTERACTION_CHECK_INTERVAL = 0.5
local RETRY_REMOTES_INTERVAL = 5
local MAX_REMOTE_RETRIES = 10
local REMOTE_FUNCTIONS_PATH = "Remotes"

-- Local debugging function
local function debugLog(...)
    if DEBUG_VERBOSE then
        print("[DEBUG]", ...)
    end
end

-- Initialize with safe loading of dependencies
local Constants, LazyLoadModules

-- Try to load LazyLoadModules with fallback
local lazyLoadSuccess, lazyLoadError = pcall(function()
    LazyLoadModules = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("LazyLoadModules"))
end)

if not lazyLoadSuccess then
    warn("[InteractionSystem] Failed to load LazyLoadModules:", lazyLoadError)
    -- Create a minimal fallback implementation
    LazyLoadModules = {
        register = function() end,
        require = function(modulePath) 
            warn("[InteractionSystem] Using fallback require for:", modulePath)
            return {} 
        end
    }
end

-- Try to load Constants with fallback
local constantsSuccess, constantsError = pcall(function()
    Constants = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("Constants"))
end)

if not constantsSuccess then
    warn("[InteractionSystem] Failed to load Constants:", constantsError)
    -- Create a fallback constants table
    Constants = {
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        },
        ITEMS = {} -- Empty items table as fallback
    }
end

-- Safely find remotes with retries
local function getSafeRemote(remoteName, remoteType, maxRetries)
    local remoteFolder = ReplicatedStorage:FindFirstChild(REMOTE_FUNCTIONS_PATH)
    
    -- Create a temporary remote folder if it doesn't exist
    if not remoteFolder then
        warn("[InteractionSystem] Remote folder not found, creating temporary one")
        remoteFolder = Instance.new("Folder")
        remoteFolder.Name = REMOTE_FUNCTIONS_PATH
        remoteFolder.Parent = ReplicatedStorage
    end
    
    -- Look for existing remote
    local remote = remoteFolder:FindFirstChild(remoteName)
    if remote then
        return remote
    end
    
    -- If not found, try a few more times
    local retriesLeft = maxRetries or MAX_REMOTE_RETRIES
    
    while retriesLeft > 0 and not remote do
        wait(RETRY_REMOTES_INTERVAL)
        retriesLeft = retriesLeft - 1
        
        -- Check again
        remoteFolder = ReplicatedStorage:FindFirstChild(REMOTE_FUNCTIONS_PATH)
        if remoteFolder then
            remote = remoteFolder:FindFirstChild(remoteName)
            if remote then
                break
            end
        end
        
        warn("[InteractionSystem] Waiting for " .. remoteName .. " remote. Retries left: " .. retriesLeft)
    end
    
    -- Last chance - create temporary instance for testing
    if not remote and game:GetService("RunService"):IsStudio() then
        warn("[InteractionSystem] Creating temporary " .. remoteType .. " '" .. remoteName .. "' for testing in Studio")
        remote = Instance.new(remoteType)
        remote.Name = remoteName
        remote.Parent = remoteFolder
    end
    
    return remote
end

-- Fallback UI function
local function createSimpleInteractionUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SimpleInteractionMenu"
    gui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 200)
    frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    frame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    frame.BackgroundTransparency = 0.2
    frame.Parent = gui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Interaction Menu"
    title.TextColor3 = Constants.UI_COLORS.TEXT
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 24, 0, 24)
    closeButton.Position = UDim2.new(1, -30, 0, 8)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = frame
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 1, -50)
    container.Position = UDim2.new(0, 10, 0, 40)
    container.BackgroundTransparency = 1
    container.Parent = frame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = container
    
    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
    
    return gui, container
end

-- Create the InteractionSystem module
local InteractionSystem = {}
InteractionSystem.__index = InteractionSystem

function InteractionSystem.new()
    local self = setmetatable({}, InteractionSystem)
    
    -- Internal state
    self.isInitialized = false
    self.currentInteractable = nil
    self.isInteractionUIVisible = false
    self.remoteEvents = {}
    self.remoteFunctions = {}
    self.interactionCheckThread = nil
    self.hasLoadingErrorsOccurred = false
    self.interactionUIScripts = {}
    
    return self
end

function InteractionSystem:Initialize()
    debugLog("Initializing enhanced interaction system")
    
    -- Only initialize once
    if self.isInitialized then
        return
    end
    
    -- Try to initialize remote functions and events
    self:InitializeRemotes()
    
    -- Initialize interaction detection
    self:InitializeInteractionDetection()
    
    -- Initialize UI components
    self:InitializeUI()
    
    self.isInitialized = true
    debugLog("Enhanced interaction system initialized")
    
    return true
end

function InteractionSystem:InitializeRemotes()
    -- Set up remote functions
    self.remoteFunctions.getAvailableInteractions = getSafeRemote("GetAvailableInteractions", "RemoteFunction")
    self.remoteEvents.cloneItem = getSafeRemote("CloneItem", "RemoteEvent")
    self.remoteEvents.useItem = getSafeRemote("UseItem", "RemoteEvent")
    self.remoteEvents.placeItem = getSafeRemote("PlaceItem", "RemoteEvent")
    self.remoteEvents.deleteItem = getSafeRemote("DeleteItem", "RemoteEvent")
    
    -- If essential remotes are missing and we're out of retries, create a notification
    if not self.remoteFunctions.getAvailableInteractions then
        self:ShowLocalNotification("Critical remotes missing. Interaction system may not work.", true)
        self.hasLoadingErrorsOccurred = true
    end
end

function InteractionSystem:InitializeInteractionDetection()
    -- Set up interaction detection loop
    self.interactionCheckThread = spawn(function()
        while true do
            wait(INTERACTION_CHECK_INTERVAL)
            if player.Character then
                self:CheckForInteractions()
            end
        end
    end)
    
    -- Set up key press detection
    ContextActionService:BindAction(
        "InteractionSystemInteract",
        function(_, inputState)
            if inputState == Enum.UserInputState.Begin and self.currentInteractable then
                self:ShowInteraction(self.currentInteractable)
            end
        end,
        false,
        Enum.KeyCode.E
    )
end

function InteractionSystem:InitializeUI()
    -- Try to load UI modules if available
    local uiModuleNames = {
        "PlacedItemDialog",
        "InventoryUI",
        "PurchaseDialog"
    }
    
    for _, moduleName in ipairs(uiModuleNames) do
        local success, result = pcall(function()
            return LazyLoadModules.require("UI/" .. moduleName)
        end)
        
        if success and result then
            self.interactionUIScripts[moduleName] = result
        else
            debugLog("Failed to load UI module:", moduleName)
        end
    end
    
    -- If essential UI modules are missing, create a notification
    if not self.interactionUIScripts.PlacedItemDialog then
        self:ShowLocalNotification("Some UI components couldn't be loaded. Using fallback UI.", false)
    end
end

function InteractionSystem:CheckForInteractions()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local rootPart = player.Character.HumanoidRootPart
    local interactablesFound = false
    
    -- Raycast to find interactables
    local ray = Ray.new(rootPart.Position, rootPart.CFrame.LookVector * MAX_INTERACTION_DISTANCE)
    local ignoreList = {player.Character}
    local hit, position, normal, material = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
    
    if hit and hit.Parent then
        -- Check if this is an interactable object
        local isInteractable = hit:FindFirstChild("IsInteractable") 
            or hit.Parent:FindFirstChild("IsInteractable")
            or hit:FindFirstChild("ItemId")
            or hit.Parent:FindFirstChild("ItemId")
        
        if isInteractable then
            self.currentInteractable = hit.Parent:FindFirstChild("ItemId") and hit.Parent or hit
            interactablesFound = true
            
            -- Show interaction prompt if it's not already visible
            if not self.isInteractionUIVisible then
                self:ShowInteractionPrompt(self.currentInteractable)
            end
        end
    end
    
    -- Clear current interactable if nothing was found
    if not interactablesFound then
        self.currentInteractable = nil
        self:HideInteractionPrompt()
    end
end

function InteractionSystem:ShowInteractionPrompt(interactable)
    -- Implement a simple interaction prompt
    if not player or not player:FindFirstChild("PlayerGui") then return end
    
    -- Remove any existing prompt
    self:HideInteractionPrompt()
    
    -- Create new prompt
    local gui = Instance.new("ScreenGui")
    gui.Name = "InteractionPrompt"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.5, -100, 0.8, 0)
    frame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    frame.BackgroundTransparency = 0.3
    frame.Parent = gui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = frame
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, -20)
    text.Position = UDim2.new(0, 10, 0, 10)
    text.BackgroundTransparency = 1
    text.TextColor3 = Constants.UI_COLORS.TEXT
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.Text = "Press E to interact"
    text.Parent = frame
    
    self.isInteractionUIVisible = true
end

function InteractionSystem:HideInteractionPrompt()
    if player and player:FindFirstChild("PlayerGui") then
        local prompt = player.PlayerGui:FindFirstChild("InteractionPrompt")
        if prompt then
            prompt:Destroy()
        end
    end
    
    self.isInteractionUIVisible = false
end

function InteractionSystem:ShowInteraction(interactable)
    if not interactable then return end
    
    -- Hide prompt
    self:HideInteractionPrompt()
    
    -- Get interactions from server
    if self.remoteFunctions.getAvailableInteractions then
        local success, interactions = pcall(function()
            return self.remoteFunctions.getAvailableInteractions:InvokeServer(interactable)
        end)
        
        if success and interactions then
            -- Try to show interaction dialog using placedItemDialog if available
            if self.interactionUIScripts.PlacedItemDialog then
                self.interactionUIScripts.PlacedItemDialog:ShowInteractions(interactable, interactions)
            else
                -- Fallback to simple interaction menu
                self:ShowSimpleInteractionMenu(interactable, interactions)
            end
        else
            self:ShowLocalNotification("Failed to get interactions from server", true)
        end
    else
        -- If remote function is missing, show test interactions in Studio
        if game:GetService("RunService"):IsStudio() then
            local testInteractions = {
                {name = "Test Interaction 1", id = "test1"},
                {name = "Test Interaction 2", id = "test2"}
            }
            self:ShowSimpleInteractionMenu(interactable, testInteractions)
        else
            self:ShowLocalNotification("Interaction system not fully loaded", true)
        end
    end
end

function InteractionSystem:ShowSimpleInteractionMenu(interactable, interactions)
    -- If no interactions or no player, don't show menu
    if not interactions or #interactions == 0 or not player or not player:FindFirstChild("PlayerGui") then
        return
    end
    
    -- Remove existing menu if present
    local existingMenu = player.PlayerGui:FindFirstChild("SimpleInteractionMenu")
    if existingMenu then
        existingMenu:Destroy()
    end
    
    -- Create new menu
    local gui, container = createSimpleInteractionUI()
    gui.Parent = player.PlayerGui
    
    -- Add interaction buttons
    for i, interaction in ipairs(interactions) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 30)
        button.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
        button.BackgroundTransparency = 0.2
        button.Text = interaction.name or "Interaction " .. i
        button.TextColor3 = Constants.UI_COLORS.TEXT
        button.TextSize = 14
        button.Font = Enum.Font.GothamMedium
        button.Parent = container
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = button
        
        -- Handle interaction
        button.MouseButton1Click:Connect(function()
            gui:Destroy()
            self:HandleInteraction(interactable, interaction)
        end)
    end
end

function InteractionSystem:HandleInteraction(interactable, interaction)
    if not interactable or not interaction then return end
    
    -- Determine which remote to use based on interaction type
    local actionType = interaction.actionType or interaction.id
    local remote = nil
    
    if actionType == "clone" or actionType == "pickup" then
        remote = self.remoteEvents.cloneItem
    elseif actionType == "use" then
        remote = self.remoteEvents.useItem
    elseif actionType == "place" then
        remote = self.remoteEvents.placeItem
    elseif actionType == "delete" then
        remote = self.remoteEvents.deleteItem
    end
    
    -- Try to fire the remote event
    if remote then
        local success, result = pcall(function()
            return remote:FireServer(interactable, interaction)
        end)
        
        if not success then
            self:ShowLocalNotification("Failed to perform interaction: " .. tostring(result), true)
        end
    else
        -- Show test notification in Studio
        if game:GetService("RunService"):IsStudio() then
            self:ShowLocalNotification("Studio test: " .. (interaction.name or "Interaction performed"), false)
        else
            self:ShowLocalNotification("Unable to perform this interaction", true)
        end
    end
end

function InteractionSystem:ShowLocalNotification(message, isError)
    if not player or not player:FindFirstChild("PlayerGui") then return end
    
    -- Remove existing notifications
    local existingNotifications = player.PlayerGui:FindFirstChild("LocalNotifications")
    if not existingNotifications then
        existingNotifications = Instance.new("ScreenGui")
        existingNotifications.Name = "LocalNotifications"
        existingNotifications.ResetOnSpawn = false
        existingNotifications.Parent = player.PlayerGui
    end
    
    -- Create notification
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 300, 0, 60)
    notification.Position = UDim2.new(0.5, -150, 0.1, 0)
    notification.BackgroundColor3 = isError and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 150, 50)
    notification.BackgroundTransparency = 0.2
    notification.Parent = existingNotifications
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification
    
    local text = Instance.new("TextLabel")
    text.Name = "Message"
    text.Size = UDim2.new(1, -20, 1, -20)
    text.Position = UDim2.new(0, 10, 0, 10)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.TextWrapped = true
    text.Text = message
    text.Parent = notification
    
    -- Animate and remove after delay
    spawn(function()
        wait(3)
        for i = 0, 10 do
            notification.BackgroundTransparency = 0.2 + (i * 0.08)
            text.TextTransparency = i * 0.1
            wait(0.1)
        end
        notification:Destroy()
    end)
end

function InteractionSystem:Update()
    -- Called from the client update loop
    -- We use this to keep checking for interactions
end

-- Return the module
return InteractionSystem
