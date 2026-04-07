local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local MathUtil = require(Util:WaitForChild("MathUtil"))
local ChunkSystem = require(script.Parent.Parent.Systems.ChunkSystem)

local SpawnService = {}
SpawnService.__index = SpawnService

function SpawnService.new(worldService, creatureService)
	return setmetatable({
		worldService = worldService,
		creatureService = creatureService,
		timer = 0,
		interval = 1.5,
		maxWildBase = 10,
		maxWildPerPlayer = 8,
		maxWildPerChunk = 4,
		spawnSpacing = 20,
		noSpawnInnerRadius = 55,
		despawnDistance = 320,
		despawnAgeGrace = 22,
	}, SpawnService)
end

function SpawnService:getTierConfig(tier)
	if tier == "small" then
		return { team = 1, aggroMult = 0.72, pursuitRange = 90, targetNearPlayerBias = 0.55, statMult = { maxHP = 0.86, pAtk = 0.9, eAtk = 0.9, spd = 1.05 }, sizeMult = 0.85, timidness = 1.35, commitment = 0.75 }
	elseif tier == "big" then
		return { team = 2, aggroMult = 1.45, pursuitRange = 180, targetNearPlayerBias = 0.0, statMult = { maxHP = 1.35, pAtk = 1.22, eAtk = 1.22, spd = 0.94 }, sizeMult = 1.26, timidness = 0.82, commitment = 1.28 }
	end
	return { team = 1, aggroMult = 1, pursuitRange = 120, targetNearPlayerBias = 0, statMult = nil, sizeMult = 1, timidness = 1, commitment = 1 }
end

function SpawnService:rollTier()
	local r = math.random()
	if r < 0.24 then return "small" end
	if r < 0.92 then return "normal" end
	return "big"
end

function SpawnService:getPartyAverageLevel(player)
	local runtimePets = self.worldService:getPlayerPets(player.UserId)
	local total, count = 0, 0
	for _, c in ipairs(runtimePets) do
		total += (c.level or 1)
		count += 1
	end
	if count > 0 then
		return total / count
	end
	return 1
end

function SpawnService:getMaxWildCap(playerCount)
	return self.maxWildBase + math.max(0, playerCount) * self.maxWildPerPlayer
end

function SpawnService:getWildAliveCount()
	local wildAlive = 0
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive then
			wildAlive += 1
		end
	end
	return wildAlive
end

function SpawnService:countWildInChunk(cx, cz)
	local count = 0
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive then
			local wcx, wcz = ChunkSystem.worldToChunk(c.pos.X, c.pos.Z)
			if wcx == cx and wcz == cz then
				count += 1
			end
		end
	end
	return count
end

function SpawnService:isPointOutsideInnerNoSpawnRadius(point, players)
	for _, player in ipairs(players) do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(point.x, 0, point.z)).Magnitude
			if d < self.noSpawnInnerRadius then
				return false
			end
		end
	end
	return true
end

function SpawnService:isPointFarEnoughFromWilds(point)
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive then
			local d = (Vector3.new(c.pos.X, 0, c.pos.Z) - Vector3.new(point.x, 0, point.z)).Magnitude
			if d < self.spawnSpacing then
				return false
			end
		end
	end
	return true
end

function SpawnService:getAllCandidateSpawnPoints(players)
	local points = {}
	for _, chunk in pairs(self.worldService.chunks) do
		local wildInChunk = self:countWildInChunk(chunk.cx, chunk.cz)
		if wildInChunk < self.maxWildPerChunk then
			for _, point in ipairs(chunk.spawnPoints or {}) do
				if self:isPointOutsideInnerNoSpawnRadius(point, players) and self:isPointFarEnoughFromWilds(point) then
					table.insert(points, {
						point = point,
						chunk = chunk,
						score = math.max(0.05, 1 + (point.levelBias or 0) * 0.35),
					})
				end
			end
		end
	end
	return points
