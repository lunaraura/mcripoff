local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))
local CompositeConfig = require(Config:WaitForChild("CompositeConfig"))

-- Visual sphere colors by effect tag
local VISUAL_COLORS = {
	electric = Color3.fromRGB(100, 200, 255),
	fire = Color3.fromRGB(255, 150, 50),
	impact = Color3.fromRGB(255, 200, 100),
	physical = Color3.fromRGB(180, 180, 180),
	defensive = Color3.fromRGB(100, 150, 255),
	water = Color3.fromRGB(100, 180, 255),
	utility = Color3.fromRGB(150, 255, 150),
}

local function getVisualColor(ability)
	if not ability or not ability.effectTags then
		return Color3.fromRGB(255, 200, 50)
	end
	for _, tag in ipairs(ability.effectTags) do
		if VISUAL_COLORS[tag] then
			return VISUAL_COLORS[tag]
		end
	end
	return Color3.fromRGB(255, 200, 50)
end

local CombatService = {}
CombatService.__index = CombatService
local DEFEATED_WILD_TIMEOUT_SECONDS = 60

-- Cast phase constants
local CAST_PHASE = {
	IDLE = "idle",
	WINDUP = "windup",
	RECOVERY = "recovery",
}

-- Cast result reasons
local CAST_RESULT = {
	STARTED = "cast_started",
	RESOLVED = "resolved",
	TARGET_LOST = "target_lost",
	TARGET_DEAD = "target_dead",
	INVALID = "invalid",
	CANCELLED = "cancelled",
}

-- Visual ID counter
local visualIdCounter = 0
local function generateVisualId()
	visualIdCounter = visualIdCounter + 1
	return "visual_" .. tostring(visualIdCounter) .. "_" .. tostring(os.clock())
end

-- Helper functions for creature cast state
local function isCasting(creature)
	local cs = creature.castState
	return cs and cs.phase == CAST_PHASE.WINDUP
end

local function isRecovering(creature)
	local cs = creature.castState
	return cs and cs.phase == CAST_PHASE.RECOVERY
end

local function canStartAbility(creature, worldTime)
	if not creature.alive then return false, "dead" end
	if isCasting(creature) then return false, "casting" end
	if isRecovering(creature) then return false, "recovering" end
	if (creature.gcdUntil or 0) > worldTime then return false, "gcd" end
	return true, "ok"
end

local function getCastStateDebug(creature)
	local cs = creature.castState
	if not cs or cs.phase == CAST_PHASE.IDLE then
		return {
			phase = CAST_PHASE.IDLE,
			abilityKey = nil,
			windupRemaining = 0,
			recoveryRemaining = 0,
			gcdRemaining = 0,
			lastCastResult = nil,
		}
	end
	return {
		phase = cs.phase,
		abilityKey = cs.abilityKey,
		windupRemaining = cs.windupRemaining or 0,
		recoveryRemaining = cs.recoveryRemaining or 0,
		gcdRemaining = 0, -- Will be filled in by getCastDebugInfo
		lastCastResult = creature.lastCastResult or nil,
	}
end

-- Initialize cast state on a creature if not present
local function ensureCastState(creature)
	if not creature.castState then
		creature.castState = {
			phase = CAST_PHASE.IDLE,
			abilityKey = nil,
			targetId = nil,
			targetPoint = nil,
			windupRemaining = 0,
			recoveryRemaining = 0,
			targetType = nil, -- Store target type for resolve phase
		}
	end
	return creature.castState
end

-- Clear cast state back to idle
local function clearCastState(creature)
	local cs = creature.castState
	if cs then
		cs.phase = CAST_PHASE.IDLE
		cs.abilityKey = nil
		cs.targetId = nil
		cs.targetPoint = nil
		cs.windupRemaining = 0
		cs.recoveryRemaining = 0
		cs.targetType = nil
	end
end

