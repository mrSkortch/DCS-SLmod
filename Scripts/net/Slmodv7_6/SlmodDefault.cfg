--Slmod v7_0 Configuration Options
-- YOU WOULD BE SMART TO MODIFY THIS USING Notepad++, A FREE TEXT EDITOR AVAILABLE AT http://notepad-plus-plus.org/
-- YOU WOULD BE SMART TO MODIFY THIS USING Notepad++, A FREE TEXT EDITOR AVAILABLE AT http://notepad-plus-plus.org/
-- YOU WOULD BE SMART TO MODIFY THIS USING Notepad++, A FREE TEXT EDITOR AVAILABLE AT http://notepad-plus-plus.org/
-- Did I say that enough?

--[[ In Notepad++,
	- Everything that is green is a comment and is not executed as Lua code.
	- Booleans (true/false), nil and other things are highlighted in blue.
	- Strings are highlighted in grey.
	- Numbers are highlighted in orange.
]]
----------------------------------------------------------------------------------------------------------------------
-- Slmod admin tools options
--[[
Set to true to enable Slmod admin tools menu to allow server admins to kick, ban, unban, add admins, remove admins, 
pause/unpause missions, restart the mission, and load a different mission from a specific folder (this folder is by 
default <Windows Install Drive>\Users\<Your User Account Name>\Saved Games\DCS\Slmod\Missions\).
]]
admin_tools = true

	--[[Adjust the display mode of the admin menu here.  Use either "text", "chat", "echo", or "both"
	Note: when a player that is incapable of receiving private trigger text requests to view the admin menu, Slmod will automatically
	send that player a series of chat messages instead.]]
	admin_display_mode = 'text'
	
	--[[Adjust the display time of the admin menu here.]]
	admin_display_time = 30
	
	--[=[If the admin tools are enabled, then this variable matters.  
	The Slmod Admin tools allows server admins to load any mission from a specific folder.
	By default, this folder is <Windows Install Drive>\Users\<Your User Account Name>\Saved Games\DCS\Slmod\Missions\.
	You can specify an alternate folder to use by setting this variable.
	
	For example, if you have multiple servers utilizing the same Dropbox folder for all your missions, your windows 
	install drive is C:, and your user account name is "John", then you could set this variable like this:
	
	admin_tools_mission_folder = [[C:\Users\John\Dropbox\Dedicated Servers\Slmod\Missions\]]
	
	LEAVE THIS VARIABLE AS nil IF YOU WANT TO USE THE DEFAULT FOLDER!]=]
	admin_tools_mission_folder = nil
	
	
	--[[If the admin tools are enabled, then this variable matters.  
	Using the "admin_register_password" variable below allows you to specify a password that will allow people
	to register themselves as server admins.  If you specify a password below, then whenever someone says "-reg"
	in chat, their NEXT chat message will be a password entry, and not shown to the rest of the players.  If their
	password entry matches the password below, they will be registered as admins to the server.
	
	For example, if you set the variable below like this:
	
	admin_register_password = "dcs123"
	
	then whenever someone types:
	
	-reg
	
	in chat, Slmod will say back to them:
	"Please enter the password to register you as a server admin (your next chat message in this mission will not be publicly displayed)."
	
	Next, if they type in chat:
	
	dcs123
	
	they will be added to the list of admins.]]
	admin_register_password = nil
	
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- SlmodStats
--[[If you set the value below to false, then SlmodStats will start disabled when you start the game.  It can be enabled at any 
time by a server admin by using the "-admin toggle stats" option in the Admin menu.  
]]
enable_slmod_stats = true
	
	--[[Enables mission-specific stats. The mission-specific stats may be written to a file and/or displayed in the in-game
	stats menu.]]
	enable_mission_stats = false
	
		--[[If mission-specific stats are enabled, then set this variable to true to save these mission stats to a file.  By default, 
		these files are located in Saved Games/DCS/Slmod/Mission Stats.]]
		write_mission_stats_files = true
		
		--[[If you don't want mission stats files saving in Saved Games/DCS/Slmod/Mission Stats, then specify an alternate file 
		directory here.]]
		mission_stats_files_dir = nil

	--[[In order for the host computer to get credit in the SlmodStats system, you must enter the UCID of the host computer below.
	The UCID must be in quotes, like this: 
	host_ucid = "a29fb043d814a012452f043dc"
	]]
	host_ucid = nil

		--[[The host's multiplayer name.  Only matters if you also specify a UCID.  The name must be quotes, like this:
		host_name = "Speed"
		]]
		host_name = nil
		
	--[[You can tell Slmod to use an alternate file directory to record global SlmodStats in here.  Otherwise, it will default
	to \Saved Games\DCS\Slmod\SlmodStats.lua.  Most useful for sharing stats with other computers/servers.]]
	stats_dir = nil
    
    --[[When displaying detailed stats the list for guns can be simplified. If this is set to true then all guns are added into a "guns" statistic. If false each type
        of gun is shown with its own stats. ]]
    simple_gun_stats = false
    
	
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- AutoAdmin settings
-- SLMOD STATS MUST BE ENABLED FOR AUTOKICK/AUTOBAN TO WORK

