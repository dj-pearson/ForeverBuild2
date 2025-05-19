-- DataService.luau
-- Handles saving and loading data from DataStore

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

local DataService = {}
DataService.__index = DataService

-- Configuration
local USE_MOCK_DATA = false -- Enable actual DataStore saving
local AUTO_SAVE_INTERVAL = 300 -- 5 minutes

function DataService.new()
    local self = setmetatable({}, DataService)
    
    if isServer then
        -- Cache of data
        self.dataCache = {}
        
        -- Mock data for testing
        self.mockData = {
            PlayerData = {},
            WorldData = {}
        }
        
        -- DataStore instances
        self.dataStores = {
            PlayerData = DataStoreService:GetDataStore("PlayerData"),
            WorldData = DataStoreService:GetDataStore("WorldData")
        }
        
        -- Setup auto-save
        if not USE_MOCK_DATA then
            self:SetupAutoSave()
        end
    end
    
    return self
end

-- Save data to DataStore or mock storage
function DataService:SaveData(storeName, key, data)
    if not isServer then
        warn("DataService: Cannot save data from client")
        return false
    end
    
    -- Support both SaveData(storeName, data) and SaveData(storeName, key, data) formats
    if data == nil then
        data = key
        key = storeName
        storeName = "WorldData"
    end
    
    if USE_MOCK_DATA then
        -- Save to mock data
        print("DataService: Saving to mock data:", storeName, key)
        if storeName == "WorldData" then
            self.mockData.WorldData = data
        else
            if not self.mockData[storeName] then
                self.mockData[storeName] = {}
            end
            self.mockData[storeName][key] = data
        end
        return true
    end
    
    -- Save to DataStore
    local dataStore = self.dataStores[storeName]
    if not dataStore then
        warn("DataService: DataStore not found for", storeName)
        return false
    end
    
    -- Cache the data
    if not self.dataCache[storeName] then
        self.dataCache[storeName] = {}
    end
    self.dataCache[storeName][key] = data
    
    -- Try to save to DataStore
    local success, result = pcall(function()
        return dataStore:SetAsync(key, data)
    end)
    
    if success then
        print("DataService: Successfully saved data for", storeName, key)
        return true
    else
        warn("DataService: Failed to save data for", storeName, key, "-", result)
        return false
    end
end

-- Load data from DataStore or mock storage
function DataService:LoadData(storeName, key)
    if not isServer then
        warn("DataService: Cannot load data from client")
        return nil
    end
    
    -- Support both LoadData(storeName) and LoadData(storeName, key) formats
    if key == nil then
        key = storeName
        storeName = "WorldData"
    end
    
    if USE_MOCK_DATA then
        -- Load from mock data
        print("DataService: Loading from mock data:", storeName, key)
        if storeName == "WorldData" then
            return self.mockData.WorldData
        else
            if not self.mockData[storeName] then
                return nil
            end
            return self.mockData[storeName][key]
        end
    end
    
    -- Check cache first
    if self.dataCache[storeName] and self.dataCache[storeName][key] then
        return self.dataCache[storeName][key]
    end
    
    -- Load from DataStore
    local dataStore = self.dataStores[storeName]
    if not dataStore then
        warn("DataService: DataStore not found for", storeName)
        return nil
    end
    
    local success, result = pcall(function()
        return dataStore:GetAsync(key)
    end)
    
    if success then
        -- Cache the result
        if not self.dataCache[storeName] then
            self.dataCache[storeName] = {}
        end
        self.dataCache[storeName][key] = result
        
        return result
    else
        warn("DataService: Failed to load data for", storeName, key, "-", result)
        return nil
    end
end

-- Clear data in a store
function DataService:ClearData(storeName, key)
    if not isServer then
        warn("DataService: Cannot clear data from client")
        return false
    end
    
    if USE_MOCK_DATA then
        -- Clear from mock data
        print("DataService: Clearing mock data:", storeName, key)
        if key then
            if self.mockData[storeName] then
                self.mockData[storeName][key] = nil
            end
        else
            self.mockData[storeName] = {}
        end
        return true
    end
    
    -- Clear from cache
    if key then
        if self.dataCache[storeName] then
            self.dataCache[storeName][key] = nil
        end
    else
        self.dataCache[storeName] = {}
    end
    
    -- Clear from DataStore
    local dataStore = self.dataStores[storeName]
    if not dataStore then
        warn("DataService: DataStore not found for", storeName)
        return false
    end
    
    if key then
        local success, result = pcall(function()
            return dataStore:RemoveAsync(key)
        end)
        
        if success then
            print("DataService: Successfully cleared data for", storeName, key)
            return true
        else
            warn("DataService: Failed to clear data for", storeName, key, "-", result)
            return false
        end
    else
        -- Can't easily clear entire DataStore, just clear cache
        warn("DataService: Clearing entire DataStore not supported, only cleared cache")
        return false
    end
end

-- Setup auto-save for all cached data
function DataService:SetupAutoSave()
    if not isServer then return end
    
    -- Create auto-save coroutine
    spawn(function()
        while true do
            wait(AUTO_SAVE_INTERVAL)
            self:SaveAllData()
        end
    end)
    
    -- Also save on server shutdown
    game:BindToClose(function()
        self:SaveAllData()
    end)
    
    print("DataService: Auto-save setup with interval", AUTO_SAVE_INTERVAL, "seconds")
end

-- Save all cached data
function DataService:SaveAllData()
    if not isServer then return end
    
    print("DataService: Performing auto-save of all data")
    
    for storeName, storeData in pairs(self.dataCache) do
        for key, data in pairs(storeData) do
            self:SaveData(storeName, key, data)
        end
    end
    
    print("DataService: Auto-save completed")
end

-- Initialize and register with SharedModule
function DataService:Initialize(sharedModule)
    print("DataService: Initializing...")
    
    -- Register with shared module if provided
    if sharedModule then
        sharedModule.DataService = self
    end
    
    print("DataService: Initialization complete")
    return self
end

return DataService 