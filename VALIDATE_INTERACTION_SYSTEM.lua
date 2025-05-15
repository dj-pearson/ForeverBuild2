-- Test validation for the updated InteractionSystemModule
print("=== INTERACTION SYSTEM VALIDATION - " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

-- Make sure we're running as a client
if not RunService:IsClient() then
    error("This test must be run from a LocalScript or in Play mode.")
    return
end

---------------------------
-- SETUP TEST ENVIRONMENT
---------------------------

-- Helper function to create test objects
local function setupTestEnvironment()
    print("Setting up test environment...")
    
    -- Create Main folder if it doesn't exist
    local mainFolder = workspace:FindFirstChild("Main")
    if not mainFolder then
        mainFolder = Instance.new("Folder")
        mainFolder.Name = "Main"
        mainFolder.Parent = workspace
        print("- Created Main folder")
    end
    
    -- Create Board in Main folder
    local board = mainFolder:FindFirstChild("Board") 
    if not board then
        board = Instance.new("Part")
        board.Name = "Board"
        board.Size = Vector3.new(4, 3, 0.5)
        board.Position = Vector3.new(0, 5, 5)
        board.Anchored = true
        board.BrickColor = BrickColor.new("Bright blue")
        board.Parent = mainFolder
        print("- Created Board in Main folder")
    end
    
    -- Create Items folder if it doesn't exist
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        itemsFolder = Instance.new("Folder")
        itemsFolder.Name = "Items"
        itemsFolder.Parent = workspace
        print("- Created Items folder")
    end
    
    -- Create a shop item
    local shopItem = itemsFolder:FindFirstChild("TestItem")
    if not shopItem then
        shopItem = Instance.new("Part")
        shopItem.Name = "TestItem"
        shopItem.Size = Vector3.new(2, 2, 2)
        shopItem.Position = Vector3.new(5, 5, 0)
        shopItem.Anchored = true
        shopItem.BrickColor = BrickColor.new("Bright green")
        shopItem.Parent = itemsFolder
        print("- Created TestItem in Items folder")
    end
    
    -- Create a placed item with item attribute
    local placedItem = workspace:FindFirstChild("PlacedTestItem")
    if not placedItem then
        placedItem = Instance.new("Model")
        placedItem.Name = "PlacedTestItem"
        placedItem:SetAttribute("item", true)
        
        local part = Instance.new("Part")
        part.Name = "MainPart"
        part.Size = Vector3.new(1, 1, 1)
        part.Position = Vector3.new(-5, 5, 0)
        part.Anchored = true
        part.BrickColor = BrickColor.new("Really red")
        part.Parent = placedItem
        
        placedItem.PrimaryPart = part
        placedItem.Parent = workspace
        print("- Created PlacedTestItem with item attribute")
    end
    
    print("Test environment setup complete!")
end

---------------------------
-- VALIDATION FUNCTIONS
---------------------------

-- Test the GetPlacedItemFromPart function
local function testGetPlacedItemFromPart(interactionSystem)
    print("\nTesting GetPlacedItemFromPart function...")
    
    -- First, test with a part from the Main folder (Board)
    local mainFolder = workspace:FindFirstChild("Main")
    if not mainFolder then
        print("❌ ERROR: Main folder not found")
        return false
    end
    
    local board = mainFolder:FindFirstChild("Board")
    if not board then
        print("❌ ERROR: Board not found in Main folder")
        return false
    end
    
    local result = interactionSystem:GetPlacedItemFromPart(board)
    if not result then
        print("❌ ERROR: GetPlacedItemFromPart failed to recognize Board in Main folder")
        return false
    else
        print("✓ Successfully recognized Board in Main folder:")
        print("  - ID: " .. result.id)
        print("  - Model: " .. result.model:GetFullName())
    end
    
    -- Test with a placed item that has the item attribute
    local placedItem = workspace:FindFirstChild("PlacedTestItem")
    if not placedItem then
        print("❌ ERROR: PlacedTestItem not found")
        return false
    end
    
    local part = placedItem:FindFirstChild("MainPart")
    if not part then
        print("❌ ERROR: MainPart not found in PlacedTestItem")
        return false
    end
    
    result = interactionSystem:GetPlacedItemFromPart(part)
    if not result then
        print("❌ ERROR: GetPlacedItemFromPart failed to recognize PlacedTestItem")
        return false
    else
        print("✓ Successfully recognized PlacedTestItem:")
        print("  - ID: " .. result.id)
        print("  - Model: " .. result.model:GetFullName())
    end
    
    print("GetPlacedItemFromPart validation completed successfully!")
    return true
end

-- Test the remote events
local function testRemoteEvents(interactionSystem)
    print("\nTesting remote events...")
    
    if not interactionSystem.remoteEvents then
        print("❌ ERROR: No remoteEvents field found in InteractionSystem")
        return false
    end
    
    -- Check for required remote events
    local requiredEvents = {
        "PickupItem",
        "InteractWithItem",
        "InteractWithMain"  -- This is the key one we added
    }
    
    local allFound = true
    for _, eventName in ipairs(requiredEvents) do
        local event = interactionSystem.remoteEvents:FindFirstChild(eventName)
        if not event then
            print("❌ ERROR: Required remote event not found: " .. eventName)
            allFound = false
        else
            print("✓ Found remote event: " .. eventName)
        end
    end
    
    if not allFound then
        print("Some required remote events are missing!")
        return false
    end
    
    print("Remote events validation completed successfully!")
    return true
end

-- Test the AttemptInteraction function
local function testAttemptInteraction(interactionSystem)
    print("\nTesting AttemptInteraction functionality...")
    
    -- Create a mock function to track calls
    local originalFireServer = nil
    local fireServerCalls = {}
    
    -- Setup mock for InteractWithMain event
    local interactWithMainEvent = interactionSystem.remoteEvents:FindFirstChild("InteractWithMain")
    if not interactWithMainEvent then
        print("❌ ERROR: InteractWithMain event not found")
        return false
    end
    
    -- Save original function and replace with mock
    originalFireServer = interactWithMainEvent.FireServer
    interactWithMainEvent.FireServer = function(self, ...)
        table.insert(fireServerCalls, {...})
        print("✓ FireServer called on InteractWithMain with args:", ...)
        -- Don't actually fire the event since we're just testing
    end
    
    -- Set current target to Board
    local mainFolder = workspace:FindFirstChild("Main")
    local board = mainFolder and mainFolder:FindFirstChild("Board")
    
    if not board then
        print("❌ ERROR: Board not found for testing")
        interactWithMainEvent.FireServer = originalFireServer
        return false
    end
    
    -- Set the current target to the Board
    interactionSystem.currentTarget = {
        id = board.Name,
        model = board
    }
    
    -- Now attempt interaction
    print("Attempting interaction with Board in Main folder...")
    interactionSystem:AttemptInteraction()
    
    -- Check if the event was fired correctly
    if #fireServerCalls == 0 then
        print("❌ ERROR: InteractWithMain.FireServer was not called")
        interactWithMainEvent.FireServer = originalFireServer
        return false
    end
    
    if fireServerCalls[1][1] ~= "Board" then
        print("❌ ERROR: InteractWithMain.FireServer called with wrong argument: " .. tostring(fireServerCalls[1][1]))
        interactWithMainEvent.FireServer = originalFireServer
        return false
    end
    
    -- Restore original function
    interactWithMainEvent.FireServer = originalFireServer
    
    print("AttemptInteraction validation completed successfully!")
    return true
end

---------------------------
-- MAIN TEST FUNCTION
---------------------------

local function runTests()
    -- Setup test environment
    setupTestEnvironment()
    
    -- Try to load the module
    print("\nAttempting to load InteractionSystemModule...")
    local InteractionSystemModule = nil
    
    local success, result = pcall(function()
        -- Try different possible paths
        local paths = {
            ReplicatedStorage.src.client.interaction.InteractionSystemModule,
            game.ReplicatedStorage.src.client.interaction.InteractionSystemModule
        }
        
        for _, path in ipairs(paths) do
            if path then
                return require(path)
            end
        end
        
        error("InteractionSystemModule not found in expected paths")
    end)
    
    if not success then
        print("❌ ERROR loading module: " .. tostring(result))
        return
    end
    
    InteractionSystemModule = result
    print("✓ Successfully loaded InteractionSystemModule")
    
    -- Create an instance
    local interactionSystem = InteractionSystemModule.new()
    if not interactionSystem then
        print("❌ ERROR: InteractionSystemModule.new() returned nil")
        return
    end
    
    print("✓ Successfully created InteractionSystem instance")
    
    -- Initialize it
    success = interactionSystem:Initialize()
    if not success then
        print("❌ ERROR: InteractionSystem:Initialize() failed")
        return
    end
    
    print("✓ Successfully initialized InteractionSystem")
    
    -- Run tests
    local placedItemTest = testGetPlacedItemFromPart(interactionSystem)
    local remoteEventsTest = testRemoteEvents(interactionSystem)
    local interactionTest = testAttemptInteraction(interactionSystem)
    
    -- Report overall results
    print("\n=== TEST RESULTS ===")
    print("GetPlacedItemFromPart test: " .. (placedItemTest and "PASSED" or "FAILED"))
    print("Remote events test: " .. (remoteEventsTest and "PASSED" or "FAILED"))
    print("AttemptInteraction test: " .. (interactionTest and "PASSED" or "FAILED"))
    
    local allPassed = placedItemTest and remoteEventsTest and interactionTest
    print("\nOVERALL RESULT: " .. (allPassed and "ALL TESTS PASSED! ✓" or "SOME TESTS FAILED ❌"))
    
    -- Cleanup interactionSystem
    interactionSystem:Cleanup()
    print("\nTest completed and resources cleaned up")
end

-- Run the tests
runTests()
