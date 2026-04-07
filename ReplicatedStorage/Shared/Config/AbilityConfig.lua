local AbilityConfig = {
	ram = {
		name = "Ram", category = "melee", cooldown = 2.0,
		resourceUse = { stamina = 5, energy = 0 },
		flatDmg = { p = 3, e = 0 }, dmgScale = { p = 0.8, e = 0 },
		damageProfile = { physical = { "impact" } }, range = 18,
		statusOnHit = {
			{ key = "bleed", chance = 0.2, params = { duration = 4, dps = 1.5 } },
		},
	},
	zap = {
		name = "Zap", category = "hitscan", cooldown = 4.2,
		resourceUse = { stamina = 0, energy = 10 },
		flatDmg = { p = 0, e = 2 }, dmgScale = { p = 0, e = 0.3 },
		damageProfile = { energy = { "electric" } }, range = 80,
		statusOnHit = {
			{ key = "slow", chance = 0.35, params = { duration = 3.5, mult = 0.72 } },
		},
		statusSelf = {
			{ key = "haste", chance = 0.25, params = { duration = 2.5, mult = 1.15 } },
		},
	},
	emberClaw = {
		name = "Ember Claw", category = "melee", cooldown = 1.4,
		resourceUse = { stamina = 6, energy = 2 },
		flatDmg = { p = 5, e = 3 }, dmgScale = { p = 0.4, e = 0.2 },
		damageProfile = { physical = { "slash" }, energy = { "heat" } }, range = 20,
		statusOnHit = {
			{ key = "burn", chance = 0.4, params = { duration = 5, dps = 2.2 } },
		},
	},
	stomp = {
		name = "Stomp", category = "aoe", cooldown = 5.2,
		resourceUse = { stamina = 12, energy = 0 },
		flatDmg = { p = 8, e = 0 }, dmgScale = { p = 0.5, e = 0 },
		damageProfile = { physical = { "impact" } }, range = 16, area = { radius = 20 },
		statusSelf = {
			{ key = "guard", chance = 1, params = { duration = 2.5, reduction = 0.22 } },
		},
	},
}

return AbilityConfig
