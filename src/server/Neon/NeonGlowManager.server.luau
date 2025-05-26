-- EnhancedGlowManager.lua
-- Place this in ServerScriptService

local TweenService = game:GetService("TweenService")
wait(1) -- Wait for everything to load

-- Color definitions
local GLOW_COLORS = {
	Red = Color3.fromRGB(255, 0, 0),
	Blue = Color3.fromRGB(0, 0, 255),
	Green = Color3.fromRGB(0, 255, 0),
	Purple = Color3.fromRGB(147, 39, 212),
	Yellow = Color3.fromRGB(255, 255, 0),
	Cyan = Color3.fromRGB(0, 255, 255),
	White = Color3.fromRGB(255, 255, 255),
	Orange = Color3.fromRGB(255, 128, 0)
}

-- Animation settings
local GLOW_TWEEN_INFO = TweenInfo.new(
	2,                      -- Duration
	Enum.EasingStyle.Sine,   -- Easing Style
	Enum.EasingDirection.InOut, -- Easing Direction
	-1,                     -- Repeat count (-1 = forever)
	true                    -- Reverse
)

-- Store tweens for cleanup
local activeTweens = {}

-- Recursively search through all containers
local function findAllGlowModels(parent)
	local glowModels = {}

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("GlowColor") then
			table.insert(glowModels, child)
		elseif child:IsA("Folder") then
			local nestedModels = findAllGlowModels(child)
			for _, model in ipairs(nestedModels) do
				table.insert(glowModels, model)
			end
		end
	end

	return glowModels
end

-- Create an outer glow effect (transparent part surrounding the cube)
local function createOuterGlow(part, color)
	local outerGlow = Instance.new("Part")
	outerGlow.Name = "OuterGlow"
	outerGlow.Parent = part.Parent
	outerGlow.Material = Enum.Material.Neon
	outerGlow.BrickColor = BrickColor.new(color)
	outerGlow.Color = color
	outerGlow.Anchored = true
	outerGlow.CanCollide = false
	outerGlow.Transparency = 0.7

	-- Handle different part types
	if part:IsA("Part") then
		outerGlow.Shape = part.Shape
	else
		-- For UnionOperations or other part types, default to Block
		outerGlow.Shape = Enum.PartType.Block
	end

	outerGlow.Size = part.Size * 1.1  -- Slightly larger
	outerGlow.CFrame = part.CFrame

	-- Keep it connected to the main part
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = outerGlow
	weld.Parent = part

	return outerGlow
end

-- Enhanced glow function
local function makePartGlow(part, color)
	-- 1. Set main part properties based on part type
	if part:IsA("Part") then
		part.Material = Enum.Material.ForceField  -- More translucent than Neon
	elseif part:IsA("UnionOperation") then
		-- UnionOperations have limited material options
		part.Material = Enum.Material.Neon
	end

	part.Color = color
	part.Transparency = 0.2  -- Slightly transparent

	-- 2. Add/update PointLight
	local light = part:FindFirstChild("PointLight") or Instance.new("PointLight")
	light.Parent = part
	light.Color = color
	light.Brightness = 3  -- Brighter
	light.Range = 15      -- Larger range

	-- 3. Create outer glow effect
	local outerGlow = createOuterGlow(part, color)

	-- 4. Add pulsing animation
	local brightColor = color
	local darkColor = Color3.new(color.R * 0.4, color.G * 0.4, color.B * 0.4)

	-- Animate main part
	local partTween = TweenService:Create(part, GLOW_TWEEN_INFO, {
		Color = darkColor,
		Transparency = 0.5
	})

	-- Animate outer glow
	local glowTween = TweenService:Create(outerGlow, GLOW_TWEEN_INFO, {
		Color = darkColor,
		Transparency = 0.9
	})

	-- Animate light
	local lightTween = TweenService:Create(light, GLOW_TWEEN_INFO, {
		Brightness = 1,
		Range = 8
	})

	-- Store tweens for later cleanup
	table.insert(activeTweens, partTween)
	table.insert(activeTweens, glowTween)
	table.insert(activeTweens, lightTween)

	-- Start animations
	partTween:Play()
	glowTween:Play()
	lightTween:Play()
end

-- Find all glow models in workspace (initial scan)
local initialWorkspaceModels = findAllGlowModels(workspace)
print(string.format("Found %d glow models in initial workspace scan.", #initialWorkspaceModels))
for _, model in ipairs(initialWorkspaceModels) do
	local colorName = model:GetAttribute("GlowColor")
	local color = GLOW_COLORS[colorName]
	if color then
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") then
				makePartGlow(part, color)
			end
		end
	else
		warn(string.format("Initial Scan: Unknown color: %s for model: %s", colorName, model.Name))
	end
end

-- Specifically target Workspace > World_Items > Placed folder
local worldItemsFolder = workspace:FindFirstChild("World_Items") or Instance.new("Folder", workspace)
worldItemsFolder.Name = "World_Items"

local placedFolder = worldItemsFolder:FindFirstChild("Placed") or Instance.new("Folder", worldItemsFolder)
placedFolder.Name = "Placed"

print(string.format("Monitoring folder: %s for new glow items.", placedFolder:GetFullName()))

-- Process existing items in Placed folder
local existingPlacedModels = findAllGlowModels(placedFolder)
print(string.format("Found %d glow models in %s.", #existingPlacedModels, placedFolder:GetFullName()))
for _, model in ipairs(existingPlacedModels) do
	local colorName = model:GetAttribute("GlowColor")
	local color = GLOW_COLORS[colorName]
	if color then
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") then
				makePartGlow(part, color)
			end
		end
	else
		warn(string.format("Placed Items Scan: Unknown color: %s for model: %s", colorName, model.Name))
	end
end

-- Listen for new items added to the Placed folder
placedFolder.ChildAdded:Connect(function(child)
	print(string.format("New child %s added to %s", child.Name, placedFolder:GetFullName()))
	if child:IsA("Model") and child:GetAttribute("GlowColor") then
		print(string.format("Processing new glow model: %s", child.Name))
		local colorName = child:GetAttribute("GlowColor")
		local color = GLOW_COLORS[colorName]
		if color then
			for _, part in ipairs(child:GetChildren()) do
				if part:IsA("BasePart") then
					makePartGlow(part, color)
				end
			end
		else
			warn(string.format("Runtime New Item: Unknown color: %s for model: %s", colorName, child.Name))
		end
	elseif child:IsA("Model") then -- If it's a model but doesn't have the attribute yet, wait for it
		child:GetAttributeChangedSignal("GlowColor"):Connect(function()
			local colorName = child:GetAttribute("GlowColor")
			local color = GLOW_COLORS[colorName]
			print(string.format("GlowColor attribute changed for %s to %s", child.Name, colorName))
			if color then
				for _, part in ipairs(child:GetChildren()) do
					if part:IsA("BasePart") then
						makePartGlow(part, color)
					end
				end
			else
				warn(string.format("Runtime Attribute Change: Unknown color: %s for model: %s", colorName, child.Name))
			end
		end)
	end
end)

-- Cleanup function
local function cleanup()
	for _, tween in ipairs(activeTweens) do
		tween:Cancel()
	end
	activeTweens = {}
end

-- Store for global access
_G.EnhancedGlowManager = {
	GLOW_COLORS = GLOW_COLORS,
	makePartGlow = makePartGlow,
	findAllGlowModels = findAllGlowModels,
	cleanup = cleanup
}