function CombatService.new(worldService, effectService)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	return setmetatable({
		worldService = worldService,
		effectService = effectService,
		playerDataService = nil,
		morphService = nil,
		remotes = {
			projectileVisual = remotes:WaitForChild("ProjectileVisualEvent"),
			aoeVisual = remotes:WaitForChild("AOEVisualEvent"),
			barrierVisual = remotes:WaitForChild("BarrierVisualEvent"),
			wallBarrierVisual = remotes:WaitForChild("WallBarrierVisualEvent"),
			combatVisualUpdate = remotes:WaitForChild("CombatVisualUpdateEvent"),
		},
	}, CombatService)
end

function CombatService:configureProgression(playerDataService, morphService)
	self.playerDataService = playerDataService
	self.morphService = morphService
end

function CombatService:hasMoveEquipped(creature, abilityKey)
	for _, key in ipairs(creature.moveset or {}) do
		if key == abilityKey then return true end
	end
	return false
end

function CombatService:resolveResistance(map, damageTypes, fallback)
	local keys = (damageTypes and #damageTypes > 0) and damageTypes or { fallback }
	local total = 0
	for _, k in ipairs(keys) do total += (map[k] or 1) end
	return total / math.max(1, #keys)
end

function CombatService:getDamageParts(source, ability)
	return {
		physical = (ability.flatDmg.p or 0) + (ability.dmgScale.p or 0) * source.modifiedStats.pAtk,
		energy = (ability.flatDmg.e or 0) + (ability.dmgScale.e or 0) * source.modifiedStats.eAtk,
	}
end

function CombatService:getFallbacks(parts)
	return {
		physical = parts.physical > 0 and "impact" or "pierce",
		energy = parts.energy > 0 and "electric" or "heat",
	}
end

function CombatService:tryApplyStatuses(source, target, ability)
	if not self.effectService or not ability then return 0, nil end
	self.effectService:applyAbilityStatuses(source, target, ability)
	local bonusDamage, reactionKey = self.effectService:evaluateReactions(source, target, ability)
	return bonusDamage or 0, reactionKey
end

function CombatService:applyDamagePacket(source, target, ability)
	source.lastEngagedAt = self.worldService.time
	target.lastEngagedAt = self.worldService.time
	local parts = self:getDamageParts(source, ability)
	local profile = ability.damageProfile or {}
	local fallback = self:getFallbacks(parts)
	local resistance = target:GetCompositeResistances()
	local physicalTypes = (#(profile.physical or {}) > 0) and profile.physical or { fallback.physical }
	local energyTypes = (#(profile.energy or {}) > 0) and profile.energy or { fallback.energy }
	local physicalMod = self:resolveResistance(resistance.physical or CompositeConfig.defaults.physical, physicalTypes, fallback.physical)
	local energyMod = self:resolveResistance(resistance.energy or CompositeConfig.defaults.energy, energyTypes, fallback.energy)
	local raw = parts.physical * physicalMod + parts.energy * energyMod
	local atkScaled = raw * (source.runtimeAtkMult or 1)
	local reduced = atkScaled * (1 - (target.runtimeDmgReduction or 0))
	local final = math.max(1, reduced)
	target.currentHP = math.max(0, target.currentHP - final)
	self.worldService:pushFloatingText(target.pos, tostring(math.floor(final + 0.5)), "#ffd7d7")
	local bonusDamage, reactionKey = self:tryApplyStatuses(source, target, ability)
	if (bonusDamage or 0) > 0 then
		target.currentHP = math.max(0, target.currentHP - bonusDamage)
		self.worldService:pushFloatingText(target.pos, string.format("+R%d", math.floor(bonusDamage + 0.5)), "#9fe8ff")
	end
	if reactionKey then
		target.lastReactionTriggered = reactionKey
	end
	if target.currentHP <= 0 then
		target.alive = false
		target.lifecycle = "defeated"
		if target.mode == "wild" then
			target.defeatedAt = self.worldService.time
			target.defeatedExpiresAt = self.worldService.time + DEFEATED_WILD_TIMEOUT_SECONDS
			target.defeatedOutcome = nil
			target.defeatedInteractedBy = nil
		end
		if self.playerDataService and source and source.ownerUserId and source.ownedId then
			local player = game:GetService("Players"):GetPlayerByUserId(source.ownerUserId)
			if player then
				local xpGain = math.max(5, math.floor((target.level or 1) * 26))
				local ok, gain = self.playerDataService:addOwnedXP(player, source.ownedId, xpGain)
				if ok and self.morphService then self.morphService:awardPoints(player, source.ownedId, 1) end
				local lvlUp = gain and gain.levelUps or 0
				self.worldService:pushEventLog(player, lvlUp > 0 and string.format("+%d XP  Level up x%d", xpGain, lvlUp) or string.format("+%d XP", xpGain), lvlUp > 0 and "#a8ffd7" or "#d7fcb7")
			end
		end
	end
end

function CombatService:spawnBarrier(source, ability)
	local b = ability.barrier or {}
	local visualColor = getVisualColor(ability)
	local visualId = generateVisualId()

	if b.kind == "wall" then
		table.insert(self.worldService.wallBarriers, {
			id = visualId,
			ownerId = source.id,
			team = source.team,
			pos = source.pos,
			length = b.length or 50,
			thickness = b.thickness or 8,
			timeLeft = b.duration or 4,
			blockMovement = b.blockMovement ~= false,
			damageReduction = b.damageReduction or 0.15,
		})
		-- Send visual event to all players
		self.remotes.wallBarrierVisual:FireAllClients("spawn", {
			id = visualId,
			x = source.pos.X,
			y = source.pos.Y + 10,
			z = source.pos.Z,
			length = b.length or 50,
			thickness = b.thickness or 8,
			height = 20,
			color = visualColor,
			transparency = 0.4,
			duration = b.duration or 4,
		})
	else
		table.insert(self.worldService.barriers, {
			id = visualId,
			ownerId = source.id,
			team = source.team,
			pos = source.pos,
			radius = b.radius or 48,
			timeLeft = b.duration or 4.5,
			slow = b.slow or 0.2,
			damageReduction = b.damageReduction or 0.18,
			blockMovement = b.blockMovement ~= false,
		})
		-- Send visual event to all players
		self.remotes.barrierVisual:FireAllClients("spawn", {
			id = visualId,
			x = source.pos.X,
			y = source.pos.Y + 2,
			z = source.pos.Z,
			radius = b.radius or 48,
			color = visualColor,
			transparency = 0.5,
			pulse = true,
			duration = b.duration or 4.5,
		})
	end
end

function CombatService:spawnProjectile(source, target, ability)
	local dir = (target.pos - source.pos)
	local m = math.max(0.01, dir.Magnitude)
	local visualId = generateVisualId()
	local visualColor = getVisualColor(ability)

	table.insert(self.worldService.projectiles, {
		id = visualId,
		sourceId = source.id,
		team = source.team,
		ability = ability,
		pos = source.pos,
		vel = Vector3.new(dir.X / m, 0, dir.Z / m) * ((ability.projectile and ability.projectile.speed) or 80),
		targetId = (ability.projectile and ability.projectile.homing) and target.id or nil,
		radius = (ability.projectile and ability.projectile.radius) or 4,
		timeLeft = (ability.projectile and ability.projectile.life) or 2,
	})

	-- Send visual event to all players
	self.remotes.projectileVisual:FireAllClients("spawn", {
		id = visualId,
		x = source.pos.X,
		y = source.pos.Y + 2,
		z = source.pos.Z,
		radius = (ability.projectile and ability.projectile.radius) or 4,
		color = visualColor,
		transparency = 0.2,
	})
end

function CombatService:spawnAoe(source, target, ability)
	local area = ability.area or {}
	local visualColor = getVisualColor(ability)
	local visualId = generateVisualId()

	if area.mode == "instant" or not area.mode then
		-- Instant AOE - show expanding sphere briefly
		self.remotes.aoeVisual:FireAllClients("spawn", {
			id = visualId,
			x = target.pos.X,
			y = target.pos.Y + 2,
			z = target.pos.Z,
			radius = area.radius or 24,
			color = visualColor,
			transparency = 0.6,
			expanding = true,
			expandDuration = 0.3,
			duration = 0.5,
		})

		for _, other in ipairs(self.worldService.creatures) do
			if other.alive and other.team ~= source.team then
				local d = (other.pos - target.pos).Magnitude
				if d <= (area.radius or 24) then self:applyDamagePacket(source, other, ability) end
			end
		end
	else
		-- Lingering AOE
		table.insert(self.worldService.areaEffects, {
			id = visualId,
			sourceId = source.id,
			team = source.team,
			ability = ability,
			pos = target.pos,
			radius = area.radius or 24,
			tickEvery = area.tick or 0.5,
			tickTimer = 0,
			timeLeft = area.duration or 1,
			moveDir = area.moveDir,
			speed = area.speed or 0,
		})

		-- Send visual event
		self.remotes.aoeVisual:FireAllClients("spawn", {
			id = visualId,
			x = target.pos.X,
			y = target.pos.Y + 2,
			z = target.pos.Z,
			radius = area.radius or 24,
			color = visualColor,
			transparency = 0.6,
			expanding = true,
			expandDuration = 0.3,
			duration = area.duration or 1,
		})
	end
end


function CombatService:resolveUtilityTarget(source, ability, requestedTarget)
	local mode = ability.targeting or "self"
	if mode == "self" then return source end
	if mode == "ally" then
		if requestedTarget and requestedTarget.alive and requestedTarget.team == source.team then
			return requestedTarget
		end
		local best, bestScore = source, -math.huge
		for _, c in ipairs(self.worldService.creatures) do
			if c.alive and c.team == source.team then
				local d = (c.pos - source.pos).Magnitude
				if d <= (ability.range or 80) then
					local hpRatio = (c.currentHP / math.max(1, c.modifiedStats.maxHP))
					local score = (1 - hpRatio) * 2 - d * 0.01
					if score > bestScore then best, bestScore = c, score end
				end
			end
		end
		return best
	end
	return source
end

function CombatService:applyUtilityAbility(source, target, ability)
	target = target or source
	if ability.heal then
		local raw = (ability.heal.flat or 0) + (ability.heal.scale or 0) * source.modifiedStats.eAtk
		local cap = (ability.heal.maxPercent or 1) * target.modifiedStats.maxHP
		local amount = math.clamp(raw, 0, cap)
		target.currentHP = math.min(target.modifiedStats.maxHP, target.currentHP + amount)
	end
	if ability.restore then
		target.currentEnergy = math.min(target.modifiedStats.energy, target.currentEnergy + (ability.restore.energy or 0))
		target.currentStamina = math.min(target.modifiedStats.stamina, target.currentStamina + (ability.restore.stamina or 0))
	end
	if self.effectService then
		for _, spec in ipairs(ability.statusOnTarget or {}) do
			if self.effectService:rollProc(spec.chance) then
				self.effectService:applyStatus(target, spec.key, source, spec.params)
			end
		end
	end
	self:tryApplyStatuses(source, source, ability)
end

function CombatService:getAbilityTargetType(ability)
	if not ability then return "none" end
	if ability.targetType then return ability.targetType end
	if ability.category == "barrier" then return "none" end
	if ability.category == "utility" or ability.category == "utility_dash" then
		if ability.targeting == "ally" then return "allyTarget" end
		if ability.targeting == "enemy" then return "enemyTarget" end
		if ability.targeting == "ground" then return "groundPoint" end
		return "self"
	end
	if ability.category == "projectile" or ability.category == "aoe" or ability.category == "blink" or ability.category == "dash" or ability.category == "retreat" or ability.category == "melee" or ability.category == "hitscan" then
		return "enemyTarget"
	end
	return "none"
end

function CombatService:validateTargetByType(source, ability, target, targetType)
	if targetType == "self" or targetType == "none" then
		return true, "ok"
	end
	if targetType == "groundPoint" then
		return false, "ground_target_unimplemented"
	end
	if targetType == "enemyTarget" then
		if not target then return false, "no_valid_enemy_target" end
		if (not target.alive) or target.team == source.team then return false, "target_not_enemy" end
		return true, "ok"
	end
	if targetType == "allyTarget" then
		if not target then return false, "no_valid_ally_target" end
		if target.team ~= source.team then return false, "target_not_ally" end
		local allowDefeated = ability.allowDefeatedTarget == true
		if not allowDefeated and not target.alive then
			return false, "target_not_alive"
		end
		return true, "ok"
	end
	return false, "invalid_target_type"
end

function CombatService:evaluateAbility(source, abilityKey, target)
	local ability = AbilityConfig[abilityKey]
	if not ability then return false, "unknown" end
	if not self:hasMoveEquipped(source, abilityKey) then return false, "not_learned" end

	-- Check cast state using new helpers
	local canStart, startReason = canStartAbility(source, self.worldService.time)
	if not canStart then return false, startReason end

	-- Check ability cooldown
	if (source.cooldowns[abilityKey] or 0) > 0 then return false, "cooldown" end

	-- Check resources
	if (ability.resourceUse.stamina or 0) > source.currentStamina then return false, "stamina" end
	if (ability.resourceUse.energy or 0) > source.currentEnergy then return false, "energy" end

	local targetType = self:getAbilityTargetType(ability)
	local validTarget, targetReason = self:validateTargetByType(source, ability, target, targetType)
	if not validTarget then
		return false, targetReason, ability, targetType
	end

	if target and targetType ~= "self" and targetType ~= "none" then
		local d = (Vector3.new(source.pos.X, 0, source.pos.Z) - Vector3.new(target.pos.X, 0, target.pos.Z)).Magnitude
		if d > (ability.range or 20) then return false, "range", ability, targetType end
	end
	return true, ability, targetType
end

function CombatService:validateManualCast(source, abilityKey, target)
	local ok, abilityOrReason, targetType = self:evaluateAbility(source, abilityKey, target)
	if not ok then
		local abilityDef = AbilityConfig[abilityKey]
		local expectedTargetType = targetType or self:getAbilityTargetType(abilityDef)
		return {
			ok = false,
			code = tostring(abilityOrReason or "invalid"),
			abilityKey = abilityKey,
			targetId = target and target.id or nil,
			targetType = expectedTargetType,
			targetResolution = target and "runtime_target" or "no_runtime_target",
		}
	end
	return {
		ok = true,
		code = "accepted",
		abilityKey = abilityKey,
		targetId = target and target.id or nil,
		targetType = targetType,
		targetResolution = target and "runtime_target" or "self_or_none",
		ability = abilityOrReason,
	}
end

function CombatService:performMobility(source, target, ability)
	local dash = ability.dash
	if not dash then return end
	local dir = (target.pos - source.pos)
	local mag = math.max(0.01, dir.Magnitude)
	local norm = Vector3.new(dir.X / mag, 0, dir.Z / mag)
	local distance = dash.distance or 60
	if ability.category == "retreat" then norm = norm * -1 end
	source.pos += norm * distance
end

-- Begin the cast of an ability (starts windup phase)
-- Returns true if cast started, false otherwise
-- All casts go through WINDUP -> RESOLVE -> RECOVERY pipeline
-- Instant casts have windupRemaining = 0 and resolve on next update
function CombatService:beginAbilityCast(source, abilityKey, target)
	local ok, abilityOrReason, targetType = self:evaluateAbility(source, abilityKey, target)
	if not ok then
		-- Store failure in lastCastResult for debug visibility
		source.lastCastResult = {
			success = false,
			reason = tostring(abilityOrReason),
			abilityKey = abilityKey,
			phase = "evaluate",
		}
		return false, tostring(abilityOrReason)
	end

	local ability = abilityOrReason

	-- Spend resources upfront
	source.currentStamina -= (ability.resourceUse.stamina or 0)
	source.currentEnergy -= (ability.resourceUse.energy or 0)

	-- Start ability cooldown
	source.cooldowns[abilityKey] = ability.cooldown or 1

	-- Start GCD
	local gcdTime = ability.gcd or 0.45
	source.gcdUntil = self.worldService.time + gcdTime

	-- Initialize cast state
	ensureCastState(source)
	local cs = source.castState
	cs.abilityKey = abilityKey
	cs.targetId = target and target.id or nil
	cs.targetPoint = nil -- For future ground targeting
	cs.targetType = targetType -- Store for resolve phase

	-- Get timing values
	local castTime = ability.castTime or 0
	local recoveryTime = ability.recovery or 0

	-- All casts start in WINDUP phase for consistency
	-- Instant casts have windupRemaining = 0 and will resolve on next updateCasts
	cs.phase = CAST_PHASE.WINDUP
	cs.windupRemaining = castTime
	cs.recoveryRemaining = recoveryTime

	-- Store initial cast result (will be updated on resolve/fizzle)
	source.lastCastResult = {
		success = true,
		reason = CAST_RESULT.STARTED,
		abilityKey = abilityKey,
		phase = CAST_PHASE.WINDUP,
		windupRemaining = castTime,
		recoveryRemaining = recoveryTime,
	}

	return true, CAST_RESULT.STARTED
end

-- Resolve the actual ability effects (called when windup completes)
function CombatService:resolveAbilityCast(source, ability, target, targetType)
	-- Validate target still exists if needed
	local needsTarget = ability.category == "projectile" or ability.category == "aoe" or
		ability.category == "blink" or ability.category == "dash" or ability.category == "retreat"

	if needsTarget and not target then
		-- Fizzle - target lost during windup
		return false, "target_lost"
	end

	if needsTarget and not target.alive then
		-- Fizzle - target died during windup
		return false, "target_dead"
	end

	-- Execute ability based on category
	if ability.category == "utility" then
		local utilTarget = (targetType == "self" or targetType == "none") and source or self:resolveUtilityTarget(source, ability, target)
		self:applyUtilityAbility(source, utilTarget, ability)
	elseif ability.category == "utility_dash" then
		local utilTarget = (targetType == "self" or targetType == "none") and source or self:resolveUtilityTarget(source, ability, target)
		if utilTarget then
			local dir = (utilTarget.pos - source.pos)
			local mag = math.max(0.01, dir.Magnitude)
			local dashDist = math.min((ability.dash and ability.dash.distance) or 60, math.max(0, mag - ((ability.dash and ability.dash.stopShort) or 6)))
			source.pos += Vector3.new(dir.X / mag, 0, dir.Z / mag) * dashDist
			self:applyUtilityAbility(source, utilTarget, ability)
		end
	elseif ability.category == "barrier" then
		self:spawnBarrier(source, ability)
	elseif ability.category == "projectile" and target then
		self:spawnProjectile(source, target, ability)
	elseif ability.category == "aoe" and target then
		self:spawnAoe(source, target, ability)
	elseif ability.category == "blink" and target then
		local dir = (target.pos - source.pos)
		local mag = math.max(0.01, dir.Magnitude)
		local behind = (ability.blink and ability.blink.behind) or 8
		source.pos = target.pos - Vector3.new(dir.X / mag, 0, dir.Z / mag) * behind
		if target then self:applyDamagePacket(source, target, ability) end
	elseif (ability.category == "dash" or ability.category == "retreat") and target then
		-- Movement is now handled during windup phase in updateCasts
		-- Just apply damage at resolve
		if target then self:applyDamagePacket(source, target, ability) end
	elseif ability.category == "melee" or ability.category == "hitscan" then
		if target then self:applyDamagePacket(source, target, ability) end
	end

	return true, "resolved"
end

-- Try to use ability from creature intent (AI or manual command)
function CombatService:tryUseAbility(source)
	local key = source.intent.abilityKey
	if not key then return end

	local target = self.worldService:getCreatureById(source.intent.targetId)

	-- Clear intent regardless of outcome
	source.intent.abilityKey = nil
	source.intent.targetId = nil

	-- Attempt to begin cast
	local started, reason = self:beginAbilityCast(source, key, target)
	if not started then
		-- Could log the failure reason if needed
		return false, reason
	end

	return true, reason
end

-- Update active casts for all creatures
function CombatService:updateCasts(dt)
	for _, creature in ipairs(self.worldService.creatures) do
		if creature.alive and creature.castState then
			local cs = creature.castState

			if cs.phase == CAST_PHASE.WINDUP then
				cs.windupRemaining = cs.windupRemaining - dt

				-- Handle movement during windup for dash abilities
				local ability = AbilityConfig[cs.abilityKey]
				if ability and (ability.category == "dash" or ability.category == "retreat") then
					local target = self.worldService:getCreatureById(cs.targetId)
					if target and target.alive then
						-- Calculate movement during windup
						local dash = ability.dash or {}
						local totalDistance = dash.distance or 60
						local castTime = ability.castTime or 0
						local totalWindup = castTime > 0 and castTime or 0.1 -- Minimum windup for movement
						local movementProgress = dt / totalWindup

						-- Direction toward target (or away for retreat)
						local dir = (target.pos - creature.pos)
						local mag = math.max(0.01, dir.Magnitude)
						local norm = Vector3.new(dir.X / mag, 0, dir.Z / mag)
						if ability.category == "retreat" then norm = norm * -1 end

						-- Move creature during windup
						local moveDistance = totalDistance * movementProgress
						creature.pos = creature.pos + norm * moveDistance
					end
				end

				if cs.windupRemaining <= 0 then
					-- Windup complete, resolve ability
					if ability then
						local target = self.worldService:getCreatureById(cs.targetId)
						-- Use stored targetType instead of recomputing
						local success, reason = self:resolveAbilityCast(creature, ability, target, cs.targetType)

						-- Update lastCastResult with resolve outcome
						creature.lastCastResult = {
							success = success,
							reason = reason,
							abilityKey = cs.abilityKey,
							phase = "resolve",
						}
					end

					-- Transition to recovery (even if resolve failed)
					cs.phase = CAST_PHASE.RECOVERY
					cs.windupRemaining = 0
				end

			elseif cs.phase == CAST_PHASE.RECOVERY then
				cs.recoveryRemaining = cs.recoveryRemaining - dt

				if cs.recoveryRemaining <= 0 then
					-- Recovery complete, back to idle
					clearCastState(creature)
				end
			end
		end
	end
end

-- Get debug info for a creature's cast state
function CombatService:getCastDebugInfo(creature)
	local info = getCastStateDebug(creature)
	info.gcdRemaining = math.max(0, (creature.gcdUntil or 0) - self.worldService.time)
	info.lastCastResult = creature.lastCastResult or nil
	return info
end

function CombatService:update(dt)
	-- Update active casts first
	self:updateCasts(dt)

	local projectileUpdates = {}
	local aoeUpdates = {}
	local destroyProjectiles = {}
	local destroyAOEs = {}
	local destroyBarriers = {}
	local destroyWallBarriers = {}

	-- Update projectiles
	for i = #self.worldService.projectiles, 1, -1 do
		local p = self.worldService.projectiles[i]
		p.timeLeft -= dt
		if p.targetId then
			local t = self.worldService:getCreatureById(p.targetId)
			if t and t.alive then
				local dir = (t.pos - p.pos)
				local m = math.max(0.01, dir.Magnitude)
				local speed = p.vel.Magnitude
				p.vel = Vector3.new(dir.X / m, 0, dir.Z / m) * speed
			end
		end
		p.pos += p.vel * dt

		-- Track position update for visuals
		if p.id then
			table.insert(projectileUpdates, {
				id = p.id,
				x = p.pos.X,
				y = p.pos.Y + 2,
				z = p.pos.Z,
			})
		end

		-- Check collision
		for _, c in ipairs(self.worldService.creatures) do
			if c.alive and c.team ~= p.team and (c.pos - p.pos).Magnitude <= (p.radius or 4) then
				local s = self.worldService:getCreatureById(p.sourceId)
				if s then self:applyDamagePacket(s, c, p.ability) end
				p.timeLeft = 0
				break
			end
		end

		-- Remove expired projectiles
		if p.timeLeft <= 0 then
			if p.id then
				table.insert(destroyProjectiles, p.id)
			end
			table.remove(self.worldService.projectiles, i)
		end
	end

	-- Update area effects
	for i = #self.worldService.areaEffects, 1, -1 do
		local a = self.worldService.areaEffects[i]
		a.timeLeft -= dt
		a.tickTimer -= dt
		if a.moveDir then a.pos += a.moveDir * (a.speed or 0) * dt end

		-- Track position update for visuals
		if a.id then
			table.insert(aoeUpdates, {
				id = a.id,
				x = a.pos.X,
				y = a.pos.Y + 2,
				z = a.pos.Z,
			})
		end

		if a.tickTimer <= 0 then
			a.tickTimer = a.tickEvery or 0.5
			for _, c in ipairs(self.worldService.creatures) do
				if c.alive and c.team ~= a.team and (c.pos - a.pos).Magnitude <= a.radius then
					local s = self.worldService:getCreatureById(a.sourceId)
					if s then self:applyDamagePacket(s, c, a.ability) end
				end
			end
		end

		-- Remove expired AOEs
		if a.timeLeft <= 0 then
			if a.id then
				table.insert(destroyAOEs, a.id)
			end
			table.remove(self.worldService.areaEffects, i)
		end
	end

	-- Update barriers
	for i = #self.worldService.barriers, 1, -1 do
		local b = self.worldService.barriers[i]
		b.timeLeft -= dt
		for _, c in ipairs(self.worldService.creatures) do
			if c.alive then
				local d = (c.pos - b.pos).Magnitude
				if d <= b.radius then
					if c.team == b.team then
						if self.effectService then self.effectService:applyStatus(c, "guard", nil, { duration = 0.4, reduction = b.damageReduction }) end
					else
						if self.effectService then self.effectService:applyStatus(c, "slow", nil, { duration = 0.4, mult = 1 - (b.slow or 0.2) }) end
						if b.blockMovement then
							local n = (c.pos - b.pos)
							local m = math.max(0.01, n.Magnitude)
							c.pos = b.pos + Vector3.new(n.X / m, 0, n.Z / m) * (b.radius + 2)
						end
					end
				end
			end
		end

		-- Remove expired barriers
		if b.timeLeft <= 0 then
			if b.id then
				table.insert(destroyBarriers, b.id)
			end
			table.remove(self.worldService.barriers, i)
		end
	end

	-- Update wall barriers
	for i = #self.worldService.wallBarriers, 1, -1 do
		local w = self.worldService.wallBarriers[i]
		w.timeLeft -= dt
		for _, c in ipairs(self.worldService.creatures) do
			if c.alive and c.team ~= w.team and w.blockMovement then
				local dx = c.pos.X - w.pos.X
				local dz = c.pos.Z - w.pos.Z
				if math.abs(dx) <= (w.length * 0.5) and math.abs(dz) <= (w.thickness * 0.5) then
					c.pos = Vector3.new(c.pos.X, c.pos.Y, w.pos.Z + (dz >= 0 and 1 or -1) * (w.thickness * 0.5 + 2))
				end
			end
		end

		-- Remove expired wall barriers
		if w.timeLeft <= 0 then
			if w.id then
				table.insert(destroyWallBarriers, w.id)
			end
			table.remove(self.worldService.wallBarriers, i)
		end
	end

	-- Send batch visual updates to all players
	if #projectileUpdates > 0 or #aoeUpdates > 0 or #destroyProjectiles > 0 or #destroyAOEs > 0 or #destroyBarriers > 0 or #destroyWallBarriers > 0 then
		self.remotes.combatVisualUpdate:FireAllClients({
			projectiles = projectileUpdates,
			aoes = aoeUpdates,
			destroyProjectiles = destroyProjectiles,
			destroyAOEs = destroyAOEs,
			destroyBarriers = destroyBarriers,
			destroyWallBarriers = destroyWallBarriers,
		})
	end
end

return CombatService
