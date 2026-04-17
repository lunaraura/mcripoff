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
		description = "Collect 3 heal berries.",
		category = "tutorial",
		stage = 2,
		requirements = {
			{ type = "item_total", keys = { "berry_red", "berry_yellow", "berry_blue" }, count = 3 },
		},
		rewards = {},
		visibility = { prerequisiteIds = { "choose_starter" } },
	},
	gather_revive_berries = {
		id = "gather_revive_berries",
		label = "Gather Revive Berries",
		description = "Collect 1 revive berry.",
		category = "tutorial",
		stage = 3,
		requirements = {
			{ type = "item_gained", key = "revive_berry", count = 1 },
		},
		rewards = {},
		visibility = { prerequisiteIds = { "gather_heal_berries" } },
	},
	unlock_planting_tool = {
		id = "unlock_planting_tool",
		label = "Unlock Planting Tool",
		description = "Complete berry-gathering objectives to unlock planting.",
		category = "unlock",
		stage = 4,
		requirements = {
			{ type = "objective_completed", id = "gather_heal_berries" },
			{ type = "objective_completed", id = "gather_revive_berries" },
		},
		rewards = {
			{ type = "unlock_tool", key = "berry_planter", amount = 1 },
			{ type = "unlock_feature", key = "planter_tool" },
		},
		visibility = { prerequisiteIds = { "gather_revive_berries" } },
	},
	level_up_pet = {
		id = "level_up_pet",
		label = "Level Up Your Pet",
		description = "Reach pet level 2.",
		category = "tutorial",
		stage = 5,
		requirements = {
			{ type = "pet_level_min", level = 2 },
		},
		rewards = {},
		visibility = { prerequisiteIds = { "unlock_planting_tool" } },
	},
	unlock_building_tool = {
		id = "unlock_building_tool",
		label = "Unlock Building Tool",
		description = "Complete pet progression objective to unlock building.",
		category = "unlock",
		stage = 6,
		requirements = {
			{ type = "objective_completed", id = "level_up_pet" },
		},
		rewards = {
			{ type = "unlock_tool", key = "node_demolisher", amount = 1 },
			{ type = "unlock_feature", key = "building_tool" },
		},
		visibility = { prerequisiteIds = { "level_up_pet" } },
	},
}

ObjectiveConfig.Order = {
	"choose_starter",
	"gather_heal_berries",
	"gather_revive_berries",
	"unlock_planting_tool",
	"level_up_pet",
	"unlock_building_tool",
}

return ObjectiveConfig
