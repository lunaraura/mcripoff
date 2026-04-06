local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureRuntime = require(script.Parent.Parent.Runtime.CreatureRuntime)

local CreatureService = {}
CreatureService.__index = CreatureService

function CreatureService.new(worldService, playerDataService)
	return setmetatable({ worldService = worldService, playerDataService = playerDataService }, CreatureService)
end

function CreatureService:spawnRuntime(speciesKey, team, x, z, opts)
	local creature = CreatureRuntime.new(speciesKey, team, x, z, opts)
	self.worldService:addCreature(creature)
	self:attachModel(creature)
	return creature
end

function CreatureService:attachModel(creature)
	local worldFolder = Workspace:FindFirstChild("World")
	if not worldFolder then return end
	local modelsFolder = worldFolder:FindFirstChild("CreatureModels")
	if not modelsFolder then return end
	local part = Instance.new("Part")
	part.Name = string.format("C_%d_%s", creature.id, creature.speciesKey)
	part.Size = Vector3.new(2, 2, 2)
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Color = creature.team == 0 and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(255, 155, 120)
	part.Position = creature.pos + Vector3.new(0, 2, 0)
	part.Parent = modelsFolder
	creature.model = part
end

function CreatureService:updateModel(creature)
	if creature.model then
		creature.model.Position = creature.pos + Vector3.new(0, 2, 0)
	end
end

function CreatureService:spawnPartyPetsForPlayer(player)
	local data = self.playerDataService:getOrCreate(player)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return end
	local offsets = { Vector3.new(-6, 0, 8), Vector3.new(6, 0, 8) }
	for slot = 1, 2 do
		local ownedId = data.partySlots[slot]
		local owned = ownedId and data.ownedCreatures[ownedId] or nil
		if owned then
			local pos = root.Position + offsets[slot]
			local pet = self:spawnRuntime(owned.speciesKey, 0, pos.X, pos.Z, { mode = "pet" })
			pet.ownerUserId = player.UserId
			pet.ownedId = ownedId
			pet.partySlot = slot
		end
	end
end

return CreatureService
