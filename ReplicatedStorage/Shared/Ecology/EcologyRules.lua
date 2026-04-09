local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local EcologyConfig = require(Config:WaitForChild("EcologyConfig"))
local MathUtil = require(Util:WaitForChild("MathUtil"))

local EcologyRules = {}
EcologyRules.Reason = EcologyConfig.reasonCodes

local function mergedMultipliers(a, b)
	local out = {}
	for k, v in pairs(a or {}) do out[k] = v end
	for k, v in pairs(b or {}) do out[k] = (out[k] or 1) * v end
	return out
end

function EcologyRules.normalizeCell(cell)
	cell.yGround = cell.yGround or cell.yG or 0
	cell.yWater = cell.yWater or cell.yW or 0
	cell.terrainClass = cell.terrainClass or (cell.water and "water" or (cell.blocked and "rock" or "ground"))
	cell.flags = cell.flags or {}
	cell.flags.spawnable = (EcologyConfig.terrainClasses[cell.terrainClass] and EcologyConfig.terrainClasses[cell.terrainClass].spawnable) or false
	cell.flags.nodeable = (EcologyConfig.terrainClasses[cell.terrainClass] and EcologyConfig.terrainClasses[cell.terrainClass].node) or false
	cell.flags.obstacleable = (EcologyConfig.terrainClasses[cell.terrainClass] and EcologyConfig.terrainClasses[cell.terrainClass].obstacle) or false
	cell.flags.floraable = (EcologyConfig.terrainClasses[cell.terrainClass] and EcologyConfig.terrainClasses[cell.terrainClass].flora) or false
	cell.spawnable = cell.flags.spawnable
	cell.nodeable = cell.flags.nodeable
	return cell
end

function EcologyRules.canHostSpawn(cell)
	cell = EcologyRules.normalizeCell(cell)
	if not cell.spawnable then return false, EcologyRules.Reason.SPAWN_TERRAIN end
	return true
end

function EcologyRules.canHostNode(cell)
	cell = EcologyRules.normalizeCell(cell)
	if not cell.flags.nodeable then return false, EcologyRules.Reason.ECOLOGY_BLOCKED end
	return true
end

function EcologyRules.pickTier()
	local r = math.random()
	local wSmall = EcologyConfig.spawn.tiers.small.weight
	local wNormal = EcologyConfig.spawn.tiers.normal.weight
	if r < wSmall then return "small", EcologyConfig.spawn.tiers.small end
	if r < wSmall + wNormal then return "normal", EcologyConfig.spawn.tiers.normal end
	return "big", EcologyConfig.spawn.tiers.big
end

function EcologyRules.pickArchetype(biomeKey)
	local weights = EcologyConfig.spawn.biomeArchetypeWeights[biomeKey] or EcologyConfig.spawn.biomeArchetypeWeights.plains
	local entries = {}
	for k, w in pairs(weights) do table.insert(entries, { key = k, weight = w }) end
	table.sort(entries, function(a, b) return a.key < b.key end)
	local key = MathUtil.pickWeighted(entries) or "skirmisher"
	return key, EcologyConfig.spawn.archetypes[key]
end

function EcologyRules.buildSpawnProfile(point, tierKey, tierCfg)
	local archeKey, archeCfg = EcologyRules.pickArchetype(point.biomeKey)
	return {
		archetypeKey = archeKey,
		tierKey = tierKey,
		team = tierCfg.team,
		statMult = mergedMultipliers(tierCfg.statMult, archeCfg.statMult),
		sizeMult = (tierCfg.sizeMult or 1) * (archeCfg.sizeMult or 1),
		timidness = (tierCfg.timidness or 1),
		commitment = (tierCfg.commitment or 1),
		aggroMult = tierCfg.aggroMult,
		pursuitRange = tierCfg.pursuitRange,
		targetNearPlayerBias = tierCfg.targetNearPlayerBias,
		abilityPool = archeCfg.abilityPool,
		abilitySlots = archeCfg.abilitySlots,
	}
end

function EcologyRules.getSpawnSettings()
	return EcologyConfig.spawn
end

function EcologyRules.getNodeCategory(nodeType)
	return EcologyConfig.nodeCategories[nodeType] or "generic_node"
end

function EcologyRules.getNodeLifecyclePolicy(lifecycleClass)
	local policies = EcologyConfig.nodeLifecyclePolicies or {}
	return policies[lifecycleClass] or policies.natural_non_respawn or {
		respawnPolicy = "none",
		playerGrowable = false,
		harvestable = true,
	}
end

function EcologyRules.classifyNodeLifecycle(nodeType, nodeSource)
	if nodeSource == "player" then
		return "player_growable"
	end
	local map = EcologyConfig.nodeTypeLifecycleClass or {}
	return map[nodeType] or "natural_non_respawn"
end

return EcologyRules
