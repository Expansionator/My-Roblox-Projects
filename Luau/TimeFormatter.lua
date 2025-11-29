--!nocheck
-- @fattah412

--[[

TimeFormatter:
A module to format the time into a readable format.

--------------------------------------------------------

Notes:

- The number (argument) that is used must be in seconds and a whole number
- When using a custom format, ensure that there are atleast 4 special characters inside the string

]]

return function(timeInSeconds: number, customFormat: string?): string
	local secondsInDay = 86400	
	local days = math.floor(timeInSeconds / secondsInDay)
	local hours = math.floor((timeInSeconds % secondsInDay) / 3600)
	local minutes = math.floor((timeInSeconds % 3600) / 60)
	local seconds = math.floor(timeInSeconds % 60)
	
	return (customFormat or "%sD %sH %sM %sS"):format(days, hours, minutes, seconds)
end