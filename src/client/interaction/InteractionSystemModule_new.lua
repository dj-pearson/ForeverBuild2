-- InteractionSystemModule_new - ForeverBuild2
-- A robust interaction system for handling item interactions in the game.
-- Handles proximity detection, UI, purchasing with in-game currency or Robux.

-- IMMEDIATE CHECK: Disable this entire system if new popup system is active
if _G.DISABLE_OLD_INTERACTION_CLIENT or _G.USE_NEW_BOTTOM_POPUP_ONLY then
    print("[InteractionSystemModule_new] Disabled by global flag - new popup system is active")
    -- Return a dummy module that does nothing
    return {
        new = function()
            return {
                Initialize = function() 
                    print("[InteractionSystemModule_new] Dummy system - doing nothing")
                end,
                CreateUI = function() end,
                ShowInteractionUI = function() end,
                HideInteractionUI = function() end,
                Update = function() end
            }
        end
    }
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

-- Get local player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import shared modules
local SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
local Constants = SharedModule.Constants
-- local LazyLoadModules = SharedModule.LazyLoadModules -- Retained, might be used elsewhere

-- Remote events
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseItemEvent = remotes:WaitForChild("PurchaseItem") 
local addToInventoryEvent = remotes:WaitForChild("AddToInventory")

-- Debug settings
local DEBUG_MODE = false -- Set to true for detailed logs
local function debugLog(...)
    if DEBUG_MODE then
        print("[InteractionSystem]", ...)
    end
end

-- Constants for interaction
local INTERACTION_DISTANCE = Constants.INTERACTION_SETTINGS and Constants.INTERACTION_SETTINGS.DISTANCE or 8
local INTERACTION_CHECK_INTERVAL = Constants.INTERACTION_SETTINGS and Constants.INTERACTION_SETTINGS.CHECK_INTERVAL or 0.5
local FADE_IN_DURATION = Constants.UI and Constants.UI.DIALOG_ANIMATION_DURATION or 0.3
local FADE_OUT_DURATION = Constants.UI and Constants.UI.DIALOG_ANIMATION_DURATION and Constants.UI.DIALOG_ANIMATION_DURATION * 0.66 or 0.2

-- Module table
local InteractionSystem = {}
InteractionSystem.__index = InteractionSystem  -- Add metatable for proper OOP

function InteractionSystem.new()
    local self = setmetatable({}, InteractionSystem)
    
    -- Initialize properties
    self.initialized = false
    self.activeInteractions = {}
    self.proximityPrompts = {}
    self.currentTarget = nil
    self.ui = nil
    self.cooldownActive = false
    self.isAdmin = false
    
    return self
end

