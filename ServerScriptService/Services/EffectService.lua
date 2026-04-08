local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local EffectConfig = require(Config:WaitForChild("EffectConfig"))
local CompositeConfig = require(Config:WaitForChild("CompositeConfig"))

local EffectService = {}
EffectService.__index = EffectService

local STATUS_DEFS = EffectConfig.statuses
local REACTIONS = EffectConfig.reactions

local STATUS_RUNTIME = {
	burn = {
		onTick = function(self, creature, inst)
			local dps = (inst.params and inst.params.dps) or 2.5
			local dmg = dps * math.max(1, inst.stacks or 1)
			creature.currentHP = math.max(0, creature.currentHP - dmg)
			if creature.currentHP <= 0 then
				creature.alive = false
				creature.lifecycle = "defeated"
			end
		end,
	},
	bleed = {
		onTick = function(self, creature, inst)
			local dps = (inst.params and inst.params.dps) or 1.8
			local dmg = dps * math.max(1, inst.stacks or 1)
			creature.currentHP = math.max(0, creature.currentHP - dmg)
			if creature.currentHP <= 0 then
				creature.alive = false
				creature.lifecycle = "defeated"
			end
		end,
	},
	slow = {
		onApply = function(self, creature, inst)
			inst._slowMult = (inst.params and inst.params.mult) or 0.7
		end,
		onStatPass = function(self, creature, inst, runtime)
			runtime.moveMult *= inst._slowMult or 0.7
		end,
	},
	shock = {
		onApply = function(self, creature, inst)
			inst._shockMult = (inst.params and inst.params.magnitude) or 0.2
		end,
		onStatPass = function(self, creature, inst, runtime)
			runtime.moveMult *= (1 - (inst._shockMult or 0.2))
			runtime.atkMult *= (1 - math.min(0.25, (inst._shockMult or 0.2) * 0.65))
		end,
	},
	haste = {
		onApply = function(self, creature, inst)
			inst._hasteMult = (inst.params and inst.params.mult) or 1.2
		end,
		onStatPass = function(self, creature, inst, runtime)
			local mult = inst._hasteMult or 1.2
			runtime.moveMult *= mult
			runtime.atkMult *= (1 + (mult - 1) * 0.35)
		end,
	},
	guard = {
		onApply = function(self, creature, inst)
			inst._reduction = math.clamp((inst.params and inst.params.reduction) or 0.25, 0, 0.75)
		end,
		onStatPass = function(self, creature, inst, runtime)
			runtime.dmgReduction = math.max(runtime.dmgReduction, inst._reduction or 0.25)
		end,
	},
}

local function toSet(tags)
	local out = {}
	for _, t in ipairs(tags or {}) do out[t] = true end
	return out
end

function EffectService.new(worldService)
	return setmetatable({ worldService = worldService }, EffectService)
end

function EffectService:getContainer(creature)
	creature.statuses = creature.statuses or {}
	return creature.statuses
end

function EffectService:getCompositeStatusHooks(creature)
	local function readHooks(compositeKey)
		local c = CompositeConfig[compositeKey]
		return c and c.statusHooks or { tagScale = {}, immunities = {} }
	end
	local outer = readHooks(creature.outerCompositeKey or creature.compositeKey or "animal")
	local inner = readHooks(creature.innerCompositeKey or creature.compositeKey or "animal")
	return outer, inner
end

function EffectService:hasStatusImmunity(creature, statusKey)
	local outer, inner = self:getCompositeStatusHooks(creature)
	return (outer.immunities and outer.immunities[statusKey]) or (inner.immunities and inner.immunities[statusKey]) or false
end

function EffectService:getStatusDurationScalar(creature, statusKey)
	local def = STATUS_DEFS[statusKey]
	if not def then return 1 end
	local outer, inner = self:getCompositeStatusHooks(creature)
	local scalar = 1
	for _, tag in ipairs(def.tags or {}) do
		local o = outer.tagScale and outer.tagScale[tag]
		local i = inner.tagScale and inner.tagScale[tag]
		if o then scalar *= o end
		if i then scalar *= i end
	end
	return math.clamp(scalar, 0.35, 2.4)
end

