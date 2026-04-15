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

-- UI visibility state
local UI_HIDDEN = false
local HIDEABLE_PANELS = {}

function UIController:setUtilityPanelsVisibility(opts)
	opts = opts or {}
	if self.optionsPanel then
		self.optionsPanel.Visible = opts.options == true and not UI_HIDDEN
	end
	if self.managementPanel then
		self.managementState.open = opts.management == true and not UI_HIDDEN
		self.managementPanel.Visible = self.managementState.open
	end
	if self.managementState.open then
		self.managementState.layer = self.managementState.layer or "root"
		self:refreshCreatureManagementMenu()
	end
end

function UIController:toggleUIHidden()
	UI_HIDDEN = not UI_HIDDEN
	self:updateAllPanelVisibility()
	if self.hideButton then
		self.hideButton.Text = UI_HIDDEN and "Show UI" or "Hide UI"
	end
end

function UIController:updateAllPanelVisibility()
	local visible = not UI_HIDDEN
	-- Update hideable panels
	for _, panel in ipairs(HIDEABLE_PANELS) do
		if panel then
			-- Special handling for management panel
			if panel == self.managementPanel then
				panel.Visible = visible and self.managementState.open
			elseif panel == self.optionsPanel then
				panel.Visible = visible and self.optionsOpen
			else
				panel.Visible = visible
			end
		end
	end
	-- Always show hide button
	if self.hideButton and self.hideButton.Parent then
		self.hideButton.Parent.Visible = true
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
				AutoBerryEnabled = 1,
			},
		maxLogLines = 6,
		activeSlot = 1,
		controlMode = "AUTO",
		stance = "FOLLOW",
		activeDesignatedTargetId = nil,
		lastManualCast = nil,
		activePetHud = nil,
		hotbarSlots = {},
		hotbarStatusLabel = nil,
		commandPanelMode = "HIDDEN",
		activeCommand = "follow",
		managementData = { party = {}, reserve = {}, items = {} },
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
		self.currentBiome = tostring(meta.currentBiome or self.currentBiome or "unknown")
		self.optionValues.AutoBerryEnabled = (meta.autoBerryEnabled == false) and 0 or 1
		self.activeDesignatedTargetId = tonumber(meta.activeDesignatedTargetId)
		self:updatePetHud(payload)
		self.managementData = meta.management or self.managementData
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

function UIController:buildUi()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	self.hiddenUi = false
	self.mainHudFrames = {}

	-- Hide UI button
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "HideUIButton"
	hideBtn.AnchorPoint = Vector2.new(1, 0)
	hideBtn.Size = UDim2.fromOffset(96, 30)
	hideBtn.Position = UDim2.new(1, -6, 0, -22)
	hideBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	hideBtn.TextColor3 = Color3.fromRGB(235, 245, 255)
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 12
	hideBtn.Text = "Hide UI"
	hideBtn.Parent = gui
	self.hideUiButton = hideBtn

	hideBtn.MouseButton1Click:Connect(function()
		self.hiddenUi = not self.hiddenUi
		self:setUiHidden(self.hiddenUi)
	end)

	-- Active pet combat HUD (replaces old debug panel)
	local activeHud = Instance.new("Frame")
	activeHud.Name = "ActivePetHud"
	activeHud.AnchorPoint = Vector2.new(0.5, 1)
	activeHud.Size = UDim2.new(0.32, 0, 0, 96)
	activeHud.Position = UDim2.new(0.5, 0, 1, -96)
	activeHud.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	activeHud.BackgroundTransparency = 0.12
	activeHud.Parent = gui
	self.activePetFrame = activeHud
	table.insert(self.mainHudFrames, activeHud)

	local petName = Instance.new("TextLabel")
	petName.Name = "PetName"
	petName.BackgroundTransparency = 1
	petName.Size = UDim2.new(1, -12, 0, 18)
	petName.Position = UDim2.fromOffset(6, 4)
	petName.Font = Enum.Font.GothamBold
	petName.TextSize = 15
	petName.TextXAlignment = Enum.TextXAlignment.Left
	petName.TextColor3 = Color3.fromRGB(235, 245, 255)
	petName.Text = "Active Pet"
	petName.Parent = activeHud
	self.activePetNameLabel = petName

	local petStats = Instance.new("TextLabel")
	petStats.Name = "PetStats"
	petStats.BackgroundTransparency = 1
	petStats.Size = UDim2.new(1, -12, 0, 18)
	petStats.Position = UDim2.fromOffset(6, 22)
	petStats.Font = Enum.Font.Code
	petStats.TextSize = 12
	petStats.TextXAlignment = Enum.TextXAlignment.Left
	petStats.TextYAlignment = Enum.TextYAlignment.Top
	petStats.TextColor3 = Color3.fromRGB(220, 235, 255)
	petStats.TextWrapped = false
	petStats.Text = "Lv -- | HP --/-- | ST -- | EN --"
	petStats.Parent = activeHud
	self.activePetStatsLabel = petStats

	local biomeLabel = Instance.new("TextLabel")
	biomeLabel.Name = "BiomeLabel"
	biomeLabel.BackgroundTransparency = 1
	biomeLabel.Size = UDim2.new(1, -12, 0, 14)
	biomeLabel.Position = UDim2.fromOffset(6, 38)
	biomeLabel.Font = Enum.Font.Code
	biomeLabel.TextSize = 11
	biomeLabel.TextXAlignment = Enum.TextXAlignment.Left
	biomeLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
	biomeLabel.Text = "Biome: -"
	biomeLabel.Parent = activeHud
	self.biomeLabel = biomeLabel

	self:buildAbilityHotbar(activeHud)
	self:buildOptionsMenu(gui)
	self:buildCommandPanel(gui)
	self:buildBuildAndToolMenu(gui)
	self:buildItemBar(gui)
	self:buildCreatureManagementMenu(gui)

	-- utility/build menu should be top-right compact
	if self.buildToolPanel then
		self.buildToolPanel.AnchorPoint = Vector2.new(1, 0)
		self.buildToolPanel.Position = UDim2.new(1, -12, 0, 48)
	end

	-- keep item bar visible for now
	if self.itemBarPanel then
		table.insert(self.mainHudFrames, self.itemBarPanel)
	end
	if self.buildToolPanel then
		table.insert(self.mainHudFrames, self.buildToolPanel)
	end
	if self.commandPanel then
		table.insert(self.mainHudFrames, self.commandPanel)
	end
	if self.commandModeLabel then
		table.insert(self.mainHudFrames, self.commandModeLabel)
	end
