local UserInputService = game:GetService("UserInputService")

local InputController = {}
InputController.__index = InputController

function InputController.new(partyController, commandController, buildController)
	return setmetatable({
		party = partyController,
		command = commandController,
		build = buildController,
	}, InputController)
end

function InputController:bind()
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.One then
			self.party:selectSlot(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			self.party:selectSlot(2)
		elseif input.KeyCode == Enum.KeyCode.F then
			self.command:sendCommand({ type = "follow" })
		elseif input.KeyCode == Enum.KeyCode.H then
			self.command:sendCommand({ type = "hold" })
		elseif input.KeyCode == Enum.KeyCode.Q then
			self.command:cast("ram", nil) -- TODO: add target picking
		elseif input.KeyCode == Enum.KeyCode.E then
			self.build:sendContext({ action = "gather" })
		end
	end)
end

return InputController