function EffectService:statusHasTag(statusKey, tag)
	local def = STATUS_DEFS[statusKey]
	if not def then return false end
	return toSet(def.tags)[tag] == true
end

function EffectService:abilityHasTag(ability, tag)
	if not ability then return false end
	for _, t in ipairs(ability.effectTags or {}) do
		if t == tag then return true end
	end
	local profile = ability.damageProfile or {}
	for _, t in ipairs(profile.energy or {}) do
		if t == "electric" and tag == "electric" then return true end
		if t == "heat" and tag == "fire" then return true end
		if t == "water" and tag == "water" then return true end
	end
	for _, t in ipairs(profile.physical or {}) do
		if t == "impact" and tag == "impact" then return true end
	end
	return false
end

function EffectService:clearStatusesByTag(creature, tag)
	local container = self:getContainer(creature)
	for key, _ in pairs(container) do
		if self:statusHasTag(key, tag) then
			self:expireStatus(creature, key)
		end
	end
end

function EffectService:applyStatus(creature, statusKey, source, params)
	if not creature or not creature.alive then return false end
	local def = STATUS_DEFS[statusKey]
	if not def then return false end
	if self:hasStatusImmunity(creature, statusKey) then
		return false
	end
	local runtime = STATUS_RUNTIME[statusKey] or {}
	local now = self.worldService and self.worldService.time or os.clock()
	local container = self:getContainer(creature)
	local inst = container[statusKey]
	local baseDuration = (params and params.duration) or def.defaultDuration or 3
	local duration = baseDuration * self:getStatusDurationScalar(creature, statusKey)
	local mode = def.stackMode or "refresh"

	if def.cleansesTags then
		for _, tag in ipairs(def.cleansesTags) do
			self:clearStatusesByTag(creature, tag)
		end
	end
	for _, old in ipairs(def.overwrites or {}) do
		self:expireStatus(creature, old)
	end
	for _, requiredMissingTag in ipairs(def.blockedByTags or {}) do
		for activeKey, _ in pairs(container) do
			if self:statusHasTag(activeKey, requiredMissingTag) then
				return false
			end
		end
	end

	if inst then
		if mode == "refresh" or mode == "stack" then
			inst.expiresAt = math.max(inst.expiresAt, now + duration)
		elseif mode == "replace" then
			inst.expiresAt = now + duration
		end
		if mode == "stack" then
			inst.stacks = math.min(def.maxStacks or 1, (inst.stacks or 1) + ((params and params.addStacks) or 1))
		elseif mode == "replace" then
			inst.stacks = (params and params.stacks) or 1
		else
			inst.stacks = math.max(inst.stacks or 1, (params and params.stacks) or 1)
		end
		inst.params = params or inst.params
		if runtime.onRefresh then runtime.onRefresh(self, creature, inst, source) end
	else
		inst = {
			key = statusKey,
			sourceId = source and source.id or nil,
			appliedAt = now,
			expiresAt = now + duration,
			stacks = math.min(def.maxStacks or 1, (params and params.stacks) or 1),
			params = params or {},
			nextTickAt = now + (def.tickInterval or 1),
		}
		container[statusKey] = inst
		if runtime.onApply then runtime.onApply(self, creature, inst, source) end
	end
	return true
end

function EffectService:expireStatus(creature, statusKey)
	local container = self:getContainer(creature)
	local inst = container[statusKey]
	if not inst then return end
	local runtime = STATUS_RUNTIME[statusKey] or {}
	if runtime.onExpire then runtime.onExpire(self, creature, inst) end
	container[statusKey] = nil
end

function EffectService:rollProc(chance)
	if chance == nil then return true end
	return math.random() <= chance
end

function EffectService:buildStatusSummary(creature)
	local container = self:getContainer(creature)
	local tokens = {}
	for key, inst in pairs(container) do
		table.insert(tokens, string.format("%s(%d)", key, inst.stacks or 1))
	end
	table.sort(tokens)
	return table.concat(tokens, ",")
end

