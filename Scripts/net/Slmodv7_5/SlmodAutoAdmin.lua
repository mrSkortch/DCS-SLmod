do
	--[[ todo:
	"forgive player" menu
	]]

	local stats = slmod.stats.getStats()
	local autoAdmin = slmod.config.autoAdmin
	
	local function checkedKick(id, ucid, kickMsg)  -- kick with verification of kicked player Ucid.
		if slmod.clients[id] and slmod.clients[id].ucid == ucid then -- make sure it's the same player!
			net.kick(id, kickMsg)
		end
	end
	
	local function delayedKick(id, ucid, kickMsg, delay)
		delay = delay or 10
		kickMsg = kickMsg or 'You were kicked.'
		slmod.scheduleFunctionByRt(checkedKick, {id, ucid, kickMsg}, DCS.getRealTime() + delay)
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
			if pStats and autoAdmin and (autoAdmin.autoBanEnabled or autoAdmin.autoKickEnabled) then
				local score = 0  -- penalty score
				local curTime = os.time()
				
				-- score team hits
				if autoAdmin.teamHit.enabled and pStats.friendlyHits then  -- score team hits.
					local lastAIHitTime  -- a time.
					local lastHumanHitTime
					for hitInd = 1, #pStats.friendlyHits do
						local hit = pStats.friendlyHits[hitInd]
						if type(hit) == 'table' and hit.time then -- I may be being obsessive-compulsive here...
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
						if type(kill) == 'table' and kill.time then -- I may be being obsessive-compulsive here...
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
						if type(colHit) == 'table' and colHit.time then -- I may be being obsessive-compulsive here...
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
						if type(colKill) == 'table' and colKill.time then -- I may be being obsessive-compulsive here...
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
	function slmod.autoAdminOnOffense(client)  -- client is a slmod.client.
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
					
					delayedKick(client.id, client.ucid, 'You were autobanned from the server.', 5)
					
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
					
					delayedKick(client.id, client.ucid, 'You were autokicked from the server.', 5)
					--net.kick(client.id, 'You were autokicked from the server.')
					slmod.info('Player "' .. tostring(client.name) .. '" is getting autokicked.', true)  -- this will output in chat too.
					return
				end
			end
			
		end
	end
	
	--------------------------------------------------------------------------------------------------------------

end
slmod.info('SlmodAutoAdmin.lua loaded.')