local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))

local MoveProgression = {}

local function pushUnique(out, seen, abilityKey)
	if type(abilityKey) ~= "string" or abilityKey == "" then
		return
	end
	if seen[abilityKey] then
		return
	end
	seen[abilityKey] = true
	table.insert(out, abilityKey)
end

function MoveProgression.getLearnedMoves(speciesKey, level, maxMoves)
	local def = SpeciesConfig[speciesKey]
	if not def then
		return { "ram" }
	end
	local out = {}
	local seen = {}
	local boundedLevel = math.max(1, math.floor(tonumber(level) or 1))
	for _, entry in ipairs(def.learnset or {}) do
		local learnLevel = math.max(1, math.floor(tonumber(entry.level) or 1))
		if learnLevel <= boundedLevel then
			pushUnique(out, seen, entry.move or entry.ability)
		end
	end
	if #out == 0 then
		for _, legacyMove in ipairs(def.moveset or {}) do
			pushUnique(out, seen, legacyMove)
		end
	end
	if #out == 0 then
		pushUnique(out, seen, "ram")
	end
	local cap = math.max(1, math.floor(tonumber(maxMoves) or 4))
	while #out > cap do
		table.remove(out, 1)
	end
	return out
end

return MoveProgression
