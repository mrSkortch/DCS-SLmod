do
	--[[ todo:
	"forgive player" menu
	]]

	local stats = slmod.stats.getStats()
	local autoAdmin = slmod.config.autoAdmin
    local delayedPenalty = {}
    local affirmativeTKConsent = {}
    
    local penaltyCheckActive = false

    function slmod.appendAutoAdminExemptList()
       if slmod.exemptAll then -- append external exemption all list to the local one
            for id, data in pairs(slmod.exemptAll) do
                if not autoAdmin.exemptionList[id] then
                    autoAdmin.exemptionList[id] = data
                end
            end
        end
        if slmod.exemptAutoAdmin then
            for id, data in pairs(slmod.exemptAutoAdmin) do -- check if anyone is only on the exempt autoAdmin list
                if not autoAdmin.exemptionList[id] then
                    autoAdmin.exemptionList[id] = data
                end
            end
        end
        return
    end
	
	local function checkedKick(id, ucid, kickMsg)  -- kick with verification of kicked player Ucid.
		if slmod.clients[id] and slmod.clients[id].ucid == ucid then -- make sure it's the same player!
			net.kick(id, kickMsg)
		end
	end
    
    local function checkedKickToSpec(id, ucid, kickMsg)
        if slmod.clients[id] and slmod.clients[id].ucid == ucid then 
            net.force_player_slot(id, 0, '')
        end
    end
	
	local function delayedKick(id, ucid, kickMsg, delay)
		delay = delay or 10
		kickMsg = kickMsg or 'You were kicked.'
        if autoAdmin.showPenaltyKickBanActions then
           local score = slmod.getUserScore(ucid)
           kickMsg = string.gsub(kickMsg, '%.' , ' with: ' .. string.format("%.2f", tostring(score)) .. ' penalty points.') 
        end
		slmod.scheduleFunctionByRt(checkedKick, {id, ucid, kickMsg}, DCS.getRealTime() + delay)
	end
    
    local function delayedKickToSpec(id, ucid, kickMsg, delay)
        delay = delay or 10
		kickMsg = kickMsg or 'You were kicked back to spectator.'
        if autoAdmin.showPenaltyKickBanActions then
           local score = slmod.getUserScore(ucid)
           kickMsg = string.gsub(kickMsg, '%.' , ' with: ' .. string.format("%.2f", tostring(score)) .. ' penalty points.') 
        end
		slmod.scheduleFunctionByRt(checkedKickToSpec, {id, ucid, kickMsg}, DCS.getRealTime() + delay)        
    end
	
	if autoAdmin.kickBanDelay.kickDelay then
		if type(autoAdmin.kickBanDelay.kickDelay) == 'string' and tonumber(type(autoAdmin.kickBanDelay.kickDelay)) then
			autoAdmin.kickBanDelay.kickDelay = tonumber(autoAdmin.kickBanDelay.kickDelay)
		end
		
		if autoAdmin.kickBanDelay.kickDelay < 10 then
			autoAdmin.kickBanDelay.kickDelay = 10
		end
	end
	
	if autoAdmin.kickBanDelay.banDelay then
		if type(autoAdmin.kickBanDelay.banDelay) == 'string' and tonumber(type(autoAdmin.kickBanDelay.banDelay)) then
			autoAdmin.kickBanDelay.banDelay = tonumber(autoAdmin.kickBanDelay.banDelay)
		end
		
		if autoAdmin.kickBanDelay.banDelay < 10 then
			autoAdmin.kickBanDelay.banDelay = 10
		end
	end
	
	--------------------------------------------------------------------------------------------------------------
	-- evaluate AutoAdmin rules... CALL THIS FUNCTION USING PCALL.   Users might mess up their config files!
	local function autoAdminScore(ucid, det)
		--slmod.info('getAutoAdminScore')
        local function scorePilot(ucid, detailed) -- this will contain all the logic.  autoAdminScore calls this function with pcall.
			--slmod.info('scoring pilot: ' .. tostring(ucid))
			local toDays = function(s)
				return math.abs(s/(24*3600))
			end
			
			local function getWeight(curve, time)  -- gets the fractional weight of the offense 
				-- first, find the two points on the curve that this time lies between.
				local cPoint 
				local weight
				for ind = 1, #curve do
					-- slmod.info('time and curve')
					-- slmod.info(time)
					-- slmod.info(curve[ind].time)
					if time <= curve[ind].time then
						cPoint = ind - 1
						break
					end
				end
				--slmod.info('cPoint')
				--slmod.info(cPoint)
				-- cPoint could be 0, or still nil, or, it could be the actual relavant point.
				if cPoint == 0 then  -- it shouldn't come to this, but someone could screw up their curves.
					return 1
				end
				if not cPoint then  -- old events will end up here.  Assume that weight is the value of hte last point.
					return curve[#curve].weight
				end
				
				if not weight then  -- weight is still nil, it must fall between two points.  Interpolate weight.
					local t1 = curve[cPoint].time
					local t2 = curve[cPoint + 1].time
					local w1 = curve[cPoint].weight
					local w2 = curve[cPoint + 1].weight
					local slope = (w2-w1)/(t2-t1)
					--slmod.info('getWeight value: ' .. tostring((time - t1)*slope + w1))
					return (time - t1)*slope + w1
				end
			end
			
		
			local pStats = stats[ucid]
            local d = {penalties = {[1] = {time = math.huge, type = 'ERASEME'}}, misc = {}}
            --[[
            penalties = {[1] = {type = teamHit, player = {if applicable}, time, pointsAdded, expireTime}}
            misc = {teamHit = {active, total, forgiven}, teamKill = (repeat)}
            banInfo = {timesAutoBanned, expectedUnBanTime in Days}
            -- ON player try connect and banned, could try to say when they get unbanned?
            ]]
			if pStats and autoAdmin and (autoAdmin.autoBanEnabled or autoAdmin.autoKickEnabled or autoAdmin.autoSpecEnabled) then
				local score = 0  -- penalty score
				local curTime = os.time()
				-- score team hits
				if autoAdmin.teamHit.enabled and pStats.friendlyHits then  -- score team hits.
                    local lastAIHitTime  -- a time.
					local lastHumanHitTime
                    local dStats = {total = 0, active = 0, forgiven = 0}
					for hitInd = 1, #pStats.friendlyHits do
                        local hit = pStats.friendlyHits[hitInd]
                        local pen = 0
						if type(hit) == 'table' and hit.time and (not hit.forgiven) then -- I may be being obsessive-compulsive here...
                            local timeSince = toDays(curTime - hit.time)
							local weight = getWeight(autoAdmin.teamHit.decayFunction, timeSince)
							if hit.human then -- a human was hit
								if not lastHumanHitTime or ((hit.time - lastHumanHitTime) > autoAdmin.teamHit.minPeriodHuman) then  -- count this hit
									lastHumanHitTime = hit.time
                                    pen = weight*autoAdmin.teamHit.penaltyPointsHuman
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if hit.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = hit.time, type = 'teamHit', pointsAdded = pen, human = true, expireTime = autoAdmin.teamHit.decayFunction[#autoAdmin.teamHit.decayFunction].time - timeSince, weapon = hit.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							else
                                if not lastAIHitTime or ((hit.time - lastAIHitTime) > autoAdmin.teamHit.minPeriodAI) then  -- count this hit
                                    lastAIHitTime = hit.time
                                    pen = weight*autoAdmin.teamHit.penaltyPointsAI
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if hit.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = hit.time, type = 'teamHit', pointsAdded = pen, human = false, expireTime = autoAdmin.teamHit.decayFunction[#autoAdmin.teamHit.decayFunction].time - timeSince, weapon = hit.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							end
						end
                        if detailed then
                            if type(hit) == 'table' then 
                                if pen > 0 then
                                    dStats.active = dStats.active + 1
                                end
                                if hit.forgiven then
                                    dStats.forgiven = dStats.forgiven + 1
                                end
                                dStats.total = dStats.total + 1
                            end
                        end
					end
                    d.hitStats = dStats
				end
				--slmod.info('score after team hits: ' .. tostring(score))
				-- score team kills
               -- slmod.info(slmod.oneLineSerialize(d))
				if autoAdmin.teamKill.enabled and pStats.friendlyKills then  -- score team Kills
                    local lastAIKillTime  -- a time.
					local lastHumanKillTime
                    local dStats = {total = 0, active = 0, forgiven = 0}
					for killInd = 1, #pStats.friendlyKills do
                        local kill = pStats.friendlyKills[killInd]
                        local pen = 0
						if type(kill) == 'table' and kill.time and (not kill.forgiven) then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - kill.time)
                            local weight = getWeight(autoAdmin.teamKill.decayFunction, timeSince)
							if kill.human then -- a human was kill
							--	slmod.info('killed human')
								if not lastHumanKillTime or ((kill.time - lastHumanKillTime) > autoAdmin.teamKill.minPeriodHuman) then  -- count this kill
									lastHumanKillTime = kill.time
                                    pen = weight*autoAdmin.teamKill.penaltyPointsHuman
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if kill.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = kill.time, type = 'teamKill', pointsAdded = pen, human = true, expireTime = autoAdmin.teamKill.decayFunction[#autoAdmin.teamKill.decayFunction].time - timeSince, weapon = kill.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							else
                                if not lastAIKillTime or ((kill.time - lastAIKillTime) > autoAdmin.teamKill.minPeriodAI) then  -- count this kill
									lastAIKillTime = kill.time
                                    pen = weight*autoAdmin.teamKill.penaltyPointsAI
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                              if kill.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = kill.time, type = 'teamKill', pointsAdded = pen, human = false, expireTime = autoAdmin.teamKill.decayFunction[#autoAdmin.teamKill.decayFunction].time  - timeSince, weapon = kill.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							end
						end
                        if detailed then
                            if type(kill) == 'table' then 
                                if pen > 0 then
                                    dStats.active = dStats.active + 1
                                end
                                if kill.forgiven then
                                    dStats.forgiven = dStats.forgiven + 1
                                end
                                dStats.total = dStats.total + 1
                            end
                        end
					end
                    d.killStats = dStats
				end
				--slmod.info('score after team kills: ' .. tostring(score))
				-- score collision hits
				if autoAdmin.teamCollisionHit.enabled and pStats.friendlyCollisionHits then 
					--slmod.info('FF colision')
					local lastAIColHitTime
					local lastHumanColHitTime
                    local dStats = {total = 0, active = 0, forgiven = 0}
					for colHitInd = 1, #pStats.friendlyCollisionHits do
						local colHit = pStats.friendlyCollisionHits[colHitInd]
                        local pen = 0
						if type(colHit) == 'table' and colHit.time and (not colHit.forgiven) then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - colHit.time)
							local weight = getWeight(autoAdmin.teamCollisionHit.decayFunction, timeSince)
							if colHit.human then -- a human was colHit
								--slmod.info('colide human')
								if not lastHumanColHitTime or ((colHit.time - lastHumanColHitTime) > autoAdmin.teamCollisionHit.minPeriodHuman) then  -- count this colHit
									lastHumanColHitTime = colHit.time
                                    pen = weight*autoAdmin.teamCollisionHit.penaltyPointsHuman
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if colHit.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = colHit.time, type = 'teamCollisionHit', pointsAdded = pen, human = true, expireTime = autoAdmin.teamCollisionHit.decayFunction[#autoAdmin.teamCollisionHit.decayFunction].time - timeSince, weapon = colHit.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							else
								if not lastAIColHitTime or ((colHit.time - lastAIColHitTime) > autoAdmin.teamCollisionHit.minPeriodAI) then  -- count this hit
									lastAIColHitTime = colHit.time
                                    pen = weight*autoAdmin.teamCollisionHit.penaltyPointsAI
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if colHit.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = colHit.time, type = 'teamCollisionHit', pointsAdded = pen, human = false, expireTime = autoAdmin.teamCollisionHit.decayFunction[#autoAdmin.teamCollisionHit.decayFunction].time - timeSince, weapon = colHit.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							end
						end
                        if detailed then
                            if type(colHit) == 'table' then 
                                if pen > 0 then
                                    dStats.active = dStats.active + 1
                                end
                                if colHit.forgiven then
                                    dStats.forgiven = dStats.forgiven + 1
                                end
                                dStats.total = dStats.total + 1
                            end
                        end
					end
                    d.colHitStats = dStats
				end
				--slmod.info('score after team collision hits: ' .. tostring(score))
				-- score collision kills
				if autoAdmin.teamCollisionKill.enabled and pStats.friendlyCollisionKills then 
					local lastAIColKillTime
					local lastHumanColKillTime
                    local dStats = {total = 0, active = 0, forgiven = 0}
					for colKillInd = 1, #pStats.friendlyCollisionKills do
						local colKill = pStats.friendlyCollisionKills[colKillInd]
                        local pen = 0
						if type(colKill) == 'table' and colKill.time and (not colKill.forgiven) then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - colKill.time)
							local weight = getWeight(autoAdmin.teamCollisionKill.decayFunction, timeSince)
							if colKill.human then -- a human was colKill
								if not lastHumanColKillTime or ((colKill.time - lastHumanColKillTime) > autoAdmin.teamCollisionKill.minPeriodHuman) then  -- count this colKill
									lastHumanColKillTime = colKill.time
                                    pen = weight*autoAdmin.teamCollisionKill.penaltyPointsHuman
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if colKill.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = colKill.time, type = 'teamCollisionKill', pointsAdded = pen, human = true, expireTime = autoAdmin.teamCollisionKill.decayFunction[#autoAdmin.teamCollisionKill.decayFunction].time - timeSince, weapon = colKill.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							else
								if not lastAIColKillTime or ((colKill.time - lastAIColKillTime) > autoAdmin.teamCollisionKill.minPeriodAI) then  -- count this hit
									lastAIColKillTime = colKill.time
                                    pen = weight*autoAdmin.teamCollisionKill.penaltyPointsAI
                                    score = score + pen
									if detailed then 
                                        for i = 1, #d.penalties do
                                            if colKill.time < d.penalties[i].time then
                                               table.insert(d.penalties, i, {time = colKill.time, type = 'teamCollisionKill', pointsAdded = pen, human = false, expireTime = autoAdmin.teamCollisionKill.decayFunction[#autoAdmin.teamCollisionKill.decayFunction].time - timeSince, weapon = colKill.weapon})
                                               break
                                            end
                                        end
                                    end
								end
							end
						end
                        if detailed then
                            if type(colKill) == 'table' then 
                                if pen > 0 then
                                    dStats.active = dStats.active + 1
                                end
                                if colKill.forgiven then
                                    dStats.forgiven = dStats.forgiven + 1
                                end
                                dStats.total = dStats.total + 1
                            end
                        end
					end
                    d.colKillStats = dStats
				end
				--slmod.info('score after team collision kills: ' .. tostring(score))
				-- Check how many times player has been auto-banned.
				-- if pStats.numTimesAutoBanned and pStats.numTimesAutoBanned  > 0 then
					-- if autoAdmin.repeatOffenderExpotential then
						-- score = score*(autoAdmin.repeatOffenderModifier^pStats.numTimesAutoBanned)  -- expotential
					-- else
						-- score = score*(pStats.numTimesAutoBanned*autoAdmin.repeatOffenderModifier)  -- linear
					-- end
				-- end
				
				-- Now factor in flight hours
				local totHours = 0
				for name, time in pairs(pStats.times) do
					if time.inAir then
						totHours = totHours + time.inAir
					end
				end
				totHours = totHours/3600 -- actually convert to hours...
				--slmod.info('totHours')
				--slmod.info(totHours)
				--local finalScore = score*getWeight(autoAdmin.flightHoursWeightFunction, totHours)
				--slmod.info('score after flight hours adjustment: ' .. tostring(finalScore))
                if detailed then
                    d.misc.flightTimeWeight = getWeight(autoAdmin.flightHoursWeightFunction, totHours)
                    d.misc.autoBanned = pStats.autoBanned or false
                    d.misc.numTimesAutoBanned = pStats.numTimesAutoBanned or 0
                    --slmod.info(slmod.oneLineSerialize(d))
                end
                
				return score*getWeight(autoAdmin.flightHoursWeightFunction, totHours), d  -- factor in flight hours, and return.
				--return finalScore
			end
		end
		
		-- pcall - prevents bad config files from making Slmod fail.
		local err, score, detail = pcall(scorePilot, ucid, det)
		if detail then
            

        end
		if err then
			return score, detail
		else
			slmod.error('autoAdmin: error calculating pilot score: ' .. tostring(score))
		end
	end
	
	-- when player banned- 
	--	-increment numTimesAutoBanned
	--	-set autoBanned = true 
	
	function slmod.autoAdminOnConnect(ucid) -- this called from the server.on_connect callback.
		if ucid and autoAdmin.autoBanEnabled and (not slmod.isAdmin(ucid)) and (not autoAdmin.exemptionList[ucid]) then  -- there BETTER BE a ucid. Oh and Admins are exempt from this check.
			local pStats = slmod.stats.getUserStats(ucid)
            if pStats then  --previous player..
				local score = autoAdminScore(ucid)
				if score then
					if pStats.autoBanned then -- player was already autoBanned
						if autoAdmin.reallowLevel and score < autoAdmin.reallowLevel then
							-- allow player.  "Unban" them too.
							slmod.stats.changeStatsValue(stats[ucid], 'autoBanned', false)
							return true  -- allow connection
						end
					end
					if score > autoAdmin.autoBanLevel then
						if not pStats.autoBanned then  -- set autoBanned true if wasn't already.
							slmod.stats.changeStatsValue(stats[ucid], 'autoBanned', true)
							
							-- also, if it wasn't true already, then he probably wasn't autoBanned before, and he should be, so set the numTimesAutoBanned field to 1
							if not pStats.numTimesAutoBanned then  -- make sure first...
								slmod.stats.changeStatsValue(stats[ucid], 'numTimesAutoBanned', 1)
							end
						end
						--slmod.info('AutoAdmin: refusing connection for player with ucid "' .. ucid .. '", player is autobanned.')
						return false, score --- the player should remain banned
					end
				end
			end
		end
		return true  -- allow connection
	end
	
	-- called on every potentially kickable/bannable offense. 
	function slmod.autoAdminOnOffense(clients, deadClients)  -- client is a slmod.client.
		--slmod.info('running slmod.autoAdminOnOffense; client = ' .. slmod.oneLineSerialize(clients))
		--{ ["id"] = 2, ["rtid"] = 16778498, ["ip"] = "50.134.222.29", ["coalition"] = "blue", ["addr"] = "50.134.222.29", ["name"] = "3Sqn_Grimes", ["ucid"] = "78c01638f5552aab2d2a9cd428f3e58f", ["motdTime"] = 295.38130488651, ["unitName"] = "Pilot #21", }
		for ind, client in pairs(clients) do
            local actionTaken = false
            if client.ucid and slmod.clients[client.id] and (slmod.clients[client.id].ucid == client.ucid) and (not slmod.isAdmin(client.ucid)) and (not autoAdmin.exemptionList[client.ucid]) and (not (client.id == 1)) then  -- client is in proper format and is online, and is not exempt
                --slmod.info('in on offense')
                -- autoban?
                if autoAdmin.autoBanEnabled and actionTaken == false then
                    --slmod.info('doing autoban eval')
                    local score = autoAdminScore(client.ucid)
                    --slmod.info('score: ' .. tostring(score))
                    if score and score > autoAdmin.autoBanLevel then  -- player gets autoBanned.
                        slmod.stats.changeStatsValue(stats[client.ucid], 'autoBanned', true) -- set as banned.
                        
                        local numTimesBanned
                        if stats[client.ucid].numTimesAutoBanned then
                            numTimesBanned = stats[client.ucid].numTimesAutoBanned + 1
                        else
                            numTimesBanned = 1
                        end
                        slmod.stats.changeStatsValue(stats[client.ucid], 'numTimesAutoBanned', numTimesBanned)  --increment the number of times the player has been banned
                        
                        -- kicking...
                        if client.rtid then  -- attempt to despawn client.
                            net.dostring_in('server', 'Object.destroy({id_ = ' .. tostring(client.rtid) .. '})')
                        end
                        
                        delayedKick(client.id, client.ucid, 'You were autobanned from the server.', autoAdmin.kickBanDelay.banDelay)
                        
                        --net.kick(client.id, 'You were autobanned from the server.')
                        slmod.info('Player "' .. tostring(client.name) .. '" is getting autobanned.', true)  -- this will output in chat too.
                        
                        -- Permaban?
                        if autoAdmin.tempBanLimit and type(autoAdmin.tempBanLimit) == 'number' and numTimesBanned >= autoAdmin.tempBanLimit then  -- permaban too.
                            slmod.update_banned_clients({ucid = client.ucid, name = client.name, ip = client.addr or client.ip}, 'autoban')
                        end
                        actionTaken = true
                    end
                end
                -- or autokick?
                if autoAdmin.autoKickEnabled and actionTaken == false then  -- if still here, check for autoKick.
                    local score = autoAdminScore(client.ucid)
                    if score and score > autoAdmin.autoKickLevel then
                        
                        -- kicking...
                        if client.rtid then  -- attempt to despawn client.
                            net.dostring_in('server', 'Object.destroy({id_ = ' .. tostring(client.rtid) .. '})')
                        end
                        
                        delayedKick(client.id, client.ucid, 'You were autokicked from the server.', autoAdmin.kickBanDelay.kickDelay)
                        --net.kick(client.id, 'You were autokicked from the server.')
                        slmod.info('Player "' .. tostring(client.name) .. '" is getting autokicked.', true)  -- this will output in chat too.
                        actionTaken = true
                    end
                end
               
                if autoAdmin.autoSpecEnabled and actionTaken == false then
                    local score = autoAdminScore(client.ucid)
                    if score and score > autoAdmin.autoSpecLevel then
                        
                        -- kicking...
                        if client.rtid then  -- attempt to despawn client.
                            net.dostring_in('server', 'Object.destroy({id_ = ' .. tostring(client.rtid) .. '})')
                        end
                        
                        delayedKickToSpec(client.id, client.ucid, 'You were autokicked back to spectator.', autoAdmin.kickBanDelay.specDelay)
                        --net.kick(client.id, 'You were autokicked from the server.')
                        slmod.info('Player "' .. tostring(client.name) .. '" is getting autokicked back to spectator', true)  -- this will output in chat too.
                        actionTaken = true
                    end
                end
			end
		end
	end
	--[[ -forgive -punish commands
    Check if forgiveness or punishment is enabled. 
    
    Add offense to scheduled function run only when punishments can be fixed
    If player forgives or punishes in that timeframe...
        on forgive modify stats entry with forgive flag. (must be also all related Hits to that unit within timeout of period?)
        
        on punish remove entry for checked function, go to slmod.autoAdminOnOffense
        
        
        
    
    ]]
    
    function slmod.getUserScore(id, detailed) -- call of local function
       -- slmod.info('getUserScore')
        local score, dets = autoAdminScore(id, detailed)
        return score, dets
    end
    
    function slmod.playerPenaltyScoreDisplay(d, s, mData)
        local msg = {}
        if d and d.penalties then
            if d.penalties[#d.penalties].type == 'ERASEME' then
                d.penalties[#d.penalties] = nil
            end
        end
        msg[#msg+1] = 'User: '
        msg[#msg+1] = mData.name
        if mData.id then 
            msg[#msg+1] =  '   |   Stats ID: '
            msg[#msg+1] = mData.id
        end
        msg[#msg+1] = '\n=======================\n'
        msg[#msg+1] = 'Current Penalty Score: ' .. s
        msg[#msg+1] = '\n=======================\n'
        msg[#msg+1] = 'Up to last 20 penalties\n'
        if d.penalties and #d.penalties > 0 then 
            for i = #d.penalties, 1, -1  do
                msg[#msg+1] = '\n'
                msg[#msg+1] = 'Type: '
                msg[#msg+1] = d.penalties[i].type
                msg[#msg+1] = '  with: '
                msg[#msg+1] = d.penalties[i].weapon
                msg[#msg+1] = '  on '
                if d.penalties[i].human then
                    msg[#msg+1] = ' player '
                else
                    msg[#msg+1] = ' AI '
                end
                msg[#msg+1] = ' Penalty of: '
                msg[#msg+1] = string.format("%.2f", tostring(d.penalties[i].pointsAdded))
                if d.penalties[i].pointsAdded == 0 then 
                     msg[#msg+1] = ' Expired '
                else
                    msg[#msg+1] = ' Expires in: '
                    msg[#msg+1] = string.format("%.2f", tostring(d.penalties[i].expireTime))
                    msg[#msg+1] = ' days.'
                end
                if #d.penalties - 20 == i then
                    break
                end
            end
        else
            msg[#msg+1] = 'No Recent Penalties on Record'
        end

        
        return table.concat(msg)
    end
   
    local function checkForgivePunishStatus()
        if #delayedPenalty > 0  then 
            penaltyCheckActive = true
            slmod.scheduleFunctionByRt(checkForgivePunishStatus, {}, DCS.getRealTime() + 1) -- set to reschedule due to there still being entries
            for i = 1, #delayedPenalty do
                local offData = delayedPenalty[i]
                if offData then
                    local vByUCID = {}
                    for j = 1, #offData.victim do
                        vByUCID[offData.victim[j].ucid] = offData.victim[j].name
                        if autoAdmin.consentEnabled then -- auto consent for teamkill check. 
                            if offData.victim[j].ucid and affirmativeTKConsent[offData.victim[j].ucid] then -- forgiveness granted!
                                offData.choice = 'forgive'
                            end
                        end
                        if not offData.choice then -- choice hasn't been made yet
                            if offData.canForgive and offData.time < os.time() - offData.canForgive then -- if forgiveness timeout has passed
                                offData.canForgive = nil
                            end
                            if offData.canPunish and offData.time < os.time() - offData.canPunish then -- if punishment timeout has passed
                                slmod.autoAdminOnOffense(offData.offender) -- punish him
                                offData.canPunish = nil
                            end
                            if not (offData.canForgive and offData.canPunish) then -- if canPunsh and canForgive no longer exist, remove it. 
                                delayedPenalty[i] = nil
                            end
                        else -- an action has been chosen!
                            if offData.choice == 'punish' then
                                slmod.autoAdminOnOffense(offData.offender) -- punish him
                                delayedPenalty[i] = nil 
                            else -- choice was to forgive him
                                for k = 1, #offData.offender do 
                                    local oUCID = offData.offender[k].ucid
                                    local pStats = slmod.stats.getUserStats(oUCID)
                                    if pStats and autoAdmin and (autoAdmin.autoBanEnabled or autoAdmin.autoKickEnabled or autoAdmin.autoSpecEnabled) and offData.canForgive then
                                        local curTime = os.time()
                                        -- score team hits
                                        
                                        if autoAdmin.teamHit.enabled and pStats.friendlyHits then  -- score team hits.
                                            for hitInd = 1, #pStats.friendlyHits do
                                                local action = pStats.friendlyHits[hitInd]
                                                for v = 1, #action.human do
                                                    if action.human[v] and vByUCID[action.human[v]] and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                                        slmod.stats.changeStatsValue(stats[oUCID].friendlyHits[hitInd], 'forgiven', true)
                                                    end
                                                end
                                            end
                                        end
                                        if autoAdmin.teamKill.enabled and pStats.friendlyKills then  -- score team hits.
                                            for kilInd = 1, #pStats.friendlyKills do
                                                local action = pStats.friendlyKills[kilInd]
                                                for v = 1, #action.human do
                                                    if action.human[v] and vByUCID[action.human[v]] and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                                        slmod.stats.changeStatsValue(stats[oUCID].friendlyKills[kilInd], 'forgiven', true)
                                                    end
                                                end
                                            end
                                        end
                                        if autoAdmin.teamCollisionHit.enabled and pStats.friendlyCollisionHits then  -- score team hits.
                                            for hitInd = 1, #pStats.friendlyCollisionHits do
                                                local action = pStats.friendlyCollisionHits[hitInd]
                                                for v = 1, #action.human do
                                                    if action.human[v] and vByUCID[action.human[v]] and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                                    slmod.stats.changeStatsValue(stats[oUCID].friendlyCollisionHits[hitInd], 'forgiven', true)
                                                    end
                                                end
                                            end
                                        end
                                        if autoAdmin.teamCollisionKill.enabled and pStats.friendlyCollisionKills then  -- score team hits.
                                            for hitInd = 1, #pStats.friendlyCollisionKills do
                                                local action = pStats.friendlyCollisionKills[hitInd]
                                                for v = 1, #action.human do
                                                    if action.human[v] and vByUCID[action.human[v]] and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                                    slmod.stats.changeStatsValue(stats[oUCID].friendlyCollisionKills[hitInd], 'forgiven', true)
                                                    end
                                                end
                                            end
                                        end                            
                                        delayedPenalty[i] = nil
                                    else 
                                        delayedPenalty[i].choice = 'punish'
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            penaltyCheckActive = false
        end
    end
    
    local function anyDeadUCID(deadClient) -- just gonna assume that the dead client thing isnt returned indexed by number and can have empty spots
        for ind, data in pairs(deadClient) do
            if data.ucid then return true end
        end
        
        return false
    end
    
    function slmod.autoAdminCheckForgiveOnOffense(clients, dClient)
        local deadClient = {} -- raw UCID of client that is killed
        if type(dClient) == 'string' then -- shouldn't happen
            deadClient[1] = dClient
        else 
            deadClient = dClient
        end
        if deadClient and anyDeadUCID(deadClient) == false then -- it is a bot you killed, Bots never forgive and never forget
            slmod.autoAdminOnOffense(clients)
        else
            local offData = {offender = {}, victim = deadClient, time = os.time()}
            if autoAdmin.forgiveEnabled then -- set timeout limits
                offData.canForgive = autoAdmin.forgiveTimeout or 30
            end
            if autoAdmin.forgiveEnabled or autoAdmin.punishEnabled then -- check if the player is exempt
                for cInd, client in pairs(clients) do 
                    if client.ucid and slmod.clients[client.id] and (slmod.clients[client.id].ucid == client.ucid) and (not slmod.isAdmin(client.ucid)) and (not autoAdmin.exemptionList[client.ucid]) and (not (client.id == 1)) then
                        table.insert(offData.offender, client)
                    end

                end
            else -- both punishment and forgiveness disabled
                slmod.autoAdminOnOffense(clients)
            end
            if #offData.offender > 0 then -- because it can be an admin
                if autoAdmin.punishFirstForgiveLater then
                    slmod.scheduleFunctionByRt(slmod.autoAdminOnOffense, {offData.offender}, DCS.getRealTime() + 1)
                else
                    if autoAdmin.punishEnabled then 
                        offData.canPunish = autoAdmin.punishTimeout or 30
                    end
                end
                
                delayedPenalty[#delayedPenalty+1] = offData
                if autoAdmin.msgPromptOnKilled then
                    local dClientIDs = {}
                    local killerClientNames = {}
                    for i = 1, #dClient do
                        table.insert(dClientIDs, dClient[i].id)
                    end
                    for cIndex, cData in pairs(clients) do
                        if #killerClientNames > 0 then
                            table.insert(killerClientNames, ' and ')
                        end
                        table.insert(killerClientNames, cData.name)
                    end
                    local msg = {}
                    if #killerClientNames > 0 then 
                        msg[#msg + 1] = 'You have been teamkilled by '
                        msg[#msg + 1] = table.concat(killerClientNames)
                    end
                    if autoAdmin.forgiveEnabled then
                        msg[#msg + 1] = '\nType "-forgive" into chat to forgive the player for any recent team damage and teamkill on you. '
                        msg[#msg + 1] = ' You have '
                        msg[#msg + 1] = autoAdmin.forgiveTimeout or 30
                        msg[#msg + 1] = ' seconds to forgive them. \n'
                    end
                    if autoAdmin.punishEnabled then
                        msg[#msg + 1] = '\nType "-punish" into chat to punish the player for any recent team damage and teamkill on you. '
                        msg[#msg + 1] = ' You have '
                        msg[#msg + 1] = autoAdmin.punishTimeout or 30
                        msg[#msg + 1] = ' seconds to punish them. \n'
                    end
                    slmod.scheduleFunctionByRt(slmod.scopeMsg, {table.concat(msg), 20, 'both', {clients = {dClientIDs}}}, DCS.getRealTime() + 0.5)
                    
                end
                if penaltyCheckActive == false then 
                     checkForgivePunishStatus()
                end
            end
        end
    end
   
    function slmod.createPunishForgiveMenu() 
        local forgivePunishItems = {}
        local forgiveShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-forgive',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = true,
				},
			},
            [2] = {
				[1] = {
					type = 'word',
					text = '-punish',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = true,
				},
			},
		}
    -- create the menu.
        local display_mode = slmod.config.admin_display_mode or 'text'
        local display_time = slmod.config.admin_display_time or 30
        SlmodForgivePunishMenu = SlmodMenu.create{ 
            showCmds = forgiveShowCommands,
            scope = {coa = 'all'}, 
            options = {
                display_time = 30, 
                display_mode = 'text', 
                title = 'Slmod Server Forgive/Punish Utility', 
                privacy = {access = true, show = true}
            }, 
            items = forgivePunishItems,
            }   
        if autoAdmin.forgiveEnabled then -- forgiving is enabled, then create this menu
            local forgiveVars = {}
            forgiveVars.menu = SlmodForgivePunishMenu
            forgiveVars.description = 'Say in chat "-forgive" to forgive the player of any team damage/kill/hit/collisions they have done to you. If no action is taken punishment will be automatic.'
            forgiveVars.active = true
            forgiveVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
            forgiveVars.selCmds = {
                    [1] = {
                        [1] = { 
                            type = 'word', 
                            text = '-forgive',
                            required = true
                        }, 
                    },
                } 
            forgiveVars.onSelect = function(self, vars, client_id)
                if slmod.clients[vars] then
                    local requester = slmod.clients[vars]
                    if #delayedPenalty > 0 and autoAdmin.forgiveEnabled then -- just to be safe
                        for i = 1, #delayedPenalty do
                            if delayedPenalty[i].canForgive then -- seriously being paranoid
                                local offData = delayedPenalty[i]
                                for j = 1, #offData.victim do
                                    if offData.victim[j].ucid == requester.ucid and os.time() < offData.time + offData.canForgive and (not offData.choice) then
                                        delayedPenalty[i].choice = 'forgive'
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            forgivePunishItems[#forgivePunishItems + 1] = SlmodMenuItem.create(forgiveVars)  -- add the item into the items table.
        end
       if autoAdmin.punishEnabled then -- punishment is enabled, then create this menu
            local punishVars = {}
            punishVars.menu = SlmodForgivePunishMenu
            punishVars.description = 'Say in chat "-punish" to punish the player of any team damage/kill/hit/collisions they have done to you. If no action is taken punishment will be automatic.'
            punishVars.active = true
            punishVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
            punishVars.selCmds = {
                    [1] = {
                        [1] = { 
                            type = 'word', 
                            text = '-punish',
                            required = true
                        }, 
                    },

                } 
            punishVars.onSelect = function(self, vars, client_id)
                if slmod.clients[vars] then
                    local requester = slmod.clients[vars]
                    if #delayedPenalty > 0 and autoAdmin.punishEnabled then -- just to be safe
                        for i = 1, #delayedPenalty do
                            if delayedPenalty[i].canPunish then -- seriously being paranoid
                                local offData = delayedPenalty[i]
                                for j = 1, #offData.victim do
                                    if offData.victim[j].ucid == requester.ucid and os.time() < offData.time + offData.canPunish and (not offData.choice) then -- victim is the person who typed the message
                                        delayedPenalty[i].choice = 'punish'
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            forgivePunishItems[#forgivePunishItems + 1] = SlmodMenuItem.create(punishVars)  -- add the item into the items table.
        end
	--------------------------------------------------------------------------------------------------------------
        if autoAdmin.consentEnabled then
            local cVars = {}
            cVars.menu = SlmodForgivePunishMenu
            cVars.description = 'Say in chat "-consent" to toggle automatically forgiving anyone who has teamkilled you. It defaults to off.'
            cVars.active = true
            cVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
            cVars.selCmds = {
                    [1] = {
                        [1] = { 
                            type = 'word', 
                            text = '-consent',
                            required = true
                        }, 
                    },

                } 
            cVars.onSelect = function(self, vars, client_id)
                if slmod.clients[vars] then
                    local requester = slmod.clients[vars]
                    if affirmativeTKConsent[requester.ucid] then
                        affirmativeTKConsent[requester.ucid] = nil
                        slmod.scheduleFunctionByRt(slmod.scopeMsg, {'You have REMOVED consent for anyone who teamkills you to automatically be granted forgiveness.' , 1, 'chat', {clients = {vars}}}, DCS.getRealTime() + 0.1)
                    else
                        affirmativeTKConsent[requester.ucid] = true
                        slmod.scheduleFunctionByRt(slmod.scopeMsg, {'You have GIVEN consent for anyone who teamkills you to automatically be granted forgiveness.' , 1, 'chat', {clients = {vars}}}, DCS.getRealTime() + 0.1)
                    end
                end
            end
            
            forgivePunishItems[#forgivePunishItems + 1] = SlmodMenuItem.create(cVars)  -- add the item into the items table.
            
        end
    end

end
slmod.info('SlmodAutoAdmin.lua loaded.')