-- Create interaction UI
function InteractionSystem:CreateUI()
    -- Check global flag again to prevent UI creation
    if _G.DISABLE_OLD_INTERACTION_CLIENT or _G.USE_NEW_BOTTOM_POPUP_ONLY then
        debugLog("CreateUI disabled by global flag - new popup system is active")
        return
    end
    
    -- Create the UI if it doesn't exist
    if self.ui then return end
    
    -- Create the ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InteractionUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Create the main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 150)
    mainFrame.Position = UDim2.new(0.5, -150, 0.75, 0)
    mainFrame.BackgroundColor3 = Constants.UI.Colors.BackgroundSecondary
    mainFrame.BackgroundTransparency = Constants.UI.Colors.BackgroundTransparency or 0.2
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    -- Add corner radius
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = mainFrame
    
    -- Item name label
    local itemNameLabel = Instance.new("TextLabel")
    itemNameLabel.Name = "ItemNameLabel"
    itemNameLabel.Size = UDim2.new(1, 0, 0, 30)
    itemNameLabel.Position = UDim2.new(0, 0, 0, 10)
    itemNameLabel.BackgroundTransparency = 1
    itemNameLabel.Font = Constants.UI.Fonts.Title.Font
    itemNameLabel.TextColor3 = Constants.UI.Colors.TextPrimary
    itemNameLabel.TextSize = Constants.UI.Fonts.Title.Size
    itemNameLabel.Text = "Item Name"
    itemNameLabel.Parent = mainFrame
    
    -- Item description label
    local descriptionLabel = Instance.new("TextLabel")
    descriptionLabel.Name = "DescriptionLabel"
    descriptionLabel.Size = UDim2.new(1, -20, 0, 40)
    descriptionLabel.Position = UDim2.new(0, 10, 0, 40)
    descriptionLabel.BackgroundTransparency = 1
    descriptionLabel.Font = Constants.UI.Fonts.Body.Font
    descriptionLabel.TextColor3 = Constants.UI.Colors.TextSecondary
    descriptionLabel.TextSize = Constants.UI.Fonts.Body.Size
    descriptionLabel.TextWrapped = true
    descriptionLabel.Text = "Item description goes here"
    descriptionLabel.Parent = mainFrame
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "PriceLabel"
    priceLabel.Size = UDim2.new(1, -20, 0, 20)
    priceLabel.Position = UDim2.new(0, 10, 0, 80)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Font = Constants.UI.Fonts.Body.Font
    priceLabel.TextColor3 = Constants.UI.Colors.ThemeAccent
    priceLabel.TextSize = Constants.UI.Fonts.Body.Size
    priceLabel.Text = "Price: 100 Coins"
    priceLabel.Parent = mainFrame
    
    -- Purchase with coins button
    local purchaseCoinsButton = Instance.new("TextButton")
    purchaseCoinsButton.Name = "PurchaseCoinsButton"
    purchaseCoinsButton.Size = UDim2.new(0.45, 0, 0, 30)
    purchaseCoinsButton.Position = UDim2.new(0.05, 0, 0, 110)
    purchaseCoinsButton.BackgroundColor3 = Constants.UI.Colors[Constants.UI.ButtonStyles.Primary.BackgroundColor]
    purchaseCoinsButton.Text = "Buy with Coins"
    purchaseCoinsButton.TextColor3 = Constants.UI.Colors[Constants.UI.ButtonStyles.Primary.TextColor]
    purchaseCoinsButton.Font = Constants.UI.Fonts.Button.Font
    purchaseCoinsButton.TextSize = Constants.UI.Fonts.Button.Size
    purchaseCoinsButton.Parent = mainFrame
    
    -- Add corner radius to coins button
    local coinsButtonCorner = Instance.new("UICorner")
    coinsButtonCorner.CornerRadius = UDim.new(0, 6)
    coinsButtonCorner.Parent = purchaseCoinsButton
    
    -- Purchase with Robux button
    local purchaseRobuxButton = Instance.new("TextButton")
    purchaseRobuxButton.Name = "PurchaseRobuxButton"
    purchaseRobuxButton.Size = UDim2.new(0.45, 0, 0, 30)
    purchaseRobuxButton.Position = UDim2.new(0.5, 0, 0, 110)
    purchaseRobuxButton.BackgroundColor3 = Constants.UI.Colors.Success
    purchaseRobuxButton.Text = "Buy with Robux"
    purchaseRobuxButton.TextColor3 = Constants.UI.Colors.TextOnPrimary
    purchaseRobuxButton.Font = Constants.UI.Fonts.Button.Font
    purchaseRobuxButton.TextSize = Constants.UI.Fonts.Button.Size
    purchaseRobuxButton.Parent = mainFrame
    
    -- Add corner radius to Robux button
    local robuxButtonCorner = Instance.new("UICorner")
    robuxButtonCorner.CornerRadius = UDim.new(0, 6)
    robuxButtonCorner.Parent = purchaseRobuxButton
    
    -- Interaction instruction
    local instructionLabel = Instance.new("TextLabel")
    instructionLabel.Name = "InstructionLabel"
    instructionLabel.Size = UDim2.new(1, 0, 0, 20)
    instructionLabel.Position = UDim2.new(0, 0, 1, 10)
    instructionLabel.BackgroundTransparency = 1
    instructionLabel.Font = Constants.UI.Fonts.Caption.Font
    instructionLabel.TextColor3 = Constants.UI.Colors.TextSecondary
    instructionLabel.TextSize = Constants.UI.Fonts.Caption.Size
    instructionLabel.Text = "Press E to interact"
    instructionLabel.Parent = mainFrame
    
    -- Store UI references
    self.ui = {
        screenGui = screenGui,
        mainFrame = mainFrame,
        itemNameLabel = itemNameLabel,
        descriptionLabel = descriptionLabel,
        priceLabel = priceLabel,
        purchaseCoinsButton = purchaseCoinsButton,
        purchaseRobuxButton = purchaseRobuxButton
    }
    
    -- Connect button events
    purchaseCoinsButton.MouseButton1Click:Connect(function()
        self:PurchaseWithCoins()
    end)
    
    purchaseRobuxButton.MouseButton1Click:Connect(function()
        self:PurchaseWithRobux()
    end)
    
    -- Add the ScreenGui to PlayerGui
    screenGui.Parent = playerGui
    
    debugLog("Interaction UI created")
