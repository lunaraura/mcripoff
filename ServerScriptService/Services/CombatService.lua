local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))
local CompositeConfig = require(Config:WaitForChild("CompositeConfig"))

local CombatService = {}
CombatService.__index = CombatService

function CombatService.new(worldService, effectService)
	return setmetatable({ worldService = worldService, effectService = effectService, playerDataService = nil, morphService = nil }, CombatService)
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
	if not self.effectService or not ability then return end
	for _, spec in ipairs(ability.statusOnHit or {}) do
		if self.effectService:rollProc(spec.chance) then
			self.effectService:applyStatus(target, spec.key, source, spec.params)
		end
	end
	for _, spec in ipairs(ability.statusSelf or {}) do
		if self.effectService:rollProc(spec.chance) then
			self.effectService:applyStatus(source, spec.key, source, spec.params)
		end
	end
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
	self:tryApplyStatuses(source, target, ability)
	if target.currentHP <= 0 then
		target.alive = false
		target.lifecycle = "defeated"
		if self.playerDataService and source and source.ownerUserId and source.ownedId then
			local player = game:GetService("Players"):GetPlayerByUserId(source.ownerUserId)
			if player then
				local xpGain = math.max(5, math.floor((target.level or 1) * 6))
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
	if b.kind == "wall" then
		table.insert(self.worldService.wallBarriers, {
			ownerId = source.id,
			team = source.team,
			pos = source.pos,
			length = b.length or 50,
			thickness = b.thickness or 8,
			timeLeft = b.duration or 4,
			blockMovement = b.blockMovement ~= false,
			damageReduction = b.damageReduction or 0.15,
		})
	else
		table.insert(self.worldService.barriers, {
			ownerId = source.id,
			team = source.team,
			pos = source.pos,
			radius = b.radius or 48,
			timeLeft = b.duration or 4.5,
			slow = b.slow or 0.2,
			damageReduction = b.damageReduction or 0.18,
			blockMovement = b.blockMovement ~= false,
		})
	end
end

function CombatService:spawnProjectile(source, target, ability)
	local dir = (target.pos - source.pos)
	local m = math.max(0.01, dir.Magnitude)
	table.insert(self.worldService.projectiles, {
		sourceId = source.id,
		team = source.team,
		ability = ability,
		pos = source.pos,
		vel = Vector3.new(dir.X / m, 0, dir.Z / m) * ((ability.projectile and ability.projectile.speed) or 80),
		targetId = (ability.projectile and ability.projectile.homing) and target.id or nil,
		radius = (ability.projectile and ability.projectile.radius) or 4,
		timeLeft = (ability.projectile and ability.projectile.life) or 2,
	})
end

function CombatService:spawnAoe(source, target, ability)
	local area = ability.area or {}
	if area.mode == "instant" or not area.mode then
		for _, other in ipairs(self.worldService.creatures) do
			if other.alive and other.team ~= source.team then
				local d = (other.pos - target.pos).Magnitude
				if d <= (area.radius or 24) then self:applyDamagePacket(source, other, ability) end
			end
		end
	else
		table.insert(self.worldService.areaEffects, {
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

function CombatService:evaluateAbility(source, abilityKey, target)
	local ability = AbilityConfig[abilityKey]
	if not ability then return false, "unknown" end
	if not self:hasMoveEquipped(source, abilityKey) then return false, "not_learned" end
	if (source.cooldowns[abilityKey] or 0) > 0 then return false, "cooldown" end
	if (ability.resourceUse.stamina or 0) > source.currentStamina then return false, "stamina" end
	if (ability.resourceUse.energy or 0) > source.currentEnergy then return false, "energy" end
	if ability.category == "utility" or ability.category == "utility_dash" or ability.category == "barrier" then return true, ability end
	if not target or not target.alive or target.team == source.team then return false, "target" end
	local d = (Vector3.new(source.pos.X, 0, source.pos.Z) - Vector3.new(target.pos.X, 0, target.pos.Z)).Magnitude
	if d > (ability.range or 20) then return false, "range" end
	return true, ability
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

function CombatService:tryUseAbility(source)
	local key = source.intent.abilityKey
	if not key then return end
	local target = self.worldService:getCreatureById(source.intent.targetId)
	local ok, abilityOrReason = self:evaluateAbility(source, key, target)
	source.intent.abilityKey = nil
	source.intent.targetId = nil
	if not ok then return end
	local ability = abilityOrReason
	source.currentStamina -= (ability.resourceUse.stamina or 0)
	source.currentEnergy -= (ability.resourceUse.energy or 0)
	source.cooldowns[key] = ability.cooldown or 1
	if ability.category == "utility" then
		local utilTarget = self:resolveUtilityTarget(source, ability, target)
		self:applyUtilityAbility(source, utilTarget, ability)
		return
	elseif ability.category == "utility_dash" then
		local utilTarget = self:resolveUtilityTarget(source, ability, target)
		if utilTarget then
			local dir = (utilTarget.pos - source.pos)
			local mag = math.max(0.01, dir.Magnitude)
			local dashDist = math.min((ability.dash and ability.dash.distance) or 60, math.max(0, mag - ((ability.dash and ability.dash.stopShort) or 6)))
			source.pos += Vector3.new(dir.X / mag, 0, dir.Z / mag) * dashDist
			self:applyUtilityAbility(source, utilTarget, ability)
		end
		return
	elseif ability.category == "barrier" then
		self:spawnBarrier(source, ability)
		return
	elseif ability.category == "projectile" and target then
		self:spawnProjectile(source, target, ability)
		return
	elseif ability.category == "aoe" and target then
		self:spawnAoe(source, target, ability)
		return
	elseif ability.category == "blink" and target then
		local dir = (target.pos - source.pos)
		local mag = math.max(0.01, dir.Magnitude)
		local behind = (ability.blink and ability.blink.behind) or 8
		source.pos = target.pos - Vector3.new(dir.X / mag, 0, dir.Z / mag) * behind
	elseif (ability.category == "dash" or ability.category == "retreat") and target then
		self:performMobility(source, target, ability)
	end
	if target then self:applyDamagePacket(source, target, ability) end
end

function CombatService:update(dt)
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
		for _, c in ipairs(self.worldService.creatures) do
			if c.alive and c.team ~= p.team and (c.pos - p.pos).Magnitude <= (p.radius or 4) then
				local s = self.worldService:getCreatureById(p.sourceId)
				if s then self:applyDamagePacket(s, c, p.ability) end
				p.timeLeft = 0
				break
			end
		end
		if p.timeLeft <= 0 then table.remove(self.worldService.projectiles, i) end
	end

	for i = #self.worldService.areaEffects, 1, -1 do
		local a = self.worldService.areaEffects[i]
		a.timeLeft -= dt
		a.tickTimer -= dt
		if a.moveDir then a.pos += a.moveDir * (a.speed or 0) * dt end
		if a.tickTimer <= 0 then
			a.tickTimer = a.tickEvery or 0.5
			for _, c in ipairs(self.worldService.creatures) do
				if c.alive and c.team ~= a.team and (c.pos - a.pos).Magnitude <= a.radius then
					local s = self.worldService:getCreatureById(a.sourceId)
					if s then self:applyDamagePacket(s, c, a.ability) end
				end
			end
		end
		if a.timeLeft <= 0 then table.remove(self.worldService.areaEffects, i) end
	end

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
		if b.timeLeft <= 0 then table.remove(self.worldService.barriers, i) end
	end

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
		if w.timeLeft <= 0 then table.remove(self.worldService.wallBarriers, i) end
	end
end

return CombatService
