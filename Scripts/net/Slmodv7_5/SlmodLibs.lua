
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--chatIOlibv1 legacy support
function slmod.chatmsg_net(text)
	net.log('chatmsg_net')
	if (not slmod.typeCheck({'string'}, {text})) then
		slmod.error('invalid variable type in slmod.chatmsg_net', true)
		return
	end
	local clientindex = 0
	while clientindex <= 128 do
		net.send_chat_to(text, clientindex, clientindex)				
		clientindex = clientindex + 1
	end
	net.recv_chat(text) --output to host
end

function slmod.chatmsg_repeat_net(msgline, numtimes, interval)
	if (not slmod.typeCheck({'string', 'number', 'number'}, {msgline, numtimes, interval})) then
		slmod.error('invalid variable type in slmod.chatmsg_repeat_net', true)
		return
	end
	slmod.chatmsg_net(msgline)
	numtimes = numtimes - 1
	while numtimes > 0 do
	
		slmod.scheduleFunction(slmod.chatmsg_net, {msgline}, DCS.getModelTime() + numtimes*interval)
		numtimes = numtimes - 1
	end
end

--used only now for the old chatIOlib support
function slmod.create_msg_MGRS_server()
	local msg_MGRS_server_string = [[slmod = slmod or {}
function slmod.msg_MGRS_server(prefacemsg, units, numdigits, numtimes, interval, coa)
	
	local unit_table = {}
	local unit_table_ind = 0
	
	--put existing units into unit_table
	for ind1 = 1, #units do
		local tempunit = Unit.getByName(units[ind1])
		if tempunit ~= nil then
			unit_table_ind = unit_table_ind + 1
			unit_table[unit_table_ind] = tempunit	
		end
	end

	--if there are any units
	if unit_table_ind >= 1 then
	
		--now get average position of the "group"
		local numunits = 0
		local avgx = 0
		local avgy = 0
		local avgz = 0
	
		for ind1 = 1,#unit_table do
			if unit_table[ind1]:isExist() then  --probably not necessary, but just to be safe...
				numunits = numunits + 1
				avgx = unit_table[ind1]:getPosition().p.x + avgx
				avgy = unit_table[ind1]:getPosition().p.y + avgy
				avgz = unit_table[ind1]:getPosition().p.z + avgz
			end
		end

		local avgp = { x =  avgx/numunits, y =  avgy/numunits, z = avgz/numunits }

		local groupMGRS = coord.LOtoMGRS(avgp)
		local groupNorthing = groupMGRS.Northing
		local groupEasting = groupMGRS.Easting
		local acc = numdigits/2
		local rndpwr = 5 - acc
		groupEasting = slmod.round(groupEasting, rndpwr)/(10^rndpwr) 
		groupNorthing = slmod.round(groupNorthing, rndpwr)/(10^rndpwr) 
		local groupEastingString = string.format('%0' .. tostring(acc) .. 'd', groupEasting)
		local groupNorthingString = string.format('%0' .. tostring(acc) .. 'd', groupNorthing)
	
		--assemble the data table
		local tbl = {}
		tbl[1] = prefacemsg
		tbl[2] = groupMGRS.UTMZone
		tbl[3] = groupMGRS.MGRSDigraph
		tbl[4] = groupEastingString
		tbl[5] = groupNorthingString
		tbl[6] = tostring(math.floor(avgp.y))
		tbl[7] = numtimes  -- AKA display_time
		tbl[8] = interval -- AKA display_mode
		tbl[9] = coa
		return slmod.oneLineSerialize(tbl)
	end
end]]
	net.dostring_in('server', msg_MGRS_server_string)
end



--Second stage chatmsg_groupMGRS function
function slmod.chatmsg_groupMGRS_net(prefacemsg, units, numdigits, numtimes, interval)
	if (not slmod.typeCheck({'string', 'table_s', 'number', 'number', 'number'}, {prefacemsg, units, numdigits, numtimes, interval})) then
		slmod.error('Slmod: invalid variable type in slmod.chatmsg_groupMGRS_net', true)
		return
	end

	if ((type(numdigits) == 'number') and (type(numtimes) == 'number') and (type(interval) == 'number')) then
	
		local tablestring = slmod.oneLineSerialize(units)
		
		local groupMGRSstring = 'slmod.msg_MGRS_server(' .. slmod.basicSerialize(prefacemsg) .. ', ' .. tablestring .. ', ' ..  tostring(numdigits) .. ', ' .. tostring(numtimes) .. ', ' .. tostring(interval) .. ')'

		local str, err = net.dostring_in('server', groupMGRSstring)
		
		if err and type(str) == 'string' then
			local retDataString = 'retData = ' .. str
			local f, err = loadstring(retDataString)
			if f then
				local safeEnv = {}
				setfenv(f, safeEnv)
				local bool, err2 = pcall(f)
				if bool then
					local retData = safeEnv['retData']
					if type(retData) == 'table' then
						local prefacemsg = retData[1]		
						local UTMZone = retData[2]
						local MGRSDigraph = retData[3]
						local groupEastingString = retData[4]
						local groupNorthingString = retData[5]
						local elevation = retData[6]
						local numtimes = retData[7]
						local interval = retData[8]
						
						local msgstring = prefacemsg .. UTMZone .. ' ' .. MGRSDigraph .. groupEastingString .. groupNorthingString .. ' ' .. 'Elevation: ' .. tostring(math.floor(elevation/0.3048)) .. ' feet'
						slmod.chatmsg_repeat_net(msgstring, numtimes, interval)
					end
				end
			end
		end
		--net.log('did the slmod.chatmsg_groupMGRS_net string successfully')
	else
		net.log('illegal variable type')
	end
end

function slmod.command_check_net(commandtext, flag)
	if (not slmod.typeCheck({'string', 'number'}, {commandtext, flag})) then
		slmod.error('invalid variable type in slmod.command_check_net', true)
		return
	end
	if slmod.chat_table ~= nil then
		local chat_ind = 1
		while chat_ind <= #slmod.chat_table do
			if commandtext ==  slmod.chat_table[chat_ind].msg then
				table.remove(slmod.chat_table, chat_ind)
				chat_ind = chat_ind - 1
				net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
			end
		
			chat_ind = chat_ind + 1
		end
	
	end
end

function slmod.command_check_start_loop_net(commandtext, flag, interval, purge)
	if (not slmod.typeCheck({'string', 'number', 'number', {'boolean', 'nil'}}, {commandtext, flag, interval, purge})) then
		slmod.error('invalid variable type in slmod.command_check_start_loop_net', true)
		return
	end
	if purge == nil then
		purge = true
	end
	
	if purge == true then
		if slmod.chat_table ~= nil then
			local chat_ind = 1
			while chat_ind <= #slmod.chat_table do
				if commandtext ==  slmod.chat_table[chat_ind].msg then
					table.remove(slmod.chat_table, chat_ind)
					chat_ind = chat_ind - 1
				end
				chat_ind = chat_ind + 1
			end
		end
	end
	
	slmod.command_check_net(commandtext, flag)	
	
	slmod.scheduleFunction(slmod.command_check_start_loop_net, {commandtext, flag, interval, false}, DCS.getModelTime() + interval)
end
--end of chatIOlibv1 legacy support
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--New, basic chat IO


-- msg_out, new basic way to output messages
function slmod.msg_out_net(text_out, display_time, display_mode, coa)   --display_mode must be 'chat', 'text', 'both', or nil
	if (not slmod.typeCheck({'string', 'number', {'string', 'nil'}, {'string', 'nil'}}, { text_out, display_time, display_mode, coa })) then
		slmod.error('invalid variable type in slmod.msg_out_net', true)
		return
	end
	
	--set defaults
	coa = coa or 'all'          
	display_mode = display_mode or 'echo'
	
	if ((display_mode ~= 'chat') and (display_mode ~= 'echo') and (display_mode ~= 'both') and (display_mode ~= 'text')) then
		display_mode = 'echo'  --force to echo mode
	end

	local nl_start, nl_end = text_out:find('\n', 1)
		
	if ((display_mode == 'text') or (display_mode == 'both') or (display_mode == 'echo')) then
		slmod.triggerText(text_out, display_time, coa)  --output trigger text
	end	
	
	if nl_end == nil then  --single line message
				
		if (display_mode == 'echo') then
			slmod.basicChat(text_out, coa)
		end	
			
		local display_num = math.floor(display_time/6);
			
		if ((display_mode == 'chat') or (display_mode == 'both')) then			
			slmod.basicChatRepeat(text_out, display_num, 6, coa)
		end
			
	else --multiline message
	
		if ((display_mode == 'chat') or (display_mode == 'both') or (display_mode == 'echo')) then
			--put the lines in a table:
			local lines = {}
			local line1 = text_out:sub(1, nl_end-1)
			lines[1] = line1
			local lines_counter = 2
			while (nl_end ~= nil) do
				local prev_nl_end = nl_end + 1
				nl_start, nl_end =  text_out:find('\n', nl_end+1)
				if nl_end == nil then
					lines[lines_counter] = text_out:sub(prev_nl_end, text_out:len())		
				else
					lines[lines_counter] = text_out:sub(prev_nl_end, nl_end-1)
					lines_counter = lines_counter + 1
				end
				
			end
				
			local numlines = #lines
			local intvl_each = math.floor(display_time/numlines)
				
			if intvl_each == 0 then
				intvl_each = 1
			end
				
			local time_disp_each = display_time/numlines
			local numtimes_each = math.floor(time_disp_each/intvl_each)
				
			if ((numtimes_each == 0) or (display_mode == 'echo')) then
				numtimes_each = 1
			end
				
			if (display_mode == 'echo') then
				intvl_each = 1
			end
				
			local msg_time = 1
			local msg_string
			for msg_counter = 1,numlines do
				msg_string = lines[msg_counter]
				for i = 1, numtimes_each do
					slmod.scheduleFunction(slmod.basicChat, {msg_string, coa}, DCS.getModelTime() + msg_time)
					msg_time = msg_time + intvl_each
				end
			end		
		end		
	end
end	


--new function to display a unit's "mpname" within a message.
function slmod.msg_out_w_unit_net(text_out, unit_name, display_time, display_mode, coa)   --display_mode must be 'chat', 'text', 'both', or nil
	if (not slmod.typeCheck({'string', 'string', 'number', {'string', 'nil'}, {'string', 'nil'}}, { text_out, unit_name, display_time, display_mode, coa })) then
		slmod.error('invalid variable type in slmod.msg_out_w_unit_net', true)
		return
	end	
	--set defaults
	coa = coa or 'all'          
	display_mode = display_mode or 'echo'
	
	--build message string
	local mpname = '!no unit!' 
	local slmod_unit = slmod.getUnitByName(unit_name)
	if slmod_unit then
		mpname = slmod_unit.mpname
	end
	local msg_string = string.format(text_out, mpname)
	slmod.msg_out_net(msg_string, display_time, display_mode, coa)
end


-- Simple function- just sends a chat message to combined arms players on coa.
function slmod.CA_chatmsg_net(text, coa) 
	-- do some type checking to be safe...
	if not slmod.typeCheck({'string', {'string', 'nil'}}, {text, coa}) then
		slmod.error('invalid variable type in slmod.CA_chatmsg_net', true)
		return
	end
		
	local BC_names = {'artillery_commander_blue_', 'instructor_blue_', 'forward_observer_blue_', 'observer_blue_', 'artillery_commander_red_', 'instructor_red_', 'forward_observer_red_', 'observer_red_' } -- fill with the names for all battle commander slots.

	local function is_BC(name)
		if type(name) == 'string' and name ~= '' then
			for ind, BC_name in pairs(BC_names) do
				if name:find(BC_name) then
					return true
				end
			end
		end
		return false
	end

	local coaNum = 0
	if coa == 'red' then
		coaNum = 1
	elseif coa == 'blue' then
		coaNum = 2
	end
	
	if slmod.clients then
		local new_clients = {}
		for id, client in pairs(slmod.clients) do
			local side = net.get_player_info(id, 'side')
			local unit_id = net.get_player_info(id, 'slot')
			if unit_id and side and (side == 0 or side == coaNum) then  --check to see if there's a unit_id and if the coalition is right
				if is_BC(unit_id) then
					if id == 1 then
						net.recv_chat(text)
					else
						net.send_chat_to(text, id, id)
					end
				end
			end
		end
	end
end


