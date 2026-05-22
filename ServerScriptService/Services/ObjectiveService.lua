local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ObjectiveConfig = require(Config:WaitForChild("ObjectiveConfig"))

local ObjectiveService = {}
ObjectiveService.__index = ObjectiveService

local STATE_NOT_STARTED = "not_started"
local STATE_ACTIVE = "active"
local STATE_COMPLETED = "completed"
local STATE_CLAIMED = "claimed"
local DEBUG_LOG = true

local function debugLog(message)
	if not DEBUG_LOG then return end
	print(string.format("[ObjectiveService] %s", tostring(message)))
end

function ObjectiveService.new(playerDataService, inventoryService, worldService)
	local self = setmetatable({
		playerDataService = playerDataService,
		inventoryService = inventoryService,
		worldService = worldService,
		objectiveClaimedListeners = {},
	}, ObjectiveService)
	self:validateDefinitions()
	return self
end

function ObjectiveService:addObjectiveClaimedListener(listener)
	if type(listener) ~= "function" then return end
	table.insert(self.objectiveClaimedListeners, listener)
end

local function ensureObjectiveState(data)
	data.objectives = data.objectives or {
		byId = {},
		counters = {
			items = {},
			petLevelMax = 1,
		},
		flags = {
			starterChosen = false,
		},
		unlockedFeatures = {},
	}
	return data.objectives
end

local function ensureObjectiveEntry(state, objectiveId)
	state.byId[objectiveId] = state.byId[objectiveId] or {
		id = objectiveId,
		status = STATE_NOT_STARTED,
		progress = 0,
		progressCurrent = 0,
		progressGoal = 1,
		progressText = "0/1",
		completedAt = nil,
		claimedAt = nil,
	}
	return state.byId[objectiveId]
end

function ObjectiveService:validateDefinitions()
	local seen = {}
	print("[ObjectiveService] Validating objectives...")
	for _, objectiveId in ipairs(ObjectiveConfig.Order or {}) do
		if seen[objectiveId] then
			warn(string.format("[ObjectiveService] Duplicate objective id in order: %s", tostring(objectiveId)))
		end
		seen[objectiveId] = true
		local def = ObjectiveConfig.Objectives[objectiveId]
		if not def then
			warn(string.format("[ObjectiveService] Missing objective definition for id in order: %s", tostring(objectiveId)))
		elseif type(def.requirements) ~= "table" or #def.requirements == 0 then
			warn(string.format("[ObjectiveService] Objective has no requirements: %s", tostring(objectiveId)))
		end
	end
end

function ObjectiveService:initPlayer(player)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	state.flags.starterChosen = data.starterChosen == true
	for matKey, amount in pairs(data.materials or {}) do
		state.counters.items[tostring(matKey)] = math.max(0, tonumber(amount) or 0)
	end
	for _, owned in pairs(data.ownedCreatures or {}) do
		state.counters.petLevelMax = math.max(tonumber(state.counters.petLevelMax) or 1, tonumber(owned and owned.level) or 1)
	end
	for _, objectiveId in ipairs(ObjectiveConfig.Order) do
		ensureObjectiveEntry(state, objectiveId)
	end
	print("[ObjectiveService] Player initialized:", player.Name)
	self:evaluateObjectives(player)
end

function ObjectiveService:applyReward(player, reward)
	if not reward then return end
	local rType = tostring(reward.type or "")
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	print("[ObjectiveService] Applying reward:", rType, reward)
	if rType == "unlock_tool" then
		local amount = math.max(1, math.floor(tonumber(reward.amount) or 1))
		local key = tostring(reward.key or "")
		if key ~= "" and self.inventoryService:getCount(player, key) < amount then
			self.inventoryService:grant(player, { { key = key, amount = amount } })
		end
		debugLog(string.format("Reward unlock_tool applied: player=%s key=%s amount=%d", tostring(player.UserId), key, amount))
	elseif rType == "unlock_feature" then
		local key = tostring(reward.key or "")
		if key ~= "" then
			state.unlockedFeatures[key] = true
			player:SetAttribute("Feature_" .. key .. "_unlocked", true)
			debugLog(string.format("Reward unlock_feature applied: player=%s key=%s", tostring(player.UserId), key))
		end
	elseif rType == "grant_item" then
		local amount = math.max(1, math.floor(tonumber(reward.amount) or 1))
		local key = tostring(reward.key or "")
		if key ~= "" then
			self.inventoryService:grant(player, { { key = key, amount = amount } })
			debugLog(string.format("Reward grant_item applied: player=%s key=%s amount=%d", tostring(player.UserId), key, amount))
		end
	end
end

function ObjectiveService:isVisible(state, def)
	local prerequisiteIds = (def.visibility and def.visibility.prerequisiteIds) or {}
	for _, reqId in ipairs(prerequisiteIds) do
		local reqEntry = state.byId[reqId]
		local status = reqEntry and reqEntry.status or STATE_NOT_STARTED
		if status ~= STATE_COMPLETED and status ~= STATE_CLAIMED then
			return false
		end
	end
	return true
