# Command Handler Fix

## Issue
The `/addadmincurrency` command was executing twice, resulting in:
- Double currency being added to admin accounts (2,000,000 instead of 1,000,000)
- Duplicate console logs
- Wasted server resources

## Root Cause
The `SetupAdminCommands` function was being called twice for each player:
1. Once in `Players.PlayerAdded` event
2. Again when connecting existing players during module initialization

This created duplicate event handlers for the same player's chat messages, causing each command to be processed multiple times.

## Solution
1. Added a tracking table `playersWithCommandHandlers` to keep track of which players already have command handlers established
2. Modified `SetupAdminCommands` to check if a player already has command handlers before connecting a new one
3. Added cleanup in the `PlayerRemoving` event to prevent memory leaks
4. Added detailed logging to help debug currency issues

## Testing
The fix ensures the `/addadmincurrency` command only executes once, correctly adding 1,000,000 coins instead of 2,000,000 coins to admin accounts.

## Implementation Details
The tracking mechanism uses the player's UserId as a key in the `playersWithCommandHandlers` table, making it efficient to check if a player already has command handlers set up.
