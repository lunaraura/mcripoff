local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))
local Items = Shared:WaitForChild("Items")
local ItemUseRules = require(Items:WaitForChild("ItemUseRules"))

local UIController = {}
UIController.__index = UIController

local function attachSizeConstraint(guiObject, minX, minY, maxX, maxY)
	local c = Instance.new("UISizeConstraint")
	c.MinSize = Vector2.new(minX, minY)
	c.MaxSize = Vector2.new(maxX, maxY)
	c.Parent = guiObject
	return c
end

local UI_MODE_STARTER = "starter"
local UI_MODE_GAMEPLAY = "gameplay"

local function getStarterPanel()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if not playerGui then return nil end
	local starterGui = playerGui:FindFirstChild("StarterPickerUI")
	if not starterGui then return nil end
	return starterGui:FindFirstChild("StarterPanel")
end

function UIController:setUtilityPanelsVisibility(opts)
	opts = opts or {}
	self.optionsOpen = opts.options == true
	self.managementState.open = opts.management == true
	self:refreshUiMode()
	if self.managementState.open then
		self.managementState.layer = self.managementState.layer or "root"
		self:refreshCreatureManagementMenu()
	end
end

function UIController:fitPanelToChildren(panel, minHeight, maxHeight, padding)
	if not panel then return end
	local basePosY = panel.AbsolutePosition.Y
	local bottom = basePosY
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local childBottom = child.AbsolutePosition.Y + child.AbsoluteSize.Y
			if childBottom > bottom then
				bottom = childBottom
			end
		end
	end
	local contentHeight = math.max(minHeight or 0, math.floor((bottom - basePosY) + (padding or 0) + 0.5))
	if maxHeight then
		contentHeight = math.min(contentHeight, maxHeight)
	end
	panel.Size = UDim2.new(panel.Size.X.Scale, panel.Size.X.Offset, 0, contentHeight)
end

function UIController:setUiMode(mode)
	local nextMode = (mode == UI_MODE_GAMEPLAY) and UI_MODE_GAMEPLAY or UI_MODE_STARTER
	if self.uiMode ~= nextMode then
		self.uiMode = nextMode
	end
	self:refreshUiMode()
end

function UIController:refreshUiMode()
	local inGameplay = self.uiMode == UI_MODE_GAMEPLAY
	local showGameplay = inGameplay and (not self.hiddenUi)
	local starterPanel = getStarterPanel()
	if starterPanel then
		starterPanel.Visible = (self.uiMode == UI_MODE_STARTER)
	end
	if self.mainGameplayHud then
		self.mainGameplayHud.Visible = showGameplay
	end
	if self.alwaysObjectiveLine then
		self.alwaysObjectiveLine.Visible = inGameplay
	end
	if self.buildToolPanel then
		self.buildToolPanel.Visible = showGameplay
	end
	if self.itemBarPanel then
		self.itemBarPanel.Visible = showGameplay
	end
	if self.optionsPanel then
		self.optionsPanel.Visible = showGameplay and self.optionsOpen == true
	end
	if self.managementPanel then
		self.managementPanel.Visible = showGameplay and self.managementState.open == true
	end
	if self.hideUiButton then
		self.hideUiButton.Text = self.hiddenUi and "Show UI" or "Hide UI"
		self.hideUiButton.Visible = inGameplay
	end
	if self.mobilePlaceBuildButton then
		local buildMode = self.build and self.build.buildMode
		self.mobilePlaceBuildButton.Visible = showGameplay and UserInputService.TouchEnabled and (buildMode == true)
	end
	if self.objectiveToastLabel and not showGameplay then
		self.objectiveToastLabel.Visible = false
	end
end

function UIController:openOptionsFromUtilityPanel()
	self:setUtilityPanelsVisibility({
		options = true,
		management = false,
	})
end

function UIController:openCreatureManagementFromUtilityPanel()
	self:setUtilityPanelsVisibility({
		options = false,
		management = true,
	})
	self.managementState.layer = "root"
	self:refreshCreatureManagementMenu()
end