end

-- Show the interaction UI for a specific item
function InteractionSystem:ShowInteractionUI(item)
    -- Check global flag to prevent showing old UI
    if _G.DISABLE_OLD_INTERACTION_CLIENT or _G.USE_NEW_BOTTOM_POPUP_ONLY then
        debugLog("ShowInteractionUI disabled by global flag - new popup system is active")
        return
    end
    
    if not self.ui then
        self:CreateUI()
    end
    
    -- Get item information
    local itemName = item.Name
    local itemTier = self:GetItemTier(itemName)
    local itemInfo = self:GetItemInfo(itemName)
    
    if not itemInfo then
        debugLog("No item info found for:", itemName)
        return
    end
    
    -- Update UI with item information
    self.ui.itemNameLabel.Text = itemName
    self.ui.descriptionLabel.Text = itemInfo.description or "No description available"
    
    -- Set price information with fallbacks
    if not itemInfo.price then
        itemInfo.price = {
            INGAME = Constants.ITEM_PRICES 
                and Constants.ITEM_PRICES.BASIC 
                and Constants.ITEM_PRICES.BASIC.INGAME 
                or 5,
            ROBUX = Constants.ITEM_PRICES 
                and Constants.ITEM_PRICES.BASIC 
                and Constants.ITEM_PRICES.BASIC.ROBUX 
                or 5
        }
    end
    
    local ingamePrice = math.max(itemInfo.price.INGAME or 5, 5)
    local robuxPrice = math.max(itemInfo.price.ROBUX or 5, 5)
    
    local coinEmoji = "💰"
    local robuxEmoji = Constants.UI.Emojis and Constants.UI.Emojis.Robux or "💎"
    
    -- Ensure Constants.CURRENCY.INGAME exists or provide a fallback
    local ingameCurrencyName = Constants.CURRENCY and Constants.CURRENCY.INGAME or "Coins"

    self.ui.priceLabel.Text = string.format("Price: %s %d %s or %s %d Robux", 
        coinEmoji, ingamePrice, ingameCurrencyName, robuxEmoji, robuxPrice)
    
    -- Update button text
    self.ui.purchaseCoinsButton.Text = string.format("%s Buy with %d %s", 
        coinEmoji, ingamePrice, ingameCurrencyName)
    self.ui.purchaseRobuxButton.Text = string.format("%s Buy with %d Robux", 
        robuxEmoji, robuxPrice)
    
    -- Ensure button visibility if they were hidden
    self.ui.purchaseCoinsButton.Visible = true
    self.ui.purchaseRobuxButton.Visible = true

    -- Store the current target with the updated prices
    self.currentTarget = {
        item = item,
        itemName = itemName,
        tier = itemTier,
        ingamePrice = ingamePrice,
        robuxPrice = robuxPrice,
        itemInfo = itemInfo
    }
    
    -- Show the UI with animation
    self.ui.mainFrame.Visible = true
    self.ui.mainFrame.BackgroundTransparency = 1
    
    -- Create tween to fade in
    local fadeIn = TweenService:Create(
        self.ui.mainFrame,
        TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.2}
    )
    
    fadeIn:Play()
end