function EffectService:applyAbilityStatuses(source, target, ability)
	if not ability then return end
	local guardPressure = false
	if target.statuses and target.statuses.guard and self:abilityHasTag(ability, "impact") then
		guardPressure = true
	end
	for _, spec in ipairs(ability.statusOnHit or {}) do
		local chance = spec.chance
		if guardPressure then chance = (chance or 1) * 0.6 end
		if self:rollProc(chance) then
			self:applyStatus(target, spec.key, source, spec.params)
		end
	end
	for _, spec in ipairs(ability.statusSelf or {}) do
		if self:rollProc(spec.chance) then
			self:applyStatus(source, spec.key, source, spec.params)
		end
	end
end

function EffectService:evaluateReactions(source, target, ability)
	local bonusDamage = 0
	local triggered = nil
	local container = self:getContainer(target)
	if container.wet and self:abilityHasTag(ability, "electric") then
		local wetStacks = container.wet.stacks or 1
		local traits = CompositeConfig[target.outerCompositeKey or target.compositeKey or "animal"] and CompositeConfig[target.outerCompositeKey or target.compositeKey or "animal"].traits or {}
		local conductivity = traits and traits.conductivity or 0.25
		local scalar = math.clamp(1 + conductivity, REACTIONS.wet_electric.compositeScalarMin or 0.7, REACTIONS.wet_electric.compositeScalarMax or 1.7)
		bonusDamage += (REACTIONS.wet_electric.bonusDamage or 0) * wetStacks * scalar
		self:applyStatus(target, "shock", source, REACTIONS.wet_electric.applyStatus.params)
		container.wet.stacks = math.max(0, wetStacks - (REACTIONS.wet_electric.consumeStatusStacks or 1))
		if container.wet.stacks <= 0 then self:expireStatus(target, "wet") end
		triggered = "wet_electric"
	end
	if container.burn and self:abilityHasTag(ability, "water") then
		local reduced = REACTIONS.wet_cools_burn.reduceStacks or 1
		container.burn.stacks = math.max(0, (container.burn.stacks or 1) - reduced)
		if (container.burn.stacks or 0) <= 0 or REACTIONS.wet_cools_burn.expireIfNoStacks then
			self:expireStatus(target, "burn")
		end
		triggered = triggered and (triggered .. "+wet_cools_burn") or "wet_cools_burn"
	end
	if container.guard and self:abilityHasTag(ability, "impact") then
		container.guard.expiresAt = math.max(self.worldService.time, container.guard.expiresAt - (REACTIONS.guard_impact.reduceDuration or 0.35))
		triggered = triggered and (triggered .. "+guard_impact") or "guard_impact"
	end
	if triggered then
		target.lastReactionTriggered = triggered
	end
	return bonusDamage, triggered
end

function EffectService:tickCreature(creature, dt)
	creature.runtimeAtkMult = 1
	creature.runtimeDmgReduction = 0
	creature.runtimeMoveMult = 1
	if not creature.alive then return end

	local now = self.worldService and self.worldService.time or os.clock()
	local runtime = { atkMult = 1, dmgReduction = 0, moveMult = 1 }
	local container = self:getContainer(creature)
	for statusKey, inst in pairs(container) do
		local def = STATUS_DEFS[statusKey]
		local hooks = STATUS_RUNTIME[statusKey] or {}
		if (not def) or now >= (inst.expiresAt or 0) then
			self:expireStatus(creature, statusKey)
		else
			if def.tickInterval and hooks.onTick and now >= (inst.nextTickAt or 0) then
				hooks.onTick(self, creature, inst, dt)
				inst.nextTickAt = now + def.tickInterval
			end
			if hooks.onStatPass then
				hooks.onStatPass(self, creature, inst, runtime, dt)
			end
		end
	end

	creature.runtimeAtkMult = runtime.atkMult
	creature.runtimeDmgReduction = runtime.dmgReduction
	creature.runtimeMoveMult = runtime.moveMult
	creature.effectFlags = {
		burning = container.burn ~= nil,
		bleeding = container.bleed ~= nil,
		slowed = container.slow ~= nil,
		shocked = container.shock ~= nil,
		guarded = container.guard ~= nil,
		hasted = container.haste ~= nil,
		wet = container.wet ~= nil,
	}
	creature.effectSummary = self:buildStatusSummary(creature)
end

return EffectService
