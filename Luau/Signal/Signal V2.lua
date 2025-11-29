--!nocheck
-- @fattah412

--[[

Signal V2:
A Signal module that behaves like a RBXScriptSignal, without the use of Bindables.

--------------------------------------------------------

Usage:

--> Properties:

SignalConnection.Environment
> Description: Indicates the environment that the script is running in
> Value: string

SignalConnection.WaitUntilFinished
> Description: When :Fire() is called, processes ALL cached functions with yielding
> Value: boolean

SignalConnection.Destroyed
> Description: Indicates if the SignalConnection was destroyed by calling :Destroy()
> Value: boolean

--> Functions:

Signal.Create()
> Description: A constructor to house all functions and data
> Returns: SignalConnection: {@metatable}

SignalConnection:Connect(Callback: () -> nil)
> Description: Caches the callback into the container which will then be executed once :Fire() is called
> Returns: Connection: {Disconnect: function}

SignalConnection:Once(Callback: () -> nil)
> Description: Behaves similarly to :Connect(), except that it only executes once
> Returns: Connection: {Disconnect: function}

SignalConnection:Wait(Timeout: number?): number
> Description: Halts script execution until :Fire() is called. Optional parameter 'Timeout' to stop yielding after the specified duration 
> Returns: TotalTimeElapsed: number

SignalConnection:Fire(...: any)
> Description: Executes all cached functions at once; arguments that are provided will be used as parameters for each function
> Returns: nil | void

SignalConnection:DisconnectAll()
> Description: Disconnects and clears all cached functions
> Returns: nil | void

SignalConnection:Destroy()
> Description: Stops the SignalConnection from running (clearing everything)
> Returns: nil | void

--------------------------------------------------------

Example Usage:

local Signal = require(game.ServerScriptService.Signal)
local mySignal = Signal.Create()

local myConnection 
myConnection = mySignal:Connect(function(message, ...): nil 
	print(message, ...)
	
	myConnection:Disconnect()
	myConnection = nil
end)

task.delay(3, function()
	mySignal:Fire("Hey, this is working!", 123, 456)
end)

mySignal:Wait()
mySignal:Destroy()

print('Signal destroyed!')

--------------------------------------------------------

]]

local RunService = game:GetService("RunService")
local Signal = {__data = {registered = {}}}
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

return Signal