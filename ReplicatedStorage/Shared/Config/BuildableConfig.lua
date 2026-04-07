local BuildableConfig = {
	fiber_trap = {
		name = "Fiber Trap",
		cost = { fiber = 2 },
		harvestTime = 1.5,
		provides = { bait = 1 },
		placement = {
			previewShape = "block",
			previewSize = { x = 4, y = 2, z = 4 },
			footprintSize = { x = 4, y = 2, z = 4 },
			collisionRadius = 2.5,
			placementRange = 16,
			allowedTerrain = { "ground" },
			allowRotation = false,
		},
	},
	relay_post = {
		name = "Relay Post",
		cost = { stone = 2, fiber = 1 },
		harvestTime = 2.0,
		provides = { battery_seed = 1 },
		placement = {
			previewShape = "block",
			previewSize = { x = 4, y = 4, z = 4 },
			footprintSize = { x = 4, y = 4, z = 4 },
			collisionRadius = 3,
			placementRange = 16,
			allowedTerrain = { "ground", "rock" },
			allowRotation = true,
		},
	},
	tent = {
		name = "Tent",
		cost = { wood = 5 },
		harvestTime = 4.0,
		provides = {},
		placement = {
			previewShape = "wedge",
			previewSize = { x = 8, y = 5, z = 8 },
			footprintSize = { x = 8, y = 5, z = 8 },
			collisionRadius = 5,
			placementRange = 18,
			allowedTerrain = { "ground" },
			allowRotation = true,
		},
	},
}

return BuildableConfig