-- Hide the interaction UI
function InteractionSystem:HideInteractionUI()
    if not self.ui or not self.ui.mainFrame.Visible then return end
    
    -- Create tween to fade out
    local fadeOut = TweenService:Create(
        self.ui.mainFrame,
        TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    )
    
    fadeOut:Play()
    
    -- Hide the frame when tween completes
    fadeOut.Completed:Connect(function()
        self.ui.mainFrame.Visible = false
    end)
    
    -- Clear current target
    self.currentTarget = nil
end

-- Get item tier based on item name
function InteractionSystem:GetItemTier(itemName)
    -- Remove underscores and spaces for matching
    local cleanName = itemName:gsub("[_]", ""):lower()
    
    -- Check if name contains tier keywords
    if cleanName:find("basic") then
        return "BASIC"
    elseif cleanName:find("level1") then
        return "LEVEL_1"
    elseif cleanName:find("level2") then
        return "LEVEL_2"
    elseif cleanName:find("secondary") then
        return "SECONDARY"
    elseif cleanName:find("rare") and cleanName:find("drop") then
        return "RARE_DROP"
    elseif cleanName:find("rare") then
        return "RARE"
    elseif cleanName:find("exclusive") then
        return "EXCLUSIVE"
    elseif cleanName:find("weapon") then
        return "WEAPONS"
    elseif cleanName:find("free") then
        return "FREE_ITEMS"
    end
    
    -- Default to BASIC if no match found
    return "BASIC"
end

-- Get item information from Constants
function InteractionSystem:GetItemInfo(itemName)
    -- Handle case where itemName is a table instead of string
    if type(itemName) == "table" then
        warn("GetItemInfo received a table instead of string for itemType:", itemName)
        -- Generate a unique key for this unknown item
        local uniqueKey = "Unknown_Item_" .. tostring(itemName):sub(-4)
        return {
            icon = "rbxassetid://3284930147", -- Default icon
            description = "Unknown Item",
            tier = "BASIC",
            price = {
                INGAME = Constants.ITEM_PRICES and Constants.ITEM_PRICES.BASIC and Constants.ITEM_PRICES.BASIC.INGAME or 5,
                ROBUX = Constants.ITEM_PRICES and Constants.ITEM_PRICES.BASIC and Constants.ITEM_PRICES.BASIC.ROBUX or 5
            }
        }
    end
    
    -- First try to match exactly
    if Constants.ITEMS and Constants.ITEMS[itemName] then
        local itemInfo = Constants.ITEMS[itemName]
        
        -- Ensure proper price structure exists
        if not itemInfo.price then
            itemInfo.price = {
                INGAME = Constants.ITEM_PRICES and Constants.ITEM_PRICES.BASIC and Constants.ITEM_PRICES.BASIC.INGAME or 5,
                ROBUX = Constants.ITEM_PRICES and Constants.ITEM_PRICES.BASIC and Constants.ITEM_PRICES.BASIC.ROBUX or 5
            }
        elseif type(itemInfo.price) == "number" then
            -- Convert old price format to new format
            local oldPrice = itemInfo.price
            itemInfo.price = {
                INGAME = oldPrice,
                ROBUX = oldPrice
            }
        end
        
        return itemInfo
    end
    
    -- Ensure ITEMS exists
    if not Constants.ITEMS then
        Constants.ITEMS = {}
    end
    
    -- Try to match by checking if the item name contains a known item key
    for key, info in pairs(Constants.ITEMS) do
        if itemName:lower():find(key:lower()) then
            -- Ensure proper price structure for matched item
            if not info.price then
                info.price = {
                    INGAME = Constants.ITEM_PRICES and Constants.ITEM_PRICES.BASIC and Constants.ITEM_PRICES.BASIC.INGAME or 5,
                    ROBUX = Constants.ITEM_PRICES and Constants.ITEM_PRICES.BASIC and Constants.ITEM_PRICES.BASIC.ROBUX or 5
                }
            elseif type(info.price) == "number" then
                local oldPrice = info.price
                info.price = {
                    INGAME = oldPrice,
                    ROBUX = oldPrice
                }
            end
            
            return info
        end
    end
    
    -- Ensure Constants.ITEM_PRICES exists
    if not Constants.ITEM_PRICES then
        Constants.ITEM_PRICES = {
            BASIC = {INGAME = 5, ROBUX = 5},
            LEVEL_1 = {INGAME = 10, ROBUX = 10},
            LEVEL_2 = {INGAME = 25, ROBUX = 25},
            RARE = {INGAME = 100, ROBUX = 100},
            FREE_ITEMS = {INGAME = 0, ROBUX = 0}
        }
    end
    
    -- If no match is found, determine tier and return generic info
    local tier = self:GetItemTier(itemName)
    local tierPrices = Constants.ITEM_PRICES[tier] or Constants.ITEM_PRICES.BASIC
    
    -- Create generic item info
    local newItemInfo = {
        icon = "rbxassetid://3284930147", -- Default icon
        description = itemName .. " - " .. tier,
        tier = tier,
        price = {
            INGAME = tierPrices.INGAME or 5,
            ROBUX = tierPrices.ROBUX or 5
        }
    }
    
    -- Cache this item for future lookups
    Constants.ITEMS[itemName] = newItemInfo
    
    return newItemInfo
