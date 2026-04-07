local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))
local AIConfig = require(Config:WaitForChild("AIConfig"))

local AIService = {}
AIService.__index = AIService

local function flatDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function unitFlat(fromPos, toPos)
	local delta = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
	local mag = delta.Magnitude
	if mag <= 0.0001 then return Vector3.zero, 0 end
	return delta / mag, mag
end

function AIService.new(worldService)
	return setmetatable({ worldService = worldService }, AIService)
end

function AIService:getProfile(creature)
	local key = creature.ai and creature.ai.brainType or "hostileWild"
	return AIConfig.profiles[key] or AIConfig.profiles.hostileWild
end

function AIService:ensureAIState(creature)
	if creature.ai then return creature.ai end
	local brainType = "hostileWild"
	if creature.mode == "pet" then
		brainType = "petFollower"
	elseif creature.role == "passive" then
		brainType = "passiveWild"
	end
	local now = self.worldService.time
	creature.ai = {
		brainType = brainType,
		behaviorState = "idle",
		targetId = nil,
		targetLockUntil = 0,
		homeAnchor = creature.spawnAnchor,
		roamAnchor = creature.spawnAnchor,
		leashRadius = 80,
		aggroRadius = 60,
		disengageRadius = 110,
		lastSeenTargetTime = 0,
		nextThinkAt = now,
		movementRefreshAt = now,
		recentThreatId = nil,
		lastIntent = "idle",
	}
	return creature.ai
end

function AIService:applyProfileSettings(creature, state, profile)
	state.leashRadius = profile.leashRadius
	state.aggroRadius = profile.aggroRadius
	state.disengageRadius = profile.disengageRadius
	if creature.mode == "wild" then
		state.homeAnchor = creature.spawnAnchor
		if not state.roamAnchor then state.roamAnchor = creature.spawnAnchor end
	end
end

function AIService:think(creature, dt)
	creature.intent.move = Vector3.zero
	creature.intent.abilityKey = nil
	creature.intent.targetId = nil
	local state = self:ensureAIState(creature)
	local profile = self:getProfile(creature)
	self:applyProfileSettings(creature, state, profile)
	if self.worldService.time < (state.nextThinkAt or 0) then
		self:applyIntent(creature, state, { kind = "idle" })
		return
	end
	state.nextThinkAt = self.worldService.time + (profile.thinkInterval or 0.2)
	local facts = self:sense(creature, state, profile, dt)
	local decision = self:decide(creature, state, profile, facts)
	local intent = self:buildIntent(creature, state, profile, facts, decision)
	self:applyIntent(creature, state, intent)
end

function AIService:sense(creature, state, profile, dt)
	local now = self.worldService.time
	local owner = nil
	local ownerRoot = nil
	local controlMode = "AUTO"
	local stance = "FOLLOW"
	local activeSlot = 1
	local holdDefenseRange = profile.holdDefenseRange or 30
	if creature.mode == "pet" then
		owner = Players:GetPlayerByUserId(creature.ownerUserId or -1)
		ownerRoot = owner and owner.Character and owner.Character.PrimaryPart
		controlMode = owner and tostring(owner:GetAttribute("PetControlMode") or "AUTO") or "AUTO"
		stance = owner and tostring(owner:GetAttribute("PetStance") or "FOLLOW") or "FOLLOW"
		activeSlot = owner and tonumber(owner:GetAttribute("ActivePetSlot") or 1) or 1
		local leashDistance = owner and tonumber(owner:GetAttribute("PetLeashDistance")) or profile.leashRadius
		state.leashRadius = math.clamp(leashDistance or profile.leashRadius, 35, 160)
		holdDefenseRange = owner and tonumber(owner:GetAttribute("PetHoldDefenseRange")) or holdDefenseRange
		holdDefenseRange = math.clamp(holdDefenseRange or 30, 10, 80)
		local slotOffset = creature.partySlot == 2 and Vector3.new(6, 0, 8) or Vector3.new(-6, 0, 8)
		if ownerRoot then
			state.homeAnchor = ownerRoot.Position
			state.roamAnchor = ownerRoot.Position + slotOffset
		end
	else
		state.homeAnchor = creature.spawnAnchor
		state.roamAnchor = state.roamAnchor or creature.spawnAnchor
	end

	local scanRange = math.max(state.disengageRadius or 100, state.aggroRadius or 60, 40)
	local enemies = {}
	for _, other in ipairs(self.worldService.creatures) do
		if other.id ~= creature.id and other.alive then
			local d = flatDistance(creature.pos, other.pos)
			if d <= scanRange then
				if other.team ~= creature.team then
					table.insert(enemies, { creature = other, dist = d, los = true })
				end
			end
		end
	end
	table.sort(enemies, function(a, b)
		return a.dist < b.dist
	end)

	if state.targetId then
		local t = self.worldService:getCreatureById(state.targetId)
		if t and t.alive then
			state.lastSeenTargetTime = now
		end
	end

	local ownerThreat = nil
	if ownerRoot and #enemies > 0 then
		local bestDist = math.huge
		for _, e in ipairs(enemies) do
			local dOwner = flatDistance(ownerRoot.Position, e.creature.pos)
			if dOwner < bestDist then
				bestDist = dOwner
				ownerThreat = e.creature
			end
		end
	end

	return {
		now = now,
		dt = dt,
		enemies = enemies,
		owner = owner,
		ownerRoot = ownerRoot,
		controlMode = controlMode,
		stance = stance,
		activeSlot = activeSlot,
		ownerThreat = ownerThreat,
		command = creature.command,
		holdDefenseRange = holdDefenseRange,
	}
