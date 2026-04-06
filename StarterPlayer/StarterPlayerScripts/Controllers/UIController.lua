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
		-- Intentionally no-op in vertical slice until billboard UI is wired.
	end)
end

return UIController
