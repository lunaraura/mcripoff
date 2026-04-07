local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = Shared:WaitForChild("Items")
local ItemUseRules = require(Items:WaitForChild("ItemUseRules"))

local BerryService = {}
BerryService.__index = BerryService

function BerryService.new(worldService, inventoryService, creatureService, playerDataService)
	return setmetatable({
		worldService = worldService,
		inventoryService = inventoryService,
		creatureService = creatureService,
		playerDataService = playerDataService,
		lastUseAtByUser = {},
	}, BerryService)
end

function BerryService:getOwnedAtSlot(player, slot)
	local data = self.playerDataService:getOrCreate(player)
	local ownedId = data.partySlots[slot]
	return ownedId and data.ownedCreatures[ownedId] or nil
end

function BerryService:getRuntimeAtSlot(player, slot)
	local owned = self:getOwnedAtSlot(player, slot)
	if not owned then return nil end
	return self.worldService:getRuntimeCreatureForOwnedId(player.UserId, owned.ownedId)
end

function BerryService:emitResult(player, result)
	local remote = self.worldService.remotes and self.worldService.remotes.ItemUseResult
	if remote then remote:FireClient(player, result) end
	if result.ok then
		self.worldService:pushEventLog(player, string.format("Item use ok [%s]", result.reasonCode), "#a8ffd7")
	else
		self.worldService:pushEventLog(player, string.format("Item use failed [%s]", result.reasonCode), "#ffb3b3")
	end
end

function BerryService:validateServerTarget(player, def, slot)
	if not slot then return false, ItemUseRules.Reason.NO_TARGET end
	local owned = self:getOwnedAtSlot(player, slot)
	if not owned then return false, ItemUseRules.Reason.TARGET_INVALID end
	local runtime = self:getRuntimeAtSlot(player, slot)
	if def.targeting == "ally_defeated" then
		if not owned.isDefeated then return false, ItemUseRules.Reason.TARGET_NOT_DEFEATED end
		return true, slot, owned, runtime
	end
	if owned.isDefeated or not runtime or not runtime.alive then return false, ItemUseRules.Reason.TARGET_INVALID end
	if def.effect.kind == "heal" and runtime.currentHP >= (runtime.modifiedStats.maxHP or runtime.currentHP) then
		return false, ItemUseRules.Reason.TARGET_FULL_HP
	end
	return true, slot, owned, runtime
end

function BerryService:applyEffect(player, def, owned, runtime, slot)
	local effect = def.effect or {}
	if effect.kind == "heal" then
		runtime.currentHP = math.min(runtime.modifiedStats.maxHP, runtime.currentHP + (effect.hpFlat or 0))
	elseif effect.kind == "restore" then
		runtime.currentStamina = math.min(runtime.modifiedStats.stamina, runtime.currentStamina + (effect.staminaFlat or 0))
		runtime.currentEnergy = math.min(runtime.modifiedStats.energy, runtime.currentEnergy + (effect.energyFlat or 0))
	elseif effect.kind == "revive" then
		self.playerDataService:revivePartySlot(player, slot)
		if owned and owned.ownedId then
			self.playerDataService:setOwnedDefeated(player, owned.ownedId, false)
		end
		self.creatureService:respawnPartyFromOwned(player)
		local revived = runtime or self.worldService:getRuntimeCreatureForOwnedId(player.UserId, owned.ownedId)
		if revived then
			revived.currentHP = math.max(1, math.floor((revived.modifiedStats.maxHP or 1) * (effect.hpPercent or 0.5)))
		end
	end
end

function BerryService:tryUseBerry(player, rawKey, targetSlot)
	local canonical, def = ItemUseRules.getDef(rawKey)
	if not canonical then
		local r = { ok = false, reasonCode = ItemUseRules.Reason.INVALID, key = tostring(rawKey) }
		self:emitResult(player, r)
		return false, r
	end
	local now = self.worldService.time
	local byItem = self.lastUseAtByUser[player.UserId] or {}
	self.lastUseAtByUser[player.UserId] = byItem
	local cd = def.useCooldown or 0
	if (byItem[canonical] or -math.huge) + cd > now then
		local r = { ok = false, reasonCode = ItemUseRules.Reason.ON_COOLDOWN, key = canonical }
		self:emitResult(player, r)
		return false, r
	end
	local count = self.inventoryService:getCount(player, canonical)
	if count < 1 then
		local r = { ok = false, reasonCode = ItemUseRules.Reason.UNOWNED, key = canonical }
		self:emitResult(player, r)
		return false, r
	end
	local okTarget, slot, owned, runtime = self:validateServerTarget(player, def, targetSlot)
	if not okTarget then
		local r = { ok = false, reasonCode = slot, key = canonical }
		self:emitResult(player, r)
		return false, r
	end
	if not self.inventoryService:tryConsume(player, canonical, 1) then
		local r = { ok = false, reasonCode = ItemUseRules.Reason.UNOWNED, key = canonical }
		self:emitResult(player, r)
		return false, r
	end
	byItem[canonical] = now
	self:applyEffect(player, def, owned, runtime, slot)
	local r = { ok = true, reasonCode = ItemUseRules.Reason.OK, key = canonical, targetSlot = targetSlot }
	self:emitResult(player, r)
	return true, r
end

return BerryService
