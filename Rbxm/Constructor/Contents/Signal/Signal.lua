--!nocheck
-- @fattah412

--[[

Signal:
A simple Signal based module that can track and modify any event connections.

-----------------------------------------------------------------------------

Usage:

--> Properties:

Container.Destroyed
> Description: Returns a boolean if the container used Container:Clean() (only if 'KeepContainer' is false or nil)
> Returns: boolean

--> Functions:

Signal.Create(KeepContainer: boolean)
> Description: Creates a container to store connections. KeepContainer keeps it from being destroyed, so you can reuse it again.
> Returns: Container: metatable

Container:Connect(Connector: RBXScriptSignal, func: (...any) -> nil)
> Description: Connects an event with a provided function
> Returns: RBXScriptConnection

Container:Once(Connector: RBXScriptSignal, func: (...any) -> nil)
> Description: Similar to Container:Connect(), but uses 'Once' to connect
> Returns: RBXScriptConnection

Container:Store(StoreType: "Connect" | "Once", Connector: RBXScriptSignal, func: (...any) -> nil)
> Description: Temporarily stores a connection, once Container:StartConnections() is called, the event will start running
> Returns: void | nil

Container:StartConnections()
> Description: Starts running all events simultaneously that was stored by Container:Store()
> Returns: void | nil

Container:StoreRepeat(Yield: boolean, func: (any) -> nil)
> Description: Stores a while loop and once Container:Clean() is called, it will stop unless 'KeepContainer' is true
> Returns: void | nil

Container:Clean()
> Description: Stops execution of while loops (only if 'KeepContainer' is false or nil) and events, and makes the Container unusable (only if 'KeepContainer' is false or nil)
> Returns: string: "Dead" | "Cleaned"

-----------------------------------------------------------------------------

Example Usage:

local Players = game:GetService("Players")

local Signal = require(Path.To.Signal)
local Container = Signal.Create()

Container:Connect(workspace.ChildAdded, function(child)
	print(child.Name, "was added to workspace!")
end)

local Connection
Connection = Container:Once(workspace.Terrain.ChildAdded, function(child)
	print(child.Name, "was added to the Terrain!")
	Connection:Disconnect()
end)

Container:StoreRepeat(false, function()
	print("I'm being repeated!")	 
	task.wait(30)
end)

do
	Container:Store("Connect", Players.PlayerAdded, function(player)
		print(player.Name, "has joined the game!")
	end)

	Container:Store("Connect", Players.PlayerRemoving, function(player)
		print(player.Name, "has left the game.")
	end)

	Container:StartConnections()
end

local Result = Container:Clean()
if Result == "Dead" then
	script:Destroy()
end

-----------------------------------------------------------------------------

]]

local Signal = {}
Signal.__index = Signal

local function countExisting(tab)
	local index = 0
	for _, _ in pairs(tab) do
		index += 1
	end
	return index + 1
end

function Signal.Create(KeepContainer: boolean)
	return setmetatable({
		__Events = {};
		__StoredEvents = {};
		__KeepContainer = KeepContainer;
		Destroyed = false;
	}, Signal)
end

function Signal:Connect(Connector: RBXScriptSignal, func: (...any) -> nil): RBXScriptConnection
	if self.Destroyed then return end
	local Connection = Connector:Connect(function(...)
		func(...)
	end)
	self.__Events[countExisting(self.__Events)] = Connection
	return Connection
end

function Signal:Once(Connector: RBXScriptSignal, func: (...any) -> nil): RBXScriptConnection
	if self.Destroyed then return end
	local Connection = Connector:Once(function(...)
		func(...)
	end)
	self.__Events[countExisting(self.__Events)] = Connection
	return Connection
end

function Signal:Store(StoreType: "Connect" | "Once", Connector: RBXScriptSignal, func: (...any) -> nil): nil
	if self.Destroyed then return end
	if StoreType ~= "Connect" and StoreType ~= "Once" then return end
	table.insert(self.__StoredEvents, {StoreType, Connector, func})
end

function Signal:StartConnections(): nil
	if self.Destroyed then return end
	for _, eventTable in pairs(self.__StoredEvents) do
		if eventTable[1] == "Connect" then
			local Connection = eventTable[2]:Connect(function(...)
				eventTable[3](...)
			end)
			self.__Events[countExisting(self.__Events)] = Connection
		elseif eventTable[1] == "Once" then
			local Connection = eventTable[2]:Once(function(...)
				eventTable[3](...)
			end)
			self.__Events[countExisting(self.__Events)] = Connection
		end
	end
	table.clear(self.__StoredEvents)
end

function Signal:StoreRepeat(Yield: boolean, func: (any) -> nil): nil
	if self.Destroyed then return end
	if Yield then
		while not self.Destroyed do
			func()
			task.wait()
		end
	else
		local c = coroutine.wrap(function()
			while not self.Destroyed do
				func()
				task.wait()
			end
			coroutine.yield()
		end)()
	end
end

function Signal:Clean(): string
	if self.Destroyed then return end
	table.clear(self.__StoredEvents)
	for index, signal in pairs(self.__Events) do
		if self.__Events[index].Connected then
			self.__Events[index]:Disconnect()
			self.__Events[index] = nil
		end
	end
	if not self.__KeepContainer then
		self.Destroyed = true
		return "Dead"
	end
	return "Cleaned"
end

return Signal