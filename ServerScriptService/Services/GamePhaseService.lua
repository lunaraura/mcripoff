local Players = game:GetService("Players")

local GamePhaseService = {}
GamePhaseService.__index = GamePhaseService

GamePhaseService.PHASE_INTRO = "intro_scene"
GamePhaseService.PHASE_TUTORIAL = "tutorial_phase"
GamePhaseService.PHASE_FULL = "full_game"
GamePhaseService.UNLOCK_OBJECTIVE_ID = "gather_heal_berries"

function GamePhaseService.new(worldService, objectiveService, remotes)
	return setmetatable({
		worldService = worldService,
		objectiveService = objectiveService,
		remotes = remotes,
		playerPhases = {},
	}, GamePhaseService)
end

function GamePhaseService:getPlayerPhase(player)
	return self.playerPhases[player.UserId] or GamePhaseService.PHASE_INTRO
end

function GamePhaseService:isIntroActive(player)
	return self:getPlayerPhase(player) == GamePhaseService.PHASE_INTRO
end

function GamePhaseService:isFullGame(player)
	return self:getPlayerPhase(player) == GamePhaseService.PHASE_FULL
end

function GamePhaseService:applyMovementGate(player, inIntro)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if inIntro then
		if player:GetAttribute("SavedWalkSpeed") == nil then
			player:SetAttribute("SavedWalkSpeed", humanoid.WalkSpeed)
		end
		if player:GetAttribute("SavedJumpPower") == nil then
			player:SetAttribute("SavedJumpPower", humanoid.JumpPower)
		end
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		local walk = tonumber(player:GetAttribute("SavedWalkSpeed")) or 16
		local jump = tonumber(player:GetAttribute("SavedJumpPower")) or 50
		humanoid.WalkSpeed = walk
		humanoid.JumpPower = jump
	end
end

function GamePhaseService:emitPhase(player, reason)
	local phase = self:getPlayerPhase(player)
	player:SetAttribute("GamePhase", phase)
	player:SetAttribute("IntroActive", phase == GamePhaseService.PHASE_INTRO)
	self:applyMovementGate(player, phase == GamePhaseService.PHASE_INTRO)
	if self.remotes and self.remotes.GamePhaseUpdate then
		self.remotes.GamePhaseUpdate:FireClient(player, {
			phase = phase,
			reason = reason or "phase_update",
			t = self.worldService.time,
		})
	end
end

function GamePhaseService:setPlayerPhase(player, phase, reason)
	local prev = self:getPlayerPhase(player)
	if prev == phase then return false end
	self.playerPhases[player.UserId] = phase
	self:emitPhase(player, reason or "phase_changed")
	return true
end

function GamePhaseService:initPlayer(player)
	self.playerPhases[player.UserId] = GamePhaseService.PHASE_INTRO
	self:emitPhase(player, "joined_intro")
	player.CharacterAdded:Connect(function()
		task.wait(0.05)
		self:emitPhase(player, "character_added")
	end)
	-- Safety fallback if client never replies.
	task.delay(25, function()
		if player.Parent and self:isIntroActive(player) then
			self:setPlayerPhase(player, GamePhaseService.PHASE_TUTORIAL, "intro_timeout")
		end
	end)
end

function GamePhaseService:removePlayer(player)
	self.playerPhases[player.UserId] = nil
end

function GamePhaseService:completeIntro(player, reason)
	if not self:isIntroActive(player) then return false end
	return self:setPlayerPhase(player, GamePhaseService.PHASE_TUTORIAL, reason or "intro_complete")
end

function GamePhaseService:onObjectiveProgress(player)
	if self:getPlayerPhase(player) ~= GamePhaseService.PHASE_TUTORIAL then
		return false
	end
	if self.objectiveService:isObjectiveComplete(player, GamePhaseService.UNLOCK_OBJECTIVE_ID) then
		return self:setPlayerPhase(player, GamePhaseService.PHASE_FULL, "tutorial_objective_complete")
	end
	return false
end

function GamePhaseService:isActionBlocked(player)
	return self:isIntroActive(player)
end

function GamePhaseService:getSpawnEligiblePlayers(players)
	local out = {}
	for _, player in ipairs(players or Players:GetPlayers()) do
		if self:isFullGame(player) then
			table.insert(out, player)
		end
	end
	return out
end

return GamePhaseService
