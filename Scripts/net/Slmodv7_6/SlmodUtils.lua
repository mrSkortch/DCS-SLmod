--Slmod Task Scheduler

do
	local Tasks = {}
	
	-- formerly schedule_task
	function slmod.scheduleFunction(f, vars, t) -- pass vars is a table of all the variables, needs to be in the same order as they are placed into the function.
		table.insert(Tasks, {f = f, vars = vars, t = t})
	end
	
	-- formerly slmod.scheduleFunction_by_realtime
	function slmod.scheduleFunctionByRt(f, vars, rt) -- pass vars is a table of all the variables, needs to be in the same order as they are placed into the function.
		table.insert(Tasks, {f = f, vars = vars, rt = rt})
	end
	
	-- formerly do_scheduled_tasks
	function slmod.doTasks()
		local i = 1
		while i <= #Tasks do
			if Tasks[i].t then -- task scheduled by model time
				if Tasks[i].t <= DCS.getModelTime() then -- examine using model time!
					local Task = Tasks[i]  -- local reference
					table.remove(Tasks, i) -- remove the task from the Tasks table
					local err, errmsg = pcall(Task.f, unpack(Task.vars, 1, table.maxn(Task.vars)))
					if not err then
						slmod.error('slmod.scheduleFunction, error in scheduled function: ' .. errmsg)
					end
				else
					i = i + 1
				end
			else  -- task must have been scheduled by real time
				if Tasks[i].rt <= DCS.getRealTime() then -- examine using real time rather than model time!
					local Task = Tasks[i]  -- local reference
					table.remove(Tasks, i) -- remove the task from the Tasks table
					--Task.f(unpack(Task.vars, 1, table.maxn(Task.vars)))
					local err, errmsg = pcall(Task.f, unpack(Task.vars, 1, table.maxn(Task.vars)))
					if not err then
						slmod.error('slmod.scheduleFunctionByRt, error in scheduled function: ' .. errmsg)
					end
				else
					i = i + 1
				end
			end
		end
	end
	
	function slmod.resetScheduledFunctions()
		Tasks = {}
	end
end
-----------------------------------------------------------------------------------------
function slmod.reset_randseed()
	--Setting up random nums
	slmod.randseed = os.time()- slmod.round(os.time(), -4) 
	slmod.info('using random seed ' .. tostring(slmod.randseed))
	math.randomseed(slmod.randseed)
	math.random()  --pop the first few randoms off
	math.random()
	math.random()
end


--Make the dostring function for the net environment, I will actually leave this one in global env.
function dostring(s)
	local f, err = loadstring(s)
	if f then
		return true, f()
	else
		slmod.error('dostring error in string: ' .. err)
		return false
	end
end

--Creates the round function, needed for chatIOlib operation
do
	-- From http://lua-users.org/wiki/SimpleRound
	-- use negative idp for rounding ahead of decimal place, positive for rounding after decimal place
	local roundstring = [[slmod = slmod or {}
function slmod.round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end]]
	dostring(roundstring)
	function slmod.create_round()
		net.dostring_in("mission", roundstring)
		net.dostring_in("server", roundstring)
		net.dostring_in("config", roundstring)
		net.dostring_in("export", roundstring)
		
	end
end

function slmod.deserializeValue(s)  -- returns the "deserialized" value if s is serialized value
	local f, errmsg = loadstring(s)
	if not f then  -- there was a compilation error when trying to interpret the string s as Lua code.
		slmod.error('slmod.deserializeValue: compilation error: ' .. tostring(errmsg))
		return nil, errmsg
	else
		--Now, set f to run in a local environment, so that it does not run f in the global environment.
		local env = {}
		setfenv(f, env) 
		
		local err, errmsg = pcall(f)  -- run f safely so if there is a Lua runtime error, it will not raise an error.
		if not err then
			slmod.error('slmod.deserializeValue: runtime error: ' .. tostring(errmsg))
			return nil, errmsg
		else --[[No error, so return the first value in the table env- we're assuming that s was only the 
				 serialization of a single value.]]
			local ind, val = next(env)
			return val
		end
	end
end


------------------------------------------------------------------
--Dostring scheduler- almost completely obsolete now.
--Will add passed strings to the dostring_table upvalue
do

	local dostring_table = {}  -- table that holds all the dostrings.
	
	function slmod.schedule_dostring_in(environment, lua_string, time_scheduled)

	--five valid environments:
	--"net"
	--"server"
	--"mission"
	--"export"
	--"config"
		if ((environment == "net") or (environment == "server") or (environment == "mission") or (environment == "export") or (environment == "config")) then
			local t = { env = environment, str = lua_string, modeltime = time_scheduled }
			table.insert(dostring_table, t)
		end

	end

	function slmod.repeat_dostring_in(env, s, interval) -- just overload slmod.schedule_dostring_in to accept a "repeat_inv" or something and this function can be eliminated.
		net.dostring_in(env, s)
		--net.log('slmod.repeat_dostring_in(\'' .. env .. '\', ' .. slmod.basicSerialize(s) .. ', ' .. tostring(interval) .. ')')
		slmod.schedule_dostring_in('net', 'slmod.repeat_dostring_in(\'' .. env .. '\', ' .. slmod.basicSerialize(s) .. ', ' .. tostring(interval) .. ')', DCS.getModelTime() + interval)
		
	end

	--Checks dostring_table, and if it is time to do any scheduled strings, do em.  Remove from table before doing in case the string has an error
	function slmod.do_scheduled_strings()
		if dostring_table ~= nil then

			local tbl_ind = 1
			while  tbl_ind <= #dostring_table do

				if dostring_table[tbl_ind].modeltime ~= nil then
					if dostring_table[tbl_ind].modeltime <= DCS.getModelTime() then  --time to do this string
						if dostring_table[tbl_ind].env == "net" then
							--net.log('doing in net: ' .. dostring_table[tbl_ind].str)
							local lstr = dostring_table[tbl_ind].str
							table.remove(dostring_table, tbl_ind) --remove BEFORE running the code!!!!  Otherwise will error out, and just run the code against next pass!!!
							tbl_ind = tbl_ind - 1
							dostring(lstr)
						elseif ((dostring_table[tbl_ind].env == "server") or (dostring_table[tbl_ind].env == "mission") or (dostring_table[tbl_ind].env == "export") or (dostring_table[tbl_ind].env == "config")) then
							--net.log('doing in ' .. dostring_table[tbl_ind].env .. ': ' .. dostring_table[tbl_ind].str)
							
							local lstr = dostring_table[tbl_ind].str
							local lenv = dostring_table[tbl_ind].env
							table.remove(dostring_table, tbl_ind) --remove BEFORE running the code.  Shouldn't be necessary in other environments, but why not?
							tbl_ind = tbl_ind - 1
							
							local errstr, err = net.dostring_in(lenv, lstr)
			
							if err == false then -- dostring failed in other env
								slmod.error('dostring failure: ' .. errstr .. ' (in ' .. lenv .. ' environment.)') -- report the error
							end			
						else
							slmod.warning('invalid environment requested for dostring')
							table.remove(dostring_table, tbl_ind)
							tbl_ind = tbl_ind - 1
						end	
					end	
				else
					slmod.warning('dostring error: nil modeltime')
					table.remove(dostring_table, tbl_ind)
					tbl_ind = tbl_ind - 1		
				end
				tbl_ind = tbl_ind + 1
			end
		end
	end

	function slmod.reset_dostring_table()
		dostring_table = {}
	end


