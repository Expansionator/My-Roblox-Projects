--!nocheck
-- @fattah412

--[[

TypeWritter:
A module that can insert each character from a string at a certain speed into a textlabel.

--------------------------------------------------------------------

Notes:

- Attempting to play, resume or pause after the writer had been completed will not work
- WaitForWriter() will yield until the current operation has been completed
- Each time when you create a writer object, a new thread is being created
- Functions does not yield except Writer:WaitForWriter()
- This can be used for GUI's on the client or server side

--------------------------------------------------------------------

Usage:

--> Properties:

WriterObject.IsPaused
> Description: Returns a boolean indicating if the writer had been paused via :Pause()
> Returns: boolean

--> Functions:

Writer.CreateWriter(TextLabel: TextLabel, Text: string, Speed: number, RepeatForever: boolean)
> Description: Creates a WriterObject. 'RepeatForever' will repeat the writer indefinitely
> Returns: WriterObject: {}: metatable

WriterObject:Play()
> Description: Plays the writer object. Cannot be played again after calling :Play()
> Returns: void | nil

WriterObject:Pause()
> Description: Pauses the writer. Use :Resume() to resume it
> Returns: void | nil

WriterObject:Resume()
> Description: Resumes the writer after it being paused. Use :Pause() to pause it
> Returns: void | nil

WriterObject:WaitForWriter()
> Description: Yields until the active writer has finished its operation
> Returns: void | nil

WriterObject:Cancel()
> Description: Stops the writer. Attempting to call other metamethods will result it not executing
> Returns: void | nil

--------------------------------------------------------------------

Example Usage:

local typeWritter = require(game.ServerScriptService.TypeWritter)
local textLabel = workspace.Part.SurfaceGui.TextLabel

for _ = 1, 10 do
	local writer = typeWritter.CreateWriter(textLabel, 
		"This is being typed by a writer!", 0.1, false)
	
	writer:Play()
	writer:WaitForWriter()
end

--------------------------------------------------------------------

]]

local TypeWritter = {}
TypeWritter.__index = TypeWritter

function TypeWritter.CreateWriter(TextLabel: TextLabel, Text: string, Speed: number, RepeatForever: boolean)
	local self = {}
	self.IsPaused = false
	self._Internal = {
		HasDonePlaying = true;
		Co = coroutine.create(function()
			local function executeDisplay()
				local chars = Text:split("")
				TextLabel.Text = ""

				self._Internal.HasDonePlaying = false
				for _, v in chars do
					if self.IsPaused then
						repeat task.wait() until not self.IsPaused
					end

					TextLabel.Text = TextLabel.Text..v
					task.wait(Speed)
				end

				self._Internal.HasDonePlaying = true

				if RepeatForever then
					executeDisplay()
				end
			end

			executeDisplay()
			self._Internal.Co = nil
		end)
	}

	return setmetatable(self, TypeWritter)
end

function TypeWritter:Play()
	if self._Internal.Co and coroutine.status(self._Internal.Co) ~= "running" then
		coroutine.resume(self._Internal.Co)
	end
end

function TypeWritter:Pause()
	self.IsPaused = true
end

function TypeWritter:Resume()
	self.IsPaused = false
end

function TypeWritter:WaitForWriter()
	repeat task.wait() until self._Internal.HasDonePlaying
end

function TypeWritter:Cancel()
	if self._Internal.Co and coroutine.status(self._Internal.Co) ~= "dead" then
		coroutine.close(self._Internal.Co)
		self._Internal.Co = nil
	end
end

return TypeWritter