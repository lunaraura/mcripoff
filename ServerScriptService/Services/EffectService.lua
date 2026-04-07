local EffectService = {}
EffectService.__index = EffectService

local STATUS_DEFS = {
	burn = {
		defaultDuration = 5,
		maxStacks = 3,
		tickInterval = 1,
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
		defaultDuration = 6,
		maxStacks = 4,
		tickInterval = 1,
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
		defaultDuration = 4,
		maxStacks = 1,
		onApply = function(self, creature, inst)
			inst._slowMult = (inst.params and inst.params.mult) or 0.7
		end,
		onStatPass = function(self, creature, inst, runtime)
			runtime.moveMult *= inst._slowMult or 0.7
		end,
	},
	haste = {
		defaultDuration = 4,
		maxStacks = 1,
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
		defaultDuration = 3,
		maxStacks = 1,
		onApply = function(self, creature, inst)
			inst._reduction = math.clamp((inst.params and inst.params.reduction) or 0.25, 0, 0.75)
		end,
		onStatPass = function(self, creature, inst, runtime)
			runtime.dmgReduction = math.max(runtime.dmgReduction, inst._reduction or 0.25)
		end,
	},
}

function EffectService.new(worldService)
	return setmetatable({ worldService = worldService }, EffectService)
end

function EffectService:getContainer(creature)
	creature.statuses = creature.statuses or {}
	return creature.statuses
end

function EffectService:applyStatus(creature, statusKey, source, params)
	if not creature or not creature.alive then return false end
	local def = STATUS_DEFS[statusKey]
	if not def then return false end
	local now = self.worldService and self.worldService.time or os.clock()
	local container = self:getContainer(creature)
	local inst = container[statusKey]
	local duration = (params and params.duration) or def.defaultDuration or 3
	if inst then
		inst.expiresAt = math.max(inst.expiresAt, now + duration)
		inst.stacks = math.min(def.maxStacks or 1, (inst.stacks or 1) + ((params and params.addStacks) or 1))
		inst.params = params or inst.params
		if def.onRefresh then
			def.onRefresh(self, creature, inst, source)
		end
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
		if def.onApply then
			def.onApply(self, creature, inst, source)
		end
	end
	return true
end

function EffectService:expireStatus(creature, statusKey)
	local container = self:getContainer(creature)
	local inst = container[statusKey]
	if not inst then return end
	local def = STATUS_DEFS[statusKey]
	if def and def.onExpire then
		def.onExpire(self, creature, inst)
	end
	container[statusKey] = nil
end

function EffectService:rollProc(chance)
	if chance == nil then return true end
	return math.random() <= chance
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
		if (not def) or now >= (inst.expiresAt or 0) then
			self:expireStatus(creature, statusKey)
		else
			if def.tickInterval and def.onTick and now >= (inst.nextTickAt or 0) then
				def.onTick(self, creature, inst, dt)
				inst.nextTickAt = now + def.tickInterval
			end
			if def.onStatPass then
				def.onStatPass(self, creature, inst, runtime, dt)
			end
		end
	end

	creature.runtimeAtkMult = runtime.atkMult
	creature.runtimeDmgReduction = runtime.dmgReduction
	creature.runtimeMoveMult = runtime.moveMult
end

return EffectService