end
function UIController:setUiHidden(hidden)
	local show = not hidden

	for _, obj in ipairs(self.mainHudFrames or {}) do
		if obj then
			obj.Visible = show
		end
	end

	if self.optionsPanel then
		self.optionsPanel.Visible = show and self.optionsPanel.Visible
	end
	if self.managementPanel then
		self.managementPanel.Visible = show and self.managementState.open
	end
	if self.optionsPanel then
		self.optionsPanel.Visible = show and self.optionsPanel.Visible
	end
	if self.optionsPanel then
		self.optionsPanel.Visible = show and self.optionsPanel.Visible
	end

	if self.hideUiButton then
		self.hideUiButton.Text = hidden and "Show UI" or "Hide UI"
		self.hideUiButton.Visible = true
	end
end
function UIController:toggleCommandPanelMode()
	if self.commandPanelMode == "HIDDEN" then
		self.commandPanelMode = "VISIBLE"
	else
		self.commandPanelMode = "HIDDEN"
	end
	if self.commandPanel then
		self.commandPanel.Visible = self.commandPanelMode == "VISIBLE"
	end
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
	if not self.commandModeLabel then return end
	--self.commandModeLabel.Text = string.format(
	--	"Command Panel [C]: %s  ActiveSlot:%s  Mode:%s  Stance:%s",
	--	self.commandPanelMode,
	--	tostring(self.activeSlot or 1),
	--	tostring(self.controlMode or "AUTO"),
	--	tostring(self.stance or "FOLLOW")
	--)
	--for key, btn in pairs(self.commandButtons or {}) do
	--	btn.BackgroundColor3 = (self.activeCommand == key) and Color3.fromRGB(70, 105, 145) or Color3.fromRGB(40, 45, 58)
	--end
end

function UIController:buildCommandPanel(gui)
	local panel = Instance.new("Frame")
	panel.Name = "CommandPanel"
	panel.Size = UDim2.fromOffset(404, 34)
	panel.Position = UDim2.fromOffset(20, 266)
	panel.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	panel.BackgroundTransparency = 0.18
	panel.Visible = false
	panel.Parent = gui
	self.commandPanel = panel

	local function makeButton(text, x, key)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(124, 24)
		b.Position = UDim2.fromOffset(x, 5)
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
		follow = makeButton("Follow", 6, "follow"),
		hold = makeButton("Hold", 140, "hold"),
		attack = makeButton("Attack", 274, "attack"),
	}

	self:refreshCommandPanel()
