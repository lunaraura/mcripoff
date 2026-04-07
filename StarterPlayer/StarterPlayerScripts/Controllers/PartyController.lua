local PartyController = {}
PartyController.__index = PartyController

function PartyController.new()
	return setmetatable({
		selectedSlot = 1,
		maxSlots = 2,
		controlMode = "AUTO",
		stance = "FOLLOW",
	}, PartyController)
end

function PartyController:selectSlot(slot)
	self.selectedSlot = math.clamp(slot, 1, self.maxSlots)
end

function PartyController:setControlMode(mode)
	if mode == "AUTO" or mode == "MANUAL" then
		self.controlMode = mode
	end
end

function PartyController:toggleControlMode()
	if self.controlMode == "AUTO" then
		self.controlMode = "MANUAL"
	else
		self.controlMode = "AUTO"
	end
	return self.controlMode
end

function PartyController:setStance(stance)
	if stance == "FOLLOW" or stance == "HOLD" then
		self.stance = stance
	end
end

return PartyController
