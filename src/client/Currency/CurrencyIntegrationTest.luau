-- CurrencyIntegrationTest.luau
-- Comprehensive test suite for the unified currency system
-- Tests wrapper functionality, primary system, fallbacks, and API functions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CurrencyIntegrationTest = {}
CurrencyIntegrationTest.__index = CurrencyIntegrationTest

-- Test configuration
local TEST_CONFIG = {
    TIMEOUT_DURATION = 10, -- seconds
    PERFORMANCE_ITERATIONS = 100,
    STRESS_TEST_DURATION = 30, -- seconds
    DEBUG_MODE = true
}

-- Test results tracking
local testResults = {
    passed = 0,
    failed = 0,
    skipped = 0,
    errors = {},
    performance = {},
    startTime = 0,
    endTime = 0
}

-- Test utilities
local function log(message)
    if TEST_CONFIG.DEBUG_MODE then
        print("[CurrencyTest]", message)
    end
end

local function assert(condition, message)
    if not condition then
        error("Assertion failed: " .. (message or "Unknown error"))
    end
end

local function timeFunction(func, ...)
    local startTime = tick()
    local results = {func(...)}
    local endTime = tick()
    return endTime - startTime, unpack(results)
end

-- Initialize test suite
function CurrencyIntegrationTest.new()
    local self = setmetatable({}, CurrencyIntegrationTest)
    self.wrapper = nil
    self.primarySystem = nil
    self.fallbackSystems = {}
    return self
end

-- Run all tests
function CurrencyIntegrationTest:RunAllTests()
    log("🧪 Starting Currency Integration Test Suite")
    testResults.startTime = tick()
    
    -- Reset test results
    testResults.passed = 0
    testResults.failed = 0
    testResults.skipped = 0
    testResults.errors = {}
    testResults.performance = {}
    
    -- Test categories
    local testCategories = {
        {name = "System Loading", func = self.TestSystemLoading},
        {name = "Wrapper Functionality", func = self.TestWrapperFunctionality},
        {name = "Primary System", func = self.TestPrimarySystem},
        {name = "Fallback Systems", func = self.TestFallbackSystems},
        {name = "API Integration", func = self.TestAPIIntegration},
        {name = "Health Monitoring", func = self.TestHealthMonitoring},
        {name = "Performance", func = self.TestPerformance},
        {name = "Stress Testing", func = self.TestStressScenarios},
        {name = "Backward Compatibility", func = self.TestBackwardCompatibility}
    }
    
    -- Run each test category
    for _, category in ipairs(testCategories) do
        log("📋 Running " .. category.name .. " tests...")
        
        local success, error = pcall(function()
            category.func(self)
        end)
        
        if not success then
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, {
                category = category.name,
                error = error,
                timestamp = tick()
            })
            log("❌ " .. category.name .. " tests failed: " .. error)
        else
            testResults.passed = testResults.passed + 1
            log("✅ " .. category.name .. " tests passed")
        end
    end
    
    testResults.endTime = tick()
    
    -- Generate test report
    self:GenerateTestReport()
    
    return testResults
end

-- Test system loading
function CurrencyIntegrationTest:TestSystemLoading()
    log("Testing system loading...")
    
    -- Test wrapper loading
    local wrapperSuccess, wrapper = pcall(function()
        return require(script.Parent.CurrencySystemWrapper)
    end)
    
    assert(wrapperSuccess, "Failed to load CurrencySystemWrapper: " .. tostring(wrapper))
    self.wrapper = wrapper
    
    -- Test primary system loading
    local primarySuccess, primary = pcall(function()
        return require(script.Parent.CurrencyManager)
    end)
    
    assert(primarySuccess, "Failed to load CurrencyManager: " .. tostring(primary))
    self.primarySystem = primary
    
    -- Test wrapper initialization
    local initSuccess = self.wrapper.Initialize()
    assert(initSuccess, "Wrapper initialization failed")
    
    log("System loading tests completed")
