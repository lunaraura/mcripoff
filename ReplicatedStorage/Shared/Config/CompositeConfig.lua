local defaults = {
	physical = { pierce = 1, slash = 1, impact = 1, drill = 1 },
	energy = { heat = 1, cold = 1, poison = 1, water = 1, electric = 1 },
}

local function withDefaults(overrides)
	overrides = overrides or {}
	local p = {}
	for k, v in pairs(defaults.physical) do p[k] = v end
	for k, v in pairs((overrides.physical or {})) do p[k] = v end
	local e = {}
	for k, v in pairs(defaults.energy) do e[k] = v end
	for k, v in pairs((overrides.energy or {})) do e[k] = v end
	return { physical = p, energy = e }
end

local CompositeConfig = {
	defaults = defaults,
	animal = { resistances = withDefaults({}), traits = { toughness = 0, mobilityBias = 0.05, energyBias = 0.05 } },
	water = { resistances = withDefaults({ energy = { heat = 1.35, water = 0.6, electric = 1.6 } }), traits = { toughness = -0.05, mobilityBias = 0.1, energyBias = 0.1 } },
	fire = { resistances = withDefaults({ energy = { heat = 0.55, cold = 1.45, water = 1.5 } }), traits = { toughness = -0.08, mobilityBias = 0.05, energyBias = 0.2 } },
	frost = { resistances = withDefaults({ energy = { heat = 1.5, cold = 0.55 } }), traits = { toughness = 0.08, mobilityBias = -0.02, energyBias = 0.05 } },
	rock = { resistances = withDefaults({ physical = { slash = 0.75, pierce = 0.85, drill = 1.35 } }), traits = { toughness = 0.3, mobilityBias = -0.12, energyBias = -0.05 } },
	voltage = { resistances = withDefaults({ energy = { electric = 0.55, water = 1.4 } }), traits = { toughness = -0.1, mobilityBias = 0.16, energyBias = 0.28 } },
	arcane = { resistances = withDefaults({ energy = { poison = 1.2, electric = 0.85 } }), traits = { toughness = -0.04, mobilityBias = 0.05, energyBias = 0.3 } },
}

return CompositeConfig
