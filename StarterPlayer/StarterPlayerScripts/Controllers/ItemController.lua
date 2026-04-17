local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = Shared:WaitForChild("Items")
local ItemUseRules = require(Items:WaitForChild("ItemUseRules"))

local ItemController = {}
ItemController.__index = ItemController

function ItemController.new(partyController)
	local items = ItemUseRules.getDisplayItems()
	return setmetatable({
		party = partyController,
		useBerryRemote = remotes:WaitForChild("UseBerry"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		itemUseResult = remotes:WaitForChild("ItemUseResult"),
		items = items,
		selectedItemIndex = 1,
		selectedItemKey = items[1] and items[1].key or nil,
		lastPetPayload = {},
		lastUseResult = { ok = true, reasonCode = ItemUseRules.Reason.OK },
		onChanged = nil,
	}, ItemController)
end

function ItemController:bind()
	self.petHudUpdate.OnClientEvent:Connect(function(payload)
		self.lastPetPayload = (payload and payload.pets) or {}
		self:emitChanged()
	end)
	self.itemUseResult.OnClientEvent:Connect(function(payload)
		self.lastUseResult = payload or { ok = false, reasonCode = ItemUseRules.Reason.INVALID }
		self:emitChanged()
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.LeftBracket then self:cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.RightBracket then self:cycle(1)
		elseif input.KeyCode == Enum.KeyCode.B then
			self:useSelected()
		else
			local keyMap = {
				[Enum.KeyCode.One] = 1,
				[Enum.KeyCode.Two] = 2,
				[Enum.KeyCode.Three] = 3,
				[Enum.KeyCode.Four] = 4,
				[Enum.KeyCode.Five] = 5,
				[Enum.KeyCode.Six] = 6,
				[Enum.KeyCode.Seven] = 7,
				[Enum.KeyCode.Eight] = 8,
				[Enum.KeyCode.Nine] = 9,
			}
			local slot = keyMap[input.KeyCode]
			if slot then
				self:selectIndex(slot)
			end
		end
	end)
end

function ItemController:emitChanged()
	if self.onChanged then self.onChanged() end
end

function ItemController:setChangedCallback(cb)
	self.onChanged = cb
end

function ItemController:getCount(itemKey)
	return tonumber(Players.LocalPlayer:GetAttribute("Mat_" .. tostring(itemKey))) or 0
end

function ItemController:cycle(delta)
	local n = #self.items
	if n <= 0 then return end
	self.selectedItemIndex = ((self.selectedItemIndex - 1 + delta) % n) + 1
	self.selectedItemKey = self.items[self.selectedItemIndex].key
	self:emitChanged()
end

function ItemController:selectIndex(index)
	local n = #self.items
	if n <= 0 then return false end
	local i = math.clamp(tonumber(index) or 1, 1, n)
	self.selectedItemIndex = i
	self.selectedItemKey = self.items[self.selectedItemIndex].key
	self:emitChanged()
	return true
end

function ItemController:getSelectedItem()
	return self.items[self.selectedItemIndex]
end

function ItemController:getTargetSlotForItem(itemKey)
	local _, def = ItemUseRules.getDef(itemKey)
	local active = self.party and self.party.selectedSlot or 1
	return ItemUseRules.computePreferredTargetSlot(def, self.lastPetPayload or {}, active)
end

function ItemController:validateSelectedUse()
	local item = self:getSelectedItem()
	local _, def = ItemUseRules.getDef(item and item.key)
	local targetSlot = self:getTargetSlotForItem(item and item.key)
	return ItemUseRules.validateClientUse(def, self:getCount(item and item.key), targetSlot), targetSlot
end

function ItemController:useSelected()
	local item = self:getSelectedItem()
	if not item then return false end
	local ok, reasonCode, targetSlot = self:validateSelectedUse()
	if not ok then
		self.lastUseResult = { ok = false, reasonCode = reasonCode, key = item.key }
		self:emitChanged()
		return false
	end
	self.useBerryRemote:FireServer({ kind = item.key, targetSlot = targetSlot })
	return true
end

return ItemController
