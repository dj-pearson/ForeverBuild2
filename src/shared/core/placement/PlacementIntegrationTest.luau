-- PlacementIntegrationTest.luau
-- Comprehensive integration test for the placement system
-- Tests both monolithic and modular implementations

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementIntegrationTest = {}

-- Test configuration
local TEST_CONFIG = {
    testItemId = "item_1",
    testPosition = Vector3.new(10, 5, 10),
    testRotation = {X = 0, Y = 45, Z = 0},
    timeoutSeconds = 10
}

function PlacementIntegrationTest:RunAllTests()
    print("=== PLACEMENT SYSTEM INTEGRATION TESTS ===")
    
    local results = {
        moduleLoading = false,
        remoteEvents = false,
        itemTemplates = false,
        placementFlow = false,
        serverClientSync = false
    }
    
    -- Test 1: Module Loading
    print("\n[TEST 1] Module Loading...")
    results.moduleLoading = self:TestModuleLoading()
    
    -- Test 2: Remote Events
    print("\n[TEST 2] Remote Events...")
    results.remoteEvents = self:TestRemoteEvents()
    
    -- Test 3: Item Templates
    print("\n[TEST 3] Item Templates...")
    results.itemTemplates = self:TestItemTemplates()
    
    -- Test 4: Placement Flow (Client only)
    if RunService:IsClient() then
        print("\n[TEST 4] Placement Flow...")
        results.placementFlow = self:TestPlacementFlow()
    end
    
    -- Test 5: Server-Client Sync (Server only)
    if RunService:IsServer() then
        print("\n[TEST 5] Server-Client Sync...")
        results.serverClientSync = self:TestServerClientSync()
    end
    
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
    return allPassed, results
end

function PlacementIntegrationTest:TestModuleLoading()
    local success = true
    
    -- Test PlacementManager loading
    local placementManagerSuccess, placementManager = pcall(function()
        return require(script.Parent.PlacementManager)
    end)
    
    if not placementManagerSuccess then
        warn("Failed to load PlacementManager:", placementManager)
        success = false
    else
        print("✅ PlacementManager loaded successfully")
        
        -- Test creating instance
        if placementManager and placementManager.new then
            local instanceSuccess, instance = pcall(function()
                return placementManager.new({Constants = {CURRENCY = {INGAME = "coins"}}})
            end)
            
            if not instanceSuccess then
                warn("Failed to create PlacementManager instance:", instance)
                success = false
            else
                print("✅ PlacementManager instance created successfully")
            end
        else
            warn("PlacementManager.new method not found")
            success = false
        end
    end
    
    -- Test PlacementUtils loading
    local utilsSuccess, utils = pcall(function()
        return require(script.Parent.Placement_Utils)
    end)
    
    if not utilsSuccess then
        warn("Failed to load Placement_Utils:", utils)
        success = false
    else
        print("✅ Placement_Utils loaded successfully")
    end
    
    return success
end

function PlacementIntegrationTest:TestRemoteEvents()
    local success = true
    
    -- Check if Remotes folder exists
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        if RunService:IsServer() then
            -- Server should create it
            remotesFolder = Instance.new("Folder")
            remotesFolder.Name = "Remotes"
            remotesFolder.Parent = ReplicatedStorage
            print("✅ Created Remotes folder on server")
        else
            warn("Remotes folder not found on client")
            return false
        end
    else
        print("✅ Remotes folder exists")
    end
    
    -- Check for required remote events
    local requiredEvents = {
        "RequestPlaceItem", "RequestRecallItem", "RequestMoveItem",
        "ItemPlaced", "ItemRecalled", "ItemUpdated", "ItemDeleted"
    }
    
    for _, eventName in ipairs(requiredEvents) do
        local event = remotesFolder:FindFirstChild(eventName)
        if not event then
            if RunService:IsServer() then
                -- Server should create missing events
                event = Instance.new("RemoteEvent")
                event.Name = eventName
                event.Parent = remotesFolder
                print("✅ Created missing remote event:", eventName)
            else
                warn("Missing remote event on client:", eventName)
                success = false
            end
        else
            print("✅ Remote event exists:", eventName)
        end
    end
    
    return success
