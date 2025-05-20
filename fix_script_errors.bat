@echo off
echo Running script fixes...

powershell -Command "Write-Host 'Copying FixScriptErrors.luau to your clipboard...' -ForegroundColor Green"
powershell -Command "Get-Content -Path '%~dp0FixScriptErrors.luau' | Set-Clipboard"

echo.
echo The FixScriptErrors.luau script has been copied to your clipboard.
echo.
echo Instructions:
echo 1. Open your Roblox Studio project
echo 2. Create a new Script in ServerScriptService
echo 3. Paste the contents of your clipboard into this script
echo 4. Run the script once (it will fix all the errors)
echo 5. Save your project after the fixes are applied
echo.
echo.
echo See Documentation\SCRIPT_ERROR_FIXES.md for more details on what this fixes.
echo.
pause
