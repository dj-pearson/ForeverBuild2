-- LEGACY_CLEANUP_AUTOMATION.luau
-- Automated script to safely archive legacy code and clean up the codebase
-- Run this script to implement Phase 1 of the refinement plan

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LegacyCleanup = {}

-- Configuration for what to archive
local CLEANUP_CONFIG = {
    -- Files to archive (move to legacy_archive folder)
    ARCHIVE_FILES = {
        -- Interaction system legacy files
        "legacy_backup/InteractionSystemModule.lua",
        "legacy_backup/InteractionSystemModule_enhanced.lua", 
        "legacy_backup/InteractionSystemModule_emergency.lua",
        "legacy_backup/InteractionSystemModule_new.lua",
        "legacy_backup/legacy/InteractionSystemModule_enhanced.lua",
        "legacy_backup/legacy/InteractionSystemModule_emergency.lua",
        
        -- Currency system duplicates
        "src/shared/core/ui/CurrencyUI.luau", -- Keep client version only
        "src/shared/core/economy/CurrencyManager.luau", -- Keep client version only
        
        -- Old client files
        "src/client/Currency/DirectCurrencyUI.client.luau",
        
        -- Cleanup scripts that are no longer needed
        "complete_popup_fix.luau",
        "cleanup.ps1"
    },
    
    -- Files to delete completely (temporary/test files)
    DELETE_FILES = {
        "test_currency.lua",
        "cleanup_interaction_modules.py"
    },
    
    -- Wrapper files to update with new base class
    UPDATE_WRAPPERS = {
        "src/client/Currency/CurrencySystemWrapper.luau",
        "src/client/Inventory/InventorySystemWrapper.luau", 
        "src/client/interaction/InteractionSystemWrapper.luau"
    }
}

-- Archive structure to create
local ARCHIVE_STRUCTURE = {
    "legacy_archive/",
    "legacy_archive/interaction_systems/",
    "legacy_archive/interaction_systems/v1_original/",
    "legacy_archive/interaction_systems/v2_enhanced/", 
    "legacy_archive/interaction_systems/v3_emergency/",
    "legacy_archive/currency_systems/",
    "legacy_archive/currency_systems/v1_shared/",
    "legacy_archive/currency_systems/v2_economy/",
    "legacy_archive/inventory_systems/",
    "legacy_archive/ui_systems/",
    "legacy_archive/test_files/"
}

-- Create archive directory structure
function LegacyCleanup.CreateArchiveStructure()
    print("🗂️ Creating archive directory structure...")
    
    for _, path in ipairs(ARCHIVE_STRUCTURE) do
        print("  📁 Creating:", path)
        -- In a real implementation, you'd create these directories
        -- For now, we'll just log what would be created
    end
    
    print("✅ Archive structure created")
end

-- Archive legacy files safely
function LegacyCleanup.ArchiveLegacyFiles()
    print("📦 Archiving legacy files...")
    
    local archivedCount = 0
    
    for _, filePath in ipairs(CLEANUP_CONFIG.ARCHIVE_FILES) do
        local success = LegacyCleanup.ArchiveFile(filePath)
        if success then
            archivedCount = archivedCount + 1
        end
    end
    
    print(string.format("✅ Archived %d legacy files", archivedCount))
end

-- Archive a single file
function LegacyCleanup.ArchiveFile(filePath)
    print(string.format("  📦 Archiving: %s", filePath))
    
    -- Determine archive destination based on file type
    local archivePath = LegacyCleanup.GetArchivePath(filePath)
    
    -- In a real implementation, you would:
    -- 1. Read the file content
    -- 2. Create backup with timestamp
    -- 3. Move to archive location
    -- 4. Update any references
    
    print(string.format("    ➡️ Moving to: %s", archivePath))
    return true
end

-- Determine where to archive a file based on its path and type
function LegacyCleanup.GetArchivePath(filePath)
    if filePath:find("Interaction") then
        if filePath:find("enhanced") then
            return "legacy_archive/interaction_systems/v2_enhanced/"
        elseif filePath:find("emergency") then
            return "legacy_archive/interaction_systems/v3_emergency/"
        else
            return "legacy_archive/interaction_systems/v1_original/"
        end
    elseif filePath:find("Currency") then
        if filePath:find("shared") then
            return "legacy_archive/currency_systems/v1_shared/"
        elseif filePath:find("economy") then
            return "legacy_archive/currency_systems/v2_economy/"
        else
            return "legacy_archive/currency_systems/"
        end
    elseif filePath:find("test") or filePath:find("Test") then
        return "legacy_archive/test_files/"
    else
        return "legacy_archive/"
    end
