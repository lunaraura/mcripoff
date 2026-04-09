local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ItemConfig = require(Config:WaitForChild("ItemConfig"))

local ItemUseRules = {}

ItemUseRules.Reason = {
	OK = "ITEM_OK",
	INVALID = "ITEM_INVALID",
	UNOWNED = "ITEM_UNOWNED",
	NO_TARGET = "ITEM_NO_TARGET",
	TARGET_INVALID = "ITEM_TARGET_INVALID",
	TARGET_NOT_DEFEATED = "ITEM_TARGET_NOT_DEFEATED",
	TARGET_FULL_HP = "ITEM_TARGET_FULL_HP",
	ON_COOLDOWN = "ITEM_ON_COOLDOWN",
}

function ItemUseRules.getCanonicalKey(inputKey)
	if not inputKey then return nil end
	if ItemConfig[inputKey] then return inputKey end
	for key, def in pairs(ItemConfig) do
		for _, alias in ipairs(def.aliases or {}) do
			if alias == inputKey then return key end
		end
	end
	return nil
end

function ItemUseRules.getDef(inputKey)
	local key = ItemUseRules.getCanonicalKey(inputKey)
	return key, key and ItemConfig[key] or nil
end

function ItemUseRules.getDisplayItems()
	local out = {}
	for key, def in pairs(ItemConfig) do
		table.insert(out, { key = key, label = def.label, targeting = def.targeting })
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

function ItemUseRules.shouldRouteToActivePet(def)
	if not def then return false end
	local effect = def.effect or {}
	return effect.kind == "restore" or effect.kind == "effect"
end

function ItemUseRules.resolveTargetSlot(def, requestedSlot, activeSlot)
	if ItemUseRules.shouldRouteToActivePet(def) then
		return activeSlot
	end
	return requestedSlot
end

function ItemUseRules.computePreferredTargetSlot(def, pets, activeSlot)
	activeSlot = activeSlot or 1
	if not def then return nil end
	if ItemUseRules.shouldRouteToActivePet(def) then
		if pets[activeSlot] and pets[activeSlot].state == "alive" then return activeSlot end
		return nil
	end
	if def.targeting == "ally_defeated" then
		if pets[activeSlot] and pets[activeSlot].state == "defeated" then return activeSlot end
		for slot = 1, 2 do
			if pets[slot] and pets[slot].state == "defeated" then return slot end
		end
		return nil
	end
	if pets[activeSlot] and pets[activeSlot].state == "alive" then return activeSlot end
	for slot = 1, 2 do
		if pets[slot] and pets[slot].state == "alive" then return slot end
	end
	return nil
end

function ItemUseRules.validateClientUse(def, count, targetSlot)
	if not def then return false, ItemUseRules.Reason.INVALID end
	if (count or 0) < 1 then return false, ItemUseRules.Reason.UNOWNED end
	if not targetSlot then return false, ItemUseRules.Reason.NO_TARGET end
	return true, ItemUseRules.Reason.OK
end

return ItemUseRules
