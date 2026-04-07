local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))
local MathUtil = require(Util:WaitForChild("MathUtil"))
local ChunkSystem = require(script.Parent.Parent.Systems.ChunkSystem)

local SpawnService = {}
SpawnService.__index = SpawnService

local ARCHETYPES = {
	skirmisher = {
		weight = 1,
		statMult = { spd = 1.12, maxHP = 0.92, pAtk = 1.04, eAtk = 1.04 },
		sizeMult = 0.93,
		abilityPool = { "ram", "zap" },
		abilitySlots = 2,
	},
	bruiser = {
		weight = 1,
		statMult = { maxHP = 1.14, pAtk = 1.12, eAtk = 0.95, spd = 0.9 },
		sizeMult = 1.08,
		abilityPool = { "ram", "stomp", "emberClaw" },
		abilitySlots = 2,
	},
	sentinel = {
		weight = 1,
		statMult = { maxHP = 1.06, pAtk = 0.96, eAtk = 1.1, spd = 0.98 },
		sizeMult = 1.03,
		abilityPool = { "zap", "stomp" },
		abilitySlots = 2,
	},
}

local BIOME_ARCHETYPE_WEIGHTS = {
	plains = { skirmisher = 3, bruiser = 2, sentinel = 1 },
	forest = { skirmisher = 2, bruiser = 2, sentinel = 2 },
	ocean = { skirmisher = 2, bruiser = 1, sentinel = 3 },
	desert = { skirmisher = 2, bruiser = 3, sentinel = 1 },
	stormfield = { skirmisher = 2, bruiser = 1, sentinel = 3 },
	volcanic = { skirmisher = 1, bruiser = 4, sentinel = 1 },
	tundra = { skirmisher = 1, bruiser = 2, sentinel = 3 },
	polar = { skirmisher = 1, bruiser = 1, sentinel = 4 },
}

local TIER_ARCHETYPE_ADJUSTMENTS = {
	small = { statMult = { spd = 1.05, maxHP = 0.92 }, slotsDelta = 0 },
	normal = { statMult = {}, slotsDelta = 0 },
	big = { statMult = { maxHP = 1.08, pAtk = 1.06, spd = 0.96 }, slotsDelta = 1 },
}

local function mergedMultipliers(a, b)
	local out = {}
	for k, v in pairs(a or {}) do out[k] = v end
	for k, v in pairs(b or {}) do out[k] = (out[k] or 1) * v end
	return out
end

local function pickWeightedMap(weightMap)
	local entries = {}
	for key, weight in pairs(weightMap or {}) do
		table.insert(entries, { key = key, weight = weight })
	end
	table.sort(entries, function(a, b) return a.key < b.key end)
	return MathUtil.pickWeighted(entries)
end

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

function SpawnService:buildMoveSet(speciesKey, archetypeKey, tier)
	local species = SpeciesConfig[speciesKey]
	local base = table.clone((species and species.moveset) or { "ram" })
	local set = {}
	for _, k in ipairs(base) do set[k] = true end
	local archetype = ARCHETYPES[archetypeKey] or ARCHETYPES.skirmisher
	for _, abilityKey in ipairs(archetype.abilityPool or {}) do
		set[abilityKey] = true
	end
	local picked = {}
	for k, _ in pairs(set) do
		table.insert(picked, k)
	end
	table.sort(picked)
	local tierAdj = TIER_ARCHETYPE_ADJUSTMENTS[tier] or TIER_ARCHETYPE_ADJUSTMENTS.normal
	local maxMoves = math.max(1, (archetype.abilitySlots or 2) + (tierAdj.slotsDelta or 0))
	while #picked > maxMoves do
		table.remove(picked, math.random(1, #picked))
	end
	return picked
end

function SpawnService:getSpawnProfile(point, tier)
	local biomeWeights = BIOME_ARCHETYPE_WEIGHTS[point.biomeKey] or BIOME_ARCHETYPE_WEIGHTS.plains
	local archetypeKey = pickWeightedMap(biomeWeights) or "skirmisher"
	local archetype = ARCHETYPES[archetypeKey] or ARCHETYPES.skirmisher
	local tierAdj = TIER_ARCHETYPE_ADJUSTMENTS[tier] or TIER_ARCHETYPE_ADJUSTMENTS.normal
	return {
		archetypeKey = archetypeKey,
		statMult = mergedMultipliers(archetype.statMult, tierAdj.statMult),
		sizeMult = (archetype.sizeMult or 1),
		timidness = archetypeKey == "skirmisher" and 1.18 or (archetypeKey == "bruiser" and 0.9 or 1.0),
		commitment = archetypeKey == "bruiser" and 1.15 or (archetypeKey == "skirmisher" and 0.9 or 1.0),
		abilitySet = archetype.abilityPool,
	}
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
	local profile = self:getSpawnProfile(point, tier)
	local anchorPlayer = players[math.random(1, #players)]
	local partyAverage = self:getPartyAverageLevel(anchorPlayer)
	local levelBias = point.levelBias or 0
	local level = math.max(1, math.floor(partyAverage * (1 + levelBias * 0.45) + (math.random() * 2 - 1) * 0.8 + 0.5))
	local combinedStatMult = mergedMultipliers(cfg.statMult, profile.statMult)
	local moveset = self:buildMoveSet(speciesKey, profile.archetypeKey, tier)

	local creature = self.creatureService:spawnRuntime(speciesKey, cfg.team, point.x, point.z, {
		mode = "wild",
		wildTier = tier,
		wildArchetype = profile.archetypeKey,
		wildProfile = {
			aggroMult = cfg.aggroMult,
			pursuitRange = cfg.pursuitRange,
			targetNearPlayerBias = cfg.targetNearPlayerBias,
			statMult = combinedStatMult,
			sizeMult = (cfg.sizeMult or 1) * (profile.sizeMult or 1),
			timidness = (cfg.timidness or 1) * (profile.timidness or 1),
			commitment = (cfg.commitment or 1) * (profile.commitment or 1),
		},
		movesetOverride = moveset,
		spawnAnchor = Vector3.new(point.x, point.y or 0, point.z),
		y = point.y or 0,
		level = level,
	})
	creature.spawnTime = self.worldService.time
	creature.spawnChunkKey = picked.chunk and picked.chunk.key or nil
	self.worldService:pushEventLogNearby(Vector3.new(point.x, 0, point.z), string.format("Wild spawned: %s L%d [%s/%s]", speciesKey, level, tier, profile.archetypeKey), "#ffd9a8", 220)
end

return SpawnService
