local EffectConfig = {}

EffectConfig.statuses = {
	burn = {
		tags = { "fire", "damage_over_time" },
		defaultDuration = 5,
		maxStacks = 3,
		stackMode = "stack",
		tickInterval = 1,
	},
	bleed = {
		tags = { "physical", "damage_over_time" },
		defaultDuration = 6,
		maxStacks = 4,
		stackMode = "stack",
		tickInterval = 1,
	},
	slow = {
		tags = { "electric", "control" },
		defaultDuration = 4,
		maxStacks = 1,
		stackMode = "refresh",
	},
	haste = {
		tags = { "utility", "buff" },
		defaultDuration = 4,
		maxStacks = 1,
		stackMode = "refresh",
	},
	guard = {
		tags = { "defensive", "shield" },
		defaultDuration = 3,
		maxStacks = 1,
		stackMode = "refresh",
	},
	wet = {
		tags = { "water", "reactive" },
		defaultDuration = 5,
		maxStacks = 2,
		stackMode = "stack",
		cleansesTags = { "fire" },
	},
	shock = {
		tags = { "electric", "reactive", "control" },
		defaultDuration = 2,
		maxStacks = 1,
		stackMode = "refresh",
	},
}

EffectConfig.reactions = {
	wet_electric = {
		requiresStatus = "wet",
		requiresAbilityTag = "electric",
		applyStatus = { key = "shock", params = { duration = 2.5, magnitude = 0.18 } },
		bonusDamage = 3,
		consumeStatusStacks = 1,
	},
	wet_cools_burn = {
		requiresStatus = "burn",
		requiresAbilityTag = "water",
		consumeStatus = "burn",
	},
	guard_impact = {
		requiresStatus = "guard",
		requiresAbilityTag = "impact",
		statusPressureReduction = 0.4,
	},
}

return EffectConfig