end

function ObjectiveService:getRequirementProgress(state, req)
	local reqType = tostring(req.type or "")
	if reqType == "starter_chosen" then
		local current = state.flags.starterChosen and 1 or 0
		return current >= 1 and 1 or 0, current, 1
	elseif reqType == "item_gained" then
		local key = tostring(req.key or "")
		local current = tonumber(state.counters.items[key]) or 0
		local goal = math.max(1, tonumber(req.count) or 1)
		return math.clamp(current / goal, 0, 1), current, goal
	elseif reqType == "item_total" then
		local total = 0
		for _, key in ipairs(req.keys or {}) do
			total = total + (tonumber(state.counters.items[tostring(key)]) or 0)
		end
		local goal = math.max(1, tonumber(req.count) or 1)
		return math.clamp(total / goal, 0, 1), total, goal
	elseif reqType == "pet_level_min" then
		local current = tonumber(state.counters.petLevelMax) or 1
		local goal = math.max(1, tonumber(req.level) or 1)
		return math.clamp(current / goal, 0, 1), current, goal
	elseif reqType == "objective_completed" then
		local id = tostring(req.id or "")
		local entry = state.byId[id]
		local done = entry and (entry.status == STATE_COMPLETED or entry.status == STATE_CLAIMED)
		local current = done and 1 or 0
		return current, current, 1
	elseif reqType == "feature_unlocked" then
		local key = tostring(req.key or "")
		local current = state.unlockedFeatures[key] and 1 or 0
		return current, current, 1
	end
	return 0, 0, 1
end

function ObjectiveService:objectiveIsComplete(state, def)
	local requirements = def.requirements or {}
	if #requirements == 0 then
		return false, 0, 0, 1, "0/1"
	end

	local aggregate = 1
	local totalCurrent = 0
	local totalGoal = 0

	for _, req in ipairs(requirements) do
		local progress, reqCurrent, reqGoal = self:getRequirementProgress(state, req)
		aggregate = math.min(aggregate, progress)

		reqCurrent = tonumber(reqCurrent) or 0
		reqGoal = math.max(1, tonumber(reqGoal) or 1)

		totalCurrent += math.min(reqCurrent, reqGoal)
		totalGoal += reqGoal
	end

	local progressText = string.format(
		"%d/%d",
		math.floor(totalCurrent + 0.5),
		math.max(1, math.floor(totalGoal + 0.5))
	)

	return aggregate >= 1, aggregate, totalCurrent, totalGoal, progressText
end

function ObjectiveService:claimObjective(player, objectiveId, def, entry)
	entry.status = STATE_CLAIMED
	entry.claimedAt = os.clock()
	for _, reward in ipairs(def.rewards or {}) do
		self:applyReward(player, reward)
	end
	self.worldService:pushEventLog(player, string.format("Objective complete: %s", tostring(def.label or objectiveId)), "#a8ffd7")
	for _, listener in ipairs(self.objectiveClaimedListeners or {}) do
		listener(player, objectiveId, def, entry)
	end
end

function ObjectiveService:evaluateObjectives(player)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	local dirty = false
	for _, objectiveId in ipairs(ObjectiveConfig.Order) do
		local def = ObjectiveConfig.Objectives[objectiveId]
		if def then
			local entry = ensureObjectiveEntry(state, objectiveId)
			if self:isVisible(state, def) then
				if entry.status == STATE_NOT_STARTED then
					entry.status = STATE_ACTIVE
					dirty = true
				end
				local complete, progress, current, goal, progressText = self:objectiveIsComplete(state, def)
				local previousProgress = tonumber(entry.progress) or 0
				entry.progress = progress
				entry.progressCurrent = current
				entry.progressGoal = goal
				entry.progressText = progressText
				if math.abs(previousProgress - progress) > 0.0001 then
					debugLog(string.format("Progress updated: player=%s objective=%s progress=%s", tostring(player.UserId), tostring(objectiveId), tostring(entry.progressText)))
				end
				if complete and (entry.status == STATE_ACTIVE or entry.status == STATE_NOT_STARTED) then
					entry.status = STATE_COMPLETED
					entry.completedAt = os.clock()
					debugLog(string.format("Objective completed: player=%s objective=%s", tostring(player.UserId), tostring(objectiveId)))
					dirty = true
				end
				if entry.status == STATE_COMPLETED then
					self:claimObjective(player, objectiveId, def, entry)
					dirty = true
					print(string.format(
						"Claimed objective: player=%s objective=%s",
						tostring(player.UserId),
						tostring(objectiveId)
						))
				end

			end
		end
	end
	
	if dirty then
		self:syncFeatureAttributes(player)
	end
	return dirty
end

