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

function InventoryService:getCount(player, key)
	local data = self.playerDataService:getOrCreate(player)
	return data.materials[key] or 0
end

function InventoryService:tryConsume(player, key, amount)
	local data = self.playerDataService:getOrCreate(player)
	local needed = math.max(1, tonumber(amount) or 1)
	local current = data.materials[key] or 0
	if current < needed then
		return false, "insufficient"
	end
	data.materials[key] = current - needed
	return true, data.materials[key]
end

return InventoryService
