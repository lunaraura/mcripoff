local MorphService = {}
MorphService.__index = MorphService

function MorphService.new(playerDataService)
	return setmetatable({ playerDataService = playerDataService }, MorphService)
end

function MorphService:awardPoints(player, amount)
	local data = self.playerDataService:getOrCreate(player)
	data.morphPoints += math.max(0, amount)
end

function MorphService:tryMorph(player, ownedId, targetSpecies)
	-- TODO: Implement full morph path checks and species evolution graph.
	return false, "Not implemented in vertical slice"
end

return MorphService