end

function UIController:buildOptionsMenu(gui)
	local panel = Instance.new("Frame")
	panel.Name = "OptionsPanel"
	panel.Size = UDim2.fromOffset(280, 214)
	panel.Position = UDim2.new(1, -292, 0, 12)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.Visible = false
	panel.Parent = gui
	self.optionsPanel = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Options (O to toggle)"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Size = UDim2.new(1, -12, 0, 22)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	self:createOptionRow(panel, 1, "RadiusChunks", "Chunk Radius", 2, 31, 1)
	self:createOptionRow(panel, 2, "PetLeashDistance", "Pet Leash", 35, 160, 5)
	self:createOptionRow(panel, 3, "PetHoldDefenseRange", "Hold Defense", 10, 60, 2)
	self:createOptionRow(panel, 4, "AutoBerryEnabled", "Auto Berries", 0, 1, 1)
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
	text.Parent = panel

	local minus = Instance.new("TextButton")
	minus.Text = "-"
	minus.Font = Enum.Font.GothamBold
	minus.TextSize = 16
	minus.Size = UDim2.fromOffset(26, 22)
	minus.Position = UDim2.fromOffset(172, y)
	minus.Parent = panel

	local plus = Instance.new("TextButton")
	plus.Text = "+"
	plus.Font = Enum.Font.GothamBold
	plus.TextSize = 16
	plus.Size = UDim2.fromOffset(26, 22)
	plus.Position = UDim2.fromOffset(238, y)
	plus.Parent = panel

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.Code
	valueLabel.TextSize = 13
	valueLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.Size = UDim2.fromOffset(36, 22)
	valueLabel.Position = UDim2.fromOffset(200, y)
	valueLabel.Parent = panel

	local function refresh()
		local v = self.optionValues[key]
		text.Text = label
		if key == "AutoBerryEnabled" then
			valueLabel.Text = (v >= 0.5) and "ON" or "OFF"
		else
			valueLabel.Text = tostring(math.floor(v + 0.5))
		end
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
	panel.Size = UDim2.new(0, 320, 0.42, 0)
	panel.Position = UDim2.new(1, -312, 0, 190)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui

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
	openBuildHubButton.Size = UDim2.fromOffset(302, 28)
	openBuildHubButton.Position = UDim2.fromOffset(9, 48)
	openBuildHubButton.Text = "Build / Action"
	openBuildHubButton.Parent = panel

	local openOptionsButton = Instance.new("TextButton")
	openOptionsButton.Size = UDim2.fromOffset(302, 28)
	openOptionsButton.Position = UDim2.fromOffset(9, 80)
	openOptionsButton.Text = "Options"
	openOptionsButton.Parent = panel

	local openManagementButton = Instance.new("TextButton")
	openManagementButton.Size = UDim2.fromOffset(302, 28)
	openManagementButton.Position = UDim2.fromOffset(9, 112)
	openManagementButton.Text = "Creature Management"
	openManagementButton.Parent = panel

	local levelTwo = Instance.new("Frame")
	levelTwo.Name = "LevelTwo"
	levelTwo.Size = UDim2.new(1, -18, 0, 138)
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

	local levelThree = Instance.new("Frame")
	levelThree.Name = "LevelThree"
	levelThree.Size = UDim2.new(1, -18, 0, 152)
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
	buildList.Size = UDim2.fromOffset(284, 118)
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
	selectedLabel.Size = UDim2.new(1, -12, 0, 18)
	selectedLabel.Position = UDim2.fromOffset(8, 226)
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
	mobilePlaceBtn.Size = UDim2.fromOffset(180, 40)
	mobilePlaceBtn.Position = UDim2.new(0.5, 0, 1, -24)
	mobilePlaceBtn.BackgroundColor3 = Color3.fromRGB(48, 102, 78)
	mobilePlaceBtn.TextColor3 = Color3.fromRGB(236, 247, 240)
	mobilePlaceBtn.Font = Enum.Font.GothamBold
	mobilePlaceBtn.TextSize = 14
	mobilePlaceBtn.Text = "Place Build"
	mobilePlaceBtn.Visible = false
	mobilePlaceBtn.Parent = gui
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
		openBuildHubButton.Text = (levelTwo.Visible or levelThree.Visible) and "Close Build / Action" or "Build / Action"
		openOptionsButton.Text = self.optionsPanel and self.optionsPanel.Visible and "Options (Open)" or "Options"
		openManagementButton.Text = (self.managementState and self.managementState.open) and "Creature Management (Open)" or "Creature Management"
		openBuildSelection.Text = levelThree.Visible and "Build Selection Open" or "Open Build Selection"
		selectedLabel.Text = string.format("Mode:%s  Tool:%s  Build:%s  Status:%s", tostring(buildMode or "-"), tostring(tool), tostring(buildKey), tostring(placementReason))
		mobilePlaceBtn.Visible = UserInputService.TouchEnabled and (buildMode == true) and (not self.hiddenUi)
	end

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
end

