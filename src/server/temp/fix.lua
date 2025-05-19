-- This script will fix the ItemPurchaseHandler.luau file by adding your actual player ID to the admin list

-- First, read the current file content
local filePath = "src/server/ItemPurchaseHandler.luau"
local file = io.open(filePath, "r")
if not file then
    print("Failed to open file:", filePath)
    return
end

local content = file:read("*all")
file:close()

-- Replace the sample user ID with your actual ID
content = content:gsub("5329862[^\n]*", "7768610061  -- Your actual user ID (Xdjpearsonx)")

-- Write the updated content back to the file
file = io.open(filePath, "w")
if not file then
    print("Failed to open file for writing:", filePath)
    return
end

file:write(content)
file:close()

print("Successfully updated admin ID in", filePath)
