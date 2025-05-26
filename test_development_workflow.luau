-- test_development_workflow.luau
-- Practical script to demonstrate development workflow for live game expansion

print("=== TESTING DEVELOPMENT WORKFLOW ===")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Load the systems
local PlacementTracker = require(script.Parent:WaitForChild("src"):WaitForChild("server"):WaitForChild("PlacementTracker"))
local ConflictResolver = require(script.Parent:WaitForChild("src"):WaitForChild("server"):WaitForChild("ConflictResolver"))

-- Initialize systems
local placementTracker = PlacementTracker.new()
local conflictResolver = ConflictResolver.new(placementTracker, nil) -- GameManager would be passed here

print("✅ Development systems initialized")

-- SCENARIO 1: Planning a new residential area
print("\n🏘️ SCENARIO 1: Planning New Residential Area")

-- Define the planned residential zone
local residentialZone = placementTracker:DefineDevelopmentZone(
    "ResidentialDistrict_A",
    Vector3.new(200, 0, 200),
    Vector3.new(400, 50, 400),
    "Residential District with 20 houses and community center"
)

-- Check for conflicts in the planned area
local residentialConflicts = placementTracker:CheckDevelopmentConflicts(
    "ResidentialDistrict_A",
    Vector3.new(200, 0, 200),
    Vector3.new(400, 50, 400)
)

