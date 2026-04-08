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
			self.command:setActiveSlot(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			self.party:selectSlot(2)
			self.command:setActiveSlot(2)
		elseif input.KeyCode == Enum.KeyCode.F then
			self.party:setStance("FOLLOW")
			self.command:sendCommand({ type = "follow" })
		elseif input.KeyCode == Enum.KeyCode.H then
			self.party:setStance("HOLD")
			self.command:sendCommand({ type = "hold" })
		elseif input.KeyCode == Enum.KeyCode.M then
			local mode = self.party:toggleControlMode()
			self.command:setControlMode(mode)
		elseif input.KeyCode == Enum.KeyCode.G then
			self.command:sendCommand({ type = "attackNearest" })
		elseif input.KeyCode == Enum.KeyCode.R then
			local targetId = self.command:getTargetIdUnderMouse()
			if targetId then
				self.command:sendCommand({ type = "designateTarget", targetId = targetId })
			else
				self.command:sendCommand({ type = "clearDesignatedTarget" })
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			self.command:cast("ram", nil) -- TODO: add target picking
		elseif input.KeyCode == Enum.KeyCode.E then
			self.build:handlePrimaryAction()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local targetId = self.command:getTargetIdUnderMouse()
			if targetId then
				self.command:sendCommand({ type = "attack", targetId = targetId })
			else
				self.command:sendCommand({ type = "attackNearest" })
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local hit = self.command.mouse and self.command.mouse.Hit
			if hit then
				self.command:sendCommand({ type = "move", point = hit.Position })
			end
		end
	end)
end

return InputController
