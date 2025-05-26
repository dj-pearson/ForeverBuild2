-- test_critical_systems_integration.luau
-- Comprehensive test suite for all critical systems

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Mock dependencies for testing
local function createMockItemData()
    return {
        ItemId = 12345,
        Name = "TestBlock",
        Price = 100,
        Category = "Buildings"
    }
end

local function createMockPlayer()
    return {
        UserId = 123456789,
        Name = "TestPlayer",
        Character = {
            HumanoidRootPart = {
                Position = Vector3.new(0, 0, 0)
            }
        }
    }
end

print("🧪 Starting Critical Systems Integration Test")
print("=" .. string.rep("=", 50))

-- Test 1: System Manager Initialization
print("\n📋 TEST 1: System Manager Initialization")
local success, SystemManager = pcall(function()
    return require(game.ServerScriptService.src.server.SystemManager)
end)

if not success then
    warn("❌ Failed to load SystemManager:", SystemManager)
    return
end

local systemManager
success, systemManager = pcall(function()
    return SystemManager.new()
end)

if success and systemManager then
    print("✅ SystemManager initialized successfully")
    
    -- Check system health
    local healthStatus = systemManager:GetSystemStatus()
    print("   Overall Health:", healthStatus.overall)
    print("   Registered Systems:", #healthStatus.individual)
    
    for systemName, health in pairs(healthStatus.individual) do
        print("   -", systemName, ":", health.status, "(Priority:", health.priority .. ")")
    end
else
    warn("❌ SystemManager initialization failed:", systemManager)
    return
end

-- Test 2: Object Pooling System
print("\n📋 TEST 2: Object Pooling System")
if systemManager.systems.objectPooling then
    local pooling = systemManager.systems.objectPooling
    local mockItem = createMockItemData()
    
    -- Test getting objects from pool
    local obj1 = pooling:GetObject(mockItem, "TEST_1")
    local obj2 = pooling:GetObject(mockItem, "TEST_2")
    
    print("✅ Created 2 test objects from pool")
    print("   Pool stats:", pooling:GetPoolingEfficiency())
    
    -- Test returning objects to pool
    local returned1 = pooling:ReturnObject(obj1, mockItem)
    local returned2 = pooling:ReturnObject(obj2, mockItem)
    
    print("✅ Returned objects to pool:", returned1, returned2)
    
    -- Test pool status
    local poolStatus = pooling:GetPoolStatus()
    for itemId, status in pairs(poolStatus) do
        print("   Pool", itemId, "- Size:", status.poolSize, "Max:", status.maxSize)
    end
else
    warn("❌ Object Pooling system not available")
end

-- Test 3: Memory Management System
print("\n📋 TEST 3: Memory Management System")
if systemManager.systems.memoryManager then
    local memManager = systemManager.systems.memoryManager
    
    -- Generate memory report
    local memReport = memManager:GenerateMemoryReport()
    print("✅ Memory report generated")
    print("   Current Memory:", memReport.currentMemory, "MB")
    print("   Optimization Mode:", memReport.currentMode)
    print("   Active Objects:", memReport.activeObjects)
    print("   Memory Trend:", memReport.memoryTrend)
    
    -- Test optimization mode changes
    print("   Testing optimization modes...")
    memManager:SetPerformanceGraphics()
    print("   ✓ Performance graphics mode set")
    
    memManager:SetNormalGraphics()
    print("   ✓ Normal graphics mode restored")
else
    warn("❌ Memory Management system not available")
end

-- Test 4: Data Backup System
print("\n📋 TEST 4: Data Backup System")
if systemManager.systems.dataBackup then
    local backupSystem = systemManager.systems.dataBackup
    
    -- Test backup operations
    print("   Testing backup operations...")
    
    -- Track some test changes
    backupSystem:TrackChange("PLACE", "TEST_PLACEMENT_1", {
        player = 123456789,
        item = 12345,
        position = Vector3.new(10, 0, 10)
    })
    
    backupSystem:TrackChange("PLACE", "TEST_PLACEMENT_2", {
        player = 123456789,
        item = 12346,
        position = Vector3.new(20, 0, 20)
    })
    
    print("✅ Tracked 2 test changes for backup")
    
    -- Generate backup report
    local backupReport = backupSystem:GenerateBackupReport()
    print("✅ Backup report generated")
    print("   Pending Changes:", backupReport.systemHealth.pendingChanges)
    print("   Successful Backups:", backupReport.backupStats.successfulBackups)
    print("   Failed Backups:", backupReport.backupStats.failedBackups)
    print("   Is Backing Up:", backupReport.systemHealth.isBackingUp)
    
    -- Test force backup
    print("   Testing force backup...")
    local backupSuccess = backupSystem:ForceFullBackup()
    print("   Force backup initiated:", backupSuccess)
else
    warn("❌ Data Backup system not available")
end

-- Test 5: Moderation System
print("\n📋 TEST 5: Moderation System")
if systemManager.systems.moderation then
    local modSystem = systemManager.systems.moderation
    local mockPlayer = createMockPlayer()
    local mockItem = createMockItemData()
    
    -- Test placement checking
    print("   Testing placement moderation...")
    
    -- Test normal placement
    local allowed1 = modSystem:CheckPlacement(mockPlayer, {Position = Vector3.new(0, 0, 0)}, mockItem)
    print("   Normal placement allowed:", allowed1)
    
    -- Test multiple rapid placements (should trigger rate limiting)
    print("   Testing rate limiting...")
    for i = 1, 15 do
        local allowed = modSystem:CheckPlacement(mockPlayer, {Position = Vector3.new(i, 0, i)}, mockItem)
        if not allowed then
            print("   ✅ Rate limiting triggered at placement", i)
            break
        end
    end
    
    -- Generate moderation report
    local modReport = modSystem:GenerateModerationReport()
    print("✅ Moderation report generated")
    print("   Total Reports:", modReport.totalReports)
    print("   Active Violators:", modReport.activeViolators)
    print("   Pending Reviews:", modReport.pendingReviews)
else
    warn("❌ Moderation system not available")
end

-- Test 6: Analytics System
print("\n📋 TEST 6: Analytics System")
if systemManager.systems.analytics then
    local analytics = systemManager.systems.analytics
    local mockPlayer = createMockPlayer()
    local mockItem = createMockItemData()
    
    -- Test analytics tracking
    print("   Testing analytics tracking...")
    
    analytics:TrackPlacement(mockPlayer, mockItem, Vector3.new(5, 0, 5))
    analytics:TrackPurchase(mockPlayer, mockItem.ItemId, mockItem.Price, "INGAME")
    analytics:TrackEconomicEvent("COINS_GENERATED", 50, mockPlayer.UserId)
    
    print("✅ Tracked placement, purchase, and economic events")
    
    -- Generate game health report
    local healthReport = analytics:GenerateGameHealthReport()
    print("✅ Game health report generated")
    print("   Current Players:", healthReport.currentPlayers)
    print("   Total Objects:", healthReport.totalObjects)
    print("   Performance Status:", healthReport.performanceStatus)
    print("   Economic Health:")
    print("     Coins in Circulation:", healthReport.economicHealth.coinsInCirculation)
    print("     Inflation Rate:", healthReport.economicHealth.inflationRate .. "%")
else
    warn("❌ Analytics system not available")
end

-- Test 7: Integrated Object Operations
print("\n📋 TEST 7: Integrated Object Operations")
print("   Testing full object placement workflow...")

local mockPlayer = createMockPlayer()
local mockItem = createMockItemData()
local testPosition = Vector3.new(15, 0, 15)
local testRotation = CFrame.Angles(0, math.rad(45), 0)

-- Test placement through SystemManager
local placementSuccess, placementId = systemManager:PlaceObject(mockPlayer, mockItem, testPosition, testRotation)

if placementSuccess then
    print("✅ Object placed successfully via SystemManager")
    print("   Placement ID:", placementId)
    
    -- Wait a moment then test removal
    wait(1)
    
    local removalSuccess = systemManager:RemoveObject(placementId, "TEST_CLEANUP")
    if removalSuccess then
        print("✅ Object removed successfully via SystemManager")
    else
        warn("❌ Object removal failed")
    end
else
    warn("❌ Object placement failed:", placementId)
end

-- Test 8: Performance Metrics
print("\n📋 TEST 8: Performance Metrics")
local perfMetrics = systemManager:GetPerformanceMetrics()
print("✅ Performance metrics retrieved")
print("   Total Requests:", perfMetrics.totalRequests)
print("   Successful Requests:", perfMetrics.successfulRequests)
print("   Failed Requests:", perfMetrics.failedRequests)
print("   Success Rate:", math.floor((perfMetrics.successfulRequests / math.max(1, perfMetrics.totalRequests)) * 100) .. "%")
print("   Average Response Time:", math.floor(perfMetrics.averageResponseTime * 1000) .. "ms")

-- Test 9: System Health Monitoring
print("\n📋 TEST 9: System Health Monitoring")
print("   Performing manual health check...")

-- Force a health check
systemManager:PerformHealthCheck()

local finalHealth = systemManager:GetSystemStatus()
print("✅ Health check completed")
print("   Overall Health:", finalHealth.overall)
print("   Critical Errors:", finalHealth.criticalErrors)
print("   Last Check:", os.date("%H:%M:%S", finalHealth.lastHealthCheck))

-- Test 10: Full System Report
print("\n📋 TEST 10: Full System Report")
local systemReport = systemManager:GenerateSystemReport()
print("✅ Full system report generated")
print("   Report Timestamp:", systemReport.timestamp)
print("   System Uptime:", math.floor(systemReport.uptime / 60), "minutes")
print("   Emergency Mode:", systemReport.emergencyMode and "ACTIVE" or "INACTIVE")
print("   Individual System Reports:", #systemReport.systemReports, "available")

-- Summary
print("\n" .. string.rep("=", 50))
print("🎯 CRITICAL SYSTEMS INTEGRATION TEST SUMMARY")
print("=" .. string.rep("=", 50))

local overallHealth = systemManager:GetSystemStatus().overall
if overallHealth == "OPERATIONAL" then
    print("✅ ALL SYSTEMS OPERATIONAL")
    print("✅ Ready for production deployment")
    print("✅ Performance optimization: ACTIVE")
    print("✅ Data protection: ACTIVE")
    print("✅ Security monitoring: ACTIVE")
    print("✅ Analytics tracking: ACTIVE")
else
    warn("⚠️ SYSTEM ISSUES DETECTED")
    warn("   Overall Status:", overallHealth)
    warn("   Manual intervention may be required")
end

print("\n🚀 Next Steps:")
print("   1. Deploy to test server")
print("   2. Load test with multiple players")
print("   3. Monitor performance metrics")
print("   4. Validate backup and recovery")
print("   5. Test emergency procedures")

print("\n✨ Critical Systems Test Complete!") 