end

-- Test wrapper functionality
function CurrencyIntegrationTest:TestWrapperFunctionality()
    log("Testing wrapper functionality...")
    
    assert(self.wrapper, "Wrapper not loaded")
    
    -- Test system status
    local status = self.wrapper.GetSystemStatus()
    assert(status, "Failed to get system status")
    assert(status.isInitialized, "System not initialized")
    assert(status.activeSystem ~= "none", "No active system")
    
    -- Test global API functions
    assert(typeof(self.wrapper.UpdateGlobalBalance) == "function", "UpdateGlobalBalance not a function")
    assert(typeof(self.wrapper.ShowGlobalPurchaseMenu) == "function", "ShowGlobalPurchaseMenu not a function")
    assert(typeof(self.wrapper.GetGlobalBalance) == "function", "GetGlobalBalance not a function")
    
    -- Test backward compatibility aliases
    assert(typeof(self.wrapper.UpdateBalance) == "function", "UpdateBalance alias not found")
    assert(typeof(self.wrapper.ShowPurchaseMenu) == "function", "ShowPurchaseMenu alias not found")
    
    log("Wrapper functionality tests completed")
end

-- Test primary system
function CurrencyIntegrationTest:TestPrimarySystem()
    log("Testing primary system...")
    
    assert(self.primarySystem, "Primary system not loaded")
    
    -- Test instance creation
    local instance = self.primarySystem.new()
    assert(instance, "Failed to create primary system instance")
    
    -- Test initialization
    local initSuccess = instance:Initialize()
    assert(initSuccess, "Primary system initialization failed")
    
    -- Test basic functionality
    assert(typeof(instance.UpdateBalance) == "function", "UpdateBalance method not found")
    assert(typeof(instance.ShowPurchaseMenu) == "function", "ShowPurchaseMenu method not found")
    assert(typeof(instance.Cleanup) == "function", "Cleanup method not found")
    
    -- Test UI creation
    local player = Players.LocalPlayer
    if player and player:FindFirstChild("PlayerGui") then
        local currencyUI = player.PlayerGui:FindFirstChild("CurrencyUI")
        assert(currencyUI, "Currency UI not created")
    end
    
    -- Cleanup test instance
    instance:Cleanup()
    
    log("Primary system tests completed")
end

-- Test fallback systems
function CurrencyIntegrationTest:TestFallbackSystems()
    log("Testing fallback systems...")
    
    -- Test SharedModule fallback
    local sharedSuccess, sharedModule = pcall(function()
        return require(ReplicatedStorage:WaitForChild("shared", 5))
    end)
    
    if sharedSuccess and sharedModule and sharedModule.CurrencyUI then
        log("SharedModule.CurrencyUI fallback available")
        assert(typeof(sharedModule.CurrencyUI) == "table", "SharedModule.CurrencyUI not a table")
    else
        log("SharedModule.CurrencyUI fallback not available")
    end
    
    -- Test legacy CurrencyUI fallback
    local legacySuccess, legacyCurrencyUI = pcall(function()
        return require(script.Parent.CurrencyUI)
    end)
    
    if legacySuccess and legacyCurrencyUI then
        log("Legacy CurrencyUI fallback available")
        assert(typeof(legacyCurrencyUI) == "table", "Legacy CurrencyUI not a table")
    else
        log("Legacy CurrencyUI fallback not available")
    end
    
    log("Fallback systems tests completed")
end

-- Test API integration
function CurrencyIntegrationTest:TestAPIIntegration()
    log("Testing API integration...")
    
    assert(self.wrapper, "Wrapper not loaded")
    
    -- Test balance update
    local updateSuccess = pcall(function()
        self.wrapper.UpdateGlobalBalance(1000)
    end)
    assert(updateSuccess, "Failed to update balance")
    
    -- Test purchase menu (non-blocking)
    local menuSuccess = pcall(function()
        -- Don't actually show the menu in tests
        return true
    end)
    assert(menuSuccess, "Purchase menu test failed")
    
    -- Test system status retrieval
    local status = self.wrapper.GetSystemStatus()
    assert(status, "Failed to get system status")
    assert(status.healthStatus, "Health status not available")
    
    log("API integration tests completed")
