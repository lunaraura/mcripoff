local BerryService = {}
BerryService.__index = BerryService

local BERRY_ITEM_DEFS = {
	red = { canonical = "berry_red", type = "heal", amount = 40 },
	yellow = { canonical = "berry_yellow", type = "heal", amount = 30 },
	blue = { canonical = "revive_berry", type = "revive", amount = 0.5 }, -- backward-compat alias
	berry_red = { canonical = "berry_red", type = "heal", amount = 40 },
	berry_yellow = { canonical = "berry_yellow", type = "heal", amount = 30 },
	berry_blue = { canonical = "berry_blue", type = "heal", amount = 25 },
	revive_berry = { canonical = "revive_berry", type = "revive", amount = 0.5 },
	replenish_berry = { canonical = "replenish_berry", type = "energy", amount = 20 },
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

function BerryService:findAlivePartyPetBySlot(player, slot)
	local data = self.playerDataService:getOrCreate(player)
	local ownedId = data.partySlots[slot]
	if not ownedId then return nil end
	return self.worldService:getRuntimeCreatureForOwnedId(player.UserId, ownedId)
end

function BerryService:findDefeatedSlot(player, preferredSlot)
	local data = self.playerDataService:getOrCreate(player)
	if preferredSlot and preferredSlot >= 1 and preferredSlot <= 2 then
		local ownedId = data.partySlots[preferredSlot]
		local owned = ownedId and data.ownedCreatures[ownedId] or nil
		if owned and owned.isDefeated then
			return preferredSlot
		end
	end
	for slot = 1, 2 do
		local ownedId = data.partySlots[slot]
		local owned = ownedId and data.ownedCreatures[ownedId] or nil
		if owned and owned.isDefeated then
			return slot
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

function BerryService:applyBerryEffect(player, itemDef, targetSlot)
	local pet = nil
	if targetSlot then
		pet = self:findAlivePartyPetBySlot(player, targetSlot)
	end
	if not pet then
		pet = self:findFirstAlivePartyPet(player)
	end
	if itemDef.type == "heal" then
		if pet then
			local maxHp = pet.modifiedStats.maxHP or 0
			local heal = math.max(1, math.floor(itemDef.amount or 20))
			pet.currentHP = math.min(maxHp, (pet.currentHP or 0) + heal)
			self.worldService:pushFloatingText(pet.pos, "+" .. tostring(heal) .. " HP", "#a8ffd7")
		end
		self.worldService:pushEventLog(player, "Used heal berry", "#a8ffd7")
		return true
	elseif itemDef.type == "energy" then
		if pet then
			local stMax = pet.modifiedStats.stamina or pet.currentStamina or 0
			local enMax = pet.modifiedStats.energy or pet.currentEnergy or 0
			pet.currentStamina = math.min(stMax, (pet.currentStamina or 0) + (itemDef.amount or 10))
			pet.currentEnergy = math.min(enMax, (pet.currentEnergy or 0) + math.floor((itemDef.amount or 10) * 0.5))
			self.worldService:pushFloatingText(pet.pos, "+ST/EN", "#ffe7a8")
		end
		self.worldService:pushEventLog(player, "Used replenish berry", "#ffe7a8")
		return true
	elseif itemDef.type == "revive" then
		local slot = self:findDefeatedSlot(player, targetSlot)
		if slot then
			self.playerDataService:revivePartySlot(player, slot)
			self.creatureService:respawnPartyFromOwned(player)
			self.worldService:pushEventLog(player, string.format("Used Revive Berry (slot %d revived)", slot), "#9fd3ff")
			return true
		end
		self.worldService:pushEventLog(player, "Used Revive Berry (no defeated party pet)", "#9fd3ff")
		return true
	end
	return false
end

function BerryService:tryUseBerry(player, kind, targetSlot)
	local itemDef = BERRY_ITEM_DEFS[kind]
	if not itemDef then
		return false, "invalid berry"
	end
	local ok = self.inventoryService:tryConsume(player, itemDef.canonical, 1)
	if not ok and kind ~= itemDef.canonical then
		ok = self.inventoryService:tryConsume(player, kind, 1)
	end
	if not ok then
		return false, "no berry"
	end
	return self:applyBerryEffect(player, itemDef, targetSlot)
end

return BerryService
