local BuildService = {}
BuildService.__index = BuildService

function BuildService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, BuildService)
end

function BuildService:handleContextAction(player, payload)
	payload = payload or {}
	local action = payload.action or "context"
	if action == "gather" or action == "context" then
		-- TODO: Connect to NodeRuntime + BuildableConfig costs/harvestTime.
		local granted = self.inventoryService:grant(player, { { key = "fiber", amount = 1 } })
		return true, granted
	elseif action == "build" then
		-- TODO: Place buildables in Workspace.World.Buildables with server validation.
		return true, "build queued"
	end
	return false, "unknown context action"
end

return BuildService
