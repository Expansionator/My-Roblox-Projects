--!nocheck

--// DataCacher V2
--// @fattah412

--// Desc:
--// A Datastore extension module that behaves similarly to a normal Datastore.
--// This module is the successor to DataCacher V1.

--[[

-------------------------------

Notes:

• The module is designed for data integrity and ease of use, providing lease-based session locking and an atomic queue system that deterministically resolves multi-server conflicts.
  You only need basic knowledge of Datastores and Lua tables to operate it.

• It is recommended to use only a single instance of the DataCacher module.

• Never store Instances or functions in profiles.
  Profiles may only contain numbers, strings, booleans, or tables composed of these types.

• Asynchronous methods like LoadProfile and GetProfile can return nil.
  Always check the value before using it.

• Asynchronous methods may yield execution for an unspecified duration.

• Avoid calling SaveProfile every time a value changes.
  Modify the profile in memory by using GetProfile.
  Let Auto-save or leave-save handle persistence.

• Do not modify a profile’s metadata. Only modify the returned data.
  Modifying metadata can corrupt data or cause kicks.
  The metadata is intended for experienced developers only.

• Session lock kicks are normal.
  It does not mean the profile data was lost.
  It means another server owns the profile.

• Always call SaveProfile on PlayerRemoving.
  Auto-save is not a replacement for final saves.

• Do not change InternalKey mid-project.
  Changing it duplicates data.
  Treat it as immutable once live.

• The system mode determines the type of Datastore used.
  Use GetDatastoreMode to determine the current mode.
  LIVE uses production data.
  STUDIO uses a separate Datastore.
  SANDBOX does not interact with any actual Datastores.

• Deleting profiles is permanent.
  DeleteProfile saves the profile, removes the Datastore key, and then kicks the player.

• IndexingName is for migration only.
  You can ignore it unless changing data format.
  It stores incompatible old data safely.
  Use GetValueFromIndexingName to inspect or recover.

• Pcall is not needed for methods like LoadProfile and SaveProfile.
  They already include their own built-in error handling.

-------------------------------

Features:

[ Data Caching ]
• Player data (also known as "Profile") is temporarily stored in the server’s memory.
• This enables fast read and write operations without repeatedly accessing the Datastore.

[ Session Locking ]
• Acts as a safeguard against data loss or corruption in multi-server environments.
• Ensures that only a single server can modify a player’s profile at any given time, maintaining data integrity and consistency.

[ Mock Datastore ]
• Uses a separate Datastore instance when running in Studio.
• If API Services are enabled, the environment runs in STUDIO mode, using a distinct Datastore that doesn’t affect live data.
• Otherwise, the environment runs in SANDBOX mode, which simulates Datastore behavior without making real API calls.

[ Automatic Saving ]
• Implements a smart, rotation-based auto-saving system on RunService.Heartbeat. 
• This distributes the save load evenly across all active profiles, preventing large spikes in Datastore requests every time a save operation runs.

[ Profile State Tracking ]
• Tracks the profile's current state. 
• These include: "Locked", "Available", "Saving", "Loading", "Auto-Saving"

[ Queue Management ]
• For methods such as LoadProfile and SaveProfile, each request is added to a queue specific to that profile.
• This ensures operations are processed sequentially and prevents race conditions, especially during quick joins/leaves or multiple concurrent requests.

[ Data Reconciliation ]
• Compares the player’s data to a predefined template. If any keys from the template are missing, they are automatically added with their default values.

[ Version Migration ]
• Provides full support for migrating data from the V1 DataCacher module format to the new V2 format, allowing for seamless and backward-compatible transitions.

-------------------------------

Functions:

DataCacher.GetDatastoreMode(): DatastoreMode
• Returns the current mode being used by the system.
• Note: Yields

DataCacher.CreateDatastore(Name: string, Settings: Config.Datastore?): DatastoreObject
• Creates a new Datastore instance using the specified name and optional settings.
• Note: Yields

DataCacher.GetDatastore(Name: string, Timeout: number?, IgnoreSuffix: boolean?): DatastoreObject?
• Finds and retrieves a Datastore that was previously created by CreateDatastore().
• Note: Yields | Not guaranteed

-------------------------------

Methods:

DatastoreObject:GetDatastoreInstance(): DataStore?
• Returns the Datastore Instance when the system mode is set to either "LIVE" or "STUDIO".

DatastoreObject:LoadProfile(Player: Player): Profile?
• Initializes the player's profile and loads their data into memory on the server. This method handles session locking.
• Note: Yields | Not guaranteed

DatastoreObject:GetProfile(Player: Player, Raw: boolean?): Profile? | RawProfile?
• Retrieves the player's profile if it is currently loaded in memory. The optional Raw parameter returns the full profile, including the metadata.
• Note: Not guaranteed

DatastoreObject:SaveProfile(Player: Player, AutoSave: boolean?, ValueCallback: ValueCallback?): boolean?
• Saves the player's profile to the Datastore. It is used for final saves (when a player leaves) or for the rotation-based auto-save.
• Note: Yields | Not guaranteed

DatastoreObject:WipeProfile(Player: Player)
• Replaces the player's current profile data with the configured template data, effectively resetting their data.
• Note: Yields | Not guaranteed

DatastoreObject:DeleteProfile(Player: Player): boolean
• Saves the profile (to release the lock) and then calls RemoveAsync() to mark the profile for deletion from the Datastore.
• Note: Yields | Not guaranteed

DatastoreObject:GetProfileKey(Username: string?, UserId: number?): string
• Retrieves the unique key used for the player's profile based on the configured key function.

DatastoreObject:GetProfileState(ProfileKey: string): ProfileState?
• Retrieves the current state of a profile from the server's cache or by fetching it externally.
• Note: Yields | Not guaranteed

DatastoreObject:IsProfileLocked(ProfileKey: string): boolean?
• Returns true if the player's profile is currently being used.
• Note: Yields | Not guaranteed

DatastoreObject:OnProfileStateChanged(ProfileKey: string, StateCallback: StateCallback): Disconnect
• Listens for profile state changes on the server and runs a callback function when the state updates.

DatastoreObject:GetProfileAsync(ProfileKey: string): RawProfile?
• Returns a copy of the profile by fetching it externally (using GetAsync), or returns the in-memory copy if the server already owns the profile.
• Note: Yields | Not guaranteed

DatastoreObject:SaveProfileAsync(ProfileKey: string, Profile: RawProfile): boolean
• Saves a provided profile copy using SetAsync(), but will fail if the profile is currently locked by any server.
• Note: Yields | Not guaranteed

DatastoreObject:GetValueFromIndexingName(ProfileKey: string): ( any, { string }? )
• For cases where IndexingName has extra characters appended, this method returns the key's value and a table of similarly named keys.

-------------------------------

Example Usage:


local Players = game:GetService("Players")
local DataCacher = require(Path.To.DataCacher) -- The path to the DataCacher module

local myTemplateData = { -- The data assigned to a player, preferably as a dictionary

	Coins = 0,

}

-- Create a Datastore object with the specified name
local Datastore = DataCacher.CreateDatastore(`MyDatastore`, {

	TemplateData = myTemplateData, -- The Datastore uses the provided template as the main player data

	-- Additional settings can be added here

})

local function onPlayerAdded(player)
	local profile = Datastore:LoadProfile(player) -- No pcall needed; errors are handled internally

	if profile then -- Always check that the profile exists!

		-- Profile loaded successfully!
		print(`Data for {player.Name} is loaded.`)
	else

		-- The player is removed if their profile fails to load, since a loaded profile is required to play
		-- However, this is not necessary if your experience does not require the player's profile!
		player:Kick("Your data was not loaded. Please rejoin!")
	end
end

local function onPlayerRemoving(player)
	local success = Datastore:SaveProfile(player) -- No pcall needed; errors are handled internally

	if success then -- The profile must be loaded before it can be saved

		-- The profile was saved and cleaned up
		print(`Data for {player.Name} is saved.`)
	end
end

-- Hook player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Ensures that existing players also have their profiles loaded
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

while true do

	-- Give every player coins every 5 seconds

	for _, player in Players:GetPlayers() do
		local profile = Datastore:GetProfile(player) -- Fetch the player’s profile directly and instantly

		if profile then -- Always check that the profile exists!

			-- Add coins by updating the profile table directly
			-- No need to save after modifying! The auto-save mechanism will handle it

			profile.Coins += 5
			print(`{player.Name}'s coins has changed to {profile.Coins}.`)
		end
	end

	task.wait(5)
end

-- Note that the code written here can’t run because of the while loop


-------------------------------

--]]

--// Services

local MessagingService = game:GetService("MessagingService")
local DatastoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DataCacher, Config = {}, require(script.Settings)
DataCacher.__index = DataCacher

--// Internal Settings
--// Note: Certain numerical values are expressed in seconds

local ONLY_ALLOW_SINGLE_MODULE = true --// Allows only one DataCacher module to run in the experience

local MAX_DELAY_ON_SERVER_SHUTDOWN = 8 --// If AutoRetry is true, this value defines the delay between consecutive retry attempts

local DELAY_BETWEEN_PROFILE_RECLAIM_ATTEMPT = 7.5 --// The delay when a server tries to reclaim the profile’s session on each attempt

--// The maximum number of full reclaim cycles the system will make before giving up
--// Each cycle counts as two attempts, so three cycles equal six attempts (twice the UpdateAsync() calls)
local MAX_FULL_CYCLES_ALLOWED = 3

