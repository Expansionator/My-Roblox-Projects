--!nocheck
-- @fattah412

--[[

Mouse:
An alternative for the GetMouse() function.

-------------------------------------------------

Notes:

- This module is compatible with Mobile Devices
- New threads are being created (using task.spawn) when a signal is fired

-------------------------------------------------

Usage:

--> Properties:

Cursor.ProcessGameInput
> Description: Events will continue executing even if the player is interacting with Roblox Core UI elements (eg. Chat)
> Value: boolean (Default: false)

Cursor.Destroyed
> Description: Indicates if the metatable was destroyed by calling :Destroy()
> Value: boolean (Default: false)

--> Functions:

Mouse.GetMouse()
> Description: Returns Cursor, with two properties that can be modified
> Returns: Cursor ({}: @metatable)

Cursor:X(): number
> Description: Returns the X coordinate of the mouse
> Returns: number

Cursor:Y(): number
> Description: Returns the Y coordinate of the mouse
> Returns: number

Cursor:XY(): Vector2
> Description: Returns the coordinates of the mouse
> Returns: Vector2

Cursor:Delta(): Vector2
> Description: Returns the delta coordinates from the last rendered frame
> Returns: Vector2

Cursor:UpdateIcon(Image: string?)
> Description: Updates the user's mouse icon. If no value is provided, it uses the default icon
> Returns: nil | void

Cursor:SetIcon(Enabled: boolean)
> Description: Sets the visibility of the mouse icon
> Returns: nil | void

Cursor:AddObjectToFilter(Object: Instance | {Instance})
> Description: Adds instances to be excluded from raycasting
> Returns: nil | void

Cursor:RemoveObjectFromFilter(Object: Instance | {Instance})
> Description: Removes existing instances that are excluded from the list
> Returns: nil | void

Cursor:GetGuisAtPosition(x: number?, y: number?): {Instance?}
> Description: Returns all Gui objects that are intersecting with the mouse location
> Returns: {Instance}

Cursor:GetTarget(Distance: number?, IgnorePlayer: boolean?): BasePart?
> Description: The object that the mouse is pointing to
> Returns: BasePart

Cursor:GetHit(Distance: number?, IgnorePlayer: number?): CFrame?
> Description: The CFrame of the mouse in workspace
> Returns: CFrame

Cursor:GetOrigin(): CFrame?
> Description: The CFrame from the camera location orientated towards the mouse location
> Returns: CFrame

Cursor:GetUnitRay(): Ray?
> Description: Similar to :GetOrigin(), but returns a Ray instead
> Returns: Ray

Cursor:OnMove(Callback: (x: number, y: number) -> nil)
> Description: Fires whenever the mouse moves to a new location
> Returns: nil | void

Cursor:OnButtonClicked(Type: ButtonTypes, Callback: () -> nil)
> Description: Fires when a button is clicked
> Returns: nil | void

Cursor:OnButtonReleased(Type: ButtonTypes, Callback: () -> nil)
> Description: Fires when a button is released
> Returns: nil | void

Cursor:OnButtonHold(Type: ButtonTypes, Callback: () -> nil)
> Description: Fires when a button is being held down
> Returns: nil | void

Cursor:OnWheelScroll(Type: WheelTypes, Callback: () -> nil)
> Description: Fires when the scroll wheel moves
> Returns: nil | void

Cursor:Destroy()
> Description: Stops the cursor from running
> Returns: nil | void

-------------------------------------------------

Example Usage:

local Cursor = require(game.ReplicatedStorage.Mouse)
local Mouse = Cursor.GetMouse()
Mouse.ProcessGameInput = true

Mouse:OnButtonClicked("MouseButton1", function(): nil 
	local target = Mouse:GetTarget()
	if target then
		print("Target found:", target)
	end
end)

Mouse:OnButtonReleased("MouseButton1", function(): nil 
	print('Left mouse released!')
end)

-------------------------------------------------

]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player.PlayerGui

local Signal = require(script.Signal)
local Mouse = {}
Mouse.__index = Mouse

export type WheelTypes = "Forward" | "Backward"
export type ButtonTypes = "MouseButton1" |"MouseButton2" | "MouseButton3"

local WheelTypes = {"Forward", "Backward"}
local ButtonTypes = {"MouseButton1", "MouseButton2", "MouseButton3"}

local function unpackDictionary(t: {[any]: any}): {any}
	local values = {}
	for _, v in t do
		table.insert(values, v)
	end
	return table.unpack(values, 1, #values)
end

function Mouse.GetMouse()
	local self = {filters = {}, listeners = {}, signals = {
		inputBegan = Signal.Create(),
		inputChanged = Signal.Create(),
		inputEnded = Signal.Create(),
		touchMoved = Signal.Create()
	}}

	self.listeners.Began = UserInputService.InputBegan:Connect(function(input, gp)
		self.signals.inputBegan:Fire(input, gp)
	end)

	self.listeners.Changed = UserInputService.InputChanged:Connect(function(input, gp)
		self.signals.inputChanged:Fire(input, gp)
	end)

	self.listeners.Ended = UserInputService.InputEnded:Connect(function(input, gp)
		self.signals.inputEnded:Fire(input, gp)
	end)

	self.listeners.TouchMoved = UserInputService.TouchMoved:Connect(function(input, gp)
		self.signals.touchMoved:Fire(input, gp)
	end)

	self.addListener = function(Type, Cb)
		self.signals[Type]:Connect(Cb)
	end

	return setmetatable({
		__data = self,
		ProcessGameInput = false,
		Destroyed = false,
	}, Mouse)
end

function Mouse:X(): number
	local mousePosition: Vector2 = self:XY()
	return mousePosition.X
end

function Mouse:Y(): number
	local mousePosition: Vector2 = self:XY()
	return mousePosition.Y
end

function Mouse:XY(): Vector2
	local mousePosition = UserInputService:GetMouseLocation()
	return mousePosition
end

function Mouse:Delta(): Vector2
	local delta = UserInputService:GetMouseDelta()
	return delta
end

function Mouse:UpdateIcon(Image: string?)
	UserInputService.MouseIcon = Image or ""
end

function Mouse:SetIcon(Enabled: boolean)
	UserInputService.MouseIconEnabled = Enabled
end

function Mouse:AddObjectToFilter(Object: Instance | {Instance})
	if typeof(Object) == "table" then
		for _, v in Object do
			self.__data.filters[v] = v
		end
		return
	end
	self.__data.filters[Object] = Object
end

function Mouse:RemoveObjectFromFilter(Object: Instance | {Instance})
	if typeof(Object) == "table" then
		for _, v in Object do
			if self.__data.filters[v] then
				self.__data.filters[v] = nil
			end
		end
		return
	end
	self.__data.filters[Object] = nil
end

function Mouse:GetGuisAtPosition(x: number?, y: number?): {Instance?}
	local guiInset: Vector2 = GuiService:GetGuiInset()
	local mousePosition: Vector2 = self:XY()

	local xPos = x or mousePosition.X - guiInset.X
	local yPos = y or mousePosition.Y - guiInset.Y

	local guisAtPosition = playerGui:GetGuiObjectsAtPosition(xPos, yPos)
	return guisAtPosition
end

function Mouse:GetTarget(Distance: number?, IgnorePlayer: boolean?): BasePart?
	local raycastParams: RaycastParams = RaycastParams.new()
	raycastParams:AddToFilter({unpackDictionary(self.__data.filters)})
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	if IgnorePlayer and player.Character then
		raycastParams:AddToFilter(player.Character)
	end

	local mousePosition: Vector2 = self:XY()
	local viewPortToRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y, 0)
	local raycastResult = workspace:Raycast(viewPortToRay.Origin, viewPortToRay.Direction * (Distance or 1000), raycastParams)

	if raycastResult then
		local resultInstance = raycastResult.Instance
		return resultInstance:IsA("BasePart") and resultInstance
	end
end

function Mouse:GetHit(Distance: number?, IgnorePlayer: number?): CFrame?
	local raycastParams: RaycastParams = RaycastParams.new()
	raycastParams:AddToFilter({unpackDictionary(self.__data.filters)})
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	if IgnorePlayer and player.Character then
		raycastParams:AddToFilter(player.Character)
	end

	local mousePosition: Vector2 = self:XY()
	local viewPortToRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y, 0)
	local raycastResult = workspace:Raycast(viewPortToRay.Origin, viewPortToRay.Direction * (Distance or 1000), raycastParams)

	return raycastResult and CFrame.new(raycastResult.Position)
