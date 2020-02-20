do
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------META Stats Code-----------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
    -- meta stats is a new file for saving meta information related to slmod
    -- v1 simply keeps track of last used mission stats file used
    -- willing to add other useful data
    -- IDEAS: Theatre of war stats, map stats
    local statsDir = slmod.config.stats_dir or lfs.writedir() .. [[Slmod\]]
    local metaStats, metaStatsF = slmod.stats.resetFile('meta')
    --local metaStatsF = io.open(statsDir .. '\\SlmodMetaStats.lua', 'w')
    local mizName
    local theatreName
    
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
    
    function slmod.stats.getMetaStats()
		return metaStats
	end
    
    function slmod.createMetaStatsMission(missionName)
        mizName = missionName
        theatreName = DCS.getCurrentMission().mission.theatre
        slmod.stats.changeMetaStatsValue(metaStats.missionStats, missionName, {})
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'firstPlayed', os.date('%b %d, %Y at %H %M %S'))
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'mostRecentPlayed', os.date('%b %d, %Y at %H %M %S'))
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'map', theatreName)
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'timesPlayed', 1)
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'hoursHosted', 0)
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'totalFlightHours', 0)
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'maxClients', 0)
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'voteEnabled', true)
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[missionName], 'totalVoteLoaded', 0)
    end
    
    function slmod.createMetaStatsMap(mapName)
        slmod.stats.changeMetaStatsValue(metaStats.mapStats, mapName, {})
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'firstPlayed', os.date('%b %d, %Y at %H %M %S'))
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'mostRecentPlayed', os.date('%b %d, %Y at %H %M %S'))
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'missions', {})
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'timesPlayed', 1)
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'hoursHosted', 0)
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'totalFlightHours', 0)
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[mapName], 'maxClients', 0)        
    end
    
    function slmod.stats.updateMetaMapInfo(mName)
        if metaStats then
            if not metaStats.missionStatsFile then
                slmod.stats.changeMetaStatsValue(metaStats, 'missionStatsFile', {})
                slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'previousMissionFile', 'false')       
                slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'currentMissionFile', 'false')   
            end
            if not metaStats.mapStats then
                slmod.stats.changeMetaStatsValue(metaStats, 'mapStats', {})
            end
            if not metaStats.missionStats then
                slmod.stats.changeMetaStatsValue(metaStats, 'missionStats', {})
            end
        end
        mizName = DCS.getMissionName()
        
        if not mName then
            mName = (mizName .. '- ' .. os.date('%b %d, %Y at %H %M %S'))
        end
        
        theatreName = DCS.getCurrentMission().mission.theatre
    
        if metaStats.missionStatsFile.currentMissionFile ~= 'false' then
            slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'previousMissionFile', metaStats.missionStatsFile.currentMissionFile)
            if metaStats.missionStatsFile.previousMissionFile then
                slmod.stats.resetFile('mission', metaStats.missionStatsFile.previousMissionFile)
            end
            
        end
        if slmod.config.write_mission_stats_files then
            slmod.stats.changeMetaStatsValue(metaStats.missionStatsFile, 'currentMissionFile', mName)
        end
        if not metaStats.missionStats[mizName] then
            slmod.createMetaStatsMission(mizName)
        else
            slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'timesPlayed', metaStats.missionStats[mizName].timesPlayed + 1)
            slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'mostRecentPlayed', os.date('%b %d, %Y at %H %M %S'))
        end
        if not metaStats.mapStats[theatreName] then
            slmod.createMetaStatsMap(theatreName)
        else
            slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName], 'timesPlayed', metaStats.mapStats[theatreName].timesPlayed + 1)
            slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName], 'mostRecentPlayed', os.date('%b %d, %Y at %H %M %S'))
        end
        if not metaStats.mapStats[theatreName].missions[mizName] then
            slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName].missions, mizName, os.date('%b %d, %Y at %H %M %S'))
        end
        if not metaStats.missionStats[mizName].voteEnabled then
            slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'voteEnabled', true)
        end

        if not metaStats.missionStats[mizName].totalVoteLoaded then
            slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'totalVoteLoaded', 0)
        end

        return
    end
    
    function slmod.stats.updateMetaFlightInfo(dt) --- ugh this is a dirty way to do it
        slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'totalFlightHours', metaStats.missionStats[mizName].totalFlightHours + dt/3600)
        slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName], 'totalFlightHours', metaStats.mapStats[theatreName].totalFlightHours + dt/3600)
    end
     
    function slmod.stats.trackMissionTimes(prevTime)  -- call every 60 seconds, tracks flight time.
        slmod.scheduleFunction(slmod.stats.trackMissionTimes, {DCS.getModelTime()}, DCS.getModelTime() + 60)  -- schedule first to avoid a Lua error.

        if not mizName then
            mizName = DCS.getMissionName()
        end
        if not theatreName then
             theatreName = DCS.getCurrentMission().mission.theatre
        end
        if ((not metaStats.missionStats) or (not metaStats.missionStats[mizName])) then
            return
        end

        if prevTime and slmod.config.enable_slmod_stats then  -- slmod.config.enable_slmod_stats may be disabled after the mission has already started.
			local dt = DCS.getModelTime() - prevTime
            if not metaStats.missionStats[mizName].hoursHosted then
                slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'hoursHosted', 0)
            end
            if not metaStats.mapStats[theatreName].hoursHosted then
                slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName], 'hoursHosted', 0)
            end            
            slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'hoursHosted', metaStats.missionStats[mizName].hoursHosted + dt/3600)
            slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName], 'hoursHosted', metaStats.mapStats[theatreName].hoursHosted + dt/3600)
        
            local count = 0
            for id, clients in pairs(slmod.clients) do
                count = count + 1
            end

            if count > metaStats.missionStats[mizName].maxClients then
                slmod.stats.changeMetaStatsValue(metaStats.missionStats[mizName], 'maxClients', count)
            end

            if count > metaStats.mapStats[theatreName].maxClients then
                slmod.stats.changeMetaStatsValue(metaStats.mapStats[theatreName], 'maxClients', count)  
            end
        end


        return
    end

    
    
    
end

slmod.info('SlmodMetaStats.lua loaded.')