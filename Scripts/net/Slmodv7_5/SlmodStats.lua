slmod.stats = slmod.stats or {}  -- make table anyway, need it.
do
    -------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- stats file initialization
	local statsDir = slmod.config.stats_dir or lfs.writedir() .. [[Slmod\]]
	
	local stats -- server stats, nil at first.
    --local metaStats
	------------------------------------------------------------------------------------------
	-- new slmod.stats.resetStatsFile function.
	local statsF -- stats file handle; upvalue of slmod.stats.resetStatsFile.
    local metaStatsF -- metaStats file handle

    
    local misStats = {}-- by-mission stats
    local misStatsF  -- mission stats file
    
    local penStats -- penalty stats
    local penStatsF -- penalty stats file
    
    local missionStatsDir = slmod.config.mission_stats_files_dir or lfs.writedir() .. [[Slmod\Mission Stats\]]
    if missionStatsDir:sub(missionStatsDir:len(), missionStatsDir:len()) ~= '\\' and missionStatsDir:sub(missionStatsDir:len(), missionStatsDir:len()) ~= '/' then
        missionStatsDir = missionStatsDir .. '\\'
    end
	-- new, reloadStats method
	--slmod.info('do reset')
	--slmod.stats.resetStatsFile()  -- load stats from file.
	-------------------------------------------------------------------------------------------------------
    -- NEW NEW write file code
	-------------------------------------------------------------------------------------------------------
    slmod.stats.resetFile = function (l, f) -- 
        local fileF
        local fileName
        local lName = ''
        local lstatsDir = statsDir
        local statData
        local envName = 'stats'
        if l == 'mission' then
            fileF = misStatsF
            if f then
                fileName = '\\' .. f
            end
            lstatsDir = missionStatsDir
            envName = 'misStats'
        elseif l == 'meta' then
            --slmod.info('meta')
            fileName = '\\SlmodMetaStats.lua'
            lName = 'SlmodMetaStats.lua'
            envName = 'metaStats'
            statData = metaStats
        elseif l == 'penalty' then
            --slmod.info('meta')
            fileName = '\\SlmodPenaltyStats.lua'
            lName = 'SlmodPenaltyStats.lua'
            envName = 'penStats'
            statData = penStats   
            fileF = penStatsF
        else
           -- slmod.info('stats')
            fileF = statsF
            fileName = '\\SlmodStats.lua'
            lName = 'SlmodStats.lua'
            statData = stats
        end
        
        
		if fileF then -- if statsF upvalue already open...
			fileF:close()
			fileF = nil
		end
		local function makeBackup(s)
            fileName = string.gsub(fileName, '.lua', '_BACKUP.lua') -- append backup to file
			local statsBackup = io.open(lstatsDir .. fileName, 'w')
			if statsBackup then
				statsBackup:write(s)
				statsBackup:close()
				slmod.info('old ' .. lName .. ' file backed up to ' .. lstatsDir .. fileName)
			else
				slmod.error('Unable to create stats backup file, could not open file: ' .. lstatsDir .. fileName)
			end
		
		end

		if not statData then  -- only loads stats when the server is started.
			slmod.info('no ' .. envName .. ' , loading from file: ' .. lstatsDir .. fileName)
			
            local prevStatsF = io.open(lstatsDir .. fileName, 'r')
			if prevStatsF then
				--slmod.info('prevStatsF')
                local statsS = prevStatsF:read('*all')
               -- slmod.info(slmod.oneLineSerialize(statsS))
				local statsFunc, err1 = loadstring(statsS)
				prevStatsF:close()
                --slmod.info('prevStatsF Close')
				if statsFunc then
					--slmod.info('doing env')
                    local env = {}
					setfenv(statsFunc, env)
					local bool, err2 = pcall(statsFunc)
					--slmod.info('if not bool')
                    if not bool then
						slmod.error('unable to load Stats, reason: ' .. tostring(err2))
						makeBackup(statsS)
					else
                        if env[envName] then
							slmod.info('using '.. lName .. ' as defined in ' .. lstatsDir .. lName)
                            statData = env[envName]
						else
                            slmod.info('no table in file ' .. lstatsDir .. lName)
							makeBackup(statsS)
						end
					end
				else
					slmod.error('unable to load ' ..  lName ..' , reason: ' .. tostring(err1))
					makeBackup(statsS)
				end
				
			else
                if f then 
                    slmod.info('Old Mission Stat file doesnt exist')
                    return
                end
                slmod.warning('Unable to open ' .. lName .. ' , will make a new ' .. lName .. ' file.')	
			end
		end
        if not statData then
            statData = {}
        end
        if l == 'meta' then
            local newStatsS = slmod.serialize('metaStats', statData) ..'\n'
            fileF = io.open(lstatsDir .. fileName, 'w')
            fileF:write(newStatsS)
            --fileF:close()
           -- fileF = nil -- close meta stats so it can be written elsewhere
        elseif l == 'mission' then
            local newStatsS = slmod.serialize('misStats', statData) ..'\n'
            --if f or slmod.config.enable_mission_stats then 
                fileF = io.open(lstatsDir .. fileName, 'w')
                fileF:write(newStatsS)
                fileF:close()
           -- end
            fileF = nil
            
        elseif l == 'penalty' then
            local newStatsS = slmod.serialize('penStats', statData) ..'\n'
            penStatsF = io.open(lstatsDir .. fileName, 'w')
            penStatsF:write(newStatsS)
        elseif not l then
            --Now, stats should be opened, or if not run, at least backed up..  Now, write over the old stats and return a file handle.
            local newStatsS = slmod.serialize('stats', statData) ..'\n'
            statsF = io.open(lstatsDir .. fileName, 'w')
            statsF:write(newStatsS)
        end
        
        return statData, fileF
	end
    stats = slmod.stats.resetFile()
    penStats = slmod.stats.resetFile('penalty')
    local statWrites = 0
    local function recompileStats()
        --slmod.info('recompile stats')
        stats = slmod.stats.resetFile()
        statWrites = 0    
    end
    
	-------------------------------------------------------------------------------------------------------
	-- Create statsTableKeys database
    local statsTableKeys = {}  -- stores strings that corresponds to table indexes within stats... needed for updating file.
	statsTableKeys[stats] = 'stats'
	do
		local function makeStatsTableKeys(levelKey, t)
            for key, val in pairs(t) do
                if type(val) == 'table' and type(key) == 'string' then
					key = levelKey .. '[' .. slmod.basicSerialize(key) .. ']'
					statsTableKeys[val] = key  -- works because each table only exists once in Slmod stats- it's REQUIRED!!! DO NOT FORGET THIS!
                    --slmod.info(slmod.basicSerialize(val) .. ' : ' .. key)
					makeStatsTableKeys(key, val)
				end
			end
		end
		
		makeStatsTableKeys('stats', stats)
	end	
	------------------------------------------------------------------------------------------------------

    ----------------
	-- call this function each time a value in stats needs to be changed... 
    -- For all root entries for a player and changing actual values by advChangeStatsValue
	-- t: the table in stats that this value belongs under
    function slmod.stats.changeStatsValue(t, key, newValue)
        if not t then
			slmod.error('Invalue stats table specified!')
			return
        end
        if type(newValue) == 'table' then
            statsTableKeys[newValue] = statsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']'
        end	
        t[key] = newValue
        local statsChangeString = statsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. '] = ' .. slmod.oneLineSerialize(newValue) .. '\n'
        statsF:write(statsChangeString)
        statWrites = statWrites + 1
        if statWrites > 1000 then
            recompileStats()
        end
		--slmod.info(statsChangeString)
        --testWrite()
	end
    
    --[[AdvancedChangeStatsValue()
    New function meant to simplify how stats are added amoung multiple files and multicrew aircraft. 
    - Changes stats for multiple users in the same aircraft at the same time without having to do a whole set of code twice
    - Writes to stats, misStats, and anything else at the same time.
    
    ucid: string or table of UCID strings that stat is to apply to
    nest: string or table of strings where table index that is to be written to. Use string 'typeName' to tell code to change the value to the actual typename for the passed players. 
    addValue: Value that is added. Accepts table or single value as string/number. 
    setValue: Sets To this value. Note: Does not accept tables, sets value to highest nest table entry. 
    insert: Inserts the entry to the table
    default: if no value present then use that. Meant for creating table entries that are missing. If not present defaults to empty table {}
    typeName: Table matching ucid table indexes. For multicrew stats. 
    penalty: Add to Penalty stats
    
    
    Sample. Ejections can be added multiple ways. 
    {nest = {'times', 'typeName', 'actions', 'losses', 'eject'}, addValue = 1}
    {nest = {'times', 'typeName', 'actions', 'losses'}, addValue = {eject = 1}}
    ]]
	
    function slmod.stats.advChangeStatsValue(vars)
        --slmod.info(slmod.oneLineSerialize(vars))
        local useUcid = {}
        local nest = vars.nest
        local addValue = vars.addValue
        local default = vars.default
        local typeName = vars.typeName
        if type(vars.ucid) == 'string' then -- can accept a string or multiple ucid to apply stat to
            useUcid[1] = vars.ucid
        else
            useUcid = vars.ucid
        end
        for j = 1, #useUcid do
            if stats[useUcid[j]] then
                local lStats = stats[useUcid[j]]
                if vars.penalty then -- add to penalty stats file
                    if not penStats[useUcid[j]] then -- create user pen stats
                        --slmod.info('create Pen stats')
                        slmod.stats.createPlayerPenaltyStats(useUcid[j], true)
                    end
                    slmod.stats.changePenStatsValue(penStats[useUcid[j]][nest], #penStats[useUcid[j]][nest] + 1, addValue)
                else
                    local mStats = misStats[useUcid[j]]
                    local lEntry = nest
                    local mEntry = slmod.deepcopy(nest)
                    if type(nest) == 'table' then -- nest can be a string for root level or table for nested levels
                        for i = 1, #nest - 1 do
                            --slmod.info(i .. ' ' .. lEntry[i])
                            if lEntry[i] == 'typeName' and typeName then
                                lEntry[i] = typeName[j]
                                mEntry[i] = typeName[j]
                            end
                            if not lStats[lEntry[i]] then
                                slmod.stats.changeStatsValue(lStats, lEntry[i], {})
                            end
                            lStats = lStats[lEntry[i]]
                            if slmod.config.enable_mission_stats then
                                if not mStats[mEntry[i]] then
                                    slmod.stats.changeMisStatsValue(mStats, mEntry[i], {})
                                end  
                                mStats = mStats[mEntry[i]]
                            end
                        end
                        lEntry = lEntry[#lEntry]
                        mEntry = mEntry[#mEntry]
                    end
                    if not lStats[lEntry] then -- if this table is not there, then it needs to create it!
                        slmod.stats.changeStatsValue(lStats, lEntry, default or {})

                    else
                        --slmod.info(lEntry .. ' exists')
                    end
                    
                    if slmod.config.enable_mission_stats then
                        if not mStats[mEntry] then 
                            local mDefault
                            if default then 
                                mDefault = slmod.deepcopy(default)
                            end
                            slmod.stats.changeMisStatsValue(mStats, mEntry, mDefault or {})
                        end
                        -- insert code to create it in mission stats here because if it doesnt exist in main stats then it doesn't exist in mission stats
                    end
                    if addValue then 
                        if type(addValue) == 'table' then 
                            for index, value in pairs(addValue) do
                                if lStats[lEntry][index] then
                                    --slmod.info('val is ' .. lStats[lEntry][index])
                                    slmod.stats.changeStatsValue(lStats[lEntry], index, lStats[lEntry][index] + value)
                                end
                                if slmod.config.enable_mission_stats then
                                    if mStats[mEntry][index] then 
                                        --slmod.info('mval is ' .. mStats[mEntry][index])
                                        slmod.stats.changeMisStatsValue(mStats[mEntry], index, mStats[mEntry][index] + value)
                                    end
                                end
                            end
                        else    
                            --slmod.info(addValue .. ' is added to single val ' .. lEntry)
                            slmod.stats.changeStatsValue(lStats, lEntry, lStats[lEntry] + addValue)
                            if  slmod.config.enable_mission_stats then 
                                slmod.stats.changeMisStatsValue(mStats, mEntry, mStats[mEntry] + addValue)
                            end
                        end
                    end
                    if vars.setValue then -- change one and only one value to this. 
                        slmod.stats.changeStatsValue(lStats, lEntry, vars.setValue)
                        if  slmod.config.enable_mission_stats then 
                            slmod.stats.changeMisStatsValue(mStats, mEntry, vars.setValue)
                        end
                    end
                    if vars.insert then
                        slmod.stats.changeStatsValue(lStats[lEntry], #lStats[lEntry] + 1, vars.insert)
                        if  slmod.config.enable_mission_stats then 
                            slmod.stats.changeMisStatsValue(mStats[mEntry], #mStats[mEntry] + 1, vars.insert)
                        end
                    end
                end
            end

        end
        --slmod.info('end adv write')
        return
    end
      
   	--------------------------------------------------------------------------------------------------
	-- Create the nextIdNum variable, so stats knows the next stats ID number it can use for a new player.
	local nextIDNum = 1
	local pIds = {}
    local function getNextId()
        
        while pIds[nextIDNum] do
            nextIDNum = nextIDNum + 1
        end
        return nextIDNum
    end    
    
	for ucid, entry in pairs(stats) do  -- gets the next free ID num. But also adds all of the Ids to a list indexed by Id. 
		pIds[entry.id] = ucid
	end
    -- and because it is possible for stats to be deleted and penStats to be kept. Iterate penStats just in case. 
    for ucid, entry in pairs(penStats) do
        pIds[entry.id] = ucid
    end

    	-- function called to add a new player to SlmodStats.
	local function createMisStatsPlayer(ucid)  -- call AFTER the regular stats createNewPlayer.
        local pStats = stats[ucid]
		if not pStats then
			slmod.error('Mission Stats: player (ucid = ' .. tostring(ucid) .. ') does not exist in regular stats!')
		else
			slmod.stats.changeMisStatsValue(misStats, ucid, {})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'names', slmod.deepcopy(pStats.names))
			slmod.stats.changeMisStatsValue(misStats[ucid], 'id', pStats.id)
			slmod.stats.changeMisStatsValue(misStats[ucid], 'times', {})
		end
 	end
   	---------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------
	-- function called to add a new player to SlmodStats.
	local function createNewPlayer(ucid, name, cMizStat) 
        slmod.stats.changeStatsValue(stats, ucid, {}) -- use original to write it
        if penStats[ucid] then -- player existed before in penstats. So re-assign them their initial data
            slmod.stats.changeStatsValue(stats[ucid], 'names', penStats[ucid].names)
            slmod.stats.changeStatsValue(stats[ucid], 'id', penStats[ucid].id)
            slmod.stats.changeStatsValue(stats[ucid], 'joinDate', penStats[ucid].joinDate)   
        else
            slmod.stats.changeStatsValue(stats[ucid], 'names', { [1] = name })
            slmod.stats.changeStatsValue(stats[ucid], 'id', getNextId())
            slmod.stats.changeStatsValue(stats[ucid], 'joinDate', os.time())
        end
		
        pIds[stats[ucid].id] = ucid
        
		slmod.stats.changeStatsValue(stats[ucid], 'times', {})
        
        if slmod.config.enable_mission_stats and cMizStat then
            createMisStatsPlayer(ucid)
        end

	end
    
    
    --- new function to create the penalty stats for a player
    local statCleanupTbls = {'friendlyHits', 'friendlyKills', 'friendlyCollisionHits', 'friendlyCollisionKills'}
    function slmod.stats.createPlayerPenaltyStats(ucid, forced)
        local lStats = stats[ucid]
        
        local anyPens = false
        if lStats.friendlyKills then 
            for i = 1, #statCleanupTbls do
                if lStats[statCleanupTbls[i]] and #lStats[statCleanupTbls[i]] > 0 then
                    anyPens = true
                end
            end
        end
        -- create default stats
        if anyPens == true or forced == true then 
            slmod.stats.changePenStatsValue(penStats,ucid, {}) -- use old method because I don't care. 
            slmod.stats.changePenStatsValue(penStats[ucid], 'id' , lStats.id)
            slmod.stats.changePenStatsValue(penStats[ucid], 'names' , slmod.deepcopy(lStats.names))
            slmod.stats.changePenStatsValue(penStats[ucid], 'joinDate' , os.time())
            slmod.stats.changePenStatsValue(penStats[ucid], 'friendlyKills', {})
            slmod.stats.changePenStatsValue(penStats[ucid], 'friendlyHits', {})
            slmod.stats.changePenStatsValue(penStats[ucid], 'friendlyCollisionHits', {})
            slmod.stats.changePenStatsValue(penStats[ucid], 'friendlyCollisionKills', {})
        end
        -- cleanup for old stats if needed
        if lStats.numTimesAutoBanned then
             slmod.stats.changePenStatsValue(penStats[ucid], 'numTimesAutoBanned', lStats.numTimesAutoBanned)
        end
        if lStats.autobanned then
            slmod.stats.changePenStatsValue(penStats[ucid], 'autobanned', lStats.autobanned)
        end 
        
        local joinDate = lStats.joinDate or os.time()
        if anyPens == true then 
            
            for index, cleanup in pairs(statCleanupTbls) do
                for p = 1, #lStats[cleanup] do
                    if lStats[cleanup][p].time < joinDate then
                        joinDate =  lStats[cleanup][p].time 
                    end
                    slmod.stats.changePenStatsValue(penStats[ucid][cleanup], #penStats[ucid][cleanup]+1, lStats[cleanup][p])
                end
            end
            slmod.stats.changePenStatsValue(penStats[ucid], 'joinDate' , joinDate)        

        end
        if not stats[ucid].joinDate then -- just in case this creates it for existing users if cleanup is never run. 
            slmod.stats.changeStatsValue(stats[ucid], 'joinDate', joinDate)
        end
        for i = 1, #statCleanupTbls do -- erase team kill info from normal stats
            if stats[ucid][statCleanupTbls[i]] then 
                slmod.stats.changeStatsValue(stats[ucid], statCleanupTbls[i], nil)
            end
        end
    
    end
	---------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-- Interlude: **BEGINNING OF MISSION STATS**
	-- needs to be up here for upvalues to be seen by lower functions.
	
  	local misStatFileName 
	-------------------------------------------------------------------------------------------------------
	-- Create misStatsTableKeys database
	local misStatsTableKeys = {}  -- stores strings that corresponds to table indexes within misStats... needed for updating file.
	misStatsTableKeys[misStats] = 'misStats'

	-- call this function each time a value in stats needs to be changed...
	-- t: the table in misStats that this value belongs under
    function slmod.stats.changeMisStatsValue(t, key, newValue)
        --slmod.info('write miz stat')
        if not t then
			slmod.error('Invalid misStats table specified!')
			return
        end

        if type(newValue) == 'table' then
            misStatsTableKeys[newValue] = misStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']'
        end	
        t[key] = newValue
        if misStatsF then
            local misStatsChangeString = misStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. '] = ' .. slmod.oneLineSerialize(newValue) .. '\n'
            misStatsF:write(misStatsChangeString)
           -- slmod.info(misStatsChangeString)
        end
        
	end
	---------------------------------------------------------------------------------------------------

	---------------------------------------------------------------------------------------------------------------------
    local penStatsTableKeys = {}  -- stores strings that corresponds to table indexes within penStats... needed for updating file.
	penStatsTableKeys[penStats] = 'penStats'
	do
		local function makeStatsTableKeys(levelKey, t)
            for key, val in pairs(t) do
                if type(val) == 'table' and (type(key) == 'string' or type(key) == 'number') then
					key = levelKey .. '[' .. slmod.basicSerialize(key) .. ']'
					penStatsTableKeys[val] = key  -- works because each table only exists once in Slmod stats- it's REQUIRED!!! DO NOT FORGET THIS!
                    --slmod.info(slmod.basicSerialize(val) .. ' : ' .. key)
					makeStatsTableKeys(key, val)
				end
			end
		end
		
		makeStatsTableKeys('penStats', penStats)
	end	
	-- call this function each time a value in stats needs to be changed...
	-- t: the table in penStats that this value belongs under
    function slmod.stats.changePenStatsValue(t, key, newValue)
        if not t then
			slmod.error('Invalid pen table specified!')
			return
        end

        if type(newValue) == 'table' then
            penStatsTableKeys[newValue] = penStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']'
        end	
        t[key] = newValue
        if penStatsF then
            local penStatsChangeString = penStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. '] = ' .. slmod.oneLineSerialize(newValue) .. '\n'
            penStatsF:write(penStatsChangeString)
            --slmod.info(penStatsChangeString)
        end
        
	end
	-----------------------------------------------------------------------------------------------------
	function slmod.stats.onMission()  -- for creating per-mission stats.
         local err  -- misStatsF already local
        local missionName = 'UNKNOWN MISSION'
        if slmod.current_mission then
            local strInd = slmod.current_mission:len()
            while strInd > 1 do
                local char = slmod.current_mission:sub(strInd, strInd)
                if char == '\\' or char == '/' then
                    strInd = strInd + 1
                    break
                end	
                strInd = strInd - 1
            end
            missionName = slmod.current_mission:sub(strInd, slmod.current_mission:len())
        end

        misStatFileName = (missionName .. '- ' .. os.date('%b %d, %Y at %H %M %S.lua'))
        slmod.stats.updateMetaMapInfo(misStatFileName)
        if slmod.config.enable_mission_stats then
            if slmod.config.write_mission_stats_files then
                if misStatsF then  -- close if open from previous.
                    misStatsF:close()
					misStatsF = nil
				end
                misStatsF, err = io.open(missionStatsDir .. misStatFileName, 'w')
				if not misStatsF then
					slmod.error('Mission stats: unable to open '  .. lfs.writedir() .. [[Slmod\Mission Stats\]] .. missionName .. '- ' .. os.date('%b %d, %Y at %H %M %S.lua') .. ' for writing, reason: ' .. tostring(err))
				else
					misStatsF:write('misStats = { }\n')
				end
			end
			for ind, val in pairs(misStats) do  -- erases all entries while keeping old reference valid... maybe could have gotten away with redefining though.
				misStats[ind] = nil
			end
			for ind, val in pairs(misStatsTableKeys) do  -- erases all entries while keeping old reference valid... maybe could have gotten away with redefining though.
				misStatsTableKeys[ind] = nil
			end
			
			misStatsTableKeys[misStats] = 'misStats'

			--misStats = {} -- reset the table.. may need to manually erase all entries though- otherwise, old references could still exist.
			for id, client in pairs(slmod.clients) do  -- add all clients to the missionStats table.
                if (slmod.config.host_ucid and id == 1) or id ~= 1 then -- only create mission stats for each player or host if specified 
                    createMisStatsPlayer(client.ucid) 
                end
			end
		end
  	end
	-- **END OF MISSION STATS**
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-- Resuming regular server stats code.
	
	---------------------------------------------------------------------------------------------------------------------
	-- Create entry for server host if necessary.
	if (slmod.config.host_ucid and not stats[slmod.config.host_ucid]) or ((not slmod.config.host_ucid) and (not stats['host'])) then -- if the host isn't in stats...
		local name = slmod.config.host_name or 'host'
		local ucid = slmod.config.host_ucid or 'host'
		createNewPlayer(ucid, name)
	end
	----------------------------------------------------------------------------------------------------------------------
	
	---------------------------------------------------------------------------------------------------------
	--player SWITCHES unit.  Used for detecting desertion under fire 
	local function onSwitchUnit(id, oldUnitRtId)  
	
	end
	
	function slmod.stats.onSetUnit(id)
		if not id then
			slmod.error('slmod.stats.onSetUnit(id): client has no id!!!')
			return
		end
		if slmod.clients[id].rtid then  -- client had an old rtid
			onSwitchUnit(id, slmod.clients[id].rtid)
		end
		local ucid = slmod.clients[id].ucid
		local name = slmod.clients[id].name
		
		if ucid and name then
		
			local newStatsNames  -- moved to this scope so that misStats has access.
			local newName
			
			if not stats[ucid] then
                createNewPlayer(ucid, name, true)
			else  -- check to see if name matches	
				if slmod.config.enable_mission_stats and not misStats[ucid] then  -- should be true in cases where stats check was true... but wait till after names has been updated.
                    createMisStatsPlayer(ucid)
                end
                local nameFound, nameInd
				for i = 1, #stats[ucid].names do
					if stats[ucid].names[i] == name then
						nameFound = true
						nameInd = i
						break
					end
				end
				local save = {nest = 'names', ucid = ucid}
				if nameFound and nameInd ~= #stats[ucid].names then  -- name was previously used but is not the last one in the names table..
                    newStatsNames = {}
					newStatsNames = slmod.deepcopy(stats[ucid].names)
					table.remove(newStatsNames, nameInd)  -- resort
					newStatsNames[#stats[ucid].names] = name
                    save.setValue = newStatsNames
				elseif not nameFound then  -- a new name.
                    save.insert = name
					newName = true
				end
                
                slmod.stats.advChangeStatsValue(save)
			end
			
			if penStats[ucid] then
				if newName then -- update penalty stats with new names too if it exists. 
					slmod.stats.changePenStatsValue(penStats[ucid].names, #penStats[ucid].names + 1, name)  -- update misStats table.
				elseif newStatsNames then
					slmod.stats.changePenStatsValue(penStats[ucid], 'names', newStatsNames)  -- update misStats table.
				end
			end
            
            slmod.stats.advChangeStatsValue({ucid = ucid, default = 0, setValue = os.time(), nest = 'lastJoin'})
			
		end
	end
	
	local function is_BC(name)
		local BC_names = {'artillery_commander_blue_', 'instructor_blue_', 'forward_observer_blue_', 'observer_blue_', 'artillery_commander_red_', 'instructor_red_', 'forward_observer_red_', 'observer_red_' } -- fill with the names for all battle commander slots.
		if type(name) == 'string' and name ~= '' then
			for ind, BC_name in pairs(BC_names) do
				if name:find(BC_name) then
					return true
				end
			end
		end
		return false
	end
		
	function slmod.stats.createGetStatsUnitInfo()
		local getStatsUnitInfoString = [[--slmod.getStatsUnitInfo
slmod = slmod or {}
function slmod.getStatsUnitInfo(unitName)
	local unit = Unit.getByName(unitName)
	if unit then
		return tostring(unit:inAir()) .. ' ' .. tostring(unit:getTypeName())
	end
end]]
		local str, err = net.dostring_in('server', getStatsUnitInfoString)
	end
	
	local clusterBombs = {}
	-- nine cluster bombs I know of, with seven submunition types.
	clusterBombs["BL-755"] = { name = "BL-755", sub = {"HEAT"}}
	clusterBombs["BL_755"] = { name = "BL_755", sub = {"HEAT"}}
	
	clusterBombs["ROCKEYE"] = { name = "Mk-20 Rockeye", sub = {"Mk 118", "Mk-118", "Mk_118"}}
	clusterBombs["Mk-20"] = clusterBombs["ROCKEYE"]
	clusterBombs["Mk_20"] = clusterBombs["ROCKEYE"]
	
	clusterBombs["CBU-97"] = { name = 'CBU-97/CBU-105 SFW', sub = {'BLU-108', 'BLU_108', "BLU-108B", "BLU_108B"}}
	clusterBombs["CBU-105"] = clusterBombs["CBU-97"]
	clusterBombs["CBU_97"] = clusterBombs["CBU-97"]
	clusterBombs["CBU_105"] = clusterBombs["CBU-97"]
	
	clusterBombs["CBU-87"] = { name = 'CBU-87/CBU-103 CEM', sub = {'BLU-97', 'BLU_97', "BLU-97B", "BLU_97B"}}
	clusterBombs["CBU-103"] = clusterBombs["CBU-87"]
	clusterBombs["CBU_87"] = clusterBombs["CBU-87"]
	clusterBombs["CBU_103"] = clusterBombs["CBU-87"]
	
	clusterBombs["RBK-500 PTAB-10"] = { name = "RBK-500 PTAB-10", sub = {"PTAB-10-5", "PTAB_10_5"}}
	clusterBombs["RBK_500 PTAB_10"] = clusterBombs["RBK-500 PTAB-10"]
	clusterBombs["RBK_500"] = clusterBombs["RBK-500 PTAB-10"]
	clusterBombs["RBK-500"] = clusterBombs["RBK-500 PTAB-10"]
	
	clusterBombs["RBK-500U PTAB-1M"] = { name = "RBK-500U PTAB-1M", sub = {"PTAB-1M", "PTAB_1M"}}
	clusterBombs["RBK_500U PTAB_1M"] = clusterBombs["RBK-500U PTAB-1M"]
	clusterBombs["RBK_500U"] = clusterBombs["RBK-500U PTAB-1M"]
	clusterBombs["RBK-500U"] = clusterBombs["RBK-500U PTAB-1M"]
	
	clusterBombs["RBK-250"] = { name = "RBK-250", sub = {"PTAB-2-5", "PTAB_2_5"}}
	clusterBombs["RBK_250"] = clusterBombs["RBK-250"]
	
	local subToCluster = {}  -- cluster bomb names indexed by submunition name.
	for typeName, clusterData in pairs(clusterBombs) do
		for ind, subTypeName in pairs(clusterData.sub) do
			subToCluster[subTypeName] = clusterData.name
		end
	end
	
	-----------------------------------------------------------------------
	--- Code for filtering out multiple cluster bomb hits on the same unit.
	local clusterHits = {}
	
	
	local function filterClusterHits(wpnName, initName, tgtName, time)
		if clusterHits[wpnName] and clusterHits[wpnName][initName] and clusterHits[wpnName][initName][tgtName] then  -- if a cluster hit by this unit has been registered on this target
			if clusterHits[wpnName][initName][tgtName] > (time - 8) then   -- if the cluster impact occurred within 8 seconds of the last one
				return false
			else  -- cluster bomb hit against this target later than 8 seconds after the last, reset the time, and count this hit.
				clusterHits[wpnName][initName][tgtName] = time
				return true
			end
		else  -- add a cluster hit for this bomb/initiator/target, count this hit.
			clusterHits[wpnName] = clusterHits[wpnName] or {}
			clusterHits[wpnName][initName] = clusterHits[wpnName][initName] or {}
			clusterHits[wpnName][initName][tgtName] = time
			return true
		end
	end
	-------------------------------------------------------------------------
	
	
	-------------------------------------------------------------------
	-- Tracking weapons.  Useful to get hits and numHits.
	--[[ If a weapon fired by a player hits something:
		if its ID exists in the trackedWeapons table, then remove from tracked weapons table, and increment "numHits" and "hit".
		If its ID does NOT exist in the trackedWeapons table, just increment numHits.
		Allows analysis of per-launch hit accuracy.
	
	]]
	local trackedWeapons = {}
	
	function slmod.stats.create_weaponIsActive()  -- ONLY use this to track non-shells- too slow for hundreds of objects.
		local weaponIsActiveString = [[--slmod.weaponIsActive
slmod = slmod or {}
function slmod.weaponIsActive(weaponID) 
	return tostring(Unit.isExist({id_ = weaponID}))
end]]
	
		net.dostring_in('server', weaponIsActiveString)
	
	end
	
	
	local function weaponIsActive(weaponID)
		local str, err = net.dostring_in('server', table.concat({'return slmod.weaponIsActive(',  tostring(weaponID), ')'}))
		if type(str) == 'string' and str == 'true' then
			return true
		end
		return false
	end
	
	function slmod.stats.updateStatsTrackedWeapons()  -- call this every second or so, cleans out tracked weapons.
		for ind, id in pairs(trackedWeapons) do
			if not weaponIsActive(id) then
				trackedWeapons[ind] = nil
			end
		end
	end
    
    ------------
    local multiCrewDefs = {}
	multiCrewDefs['F-14A'] = {[2] = 'RIO'}
    multiCrewDefs['F-14B'] = {[2] = 'RIO'}
	multiCrewDefs['Mi-8MT'] = {[2] = 'Copilot', [3] = 'FO', [4] = 'Dakka'}
    multiCrewDefs['UH-1H'] = {[2] = 'Copilot', [3] = 'Dakka', [4] = 'DakkaDakka'}
    
    local function getPlayerNamesString(clients)
        local names = {}
        for cIndex, cData in pairs(clients) do
            if #names > 0 then
                table.insert(names, ' and ')
            end
            table.insert(names, cData.name)
       end
        return table.concat(names)
    end
	-------------------------------------------------------------------
	local function onFriendlyHit(clients, target, weapon)
        if slmod.config.enable_team_hit_messages then
			local msg = {[1] = 'Slmod- TEAM HIT: "', [2] = getPlayerNamesString(clients), [3] = '" hit friendly unit "', [4] = getPlayerNamesString(target), [5] = '" with ', [6] = tostring(weapon) ,[7] = '!'}
            slmod.scopeMsg(table.concat(msg), 1, 'chat')
            --slmod.scopeMsg('Slmod- TEAM HIT: "' .. tostring(client.name).. '" hit friendly unit "' .. tostring(target.name) .. '" with ' .. tostring(weapon) .. '!', 1, 'chat') OLD
		end
		-- Chat log
		if slmod.config.chat_log and slmod.config.log_team_hits and slmod.chatLogFile then
			local wpnInfo
			if weapon then
				wpnInfo = ' with ' .. weapon .. '\n'
			else
				wpnInfo = '\n'
			end
			local msg = {'TEAM HIT: ', os.date('%b %d %H:%M:%S '), '{players = {'}
            for ind, dat in pairs(clients) do
                table.insert(msg, table.concat({ind, ' = {name  = ', slmod.basicSerialize(tostring(dat.name)), ', ucid = ', slmod.basicSerialize(tostring(dat.ucid)), ', ip = ',  slmod.basicSerialize(tostring(dat.addr)), ', id = ', tostring(dat.id), '}'}))
            end
            for ind, tDat in pairs(target) do
                table.insert(msg, table.concat({ind, ' = {name = ', tDat.name}))
            end
            table.insert(msg, wpnInfo)
            slmod.chatLogFile:write(table.concat(msg))
            --slmod.chatLogFile:write(table.concat{'TEAM HIT: ', os.date('%b %d %H:%M:%S '), ' {name  = ', slmod.basicSerialize(tostring(client.name)), ', ucid = ', slmod.basicSerialize(tostring(client.ucid)), ', ip = ',  slmod.basicSerialize(tostring(client.addr)), ', id = ', tostring(client.id), '} hit ', target.name, wpnInfo}) OLD
			slmod.chatLogFile:flush()
		end
		-- autokick/autoban

		slmod.autoAdminCheckForgiveOnOffense(clients, target, 'teamHit')
	end

	local function onFriendlyKill(clients, target, weapon)
        if slmod.config.enable_team_kill_messages then
			local msg = {[1] = 'Slmod- TEAM KILL: "', [2] = getPlayerNamesString(clients), [3] = '" killed friendly unit "', [4] = getPlayerNamesString(target), [5] = '" with ', [6] = tostring(weapon) ,[7] = '!'}
            slmod.scopeMsg(table.concat(msg), 1, 'chat')
		end
		-- chat log
		if slmod.config.chat_log and slmod.config.log_team_kills and slmod.chatLogFile then
			local wpnInfo
			if weapon then
				wpnInfo = ' with ' .. weapon .. '\n'
			else
				wpnInfo = '\n'
			end
			local msg = {'TEAM KILL: ', os.date('%b %d %H:%M:%S '), '{players = {'}
            for ind, dat in pairs(clients) do
                
                table.insert(msg, table.concat({ind, ' = {name  = ', slmod.basicSerialize(tostring(dat.name)), ', ucid = ', slmod.basicSerialize(tostring(dat.ucid)), ', ip = ',  slmod.basicSerialize(tostring(dat.addr)), ', id = ', tostring(dat.id), '}'}))
            end
            for ind, tDat in pairs(target) do
                table.insert(msg, table.concat({ind, ' = {name = ', tDat.name}))
            end
            table.insert(msg, wpnInfo)
            slmod.chatLogFile:write(table.concat(msg))
            --slmod.chatLogFile:write(table.concat{'TEAM HIT: ', os.date('%b %d %H:%M:%S '), ' {name  = ', slmod.basicSerialize(tostring(client.name)), ', ucid = ', slmod.basicSerialize(tostring(client.ucid)), ', ip = ',  slmod.basicSerialize(tostring(client.addr)), ', id = ', tostring(client.id), '} hit ', target.name, wpnInfo}) OLD
			slmod.chatLogFile:flush()
		end
		-- autokick/autoban
		slmod.autoAdminCheckForgiveOnOffense(clients, target, 'teamKill')
	end
    

	local function onPvPKill(initName, tgtName, weapon, killerObj, victimObj)
		if slmod.config.enable_pvp_kill_messages then
			if killerObj and victimObj then
				slmod.scopeMsg('Slmod- PVP KILL: Humiliation! "' .. getPlayerNamesString(initName).. '" (flying a ' .. tostring(killerObj) .. ') scored a victory against "' .. getPlayerNamesString(tgtName) .. '" (flying a ' .. tostring(victimObj) .. ') with ' .. tostring(weapon) .. '!', 1, 'chat') 
			else
				slmod.scopeMsg('Slmod- PVP KILL: "' .. getPlayerNamesString(initName).. '" scored a victory against "' .. getPlayerNamesString(tgtName) .. '" with ' .. tostring(weapon) .. '!', 1, 'chat') 
			end
		end
	end
	
	
	local hitAIs = {}
	local hitHumans = {}
	
	
	
	--[[
	hitHumans = {
		[<string hit human unitName>] = {
			[1] = {  -- the first hit on this unit.
				time = <number>,
				
				<possibility 1- human initiator>: 
				initiator = {  -- a DEEPCOPY of an SlmodClient.
					id = <number, client ID#>, 
					addr = <number, ip address (N/A for host)>, 
					name = <string multiplayer name>, 
					ucid = <string ucid; not guaranteed for host!>,
					ip = <number, ip address (N/A for host)>, -- same as addr
					
					-- updated quantities, could be maybe a second old..
					coalition = <string>, -- either "red", "blue" or "spec"; should be guaranteed field.
					unitName = <string ME unit name>, -- not guaranteed
					rtid = <number, unit runtime id#>, -- not guaranteed
				},
		
				<possibility 2- AI initiator>: 
				initiator = <string AI unitName, or "Building" or maybe nil>,
				
				target = <SlmodClient>,  -- must exist, is an slmodClient.
				
				friendlyHit = <true or nil>
			},  -- end of first hit
			
			[2] = { -- second hit, and so on.
			...
			}, -- end of second hit
			
		},  -- end of this unitName.
		
		[<string, another hit human unitName>] = {
		...
		},
		
	}  -- end of hitHumans
	
	
	
	hitAIs = {
		[<string hit AI unitName>] = {
			[1] = {
				time = <number>,
				
				initiator = SlmodClient,
				
				friendlyHit = <true or nil>,
			
			},  -- end of first hit.
			
			[2] = {  -- second hit on this unit
			...
			},
		
		}, -- end of hit AI unit name
		
		[<string another hit AI unitName>] = {
		...
		},
	
	}
	
	
	-- need to quickly cycle through hitHumans and see if they no longer exist- perhaps dead without an event.
	
	If they don't exist anymore, then treat them as if they died.
	]]
	
	-- ALSO, I need to special detection for mid-air collisions
	
	
	local function getHitData(unitName)
		 if hitHumans[unitName] then
			return hitHumans[unitName][#hitHumans[unitName]] -- just return the last hit
		end
		if hitAIs[unitName] then
			return hitAIs[unitName][#hitAIs[unitName]] -- just return the last hit
		end
	end
	
	local landedUnits = {}  -- used to remove kill detection on landed units.
	local suppressDeath = {}  -- used to suppress any extra dead event after a unit no longer exists.  Probably not necessary
	local humanShots = {}  -- in the case of an unidentified weapon in in a hit event, this is used to associate the event with the last weapon fired.
	local gunTypes = {}
    
	local function computeTotal(kills)  -- computes total kills for a specific type (vehicle, ship, plane, etc.)
		local total = 0
		for typeName, typeKills in pairs(kills) do
			if typeName ~= 'total' then
				total = total + typeKills
			end
		end
		return total
	end
	
	
	function slmod.stats.reset()
		eventInd = 1
		clusterHits = {}
		trackedWeapons = {}
		hitAIs = {}
		hitHumans = {}
		landedUnits = {}
		suppressDeath = {}
		humanShots = {}
		
		-- compute/re-check totals
		for ucid, pStats in pairs(stats) do
			if ucid ~= 'version' then  -- no 'version' entry at this time
				if pStats.kills then
					for cat, typeKills in pairs(pStats.kills) do
						local total = computeTotal(typeKills)
						if not typeKills.total then  -- if typeKills.total doesn't even exist...
							-- add the total field if it doesn't exist- should never happen except in very old stats.
							slmod.stats.changeStatsValue(typeKills, 'total', total)
						elseif typeKills.total and typeKills.total ~= total then -- it doesn't match- could happn in cases of errors.
							slmod.warning('total typeKills for type ' .. tostring(cat) .. ' does not match the total field.')
							slmod.stats.changeStatsValue(typeKills, 'total', total)
						end
					end
				end
			end
		end
		
	end
	
	local function unsuppressDeath(unitName)  -- allows death counting to occur again for this unit.
		--slmod.info('Unsupress death')
        --slmod.info(unitName)
        suppressDeath[unitName] = nil
	end
	
	
	local function PvPRules(killer, victim)  -- expects unitNames, returns a boolean true if it was a fair match, false otherwise, nil in case of fuck up
		local attack = {'a%-10', 'su%-25'}
		--slmod.info('pvp rules')
		local killerUnit = slmod.allMissionUnitsByName[killer]
		local victimUnit = slmod.allMissionUnitsByName[victim]
		if killerUnit and victimUnit then
			local killerCat = killerUnit.category
			local victimCat = victimUnit.category
			if killerCat == 'helicopter' then  -- helos always count.
				if victimCat ~= 'helicopter' then -- humiliation kill
					return true, killerUnit.objtype, victimUnit.objtype
				else
					return true
				end
			end
			
			if victimCat == 'helicopter' then
				return false  -- killerCat was not helicopter but victim cat is!
			end
			-- only planes left.  Find out if they are attack.
			local killerType = killerUnit.objtype
			local victimType = victimUnit.objtype
			for i = 1, #attack do
				if killerType:lower():find(attack[i]) then  -- convert killer type to lowercase, then search for attack[i] in it.
					killerCat = 'attack'
					break
				end
			end
			for i = 1, #attack do
				if victimType:lower():find(attack[i]) then  -- convert victim type to lowercase, then search for attack[i] in it.
					victimCat = 'attack'
					break
				end
			end
			
			if killerCat == 'plane' and victimCat == 'attack' then
				return false
			end
			
			if killerCat == 'attack' and victimCat == 'plane' then
				return true, killerUnit.objtype, victimUnit.objtype
			else
				return true  -- still here, must be a countable kill.
			end
		end
	end
	
	
	local acft = {} -- exceptions list. For some reason mig-29A is not matching with below code because it is displayed as Mig-29.
	-- Temp fix
	acft['mig-29'] = true
	
	local function isAircraft(weaponName)  -- determines if the weapon was a aircraft.
        --slmod.info('isAC')
		if weaponName and weaponName:len() > 1 then
            for planeCat, planes in pairs(slmod.unitCategories.Planes) do
				for plane, trashVal in pairs(planes) do
					if weaponName:sub(1, weaponName:len() - 1):lower():gsub('[^%d%a]', '') == plane:sub(1, plane:len() - 1):lower():gsub('[^%d%a]', '') then  -- take out the last character, convert to lower case, remove anything not a letter or a number... do comparison this way.
                        return true
					end
				end
			end
			for heloCat, helos in pairs(slmod.unitCategories.Helicopters) do
				for helo, trashVal in pairs(helos) do
					if weaponName:sub(1, weaponName:len() - 1):lower():gsub('[^%d%a]', '') == helo:sub(1, helo:len() - 1):lower():gsub('[^%d%a]', '') then
						return true
					end
				end
			end
			
            if acft[weaponName] then
				return true
			end
		end
		return false
	end
	
	
	function slmod.stats.create_unitIsStationary()
		local unitIsStationaryString = [[--slmod.unitIsStationary
slmod = slmod or {}
function slmod.unitIsStationary(unitName)
	local unit = Unit.getByName(unitName)
	if unit then
		local vel = unit:getVelocity()
		if vel then
			if (vel.x^2 + vel.y^2 + vel.z^2)^0.5 < 0.1 then
				return true
			end
		end
	end
	return false
end]]
		local str, err = net.dostring_in('server', unitIsStationaryString)
		if not err then
			slmod.error('unable to create unitIsStationary(), reason: ' .. tostring(str))
		end
	
	end
	
	local function unitIsStationary(unitName)
		local str, err = net.dostring_in('server', table.concat({'return tostring(slmod.unitIsStationary(', slmod.basicSerialize(unitName), '))'}))
		if err then
			return str == 'true'
		else
			slmod.error('error running slmod.unitIsStationary in server env, reason: ' .. tostring(str))
		end
	end
	
	--[==[function slmod.stats.create_unitIsAlive()  -- pre 1.2.4 version
		local unitIsAliveString = [[--slmod.unitIsAlive
slmod = slmod or {}
function slmod.unitIsAlive(unitName)
	local unit = Unit.getByName(unitName)
	if unit then
		return unit:isExist()
	else
		return false
	end
end]]
		local str, err = net.dostring_in('server', unitIsAliveString)
		if not err then
			slmod.error('unable to create unitIsAlive in main simulation env, reason: ' .. tostring(str))
		end
	end]==]
	
	function slmod.stats.create_unitIsAlive()
		local unitIsAliveString = [[--slmod.unitIsAlive
slmod = slmod or {}
function slmod.unitIsAlive(unitName)
	local unit = Unit.getByName(unitName)
	if unit then
		return true
	else
		return false
	end
end]]
		local str, err = net.dostring_in('server', unitIsAliveString)
		if not err then
			slmod.error('unable to create unitIsAlive in main simulation env, reason: ' .. tostring(str))
		end
	end
	

	local function unitIsAlive(unitName)
		local str, err = net.dostring_in('server', table.concat({'return tostring(slmod.unitIsAlive(', slmod.basicSerialize(unitName), '))'}))
		if err then
			if str == 'true' then
				return true
			else
				return false
			end
		else
			slmod.error('unable to call slmod.unitIsAlive in main simulation env, reason: ' .. tostring(str))
		end
	end
    
    
	
	-----------------------------
	-- tracks what clients were in air last check...
	-- used for pvp kills - don't award a PvP kill on clients on the ground.
	local inAirClients = {}
	-----------------------
	
	----------------------------------------------------------------------------------------------------------
	-- death logic
	local function runDeathLogic(deadName)
		if slmod.allMissionUnitsByName[deadName] then -- the dying unit should always be identified properly by name (not necessarily...could be Building).
            local deadCategory = slmod.allMissionUnitsByName[deadName].category 
			local deadClient = slmod.clientsByName[deadName] or slmod.oldClientsByName[deadName]
			-- Find the object in SlmodStats categories
			local deadObjType = slmod.allMissionUnitsByName[deadName].objtype
			local deadStatsCat
			local deadStatsType
			if deadCategory == 'static' then  -- just automatically assign into static objects.
				deadStatsCat = 'Buildings'
				deadStatsType = 'Static'
			end
			--slmod.info(deadStatsCat)
			if not deadStatsCat or (not deadStatsCat == 'Buildings') then -- need to find the type.
				--slmod.info(slmod.tableshow( slmod.catsByUnitType))
				if slmod.catsByUnitType[deadObjType] then
					local types = slmod.catsByUnitType[deadObjType]
					deadStatsCat = types[1]
					deadStatsType = types[2]
					if not (deadStatsCat and deadStatsType) then
						return
						slmod.error('SlmodStats deadStatsCat or deadStatsType not recognized; deadStatsCat: ' .. tostring(deadStatsCat) .. '; deadStatsType: ' .. tostring(deadStatsType))
					end
				else
					slmod.error('SlmodStats - unit type ' .. tostring(deadObjType) .. ' for unit ' .. tostring(deadName) .. ' not in database!')
					return
				end
			end
            --slmod.info(deadObjType)
            --slmod.info(deadStatsCat)
           -- slmod.info(deadStatsType)
			--slmod.info('here4')
			-- see if a human was involved.
			local lastHitEvent = getHitData(deadName)
			if lastHitEvent then  -- either a human died or an AI that was hit by a human died.
				--local lastHitEvent = hitData[#hitData] --- at least FOR NOW, just using last hit!
				--slmod.info('lastHitEvent')
                --slmod.info(slmod.oneLineSerialize(lastHitEvent))
                
				local hitObj = lastHitEvent.initiator
                local hitObjType = 'unknown'
                if lastHitEvent.shotFrom then
                    hitObjType = lastHitEvent.shotFrom
                end
				local weapon = lastHitEvent.weapon
                local saveStat = {}
                local ucid, typeName = {}, {}
                if type(lastHitEvent.initiator) == 'table' then 
                    for seat, data in pairs(lastHitEvent.initiator) do
                        ucid[seat] = data.ucid
                        if seat > 1 then
                            typeName[seat] = multiCrewNameCheck(hitObjType, seat)
                        else
                            typeName[seat] = hitObjType
                        end
                    end
                end
                saveStat = {ucid = ucid, typeName = typeName}
                local deadObjData = {}
                local dStat = {}
                local ducid, dtypeName = {}, {}
                if deadClient then 
                    for seatId, dData in pairs (deadClient) do
                        ducid[seatId] = dData.ucid
                        deadObjData[seatId] = {ucid = dData.ucid, name = dData.name, id = dData.id}
                        if seatId > 1 then
                            dtypeName[seatId] = multiCrewNameCheck(deadObjType, seatId)
                        else
                            dtypeName[seatId] = deadObjType
                        end
                    end
                    dStat = {ucid = ducid, typeName = dtypeName}
                else
                    deadObjData[1] = {name = deadName}
                end
                
                --case 1 - deadAI, hit by human.
				
                if type(hitObj) == 'table' then -- it SHOULD be
                    --slmod.info(slmod.oneLineSerialize(hitObj))
                    if not lastHitEvent.friendlyHit then -- good kill
                        saveStat.nest = {'times', 'typeName', 'kills', deadStatsCat, deadStatsType}
                        saveStat.addValue = 1
                        saveStat.default =  0
                        slmod.stats.advChangeStatsValue(saveStat)
                        
                        -- Add to total Kills for a given category
                        saveStat.nest = {'times', 'typeName', 'kills', deadStatsCat, 'total'}
                        slmod.stats.advChangeStatsValue(saveStat)
                        
                        
                        if weapon then
                            saveStat.nest = {'times', 'typeName', 'weapons', weapon}
                            saveStat.addValue = {kills = 1}
                            saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0}
                            slmod.stats.advChangeStatsValue(saveStat)
                        end    
                        --slmod.stats.changeStatsValue(stats[deadClientUCID[i]].losses, 'crash', stats[deadClientUCID[i]].losses.crash + 1)
                        
                        if deadClient then
                            dStat.nest = {'times', 'typeName', 'losses'}
                            dStat.addValue = {crash = 1}
                            dStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                            slmod.stats.advChangeStatsValue(dStat)
                        
                        
                        end
                        
                        --- DO PVP STUFF
                        
                        if lastHitEvent.inAirHit or lastHitEvent.inAirHit == nil then
                            --slmod.info('lastHitEvent.inAirHit: '  .. tostring(lastHitEvent.inAirHit))
                            local countPvP, killerObj, victimObj = PvPRules(lastHitEvent.unitName, deadName)
                            if countPvP then  -- count in PvP!
                                saveStat.nest = {'times', 'typeName', 'pvp', 'kills'}
                                saveStat.addValue = 1
                                saveStat.default = 0
                                slmod.stats.advChangeStatsValue(saveStat)
                                
                                dStat.nest = {'times', 'typeName', 'pvp', 'losses'}
                                dStat.addValue = 1
                                dStat.default = 0
                                
                                slmod.stats.advChangeStatsValue(dStat)
                                onPvPKill(hitObj, deadClient, weapon, killerObj, victimObj)
                           end
                        end
                    else -- teamkilled 
                        saveStat.penalty = true 
                        if weapon == 'kamikaze' then
                            saveStat.nest = 'friendlyCollisionKills'
                            --slmod.info('KKill')
                        else
                           saveStat.nest = 'friendlyKills'
                        end
                        saveStat.addValue = { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = weapon, shotFrom = hitObjType}
                        if deadClient then
                            saveStat.addValue.human = ducid
                        end
                        slmod.stats.advChangeStatsValue(saveStat)
                        onFriendlyKill(hitObj, deadObjData, weapon)
                    end
                elseif type(hitObj) == 'string' then  -- AI hit them
                    dStat.nest = {'times', 'typeName', 'actions', 'losses'}
                    dStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                    dStat.addValue = {crash = 1}
                    slmod.stats.advChangeStatsValue(dStat)
                else
                    if type(hitObj) == 'table' then
                        slmod.warning('SlmodStats- hitter (' .. slmod.oneLineSerialize(hitObj) .. ') is not an SlmodClient, and dead unit (unitName = ' .. tostring(deadName) .. ') is not an SlmodClient!')
                    else
                        slmod.warning('SlmodStats- hitter (' .. tostring(hitObj) .. ') is not an SlmodClient, and dead unit (unitName = ' .. tostring(deadName) .. ') is not an SlmodClient!')
                    end
                end    
			elseif deadClient then  -- client died without being hit.
                local saveStat = {}
                local ucid, typeName = {}, {}
                    for seat, data in pairs(deadClient) do
                        ucid[seat] = data.ucid
                        if seat > 1 then
                            typeName[seat] = multiCrewNameCheck(deadObjType)
                        else
                            typeName[seat] = deadObjType
                        end
                        saveStat = {ucid = ucid, typeName = typeName}
                    end
                
                saveStat.nest = {'times', 'typeName', 'actions', 'losses'}
                saveStat.default = {crash = 0}
                saveStat.addValue = {crash = 1}
                slmod.stats.advChangeStatsValue(saveStat)
			end
			
			-- wipe this unit if he is a hitHuman
            hitHumans[deadName] = nil
		end
	end
	----------------------------------------------------------------------------------------------------------
	local function multiCrewNameCheck(tName, seatId)
        if not multiCrewDefs[tName][seatId] then
            tName = tName .. ' Co-Pilot'
        else
            tName = tName .. ' ' .. multiCrewDefs[tName][seatId]
        end
        return tName
    end
    
    local function parseOutExtraClientData(client)
        local cTbl = {}
        for index, cData in pairs(client) do
            local new = {}
            new.ucid = cData.ucid
            new.name = cData.name
            new.id = cData.id
            cTbl[index] = new
        end
        
        return cTbl
    
    end

	----------------------------------------------------------------------------------------------------------
	-- tracks flight times.

	function slmod.stats.trackFlightTimes(prevTime)  -- call every 10 seconds, tracks flight time.
		slmod.scheduleFunction(slmod.stats.trackFlightTimes, {DCS.getModelTime()}, DCS.getModelTime() + 10)  -- schedule first to avoid a Lua error.
		
		inAirClients = {}  -- reset upvalue inAirClients table.
		if prevTime and slmod.config.enable_slmod_stats then  -- slmod.config.enable_slmod_stats may be disabled after the mission has already started.
			local dt = DCS.getModelTime() - prevTime
            local metaFlightTime = 0
			-- first, update all client flight times.
			for id, client in pairs(slmod.clients) do -- for each player (including host)
                local side = net.get_player_info(id, 'side')
				local unitId, seatId = slmod.getClientUnitId(id) --slot id filtered for multicrew  (seadId corresponds to number you press in SP to occupy slot - 1. Pilot: 0, Rio/copilot: 1, 2:Engineer/Gunner, 3: Gunner
                if unitId then -- if in a unit.
					if is_BC(unitId) then  -- if it is a CA slot
						if client.ucid and stats[client.ucid] then
							slmod.stats.advChangeStatsValue({ucid = client.ucid, nest = {'times', 'CA'}, addValue = {total = dt }, default = {total = 0, inAir = 0}})
						end
					else -- not a CA slot.
						unitId = tonumber(unitId)
						if unitId and unitId > 0 then
							unitName = tostring(DCS.getUnitProperty(unitId, 3))  -- get Unit's ME name
							if unitName then
                                local retStr = net.dostring_in('server', table.concat({'return slmod.getStatsUnitInfo(', slmod.basicSerialize(unitName), ')'}))  -- get if the unit is in air, and the unit's name.
                                if retStr and retStr ~= '' then
									if retStr:sub(1, 4) == 'true' then  -- in air
										local typeName = retStr:sub(6) -- six to end.
										if client.ucid and stats[client.ucid] then
                                            if seatId > 0 then
                                                typeName = multiCrewNameCheck(typeName, seatId)
                                            end
                                            slmod.stats.advChangeStatsValue({ucid = client.ucid, nest = {'times', typeName}, addValue = {total = dt, inAir = dt}, default = {total = 0, inAir = 0}})

                                            metaFlightTime = metaFlightTime + dt
											inAirClients[client.ucid] = true  -- used for PvP kills to avoid counting hits in the air
										end
									elseif retStr:sub(1,5) == 'false' then  -- not in air
										local typeName = retStr:sub(7) -- seven to end.
                                        if seatId > 0 then
                                            typeName = multiCrewNameCheck(typeName, seatId)
                                        end
                                        if client.ucid and stats[client.ucid] then
											slmod.stats.advChangeStatsValue({ucid = client.ucid, nest = {'times', typeName}, addValue = {total = dt}, default = {total = 0, inAir = 0}})
											inAirClients[client.ucid] = false
										end
									end
								end
							end
						end
					end
				end
			end  -- for id, client in pairs(slmod.clients) do
			
            slmod.stats.updateMetaFlightInfo(metaFlightTime)
        end -- if prevTime and slmod.config.enable_slmod_stats then
	end -- end of flight time tracking.
	----------------------------------------------------------------------------------------------------------
	-- gunsTracking code maybe. or add it to slmodevents...
	--[[
	local gunsFired = {}
	local function checkGunAmmo()
	
	end]]
	----------------------------------------------------------------------------------------------------------
	-- events tracking

	function slmod.stats.trackEvents()  -- called every second from server.onProcess
		local human_hits
		local ranhuman_hits = false
		if slmod.config.enable_slmod_stats then  -- slmod.config.enable_slmod_stats may be disabled after the mission has already started.
			--Now do slmod.events-based stats.
			while #slmod.events >= eventInd do
				local event = slmod.events[eventInd]
				--slmod.info('checking ' .. eventInd)
                --slmod.info(slmod.oneLineSerialize(slmod.events[eventInd]))
				eventInd = eventInd + 1  -- increment NOW so if there is a Lua error, I'm not stuck forever on this event.
                
                
                local initClient -- load this for each event with standardized table
                local saveStat = {}
                local ucid, typeName = {}, {}

				if slmod.clientsByRtId and slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator] then
                    initClient = slmod.clientsByRtId[event.initiatorID]
                    for seat, data in pairs(initClient) do
                        ucid[seat] = data.ucid
                        if seat > 1 then
                            typeName[seat] = multiCrewNameCheck(event.initiator_objtype, seat)
                        else
                            typeName[seat] = event.initiator_objtype
                        end
                        saveStat = {ucid = ucid, typeName = typeName}
                    end
                    
                end
				--slmod.info(slmod.oneLineSerialize(saveStat))
                ----------------------------------------------------------------------------------------------------------
				--- Shot events
				--if (event.type == 'shot' or event.type == 'start shooting') and event.initiator_name and event.initiator_mpname and event.initiator_name ~= event.initiator_mpname then  -- human shot event
				if (event.type == 'shot' or event.type == 'end shooting' or event.type == 'start shooting') and event.initiator and event.initiatorPilotName and event.initiator ~= event.initiatorPilotName then  -- human shot event
					if slmod.clientsByRtId then
						local clients = slmod.clientsByRtId[event.initiatorID]
                        if clients then -- don't check for specific seat I guess, just see if it exists. To many variables if hot swapping seats is added to more aircraft
                            if event.weapon or event.type == 'end shooting' or event.type == 'start shooting' then
                                local weapon
                                if event.type == 'end shooting' then
                                    weapon = event.weapon
                                    --- this is code to check the number of rounds fired. 
                                    local shotFirstEvent
                                    
                                    gunTypes[event.weapon] = event.initiator_objtype
                                    
                                    for i = (eventInd - 2), 4, -1 do
                                        if event.initiator == slmod.events[i].initiator then -- finds the first start shooting event from the current end shootingfor the initiator
                                        --Iterate back to find the first shooting start event. Break if shooting end on same weapon found
                                        -- Go back max 40 events?
                                            if slmod.events[i].type == 'start shooting' then
                                                if slmod.events[i].weapon and event.weapon == slmod.events[i].weapon then
                                                    shotFirstEvent = i
                                                end
                                            elseif slmod.events[i].type == 'end shooting' then -- gone to far
                                                break
                                            end
                                            if i < eventInd - 40 then
                                                break
                                            end
                                        end
                            
                                    end
                                    --
                                    if shotFirstEvent and type(shotFirstEvent) == 'number' then
                                        event.numtimes = slmod.events[shotFirstEvent].numShells - event.numShells
                                    end
                                else
                                    weapon = event.weapon
                                    -------------------
                                    -- problem: mp clients cannot hit with guns.  Empty weapon name, mismatching runtime IDs, etc.
                                    --[[ change any shell names or nil shell names to "guns".
                                    if isShell(weapon) then
                                        weapon = 'guns'
                                    end]]
                                    -------------------
                                    if clusterBombs[weapon] then -- handle cluster bombs
                                        weapon = clusterBombs[weapon].name
                                    end
                                end
                                local isGun = false
                                if gunTypes[weapon] then
                                    isGun = true
                                end
                                saveStat.nest = {'times', 'typeName', 'weapons', weapon}
                                saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0}
                                if event.numtimes then
                                    saveStat.addValue = {shot = event.numtimes}
                                else
                                    saveStat.addValue = {shot = 1}
                                end
                                if isGun == true then
                                    saveStat.default.gun = true
                                end
                                slmod.stats.advChangeStatsValue(saveStat)
                                    
                                
                                humanShots[event.initiator] = weapon   -- for this initiator, store the name of the last weapon fired.
                                
                                if event.weaponID then  -- add to tracked weapons.  Right now, only bombs, rockets, and missiles will have an ID.
                                    trackedWeapons[event.weaponID] = event.weaponID
                                end
                                
							end
						end
					
                    end
				end -- end shot events/start shooting events
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				-- hit events
				if event.type == 'hit' and event.target then
					--slmod.info('eventTypeHit')
					local tgtName = event.target  -- dependable at least.
					local tgtClient
					local tgtSide
					local tgtCategory
					local tgtTypeName
					local initName = event.initiator  -- may not be dependable.
					local initClient
					local initUCID
					local initSide
                    local initType = event.initiator_objtype
					local nonAliveHit = false
	
					local time = event.t
					
					local weapon = event.weapon
					
					
					-------------------
					-- problem: mp clients cannot hit with guns.  Empty weapon name, mismatching runtime IDs, etc.

                    local isGun = false
                    if gunTypes[weapon] then
                        isGun = true
                    end
					
					if isAircraft(weapon) then
						weapon = 'kamikaze'
					end
					------------------
					
					--------------------------------------------
					-- Gather target information.
					if slmod.clientsByName[tgtName] or slmod.oldClientsByName[tgtName] then
						--slmod.info('get target info')
						if slmod.clientsByName[tgtName] then
							tgtClient = slmod.deepcopy(slmod.clientsByName[event.target])
						else
							tgtClient = slmod.deepcopy(slmod.oldClientsByName[event.target])
						end

						if tgtClient[1] and tgtClient[1].coalition then 
                            tgtSide = tgtClient[1].coalition
                        end
						tgtCategory = slmod.allMissionUnitsByName[tgtName].category  -- could end up getting a nil index error here, maybe protect for robustness later.
						tgtTypeName = slmod.allMissionUnitsByName[tgtName].objtype
					else -- target is AI unit/STATIC/building/w/e
						--slmod.info('target is not client')
						if slmod.allMissionUnitsByName[tgtName] then  
							tgtSide = slmod.allMissionUnitsByName[tgtName].coalition
							tgtCategory = slmod.allMissionUnitsByName[tgtName].category
							tgtTypeName = slmod.allMissionUnitsByName[tgtName].objtype
							--slmod.info('here2')
						else
							slmod.error('error in stats, could not match target unit in hit event with a mission editor unit name.  Could it be a map object? Event Index: ' .. eventInd)
							--slmod.info(slmod.oneLineSerialize(event))
						end
						
					end
					-----------------------------------------------
					-- gather information on the initiator, if initiator was human.
					
					-- code for "killed by Building" compensation.
					if event.initiatorID == 0 then -- possible hit by a human
						--slmod.info('killed by building')
						if not ranhuman_hits then  -- first, see if I can get new human_hits from main simulation env.
							local str, err = net.dostring_in('server', 'return slmod.getLatestHumanHits()')
							if err then
								if str ~= 'no hits' then
									human_hits = slmod.deserializeValue(str)
									--slmod.info('here4')
								else
									--slmod.info('here5')
								end
							else
								slmod.warning('unable to get latest human_hits from server env, reason: ' .. str)
							end
							ranhuman_hits = true  -- don't need to run again this cycle.
						end
						
						if human_hits and #human_hits > 0 then -- there were some human hits
							for hitsInd = 1, #human_hits do
								--slmod.info('human hits greater than 0')
								--slmod.info(time)
								--slmod.info(human_hits[hitsInd].time)
								--slmod.info(tgtName)
								--slmod.info(human_hits[hitsInd].target)
								--slmod.info(human_hits[hitsInd].initiator)
									
								if time == human_hits[hitsInd].time and tgtName == human_hits[hitsInd].target and human_hits[hitsInd].initiator then  -- hit matches time and target id_.
									
									--slmod.info('here1')
									nonAliveHit = true
									initClient = human_hits[hitsInd].initiator
									initName = initClient.unitName
									initUCID = initClient.ucid
									initSide = initClient.coalition
									break
								end
							
							end
							
						end
					elseif initName then
                        if event.initiatorPilotName and initName ~= event.initiatorPilotName then  -- almost certainly human, and ALIVE.
                            initClient = slmod.clientsByRtId[event.initiatorID]
                        elseif slmod.oldClientsByName[initName] then -- was a human, but they are now dead. 
                            initClient = slmod.oldClientsByName[initName]
                        else  -- initiator probably not human.
						-- nothing right now...
                        
                        end
					

					end
					-----------------------------------------------------------
					
					-- OK, now we have data on target and initiator- hopefully, 99.999% accurate data!
					
					if initClient and initName ~= tgtName then  -- a human initiated hit and they didn't TK themself
						local givenPenalty = false
                        local addedHit = false
                        --slmod.info(initType)
                        
                        for seat, clientData in pairs(initClient) do
                            initSide = clientData.coalition
                        end
                        -- first, handle the case of nil weapon.  Happens due to a bug in DCS, and is very difficult to solve this bug fully.
                        -- for now, just assume that the weapon is the last weapon the human fired.
                        if (not weapon) and initName and humanShots[initName] then
                            weapon = humanShots[initName]
                        elseif not weapon then
                            weapon = 'unknown'
                            slmod.warning('SlmodStats - nil weapon in hit event, and no weapons fired by client!')
                        end
                        
                    
                        local isCluster = false  
                        if subToCluster[weapon] then
                            weapon = subToCluster[weapon]
                            isCluster = true
                        end
                        
                        
                        if (not isCluster) or (isCluster and filterClusterHits(weapon, initName, tgtName, time)) then  -- count this hit, it's not a cluster hit or is a new cluster hit.
                            --slmod.info('saveHit')
                            if not stats[saveStat.ucid[1]].times[saveStat.typeName[1]].weapons then
                                saveStat.default = {}
                                saveStat.nest = {'times', 'typeName', 'weapons'}
                                slmod.stats.advChangeStatsValue(saveStat)  
                            end
                            
                            if not stats[saveStat.ucid[1]].times[saveStat.typeName[1]].weapons[weapon] then
                                saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0}
                                saveStat.nest = {'times', 'typeName', 'weapons', weapon}
                                slmod.stats.advChangeStatsValue(saveStat)
                            end

                            if tgtSide and initSide then
                                local saveToHit = {time = time, initiator = parseOutExtraClientData(initClient), weapon = weapon, shotFrom = initType, rtid = event.initiatorID, unitName = initName}
                                local tgtInfoForFHit = {[1] = {name = tgtName}}
                                if tgtSide == initSide then
                                    saveToHit.friendlyHit = true
                                end
                                
                                if tgtClient then 
                                    if tgtClient[1].ucid and inAirClients[tgtClient[1].ucid] ~= nil then
                                        saveToHit.inAirHit = inAirClients[tgtClient[1].ucid]
                                    end
                                    saveToHit.target = slmod.deepcopy(tgtClient)
                                    hitHumans[tgtName] = hitHumans[tgtName] or {}
                                    hitHumans[tgtName][#hitHumans[tgtName] + 1] = saveToHit
                                    tgtInfoForFHit = slmod.deepcopy(tgtClient)
                                else
                                    hitAIs[tgtName] = hitAIs[tgtName] or {}
                                    hitAIs[tgtName][#hitAIs[tgtName] + 1] = saveToHit
                                end
                                
                                if tgtSide ~= initSide then  -- hits on enemy units in here
                                    saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0}
                                    saveStat.nest = {'times', 'typeName', 'weapons', weapon}
                                    saveStat.addValue = {}
                                    saveStat.addValue.numHits = event.numtimes or 1
                                    
                                    if (event.weaponID and trackedWeapons[event.weaponID]) or isGun == true then  -- this is the first time this weapon hit something.
                                        if isGun == false then
                                            
                                            trackedWeapons[event.weaponID] = nil
                                        end
                                        saveStat.addValue.hit = 1
                                    end
                                    
                                    slmod.stats.advChangeStatsValue(saveStat)
                                    

                                else
                                    saveStat.penalty = true 
                                    if weapon == 'kamikaze' then
                                       saveStat.nest = 'friendlyCollisionHits'
                                    else
                                       saveStat.nest = 'friendlyHits'
                                    end
                                    saveStat.addValue = { time = os.time(), objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon, shotFrom = initType}
                                    if tgtClient then
                                        local hitClient = {}
                                        for i = 1, #tgtClient do 
                                            if tgtClient[i].ucid then 
                                                table.insert(hitClient, tgtClient[i].ucid)
                                            end
                                        end
                                        saveStat.addValue.human = hitClient
                                    end
                                    slmod.stats.advChangeStatsValue(saveStat)
                                    onFriendlyHit(initClient, tgtInfoForFHit, weapon)
                                        
                                end
                            else
                                slmod.error('SlmodStats error- either tgtSide or initSide does not exist for hit event! Event Line follows:')
                                slmod.info(slmod.oneLineSerialize(event))
                            end
                            
                        end
                        
                    elseif tgtClient and not initClient then -- only case left unhandled in above code: AI hits human.
                        local inAirHit
                        if tgtClient[1].ucid and inAirClients[tgtClient[1].ucid] ~= nil then
                            inAirHit = inAirClients[tgtClient[1].ucid]
                        end
                    
                        hitHumans[tgtName] = hitHumans[tgtName] or {}
                        hitHumans[tgtName][#hitHumans[tgtName] + 1] = {time = time, initiator = initName, target = slmod.deepcopy(tgtClient), inAirHit = inAirHit}
                        --slmod.info('here9')
                    
                    
					end
				end -- end of hit events.
				----------------------------------------------------------------------------------------------------------
				
				--[[if event.type == 'birth' then
					slmod.info('here')
					slmod.info(#slmod.allMissionUnitsByName)
				
				end]]
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'dead' or event.type == 'crash' then
					local deadName = event.initiator  -- should be dependable.
					if not suppressDeath[deadName] then
						runDeathLogic(deadName)  -- run the death logic function.
					end
				end  -- end of crash/dead events.
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'pilot dead' then
                    saveStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                    saveStat.nest = {'times', 'typeName', 'actions', 'losses'}
                    if event.initiator then
						local deadClient = slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator]
						if deadClient then
							saveStat.addValue = {pilotDeath = 1}
                            slmod.stats.advChangeStatsValue(saveStat)
						end
					end				
				end -- end of pilot dead
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'land' then  -- check if this is the valid name.
					if event.initiator then 
                        if hitHumans[event.initiator] then
                            landedUnits[event.initiator] = DCS.getModelTime()
                        end
					end
				end -- end of land
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'takeoff' then  -- check if this is the valid name.
					if event.initiator then
                        if landedUnits[event.initiator] then
                            landedUnits[event.initiator] = nil
                        end
                        -- iterate back up to 10 seconds to see if the player bounced
					end
				end
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'eject' then
					if event.initiator then
						local deadClient = slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator]
						if deadClient then
							saveStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                            saveStat.nest = {'times', 'typeName', 'actions', 'losses'}
                            saveStat.addValue = {eject = 1}
                            slmod.stats.advChangeStatsValue(saveStat)
						end
					end				
				end	-- end of eject
				----------------------------------------------------------------------------------------------------------
				if event.type == 'refueling stop' then
                    if event.initiator then
                    
                    end
                end
                
                
				
			end  -- end of while loop.
			
			-- If a hitHuman lands and comes to a stop after landing without dying, remove them from hit units.
			local currentTime = DCS.getModelTime()
			for unitName, landTime in pairs(landedUnits) do
				if slmod.activeUnitsByName[unitName] then
					if currentTime - landTime > 10 then  -- start checking to see if the unit is stationary.
						if unitIsStationary(unitName) then
							--slmod.info(unitName .. ' was a hit unit and has landed safely, clear it so it cant be TKd')
                            hitHumans[unitName] = nil -- human cannot be killed now.
							landedUnits[unitName] = nil
						end
					end
				else
					landedUnits[unitName] = nil
				end
			
			end
			
			
			--[[If any entries in hitHumans are no longer alive, then it counts it as a death, and removes the entry of hitHumans.
			The removal of that entry in hitHumans prevents a potential future "dead" event from counting as an additional death.
			Remember- hitHumans only includes humans that were hit, so this function won't erroneously count crashes for no reason.
			
			ALSO, clear the landedUnits table entry for this unit if it is not alive.]]
			
			-- NOW, check to see if any hitHumans are non-existant.
			for unitName, hits in pairs(hitHumans) do
				if not unitIsAlive(unitName) then
					slmod.info('SlmodStats- hit client unitName: ' .. unitName .. ', hits[#hits]: ' .. slmod.oneLineSerialize(hits[#hits]) .. '  no longer exists, running death logic.')
					
					suppressDeath[unitName] = true
					runDeathLogic(unitName)
					slmod.scheduleFunction(unsuppressDeath, {unitName}, DCS.getModelTime() + 10)-- allow this unit to die again in 10 seconds.
					landedUnits[unitName] = nil  -- may or may not be nil.
				end
			end	
			
			slmod.stats.updateStatsTrackedWeapons()  -- clean out any dead, un-used trackedWeapons.
		else  -- disabled, but make event counter increment still.
			eventInd = #slmod.events + 1
		end
	end
	
	function slmod.stats.closeStatsFile()
		if statsF then
			statsF:close()
			statsF = nil
		end
        if penStatsF then
        	penStatsF:close()
			penStatsF = nil
        end
	end

	-- ***END OF STATS TRACKING**
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-- Additional functions for interfacing with private stats data.
	function slmod.stats.getStats()
		return stats
	end
    function slmod.stats.getPenStats()
        return penStats
    end
    function slmod.stats.getUserPenStats(ucid)
        if penStats[ucid] then
            return penStats[ucid]
        end
    end
    function slmod.stats.getUserStats(ucid)
        if stats[ucid] then
            return stats[ucid]
        end
    end
	-- ***BEGINNING OF STATS USER INTERFACE***
    
    local commonStatTbl = {
    ['Ground Units'] =  {['SAM'] = 0,['AAA'] = 0,['EWR'] = 0, ['Arty/MLRS'] = 0, ['Infantry'] = 0, ['Tanks'] = 0, ['IFVs'] = 0,['APCs'] = 0, ['Unarmored'] = 0, ['Forts'] = 0, ['Other'] = 0, ['total'] =0, },
	['Planes'] =  {['Fighters'] = 0,['Attack'] = 0,['Bombers'] = 0,['Support'] = 0,['UAVs'] = 0,['Transports'] = 0,['Other'] = 0,['total'] = 0,	},
	['Helicopters'] =  	{['Attack'] = 0,['Utility'] = 0,['Other'] = 0,['total'] = 0,		},
	['Ships'] = 	{['Warships'] = 0,['Subs'] = 0,['Unarmed'] = 0,['Other'] = 0,['total'] = 0,		},
	['Buildings'] =  	{['Static'] = 0,['Other'] = 0,['total'] = 0,}
    }
	
	-- inserts and overwrites string "ins" into string s at location loc without changing length.
	local function stringInsert(s, ins, loc) -- WHY DO YOU HAVE TO MESS WITH THE FORMATTING? DAMN YOU. DAMN YOU ALL TO HELL!
		--net.log('insert')
		--net.log(s)
		--net.log(ins)
		local sBefore
		if loc > 1 then
			sBefore = s:sub(1, loc-1)
		else
			sBefore = ''
		end
		local sAfter
		if (loc + ins:len() + 1) <= s:len() then
			sAfter = s:sub(loc + ins:len() + 1)
			
		else
			sAfter = ''
		end
		--net.log(table.concat({sBefore, ins, sAfter}))
		return table.concat({sBefore, ins, sAfter})
	end
	
	
	-- Creates the simple stats string.
	local function createSimpleStats(ucid, mode)
		--[[
		Summarized stats for player: "Speed", SlmodStats ID# 9:
		  | TIME: 23231.2 hours | PvP KILL/DEATH: 30300/1229 | KILLS: Air = 4132, Grnd/Sea = 3093, Friendly = 9 | LOSSES: 2331
		
		
		
		]]

		-- FUNCTION USUALLY EXPECTS A UCID.  However, overload it to directly accept a stats table!
	
        if stats[ucid] or type(ucid) == 'table' then
			local pStats
            if type(ucid) == 'string' then
				if (not mode) or mode == 'server' then
					pStats = stats[ucid]
				elseif mode == 'mission' and slmod.config.enable_mission_stats and misStats then
					pStats = misStats[ucid]
				end
			else
				pStats = ucid
			end
			if pStats then
                local ppStats
                if penStats[pStats.ucid] then
                    ppStats = penStats[pStats.ucid]
                end
				local sTbl = {}  -- faster to use table.concat.
				sTbl[#sTbl + 1] = 'Summarized stats for player: "'
				sTbl[#sTbl + 1] = pStats.names[#pStats.names]
				sTbl[#sTbl + 1] = '", SlmodStats ID# '
				sTbl[#sTbl + 1] = tostring(pStats.id)
				sTbl[#sTbl + 1] = ':\n   | TIME: '
				
				local totalTime = 0
                
                local killList = {['Ground Units'] = 0, ['Planes'] = 0, ['Helicopters'] = 0, ['Ships'] = 0, ['Buildings'] = 0}
                local pvp = {kills = 0, losses = 0}
                local losses = 0 
                for platform, times in pairs(pStats.times) do
					totalTime = totalTime + times.total
                    if times.kills then
                        for cat, catData in pairs(times.kills) do
                            if killList[cat] then
                                killList[cat] = killList[cat] + catData.total
                            end
                        end                    
                    end
                    if times.action then 
                        if times.actions.losses then
                            losses = times.actions.losses.crash + losses
                        end
                        
                        if times.actions.pvp then
                            pvp.kills = times.actions.pvp.kills + pvp.kills
                            pvp.losses = times.actions.pvp.losses + pvp.losses
                        end
                    end
				end
                
                if pStats.PvP then
                    pvp.kills = pStats.PvP.kills + pvp.kills
                    pvp.losses = pStats.PvP.losses + pvp.losses
                end
                
                if pStats.losses then
                    losses = losses + pStats.losses.crash
                end
				
				sTbl[#sTbl + 1] = string.format('%.1f', totalTime/3600)
				sTbl[#sTbl + 1] = ' hours | PvP K/D: '
				sTbl[#sTbl + 1] = tostring(pvp.kills)
				sTbl[#sTbl + 1] = '/'
				sTbl[#sTbl + 1] = tostring(pvp.losses)
				sTbl[#sTbl + 1] = ' | KILLS: Air = '
                
                local vehicleKills, planeKills, heloKills, shipKills, buildingKills = 0, 0, 0, 0 , 0
                if pStats.kills then -- paranoia if people update stats without deleting old stats. 
                    vehicleKills = pStats.kills['Ground Units'].total or 0
                    planeKills = pStats.kills['Planes'].total or 0
                    heloKills = pStats.kills['Helicopters'].total or 0
                    shipKills = pStats.kills['Ships'].total or 0
                    buildingKills = pStats.kills['Buildings'].total or 0
                end
				local airKills = killList.Planes + killList.Helicopters + (planeKills + heloKills)
				local surfaceKills = killList['Ground Units'] + killList.Ships + killList.Buildings + (vehicleKills + shipKills + buildingKills)
				local friendlyKills =  0
				if ppStats then
                    friendlyKills = #ppStats.friendlyKills
                end

				sTbl[#sTbl + 1] = tostring(airKills)
				sTbl[#sTbl + 1] = ', Grnd/Sea = '
				sTbl[#sTbl + 1] = tostring(surfaceKills)
				sTbl[#sTbl + 1] = ', friendly = '
				sTbl[#sTbl + 1] = tostring(friendlyKills)
				sTbl[#sTbl + 1] = ' | LOSSES: '
				sTbl[#sTbl + 1] = tostring(losses)
				
				return table.concat(sTbl)
			end
		end
	end
	
	--Creates the detailed stats page(s).
	local function createDetailedStats(ucid, mode, ac)
        
		local function makeKillsColumn(kills)
			local types = {}
			for typeName, typeKills in pairs(kills) do
				if typeName ~= 'total' then
					types[#types + 1] = typeName
				end
			end
			table.sort(types)
			local killsStrings = {}
			for i = 1, #types do
				killsStrings[#killsStrings + 1] = types[i] ..' = ' .. tostring(kills[types[i]])	
			end
			return killsStrings
		end
        
		if stats[ucid] or type(ucid) == 'table' then
			local pStats
			if type(ucid) == 'string' then
				if (not mode) or mode == 'server' then
					pStats = stats[ucid]
				elseif mode == 'mission' and slmod.config.enable_mission_stats and misStats then
					pStats = misStats[ucid]
				end
			else
				pStats = ucid
			end
			if pStats then
                --slmod.info('in pStats') 
				local p1Tbl = {}  -- faster to use table.concat.
				p1Tbl[#p1Tbl + 1] = 'Stats for player: "'
				p1Tbl[#p1Tbl + 1] = pStats.names[#pStats.names]
				p1Tbl[#p1Tbl + 1] = '", SlmodStats ID# '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.id)
				p1Tbl[#p1Tbl + 1] = ':\n\nFLIGHT TIMES (HOURS): '
                local ins = #p1Tbl + 1
                p1Tbl[#p1Tbl + 1] = '\n    NAME                  IN AIR                TOTAL\n'
				local platforms = {}
				for platformName, timeTable in pairs(pStats.times) do
					if (ac and ac == platformName) or not ac then
                       platforms[#platforms + 1] = platformName
                    end
				end
                --slmod.info('sort plat') 
				table.sort(platforms)    
                local tTime = 0
                local aTime = 0
                local killList = slmod.deepcopy(commonStatTbl)
                local pvp = {kills = 0, losses = 0}
				local losses = {crash = 0, eject = 0, pilotDeath = 0}
                --slmod.info('do plat') 
				for i = 1, #platforms do
					--slmod.info(i)
                    --slmod.info(platforms[i])
                    local line = '                                                                                                                             \n'
					line = stringInsert(line, platforms[i], 5)  -- insert platform name.
                    aTime =  pStats.times[platforms[i]].inAir + aTime
                    tTime =  pStats.times[platforms[i]].total + tTime
					local inAirTime = string.format('%.2f', pStats.times[platforms[i]].inAir/3600)
					local totalTime = string.format('%.2f', pStats.times[platforms[i]].total/3600)
					line = stringInsert(line, inAirTime, 27)  -- insert inAirTime
					line = stringInsert(line, totalTime, 49)  -- insert totalTime
					p1Tbl[#p1Tbl + 1] = line
                    --slmod.info('plat kills')
                    if pStats.times[platforms[i]].kills then
                        for cat, catData in pairs(pStats.times[platforms[i]].kills) do
                            if killList[cat] and type(catData) == 'table' then
                                for killType, killNum in pairs(catData) do
                                    if killList[cat][killType] then
                                       killList[cat][killType] = killList[cat][killType] + killNum -- add to the killType
                                    end                                    
                                end
                            end
                        end                    
                    end
                    --slmod.info('actions')
                    if pStats.times[platforms[i]].actions then 
                        --slmod.info('losses')
                        if pStats.times[platforms[i]].actions.losses then
                            losses.eject = pStats.times[platforms[i]].actions.losses.eject + losses.eject
                            losses.crash = pStats.times[platforms[i]].actions.losses.crash + losses.crash
                            losses.pilotDeath = pStats.times[platforms[i]].actions.losses.pilotDeath + losses.pilotDeath
                        end
                        --slmod.info('pvp')
                        if pStats.times[platforms[i]].actions.pvp then
                            pvp.kills = pStats.times[platforms[i]].actions.pvp.kills + pvp.kills
                            pvp.losses = pStats.times[platforms[i]].actions.pvp.losses + pvp.losses
                        end
                    end
                    
                        
                    
				end
                --slmod.info('do kills') 
                table.insert(p1Tbl, ins, ' Total Flight: ' .. string.format('%.2f', aTime/3600) .. '  Overall: ' .. string.format('%.2f', tTime/3600))
				p1Tbl[#p1Tbl + 1] = '\nKILLS:\n     GROUND                PLANES                HELOS                 SHIPS             BUILDINGS\n'
                if pStats.kills and not ac then -- new tables for this won't exist, add it to old list if applicable
                    for cat, catData in pairs(pStats.kills) do
                        if killList[cat] and type(catData) == 'table' then
                            for killType, killNum in pairs(catData) do
                                if killList[cat][killType] then
                                   killList[cat][killType] = killList[cat][killType] + killNum -- add to the killType
                                end                                    
                            end
                        end
                    end   
                end
				local vehicleKillsStrings = makeKillsColumn(killList['Ground Units'])
				local planeKillsStrings = makeKillsColumn(killList.Planes)
				local heloKillsStrings = makeKillsColumn(killList.Helicopters)
				local shipKillsStrings = makeKillsColumn(killList.Ships)
				local buildingKillsStrings = makeKillsColumn(killList.Buildings)
				
				--slmod.info(slmod.tableshow(vehicleKillsStrings))
				--slmod.info(slmod.tableshow(planeKillsStrings))
				--slmod.info(slmod.tableshow(heloKillsStrings))
				--slmod.info(slmod.tableshow(shipKillsStrings))
				--slmod.info(slmod.tableshow(buildingKillsStrings))
				-- probably could simplify this to just base columns off of #vehicleKillsStrings
				local maxSize = 0
				if #vehicleKillsStrings > maxSize then
					maxSize = #vehicleKillsStrings
				end
				if #planeKillsStrings > maxSize then
					maxSize = #planeKillsStrings
				end
				if #heloKillsStrings > maxSize then
					maxSize = #heloKillsStrings
				end
				if #shipKillsStrings > maxSize then
					maxSize = #shipKillsStrings
				end
				if #buildingKillsStrings > maxSize then
					maxSize = #buildingKillsStrings
				end
				for i = 1, maxSize do
					--net.log(i)
					local line = '                                                                                                                    \n'
					if vehicleKillsStrings[i] then
						--net.log('vehicle')
						line = stringInsert(line, vehicleKillsStrings[i], 5)
					end
					--net.log(line)
					if planeKillsStrings[i] then
						--net.log('planes')
						line = stringInsert(line, planeKillsStrings[i], 24) --28
					end
					--net.log(line)
					if heloKillsStrings[i] then
						--net.log('helo')
						line = stringInsert(line, heloKillsStrings[i], 46) -- 50
					end
					--net.log(line)
					if shipKillsStrings[i] then
						--net.log('ships')
						line = stringInsert(line, shipKillsStrings[i], 66) --72
					end		
					--net.log(line)					
					if buildingKillsStrings[i] then
						--net.log('buildings')
						line = stringInsert(line, buildingKillsStrings[i], 88) --92
					end								
					--net.log(line)
					p1Tbl[#p1Tbl + 1] = line
				end
							
				p1Tbl[#p1Tbl + 1] = '---------------------------------------------------------------------------------------------------------------------------\n'
				local totalsLine = 'TOTALS:                                                                                                             '
				totalsLine = stringInsert(totalsLine, tostring(killList['Ground Units'].total), 10)
				totalsLine = stringInsert(totalsLine, tostring(killList.Planes.total), 36)
				totalsLine = stringInsert(totalsLine, tostring(killList.Helicopters.total), 62)
				totalsLine = stringInsert(totalsLine, tostring(killList.Ships.total), 88)
				totalsLine = stringInsert(totalsLine, tostring(killList.Buildings.total), 110)
				p1Tbl[#p1Tbl + 1] = totalsLine
				
                local displayPenStats = penStats[pStats.ucid] or {friendlyHits = {}, friendlyKills = {}, friendlyCollisionHits = {}, friendlyCollisionKills = {}}
				p1Tbl[#p1Tbl + 1] = '\n\nFRIENDLY FIRE:\n              hits: '
				p1Tbl[#p1Tbl + 1] = tostring(#displayPenStats.friendlyHits)
				p1Tbl[#p1Tbl + 1] = ';        kills: '
				p1Tbl[#p1Tbl + 1] = tostring(#displayPenStats.friendlyKills)
				p1Tbl[#p1Tbl + 1] = ';  Friendly collision hits: '
				
				local cHits -- old stats may not have collision hits/kills
				if displayPenStats.friendlyCollisionHits then
					cHits = #displayPenStats.friendlyCollisionHits
				else
					cHits = 0
				end
				
				p1Tbl[#p1Tbl + 1] = tostring(cHits)
				p1Tbl[#p1Tbl + 1] = ';  Friendly collision kills: '
				
				local cKills -- old stats may not have collision hits/kills
				if displayPenStats.friendlyCollisionKills then
					cKills = #displayPenStats.friendlyCollisionKills
				else
					cKills = 0
				end
		
				p1Tbl[#p1Tbl + 1] = tostring(cKills)
				p1Tbl[#p1Tbl + 1] = ';'
                 if pStats.PvP and not ac then
                    pvp.kills = pStats.PvP.kills + pvp.kills
                    pvp.losses = pStats.PvP.losses + pvp.losses
                end
                
                if pStats.losses and not ac then
                    losses.crash = losses.crash + pStats.losses.crash
                    losses.pilotDeath = losses.pilotDeath + pStats.losses.pilotDeath
                    losses.eject = losses.eject + pStats.losses.eject
                end
				
				p1Tbl[#p1Tbl + 1] = '\nPLAYER VS. PLAYER:\n    Kills: '
				p1Tbl[#p1Tbl + 1] = tostring(pvp.kills)
				p1Tbl[#p1Tbl + 1] = ';  Losses: '
				p1Tbl[#p1Tbl + 1] = tostring(pvp.losses)
				p1Tbl[#p1Tbl + 1] = ';\n\n'

				p1Tbl[#p1Tbl + 1] = 'LOSSES:\n    Crashes: '
				p1Tbl[#p1Tbl + 1] = tostring(losses.crash)
				p1Tbl[#p1Tbl + 1] = ';  Ejections: '
				p1Tbl[#p1Tbl + 1] = tostring(losses.eject)
				p1Tbl[#p1Tbl + 1] = ';  Pilot Deaths: '
				p1Tbl[#p1Tbl + 1] = tostring(losses.pilotDeath)
				p1Tbl[#p1Tbl + 1] = ';\n\n'
				-- END OF FIRST PAGE
				---------------------------------------
				--slmod.info('page 2') 
				local p2Tbl = {}
				p2Tbl[#p2Tbl + 1] = 'WEAPONS DATA (Note- due to a bug in DCS, some weapon\'s hits cannot be properly counted for multiplayer clients.)\n'
				-- sort weapons in alphabetical order
				local weaponNames = {}
                local weaponDat = {}
                --slmod.info('common weaps') 
				for acName, acTbl in pairs(pStats.times) do
                     if (ac and ac == acName) or not ac then 
                        if acTbl.weapons then 
                            for wepName, wepData in pairs(acTbl.weapons) do
                                if not weaponDat[wepName] then
                                    weaponDat[wepName] = wepData
                                    weaponNames[#weaponNames + 1] = wepName
                                else
                                    for wepStat, wepVal in pairs(wepData) do
                                        if type(wepVal) == 'number' then 
                                            weaponDat[wepName][wepStat] = weaponDat[wepName][wepStat] + wepVal
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                --slmod.info('do weaps') 
                if pStats.weapons and not ac then -- fix weapon stats if information is available
                    for weaponName, weaponData in pairs(pStats.weapons) do
                        if not weaponDat[weaponName] then
                            weaponDat[weaponName] = weaponData
                            weaponNames[#weaponNames + 1] = weaponName

                        else
                            for wepStat, wepVal in pairs(weaponData) do
                                if type(wepVal) == 'number' then 
                                    weaponDat[weaponName][wepStat] = weaponDat[weaponName][wepStat] + wepVal
                                end
                            end
                        end
                    end
                end
                --slmod.info('sort weaps') 
				table.sort(weaponNames)  -- put in alphabetical order
				for i = 1, #weaponNames do
					local line = '                                                                                                                     \n'
					line = stringInsert(line, weaponNames[i], 1)
					line = stringInsert(line, 'fired = ' .. tostring(weaponDat[weaponNames[i]].shot), 22)
					line = stringInsert(line, 'hit = ' .. tostring(weaponDat[weaponNames[i]].hit), 44)
					line = stringInsert(line, 'kills = ' .. tostring(weaponDat[weaponNames[i]].kills), 66)
					line = stringInsert(line, 'object hits = ' .. tostring(weaponDat[weaponNames[i]].numHits), 84)
					p2Tbl[#p2Tbl + 1] = line
				end
				return table.concat(p1Tbl), table.concat(p2Tbl)
			end
		end
	end
	
	
	
	-------------------------------------------------------------------------------------------------------------
	function slmod.create_SlmodStatsMenu()
		-- stats menu show commands
		local statsShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-stats',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = false,
				}
			}
		}
		
		local statsItems = {}
		
		-- create the menu.
		SlmodStatsMenu = SlmodMenu.create{ 
			showCmds = statsShowCommands, 
			scope = {
				coa = 'all'
			}, 
			options = {
				display_time = 30, 
				display_mode = 'text', 
				title = 'SlmodStats Multiplayer Statistics System', 
				privacy = {access = true, show = true}
			}, 
			items = statsItems,
			modesByUcid = {}, -- keeps track of 'mission' or 'server' stats modes for players.
			statsModes = {'mission', 'server'},
		}
		
		-- Not necessarily the best way to do this...
		-- This and the MOTD really demonstrate the need for dynamic titles or titles-by-player.
		local oldStatsShow = SlmodStatsMenu.show
		SlmodStatsMenu.show = function(self, client_id, show_scope)
			if slmod.clients[client_id] and slmod.clients[client_id].ucid then
				local mode = 'server'  -- default
				if self.modesByUcid[slmod.clients[client_id].ucid] then
					mode = self.modesByUcid[slmod.clients[client_id].ucid]
				end
				self.options.title = 'SlmodStats Multiplayer Statistics System (currently showing ' .. mode .. ' stats)'
			else
				slmod.error('Error showing stats menu: No client for id ' .. tostring(client_id))
				self.options.title = 'SlmodStats Multiplayer Statistics System'  -- reset
			end
			
			return oldStatsShow(self, client_id, show_scope)
		end
		
		
		----------------------------------------------------------------------------------------------------------
		-- Create the SlmodStatsMenu items.
		
		
		---------------------------------------------------------------------------------------------------------------------------------
		-- first item, -stats show
		local showVars = {}
		showVars.menu = SlmodStatsMenu
		showVars.description = 'Say in chat "-stats show" for a stats summary for all currently connected players.'
		showVars.active = true
		showVars.options = {
			display_mode = 'text', 
			display_time = 30, 
			privacy = {
				access = true, 
				show = true
			}
		}
		showVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word',
					text = 'show',
					required = true
				}
			},
			
			[2] = {
				[1] = { 
					type = 'word', 
					text = '-show',
					required = true
				},
				[2] = { 
					type = 'word', 
					text = 'stats',
					required = true
				}
			}	
		} 
		
		showVars.onSelect = function(self, vars, clientId)
			
			-- get stats for all currently connected players.
			local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
			local statsToUse = stats
			if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
				statsToUse = misStats
			end
			
			local playerStats = {}
			for id, clientInfo in pairs(slmod.clients) do
				if statsToUse[clientInfo.ucid] then
					playerStats[#playerStats + 1] = statsToUse[clientInfo.ucid]
				end
			end
			
			-- sort in alphabetical order by player name.
			table.sort(playerStats, function (pStat1, pStat2) 
				return pStat1.names[#pStat1.names] < pStat2.names[#pStat2.names] 
			end)
			
			local msgTbl = {''}  -- empty string just in case...
			--build message string
			for i = 1, #playerStats do
				msgTbl[#msgTbl + 1] = tostring(createSimpleStats(playerStats[i]))
				msgTbl[#msgTbl + 1] = '\n'
			end
			
			local msg = table.concat(msgTbl)
			slmod.scopeMsg(msg, self.options.display_time, self.options.display_mode, {clients = {clientId}})
			
		end
		statsItems[#statsItems + 1] = SlmodMenuItem.create(showVars)
		
		
		---------------------------------------------------------------------------------------------------------------------------------
		-- second item, -stats me
		local statsMeVars = {}
		statsMeVars.menu = SlmodStatsMenu
		statsMeVars.description = 'Say in chat "-stats me" for a short summary of your stats.'
		statsMeVars.active = true
		statsMeVars.options = {
			display_mode = 'text', 
			display_time = 15, 
			privacy = {
				access = true, 
				show = true
			}
		}
		statsMeVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word',
					text = 'me',
					required = true
				}
			},
			
			[2] = {
				[1] = { 
					type = 'word', 
					text = '-statsme',
					required = true
				}
			}	
		} 
		
		statsMeVars.onSelect = function(self, vars, clientId)
			local requester = slmod.clients[clientId]
			if requester then
				
				local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
				
				if stats[requester.ucid] then
					local msg = createSimpleStats(requester.ucid, requesterMode)
					if msg then
						--slmod.info(msg)
						slmod.scopeMsg(msg, self.options.display_time, self.options.display_mode, {clients = {clientId}})
					end
				else
					slmod.error('in statsMeVars.onSelect, requester with UCID ' .. tostring(requester.ucid) .. ' does not exist in stats!')
				end
			else
				slmod.error('in statsMeVars.onSelect, requester with clientId ' .. tostring(clientId) .. ' does not exist in slmod.clients!')
			end
		end
		statsItems[#statsItems + 1] = SlmodMenuItem.create(statsMeVars)
		
		
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- third item, -full stats me
		local fullStatsMeVars = {}
		fullStatsMeVars.menu = SlmodStatsMenu
		fullStatsMeVars.description = 'Say in chat "-full stats me" for a full description of your stats.'
		fullStatsMeVars.active = true
		fullStatsMeVars.options = {
			display_mode = 'text', 
			display_time = 50, 
			privacy = {
				access = true, 
				show = true
			}
		}
		fullStatsMeVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-ful',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'stats',
					required = true
				}, 
				[3] = { 
					type = 'word',
					text = 'me',
					required = true
				}
			},
			
			[2] = {
				[1] = { 
					type = 'word', 
					text = '-ful',
					required = true
				},
				[2] = { 
					type = 'word', 
					text = 'statsme',
					required = true
				}
			},
			[3] = {
				[1] = { 
					type = 'word', 
					text = '-fullstatsme',
					required = true
				}
			}				
		} 
		
		fullStatsMeVars.onSelect = function(self, vars, clientId)
			local requester = slmod.clients[clientId]
			if requester then
				if stats[requester.ucid] then  -- this check invalid if server stats ever optionally disabled.
					
					local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
				
					local page1, page2 = createDetailedStats(requester.ucid, requesterMode)
					if page1 and page2 then
						slmod.scopeMsg(page1, self.options.display_time/2, self.options.display_mode, {clients = {clientId}})
						slmod.scheduleFunction(slmod.scopeMsg, {page2, self.options.display_time/2, self.options.display_mode, {clients = {clientId}}}, DCS.getModelTime() + self.options.display_time/2)
					end
				else
					slmod.error('in fullStatsMeVars.onSelect, requester with UCID ' .. tostring(requester.ucid) .. ' does not exist in stats!')
				end
			else
				slmod.error('in fullStatsMeVars.onSelect, requester with clientId ' .. tostring(clientId) .. ' does not exist in slmod.clients!')
			end
		end
		statsItems[#statsItems + 1] = SlmodMenuItem.create(fullStatsMeVars)
		
		---------------------------------------------------------------------------------------------------------------------------------------
		
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- fourth item, -stats for id <number>
		local statsForIdVars = {}
		statsForIdVars.menu = SlmodStatsMenu
		statsForIdVars.description = 'Say in chat "-stats id <number>", where "<number>" is a player\'s Stats ID#, to get summarized stats for that player.'
		statsForIdVars.active = true
		statsForIdVars.options = {
			display_mode = 'text', 
			display_time = 15, 
			privacy = {
				access = true, 
				show = true
			}
		}
		statsForIdVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'for',
					required = false
				}, 
				[3] = { 
					type = 'word',
					text = 'id',
					required = true
				},
				[4] = { 
					type = 'number',
					varname = 'id',
					required = true
				}
			}				
		} 
		
		statsForIdVars.onSelect = function(self, vars, clientId)
			if vars and vars.id then
				
                local pId = vars.id
				local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
				--slmod.info('stats byId select')
                --slmod.info(pId)
				local statsToUse = stats
				if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
					statsToUse = misStats
				end

				for ucid, pStats in pairs(statsToUse) do -- this is inefficient- maybe I need to make a stats by id table.
					if type(pStats) == 'table' and pStats.id and pStats.id == pId then  -- found the id#.
						--slmod.info('stats found create')
                        local msg = createSimpleStats(pStats)
						if msg then
							slmod.scopeMsg(msg, self.options.display_time, self.options.display_mode, {clients = {clientId}})
						end
					end
				end
			end
		end
		
		statsItems[#statsItems + 1] = SlmodMenuItem.create(statsForIdVars)
		
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- fifth item, -stats for name <string>
		local statsForNameVars = {}
		statsForNameVars.menu = SlmodStatsMenu
		statsForNameVars.description = 'Say in chat "-stats name <player name>", to get summarized stats for that player (Only works for connected clients).'
		statsForNameVars.active = true
		statsForNameVars.options = {
			display_mode = 'text', 
			display_time = 15, 
			privacy = {
				access = true, 
				show = true
			}
		}
		statsForNameVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'for',
					required = false
				}, 
				[3] = { 
					type = 'word',
					text = 'name',
					required = true
				},
				[4] = { 
					type = 'text',
					varname = 'playerName',
					required = true
				}
			}				
		} 
		
		statsForNameVars.onSelect = function(self, vars, clientId)
			if vars and vars.playerName then
				local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
				for id, client in pairs(slmod.clients) do
					if client.name and client.name == vars.playerName then
						if client.ucid and stats[client.ucid] then
							local msg = createSimpleStats(stats[client.ucid], requesterMode)
							if msg then
								slmod.scopeMsg(msg, self.options.display_time, self.options.display_mode, {clients = {clientId}})
							end
						end
					end
				end
			end
		end	
		
		statsItems[#statsItems + 1] = SlmodMenuItem.create(statsForNameVars)
		
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- sixth item, -full stats for id <number>
		local fullStatsForIdVars = {}
		fullStatsForIdVars.menu = SlmodStatsMenu
		fullStatsForIdVars.description = 'Say in chat "-full stats id <number>", where "<number>" is a player\'s Stats ID#, to get FULL stats for that player.'
		fullStatsForIdVars.active = true
		fullStatsForIdVars.options = {
			display_mode = 'text', 
			display_time = 50, 
			privacy = {
				access = true, 
				show = true
			}
		}
		fullStatsForIdVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-full',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'stats',
					required = true
				}, 
				--[3] = { 
				--	type = 'word', 
				--	text = 'for',
				--	required = false
				--}, 
				[3] = { 
					type = 'word',
					text = 'id',
					required = true
				},
				[4] = { 
					type = 'number',
					varname = 'id',
					required = true
				}
			}				
		} 
		
		fullStatsForIdVars.onSelect = function(self, vars, clientId)
			if vars and vars.id then
				local pId = vars.id
				--slmod.info('full stats id') 
				local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
	
				local statsToUse = stats
				if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
					statsToUse = misStats
				end
                --slmod.info(pId) 
				for ucid, pStats in pairs(statsToUse) do -- this is inefficient- maybe I need to make a stats by id table.
					if type(pStats) == 'table' and pStats.id and pStats.id == pId then  -- found the id#.
						--slmod.info('found, create fullstats') 
                        local page1, page2 = createDetailedStats(pStats)
						if page1 and page2 then
							--slmod.info(msg)
							slmod.scopeMsg(page1, self.options.display_time/2, self.options.display_mode, {clients = {clientId}})
							slmod.scheduleFunction(slmod.scopeMsg, {page2, self.options.display_time/2, self.options.display_mode, {clients = {clientId}}}, DCS.getModelTime() + self.options.display_time/2)
						end
					end
				end
			end
		end
		
		statsItems[#statsItems + 1] = SlmodMenuItem.create(fullStatsForIdVars)
		
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- seventh item, -full stats for name <player name>
		local fullStatsForNameVars = {}
		fullStatsForNameVars.menu = SlmodStatsMenu
		fullStatsForNameVars.description = 'Say in chat "-full stats name <player name>" to get FULL stats for that player (Only works for connected clients).'
		fullStatsForNameVars.active = true
		fullStatsForNameVars.options = {
			display_mode = 'text', 
			display_time = 50, 
			privacy = {
				access = true, 
				show = true
			}
		}
		fullStatsForNameVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-full',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'stats',
					required = true
				}, 
				[3] = { 
					type = 'word', 
					text = 'for',
					required = false
				}, 
				[4] = { 
					type = 'word',
					text = 'name',
					required = true
				},
				[5] = { 
					type = 'text',
					varname = 'playerName',
					required = true
				}
			}				
		} 
		
		fullStatsForNameVars.onSelect = function(self, vars, clientId)
			if vars and vars.playerName then
				for id, client in pairs(slmod.clients) do
					if client.name and client.name == vars.playerName then
						
						local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
						local statsToUse = stats
						if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
							statsToUse = misStats
						end
					
						if client.ucid and statsToUse[client.ucid] then
							local page1, page2 = createDetailedStats(statsToUse[client.ucid])
							if page1 and page2 then
								--slmod.info(msg)
								slmod.scopeMsg(page1, self.options.display_time/2, self.options.display_mode, {clients = {clientId}})
								slmod.scheduleFunction(slmod.scopeMsg, {page2, self.options.display_time/2, self.options.display_mode, {clients = {clientId}}}, DCS.getModelTime() + self.options.display_time/2)
							end
						end
					end
				end
			end
		end	
		
		statsItems[#statsItems + 1] = SlmodMenuItem.create(fullStatsForNameVars)
        
        local aircraftStatsMe = {}
		aircraftStatsMe.menu = SlmodStatsMenu
		aircraftStatsMe.description = 'Say in chat "-stats ac me" to display stats for your current aircraft'
		aircraftStatsMe.active = true
		aircraftStatsMe.options = {
			display_mode = 'text', 
			display_time = 50, 
			privacy = {
				access = true, 
				show = true
			}
		}
		aircraftStatsMe.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'ac',
					required = true
				}, 
				[3] = { 
					type = 'word', 
					text = 'me',
					required = true
				}
			}				
		} 
		
		aircraftStatsMe.onSelect = function(self, vars, clientId)
			local requester = slmod.clients[clientId]
			if requester then
				if stats[requester.ucid] then  -- this check invalid if server stats ever optionally disabled.
					local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
                    local statsToUse = stats
                    if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
                        statsToUse = misStats
                    end
                    local uName, seat = slmod.getClientUnitName(clientId)
                    local ac = slmod.allMissionUnitsByName[uName].objtype
                    if seat > 0 then
                        ac = multiCrewNameCheck(ac, seat)
                    end
                    local page1, page2 = createDetailedStats(statsToUse[slmod.clients[clientId].ucid], requesterMode, ac)
                    if page1 and page2 then
								--slmod.info(msg)
                        slmod.scopeMsg(page1, self.options.display_time/2, self.options.display_mode, {clients = {clientId}})
                        slmod.scheduleFunction(slmod.scopeMsg, {page2, self.options.display_time/2, self.options.display_mode, {clients = {clientId}}}, DCS.getModelTime() + self.options.display_time/2)
                    end
                end
            end
		end	
		
		statsItems[#statsItems + 1] = SlmodMenuItem.create(aircraftStatsMe)
        
        -- 9th item, -full stats for name <player name>
		local detailedPenaltyScoreMe = {}
		detailedPenaltyScoreMe.menu = SlmodStatsMenu
		detailedPenaltyScoreMe.description = 'Say in chat "-stats penalty" to get detailed information for your current penalty point status on the server.'
		detailedPenaltyScoreMe.active = true
		detailedPenaltyScoreMe.options = {
			display_mode = 'text', 
			display_time = 30, 
			privacy = {
				access = true, 
				show = true
			}
		}
		detailedPenaltyScoreMe.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'penalty',
					required = true
				}, 
			},
			[2] = {
				[1] = { 
					type = 'word', 
					text = '-stats',
					required = true
				}, 
				[2] = { 
					type = 'word', 
					text = 'pen',
					required = true
				}, 
            },
		} 
		
		detailedPenaltyScoreMe.onSelect = function(self, vars, clientId)
			local requester = slmod.clients[clientId]
			if requester then
				if stats[requester.ucid] then  -- this check invalid if server stats ever optionally disabled.
                    --slmod.info(requester.ucid)
                    local score, detail = slmod.getUserScore(requester.ucid, true)
                    local penScore = slmod.playerPenaltyScoreDisplay(detail, score, {name = requester.name})
                    
                    slmod.scopeMsg(penScore, self.options.display_time, self.options.display_mode, {clients = {clientId}})
                end
            end
		end	
		
        if slmod.config.autoAdmin.userCanGetOwnDetailedPenalty then 
            statsItems[#statsItems + 1] = SlmodMenuItem.create(detailedPenaltyScoreMe)
        end
		
		---------------------------------------------------------------------------------------------------------------------------------------
		
		if slmod.config.enable_mission_stats then
			---------------------------------------------------------------------------------------------------------------------------------------
			-- Eighth item, -stats mode switch
			local statsModeSwitchVars = {}
			statsModeSwitchVars.menu = SlmodStatsMenu
			statsModeSwitchVars.description = 'Say in chat "-stats mode" to cycle between different stats modes (such as "server" or "mission").'
			statsModeSwitchVars.active = true
			statsModeSwitchVars.options = {
				display_mode = 'chat', 
				display_time = 1, 
				privacy = {
					access = true, 
					show = true
				}
			}
			statsModeSwitchVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-stat',
						required = true
					}, 
					[2] = { 
						type = 'word', 
						text = 'mod',
						required = true
					}, 
					[3] = { 
						type = 'word', 
						text = 'swit',
						required = false
					}, 
				}				
			} 
			
			statsModeSwitchVars.onSelect = function(self, vars, clientId)
				local clientModes = self:getMenu().modesByUcid
				local statsModes = self:getMenu().statsModes
				local clientUcid = slmod.clients[clientId].ucid
				local curMode = clientModes[clientUcid] or 'server'
				
				-- find next mode.. this code cycles through them.
				local modeNum = 1
				for i = 1, #statsModes - 1 do
					if statsModes[i] == curMode then
						modeNum = i + 1
						break
					end
				end
				
				local newMode = statsModes[modeNum]
				clientModes[clientUcid] = newMode -- changes it in modesByUcid.
				slmod.scopeMsg('Stats mode switched to ' .. newMode, self.options.display_time, self.options.display_mode, {clients = {clientId}})
			end
			
			statsItems[#statsItems + 1] = SlmodMenuItem.create(statsModeSwitchVars)
			
			---------------------------------------------------------------------------------------------------------------------------------------
		end
		
		
	end
	
	-- ***END OF STATS USER INTERFACE***


	
end


slmod.info('SlmodStats.lua loaded.')