local Players = game:GetService("Players")
local ChunkSystem = require(script.Parent.Parent.Systems.ChunkSystem)
local BiomeSystem = require(script.Parent.Parent.Systems.BiomeSystem)

local WorldService = {}
WorldService.__index = WorldService

function WorldService.new(remotes)
	return setmetatable({
		time = 0,
		creatures = {},
		creaturesById = {},
		chunks = {},
		nodes = {},
		barriers = {},
		wallBarriers = {},
		projectiles = {},
		areaEffects = {},
		remotes = remotes,
	}, WorldService)
end

function WorldService:addCreature(creature)
	table.insert(self.creatures, creature)
	self.creaturesById[creature.id] = creature
end

function WorldService:getCreatureById(id)
	return self.creaturesById[id]
end

function WorldService:removeCreature(id)
	local target = self.creaturesById[id]
	if not target then return false end
	self.creaturesById[id] = nil
	local filtered = {}
	for _, c in ipairs(self.creatures) do
		if c.id ~= id then
			table.insert(filtered, c)
		end
	end
	self.creatures = filtered
	if target.model then
		target.model:Destroy()
	end
	return true
end

function WorldService:removeDead()
	local filtered = {}
	for _, c in ipairs(self.creatures) do
		if c.alive then
			table.insert(filtered, c)
		else
			self.creaturesById[c.id] = nil
			if c.model then c.model:Destroy() end
		end
	end
	self.creatures = filtered
end

function WorldService:findNearestEnemyOf(creature, maxRange)
	local best, bestD = nil, maxRange or math.huge
	for _, other in ipairs(self.creatures) do
		if other.id ~= creature.id and other.alive and other.team ~= creature.team then
			local d = (Vector3.new(creature.pos.X, 0, creature.pos.Z) - Vector3.new(other.pos.X, 0, other.pos.Z)).Magnitude
			if d < bestD then
				best, bestD = other, d
			end
		end
	end
	return best, bestD
end

function WorldService:getChunkCellAtWorld(x, z)
	local cx, cz = ChunkSystem.worldToChunk(x, z)
	local chunk = self.chunks[ChunkSystem.key(cx, cz)]
	if not chunk or not chunk.cells then return nil end
	local cellsPerAxis = ChunkSystem.CHUNK_SIZE / ChunkSystem.CELL_SIZE
	local localX = x - (cx * ChunkSystem.CHUNK_SIZE)
	local localZ = z - (cz * ChunkSystem.CHUNK_SIZE)
	local ix = math.clamp(math.floor((localX / ChunkSystem.CELL_SIZE) + 0.5), 0, cellsPerAxis - 1)
	local iz = math.clamp(math.floor((localZ / ChunkSystem.CELL_SIZE) + 0.5), 0, cellsPerAxis - 1)
	local idx = iz * cellsPerAxis + ix + 1
	return chunk.cells[idx]
end

-- Canonical contract: creature.pos.Y is ALWAYS world ground-contact height (feet), never model center.
function WorldService:resolveCreatureGroundY(x, z, fallbackY)
	local cell = self:getChunkCellAtWorld(x, z)
	if cell and (cell.yGround or cell.yG) then
		return cell.yGround or cell.yG
	end
	local env = BiomeSystem.sampleEnvironment(x, z)
	if env and env.yGround then
		return env.yGround
	end
	return fallbackY or 0
end

function WorldService:snapCreatureToGround(creature)
	if not creature or not creature.pos then return nil end
	local y = self:resolveCreatureGroundY(creature.pos.X, creature.pos.Z, creature.pos.Y)
	creature.pos = Vector3.new(creature.pos.X, y, creature.pos.Z)
	creature.lastResolvedGroundY = y
	return y
end

function WorldService:updateChunksAroundPlayers()
	local wanted = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			local ccx, ccz = ChunkSystem.worldToChunk(root.Position.X, root.Position.Z)
			local radius = math.max(ChunkSystem.LOAD_RADIUS, tonumber(player:GetAttribute("RadiusChunks")) or ChunkSystem.LOAD_RADIUS)
			ChunkSystem.ensureLoaded(self, root.Position.X, root.Position.Z, radius)
			for dz = -radius, radius do
				for dx = -radius, radius do
					wanted[ChunkSystem.key(ccx + dx, ccz + dz)] = true
				end
			end
		end
	end
	for key, chunk in pairs(self.chunks) do
		if not wanted[key] then
			ChunkSystem.clearChunkTerrain(chunk)
			self.chunks[key] = nil
		end
	end
end

function WorldService:pushFloatingText(position, text, color)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character.PrimaryPart
		if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < 180 then
			self.remotes.FloatingTextEvent:FireClient(player, {
				x = position.X,
				z = position.Z,
				text = text,
				color = color or "#ffd7d7",
			})
		end
	end
end

function WorldService:pushEventLog(player, text, color)
	if not self.remotes.EventLogEvent then return end
	self.remotes.EventLogEvent:FireClient(player, {
		text = text,
		color = color or "#e8f2ff",
		t = self.time,
	})
end

function WorldService:pushEventLogNearby(position, text, color, range)
	local r = range or 180
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character.PrimaryPart
		if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude <= r then
			self:pushEventLog(player, text, color)
		end
	end
end

function WorldService:getPlayerPets(userId)
	local out = {}
	for _, c in ipairs(self.creatures) do
		if c.alive and c.ownerUserId == userId and c.mode == "pet" then
			table.insert(out, c)
		end
	end
	table.sort(out, function(a, b)
		return (a.partySlot or 99) < (b.partySlot or 99)
	end)
	return out
end

function WorldService:getRuntimeCreatureForOwnedId(userId, ownedId)
	if not ownedId then return nil end
	for _, c in ipairs(self.creatures) do
		if c.ownerUserId == userId and c.mode == "pet" and c.ownedId == ownedId then
			return c
		end
	end
	return nil
end

function WorldService:stepTime(dt)
	self.time += dt
end

return WorldService
