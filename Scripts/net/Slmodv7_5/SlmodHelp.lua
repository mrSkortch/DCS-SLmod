do
	-- Slmod Help menu
	function slmod.create_SlmodHelpMenu()

		-- help menu show commands
		local helpShowCmds = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-help',
					required = true,
				}
			},
			[2] = {
				[1] = {
					type = 'word',
					text = '-slmod',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = true,
				}
			},
			[3] = {
				[1] = {
					type = 'word',
					text = '-menu',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = false,
				}
			}
		}
		
		local helpItems = {}
		
		-- create the menu.
		SlmodHelpMenu = SlmodMenu.create{
			showCmds = helpShowCmds, 
			scope = {
				coa = 'all'
			}, 
			options = {
				display_time = 30, 
				display_mode = 'text', 
				title = '', 
				privacy = {
					access = true, 
					show = true
				}
			}, 
			items = helpItems -- empty for now.
		}
		
		--[[
		Menus and config settings
		
		Coordinate Converter     --slmod.config.coord_converter
		MOTD     -- MOTD_enabled
		POS
		PTS
		stats   -- slmod.config.enable_slmod_stats
		Admin Menu  -- scope is by getScope().
		
		]]
		SlmodHelpMenu.show = function(self, clientId, show_scope)  -- updates the "title" of this not-menu.
			local title = 'Slmod Help Menu\nThese are the active Slmod menus accessible to you:\n'
			if slmod.config.admin_tools and SlmodAdminMenu and clientId and slmod.clientInScope(clientId, SlmodAdminMenu:getScope()) then
				title = title..'- Slmod Server Admin Menu (' .. tostring(#SlmodAdminMenu:getItems()) .. ' items) - show this menu by saying "-admin" in chat.\n'
			end
			
			if SlmodStatsMenu then  -- Maybe in future, allow users to turn it off.
				title = title..'- SlmodStats multiplayer statistics viewer/menu (' .. tostring(#SlmodStatsMenu:getItems()) .. ' items) - show this menu by saying "-stats" in chat.\n'
			end
			
			if slmod.config.MOTD_enabled then
				title = title..'- Server Message of the Day (MOTD), show by saying "-motd" in chat.\n'
			end
			
			if slmod.config.coord_converter and slmod.ConvMenu then
				title = title..'- Slmod Coordinate Conversion Utility (' .. tostring(#slmod.ConvMenu:getItems()) .. ' items), show by saying "-conv" in chat.\n'
			end
            
            if slmod.config.autoAdmin.forgiveEnabled or slmod.config.autoAdmin.forgiveEnabled then
               title = title..'- Slmod Forgive/Punish (' .. tostring(#SlmodForgivePunishMenu:getItems()) .. ' items), show by saying "-forgive" or "-punish" in chat. \n'
            end
            
            if slmod.config.voteConfig.enabled then
               title = title..'- Slmod Voting (' .. tostring(#SlmodVoteMenu:getItems()) .. ' items), show by saying "-vote" in chat. \n'
            end
			
			local clientPOS
			local clientSide = slmod.getClientSide(clientId)
			if clientSide == 'red' then
				clientPOS = RedPOS
			elseif clientSide == 'blue' then
				clientPOS = BluePOS
			end
			if clientPOS then
				title = title..'- Parallel Options System (' .. tostring(#clientPOS:getItems()) .. ' items), show by saying "-sol" in chat.\n'
			end
			
			local clientPTS
			if clientSide == 'red' then
				clientPTS = RedPTS
			elseif clientSide == 'blue' then
				clientPTS = BluePTS
			end
			if clientPTS then
				title = title..'- Parallel Tasking System (' .. tostring(#clientPTS:getItems()) .. ' items), show by saying "-stl" in chat.\n'
			end
			
			self.options.title = title

			SlmodMenu.show(self, clientId, show_scope)
		end
		
		local helpShowVars = {}
		--MOTDShowVars.menu = SlmodMOTDMenu  -- probably not necessary?
		helpShowVars .description = 'To show this help again, say "-help" in chat.'
		--MOTDShowVars.active = true
		--MOTDShowVars.options = {} -- maybe not necessary.
		--MOTDShowVars.selCmds = {}  -- also maybe not necessary.
		
		--showVars.onSelect = function() end  -- empty- not needed.
		helpItems[#helpItems + 1] = SlmodMenuItem.create(helpShowVars)
		
		
		
	end

end
slmod.info('SlmodHelp.lua loaded.')