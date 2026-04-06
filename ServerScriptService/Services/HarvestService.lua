local HarvestService = {}
HarvestService.__index = HarvestService

function HarvestService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, HarvestService)
end

function HarvestService:tryHarvestCreature(player, targetId)
	local c = self.worldService:getCreatureById(targetId)
	if not c or not c.alive or c.role ~= "passive" then
		return false, "invalid target"
	end
	if self.worldService.time < (c.nextHarvestAt or 0) then
		return false, "cooldown"
	end
	local granted = self.inventoryService:grant(player, c.harvestDrop)
	if c.speciesKey == "sheeplet" then
		local berryKinds = { "red", "yellow", "blue" }
		local berryKey = berryKinds[math.random(1, #berryKinds)]
		local berryGrant = self.inventoryService:grant(player, { { key = berryKey, amount = 1 } })
		for _, item in ipairs(berryGrant) do
			table.insert(granted, item)
		end
	end
	c.nextHarvestAt = self.worldService.time + (c.harvestCooldown or 0)
	self.worldService:pushFloatingText(c.pos, "Harvested", "#d7fcb7")
	self.worldService:pushEventLog(player, string.format("Harvested %s", c.speciesKey), "#d7fcb7")
	return true, granted
end

function HarvestService:tryHarvestNearestPassive(player, radius)
	local root = player.Character and player.Character.PrimaryPart
	if not root then
		return false, "no character"
	end
	local best, bestD = nil, radius or 14
	for _, c in ipairs(self.worldService.creatures) do
		if c.alive and c.role == "passive" then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude
			if d < bestD then
				best, bestD = c, d
			end
		end
	end
	if not best then
		return false, "no passive nearby"
	end
	return self:tryHarvestCreature(player, best.id)
end

return HarvestService
