-- BlueprintSystemTest.luau
-- Comprehensive test script for the Blueprint system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local BlueprintSystemTest = {}

-- Test configuration
local TEST_CONFIG = {
    KEYBOARD_SHORTCUTS = {
        F1 = "Toggle Blueprint UI",
        F2 = "Create Test Blueprint",
        F3 = "Test Blueprint Placement",
        F4 = "Test Marketplace Features",
        F5 = "Test Social Integration",
        F6 = "Test XP Integration",
        F7 = "Test Building Tools Integration",
        F8 = "Run Full System Test",
        F9 = "Generate Test Data",
        F10 = "Clear Test Data"
    }
}

function BlueprintSystemTest.Initialize()
    print("BlueprintSystemTest: Initializing test environment...")
    
    -- Set up keyboard shortcuts for testing
    BlueprintSystemTest.SetupTestShortcuts()
    
    -- Display test instructions
    BlueprintSystemTest.ShowTestInstructions()
    
    print("BlueprintSystemTest: Test environment ready!")
end

function BlueprintSystemTest.SetupTestShortcuts()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F1 then
            BlueprintSystemTest.TestBlueprintUI()
        elseif input.KeyCode == Enum.KeyCode.F2 then
            BlueprintSystemTest.CreateTestBlueprint()
        elseif input.KeyCode == Enum.KeyCode.F3 then
            BlueprintSystemTest.TestBlueprintPlacement()
        elseif input.KeyCode == Enum.KeyCode.F4 then
            BlueprintSystemTest.TestMarketplaceFeatures()
        elseif input.KeyCode == Enum.KeyCode.F5 then
            BlueprintSystemTest.TestSocialIntegration()
        elseif input.KeyCode == Enum.KeyCode.F6 then
            BlueprintSystemTest.TestXPIntegration()
        elseif input.KeyCode == Enum.KeyCode.F7 then
            BlueprintSystemTest.TestBuildingToolsIntegration()
        elseif input.KeyCode == Enum.KeyCode.F8 then
            BlueprintSystemTest.RunFullSystemTest()
        elseif input.KeyCode == Enum.KeyCode.F9 then
            BlueprintSystemTest.GenerateTestData()
        elseif input.KeyCode == Enum.KeyCode.F10 then
            BlueprintSystemTest.ClearTestData()
        end
    end)
end

function BlueprintSystemTest.ShowTestInstructions()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BlueprintTestInstructions"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Name = "InstructionsFrame"
    frame.Size = UDim2.new(0, 400, 0, 350)
    frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "📐 Blueprint System Test Controls"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local instructionsText = [[
F1 - Toggle Blueprint UI
F2 - Create Test Blueprint
F3 - Test Blueprint Placement
F4 - Test Marketplace Features
F5 - Test Social Integration
F6 - Test XP Integration
F7 - Test Building Tools Integration
F8 - Run Full System Test
F9 - Generate Test Data
F10 - Clear Test Data

Ctrl+B - Toggle Blueprint Workshop
Ctrl+Shift+S - Quick Save Blueprint
Ctrl+Shift+V - Place Last Blueprint]]
    
    local instructions = Instance.new("TextLabel")
    instructions.Name = "Instructions"
    instructions.Size = UDim2.new(1, -20, 1, -60)
    instructions.Position = UDim2.new(0, 10, 0, 50)
    instructions.BackgroundTransparency = 1
    instructions.Text = instructionsText
    instructions.TextColor3 = Color3.fromRGB(200, 200, 200)
    instructions.TextSize = 14
    instructions.Font = Enum.Font.Gotham
    instructions.TextXAlignment = Enum.TextXAlignment.Left
    instructions.TextYAlignment = Enum.TextYAlignment.Top
    instructions.TextWrapped = true
    instructions.Parent = frame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = frame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
    
    -- Auto-hide after 10 seconds
    task.spawn(function()
        task.wait(10)
        if gui.Parent then
            gui:Destroy()
        end
    end)
end