end

function Mouse:GetOrigin(): CFrame?
	local mousePosition: Vector2 = self:XY()
	local unitRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	if unitRay then
		local blankIdentity = CFrame.new(unitRay.Origin, unitRay.Origin + unitRay.Direction)
		return blankIdentity
	end
end

function Mouse:GetUnitRay(): Ray?
	local mousePosition: Vector2 = self:XY()
	local unitRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	return unitRay
end

function Mouse:OnMove(Callback: (x: number, y: number) -> nil)
	self.__data.addListener("inputChanged", function(input: InputObject, gp: boolean)
		if gp and not self.ProcessGameInput then return end
		local mousePosition: Vector2 = self:XY()
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			Callback(mousePosition.X, mousePosition.Y)
		end
	end)

	self.__data.addListener("touchMoved", function(input: InputObject, gp: boolean) 
		if gp and not self.ProcessGameInput then return end
		local mousePosition: Vector2 = self:XY()
		Callback(mousePosition.X, mousePosition.Y)
	end)
end

function Mouse:OnButtonClicked(Type: ButtonTypes, Callback: () -> nil)
	if not table.find(ButtonTypes, Type) then
		return
	end

	local enum = Enum.UserInputType[Type]
	self.__data.addListener("inputBegan", function(input: InputObject, gp: boolean)
		if gp and not self.ProcessGameInput then return end
		if input.UserInputType == enum then
			Callback()
		else
			if Type == "MouseButton1" and input.UserInputType == Enum.UserInputType.Touch then
				Callback()	
			end
		end
	end)