end

function PlacementIntegrationTest:TestItemTemplates()
    local success = true
    
    -- Test template loading
    local placementManager = require(script.Parent.PlacementManager)
    local instance = placementManager.new({Constants = {CURRENCY = {INGAME = "coins"}}})
    
    if not instance.GetItemTemplate then
        warn("GetItemTemplate method not found")
        return false
    end
    
    -- Test getting a template
    local template = instance:GetItemTemplate(TEST_CONFIG.testItemId)
    if not template then
        warn("Failed to get template for:", TEST_CONFIG.testItemId)
        success = false
    else
        print("✅ Template retrieved for:", TEST_CONFIG.testItemId)
        
        -- Validate template
        if not (template:IsA("Model") or template:IsA("BasePart")) then
            warn("Template is not a Model or BasePart")
            success = false
        else
            print("✅ Template is valid type:", template.ClassName)
        end
    end
    
    return success
end

function PlacementIntegrationTest:TestPlacementFlow()
    if RunService:IsServer() then return true end -- Skip on server
    
    local success = true
    
    -- Test placement manager client methods
    local placementManager = require(script.Parent.PlacementManager)
    local instance = placementManager.new({Constants = {CURRENCY = {INGAME = "coins"}}})
    
    -- Test ShowItemInHand
    if instance.ShowItemInHand then
        local handSuccess = instance:ShowItemInHand(TEST_CONFIG.testItemId)
        if handSuccess then
            print("✅ ShowItemInHand succeeded")
            
            -- Clean up
            if instance.ClearItemFromHand then
                instance:ClearItemFromHand()
                print("✅ ClearItemFromHand succeeded")
            end
        else
            warn("ShowItemInHand failed")
            success = false
        end
    else
        warn("ShowItemInHand method not found")
        success = false
    end
    
    -- Test StartPlacing
    if instance.StartPlacing then
        local placingSuccess = instance:StartPlacing(TEST_CONFIG.testItemId)
        if placingSuccess then
            print("✅ StartPlacing succeeded")
            
            -- Clean up
            if instance.ResetPlacementState then
                instance:ResetPlacementState()
                print("✅ ResetPlacementState succeeded")
            end
        else
            warn("StartPlacing failed")
            success = false
        end
    else
        warn("StartPlacing method not found")
        success = false
    end
    
    return success
end

function PlacementIntegrationTest:TestServerClientSync()
    if RunService:IsClient() then return true end -- Skip on client
    
    local success = true
    
    -- Test server-side placement functionality
    local placementManager = require(script.Parent.PlacementManager)
    local instance = placementManager.new({Constants = {CURRENCY = {INGAME = "coins"}}})
    
    -- Test Initialize method
    if instance.Initialize then
        local initSuccess = instance:Initialize()
        if initSuccess then
            print("✅ Server Initialize succeeded")
        else
            warn("Server Initialize failed")
            success = false
        end
    else
        warn("Initialize method not found")
        success = false
    end
    
    -- Test world folder creation
    local worldFolder = game.Workspace:FindFirstChild("World_Items")
    if worldFolder then
        print("✅ World_Items folder exists")
        
        local placedFolder = worldFolder:FindFirstChild("Placed")
        if placedFolder then
            print("✅ Placed folder exists")
        else
            warn("Placed folder not found")
            success = false
        end
    else
        warn("World_Items folder not found")
        success = false
    end
    
    return success
end

-- Auto-run tests when required
if RunService:IsServer() then
    -- Run server tests after a delay
    task.spawn(function()
        task.wait(2) -- Wait for other systems to initialize
        PlacementIntegrationTest:RunAllTests()
    end)
elseif RunService:IsClient() then
    -- Run client tests when player is added
    local player = Players.LocalPlayer
    if player then
        task.spawn(function()
            task.wait(3) -- Wait for client to fully load
            PlacementIntegrationTest:RunAllTests()
        end)
    end
end

return PlacementIntegrationTest 