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

    
    local misStats = {}
    local misStatsF  -- mission stats file
    
    local penStats -- penalty stats
    local penStatsF -- penalty stats file
    
    local campStats 
    local campStatsF
    local campStatsActive = false
    
    local missionStatsDir = slmod.config.mission_stats_files_dir or lfs.writedir() .. [[Slmod\Mission Stats\]]
    if missionStatsDir:sub(missionStatsDir:len(), missionStatsDir:len()) ~= '\\' and missionStatsDir:sub(missionStatsDir:len(), missionStatsDir:len()) ~= '/' then
        missionStatsDir = missionStatsDir .. '\\'
    end
    
    local campStatsDir = slmod.config.campaign_stats_files_dir or lfs.writedir() .. [[Slmod\Campaign Stats\]]
    if campStatsDir:sub(campStatsDir:len(), campStatsDir:len()) ~= '\\' and campStatsDir:sub(campStatsDir:len(), campStatsDir:len()) ~= '/' then
        campStatsDir = campStatsDir .. '\\'
    end
    
    
    local useBuffer = false
	-- new, reloadStats method
	----slmod.info('do reset')
	--slmod.stats.resetStatsFile()  -- load stats from file.
	-------------------------------------------------------------------------------------------------------
    -- NEW NEW write file code
	-------------------------------------------------------------------------------------------------------
    slmod.stats.resetFile = function (l, f) -- 
        local fileF
        local fileName
        local lName = ''
        local lstatsDir = slmod.deepcopy(statsDir)
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
            ----slmod.info('meta')
            fileName = '\\SlmodMetaStats.lua'
            lName = 'SlmodMetaStats.lua'
            envName = 'metaStats'
            statData = metaStats
        elseif l == 'penalty' then
            ----slmod.info('meta')
            fileName = '\\SlmodPenaltyStats.lua'
            lName = 'SlmodPenaltyStats.lua'
            envName = 'penStats'
            statData = penStats   
            fileF = penStatsF
        elseif l == 'camp' then
           -- slmod.info(campStatsDir)
            --slmod.info(f)
            lstatsDir = campStatsDir
            envName = 'campStats'
            statData = campStats
            fileF = campStatsF
            fileName = '\\' .. f
            lName = f
        else
           -- --slmod.info('stats')
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
				--slmod.info('old ' .. lName .. ' file backed up to ' .. lstatsDir .. fileName)
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
                --slmod.info(slmod.oneLineSerialize(statsS))
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
                if f and l == 'mission' then 
                   -- slmod.info('Old Mission Stat file doesnt exist')
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
        elseif l == 'camp' then
           -- slmod.info('open')
            local newStatsS = slmod.serialize('campStats', statData) ..'\n'
            campStatsF = io.open(lstatsDir .. fileName, 'w')
            campStatsF:write(newStatsS)
            campStatsActive = true
        elseif not l then
            --Now, stats should be opened, or if not run, at least backed up..  Now, write over the old stats and return a file handle.
            local newStatsS = slmod.serialize('stats', statData) ..'\n'
            statsF = io.open(lstatsDir .. fileName, 'w')
            statsF:write(newStatsS)
        end
        
        if slmod.config.save_json_stats then
            --slmod.info('writing json file')
           -- slmod.info(jsonFileName)
            local jsonFileName = string.gsub(fileName, '.lua', '.json')
            local jsonStats = net.lua2json(statData)
            local jsonF = io.open(lstatsDir .. jsonFileName, 'w')
            jsonF:write(jsonStats)
            jsonF:close()
        end
        
        return statData, fileF
	end
    stats = slmod.stats.resetFile()
    penStats = slmod.stats.resetFile('penalty')
    local statWrites = 0
    local function recompileStats()
        ----slmod.info('recompile stats')
        stats = slmod.stats.resetFile()
        statWrites = 0    
    end
    local AIstats
    

    
	-------------------------------------------------------------------------------------------------------
	-- Create statsTableKeys database
    --slmod.info('makeTblKeys')
        local statsTableKeys = {}  -- stores strings that corresponds to table indexes within stats... needed for updating file.
        statsTableKeys[stats] = 'stats'
        do
            local function makeStatsTableKeys(levelKey, t)
                for key, val in pairs(t) do
                    if type(val) == 'table' and type(key) == 'string' then
                        key = levelKey .. '[' .. slmod.basicSerialize(key) .. ']'
                        statsTableKeys[val] = key  -- works because each table only exists once in Slmod stats- it's REQUIRED!!! DO NOT FORGET THIS!
                        ----slmod.info(slmod.basicSerialize(val) .. ' : ' .. key)
                        makeStatsTableKeys(key, val)
                    end
                end
            end
            
            makeStatsTableKeys('stats', stats)
        end	
        ------------------------------------------------------------------------------------------------------
        --[[ stats write buffer

        ]]
        local statsBuffer = {}
        local buffer = {}
        local function statsWriteBuffer()
            --slmod.scheduleFunction(statsWriteBuffer, {}, DCS.getModelTime() + 4)
            if #statsBuffer > 0 then
                for i = 1, #statsBuffer do
                    local lStat = buffer[statsBuffer[i]]
                    local wVal = statsBuffer[i] .. ' = ' .. slmod.oneLineSerialize(lStat.val) .. '\n'
                    if lStat.tName == 'stats' then
                        statsF:write(wVal)
                    elseif lStat.tName == 'misStats' then
                        misStatsF:write(wVal)
                    elseif lStat.tName == 'campStats' then
                        campStatsF:write(wVal)
                    end
                end
                statsBuffer = {}
                buffer = {}
            end
        end
        
        local function addStatToBuffer(tName, key, newValue)
            if buffer[key] then
                buffer[key].val = newValue
            else    
                buffer[key] = {tName = tName, val = newValue, index = #statsBuffer + 1}
                table.insert(statsBuffer, key)
            end
            
        end
        ----------------
        -- call this function each time a value in stats needs to be changed... 
        -- For all root entries for a player and changing actual values by advChangeStatsValue
        -- t: the table in stats that this value belongs under
        function slmod.stats.changeStatsValue(t, key, newValue, def)
            if not t then
                slmod.error('Invalue stats table specified!')
                return
            end
            if type(newValue) == 'table' then
                statsTableKeys[newValue] = statsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']'
            end
            if not key then
                slmod.warning('Key not found, trying to write value: ' .. slmod.oneLineSerialize(newValue))
                return
            else
                t[key] = newValue
            end
            --
            if useBuffer == true then
                 addStatToBuffer('stats', statsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']', slmod.deepcopy(newValue))
            else
                local statsChangeString = statsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. '] = ' .. slmod.oneLineSerialize(newValue) .. '\n'
                statsF:write(statsChangeString)
            end
           
            statWrites = statWrites + 1
            if statWrites > 10000 then
                recompileStats()
            end
           

        end
        

            -- Create the nextIdNum variable, so stats knows the next stats ID number it can use for a new player.
        local nextIDNum = 1
        local pIds = {}
        local function getNextId()
            
            while pIds[nextIDNum] do
                --slmod.info(nextIDNum)
                nextIDNum = nextIDNum + 1
            end
            --slmod.info('rtn: ' .. nextIDNum)
            return slmod.deepcopy(nextIDNum)
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
        
        local function createCampStatsPlayer(ucid)
            local pStats = stats[ucid]
            if not pStats then
                slmod.error('Campaign Stats: player (ucid = ' .. tostring(ucid) .. ') does not exist in regular stats!')
            else
                slmod.stats.changeCampStatsValue(campStats, ucid, {})
                slmod.stats.changeCampStatsValue(campStats[ucid], 'names', slmod.deepcopy(pStats.names))
                slmod.stats.changeCampStatsValue(campStats[ucid], 'id', pStats.id)
                slmod.stats.changeCampStatsValue(campStats[ucid], 'times', {})
            end
        end
        

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
            
            if campStatsActive == true and not campStats[ucid] then
                createCampStatsPlayer(ucid)
            end

        end
        
        ---------------------------------------------------------------------------------------------------
        

         --slmod.info('camp keys')
        local campStatsTableKeys = {}  -- stores strings that corresponds to table indexes within stats... needed for updating file.
        local function buildCampStatsKeys()
            campStatsTableKeys[campStats] = 'campStats'
            do
                local function makeStatsTableKeys(levelKey, t)
                    for key, val in pairs(t) do
                        if type(val) == 'table' and type(key) == 'string' then
                            key = levelKey .. '[' .. slmod.basicSerialize(key) .. ']'
                            campStatsTableKeys[val] = key  -- works because each table only exists once in Slmod stats- it's REQUIRED!!! DO NOT FORGET THIS!
                            ----slmod.info(slmod.basicSerialize(val) .. ' : ' .. key)
                            makeStatsTableKeys(key, val)
                        end
                    end
                end
                
                makeStatsTableKeys('campStats', campStats)
            end	
        end
        
        
        function slmod.stats.startCampaign(cFile)
            campStats = slmod.stats.resetFile('camp', cFile)
            buildCampStatsKeys()
            if campStats and slmod.config.stats_coa > 0 then 
                if not campStats['bluePlayers'] then
                    createCampStatsPlayer('bluePlayers')
                end
                if not campStats['redPlayers'] then
                    createCampStatsPlayer('redPlayers')
                end
                if slmod.config.stats_coa > 1 then
                    if not campStats['blueAI'] then
                        createCampStatsPlayer('blueAI')
                    end
                    if not campStats['redAI'] then
                        createCampStatsPlayer('redAI')
                    end
                end
            end
        end
        
        
        function slmod.stats.changeCampStatsValue(t, key, newValue)
            if not t then
                slmod.error('Invalue stats table specified!')
                return
            end
            if type(newValue) == 'table' then
                campStatsTableKeys[newValue] = campStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']'
            end
            --if not t[key] then
            --    slmod.warning('Key not found: ' .. slmod.basicSerialize(key))
           -- else
                t[key] = newValue
            --end
            --
            if useBuffer == true then 
                addStatToBuffer('campStats', campStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. ']', slmod.oneLineSerialize(newValue))
            else
                local statsChangeString = campStatsTableKeys[t] .. '[' .. slmod.basicSerialize(key) .. '] = ' .. slmod.oneLineSerialize(newValue) .. '\n'
                campStatsF:write(statsChangeString)
            end
            --

            ----slmod.info(statsChangeString)
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

    function slmod.stats.advChangeStatsValue(vars, logg)
        if logg then 
            slmod.info(slmod.oneLineSerialize(vars)) 
        end
        local useUcid = {}
        local nest = vars.nest
        local addValue = vars.addValue
        local def = vars.default or {}
        local typeName = vars.typeName
        if type(vars.ucid) == 'string' then -- can accept a string or multiple ucid to apply stat to
            useUcid[1] = vars.ucid
        else
            useUcid = vars.ucid
        end
        for j = 1, #useUcid do
            if stats[useUcid[j]] then
                local lStats = stats[useUcid[j]]
                if not lStats then
                    slmod.warning('No Stats table exists for: ' .. useUcid[j])
                    for id, cData in pairs(slmod.clients) do
                        if cData.ucid == useUcid[j] then
                            createNewPlayer(cData.ucid, cData.name, true)
                            break
                        end
                    end
                end
                if lStats then 
                    if vars.penalty then -- add to penalty stats file
                        if not penStats[useUcid[j]] then -- create user pen stats
                            --slmod.info('create Pen stats')
                            slmod.stats.createPlayerPenaltyStats(useUcid[j], true)
                        end
                        slmod.stats.changePenStatsValue(penStats[useUcid[j]][nest], #penStats[useUcid[j]][nest] + 1, addValue)
                    else
                        local mStats = misStats[useUcid[j]]
                        local lEntry = slmod.deepcopy(nest)
                        local mEntry = slmod.deepcopy(nest)
                        
                        local cStats 
                        if campStats and campStats[useUcid[j]] then
                            cStats = campStats[useUcid[j]]
                        end
                        local cEntry = slmod.deepcopy(nest)
                        
                        local default = slmod.deepcopy(def)
                        if type(nest) == 'table' then -- nest can be a string for root level or table for nested levels
                            for i = 1, #nest - 1 do
                                --slmod.info(i .. ' ' .. lEntry[i])
                                if lEntry[i] == 'typeName' and typeName then
                                    lEntry[i] = typeName[j]
                                    mEntry[i] = typeName[j]
                                    cEntry[i] = typeName[j]
                                end
                                if not lEntry[i] then
                                    slmod.warning(slmod.oneLineSerialize(nest) .. 'index: ' .. i) 
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
                                if campStatsActive == true then
                                    if not cStats[cEntry[i]] then
                                        slmod.stats.changeCampStatsValue(cStats, cEntry[i], {})
                                    end  
                                    cStats = cStats[cEntry[i]]
                                end
                            end
                            lEntry = lEntry[#lEntry]
                            mEntry = mEntry[#mEntry]
                            cEntry = cEntry[#cEntry]
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
                        if campStatsActive == true and not cStats[cEntry] then
                            local cDefault
                            if default then
                                cDefault = slmod.deepcopy(default)
                            end
                            slmod.stats.changeCampStatsValue(cStats, cEntry, cDefault or {})
                        end
                        if addValue then 
                            if type(addValue) == 'table' then 
                                for index, value in pairs(addValue) do
                                    if lStats[lEntry][index] then
                                        --slmod.info('val is ' .. lStats[lEntry][index])
                                        slmod.stats.changeStatsValue(lStats[lEntry], index, lStats[lEntry][index] + value)
                                    elseif default[index] then
                                        slmod.stats.changeStatsValue(lStats[lEntry], index, default[index] + value)
                                    end
                                    if slmod.config.enable_mission_stats then
                                        if mStats[mEntry][index] then 
                                            ----slmod.info('mval is ' .. mStats[mEntry][index])
                                            slmod.stats.changeMisStatsValue(mStats[mEntry], index, mStats[mEntry][index] + value)
                                        end
                                    end
                                    if campStatsActive == true then
                                        if cStats[cEntry][index] then 
                                            ----slmod.info('mval is ' .. mStats[mEntry][index])
                                            slmod.stats.changeCampStatsValue(cStats[cEntry], index, cStats[cEntry][index] + value)
                                        end
                                    end
                                end
                            else    
                                --slmod.info(addValue .. ' is added to single val ' .. lEntry)
                                slmod.stats.changeStatsValue(lStats, lEntry, lStats[lEntry] + addValue)
                                if  slmod.config.enable_mission_stats then 
                                    slmod.stats.changeMisStatsValue(mStats, mEntry, mStats[mEntry] + addValue)
                                end
                                if campStatsActive == true then
                                    slmod.stats.changeCampStatsValue(cStats, cEntry, cStats[cEntry] + addValue)
                                end
                            end
                        end
                        if vars.setValue then -- change one and only one value to this. 
                            slmod.stats.changeStatsValue(lStats, lEntry, vars.setValue)
                            if  slmod.config.enable_mission_stats then 
                                slmod.stats.changeMisStatsValue(mStats, mEntry, vars.setValue)
                            end
                            if campStatsActive == true then
                                slmod.stats.changeCampStatsValue(cStats, cEntry, vars.setValue)
                            end
                        end
                        if vars.insert then
                            --slmod.info('insert')
                            if vars.insertAt then
                                -- can't do a simple table.insert. Need to get all values, insert at start of table, THEN rewrite all table entries. 
                                local tab = slmod.deepcopy(lStats[lEntry])
                                table.insert(tab, insertAt, vars.insert)
                                if vars.maxSaved and type(vars.maxSaved) == 'number' then
                                    for i = 1, #tab do
                                        if i > vars.maxSaved then
                                            tab[i] = nil
                                        end
                                    end
                                end
                                slmod.stats.changeStatsValue(lStats, lEntry, tab)
                                if slmod.config.enable_mission_stats then 
                                    slmod.stats.changeMisStatsValue(mStats, mEntry, tab)
                                end
                                if campStatsActive == true then
                                    slmod.stats.changeCampStatsValue(cStats, cEntry, tab)
                                end
                            else
                                --slmod.info('just insert')
                                slmod.stats.changeStatsValue(lStats[lEntry], #lStats[lEntry] + 1, vars.insert)
                                if  slmod.config.enable_mission_stats then 
                                    slmod.stats.changeMisStatsValue(mStats[mEntry], #mStats[mEntry] + 1, vars.insert)
                                end
                                if campStatsActive == true then
                                    slmod.stats.changeCampStatsValue(cStats[cEntry], #cStats[cEntry] + 1, vars.insert)
                                end
                            end
                        end
                    end
                

                end
            end

        end
        --[[
        if slmod.config.save_best_life and slmod.config.save_best_life > 0 and not (vars.AI or vars.penalty or vars.life) then
            local lifeVars = slmod.deepcopy(vars)
            lifeVars.life = true
            if type(lifeVars.nest) == 'table' then
                table.insert(lifeVars.nest, 1, 'currentLife')
            else
                lifeVars.nest = {'currentLife', vars.nest}
            end
            slmod.scheduleFunction(slmod.stats.advChangeStatsValue, {lifeVars, logg}, DCS.getModelTime() + 1)
        end]]
        
        if slmod.config.stats_coa and slmod.config.stats_coa > 0 and vars.coa and not (vars.AI or vars.penalty) then
            -- change vars.ucid to correspond to player or AI value based on setting
            -- Do I really want to have stats for that?
            local u = {}
            local cVars = slmod.deepcopy(vars) -- because it would have changed the original saveStat value. 
            for i = 1, #useUcid do
                u[i] = cVars.coa .. 'Players'
            end
            cVars.ucid = u
            cVars.coa = nil
            
            slmod.scheduleFunction(slmod.stats.advChangeStatsValue, {cVars, logg}, DCS.getModelTime() + 1)
        end
        return
    end
   	--------------------------------------------------------------------------------------------------


    
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
        ----slmod.info('write miz stat')
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
            if useBuffer == true then
                addStatToBuffer('misStats', key, slmod.deepCopy(misStatsChangeString))
            else
                misStatsF:write(misStatsChangeString)
            end
            --
           -- --slmod.info(misStatsChangeString)
        end
        
	end
	---------------------------------------------------------------------------------------------------
     --slmod.info('penTblKeys')
	---------------------------------------------------------------------------------------------------------------------
    local penStatsTableKeys = {}  -- stores strings that corresponds to table indexes within penStats... needed for updating file.
	penStatsTableKeys[penStats] = 'penStats'
	do
		local function makeStatsTableKeys(levelKey, t)
            for key, val in pairs(t) do
                if type(val) == 'table' and (type(key) == 'string' or type(key) == 'number') then
					key = levelKey .. '[' .. slmod.basicSerialize(key) .. ']'
					penStatsTableKeys[val] = key  -- works because each table only exists once in Slmod stats- it's REQUIRED!!! DO NOT FORGET THIS!
                    ----slmod.info(slmod.basicSerialize(val) .. ' : ' .. key)
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
            ----slmod.info(penStatsChangeString)
        end
        
	end
    
     --slmod.info('mDefs')
    local multiCrewDefs = {}
	multiCrewDefs['Mi-8MT'] = {[2] = 'Copilot', [3] = 'FO', [4] = 'LG', [5] = 'RG'}
    multiCrewDefs['UH-1H'] = {[2] = 'Copilot', [3] = 'LG', [4] = 'RG'}
    
    
    local function getLifeScore(lStats)
        local score = 0
        local fTime = 0
        -- check basic level
        if lStats.kills then
            for kCat, kData in pairs(lStats.kills) do
                if type(kData) == 'table' then
                    for kEntry, kVal in pairs(kData) do
                        if kEntry ~= 'total' then
                            score = score + kVal
                        end
                    end
                end
            end
        end
        
        -- check aircraft>Kills
        for acName, acVal in pairs(lStats.times) do
            if acVal.inAir then
                fTime = fTime + acVal.inAir
            end
            if acVal.kills then
                for kCat, kData in pairs(acVal.kills) do
                    if type(kData) == 'table' then
                        for kEntry, kVal in pairs(kData) do
                            if kEntry ~= 'total' then
                                score = score + kVal
                            end
                        end
                    end
                end
            end
            if acVal.weapons then
                for wepName, wepData in pairs(acVal.weapons) do
                    if wepData.kL then
                        for cat, catData in pairs(wepData.kL) do
                            if catData.total then
                               score = score + catData.total
                            end
                        end 
                    end
                end
            
            end
        end
        return score
    end
    local lifeEvents = {}
    
    local function checkLifeEnd(vars)
        slmod.info('checkLifeEnd')
        slmod.info(slmod.oneLineSerialize(vars))
        if slmod.config.save_best_life and slmod.config.save_best_life > 0 then
            local evalLife = false
            local curTime = DCS.getModelTime()
            local killUCID = {}
            local eventName = vars.eventName
            local ucids = vars.ucids
            local unitName = vars.client[1].unitName
            local killEm = false
            if eventName == 'pilotDead' or (slmod.config.endLifeOn and slmod.config.endLifeOn[eventName] and slmod.config.endLifeOn[eventName] == true) then
                killEm = true -- there was a pilot dead event or the other applicable event occurred. 
            end
            
            
            if not lifeEvents[unitName] then
                lifeEvents[unitName] = {}
            end 
            
            local tName = slmod.allMissionUnitsByName[unitName].objtype
            
            if not lifeEvents[unitName].num then
                lifeEvents[unitName].num = 0
                lifeEvents[unitName].deadPilots  = 0
                lifeEvents[unitName].ucidList = {}
            end
            
            if eventName == 'pilotDead' then
                lifeEvents[unitName].deadPilots = lifeEvents[unitName].deadPilots + 1
            end
            
                -- create and save table with info on death related events for a given aircraft.
            for i = 1, #ucids do
 
                if not lifeEvents[unitName][ucids[i]] then
                    lifeEvents[unitName][ucids[i]] = {}
                    lifeEvents[unitName].num = lifeEvents[unitName].num + 1
                    table.insert(lifeEvents[unitName].ucidList, ucids[i])
                end
                if not lifeEvents[unitName][ucids[i]][eventName] then
                    lifeEvents[unitName][ucids[i]][eventName] = curTime
                end

            end
            
            if killEm == true  then -- evaluate and populate list of players to set a new life
                --[[
                Must handle pilot deaths for multicrew aircraft. 
                
                Problems: 
                    Aircraft can have multiple players per aircraft. Pilot dead event doesn't mean they can't land safely. 
                    DCS does a shit job of giving multiCrew aircraft information
                        A: Have to rely on slot roles and hope it accurately reflects the current status quo. 
                    Pilot dead event doesn't occur for door gunners
                        A: Just can't get a player death via being a door gunner until it is fixed.
                    
                Solutions:
                    A. Require 2 deaths per aircraft
                    B. Kill whoever is in 2nd seat first.
                    C. Give death to first person to leave the slot. 
                ]]
                if multiCrewDefs[tName] and #ucids > 1 then -- if it is a multicrew aircraft and is multicrew right now
                    if slmod.config.multicrew_life == 2 then
                        if lifeEvents[unitName].deadPilots == 2 then
                            killUCID = lifeEvents[unitName].ucidList
                            evalLife = true
                        end
                    else
                        for i = 1, #ucids do
                            if lifeEvents[unitName][ucids[i]].leftSlot then
                                table.insert(killUCID, ucids[i])
                                evalLife = true
                            end
             
                        end
                    end
                    
                else
                    killUCID = ucids
                    if not lifeEvents[unitName][ucids[1]].pilotDead then -- special case of damaged but left the slot. 
                        evalLife = true
                    end
                
                end
               
            end
            
            
            
            if evalLife == true and #killUCID > 0 then
                local numRemoved = 0
                for i = 1, #killUCID do
                    if stats[killUCID[i]] then
                        local lStat = stats[killUCID[i]]
                        local bestScore = 0
                        local currentScore = 0 
                        if lStat.bestLife then
                            bestScore = getLifeScore(lStat.bestLife)
                        end
                        if lStat.currentLife then
                            currentScore = getLifeScore(lStat.currentLife)
                        end
                        if currentScore > bestScore then
                            lStat.currentLife.endDate = os.time
                            local newWrite = {nest = {'bestLife'}, ucid = killUCID[i], setValue = lStat.currentLife}
                            slmod.stats.advChangeStatsValue(newWrite) -- copy current life values into bestLife
                            
                            newWrite.nest = {'currentLife'}
                            newWrite.setValue = {startDate = os.time}
                            slmod.stats.advChangeStatsValue(newWrite) -- erase contents of current life
                        end
                    end
                    
                    if lifeEvents[unitName][killUCID[i]] then -- remove each players events. Stupid but possible for a player to die only for another to join the aircraft and generate other kill events. 
                        lifeEvents[unitName][killUCID[i]] = nil
                        lifeEvents[unitName].num = lifeEvents[unitName].num  - 1
                        numRemoved = numRemoved + 1
                    end
                end
                if numRemoved == lifeEvents[unitName].num  then -- fully remove that unit from list. 
                    lifeEvents[unitName] = nil
                end
                 
            end
        end
        return
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
        
        if slmod.config and slmod.config.stats_coa and slmod.config.stats_coa > 0 then
            if not stats['redPlayers'] then
                createNewPlayer('redPlayers', 'globalRedPlayerStats', slmod.config.enable_mission_stats) 
            end
            if not stats['bluePlayers'] then
                createNewPlayer('bluePlayers', 'globalRedPlayerStats', slmod.config.enable_mission_stats) 
            end
            if slmod.config.stats_coa > 1 then 
                AIstats = true
                if not stats['redAI'] then
                    createNewPlayer('redAI', 'globalRedAIStats', slmod.config.enable_mission_stats) 
                end
                if not stats['blueAI'] then
                    createNewPlayer('blueAI', 'globalBlueAIStats', slmod.config.enable_mission_stats) 
                end
            end
        end
        
        
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
        
        
        if campStatsActive == true then -- disables campaign stats, needs to be renabled by the mission that gets loaded
            campStatsActive = false
            campStats = nil
        end
        -- On mission load, check for objects to get added to the multicrew defs
        local coas = DCS.getAvailableCoalitions()
        local checked = {}
        local searchMC = {
            ['f-14'] = {[2] = 'RIO'}, -- other F14 versions proof
            ['f-15e'] = {[2] = 'WSO'}, -- future proof       
            ['mi-24'] = {[2] = 'WSO'}, -- future proof
            ['l-39'] = {[2] = 'Copilot'},
        }
        for coaId, coaData in pairs(coas) do
            local slots = DCS.getAvailableSlots(coaId)
            for slotVal, slotData in pairs(slots) do

                checked[slotData.type] = true
                for sName, sData in pairs(searchMC) do
                    if string.find(string.lower(slotData.type), sName) then
                        multiCrewDefs[slotData.type] = searchMC[sName]
                    end
                end
                if string.find(slotData.unitId, '_') and not multiCrewDefs[slotData.type] then -- slot has a 2nd seat or more that hasn't been defined yet
                    local roleName = slotData.role
                    if slotData.role and string.len(slotData.role) < 6  then
                        local initial = {}
                        for w in string.gmatch(slotData.role, '%a+') do
                            initial[#initial] = string.upper(string.sub(w, 1, 1))
                        end
                        roleName = table.concat(initial)
                    else
                        roleName = 'Copilot'
                    end
                    local slotInd = slotData.multicrew_place or tonumber(string.sub(slotData.unitId, string.len(slotData.unitId), string.len(slotData.unitId)))
                    multiCrewDefs[slotData.type] = {}
                    if slotInd then
                        multiCrewDefs[slotData.type][slotInd] = roleName
                    end
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
	local inAirClients = {}
	
    
    local function getNest(tbl)
        local nest = {'times', 'typeName'}
        if slmod.config.stats_level then
            if slmod.config.stats_level == 0 then
                nest = {}
            elseif slmod.config.stats_level == 2 then
                nest = {'times', 'typeName'}
            end    
        end
        for i = 1, #tbl do
            table.insert(nest, tbl[i])
        end
        return nest
    end
    
    ---------------------------------------------------------------------------------------------------------
	--player SWITCHES unit.  Used for detecting desertion under fire 
	local function onSwitchUnit(id, oldUnitRtId)  
        --slmod.info('onSwitchUnit')
        --slmod.info(id)
        --slmod.info(oldUnitRtId)
        --checkLifeEnd(oldUnitRtId, 'leftSlot')
        

	end
    
	function slmod.stats.onSetUnit(id)
        if not id then
			slmod.error('slmod.stats.onSetUnit(id): client has no id!!!')
			return
		end
		if slmod.clients[id].rtid then  -- client had an old rtid
			--slmod.info(slmod.oneLineSerialize(slmod.clients[id]))
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
                if campStatsActive == true and not campStats[ucid] then
                    createCampStatsPlayer(ucid)
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
            
            --slmod.info(slmod.oneLineSerialize(slmod.oldClientsByName))
			if inAirClients[ucid] then
                --slmod.info('client was in Air')
                -- add client left slot in air to losses here. 
                if slmod.oldClientsByName[name] then
                    --local objType = slmod.allMissionUnitsByName[name].objtype
                    --slmod.stats.advChangeStatsValue({ucid = ucid, default = 0, addValue = 1, nest = getNest({'actions', 'losses', 'leftSlotInAir'}}))
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
    
    ------------

    
    local function getPlayerNamesString(clients)
        local names = {}
        for cIndex, cData in pairs(clients) do
            if cIndex ~= 'player' then 
                    if #names > 0 then
                    table.insert(names, ' and ')
                end
                table.insert(names, cData.name)
            end
       end
        return table.concat(names)
    end
    

	-------------------------------------------------------------------
    local hitSpamFilter = {}
	local function onFriendlyHit(clients, target, weapon, player)
        local penType = 'teamHit'
        if weapon and weapon == 'kamikaze' then
            penType = 'teamCollisionHit'
        
        end
        slmod.scheduleFunction(slmod.autoAdminCheckForgiveOnOffense, {clients, target, penType}, DCS.getModelTime() + 0.1)
        
        if slmod.config.enable_team_hit_messages and slmod.config.autoAdmin[penType].enabled == true then
			local tString = getPlayerNamesString(target)
            local scoreAdded = 0 
            if target.player then
                scoreAdded = slmod.config.autoAdmin[penType].penaltyPointsHuman
            else
                scoreAdded = slmod.config.autoAdmin[penType].penaltyPointsAI
            end
            if scoreAdded > 0 and hitSpamFilter[tString] and hitSpamFilter[tString] > DCS.getModelTime() + 10 or not hitSpamFilter[tString] then 
                hitSpamFilter[tString] = DCS.getModelTime()
                local msg = {[1] = 'Slmod- TEAM HIT: "', [2] = getPlayerNamesString(clients), [3] = '" hit friendly unit "', [4] = tString, [5] = '" with ', [6] = tostring(weapon) ,[7] = '!'}
                slmod.scopeMsg(table.concat(msg), 1, 'chat')
            end
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
			--slmod.info(slmod.oneLineSerialize(target))
            for ind, tDat in pairs(target) do
                table.insert(msg, table.concat({ind, ' = {name = ', tDat.name}))
            end
            table.insert(msg, wpnInfo)
            slmod.chatLogFile:write(table.concat(msg))
            --slmod.chatLogFile:write(table.concat{'TEAM HIT: ', os.date('%b %d %H:%M:%S '), ' {name  = ', slmod.basicSerialize(tostring(client.name)), ', ucid = ', slmod.basicSerialize(tostring(client.ucid)), ', ip = ',  slmod.basicSerialize(tostring(client.addr)), ', id = ', tostring(client.id), '} hit ', target.name, wpnInfo}) OLD
			slmod.chatLogFile:flush()
		end
		-- autokick/autoban


	end

	local function onFriendlyKill(clients, target, weapon, player)
        --slmod.info('On Friendly Kill')
        --slmod.info(slmod.oneLineSerialize(clients))
        --slmod.info(slmod.oneLineSerialize(target))
        local penType = 'teamKill'
        if weapon and weapon == 'kamikaze' then
            penType = 'teamCollisionKill'
        end
        -- Set to run this in case anything in here fails. 
        slmod.scheduleFunction(slmod.autoAdminCheckForgiveOnOffense, {clients, target, penType}, DCS.getModelTime() + 0.1)
        if slmod.config.enable_team_kill_messages and slmod.config.autoAdmin[penType].enabled then
            local scoreAdded = 0 
            if target.player then
                scoreAdded = slmod.config.autoAdmin[penType].penaltyPointsHuman
            else
                scoreAdded = slmod.config.autoAdmin[penType].penaltyPointsAI
            end
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
    -- Function that lets people know how they were killed. When it wasn't a TK or PvP
    local function onTellPlayerDied(initName, weapon, scope)
        --[[if slmod.config.enable_player_death_message then
            slmod.scopeMsg('Slmod- You were killed by: "' .. getPlayerNamesString(initName) .. tostring(weapon) .. '.', 1, 'chat') 
        end]]
        
    end
    

	
	
	local hitObjs = {}
    
    

	
	
	--[[
	hitObjs = {
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
		
	}  -- end of hitObjs
	
	
	
	hitObjs = {
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
	
	
	-- need to quickly cycle through hitObjs and see if they no longer exist- perhaps dead without an event.
	
	If they don't exist anymore, then treat them as if they died.
	]]
	
	-- ALSO, I need to special detection for mid-air collisions
	
	
	local function getHitData(unitName)
        if hitObjs[unitName] then
			return hitObjs[unitName] -- just return the last hit
		end
	end
	
	local landedUnits = {}  -- used to remove kill detection on landed units.
	local suppressDeath = {}  -- used to suppress any extra dead event after a unit no longer exists.  Probably not necessary
	local humanShots = {}  -- in the case of an unidentified weapon in in a hit event, this is used to associate the event with the last weapon fired.
	local gunTypes = {}
    local cvLandings = {}
    local refuelings = {}
    
	local function computeTotal(kills)  -- computes total kills for a specific type (vehicle, ship, plane, etc.)
		local total = 0
		for typeName, typeKills in pairs(kills) do
			if typeName ~= 'total' then
				total = total + typeKills
			end
		end
		return total
	end
	
	local acft = {} -- Aircraft List. Built by attributes DB, writes list of aicraft by name and display name. 
    acft['SA342'] = true -- because unicorn
    local function buildACFT()
        for uName, unitData in pairs(slmod.unitAttributes) do
            if unitData.attributes and unitData.attributes['Air'] then
                acft[unitData.displayName] = true
                acft[unitData.name] = true
            end
        end
	end
    
	function slmod.stats.reset()
		eventInd = 1
		clusterHits = {}
		trackedWeapons = {}
		hitObjs = {}
		landedUnits = {}
        refuelings = {}
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
                --[[
                if pStats.times then
                    for typeName, typeData in pairs(pStats.times) do
                        if typeData.kills then -- fix kill totals
                        
                        end
                        if typeData.weapons then
                            for wepName, wepData in pairs(typeData.weapons) do
                                if wepData.kL then -- fix kill list
                                
                                
                                end
                            end
                        
                        end
                    end
                
                end
                ]]
			end
		end
		buildACFT()
	end
	
	local function unsuppressDeath(unitName)  -- allows death counting to occur again for this unit.
		----slmod.info('Unsupress death')
        ----slmod.info(unitName)
        suppressDeath[unitName] = nil
	end
    
    local function clearCVLanding(checkTime)
        local curTime = DCS.getModelTime()
        if cvLandings and #cvLandings > 0 then
            for i = 1, #cvLandings do
                if checkTime == cvLandings[i].t then
                    --slmod.info('match delete')
                    cvLandings[i] = nil
                end
            end        
        else
            
        end    
    end
    
    local function buildTestMultCrew(initC)
        if not stats['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'] then
            createNewPlayer('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'Goose')
        end
        initC[2] = {ucid = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', name = 'Goose', unitName = 'getShotDownEvent', coalition = 'blue'}
        return initC
    end
    
    local function buildTestAIAsClient()
        if not stats['AIClientStats'] then
            createNewPlayer('AIClientStats', 'AnnoyingBug')
        end
        return {[1] = {ucid = 'AIClientStats', name = 'AnnoyingBug', unitName = 'FakeShotDown', coalition = 'red',}} 
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
	
	

	local function isAircraft(weaponName)  -- determines if the weapon was a aircraft.
		if weaponName and weaponName:len() > 1 then
            if acft[weaponName] then
				return true
			end
            -- Fallback, but shouldn't happen. 
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
    
    
	local function multiCrewNameCheck(tName, seatId)
        --slmod.info(tName)
        --slmod.info(seatId)
        if multiCrewDefs[tName] and not multiCrewDefs[tName][seatId] then
            tName = tName .. ' CoPilot'
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
            new.ip = cData.ip
            new.name = cData.name
            new.coalition = cData.coalition
            new.id = cData.id
            cTbl[index] = new
        end
        
        return cTbl
    
    end
	-----------------------------
	-- tracks what clients were in air last check...
	-- used for pvp kills - don't award a PvP kill on clients on the ground.
	
    
    
	-----------------------
	local runDeathLogicChecker = {}
	----------------------------------------------------------------------------------------------------------
	-- death logic
	local function runDeathLogic(deadName)
		--slmod.info('runDeathLogic')
        if runDeathLogicChecker[deadName] then
            slmod.warning('runDeathLogic Failed on: ' .. slmod.oneLineSerialize(hitObjs[deadName]))
            hitObjs[deadName] = nil
            runDeathLogicChecker[deadName] = nil
            
        else
            runDeathLogicChecker[deadName] = true
        end
        --slmod.info('Running Death Logic')
        if slmod.allMissionUnitsByName[deadName] then -- the dying unit should always be identified properly by name (not necessarily...could be Building).
            --slmod.info(deadName)
            --slmod.info('allMissionUnitsByName; exists')
            local deadUnit = slmod.allMissionUnitsByName[deadName]
            local deadCategory = deadUnit.category 
			local deadClient = slmod.clientsByName[deadName] or slmod.oldClientsByName[deadName]
			--[[Find the object in SlmodStats categories
            if deadClient and deadClient[1] and deadClient[1].unitName == 'getShotDownEvent' then
                deadClient = buildTestMultCrew(deadClient)
            end]]
			local deadObjType = deadUnit.objtype
			local deadStatsCat
			local deadStatsType
			if deadCategory == 'static' then  -- just automatically assign into static objects.
				deadStatsCat = 'Buildings'
				deadStatsType = 'Static'
			end
			if not deadStatsCat or (not deadStatsCat == 'Buildings') then -- need to find the type.
				----slmod.info(slmod.tableshow( slmod.catsByUnitType))
				if slmod.catsByUnitType[deadObjType] then
					local types = slmod.catsByUnitType[deadObjType]
					deadStatsCat = types[1]
					deadStatsType = types[2]
					if not (deadStatsCat and deadStatsType) then
						slmod.error('SlmodStats deadStatsCat or deadStatsType not recognized; deadStatsCat: ' .. tostring(deadStatsCat) .. '; deadStatsType: ' .. tostring(deadStatsType))
                        return
					end
				else
					slmod.error('SlmodStats - unit type ' .. tostring(deadObjType) .. ' for unit ' .. tostring(deadName) .. ' not in database!')
                    --slmod.error(slmod.oneLineSerialize(slmod.catsByUnitType))
					return
				end
			end
            --slmod.info(deadObjType)
            --slmod.info(deadStatsCat)
            --slmod.info(deadStatsType)
			--slmod.info('here4')
			--[[Changes to death code.
                1. Add stat to losses to indicate what killed the player. Possible multiple settings
                    A. actions.losses.killedBy.category (fighters, sams, etc)
                    B. actions.losses.killedBy.ObjectName.Weapon (Mig-31.R-33)
                2. Add chat message to player saying they were shot down by X with Y weapons. 
                3. Assists. Player with the last hit gets the kill credit, for any other player who hits the target will be given an assist. The assist table matches the kills table format
                4. Possible addition/change of supporting AI stats.
          
                
                
                How to add assists...
                    Rules: Last player to hit target gets kill. Any other player hit target gets assist. Killer cannot get assist on the kill. 
                    Odd situation; PlayerA hits target with aircraftX. PlayerA switches to aircraftY and hits the object again. 
                    
                    TO DECIDE: How deep assists go regardless of settings.
                        1. Assist per kill.                     | For each player to hit a target, their last hit gets a single assist.     
                                   | 
                        2. Assist per weapon type per kill.     | Player hits target with weapon typeA and weapon typeB. B kills target, A gets + 1 assist
                        3. Assist by player aircraft per kill   | Same as option 1, but each aircraft is checked allowing a player to hit a target with 1 aircraft, then switches to another for a hit. 
                        
                        
                    Important note: Hit data is based on hit events. Multiple events may occur within a short timespan and multiple targets at the same time.      
                Build list of valid hits to save. 
            ]]
			local allHits = getHitData(deadName)
            local validHits = {}
            if allHits and type(allHits) == 'table' and #allHits > 0 then -- assists are enabled and the object was hit more than once. 
                --slmod.info('number of hits: ' .. #allHits)
                local scope = #allHits
                if slmod.config.assists_level and slmod.config.assists_level > 0 then
                    scope = 1
                end
                local hitsByType = {}
                for i = #allHits, scope, -1  do -- go backwards through the list so that validHits starts at the kill
                    local lHit = allHits[i]

                    if lHit.weapon then
                        --slmod.info('weapon: ' .. lHit.weapon)
                        if not hitsByType[lHit.weapon] then -- create list by weapon 
                            --slmod.info('create weapon')
                            hitsByType[lHit.weapon] = {}
                        end
                        if lHit.initiator then
                            local lId = lHit.initiator
                            if type(lHit.initiator) == 'table' and lHit.initiator[1] and lHit.initiator[1].ucid then -- then check for the pilot in the first seat
                                lId = lHit.initiator[1].ucid
                            end
                            if not hitsByType[lHit.weapon][lId] then
                                hitsByType[lHit.weapon][lId] = {}
                            end
                            if not hitsByType[lHit.weapon][lId][lHit.shotFrom] then -- then check the object type. 
                                --slmod.info('add valid hit')
                                hitsByType[lHit.weapon][lId][lHit.shotFrom] = true
                                validHits[#validHits+1] = lHit
                            end
                        end
                    end
                end
            
            end
            
			if #validHits > 0 then  -- either a human died or an AI that was hit by a human died.
				--local lastHitEvent = hitData[#hitData] --- at least FOR NOW, just using last hit!
                local deadObjData = {}
                local dStat = {}
                local ducid, dtypeName = {}, {}
                --slmod.info('check deadClient')
                if deadClient then 
                    --slmod.info('deadClient')
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
                    
                    --slmod.info('deadClient check to end life')
                    if slmod.config.save_best_life and slmod.config.save_best_life > 0 then
                        --checkLifeEnd({ucids = dStat.ucid, eventName = 'dead', client = deadClient})
                    end
                else
                    deadObjData[1] = {name = deadName}
                    if slmod.config.stats_coa > 1 then
                        dStat.ucid = {deadUnit.coalition .. 'AI'}
                        dStat.typeName = {deadObjType}
                        dStat.AI = true
                    end
                end
                if validHits and validHits[1] and validHits[1].target and validHits[1].target.coalition and slmod.config.stats_coa > 0 and not dStat.AI then
                    dStat.coa = validHits[1].target.coalition
                end
                 --slmod.info(slmod.oneLineSerialize(dStat))
                -- Only do dead check stuff once, cause it only died once.
                for i = 1, #validHits do
                    --slmod.info(i)
                    local lHit = validHits[i]
                    local killerObj = lHit.initiator
                    local killerObjType = 'unknown'
                    if lHit.shotFrom then
                        killerObjType = lHit.shotFrom
                    end
                    local weapon = lHit.weapon
                    local saveStat = {}
                    local ucid, typeName = {}, {}

                    if type(lHit.initiator) == 'table' then 
                        for seat, data in pairs(lHit.initiator) do
                            ucid[seat] = data.ucid
                            if seat > 1 then
                                typeName[seat] = multiCrewNameCheck(killerObjType, seat)
                            else
                                typeName[seat] = killerObjType
                            end
                        end
                    else
                        ucid = {lHit.initiator_coalition.. 'AI'}
                        typeName = {lHit.shotFrom}
                    end
                    saveStat = {ucid = ucid, typeName = typeName}
                    if slmod.config.stats_coa > 0 then 
                        if type(lHit.initiator) ~= 'table' and slmod.config.stats_coa == 2 then
                            saveStat.AI = true
                        else
                            saveStat.coa = lHit.initiator_coalition
                        end
                        
                    end
                   
                    --case 1 - deadAI, hit by human.
                    if i == 1 then  -- this is whoever got the kill
                        local killerStatsCat
                        local killerStatsType
                        if deadCategory == 'static' then  -- just automatically assign into static objects.
                            killerStatsCat = 'Buildings'
                            killerStatsType = 'Static'
                        end
                        if not killerStatsCat or (not killerStatsCat == 'Buildings') then -- need to find the type.
                            ----slmod.info(slmod.tableshow( slmod.catsByUnitType))
                            if slmod.catsByUnitType[killerObjType] then
                                local types = slmod.catsByUnitType[killerObjType]
                                killerStatsCat = types[1]
                                killerStatsType = types[2]
                                if not (killerStatsCat and killerStatsType) then
                                    slmod.error('SlmodStats killerStatsCat or killerStatsType not recognized; killerStatsCat: ' .. tostring(killerStatsCat) .. '; killerStatsType: ' .. tostring(killerStatsType))
                                    return
                                end
                            else
                                slmod.error('SlmodStats - unit type ' .. tostring(killerObjType) .. ' for unit ' .. tostring(deadName) .. ' not in database!')
                                --slmod.error(slmod.oneLineSerialize(slmod.catsByUnitType))
                                return
                            end
                        end
                        --slmod.info('check for killer obj')
                        if killerObj and (type(killerObj) == 'table' or saveStat.AI) then 
                           
                                --slmod.info(slmod.oneLineSerialize(killerObj))
                                --slmod.info('killerObj is table')
                            if not lHit.friendlyHit then -- good kill
                                --slmod.info('not a TK')
                                if slmod.config.stats_level < 2 or (slmod.config.stats_level < 2 and not weapon) then
                                    saveStat.nest = getNest({'kills', deadStatsCat, deadStatsType})
                                    saveStat.addValue = 1
                                    saveStat.default =  0
                                    slmod.stats.advChangeStatsValue(saveStat)
                                    
                                    if slmod.config.kd_specifics == true then
                                        saveStat.nest = getNest({'kL', 'objects', deadObjType})
                                        slmod.stats.advChangeStatsValue(saveStat)
                                    end
                                    
                                    -- Add to total Kills for a given category
                                    saveStat.nest = getNest({'kills', deadStatsCat, 'total'})
                                    slmod.stats.advChangeStatsValue(saveStat)
                                end
                                
                                if weapon then
                                    saveStat.nest = getNest({'weapons', weapon})
                                    saveStat.addValue = {kills = 1}
                                    saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0, assist = 0}
                                    slmod.stats.advChangeStatsValue(saveStat)
                                    
                                    if slmod.config.stats_level == 2 then
                                        saveStat.nest = getNest({'weapons', weapon, 'kL', deadStatsCat, deadStatsType})
                                        saveStat.addValue = 1
                                        saveStat.default =  0
                                        slmod.stats.advChangeStatsValue(saveStat)
                                        
                                        saveStat.nest = getNest({'weapons', weapon, 'kL', deadStatsCat, 'total'})
                                        slmod.stats.advChangeStatsValue(saveStat)
                                        
                                        if slmod.config.kd_specifics == true then
                                            saveStat.nest = getNest({'weapons', weapon, 'spec', 'kills', deadObjType})
                                            slmod.stats.advChangeStatsValue(saveStat)
                                        end
                                    end
                                end    
                                --slmod.stats.changeStatsValue(stats[deadClientUCID[i]].losses, 'crash', stats[deadClientUCID[i]].losses.crash + 1)
                                --slmod.info('check if target was player')
                                if deadClient or dStat.AI then
                                    
                                    dStat.nest = getNest({'actions', 'losses'})
                                    dStat.addValue = {crash = 1}
                                    dStat.default = {crash = 0, eject = 0}
                                    slmod.stats.advChangeStatsValue(dStat)
                                --- DO PVP STUFF
                                    --slmod.info('pvp stuff')
                                    if lHit.inAirHit or lHit.inAirHit == nil then
                                        --slmod.info('Do PvP Rules')
                                        --slmod.info('lastHitEvent.inAirHit: '  .. tostring(lHit.inAirHit))
                                        if slmod.config.pvp_as_own_stat and slmod.config.pvp_as_own_stat > 0 and type(killerObj) == 'table' and deadClient then 
                                            local countPvP, killerType, victimObj = PvPRules(lHit.unitName, deadName)
                                            
                                            if countPvP then  -- count in PvP!
                                                --slmod.info('valid PvP')
                                                saveStat.nest = {'pvp', 'typeName', 'kills'}
                                                saveStat.addValue = 1
                                                saveStat.default = 0
                                                slmod.stats.advChangeStatsValue(saveStat)
                                                
                                                dStat.nest = {'pvp', 'typeName', 'losses'}
                                                dStat.addValue = 1
                                                dStat.default = 0
                                                
                                                slmod.stats.advChangeStatsValue(dStat)
                                                
                                                if slmod.config.pvp_as_own_stat == 2 then
                                                    saveStat.nest = {'pvp', 'typeName', 'killSpec', weapon, deadObjType}
                                                    slmod.stats.advChangeStatsValue(saveStat)
                                                    
                                                    dStat.nest = getNest{'pvp', 'typeName', 'lossSpec', killerObjType, weapon}
                                                    slmod.stats.advChangeStatsValue(dStat)
                                                end
                                                
                                                slmod.scheduleFunction(onPvPKill, {killerObj, deadClient, weapon, killerType, victimObj, true}, DCS.getModelTime() + 0.5)
                                                --onPvPKill(killerObj, deadClient, weapon, killerObj, victimObj, true)
                                           end
                                        end
                                    end
                                end
                            else -- teamkilled 
                                
                                saveStat.penalty = true 
                                if weapon == 'kamikaze' then
                                    saveStat.nest = 'friendlyCollisionKills'
                                    ----slmod.info('KKill')
                                else
                                   saveStat.nest = 'friendlyKills'
                                end
                                saveStat.addValue = { time = os.time(), objCat = deadCategory, objTypeName = deadObjType, weapon = weapon, shotFrom = killerObjType}
                                local isPlayer = false
                                if deadClient then
                                    saveStat.addValue.human = ducid
                                    isPlayer = true
                                end
                                slmod.stats.advChangeStatsValue(saveStat)
                                slmod.scheduleFunction(onFriendlyKill, {killerObj, deadObjData, weapon, isPlayer}, DCS.getModelTime() + 0.5)
                                
                                saveStat.nest = getNest({'actions', 'losses'})
                                saveStat.addValue = {teamKilled = 1}
                                --onFriendlyKill(killerObj, deadObjData, weapon)
                            end
                             
                                
                                
                                --[[NOTE PROBABLY DELETE 
                                slmod.info('player hit by AI')
                                dStat.nest = getNest({'actions', 'losses'})
                                dStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                                dStat.addValue = {crash = 1}
                                slmod.stats.advChangeStatsValue(dStat)
                                ]]
                                
                            
                        else
                            if slmod.config.stats_coa > 1 then 
                                if type(killerObj) == 'table' then
                                    slmod.warning('SlmodStats- hitter (' .. slmod.oneLineSerialize(killerObj) .. ') is not an SlmodClient, and dead unit (unitName = ' .. tostring(deadName) .. ') is not an SlmodClient!')
                                else
                                    slmod.warning('SlmodStats- hitter (' .. tostring(killerObj) .. ') is not an SlmodClient, and dead unit (unitName = ' .. tostring(deadName) .. ') is not an SlmodClient!')
                                end
                            end
                        end
                        --slmod.info('check for death stats')
                        --Add detailed loss to player here
                        if deadClient or slmod.config.stats_coa == 2 then 
                            dStat.nest = getNest({'actions', 'losses'})
                            dStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                            dStat.addValue = {crash = 1}
                            slmod.stats.advChangeStatsValue(dStat)
                            
                            dStat.nest = getNest({'actions', 'lostTo', killerStatsCat, killerStatsType})
                            dStat.addValue = 1
                            dStat.default = 0
                            slmod.stats.advChangeStatsValue(dStat)
                            if slmod.config.kd_specifics == true then
                                dStat.nest = getNest({'spec', 'deaths', killerObjType, weapon})
                                slmod.stats.advChangeStatsValue(dStat)
                            end
                        end

                        
                        --slmod.info('end of kill stats')
                    else -- add assist
                       --slmod.info('in assist')
                        if weapon then
                            if saveStat.AI and saveStat.coa then
                                saveStat.coa = nil
                            end
                            --slmod.info('weapon')
                            saveStat.nest = getNest({'weapons', weapon})
                            saveStat.addValue = {assist = 1}
                            saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0, assist = 0}
                            slmod.stats.advChangeStatsValue(saveStat)
                            
                            if slmod.config.assists_level == 2 then
                                saveStat.nest = getNest({'weapons', weapon, 'aL', deadStatsCat, deadStatsType})
                                saveStat.default = 0
                                saveStat.addValue = 1
                                slmod.stats.advChangeStatsValue(saveStat)
                                if slmod.config.kd_specifics == true then
                                    saveStat.nest = getNest({'weapons', weapon, 'spec', 'assists', deadObjType})
                                    slmod.stats.advChangeStatsValue(saveStat)
                                end
                            end
                            
                        end 
                        --slmod.info('end of assist')
                    end
                end
                
			elseif deadClient or slmod.config.stats_coa == 2 then  -- client died without being hit.
                local saveStat = {}
                if deadClient then 
                    local ucid, typeName = {}, {}
                    for seat, data in pairs(deadClient) do
                        ucid[seat] = data.ucid
                        if seat > 1 then
                            typeName[seat] = multiCrewNameCheck(deadObjType, seat)
                        else
                            typeName[seat] = deadObjType
                        end
                        saveStat = {ucid = ucid, typeName = typeName}
                    end
                else
                    saveStat = {ucid = {deadUnit.coalition .. 'AI'}, typeName = {deadObjType}, AI = true}
                end
                saveStat.nest = getNest({ 'actions', 'losses'})
                if landedUnits[deadName] then 
                    saveStat.default = {crashLanding = 0}
                    saveStat.addValue = {crashLanding = 1}
                else
                    saveStat.default = {pilotError = 0}
                    saveStat.addValue = {pilotError = 1}
                end

                slmod.stats.advChangeStatsValue(saveStat)

			end
            
            
			
			-- wipe this unit if he is a hitHuman
            hitObjs[deadName] = nil
            runDeathLogicChecker[deadName] = nil 
		end
	end
	----------------------------------------------------------------------------------------------------------


	----------------------------------------------------------------------------------------------------------
	-- tracks flight times.

	function slmod.stats.trackFlightTimes(prevTime)  -- call every 10 seconds, tracks flight time.
		slmod.scheduleFunction(slmod.stats.trackFlightTimes, {DCS.getModelTime()}, DCS.getModelTime() + 10)  -- schedule first to avoid a Lua error.
		statsWriteBuffer()
		inAirClients = {}  -- reset upvalue inAirClients table.
		if prevTime and slmod.config.enable_slmod_stats then  -- slmod.config.enable_slmod_stats may be disabled after the mission has already started.
			local dt = DCS.getModelTime() - prevTime
            local metaFlightTime = 0
			-- first, update all client flight times.
			local coaFlightTimes = {}
            
            for id, client in pairs(slmod.clients) do -- for each player (including host)
                local side = slmod.getClientSide(id)
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
									if not coaFlightTimes[side] then
                                        coaFlightTimes[side] = {}
                                    end
                                    
                                    if retStr:sub(1, 4) == 'true' then  -- in air
										local typeName = retStr:sub(6) -- six to end.
										if client.ucid and stats[client.ucid] then
                                            if seatId > 0 then
                                                typeName = multiCrewNameCheck(typeName, seatId)
                                            end
                                            slmod.stats.advChangeStatsValue({ucid = client.ucid, nest = {'times', typeName}, addValue = {total = dt, inAir = dt}, default = {total = 0, inAir = 0}})

                                            metaFlightTime = metaFlightTime + dt
                                            
                                            if slmod.config.stats_coa > 0 then 
                                                if not coaFlightTimes[side][typeName] then
                                                    coaFlightTimes[side][typeName] = {total = 0, inAir = 0}
                                                end
                                                coaFlightTimes[side][typeName].total = coaFlightTimes[side][typeName].total + dt
                                                coaFlightTimes[side][typeName].inAir = coaFlightTimes[side][typeName].inAir + dt
                                            end
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
                                        if slmod.config.stats_coa > 0 then 
                                            if not coaFlightTimes[side][typeName] then
                                                coaFlightTimes[side][typeName] = {total = 0, inAir = 0}
                                            end
                                            coaFlightTimes[side][typeName].total = coaFlightTimes[side][typeName].total + dt
                                        end
									end
								end
							end
						end
					end
				end
			end  -- for id, client in pairs(slmod.clients) do
			if metaFlightTime > 0 then -- dont update it if nobody hasnt flown
                slmod.stats.updateMetaFlightInfo(metaFlightTime)
            end
            -- add all player states to respective coalition stats table if enabled
            if slmod.config.stats_coa > 0 then 
                for coaName, aircraft in pairs(coaFlightTimes) do
                    local saveStat = {ucid = coaName .. 'Players', default = {total = 0, inAir = 0}}
                    for airName, airStat in pairs(aircraft) do
                        saveStat.nest = {'times', airName}
                        saveStat.addValue = {total = airStat.total, inAir = airStat.inAir}
                        slmod.stats.advChangeStatsValue(saveStat)
                    end           
                end
            end
            
            
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
                if not slmod.oldClientsByName then -- Temp added because report this table not existing causing an error on some servers. Trying to find cause. 
                    slmod.info('checking ' .. eventInd)
                    slmod.info(slmod.oneLineSerialize(slmod.events[eventInd]))
                end       
				eventInd = eventInd + 1  -- increment NOW so if there is a Lua error, I'm not stuck forever on this event.
                
                
                local initiator -- load this for each event with standardized table
                local saveStat  -- use saveStat as a condition value for conditional stat saving. If it has a value then either a client did a thing or AI stats are enabled. 
                local ucid, typeName = {}, {}
                local initSide = event.initiator_coalition
                local initClient
                local testRun = false
                
                if slmod.allMissionUnitsByName[event.initiator] and not event.initiator_objtype then 
                    --slmod.info('objtype missing in event')
                    --slmod.info(slmod.oneLineSerialize(event))
                    event.initiator_objtype = slmod.allMissionUnitsByName[event.initiator].objtype
                end 
				if (slmod.clientsByRtId and (slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator])) or event.initiator == 'FakeShotDown' then
                    --slmod.info(event.initiator)
                    initiator = slmod.clientsByRtId[event.initiatorID] or slmod.oldClientsByName[event.initiator]
                    --[[slmod.info(slmod.oneLineSerialize(initiator))
                    if event.initiator == 'getShotDownEvent' then --- Fake event to bug test this
                        initiator = buildTestMultCrew(initiator)
                     
                    elseif event.initiator == 'FakeShotDown' then
                        initiator = buildTestAIAsClient()
                        event.initiatorPilotName = 'AnnoyingBug'
                  
                    end]]
                    for seat, data in pairs(initiator) do
                        ucid[seat] = data.ucid
                        if seat > 1 then
                            typeName[seat] = multiCrewNameCheck(event.initiator_objtype, seat)
                        else
                            typeName[seat] = event.initiator_objtype
                        end
                        saveStat = {ucid = ucid, typeName = typeName}
                       
                    end
                    if slmod.config.stats_coa > 0 then 
                        saveStat.coa = event.initiator_coalition 
                    end
                    initClient = true
                    --slmod.info(slmod.oneLineSerialize(initiator))
                else
                    initiator = slmod.allMissionUnitsByName[event.initiator]
                   -- slmod.info('assign saveStat to AI')
                    if slmod.config.stats_coa > 1 and initiator then
                        saveStat = {ucid = {initiator.coalition.. 'AI'}, typeName = {initiator.objtype}, AI = true}
                    end
                end


                --slmod.info(slmod.oneLineSerialize(saveStat))
                ----------------------------------------------------------------------------------------------------------
				--- Shot events
				--if (event.type == 'shot' or event.type == 'start shooting') and event.initiator_name and event.initiator_mpname and event.initiator_name ~= event.initiator_mpname then  -- human shot event
				--slmod.info('check shot')
                if (event.type == 'shot' or event.type == 'end shooting' or event.type == 'start shooting') and event.initiator then  -- human shot event
					if slmod.clientsByRtId then
                        if initiator and saveStat then -- don't check for specific seat I guess, just see if it exists. To many variables if hot swapping seats is added to more aircraft
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
                                saveStat.nest = getNest({'weapons', weapon})
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
                                    
                                if initClient then 
                                    humanShots[event.initiator] = weapon   -- for this initiator, store the name of the last weapon fired.
                                    if event.weaponID then  -- add to tracked weapons.  Right now, only bombs, rockets, and missiles will have an ID and only to track player weapons
                                        trackedWeapons[event.weaponID] = event.weaponID
                                    end
                                end
                                

                                
							end
						end
                    end
				end -- end shot events/start shooting events
				----------------------------------------------------------------------------------------------------------
				
				
				--slmod.info('check hit')
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
					local initUCID
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
						----slmod.info('target is not client')
						if slmod.allMissionUnitsByName[tgtName] then  
							tgtSide = slmod.allMissionUnitsByName[tgtName].coalition
							tgtCategory = slmod.allMissionUnitsByName[tgtName].category
							tgtTypeName = slmod.allMissionUnitsByName[tgtName].objtype
							----slmod.info('here2')
						else
                            if event.targetCategory and (event.targetCategory ~= 2 and event.targetCategory ~= 5) or not event.targetCategory then -- it is a scenery object or a weapon
                                slmod.error('error in stats, could not match target unit in hit event with a mission editor unit name.  Could it be a map object? Event Index: ' .. eventInd)
                            end
							----slmod.info(slmod.oneLineSerialize(event))
						end
						
					end
					-----------------------------------------------
					-- gather information on the initiator, if initiator was human.
					
					-- code for "killed by Building" compensation.
					if event.initiatorID == 0 then -- possible hit by a human
						--slmod.info('killed by building') -- leave this uncommented, just wanna see if it ever happens.
						if not ranhuman_hits then  -- first, see if I can get new human_hits from main simulation env.
							local str, err = net.dostring_in('server', 'return slmod.getLatestHumanHits()')
							if err then
								if str ~= 'no hits' then
									human_hits = slmod.deserializeValue(str)
									----slmod.info('here4')
								else
									----slmod.info('here5')
								end
							else
								slmod.warning('unable to get latest human_hits from server env, reason: ' .. str)
							end
							ranhuman_hits = true  -- don't need to run again this cycle.
						end
						
						if human_hits and #human_hits > 0 then -- there were some human hits
							for hitsInd = 1, #human_hits do
								----slmod.info('human hits greater than 0')
								----slmod.info(time)
								----slmod.info(human_hits[hitsInd].time)
								----slmod.info(tgtName)
								----slmod.info(human_hits[hitsInd].target)
								----slmod.info(human_hits[hitsInd].initiator)
									
								if time == human_hits[hitsInd].time and tgtName == human_hits[hitsInd].target and human_hits[hitsInd].initiator then  -- hit matches time and target id_.
									
									--slmod.info('here1')
									nonAliveHit = true
									initiator = human_hits[hitsInd].initiator
									initName = initiator.unitName
									initUCID = initiator.ucid
									initSide = initiator.coalition
									break
								end
							
							end
							
						end
					--[[elseif initName then
                        if event.initiatorPilotName and initName ~= event.initiatorPilotName then  -- almost certainly human, and ALIVE.
                            --slmod.info('redefine initiator')
                            initiator = slmod.clientsByRtId[event.initiatorID]
                        elseif slmod.oldClientsByName[initName] then -- was a human, but they are now dead. 
                            --slmod.info('redefine initiator OLD')                           
                           initiator = slmod.oldClientsByName[initName]
                        else  -- initiator probably not human.
						-- nothing right now...
                        
                        end]]
					

					end
					-----------------------------------------------------------
					
					-- OK, now we have data on target and initiator- hopefully, 99.999% accurate data!
					
					if saveStat and initName ~= tgtName then -- whoever didn't TK themself and its going to save the stat
						--slmod.info('log hit')
                        local givenPenalty = false
                        local addedHit = false
                        ----slmod.info(initType)
                        
                        if not initSide then 
                            for seat, clientData in pairs(initiator) do
                                initSide = clientData.coalition
                            end
                        end
                        -- first, handle the case of nil weapon.  Happens due to a bug in DCS, and is very difficult to solve this bug fully.
                        -- for now, just assume that the weapon is the last weapon the human fired.
                        if initClient and initName and humanShots[initName] then
                            if not weapon then
                                weapon = humanShots[initName]
                            elseif weapon and weapon == 'kamikaze' and unitIsAlive(initName) == true and event.targetCategory and (event.targetCategory == 3 or event.targetCategory == 6) then
                                weapon = humanShots[initName]
                            end     
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

                            if tgtSide and initSide then
                                local saveToHit = {time = time,  weapon = weapon, shotFrom = initType, rtid = event.initiatorID, unitName = initName, initiator_coalition = initSide}
                                if initClient then     
                                    saveToHit.initiator = parseOutExtraClientData(initiator)
                                else
                                    saveToHit.initiator = event.initiator_name
                                end
                                local tgtInfoForFHit = {[1] = {name = tgtName}}
                                if tgtSide == initSide then
                                    saveToHit.friendlyHit = true
                                end
                                
                                if tgtClient then 
                                    --slmod.info('tgt Client')
                                    if tgtClient[1].ucid and inAirClients[tgtClient[1].ucid] ~= nil then
                                        saveToHit.inAirHit = inAirClients[tgtClient[1].ucid]
                                    end
                                    saveToHit.target = slmod.deepcopy(parseOutExtraClientData(tgtClient))
                                    hitObjs[tgtName] = hitObjs[tgtName] or {}
                                    hitObjs[tgtName][#hitObjs[tgtName] + 1] = saveToHit
                                    --slmod.info('hitObjs added to')
                                    tgtInfoForFHit = slmod.deepcopy(tgtClient)
                                else
                                    hitObjs[tgtName] = hitObjs[tgtName] or {}
                                    hitObjs[tgtName][#hitObjs[tgtName] + 1] = saveToHit
                                end
                                
                                if tgtSide ~= initSide then  -- hits on enemy units in here
                                    --slmod.info('Hit Enemy')
                                    saveStat.default = {shot = 0, hit = 0, numHits = 0, kills = 0}
                                    saveStat.nest = getNest({'weapons', weapon})
                                    saveStat.addValue = {}
                                    saveStat.addValue.numHits = event.numtimes or 1
                                    --slmod.info('add Hits')
                                    if (event.weaponID and trackedWeapons[event.weaponID]) or isGun == true then  -- this is the first time this weapon hit something.
                                        if isGun == false then
                                            
                                            trackedWeapons[event.weaponID] = nil
                                        end
                                        saveStat.addValue.hit = 1
                                    end
                                    
                                    slmod.stats.advChangeStatsValue(saveStat)
                                    

                                else 
                                    --slmod.info('teamHit')
                                    if not saveStat.AI then -- AI are not allowed to get TKs for penalty purposes. 
                                        saveStat.penalty = true 
                                        if weapon == 'kamikaze' then
                                           ----slmod.info('set as collision')
                                           saveStat.nest = 'friendlyCollisionHits'
                                        else
                                           saveStat.nest = 'friendlyHits'
                                        end
                                        saveStat.addValue = { time = os.time(), objCat = tgtCategory, objTypeName = tgtTypeName, weapon = weapon, shotFrom = initType}
                                        local isPlayer = false
                                        if tgtClient then
                                            local hitClient = {}
                                            isPlayer = true
                                            for i = 1, #tgtClient do 
                                                if tgtClient[i].ucid then 
                                                    table.insert(hitClient, tgtClient[i].ucid)
                                                end
                                            end
                                            saveStat.addValue.human = hitClient
                                        end
                                        slmod.stats.advChangeStatsValue(saveStat)
                                        --slmod.info('schedule onFriendlyHit')
                                        slmod.scheduleFunction(onFriendlyHit, {initiator, tgtInfoForFHit, weapon, isPlayer}, DCS.getModelTime() + 0.2)
                                        --onFriendlyHit(initiator, tgtInfoForFHit, weapon)
                                    end    
                                end
                            else
                                if event.targetCategory ~= 5 and (not event.initiatorScenery) then
                                    
                                    slmod.error('SlmodStats error- either tgtSide or initSide does not exist for hit event! Event Line follows:')
                                    slmod.warning(slmod.oneLineSerialize(event))
                                end
                            end
                            
                        end
                        
                    elseif tgtClient and not initClient then -- only case left unhandled in above code: AI hits human and AI stats arent being saved
                        local inAirHit
                        if tgtClient[1].ucid and inAirClients[tgtClient[1].ucid] ~= nil then
                            inAirHit = inAirClients[tgtClient[1].ucid]
                        end
                    
                        hitObjs[tgtName] = hitObjs[tgtName] or {}
                        hitObjs[tgtName][#hitObjs[tgtName] + 1] = {time = time, initiator = initName, target = slmod.deepcopy(tgtClient), inAirHit = inAirHit, weapon = weapon, shotFrom = initType, initiator_coalition = initSide}
                        ----slmod.info('here9')
                    
                    
					end
				end -- end of hit events.
				----------------------------------------------------------------------------------------------------------
				
				--[[if event.type == 'birth' then
					--slmod.info('here')
					--slmod.info(#slmod.allMissionUnitsByName)
				
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
                    if saveStat and event.initiator then 
                        local deadClient = slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator]
                        if deadClient then
                            saveStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                            saveStat.nest = getNest({'actions', 'losses'})
                            saveStat.addValue = {pilotDeath = 1}
                            slmod.stats.advChangeStatsValue(saveStat)
                        end
                        
                        if deadClient and slmod.config.save_best_life and slmod.config.save_best_life > 0 then
                            --checkLifeEnd({ucids = saveStat.ucid, eventName = 'pilotDead', client = deadClient})
                        end
                        
                    end
				end -- end of pilot dead
				----------------------------------------------------------------------------------------------------------

				----------------------------------------------------------------------------------------------------------
				if event.type == 'land' then  -- check if this is the valid name.
                    if event.initiator then 
                        local lUnit = {}
                        lUnit.t = DCS.getModelTime()
                        if hitObjs[event.initiator] then
                            lUnit.hit = true
                        end
                        if saveStat then 
                            saveStat.nest = getNest({ 'actions', 'landing'})
                            if event.target then
                                if slmod.allMissionUnitsByName[event.target] then
                                    if slmod.allMissionUnitsByName[event.target].category == 3 then
                                        table.insert(saveStat.nest, 'FARP')
                                    else
                                        table.insert(saveStat.nest, slmod.allMissionUnitsByName[event.target].objtype)
                                    end
                                else
                                    table.insert(saveStat.nest, 'airbase')
                                    if slmod.config.stats_level == 2 then
                                        saveStat.nestAlt = slmod.deepcopy(saveStat.nest)
                                        saveStat.nestAlt[#saveStat.nestAlt] = 'baseList'
                                        table.insert(saveStat.nestAlt, event.target)
                                    end
                                end
                            else
                                table.insert(saveStat.nest, 'austere')
                            end
                            saveStat.default = 0
                            saveStat.addValue = 1
                            --slmod.stats.advChangeStatsValue(saveStat)
                            lUnit.saveStat = slmod.deepcopy(saveStat)
                            --slmod.info('landing event at: ' .. event.place)
                            if event.target and slmod.allMissionUnitsByName[event.target] then
                                local objData = slmod.allMissionUnitsByName[event.target]
                                if objData.category == 'ship' then
                                    --slmod.info('someoneLandedOnShip')
                                    lUnit.ship = true
                                    if slmod.clientsByName[event.initiator] then
                                        --slmod.info('was a player')
                                
                                        local modEvent = slmod.deepcopy(event)
                                        modEvent.ucid = saveStat.ucid
                                        modEvent.typeName = saveStat.typeName
                                        table.insert(cvLandings, modEvent)
                                        --slmod.info('inserted into cvLandings')
                                        slmod.scheduleFunction(clearCVLanding, {event.t}, DCS.getModelTime() + 3.5)
                                    end
                                end
                            end
                        end
                        landedUnits[event.initiator] = lUnit
					end
				end -- end of land
				----------------------------------------------------------------------------------------------------------
				if event.type == 'comment' then -- Attempt to add LSO score for player
                    if event.place and type(event.place) == 'string' and string.find(event.place, "LSO") then
                    --[[Notes for future. 
                        Probably just put everything into the cvLandings loop. 
                        saveStat.default keeps inserting all that into sub-tables. Need to write default table first or values one at a time. Then Add grade. Then add wire
                        slmod.stats.advChangeStatsValue needs a insertAt entry so it can insert at the start of the list. Would be useful if I create a grade count limit. Players after a while will get a ton of traps...
                        bolter comment doesnt seem to be called via event...
                    ]]
                        --slmod.info('LSO EVENT')
                        --if string.find(event.place, 'WO') then -- It was a wave off
                            -- difficult to know precise data because there is FUCKING NO OTHER DATA. Would have to guess, and I don't want to do that. 
                        if string.find(event.place, 'WIRE') then -- caught a wire. 
                            if cvLandings and #cvLandings > 0 then
                                --slmod.info('check landings')
                                for i = #cvLandings, 1, -1 do
                                    local lEvent = cvLandings[i]

                                    
                                    
                                    if cvLandings[i].ucid then 
                                        --slmod.info('was a player')
                                        saveStat.ucid = cvLandings[i].ucid
                                        saveStat.nest = getNest({'actions', 'LSO'})
                                        saveStat.default = {['1'] = 0, ['2'] = 0, ['3'] = 0, ['4'] = 0, grades = {}}
                                        saveStat.typeName = cvLandings[i].typeName
                                        local findWire = string.find(event.place, 'WIRE')
                                        local wire = tostring(string.match(event.place, '%d', findWire))
                                        --slmod.info(wire)
                                        if wire then --- maybe isn't there, aka NO Communication
                                            saveStat.addValue = {[wire] = 1}
                                            slmod.stats.advChangeStatsValue(saveStat) -- Add LSO stat table
                                        end                                           
                                        saveStat.nest = getNest({'actions', 'LSO', 'grades'})
                                        saveStat.default = {}
                                        saveStat.addValue = nil
                                        saveStat.insert = event.place
                                        slmod.stats.advChangeStatsValue(saveStat)
                                    end
                                    --slmod.info('cleared via LSO score')
                                    cvLandings[i] = nil
                                end
                                
                            end
                        end
                    end                
                end
                
                if event.type == 'landing quality mark' and event.initiator and event.comment and saveStat then
                    saveStat.nest = getNest({'actions', 'LSO'})
                    saveStat.default = {['1'] = 0, ['2'] = 0, ['3'] = 0, ['4'] = 0, grades = {}}
                    local findWire = string.find(event.comment, 'WIRE')
                    local wire = tostring(string.match(event.comment, '%d', findWire))
                    --slmod.info(wire)
                    if wire then --- maybe isn't there, aka NO Communication
                        saveStat.addValue = {[wire] = 1}
                        slmod.stats.advChangeStatsValue(saveStat) -- Add LSO stat table
                    end                                           
                    saveStat.nest = getNest({'actions', 'LSO', 'grades'})
                    saveStat.default = {}
                    saveStat.addValue = nil
                    saveStat.insert = event.comment
                    slmod.stats.advChangeStatsValue(saveStat)
                
                end
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'takeoff' then  -- check if this is the valid name.
                    if saveStat then
                        saveStat.default = 0
                        saveStat.addValue = 1
                        if landedUnits[event.initiator] then
                            saveStat.nest = getNest({ 'actions', 'bounced'})
                            
                            if event.target_objtype and slmod.allMissionUnitsByName[event.target] then 
                                local tObjType = slmod.catsByUnitType[event.target_objtype]
                                local iObjType = slmod.catsByUnitType[event.initiator_objtype]
                                if iObjType and tObjType and  iObjType[1] == 'Planes' and tObjType[1] == 'Ships' then 
                                    saveStat.nest[#saveStat.nest] = 'bolter'
                                end
                            end
                            
                        else
                            saveStat.nest = getNest({ 'actions', 'takeoff'})
                            if event.target then
                                if slmod.allMissionUnitsByName[event.target] then
                                    if slmod.allMissionUnitsByName[event.target].category == 3 then
                                        table.insert(saveStat.nest, 'FARP')
                                    else
                                        table.insert(saveStat.nest, slmod.allMissionUnitsByName[event.target].objtype)
                                    end
                                    
                                else
                                    table.insert(saveStat.nest, 'airbase')
                                    slmod.stats.advChangeStatsValue(saveStat)
                                    if slmod.config.stats_level == 2 then
                                        saveStat.nest[#saveStat.nest] = 'baseList'
                                        table.insert(saveStat.nest, event.target)
                                    end
                                end
                            else
                                table.insert(saveStat.nest, 'austere')
                            end
                        end
                        slmod.stats.advChangeStatsValue(saveStat)
                        landedUnits[event.initiator] = nil
					end
				end
				----------------------------------------------------------------------------------------------------------
				
				
				
				----------------------------------------------------------------------------------------------------------
				if event.type == 'eject' then
					if saveStat then
						local deadClient = slmod.clientsByName[event.initiator] or slmod.oldClientsByName[event.initiator]
						if deadClient then
							saveStat.default = {crash = 0, eject = 0, pilotDeath = 0}
                            saveStat.nest = getNest({'actions', 'losses'})
                            saveStat.addValue = {eject = 1}
                            slmod.stats.advChangeStatsValue(saveStat)
                            
                            --checkLifeEnd({eventName = 'eject', ucids = saveStat.ucid, client = deadClient })
						end
					end				
				end	-- end of eject
				----------------------------------------------------------------------------------------------------------
				if event.type == 'refueling' and saveStat then -- Refueling event does not work on clients, but has been reported since 2.5.5.40647
                    refuelings[event.initiator] = DCS.getModelTime()
                end
                
                if event.type == 'refueling stop' then
                    if saveStat then
                        if event.initiator and refuelings[event.initiator] then 
                            local rTime = event.t - refuelings[event.initiator]
                            saveStat.default = {total = 0, connects = 0, short = 0, med = 0, long = 0}
                            saveStat.nest = getNest({'actions', 'tanking'})
                            saveStat.addValue = {connects = 1}
                            saveStat.addValue.total = rTime
                            if rTime < 10 then
                                saveStat.addValue.short = 1
                            elseif rTime >= 10 and rTime < 60 then
                                saveStat.addValue.med = 1
                            else    
                                saveStat.addValue.long = 1
                            end
                            slmod.stats.advChangeStatsValue(saveStat)
                            refuelings[event.initiator] = nil
                        end
                    end
                end
                
                
				
			end  -- end of while loop.
			
			-- If a hitHuman lands and comes to a stop after landing without dying, remove them from hit units.
			local currentTime = DCS.getModelTime()
			for unitName, landData in pairs(landedUnits) do
				
                if slmod.activeUnitsByName[unitName] then
	
                    if currentTime - landData.t > 10 then  -- start checking to see if the unit is stationary.
                        if unitIsStationary(unitName) or landData.ship then
							if landData.saveStat then 
                                slmod.stats.advChangeStatsValue(landData.saveStat)

                                if landData.saveStat.nestAlt then   -- not very elegant
                                    local tStat = slmod.deepcopy(landData.saveStat)
                                    tStat.nest = tStat.nestAlt
                                    slmod.stats.advChangeStatsValue(tStat)
                                end
                                
                                if hitObjs[unitName] then
                                    landedUnits[unitName].saveStat.nest[#landedUnits[unitName].saveStat.nest] = 'landedWhileDamaged'
                                    slmod.stats.advChangeStatsValue(landData.saveStat)
                                end
                            end
                            --slmod.info(unitName .. ' was a hit unit and has landed safely, clear it so it cant be TKd')
                            hitObjs[unitName] = nil
							landedUnits[unitName] = nil
                            
						end
					end
				else
					landedUnits[unitName] = nil
				end
			
			end
			
			
			--[[If any entries in hitObjs are no longer alive, then it counts it as a death, and removes the entry of hitObjs.
			The removal of that entry in hitObjs prevents a potential future "dead" event from counting as an additional death.
			Remember- hitObjs only includes humans that were hit, so this function won't erroneously count crashes for no reason.
			
			ALSO, clear the landedUnits table entry for this unit if it is not alive.]]
			
			-- NOW, check to see if any hitObjs are non-existant.
			for unitName, hits in pairs(hitObjs) do
				if not unitIsAlive(unitName) then
					----slmod.info('SlmodStats- hit client unitName: ' .. unitName .. ', hits[#hits]: ' .. slmod.oneLineSerialize(hits[#hits]) .. '  no longer exists, running death logic.')
					
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
    
    function slmod.stats.getMisStats()
        if misStats then
            return misStats
        end
    end
    
    function slmod.stats.getCampaignStats()
        if campStats then
            return campStats
        end
    end
	
    function slmod.custom_stats_net(saveStat)
         -- Formatted in advanced save tbl.
        if saveStat then

            if saveStat.unit and (type(saveStat.unit) == 'string' or type(saveStat.unit) == 'number') then
                local client
                local objType
                local typeName = {}
                local ucid = {}
                local unitId
                if type(saveStat.unit) == 'string' then -- can be unit id or unitName overload it?
                -- try to figure out the unit to apply the stat to
                    if slmod.allMissionUnitsByName[saveStat.unit] then
                        unitId = slmod.allMissionUnitsByName[saveStat.unit].unitId
                    end
                elseif type(saveStat.unit) == 'number' then
                     unitId = saveStat.unit
                end
                
                if unitId then
                    objType = slmod.allMissionUnitsById[unitId].objtype
                    local rt = slmod.getClientRtId(unitId)
                    client = slmod.clientsByRtId[tonumber(rt)]
                end
                if client then 
                    for seat, data in pairs(client) do
                        ucid[seat] = data.ucid
                        if seat > 1 then
                            typeName[seat] = multiCrewNameCheck(objType, seat)
                        else
                            typeName[seat] = objType
                        end
                    end
                else
                    slmod.info('CustomStat; client failed to return. Was given: ' .. saveStat.unit)
                end
                saveStat.ucid = ucid
                saveStat.typeName = typeName
            end

            if saveStat.nest then -- Force stat to only have access to custom nest. 
                local tempNest = {}
                if type(saveStat.nest) == 'string' then
                    tempNest = {'custom', saveStat.nest}
                elseif type(saveStat.nest) == 'table' then
                    if saveStat.nest[1] then
                        if type(saveStat.nest[1]) == 'string' and string.lower(saveStat.nest[1]) ~= 'custom' then
                            table.insert(tempNest, 'custom')
                        end
                        for i = 1, #saveStat.nest do
                            if type(saveStat.nest[i]) == 'string' then
                                 table.insert(tempNest, saveStat.nest[i])
                            end
                        end
                    end

                end
                saveStat.nest = tempNest -- rewrite the nest no matter what
            end
            if #saveStat.ucid > 0 and saveStat.nest and (saveStat.insert or saveStat.addValue or saveStat.setValue) then
                saveStat.unit = nil
                slmod.stats.advChangeStatsValue(saveStat)
            end
        
        end       
        
    
    end


	
end


slmod.info('SlmodStats.lua loaded.')