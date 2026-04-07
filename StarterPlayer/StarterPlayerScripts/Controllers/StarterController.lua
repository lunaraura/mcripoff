local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local StarterController = {}
StarterController.__index = StarterController

function StarterController.new()
	return setmetatable({
		requestStarterChoice = remotes:WaitForChild("RequestStarterChoice"),
		petHudUpdate = remotes:WaitForChild("PetHudUpdate"),
		starterChosen = true,
		starterButtons = {},
		starterOptions = {
			{ speciesKey = "dog", label = "Dog" },
			{ speciesKey = "sparkit", label = "Sparkit" },
			{ speciesKey = "cinderpup", label = "Cinderpup" },
		},
	}, StarterController)
end

function StarterController:bind()
	self:buildUi()
	self.petHudUpdate.OnClientEvent:Connect(function(payload)
		local meta = payload and payload.meta or {}
		if meta.starterChosen ~= nil then
			self.starterChosen = meta.starterChosen == true
			self:updateVisibility()
		end
	end)
end

function StarterController:buildUi()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "StarterPickerUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	local root = Instance.new("Frame")
	root.Name = "StarterPanel"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.fromScale(0.5, 0.08)
	root.Size = UDim2.fromOffset(420, 120)
	root.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	root.BackgroundTransparency = 0.2
	root.Parent = gui
	self.root = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 26)
	title.Position = UDim2.fromOffset(6, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(235, 245, 255)
	title.Text = "Choose your starter"
	title.Parent = root

	for i, entry in ipairs(self.starterOptions) do
		local button = Instance.new("TextButton")
		button.Name = "Starter_" .. entry.speciesKey
		button.Size = UDim2.fromOffset(128, 36)
		button.Position = UDim2.fromOffset(12 + (i - 1) * 136, 44)
		button.BackgroundColor3 = Color3.fromRGB(42, 62, 88)
		button.TextColor3 = Color3.fromRGB(240, 245, 255)
		button.Font = Enum.Font.Gotham
		button.TextSize = 14
		button.Text = entry.label
		button.Parent = root
		button.MouseButton1Click:Connect(function()
			self.requestStarterChoice:FireServer({ speciesKey = entry.speciesKey })
		end)
		self.starterButtons[entry.speciesKey] = button
	end

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, -12, 0, 24)
	hint.Position = UDim2.fromOffset(6, 84)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Font = Enum.Font.Code
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(170, 205, 240)
	hint.Text = "Server-authoritative: UI hides after starterChosen=true." 
	hint.Parent = root

	self:updateVisibility()
end

function StarterController:updateVisibility()
	if self.root then
		self.root.Visible = not self.starterChosen
	end
end

return StarterController
