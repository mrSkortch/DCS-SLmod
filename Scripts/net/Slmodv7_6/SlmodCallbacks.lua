--------------------------------------------------------
 -- for data passing from MissionScripting.lua
slmod.recvData = {} 
slmod.recvCmds = {}

slmod.recvDataCntr = 1  -- index of last command + 1
--------------------------------------------------------

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
--FUNCTION REDEFINITIONS:
slmod.func_old = slmod.func_old or {}

--redefine on_process
--slmod.func_old.on_process = slmod.func_old.on_process or onSimulationFrame -- using a global just in case I make a reload_slmod work again

local slmodCall = {}

do
	
	--[[this function gets the Command data  
	Returns either false or a the number followed the be remaining data in the string.
	Ex:
	getCmdData("[1][1][1]afdsafsdfsadfasdf")
	-> 1, 1, 1, afdsafsdfsadfasdf
	
	
	]]
	local function getCmdData(s)
		local function getNextData(s)
			local start, stop
			for i = 1, 6 do -- search for the first instance of "[<number>]"... can't use start, stop = s:find('%[%d+%]', s) because "+" always returns the LONGEST match, and I need the FIRST match!!!
				local pattern = '%['
				for j = 1, i do
					pattern = pattern .. '%d'
				end
				pattern = pattern .. '%]'
				--assembled the pattern
				start, stop = s:find(pattern)
				if start and start == 1 then
					break
				end
			end
			if start then
				local num = tonumber(s:sub(start + 1, stop - 1))
				
				if type(num) == 'number' and stop < s:len() then -- just making sure...
					return num, s:sub(stop + 1)
				end
			end
		end
		-- start is now either nil or 1.
		
		local cmdNum, s = getNextData(s)
		if cmdNum then
			local totalLines, s = getNextData(s)
			if totalLines then
				local lineNum, s = getNextData(s)
				if lineNum then
					return cmdNum, totalLines, lineNum, s
				end
			end
		end
	end

	-- create the sandbox
	local sandbox = {}
	sandbox['slmod'] = {}
	sandbox.slmod['dump_Gs_net'] = slmod.dump_Gs_net
			
	sandbox.slmod['chatmsg_net'] = slmod.chatmsg_net
	sandbox.slmod['chatmsg_repeat_net'] = slmod.chatmsg_repeat_net
	sandbox.slmod['chatmsg_groupMGRS_net'] = slmod.chatmsg_groupMGRS_net
	sandbox.slmod['command_check_net'] = slmod.command_check_net
	sandbox.slmod['command_check_start_loop_net'] = slmod.command_check_start_loop_net
	
	sandbox.slmod['msg_out_net'] = slmod.msg_out_net
	sandbox.slmod['msg_out_w_unit_net'] = slmod.msg_out_w_unit_net
	sandbox.slmod['CA_chatmsg_net'] = slmod.CA_chatmsg_net
	sandbox.slmod['msg_MGRS_net'] = slmod.msg_MGRS_net
	sandbox.slmod['msg_LL_net'] = slmod.msg_LL_net
	sandbox.slmod['msg_leading_net'] = slmod.msg_leading_net
	sandbox.slmod['chat_cmd_net'] = slmod.chat_cmd_net
	
	sandbox.slmod['add_task_net'] = slmod.add_task_net
	sandbox.slmod['remove_task_net'] = slmod.remove_task_net
	sandbox.slmod['show_task_net'] = slmod.show_task_net
	sandbox.slmod['show_task_list_net'] = slmod.show_task_list_net
	sandbox.slmod['set_PTS_list_output_net'] = slmod.set_PTS_list_output_net
	sandbox.slmod['set_PTS_task_output_net'] = slmod.set_PTS_task_output_net
	
	sandbox.slmod['add_option_net'] = slmod.add_option_net
	sandbox.slmod['remove_option_net'] = slmod.remove_option_net
	sandbox.slmod['show_option_list_net'] = slmod.show_option_list_net
	sandbox.slmod['set_POS_output_net'] = slmod.set_POS_output_net
	
	sandbox.slmod['units_LOS_net'] = slmod.units_LOS_net
	sandbox.slmod['rand_flags_on_net'] = slmod.rand_flags_on_net
	sandbox.slmod['rand_flag_choice_net'] = slmod.rand_flag_choice_net
	sandbox.slmod['num_dead_gt_net'] = slmod.num_dead_gt_net
	sandbox.slmod['units_in_moving_zones_net'] = slmod.units_in_moving_zones_net
	sandbox.slmod['units_in_zones_net'] = slmod.units_in_zones_net
	
	sandbox.slmod['mapobj_destroyed_net'] = slmod.mapobj_destroyed_net
	sandbox.slmod['mapobj_dead_in_zone_net'] = slmod.mapobj_dead_in_zone_net
	sandbox.slmod['units_hitting_net'] = slmod.units_hitting_net
	sandbox.slmod['units_firing_net'] = slmod.units_firing_net
	sandbox.slmod['units_crashed_net'] = slmod.units_crashed_net
	sandbox.slmod['units_ejected_net'] = slmod.units_ejected_net
	sandbox.slmod['pilots_dead_net'] = slmod.pilots_dead_net
	sandbox.slmod['units_killed_by_net'] = slmod.units_killed_by_net
	
	sandbox.slmod['weapons_impacting_in_zones_net'] = slmod.weapons_impacting_in_zones_net
	sandbox.slmod['weapons_impacting_in_moving_zones_net'] = slmod.weapons_impacting_in_moving_zones_net
	sandbox.slmod['weapons_in_zones_net'] = slmod.weapons_in_zones_net
	sandbox.slmod['weapons_in_moving_zones_net'] = slmod.weapons_in_moving_zones_net
    
    sandbox.slmod['custom_stats_net'] = slmod.custom_stats_net
    sandbox.slmod['set_campaign_net'] = slmod.set_campaign_net
    sandbox.slmod['mission_admin_action'] = slmod.mission_admin_action
    sandbox.slmod['mission_config_net'] = slmod.mission_config_net
	
	--creating slmod.clients and banning code.