end
-------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------------
-- Other environment functions, these functions operate or support operation in other environments (other than net), most are beginning components of end user
-- functions.

--slmod.create_in_export
--[[
Because mods like TARS can interfere with the export environment, it might be necessary to attempt to recreate a function in it 
multiple times. Note: Function string cannot have 10th level long string enclosures: [==========[ or ]==========]
fs =  function string
msg = function name, optional, only for debugging purposes.
]]
function slmod.create_in_export(fs, msg)
	local success, load_success = net.dostring_in('export', fs)	
	--If load failed, keep re-trying to load until successful
	if load_success == false then
		slmod.warning('unable to load ' .. tostring(msg) .. ' into export, scheduling reattempt.')
		if msg == nil then
			slmod.schedule_dostring_in('net', 'slmod.create_in_export([==========[' .. fs .. ']==========])', DCS.getModelTime() + 0.1)
		elseif type(msg) == 'string' then
			slmod.schedule_dostring_in('net', 'slmod.create_in_export([==========[' .. fs .. [[]==========], ']] .. msg .. [[')]], DCS.getModelTime() + 0.1)
		end
	else
		slmod.info('successfully loaded (name = ' .. tostring(msg) .. ') function into export.')	
	end
end

do
	local basicSerialize_string = [[slmod = slmod or {}
function slmod.basicSerialize(s)
	if s == nil then
		return "\"\""
	else
		if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
			return tostring(s)
		elseif type(s) == 'string' then
			return string.format('%q', s)
		end
	end	
end]]

	dostring(basicSerialize_string)
	
	function slmod.create_basicSerialize()
		--create in other environments
		net.dostring_in('mission', basicSerialize_string)
		net.dostring_in('server', basicSerialize_string)
		net.dostring_in('config', basicSerialize_string)
		slmod.create_in_export(basicSerialize_string, 'slmod.basicSerialize')

	end
end

--Should be able to replace next chance I get with the new coord function(s)
function slmod.create_LLtoLO()

	local LLtoLO_string = [[-- server env
slmod = slmod or {}
function slmod.LLtoLO(coord_table)
	local lat_deg = coord_table.lat
	local lon_deg = coord_table.lon
	local k_lat = 111300   -- 111300 meters/deg
	
	--first estimate of xc and zc
	local x_est = (lat_deg - 42.32865)*k_lat - 274428.57
	
	local k_lon = math.cos(lat_deg*2*math.pi/360)*k_lat
	
	local z_est = (lon_deg - 41.7715167)*k_lon + 623428.57
	
	local est_tbl = { x = x_est, y = 0, z = z_est }
	local est_coords = {}
	est_coords.lat, est_coords.lon = coord.LOtoLL(est_tbl)
	local lat_err = est_coords.lat - lat_deg
	local lon_err = est_coords.lon - lon_deg
	
	local iteration_count = 0
	
	while (((math.abs(lat_err) > 0.5e-6) or (math.abs(lon_err) > 0.5e-6)) and (iteration_count < 15)) do
	
		local x_correction = -lat_err*k_lat
		local z_correction = -lon_err*k_lon
		
		x_est = x_est + x_correction
		z_est = z_est + z_correction

		est_tbl = { x = x_est, y = 0, z = z_est }
		est_coords.lat, est_coords.lon = coord.LOtoLL(est_tbl)
		
		lat_err = est_coords.lat - lat_deg
		lon_err = est_coords.lon - lon_deg
		
		iteration_count = iteration_count + 1
	end

	return est_tbl

end]]

	net.dostring_in('server', LLtoLO_string)
end


------------------------------------------------------------------------------------------------------------------
-- General, multi-env support functions

do
	local serialize_string = [=[slmod = slmod or {}
function slmod.serialize(name, value, level)
	-----Based on ED's serialize_simple2
	local basicSerialize = function (o)
	  if type(o) == "number" then
		return tostring(o)
	  elseif type(o) == "boolean" then
		return tostring(o)
	  else -- assume it is a string
		return slmod.basicSerialize(o)
	  end
	end
	
	local serialize_to_t = function (name, value, level)
	----Based on ED's serialize_simple2


	  local var_str_tbl = {}
	  if level == nil then level = "" end
	  if level ~= "" then level = level.."  " end
	  
	  table.insert(var_str_tbl, level .. name .. " = ")
	  
	  if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
		table.insert(var_str_tbl, basicSerialize(value) ..  ",\n")
	  elseif type(value) == "table" then
		  table.insert(var_str_tbl, "\n"..level.."{\n")
		  
		  for k,v in pairs(value) do -- serialize its fields
			local key
			if type(k) == "number" then
			  key = string.format("[%s]", k)
			else
			  key = string.format("[%q]", k)
			end

			table.insert(var_str_tbl, slmod.serialize(key, v, level.."  "))

		  end
		  if level == "" then
			table.insert(var_str_tbl, level.."} -- end of "..name.."\n")

		  else
			table.insert(var_str_tbl, level.."}, -- end of "..name.."\n")

		  end
	  else
		net.log("Cannot serialize a "..type(value))
	  end
	  return var_str_tbl
	end
	
	local t_str = serialize_to_t(name, value, level)
	
	return table.concat(t_str)
end]=]


	dostring(serialize_string)

	function slmod.create_serialize()
		----create in other four environments
		net.dostring_in('mission', serialize_string)
		net.dostring_in('server', serialize_string)
		net.dostring_in('config', serialize_string)
		slmod.create_in_export(serialize_string, 'slmod.serialize')

	end
end




do
	local serializeWithCycles_string = [=[--mostly straight out of Programming in Lua
slmod = slmod or {}
function slmod.serializeWithCycles(name, value, saved)
	local basicSerialize = function (o)
		if type(o) == "number" then
			return tostring(o)
		elseif type(o) == "boolean" then
			return tostring(o)
		else -- assume it is a string
			return slmod.basicSerialize(o)
		end
	end
	
	local t_str = {}
	saved = saved or {}       -- initial value
	if ((type(value) == 'string') or (type(value) == 'number') or (type(value) == 'table') or (type(value) == 'boolean')) then
		table.insert(t_str, name .. " = ")
		if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
			table.insert(t_str, basicSerialize(value) ..  "\n")
		else

			if saved[value] then    -- value already saved?
				table.insert(t_str, saved[value] .. "\n")
			else
				saved[value] = name   -- save name for next time
				table.insert(t_str, "{}\n")
				for k,v in pairs(value) do      -- save its fields
					local fieldname = string.format("%s[%s]", name, basicSerialize(k))
					table.insert(t_str, slmod.serializeWithCycles(fieldname, v, saved))
				end
			end
		end
		return table.concat(t_str)
	else
		return ""
	end
end]=]
	dostring(serializeWithCycles_string)

	function slmod.create_serializeWithCycles()
		----create in other four environments
		net.dostring_in('mission', serializeWithCycles_string)
		net.dostring_in('server', serializeWithCycles_string)
		net.dostring_in('config', serializeWithCycles_string)
		slmod.create_in_export(serializeWithCycles_string, 'slmod.serializeWithCycles')
	end
