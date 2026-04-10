local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))
local FamilyConfig = require(Config:WaitForChild("FamilyConfig"))
local Creatures = Shared:WaitForChild("Creatures")
local MoveProgression = require(Creatures:WaitForChild("MoveProgression"))
local StatProgression = require(Creatures:WaitForChild("StatProgression"))

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


local function defaultFamilyKey(owned)
	local def = owned and SpeciesConfig[owned.speciesKey]
	return (owned and owned.familyKey) or (def and def.familyKey) or "canine"
end

local function ensureOwnedStatLayers(owned)
	if not owned then return end
	if not FamilyConfig[owned.familyKey or ""] then
		owned.familyKey = defaultFamilyKey(owned)
	end
	owned.rollStats = StatProgression.sanitizeLayer(owned.rollStats)
	owned.growthStats = StatProgression.sanitizeLayer(owned.growthStats)
	if (not owned.rollStatsInitialized) then
		owned.rollStats = StatProgression.generateRollStats(owned.speciesKey, owned.ownedId)
		owned.rollStatsInitialized = true
	end
end

local nextOwnedId = 1
function PlayerDataService:createOwnedCreature(speciesKey)
	local def = SpeciesConfig[speciesKey]
	local id = nextOwnedId
	nextOwnedId += 1
	local owned = {
		ownedId = id,
		speciesKey = speciesKey,
		nickname = def.name,
		level = 1,
		xp = 0,
		morphPoints = 0,
		isDefeated = false,
		abilities = table.clone(def.abilities or {}),
		moveset = MoveProgression.getLearnedMoves(speciesKey, 1),
		familyKey = def.familyKey,
		compositeKey = def.compositeKey,
		outerCompositeKey = def.outerCompositeKey or def.compositeKey,
		innerCompositeKey = def.innerCompositeKey or def.compositeKey,
		rollStats = StatProgression.generateRollStats(speciesKey, id),
		growthStats = StatProgression.zeroLayer(),
		rollStatsInitialized = true,
	}
	return owned
end


