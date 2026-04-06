local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local ALLOWED_STARTERS = {
	dog = true,
	sparkit = true,
	cinderpup = true,
	pebblit = true,
}

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
		materials = { fiber = 0, stone = 0, meat = 0, battery_seed = 0, red = 0, yellow = 0, blue = 0 },
		morphPoints = 0,
		selectedPetSlot = 1,
		starterChosen = false,
	}
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

function PlayerDataService:getPartyOwned(player, slot)
	local data = self:getOrCreate(player)
	local ownedId = data.partySlots[slot]
	if not ownedId then return nil end
	return data.ownedCreatures[ownedId]
end

function PlayerDataService:hasAnyOwned(player)
	local data = self:getOrCreate(player)
	for _, owned in pairs(data.ownedCreatures) do
		if owned then return true end
	end
	return false
end

function PlayerDataService:canChooseStarter(player)
	local data = self:getOrCreate(player)
	if data.starterChosen then return false, "starter already chosen" end
	if self:hasAnyOwned(player) then return false, "owned creatures already exist" end
	return true, "ok"
end

function PlayerDataService:chooseStarter(player, speciesKey)
	local ok, reason = self:canChooseStarter(player)
	if not ok then return false, reason end
	if not ALLOWED_STARTERS[speciesKey] then
		return false, "invalid starter choice"
	end
	local data = self:getOrCreate(player)
	local starter = self:createOwnedCreature(speciesKey)
	data.ownedCreatures[starter.ownedId] = starter
	data.partySlots[1] = starter.ownedId
	data.partySlots[2] = nil
	data.starterChosen = true
	return true, starter
end

function PlayerDataService:swapPartyWithReserve(player, partySlot, reserveIndex)
	local data = self:getOrCreate(player)
	if partySlot < 1 or partySlot > 2 then
		return false, "invalid party slot"
	end
	local reserveId = data.reserve[reserveIndex]
	if not reserveId then
		return false, "invalid reserve index"
	end
	local oldPartyId = data.partySlots[partySlot]
	data.partySlots[partySlot] = reserveId
	data.reserve[reserveIndex] = oldPartyId
	return true, "swapped"
end

function PlayerDataService:getReserveList(player)
	local data = self:getOrCreate(player)
	local out = {}
	for i, ownedId in ipairs(data.reserve) do
		local owned = data.ownedCreatures[ownedId]
		if owned then
			out[i] = { reserveIndex = i, ownedId = owned.ownedId, speciesKey = owned.speciesKey, nickname = owned.nickname }
		end
	end
	return out
end

return PlayerDataService