function ObjectiveService:syncFeatureAttributes(player)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	for featureKey, unlocked in pairs(state.unlockedFeatures or {}) do
		player:SetAttribute("Feature_" .. tostring(featureKey) .. "_unlocked", unlocked == true)
	end
end

function ObjectiveService:recordObjectiveEvent(player, eventType, payload)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	payload = payload or {}
	local key = tostring(eventType or "")
	debugLog(string.format("Event: player=%s type=%s", tostring(player.UserId), key))
	if key == "starter_chosen" then
		state.flags.starterChosen = true
	elseif key == "item_gained" then
		local itemKey = tostring(payload.key or "")
		if itemKey ~= "" then
			local amount = math.max(0, math.floor(tonumber(payload.amount) or 0))
			state.counters.items[itemKey] = (tonumber(state.counters.items[itemKey]) or 0) + amount
		end
	elseif key == "pet_level_reached" then
		local level = math.max(1, math.floor(tonumber(payload.level) or 1))
		state.counters.petLevelMax = math.max(tonumber(state.counters.petLevelMax) or 1, level)
	elseif key == "feature_unlocked" then
		local feature = tostring(payload.key or "")
		if feature ~= "" then
			state.unlockedFeatures[feature] = true
		end
	end
	return self:evaluateObjectives(player)
end

function ObjectiveService:isObjectiveComplete(player, objectiveId)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	local entry = state.byId[objectiveId]
	if not entry then return false end
	return entry.status == STATE_COMPLETED or entry.status == STATE_CLAIMED
end

function ObjectiveService:isFeatureUnlocked(player, featureKey)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)
	return state.unlockedFeatures[tostring(featureKey or "")] == true
end

function ObjectiveService:getClientSummary(player)
	local data = self.playerDataService:getOrCreate(player)
	local state = ensureObjectiveState(data)

	local activeObjective = nil
	local nextObjective = nil
	local recentlyCompleted = nil
	local allObjectives = {}

	for _, objectiveId in ipairs(ObjectiveConfig.Order) do
		local def = ObjectiveConfig.Objectives[objectiveId]
		local entry = state.byId[objectiveId]

		if def and entry then
			local isVisible = self:isVisible(state, def)
			local item = {
				id = objectiveId,
				label = tostring(def.label or objectiveId),
				description = tostring(def.description or ""),
				category = tostring(def.category or "general"),
				stage = tonumber(def.stage) or 0,
				status = tostring(entry.status or STATE_NOT_STARTED),
				progress = tonumber(entry.progress) or 0,
				progressCurrent = tonumber(entry.progressCurrent) or 0,
				progressGoal = tonumber(entry.progressGoal) or 1,
				progressText = tostring(entry.progressText or "0/1"),
				visibility = isVisible and "visible" or "locked",
			}

			table.insert(allObjectives, item)

			if isVisible and item.status == STATE_ACTIVE and not activeObjective then
				activeObjective = item
			end

			if item.status == STATE_CLAIMED then
				if not recentlyCompleted or (entry.claimedAt or 0) > (recentlyCompleted.claimedAt or 0) then
					recentlyCompleted = {
						id = item.id,
						label = item.label,
						claimedAt = entry.claimedAt or 0,
					}
				end
			end
		end
	end

	table.sort(allObjectives, function(a, b)
		if a.stage == b.stage then
			return a.id < b.id
		end
		return a.stage < b.stage
	end)
	local visibleObjectives = {}
	for _, item in ipairs(allObjectives) do
		if item.visibility == "visible" then
			table.insert(visibleObjectives, item)
		end
	end
	if activeObjective then
		local foundActive = false
		for _, item in ipairs(allObjectives) do
			if item.id == activeObjective.id then
				foundActive = true
			elseif foundActive and item.visibility == "visible" and (item.status == STATE_ACTIVE or item.status == STATE_NOT_STARTED) then
				nextObjective = item
				break
			end
		end
	end

	-- Fallback: first later visible not-started objective.
	if not nextObjective then
		for _, item in ipairs(allObjectives) do
			if item.visibility == "visible" and item.status == STATE_NOT_STARTED then
				nextObjective = item
				break
			end
		end
	end

	local unlocked = {}
	for key, isUnlocked in pairs(state.unlockedFeatures or {}) do
		if isUnlocked == true then
			table.insert(unlocked, key)
		end
	end
	table.sort(unlocked)
	local visibleObjectives = {}
	for _, item in ipairs(allObjectives) do
		if item.visibility == "visible" then
			table.insert(visibleObjectives, item)
		end
	end
	return {
		active = activeObjective and { activeObjective } or {},
		activeObjective = activeObjective,
		nextObjective = nextObjective,
		recentlyCompleted = recentlyCompleted,
		objectives = allObjectives,
		visibleObjectives = visibleObjectives,
		unlockedFeatures = unlocked,
	}
end

return ObjectiveService