function PlayerDataService:createOwnedFromRuntime(creature)
	local def = SpeciesConfig[creature.speciesKey]
	local id = nextOwnedId
	nextOwnedId += 1
	local level = math.max(1, math.floor(tonumber(creature.level) or 1))
	local defaultMoveset = MoveProgression.getLearnedMoves(creature.speciesKey, level)
	local moveset = table.clone((creature.moveset and #creature.moveset > 0) and creature.moveset or defaultMoveset)
	local owned = {
		ownedId = id,
		speciesKey = creature.speciesKey,
		nickname = (def and def.name) or creature.speciesKey,
		level = level,
		xp = 0,
		morphPoints = math.max(0, math.floor(tonumber(creature.morphPoints) or 0)),
		isDefeated = false,
		abilities = table.clone((def and def.abilities) or {}),
		moveset = moveset,
		familyKey = creature.familyKey or (def and def.familyKey),
		compositeKey = creature.compositeKey or (def and def.compositeKey),
		outerCompositeKey = creature.outerCompositeKey or (def and (def.outerCompositeKey or def.compositeKey)),
		innerCompositeKey = creature.innerCompositeKey or (def and (def.innerCompositeKey or def.compositeKey)),
		rollStats = StatProgression.sanitizeLayer(creature.rollStats),
		growthStats = StatProgression.sanitizeLayer(creature.growthStats),
		rollStatsInitialized = creature.rollStats ~= nil,
		capturedFrom = {
			speciesKey = creature.speciesKey,
			wildTier = creature.wildTier,
			capturedAt = os.clock(),
		},
	}
	ensureOwnedStatLayers(owned)
	return owned
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


local function compactReserve(data)
	local cleaned = {}
	for _, ownedId in ipairs(data.reserve or {}) do
		if ownedId then
			table.insert(cleaned, ownedId)
		end
	end
	data.reserve = cleaned
end

function PlayerDataService:findOwnedLocation(player, ownedId)
	local data = self:getOrCreate(player)
	local id = tonumber(ownedId)
	if not id then return nil, nil end
	for slot = 1, 2 do
		if tonumber(data.partySlots[slot]) == id then
			return "party", slot
		end
	end
	for reserveIndex, reserveId in ipairs(data.reserve) do
		if tonumber(reserveId) == id then
			return "reserve", reserveIndex
		end
	end
	return nil, nil
end

function PlayerDataService:swapPartySlots(player, slotA, slotB)
	local data = self:getOrCreate(player)
	slotA = tonumber(slotA)
	slotB = tonumber(slotB)
	if slotA ~= 1 and slotA ~= 2 then return false, "invalid slotA" end
	if slotB ~= 1 and slotB ~= 2 then return false, "invalid slotB" end
	if slotA == slotB then return true, "noop" end
	data.partySlots[slotA], data.partySlots[slotB] = data.partySlots[slotB], data.partySlots[slotA]
	return true, "swapped"
end

function PlayerDataService:moveOwnedToReserve(player, ownedId)
	local data = self:getOrCreate(player)
	local location, idx = self:findOwnedLocation(player, ownedId)
	if location ~= "party" then
		return false, "owned not in party"
	end
	local movingId = data.partySlots[idx]
	if not movingId then
		return false, "party slot empty"
	end
	data.partySlots[idx] = nil
	table.insert(data.reserve, movingId)
	compactReserve(data)
	return true, "moved_to_reserve", idx
end

function PlayerDataService:moveOwnedToParty(player, ownedId, targetSlot)
	local data = self:getOrCreate(player)
	local location, idx = self:findOwnedLocation(player, ownedId)
	if not location then
		return false, "owned not found"
	end
	if location == "party" then
		if targetSlot and tonumber(targetSlot) and tonumber(targetSlot) ~= idx then
			return self:swapPartySlots(player, idx, tonumber(targetSlot))
		end
		return true, "already_in_party", idx
	end

	local slot = tonumber(targetSlot)
	if slot and slot ~= 1 and slot ~= 2 then
		return false, "invalid target slot"
	end
	if not slot then
		slot = self:getFirstOpenPartySlot(player)
		if not slot then
			return false, "party_full"
		end
	end
	local movingId = data.reserve[idx]
	if not movingId then
		return false, "invalid reserve index"
	end
	local replacedId = data.partySlots[slot]
	data.partySlots[slot] = movingId
	table.remove(data.reserve, idx)
	if replacedId then
		table.insert(data.reserve, replacedId)
	end
	compactReserve(data)
	return true, replacedId and "swapped_into_party" or "moved_to_party", slot
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
	ensureOwnedStatLayers(owned)
	local gained = math.max(0, math.floor(amount or 0))
	if gained <= 0 then
		return true, { gained = 0, levelUps = 0, level = owned.level }
	end
	owned.xp = (owned.xp or 0) + gained
	owned.level = owned.level or 1
	local startLevel = owned.level
	local levelUps = 0
	while true do
		local needed = math.max(15, owned.level * 25)
		if owned.xp < needed then break end
		owned.xp -= needed
		owned.level += 1
		levelUps += 1
	end
	local def = SpeciesConfig[owned.speciesKey]
	local growthGains = StatProgression.zeroLayer()
	if levelUps > 0 then
		owned.growthStats, growthGains = StatProgression.applyLevelGrowth(
			owned.growthStats,
			owned.familyKey or (def and def.familyKey) or "canine",
			startLevel,
			owned.level,
			owned.ownedId,
			owned.speciesKey
		)
	end
	owned.abilities = table.clone((def and def.abilities) or owned.abilities or {})
	owned.moveset = MoveProgression.getLearnedMoves(owned.speciesKey, owned.level)
	return true, {
		gained = gained,
		levelUps = levelUps,
		level = owned.level,
		xp = owned.xp,
		moveset = owned.moveset,
		growthGains = growthGains,
		growthStats = owned.growthStats,
	}
end

return PlayerDataService
