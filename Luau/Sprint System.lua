--!nocheck
-- @fattah412

--[[

Sprint System:
A sprinting system with many settings that can configured.

--------------------------------------------------------------------------

Notes:

- Place this script in StarterPlayer > StarterCharacterScripts
- RUNNING_ANIMATION_IDS and WALKING_ANIMATION_IDS requires a table with both R6 and R15 type
- If STAMINA_SYSTEM is true, a Number value and an attribute wlll be created in this script
- If TOGGLE_SPRINT is true, the player has to click the same key again to activate/deactive the sprint
- Comments are provided beside each variable

--------------------------------------------------------------------------

]]

--> Basic Configuration <--

local ACTION_NAME = "Sprint_System" -- The action named used for ContextActionService

local MAX_SPEED = 32 -- The max speed that the player will have
local DEFAULT_SPEED = 16 -- The default speed that is assigned by default

local GRADUAL_SPEED = false -- Slowly increments the player's speed until it reaches the max speed
local GRADUAL_TOTAL_SPEED = 3 -- The total duration used to reach to the max speed

local CAMERA_FOV_CHANGE = true -- Changes the camera FOV when sprinting/walking
local FOV_CHANGING_SPEED = GRADUAL_SPEED and GRADUAL_TOTAL_SPEED or 0.5 -- The speed in which the camera changes to a new FOV
local DEFAULT_CAMERA_FOV = 70 -- The default FOV for the camera
local MAX_CAMERA_FOV = 140 -- The max FOV for the camera

local TOGGLE_SPRINT = false -- Uses a toggle system for sprinting. If false, it will require the player to hold the button

local STAMINA_SYSTEM = false -- Makes it so that the player has limited sprint based on their stamina. Creates a Number value inside this script indicating the user's stamina
local MAX_STAMINA = 100 -- The max stamina that the player can have
local STAMINA_INCREMENT = 1 -- How many steps before reaching the max stamina
local STAMINA_SPEED = 0.5 -- In seconds, how long will it take to regenerate/degenerate the stamina

local STOP_SPRINTING_UPON_NOT_MOVING = true -- The script will stop sprinting once the player is not moving

-- Format for animationIds is {R15 = 0, R6 = 0}. For example: local RUNNING_ANIMATION_IDS = {R15 = 123, R6 = nil}
local RUNNING_ANIMATION_IDS = nil -- Plays the animation ids when the player is running
local WALKING_ANIMATION_IDS = nil -- Plays the animation ids when the player is walking

local SPRINT_KEY = Enum.KeyCode.LeftShift -- The key used to sprint
local MOBILE_TOUCH_BUTTON = true -- Adds a mobile touch button near to the jump button
local MOBILE_TOUCH_BUTTON_SETTINGS = { -- The settings for that touch button
	Title = "Sprint"; -- The title of the button
	Position = UDim2.new(1, -130,1, -130); -- The position it will be at
	Description = nil; -- A description that the button will have
	Image = nil; -- An image that will be displayed on the button
}

------------------------------------------------------------------------
--> DO NOT EDIT BELOW <--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local character = player.Character
local humanoid: Humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera
local animator: Animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local isSprinting, runningTrack, walkingTrack, staminaValue, connection
local currentStamina = MAX_STAMINA

local function createTrack(id)
	if id then
		local rigType = humanoid.RigType.Name
		if id[rigType] then
			local animationObject = Instance.new("Animation", script)
			animationObject.AnimationId = "rbxassetid://"..id[rigType]

			return animator:LoadAnimation(animationObject)
		end
	end
end

runningTrack = createTrack(RUNNING_ANIMATION_IDS)
walkingTrack = createTrack(WALKING_ANIMATION_IDS)

if STAMINA_SYSTEM then
	staminaValue = Instance.new("NumberValue", script)
	staminaValue.Value = MAX_STAMINA
	staminaValue.Name = "Stamina"

	script:SetAttribute("Stamina", MAX_STAMINA)
end

local function tween(...)
	local object = TweenService:Create(...)
	object:Play()

	return object
end

