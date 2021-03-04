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
    local campaignName
    
    local activeCampaign
    
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
	local function changeMetaStatsValue(t, key, newValue)
        --slmod.info('write val')
        --slmod.info(slmod.oneLineSerialize(key))
        --slmod.info(slmod.oneLineSerialize(newValue))
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
    
    function slmod.stats.changeMetaStatsValue(t, key, newValue, noMeta)
        if noMeta and  metaStats[t] then
            changeMetaStatsValue(metaStats[t], key, newValue)
        else
            changeMetaStatsValue(t, key, newValue)
        end
    
    end
    
    function slmod.stats.getMetaStats()
		return metaStats
	end
    
    function slmod.createMetaStatsMission(missionName)
        local oDate =   os.date('%b %d, %Y at %H %M %S')
        mizName = missionName
        theatreName = DCS.getCurrentMission().mission.theatre
        changeMetaStatsValue(metaStats.missionStats, missionName, {})
        changeMetaStatsValue(metaStats.missionStats[missionName], 'firstPlayed', oDate)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'mostRecentPlayed', oDate)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'map', theatreName)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'timesPlayed', 1)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'hoursHosted', 0)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'totalFlightHours', 0)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'maxClients', 0)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'voteEnabled', true)
        changeMetaStatsValue(metaStats.missionStats[missionName], 'totalVoteLoaded', 0)
    end
    
    function slmod.createMetaStatsMap(mapName)
    local oDate =   os.date('%b %d, %Y at %H %M %S')
        changeMetaStatsValue(metaStats.mapStats, mapName, {})
        changeMetaStatsValue(metaStats.mapStats[mapName], 'firstPlayed', oDate)
        changeMetaStatsValue(metaStats.mapStats[mapName], 'mostRecentPlayed', oDate)
        changeMetaStatsValue(metaStats.mapStats[mapName], 'missions', {})
        changeMetaStatsValue(metaStats.mapStats[mapName], 'timesPlayed', 1)
        changeMetaStatsValue(metaStats.mapStats[mapName], 'hoursHosted', 0)
        changeMetaStatsValue(metaStats.mapStats[mapName], 'totalFlightHours', 0)
        changeMetaStatsValue(metaStats.mapStats[mapName], 'maxClients', 0)        
    end

    function slmod.stats.updateMetaMapInfo(mName)
        local oDate =   os.date('%b %d, %Y at %H %M %S')
        if metaStats then
            if not metaStats.missionStatsFile then
                changeMetaStatsValue(metaStats, 'missionStatsFile', {})
                changeMetaStatsValue(metaStats.missionStatsFile, 'previousMissionFile', 'false')       
                changeMetaStatsValue(metaStats.missionStatsFile, 'currentMissionFile', 'false')   
            end
            if not metaStats.mapStats then
                changeMetaStatsValue(metaStats, 'mapStats', {})
            end
            if not metaStats.missionStats then
                changeMetaStatsValue(metaStats, 'missionStats', {})
            end
        end
        mizName = DCS.getMissionName()
        
        if not mName then
            mName = (mizName .. '- ' .. oDate .. '.lua')
        end
        
        theatreName = DCS.getCurrentMission().mission.theatre
    
        if metaStats.missionStatsFile.currentMissionFile ~= 'false' then
            changeMetaStatsValue(metaStats.missionStatsFile, 'previousMissionFile', metaStats.missionStatsFile.currentMissionFile)
            if metaStats.missionStatsFile.previousMissionFile then
                slmod.stats.resetFile('mission', metaStats.missionStatsFile.previousMissionFile)
            end
            
        end
        if slmod.config.write_mission_stats_files then
            changeMetaStatsValue(metaStats.missionStatsFile, 'currentMissionFile', mName)
        end
        if not metaStats.missionStats[mizName] then
            slmod.createMetaStatsMission(mizName)
        else
            changeMetaStatsValue(metaStats.missionStats[mizName], 'timesPlayed', metaStats.missionStats[mizName].timesPlayed + 1)
            changeMetaStatsValue(metaStats.missionStats[mizName], 'mostRecentPlayed',oDate)
        end
        if not metaStats.mapStats[theatreName] then
            slmod.createMetaStatsMap(theatreName)
        else
            changeMetaStatsValue(metaStats.mapStats[theatreName], 'timesPlayed', metaStats.mapStats[theatreName].timesPlayed + 1)
            changeMetaStatsValue(metaStats.mapStats[theatreName], 'mostRecentPlayed', oDate)
        end
        if not metaStats.mapStats[theatreName].missions[mizName] then
            changeMetaStatsValue(metaStats.mapStats[theatreName].missions, mizName, oDate)
        end
        if not metaStats.missionStats[mizName].voteEnabled then
            changeMetaStatsValue(metaStats.missionStats[mizName], 'voteEnabled', true)
        end

        if not metaStats.missionStats[mizName].totalVoteLoaded then
            changeMetaStatsValue(metaStats.missionStats[mizName], 'totalVoteLoaded', 0)
        end
        
        if campaignName then 
            campaignName = nil
        end

        return
    end
    
    function slmod.stats.updateMetaFlightInfo(dt) --- ugh this is a dirty way to do it
        changeMetaStatsValue(metaStats.missionStats[mizName], 'totalFlightHours', metaStats.missionStats[mizName].totalFlightHours + dt/3600)
        changeMetaStatsValue(metaStats.mapStats[theatreName], 'totalFlightHours', metaStats.mapStats[theatreName].totalFlightHours + dt/3600)
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
                changeMetaStatsValue(metaStats.missionStats[mizName], 'hoursHosted', 0)
            end
            if not metaStats.mapStats[theatreName].hoursHosted then
                changeMetaStatsValue(metaStats.mapStats[theatreName], 'hoursHosted', 0)
            end            
            changeMetaStatsValue(metaStats.missionStats[mizName], 'hoursHosted', metaStats.missionStats[mizName].hoursHosted + dt/3600)
            changeMetaStatsValue(metaStats.mapStats[theatreName], 'hoursHosted', metaStats.mapStats[theatreName].hoursHosted + dt/3600)
        
            local count = 0
            for id, clients in pairs(slmod.clients) do
                count = count + 1
            end

            if count > metaStats.missionStats[mizName].maxClients then
                changeMetaStatsValue(metaStats.missionStats[mizName], 'maxClients', count)
            end

            if count > metaStats.mapStats[theatreName].maxClients then
                changeMetaStatsValue(metaStats.mapStats[theatreName], 'maxClients', count)  
            end
            
            if metaStats.campaigns and campaignName then 
                local numCamps = #metaStats.campaigns[campaignName].stats
                if campaignName and  metaStats.campaigns[campaignName] and  metaStats.campaigns[campaignName].stats and  metaStats.campaigns[campaignName].stats and metaStats.campaigns[campaignName].stats[numCamps] then
                   if count > metaStats.campaigns[campaignName].stats[numCamps].maxClients then 
                        changeMetaStatsValue(metaStats.campaigns[campaignName].stats[numCamps], 'maxClients', count)  
                   end
                end
            end
        end


        return
    end

    --[[Campaign Stats code
    Function is only run via mission script command. 
    This function will do the following: 
        1. Check for existing campaign data, if does not exist then create one.
        2. Stores active campaign in metaStats.campaigns table, by cName .. ' ' .. os.time() --- Start time of campaign.
        3. Sends filename to slmod.stats.resetFile to open and load that file.
    
    Note: Mission Reload/change needs to reset state of campaign file to nothing. 
    
    campName
        activeFile 
        missionNames
        stats
            [1] = { startDate
                endDate
                maxClients
    
    ]]

    
    
    function slmod.set_campaign_net(cName, reset)
    local oDate =   os.date('%b %d, %Y at %H %M %S')
        slmod.info('start campaign')
        slmod.info(cName)
        if not metaStats.campaigns then
            slmod.info('create campaigns')
            changeMetaStatsValue(metaStats, 'campaigns', {})
        end
        if not metaStats.campaigns[cName] then
            slmod.info('create: '.. cName)
            changeMetaStatsValue(metaStats.campaigns, cName, {})
            changeMetaStatsValue(metaStats.campaigns[cName], 'stats', {})
            changeMetaStatsValue(metaStats.campaigns[cName].stats, 1, {})
            changeMetaStatsValue(metaStats.campaigns[cName].stats[1], 'startDate', oDate)
            changeMetaStatsValue(metaStats.campaigns[cName].stats[1], 'maxClients', 0)
            
            --changeMetaStatsValue(metaStats.campaigns[cName].stats, 'clients', 0)
            changeMetaStatsValue(metaStats.campaigns[cName], 'missionNames', {})
            changeMetaStatsValue(metaStats.campaigns[cName].missionNames, mizName, 1)
        end
        
        if reset or not metaStats.campaigns[cName].activeFile then
            if reset and metaStats.campaigns[cName].activeFile then -- Reset an existing campaign
                changeMetaStatsValue(metaStats.campaigns[cName].stats[#metaStats.campaigns[cName].stats], 'endDate', oDate)
                changeMetaStatsValue(metaStats.campaigns[cName].stats[#metaStats.campaigns[cName].stats + 1], #metaStats.campaigns[cName].stats + 1, {})
                changeMetaStatsValue(metaStats.campaigns[cName].stats[#metaStats.campaigns[cName].stats], 'startDate', oDate)
                changeMetaStatsValue(metaStats.campaigns[cName].stats[#metaStats.campaigns[cName].stats], 'maxClients', 0)
                activeCampaign = cName .. ' ' .. oDate .. '.lua'
                slmod.info('reset with existing file')
            else   -- new campaign is created 
                slmod.info('new campaign')
                activeCampaign = cName .. ' ' .. oDate .. '.lua'
                changeMetaStatsValue(metaStats.campaigns[cName], 'activeFile', activeCampaign)
            end
            slmod.info('create stats')
            
        else   -- load previous campaign
            slmod.info('load existing')
            if mizName then -- cant be to careful
                if not metaStats.campaigns[cName].missionNames[mizName] then
                    changeMetaStatsValue(metaStats.campaigns[cName].missionNames, mizName, 0)
                end
                changeMetaStatsValue(metaStats.campaigns[cName].missionNames, mizName, metaStats.campaigns[cName].missionNames[mizName] +  1)
            end
            activeCampaign = metaStats.campaigns[cName].activeFile
        end
        if activeCampaign then 
            slmod.stats.startCampaign(activeCampaign)
        end
        campaignName = cName
    end
    
    
end

slmod.info('SlmodMetaStats.lua loaded.')