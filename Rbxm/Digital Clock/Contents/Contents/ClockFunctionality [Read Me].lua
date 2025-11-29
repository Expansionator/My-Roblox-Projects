--!nocheck
-- @fattah412

--[[

Digital Clock:
A simple 24-hour based digital clock.

---------------------------------

Notes:

- This can be written in a server script or a local script
- This does not support multiple clocks (you have to do that yourself)
- Place the LocalScript ('ClockFunctionality [Read Me]') in any client-sided services (like StarterPlayerScripts)
- This can be fully customized to your likings

---------------------------------

]]

local RunService = game:GetService("RunService")

local DigitalClock = workspace:WaitForChild("Digital Clock", math.huge)
local MinDisplay = DigitalClock:WaitForChild("MinuteDisplay", math.huge)
local HourDisplay = DigitalClock:WaitForChild("HourDisplay", math.huge)
local SecDisplay = DigitalClock:WaitForChild("SecondDisplay", math.huge)

local Timemap: {[number]: {string}} = {
	[0] = {"P1", "P2", "P3", "P4", "P5", "P6"};
	[1] = {"P2", "P3"};
	[2] = {"P1", "P2", "P4", "P5", "P7"};
	[3] = {"P1", "P2", "P3", "P4", "P7"};
	[4] = {"P2", "P3", "P6", "P7"};
	[5] = {"P1", "P3", "P4", "P6", "P7"};
	[6] = {"P1", "P3", "P4", "P5", "P6", "P7"};
	[7] = {"P1", "P2", "P3"};
	[8] = {"P1", "P2", "P3", "P4", "P5", "P6", "P7"};
	[9] = {"P1", "P2", "P3", "P6", "P7"};
}

local function fillEmptyZeros(num: number)
	if num < 10 then
		return "0"..num
	end
	return tostring(num)
end

local function showDisplayForTime(display: Model, n: string)
	local left, right = display.Left, display.Right
	local x, y = n:split("")[1], n:split("")[2]
	
	local function iterate(model: Model, char: number)
		for _, digit: Part in model:GetChildren() do
			local tab = Timemap[char]
			if table.find(tab, digit.Name) then
				digit.Color = Color3.fromRGB(163, 162, 165)
			else
				digit.Color = Color3.fromRGB(79, 76, 78)
			end
		end
	end
	
	iterate(left, tonumber(x))
	iterate(right, tonumber(y))
end

local function updateClockDisplay(hour: string, min: string, sec: string)
	showDisplayForTime(HourDisplay, hour)
	showDisplayForTime(MinDisplay, min)
	showDisplayForTime(SecDisplay, sec)
end

while DigitalClock and DigitalClock.Parent do
	local date = RunService:IsClient() and os.date("*t") or os.date("!*t")
	local hour, minute, second = 
		fillEmptyZeros(date.hour), fillEmptyZeros(date.min), fillEmptyZeros(date.sec)
	
	updateClockDisplay(hour, minute, second)
	task.wait(1)
end