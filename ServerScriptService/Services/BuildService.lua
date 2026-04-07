local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))

local BuildService = {}
BuildService.__index = BuildService

function BuildService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService, nextBuildId = 1, buildables = {} }, BuildService)
end

function BuildService:getOrCreateBuildFolder()
	local world = workspace:FindFirstChild("World")
	if not world then
		world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = workspace
	end
	local builds = world:FindFirstChild("Buildables")
	if not builds then
		builds = Instance.new("Folder")
		builds.Name = "Buildables"
		builds.Parent = world
	end
	return builds
end

function BuildService:createBuildModel(build)
	local def = BuildableConfig[build.key]
	if not def then return nil end
	local placement = def.placement or {}
	local preview = placement.previewSize or { x = 4, y = 4, z = 4 }
	local parentFolder = self:getOrCreateBuildFolder()
	local part
	if (placement.previewShape or "block") == "wedge" then
		part = Instance.new("WedgePart")
		part.Size = Vector3.new(preview.x or 8, preview.y or 5, preview.z or 8)
		part.Material = Enum.Material.Fabric
		part.Color = Color3.fromRGB(156, 126, 98)
		part.Anchored = true
		part.CanCollide = true
		part.CFrame = CFrame.new(build.pos) * CFrame.Angles(0, math.rad((build.rotationY or 180)), 0)
	else
		part = Instance.new("Part")
		part.Size = Vector3.new(preview.x or 4, preview.y or 4, preview.z or 4)
		part.Shape = Enum.PartType.Block
		part.Material = Enum.Material.Wood
		part.Color = Color3.fromRGB(120, 95, 72)
		part.Anchored = true
		part.CanCollide = true
		part.CFrame = CFrame.new(build.pos) * CFrame.Angles(0, math.rad(build.rotationY or 0), 0)
	end
	part.Name = string.format("Build_%s_%d", build.key, build.id)
	part.Parent = parentFolder
	build.model = part
	return part
end

function BuildService:getBuildFootprintSize(buildKey)
	local def = BuildableConfig[buildKey]
	local p = def and def.placement or nil
	local fp = p and p.footprintSize or nil
	if fp then
		return Vector3.new(fp.x or 4, fp.y or 4, fp.z or 4)
	end
	local pv = p and p.previewSize or nil
	if pv then
		return Vector3.new(pv.x or 4, pv.y or 4, pv.z or 4)
	end
	return Vector3.new(4, 4, 4)
end

function BuildService:getPlacementRules(buildKey)
	local def = BuildableConfig[buildKey]
	local p = def and def.placement or {}
	return {
		placementRange = p.placementRange or 18,
		collisionRadius = p.collisionRadius or 4,
		allowedTerrain = p.allowedTerrain or { "ground" },
		allowRotation = p.allowRotation ~= false,
	}
end

