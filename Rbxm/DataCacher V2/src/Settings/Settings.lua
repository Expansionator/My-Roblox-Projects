--!nocheck

--// Settings:
--// Default settings used when creating a Datastore using DataCacher.

--// Note:
--// Settings marked with [Important] require manual configuration.
--// CreateDatastore() accepts a table of "Datastore" settings to use. Otherwise, the default settings listed here are applied.

export type Globals = {

	BurnerDataStore: string,
	MockDatastoreSuffix: string,

	MockDatastore: boolean,
	PreviousVersionSupport: boolean,
	SandboxMode: boolean,
	AutoSave: boolean,

	AutoSaveInterval: number,
	SessionDeadThreshold: number,

}

export type Datastore = {

	DataKey: string,
	SessionKey: string,

	KeySuffix: string,
	InternalKey: string,
	IndexingName: string,

	ProfileLockText: string,
	ProfileDeletionText: string,

	Reconcile: boolean,
	AutoRetry: boolean,

	RetryAttempts: number,

	Key: ( Username: string, UserId: number ) -> string,

	TemplateData: {},

}

export type Settings = {

	Globals: Globals,
	Datastore: Datastore,

}

return {

	--// All global-related settings
	Globals = {

		--// A Datastore name used to check whether Datastore services are online
		BurnerDataStore = "_____DataCacher_DS",

		--// Creates a Datastore that simulates real Datastore behavior, restricted to Studio usage only
		--// Uses a localized Datastore within Studio if API services are available
		--// Otherwise, falls back to a fake Datastore that does not perform asynchronous requests
		MockDatastore = true,

		--// If MockDatastore is true and this value is true, the mode is forced to SANDBOX
		SandboxMode = false,

		--// The suffix appended to the configured Datastore name if in Studio
		MockDatastoreSuffix = "__Studio",

		--// Provides compatibility for converting a player's profile from the previous format to the new format
		--// The old profile must remain unmodified and retain its original format
		--// Set this to false if your experience has never used the old DataCacher module
		PreviousVersionSupport = true, -- [Important]

		--// Automatically saves each player’s profile after the set delay
		--// Applies to all Datastores created with CreateDatastore()
		AutoSave = true,

		--// In seconds, the delay between each auto save
		--// This should ideally be set to more than one minute
		AutoSaveInterval = 5 * 60,

		--// In seconds, the time to wait before assuming the profile's host server is unavailable and transferring ownership
		--// This is ignored if AutoSave is enabled. Instead, uses AutoSaveInterval, doubles the value, and adds a 30-second offset
		SessionDeadThreshold = 10 * 60,

	},

	--// All Datastore-related settings
	Datastore = {

		--// Used in the player's profile data and other systems to prevent overwriting when migrating from an existing Datastore
		--// Avoid changing this variable as it will duplicate the table with all DataCacher variables re-stored inside this table
		--// Only change this variable before you start using DataCacher in your experience
		--//
		--// For example, when attempting to Datastore:GetAsync() a player's key, it'll return like this:
		--// { __Data = { Your player data }, __Metadata = { Your session data } }
		--//
		--// See DataKey and SessionKey for more information
		InternalKey = "__", -- [Important]

		--// The key used to create and store a player’s profile data
		--// Ensure that this key is not used in the profile
		--// Only change this variable before you start using DataCacher in your experience
		--//
		--// Example: "__Data"
		--// See InternalKey for more information
		DataKey = "Data", -- [Important]

		--// The key used to create and store a player’s profile metadata
		--// Ensure that this key is not used in the profile
		--// Only change this variable before you start using DataCacher in your experience
		--//
		--// Example: "__Metadata"
		--// See InternalKey for more information
		SessionKey = "Metadata", -- [Important]

		--// The key used to reference a player's profile and other operations
		--// Username and UserId are already available for use
		--// This key is also used for MessagingService
		Key = function(Username: string?, UserId: number?): string -- [Important]

			--// This must return a string
			--// Use UserId instead of Username for GDPR compliance and unique identification

			return `Player_{UserId}`
		end,

		--// The suffix added to the topic for MessagingService if in Studio 
		KeySuffix = "__Studio",

		--// The default data that is assigned to a player
		--// The table must be either in dictionary or array format, but not both
		--// A dictionary format is strongly recommended
		TemplateData = {},

		--// Ensures the player's profile matches TemplateData by filling in missing values
		--// This will only work with dictionaries
		Reconcile = true,

		--// The system determines how values are stored in the player’s profile when migrating from an existing Datastore
		--// Migration conditions depend on both data (the data that is being imported) type and TemplateData type
		--//
		--// Condition #1: Is TemplateData an array?
		--// Condition #2: Is data an array?
		--//	   ? True: { [1] = "Hey!", [2] = "Hi!" }
		--//	  ? False: { [1] = { First = "Hey!", Second = "Hi!" } }
		--//
		--// Condition #1: Is TemplateData a dictionary?
		--// Condition #2: Is data a dictionary? (Reconcile is set to true)
		--//	   ? True: { Coins = { Lobby = 10, InGame = 5 } }
		--//	  ? False: { Coins = { Lobby = 0, InGame = 0 }, __OldData = { 10, 5 } }
		--//
		--// Used to ensure that array data is compatible with TemplateData (dictionary)
		--// This appends an additional key to the player's profile
		--// If the key already exists in the profile, the system will append characters (see DataCacher.lua) to the key
		IndexingName = "__OldData",

		--// Retries saving the profile if an error occurs, such as Datastore APIs failing
		--// Implements exponential backoff with equal jitter
		AutoRetry = true,

		--// Specifies the number of retry attempts to perform if an operation fails (excluding reclaim attempts)
		--// This is ignored when the server is shutting down and a save operation is in progress
		--// It is recommended to keep this value between 3 and 5
		RetryAttempts = 5,

		--// The kick message shown if the system cannot reclaim the profile
		ProfileLockText = "A session was already loaded. Please try again later.",

		--// For DeleteProfile(), the kick message shown once the player is kicked
		ProfileDeletionText = "Your data has been deleted. Joining the game again will create new data.",

	},
}