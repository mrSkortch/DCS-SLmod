-- Slmod Debugger
function slmod.create_DebugScripts()
	local DebugScripts_string = [[slmod = slmod or {}
function slmod.debugScripts()
	local syntaxerrors = 'LUA SYNTAX ERRORS:\n\n'
	local errorcount = 0
	for coa, coa_tbl in pairs(mission["coalition"]) do 
		if coa == 'red' or coa == 'blue' then -- if it's red or blue
			if coa_tbl["country"] then
				for coun_key, coun_val in pairs(coa_tbl["country"]) do --do for all countries
					for key, val in pairs(coun_val) do --open up country table
						--net.log('key and val: ' .. tostring(key) .. ', ' .. tostring(val))
						if type(val) == 'table' and val["group"] then -- found a group table for this country
							for group_key, group in pairs(val["group"]) do --step through all the groups
								--net.log('found group: ' .. group["name"])
								if group["tasks"] and (#group["tasks"] > 0) then
									for task_ind = 1, #group["tasks"] do
										local task = group["tasks"][task_ind]  -- a task
										if  task.id and task.id == "WrappedAction" and task.params and task.params.action and task.params.action.id 
										and (task.params.action.id == "Script") and task.params.action.params and task.params.action.params.command 
										and (type(task.params.action.params.command) == 'string') then -- a script is found!
											local func, err = loadstring(task.params.action.params.command)
											if not func and (type(err) == 'string') then -- a syntax error!
												errorcount = errorcount + 1
												local err_str = 'Error #' .. tostring(errorcount) .. ': In group "' .. group["name"] ..'", task #' .. tostring(task_ind) .. ': ' .. err .. '\n\n'
												syntaxerrors = syntaxerrors .. err_str
												
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
	
	if errorcount > 0 then
		return syntaxerrors
	end
end]]

	net.dostring_in('mission', DebugScripts_string)

end



function slmod.runSlmodDebugger()
	local ret_str, err = net.dostring_in('mission', 'return slmod.debugScripts()')
	if err then
		if ret_str and ret_str ~= '' then -- errors!
			local error_file_loc = lfs.writedir() .. 'Logs/' .. slmod.config.debugger_outfile
			slmod.msg_out_net('Slmod Debugger: Warning! Lua error(s) found in this mission\'s triggered actions!\nSlmod will continue to function normally, however, these triggered actions will not work correctly.\nSaving a copy of this error report to: ' .. error_file_loc .. '\n\n' .. ret_str, 60, 'text')
			local errorfile = io.open(error_file_loc, 'w')
			if errorfile then
				errorfile:write(ret_str)
				errorfile:close()
				errorfile = nil
			end
		else
			slmod.info('Slmod Debugger: No Lua errors found in this mission')
		end
	else
		slmod.warning('unable to run Slmod Debugger in mission environment, reason: ' .. tostring(ret_str))
	end
end

slmod.info('SlmodDebugger.lua loaded.')