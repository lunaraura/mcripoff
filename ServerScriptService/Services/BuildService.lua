local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = Shared:WaitForChild("Build")
local PlacementRules = require(Build:WaitForChild("PlacementRules"))

local BuildService = {}
BuildService.__index = BuildService

BuildService.Actions = {
	BUILD = "build",
	HARVEST_BUILD = "harvestBuild",
	GATHER = "gather",
	CONTEXT = "context",
	PLANT_SHRUB = "plantShrub",
}

function BuildService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService, objectiveService = nil, nextBuildId = 1, buildables = {} }, BuildService)
end

local SHRUB_BERRY_KEYS = {
	berry_red = true,
	berry_yellow = true,
	berry_blue = true,
	revive_berry = true,
	replenish_berry = true,
}
local SHRUB_GROWTH_SECONDS = 90
local SHRUB_YIELD_AMOUNT = 2

local function getShrubDisplayColor(berryKey, stage)
	local colorMap = {
		berry_red = Color3.fromRGB(200, 85, 85),
		berry_yellow = Color3.fromRGB(230, 210, 110),
		berry_blue = Color3.fromRGB(110, 180, 255),
		revive_berry = Color3.fromRGB(150, 120, 240),
		replenish_berry = Color3.fromRGB(90, 200, 220),
	}
	local base = colorMap[berryKey] or Color3.fromRGB(160, 220, 120)
	if stage == "planted" then
		return base:Lerp(Color3.fromRGB(50, 60, 50), 0.55)
	end
	if stage == "growing" then
		return base:Lerp(Color3.fromRGB(95, 125, 95), 0.25)
	end
	return base
end

function BuildService:configureObjectiveService(objectiveService)
	self.objectiveService = objectiveService
end

function BuildService:isFeatureUnlocked(player, featureKey)
	if not self.objectiveService then
		return true
	end
	return self.objectiveService:isFeatureUnlocked(player, featureKey)
end

function BuildService:getOrCreateBuildFolder()
	local world = workspace:FindFirstChild("World") or Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	local builds = world:FindFirstChild("Buildables") or Instance.new("Folder")
	builds.Name = "Buildables"
	builds.Parent = world
	return builds
end

function BuildService:createBuildModel(build)
	local def = PlacementRules.getBuildDef(build.key)
	local placement = PlacementRules.getPlacement(build.key)
	if not def or not placement then return nil end
	local preview = placement.previewSize
	local parentFolder = self:getOrCreateBuildFolder()
	local shape = placement.previewShape or "block"
	local part = shape == "wedge" and Instance.new("WedgePart") or Instance.new("Part")
	part.Size = Vector3.new(preview.x or 4, preview.y or 4, preview.z or 4)
	part.Anchored = true
	part.CanCollide = true
	part.CFrame = CFrame.new(build.pos) * CFrame.Angles(0, math.rad(build.rotationY or 0), 0)
	part.Name = string.format("Build_%s_%d", build.key, build.id)
	if build.key == "berry_shrub" then
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Grass
		part.Color = getShrubDisplayColor(build.shrubBerryKey, build.shrubStage)
		part.CanCollide = true
	end
	part:SetAttribute("CollisionCategory", "buildable")
	part:SetAttribute("BuildableKey", build.key)
	part:SetAttribute("BuildableId", build.id)
	part:SetAttribute("BuildRecordId", build.id)
	part:SetAttribute("InteractionHook", "harvest_build")
	part.Parent = parentFolder
	build.model = part
	return part
end

function BuildService:getShrubGrowthStage(build, now)
	now = now or self.worldService.time
	if build.key ~= "berry_shrub" then return nil end
	local plantedAt = tonumber(build.shrubPlantedAt) or now
	local matureAt = tonumber(build.shrubMatureAt) or (plantedAt + SHRUB_GROWTH_SECONDS)
	if now >= matureAt then
		return "mature"
	end
	local progress = math.clamp((now - plantedAt) / math.max(1, matureAt - plantedAt), 0, 1)
	if progress < 0.35 then
		return "planted"
	end
	return "growing"
end

