--!nocheck

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Tool = script.Parent

local Handle = Tool.Handle
local Event = Tool.Event

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if Tool.Parent == player.Character then
			Event:FireServer()
		end
	end
end)