-- For new parallel tasking system, and later to be used for others?
function slmod.create_get_coords_msg_string() 
	local get_coords_msg_string_string = [==[function get_coords_msg_string(coordtype, msg, units, numdigits)
	
	local unit_table = {}
	local unit_table_ind = 0
	
	--put existing units into unit_table
	for ind1 = 1, #units do
		local tempunit = Unit.getByName(units[ind1])
		if tempunit ~= nil then
			unit_table_ind = unit_table_ind + 1
			unit_table[unit_table_ind] = tempunit	
		end
	end

	--if there are any units
	if unit_table_ind >= 1 then
	
		--now get average position of the "group"
		local numunits = 0
		local avgx = 0
		local avgy = 0
		local avgz = 0
	
		for ind1 = 1,#unit_table do
			if unit_table[ind1]:isExist() then  --probably not necessary, but just to be safe...
				numunits = numunits + 1
				avgx = unit_table[ind1]:getPosition().p.x + avgx
				avgy = unit_table[ind1]:getPosition().p.y + avgy
				avgz = unit_table[ind1]:getPosition().p.z + avgz
			end
		end

		local avgp = { x =  avgx/numunits, y =  avgy/numunits, z = avgz/numunits }

		if coordtype == 'MGRS' then
			local groupMGRS = coord.LOtoMGRS(avgp)
			local groupNorthing = groupMGRS.Northing
			local groupEasting = groupMGRS.Easting
			local acc = math.floor(math.abs(numdigits)/2)
			local rndpwr = 5 - acc
			groupEasting = slmod.round(groupEasting, rndpwr)/(10^rndpwr) 
			groupNorthing = slmod.round(groupNorthing, rndpwr)/(10^rndpwr) 
			local groupEastingString = string.format('%0' .. tostring(acc) .. 'd', groupEasting)
			local groupNorthingString = string.format('%0' .. tostring(acc) .. 'd', groupNorthing)
			local coords_string = groupMGRS.UTMZone .. ' ' ..  groupMGRS.MGRSDigraph .. groupEastingString .. groupNorthingString .. ' elevation: ' .. tostring(math.floor(avgp.y)).. ' meters'
			
			if (string.find(msg, '%%s')) then  -- look for %s
				local s = string.format(msg, coords_string)
				return s
			else
				return msg .. coords_string
			end
		elseif coordtype == 'LL' then
			local groupLL = {}
			groupLL['lat'], groupLL['lon'] = coord.LOtoLL(avgp)
			local latdeg = math.floor(math.abs(groupLL.lat))
			local latmin = (math.abs(groupLL.lat) - latdeg)*60
			local longdeg = math.floor(math.abs(groupLL.lon))
			local longmin = (math.abs(groupLL.lon) - longdeg)*60
			-- now do rounding
			latmin = slmod.round(latmin, numdigits)
			longmin = slmod.round(longmin, numdigits)
			
			if latmin == 60 then
				latmin = 0
				latdeg = latdeg + 1
			end
			
			if longmin == 60 then
				longmin = 0
				longdeg = longdeg + 1
			end
			
			local NS_hemi
			local EW_hemi
			
			if groupLL.lat > 0 then
				NS_hemi = 'N'
			else
				NS_hemi = 'S'
			end
			
			if groupLL.lon > 0 then
				EW_hemi = 'E'
			else
				EW_hemi = 'W'
			end
			
			local len_adj  --total length adjustment from nominal (including decimal point)
			local acc_adj --number of digits after decimal
			if numdigits > 0 then
				len_adj = numdigits + 1  -- plus one because the decimal point counts
			else
				len_adj = 0
			end
			if numdigits >= 0 then
				acc_adj = numdigits
			else
				acc_adj = 0
			end

			local coords_string = string.format('%02d', tostring(latdeg)) .. ' ' .. string.format('%0' .. tostring(2+len_adj) .. '.' .. tostring(acc_adj) .. 'f', tostring(latmin)) .. '\' ' .. NS_hemi .. ', ' .. string.format('%03d', tostring(longdeg)) .. ' ' .. string.format('%0' .. tostring(2+len_adj) .. '.' .. tostring(acc_adj) .. 'f', tostring(longmin)) .. '\' ' .. EW_hemi .. ', elevation: ' .. tostring(math.floor(avgp.y)) .. ' meters'
		
			if (string.find(msg, '%%s')) then  -- look for %s
				local s = string.format(msg, coords_string)
				return s
			else
				return msg .. coords_string
			end
		end
	else
		return ''
	end
end]==]

	net.dostring_in('server', get_coords_msg_string_string)

end


function slmod.msg_MGRS_net(prefacemsg, units, numdigits, display_time, display_mode, coa)
	--Type-check for security:
	if slmod.typeCheck({'string', 'table_s', 'number', {'number', 'nil'}, {'string', 'nil'}, {'string', 'nil'}}, { prefacemsg, units, numdigits, display_time, display_mode, coa }) ~= true then
		slmod.error('invalid variable type in slmod.msg_MGRS_net', true)
		return
	end
	
	display_mode = display_mode or 'echo'
	display_time = display_time or 30
	coa = coa or 'all'
	
	if not units.processed then
		units = slmod.makeUnitTable(units)
	end
	units.processed = nil  --delete this entry just to make sure there is no problem.
	
	if ((numdigits ~= 2) and (numdigits ~= 4) and (numdigits ~= 6) and (numdigits ~= 8) and (numdigits ~= 10)) then
		slmod.error('you must specify numdigits to be either 2, 4, 6, 8, or 10 in msg_MGRS', true)
		return
	end
	local msg_string =  net.dostring_in('server', 'return get_coords_msg_string(\'MGRS\', ' .. slmod.basicSerialize(prefacemsg) .. ', ' .. slmod.oneLineSerialize(units) .. ', ' .. tostring(numdigits) .. ')')
	if msg_string and msg_string ~= '' then
		slmod.msg_out_net(msg_string, display_time, display_mode, coa)
	end
end



function slmod.msg_LL_net(prefacemsg, units, precision, display_time, display_mode, coa)
	------Type-check for security:
	if slmod.typeCheck({'string', 'table_s', 'number', {'number', 'nil'}, {'string', 'nil'}, {'string', 'nil'}}, { prefacemsg, units, precision, display_time, display_mode, coa }) ~= true then
		slmod.error('invalid variable type in slmod.msg_LL_net', true)
		return
	end
	
	display_mode = display_mode or 'echo'
	display_time = display_time or 30
	coa = coa or 'all'
	
	if not units.processed then
		units = slmod.makeUnitTable(units)
	end
	units.processed = nil  --delete this entry just to make sure there is no problem.
	
	if ((precision ~= -1) and (precision ~= 0) and (precision ~= 1) and (precision ~= 2) and (precision ~= 3)) then
		slmod.error('you must specify precision to be either -1, 0, 1, 2, or 3 in slmod.msg_LL_net', true)
		return
	end
	local msg_string =  net.dostring_in('server', 'return get_coords_msg_string(\'LL\', ' .. slmod.basicSerialize(prefacemsg) .. ', ' .. slmod.oneLineSerialize(units) .. ', ' .. tostring(precision) .. ')')
	if msg_string and msg_string ~= '' then
		slmod.msg_out_net(msg_string, display_time, display_mode, coa)
	end
end


function slmod.create_get_leading_msg_string() 
	local get_leading_msg_string_string = [==[function get_leading_msg_string(coordtype, msg, units, direction, radius, numdigits)

	local extrema_unit_posit
	local newunitgroup = {}
	local current_unit
	local northmostcoord
	local southmostcoord
	local eastmostcoord
	local westmostcoord
	
	if direction == 'N' then
		for ind1 = 1, #units do
			current_unit = Unit.getByName(units[ind1])
			if current_unit ~= nil then
				if northmostcoord == nil then
					northmostcoord = current_unit:getPosition().p.x
					extrema_unit_posit = current_unit:getPosition().p
				end
				if current_unit:getPosition().p.x > northmostcoord then
					extrema_unit_posit = current_unit:getPosition().p
					northmostcoord = extrema_unit_posit.x
				end
			end
		end
	end
	if direction == 'S' then
		for ind1 = 1, #units do
			current_unit = Unit.getByName(units[ind1])
			if current_unit ~= nil then
				if southmostcoord == nil then
					southmostcoord = current_unit:getPosition().p.x
					extrema_unit_posit = current_unit:getPosition().p
				end
				if current_unit:getPosition().p.x < southmostcoord then
					extrema_unit_posit = current_unit:getPosition().p
					southmostcoord = extrema_unit_posit.x
				end
			end
		end
	end
	if direction == 'E' then
		for ind1 = 1, #units do
			current_unit = Unit.getByName(units[ind1])
			if current_unit ~= nil then
				if eastmostcoord == nil then
					eastmostcoord = current_unit:getPosition().p.z
					extrema_unit_posit = current_unit:getPosition().p
				end
				if current_unit:getPosition().p.z > eastmostcoord then
					extrema_unit_posit = current_unit:getPosition().p
					eastmostcoord = extrema_unit_posit.z
				end
			end
		end
	end
	if direction == 'W' then
		for ind1 = 1, #units do
			current_unit = Unit.getByName(units[ind1])
			if current_unit ~= nil then
				if westmostcoord == nil then
					westmostcoord = current_unit:getPosition().p.z
					extrema_unit_posit = current_unit:getPosition().p
				end
				if current_unit:getPosition().p.z < westmostcoord then
					extrema_unit_posit = current_unit:getPosition().p
					westmostcoord = extrema_unit_posit.z
				end
			end
		end
	end
	
	--Now make a list of all the units neareast the extrema_unit_posit
	for ind1 = 1, #units do
		if extrema_unit_posit == nil then
			break  --not sure what hte point of this is anymore.
		end
		current_unit = Unit.getByName(units[ind1])
		if current_unit ~= nil then
			if ((extrema_unit_posit.x - current_unit:getPosition().p.x)^2 + (extrema_unit_posit.z - current_unit:getPosition().p.z)^2)^0.5 < radius then
				table.insert(newunitgroup, units[ind1])
			end
		end	
	end
	if #newunitgroup >= 1 then
		return get_coords_msg_string(coordtype, msg, newunitgroup, numdigits)
	end
	return ''
end]==]

	net.dostring_in('server', get_leading_msg_string_string)

end


function slmod.msg_leading_net(coordtype, prefacemsg, units, direction, radius, precision, display_time, display_mode, coa)
	--Type-check for security:
	if slmod.typeCheck({'string', 'string', 'table_s', 'string', 'number', 'number', {'number', 'nil'}, {'string', 'nil'}, {'string', 'nil'}}, { coordtype, prefacemsg, units, direction, radius, precision, display_time, display_mode, coa }) ~= true then
		slmod.error('invalid variable type in slmod.msg_leading_net', true)
		return
	end
	display_mode = display_mode or 'echo'
	display_time = display_time or 30
	coa = coa or 'all'
	radius = radius or 3000
	
	if not units.processed then
		units = slmod.makeUnitTable(units)
	end
	units.processed = nil  --delete this entry just to make sure there is no problem.
	
	if (((coordtype == 'LL') and (precision ~= -1) and (precision ~= 0) and (precision ~= 1) and (precision ~= 2) and (precision ~= 3)) or ((coordtype == 'MGRS') and (precision ~= 2) and (precision ~= 4) and (precision ~= 6) and (precision ~= 8) and (precision ~= 10))) then
		slmod.error('you must specify precision to be either -1, 0, 1, 2, or 3 in slmod.msg_leading for coordtype LL, or 2, 4, 6, 8, or 10 for coordtype MGRS', true)
		return
	end
	
	if ((direction ~= 'N') and (direction ~= 'E') and (direction ~= 'S') and (direction ~= 'W')) then
		slmod.error('you must specify direction to be either "N", "S", "E", or "W" in slmod.msg_leading', true)
		return
	end
	
	if coordtype == 'LL' then
		local msg_string =  net.dostring_in('server', 'return get_leading_msg_string(\'LL\', ' .. slmod.basicSerialize(prefacemsg) .. ', ' .. slmod.oneLineSerialize(units) .. ', ' .. slmod.basicSerialize(direction) .. ', ' .. tostring(radius) .. ', ' .. tostring(precision) .. ')')
		if msg_string and msg_string ~= '' then
			slmod.msg_out_net(msg_string, display_time, display_mode, coa)
		end
	elseif coordtype == 'MGRS' then
		local msg_string =  net.dostring_in('server', 'return get_leading_msg_string(\'MGRS\', ' .. slmod.basicSerialize(prefacemsg) .. ', ' .. slmod.oneLineSerialize(units) .. ', ' .. slmod.basicSerialize(direction) .. ', ' .. tostring(radius) .. ', ' .. tostring(precision) .. ')')
		if msg_string and msg_string ~= '' then
			slmod.msg_out_net(msg_string, display_time, display_mode, coa)
		end
	end
