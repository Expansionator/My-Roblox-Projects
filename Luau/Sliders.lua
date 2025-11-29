--!nocheck
-- @fattah412

--[[

Sliders:
A module that can create custom sliders with values with an increment.

------------------------------------------------------------------

Notes:

- If min and max are between 0 and 1 (or anything similar), an increment must be specified

------------------------------------------------------------------

Functions:

Sliders.CreateSlider(container: GuiObject, slider: GuiButton, mode: "Vertical" | "Horizontal", data: Data)
> Description: Creates a slider, with reference to the mode
> Returns: {}: (@metatable)

Sliders:ListenToSlide(callback: (value: number) -> nil)
> Description: Binds a function and calls it when the slider is being used
> Returns: nil | void

Sliders:SetValue(value: number)
> Description: Updates the slider to be at the specified value (value must be within min and max)
> Returns: nil | void

Sliders:GetValue()
> Description: Gets the current value of the slider
> Returns: number

Sliders:Delete()
> Description: Destroys the slider connections
> Returns: nil | void

------------------------------------------------------------------

Example Usage:

local Sliders = require(game.ReplicatedStorage.Sliders)

local Container = script.Parent.Container
local Slider = Container.Slider

local SliderConnection = Sliders.CreateSlider(Container, Slider, "Horizontal", {
	Min = 0,
	Max = 100,
	Increment = 2,
	DefaultValue = 50,
})

SliderConnection:ListenToSlide(function(value: number): nil 
	print(value)
end)

]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Sliders = {}
Sliders.__index = Sliders

export type Data = {
	Min: number,
	Max: number,
	Increment: number?,
	DefaultValue: number?,
}

local Signal
do
	Signal = {__data = {registered = {}}}
	Signal.__index = Signal

	local Connection
	do
		Connection = {}
		Connection.__index = Connection

		function Connection.new(cb, cb2)
			return setmetatable({
				__data = {
					destroyed = false;
					callback = cb;
					callback2 = cb2;
				};
			}, Connection)
		end

		function Connection:Disconnect()
			if not self or not self.__data or self.__data.destroyed then 
				return 
			end

			local activeThread = self.__data.callback2
			self.__data.destroyed = true

			table.clear(self)
			activeThread()
		end
	end

	function Signal.Create()
		local self 
		self = {
			Environment = (RunService:IsServer() and "Server") or (RunService:IsClient() and "Client");
			WaitUntilFinished = false;
			Destroyed = false;

			__data = {
				funcIndex = 0; waitIndex = 0;
				getIndex = function(method)
					self.__data[method.."Index"] += 1
					return self.__data[method.."Index"]
				end;

				functions = {};
				activeThreads = {};
			}
		}

		return setmetatable(self, Signal)
	end

	function Signal:Connect(Callback: () -> nil)
		if self.Destroyed then return end
		local index = self.__data.getIndex("func")

		if typeof(Callback) == "function" then
			local conn = Connection.new(Callback, function()
				if self.Destroyed or not self.__data or not self.__data.functions then
					return
				end

				self.__data.functions[index] = nil
			end)

			self.__data.functions[index] = conn
			return conn
		end
	end

	function Signal:Once(Callback: () -> nil)
		if self.Destroyed then return end

		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			Callback(...)
		end)

		return conn
	end

	function Signal:Wait(Timeout: number?): number
		if self.Destroyed then return end

		local thread, t = coroutine.running(), os.clock()
		local conn
		conn = self:Connect(function()
			conn:Disconnect()
			coroutine.resume(thread)
		end)

		local scheduler: thread
		if Timeout and typeof(Timeout) == "number" then
			scheduler = coroutine.create(function()
				task.wait(Timeout)
				if coroutine.status(thread) == "suspended" then
					coroutine.resume(thread)
					conn:Disconnect()
				end
			end)
			coroutine.resume(scheduler)
		end

		local index = self.__data.getIndex("wait")
		self.__data.activeThreads[index] = thread

		coroutine.yield() self.__data.activeThreads[index] = nil	
		if scheduler and (coroutine.status(scheduler) == "running" or coroutine.status(scheduler) == "suspended") then
			coroutine.close(scheduler) 
		end

		return os.clock() - t
	end

	function Signal:Fire(...: any)
		if self.Destroyed then return end
		for _, callback in self.__data.functions do
			local thread = callback.__data.callback

			if self.WaitUntilFinished then
				thread(...) continue
			end
			task.spawn(thread, ...)
		end
	end

	function Signal:DisconnectAll()
		if self.Destroyed then return end
		for index, _ in self.__data.functions do
			self.__data.functions[index] = nil
		end
	end

	function Signal:Destroy()
		if self.Destroyed then return end
		self:DisconnectAll()

		for _, thread in self.__data.activeThreads do
			if coroutine.status(thread) == "suspended" then
				coroutine.resume(thread)
			end
		end

		table.clear(self)
		self.Destroyed = true
	end
