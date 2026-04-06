local FamilyConfig = {
	canine = { aiTendency = { aggression = 0.65, engageRangeBias = 1.0 }, statMult = { maxHP = 1.04, spd = 1.05, stamina = 1.1, energy = 0.95 } },
	feline = { aiTendency = { aggression = 0.55, engageRangeBias = 1.08 }, statMult = { maxHP = 0.95, spd = 1.15, stamina = 1.0, energy = 1.08 } },
	ursine = { aiTendency = { aggression = 0.72, engageRangeBias = 0.92 }, statMult = { maxHP = 1.22, spd = 0.88, stamina = 1.14, energy = 0.9 } },
	avian = { aiTendency = { aggression = 0.48, engageRangeBias = 1.25 }, statMult = { maxHP = 0.9, spd = 1.2, stamina = 0.95, energy = 1.15 } },
	slime = { aiTendency = { aggression = 0.4, engageRangeBias = 0.95 }, statMult = { maxHP = 1.08, spd = 0.92, stamina = 0.92, energy = 1.1 } },
	herd = { aiTendency = { aggression = 0.18, engageRangeBias = 0.9 }, statMult = { maxHP = 1.0, spd = 1.0, stamina = 1.06, energy = 0.92 } },
}

return FamilyConfig
