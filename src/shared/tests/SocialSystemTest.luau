-- SocialSystemTest.luau
-- Test script for validating social system functionality

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local SocialSystemTest = {}

-- Test configuration
local TEST_CONFIG = {
    ENABLED = true,
    AUTO_TEST = false,
    TEST_DELAY = 2,
    
    -- Test controls
    CONTROLS = {
        [Enum.KeyCode.F8] = "ToggleSocialUI",
        [Enum.KeyCode.F9] = "TestChatSystem", 
        [Enum.KeyCode.F10] = "TestGuildSystem",
        [Enum.KeyCode.F11] = "TestTeamSystem",
        [Enum.KeyCode.F12] = "RunFullTest"
    }
}

function SocialSystemTest.Initialize()
    if not TEST_CONFIG.ENABLED then return end
    
    print("SocialSystemTest: Initializing test suite...")
    
    -- Set up test controls
    SocialSystemTest.SetupTestControls()
    
    -- Wait for social system to be ready
    task.spawn(function()
        while not _G.ForeverBuildSystems or not _G.ForeverBuildSystems.SocialManager do
            task.wait(1)
        end
        
        print("SocialSystemTest: Social system detected, test suite ready!")
        SocialSystemTest.ShowTestInstructions()
        
        if TEST_CONFIG.AUTO_TEST then
            task.wait(5)
            SocialSystemTest.RunFullTest()
        end
    end)
end

function SocialSystemTest.SetupTestControls()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local testAction = TEST_CONFIG.CONTROLS[input.KeyCode]
        if testAction then
            SocialSystemTest[testAction]()
        end
    end)
end

function SocialSystemTest.ShowTestInstructions()
    print("==========================================")
    print("SOCIAL SYSTEM TEST CONTROLS:")
    print("F8  - Toggle Social UI")
    print("F9  - Test Chat System")
    print("F10 - Test Guild System") 
    print("F11 - Test Team System")
    print("F12 - Run Full Test Suite")
    print("==========================================")
    print("Ctrl+S - Open Social Hub (normal gameplay)")
    print("Alt+1-5 - Play emotes")
    print("==========================================")
end

function SocialSystemTest.ToggleSocialUI()
    print("SocialSystemTest: Toggling Social UI...")
    
    local socialUI = _G.ForeverBuildSystems.SocialUI
    if socialUI then
        socialUI:Toggle()
        print("✅ Social UI toggled")
    else
        print("❌ Social UI not found")
    end
end

function SocialSystemTest.TestChatSystem()
    print("SocialSystemTest: Testing chat system...")
    
    local socialManager = _G.ForeverBuildSystems.SocialManager
    if not socialManager then
        print("❌ Social manager not found")
        return
    end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("❌ Remotes folder not found")
        return
    end
    
    local sendEvent = remotes:FindFirstChild("SendChatMessage")
    if not sendEvent then
        print("❌ SendChatMessage remote not found")
        return
    end
    
    -- Test sending messages to different channels
    local testMessages = {
        {channel = "global", message = "🧪 Testing global chat functionality!"},
        {channel = "global", message = "🎮 Social system test in progress..."},
        {channel = "global", message = "👋 Hello from the test suite!"}
    }
    
    for i, test in ipairs(testMessages) do
        task.wait(1)
        sendEvent:FireServer(test.channel, test.message)
        print("✅ Sent test message " .. i .. " to " .. test.channel)
    end
    
    print("✅ Chat system test completed")
end

function SocialSystemTest.TestGuildSystem()
    print("SocialSystemTest: Testing guild system...")
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("❌ Remotes folder not found")
        return
    end
    
    -- Test guild creation
    local createGuildEvent = remotes:FindFirstChild("CreateGuild")
    if createGuildEvent then
        createGuildEvent:FireServer("Test Guild " .. math.random(1000, 9999), 
            "A test guild created by the automated test suite")
        print("✅ Guild creation test sent")
    else
        print("❌ CreateGuild remote not found")
    end
    
    -- Test joining sample guild
    task.wait(2)
    local joinGuildEvent = remotes:FindFirstChild("JoinGuild")
    if joinGuildEvent then
        joinGuildEvent:FireServer("sample_guild_1")
        print("✅ Guild join test sent")
    else
        print("❌ JoinGuild remote not found")
    end
    
    print("✅ Guild system test completed")
end

function SocialSystemTest.TestTeamSystem()
    print("SocialSystemTest: Testing team system...")
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        print("❌ Remotes folder not found")
        return
    end
    
    -- Test team creation
    local createTeamEvent = remotes:FindFirstChild("CreateTeam")
    if createTeamEvent then
        createTeamEvent:FireServer("Test Team " .. math.random(100, 999), "building")
        print("✅ Team creation test sent")
    else
        print("❌ CreateTeam remote not found")
    end
    
    -- Test help request
    task.wait(2)
    local requestHelpEvent = remotes:FindFirstChild("RequestHelp")
    if requestHelpEvent then
        requestHelpEvent:FireServer("Test Project", "This is a test help request from the automated test suite")
        print("✅ Help request test sent")
    else
        print("❌ RequestHelp remote not found")
    end
    
    print("✅ Team system test completed")
end