function UIController.new(buildController, itemController, partyController, commandController)
	return setmetatable({
		floatingTextEvent = remotes:WaitForChild("FloatingTextEvent"),
		eventLogEvent = remotes:WaitForChild("EventLogEvent"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		manualCastResult = remotes:WaitForChild("ManualCastResult"),
		requestClientOption = remotes:WaitForChild("RequestClientOption"),
		requestContextAction = remotes:WaitForChild("RequestContextAction"),
		requestCreatureManageRemote = remotes:WaitForChild("RequestCreatureManage"),
		creatureManageResultRemote = remotes:WaitForChild("CreatureManageResult"),
		build = buildController,
		items = itemController,
		party = partyController,
		command = commandController,
		hudLabels = {},
		logLabels = {},
		optionRows = {},
		optionValues = {
			RadiusChunks = 2,
			PetLeashDistance = 90,
			PetHoldDefenseRange = 30,
		},
		maxLogLines = 6,
		activeSlot = 1,
		controlMode = "AUTO",
		stance = "FOLLOW",
		activeDesignatedTargetId = nil,
		lastManualCast = nil,
		activePetHud = nil,
		uiMode = UI_MODE_STARTER,
		starterChosen = false,
		optionsOpen = false,
		hiddenUi = false,
		hotbarSlots = {},
		hotbarStatusLabel = nil,
		activeCommand = "follow",
		managementData = { party = {}, reserve = {}, items = {} },
		objectiveSummary = { active = {}, objectives = {}, unlockedFeatures = {} },
		lastObjectiveProgressText = nil,
		knownUnlockedFeatures = {},
		lastObjectiveToastId = nil,
		lastObjectiveToastAt = 0,
		itemBarWindowStart = 1,
		managementState = { layer = "root", selected = nil, open = false, pendingSwapPartySlot = nil, selectedItemKey = nil },
	}, UIController)
end

function UIController:bind()
	self:buildUi()
	for key, value in pairs(self.optionValues) do
		self.requestClientOption:FireServer({ key = key, value = value })
	end
	self.floatingTextEvent.OnClientEvent:Connect(function(payload)
		self:spawnFloatingWorldText(payload)
	end)
	self.eventLogEvent.OnClientEvent:Connect(function(payload)
		self:appendLog(payload.text, payload.color)
	end)
	self.petHudUpdate.OnClientEvent:Connect(function(payload)
		local meta = payload and payload.meta or {}
		self.activeSlot = tonumber(meta.activeSlot) or self.activeSlot
		self.controlMode = tostring(meta.controlMode or self.controlMode)
		self.stance = tostring(meta.stance or self.stance)
		if meta.starterChosen ~= nil then
			self.starterChosen = meta.starterChosen == true
		end
		self:setUiMode(self.starterChosen and UI_MODE_GAMEPLAY or UI_MODE_STARTER)
		self.activeDesignatedTargetId = tonumber(meta.activeDesignatedTargetId)
		self:updatePetHud(payload)
		self.managementData = meta.management or self.managementData
		local previousSummary = self.objectiveSummary
		self.objectiveSummary = meta.objectives or self.objectiveSummary
		self:refreshObjectiveHud()
		self:refreshObjectiveList()
		self:emitObjectiveDeltaFeedback(previousSummary, self.objectiveSummary)
		self:refreshCreatureManagementMenu()
		
	end)
	self.creatureManageResultRemote.OnClientEvent:Connect(function(payload)
		if payload and payload.reason then
			local color = payload.ok and "#a8ffd7" or "#ffb3b3"
			self:appendLog(string.format("Manage[%s]: %s", tostring(payload.action or "?"), tostring(payload.reason)), color)
		end
	end)
	self.manualCastResult.OnClientEvent:Connect(function(payload)
		self.lastManualCast = payload
		local color = payload and payload.ok and "#a8ffd7" or "#ffb3b3"
		self:appendLog(string.format("ManualCast[%s] slot=%s ability=%s type=%s", tostring(payload and payload.code or "?"), tostring(payload and payload.slot or "-"), tostring(payload and payload.abilityKey or "-"), tostring(payload and payload.targetType or "-")), color)
		self:refreshAbilityHotbar()
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.O then
			self:toggleOptionsMenu()
		elseif input.KeyCode == Enum.KeyCode.M then
			self:toggleCreatureManagementMenu()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:managementBack()
		end
	end)
end

function UIController:emitObjectiveDeltaFeedback(previousSummary, nextSummary)
	local prev = previousSummary or {}
	local nextState = nextSummary or {}
	local prevActive = prev.activeObjective
	local nextActive = nextState.activeObjective
	local prevProgress = prevActive and tostring(prevActive.progressText or "") or ""
	local nextProgress = nextActive and tostring(nextActive.progressText or "") or ""
	if nextActive and nextProgress ~= "" and prevProgress ~= nextProgress then
		print(string.format("[UIObjective] progress %s -> %s (%s)", prevProgress, nextProgress, tostring(nextActive.id or nextActive.label or "?")))
		if prevProgress ~= "" then
			self:showObjectiveToast(string.format("%s progress: %s", tostring(nextActive.label or nextActive.id or "Objective"), nextProgress))
		end
	end
	local unlocked = {}
	for _, key in ipairs(nextState.unlockedFeatures or {}) do
		unlocked[tostring(key)] = true
		if not self.knownUnlockedFeatures[tostring(key)] then
			print(string.format("[UIObjective] unlocked feature: %s", tostring(key)))
			self:showObjectiveToast(string.format("Unlocked: %s", tostring(key)))
		end
	end
	self.knownUnlockedFeatures = unlocked
end

function UIController:buildUi()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	-- Hide UI button
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "HideUIButton"
	hideBtn.AnchorPoint = Vector2.new(0, 0)
	hideBtn.Size = UDim2.new(0.14, 0, 0.045, 0)
	hideBtn.Position = UDim2.new(0.015, 0, 0.015, 0)
	hideBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	hideBtn.TextColor3 = Color3.fromRGB(235, 245, 255)
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 12
	hideBtn.Text = "Hide UI"
	hideBtn.Parent = gui
	self.hideUiButton = hideBtn
	attachSizeConstraint(hideBtn, 88, 28, 180, 44)

	hideBtn.MouseButton1Click:Connect(function()
		self.hiddenUi = not self.hiddenUi
		self:refreshUiMode()
	end)

		-- Main gameplay HUD (stance controls + ability hotbar only)
	local activeHud = Instance.new("Frame")
	activeHud.Name = "MainGameplayHud"
	activeHud.AnchorPoint = Vector2.new(0.5, 1)
	activeHud.Size = UDim2.new(0.62, 0, 0.13, 0)
	activeHud.Position = UDim2.new(0.5, 0, 0.89, 0)
	activeHud.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	activeHud.BackgroundTransparency = 0.12
	activeHud.Parent = gui
	self.mainGameplayHud = activeHud
	self.activePetFrame = activeHud
	attachSizeConstraint(activeHud, 320, 84, 860, 152)

	local objectiveToast = Instance.new("TextLabel")
	objectiveToast.Name = "ObjectiveToastLabel"
	objectiveToast.BackgroundColor3 = Color3.fromRGB(24, 42, 28)
	objectiveToast.BackgroundTransparency = 0.2
	objectiveToast.Size = UDim2.fromOffset(300, 24)
	objectiveToast.AnchorPoint = Vector2.new(0.5, 1)
	objectiveToast.Position = UDim2.new(0.5, 0, 0.84, 0)
	objectiveToast.Font = Enum.Font.GothamBold
	objectiveToast.TextSize = 12
	objectiveToast.TextColor3 = Color3.fromRGB(210, 255, 210)
	objectiveToast.Visible = false
	objectiveToast.Text = ""
	objectiveToast.Parent = gui
	self.objectiveToastLabel = objectiveToast

	local alwaysObjective = Instance.new("TextLabel")
	alwaysObjective.Name = "AlwaysObjectiveLine"
	alwaysObjective.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
	alwaysObjective.BackgroundTransparency = 0.22
	alwaysObjective.AnchorPoint = Vector2.new(0.5, 0)
	alwaysObjective.Size = UDim2.fromOffset(420, 22)
	alwaysObjective.Position = UDim2.new(0.5, 0, 0.015, 0)
	alwaysObjective.Font = Enum.Font.Code
	alwaysObjective.TextSize = 12
	alwaysObjective.TextColor3 = Color3.fromRGB(230, 240, 255)
	alwaysObjective.Text = "Objective: --"
	alwaysObjective.Visible = false
	alwaysObjective.Parent = gui
	self.alwaysObjectiveLine = alwaysObjective
	attachSizeConstraint(alwaysObjective, 180, 20, 520, 26)

	self:buildCommandPanel(activeHud)
	self:buildAbilityHotbar(activeHud)
	self:buildOptionsMenu(gui)
	self:buildBuildAndToolMenu(gui)
	self:buildItemBar(gui)
	self:buildCreatureManagementMenu(gui)

	-- utility/build menu should be top-right compact
	if self.buildToolPanel then
		self.buildToolPanel.AnchorPoint = Vector2.new(1, 0)
		self.buildToolPanel.Position = UDim2.new(0.99, 0, 0.07, 0)
	end

	self:setUiMode(UI_MODE_STARTER)
	self:refreshObjectiveHud()
	self:fitPanelToChildren(self.mainGameplayHud, 96, 170, 8)
	self:fitPanelToChildren(self.itemBarPanel, 72, 140, 10)
	self:fitPanelToChildren(self.buildToolPanel, 220, 520, 12)
	self:fitPanelToChildren(self.optionsPanel, 150, 340, 8)
end

function UIController:toggleCommandPanelMode()
	self:refreshCommandPanel()
end

function UIController:sendCommandFromUi(kind)
	if not self.command then return end
	if kind == "follow" then
		if self.party then self.party:setStance("FOLLOW") end
		self.command:sendCommand({ type = "setStance", stance = "FOLLOW" })
	elseif kind == "hold" then
		if self.party then self.party:setStance("HOLD") end
		self.command:sendCommand({ type = "setStance", stance = "HOLD" })
	elseif kind == "attack" then
		if self.party then self.party:setStance("AGGRESSIVE") end
		self.command:sendCommand({ type = "setStance", stance = "AGGRESSIVE" })
	end
	self.activeCommand = kind
	self:refreshCommandPanel()
end

function UIController:refreshCommandPanel()
	for key, btn in pairs(self.commandButtons or {}) do
		btn.BackgroundColor3 = (self.activeCommand == key) and Color3.fromRGB(70, 105, 145) or Color3.fromRGB(40, 45, 58)
	end
end

function UIController:showObjectiveToast(text)
	if not self.objectiveToastLabel then return end
	self.objectiveToastLabel.Text = tostring(text or "")
	self.objectiveToastLabel.Visible = true
	local token = os.clock()
	self.lastObjectiveToastAt = token
	task.delay(2.0, function()
		if self.objectiveToastLabel and self.lastObjectiveToastAt == token then
			self.objectiveToastLabel.Visible = false
		end
	end)
end

function UIController:refreshObjectiveHud()
	local summary = self.objectiveSummary or {}
	local active = summary.activeObjective or ((summary.active and summary.active[1]) or nil)
	local nextObj = summary.nextObjective
	if active then
		local progressText = tostring(active.progressText or string.format("%d/%d", tonumber(active.progressCurrent) or 0, tonumber(active.progressGoal) or 1))
		local line = string.format("Objective: %s (%s)", tostring(active.label or active.id or "--"), progressText)
		if self.objectiveLabel then
			self.objectiveLabel.Text = line
		end
		if self.alwaysObjectiveLine then
			self.alwaysObjectiveLine.Text = line
		end
	elseif nextObj then
		local line = string.format("Next: %s", tostring(nextObj.label or nextObj.id or "--"))
		if self.objectiveLabel then
			self.objectiveLabel.Text = line
		end
		if self.alwaysObjectiveLine then
			self.alwaysObjectiveLine.Text = line
		end
	else
		if self.objectiveLabel then
			self.objectiveLabel.Text = "Objectives complete"
		end
		if self.alwaysObjectiveLine then
			self.alwaysObjectiveLine.Text = "Objectives complete"
		end
	end
	local recentlyCompleted = summary.recentlyCompleted
	local toastId = recentlyCompleted and tostring(recentlyCompleted.id) or nil
	if toastId and toastId ~= self.lastObjectiveToastId then
		self.lastObjectiveToastId = toastId
		self:showObjectiveToast(string.format("Objective complete: %s", tostring(recentlyCompleted.label or toastId)))
	end
end

function UIController:refreshObjectiveList()
	if not self.objectiveListScroll then return end

	local objectives = (self.objectiveSummary and self.objectiveSummary.visibleObjectives) or {}
	local sigParts = {}
	for _, obj in ipairs(objectives) do
		table.insert(sigParts, string.format(
			"%s|%s|%s|%s",
			tostring(obj.id or ""),
			tostring(obj.status or ""),
			tostring(obj.progressText or ""),
			tostring(obj.visibility or "")
			))
	end
	local signature = table.concat(sigParts, "||")
	if self.lastObjectiveListSignature == signature then
		return
	end
	self.lastObjectiveListSignature = signature

	local list = self.objectiveListScroll
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") and child.Name == "ObjectiveRow" then
			child:Destroy()
		end
	end

	local y = 0
	for _, obj in ipairs(objectives) do
		if obj and obj.visibility ~= "locked" and tostring(obj.label or "") ~= "" then
			local row = Instance.new("TextLabel")
			row.Name = "ObjectiveRow"
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -8, 0, 18)
			row.Position = UDim2.fromOffset(4, y)
			row.Font = Enum.Font.Code
			row.TextSize = 11
			row.TextXAlignment = Enum.TextXAlignment.Left

			local prefix = "[UPCOMING]"
			local color = Color3.fromRGB(190, 210, 230)
			if obj.status == "active" then
				prefix = "[ACTIVE]"
				color = Color3.fromRGB(215, 235, 180)
			elseif obj.status == "claimed" or obj.status == "completed" then
				prefix = "[DONE]"
				color = Color3.fromRGB(160, 235, 170)
			end

			row.TextColor3 = color
			local progressText = tostring(obj.progressText or "")
			row.Text = string.format(
				"%s %s%s",
				prefix,
				tostring(obj.label or obj.id or "--"),
				(progressText ~= "" and (" (" .. progressText .. ")") or "")
			)
			row.Parent = list
			y += 19
		end
	end

	list.CanvasSize = UDim2.fromOffset(0, math.max(y, 0))
