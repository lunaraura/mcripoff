local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local FamilyConfig = require(Config:WaitForChild("FamilyConfig"))

local StatProgression = {}

StatProgression.CORE_STAT_KEYS = { "maxHP", "pAtk", "eAtk", "spd", "stamina", "energy" }
StatProgression.DEFAULT_GROWTH_WEIGHTS = {
	maxHP = 1,
	pAtk = 1,
	eAtk = 1,
	spd = 1,
	stamina = 1,
	energy = 1,
}
StatProgression.BASE_GROWTH_GAINS = {
	maxHP = 4,
	pAtk = 1,
	eAtk = 1,
	spd = 1,
	stamina = 1,
	energy = 1,
}

local function hashString(str)
	local hash = 2166136261
	for i = 1, #str do
		hash = bit32.bxor(hash, string.byte(str, i))
		hash = (hash * 16777619) % 2147483647
	end
	return hash
end

local function seedFor(speciesKey, creatureId, salt)
	local speciesHash = hashString(tostring(speciesKey or "unknown"))
	local idComponent = math.floor(tonumber(creatureId) or 0) * 131
	return (speciesHash + idComponent + (salt or 0) * 977) % 2147483647
end

local function weightedPick(weights, rng)
	local total = 0
	for _, statKey in ipairs(StatProgression.CORE_STAT_KEYS) do
		local w = tonumber(weights[statKey]) or 0
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return "maxHP"
	end
	local roll = rng:NextNumber(0, total)
	local cursor = 0
	for _, statKey in ipairs(StatProgression.CORE_STAT_KEYS) do
		local w = tonumber(weights[statKey]) or 0
		if w > 0 then
			cursor += w
			if roll <= cursor then
				return statKey
			end
		end
	end
	return "maxHP"
end

function StatProgression.zeroLayer()
	local out = {}
	for _, statKey in ipairs(StatProgression.CORE_STAT_KEYS) do
		out[statKey] = 0
	end
	return out
end

function StatProgression.sanitizeLayer(layer)
	local out = StatProgression.zeroLayer()
	for _, statKey in ipairs(StatProgression.CORE_STAT_KEYS) do
		out[statKey] = math.max(0, tonumber(layer and layer[statKey]) or 0)
	end
	return out
end

function StatProgression.mergeAdditiveLayer(targetStats, additiveLayer)
	if not targetStats then return end
	for _, statKey in ipairs(StatProgression.CORE_STAT_KEYS) do
		if targetStats[statKey] ~= nil then
			targetStats[statKey] += tonumber(additiveLayer and additiveLayer[statKey]) or 0
		end
	end
end

function StatProgression.getFamilyGrowthWeights(familyKey)
	local family = FamilyConfig[familyKey]
	if family and family.growthWeights then
		return family.growthWeights
	end
	return StatProgression.DEFAULT_GROWTH_WEIGHTS
end

function StatProgression.generateRollStats(speciesKey, creatureId)
	local rng = Random.new(seedFor(speciesKey, creatureId, 11))
	return {
		maxHP = rng:NextInteger(0, 6),
		pAtk = rng:NextInteger(0, 2),
		eAtk = rng:NextInteger(0, 2),
		spd = rng:NextInteger(0, 1),
		stamina = rng:NextInteger(0, 2),
		energy = rng:NextInteger(0, 2),
	}
end

function StatProgression.applyLevelGrowth(growthStats, familyKey, oldLevel, newLevel, creatureId, speciesKey)
	local outGrowth = StatProgression.sanitizeLayer(growthStats)
	local gains = StatProgression.zeroLayer()
	local startLevel = math.max(1, math.floor(tonumber(oldLevel) or 1))
	local finalLevel = math.max(startLevel, math.floor(tonumber(newLevel) or startLevel))
	if finalLevel <= startLevel then
		return outGrowth, gains
	end

	local weights = StatProgression.getFamilyGrowthWeights(familyKey)
	for level = startLevel + 1, finalLevel do
		local rng = Random.new(seedFor(speciesKey, creatureId, level))
		local statKey = weightedPick(weights, rng)
		local gain = StatProgression.BASE_GROWTH_GAINS[statKey] or 0
		outGrowth[statKey] += gain
		gains[statKey] += gain
	end

	return outGrowth, gains
end

return StatProgression