end

function Sliders.CreateSlider(container: GuiObject, slider: GuiButton, mode: "Vertical" | "Horizontal", data: Data)
	local self = {
		onSlidingConnection = Signal.Create(),
		rbx_connections = {},
		value = data.Min,
		
		__isDestroyed = false,
	}

	local range = data.Max - data.Min
	if data.Increment then
		assert(range % data.Increment == 0, "Increment must be divisible!")
	end

	local function calculateValue(percentage)
		local value = math.round((percentage * range) / (data.Increment or 1)) * (data.Increment or 1)
		return data.Min + value
	end

	self.updateSliderPosition = function(percentage)
		if not percentage then
			percentage = (self.value - data.Min) / range
		end

		local sliderPosition = slider.Position
		if mode == "Horizontal" then
			slider.Position = UDim2.new(
				percentage, sliderPosition.X.Offset,
				sliderPosition.Y.Scale, sliderPosition.Y.Offset
			)
		elseif mode == "Vertical" then
			slider.Position = UDim2.new(
				sliderPosition.X.Scale, sliderPosition.X.Offset,
				percentage, sliderPosition.Y.Offset
			)
		end
	end

	if data.DefaultValue then
		if data.Increment then
			assert(data.DefaultValue % data.Increment == 0, "Default value must be divisible!")
		end

		local percentage = (data.DefaultValue - data.Min) / range
		local value = calculateValue(percentage)

		self.value = value
		self.updateSliderPosition(percentage)
	end

	local isHoldingDown = false
	
	local function inputBegan()
		local absolutePosition, absoluteSize = container.AbsolutePosition, container.AbsoluteSize
		local minPosition, maxPosition = absolutePosition, absolutePosition + absoluteSize

		local guiInset = GuiService:GetGuiInset()
		local mousePosition = UserInputService:GetMouseLocation() - guiInset
		mousePosition -= minPosition

		local n
		if mode == "Horizontal" then
			n = math.clamp(mousePosition.X / absoluteSize.X, 0, 1)
		elseif mode == "Vertical" then
			n = math.clamp(mousePosition.Y / absoluteSize.Y, 0, 1)
		end
		self.updateSliderPosition(n)

		local value = calculateValue(n)

		self.value = value
		self.onSlidingConnection:Fire(value)
	end

	self.rbx_connections["inputBegan"] = slider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isHoldingDown = true
			while isHoldingDown and not self.__isDestroyed do
				inputBegan()
				RunService.Heartbeat:Wait()
			end
		end
	end)

	self.rbx_connections["inputEnded"] = slider.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isHoldingDown = false
		end
	end)
	
	self.rbx_connections["inputBegan2"] = container.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			inputBegan()
		end
	end)
	
	local metatable = setmetatable({__slider = self}, Sliders)
	self.rbx_connections["delete"] = slider.Destroying:Once(function()
		metatable:Delete()
	end)

	return metatable
end

function Sliders:ListenToSlide(callback: (value: number) -> nil)
	if self.Destroyed then return end
	self.__slider.onSlidingConnection:Connect(callback)
end

function Sliders:SetValue(value: number)
	self.__slider.value = value
	self.__slider.updateSliderPosition()
end

function Sliders:GetValue(): number
	if self.Destroyed then return end
	return self.__slider.value
end

function Sliders:Delete()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.__slider.__isDestroyed = true

	for name in self.__slider.rbx_connections do
		self.__slider.rbx_connections[name]:Disconnect()
		self.__slider.rbx_connections[name] = nil
	end

	self.__slider.onSlidingConnection:Destroy()
end

return Sliders