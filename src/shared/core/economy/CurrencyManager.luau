local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local IS_SERVER = RunService:IsServer()

local Constants = require(script.Parent.Parent.Constants)

local CurrencyManager = {}
CurrencyManager.__index = CurrencyManager

-- Initialize a new CurrencyManager
function CurrencyManager.new()
    local self = setmetatable({}, CurrencyManager)
    
    -- Server-specific properties
    if IS_SERVER then
        self.playerBalances = {}
        local DataStoreService = game:GetService("DataStoreService")
        self.currencyStore = DataStoreService:GetDataStore("PlayerData")
        self.rewardTimers = {}
    -- Client-specific properties
    else
        self.playerCurrency = Constants.CURRENCY.STARTING_COINS or 0
    end
    
    return self
end

-- Initialize the CurrencyManager
function CurrencyManager:Initialize()
    if IS_SERVER then
        -- Set up player handling
        self:SetupPlayerHandling()
        
        -- Set up marketplace handling
        self:SetupMarketplaceHandling()
    else
        -- Client-side setup
        self:SetupClientHandling()
    end
end

-- Set up player handling
function CurrencyManager:SetupPlayerHandling()
    game.Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    game.Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)

    -- Handle players already in the game when the manager initializes
    if IS_SERVER then -- Ensure this server-specific logic runs only on the server
        for _, player in ipairs(Players:GetPlayers()) do
            if not self.playerBalances[player.UserId] then
                print(string.format("CurrencyManager:SetupPlayerHandling - Processing existing player: %s", player.Name))
                self:OnPlayerJoined(player)
            else
                print(string.format("CurrencyManager:SetupPlayerHandling - Existing player %s already has a balance entry.", player.Name))
            end
        end
    end
end

-- Set up marketplace handling
function CurrencyManager:SetupMarketplaceHandling()
    -- Handle purchase requests
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        
        -- Process the purchase
        local success = self:ProcessPurchase(player, receiptInfo)
        if success then
            return Enum.ProductPurchaseDecision.PurchaseGranted
        else
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    end
end

-- Handle player joining
function CurrencyManager:OnPlayerJoined(player)
    -- Initialize player balance
    self:InitializePlayerBalance(player)
    
    -- Start reward timer
    self:StartRewardTimer(player)
    
    -- Check for daily/weekly/monthly bonuses
    self:CheckLoginBonuses(player)
end

-- Handle player leaving
function CurrencyManager:OnPlayerLeaving(player)
    -- Stop reward timer
    self:StopRewardTimer(player)
    
    -- Save player balance
    self:SavePlayerBalance(player)
end

-- Initialize player balance
function CurrencyManager:InitializePlayerBalance(player)
    local balance = {
        currency = 0,
        inventory = {},
        lastRewardTime = os.time(),
        lastDailyBonus = 0,
        lastWeeklyBonus = 0,
        lastMonthlyBonus = 0,
        isLoading = true,
        isLoaded = false
    }
    
    self.playerBalances[player.UserId] = balance
    
    -- Load saved balance
    self:LoadPlayerBalance(player)
end