function SocialSystemTest.TestEmoteSystem()
    print("SocialSystemTest: Testing emote system...")
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") then
        print("❌ Player character not ready for emote test")
        return
    end
    
    local humanoid = LocalPlayer.Character.Humanoid
    local animator = humanoid:FindFirstChild("Animator")
    
    if not animator then
        print("❌ Animator not found")
        return
    end
    
    -- Test wave emote
    local waveAnimation = Instance.new("Animation")
    waveAnimation.AnimationId = "rbxassetid://507770239"
    
    local success, animationTrack = pcall(function()
        return animator:LoadAnimation(waveAnimation)
    end)
    
    if success then
        animationTrack:Play()
        print("✅ Emote animation test successful")
        
        task.wait(2)
        animationTrack:Stop()
    else
        print("❌ Emote animation test failed")
    end
    
    print("✅ Emote system test completed")
end

function SocialSystemTest.TestNotificationSystem()
    print("SocialSystemTest: Testing notification system...")
    
    local socialManager = _G.ForeverBuildSystems.SocialManager
    if not socialManager or not socialManager.ShowNotification then
        print("❌ Notification system not found")
        return
    end
    
    -- Test different notification types
    local notifications = {
        {title = "Success Test", message = "This is a success notification test", type = "success"},
        {title = "Info Test", message = "This is an info notification test", type = "info"},
        {title = "Warning Test", message = "This is a warning notification test", type = "warning"},
        {title = "Error Test", message = "This is an error notification test", type = "error"}
    }
    
    for i, notif in ipairs(notifications) do
        task.wait(1)
        socialManager.ShowNotification(notif.title, notif.message, notif.type)
        print("✅ " .. notif.type .. " notification test sent")
    end
    
    print("✅ Notification system test completed")
end

function SocialSystemTest.TestIntegrationSystems()
    print("SocialSystemTest: Testing integration systems...")
    
    -- Test XP system integration
    if _G.ForeverBuildSystems.XPManager then
        local xpManager = _G.ForeverBuildSystems.XPManager
        
        -- Award some test XP
        if xpManager.AwardXP then
            xpManager:AwardXP(LocalPlayer, 50, "social_test")
            print("✅ XP integration test sent")
        end
    else
        print("⚠️ XP system not found for integration test")
    end
    
    -- Test currency system integration
    if _G.ForeverBuildSystems.CurrencyManager then
        print("✅ Currency system integration available")
    else
        print("⚠️ Currency system not found for integration test")
    end
    
    -- Test building tools integration
    if _G.ForeverBuildSystems.BuildingToolsManager then
        print("✅ Building tools integration available")
    else
        print("⚠️ Building tools not found for integration test")
    end
    
    print("✅ Integration systems test completed")
end

function SocialSystemTest.RunFullTest()
    print("SocialSystemTest: Running full test suite...")
    print("==========================================")
    
    -- Run all tests with delays
    SocialSystemTest.ToggleSocialUI()
    task.wait(TEST_CONFIG.TEST_DELAY)
    
    SocialSystemTest.TestNotificationSystem()
    task.wait(TEST_CONFIG.TEST_DELAY)
    
    SocialSystemTest.TestChatSystem()
    task.wait(TEST_CONFIG.TEST_DELAY)
    
    SocialSystemTest.TestGuildSystem()
    task.wait(TEST_CONFIG.TEST_DELAY)
    
    SocialSystemTest.TestTeamSystem()
    task.wait(TEST_CONFIG.TEST_DELAY)
    
    SocialSystemTest.TestEmoteSystem()
    task.wait(TEST_CONFIG.TEST_DELAY)
    
    SocialSystemTest.TestIntegrationSystems()
    
    print("==========================================")
    print("✅ FULL TEST SUITE COMPLETED")
    print("Check output above for any ❌ failures")
    print("==========================================")
end

function SocialSystemTest.GetTestReport()
    local socialManager = _G.ForeverBuildSystems.SocialManager
    local socialUI = _G.ForeverBuildSystems.SocialUI
    
    local report = {
        SocialManager = socialManager ~= nil,
        SocialUI = socialUI ~= nil,
        RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes") ~= nil,
        PlayerCharacter = LocalPlayer.Character ~= nil,
        
        -- Check specific remotes
        SendChatMessage = false,
        CreateGuild = false,
        CreateTeam = false,
        RequestHelp = false
    }
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        report.SendChatMessage = remotes:FindFirstChild("SendChatMessage") ~= nil
        report.CreateGuild = remotes:FindFirstChild("CreateGuild") ~= nil
        report.CreateTeam = remotes:FindFirstChild("CreateTeam") ~= nil
        report.RequestHelp = remotes:FindFirstChild("RequestHelp") ~= nil
    end
    
    return report
end

function SocialSystemTest.PrintTestReport()
    print("==========================================")
    print("SOCIAL SYSTEM STATUS REPORT:")
    print("==========================================")
    
    local report = SocialSystemTest.GetTestReport()
    
    for component, status in pairs(report) do
        local icon = status and "✅" or "❌"
        print(icon .. " " .. component .. ": " .. tostring(status))
    end
    
    print("==========================================")
end

-- Auto-initialize if in testing environment
if RunService:IsStudio() then
    task.spawn(function()
        task.wait(2)
        SocialSystemTest.Initialize()
    end)
end

return SocialSystemTest 