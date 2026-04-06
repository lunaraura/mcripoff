local BuildService = {}
BuildService.__index = BuildService

function BuildService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, BuildService)
end

function BuildService:handleContextAction(player, payload)
	payload = payload or {}
	local action = payload.action or "context"
	if action == "gather" or action == "context" then
		-- TODO: Port full node-based gather/context interactions from JS into NodeRuntime/BuildService.
		return false, "no gather target"
	elseif action == "build" then
		-- TODO: Port JS build placement/validation/harvest loop; disabled until full pass lands.
		return false, "build disabled"
	end
	return false, "unknown context action"
end

return BuildService
