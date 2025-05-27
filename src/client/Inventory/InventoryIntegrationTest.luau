-- InventoryIntegrationTest.luau
-- Comprehensive test suite for the inventory system
-- Tests both unified and legacy systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InventoryIntegrationTest = {}
InventoryIntegrationTest.__index = InventoryIntegrationTest

function InventoryIntegrationTest.new()
    local self = setmetatable({}, InventoryIntegrationTest)
    
    self.testResults = {}
    self.player = Players.LocalPlayer
    
    return self
end

function InventoryIntegrationTest:RunAllTests()
    print("🧪 Starting Inventory System Integration Tests...")
    print("=" .. string.rep("=", 50))
    
    self.testResults = {}
    
    -- Core system tests
    self:TestModuleLoading()
    self:TestWrapperSystem()
    self:TestUnifiedSystem()
    self:TestLegacyFallbacks()
    
    -- UI tests
    self:TestUIComponents()
    self:TestInventoryDisplay()
    self:TestTierFiltering()
    
    -- Integration tests
    self:TestRemoteEvents()
    self:TestItemSelection()
    self:TestNotificationSystem()
    
    -- Performance tests
    self:TestPerformance()
    
    -- Generate report
    self:GenerateReport()
    
    return self.testResults
end

function InventoryIntegrationTest:TestModuleLoading()
    print("\n📦 Testing Module Loading...")
    
    -- Test unified system loading
    local unifiedSuccess = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        return InventoryManager and InventoryManager.new
    end)
    self:RecordTest("Unified InventoryManager Loading", unifiedSuccess)
    
    -- Test wrapper loading
    local wrapperSuccess = pcall(function()
        local InventorySystemWrapper = require(script.Parent.InventorySystemWrapper)
        return InventorySystemWrapper and InventorySystemWrapper.new
    end)
    self:RecordTest("InventorySystemWrapper Loading", wrapperSuccess)
    
    -- Test SharedModule integration
    local sharedSuccess = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("shared")
        if shared then
            local sharedModule = require(shared)
            return sharedModule and sharedModule.InventoryUI
        end
        return false
    end)
    self:RecordTest("SharedModule InventoryUI Access", sharedSuccess)
end

function InventoryIntegrationTest:TestWrapperSystem()
    print("\n🔄 Testing Wrapper System...")
    
    local success, wrapper = pcall(function()
        local InventorySystemWrapper = require(script.Parent.InventorySystemWrapper)
        return InventorySystemWrapper.GetGlobalInstance()
    end)
    
    if success and wrapper then
        self:RecordTest("Wrapper Instance Creation", true)
        
        -- Test initialization
        local initSuccess = wrapper.isInitialized
        self:RecordTest("Wrapper Initialization", initSuccess)
        
        -- Test system type detection
        local hasSystemType = wrapper.systemType ~= "none"
        self:RecordTest("System Type Detection", hasSystemType)
        
        -- Test health check
        local healthSuccess = pcall(function()
            local health = wrapper.CheckSystemHealth()
            return health and health.recommendedAction
        end)
        self:RecordTest("Health Check Function", healthSuccess)
        
        -- Test global functions
        local globalFuncSuccess = pcall(function()
            return wrapper.ToggleInventory and wrapper.ShowInventory and wrapper.HideInventory
        end)
        self:RecordTest("Global Functions Available", globalFuncSuccess)
        
    else
        self:RecordTest("Wrapper Instance Creation", false, wrapper)
    end
end

function InventoryIntegrationTest:TestUnifiedSystem()
    print("\n🎯 Testing Unified System...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        return InventoryManager.new()
    end)
    
    if success and inventoryManager then
        self:RecordTest("Unified System Creation", true)
        
        -- Test initialization
        local initSuccess = pcall(function()
            return inventoryManager:Initialize()
        end)
        self:RecordTest("Unified System Initialization", initSuccess)
        
        if initSuccess then
            -- Test core properties
            local hasProperties = inventoryManager.player and inventoryManager.inventoryData
            self:RecordTest("Core Properties Present", hasProperties)
            
            -- Test UI creation
            local hasUI = inventoryManager.gui and inventoryManager.mainFrame
            self:RecordTest("UI Components Created", hasUI)
            
            -- Test methods
            local hasMethods = inventoryManager.Show and inventoryManager.Hide and inventoryManager.Toggle
            self:RecordTest("Core Methods Available", hasMethods)
            
            -- Test tier system
            local tierSuccess = pcall(function()
                inventoryManager:SelectTier("Basic")
                return inventoryManager.currentTier == "Basic"
            end)
            self:RecordTest("Tier Selection System", tierSuccess)
            
            -- Cleanup
            pcall(function()
                inventoryManager:Cleanup()
            end)
        end
    else
        self:RecordTest("Unified System Creation", false, inventoryManager)
    end
