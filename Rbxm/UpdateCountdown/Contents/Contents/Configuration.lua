--!nocheck

local Board = script.Parent
local Config = {
	--// The update epoch time (GMT/UTC) (https://www.epochconverter.com)
	UpdateEpochTime = 1735689599,
}

local function floor(n: number): (string, number)
	local floored = math.floor(n)
	return floored < 10 and "0"..floored or tostring(floored), floored
end

--// Executes when the timer has ended
Config.OnCountdownEnded = function()
	Board:Destroy()
end

--// Executes per second
Config.OnTimerTicking = function(epoch: number, epochDiff: number)
	local secondsInDay = 86400
	
	local days = floor(epochDiff / secondsInDay)
	local hours = floor((epochDiff % secondsInDay) / 3600)
	local minutes = floor((epochDiff % 3600) / 60)
	local seconds = floor(epochDiff % 60)
	
	local format = "Update in:\n%s : %s : %s : %s!"
	Board.Gui.Label.Text = format:format(days, hours, minutes, seconds)
end

return Config