end



do
		local oneLineSerialize_string = [=[slmod = slmod or {}
function slmod.oneLineSerialize(tbl) -- serialization on a single line, no comments
	if type(tbl) == 'table' then 

		local tbl_str = {}

		tbl_str[#tbl_str + 1] = '{ '
		
		for ind,val in pairs(tbl) do -- serialize its fields
			if type(ind) == "number" then
				tbl_str[#tbl_str + 1] = '[' 
				tbl_str[#tbl_str + 1] = tostring(ind)
				tbl_str[#tbl_str + 1] = '] = '
			else --must be a string
				tbl_str[#tbl_str + 1] = '[' 
				tbl_str[#tbl_str + 1] = slmod.basicSerialize(ind)
				tbl_str[#tbl_str + 1] = '] = '
			end
				
			if ((type(val) == 'number') or (type(val) == 'boolean')) then
				tbl_str[#tbl_str + 1] = tostring(val)
				tbl_str[#tbl_str + 1] = ', '		
			elseif type(val) == 'string' then
				tbl_str[#tbl_str + 1] = slmod.basicSerialize(val)
				tbl_str[#tbl_str + 1] = ', '
			elseif type(val) == 'nil' then -- won't ever happen, right?
				tbl_str[#tbl_str + 1] = 'nil, '
			elseif type(val) == 'table' then
				tbl_str[#tbl_str + 1] = slmod.oneLineSerialize(val)
				tbl_str[#tbl_str + 1] = ', '
			else
				net.log('slmod: slmod.oneLineSerialize: unable to serialize value type ' .. slmod.basicSerialize(type(val)) .. ' at index ' .. tostring(ind))
			end
		
		end
		
		tbl_str[#tbl_str + 1] = '}'
		return table.concat(tbl_str)
	elseif type(tbl) == 'string' then
		return slmod.basicSerialize(tbl)
	else
		return tostring(tbl)
	end
end]=]
	dostring(oneLineSerialize_string)
	
	function slmod.create_oneLineSerialize()

		--create in other four environments
		net.dostring_in('mission', oneLineSerialize_string)
		net.dostring_in('server', oneLineSerialize_string)
		net.dostring_in('config', oneLineSerialize_string)
		slmod.create_in_export(oneLineSerialize_string, 'slmod.oneLineSerialize')

	end

end

do
	--from http://lua-users.org/wiki/CopyTable
	local deepcopy_string = [=[slmod = slmod or {}
function slmod.deepcopy(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end]=]
	dostring(deepcopy_string)
	
	function slmod.create_deepcopy()
		--create in other four environments
		net.dostring_in('mission', deepcopy_string)
		net.dostring_in('server', deepcopy_string)
		net.dostring_in('config', deepcopy_string)
		slmod.create_in_export(deepcopy_string, 'slmod.deepcopy')
		
	end
end
------------------------------------------------------------------------------------------------------------------------------
--stuff for showing the contents of tables, NOT serialization

do
	local tableshow_string = [=[slmod = slmod or {}
--Function to create string for viewing the contents of a table -NOT for serialization
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
				tbl_str[#tbl_str + 1] = slmod.basicSerialize(ind)
				tbl_str[#tbl_str + 1] = '] = '
			end
					
			if ((type(val) == 'number') or (type(val) == 'boolean')) then
				tbl_str[#tbl_str + 1] = tostring(val)
				tbl_str[#tbl_str + 1] = ',\n'		
			elseif type(val) == 'string' then
				tbl_str[#tbl_str + 1] = slmod.basicSerialize(val)
				tbl_str[#tbl_str + 1] = ',\n'
			elseif type(val) == 'nil' then -- won't ever happen, right?
				tbl_str[#tbl_str + 1] = 'nil,\n'
			elseif type(val) == 'table' then
				if tableshow_tbls[val] then
					tbl_str[#tbl_str + 1] = tostring(val) .. ' already defined: ' .. tableshow_tbls[val] .. ',\n'
				else
					tableshow_tbls[val] = loc ..  '[' .. slmod.basicSerialize(ind) .. ']'
					tbl_str[#tbl_str + 1] = tostring(val) .. ' '
					tbl_str[#tbl_str + 1] = slmod.tableshow(val,  loc .. '[' .. slmod.basicSerialize(ind).. ']', indent .. '    ', tableshow_tbls)
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
				tbl_str[#tbl_str + 1] = 'unable to serialize value type ' .. slmod.basicSerialize(type(val)) .. ' at index ' .. tostring(ind)
			end
		end
		
		tbl_str[#tbl_str + 1] = indent .. '}'
		return table.concat(tbl_str)
	end
end]=]


	dostring(tableshow_string)

	function slmod.create_tableshow()
		--create in other four environments
		net.dostring_in('mission', tableshow_string)
		net.dostring_in('server', tableshow_string)
		net.dostring_in('config', tableshow_string)
		slmod.create_in_export(tableshow_string, 'slmod.tableshow')

	end
end


--Function to create string for viewing the contents of a table -NOT for serialization  -- REDUNDANT?  NEEDS TO BE DELETED?
function slmod.tableprint(tbl, loc, indent, tableshow_tbls) --based on slmod.serialize, this is a _G serialization
	tableshow_tbls = tableshow_tbls or {} --create table of tables
	loc = loc or ""
	indent = indent or ""
	if type(tbl) == 'table' then --function only works for tables!

		net.log(indent .. '{')
		
		for ind,val in pairs(tbl) do -- serialize its fields
			local line = ''
			if type(ind) == "number" then
				line = line .. indent .. loc .. '[' .. tostring(ind) .. '] = '
			else --must be a string
				line = line .. indent .. loc .. '[' .. slmod.basicSerialize(ind) .. '] = '
			end
					
			if ((type(val) == 'number') or (type(val) == 'boolean')) then
				line = line .. tostring(val) .. ','
				net.log(line)
			elseif type(val) == 'string' then
				line = line .. slmod.basicSerialize(val) .. ','
				net.log(line)
			elseif type(val) == 'nil' then -- won't ever happen, right?
				line = line .. 'nil,'
				net.log(line)
			elseif type(val) == 'table' then
				if tableshow_tbls[val] then
					line = line .. tostring(val) .. ' already defined: ' .. tableshow_tbls[val] .. ','
					net.log(line)
				else
					tableshow_tbls[val] = loc ..  '[' .. slmod.basicSerialize(ind) .. ']'
					line = line .. tostring(val) .. ' '
					net.log(line)
					slmod.tableprint(val,  loc .. '[' .. slmod.basicSerialize(ind).. ']', indent .. '    ', tableshow_tbls)
				end
			elseif type(val) == 'function' then
				if debug and debug.getinfo then
					fcnname = tostring(val)
					local info = debug.getinfo(val, "S")
					if info.what == "C" then
						line = line .. string.format('%q', fcnname .. ', C function') .. ','
						net.log(line)
					else 
						if (string.sub(info.source, 1, 2) == [[./]]) then
							line = line .. string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')' .. info.source) ..','
							net.log(line)
						else
							line = line .. string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')') ..','
							net.log(line)
						end
					end
					
				else
					line = line .. 'a function,'
					net.log(line)
					
				end
			else
				net.log('slmod: slmod.tableprint: unable to serialize value type ' .. slmod.basicSerialize(type(val)) .. ' at index ' .. tostring(ind))
			end
		end
		net.log(indent .. '},')
	end
end



-------------------------------------------------------------------------------------------------------------
-- net environment components



-----------------------------------------------------------------------------------
--testing function.  Saves the variable named vName in 'server' to a file in Saved Games\A-10C\Logs named vName
function slmod.save_var(eName, fName, vName, lvName)
	local Loc = lfs.writedir() .. [[Logs\]] .. fName
	if eName ~= 'net' then
		local exec_str = 'var_out_file = io.open([[' .. Loc .. ']], \'w\');' .. ' var_out_file:write(slmod.serialize(\''  .. vName .. '\', ' .. vName .. ', \'\')); var_out_file:close()'
		net.dostring_in(eName, exec_str)
	else
		lvName = lvName or 'Unknown_Variable_Name'
		var_out_file = io.open(Loc, 'w')
		var_out_file:write(slmod.serialize(lvName, vName, ''))
		var_out_file:close()
	
	end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------

	
-- runtime ID.  Returns the unit information from slmod.activeUnits or slmod.oldActiveUnits (if not in slmod.activeUnits) for this id
function slmod.getUnitById(id) 
	if slmod.activeUnits and slmod.activeUnits[id] then
		return slmod.activeUnits[id]
	elseif slmod.oldActiveUnits and slmod.oldActiveUnits[id] then -- if not in slmod.activeUnits, search slmod.oldActiveUnits
		return slmod.oldActiveUnits[id]
	else
		return 'no_unit'  --might want to think about switching this to nil
	end
end	
	
-- mission editor name.  Returns the unit information from slmod.activeUnits or slmod.oldActiveUnits (if not in slmod.activeUnits) for this name
function slmod.getUnitByName(name)
	if slmod.activeUnitsByName and slmod.activeUnitsByName[name] then
        return slmod.activeUnitsByName[name]
	end
	
	if slmod.oldActiveUnitsByName and slmod.oldActiveUnitsByName[name] then
        return slmod.oldActiveUnitsByName[name]
	end
	
end	

function slmod.flagIsTrue(flag)
	if tonumber(flag) > 0 then
		local ret_str, ret_bool = net.dostring_in('mission', 'return tostring(c_flag_is_true(' .. tostring(flag) .. '))')
		if ret_bool then
			if ret_str == 'true' then
				return true
			elseif ret_str == 'false' then
				return false
			end
		end
	else
		return false
	end
end


function slmod.typeCheck(type_tbl, var_tbl)
	-- type_tbl example format: { {'table_n', 'number'}, 'string', 'number', 'number', {'string', 'nil'}, {'number', 'nil'} }
	--Each separate entry in type_tbl is the acceptable type of corresponding entry in var_tbl.  The character * such as '*string' indicates a table has all strings in it
	local check_passed = true
	if ((type(type_tbl) == 'table') and (type(var_tbl) == 'table')) then
		for type_tbl_ind = 1, #type_tbl do
			if type(type_tbl[type_tbl_ind]) == 'table' then
				local one_passed_check = false
				for j = 1, #type_tbl[type_tbl_ind] do
					local passed_type_tbl
					local passed_var_tbl
					if ((type_tbl[type_tbl_ind][j] == 'table_s') or (type_tbl[type_tbl_ind][j] == 'table_n')) then
						passed_type_tbl = {type_tbl[type_tbl_ind][j]}
						passed_var_tbl = {var_tbl[type_tbl_ind]}
					else
						passed_type_tbl = type_tbl[type_tbl_ind][j]
						passed_var_tbl = var_tbl[type_tbl_ind]
					end
					if slmod.typeCheck(passed_type_tbl, passed_var_tbl) then 
						one_passed_check = true
					end

				end
				if one_passed_check == false then
					check_passed = false
				end
			elseif type_tbl[type_tbl_ind] == 'table_s' then --table of strings
				if type(var_tbl[type_tbl_ind]) == 'table' then
					for i = 1, #var_tbl[type_tbl_ind] do
						if type(var_tbl[type_tbl_ind][i]) ~= 'string' then
							check_passed = false
						end		
					end
				else
					check_passed = false
				end
			elseif type_tbl[type_tbl_ind] == 'table_n' then --table of numbers
				if type(var_tbl[type_tbl_ind]) == 'table' then
					for i = 1, #var_tbl[type_tbl_ind] do
						if type(var_tbl[type_tbl_ind][i]) ~= 'number' then
							check_passed = false
						end		
					end
				else
					check_passed = false
				end
			elseif type_tbl[type_tbl_ind] == 'table_b' then --table of booleans
				if type(var_tbl[type_tbl_ind]) == 'table' then
					for i = 1, #var_tbl[type_tbl_ind] do
						if type(var_tbl[type_tbl_ind][i]) ~= 'boolean' then
							check_passed = false
						end		
					end
				else
					check_passed = false
				end
				
			elseif type(var_tbl[type_tbl_ind]) ~= type_tbl[type_tbl_ind] then
				check_passed = false
			end
		end
	elseif type(var_tbl) ~= type_tbl then
		check_passed = false
	end
	return check_passed
end


function slmod.getZoneByName(name)
	for zone_ind = 1, #slmod.me_zones do
		if slmod.me_zones[zone_ind].name == name then
			local zone_tbl = slmod.me_zones[zone_ind]
			return zone_tbl
		end
	end
end


function slmod.importMissionZones()  -- I would bring the whole mission in... but its a lot of data and it locks up lua dostring().  Perhaps if I used dostring line by line?
	local zones_str, bool_err = net.dostring_in('mission', 'return slmod.serializeWithCycles(\'slmod.me_zones\', mission[\'triggers\'][\'zones\'])')
	if bool_err then
		-- local Loc = lfs.writedir() .. [[Logs\]] .. 'zones_str.txt'
		-- local f = io.open(Loc, 'w')
		-- f:write(zones_str)
		-- f:close()
		--slmod.save_var('net', 'zones_str.txt', zones_str, 'zones_str')
		slmod.me_zones = nil
		dostring(zones_str)
		if type(slmod.me_zones) == 'table' then
			slmod.info('slmod.importMissionZones: zones successfully loaded to net environment.')
			--now, change y into z for main x,y,z format
			for i = 1, #slmod.me_zones do
				slmod.me_zones[i]['z'] = slmod.me_zones[i].y
				slmod.me_zones[i].y = nil
			end
			
			--slmod.save_var('net', 'slmod.me_zones.txt', slmod.me_zones, 'slmod.me_zones')
		else
			--slmod.error('slmod: error?: failed to create slmod.me_zones table in slmod.importMissionZones(), ignore this message if the mission has no zones')
			slmod.me_zones = {} --reset 
		end
	else
		slmod.error('failed to get zones from mission environment in slmod.importMissionZones(), reason: ' .. tostring(zones_str))
		slmod.me_zones = {} --reset 	
	end

end


--------------------------------------------------------------------------------------------------------------------------------------------------------------
--Rebuild of chat IO

function slmod.basicChat(msg, coa)  --new internal function for generating chat, not usable by mission builders
	coa = coa or 'all'
	
	local destcoa = 0  --initialize for message to all
	if coa == 'red' then
		destcoa = 1
	elseif coa == 'blue' then
		destcoa = 2
	end
	
	local side = net.get_player_info(1, 'side')
	if ((destcoa == 0) or ((type(side) == 'number') and (side == destcoa))) then
		net.recv_chat(msg)  -- send to host
	end
	
	for i = 2, 200 do  --hopefully client index never gets above 200!  I guess there is not a table of clients anywhere, at least, I can't find it! This is kinda sloppy, maybe I need to log client indexes as they connect so I know for sure what the max index is?
		local side = net.get_player_info(i, 'side')
		if ((destcoa == 0) or ((type(side) == 'number') and (side == destcoa))) then
			net.send_chat_to(msg, i, i)
		end
	end	
end

function slmod.basicChatRepeat(msg, numtimes, interval, coa)  --new internal function for repeating chat, not usable by mission builders
	coa = coa or 'all'
	slmod.basicChat(msg, coa)
	numtimes = numtimes - 1
	while numtimes > 0 do
		slmod.scheduleFunction(slmod.basicChat, {msg, coa}, DCS.getModelTime() + numtimes*interval)
		numtimes = numtimes - 1
	end
end

function slmod.triggerText(msg, display_time, coa) --new internal function for generating trigger text, not usable by mission builders
	coa = coa or 'all'
	if coa == 'red' then
		net.dostring_in('mission', 'a_out_text_delay_s(\'red\', ' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
	elseif coa == 'blue' then
		net.dostring_in('mission', 'a_out_text_delay_s(\'blue\', ' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
	else
		net.dostring_in('mission', 'a_out_text_delay(' ..  slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
	end
end

-----------------------------------------------------------------------------------------------
-- Chat/text out built for the SlmodMenu system.

function slmod.clientInScope(client_id, scope)  
	--[[ id is the multiplayer client id, scope is table like this: 
	{ coa = string, units = {[1] = runtime_id, [2] = runtime_id, [3] = string}, clients = { [1] = client_num, [2] = clientnum}}

	Function returns true of Client with client_id is in scope]]
	local client_rtid
	local client_unitname
	local client_coa 
	do
		local side = net.get_player_info(client_id, 'side')
		local unit_id = net.get_player_info(client_id, 'slot')
		if side then
			if tonumber(side) == 0 then
				client_coa = 'spec'
			elseif tonumber(side) == 1 then
				client_coa = 'red'
			elseif tonumber(side) == 2 then
				client_coa = 'blue'
			end
		end
		if unit_id then
			unit_id = tonumber(unit_id)
			if unit_id and unit_id > 0 then  --making sure it successfully converted, and it's a reasonable value
				client_rtid = DCS.getUnitProperty(unit_id, 1)
				client_unitname = DCS.getUnitProperty(unit_id, 3)
			end
		end
	end

	for cat, val  in pairs(scope) do
		if cat == 'coa' and (val == client_coa or val == 'all') then
			return true
		end
		if cat == 'clients' then
			for ind,id in pairs(val) do
				if id == client_id then
					return true
				end
			end
		end
		if cat == 'units' then
			for ind, unit in pairs(val) do
				if type(unit) == 'string' then
					if unit == client_unitname then
						return true
					end
				end
				if type(unit) == 'number' then
					if unit == client_rtid then
						return true
					end
				end
			end
		end
	end
	return false  -- search done, no match in scope.
end


-- New function: slmod.scopeMsg(text_out, display_time, display_mode, to)  -- to is the new variable that is a table of vars: { coas = {}, clients = {}, units = {} }

function slmod.scopeChat(msg, scope, numtimes, interval)  --new internal function for generating specific chat
	scope = scope or {} -- to avoid a lua error in case of no nil scope
	--scope = { coa = string, clients = {}, units = {}}
	if slmod.clientInScope(1, scope) then
		net.recv_chat(msg)  -- send to host
	end
	
	for i = 2, 200 do  -- at some point, I may need to revisit this assumption about clients id not getting higher than 200.. there is no clients table at the moment- make one?
		if slmod.clients[i] and slmod.clientInScope(i, scope) then
			net.send_chat_to(msg, i, 1)
		end
	end
	
	if numtimes and interval then --repeat chat message
		numtimes = numtimes - 1
		while numtimes > 0 do
			--slmod.scheduleFunction(slmod.scopeChat, {msg, scope}, DCS.getModelTime() + numtimes*interval)
			slmod.scheduleFunctionByRt(slmod.scopeChat, {msg, scope}, DCS.getRealTime() + numtimes*interval) -- now using realtime.
			numtimes = numtimes - 1
		end
	end
end


function slmod.scopeText(msg, display_time, scope)
	display_time = display_time or 10
	scope = scope or {} -- to avoid a lua error in case of no nil scope
	--scope = { coa = string, clients = {}, units = {}}
	--not a problem is trigger text is sent twice
	if scope.coa then 
		if scope.coa == 'all' then
			net.dostring_in('mission', 'a_out_text_delay(' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
		elseif scope.coa == 'red' then
			net.dostring_in('mission', 'a_out_text_delay_s(\'red\', ' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
		elseif scope.coa == 'blue' then
			net.dostring_in('mission', 'a_out_text_delay_s(\'blue\', ' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
		end
	end
	-- if scope.countries then
	
	-- end
	
	if scope.clients then
		for i = 1, #scope.clients do
			local groupId = slmod.getClientGroupId(scope.clients[i])
			if groupId and groupId ~= "No Id"then
				groupId = tostring(groupId)  --it should already be, just making sure...
				net.dostring_in('mission', 'a_out_text_delay_g(' .. groupId .. ', ' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
			elseif groupId == "No Id" then  --battle commander slot cannot recieve specific text... PROBLEM- now they recieve it twice in echo mode.
                slmod.scopeMsg(msg, 5, 'chat', {clients = {scope.clients[i]}})  --send the message as chat instead for CA slots.. also, for now, fix length at 5 secs.
			end
		end
	end
	
	if scope.units then  --problem: no support for unit runtime ID... dropped support for RT ID?
		for i = 1, #scope.units do
			local groupId = slmod.getGroupIdByUnitName(scope.units[i])
			if groupId and groupId ~= "No Id" then
				groupId = tostring(groupId)
				net.dostring_in('mission', 'a_out_text_delay_g(' .. groupId .. ', ' .. slmod.basicSerialize(msg) .. ', ' .. tostring(display_time) .. ')')
			end
		end
	end
end

function slmod.scopeMsg(text_out, display_time, display_mode, scope)   --display_mode must be 'chat', 'text', 'both', or nil
	--set defaults
	scope = scope or {coa = 'all'}       
	display_mode = display_mode or 'echo'
	
	if ((display_mode ~= 'chat') and (display_mode ~= 'echo') and (display_mode ~= 'both') and (display_mode ~= 'text')) then
		display_mode = 'echo'  --force to echo mode
	end
	local nl_start, nl_end = text_out:find('\n', 1)
		
	if ((display_mode == 'text') or (display_mode == 'both') or (display_mode == 'echo')) then
		slmod.scopeText(text_out, display_time, scope)  --output trigger text
	end	
	
	if nl_end == nil then  --single line message
				
		if (display_mode == 'echo') then
			slmod.scopeChat(text_out, scope)
		end	
			
		local display_num = math.floor(display_time/6);
			
		if ((display_mode == 'chat') or (display_mode == 'both')) then	
			slmod.scopeChat(text_out, scope, display_num, 6)
		end
			
	else --multiline message 
		--stopped here
	
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
					slmod.scheduleFunctionByRt(slmod.scopeChat, {msg_string, scope}, DCS.getRealTime() + msg_time) -- now using realtime.
					--slmod.scheduleFunction(slmod.scopeChat, {msg_string, scope}, DCS.getModelTime() + msg_time)
					msg_time = msg_time + intvl_each
				end
			end		
		end		
	end
end	

-----------------------------------------------------------------------------


function slmod.getMissionTime()
	local retstr, reterr = net.dostring_in('server', 'return tostring(timer.getTime())')
	if reterr then
		return tonumber(retstr)
	end
end


--[[
			MGRS = { type = 'MGRS', UTMZone = string, MGRSDigraph = string, Easting = number, Northing = number}
			LL = { type = 'LL', lat = number (degrees), lon = number (degrees)}
			BR = { type = 'BR', az = number (TBD), dist = number (TBD)} -- bearing and range, ref point determined outside this function  Units for az and dist are degs and NM
			]]

------------------------------------------
-- net env functions
slmod.coord = {}  

function slmod.coord.MGRStoLL(MGRS) --net env gateway to server function slmod.coord.MGRStoLL
	--net.log(slmod.oneLineSerialize(MGRS))
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.MGRStoLL(' .. slmod.oneLineSerialize(MGRS) .. '))')
	--net.log('returned string and error from server for MGRStoLL:')
	--net.log(ret_str)
	--net.log(ret_err)
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.MGRStoLL: ' .. tostring(ret_str))
	end
end

function slmod.coord.MGRStoBR(MGRS, refpoint) --net env gateway to server function slmod.coord.MGRStoBR
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.MGRStoBR(' .. slmod.oneLineSerialize(MGRS) .. ', ' .. slmod.oneLineSerialize(refpoint) .. '))')
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.MGRStoBR: ' .. tostring(ret_str))
	end
end

function slmod.coord.LLtoMGRS(LL) --net env gateway to server function slmod.coord.LLtoMGRS
	-- net.log('type LL:')
	-- net.log(type(LL))
	-- net.log(LL.lat)
	-- net.log(LL.lon)
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.LLtoMGRS(' .. slmod.oneLineSerialize(LL) .. '))')
	-- net.log('returned string:')
	-- net.log(ret_str)
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.LLtoMGRS: ' .. tostring(ret_str))
	end
end

function slmod.coord.LLtoBR(LL) --net env gateway to server function slmod.coord.LLtoBR
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.LLtoBR(' .. slmod.oneLineSerialize(LL) .. ', ' .. slmod.oneLineSerialize(refpoint) .. '))')
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.LLtoBR: ' .. tostring(ret_str))
	end
end

function slmod.coord.BRtoMGRS(BR, refpoint) --net env gateway to server function slmod.coord.BRtoMGRS
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoMGRS(' .. slmod.oneLineSerialize(BR) .. ', ' .. slmod.oneLineSerialize(refpoint) .. '))')
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.BRtoMGRS: ' .. tostring(ret_str))
	end
end

function slmod.coord.BRtoLL(BR, refpoint) --net env gateway to server function slmod.coord.BRtoLL
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoLL(' .. slmod.oneLineSerialize(BR) .. ', ' .. slmod.oneLineSerialize(refpoint) .. '))')
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.BRtoLL: ' .. tostring(ret_str))
	end
end

function slmod.coord.BRtoBR(BR, refpoint1, refpoint2) --net env gateway to server function slmod.coord.BRtoBR
	local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoBR(' .. slmod.oneLineSerialize(BR) .. ', ' .. slmod.oneLineSerialize(refpoint1) .. ', ' .. slmod.oneLineSerialize(refpoint2) .. '))')
	if ret_err and type(ret_str) == 'string' then -- successful
		local coords = slmod.deserializeValue('coords = ' .. ret_str)
		if type(coords) == 'table' then
			return coords
		end
	else
		slmod.error('error in slmod.coord.BRtoBR: ' .. tostring(ret_str))
	end
end

function slmod.coord.tostring(coords) --converts Slmod-format coords into a string 
	local coord_string
	if coords.type == 'MGRS' then  --precision: 10 digits for now.
		coord_string = coords.UTMZone .. ' ' .. coords.MGRSDigraph .. ' ' .. string.format('%05d', slmod.round(tonumber(coords.Easting), 0)) .. ' ' .. string.format('%05d', slmod.round(tonumber(coords.Northing), 0))
	elseif coords.type == 'LL' then  -- precision: DD MM.MMM'
		local lathemi, lonhemi
		if coords.lat > 0 then
			lathemi = 'N'
		else
			lathemi = 'S'
		end
		if coords.lon > 0 then
			lonhemi = 'E'
		else
			lonhemi = 'W'
		end
		coords.lat = math.abs(coords.lat)
		coords.lon = math.abs(coords.lon)
		local latdeg = math.floor(coords.lat)
		local latmin = (coords.lat - latdeg)*60
		local londeg = math.floor(coords.lon)
		local lonmin = (coords.lon - londeg)*60
		latmin = slmod.round(latmin, 3)
		lonmin = slmod.round(lonmin, 3)
		
		if latmin == 60 then
			latmin = 0
			latdeg = latdeg + 1
		end
			
		if lonmin == 60 then
			lonmin = 0
			londeg = londeg + 1
		end
		
		coord_string = string.format('%02d', latdeg) .. ' ' .. string.format('%02d', math.floor(latmin)) .. '.' .. tostring(math.floor((latmin- math.floor(latmin))*1000)) .. '\'' .. lathemi .. ' ' .. string.format('%03d', londeg) .. ' ' .. string.format('%02d', math.floor(lonmin)) .. '.' .. tostring(math.floor((lonmin- math.floor(lonmin))*1000)) .. '\'' .. lonhemi
		
	elseif coords.type == 'BR' then
		local az = slmod.round(coords.az, 0)
		local dist = slmod.round(coords.dist, 0)
		coord_string = tostring(az) .. ' for ' .. tostring(dist)
	end
	return coord_string
end

function slmod.create_coord()
	local coord_string = [=[-- Server functions ---------------

if not coord.LOtoMGRS then
	--slmod.info('creating coord.LOtoMGRS')
	coord.LOtoMGRS = function(point) -- creating the missing one.
		local lat, lon = coord.LOtoLL(point)	
		return coord.LLtoMGRS(lat, lon)	
	end
end

if not coord.LLtoMGRS then
	--slmod.info('creating coord.LLtoMGRS')
	coord.LLtoMGRS = function(lat, lon) -- creating the missing one.
		local LL = {}
		LL.lat = lat
		LL.lon = lon
		return coord.LOtoMGRS(slmod.LLtoLO(LL))	
	end
end

slmod = slmod or {}
slmod.coord = {}

function slmod.coord.MGRStoLL(MGRS)  -- this function seems a little wasteful, it should have almost no chance of error though
	if MGRS.UTMZone and MGRS.MGRSDigraph and MGRS.Easting and MGRS.Northing then
		local LLlat, LLlon = coord.MGRStoLL(MGRS)
		if LLlat and LLlon then
			return { lat = LLlat, lon = LLlon }
			--return '{ lat = ' .. tostring(LL.lat) .. ', lon = ' .. tostring(LL.lon) .. ' }'
		end
	end
end

-- MAKE SURE THAT utils IS THE CORRECT TABLE!
function slmod.coord.MGRStoBR(MGRS, refpoint) -- refpoint could be Unit.getPosition(client Unit).p or Coaltion.getMainRefPoint(client_coa)
	if refpoint and refpoint.x and refpoint.y and refpoint.z then  --making sure that refpoint is correct
		if MGRS.UTMZone and MGRS.MGRSDigraph and MGRS.Easting and MGRS.Northing then
			local LLlat, LLlon = coord.MGRStoLL(MGRS)
			if LLlat and LLlon then
				local LL = { lat = LLlat, lon = LLlon }
				local LO = slmod.LLtoLO(LL) --now LO is lock on coords
				if LO and LO.x and LO.y and LO.z then --making sure the coversion went successfully 
					local vec = { x = LO.x - refpoint.x, y = LO.y - refpoint.y, z = LO.z - refpoint.z } 
					return { az = utils.round(utils.get_azimuth(vec) * utils.units.deg.coeff, 1),  dist = utils.adv_round(utils.get_lengthZX(vec) * utils.units.nm.coeff, 1) }
					--return slmod.oneLineSerialize({ az = utils.round(utils.get_azimuth(vec) * utils.units.deg.coeff, 1),  dist = utils.adv_round(utils.get_lengthZX(vec) * utils.units.nm.coeff, 1) })
				end
			end
		end
	end
end

function slmod.coord.LLtoMGRS(LL)  -- this function seems a little wasteful
	if LL.lat and LL.lon then
		local MGRS = coord.LLtoMGRS(LL.lat, LL.lon)
		if MGRS and MGRS.UTMZone and MGRS.MGRSDigraph and MGRS.Easting and MGRS.Northing then  --not really necessary I think
			return MGRS
		end
	end
end

-- MAKE SURE THAT utils IS THE CORRECT TABLE!
function slmod.coord.LLtoBR(LL, refpoint)  --refpoint could be Unit.getPosition(client Unit).p or Coaltion.getMainRefPoint(client_coa)
	if refpoint and refpoint.x and refpoint.y and refpoint.z then  --making sure that refpoint is correct
		if LL.lat and LL.lon then
			local LO = slmod.LLtoLO(LL) --now LO is lock on coords
			if LO and LO.x and LO.y and LO.z then --making sure the coversion went successfully 
				local vec = { x = LO.x - refpoint.x, y = LO.y - refpoint.y, z = LO.z - refpoint.z } 
				return { az = utils.round(utils.get_azimuth(vec) * utils.units.deg.coeff, 1),  dist = utils.adv_round(utils.get_lengthZX(vec) * utils.units.nm.coeff, 1) }
				--return slmod.oneLineSerialize({ az = utils.round(utils.get_azimuth(vec) * utils.units.deg.coeff, 1),  dist = utils.adv_round(utils.get_lengthZX(vec) * utils.units.nm.coeff, 1) })
			end
		end
	end
end

function slmod.coord.get_vec_from_BR(az, dist)  -- az: degrees, dist, NM
	local unit_vec_x = math.cos(2*3.14159*az/360)
	local unit_vec_z = math.sin(2*3.14159*az/360)
	return { x = unit_vec_x*dist/utils.units.nm.coeff, y = 0, z = unit_vec_z*dist/utils.units.nm.coeff }
end
-- x =  north, z = east
function slmod.coord.BRtoMGRS(BR, refpoint)
	if refpoint and refpoint.x and refpoint.y and refpoint.z and BR and BR.az and BR.dist then  --making sure that input vars are OK
		local vec = slmod.coord.get_vec_from_BR(BR.az, BR.dist)  --vector from ref
		vec.x = vec.x + refpoint.x  --add in the refpoint coords
		vec.y = vec.y + refpoint.y
		vec.z = vec.z + refpoint.z
		local MGRS = coord.LOtoMGRS(vec)
		if MGRS and MGRS.UTMZone and MGRS.MGRSDigraph and MGRS.Easting and MGRS.Northing then  --not really necessary I think
			return MGRS
			--return slmod.oneLineSerialize(MGRS)
		end
	end
end

---- MAKE SURE THAT utils IS THE CORRECT TABLE!
function slmod.coord.BRtoLL(BR, refpoint)
	if refpoint and refpoint.x and refpoint.y and refpoint.z and BR and BR.az and BR.dist then
		local vec = slmod.coord.get_vec_from_BR(BR.az, BR.dist)  --vector from ref
		vec.x = vec.x + refpoint.x  --add in the refpoint coords
		vec.y = vec.y + refpoint.y
		vec.z = vec.z + refpoint.z
		local LL = {}
		LL['lat'], LL['lon'] = coord.LOtoLL(vec)
		if LL and LL.lat and LL.lon then  --not really necessary I think
			return LL
			--return slmod.oneLineSerialize(LL)
		end
	end
end

function slmod.coord.BRtoBR(BR, refpoint1, refpoint2)  -- transform from BR from refpoint1 to BR from refpoint2
	if refpoint1 and refpoint1.x and refpoint1.y and refpoint1.z and refpoint2 and refpoint2.x and refpoint2.y and refpoint2.z and BR and BR.az and BR.dist then  --making sure that refpoint is correct
		local vec = slmod.coord.get_vec_from_BR(BR.az, BR.dist) 
		vec.x = vec.x + refpoint1.x - refpoint2.x
		vec.y = vec.y + refpoint1.y - refpoint2.y
		vec.z = vec.z + refpoint1.z - refpoint2.z
		return { az = utils.round(utils.get_azimuth(vec) * utils.units.deg.coeff, 1),  dist = utils.adv_round(utils.get_lengthZX(vec) * utils.units.nm.coeff, 1) }
	end
end
----------------------------------]=]

	local ret_str, ret_err = net.dostring_in('server', coord_string)
end


-- function slmod.create_getGroupIdByGroupName()  --seems to be a problem with this function- not using it for now.
	-- local getGroupIdByGroupName_string = [[slmod = slmod or {}
	-- function slmod.getGroupIdByGroupName(group_name)
		-- for key, val in pairs(db["human"]["group"]["country"]["plane"]["group"]) do
			-- if val.name == group_name then
				-- return val.groupId
			-- end
		-- end
	-- end]]

	-- net.dostring_in('mission', getGroupIdByGroupName_string)

-- end


function slmod.getUnzippedMission(t_window)
	
	t_window = t_window or 3600 -- default: if t_window not specified, look at all files newer than 1 hour.
	
	local run_t = os.time()
	local mis_path, mis_t
	local path =  lfs.tempdir()
	
	for file in lfs.dir(path) do
		if file and file:sub(1,1) == '~' then
			local fpath = path .. '/' .. file
			local mod_t = lfs.attributes(fpath, 'modification')
			if mod_t and math.abs(run_t - mod_t) <= t_window then
				local f = io.open(fpath, 'r')
				if f then
					local fline = f:read()
					if fline and fline:sub(1,7) == 'mission' and (not mis_t or mod_t > mis_t) then -- found an unzipped mission file, and either none was found before or this is the most recent
						mis_t = mod_t
						mis_path = fpath
					end
					f:close()
				end
			end
		end	
	end
	
	if mis_path then -- a mission file was found
		local f = io.open(mis_path, 'r')
		if f then
			local mission = f:read('*all')
			f:close()
			return mission
		end
	end	
end

--untested as of v035
-- runs a the functional result of loadstring in an empty, local environment, to avoid going global.
-- fixes the "temp global" pollution problem I get when I do dostring in the global.  This is a much neater, cleaner solution.
-- hopefully returns all the variables in the local environment.
function slmod.getLoadedEnv(s) 
	local f, err = loadstring(s)
	if f then
		local env = {}
		setfenv(f, env)
		f()
		---- remap to consecutive numbers
		-- local newenv = {}
		-- for i,v in pairs(env) do
			-- newenv[#newenv + 1] = v
		-- end
		-- return unpack(newenv)
		return unpack(env)
		--return (next(env))
	end
end

--Untested as of v035
function slmod.doStringIn(s, env) -- dostring in a table.  Does not pass back the table, assume you still have it from where you called this function from.
	local f, err = loadstring(s)
	if f then
		setfenv(f, env)
		return f()
	end
end

function slmod.getSlotFromMultCrew(multId)
    if type(multId) == 'string' then
        if string.find(multId, '%d+') then
            local s, e = string.find(multId, '%d+')
            local seatS, seatE = string.find(multId, '%d+', e+1)
            if s and e then
                if seatS and seatE then
                    return string.sub(multId, s, e), string.sub(multId, seatS, seatE)
                end
                --slmod.info('seatS and seatE missing')
                return string.sub(multId, s, e)
            end
        end	
    end
end

function slmod.getClientRtId(client_id)
	--slmod.info('getClientRtId')
	if slot_id and slot_id ~= ''  then
        if type(slot_id) == 'string' and (slot_id == '' or string.find(slot_id, 'red') or string.find(slot_id, 'blue')) then
			--net.log('client is on spectators or CA slot')
			return 0
		end
        local seat = 0
		if not tonumber(slot_id) then
            slot_id, seat = slmod.getSlotFromMultCrew(slot_id)
		end
		slot_id = tonumber(slot_id)
        seat = tonumber(seat)
		if slot_id and slot_id > 0 then  --making sure it successfully converted, and it's a reasonable value
			return DCS.getUnitProperty(slot_id, 1), seat
		end
	end
end

function slmod.getClientUnitId(client_id)
    local slot_id = net.get_player_info(client_id, 'slot')
	if slot_id and slot_id ~= '' and not (string.find(slot_id, 'red') or string.find(slot_id, 'blue'))then
        local seat = 0
		if (not tonumber(slot_id)) then
			slot_id, seat = slmod.getSlotFromMultCrew(slot_id)
		end
		if (tonumber(slot_id) and tonumber(slot_id) > 0) or string.find(slot_id, 'red') or string.find(slot_id, 'blue') then
            seat = tonumber(seat)
            if slot_id then  --making sure it successfully converted, and it's a reasonable value
                return DCS.getUnitProperty(slot_id, 2), seat
            end
        end
	end
end

function slmod.getClientUnitName(client_id)
	--slmod.info('getClientUnitName')
    local slot_id = net.get_player_info(client_id, 'slot')
	if slot_id and slot_id ~= '' and not (string.find(slot_id, 'red') or string.find(slot_id, 'blue')) then
        local seat = 0
		if (not tonumber(slot_id)) then
			slot_id, seat = slmod.getSlotFromMultCrew(slot_id)
		end
		if (tonumber(slot_id) and tonumber(slot_id) > 0) or string.find(slot_id, 'red') or string.find(slot_id, 'blue') then
            seat = tonumber(seat)
            if slot_id then  --making sure it successfully converted, and it's a reasonable value
                return DCS.getUnitProperty(slot_id, 3), seat
            end
        end
	end
end

function slmod.getClientSide(client_id)
	local side = net.get_player_info(client_id, 'side')
	if side then
		side = tonumber(side)
		if side == 0 then
			return 'spec'
		elseif side == 1 then
			return 'red'
		elseif side == 2 then
			return 'blue'
		end
	end
end


function slmod.getClientGroupId(client_id)
    local slot_id = net.get_player_info(client_id, 'slot')
	if slot_id then
		if type(slot_id) == 'string' and (slot_id == '' or string.find(slot_id, 'red') or string.find(slot_id, 'blue')) then
			--net.log('client is on spectators or CA slot')
			return "No Id"
		end
		if not tonumber(slot_id) then
			slot_id = slmod.getSlotFromMultCrew(slot_id)
		end
		slot_id = tonumber(slot_id)
		if slot_id and slot_id > 0 then  --making sure it successfully converted, and it's a reasonable value
			return DCS.getUnitProperty(slot_id, 6)
		end
	end
end

function slmod.getGroupIdByUnitName(unitname)
	local lmission_units = slmod.activeUnitsBase
	for ind, unit_data in pairs(lmission_units) do
		if unit_data.name == unitname then
			return unit_data.groupId
		end
	end
end

function slmod.getClientNameAndRtId(client_id) -- unit name and RTID. CA slots dont have a unit name
	--slmod.info('getClientNameAndRtId')
    local slot_id = net.get_player_info(client_id, 'slot')
    local seat 
	if slot_id and slot_id ~= '' and not (string.find(slot_id, 'red') or string.find(slot_id, 'blue')) then
		if (not tonumber(slot_id)) then
			slot_id, seat = slmod.getSlotFromMultCrew(slot_id)
		end
        if not seat then 
            seat = 1
        end
		slot_id = tonumber(slot_id)
       
		if slot_id and slot_id > 0 then  --making sure it successfully converted, and it's a reasonable value
            return DCS.getUnitProperty(slot_id, 3), DCS.getUnitProperty(slot_id, 1), seat
		end
	end
end


slmod.info('SlmodUtils.lua loaded.')