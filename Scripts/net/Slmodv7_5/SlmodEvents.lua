function slmod.create_getNextSlmodEvents()

	local GetNextSlmodEvents_string = [=[-- debriefing module events hook
do
	--env.info('slmod GetNextSlmodEvents_string')
    local slmod_events_ind = 1
	slmod = slmod or {}
	slmod.rawEvents = nil
	
	local lUnit = Unit
	local function GetUnitRTidByName(name)
		local unit = lUnit.getByName(name)
		local unit_rtid
		if unit and unit.id_ then
			return unit.id_	
		end
		if slmod.clientsMission[name] then
			return slmod.clientsMission[name].rtid  -- either nil or a rtid.
		end
	end
    
    local function getUnitNameById(id)
        if slmod.allMissionUnitsById then
            if slmod.allMissionUnitsById[id] then
                return slmod.allMissionUnitsById[id].name
            else
                env.info('entry not found: ' .. id)
            end
        end
    end
	
	function slmod.getNextSlmodEvents()
		--env.info('in getNextSlmodEvents')
		--from debriefing.lua, not sure what it's for though.  Need it for events.
		local function dtransl(s) 
			if s and s ~= '' then return i18n.gettext.dtranslate('missioneditor', s) end
			return ''
		end


		local function compare_events(new_event, slmod_event)
			for fldname, fldval in pairs(new_event) do
				if fldname ~= 't' then --ignore the time stamp
					if slmod_event[fldname] ~= nil then	-- slmod_event has that field name		
						if slmod_event[fldname] ~= fldval then  --field val is different
							return false
						end
					else
						return false --slmod event does not have that field name
					end
				end			
			end
			return true --all field names and values the same as the slmod_event with the exception of 't'
		end



		if not slmod.rawEvents then
			--env.info('no raw events')
			slmod.rawEvents = {}
			if not debriefing.addEvent_old then
				--env.info('not addEventOld')
				debriefing.addEvent_old = debriefing.addEvent
				function debriefing.addEvent(event)
					--env.info('debriefing event:')
					--env.info(slmod.oneLineSerialize(event))
					if event.type == 'birth' then
                        return
                    end
                    
                    if (('takeoff' == event.type) or ('land' == event.type) or ('base captured' == event.type)) and ( (event.place ~= nil) and (event.place ~= '') ) then
						--env.info('do weird transl')
						event.target = dtransl(event.place);
					end
					if slmod and slmod.deepcopy then
						--log.info('slmod and deepcopy')
						--env.info(event.initiator)
						
						local eventCopy = slmod.deepcopy(event)
						
						--env.info(GetUnitRTidByName(event.initiator))
						if eventCopy.initiatorMissionID and not event.initiator then
                            eventCopy.initiator = getUnitNameById(eventCopy.initiatorMissionID)
                        end
                        
                        if eventCopy.targetMissionID and ((eventCopy.target and not GetUnitRTidByName(eventCopy.target)) or not eventCopy.target) then
                            eventCopy.target = getUnitNameById(eventCopy.targetMissionID)
                        end
                        
                        if eventCopy.initiator then -- for mission start/stop events
							eventCopy.initiatorID = GetUnitRTidByName(eventCopy.initiator)
						end
						
						if eventCopy.type == 'shot' or eventCopy.type =='start shooting' or eventCopy.type == 'end shooting' then
							-- env.info(eventCopy.type)
							-- if slmod.lastShotEvent then
							--env.info('slmod.lastShotEvent data:')
							-- env.info(slmod.lastShotEvent.time)
							-- env.info(slmod.lastShotEvent.initiatorID)
						-- env.info(slmod.lastShotEvent.weapon)
						-- env.info(slmod.lastShotEvent.weaponID)
							-- end
						--env.info(slmod.oneLineSerialize(slmod.lastShotEvent))
						
							if slmod.lastShotEvent and slmod.lastShotEvent.time == eventCopy.t and slmod.lastShotEvent.initiatorID == eventCopy.initiatorID then  -- a match!
							---	env.info('last shot event')
								if not slmod.lastShotEvent.isShell then
								--	env.info('is shell false')
									eventCopy['weaponID'] = slmod.lastShotEvent.weaponID  -- only do this for non-shells!
								end
								slmod.lastShotEvent = nil
							end
							local lShells
							if eventCopy.type =='start shooting' or eventCopy.type == 'end shooting' then -- scripting engine shell enum
								--env.info('line92')
								lShells = 0
								for index, data in pairs(Unit.getByName(eventCopy.initiator):getAmmo()) do
									if data.desc.category == 0 then
										lShells = lShells + data.count
									end
								end
								--env.info('lshells ' .. lShells)
								eventCopy['numShells'] = lShells
							end
						end
						
						if eventCopy.type == 'hit' then
							--env.info('hit')
							if slmod.lastHitEvent and slmod.lastHitEvent.time == eventCopy.t and slmod.lastHitEvent.initiatorID == eventCopy.initiatorID then  -- a match!
								if not slmod.lastHitEvent.isShell then
									eventCopy['weaponID'] = slmod.lastHitEvent.weaponID
								end
								slmod.lastHitEvent = nil
							end
						end
						
						--log.info(slmod.oneLineSerialize(eventCopy))
						
						--log.info('add to raw events')
						table.insert(slmod.rawEvents, eventCopy)
					else
						--log.info('else')
						table.insert(slmod.rawEvents, event)
					end
					--log.info('return')
					return debriefing.addEvent_old(event)
				end
			end		
		end
		local new_events = {}
		local t_insert = table.insert --declare locally for faster run times
		if #slmod.rawEvents >= slmod_events_ind then
			--env.info('rawEvents > events_ind')
            --needs to be a while loop, index it operates on is a global var
			while slmod_events_ind <= #slmod.rawEvents do
				t_insert(new_events, slmod.rawEvents[slmod_events_ind])
				
				slmod_events_ind = slmod_events_ind + 1
			end	
			
			local time_res = 0.2 --max time separate between identical events
			
			local slmod_events = {}
			
			slmod_events[1] = slmod.deepcopy(new_events[1])
			slmod_events[1]['numtimes'] = 1
			slmod_events[1]['stoptime'] = slmod_events[1].t
			
			----if there is more than 1 new event
			if #new_events > 1 then
				local new_events_ind = 2
				local cur_time
				local time_res_ind = 1

				while new_events_ind <= #new_events do
					--first, get the time of the currently evaluated event in new_events
					cur_time = new_events[new_events_ind].t 
					
					 --env.info('evaluating event #' .. tostring(new_events_ind) .. 'in new_events')
					-- env.info('time is: ' .. tostring(cur_time) .. '\n')
					
					------Next, get the index of the first event in slmod_events that occurred within time_res
					while ((time_res_ind <= #slmod_events) and ((cur_time - slmod_events[time_res_ind].stoptime) > time_res)) do
					
						time_res_ind = time_res_ind + 1
					end
					------time_res_ind now has index of the first event to occur within time_res of the current event
					
					local eval_ind = time_res_ind --make a copy... we don't want to have to re-search from scratch, so preserve value of time_res_ind
					
					if (time_res_ind > #slmod_events) then  --no event in slmod_events has occured within time_res, make a new slmod_event
						-- env.info('no event has occured within time_res, creating new slmod_event\n')
						------adding a new slmod_event
						slmod_events[#slmod_events + 1] = slmod.deepcopy(new_events[new_events_ind])
						slmod_events[#slmod_events]['numtimes'] = 1
						slmod_events[#slmod_events]['stoptime'] = slmod_events[#slmod_events].t
		 
					else-- we need to check if there is an event match
						-- env.info('event has occured within time_res at index ' .. tostring(time_res_ind) .. ' of slmod_events (size of slmod_events: ' .. tostring(#slmod_events) .. ') at stoptime ' ..  tostring(slmod_events[time_res_ind].stoptime) .. '\n')
			
						while eval_ind  <= #slmod_events do
						
							--do compare, if matches, break.  if no match, then eval_ind  will be > #slmod_events.  if it does break, then eval_ind will be <= #slmod_events
							if compare_events(new_events[new_events_ind], slmod_events[eval_ind]) then
								
								-- env.info('match found for new_events[new_events_ind] at index ' .. tostring(eval_ind) .. ' of slmod_events\n')
								break
							end
							
							
							eval_ind  = eval_ind  + 1
						end
					
						if eval_ind > #slmod_events then  --no match was found, make a new slmod_event
							-- env.info('no match found, making a new event in slmod_events\n')
							------adding a new slmod_event
							slmod_events[#slmod_events + 1] = slmod.deepcopy(new_events[new_events_ind])
							slmod_events[#slmod_events]['numtimes'] = 1
							slmod_events[#slmod_events]['stoptime'] = slmod_events[#slmod_events].t
						
					
						else  -- a match for new_events[new_events_ind] within time_res was found within slmod_events at eval_ind
							-- env.info('a match was found at ' .. tostring(eval_ind) .. 'of slmod_events\n')
							slmod_events[eval_ind]['numtimes'] = slmod_events[eval_ind]['numtimes'] + 1
							slmod_events[eval_ind]['stoptime'] = cur_time
						
						end
						
					end			

					new_events_ind = new_events_ind + 1
				end	
			
			end
           -- env.info('exit')
			return slmod.serialize('slmod_next_events', slmod_events)
			
		end
        --env.info('noE')
		return 'no_new_events'
	end
    --env.info('end GetNextSlmodEvents_string')
end]=]
	

	local str, err = net.dostring_in('server', GetNextSlmodEvents_string)
	if not err then
		slmod.error('unable to load getNextSlmodEvents code to server, reason: ' .. tostring(str))
	end

end



function slmod.addSlmodEvents()  -- called every second to build slmod.events.
	
	if slmod.events == nil then
		slmod.events = {}  --create global event table if it doesn't exist
	end
	
	local events_str, error_bool = net.dostring_in('server', 'return slmod.getNextSlmodEvents()')  --if new events have occured, will return a lua executable string
	if ((error_bool == true) and (events_str ~= 'no_new_events')) then  --new events have occurred since last call of slmod.addSlmodEvents()
		local slmod_next_events = slmod.deserializeValue(events_str)
		if ((type(slmod_next_events) == 'table') and (#slmod_next_events > 0 ))then  --shouldn't be necessary, but you never know
			-- Now, append all the entries of slmod_next_events into the global events list, "slmod.events".
			
			local t_insert = table.insert -- create local copies/references for faster execution
			
			local temp_event
			for i = 1, #slmod_next_events do
				temp_event = slmod.deepcopy(slmod_next_events[i])
				--slmod.info('original event')
				--slmod.info(slmod.tableshow(temp_event))
				------------------------------------------
				--Add to list of killers, new for v6_0
				slmod.deadUnits = slmod.deadUnits or {} --create the global dead units list
				if (temp_event.type == 'dead') or (temp_event.type == 'crash') then
					local killed_unit = temp_event.initiator
					table.insert(slmod.deadUnits, { killed_unit = killed_unit, killers = {}, hit_times = {} })
					local lslmod_events = slmod.events -- making a local reference... supposedly faster.
					for i = #lslmod_events, 1, -1  do   --now look through all the previous slmod.events
						local event = lslmod_events[i];
						if 	event.type == 'hit' and event.target == killed_unit then  -- if this unit that just died was previously hit, add the unit that hit it to the table of killers and units killed.
						--	slmod.info('insert killers and hit_times')
							table.insert(slmod.deadUnits[#slmod.deadUnits].killers, event.initiator)  -- add the hit initiator to the table of units that hit this unit before it died.
							table.insert(slmod.deadUnits[#slmod.deadUnits].hit_times, event.t)
						end
					end
				end
				
				-- input extra slmod information
				----------------------------------------------------------
				
				-- target information comes after a hit event
				--slmod.info('check target')
				if temp_event.type ~= 'birth' then
					if type(temp_event['target']) == 'string' then
						--slmod.info('target')
						local ret_unit =  slmod.getUnitByName(temp_event['target'])
						if type(ret_unit) ==  'table' then
							temp_event['target_name'] = ret_unit.name
							temp_event['target_mpname'] = ret_unit.initiatorPilotName
							
							if (ret_unit.x and ret_unit.y and ret_unit.z) then --check is probably not necessary
								temp_event['target_x'] = ret_unit.x
								temp_event['target_y'] = ret_unit.y
								temp_event['target_z'] = ret_unit.z
							end
							
							if temp_event['targetMissionID'] and type(temp_event['targetMissionID'])== 'string' then
								temp_event['targetMissionID'] = tonumber(temp_event['targetMissionID'])
							end
							
							temp_event['target_id'] = ret_unit.id
							
							
							if ret_unit.objtype then --check is probably not necessary
								temp_event['target_objtype'] = ret_unit.objtype
							end
							
							if ret_unit.coalition then --check is probably not necessary
								temp_event['target_coalition'] = ret_unit.coalition
							end
						end
					end
					
					if ((type(temp_event['initiatorMissionID']) == 'string') and (type(tonumber(temp_event['initiatorMissionID'])) == 'number')) then
						--slmod.info('convertToNumber')
						temp_event['initiatorMissionID'] = tonumber(temp_event['initiatorMissionID'])
					end
					-- initiator info
				--	slmod.info('check iniator')
					if ((type(temp_event['initiatorMissionID']) == 'number') and (type(temp_event['initiator']) == 'string')) then
						--slmod.info('valid mission Id')
						local ret_unit =  slmod.getUnitByName(temp_event['initiator'])	
						--slmod.info(slmod.tableshow(ret_unit))
						if ((type(ret_unit) ==  'table') and (temp_event['initiator'] == ret_unit.name)) then -- just need to make sure that name == initiator
							--slmod.info('valid unitName')
							
							temp_event['initiator_name'] = ret_unit.name
							temp_event['initiator_mpname'] = ret_unit.initiatorPilotName
							temp_event['initiatorID'] = ret_unit.id
							if (ret_unit.x and ret_unit.y and ret_unit.z) then	
								temp_event['initiator_x'] = ret_unit.x
								temp_event['initiator_y'] = ret_unit.y
								temp_event['initiator_z'] = ret_unit.z
							end
							if ret_unit.objtype then
								temp_event['initiator_objtype'] = ret_unit.objtype
							end
							
							if ret_unit.coalition then
								temp_event['initiator_coalition'] = ret_unit.coalition
							end
						end
					end
				elseif temp_event.type == 'birth' then
					--slmod.info('event birth')
                    if slmod.allMissionUnitsByName and slmod.activeUnitsBase and temp_event.type == 'birth' then
						
						local newUnit = {}
						newUnit.groupId = temp_event.groupId
						newUnit.group = temp_event.group
						newUnit.countryName = temp_event.countryName
						newUnit.countryId = temp_event.countryId
						newUnit.name = temp_event.name
						newUnit.mpname = temp_event.mpname
						newUnit.skill = temp_event.skill
						newUnit.unitId = temp_event.unitId
						newUnit.objtype = temp_event.objtype
						newUnit.coalition = temp_event.coalition
						newUnit.category = temp_event.category
						
						local lUnitsBase = slmod.activeUnitsBase
						lUnitsBase[#lUnitsBase + 1] = slmod.deepcopy(newUnit)
						slmod.allMissionUnitsByName[newUnit.name] = slmod.deepcopy(newUnit)
						slmod.allMissionUnitsById[newUnit.unitId] = slmod.deepcopy(newUnit)
                        
                        local s = table.concat({'slmod = slmod or {}\n', 'slmod.allMissionUnitsById[', slmod.oneLineSerialize(newUnit.unitId), '] = ', slmod.oneLineSerialize(newUnit)})
        
                        local str, err = net.dostring_in('server', s)
                        if not err then
                            slmod.error('failed to Appent slmod.allMissionUnitsById, reason: ' .. str)
                        end
					end
				--slmod.activeUnitsBase[#slmod.activeUnitsBase + 1] = newUnit
				end
				--------------------------------------------------------------------
				--slmod.info('final eventTable')
				--slmod.info(slmod.tableshow(temp_event))
				t_insert(slmod.events, temp_event)  -- insert the event onto the end of slmod.events
				
				--------------------------------------------------------------------------------------------------------------------------------------
				--------------------------------------------------------------------------------------------------------------------------------------
				
			end
			--slmod.info('end add events')
		else
			slmod.error('returned slmod events string is not \'no_new_events\', and is not a table or table size is zero!')			
		end
	
	elseif error_bool == false then
		slmod.error('unable to retreive events from server environment, reason: ' .. events_str)	
	end
end



function slmod.outputSlmodEvents()  --output of the latest events since the last run of this function to file.
	local beginS
	if slmod.next_event_ind == nil then
		slmod.next_event_ind = 1
		beginS = 'slmod.events = {}\n'  -- beginning of file...
	end
	slmod.eventsFile = slmod.eventsFile or io.open(lfs.writedir() .. 'Slmod\\slmodEvents.txt', 'w')
	if slmod.eventsFile then
		local next_events_st = {}  --table of strings to be concatenated together
		if beginS then
			next_events_st[#next_events_st + 1] = beginS
		end
		
		while slmod.next_event_ind <= #slmod.events do
			next_events_st[#next_events_st + 1] = 'slmod.events['
			next_events_st[#next_events_st + 1] = tostring(slmod.next_event_ind)
			next_events_st[#next_events_st + 1] = '] = { '
			for fldname,fldval in pairs(slmod.events[slmod.next_event_ind]) do 
				if type(fldname) == 'string' then
					next_events_st[#next_events_st + 1] = '['
					next_events_st[#next_events_st + 1] = slmod.basicSerialize(fldname)
					next_events_st[#next_events_st + 1] = '] = '
				elseif type(fldname) == 'number' then
					next_events_st[#next_events_st + 1] = '['
					next_events_st[#next_events_st + 1] = tostring(fldname)
					next_events_st[#next_events_st + 1] = '] = '
				
				end
				
				if (type(fldval) == 'string') then
				
					next_events_st[#next_events_st + 1] = slmod.basicSerialize(fldval)
					next_events_st[#next_events_st + 1] = ', '
				elseif (type(fldval) == 'number') then
					
					next_events_st[#next_events_st + 1] = tostring(fldval)
					next_events_st[#next_events_st + 1] = ', '
					
				else
					next_events_st[#next_events_st + 1] = 'nil, '  --unknown type or nil
				
				end

			end
			next_events_st[#next_events_st + 1] = '}\n'
			slmod.next_event_ind = slmod.next_event_ind + 1
		end	
		
		local next_events_s = table.concat(next_events_st)  --table.concat is fastest way to concatenate strings
		
		slmod.eventsFile:write(next_events_s)
	end
	
end


--loaded into server env every mission reset.

function slmod.load_weapons_impacting_code_to_server()  -- not just weapons impacting anymore...
	local weapons_impacting_code = [==[-- world events hook
slmod = slmod or {}
slmod.old_onEvent = slmod.old_onEvent or world.onEvent  --needs to be global here- otherwise, on mission reloading, we will create a new old_onEvent.
do 
	local active_weapons = {} --reinitalize... also, this is a global variable only temporarily.. remake this local
	local new_weapons = {}  --will turn local again later.
	local track_weapons_for = {} --reinitialize  maybe this will turn local again?
	local track_weapons_for_byname = {}  
	--[[This is the same as track_weapons_for, except all units are referened by name rather than run time id.  This is the "master reference" list.
	Only actual weapons_impacting_in_zone etcs. functions may change this table.
	Meanwhile, track_weapons_for gets changed by the update_track_weapons_for function.
	]]
	local event_start_ind = 1 --reinitialize
	local associate_weapons_scheduled = false -- reinit
	local ltinsert = table.insert  -- for faster execution.
	local ltremove = table.remove
	local lUnit = Unit
	local lObject = Object
	local prev_time = 0 --start time... needed to avoid running two weapons tracking loops after mission reset.
	--[[track_weapons_for: indexed by RTID
	track_weapons_for = {
		[12214524] = { 
			['GAU8_30_HE'] = {
				[1] = {
					type = 'zone',
					zone_name = 'New Trigger Zone #1',
					x = -155214.223, 
					z = 531533.552, 
					check_type = 'impacting_in_zone',
					radius = 300, 
					flag = 301
				}
				[2] = {
					type = 'zone',
					zone_name = 'New Trigger Zone #2'
					x = -155423.72, 
					z = 531676.81, 
					check_type = 'in_zone',
					zone_type = 'cylinder', 
					radius = 400, 
					flag = 103,
				}
				[3] = {
					type = 'moving_zone',
					unit_rtid = 112432353,  --what is actually used.
					check_type = 'impacting_in_zone',
					unit_name = 'ru_tank1_1', --residual from the reference over from track_weapons_for_byname.
					radius = 1000, 
					flag = 302
				}
			}
		}
	}]]
	
	-- this is the function that gets called by slmod net environment to start weapon tracking.
	function slmod.add_to_track_weapons_for_byname(checks_tbl, add)  -- add is boolean- true, add this, false, subtract this.
		if add then  --add entries into track_weapons_for_byname
			for unit_name, weapon_list in pairs(checks_tbl) do
				track_weapons_for_byname[unit_name] = track_weapons_for_byname[unit_name] or {}
				for weapon_type, checks in pairs(weapon_list) do
					track_weapons_for_byname[unit_name][weapon_type] = track_weapons_for_byname[unit_name][weapon_type] or {}
					for check_ind, check in pairs(checks) do
						ltinsert(track_weapons_for_byname[unit_name][weapon_type], check)  --add to the table, whether a duplicate is already there or not.
					end	
				end
			end
		
		else --remove entries from track_weapons_for_byname
			for unit_name, weapon_list in pairs(track_weapons_for_byname) do
				if checks_tbl[unit_name] then -- remove check(s) from this unit.
					for weapon_type, checks in pairs(weapon_list) do
						if checks_tbl[unit_name][weapon_type] then -- remove checks from this unit & weapon_type
							for check_ind, check in pairs(checks) do
								--now compare all the individual checks_tbl entries to this one.  If there is a match, then remove.
								for checks_tbl_check_ind, checks_tbl_check in pairs(checks_tbl[unit_name][weapon_type]) do
									if check.type == checks_tbl_check.type and check.zone_name == checks_tbl_check.zone_name and check.unit_name == checks_tbl_check.unit_name 
									and check.x == checks_tbl_check.x and check.z == checks_tbl_check.z and check.check_type == checks_tbl_check.check_type
									and check.zone_type == checks_tbl_check.zone_type and check.zone_type == checks_tbl_check.zone_type and check.radius == checks_tbl_check.radius
									and check.flag == checks_tbl_check.flag then -- exact match
										ltremove(checks, check_ind)  --remove from track_weapons_for_byname
										ltremove(checks_tbl[unit_name][weapon_type], checks_tbl_check_ind) -- ALSO remove from the checks_tbl!
										break  --leave this for loop, match found and removed.
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	
	
	
	local function GetUnitRTidByName(name)
		local unit = lUnit.getByName(name)
		local unit_rtid
		if unit and unit.id_ then
			return unit.id_	
		end
		if slmod.clientsMission[name] then
			return slmod.clientsMission[name].rtid  -- either nil or a rtid.
		end
	end
	
	--[[This function is effectively "garbage collection" for the track_weapons_for table.  It only adds unit rt ids to 
	track_weapons_for if they exist and they have weapons that need to be tracked.
	Call periodically- from SlmodCallbacks every second? Maybe every time a new slmod.activeUnits table is created and also every time 
	a weapons_impacting_in_zone function is called?
	]]
	function slmod.update_track_weapons_for()
		--env.info('running update_track_weapons_for')
		track_weapons_for = {} --reinitialize.
		
		for unit_name, weapon_list in pairs(track_weapons_for_byname) do
			--env.info('trying to get RTid for: ' .. unit_name)
			local unit_rtid = GetUnitRTidByName(unit_name)
			--env.info('RTid is: ' .. tostring(unit_rtid))
			if unit_rtid then  -- only worth continuing if this unit has a rtid
				--env.info('unit_rtid found!, it is: ' .. tostring(unit_rtid))
				for weapon, checks in pairs(weapon_list) do
					--env.info('serializing weapon and checks:')
					--env.info(slmod.oneLineSerialize(weapon))
					--env.info(slmod.oneLineSerialize(checks))
					for check_ind, check in pairs(checks) do
						if check['type'] == 'zone' then --free to add this to track_weapons_for
							track_weapons_for[unit_rtid] = track_weapons_for[unit_rtid] or {}
							track_weapons_for[unit_rtid][weapon] = track_weapons_for[unit_rtid][weapon] or {}
							ltinsert(track_weapons_for[unit_rtid][weapon], check)
						elseif check['type'] == 'moving_zone' then -- want to check if this zone unit actually exists.
							--env.info('check type is moving zone...')
							local zone_unit_rtid = GetUnitRTidByName(check['unit_name'])
							--env.info('zone_unit_rtid is: ' .. tostring(zone_unit_rtid))
							if zone_unit_rtid then  -- only worth continuing if this unit has a rtid
								track_weapons_for[unit_rtid] = track_weapons_for[unit_rtid] or {}
								track_weapons_for[unit_rtid][weapon] = track_weapons_for[unit_rtid][weapon] or {}
								check['unit_rtid'] = zone_unit_rtid
								--env.info('inserting into track_weapons_for...')
								ltinsert(track_weapons_for[unit_rtid][weapon], check)
							end
						end
					end
				end	
			end
		end
	end
	
	local function associate_weapon_names()
		associate_weapons_scheduled = false
		--env.info('associating weapon names...')
		if slmod.rawEvents then
			if new_weapons then
				while #new_weapons >= 1 do
					local weapon = new_weapons[1]			
					for i = event_start_ind, #slmod.rawEvents do  -- for this weapon, search through slmod.rawEvents for a match.
						if slmod.rawEvents[i].type == 'shot' and track_weapons_for[slmod.rawEvents[i].initiatorID] and (track_weapons_for[slmod.rawEvents[i].initiatorID][slmod.rawEvents[i].weapon] or track_weapons_for[slmod.rawEvents[i].initiatorID]['all']) and slmod.rawEvents[i].t == new_weapons[1].t then -- this event is a shot event, is for someone who is being tracked, weapon type match, time match
							new_weapons[1]['name'] = slmod.rawEvents[i].weapon  -- add the weapon name.
							new_weapons[1]['initiator'] = slmod.rawEvents[i].initiator
							if new_weapons[1]['initiator'] and (new_weapons[1]['initiator'] ~= '') then -- lets do one more check, since we are now depending on the initiator table working.
								ltinsert(active_weapons, new_weapons[1]) -- insert into active weapons
							end
							-- ltremove(new_weapons, new_weapons_ind)  --remove from new weapons
							-- new_weapons_ind = new_weapons_ind - 1  --subtract 1 to counteract while loop counter.
							break  --break out of for loop, don't need to search anymore
						end
					end
					--ok, done with this weapon.  It either was matched with a slmod_raw_event, or wasn't; regardless, it needs to be removed.
					ltremove(new_weapons, 1)
					--new_weapons_ind = new_weapons_ind + 1
				end
			else
				--env.info('no new_weapons!')
				return
			end
			event_start_ind = #slmod.rawEvents + 1 -- a potential problem- if this is called before all events have filtered over to slmod.rawEvents, then I could end up missing events.
		end
		--env.info('exiting function')
	end
	
	
	function slmod.track_weapons()  -- make this function be passed a time when the new function scheduler is completed.
		--env.info('slmod tracking weapons at: ' .. tostring(timer.getTime()))
		local cur_time = timer.getTime()
		if cur_time and cur_time > prev_time then  --prev_time - a local variable to this block of code.
			prev_time = cur_time	
			timer.scheduleFunction(slmod.track_weapons, {}, timer.getTime() + 0.1)  --schedule before the function is run... don't want a lua error to end it.
		end
		--env.info('next weapon tracking scheduled for: ' .. tostring(timer.getTime() + 0.1))
		local i = 1
		while i <= #active_weapons do
			local weapon_coords  -- will be either current weapon position, or impacted position
			local impacted = false
			local using_ip = false
			local weapon_data = active_weapons[i]
			if not lUnit.isExist(active_weapons[i].weapon) then
				--env.info('weapon no longer exists, weapon impacted?')
				if active_weapons[i].prev_ip then
					--env.info('USING PREVIOUS IP!:')
					weapon_coords = active_weapons[i].prev_ip
					using_ip = true
				else
					--env.info('no previous IP!')
					if active_weapons[i].prev_pos then
						weapon_coords = active_weapons[i].prev_pos
					end
				end
				impacted = true
				--env.info('weapon removed.')
				ltremove(active_weapons, i)  -- this weapon is gone, remove it!
				--DON'T increment the while loop counter, we removed a weapon
			else  -- weapon still exists, need to update in active_weapons.
				----update data for the weapon:
				--env.info('updating this weapon')
				local weapon_pos = lObject.getPosition(active_weapons[i].weapon)
				active_weapons[i].prev_pos = weapon_pos.p
				active_weapons[i].prev_ip = land.getIP(weapon_pos.p, weapon_pos.x, 200)
				weapon_coords = weapon_pos.p
				i = i + 1  --increment the while loop counter to go to next weapon
			end
			--now, need to check if weapon_coords, impacted, and the weapon_data indicate a weapons_in_zone or weapons_impacting_in_zone event.
			local tracked_weapons = track_weapons_for[weapon_data['initiatorID']]
			if not tracked_weapons then
				local new_rtid = GetUnitRTidByName(weapon_data['initiator']) -- can happen sometimes especially if someone switches aircraft.
				if new_rtid then
					tracked_weapons = track_weapons_for[new_rtid]
				end
			end
			if not tracked_weapons then --still can't figure out who this weapon belonged to: now look into track_weapons_for_byname, more slow
				tracked_weapons = track_weapons_for_byname[weapon_data['initiator']]  -- problem- unit_rtid may not exist here. Solved below.
			end
			
			if tracked_weapons then  -- make sure it was able to get a tracked_weapons table.
				for weapon_type, checks in pairs(tracked_weapons) do
					if ((weapon_data.name == weapon_type) or (weapon_type == 'all')) then  -- this is one of the weapons we were looking for
						for j = 1, #checks do --can do this, checks is incremental.
							if checks[j].check_type == 'in_zone' then --doesn't matter if impacted or not for in_zone.
								if checks[j].type == 'zone' then  --if check type is a regular zone
									if checks[j].zone_type == 'sphere' then
										if ((weapon_coords.x - checks[j].x)^2 + (weapon_coords.z - checks[j].z)^2 + (weapon_coords.y - land.getHeight({x = checks[j].x, y = checks[j].z}))^2 )^0.5 < checks[j].radius then --in zone!
											trigger.action.setUserFlag(checks[j].flag, true)
										end
									elseif checks[j].zone_type == 'cylinder' then
										if ((weapon_coords.x - checks[j].x)^2 + (weapon_coords.z - checks[j].z)^2)^0.5 < checks[j].radius then --in zone!
											trigger.action.setUserFlag(checks[j].flag, true)
										end
									end
								elseif checks[j].type == 'moving_zone' then  -- if the check type is a moving zone
									local zone_unit_rtid = checks[j].unit_rtid
									if not zone_unit_rtid then  -- could not happen if track_weapons_for_byname is being used.
										zone_unit_rtid = GetUnitRTidByName(checks[j].unit_name)
									end
									if zone_unit_rtid then  -- make sure it was able to find one!
										local zone_unit_pos = lObject.getPosition({ id_ = zone_unit_rtid})
										if zone_unit_pos then
											zone_unit_pos = zone_unit_pos.p
											if checks[j].zone_type == 'sphere' then
												if ((weapon_coords.x - zone_unit_pos.x)^2 + (weapon_coords.z - zone_unit_pos.z)^2 + (weapon_coords.y - zone_unit_pos.y)^2 )^0.5 < checks[j].radius then --in zone!
													trigger.action.setUserFlag(checks[j].flag, true)
												end
											elseif checks[j].zone_type == 'cylinder' then
												if ((weapon_coords.x - zone_unit_pos.x)^2 + (weapon_coords.z - zone_unit_pos.z)^2)^0.5 < checks[j].radius then --in zone!
													trigger.action.setUserFlag(checks[j].flag, true)
												end
											end
										end
									end
								end
							elseif impacted and checks[j].check_type == 'impacting_in_zone' then
								if checks[j].type == 'zone' then
									if using_ip then
										if ((weapon_coords.x - checks[j].x)^2 + (weapon_coords.z - checks[j].z)^2)^0.5 < checks[j].radius then --in zone!
											trigger.action.setUserFlag(checks[j].flag, true)
										end
									else --no IP, so use effectively a spherical zone.
										if ((weapon_coords.x - checks[j].x)^2 + (weapon_coords.z - checks[j].z)^2 + (weapon_coords.y - land.getHeight({x = checks[j].x, y = checks[j].z}))^2)^0.5 < checks[j].radius then --in zone!
											trigger.action.setUserFlag(checks[j].flag, true)
										end
									end
								elseif checks[j].type == 'moving_zone' then
									local zone_unit_rtid = checks[j].unit_rtid
									if not zone_unit_rtid then  -- could not happen if track_weapons_for_byname is being used.
										zone_unit_rtid = GetUnitRTidByName(checks[j].unit_name)
									end
									if zone_unit_rtid then  -- make sure it was able to find one!
										local zone_unit_pos = lObject.getPosition({ id_ = zone_unit_rtid})
										if zone_unit_pos then
											zone_unit_pos = zone_unit_pos.p
											if using_ip then
												if ((weapon_coords.x - zone_unit_pos.x)^2 + (weapon_coords.z - zone_unit_pos.z)^2)^0.5 < checks[j].radius then --in zone!
													trigger.action.setUserFlag(checks[j].flag, true)
												end
											else --no IP, so use effectively a spherical zone.
												if ((weapon_coords.x - zone_unit_pos.x)^2 + (weapon_coords.z - zone_unit_pos.z)^2 + (weapon_coords.y - zone_unit_pos.y)^2)^0.5 < checks[j].radius then --in zone!
													trigger.action.setUserFlag(checks[j].flag, true)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	slmod.humanWeapons = {}  -- will naturally be reset with this script!
	slmod.humanHits = {}
	slmod.humanHitsInd = 1
	
	world.onEvent = function(event) 
		--env.info('world event:')
		--env.info(slmod.oneLineSerialize(event))
        --env.info(slmod.oneLineSerialize(slmod.clientsMission))
		
		-- store latest event for preventing server crash when using DCS.getUnitProperty in active units database building code.
		slmod.lastEvent = event
		
		if event and (event.id == world.event.S_EVENT_SHOT or event.id == world.event.S_EVENT_SHOOTING_START or event.id == world.event.S_EVENT_SHOOTING_END) then
			--env.info('shot event')
			if event.weapon then
				slmod.humanWeapons[event.weapon.id_] = nil  --erase this entry if it existed before.
			end
			-------------------------------------------------------------------
			-- code for use in SlmodStats system and slmod.events
			if event.weapon then
				--env.info('event weapon')
				--env.info(event.initiator)
				local initName = Unit.getName(event.initiator)
				
				
				if initName then
					if slmod.clientsMission and slmod.clientsMission[initName] and event.weapon and slmod.deepcopy then
						--env.info('slmod: added human weapon')
                        slmod.humanWeapons[event.weapon.id_] = slmod.deepcopy(slmod.clientsMission[initName])
					end
				end
				
				local isShell
				local shellNum = 0
				--env.info('shell check')
				--if (pcall(Unit.hasAttribute, event.weapon, 'Bomb')) and (not (Unit.hasAttribute(event.weapon, 'Bomb') or Unit.hasAttribute(event.weapon, 'Missile') or Unit.hasAttribute(event.weapon, 'Rocket'))) then
				if Weapon.getDesc(event.weapon).category == 0 then -- scripting engine shell enum
				--	env.info('statement true')
					isShell = true
					--env.info('line824')
					-- doesnt actually save anything
					--[[lShells = 0
					for index, data in pairs(Unit.getByName(eventCopy.initiator):getAmmo()) do
						if data.desc.category == 0 then
							lShells = lShells + data.count
						end
					end]]
					--env.info('lshells ' .. lShells)
				end
				--env.info('add last shot event')
				
				slmod.lastShotEvent = {initiatorID = event.initiator.id_, time = event.time, weaponID = event.weapon.id_, isShell = isShell}
	
			end
			-------------------------------------------------------------------
			--env.info('shot event found!')
			--env.info(event.weapon.id_)
			--env.info(track_weapons_for[event.initiator.id_])
			if event.weapon and event.weapon.id_ and event.weapon.id_ ~= 0 and track_weapons_for[event.initiator.id_] then
			--	env.info('tracking this weapon')

				local weapon_pos = lObject.getPosition(event.weapon)
				
				table.insert(new_weapons, {weapon = event.weapon, prev_pos = weapon_pos.p, prev_ip = land.getIP(weapon_pos.p, weapon_pos.x, 200), initiatorID = event.initiator.id_, t = event.time })
				if not associate_weapons_scheduled then
					timer.scheduleFunction(associate_weapon_names, {}, timer.getTime() + 0.05)  --schedule it, wait a little bit of time for the info to percolate through.
					associate_weapons_scheduled = true
				end
			end
		
		end
		
		if event and event.id == world.event.S_EVENT_HIT then  -- needed for SlmodStats.
			------------------------------------------------------------------
			-- code for slmod.lastHitEvent, used in stat system and slmod.events
			if event.weapon then
				-- env.info('HIT EVENT: info:')
				-- env.info(slmod.oneLineSerialize(event))
				if (slmod.humanWeapons[event.weapon.id_] or (event.initiator and Unit.isExist(event.initiator) and (pcall(Unit.getName, event.initiator)) and slmod.clientsMission[Unit.getName(event.initiator)])) and event.target and slmod.deepcopy then  -- a hit on something by a human
					
					local targetName
					
					if (pcall(Unit.getName, event.target)) then
						targetName = Unit.getName(event.target)
					end
					if slmod.humanWeapons[event.weapon.id_] then
						slmod.humanHits[#slmod.humanHits + 1] = { target = targetName, targetID = event.target.id_, time = event.time, weaponID = event.weapon.id_, initiator = slmod.deepcopy(slmod.humanWeapons[event.weapon.id_])}
					else  -- human hits used to get shooter in cases of unknown initiator (id_ = 0)
						slmod.humanHits[#slmod.humanHits + 1] = { target = targetName, targetID = event.target.id_, time = event.time, weaponID = event.weapon.id_, initiator = slmod.deepcopy(slmod.clientsMission[Unit.getName(event.initiator)])}
					end
				end
				
--[[				
00060.601 UNKNOWN WinMain: false
00060.601 UNKNOWN WinMain: true	false
00060.601 UNKNOWN WinMain: false
00060.601 UNKNOWN WinMain: true
00060.601 UNKNOWN WinMain: false]]
				local isShell
				if (pcall(Unit.hasAttribute, event.weapon, 'Bomb')) and (not (Unit.hasAttribute(event.weapon, 'Bomb') or Unit.hasAttribute(event.weapon, 'Missile') or Unit.hasAttribute(event.weapon, 'Rocket'))) then
					--env.info('WEAPON IS SHELL')
					--env.info(Object.isExist(event.weapon))
					--env.info(pcall(Unit.hasAttribute, event.weapon, 'Bomb'))
					--env.info(Unit.hasAttribute(event.weapon, 'Bomb'))
					--env.info(Unit.hasAttribute(event.weapon, 'Missile'))
					--env.info(Unit.hasAttribute(event.weapon, 'Rocket'))
					isShell = true
				end
				if event.initiator then
					slmod.lastHitEvent = {initiatorID = event.initiator.id_, time = event.time, weaponID = event.weapon.id_, isShell = isShell}
				end
			end
			-------------------------------------------------------------------
		end
		
		------ birth logic
		if slmod.rawEvents then -- and #slmod.rawEvents > 2 then
			--env.info('check birth event')
            if event.id == world.event.S_EVENT_BIRTH then -- Event births occuring after mission start
				--env.info('birth event')
                local lunit = event.initiator
				
                if ((Object.getCategory(lunit) == 1 and not lunit:getPlayerName()) or Object.getCategory(lunit) ~= 1) then -- only run logic on non clients
					--env.info('c1')
                    local newEvent = {}
									
					local lgroup
                    if lunit:getCategory() == 3 or lunit:getCategory() == 6 then
                        lgroup = StaticObject.getByName(lunit:getName())
                    else
                        lgroup  = lunit:getGroup()
                    end
                    -- env.info('c2')
					--local newUnit = {}
					
					local lCoa = tonumber(lunit:getCoalition())
					
					if lCoa == 1 then
						newEvent.coalition = 'red'
					elseif lCoa == 2 then
						newEvent.coalition = 'blue'
					else
						newEvent.coalition  = 'neutral'
					end
					--env.info('c3')		
					
					newEvent.name  = lunit:getName()
					newEvent.unitId  = (lunit:getID())
					
					if Object.getCategory(lunit) == 1 and lunit:getPlayerName() then
                        newEvent.mpname = lunit:getPlayerName()
                    else
                        newEvent.mpname = lunit:getName()
                    end
                    --env.info('c4')
					 --at least, for now.
					newEvent.objtype = lunit:getTypeName()
					newEvent.group = lgroup:getName()
					newEvent.groupId = tonumber(lgroup:getID())
					newEvent.skill = "Random" -- cant find this out, so just say its random
					newEvent.countryName = string.lower(country.name[tonumber(lunit:getCountry())])
					newEvent.countryId= (lunit:getCountry())
					--env.info('c5')
					if tonumber(lunit:getCategory()) == 3 or tonumber(lunit:getCategory()) == 6 then
						newEvent.category  = 'static'
					else
						local lCat = tonumber(lgroup:getCategory())
						if lCat == 0 then
							lCat = 'plane'
						elseif lCat == 1 then
							lCat = 'helicopter'
						elseif lCat == 2 then
							lCat = 'vehicle'
						elseif lCat == 3 then
							lCat = 'vehicle'
						end
						newEvent.category = lCat
					end
					--env.info(slmod.tableshow(newUnit))
					
					
					
					newEvent.type = 'birth'
					newEvent.t = timer.getAbsTime()
					newEvent.numtimes = 1
					newEvent.initiator = lunit:getName()
					--env.info('insert into rawEvents')
					table.insert(slmod.rawEvents, newEvent)
					--env.info(slmod.tableshow(newEvent))
					--slmod.allMissionUnitsByName[newUnit.name] = newUnit
					--slmod.activeUnitsBase[#slmod.activeUnitsBase + 1] = newUnit
				end
			end
		end
		
		--env.info('running old_onEvent')
		return slmod.old_onEvent(event)
	end
	
	function slmod.getLatestHumanHits()  -- used only for tracking hits
		local hits = {}
		while slmod.humanHitsInd <= #slmod.humanHits do
			hits[#hits + 1] = slmod.humanHits[slmod.humanHitsInd]
			slmod.humanHitsInd = slmod.humanHitsInd + 1	
		end
		if #hits > 0 then
			return 'hits = ' .. slmod.oneLineSerialize(hits)
		else
			return 'no hits'
		end
	end
	
	
	function slmod.missionEndEvent()
		if slmod.lastEvent then
			return slmod.lastEvent.id == world.event.S_EVENT_MISSION_END 
		end
	end
	
	
end]==]
	local str, err = net.dostring_in('server', weapons_impacting_code)
	if err then
		slmod.info('weapons_impacting_code loaded successfully to server env')
	else
		slmod.error('failed to load weapons_impacting_code to server, reason: ' .. str)
	end
end

function slmod.missionEndEvent() -- needed to avoid a ctd from DCS.getUnitProperty when the server is shutting down.
	local str, err = net.dostring_in('server', 'return tostring(slmod.missionEndEvent())')
	if err and str then
		return str == 'true'
	end
	return false
end

slmod.info('SlmodEvents.lua loaded.')