local HarvestConfig = {}

HarvestConfig.toolDefs = {
	node_demolisher = {
		label = "Node Demolisher",
		mode = "destroy",
		allowedNodeTypes = {
			tree = true,
			rock = true,
			ore = true,
			crystal = true,
		},
	},
	berry_planter = {
		label = "Berry Planter",
		mode = "gather_tool",
		allowedBerryKinds = {
			berry_red = true,
			berry_yellow = true,
			berry_blue = true,
			revive_berry = true,
			replenish_berry = true,
		},
	},
}

HarvestConfig.obstacleHarvestDefs = {
	tree = {
		label = "Tree",
		defaultDurability = 4,
		dropKey = "wood",
		dropAmount = 2,
		gatherTime = 0.35,
	},
	rock = {
		label = "Rock",
		defaultDurability = 3,
		dropKey = "stone",
		dropAmount = 2,
		gatherTime = 0.35,
	},
	ore = {
		label = "Ore",
		defaultDurability = 4,
		dropKey = "stone",
		dropAmount = 3,
		gatherTime = 0.45,
	},
	crystal = {
		label = "Crystal",
		defaultDurability = 5,
		dropKey = "battery_seed",
		dropAmount = 2,
		gatherTime = 0.45,
	},
}

function HarvestConfig.getObstacleDef(nodeType)
	local key = string.lower(tostring(nodeType or ""))
	return HarvestConfig.obstacleHarvestDefs[key]
end

function HarvestConfig.getToolDef(toolKey)
	return HarvestConfig.toolDefs[tostring(toolKey or "")]
end

return HarvestConfig
