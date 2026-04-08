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
	animal = {
		resistances = withDefaults({ physical = { drill = 1.1 }, energy = { water = 0.8, electric = 1.4 } }),
		specialEffects = {},
		statusHooks = { tagScale = {}, immunities = {} },
		traits = { toughness = 0, conductivity = 0.25, heatRetention = 0.35, mobilityBias = 0.08, energyBias = 0.05, regenBias = 0.10 },
	},
	water = {
		resistances = withDefaults({ physical = { slash = 0.95, impact = 1.15, drill = 1.05 }, energy = { heat = 1.35, cold = 0.85, poison = 0.9, water = 0.6, electric = 1.6 } }),
		specialEffects = { "waterAdd" },
		statusHooks = { tagScale = { fire = 0.75, electric = 1.2 }, immunities = {} },
		traits = { toughness = -0.05, conductivity = 0.90, heatRetention = -0.35, mobilityBias = 0.10, energyBias = 0.10, regenBias = 0.18 },
	},
	fire = {
		resistances = withDefaults({ physical = { slash = 0.95, impact = 1.1 }, energy = { heat = 0.55, cold = 1.45, poison = 0.9, water = 1.5 } }),
		specialEffects = { "fireUp", "burnoff" },
		statusHooks = { tagScale = { fire = 0.55, water = 1.2 }, immunities = { freeze = true } },
		traits = { toughness = -0.08, conductivity = 0.10, heatRetention = 0.95, mobilityBias = 0.05, energyBias = 0.20, regenBias = -0.05 },
	},
	frost = {
		resistances = withDefaults({ physical = { slash = 0.95, impact = 1.05 }, energy = { heat = 1.5, cold = 0.55, water = 0.85, electric = 1.1 } }),
		specialEffects = {},
		statusHooks = { tagScale = { cold = 0.6, fire = 1.2 }, immunities = {} },
		traits = { toughness = 0.08, conductivity = 0.35, heatRetention = -0.25, mobilityBias = -0.04, energyBias = 0.05, regenBias = 0.10 },
	},
	rock = {
		resistances = withDefaults({ physical = { slash = 0.75, pierce = 0.85, impact = 1.1, drill = 1.35 }, energy = { poison = 0.6, water = 0.95, electric = 0.8 } }),
		specialEffects = { "hardSurface" },
		statusHooks = { tagScale = { impact = 0.8 }, immunities = { bleed = true } },
		traits = { toughness = 0.35, conductivity = 0.15, heatRetention = 0.65, mobilityBias = -0.12, energyBias = -0.05, regenBias = 0.0 },
	},
	voltage = {
		resistances = withDefaults({ physical = { pierce = 1.05, impact = 1.1 }, energy = { heat = 1.1, water = 1.4, electric = 0.55 } }),
		specialEffects = { "waterVolt" },
		statusHooks = { tagScale = { electric = 0.5, water = 1.15 }, immunities = { shock = true } },
		traits = { toughness = -0.10, conductivity = 1.00, heatRetention = 0.05, mobilityBias = 0.18, energyBias = 0.28, regenBias = 0.00 },
	},
	arcane = {
		resistances = withDefaults({ physical = { impact = 1.05 }, energy = { heat = 0.95, cold = 0.95, poison = 1.2, electric = 0.85 } }),
		specialEffects = {},
		statusHooks = { tagScale = {}, immunities = {} },
		traits = { toughness = -0.04, conductivity = 0.60, heatRetention = 0.20, mobilityBias = 0.05, energyBias = 0.30, regenBias = 0.05 },
	},
}

return CompositeConfig
