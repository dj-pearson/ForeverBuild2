# ForeverBuild2 - Troubleshooting Guide

This document provides solutions for common issues you might encounter when using the new initialization structure.

## Common Errors

### "Attempted to call require with invalid argument(s)"

This error occurs when a script tries to require a module that doesn't exist or isn't accessible.

#### Solutions:

1. **Check the Instance Hierarchy**:
   - Make sure all instances are in the correct locations
   - Verify that the renamed "init" scripts are correctly placed

2. **Use WaitForChild**:
   ```lua
   local module = require(game:GetService("ReplicatedStorage"):WaitForChild("shared", 10))
   ```
   
3. **Use pcall for Safety**:
   ```lua
   local success, module = pcall(function()
       return require(game:GetService("ReplicatedStorage"):WaitForChild("shared", 10))
   end)
   
   if not success then
       warn("Failed to require module: ", module)
       -- Fallback behavior
   else
       -- Use module normally
   end
   ```

### "X is not a valid member of Y"

This error occurs when trying to access a property or method that doesn't exist.

#### Solutions:

1. **Check if the Module Loaded Correctly**:
   ```lua
   print("Module contents:", module)
   for key, value in pairs(module) do
       print("  - " .. key .. ": " .. tostring(value))
   end
   ```

2. **Add Nil Checks**:
   ```lua
   if module and module.SomeFunction then
       module.SomeFunction()
   else
       warn("Module or function not available")
   end
   ```

### "Script Timeout"

This occurs when a script takes too long to execute, often due to waiting for instances that never appear.

#### Solutions:

1. **Add Timeouts to WaitForChild**:
   ```lua
   local instance = parent:WaitForChild("ChildName", 10) -- 10 second timeout
   if not instance then
       warn("Child not found after 10 seconds")
       -- Fallback behavior
   end
   ```

2. **Use FindFirstChild with Fallbacks**:
   ```lua
   local instance = parent:FindFirstChild("ChildName")
   if not instance then
       warn("Child not found, creating a fallback")
       -- Create fallback or use alternative path
   end
   ```

## Path Resolution Issues

### After Renaming "inits" to "init"

When you rename the files from "inits" to "init" in Roblox Studio, the paths change. Here's how to handle it:

1. **For ModuleScripts**:
   - `script` refers to the ModuleScript itself
   - `script.Parent` refers to the container of the ModuleScript

2. **For LocalScripts/Scripts**:
   - `script` refers to the Script itself
   - `script.Parent` refers to the container of the Script

3. **Accessing Siblings**:
   - Use `script.Parent:WaitForChild("SiblingName")`

4. **Accessing Children**:
   - Use `script:WaitForChild("ChildName")`

## Debugging Tips

1. **Print Instance Paths**:
   ```lua
   print("Script path:", script:GetFullName())
   print("Parent path:", script.Parent:GetFullName())
   ```

2. **Check Module Contents**:
   ```lua
   local function printTable(t, indent)
       indent = indent or 0
       for k, v in pairs(t) do
           if type(v) == "table" then
               print(string.rep("  ", indent) .. k .. ":")
               printTable(v, indent + 1)
           else
               print(string.rep("  ", indent) .. k .. ": " .. tostring(v))
           end
       end
   end
   
   print("Module contents:")
   printTable(myModule)
   ```

3. **Trace Require Calls**:
   ```lua
   local function safeRequire(path)
       print("Attempting to require:", path:GetFullName())
       local success, result = pcall(function()
           return require(path)
       end)
       if success then
           print("Successfully required:", path:GetFullName())
           return result
       else
           warn("Failed to require:", path:GetFullName(), "Error:", result)
           return nil
       end
   end
   
   local myModule = safeRequire(game:GetService("ReplicatedStorage"):WaitForChild("shared"))
   ```

By following these troubleshooting steps, you should be able to resolve most common issues with the new initialization structure. 