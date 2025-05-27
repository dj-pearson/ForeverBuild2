-- InteractionIntegrationTest.luau
-- Comprehensive integration test for the interaction system
-- Tests unified system, fallbacks, and integration points

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionIntegrationTest = {}

-- Test configuration
local TEST_CONFIG = {
    testItemName = "TestItem",
    testDistance = 5,
    timeoutSeconds = 10,
    debugMode = true
}

function InteractionIntegrationTest:RunAllTests()
    print("=== INTERACTION SYSTEM INTEGRATION TESTS ===")
    
    local results = {
        wrapperLoading = false,
        systemInitialization = false,
        remoteEvents = false,
        uiComponents = false,
        interactionFlow = false,
        fallbackSystems = false
    }
    
    -- Test 1: Wrapper Loading
    print("\n[TEST 1] Wrapper Loading...")
    results.wrapperLoading = self:TestWrapperLoading()
    
    -- Test 2: System Initialization
    print("\n[TEST 2] System Initialization...")
    results.systemInitialization = self:TestSystemInitialization()
    
    -- Test 3: Remote Events
    print("\n[TEST 3] Remote Events...")
    results.remoteEvents = self:TestRemoteEvents()
    
    -- Test 4: UI Components
    print("\n[TEST 4] UI Components...")
    results.uiComponents = self:TestUIComponents()
    
    -- Test 5: Interaction Flow
    print("\n[TEST 5] Interaction Flow...")
    results.interactionFlow = self:TestInteractionFlow()
    
    -- Test 6: Fallback Systems
    print("\n[TEST 6] Fallback Systems...")
    results.fallbackSystems = self:TestFallbackSystems()
    
    -- Print results
    print("\n=== TEST RESULTS ===")
    for testName, passed in pairs(results) do
        local status = passed and "✅ PASS" or "❌ FAIL"
        print(string.format("%s: %s", testName, status))
    end
    
    local allPassed = true
    for _, passed in pairs(results) do
        if not passed then allPassed = false; break end
    end
    
    print(string.format("\nOVERALL: %s", allPassed and "✅ ALL TESTS PASSED" or "❌ SOME TESTS FAILED"))
    
    -- Additional system health check
    self:PerformSystemHealthCheck()
    
    return allPassed, results
end

function InteractionIntegrationTest:TestWrapperLoading()
    local success = true
    
    -- Test wrapper loading
    local wrapperSuccess, wrapper = pcall(function()
        return require(script.Parent.InteractionSystemWrapper)
    end)
    
    if not wrapperSuccess then
        warn("Failed to load InteractionSystemWrapper:", wrapper)
        success = false
    else
        print("✅ InteractionSystemWrapper loaded successfully")
        
        -- Test wrapper instantiation
        local instanceSuccess, instance = pcall(function()
            return wrapper.new()
        end)
        
        if not instanceSuccess then
            warn("Failed to create wrapper instance:", instance)
            success = false
        else
            print("✅ Wrapper instance created successfully")
            
            -- Test system info
            if instance.GetSystemInfo then
                local info = instance:GetSystemInfo()
                print("✅ System info available:", info.selectedSystem)
            else
                warn("GetSystemInfo method not available")
                success = false
            end
            
            -- Cleanup
            if instance.Cleanup then
                instance:Cleanup()
            end
        end
    end
    
    return success
end

function InteractionIntegrationTest:TestSystemInitialization()
    local success = true
    
    -- Test unified system loading
    local unifiedSuccess, unifiedModule = pcall(function()
        return require(script.Parent.InteractionManager)
    end)
    
    if not unifiedSuccess then
        warn("Failed to load unified InteractionManager:", unifiedModule)
        success = false
    else
        print("✅ Unified InteractionManager loaded successfully")
        
        -- Test instance creation and initialization
        local instanceSuccess, instance = pcall(function()
            local inst = unifiedModule.new()
            local initResult = inst:Initialize()
            return inst, initResult
        end)
        
        if not instanceSuccess then
            warn("Failed to initialize unified system:", instance)
            success = false
        else
            local inst, initResult = instance, true -- Unpack if needed
            if initResult then
                print("✅ Unified system initialized successfully")
            else
                warn("Unified system initialization returned false")
                success = false
            end
            
            -- Cleanup
            if inst and inst.Cleanup then
                inst:Cleanup()
            end
        end
    end
    
    return success
