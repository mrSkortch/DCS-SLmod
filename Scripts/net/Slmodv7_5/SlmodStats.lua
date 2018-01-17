slmod.stats = slmod.stats or {}  -- make table anyway, need it.
do
	slmod.info('loadStats')
    -------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- stats file initialization
	local statsDir = slmod.config.stats_dir or lfs.writedir() .. [[Slmod\]]
	
	local stats -- server stats, nil at first.
	local metaStats -- slmod meta stats
   
	------------------------------------------------------------------------------------------
	-- new slmod.stats.resetStatsFile function.
	local statsF -- stats file handle; upvalue of slmod.stats.resetStatsFile.
    local metaStatsF -- metaStats file handle
    
    local misStats = {}  -- by-mission stats
    local misStatsF  -- mission stats file
    
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
            fileF = metaStatsF
            fileName = '\\SlmodMetaStats.lua'
            statData = metaStats
            lName = 'SlmodMetaStats'
            envName = 'metaStats'
        else 
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
				local statsFunc, err1 = loadstring(statsS)
				prevStatsF:close()
               -- slmod.info('prevStatsF Close')
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
							slmod.info('loading stats file ' .. lstatsDir .. lName)
                            --slmod.info('using '.. lName .. ' as defined in ' .. lstatsDir .. lName)
                            statData = env[envName]
                            --slmod.info('stats assigned')
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
				slmod.warning('Unable to open ' .. lName .. ' , will make a new ' .. lName .. ' file.')	
			end
		end
        if not statData then
            statData = {}
        end
        if l == 'meta' then
            local newStatsS = slmod.serialize('metaStats', statData) ..'\n'
            metaStatsF = io.open(lstatsDir .. fileName, 'w')
            metaStatsF:write(newStatsS)
        elseif l == 'mission' then
            local newStatsS = slmod.serialize('misStats', statData) ..'\n'
            fileF = io.open(lstatsDir .. fileName, 'w')
            fileF:write(newStatsS)
            fileF:close()
            fileF = nil
        elseif not l then
            
            --Now, stats should be opened, or if not run, at least backed up..  Now, write over the old stats and return a file handle.
            local newStatsS = slmod.serialize('stats', statData) ..'\n'
            statsF = io.open(lstatsDir .. fileName, 'w')
            statsF:write(newStatsS)
        end

        return statData
	end
    stats = slmod.stats.resetFile()
    metaStats = slmod.stats.resetFile('meta')
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
					makeStatsTableKeys(key, val)
				end
			end
		end
		
		makeStatsTableKeys('stats', stats)
		
	end	

	------------------------------------------------------------------------------------------------------
	local metaStatsTableKeys = {}  -- stores strings that corresponds to table indexes within metaStats... needed for updating file.
	metaStatsTableKeys[metaStats] = 'metaStats'
	do
		local function makeMetaStatsTableKeys(levelKey, t)
            for key, val in pairs(t) do
				if type(val) == 'table' and type(key) == 'string' then
					key = levelKey .. '[' .. slmod.basicSerialize(key) .. ']'
					metaStatsTableKeys[val] = key  -- works because each table only exists once in Slmod stats- it's REQUIRED!!! DO NOT FORGET THIS!
					makeMetaStatsTableKeys(key, val)
				end
			end
		end
		
		makeMetaStatsTableKeys('metaStats', metaStats)
		
	end	
	-- call this function each time a value in stats needs to be changed...
	-- t: the table in metaStats that this value belongs under
	function slmod.stats.changeMetaStatsValue(t, key, newValue)
        if not t then
			slmod.error('Invalid metaStats table specified!')
			return
		end
		if type(newValue) == 'table' then
			metaStatsTableKeys[newValue] = metaStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']'
		end

		t[key] = newValue
		if metaStatsF then
            local metaStatsChangeString = metaStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. '] = ' .. slmod.oneLineSerialize(newValue) .. '\n'
            metaStatsF:write(metaStatsChangeString)
			--slmod.info(metaStatsChangeString, true)
		end
	end
    
	-- call this function each time a value in stats needs to be changed...
	-- t: the table in stats that this value belongs under
	function slmod.stats.changeStatsValue(t, key, newValue)
		--slmod.info('changeStatsValue')
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
		--slmod.info(statsChangeString, true)
	end
	
	--------------------------------------------------------------------------------------------------
	-- Create the nextIdNum variable, so stats knows the next stats ID number it can use for a new player.
	local nextIDNum = 1
	
	for ucid, entry in pairs(stats) do  -- gets the next free ID num.
		if type(entry) == 'table' and entry.id and entry.id >= nextIDNum then
			nextIDNum = entry.id + 1
		end
	end
	---------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------
	-- function called to add a new player to SlmodStats.
	local function createNewPlayer(ucid, name)
        slmod.stats.changeStatsValue(stats, ucid, {})
		slmod.stats.changeStatsValue(stats[ucid], 'names', { [1] = name })
		slmod.stats.changeStatsValue(stats[ucid], 'id', nextIDNum)
		
		nextIDNum = nextIDNum + 1
		
		slmod.stats.changeStatsValue(stats[ucid], 'times', {})
		slmod.stats.changeStatsValue(stats[ucid], 'weapons', {})
		
		slmod.stats.changeStatsValue(stats[ucid], 'kills', {})
		slmod.stats.changeStatsValue(stats[ucid].kills, 'Ground Units', 
		{
			['SAM'] = 0, 
			['AAA'] = 0, 
			['EWR'] = 0, 
			['Arty/MLRS'] = 0, 
			['Infantry'] = 0, 
			['Tanks'] = 0, 
			['IFVs'] = 0,
			['APCs'] = 0, 
			['Unarmored'] = 0, 
			['Forts'] = 0, 
			['Other'] = 0,
			['total'] = 0,
		})
		slmod.stats.changeStatsValue(stats[ucid].kills, 'Planes', 
		{
			['Fighters'] = 0,
			['Attack'] = 0,
			['Bombers'] = 0,
			['Support'] = 0,
			['UAVs'] = 0,
			['Transports'] = 0,
			['Other'] = 0,
			['total'] = 0,
		})
		slmod.stats.changeStatsValue(stats[ucid].kills, 'Helicopters', 
		{
			['Attack'] = 0,
			['Utility'] = 0,
			['Other'] = 0,
			['total'] = 0,
		})
		slmod.stats.changeStatsValue(stats[ucid].kills, 'Ships', 
		{
			['Warships'] = 0,
			['Subs'] = 0,
			['Unarmed'] = 0,
			['Other'] = 0,
			['total'] = 0,
		})
		slmod.stats.changeStatsValue(stats[ucid].kills, 'Buildings', 
		{
			['Static'] = 0,
			['Other'] = 0,
			['total'] = 0,
		})
		slmod.stats.changeStatsValue(stats[ucid], 'friendlyKills', {})
		slmod.stats.changeStatsValue(stats[ucid], 'friendlyHits', {})
		slmod.stats.changeStatsValue(stats[ucid], 'friendlyCollisionHits', {})
		slmod.stats.changeStatsValue(stats[ucid], 'friendlyCollisionKills', {})
		slmod.stats.changeStatsValue(stats[ucid], 'PvP', {kills = 0, losses = 0})
		slmod.stats.changeStatsValue(stats[ucid], 'losses', {crash = 0, eject = 0, pilotDeath = 0})
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
			--slmod.info(misStatsChangeString, true)
		end
	end
	
	
	---------------------------------------------------------------------------------------------------
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
			slmod.stats.changeMisStatsValue(misStats[ucid], 'weapons', {})
			
			slmod.stats.changeMisStatsValue(misStats[ucid], 'kills', {})
			slmod.stats.changeMisStatsValue(misStats[ucid].kills, 'Ground Units', 
			{
				['SAM'] = 0, 
				['AAA'] = 0, 
				['EWR'] = 0, 
				['Arty/MLRS'] = 0, 
				['Infantry'] = 0, 
				['Tanks'] = 0, 
				['IFVs'] = 0,
				['APCs'] = 0, 
				['Unarmored'] = 0, 
				['Forts'] = 0, 
				['Other'] = 0,
				['total'] = 0,
			})
			slmod.stats.changeMisStatsValue(misStats[ucid].kills, 'Planes', 
			{
				['Fighters'] = 0,
				['Attack'] = 0,
				['Bombers'] = 0,
				['Support'] = 0,
				['UAVs'] = 0,
				['Transports'] = 0,
				['Other'] = 0,
				['total'] = 0,
			})
			slmod.stats.changeMisStatsValue(misStats[ucid].kills, 'Helicopters', 
			{
				['Attack'] = 0,
				['Utility'] = 0,
				['Other'] = 0,
				['total'] = 0,
			})
			slmod.stats.changeMisStatsValue(misStats[ucid].kills, 'Ships', 
			{
				['Warships'] = 0,
				['Subs'] = 0,
				['Unarmed'] = 0,
				['Other'] = 0,
				['total'] = 0,
			})
			slmod.stats.changeMisStatsValue(misStats[ucid].kills, 'Buildings', 
			{
				['Static'] = 0,
				['Other'] = 0,
				['total'] = 0,
			})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'friendlyKills', {})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'friendlyHits', {})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'friendlyCollisionHits', {})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'friendlyCollisionKills', {})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'PvP', {kills = 0, losses = 0})
			slmod.stats.changeMisStatsValue(misStats[ucid], 'losses', {crash = 0, eject = 0, pilotDeath = 0})
		end
	end
	---------------------------------------------------------------------------------------------------------------------
    
	-----------------------------------------------------------------------------------------------------
	function slmod.stats.onMission()  -- for creating per-mission stats.
		if slmod.config.enable_mission_stats then
			if metaStats.missionStatsFile.currentMissionFile then
                slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'previousMissionFile', metaStats.missionStatsFile.currentMissionFile)
                if metaStats.missionStatsFile.previousMissionFile then
                    slmod.stats.resetFile('mission', metaStats.missionStatsFile.previousMissionFile)
                end
                
            end
            if slmod.config.write_mission_stats_files then
				if misStatsF then  -- close if open from previous.
                    misStatsF:close()
					misStatsF = nil
				end
				
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
                slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'currentMissionFile', misStatFileName)
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
				createMisStatsPlayer(client.ucid) 
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
				createNewPlayer(ucid, name)
			else  -- check to see if name matches	
				local nameFound, nameInd
				for i = 1, #stats[ucid].names do
					if stats[ucid].names[i] == name then
						nameFound = true
						nameInd = i
						break
					end
				end
				
				if nameFound and nameInd ~= #stats[ucid].names then  -- name was previously used but is not the last one in the names table..
					newStatsNames = {}
					local newStatsNames = slmod.deepcopy(stats[ucid].names)
					table.remove(newStatsNames, nameInd)  -- resort
					newStatsNames[#stats[ucid].names] = name
					slmod.stats.changeStatsValue(stats[ucid], 'names', newStatsNames)  -- update stats table.
				elseif not nameFound then  -- a new name.
					slmod.stats.changeStatsValue(stats[ucid].names, #stats[ucid].names + 1, name)  -- update stats table.
					newName = true
				end
			end
			
			if slmod.config.enable_mission_stats then
				if not misStats[ucid] then  -- should be true in cases where stats check was true... but wait till after names has been updated.
					createMisStatsPlayer(ucid)
				elseif newName then -- update mission stats with new names too.
					slmod.stats.changeMisStatsValue(misStats[ucid].names, #misStats[ucid].names + 1, name)  -- update misStats table.
				elseif newStatsNames then
					slmod.stats.changeMisStatsValue(misStats[ucid], 'names', newStatsNames)  -- update misStats table.
				end
			end
			
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
	
	
	-------------------------------------------------------------------
	
	local function onFriendlyHit(client, tgtName, weapon)
		if slmod.config.enable_team_hit_messages then
			slmod.scopeMsg('Slmod- TEAM HIT: "' .. tostring(client.name).. '" hit friendly unit "' .. tostring(tgtName) .. '" with ' .. tostring(weapon) .. '!', 1, 'chat')
		end
		-- Chat log
		if slmod.config.chat_log and slmod.config.log_team_hits and slmod.chatLogFile then
			local wpnInfo
			if weapon then
				wpnInfo = ' with ' .. weapon .. '\n'
			else
				wpnInfo = '\n'
			end
			slmod.chatLogFile:write(table.concat{'TEAM HIT: ', os.date('%b %d %H:%M:%S '), ' {name  = ', slmod.basicSerialize(tostring(client.name)), ', ucid = ', slmod.basicSerialize(tostring(client.ucid)), ', ip = ',  slmod.basicSerialize(tostring(client.addr)), ', id = ', tostring(client.id), '} hit ', tgtName, wpnInfo})
			slmod.chatLogFile:flush()
		end
		-- autokick/autoban
		slmod.autoAdminOnOffense(client)
	end
	
	local function onFriendlyKill(client, tgtName, weapon)
		if slmod.config.enable_team_kill_messages then
			slmod.scopeMsg('Slmod- TEAM KILL: "' .. tostring(client.name).. '" killed friendly unit "' .. tostring(tgtName) .. '" with ' .. tostring(weapon) .. '!', 1, 'chat')
		end
		-- chat log
		if slmod.config.chat_log and slmod.config.log_team_kills and slmod.chatLogFile then
			local wpnInfo
			if weapon then
				wpnInfo = ' with ' .. weapon .. '\n'
			else
				wpnInfo = '\n'
			end
			slmod.chatLogFile:write(table.concat{'TEAM KILL: ', os.date('%b %d %H:%M:%S '), ' {name  = ', slmod.basicSerialize(tostring(client.name)), ', ucid = ', slmod.basicSerialize(tostring(client.ucid)), ', ip = ',  slmod.basicSerialize(tostring(client.addr)), ', id = ', tostring(client.id), '} killed ', tgtName, wpnInfo})
			slmod.chatLogFile:flush()
		end
		-- autokick/autoban
		slmod.autoAdminOnOffense(client)
	end
	
	local function onPvPKill(initName, tgtName, weapon, killerObj, victimObj)
		if slmod.config.enable_pvp_kill_messages then
			if killerObj and victimObj then
				slmod.scopeMsg('Slmod- PVP KILL: Humiliation! "' .. tostring(initName).. '" (flying a ' .. tostring(killerObj) .. ') scored a victory against "' .. tostring(tgtName) .. '" (flying a ' .. tostring(victimObj) .. ') with ' .. tostring(weapon) .. '!', 1, 'chat') 
			else
				slmod.scopeMsg('Slmod- PVP KILL: "' .. tostring(initName).. '" scored a victory against "' .. tostring(tgtName) .. '" with ' .. tostring(weapon) .. '!', 1, 'chat') 
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
		suppressDeath[unitName] = nil
	end
	
	
	local function PvPRules(killer, victim)  -- expects unitNames, returns a boolean true if it was a fair match, false otherwise, nil in case of fuck up
		local attack = {'a%-10', 'su%-25'}
		
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
	
	local shells = {}
	-- hit events
	shells["30mm HE"] = true -- What the Mi-8 gunpod fired apparently
	shells["30mm AP"] = true
	shells["12.7mm"] = true -- Also mi-8 gunpod hit event
	shells["23mm HE"] = true  -- could be a problem.... Su-25 gun pods stuck on.
	shells["30mm TP"] = true
	shells["20mm HE"] = true
	shells["PKT_7_62"] = true -- mi8 gunpod hit event
	shells["M134 7.62"] = true -- Huey hit event
	shells["MG_20x82_HEI_T"] = true --fw190
	shells["MG_20x82_API"] = true  --fw190
	shells["GSH 23 HE"] = true -- Mig-21
	shells["GSH 23 AP"] = true -- Mig-21
	
	-- shooting start and shooting end events
	shells["M_2_L1"] = true -- P-51D events... sigh
	shells["M_2_L2"] = true
	shells["M_2_L3"] = true
	shells["M_2_R1"] = true
	shells["M_2_R2"] = true
	shells["M_2_R3"] = true
	shells["GSh_23_SPUU22"] = true -- Su-25 gunpod
	shells["GSh_30_1"] = true -- Su-27/33, Mig-29A/S/G
	shells["GSh_30_2"] = true --Su-25A/T
	shells["2A42"] = true --Ka-50
	shells["GSh_23_UPK"] = true -- Ka-50 Gunpod (I think)
	shells["GAU_8"] = true -- A-10A shooting start and end shows as this
	shells["YakB_12_7"] = true -- Mi8 gunpod shooting event 50 cal
	shells["GSHG_7_62"] = true -- Mi8 gunpod shooting event
	shells["AP_30_PLAMYA"] = true -- mi8 Grenade pod shot event. 
	shells["M_134"] = true -- Huey shooting event
	shells["M_60"] = true
	shells["m3_browning"] = true --F86
	shells["MG_151_20"] = true --Fw190
	shells["MG_131"] = true --Fw190
	shells["GSH_23"] = true --Mig-21
	
	
	
	
	local function isShell(weaponName)  -- determines if the weapon was a shell.
		--slmod.info(weaponName)
		--slmod.info(shells[weaponName])
		return shells[weaponName]
	end
	
	local acft = {} -- exceptions list. For some reason mig-29A is not matching with below code because it is displayed as Mig-29.
	-- Temp fix
	acft['mig-29'] = true
	
	local function isAircraft(weaponName)  -- determines if the weapon was a aircraft.

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
			--slmod.info('here4')
			-- see if a human was involved.
			local lastHit = getHitData(deadName)
			if lastHit then  -- either a human died or an AI that was hit by a human died.
				--local lastHit = hitData[#hitData] --- at least FOR NOW, just using last hit!
				
				local hitter = lastHit.initiator
				--case 1 - deadAI, hit by human.
				if not deadClient then -- SHOULD be an AI hit by human!
					if type(hitter) == 'table' then -- it SHOULD be
						local hitterUCID = hitter.ucid
						-- add this killed unit to the human's record.
						if not lastHit.friendlyHit then
						
							if not stats[hitter.ucid].kills[deadStatsCat] then  -- should never happen
								slmod.warning('SlmodStats- had to make a new category for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
								slmod.stats.changeStatsValue(stats[hitter.ucid].kills, deadStatsCat, {})
							end
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								if not misStats[hitter.ucid].kills[deadStatsCat] then  -- should never happen
									slmod.warning('SlmodStats- Mission Stats- had to make a new category for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills, deadStatsCat, {})
								end
							end
							----------------------------------------------------------------------------------------------------------------
							
							if not stats[hitter.ucid].kills[deadStatsCat][deadStatsType] then  -- should also never happen
								slmod.warning('SlmodStats- had to make a new type category for ' .. tostring(deadStatsType) .. ' of dead unit.')
								slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], deadStatsType, 0)
							end
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								if not misStats[hitter.ucid].kills[deadStatsCat][deadStatsType] then  -- should also never happen
									slmod.warning('SlmodStats- Mission Stats- had to make a new type category for ' .. tostring(deadStatsType) .. ' of dead unit.')
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], deadStatsType, 0)
								end
							end
							----------------------------------------------------------------------------------------------------------------
							
							slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], deadStatsType, stats[hitter.ucid].kills[deadStatsCat][deadStatsType] + 1)  -- change the type kills
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], deadStatsType, misStats[hitter.ucid].kills[deadStatsCat][deadStatsType] + 1)  -- change the type kills
							end
							----------------------------------------------------------------------------------------------------------------
							
							if not stats[hitter.ucid].kills[deadStatsCat].total then  -- should also never happen
								slmod.warning('SlmodStats- had to make a new total entry for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
								slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], 'total', 0)
							end
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								if not misStats[hitter.ucid].kills[deadStatsCat].total then  -- should also never happen
									slmod.warning('SlmodStats- Mission Stats- had to make a new total entry for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], 'total', 0)
								end
							end
							----------------------------------------------------------------------------------------------------------------
							
							
							slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], 'total', stats[hitter.ucid].kills[deadStatsCat].total + 1)  -- change the total
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], 'total', misStats[hitter.ucid].kills[deadStatsCat].total + 1)  -- change the total
							end
							----------------------------------------------------------------------------------------------------------------
							
							--------------------------------------
							-- add kill for this weapon.
							local weapon = lastHit.weapon
							if weapon then
								if not stats[hitter.ucid].weapons[weapon] then  -- this weapon not in this client's database, add it.
									slmod.stats.changeStatsValue(stats[hitter.ucid].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills = 0})
								end
								slmod.stats.changeStatsValue(stats[hitter.ucid].weapons[weapon], 'kills', stats[hitter.ucid].weapons[weapon].kills + 1)
								
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									if not misStats[hitter.ucid].weapons[weapon] then  -- this weapon not in this client's database, add it.
										slmod.stats.changeMisStatsValue(misStats[hitter.ucid].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills = 0})
									end
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].weapons[weapon], 'kills', misStats[hitter.ucid].weapons[weapon].kills + 1)
								end
								----------------------------------------------------------------------------------------------------------------

							end
							--------------------------------------
							
							
						else -- teamkill
							-- { time =  1004215421, human = 'af9142dc121b941274', objCat = 'plane', objTypeName = 'F-15C'},
							--local teamKillTable = { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = lastHit.weapon}
							local weapon = lastHit.weapon
							if weapon and weapon == 'kamikaze' then  -- friendly collision kill
								if not stats[hitter.ucid].friendlyCollisionKills then -- might be needed for old stats files.
									slmod.stats.changeStatsValue(stats[hitter.ucid], 'friendlyCollisionKills', {})
								end
								slmod.stats.changeStatsValue(stats[hitter.ucid].friendlyCollisionKills, #stats[hitter.ucid].friendlyCollisionKills + 1, { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									if not misStats[hitter.ucid].friendlyCollisionKills then -- might be needed for old stats files.
										slmod.stats.changeMisStatsValue(misStats[hitter.ucid], 'friendlyCollisionKills', {})
									end
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].friendlyCollisionKills, #misStats[hitter.ucid].friendlyCollisionKills + 1, { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								end
								----------------------------------------------------------------------------------------------------------------
								
							else  -- friendly fire kill
								slmod.stats.changeStatsValue(stats[hitter.ucid].friendlyKills, #stats[hitter.ucid].friendlyKills + 1, { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].friendlyKills, #misStats[hitter.ucid].friendlyKills + 1, { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								end
								----------------------------------------------------------------------------------------------------------------
								
							end
							onFriendlyKill(hitter, deadName, weapon)
						end
						
					else
						if type(hitter) == 'table' then
							slmod.warning('SlmodStats- hitter (' .. slmod.oneLineSerialize(hitter) .. ') is not an SlmodClient, and dead unit (unitName = ' .. tostring(deadName) .. ') is not an SlmodClient!')
						else
							slmod.warning('SlmodStats- hitter (' .. tostring(hitter) .. ') is not an SlmodClient, and dead unit (unitName = ' .. tostring(deadName) .. ') is not an SlmodClient!')
						end
					end
				
				else  -- a human died
					if type(hitter) == 'table' then -- case2 - a human was killed by a human.
						if not lastHit.friendlyHit then
							if not stats[hitter.ucid].kills[deadStatsCat] then  -- should never happen
								slmod.warning('SlmodStats- had to make a new category for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
								slmod.stats.changeStatsValue(stats[hitter.ucid].kills, deadStatsCat, {})
							end
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								if not misStats[hitter.ucid].kills[deadStatsCat] then  -- should never happen
									slmod.warning('SlmodStats- Mission Stats- had to make a new category for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills, deadStatsCat, {})
								end
							end
							----------------------------------------------------------------------------------------------------------------
							
							if not stats[hitter.ucid].kills[deadStatsCat][deadStatsType] then  -- should also never happen
								slmod.warning('SlmodStats- had to make a new type category for ' .. tostring(deadStatsType) .. ' of dead unit.')
								slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], deadStatsType, 0)
							end
							slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], deadStatsType, stats[hitter.ucid].kills[deadStatsCat][deadStatsType] + 1)  -- give a kill
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								if not misStats[hitter.ucid].kills[deadStatsCat][deadStatsType] then  -- should also never happen
									slmod.warning('SlmodStats- Mission Stats- had to make a new type category for ' .. tostring(deadStatsType) .. ' of dead unit.')
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], deadStatsType, 0)
								end
								slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], deadStatsType, misStats[hitter.ucid].kills[deadStatsCat][deadStatsType] + 1)  -- give a kill
							end
							----------------------------------------------------------------------------------------------------------------
							
							if not stats[hitter.ucid].kills[deadStatsCat].total then  -- should also never happen
								slmod.warning('SlmodStats- had to make a new total entry for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
								slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], 'total', 0)
							end
							slmod.stats.changeStatsValue(stats[hitter.ucid].kills[deadStatsCat], 'total', stats[hitter.ucid].kills[deadStatsCat].total + 1)  -- change the total							
							slmod.stats.changeStatsValue(stats[deadClient.ucid].losses, 'crash', stats[deadClient.ucid].losses.crash + 1) -- give a crash to killed client.
							
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								if not misStats[hitter.ucid].kills[deadStatsCat].total then  -- should also never happen
									slmod.warning('SlmodStats- Mission Stats- had to make a new total entry for type ' .. tostring(deadStatsCat) .. ' of dead unit.')
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], 'total', 0)
								end
								slmod.stats.changeMisStatsValue(misStats[hitter.ucid].kills[deadStatsCat], 'total', misStats[hitter.ucid].kills[deadStatsCat].total + 1)  -- change the total							
								slmod.stats.changeMisStatsValue(misStats[deadClient.ucid].losses, 'crash', misStats[deadClient.ucid].losses.crash + 1) -- give a crash to killed client.
							end
							----------------------------------------------------------------------------------------------------------------
							
							
							--------------------------------------
							-- add kill for this weapon.							
							local weapon = lastHit.weapon
							if weapon then
								if not stats[hitter.ucid].weapons[weapon] then  -- this weapon not in this client's database, add it.
									slmod.stats.changeStatsValue(stats[hitter.ucid].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills = 0})
								end
								slmod.stats.changeStatsValue(stats[hitter.ucid].weapons[weapon], 'kills', stats[hitter.ucid].weapons[weapon].kills + 1)
								
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									if not misStats[hitter.ucid].weapons[weapon] then  -- this weapon not in this client's database, add it.
										slmod.stats.changeMisStatsValue(misStats[hitter.ucid].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills = 0})
									end
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].weapons[weapon], 'kills', misStats[hitter.ucid].weapons[weapon].kills + 1)
								end
								----------------------------------------------------------------------------------------------------------------	
							end
							--------------------------------------	

							--PvP
							if lastHit.inAirHit or lastHit.inAirHit == nil then  --058 -  only count in-air hits (or case of unable to figure out if hit was in air or not... could be a problem for clients after joining though
								--slmod.info('lastHit.inAirHit: '  .. tostring(lastHit.inAirHit))
								local countPvP, killerObj, victimObj = PvPRules(hitter.unitName, deadName)
								if countPvP then  -- count in PvP!
									slmod.stats.changeStatsValue(stats[hitter.ucid].PvP, 'kills', stats[hitter.ucid].PvP.kills + 1)  -- give a PvP kill
									slmod.stats.changeStatsValue(stats[deadClient.ucid].PvP, 'losses', stats[deadClient.ucid].PvP.losses + 1) -- give a PvP death
									
									----------------------------------------------------------------------------------------------------------------
									-- mission stats
									if slmod.config.enable_mission_stats then
										slmod.stats.changeMisStatsValue(misStats[hitter.ucid].PvP, 'kills', misStats[hitter.ucid].PvP.kills + 1)  -- give a PvP kill
										slmod.stats.changeMisStatsValue(misStats[deadClient.ucid].PvP, 'losses', misStats[deadClient.ucid].PvP.losses + 1) -- give a PvP death
									end
									----------------------------------------------------------------------------------------------------------------	
									
									
									onPvPKill(hitter.name, deadClient.name, weapon, killerObj, victimObj)
								end
							end
							
						
						else  -- friendly fire, human killing human.
						-- local teamKillTable = { time = os.time(), human = deadClient.ucid, objCat = deadCategory, objTypeName = deadObjType}
							local weapon = lastHit.weapon
							if weapon and weapon == 'kamikaze' then  -- friendly collision kill
								
								if not stats[hitter.ucid].friendlyCollisionKills then -- might be needed for old stats files.
									slmod.stats.changeStatsValue(stats[hitter.ucid], 'friendlyCollisionKills', {})
								end
								slmod.stats.changeStatsValue(stats[hitter.ucid].friendlyCollisionKills, #stats[hitter.ucid].friendlyCollisionKills + 1, { time = os.time(), human = deadClient.ucid, objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									if not misStats[hitter.ucid].friendlyCollisionKills then -- might be needed for old stats files.
										slmod.stats.changeMisStatsValue(misStats[hitter.ucid], 'friendlyCollisionKills', {})
									end
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].friendlyCollisionKills, #misStats[hitter.ucid].friendlyCollisionKills + 1, { time = os.time(), human = deadClient.ucid, objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								end
								----------------------------------------------------------------------------------------------------------------	
								
							else  -- friendly fire kill
								slmod.stats.changeStatsValue(stats[hitter.ucid].friendlyKills, #stats[hitter.ucid].friendlyKills + 1, { time = os.time(), human = deadClient.ucid, objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									slmod.stats.changeMisStatsValue(misStats[hitter.ucid].friendlyKills, #misStats[hitter.ucid].friendlyKills + 1, { time = os.time(), human = deadClient.ucid, objCat = deadCategory, objTypeName = deadObjType, weapon = weapon})
								end
								----------------------------------------------------------------------------------------------------------------
								
							end
							onFriendlyKill(hitter, deadClient.name, weapon)
						end
					
					elseif type(hitter) == 'string' then  -- a human was killed by an AI.
						slmod.stats.changeStatsValue(stats[deadClient.ucid].losses, 'crash', stats[deadClient.ucid].losses.crash + 1) -- give a crash
						
						----------------------------------------------------------------------------------------------------------------
						-- mission stats
						if slmod.config.enable_mission_stats then
							slmod.stats.changeMisStatsValue(misStats[deadClient.ucid].losses, 'crash', misStats[deadClient.ucid].losses.crash + 1) -- give a crash
						end
						----------------------------------------------------------------------------------------------------------------
					
					end
				end
			
			elseif deadClient then  -- client died without being hit.
				slmod.stats.changeStatsValue(stats[deadClient.ucid].losses, 'crash', stats[deadClient.ucid].losses.crash + 1) -- give a crash
				
				----------------------------------------------------------------------------------------------------------------
				-- mission stats
				if slmod.config.enable_mission_stats then
					slmod.stats.changeMisStatsValue(misStats[deadClient.ucid].losses, 'crash', misStats[deadClient.ucid].losses.crash + 1) -- give a crash
				end
				----------------------------------------------------------------------------------------------------------------
			
			end
			
			-- wipe this unit if he is a hitHuman
			hitHumans[deadName] = nil
		end
	end
	----------------------------------------------------------------------------------------------------------
	

	----------------------------------------------------------------------------------------------------------
	-- tracks flight times.
	function slmod.stats.trackFlightTimes(prevTime)  -- call every 10 seconds, tracks flight time.
		slmod.scheduleFunction(slmod.stats.trackFlightTimes, {DCS.getModelTime()}, DCS.getModelTime() + 10)  -- schedule first to avoid a Lua error.
		
		inAirClients = {}  -- reset upvalue inAirClients table.
		if prevTime and slmod.config.enable_slmod_stats then  -- slmod.config.enable_slmod_stats may be disabled after the mission has already started.
			local dt = DCS.getModelTime() - prevTime
			-- first, update all client flight times.
			for id, client in pairs(slmod.clients) do -- for each player (including host)
				local side = net.get_player_info(id, 'side')
				local unitId = net.get_player_info(id, 'slot')  -- get side and unitId

				if unitId then -- if in a unit.
					if is_BC(unitId) then  -- if it is a CA slot
						if client.ucid and stats[client.ucid] then
							if not stats[client.ucid].times.CA then  -- add this typeName to the client's stats
								slmod.stats.changeStatsValue(stats[client.ucid].times, 'CA', {total = 0, inAir = 0})
							end
							slmod.stats.changeStatsValue(stats[client.ucid].times.CA, 'total', stats[client.ucid].times.CA.total + dt)
							
							---------------------------------------------------------------------
							if slmod.config.enable_mission_stats then  -- mission stats
								if not misStats[client.ucid].times.CA then  -- add this typeName to the client's stats
									slmod.stats.changeMisStatsValue(misStats[client.ucid].times, 'CA', {total = 0, inAir = 0})
								end
								slmod.stats.changeMisStatsValue(misStats[client.ucid].times.CA, 'total', misStats[client.ucid].times.CA.total + dt)
							end
							----------------------------------------------------------------------
							
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
										
											if not stats[client.ucid].times[typeName] then  -- add this typeName to the client's stats
												slmod.stats.changeStatsValue(stats[client.ucid].times, typeName, {total = 0, inAir = 0})
											end
											slmod.stats.changeStatsValue(stats[client.ucid].times, typeName, {total = stats[client.ucid].times[typeName].total + dt, inAir = stats[client.ucid].times[typeName].inAir + dt}) -- do both at once, saves lines.
											
											---------------------------------------------------------------------
											if slmod.config.enable_mission_stats then  -- mission stats
												if not misStats[client.ucid].times[typeName] then  -- add this typeName to the client's stats
													slmod.stats.changeMisStatsValue(misStats[client.ucid].times, typeName, {total = 0, inAir = 0})
												end
												slmod.stats.changeMisStatsValue(misStats[client.ucid].times, typeName, {total = misStats[client.ucid].times[typeName].total + dt, inAir = misStats[client.ucid].times[typeName].inAir + dt}) -- do both at once, saves lines.
											end
											---------------------------------------------------------------------
											
											inAirClients[client.ucid] = true  -- used for PvP kills to avoid counting hits in the air
											-- slmod.stats.changeStatsValue(stats[client.ucid].times[typeName], 'total', stats[client.ucid].times[typeName].total + dt)
											-- slmod.stats.changeStatsValue(stats[client.ucid].times[typeName], 'inAir', stats[client.ucid].times[typeName].inAir + dt)
										end
									elseif retStr:sub(1,5) == 'false' then  -- not in air
										local typeName = retStr:sub(7) -- seven to end.
										if client.ucid and stats[client.ucid] then
											if not stats[client.ucid].times[typeName] then  -- add this typeName to the client's stats
												slmod.stats.changeStatsValue(stats[client.ucid].times, typeName, {total = 0, inAir = 0})
											end
											slmod.stats.changeStatsValue(stats[client.ucid].times[typeName], 'total', stats[client.ucid].times[typeName].total + dt)
											
											---------------------------------------------------------------------
											if slmod.config.enable_mission_stats then  -- mission stats
												if not misStats[client.ucid].times[typeName] then  -- add this typeName to the client's stats
													slmod.stats.changeMisStatsValue(misStats[client.ucid].times, typeName, {total = 0, inAir = 0})
												end
												slmod.stats.changeMisStatsValue(misStats[client.ucid].times[typeName], 'total', misStats[client.ucid].times[typeName].total + dt)
											end
											---------------------------------------------------------------------
											
											inAirClients[client.ucid] = false
										end
									end
								end
							end
						end
					end
				end
			end  -- for id, client in pairs(slmod.clients) do
			
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
				eventInd = eventInd + 1  -- increment NOW so if there is a Lua error, I'm not stuck forever on this event.
				--slmod.info(slmod.tableshow(event))
				
				
				----------------------------------------------------------------------------------------------------------
				--- Shot events
				--if (event.type == 'shot' or event.type == 'start shooting') and event.initiator_name and event.initiator_mpname and event.initiator_name ~= event.initiator_mpname then  -- human shot event
				if (event.type == 'shot' or event.type == 'end shooting' or event.type == 'start shooting') and event.initiator and event.initiatorPilotName and event.initiator ~= event.initiatorPilotName then  -- human shot event
					--slmod.info('shotting')
					if slmod.clientsByRtId then
						--slmod.info('clientsByRtId')
						local client = slmod.clientsByRtId[event.initiatorID]
						if client then
							--slmod.info('clientfound')
							if event.weapon or event.type == 'end shooting' or event.type == 'start shooting' then
								--slmod.info('weapon found')
								local weapon
								if event.type == 'end shooting' then
									--slmod.info('gun check')
									weapon = 'guns'
									--- this is code to check the number of rounds fired. 
									local shootingCount = 0 -- required for P-51D or other types that have multiple shooting events
									local endShootCount = 0
									local lastEvent = 'end shooting'
									local endLoop = false
									local endIndex
									local foundMatches = false
									
									for i = (eventInd - 1), 4, -1 do
										if event.initiator == slmod.events[i].initiator then -- finds the first start shooting event from the current end shootingfor the initiator
										--	slmod.info('found')
										--	slmod.info(i)
											if slmod.events[i].type == 'end shooting' then
												--slmod.info('end shot +')
												endShootCount = endShootCount + 1
												lastEvent = 'end shooting'
											elseif slmod.events[i].type == 'start shooting' then
												--slmod.info('start shot +')
												shootingCount = shootingCount + 1
												lastEvent = 'start shooting'
											end
											--[[ If the shot events are equal.
											if the 
											
											]]
											if endShootCount == shootingCount and shootingCount > 0 then -- if the shot count is the same
											--	slmod.info('equal')
											--	slmod.info(i)
												--local otherLastEvent = slmod.events[i].type
												local actualEndShootCount = 1
												local actualStartShootCount = 0
												local newLastEvent = 'end shooting'
												local iterating = 0
												for x = i, i - 10, -1 do -- iterate back a few just to check
													--slmod.info(x)
													
													if slmod.events[i].initiator == slmod.events[x].initiator then -- same initiators 
													--	slmod.info(slmod.events[x].type)
														iterating = iterating + 1
														if slmod.events[x].type == 'start shooting' then
															actualStartShootCount = actualStartShootCount + 1
													--		slmod.info('startShotFound')
															endIndex = x
														elseif slmod.events[x].type == 'end shooting' then
															if actualStartShootCount > 0 then
															--	slmod.info('alternate')
																endLoop = true
																--foundMatches = true
																break
															else
															actualEndShootCount = actualEndShootCount + 1
														--	slmod.info('endShotFound')
															end
														else
													--		slmod.info('something happened')
														end
													elseif x == 3 then
														iterating = iterating + 1
													end

													--slmod.info('start shot total ' .. actualStartShootCount)
													--slmod.info('end shot total ' ..actualEndShootCount)
													if actualStartShootCount ==  actualEndShootCount and slmod.events[x-1].type ~= 'start shooting' then
													--	slmod.info('found, break out')
														foundMatches = true
														endLoop = true
														break
													end
													if x == 3 then
														endLoop = true
														break													
													end
													
												end
												--[[if switchedState == true and type(endIndex) == 'number' then
													event.numtimes = slmod.events[endIndex].numShells - event.numShells - (shootingCount + endShootCount + 1)
													endLoop = true
												end]]
											end
										end

											 -- rewrite numtimes to now equal new shells.
											
										
										
										if i == 3 or endLoop == true then -- mayday mayday mayday just in case
											--slmod.info('oh shit')
											break
										end
									end
									--slmod.info('used index: ' .. endIndex)
									if foundMatches == true and type(endIndex) == 'number' then
										--slmod.info('add num')
										event.numtimes = slmod.events[endIndex].numShells - event.numShells - (shootingCount + endShootCount - 2)
									end
									--slmod.info(event.numtimes)
								else
									weapon = event.weapon
									-------------------
									-- problem: mp clients cannot hit with guns.  Empty weapon name, mismatching runtime IDs, etc.
									-- change any shell names or nil shell names to "guns".
									if isShell(weapon) then
										weapon = 'guns'
									end
									-------------------
									if clusterBombs[weapon] then -- handle cluster bombs
										weapon = clusterBombs[weapon].name
									end
								end
								--slmod.info(weapon)
								--slmod.info('global stats')
								if not stats[client.ucid].weapons[weapon] then  -- this weapon not in this client's database, add it.
									--slmod.info('add weapon type')
									slmod.stats.changeStatsValue(stats[client.ucid].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills= 0})
								end
								if event.numtimes then  -- there should ALWAYS be a numtimes.
									--slmod.info('numtimes exists')
									slmod.stats.changeStatsValue(stats[client.ucid].weapons[weapon], 'shot', stats[client.ucid].weapons[weapon].shot + event.numtimes)
								else
									--slmod.info('no numtimes')
									slmod.stats.changeStatsValue(stats[client.ucid].weapons[weapon], 'shot', stats[client.ucid].weapons[weapon].shot + 1)
								end
								--slmod.info('mission stats')
								----------------------------------------------------------------------------------------------------------------
								-- mission stats
								if slmod.config.enable_mission_stats then
									if not misStats[client.ucid].weapons[weapon] then  -- this weapon not in this client's database, add it.
										slmod.stats.changeMisStatsValue(misStats[client.ucid].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills= 0})
									end
									if event.numtimes then  -- there should ALWAYS be a numtimes.
										slmod.stats.changeMisStatsValue(misStats[client.ucid].weapons[weapon], 'shot', misStats[client.ucid].weapons[weapon].shot + event.numtimes)
									else
										slmod.stats.changeMisStatsValue(misStats[client.ucid].weapons[weapon], 'shot', misStats[client.ucid].weapons[weapon].shot + 1)
									end
								end
								----------------------------------------------------------------------------------------------------------------
								--slmod.info('human shots')
								-- Now, add to humanShots
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
					local tgtUCID
					local tgtSide
					local tgtCategory
					local tgtTypeName
					local initName = event.initiator  -- may not be dependable.
					local initClient
					local initUCID
					local initSide
					local nonAliveHit = false
	
					local time = event.t
					
					local weapon = event.weapon
					
					
					-------------------
					-- problem: mp clients cannot hit with guns.  Empty weapon name, mismatching runtime IDs, etc.
					-- change any shell names to "guns".
					if isShell(weapon) then
						weapon = 'guns'
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
						tgtUCID = tgtClient.ucid
						tgtSide = tgtClient.coalition
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
					elseif initName and event.initiatorPilotName and initName ~= event.initiatorPilotName then  -- almost certainly human, and ALIVE.
						--slmod.info('client fired shot')
						initClient = slmod.clientsByRtId[event.initiatorID]
						if initClient then
							initUCID = initClient.ucid
							initSide = initClient.coalition
						end
					
					else  -- initiator probably not human.
						-- nothing right now...
					end
					-----------------------------------------------------------
					
					-- OK, now we have data on target and initiator- hopefully, 99.999% accurate data!
					
					if initClient then  -- a human initiated hit
						--slmod.info('human caused hit')
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
							
							-- create weapon category for this weapon if it does not exist.
							if not stats[initUCID].weapons[weapon] then -- this could happen if stats re-enabled while weapons in flight, or unknown weapon.
								slmod.stats.changeStatsValue(stats[initUCID].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills = 0})
							end
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								-- create weapon category for this weapon if it does not exist.
								if not misStats[initUCID].weapons[weapon] then -- this could happen if stats re-enabled while weapons in flight, or unknown weapon.
									slmod.stats.changeMisStatsValue(misStats[initUCID].weapons, weapon, {shot = 0, hit = 0, numHits = 0, kills = 0})
								end
							end
							----------------------------------------------------------------------------------------------------------------
							
							if tgtSide and initSide then
								if tgtSide ~= initSide then  -- hits on enemy units in here
									--slmod.info('here8')
									if event.numtimes then  -- there should ALWAYS be a numtimes.
										slmod.stats.changeStatsValue(stats[initUCID].weapons[weapon], 'numHits', stats[initUCID].weapons[weapon].numHits + event.numtimes)
										
										----------------------------------------------------------------------------------------------------------------
										-- mission stats
										if slmod.config.enable_mission_stats then
											slmod.stats.changeMisStatsValue(misStats[initUCID].weapons[weapon], 'numHits', misStats[initUCID].weapons[weapon].numHits + event.numtimes)
										end
										----------------------------------------------------------------------------------------------------------------
										
									else
										slmod.stats.changeStatsValue(stats[initUCID].weapons[weapon], 'numHits', stats[initUCID].weapons[weapon].numHits + 1)
										
										----------------------------------------------------------------------------------------------------------------
										-- mission stats
										if slmod.config.enable_mission_stats then
											slmod.stats.changeMisStatsValue(misStats[initUCID].weapons[weapon], 'numHits', misStats[initUCID].weapons[weapon].numHits + 1)
										end
										----------------------------------------------------------------------------------------------------------------
									end
									
									if (event.weaponID and trackedWeapons[event.weaponID]) or weapon == 'guns' then  -- this is the first time this weapon hit something.
										if weapon ~= 'guns' then
											trackedWeapons[event.weaponID] = nil
										end
										slmod.stats.changeStatsValue(stats[initUCID].weapons[weapon], 'hit', stats[initUCID].weapons[weapon].hit + 1)
										
										----------------------------------------------------------------------------------------------------------------
										-- mission stats
										if slmod.config.enable_mission_stats then
											slmod.stats.changeMisStatsValue(misStats[initUCID].weapons[weapon], 'hit', misStats[initUCID].weapons[weapon].hit + 1)
										end
										----------------------------------------------------------------------------------------------------------------
									end
									
									
									if tgtClient then -- human hit an enemy human
										local inAirHit
										if tgtClient.ucid and inAirClients[tgtClient.ucid] ~= nil then
											inAirHit = inAirClients[tgtClient.ucid]
										end
									
										hitHumans[tgtName] = hitHumans[tgtName] or {}
										hitHumans[tgtName][#hitHumans[tgtName] + 1] = {time = time, initiator = slmod.deepcopy(initClient), target = slmod.deepcopy(tgtClient), weapon = weapon, inAirHit = inAirHit}
									else  -- human hit an enemy AI
										hitAIs[tgtName] = hitAIs[tgtName] or {}
										hitAIs[tgtName][#hitAIs[tgtName] + 1] = {time = time, initiator = slmod.deepcopy(initClient), weapon = weapon}
									end
									
						
								
								else  -- friendly fire
									--slmod.info('in friendly fire')
									if tgtName ~= initName then  -- hit a friendly unit!
										if weapon ~= 'kamikaze' then
											if tgtClient then -- human hit a friendly human
												slmod.stats.changeStatsValue(stats[initUCID].friendlyHits, #stats[initUCID].friendlyHits + 1, { time = os.time(), human = tgtClient.ucid, objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})	
												
												----------------------------------------------------------------------------------------------------------------
												-- mission stats
												if slmod.config.enable_mission_stats then
													slmod.stats.changeMisStatsValue(misStats[initUCID].friendlyHits, #misStats[initUCID].friendlyHits + 1, { time = os.time(), human = tgtClient.ucid, objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												end
												----------------------------------------------------------------------------------------------------------------
												
												local inAirHit
												if tgtClient.ucid and inAirClients[tgtClient.ucid] ~= nil then
													inAirHit = inAirClients[tgtClient.ucid]
												end
								
												hitHumans[tgtName] = hitHumans[tgtName] or {}
												hitHumans[tgtName][#hitHumans[tgtName] + 1] = {time = time, initiator = slmod.deepcopy(initClient), friendlyHit = true, target = slmod.deepcopy(tgtClient), weapon = weapon, inAirHit = inAirHit}
												
												onFriendlyHit(initClient, tgtClient.name, weapon)
											else  -- human hit a friendly AI
												slmod.stats.changeStatsValue(stats[initUCID].friendlyHits, #stats[initUCID].friendlyHits + 1, { time = os.time(), objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												
												----------------------------------------------------------------------------------------------------------------
												-- mission stats
												if slmod.config.enable_mission_stats then
													slmod.stats.changeMisStatsValue(misStats[initUCID].friendlyHits, #misStats[initUCID].friendlyHits + 1, { time = os.time(), objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												end
												----------------------------------------------------------------------------------------------------------------
												
												hitAIs[tgtName] = hitAIs[tgtName] or {}
												hitAIs[tgtName][#hitAIs[tgtName] + 1] = {time = time, initiator = slmod.deepcopy(initClient), friendlyHit = true, weapon = weapon}
												
												onFriendlyHit(initClient, tgtName, weapon)
											end
										else -- friendly collision  (weapon = 'kamikaze')
										
											if not stats[initUCID].friendlyCollisionHits then -- might be needed for old stats files.
												slmod.stats.changeStatsValue(stats[initUCID], 'friendlyCollisionHits', {})
											end
											
											----------------------------------------------------------------------------------------------------------------
											-- mission stats
											if slmod.config.enable_mission_stats then
												if not misStats[initUCID].friendlyCollisionHits then -- might be needed for old stats files.
													slmod.stats.changeMisStatsValue(misStats[initUCID], 'friendlyCollisionHits', {})
												end
											end
											----------------------------------------------------------------------------------------------------------------
											
											if tgtClient then -- human hit a friendly human
												slmod.stats.changeStatsValue(stats[initUCID].friendlyCollisionHits, #stats[initUCID].friendlyCollisionHits + 1, { time = os.time(), human = tgtClient.ucid, objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												
												----------------------------------------------------------------------------------------------------------------
												-- mission stats
												if slmod.config.enable_mission_stats then
													slmod.stats.changeMisStatsValue(misStats[initUCID].friendlyCollisionHits, #misStats[initUCID].friendlyCollisionHits + 1, { time = os.time(), human = tgtClient.ucid, objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												end
												----------------------------------------------------------------------------------------------------------------
												
												local inAirHit
												if tgtClient.ucid and inAirClients[tgtClient.ucid] ~= nil then
													inAirHit = inAirClients[tgtClient.ucid]
												end
												
												hitHumans[tgtName] = hitHumans[tgtName] or {}
												hitHumans[tgtName][#hitHumans[tgtName] + 1] = {time = time, initiator = slmod.deepcopy(initClient), friendlyHit = true, target = slmod.deepcopy(tgtClient), weapon = weapon, inAirHit = inAirHit}
												
												onFriendlyHit(initClient, tgtClient.name, weapon)
											else  -- human hit a friendly AI	
												slmod.stats.changeStatsValue(stats[initUCID].friendlyCollisionHits, #stats[initUCID].friendlyCollisionHits + 1, { time = os.time(), objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												
												----------------------------------------------------------------------------------------------------------------
												-- mission stats
												if slmod.config.enable_mission_stats then
													slmod.stats.changeMisStatsValue(misStats[initUCID].friendlyCollisionHits, #misStats[initUCID].friendlyCollisionHits + 1, { time = os.time(), objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon})
												end
												----------------------------------------------------------------------------------------------------------------
												
												hitAIs[tgtName] = hitAIs[tgtName] or {}
												hitAIs[tgtName][#hitAIs[tgtName] + 1] = {time = time, initiator = slmod.deepcopy(initClient), friendlyHit = true, weapon = weapon}
												
												onFriendlyHit(initClient, tgtName, weapon)
											end
										end
										
										
									
									else  -- self-inflicted
										
									end
								
								end
							
							else
								slmod.error('SlmodStats error- either tgtSide or initSide does not exist for hit event!')
							end
							
						end
					
					elseif tgtClient and not initClient then -- only case left unhandled in above code: AI hits human.
						local inAirHit
						if tgtClient.ucid and inAirClients[tgtClient.ucid] ~= nil then
							inAirHit = inAirClients[tgtClient.ucid]
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
						--slmod.info('running death logic from dead event/crash event')
						runDeathLogic(deadName)  -- run the death logic function.
					end
				end  -- end of crash/dead events.
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'pilot dead' then
					if event.initiator then
						local deadClient = slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator]
						if deadClient then
							slmod.stats.changeStatsValue(stats[deadClient.ucid].losses, 'pilotDeath', stats[deadClient.ucid].losses.pilotDeath + 1) -- give a pilotDeath
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								slmod.stats.changeMisStatsValue(misStats[deadClient.ucid].losses, 'pilotDeath', misStats[deadClient.ucid].losses.pilotDeath + 1) -- give a pilotDeath
							end
							----------------------------------------------------------------------------------------------------------------
							
						end
					end				
				end -- end of pilot dead
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'land' then  -- check if this is the valid name.
					if event.initiator and hitHumans[event.initiator] then
						landedUnits[event.initiator] = DCS.getModelTime()
					end
				end -- end of land
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'takeoff' then  -- check if this is the valid name.
					if event.initiator and landedUnits[event.initiator] then
						landedUnits[event.initiator] = nil
					end
				end
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'eject' then
					if event.initiator then
						local deadClient = slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator]
						if deadClient then
							slmod.stats.changeStatsValue(stats[deadClient.ucid].losses, 'eject', stats[deadClient.ucid].losses.eject + 1)
							
							----------------------------------------------------------------------------------------------------------------
							-- mission stats
							if slmod.config.enable_mission_stats then
								slmod.stats.changeMisStatsValue(misStats[deadClient.ucid].losses, 'eject', misStats[deadClient.ucid].losses.eject + 1)
							end
							----------------------------------------------------------------------------------------------------------------
							
						end
					end				
				end	-- end of eject
				----------------------------------------------------------------------------------------------------------
				
				
			end  -- end of while loop.
			
			-- If a hitHuman lands and comes to a stop after landing without dying, remove them from hit units.
			local currentTime = DCS.getModelTime()
			for unitName, landTime in pairs(landedUnits) do
				if slmod.activeUnitsByName[unitName] then
					if currentTime - landTime > 10 then  -- start checking to see if the unit is stationary.
						if unitIsStationary(unitName) then
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
					--slmod.info('SlmodStats- hit client unitName: ' .. unitName .. ', hits[#hits]: ' .. slmod.oneLineSerialize(hits[#hits]) .. '  no longer exists, running death logic.')
					
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
	-- ***BEGINNING OF STATS USER INTERFACE***
	
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
			
				local sTbl = {}  -- faster to use table.concat.
				sTbl[#sTbl + 1] = 'Summarized stats for player: "'
				sTbl[#sTbl + 1] = pStats.names[#pStats.names]
				sTbl[#sTbl + 1] = '", SlmodStats ID# '
				sTbl[#sTbl + 1] = tostring(pStats.id)
				sTbl[#sTbl + 1] = ':\n   | TIME: '
				
				local totalTime = 0
				for platform, times in pairs(pStats.times) do
					totalTime = totalTime + times.total
				end
				
				sTbl[#sTbl + 1] = string.format('%.1f', totalTime/3600)
				
				sTbl[#sTbl + 1] = ' hours | PvP K/D: '
				sTbl[#sTbl + 1] = tostring(pStats.PvP.kills)
				sTbl[#sTbl + 1] = '/'
				sTbl[#sTbl + 1] = tostring(pStats.PvP.losses)
				sTbl[#sTbl + 1] = ' | KILLS: Air = '
				
				
				
				local vehicleKills = pStats.kills['Ground Units'].total or 0
				local planeKills = pStats.kills['Planes'].total or 0
				local heloKills = pStats.kills['Helicopters'].total or 0
				local shipKills = pStats.kills['Ships'].total or 0
				local buildingKills = pStats.kills['Buildings'].total or 0
				
				local airKills = planeKills + heloKills
				local surfaceKills = vehicleKills + shipKills + buildingKills
				local friendlyKills = #pStats.friendlyKills
				
				sTbl[#sTbl + 1] = tostring(airKills)
				sTbl[#sTbl + 1] = ', Grnd/Sea = '
				sTbl[#sTbl + 1] = tostring(surfaceKills)
				sTbl[#sTbl + 1] = ', friendly = '
				sTbl[#sTbl + 1] = tostring(friendlyKills)
				sTbl[#sTbl + 1] = ' | LOSSES: '
				sTbl[#sTbl + 1] = tostring(pStats.losses.crash)
				
				return table.concat(sTbl)
			end
		end
	end
	
	
	
	--Creates the detailed stats page(s).
	local function createDetailedStats(ucid, mode)

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
				local p1Tbl = {}  -- faster to use table.concat.
				p1Tbl[#p1Tbl + 1] = 'Stats for player: "'
				p1Tbl[#p1Tbl + 1] = pStats.names[#pStats.names]
				p1Tbl[#p1Tbl + 1] = '", SlmodStats ID# '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.id)
				p1Tbl[#p1Tbl + 1] = ':\n\nFLIGHT TIMES (HOURS):\n    NAME                  IN AIR                TOTAL\n'
				local platforms = {}
				for platformName, timeTable in pairs(pStats.times) do
					platforms[#platforms + 1] = platformName
				end
				table.sort(platforms)
				
				for i = 1, #platforms do
					local line = '                                                                                                                             \n'
					line = stringInsert(line, platforms[i], 5)  -- insert platform name.
					local inAirTime = string.format('%.2f', pStats.times[platforms[i]].inAir/3600)
					local totalTime = string.format('%.2f', pStats.times[platforms[i]].total/3600)
					line = stringInsert(line, inAirTime, 27)  -- insert inAirTime
					line = stringInsert(line, totalTime, 49)  -- insert totalTime
					p1Tbl[#p1Tbl + 1] = line
				end
				p1Tbl[#p1Tbl + 1] = '\nKILLS:\n     GROUND                PLANES                HELOS                 SHIPS             BUILDINGS\n'
				local vehicleKills = pStats.kills['Ground Units']
				local planeKills = pStats.kills['Planes']
				local heloKills = pStats.kills['Helicopters']
				local shipKills = pStats.kills['Ships']
				local buildingKills = pStats.kills['Buildings']
				
				local vehicleKillsStrings = makeKillsColumn(vehicleKills)
				local planeKillsStrings = makeKillsColumn(planeKills)
				local heloKillsStrings = makeKillsColumn(heloKills)
				local shipKillsStrings = makeKillsColumn(shipKills)
				local buildingKillsStrings = makeKillsColumn(buildingKills)
				
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
				totalsLine = stringInsert(totalsLine, tostring(vehicleKills.total), 10)
				totalsLine = stringInsert(totalsLine, tostring(planeKills.total), 36)
				totalsLine = stringInsert(totalsLine, tostring(heloKills.total), 62)
				totalsLine = stringInsert(totalsLine, tostring(shipKills.total), 88)
				totalsLine = stringInsert(totalsLine, tostring(buildingKills.total), 110)
				p1Tbl[#p1Tbl + 1] = totalsLine
				
				
				p1Tbl[#p1Tbl + 1] = '\n\nFRIENDLY FIRE:\n              hits: '
				p1Tbl[#p1Tbl + 1] = tostring(#pStats.friendlyHits)
				p1Tbl[#p1Tbl + 1] = ';        kills: '
				p1Tbl[#p1Tbl + 1] = tostring(#pStats.friendlyKills)
				p1Tbl[#p1Tbl + 1] = ';  Friendly collision hits: '
				
				local cHits -- old stats may not have collision hits/kills
				if pStats.friendlyCollisionHits then
					cHits = #pStats.friendlyCollisionHits
				else
					cHits = 0
				end
				
				p1Tbl[#p1Tbl + 1] = tostring(cHits)
				p1Tbl[#p1Tbl + 1] = ';  Friendly collision kills: '
				
				local cKills -- old stats may not have collision hits/kills
				if pStats.friendlyCollisionKills then
					cKills = #pStats.friendlyCollisionKills
				else
					cKills = 0
				end
		
				p1Tbl[#p1Tbl + 1] = tostring(cKills)
				p1Tbl[#p1Tbl + 1] = ';'
				
				
				p1Tbl[#p1Tbl + 1] = '\n\nPLAYER VS. PLAYER:\n    Kills: '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.PvP.kills)
				p1Tbl[#p1Tbl + 1] = ';  Losses: '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.PvP.losses)
				p1Tbl[#p1Tbl + 1] = ';\n\n'

				p1Tbl[#p1Tbl + 1] = 'LOSSES:\n    Crashes: '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.losses.crash)
				p1Tbl[#p1Tbl + 1] = ';  Ejections: '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.losses.eject)
				p1Tbl[#p1Tbl + 1] = ';  Pilot Deaths: '
				p1Tbl[#p1Tbl + 1] = tostring(pStats.losses.pilotDeath)
				p1Tbl[#p1Tbl + 1] = ';\n\n'
				-- END OF FIRST PAGE
				---------------------------------------
				
				local p2Tbl = {}
				p2Tbl[#p2Tbl + 1] = 'WEAPONS DATA (Note- due to a bug in DCS, some weapon\'s hits cannot be properly counted for multiplayer clients.)\n'
				
				-- sort weapons in alphabetical order
				local weaponNames = {}
				
				for weaponName, weaponData in pairs(pStats.weapons) do
					weaponNames[#weaponNames + 1] = weaponName
				end
				table.sort(weaponNames)  -- put in alphabetical order
				
				for i = 1, #weaponNames do
					local line = '                                                                                                                     \n'
					line = stringInsert(line, weaponNames[i], 1)
					line = stringInsert(line, 'fired = ' .. tostring(pStats.weapons[weaponNames[i]].shot), 22)
					line = stringInsert(line, 'hit = ' .. tostring(pStats.weapons[weaponNames[i]].hit), 44)
					line = stringInsert(line, 'kills = ' .. tostring(pStats.weapons[weaponNames[i]].kills), 66)
					line = stringInsert(line, 'object hits = ' .. tostring(pStats.weapons[weaponNames[i]].numHits), 84)
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
						--slmod.info(msg)
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
				
				local statsToUse = stats
				if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
					statsToUse = misStats
				end

				for ucid, pStats in pairs(statsToUse) do -- this is inefficient- maybe I need to make a stats by id table.
					if type(pStats) == 'table' and pStats.id and pStats.id == pId then  -- found the id#.
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
				[3] = { 
					type = 'word', 
					text = 'for',
					required = false
				}, 
				[4] = { 
					type = 'word',
					text = 'id',
					required = true
				},
				[5] = { 
					type = 'number',
					varname = 'id',
					required = true
				}
			}				
		} 
		
		fullStatsForIdVars.onSelect = function(self, vars, clientId)
			if vars and vars.id then
				local pId = vars.id
				
				local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
	
				local statsToUse = stats
				if requesterMode and requesterMode == 'mission' and slmod.config.enable_mission_stats then
					statsToUse = misStats
				end

				for ucid, pStats in pairs(statsToUse) do -- this is inefficient- maybe I need to make a stats by id table.
					if type(pStats) == 'table' and pStats.id and pStats.id == pId then  -- found the id#.
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
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------META Stats Code-----------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
    -- meta stats is a new file for saving meta information related to slmod
    -- v1 simply keeps track of last used mission stats file used
    -- willing to add other useful data
    --- IDEAS: Theatre of war stats, map stats
    local function createMetaStats()
        slmod.stats.changeMetaStatsValue(metaStats, 'missionStatsFile', {})
        slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'previousMissionFile', '')       
        slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'currentMissionFile', '')        
    end
    local anything
    for i, j in pairs(metaStats) do
        anything = true
    end
    if not anything then
        slmod.info('createMeta')
        createMetaStats()
    end

	
end

slmod.info('SlmodStats.lua loaded.')