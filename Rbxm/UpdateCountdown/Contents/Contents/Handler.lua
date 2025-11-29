--!nocheck
-- @fattah412

local Board = script.Parent
local Config = require(Board.Configuration)

local epochNow: number = os.time()
while epochNow < Config.UpdateEpochTime do
	local epochDiff = Config.UpdateEpochTime - epochNow
	Config.OnTimerTicking(epochNow, epochDiff)
	
	epochNow = os.time()
	task.wait(1)
end

Config.OnCountdownEnded()