-- TEST_INTERACTION_SYSTEM_FIXES.lua
-- This script tests the specific syntax fixes we made
-- May 14, 2025

local RunService = game:GetService("RunService")

-- Check if we're in Studio
if not RunService:IsStudio() then
    error("This script should only be run in Roblox Studio.")
    return
end

print("========== TESTING SPECIFIC SYNTAX FIXES ==========")

-- Test function to check for duplicate Constants definition
local function testConstantsDefinition(source)
    print("\n[TEST 1] Checking for duplicate Constants definition...")
    
    local constantsCount = 0
    for line in source:gmatch("[^\r\n]+") do
        if line:match("Constants not available from SharedModule") then
            constantsCount = constantsCount + 1
        end
    end
    
    if constantsCount > 1 then
        warn("✗ Found " .. constantsCount .. " Constants fallback blocks (should be only 1)")
        return false
    else
        print("✓ Constants is defined only once")
        return true
    end
end

-- Test function to check for the unexpected end symbol
local function testUnexpectedEnd(source)
    print("\n[TEST 2] Checking for unexpected 'end' symbol...")
    
    local lineNum = 0
    local foundIssue = false
    
    for line in source:gmatch("[^\r\n]+") do
        lineNum = lineNum + 1
        
        -- Look for the problematic pattern: end immediately after SharedModule check
        if line:match("^end$") and lineNum >= 60 and lineNum <= 70 then
            -- Check the previous non-empty line
            local prevLines = {}
            for prevLine in source:gmatch("[^\r\n]+") do
                table.insert(prevLines, prevLine)
                if #prevLines > lineNum then break end
            end
            
            -- If the previous meaningful line was the SharedModule check, this is our issue
            for i = lineNum - 1, lineNum - 5, -1 do
                if i > 0 and prevLines[i] and prevLines[i]:match("Successfully got Constants from SharedModule") then
                    foundIssue = true
                    warn("✗ Found unexpected 'end' at around line " .. lineNum)
                    break
                end
            end
        end
    end
    
    if not foundIssue then
        print("✓ No unexpected 'end' symbol found")
        return true
    end
    
    return false
end

-- Test function to check for ShowSimpleInteractionMenu closing brace
local function testShowSimpleInteractionMenu(source)
    print("\n[TEST 3] Checking ShowSimpleInteractionMenu closing brace...")
    
    -- Extract the function content
    local pattern = "function%s+InteractionSystem:ShowSimpleInteractionMenu.-end"
    local functionStr = source:match(pattern)
    
    if not functionStr then
        warn("✗ Couldn't find ShowSimpleInteractionMenu function or it's incomplete")
        return false
    end
    
    -- Count opening and closing braces in the function
    local openBraces = 0
    local closeBraces = 0
    
    for line in functionStr:gmatch("[^\r\n]+") do
        -- Count opening braces in this line
        for _ in line:gmatch("{") do
            openBraces = openBraces + 1
        end
        
        -- Count closing braces in this line
        for _ in line:gmatch("}") do
            closeBraces = closeBraces + 1
        end
    end
    
    if openBraces == closeBraces then
        print("✓ ShowSimpleInteractionMenu has matching braces: " .. openBraces .. " pairs")
        return true
    else
        warn("✗ ShowSimpleInteractionMenu has " .. openBraces .. " opening braces but " .. closeBraces .. " closing braces")
        return false
    end
end

-- Test function to check the UI module loading pattern
local function testUIModuleLoading(source)
    print("\n[TEST 4] Checking for proper UI module loading pattern...")
    
    local foundPattern = false
    
    -- Look for the improved loading pattern
    if source:match("if%s+not%s+%w+%s+or%s+typeof%s*%(%s*%w+%.%w+%s*%)%s*~=%s*\"function\"") then
        foundPattern = true
    end
    
    if foundPattern then
        print("✓ Found improved UI module loading pattern with fallback")
        return true
    else
        warn("✗ Could not find improved UI module loading pattern with fallback")
        return false
    end
end

-- Main test flow
local fixedModulePath = "src/client/interaction/InteractionSystemModule_fixed.lua"

-- Load the file content
local file = io.open(fixedModulePath, "r")
if not file then
    error("Fixed module not found at: " .. fixedModulePath)
    return
end

local content = file:read("*all")
file:close()

-- Run all tests
local test1 = testConstantsDefinition(content)
local test2 = testUnexpectedEnd(content)
local test3 = testShowSimpleInteractionMenu(content)
local test4 = testUIModuleLoading(content)

-- Present final results
print("\n========== TEST RESULTS ==========")

if test1 and test2 and test3 and test4 then
    print("\n✅ ALL SYNTAX FIX TESTS PASSED!")
    print("The InteractionSystemModule has been fixed successfully!")
else
    print("\n❌ SOME TESTS FAILED")
    print("Please review the errors above and make additional fixes.")
end

print("\n========== END OF TESTING ==========")
