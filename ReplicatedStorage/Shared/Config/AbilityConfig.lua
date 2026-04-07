local AbilityConfig = {
	ram = {
		name = "Ram", category = "melee", cooldown = 2.0,
		resourceUse = { stamina = 5, energy = 0 },
		flatDmg = { p = 3, e = 0 }, dmgScale = { p = 0.8, e = 0 },
		damageProfile = { physical = { "impact" } }, range = 24,
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
	},
	emberClaw = {
		name = "Ember Claw", category = "melee", cooldown = 1.4,
		resourceUse = { stamina = 6, energy = 2 },
		flatDmg = { p = 5, e = 3 }, dmgScale = { p = 0.4, e = 0.2 },
		damageProfile = { physical = { "slash" }, energy = { "heat" } }, range = 26,
		statusOnHit = {
			{ key = "burn", chance = 0.4, params = { duration = 5, dps = 2.2 } },
		},
	},
	pebbleShot = {
		name = "Pebble Shot", category = "projectile", cooldown = 6.0,
		resourceUse = { stamina = 5, energy = 0 },
		flatDmg = { p = 4, e = 0 }, dmgScale = { p = 0.2, e = 0 },
		damageProfile = { physical = { "pierce" } }, range = 150,
		projectile = { speed = 90, homing = false, radius = 4, life = 2.6 },
	},
	staticBurst = {
		name = "Static Burst", category = "aoe", cooldown = 5.2,
		resourceUse = { stamina = 0, energy = 15 },
		flatDmg = { p = 0, e = 10 }, dmgScale = { p = 0, e = 0.3 },
		damageProfile = { energy = { "electric" } }, range = 90,
		area = { radius = 40, mode = "instant" },
		statusOnHit = { { key = "slow", chance = 1, params = { duration = 1.5, mult = 0.65 } } },
	},
	stomp = {
		name = "Stomp", category = "aoe", cooldown = 5.2,
		resourceUse = { stamina = 12, energy = 0 },
		flatDmg = { p = 8, e = 0 }, dmgScale = { p = 0.5, e = 0 },
		damageProfile = { physical = { "impact" } }, range = 26,
		area = { radius = 28, mode = "lingering", duration = 1.0, tick = 0.5 },
		statusSelf = { { key = "guard", chance = 1, params = { duration = 2.5, reduction = 0.22 } } },
	},
	dashBite = {
		name = "Dash Bite", category = "dash", cooldown = 3.0,
		resourceUse = { stamina = 10, energy = 0 },
		flatDmg = { p = 15, e = 0 }, dmgScale = { p = 0.65, e = 0 },
		damageProfile = { physical = { "slash" } }, range = 26,
		dash = { distance = 90, stopShort = 10 },
		statusOnHit = { { key = "slow", chance = 0.35, params = { duration = 1.1, mult = 0.75 } } },
	},
	staticBarrier = {
		name = "Static Barrier", category = "barrier", cooldown = 10.5,
		resourceUse = { stamina = 0, energy = 20 },
		flatDmg = { p = 0, e = 0 }, dmgScale = { p = 0, e = 0 }, range = 120,
		barrier = { kind = "zone", radius = 52, duration = 5.0, slow = 0.25, damageReduction = 0.22, blockMovement = true },
	},
	stoneWall = {
		name = "Stone Wall", category = "barrier", cooldown = 12.0,
		resourceUse = { stamina = 8, energy = 10 },
		flatDmg = { p = 0, e = 0 }, dmgScale = { p = 0, e = 0 }, range = 90,
		barrier = { kind = "wall", duration = 4.0, length = 60, thickness = 8, blockMovement = true, damageReduction = 0.15 },
	},
	rallyHowl = {
		name = "Rally Howl", category = "utility", cooldown = 6.2,
		resourceUse = { stamina = 0, energy = 10 },
		flatDmg = { p = 0, e = 0 }, dmgScale = { p = 0, e = 0 }, range = 0,
		statusSelf = { { key = "haste", chance = 1, params = { duration = 4, mult = 1.2 } } },
	},
	disengage = {
		name = "Disengage", category = "retreat", cooldown = 3.0,
		resourceUse = { stamina = 10, energy = 0 },
		flatDmg = { p = 10, e = 0 }, dmgScale = { p = 0, e = 0 },
		damageProfile = { physical = { "impact" } },
		dash = { distance = 80, stopShort = 10 }, range = 20,
	},
}

return AbilityConfig
