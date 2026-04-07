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
		materials = {
			fiber = 0, wood = 0, stone = 0, meat = 0, battery_seed = 0,
			red = 0, yellow = 0, blue = 0,
			berry_red = 0, berry_yellow = 0, berry_blue = 0,
			revive_berry = 0, replenish_berry = 0,
			lure_meat = 0, crystal_shard = 0, water_glob = 0,
		},
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
		isDefeated = false,
		moveset = table.clone(def.moveset),
		familyKey = def.familyKey,
		compositeKey = def.compositeKey,
		outerCompositeKey = def.outerCompositeKey or def.compositeKey,
		innerCompositeKey = def.innerCompositeKey or def.compositeKey,
	}
end


function PlayerDataService:createOwnedFromRuntime(creature)
	local def = SpeciesConfig[creature.speciesKey]
	local id = nextOwnedId
	nextOwnedId += 1
	local moveset = table.clone((creature.moveset and #creature.moveset > 0) and creature.moveset or (def and def.moveset) or { "ram" })
	return {
		ownedId = id,
		speciesKey = creature.speciesKey,
		nickname = (def and def.name) or creature.speciesKey,
		level = math.max(1, math.floor(tonumber(creature.level) or 1)),
		xp = 0,
		morphPoints = math.max(0, math.floor(tonumber(creature.morphPoints) or 0)),
		isDefeated = false,
		moveset = moveset,
		familyKey = creature.familyKey or (def and def.familyKey),
		compositeKey = creature.compositeKey or (def and def.compositeKey),
		outerCompositeKey = creature.outerCompositeKey or (def and (def.outerCompositeKey or def.compositeKey)),
		innerCompositeKey = creature.innerCompositeKey or (def and (def.innerCompositeKey or def.compositeKey)),
		capturedFrom = {
			speciesKey = creature.speciesKey,
			wildTier = creature.wildTier,
			capturedAt = os.clock(),
		},
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

function PlayerDataService:getFirstOpenPartySlot(player)
	local data = self:getOrCreate(player)
	for slot = 1, 2 do
		if data.partySlots[slot] == nil then
			return slot
		end
	end
	return nil
end

function PlayerDataService:addOwnedCreature(player, speciesKey)
	local data = self:getOrCreate(player)
	local owned = self:createOwnedCreature(speciesKey)
	data.ownedCreatures[owned.ownedId] = owned
	local openSlot = self:getFirstOpenPartySlot(player)
	if openSlot then
		data.partySlots[openSlot] = owned.ownedId
		return owned, "party", openSlot
	end
	table.insert(data.reserve, owned.ownedId)
	return owned, "reserve", #data.reserve
end


function PlayerDataService:addOwnedFromRuntime(player, runtimeCreature)
	if not runtimeCreature then
		return nil, "invalid runtime creature"
	end
	local data = self:getOrCreate(player)
	local owned = self:createOwnedFromRuntime(runtimeCreature)
	data.ownedCreatures[owned.ownedId] = owned
	local openSlot = self:getFirstOpenPartySlot(player)
	if openSlot then
		data.partySlots[openSlot] = owned.ownedId
		return owned, "party", openSlot
	end
	table.insert(data.reserve, owned.ownedId)
	return owned, "reserve", #data.reserve
end

function PlayerDataService:setOwnedDefeated(player, ownedId, isDefeated)
	local data = self:getOrCreate(player)
	local owned = data.ownedCreatures[ownedId]
	if not owned then return false end
	owned.isDefeated = isDefeated and true or false
	return true
end

function PlayerDataService:revivePartySlots(player)
	local data = self:getOrCreate(player)
	for slot = 1, 2 do
		local ownedId = data.partySlots[slot]
		local owned = ownedId and data.ownedCreatures[ownedId] or nil
		if owned then
			owned.isDefeated = false
		end
	end
	return true
end

function PlayerDataService:revivePartySlot(player, slot)
	local data = self:getOrCreate(player)
	if slot < 1 or slot > 2 then return false end
	local ownedId = data.partySlots[slot]
	local owned = ownedId and data.ownedCreatures[ownedId] or nil
	if not owned then return false end
	owned.isDefeated = false
	return true
end

function PlayerDataService:addOwnedXP(player, ownedId, amount)
	local data = self:getOrCreate(player)
	local owned = data.ownedCreatures[ownedId]
	if not owned then
		return false, "owned creature not found"
	end
	local gained = math.max(0, math.floor(amount or 0))
	if gained <= 0 then
		return true, { gained = 0, levelUps = 0, level = owned.level }
	end
	owned.xp = (owned.xp or 0) + gained
	owned.level = owned.level or 1
	local levelUps = 0
	while true do
		local needed = math.max(15, owned.level * 25)
		if owned.xp < needed then break end
		owned.xp -= needed
		owned.level += 1
		levelUps += 1
	end
	return true, { gained = gained, levelUps = levelUps, level = owned.level, xp = owned.xp }
end

return PlayerDataService
