local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UIController = {}
UIController.__index = UIController

function UIController.new()
	return setmetatable({
		floatingTextEvent = remotes:WaitForChild("FloatingTextEvent"),
		eventLogEvent = remotes:WaitForChild("EventLogEvent"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		requestClientOption = remotes:WaitForChild("RequestClientOption"),
		hudLabels = {},
		logLabels = {},
		optionRows = {},
		optionValues = {
			RadiusChunks = 2,
			PetLeashDistance = 90,
			PetHoldDefenseRange = 30,
		},
		maxLogLines = 6,
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
		self:updatePetHud(payload)
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

function UIController:updatePetHud(payload)
	local pets = payload and payload.pets or {}
	for i = 1, 2 do
		local label = self.hudLabels[i]
		if label then
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
				if state == "alive" then
					local cmd = pet.command or "auto"
					label.Text = string.format(
						"Slot %d: %s [%s] (Lv %d)\nHP %d/%d  ST %d  EN %d\nCmd: %s  Target: %s\nCD: %s",
						i,
						displayName,
						speciesName,
						tostring(pet.level or 1),
						hp,
						maxHp,
						st,
						en,
						tostring(cmd),
						tostring(pet.targetId or "-"),
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