end

function UIController:buildCommandPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "CommandPanel"
	panel.Size = UDim2.new(1, -12, 0, 26)
	panel.Position = UDim2.fromOffset(6, 6)
	panel.BackgroundTransparency = 1
	panel.Parent = parent
	self.commandPanel = panel

	local function makeButton(text, x, key)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(96, 22)
		b.Position = UDim2.fromOffset(x, 2)
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = Color3.fromRGB(230, 240, 255)
		b.BackgroundColor3 = Color3.fromRGB(40, 45, 58)
		b.Parent = panel
		b.MouseButton1Click:Connect(function()
			self:sendCommandFromUi(key)
		end)
		return b
	end

	self.commandButtons = {
		follow = makeButton("Follow", 0, "follow"),
		hold = makeButton("Hold", 102, "hold"),
		attack = makeButton("Attack", 204, "attack"),
	}

	self:refreshCommandPanel()
end

function UIController:buildOptionsMenu(gui)
	local panel = Instance.new("Frame")
	panel.Name = "OptionsPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Size = UDim2.new(0.28, 0, 0.26, 0)
	panel.Position = UDim2.new(0.99, 0, 0.02, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.ZIndex = 40
	panel.Visible = false
	panel.Parent = gui
	self.optionsPanel = panel
	attachSizeConstraint(panel, 250, 170, 420, 300)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Options (O to toggle)"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Size = UDim2.new(1, -12, 0, 22)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 41
	title.Parent = panel

	self:createOptionRow(panel, 1, "RadiusChunks", "Chunk Radius", 2, 31, 1)
	self:createOptionRow(panel, 2, "PetLeashDistance", "Pet Leash", 35, 160, 5)
	self:createOptionRow(panel, 3, "PetHoldDefenseRange", "Hold Defense", 10, 60, 2)
end

function UIController:createOptionRow(panel, row, key, label, minV, maxV, step)
	local y = 30 + (row - 1) * 42
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextSize = 13
	text.TextColor3 = Color3.fromRGB(220, 235, 255)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Size = UDim2.fromOffset(160, 22)
	text.Position = UDim2.fromOffset(10, y)
	text.ZIndex = 41
	text.Parent = panel

	local minus = Instance.new("TextButton")
	minus.Text = "-"
	minus.Font = Enum.Font.GothamBold
	minus.TextSize = 16
	minus.Size = UDim2.fromOffset(26, 22)
	minus.Position = UDim2.fromOffset(172, y)
	minus.ZIndex = 41
	minus.Parent = panel

	local plus = Instance.new("TextButton")
	plus.Text = "+"
	plus.Font = Enum.Font.GothamBold
	plus.TextSize = 16
	plus.Size = UDim2.fromOffset(26, 22)
	plus.Position = UDim2.fromOffset(238, y)
	plus.ZIndex = 41
	plus.Parent = panel

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.Code
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.Size = UDim2.fromOffset(36, 22)
	valueLabel.Position = UDim2.fromOffset(200, y)
	valueLabel.ZIndex = 41
	valueLabel.Parent = panel

	local function refresh()
		local v = self.optionValues[key]
		text.Text = label
		valueLabel.Text = tostring(math.floor(v + 0.5))
	end

	local function apply(delta)
		local v = self.optionValues[key]
		v = math.clamp(v + delta, minV, maxV)
		self.optionValues[key] = v
		refresh()
		self.requestClientOption:FireServer({ key = key, value = v })
	end

	minus.MouseButton1Click:Connect(function() apply(-step) end)
	plus.MouseButton1Click:Connect(function() apply(step) end)
	refresh()
	self.optionRows[key] = { text = text, value = valueLabel }
end

function UIController:toggleOptionsMenu()
	if self.uiMode ~= UI_MODE_GAMEPLAY then return end
	if not self.optionsPanel then return end
	local nextVisible = not self.optionsPanel.Visible
	self:setUtilityPanelsVisibility({
		options = nextVisible,
		management = false,
	})
end

function UIController:buildBuildAndToolMenu(gui)
	local panel = Instance.new("Frame")
	panel.Name = "BuildToolPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Size = UDim2.new(0.30, 0, 0.42, 0)
	panel.Position = UDim2.new(0.99, 0, 0.08, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui
	self.buildToolPanel = panel
	attachSizeConstraint(panel, 250, 240, 420, 460)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Build / Action"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Size = UDim2.new(1, -12, 0, 20)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local hubTitle = Instance.new("TextLabel")
	hubTitle.BackgroundTransparency = 1
	hubTitle.Size = UDim2.fromOffset(302, 18)
	hubTitle.Position = UDim2.fromOffset(9, 28)
	hubTitle.TextXAlignment = Enum.TextXAlignment.Left
	hubTitle.Font = Enum.Font.Code
	hubTitle.TextSize = 12
	hubTitle.TextColor3 = Color3.fromRGB(210, 225, 240)
	hubTitle.Text = "Utilities"
	hubTitle.Parent = panel

	local openBuildHubButton = Instance.new("TextButton")
	openBuildHubButton.Size = UDim2.new(1, -18, 0, 28)
	openBuildHubButton.Position = UDim2.fromOffset(9, 48)
	openBuildHubButton.Text = "Build / Action"
	openBuildHubButton.Parent = panel

	local openOptionsButton = Instance.new("TextButton")
	openOptionsButton.Size = UDim2.new(1, -18, 0, 28)
	openOptionsButton.Position = UDim2.fromOffset(9, 80)
	openOptionsButton.Text = "Options"
	openOptionsButton.Parent = panel

	local openManagementButton = Instance.new("TextButton")
	openManagementButton.Size = UDim2.new(1, -18, 0, 28)
	openManagementButton.Position = UDim2.fromOffset(9, 112)
	openManagementButton.Text = "Creature Management"
	openManagementButton.Parent = panel

	local objectiveHeader = Instance.new("TextLabel")
	objectiveHeader.BackgroundTransparency = 1
	objectiveHeader.Size = UDim2.new(1, -18, 0, 16)
	objectiveHeader.Position = UDim2.fromOffset(9, 128)
	objectiveHeader.TextXAlignment = Enum.TextXAlignment.Left
	objectiveHeader.Font = Enum.Font.GothamBold
	objectiveHeader.TextSize = 11
	objectiveHeader.TextColor3 = Color3.fromRGB(210, 225, 240)
	objectiveHeader.Text = "Objectives"
	objectiveHeader.Parent = panel

	local objectiveList = Instance.new("ScrollingFrame")
	objectiveList.Name = "ObjectiveList"
	objectiveList.Size = UDim2.new(1, -18, 1, -154)
	objectiveList.Position = UDim2.fromOffset(9, 146)
	objectiveList.ScrollBarThickness = 5
	objectiveList.CanvasSize = UDim2.fromOffset(0, 0)
	objectiveList.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	objectiveList.BackgroundTransparency = 0.15
	objectiveList.Parent = panel
	self.objectiveListScroll = objectiveList

	local levelTwo = Instance.new("Frame")
	levelTwo.Name = "LevelTwo"
	levelTwo.Size = UDim2.new(1, -18, 1, -154)
	levelTwo.Position = UDim2.fromOffset(9, 146)
	levelTwo.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	levelTwo.BackgroundTransparency = 0.15
	levelTwo.Visible = false
	levelTwo.Parent = panel

	local levelTwoTitle = Instance.new("TextLabel")
	levelTwoTitle.BackgroundTransparency = 1
	levelTwoTitle.Size = UDim2.new(1, -12, 0, 20)
	levelTwoTitle.Position = UDim2.fromOffset(8, 4)
	levelTwoTitle.TextXAlignment = Enum.TextXAlignment.Left
	levelTwoTitle.Font = Enum.Font.GothamBold
	levelTwoTitle.TextSize = 12
	levelTwoTitle.TextColor3 = Color3.fromRGB(210, 225, 240)
	levelTwoTitle.Text = "Tools & Actions"
	levelTwoTitle.Parent = levelTwo

	local toolDemolisher = Instance.new("TextButton")
	toolDemolisher.Size = UDim2.fromOffset(136, 24)
	toolDemolisher.Position = UDim2.fromOffset(8, 28)
	toolDemolisher.Text = "Prefer Demolisher"
	toolDemolisher.Parent = levelTwo

	local toolPlanter = Instance.new("TextButton")
	toolPlanter.Size = UDim2.fromOffset(136, 24)
	toolPlanter.Position = UDim2.fromOffset(156, 28)
	toolPlanter.Text = "Prefer Planter"
	toolPlanter.Parent = levelTwo

	local openBuildSelection = Instance.new("TextButton")
	openBuildSelection.Size = UDim2.fromOffset(284, 24)
	openBuildSelection.Position = UDim2.fromOffset(8, 58)
	openBuildSelection.Text = "Open Build Selection"
	openBuildSelection.Parent = levelTwo

	local useButton = Instance.new("TextButton")
	useButton.Size = UDim2.fromOffset(284, 24)
	useButton.Position = UDim2.fromOffset(8, 88)
	useButton.Text = "Interact / Place"
	useButton.Parent = levelTwo

	local plantHeader = Instance.new("TextLabel")
	plantHeader.BackgroundTransparency = 1
	plantHeader.Size = UDim2.fromOffset(284, 16)
	plantHeader.Position = UDim2.fromOffset(8, 118)
	plantHeader.TextXAlignment = Enum.TextXAlignment.Left
	plantHeader.Font = Enum.Font.GothamBold
	plantHeader.TextSize = 11
	plantHeader.TextColor3 = Color3.fromRGB(205, 228, 205)
	plantHeader.Text = "Plant Berry Bush (consumes berry)"
	plantHeader.Parent = levelTwo

	local shrubCfg = BuildableConfig.berry_shrub and BuildableConfig.berry_shrub.berryPlanting or {}
	local plantDefs = {}
	local order = shrubCfg.berryOrder or {}
	local berryTypes = shrubCfg.berryTypes or {}
	for _, key in ipairs(order) do
		local def = berryTypes[key]
		if def then
			table.insert(plantDefs, { key = key, label = tostring(def.label or key) })
		end
	end
	local plantButtons = {}
	for i, def in ipairs(plantDefs) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(136, 22)
		local row = math.floor((i - 1) / 2)
		local col = (i - 1) % 2
		btn.Position = UDim2.fromOffset(8 + (col * 148), 138 + (row * 24))
		btn.Text = string.format("Plant %s", def.label)
		btn.Parent = levelTwo
		btn.MouseButton1Click:Connect(function()
			if self.build then
				self.build:plantShrub(def.key)
			end
			refresh()
		end)
		plantButtons[def.key] = btn
	end

	local levelThree = Instance.new("Frame")
	levelThree.Name = "LevelThree"
	levelThree.Size = UDim2.new(1, -18, 1, -154)
	levelThree.Position = UDim2.fromOffset(9, 146)
	levelThree.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	levelThree.BackgroundTransparency = 0.1
	levelThree.Visible = false
	levelThree.Parent = panel

	local backToLevelTwo = Instance.new("TextButton")
	backToLevelTwo.Size = UDim2.fromOffset(284, 22)
	backToLevelTwo.Position = UDim2.fromOffset(8, 6)
	backToLevelTwo.Text = "Back to Tools & Actions"
	backToLevelTwo.Parent = levelThree

	local buildList = Instance.new("ScrollingFrame")
	buildList.Size = UDim2.new(1, -16, 1, -36)
	buildList.Position = UDim2.fromOffset(8, 30)
	buildList.CanvasSize = UDim2.fromOffset(0, 0)
	buildList.ScrollBarThickness = 6
	buildList.Visible = true
	buildList.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	buildList.BackgroundTransparency = 0.15
	buildList.Parent = levelThree

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = buildList

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Name = "SelectedLabel"
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.Size = UDim2.new(1, -12, 0, 16)
	selectedLabel.Position = UDim2.new(0, 8, 1, -18)
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.TextYAlignment = Enum.TextYAlignment.Top
	selectedLabel.Font = Enum.Font.Code
	selectedLabel.TextSize = 12
	selectedLabel.TextColor3 = Color3.fromRGB(200, 220, 235)
	selectedLabel.TextWrapped = false
	selectedLabel.Text = "Mode:-  Tool:-  Build:-  Status:-"
	selectedLabel.Parent = panel

	local mobilePlaceBtn = Instance.new("TextButton")
	mobilePlaceBtn.Name = "MobilePlaceBuildButton"
	mobilePlaceBtn.AnchorPoint = Vector2.new(0.5, 1)
	mobilePlaceBtn.Size = UDim2.new(0.28, 0, 0.07, 0)
	mobilePlaceBtn.Position = UDim2.new(0.5, 0, 0.98, 0)
	mobilePlaceBtn.BackgroundColor3 = Color3.fromRGB(48, 102, 78)
	mobilePlaceBtn.TextColor3 = Color3.fromRGB(236, 247, 240)
	mobilePlaceBtn.Font = Enum.Font.GothamBold
	mobilePlaceBtn.TextSize = 14
	mobilePlaceBtn.Text = "Place Build"
	mobilePlaceBtn.Visible = false
	mobilePlaceBtn.Parent = gui
	attachSizeConstraint(mobilePlaceBtn, 140, 36, 260, 52)
	mobilePlaceBtn.MouseButton1Click:Connect(function()
		if self.build then
			self.build:handlePrimaryAction()
		end
	end)

	local refresh

	local function formatCost(cost)
		local tokens = {}
		for mat, amt in pairs(cost or {}) do
			table.insert(tokens, string.format("%s:%s", tostring(mat), tostring(amt)))
		end
		table.sort(tokens)
		return (#tokens > 0) and table.concat(tokens, ",") or "free"
	end

	local function rebuildBuildMenu()
		for _, child in ipairs(buildList:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local yCount = 0
		local entries = (self.build and self.build:getBuildableEntries()) or {}
		for _, entry in ipairs(entries) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -8, 0, 24)
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Font = Enum.Font.Code
			btn.TextSize = 12
			btn.Text = string.format("%s [%s]", tostring(entry.label), formatCost(entry.cost))
			btn.Parent = buildList
			btn.MouseButton1Click:Connect(function()
				if self.build then
					self.build:selectBuildable(entry.key)
					self.build:setBuildMode(true)
				end
				levelThree.Visible = false
				levelTwo.Visible = true
				refresh()
			end)
			yCount += 28
		end
		buildList.CanvasSize = UDim2.fromOffset(0, yCount)
	end

	refresh = function()
		local buildMode = self.build and self.build.buildMode
		local tool = self.build and self.build.selectedTool or "-"
		local buildKey = self.build and self.build.selectedBuildKey or "-"
		local placementReason = self.build and self.build.placement and (self.build.placement.reasonCode or self.build.placement.reason) or "-"
		local interactionHint = self.build and self.build.lastInteractionHint or ""
		openBuildHubButton.Text = (levelTwo.Visible or levelThree.Visible) and "Close Build / Action" or "Build / Action"
		openOptionsButton.Text = self.optionsPanel and self.optionsPanel.Visible and "Options (Open)" or "Options"
		openManagementButton.Text = (self.managementState and self.managementState.open) and "Creature Management (Open)" or "Creature Management"
		openBuildSelection.Text = levelThree.Visible and "Build Selection Open" or "Open Build Selection"
		local statusText = interactionHint ~= "" and interactionHint or tostring(placementReason)
		selectedLabel.Text = string.format("Mode:%s  Tool:%s  Build:%s  Status:%s", tostring(buildMode or "-"), tostring(tool), tostring(buildKey), statusText)
		for _, def in ipairs(plantDefs) do
			local btn = plantButtons[def.key]
			if btn then
				local count = tonumber(Players.LocalPlayer:GetAttribute("Mat_" .. def.key)) or 0
				btn.Text = string.format("Plant %s (x%d)", def.label, count)
				btn.AutoButtonColor = count > 0
				btn.BackgroundColor3 = count > 0 and Color3.fromRGB(46, 78, 56) or Color3.fromRGB(62, 48, 48)
				btn.TextColor3 = count > 0 and Color3.fromRGB(235, 245, 235) or Color3.fromRGB(220, 188, 188)
			end
		end
		mobilePlaceBtn.Visible = UserInputService.TouchEnabled and (buildMode == true) and (self.uiMode == UI_MODE_GAMEPLAY) and (not self.hiddenUi)
		objectiveHeader.Visible = not (levelTwo.Visible or levelThree.Visible)
		objectiveList.Visible = objectiveHeader.Visible
	end

	self.mobilePlaceBuildButton = mobilePlaceBtn

	openBuildHubButton.MouseButton1Click:Connect(function()
		local opening = not (levelTwo.Visible or levelThree.Visible)
		levelTwo.Visible = opening
		levelThree.Visible = false
		refresh()
	end)

	openOptionsButton.MouseButton1Click:Connect(function()
		levelTwo.Visible = false
		levelThree.Visible = false
		self:openOptionsFromUtilityPanel()
		refresh()
	end)

	openManagementButton.MouseButton1Click:Connect(function()
		levelTwo.Visible = false
		levelThree.Visible = false
		self:openCreatureManagementFromUtilityPanel()
		refresh()
	end)

	openBuildSelection.MouseButton1Click:Connect(function()
		levelTwo.Visible = false
		levelThree.Visible = true
		refresh()
	end)

	backToLevelTwo.MouseButton1Click:Connect(function()
		levelThree.Visible = false
		levelTwo.Visible = true
		refresh()
	end)

	useButton.MouseButton1Click:Connect(function()
		if self.build then
			self.build:handlePrimaryAction()
		else
			self.requestContextAction:FireServer({ action = "context" })
		end
	end)

	toolDemolisher.MouseButton1Click:Connect(function()
		if self.build then
			self.build:selectTool("node_demolisher")
		end
		refresh()
	end)

	toolPlanter.MouseButton1Click:Connect(function()
		if self.build then
			self.build:selectTool("berry_planter")
		end
		refresh()
	end)

	rebuildBuildMenu()
	refresh()
	self:refreshObjectiveList()
end

function UIController:buildItemBar(gui)
	local panel = Instance.new("Frame")
	panel.Name = "ItemBar"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Size = UDim2.new(0.48, 0, 0.10, 0)
	panel.Position = UDim2.new(0.5, 0, 0.995, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui
	self.itemBarPanel = panel
	attachSizeConstraint(panel, 280, 66, 620, 120)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 18)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Text = "Items (1-9 select, tap selected to use)"
	title.Parent = panel

	local slotHost = Instance.new("Frame")
	slotHost.Name = "ItemSlotHost"
	slotHost.BackgroundTransparency = 1
	slotHost.Size = UDim2.new(1, -12, 0, 40)
	slotHost.Position = UDim2.fromOffset(6, 24)
	slotHost.Parent = panel

	local function refresh()
		for _, child in ipairs(slotHost:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		if not self.items then return end
		local entries = self.items.items or {}
		local maxSlots = math.min(9, #entries)
		if maxSlots <= 0 then return end
		local width = math.max(120, slotHost.AbsoluteSize.X)
		local slotW = UserInputService.TouchEnabled and 58 or 64
		local pad = 6
		local visibleSlots = math.clamp(math.floor((width + pad) / (slotW + pad)), 1, maxSlots)
		local activeIndex = math.clamp(self.items.selectedItemIndex or 1, 1, #entries)
		local maxStart = math.max(1, #entries - visibleSlots + 1)
		local startIndex = math.clamp(self.itemBarWindowStart or 1, 1, maxStart)
		if activeIndex < startIndex then
			startIndex = activeIndex
		elseif activeIndex >= (startIndex + visibleSlots) then
			startIndex = activeIndex - visibleSlots + 1
		end
		startIndex = math.clamp(startIndex, 1, maxStart)
		self.itemBarWindowStart = startIndex
		for i = 1, visibleSlots do
			local itemIndex = startIndex + i - 1
			local item = entries[itemIndex]
			if item then
				local slot = Instance.new("TextButton")
				slot.Size = UDim2.fromOffset(slotW, 36)
				slot.Position = UDim2.fromOffset((i - 1) * (slotW + pad), 2)
				slot.TextWrapped = true
				slot.Font = Enum.Font.Code
				slot.TextSize = 11
				local count = self.items:getCount(item.key)
				local prefix = (itemIndex <= 9) and tostring(itemIndex) or "-"
				slot.Text = string.format("%s\n%d:%s", tostring(item.label or item.key), prefix, tostring(count))
				local selected = itemIndex == activeIndex
				slot.BackgroundColor3 = selected and Color3.fromRGB(63, 95, 122) or Color3.fromRGB(34, 40, 52)
				slot.TextColor3 = selected and Color3.fromRGB(240, 250, 255) or Color3.fromRGB(208, 220, 235)
				if selected then
					local stroke = Instance.new("UIStroke")
					stroke.Thickness = 2
					stroke.Color = Color3.fromRGB(210, 235, 255)
					stroke.Parent = slot
				end
				slot.Parent = slotHost
				slot.MouseButton1Click:Connect(function()
					local wasSelected = (self.items.selectedItemIndex == itemIndex)
					self.items:selectIndex(itemIndex)
					if wasSelected then
						self.items:useSelected()
					end
				end)
			end
		end
	end

	if self.items then
		self.items:setChangedCallback(refresh)
	end

	refresh()
	slotHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refresh()
	end)
	task.spawn(function()
		while panel.Parent do
			refresh()
			task.wait(0.2)
		end
	end)
end

function UIController:updatePetHud(payload)
	local pets = payload and payload.pets or {}

	for i = 1, 2 do
		local label = self.hudLabels[i]
		if label then
			if i == (self.activeSlot or 1) then
				label.BackgroundColor3 = Color3.fromRGB(52, 62, 90)
			else
				label.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			end
			local pet = pets[i]
			if not pet then
				label.Text = string.format("Slot %d: (empty)", i)
			else
				local hp = math.floor((pet.hp or 0) + 0.5)
				local maxHp = math.floor((pet.maxHP or 0) + 0.5)
				local st = math.floor((pet.stamina or 0) + 0.5)
				local en = math.floor((pet.energy or 0) + 0.5)
				local speciesName = tostring(pet.species or "?")
				local displayName = tostring(pet.name or speciesName)
				local state = tostring(pet.state or "alive")
				local cooldownSummary = self:buildCooldownSummary(pet.cooldowns)
				if i == (self.activeSlot or 1) then
					local stance = tostring(self.stance or "FOLLOW")
					if stance == "HOLD" then
						self.activeCommand = "hold"
					elseif stance == "AGGRESSIVE" then
						self.activeCommand = "attack"
					else
						self.activeCommand = "follow"
					end
				end
				if state == "alive" then
					local hpPct = math.floor((hp / math.max(1, maxHp)) * 100)
					local statusLine = string.format("Manual:%s  Cast:%s", tostring(pet.manualCastState or "idle"), tostring(pet.manualCastCode or "-"))
					label.Text = string.format(
						"Slot %d  %s  Lv %d\nHP %d/%d (%d%%)\nStamina %d  Energy %d\n%s\nCD: %s",
						i,
						displayName,
						tostring(pet.level or 1),
						hp,
						maxHp,
						hpPct,
						st,
						en,
						statusLine,
						cooldownSummary
					)
				else
					label.Text = string.format(
						"Slot %d  %s  Lv %d\nDEFEATED\nHP 0/%d\nUse revive on this slot",
						i,
						displayName,
						tostring(pet.level or 1),
						math.max(maxHp, 0)
					)
				end
			end
		end
	end
	local activePet = pets[self.activeSlot or 1]
	self.activePetHud = activePet
	self:refreshCommandPanel()
	self:refreshAbilityHotbar()
end

function UIController:buildAbilityHotbar(parent)
	local panel = Instance.new("Frame")
	panel.Name = "AbilityHotbar"
	panel.Size = UDim2.new(1, -12, 0, 52)
	panel.Position = UDim2.fromOffset(6, 36)
	panel.BackgroundTransparency = 1
	panel.Parent = parent
	self.hotbarPanel = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 0)
	title.Visible = false
	title.Parent = panel

	for i = 1, 4 do
		local slot = Instance.new("TextButton")
		slot.Name = "AbilitySlot" .. i
		slot.Size = UDim2.new(0.245, -4, 0, 50)
		slot.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
		slot.Font = Enum.Font.Code
		slot.TextSize = 12
		slot.TextWrapped = true
		slot.TextColor3 = Color3.fromRGB(230, 240, 255)
		slot.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
		slot.Text = string.format("[%d] --", i)
		slot.Parent = panel
		slot.MouseButton1Click:Connect(function()
			self:triggerHotbarSlot(i)
		end)
		self.hotbarSlots[i] = slot
	end

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 12)
	status.Position = UDim2.fromOffset(0, 44)
	status.Visible = false
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Font = Enum.Font.Code
	status.TextSize = 11
	status.TextColor3 = Color3.fromRGB(200, 220, 235)
	status.Text = "Ready"
	status.Parent = panel
	self.hotbarStatusLabel = status

	task.spawn(function()
		while panel.Parent do
			self:refreshAbilityHotbar()
			task.wait(0.12)
		end
	end)
end

function UIController:inferAbilityTargetType(ability)
	if not ability then return "none" end
	if ability.targetType then return ability.targetType end
	if ability.category == "utility" or ability.category == "utility_dash" then
		if ability.targeting == "ally" then return "allyTarget" end
		if ability.targeting == "enemy" then return "enemyTarget" end
		return "self"
	end
	if ability.category == "barrier" then return "none" end
	return "enemyTarget"
end

function UIController:getAbilityResourceState(pet, ability)
	if not pet or not ability then return true, nil end
	local needStamina = (ability.resourceUse and ability.resourceUse.stamina) or 0
	local needEnergy = (ability.resourceUse and ability.resourceUse.energy) or 0
	if (tonumber(pet.stamina) or 0) < needStamina then
		return false, "low_stamina"
	end
	if (tonumber(pet.energy) or 0) < needEnergy then
		return false, "low_energy"
	end
	return true, nil
end

function UIController:refreshAbilityHotbar()
	if not self.hotbarSlots then return end
	local pet = self.activePetHud
	local moveset = (pet and pet.moveset) or {}
	for i = 1, 4 do
		local slot = self.hotbarSlots[i]
		if slot then
			local key = moveset[i]
			local ability = key and AbilityConfig[key] or nil
			local cd = key and math.max(0, tonumber(pet and pet.cooldowns and pet.cooldowns[key]) or 0) or 0
			local canCast, reason = self:getAbilityResourceState(pet, ability)
			if not key then
				slot.Text = string.format("[%d] --", i)
				slot.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
			elseif cd > 0 then
				slot.Text = string.format("[%d] %s\nCD %.1fs", i, tostring(ability and ability.name or key), cd)
				slot.BackgroundColor3 = Color3.fromRGB(65, 50, 45)
			elseif not canCast then
				slot.Text = string.format("[%d] %s\n%s", i, tostring(ability and ability.name or key), tostring(reason))
				slot.BackgroundColor3 = Color3.fromRGB(78, 44, 44)
			else
				slot.Text = string.format("[%d] %s", i, tostring(ability and ability.name or key))
				slot.BackgroundColor3 = Color3.fromRGB(35, 62, 54)
			end
		end
	end
	if self.hotbarStatusLabel then
		local cast = self.lastManualCast
		if cast and (tonumber(cast.slot) == tonumber(self.activeSlot)) then
			self.hotbarStatusLabel.Text = string.format("Last: %s / %s / %s", tostring(cast.code or "-"), tostring(cast.targetType or "-"), tostring(cast.targetResolution or "-"))
		else
			self.hotbarStatusLabel.Text = "Ready"
		end
	end
end

function UIController:triggerHotbarSlot(slotIndex)
	local pet = self.activePetHud
	if not pet or pet.state ~= "alive" then
		self:appendLog("Hotbar: active pet unavailable", "#ffb3b3")
		return
	end
	local moveset = pet.moveset or {}
	local abilityKey = moveset[slotIndex]
	if not abilityKey then
		self:appendLog(string.format("Hotbar[%d]: empty", slotIndex), "#ffb3b3")
		return
	end
	local ability = AbilityConfig[abilityKey]
	local cd = math.max(0, tonumber(pet.cooldowns and pet.cooldowns[abilityKey]) or 0)
	if cd > 0 then
		self:appendLog(string.format("Hotbar[%d]: %s cooldown %.1fs", slotIndex, tostring(abilityKey), cd), "#ffb3b3")
		return
	end
	local canCast, reason = self:getAbilityResourceState(pet, ability)
	if not canCast then
		self:appendLog(string.format("Hotbar[%d]: %s", slotIndex, tostring(reason)), "#ffb3b3")
		return
	end
	local targetType = self:inferAbilityTargetType(ability)
	local targetId = nil
	if targetType == "enemyTarget" then
		targetId = self.activeDesignatedTargetId or (self.command and self.command.getNearestCreatureTargetId and self.command:getNearestCreatureTargetId((ability and ability.range) or 140) or nil)
	end
	self:appendLog(string.format("Hotbar[%d] cast %s type=%s target=%s", slotIndex, tostring(abilityKey), tostring(targetType), tostring(targetId or "-")), "#d7fcb7")
	if self.command then
		self.command:cast(abilityKey, targetId)
	end
end

function UIController:buildCooldownSummary(cooldowns)
	if type(cooldowns) ~= "table" then return "ready" end
	local entries = {}
	for move, cd in pairs(cooldowns) do
		local value = tonumber(cd) or 0
		table.insert(entries, string.format("%s:%.1f", tostring(move), value))
	end
	table.sort(entries)
	if #entries == 0 then return "ready" end
	return table.concat(entries, "  ")
end

function UIController:appendLog(text, colorHex)
	if not text or not self.logLabels or #self.logLabels == 0 then return end
	for i = self.maxLogLines, 2, -1 do
		if self.logLabels[i] and self.logLabels[i - 1] then
			self.logLabels[i].Text = self.logLabels[i - 1].Text
			self.logLabels[i].TextColor3 = self.logLabels[i - 1].TextColor3
		end
	end
	if self.logLabels[1] then
		self.logLabels[1].Text = text
		self.logLabels[1].TextColor3 = self:hexToColor3(colorHex) or Color3.fromRGB(200, 220, 235)
	end
end
function UIController:spawnFloatingWorldText(payload)
	if not payload then return end
	local fxFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("FX")
	if not fxFolder then fxFolder = workspace end

	local anchor = Instance.new("Part")
	anchor.Name = "FloatingTextAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = Vector3.new(payload.x or 0, 4, payload.z or 0)
	anchor.Parent = fxFolder

	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(120, 36)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.Adornee = anchor
	gui.Parent = anchor

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextStrokeTransparency = 0.35
	text.TextColor3 = self:hexToColor3(payload.color) or Color3.fromRGB(255, 215, 215)
	text.Text = tostring(payload.text or "")
	text.Parent = gui

	task.spawn(function()
		for _ = 1, 25 do
			if not anchor.Parent then return end
			anchor.Position += Vector3.new(0, 0.07, 0)
			task.wait(0.03)
		end
	end)
	Debris:AddItem(anchor, 1.1)
end


function UIController:toggleCreatureManagementMenu()
	if self.uiMode ~= UI_MODE_GAMEPLAY then return end
	local nextOpen = not self.managementState.open
	self:setUtilityPanelsVisibility({
		options = false,
		management = nextOpen,
	})
	if nextOpen then
		self.managementState.layer = "root"
	end
	self:refreshCreatureManagementMenu()
end

function UIController:managementBack()
	if not self.managementState.open then return end
	if self.managementState.layer == "root" then
		self.managementState.open = false
		if self.managementPanel then self.managementPanel.Visible = false end
		return
	end
	if self.managementState.layer == "swap" or self.managementState.layer == "items" or self.managementState.layer == "summary" then
		self.managementState.layer = "actions"
	elseif self.managementState.layer == "itemTarget" then
		self.managementState.layer = "items"
	else
		self.managementState.layer = "root"
	end
	self:refreshCreatureManagementMenu()
end

function UIController:sendCreatureManageRequest(action, payload)
	payload = payload or {}
	payload.action = action
	self.requestCreatureManageRemote:FireServer(payload)
end

function UIController:buildCreatureManagementMenu(gui)
	local panel = Instance.new("Frame")
	panel.Name = "CreatureManagementPanel"
	panel.Size = UDim2.fromOffset(430, 330)
	panel.Position = UDim2.new(0.5, -215, 0.5, -165)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	panel.BackgroundTransparency = 0.12
	panel.Visible = false
	panel.Parent = gui
	self.managementPanel = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 6)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Text = "Creature Management"
	title.Parent = panel
	self.managementTitle = title

	local back = Instance.new("TextButton")
	back.Size = UDim2.fromOffset(86, 22)
	back.Position = UDim2.new(1, -94, 0, 8)
	back.Text = "Back"
	back.Parent = panel
	back.MouseButton1Click:Connect(function() self:managementBack() end)

	local rootList = Instance.new("ScrollingFrame")
	rootList.Size = UDim2.fromOffset(412, 206)
	rootList.Position = UDim2.fromOffset(9, 34)
	rootList.CanvasSize = UDim2.fromOffset(0, 0)
	rootList.ScrollBarThickness = 6
	rootList.Parent = panel
	self.managementRootList = rootList
	local rootLayout = Instance.new("UIListLayout")
	rootLayout.Padding = UDim.new(0, 4)
	rootLayout.Parent = rootList

	local actions = Instance.new("Frame")
	actions.Size = UDim2.fromOffset(412, 206)
	actions.Position = UDim2.fromOffset(9, 34)
	actions.BackgroundTransparency = 1
	actions.Visible = false
	actions.Parent = panel
	self.managementActionsFrame = actions

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.Padding = UDim.new(0, 4)
	actionLayout.Parent = actions

	self.managementFooter = Instance.new("TextLabel")
	self.managementFooter.BackgroundTransparency = 1
	self.managementFooter.Size = UDim2.fromOffset(412, 78)
	self.managementFooter.Position = UDim2.fromOffset(9, 246)
	self.managementFooter.Font = Enum.Font.Code
	self.managementFooter.TextXAlignment = Enum.TextXAlignment.Left
	self.managementFooter.TextYAlignment = Enum.TextYAlignment.Top
	self.managementFooter.TextWrapped = true
	self.managementFooter.TextSize = 13
	self.managementFooter.TextColor3 = Color3.fromRGB(210, 225, 240)
	self.managementFooter.Parent = panel
end

function UIController:refreshCreatureManagementMenu()
	if not self.managementPanel then return end
	self.managementPanel.Visible = self.managementState.open
	if not self.managementState.open then return end
	local data = self.managementData or { party = {}, reserve = {}, items = {} }
	local selected = self.managementState.selected
	local function renderCreatureEntry(entry)
		if not entry then return "(Empty Slot)" end
		local hpText = (entry.maxHP or 0) > 0 and string.format("%d/%d", entry.hp or 0, entry.maxHP or 0) or "--"
		return string.format("%s Lv.%d  HP:%s  [%s]", tostring(entry.name or entry.speciesKey), tonumber(entry.level) or 1, hpText, tostring(entry.state or "stored"))
	end
	for _, c in ipairs(self.managementRootList:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end
	local function addRootButton(text, entry)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -8, 0, 24)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Font = Enum.Font.Code
		btn.TextSize = 13
		btn.Text = text
		btn.Parent = self.managementRootList
		if entry and entry.ownedId then
			btn.MouseButton1Click:Connect(function()
				self.managementState.selected = entry
				self.managementState.layer = "actions"
				self:refreshCreatureManagementMenu()
			end)
		end
	end
	addRootButton("== Party ==", nil)
	for slot = 1, 2 do
		local entry = data.party and data.party[slot] or nil
		addRootButton(string.format("Slot %d: %s", slot, renderCreatureEntry(entry)), entry)
	end
	addRootButton("== Reserve ==", nil)
	for _, entry in ipairs(data.reserve or {}) do
		addRootButton(string.format("[%d] %s", tonumber(entry.slotOrIndex) or 0, renderCreatureEntry(entry)), entry)
	end
	self.managementRootList.CanvasSize = UDim2.fromOffset(0, math.max(0, (#self.managementRootList:GetChildren() - 1) * 28))

	self.managementRootList.Visible = self.managementState.layer == "root"
	self.managementActionsFrame.Visible = self.managementState.layer ~= "root"
	for _, c in ipairs(self.managementActionsFrame:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end

	if self.managementState.layer == "actions" and selected then
		local actions = {
			{ key = "summary", label = "Summary / Info" },
			{ key = "move_to_party", label = "Move to Party" },
			{ key = "move_to_reserve", label = "Move to Reserve" },
			{ key = "swap_with_party", label = "Swap with Party Member" },
			{ key = "use_item", label = "Use Item" },
			{ key = "cancel", label = "Cancel" },
		}
		for _, action in ipairs(actions) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -8, 0, 24)
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 13
			btn.Text = action.label
			btn.Parent = self.managementActionsFrame
			btn.MouseButton1Click:Connect(function()
				if action.key == "cancel" then
					self.managementState.layer = "root"
				elseif action.key == "summary" then
					self.managementState.layer = "summary"
				elseif action.key == "move_to_party" then
					self:sendCreatureManageRequest("move_to_party", { ownedId = selected.ownedId })
				elseif action.key == "move_to_reserve" then
					self:sendCreatureManageRequest("move_to_reserve", { ownedId = selected.ownedId })
				elseif action.key == "swap_with_party" then
					self.managementState.layer = "swap"
				elseif action.key == "use_item" then
					self.managementState.layer = "items"
				end
				self:refreshCreatureManagementMenu()
			end)
		end
	elseif self.managementState.layer == "swap" and selected then
		for slot = 1, 2 do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -8, 0, 24)
			btn.Text = string.format("Swap into Party Slot %d", slot)
			btn.Parent = self.managementActionsFrame
			btn.MouseButton1Click:Connect(function()
				self:sendCreatureManageRequest("swap_with_party", { ownedId = selected.ownedId, targetSlot = slot })
				self.managementState.layer = "actions"
				self:refreshCreatureManagementMenu()
			end)
		end
	elseif self.managementState.layer == "items" and selected then
		for _, item in ipairs(data.items or {}) do
			local count = tonumber(item.count) or 0
			local _, def = ItemUseRules.getDef(item.key)
			local targetSlot = selected.location == "party" and selected.slotOrIndex or nil
			local valid, _ = ItemUseRules.validateClientUse(def, count, targetSlot)
			if valid then
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, -8, 0, 24)
				btn.Text = string.format("%s x%d", tostring(item.label or item.key), count)
				btn.Parent = self.managementActionsFrame
				btn.MouseButton1Click:Connect(function()
					self:sendCreatureManageRequest("use_item", { ownedId = selected.ownedId, itemKey = item.key, targetSlot = targetSlot })
				end)
			end
		end
	elseif self.managementState.layer == "summary" and selected then
		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -8, 1, -8)
		info.BackgroundTransparency = 1
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.Font = Enum.Font.Code
		info.TextSize = 13
		info.Text = string.format("Name: %s\nSpecies: %s\nLevel: %d\nState: %s\nHP: %d/%d\nLocation: %s", tostring(selected.name or "-"), tostring(selected.speciesKey or "-"), tonumber(selected.level) or 1, tostring(selected.state or "-"), tonumber(selected.hp) or 0, tonumber(selected.maxHP) or 0, tostring(selected.location or "-"))
		info.Parent = self.managementActionsFrame
	end

	self.managementTitle.Text = string.format("Creature Management [%s]", tostring(self.managementState.layer))
	if selected then
		self.managementFooter.Text = string.format("Selected: %s Lv.%d (%s)\n[M] Toggle menu  [Esc] Back", tostring(selected.name or selected.speciesKey), tonumber(selected.level) or 1, tostring(selected.location or "-"))
	else
		self.managementFooter.Text = "Select a creature to open actions. [M] Toggle menu  [Esc] Back"
	end
end

function UIController:hexToColor3(hex)
	if type(hex) ~= "string" then return nil end
	local clean = string.gsub(hex, "#", "")
	if #clean ~= 6 then return nil end
	local r = tonumber(string.sub(clean, 1, 2), 16)
	local g = tonumber(string.sub(clean, 3, 4), 16)
	local b = tonumber(string.sub(clean, 5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

return UIController
