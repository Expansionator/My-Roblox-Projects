--!nocheck
-- @fattah412

--[[

Turret:
A basic Turret system that can shoot players if they're in range.

------------------------------------------------------------------------------

Notes:

- This script cannot adapt to other models if their properties are not the same
- The turret cannot detect anything else except players
- This model is fully editable, but be careful when doing so

------------------------------------------------------------------------------

]]

local RANGE_TO_TARGET = 50 -- The maximum distance the turret can check for
local DAMAGE_PER_BULLET = 15 -- The damage per bullet hit
local FIRING_SPEED = 0.45 -- How fast each bullet can be fired

local CHECK_FOR_WALLS = false -- Stops firing if the target is behind a wall
local USE_RAY_LINE_TO_SHOOT = false -- If true, uses a beam-like bullet projectile

local BULLET_SPEED = 70 -- How fast should the bullet be
local BULLET_DELETE_TIMER = 3 -- The duration before the bullet gets destroyed

local LIMITED_AMMO = false -- If true, the turret has a limited amount of ammo before it has to reload
local TOTAL_AMMO = 30 -- The total ammo for the turret
local RELOAD_SPEED = 3 -- How fast should the reload speed be

local CHECK_FOR_FORCEFIELD = true -- Checks if the target has a forcefield
local TARGET_SAME_PLAYER_UNTIL_FAILURE = false -- Targets the same player until death or out of bounds
local ALLOW_BULLET_HIT_OTHER_PLAYERS = false -- Allows the bullet to damage other players when 'USE_RAY_LINE_TO_SHOOT' is false

local BULLET_SIZE_INCREMENT = 0.5 -- If 'USE_RAY_LINE_TO_SHOOT' is false, uses this increment for the bullet size that's shaped like a ball

local SHOOT_SOUND_ID = nil -- The sound that will be played when the turret is shooting
local RELOAD_SOUND_ID = nil -- The sound that will be played when the turret is reloading
local BASE_SOUNDS_VOLUME = 1 -- The volume for both sound id's

------------------------------------------------------------------------------

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Turret = script.Parent
local BulletTemplate = Turret.Bullet
local Structure = Turret.Structure
local BulletVisuals = Turret.BulletVisuals

local GetClosestPlayer = require(script.GetClosestPlayer)
local PrimaryPart = Structure.Barrel

local isReloading, shootingSound, reloadSound
local currentAmmo = TOTAL_AMMO

local function loadSoundId(soundId: number)
	if soundId and typeof(soundId) == "number" then
		local newSound = Instance.new("Sound", Structure.Body)
		newSound.SoundId = "rbxassetid://"..soundId
		newSound.Volume = BASE_SOUNDS_VOLUME
		newSound.Name = "Turret Audio"

		return newSound
	end
end

local function playSoundId(sound: Instance)
	if sound then
		sound:Play()
	end
end

local function _shoot(char: Model, target: Player)
	local charPosition = char:GetPivot()
	local direction = (charPosition.Position - PrimaryPart.Position)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local BARREL_EDGE_POSITION = (PrimaryPart.Position - (PrimaryPart.CFrame.RightVector * 2))

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local function approxShoot()
		if LIMITED_AMMO then
			currentAmmo -= 1
		end

		local bullet = BulletTemplate:Clone()
		bullet.Transparency = 0

		playSoundId(shootingSound)

		if USE_RAY_LINE_TO_SHOOT then
			bullet.Anchored = true
			bullet.Size = Vector3.new(bullet.Size.X, bullet.Size.Y, direction.Magnitude)
			bullet.CFrame = CFrame.lookAt(BARREL_EDGE_POSITION, charPosition.Position)
			bullet.Position = (BARREL_EDGE_POSITION + charPosition.Position) / 2

			humanoid.Health -= DAMAGE_PER_BULLET
		else
			local attachment = Instance.new("Attachment", bullet)
			local linearVelocity = Instance.new("LinearVelocity")
			linearVelocity.MaxForce = math.huge
			linearVelocity.Attachment0 = attachment
			linearVelocity.VectorVelocity = direction.Unit * BULLET_SPEED

			bullet.Position = BARREL_EDGE_POSITION
			bullet.Shape = Enum.PartType.Ball
			bullet.Size += Vector3.new(BULLET_SIZE_INCREMENT, BULLET_SIZE_INCREMENT, BULLET_SIZE_INCREMENT)
			bullet.Anchored = false

			linearVelocity.Parent = attachment

			local Connection
			Connection = bullet.Touched:Connect(function(hit)
				if hit and hit.Parent then
					local char = hit.Parent:IsA("Model") and hit.Parent
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local player = hum and Players:GetPlayerFromCharacter(char)

					if player then
						if not ALLOW_BULLET_HIT_OTHER_PLAYERS then
							if player.UserId ~= target.UserId then
								return
							end
						end

						humanoid.Health -= DAMAGE_PER_BULLET
						bullet:Destroy()

						Connection:Disconnect()
					end
				end
			end)
		end

		bullet.Parent = BulletVisuals
		Debris:AddItem(bullet, BULLET_DELETE_TIMER)
	end

	if CHECK_FOR_WALLS then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {Turret}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.IgnoreWater = true

		local ray: RaycastResult = workspace:Raycast(PrimaryPart.Position, direction.Unit * direction.Magnitude, raycastParams)
		if ray and ray.Instance:IsDescendantOf(char) then
			approxShoot()
		end
	else
		approxShoot()
	end
end

local function shootTarget(char: Model, target: Player)
	if not LIMITED_AMMO then
		_shoot(char, target)
	else
		if currentAmmo > 1 then
			_shoot(char, target)
		else
			isReloading = true
			playSoundId(reloadSound)

			currentAmmo = TOTAL_AMMO
			task.wait(RELOAD_SPEED)

			isReloading = false
		end
	end
end

local function aimAtTarget(target: Player)
	local Connection = RunService.Heartbeat:Connect(function()
		local char: Model = target.Character
		if char and not isReloading then
			local charPosition = char:GetPivot()
			local bodyPosition = Structure.Body.Position

			Structure.Body.CFrame = CFrame.lookAt(bodyPosition, Vector3.new(charPosition.X, bodyPosition.Y, charPosition.Z))
			Structure.Head.CFrame = CFrame.lookAt(Structure.Head.Position, charPosition.Position)
		end
	end)
	return Connection
end

local function lockOntoTarget(target: Player)
	local char: Model = target.Character
	if char then
		local Connection = aimAtTarget(target)
		while char and char:IsDescendantOf(workspace) and (char:GetPivot().Position - PrimaryPart.Position).Magnitude <= RANGE_TO_TARGET do
			shootTarget(char, target)			
			task.wait(FIRING_SPEED)

			if not TARGET_SAME_PLAYER_UNTIL_FAILURE then
				local preTarget = GetClosestPlayer(PrimaryPart, RANGE_TO_TARGET)
				if preTarget and target.UserId ~= preTarget.UserId then
					break
				end
			end
		end

		Connection:Disconnect()
		Connection = nil

		isReloading = false
	end
end

local function checkForTarget()
	local target = GetClosestPlayer(PrimaryPart, RANGE_TO_TARGET)
	if target then
		local char: Model = target.Character
		if char then
			if CHECK_FOR_FORCEFIELD then
				if not char:FindFirstChildOfClass("ForceField") then
					lockOntoTarget(target)
				end
			else
				lockOntoTarget(target)
			end
		end
	end
end

shootingSound = loadSoundId(SHOOT_SOUND_ID)
reloadSound = loadSoundId(RELOAD_SOUND_ID)

while true do
	checkForTarget()
	task.wait(1)
end