-- Load player balance from DataStore
function CurrencyManager:LoadPlayerBalance(player)
    local userId = player.UserId
    -- Ensure playerBalances entry exists
    if not self.playerBalances[userId] then
        -- This case should ideally be handled by InitializePlayerBalance first
        self.playerBalances[userId] = {
            currency = 0,
            inventory = {},
            lastRewardTime = os.time(),
            lastDailyBonus = 0,
            lastWeeklyBonus = 0,
            lastMonthlyBonus = 0,
            isLoading = true,
            isLoaded = false
        }
        warn(string.format("CurrencyManager:LoadPlayerBalance - playerBalances entry for %s was missing, created.", player.Name))
    else
        self.playerBalances[userId].isLoading = true -- Set loading true if called directly
        self.playerBalances[userId].isLoaded = false
    end

    local success, result
    local attempts = 0
    local maxAttempts = 6 -- Try up to 6 times (was 3)
    
    while attempts < maxAttempts and not (success and result) do
        attempts = attempts + 1
        if attempts > 1 then
            print(string.format("CurrencyManager:LoadPlayerBalance - Retrying GetAsync for %s (attempt %d/%d)", player.Name, attempts, maxAttempts))
            task.wait(2) -- Wait 2 seconds before retrying (was 1)
        end
        success, result = pcall(function()
            return self.currencyStore:GetAsync("Player_" .. userId)
        end)
        if not success then -- pcall itself failed
             warn(string.format("CurrencyManager:LoadPlayerBalance - pcall to GetAsync failed for %s on attempt %d: %s", player.Name, attempts, tostring(result))) -- result here is the error message
             result = nil -- Ensure result is nil if pcall failed, so the loop condition (success and result) is false
        end
    end
    
    if success and result then
        -- Merge loaded data with existing structure to preserve flags
        self.playerBalances[userId].currency = result.currency or 0
        self.playerBalances[userId].inventory = result.inventory or {}
        self.playerBalances[userId].lastRewardTime = result.lastRewardTime or os.time()
        self.playerBalances[userId].lastDailyBonus = result.lastDailyBonus or 0
        self.playerBalances[userId].lastWeeklyBonus = result.lastWeeklyBonus or 0
        self.playerBalances[userId].lastMonthlyBonus = result.lastMonthlyBonus or 0
        print(string.format("💰 SERVER CurrencyManager: Loaded balance for %s: %d from DataStore (PlayerData)", player.Name, self.playerBalances[userId].currency))
    else
        -- Initialize with correct balance if loading fails or new player
        local defaultCurrency = (Constants.CURRENCY and Constants.CURRENCY.STARTING_CURRENCY) or 100
        self.playerBalances[userId].currency = defaultCurrency 
        self.playerBalances[userId].inventory = {}
        self.playerBalances[userId].lastRewardTime = os.time()
        self.playerBalances[userId].lastDailyBonus = 0
        self.playerBalances[userId].lastWeeklyBonus = 0
        self.playerBalances[userId].lastMonthlyBonus = 0
        print(string.format("💰 SERVER CurrencyManager: Set default balance for %s: %d coins (DataStore load failed or new player: %s)", player.Name, defaultCurrency, tostring(not success or not result)))
    end
    
    self.playerBalances[userId].isLoading = false -- FINISHED loading
    self.playerBalances[userId].isLoaded = true   -- Data is now loaded
    
    -- Send this initial balance to the client
    self:UpdatePlayerBalance(player)
end

-- Save player balance to DataStore
function CurrencyManager:SavePlayerBalance(player)
    local balance = self.playerBalances[player.UserId]
    if not balance then return end
    
    -- Ensure the structure being saved matches what ItemPurchaseHandler expects if it also saves this.
    -- For now, assuming CurrencyManager is the sole manager of its playerBalances structure.
    -- However, the key IS now shared with ItemPurchaseHandler's datastore.

    local dataToSave = {
        currency = balance.currency or 0,
        inventory = balance.inventory or {},
        lastRewardTime = balance.lastRewardTime or os.time(),
        lastDailyBonus = balance.lastDailyBonus or 0,
        lastWeeklyBonus = balance.lastWeeklyBonus or 0,
        lastMonthlyBonus = balance.lastMonthlyBonus or 0
        -- Do NOT save isLoading or isLoaded flags to the datastore
    }

    pcall(function()
        self.currencyStore:SetAsync("Player_" .. player.UserId, dataToSave)
    end)
end

-- Start reward timer for player
function CurrencyManager:StartRewardTimer(player)
    local timer = task.spawn(function()
        while player and player.Parent do
            task.wait(Constants.CURRENCY.REWARD_INTERVAL)
            self:GiveReward(player)
        end
    end)
    
    self.rewardTimers[player.UserId] = timer
end

-- Stop reward timer for player
function CurrencyManager:StopRewardTimer(player)
    local timer = self.rewardTimers[player.UserId]
    if timer then
        task.cancel(timer)
        self.rewardTimers[player.UserId] = nil
    end
end

-- Give reward to player
function CurrencyManager:GiveReward(player)
    local balance = self.playerBalances[player.UserId]
    if not balance then return end
    
    -- Calculate reward amount
    local rewardAmount = math.floor(Constants.CURRENCY.REWARD_RATE * (Constants.CURRENCY.REWARD_INTERVAL / 60))
    rewardAmount = math.clamp(rewardAmount, Constants.CURRENCY.MIN_REWARD_AMOUNT, Constants.CURRENCY.MAX_REWARD_AMOUNT)
    
    -- Add reward to balance
    balance.currency = balance.currency + rewardAmount
    balance.lastRewardTime = os.time()
    
    -- Update player
    self:UpdatePlayerBalance(player)
