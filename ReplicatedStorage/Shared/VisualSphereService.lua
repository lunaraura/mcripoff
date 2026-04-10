-- VisualSphereService: Manages visual sphere representations for combat effects
-- All spheres are non-colliding, anchored parts used purely for visualization

local VisualSphereService = {}
VisualSphereService.__index = VisualSphereService

-- Configuration
local CONFIG = {
	-- Projectile settings
	projectile = {
		baseSize = 2,
		color = Color3.fromRGB(255, 200, 50), -- Bright orange-yellow
		transparency = 0.2,
		material = Enum.Material.Neon,
		trailFadeTime = 0.15,
	},
	-- AOE settings
	aoe = {
		color = Color3.fromRGB(255, 100, 100), -- Red-ish
		transparency = 0.6,
		material = Enum.Material.ForceField,
		expandDuration = 0.3,
	},
	-- Barrier settings
	barrier = {
		color = Color3.fromRGB(100, 150, 255), -- Blue
		transparency = 0.5,
		material = Enum.Material.ForceField,
		pulseSpeed = 2, -- Pulses per second
		pulseIntensity = 0.15,
	},
	-- Wall barrier settings
	wallBarrier = {
		color = Color3.fromRGB(150, 120, 80), -- Brown/tan
		transparency = 0.4,
		material = Enum.Material.Slate,
	},
}

-- Create a base sphere part with common properties
local function createBaseSphere(name, position, radius)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	part.Position = position
	part.Parent = workspace
	return part
end

-- Create a projectile sphere
function VisualSphereService.spawnProjectileSphere(params)
	local position = params.position or Vector3.new(0, 0, 0)
	local radius = params.radius or 2
	local color = params.color or CONFIG.projectile.color
	local transparency = params.transparency or CONFIG.projectile.transparency
	local material = params.material or CONFIG.projectile.material

	local sphere = createBaseSphere("ProjectileVisual", position, radius)
	sphere.Color = color
	sphere.Transparency = transparency
	sphere.Material = material

	return sphere
end

-- Create an AOE sphere
function VisualSphereService.spawnAOESphere(params)
	local position = params.position or Vector3.new(0, 0, 0)
	local radius = params.radius or 10
	local color = params.color or CONFIG.aoe.color
	local transparency = params.transparency or CONFIG.aoe.transparency
	local material = params.material or CONFIG.aoe.material
	local expanding = params.expanding or false
	local expandDuration = params.expandDuration or CONFIG.aoe.expandDuration

	local sphere = createBaseSphere("AOEVisual", position, expanding and 0.1 or radius)
	sphere.Color = color
	sphere.Transparency = transparency
	sphere.Material = material

	-- If expanding, start small and grow
	if expanding then
		local startSize = 0.1
		local targetSize = radius * 2
		local startTime = os.clock()
		local connection
		connection = game:GetService("RunService").RenderStepped:Connect(function()
			local elapsed = os.clock() - startTime
			local progress = math.min(elapsed / expandDuration, 1)
			-- Ease out quad
			local eased = 1 - (1 - progress) * (1 - progress)
			local currentSize = startSize + (targetSize - startSize) * eased
			if sphere and sphere.Parent then
				sphere.Size = Vector3.new(currentSize, currentSize, currentSize)
			end
			if progress >= 1 then
				connection:Disconnect()
			end
		end)
	end

	return sphere
end

-- Create a barrier sphere
function VisualSphereService.spawnBarrierSphere(params)
	local position = params.position or Vector3.new(0, 0, 0)
	local radius = params.radius or 20
	local color = params.color or CONFIG.barrier.color
	local transparency = params.transparency or CONFIG.barrier.transparency
	local material = params.material or CONFIG.barrier.material
	local pulse = params.pulse ~= false -- Default to true

	local sphere = createBaseSphere("BarrierVisual", position, radius)
	sphere.Color = color
	sphere.Transparency = transparency
	sphere.Material = material

	-- Add pulsing effect
	if pulse then
		local baseTransparency = transparency
		local startTime = os.clock()
		local connection
		connection = game:GetService("RunService").RenderStepped:Connect(function()
			if not sphere or not sphere.Parent then
				connection:Disconnect()
				return
			end
			local elapsed = os.clock() - startTime
			local pulseValue = math.sin(elapsed * CONFIG.barrier.pulseSpeed * math.pi * 2)
			sphere.Transparency = baseTransparency + pulseValue * CONFIG.barrier.pulseIntensity
		end)
		-- Store connection for cleanup
		sphere:SetAttribute("PulseConnection", true)
	end

	return sphere
end

-- Create a wall barrier visual (using a block, not sphere, but same principles)
function VisualSphereService.spawnWallBarrierVisual(params)
	local position = params.position or Vector3.new(0, 0, 0)
	local length = params.length or 50
	local thickness = params.thickness or 8
	local height = params.height or 20
	local color = params.color or CONFIG.wallBarrier.color
	local transparency = params.transparency or CONFIG.wallBarrier.transparency
	local material = params.material or CONFIG.wallBarrier.material

	local part = Instance.new("Part")
	part.Name = "WallBarrierVisual"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(length, height, thickness)
	part.Position = position
	part.Color = color
	part.Transparency = transparency
	part.Material = material
	part.Parent = workspace

	return part
end

-- Update sphere position (for projectiles)
function VisualSphereService.updateSpherePosition(sphere, newPosition)
	if sphere and sphere.Parent then
		sphere.Position = newPosition
	end
end

-- Update sphere size (for expanding AOEs)
function VisualSphereService.updateSphereSize(sphere, newRadius)
	if sphere and sphere.Parent then
		sphere.Size = Vector3.new(newRadius * 2, newRadius * 2, newRadius * 2)
	end
end

-- Clean up a sphere
function VisualSphereService.destroySphere(sphere)
	if sphere then
		sphere.Parent = nil
	end
end

-- Fade out and destroy a sphere
function VisualSphereService.fadeOutAndDestroy(sphere, duration)
	if not sphere or not sphere.Parent then return end

	duration = duration or 0.2
	local startTransparency = sphere.Transparency
	local startTime = os.clock()

	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		if not sphere or not sphere.Parent then
			connection:Disconnect()
			return
		end
		local elapsed = os.clock() - startTime
		local progress = math.min(elapsed / duration, 1)
		sphere.Transparency = startTransparency + (1 - startTransparency) * progress
		if progress >= 1 then
			sphere.Parent = nil
			connection:Disconnect()
		end
	end)
end

-- Get configuration for external use
function VisualSphereService.getConfig()
	return CONFIG
end

return VisualSphereService
