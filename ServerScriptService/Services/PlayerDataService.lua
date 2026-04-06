local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpeciesConfig = require(ReplicatedStorage.Shared.Config.SpeciesConfig)

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

function PlayerDataService.new()
	return setmetatable({ dataByUserId = {} }, PlayerDataService)
end

function PlayerDataService:getOrCreate(player)
	local data = self.dataByUserId[player.UserId]
	if data then return data end
	data = {
		ownedCreatures = {},
		partySlots = { nil, nil }, -- 2 active pets
		reserve = {},
		materials = { fiber = 0, stone = 0, meat = 0, battery_seed = 0 },
		morphPoints = 0,
		selectedPetSlot = 1,
	}
	local starterA = self:createOwnedCreature("dog")
	local starterB = self:createOwnedCreature("sparko")
	data.ownedCreatures[starterA.ownedId] = starterA
	data.ownedCreatures[starterB.ownedId] = starterB
	data.partySlots[1] = starterA.ownedId
	data.partySlots[2] = starterB.ownedId
	self.dataByUserId[player.UserId] = data
	return data
end

local nextOwnedId = 1
function PlayerDataService:createOwnedCreature(speciesKey)
	local def = SpeciesConfig[speciesKey]
	local id = nextOwnedId
	nextOwnedId += 1
	return {
		ownedId = id,
		speciesKey = speciesKey,
		nickname = def.name,
		level = 1,
		xp = 0,
		morphPoints = 0,
		moveset = table.clone(def.moveset),
		familyKey = def.familyKey,
		compositeKey = def.compositeKey,
	}
end

return PlayerDataService
