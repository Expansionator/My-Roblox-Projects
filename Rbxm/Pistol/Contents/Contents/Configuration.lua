return {
	FireRate = .45; -- How fast the gun can shoot
	MaxDistance = 150; -- The max distance the gun can shoot
	
	InfiniteAmmo = false; -- Makes it so that there is no reloading
	MaxAmmo = 17; -- The max ammo for the gun
	
	ReloadSpeed = 1.25; -- How fast the gun reloads
	ReloadKey = Enum.KeyCode.R; -- The key to reload

	Automatic = true; -- Allows the ability to hold and shoot

	CreateTouchButton = true; -- Creates a mobile touch button to reload
	ButtonProperties = { -- Properties for the touch button
		Title = "R";
		Description = nil;
		Image = nil;
		Position = UDim2.new(0.5, 0, 0.15, 0);
	};

	ShowAmmoUI = true; -- Shows the Ammo UI at the bottom right of the screen

	SafeProtection = true; -- Checks the character for a forcefield

	TeamCheck = false; -- Stops damaging if the player's team is in the list
	ValidTeams = {}; -- The teams to ignore (array of strings)

	NoFriendlyFire = true; -- Prevents shooting your own teammates if they're on the same team

	CreatorTagName = "CreatorTag"; -- The name for the tag (StringValue)
	CreatorTag = true; -- Creates a StringValue under the humanoid with the username of who shot the target

	BulletVisualization = true; -- Visualizes the bullet when shooting
	RayBulletType = true; -- If true, makes the bullet look like a block

	BulletLifetime = 0.25; -- How long the bullet last before being destroyed
	BulletSpeed = 5; -- The speed at which the bullet is traveling

	BulletProperties = { -- Properties for the bullet
		Color = Color3.fromRGB(255, 242, 99);
		Material = Enum.Material.Neon;
		Sizes = {
			X = .25;
			Y = .25;
			Z = 1.5;
		};
	};
	
	Animations = { -- Animations that plays when using the gun (in numbers)
		R6 = { --R6 Animations
			Idle = nil;
			Shoot = nil;
			Reload = nil;
		};
		
		R15 = { -- R15 Animations
			Idle = nil;
			Shoot = nil;
			Reload = nil;
		};
	};

	OnlyShootPlayers = false; -- Shoots only real players and not bots

	BaseDamage = 15; -- The base damage for all body parts except the head

	HeadshotEnabled = true; -- Deals additional damage if aimed onto the head
	HeadDamage = 35; -- The headshot damage
}