end

function InteractionIntegrationTest:TestRemoteEvents()
    local success = true
    
    -- Check if Remotes folder exists
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        warn("Remotes folder not found")
        success = false
    else
        print("✅ Remotes folder exists")
        
        -- Check for required remote events
        local requiredRemotes = {
            "PurchaseItem", "InteractWithItem", "UseItem", "CollectItem"
        }
        
        local foundRemotes = 0
        for _, remoteName in ipairs(requiredRemotes) do
            local remote = remotesFolder:FindFirstChild(remoteName)
            if remote then
                foundRemotes = foundRemotes + 1
                print("✅ Remote found:", remoteName)
            else
                if TEST_CONFIG.debugMode then
                    warn("Remote not found:", remoteName)
                end
            end
        end
        
        if foundRemotes == 0 then
            warn("No required remotes found")
            success = false
        else
            print(string.format("✅ Found %d/%d required remotes", foundRemotes, #requiredRemotes))
        end
    end
    
    return success
end

function InteractionIntegrationTest:TestUIComponents()
    local success = true
    
    -- Test UI creation with unified system
    local uiSuccess, uiResult = pcall(function()
        local InteractionManager = require(script.Parent.InteractionManager)
        local instance = InteractionManager.new()
        
        -- Test UI component creation
        instance:CreateUIComponents()
        
        -- Verify billboard template exists
        if not instance.billboardTemplate then
            error("Billboard template not created")
        end
        
        -- Verify notification container exists
        if not instance.notificationContainer then
            error("Notification container not created")
        end
        
        -- Test notification system
        instance:ShowNotification("Test notification", 1)
        
        -- Cleanup
        instance:Cleanup()
        
        return true
    end)
    
    if not uiSuccess then
        warn("UI component test failed:", uiResult)
        success = false
    else
        print("✅ UI components created and tested successfully")
    end
    
    return success
end

function InteractionIntegrationTest:TestInteractionFlow()
    local success = true
    
    -- Test interaction detection and handling
    local flowSuccess, flowResult = pcall(function()
        local InteractionManager = require(script.Parent.InteractionManager)
        local instance = InteractionManager.new()
        instance:Initialize()
        
        -- Create a test interactable item
        local testItem = Instance.new("Part")
        testItem.Name = TEST_CONFIG.testItemName
        testItem.Size = Vector3.new(2, 2, 2)
        testItem.Position = Vector3.new(0, 5, 0)
        testItem.Anchored = true
        testItem:SetAttribute("Interactable", true)
        testItem:SetAttribute("InteractionType", "USE")
        testItem.Parent = workspace
        
        -- Test interactable detection
        local isInteractable = instance:IsInteractable(testItem)
        if not isInteractable then
            error("Test item not detected as interactable")
        end
        
        -- Test position detection
        local position = instance:GetInstancePosition(testItem)
        if not position then
            error("Could not get test item position")
        end
        
        -- Test interaction text generation
        local targetData = {instance = testItem, id = testItem.Name}
        local interactionText = instance:GetInteractionText(targetData)
        if not interactionText or interactionText == "" then
            error("Could not generate interaction text")
        end
        
        -- Cleanup
        testItem:Destroy()
        instance:Cleanup()
        
        return true
    end)
    
    if not flowSuccess then
        warn("Interaction flow test failed:", flowResult)
        success = false
    else
        print("✅ Interaction flow tested successfully")
    end
    
    return success
end

function InteractionIntegrationTest:TestFallbackSystems()
    local success = true
    
    -- Test that fallback systems can be loaded
    local fallbackModules = {
        "ItemInteractionClient",
        "InteractionSystemModule_enhanced",
        "InteractionSystemModule_emergency"
    }
    
    local workingFallbacks = 0
    
    for _, moduleName in ipairs(fallbackModules) do
        local moduleScript = script.Parent:FindFirstChild(moduleName)
        if moduleScript then
            local moduleSuccess, moduleResult = pcall(function()
                return require(moduleScript)
            end)
            
            if moduleSuccess and moduleResult then
                workingFallbacks = workingFallbacks + 1
                print("✅ Fallback system available:", moduleName)
                
                -- Test instantiation if possible
                if moduleResult.new then
                    local instSuccess, inst = pcall(function()
                        return moduleResult.new()
                    end)
                    
                    if instSuccess and inst then
                        print("  ✅ Can instantiate:", moduleName)
                        
                        -- Cleanup if possible
                        if inst.Cleanup then
                            pcall(function() inst:Cleanup() end)
                        end
                    end
                end
            else
                warn("Fallback system failed to load:", moduleName, moduleResult)
            end
        else
            if TEST_CONFIG.debugMode then
                warn("Fallback module not found:", moduleName)
            end
        end
    end
    
    if workingFallbacks == 0 then
        warn("No working fallback systems found")
        success = false
    else
        print(string.format("✅ %d fallback systems available", workingFallbacks))
    end
    
    return success
end

function InteractionIntegrationTest:PerformSystemHealthCheck()
    print("\n=== SYSTEM HEALTH CHECK ===")
    
    -- Use the wrapper's health check if available
    local wrapperSuccess, wrapper = pcall(function()
        return require(script.Parent.InteractionSystemWrapper)
    end)
    
    if wrapperSuccess and wrapper.CheckSystemHealth then
        local health = wrapper.CheckSystemHealth()
        
        print("Unified System Available:", health.unifiedAvailable and "✅" or "❌")
        print("Legacy Systems Available:", health.legacyAvailable and "✅" or "❌")
        print("Emergency System Available:", health.emergencyAvailable and "✅" or "❌")
        print("Recommendation:", health.recommendedAction)
    else
        warn("Could not perform automated health check")
    end
    
    -- Check global debug functions
    if _G.InteractionSystemDebug then
        print("✅ Global debug functions available")
        
        local currentSystem = _G.InteractionSystemDebug.GetCurrentSystem()
        if currentSystem and not currentSystem.error then
            print("Current System:", currentSystem.selectedSystem or "Unknown")
        end
    else
        warn("❌ Global debug functions not available")
    end
end

function InteractionIntegrationTest:CreateTestEnvironment()
    print("[InteractionIntegrationTest] Creating test environment...")
    
    -- Create test items in workspace
    local testFolder = workspace:FindFirstChild("InteractionTestItems")
    if testFolder then testFolder:Destroy() end
    
    testFolder = Instance.new("Folder")
    testFolder.Name = "InteractionTestItems"
    testFolder.Parent = workspace
    
    -- Create different types of test items
    local testItems = {
        {
            name = "PurchaseableItem",
            attributes = {Purchasable = true, Price = 100},
            interactionType = "purchase"
        },
        {
            name = "PickupItem", 
            attributes = {Interactable = true, InteractionType = "PICKUP"},
            interactionType = "pickup"
        },
        {
            name = "UseableItem",
            attributes = {Interactable = true, InteractionType = "USE"},
            interactionType = "use"
        }
    }
    
    for i, itemData in ipairs(testItems) do
        local item = Instance.new("Part")
        item.Name = itemData.name
        item.Size = Vector3.new(2, 2, 2)
        item.Position = Vector3.new(i * 5, 5, 0)
        item.Anchored = true
        item.BrickColor = BrickColor.new("Bright blue")
        
        for attrName, attrValue in pairs(itemData.attributes) do
            item:SetAttribute(attrName, attrValue)
        end
        
        item.Parent = testFolder
    end
    
    print("✅ Test environment created with", #testItems, "test items")
    return testFolder
end

function InteractionIntegrationTest:CleanupTestEnvironment()
    local testFolder = workspace:FindFirstChild("InteractionTestItems")
    if testFolder then
        testFolder:Destroy()
        print("✅ Test environment cleaned up")
    end
end

-- Auto-run tests when required (client-side only)
if RunService:IsClient() then
    local player = Players.LocalPlayer
    if player then
        task.spawn(function()
            task.wait(3) -- Wait for client to fully load
            InteractionIntegrationTest:RunAllTests()
        end)
    end
end

return InteractionIntegrationTest 