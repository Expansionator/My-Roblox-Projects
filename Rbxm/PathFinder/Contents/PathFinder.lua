--!nocheck
-- @fattah412

--[[

PathFinder:
The module designed for bots to pathfind to a position with full customizable functions.

--------------------------------------------------------------------------------

Notes:

- This system fully relies on PathfindingService. It might not produce the best routes
- The bot (NPC) must have a Humanoid and a HumanoidRootPart
- :CreateAI() yields if it's paused using :ChangePauseStatus(true)
- You can visualize the waypoints created by setting 'VisualizePath' to true
- If no part was defined for 'VisualizePart', with 'VisualizePath' being set to true, it will use its default part
	> Waypoints that are selected to be used, will turn green. Failed waypoints will be turn red
- Every time when you call .CreateAI(), 5 new BindableEvents are created. Which are destroyed after the completion or failure of the path
- This system supports real time updates. However, 'UpdateRealTime' must be true and 'TargetPart' must be a basepart
	> If neither of those are set, :MoveTo() will use 'GoalPosition' which takes in a Vector3 value
- You can listen to the events that are happening using the provided functions
- This system has the ability to pause/resume the current action of the bot, using :OnStatusChanged()
- If the path that's trying to be created fails, it is advised to create a new constructor
- If you have ladders or anything similar to that, use the Instance named 'PathfindingLink'
- :Stop() will stop and delete any tables and events. This function will not call :OnPathCreationFailure() and/or :OnFinished()
- Calling :Stop() will delete every data that the constructor has, making it unusable
- This system behaves weirdly with mazes that are made out of meshes

--------------------------------------------------------------------------------

Usage:

--> Properties:

Path.CompletedPath
> Description: Returns a boolean indicating if the path was completed and successful
> Returns: boolean

Path.Failure
> Description: Returns a boolean indicating if the path failed to create
> Returns: boolean

--> Functions:

PathFinder.CreateAI(Bot: Model, AgentParameters: {}?, VisualizePath: boolean?, VisualizePart: BasePart?)
> Description: Creates the AI for the bot, path can be visualized using the system's part or the provided one
> Returns: Path: {}: metatable

Path:MoveTo(GoalPosition: Vector3, UpdateRealTime: boolean?, TargetPart: BasePart?)
> Description: Moves the bot to a fixed position, or real time position. Can only be called once
> Returns: void | nil

Path:ChangePauseStatus(MoveBot: boolean)
> Description: Makes the bot stop/resume moving, depending on the provided value
> Returns: void | nil

Path:OnStatusChanged(f: (botPaused: boolean) -> ())
> Description: Listens to when the bot pauses/resumes
> Returns: RBXScriptConnection

Path:OnPathCreationFailure(f: (pathStatus: Enum.PathStatus, startPosition: Vector3) -> ())
> Description: Listens to when the path failed to be created
> Returns: RBXScriptConnection

Path:OnBlocked(f: (position: Vector3) -> ())
> Description: Listens to when the bot was stopped by an obstacle. The bot will still continue finding a new path if this occurs
> Returns: RBXScriptConnection

Path:OnEachWaypoint(f: (waypoint: PathWaypoint) -> ())
> Description: Listens to when the bot reaches each waypoint, returning the same waypoint
> Returns: RBXScriptConnection

Path:OnFinished(f: (timeTook: number) -> ())
> Description: Listens to when the bot has successfully reached the goal destination. Returns a number in seconds
> Returns: RBXScriptConnection

Path:Stop()
> Description: Stops the AI, cleaning any mess made by the system
> Returns: void | nil

--------------------------------------------------------------------------------

Example Usage:
[Using Real Time Positioning]

local Pathfinder = require(game.ServerScriptService.PathFinder)
local myBot: Model = workspace:WaitForChild("My Bot")
local goalPart: BasePart = workspace:WaitForChild("Goal")

local myNewAI = Pathfinder.CreateAI(myBot, nil, true)
local materialsWalkedOn = {}

myNewAI:OnPathCreationFailure(function(pathStatus: Enum.PathStatus, startPosition: Vector3) 
	local r = math.round
	print('The path failed to create with the status of '..pathStatus.Name..
		" and the position it failed at is", Vector3.new(r(startPosition.X), r(startPosition.Y), r(startPosition.Z)))	
end)

local Connection = myNewAI:OnBlocked(function(position: Vector3) 
	print('The bot was blocked at', position)
end)

myNewAI:OnFinished(function(timeTook: number) 
	print('It took the bot '..timeTook..' seconds to complete the path!')
	print('The bot has '..(myNewAI.CompletedPath and "completed the path!" or "not completed the path"))
	print('The materials that the bot had touched are '..table.concat(materialsWalkedOn, ", "))
	
	Connection:Disconnect()
	Connection = nil
	
	for _ = 1, 3 do
		myBot.Humanoid.Jump = true
		task.wait(.45)
	end
end)

myNewAI:OnStatusChanged(function(botPaused: boolean) 
	print('The bot is '..(botPaused and "paused!" or "not paused!"))	
end)

myNewAI:OnEachWaypoint(function(waypoint: PathWaypoint) 
	if waypoint.Label ~= "Jump" and not table.find(materialsWalkedOn, waypoint.Label) then
		table.insert(materialsWalkedOn, waypoint.Label)
	end
end)

myNewAI:MoveTo(nil, true, goalPart)

task.wait(5) myNewAI:ChangePauseStatus(true)
task.wait(5) myNewAI:ChangePauseStatus(false)

--------------------------------------------------------------------------------

]]

