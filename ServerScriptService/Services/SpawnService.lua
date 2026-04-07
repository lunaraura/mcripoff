local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local Ecology = Shared:WaitForChild("Ecology")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))
local MathUtil = require(Util:WaitForChild("MathUtil"))
local EcologyRules = require(Ecology:WaitForChild("EcologyRules"))
local ChunkSystem = require(script.Parent.Parent.Systems.ChunkSystem)

local SpawnService = {}
SpawnService.__index = SpawnService

function SpawnService.new(worldService, creatureService)
	local settings = EcologyRules.getSpawnSettings()
	return setmetatable({
		worldService = worldService,
		creatureService = creatureService,
		timer = 0,
		interval = 1.5,
		maxWildBase = 10,
		maxWildPerPlayer = 8,
		spawnSettings = settings,
		lastRejection = nil,
	}, SpawnService)
end

function SpawnService:getPartyAverageLevel(player)
	local runtimePets = self.worldService:getPlayerPets(player.UserId)
	local total, count = 0, 0
	for _, c in ipairs(runtimePets) do total += (c.level or 1); count += 1 end
	return count > 0 and (total / count) or 1
end

function SpawnService:getMaxWildCap(playerCount)
	return self.maxWildBase + math.max(0, playerCount) * self.maxWildPerPlayer
end

function SpawnService:getWildAliveCount()
	local wildAlive = 0
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive then wildAlive += 1 end
	end
	return wildAlive
end

function SpawnService:countWildInChunk(cx, cz)
	local count = 0
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive then
			local wcx, wcz = ChunkSystem.worldToChunk(c.pos.X, c.pos.Z)
			if wcx == cx and wcz == cz then count += 1 end
		end
	end
	return count
end

function SpawnService:getAllCandidateSpawnPoints(players)
	local settings = self.spawnSettings
	local points = {}
	for _, chunk in pairs(self.worldService.chunks) do
		if self:countWildInChunk(chunk.cx, chunk.cz) < (settings.chunkCap or 4) then
			for _, point in ipairs(chunk.spawnPoints or {}) do
				local cellOk = point.terrainClass == "ground"
				if not cellOk then
					self.lastRejection = EcologyRules.Reason.SPAWN_TERRAIN
				else
					local nearPlayer = false
					for _, player in ipairs(players) do
						local root = player.Character and player.Character.PrimaryPart
						if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(point.x, 0, point.z)).Magnitude < (settings.noSpawnInnerRadius or 55) then
							nearPlayer = true
							break
						end
					end
					if nearPlayer then
						self.lastRejection = EcologyRules.Reason.SPAWN_TOO_CLOSE_PLAYER
					else
						local nearWild = false
						for _, c in ipairs(self.worldService.creatures) do
							if c.mode == "wild" and c.alive and (Vector3.new(c.pos.X, 0, c.pos.Z) - Vector3.new(point.x, 0, point.z)).Magnitude < (settings.spacing or 20) then
								nearWild = true
								break
							end
						end
						if nearWild then
							self.lastRejection = EcologyRules.Reason.SPAWN_TOO_CLOSE_WILD
						else
							table.insert(points, { point = point, chunk = chunk, score = math.max(0.05, 1 + (point.levelBias or 0) * 0.35) })
						end
					end
				end
			end
		else
			self.lastRejection = EcologyRules.Reason.SPAWN_CHUNK_CAP
		end
	end
	return points
end