end

-- Purchase with in-game currency
function InteractionSystem:PurchaseWithCoins()
    if not self.currentTarget or self.cooldownActive then 
        if self.cooldownActive then
            print("Purchase on cooldown, ignoring request")
        else
            warn("PurchaseWithCoins failed: No current target")
        end
        return 
    end
    
    -- Set cooldown to prevent spam
    self.cooldownActive = true
    
    local item = self.currentTarget.item
    local itemName = self.currentTarget.itemName
    local price = self.currentTarget.ingamePrice
    
    print("CLIENT - Attempting to purchase", itemName, "with", price, "coins")
    
    -- Check for invalid data
    if not item or not item:IsA("Model") then
        warn("PurchaseWithCoins failed: Invalid item", item)
        self.cooldownActive = false -- Reset cooldown
        return
    end
    
    -- Call server to handle purchase
    print("CLIENT - Firing PurchaseItem event to server with item:", item:GetFullName(), "Currency type: INGAME, Price:", price)
    purchaseItemEvent:FireServer(item, "INGAME", price)
    
    -- Hide the UI to show that purchase is in progress
    self:HideInteractionUI()
    
    -- Reset cooldown after 2 seconds
    spawn(function()
        wait(2)
        self.cooldownActive = false
    end)
end

-- Purchase with Robux through developer product
function InteractionSystem:PurchaseWithRobux()
    if not self.currentTarget then return end
    
    local item = self.currentTarget.item
    local itemName = self.currentTarget.itemName
    local tier = self.currentTarget.tier
    local price = self.currentTarget.robuxPrice
    
    debugLog("Attempting to purchase", itemName, "with Robux")
    
    -- Create fallback TIER_PRODUCTS if it doesn't exist
    if not Constants.TIER_PRODUCTS then
        warn("Constants.TIER_PRODUCTS is nil, creating fallback")
        Constants.TIER_PRODUCTS = {
            BASIC = {id = "tier_basic", assetId = 1472807192, robux = 5},
            LEVEL_1 = {id = "tier_level1", assetId = 1472807192, robux = 10},
            LEVEL_2 = {id = "tier_level2", assetId = 1472807192, robux = 25},
            SECONDARY = {id = "tier_secondary", assetId = 1472807192, robux = 15},
            RARE = {id = "tier_rare", assetId = 1472807192, robux = 100},
            EXCLUSIVE = {id = "tier_exclusive", assetId = 1472807192, robux = 1000},
            WEAPONS = {id = "tier_weapons", assetId = 1472807192, robux = 500},
            RARE_DROP = {id = "tier_rare_drop", assetId = 1472807192, robux = 800}
        }
    end
    
    -- Get the appropriate developer product
    local productInfo = Constants.TIER_PRODUCTS[tier]
    
    -- If no product info for this tier, use BASIC as fallback
    if not productInfo then
        warn("No product info found for tier:", tier, "using BASIC tier as fallback")
        productInfo = Constants.TIER_PRODUCTS.BASIC
        
        -- If still no product info, create a basic one
        if not productInfo then
            productInfo = {id = "tier_basic", assetId = 1472807192, robux = 5}
        end
    end
    
    -- Prompt purchase
    MarketplaceService:PromptProductPurchase(player, productInfo.assetId)
    
    -- The completion of this purchase will be handled by a MarketplaceService.ProcessReceipt callback on the server
