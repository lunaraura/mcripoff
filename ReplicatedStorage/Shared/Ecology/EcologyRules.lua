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

local function pickTierFromWeights(weights)
	local wSmall = tonumber(weights.small) or 0
	local wNormal = tonumber(weights.normal) or 0
	local wBig = tonumber(weights.big) or 0
	local total = wSmall + wNormal + wBig
	if total <= 0 then
		return "normal", EcologyConfig.spawn.tiers.normal
	end
	local r = math.random() * total
	if r < wSmall then return "small", EcologyConfig.spawn.tiers.small end
	if r < (wSmall + wNormal) then return "normal", EcologyConfig.spawn.tiers.normal end
	return "big", EcologyConfig.spawn.tiers.big
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
	return pickTierFromWeights({
		small = EcologyConfig.spawn.tiers.small.weight,
		normal = EcologyConfig.spawn.tiers.normal.weight,
		big = EcologyConfig.spawn.tiers.big.weight,
	})
end

function EcologyRules.pickTierAtTime(timeOfDayNormalized)
	local weights = {
		small = EcologyConfig.spawn.tiers.small.weight,
		normal = EcologyConfig.spawn.tiers.normal.weight,
		big = EcologyConfig.spawn.tiers.big.weight,
	}
	local nightCfg = EcologyConfig.spawn.night or {}
	local isNight = (timeOfDayNormalized or 0) >= 0.75 or (timeOfDayNormalized or 0) < 0.25
	if isNight then
		local mults = nightCfg.tierWeightMultipliers or {}
		weights.small *= tonumber(mults.small) or 1
		weights.normal *= tonumber(mults.normal) or 1
		weights.big *= tonumber(mults.big) or 1
	end
	return pickTierFromWeights(weights)
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

function EcologyRules.pickWildVariant(timeOfDayNormalized)
	local variants = EcologyConfig.spawn.variants or {}
	local entries = {}
	local nightCfg = EcologyConfig.spawn.night or {}
	local isNight = (timeOfDayNormalized or 0) >= 0.75 or (timeOfDayNormalized or 0) < 0.25
	local chanceMult = isNight and (tonumber(nightCfg.variantChanceMult) or 1) or 1
	for variantKey, cfg in pairs(variants) do
		table.insert(entries, {
			key = variantKey,
			weight = (tonumber(cfg.weight) or 0) * chanceMult,
		})
	end
	table.sort(entries, function(a, b) return a.key < b.key end)
	local picked = MathUtil.pickWeighted(entries)
	if not picked then return nil, nil end
	return picked, variants[picked]
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
