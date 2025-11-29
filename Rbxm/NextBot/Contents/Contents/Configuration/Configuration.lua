return {
	InfiniteRange = true; -- Determines whether the bot can lock onto players at extremely far distances
	MaxDistance = 100, -- If InfiniteRange is false, this value is used as the max distance the bot can search for players

	Health = math.huge; -- The humanoid Health/MaxHealth for the bot
	Walkspeed = 65; -- The humanoid Walkspeed for the bot
	JumpPower = 50; -- The humanoid JumpPower (variable) for the bot

	CheckForWalls = false; -- Checks if the player is behind a wall. If so, it will not lock onto it
	CheckForForceField = false; -- Checks if the player has a ForceField

	RandomWalking = true; -- If the bot does not find a target, it will wander randomly until it finds one
	StudsOffset = 50; -- The range in which the bot can randomly walk to

	UseHeartbeat = true; -- If true, uses the RunService.Heartbeat:Wait() event to wait until it can move to the next waypoint (tends to be less accurate). Otherwise, it uses the operation (magnitude / speed) instead (tends to be more accurate)

	VisualizePath = false; -- Shows the path that was created (set 'linkingVisualizerEnabled' to false that is inside the main script if you don't wanna see the line that connects between two waypoints)
	RegenerateBot = true; -- If the humanoid dies, it will respawn to its original position

	CanUpdateJumpPower = true; -- Updates the JumpPower based on the differences between the bot Y level and the player's Y level

	WaypointDistance = 10; -- If UseHeartbeat is false, it uses this value to check whether it is out of range from the furthest waypoint. In this case, it will regenerate a path

	UseMaxWaypoints = false; -- Controls the amount of waypoints that are created from the path
	MaxWaypoints = 1; -- If UseMaxWaypoints or CustomYield are true, it uses this value to determine the number of waypoints created

	CustomYield = false; -- Yields the bot at its place until it can move to the next waypoint
	YieldDelay = 1; -- If CustomYield is true, uses this value as the delay when moving to the next waypoint

	ShowState = true; -- Updates the attribute "State" that is within the bot attributes to display the current state that the bot is in

	IgnoredObjects = {}; -- The Instances (value cannot be nil) that will be ignored when attempting to raycast to check for a wall and the objects whose bounding boxes collide with the bot's hitbox
	AgentParameters = { -- The Agent Parameters that are used when creating a path (case sensitive)
		AgentCanJump = true; -- Determines if paths can be created at locations where the bot needs to jump
		WaypointSpacing = 15; -- The space between each created waypoint
		AgentRadius = 4; -- The minimum radius required for a path to be considered traversable
		AgentHeight = 7; -- The minimum total height required for a path to be considered traversable
	};

	DamageInstantly = true; -- If a player touches the bot's hitbox, it will set its health to 0
	Debounce = 0.5; -- If DamageInstantly is false, it uses this delay to wait until it can damage the player again
	Damage = 100; -- If DamageInstantly is false, along with Debounce, the damage that is applied to the player's health

	SoundSettings = { -- The settings for sounds (case sensitive) (uses the Sound Instance properties)
		PlayOnRemove = false;
		Looped = false;
		PlaybackSpeed = 1;
		Volume = 0.5;
	};

	CustomSoundProperties = { -- Custom sound properties for the indexes that are in the Sounds table (case sensitive) (uses the Sound Instance properties)
		Roaming = {
			Looped = true;
		};

		Chasing = {
			Looped = true;
			Volume = 0.75;
		};
	};

	Sounds = { -- Sounds that are used for the bot (value must be either a string ("rbxassetid://xxx") or a number (asset id) or nil)
		Roaming = nil; -- Plays when no player is found and the bot is wandering around
		Chasing = nil; -- Plays when the bot is locked onto a player and is currently in the "Chasing" state
		Death = nil; -- Plays when the bot dies due to natural causes or from external factors
		Kill = nil; -- Plays when the bot kills a player
	};
}