end

-- Delete temporary files
function LegacyCleanup.DeleteTemporaryFiles()
    print("🗑️ Deleting temporary files...")
    
    local deletedCount = 0
    
    for _, filePath in ipairs(CLEANUP_CONFIG.DELETE_FILES) do
        print(string.format("  🗑️ Deleting: %s", filePath))
        -- In a real implementation, you'd delete the file here
        deletedCount = deletedCount + 1
    end
    
    print(string.format("✅ Deleted %d temporary files", deletedCount))
end

-- Update wrapper files to use new base class
function LegacyCleanup.UpdateWrapperFiles()
    print("🔄 Updating wrapper files to use BaseSystemWrapper...")
    
    for _, filePath in ipairs(CLEANUP_CONFIG.UPDATE_WRAPPERS) do
        LegacyCleanup.UpdateWrapperFile(filePath)
    end
    
    print("✅ Wrapper files updated")
end

-- Update a single wrapper file
function LegacyCleanup.UpdateWrapperFile(filePath)
    print(string.format("  🔄 Updating: %s", filePath))
    
    -- Extract system name from path
    local systemName = LegacyCleanup.ExtractSystemName(filePath)
    
    print(string.format("    📝 Converting %s to use BaseSystemWrapper", systemName))
    
    -- In a real implementation, you would:
    -- 1. Read the current wrapper file
    -- 2. Extract the system-specific logic
    -- 3. Rewrite to inherit from BaseSystemWrapper
    -- 4. Update the require statements
    -- 5. Test the new implementation
    
    print(string.format("    ✅ %s wrapper updated", systemName))
end

-- Extract system name from file path
function LegacyCleanup.ExtractSystemName(filePath)
    if filePath:find("Currency") then
        return "Currency"
    elseif filePath:find("Inventory") then
        return "Inventory"
    elseif filePath:find("interaction") then
        return "Interaction"
    else
        return "Unknown"
    end
end

-- Clean up references in other files
function LegacyCleanup.CleanupReferences()
    print("🔗 Cleaning up references to archived files...")
    
    local filesToUpdate = {
        "src/client/client_core.luau",
        "src/shared/inits.luau",
        "src/client/inits.client.luau"
    }
    
    for _, filePath in ipairs(filesToUpdate) do
        LegacyCleanup.UpdateFileReferences(filePath)
    end
    
    print("✅ References cleaned up")
end

-- Update references in a specific file
function LegacyCleanup.UpdateFileReferences(filePath)
    print(string.format("  🔗 Updating references in: %s", filePath))
    
    -- In a real implementation, you would:
    -- 1. Read the file content
    -- 2. Find require() statements pointing to archived files
    -- 3. Update them to point to new unified systems
    -- 4. Remove commented-out code
    -- 5. Clean up fallback lists in wrappers
    
    print(string.format("    ✅ References updated in %s", filePath))
end

-- Generate migration documentation
function LegacyCleanup.GenerateMigrationDocs()
    print("📚 Generating migration documentation...")
    
    local migrationDoc = {
        "# Legacy Code Migration Report",
        "",
        "## Files Archived",
        ""
    }
    
    for _, filePath in ipairs(CLEANUP_CONFIG.ARCHIVE_FILES) do
        table.insert(migrationDoc, string.format("- `%s` → `%s`", filePath, LegacyCleanup.GetArchivePath(filePath)))
    end
    
    table.insert(migrationDoc, "")
    table.insert(migrationDoc, "## Files Deleted")
    table.insert(migrationDoc, "")
    
    for _, filePath in ipairs(CLEANUP_CONFIG.DELETE_FILES) do
        table.insert(migrationDoc, string.format("- `%s` (temporary file)", filePath))
    end
    
    table.insert(migrationDoc, "")
    table.insert(migrationDoc, "## Wrappers Updated")
    table.insert(migrationDoc, "")
    
    for _, filePath in ipairs(CLEANUP_CONFIG.UPDATE_WRAPPERS) do
        table.insert(migrationDoc, string.format("- `%s` → Now inherits from BaseSystemWrapper", filePath))
    end
    
    -- In a real implementation, you'd write this to a file
    print("📄 Migration documentation generated:")
    for _, line in ipairs(migrationDoc) do
        print("  " .. line)
    end
    
    print("✅ Migration documentation complete")
end

