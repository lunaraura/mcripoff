local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local Ecology = Shared:WaitForChild("Ecology")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local Creatures = Shared:WaitForChild("Creatures")
local MoveProgression = require(Creatures:WaitForChild("MoveProgression"))
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
		interval = tonumber(settings.spawnAttemptInterval) or 1.0,
		maxWildBase = 10,
		maxWildPerPlayer = 8,
		spawnSettings = settings,
		lastRejection = nil,
		rejectionCounts = {},
		lastDebugLogAt = 0,
		lastSpawnDebug = nil,
	}, SpawnService)
end

function SpawnService:noteRejection(reason)
	if not reason then return end
	self.lastRejection = reason
	self.rejectionCounts[reason] = (self.rejectionCounts[reason] or 0) + 1
end

function SpawnService:emitDebugSummary(players, candidatesCount)
	if self.spawnSettings.debugLogging ~= true then return end
	if (self.worldService.time - (self.lastDebugLogAt or 0)) < (tonumber(self.spawnSettings.debugLogInterval) or 8) then return end
	self.lastDebugLogAt = self.worldService.time
	local pieces = {}
	for reason, count in pairs(self.rejectionCounts) do
		table.insert(pieces, string.format("%s=%d", tostring(reason), tonumber(count) or 0))
	end
	table.sort(pieces)
	local summary = #pieces > 0 and table.concat(pieces, "  ") or "none"
	print(string.format("[SpawnDebug] t=%.1f players=%d wildAlive=%d candidates=%d rejections: %s",
		self.worldService.time,
		#players,
		self:getWildAliveCount(),
		tonumber(candidatesCount) or 0,
		summary
	))
	self.rejectionCounts = {}
end

function SpawnService:getPartyAverageLevel(player)
	local runtimePets = self.worldService:getPlayerPets(player.UserId)
	local total, count = 0, 0
	for _, c in ipairs(runtimePets) do total += (c.level or 1); count += 1 end
	return count > 0 and (total / count) or 1
end

function SpawnService:getMaxWildCap(playerCount)
	local baseCap = self.maxWildBase + math.max(0, playerCount) * self.maxWildPerPlayer
	local nightCfg = self.spawnSettings.night or {}
	if self.worldService:isNight() then
		baseCap = math.floor(baseCap * (tonumber(nightCfg.maxWildCapMultiplier) or 1) + 0.5)
	end
	return baseCap
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
					self:noteRejection(EcologyRules.Reason.SPAWN_TERRAIN)
				else
					local nearestPlayerDistance = math.huge
					for _, player in ipairs(players) do
						local root = player.Character and player.Character.PrimaryPart
						if root then
							local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(point.x, 0, point.z)).Magnitude
							if d < nearestPlayerDistance then
								nearestPlayerDistance = d
							end
						end
					end
					local minDistance = settings.noSpawnInnerRadius or 55
					local maxVisibleDistance = settings.visibleSpawnMaxDistance or 220
					if nearestPlayerDistance < minDistance then
						self:noteRejection(EcologyRules.Reason.SPAWN_TOO_CLOSE_PLAYER)
					elseif nearestPlayerDistance > maxVisibleDistance then
						self:noteRejection(EcologyRules.Reason.SPAWN_TOO_FAR_PLAYER)
					else
						local nearWild = false
						for _, c in ipairs(self.worldService.creatures) do
							if c.mode == "wild" and c.alive and (Vector3.new(c.pos.X, 0, c.pos.Z) - Vector3.new(point.x, 0, point.z)).Magnitude < (settings.spacing or 20) then
								nearWild = true
								break
							end
						end
						if nearWild then
							self:noteRejection(EcologyRules.Reason.SPAWN_TOO_CLOSE_WILD)
						else
							local preferredDistance = tonumber(settings.preferredSpawnDistance) or 130
							local distanceBias = 1 - math.clamp(math.abs(nearestPlayerDistance - preferredDistance) / math.max(20, maxVisibleDistance), 0, 0.9)
							local score = math.max(0.05, (1 + (point.levelBias or 0) * 0.35) * (0.35 + distanceBias))
							table.insert(points, {
								point = point,
								chunk = chunk,
								score = score,
								nearestPlayerDistance = nearestPlayerDistance,
							})
						end
					end
				end
			end
		else
			self:noteRejection(EcologyRules.Reason.SPAWN_CHUNK_CAP)
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
	local removedCount = 0
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
			removedCount += 1
		else
			table.insert(kept, c)
		end
	end
	self.worldService.creatures = kept
	if removedCount > 0 and self.spawnSettings.debugLogging == true then
		print(string.format("[SpawnDebug] cleanup removed distant wilds: %d", removedCount))
	end
end

function SpawnService:pickWeightedSpecies(spawnWeights)
	local entries = {}
	for speciesKey, weight in pairs(spawnWeights or {}) do table.insert(entries, { key = speciesKey, weight = weight }) end
	table.sort(entries, function(a, b) return a.key < b.key end)
	return MathUtil.pickWeighted(entries)
end