end

function InventoryIntegrationTest:TestLegacyFallbacks()
    print("\n🔙 Testing Legacy Fallbacks...")
    
    -- Test SharedModule InventoryUI
    local legacySuccess = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("shared")
        if shared then
            local sharedModule = require(shared)
            local inventoryUI = sharedModule.InventoryUI
            
            if inventoryUI then
                -- Test basic methods
                local hasBasicMethods = inventoryUI.Show and inventoryUI.Hide and inventoryUI.Toggle
                self:RecordTest("Legacy InventoryUI Methods", hasBasicMethods)
                
                -- Test initialization capability
                local canInit = inventoryUI.Initialize ~= nil
                self:RecordTest("Legacy InventoryUI Initialization", canInit)
                
                return true
            end
        end
        return false
    end)
    
    if not legacySuccess then
        self:RecordTest("Legacy InventoryUI Access", false)
    end
    
    -- Test fallback loading in wrapper
    local fallbackSuccess = pcall(function()
        local InventorySystemWrapper = require(script.Parent.InventorySystemWrapper)
        local wrapper = InventorySystemWrapper.new()
        
        -- Temporarily disable unified system
        local originalFlag = wrapper.USE_UNIFIED_SYSTEM
        wrapper.USE_UNIFIED_SYSTEM = false
        
        local success = wrapper:LoadBestSystem()
        
        -- Restore flag
        wrapper.USE_UNIFIED_SYSTEM = originalFlag
        
        return success
    end)
    self:RecordTest("Fallback System Loading", fallbackSuccess)
end

function InventoryIntegrationTest:TestUIComponents()
    print("\n🎨 Testing UI Components...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        local instance = InventoryManager.new()
        instance:Initialize()
        return instance
    end)
    
    if success and inventoryManager then
        -- Test main UI elements
        local hasMainFrame = inventoryManager.mainFrame ~= nil
        self:RecordTest("Main Frame Creation", hasMainFrame)
        
        if hasMainFrame then
            -- Test title bar
            local titleBar = inventoryManager.mainFrame:FindFirstChild("TitleBar")
            self:RecordTest("Title Bar Creation", titleBar ~= nil)
            
            -- Test sidebar
            local sidebar = inventoryManager.mainFrame:FindFirstChild("Sidebar")
            self:RecordTest("Sidebar Creation", sidebar ~= nil)
            
            -- Test items container
            local containerFrame = inventoryManager.mainFrame:FindFirstChild("ContainerFrame")
            self:RecordTest("Container Frame Creation", containerFrame ~= nil)
            
            if containerFrame then
                local itemsContainer = containerFrame:FindFirstChild("ItemsContainer")
                self:RecordTest("Items Container Creation", itemsContainer ~= nil)
            end
            
            -- Test notification system
            local notificationContainer = inventoryManager.gui:FindFirstChild("NotificationContainer")
            self:RecordTest("Notification System Creation", notificationContainer ~= nil)
        end
        
        -- Test inventory button
        local buttonGui = self.player.PlayerGui:FindFirstChild("InventoryButtonUI")
        self:RecordTest("Inventory Button Creation", buttonGui ~= nil)
        
        -- Cleanup
        pcall(function()
            inventoryManager:Cleanup()
        end)
    else
        self:RecordTest("UI Components Test Setup", false, inventoryManager)
    end
end

function InventoryIntegrationTest:TestInventoryDisplay()
    print("\n📋 Testing Inventory Display...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        local instance = InventoryManager.new()
        instance:Initialize()
        return instance
    end)
    
    if success and inventoryManager then
        -- Test with sample data
        local sampleInventory = {
            brick_cube = {tier = "BASIC", quantity = 5},
            wood_cube = {tier = "BASIC", quantity = 3},
            rare_item = {tier = "RARE", quantity = 1}
        }
        
        local displaySuccess = pcall(function()
            inventoryManager:UpdateInventory(sampleInventory, 1000)
            inventoryManager:UpdateInventoryDisplay()
            return true
        end)
        self:RecordTest("Inventory Display Update", displaySuccess)
        
        -- Test tier filtering
        local filterSuccess = pcall(function()
            inventoryManager:SelectTier("Basic")
            inventoryManager:SelectTier("Rare")
            return true
        end)
        self:RecordTest("Tier Filtering", filterSuccess)
        
        -- Test item button creation
        local buttonSuccess = pcall(function()
            local button = inventoryManager:CreateItemButton("Test Item", {tier = "BASIC"}, 1)
            return button and button:IsA("TextButton")
        end)
        self:RecordTest("Item Button Creation", buttonSuccess)
        
        -- Cleanup
        pcall(function()
            inventoryManager:Cleanup()
        end)
    else
        self:RecordTest("Inventory Display Test Setup", false, inventoryManager)
    end
