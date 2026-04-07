local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))

local BuildService = {}
BuildService.__index = BuildService

function BuildService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService, nextBuildId = 1, buildables = {} }, BuildService)
end

function BuildService:nearestCell(root)
	local best, bestD = nil, math.huge
	for _, chunk in pairs(self.worldService.chunks) do
		for _, cell in ipairs(chunk.cells) do
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(cell.x, 0, cell.z)).Magnitude
			if d < bestD then
				best, bestD = cell, d
			end
		end
	end
	return best, bestD
end

function BuildService:tryGather(player, payload)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local cell, dist = self:nearestCell(root)
	if not cell or dist > 18 then
		return false, "no gather target"
	end
	local key = "fiber"
	if cell.terrainClass == "rock" then
		key = "stone"
	elseif cell.terrainClass == "water" then
		key = "battery_seed"
	end
	local granted = self.inventoryService:grant(player, { { key = key, amount = 1 } })
	self.worldService:pushEventLog(player, string.format("Gathered %s", key), "#d7fcb7")
	-- TODO: Replace terrain-class gather with biome/node-driven context actions.
	return true, granted
end

function BuildService:canAfford(player, costs)
	for matKey, amount in pairs(costs or {}) do
		if self.inventoryService:getCount(player, matKey) < amount then
			return false, matKey
		end
	end
	return true
end

function BuildService:tryBuild(player, payload)
	local buildKey = payload.buildKey or "fiber_trap"
	local def = BuildableConfig[buildKey]
	if not def then return false, "unknown build key" end
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local ok, missing = self:canAfford(player, def.cost)
	if not ok then return false, "missing " .. tostring(missing) end
	for matKey, amount in pairs(def.cost or {}) do
		self.inventoryService:tryConsume(player, matKey, amount)
	end
	local id = self.nextBuildId
	self.nextBuildId += 1
	self.buildables[id] = {
		id = id,
		key = buildKey,
		ownerUserId = player.UserId,
		pos = root.Position + root.CFrame.LookVector * 8,
		nextHarvestAt = self.worldService.time + (def.harvestTime or 1),
	}
	self.worldService:pushEventLog(player, string.format("Built %s", def.name or buildKey), "#bfe2ff")
	return true, self.buildables[id]
end

function BuildService:tryHarvestBuild(player, payload)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local best, bestD = nil, 12
	for _, b in pairs(self.buildables) do
		local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(b.pos.X, 0, b.pos.Z)).Magnitude
		if d < bestD then
			best, bestD = b, d
		end
	end
	if not best then return false, "no buildable nearby" end
	local def = BuildableConfig[best.key]
	if not def then return false, "invalid buildable" end
	if self.worldService.time < (best.nextHarvestAt or 0) then
		return false, "not ready"
	end
	local rewards = {}
	for key, amount in pairs(def.provides or {}) do
		local mappedKey = key
		if key == "bait" then
			mappedKey = "lure_meat"
		end
		table.insert(rewards, { key = mappedKey, amount = amount })
	end
	local granted = self.inventoryService:grant(player, rewards)
	best.nextHarvestAt = self.worldService.time + (def.harvestTime or 1)
	self.worldService:pushEventLog(player, string.format("Harvested %s", def.name or best.key), "#d7fcb7")
	return true, granted
end

function BuildService:handleContextAction(player, payload)
	payload = payload or {}
	local action = payload.action or "context"
	if action == "gather" or action == "context" then
		return self:tryGather(player, payload)
	elseif action == "build" then
		return self:tryBuild(player, payload)
	elseif action == "harvestBuild" then
		return self:tryHarvestBuild(player, payload)
	end
	return false, "unknown context action"
end

return BuildService
