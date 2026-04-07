local EcologyConfig = {
	terrainClasses = {
		ground = { spawnable = true, flora = true, node = true, obstacle = true },
		rock = { spawnable = false, flora = false, node = true, obstacle = true },
		water = { spawnable = false, flora = false, node = false, obstacle = false },
	},
	biomeTags = {
		plains = { "temperate", "open" },
		forest = { "temperate", "wooded" },
		ocean = { "wet", "coastal" },
		desert = { "arid", "open" },
		stormfield = { "charged", "open" },
		volcanic = { "hot", "rocky" },
		tundra = { "cold", "open" },
		polar = { "cold", "rocky" },
	},
	nodeCategories = {
		Tree = "flora_node",
		Rock = "mineral_node",
		Ore = "mineral_node",
		Crystal = "energy_node",
	},
	obstacleCategories = {
		RockObstacle = "rock_obstacle",
		TreeNode = "tree_obstacle",
	},
	spawn = {
		chunkCap = 4,
		spacing = 20,
		noSpawnInnerRadius = 55,
		despawnDistance = 320,
		despawnAgeGrace = 22,
		tiers = {
			small = { team = 1, weight = 0.24, statMult = { maxHP = 0.86, pAtk = 0.9, eAtk = 0.9, spd = 1.05 }, sizeMult = 0.85, timidness = 1.35, commitment = 0.75, pursuitRange = 90, aggroMult = 0.72, targetNearPlayerBias = 0.55 },
			normal = { team = 1, weight = 0.68, statMult = {}, sizeMult = 1, timidness = 1, commitment = 1, pursuitRange = 120, aggroMult = 1, targetNearPlayerBias = 0 },
			big = { team = 2, weight = 0.08, statMult = { maxHP = 1.35, pAtk = 1.22, eAtk = 1.22, spd = 0.94 }, sizeMult = 1.26, timidness = 0.82, commitment = 1.28, pursuitRange = 180, aggroMult = 1.45, targetNearPlayerBias = 0 },
		},
		archetypes = {
			skirmisher = { statMult = { spd = 1.12, maxHP = 0.92, pAtk = 1.04, eAtk = 1.04 }, sizeMult = 0.93, abilityPool = { "ram", "zap", "dashBite", "disengage" }, abilitySlots = 2 },
			bruiser = { statMult = { maxHP = 1.14, pAtk = 1.12, eAtk = 0.95, spd = 0.9 }, sizeMult = 1.08, abilityPool = { "ram", "stomp", "emberClaw", "stoneWall" }, abilitySlots = 2 },
			sentinel = { statMult = { maxHP = 1.06, pAtk = 0.96, eAtk = 1.1, spd = 0.98 }, sizeMult = 1.03, abilityPool = { "zap", "staticBurst", "staticBarrier", "pebbleShot" }, abilitySlots = 2 },
		},
		biomeArchetypeWeights = {
			plains = { skirmisher = 3, bruiser = 2, sentinel = 1 },
			forest = { skirmisher = 2, bruiser = 2, sentinel = 2 },
			ocean = { skirmisher = 2, bruiser = 1, sentinel = 3 },
			desert = { skirmisher = 2, bruiser = 3, sentinel = 1 },
			stormfield = { skirmisher = 2, bruiser = 1, sentinel = 3 },
			volcanic = { skirmisher = 1, bruiser = 4, sentinel = 1 },
			tundra = { skirmisher = 1, bruiser = 2, sentinel = 3 },
			polar = { skirmisher = 1, bruiser = 1, sentinel = 4 },
		},
	},
	regen = {
		nodeMinSeconds = 20,
		nodeDefaultSeconds = 30,
	},
	reasonCodes = {
		SPAWN_TOO_CLOSE_PLAYER = "SPAWN_TOO_CLOSE_PLAYER",
		SPAWN_TOO_CLOSE_WILD = "SPAWN_TOO_CLOSE_WILD",
		SPAWN_CHUNK_CAP = "SPAWN_CHUNK_CAP",
		SPAWN_TERRAIN = "SPAWN_TERRAIN",
		ECOLOGY_BLOCKED = "ECOLOGY_BLOCKED",
	},
}

return EcologyConfig
