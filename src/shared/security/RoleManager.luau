-- RoleManager.luau
-- Enterprise-level Role-Based Access Control (RBAC) system
-- Provides hierarchical permissions, resource-level access, and dynamic role management

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local RoleManager = {}
RoleManager.__index = RoleManager

-- DataStore for persistent role data
local RoleStore = DataStoreService:GetDataStore("PlayerRoles_v1")
local PermissionStore = DataStoreService:GetDataStore("RolePermissions_v1")

-- Configuration
local CONFIG = {
    -- Role hierarchy levels (higher number = more permissions)
    ROLE_HIERARCHY = {
        GUEST = 0,
        PLAYER = 10,
        VIP = 20,
        MODERATOR = 50,
        ADMIN = 80,
        SUPER_ADMIN = 100
    },
    
    -- Permission categories
    PERMISSION_CATEGORIES = {
        SYSTEM = "SYSTEM",
        MODERATION = "MODERATION",
        ECONOMY = "ECONOMY",
        BUILDING = "BUILDING",
        SOCIAL = "SOCIAL",
        ANALYTICS = "ANALYTICS"
    },
    
    -- Default role assignment
    DEFAULT_ROLE = "PLAYER",
    
    -- Security settings
    REQUIRE_CONFIRMATION_FOR_ROLE_CHANGES = true,
    LOG_ALL_PERMISSION_CHECKS = false,
    CACHE_PERMISSIONS = true,
    CACHE_DURATION = 300, -- 5 minutes
    
    DEBUG_MODE = false
}

-- Predefined roles with their permissions
local ROLE_DEFINITIONS = {
    GUEST = {
        name = "Guest",
        description = "Limited access for unregistered users",
        hierarchy = CONFIG.ROLE_HIERARCHY.GUEST,
        permissions = {
            "view_public_content",
            "basic_interaction"
        },
        restrictions = {
            "no_building",
            "no_economy",
            "limited_chat"
        }
    },
    
    PLAYER = {
        name = "Player",
        description = "Standard player with basic game access",
        hierarchy = CONFIG.ROLE_HIERARCHY.PLAYER,
        permissions = {
            "view_public_content",
            "basic_interaction",
            "place_items",
            "purchase_items",
            "use_inventory",
            "chat_public",
            "save_progress"
        },
        restrictions = {
            "no_admin_areas",
            "limited_item_value"
        }
    },
    
    VIP = {
        name = "VIP Player",
        description = "Premium player with enhanced privileges",
        hierarchy = CONFIG.ROLE_HIERARCHY.VIP,
        permissions = {
            "view_public_content",
            "basic_interaction",
            "place_items",
            "purchase_items",
            "use_inventory",
            "chat_public",
            "save_progress",
            "access_vip_areas",
            "enhanced_building",
            "priority_support",
            "exclusive_items"
        },
        restrictions = {
            "no_admin_areas"
        }
    },
    
    MODERATOR = {
        name = "Moderator",
        description = "Community moderator with enforcement powers",
        hierarchy = CONFIG.ROLE_HIERARCHY.MODERATOR,
        permissions = {
            "view_public_content",
            "basic_interaction",
            "place_items",
            "purchase_items",
            "use_inventory",
            "chat_public",
            "save_progress",
            "access_vip_areas",
            "enhanced_building",
            "moderate_chat",
            "kick_players",
            "temporary_ban",
            "view_player_reports",
            "access_moderation_tools",
            "view_basic_analytics"
        },
        restrictions = {
            "no_system_admin",
            "no_permanent_ban"
        }
    },
    
    ADMIN = {
        name = "Administrator",
        description = "Game administrator with extensive system access",
        hierarchy = CONFIG.ROLE_HIERARCHY.ADMIN,
        permissions = {
            "view_public_content",
            "basic_interaction",
            "place_items",
            "purchase_items",
            "use_inventory",
            "chat_public",
            "save_progress",
            "access_vip_areas",
            "enhanced_building",
            "moderate_chat",
            "kick_players",
            "temporary_ban",
            "permanent_ban",
            "view_player_reports",
            "access_moderation_tools",
            "view_basic_analytics",
            "access_admin_panel",
            "manage_economy",
            "system_monitoring",
            "player_management",
            "content_management"
        },
        restrictions = {
            "no_system_config"
        }
    },
    
    SUPER_ADMIN = {
        name = "Super Administrator",
        description = "Highest level access with all permissions",
        hierarchy = CONFIG.ROLE_HIERARCHY.SUPER_ADMIN,
        permissions = {
            "*" -- Wildcard - all permissions
        },
        restrictions = {}
    }
}