function BuildService:refreshShrubVisual(build)
	if not build or build.key ~= "berry_shrub" then return end
	local stage = self:getShrubGrowthStage(build, self.worldService.time)
	build.shrubStage = stage
	local part = build.model
	if not (part and part:IsA("BasePart")) then return end
	part:SetAttribute("ShrubBerryKey", tostring(build.shrubBerryKey or "berry_red"))
	part:SetAttribute("GrowthStage", stage)
	part:SetAttribute("Mature", stage == "mature")
	part.Color = getShrubDisplayColor(build.shrubBerryKey, stage)
	if stage == "planted" then
		part.Size = Vector3.new(2.6, 2.2, 2.6)
	elseif stage == "growing" then
		part.Size = Vector3.new(3.6, 3.2, 3.6)
	else
		part.Size = Vector3.new(4.4, 4.0, 4.4)
	end
end

function BuildService:getCellAtPosition(pos)
	local cx, cz = math.floor(pos.X / 64), math.floor(pos.Z / 64)
	local key = string.format("%d:%d", cx, cz)
	local chunk = self.worldService.chunks[key]
	if not chunk then return nil end
	local best, bestD = nil, math.huge
	for _, cell in ipairs(chunk.cells or {}) do
		local d = (Vector3.new(cell.x, 0, cell.z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bestD then best, bestD = cell, d end
	end
	return best
end

function BuildService:getBlockingCategory(part)
	local category = part:GetAttribute("CollisionCategory")
	if category == "buildable" or part:FindFirstAncestor("Buildables") then return "build" end
	if category == "node" or category == "obstacle" or part:FindFirstAncestor("Nodes") then return "obstacle" end
	if part:FindFirstAncestor("CreatureModels") then return "creature" end
	return nil
end

function BuildService:validatePlacement(player, buildKey, pos, rotationY)
	local def = PlacementRules.getBuildDef(buildKey)
	local placement = PlacementRules.getPlacement(buildKey)
	if not def or not placement then return { ok = false, reasonCode = PlacementRules.Reason.UNKNOWN_BUILD_KEY } end
	local root = player.Character and player.Character.PrimaryPart
	if not root then return { ok = false, reasonCode = PlacementRules.Reason.NO_CHARACTER } end
	local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
	if dist > placement.placementRange then return { ok = false, reasonCode = PlacementRules.Reason.TOO_FAR } end
	local cell = self:getCellAtPosition(pos)
	if not cell then return { ok = false, reasonCode = PlacementRules.Reason.MISSING_CELL } end
	if cell.blocked or cell.water then return { ok = false, reasonCode = PlacementRules.Reason.BLOCKED_TERRAIN } end
	if not PlacementRules.isTerrainAllowed(cell.terrainClass or "ground", placement) then
		return { ok = false, reasonCode = PlacementRules.Reason.INVALID_TERRAIN }
	end

	local fp = placement.footprintSize
	local size = Vector3.new(fp.x or 4, fp.y or 4, fp.z or 4)
	local cframe = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotationY or 0), 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local parts = Workspace:GetPartBoundsInBox(cframe, size, params)
	for _, part in ipairs(parts) do
		if part and part.CanCollide and part.Transparency < 0.95 then
			local c = self:getBlockingCategory(part)
			if c == "build" then return { ok = false, reasonCode = PlacementRules.Reason.OVERLAP_BUILD } end
			if c == "obstacle" then return { ok = false, reasonCode = PlacementRules.Reason.OVERLAP_OBSTACLE } end
			if c == "creature" then return { ok = false, reasonCode = PlacementRules.Reason.OVERLAP_CREATURE } end
		end
	end
	for _, c in ipairs(self.worldService.creatures) do
		if c.alive then
			local d = (Vector3.new(c.pos.X, 0, c.pos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if d < math.max(4, placement.collisionRadius) then
				return { ok = false, reasonCode = PlacementRules.Reason.OVERLAP_CREATURE }
			end
		end
	end
	return { ok = true, reasonCode = PlacementRules.Reason.OK, placement = placement, def = def }
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
	if not self:isFeatureUnlocked(player, "building_tool") then
		return false, { reasonCode = "FEATURE_LOCKED_BUILDING" }
	end
	local buildKey = payload.buildKey or "fiber_trap"
	if buildKey == "berry_shrub" then
		return false, { reasonCode = "USE_BERRY_PLANT_ACTION" }
	end
	local validationDef = PlacementRules.getBuildDef(buildKey)
	if not validationDef then return false, { reasonCode = PlacementRules.Reason.UNKNOWN_BUILD_KEY } end
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, { reasonCode = PlacementRules.Reason.NO_CHARACTER } end
	local placement = PlacementRules.getPlacement(buildKey)
	local rotationY = placement.allowRotation and (tonumber(payload.rotationY) or 0) or 0
	local desiredPos = typeof(payload.position) == "Vector3" and payload.position or (root.Position + root.CFrame.LookVector * 8)
	local snapped = PlacementRules.snapPosition(desiredPos, placement.grid, desiredPos.Y)
	local v = self:validatePlacement(player, buildKey, snapped, rotationY)
	if not v.ok then return false, v end
	local ok, missing = self:canAfford(player, validationDef.cost)
	if not ok then return false, { reasonCode = PlacementRules.Reason.MISSING_MATERIALS, missing = missing } end
	for matKey, amount in pairs(validationDef.cost or {}) do
		self.inventoryService:tryConsume(player, matKey, amount)
	end
	local harvest = PlacementRules.getHarvest(validationDef)
	local id = self.nextBuildId
	self.nextBuildId += 1
	self.buildables[id] = {
		id = id,
		key = buildKey,
		ownerUserId = player.UserId,
		pos = snapped,
		rotationY = rotationY,
		nextHarvestAt = self.worldService.time + harvest.interval,
		lastEffectAt = 0,
		harvest = harvest,
		record = { reasonCode = PlacementRules.Reason.OK, createdAt = self.worldService.time },
	}
	self:createBuildModel(self.buildables[id])
	return true, self.buildables[id]
end

function BuildService:nearestCell(root)
	local best, bestD = nil, math.huge
	for _, chunk in pairs(self.worldService.chunks) do
		for _, cell in ipairs(chunk.cells) do
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(cell.x, 0, cell.z)).Magnitude
			if d < bestD then best, bestD = cell, d end
		end
	end
	return best, bestD
end

function BuildService:tryGather(player)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, { reasonCode = PlacementRules.Reason.NO_CHARACTER } end
	local cell, dist = self:nearestCell(root)
	if not cell or dist > 18 then return false, { reasonCode = PlacementRules.Reason.NOT_FOUND } end
	local key = cell.terrainClass == "rock" and "stone" or (cell.terrainClass == "water" and "battery_seed" or "fiber")
	return true, self.inventoryService:grant(player, { { key = key, amount = 1 } })
end

function BuildService:getResolvedHarvestRewards(build)
	local rewards = {}
	for key, amount in pairs((build.harvest and build.harvest.provides) or {}) do
		table.insert(rewards, { key = (key == "bait" and "lure_meat" or key), amount = amount })
	end
	if build.key == "berry_shrub" and build.shrubBerryKey then
		table.insert(rewards, { key = build.shrubBerryKey, amount = SHRUB_YIELD_AMOUNT })
	end
	return rewards
end

function BuildService:tryPlantShrub(player, payload)
	payload = payload or {}
	if not self:isFeatureUnlocked(player, "planter_tool") then
		return false, { reasonCode = "FEATURE_LOCKED_PLANTER" }
	end
	local berryKey = tostring(payload.berryKey or "berry_red")
	if not SHRUB_BERRY_KEYS[berryKey] then
		return false, { reasonCode = "INVALID_BERRY_KEY" }
	end
	if self.inventoryService:getCount(player, berryKey) < 1 then
		return false, { reasonCode = "MISSING_BERRY", berryKey = berryKey }
	end
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, { reasonCode = PlacementRules.Reason.NO_CHARACTER } end
	local placement = PlacementRules.getPlacement("berry_shrub")
	local desiredPos = typeof(payload.position) == "Vector3" and payload.position or (root.Position + root.CFrame.LookVector * 8)
	local sampledY = self.worldService.resolveCreatureGroundY and self.worldService:resolveCreatureGroundY(desiredPos.X, desiredPos.Z, desiredPos.Y) or desiredPos.Y
	local snapped = PlacementRules.snapPosition(desiredPos, placement.grid, sampledY)
	local v = self:validatePlacement(player, "berry_shrub", snapped, 0)
	if not v.ok then return false, v end
	local consumed = self.inventoryService:tryConsume(player, berryKey, 1)
	if not consumed then
		return false, { reasonCode = "MISSING_BERRY", berryKey = berryKey }
	end
	local id = self.nextBuildId
	self.nextBuildId += 1
	local harvest = PlacementRules.getHarvest(v.def)
	local plantedAt = self.worldService.time
	self.buildables[id] = {
		id = id,
		key = "berry_shrub",
		ownerUserId = player.UserId,
		pos = snapped,
		rotationY = 0,
		nextHarvestAt = plantedAt + SHRUB_GROWTH_SECONDS,
		lastEffectAt = 0,
		harvest = harvest,
		shrubBerryKey = berryKey,
		shrubPlantedAt = plantedAt,
		shrubMatureAt = plantedAt + SHRUB_GROWTH_SECONDS,
		shrubStage = "planted",
		record = { reasonCode = PlacementRules.Reason.OK, createdAt = self.worldService.time },
	}
	self:createBuildModel(self.buildables[id])
	self:refreshShrubVisual(self.buildables[id])
	self.worldService:pushEventLog(player, string.format("Planted shrub (%s)", berryKey), "#b7f0c1")
	return true, self.buildables[id]
end

function BuildService:tryHarvestBuild(player)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, { reasonCode = PlacementRules.Reason.NO_CHARACTER } end
	local best, bestD = nil, 12
	for _, b in pairs(self.buildables) do
		local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(b.pos.X, 0, b.pos.Z)).Magnitude
		if d < bestD then best, bestD = b, d end
	end
	if not best then return false, { reasonCode = PlacementRules.Reason.NOT_FOUND } end
	if best.key == "berry_shrub" then
		local stage = self:getShrubGrowthStage(best, self.worldService.time)
		self:refreshShrubVisual(best)
		if stage ~= "mature" then
			return false, { reasonCode = PlacementRules.Reason.NOT_READY, growthStage = stage, readyAt = best.shrubMatureAt }
		end
	end
	if self.worldService.time < (best.nextHarvestAt or 0) then return false, { reasonCode = PlacementRules.Reason.NOT_READY } end
	local rewards = self:getResolvedHarvestRewards(best)
	if best.key == "berry_shrub" then
		best.shrubPlantedAt = self.worldService.time
		best.shrubMatureAt = self.worldService.time + SHRUB_GROWTH_SECONDS
		best.nextHarvestAt = best.shrubMatureAt
		best.shrubStage = "planted"
		self:refreshShrubVisual(best)
	else
		best.nextHarvestAt = self.worldService.time + ((best.harvest and best.harvest.interval) or 1)
	end
	return true, self.inventoryService:grant(player, rewards)
end

function BuildService:tickStructureEffects()
	for _, b in pairs(self.buildables) do
		if b.key == "berry_shrub" then
			self:refreshShrubVisual(b)
		end
		local def = PlacementRules.getBuildDef(b.key)
		local effect = def and def.effect
		if effect and effect.type == "pet_regen" then
			local interval = math.max(1, tonumber(effect.interval) or 5)
			if self.worldService.time >= (b.lastEffectAt or 0) + interval then
				b.lastEffectAt = self.worldService.time
				for _, creature in ipairs(self.worldService.creatures) do
					if creature.alive and creature.mode == "pet" and (Vector3.new(creature.pos.X, 0, creature.pos.Z) - Vector3.new(b.pos.X, 0, b.pos.Z)).Magnitude <= (effect.radius or 20) then
						local maxHP = creature.modifiedStats and creature.modifiedStats.maxHP or creature.currentHP
						creature.currentHP = math.min(maxHP, creature.currentHP + math.max(1, math.floor(effect.flatHeal or 5)))
					end
				end
			end
		end
	end
end

function BuildService:handleContextAction(player, payload)
	payload = payload or {}
	local action = payload.action or BuildService.Actions.CONTEXT
	if action == BuildService.Actions.BUILD then return self:tryBuild(player, payload) end
	if action == BuildService.Actions.PLANT_SHRUB then return self:tryPlantShrub(player, payload) end
	if action == BuildService.Actions.HARVEST_BUILD then return self:tryHarvestBuild(player) end
	if action == BuildService.Actions.GATHER then return self:tryGather(player) end
	if action == BuildService.Actions.CONTEXT then
		local ok, result = self:tryHarvestBuild(player)
		if ok then return true, result end
		return self:tryGather(player)
	end
	return false, { reasonCode = PlacementRules.Reason.INVALID_ACTION }
end

return BuildService