local MAX_PROFILE_RECLAIM_REQUESTS = 5 --// The maximum number of requests stored in ReclaimRequests before older ones are removed

--// This value is applied after doubling AutoSaveInterval, or after using SessionDeadThreshold when AutoSave is disabled
--// It acts as an offset, allowing multiple auto-saves and increasing the chance that LastUpdated is refreshed before assuming the profile's host server is unavailable
local SESSION_DEAD_THRESHOLD_OFFSET = 30

local SPACE_CHARACTER = "_" --// For IndexingName, the character that fills the gaps to guarantee key uniqueness, followed by LAST_CHARACTER_SUFFIX
local LAST_CHARACTER_SUFFIX = "DC" --// For IndexingName, the character appended to the key if there's a duplicate

local METADATA_TEMPLATE = { --// System variables associated with the player's profile

	--// The version of the profile of which when data is saved
	Version = 1, 

	--// The state, either "Locked" or "Available", which reflects on the profile's availability
	State = "Available",

	--// The time when the profile was created or last reformatted
	Created = nil,

	--// The time when the profile was last updated via UpdateAsync()
	LastUpdated = nil,

	Session = {

		--// The job ID of the server currently managing the profile
		JobId = nil,

		--// The place ID of the server currently managing the profile
		PlaceId = nil,

		--// The list of servers and associated information attempting to load the profile
		ReclaimRequests = {},

	},
}

--// Types

export type Profile = {}
export type RawProfile = { __Data: Profile, __Metadata: Metadata }
export type ProfileState = "Locked" | "Available" | "Saving" | "Loading" | "Auto-Saving"

export type ValueCallback = ( OldProfile: RawProfile, CurrentProfile: RawProfile ) -> RawProfile
export type StateCallback = ( State: ProfileState ) -> nil

export type Disconnect = { Disconnect: () -> nil }

export type DatastoreMode = "LIVE" | "STUDIO" | "SANDBOX"
export type DatastoreObject = typeof( setmetatable({} :: DatastoreObjectAttributes, {} :: { __index: DatastoreObjectMethods }) )
export type DatastoreObjectAttributes = { Settings: Config.Datastore, Datastore: DataStore }

export type DatastoreObjectMethods = {

	GetDatastoreInstance: ( self: DatastoreObject ) -> DataStore?,
	LoadProfile: ( self: DatastoreObject, Player: Player ) -> Profile?,
	GetProfile: ( self: DatastoreObject, Player: Player, Raw: boolean? ) -> Profile? | RawProfile?,
	SaveProfile: ( self: DatastoreObject, Player: Player, AutoSave: boolean?, ValueCallback: ValueCallback? ) -> boolean?,
	WipeProfile: ( self: DatastoreObject, Player: Player ) -> nil,
	DeleteProfile: ( self: DatastoreObject, Player: Player ) -> boolean,
	GetProfileKey: ( self: DatastoreObject, Username: string?, UserId: number? ) -> string,
	GetProfileState: ( self: DatastoreObject, ProfileKey: string ) -> ProfileState?,
	IsProfileLocked: ( self: DatastoreObject, ProfileKey: string ) -> boolean?,
	OnProfileStateChanged: ( self: DatastoreObject, ProfileKey: string, StateCallback: StateCallback ) -> Disconnect,
	GetProfileAsync: ( self: DatastoreObject, ProfileKey: string ) -> RawProfile?,
	SaveProfileAsync: ( self: DatastoreObject, ProfileKey: string, Profile: RawProfile ) -> boolean,
	GetValueFromIndexingName: ( self: DatastoreObject, ProfileKey: string ) -> ( any, { string }? ),

}

export type Metadata = {

	Created: number,
	Version: number,
	LastUpdated: number,

	State: "Locked" | "Available",

	Session: {

		JobId: string,
		PlaceId: number,

		ReclaimRequests: { string },

	}

}

assert(RunService:IsServer(), 'Module is unable to be required from the client.')

--// Global Variables

local GlobalSettings = Config.Globals

local DatastoreAccess = false

local DatastoreEnabled = true
local MockDatastoreEnabled = false

local ProfilePointer = 0
local LastUpdate

local ActiveProfileRequests = 0

local StudioToken
local IsServerClosing = false

local gTable = {

	Datastores = {},
	AutoUpdateList = {},

}

table.freeze(Config.Globals) --// Prevent any changes being made

local function WaitForDatastoreAccess()

	--// Ensures the system is fully ready before accessing datastores
	while not DatastoreAccess do
		task.wait()
	end
end

local function Clone(t)

	--// Enables thorough copying (deep copy)

	local newTable = {}

	for index, value in t do
		if typeof(value) == "table" then
			value = Clone(value)
		end
		newTable[index] = value
	end
	return newTable
end

local function GetTime()

	--// A replacement for os.time(), which is no longer recommended for upcoming developments
	return DateTime.now().UnixTimestamp
end

do

	--// Handles the creation of a mock Datastore system
	--// There are two types of mock Datastore systems:
	--//
	--// STUDIO:
	--// Used when API services are enabled
	--// Operates on a separate Datastore instance, distinct from the one used by public servers
	--//
	--// SANDBOX:
	--// Used when API services are unavailable
	--// Simulates real Datastore behavior locally
	--// Some features are unavailable in this mode

	if GlobalSettings.MockDatastore and RunService:IsStudio() then

		--// Creates a JobId for Studio sessions
		StudioToken = HttpService:GenerateGUID(false)

		task.defer(function()
			local success = pcall(function()
				DatastoreService:GetDataStore(GlobalSettings.BurnerDataStore):SetAsync(GlobalSettings.BurnerDataStore, GetTime())
			end)

			DatastoreEnabled = false
			MockDatastoreEnabled = if GlobalSettings.SandboxMode then false else success --// Decides which type of mock Datastore should be used

			DatastoreAccess = true

			warn(`GlobalSettings.MockDatastore is ENABLED. Current mode: { DataCacher.GetDatastoreMode() }`)
		end)
	else
		DatastoreAccess = true
	end
end

do

	--// Checks for other DataCacher modules
	--// Although DataCacher supports multiple modules, a single module is recommended

	if ONLY_ALLOW_SINGLE_MODULE then

		assert(not _G.__IsDataCacherLoaded, "_G.__IsDataCacherLoaded already has a reference to an identical module.")
		_G.__IsDataCacherLoaded = true
	end
end

local Wrapper = {}
do

	--// Wraps the primary function, allowing additional functions to run alongside it

	Wrapper.__index = Wrapper

	function Wrapper.Create(Callback: () -> nil)
		return setmetatable({

			Primary = Callback,

		}, Wrapper)
	end

	function Wrapper:Execute(Callbacks: {() -> nil}?, ...: any?)
		self.Primary(...)

		for _, callback in (Callbacks or {}) do
			callback(...)
		end
	end
end

local MockDatastore = {}
do

	--// Creates the SANDBOX mock Datastore system
	--// Does not handle the STUDIO system

	MockDatastore.__Datastores = {}
	MockDatastore.__index = MockDatastore

	function MockDatastore.New(Name: string)
		assert(not MockDatastore.__Datastores[Name], `There's already an existing mock Datastore called {Name}.`)

		local mock = setmetatable({ 

			Container = {},
			Queue = {},
			IsQueueRunning = {},

		}, MockDatastore)

		MockDatastore.__Datastores[Name] = mock
		return mock
	end

	function MockDatastore:Get(Key: string): (boolean, {}?)
		task.wait( math.random() ) --// Simulate API call delay

		local container = self.Container
		if not container[Key] then

			container[Key] = {

				Data = nil,
				Previous = nil,

			}
		end
		return true, container[Key].Data
	end

	function MockDatastore:Update(Key: string, Transform: (Data: {}) -> {}): {}?
		local gContainer = self.Container
		local gQueue = self.Queue

		local function Fn()
			local container = gContainer[Key]
			if not container then
				gContainer[Key] = { Data = nil, Previous = nil }
				container = gContainer[Key]
			end

			--// Updates the current data
			local currentData = container.Data and Clone(container.Data)
			local newData = Transform(currentData)

			if not newData then

				--// Transform function did not return anything
				return
			end

			container.Previous = currentData
			container.Data = newData

			task.wait( math.random() ) --// Simulate API call delay
		end

		if not gQueue[Key] then
			gQueue[Key] = {}
		end
		table.insert(gQueue[Key], Fn)

		local keyQueue = gQueue[Key]
		if #keyQueue == 1 then

			--// Handles the queue system

			local function RunNext()
				local nextFn = keyQueue[1]
				if nextFn then
					nextFn()
					table.remove(keyQueue, 1)

					if #keyQueue > 0 then
						RunNext() --// Proceed to the next queue
					else
						gQueue[Key] = nil --// Clears the queue automatically
					end
				end
			end
			RunNext()

		end
		return gContainer[Key].Data
	end

	function MockDatastore:Clear(Key: string)
		self.Container[Key] = nil
		self.Queue[Key] = nil
	end
end

local function Reconcile(t, refTable)

	--// Enables thorough reconciliation (deep)

	for index, value in refTable do
		if typeof(index) ~= "string" then continue end

		if t[index] == nil then
			t[index] = typeof(value) == "table" and Clone(value) or value
		end

		if typeof(t[index]) == "table" and typeof(value) == "table" then
			Reconcile(t[index], value)
		end
	end
end

local function IsTableArray(t)
	local n = 0

	for index in t do
		if typeof(index) ~= "number" or index < 1 or index % 1 ~= 0 then
			return false
		end
		n += 1
	end
	return n == #t
