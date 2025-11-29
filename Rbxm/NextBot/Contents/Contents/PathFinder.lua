--!nocheck
-- @fattah412

--[[

Nextbot:
The bot that behaves like a NextBot with full customizable options.

-------------------------------------------------------------------

Notes:

- Settings for this bot can be found under this script
- It is advised to not change some of the properties that is in the Humanoid, as it will be overwritten by code
- You can update the size of the hitbox to a size you desire
- You can change the image of the NextBot which is located inside the HumanoidRootPart named "CharacterGui"

]]

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Random = Random.new()

local Bot = script.Parent
local HRP = Bot.HumanoidRootPart
local Hitbox = Bot.Hitbox

local VisualizeFolder = Bot.VisualizeFolder
local Humanoid = Bot.Humanoid

local Config = require(script.Configuration)

local defaultPosition = Bot:GetPivot()
local clonedBot = Config.RegenerateBot and Bot:Clone()

local path: Path = PathfindingService:CreatePath(Config.AgentParameters)
local onDeathTrack, soundTracks = {}, {}
local isPlayingAudioTrack

local overlapParams = OverlapParams.new()
overlapParams.FilterDescendantsInstances = {Bot, table.unpack(Config.IgnoredObjects, 1, #Config.IgnoredObjects)}
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {Bot, table.unpack(Config.IgnoredObjects, 1, #Config.IgnoredObjects)}
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local audioPlayback: Sound = Instance.new("Sound")
for propertyName: string, propertyValue: any in Config.SoundSettings do
	audioPlayback[propertyName] = propertyValue
end

Humanoid.MaxHealth = Config.Health
Humanoid.Health = Config.Health
Humanoid.WalkSpeed = Config.Walkspeed
Humanoid.JumpPower = Config.JumpPower

for _, bodyPart: BasePart in Bot:GetDescendants() do
	if bodyPart:IsA("BasePart") then
		bodyPart:SetNetworkOwner(nil)
	end
end

local function loadAudioPlayback(soundId: string, name: string)
	if soundId and name and not soundTracks[name] then
		local newPlayback = audioPlayback:Clone()
		newPlayback.Parent = HRP
		newPlayback.SoundId = typeof(soundId) == "number" and "rbxassetid://"..soundId or soundId
		newPlayback.Name = name
		
		local customSoundProperties = Config.CustomSoundProperties[name]
		if customSoundProperties then
			for propertyName: string, propertyValue: any in customSoundProperties do
				newPlayback[propertyName] = propertyValue
			end
		end
		
		soundTracks[name] = newPlayback
	end
end

local function playAudioPlayback(name: string, yield: boolean)
	local audio: Sound = soundTracks[name]
	if Config.ShowState then
		Bot:SetAttribute("State", name)
	end
	
	if audio then
		if isPlayingAudioTrack then
			repeat RunService.Heartbeat:Wait() until not isPlayingAudioTrack
			if Humanoid.Health <= 0 then
				return
			end
		end
		
		for soundName: string, sound: Sound in soundTracks do
			if soundName ~= name then
				sound:Stop()
			end
		end
		
		if not audio.IsPlaying then
			audio:Play()
			
			if yield == true and audio.IsPlaying then
				isPlayingAudioTrack = true
				audio.Ended:Wait()
				isPlayingAudioTrack = false
			end
		end
	end
end

local function findNearestPlayer()
	local maxRange = Config.InfiniteRange and math.huge or Config.MaxDistance
	local range, playersInRange = {}, {}

	for _, player: Player in Players:GetPlayers() do
		local char = player.Character
		local humanoid: Humanoid = char and char:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health > 0 then
			local pos = char:GetPivot().Position
			local magnitude = (pos - HRP.Position).Magnitude

			if magnitude <= maxRange then
				if Config.CheckForForceField and char:FindFirstChildOfClass("ForceField") then
					continue
				end
				
				table.insert(range, magnitude)
				playersInRange[magnitude] = char
			end
		end
	end

	if #range >= 1 then
		table.sort(range, function(a, b)
			return a < b
		end)
		return playersInRange[range[1]]
	end
end

local function getPosition(char: Model)
	if char:IsDescendantOf(workspace) then
		return char:GetPivot().Position
	end
end

local function getVisualizer(pos: Vector3)
	local newPart = Instance.new("Part")
	newPart.Position = pos + (Vector3.yAxis * 3)
	newPart.Size = Vector3.one * 1.5
	newPart.Material = Enum.Material.Neon
	newPart.Color = Color3.new(1, 1, 1)
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = false
	newPart.Shape = Enum.PartType.Ball
	newPart.Massless = true
	
	return newPart
end

local linkingVisualizerEnabled = true
local function linkVisualizers(prevPos: Vector3, aftPos: Vector3)
	if not linkingVisualizerEnabled then
		return
	end

	local diff = (aftPos - prevPos)
	local position = (prevPos + aftPos) / 2
	local magnitude = diff.Magnitude
	
	local newPart = Instance.new("Part", VisualizeFolder)
	newPart.Anchored = true
	newPart.Size = Vector3.new(.3, .3, magnitude)
	newPart.CFrame = CFrame.lookAt(position, aftPos, Vector3.yAxis)
	newPart.Position = Vector3.new(position.X, aftPos.Y + 3, position.Z)
	newPart.Material = Enum.Material.Neon
	newPart.Color = Color3.new(1, 1, 1)
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = false
	newPart.CastShadow = false
	newPart.Massless = true
end

local function lockOntoPlayer(char: Model)
	local lowerHips = Vector3.new(0, HRP.Size.Y / 0.75, 0) 
	
	path:ComputeAsync(HRP.Position - lowerHips, getPosition(char))
	VisualizeFolder:ClearAllChildren()
	
	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		playAudioPlayback("Chasing")
		
		if Config.CustomYield or Config.UseMaxWaypoints then
			for i = 1, #waypoints do
				if i == 1 or i > (Config.MaxWaypoints + 1) then
					waypoints[i] = nil
				end
			end
		end
		
		if Config.VisualizePath then
			local lastPosition
			for _, waypoint: PathWaypoint in waypoints do
				local newPart = getVisualizer(waypoint.Position)
				newPart.Parent = VisualizeFolder
				
				if lastPosition then
					linkVisualizers(lastPosition, waypoint.Position)
				end
				lastPosition = waypoint.Position
			end
		end
		
		local lastWaypoint: PathWaypoint = waypoints[#waypoints]
		local prevWaypoint: PathWaypoint = waypoints[(Config.CustomYield or Config.UseMaxWaypoints) and #waypoints or 1]
		
		for _, waypoint: PathWaypoint in waypoints do
			local delayTime = (waypoint.Position - prevWaypoint.Position).Magnitude / Humanoid.WalkSpeed
			Humanoid:MoveTo(waypoint.Position)
			
			if Config.UseHeartbeat then
				RunService.Heartbeat:Wait()
			else
				if not Config.CustomYield then
					if (getPosition(char) - lastWaypoint.Position).Magnitude > Config.WaypointDistance then
						break
					end
				end
				
				task.wait(delayTime)
			end
			
			if Config.CustomYield then
				task.wait(Config.YieldDelay)
			end
			
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				if Config.AgentParameters and Config.AgentParameters.AgentCanJump then
					local position = getPosition(char)
					if position then
						if Config.CanUpdateJumpPower then
							local height = Config.JumpPower + math.abs(position.Y - HRP.Position.Y)
							Humanoid.JumpPower = height
							Humanoid.Jump = true
						else
							Humanoid.Jump = true
						end
					end
				end
			end
			
			prevWaypoint = waypoint
		end
	end
end

local function startWalking()
	local x = Random:NextNumber(-Config.StudsOffset, Config.StudsOffset)
	local z = Random:NextNumber(-Config.StudsOffset, Config.StudsOffset)
	
	local basePos = HRP.Position
	local newPosition = basePos + Vector3.new(x, 0, z)
	
	Humanoid:MoveTo(newPosition)
end

Humanoid.Died:Once(function()
	playAudioPlayback("Death", true)
	
	if clonedBot then
		clonedBot:PivotTo(defaultPosition)
		clonedBot.Parent = Bot.Parent
	end
	
	audioPlayback:Destroy()
	for index, sound in soundTracks do
		sound:Destroy()
		soundTracks[index] = nil
	end
	
	table.clear(onDeathTrack)
	Bot:Destroy()
end)

local Connection
Connection = RunService.Heartbeat:Connect(function()
	if Humanoid.Health <= 0 then
		Connection:Disconnect()
		Connection = nil
	end
	
	local partsInBox = workspace:GetPartBoundsInBox(Hitbox.CFrame, Hitbox.Size, overlapParams)
	if partsInBox and #partsInBox >= 1 then
		for _, obj in partsInBox do
			local char: Model = obj:FindFirstAncestorOfClass("Model")
			local player: Player = char and Players:GetPlayerFromCharacter(char)
			
			if player then
				local humanoid: Humanoid = char:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					if Config.CheckForForceField and char:FindFirstChildOfClass("ForceField") then
						continue
					end
										
					if Config.DamageInstantly then
						humanoid.Health = 0
					else
						local t = onDeathTrack[player.UserId]
						if t and os.clock() - t < Config.Debounce then
							continue
						end
						
						onDeathTrack[player.UserId] = os.clock()
						humanoid.Health -= Config.Damage
					end
					
					VisualizeFolder:ClearAllChildren()
					if humanoid.Health <= 0 then
						playAudioPlayback("Kill", true)
					end
				end
			end
		end
	end
end)

for soundName: string, soundId: any in Config.Sounds do
	loadAudioPlayback(soundId, soundName)
end

while Humanoid.Health > 0 do
	local target = findNearestPlayer()
	if target then
		if Config.CheckForWalls then
			local humanoidRootPart: BasePart = target:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				local diff = (humanoidRootPart.Position - HRP.Position)
				local direction = diff.Unit * (diff.Magnitude + 1)
				local raycast = workspace:Raycast(HRP.Position, direction, raycastParams)
				
				if raycast then
					local instance = raycast.Instance:FindFirstAncestorOfClass("Model")
					if instance and target == instance then
						lockOntoPlayer(target) 
						continue
					end
				end
			end
		else
			lockOntoPlayer(target) 
			continue
		end
	end
	
	playAudioPlayback("Roaming")
	if Config.RandomWalking then
		startWalking()
	end
	
	RunService.Heartbeat:Wait()
end