local ObjectiveConfig = {}

ObjectiveConfig.Objectives = {
	choose_starter = {
		id = "choose_starter",
		label = "Choose Your Starter",
		description = "Pick your first companion creature.",
		category = "tutorial",
		stage = 1,
		requirements = {
			{ type = "starter_chosen" },
		},
		rewards = {},
		visibility = { prerequisiteIds = {} },
	},
	gather_heal_berries = {
		id = "gather_heal_berries",
		label = "Gather Heal Berries",
		description = "Collect 3 heal berries to unlock planting.",
		category = "tutorial",
		stage = 2,
		requirements = {
			{ type = "item_total", keys = { "berry_red", "berry_yellow", "berry_blue" }, count = 3 },
		},
		rewards = {
			{ type = "unlock_tool", key = "berry_planter", amount = 1 },
			{ type = "unlock_feature", key = "planter_tool" },
		},
		visibility = { prerequisiteIds = { "choose_starter" } },
	},
	level_up_pet = {
		id = "level_up_pet",
		label = "Level Up Your Pet",
		description = "Reach pet level 2 to unlock the node demolisher.",
		category = "tutorial",
		stage = 3,
		requirements = {
			{ type = "pet_level_min", level = 2 },
		},
		rewards = {
			{ type = "unlock_tool", key = "node_demolisher", amount = 1 },
			{ type = "unlock_feature", key = "building_tool" },
		},
		visibility = { prerequisiteIds = { "gather_heal_berries" } },
	},
}

ObjectiveConfig.Order = {
	"choose_starter",
	"gather_heal_berries",
	"level_up_pet",
}

return ObjectiveConfig
