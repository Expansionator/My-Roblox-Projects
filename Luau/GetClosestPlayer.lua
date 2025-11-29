--!nocheck
-- @fattah412

--[[

GetClosestPlayer:
Finds the closest player to a specific part. Useful for making AI bots.

--------------------------------------------------------------------------

Notes:

- You can exclude certain players using the last argument
- It's a really simple module, you can change it to however you want

--------------------------------------------------------------------------

Example Usage:

local GetClosestPlayer = require(game.ServerScriptService.GetClosestPlayer)
local SpawnLocation = workspace:WaitForChild("SpawnLocation")

local maxDistance = 50

while task.wait(1) do
	local closestPlayer = GetClosestPlayer(SpawnLocation, maxDistance)
	if closestPlayer then
		print('The closest player is', closestPlayer)
	end
end

--------------------------------------------------------------------------

]]

local Players = game:GetService("Players")
return function(referencePart: BasePart, maxDistance: number, playersToIgnore: {Player}?)
	local closestPositions, assignedPlayers = {}, {}
	local ignoredPlayers = {}
	
	if playersToIgnore then
		for _, v in playersToIgnore do
			table.insert(ignoredPlayers, v.UserId)
		end
	end
	
	for _, v in Players:GetPlayers() do
		local char = v.Character
		if char and not table.find(ignoredPlayers, v.UserId) then
			local magnitude = (char:GetPivot().Position - referencePart.Position).Magnitude
			if magnitude <= maxDistance then
				table.insert(closestPositions, magnitude)
				assignedPlayers[v] = magnitude
			end		
		end
	end
	
	if #closestPositions >= 1 then
		local minDistance = math.min(unpack(closestPositions))
		for player, magnitude in assignedPlayers do
			if magnitude == minDistance then
				return player
			end
		end
	end
end