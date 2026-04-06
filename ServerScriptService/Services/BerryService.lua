local BerryService = {}
BerryService.__index = BerryService

local VALID_BERRIES = {
	red = true,
	yellow = true,
	blue = true,
}

function BerryService.new(worldService, inventoryService, creatureService, playerDataService)
	return setmetatable({
		worldService = worldService,
		inventoryService = inventoryService,
		creatureService = creatureService,
		playerDataService = playerDataService,
	}, BerryService)
end

function BerryService:findFirstAlivePartyPet(player)
	for _, c in ipairs(self.worldService.creatures) do
		if c.ownerUserId == player.UserId and c.mode == "pet" and c.alive then
			return c
		end
	end
	return nil
end

function BerryService:hasAnyDefeatedSlot(player)
	local data = self.playerDataService:getOrCreate(player)
	for slot = 1, 2 do
		local ownedId = data.partySlots[slot]
		if ownedId and (not self.worldService:getRuntimeCreatureForOwnedId(player.UserId, ownedId)) then
			return true
		end
	end
	return false
end

function BerryService:applyBerryEffect(player, kind)
	local pet = self:findFirstAlivePartyPet(player)
	if kind == "red" then
		if pet then
			local maxHp = pet.modifiedStats.maxHP or 0
			local heal = math.max(1, math.floor(maxHp * 0.35 + 0.5))
			pet.currentHP = math.min(maxHp, (pet.currentHP or 0) + heal)
			self.worldService:pushFloatingText(pet.pos, "+" .. tostring(heal) .. " HP", "#a8ffd7")
		end
		self.worldService:pushEventLog(player, "Used Red Berry", "#a8ffd7")
		return true
	elseif kind == "yellow" then
		if pet then
			local stMax = pet.modifiedStats.stamina or pet.currentStamina or 0
			local enMax = pet.modifiedStats.energy or pet.currentEnergy or 0
			pet.currentStamina = math.min(stMax, (pet.currentStamina or 0) + 10)
			pet.currentEnergy = math.min(enMax, (pet.currentEnergy or 0) + 10)
			self.worldService:pushFloatingText(pet.pos, "+ST/EN", "#ffe7a8")
		end
		self.worldService:pushEventLog(player, "Used Yellow Berry", "#ffe7a8")
		return true
	elseif kind == "blue" then
		if self:hasAnyDefeatedSlot(player) then
			self.playerDataService:revivePartySlots(player)
			self.creatureService:respawnPartyFromOwned(player)
			self.worldService:pushEventLog(player, "Used Blue Berry (party revived)", "#9fd3ff")
			return true
		end
		self.worldService:pushEventLog(player, "Used Blue Berry (no defeated party pet)", "#9fd3ff")
		return true
	end
	return false
end

function BerryService:tryUseBerry(player, kind)
	if not VALID_BERRIES[kind] then
		return false, "invalid berry"
	end
	local ok = self.inventoryService:tryConsume(player, kind, 1)
	if not ok then
		return false, "no berry"
	end
	return self:applyBerryEffect(player, kind)
end

return BerryService