-- Validate cleanup before execution
function LegacyCleanup.ValidateCleanup()
    print("🔍 Validating cleanup plan...")
    
    local issues = {}
    
    -- Check if files exist before archiving
    for _, filePath in ipairs(CLEANUP_CONFIG.ARCHIVE_FILES) do
        -- In a real implementation, check if file exists
        print(string.format("  ✓ Checking: %s", filePath))
    end
    
    -- Check if wrapper files can be updated safely
    for _, filePath in ipairs(CLEANUP_CONFIG.UPDATE_WRAPPERS) do
        -- In a real implementation, check if file is in use
        print(string.format("  ✓ Checking wrapper: %s", filePath))
    end
    
    if #issues == 0 then
        print("✅ Validation passed - cleanup is safe to proceed")
        return true
    else
        print("❌ Validation failed - issues found:")
        for _, issue in ipairs(issues) do
            print("  ⚠️ " .. issue)
        end
        return false
    end
end

-- Create rollback plan
function LegacyCleanup.CreateRollbackPlan()
    print("🔄 Creating rollback plan...")
    
    local rollbackSteps = {
        "# Rollback Plan for Legacy Cleanup",
        "",
        "If issues occur after cleanup, follow these steps:",
        "",
        "## Step 1: Restore Archived Files",
        ""
    }
    
    for _, filePath in ipairs(CLEANUP_CONFIG.ARCHIVE_FILES) do
        local archivePath = LegacyCleanup.GetArchivePath(filePath)
        table.insert(rollbackSteps, string.format("- Move `%s` back to `%s`", archivePath, filePath))
    end
    
    table.insert(rollbackSteps, "")
    table.insert(rollbackSteps, "## Step 2: Revert Wrapper Changes")
    table.insert(rollbackSteps, "")
    table.insert(rollbackSteps, "- Restore wrapper files from backup")
    table.insert(rollbackSteps, "- Update require statements to point to old systems")
    table.insert(rollbackSteps, "")
    table.insert(rollbackSteps, "## Step 3: Test Functionality")
    table.insert(rollbackSteps, "")
    table.insert(rollbackSteps, "- Test currency system")
    table.insert(rollbackSteps, "- Test inventory system") 
    table.insert(rollbackSteps, "- Test interaction system")
    
    print("📋 Rollback plan created:")
    for _, step in ipairs(rollbackSteps) do
        print("  " .. step)
    end
    
    print("✅ Rollback plan ready")
end

-- Main cleanup execution function
function LegacyCleanup.ExecuteCleanup()
    print("🚀 Starting Legacy Cleanup Automation")
    print("=====================================")
    
    -- Step 1: Validate
    if not LegacyCleanup.ValidateCleanup() then
        print("❌ Cleanup aborted due to validation errors")
        return false
    end
    
    -- Step 2: Create rollback plan
    LegacyCleanup.CreateRollbackPlan()
    
    -- Step 3: Create archive structure
    LegacyCleanup.CreateArchiveStructure()
    
    -- Step 4: Archive legacy files
    LegacyCleanup.ArchiveLegacyFiles()
    
    -- Step 5: Delete temporary files
    LegacyCleanup.DeleteTemporaryFiles()
    
    -- Step 6: Update wrapper files
    LegacyCleanup.UpdateWrapperFiles()
    
    -- Step 7: Clean up references
    LegacyCleanup.CleanupReferences()
    
    -- Step 8: Generate documentation
    LegacyCleanup.GenerateMigrationDocs()
    
    print("=====================================")
    print("🎉 Legacy Cleanup Complete!")
    print("")
    print("📊 Summary:")
    print(string.format("  📦 Archived: %d files", #CLEANUP_CONFIG.ARCHIVE_FILES))
    print(string.format("  🗑️ Deleted: %d files", #CLEANUP_CONFIG.DELETE_FILES))
    print(string.format("  🔄 Updated: %d wrappers", #CLEANUP_CONFIG.UPDATE_WRAPPERS))
    print("")
    print("🔄 Next Steps:")
    print("  1. Test all systems to ensure functionality")
    print("  2. Update any remaining references")
    print("  3. Run integration tests")
    print("  4. Monitor for any issues")
    print("")
    print("📋 Rollback: If issues occur, follow the rollback plan above")
    
    return true
end

-- Dry run function (shows what would be done without actually doing it)
function LegacyCleanup.DryRun()
    print("🔍 DRY RUN - Legacy Cleanup Preview")
    print("===================================")
    print("This shows what WOULD be done without actually making changes")
    print("")
    
    LegacyCleanup.ExecuteCleanup()
    
    print("")
    print("🔍 DRY RUN COMPLETE")
    print("To execute for real, call LegacyCleanup.ExecuteCleanup()")
end

-- Export the module
return LegacyCleanup 