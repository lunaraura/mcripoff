local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local ItemController = {}
ItemController.__index = ItemController

function ItemController.new(partyController)
	return setmetatable({
		party = partyController,
		useBerryRemote = remotes:WaitForChild("UseBerry"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		items = {
			{ key = "berry_red", label = "Red Berry" },
			{ key = "berry_yellow", label = "Yellow Berry" },
			{ key = "revive_berry", label = "Blue/Revive Berry" },
		},
		selectedItemIndex = 1,
		selectedItemKey = "berry_red",
		lastPetPayload = {},
		onChanged = nil,
	}, ItemController)
end

function ItemController:bind()
	self.petHudUpdate.OnClientEvent:Connect(function(payload)
		self.lastPetPayload = (payload and payload.pets) or {}
		self:emitChanged()
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.LeftBracket then
			self:cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.RightBracket then
			self:cycle(1)
		elseif input.KeyCode == Enum.KeyCode.B then
			self:useSelected()
		end
	end)
end

function ItemController:emitChanged()
	if self.onChanged then
		self.onChanged()
	end
end

function ItemController:setChangedCallback(cb)
	self.onChanged = cb
end

function ItemController:getCount(itemKey)
	local player = Players.LocalPlayer
	return tonumber(player:GetAttribute("Mat_" .. tostring(itemKey))) or 0
end

function ItemController:cycle(delta)
	local n = #self.items
	local nextIndex = ((self.selectedItemIndex - 1 + delta) % n) + 1
	self.selectedItemIndex = nextIndex
	self.selectedItemKey = self.items[nextIndex].key
	self:emitChanged()
end

function ItemController:getSelectedItem()
	return self.items[self.selectedItemIndex]
end

function ItemController:getDefeatedSlotPreference()
	local active = self.party and self.party.selectedSlot or 1
	local activePet = self.lastPetPayload[active]
	if activePet and activePet.state == "defeated" then
		return active
	end
	for slot = 1, 2 do
		local pet = self.lastPetPayload[slot]
		if pet and pet.state == "defeated" then
			return slot
		end
	end
	return nil
end

function ItemController:getTargetSlotForItem(itemKey)
	if itemKey == "revive_berry" then
		return self:getDefeatedSlotPreference()
	end
	return self.party and self.party.selectedSlot or 1
end

function ItemController:useSelected()
	local item = self:getSelectedItem()
	if not item then return end
	local targetSlot = self:getTargetSlotForItem(item.key)
	self.useBerryRemote:FireServer({ kind = item.key, targetSlot = targetSlot })
end

return ItemController