end


--replacement for command_check_start_loop
function slmod.chat_cmd_net(cmd_text, flag, chat_ind, stopflag, coa)
	if stopflag == '' then
		stopflag = nil
	end
	if (not slmod.typeCheck({'string', 'number', 'number', {'number', 'nil'}, {'string', 'nil'}}, { cmd_text, flag, chat_ind, stopflag, coa })) then
		slmod.error('invalid variable type in slmod.chat_cmd_net', true)
		return
	end
	stopflag = stopflag or -1

	if ((coa ~= 'red') and (coa ~= 'blue')) then
		coa = 'all'
	end
	
	if chat_ind == -1 then
		chat_ind = #slmod.chat_table + 1  -- start searching at next chat
	end
	
	if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then

		local coa_int = 0
		
		if coa == 'red' then
			coa_int = 1
		elseif coa == 'blue' then
			coa_int = 2
		end
		
		while chat_ind <= #slmod.chat_table do
			if cmd_text == slmod.chat_table[chat_ind].msg then  --ok, a message match found
				if coa == 'all' then
					net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)') 
				else  --need to check sides
					-- now if the side checks out:
					local side = net.get_player_info(slmod.chat_table[chat_ind].id, 'side')
					if side == coa_int then
						net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
					end	
				end
			end
			chat_ind = chat_ind + 1
		end

		slmod.scheduleFunction(slmod.chat_cmd_net, {cmd_text, flag, chat_ind, stopflag, coa}, DCS.getModelTime() + 1)		
	end
end
--End of basic chat IO
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
-- OO Parallel Tasking System
function slmod.ResetPTS()  --reset the normal PTS items, call this every SlmodReset
	
	if RedPTS then  --VERY MUCH necessary- need to remove ALL references everywhere to the old menus!
		RedPTS = RedPTS:destroy()
	end
	if BluePTS then
		BluePTS = BluePTS:destroy()
	end
	
	local showCmds = {
		[1] = {
			[1] = {  
				type = 'word',
				text = '-stl',
				required = true
			}
		},
		[2] = {  
			[1] = {
				type = 'word',
				text = 'show',
				required = true
			},
			[2] = {
				type = 'word',
				text = 'task',
				required = true
			},
			[3] = {
				type = 'word',
				text = 'list',
				required = true
			}
		}
	}
	local options = {} 
	options.title = 'Tasks:'
	--options.itemSelCmd_base = '-st'
	RedPTS = PTSMenu.create(slmod.deepcopy(showCmds), {coa = 'red'}, slmod.deepcopy(options))   -- slmod.deepcopy might not always be appropriate for this use - are subtables copied too with slmod.deepcopy?
	BluePTS = PTSMenu.create(slmod.deepcopy(showCmds), {coa = 'blue'}, slmod.deepcopy(options))

end


function slmod.add_task_net(coa, id, task_type, description, msg, group, numdigits, direction, radius)
	if (not slmod.typeCheck({'string', 'number', 'string', 'string', 'string', {'table_s', 'nil'}, {'number', 'nil'}, {'string', 'nil'}, {'number', 'nil'}}, { coa, id, task_type, description, msg, group, numdigits, direction, radius })) then
		slmod.error('invalid variable type in slmod.add_task_net', true)
		return
	end	
	if ((task_type ~= 'msg_out') and (task_type ~= 'msg_LL') and (task_type ~= 'msg_MGRS') and (task_type ~= 'msg_leading_LL') and (task_type ~= 'msg_leading_MGRS')) then
		slmod.error('invalid task_type specified in slmod.add_task_net; you must specify a task type of either "msg_out", "msg_LL", "msg_MGRS", "msg_leading_LL", or "msg_leading_MGRS" for an add_task function.', true)
		return
	end	
	if ((task_type == 'msg_leading_MGRS') or (task_type == 'msg_leading_LL')) then
		radius = radius or 3000
	end
	
	if group then
		if not group.processed then
			group = slmod.makeUnitTable(group)
		end
		group.processed = nil  --delete this entry just to make sure there is no problem.
	end
	
	local task_data = { description = description, msg = msg, task_type = task_type, group = group, numdigits = numdigits, id = id, direction = direction, radius = radius }
	
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePTS then
			BluePTS:add_task(nil, task_data)
		else
			slmod.error('no BluePTS in slmod.add_task_net', true)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPTS then
			RedPTS:add_task(nil, task_data)
		else
			slmod.error('no RedPTS in slmod.add_task_net', true)
		end
	end
end

function slmod.remove_task_net(coa, id)
	if (not slmod.typeCheck({'string', 'number'}, { coa, id})) then
		slmod.error('invalid variable type in slmod.remove_task_net', true)
		return
	end
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePTS then
			BluePTS:removeById(id)
		else
			slmod.error('no BluePTS in slmod.remove_task_net', true)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPTS then
			RedPTS:removeById(id)
		else
			slmod.error('no RedPTS in slmod.remove_task_net', true)
		end
	end
end


function slmod.show_task_net(coa, id, display_time, display_mode)
	if (not slmod.typeCheck({'string', 'number', {'number', 'nil'}, {'string', 'nil'}}, { coa, id, display_time, display_mode })) then
		slmod.error('invalid variable type in slmod.show_task_net', true)
		return
	end
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePTS and BluePTS:getItemById(id) then
			BluePTS:getItemById(id):show({coa = 'blue'}, display_time, display_mode)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if BluePTS and BluePTS:getItemById(id) then
			BluePTS:getItemById(id):show({coa = 'red'}, display_time, display_mode)
		end
	end
end


function slmod.show_task_list_net(coa)
	if (not slmod.typeCheck({'string'}, { coa })) then
		slmod.error('invalid variable type in slmod.show_task_list_net', true)
		return
	end

	--show blue the task list
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePTS then
			BluePTS:show()
		else
			slmod.error('no BluePTS in slmod.show_task_list_net', true)
		end
	end
	
	--show red the task list
	if ((coa == 'red') or (coa == 'all')) then
		if RedPTS then
			RedPTS:show()
		else
			slmod.error('no RedPTS in slmod.show_task_list_net', true)
		end
	end
end


function slmod.set_PTS_list_output_net(display_time, display_mode, coa)
	if (not slmod.typeCheck({'number', {'string', 'nil'}, {'string', 'nil'}}, { display_time, display_mode, coa })) then
		slmod.error('invalid variable type in slmod.set_PTS_list_output_net', true)
		return
	end
	if ((type(display_mode) == 'string') and ((display_mode ~= 'chat') and (display_mode ~= 'text') and (display_mode ~= 'echo') and (display_mode ~= 'both'))) then
		slmod.error('invalid display_mode requested in slmod.set_PTS_list_output_net', true)
		return
	end
	if ((type(coa) == 'string') and ((coa ~= 'red') and (coa ~= 'blue') and (coa ~= 'all'))) then
		slmod.error('invalid coalition requested in slmod.set_PTS_list_output_net', true)
		return
	end	
	coa  = coa or 'all'
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPTS then
			if display_mode then
				RedPTS.options.display_mode = display_mode
			end
			RedPTS.options.display_time = display_time	
		else
			slmod.error('no RedPTS in slmod.set_PTS_list_output_net', true)
		end
	end
	
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePTS then
			if display_mode then
				BluePTS.options.display_mode = display_mode
			end
			BluePTS.options.display_time = display_time	
		else
			slmod.error('no BluePTS in slmod.set_PTS_list_output_net', true)
		end
	end
end


function slmod.set_PTS_task_output_net(display_time, display_mode, coa)
	if (not slmod.typeCheck({'number', {'string', 'nil'}, {'string', 'nil'}}, { display_time, display_mode, coa })) then
		slmod.error('invalid variable type in slmod.set_PTS_task_output_net', true)
		return
	end
	if ((type(display_mode) == 'string') and ((display_mode ~= 'chat') and (display_mode ~= 'text') and (display_mode ~= 'echo') and (display_mode ~= 'both'))) then
		slmod.error('invalid display_mode requested in slmod.set_PTS_task_output_net', true)
		return
	end
	if ((type(coa) == 'string') and ((coa ~= 'red') and (coa ~= 'blue') and (coa ~= 'all'))) then
		slmod.error('invalid coalition requested in slmod.set_PTS_task_output_net', true)
		return
	end
	coa  = coa or 'all'
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPTS then
			if display_mode then
				RedPTS.options.task_display_mode = display_mode
			end
			RedPTS.options.task_display_time = display_time	
		else
			slmod.error('no RedPTS in slmod.set_PTS_task_output_net', true)
		end
	end
	
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePTS then
			if display_mode then
				BluePTS.options.task_display_mode = display_mode
			end
			BluePTS.options.task_display_time = display_time	
		else
			slmod.error('no BluePTS in slmod.set_PTS_task_output_net', true)
		end
	end
	
end
-- End of PTS
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
-- OO Parallel Options System
function slmod.ResetPOS()  --reset the normal POS items, call this every SlmodReset
	
	if RedPOS then  --VERY MUCH necessary- need to remove ALL references everywhere to the old menus!
		RedPOS = RedPOS:destroy()
	end
	if BluePOS then
		BluePOS = BluePOS:destroy()
	end
	
	local showCmds = {
		[1] = {
			[1] = {  
				type = 'word',
				text = '-sol',
				required = true
			}
		},
		[2] = {  
			[1] = {
				type = 'word',
				text = 'show',
				required = true
			},
			[2] = {
				type = 'word',
				text = 'option',
				required = true
			},
			[3] = {
				type = 'word',
				text = 'list',
				required = true
			}
		}
	}
	local options = {}
	options.title = 'Options and Commands'
	--options.itemSelCmd_base = '-op'
	RedPOS = POSMenu.create(slmod.deepcopy(showCmds), {coa = 'red'}, slmod.deepcopy(options))   -- slmod.deepcopy might not always be appropriate for this use - are subtables copied too with slmod.deepcopy?
	BluePOS = POSMenu.create(slmod.deepcopy(showCmds), {coa = 'blue'}, slmod.deepcopy(options))

end


function slmod.add_option_net(coa, id, description, flag)
	if (not slmod.typeCheck({'string', 'number', 'string', 'number'}, { coa, id, description, flag })) then
		slmod.error('invalid variable type in slmod.add_option_net', true)
		return
	end	
	if flag < 0 then
		slmod.error('you cannot specify a negative flag for an add_option function.', true)
		return
	end	
	
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePOS then
			BluePOS:add_option(id, description, flag)
		else
			slmod.error('no BluePOS in slmod.add_option_net', true)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPOS then
			RedPOS:add_option(id, description, flag)
		else
			slmod.error('no RedPOS in slmod.add_option_net', true)
		end
	end
end


function slmod.remove_option_net(coa, id)
	if (not slmod.typeCheck({'string', 'number'}, { coa, id})) then
		slmod.error('invalid variable type in slmod.remove_option_net', true)
		return
	end
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePOS then
			BluePOS:removeById(id)
		else
			slmod.error('no BluePOS in slmod.remove_option_net', true)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPOS then
			RedPOS:removeById(id)
		else
			slmod.error('no RedPOS in slmod.remove_option_net', true)
		end
	end
end


function slmod.show_option_list_net(coa)
	if (not slmod.typeCheck({'string'}, { coa })) then
		slmod.error('invalid variable type in slmod.show_option_list_net', true)
		return
	end
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePOS then
			BluePOS:show()
		else
			slmod.error('no BluePOS in slmod.show_option_list_net', true)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPOS then
			RedPOS:show()
		else
			slmod.error('no RedPOS in slmod.show_option_list_net', true)
		end
	end
end


function slmod.set_POS_output_net(display_time, display_mode, coa)
	if (not slmod.typeCheck({'number', {'string', 'nil'}, {'string', 'nil'}}, {display_time, display_mode, coa})) then
		slmod.error('invalid variable type in slmod.set_POS_output_net', true)
		return
	end	
	coa = coa or 'all'
	
	if ((display_mode ~= 'echo') and (display_mode ~= 'chat') and (display_mode ~= 'text') and (display_mode ~= 'both') and (display_mode ~= nil)) then
		slmod.error('invalid display_mode specified for parallel options system output in slmod.set_POS_output_net', true)
		return
	end	
	
	if ((coa == 'blue') or (coa == 'all')) then
		if BluePOS then
			if display_time then
				BluePOS.options.display_time = display_time
			end
			if display_mode then
				BluePOS.options.display_mode = display_mode
			end
		else
			slmod.error('no BluePOS in slmod.set_POS_output_net', true)
		end
	end
	
	if ((coa == 'red') or (coa == 'all')) then
		if RedPOS then
			if display_time then
				RedPOS.options.display_time = display_time
			end
			if display_mode then
				RedPOS.options.display_mode = display_mode
			end
		else
			slmod.error('no RedPOS in slmod.set_POS_output_net', true)
		end
	end
