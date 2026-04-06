local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Services = SSS:WaitForChild("Services")
local Systems = SSS:WaitForChild("Systems")
local Runtime = SSS:WaitForChild("Runtime")

local function ensureRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	local evt = folder:FindFirstChild(name)
	if not evt then
		evt = Instance.new("RemoteEvent")
		evt.Name = name
		evt.Parent = folder
	end
	return evt
end

local remotes = {
	RequestPetCommand = ensureRemote("RequestPetCommand"),
	RequestContextAction = ensureRemote("RequestContextAction"),
	RequestManualCast = ensureRemote("RequestManualCast"),
	FloatingTextEvent = ensureRemote("FloatingTextEvent"),
}

local WorldService = require(Services:WaitForChild("WorldService"))
local CreatureService = require(Services:WaitForChild("CreatureService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local AIService = require(Services:WaitForChild("AIService"))
local SpawnService = require(Services:WaitForChild("SpawnService"))
local EffectService = require(Services:WaitForChild("EffectService"))
local HarvestService = require(Services:WaitForChild("HarvestService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local BuildService = require(Services:WaitForChild("BuildService"))
local MorphService = require(Services:WaitForChild("MorphService"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local playerDataService = PlayerDataService.new()
local worldService = WorldService.new(remotes)
local inventoryService = InventoryService.new(playerDataService)
local creatureService = CreatureService.new(worldService, playerDataService)
local combatService = CombatService.new(worldService)
local aiService = AIService.new(worldService)
local spawnService = SpawnService.new(worldService, creatureService)
local effectService = EffectService.new()
local harvestService = HarvestService.new(worldService, inventoryService)
local buildService = BuildService.new(worldService, inventoryService)
local morphService = MorphService.new(playerDataService)

Players.PlayerAdded:Connect(function(player)
	playerDataService:getOrCreate(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		creatureService:spawnPartyPetsForPlayer(player)
	end)
end)

remotes.RequestPetCommand.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local data = playerDataService:getOrCreate(player)
	for _, c in ipairs(worldService.creatures) do
		if c.ownerUserId == player.UserId and c.partySlot and c.partySlot <= 2 then
			if payload.slot == nil or payload.slot == c.partySlot then
				c.command = payload.command
			end
		end
	end
end)

remotes.RequestManualCast.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	for _, c in ipairs(worldService.creatures) do
		if c.ownerUserId == player.UserId and c.partySlot == payload.slot then
			c.intent.abilityKey = payload.abilityKey
			c.intent.targetId = payload.targetId
		end
	end
end)

remotes.RequestContextAction.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	if payload.action == "harvestCreature" then
		harvestService:tryHarvestCreature(player, payload.targetId)
	else
		buildService:handleContextAction(player, payload)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	worldService:stepTime(dt)
	worldService:updateChunksAroundPlayers()
	spawnService:update(dt)
	for _, creature in ipairs(worldService.creatures) do
		if creature.alive then
			effectService:tickCreature(creature, dt)
			aiService:think(creature, dt)
			combatService:tryUseAbility(creature)
			creature:Tick(dt)
			creatureService:updateModel(creature)
		end
	end
	worldService:removeDead()
	-- TODO: Add nearby-only UI/state replication stream for cooldowns/hp bars.
end)
