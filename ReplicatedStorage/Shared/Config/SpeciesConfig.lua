local SpeciesConfig = {
	dog = {
		name = "Dog", familyKey = "canine", compositeKey = "animal", role = "fighter",
		baseStats = { pAtk = 12, eAtk = 2, range = 24, maxHP = 110, spd = 28, castSpd = 1, size = 4, stamina = 25, energy = 10, recoverStamina = 2, recoverEnergy = 1 },
		moveset = { "ram", "emberClaw" }, drop = { { key = "meat", amount = 1 } }, morphOptions = {},
	},
	sparko = {
		name = "Sparko", familyKey = "avian", compositeKey = "voltage", role = "ranged",
		baseStats = { pAtk = 4, eAtk = 11, range = 90, maxHP = 82, spd = 30, castSpd = 1.1, size = 3, stamina = 16, energy = 22, recoverStamina = 1.1, recoverEnergy = 2 },
		moveset = { "zap", "ram" }, drop = { { key = "battery_seed", amount = 1 } }, morphOptions = {},
	},
	boarox = {
		name = "Boarox", familyKey = "ursine", compositeKey = "rock", role = "tank",
		baseStats = { pAtk = 13, eAtk = 1, range = 24, maxHP = 140, spd = 22, castSpd = 0.9, size = 5, stamina = 28, energy = 8, recoverStamina = 2.1, recoverEnergy = 0.9 },
		moveset = { "stomp", "ram" }, drop = { { key = "stone", amount = 1 } }, morphOptions = {},
	},
	sheeplet = {
		name = "Sheeplet", familyKey = "herd", compositeKey = "animal", role = "passive",
		baseStats = { pAtk = 3, eAtk = 0, range = 20, maxHP = 76, spd = 24, castSpd = 1.0, size = 3, stamina = 14, energy = 8, recoverStamina = 1.8, recoverEnergy = 1.0 },
		moveset = {}, harvestDrop = { { key = "fiber", amount = 2 } }, harvestCooldown = 20, drop = { { key = "meat", amount = 1 } }, morphOptions = {},
	},
}

return SpeciesConfig
