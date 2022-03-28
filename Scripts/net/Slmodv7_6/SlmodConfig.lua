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

slmod.version = '7_6'  -- file directory

slmod.mainVersion = '7_6'  -- so far, these are only used in MOTD and some load scripts.
slmod.buildVersion = '151'  

slmod.configVersion = '28'  -- as new options as are added to SlmodConfig, this will change.

net.log('SLMOD INIT: Loading Slmodv' .. tostring(slmod.mainVersion) .. '_' .. slmod.buildVersion .. '...')
do
	local config_dir = lfs.writedir() .. [[Slmod\]]
	
	lfs.mkdir(config_dir)  -- create Slmod config directories, should not over-write current.
	lfs.mkdir(config_dir .. [[Missions\]])
	lfs.mkdir(config_dir .. [[Chat Logs\]])
	lfs.mkdir(config_dir .. [[Mission Stats\]])
    lfs.mkdir(config_dir .. [[Mission Events\]])
    lfs.mkdir(config_dir .. [[Campaign Stats\]])
	
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
	--[[
        Ok, so this is working fairly ok so far, but there is a new problem!
        
        It is not setting the correct reference for nested tables in the useSettings table. That whole bit of code from for valName, valData to the writeValue needs some changes. 
        
        REMINDER 1: Add saving the config version number with #def.s
        REMINDER 2: Test in pairs iteration. mapStrings is saved as a string key. So I might need to edit writeTbl to support it.
    
    ]]
	--------------------------------------------------------------------------------
	-- Config code
    net.log('Load default file')
    local defF = io.open(lfs.writedir() .. 'Scripts/net/Slmodv' .. slmod.version .. '/SlmodDefault.cfg', 'r')
    local defSettings
    local def = {}
    local oldSet = {}
    local makeFile = true
    local oldPresent = false
    if defF then
        --net.log('Read File')
        defSettings = defF:read('*all')
        defF:close()
        defF = nil

        if defSettings then
        	local defaultConfigFunc, err1 = loadstring(defSettings)
            if defaultConfigFunc then
                setfenv(defaultConfigFunc, def)
                local bool, err2 = pcall(defaultConfigFunc)
                if not bool then
                    net.log(tostring(err2))
                end
                defaultConfigFunc()
            else
                net.log(tostring(err1))
            end
        end
    end
	local function loadConfig(verify)
		--net.log('Load Config')
        --lfs.mkdir(config_dir) -- try creating the dir, just to be sure
		local oldf = io.open(config_dir .. 'config.lua', 'r')
        local curSettings
		-- Make copy of old file. For now always do it. 
        if oldf then
			net.log('old file')
            local old_settings = oldf:read('*all')
            old_settings = string.gsub(old_settings, "= false", "= 'false'")
            old_settings = string.gsub(old_settings, "= nil", "= 'nil'")
            local oldSConfig = loadstring(old_settings)
            setfenv(oldSConfig, oldSet)
            oldSConfig()
			oldf:close()
			oldf = nil
			local new_oldf = io.open(config_dir .. 'configOLD.lua', 'w')
			new_oldf:write(old_settings)
			new_oldf:close()
			new_oldf = nil
            oldPresent = true
		end

		local newF = io.open(config_dir .. 'config.lua', 'w')
		if def and newF then

            local useSetting = {}
            
            local function basicSerialize(val)
                -- net.log('base serialize')
                if type(val) == 'string' and val ~= 'nil'  and val ~= 'false' then
                    return string.format('%q', val)
                else
                    return tostring(val)
                end
            end
            
            local function getSpaces(tab)
                local spaces = ''
                for i = 1, 4 * (tab) do
                    spaces = spaces .. ' '
                end
                return tostring(spaces)
            end
            
            local function validateTbl(nTbl, dTbl, valTypes)
                if type(nTbl) == 'table' then
                    local literallyAnything = false
                    if valTypes then
                        for ind, dat in pairs(nTbl) do
                            literallyAnything = true 
                            if type(dat) == 'table' then 
                                for entry, value in pairs(dat) do
                                    local valid = true
                                    for vName, vType in pairs(valTypes) do
                                        if type(vType) == 'table' then
                                            for i = 1, #vType do
                                                if (vType[i]) ~= type(value) then
                                                    valid = false
                                                end
                                            end
                                        elseif (vType) ~= type(value) then
                                            valid = false
                                        end
                                    end
                                    if valid == false then
                                        if dTbl[ind] and dTbl[ind][entry] then
                                            nTbl[ind][entry] = dTbl[ind][entry]
                                        else
                                            if dTbl[ind] then
                                                nTbl[ind] = dTbl[ind]
                                            else
                                                nTbl[ind] = nil
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if literallyAnything == true then 
                        return nTbl
                    else
                        return dTbl
                    end
                else
                    return nTbl
                end
            end
            
            local function writeTbl(data, tb, prs)

                if type(data) == 'table' then
                    if data[1] then
                        local str = '{\n'
                        for i = 1, #data do
                            str = str .. getSpaces(1) .. '[' .. i .. '] = '
                            if type(data[i]) == 'table' then
                                str = str .. '{'
                                for vName, vEntry in pairs(data[i]) do
                                    str = str .. vName .. ' = ' .. basicSerialize(vEntry) .. ', '
                                end
                                str = str .. '},\n'
                            else
                               str = str .. basicSerialize(data[i])
                            end
                        
                        end
                        str = str .. '\n}'
                        return str
                    else
                        if prs then
                            local str = '{\n'
                            for name, val in pairs(data) do
                                str = str .. getSpaces(1) .. '[' .. basicSerialize(name) .. '] = '
                                str = str .. basicSerialize(val) .. ',\n'
                            end
                            str = str .. '\n}\n'
                            return str
                        else                        
                            return  '{}\n'                     
                        end
                      
                    end
                end
               
            end
            
     
            for i = 1, #def.s do
                --net.log('index: ' .. i)
                local entry = def.s[i]

                
                if entry.help then 
                    --net.log('write help')

                    newF:write(tostring('--[['))
                    --net.log(entry.help)
                    newF:write(tostring(entry.help))
                    newF:write(tostring(']]\n'))
                end
                if entry.helpSpec then
                    newF:write(tostring('--[=['))
                    newF:write(tostring(entry.helpSpec))
                    newF:write(tostring(']=]\n'))
                end
                if entry.val then
                    --net.log('check val')
                    for valName, valData in pairs(entry.val) do
                        --net.log('valName: ' .. valName)
                        --net.log('New Type: ' .. type(valData))
                        local oldRef = oldSet
                        local uSet -- 
                        local lSet -- old/default setting value
                        --[[
                            oldRef is a local instance of oldSet, so it is problematic that I am re-writing that value. 
                            Make lRef only the reference to it then and modify that?
                        
                        ]]
                        if entry.nest then
                            for i = 1, #entry.nest do
                                --net.log(entry.nest[i])
                                if oldRef[entry.nest[i]] then
                                    oldRef = oldRef[entry.nest[i]]
                                end
                            end
                            --lRef = entry.nest[#entry.nest]

                            lSet = oldRef[valName]
                            
                        else
                            lSet = oldSet[valName]
                        end
                        
                        if lSet then
                            --net.log('check old setting')
                            if type(lSet) == 'string' and (lSet == 'false' or lSet == 'nil') then -- exception created for false/nil due to loadstring deleting the entries on compile
                                --net.log('lSet is string: ' .. lSet)
                                if lSet == 'nil' then
                                    uSet = nil
                                else
                                    uSet = false
                                    if type(valData) ~= 'boolean' then
                                         uSet = valData
                                    end
                                end
                            else
                              --  net.log(tostring((lSet)))
                                if type(valData) == type(lSet) and not entry.root then
                                   -- net.log('check')
                                    uSet = validateTbl(lSet, valData, entry.ver)
                                else
                                    uSet = valData
                                end
                            end

                            --net.log('Old setting')
                        else
                            --net.log('Use New Setting')
                            if type(valData) == 'string' and (valData == 'false' or valData == 'nil') then
                                if valData == 'false' then
                                    uSet = false
                                else
                                    uSet = nil
                                end
                            
                            else
                                uSet = valData
                            end
                           -- net.log('assigned')
                        end
                        local writeValue = ''
                        if entry.tab then
                          --   net.log('get tab')
                              writeValue = writeValue .. getSpaces(entry.tab)
                        end
                        if entry.nest then
                          --  net.log('get nest')
                            local index = {}
                            local sRef = useSetting
                            for i = 1, #entry.nest do
                                writeValue = writeValue .. entry.nest[i] .. '.'
                                if sRef[entry.nest[i]] then
                                    sRef = sRef[entry.nest[i]]
                                end
                               
                            end
                            sRef[valName] = uSet
                        else
                            useSetting[valName] = uSet
                        end
                        --net.log('check type')
                        if type(uSet) == 'table' then
                             --net.log('tbl')
                            writeValue = writeValue .. valName .. ' = ' .. writeTbl(uSet, entry.tab, entry.prs)
                        else
                           -- net.log('else')
                           -- net.log(uSet)
                            writeValue = writeValue .. valName .. ' = ' .. basicSerialize(uSet) .. '\n\n'
                        end
                        newF:write(writeValue)
                        
                    end
                
                end
                
            end
            newF:write([[------------------------------------------------------------------------------------------------------------------------
-- Config version, only change this to force the config to be rechecked/rewritten!]])
            newF:write('\nconfigVersion = ' .. #def.s)

			--newf:write(default_settings)
			newF:close()
			newF = nil
			
			--now load default settings
            --net.log('check values')
            for vName, v in pairs(useSetting) do
                --net.log(vName)
                if type(v) == 'table' then
                    --net.log(vName .. ' is a table')
                    for tVal, tEntry in pairs(v) do
                       --net.log(tVal)
                        if type(tEntry) ~= 'table' then
                           net.log(tVal .. ' : ' .. tostring(tEntry))
                        end
                    end
                else
                     net.log(v)
                end
            end
            --net.log('fenv config')
			if not slmod.config then
                --net.log('no slmod.config, setfenv')
                setfenv(useSetting, slmod.config)
            else
                --net.log('slmod.config exists')
                slmod.config = useSetting
            end
            --net.log('double check')
            
			slmod.info('using default config settings.')
			return true
		else
			if newF then
				newF:close()
			end
			if defaultf then
				defaultf:close()
			end
			slmod.error('unable to load or create Slmod default settings!')
			return false
		end
	end
	--net.log('open config')
	local f = io.open(config_dir .. 'config.lua', 'r')
	local check = true
    local verify
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
			else
				slmod.info('using settings defined in ' .. config_dir .. 'config.lua')
                check = false
			end
			if def and def.configVersion and slmod.config.configVersion ~= def.configVersion then  -- old settings
				slmod.warning('config version is old.  Loading new config version.')
                check = true
                verify = true
			end
			
		else
			slmod.error('unable to load config settings, reason: ' .. tostring(err1))
		end
	else
		slmod.warning('no config file detected.')
	end
    if check == true then
        loadConfig(verify)
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