end

--End of parallel options system
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--Flag manipulation and unit property/position

function slmod.create_units_LOS_server() 
	local units_LOS_server_string = [==[function units_LOS_server(unitset1_ids, altoffset1, unitset2_ids, altoffset2, checks, flag, radius)
	--net.log('units_LOS_server here1')
	local unitset1posits = {}
	local unitset2posits = {}

	--store all the unitset1 posits and indexes
	local unitset_counter = 1
	for k =1, #unitset1_ids do
		if ((unitset1_ids[k] ~= nil) and (type(unitset1_ids[k]) == 'number') and (Unit.isExist({ id_ = unitset1_ids[k] }) == true)) then
			--net.log('units_LOS_server: unitset1 unit exists, etc')
			unitset1posits[unitset_counter] = Unit.getPosition({ id_ = unitset1_ids[k] }).p
			unitset_counter =  unitset_counter + 1	
		
		end
	end
	
	unitset_counter = 1
	
	for k =1, #unitset2_ids do
		if ((unitset2_ids[k] ~= nil) and (type(unitset2_ids[k]) == 'number') and (Unit.isExist({ id_ = unitset2_ids[k] }) == true)) then
			--net.log('units_LOS_server: unitset2 unit exists, etc')
			unitset2posits[unitset_counter] = Unit.getPosition({ id_ = unitset2_ids[k] }).p
			unitset_counter =  unitset_counter + 1		
		end
	end

	local k = 1 --unitset1 index counter
	local n  --unitset2 counter
	local y1,x1,z1,y2,x2,z2, obstruction, m, t, yline, xline, zline, xpcheck, zpcheck
	
	--do for each of unitset1
	while k <= #unitset1posits do
		--Three spatial coordinate components of a UnitSet1 unit
		y1 = unitset1posits[k].y + altoffset1
		x1 = unitset1posits[k].x
		z1 = unitset1posits[k].z

		n = 1
		while n <= #unitset2posits do
				
			obstruction = false
			--Three spatial coordinate components of a UnitSet2 unit
			y2 = unitset2posits[n].y + altoffset2
			x2 = unitset2posits[n].x
			z2 = unitset2posits[n].z

			m = 1
			
			t = 0
			--check checks of ponits between the UnitSet1 unit and the
			--UnitSet2 unit.  If at any point there is a terrain obstruction, then
			--obstruction (initialized to false) will be set to true.
			--net.log('here2')
			if (radius and (((x2 - x1)^2 + (z2 - z1)^2)^0.5 > radius)) then
				obstruction = true  --not techinically an "obstruction", but logically the same
				--net.log('out of range')
			else
				--net.log('here3')
				while (t <= 1) do
			
					t =  m/checks 
							
					yline = y1 + (y2 - y1)*t	
					xline = x1 + (x2 - x1)*t		
					zline = z1 + (z2 - z1)*t
				
					--now do a terrain height @ position check
					xpcheck = xline
					zpcheck = zline
				
					pcheck = { x = xpcheck, y = zpcheck }
				
					yland = land.getHeight(pcheck)
				
					--If the land altitude is EVER greater than the 
					--line altitude, set obstruction to true
					
					if yland > yline then
						--net.log('here- obstruction')
						obstruction = true
						break
					end
					m = m + 1
				end --while (t <= 1) do
			end	
			--If obstruction remains false after all the checks
			--checks, then there must be a a line of sight between the 
			--unitset1 unit and the unitset2 unit, set LOS to true
			if obstruction == false then
				--net.log('units_LOS_server here2')
				trigger.action.setUserFlag(flag, true)
				return
			end	
			n = n + 1			
		end --while n <= #unitset2 do
		k = k + 1
	end --while k <= #unitset1 do
end]==]

	net.dostring_in('server', units_LOS_server_string)

end


