--!nocheck
-- @fattah412

--[[

AnimationHandler:
A module that handles animation-based requests for the player.

--------------------------------------------------------------

Notes:

- If this module is required from a LocalScript, the additional "Player" argument is not needed
- PlayAnimation() and LoadAnimation() will not run if there's an existing animation played/loaded (Stop the animation to first)
	> If "WaitUntilFinished" is true for PlayAnimation(), it will wait until the current animation finishes, which will then be stopped
- This module can be required from both server and client
- If "IgnoreStoringAnimation" is true for LoadAnimation(), it will not store the animation but instead give you full control over it
	> However, other functions would not work when attemping to use this animationId

--------------------------------------------------------------

Usage:

--> Functions:

AnimationHandler.LoadAnimation(AnimationId: string | number, Player: Player?, IgnoreStoringAnimation: boolean?): AnimationTrack
> Description: Creates an animation in the humanoid, and loads a track which can be used outside of this ModuleScript
> Returns: AnimationTrack | nil

AnimationHandler.PlayAnimation(AnimationId: string | number, Player: Player?, WaitUntilFinished: boolean?)
> Description: Plays an animation that was not loaded. Optional argument "WaitUntilFinished" waits and destroys the animation after finished playing
> Returns: nil

AnimationHandler.WaitUntilFinished(AnimationId: string | number, Player: Player?)
> Description: Waits an existing animation until it finishes playing
> Returns: nil

AnimationHandler.StopAnimation(AnimationId: string | number, Player: Player?)
> Description: Stops an existing animation and releases it from memory
> Returns: nil

AnimationHandler.StopAllAnimations(Player: Player?)
> Description: Similar to StopAnimation(), but stops all existing stored animations
> Returns: nil

AnimationHandler.GetAnimations(Player: Player?): {[string]: {}}
> Description: Returns a table with all existing stored animation ids, as well as the actual stored used table
> Returns: table: {AnimationIds = {string}, Raw = {[AnimationId] = {Track = AnimationTrack, Animation = Animation}}}

--------------------------------------------------------------

Example Usage:
[Client]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AnimationHandler = require(ReplicatedStorage.AnimationHandler)
local AnimationId = "rbxassetid://xxxxxxxxxx"

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.F then
		AnimationHandler.PlayAnimation(AnimationId, nil, true)
	end
end)

--------------------------------------------------------------

]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AnimationHandler = {}

local self = {activeTracks = {}}
self.isClient = RunService:IsClient()
self.player = self.isClient and Players.LocalPlayer

local function getAnimationId(animationId): string
	if not animationId then return end
	if typeof(animationId) == "number" then
		return "rbxassetid://"..animationId
	end
	return (typeof(animationId) == "string" and 
		(animationId:find("rbxassetid://") or animationId:find("http://www.roblox.com/asset/?id="))
		and animationId)
end

local function getArguments(animationId, Player, ignoreAnim): (string, Player)
	local player: Player = self.player or Player
	assert(player, "No player found!")
	assert(player:IsA("Player"), "Player is not a player!")

	if ignoreAnim then
		return player
	end

	local AnimationId: string = getAnimationId(animationId)
	assert(AnimationId, "Animation ID not found!")

	return AnimationId, player
end

local function cleanUpTable(player: Player)
	local userId = player.UserId
	if self.activeTracks[userId] then
		for animationId: string, _ in self.activeTracks[userId] do
			AnimationHandler.StopAnimation(animationId, player)
		end

		self.activeTracks[userId] = nil
	end
end

function AnimationHandler.LoadAnimation(AnimationId: string | number, Player: Player?, IgnoreStoringAnimation: boolean?): AnimationTrack
	local animationId, player = getArguments(AnimationId, Player)
	local char: Model = player.Character

	if char then
		local humanoid: Humanoid = char:FindFirstChildOfClass("Humanoid")
		local animator: Animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		local userId: number = player.UserId

		self.activeTracks[userId] = self.activeTracks[userId] or {}

		if animator and not self.activeTracks[userId][animationId] then
			local animation = Instance.new("Animation", humanoid)
			animation.Name = "Anim"
			animation.AnimationId = animationId

			local animationTrack: AnimationTrack = animator:LoadAnimation(animation)
			if not IgnoreStoringAnimation then
				self.activeTracks[userId][animationId] = {
					Track = animationTrack,
					Animation = animation
				}
			end

			return animationTrack
		end
	end
end

function AnimationHandler.PlayAnimation(AnimationId: string | number, Player: Player?, WaitUntilFinished: boolean?)
	local animationTrack = AnimationHandler.LoadAnimation(AnimationId, Player)
	if animationTrack and not animationTrack.IsPlaying then
		repeat RunService.Heartbeat:Wait() until animationTrack.Length > 0
		animationTrack:Play()

		if WaitUntilFinished then
			AnimationHandler.WaitUntilFinished(AnimationId, Player)
			AnimationHandler.StopAnimation(AnimationId, Player)
		end
	end
end

function AnimationHandler.WaitUntilFinished(AnimationId: string | number, Player: Player?)
	local animationId, player = getArguments(AnimationId, Player)
	local userId = player.UserId
	local tab = self.activeTracks[userId] and self.activeTracks[userId][animationId]

	if tab then
		local animationTrack: AnimationTrack = tab.Track
		if animationTrack.IsPlaying and animationTrack.Length > 0 then
			animationTrack.Ended:Wait()
		end
	end
end

function AnimationHandler.StopAnimation(AnimationId: string | number, Player: Player?)
	local animationId, player = getArguments(AnimationId, Player)
	local userId = player.UserId
	local tab = self.activeTracks[userId] and self.activeTracks[userId][animationId]

	if tab then
		local animationTrack: AnimationTrack = tab.Track
		local animationInstance: Animation = tab.Animation

		if animationTrack.IsPlaying then
			animationTrack:Stop()
		end

		animationTrack:Destroy()
		animationInstance:Destroy()

		self.activeTracks[userId][animationId].Animation = nil
		self.activeTracks[userId][animationId].Track = nil
		self.activeTracks[userId][animationId] = nil
	end
end

function AnimationHandler.StopAllAnimations(Player: Player?)
	local player: Player = getArguments(nil, Player, true)
	local animationTable = AnimationHandler.GetAnimations(player)

	if animationTable then
		for _, animationId: string in animationTable.AnimationIds do
			AnimationHandler.StopAnimation(animationId, player)
		end
	end
end

function AnimationHandler.GetAnimations(Player: Player?): {[string]: {}}
	local player: Player = getArguments(nil, Player, true)
	local originalTable = self.activeTracks[player.UserId]

	if originalTable then
		local newTable = {
			Raw = originalTable; 
			AnimationIds = {};
		}

		for animationId: string, _ in originalTable do
			table.insert(newTable.AnimationIds, animationId)
		end

		return newTable
	end
end

do
	Players.PlayerRemoving:Connect(function(player)
		if self.isClient then
			if player.UserId == self.player.UserId then
				cleanUpTable(player)
			end
			return
		end

		cleanUpTable(player)
	end)
end

return AnimationHandler