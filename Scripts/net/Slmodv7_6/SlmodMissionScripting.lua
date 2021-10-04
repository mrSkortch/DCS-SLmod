dofile('Scripts/ScriptingSystem.lua')
--[[
do -- witchcraft
	witchcraft = {}
	witchcraft.host = "localhost"
	witchcraft.port = 3001
	dofile(lfs.writedir().."Scripts\\witchcraft.lua")
end
]]
--Sanitize Mission Scripting environment
--This makes unavailable some unsecure functions. 
--Mission downloaded from server to client may contain potentialy harmful lua code that may use these functions.
--You can remove the code below and make availble these functions at your own risk.

local function sanitizeModule(name)
	_G[name] = nil
	package.loaded[name] = nil
end
-------------------------------------------------------------------------------------------------------
-- Slmod begins here.
do
	env.info('Loading SLMOD MissionScripting.lua')
    slmod = {}
	local config = {}  -- don't want hte slmod config settings adjustable from MissionScripting, so local
	slmod.version = '7_6'
	---------------------------------------------------------------------------------------------------
	-- Loading the config settings
	local configPath = lfs.writedir() .. [[Slmod\config.lua]]
	
	local function defaultSettings() -- because this is the only setting it cares about
        config.udp_port = 52146 
	end	
	
	local configFile = io.open(configPath, 'r')
	if configFile then
		local configString = configFile:read('*all')
		local configFunc, err1 = loadstring(configString)
		if configFunc then
			setfenv(configFunc, config)
			local bool, err2 = pcall(configFunc)
			if not bool then
				env.info('Slmod Error: unable to load config settings, reason: ' .. tostring(err2))
				defaultSettings()
			else
				env.info('Slmod: using settings defined in ' .. configPath)
			end
		else
			env.info('Slmod Error: unable to load config settings, reason: ' .. tostring(err1))
			defaultSettings()
		end
		configFile:close()
	else -- unable to open the config file
		env.info('Slmod: no config file detected.')
		defaultSettings()
	end
	
	--------------------------------------------------------------------------------------
	-- Serialization functions
	
	local function basicSerialize(s)
		if s == nil then
			return "\"\""
		else
			if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
				return tostring(s)
			elseif type(s) == 'string' then
				s = string.format('%q', s)
				return s
			end
		end	
	end
	
	local function oneLineSerialize(tbl)  -- serialization of a table all on a single line, no comments, made to replace old get_table_string function
		if type(tbl) == 'table' then --function only works for tables!

			local tbl_str = {}
			tbl_str[#tbl_str + 1] = '{ '
			
			for ind,val in pairs(tbl) do -- serialize its fields
				if type(ind) == 'number' then
					tbl_str[#tbl_str + 1] = '[' 
					tbl_str[#tbl_str + 1] = tostring(ind)
					tbl_str[#tbl_str + 1] = '] = '
				else --must be a string
					tbl_str[#tbl_str + 1] = '[' 
					tbl_str[#tbl_str + 1] = basicSerialize(ind)
					tbl_str[#tbl_str + 1] = '] = '
				end
					
				if ((type(val) == 'number') or (type(val) == 'boolean')) then
					tbl_str[#tbl_str + 1] = tostring(val)
					tbl_str[#tbl_str + 1] = ', '		
				elseif type(val) == 'string' then
					tbl_str[#tbl_str + 1] = basicSerialize(val)
					tbl_str[#tbl_str + 1] = ', '
				elseif type(val) == 'nil' then -- won't ever happen, right?
					tbl_str[#tbl_str + 1] = 'nil, '
				elseif type(val) == 'table' then
					tbl_str[#tbl_str + 1] = oneLineSerialize(val)
					tbl_str[#tbl_str + 1] = ', '   --I think this is right, I just added it
				else
					env.info('unable to serialize value type ' .. basicSerialize(type(val)) .. ' at index ' .. tostring(ind))
				end
			
			end
			tbl_str[#tbl_str + 1] = '}'
			return table.concat(tbl_str)
		end
	end

	-- global function to create string for viewing the contents of a table -NOT for serialization
	function slmod.tableshow(tbl, loc, indent, tableshow_tbls) --based on slmod.serialize, this is a _G serialization
		tableshow_tbls = tableshow_tbls or {} --create table of tables
		loc = loc or ""
		indent = indent or ""
		if type(tbl) == 'table' then --function only works for tables!
			tableshow_tbls[tbl] = loc
			
			local tbl_str = {}

			tbl_str[#tbl_str + 1] = indent .. '{\n'
			
			for ind,val in pairs(tbl) do -- serialize its fields
				if type(ind) == "number" then
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = tostring(ind)
					tbl_str[#tbl_str + 1] = '] = '
				else
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = basicSerialize(ind)
					tbl_str[#tbl_str + 1] = '] = '
				end
						
				if ((type(val) == 'number') or (type(val) == 'boolean')) then
					tbl_str[#tbl_str + 1] = tostring(val)
					tbl_str[#tbl_str + 1] = ',\n'		
				elseif type(val) == 'string' then
					if ind ~= 'MissionScripting_G' then
						tbl_str[#tbl_str + 1] = basicSerialize(val)
						tbl_str[#tbl_str + 1] = ',\n'
					else
						tbl_str[#tbl_str + 1] = 'Value Skipped,\n'
					end
				elseif type(val) == 'nil' then -- won't ever happen, right?
					tbl_str[#tbl_str + 1] = 'nil,\n'
				elseif type(val) == 'table' then
					if tableshow_tbls[val] then
						tbl_str[#tbl_str + 1] = tostring(val) .. ' already defined: ' .. tableshow_tbls[val] .. ',\n'
					else
						tableshow_tbls[val] = loc ..  '[' .. basicSerialize(ind) .. ']'
						tbl_str[#tbl_str + 1] = tostring(val) .. ' '
						tbl_str[#tbl_str + 1] = slmod.tableshow(val,  loc .. '[' .. basicSerialize(ind).. ']', indent .. '    ', tableshow_tbls)
						tbl_str[#tbl_str + 1] = ',\n'  
					end
				elseif type(val) == 'function' then
					if debug and debug.getinfo then
						fcnname = tostring(val)
						local info = debug.getinfo(val, "S")
						if info.what == "C" then
							tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', C function') .. ',\n'
						else 
							if (string.sub(info.source, 1, 2) == [[./]]) then
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')' .. info.source) ..',\n'
							else
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')') ..',\n'
							end
						end
						
					else
						tbl_str[#tbl_str + 1] = 'a function,\n'	
					end
				else
					tbl_str[#tbl_str + 1] = 'unable to serialize value type ' .. basicSerialize(type(val)) .. ' at index ' .. tostring(ind)
				end
			end
			
			tbl_str[#tbl_str + 1] = indent .. '}'
			return table.concat(tbl_str)
		end
	end

	----------------------------------------------------------------------------------------------------
	-- data sending over LuaSocket.
	package.path  = package.path..";.\\LuaSocket\\?.lua"
	package.cpath = package.cpath..";.\\LuaSocket\\?.dll"
	local socket = require('socket')
	
	local port = config.udp_port
	local ip = socket.dns.toip('localhost')
	
	--[[ New data passing method for Slmod:
	[1][2][1]add_task_net( .....
	[1][2][2] ... )              -- first number: function/command number.  Second number: total # of lines.  Third number: line #.  Lines limited to 1000 chars.
	--Functions run in a secure sandboxed environment.]]
	
	local charLim = 2000
	
	local sendCount = 1  -- Command #.
	
	local dataToSend = {}  -- data that needs to be sent over the UDP
	
	local addUDPData = function(tbl)  -- adds data to the the queue to be sent via LuaSocket.
		
		local tblLen = table.maxn(tbl)
		local fcnString = tbl[1] .. '('
		for i = 2, tblLen do
			if type(tbl[i]) == 'table' then
					if oneLineSerialize then
        env.info('one line exists')
    end
                fcnString = fcnString .. oneLineSerialize(tbl[i])
			else
				fcnString = fcnString .. basicSerialize(tbl[i])
			end
			
			if i ~= tblLen then
				fcnString = fcnString .. ', '
			end
		
		end
		fcnString = fcnString .. ')'
		
		-- now, need to break up into lines.
		local dataStrings = {}
		
		local remChars = fcnString
		repeat
			if remChars:len() > charLim then
				dataStrings[#dataStrings + 1] = remChars:sub(1, charLim)
				remChars = remChars:sub(charLim + 1)  -- from charLim + 1 to end
			else
				dataStrings[#dataStrings + 1] = remChars
				remChars = ''
			end
		until remChars == ''
		
		-- now add line numbers
		for i = 1, #dataStrings do
			dataToSend[#dataToSend + 1] = '[' .. sendCount .. '][' .. #dataStrings .. '][' .. i .. ']' .. dataStrings[i]
		end
		sendCount = sendCount + 1
	end
	
	local bufferSize = 8192  -- default UDP buffer is 8 kB
	
	--sends data from dataToSend over LuaSocket udp port.  Global, but cannot be used for exploitive purposes, because it can only access a certain UDP port, and send data from a local upvalued table.
	slmod.sendData = function()  -- global function, called via net.dostring_in('mission', 'a_do_script(\'sendData()\')') from SlmodCallbacks.lua (in server.on_process callback).
		if #dataToSend > 0 then
			local bufferLimit = false
			local totalSent = 0
			local udp = socket.udp()
			while #dataToSend > 0 do
				totalSent = totalSent + dataToSend[1]:len()  -- first, see if total exceeds buffer size
				--env.info('total sent: ' .. totalSent)
				if totalSent >= bufferSize then
					--env.info('BREAKING!')
					bufferLimit = true
					break
				else		
					udp:sendto(dataToSend[1], ip, port)
					--env.info('sent: ' .. dataToSend[1])
					table.remove(dataToSend, 1)	
				end
			end		
			udp:close()
		end
	end
	
	---------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	-- chatIOlibv1 support
	function slmod.chatmsg(text)
		local tbl = {}
		tbl[1] = 'slmod.chatmsg_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text']	
		else
			tbl[2] = text	
		end

		addUDPData(tbl)
	end

	function slmod.chatmsg_repeat(text, numtimes, interval)
		local tbl = {}
		tbl[1] = 'slmod.chatmsg_repeat_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['msgline']
			tbl[3] = vars['numtimes']
			tbl[4] = vars['interval']		
		else
			tbl[2] = text
			tbl[3] = numtimes
			tbl[4] = interval		
		end
		addUDPData(tbl)
	end

	function slmod.chatmsg_groupMGRS(text, units, numdigits, numtimes, interval)
		local tbl = {}
		tbl[1] = 'slmod.chatmsg_groupMGRS_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[3] = vars['units']
			tbl[4] = vars['numdigits'] or vars['precision']
			tbl[5] = vars['numtimes']
			tbl[6] = vars['interval']			
		else
			tbl[2] = text
			tbl[3] = units
			tbl[4] = numdigits
			tbl[5] = numtimes
			tbl[6] = interval		
		end
		addUDPData(tbl)
	end

	function slmod.command_check(text, flag)
		local tbl = {}
		tbl[1] = 'command_check_net'
		if type(text) == 'table' then
			local vars = text			
			tbl[2] = vars['text'] or vars['commandtext']
			tbl[3] = vars['flag']			
		else
			tbl[2] = text
			tbl[3] = flag		
		end
		addUDPData(tbl)
	end

	function slmod.command_check_start_loop(text, flag, interval, purge)
		local tbl = {}
		tbl[1] = 'command_check_start_loop_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['commandtext']
			tbl[3] = vars['flag']
			tbl[4] = vars['interval']
			tbl[5] = vars['purge']		
		else
			tbl[2] = text
			tbl[3] = flag
			tbl[4] = interval
			tbl[5] = purge		
		end
		addUDPData(tbl)
	end

	-- End of chatIOlibv1 support
	------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	--Slmod functions
	function slmod.msg_out(text, display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.msg_out_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['text_out']
			tbl[3] = vars['display_time']
			tbl[4] = vars['display_mode']
			tbl[5] = vars['coa'] or vars['coalition']
		else
			tbl[2] = text
			tbl[3] = display_time
			tbl[4] = display_mode
			tbl[5] = coa
		end
		addUDPData(tbl)
	end

	function slmod.msg_MGRS(text, units, numdigits, display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.msg_MGRS_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[3] = vars['units'] or vars['group']
			tbl[4] = vars['numdigits'] or vars['precision']
			tbl[5] = vars['display_time']
			tbl[6] = vars['display_mode']
			tbl[7] = vars['coa'] or vars['coalition']	
		else
			tbl[2] = text
			tbl[3] = units
			tbl[4] = numdigits
			tbl[5] = display_time
			tbl[6] = display_mode
			tbl[7] = coa		
		end
		addUDPData(tbl)
	end

	function slmod.msg_LL(text, units, precision, display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.msg_LL_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[3] = vars['units'] or vars['group']
			tbl[4] = vars['precision'] or vars['numdigits']
			tbl[5] = vars['display_time']
			tbl[6] = vars['display_mode']
			tbl[7] = vars['coa'] or vars['coalition']
		else
			tbl[2] = text
			tbl[3] = units
			tbl[4] = precision
			tbl[5] = display_time
			tbl[6] = display_mode
			tbl[7] = coa
		end
		addUDPData(tbl)
	end

	function slmod.msg_leading(coordtype, text, units, direction, radius, precision, display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.msg_leading_net' 
		if type(coordtype) == 'table' then
			local vars = coordtype
			tbl[2] = vars['coordtype'] or vars['type']
			tbl[3] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[4] = vars['units'] or vars['group']
			tbl[5] = vars['direction']
			tbl[6] = vars['radius']
			tbl[7] = vars['precision'] or vars['numdigits']
			tbl[8] = vars['display_time']
			tbl[9] = vars['display_mode']
			tbl[10] = vars['coa'] or vars['coalition']
		else
			tbl[2] = coordtype
			tbl[3] = text
			tbl[4] = units
			tbl[5] = direction
			tbl[6] = radius
			tbl[7] = precision
			tbl[8] = display_time
			tbl[9] = display_mode
			tbl[10] = coa
		end
		addUDPData(tbl)
	end

	function slmod.add_task(id, task_type, description, text, units, precision, direction, radius)
		local tbl = {}
		tbl[1] = 'slmod.add_task_net'
		tbl[2] = 'all'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['task_type'] or vars['type']
			tbl[5] = vars['description']
			tbl[6] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[7] = vars['units'] or vars['group']
			tbl[8] = vars['precision'] or vars['numdigits']
			tbl[9] = vars['direction']
			tbl[10] = vars['radius']			
		else
			tbl[3] = id
			tbl[4] = task_type
			tbl[5] = description
			tbl[6] = text
			tbl[7] = units
			tbl[8] = precision
			tbl[9] = direction
			tbl[10] = radius
		end
		addUDPData(tbl)
	end

	function slmod.add_red_task(id, task_type, description, text, units, precision, direction, radius)
		local tbl = {}
		tbl[1] = 'slmod.add_task_net'
		tbl[2] = 'red'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['task_type'] or vars['type']
			tbl[5] = vars['description']
			tbl[6] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[7] = vars['units'] or vars['group']
			tbl[8] = vars['precision'] or vars['numdigits']
			tbl[9] = vars['direction']
			tbl[10] = vars['radius']			
		else
			tbl[3] = id
			tbl[4] = task_type
			tbl[5] = description
			tbl[6] = text
			tbl[7] = units
			tbl[8] = precision
			tbl[9] = direction
			tbl[10] = radius
		end
		addUDPData(tbl)
	end

	function slmod.add_blue_task(id, task_type, description, text, units, precision, direction, radius)
		local tbl = {}
		tbl[1] = 'slmod.add_task_net'
		tbl[2] = 'blue'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['task_type'] or vars['type']
			tbl[5] = vars['description']
			tbl[6] = vars['text'] or vars['prefacemsg'] or vars['msg']
			tbl[7] = vars['units'] or vars['group']
			tbl[8] = vars['precision'] or vars['numdigits']
			tbl[9] = vars['direction']
			tbl[10] = vars['radius']			
		else
			tbl[3] = id
			tbl[4] = task_type
			tbl[5] = description
			tbl[6] = text
			tbl[7] = units
			tbl[8] = precision
			tbl[9] = direction
			tbl[10] = radius
		end
		addUDPData(tbl)
	end

	function slmod.remove_task(id)
		local tbl = {}
		tbl[1] = 'slmod.remove_task_net'
		tbl[2] = 'all'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
		else
			tbl[3] = id		
		end
		addUDPData(tbl)
	end

	function slmod.remove_red_task(id)
		local tbl = {}
		tbl[1] = 'slmod.remove_task_net'
		tbl[2] = 'red'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
		else
			tbl[3] = id		
		end
		addUDPData(tbl)
	end

	function slmod.remove_blue_task(id)
		local tbl = {}
		tbl[1] = 'slmod.remove_task_net'
		tbl[2] = 'blue'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
		else
			tbl[3] = id		
		end
		addUDPData(tbl)
	end

	function slmod.show_task(id, display_time, display_mode)
		local tbl = {}
		tbl[1] = 'slmod.show_task_net'
		tbl[2] = 'all'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['display_time']
			tbl[5] = vars['display_mode']
		else
			tbl[3] = id
			tbl[4] = display_time
			tbl[5] = display_mode
		end
		addUDPData(tbl)
	end

	function slmod.show_red_task(id, display_time, display_mode)
		local tbl = {}
		tbl[1] = 'slmod.show_task_net'
		tbl[2] = 'red'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['display_time']
			tbl[5] = vars['display_mode']
		else
			tbl[3] = id
			tbl[4] = display_time
			tbl[5] = display_mode
		end
		addUDPData(tbl)
	end

	function slmod.show_blue_task(id, display_time, display_mode)
		local tbl = {}
		tbl[1] = 'slmod.show_task_net'
		tbl[2] = 'blue'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['display_time']
			tbl[5] = vars['display_mode']
		else
			tbl[3] = id
			tbl[4] = display_time
			tbl[5] = display_mode
		end
		addUDPData(tbl)
	end

	function slmod.show_task_list()
		local tbl = {}
		tbl[1] = 'slmod.show_task_list_net'
		tbl[2] = 'all'
		addUDPData(tbl)
	end

	function slmod.show_red_task_list()
		local tbl = {}
		tbl[1] = 'slmod.show_task_list_net'
		tbl[2] = 'red'
		addUDPData(tbl)
	end

	function slmod.show_blue_task_list()
		local tbl = {}
		tbl[1] = 'slmod.show_task_list_net'
		tbl[2] = 'blue'
		addUDPData(tbl)
	end

	function slmod.mapobj_destroyed(id, flag, percent)
		local tbl = {}
		tbl[1] = 'slmod.mapobj_destroyed_net'
		if type(id) == 'table' and flag == nil then
			local vars = id
			tbl[2] = vars['id']
			tbl[3] = vars['flag']
			tbl[4] = 1
			tbl[5] = vars['percent']		
		else
			tbl[2] = id
			tbl[3] = flag
			tbl[4] = 1
			tbl[5] = percent
		end
		addUDPData(tbl)
	end

	function slmod.units_LOS(unitset1, altoffset1, unitset2, altoffset2, flag, stopflag, interval, checks, radius)
		local tbl = {}
		tbl[1] = 'slmod.units_LOS_net'
		if type(unitset1) == 'table' and altoffset1 == nil then
			local vars = unitset1
			tbl[2] = vars['unitset1'] or vars['units']
			tbl[3] = vars['altoffset1']
			tbl[4] = vars['unitset2']
			tbl[5] = vars['altoffset2']
			tbl[6] = vars['flag']
			tbl[7] = vars['stopflag']
			tbl[8] = vars['interval']
			tbl[9] = vars['checks']
			tbl[10] = vars['radius']		
		else
			tbl[2] = unitset1
			tbl[3] = altoffset1
			tbl[4] = unitset2
			tbl[5] = altoffset2
			tbl[6] = flag
			tbl[7] = stopflag
			tbl[8] = interval
			tbl[9] = checks
			tbl[10] = radius
		end
		addUDPData(tbl)
	end

	function slmod.units_hitting(init_units, tgt_units, flag, stopflag, text, display_units, display_time, display_mode, coa, mpname)
		local tbl = {}
		tbl[1] = 'slmod.units_hitting_net'
		if type(init_units) == 'table' and flag == nil then
			local vars = init_units
			tbl[2] = vars['init_units'] or vars['units']
			tbl[3] = vars['tgt_units']
			tbl[4] = vars['flag']
			tbl[5] = -1
			tbl[6] = vars['stopflag']
			tbl[7] = vars['text'] or vars['msg']
			tbl[8] = vars['display_units']
			tbl[9] = vars['display_time']
			tbl[10] = vars['display_mode']
			tbl[11] = vars['coa'] or vars['coalition']
			tbl[12] = vars['mpname']
		else
			tbl[2] = init_units
			tbl[3] = tgt_units
			tbl[4] = flag
			tbl[5] = -1
			tbl[6] = stopflag
			tbl[7] = text
			tbl[8] = display_units
			tbl[9] = display_time
			tbl[10] = display_mode
			tbl[11] = coa
			tbl[12] = mpname		
		end
		addUDPData(tbl)
	end

	function slmod.mapobj_dead_in_zone(zone, flag, stopflag, numdead)
		local tbl = {}
		tbl[1] = 'slmod.mapobj_dead_in_zone_net'
		if type(zone) == 'table' then
			local vars = zone
			tbl[2] = vars['zone']
			tbl[3] = vars['flag']
			tbl[4] = -1
			tbl[5] = 0
			tbl[6] = vars['stopflag']
			tbl[7] = vars['numdead'] or vars['num_dead']
		else
			tbl[2] = zone
			tbl[3] = flag
			tbl[4] = -1
			tbl[5] = 0
			tbl[6] = stopflag
			tbl[7] = numdead
		end
		addUDPData(tbl)
	end

	function slmod.units_firing(init_units, flag, stopflag, weapons, text, display_units, display_time, display_mode, coa, mpname)
		local tbl = {}
		tbl[1] = 'slmod.units_firing_net'
		if type(init_units) == 'table' and flag == nil then
			local vars = init_units
			tbl[2] = vars['init_units'] or vars['units']
			tbl[3] = vars['flag']
			tbl[4] = -1
			tbl[5] = vars['stopflag']
			tbl[6] = vars['weapons']
			tbl[7] = vars['text'] or vars['msg']
			tbl[8] = vars['display_units']
			tbl[9] = vars['display_time']
			tbl[10] = vars['display_mode']
			tbl[11] = vars['coa'] or vars['coalition']
			tbl[12] = vars['mpname']	
		else
			tbl[2] = init_units
			tbl[3] = flag
			tbl[4] = -1
			tbl[5] = stopflag
			tbl[6] = weapons
			tbl[7] = text
			tbl[8] = display_units
			tbl[9] = display_time
			tbl[10] = display_mode
			tbl[11] = coa
			tbl[12] = mpname			
		end
		addUDPData(tbl)
	end

	function slmod.msg_out_w_unit(text, unit_name, display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.msg_out_w_unit_net'
		if type('text') == 'table' then
			tbl[2] = vars['text'] or vars['text_out']
			tbl[3] = vars['unit_name'] or vars['unit']
			tbl[4] = vars['display_time']
			tbl[5] = vars['display_mode']
			tbl[6] = vars['coa'] or vars['coalition']			
		else
			tbl[2] = text
			tbl[3] = unit_name
			tbl[4] = display_time
			tbl[5] = display_mode
			tbl[6] = coa
		end
		addUDPData(tbl)
	end

	function slmod.chat_cmd(text, flag, stopflag, coa, requireAdmin)
		local tbl = {}
		tbl[1] = 'slmod.chat_cmd_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['cmd_text'] or vars['msg']
			tbl[3] = vars['flag']
			tbl[4] = -1
			tbl[5] = vars['stopflag']
			tbl[6] = vars['coa'] or vars['coalition']
			tbl[7] = vars['requireAdmin']
		else
			tbl[2] = text
			tbl[3] = flag
			tbl[4] = -1
			tbl[5] = stopflag
			tbl[6] = coa
			tbl[7] = requireAdmin
		end
		addUDPData(tbl)
	end

	function slmod.rand_flags_on(startflag, endflag, prob)
		local tbl = {}
		tbl[1] = 'slmod.rand_flags_on_net'
		if type(startflag) == 'table' then
			local vars = startflag
			tbl[2] = vars['startflag'] or vars['flag']
			tbl[3] = vars['endflag'] or vars['stopflag']
			tbl[4] = vars['prob']
		else
			tbl[2] = startflag
			tbl[3] = endflag
			tbl[4] = prob
		end
		addUDPData(tbl)
	end

	function slmod.rand_flag_choice(startflag, endflag)
		local tbl = {}
		tbl[1] = 'slmod.rand_flag_choice_net'
		if type(startflag) == 'table' then
			local vars = startflag
			tbl[2] = vars['startflag'] or vars['flag']
			tbl[3] = vars['endflag'] or vars['stopflag']
		else
			tbl[2] = startflag
			tbl[3] = endflag
		end
		addUDPData(tbl)
	end

	function slmod.num_dead_gt(units, numdead, flag, stopflag)
		local tbl = {}
		tbl[1] = 'slmod.num_dead_gt_net'
		if type(units) == 'table' and numdead == nil then
			local vars = units
			tbl[2] = vars['units']
			tbl[3] = vars['numdead'] or vars['num_dead']
			tbl[4] = vars['flag']
			tbl[5] = vars['stopflag']
		else
			tbl[2] = units
			tbl[3] = numdead
			tbl[4] = flag
			tbl[5] = stopflag
		end
		addUDPData(tbl)
	end

	-----------------------------------------------------------------------------------------------
	--Parallel options system

	function slmod.add_option(id, description, flag)
		local tbl = {}
		tbl[1] = 'slmod.add_option_net'
		tbl[2] = 'all'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['description']
			tbl[5] = vars['flag']
		else
			tbl[3] = id
			tbl[4] = description
			tbl[5] = flag
		end
		addUDPData(tbl)
	end

	function slmod.add_red_option(id, description, flag)
		local tbl = {}
		tbl[1] = 'slmod.add_option_net'
		tbl[2] = 'red'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['description']
			tbl[5] = vars['flag']
		else
			tbl[3] = id
			tbl[4] = description
			tbl[5] = flag
		end
		addUDPData(tbl)
	end

	function slmod.add_blue_option(id, description, flag)
		local tbl = {}
		tbl[1] = 'slmod.add_option_net'
		tbl[2] = 'blue'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
			tbl[4] = vars['description']
			tbl[5] = vars['flag']
		else
			tbl[3] = id
			tbl[4] = description
			tbl[5] = flag
		end
		addUDPData(tbl)
	end

	function slmod.remove_option(id)
		local tbl = {}
		tbl[1] = 'slmod.remove_option_net'
		tbl[2] = 'all'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
		else
			tbl[3] = id
		end
		addUDPData(tbl)
	end

	function slmod.remove_red_option(id)
		local tbl = {}
		tbl[1] = 'slmod.remove_option_net'
		tbl[2] = 'red'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
		else
			tbl[3] = id
		end
		addUDPData(tbl)
	end

	function slmod.remove_blue_option(id)
		local tbl = {}
		tbl[1] = 'slmod.remove_option_net'
		tbl[2] = 'blue'
		if type(id) == 'table' then
			local vars = id
			tbl[3] = vars['id']
		else
			tbl[3] = id
		end
		addUDPData(tbl)
	end

	function slmod.show_option_list()
		local tbl = {}
		tbl[1] = 'slmod.show_option_list_net'
		tbl[2] = 'all'
		addUDPData(tbl)
	end

	function slmod.show_red_option_list()
		local tbl = {}
		tbl[1] = 'slmod.show_option_list_net'
		tbl[2] = 'red'
		addUDPData(tbl)
	end

	function slmod.show_blue_option_list()
		local tbl = {}
		tbl[1] = 'slmod.show_option_list_net'
		tbl[2] = 'blue'
		addUDPData(tbl)
	end
	
	function slmod.set_POS_output(display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.set_POS_output_net'
		if type(display_time) == 'table' then
			tbl[2] = vars['display_time']
			tbl[3] = vars['display_mode']
			tbl[4] = vars['coa'] or vars['coalition']
		else
			tbl[2] = display_time
			tbl[3] = display_mode
			tbl[4] = coa
		end
		addUDPData(tbl)
	end
	
	function slmod.set_PTS_list_output(display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.set_PTS_list_output_net'
		if type(display_time) == 'table' then
			tbl[2] = vars['display_time']
			tbl[3] = vars['display_mode']
			tbl[4] = vars['coa'] or vars['coalition']
		else
			tbl[2] = display_time
			tbl[3] = display_mode
			tbl[4] = coa
		end
		addUDPData(tbl)
	end
	
	function slmod.set_PTS_task_output(display_time, display_mode, coa)
		local tbl = {}
		tbl[1] = 'slmod.set_PTS_task_output_net'
		if type(display_time) == 'table' then -- likely a new data passage method
			local vars = display_time
			tbl[2] = vars['display_time']
			tbl[3] = vars['display_mode']
			tbl[4] = vars['coa'] or vars['coalition']
		else
			tbl[2] = display_time
			tbl[3] = display_mode
			tbl[4] = coa
		end
		addUDPData(tbl)
	end
	
	function slmod.units_crashed(units, flag, stopflag)
		local tbl = {}
		tbl[1] = 'slmod.units_crashed_net'
		if type(units) == 'table' and flag == nil then
			local vars = units
			tbl[2] = vars['units']
			tbl[3] = vars['flag']
			tbl[4] = -1
			tbl[5] = vars['stopflag']
		else
			tbl[2] = units
			tbl[3] = flag
			tbl[4] = -1
			tbl[5] = stopflag
		end
		addUDPData(tbl)
	end
	
	function slmod.units_ejected(units, flag, stopflag)
		local tbl = {}
		tbl[1] = 'slmod.units_ejected_net'
		if type(units) == 'table' and flag == nil then
			local vars = units
			tbl[2] = vars['units']
			tbl[3] = vars['flag']
			tbl[4] = -1
			tbl[5] = vars['stopflag']
		else
			tbl[2] = units
			tbl[3] = flag
			tbl[4] = -1
			tbl[5] = stopflag
		end
		addUDPData(tbl)
	end
	
	slmod.pilots_ejected = slmod.units_ejected -- if someone gets confused, and uses slmod.pilots_ejected, there will be no error. 
	
	function slmod.units_killed_by(dead_units, killer_units, flag, stopflag, last_to_hit, time_limit)
		local tbl = {}
		tbl[1] = 'slmod.units_killed_by_net'
		if type(dead_units) == 'table' and killer_units == nil then 
			local vars = dead_units
			tbl[2] = vars['dead_units']
			tbl[3] = vars['killer_units']
			tbl[4] = vars['flag']
			tbl[5] = -1
			tbl[6] = vars['stopflag']
			tbl[7] = vars['last_to_hit']
			tbl[8] = vars['time_limit']
	
		else
			tbl[2] = dead_units
			tbl[3] = killer_units
			tbl[4] = flag
			tbl[5] = -1
			tbl[6] = stopflag
			tbl[7] = last_to_hit
			tbl[8] = time_limit
		end
		addUDPData(tbl)
	end
	
	function slmod.pilots_dead(units, flag, stopflag)
		local tbl = {}
		tbl[1] = 'pilots_dead_net'
		if type(units) == 'table' and flag == nil then
			local vars = units
			tbl[2] = vars['units'] or vars['pilots']
			tbl[3] = vars['flag']
			tbl[4] = -1
			tbl[5] = vars['stopflag']
		
		else
			tbl[2] = units
			tbl[3] = flag
			tbl[4] = -1
			tbl[5] = stopflag
		end
		addUDPData(tbl)
	end
	
	
	function slmod.weapons_impacting_in_zones(init_units, zones, weapons, flag, stopflag)
		local tbl = {}
		tbl[1] = 'slmod.weapons_impacting_in_zones_net'
		if type(init_units) == 'table' and zones == nil then
			local vars = init_units
			tbl[2] = vars['init_units'] or vars['units']
			tbl[3] = vars['zones'] or vars['zone']
			tbl[4] = vars['weapons'] or vars['weapon']
			tbl[5] = vars['flag']
			tbl[6] = vars['stopflag']
		else
			tbl[2] = init_units
			tbl[3] = zones
			tbl[4] = weapons
			tbl[5] = flag
			tbl[6] = stopflag
		end
		addUDPData(tbl)
	end

	function slmod.weapons_impacting_in_moving_zones(init_units, zone_units, radius, weapons, flag, stopflag)
		local tbl = {}
		tbl[1] = 'slmod.weapons_impacting_in_moving_zones_net'
		if type(init_units) == 'table' and zone_units == nil then
			local vars = init_units
			tbl[2] = vars['init_units'] or vars['units']
			tbl[3] = vars['zones'] or vars['zone_units'] or vars['zoneunits']
			tbl[4] = vars['radius']
			tbl[5] = vars['weapons'] or vars['weapon']
			tbl[6] = vars['flag']
			tbl[7] = vars['stopflag']
		else
			tbl[2] = init_units
			tbl[3] = zone_units
			tbl[4] = radius
			tbl[5] = weapons
			tbl[6] = flag
			tbl[7] = stopflag
		end
		addUDPData(tbl)
	end
		
	function slmod.weapons_in_zones(init_units, zones, weapons, flag, stopflag, zone_type)
		local tbl = {}
		tbl[1] = 'slmod.weapons_in_zones_net'
		if type(init_units) == 'table' and zones == nil then
			local vars = init_units
			tbl[2] = vars['init_units'] or vars['units']
			tbl[3] = vars['zones'] or vars['zone']
			tbl[4] = vars['weapons'] or vars['weapon']
			tbl[5] = vars['flag']
			tbl[6] = vars['stopflag']
			tbl[7] = vars['zone_type'] or vars['zonetype']
		else
			tbl[2] = init_units
			tbl[3] = zones
			tbl[4] = weapons
			tbl[5] = flag
			tbl[6] = stopflag
			tbl[7] = zone_type
		end
		addUDPData(tbl)
	end
	
	function slmod.weapons_in_moving_zones(init_units, zone_units, radius, weapons, flag, stopflag, zone_type)
		local tbl = {}
		tbl[1] = 'slmod.weapons_in_moving_zones_net'
		if type(init_units) == 'table' and zone_units == nil then
			local vars = init_units
			tbl[2] = vars['init_units'] or vars['units']
			tbl[3] = vars['zones'] or vars['zone_units'] or vars['zoneunits']
			tbl[4] = vars['radius']
			tbl[5] = vars['weapons'] or vars['weapon']
			tbl[6] = vars['flag']
			tbl[7] = vars['stopflag']
			tbl[8] = vars['zone_type'] or vars['zonetype']
		else
			tbl[2] = init_units
			tbl[3] = zone_units
			tbl[4] = radius
			tbl[5] = weapons
			tbl[6] = flag
			tbl[7] = stopflag
			tbl[8] = zone_type
		end
		addUDPData(tbl)
	end
	
	function slmod.units_in_moving_zones(units, zone_units, zone_radius, flag, stopflag, zone_type, req_num, interval)
		local tbl = {}
		tbl[1] = 'slmod.units_in_moving_zones_net'
		if type(units) == 'table' and zone_units == nil then
			local vars = units
			tbl[2] = vars['units']
			tbl[3] = vars['zone_units'] or vars['zoneunits']
			tbl[4] = vars['zone_radius'] or vars['radius'] or vars['zoneradius']
			tbl[5] = vars['flag']
			tbl[6] = vars['stopflag']
			tbl[7] = vars['zone_type'] or vars['zonetype']
			tbl[8] = vars['req_num'] or vars['num_req'] or vars['reqnum'] or vars['numreq']
			tbl[9] = vars['interval']
		
		else
			tbl[2] = units
			tbl[3] = zone_units
			tbl[4] = zone_radius
			tbl[5] = flag
			tbl[6] = stopflag
			tbl[7] = zone_type
			tbl[8] = req_num
			tbl[9] = interval
		end
		addUDPData(tbl)
	end
	
	
	function slmod.units_in_zones(units, zones, flag, stopflag, zone_type, req_num, interval)
		local tbl = {}
		tbl[1] = 'slmod.units_in_zones_net'
		if type(units) == 'table' and zones == nil then
			local vars = units
			tbl[2] = vars['units']
			tbl[3] = vars['zones']
			tbl[4] = vars['flag']
			tbl[5] = vars['stopflag']
			tbl[6] = vars['zone_type'] or vars['zonetype']
			tbl[7] = vars['req_num'] or vars['num_req'] or vars['reqnum'] or vars['numreq']
			tbl[8] = vars['interval']
		
		else
			tbl[2] = units
			tbl[3] = zones
			tbl[4] = flag
			tbl[5] = stopflag
			tbl[6] = zone_type
			tbl[7] = req_num
			tbl[8] = interval
		end
		addUDPData(tbl)
	end
	
	function slmod.CA_chatmsg(text, coa)
		local tbl = {}
		tbl[1] = 'slmod.CA_chatmsg_net'
		if type(text) == 'table' then
			local vars = text
			tbl[2] = vars['text'] or vars['text_out'] or vars['msg']
			tbl[3] = vars['coa'] or vars['coalition']
		else
			tbl[2] = text
			tbl[3] = coa
		end
		addUDPData(tbl)
	end
	
	-----------------------------------------------------------------------------------------------
	-- A function for Lua mod developers.  
	function slmod.dump_Gs()
		local ScriptRuntime_G = slmod.tableshow(_G, '["_G"]')
		local tbl = {}
		tbl[1] = 'slmod.dump_Gs_net'
		tbl[2] = ScriptRuntime_G
		tbl[3] = slmod.MissionScripting_G
		addUDPData(tbl)
	end


    function slmod.customStat(custom)
        local tbl = {}
        tbl[1] = 'slmod.custom_stats_net'
        tbl[2] = custom
        
        addUDPData(tbl)
    end
    
    function slmod.setCampaign(name, new)
        local tbl = {}
        tbl[1] = 'slmod.set_campaign_net'
        tbl[2] = name
        tbl[3] = new
        
        addUDPData(tbl)
    end
    
    
    function slmod.missionAdminAction(id, action, reason)
        local tbl = {}
        tbl[1] = 'slmod.mission_admin_action'
        tbl[2] = id
        tbl[3] = action
        tbl[4] = reason
        
        addUDPData(tbl)
    end
	
	Slmod = slmod -- if someone accidentally uses Slmod, it works.
	
	slmod.MissionScripting_G = slmod.tableshow(_G, '["_G"]') -- do last in case there is a problem
	
	
	--sanitizeModule('debug')  -- So malicious missions can't break out of the sandbox and use LuaSocket.
	env.info('MissionScripting.lua SLMOD code loaded')
end
-------------------------------------------------------------------------------------
--Stepanovich's code starts again below.
do
	sanitizeModule('os')
	sanitizeModule('io')
	sanitizeModule('lfs')
	require = nil
	loadlib = nil
end