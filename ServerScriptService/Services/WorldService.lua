local Players = game:GetService("Players")
local ChunkSystem = require(script.Parent.Parent.Systems.ChunkSystem)

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

function WorldService:updateChunksAroundPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			ChunkSystem.ensureLoaded(self, root.Position.X, root.Position.Z)
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

function WorldService:stepTime(dt)
	self.time += dt
end

return WorldService
