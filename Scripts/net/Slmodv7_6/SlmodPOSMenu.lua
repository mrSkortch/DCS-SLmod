-------------------------------------------------------------------------------------------------------------------
-- Parallel Options System menu class
POSMenu = {
	create = function(showCmds, scope, options, items)

		options = options or {}
		options.privacy = options.privacy or {}
		options.privacy.access = options.privacy.access or true  -- default: no one can see the menu show request except those who request it
		options.privacy.show = options.privacy.show or true -- default: no one can see the menu except those who request it
		
		options.itemSelCmd_base = options.itemSelCmd_base or '-op' --need to define a default 
		
		options.display_mode = options.display_mode or slmod.config.POS_list_display_mode
		options.display_time = options.display_time or slmod.config.POS_list_display_time
		
		local new = SlmodMenu.create({ showCmds = showCmds, scope = scope, options = options, items = items})
		new.option_count = 0
		setmetatable(new, { __index = POSMenu })-- make the new POSMenu type object look in the POSMenu table instead of SlmodMenu
		return new
	end,
	
	add_option = function(self, id, description, flag) --self here: the menu
		--create the menu item:
		local vars = {} --vars needs to include
		self.option_count = self.option_count + 1
		vars.description = 'Option ' .. tostring(self.option_count) .. ': ' .. description .. ', say "-op' .. tostring(self.option_count) .. '" to select this option.'
		vars.plain_description = description
		vars.id = id
		vars.flag = flag
		vars.option_num = self.option_count
		vars.menu = self
		vars.selCmds = {
			[1] = {
				[1] = {  
					type = 'word',
					text = self.options.itemSelCmd_base .. tostring(self.option_count),  -- which, by default, will be "-op#"
					required = true
				}
			},
			[2] = {
				[1] = {  
					type = 'word',
					text = self.options.itemSelCmd_base .. tostring(self.option_count),  -- which, by default, will be "-op"
					required = true
				},
				[2] = {  
					type = 'word',
					text = tostring(self.option_count),  -- which, by default, will be "#"
					required = true
				}
			}
		}
		vars.options = {}
		vars.options.privacy = {}
		vars.options.privacy.access = true    -- vars.options.privacy.show not used.
		
		vars.onSelect = function(self, client_id)  --self here is the item itself
			net.dostring_in('server', 'trigger.action.setUserFlag(' .. tostring(self.flag) .. ', true)')
			local playername = '!UNKNOWN PLAYER!'
			if client_id then

				playername = net.get_name(client_id)
				
				--donno why I was using this old code below... the above method is vastly easier
				-- local side, unit_id = net.get_slot(client_id)
				-- unit_id = unit_id or -1
				-- unit_id = tonumber(unit_id)
				-- if unit_id and unit_id > 0 then		
					-- local name = DCS.getUnitProperty(unit_id, 14)
					-- if type(name) == 'string' and name ~= '' then
						-- playername = name
					-- end
				-- end
				
			end
			--slmod.scopeMsg(playername .. ' selected option ' .. tostring(self.option_num) .. ', "' .. self.plain_description .. '"', 5, 'chat', self:getMenu().scope)   -- don't do msg out yet, otherwise the confirmation text will come BEFORE the chat command to do the menu item.
			slmod.scheduleFunctionByRt(slmod.scopeMsg, {playername .. ' selected option ' .. tostring(self.option_num) .. ', "' .. self.plain_description .. '"', 5, 'chat', self:getMenu().scope}, DCS.getRealTime() + 0.1)
		end
		self:addItem(SlmodMenuItem.create(vars))
	end,
	
	remove_option = function(self, id)  --not really necessary, but I'm including it anyway.
		self:removeById(id)
	end,
	

}
setmetatable(POSMenu, { __index = SlmodMenu }) -- ok, now point the POSMenu to SlmodMenu

slmod.info('SlmodPOSMenu.lua loaded.')