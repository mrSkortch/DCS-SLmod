--Slmod Config
--[[ If you are looking here for Slmod configuration settings, they have been moved to 
	<Windows Install Drive>\Users\<Your User Account Name>\Saved Games\DCS\Slmod\config.lua
	
	DEFAULT ONLY configuration settings are located at:
	<DCS Install Directory>\Scripts\net\Slmodv<Slmod Version>\SlmodDefault.cfg
]]
--[[
060
changed autoAdmin.<offense type>.decayCurve to autoAdmin.<offense type>.decayFunction
changed autoAdmin.flightHoursCoefficient to autoAdmin.flightHoursWeightFunction
SlmodDebugger now disabled by default
]]

--[[
059
- log_team_kills option added
- team kills/team hits now written to chat log via SlmodStats.
- delayed kick on autokick/autoban implemented; attempt to despawn client unit made.
- stats-by-mission added
- added write_mission_stats_files option to config
- added mission_stats_files_dir option to config
- added experimental code to error check slmod.clients  - maybe remove in release version, or make an option.
]]

--[[
058
- chat_log config option now true by default
- a BannedClients.lua file is now created if one does not exist.
- reorganized config options a bit.
- added SlmodMissionScripting.lua and the auto-installer code into SlmodConfig.lua
- Slmod now installs from Saved Games/DCS

- Added SlmodAutoAdmin

- converted BannedClients to the new format:
	slmod.bannedUcids/Ips = {
		[<ip>/<ucid>] = { 
			ucid = ucid, 
			ip = <ip>, 
			time = <os.time()>, 
			exp = <expiration time, optional variable>,
			name = <client name>,
			bannedBy = { name = <name>, ucid = <ucid>} OR "autoban",
		}
	}

- fixed world.onEvent Lua error on nil weapon.
- pvp kills no longer awarded for killing players on the ground
]]

--[[
057
- added friendly collision hits, friendly collision kills, and kamikaze to SlmodStats
- added the enable_pvp_kill_messages, enable_team_hit_messages, and enable_team_kill_messages options to the config options
- added the pvp kill, team hit, and team kill chat message notifications
- fixed a bug that caused kills to be counted double in many cases (due to change in Unit.isExist- returns false when pilot dead or ejected, wtf?!?!)
]]

--[[
056
- added admin_display_mode and admin_display_time options.
- added the kick-by-id and ban-by-id admin menu options and submenus
- added 1.2.4 compatibility
- uses netview to determine the proper time to begin and end server.on_process code - check in future versions of DCS to ensure netview is maintained!
]]



--[[
055
- Added .getScope method to SlmodMenu.
- Added .getItems method to SlmodMenu.
- MOTD default message now detects if you are a server admin.
- Added -help menu
- fixed crash on exit bug (had to detect whether the last event to occur was "END MISSION" before running coroutine).  The crash was caused by DCS.getUnitProperty used after the server has already shut down.

]]




--[[
When new version of config settings:

slmod.version - needs to be updated in MissionScripting.lua and SlmodConfig.lua.
slmod.configVersion - needs to be updated in SlmodConfig.lua
configVersion - needs to be updated in SlmodDefault.cfg
]]
slmod = slmod or {}
slmod.config = slmod.config or {}

slmod.version = '7_5'  -- file directory

slmod.mainVersion = '7_5'  -- so far, these are only used in MOTD and some load scripts.
slmod.buildVersion = '119'  

slmod.configVersion = '28'  -- as new options as are added to SlmodConfig, this will change.

