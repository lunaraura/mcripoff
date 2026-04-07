local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))

local AIService = {}
AIService.__index = AIService

function AIService.new(worldService)
	return setmetatable({ worldService = worldService, passiveState = {} }, AIService)
end

function AIService:think(creature, dt)
	creature.intent.move = Vector3.zero
	creature.intent.abilityKey = nil
	creature.intent.targetId = nil
	if creature.mode == "pet" then
		self:thinkPet(creature)
	else
		self:thinkWild(creature, dt)
	end
end

function AIService:thinkPet(creature)
	if creature.command and creature.command.type == "follow" then
		local owner = Players:GetPlayerByUserId(creature.ownerUserId or -1)
		local root = owner and owner.Character and owner.Character.PrimaryPart
		if root then
			local delta = root.Position - creature.pos
			if delta.Magnitude > 10 then
				creature.intent.move = Vector3.new(delta.X, 0, delta.Z)
			end
		end
		return
	end
	if creature.command and creature.command.type == "hold" then
		creature.intent.move = Vector3.zero
		return
	end
	if creature.command and creature.command.type == "move" and creature.command.point then
		local delta = creature.command.point - creature.pos
		if delta.Magnitude > 3 then
			creature.intent.move = Vector3.new(delta.X, 0, delta.Z)
		else
			creature.command = { type = "follow", issuedAt = self.worldService.time }
		end
		return
	end
	if creature.command and creature.command.type == "attack" and creature.command.targetId then
		local target = self.worldService:getCreatureById(creature.command.targetId)
		if target and target.alive and target.team ~= creature.team then
			self:fightTarget(creature, target)
			return
		end
		creature.command = { type = "follow", issuedAt = self.worldService.time }
	end
	if creature.command and creature.command.type == "attackNearest" then
		local target = self.worldService:findNearestEnemyOf(creature, 100)
		if target then
			self:fightTarget(creature, target)
			return
		end
	end
	local target, d = self.worldService:findNearestEnemyOf(creature, 85)
	if not target then return end
	local direction = (target.pos - creature.pos)
	if d > 10 then creature.intent.move = Vector3.new(direction.X, 0, direction.Z) end
	for _, key in ipairs(creature.moveset) do
		if AbilityConfig[key] and (creature.cooldowns[key] or 0) <= 0 then
			creature.intent.abilityKey = key
			creature.intent.targetId = target.id
			break
		end
	end
end

function AIService:thinkWild(creature, dt)
	if creature.role == "passive" then
		self:thinkPassiveWild(creature, dt)
		return
	end
	local aggroRange = (creature.modifiedStats.range or 70) * (creature.wildProfile.aggroMult or 1) * (creature.wildProfile.commitment or 1)
	local target = self:pickWildTarget(creature, aggroRange)
	if not target then
		self:returnToAnchor(creature, 8)
		return
	end
	self:fightTarget(creature, target)
end

function AIService:pickWildTarget(creature, aggroRange)
	return self.worldService:findNearestEnemyOf(creature, aggroRange)
end

function AIService:fightTarget(creature, target)
	local delta = target.pos - creature.pos
	local d = delta.Magnitude
	if d > 12 then
		creature.intent.move = Vector3.new(delta.X, 0, delta.Z)
	end
	for _, key in ipairs(creature.moveset) do
		local ability = AbilityConfig[key]
		if ability and (creature.cooldowns[key] or 0) <= 0 and d <= (ability.range or 20) then
			creature.intent.abilityKey = key
			creature.intent.targetId = target.id
			return
		end
	end
end

function AIService:thinkPassiveWild(creature, dt)
	local threat = self:findPassiveThreat(creature)
	if threat then
		local away = creature.pos - threat.pos
		creature.intent.move = Vector3.new(away.X, 0, away.Z)
		return
	end
	local s = self.passiveState[creature.id]
	if not s then
		s = { timer = 0, angle = math.random() * math.pi * 2 }
		self.passiveState[creature.id] = s
	end
	s.timer -= dt
	if s.timer <= 0 then
		s.timer = 0.7 + math.random() * 1.1
		s.angle += (math.random() - 0.5) * 1.6
	end
	local anchorDelta = creature.spawnAnchor - creature.pos
	if anchorDelta.Magnitude > (20 + 20 * (creature.wildProfile.timidness or 1)) then
		creature.intent.move = Vector3.new(anchorDelta.X, 0, anchorDelta.Z)
		return
	end
	creature.intent.move = Vector3.new(math.cos(s.angle), 0, math.sin(s.angle))
end

function AIService:findPassiveThreat(creature)
	local radius = 70 + 22 * (creature.wildProfile.timidness or 1)
	local best, bestD = nil, radius
	for _, other in ipairs(self.worldService.creatures) do
		if other.id ~= creature.id and other.alive and other.team ~= creature.team then
			local d = (other.pos - creature.pos).Magnitude
			if d < bestD then best, bestD = other, d end
		end
	end
	return best
end

function AIService:returnToAnchor(creature, tolerance)
	local d = (creature.spawnAnchor - creature.pos).Magnitude
	if d > tolerance then
		local delta = creature.spawnAnchor - creature.pos
		creature.intent.move = Vector3.new(delta.X, 0, delta.Z)
	end
end

return AIService
