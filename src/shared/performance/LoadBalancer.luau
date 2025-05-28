-- LoadBalancer.luau
-- Enterprise-level load balancing system for optimal performance distribution
-- Part of Phase 2.3 Algorithm Optimization

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LoadBalancer = {}
LoadBalancer.__index = LoadBalancer

-- Configuration
local CONFIG = {
    -- Frame timing
    MAX_FRAME_TIME = 0.016, -- 60 FPS target (16ms per frame)
    TARGET_FRAME_TIME = 0.012, -- Target 12ms to leave buffer
    CRITICAL_FRAME_TIME = 0.020, -- 20ms is critical
    
    -- Task management
    MAX_TASKS_PER_FRAME = 100, -- Maximum tasks per frame
    MIN_TASKS_PER_FRAME = 10, -- Minimum tasks to process
    BATCH_SIZE = 25, -- Default batch size
    PRIORITY_BOOST_FACTOR = 2, -- Priority boost multiplier
    
    -- Adaptive settings
    ENABLE_ADAPTIVE_BALANCING = true, -- Automatically adjust based on performance
    ADAPTATION_INTERVAL = 1.0, -- How often to adapt (seconds)
    PERFORMANCE_HISTORY_SIZE = 30, -- Frames to keep in history
    
    -- Queue management
    MAX_QUEUE_SIZE = 10000, -- Maximum tasks in queue
    QUEUE_CLEANUP_INTERVAL = 5.0, -- Queue cleanup interval
    TASK_TIMEOUT = 30.0, -- Task timeout (seconds)
    
    -- Worker threads simulation
    ENABLE_WORKER_SIMULATION = true, -- Simulate multiple workers
    MAX_WORKERS = 4, -- Maximum simulated workers
    WORKER_EFFICIENCY = 0.8, -- Worker efficiency factor
    
    -- Memory management
    MEMORY_THRESHOLD = 100 * 1024 * 1024, -- 100MB threshold
    EMERGENCY_MODE_THRESHOLD = 200 * 1024 * 1024, -- 200MB emergency
}

-- Task priorities
local PRIORITY = {
    CRITICAL = 1, -- Must complete this frame
    HIGH = 2, -- Should complete soon
    NORMAL = 3, -- Normal priority
    LOW = 4, -- Can be delayed
    BACKGROUND = 5, -- Background tasks
}

-- Task categories for optimization
local CATEGORY = {
    RENDER = "render", -- Rendering tasks
    PHYSICS = "physics", -- Physics calculations
    NETWORK = "network", -- Network operations
    AI = "ai", -- AI/pathfinding
    AUDIO = "audio", -- Audio processing
    SYSTEM = "system", -- System tasks
    USER = "user", -- User interactions
}

function LoadBalancer.new()
    local self = setmetatable({}, LoadBalancer)
    
    -- Task queues by priority
    self.taskQueues = {}
    for i = 1, 5 do
        self.taskQueues[i] = {
            tasks = {},
            totalWeight = 0,
            lastProcessed = 0
        }
    end
    
    -- Task categories
    self.categoryQueues = {}
    for _, category in pairs(CATEGORY) do
        self.categoryQueues[category] = {
            tasks = {},
            weight = 1.0,
            averageTime = 0.001
        }
    end
    
    -- Worker simulation
    self.workers = {}
    for i = 1, CONFIG.MAX_WORKERS do
        self.workers[i] = {
            id = i,
            busy = false,
            currentTask = nil,
            tasksCompleted = 0,
            totalTime = 0,
            efficiency = CONFIG.WORKER_EFFICIENCY + (math.random() - 0.5) * 0.2
        }
    end
    
    -- Performance tracking
    self.performance = {
        frameHistory = {},
        avgFrameTime = 0.016,
        peakFrameTime = 0,
        tasksPerSecond = 0,
        totalTasksProcessed = 0,
        droppedTasks = 0,
        lastFrameTime = 0,
        adaptiveMultiplier = 1.0
    }
    
    -- Adaptive balancing
    self.adaptation = {
        enabled = CONFIG.ENABLE_ADAPTIVE_BALANCING,
        lastAdaptation = os.time(),
        performanceTrend = 0, -- -1 degrading, 0 stable, 1 improving
        adjustmentFactor = 1.0,
        emergencyMode = false
    }
    
    -- Frame timing
    self.timing = {
        frameStart = 0,
        frameEnd = 0,
        frameTime = 0,
        frameCount = 0,
        lastCleanup = os.time()
    }
    
    -- Task management
    self.taskId = 0
    self.activeTasks = {}
    self.completedTasks = {}
    self.failedTasks = {}
    
    -- Initialize systems
    self:InitializeWorkers()
    self:SetupFrameLoop()
    
    print("LoadBalancer: Initialized with enterprise-level load balancing")
    return self