do
	local runF = false
	
	local function getNetview()
        if DCS.isMultiplayer() == true and DCS.isServer() == true then
			if runF == false then
                slmod.clients = slmod.clients or {}
                slmod.clients[1] = {id = 1, name = net.get_name(1), ucid = slmod.config.host_ucid or 'host' }  -- server host
				runF = true
			end			
            return true
		end
		return false
	end
    

	local prevExecTime = 0  -- for once-every-second code.
	local prevSTest = 0
	function slmodCall.onSimulationFrame()
		if runF == false then  
             getNetview()
        else   -- only run if netview is running.  Netview seems to know the proper times as to when the
	        -- game is fully started, and when the game is beginning to stop.
			---------------------------------------------------------------------------------------------------------------
			-- data passing code
			--net.log('netViewTrue')
			if DCS.getModelTime() > 0 then  -- must check this to prevent a possible CTD by using a_do_script before the game is ready to use a_do_script.
				local str, err = net.dostring_in('mission', 'return a_do_script(\'slmod.sendData()\')')  -- using LuaSocket, sends any data from Slmod mission scripting components to slmod.config.udp_port.
			end
			
			if not slmod.udp then
				package.path  = package.path..';.\\LuaSocket\\?.lua'
				package.cpath = package.cpath..';.\\LuaSocket\\?.dll'
				slmod.socket = require('socket')
				local host, port = 'localhost', slmod.config.udp_port
				local ip = slmod.socket.dns.toip(host)
				slmod.udp = slmod.socket.udp()
				slmod.udp:setsockname(ip, port)
				slmod.udp:settimeout(0.0001)   -- REALLY short timeout.  Asynchronous operation required.
			end
				
			local cmd, err, dataSent
			repeat
				cmd, err = slmod.udp:receive()
				if not err then
					slmod.recvData[#slmod.recvData + 1] = cmd
					dataSent = true
					--net.log('recieved data: ' .. cmd)
				end
			until err
					
			-- now process the data (if there is any)
			if dataSent then
			
				while slmod.recvDataCntr <= #slmod.recvData do
					
					local s =  slmod.recvData[slmod.recvDataCntr]
					slmod.recvDataCntr = slmod.recvDataCntr + 1  -- increment first so that the process can't get stuck.	
					local cmdNum, totalLines, lineNum, data = getCmdData(s)
					if cmdNum then	
						slmod.recvCmds[cmdNum] = slmod.recvCmds[cmdNum] or {}
						slmod.recvCmds[cmdNum][lineNum] = data -- from the end of the line number to end.
						
						if #slmod.recvCmds[cmdNum] == totalLines then -- ready to run this in a protected environment
							local fcnString = ''
							for i = 1, #slmod.recvCmds[cmdNum] do
								fcnString = fcnString .. slmod.recvCmds[cmdNum][i]
							end
							--net.log(fcnString)
							local f, err = loadstring(fcnString)
							if f then
								setfenv(f, sandbox)
								local err, errmsg = pcall(f)
								if not err then
									slmod.error('error in function: ' .. errmsg)
								end
							else
								slmod.error('error in loaded function string: ' .. fcnString)
							end
						end
					end	
				end
			end -- end of data passing code.
			-------------------------------------------------------------------------------------------------

			--Check to see if it's time to do any scheduled strings
			slmod.do_scheduled_strings()
			
			--slmod.getBallisticsFromExport()
			
			--Check for scheduled tasks
			slmod.doTasks()

			
			if slmod.mission_started == true then
				slmod.reset()
				slmod.mission_started = false

				if slmod.config.debugger then
					slmod.runSlmodDebugger()
				end
				slmod.checkSlmodClients()  -- experimental check slmod.clients function
			end
			-- do the updateActiveUnits coroutine...
			slmod.coroutines = slmod.coroutines or {}
			if not slmod.coroutines.updateActiveUnits then
				slmod.coroutines.updateActiveUnits = {co = coroutine.create(slmod.updateActiveUnits), startTime = DCS.getRealTime(), lastRun = DCS.getRealTime()}
				coroutine.resume(slmod.coroutines.updateActiveUnits.co)
			else  -- the coroutine did exist.
				if DCS.getRealTime() - slmod.coroutines.updateActiveUnits.lastRun >= 0.05 then -- 20 times a second...
					if not slmod.missionEndEvent() then  -- if the last event was not an end mission event...
						if coroutine.status(slmod.coroutines.updateActiveUnits.co) == 'dead' then -- it's finished
							if DCS.getRealTime() - slmod.coroutines.updateActiveUnits.startTime >= 3 then  -- make sure at least 3 seconds have elapsed.
								slmod.coroutines.updateActiveUnits = nil -- erase it, ready for next cycle to start.
							end
						else  -- it's not done.
							coroutine.resume(slmod.coroutines.updateActiveUnits.co)
							slmod.coroutines.updateActiveUnits.lastRun = DCS.getRealTime()
						end
					end
				end
			end
			local curExecTime = os.clock()
			------------------------------------------------------------Every second if server and slmod enabled ---------------------------------------------------------------------------
			if math.abs(curExecTime - prevExecTime) >= 1 then --do every second
				prevExecTime = curExecTime
				--------------------------------------------------------
				--Add clients to server env and ucids/names to clients.
				slmod.updateClients()

				-- Check pings
				if slmod.config.pingcheck_conf.enabled == true then
					slmod.pingCheck.heartbeat()
				end
				
				---------------------------------------------------------------
				-- events
				slmod.addSlmodEvents()
				
				if slmod.stats.trackEvents then  -- needs to be this way to increment events counter!
					slmod.stats.trackEvents()
				end
				
				if slmod.config.events_output then
					slmod.outputSlmodEvents()
				end
				------------------------------------------------------------------------------			
				 --update any tracked weapons
				local wpn_track_str, wpn_track_err = net.dostring_in('server', 'slmod.update_track_weapons_for()')
				if not wpn_track_err then
					slmod.error('unable to update tracked weapons, reason: ' .. wpn_track_str)
				end

				------------- DO ANY DO ONCE CODE AT T>1 ----------------------------------------------------
				if slmod.do_once_code and DCS.getModelTime() > 1 then
					--net.log('do once')
					net.dostring_in('server', 'slmod.track_weapons()')  -- start weapons tracking
					slmod.doOnceTest1() -- do any tests
					slmod.do_once_code = false
				end
				-----------------------------------------------------------------------------------------------
				
				---------------DO ANY TESTS-----------------------------------------------------
				slmod.onProcessTest1()
				
				slmod.testCounter =  slmod.testCounter or 0

				slmod.testCounter = slmod.testCounter + 1
				if slmod.testCounter >= 10 then
				
					slmod.onProcessTest2()
					slmod.testCounter = 0
					
				end
				
				if slmod.config.pause_when_empty and (DCS.getRealTime() > slmod.mission_start_time + 8) then -- 8 second window to hopefully always avoid the CTD
					if DCS.getPause() == false then
						slmod_pause_forced = false  -- turn off the forced pause if the server is not paused for any reason.
					end
					
					if not slmod_pause_override then 
						if (slmod.num_clients and slmod.num_clients == 1 or not slmod.num_clients) and DCS.getPause() == false then
							DCS.setPause(true)
						elseif slmod.num_clients and slmod.num_clients > 1 and DCS.getPause() == true and (not slmod_pause_forced) then
							DCS.setPause(false)
						end
					end
					
				end
				
			end
			-- pause logic:
			--IF the pause when empty feature is enabled
				--slmod_pause_forced continuously turned off when unpaused
				--slmod_pause_forced is enabled if override is off and the server is paused with the admin pause command
				--slmod_pause_forced turned off when override is toggled
			



			
		
        end
	end
	--slmod.func_old.on_process()
	
end



-- redefine on_mission
--slmod.func_old.on_mission = slmod.func_old.on_mission or onMissionLoadBegin --onMissionLoadBegin
function slmodCall.onMissionLoadBegin()
	slmod.current_mission = DCS.getMissionName()
    local missionName = ''
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
    slmod.current_mission_safe_name = missionName
    
    slmod.current_map = DCS.getCurrentMission().mission.theatre
	slmod.mission_start_time = DCS.getRealTime()  --needed to prevent CTD caused by C Lua API on net.pause and net.resume
	slmod.mission_started = true
	slmod.do_once_code = true

	-- flush out the udp port if there is anything left.
	if slmod.udp then
		repeat
			local cmd, err = slmod.udp:receive()
		until err
	end
	
	return --slmod.func_old.on_mission(filename)
end

--slmod.func_old.onPlayerTrySendChat = slmod.func_old.onPlayerTrySendChat or onPlayerTrySendChat -- old_on_chat should be an upvalue of on_chat, using the "or" just in case I make a reload_slmod work again
local lastLogLine = '' 
function slmodCall.onPlayerTrySendChat(id, msg, all)  --new definition
	local function cut_tail_spaces(str)
		local tail = string.find(str, '%s+$')  -- find where trailing spaces start
		if tail then
			return string.sub(str, 1, tail-1)  -- cut if there are any
		else
			return str
		end
	end
	local realString = cut_tail_spaces(msg)

	slmod.chat_table = slmod.chat_table or {}
	table.insert(slmod.chat_table, { id = id, msg = realString, all = all })
	
	--new functionality
	local suppress = slmod.doMenuCommands(id, realString)
    --TODO ADD CHECK TO SEE IF HOST IS SPAMMING
	if slmod.chatLogFile and slmod.clients[id]  then  -- client better exist in slmod clients!
		local clientInfo = table.concat({'{name  = ', slmod.basicSerialize(tostring(slmod.clients[id].name)), ', ucid = ', slmod.basicSerialize(tostring(slmod.clients[id].ucid)), ', ip = ',  slmod.basicSerialize(tostring(slmod.clients[id].addr)), ', id = ', tostring(id),  '}'})

		local logline
        local writeLog = true
		if realString ~= '/mybad' then
			logline = 'CHAT: ' .. os.date('%b %d %H:%M:%S ') .. clientInfo .. ' said "' .. realString .. '"'
			if all then
				logline = logline .. ' to all'
			else
				logline = logline .. ' to coalition'
			end
			
			if suppress then -- do you see the violence inheirited in the system?
				logline = logline .. ' (output suppressed by Slmod)\n'
			else
				logline = logline .. '\n'
			end
		else
			logline = 'SCREENSHOT: ' .. os.date('%b %d %H:%M:%S ') .. clientInfo .. ' made a screenshot.\n'
		end

        if lastLogLine == logline then -- if the last written message is identical to this one, then don't write to the log
            lastLogLine = logline
        end
        if id == 1 and slmod.config.log_only_important_server_messages then -- useful slmod messages start with Slmod: or Slmod-. All other messages from host will be removed from chat lot
           writeLog = false
           if (string.find(logline, 'Slmod:') and string.find(logline, 'Slmod:') < 2) or (string.find(logline, 'Slmod%-') and string.find(logline, 'Slmod%-') < 2) then
              writeLog = true
           end
        end
        if writeLog == true or suppress == true then
            slmod.chatLogFile:write(logline)
            slmod.chatLogFile:flush()
        end
	elseif not slmod.clients[id] then
		slmod.error('chat message from non-existent client in slmod.clients!')
	end
	
	if suppress then
		return '' -- don't go any further- suppress any further on_chat.
	end
end

-----------------------------------------------------------------------------------------
--modify on_connect
--slmod.func_old.on_connect = slmod.func_old.on_connect or onPlayerConnect
function slmodCall.onPlayerConnect(id)
	slmod.info('connected client ' .. id)
	slmod.clients = slmod.clients or {} --should not be necessary.
	slmod.clients[id] = {id = id, addr = net.get_player_info(id, 'ipaddr'), name = net.get_player_info(id, 'name'), ucid = net.get_player_info(id, 'ucid'), ip = net.get_player_info(id, 'ipaddr')}

	if not slmod.num_clients then
		slmod.num_clients = 1
	else
		slmod.num_clients = slmod.num_clients + 1
	end

    if slmod.config.pingcheck_conf and slmod.config.pingcheck_conf.enabled then 
 
		slmod.pingCheck.addClient(id)
    end
    slmod.info('num clients: '.. slmod.num_clients)
	return --slmod.func_old.on_connect(id)
end 

--slmod.func_old.onPlayerTryConnect = slmod.func_old.on_connect or onPlayerTryConnect
function slmodCall.onPlayerTryConnect(addr, name, ucid)
	--net.log('ontryconnect')
	slmod.bannedIps = slmod.bannedIps or {}
	slmod.bannedUcids = slmod.bannedUcids or {}

	if slmod.bannedIps[addr] then
		return false, "You are banned from this server."
	end

	if slmod.bannedUcids[ucid] then
		return false, "You are banned from this server."
	end
	
	local allow, score = slmod.autoAdminOnConnect(ucid)

    if allow == false  then
		if slmod.config.autoAdmin.showPenaltyKickBanActions then
            if slmod.config.autoAdmin.reallowLevel then 
                return false, 'You are autobanned from this server with: ' .. string.format("%.2f", tostring(score)) .. ' penalty points. Unautoban occurs below ' .. slmod.config.autoAdmin.reallowLevel .. ' points.' 
            else
                return false, 'You are autobanned from this server with: ' .. string.format("%.2f", tostring(score)) .. ' penalty points.' 
            end
        else
            return false, 'You are autobanned from this server'
        end
	end


	--return true
end

-- modify on_set_unit
--slmod.func_old.on_set_unit = slmod.func_old.on_set_unit or onPlayerChangeSlot
function slmodCall.onPlayerChangeSlot(id)
	--net.log('on change slot')
	if slmod.stats.onSetUnit then
		slmod.stats.onSetUnit(id)
	end

    if SlmodMOTDMenu then  -- right now, simple MOTD- send it to player when they select unit.
        if slmod.clients[id] and (not slmod.clients[id].motdTime or DCS.getRealTime() - slmod.clients[id].motdTime > 5) then
            slmod.clients[id].motdTime = DCS.getRealTime()
            slmod.scheduleFunctionByRt(SlmodMOTDMenu.show, {SlmodMOTDMenu, id, {clients = {id}}}, DCS.getRealTime() + 0.1)
        end
    end
    if slmod.config.pingcheck_conf.enabled then 
        slmod.pingCheck.setActive(id)
    end
	return --slmod.func_old.on_set_unit(id)
end

--modify on_disconnect
--slmod.func_old.on_disconnect = slmod.func_old.on_disconnect or onPlayerDisconnect
function slmodCall.onPlayerDisconnect(id, err)
	slmod.info('slmod_onPlayerDisconnect ' .. id)
	slmod.clients = slmod.clients or {}  --should not be necessary.
	if slmod.clients[id] then
        slmod.clients[id] = nil
		slmod.num_clients = slmod.num_clients - 1
	end
    slmod.info('num clients: '.. slmod.num_clients)
	return --slmod.func_old.on_disconnect(id, err)
end
-- this is actually called every time the server closes- not when the game shuts down!
--[[ modify on_net_stop to close files.
slmod.func_old.on_net_stop = slmod.func_old.on_net_stop or server.on_net_stop
server.on_net_stop = function()
	slmod.info('in server.on_net_stop')
	if slmod.chatLogFile then
		slmod.chatLogFile:close()
		slmod.chatLogFile = nil
	end
	slmod.stats.closeStatsFile()
	slmod.udp:close()
	slmod.closeLog()
	return slmod.func_old.on_net_stop()
end
]]

DCS.setUserCallbacks(slmodCall)
end
slmod.info('SlmodCallbacks.lua loaded')