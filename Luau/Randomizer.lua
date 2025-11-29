--!nocheck
-- @fattah412

--[[

Randomizer:
A randomizer function that selects a index based on their percentage.

---------------------------------------------------------------------

Notes:

- Only use tables that are in dictionary format (key = value)
- This module supports decimals.

---------------------------------------------------------------------

Example Usage:

local Randomizer = require(game.ServerScriptService:WaitForChild("Randomizer"))
local myTable = {
	Cat = 100;
	Dog = 50;
	Bird = 20.55;
	Elephant = 15.2156;
	Wolf = 0.952;
}

local myChosenIndex = Randomizer(myTable)
print(myChosenIndex, "is the chosen one!")

---------------------------------------------------------------------

]]

return function(tab: {})
	local total = 0
	local cumulativeTable = {}

	for index, value in pairs(tab) do
		total = total + value
		cumulativeTable[index] = total
	end
	
	local randomNumber = math.random() * total
	for index, value in pairs(cumulativeTable) do
		if randomNumber <= value then
			return index
		end
	end
end