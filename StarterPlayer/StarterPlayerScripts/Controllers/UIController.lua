local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UIController = {}
UIController.__index = UIController

function UIController.new()
	return setmetatable({ floatingTextEvent = remotes:WaitForChild("FloatingTextEvent") }, UIController)
end

function UIController:bind()
	self.floatingTextEvent.OnClientEvent:Connect(function(payload)
		-- TODO: Replace print with billboard text pooling.
		print(string.format("[FX] %s @ (%.1f, %.1f)", payload.text, payload.x, payload.z))
	end)
end

return UIController
