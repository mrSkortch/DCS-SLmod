--------------------------------------------------------------------------------------------------------------------------
-- Parallel Tasking System menu class
PTSMenu = {
	create = function(showCmds, scope, options, items)

		options = options or {}
		options.privacy = options.privacy or {}
		options.privacy.access = options.privacy.access or true  -- default: no one can see the menu show request except those who request it
		options.privacy.show = options.privacy.show or true -- default: no one can see the menu except those who request it
		
		options.itemSelCmd_base = options.itemSelCmd_base or '-st' --need to define a default 
		
		options.task_display_time = options.task_display_time or slmod.config.PTS_task_display_time
		options.task_display_mode = options.task_display_mode or slmod.config.PTS_task_display_mode
		
		options.display_mode = options.display_mode or slmod.config.PTS_list_display_mode
		options.display_time = options.display_time or slmod.config.PTS_list_display_time
		
		local new = SlmodMenu.create({showCmds = showCmds, scope = scope, options = options, items = items})
		new.task_count = 0
		setmetatable(new, { __index = PTSMenu })-- make the new PTSMenu type object look in the PTSMenu table instead of SlmodMenu
		return new
	end,
	--slmod.add_task_net(coa, id, task_type, description, prefacemsg, group, numdigits, direction, radius)
	add_task = function(self, options, task_data) --self here: the menu
		--[[ task_data: table containing (potentially) these entries:
		task_data.id
		task_data.task_type
		task_data.description
		task_data.msg
		task_data.group
		task_data.numdigits
		task_data.direction
		task_data.radius
	
		]]
		--create the menu item:
		local vars = {} --vars needs to include
		self.task_count = self.task_count + 1
		vars.description = 'Task ' .. tostring(self.task_count) .. ': ' .. task_data.description .. ', say "-st' .. tostring(self.task_count) .. '" to show this task.'
		vars.plain_description = task_data.description
		vars.task_type = task_data.task_type
		vars.msg = task_data.msg
		vars.group = task_data.group
		vars.numdigits = task_data.numdigits
		vars.direction = task_data.direction
		vars.radius = task_data.radius or 3000  --check if this is correct default value.
		vars.id = task_data.id
		vars.task_num = self.task_count
		vars.menu = self
		vars.selCmds = {
			[1] = { --  "-st#"
				[1] = {  
					type = 'word',
					text = self.options.itemSelCmd_base .. tostring(self.task_count),  -- which, by default, will be "-st#"
					required = true
				}
			},
			[2] = {  -- "-st #"   doesn't work, examine.
				[1] = {  
					type = 'word',
					text = self.options.itemSelCmd_base .. tostring(self.task_count),  -- which, by default, will be "-st"
					required = true
				},
				[2] = {  
					type = 'word',
					text = tostring(self.task_count),  -- which, by default, will be "#"
					required = true
				}
			}
		}
		vars.options = options or {}
		vars.options.privacy = vars.options.privacy or {}
		vars.options.privacy.access = vars.options.privacy.access or true 
		vars.options.privacy.show = vars.options.privacy.show or true   
		
		vars.show = function(self, scope, display_time, display_mode)
			
			display_time = display_time or self:getMenu().options.task_display_time
			display_mode = display_mode or self:getMenu().options.task_display_mode
			
			scope = scope or self:getMenu().scope
			
			if self.task_type == 'msg_LL' then
				
				local msg_string =  net.dostring_in('server', 'return get_coords_msg_string(\'LL\', ' .. slmod.basicSerialize(self.msg) .. ', ' .. slmod.oneLineSerialize(self.group) .. ', ' .. tostring(self.numdigits) .. ')')
				if msg_string and msg_string ~= '' then
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {msg_string, display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				else
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Unable to show task.', display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				end
			elseif self.task_type == 'msg_MGRS' then
				
				local msg_string =  net.dostring_in('server', 'return get_coords_msg_string(\'MGRS\', ' .. slmod.basicSerialize(self.msg) .. ', ' .. slmod.oneLineSerialize(self.group) .. ', ' .. tostring(self.numdigits) .. ')')
				if msg_string and msg_string ~= '' then
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {msg_string, display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				else
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Unable to show task.', display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				end
			elseif self.task_type == 'msg_out' then
				
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {self.msg, display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
			
			elseif self.task_type == 'msg_leading_LL' then
				local msg_string =  net.dostring_in('server', 'return get_leading_msg_string(\'LL\', ' .. slmod.basicSerialize(self.msg) .. ', ' .. slmod.oneLineSerialize(self.group) .. ', ' .. slmod.basicSerialize(self.direction) .. ', ' .. tostring(self.radius) .. ', ' .. tostring(self.numdigits) .. ')')
				if msg_string and msg_string ~= '' then
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {msg_string, display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				else
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Unable to show task.', display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				end
			elseif self.task_type == 'msg_leading_MGRS' then
				local msg_string =  net.dostring_in('server', 'return get_leading_msg_string(\'MGRS\', ' .. slmod.basicSerialize(self.msg) .. ', ' .. slmod.oneLineSerialize(self.group) .. ', ' .. slmod.basicSerialize(self.direction) .. ', ' .. tostring(self.radius) .. ', ' .. tostring(self.numdigits) .. ')')
				if msg_string and msg_string ~= '' then
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {msg_string, display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				else
					slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Unable to show task.', display_time, display_mode, scope}, DCS.getRealTime() + 0.1)
				end
			end
		end
		
		vars.onSelect = function(self, client_id)  --self here is the item itself
			
			local scope
			if self.options.privacy.show then
				scope = { clients = {client_id}}
			else
				scope = self:getMenu().scope
			end
			self:show(scope)
		end
	
		self:addItem(SlmodMenuItem.create(vars))
	end,
	
	remove_task = function(self, id)  --not really necessary, but I'm including it anyway.
		self:removeById(id)
	end,
	

}
setmetatable(PTSMenu, { __index = SlmodMenu }) -- ok, now point the PTSMenu to SlmodMenu

slmod.info('SlmodPTSMenu.lua loaded.')