local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))

local BuildService = {}
BuildService.__index = BuildService

function BuildService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, BuildService)
end

function BuildService:handleContextAction(player, payload)
	payload = payload or {}
	local action = payload.action or "context"
	if action == "gather" or action == "context" then
		-- TODO: Replace simple gather with biome/node-based gathering from NodeRuntime.
		local gatherKey = payload.resourceKey or "fiber"
		local granted = self.inventoryService:grant(player, { { key = gatherKey, amount = 1 } })
		self.worldService:pushEventLog(player, string.format("Gathered %s", gatherKey), "#d7fcb7")
		return true, granted
	elseif action == "build" then
		local buildKey = payload.buildKey
		local def = BuildableConfig[buildKey]
		if not def then
			return false, "unknown build key"
		end
		for matKey, cost in pairs(def.cost or {}) do
			local count = self.inventoryService:getCount(player, matKey)
			if count < cost then
				return false, string.format("missing %s", matKey)
			end
		end
		for matKey, cost in pairs(def.cost or {}) do
			self.inventoryService:tryConsume(player, matKey, cost)
		end
		-- TODO: Place persistent buildable runtime objects in world/chunk index.
		local rewards = {}
		for key, amount in pairs(def.provides or {}) do
			table.insert(rewards, { key = key, amount = amount })
		end
		local granted = self.inventoryService:grant(player, rewards)
		self.worldService:pushEventLog(player, string.format("Built %s", def.name or buildKey), "#bfe2ff")
		return true, granted
	end
	return false, "unknown context action"
end

return BuildService