end

-- Check if an item is interactable
function InteractionSystem:IsInteractable(item)
    -- Implementation for determining if an item can be interacted with
    -- For now, assume that all items in the Items folder are interactable
    local isInItemsFolder = false
    
    local current = item
    while current and current ~= game.Workspace do
        if current.Name == "Items" then
            isInItemsFolder = true
            break
        end
        current = current.Parent
    end
    
    return isInItemsFolder
end

-- Check for items in proximity to interact with
function InteractionSystem:CheckForInteractables()
    -- Get player's position
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return {}
    end
    
    local rootPart = character.HumanoidRootPart
    local playerPosition = rootPart.Position
    
    -- Find items that can be interacted with
    local interactables = {}
    
    -- Look for the Items folder in Workspace
    local itemsFolder = game.Workspace:FindFirstChild("Items")
    if not itemsFolder then
        debugLog("Items folder not found in Workspace")
        return interactables
    end
    
    -- Search through all folders in the Items folder
    for _, folder in ipairs(itemsFolder:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            -- Check each item in the folder
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("Model") and self:IsInteractable(item) then
                    -- Find primary part or use the first part
                    local primaryPart = item.PrimaryPart
                    if not primaryPart then
                        for _, part in ipairs(item:GetDescendants()) do
                            if part:IsA("BasePart") then
                                primaryPart = part
                                break
                            end
                        end
                    end
                    
                    if primaryPart then
                        local distance = (playerPosition - primaryPart.Position).Magnitude
                        if distance <= INTERACTION_DISTANCE then
                            table.insert(interactables, {
                                item = item,
                                distance = distance
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(interactables, function(a, b)
        return a.distance < b.distance
    end)
    
    return interactables
end

-- Update the current interaction state
function InteractionSystem:Update()
    -- Check for interactables
    local interactables = self:CheckForInteractables()
    
    -- Update UI based on nearest interactable
    if #interactables > 0 then
        local nearest = interactables[1].item
        
        -- Show interaction UI if not already showing for this item
        if not self.currentTarget or self.currentTarget.item ~= nearest then
            self:ShowInteractionUI(nearest)
        end
    else
        -- Hide UI if no interactables are found
        if self.currentTarget then
            self:HideInteractionUI()
        end
    end
end

-- Handle input for interactions
function InteractionSystem:HandleInput(input, gameProcessed)
    if gameProcessed then return end
    
    -- Check for 'E' key press for interaction
    if input.KeyCode == Enum.KeyCode.E and self.currentTarget and not self.cooldownActive then
        self:PurchaseWithCoins()
    end
end

-- Initialize the interaction system
function InteractionSystem:Initialize()
    -- Check global flag to prevent old popup system from running
    if _G.DISABLE_OLD_INTERACTION_CLIENT then
        debugLog("InteractionSystem initialization disabled by global flag (new popup system active)")
        return
    end
    
    debugLog("Initializing InteractionSystem...")
    if self.initialized then
        debugLog("Already initialized.")
        return
    end

    self:CreateUI() -- Ensure UI is created on initialization

    -- Check for admin status (example, replace with your actual admin check)
    -- This might involve checking a group, a DataStore value, or a list of UserIds
    -- For simplicity, using the Constants.isAdminPlayerName
    self.isAdmin = Constants.isAdminPlayerName(player.Name)
    if self.isAdmin then
        debugLog("Player is an admin.")
    end

    -- Start checking for nearby interactables
    task.spawn(function()
        while true do
            self:Update()
            task.wait(INTERACTION_CHECK_INTERVAL)
        end
    end)
    
    -- Connect to input events for interaction
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        if input.KeyCode == Enum.KeyCode.E then
            if self.currentTarget and self.ui and self.ui.mainFrame.Visible and not self.cooldownActive then
                self:PurchaseWithCoins()
            end
        end
    end)

    self.initialized = true
    debugLog("InteractionSystem Initialized.")
end

-- Return the module
return InteractionSystem