function SpawnService:buildMoveSet(speciesKey, level, profile)
	local base = table.clone(MoveProgression.getLearnedMoves(speciesKey, level))
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
	if self:getWildAliveCount() >= self:getMaxWildCap(#players) then
		self:noteRejection("GLOBAL_WILD_CAP_REACHED")
		self:emitDebugSummary(players, 0)
		return
	end

	for _, player in ipairs(players) do
		local root = player.Character and player.Character.PrimaryPart
		if root then ChunkSystem.ensureLoaded(self.worldService, root.Position.X, root.Position.Z) end
	end

	local candidates = self:getAllCandidateSpawnPoints(players)
	if #candidates == 0 then
		self:emitDebugSummary(players, 0)
		return
	end
	local picked = self:pickCandidate(candidates)
	local point = picked.point
	local tod = self.worldService:getTimeOfDayNormalized()
	local tierKey, tierCfg = EcologyRules.pickTierAtTime(tod)
	local profile = EcologyRules.buildSpawnProfile(point, tierKey, tierCfg)
	local variantKey, variantCfg = EcologyRules.pickWildVariant(tod)
	if variantCfg then
		for k, v in pairs(variantCfg.statMult or {}) do
			profile.statMult[k] = (profile.statMult[k] or 1) * v
		end
		profile.sizeMult = (profile.sizeMult or 1) * (tonumber(variantCfg.sizeMult) or 1)
	end
	local speciesKey = self:pickWeightedSpecies(point.spawnWeights)
	if not speciesKey then speciesKey = MathUtil.pickWeighted((BiomeConfig[point.biomeKey] or BiomeConfig.plains).spawns) end
	local level = math.max(1, math.floor(self:getPartyAverageLevel(players[math.random(1, #players)]) * (1 + (point.levelBias or 0) * 0.45) + (math.random() * 2 - 1) * 0.8 + 0.5))
	if self.worldService:isNight() then
		level += tonumber(self.spawnSettings.night and self.spawnSettings.night.levelBonus) or 0
	end
	if variantKey == "elite" then
		level += 1
	elseif variantKey == "apex" then
		level += 2
	end
	level = math.max(1, math.floor(level))
	local moveset = self:buildMoveSet(speciesKey, level, profile)

	local payload = {
		mode = "wild",
		wildTier = tierKey,
		wildVariant = variantKey,
		wildArchetype = profile.archetypeKey,
		wildProfile = {
			aggroMult = profile.aggroMult,
			pursuitRange = profile.pursuitRange,
			targetNearPlayerBias = profile.targetNearPlayerBias,
			statMult = profile.statMult,
			sizeMult = profile.sizeMult,
			timidness = profile.timidness,
			commitment = profile.commitment,
			rewardMult = variantCfg and tonumber(variantCfg.dropMult) or 1,
			morphPointBonus = variantCfg and tonumber(variantCfg.morphPointBonus) or 0,
		},
		movesetOverride = moveset,
		spawnAnchor = Vector3.new(point.x, point.y or 0, point.z),
		y = point.y or 0,
		level = level,
	}
	local ok, creature = pcall(function()
		return self.creatureService:spawnFromSpawnPayload(speciesKey, {
			team = profile.team,
			x = point.x,
			z = point.z,
			opts = payload,
		})
	end)
	if not ok or not creature then
		self:noteRejection("RUNTIME_CREATURE_CREATE_FAILED")
		if self.spawnSettings.debugLogging == true then
			warn(string.format("[SpawnDebug] spawn runtime failure species=%s biome=%s err=%s", tostring(speciesKey), tostring(point.biomeKey), tostring(creature)))
		end
		self:emitDebugSummary(players, #candidates)
		return
	end
	creature.spawnTime = self.worldService.time
	creature.spawnChunkKey = picked.chunk and picked.chunk.key or nil
	if not (creature.model and creature.model.Parent) then
		self:noteRejection("MODEL_CREATION_FAILED")
		if self.spawnSettings.debugLogging == true then
			warn(string.format("[SpawnDebug] model missing after spawn creatureId=%s species=%s", tostring(creature.id), tostring(creature.speciesKey)))
		end
	else
		self.lastSpawnDebug = {
			creatureId = creature.id,
			speciesKey = creature.speciesKey,
			nearestPlayerDistance = picked.nearestPlayerDistance,
			chunkKey = creature.spawnChunkKey,
			pos = creature.pos,
		}
		if self.spawnSettings.debugLogging == true then
			print(string.format(
				"[SpawnDebug] spawned wild id=%d species=%s tier=%s variant=%s chunk=%s dist=%.1f pos=(%.1f,%.1f,%.1f)",
				tonumber(creature.id) or -1,
				tostring(creature.speciesKey),
				tostring(tierKey),
				tostring(variantKey or "none"),
				tostring(creature.spawnChunkKey),
				tonumber(picked.nearestPlayerDistance) or -1,
				creature.pos.X, creature.pos.Y, creature.pos.Z
			))
		end
	end
	self:emitDebugSummary(players, #candidates)
end

return SpawnService
