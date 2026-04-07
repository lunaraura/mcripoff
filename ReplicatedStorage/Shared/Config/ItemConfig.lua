local ItemConfig = {
	berry_red = {
		label = "Red Berry",
		aliases = { "red" },
		itemType = "consumable",
		targeting = "ally_alive",
		useCooldown = 0.35,
		effect = { kind = "heal", hpFlat = 40 },
	},
	berry_yellow = {
		label = "Yellow Berry",
		aliases = { "yellow" },
		itemType = "consumable",
		targeting = "ally_alive",
		useCooldown = 0.35,
		effect = { kind = "heal", hpFlat = 30 },
	},
	replenish_berry = {
		label = "Replenish Berry",
		aliases = { "berry_blue" },
		itemType = "consumable",
		targeting = "ally_alive",
		useCooldown = 0.35,
		effect = { kind = "restore", staminaFlat = 20, energyFlat = 10 },
	},
	revive_berry = {
		label = "Revive Berry",
		aliases = { "blue" },
		itemType = "consumable",
		targeting = "ally_defeated",
		useCooldown = 0.5,
		effect = { kind = "revive", hpPercent = 0.5 },
	},
}

return ItemConfig
