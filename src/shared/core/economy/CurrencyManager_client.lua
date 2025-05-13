local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Make sure this is a client-only module
if RunService:IsServer() then
    warn("CurrencyManager_client should only be used on the client side")
    return nil
end

-- Require constants module
local Constants = require(script.Parent.Parent.Constants)

-- Create the CurrencyManager class
local CurrencyManager = {}
CurrencyManager.__index = CurrencyManager

-- Constructor
function CurrencyManager.new()
    local self = setmetatable({}, CurrencyManager)
    self.playerCurrency = Constants.CURRENCY.STARTING_COINS or 0
    self.remotes = nil
    return self
end

-- Initialize method (client version)
function CurrencyManager:Initialize()
    print("Initializing CurrencyManager (client version)")
    
    -- Try to get remotes
    local success, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    
    if success and remotes then
        self.remotes = remotes
        -- Listen for currency updates
        if remotes:FindFirstChild("UpdateBalance") then
            remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
                self.playerCurrency = newBalance
                self:OnCurrencyUpdated(newBalance)
            end)
        else
            warn("UpdateBalance remote event not found")
            -- Try again after a delay
            task.delay(5, function()
                if ReplicatedStorage:FindFirstChild("Remotes") and 
                   ReplicatedStorage.Remotes:FindFirstChild("UpdateBalance") then
                    self.remotes = ReplicatedStorage.Remotes
                    self.remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
                        self.playerCurrency = newBalance
                        self:OnCurrencyUpdated(newBalance)
                    end)
                end
            end)
        end
    else
        warn("Failed to find Remotes folder")
    end
    
    print("CurrencyManager client initialized")
end

-- Get player's currency (client version)
function CurrencyManager:GetPlayerCurrency()
    return self.playerCurrency
end

-- Event handler for currency updates
function CurrencyManager:OnCurrencyUpdated(newBalance)
    -- This could fire an event for other client modules to listen to
    -- For now, just log the update
    print("Currency updated:", newBalance)
end

-- Mock purchases (client version)
function CurrencyManager:TryPurchase(itemId, cost)
    if not self.remotes or not self.remotes:FindFirstChild("BuyItem") then
        return { success = false, message = "BuyItem remote event not found" }
    end
    
    -- Fire the remote event to the server to handle the actual purchase
    self.remotes.BuyItem:FireServer(itemId)
    
    -- The actual result will come back via the UpdateBalance event
    return { success = true, message = "Purchase request sent" }
end

return CurrencyManager