end

function Mouse:OnButtonReleased(Type: ButtonTypes, Callback: () -> nil)
	if not table.find(ButtonTypes, Type) then
		return
	end

	local enum = Enum.UserInputType[Type]
	self.__data.addListener("inputEnded", function(input: InputObject, gp: boolean)
		if gp and not self.ProcessGameInput then return end
		if input.UserInputType == enum then
			Callback()
		else
			if Type == "MouseButton1" and input.UserInputType == Enum.UserInputType.Touch then
				Callback()	
			end
		end
	end)
end

function Mouse:OnButtonHold(Type: ButtonTypes, Callback: () -> nil)
	if not table.find(ButtonTypes, Type) then
		return
	end

	local enum = Enum.UserInputType[Type]
	local isHolding = false

	self.__data.addListener("inputBegan", function(input: InputObject, gp: boolean)
		if gp and not self.ProcessGameInput then return end
		if input.UserInputType == enum then
			isHolding = true
			while isHolding do
				task.spawn(Callback) task.wait()
			end
		else
			if Type == "MouseButton1" and input.UserInputType == Enum.UserInputType.Touch then
				isHolding = true
				while isHolding do
					task.spawn(Callback) task.wait()
				end
			end
		end
	end)

	self.__data.addListener("inputEnded", function(input: InputObject, gp: boolean)
		if gp and not self.ProcessGameInput then return end
		if input.UserInputType == enum then
			isHolding = false
		else
			if Type == "MouseButton1" and input.UserInputType == Enum.UserInputType.Touch then
				isHolding = false
			end
		end
	end)
end

function Mouse:OnWheelScroll(Type: WheelTypes, Callback: () -> nil)
	if not table.find(WheelTypes, Type) then
		return
	end

	self.__data.addListener("inputChanged", function(input: InputObject, gp: boolean)
		if gp and not self.ProcessGameInput then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if input.Position.Z > 0 and Type == "Forward" then
				Callback()
			elseif input.Position.Z < 0 and Type == "Backward" then
				Callback()
			end
		end
	end)
end

function Mouse:Destroy()
	self.Destroyed = true
	table.clear(self.__data.filters)

	for index, _ in self.__data.listeners do
		self.__data.listeners[index]:Disconnect()
		self.__data.listeners[index] = nil
	end

	for index, _ in self.__data.signals do
		self.__data.signals[index]:Destroy()
		self.__data.signals[index] = nil
	end

	self.__data.filters = nil
	self.__data.listeners = nil
	self.__data.signals = nil
end

return Mouse