-- Resource-specific permissions
local RESOURCE_PERMISSIONS = {
    -- Building system
    BUILDING = {
        "place_basic_items",
        "place_advanced_items",
        "place_exclusive_items",
        "delete_own_items",
        "delete_any_items",
        "modify_terrain",
        "access_building_tools"
    },
    
    -- Economy system
    ECONOMY = {
        "purchase_basic_items",
        "purchase_premium_items",
        "sell_items",
        "trade_items",
        "access_marketplace",
        "manage_currency",
        "view_economy_stats"
    },
    
    -- Social features
    SOCIAL = {
        "chat_public",
        "chat_private",
        "create_groups",
        "join_groups",
        "invite_friends",
        "view_profiles"
    },
    
    -- Moderation tools
    MODERATION = {
        "view_reports",
        "moderate_chat",
        "kick_players",
        "temporary_ban",
        "permanent_ban",
        "access_mod_tools",
        "review_appeals"
    },
    
    -- System administration
    SYSTEM = {
        "access_admin_panel",
        "system_monitoring",
        "manage_servers",
        "configure_settings",
        "emergency_shutdown",
        "data_management"
    },
    
    -- Analytics and reporting
    ANALYTICS = {
        "view_basic_stats",
        "view_detailed_analytics",
        "export_data",
        "create_reports",
        "access_dashboards"
    }
}

function RoleManager.new()
    local self = setmetatable({}, RoleManager)
    
    -- Player role assignments
    self.playerRoles = {}
    
    -- Permission cache
    self.permissionCache = {}
    
    -- Role change history
    self.roleHistory = {}
    
    -- Permission check statistics
    self.stats = {
        totalPermissionChecks = 0,
        deniedPermissions = 0,
        roleChanges = 0,
        cacheHits = 0,
        cacheMisses = 0
    }
    
    -- Cleanup timer
    self.lastCleanup = tick()
    self.cleanupInterval = 600 -- Clean up every 10 minutes
    
    return self
end

function RoleManager:Initialize()
    print("[RoleManager] Initializing enterprise RBAC system...")
    
    -- Setup player tracking
    self:SetupPlayerTracking()
    
    -- Load persistent role data
    self:LoadRoleData()
    
    -- Start cleanup loop
    self:StartCleanupLoop()
    
    -- Initialize default roles
    self:InitializeDefaultRoles()
    
    print("[RoleManager] RBAC system initialized")
    return true
end

function RoleManager:SetupPlayerTracking()
    -- Track existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:InitializePlayerRole(player)
    end
    
    -- Track new players
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerRole(player)
    end)
    
    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerRole(player)
    end)
end

function RoleManager:InitializePlayerRole(player)
    local userId = player.UserId
    
    -- Load player's role from persistent storage or assign default
    local savedRole = self:LoadPlayerRole(player)
    local role = savedRole or self:DetermineDefaultRole(player)
    
    self.playerRoles[userId] = {
        role = role,
        assignedAt = tick(),
        assignedBy = "SYSTEM",
        lastChecked = 0
    }
    
    -- Initialize permission cache
    self.permissionCache[userId] = {
        permissions = {},
        cachedAt = 0,
        expiresAt = 0
    }
    
    print("[RoleManager] Initialized role for player:", player.Name, "- Role:", role)
end

function RoleManager:CleanupPlayerRole(player)
    local userId = player.UserId
    
    -- Save current role before cleanup
    self:SavePlayerRole(player)
    
    -- Clear cache and tracking
    self.permissionCache[userId] = nil
    
    print("[RoleManager] Cleaned up role data for player:", player.Name)
end

function RoleManager:DetermineDefaultRole(player)
    -- Check if player is a known admin
    local adminIds = {
        3246397734, -- Default Roblox test account ID
        7768610061  -- Your actual user ID (Xdjpearsonx)
    }
    
    for _, adminId in ipairs(adminIds) do
        if player.UserId == adminId then
            return "SUPER_ADMIN"
        end
    end
    
    -- Check for admin attribute
    if player:GetAttribute("IsAdmin") == true then
        return "ADMIN"
    end
    
    -- Check for VIP status (placeholder - integrate with your VIP system)
    if player:GetAttribute("IsVIP") == true then
        return "VIP"
    end
    
    -- Default role
    return CONFIG.DEFAULT_ROLE
