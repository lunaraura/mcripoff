local BuildableConfig = {
	fiber_trap = {
		name = "Fiber Trap",
		cost = { fiber = 2 },
		harvesting = {
			interval = 1.5,
			provides = { bait = 1 },
		},
		placement = {
			previewShape = "block",
			previewSize = { x = 4, y = 2, z = 4 },
			footprintSize = { x = 4, y = 2, z = 4 },
			collisionRadius = 2.5,
			placementRange = 16,
			allowedTerrain = { "ground" },
			allowRotation = false,
			grid = 4,
		},
	},
	relay_post = {
		name = "Relay Post",
		cost = { stone = 2, fiber = 1 },
		harvesting = {
			interval = 2.0,
			provides = { battery_seed = 1 },
		},
		placement = {
			previewShape = "block",
			previewSize = { x = 4, y = 4, z = 4 },
			footprintSize = { x = 4, y = 4, z = 4 },
			collisionRadius = 3,
			placementRange = 16,
			allowedTerrain = { "ground", "rock" },
			allowRotation = true,
			grid = 4,
		},
	},

	berry_shrub = {
		name = "Berry Shrub",
		cost = {},
		harvesting = {
			interval = 20,
			provides = {},
		},
		placement = {
			previewShape = "ball",
			previewSize = { x = 4, y = 3, z = 4 },
			footprintSize = { x = 4, y = 4, z = 4 },
			collisionRadius = 2.5,
			placementRange = 16,
			allowedTerrain = { "ground" },
			allowRotation = false,
			grid = 4,
		},
	},
	tent = {
		name = "Tent",
		cost = { wood = 5 },
		harvesting = {
			interval = 4.0,
			provides = {},
		},
		effect = {
			type = "pet_regen",
			radius = 20,
			interval = 5,
			flatHeal = 6,
		},
		placement = {
			previewShape = "wedge",
			previewSize = { x = 8, y = 5, z = 8 },
			footprintSize = { x = 8, y = 5, z = 8 },
			collisionRadius = 5,
			placementRange = 18,
			allowedTerrain = { "ground" },
			allowRotation = true,
			grid = 4,
		},
	},
}

return BuildableConfig