-- DO NOT MODIFY THIS
autoAdmin = {} -- DO NOT MODIFY THIS
-- DO NOT MODIFY THIS 

------------------------------------------------------
-- Global AutoKick/Autoban settings
--Set autoAdmin.autoBanEnabled to true below to enable autobanning.
autoAdmin.autoBanEnabled = true

--Set autoAdmin.autoKickEnabled to true below to enable autokicking
autoAdmin.autoKickEnabled = true

--Set autoAdmin.autoSpecEnable to true below to enable auto kicking to spectator
autoAdmin.autoSpecEnabled = true

--Set autoAdmin.foriveEnabled to true below to enable forgive command
autoAdmin.forgiveEnabled = true

--Set autoAdmin.punishEnabled to true below to enable punish command
autoAdmin.punishEnabled = true

--Set autoAdmin.msgOnForgive to true below to display a message when a player decides to forgive another player for Teamhit/damage
autoAdmin.msgOnForgive = true
-- Set autoAdmin.msgOnForgiveMode to specify how you want the punish message to be displayed. 
autoAdmin.msgOnForgiveMode = 'chat'
--Set autoAdmin.msgOnPunish to true below to display a message when a player decides to punish another player for Teamhit/damage
autoAdmin.msgOnPunish = true
-- Set autoAdmin.msgOnPunishMode to specify how you want the punish message to be displayed. 
autoAdmin.msgOnPunishMode = 'chat'
--Set autoAdmin.msgPromptOnKilled to true below to display a message to the player that has been teamkilled with information on how to forgive or punish the teammate. 
autoAdmin.msgPromptOnKilled = true
-- Set autoAdmin.msgPromptOnKilledMode to specify how you want the punish message to be displayed. 
autoAdmin.msgPromptOnKilledMode = 'text'
-- Set autoAdmin.consentEnabled to true below to enable a command that allows players to automatically given consent to being teamkilled. This is useful for training purposes. 
-- Teamkill stats will show up in the slmodStats file, however they will be labeled as "forgiven" automatically. 
autoAdmin.consentEnabled = false
-- Set autoAdmin.showPenaltyInMODT to display a players current penalty score in the Message of the Day on spawning in a slot or MODT command
autoAdmin.showPenaltyInMODT = true
-- Set autoAdmin.showPenaltyKickBanActions to display to a player their penalty score when kicked or attempting to join a server while banned. 
autoAdmin.showPenaltyKickBanActions = true
-- Set autoAdmin.userCanGetOwnDetailedPenalty to enable the command to allow the player to get their own detailed penalty score. 
autoAdmin.userCanGetOwnDetailedPenalty = true


-- the required penalty points before a player is autobanned.
autoAdmin.autoBanLevel = 100

