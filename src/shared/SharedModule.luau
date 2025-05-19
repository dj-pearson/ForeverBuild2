--[[
    SharedModule.luau
    This module provides a simplified, resilient interface for shared components.
    It handles missing dependencies gracefully to prevent cascading failures.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModule = {}

print("Shared init.luau loading...")

-- Try to load Constants from core folder
local Constants = nil
local success, errorMessage = pcall(function()
    -- First try to load from within the shared module's core folder
    local coreModule = script:FindFirstChild("core")
    if coreModule and coreModule:FindFirstChild("Constants") then
        print("Loading Constants from core subfolder")
        Constants = require(coreModule.Constants)
        return true
    end
    
    -- Then try to load from ReplicatedStorage.core
    local coreFolder = ReplicatedStorage:FindFirstChild("core") 
    if coreFolder and coreFolder:FindFirstChild("Constants") then
        print("Loading Constants from ReplicatedStorage.core")
        Constants = require(coreFolder.Constants)
        return true
    end
    
    error("Could not find Constants module")
end)

if not success then
    warn("Failed to load Constants module: " .. errorMessage)
    print("Using fallback Constants")
    
    -- Use fallback Constants
    Constants = {
        -- Item Actions and Costs
        ITEM_ACTIONS = {
            clone = { cost = 100 },
            move = { cost = 10 },
            rotate = { cost = 5 },
            destroy = { cost = 20 }
        },
        
        -- Currency Configuration
        CURRENCY = {
            INGAME = "Coins",
            ROBUX = "Robux",
            REWARD_RATE = 1.67, -- Coins per real minute
            REWARD_INTERVAL = 60, -- Reward interval in seconds
            STARTING_CURRENCY = 100,
            STARTING_COINS = 100,
            PRODUCTS = {
                {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 3285357280},
                {id = "coins_5000", name = "5,500 Coins", coins = 5000, robux = 350, bonusCoins = 500, assetId = 3285387112}
            }
        },
        
        -- Admin Configuration
        ADMIN_IDS = {
            7768610061 -- Main admin ID
        },
        
        -- UI Colors
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        },
        
        -- Interaction Settings
        INTERACTION_DISTANCE = 10
    }
end

-- Expose Constants
SharedModule.Constants = Constants

-- Create stub managers
SharedModule.GameManager = {
    new = function()
        return {
            Initialize = function() end,
            InitializePlayerData = function() return true end,
            SavePlayerData = function() return true end,
            HandleItemPurchase = function() return true end
        }
    end
}

SharedModule.InventoryManager = {
    new = function()
        return {
            Initialize = function() end,
            GetPlayerInventory = function() return { inventory = {}, currency = 100 } end,
            AddItemToInventory = function() return true end
        }
    end
}

SharedModule.LazyLoadModules = {
    register = function() return true end,
    require = function() return {} end
}

function SharedModule.Init()
    print("[SharedModule] Init called. Using simplified SharedModule structure.")
end

return SharedModule 