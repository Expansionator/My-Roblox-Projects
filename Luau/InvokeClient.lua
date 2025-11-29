--!nocheck
-- @fattah412

--[[

InvokeClient:
A module designed to invoke the client without the risk of indefinite waiting.

------------------------------------------------------------------------------

Notes:

- The 'Timeout' property will only be used if no data was returned
- This operates identically to the :InvokeClient() function
- A new thread is always being created when calling .InvokeClient()
- Only works in the server

------------------------------------------------------------------------------

Usage:

--> Properties:

Invoker.Timeout
> Description: The total duration before suspending the invoke client, causing it to return the final value
> Returns: number

--> Functions:

Invoker.InvokeClient(RemoteFunction: RemoteFunction, player: Player, ...: any)
> Description: Invokes to the client, with a set of arguments and a time limit
> Returns: any

------------------------------------------------------------------------------

Example Usage:

[ Server ]

local Sss = game:GetService("ServerScriptService")
local Rp = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Invoker = require(Sss:WaitForChild("InvokeClient"))
local RemoteFunction = Rp:WaitForChild("RemoteFunction")

Invoker.Timeout = 7
Players.PlayerAdded:Connect(function(player)
	local myCat, myFood, myHobby = Invoker.InvokeClient(RemoteFunction, player, "MyNewData")
	print(myCat, myFood, myHobby)
end)

[ Client ]

local Rp = game:GetService("ReplicatedStorage")
local RemoteFunction = Rp:WaitForChild("RemoteFunction")

RemoteFunction.OnClientInvoke = function(option)
	if option == "MyNewData" then
		return "James", "Pizza", "Gaming"
	end
end

--]]

local Invoker = {}
Invoker.Timeout = 5

function Invoker.InvokeClient(RemoteFunction: RemoteFunction, player: Player, ...: any)
	local args = table.pack(...)
	args["n"] = nil

	local data, t = nil, os.time()
	local Task = coroutine.create(function()
		local result = table.pack(RemoteFunction:InvokeClient(player, unpack(args)))
		data = {unpack(result)}
	end)
	
	coroutine.resume(Task)
	repeat task.wait() until data or os.time() - t >= Invoker.Timeout

	if coroutine.status(Task) ~= "dead" then
		coroutine.close(Task)
	end

	if data then 
		return unpack(data) 
	end
end

return Invoker