function SpawnService:pickCandidate(candidates)
	local total = 0
	for _, c in ipairs(candidates) do total += (c.score or 1) end
	if total <= 0 then return candidates[math.random(1, #candidates)] end
	local r = math.random() * total
	for _, c in ipairs(candidates) do
		r -= (c.score or 1)
		if r <= 0 then return c end
	end
	return candidates[#candidates]
end

function SpawnService:cleanupDistantUnengagedWilds(players)
	local settings = self.spawnSettings
	local kept = {}
	for _, c in ipairs(self.worldService.creatures) do
		local remove = false
		if c.mode == "wild" and c.alive then
			local minD = math.huge
			for _, player in ipairs(players) do
				local root = player.Character and player.Character.PrimaryPart
				if root then minD = math.min(minD, (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude) end
			end
			local age = self.worldService.time - (c.spawnTime or self.worldService.time)
			if minD > (settings.despawnDistance or 320) and (not (c.intent and c.intent.targetId)) and ((self.worldService.time - (c.lastEngagedAt or -math.huge)) > 15) and age > (settings.despawnAgeGrace or 22) then
				remove = true
			end
		end
		if remove then
			self.worldService.creaturesById[c.id] = nil
			if c.model then c.model:Destroy() end
		else
			table.insert(kept, c)
		end
	end
	self.worldService.creatures = kept
end

function SpawnService:pickWeightedSpecies(spawnWeights)
	local entries = {}
	for speciesKey, weight in pairs(spawnWeights or {}) do table.insert(entries, { key = speciesKey, weight = weight }) end
	table.sort(entries, function(a, b) return a.key < b.key end)
	return MathUtil.pickWeighted(entries)
end

function SpawnService:buildMoveSet(speciesKey, profile)
	local species = SpeciesConfig[speciesKey]
	local base = table.clone((species and species.moveset) or { "ram" })
	local set = {}
	for _, k in ipairs(base) do set[k] = true end
	for _, abilityKey in ipairs(profile.abilityPool or {}) do set[abilityKey] = true end
	local picked = {}
	for k, _ in pairs(set) do table.insert(picked, k) end
	table.sort(picked)
	while #picked > math.max(1, profile.abilitySlots or 2) do table.remove(picked, math.random(1, #picked)) end
	return picked
end

function SpawnService:update(dt)
	self.timer += dt
	if self.timer < self.interval then return end
	self.timer = 0
	local players = Players:GetPlayers()
	if #players == 0 then return end
	self:cleanupDistantUnengagedWilds(players)
	if self:getWildAliveCount() >= self:getMaxWildCap(#players) then return end

	for _, player in ipairs(players) do
		local root = player.Character and player.Character.PrimaryPart
		if root then ChunkSystem.ensureLoaded(self.worldService, root.Position.X, root.Position.Z) end
	end

	local candidates = self:getAllCandidateSpawnPoints(players)
	if #candidates == 0 then return end
	local picked = self:pickCandidate(candidates)
	local point = picked.point
	local tierKey, tierCfg = EcologyRules.pickTier()
	local profile = EcologyRules.buildSpawnProfile(point, tierKey, tierCfg)
	local speciesKey = self:pickWeightedSpecies(point.spawnWeights)
	if not speciesKey then speciesKey = MathUtil.pickWeighted((BiomeConfig[point.biomeKey] or BiomeConfig.plains).spawns) end
	local level = math.max(1, math.floor(self:getPartyAverageLevel(players[math.random(1, #players)]) * (1 + (point.levelBias or 0) * 0.45) + (math.random() * 2 - 1) * 0.8 + 0.5))
	local moveset = self:buildMoveSet(speciesKey, profile)

	local payload = {
		mode = "wild",
		wildTier = tierKey,
		wildArchetype = profile.archetypeKey,
		wildProfile = {
			aggroMult = profile.aggroMult,
			pursuitRange = profile.pursuitRange,
			targetNearPlayerBias = profile.targetNearPlayerBias,
			statMult = profile.statMult,
			sizeMult = profile.sizeMult,
			timidness = profile.timidness,
			commitment = profile.commitment,
		},
		movesetOverride = moveset,
		spawnAnchor = Vector3.new(point.x, point.y or 0, point.z),
		y = point.y or 0,
		level = level,
	}
	local creature = self.creatureService:spawnFromSpawnPayload(speciesKey, {
		team = profile.team,
		x = point.x,
		z = point.z,
		opts = payload,
	})
	creature.spawnTime = self.worldService.time
	creature.spawnChunkKey = picked.chunk and picked.chunk.key or nil
end

return SpawnService
