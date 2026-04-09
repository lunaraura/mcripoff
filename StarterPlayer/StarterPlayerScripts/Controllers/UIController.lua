local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UIController = {}
UIController.__index = UIController

function UIController.new(buildController, itemController, partyController, commandController)
	return setmetatable({
		floatingTextEvent = remotes:WaitForChild("FloatingTextEvent"),
		eventLogEvent = remotes:WaitForChild("EventLogEvent"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		manualCastResult = remotes:WaitForChild("ManualCastResult"),
		requestClientOption = remotes:WaitForChild("RequestClientOption"),
		requestContextAction = remotes:WaitForChild("RequestContextAction"),
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
		commandPanelMode = "HIDDEN",
		activeCommand = "follow",
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
		self.activeDesignatedTargetId = tonumber(meta.activeDesignatedTargetId)
		self:updatePetHud(payload)
	end)
	self.manualCastResult.OnClientEvent:Connect(function(payload)
		self.lastManualCast = payload
		local color = payload and payload.ok and "#a8ffd7" or "#ffb3b3"
		self:appendLog(string.format("ManualCast[%s] slot=%s ability=%s", tostring(payload and payload.code or "?"), tostring(payload and payload.slot or "-"), tostring(payload and payload.abilityKey or "-")), color)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.O then
			self:toggleOptionsMenu()
		end
	end)
end

function UIController:buildUi()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetDebugHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 0.3
	root.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	root.Size = UDim2.fromOffset(420, 250)
	root.Position = UDim2.fromOffset(12, 12)
	root.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Pet HUD (Debug)"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Size = UDim2.new(1, -12, 0, 24)
	title.Position = UDim2.fromOffset(8, 4)
	title.Parent = root
	self.titleLabel = title

	for i = 1, 2 do
		local petCard = Instance.new("TextLabel")
		petCard.Name = "Pet" .. i
		petCard.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		petCard.BackgroundTransparency = 0.15
		petCard.Font = Enum.Font.Code
		petCard.TextSize = 14
		petCard.TextXAlignment = Enum.TextXAlignment.Left
		petCard.TextYAlignment = Enum.TextYAlignment.Top
		petCard.TextColor3 = Color3.fromRGB(220, 235, 255)
		petCard.Size = UDim2.fromOffset(196, 90)
		petCard.Position = UDim2.fromOffset(8 + (i - 1) * 204, 32)
		petCard.Text = string.format("Slot %d: --", i)
		petCard.Parent = root
		self.hudLabels[i] = petCard
	end

	local logTitle = Instance.new("TextLabel")
	logTitle.BackgroundTransparency = 1
	logTitle.Text = "Recent Events"
	logTitle.Font = Enum.Font.GothamBold
	logTitle.TextSize = 14
	logTitle.TextXAlignment = Enum.TextXAlignment.Left
	logTitle.TextColor3 = Color3.fromRGB(235, 245, 255)
	logTitle.Size = UDim2.new(1, -12, 0, 20)
	logTitle.Position = UDim2.fromOffset(8, 130)
	logTitle.Parent = root

	for i = 1, self.maxLogLines do
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.Code
		line.TextSize = 13
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = Color3.fromRGB(200, 220, 235)
		line.Size = UDim2.new(1, -16, 0, 16)
		line.Position = UDim2.fromOffset(8, 134 + i * 17)
		line.Text = ""
		line.Parent = root
		self.logLabels[i] = line
	end
	self:buildOptionsMenu(gui)
	self:buildCommandPanel(gui)
	self:buildBuildAndToolMenu(gui)
	self:buildItemBar(gui)
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
	self.commandModeLabel.Text = string.format(
		"Command Panel [C]: %s  ActiveSlot:%s  Mode:%s  Stance:%s",
		self.commandPanelMode,
		tostring(self.activeSlot or 1),
		tostring(self.controlMode or "AUTO"),
		tostring(self.stance or "FOLLOW")
	)
	for key, btn in pairs(self.commandButtons or {}) do
		btn.BackgroundColor3 = (self.activeCommand == key) and Color3.fromRGB(70, 105, 145) or Color3.fromRGB(40, 45, 58)
	end
end

function UIController:buildCommandPanel(gui)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(404, 18)
	label.Position = UDim2.fromOffset(20, 266)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Code
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(210, 230, 245)
	label.Parent = gui
	self.commandModeLabel = label

	local panel = Instance.new("Frame")
	panel.Name = "CommandPanel"
	panel.Size = UDim2.fromOffset(404, 34)
	panel.Position = UDim2.fromOffset(20, 286)
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
	panel.Size = UDim2.fromOffset(280, 170)
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

	self:createOptionRow(panel, 1, "RadiusChunks", "Chunk Radius", 2, 7, 1)
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
	if not self.optionsPanel then return end
	self.optionsPanel.Visible = not self.optionsPanel.Visible
end

function UIController:buildBuildAndToolMenu(gui)
	local panel = Instance.new("Frame")
	panel.Name = "BuildToolPanel"
	panel.Size = UDim2.fromOffset(320, 250)
	panel.Position = UDim2.new(1, -312, 0, 190)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "Tools / Build"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Size = UDim2.new(1, -12, 0, 20)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local buildMenuToggle = Instance.new("TextButton")
	buildMenuToggle.Size = UDim2.fromOffset(150, 24)
	buildMenuToggle.Position = UDim2.fromOffset(10, 30)
	buildMenuToggle.Text = "Open Build Menu"
	buildMenuToggle.Parent = panel

	local useButton = Instance.new("TextButton")
	useButton.Size = UDim2.fromOffset(150, 24)
	useButton.Position = UDim2.fromOffset(164, 30)
	useButton.Text = "Use Selected"
	useButton.Parent = panel

	local toolTitle = Instance.new("TextLabel")
	toolTitle.BackgroundTransparency = 1
	toolTitle.Size = UDim2.fromOffset(140, 18)
	toolTitle.Position = UDim2.fromOffset(10, 58)
	toolTitle.TextXAlignment = Enum.TextXAlignment.Left
	toolTitle.Font = Enum.Font.GothamBold
	toolTitle.TextSize = 12
	toolTitle.TextColor3 = Color3.fromRGB(210, 225, 240)
	toolTitle.Text = "Tools"
	toolTitle.Parent = panel

	local buildTitle = Instance.new("TextLabel")
	buildTitle.BackgroundTransparency = 1
	buildTitle.Size = UDim2.fromOffset(140, 18)
	buildTitle.Position = UDim2.fromOffset(164, 58)
	buildTitle.TextXAlignment = Enum.TextXAlignment.Left
	buildTitle.Font = Enum.Font.GothamBold
	buildTitle.TextSize = 12
	buildTitle.TextColor3 = Color3.fromRGB(210, 225, 240)
	buildTitle.Text = "Buildables"
	buildTitle.Parent = panel

	local toolDemolisher = Instance.new("TextButton")
	toolDemolisher.Size = UDim2.fromOffset(150, 22)
	toolDemolisher.Position = UDim2.fromOffset(10, 76)
	toolDemolisher.Text = "Demolisher"
	toolDemolisher.Parent = panel

	local toolPlanter = Instance.new("TextButton")
	toolPlanter.Size = UDim2.fromOffset(150, 22)
	toolPlanter.Position = UDim2.fromOffset(10, 102)
	toolPlanter.Text = "Berry Planter"
	toolPlanter.Parent = panel

	local buildList = Instance.new("ScrollingFrame")
	buildList.Size = UDim2.fromOffset(150, 132)
	buildList.Position = UDim2.fromOffset(164, 76)
	buildList.CanvasSize = UDim2.fromOffset(0, 0)
	buildList.ScrollBarThickness = 6
	buildList.Visible = false
	buildList.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	buildList.BackgroundTransparency = 0.15
	buildList.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = buildList

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.Size = UDim2.new(1, -12, 0, 20)
	selectedLabel.Position = UDim2.fromOffset(8, 218)
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.Font = Enum.Font.Code
	selectedLabel.TextSize = 13
	selectedLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	selectedLabel.Parent = panel

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
		buildMenuToggle.Text = buildList.Visible and "Close Build Menu" or "Open Build Menu"
		selectedLabel.Text = string.format("tool=%s  build=%s  mode=%s  reason=%s", tostring(tool), tostring(buildKey), buildMode and "BUILD" or "TOOL", tostring(placementReason))
	end

	buildMenuToggle.MouseButton1Click:Connect(function()
		buildList.Visible = not buildList.Visible
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
	if self.titleLabel then
		self.titleLabel.Text = string.format(
			"Pet HUD (Debug)  Active:%d  Mode:%s  Stance:%s  ActiveTarget:%s",
			self.activeSlot or 1,
			self.controlMode or "AUTO",
			self.stance or "FOLLOW",
			tostring(self.activeDesignatedTargetId or "-")
		)
	end
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
						local cmd = pet.command or "auto"
							local manual = tostring(pet.manualCastState or "idle")
							local manualCode = tostring(pet.manualCastCode or "-")
						local designated = tostring(pet.designatedTargetId or "-")
						local cmdTarget = tostring(pet.commandTargetId or "-")
						local forcedState = tostring(pet.forcedState or "-")
						local ignored = tostring(pet.commandIgnoreReason or "-")
						local override = pet.commandOverride and "Y" or "N"
						label.Text = string.format(
								"Slot %d: %s [%s] (Lv %d)\nHP %d/%d  ST %d  EN %d\nStance:%s  Cmd:%s  CmdTarget:%s\nTarget:%s  Designated:%s  Forced:%s\nManual:%s (%s)  Override:%s  Ignored:%s\nCD: %s",
							i,
							displayName,
							speciesName,
						tostring(pet.level or 1),
						hp,
							maxHp,
							st,
							en,
							tostring(self.stance or "FOLLOW"),
							tostring(cmd),
							cmdTarget,
							tostring(pet.targetId or "-"),
								designated,
								forcedState,
								manual,
								manualCode,
								override,
								ignored,
							cooldownSummary
						)
				else
					label.Text = string.format(
						"Slot %d: %s [%s] (Lv %d)\nHP 0/%d  ST 0  EN 0\nDEFEATED\nCD: --",
						i,
						displayName,
						speciesName,
						tostring(pet.level or 1),
						math.max(maxHp, 0)
					)
				end
			end
		end
	end
	self:refreshCommandPanel()
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
	if not text then return end
	for i = self.maxLogLines, 2, -1 do
		self.logLabels[i].Text = self.logLabels[i - 1].Text
		self.logLabels[i].TextColor3 = self.logLabels[i - 1].TextColor3
	end
	self.logLabels[1].Text = text
	self.logLabels[1].TextColor3 = self:hexToColor3(colorHex) or Color3.fromRGB(200, 220, 235)
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
