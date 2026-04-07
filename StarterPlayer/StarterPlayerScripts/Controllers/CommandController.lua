local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local CommandController = {}
CommandController.__index = CommandController

function CommandController.new(partyController)
	return setmetatable({
		partyController = partyController,
		requestPetCommand = remotes:WaitForChild("RequestPetCommand"),
		requestManualCast = remotes:WaitForChild("RequestManualCast"),
		mouse = nil,
	}, CommandController)
end

function CommandController:bind(mouse)
	self.mouse = mouse
end

function CommandController:sendCommand(command)
	self.requestPetCommand:FireServer({
		slot = self.partyController.selectedSlot,
		command = command,
	})
end

function CommandController:setActiveSlot(slot)
	self.requestPetCommand:FireServer({
		slot = slot,
		command = { type = "setActive" },
	})
end

function CommandController:setControlMode(mode)
	self.requestPetCommand:FireServer({
		slot = self.partyController.selectedSlot,
		command = { type = "setControlMode", mode = mode },
	})
end

function CommandController:cast(abilityKey, targetId)
	self.requestManualCast:FireServer({
		slot = self.partyController.selectedSlot,
		abilityKey = abilityKey,
		targetId = targetId,
	})
end

function CommandController:getTargetIdUnderMouse()
	local target = self.mouse and self.mouse.Target
	if not target then return nil end
	local model = target:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	local id = string.match(model.Name, "^C_(%d+)_")
	if not id then return nil end
	return tonumber(id)
end

return CommandController
