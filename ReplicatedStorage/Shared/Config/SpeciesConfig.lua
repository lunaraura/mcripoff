local SpeciesConfig = {
	dog = {
		name = "Dog", familyKey = "canine", compositeKey = "animal", outerCompositeKey = "animal", innerCompositeKey = "animal", role = "fighter",
		stage = 0,
		baseStats = { pAtk = 12, eAtk = 2, range = 24, maxHP = 110, spd = 28, castSpd = 1, size = 4, stamina = 25, energy = 10, recoverStamina = 2, recoverEnergy = 1 },
		moveset = { "ram", "dashBite", "rallyHowl", "guardianLeap" }, drop = { { key = "meat", amount = 1 } },
		morphOptions = { { option = "warden_hound", pointsNeeded = 3 }, { option = "storm_hound", pointsNeeded = 3 }, { option = "cinderpup", pointsNeeded = 3 } },
	},
	sparko = {
		name = "Sparko", familyKey = "avian", compositeKey = "voltage", outerCompositeKey = "animal", innerCompositeKey = "voltage", role = "ranged",
		stage = 1,
		baseStats = { pAtk = 4, eAtk = 11, range = 90, maxHP = 82, spd = 30, castSpd = 1.1, size = 3, stamina = 16, energy = 22, recoverStamina = 1.1, recoverEnergy = 2 },
		moveset = { "zap", "staticBurst", "ram" }, drop = { { key = "battery_seed", amount = 1 } }, morphOptions = {},
	},
	sparkit = {
		name = "Sparkit", familyKey = "feline", compositeKey = "voltage", outerCompositeKey = "animal", innerCompositeKey = "voltage", role = "ranged",
		stage = 1,
		baseStats = { pAtk = 4, eAtk = 10, range = 88, maxHP = 80, spd = 30, castSpd = 1.1, size = 3, stamina = 16, energy = 22, recoverStamina = 1.1, recoverEnergy = 2 },
		moveset = { "zap", "staticBurst", "staticBarrier", "energize" }, drop = { { key = "battery_seed", amount = 1 } }, morphOptions = { { option = "sparko", pointsNeeded = 2 } },
	},
	cinderpup = {
		name = "Cinderpup", familyKey = "ursine", compositeKey = "fire", outerCompositeKey = "fire", innerCompositeKey = "animal", role = "fighter",
		stage = 1,
		baseStats = { pAtk = 10, eAtk = 6, range = 24, maxHP = 102, spd = 29, castSpd = 1.0, size = 4, stamina = 24, energy = 14, recoverStamina = 1.9, recoverEnergy = 1.4 },
		moveset = { "emberClaw", "ram" }, drop = { { key = "meat", amount = 1 } }, morphOptions = { { option = "magma_ursa", pointsNeeded = 3 }, { option = "dog", pointsNeeded = 3 } },
	},
	pebblit = {
		name = "Pebblit", familyKey = "crust_rock", compositeKey = "rock", outerCompositeKey = "rock", innerCompositeKey = "animal", role = "tank",
		stage = 1,
		baseStats = { pAtk = 11, eAtk = 1, range = 22, maxHP = 124, spd = 22, castSpd = 0.9, size = 4, stamina = 26, energy = 8, recoverStamina = 2.0, recoverEnergy = 1.0 },
		moveset = { "pebbleShot", "ram", "stoneWall" }, drop = { { key = "stone", amount = 1 } }, morphOptions = { { option = "boarox", pointsNeeded = 3 } },
	},
	boarox = {
		name = "Boarox", familyKey = "ursine", compositeKey = "rock", outerCompositeKey = "rock", innerCompositeKey = "animal", role = "tank",
		stage = 1,
		baseStats = { pAtk = 13, eAtk = 1, range = 24, maxHP = 140, spd = 22, castSpd = 0.9, size = 5, stamina = 28, energy = 8, recoverStamina = 2.1, recoverEnergy = 0.9 },
		moveset = { "stomp", "ram", "rallyHowl" }, drop = { { key = "stone", amount = 1 } }, morphOptions = {},
	},
	warden_hound = {
		name = "Warden Hound", familyKey = "canine", compositeKey = "rock", outerCompositeKey = "rock", innerCompositeKey = "animal", role = "tank",
		stage = 1,
		baseStats = { pAtk = 12, eAtk = 4, range = 26, maxHP = 135, spd = 24, castSpd = 0.95, size = 5, stamina = 28, energy = 12, recoverStamina = 2.1, recoverEnergy = 1.0 },
		moveset = { "ram", "stomp", "rallyHowl", "stoneWall" }, drop = { { key = "stone", amount = 2 } }, morphOptions = {},
	},
	storm_hound = {
		name = "Storm Hound", familyKey = "canine", compositeKey = "voltage", outerCompositeKey = "animal", innerCompositeKey = "voltage", role = "skirmisher",
		stage = 1,
		baseStats = { pAtk = 9, eAtk = 10, range = 90, maxHP = 96, spd = 32, castSpd = 1.1, size = 4, stamina = 24, energy = 20, recoverStamina = 2.0, recoverEnergy = 2.1 },
		moveset = { "dashBite", "blinkStrike", "staticBurst", "disengage" }, drop = { { key = "battery_seed", amount = 2 } }, morphOptions = {},
	},
	magma_ursa = {
		name = "Magma Ursa", familyKey = "ursine", compositeKey = "rock", outerCompositeKey = "rock", innerCompositeKey = "fire", role = "tank",
		stage = 1,
		baseStats = { pAtk = 14, eAtk = 7, range = 30, maxHP = 150, spd = 20, castSpd = 0.9, size = 6, stamina = 30, energy = 16, recoverStamina = 2.2, recoverEnergy = 1.2 },
		moveset = { "emberClaw", "stomp", "ram", "stoneWall" }, drop = { { key = "stone", amount = 2 } }, morphOptions = {},
	},
	glintswift = {
		name = "Glintswift", familyKey = "avian", compositeKey = "frost", outerCompositeKey = "frost", innerCompositeKey = "arcane", role = "ranged",
		stage = 1,
		baseStats = { pAtk = 5, eAtk = 11, range = 110, maxHP = 80, spd = 33, castSpd = 1.2, size = 3, stamina = 18, energy = 25, recoverStamina = 1.3, recoverEnergy = 2.4 },
		moveset = { "zap", "staticBurst", "disengage" }, drop = { { key = "crystal_shard", amount = 1 } }, morphOptions = {},
	},
	miregel = {
		name = "Miregel", familyKey = "slime", compositeKey = "water", outerCompositeKey = "water", innerCompositeKey = "arcane", role = "utility",
		stage = 1,
		baseStats = { pAtk = 6, eAtk = 9, range = 70, maxHP = 112, spd = 24, castSpd = 1.0, size = 5, stamina = 18, energy = 22, recoverStamina = 1.0, recoverEnergy = 2.1 },
		moveset = { "ram", "mendPulse", "staticBarrier", "energize" }, drop = { { key = "water_glob", amount = 1 } }, morphOptions = {},
	},
	sheeplet = {
		name = "Sheeplet", familyKey = "herd", compositeKey = "animal", outerCompositeKey = "animal", innerCompositeKey = "animal", role = "passive",
		stage = 0,
		baseStats = { pAtk = 3, eAtk = 0, range = 20, maxHP = 76, spd = 24, castSpd = 1.0, size = 3, stamina = 14, energy = 8, recoverStamina = 1.8, recoverEnergy = 1.0 },
		moveset = {}, harvestDrop = { { key = "fiber", amount = 2 } }, harvestCooldown = 20, drop = { { key = "meat", amount = 1 } }, morphOptions = {},
	},
	goat = {
		name = "Goat", familyKey = "herd", compositeKey = "animal", outerCompositeKey = "animal", innerCompositeKey = "animal", role = "passive",
		stage = 0,
		baseStats = { pAtk = 5, eAtk = 0, range = 22, maxHP = 88, spd = 26, castSpd = 1.0, size = 3.5, stamina = 18, energy = 9, recoverStamina = 2.0, recoverEnergy = 1.0 },
		moveset = { "ram" }, harvestDrop = { { key = "fiber", amount = 1 } }, harvestCooldown = 22, drop = { { key = "meat", amount = 1 } }, morphOptions = {},
	},
	got = {
		name = "Got", familyKey = "herd", compositeKey = "animal", outerCompositeKey = "animal", innerCompositeKey = "animal", role = "passive",
		stage = 0,
		baseStats = { pAtk = 5, eAtk = 0, range = 22, maxHP = 88, spd = 26, castSpd = 1.0, size = 3.5, stamina = 18, energy = 9, recoverStamina = 2.0, recoverEnergy = 1.0 },
		moveset = { "ram" }, harvestDrop = { { key = "fiber", amount = 1 } }, harvestCooldown = 22, drop = { { key = "meat", amount = 1 } }, morphOptions = {},
	},
	elephant = {
		name = "Elephant", familyKey = "ursine", compositeKey = "animal", outerCompositeKey = "animal", innerCompositeKey = "animal", role = "tank",
		stage = 0,
		baseStats = { pAtk = 14, eAtk = 1, range = 24, maxHP = 175, spd = 19, castSpd = 0.85, size = 7, stamina = 34, energy = 8, recoverStamina = 2.3, recoverEnergy = 0.8 },
		moveset = { "stomp", "ram" }, drop = { { key = "meat", amount = 2 }, { key = "fiber", amount = 2 } }, morphOptions = {},
	},
	boar = {
		name = "Boar", familyKey = "ursine", compositeKey = "animal", outerCompositeKey = "animal", innerCompositeKey = "animal", role = "fighter",
		stage = 0,
		baseStats = { pAtk = 11, eAtk = 0, range = 24, maxHP = 108, spd = 25, castSpd = 0.95, size = 4.5, stamina = 24, energy = 7, recoverStamina = 2.0, recoverEnergy = 0.9 },
		moveset = { "ram", "dashBite" }, drop = { { key = "meat", amount = 1 } }, morphOptions = { { option = "boarox", pointsNeeded = 3 } },
	},
}

return SpeciesConfig