-- the required penalty points before a player is autokicked.
autoAdmin.autoKickLevel = 60  

-- the required penalty points before a player is autokicked to spectators
autoAdmin.autoSpecLevel = 40

-- The amount of time the option to forgive will be available for in seconds
autoAdmin.forgiveTimeout = 30

-- Amount of time it waits before allowing a punishment can occur
autoAdmin.punishTimeout = 30

-- If true it will allow for the the punish timeout to be reached before punishment is applied. If false punishment will occur immediately. Victim can still forgive within forgiveTimeout
autoAdmin.punishFirstForgiveLater = false
--[[
forgiveTimeout and punishTimeout do not need to be equal.

If forgiveTimeout was set to be 120 seconds and punishTimeout to 0. The punishment will be applied immediately (or after whichever KickBanDelay applies) In the following 2 minutes
the player can be forgiven.

Example: 
Player A teamkills B. A gets kicked from the server. B decides to forgive. A rejoins and their penalty score hasn't changed. 
Note that if player A gets temp or perma banned and is later forgiven the ban will still apply!


Also note that with this change a new entry can be added to the 
]] 


--[[ 
Describes how penalty points are weighted based on how many flight hours the offender has. Each entry in the table 
below is a point on a curve.  Each point contains both a time (in HOURS) and a value (weight).
Past the time specified for the last point on the curve, the value (weight) of the last point is maintained indefinitely.

The first time specified should be time = 0, the time of the offense.
]]
autoAdmin.flightHoursWeightFunction = {
	[1] = {time = 0, weight = 1.4},
	[2] = {time = 3, weight = 1},
	[3] = {time = 10, weight = 0.7},
}

-- After this number of temp bans, the player gets perma-banned.
autoAdmin.tempBanLimit = 2

-- The number of penaltyPoints that an autobanned player's penalty score must decay to in order to be reallowed into the server.
autoAdmin.reallowLevel = 75

-------------------------------------------------------------------------------
-- TEAM HIT SETTINGS

-- DO NOT MODIFY THIS
autoAdmin.teamHit = {} -- DO NOT MODIFY THIS
-- DO NOT MODIFY THIS

--[[ 
If autokicking and/or autobanning is enabled, allow team hitting to be taken into account by setting 
autoAdmin.teamHit.enabled = true below.]]
autoAdmin.teamHit.enabled = false

-- initial penalty points for team-hitting an AI.
autoAdmin.teamHit.penaltyPointsAI = 8  

-- initial penalty points for team-hitting a human.
autoAdmin.teamHit.penaltyPointsHuman = 12

--[[ 
Describes how penalty points for team hitting decay over time.  Each entry in the table below is a point on a curve.
Each point contains both a time ( in DAYS) and a value (weight).
Past the time specified for the last point on the curve, the value (weight) of the last point is maintained indefinitely.

The first time specified should be day 0, the time of the offense.
]]
autoAdmin.teamHit.decayFunction = {
	[1] = {time = 0, weight = 1},
	[2] = {time = 3, weight = 0.75},
	[3] = {time = 30, weight = 0.25},
	[4] = {time = 60, weight = 0},
}

--[[This setting limits how often team hits on AI units can count towards autokicking/autobanning.  At the most, 
team hits on AI units can only be counted once every autoAdmin.teamHit.minPeriodAI seconds.]]
autoAdmin.teamHit.minPeriodAI = 30

--[[This setting limits how often team hits on human players can count towards autokicking/autobanning.  At the most, 
team hits on human players can only be counted once every autoAdmin.teamHit.minPeriodHuman seconds.]]
autoAdmin.teamHit.minPeriodHuman = 5
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TEAM KILL SETTINGS

-- DO NOT MODIFY THIS
autoAdmin.teamKill = {} -- DO NOT MODIFY THIS
-- DO NOT MODIFY THIS

--[[ 
If autokicking and/or autobanning is enabled, allow team killing to be taken into account by setting 
autoAdmin.teamKill.enabled = true below.]]
autoAdmin.teamKill.enabled = true