end

-- Check login bonuses
function CurrencyManager:CheckLoginBonuses(player)
    local balance = self.playerBalances[player.UserId]
    if not balance then return end
    
    local currentTime = os.time()
    
    -- Check daily bonus
    if currentTime - balance.lastDailyBonus >= 86400 then -- 24 hours
        balance.currency = balance.currency + Constants.CURRENCY.DAILY_BONUS
        balance.lastDailyBonus = currentTime
    end
    
    -- Check weekly bonus
    if currentTime - balance.lastWeeklyBonus >= 604800 then -- 7 days
        balance.currency = balance.currency + Constants.CURRENCY.WEEKLY_BONUS
        balance.lastWeeklyBonus = currentTime
    end
    
    -- Check monthly bonus
    if currentTime - balance.lastMonthlyBonus >= 2592000 then -- 30 days
        balance.currency = balance.currency + Constants.CURRENCY.MONTHLY_BONUS
        balance.lastMonthlyBonus = currentTime
    end
    
    -- Update player
    self:UpdatePlayerBalance(player)
end

-- Update player balance
function CurrencyManager:UpdatePlayerBalance(player)
    local balanceData = self.playerBalances[player.UserId]
    if not balanceData then 
        warn(string.format("CurrencyManager:UpdatePlayerBalance - No balance data for player %s (UserId: %s)", player.Name, player.UserId))
        return 
    end
    
    -- Ensure data is loaded before sending update, or if it's explicitly being set (e.g. default)
    if not balanceData.isLoaded and not balanceData.isLoading then
        -- This might happen if UpdatePlayerBalance is called before LoadPlayerBalance completes
        -- Or if there's a logic path that bypasses the loading flags.
        -- For safety, one could argue to initiate a load here or wait.
        -- However, UpdatePlayerBalance is also called *after* loading completes or default is set.
        -- The print statement below will help to understand the context if this warning appears.
        warn(string.format("CurrencyManager:UpdatePlayerBalance - Called for %s when data might not be fully loaded. isLoaded: %s, isLoading: %s. Currency: %s", player.Name, tostring(balanceData.isLoaded), tostring(balanceData.isLoading), tostring(balanceData.currency)))
    end
    
    local currentCurrency = balanceData.currency
    
    -- Ensure Remotes folder and UpdateBalance event exist before firing
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateBalanceEvent = remotes:FindFirstChild("UpdateBalance")
        if updateBalanceEvent then
            print(string.format("💰 SERVER CurrencyManager: Firing UpdateBalance remote event for %s with %d currency", player.Name, currentCurrency))
            updateBalanceEvent:FireClient(player, currentCurrency)
        else
            warn(string.format("CurrencyManager:UpdatePlayerBalance - UpdateBalance RemoteEvent not found for player %s", player.Name))
        end
    else
        warn(string.format("CurrencyManager:UpdatePlayerBalance - Remotes folder not found for player %s", player.Name))
    end
end

