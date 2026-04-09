local FamilyConfig = {
	canine = {
		aiTendency = { aggression = 0.65, engageRangeBias = 1.0 },
		growthWeights = { maxHP = 1.15, pAtk = 1.15, eAtk = 0.8, spd = 1.1, stamina = 1.2, energy = 0.85 },
	},
	feline = {
		aiTendency = { aggression = 0.55, engageRangeBias = 1.08 },
		growthWeights = { maxHP = 0.9, pAtk = 1.05, eAtk = 1.05, spd = 1.25, stamina = 1.0, energy = 1.1 },
	},
	ursine = {
		aiTendency = { aggression = 0.72, engageRangeBias = 0.92 },
		growthWeights = { maxHP = 1.35, pAtk = 1.2, eAtk = 0.8, spd = 0.75, stamina = 1.25, energy = 0.9 },
	},
	avian = {
		aiTendency = { aggression = 0.48, engageRangeBias = 1.25 },
		growthWeights = { maxHP = 0.8, pAtk = 0.95, eAtk = 1.2, spd = 1.35, stamina = 0.9, energy = 1.2 },
	},
	slime = {
		aiTendency = { aggression = 0.4, engageRangeBias = 0.95 },
		growthWeights = { maxHP = 1.15, pAtk = 0.85, eAtk = 1.05, spd = 0.85, stamina = 0.9, energy = 1.25 },
	},
	herd = {
		aiTendency = { aggression = 0.18, engageRangeBias = 0.9 },
		growthWeights = { maxHP = 1.0, pAtk = 0.9, eAtk = 0.8, spd = 1.05, stamina = 1.2, energy = 0.95 },
	},
	crust_rock = {
		aiTendency = { aggression = 0.5, engageRangeBias = 0.9 },
		growthWeights = { maxHP = 1.3, pAtk = 1.15, eAtk = 0.75, spd = 0.7, stamina = 1.3, energy = 0.85 },
	},
}

return FamilyConfig
