local EffectService = {}
EffectService.__index = EffectService

function EffectService.new()
	return setmetatable({}, EffectService)
end

function EffectService:tickCreature(creature, dt)
	-- TODO: Port soak/status/buff stacks from JS prototype.
	creature.runtimeAtkMult = 1
	creature.runtimeDmgReduction = 0
end

return EffectService