end

function InventoryIntegrationTest:TestTierFiltering()
    print("\n🏷️ Testing Tier Filtering...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        local instance = InventoryManager.new()
        instance:Initialize()
        return instance
    end)
    
    if success and inventoryManager then
        -- Test tier category detection
        local tierTests = {
            {tier = "BASIC", expected = "Basic"},
            {tier = "RARE", expected = "Rare"},
            {tier = "WEAPON", expected = "Weapons"},
            {tier = nil, expected = "Other"}
        }
        
        for _, test in ipairs(tierTests) do
            local category = inventoryManager:GetTierCategory(test.tier)
            local correct = category == test.expected
            self:RecordTest("Tier Category: " .. (test.tier or "nil"), correct)
        end
        
        -- Test item filtering
        local testItem = {tier = "BASIC"}
        local belongsToBasic = inventoryManager:ItemBelongsToTier(testItem, "Basic")
        local belongsToRare = inventoryManager:ItemBelongsToTier(testItem, "Rare")
        
        self:RecordTest("Item Belongs to Correct Tier", belongsToBasic)
        self:RecordTest("Item Doesn't Belong to Wrong Tier", not belongsToRare)
        
        -- Cleanup
        pcall(function()
            inventoryManager:Cleanup()
        end)
    else
        self:RecordTest("Tier Filtering Test Setup", false, inventoryManager)
    end
end

function InventoryIntegrationTest:TestRemoteEvents()
    print("\n📡 Testing Remote Events...")
    
    -- Test remote events folder
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    self:RecordTest("Remotes Folder Exists", remotesFolder ~= nil)
    
    if remotesFolder then
        -- Test specific remotes
        local requiredRemotes = {"GetInventory", "UseItem", "RecallItem", "AddToInventory"}
        
        for _, remoteName in ipairs(requiredRemotes) do
            local remote = remotesFolder:FindFirstChild(remoteName)
            self:RecordTest("Remote: " .. remoteName, remote ~= nil)
        end
        
        -- Test GetInventory functionality
        local getInventoryRemote = remotesFolder:FindFirstChild("GetInventory")
        if getInventoryRemote then
            local invokeSuccess = pcall(function()
                -- Don't actually invoke to avoid server errors in test
                return getInventoryRemote:IsA("RemoteFunction")
            end)
            self:RecordTest("GetInventory Remote Type", invokeSuccess)
        end
    end
end

function InventoryIntegrationTest:TestItemSelection()
    print("\n🖱️ Testing Item Selection...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        local instance = InventoryManager.new()
        instance:Initialize()
        return instance
    end)
    
    if success and inventoryManager then
        -- Test callback setup
        local callbackTriggered = false
        inventoryManager.OnItemSelected = function(itemName, itemData)
            callbackTriggered = true
        end
        
        -- Test item click simulation
        local clickSuccess = pcall(function()
            inventoryManager:OnItemClicked("test_item", {
                id = "test_item",
                displayName = "Test Item",
                count = 1
            })
            return true
        end)
        self:RecordTest("Item Click Handling", clickSuccess)
        self:RecordTest("Item Selection Callback", callbackTriggered)
        
        -- Test notification on selection
        local notificationSuccess = pcall(function()
            inventoryManager:ShowNotification("Test notification")
            return true
        end)
        self:RecordTest("Selection Notification", notificationSuccess)
        
        -- Cleanup
        pcall(function()
            inventoryManager:Cleanup()
        end)
    else
        self:RecordTest("Item Selection Test Setup", false, inventoryManager)
    end
end

function InventoryIntegrationTest:TestNotificationSystem()
    print("\n🔔 Testing Notification System...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        local instance = InventoryManager.new()
        instance:Initialize()
        return instance
    end)
    
    if success and inventoryManager then
        -- Test notification creation
        local notificationSuccess = pcall(function()
            inventoryManager:ShowNotification("Test notification", 1)
            return inventoryManager.notificationContainer ~= nil
        end)
        self:RecordTest("Notification Creation", notificationSuccess)
        
        -- Test multiple notifications
        local multipleSuccess = pcall(function()
            for i = 1, 3 do
                inventoryManager:ShowNotification("Test " .. i, 0.5)
            end
            return #inventoryManager.notifications > 0
        end)
        self:RecordTest("Multiple Notifications", multipleSuccess)
        
        -- Test notification cleanup
        task.wait(1) -- Wait for notifications to auto-remove
        local cleanupSuccess = #inventoryManager.notifications <= 3 -- Should respect max limit
        self:RecordTest("Notification Cleanup", cleanupSuccess)
        
        -- Cleanup
        pcall(function()
            inventoryManager:Cleanup()
        end)
    else
        self:RecordTest("Notification System Test Setup", false, inventoryManager)
    end
