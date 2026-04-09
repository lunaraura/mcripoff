local BiomeConfig = {
	plains = {
		color = Color3.fromRGB(136, 170, 124),
		rules = { temperature = 0.55, rainfall = 0.45, lithosphere = 0.45, barrenness = 0.35, arcane = 0.45, softness = 0.28, bias = 1.0 },
		spawns = { { key = "dog", weight = 3 }, { key = "sheeplet", weight = 2 }, { key = "goat", weight = 2 }, { key = "boar", weight = 2 }, { key = "pebblit", weight = 2 }, { key = "elephant", weight = 1 }, { key = "boarox", weight = 1 } },
		nodes = { { key = "berry_bush_red", weight = 12 }, { key = "energy_crystal", weight = 2 }, { key = "revive_berry_bush", weight = 1 }, { key = "replenish_berry_bush", weight = 1 } },
	},
	ocean = {
		color = Color3.fromRGB(75, 115, 150),
		rules = { temperature = 0.46, rainfall = 0.86, lithosphere = 0.22, barrenness = 0.20, arcane = 0.50, softness = 0.22, bias = 0.82 },
		spawns = { { key = "sparkit", weight = 2 }, { key = "dog", weight = 1 }, { key = "sheeplet", weight = 2 } },
		nodes = { { key = "energy_crystal", weight = 6 }, { key = "replenish_berry_bush", weight = 4 }, { key = "bait_shrub", weight = 1 } },
	},
	forest = {
		color = Color3.fromRGB(110, 154, 95),
		rules = { temperature = 0.50, rainfall = 0.75, lithosphere = 0.42, barrenness = 0.15, arcane = 0.42, softness = 0.26, bias = 1.05 },
		spawns = { { key = "dog", weight = 3 }, { key = "goat", weight = 2 }, { key = "boar", weight = 2 }, { key = "cinderpup", weight = 2 }, { key = "sheeplet", weight = 1 } },
		nodes = { { key = "berry_bush_red", weight = 22 }, { key = "bait_shrub", weight = 3 }, { key = "revive_berry_bush", weight = 1 }, { key = "replenish_berry_bush", weight = 1 } },
	},
	desert = {
		color = Color3.fromRGB(184, 165, 108),
		rules = { temperature = 0.82, rainfall = 0.12, lithosphere = 0.40, barrenness = 0.90, arcane = 0.30, softness = 0.22, bias = 0.95 },
		spawns = { { key = "pebblit", weight = 5 }, { key = "cinderpup", weight = 3 } },
		nodes = { { key = "energy_crystal", weight = 5 }, { key = "bait_shrub", weight = 2 }, { key = "revive_berry_bush", weight = 1 }, { key = "replenish_berry_bush", weight = 1 } },
	},
	stormfield = {
		color = Color3.fromRGB(92, 116, 143),
		rules = { temperature = 0.45, rainfall = 0.65, lithosphere = 0.55, barrenness = 0.55, arcane = 0.76, softness = 0.24, bias = 0.85 },
		spawns = { { key = "sparkit", weight = 5 }, { key = "dog", weight = 1 }, { key = "sparko", weight = 2 } },
		nodes = { { key = "energy_crystal", weight = 6 }, { key = "berry_bush_red", weight = 2 }, { key = "revive_berry_bush", weight = 1 }, { key = "replenish_berry_bush", weight = 1 } },
	},
	volcanic = {
		color = Color3.fromRGB(139, 92, 79),
		rules = { temperature = 0.88, rainfall = 0.18, lithosphere = 0.82, barrenness = 0.78, arcane = 0.55, softness = 0.20, bias = 0.70 },
		spawns = { { key = "cinderpup", weight = 5 }, { key = "pebblit", weight = 2 }, { key = "boarox", weight = 1 } },
		nodes = { { key = "bait_shrub", weight = 4 }, { key = "energy_crystal", weight = 2 }, { key = "revive_berry_bush", weight = 1 }, { key = "replenish_berry_bush", weight = 1 } },
	},
	tundra = {
		color = Color3.fromRGB(148, 166, 174),
		rules = { temperature = 0.20, rainfall = 0.44, lithosphere = 0.52, barrenness = 0.55, arcane = 0.38, softness = 0.21, bias = 0.72 },
		spawns = { { key = "dog", weight = 2 }, { key = "goat", weight = 1 }, { key = "pebblit", weight = 3 }, { key = "sheeplet", weight = 1 }, { key = "elephant", weight = 1 } },
		nodes = { { key = "replenish_berry_bush", weight = 5 }, { key = "revive_berry_bush", weight = 3 }, { key = "energy_crystal", weight = 2 } },
	},
	polar = {
		color = Color3.fromRGB(215, 231, 240),
		rules = { temperature = 0.07, rainfall = 0.26, lithosphere = 0.58, barrenness = 0.76, arcane = 0.62, softness = 0.18, bias = 0.55 },
		spawns = { { key = "sparkit", weight = 2 }, { key = "pebblit", weight = 2 }, { key = "sparko", weight = 2 } },
		nodes = { { key = "energy_crystal", weight = 6 }, { key = "replenish_berry_bush", weight = 2 }, { key = "revive_berry_bush", weight = 2 } },
	},
}

return BiomeConfig