-- initial penalty points for team-killing an AI.
autoAdmin.teamKill.penaltyPointsAI = 18

-- initial penalty points for team-killing a human.
autoAdmin.teamKill.penaltyPointsHuman = 30

--[[ 
Describes how penalty points for team killing decay over time.  Each entry in the table below is a point on a curve.
Each point contains both a time (in DAYS) and a value (weight).
Past the time specified for the last point on the curve, the value (weight) of the last point is maintained indefinitely.

The first time specified should be day 0, the time of the offense.
]]
autoAdmin.teamKill.decayFunction = {
	[1] = {time = 0, weight = 1},
	[2] = {time = 3, weight = 0.75},
	[3] = {time = 30, weight = 0.25},
	[4] = {time = 60, weight = 0},
}

--[[This setting limits how often team kills on AI units can count towards autokicking/autobanning.  At the most, 
team kills on AI units can only be counted once every autoAdmin.teamKill.minPeriodAI seconds.]]
autoAdmin.teamKill.minPeriodAI = 20

--[[This setting limits how often team kills on human players can count towards autokicking/autobanning.  At the most, 
team kills on human players can only be counted once every autoAdmin.teamKill.minPeriodHuman seconds.]]
autoAdmin.teamKill.minPeriodHuman = 0
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TEAM COLLISION HIT SETTINGS

-- DO NOT MODIFY THIS
autoAdmin.teamCollisionHit = {} -- DO NOT MODIFY THIS
-- DO NOT MODIFY THIS

--[[ 
If autokicking and/or autobanning is enabled, allow team collision hitting to be taken into account by setting 
autoAdmin.teamCollisionHit.enabled = true below.]]
autoAdmin.teamCollisionHit.enabled = false

-- initial penalty points for team collision-hitting an AI.
autoAdmin.teamCollisionHit.penaltyPointsAI = 1

-- initial penalty points for team-collision-hitting a human.
autoAdmin.teamCollisionHit.penaltyPointsHuman = 5

--[[ 
Describes how penalty points for team collision-hitting decay over time.  Each entry in the table below is a point on a curve.
Each point contains both a time (time) and a value (weight).
Past the time specified for the last point on the curve, the value (weight) of the last point is maintained indefinitely.

The first time specified should be time 0, the time of the offense.
]]
autoAdmin.teamCollisionHit.decayFunction = {
	[1] = {time = 0, weight = 1},
	[2] = {time = 2, weight = 0.75},
	[3] = {time = 30, weight = 0},
}

--[[This setting limits how often team collision-hitting on AI units can count towards autokicking/autobanning.  At the most, 
team collision hits on AI units can only be counted once every autoAdmin.teamCollisionHit.minPeriodAI seconds.]]
autoAdmin.teamCollisionHit.minPeriodAI = 10

--[[This setting limits how often team collision-hitting on human players can count towards autokicking/autobanning.  At the most, 
team collision hits on human players can only be counted once every autoAdmin.teamCollisionHit.minPeriodHuman seconds.]]
autoAdmin.teamCollisionHit.minPeriodHuman = 10
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TEAM COLLISION KILL SETTINGS

-- DO NOT MODIFY THIS
autoAdmin.teamCollisionKill = {} -- DO NOT MODIFY THIS
-- DO NOT MODIFY THIS

--[[ 
If autokicking and/or autobanning is enabled, allow team collision killing to be taken into account by setting 
autoAdmin.teamCollisionKill.enabled = true below.]]
autoAdmin.teamCollisionKill.enabled = true

-- initial penalty points for team collision-killing an AI.
autoAdmin.teamCollisionKill.penaltyPointsAI = 12 

-- initial penalty points for team collision-killing a human.
autoAdmin.teamCollisionKill.penaltyPointsHuman = 20