end

function RoleManager:AssignRole(player, newRole, assignedBy)
    local userId = player.UserId
    
    -- Validate new role
    if not ROLE_DEFINITIONS[newRole] then
        warn("[RoleManager] Invalid role:", newRole)
        return false, "Invalid role specified"
    end
    
    -- Get current role
    local currentRole = self:GetPlayerRole(player)
    
    -- Check if assigner has permission to assign this role
    if assignedBy and not self:CanAssignRole(assignedBy, newRole) then
        warn("[RoleManager] Insufficient permissions to assign role:", newRole)
        return false, "Insufficient permissions to assign role"
    end
    
    -- Record role change
    self:RecordRoleChange(player, currentRole, newRole, assignedBy)
    
    -- Update player role
    self.playerRoles[userId] = {
        role = newRole,
        assignedAt = tick(),
        assignedBy = assignedBy and assignedBy.Name or "SYSTEM",
        lastChecked = 0
    }
    
    -- Clear permission cache
    self:ClearPlayerPermissionCache(player)
    
    -- Save to persistent storage
    self:SavePlayerRole(player)
    
    -- Update statistics
    self.stats.roleChanges = self.stats.roleChanges + 1
    
    print("[RoleManager] Assigned role", newRole, "to", player.Name, "by", assignedBy and assignedBy.Name or "SYSTEM")
    return true, "Role assigned successfully"
end

function RoleManager:GetPlayerRole(player)
    local userId = player.UserId
    local roleData = self.playerRoles[userId]
    
    if roleData then
        return roleData.role
    end
    
    -- Initialize if not found
    self:InitializePlayerRole(player)
    return self.playerRoles[userId].role
end

function RoleManager:HasPermission(player, permission, resource)
    local userId = player.UserId
    
    -- Update statistics
    self.stats.totalPermissionChecks = self.stats.totalPermissionChecks + 1
    
    -- Check cache first
    if CONFIG.CACHE_PERMISSIONS then
        local cached = self:GetCachedPermission(player, permission, resource)
        if cached ~= nil then
            self.stats.cacheHits = self.stats.cacheHits + 1
            if not cached then
                self.stats.deniedPermissions = self.stats.deniedPermissions + 1
            end
            return cached
        end
        self.stats.cacheMisses = self.stats.cacheMisses + 1
    end
    
    -- Get player role
    local role = self:GetPlayerRole(player)
    local roleDefinition = ROLE_DEFINITIONS[role]
    
    if not roleDefinition then
        warn("[RoleManager] Unknown role:", role)
        return false
    end
    
    -- Check for wildcard permission (Super Admin)
    if self:HasWildcardPermission(roleDefinition) then
        self:CachePermission(player, permission, resource, true)
        return true
    end
    
    -- Check specific permission
    local hasPermission = self:CheckSpecificPermission(roleDefinition, permission, resource)
    
    -- Cache result
    if CONFIG.CACHE_PERMISSIONS then
        self:CachePermission(player, permission, resource, hasPermission)
    end
    
    -- Log if enabled
    if CONFIG.LOG_ALL_PERMISSION_CHECKS then
        print("[RoleManager] Permission check:", player.Name, permission, resource or "global", hasPermission and "GRANTED" or "DENIED")
    end
    
    if not hasPermission then
        self.stats.deniedPermissions = self.stats.deniedPermissions + 1
    end
    
    return hasPermission
end

function RoleManager:HasWildcardPermission(roleDefinition)
    for _, permission in ipairs(roleDefinition.permissions) do
        if permission == "*" then
            return true
        end
    end
    return false
end