local PathfindingService = game:GetService("PathfindingService")
local Signal = require(script.Signal)

local PathAI = {}
PathAI.__index = PathAI

function PathAI.CreateAI(Bot: Model, AgentParameters: {}?, VisualizePath: boolean?, VisualizePart: BasePart?)
	return setmetatable({
		CompletedPath = false;
		Failure = false;
		_Internal = {
			_DidFireFailure = false;
			_Visualizer = VisualizePath;
			_Modifer = AgentParameters;
			_IsMoveToCalled = false;
			_VisualizerPart = VisualizePart;
			_VisualizeFolder = VisualizePath and Instance.new("Folder", workspace);
			_DidFireSuccess = false;
			_HookFailure = false;
			_HookSuccess = false;
			_IsPaused = false;
			_bot = Bot;
			_Container = Signal.Create();
			_Events = {
				OnFinished = Instance.new("BindableEvent");
				OnBlocked = Instance.new("BindableEvent");
				OnStatus = Instance.new("BindableEvent");
				OnPathFailure = Instance.new("BindableEvent");
				OnEachWp = Instance.new("BindableEvent");
			};
		}
	}, PathAI)
end

function PathAI:MoveTo(GoalPosition: Vector3, UpdateRealTime: boolean?, TargetPart: BasePart?)
	if self.CompletedPath or self.Failure then return end
	if self._Internal._IsMoveToCalled then return end
	self._Internal._IsMoveToCalled = true

	local humanoid: Humanoid = self._Internal._bot:FindFirstChildOfClass("Humanoid")
	local hrp: BasePart = self._Internal._bot:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp then
		return warn(script.Name..": Humanoid or HumanoidRootPart missing!")
	end

	local waypoints, storedParts, activeParts = {}, {}, {}
	local path: Path = PathfindingService:CreatePath(self._Internal._Modifer)
	local wpIndex = 1
	local lastPart = nil
	local timeNow = os.time()
	local originalPosition = UpdateRealTime and TargetPart and TargetPart.Position

	local function checkForPauses()
		if self._Internal._IsPaused then
			repeat task.wait() until not self._Internal._IsPaused
		end
	end

	local function checkForVisualizer()
		if self._Internal._Visualizer and not self._Internal._VisualizerPart then
			if wpIndex > 1 and #activeParts > 0 then
				activeParts[wpIndex].BrickColor = BrickColor.new("Grime")
				activeParts[wpIndex - 1].BrickColor = BrickColor.new("Medium stone grey")
			end
		end
	end

	local function cleanUp()
		if not self.Failure then
			self.CompletedPath = true
			self._Internal._Events.OnFinished:Fire(os.time() - timeNow)

			if self._Internal._HookSuccess then
				repeat task.wait() until self._Internal._DidFireSuccess
			end
		else
			self._Internal._Events.OnPathFailure:Fire(path.Status, hrp.Position)
			if self._Internal._HookFailure then
				repeat task.wait() until self._Internal._DidFireFailure
			end
		end

		self._Internal._Container:Clean()
		for i, v in self._Internal._Events do
			v:Destroy()
		end

		if self._Internal._VisualizeFolder then
			self._Internal._VisualizeFolder:Destroy()
		end

		self._Internal = nil
	end

	local function computeAsync()
		local success, _ = pcall(function()
			local newPosition = UpdateRealTime and TargetPart and TargetPart.Position or GoalPosition
			path:ComputeAsync(hrp.Position - Vector3.new(0, hrp.Size.Y / 0.75), newPosition)	
		end)

		waypoints = {}

		if success and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
			wpIndex = 1

			table.clear(activeParts)

			if self._Internal._Visualizer then
				if not self._Internal._VisualizerPart then
					for _, v in storedParts do
						v.BrickColor = BrickColor.new("Persimmon")
					end
				end

				for _, v in waypoints do
					if self._Internal._VisualizerPart then
						local newVisualizer = self._Internal._VisualizerPart:Clone()
						newVisualizer.Parent = self._Internal._VisualizeFolder
						newVisualizer.Position = v.Position + Vector3.new(0, 1.5, 0)
					else
						local newVisualizer = Instance.new("Part", self._Internal._VisualizeFolder)
						newVisualizer.BrickColor = BrickColor.new("Medium stone grey")
						newVisualizer.CastShadow = false
						newVisualizer.Size = Vector3.new(1.476, 1.476, 1.476)
						newVisualizer.Position = v.Position + Vector3.new(0, 1.5, 0)
						newVisualizer.CanCollide = false
						newVisualizer.CanQuery = false
						newVisualizer.CanTouch = false
						newVisualizer.Anchored = true
						newVisualizer.Shape = Enum.PartType.Ball
						newVisualizer.Material = Enum.Material.Neon

						table.insert(storedParts, newVisualizer)
						table.insert(activeParts, newVisualizer)
					end
				end
			end

			if UpdateRealTime and TargetPart and TargetPart.Position ~= originalPosition then
				originalPosition = TargetPart.Position
				computeAsync()
			else
				if waypoints[wpIndex] then
					if waypoints[wpIndex].Action == Enum.PathWaypointAction.Jump then
						humanoid.Jump = true
					end

					checkForPauses() checkForVisualizer()
					humanoid:MoveTo(waypoints[wpIndex].Position)

					self._Internal._Events.OnEachWp:Fire(waypoints[wpIndex])
				else
					computeAsync()
				end
			end
		else
			self.Failure = true
			cleanUp()
		end
	end

	self._Internal._Container:Connect(humanoid.MoveToFinished, function(reached)
		if reached and wpIndex < #waypoints then
			if UpdateRealTime and TargetPart and TargetPart.Position ~= originalPosition then
				originalPosition = TargetPart.Position
				computeAsync()
			else
				wpIndex += 1
				if waypoints[wpIndex].Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end

				checkForPauses() checkForVisualizer()
				humanoid:MoveTo(waypoints[wpIndex].Position)

				self._Internal._Events.OnEachWp:Fire(waypoints[wpIndex])
			end
		elseif reached and wpIndex == #waypoints then
			if UpdateRealTime and TargetPart then
				if TargetPart.Position ~= originalPosition then
					originalPosition = TargetPart.Position
					computeAsync()
				else
					cleanUp()
				end
			else
				cleanUp()
			end
		end
	end)

	self._Internal._Container:Connect(path.Blocked, function(blockedWpIndex)
		if blockedWpIndex > wpIndex then
			self._Internal._Events.OnBlocked:Fire(waypoints[blockedWpIndex].Position)
			computeAsync()
		end
	end)

	computeAsync()