--[[ 
Describes how penalty points for team collision-killing decay over time.  Each entry in the table below is a point on a curve.
Each point contains both a time (in DAYS) and a value (weight).
Past the time specified for the last point on the curve, the value (weight) of the last point is maintained indefinitely.

The first time specified should be time 0, the time of the offense.
]]
autoAdmin.teamCollisionKill.decayFunction = {
	[1] = {time = 0, weight = 1},
	[2] = {time = 2, weight = 0.75},
	[3] = {time = 30, weight = 0},
}

--[[This setting limits how often team collision-killing on AI units can count towards autokicking/autobanning.  At the most, 
team collision kills on AI units can only be counted once every autoAdmin.teamCollisionKill.minPeriodAI seconds.]]
autoAdmin.teamCollisionKill.minPeriodAI = 0

--[[This setting limits how often team collision-killing on human players can count towards autokicking/autobanning.  At the most, 
team collision kills on human players can only be counted once every autoAdmin.teamCollisionKill.minPeriodHuman seconds.]]
autoAdmin.teamCollisionKill.minPeriodHuman = 0
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- AutoAdmin exemption list
--[[
All server administrators registered to the Slmod Admin Menu are naturally exempt from being autokicked/autobanned.  However, if 
you want to add additional players to the exemption list, do so below.

The forumla for an entry in autoAdmin.exemptionList is as follows:

["<player's ucid>"] = "<player's name>",

such as:

autoAdmin.exemptionList = {
	["14da0413fe23c41b2495f2f257"] = "f1owyerG",
	["a50f741d91ef2478213b42023f"] = "deepS",
	["ab04135debb24c40032489ad03"] = "semirG",
}

The player's name isn't used for anything really, it's just a label for YOU to remember who they are.
]]
autoAdmin.exemptionList = {


}

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

-- AutoAdmin kick/ban delay settings
--[[
This setting sets a value on how long of a delay in seconds a kick or ban will wait when the autoadmin decides to do either. 
If set to 0 the delay will be non existent. Value must not be negative, otherwise no delay will be used. 
Purpose of this function is to let the victim and others know that a specified user is being kicked or banned. 
]]

autoAdmin.kickBanDelay = {}

autoAdmin.kickBanDelay.kickDelay = 10 -- Delay for kicks

autoAdmin.kickBanDelay.banDelay = 10 -- delay for bans

autoAdmin.kickBanDelay.specDelay = 10 -- delay for kicking to spectator
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- Vote mission settings
--[[
3 types of voting exist:
1. majority : this is the simple majority wins a vote
    Example: 5 Vote for A, 3 Vote for B, and 6 vote for C: C wins
2. magic : short for magic number, this means a required minimum number of votes are needed to change the mission
    Example 1: val set to 5, A gets 4, B gets 5, C gets 3: B wins
    Example 2: val set to 6, A gets 4, B gets 5, C gets 3: Vote fails
3. ratio : A set ratio of the players on the server need to vote for a mission.
    Example 1: val set to 0.6 (60%). 20 players on server. A gets 14, B gets 5: A Wins
    Example 2: val set to 0.6 (60%). 10 players on server. A gets 2, B gets 7: B Wins
]]
voteConfig = {}
-- If voting is enabled. Must be enabled for RTV to be enabled
voteConfig.enabled = true
-- Max time in seconds the vote will last for. Can be overrided by endIF condition
voteConfig.maxVoteTime = 180
-- minimum time in seconds the vote will last for. CANNOT be overrided
voteConfig.minVoteTime = 60
--Time between when votes can take place
voteConfig.voteTimeout = 1200 -- delay until the next mission vote can take place
-- Player votes and vote status will be hidden or not
voteConfig.hidden = false 
-- where messages will be displayed for voted status
voteConfig.display_mode = 'chat'

voteConfig.display_time = 30
-- time in seconds which any update for the vote will take place.
-- If vote is hidden it only displays time left
voteConfig.voteReminder = 30
-- Allow voting if an admin is present on the server.
-- Admin can toggle, start, and stop voting at any point regardless
voteConfig.allowIfAdminPresent = true
-- Require an admin to allow the vote to take place if one is connected. 
voteConfig.requireAdminVerifyIfPresent = false


