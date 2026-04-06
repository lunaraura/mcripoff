local Players = game:GetService("Players")
local PlayerScripts = script.Parent
local Controllers = PlayerScripts:WaitForChild("Controllers")

local PartyController = require(Controllers:WaitForChild("PartyController"))
local CommandController = require(Controllers:WaitForChild("CommandController"))
local BuildController = require(Controllers:WaitForChild("BuildController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local InputController = require(Controllers:WaitForChild("InputController"))

local localPlayer = Players.LocalPlayer
local party = PartyController.new()
local build = BuildController.new()
local command = CommandController.new(party)
local ui = UIController.new()
local input = InputController.new(party, command, build)

local mouse = localPlayer:GetMouse()
command:bind(mouse)
ui:bind()
input:bind()