end

function AIService:scoreTarget(creature, state, profile, facts, candidate)
	local target = candidate.creature
	local score = 100 - candidate.dist
	if candidate.dist > state.aggroRadius then
		score -= 35
	end
	if target.id == state.targetId then
		score += profile.retainBias or 10
	end
	if creature.mode == "pet" and facts.ownerThreat and target.id == facts.ownerThreat.id then
		score += profile.ownerThreatBias or 20
	end
	if creature.mode == "pet" and creature.partySlot and facts.activeSlot and creature.partySlot ~= facts.activeSlot then
		score -= 8
	end
	return score
end

function AIService:selectTarget(creature, state, profile, facts)
	local now = facts.now
	local current = state.targetId and self.worldService:getCreatureById(state.targetId) or nil
	if current and current.alive and now <= (state.targetLockUntil or 0) then
		local dCurrent = flatDistance(creature.pos, current.pos)
		if dCurrent <= state.disengageRadius then
			return current
		end
	end

	local best, bestScore = nil, -math.huge
	for _, e in ipairs(facts.enemies) do
		local score = self:scoreTarget(creature, state, profile, facts, e)
		if score > bestScore then
			best, bestScore = e.creature, score
		end
	end

	if best and flatDistance(creature.pos, best.pos) <= state.aggroRadius then
		state.targetLockUntil = now + (profile.targetLockSeconds or 1.2)
		state.lastSeenTargetTime = now
		return best
	end
	return nil
end

function AIService:transition(state, newState)
	if state.behaviorState ~= newState then
		state.behaviorState = newState
	end
end