end

function SpawnService:pickCandidate(candidates)
	local total = 0
	for _, c in ipairs(candidates) do
		total += (c.score or 1)
	end
	if total <= 0 then
		return candidates[math.random(1, #candidates)]
	end
	local r = math.random() * total
	for _, c in ipairs(candidates) do
		r -= (c.score or 1)
		if r <= 0 then
			return c
		end
	end
	return candidates[#candidates]
end

function SpawnService:cleanupDistantUnengagedWilds(players)
	local kept = {}
	for _, c in ipairs(self.worldService.creatures) do
		local remove = false
		if c.mode == "wild" and c.alive then
			local minD = math.huge
			for _, player in ipairs(players) do
				local root = player.Character and player.Character.PrimaryPart
				if root then
					local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude
					minD = math.min(minD, d)
				end
			end
			local hasTarget = c.intent and c.intent.targetId ~= nil
			local recentlyEngaged = (self.worldService.time - (c.lastEngagedAt or -math.huge)) <= 15
			local age = self.worldService.time - (c.spawnTime or self.worldService.time)
			if minD > self.despawnDistance and (not hasTarget) and (not recentlyEngaged) and age > self.despawnAgeGrace then
				remove = true
			end
		end
		if remove then
			self.worldService.creaturesById[c.id] = nil
			if c.model then
				c.model:Destroy()
			end
		else
			table.insert(kept, c)
		end
	end
	self.worldService.creatures = kept
end

function SpawnService:pickWeightedSpecies(spawnWeights)
	local entries = {}
	for speciesKey, weight in pairs(spawnWeights or {}) do
		table.insert(entries, { key = speciesKey, weight = weight })
	end
	table.sort(entries, function(a, b) return a.key < b.key end)
	return MathUtil.pickWeighted(entries)
end

function SpawnService:update(dt)
	self.timer += dt
	if self.timer < self.interval then return end
	self.timer = 0
	local players = Players:GetPlayers()
	if #players == 0 then return end

	self:cleanupDistantUnengagedWilds(players)
	local wildAlive = self:getWildAliveCount()
	local maxWild = self:getMaxWildCap(#players)
	if wildAlive >= maxWild then return end

	for _, player in ipairs(players) do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			ChunkSystem.ensureLoaded(self.worldService, root.Position.X, root.Position.Z)
		end
	end

	local candidates = self:getAllCandidateSpawnPoints(players)
	if #candidates == 0 then return end
	local picked = self:pickCandidate(candidates)
	local point = picked.point
	local tier = self:rollTier()
	local cfg = self:getTierConfig(tier)
	local speciesKey = self:pickWeightedSpecies(point.spawnWeights)
	if not speciesKey then
		local biome = BiomeConfig[point.biomeKey] or BiomeConfig.plains
		speciesKey = MathUtil.pickWeighted(biome.spawns)
	end
	local anchorPlayer = players[math.random(1, #players)]
	local partyAverage = self:getPartyAverageLevel(anchorPlayer)
	local levelBias = point.levelBias or 0
	local level = math.max(1, math.floor(partyAverage * (1 + levelBias * 0.45) + (math.random() * 2 - 1) * 0.8 + 0.5))

	local creature = self.creatureService:spawnRuntime(speciesKey, cfg.team, point.x, point.z, {
		mode = "wild",
		wildTier = tier,
		wildProfile = cfg,
		spawnAnchor = Vector3.new(point.x, point.y or 0, point.z),
		y = point.y or 0,
		level = level,
	})
	creature.spawnTime = self.worldService.time
	creature.spawnChunkKey = picked.chunk and picked.chunk.key or nil
	self.worldService:pushEventLogNearby(Vector3.new(point.x, 0, point.z), string.format("Wild spawned: %s L%d [%s]", speciesKey, level, tier), "#ffd9a8", 220)
end

return SpawnService