--[[
ruleSets table can be used to define different voting rules that apply as the number of players on a server change

rangeMin: minimum number of players in range
rangeMax: max range of players in range
use: which voting type to use
val: number. Meaning defined by rule used. 
    majority: does nothing
    magic: number of votes that must be reached for a mission to win
    ratio: percentage of users that must vote for the mission
endIf: Optional condition to end the vote before maxVoteTime is reached based on the number of votes cast
0: vote goes till maxVoteTime
0.0-1.0: (example 0.8) ratio of players needed to vote
1+: number of players needed to vote to end the vote early
---
Default ruleset is defined as follows: 

voteConfig.ruleSets = {
    [1] = {rangeMin = 0, rangeMax = 9, use = 'majority', val = 0, endIf = 1},
    [2] = {rangeMin = 10, rangeMax = 21, use = 'magic', val = 8, endIf = 17}, 
    [3] = {rangeMin = 22, rangeMax = 999, use = 'ratio', val = 0.6, endIf = 0.8},
}


]]
voteConfig.ruleSets = {
    [1] = {rangeMin = 0, rangeMax = 9, use = 'majority', val = 0, endIf = 1},
    [2] = {rangeMin = 10, rangeMax = 21, use = 'magic', val = 8, endIf = 17}, 
    [3] = {rangeMin = 22, rangeMax = 999, use = 'ratio', val = 0.6, endIf = 0.8},
}
-- In sample ruleSet 0-9 players will use majority rules. If all players vote then the vote will be decided after last vote
-- 10-21 players use magic number rules with a value of 8 votes. If 17 of possible 21 players vote then the vote will be decided
-- 22-999 players will use a ratio rule requiring 60% of the vote. If 80% of the players on the server vote, the vote will end. 


-- if multiple rules overlap in range then the first rule that is valid for the current player count will be used



-- If Rock the Vote is enabled. Intention for this is to act as a buffer to mission voting. Players know if an RTV succeeds there will be a mission vote. 
voteConfig.rtvEnabled = true
-- Ratio of players needed to RTV to start a vote
voteConfig.rtvLevel = 0.5
-- How often an RTV vote can take place
-- if set to 0, players can call for an rtv at any time
voteConfig.rtvTimeout = 1200
-- How long an RTV vote can go from first few first vote to last
-- If set to 0 vote time is forever
voteConfig.rtvVoteTime = 1000


----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- String of what each map name will be prefixed by on the vote mission list and admin load mission list. 
-- Mission must have been loaded onto the server and populated into the metaStats file. Otherwise the prefix will be blank
-- Also missions with the word 'miz' in it may not display correctly. 
mapStrings = {
    ['Caucasus'] = 'BS',
    ['Nevada'] = 'NV',
    ['Normandy'] = 'NO',
    ['PersianGulf'] = 'PG',
}

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- PingCheck settings
pingcheck_conf = {}

--Enable/disable PingCheck
pingcheck_conf.enabled = true

--Maximum ping
pingcheck_conf.max_ping = 350

--Defines the waiting time between ping checks in seconds
pingcheck_conf.wait_time = 10

--Defines the waiting time between high ping warnings in seconds
pingcheck_conf.warning_repeat_time = 30

--Limits the amount of warnings a player can receive
pingcheck_conf.warning_limit = 4

--Enables/disables sending a warning message to a player
pingcheck_conf.warning_msg = true

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- General Server Options

--set to true to make the server automatically pause when only the server host is the only person present in the mission.
pause_when_empty = false

