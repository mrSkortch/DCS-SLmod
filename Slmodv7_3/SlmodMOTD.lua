if slmod.config.MOTD_enabled then

	local function is_BC(name)  -- I probably need to make this a global function in SlmodUtils, I use it three times ALREADY...
		local BC_names = {'artillery_commander_blue_', 'instructor_blue_', 'forward_observer_blue_', 'observer_blue_', 'artillery_commander_red_', 'instructor_red_', 'forward_observer_red_', 'observer_red_' } -- fill with the names for all battle commander slots.
		if type(name) == 'string' and name ~= '' then
			for ind, BC_name in pairs(BC_names) do
				if name:find(BC_name) then
					return true
				end
			end
		end
		return false
	end

	local chatKeyByModule = {
		['A-10A'] = '`/~ (the "tilde key")',
		['CA'] = '`/~ (the "tilde key")',
		['A-10C'] = 'Tab',
		['F-15C'] = '`/~ (the "tilde key")',
		['Ka-50'] = 'Tab',
		['Mi-8MT'] = 'Tab',
		['Mi-8MTV2'] = 'Tab',
		['MiG-29A'] = '`/~ (the "tilde key")',
		['MiG-29G'] = '`/~ (the "tilde key")',
		['MiG-29S'] = '`/~ (the "tilde key")',
		['P-51D'] = 'Tab',
		['Su-25'] =  '`/~ (the "tilde key")',
		['Su-25T'] =  '`/~ (the "tilde key")',
		['Su-27'] = '`/~ (the "tilde key")',
		['Su-33'] = '`/~ (the "tilde key")',
		['UH-1H'] = 'Tab',
		['F-86F Sabre'] = 'Tab',
		['F-86F'] = 'Tab',
		['FW-190D9'] = 'Tab',
		['TF-51D'] = 'Tab',
	}
	
	local function getChatKey(id) -- id is client id.
		if id then
			local side, unitId = net.get_unit(id)  -- get side and unitId
			if unitId then -- if in a unit.
				if is_BC(unitId) then  -- if it is a CA slot
					return chatKeyByModule['CA']
				else -- not a CA slot.
					unitId = tonumber(unitId)
					if unitId and unitId > 0 then
						local unitName = tostring(net.get_unit_property(unitId, 3))  -- get Unit's ME name
						if unitName then
							local unitData = slmod.allMissionUnitsByName[unitName]
							if unitData then
								local typeName = unitData.objtype
								if typeName and chatKeyByModule[typeName] then
									return chatKeyByModule[typeName]
								else
									slmod.warning('MOTD: Unable to get chat key for client ' .. tostring(id).. ', reason: no default chat key found for typeName ' .. tostring(typeName))
								end
							else
								slmod.warning('MOTD: Unable to get chat key for unitName ' .. slmod.basicSerialize(unitName) .. ', reason: unit not in mission!')
							end
						else
							slmod.warning('MOTD: Unable to get chat key for client ' .. tostring(id).. ', reason: no unitName')
						end
					else
						slmod.warning('MOTD: Unable to get chat key for client ' .. tostring(id).. ', reason: invalid unitId.')
					end
				end
			else
				slmod.warning('MOTD: Unable to get chat key for client ' .. tostring(id).. ', reason: no unitId.')
			end
		else
			slmod.warning('MOTD: Unable to get chat key for client ??, reason: no client id.')
		end
	end



	
	function slmod.create_SlmodMOTDMenu()
		
		-- check display_time and display_mode.
		
		local displayTime = slmod.config.MOTD_display_time
		if (not slmod.config.MOTD_display_time) or type(slmod.config.MOTD_display_time) ~= 'number' or slmod.config.MOTD_display_time < 0 then
			displayTime = 30
		end
		
		local displayMode = slmod.config.MOTD_display_mode
		if (not slmod.config.MOTD_display_mode) or type(slmod.config.MOTD_display_mode) ~= 'string' or (slmod.config.MOTD_display_mode ~= 'text' and slmod.config.MOTD_display_mode ~= 'chat' and slmod.config.MOTD_display_mode ~= 'echo' and slmod.config.MOTD_display_mode ~= 'both') then
			displayMode = 'text'
		end
		
		local MOTDShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-motd',
					required = true,
				}
			}
		}
	
		local MOTDItems = {}
		-- create the menu.
		SlmodMOTDMenu = SlmodMenu.create{ 
			showCmds = MOTDShowCommands, 
			scope = {
				coa = 'all'
			}, 
			options = {
				display_time = displayTime, 
				display_mode = displayMode, 
				title = '',
				privacy = {access = true, show = true}
			}, 
			items = MOTDItems
		}
		
		-- Kinda a hack
		local old_show = SlmodMOTDMenu.show
		
		SlmodMOTDMenu.show = function(self, clientId, show_scope)  -- updates the title (MOTD)
			local titleTbl = {}
			if (not slmod.config.custom_MOTD) or type(slmod.config.custom_MOTD) ~= 'string' then  -- use default first line
				local serverName
				if config and config.server and config.server.name then
					serverName = config.server.name
				else
					serverName = '"DCS Server"'
				end
				titleTbl[#titleTbl + 1] = 'Welcome to "'
				titleTbl[#titleTbl + 1] = serverName
				titleTbl[#titleTbl + 1] = '"!'
				--title = 'Welcome to "' .. serverName .. '"!'
			else
				titleTbl[#titleTbl + 1] = slmod.config.custom_MOTD
				--title = slmod.config.custom_MOTD  -- use custom first line
			end
			titleTbl[#titleTbl + 1] = '\nThis server is running Slmod version '
			titleTbl[#titleTbl + 1] = slmod.mainVersion
			titleTbl[#titleTbl + 1] = ', build '
			titleTbl[#titleTbl + 1] = slmod.buildVersion
			titleTbl[#titleTbl + 1] = '.  To see the Slmod help menu, say "-help" in chat.\n'
			--title = title .. '\nThis server is running Slmod version ' .. slmod.mainVersion .. ', build ' .. slmod.buildVersion .. '.\n' .. 'To see the Slmod help menu, say "-help" in chat.\n'
			
			if slmod.config.enable_slmod_stats then
				titleTbl[#titleTbl + 1] = 'Stats tracking is enabled; to view player stats, say "-stats" in chat.\n'
				--title = title .. 'This server is tracking stats with SlmodStats. To view the SlmodStats menu, say "-stats" in chat.\n'
			else
				titleTbl[#titleTbl + 1] = 'Stats tracking is disabled; to view player stats, say "-stats" in chat.\n'
				--title = title .. 'This server currently has stats tracking with SlmodStats disabled.  If you are an admin, you may re-enable it with the Admin menu.\n'
			end
			
			if slmod.config.autoAdmin.autoBanEnabled or slmod.config.autoAdmin.autoKickEnabled then
				local offCounter = 0  -- offense counter.
				if slmod.config.autoAdmin.teamHit.enabled then
					offCounter = offCounter + 1
				end
				if slmod.config.autoAdmin.teamKill.enabled then
					offCounter = offCounter + 1
				end
				if slmod.config.autoAdmin.teamCollisionHit.enabled then
					offCounter = offCounter + 1
				end
				if slmod.config.autoAdmin.teamCollisionKill.enabled then
					offCounter = offCounter + 1
				end
				if offCounter ~= 0 then
					titleTbl[#titleTbl + 1] = 'WARNING! '
					--title = title .. 'WARNING! '
					if slmod.config.autoAdmin.autoKickEnabled then
						titleTbl[#titleTbl + 1] = 'Auto Kick '
						--title = title .. 'Auto Kick '
						if slmod.config.autoAdmin.autoBanEnabled then
							titleTbl[#titleTbl + 1] = 'and '
							--title = title .. 'and '
						end
					end
					if slmod.config.autoAdmin.autoBanEnabled then
						titleTbl[#titleTbl + 1] = 'Auto Ban '
						--title = title .. 'Auto Ban '
					end
					if slmod.config.autoAdmin.autoBanEnabled and slmod.config.autoAdmin.autoKickEnabled then
						titleTbl[#titleTbl + 1] = 'are enabled. Actionable offenses include: '
						--title = title .. 'are enabled. Actionable offenses include: '
					else
						titleTbl[#titleTbl + 1] = 'is enabled. Actionable offenses include: '
						--title = title .. 'is enabled. Actionable offenses include: '
					end
					if slmod.config.autoAdmin.teamHit.enabled then
						titleTbl[#titleTbl + 1] = 'team-hit'
						--title = title .. 'team-hit'
						if slmod.config.autoAdmin.teamKill.enabled or slmod.config.autoAdmin.teamCollisionHit.enabled or slmod.config.autoAdmin.teamCollisionKill.enabled then
							titleTbl[#titleTbl + 1] = ', '
							--title = title .. ', '
						end
					end
					if slmod.config.autoAdmin.teamKill.enabled then
						titleTbl[#titleTbl + 1] = 'team-kill'
						--title = title .. 'team-kill'
						if slmod.config.autoAdmin.teamCollisionHit.enabled or slmod.config.autoAdmin.teamCollisionKill.enabled then
							titleTbl[#titleTbl + 1] = ', '
							--title = title .. ', '
						end
					end
					if slmod.config.autoAdmin.teamCollisionHit.enabled then
						titleTbl[#titleTbl + 1] = 'team-collision-hit'
						--title = title .. 'team-collision-hit'
						if slmod.config.autoAdmin.teamCollisionKill.enabled then
							titleTbl[#titleTbl + 1] = ', '
							--title = title .. ', '
						end
					end
					if slmod.config.autoAdmin.teamCollisionKill.enabled then
						titleTbl[#titleTbl + 1] = 'team-collision-kill'
						--title = title .. 'team-collision-kill'
					end
					titleTbl[#titleTbl + 1] = '.'
					--title = title .. '.\n'
				end
				
			end
			
			if slmod.config.coord_converter then
				titleTbl[#titleTbl + 1] = '\nSlmod Coordinate Converter is enabled. For instructions on how to use it, say "-conv" in chat.'
				--title = title .. 'This server has the Slmod Coordinate Converter enabled. For instructions on how to use it, say "-conv" in chat.\n'
			end
			if slmod.config.MOTD_show_POS_and_PTS then
				titleTbl[#titleTbl + 1] = '\nSome missions may make use of the Parallel Tasking System. To see any tasks, say "-stl" in chat.'
				--title = title .. 'Some missions may make use of the Parallel Tasking System. To see any tasks, say "-stl" in chat.\n'
				titleTbl[#titleTbl + 1] = '\nSome missions may make use of the Parallel Options System. To see any options, say "-sol" in chat.'
				--title = title .. 'Some missions may make use of the Parallel Options System. To see any options, say "-sol" in chat.'
			end
			
			if slmod.config.admin_tools and SlmodAdminMenu and clientId and slmod.clientInScope(clientId, SlmodAdminMenu:getScope()) then
				titleTbl[#titleTbl + 1] = '\nYou are registered as a server admin.  Say "-admin" in chat to access the Admin menu.'
				--title =  title ..'You are registered as a server admin.  Say "-admin" in chat to access the Admin menu.'
			end
			
			local chatKey = getChatKey(clientId)
			if chatKey then
				titleTbl[#titleTbl + 1] = '\n(The default US keystroke for chat in your module is: '
				titleTbl[#titleTbl + 1] = chatKey
				titleTbl[#titleTbl + 1] = '.)'
				--title = title .. '\n(The default keystroke for chat in your selected module (on US keyboards) is: ' .. chatKey .. '.)'
			end
			
			self.options.title = table.concat(titleTbl) -- kinda a hax also- there is only one motd menu for everyone, but I change the title based on the last time it was requested...
			
			return old_show(self, clientId, show_scope)
		end
		
		---------------------------------------------------------------------------------------------------------------------------------
		-- reshow menu item.  No selection really necessary- it just serves to keep the ("This menu is empty" text away, and also to give the command to re-show MOTD.
		local MOTDShowVars = {}
		--MOTDShowVars.menu = SlmodMOTDMenu  -- probably not necessary?
		MOTDShowVars.description = 'To repeat this message, say "-motd" in chat at any time.'
		--MOTDShowVars.active = true
		--MOTDShowVars.options = {} -- maybe not necessary.
		--MOTDShowVars.selCmds = {}  -- also maybe not necessary.
		
		--showVars.onSelect = function() end  -- empty- not needed.
		MOTDItems[#MOTDItems + 1] = SlmodMenuItem.create(MOTDShowVars)
	end
	
	
end


slmod.info('SlmodMOTD.lua loaded.')