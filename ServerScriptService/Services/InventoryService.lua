local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new(playerDataService)
	return setmetatable({ playerDataService = playerDataService }, InventoryService)
end

function InventoryService:grant(player, rewards)
	local data = self.playerDataService:getOrCreate(player)
	local granted = {}
	for _, r in ipairs(rewards or {}) do
		data.materials[r.key] = (data.materials[r.key] or 0) + (r.amount or 0)
		table.insert(granted, { key = r.key, amount = r.amount or 0 })
	end
	return granted
end

return InventoryService