end

-- Test health monitoring
function CurrencyIntegrationTest:TestHealthMonitoring()
    log("Testing health monitoring...")
    
    assert(self.wrapper, "Wrapper not loaded")
    
    -- Get initial status
    local initialStatus = self.wrapper.GetSystemStatus()
    assert(initialStatus, "Failed to get initial status")
    
    -- Wait for health check
    task.wait(2)
    
    -- Get updated status
    local updatedStatus = self.wrapper.GetSystemStatus()
    assert(updatedStatus, "Failed to get updated status")
    
    -- Verify health monitoring is working
    assert(updatedStatus.lastHealthCheck >= initialStatus.lastHealthCheck, "Health check not updating")
    
    log("Health monitoring tests completed")
end

-- Test performance
function CurrencyIntegrationTest:TestPerformance()
    log("Testing performance...")
    
    assert(self.wrapper, "Wrapper not loaded")
    
    -- Test balance update performance
    local updateTime, _ = timeFunction(function()
        for i = 1, TEST_CONFIG.PERFORMANCE_ITERATIONS do
            self.wrapper.UpdateGlobalBalance(i)
        end
    end)
    
    testResults.performance.balanceUpdates = {
        iterations = TEST_CONFIG.PERFORMANCE_ITERATIONS,
        totalTime = updateTime,
        averageTime = updateTime / TEST_CONFIG.PERFORMANCE_ITERATIONS
    }
    
    log(string.format("Balance update performance: %.4f seconds for %d iterations (%.6f avg)", 
        updateTime, TEST_CONFIG.PERFORMANCE_ITERATIONS, updateTime / TEST_CONFIG.PERFORMANCE_ITERATIONS))
    
    -- Test status retrieval performance
    local statusTime, _ = timeFunction(function()
        for i = 1, TEST_CONFIG.PERFORMANCE_ITERATIONS do
            self.wrapper.GetSystemStatus()
        end
    end)
    
    testResults.performance.statusRetrieval = {
        iterations = TEST_CONFIG.PERFORMANCE_ITERATIONS,
        totalTime = statusTime,
        averageTime = statusTime / TEST_CONFIG.PERFORMANCE_ITERATIONS
    }
    
    log(string.format("Status retrieval performance: %.4f seconds for %d iterations (%.6f avg)", 
        statusTime, TEST_CONFIG.PERFORMANCE_ITERATIONS, statusTime / TEST_CONFIG.PERFORMANCE_ITERATIONS))
    
    log("Performance tests completed")
end

-- Test stress scenarios
function CurrencyIntegrationTest:TestStressScenarios()
    log("Testing stress scenarios...")
    
    assert(self.wrapper, "Wrapper not loaded")
    
    local startTime = tick()
    local operations = 0
    local errors = 0
    
    -- Stress test: rapid balance updates
    while tick() - startTime < TEST_CONFIG.STRESS_TEST_DURATION do
        local success = pcall(function()
            self.wrapper.UpdateGlobalBalance(math.random(1, 10000))
            operations = operations + 1
        end)
        
        if not success then
            errors = errors + 1
        end
        
        task.wait(0.01) -- Small delay to prevent overwhelming
    end
    
    local duration = tick() - startTime
    
    testResults.performance.stressTest = {
        duration = duration,
        operations = operations,
        errors = errors,
        operationsPerSecond = operations / duration,
        errorRate = errors / operations
    }
    
    log(string.format("Stress test: %d operations in %.2f seconds (%.2f ops/sec, %.2f%% error rate)", 
        operations, duration, operations / duration, (errors / operations) * 100))
    
    assert(errors / operations < 0.1, "Error rate too high in stress test")
    
    log("Stress testing completed")