function AIService:decide(creature, state, profile, facts)
	local now = facts.now
	local command = facts.command or { type = "follow" }
	local isManual = facts.controlMode == "MANUAL"
	local target = nil
	local forcedState = nil

	if creature.mode == "pet" then
		if command.type == "move" and command.point then
			state.roamAnchor = command.point
			forcedState = "hold"
		elseif command.type == "hold" or facts.stance == "HOLD" then
			forcedState = "hold"
		elseif command.type == "follow" or facts.stance == "FOLLOW" then
			forcedState = "follow"
		elseif command.type == "attack" and command.targetId then
			target = self.worldService:getCreatureById(command.targetId)
			if target and target.alive and target.team ~= creature.team then
				forcedState = "chase"
			else
				creature.command = { type = "follow", issuedAt = now }
			end
		elseif command.type == "attackNearest" then
			target = self:selectTarget(creature, state, profile, facts)
			forcedState = target and "chase" or "follow"
		end
	end

	if creature.mode == "wild" and creature.role == "passive" then
		target = self:selectTarget(creature, state, profile, facts)
		if target then
			state.recentThreatId = target.id
			self:transition(state, "flee")
			return { state = "flee", target = target }
		end
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > profile.roamRadius then
			self:transition(state, "return")
			return { state = "return", anchor = state.roamAnchor }
		end
		self:transition(state, "roam")
		return { state = "roam", anchor = state.roamAnchor }
	end

	if forcedState == "hold" then
		if not isManual then
			target = target or self:selectTarget(creature, state, profile, facts)
			if target and flatDistance(creature.pos, target.pos) <= (facts.holdDefenseRange or profile.holdDefenseRange or 30) then
				self:transition(state, "attack")
				return { state = "attack", target = target }
			end
		end
		self:transition(state, "hold")
		return { state = "hold", anchor = state.roamAnchor }
	end

	if forcedState == "follow" then
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > state.leashRadius then
			self:transition(state, "return")
			return { state = "return", anchor = state.roamAnchor }
		end
		if not isManual then
			target = self:selectTarget(creature, state, profile, facts)
			if target then
				local d = flatDistance(creature.pos, target.pos)
				if d <= profile.preferredRange then
					self:transition(state, "attack")
					return { state = "attack", target = target }
				end
				self:transition(state, "chase")
				return { state = "chase", target = target }
			end
		end
		self:transition(state, "follow")
		return { state = "follow", anchor = state.roamAnchor }
	end

	if forcedState == "chase" and target then
		if flatDistance(creature.pos, target.pos) <= profile.preferredRange then
			self:transition(state, "attack")
			return { state = "attack", target = target }
		end
		self:transition(state, "chase")
		return { state = "chase", target = target }
	end

	target = self:selectTarget(creature, state, profile, facts)
	if target then
		local d = flatDistance(creature.pos, target.pos)
		if d <= profile.preferredRange then
			self:transition(state, "attack")
			return { state = "attack", target = target }
		end
		self:transition(state, "chase")
		return { state = "chase", target = target }
	end

	state.targetId = nil
	if creature.mode == "pet" then
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > 4 then
			self:transition(state, "follow")
			return { state = "follow", anchor = state.roamAnchor }
		end
		self:transition(state, "idle")
		return { state = "idle" }
	end

	local homeDist = flatDistance(creature.pos, state.homeAnchor)
	if homeDist > profile.roamRadius then
		self:transition(state, "return")
		return { state = "return", anchor = state.homeAnchor }
	end
	self:transition(state, "roam")
	return { state = "roam", anchor = state.homeAnchor }
end

function AIService:pickAbilityForTarget(creature, target)
	if not target then return nil end
	local d = flatDistance(creature.pos, target.pos)
	for _, key in ipairs(creature.moveset or {}) do
		local ability = AbilityConfig[key]
		if ability and (creature.cooldowns[key] or 0) <= 0 and d <= (ability.range or 20) then
			return key
		end
	end
	return nil
end

function AIService:buildIntent(creature, state, profile, facts, decision)
	local intent = { kind = decision.state, move = Vector3.zero, targetId = nil, abilityKey = nil }
	if decision.target then
		state.targetId = decision.target.id
		intent.targetId = decision.target.id
	end

	if decision.state == "chase" then
		local dir = unitFlat(creature.pos, decision.target.pos)
		intent.move = dir
		intent.kind = "chase"
		return intent
	end
	if decision.state == "attack" then
		local dir, d = unitFlat(creature.pos, decision.target.pos)
		if d > profile.preferredRange then intent.move = dir end
		intent.abilityKey = self:pickAbilityForTarget(creature, decision.target)
		return intent
	end
	if decision.state == "follow" or decision.state == "return" then
		local dir, d = unitFlat(creature.pos, decision.anchor)
		if d > 3 then intent.move = dir end
		return intent
	end
	if decision.state == "roam" then
		local angle = (state.roamAngle or math.random() * math.pi * 2)
		if facts.now >= (state.movementRefreshAt or 0) then
			angle += (math.random() - 0.5) * 1.7
			state.movementRefreshAt = facts.now + (profile.movementRefresh or 0.8)
			state.roamAngle = angle
		end
		local anchorDist = flatDistance(creature.pos, decision.anchor)
		if anchorDist > profile.roamRadius then
			local dir = unitFlat(creature.pos, decision.anchor)
			intent.move = dir
		else
			intent.move = Vector3.new(math.cos(angle), 0, math.sin(angle))
		end
		return intent
	end
	if decision.state == "flee" then
		local away = unitFlat(decision.target.pos, creature.pos)
		intent.move = away
		return intent
	end
	if decision.state == "hold" then
		intent.move = Vector3.zero
		return intent
	end
	return intent
end

function AIService:applyIntent(creature, state, intent)
	creature.intent.move = intent.move or Vector3.zero
	creature.intent.targetId = intent.targetId
	creature.intent.abilityKey = intent.abilityKey
	state.lastIntent = intent.kind or "idle"
	creature.debugAI = {
		brainType = state.brainType,
		behaviorState = state.behaviorState,
		targetId = state.targetId,
		intent = state.lastIntent,
	}
end

return AIService
