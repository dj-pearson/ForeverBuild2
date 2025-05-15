-- Install the fixed InteractionSystemModule
print("Installing fixed InteractionSystemModule...")

-- Check if the fixed module exists
local fixedModulePath = script.Parent.src.client.interaction.InteractionSystemModule_fixed
if not fixedModulePath then
    error("Fixed InteractionSystemModule not found at expected path.")
    return
end

-- Backup the current module
local currentModulePath = script.Parent.src.client.interaction.InteractionSystemModule
if currentModulePath then
    -- Create a backup with timestamp
    local backupName = "InteractionSystemModule_backup_" .. os.time() .. ".lua"
    local backupModule = currentModulePath:Clone()
    backupModule.Name = backupName
    backupModule.Parent = currentModulePath.Parent
    print("Backed up current module as:", backupName)
end

-- Install the fixed module
local fixedModule = fixedModulePath:Clone()
fixedModule.Name = "InteractionSystemModule" -- Rename to replace the original
fixedModule.Parent = script.Parent.src.client.interaction

-- Remove the _fixed version to avoid confusion
fixedModulePath:Destroy()

print("Installation complete! The fixed InteractionSystemModule has been installed.")
print("The interaction system now correctly handles both Items folder objects and Main folder objects like the Board.")
print("Changes made:")
print("1. Added special handling for objects in the Main folder")
print("2. Fixed logic in GetPlacedItemFromPart to better identify interactive objects")
print("3. Added support for interacting with Main folder items through InteractWithMain event")
print("4. Improved ShowInteractionUI to better handle different types of objects")
print("5. Enhanced error handling throughout the module")
