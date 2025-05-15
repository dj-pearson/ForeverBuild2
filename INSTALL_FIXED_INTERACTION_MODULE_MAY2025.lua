-- INSTALL_FIXED_INTERACTION_MODULE.lua
-- This script replaces the original module with the fixed version
-- May 14, 2025

-- Load file system services
local RunService = game:GetService("RunService")

-- Check if we're in Studio
if not RunService:IsStudio() then
    error("This script should only be run in Roblox Studio.")
    return
end

print("====== INSTALLING FIXED INTERACTION SYSTEM MODULE ======")
print("Starting installation process...")

-- Step 1: Check if the fixed module exists
local fixedModulePath = "src/client/interaction/InteractionSystemModule_fixed.lua"
local originalModulePath = "src/client/interaction/InteractionSystemModule.lua"
local backupPath = "src/client/interaction/InteractionSystemModule.lua.bak"

local function fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

if not fileExists(fixedModulePath) then
    error("Fixed module not found at: " .. fixedModulePath)
    return
end

print("✓ Fixed module found")

-- Step 2: Create a backup of the original file
print("Creating backup of original module...")

if not fileExists(backupPath) then
    local originalFile = io.open(originalModulePath, "r")
    if originalFile then
        local content = originalFile:read("*all")
        originalFile:close()
        
        local backupFile = io.open(backupPath, "w")
        if backupFile then
            backupFile:write(content)
            backupFile:close()
            print("✓ Backup created at: " .. backupPath)
        else
            warn("Failed to create backup file")
            return
        end
    else
        warn("Failed to open original module")
        return
    end
else
    print("✓ Backup already exists, skipping backup step")
end

-- Step 3: Copy the fixed module to replace the original
print("Installing fixed module...")

local fixedFile = io.open(fixedModulePath, "r")
if fixedFile then
    local content = fixedFile:read("*all")
    fixedFile:close()
    
    local originalFile = io.open(originalModulePath, "w")
    if originalFile then
        originalFile:write(content)
        originalFile:close()
        print("✓ Fixed module installed successfully")
    else
        warn("Failed to write to original module path")
        return
    end
else
    warn("Failed to open fixed module")
    return
end

print("\n====== INSTALLATION COMPLETE ======")
print("The InteractionSystemModule has been replaced with the fixed version.")
print("A backup of the original file was saved to: " .. backupPath)
print("You can now test the interaction system in-game.")

print("\nTo validate the fixed module, run the VALIDATE_FIXED_INTERACTION_MODULE script.")
print("If you encounter issues, restore the backup by renaming it back to InteractionSystemModule.lua")