end

-- Initialize worker simulation
function LoadBalancer:InitializeWorkers()
    for _, worker in ipairs(self.workers) do
        worker.busy = false
        worker.currentTask = nil
        worker.tasksCompleted = 0
        worker.totalTime = 0
    end
    
    print("LoadBalancer: Initialized", #self.workers, "simulated workers")
end

-- Add task to load balancer
function LoadBalancer:AddTask(taskFunction, priority, category, weight, metadata)
    if not taskFunction or type(taskFunction) ~= "function" then
        warn("LoadBalancer: Invalid task function")
        return false
    end
    
    self.taskId = self.taskId + 1
    
    local task = {
        id = self.taskId,
        func = taskFunction,
        priority = priority or PRIORITY.NORMAL,
        category = category or CATEGORY.SYSTEM,
        weight = weight or 1.0,
        metadata = metadata or {},
        createdTime = os.time(),
        attempts = 0,
        maxAttempts = 3,
        timeout = CONFIG.TASK_TIMEOUT,
        dependencies = {},
        completed = false,
        failed = false
    }
    
    -- Check queue size
    local totalTasks = self:GetTotalQueuedTasks()
    if totalTasks >= CONFIG.MAX_QUEUE_SIZE then
        self:DropLowPriorityTasks()
        if totalTasks >= CONFIG.MAX_QUEUE_SIZE then
            self.performance.droppedTasks = self.performance.droppedTasks + 1
            return false
        end
    end
    
    -- Add to priority queue
    local priorityQueue = self.taskQueues[task.priority]
    if priorityQueue then
        table.insert(priorityQueue.tasks, task)
        priorityQueue.totalWeight = priorityQueue.totalWeight + task.weight
    end
    
    -- Add to category queue
    local categoryQueue = self.categoryQueues[task.category]
    if categoryQueue then
        table.insert(categoryQueue.tasks, task)
    end
    
    -- Track active task
    self.activeTasks[task.id] = task
    
    return task.id
end

-- Add batch task
function LoadBalancer:AddBatchTask(taskFunctions, priority, category, batchSize)
    local batchId = self.taskId + 1
    local tasks = {}
    
    for i, taskFunc in ipairs(taskFunctions) do
        local taskId = self:AddTask(taskFunc, priority, category, 1.0, {
            batchId = batchId,
            batchIndex = i,
            totalInBatch = #taskFunctions
        })
        
        if taskId then
            table.insert(tasks, taskId)
        end
    end
    
    return batchId, tasks
end

-- Process tasks for current frame
function LoadBalancer:ProcessFrame()
    self.timing.frameStart = os.clock()
    local tasksProcessed = 0
    local maxTasks = self:CalculateMaxTasks()
    
    -- Process high priority tasks first
    for priority = 1, 5 do
        if tasksProcessed >= maxTasks then break end
        
        local remaining = maxTasks - tasksProcessed
        local processed = self:ProcessPriorityQueue(priority, remaining)
        tasksProcessed = tasksProcessed + processed
        
        -- Check frame time limit
        if self:IsFrameTimeExceeded() then
            break
        end
    end
    
    -- Update performance metrics
    self.timing.frameEnd = os.clock()
    self.timing.frameTime = self.timing.frameEnd - self.timing.frameStart
    self.timing.frameCount = self.timing.frameCount + 1
    
    self:UpdatePerformanceMetrics(tasksProcessed)
    
    -- Adaptive balancing
    if self.adaptation.enabled then
        self:AdaptPerformance()
    end
    
    -- Cleanup if needed
    if os.time() - self.timing.lastCleanup > CONFIG.QUEUE_CLEANUP_INTERVAL then
        self:CleanupTasks()
        self.timing.lastCleanup = os.time()
    end
    
    return tasksProcessed
end

-- Process priority queue
function LoadBalancer:ProcessPriorityQueue(priority, maxTasks)
    local queue = self.taskQueues[priority]
    if not queue or #queue.tasks == 0 then
        return 0
    end
    
    local tasksProcessed = 0
    local tasksToRemove = {}
    
    -- Calculate time allocation for this priority
    local timeAllocation = self:GetTimeAllocation(priority)
    local startTime = os.clock()
    
    for i, task in ipairs(queue.tasks) do
        if tasksProcessed >= maxTasks then break end
        
        -- Check time limit
        local elapsed = os.clock() - startTime
        if elapsed > timeAllocation then break end
        
        -- Process task
        local success = self:ProcessTask(task)
        if success then
            tasksProcessed = tasksProcessed + 1
            table.insert(tasksToRemove, i)
        elseif task.failed then
            table.insert(tasksToRemove, i)
        end
    end
    
    -- Remove completed/failed tasks
    for i = #tasksToRemove, 1, -1 do
        local index = tasksToRemove[i]
        local task = queue.tasks[index]
        queue.totalWeight = queue.totalWeight - task.weight
        table.remove(queue.tasks, index)
    end
    
    queue.lastProcessed = os.time()
    return tasksProcessed
end

-- Process individual task
function LoadBalancer:ProcessTask(task)
    if not task or task.completed or task.failed then
        return false
    end
    
    -- Check timeout
    if os.time() - task.createdTime > task.timeout then
        task.failed = true
        self.failedTasks[task.id] = task
        self.activeTasks[task.id] = nil
        return false
    end
    
    -- Check dependencies
    if not self:AreDependenciesMet(task) then
        return false
    end
    
    local startTime = os.clock()
    task.attempts = task.attempts + 1
    
    -- Assign to worker
    local worker = self:GetAvailableWorker()
    if worker then
        worker.busy = true
        worker.currentTask = task
    end
    
    -- Execute task
    local success, result = pcall(task.func)
    
    local endTime = os.clock()
    local executionTime = endTime - startTime
    
    -- Update worker
    if worker then
        worker.busy = false
        worker.currentTask = nil
        worker.tasksCompleted = worker.tasksCompleted + 1
        worker.totalTime = worker.totalTime + executionTime
    end
    
    -- Update category statistics
    local categoryQueue = self.categoryQueues[task.category]
    if categoryQueue then
        categoryQueue.averageTime = (categoryQueue.averageTime * 0.9) + (executionTime * 0.1)
    end
    
    if success then
        task.completed = true
        task.result = result
        task.completedTime = os.time()
        self.completedTasks[task.id] = task
        self.activeTasks[task.id] = nil
        self.performance.totalTasksProcessed = self.performance.totalTasksProcessed + 1
        return true
    else
        -- Handle failure
        if task.attempts >= task.maxAttempts then
            task.failed = true
            task.error = result
            self.failedTasks[task.id] = task
            self.activeTasks[task.id] = nil
            warn("LoadBalancer: Task", task.id, "failed after", task.attempts, "attempts:", result)
        end
        return false
    end
end

-- Calculate maximum tasks for this frame
function LoadBalancer:CalculateMaxTasks()
    local baseTasks = CONFIG.MAX_TASKS_PER_FRAME
    local adaptiveMultiplier = self.adaptation.adjustmentFactor
    local performanceMultiplier = 1.0
    
    -- Adjust based on recent frame performance
    if self.performance.avgFrameTime > CONFIG.TARGET_FRAME_TIME then
        performanceMultiplier = 0.8 -- Reduce load
    elseif self.performance.avgFrameTime < CONFIG.TARGET_FRAME_TIME * 0.8 then
        performanceMultiplier = 1.2 -- Increase load
    end
    
    -- Emergency mode
    if self.adaptation.emergencyMode then
        performanceMultiplier = 0.5
    end
    
    local maxTasks = math.floor(baseTasks * adaptiveMultiplier * performanceMultiplier)
    return math.max(CONFIG.MIN_TASKS_PER_FRAME, math.min(CONFIG.MAX_TASKS_PER_FRAME, maxTasks))
end

-- Get time allocation for priority level
function LoadBalancer:GetTimeAllocation(priority)
    local baseTime = CONFIG.TARGET_FRAME_TIME / 5 -- Divide equally
    local priorityMultiplier = {
        [1] = 3.0, -- Critical gets 3x
        [2] = 2.0, -- High gets 2x
        [3] = 1.0, -- Normal gets 1x
        [4] = 0.7, -- Low gets 0.7x
        [5] = 0.5, -- Background gets 0.5x
    }
    
    return baseTime * (priorityMultiplier[priority] or 1.0)
end

-- Check if frame time exceeded
function LoadBalancer:IsFrameTimeExceeded()
    local elapsed = os.clock() - self.timing.frameStart
    return elapsed > CONFIG.TARGET_FRAME_TIME
end

-- Get available worker
function LoadBalancer:GetAvailableWorker()
    if not CONFIG.ENABLE_WORKER_SIMULATION then
        return nil
    end
    
    for _, worker in ipairs(self.workers) do
        if not worker.busy then
            return worker
        end
    end
    
    return nil
end

-- Check if task dependencies are met
function LoadBalancer:AreDependenciesMet(task)
    for _, depId in ipairs(task.dependencies) do
        local depTask = self.completedTasks[depId]
        if not depTask or not depTask.completed then
            return false
        end
    end
    return true
end

-- Update performance metrics
function LoadBalancer:UpdatePerformanceMetrics(tasksProcessed)
    -- Update frame history
    table.insert(self.performance.frameHistory, self.timing.frameTime)
    if #self.performance.frameHistory > CONFIG.PERFORMANCE_HISTORY_SIZE then
        table.remove(self.performance.frameHistory, 1)
    end
    
    -- Calculate average frame time
    local total = 0
    for _, frameTime in ipairs(self.performance.frameHistory) do
        total = total + frameTime
    end
    self.performance.avgFrameTime = total / #self.performance.frameHistory
    
    -- Update peak frame time
    if self.timing.frameTime > self.performance.peakFrameTime then
        self.performance.peakFrameTime = self.timing.frameTime
    end
    
    -- Calculate tasks per second
    local currentTime = os.time()
    if currentTime > self.performance.lastFrameTime then
        self.performance.tasksPerSecond = tasksProcessed / (currentTime - self.performance.lastFrameTime)
        self.performance.lastFrameTime = currentTime
    end
end

-- Adaptive performance adjustment
function LoadBalancer:AdaptPerformance()
    local currentTime = os.time()
    if currentTime - self.adaptation.lastAdaptation < CONFIG.ADAPTATION_INTERVAL then
        return
    end
    
    -- Analyze performance trend
    local recentFrames = {}
    local historySize = math.min(10, #self.performance.frameHistory)
    for i = #self.performance.frameHistory - historySize + 1, #self.performance.frameHistory do
        table.insert(recentFrames, self.performance.frameHistory[i])
    end
    
    if #recentFrames >= 5 then
        local firstHalf = 0
        local secondHalf = 0
        local halfSize = math.floor(#recentFrames / 2)
        
        for i = 1, halfSize do
            firstHalf = firstHalf + recentFrames[i]
        end
        for i = halfSize + 1, #recentFrames do
            secondHalf = secondHalf + recentFrames[i]
        end
        
        firstHalf = firstHalf / halfSize
        secondHalf = secondHalf / (#recentFrames - halfSize)
        
        if secondHalf > firstHalf * 1.1 then
            self.adaptation.performanceTrend = -1 -- Degrading
        elseif secondHalf < firstHalf * 0.9 then
            self.adaptation.performanceTrend = 1 -- Improving
        else
            self.adaptation.performanceTrend = 0 -- Stable
        end
    end
    
    -- Adjust performance
    if self.adaptation.performanceTrend == -1 then
        -- Performance degrading, reduce load
        self.adaptation.adjustmentFactor = math.max(0.5, self.adaptation.adjustmentFactor * 0.9)
    elseif self.adaptation.performanceTrend == 1 then
        -- Performance improving, can increase load
        self.adaptation.adjustmentFactor = math.min(2.0, self.adaptation.adjustmentFactor * 1.05)
    end
    
    -- Check for emergency mode
    local memoryUsage = collectgarbage("count") * 1024
    if memoryUsage > CONFIG.EMERGENCY_MODE_THRESHOLD or self.performance.avgFrameTime > CONFIG.CRITICAL_FRAME_TIME then
        self.adaptation.emergencyMode = true
        self.adaptation.adjustmentFactor = 0.3
    elseif memoryUsage < CONFIG.MEMORY_THRESHOLD and self.performance.avgFrameTime < CONFIG.TARGET_FRAME_TIME then
        self.adaptation.emergencyMode = false
    end
    
    self.adaptation.lastAdaptation = currentTime
end

-- Drop low priority tasks to make room
function LoadBalancer:DropLowPriorityTasks()
    local dropped = 0
    
    -- Start with background tasks
    for priority = 5, 4, -1 do
        local queue = self.taskQueues[priority]
        if queue and #queue.tasks > 0 then
            local toRemove = math.min(10, #queue.tasks)
            for i = 1, toRemove do
                local task = table.remove(queue.tasks)
                if task then
                    queue.totalWeight = queue.totalWeight - task.weight
                    self.activeTasks[task.id] = nil
                    dropped = dropped + 1
                end
            end
            
            if dropped >= 10 then break end
        end
    end
    
    self.performance.droppedTasks = self.performance.droppedTasks + dropped
end

-- Cleanup completed and failed tasks
function LoadBalancer:CleanupTasks()
    local currentTime = os.time()
    local cleanupAge = 60 -- Keep completed tasks for 1 minute
    
    -- Cleanup completed tasks
    local completedToRemove = {}
    for taskId, task in pairs(self.completedTasks) do
        if currentTime - task.completedTime > cleanupAge then
            table.insert(completedToRemove, taskId)
        end
    end
    
    for _, taskId in ipairs(completedToRemove) do
        self.completedTasks[taskId] = nil
    end
    
    -- Cleanup failed tasks
    local failedToRemove = {}
    for taskId, task in pairs(self.failedTasks) do
        if currentTime - task.createdTime > cleanupAge then
            table.insert(failedToRemove, taskId)
        end
    end
    
    for _, taskId in ipairs(failedToRemove) do
        self.failedTasks[taskId] = nil
    end
    
    -- Clean up category queues
    for _, categoryQueue in pairs(self.categoryQueues) do
        local tasksToRemove = {}
        for i, task in ipairs(categoryQueue.tasks) do
            if task.completed or task.failed then
                table.insert(tasksToRemove, i)
            end
        end
        
        for i = #tasksToRemove, 1, -1 do
            table.remove(categoryQueue.tasks, tasksToRemove[i])
        end
    end
end

-- Setup frame loop
function LoadBalancer:SetupFrameLoop()
    if RunService:IsClient() then
        self.frameConnection = RunService.Heartbeat:Connect(function()
            self:ProcessFrame()
        end)
    else
        self.frameConnection = RunService.Heartbeat:Connect(function()
            self:ProcessFrame()
        end)
    end
end

-- Utility functions
function LoadBalancer:GetTotalQueuedTasks()
    local total = 0
    for _, queue in pairs(self.taskQueues) do
        total = total + #queue.tasks
    end
    return total
end

function LoadBalancer:GetTaskStatus(taskId)
    if self.completedTasks[taskId] then
        return "completed", self.completedTasks[taskId].result
    elseif self.failedTasks[taskId] then
        return "failed", self.failedTasks[taskId].error
    elseif self.activeTasks[taskId] then
        return "pending", nil
    else
        return "not_found", nil
    end
end

function LoadBalancer:CancelTask(taskId)
    local task = self.activeTasks[taskId]
    if not task then return false end
    
    -- Remove from queues
    for _, queue in pairs(self.taskQueues) do
        for i = #queue.tasks, 1, -1 do
            if queue.tasks[i].id == taskId then
                queue.totalWeight = queue.totalWeight - queue.tasks[i].weight
                table.remove(queue.tasks, i)
                break
            end
        end
    end
    
    -- Remove from category queues
    for _, categoryQueue in pairs(self.categoryQueues) do
        for i = #categoryQueue.tasks, 1, -1 do
            if categoryQueue.tasks[i].id == taskId then
                table.remove(categoryQueue.tasks, i)
                break
            end
        end
    end
    
    self.activeTasks[taskId] = nil
    return true
end

function LoadBalancer:SetTaskDependency(taskId, dependencyId)
    local task = self.activeTasks[taskId]
    if task then
        table.insert(task.dependencies, dependencyId)
        return true
    end
    return false
end

-- Get performance metrics
function LoadBalancer:GetMetrics()
    local queueSizes = {}
    for priority, queue in pairs(self.taskQueues) do
        queueSizes[priority] = #queue.tasks
    end
    
    local workerStats = {}
    for _, worker in pairs(self.workers) do
        table.insert(workerStats, {
            id = worker.id,
            busy = worker.busy,
            tasksCompleted = worker.tasksCompleted,
            averageTime = worker.tasksCompleted > 0 and worker.totalTime / worker.tasksCompleted or 0,
            efficiency = worker.efficiency
        })
    end
    
    return {
        frameTime = self.timing.frameTime,
        avgFrameTime = self.performance.avgFrameTime,
        peakFrameTime = self.performance.peakFrameTime,
        tasksPerSecond = self.performance.tasksPerSecond,
        totalTasksProcessed = self.performance.totalTasksProcessed,
        droppedTasks = self.performance.droppedTasks,
        queueSizes = queueSizes,
        totalQueuedTasks = self:GetTotalQueuedTasks(),
        adaptiveMultiplier = self.adaptation.adjustmentFactor,
        emergencyMode = self.adaptation.emergencyMode,
        performanceTrend = self.adaptation.performanceTrend,
        workerStats = workerStats,
        memoryUsage = collectgarbage("count") * 1024
    }
end

-- Shutdown load balancer
function LoadBalancer:Shutdown()
    if self.frameConnection then
        self.frameConnection:Disconnect()
    end
    
    -- Clear all queues
    for _, queue in pairs(self.taskQueues) do
        queue.tasks = {}
        queue.totalWeight = 0
    end
    
    for _, categoryQueue in pairs(self.categoryQueues) do
        categoryQueue.tasks = {}
    end
    
    self.activeTasks = {}
    self.completedTasks = {}
    self.failedTasks = {}
    
    print("LoadBalancer: Shutdown completed")
end

return LoadBalancer 