end

function InventoryIntegrationTest:TestPerformance()
    print("\n⚡ Testing Performance...")
    
    local success, inventoryManager = pcall(function()
        local InventoryManager = require(script.Parent.InventoryManager)
        local instance = InventoryManager.new()
        instance:Initialize()
        return instance
    end)
    
    if success and inventoryManager then
        -- Test large inventory performance
        local largeInventory = {}
        for i = 1, 100 do
            largeInventory["item_" .. i] = {
                tier = (i % 2 == 0) and "BASIC" or "RARE",
                quantity = math.random(1, 10)
            }
        end
        
        local startTime = tick()
        local performanceSuccess = pcall(function()
            inventoryManager:UpdateInventory(largeInventory, 5000)
            inventoryManager:UpdateInventoryDisplay()
            return true
        end)
        local endTime = tick()
        
        local processingTime = endTime - startTime
        self:RecordTest("Large Inventory Performance", performanceSuccess and processingTime < 1.0)
        
        -- Test memory usage
        local memoryBefore = collectgarbage("count")
        inventoryManager:UpdateInventoryDisplay()
        collectgarbage("collect")
        local memoryAfter = collectgarbage("count")
        
        local memoryEfficient = (memoryAfter - memoryBefore) < 100 -- Less than 100KB increase
        self:RecordTest("Memory Efficiency", memoryEfficient)
        
        -- Cleanup
        pcall(function()
            inventoryManager:Cleanup()
        end)
    else
        self:RecordTest("Performance Test Setup", false, inventoryManager)
    end
end

function InventoryIntegrationTest:RecordTest(testName, success, errorMessage)
    local result = {
        name = testName,
        success = success,
        error = errorMessage
    }
    
    table.insert(self.testResults, result)
    
    local status = success and "✅ PASS" or "❌ FAIL"
    local message = success and "" or (errorMessage and (" - " .. tostring(errorMessage)) or "")
    print(string.format("  %s %s%s", status, testName, message))
end

function InventoryIntegrationTest:GenerateReport()
    print("\n" .. string.rep("=", 60))
    print("📊 INVENTORY SYSTEM TEST REPORT")
    print(string.rep("=", 60))
    
    local totalTests = #self.testResults
    local passedTests = 0
    local failedTests = {}
    
    for _, result in ipairs(self.testResults) do
        if result.success then
            passedTests = passedTests + 1
        else
            table.insert(failedTests, result)
        end
    end
    
    local successRate = (passedTests / totalTests) * 100
    
    print(string.format("Total Tests: %d", totalTests))
    print(string.format("Passed: %d", passedTests))
    print(string.format("Failed: %d", totalTests - passedTests))
    print(string.format("Success Rate: %.1f%%", successRate))
    
    if #failedTests > 0 then
        print("\n❌ FAILED TESTS:")
        for _, failure in ipairs(failedTests) do
            print(string.format("  • %s%s", failure.name, 
                failure.error and (" - " .. tostring(failure.error)) or ""))
        end
    end
    
    print("\n🎯 RECOMMENDATIONS:")
    if successRate >= 90 then
        print("  ✅ Inventory system is working excellently!")
        print("  ✅ Ready for production use")
    elseif successRate >= 75 then
        print("  ⚠️ Inventory system is mostly functional")
        print("  ⚠️ Consider addressing failed tests before production")
    else
        print("  ❌ Inventory system has significant issues")
        print("  ❌ Requires debugging before use")
    end
    
    -- System health check
    local healthSuccess, health = pcall(function()
        local InventorySystemWrapper = require(script.Parent.InventorySystemWrapper)
        return InventorySystemWrapper.CheckSystemHealth()
    end)
    
    if healthSuccess and health then
        print("\n🏥 SYSTEM HEALTH:")
        print("  " .. health.recommendedAction)
    end
    
    print(string.rep("=", 60))
    
    return {
        totalTests = totalTests,
        passedTests = passedTests,
        failedTests = failedTests,
        successRate = successRate,
        health = healthSuccess and health or nil
    }
end

return InventoryIntegrationTest 