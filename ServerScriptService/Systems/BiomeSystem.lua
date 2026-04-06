local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))

local BiomeSystem = {}

local BIOME_KEYS = {}
for key, _ in pairs(BiomeConfig) do
	table.insert(BIOME_KEYS, key)
end
table.sort(BIOME_KEYS)

local function clamp01(v)
	return math.max(0, math.min(1, v))
end

local function noise01(x, z, scale, seed)
	return 0.5 + 0.5 * math.noise((x + seed * 137) * scale, (z - seed * 97) * scale)
end

function BiomeSystem.sampleClimate(x, z)
	return {
		temperature = clamp01(noise01(x, z, 0.0018, 1)),
		rainfall = clamp01(noise01(x, z, 0.0017, 2)),
		lithosphere = clamp01(noise01(x, z, 0.0021, 3)),
		barrenness = clamp01(noise01(x, z, 0.0015, 4)),
		arcane = clamp01(noise01(x, z, 0.0012, 5)),
		softness = clamp01(noise01(x, z, 0.0023, 6)),
	}
end

function BiomeSystem.scoreBiome(rules, climate)
	local wTemp, wRain, wLitho = 1.00, 0.92, 0.76
	local wBarren, wArcane, wSoft = 0.74, 0.58, 0.64
	local d =
		math.abs((climate.temperature or 0.5) - (rules.temperature or 0.5)) * wTemp +
		math.abs((climate.rainfall or 0.5) - (rules.rainfall or 0.5)) * wRain +
		math.abs((climate.lithosphere or 0.5) - (rules.lithosphere or 0.5)) * wLitho +
		math.abs((climate.barrenness or 0.5) - (rules.barrenness or 0.5)) * wBarren +
		math.abs((climate.arcane or 0.5) - (rules.arcane or 0.5)) * wArcane +
		math.abs((climate.softness or 0.5) - (rules.softness or 0.5)) * wSoft
	local closeness = math.exp(-2.3 * d)
	return closeness * (rules.bias or 1)
end

function BiomeSystem.sample(x, z)
	local climate = BiomeSystem.sampleClimate(x, z)
	local bestKey, bestScore = "plains", -math.huge
	for _, biomeKey in ipairs(BIOME_KEYS) do
		local def = BiomeConfig[biomeKey]
		local score = BiomeSystem.scoreBiome(def.rules or {}, climate)
		if score > bestScore then
			bestScore = score
			bestKey = biomeKey
		end
	end
	return bestKey
end

function BiomeSystem.sampleEnvironment(x, z)
	local climate = BiomeSystem.sampleClimate(x, z)
	local biomeKey = BiomeSystem.sample(x, z)
	local heightNoise = noise01(x, z, 0.0044, 9)
	local rugged = (climate.lithosphere * 0.65) + ((1 - climate.softness) * 0.35)
	local wet = climate.rainfall * (1 - climate.barrenness * 0.45)
	local waterThreshold = 0.18 + (wet * 0.25) - (rugged * 0.14)
	local rockThreshold = 0.82 - (rugged * 0.21) + (climate.barrenness * 0.05)
	local terrainClass = "ground"
	if heightNoise <= waterThreshold then
		terrainClass = "water"
	elseif heightNoise >= rockThreshold then
		terrainClass = "rock"
	end
	return {
		biomeKey = biomeKey,
		climate = climate,
		terrainClass = terrainClass,
		heightNoise = heightNoise,
	}
end

function BiomeSystem.terrainClass(x, z)
	return BiomeSystem.sampleEnvironment(x, z).terrainClass
end

return BiomeSystem