end

local function IsTableMixed(t)
	local hasArrayKeys = false
	local hasDictKeys = false

	local n = 0

	for index in t do
		if typeof(index) == "number" and index >= 1 and index % 1 == 0 then
			hasArrayKeys = true
			n += 1

			continue
		end
		hasDictKeys = true
	end

	if (hasArrayKeys and not hasDictKeys and n == #t) or (hasDictKeys and not hasArrayKeys) then
		return false
	end
	return true
end

local function Count(t)
	local index = 0

	for _, _ in t do
		index += 1
	end
	return index
end

local function IsV1Format(data)

	--// DataCacher V1 support

	local doesContainStructure = true
	local oldStructure = {

		--// V1 profile structure

		LastJoined = -1,
		LastLeft = -1,
		Version = -1,

		Session = {},
		data = {},

	}

	for index, value in oldStructure do
		if not data[index] or typeof(data[index]) ~= typeof(value) then

			doesContainStructure = false
			break
		end
	end

	--// The structure must be identical, with the same number of values
	if doesContainStructure and Count(oldStructure) == Count(data) then
		return true
	end
	return false
end

local function AddProfileToAutoList(profileKey, datastoreName)

	--// Checks if there's already an identical profile
	for _, profileInfo in gTable.AutoUpdateList do
		if profileInfo.ProfileKey == profileKey and profileInfo.DatastoreName == datastoreName then

			--// Found an identical profile
			return
		end
	end

	if #gTable.AutoUpdateList == 0 then

		--// Logs the current time for the first profile
		LastUpdate = os.clock()
	end

	table.insert(gTable.AutoUpdateList, {

		--// Essential for tracking newly created profiles
		LastCreated = os.clock(),

		ProfileKey = profileKey,
		DatastoreName = datastoreName,

	})

	--// Align the pointer to accommodate for the new profile
	ProfilePointer += 1
end

local function RemoveProfileFromAutoList(profileKey, datastoreName)

	--// Checks if there's already an identical profile
	for index, profileInfo in gTable.AutoUpdateList do
		if profileInfo.ProfileKey == profileKey and profileInfo.DatastoreName == datastoreName then

			--// Removes the profile from the list
			table.remove(gTable.AutoUpdateList, index)

			--// Align the pointer to adjust with the current profiles
			ProfilePointer -= 1

			if #gTable.AutoUpdateList == 0 then

				--// Reset the timer to allow a new profile to record its time again
				LastUpdate = nil
			else
				if ProfilePointer <= 0 then

					--// Resets the pointer to 1 if it’s misaligned while profiles exist
					ProfilePointer = 1
				end
			end
			break
		end
	end
end

local function GetMetadata()
	local metadata = Clone(METADATA_TEMPLATE)
	return metadata
end

local function GetJobId()
	return StudioToken or game.JobId
end

local function IsSessionReadyForUse(jobId, placeId, isOwnershipRequired)

	--// A critical function for session locking and validation

	if jobId == GetJobId() and placeId == game.PlaceId then

		--// Session is owned by this server
		return true
	end

	if not isOwnershipRequired and (not jobId and not placeId) then

		--// Session is empty and is ready to be locked
		return true
	end

	--// Session is owned by a different server
	return false
end

--[[
Returns the system’s current operating mode.

LIVE: Used when running on live Roblox servers.
STUDIO: Used when API services are enabled in Studio.
SANDBOX: Used when API services are unavailable.
]]
function DataCacher.GetDatastoreMode(): DatastoreMode
	WaitForDatastoreAccess()

	if DatastoreEnabled then

		--// The mode is currently running on a live Roblox server
		return "LIVE"
	end

	--// The mode is either currently using API services or operating fully offline
	return MockDatastoreEnabled and "STUDIO" or "SANDBOX"
end

--[[
Creates a Datastore using the specified name.
Includes methods and settings associated with the Datastore.
]]
function DataCacher.CreateDatastore(Name: string, Settings: Config.Datastore?)
	WaitForDatastoreAccess()

	if not DatastoreEnabled then

		--// Append the mock Datastore name suffix
		Name = Name..GlobalSettings.MockDatastoreSuffix
	end

	local newSettings = Clone(Settings or {})
	Reconcile(newSettings, Config.Datastore)

	table.freeze(newSettings) --// Prevent any changes being made

	assert(typeof(Name) == "string", `The Datastore name must be a string.`)
	assert(not gTable.Datastores[Name], `There's already an existing Datastore with the same name ({Name}).`)
	assert(not IsTableMixed(newSettings.TemplateData), `The TemplateData table for {Name} contains both arrays and dictionaries.`)

	local container = setmetatable({

		__Internal = {

			Name = Name,
			Settings = newSettings,

			--// The cached profiles stored in this table
			PlayerData = {},

			--// Metadata that is used for the server for each player
			--// Predefined in the server table for ease of accessibility

			PlayerUserIds = {},
			ProfileLoaded = {},
			SkipNewerSaveRequests = {},
			DeletionRequests = {},
			PendingLoadRequests = {},
			Subscriptions = {},

			States = {},
			StateCallbacks = {},

			Queue = {

				UpdateAsync = {},
				Requests = {},

			},

			Datastore = (DatastoreEnabled or MockDatastoreEnabled) and 
				DatastoreService:GetDataStore(Name) or MockDatastore.New(Name),

		}

	}, DataCacher)

	local self = container.__Internal
	do

		self.RequestProfileSave = function(...)

			--// A simpler reference to the SaveProfile method
			container:SaveProfile(...)
		end

		self.IsProfileLoaded = function(profileKey)

			--// Returns a boolean indicating whether the profile has been fully loaded by LoadProfile

			if table.find(self.ProfileLoaded, profileKey) then
				return true
			end
			return false
		end

		self.IsLatestRequest = function(profileKey, actionType)

			--// Returns a boolean indicating whether the request (Load, Save, or Auto-save) is the most recent

			local totalQueueByType = self.GetTotalQueue(profileKey, actionType)
			if totalQueueByType and totalQueueByType > 1 then
				return false
			end
			return true
		end

		self.GetStructureKeys = function()

			--// __Data, __Metadata and __Studio
			return `{newSettings.InternalKey}{newSettings.DataKey}`, `{newSettings.InternalKey}{newSettings.SessionKey}`, (not DatastoreEnabled and newSettings.KeySuffix or "")
		end

		self.ClearProfileSubscriptions = function(profileKey)

			--// For MessagingService, deletes all active subscriptions

			local activeSubscriptions = self.Subscriptions
			local profileSubscriptions = activeSubscriptions[profileKey]

			if not profileSubscriptions then
				return
			end

			for _, subscription in profileSubscriptions do
				subscription:Disconnect()
			end
			activeSubscriptions[profileKey] = nil
		end

		self.WaitInQueue = function(key, queueType, actionType)

			--// A critical system that organizes and executes requests in sequential order

			local queueTable = self.Queue
			local requestTable = queueTable.Requests

			local isFirst = false
			local queue = queueTable[queueType][key]

			if not queue then
				queueTable[queueType][key] = {}

				isFirst = true
				queue = queueTable[queueType][key]
			end

			local profileCounterTable
			if actionType then

				--// Handles LoadProfile and SaveProfile counters
				--// Uses a separate table instead of the queue for faster performance

				if not requestTable[key] then
					requestTable[key] = {}
				end
				profileCounterTable = requestTable[key]

				if not profileCounterTable[actionType] then

					--// ProfileKey = { ActionType = 0 }
					profileCounterTable[actionType] = 0
				end

				--// This action is now recognised in the queue
				profileCounterTable[actionType] += 1
			end

			if not isFirst then

				--// Stores the current coroutine into the queue and halt execution until it is resumed

				table.insert(queue, coroutine.running())
				coroutine.yield()
			end

			return function()
				local co = table.remove(queue, 1)
				if co then
					if actionType then

						--// The previous request has finished
						profileCounterTable[actionType] -= 1
					end

					coroutine.resume(co) --// Resume the next queue
					return
				end

				--// Clear the queue and counter tables if there's no more queue left

				queueTable[queueType][key] = nil
				requestTable[key] = nil
			end
		end

		self.GetTotalQueue = function(profileKey, actionType)

			--// The total number of requests associated with a profile

			local profileCounterTable = self.Queue.Requests[profileKey]
			local totalQueue = profileCounterTable and profileCounterTable[actionType]

			return totalQueue
		end

		self.SetPlayerState = function(profileKey, state)

			--// Sets the profile to the specified state and executes any callbacks associated with it

			local function FireStateCallbacks()
				local currentState = self.States[profileKey]
				local iterable = currentState and self.StateCallbacks[profileKey]

				--// Use an empty table if the table or state is missing
				for _, callback in (iterable or {}) do

					--// Fires each callback that was assigned to this profile
					task.spawn(callback, currentState)
				end
			end

			self.States[profileKey] = state
			FireStateCallbacks()

			--// At the time of when this function is called, if the state is the same, update the state
			return function()

				if self.States[profileKey] == state then

					self.States[profileKey] = self.IsProfileLoaded(profileKey) and "Locked" or nil
					FireStateCallbacks()
				end
			end
		end

		self.WaitForPlayerState = function(profileKey, iterate)

			--// Waits until the profile is ready for use

			local currentState = self.States[profileKey]
			if not currentState or currentState == "Locked" then

				--// The profile is ready for use
				return true
			end

			if not iterate then

				--// Keep waiting until the profile is available

				repeat task.wait()
				until self.WaitForPlayerState(profileKey, true)
			end
		end

		self.Request = function(profileKey, params)

			--// The core handler that ensures all profile asynchronous requests are processed correctly

			local dataKey, sessionKey = self.GetStructureKeys()
			local datastore = self.Datastore

			local profile = self.PlayerData[profileKey]
			local templateData = Clone(newSettings.TemplateData)

			local hasIgnoredAndSavedRequest = false
			local hasIgnoredRequest = false
			local ignoreSessionRequest = false
			local isLatestRequest = true

			local success, newData

			local totalAttempts = newSettings.AutoRetry and newSettings.RetryAttempts or 1
			local expBackoff, attempt = 1, 0

			while attempt < totalAttempts or IsServerClosing do

				--// Iterates once or the specified number of retry attempts
				--// Continues iterating indefinitely if the server is closing to maximize the chance of the request being successful

				attempt += 1

				if not isLatestRequest then

					--// While waiting for the next attempt, a duplicate request was added to the queue

					hasIgnoredRequest = true 
					break
				end

				if IsServerClosing and params.Action ~= "Saving" then

					--// Reject this request if this function is attempting to load or auto-save the profile during a server shutdown

					hasIgnoredRequest = true 
					break
				end

				if params.Action ~= "Loading" and not (profile and self.IsProfileLoaded(profileKey)) then

					--// An attempt to save or auto-save but the profile is not loaded

					hasIgnoredRequest = true
					break
				end

				if params.RestoreSession then

					--// The server should no longer access the profile and must immediately remove the player

					ignoreSessionRequest = true
					hasIgnoredRequest = true

					break
				end

				--// Request (Atomic)
				success, newData = pcall(function()

					local function Transform(data)
						local metadataTemplate = GetMetadata()
						local hasValueInData = true

						if typeof(data) ~= "table" then

							--// Creates a new table if the data is missing
							--// Converts the current value to a table and stores the original value inside

							data = data and { data } or templateData
							hasValueInData = data ~= nil
						end

						local dataValue, sessionValue = data[dataKey], data[sessionKey]
						local areBothValuesTable = typeof(dataValue) == "table" and typeof(sessionValue) == "table"

						--// This is somewhat problematic, as developers may structure their tables in a variety of ways
						--// Conditions are best effort and not guaranteed to be fully reliable. Ensure that InternalKey, DataKey, and SessionKey are unique
						--// Checks that the data and metadata exist, that both are tables, and that the metadata is a dictionary
						if not (dataValue and sessionValue) or not areBothValuesTable or IsTableArray(sessionValue) then

							--// Handles DataCacher v1.0.0 importation
							--// Imports older data for migration to the new format
							--// Ensures that the profile is consistent with the new format


							--// DataCacher v1.0 migration
							if GlobalSettings.PreviousVersionSupport and IsV1Format(data) then

								data = data.data
								hasValueInData = true
							end

							local oldData = Clone(data)

							local isTemplateArray = IsTableArray(templateData)
							local isDataArray = IsTableArray(oldData)

							--// Array handling
							if hasValueInData and isTemplateArray and not isDataArray then

								oldData = { oldData }
							end

							--// Dictionary handling
							if hasValueInData and not isTemplateArray then

								local indexName = newSettings.IndexingName
								local charactersToAdd = ""

								local function GenerateChars()
									local defaultLength = indexName:len()
									local suffixLength = LAST_CHARACTER_SUFFIX:len()

									local maxLength = defaultLength

									for index in templateData do
										if typeof(index) ~= "string" then continue end

										local len = index:len()
										if index:match(indexName) and len > maxLength then

											--// The index includes the prefix and is longer than the previously longest index
											maxLength = len
										end
									end

									local spaceLeft = maxLength - (defaultLength + suffixLength) --// The number of gaps left to fill
									local totalGaps = spaceLeft + 1 --// Adds an extra space character to ensure the index is unique

									local newSuffix = `{(SPACE_CHARACTER):rep(totalGaps)}{LAST_CHARACTER_SUFFIX}`
									return newSuffix
								end

								if templateData[indexName] then

									--// Find a new index that is not in the table
									charactersToAdd = GenerateChars()
								end

								if isDataArray then

									--// Wrap the table into a dictionary format if it is an array
									oldData = { [indexName..charactersToAdd] = oldData }
								end
							end

							data = {

								[dataKey] = oldData,
								[sessionKey] = metadataTemplate,

							}
						end

						if newSettings.Reconcile then

							--// May be slightly computationally expensive
							Reconcile(data[dataKey], templateData)
						end
						Reconcile(data[sessionKey], metadataTemplate)

						do

							local metadata = data[sessionKey]
							local session = metadata.Session

							local currentMetadata = profile and profile[sessionKey]

							do

								--// Manages conditions associated with session locking

								local sessionReady = IsSessionReadyForUse(session.JobId, session.PlaceId, params.Action ~= "Loading")
								local isReclaimsInList = params.Action == "Loading" and #session.ReclaimRequests > 0

								if not sessionReady or isReclaimsInList then

									--// The session must be empty to load the profile
									--// The session must be owned by this server to save or auto-save the profile
									--// The session must not have other servers attempting to load the profile

									if params.ManageSession then

										--// An attempt was made to load the profile, but it was met with a session conflict

										local hasConflictBeenHandled = params.ManageSession(data)
										if not hasConflictBeenHandled then

											--// The session could not be transferred to this server
											--// Save the session while continuing to retry reclaiming the profile

											hasIgnoredAndSavedRequest = true
											return data
										end
									else

										--// An attempt was made to save or auto-save the profile but the session is not owned by this server
										--// This can happen if API services are unavailable, inadvertently allowing other servers to reclaim the profile while the original server is still running

										local hasSessionReverted = params.RevertSession and params.RevertSession(data)
										if not hasSessionReverted then

											--// There's no fail-safe function for this edge case, so we fall back to removing the player

											ignoreSessionRequest = true
											hasIgnoredRequest = true

											return
										end
									end
								end
							end

							if profile and currentMetadata.Version ~= metadata.Version then

								--// Both versions are not identical

								hasIgnoredRequest = true
								return
							end

							if params.RejectSave then

								--// Refresh LastUpdated without saving data

								metadata.LastUpdated = GetTime()
								return data
							end
						end

						if params.Transform then

							local metadata = data[sessionKey]
							if not metadata.Created then

								--// Logs the Unix timestamp at the time the profile is created
								metadata.Created = GetTime()
							end

							--// Finally, update the profile once all checks have passed or the session has been successfully reclaimed
							params.Transform(data)
						end
						return data
					end

					if DatastoreEnabled or MockDatastoreEnabled then
						return datastore:UpdateAsync(profileKey, Transform)
					end
					return datastore:Update(profileKey, Transform)
				end)

				local isRequestSuccessful = success and newData
				if isRequestSuccessful then

					--// The request was successful, so we can exit the loop safely
					break
				end

				if hasIgnoredRequest then

					--// The request specifies that no value should be returned
					break
				end

				--// Profile couldn't be updated, retry until an attempt succeeds or the max attempt limit is reached

				local jitter = expBackoff / 2
				local expDelay = Random.new():NextNumber(jitter, expBackoff)

				local offset = math.min(IsServerClosing and MAX_DELAY_ON_SERVER_SHUTDOWN or math.huge, expDelay)

				local startTime = os.clock()
				local endTime = startTime + offset

				while os.clock() < endTime do

					--// A replacement for task.wait, with logic implemented

					if not self.IsLatestRequest(profileKey, params.Action) then

						--// This request isn't the most latest request

						isLatestRequest = false
						break
					end

					if IsServerClosing and offset > MAX_DELAY_ON_SERVER_SHUTDOWN then

						--// Server is shutting down while waiting for end time to complete (e.g., 32 seconds)
						--// Adjusts the end time to cap at 8 seconds, continuing from the current time until the limit is reached
						--// Reset the offset to prevent this if-statement from running again

						endTime = startTime + MAX_DELAY_ON_SERVER_SHUTDOWN
						offset = MAX_DELAY_ON_SERVER_SHUTDOWN
					end

					task.wait()
				end

				--// Exponentially increases the delay per attempt
				expBackoff *= 2
			end

			if hasIgnoredRequest then

				--// The system was forced not to save
				return nil, ignoreSessionRequest
			end
			return success and newData, success and hasIgnoredAndSavedRequest
		end
	end

	gTable.Datastores[Name] = container
	return container
end

--[[
Finds and retrieves a Datastore that was created by CreateDatastore().
Settings are read-only and can't be modified.
]]
function DataCacher.GetDatastore(Name: string, Timeout: number?, IgnoreSuffix: boolean?): DatastoreObject?
	WaitForDatastoreAccess()

	if not IgnoreSuffix and not DatastoreEnabled then

		--// Append the mock Datastore name suffix
		Name = Name..GlobalSettings.MockDatastoreSuffix
	end

	if not gTable.Datastores[Name] then
		local elapsedTime = os.clock()
		Timeout = Timeout or math.huge

		repeat task.wait() --// Waits until there's a matching Datastore, the time running out or when the server is closing
		until gTable.Datastores[Name] or (os.clock() - elapsedTime) >= Timeout or IsServerClosing
	end

	--// This could return a Datastore that might not exist
	return gTable.Datastores[Name]
end

--[[
Returns the Datastore Instance.
The system mode must be either "LIVE" or "STUDIO".
]]
function DataCacher:GetDatastoreInstance(): DataStore?
	local self = self.__Internal
	return (DatastoreEnabled or MockDatastoreEnabled) and self.Datastore or nil
end

--[[
Initializes the player's profile and stores their data in memory.
This method fails if the profile is already loaded or in a saving state.
]]
function DataCacher:LoadProfile(Player: Player): Profile?
	local self = self.__Internal
	local Settings = self.Settings

	local profileKey = Settings.Key(Player.Name, Player.UserId)
	local dataKey, sessionKey, topicKey = self.GetStructureKeys()

	local ignoreSessionRequest = false
	local jobId = GetJobId()

	local actionType = "Loading"

	ActiveProfileRequests += 1

	local nextQueue = self.WaitInQueue(profileKey, "UpdateAsync", actionType) --// Helps with rejoining too quickly	
	local wrapper = Wrapper.Create(function(isReadyToDisconnect)

		--// Decrements total requests and runs the next queue

		if isReadyToDisconnect then

			--// The subscription for the profile is created before calling Request()
			--// If the process cannot complete, the subscription must be unsubscribed to prevent memory leaks
			--// For example, the server explicitly requests profile removal or the profile cannot be loaded

			self.ClearProfileSubscriptions(profileKey)
		end

		if ignoreSessionRequest then

			--// The server has requested the player’s removal due to session locking
			Player:Kick(Settings.ProfileLockText)
		end

		ActiveProfileRequests -= 1
		nextQueue()
	end)

	do
		self.WaitForPlayerState(profileKey)

		if not self.IsLatestRequest(profileKey, actionType) then

			--// This request isn't the most latest request
			return wrapper:Execute()
		end

		if IsServerClosing or self.IsProfileLoaded(profileKey) then

			--// Ignores this request if there's already a profile or during server shutdown
			return wrapper:Execute()
		end

		if table.find(self.DeletionRequests, profileKey) then

			--// There's an attempt to delete the profile, reject this request
			return wrapper:Execute()
		end
	end

	local makeProfileReady = self.SetPlayerState(profileKey, "Loading")
	local profile, isAttemptingToReclaim
	do

		--// Handles profile loading and session locking

		--[[

			Session Locking Mechanism

			What it is:
			• Session locking is a technique used to prevent multiple requests from modifying the same user session at the same time
			• When a request starts using a session, it “locks” that session so other requests must wait until the lock is released, ensuring data consistency and avoiding race conditions

			--------------------------------------------------------------------

			Here's an overview of DataCacher’s session locking mechanism design:

			[ Overview ]

			• The system prioritizes data integrity, with minor drawbacks such as sacrificing some User Experience (UX)
			• This trade-off may result in the player waiting longer or being kicked if accessing the profile is deemed unsafe

			• It adheres to the CAP theorem, prioritizing Consistency (C) and Partition Tolerance (P), while Availability (A) may be temporarily impacted during contention or API outages
			• It primarily follows FIFO principles, while incorporating certain LIFO characteristics

			• A queue is used to track servers attempting to load the same profile

			• There is a lock that the latest server owning the profile is expected to refresh
			• It is essentially a lease-based lock, where a server does not own the profile indefinitely but retains it as long as it can provide a heartbeat to update the lock

			• The system follows the principle of allowing the latest server that owns the profile to retain ownership
			• Other servers attempting to load the same profile do not forcefully release the current lock, but wait until it is safe to reclaim the profile
			• MessagingService is used only in special circumstances where a forceful release of the lock is necessary

			• The player's saved profile in the Datastore serves as the source of truth for the session locking mechanism

			--------------------------------------------------------------------

			[ Loading Profiles ]

			• When a player joins a server, the system verifies that their profile is not already in use
			• If available, meaning it is not locked by another server or the lock has expired, the server will claim and lock the profile
			• Otherwise, it triggers the session locking mechanism

			--------------------------------------------------------------------

			[ Initialization ]

			• The system creates a MessagingService subscription to quickly resolve specific cases
			• Each iteration of the system’s while loop is called an "attempt", during which the server tries to claim or reclaim the profile
			• The loop continues as long as these conditions are met:
				• The request (LoadProfile) must be the most recent
				• The server must still be active
				• The request is still permitted to run
				• It is still within the range of allowed attempts
				• The profile has not been claimed by this server yet

			--------------------------------------------------------------------

			[ Locking Profiles ]

			• When the server can access the profile after the conditions are met, the following operations take place:
				• The profile's metadata is used
				• The "JobId" and "PlaceId" are set for this server
				• The lock is automatically set once the profile is loaded
				• A periodic auto-saving system automatically saves to keep the lock active
				• Clears the table containing servers that attempted to load the same profile

			• The "lock" is stored in the profile’s metadata as a Unix timestamp
			• It represents the last time a server successfully accessed and modified (e.g., saved) the profile
			• Its primary purpose is to indicate that the server currently holding the profile is still active
			• Other servers use this timestamp to determine whether the profile is safe to reclaim

			--------------------------------------------------------------------

			[ Reclaim Cycles ]

			• Every attempt made contributes to completing a cycle
			• With every attempt, an UpdateAsync() call is made
			• A cycle consists of two attempts being made (3 cycles = 6 attempts)
				• This ensures fairness, giving the latest server in the queue a chance to reclaim the profile before being removed to allow other servers the same opportunity

			• If the cycle is disrupted, or after completing all cycles the profile still cannot be reclaimed, the server will kick the player
				• This prevents situations where a server has a reference to the player, but their profile has not been loaded
				• This also ensures that if a profile cannot be fully accessed, the player is kicked rather than assuming the profile is usable

			• For every attempt:
				• Checks whether the server can reclaim the profile
				• The cycle stops completely if the server's JobId cannot be found in the queue
					• This occurs if other servers have forcefully removed the server from the queue

				• If reclaiming the profile is not possible, the cycle continues until the total number of cycles is reached or the profile is successfully reclaimed

			• For every first attempt in a cycle (odd-numbered):
				• Keeps a record (JobId) of the latest server in the queue
				• This "snapshot" is used to check whether the removal operation can be safely performed during the next attempt

			• For every second attempt in a cycle (even-numbered):
				• Prevents the server from getting stuck behind the latest server in the queue, regardless of whether that server is active or inactive (“ghost”) due to a crash
				• The server compares the current latest server in the queue with the previous latest server it recorded during the first attempt
					• If the latest server matches the recorded server, remove it from the queue
					• Otherwise, do not remove anything and proceed to the next cycle

				• This allows the queue to rotate, eventually moving the server to the end so it can have a chance to reclaim the profile

			--------------------------------------------------------------------

			[ Queue ]

			• A table ("queue") stored in the profile's metadata tracks the servers attempting to load the same profile
			• The purpose of the queue is to allow all servers a chance to reclaim the profile, while giving the most recently added server exclusive priority to do so
			• Since new servers can be added to the queue, and with the atomic behavior of UpdateAsync(), this prevents overwriting and ensures the order of servers remains sequential and deterministic
			• For optimization, only a limited number of servers are allowed in the queue, while older servers are removed
				• This helps reduce the total number of UpdateAsync() calls while still allowing a sufficient number of servers in the queue

			• The queue is regarded as the most recent and authoritative source of truth by all servers
			• Every server in the queue sees the latest state of the queue, thanks to the atomic behavior of UpdateAsync()
			• A server must be in the queue if it has added itself. If it is not found, the player is kicked because the server was forcefully removed by others

			• The latest server in the queue can attempt to reclaim the profile during a cycle before being removed by other servers, if any exist
				• It does not remove itself or others, instead relying on the other servers to remove it
				• If no other servers are competing, it keeps retrying until the profile is reclaimed or the maximum cycles are reached

			• Other servers in the queue will eventually handle the latest server, while ensuring that only one server is allowed to perform the removal
				• This gradually reduces the queue size while giving other servers a chance to reclaim the profile

			• There are some special characteristics by using a queue:
				• It is behavior-based, meaning it resolves conflicts deterministically by coordinating servers in a structured waiting system
				• For the latest server in the queue:
					• If it crashes or becomes unresponsive, the remaining servers automatically manage it. When no servers remain, any new server joining the queue will try to reclaim the profile
					• Since a dead server cannot interfere with the latest entrant (server), the new server can continue retrying without disrupting the overall process
					• Otherwise, it relies on other servers to remove it while simultaneously attempting to reclaim the profile

				• For other servers in the queue:
					• Only a single server is allowed to remove the latest server from the queue
					• This is enforced by allowing removal of the latest server only after each cycle, and only if the previously recorded latest server matches the currently captured latest server
					• Helps prevent timing conflicts, as every server must confirm it is still observing the same latest server
					• Using servers A (oldest), B, and C (latest) as examples in the queue:
						• If server C is dead, server A or B will take over handling server C
						• If server B is dead, server A will take over handling server B
						• If servers A and B are dead, server C will continue retrying, as it is expecting for server A or B to remove it
						• If all servers are dead, the queue remains stale until a new server enters the queue

			--------------------------------------------------------------------

			[ MessagingService ]

			• During normal operations, when API services are active and Datastores are accessible, UpdateAsync() serves as the primary mechanism for session locking
			• In rare cases, if a profile is owned by a server but the API services go down, the server cannot update the lock, causing other servers to mistakenly assume it is dead
			• Once API services are restored, a server that was attempting to reclaim the profile may mistakenly succeed, even though the original server is still active
			• Now two servers have access to the same profile, creating a critical risk of data corruption or loss
				• However, other servers attempting to reclaim the profile during or after the API outage will add themselves to the queue
				• This guarantees that only two servers can simultaneously own the same profile

			• MessagingService is used to notify the server that mistakenly reclaimed the profile to kick its player and avoid modifying the profile
			• Meanwhile, the original server quickly restores the mistaken metadata with its current cached version

			--------------------------------------------------------------------

		--]]

		local pendingListTable = self.PendingLoadRequests
		local isLatestRequest = true

		if not table.find(pendingListTable, profileKey) then
			table.insert(pendingListTable, profileKey)
		end

		local function HandleProfileSubscription()

			--// task.spawn runs this function asynchronously so it doesn’t block the current thread

			if not DatastoreEnabled and not MockDatastoreEnabled then

				--// Currently in SANDBOX mode, blocking subscription creation
				return
			end

			local activeSubscriptions = self.Subscriptions
			local profileSubscriptions

			if not activeSubscriptions[profileKey] then

				--// Uses a table to track multiple subscriptions and handle duplicates caused by SubscribeAsync’s unpredictable behavior
				activeSubscriptions[profileKey] = {}
			end
			profileSubscriptions = activeSubscriptions[profileKey]

			if #profileSubscriptions > 0 then

				--// We should avoid creating a new subscription when an active one is already running
				return
			end

			table.insert(profileSubscriptions, MessagingService:SubscribeAsync(profileKey..topicKey, function(message)

				--// This is the other session, currently attempting to remove the player from this server so the original server retains profile ownership
				--// Used only in very specific fallback scenarios, since API services are usually active

				local session = message and message.Data and message.Data.Session
				if session and not IsSessionReadyForUse(session.JobId, session.PlaceId, true) then

					--// Ensures the original server does not handle messages it originally published
					--// Reject saving the profile and immediately remove the player to prevent any remaining references

					self.RequestProfileSave({Key = profileKey, RestoreSession = true})
				end
			end))

			if #profileSubscriptions > 1 then

				--// Because SubscribeAsync yields, another subscription may be created before it finishes, causing duplicate subscriptions
				--// Previously, the change wasn’t noticeable due to timing conflicts, so a table is used to track and handle duplicate subscriptions to prevent memory leaks
				--// Remove duplicate subscriptions, keeping only the original

				for index = #profileSubscriptions, 2, -1 do

					--// Loop backwards when removing subscriptions to prevent skipping any due to index shifts
					--// Disconnect the subscription and remove it from the list

					profileSubscriptions[index]:Disconnect()
					table.remove(profileSubscriptions, index)
				end
			end
		end
		task.spawn(HandleProfileSubscription)

		local maxProfileReclaimAttempts = MAX_FULL_CYCLES_ALLOWED * 2
		local totalAttempts, isServerInQueue = 0, false
		local lastJobId, lastSessionJobId

		while isLatestRequest and not IsServerClosing and table.find(pendingListTable, profileKey) and totalAttempts < maxProfileReclaimAttempts do

			--// Ensure that this is the most recent request, the server is active, this request is still permitted to run, and retry attempts remain within the allowed limit

			profile, isAttemptingToReclaim = self.Request(profileKey, {

				Action = actionType,

				ManageSession = function(latestData)

					--// Attempt to reclaim the profile

					local metadata = latestData[sessionKey]
					local session = metadata.Session

					local reclaimRequests = session.ReclaimRequests

					local function IsServerTheLatest(serverJobId)
						local totalServersInQueue = #reclaimRequests
						local latestJobId = reclaimRequests[totalServersInQueue]

						if serverJobId == latestJobId or totalServersInQueue == 1 then

							--// The latest server in the queue either matches the provided JobId or is the last in the queue
							return true
						end

						--// The server isn’t the newest in the queue
						return false
					end

					if not table.find(reclaimRequests, jobId) then

						--// The server is missing from the queue

						if isServerInQueue then

							--// Another server has forcibly removed this server from the queue
							--// Reduces UpdateAsync calls to avoid overwhelming the Datastore

							ignoreSessionRequest = true
							return false
						else

							--// The server has just started requesting to reclaim the profile

							isServerInQueue = true
							table.insert(reclaimRequests, jobId)
						end
					end

					local totalServersInQueue = #reclaimRequests
					if totalServersInQueue > MAX_PROFILE_RECLAIM_REQUESTS then

						--// More servers are attempting to reclaim the profile than the allowed limit
						--// Shift the excess queue from the right side to the left side to remove outdated servers

						local totalOutdatedServers = totalServersInQueue - MAX_PROFILE_RECLAIM_REQUESTS
						for _ = 1, totalOutdatedServers do
							table.remove(reclaimRequests, 1)
						end
						totalServersInQueue = #reclaimRequests
					end

					local lastUpdated = metadata.LastUpdated
					local currentJobId = session.JobId

					local expiryTime = (GlobalSettings.AutoSave and (GlobalSettings.AutoSaveInterval * 2) or GlobalSettings.SessionDeadThreshold) + SESSION_DEAD_THRESHOLD_OFFSET
					local lockExpiryDiff = lastUpdated and GetTime() - lastUpdated

					if IsServerTheLatest(jobId) and (IsSessionReadyForUse(currentJobId, session.PlaceId) or (lockExpiryDiff and lockExpiryDiff >= expiryTime)) then

						--// The server is the latest one, and the session is either unlocked or its lock has expired
						return true
					else
						if not lastSessionJobId then

							--// Stores the JobId of the server that currently owns the profile to determine if ownership has changed
							lastSessionJobId = currentJobId
						end
					end

					if (lastSessionJobId and currentJobId) and lastSessionJobId ~= currentJobId then

						--// After a server reclaims the profile, the queue should be cleared
						--// In rare cases, if this server misses the change, it will stop and remove the player

						ignoreSessionRequest = true
						return false
					end

					if totalServersInQueue > 1 then

						--// There's a race between servers trying to reclaim the profile
						--// Each server removes the current latest server in the queue. If other servers are inactive, the server continues attempting to reclaim the profile
						--// Removing the current latest server after some time allows other servers to reclaim the profile and helps reduce the queue


						--// After self.Request succeeds, totalAttempts is incremented by one
						--// Adding +1 makes the first attempt part of the first cycle (changing 0 % 2 == 0 to 1 % 2 == 1)
						local hasCompletedFullCycle = (totalAttempts + 1) % 2 == 0
						local latestJobId = reclaimRequests[totalServersInQueue]

						if hasCompletedFullCycle then

							--// Each cycle completes after two attempts (including this attempt)
							--// Verifies whether each server in the queue is still active

							if lastJobId == latestJobId and not IsServerTheLatest(jobId) then

								--// Ensure that only the same server captured in the previous attempt is removed (for cases where the server is removed by another server)
								--// Do not remove this server if it’s the latest and let other servers handle it

								table.remove(reclaimRequests, totalServersInQueue) --// Allow other servers to attempt reclaiming the profile
							end
						else

							--// Sets lastJobId to the most latest server in the queue for the next attempt, ensuring sufficient time before removing the server from the queue
							--// This gives the latest server a chance to reclaim the profile twice before being removed by other servers

							lastJobId = latestJobId
						end
					end

					--// Session has not been reclaimed by this server
					return false
				end,

				Transform = function(latestData)
					local metadata = latestData[sessionKey]
					local session = metadata.Session

					--// Updates the metadata

					metadata.LastUpdated = GetTime()
					metadata.State = "Locked"

					session.JobId = jobId
					session.PlaceId = game.PlaceId

					--// To start fresh without any servers wanting to reclaim the profile
					table.clear(session.ReclaimRequests)
				end

			})

			if profile then

				--// The loop will continue if the profile couldn't be fetched

				totalAttempts += 1

				if not isAttemptingToReclaim then

					--// The profile was successfully fetched and claimed by this server
					--// Creates the subscription if it was not created previously

					task.spawn(HandleProfileSubscription)
					break
				end
			end

			--// Ensures the profile only returns if it is fetched successfully
			profile = nil

			if ignoreSessionRequest then

				--// The server cannot safely continue managing the profile because the session can no longer be reclaimed
				break
			end

			--// Ensures that the subscription is created (if it was not created previously) only while the loop is active, minimizing unnecessary cleanup
			task.spawn(HandleProfileSubscription)

			local endTime = os.clock() + DELAY_BETWEEN_PROFILE_RECLAIM_ATTEMPT
			while os.clock() < endTime do

				--// A replacement for task.wait, with logic implemented

				if IsServerClosing or not table.find(pendingListTable, profileKey) then

					--// The server is shutting down or the player has left the server (save method called)
					break
				end

				if not self.IsLatestRequest(profileKey, actionType) then

					--// A new request attempted to load the same profile while it was being reclaimed. Prioritize the latest request instead

					isLatestRequest = false
					break
				end

				task.wait()
			end
		end

		if totalAttempts >= maxProfileReclaimAttempts and not profile then

			--// Remove the player if the profile cannot be fetched after all retries to avoid leaving stale references on the server
			ignoreSessionRequest = true
		end

		local pendingListIndex = table.find(pendingListTable, profileKey)
		if pendingListIndex then

			table.remove(pendingListTable, pendingListIndex)
		end
	end

	if not profile then

		--// Removes the player state when profile cannot be fetched
		return wrapper:Execute({makeProfileReady}, true)
	end

	--// Create references to the player

	self.PlayerData[profileKey] = profile
	self.PlayerUserIds[profileKey] = Player.UserId

	table.insert(self.ProfileLoaded, profileKey)

	AddProfileToAutoList(profileKey, self.Name)

	wrapper:Execute({makeProfileReady})
	return profile[dataKey] --// Profile is ready!
end

--[[
Retrieves the player's profile if it is loaded.
If Raw is true, this method returns the raw profile format, including __Data and __Metadata.
]]
function DataCacher:GetProfile(Player: Player, Raw: boolean?): Profile? | RawProfile?
	local self = self.__Internal

	local profileKey = self.Settings.Key(Player.Name, Player.UserId)
	local dataKey = self.GetStructureKeys()

	do
		self.WaitForPlayerState(profileKey)

		if IsServerClosing or not self.IsProfileLoaded(profileKey) then

			--// The server is shutting down or there's no profile
			return
		end
	end

	local profile = self.PlayerData[profileKey]

	--// Returns the profile with either only the actual data or both actual data and metadata
	return Raw and profile or profile[dataKey]
end

--[[
Saves the player's profile to the Datastore.

Set AutoSave to true to save data during the session.
ValueCallback is an optional callback function that returns a modified profile.
]]
function DataCacher:SaveProfile(Player: Player, AutoSave: boolean?, ValueCallback: ValueCallback?): boolean?
	local self = self.__Internal
	local Settings = self.Settings

	--// Supports provided metadata because of BindToClose, Heartbeat, and other internal operations
	--// For internal use only. Not intended for use by other scripts
	local profileSaveMetaData = typeof(Player) == "table" and Player

	local profileKey = profileSaveMetaData and profileSaveMetaData.Key or Settings.Key(Player.Name, Player.UserId)
	local dataKey, sessionKey, topicKey = self.GetStructureKeys()

	local isRestoringSession = profileSaveMetaData and profileSaveMetaData.RestoreSession

	local actionType = AutoSave and "Auto-Saving" or "Saving"

	ActiveProfileRequests += 1

	local pendingRequestIndex = table.find(self.PendingLoadRequests, profileKey)
	if pendingRequestIndex and not AutoSave then

		--// The profile currently has an active load/reclaim request. Stop the request and allow the save operation to begin
		table.remove(self.PendingLoadRequests, pendingRequestIndex)
	end

	local nextQueue = self.WaitInQueue(profileKey, "UpdateAsync", actionType)
	local wrapper = Wrapper.Create(function()

		--// Decrements total requests and runs the next queue

		local skipSaveRequestIndex = table.find(self.SkipNewerSaveRequests, profileKey)
		if skipSaveRequestIndex then

			table.remove(self.SkipNewerSaveRequests, skipSaveRequestIndex)
		end

		ActiveProfileRequests -= 1
		nextQueue()
	end)

	do
		self.WaitForPlayerState(profileKey)

		if not self.IsLatestRequest(profileKey, actionType) then

			--// This request isn't the most latest request
			return wrapper:Execute()
		end

		if (IsServerClosing and AutoSave) or not self.IsProfileLoaded(profileKey) then

			--// Ignores the request if there's no profile or the request is an auto-save during server shutdown
			return wrapper:Execute()
		end

		if table.find(self.DeletionRequests, profileKey) and AutoSave then

			--// Allow save requests only if the profile is being deleted
			return wrapper:Execute()
		end

		if table.find(self.SkipNewerSaveRequests, profileKey) then

			--// Prevents the request from proceeding when an existing request takes priority over incoming requests
			return wrapper:Execute()
		end
	end

	local releaseProfile = self.SetPlayerState(profileKey, AutoSave and "Auto-Saving" or "Saving")

	if isRestoringSession and not AutoSave then

		--// In rare cases, when the server requests the removal of a player due to session locking,
		--// newer incoming requests may overwrite this high-priority request if API services are unavailable
		--// To prevent disruption of the profile release process (clearing references without saving), incoming requests should be rejected

		table.insert(self.SkipNewerSaveRequests, profileKey)
	end

	local profile = self.PlayerData[profileKey]
	local newProfile, ignoreSessionRequest = self.Request(profileKey, {

		Action = actionType,

		RestoreSession = isRestoringSession,
		RejectSave = profileSaveMetaData and profileSaveMetaData.RejectSave,

		RevertSession = function(latestData)

			--// Another session reclaimed ownership without realizing the original server still owns the profile

			local currentMetadata = profile[sessionKey]

			local metadata = latestData[sessionKey]
			local session = metadata.Session

			local jobId = GetJobId()

			do

				--// Restore the modified session to the original session

				metadata.Version = currentMetadata.Version
				metadata.State = "Locked"

				session.JobId = jobId
				session.PlaceId = game.PlaceId
			end

			task.spawn(MessagingService.PublishAsync, MessagingService, profileKey..topicKey, {

				--// Quickly request the other session to remove the player from that server

				Session = {

					JobId = jobId,
					PlaceId = game.PlaceId,

				}
			})
			return true
		end,

		Transform = function(latestData)
			local metadata = latestData[sessionKey]
			local session = metadata.Session

			metadata.LastUpdated = GetTime()

			if ValueCallback then

				--// Handles the custom callback if provided

				ValueCallback(latestData, profile)
				return
			end

			--// Updates the player's data
			latestData[dataKey] = profile[dataKey]

			if not AutoSave then

				--// Updates the metadata

				metadata.Version += 1
				metadata.State = "Available"

				session.JobId = nil
				session.PlaceId = nil
			end
		end

	})

	if not AutoSave then

		--// Remove any references to the player as the player is leaving

		self.PlayerData[profileKey] = nil
		if not ignoreSessionRequest then

			--// Allow the other condition to delete it after removing the player
			self.PlayerUserIds[profileKey] = nil
		end

		table.remove(self.ProfileLoaded, table.find(self.ProfileLoaded, profileKey))

		if not DatastoreEnabled and not MockDatastoreEnabled then

			--// Removes the profile from the simulated Datastore when running in SANDBOX mode
			self.Datastore:Clear(profileKey)
		end

		self.ClearProfileSubscriptions(profileKey)
		RemoveProfileFromAutoList(profileKey, self.Name)
	end

	if ignoreSessionRequest then

		--// In rare cases, the server that previously owned the profile may have its ownership transferred to another server during an auto-save or save attempt
		--// Remove the player to ensure the server clears its reference to the profile, helping prevent data corruption or loss

		local playerUserId = self.PlayerUserIds[profileKey]
		local playerInServer = playerUserId and Players:GetPlayerByUserId(playerUserId)

		if playerInServer then

			--// Remove the player from the server
			playerInServer:Kick(Settings.ProfileLockText)
		end

		self.PlayerUserIds[profileKey] = nil
		return wrapper:Execute({releaseProfile})
	end

	if not newProfile then

		--// Removes the player state when profile cannot be fetched
		return wrapper:Execute({releaseProfile})
	end

	wrapper:Execute({releaseProfile})
	return true --// Profile is saved!
end

--[[
Replaces the player's profile data with the template.
It is recommended to kick the player after calling this method.
]]
function DataCacher:WipeProfile(Player: Player)
	local self = self.__Internal
	local Settings = self.Settings

	local profileKey = Settings.Key(Player.Name, Player.UserId)
	local dataKey = self.GetStructureKeys()

	do
		self.WaitForPlayerState(profileKey)

		if IsServerClosing or not self.IsProfileLoaded(profileKey) then

			--// The server is shutting down or there's no profile
			return
		end
	end

	local profile = self.PlayerData[profileKey]

	--// Replaces the profile data with the template while retaining its metadata
	profile[dataKey] = Clone(Settings.TemplateData)
end

--[[
Deletes the player's profile from the Datastore.
Call this method once the profile has been loaded.
]]
function DataCacher:DeleteProfile(Player: Player): boolean
	local self = self.__Internal
	local Settings = self.Settings

	local deletionTable = self.DeletionRequests
	local profileKey = Settings.Key(Player.Name, Player.UserId)

	if IsServerClosing or table.find(deletionTable, profileKey) then

		--// This method was already called or the server is shutting down
		return false
	end

	table.insert(deletionTable, profileKey) --// Prevent all requests except save requests

	--// Saves the profile to remove any remaining references
	self.RequestProfileSave(Player)

	local wrapper = Wrapper.Create(function()
		local deletedKeyIndex = table.find(deletionTable, profileKey)
		if deletedKeyIndex then

			table.remove(deletionTable, deletedKeyIndex)
		end
	end)

	if self.IsProfileLoaded(profileKey) then

		--// The profile remains loaded even after a save attempt

		wrapper:Execute()
		return false
	end

	local success = pcall(function()

		--// Removes the profile from the Datastore
		--// Note: RemoveAsync() marks the profile as deleted but does not erase it until after the 30 day period

		self.Datastore:RemoveAsync(profileKey)
	end)

	if success then

		--// Remove the player to prevent potential bugs and ensure stability
		Player:Kick(Settings.ProfileDeletionText)
	end

	wrapper:Execute()
	return success
end

--[[
Retrieves the player's profile key using their Username and/or UserId.
Only one argument might be required, depending on Settings.Key.
]]
function DataCacher:GetProfileKey(Username: string?, UserId: number?): string
	local self = self.__Internal
	return self.Settings.Key(Username, UserId)
end

--[[
Retrieves the current player's profile state from the server or externally if not found. 
Default states “Locked” and “Available” are returned from the server or externally.

Locked: The profile is currently in use and not controlled by other states.
Available: The profile is inactive and not owned by a server.
Saving: The profile is currently being saved.
Loading: The profile is currently being loaded.
Auto-Saving: The profile is currently being automatically saved.
]]
function DataCacher:GetProfileState(ProfileKey: string): ProfileState?
	local self = self.__Internal

	local _, sessionKey = self.GetStructureKeys()

	local state = self.States[ProfileKey]
	if not state and (DatastoreEnabled or MockDatastoreEnabled) then

		--// State missing, likely because the player isn't in the server
		--// Falls back to fetching the state externally

		local success, profile = pcall(function()
			return self.Datastore:GetAsync(ProfileKey)
		end)

		if not success or not profile then

			--// Skip state retrieval if the profile doesn't exist
			return
		end

		do

			--// Checks if the profile is a valid profile and that there is a legitimate state
			--// Does not prevent user tampering

			if typeof(profile) ~= "table" then
				return
			end

			local metadata = profile[sessionKey]
			if not metadata or typeof(metadata) ~= "table" then
				return
			end

			local unknownState = metadata.State
			if unknownState ~= "Locked" and unknownState ~= "Available" then
				return
			end
		end

		--// Finally, return the state that is either "Locked" or "Available"
		return profile[sessionKey].State
	end

	--// The profile is loaded and has an active state
	return state
end

--[[
Returns true if the player's profile is currently being used by a server.
]]
function DataCacher:IsProfileLocked(ProfileKey: string): boolean?
	local state = self:GetProfileState(ProfileKey)
	if not state then

		--// No state was found
		return
	end
	return state ~= "Available"
end

--[[
Listens for profile state changes from the server.
Returns a table with a Disconnect() function to stop listening to the given callback.
]]
function DataCacher:OnProfileStateChanged(ProfileKey: string, StateCallback: StateCallback): Disconnect
	local self = self.__Internal

	local stateCallbacks = self.StateCallbacks
	local profileStates = stateCallbacks[ProfileKey]

	if not profileStates then

		--// Creates the table for future callbacks

		stateCallbacks[ProfileKey] = {}
		profileStates = stateCallbacks[ProfileKey]
	end

	table.insert(profileStates, StateCallback)

	local isDisconnected = false
	return {

		Disconnect = function()
			if isDisconnected then

				--// This function was already called
				return
			end
			isDisconnected = true

			for index, callback in profileStates do
				if callback == StateCallback then

					--// Removes the callback from the table
					table.remove(profileStates, index)
					break
				end
			end

			if #profileStates == 0 then

				--// Deletes the table as there are no callbacks left

				stateCallbacks[ProfileKey] = nil
				profileStates = nil
			end
		end,

	}
end

--[[
Returns a copy of the player's original profile by fetching it externally.
If the current server owns the profile, this method returns the original profile directly without external fetching.

This method might return an invalid profile format unless corrected at runtime.
]]
function DataCacher:GetProfileAsync(ProfileKey: string): RawProfile?
	local self = self.__Internal

	if self.IsProfileLoaded(ProfileKey) then

		--// Profile is already loaded on this server
		return self.PlayerData[ProfileKey]
	else
		if DatastoreEnabled or MockDatastoreEnabled then

			--// API services are enabled

			local success, profile = pcall(function()
				return self.Datastore:GetAsync(ProfileKey)
			end)
			return success and profile
		end
	end
end

--[[
Saves the provided profile using SetAsync() rather than UpdateAsync().
This method fails if the player's profile is already loaded on a server.
]]
function DataCacher:SaveProfileAsync(ProfileKey: string, Profile: RawProfile): boolean
	local state = self:GetProfileState(ProfileKey)
	if state ~= "Available" then

		--// The profile is either in use by a server or does not exist
		return false
	end

	local success = pcall(function()

		--// Saves the provided profile
		self.__Internal.Datastore:SetAsync(ProfileKey, Profile)
	end)
	return success
end

--[[
For cases where IndexingName is used and the system appends additional characters. 
This method locates the resulting key and returns the value assigned to it along with a table of keys with similar names.
]]
function DataCacher:GetValueFromIndexingName(ProfileKey: string): ( any, { string }? )
	local self = self.__Internal

	local indexName = self.Settings.IndexingName
	local dataKey = self.GetStructureKeys()

	if not self.IsProfileLoaded(ProfileKey) then

		--// Ignores if there's no profile
		return
	end

	local profile = self.PlayerData[ProfileKey]
	local matchesTable = {}

	for key, value in profile[dataKey] do

		--// Iterates through all keys to locate ones that contain the required variables

		if typeof(key) ~= "string" then

			--// Accept only keys that are strings
			continue
		end

		local prefixStart, prefixEnd = key:find(indexName)
		local suffixStart, suffixEnd = key:find(LAST_CHARACTER_SUFFIX)

		if not (prefixStart and suffixStart) then

			--// The key must contain "__OldData" (prefix) and "DC" (suffix)
			continue
		end

		if prefixStart ~= 1 or suffixEnd ~= #key then

			--// The prefix must be at the start of the key
			--// The suffix must be at the end of the key

			continue
		end

		local gapStart, gapEnd = prefixEnd + 1, suffixStart - 1
		local isGapIdentical = true

		for index = gapStart, gapEnd do

			--// Checks whether the gap between the prefix and suffix contains an "_"

			local char = key:sub(index, index)
			if char ~= SPACE_CHARACTER then

				--// The gap between the prefix and suffix is "_" and not any other character

				isGapIdentical = false
				break
			end
		end

		if not isGapIdentical then
			continue
		end
		table.insert(matchesTable, key)
	end

	table.sort(matchesTable, function(a, b)

		--// The system appends characters to make the key unique, which can increase its length
		--// Sorting the table in descending order ensures the longest key comes first

		return #a > #b
	end)

	local key = matchesTable[1]
	local value = key and profile[dataKey][key]

	return value, value and matchesTable or nil
end

RunService.Heartbeat:Connect(function()

	--// Auto-saving of profiles / Auto-refreshing of LastUpdated

	--// Based on the ProfileStore system, with added documentation and minor changes
	--// https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543

	local interval = GlobalSettings.AutoSave and GlobalSettings.AutoSaveInterval or GlobalSettings.SessionDeadThreshold / 2
	local autoUpdateList = gTable.AutoUpdateList

	local totalProfiles = #autoUpdateList
	if totalProfiles > 0 then

		--// Adjusts the delay dynamically based on the total number of profiles in the list
		local delayPerProfile = interval / totalProfiles
		local profile

		local now = os.clock()

		local function AdjustProfilePointer()
			ProfilePointer += 1 --// Move to the next profile
			if ProfilePointer > totalProfiles then

				--// Loops the pointer back to the first profile when it reaches the end of the list
				ProfilePointer = 1
			end
		end

		local function IsProfileReadyForUpdate()

			--// Returns true if the profile’s age exceeds half of Interval
			--// This system automatically saves profiles over time using a rotation-based approach
			--// It spreads saves evenly across all active profiles to avoid spikes in Datastore requests
			--// After the first save, the system enforces full rotation timing automatically

			--[[
				
				An example with two profiles and an interval of one minute:
				
				T = Time
				Delay = 60 seconds / 2 profiles (30 seconds for each profile)
				
				Timeline:
				T = 0s (Profiles were just created)
				T = 30s (Profile #1 is saved)
				T = 60s (Profile #2 is saved)
				T = 90s (Profile #1 is saved, since the full one minute has passed)
				T = 120s (Profile #2 is saved, since the full one minute has passed)
				
			--]]

			return (now - profile.LastCreated) >= (interval / 2)
		end

		--// Checks if sufficient time has passed before saving a profile
		--// Uses a while loop to catch up on timing when the frame runs slower than expected
		while (now - LastUpdate) > delayPerProfile do
			LastUpdate += delayPerProfile --// Uses delayPerProfile to keep the system on schedule and prevent timing drift

			for _ = 1, totalProfiles do

				--// Checks for every profile in the list
				--// Maximizes each save attempt to find a profile until one meets the age requirement

				profile = autoUpdateList[ProfilePointer]

				if IsProfileReadyForUpdate() then

					--// The current profile is eligible for saving
					break
				end

				--// Set the profile to nil and move to the next profile

				profile = nil
				AdjustProfilePointer()
			end

			if profile then

				--// Save the profile and move to the next profile

				local datastore = DataCacher.GetDatastore(profile.DatastoreName, nil, true)
				task.defer(datastore.SaveProfile, datastore, {

					Key = profile.ProfileKey,
					RejectSave = not GlobalSettings.AutoSave, --// For LastUpdated

				}, true)

				AdjustProfilePointer()
			end
		end
	end
end)

game:BindToClose(function()

	--// Used for final edge cases such as when the server shuts down unexpectedly
	--// Helps during Studio shutdowns when PlayerRemoving misses save requests

	IsServerClosing = true
	WaitForDatastoreAccess()

	local activeProfileSaveRequests = 0
	if DatastoreEnabled or MockDatastoreEnabled then

		for _, datastore in gTable.Datastores do
			local self = datastore.__Internal

			--// Saves any remaining profiles
			for profileKey in self.PlayerData do
				activeProfileSaveRequests += 1

				task.spawn(function()

					self.RequestProfileSave({Key = profileKey})
					activeProfileSaveRequests -= 1
				end)
			end
		end

		--// Yields until all asynchronous operations are complete 
		while activeProfileSaveRequests > 0 or ActiveProfileRequests > 0 do
			task.wait()
		end
	else

		--// Since it's a mock Datastore, there's no need to wait for operations to complete
		return
	end
end)

return DataCacher