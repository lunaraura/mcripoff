-- CombatVisualController: Client-side controller for rendering combat visuals
-- Receives events from server and creates visual sphere representations

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualSphereService = require(Shared:WaitForChild("VisualSphereService"))

local CombatVisualController = {}
CombatVisualController.__index = CombatVisualController

-- Active visual tracking
local activeProjectiles = {} -- [id] = { sphere, data }
local activeAOEs = {} -- [id] = { sphere, data }
local activeBarriers = {} -- [id] = { sphere, data }
local activeWallBarriers = {} -- [id] = { part, data }

function CombatVisualController.new()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	return setmetatable({
		projectileVisual = remotes:WaitForChild("ProjectileVisualEvent"),
		aoeVisual = remotes:WaitForChild("AOEVisualEvent"),
		barrierVisual = remotes:WaitForChild("BarrierVisualEvent"),
		wallBarrierVisual = remotes:WaitForChild("WallBarrierVisualEvent"),
		combatVisualUpdate = remotes:WaitForChild("CombatVisualUpdateEvent"),
	}, CombatVisualController)
end

-- Handle projectile spawn
local function onProjectileSpawn(data)
	local id = data.id
	if not id then return end

	-- Clean up any existing projectile with this ID
	if activeProjectiles[id] then
		VisualSphereService.destroySphere(activeProjectiles[id].sphere)
	end

	local sphere = VisualSphereService.spawnProjectileSphere({
		position = Vector3.new(data.x, data.y, data.z),
		radius = data.radius or 2,
		color = data.color,
		transparency = data.transparency,
	})

	activeProjectiles[id] = {
		sphere = sphere,
		data = data,
	}
end

-- Handle projectile update (position)
local function onProjectileUpdate(data)
	local id = data.id
	if not id or not activeProjectiles[id] then return end

	local visual = activeProjectiles[id]
	if visual.sphere and visual.sphere.Parent then
		visual.sphere.Position = Vector3.new(data.x, data.y, data.z)
	end
end

-- Handle projectile destroy
local function onProjectileDestroy(data)
	local id = data.id
	if not id or not activeProjectiles[id] then return end

	local visual = activeProjectiles[id]
	if visual.sphere then
		VisualSphereService.fadeOutAndDestroy(visual.sphere, 0.15)
	end
	activeProjectiles[id] = nil
end

-- Handle AOE spawn
local function onAOESpawn(data)
	local id = data.id
	if not id then return end

	-- Clean up any existing AOE with this ID
	if activeAOEs[id] then
		VisualSphereService.destroySphere(activeAOEs[id].sphere)
	end

	local sphere = VisualSphereService.spawnAOESphere({
		position = Vector3.new(data.x, data.y, data.z),
		radius = data.radius or 10,
		color = data.color,
		transparency = data.transparency,
		expanding = data.expanding or false,
		expandDuration = data.expandDuration,
	})

	activeAOEs[id] = {
		sphere = sphere,
		data = data,
	}

	-- Auto-destroy after duration
	if data.duration then
		task.delay(data.duration, function()
			if activeAOEs[id] then
				VisualSphereService.fadeOutAndDestroy(activeAOEs[id].sphere, 0.2)
				activeAOEs[id] = nil
			end
		end)
	end
end

-- Handle AOE update (position for moving AOEs)
local function onAOEUpdate(data)
	local id = data.id
	if not id or not activeAOEs[id] then return end

	local visual = activeAOEs[id]
	if visual.sphere and visual.sphere.Parent then
		visual.sphere.Position = Vector3.new(data.x, data.y, data.z)
		if data.radius then
			visual.sphere.Size = Vector3.new(data.radius * 2, data.radius * 2, data.radius * 2)
		end
	end
end

-- Handle AOE destroy
local function onAOEDestroy(data)
	local id = data.id
	if not id or not activeAOEs[id] then return end

	local visual = activeAOEs[id]
	if visual.sphere then
		VisualSphereService.fadeOutAndDestroy(visual.sphere, 0.2)
	end
	activeAOEs[id] = nil
end

-- Handle barrier spawn
local function onBarrierSpawn(data)
	local id = data.id
	if not id then return end

	-- Clean up any existing barrier with this ID
	if activeBarriers[id] then
		VisualSphereService.destroySphere(activeBarriers[id].sphere)
	end

	local sphere = VisualSphereService.spawnBarrierSphere({
		position = Vector3.new(data.x, data.y, data.z),
		radius = data.radius or 20,
		color = data.color,
		transparency = data.transparency,
		pulse = data.pulse,
	})

	activeBarriers[id] = {
		sphere = sphere,
		data = data,
	}

	-- Auto-destroy after duration
	if data.duration then
		task.delay(data.duration, function()
			if activeBarriers[id] then
				VisualSphereService.fadeOutAndDestroy(activeBarriers[id].sphere, 0.3)
				activeBarriers[id] = nil
			end
		end)
	end
