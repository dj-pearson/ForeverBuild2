-- Toggle Model Logging Script
-- Use this to control ModelDisplayUtil logging levels during runtime

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the commands to be available
wait(2)

print("=== MODEL DISPLAY LOGGING CONTROLLER ===")
print("Available commands:")
print("  • Detailed: Shows all models and parts")
print("  • Quiet: Shows only important items (limited)")  
print("  • Silent: Shows almost nothing")
print("  • Status: Shows current settings")

-- Try to get the logging command
local loggingCommand = ReplicatedStorage:FindFirstChild("ModelDisplayLogging")
if not loggingCommand then
    print("❌ ModelDisplayLogging command not found. Make sure ModelDisplayUtil is loaded.")
    return
end

-- Function to set logging mode
local function setLoggingMode(mode)
    local result = loggingCommand:Invoke(mode)
    print("✅ " .. result)
end

-- Show current status
print("\n📊 Current Status:")
local status = loggingCommand:Invoke("status")
print(status)

print("\n🎛️ Quick Mode Changes:")
print("Copy and paste one of these commands in the command bar:")
print("")
print("-- Enable detailed logging (for debugging)")
print('game:GetService("ReplicatedStorage").ModelDisplayLogging:Invoke("detailed")')
print("")
print("-- Enable quiet mode (recommended for normal use)")
print('game:GetService("ReplicatedStorage").ModelDisplayLogging:Invoke("quiet")')
print("")
print("-- Enable silent mode (minimal logging)")
print('game:GetService("ReplicatedStorage").ModelDisplayLogging:Invoke("silent")')
print("")
print("-- Check current status")
print('game:GetService("ReplicatedStorage").ModelDisplayLogging:Invoke("status")')

-- Set to quiet mode by default for immediate relief
print("\n🔧 Setting to quiet mode for immediate performance improvement...")
setLoggingMode("quiet")

print("\n✅ Model logging optimization complete!")
print("The massive log spam should now be significantly reduced.")
print("Use the commands above to adjust logging as needed.") 