net.log('SLMOD INIT: Loading Slmodv' .. tostring(slmod.mainVersion) .. '_' .. slmod.buildVersion .. '...')
do
	local config_dir = lfs.writedir() .. [[Slmod\]]
	
	lfs.mkdir(config_dir)  -- create Slmod config directories, should not over-write current.
	lfs.mkdir(config_dir .. [[Missions\]])
	lfs.mkdir(config_dir .. [[Chat Logs\]])
	lfs.mkdir(config_dir .. [[Mission Stats\]])
	
	-------------------------------------------------------------------------------------
	-- Create Slmod.log
	local logFileLoc = config_dir .. [[Slmod.log]]
	local logFile = io.open(logFileLoc, 'w')
	if logFile then
		logFile:write('Slmod started at ' .. os.date('%b %d, %Y, %H:%M:%S') .. '\n')		
	end
	
	function slmod.error(msg, chat)
		msg = tostring(msg)
		local newMsg = 'SLMOD ERROR: ' .. msg
		net.log(newMsg)
		if chat and slmod.basicChat then
			slmod.basicChat(newMsg)
		end
		if logFile then
			logFile:write(tostring(os.clock()) .. '  ' .. newMsg .. '\n')
			logFile:flush()
		end
	end
	
	function slmod.warning(msg, chat)
		msg = tostring(msg)
		local newMsg = 'SLMOD WARNING: ' .. msg
		net.log(newMsg)
		if chat and slmod.basicChat then
			slmod.basicChat(newMsg)
		end
		if logFile then
			logFile:write(tostring(os.clock()) .. '  ' .. newMsg .. '\n')
			logFile:flush()
		end
	end
	
	function slmod.info(msg, chat)
		msg = tostring(msg)
		local newMsg = 'SLMOD INFO: ' .. msg
		net.log(newMsg)
		if chat and slmod.basicChat then
			slmod.basicChat(newMsg)
		end
		if logFile then
			logFile:write(tostring(os.clock()) .. '  ' .. newMsg .. '\n')
			logFile:flush()
		end
	end
	
	function slmod.closeLog()
		slmod.info('Normal DCS termination at ' .. tostring(os.clock()))
		logFile:close()
	end
	
	-- end of Slmod.log code
	------------------------------------------------------------------------------
	
	--------------------------------------------------------------------------------
	-- Config code
	local function default_settings()
		--lfs.mkdir(config_dir) -- try creating the dir, just to be sure
		local oldf = io.open(config_dir .. 'config.lua', 'r')
		if oldf then
			local old_settings = oldf:read('*all')
			oldf:close()
			oldf = nil
			local new_oldf = io.open(config_dir .. 'configOLD.lua', 'w')
			new_oldf:write(old_settings)
			new_oldf:close()
			new_oldf = nil
		end
		--net.log('here1')
		local newf = io.open(config_dir .. 'config.lua', 'w')
		--net.log('here2')
		local defaultf = io.open(lfs.writedir() .. 'Scripts/net/Slmodv' .. slmod.version .. '/SlmodDefault.cfg', 'r')
		if defaultf and newf then
			local default_settings = defaultf:read('*all')
			defaultf:close()
			defaultf = nil
			newf:write(default_settings)
			newf:close()
			newf = nil
			
			--now load default settings
			local defaultConfigFunc = loadstring(default_settings)
			setfenv(defaultConfigFunc, slmod.config)
			defaultConfigFunc()
			slmod.info('using default config settings.')
			return true
		else
			if newf then
				newf:close()
			end
			if defaultf then
				defaultf:close()
			end
			slmod.error('unable to load or create Slmod default settings!')
			return false
		end
	end
	
	local f = io.open(config_dir .. 'config.lua', 'r')
	if f then -- config already exists
		local config_settings = f:read('*all')
		f:close()
		f = nil
		local config_func, err1 = loadstring(config_settings)
		if config_func then
			setfenv(config_func, slmod.config)
			local bool, err2 = pcall(config_func)
			if not bool then
				slmod.error('unable to load config settings, reason: ' .. tostring(err2))
				default_settings()
			else
				slmod.info('using settings defined in ' .. config_dir .. 'config.lua')
			end
			if slmod.config.configVersion ~= slmod.configVersion then  -- old settings
				slmod.warning('config version is old.  Loading new config version.')
				default_settings()
			end
			
		else
			slmod.error('unable to load config settings, reason: ' .. tostring(err1))
			default_settings()
		end
	else
		slmod.warning('no config file detected.')
		default_settings()
	end
	---------------------------------------------------------------------------------------------------
	
	--Create chat log
	if slmod.config.chat_log then
		slmod.chatLogFile = io.open(config_dir .. [[Chat Logs\]] .. os.date('%b %d, %Y at %H %M %S.txt'), 'w')
	end	
	----------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------
	-- added 058- install MissionScripting.lua
	local curMSf, err = io.open('./Scripts/MissionScripting.lua', 'r')
	if curMSf then
		local slmodMSf, err = io.open(lfs.writedir() .. 'Scripts/net/Slmodv' .. slmod.version .. '/SlmodMissionScripting.lua', 'r')
		if slmodMSf then
			
			local curMS = curMSf:read('*all')
			local slmodMS = slmodMSf:read('*all')
			curMSf:close()
			slmodMSf:close()
			
			local curMSfunc, err = loadstring(curMS)
			if curMSfunc then
				local slmodMSfunc, err = loadstring(slmodMS)
				if slmodMSfunc then
					if string.dump(curMSfunc) ~= string.dump(slmodMSfunc) and curMS ~= slmodMS then  -- attempt installation... the first condition should be enough of a test, but I'm afraid it might be system dependent.
						slmod.warning('./Scripts/MissionScripting.lua is not up to date.  Installing new ./Scripts/MissionScripting.lua.')
						local newMSf, err = io.open('./Scripts/MissionScripting.lua', 'w')
						if newMSf then
							newMSf:write(slmodMS)
							newMSf:close()
						else
							slmod.error('Unable to open ./Scripts/MissionScripting.lua for writing, reason: ' .. tostring(err))
						end
					
					else  -- no installation is required
						slmod.info('./Scripts/MissionScripting.lua is up to date, no installation required.')
						return true
					end		
				else
					slmod.error('Unable to compile ' .. lfs.writedir() .. 'Scripts/net/Slmodv' .. slmod.version .. '/SlmodMissionScripting.lua, reason: ' .. tostring(err))
				end
			else	
				slmod.error('Unable to compile ./Scripts/MissionScripting.lua, reason: ' .. tostring(err))
			end	
		else
			slmod.error('Unable to open ' .. lfs.writedir() .. 'Scripts/net/Slmodv' .. slmod.version .. '/SlmodMissionScripting.lua for reading, reason: ' .. tostring(err))
		end
	else
		slmod.error('Unable to open ./Scripts/MissionScripting.lua for reading, reason: ' .. tostring(err))
	end
	---------------------------------------------------------------------------------------------------------------------------------------
end

slmod.info('SlmodConfig.lua loaded.')