function RoleManager:CheckSpecificPermission(roleDefinition, permission, resource)
    -- Check direct permissions
    for _, rolePermission in ipairs(roleDefinition.permissions) do
        if rolePermission == permission then
            return true
        end
    end
    
    -- Check resource-specific permissions
    if resource then
        local resourcePermissions = RESOURCE_PERMISSIONS[resource:upper()]
        if resourcePermissions then
            for _, resourcePermission in ipairs(resourcePermissions) do
                if resourcePermission == permission then
                    -- Check if role has this resource permission
                    for _, rolePermission in ipairs(roleDefinition.permissions) do
                        if rolePermission == resourcePermission then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    -- Check hierarchical permissions (higher roles inherit lower role permissions)
    local currentHierarchy = roleDefinition.hierarchy
    for roleName, definition in pairs(ROLE_DEFINITIONS) do
        if definition.hierarchy < currentHierarchy then
            for _, lowerPermission in ipairs(definition.permissions) do
                if lowerPermission == permission then
                    return true
                end
            end
        end
    end
    
    return false
end

function RoleManager:CanAssignRole(assigner, targetRole)
    if not assigner then
        return true -- System can assign any role
    end
    
    local assignerRole = self:GetPlayerRole(assigner)
    local assignerDefinition = ROLE_DEFINITIONS[assignerRole]
    local targetDefinition = ROLE_DEFINITIONS[targetRole]
    
    if not assignerDefinition or not targetDefinition then
        return false
    end
    
    -- Check if assigner has wildcard permissions
    if self:HasWildcardPermission(assignerDefinition) then
        return true
    end
    
    -- Check if assigner has higher hierarchy than target role
    return assignerDefinition.hierarchy > targetDefinition.hierarchy
end

function RoleManager:GetCachedPermission(player, permission, resource)
    local userId = player.UserId
    local cache = self.permissionCache[userId]
    
    if not cache then
        return nil
    end
    
    local currentTime = tick()
    if currentTime > cache.expiresAt then
        -- Cache expired
        cache.permissions = {}
        cache.cachedAt = 0
        cache.expiresAt = 0
        return nil
    end
    
    local key = permission .. (resource and (":" .. resource) or "")
    return cache.permissions[key]
end

function RoleManager:CachePermission(player, permission, resource, hasPermission)
    local userId = player.UserId
    local cache = self.permissionCache[userId]
    
    if not cache then
        return
    end
    
    local currentTime = tick()
    
    -- Initialize cache if empty or expired
    if currentTime > cache.expiresAt then
        cache.permissions = {}
        cache.cachedAt = currentTime
        cache.expiresAt = currentTime + CONFIG.CACHE_DURATION
    end
    
    local key = permission .. (resource and (":" .. resource) or "")
    cache.permissions[key] = hasPermission
end

function RoleManager:ClearPlayerPermissionCache(player)
    local userId = player.UserId
    if self.permissionCache[userId] then
        self.permissionCache[userId].permissions = {}
        self.permissionCache[userId].expiresAt = 0
    end
end

function RoleManager:RecordRoleChange(player, oldRole, newRole, assignedBy)
    local userId = player.UserId
    
    if not self.roleHistory[userId] then
        self.roleHistory[userId] = {}
    end
    
    local change = {
        timestamp = tick(),
        oldRole = oldRole,
        newRole = newRole,
        assignedBy = assignedBy and assignedBy.Name or "SYSTEM",
        reason = "Role assignment"
    }
    
    table.insert(self.roleHistory[userId], change)
    
    -- Limit history size
    if #self.roleHistory[userId] > 50 then
        table.remove(self.roleHistory[userId], 1)
    end
    
    print("[RoleManager] Recorded role change for", player.Name, ":", oldRole, "->", newRole)
end

function RoleManager:GetPlayerRoleHistory(player)
    local userId = player.UserId
    return self.roleHistory[userId] or {}
end

function RoleManager:GetRoleDefinition(roleName)
    return ROLE_DEFINITIONS[roleName]
end

function RoleManager:GetAllRoles()
    local roles = {}
    for roleName, definition in pairs(ROLE_DEFINITIONS) do
        table.insert(roles, {
            name = roleName,
            displayName = definition.name,
            description = definition.description,
            hierarchy = definition.hierarchy,
            permissionCount = #definition.permissions
        })
    end
    
    -- Sort by hierarchy
    table.sort(roles, function(a, b)
        return a.hierarchy < b.hierarchy
    end)
    
    return roles
end

function RoleManager:GetPlayersWithRole(roleName)
    local players = {}
    
    for userId, roleData in pairs(self.playerRoles) do
        if roleData.role == roleName then
            local player = Players:GetPlayerByUserId(userId)
            if player then
                table.insert(players, {
                    player = player,
                    assignedAt = roleData.assignedAt,
                    assignedBy = roleData.assignedBy
                })
            end
        end
    end
    
    return players
