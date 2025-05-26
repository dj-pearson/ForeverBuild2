-- test_currency_fix.luau
-- Test script to validate currency system is working correctly

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

print("🧪 Testing Currency Fix...")

-- Wait for system to initialize
wait(3)

local function testCurrencyRetrieval()
    print("=== CURRENCY RETRIEVAL TEST ===")
    
    -- Test 1: Try to get CurrencyManager from ReplicatedStorage
    local success1, currencyManager = pcall(function()
        return require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("economy"):WaitForChild("CurrencyManager"))
    end)
    
    if success1 and currencyManager then
        print("✓ Found CurrencyManager module")
        
        -- Try Method 1: GetPlayerCurrency
        if typeof(currencyManager.GetPlayerCurrency) == "function" then
            local coins1 = currencyManager:GetPlayerCurrency(player)
            print("Method 1 - GetPlayerCurrency:", coins1)
        end
        
        -- Try Method 2: playerCurrency property
        if currencyManager.playerCurrency then
            print("Method 2 - playerCurrency property:", currencyManager.playerCurrency)
        end
    else
        print("❌ Could not find CurrencyManager module")
    end
    
    -- Test 3: Try GetMyBalance remote
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local getMyBalanceFunc = remotes:FindFirstChild("GetMyBalance")
        if getMyBalanceFunc and getMyBalanceFunc:IsA("RemoteFunction") then
            local success3, coins3 = pcall(function()
                return getMyBalanceFunc:InvokeServer()
            end)
            if success3 then
                print("Method 3 - GetMyBalance remote:", coins3)
            else
                print("Method 3 - GetMyBalance remote failed:", coins3)
            end
        else
            print("Method 3 - GetMyBalance remote not found")
        end
    else
        print("Method 3 - Remotes folder not found")
    end
    
    -- Test 4: Try global CurrencyUI
    if _G.CurrencyUI and _G.CurrencyUI.balance then
        print("Method 4 - _G.CurrencyUI.balance:", _G.CurrencyUI.balance)
    else
        print("Method 4 - _G.CurrencyUI not found or no balance")
    end
    
    -- Test 5: Try leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local coins = leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
        if coins then
            print("Method 5 - leaderstats:", coins.Value)
        else
            print("Method 5 - leaderstats found but no coins")
        end
    else
        print("Method 5 - leaderstats not found")
    end
    
    print("=== END CURRENCY TEST ===")
end

local function testEKeyPurchase()
    print("=== E-KEY PURCHASE TEST ===")
    
    -- Check if ItemInteractionClient has the updated GetPlayerCoins method
    if _G.ItemInteractionClient then
        print("✓ Found ItemInteractionClient")
        if typeof(_G.ItemInteractionClient.GetPlayerCoins) == "function" then
            local coins = _G.ItemInteractionClient:GetPlayerCoins()
            print("✓ ItemInteractionClient:GetPlayerCoins() returned:", coins)
        else
            print("❌ ItemInteractionClient:GetPlayerCoins() method not found")
        end
    else
        print("❌ ItemInteractionClient not found")
    end
    
    -- Check if BottomPurchasePopup has the updated GetPlayerCoins method
    if _G.ItemInteractionClient and _G.ItemInteractionClient.bottomPurchasePopup then
        local popup = _G.ItemInteractionClient.bottomPurchasePopup
        print("✓ Found BottomPurchasePopup")
        if typeof(popup.GetPlayerCoins) == "function" then
            local coins = popup:GetPlayerCoins()
            print("✓ BottomPurchasePopup:GetPlayerCoins() returned:", coins)
        else
            print("❌ BottomPurchasePopup:GetPlayerCoins() method not found")
        end
    else
        print("❌ BottomPurchasePopup not found")
    end
    
    print("=== END E-KEY PURCHASE TEST ===")
end

-- Run tests
testCurrencyRetrieval()
wait(1)
testEKeyPurchase()

print("🧪 Currency Fix Test Complete!")
print("💡 Try pressing E near a Red Brick Wall now!") 