end

function PathAI:ChangePauseStatus(MoveBot: boolean)
	if not self._Internal then return end
	if self.CompletedPath or self.Failure then return end

	self._Internal._IsPaused = MoveBot
	self._Internal._Events.OnStatus:Fire(MoveBot)
end

function PathAI:OnStatusChanged(f: (botPaused: boolean) -> ())
	if self.CompletedPath or self.Failure then return end
	return self._Internal._Container:Connect(self._Internal._Events.OnStatus.Event, function(bool)
		f(bool)
	end)
end

function PathAI:OnPathCreationFailure(f: (pathStatus: Enum.PathStatus, startPosition: Vector3) -> ())
	if self.CompletedPath or self.Failure then return end
	self._Internal._HookFailure = true

	return self._Internal._Container:Connect(self._Internal._Events.OnPathFailure.Event, function(x, y)
		task.spawn(f, x, y)
		self._Internal._DidFireFailure = true
	end)
end

function PathAI:OnBlocked(f: (position: Vector3) -> ())
	if self.CompletedPath or self.Failure then return end
	return self._Internal._Container:Connect(self._Internal._Events.OnBlocked.Event, function(pos)
		f(pos)
	end)
end

function PathAI:OnEachWaypoint(f: (waypoint: PathWaypoint) -> ())
	if self.CompletedPath or self.Failure then return end
	return self._Internal._Container:Connect(self._Internal._Events.OnEachWp.Event, function(wp)
		f(wp)
	end)
end

function PathAI:OnFinished(f: (timeTook: number) -> ())
	if self.CompletedPath or self.Failure then return end
	self._Internal._HookSuccess = true

	return self._Internal._Container:Once(self._Internal._Events.OnFinished.Event, function(timeTook)
		task.spawn(f, timeTook)
		self._Internal._DidFireSuccess = true
	end)
end

function PathAI:Stop()
	if self.CompletedPath or self.Failure then return end
	if not self._Internal then return end

	self._Internal._Container:Clean()
	for i, v in self._Internal._Events do
		v:Destroy()
	end

	if self._Internal._VisualizeFolder then
		self._Internal._VisualizeFolder:Destroy()
	end

	self._Internal = nil
end

return PathAI