end

function RoleManager:LoadPlayerRole(player)
    -- Load role from DataStore
    local success, result = pcall(function()
        return RoleStore:GetAsync(tostring(player.UserId))
    end)
    
    if success and result then
        return result.role
    end
    
    return nil
end

function RoleManager:SavePlayerRole(player)
    -- Save role to DataStore
    local userId = player.UserId
    local roleData = self.playerRoles[userId]
    
    if not roleData then
        return
    end
    
    local success, result = pcall(function()
        return RoleStore:SetAsync(tostring(userId), {
            role = roleData.role,
            assignedAt = roleData.assignedAt,
            assignedBy = roleData.assignedBy
        })
    end)
    
    if not success then
        warn("[RoleManager] Failed to save role data:", result)
    end
end

function RoleManager:LoadRoleData()
    -- Load existing role assignments
    print("[RoleManager] Loading persistent role data...")
    -- Implementation would load from DataStore
end

function RoleManager:InitializeDefaultRoles()
    -- Ensure all role definitions are properly configured
    for roleName, definition in pairs(ROLE_DEFINITIONS) do
        if not definition.hierarchy then
            warn("[RoleManager] Role missing hierarchy:", roleName)
        end
        if not definition.permissions then
            warn("[RoleManager] Role missing permissions:", roleName)
        end
    end
    
    print("[RoleManager] Default roles initialized")
end

function RoleManager:StartCleanupLoop()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        if currentTime - self.lastCleanup >= self.cleanupInterval then
            self:PerformCleanup(currentTime)
            self.lastCleanup = currentTime
        end
    end)
end

function RoleManager:PerformCleanup(currentTime)
    local expiredCaches = 0
    
    -- Clean up expired permission caches
    for userId, cache in pairs(self.permissionCache) do
        if currentTime > cache.expiresAt and cache.expiresAt > 0 then
            cache.permissions = {}
            cache.expiresAt = 0
            expiredCaches = expiredCaches + 1
        end
    end
    
    -- Clean up old role history
    for userId, history in pairs(self.roleHistory) do
        local validHistory = {}
        for _, change in ipairs(history) do
            if currentTime - change.timestamp < 2592000 then -- Keep last 30 days
                table.insert(validHistory, change)
            end
        end
        self.roleHistory[userId] = validHistory
    end
    
    if expiredCaches > 0 then
        print("[RoleManager] Cleaned up", expiredCaches, "expired permission caches")
    end
end

function RoleManager:GetRoleStats()
    return {
        totalPermissionChecks = self.stats.totalPermissionChecks,
        deniedPermissions = self.stats.deniedPermissions,
        roleChanges = self.stats.roleChanges,
        cacheHits = self.stats.cacheHits,
        cacheMisses = self.stats.cacheMisses,
        cacheHitRate = self.stats.totalPermissionChecks > 0 and (self.stats.cacheHits / self.stats.totalPermissionChecks * 100) or 0,
        denialRate = self.stats.totalPermissionChecks > 0 and (self.stats.deniedPermissions / self.stats.totalPermissionChecks * 100) or 0
    }
end

function RoleManager:GetPlayerRoleInfo(player)
    local userId = player.UserId
    local roleData = self.playerRoles[userId]
    
    if not roleData then
        return nil
    end
    
    local roleDefinition = ROLE_DEFINITIONS[roleData.role]
    
    return {
        role = roleData.role,
        displayName = roleDefinition and roleDefinition.name or roleData.role,
        description = roleDefinition and roleDefinition.description or "Unknown role",
        hierarchy = roleDefinition and roleDefinition.hierarchy or 0,
        assignedAt = roleData.assignedAt,
        assignedBy = roleData.assignedBy,
        permissionCount = roleDefinition and #roleDefinition.permissions or 0,
        hasWildcard = roleDefinition and self:HasWildcardPermission(roleDefinition) or false
    }
end

function RoleManager:Cleanup()
    print("[RoleManager] Cleaning up...")
    
    -- Save all player roles
    for userId, _ in pairs(self.playerRoles) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerRole(player)
        end
    end
    
    -- Clear all data
    self.playerRoles = {}
    self.permissionCache = {}
    self.roleHistory = {}
    
    print("[RoleManager] Cleanup complete")
end

return RoleManager 