-- Get player balance
function CurrencyManager:GetBalance(player)
    local userId = player.UserId
    local attempts = 0
    -- Wait up to ~5 seconds total. PlayerAdded should definitely have fired by then.
    local maxAttemptsInit = 25 -- for playerBalances[userId] to exist (2.5s)
    local maxAttemptsLoad = 25 -- for data to be loaded (additional 2.5s)

    -- Wait for the player's balance entry to be created by OnPlayerJoined/InitializePlayerBalance
    while not self.playerBalances[userId] and attempts < maxAttemptsInit do
        print(string.format("CurrencyManager:GetBalance - Waiting for balance entry for %s (attempt %d/%d)", player.Name, attempts + 1, maxAttemptsInit))
        task.wait(0.1)
        attempts = attempts + 1
    end

    if not self.playerBalances[userId] then
        warn(string.format("CurrencyManager:GetBalance - Balance entry for %s NOT found after %d attempts. This player may not be fully initialized. Returning 0.", player.Name, attempts))
        -- Attempting a last-ditch init, though this is not ideal here.
        self:InitializePlayerBalance(player) 
        -- This InitializePlayerBalance will do an async load. We can't wait for it here without overcomplicating.
        -- The UI will get 0, then an update when LoadPlayerBalance completes.
        return 0 
    end

    -- Now wait for the data to be loaded (isLoading == false and isLoaded == true)
    attempts = 0 -- Reset attempts for the loading phase
    while self.playerBalances[userId].isLoading == true and attempts < maxAttemptsLoad do
        print(string.format("CurrencyManager:GetBalance - Balance for %s is loading (attempt %d/%d). Waiting...", player.Name, attempts + 1, maxAttemptsLoad))
        task.wait(0.1)
        attempts = attempts + 1
    end

    if not self.playerBalances[userId].isLoaded then
        warn(string.format("CurrencyManager:GetBalance - Failed to get loaded balance for %s after %d + %d attempts. isLoading: %s, isLoaded: %s. Returning current currency or 0.", 
            player.Name, 
            maxAttemptsInit,
            attempts,
            tostring(self.playerBalances[userId].isLoading),
            tostring(self.playerBalances[userId].isLoaded)
        ))
        -- Return whatever currency is there, or 0; an update should come later if it was a genuine load issue.
        return self.playerBalances[userId].currency or 0
    end
    
    print(string.format("CurrencyManager:GetBalance - Successfully retrieved balance for %s: %d currency", player.Name, self.playerBalances[userId].currency))
    return self.playerBalances[userId].currency
end

-- Add currency to player
function CurrencyManager:AddCurrency(player, amount)
    local balance = self.playerBalances[player.UserId]
    if not balance then return false end
    
    balance.currency = balance.currency + amount
    self:UpdatePlayerBalance(player)
    return true
end

-- Remove currency from player
function CurrencyManager:RemoveCurrency(player, amount)
    local balance = self.playerBalances[player.UserId]
    if not balance then return false end
    
    if balance.currency < amount then
        return false
    end
    
    balance.currency = balance.currency - amount
    self:UpdatePlayerBalance(player)
    return true
end

-- Process Robux purchase
function CurrencyManager:ProcessPurchase(player, receiptInfo)
    -- Get product info
    local productId = receiptInfo.ProductId
    local productInfo = self:GetProductInfo(productId)
    if not productInfo then return false end
    
    -- Add currency to player
    return self:AddCurrency(player, productInfo.coins)
end

-- Get product info
function CurrencyManager:GetProductInfo(productId)
    -- TODO: Implement product info lookup
    return nil
end

-- Check if player can afford item
function CurrencyManager:CanAffordItem(player, itemId, useRobux)
    local balance = self.playerBalances[player.UserId]
    if not balance then return false end
    
    -- Get item price
    local price = self:GetItemPrice(itemId, useRobux)
    if not price then return false end
    
    if useRobux then
        -- Check Robux balance
        return player:GetAttribute("Robux") >= price
    else
        -- Check currency balance
        return balance.currency >= price
    end
end

-- Get item price
function CurrencyManager:GetItemPrice(itemId, useRobux)
    -- TODO: Implement item price lookup
    return nil
end

-- Client-side handling
function CurrencyManager:SetupClientHandling()
    print("Initializing CurrencyManager client-side")
    
    -- Try to get remotes
    local success, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    
    if success and remotes then
        -- Listen for currency updates
        if remotes:FindFirstChild("UpdateBalance") then
            remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
                self.playerCurrency = newBalance
                print("Currency updated:", newBalance)
            end)
        else
            warn("UpdateBalance remote event not found")
            -- Try again after a delay
            task.delay(5, function()
                if ReplicatedStorage:FindFirstChild("Remotes") and 
                   ReplicatedStorage.Remotes:FindFirstChild("UpdateBalance") then
                    ReplicatedStorage.Remotes.UpdateBalance.OnClientEvent:Connect(function(newBalance)
                        self.playerCurrency = newBalance
                        print("Currency updated:", newBalance)
                    end)
                end
            end)
        end
    else
        warn("Failed to find Remotes folder")
    end
    
    print("CurrencyManager client initialized")
end

-- Get player's currency (works on both client and server)
function CurrencyManager:GetPlayerCurrency(player)
    if IS_SERVER then
        -- Server implementation
        local balance = self.playerBalances[player.UserId]
        return balance and balance.currency or 0
    else
        -- Client implementation
        return self.playerCurrency or 0
    end
end

return CurrencyManager