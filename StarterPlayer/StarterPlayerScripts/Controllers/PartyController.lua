local PartyController = {}
PartyController.__index = PartyController

function PartyController.new()
	return setmetatable({ selectedSlot = 1, maxSlots = 2 }, PartyController)
end

function PartyController:selectSlot(slot)
	self.selectedSlot = math.clamp(slot, 1, self.maxSlots)
end

return PartyController