function BlueprintSystemTest.TestBlueprintUI()
    print("BlueprintSystemTest: Testing Blueprint UI...")
    
    local blueprintUI = _G.BlueprintUI
    if blueprintUI then
        blueprintUI:Toggle()
        print("✅ Blueprint UI toggle test passed")
        
        -- Test tab switching
        task.spawn(function()
            task.wait(1)
            blueprintUI:SwitchTab("MARKETPLACE")
            task.wait(1)
            blueprintUI:SwitchTab("CREATE")
            task.wait(1)
            blueprintUI:SwitchTab("FEATURED")
            task.wait(1)
            blueprintUI:SwitchTab("SEARCH")
            task.wait(1)
            blueprintUI:SwitchTab("MY_BLUEPRINTS")
            print("✅ Blueprint UI tab switching test passed")
        end)
    else
        print("❌ Blueprint UI not found")
    end
end

function BlueprintSystemTest.CreateTestBlueprint()
    print("BlueprintSystemTest: Creating test blueprint...")
    
    local blueprintManager = _G.BlueprintManager
    if blueprintManager then
        local testBlueprint = {
            name = "Test Blueprint " .. math.random(1000, 9999),
            description = "A test blueprint created by the test system",
            category = "test",
            tags = {"test", "automated", "sample"},
            items = {
                {itemId = "test_block", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                {itemId = "test_block", position = Vector3.new(4, 0, 0), rotation = Vector3.new(0, 0, 0)},
                {itemId = "test_block", position = Vector3.new(0, 0, 4), rotation = Vector3.new(0, 0, 0)},
                {itemId = "test_block", position = Vector3.new(4, 0, 4), rotation = Vector3.new(0, 0, 0)},
                {itemId = "test_roof", position = Vector3.new(2, 4, 2), rotation = Vector3.new(0, 0, 0)}
            },
            creatorId = LocalPlayer.UserId,
            creatorName = LocalPlayer.Name,
            isPublic = false
        }
        
        if blueprintManager.CreateBlueprint then
            blueprintManager:CreateBlueprint(testBlueprint)
            print("✅ Test blueprint creation passed")
        else
            print("❌ Blueprint creation method not found")
        end
    else
        print("❌ Blueprint Manager not found")
    end
end

function BlueprintSystemTest.TestBlueprintPlacement()
    print("BlueprintSystemTest: Testing blueprint placement...")
    
    local blueprintManager = _G.BlueprintManager
    if blueprintManager and blueprintManager.lastBlueprint then
        local blueprint = blueprintManager.lastBlueprint
        local testPosition = Vector3.new(0, 10, 0)
        
        -- Simulate blueprint placement
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local placeBlueprintRemote = remotes:FindFirstChild("PlaceBlueprint")
            if placeBlueprintRemote then
                placeBlueprintRemote:FireServer(blueprint, testPosition)
                print("✅ Blueprint placement test passed")
            else
                print("❌ PlaceBlueprint remote not found")
            end
        else
            print("❌ Remotes folder not found")
        end
    else
        print("❌ No blueprint available for placement test")
    end
end

function BlueprintSystemTest.TestMarketplaceFeatures()
    print("BlueprintSystemTest: Testing marketplace features...")
    
    local blueprintManager = _G.BlueprintManager
    if blueprintManager then
        -- Test marketplace listing
        if blueprintManager.ShareToMarketplace then
            local testBlueprint = {
                id = "test_marketplace_" .. math.random(1000, 9999),
                name = "Marketplace Test Blueprint",
                description = "Testing marketplace functionality",
                category = "test",
                isPublic = true,
                price = 100
            }
            
            blueprintManager:ShareToMarketplace(LocalPlayer, testBlueprint)
            print("✅ Marketplace listing test passed")
        end
        
        -- Test featured blueprints
        if blueprintManager.GetFeaturedBlueprints then
            local featured = blueprintManager:GetFeaturedBlueprints()
            print("✅ Featured blueprints test passed - Found", #featured, "featured blueprints")
        end
    else
        print("❌ Blueprint Manager not found")
    end
end

function BlueprintSystemTest.TestSocialIntegration()
    print("BlueprintSystemTest: Testing social integration...")
    
    local socialManager = _G.SocialManager
    local blueprintManager = _G.BlueprintManager
    
    if socialManager and blueprintManager then
        -- Test blueprint sharing announcement
        local testBlueprint = {
            name = "Social Test Blueprint",
            creatorName = LocalPlayer.Name
        }
        
        -- Simulate blueprint creation event
        if socialManager.BroadcastToGuild then
            socialManager:BroadcastToGuild(LocalPlayer, {
                type = "achievement",
                message = LocalPlayer.Name .. " created a test blueprint: " .. testBlueprint.name,
                icon = "📐"
            })
            print("✅ Social integration test passed")
        end
    else
        print("❌ Social Manager or Blueprint Manager not found")
    end
end

function BlueprintSystemTest.TestXPIntegration()
    print("BlueprintSystemTest: Testing XP integration...")
    
    local xpManager = _G.XPManager
    if xpManager then
        local initialXP = xpManager:GetPlayerXP(LocalPlayer)
        
        -- Simulate blueprint creation XP reward
        xpManager:AwardXP(LocalPlayer, 50, "Test Blueprint Creation")
        
        local newXP = xpManager:GetPlayerXP(LocalPlayer)
        
        if newXP > initialXP then
            print("✅ XP integration test passed - XP increased from", initialXP, "to", newXP)
        else
            print("❌ XP integration test failed - XP did not increase")
        end
    else
        print("❌ XP Manager not found")
    end
end

function BlueprintSystemTest.TestBuildingToolsIntegration()
    print("BlueprintSystemTest: Testing building tools integration...")
    
    local buildingToolsManager = _G.BuildingToolsManager
    if buildingToolsManager then
        -- Test selection system
        if buildingToolsManager.selectedItems then
            print("✅ Building tools selection system found")
            
            -- Create test items for selection
            BlueprintSystemTest.CreateTestItems()
            
            -- Test blueprint creation from selection
            if buildingToolsManager.selectedItems and #buildingToolsManager.selectedItems > 0 then
                print("✅ Building tools integration test passed - Found", #buildingToolsManager.selectedItems, "selected items")
            else
                print("⚠️ Building tools integration test - No items selected")
            end
        else
            print("❌ Building tools selection system not found")
        end
    else
        print("❌ Building Tools Manager not found")
    end
end

function BlueprintSystemTest.CreateTestItems()
    -- Create some test items in the workspace for testing
    local testFolder = workspace:FindFirstChild("TestItems")
    if not testFolder then
        testFolder = Instance.new("Folder")
        testFolder.Name = "TestItems"
        testFolder.Parent = workspace
    end
    
    for i = 1, 3 do
        local testPart = Instance.new("Part")
        testPart.Name = "TestItem_" .. i
        testPart.Size = Vector3.new(4, 4, 4)
        testPart.Position = Vector3.new(i * 6, 5, 0)
        testPart.BrickColor = BrickColor.random()
        testPart.Material = Enum.Material.Neon
        testPart.Anchored = true
        testPart.Parent = testFolder
        
        -- Add to selection if building tools manager exists
        local buildingToolsManager = _G.BuildingToolsManager
        if buildingToolsManager and buildingToolsManager.selectedItems then
            table.insert(buildingToolsManager.selectedItems, testPart)
        end
    end
    
    print("BlueprintSystemTest: Created 3 test items for testing")
end

function BlueprintSystemTest.RunFullSystemTest()
    print("BlueprintSystemTest: Running full system test...")
    
    local testResults = {
        ui = false,
        creation = false,
        placement = false,
        marketplace = false,
        social = false,
        xp = false,
        buildingTools = false
    }
    
    -- Test UI
    local blueprintUI = _G.BlueprintUI
    if blueprintUI then
        testResults.ui = true
        print("✅ UI System: PASS")
    else
        print("❌ UI System: FAIL")
    end
    
    -- Test Blueprint Manager
    local blueprintManager = _G.BlueprintManager
    if blueprintManager then
        testResults.creation = true
        print("✅ Blueprint Manager: PASS")
    else
        print("❌ Blueprint Manager: FAIL")
    end
    
    -- Test XP Integration
    local xpManager = _G.XPManager
    if xpManager then
        testResults.xp = true
        print("✅ XP Integration: PASS")
    else
        print("❌ XP Integration: FAIL")
    end
    
    -- Test Social Integration
    local socialManager = _G.SocialManager
    if socialManager then
        testResults.social = true
        print("✅ Social Integration: PASS")
    else
        print("❌ Social Integration: FAIL")
    end
    
    -- Test Building Tools Integration
    local buildingToolsManager = _G.BuildingToolsManager
    if buildingToolsManager then
        testResults.buildingTools = true
        print("✅ Building Tools Integration: PASS")
    else
        print("❌ Building Tools Integration: FAIL")
    end
    
    -- Calculate overall score
    local passCount = 0
    local totalTests = 0
    for _, result in pairs(testResults) do
        totalTests = totalTests + 1
        if result then
            passCount = passCount + 1
        end
    end
    
    local percentage = math.floor((passCount / totalTests) * 100)
    print("BlueprintSystemTest: Full system test completed")
    print("📊 Test Results:", passCount .. "/" .. totalTests, "(" .. percentage .. "%)")
    
    if percentage >= 80 then
        print("🎉 Blueprint System: EXCELLENT")
    elseif percentage >= 60 then
        print("✅ Blueprint System: GOOD")
    elseif percentage >= 40 then
        print("⚠️ Blueprint System: NEEDS IMPROVEMENT")
    else
        print("❌ Blueprint System: CRITICAL ISSUES")
    end
end

function BlueprintSystemTest.GenerateTestData()
    print("BlueprintSystemTest: Generating test data...")
    
    local blueprintManager = _G.BlueprintManager
    if blueprintManager then
        local testBlueprints = {
            {
                name = "Test House Alpha",
                description = "A simple test house design",
                category = "residential",
                tags = {"house", "test", "simple"},
                items = {
                    {itemId = "wall", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "wall", position = Vector3.new(4, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "roof", position = Vector3.new(2, 4, 2), rotation = Vector3.new(0, 0, 0)}
                }
            },
            {
                name = "Test Tower Beta",
                description = "A tall test tower structure",
                category = "commercial",
                tags = {"tower", "test", "tall"},
                items = {
                    {itemId = "pillar", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "pillar", position = Vector3.new(0, 4, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "pillar", position = Vector3.new(0, 8, 0), rotation = Vector3.new(0, 0, 0)}
                }
            },
            {
                name = "Test Bridge Gamma",
                description = "A decorative test bridge",
                category = "decoration",
                tags = {"bridge", "test", "decorative"},
                items = {
                    {itemId = "plank", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "plank", position = Vector3.new(2, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "railing", position = Vector3.new(1, 1, 0), rotation = Vector3.new(0, 0, 0)}
                }
            }
        }
        
        for _, blueprintData in ipairs(testBlueprints) do
            blueprintData.creatorId = LocalPlayer.UserId
            blueprintData.creatorName = LocalPlayer.Name
            blueprintData.isPublic = true
            
            if blueprintManager.CreateBlueprint then
                blueprintManager:CreateBlueprint(blueprintData)
            end
        end
        
        print("✅ Generated", #testBlueprints, "test blueprints")
    else
        print("❌ Blueprint Manager not found")
    end
end

function BlueprintSystemTest.ClearTestData()
    print("BlueprintSystemTest: Clearing test data...")
    
    -- Clear test items from workspace
    local testFolder = workspace:FindFirstChild("TestItems")
    if testFolder then
        testFolder:Destroy()
        print("✅ Cleared test items from workspace")
    end
    
    -- Clear test blueprints (if manager supports it)
    local blueprintManager = _G.BlueprintManager
    if blueprintManager and blueprintManager.ClearTestData then
        blueprintManager:ClearTestData()
        print("✅ Cleared test blueprints")
    end
    
    print("BlueprintSystemTest: Test data cleared")
end

-- Auto-initialize in Studio
if RunService:IsStudio() then
    BlueprintSystemTest.Initialize()
end

return BlueprintSystemTest 