function BuildService:getCellAtPosition(pos)
	local cx, cz = math.floor(pos.X / 64), math.floor(pos.Z / 64)
	local key = string.format("%d:%d", cx, cz)
	local chunk = self.worldService.chunks[key]
	if not chunk then return nil end
	local best, bestD = nil, math.huge
	for _, cell in ipairs(chunk.cells or {}) do
		local d = (Vector3.new(cell.x, 0, cell.z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bestD then
			best, bestD = cell, d
		end
	end
	return best
end

function BuildService:isTerrainAllowed(buildKey, pos)
	local rules = self:getPlacementRules(buildKey)
	local cell = self:getCellAtPosition(pos)
	if not cell then
		return false, "missing chunk/cell"
	end
	if cell.blocked or cell.water then
		return false, "blocked terrain"
	end
	local terrainClass = cell.terrainClass or "ground"
	for _, allowed in ipairs(rules.allowedTerrain) do
		if allowed == terrainClass then
			return true
		end
	end
	return false, "invalid terrain class"
end

function BuildService:isValidBuildPlacement(player, buildKey, pos)
	local rules = self:getPlacementRules(buildKey)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
	if dist > rules.placementRange then
		return false, "too far"
	end
	local terrainOk, terrainReason = self:isTerrainAllowed(buildKey, pos)
	if not terrainOk then
		return false, terrainReason
	end
	local size = self:getBuildFootprintSize(buildKey)
	local overlapBuild = false
	for _, b in pairs(self.buildables) do
		local d = (Vector3.new(b.pos.X, 0, b.pos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < math.max(rules.collisionRadius, math.max(size.X, size.Z) * 0.5) then
			overlapBuild = true
			break
		end
	end
	if overlapBuild then return false, "overlaps existing build" end
	for _, c in ipairs(self.worldService.creatures) do
		if c.alive then
			local d = (Vector3.new(c.pos.X, 0, c.pos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if d < math.max(4, rules.collisionRadius) then
				return false, "overlaps creature"
			end
		end
	end
	return true
end

function BuildService:nearestCell(root)
	local best, bestD = nil, math.huge
	for _, chunk in pairs(self.worldService.chunks) do
		for _, cell in ipairs(chunk.cells) do
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(cell.x, 0, cell.z)).Magnitude
			if d < bestD then
				best, bestD = cell, d
			end
		end
	end
	return best, bestD
end

function BuildService:tryGather(player, payload)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local cell, dist = self:nearestCell(root)
	if not cell or dist > 18 then
		return false, "no gather target"
	end
	local key = "fiber"
	if cell.terrainClass == "rock" then
		key = "stone"
	elseif cell.terrainClass == "water" then
		key = "battery_seed"
	end
	local granted = self.inventoryService:grant(player, { { key = key, amount = 1 } })
	self.worldService:pushEventLog(player, string.format("Gathered %s", key), "#d7fcb7")
	-- TODO: Replace terrain-class gather with biome/node-driven context actions.
	return true, granted
end

function BuildService:canAfford(player, costs)
	for matKey, amount in pairs(costs or {}) do
		if self.inventoryService:getCount(player, matKey) < amount then
			return false, matKey
		end
	end
	return true
end

function BuildService:tryBuild(player, payload)
	local buildKey = payload.buildKey or "fiber_trap"
	local def = BuildableConfig[buildKey]
	if not def then return false, "unknown build key" end
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local desiredPos = payload.position
	local placementPos = root.Position + root.CFrame.LookVector * 8
	local rules = self:getPlacementRules(buildKey)
	local rotationY = rules.allowRotation and (tonumber(payload.rotationY) or 0) or 0
	if typeof(desiredPos) == "Vector3" then
		placementPos = Vector3.new(
			math.floor(desiredPos.X / 4 + 0.5) * 4,
			desiredPos.Y,
			math.floor(desiredPos.Z / 4 + 0.5) * 4
		)
	end
	local okPlacement, placementReason = self:isValidBuildPlacement(player, buildKey, placementPos)
	if not okPlacement then
		return false, placementReason
	end
	local ok, missing = self:canAfford(player, def.cost)
	if not ok then return false, "missing " .. tostring(missing) end
	for matKey, amount in pairs(def.cost or {}) do
		self.inventoryService:tryConsume(player, matKey, amount)
	end
	local id = self.nextBuildId
	self.nextBuildId += 1
	self.buildables[id] = {
		id = id,
		key = buildKey,
		ownerUserId = player.UserId,
		pos = placementPos,
		rotationY = rotationY,
		nextHarvestAt = self.worldService.time + (def.harvestTime or 1),
	}
	self:createBuildModel(self.buildables[id])
	self.worldService:pushEventLog(player, string.format("Built %s", def.name or buildKey), "#bfe2ff")
	return true, self.buildables[id]
end

function BuildService:tryHarvestBuild(player, payload)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local best, bestD = nil, 12
	for _, b in pairs(self.buildables) do
		local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(b.pos.X, 0, b.pos.Z)).Magnitude
		if d < bestD then
			best, bestD = b, d
		end
	end
	if not best then return false, "no buildable nearby" end
	local def = BuildableConfig[best.key]
	if not def then return false, "invalid buildable" end
	if self.worldService.time < (best.nextHarvestAt or 0) then
		return false, "not ready"
	end
	local rewards = {}
	for key, amount in pairs(def.provides or {}) do
		local mappedKey = key
		if key == "bait" then
			mappedKey = "lure_meat"
		end
		table.insert(rewards, { key = mappedKey, amount = amount })
	end
	local granted = self.inventoryService:grant(player, rewards)
	best.nextHarvestAt = self.worldService.time + (def.harvestTime or 1)
	self.worldService:pushEventLog(player, string.format("Harvested %s", def.name or best.key), "#d7fcb7")
	return true, granted
end

function BuildService:handleContextAction(player, payload)
	payload = payload or {}
	local action = payload.action or "context"
	if action == "gather" or action == "context" then
		return self:tryGather(player, payload)
	elseif action == "build" then
		return self:tryBuild(player, payload)
	elseif action == "harvestBuild" then
		return self:tryHarvestBuild(player, payload)
	end
	return false, "unknown context action"
end

return BuildService
