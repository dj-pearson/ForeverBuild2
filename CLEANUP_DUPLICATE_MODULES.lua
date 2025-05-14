--[[
    ForeverBuild Cleanup Script
    
    This script removes all the unnecessary duplicate modules that were created as part of previous
    fix attempts, now that we've directly fixed the original InteractionSystemModule.lua file.
]]

print("=== CLEANUP SCRIPT ===")
print("Cleaning up unnecessary duplicate modules...")

-- Function to check if a file exists
local function fileExists(path)
    local success, _ = pcall(function()
        return readfile(path)
    end)
    return success
end

-- Files to remove (these are now unnecessary since we fixed the original)
local filesToDelete = {
    "src/client/interaction/InteractionSystemModule_fixed.lua",
    "src/client/interaction/LoadFixedModuleFirst.lua",
    "src/client/interaction/InteractionSystemModule_emergency.lua",
    "INSTALL_FIXED_INTERACTION_MODULE.lua"
}

-- Count of files removed
local removedCount = 0

-- Try to remove each file
for _, filepath in ipairs(filesToDelete) do
    -- Convert to Windows path
    local winPath = filepath:gsub("/", "\\")
    
    print("Checking for " .. winPath)
    if fileExists(winPath) then
        -- This doesn't actually delete in Roblox Studio, you'd need to manually delete there
        print("Would delete: " .. winPath)
        removedCount = removedCount + 1
    else
        print("File not found: " .. winPath)
    end
end

print("Found " .. removedCount .. " files to remove.")
print("NOTE: In Roblox Studio, you'll need to manually delete these files.")
print("=== CLEANUP COMPLETE ===")

-- Reminder of what to check
print("\nIMPORTANT: The interaction system has been fixed in the original module.")
print("- The fix removed BindToClose (which is server-only) and replaced it with PlayerRemoving")
print("- If you're testing in Roblox Studio, you may need to restart the game to see the changes")
print("- Check RobloxOutput.txt for any remaining errors after the fix")
