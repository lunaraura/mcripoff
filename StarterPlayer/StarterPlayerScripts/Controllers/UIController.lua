local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UIController = {}
UIController.__index = UIController

function UIController.new()
	return setmetatable({
		floatingTextEvent = remotes:WaitForChild("FloatingTextEvent"),
		eventLogEvent = remotes:WaitForChild("EventLogEvent"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		hudLabels = {},
		logLabels = {},
		maxLogLines = 6,
	}, UIController)
end

function UIController:bind()
	self:buildUi()
	self.floatingTextEvent.OnClientEvent:Connect(function(payload)
		self:spawnFloatingWorldText(payload)
	end)
	self.eventLogEvent.OnClientEvent:Connect(function(payload)
		self:appendLog(payload.text, payload.color)
	end)
	self.petHudUpdate.OnClientEvent:Connect(function(payload)
		self:updatePetHud(payload)
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
				local maxHp = math.floor((pet.maxHP or 1) + 0.5)
				local st = math.floor((pet.stamina or 0) + 0.5)
				local en = math.floor((pet.energy or 0) + 0.5)
				local cmd = pet.command or "auto"
				local cooldownSummary = self:buildCooldownSummary(pet.cooldowns)
				label.Text = string.format(
					"Slot %d: %s (Lv %d)\nHP %d/%d  ST %d  EN %d\nCmd: %s  Target: %s\nCD: %s",
					i,
					tostring(pet.species),
					tostring(pet.level or 1),
					hp,
					maxHp,
					st,
					en,
					tostring(cmd),
					tostring(pet.targetId or "-"),
					cooldownSummary
				)
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
