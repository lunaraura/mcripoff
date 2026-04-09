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


local function getAbilityTag(ability)
	local category = ability and ability.category or "melee"
	if category == "utility" or category == "utility_dash" then return "utility" end
	if category == "barrier" or category == "retreat" then return "defensive" end
	if category == "dash" or category == "blink" then return "mobility" end
	return "offensive"
end

local function hasStatus(creature, key)
	return creature and creature.statuses and creature.statuses[key] ~= nil
end

local function isValidEnemy(source, target)
	return target and target.alive and target.team ~= source.team
end

local COMMAND_INTENT_MEMORY = 4.0
local ACTIVE_ASSIST_RANGE = 90

local function scaledMove(dir, stateKey, profile)
	local mults = profile and profile.movementByState or nil
	local scale = (mults and mults[stateKey]) or 1
	if scale <= 0 then return Vector3.zero end
	return dir * scale
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
		lastChosenAbility = nil,
		lastAbilityScoreSummary = nil,
		retainedIntent = { kind = "idle", move = Vector3.zero, targetId = nil, abilityKey = nil },
		isDormant = false,
		idleSleepUntil = 0,
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
	if creature.manualCastState == "pending" and creature.manualCastRequest and self.worldService.time > ((creature.manualCastRequest.createdAt or 0) + 1.5) then
		creature.manualCastState = "rejected"
		creature.manualCastNote = "timeout"
		creature.manualCastRequest = nil
	end
	local state = self:ensureAIState(creature)
	local profile = self:getProfile(creature)
	self:applyProfileSettings(creature, state, profile)
	local now = self.worldService.time

	if creature.mode == "wild" and state.isDormant and now < (state.idleSleepUntil or 0) then
		local wakeRadius = profile.activityRadius or 36
		local nearbyEnemy = self.worldService:findNearestEnemyOf(creature, wakeRadius)
		if not nearbyEnemy then
			self:applyIntent(creature, state, state.retainedIntent or { kind = "idle", move = Vector3.zero, targetId = nil, abilityKey = nil })
			return
		end
		state.isDormant = false
		state.idleSleepUntil = 0
		state.nextThinkAt = now
	end

	if now < (state.nextThinkAt or 0) then
		self:applyIntent(creature, state, state.retainedIntent or { kind = "idle", move = Vector3.zero, targetId = nil, abilityKey = nil })
		return
	end
	state.nextThinkAt = now + (profile.thinkInterval or 0.2)
	local facts = self:sense(creature, state, profile, dt)
	local decision = self:decide(creature, state, profile, facts)
	local intent = self:buildIntent(creature, state, profile, facts, decision)
	local engagedWindow = profile.engagedMemorySeconds or 2.5
	local recentlyEngaged = (creature.lastEngagedAt and (now - creature.lastEngagedAt) <= engagedWindow) or false
	if creature.mode == "wild" and (not recentlyEngaged) and (decision.state == "idle" or decision.state == "roam") and #facts.enemies == 0 then
		state.isDormant = true
		state.idleSleepUntil = now + (profile.idleSleepDuration or 1.5)
		state.nextThinkAt = now + (profile.dormantThinkInterval or 1.0)
	else
		state.isDormant = false
	end
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
	local isActivePet = false
	local designatedTargetId = creature.designatedTargetId
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
		isActivePet = creature.partySlot == activeSlot
		if owner and creature.partySlot then
			local attrKey = string.format("PetDesignatedTargetSlot%d", creature.partySlot)
			designatedTargetId = tonumber(owner:GetAttribute(attrKey))
		end
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
		isActivePet = isActivePet,
		designatedTargetId = designatedTargetId,
		activeDesignatedTargetId = owner and tonumber(owner:GetAttribute("ActiveDesignatedTargetId")) or nil,
		commandOverrideActive = self.worldService.time <= (creature.commandOverrideUntil or 0),
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
	local preferredIds = {
		(facts.command and facts.command.targetId) or nil,
		facts.designatedTargetId,
		state.targetId,
	}
	for _, id in ipairs(preferredIds) do
		local preferred = id and self.worldService:getCreatureById(id) or nil
		if isValidEnemy(creature, preferred) then
			local dPreferred = flatDistance(creature.pos, preferred.pos)
			if dPreferred <= state.disengageRadius then
				state.targetId = preferred.id
				state.targetLockUntil = now + (profile.targetLockSeconds or 1.2)
				state.lastSeenTargetTime = now
				return preferred
			end
		end
	end
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
	local commandMemory = command.type == "move" and 20 or COMMAND_INTENT_MEMORY
	local commandOverrideActive = creature.mode == "pet" and facts.commandOverrideActive
	state.lastCommandIgnoreReason = nil
	if command and command.issuedAt and (now - command.issuedAt) > commandMemory and not commandOverrideActive then
		state.lastCommandIgnoreReason = "command_expired"
		command = { type = "follow", issuedAt = now }
		creature.command = command
	end
	local isManual = facts.controlMode == "MANUAL" and facts.isActivePet
	local suppressAutonomousOffense = isManual
	local autonomousOffenseAllowed = not suppressAutonomousOffense
	local target = nil
	local forcedState = nil
	local commandType = command.type or "follow"
	local allowCommandOffense = false

	if creature.mode == "pet" then
		if commandOverrideActive and command.type == "move" and command.point then
			forcedState = "move"
		elseif commandOverrideActive and command.type == "attack" and command.targetId then
			target = self.worldService:getCreatureById(command.targetId)
			if target and target.alive and target.team ~= creature.team then
				state.targetId = target.id
				forcedState = "chase"
				allowCommandOffense = true
			else
				local fallbackType = "follow"
				if facts.stance == "HOLD" then
					fallbackType = "hold"
				elseif facts.stance == "AGGRESSIVE" then
					fallbackType = "aggressive"
				end
				state.lastCommandIgnoreReason = "attack_target_invalid"
				creature.command = { type = fallbackType, issuedAt = now }
				commandType = creature.command.type
				forcedState = commandType
			end
		elseif command.type == "hold" or facts.stance == "HOLD" then
			forcedState = "hold"
		elseif command.type == "aggressive" or facts.stance == "AGGRESSIVE" then
			forcedState = "aggressive"
		elseif command.type == "follow" or facts.stance == "FOLLOW" then
			forcedState = "follow"
		elseif commandOverrideActive and command.type == "attackNearest" then
			target = self:selectTarget(creature, state, profile, facts)
			forcedState = target and "chase" or "follow"
			allowCommandOffense = target ~= nil
		end
	end

	if creature.mode == "wild" and creature.role == "passive" then
		target = self:selectTarget(creature, state, profile, facts)
		if target then
			state.recentThreatId = target.id
			self:transition(state, "flee")
			return { state = "flee", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > profile.roamRadius then
			self:transition(state, "return")
			return { state = "return", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		self:transition(state, "roam")
		return { state = "roam", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	if forcedState == "move" then
		local moveAnchor = command.point
		local moveDist = moveAnchor and flatDistance(creature.pos, moveAnchor) or math.huge
		if moveAnchor and moveDist > 4 then
			self:transition(state, "move")
			return { state = "move", anchor = moveAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		creature.command = { type = "hold", issuedAt = now }
		commandType = creature.command.type
		forcedState = commandType
	end

	if forcedState == "hold" then
		if autonomousOffenseAllowed then
			target = target or self:selectTarget(creature, state, profile, facts)
			if target and flatDistance(creature.pos, target.pos) <= (facts.holdDefenseRange or profile.holdDefenseRange or 30) then
				self:transition(state, "attack")
				return { state = "attack", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
			end
		end
		self:transition(state, "hold")
		return { state = "hold", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	if forcedState == "follow" then
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > state.leashRadius then
			self:transition(state, "return")
			return { state = "return", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		if autonomousOffenseAllowed then
			target = self:selectTarget(creature, state, profile, facts)
			if target then
				local d = flatDistance(creature.pos, target.pos)
				if d <= profile.preferredRange then
					self:transition(state, "attack")
					return { state = "attack", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
				end
				self:transition(state, "chase")
				return { state = "chase", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
			end
		end
		self:transition(state, "follow")
		return { state = "follow", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	if forcedState == "aggressive" then
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > state.leashRadius then
			self:transition(state, "return")
			return { state = "return", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		if autonomousOffenseAllowed then
			target = self:selectTarget(creature, state, profile, facts)
			if target then
				local d = flatDistance(creature.pos, target.pos)
				if d <= profile.preferredRange then
					self:transition(state, "attack")
					return { state = "attack", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
				end
				self:transition(state, "chase")
				return { state = "chase", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
			end
		end
		self:transition(state, "follow")
		return { state = "follow", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	if forcedState == "chase" and target then
		if flatDistance(creature.pos, target.pos) <= profile.preferredRange then
			self:transition(state, "attack")
			return { state = "attack", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		self:transition(state, "chase")
		return { state = "chase", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end
	if creature.mode == "pet" and facts.commandOverrideActive and (command.type == "follow" or command.type == "hold" or command.type == "aggressive") then
		local commandState = command.type == "hold" and "hold" or (command.type == "aggressive" and "aggressive" or "follow")
		self:transition(state, commandState)
		return { state = commandState, anchor = state.roamAnchor, forcedState = commandState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	target = autonomousOffenseAllowed and self:selectTarget(creature, state, profile, facts) or nil
	if not target and creature.mode == "pet" and (not facts.isActivePet) and facts.activeDesignatedTargetId then
		local activeDesignated = self.worldService:getCreatureById(facts.activeDesignatedTargetId)
		if isValidEnemy(creature, activeDesignated) then
			local dAssist = flatDistance(creature.pos, activeDesignated.pos)
			if dAssist <= ACTIVE_ASSIST_RANGE then
				target = activeDesignated
			end
		end
	end
	if not target and facts.designatedTargetId then
		local designated = self.worldService:getCreatureById(facts.designatedTargetId)
		if isValidEnemy(creature, designated) and flatDistance(creature.pos, designated.pos) <= state.disengageRadius then
			target = designated
		end
	end
	if target then
		local d = flatDistance(creature.pos, target.pos)
		if d <= profile.preferredRange then
			self:transition(state, "attack")
			return { state = "attack", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		self:transition(state, "chase")
		return { state = "chase", target = target, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	state.targetId = nil
	if creature.mode == "pet" then
		local anchorDist = flatDistance(creature.pos, state.roamAnchor)
		if anchorDist > 4 then
			self:transition(state, "follow")
			return { state = "follow", anchor = state.roamAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
		end
		self:transition(state, "idle")
		return { state = "idle", forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end

	local homeDist = flatDistance(creature.pos, state.homeAnchor)
	if homeDist > profile.roamRadius then
		self:transition(state, "return")
		return { state = "return", anchor = state.homeAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
	end
	self:transition(state, "roam")
	return { state = "roam", anchor = state.homeAnchor, forcedState = forcedState, commandType = commandType, suppressAutonomousOffense = suppressAutonomousOffense, allowCommandOffense = allowCommandOffense }
end


function AIService:evaluateAbility(creature, target, abilityKey, state, profile, facts)
	local ability = AbilityConfig[abilityKey]
	if not ability then
		return nil
	end
	if (creature.cooldowns[abilityKey] or 0) > 0 then
		return nil
	end
	if (ability.resourceUse and (ability.resourceUse.stamina or 0) or 0) > creature.currentStamina then
		return nil
	end
	if (ability.resourceUse and (ability.resourceUse.energy or 0) or 0) > creature.currentEnergy then
		return nil
	end
	local selfHpRatio = creature.currentHP / math.max(1, creature.modifiedStats.maxHP)
	local targetHpRatio = target and (target.currentHP / math.max(1, target.modifiedStats.maxHP)) or 1
	local dist = target and flatDistance(creature.pos, target.pos) or math.huge
	local abilityRange = ability.range or 20
	local tag = getAbilityTag(ability)
	if tag == "offensive" and dist > abilityRange and tag ~= "mobility" then
		return nil
	end
	local tactical = profile.tactical or {}
	local score = 0
	local reason = "baseline"
	if tag == "offensive" then
		local dmgEstimate = (ability.flatDmg and (ability.flatDmg.p or 0) + (ability.flatDmg.e or 0) or 0)
		dmgEstimate += (ability.dmgScale and (ability.dmgScale.p or 0) * creature.modifiedStats.pAtk + (ability.dmgScale.e or 0) * creature.modifiedStats.eAtk or 0)
		score += dmgEstimate * 0.12 + (tactical.offensive or 0)
		reason = "offensive_damage"
		if dist <= abilityRange then score += 10 else score -= 12 end
		if targetHpRatio <= 0.35 then score += 3 end
	end
	if tag == "mobility" then
		score += (tactical.mobility or 0)
		reason = "mobility_position"
		if state.behaviorState == "chase" and dist > profile.preferredRange then
			score += 9
		else
			score -= 8
		end
	end
	if tag == "defensive" then
		score += (tactical.defensive or 0)
		reason = "defensive_safety"
		if selfHpRatio < 0.45 then
			score += 12
		else
			score -= 4
		end
	end
	if tag == "utility" then
		score += (tactical.utility or 0)
		reason = "utility_timing"
		if selfHpRatio < 0.65 then score += 4 end
	end

	local tags = {}
	for _, t in ipairs(ability.effectTags or {}) do tags[t] = true end
	if tags.electric and hasStatus(target, "wet") then
		score += 8
		reason = "reaction_wet_electric"
	end
	if tags.water and hasStatus(target, "burn") then
		score += 6
		reason = "reaction_wet_cools_burn"
	end
	if tags.impact and hasStatus(target, "guard") then
		score -= 4
	end
	for _, spec in ipairs(ability.statusOnHit or {}) do
		if not hasStatus(target, spec.key) then
			score += 4 + (tactical.status or 0)
			reason = "apply_status_" .. tostring(spec.key)
		end
	end
	if state.behaviorState == "flee" or state.behaviorState == "return" or state.behaviorState == "roam" then
		if tag == "offensive" then score -= 30 end
	end
	if creature.role == "passive" and tag == "offensive" then
		score -= 40
	end
	if dist > abilityRange and tag ~= "mobility" then
		score -= 6
	end
	return { key = abilityKey, score = score, reason = reason, tag = tag }
end

function AIService:pickAbilityForTarget(creature, target, state, profile, facts)
	if not target then return nil, nil end
	local best = nil
	local top = {}
	for _, key in ipairs(creature.moveset or {}) do
		local entry = self:evaluateAbility(creature, target, key, state, profile, facts)
		if entry then
			table.insert(top, entry)
			if (not best) or entry.score > best.score then
				best = entry
			end
		end
	end
	table.sort(top, function(a, b)
		return a.score > b.score
	end)
	local summary = {}
	for i = 1, math.min(3, #top) do
		local e = top[i]
		table.insert(summary, string.format("%s=%.1f[%s]", e.key, e.score, e.reason))
	end
	return best and best.key or nil, table.concat(summary, ", ")
end

function AIService:buildIntent(creature, state, profile, facts, decision)
	local intent = {
		kind = decision.state,
		move = Vector3.zero,
		targetId = nil,
		abilityKey = nil,
		debugMeta = {
			commandType = decision.commandType or "follow",
			forcedState = decision.forcedState or "none",
			decisionState = decision.state,
			commandOverrideActive = facts.commandOverrideActive == true,
			commandOverrideUntil = creature.commandOverrideUntil or 0,
			designatedTargetId = facts.designatedTargetId,
			suppressAutonomousOffense = decision.suppressAutonomousOffense == true,
			allowCommandOffense = decision.allowCommandOffense == true,
			commandIgnoreReason = state.lastCommandIgnoreReason,
		},
	}
	local manualReq = creature.manualCastRequest
	if decision.target then
		state.targetId = decision.target.id
		intent.targetId = decision.target.id
	end

	if decision.state == "move" then
		local dir, d = unitFlat(creature.pos, decision.anchor)
		if d > 3 then intent.move = scaledMove(dir, "move", profile) end
		return intent
	end
	if decision.state == "chase" then
		local dir = unitFlat(creature.pos, decision.target.pos)
		intent.move = scaledMove(dir, "chase", profile)
		intent.kind = "chase"
		return intent
	end
	if decision.state == "attack" then
		local dir, d = unitFlat(creature.pos, decision.target.pos)
		if d > profile.preferredRange then intent.move = scaledMove(dir, "chase", profile) end
		local abilityKey, summary = nil, nil
		if manualReq and manualReq.abilityKey then
			abilityKey = manualReq.abilityKey
			intent.targetId = manualReq.targetId or intent.targetId
			creature.manualCastRequest = nil
			creature.manualCastState = "accepted"
			creature.manualCastNote = "queued"
			summary = "manual_cast"
		elseif (not decision.suppressAutonomousOffense) or decision.allowCommandOffense then
			abilityKey, summary = self:pickAbilityForTarget(creature, decision.target, state, profile, facts)
		end
		intent.abilityKey = abilityKey
		state.lastAbilityScoreSummary = summary
		state.lastChosenAbility = abilityKey
		return intent
	end
	if decision.state == "follow" or decision.state == "return" then
		local dir, d = unitFlat(creature.pos, decision.anchor)
		if d > 3 then intent.move = scaledMove(dir, decision.state, profile) end
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
			intent.move = scaledMove(dir, "return", profile)
		else
			intent.move = scaledMove(Vector3.new(math.cos(angle), 0, math.sin(angle)), "roam", profile)
		end
		return intent
	end
	if decision.state == "flee" then
		local away = unitFlat(decision.target.pos, creature.pos)
		intent.move = scaledMove(away, "flee", profile)
		return intent
	end
	if decision.state == "hold" then
		intent.move = Vector3.zero
		if manualReq and manualReq.abilityKey then
			intent.abilityKey = manualReq.abilityKey
			intent.targetId = manualReq.targetId
			creature.manualCastRequest = nil
			creature.manualCastState = "accepted"
			creature.manualCastNote = "queued"
		end
		return intent
	end
	if manualReq and manualReq.abilityKey then
		intent.abilityKey = manualReq.abilityKey
		intent.targetId = manualReq.targetId
		creature.manualCastRequest = nil
		creature.manualCastState = "accepted"
		creature.manualCastNote = "queued"
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
		lastChosenAbility = state.lastChosenAbility,
		abilityScoreSummary = state.lastAbilityScoreSummary,
		controlMode = creature.ownerUserId and tostring((Players:GetPlayerByUserId(creature.ownerUserId) and Players:GetPlayerByUserId(creature.ownerUserId):GetAttribute("PetControlMode")) or "AUTO") or "-",
		persistentStance = creature.ownerUserId and tostring((Players:GetPlayerByUserId(creature.ownerUserId) and Players:GetPlayerByUserId(creature.ownerUserId):GetAttribute("PetStance")) or "FOLLOW") or "-",
		manualCastState = creature.manualCastState,
		commandOverride = self.worldService.time <= (creature.commandOverrideUntil or 0),
		commandOverrideUntil = creature.commandOverrideUntil or 0,
		currentCommandType = intent.debugMeta and intent.debugMeta.commandType or "follow",
		commandTargetId = creature.command and tonumber(creature.command.targetId) or nil,
		forcedState = intent.debugMeta and intent.debugMeta.forcedState or "none",
		decisionState = intent.debugMeta and intent.debugMeta.decisionState or state.behaviorState,
		designatedTargetId = intent.debugMeta and intent.debugMeta.designatedTargetId or creature.designatedTargetId,
		suppressAutonomousOffense = intent.debugMeta and intent.debugMeta.suppressAutonomousOffense or false,
		allowCommandOffense = intent.debugMeta and intent.debugMeta.allowCommandOffense or false,
		commandIgnoreReason = intent.debugMeta and tostring(intent.debugMeta.commandIgnoreReason or "-") or "-",
		intendedMove = string.format("%.2f,%.2f,%.2f", creature.intent.move.X, creature.intent.move.Y, creature.intent.move.Z),
		nextThinkAt = state.nextThinkAt or 0,
		idleSleepUntil = state.idleSleepUntil or 0,
		isDormant = state.isDormant == true,
	}
	state.retainedIntent = {
		kind = intent.kind or "idle",
		move = intent.move or Vector3.zero,
		targetId = intent.targetId,
		abilityKey = nil,
	}
end


return AIService