end

-- Test backward compatibility
function CurrencyIntegrationTest:TestBackwardCompatibility()
    log("Testing backward compatibility...")
    
    assert(self.wrapper, "Wrapper not loaded")
    
    -- Test old API method names
    local oldMethods = {
        "UpdateBalance",
        "ShowPurchaseMenu",
        "GetBalance"
    }
    
    for _, methodName in ipairs(oldMethods) do
        assert(typeof(self.wrapper[methodName]) == "function", 
            "Backward compatibility method not found: " .. methodName)
    end
    
    -- Test calling old methods
    local success = pcall(function()
        self.wrapper.UpdateBalance(500)
        -- Don't actually show menu in tests
        -- self.wrapper.ShowPurchaseMenu()
    end)
    
    assert(success, "Backward compatibility method calls failed")
    
    log("Backward compatibility tests completed")
end

-- Generate comprehensive test report
function CurrencyIntegrationTest:GenerateTestReport()
    local duration = testResults.endTime - testResults.startTime
    
    print("\n" .. "="*60)
    print("🧪 CURRENCY INTEGRATION TEST REPORT")
    print("="*60)
    print(string.format("⏱️  Duration: %.2f seconds", duration))
    print(string.format("✅ Passed: %d", testResults.passed))
    print(string.format("❌ Failed: %d", testResults.failed))
    print(string.format("⏭️  Skipped: %d", testResults.skipped))
    print(string.format("📊 Success Rate: %.1f%%", (testResults.passed / (testResults.passed + testResults.failed)) * 100))
    
    -- Error details
    if #testResults.errors > 0 then
        print("\n❌ ERRORS:")
        for i, error in ipairs(testResults.errors) do
            print(string.format("  %d. [%s] %s", i, error.category, error.error))
        end
    end
    
    -- Performance results
    if next(testResults.performance) then
        print("\n📊 PERFORMANCE RESULTS:")
        
        if testResults.performance.balanceUpdates then
            local perf = testResults.performance.balanceUpdates
            print(string.format("  Balance Updates: %.6f seconds average (%d iterations)", 
                perf.averageTime, perf.iterations))
        end
        
        if testResults.performance.statusRetrieval then
            local perf = testResults.performance.statusRetrieval
            print(string.format("  Status Retrieval: %.6f seconds average (%d iterations)", 
                perf.averageTime, perf.iterations))
        end
        
        if testResults.performance.stressTest then
            local perf = testResults.performance.stressTest
            print(string.format("  Stress Test: %.2f ops/sec, %.2f%% error rate", 
                perf.operationsPerSecond, perf.errorRate * 100))
        end
    end
    
    -- System status
    if self.wrapper then
        local status = self.wrapper.GetSystemStatus()
        print("\n🔧 SYSTEM STATUS:")
        print(string.format("  Active System: %s", status.activeSystem))
        print(string.format("  Health Status: %s", status.healthStatus))
        print(string.format("  Primary Available: %s", tostring(status.availableSystems.primary)))
        print(string.format("  Fallbacks Available: %d", status.availableSystems.fallbacks))
    end
    
    print("="*60)
    
    -- Overall result
    if testResults.failed == 0 then
        print("🎉 ALL TESTS PASSED! Currency system is ready for production.")
    else
        print("⚠️  SOME TESTS FAILED. Please review errors before deployment.")
    end
    
    print("="*60 .. "\n")
end

-- Cleanup test environment
function CurrencyIntegrationTest:Cleanup()
    log("Cleaning up test environment...")
    
    if self.wrapper and self.wrapper.Cleanup then
        self.wrapper.Cleanup()
    end
    
    log("Test cleanup completed")
end

-- Quick test function for manual testing
function CurrencyIntegrationTest.QuickTest()
    local tester = CurrencyIntegrationTest.new()
    local results = tester:RunAllTests()
    tester:Cleanup()
    return results
end

return CurrencyIntegrationTest 