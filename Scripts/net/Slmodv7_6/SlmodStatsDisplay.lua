slmod.stats = slmod.stats or {}  -- make table anyway, need it.
do


-- Additional functions for interfacing with private stats data.
	-- ***BEGINNING OF STATS USER INTERFACE***
    local stats
    local penStats
    local misStats
    local campStats
    
    function slmod.stats.displayInit()
       --slmod.info('display stats init')
        stats = slmod.stats.getStats()
        penStats = slmod.stats.getPenStats()
        misStats = slmod.stats.getMisStats()
        campStats = slmod.stats.getCampaignStats()
    end
    
    
    local function checkStatsMode(requesterMode)
        local rtnStats = {}
        if requesterMode == 'mission' and misStats then
            rtnStats = misStats
        elseif requesterMode == 'campaign' and campStats then
            rtnStats = campStats
        else
            rtnStats = stats
        end
        
        return rtnStats
    end
    
    
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
	local function createSimpleStats(ucid, mode, subM)
		--[[
		Summarized stats for player: "Speed", SlmodStats ID# 9:
		  | TIME: 23231.2 hours | PvP KILL/DEATH: 30300/1229 | KILLS: Air = 4132, Grnd/Sea = 3093, Friendly = 9 | LOSSES: 2331
		
		TO MODIFY SLIGHTLY
        
        add ability to view bestLife and currentLife stats
		
		]]

		-- FUNCTION USUALLY EXPECTS A UCID.  However, overload it to directly accept a stats table!
        
        
        
      --slmod.info('simple')
        if stats[ucid] or type(ucid) == 'table' then
			local pStats
            local sStats
            if type(ucid) == 'string' then
				if (not mode) or mode == 'server' then
					pStats = stats[ucid]
				elseif mode == 'mission' and slmod.config.enable_mission_stats and misStats then
					pStats = misStats[ucid]
				end
			else
				pStats = ucid
			end
          --slmod.info('if pstats')
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
                      --slmod.info('kill list')
                local killList = {['Ground Units'] = 0, ['Planes'] = 0, ['Helicopters'] = 0, ['Ships'] = 0, ['Buildings'] = 0}
                local pvp = {kills = 0, losses = 0}
                local losses = 0 
              --slmod.info('platform')
                for platform, times in pairs(pStats.times) do
					slmod.info(platform)
                    totalTime = totalTime + times.total
                    if times.kills then
                      --slmod.info('times.kills')
                        for cat, catData in pairs(times.kills) do
                          --slmod.info(cat)
                            if killList[cat] then
                              --slmod.info(catData.total)
                                killList[cat] = killList[cat] + catData.total
                            end
                        end                    
                    end
                    if times.weapons then
                      --slmod.info('times.weapons')
                        for wepName, wepData in pairs(times.weapons) do
                          --slmod.info(wepName)
                            if type(wepData) == 'table' and wepData.kL then
                              --slmod.info('kil')
                                for cat, catData in pairs(wepData.kL) do
                                    if killList[cat] then
                                        if catData.total then
                                          --slmod.info(catData.total)
                                            killList[cat] = killList[cat] + catData.total
                                        else
                                           if type(catData) == 'table' then
                                                for k, kVal in pairs(catData) do
                                                    killList[cat] = killList[cat] + kVal
                                                end
                                            end
                                        end
                                    end
                                end 
                            end
                        end
                    
                    end
                    if times.action then 
                      --slmod.info('action')
                        if times.actions.losses then
                          --slmod.info('losses')
                            losses = times.actions.losses.crash + losses
                        end
                        
                        if times.actions.pvp then
                          --slmod.info('pvp')
                            pvp.kills = times.actions.pvp.kills + pvp.kills
                            pvp.losses = times.actions.pvp.losses + pvp.losses
                        end
                    end
				end
                      --slmod.info('pvp')
                if pStats.PvP then
                    pvp.kills = pStats.PvP.kills + pvp.kills
                    pvp.losses = pStats.PvP.losses + pvp.losses
                end
                      --slmod.info('losses')
                if pStats.losses then
                    losses = losses + pStats.losses.crash
                end
				
				sTbl[#sTbl + 1] = string.format('%.1f', totalTime/3600)
				sTbl[#sTbl + 1] = ' hours | PvP K/D: '
				sTbl[#sTbl + 1] = tostring(pvp.kills)
				sTbl[#sTbl + 1] = '/'
				sTbl[#sTbl + 1] = tostring(pvp.losses)
				sTbl[#sTbl + 1] = ' | KILLS: Air = '
                      --slmod.info('kills')
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
                      --slmod.info('summary')
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
				local acStats
                if ac and pStats.times[ac] then
                    acStats = pStats.times[ac]
                end
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
				local losses = {crash = 0, eject = 0, pilotDeath = 0, pilotError = 0, crashLanding = 0}
               --slmod.info('do plat') 
				for i = 1, #platforms do
					if pStats.times[platforms[i]].total then 
                       --slmod.info(i)
                       --slmod.info(platforms[i])
                        local line = '                                                                                                                             \n'
                        line = stringInsert(line, platforms[i], 5)  -- insert platform name.
                       --slmod.info('insertLine')
                        aTime =  pStats.times[platforms[i]].inAir + aTime
                       --slmod.info('aTime')
                        tTime =  pStats.times[platforms[i]].total + tTime
                       --slmod.info('tTime')
                        local inAirTime = string.format('%.2f', pStats.times[platforms[i]].inAir/3600)
                       --slmod.info('pATime')
                        local totalTime = string.format('%.2f', pStats.times[platforms[i]].total/3600)
                       --slmod.info('pTTime')
                        line = stringInsert(line, inAirTime, 27)  -- insert inAirTime
                        line = stringInsert(line, totalTime, 49)  -- insert totalTime
                       --slmod.info('addtotbl')
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
                        
                        if pStats.times[platforms[i]].weapons then 
                            for wepName, wepData in pairs(pStats.times[platforms[i]].weapons) do
                               --slmod.info(wepName)
                                if type(wepData) == 'table' and wepData.kL then
                                   --slmod.info('killList')
                                    for cat, catData in pairs(wepData.kL) do
                                       --slmod.info(cat)
                                        if killList[cat] and type(catData) == 'table' then
                                            for killType, killNum in pairs(catData) do
                                               --slmod.info(killType)
                                               --slmod.info(killNum)
                                                if killList[cat][killType] then
                                                   killList[cat][killType] = killList[cat][killType] + killNum -- add to the killType
                                                end                                    
                                            end
                                        end
                                    end    
                                end
                            end
                        end
                        
                       --slmod.info('actions')
                        if pStats.times[platforms[i]].actions then 
                           --slmod.info('losses')
                            if pStats.times[platforms[i]].actions.losses then
                                for statType, statData in pairs(pStats.times[platforms[i]].actions.losses) do
                                    if not losses[statType] then
                                        losses[statType] = 0
                                    end
                                    losses[statType] =  losses[statType] + statData
                                end
                            end
                           --slmod.info('pvp')
                            if pStats.times[platforms[i]].actions.pvp then
                                for statType, statData in pairs(pStats.times[platforms[i]].actions.losses) do
                                    pvp[statType] =  pvp[statType] + statData
                                end                           
                            end
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
                
                if pStats.weapons then
                    for wepName, wepData in pairs(pStats.weapons) do
                      --slmod.info(wepName)
                        if type(wepData) == 'table' and wepData.kL then
                          --slmod.info('killList')
                            for cat, catData in pairs(wepData.kL) do
                              --slmod.info(cat)
                                if killList[cat] and type(catData) == 'table' then
                                    for killType, killNum in pairs(catData) do
                                      --slmod.info(killType)
                                      --slmod.info(killNum)
                                        if killList[cat][killType] then
                                           killList[cat][killType] = killList[cat][killType] + killNum -- add to the killType
                                        end                                    
                                    end
                                end
                            end    
                        end
                    end
                end
              --slmod.info('kill strings')
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
              --slmod.info('maxsize')
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
              --slmod.info('totals')
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
                p1Tbl[#p1Tbl + 1] = ';  Pilot Error: '
                p1Tbl[#p1Tbl + 1] = tostring(losses.pilotError)
                p1Tbl[#p1Tbl + 1] = ';  Crash Landing: '
                p1Tbl[#p1Tbl + 1] = tostring(losses.crashLanding)
                p1Tbl[#p1Tbl + 1] = ';\n\n'
                
              --slmod.info('ac check')
                if ac then
                    if acStats.actions and acStats.actions.LSO then -- LSO display, only show if doing aircraft specific stats
                        for i = 1, 5 do -- Forrestal has 5 wires...
                            if acStats.actions.LSO[tostring(i)] then
                                p1Tbl[#p1Tbl + 1] = 'WIRE: #'
                                p1Tbl[#p1Tbl + 1] = i
                                p1Tbl[#p1Tbl + 1] = '  x'
                                p1Tbl[#p1Tbl + 1] = acStats.actions.LSO[tostring(i)]
                                p1Tbl[#p1Tbl + 1] = '     '
                            end
                        
                        end
                        if acStats.actions.LSO.grades and #acStats.actions.LSO.grades > 0 then
                            local count = 0
                            p1Tbl[#p1Tbl + 1] = '\nUp to 5 most recent landing scores\n'
                            for i = #acStats.actions.LSO.grades, 1, -1 do
                                count = count + 1
                                if count <= 5 then 
                                    p1Tbl[#p1Tbl + 1] = '\n   '
                                    p1Tbl[#p1Tbl + 1] = tostring(count)
                                    p1Tbl[#p1Tbl + 1] = ': '
                                    p1Tbl[#p1Tbl + 1] = acStats.actions.LSO.grades[i]
                                else
                                    break
                                end
                            end
                        
                        
                        end
                        
                    end
                end
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
                              --slmod.info(wepName)
                                if type(wepData) == 'table' and not weaponDat[wepName] then
                                  --slmod.info('created')
                                    weaponDat[wepName] = wepData
                                    weaponNames[#weaponNames + 1] = wepName
                                else
                                    if type(wepData) == 'table' then 
                                        for wepStat, wepVal in pairs(wepData) do
                                            if type(wepVal) == 'number' then 
                                                if not weaponDat[wepName][wepStat] then
                                                    weaponDat[wepName][wepStat] = 0
                                                end
                                                weaponDat[wepName][wepStat] = weaponDat[wepName][wepStat] + wepVal
                                            end
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
                      --slmod.info(weaponName) 
                        if not weaponDat[weaponName] then
                            weaponDat[weaponName] = weaponData
                            weaponNames[#weaponNames + 1] = weaponName

                        else
                            for wepStat, wepVal in pairs(weaponData) do
                                if type(wepVal) == 'number' then 
                                    if not weaponDat[weaponName][wepStat] then
                                        weaponDat[weaponName][wepStat] = 0
                                    end
                                    weaponDat[weaponName][wepStat] = weaponDat[weaponName][wepStat] + wepVal
                                end
                            end
                        end
                    end
                end
              --slmod.info('sort weaps') 
                table.sort(weaponNames)  -- put in alphabetical order
               --slmod.info('sorted')
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
			statsModes = {'mission', 'server', 'campaign'},
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
          --slmod.info('checkStatsMode')
			local statsToUse = checkStatsMode(requesterMode)
                
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
               --slmod.info('requester: '.. slmod.oneLineSerialize(requester))
                if not stats then
                   --slmod.info('Stats table not loaded')
                    slmod.stats.displayInit()
                end
               
				if stats and stats[requester.ucid] then  -- this check invalid if server stats ever optionally disabled.
                  --slmod.info('is in stats')
					local requesterMode = self:getMenu().modesByUcid[slmod.clients[clientId].ucid]
                  --slmod.info('StatsTouse')
                    local statsToUse = checkStatsMode(requesterMode)
					--slmod.info('get detailed')
                    local page1, page2 = createDetailedStats(statsToUse[requester.ucid], requesterMode)
					--slmod.info('schedule')
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
                local statsToUse = checkStatsMode(requesterMode)



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
	
                local statsToUse = checkStatsMode(requesterMode)

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
                        local statsToUse = checkStatsMode(requesterMode)

					
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
	
	-- ***END OF STATS USER INTERFACE***


	
end


slmod.info('SlmodStatsDisplay.lua loaded.')