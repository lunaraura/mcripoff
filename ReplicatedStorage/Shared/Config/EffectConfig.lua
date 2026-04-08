local EffectConfig = {}

EffectConfig.statuses = {
	burn = {
		class = "damage",
		tags = { "fire", "damage_over_time" },
		defaultDuration = 5,
		maxStacks = 3,
		stackMode = "stack",
		tickInterval = 1,
		overwrites = { "freeze" },
	},
	bleed = {
		class = "damage",
		tags = { "physical", "damage_over_time" },
		defaultDuration = 6,
		maxStacks = 4,
		stackMode = "stack",
		tickInterval = 1,
	},
	slow = {
		class = "control",
		tags = { "electric", "control" },
		defaultDuration = 4,
		maxStacks = 1,
		stackMode = "refresh",
		blockedByTags = { "slow_immune" },
	},
	haste = {
		class = "buff",
		tags = { "utility", "buff" },
		defaultDuration = 4,
		maxStacks = 1,
		stackMode = "refresh",
	},
	guard = {
		class = "defensive",
		tags = { "defensive", "shield" },
		defaultDuration = 3,
		maxStacks = 1,
		stackMode = "refresh",
	},
	wet = {
		class = "reactive",
		tags = { "water", "reactive" },
		defaultDuration = 5,
		maxStacks = 2,
		stackMode = "stack",
		cleansesTags = { "fire" },
	},
	shock = {
		class = "control",
		tags = { "electric", "reactive", "control" },
		defaultDuration = 2,
		maxStacks = 1,
		stackMode = "refresh",
	},
	freeze = {
		class = "control",
		tags = { "cold", "control" },
		defaultDuration = 1.8,
		maxStacks = 1,
		stackMode = "refresh",
		blockedByTags = { "freeze_immune" },
	},
}

EffectConfig.reactions = {
	wet_electric = {
		requiresStatus = "wet",
		requiresAbilityTag = "electric",
		applyStatus = { key = "shock", params = { duration = 2.5, magnitude = 0.18 } },
		bonusDamage = 3,
		consumeStatusStacks = 1,
		compositeScalarTrait = "conductivity",
		compositeScalarMin = 0.7,
		compositeScalarMax = 1.7,
	},
	wet_cools_burn = {
		requiresStatus = "burn",
		requiresAbilityTag = "water",
		reduceStacks = 2,
		expireIfNoStacks = true,
	},
	guard_impact = {
		requiresStatus = "guard",
		requiresAbilityTag = "impact",
		statusPressureReduction = 0.4,
		reduceDuration = 0.35,
	},
}

return EffectConfig
