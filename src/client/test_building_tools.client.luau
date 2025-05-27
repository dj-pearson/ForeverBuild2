-- Test script for BuildingToolsManager
-- This script can be used to test the building tools functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("BuildingTools Test: Starting...")

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)
if not shared then
    warn("BuildingTools Test: Could not find shared module")
    return
end

local SharedModule = require(shared)
if not SharedModule.BuildingToolsManager then
    warn("BuildingTools Test: BuildingToolsManager not found in SharedModule")
    return
end

-- Initialize BuildingToolsManager
local buildingTools = SharedModule.BuildingToolsManager.new()
if buildingTools then
    buildingTools:Initialize()
    
    -- Store global reference for easy access
    _G.BuildingToolsTest = buildingTools
    
    print("BuildingTools Test: Initialized successfully!")
    print("BuildingTools Test: Press B to toggle tools")
    print("BuildingTools Test: Press G to toggle grid")
    print("BuildingTools Test: Use Ctrl+C/V for copy/paste")
    print("BuildingTools Test: Use Delete to delete selected items")
    print("BuildingTools Test: Use Ctrl+R to rotate selected items")
    print("BuildingTools Test: Use Ctrl+A to select all items")
    print("BuildingTools Test: Use Esc to clear selection")
    
    -- Create some test objects for testing
    task.spawn(function()
        task.wait(2) -- Wait for everything to load
        
        local testFolder = workspace:FindFirstChild("BuildingTestObjects") 
        if not testFolder then
            testFolder = Instance.new("Folder")
            testFolder.Name = "BuildingTestObjects"
            testFolder.Parent = workspace
        end
        
        -- Create test cubes
        for i = 1, 5 do
            local testCube = Instance.new("Part")
            testCube.Name = "TestCube" .. i
            testCube.Size = Vector3.new(4, 4, 4)
            testCube.Position = Vector3.new(i * 6, 2, 0)
            testCube.Material = Enum.Material.Neon
            testCube.BrickColor = BrickColor.random()
            testCube.Anchored = true
            testCube:SetAttribute("CanSelect", true)
            testCube:SetAttribute("CanDelete", true)
            testCube:SetAttribute("CanAlign", true)
            testCube.Parent = testFolder
        end
        
        print("BuildingTools Test: Created test objects for testing")
    end)
else
    warn("BuildingTools Test: Failed to create BuildingToolsManager instance")
end 