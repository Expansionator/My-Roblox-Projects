--!nocheck
--@ fattah412

--[[

MouseHover V2:
An alternative to Gui.MouseEnter, Gui.MouseLeave and Gui.MouseMoved.

-----------------------------------------

Notes:

- This module is recommended to be placed in ReplicatedStorage, or any services that does not destroy/respawn this module
- This module only works with touch-enabled and/or mouse-enabled devices
- You can only assign one function for each event

-----------------------------------------

Usage:
--> Functions:

MouseHover.CreateContainer()
> Description: Constructs the main handler that has a RenderStepped event running
> Returns: MouseContainer: {@metatable}

MouseContainer:ListenToObject(object: GuiObject, callbacks: Callbacks)
> Description: Listens to when the mouse has entered, left or moved within the gui object
> Returns: nil | void

MouseContainer:Destroy()
> Description: Stops any connections that are in the container
> Returns: nil | void

-----------------------------------------

Example Usage:

local ScreenGui = script.Parent
local GuiObject = ScreenGui.Button

local MouseHover = require(game.ReplicatedStorage.MouseHover)
local container = MouseHover.CreateContainer()

container:ListenToObject(GuiObject, {
	OnMouseEnter = function(x, y)
		print('Mouse has entered')
	end,

	OnMouseMove = function(x, y)
		print('Mouse has moved within the gui element')
	end,

	OnMouseLeave = function()
		print('Mouse has left')
	end,
})

-----------------------------------------

]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local MouseHover = {}
MouseHover.__index = MouseHover

export type Callbacks = {
	OnMouseEnter: (x: number, y: number) -> nil,
	OnMouseMove: (x: number, y: number) -> nil,
	OnMouseLeave: (x: number, y: number) -> nil,
}

local function getMousePosition(): Vector2
	local guiInset = GuiService:GetGuiInset()
	local mousePosition = UserInputService:GetMouseLocation()

	return mousePosition - guiInset
end

local function isGuiObjectAtPosition(object: GuiObject, x: number, y: number): boolean
	local playerGui = Players.LocalPlayer.PlayerGui
	local guiObjects = playerGui:GetGuiObjectsAtPosition(x, y)

	return guiObjects and guiObjects[1] == object
end

function MouseHover.CreateContainer()
	local self = setmetatable({__pv = {
		destroyed = false,
		objects = {},
	}}, MouseHover)

	self.__pv.connection = RunService.RenderStepped:Connect(function()
		local mousePosition = getMousePosition()
		local objectInFrame

		for _, meta in self.__pv.objects do
			if not isGuiObjectAtPosition(meta.object, mousePosition.X, mousePosition.Y) then
				meta.onLeave(mousePosition)
				continue
			end
			objectInFrame = meta
		end

		if objectInFrame then
			objectInFrame.onEnter(mousePosition)
		end
	end)

	return self
end

function MouseHover:ListenToObject(object: GuiObject, callbacks: Callbacks)
	if self.__pv.destroyed then
		return
	end
	local isHovering = false

	local function onMouseMove()
		if not isHovering then return end
		while isHovering and not self.__pv.destroyed do
			local mousePosition = getMousePosition()
			if callbacks.OnMouseMove then
				callbacks.OnMouseMove(mousePosition.X, mousePosition.Y)
			end

			RunService.RenderStepped:Wait()
		end
	end

	local function onMouseEnter(mousePosition: Vector2)
		if isHovering then
			return
		end
		isHovering = true

		if callbacks.OnMouseEnter then
			callbacks.OnMouseEnter(mousePosition.X, mousePosition.Y)
		end
		onMouseMove()
	end

	local function onMouseLeave(mousePosition: Vector2)
		if not isHovering then
			return
		end
		isHovering = false

		if callbacks.OnMouseLeave then
			callbacks.OnMouseLeave(mousePosition.X, mousePosition.Y)
		end
	end

	local function clearObjectTable()
		for _, meta in self.__pv.objects do
			if meta.object == object then
				meta.object = nil

				if meta.connection then
					meta.connection:Disconnect()
					meta.connection = nil
				end
				break
			end
		end
	end

	table.insert(self.__pv.objects, {
		object = object,

		onEnter = onMouseEnter,
		onLeave = onMouseLeave,

		connection = object.Destroying:Once(function()
			isHovering = false
			clearObjectTable()
		end)
	})
end

function MouseHover:Destroy()
	if self.__pv.destroyed then
		return
	end
	self.__pv.destroyed = true

	self.__pv.connection:Disconnect()
	self.__pv.connection = nil

	local mousePosition = getMousePosition()
	for _, meta in self.__pv.objects do
		meta.onLeave(mousePosition.X, mousePosition.Y)
		meta.object = nil

		if meta.connection then
			meta.connection:Disconnect()
			meta.connection = nil
		end
	end

	table.clear(self.__pv.objects)
	self.__pv.objects = nil
end

return MouseHover