--Set to true to make Slmod output a chat log to \Saved Games\DCS\Slmod\Chat Logs\<Date, time stamp>.txt.
chat_log = true

	-- IF chat logging is set true, then enable this variable to also log team hitting events in the chat log.
	-- SLMOD STATS MUST BE ENABLED FOR THIS OPTION TO WORK
	log_team_hits = true
	
	-- IF chat logging is set true, then enable this variable to also log team killing events in the chat log.
	-- SLMOD STATS MUST BE ENABLED FOR THIS OPTION TO WORK
	log_team_kills = true

    -- If chat logging is set true, then this variable is used to filter out common serverside messages from chat. Currently messages SLMOD sends to clients is logged.
    -- Chat log gets filled up with MOTD, chat commands, etc. If true only the important messages from slmod will be logged. If false all messages from server will be logged. 
    log_only_important_server_messages = true
--[[Enables server-wide chat messages that announce when players achieve PvP (player-vs-player) kills in SlmodStats.  
Remember that PvP kills follow their own special rules- see the Slmod manual for more info.
THIS OPTION REQUIRES THAT SLMODSTATS IS ENABLED!]]
enable_pvp_kill_messages = true
	
--[[Enables server-wide chat messages that announce when players hit friendly units with weapons.
THIS OPTION REQUIRES THAT SLMODSTATS IS ENABLED!]]
enable_team_hit_messages = true

--[[Enables server-wide chat messages that announce when player kill friendly units with weapons.
THIS OPTION REQUIRES THAT SLMODSTATS IS ENABLED!]]
enable_team_kill_messages = true	
	
--Enables the server Message Of The Day (MOTD).  It will be sent to everyone every time they join an aircraft.
MOTD_enabled = true

	--Enter your custom MOTD here.  It replaces the first line of the default MOTD.
	custom_MOTD = nil
		
	-- The display time of the MOTD.  Seconds.
	MOTD_display_time = 30
		
	-- The display mode of the MOTD.  The same options as for the PTS_list_display_mode (see below).
	MOTD_display_mode = 'chat'		
	
	-- In the MOTD, this setting controls whether or not the keystrokes to access the POS/PTS are given.
	MOTD_show_POS_and_PTS = false
	
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- Parallel Tasking System options:
--[[
Default display_mode for the Parallel Tasking System list, allowed values are:
'chat' - display as a chat message.  Will "flash" to fill the entire display_time.
'echo' - trigger text for the entire duration of the display_time, plus a single chat message "echo" of every line.
'text' - trigger text only.
'both' - both the 'chat' and 'text' options simultaneously.
]]
PTS_list_display_mode = 'text'

--display time for the Parallel Tasking System list; seconds.
PTS_list_display_time = 30

--Output mode for the Parallel Tasking System's tasks, same allowed values as PTS_list_display_mode (see above).
PTS_task_display_mode = 'text'

--display time for the Parallel Tasking System's tasks; seconds.
PTS_task_display_time = 40
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- Parallel Options System options:

--Output mode for the Parallel Options System menu/list, same allowed values as PTS_list_display_mode (see above).
POS_list_display_mode = 'text'

--display time for the Parallel Options System list; seconds.
POS_list_display_time = 30

----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- MISCELLANEOUS OPTIONS

--Set to true to output active, alive units to \Saved Games\DCS\Slmod\activeUnits.txt.  activeUnits.txt is updated roughly every 3-4 seconds.
export_world_objs = false

--[[Set to true to output world events to the file \Saved Games\DCS\Slmod\slmodEvents.txt.  These are updated in 
real time, no faster than about about once per second.]]
events_output = false
	
-- true: coordiante converter allowed, false: coordinate converter disabled for all
coord_converter = true 

-- Facility to report Lua syntax errors at mission start, set true to enable this, false to disable.
debugger = false 

	-- file where syntax errors will be saved to.
	debugger_outfile = 'Lua_Syntax_Errors.txt'  

--[[
Slmod sends data from the mission scripting Lua environment to the net environment through localhost (your own computer) via
a UDP port.  By default, this UDP port is 52146, which is not a port used by anything known.  However, if you want to change 
it, specify a different port here (note: must be a VALID port!).
]]
udp_port = 52146

----------------------------------------------------------------------------------------------------------------------
-- Config version, don't touch this!	
configVersion = '28'