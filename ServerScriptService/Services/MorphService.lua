local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))

local MorphService = {}
MorphService.__index = MorphService

function MorphService.new(playerDataService)
	return setmetatable({ playerDataService = playerDataService }, MorphService)
end

function MorphService:awardPoints(player, ownedId, amount)
	local data = self.playerDataService:getOrCreate(player)
	local owned = data.ownedCreatures[ownedId]
	if not owned then
		return false, "owned creature not found"
	end
	owned.morphPoints = math.max(0, (owned.morphPoints or 0) + math.max(0, amount or 0))
	return true, owned.morphPoints
end

function MorphService:tryMorph(player, ownedId, targetSpecies)
	local data = self.playerDataService:getOrCreate(player)
	local owned = data.ownedCreatures[ownedId]
	local fromDef = owned and SpeciesConfig[owned.speciesKey] or nil
	local targetDef = SpeciesConfig[targetSpecies]
	if not owned then return false, "owned creature not found" end
	if not targetDef then return false, "target species not found" end
	local option = nil
	for _, opt in ipairs(fromDef and fromDef.morphOptions or {}) do
		if opt.option == targetSpecies then
			option = opt
			break
		end
	end
	if not option then
		return false, "invalid morph option"
	end
	local needed = option.pointsNeeded or 0
	if (owned.morphPoints or 0) < needed then
		return false, string.format("need %d morph points", needed)
	end
	owned.morphPoints = math.max(0, (owned.morphPoints or 0) - needed)
	owned.speciesKey = targetSpecies
	owned.familyKey = targetDef.familyKey
	owned.compositeKey = targetDef.compositeKey
	owned.moveset = table.clone(targetDef.moveset or {})
	-- TODO: add biome/path/lineage constraints when evolution graph is authored.
	return true, owned
end

return MorphService