local function stopSprinting()
	if runningTrack then
		runningTrack:Stop()
	end

	if walkingTrack then
		walkingTrack:Play()
	end

	if GRADUAL_SPEED then
		tween(humanoid, TweenInfo.new(GRADUAL_TOTAL_SPEED), {WalkSpeed = DEFAULT_SPEED})
	else
		humanoid.WalkSpeed = DEFAULT_SPEED
	end

	if CAMERA_FOV_CHANGE then
		tween(camera, TweenInfo.new(FOV_CHANGING_SPEED), {FieldOfView = DEFAULT_CAMERA_FOV})
	end
end

local function startSprinting()
	if runningTrack then
		runningTrack:Play()
	end

	if walkingTrack then
		walkingTrack:Stop()
	end

	if GRADUAL_SPEED then
		tween(humanoid, TweenInfo.new(GRADUAL_TOTAL_SPEED), {WalkSpeed = MAX_SPEED})
	else
		humanoid.WalkSpeed = MAX_SPEED
	end

	if CAMERA_FOV_CHANGE then
		tween(camera, TweenInfo.new(FOV_CHANGING_SPEED), {FieldOfView = MAX_CAMERA_FOV})
	end
end

local function configureSpeed(action: "Start" | "End")
	if action == "Start" then
		startSprinting()
	elseif action == "End" then
		stopSprinting()
	end
end

local function onSprinting(actionName, inputState: Enum.UserInputState)
	if actionName == ACTION_NAME then
		if TOGGLE_SPRINT then
			if inputState == Enum.UserInputState.Begin then
				isSprinting = not isSprinting
				configureSpeed(isSprinting and "Start" or "End")
			end
		else
			if inputState == Enum.UserInputState.Begin then
				isSprinting = true
				configureSpeed("Start")
			elseif inputState == Enum.UserInputState.End then
				isSprinting = false
				configureSpeed("End")
			end
		end
	end
end

ContextActionService:BindAction(ACTION_NAME, onSprinting, MOBILE_TOUCH_BUTTON, SPRINT_KEY)

if MOBILE_TOUCH_BUTTON then
	if MOBILE_TOUCH_BUTTON_SETTINGS.Title then
		ContextActionService:SetTitle(ACTION_NAME, MOBILE_TOUCH_BUTTON_SETTINGS.Title)
	end

	if MOBILE_TOUCH_BUTTON_SETTINGS.Position then
		ContextActionService:SetPosition(ACTION_NAME, MOBILE_TOUCH_BUTTON_SETTINGS.Position)
	end

	if MOBILE_TOUCH_BUTTON_SETTINGS.Description then
		ContextActionService:SetDescription(ACTION_NAME, MOBILE_TOUCH_BUTTON_SETTINGS.Description)
	end

	if MOBILE_TOUCH_BUTTON_SETTINGS.Image then
		ContextActionService:SetImage(ACTION_NAME, MOBILE_TOUCH_BUTTON_SETTINGS.Image)
	end
end

humanoid.Died:Once(function()
	ContextActionService:UnbindAction(ACTION_NAME)
	if isSprinting then
		stopSprinting()
	end
	if connection and connection.Connected then
		connection:Disconnect()
	end
end)

if STOP_SPRINTING_UPON_NOT_MOVING then
	connection = RunService.Heartbeat:Connect(function()
		if humanoid.MoveDirection.Magnitude == 0 and isSprinting then
			isSprinting = false
			stopSprinting()
		end
	end)
end

if STAMINA_SYSTEM then
	while true do
		if currentStamina < STAMINA_INCREMENT and isSprinting then
			isSprinting = false
			stopSprinting()
		end

		if isSprinting and currentStamina >= STAMINA_INCREMENT then
			currentStamina -= STAMINA_INCREMENT
		elseif not isSprinting and currentStamina < MAX_STAMINA then
			currentStamina += STAMINA_INCREMENT
		elseif currentStamina > MAX_STAMINA then
			currentStamina = MAX_STAMINA
		end

		staminaValue.Value = currentStamina
		script:SetAttribute("Stamina", currentStamina)

		task.wait(STAMINA_SPEED)
	end
end
