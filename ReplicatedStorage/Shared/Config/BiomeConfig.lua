local BiomeConfig = {
	plains = {
		color = Color3.fromRGB(136, 170, 124),
		spawns = { { key = "dog", weight = 3 }, { key = "sparko", weight = 2 }, { key = "sheeplet", weight = 5 } },
		nodes = { { key = "berry_bush", weight = 5 }, { key = "stone_node", weight = 3 } },
	},
	stormfield = {
		color = Color3.fromRGB(92, 116, 143),
		spawns = { { key = "sparko", weight = 6 }, { key = "boarox", weight = 2 }, { key = "sheeplet", weight = 2 } },
		nodes = { { key = "battery_crystal", weight = 5 }, { key = "stone_node", weight = 2 } },
	},
}

return BiomeConfig
