-- Slmod server administration utility
-- uses SlmodMenu class.

do
	local config_dir = lfs.writedir() .. [[Slmod\]]
	
	local Admins = {}
	
	----------------------------------------------------------------------------------------
	local function load_banned_clients()  -- loads banned clients.
		local ban_f = io.open(config_dir .. 'BannedClients.lua', 'r')
		if ban_f then
			local ban_s = ban_f:read('*all')
			local ban_func, err1 = loadstring(ban_s)
			if ban_func then
				local safe_env = {}
				setfenv(ban_func, safe_env)
				local bool, err2 = pcall(ban_func)
				if not bool then
					slmod.error('unable to load banned clients, reason: ' .. tostring(err2))
					slmod.bannedIps = slmod.bannedIps or {}
					slmod.bannedUcids = slmod.bannedUcids or {}
				else
					slmod.bannedIps = safe_env['slmod_banned_ips'] or {}
					slmod.bannedUcids = safe_env['slmod_banned_ucids'] or {}
					slmod.info('using banned ucids and/or ips as defined in ' .. config_dir .. 'BannedClients.lua')
				end
			else
				slmod.error('unable to load banned clients, reason: ' .. tostring(err1))
			end
			
		else  -- unable to open file, attempt to create one.
			slmod.info('Unable to open or find ' .. config_dir .. 'BannedClients.lua, creating file...')
			slmod.bannedIps = slmod.bannedIps or {}
			slmod.bannedUcids = slmod.bannedUcids or {}
			
			slmod.update_banned_clients() -- creates the file.
		end
	end
	----------------------------------------------------------------------------------------
	
	----------------------------------------------------------------------------------------
	-- clientInfo = {ucid = string, name = string, ip = string}, --adminInfo = {ucid = string, name = string} OR 'autoban', expTime -expiration time, optional.... ALL variables optional, called with nothing, it just re-serializes the file.
	function slmod.update_banned_clients(clientInfo, adminInfo, expTime)  -- adds a banned client   -- NO LONGER LOCAL
		-- clientInfo: {ucid = string, name = string, ip = string}
		slmod.bannedIps = slmod.bannedIps or {}
		slmod.bannedUcids = slmod.bannedUcids or {}
		
		
		if type(clientInfo) == 'table' then  -- a client will be added.
			local banData = {}
			banData['name'] = clientInfo.name
			banData['ip'] = clientInfo.ip
			banData['ucid'] = clientInfo.ucid
			banData['time'] = os.time()
			banData['expTime'] = expTime
			banData['bannedBy'] = adminInfo
			slmod.bannedIps[clientInfo.ip] = banData
			slmod.bannedUcids[clientInfo.ucid] = banData
		end
		
		local file_s = slmod.serialize('slmod_banned_ips', slmod.bannedIps) .. '\n\n' .. slmod.serialize('slmod_banned_ucids', slmod.bannedUcids)

		local ban_f = io.open(config_dir .. 'BannedClients.lua', 'w')
		if ban_f then
			ban_f:write(file_s)
			ban_f:close()
			ban_f = nil
		else
			slmod.error('Unable to open ' .. config_dir .. 'BannedClients.lua for writing.')
		end
	end
	----------------------------------------------------------------------------------------
	
	----------------------------------------------------------------------------------------
	local function load_admins()
		local Admins_f = io.open(config_dir .. 'ServerAdmins.lua', 'r')
		if Admins_f then
			local Admins_s = Admins_f:read('*all')
			local Admins_func, err1 = loadstring(Admins_s)
			if Admins_func then
				local safe_env = {}
				setfenv(Admins_func, safe_env)
				local bool, err2 = pcall(Admins_func)
				if not bool then
					slmod.error('unable to load server admins, reason: ' .. tostring(err2))
					Admins = Admins or {}
				else
					Admins = safe_env['Admins'] or {}
					if safe_env['Admins'] then
						slmod.info('using server admins as defined in ' .. config_dir .. 'ServerAdmins.lua')
					end
				end
			else
				slmod.error('unable to load server admins, reason: ' .. tostring(err1))
			end
			
		else
			Admins = Admins or {}
		end
	end
	----------------------------------------------------------------------------------------
	
	----------------------------------------------------------------------------------------
	local function update_admins(client_info)
		-- client_info: {ucid = string, name = string}
		Admins = Admins or {}
		
		if client_info then
			Admins[client_info.ucid] = client_info.name
		end
		
		local file_s = slmod.serialize('Admins', Admins)

		local Admins_f = io.open(config_dir .. 'ServerAdmins.lua', 'w')
		if Admins_f then
			Admins_f:write(file_s)
			Admins_f:close()
			Admins_f = nil
		else
			slmod.error('unable to file of allowed server admins.')
		end
		
	end
	----------------------------------------------------------------------------------------
	
	----------------------------------------------------------------------------------------
	local function create_LoadMissionMenuFor(id)  --creates the temporary load mission menu for this client id.
		local path
		if slmod.config.admin_tools_mission_folder and type(slmod.config.admin_tools_mission_folder) == 'string' then
			path = slmod.config.admin_tools_mission_folder
			if (path:sub(-1) ~= '\\') or (path:sub(-1) ~= '/') then
				path = path .. '\\'
			end
		else
			path = lfs.writedir() .. [[Slmod\Missions\]]
		end
		-- load mission menu show commands  -- this menu is automatically shown when it is created, but
		local LoadShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-show',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'again',
					required = true,
				}
			}
		}
		
		local LoadItems = {}
		local display_mode = slmod.config.admin_display_mode or 'text'
		local display_time = slmod.config.admin_display_time or 30
		local LoadMenu = SlmodMenu.create({showCmds = LoadShowCommands, scope = {clients = {id}}, options = {display_time = display_time, display_mode = display_mode, title = 'Mission listing in ' .. path .. ' (you have two minutes to make a choice):', privacy = {access = true, show = true}}, items = LoadItems})
		slmod.scheduleFunctionByRt(SlmodMenu.destroy, {LoadMenu}, net.get_real_time() + 120)  --scheduling self-destruct of this menu in two minutes.
		
		local miz_cntr = 1
		for file in lfs.dir(path) do
			if file:sub(-4) == '.miz' then
				local LoadVars = {}
				LoadVars.menu = LoadMenu
				LoadVars.description = 'Mission ' .. tostring(miz_cntr) .. ': "' .. file .. '", say in chat "-load ' .. tostring(miz_cntr) .. '" to load this mission.'
				LoadVars.active = true
				LoadVars.filename = file
				LoadVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
				LoadVars.selCmds = {
						[1] = {
							[1] = { 
								type = 'word', 
								text = '-load',
								required = true
							}, 
							[2] = { 
								type = 'word',
								text = tostring(miz_cntr),
								required = true
							}
						}
					} 
				LoadVars.onSelect = function(self, vars, client_id)
					if not client_id then
						client_id = vars
					end
					
					local AdminName
					if client_id == 1 then
						AdminName = net.get_name(1)
					elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
						AdminName = Admins[slmod.clients[client_id].ucid]
					else
						AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
					end
					
					slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" is loading the mission: "' .. self.filename .. '".' }, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
					slmod.scheduleFunctionByRt(net.load_mission, {path .. self.filename}, net.get_real_time() + 5)
				end
				LoadItems[miz_cntr] = SlmodMenuItem.create(LoadVars) 
				miz_cntr = miz_cntr + 1
			end
		end
		
		local ShowAgainVars = {}
		ShowAgainVars.menu = LoadMenu
		ShowAgainVars.description = 'Say "-show again" in chat to view this menu again.'
		ShowAgainVars.active = true
		ShowAgainVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		ShowAgainVars.selCmds = {} 
		ShowAgainVars.onSelect = function() end
		LoadItems[miz_cntr] = SlmodMenuItem.create(ShowAgainVars) 
		
		LoadMenu:show()
	end
	----------------------------------------------------------------------------------------
	
	----------------------------------------------------------------------------------------
	-- create the Admin Menu.
	function slmod.create_SlmodAdminMenu()
		load_banned_clients()
		load_admins()
		
		-- Used for Admin menu and id ban submenu.
		local display_mode = slmod.config.admin_display_mode or 'text'
		local display_time = slmod.config.admin_display_time or 30
		
		-----------------------------------------------------------------------------------------------------------------
		-----------------------------------------------------------------------------------------------------------------
		-- id ban submenu.
		-- id ban show commands
		
		-- show commands moved to the onSelect option for the admin menu.
		
		local idBanMenu = SlmodMenu.create{
			showCmds = {},  -- no inherent show commands, the menu is shown onSelect of an admin menu option.
			scope = {}, -- scope starts empty- will update scope and items in the AdminMenu update scope function.
			options = {display_time = display_time, display_mode = display_mode, title = 'Select a client id to ban.  Current clients are:', 
			privacy = {access = true, show = true}},
			items = {},
			--Additional function: update items.  Also called in update_scope
			updateBanItems = function(self)  -- self is menu.
				self.items = {}  -- reset items.
				for id, client in pairs(slmod.clients) do
					if id ~= 1 and client.name then
						local idBanVars = {}
						idBanVars.menu = self
						idBanVars.description = '"' .. client.name  ..'"; say in chat "-admin id ban ' .. tostring(id) .. '" to ban this player from the server.'
						idBanVars.active = true
						idBanVars.id = id
						idBanVars.name = client.name
						--idBanVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}  -- probably not used for anything.
						idBanVars.selCmds = {
							[1] = {
								[1] = { 
									type = 'word', 
									text = '-admin',
									required = true
								}, 
								[2] = { 
									type = 'word',
									text = 'id',
									required = true
								},
								[3] = { 
									type = 'word',
									text = 'ban',
									required = true
								},
								[4] = { 
									type = 'word',
									text = tostring(id),
									required = true
								}
							}
						} 
						idBanVars.onSelect = function(self, vars, client_id)  -- self here is the item.
							client_id = client_id or vars  -- don't think this is necessary
							local banId = self.id
							
							if banId and slmod.clients[banId] then
								
								local admin = slmod.clients[client_id]
								if not admin then
									admin = {name = '!UNKNOWN ADMIN!'} -- should NEVER get to this.
								end

								net.kick(banId, 'You were banned from the server.')
								slmod.update_banned_clients({ucid = slmod.clients[banId].ucid, name = self.name, ip = slmod.clients[banId].addr or slmod.clients[banId].ip}, {name = admin.name, ucid = admin.ucid})
								
								slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: server admin "' .. admin.name .. '" banned player "' .. self.name .. '" from the server.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
							else
								slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: no player with a client id of ' .. tostring(self.id) .. ' exists!', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
							end
						end
						-- confusing:  now self is back to the submenu.
						self.items[#self.items + 1] = SlmodMenuItem.create(idBanVars) 
					
					end  -- end of if id ~= 1 and client.name then
				end  -- end of for id, client in pairs(slmod.clients) do
			
			end,  -- end of the updateBanItems
		} -- end of local idBanMenu = SlmodMenu.create{
		------------------------------------------------------------------------------------------------------------
		
		-----------------------------------------------------------------------------------------------------------------
		-----------------------------------------------------------------------------------------------------------------
		-- id kick submenu.
		-- id kick show commands
		
		-- show commands moved to the onSelect option for the admin menu.
		
		local idKickMenu = SlmodMenu.create{
			showCmds = {},  -- no inherent show commands, the menu is shown onSelect of an admin menu option.
			scope = {}, -- scope starts empty- will update scope and items in the AdminMenu update scope function.
			options = {display_time = display_time, display_mode = display_mode, title = 'Select a client id to kick.  Current clients are:', 
			privacy = {access = true, show = true}},
			items = {},
			--Additional function: update items.  Also called in update_scope
			updateKickItems = function(self)  -- self is menu.
				self.items = {}  -- reset items.
				for id, client in pairs(slmod.clients) do
					if id ~= 1 and client.name then
						local idKickVars = {}
						idKickVars.menu = self
						idKickVars.description = '"' .. client.name  ..'"; say in chat "-admin id kick ' .. tostring(id) .. '" to kick this player from the server.'
						idKickVars.active = true
						idKickVars.id = id
						idKickVars.name = client.name
						--idKickVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}  -- probably not used for anything.
						idKickVars.selCmds = {
							[1] = {
								[1] = { 
									type = 'word', 
									text = '-admin',
									required = true
								}, 
								[2] = { 
									type = 'word',
									text = 'id',
									required = true
								},
								[3] = { 
									type = 'word',
									text = 'kic',
									required = true
								},
								[4] = { 
									type = 'word',
									text = tostring(id),
									required = true
								}
							}
						} 
						idKickVars.onSelect = function(self, vars, client_id)  -- self here is the item.
							client_id = client_id or vars  -- don't think this is necessary
							local kickId = self.id
							
							if kickId and slmod.clients[kickId] then
								net.kick(kickId, 'You were kicked from the server.')
								--slmod.update_banned_clients({ucid = slmod.clients[banId].ucid, name = self.name, ip = slmod.clients[banId].addr})   --not applicable, but may need to add a temp ban here later.
								
								local adminName
								if client_id == 1 then
									adminName = net.get_name(1)
								elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
									adminName = Admins[slmod.clients[client_id].ucid]
								else
									adminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
								end
								
								slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: server admin "' .. adminName .. '" kicked player "' .. self.name .. '" from the server.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
							else
								slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: no player with a client id of ' .. tostring(self.id) .. ' exists!', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
							end
						end
						-- confusing:  now self is back to the submenu.
						self.items[#self.items + 1] = SlmodMenuItem.create(idKickVars) -- add this item to the submenu
					
					end  -- end of if id ~= 1 and client.name then
				end  -- end of for id, client in pairs(slmod.clients) do
			
			end,  -- end of the updateKickItems
		} -- end of local idKickMenu = SlmodMenu.create{
		------------------------------------------------------------------------------------------------------------
		
		
		
		local function update_scope()  -- called to continuously update scope of Admin Menu and its submenus.
			if SlmodAdminMenu then
				local newscope = {clients = {1}}
				for ucid, name in pairs(Admins) do
					for key, val in pairs(slmod.clients) do 
						if val.ucid and val.ucid == ucid then
							newscope.clients[#newscope.clients + 1] = val.id
						end
					end
				end
				SlmodAdminMenu:setScope(newscope)
				idKickMenu:setScope(newscope)
				idKickMenu:updateKickItems()
				idBanMenu:setScope(newscope)
				idBanMenu:updateBanItems()
			end
			slmod.scheduleFunctionByRt(update_scope, {},  net.get_real_time() + 0.5)
		end
		
		
		
		
		-------------------------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------------------------
		--main Admin menu
		
		-- admin menu show commands
		local AdminShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-admin',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = false,
				}
			}
		}
		
		
		
		local AdminItems = {}
		
		-- create the menu.
		local display_mode = slmod.config.admin_display_mode or 'text'
		local display_time = slmod.config.admin_display_time or 30
		SlmodAdminMenu = SlmodMenu.create{ 
			showCmds = AdminShowCommands,
			destroyIdBanMenu = function() idBanMenu:destroy() end,
			scope = {clients = {1}}, 
			options = {
				display_time = display_time, 
				display_mode = display_mode, 
				title = 'Slmod Server Administration Utility', 
				privacy = {access = true, show = true}
			}, 
			items = AdminItems
		}
		
		----------------------------------------------------------------------------------------------------------
		-- Create the items
		
		-- first item, kicking.
		local AdminKickVars = {}
		AdminKickVars.menu = SlmodAdminMenu
		AdminKickVars.description = 'Say in chat "-admin kick <player name>" to kick a player from the server.'
		AdminKickVars.active = true
		AdminKickVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		AdminKickVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'kick',
						required = true
						},
					[3] = {
						type = 'text',  -- new match type- ALL remaining text from chat message!  Can only be the last variable.
						varname = 'playername',
						required = true,
					}
				}
			} 
		AdminKickVars.onSelect = function(self, vars, client_id)
			--print('in onSelect')
			local playername = vars.playername or ''
			for key, val in pairs(slmod.clients) do -- skips host
				if val.name and type(val.name) == 'string' and val.name == playername and val.id and val.id ~= 1 then
					net.kick(key, 'You were kicked from the server.')
					
					local AdminName
					if client_id == 1 then
						AdminName = net.get_name(1)
					elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
						AdminName = Admins[slmod.clients[client_id].ucid]
					else
						AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
					end
					
					slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: server admin "' .. AdminName .. '" kicked player "' .. val.name .. '" from the server.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
					return
				end
			end
			slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: unable to find player named "' .. playername .. '".', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(AdminKickVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- second item, kick by id submenu
		local adminIdKickVars = {}
		adminIdKickVars.menu = SlmodAdminMenu
		adminIdKickVars.description = 'Say in chat "-admin id kick" to view the kick-by-client-ID submenu.'
		adminIdKickVars.active = true
		adminIdKickVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		adminIdKickVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-admin',
					required = true
				}, 
				[2] = { 
					type = 'word',
					text = 'id',
					required = true
					},
				[3] = {
					type = 'word',
					text = 'kic',
					required = true,
				}
			}
		} 
		adminIdKickVars.onSelect = function(self, vars, clientId)
			clientId = clientId or vars
			idKickMenu:show(clientId)
		end
		
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(adminIdKickVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		
		-----------------------------------------------------------------------------------------------
		-- third item, banning.
		local AdminBanVars = {}
		AdminBanVars.menu = SlmodAdminMenu
		AdminBanVars.description = 'Say in chat "-admin ban <player name>" to ban a player from the server.'
		AdminBanVars.active = true
		AdminBanVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		AdminBanVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'ban',
						required = true
						},
					[3] = {
						type = 'text',  -- new match type- ALL remaining text from chat message!  Can only be the last variable.
						varname = 'playername',
						required = true,
					}
				}
			} 
		AdminBanVars.onSelect = function(self, vars, client_id)
			--print('in onSelect')
			local playername = vars.playername or ''
			for id, client in pairs(slmod.clients) do -- skips host
				if client.name and type(client.name) == 'string' and client.name == playername and client.id and client.id ~= 1 then
					
					local admin
					if client_id and slmod.clients[client_id] then
						admin = slmod.clients[client_id] 
					else 
						admin = {name = '!UNKNOWN ADMIN!'} -- should NEVER get to this.
					end

					net.kick(id, 'You were banned from the server.')
					slmod.update_banned_clients({ucid = slmod.clients[id].ucid, name = client.name, ip = slmod.clients[id].addr or slmod.clients[id].ip}, {name = admin.name, ucid = admin.ucid})
					
					slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: server admin "' .. admin.name .. '" banned player "' .. client.name .. '" from the server.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
					return
				end
			end
			slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: unable to find player named "' .. playername .. '".', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(AdminBanVars)  -- add the item into the items table.
		
		
		-----------------------------------------------------------------------------------------------
		-- forth item, ban by id submenu
		local adminIdBanVars = {}
		adminIdBanVars.menu = SlmodAdminMenu
		adminIdBanVars.description = 'Say in chat "-admin id ban" to view the ban-by-client-ID submenu.'
		adminIdBanVars.active = true
		adminIdBanVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		adminIdBanVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-admin',
					required = true
				}, 
				[2] = { 
					type = 'word',
					text = 'id',
					required = true
					},
				[3] = {
					type = 'word',
					text = 'ban',
					required = true,
				}
			}
		} 
		adminIdBanVars.onSelect = function(self, vars, clientId)
			clientId = clientId or vars
			idBanMenu:show(clientId)
		end
		
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(adminIdBanVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- fifth item, unbanning.
		local AdminUnbanVars = {}
		AdminUnbanVars.menu = SlmodAdminMenu
		AdminUnbanVars.description = 'Say in chat "-admin unban <player name>" to unban a player from the server.'
		AdminUnbanVars.active = true
		AdminUnbanVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		AdminUnbanVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'unban',
						required = true
						},
					[3] = {
						type = 'text',  -- new match type- ALL remaining text from chat message!  Can only be the last variable.
						varname = 'playername',
						required = true,
					}
				}
			} 
		AdminUnbanVars.onSelect = function(self, vars, client_id)
			--print('in onSelect')
			local playername = vars.playername or ''
			local ip_cntr = 0
			local ucid_cntr = 0
			for ip, data in pairs(slmod.bannedIps) do
				if type(data) == 'string' and data == playername then  -- old format
					slmod.bannedIps[ip] = nil
					ip_cntr = ip_cntr + 1
				elseif type(data) == 'table' and data.name and data.name == playername then  -- new format
					slmod.bannedIps[ip] = nil
					ip_cntr = ip_cntr + 1
				end
			end
			for ucid, data in pairs(slmod.bannedUcids) do
				if type(data) == 'string' and data == playername then  -- old format
					slmod.bannedUcids[ucid] = nil
					ucid_cntr = ucid_cntr + 1
				elseif type(data) == 'table' and data.name and data.name == playername then  -- new format
					slmod.bannedUcids[ucid] = nil
					ucid_cntr = ucid_cntr + 1
				end
			end
			if ip_cntr > 0 or ucid_cntr > 0 then
				slmod.update_banned_clients()
				
				local AdminName
				if client_id == 1 then
					AdminName = net.get_name(1)
				elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
					AdminName = Admins[slmod.clients[client_id].ucid]
				else
					AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
				end
				
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: admin "' .. AdminName .. '" removed ' .. tostring(ip_cntr) .. ' IPs and ' .. tostring(ucid_cntr) .. ' UCIDs associated with player name "' .. playername .. '" from the ban list.', 1, 'chat', AdminUnbanVars.menu.scope}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			else
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: unable to find player named "' .. playername .. '" in banned clients.', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			end
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(AdminUnbanVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- forth item, add an admin.
		local AddAdminVars = {}
		AddAdminVars.menu = SlmodAdminMenu
		AddAdminVars.description = 'Say in chat "-admin add <player name>" to add a currently connected player to the list of server admins.'
		AddAdminVars.active = true
		AddAdminVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		AddAdminVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'add',
						required = true
						},
					[3] = {
						type = 'text',  -- new match type- ALL remaining text from chat message!  Can only be the last variable.
						varname = 'playername',
						required = true,
					}
				}
			} 
		AddAdminVars.onSelect = function(self, vars, client_id)
			--print('in onSelect')
			if vars.playername and type(vars.playername) == 'string' and vars.playername:len() > 0 then
				local playername = vars.playername
				for key, val in pairs(slmod.clients) do
					if val.name == playername then
						Admins[val.ucid] = val.name  -- update_scope will add this admin to scope within 0.1 sec.
						update_admins({ucid = val.ucid, name = val.name})  -- update the file of admins
						
						local AdminName
						if client_id == 1 then
							AdminName = net.get_name(1)
						elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
							AdminName = Admins[slmod.clients[client_id].ucid]
						else
							AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
						end
						
						slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: admin "' .. AdminName .. '" added player "' .. val.name .. '" to the list of admins.', 1, 'chat', AddAdminVars.menu.scope}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
						slmod.scopeMsg('Slmod: you were granted server admin status by admin "' .. AdminName .. '".', 1, 'chat', {clients = {val.id}})
						return
					end
				end
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: unable to find player named "' .. playername .. '" in currently connected clients.', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			end
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(AddAdminVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- fifth item, remove an admin.
		local RemoveAdminVars = {}
		RemoveAdminVars.menu = SlmodAdminMenu
		RemoveAdminVars.description = 'Say in chat "-admin remove <player name>" to remove a player from the list of server admins.'
		RemoveAdminVars.active = true
		RemoveAdminVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		RemoveAdminVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'remove',
						required = true
						},
					[3] = {
						type = 'text',  -- new match type- ALL remaining text from chat message!  Can only be the last variable.
						varname = 'playername',
						required = true,
					}
				}
			} 
		RemoveAdminVars.onSelect = function(self, vars, client_id)
			--print('in onSelect')
			local playername = vars.playername or ''
			local ucid_cntr = 0
			for ucid, name in pairs(Admins) do
				if type(name) == 'string' and name == playername then
					Admins[ucid] = nil
					ucid_cntr = ucid_cntr + 1
				end
			end
			if ucid_cntr > 0 then
				update_admins()
				
				local AdminName
				if client_id == 1 then
					AdminName = net.get_name(1)
				elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
					AdminName = Admins[slmod.clients[client_id].ucid]
				else
					AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
				end
				
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: admin "' .. AdminName .. '" removed ' .. tostring(ucid_cntr) .. ' UCIDs associated with player name "' .. playername .. '" from the list of server admins.', 1, 'chat', RemoveAdminVars.menu.scope}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			else
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: unable to find player named "' .. playername .. '" in server admins.', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			end
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(RemoveAdminVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- sixth item, toggle pause
		local TogglePauseVars = {}
		TogglePauseVars.menu = SlmodAdminMenu
		TogglePauseVars.description = 'Say in chat "-admin pause" to toggle pause on/off.'
		TogglePauseVars.active = true
		TogglePauseVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		TogglePauseVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'pause',
						required = true
					}
				},
				[2] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'unpause',
						required = true
					}
				}
			} 
		TogglePauseVars.onSelect = function(self, vars, client_id)
			if not client_id then
				client_id = vars
			end
			
			local AdminName
			if client_id == 1 then
				AdminName = net.get_name(1)
			elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
				AdminName = Admins[slmod.clients[client_id].ucid]
			else
				AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
			end
			
			if net.is_paused() then
				net.resume()
				slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" unpaused the game.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			else
				net.pause()
				if not slmod_pause_override then 
					slmod_pause_forced = true
				end
				slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" paused the game.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			end
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(TogglePauseVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- pause control override
		if slmod.config.pause_when_empty then
			local PauseOverrideVars = {}
			PauseOverrideVars.menu = SlmodAdminMenu
			PauseOverrideVars.description = 'Say in chat "-admin override pause" to temporarily enable/disable the server pause when empty feature.'
			PauseOverrideVars.active = true
			PauseOverrideVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
			PauseOverrideVars.selCmds = {
					[1] = {
						[1] = { 
							type = 'word', 
							text = '-admin',
							required = true
						}, 
						[2] = { 
							type = 'word',
							text = 'over',
							required = true
						},
						[3] = { 
							type = 'word', 
							text = 'paus',
							required = true
						}
					},
					[2] = {
						[1] = { 
							type = 'word', 
							text = '-admin',
							required = true
						}, 
						[2] = { 
							type = 'word',
							text = 'paus',
							required = true
						},
						[3] = { 
							type = 'word', 
							text = 'over',
							required = true
						}
					},
				} 
			PauseOverrideVars.onSelect = function(self, vars, client_id)
				if not client_id then
					client_id = vars
				end
				
				local AdminName
				if client_id == 1 then
					AdminName = net.get_name(1)
				elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
					AdminName = Admins[slmod.clients[client_id].ucid]
				else
					AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
				end
				
				slmod_pause_forced = false --toggle off pause forced when override enabled/disabled.
				
				if not slmod_pause_override then
					slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" has enabled manual pause control.  The server will NOT pause when empty!'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
					slmod_pause_override = true
				else
					slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" has disabled manual pause control.  The server will pause when empty.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
					slmod_pause_override = false
				end
			end
			
			AdminItems[#AdminItems + 1] = SlmodMenuItem.create(PauseOverrideVars)  -- add the item into the items table.
		end
		-------------------------------------------------------------------------------------------------------
		
		
		-----------------------------------------------------------------------------------------------
		-- seventh item, reload mission
		local ReloadVars = {}
		ReloadVars.menu = SlmodAdminMenu
		ReloadVars.description = 'Say in chat "-admin restart" to restart the current mission.'
		ReloadVars.active = true
		ReloadVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		ReloadVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'resta',
						required = true
					}
				},
				[2] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'reloa',
						required = true
					}
				}
			} 
		ReloadVars.onSelect = function(self, vars, client_id)
			if not client_id then
				client_id = vars
			end
			
			local AdminName
			if client_id == 1 then
				AdminName = net.get_name(1)
			elseif slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
				AdminName = Admins[slmod.clients[client_id].ucid]
			else
				AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
			end
			
			slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" is restarting the mission.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			slmod.scheduleFunctionByRt(net.load_mission, {slmod.current_mission}, net.get_real_time() + 5)
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(ReloadVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- eighth item, load a mission
		local LoadMisVars = {}
		LoadMisVars.menu = SlmodAdminMenu
		LoadMisVars.description = 'Say in chat "-admin load" to load a new mission from a list of available missions.'
		LoadMisVars.active = true
		LoadMisVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		LoadMisVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'word', 
						text = '-admin',
						required = true
					}, 
					[2] = { 
						type = 'word',
						text = 'load',
						required = true
					},
					[3] = { 
						type = 'word', 
						text = 'mis',
						required = false
					}
				}
			} 
		LoadMisVars.onSelect = function(self, vars, client_id)
			if not client_id then
				client_id = vars
			end
			create_LoadMissionMenuFor(client_id)
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(LoadMisVars)  -- add the item into the items table.
		
		-----------------------------------------------------------------------------------------------
		-- ninth item, enable/disable stats
		local toggleStatsVars = {}
		toggleStatsVars.menu = SlmodAdminMenu
		toggleStatsVars.description = 'Say in chat "-admin toggle stats" to toggle SlmodStats stats recording on/off.'
		toggleStatsVars.active = true
		toggleStatsVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		toggleStatsVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-admin',
					required = true
				}, 
				[2] = { 
					type = 'word',
					text = 'tog',
					required = true
				},
				[3] = { 
					type = 'word', 
					text = 'stat',
					required = true
				}
			}
		} 
		toggleStatsVars.onSelect = function(self, vars, clientId)
			if not clientId then
				clientId = vars
			end
			local AdminName
			if clientId == 1 then
				AdminName = net.get_name(1)
			elseif slmod.clients[clientId] and slmod.clients[clientId].ucid and Admins[slmod.clients[clientId].ucid] then
				AdminName = Admins[slmod.clients[clientId].ucid]
			else
				AdminName = '!UNKNOWN ADMIN!' -- should NEVER get to this.
			end
			if slmod.config.enable_slmod_stats then
				slmod.config.enable_slmod_stats = false
				slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" has disabled stats tracking.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			else
				slmod.config.enable_slmod_stats = true
				slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. AdminName .. '" has enabled stats tracking.'}, net.get_real_time() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.
			end
		end
		
		AdminItems[#AdminItems + 1] = SlmodMenuItem.create(toggleStatsVars)  -- add the item into the items table.
		-------------------------------------------------------------------------------------------------------

		update_scope()   -- keep scope updated with all connected server admins.
	end
	
	------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	-- New menu- admin registration menu.  Can register yourself as an admin.
	if slmod.config.admin_register_password then
		----------------------------------------------------------------------------------------
		-- new function: creates the invisible menu for password entry
		local function create_PasswordEntryFor(id)  --creates the temporary password entry menu for this client.

			local PasswordShowCommands = {} --no show commands for this menu!

			local PasswordItems = {}
			local PasswordMenu = SlmodMenu.create({ showCmds = PasswordShowCommands, scope = {clients = {id}}, options = {display_time = 5, display_mode = 'chat', title = 'Please enter the password to register you as a server admin (your next chat message in this mission will not be publicly displayed).', privacy = {access = true, show = true}}, items = PasswordItems})
			--slmod.scheduleFunctionByRt(SlmodMenu.destroy, {PasswordMenu}, net.get_real_time() + 120)  --scheduling self-destruct of this menu in two minutes.
			
			local PasswordVars = {}
			PasswordVars.menu = PasswordMenu
			PasswordVars.description = ''
			PasswordVars.active = true
			PasswordVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
			PasswordVars.selCmds = {
				[1] = {
					[1] = { 
						type = 'text',
						varname = 'password',
						required = true,
					} 
				}
			} 
			PasswordVars.onSelect = function(self, vars, client_id)	
				slmod.scheduleFunctionByRt(SlmodMenu.destroy, {PasswordMenu}, net.get_real_time() + 0.1) -- Schedule first, incase Lua error below.
				local password = vars.password
				if password and password == slmod.config.admin_register_password then
					slmod.scopeMsg('Slmod: player "' .. tostring(net.get_name(client_id)) .. '" has registered as a server admin.', 1, 'chat', SlmodAdminMenu.scope)
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: you have been registered as an admin on this server.', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)
					update_admins(slmod.clients[client_id])
				else
					slmod.scopeMsg('Slmod: player "' .. tostring(net.get_name(client_id)) .. '" attempted to register as server admin with invalid password.', 1, 'chat', SlmodAdminMenu.scope)
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: invalid password. DO NOT ATTEMPT TO RE-ENTER THE PASSWORD.  Type "-reg" again in chat to start over again!', 1, 'chat', {clients = {client_id}}}, net.get_real_time() + 0.1)
				end
			end

			PasswordItems[1] = SlmodMenuItem.create(PasswordVars) 	
			
			PasswordMenu:show()
		end
		----------------------------------------------------------------------------------------

		-- admin register show commands
		local AdminRegisterShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-admin',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'reg',
					required = true,
				},
				[3] = {
					type = 'word',
					text = 'help',
					required = false,
				}
			}
		}
			
		local AdminRegisterItems = {}
		
		-- create the menu.
		local SlmodAdminRegisterMenu = SlmodMenu.create({ showCmds = AdminRegisterShowCommands, scope = {coa = 'all'}, options = {display_time = 5, display_mode = 'chat', title = 'Slmod Admin Registration', privacy = {access = true, show = true}}, items = AdminRegisterItems})
			
		----------------------------------------------------------------------------------------------------------
		-- Create the items
		local AdminRegisterVars = {}
		AdminRegisterVars.menu = SlmodAdminRegisterMenu
		AdminRegisterVars.description = 'Say "-reg" in chat to enable password entry for server admin registration.'
		AdminRegisterVars.active = true
		AdminRegisterVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		AdminRegisterVars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-reg',
					required = true
				}
			}
		}
		AdminRegisterVars.onSelect = function(self, vars, client_id)
			if not client_id then
				client_id = vars
			end
			create_PasswordEntryFor(client_id)
		end
		
		AdminRegisterItems[1] = SlmodMenuItem.create(AdminRegisterVars)  -- add the item into the items table.

	end
	------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------
	-- function(s) to get private data about AdminMenu.
	function slmod.isAdmin(ucid)
		if Admins[ucid] then
			return true
		else
			return false
		end
	end
	
	
end

slmod.info('SlmodAdminMenu.lua loaded')