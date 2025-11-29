--!nocheck

local Debris = game:GetService("Debris")
return {

	BulletFolderName = "BulletsFolder", --> The folder name, where bullets are stored

	MaxDistance = 1000, --> The max distance the mouse can click away from the camera
	Damage = 15, --> The damage per bullet that is inflicted onto a humanoid object
	Rate = 0.45, --> The fire rate speed; how fast the gun can shoot per bullet

	Exclusions = {}, --> Instances that are excluded when creating a raycast (server) operation

	CheckForPlayers = false, --> Only shoots players and not other humanoid objects
	CheckForForceField = true, --> Uses the Humanoid:TakeDamage() function, which checks for an existing forcefield

	FirstPersonView = false, --> Makes your camera switch to first person mode once equipped
	NoFriendlyFire = false, --> If true, prevents the ability to shoot your own team members
	Automatic = true, --> Makes the gun automatic, by holding LMB or TOUCH

	EnableMobileControls = true, --> Uses ContextActionService mobile buttons binded to reloading, zooming in/out
	ActionSettings = { --> Action settings (mobile buttons) for ContextActionService
		Reload = {
			Name = "Reload", --> Action Name
			Title = "R", --> Button Title
			Description = nil, --> Button Description
			Image = nil, --> Button Image
			Position = UDim2.new(0.5, 0, 0.15, 0), --> Button Image
		},

		ZoomIn = {
			Name = "ZoomIn",
			Title = "+",
			Description = nil,
			Image = nil,
			Position = UDim2.new(0.33, 0, 0.4, 0),
		},

		ZoomOut = {
			Name = "ZoomOut",
			Title = "-",
			Description = nil,
			Image = nil,
			Position = UDim2.new(0.75, 0, 0.15, 0),
		},
	},

	BulletMarkEnabled = true, --> Calls the OnBulletMark() function (Config.Bullet.Enabled must be enabled)
	OnBulletMark = function(raycastResult: RaycastResult) --> What happens at the bullet 'end' position after shooting
		local position = raycastResult.Position
		local normal = raycastResult.Normal

		local lookDirection = CFrame.new(position, position + normal)

		local markFolder: Folder = workspace:FindFirstChild("BulletMarksFolder")
		if not markFolder then
			local newFolder = Instance.new("Folder", workspace)
			newFolder.Name = "BulletMarksFolder"

			markFolder = newFolder
		end

		local mark = Instance.new("Part", markFolder)
		mark.Name = "BulletMark"
		mark.Anchored = true
		mark.Transparency = 1
		mark.Size = Vector3.new(1, 1, 0.1)
		mark.CanCollide = false
		mark.CastShadow = false
		mark.CanTouch = false
		mark.CanQuery = false
		mark.Position = position
		mark.CFrame = lookDirection

		local decal = Instance.new("Decal", mark)
		decal.Texture = "rbxassetid://176678487"

		Debris:AddItem(mark, 3)
		return {markFolder} --> Objects to be excluded (Type: table: {Array: Instance})
	end,

	CreatorTag = { --> Creates a StringValue inside the Humanoid, with the value of the player's name who hit the object
		Enabled = false,
		Name = "CreatorTag",
	},

	UIFormat = { --> String formats used for the AmmoUI (%s indicates values)
		GunName = "%s",
		Ammo = "Ammo: %s / %s",
		Reload = "Reloading..",
		InfiniteAmmo = "inf",
	},

	Reload = { --> Reloading feature for the gun
		Enabled = true, --> If false, the gun will have infinite ammo
		Key = Enum.KeyCode.R, --> The key (using Enum.Keycode) used to trigger the action

		MaxAmmo = 15, --> The max amount of ammo applied for this gun
		Speed = 2, --> How fast does the action take place
	},

	Zoom = { --> Zooming in/out using the camera
		Enabled = false,
		Key = Enum.UserInputType.MouseButton2, --> The key (using Enum.UserInputType) used to trigger the action

		StartZooming = function(Camera: Camera) --> Fires when the player zooms in
			local fov: number = 30
			Camera.FieldOfView = fov
		end,

		StopZooming = function(Camera: Camera) --> Fires when the player stops zooming
			local fov: number = 70
			Camera.FieldOfView = fov
		end,
	},

	BodyPartDamageEnabled = true, --> Creates a custom damage for a body part
	CustomBodyParts = { --> A dictionary containing the body part name, and the damage that should be inflicted
		["Head"] = 25, --> Capitalization matters!
	},

	Input = "UserInputType", --> The enum type, UserInputType for this case
	InputTypes = {Enum.UserInputType.Touch, Enum.UserInputType.MouseButton1}, --> An array of enums that are used to begin the shooting (action)

	Bullet = { --> Custom properties for a bullet (not referencing actual properties)
		Enabled = true, --> Determines whether bullets are shown on the server
		Size = 0.025, --> The size (X and Y)
		Color = Color3.fromRGB(226, 161, 70), --> The color
		Material = Enum.Material.Neon, --> The material
		Lifespan = 0.25, --> How long will the bullet last before being destroyed (visual only)
		Transparency = 0.85, --> The transparency
	},

	SoundSettings = { --> Actual properties for sounds that are created within the handle
		Volume = 0.25,
	},

	Sounds = { --> A dictionary of sound id's, with the key being the sound name, and the value being the sound id
		Shoot = "rbxassetid://8169240213",
		Reload = "rbxassetid://8190500163",
		NoAmmo = "rbxassetid://9113107031",
	},

}