function UIController:buildItemBar(gui)
	local panel = Instance.new("Frame")
	panel.Name = "ItemBar"
	panel.Size = UDim2.fromOffset(300, 72)
	panel.Position = UDim2.new(0.5, -150, 1, -88)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 18)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Text = "Items  [ / ] cycle   B use"
	title.Parent = panel

	local prevBtn = Instance.new("TextButton")
	prevBtn.Size = UDim2.fromOffset(28, 28)
	prevBtn.Position = UDim2.fromOffset(8, 30)
	prevBtn.Text = "<"
	prevBtn.Parent = panel

	local useBtn = Instance.new("TextButton")
	useBtn.Size = UDim2.fromOffset(90, 28)
	useBtn.Position = UDim2.fromOffset(106, 30)
	useBtn.Text = "Use Item"
	useBtn.Parent = panel

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.fromOffset(28, 28)
	nextBtn.Position = UDim2.fromOffset(264, 30)
	nextBtn.Text = ">"
	nextBtn.Parent = panel

	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Size = UDim2.fromOffset(150, 28)
	info.Position = UDim2.fromOffset(44, 30)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Font = Enum.Font.Code
	info.TextSize = 13
	info.TextColor3 = Color3.fromRGB(220, 235, 255)
	info.Parent = panel

	local function refresh()
		if not self.items then
			info.Text = "No item controller"
			return
		end
		local selected = self.items:getSelectedItem()
		local key = selected and selected.key or "?"
		local label = selected and selected.label or key
		local count = self.items:getCount(key)
		local status = self.items.lastUseResult and self.items.lastUseResult.reasonCode or ""
		info.Text = string.format("%s x%d [%s]", label, count, status)
	end
	
	prevBtn.MouseButton1Click:Connect(function()
		if self.items then self.items:cycle(-1) end
		refresh()
	end)
	nextBtn.MouseButton1Click:Connect(function()
		if self.items then self.items:cycle(1) end
		refresh()
	end)
	useBtn.MouseButton1Click:Connect(function()
		if self.items then self.items:useSelected() end
	end)
	if self.items then
		self.items:setChangedCallback(refresh)
	end
	
	refresh()
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

	if self.activePetNameLabel and self.activePetStatsLabel then
		if not activePet then
			self.activePetNameLabel.Text = "Active Pet: (empty)"
			self.activePetStatsLabel.Text = "Lv -- | HP --/-- | ST -- | EN --"
		else
			local hp = math.floor((activePet.hp or 0) + 0.5)
			local maxHp = math.floor((activePet.maxHP or 0) + 0.5)
			local st = math.floor((activePet.stamina or 0) + 0.5)
			local en = math.floor((activePet.energy or 0) + 0.5)
			local displayName = tostring(activePet.name or activePet.species or "?")
			local level = tonumber(activePet.level) or 1
			local state = tostring(activePet.state or "alive")
			self.activePetNameLabel.Text = string.format("%s  Lv %d  [%s]", displayName, level, state)
			self.activePetStatsLabel.Text = string.format(
				"HP %d/%d    ST %d    EN %d    Mode:%s    Stance:%s",
				hp, maxHp, st, en,
				tostring(self.controlMode or "AUTO"),
				tostring(self.stance or "FOLLOW")
			)
		end
	end
	if self.biomeLabel then
		local biomeToken = tostring(self.currentBiome or "unknown")
		self.biomeLabel.Text = string.format("Biome: %s", biomeToken)
	end
	self.activePetHud = pets[self.activeSlot or 1]
	self:refreshCommandPanel()
	self:refreshAbilityHotbar()
end

function UIController:buildAbilityHotbar(parent)
	local panel = Instance.new("Frame")
	panel.Name = "AbilityHotbar"
	panel.Size = UDim2.new(1, -12, 0, 42)
	panel.Position = UDim2.fromOffset(6, 44)
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
		slot.Size = UDim2.new(0.245, -4, 0, 42)
		slot.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
		slot.Font = Enum.Font.Code
		slot.TextSize = 11
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