--Detects line of sight
function slmod.units_LOS_net(unitset1, altoffset1, unitset2, altoffset2, flag, stopflag, interval, checks, radius)
	if stopflag == '' then
		stopflag = nil
	end
	if slmod.typeCheck({'table_s', 'number', 'table_s', 'number', 'number', {'number', 'nil'}, {'number', 'nil'}, {'number', 'nil'}, {'number', 'nil'}}, { unitset1, altoffset1, unitset2, altoffset2, flag, stopflag, interval, checks, radius }) == false then
		slmod.error('invalid variable type in slmod.units_LOS_net', true)
		return
	end
	
	if ((stopflag ~= nil) and (stopflag > 0) and slmod.flagIsTrue(stopflag)) then
		return
	end
	
	if not unitset1.processed then
		unitset1 = slmod.makeUnitTable(unitset1)
	end
	
	if not unitset2.processed then
		unitset2 = slmod.makeUnitTable(unitset2)
	end
	
	local unitset1_ids = {}
	local unitset2_ids = {}
	
	interval = interval or 1 --set to 1 if no interval specified
	stopflag = stopflag or -1 --set to -1 if no stopflag specified
	checks = checks or 1000
	----------------------------------------------------------------------------
	
	--new way, using slmod.activeUnitsByName (should be more efficient):
	for i = 1, #unitset1 do  -- create the id table for unitset1
		if type(slmod.activeUnitsByName) == 'table' then --just making sure
			if slmod.activeUnitsByName[unitset1[i]] and slmod.activeUnitsByName[unitset1[i]].id then  
				table.insert(unitset1_ids, slmod.activeUnitsByName[unitset1[i]].id)
			end
		end
	end
	
	for i = 1, #unitset2 do  -- create the id table for unitset1
		if type(slmod.activeUnitsByName) == 'table' then --just making sure
			if slmod.activeUnitsByName[unitset2[i]] and slmod.activeUnitsByName[unitset2[i]].id then  
				table.insert(unitset2_ids, slmod.activeUnitsByName[unitset2[i]].id)
			end
		end
	end
	----------------------------------------------------------------------------------
	
	
	if ((#unitset1_ids >= 1) and (#unitset2_ids >= 1)) then  -- if at least 1 unit exists in each

		local unitset1_ids_str, unitset2_ids_str
		local unitset1_ids_str_tbl = {}
		local unitset2_ids_str_tbl = {}	
		
		unitset1_ids_str_tbl[#unitset1_ids_str_tbl + 1] = '{'  --create the serialized tables for passage to server env, replace this with slmod.oneLineSerialize 
		
		for i = 1, #unitset1_ids do
			unitset1_ids_str_tbl[#unitset1_ids_str_tbl + 1] = tostring(unitset1_ids[i])
			unitset1_ids_str_tbl[#unitset1_ids_str_tbl + 1] = ','
		end
		unitset1_ids_str_tbl[#unitset1_ids_str_tbl + 1] = '}'
		unitset1_ids_str = table.concat(unitset1_ids_str_tbl)
			
			
		unitset2_ids_str_tbl[#unitset2_ids_str_tbl + 1] = '{'
		for i = 1, #unitset2_ids do
			unitset2_ids_str_tbl[#unitset2_ids_str_tbl + 1] = tostring(unitset2_ids[i])
			unitset2_ids_str_tbl[#unitset2_ids_str_tbl + 1] = ','
		end
		unitset2_ids_str_tbl[#unitset2_ids_str_tbl + 1] = '}'
		unitset2_ids_str = table.concat(unitset2_ids_str_tbl)
		
		-- call server-side function to find units_LOS and set flag.
		if radius then
			net.dostring_in('server', 'units_LOS_server(' .. unitset1_ids_str .. ', ' .. tostring(altoffset1) .. ', ' .. unitset2_ids_str .. ', ' .. tostring(altoffset2) .. ', ' .. tostring(checks) .. ', ' .. tostring(flag) .. ', ' .. tostring(radius) .. ')')

		else
			net.dostring_in('server', 'units_LOS_server(' .. unitset1_ids_str .. ', ' .. tostring(altoffset1) .. ', ' .. unitset2_ids_str .. ', ' .. tostring(altoffset2) .. ', ' .. tostring(checks) .. ', ' .. tostring(flag) .. ')')
		end
	end
	
	--Do another check for stopflag- perhaps stopflag could be the same as flag
	if ((stopflag > 0) and slmod.flagIsTrue(stopflag)) then
		return
	end
	
	--if an interval is specified, loop
	if interval > 0 then 
		slmod.scheduleFunction(slmod.units_LOS_net, {unitset1, altoffset1, unitset2, altoffset2, flag, stopflag, interval, checks, radius}, DCS.getModelTime() + interval)
	end
end


function slmod.rand_flags_on_net(startflag, endflag, prob)
	if (not slmod.typeCheck({'number', 'number', {'number', 'nil'}}, { startflag, endflag, prob })) then
		slmod.error('invalid variable type in slmod.rand_flags_on_net', true)
		return
	end
	if (startflag and endflag and (prob == nil)) then --only two vars specified
		prob = endflag
		endflag = startflag
	end
	--flag range check to avoid infinite loops and the like
	if ((startflag < 1) or (startflag > endflag)) then
		slmod.error('invalid flag range in slmod.rand_flags_on_net', true)
		return
	end
	if ((prob < 0) or (prob > 100)) then
		slmod.error('probability out of bounds (0 to 100) in slmod.rand_flags_on_net', true)
	end
	
	--modify randomseed and pop off several values, just to be sure...
	slmod.randseed = slmod.randseed + math.floor((math.random() - 0.5)*(os.time()- slmod.round(os.time(), -4))/4)
	math.randomseed(slmod.randseed)
	math.random()
	math.random()
	math.random()
	math.random()
	--ok hopefully that's good enough...
	
	startflag = math.floor(startflag)  --no decimal flags
	endflag = math.floor(endflag)
	
	local randval
	for flag = startflag, endflag do
		randval = math.random()*100
		if randval <= prob then
			--net.log('flag ' .. tostring(flag) .. ' turning on')
			net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
		end
	end
end


function slmod.rand_flag_choice_net(startflag, endflag)
	if (not slmod.typeCheck({'number', 'number'}, {startflag, endflag})) then
		slmod.error('invalid variable type in slmod.rand_flag_choice_net', true)
		return
	end

	--flag range check to avoid infinite loops and the like
	if ((startflag < 1) or (startflag > endflag)) then
		slmod.error('invalid flag range in slmod.rand_flag_choice_net', true)
		return
	end

	--modify randomseed and pop off several values, just to be sure...
	slmod.randseed = slmod.randseed + math.floor((math.random() - 0.5)*(os.time()- slmod.round(os.time(), -4))/4)
	math.randomseed(slmod.randseed)
	math.random()
	math.random()
	math.random()
	math.random()
	--ok hopefully that's good enough...
	
	startflag = math.floor(startflag)  --no decimal flags
	endflag = math.floor(endflag)
	
	local testval
	local maxval = -1
	local maxvalflag = -1
	for flag = startflag, endflag do
		testval = math.random()
		if testval > maxval then
			maxval = testval
			maxvalflag = flag
		end
	end
	net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(maxvalflag) .. ', true)')
end


function slmod.create_num_dead_gt_server()

	local num_dead_gt_server_string = [=[--server func for num_dead_gt
function num_dead_gt_server(units)
	local numdead = 0
	for unit_ind = 1, #units do
		if Unit.getByName(units[unit_ind]) == nil then
			numdead = numdead + 1
		end	
	end
	return tostring(numdead)
end]=]
	
	net.dostring_in('server', num_dead_gt_server_string)
end

function slmod.num_dead_gt_net(units, numdead, flag, stopflag)
	if stopflag == '' then
		stopflag = nil
	end
	if (not slmod.typeCheck({'table_s', 'number', 'number', {'number', 'nil'}}, { units, numdead, flag, stopflag })) then
		slmod.error('invalid variable type in slmod.num_dead_gt_net', true)
		return
	end	
	
	stopflag = stopflag or -1
	
	if not units.processed then
		units = slmod.makeUnitTable(units)
	end

	local ret_numdead, ret_err = net.dostring_in('server', 'return num_dead_gt_server(' .. slmod.oneLineSerialize(units) .. ')')

	if (ret_err and (tonumber(ret_numdead) > numdead)) then
		net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
	elseif ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		slmod.scheduleFunction(slmod.num_dead_gt_net, {units, numdead, flag, stopflag}, DCS.getModelTime() + 1)
	end
end


function slmod.create_units_in_moving_zones_server() 
	local units_in_moving_zones_server_string = [==[function units_in_moving_zones_server(units_ids, zone_units_ids, flag, radius, zone_type, req_num)
	-- assumes zone_type is already in 'sphere' or 'cylinder', and req_num is at least 1.
	local units_posits = {}
	local zone_units_posits = {}

	-- store all the units_ids posits & ids
	for k =1, #units_ids do
		if type(units_ids[k]) == 'number' and Unit.isExist({ id_ = units_ids[k] }) then
			units_posits[#units_posits + 1] = Unit.getPosition({ id_ = units_ids[k] }).p
		end
	end
	
	if #units_posits < req_num  then -- not enough units to satisfy req_num
		return
	end
	
	--store all the zone_units_ids posits & ids
	for k =1, #zone_units_ids do
		if type(zone_units_ids[k]) == 'number' and Unit.isExist({ id_ = zone_units_ids[k] }) then
			zone_units_posits[#zone_units_posits + 1] = Unit.getPosition({ id_ = zone_units_ids[k] }).p
		end
	end
	
	local num_in_zone = 0  --number in zone counter.
	for units_ind = 1, #units_posits do
		for zone_units_ind = 1, #zone_units_posits do
			if zone_type == 'cylinder' and (((units_posits[units_ind].x - zone_units_posits[zone_units_ind].x)^2 + (units_posits[units_ind].z - zone_units_posits[zone_units_ind].z)^2)^0.5 <= radius) then
				num_in_zone = num_in_zone + 1
				break
			elseif zone_type == 'sphere' and (((units_posits[units_ind].x - zone_units_posits[zone_units_ind].x)^2 + (units_posits[units_ind].y - zone_units_posits[zone_units_ind].y)^2 + (units_posits[units_ind].z - zone_units_posits[zone_units_ind].z)^2)^0.5) <= radius then
				num_in_zone = num_in_zone + 1
				break
			end
		end
		if num_in_zone >= req_num then
			trigger.action.setUserFlag(flag, true)
			return
		end
	end
end]==]

	local str, err = net.dostring_in('server', units_in_moving_zones_server_string)
	if not err then
		slmod.error('failed to create units_in_moving_zones_server, reason: ' .. tostring(str))
	end
end


-- Units in moving zones
function slmod.units_in_moving_zones_net(units, zone_units, radius, flag, stopflag, zone_type, req_num, interval)
	if stopflag == '' then
		stopflag = nil
	end
	if slmod.typeCheck({'table_s', 'table_s', 'number', 'number', {'number', 'nil'}, {'string', 'nil'}, {'number', 'nil'}, {'number', 'nil'}}, { units, zone_units, radius, flag, stopflag, zone_type, req_num, interval }) == false then
		slmod.error('invalid variable type in slmod.units_in_moving_zones_net', true)
		return
	end
	
	if ((stopflag ~= nil) and (stopflag > 0) and slmod.flagIsTrue(stopflag)) then
		return
	end
	
	if not units.processed then
		units = slmod.makeUnitTable(units)
	end
	
	if not zone_units.processed then
		zone_units = slmod.makeUnitTable(zone_units)
	end
	
	local units_ids = {}
	local zone_units_ids = {}
	
	zone_type = zone_type or 'cylinder'
	if zone_type == 'c' or zone_type == 'cylindrical' or zone_type == 'C' then
		zone_type = 'cylinder'
	end
	if zone_type == 's' or zone_type == 'spherical' or zone_type == 'S' then
		zone_type = 'sphere'
	end
	if zone_type ~= 'cylinder' and zone_type ~= 'sphere' then
		slmod.error('invalid zone_type in slmod.units_in_moving_zones_net', true)
	end
	
	req_num = req_num or 1
	interval = interval or 1 --set to 1 if no interval specified
	stopflag = stopflag or -1 --set to -1 if no stopflag specified

	for i = 1, #units do  -- create the id table for unitset1
		if type(slmod.activeUnitsByName) == 'table' then --just making sure
			if slmod.activeUnitsByName[units[i]] and slmod.activeUnitsByName[units[i]].id then  
				table.insert(units_ids, slmod.activeUnitsByName[units[i]].id)
			end
		end
	end
	
	for i = 1, #zone_units do  -- create the id table for unitset1
		if type(slmod.activeUnitsByName) == 'table' then --just making sure
			if slmod.activeUnitsByName[zone_units[i]] and slmod.activeUnitsByName[zone_units[i]].id then  
				table.insert(zone_units_ids, slmod.activeUnitsByName[zone_units[i]].id)
			end
		end
	end
	
	if ((#units_ids >= 1) and (#zone_units_ids >= 1)) then  -- if at least 1 unit exists in each
		local str, err = net.dostring_in('server', 'units_in_moving_zones_server(' .. slmod.oneLineSerialize(units_ids) .. ', ' .. slmod.oneLineSerialize(zone_units_ids) .. ', ' .. tostring(flag) .. ', ' .. tostring(radius) .. ', ' .. slmod.basicSerialize(zone_type) .. ', ' .. tostring(req_num) .. ')')
		if not err then
			slmod.error('units_in_moving_zones_server call failed, reason: ' .. tostring(str))
		end
	end
	
	if ((stopflag > 0) and slmod.flagIsTrue(stopflag)) then
		return
	end
	
	if interval > 0 then 
		slmod.scheduleFunction(slmod.units_in_moving_zones_net, {units, zone_units, radius, flag, stopflag, zone_type, req_num, interval}, DCS.getModelTime() + interval)
	end
end


function slmod.create_units_in_zones_server() 
	local units_in_zones_server_string = [==[function units_in_zones_server(units_ids, zones, flag, zone_type, req_num)
	-- assumes zone_type is already in 'sphere' or 'cylinder', and req_num is at least 1.
	local units_posits = {}

	-- store all the units_ids posits & ids
	for k =1, #units_ids do
		if type(units_ids[k]) == 'number' and Unit.isExist({ id_ = units_ids[k] }) then
			units_posits[#units_posits + 1] = Unit.getPosition({ id_ = units_ids[k] }).p
		end
	end
	
	if #units_posits < req_num  then -- not enough units to satisfy req_num
		return
	end
	
	
	local num_in_zone = 0  --number in zone counter.
	for units_ind = 1, #units_posits do
		for zones_ind = 1, #zones do
			if zone_type == 'sphere' then  --add land height value for sphere zone type
				local alt = land.getHeight({x = zones[zones_ind].x, y = zones[zones_ind].z})
				if alt then
					zones[zones_ind].y = alt
				end
			end
			if zone_type == 'cylinder' and (((units_posits[units_ind].x - zones[zones_ind].x)^2 + (units_posits[units_ind].z - zones[zones_ind].z)^2)^0.5 <= zones[zones_ind].radius) then
				num_in_zone = num_in_zone + 1
				break
			elseif zone_type == 'sphere' and (((units_posits[units_ind].x - zones[zones_ind].x)^2 + (units_posits[units_ind].y - zones[zones_ind].y)^2 + (units_posits[units_ind].z - zones[zones_ind].z)^2)^0.5 <= zones[zones_ind].radius) then
				num_in_zone = num_in_zone + 1
				break
			end
		end
		if num_in_zone >= req_num then
			trigger.action.setUserFlag(flag, true)
			return
		end
	end
end]==]

	local str, err = net.dostring_in('server', units_in_zones_server_string)
	if not err then
		slmod.error('failed to create units_in_zones_server, reason: ' .. tostring(str))
	end
end


-- Units in zones
function slmod.units_in_zones_net(units, zones, flag, stopflag, zone_type, req_num, interval)
	if stopflag == '' then
		stopflag = nil
	end
	if slmod.typeCheck({'table_s', 'table_s', 'number',  {'number', 'nil'}, {'string', 'nil'}, {'number', 'nil'}, {'number', 'nil'}}, { units, zones, flag, stopflag, zone_type, req_num, interval }) == false then
		slmod.error('invalid variable type in slmod.units_in_zones_net', true)
		return
	end
	
	if ((stopflag ~= nil) and (stopflag > 0) and slmod.flagIsTrue(stopflag)) then
		return
	end
	
	if not units.processed then
		units = slmod.makeUnitTable(units)
	end
	
	--create the table of zones
	local zone_tbl = {}
	for zone_ind = 1, #zones do
		local zone = slmod.getZoneByName(zones[zone_ind])
		if not zone then
			slmod.error('unable to find the zone named "' .. zones[zone_ind] .. '" in slmod.units_in_zones_net', true)
			return
		else  --ok, the zone WAS found.
			local new_zone = {}
			new_zone['x'] = zone.x
			new_zone['y'] = 0
			new_zone['z'] = zone.z
			new_zone['radius'] = zone.radius
			zone_tbl[#zone_tbl + 1] = new_zone
		end
	end

	local units_ids = {}

	zone_type = zone_type or 'cylinder'
	if zone_type == 'c' or zone_type == 'cylindrical' or zone_type == 'C' then
		zone_type = 'cylinder'
	end
	if zone_type == 's' or zone_type == 'spherical' or zone_type == 'S' then
		zone_type = 'sphere'
	end
	if zone_type ~= 'cylinder' and zone_type ~= 'sphere' then
		slmod.error('invalid zone_type in slmod.units_in_zones_net', true)
	end
	
	req_num = req_num or 1
	interval = interval or 1 --set to 1 if no interval specified
	stopflag = stopflag or -1 --set to -1 if no stopflag specified

	for i = 1, #units do  -- create the id table for unitset1
		if type(slmod.activeUnitsByName) == 'table' then --just making sure
			if slmod.activeUnitsByName[units[i]] and slmod.activeUnitsByName[units[i]].id then
				table.insert(units_ids, slmod.activeUnitsByName[units[i]].id)
			end
		end
	end
		
	if #units_ids >= 1 then  -- if at least 1 unit exists
		local str, err = net.dostring_in('server', 'units_in_zones_server(' .. slmod.oneLineSerialize(units_ids) .. ', ' .. slmod.oneLineSerialize(zone_tbl) .. ', ' .. tostring(flag) .. ', ' .. slmod.basicSerialize(zone_type) .. ', ' .. tostring(req_num) .. ')')
		if not err then
			slmod.error('units_in_zones_server call failed, reason: ' .. tostring(str))
		end
	end
	
	if ((stopflag > 0) and slmod.flagIsTrue(stopflag)) then
		return
	end
	
	if interval > 0 then 
		slmod.scheduleFunction(slmod.units_in_zones_net, {units, zones, flag, stopflag, zone_type, req_num, interval}, DCS.getModelTime() + interval)
	end
end

--End of unit property/postion, flag manipulation functions
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--Events-based functions

--Continuously tries to determine if map object has been destroyed, uses new events system
function slmod.mapobj_destroyed_net(id, flag, evnt_ind, percent, numdead)
	--Type-check for security:
	if (((type(id) ~= 'table') and (type(id) ~= 'number')) or (type(flag) ~= 'number') or ((type(percent) ~= 'number') and (type(percent) ~= 'nil' ))) then  --replace with the type check func
		slmod.error('invalid variable type in slmod.mapobj_destroyed_net', true)
		return
	end
	percent = percent or 0
	numdead = numdead or 0
	
	local total_ids
	local id_tbl = {}
	
	if type(id) == 'table' then
		total_ids = #id
		id_tbl = id
	else
		total_ids = 1
		id_tbl[1] = id
	end
	
	--if more than ids_req are killed, set flag
	local ids_req = (percent/100)*total_ids

	while (evnt_ind <= #slmod.events) do
		
		for id_ind = 1, #id_tbl do
			if ((slmod.events[evnt_ind]['type'] == 'dead') and (slmod.events[evnt_ind]['initiatorID'] == id_tbl[id_ind])) then
				numdead = numdead + 1
				if numdead > ids_req then
					net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
					return  -- break out, stop looping function.
				end
			end
		end

		evnt_ind = evnt_ind + 1
	end
	--Flag wasn't set, so call again later
	slmod.scheduleFunction(slmod.mapobj_destroyed_net, {id, flag, evnt_ind, percent, numdead}, DCS.getModelTime() + 1)
end

function slmod.mapobj_dead_in_zone_net(zone, flag, evnt_ind, tot_dead, stopflag, numdead)
	if stopflag == '' then
		stopflag = nil
	end
	--Type-check for security:
	if slmod.typeCheck({'string', 'number', 'number', 'number', {'number', 'nil'}, {'number', 'nil'}}, { zone, flag, evnt_ind, tot_dead, stopflag, numdead }) ~= true then
		slmod.error('invalid variable type in slmod.mapobj_dead_in_zone_net', true)
		return
	end
	
	local zone_tbl = slmod.getZoneByName(zone)

	if (((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) and zone_tbl) then
		stopflag = stopflag or -1
		tot_dead = tot_dead or 0
		numdead = numdead or 0
		if evnt_ind == -1 then
			evnt_ind = #slmod.events + 1 --start at NEXT event!
		end
		
		while (evnt_ind <= #slmod.events) do
			
			if ((slmod.events[evnt_ind]['type'] == 'dead') and (slmod.events[evnt_ind]['initiator'] == 'Building') and (slmod.activeUnits[slmod.events[evnt_ind]['initiatorID']] == nil)) then  --a building died

				local locstr, locstr_err = net.dostring_in('server', 'return slmod.oneLineSerialize(Unit.getPosition({ id_ = ' .. slmod.basicSerialize(slmod.events[evnt_ind]['initiatorID']) .. ' }).p)')	

				if locstr_err == true then
					local posTbl = slmod.deserializeValue('posTbl = ' .. locstr)
					if type(posTbl) == 'table' then --done successfully!
						
						if (((posTbl.x - zone_tbl.x)^2 + (posTbl.z - zone_tbl.z)^2)^0.5 <= zone_tbl.radius) then  --unit is dead in zone!
							tot_dead = tot_dead + 1
							if tot_dead > numdead then
								net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
								return  -- break out, stop looping function.
							end
						end
					end
				else
					slmod.error('unable to get building position in slmod.mapobj_dead_in_zone_net')
				end
			end
			evnt_ind = evnt_ind + 1
		end
		if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then --do another check just to be sure stopflag wasn't set by own function
			--schedule next check
			slmod.scheduleFunction(slmod.mapobj_dead_in_zone_net, {zone, flag, evnt_ind, tot_dead, stopflag, numdead}, DCS.getModelTime() + 1)
		end
	end
end


function slmod.units_hitting_net(init_units, tgt_units, flag, evnt_ind, stopflag, msg, display_units, display_time, display_mode, coa, mpname)
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if slmod.typeCheck({'table_s', 'table_s', 'number', 'number', {'number', 'nil'}, {'string', 'nil'}, {'string', 'nil'}, {'number', 'nil'}, {'string', 'nil'}, {'string', 'nil'}, {'boolean', 'nil'}}, { init_units, tgt_units, flag, evnt_ind, stopflag, msg, display_units, display_time, display_mode, coa, mpname }) ~= true then
		slmod.error('invalid variable type in slmod.units_hitting_net', true)--stopflag         --msg        --display_units    --display_time     --display_mode     --coa               --mpname
		return
	end
	if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		if mpname == nil then  -- cant do mpname = mpname or nil, as mpname could be false boolean!
			mpname = true
		end
		coa = coa or 'all'  --not yet used
		
		stopflag = stopflag or -1
		
		if evnt_ind == -1 then -- -1 is the start condition for evnt_ind
			evnt_ind = #slmod.events + 1  -- start at NEXT event!
		end
		
		if msg then
			display_time = display_time or 5
			display_mode = display_mode or 'echo'
			display_units = display_units or ''
		end
		
		if not init_units.processed then
			init_units = slmod.makeUnitTable(init_units)
		end
		
		if not tgt_units.processed then
			tgt_units = slmod.makeUnitTable(tgt_units)
		end
		
		while evnt_ind <= #slmod.events do
			for tgt_units_ind = 1, #tgt_units do
				for init_units_ind = 1, #init_units do	
					if ((slmod.events[evnt_ind]['type'] == 'hit') and (slmod.events[evnt_ind]['target_name'] == tgt_units[tgt_units_ind]) and (slmod.events[evnt_ind]['initiator_name'] == init_units[init_units_ind])) then
						-- a match has been found with parameters.
						net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
						if msg then
							local init_unit_name, tgt_unit_name
							if mpname then
								if slmod.getUnitByName(init_units[init_units_ind]) then
									init_unit_name = slmod.getUnitByName(init_units[init_units_ind]).mpname or '!unknown unit!'
								else
									init_unit_name = '!unknown unit!'
								end
								if slmod.getUnitByName(tgt_units[tgt_units_ind]) then
									tgt_unit_name = slmod.getUnitByName(tgt_units[tgt_units_ind]).mpname or '!unknown unit!'
								else
									tgt_unit_name = '!unknown unit!'
								end
								-- init_unit_name = slmod.getUnitByName(init_units[init_units_ind]).mpname or '!unknown unit!' --potential problem: slmod.getUnitByName returns nil!
								-- tgt_unit_name = slmod.getUnitByName(tgt_units[tgt_units_ind]).mpname or '!unknown unit!'
							else
								if slmod.getUnitByName(init_units[init_units_ind]) then
									init_unit_name = slmod.getUnitByName(init_units[init_units_ind]).name or '!unknown unit!'
								else
									init_unit_name = '!unknown unit!'
								end
								if slmod.getUnitByName(tgt_units[tgt_units_ind]) then
									tgt_unit_name = slmod.getUnitByName(tgt_units[tgt_units_ind]).name or '!unknown unit!'
								else
									tgt_unit_name = '!unknown unit!'
								end
								-- init_unit_name = slmod.getUnitByName(init_units[init_units_ind]).name or '!unknown unit!'
								-- tgt_unit_name = slmod.getUnitByName(tgt_units[tgt_units_ind]).name or '!unknown unit!'
							end
							if display_units == 't' then
								slmod.msg_out_net(string.format(msg, tgt_unit_name), display_time, display_mode, coa) 
							elseif display_units == 'i' then
								slmod.msg_out_net(string.format(msg, init_unit_name), display_time, display_mode, coa)
							elseif display_units == 'it' then
								slmod.msg_out_net(string.format(msg, init_unit_name, tgt_unit_name), display_time, display_mode, coa)
							elseif display_units == 'ti' then
								slmod.msg_out_net(string.format(msg, tgt_unit_name, init_unit_name), display_time, display_mode, coa)
							else
								slmod.msg_out_net(msg, display_time, display_mode, coa)
							end
						end
					end
				end
			end
			evnt_ind = evnt_ind + 1
		end
		if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
			if msg then -- a message
				slmod.scheduleFunction(slmod.units_hitting_net, {init_units, tgt_units, flag, evnt_ind, stopflag, msg, display_units, display_time, display_mode, coa, mpname}, DCS.getModelTime() + 1)
			else -- no message
				slmod.scheduleFunction(slmod.units_hitting_net, {init_units, tgt_units, flag, evnt_ind, stopflag}, DCS.getModelTime() + 1)
			end
		end
	end
end

--[[
Some weapon names, as named in the events system (1.1.1.0, may have changed in time since):
"GAU8_30_AP"
"GAU8_30_HE"

"CBU_87"
"CBU_97"
"CBU_103"
"CBU_105"

"GBU_10"
"GBU_12"
"GBU-31"
"GBU-38"
"Mk_82"
"MK_82AIR"
"Mk_84"

"AGM-65D Maverick"
"AGM-65H Maverick"
"AGM-65G Maverick"
"AGM-65K Maverick"

"HYDRA-70MK5"
"HYDRA-70MK1"
"HYDRA_70_M274"
"HYDRA_70_MK61"
"HYDRA-70WTU1B"
"HYDRA-70M257"
"HYDRA_70_M151"
"HYDRA_70_M156"

"AIM-9M"
"AIM-120B"
"AIM-120C" 
"AIM-7M"
"AGM-88 HARM"
]]--
function slmod.units_firing_net(init_units, flag, evnt_ind, stopflag, weapons, msg, display_units, display_time, display_mode, coa, mpname)
	if stopflag == '' then
		stopflag = nil
	end
	if slmod.typeCheck({'table_s', 'number', 'number', {'number', 'nil'}, {'table_s', 'nil'}, {'string', 'nil'}, {'string', 'nil'}, {'number', 'nil'}, {'string', 'nil'}, {'string', 'nil'}, {'boolean', 'nil'}}, { init_units, flag, evnt_ind, stopflag, weapons, msg, display_units, display_time, display_mode, coa, mpname }) ~= true then
														--stopflag			--weapons			--msg			--display_units		--display_time		--display_mode	  --coa                 --mpname
		slmod.error('invalid variable type in slmod.units_firing_net', true)
		return
	end
	if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		stopflag = stopflag or -1
		display_time = display_time or 5
		display_mode = display_mode or 'echo'
		display_units = display_units or ''
		
		if ((weapons == nil) or (#weapons == 0)) then
			weapons = {'all'}
		end
		
		coa = coa or 'all'
		
		if mpname == nil then  -- cant do mpname = mpname or nil, as mpname could be false boolean!
			mpname = true
		end

		if evnt_ind == -1 then
			evnt_ind = #slmod.events + 1  -- start at next event!
		end
		
		if not init_units.processed then
			init_units = slmod.makeUnitTable(init_units)
		end
		
		while (evnt_ind <= #slmod.events) do
			if ((slmod.events[evnt_ind]['type'] == 'shot') and (slmod.events[evnt_ind]['initiator_name'] ~= nil)) then  --something was fired and that something has a slmod events name
				for init_ind = 1, #init_units do
					if (slmod.events[evnt_ind]['initiator_name'] == init_units[init_ind]) then  --an init_unit fired something
						local match_found =  false
						
						if weapons[1] == 'all' then
							match_found = true
						else
							for weapon_ind = 1, #weapons do
								if weapons[weapon_ind] == slmod.events[evnt_ind]['weapon'] then
									match_found = true
									break
								end
							end
						end
						
						--now, if match_found remains false, then no weapons match, otherwise, need to output a message
						if match_found then
							-- a match has been found with parameters.
							net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
							if msg then
							
								local init_unit_name, weapon_name
								local init_u_tbl = slmod.getUnitByName(init_units[init_ind])
								if init_u_tbl then
									if mpname then
										init_unit_name = init_u_tbl.mpname
									else
										init_unit_name = init_u_tbl.name
									end
								else
									init_unit_name = '!unknown unit!'
								end

								weapon_name = slmod.events[evnt_ind]['weapon'] or '!unknown weapon!'
								
								if display_units == 'i' then
									slmod.msg_out_net(string.format(msg, init_unit_name), display_time, display_mode, coa) 
								elseif display_units == 'w' then
									slmod.msg_out_net(string.format(msg, weapon_name), display_time, display_mode, coa)
								elseif display_units == 'iw' then
									slmod.msg_out_net(string.format(msg, init_unit_name, weapon_name), display_time, display_mode, coa)
								elseif display_units == 'wi' then
									slmod.msg_out_net(string.format(msg, weapon_name, init_unit_name), display_time, display_mode, coa)
								else
									msg_out_net(msg, display_time, display_mode, coa)
								end
							end
						end
						
					end --if (slmod.events[evnt_ind]['name'] == init_units[init_ind]) then  --an init_unit fired something
					
				end --for init_ind = 1, #init_units do
			end	--if ((slmod.events[evnt_ind]['type'] == 'shot') and (slmod.events[evnt_ind]['name'] ~= nil)) then  --something was fired and that something has a slmod events name
			evnt_ind = evnt_ind + 1
		end	 --while (evnt_ind <= #slmod.events) do
		if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
			if msg then -- a message
				slmod.scheduleFunction(slmod.units_firing_net, {init_units, flag, evnt_ind, stopflag, weapons, msg, display_units, display_time, display_mode, coa, mpname}, DCS.getModelTime() + 1)
			else -- no message
				slmod.scheduleFunction(slmod.units_firing_net, {init_units, flag, evnt_ind, stopflag, weapons}, DCS.getModelTime() + 1)
			end
		end
	end
end


function slmod.units_crashed_net(units, flag, evnt_ind, stopflag)
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if slmod.typeCheck({'table_s', 'number', 'number', {'number', 'nil'}}, {units,  flag, evnt_ind, stopflag} ) ~= true then
		slmod.error('invalid variable type in slmod.units_crashed_net', true)
		return
	end
	if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		
		stopflag = stopflag or -1
		
		if evnt_ind == -1 then -- -1 is the start condition for evnt_ind
			evnt_ind = #slmod.events + 1  -- start at NEXT event!
		end
		
		if not units.processed then
			units = slmod.makeUnitTable(units)
		end
		
		while evnt_ind <= #slmod.events do
			for units_ind = 1, #units do	
				if ((slmod.events[evnt_ind]['type'] == 'crash') and (slmod.events[evnt_ind]['initiator'] == units[units_ind])) then
					-- a match has been found with parameters.
					net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
				end
			end
			evnt_ind = evnt_ind + 1
		end
		if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
			slmod.scheduleFunction(slmod.units_crashed_net, {units, flag, evnt_ind, stopflag}, DCS.getModelTime() + 1)
		end
	end
end


function slmod.units_ejected_net(units, flag, evnt_ind, stopflag)
	-- do some type checking to be safe...
	if slmod.typeCheck({'table_s', 'number', 'number', {'number', 'nil'}}, {units,  flag, evnt_ind, stopflag}) ~= true then
		slmod.error('invalid variable type in slmod.units_ejected_net', true)
		return
	end
	if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		
		stopflag = stopflag or -1
		
		if evnt_ind == -1 then -- -1 is the start condition for evnt_ind
			evnt_ind = #slmod.events + 1  -- start at NEXT event!
		end
		
		if not units.processed then
			units = slmod.makeUnitTable(units)
		end
		
		while evnt_ind <= #slmod.events do
			for units_ind = 1, #units do	
				if ((slmod.events[evnt_ind]['type'] == 'eject') and (slmod.events[evnt_ind]['initiator'] == units[units_ind])) then
					-- a match has been found with parameters.
					net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
				end
			end
			evnt_ind = evnt_ind + 1
		end
		if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
			slmod.scheduleFunction(slmod.units_ejected_net, {units, flag, evnt_ind, stopflag}, DCS.getModelTime() + 1)
		end
	end
end


function slmod.pilots_dead_net(units, flag, evnt_ind, stopflag)
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if slmod.typeCheck({'table_s', 'number', 'number', {'number', 'nil'}}, {units,  flag, evnt_ind, stopflag}) ~= true then
		slmod.error('invalid variable type in slmod.pilots_dead_net', true)
		return
	end
	if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		
		stopflag = stopflag or -1
		
		if evnt_ind == -1 then -- -1 is the start condition for evnt_ind
			evnt_ind = #slmod.events + 1  -- start at NEXT event!
		end
		
		if not units.processed then
			units = slmod.makeUnitTable(units)
		end
		
		while evnt_ind <= #slmod.events do
			for units_ind = 1, #units do	
				if ((slmod.events[evnt_ind]['type'] == 'pilot dead') and (slmod.events[evnt_ind]['initiator'] == units[units_ind])) then
					-- a match has been found with parameters.
					net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
				end
			end
			evnt_ind = evnt_ind + 1
		end
		if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
			slmod.scheduleFunction(slmod.pilots_dead_net, {units, flag, evnt_ind, stopflag}, DCS.getModelTime() + 1)
		end
	end
end


function slmod.units_killed_by_net(dead_units, killer_units, flag, dead_ind, stopflag, last_to_hit, time_limit)   --last to hit- number value.  If nil or <1, then any unit ever to hit this unit is considered a killer.  if a positive value, the only the last last_to_hit units that hit this unit are considered killers.
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if slmod.typeCheck({'table_s', 'table_s', 'number', 'number', {'number', 'nil'}, {'number', 'nil'}, {'number', 'nil'}}, {dead_units, killer_units, flag, dead_ind, stopflag, last_to_hit, time_limit}) ~= true then
		slmod.error('Slmod: invalid variable input in slmod.units_killed_by_net')--stopflag     --last_to_hit   --time_limit
		return
	end
	
	if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then
		
		stopflag = stopflag or -1
		
		if not dead_units.processed then
			dead_units = slmod.makeUnitTable(dead_units)
		end

		if not killer_units.processed then
			killer_units = slmod.makeUnitTable(killer_units)
		end		
		
		local mission_time
		if time_limit then
			mission_time = slmod.getMissionTime()
		end
		
		if dead_ind == -1 then -- -1 is the start condition for dead_ind
			dead_ind  = #slmod.deadUnits + 1  -- start at NEXT killed unit
		end
		local lslmod_dead_units = slmod.deadUnits  --local reference because it's supposedly faster.
		
		-- example: slmod.deadUnits[1] =  { killed_unit = 't-80_1', killers = {'client1', 'm1_1'}, hit_times = { 44224.55, 44125.76 }}
		
		while dead_ind  <= #lslmod_dead_units do
			for dead_units_ind = 1, #dead_units do
				if lslmod_dead_units[dead_ind].killed_unit == dead_units[dead_units_ind] then -- one of the units that we are looking for died
					for killer_units_ind = 1, #killer_units do --now, cycle through the list of killer units
						local max_ind
						if not last_to_hit or last_to_hit < 1 or math.floor(last_to_hit) >= #lslmod_dead_units[dead_ind].killers then
							max_ind = #lslmod_dead_units[dead_ind].killers
						else  -- last to hit defined and > 1
							max_ind = math.floor(last_to_hit)  -- max_ind will NOT be > than #lslmod_dead_units[dead_ind].killers- check
						end
						for killers_ind = 1, max_ind do --NOW look through the list of killers of this unit
							if lslmod_dead_units[dead_ind].killers[killers_ind] == killer_units[killer_units_ind] then -- if this killer_unit was one of the last max_ind killers to hit the dead_unit
								if time_limit then
									if (mission_time - lslmod_dead_units[dead_ind].hit_times[killers_ind]) < time_limit then  --if time_limit exists and this hit was made within the time_limit
										net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
									end
								else --no time_limit
									net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(flag) .. ', true)')
								end
							end
						end
					end
				end
			end
			dead_ind = dead_ind + 1
		end
		if ((stopflag == nil) or (stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then  --schecule the next check!
			slmod.scheduleFunction(slmod.units_killed_by_net, {dead_units, killer_units, flag, dead_ind, stopflag, last_to_hit, time_limit}, DCS.getModelTime() + 1)
		end
	end
end

--End of events-based functions
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
-- Weapons tracking functions:

 -- function that is called periodically to check if a weapon_in_zones type function has expired.
 -- used for weapons_impacting_in_zones, weapons_impacting_in_moving_zones, weapons_in_zones, weapons_in_moving_zones
function slmod.weapons_in_zones_checker(checks_tbl, stopflag) -- function that is called periodically to check if a weapon_in_zones type function has expired.
	if slmod.flagIsTrue(stopflag) then -- stopflag is now true, remove checks_tbl from track_weapons_for_byname
		local str, err = net.dostring_in('server', 'slmod.add_to_track_weapons_for_byname(' .. slmod.oneLineSerialize(checks_tbl) .. ', false)')
		if not err then
			slmod.error('unable to slmod.add_to_track_weapons_for_byname, reason: ' .. str)
		end
	else  --stopflag not true, schedule a future function run.
		slmod.scheduleFunction(slmod.weapons_in_zones_checker, {checks_tbl, stopflag}, DCS.getModelTime() + 1)
	end
end


function slmod.weapons_impacting_in_zones_net(init_units, zones, weapons, flag, stopflag)   
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if not slmod.typeCheck({{'string', 'table_s'}, {'string', 'table_s'}, {'table_s', 'string'}, 'number', {'number', 'nil'}}, {init_units, zones, weapons, flag, stopflag}) then
		slmod.error('invalid variable type in slmod.weapons_impacting_in_zones_net', true)
		return
	end
		
	stopflag = stopflag or -1
	-----------------------------------------------------------------
	--Allowing people to put a single string instead...
	if type(weapons) == 'string' then
		weapons = {weapons}
	end
	
	if type(zones) == 'string' then
		zones = {zones}
	end
	
	if type(init_units) == 'string' then
		init_units = {init_units}
	end
	------------------------------------------------------------------
	init_units = slmod.makeUnitTable(init_units)

	if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then -- this is the first time the function is run, and stopflag was either not specified, or is false.  Need to add track_weapons_for_byname in server env.
		
		--need to assemble the table to be passed to server env...
		local checks_tbl = {}
		for unit_ind = 1, #init_units do
			checks_tbl[init_units[unit_ind]] = {}
			for weapon_ind = 1, #weapons do
				checks_tbl[init_units[unit_ind]][weapons[weapon_ind]] = {}
				for zone_ind = 1, #zones do
					local zone = slmod.getZoneByName(zones[zone_ind])
					if not zone then
						slmod.error('unable to find the zone named "' .. zones[zone_ind] .. '" in slmod.weapons_impacting_in_zones_net', true)
						return
					else  --ok, the zone WAS found.
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind] = {}
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['type'] = 'zone'
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['zone_name'] = zone.name
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['x'] = zone.x
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['z'] = zone.z
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['check_type'] = 'impacting_in_zone'
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['radius'] = zone.radius
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['flag'] = flag
					end
				end		
			end
		end
		--checks_tbl now populated...
		net.dostring_in('server', 'slmod.add_to_track_weapons_for_byname(' .. slmod.oneLineSerialize(checks_tbl) .. ', true)')
		if stopflag ~= -1 then
			-- start the checker for stopflag.
			slmod.scheduleFunction(slmod.weapons_in_zones_checker, {checks_tbl, stopflag}, DCS.getModelTime() + 1)
		end
	end
end


function slmod.weapons_impacting_in_moving_zones_net(init_units, zone_units, radius, weapons, flag, stopflag)   
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if not slmod.typeCheck({{'string', 'table_s'}, {'string', 'table_s'}, 'number', {'string', 'table_s'}, 'number', {'number', 'nil'}}, {init_units, zone_units, radius, weapons, flag, stopflag}) then
		slmod.error('invalid variable type in slmod.weapons_impacting_in_moving_zones_net', true)
		return
	end
		
	stopflag = stopflag or -1
	
	-----------------------------------------------------------------
	--Allowing people to put a single string instead...
	if type(weapons) == 'string' then
		weapons = {weapons}
	end
	
	if type(zone_units) == 'string' then
		zone_units = {zone_units}
	end
	
	if type(init_units) == 'string' then
		init_units = {init_units}
	end
	------------------------------------------------------------------	
		
	init_units = slmod.makeUnitTable(init_units)
	zone_units = slmod.makeUnitTable(zone_units)
	
	if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then -- this is the first time the function is run, and stopflag was either not specified, or is false.  Need to add track_weapons_for_byname in server env.
		
		--need to assemble the table to be passed to server env...
		local checks_tbl = {}
		for unit_ind = 1, #init_units do
			checks_tbl[init_units[unit_ind]] = {}
			for weapon_ind = 1, #weapons do
				checks_tbl[init_units[unit_ind]][weapons[weapon_ind]] = {}
				for zone_unit_ind = 1, #zone_units do
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind] = {}
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['type'] = 'moving_zone'
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['unit_name'] = zone_units[zone_unit_ind]
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['check_type'] = 'impacting_in_zone'
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['radius'] = radius
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['flag'] = flag
				end		
			end
		end
		--checks_tbl now populated...
		net.dostring_in('server', 'slmod.add_to_track_weapons_for_byname(' .. slmod.oneLineSerialize(checks_tbl) .. ', true)')
		if stopflag ~= -1 then
			-- start the checker for stopflag.
			slmod.scheduleFunction(slmod.weapons_in_zones_checker, {checks_tbl, stopflag}, DCS.getModelTime() + 1)
		end

	end
end


function slmod.weapons_in_zones_net(init_units, zones, weapons, flag, stopflag, zone_type)   
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if not slmod.typeCheck({{'string', 'table_s'}, {'string', 'table_s'}, {'table_s', 'string'}, 'number', {'number', 'nil'}, {'string', 'nil'}}, {init_units, zones, weapons, flag, stopflag, zone_type}) then
		slmod.error('invalid variable type in slmod.weapons_in_zones_net', true)
		return
	end
		
	stopflag = stopflag or -1
	
	zone_type = zone_type or 'cylinder'
	if zone_type == 'c' or zone_type == 'cylindrical' or zone_type == 'C' then
		zone_type = 'cylinder'
	end
	if zone_type == 's' or zone_type == 'spherical' or zone_type == 'S' then
		zone_type = 'sphere'
	end
	if zone_type ~= 'cylinder' and zone_type ~= 'sphere' then
		slmod.error('invalid zone_type in slmod.weapons_in_zones_net', true)
	end
	
	-----------------------------------------------------------------
	--Allowing people to put a single string instead...
	if type(weapons) == 'string' then
		weapons = {weapons}
	end
	
	if type(zones) == 'string' then
		zones = {zones}
	end
	
	if type(init_units) == 'string' then
		init_units = {init_units}
	end
	------------------------------------------------------------------
	init_units = slmod.makeUnitTable(init_units)

	if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then -- this is the first time the function is run, and stopflag was either not specified, or is false.  Need to add track_weapons_for_byname in server env.
		
		--need to assemble the table to be passed to server env...
		local checks_tbl = {}
		for unit_ind = 1, #init_units do
			checks_tbl[init_units[unit_ind]] = {}
			for weapon_ind = 1, #weapons do
				checks_tbl[init_units[unit_ind]][weapons[weapon_ind]] = {}
				for zone_ind = 1, #zones do
					local zone = slmod.getZoneByName(zones[zone_ind])
					if not zone then
						slmod.error('Slmod error: unable to find the zone named "' .. zones[zone_ind] .. '" in slmod.weapons_in_zones_net')
						return
					else  --ok, the zone WAS found.
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind] = {}
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['type'] = 'zone'
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['zone_name'] = zone.name
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['x'] = zone.x
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['z'] = zone.z
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['zone_type'] = zone_type
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['check_type'] = 'in_zone'
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['radius'] = zone.radius
						checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_ind]['flag'] = flag
					end
				end		
			end
		end
		--checks_tbl now populated...
		net.dostring_in('server', 'slmod.add_to_track_weapons_for_byname(' .. slmod.oneLineSerialize(checks_tbl) .. ', true)')
		if stopflag ~= -1 then
			-- start the checker for stopflag.
			slmod.scheduleFunction(slmod.weapons_in_zones_checker, {checks_tbl, stopflag}, DCS.getModelTime() + 1)
		end

	end
end


function slmod.weapons_in_moving_zones_net(init_units, zone_units, radius, weapons, flag, stopflag, zone_type)   
	if stopflag == '' then
		stopflag = nil
	end
	-- do some type checking to be safe...
	if not slmod.typeCheck({{'string', 'table_s'}, {'string', 'table_s'}, 'number', {'string', 'table_s'}, 'number', {'number', 'nil'}, {'string', 'nil'}}, {init_units, zone_units, radius, weapons, flag, stopflag, zone_type}) then
		slmod.error('invalid variable type in slmod.weapons_in_moving_zones_net', true)
		return
	end
		
	stopflag = stopflag or -1
	
	zone_type = zone_type or 'sphere'  -- use sphere for this default.
	if zone_type == 'c' or zone_type == 'cylindrical' or zone_type == 'C' then
		zone_type = 'cylinder'
	end
	if zone_type == 's' or zone_type == 'spherical' or zone_type == 'S' then
		zone_type = 'sphere'
	end
	if zone_type ~= 'cylinder' and zone_type ~= 'sphere' then
		slmod.error('invalid zone_type in slmod.weapons_in_moving_zones_net', true)
	end
	
	-----------------------------------------------------------------
	--Allowing people to put a single string instead...
	if type(weapons) == 'string' then
		weapons = {weapons}
	end
	
	if type(zone_units) == 'string' then
		zone_units = {zone_units}
	end
	
	if type(init_units) == 'string' then
		init_units = {init_units}
	end
	------------------------------------------------------------------	
		
	init_units = slmod.makeUnitTable(init_units)
	zone_units = slmod.makeUnitTable(zone_units)
	
	if ((stopflag == -1) or (not slmod.flagIsTrue(stopflag))) then -- this is the first time the function is run, and stopflag was either not specified, or is false.  Need to add track_weapons_for_byname in server env.
		
		--need to assemble the table to be passed to server env...
		local checks_tbl = {}
		for unit_ind = 1, #init_units do
			checks_tbl[init_units[unit_ind]] = {}
			for weapon_ind = 1, #weapons do
				checks_tbl[init_units[unit_ind]][weapons[weapon_ind]] = {}
				for zone_unit_ind = 1, #zone_units do
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind] = {}
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['type'] = 'moving_zone'
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['unit_name'] = zone_units[zone_unit_ind]
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['check_type'] = 'in_zone'
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['radius'] = radius
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['zone_type'] = zone_type
					checks_tbl[init_units[unit_ind]][weapons[weapon_ind]][zone_unit_ind]['flag'] = flag
				end		
			end
		end
		--checks_tbl now populated...
		net.dostring_in('server', 'slmod.add_to_track_weapons_for_byname(' .. slmod.oneLineSerialize(checks_tbl) .. ', true)')
		if stopflag ~= -1 then
			-- start the checker for stopflag.
			slmod.scheduleFunction(slmod.weapons_in_zones_checker, {checks_tbl, stopflag}, DCS.getModelTime() + 1)
		end

	end
end


-- end of weapons tracking functions
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
-- Testing funcs

--the dump _Gs function...
function slmod.dump_Gs_net(ScriptRuntime_G, MissionScripting_G)
	if (not slmod.typeCheck({{'string', 'nil'}, {'string', 'nil'}}, { ScriptRuntime_G, MissionScripting_G })) then
		slmod.error('invalid variable type in slmod.dump_Gs_net', true)
		return
	end
	--First, write the mission scripting _Gs:
	--Initial mission scripting _G
	if MissionScripting_G then
		local msi_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'MissionScripting.lua initial env _G.txt', 'w')
		msi_G_f:write(MissionScripting_G)
		msi_G_f:close()
	end
	
	--Runtime mission scripting _G
	if ScriptRuntime_G then
		local msr_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'MissionScripting.lua runtime env _G.txt', 'w')
		msr_G_f:write(ScriptRuntime_G)
		msr_G_f:close()
	end
	
	--Now five other environments:
	--net
	local net_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'net env _G.txt', 'w')
	net_G_f:write(slmod.tableshow(_G, '["_G"]'))
	net_G_f:close()	
	
	--mission
	local mis_G_s, err = net.dostring_in('mission', 'return slmod.tableshow(_G, \'["_G"]\')')
	if err then
		local mis_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'mission env _G.txt', 'w')
		mis_G_f:write(mis_G_s)
		mis_G_f:close()
	else
		slmod.error('unable to obtain mission environment _G in slmod.dump_Gs_net, reason: ' ..  mis_G_s, true)
	end
	
	-- server
	local serv_G_s, err = net.dostring_in('server', 'return slmod.tableshow(_G, \'["_G"]\')')
	if err then
		local serv_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'server env _G.txt', 'w')
		serv_G_f:write(serv_G_s)
		serv_G_f:close()
	else
		slmod.error('unable to obtain server environment _G in slmod.dump_Gs_net, reason: ' .. serv_G_s, true)
	end
	
	-- export
	local exp_G_s, err = net.dostring_in('export', 'return slmod.tableshow(_G, \'["_G"]\')')
	if err then
		local exp_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'export env _G.txt', 'w')
		exp_G_f:write(exp_G_s)
		exp_G_f:close()
	else
		slmod.error('unable to obtain export environment _G in slmod.dump_Gs_net, reason: ' .. exp_G_s, true)
	end
	
	-- config
	local conf_G_s, err = net.dostring_in('config', 'return slmod.tableshow(_G, \'["_G"]\')')
	if err then
		local conf_G_f = io.open(lfs.writedir() .. [[Logs\]] .. 'config env _G.txt', 'w')
		conf_G_f:write(conf_G_s)
		conf_G_f:close()
	else
		slmod.error('unable to obtain config environment _G in slmod.dump_Gs_net, reason: ' .. conf_G_s, true)
	end
	
end
--End of testing functions
------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------
function slmod.reset()

	slmod.reset_dostring_table()
	
	slmod.resetScheduledFunctions()
	
	slmod.chat_table = {}
	
	slmod.activeUnits = {}

	slmod.oldActiveUnits = {}
	
	slmod.activeUnitsByName = {}
	
	slmod.oldActiveUnitsByName = {}
	
	slmod.next_event_ind = nil
	
	if slmod.eventsFile then
		slmod.eventsFile:close()
	end
	slmod.eventsFile = nil

	slmod.events = {}
	
	slmod.deadUnits = {}
	
	--ls_res = {}

	--ls_strng_list = {}
	
	slmod.me_zones = nil
	
	slmod.recvData = {}
	slmod.recvCmds = {}
	slmod.recvDataCntr = 1

	-----------------------------------------------
	-- load functions
	slmod.create_basicSerialize()

	slmod.create_round()

	slmod.create_msg_MGRS_server()
	
	slmod.create_LLtoLO()
	
	--create_GetExportUnits()
	--create_GetMissionUnits()
	slmod.create_units_LOS_server()
	
	slmod.create_serialize()
	slmod.create_oneLineSerialize()
	slmod.create_serializeWithCycles()
	slmod.create_deepcopy()
	slmod.create_getNextSlmodEvents()

	slmod.create_num_dead_gt_server()
	
	slmod.create_tableshow()
	
	--slmod.create_getGroupIdByGroupName()
	slmod.create_DebugScripts()
	slmod.create_getUnitXYZ()
	slmod.create_getMissionUnitData()
	slmod.create_coord()
	
	slmod.create_get_coords_msg_string()
	slmod.create_get_leading_msg_string()
	
	slmod.create_units_in_moving_zones_server()

	slmod.create_units_in_zones_server() 
	
	if slmod.ConvMenu then
		slmod.ConvMenu:destroy()
		slmod.ConvMenu = nil
	end
	if slmod.config.coord_converter then
		slmod.create_ConvMenu()
	end
	
	if SlmodAdminMenu then
		SlmodAdminMenu.destroyIdBanMenu()
		SlmodAdminMenu:destroy()
		SlmodAdminMenu = nil
	end
	if slmod.config.admin_tools then
		slmod.create_SlmodAdminMenu()
	end
	
    slmod.loadPingExemptList()
	slmod.create_getUnitAttributes()
	slmod.makeUnitAttributesTable()
	slmod.makeUnitCategories()
    slmod.resetConsent()
	
	--slmod.save_var('net', 'unitCategories.txt', slmod.unitCategories, 'slmod.unitCategories')

	if slmod.stats.reset then  -- if this function doesn't exist, then slmod stats are completely disabled.
        slmod.stats.reset()
        slmod.stats.resetFile()
        slmod.stats.createGetStatsUnitInfo()
        slmod.stats.create_weaponIsActive()
        slmod.stats.create_unitIsStationary()
        slmod.stats.create_unitIsAlive()
        slmod.stats.trackFlightTimes()  -- start tracking times.
        slmod.stats.trackMissionTimes()
        slmod.create_SlmodStatsMenu()

		slmod.stats.onMission()
		

	end
    
    if slmod.config.autoAdmin.forgiveEnabled or slmod.config.autoAdmin.punishEnabled then
        slmod.createPunishForgiveMenu()
    end
    
    if slmod.create_SlmodVoteMenu then
        slmod.create_SlmodVoteMenu()
    end
	
	if slmod.create_SlmodMOTDMenu then
		slmod.create_SlmodMOTDMenu()
	end
	
	slmod.create_SlmodHelpMenu()
	--slmod.updateClientStats()
	
	slmod.ResetPTS()  --parallel tasking system
	slmod.ResetPOS()  --parallel options system
	--slmod.create_ReturnWeapons()
	slmod.load_weapons_impacting_code_to_server()
	--net.dostring_in('server', 'slmod_track_weapons()') --start tracking any tracked weapons
	----------------------------------------------------
	
	slmod.reset_randseed()
    
    --[[
    for id, _x in pairs(slmod.clients) do
        if net.get_name(id) and net.get_player_info(id, 'ucid') then -- check if client is still there, otherwise clear it
            
        end
    end
    
    ]]
    
    
	local curClients = 0
    local curList = net.get_player_list()
	for id, dat in pairs(net.get_player_list()) do
		curClients = curClients + 1
        
        if (slmod.clients[id] and slmod.clients[id].ucid ~= net.get_player_info(id, 'ucid')) or not slmod.clients[id] then
            slmod.clients[id] = {id = id, addr = net.get_player_info(id, 'ipaddr'), name = net.get_player_info(id, 'name'), ucid = net.get_player_info(id, 'ucid'), ip = net.get_player_info(id, 'ipaddr')}
        end
	end
	if slmod.num_clients and slmod.num_clients ~= curClients then
		slmod.info('Reset Num Clients')
		slmod.num_clients = curClients
	end
	
end

slmod.info('SlmodLibs.lua loaded.')