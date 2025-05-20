print("--- THIS IS THE VERY LATEST VERSION OF DirectInventoryUI.client.luau, TIMESTAMP: " .. os.time() .. " ---")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedModule = nil
local InventoryUIModule = nil

local MAX_WAIT_TIME = 15 -- seconds, increased wait time
local waitInterval = 0.1
local timeWaited = 0

print("DirectInventoryUI: Waiting for SharedModule and its InventoryUI...")

-- Wait for SharedModule and InventoryUI to be ready
repeat
    local sharedModuleInstance = ReplicatedStorage:FindFirstChild("shared")
    if sharedModuleInstance then
        local success, module = pcall(function()
            return require(sharedModuleInstance)
        end)
        if success and module then
            SharedModule = module
            if module.InventoryUI and typeof(module.InventoryUI.Toggle) == "function" then
                InventoryUIModule = module.InventoryUI
                print("DirectInventoryUI: SharedModule.InventoryUI found and ready.")
                break
            else
                -- print("DirectInventoryUI: SharedModule found, but InventoryUI or Toggle function is missing. Will retry...")
            end
        elseif not success then
            warn("DirectInventoryUI: Error requiring SharedModule: ", module) -- 'module' is error message on pcall fail
        end
    end
    task.wait(waitInterval)
    timeWaited = timeWaited + waitInterval
until InventoryUIModule or timeWaited >= MAX_WAIT_TIME

if not InventoryUIModule then
    warn("DirectInventoryUI: Timed out waiting for SharedModule.InventoryUI. The main inventory system might not be available.")
    -- Optionally, destroy this script if it has no other purpose
    -- script:Destroy()
    return
end

print("DirectInventoryUI: SharedModule.InventoryUI is confirmed available.")

-- Check if SharedModule.InventoryUI has already created its button
-- This is a bit indirect; ideally, InventoryUIModule would have a flag or method to check this.
-- For now, we assume client_core.luau or InventoryUILoader handles initialization including button creation.

local existingSharedInventoryButton = nil
if playerGui and SharedModule and SharedModule.UI_NAMES and SharedModule.UI_NAMES.INVENTORY_MAIN_BUTTON then
    local mainInventoryScreenGui = playerGui:FindFirstChild(SharedModule.UI_NAMES.INVENTORY_SCREEN_GUI, true) -- Search recursively
    if mainInventoryScreenGui then
        existingSharedInventoryButton = mainInventoryScreenGui:FindFirstChild(SharedModule.UI_NAMES.INVENTORY_MAIN_BUTTON)
    end
end

if existingSharedInventoryButton then
    print("DirectInventoryUI: Detected that SharedModule.InventoryUI has already created its button (", existingSharedInventoryButton:GetFullName(), "). DirectInventoryUI will not create a duplicate button.")
else
    print("DirectInventoryUI: SharedModule.InventoryUI did NOT create a button, or it couldn't be found. This script will NOT create a fallback button anymore.")
    -- REMOVED FALLBACK BUTTON CREATION LOGIC
end

-- Keybind handling (TAB key) - This can remain as it's a user input listener
local function onInputBegan(input, gameProcessedEvent)
    if gameProcessedEvent then return end

    if input.KeyCode == Enum.KeyCode.Tab then
        if InventoryUIModule and InventoryUIModule.Toggle then
            print("DirectInventoryUI: TAB key pressed, calling SharedModule.InventoryUI.Toggle()")
            local success, err = pcall(function()
                InventoryUIModule.Toggle()
            end)
            if not success then
                warn("DirectInventoryUI: Error calling InventoryUIModule.Toggle():", err)
            end
        else
            warn("DirectInventoryUI: TAB pressed, but InventoryUIModule or Toggle is not available.")
        end
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

print("DirectInventoryUI: Setup complete. TAB key is bound to SharedModule.InventoryUI.Toggle. No button created by this script.")

-- Ensure the SharedModule.InventoryUI is initialized if it hasn't been already
-- This is often handled by client_core.luau or an InventoryUILoader script.
-- If InventoryUIModule.Initialize is not idempotent or if calling it multiple times is an issue,
-- this part might need more careful handling (e.g., checking an IsInitialized flag).
task.wait(1) -- Give other scripts a moment to initialize first
if InventoryUIModule and typeof(InventoryUIModule.Initialize) == "function" then
    -- Check if it's already initialized (assuming it sets a flag or similar)
    -- This is a common pattern, but might not be present in your specific InventoryUI
    if not InventoryUIModule.IsInitialized then -- Replace with actual check if available
        print("DirectInventoryUI: Attempting to call Initialize on SharedModule.InventoryUI as a fallback...")
        local initSuccess, initErr = pcall(function()
            InventoryUIModule.Initialize(playerGui) -- Pass playerGui if needed by Initialize
        end)
        if initSuccess then
            print("DirectInventoryUI: Successfully called SharedModule.InventoryUI.Initialize().")
        else
            warn("DirectInventoryUI: Error calling SharedModule.InventoryUI.Initialize():", initErr)
        end
    else
        print("DirectInventoryUI: SharedModule.InventoryUI appears to be already initialized.")
    end
else
    print("DirectInventoryUI: SharedModule.InventoryUI.Initialize function not found. Assuming it's initialized elsewhere.")
end 