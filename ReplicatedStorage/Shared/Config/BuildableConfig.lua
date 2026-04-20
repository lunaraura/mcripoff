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
		berryPlanting = {
			berryOrder = { "berry_red", "berry_yellow", "berry_blue", "revive_berry", "replenish_berry" },
			berryTypes = {
				berry_red = { label = "Red", yield = 2, baseColor = { 200, 85, 85 } },
				berry_yellow = { label = "Yellow", yield = 2, baseColor = { 230, 210, 110 } },
				berry_blue = { label = "Blue", yield = 2, baseColor = { 110, 180, 255 } },
				revive_berry = { label = "Revive", yield = 1, baseColor = { 150, 120, 240 } },
				replenish_berry = { label = "Replenish", yield = 1, baseColor = { 90, 200, 220 } },
			},
			growth = {
				durationSeconds = 90,
				stageThresholds = {
					planted = 0.0,
					growing = 0.35,
					mature = 1.0,
				},
			},
			stageVisuals = {
				planted = { size = { 2.6, 2.2, 2.6 }, darken = 0.55 },
				growing = { size = { 3.6, 3.2, 3.6 }, darken = 0.25 },
				mature = { size = { 4.4, 4.0, 4.4 }, darken = 0.0 },
			},
			plantingCostSource = "consume_selected_berry_item",
		},
		harvesting = {
			interval = 90,
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
