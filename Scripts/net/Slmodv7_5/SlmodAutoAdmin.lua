do
	--[[ todo:
	"forgive player" menu
	]]

	local stats = slmod.stats.getStats()
	local autoAdmin = slmod.config.autoAdmin
    local delayedPenalty = {}
    local checkForgive = false

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
		slmod.scheduleFunctionByRt(checkedKick, {id, ucid, kickMsg}, DCS.getRealTime() + delay)
	end
    
    local function delayedKickToSpec(id, ucid, kickMsg, delay)
        delay = delay or 10
		kickMsg = kickMsg or 'You were kicked back to spectator.'
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
	local function autoAdminScore(ucid)
		local function scorePilot(ucid) -- this will contain all the logic.  autoAdminScore calls this function with pcall.
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
			if pStats and autoAdmin and (autoAdmin.autoBanEnabled or autoAdmin.autoKickEnabled or autoAdmin.autoSpecEnabled) then
				local score = 0  -- penalty score
				local curTime = os.time()
				
				-- score team hits
				if autoAdmin.teamHit.enabled and pStats.friendlyHits then  -- score team hits.
					local lastAIHitTime  -- a time.
					local lastHumanHitTime
					for hitInd = 1, #pStats.friendlyHits do
						local hit = pStats.friendlyHits[hitInd]
						if type(hit) == 'table' and hit.time and not hit.forgiven then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - hit.time)
							local weight = getWeight(autoAdmin.teamHit.decayFunction, timeSince)
							if hit.human then -- a human was hit
								if not lastHumanHitTime or ((hit.time - lastHumanHitTime) > autoAdmin.teamHit.minPeriodHuman) then  -- count this hit
									lastHumanHitTime = hit.time
									
									score = score + weight*autoAdmin.teamHit.penaltyPointsHuman
									
								end
							else
								if not lastAIHitTime or ((hit.time - lastAIHitTime) > autoAdmin.teamHit.minPeriodAI) then  -- count this hit
									lastAIHitTime = hit.time
									
									score = score + weight*autoAdmin.teamHit.penaltyPointsAI
								end
							end
						end
					end
				end
				--slmod.info('score after team hits: ' .. tostring(score))
				-- score team kills
				if autoAdmin.teamKill.enabled and pStats.friendlyKills then  -- score team Kills
					--slmod.info('has teamkills')
					local lastAIKillTime  -- a time.
					local lastHumanKillTime
					for killInd = 1, #pStats.friendlyKills do
						local kill = pStats.friendlyKills[killInd]
						if type(kill) == 'table' and kill.time not kill.forgiven then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - kill.time)
							local weight = getWeight(autoAdmin.teamKill.decayFunction, timeSince)
							if kill.human then -- a human was kill
							--	slmod.info('killed human')
								if not lastHumanKillTime or ((kill.time - lastHumanKillTime) > autoAdmin.teamKill.minPeriodHuman) then  -- count this kill
									lastHumanKillTime = kill.time
									score = score + weight*autoAdmin.teamKill.penaltyPointsHuman
								end
							else
								--slmod.info('killed norm')
								if not lastAIKillTime or ((kill.time - lastAIKillTime) > autoAdmin.teamKill.minPeriodAI) then  -- count this kill
									lastAIKillTime = kill.time
									score = score + weight*autoAdmin.teamKill.penaltyPointsAI
								end
							end
						end
					end
				end
				--slmod.info('score after team kills: ' .. tostring(score))
				-- score collision hits
				if autoAdmin.teamCollisionHit.enabled and pStats.friendlyCollisionHits then 
					--slmod.info('FF colision')
					local lastAIColHitTime
					local lastHumanColHitTime
					for colHitInd = 1, #pStats.friendlyCollisionHits do
						local colHit = pStats.friendlyCollisionHits[colHitInd]
						if type(colHit) == 'table' and colHit.time not colHit.forgiven then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - colHit.time)
							local weight = getWeight(autoAdmin.teamCollisionHit.decayFunction, timeSince)
							if colHit.human then -- a human was colHit
								--slmod.info('colide human')
								if not lastHumanColHitTime or ((colHit.time - lastHumanColHitTime) > autoAdmin.teamCollisionHit.minPeriodHuman) then  -- count this colHit
									lastHumanColHitTime = colHit.time
									score = score + weight*autoAdmin.teamCollisionHit.penaltyPointsHuman
								end
							else  -- an AI was collided with
								--slmod.info('colide robot')
								if not lastAIColHitTime or ((colHit.time - lastAIColHitTime) > autoAdmin.teamCollisionHit.minPeriodAI) then  -- count this colHit
									lastAIColHitTime = colHit.time
									score = score + weight*autoAdmin.teamCollisionHit.penaltyPointsAI
								end
							end
						end
					end
				end
				--slmod.info('score after team collision hits: ' .. tostring(score))
				-- score collision kills
				if autoAdmin.teamCollisionKill.enabled and pStats.friendlyCollisionKills then 
					local lastAIColKillTime
					local lastHumanColKillTime
					for colKillInd = 1, #pStats.friendlyCollisionKills do
						local colKill = pStats.friendlyCollisionKills[colKillInd]
						if type(colKill) == 'table' and colKill.time not colKill.forgiven then -- I may be being obsessive-compulsive here...
							local timeSince = toDays(curTime - colKill.time)
							local weight = getWeight(autoAdmin.teamCollisionKill.decayFunction, timeSince)
							if colKill.human then -- a human was colKill
								if not lastHumanColKillTime or ((colKill.time - lastHumanColKillTime) > autoAdmin.teamCollisionKill.minPeriodHuman) then  -- count this colKill
									lastHumanColKillTime = colKill.time
									score = score + weight*autoAdmin.teamCollisionKill.penaltyPointsHuman
								end
							else  -- an AI was collided with
								if not lastAIColKillTime or ((colKill.time - lastAIColKillTime) > autoAdmin.teamCollisionKill.minPeriodAI) then  -- count this colKill
									lastAIColKillTime = colKill.time
									score = score + weight*autoAdmin.teamCollisionKill.penaltyPointsAI
								end
							end
						end
					end
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
				return score*getWeight(autoAdmin.flightHoursWeightFunction, totHours)  -- factor in flight hours, and return.
				--return finalScore
			end
		end
		
		-- pcall - prevents bad config files from making Slmod fail.
		local err, score = pcall(scorePilot, ucid)
		
		if err then
			return score
		else
			slmod.error('autoAdmin: error calculating pilot score: ' .. tostring(score))
		end
	end
	
	-- when player banned- 
	--	-increment numTimesAutoBanned
	--	-set autoBanned = true 
	
	function slmod.autoAdminOnConnect(ucid) -- this called from the server.on_connect callback.
		if ucid and autoAdmin.autoBanEnabled and (not slmod.isAdmin(ucid)) and (not autoAdmin.exemptionList[ucid]) then  -- there BETTER BE a ucid. Oh and Admins are exempt from this check.
			if stats[ucid] then  --previous player..
				local score = autoAdminScore(ucid)
				if score then
					if stats[ucid].autoBanned then -- player was already autoBanned
						if autoAdmin.reallowLevel and score < autoAdmin.reallowLevel then
							-- allow player.  "Unban" them too.
							slmod.stats.changeStatsValue(stats[ucid], 'autoBanned', false)
							return true  -- allow connection
						end
					end
					if score > autoAdmin.autoBanLevel then
						if not stats[ucid].autoBanned then  -- set autoBanned true if wasn't already.
							slmod.stats.changeStatsValue(stats[ucid], 'autoBanned', true)
							
							-- also, if it wasn't true already, then he probably wasn't autoBanned before, and he should be, so set the numTimesAutoBanned field to 1
							if not stats[ucid].numTimesAutoBanned then  -- make sure first...
								slmod.stats.changeStatsValue(stats[ucid], 'numTimesAutoBanned', 1)
							end
						end
						--slmod.info('AutoAdmin: refusing connection for player with ucid "' .. ucid .. '", player is autobanned.')
						return false --- the player should remain banned
					end
				end
			end
		end
		return true  -- allow connection
	end
	
	-- called on every potentially kickable/bannable offense. 
	function slmod.autoAdminOnOffense(client, deadClient)  -- client is a slmod.client.
		--slmod.info('running slmod.autoAdminOnOffense; client = ' .. slmod.oneLineSerialize(client))
		--{ ["id"] = 2, ["rtid"] = 16778498, ["ip"] = "50.134.222.29", ["coalition"] = "blue", ["addr"] = "50.134.222.29", ["name"] = "3Sqn_Grimes", ["ucid"] = "78c01638f5552aab2d2a9cd428f3e58f", ["motdTime"] = 295.38130488651, ["unitName"] = "Pilot #21", }
		if client.ucid and slmod.clients[client.id] and (slmod.clients[client.id].ucid == client.ucid) and (not slmod.isAdmin(client.ucid)) and (not autoAdmin.exemptionList[client.ucid]) and (not (client.id == 1)) then  -- client is in proper format and is online, and is not exempt
			--slmod.info('in on offense')
			-- autoban?
			if autoAdmin.autoBanEnabled then
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
					return
				end
			end
			-- or autokick?
			if autoAdmin.autoKickEnabled then  -- if still here, check for autoKick.
				local score = autoAdminScore(client.ucid)
				if score and score > autoAdmin.autoKickLevel then
					
					-- kicking...
					if client.rtid then  -- attempt to despawn client.
						net.dostring_in('server', 'Object.destroy({id_ = ' .. tostring(client.rtid) .. '})')
					end
					
					delayedKick(client.id, client.ucid, 'You were autokicked from the server.', autoAdmin.kickBanDelay.kickDelay)
					--net.kick(client.id, 'You were autokicked from the server.')
					slmod.info('Player "' .. tostring(client.name) .. '" is getting autokicked.', true)  -- this will output in chat too.
					return
				end
			end
           
            if autoAdmin.autoSpecEnabled then
            	local score = autoAdminScore(client.ucid)
				if score and score > autoAdmin.autoSpecLevel then
					
					-- kicking...
					if client.rtid then  -- attempt to despawn client.
						net.dostring_in('server', 'Object.destroy({id_ = ' .. tostring(client.rtid) .. '})')
					end
					
					delayedKickToSpec(client.id, client.ucid, 'You were autokicked back to spectator', autoAdmin.kickBanDelay.specDelay)
					--net.kick(client.id, 'You were autokicked from the server.')
					slmod.info('Player "' .. tostring(client.name) .. '" is getting autokicked back to spectator', true)  -- this will output in chat too.
					return
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
    local function checkForgivePunishStatus()
        if #delayedPenalty > 0  then 
            slmod.scheduleFunctionByRt(checkForgivePunishStatus, {}, DCS.getRealTime() + 1) -- set to reschedule due to there still being entries
            for i = 1, #delayedPenalty do
                local offData = delayedPenalty[i]
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
                        local pStats = stats[offData.offender]
                        if pStats and autoAdmin and (autoAdmin.autoBanEnabled or autoAdmin.autoKickEnabled or autoAdmin.autoSpecEnabled) then
                            local score = 0  -- penalty score
                            local curTime = os.time()
                            -- score team hits
                            if autoAdmin.teamHit.enabled and pStats.friendlyHits then  -- score team hits.
                                for hitInd = 1, #pStats.friendlyHits do
                                    local action = pStats.friendlyHits[hitInd]
                                    if action.human and action.human == offData.victim and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                        slmod.stats.changeStatsValue(stats[offData.offender].friendlyHits[hitInd], 'forgiven', true)
                                    end
                                end
                            end
                            if autoAdmin.teamKill.enabled and pStats.friendlyKills then  -- score team hits.
                                for hitInd = 1, #pStats.friendlyKills do
                                    local action = pStats.friendlyKills[hitInd]
                                    if action.human and action.human == offData.victim and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                        slmod.stats.changeStatsValue(stats[offData.offender].friendlyKills[hitInd], 'forgiven', true)
                                    end
                                end
                            end
                            if autoAdmin.teamCollisionHit.enabled and pStats.friendlyCollisionHits then  -- score team hits.
                                for hitInd = 1, #pStats.friendlyCollisionHits do
                                    local action = pStats.friendlyCollisionHits[hitInd]
                                    if action.human and action.human == offData.victim and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                        slmod.stats.changeStatsValue(stats[offData.offender].friendlyCollisionHits[hitInd], 'forgiven', true)
                                    end
                                end
                            end
                            if autoAdmin.teamCollisionKill.enabled and pStats.friendlyCollisionKills then  -- score team hits.
                                for hitInd = 1, #pStats.friendlyCollisionKills do
                                    local action = pStats.friendlyCollisionKills[hitInd]
                                    if action.human and action.human == offData.victim and curTime - offData.canForgive < action.time and (not action.forgiven) then
                                        slmod.stats.changeStatsValue(stats[offData.offender].friendlyCollisionKills[hitInd], 'forgiven', true)
                                    end
                                end
                            end                            
                        end
                    end
                end
            end
        end
    end
    
   
    function slmod.autoAdminCheckForgiveOnOffense(client, deadClient)
        if not deadClient then -- it is a bot you killed, Bots never forgive and never forget
            slmod.autoAdminOnOffense(client)
        else
            if autoAdmin.forgiveEnabled or autoAdmin.punishEnabled then -- check if the player is exempt
                if client.ucid and slmod.clients[client.id] and (slmod.clients[client.id].ucid == client.ucid) and (not slmod.isAdmin(client.ucid)) and (not autoAdmin.exemptionList[client.ucid]) and (not (client.id == 1)) then
                    local offData = {offender = client, victim = deadClient, time = os.time()}
                    if autoAdmin.forgiveEnabled then -- set timeout limits
                        offData.canForgive = autoAdmin.forgiveTimeout or 30
                    end
                    if autoAdmin.punishEnabled then
                        offData.canPunish = autoAdmin.punishTimeout or 30
                    end
                    delayedPenalty[#delayedPenalty+1] = offData
                    checkForgive = true
                    slmod.scheduleFunctionByRt(checkForgivePunishStatus, {}, DCS.getRealTime() + 1)
                end
            else -- both punishment and forgiveness disabled
                slmod.autoAdminOnOffense(client)
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
					required = false,
				}
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
					required = false,
				}
			},
		}
    -- create the menu.
        local display_mode = slmod.config.admin_display_mode or 'text'
        local display_time = slmod.config.admin_display_time or 30
        
        SlmodForgivePunishMenu = SlmodMenu.create{ 
            showCmds = forgiveShowCommands,
                scope = {coa = 'all'}, 
                options = {
                    display_time = display_time, 
                    display_mode = display_mode, 
                    title = 'Slmod Server Forgive/Punish Utility', 
                    privacy = {access = true, show = true}
                }, 
                items = forgivePunishItems
            },   
        
        if autoAdmin.forgiveEnabled then -- forgiving is enabled, then create this menu
            local forgiveVars = {}
            forgiveVars.menu = SlmodForgivePunishMenu
            forgiveVars.description = 'Say in chat "-forgive to forgive the player of any team damage/kill/hit/collisions they have done to you. If not action is taken punishment will be automatic.'
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
                local requester = slmod.clients[clientId]
                if #delayedPenalty > 0 and autoAdmin.forgiveEnabled then -- just to be safe
                    for i = 1, #delayedPenalty do
                        if delayedPenalty[i].canForgive then -- seriously being paranoid
                            local offData = delayedPenalty[i]
                            if offData.victim == requester.ucid and os.time() < offData.time + offData.canForgive and (not offData.choice) then -- victim is the person who typed the message
                                offData.choice = 'forgive'
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
            punishVars.description = 'Say in chat "-punish to punish the player of any team damage/kill/hit/collisions they have done to you. If not action is taken punishment will be automatic.'
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
                local requester = slmod.clients[clientId]
                if #delayedPenalty > 0 and autoAdmin.punishEnabled then -- just to be safe
                    for i = 1, #delayedPenalty do
                        if delayedPenalty[i].canPunish then -- seriously being paranoid
                            local offData = delayedPenalty[i]
                            if offData.victim == requester.ucid and os.time() < offData.time + offData.canPunish and (not offData.choice) then -- victim is the person who typed the message
                                offData.choice = 'punish'
                            end
                        end
                    end
                end

            end
            
            forgivePunishItems[#forgivePunishItems + 1] = SlmodMenuItem.create(punishVars)  -- add the item into the items table.
        end
	--------------------------------------------------------------------------------------------------------------
    end

end
slmod.info('SlmodAutoAdmin.lua loaded.')