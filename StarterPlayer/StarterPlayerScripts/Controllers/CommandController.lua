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

function CommandController:cast(abilityKey, targetId)
	self.requestManualCast:FireServer({
		slot = self.partyController.selectedSlot,
		abilityKey = abilityKey,
		targetId = targetId,
	})
end

return CommandController