print("📊 Residential Zone Analysis:")
print("   Total conflicts:", residentialConflicts.totalConflicts)
print("   Affected players:", #residentialConflicts.playerSummary)

if residentialConflicts.totalConflicts > 0 then
    print("   📋 Conflict Details:")
    for playerName, summary in pairs(residentialConflicts.playerSummary) do
        print("      Player:", playerName, "has", summary.objectCount, "objects")
        print("         Items:", table.concat(summary.items, ", "))
    end
    
    -- Decision point: How to handle conflicts?
    print("\n🤔 Development Decision Required:")
    print("   Option A: Relocate all objects to nearby safe areas")
    print("   Option B: Compensate players and remove objects")
    print("   Option C: Redesign residential layout to avoid conflicts")
    print("   Option D: Phase development - build around existing objects")
    
    -- Example: Let's relocate objects
    print("\n🔧 Executing Option A: Relocating Objects")
    local resolutionResults = conflictResolver:EnforceProtectedZone("ResidentialDistrict_A")
    
    print("✅ Resolution Results:")
    print("   Objects relocated:", resolutionResults.relocated)
    print("   Objects compensated & removed:", resolutionResults.compensated)
    print("   Failed relocations:", resolutionResults.failed)
end

-- SCENARIO 2: Planning a road network
print("\n🛣️ SCENARIO 2: Planning Road Network")

-- Define multiple road segments
local roadSegments = {
    {
        name = "MainStreet_North",
        start = Vector3.new(-300, 0, -100),
        finish = Vector3.new(300, 0, -80),
        width = 20
    },
    {
        name = "MainStreet_South", 
        start = Vector3.new(-300, 0, 80),
        finish = Vector3.new(300, 0, 100),
        width = 20
    },
    {
        name = "CenterAvenue",
        start = Vector3.new(-10, 0, -200),
        finish = Vector3.new(10, 0, 200),
        width = 15
    }
}

local totalRoadConflicts = 0
local roadConflictDetails = {}

for _, road in ipairs(roadSegments) do
    -- Create development zone for each road
    local roadZone = placementTracker:DefineDevelopmentZone(
        road.name,
        Vector3.new(
            math.min(road.start.X, road.finish.X) - road.width/2,
            0,
            math.min(road.start.Z, road.finish.Z) - road.width/2
        ),
        Vector3.new(
            math.max(road.start.X, road.finish.X) + road.width/2,
            10,
            math.max(road.start.Z, road.finish.Z) + road.width/2
        ),
        "Road infrastructure - " .. road.name
    )
    
    -- Check conflicts for this road segment
    local roadConflicts = placementTracker:CheckDevelopmentConflicts(
        road.name,
        Vector3.new(
            math.min(road.start.X, road.finish.X) - road.width/2,
            0,
            math.min(road.start.Z, road.finish.Z) - road.width/2
        ),
        Vector3.new(
            math.max(road.start.X, road.finish.X) + road.width/2,
            10,
            math.max(road.start.Z, road.finish.Z) + road.width/2
        )
    )
    
    totalRoadConflicts = totalRoadConflicts + roadConflicts.totalConflicts
    roadConflictDetails[road.name] = roadConflicts
    
    print("📋", road.name, "conflicts:", roadConflicts.totalConflicts)
end

print("📊 Total Road Network Conflicts:", totalRoadConflicts)

-- SCENARIO 3: Generate comprehensive development report
print("\n📈 SCENARIO 3: Development Report Generation")

local developmentReport = placementTracker:GenerateDevelopmentReport()

print("📊 COMPREHENSIVE DEVELOPMENT REPORT")
print("   Report Date:", developmentReport.timestamp)
print("   Total Player Placements:", developmentReport.totalPlacements)
print("   Active Development Zones:", developmentReport.activeZones)
print("   Active Players:", #developmentReport.playerStats)

-- Show top players by placement count
print("\n👥 Top Players by Placement Count:")
local playerList = {}
for playerName, stats in pairs(developmentReport.playerStats) do
    table.insert(playerList, {name = playerName, count = stats.totalPlacements})
end

table.sort(playerList, function(a, b) return a.count > b.count end)

for i = 1, math.min(5, #playerList) do
    local player = playerList[i]
    print("   " .. i .. ". " .. player.name .. ": " .. player.count .. " objects")
end

-- Show density hotspots
print("\n🔥 Density Hotspots (High Activity Areas):")
local densityList = {}
for gridKey, density in pairs(developmentReport.densityMap) do
    table.insert(densityList, density)
end

table.sort(densityList, function(a, b) return a.objectCount > b.objectCount end)

for i = 1, math.min(5, #densityList) do
    local hotspot = densityList[i]
    print(string.format("   %d. Grid (%d,%d): %d objects at %s", 
        i, hotspot.gridX, hotspot.gridZ, hotspot.objectCount, tostring(hotspot.worldCenter)))
end

-- SCENARIO 4: Development recommendations
print("\n💡 SCENARIO 4: Development Recommendations")

print("🎯 Recommended Development Strategy:")

if totalRoadConflicts > developmentReport.totalPlacements * 0.1 then
    print("   ⚠️  HIGH CONFLICT: Consider phased road development")
    print("      - Build roads in sections with fewer conflicts first")
    print("      - Offer relocation assistance program")
    print("      - Consider underground/elevated road options")
end

if developmentReport.totalPlacements > 100 then
    print("   📈 HIGH ACTIVITY: Implement placement restrictions")
    print("      - Define no-build zones for future expansion")
    print("      - Create designated building districts")
    print("      - Implement zoning system (residential, commercial, etc.)")
end

-- Show areas with low player activity (good for development)
print("\n🌿 Low-Activity Areas (Good for Development):")
local lowActivityAreas = {}
for gridKey, density in pairs(developmentReport.densityMap) do
    if density.objectCount <= 2 then
        table.insert(lowActivityAreas, density)
    end
end

if #lowActivityAreas > 0 then
    for i = 1, math.min(3, #lowActivityAreas) do
        local area = lowActivityAreas[i]
        print(string.format("   • Grid (%d,%d): Only %d objects at %s", 
            area.gridX, area.gridZ, area.objectCount, tostring(area.worldCenter)))
    end
else
    print("   ℹ️  All areas have significant player activity - careful planning required")
end

-- SCENARIO 5: Version management strategy
print("\n🔄 SCENARIO 5: Version Management Strategy")

print("📋 Recommended Workflow for Live Game Updates:")
print("   1. 📊 Generate development report (current data)")
print("   2. 🎯 Define development zones for planned features")
print("   3. 🔍 Check conflicts using CheckDevelopmentConflicts()")
print("   4. 🤝 Communicate with affected players (advance notice)")
print("   5. 🔧 Execute conflict resolution (relocate/compensate)")
print("   6. 🏗️  Deploy new content to cleared areas")
print("   7. 📈 Monitor player reaction and adjust as needed")

print("\n💾 Data Backup Recommendations:")
print("   • Save world state before major updates")
print("   • Version your development zones in DataStore")
print("   • Track all player notifications and compensations")
print("   • Maintain rollback capability for 48 hours post-update")

print("\n🎮 Player Communication Strategy:")
print("   • Send in-game mail 48-72 hours before changes")
print("   • Offer preview of new features to affected players")
print("   • Provide generous compensation (110-200% of item value)")
print("   • Create VIP relocation service for long-term players")

print("\n=== DEVELOPMENT WORKFLOW TEST COMPLETE ===")
print("🎯 Key Takeaway: Proactive planning and player communication")
print("   are essential for successful live game development!")

-- Return systems for further use
return {
    placementTracker = placementTracker,
    conflictResolver = conflictResolver,
    developmentReport = developmentReport
} 