end

-- Handle barrier destroy
local function onBarrierDestroy(data)
	local id = data.id
	if not id or not activeBarriers[id] then return end

	local visual = activeBarriers[id]
	if visual.sphere then
		VisualSphereService.fadeOutAndDestroy(visual.sphere, 0.3)
	end
	activeBarriers[id] = nil
end

-- Handle wall barrier spawn
local function onWallBarrierSpawn(data)
	local id = data.id
	if not id then return end

	-- Clean up any existing wall barrier with this ID
	if activeWallBarriers[id] then
		VisualSphereService.destroySphere(activeWallBarriers[id].part)
	end

	local part = VisualSphereService.spawnWallBarrierVisual({
		position = Vector3.new(data.x, data.y, data.z),
		length = data.length or 50,
		thickness = data.thickness or 8,
		height = data.height or 20,
		color = data.color,
		transparency = data.transparency,
	})

	activeWallBarriers[id] = {
		part = part,
		data = data,
	}

	-- Auto-destroy after duration
	if data.duration then
		task.delay(data.duration, function()
			if activeWallBarriers[id] then
				VisualSphereService.fadeOutAndDestroy(activeWallBarriers[id].part, 0.3)
				activeWallBarriers[id] = nil
			end
		end)
	end
end

-- Handle wall barrier destroy
local function onWallBarrierDestroy(data)
	local id = data.id
	if not id or not activeWallBarriers[id] then return end

	local visual = activeWallBarriers[id]
	if visual.part then
		VisualSphereService.fadeOutAndDestroy(visual.part, 0.3)
	end
	activeWallBarriers[id] = nil
end

-- Handle batch updates (for efficiency)
local function onCombatVisualUpdate(data)
	-- Update projectiles
	if data.projectiles then
		for _, p in ipairs(data.projectiles) do
			onProjectileUpdate(p)
		end
	end

	-- Update AOEs
	if data.aoes then
		for _, a in ipairs(data.aoes) do
			onAOEUpdate(a)
		end
	end

	-- Destroy expired
	if data.destroyProjectiles then
		for _, id in ipairs(data.destroyProjectiles) do
			onProjectileDestroy({ id = id })
		end
	end
	if data.destroyAOEs then
		for _, id in ipairs(data.destroyAOEs) do
			onAOEDestroy({ id = id })
		end
	end
	if data.destroyBarriers then
		for _, id in ipairs(data.destroyBarriers) do
			onBarrierDestroy({ id = id })
		end
	end
	if data.destroyWallBarriers then
		for _, id in ipairs(data.destroyWallBarriers) do
			onWallBarrierDestroy({ id = id })
		end
	end
end

function CombatVisualController:bind()
	-- Connect to remote events
	self.projectileVisual.OnClientEvent:Connect(function(action, data)
		if action == "spawn" then
			onProjectileSpawn(data)
		elseif action == "update" then
			onProjectileUpdate(data)
		elseif action == "destroy" then
			onProjectileDestroy(data)
		end
	end)

	self.aoeVisual.OnClientEvent:Connect(function(action, data)
		if action == "spawn" then
			onAOESpawn(data)
		elseif action == "update" then
			onAOEUpdate(data)
		elseif action == "destroy" then
			onAOEDestroy(data)
		end
	end)

	self.barrierVisual.OnClientEvent:Connect(function(action, data)
		if action == "spawn" then
			onBarrierSpawn(data)
		elseif action == "destroy" then
			onBarrierDestroy(data)
		end
	end)

	self.wallBarrierVisual.OnClientEvent:Connect(function(action, data)
		if action == "spawn" then
			onWallBarrierSpawn(data)
		elseif action == "destroy" then
			onWallBarrierDestroy(data)
		end
	end)

	self.combatVisualUpdate.OnClientEvent:Connect(onCombatVisualUpdate)

	-- Cleanup on player leaving
	game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function()
		-- Clean up all visuals
		for id, visual in pairs(activeProjectiles) do
			VisualSphereService.destroySphere(visual.sphere)
		end
		for id, visual in pairs(activeAOEs) do
			VisualSphereService.destroySphere(visual.sphere)
		end
		for id, visual in pairs(activeBarriers) do
			VisualSphereService.destroySphere(visual.sphere)
		end
		for id, visual in pairs(activeWallBarriers) do
			VisualSphereService.destroySphere(visual.part)
		end

		activeProjectiles = {}
		activeAOEs = {}
		activeBarriers = {}
		activeWallBarriers = {}
	end)
end

return CombatVisualController
