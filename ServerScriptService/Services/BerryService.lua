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


function BerryService:resolveAllyTarget(player, def, requestedSlot, requestedOwnedId)
	local data = self.playerDataService:getOrCreate(player)
	local activeSlot = tonumber(player:GetAttribute("ActivePetSlot")) or 1
	local resolvedSlot = tonumber(requestedSlot)
	local debug = {
		targetType = ItemUseRules.getTargetType(def),
		itemTargeting = tostring(def and def.targeting or "none"),
		requestedSlot = tonumber(requestedSlot),
		requestedOwnedId = tonumber(requestedOwnedId),
		activeSlot = activeSlot,
	}

	if not resolvedSlot and requestedOwnedId then
		for slot = 1, 2 do
			local ownedId = data.partySlots[slot]
			if ownedId and tonumber(ownedId) == tonumber(requestedOwnedId) then
				resolvedSlot = slot
				break
			end
		end
	end

	if not resolvedSlot then
		local pets = {}
		for slot = 1, 2 do
			local ownedId = data.partySlots[slot]
			local owned = ownedId and data.ownedCreatures[ownedId] or nil
			if owned then
				pets[slot] = {
					state = owned.isDefeated and "defeated" or "alive",
					ownedId = owned.ownedId,
				}
			end
		end
		resolvedSlot = ItemUseRules.computePreferredTargetSlot(def, pets, activeSlot)
	end

	debug.resolvedSlot = resolvedSlot
	local owned = resolvedSlot and self:getOwnedAtSlot(player, resolvedSlot) or nil
	local runtime = resolvedSlot and self:getRuntimeAtSlot(player, resolvedSlot) or nil
	debug.resolvedOwnedId = owned and owned.ownedId or nil
	debug.resolvedOwnedDefeated = owned and owned.isDefeated or nil
	debug.resolvedRuntimeAlive = runtime and runtime.alive or nil
	return resolvedSlot, owned, runtime, debug
end

function BerryService:emitResult(player, result)
	local remote = self.worldService.remotes and self.worldService.remotes.ItemUseResult
	if remote then remote:FireClient(player, result) end
	local dbg = result.debug or {}
	local debugSuffix = string.format(" tgtType=%s slot=%s owned=%s", tostring(dbg.targetType or "-"), tostring(dbg.resolvedSlot or "-"), tostring(dbg.resolvedOwnedId or "-"))
	if result.ok then
		self.worldService:pushEventLog(player, string.format("Item use ok [%s]%s", result.reasonCode, debugSuffix), "#a8ffd7")
	else
		self.worldService:pushEventLog(player, string.format("Item use failed [%s]%s", result.reasonCode, debugSuffix), "#ffb3b3")
	end
end

function BerryService:validateServerTarget(player, def, requestedSlot, requestedOwnedId)
	local slot, owned, runtime, debug = self:resolveAllyTarget(player, def, requestedSlot, requestedOwnedId)
	if not slot then return false, ItemUseRules.Reason.NO_VALID_ALLY, nil, nil, nil, debug end
	if not owned then return false, ItemUseRules.Reason.TARGET_INVALID, slot, nil, nil, debug end
	if def.targeting == "ally_defeated" then
		if not owned.isDefeated then return false, ItemUseRules.Reason.TARGET_NOT_DEFEATED, slot, owned, runtime, debug end
		debug.resolution = "ally_defeated_ok"
		return true, ItemUseRules.Reason.OK, slot, owned, runtime, debug
	end
	if owned.isDefeated or not runtime or not runtime.alive then return false, ItemUseRules.Reason.TARGET_INVALID, slot, owned, runtime, debug end
	if def.effect.kind == "heal" and runtime.currentHP >= (runtime.modifiedStats.maxHP or runtime.currentHP) then
		return false, ItemUseRules.Reason.TARGET_FULL_HP, slot, owned, runtime, debug
	end
	debug.resolution = "ally_alive_ok"
	return true, ItemUseRules.Reason.OK, slot, owned, runtime, debug
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
			if owned and owned.ownedId then
				self.creatureService:syncOwnedFromRuntime(player, owned.ownedId, revived)
			end
		end
	end
end

function BerryService:tryUseBerry(player, rawKey, targetSlot, targetOwnedId)
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
	local activeSlot = tonumber(player:GetAttribute("ActivePetSlot")) or 1
	local resolvedTargetSlot = ItemUseRules.resolveTargetSlot(def, targetSlot, activeSlot)
	local okTarget, reasonCode, slot, owned, runtime, runtimeDebug = self:validateServerTarget(player, def, resolvedTargetSlot, targetOwnedId)
	if not okTarget then
		local r = { ok = false, reasonCode = reasonCode, key = canonical, debug = runtimeDebug }
		self:emitResult(player, r)
		return false, r
	end
	if not self.inventoryService:tryConsume(player, canonical, 1) then
		local r = { ok = false, reasonCode = ItemUseRules.Reason.UNOWNED, key = canonical }
		self:emitResult(player, r)
		return false, r
	end
	byItem[canonical] = now
	self:applyEffect(player, def, owned, runtime or self:getRuntimeAtSlot(player, slot), slot)
	local r = { ok = true, reasonCode = ItemUseRules.Reason.OK, key = canonical, targetSlot = slot, debug = runtimeDebug }
	self:emitResult(player, r)
	return true, r
end

return BerryService
