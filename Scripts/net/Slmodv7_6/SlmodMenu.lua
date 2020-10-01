--SlmodMenu class and associated functions
do
	local menus = {}  -- a table that holds all current menus.
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	-- Beginning of SlmodMenu class
	SlmodMenu = {
		--constructor function
		create = function (vars) -- items, options- theses are optional.  Initial items can be assigned here at creation, or added later.
			
			local new = {}
			for ind, val in pairs(vars) do
				new[ind] = val  -- probably unnecessary... need to be very! careful when creating items that they use different tables.
			end
			
			if not (new.showCmds or new.scope) then -- don't allow menu to be created at all if these aren't specified.
				return false
			end
			-- showCmds: single table, accepted chat commands to get the table to show
			--[[ scope follows this format: scope = { coas = {}, clients = {}, units = {} } , coas = coalitions, clients = client nums, units = unit runtime id
				If you belong to any one of the tables, you can see and interact with a menu.]]
			
			new.items = new.items or {}  -- The actual menu items
			--[[an example item  [1] = { description = string, onSelect = function, active = bool, selCmds = {}, id =  number --optional, options = {} }   ]]
			--options include display_time, display_mode, and title
			
			--[[ ANOTHER LIKELY "TO IMPLEMENT":
				some kind of confirm selection variable.  "Are you sure you want to access this" or something.  
				Menu items can be easy to accidentally select, and this could be a problem if it's something critical.
			]]
			
			--[[Possible "TO IMPLEMENT":
				Variable to make it so that menu items are only selectable while they are being shown, or within a certain time frame
				after the menu is called?
			
			]]

			new.options = new.options or {}
			new.options.display_time = new.options.display_time or 40
			new.options.display_mode = new.options.display_mode or 'echo'
			
			--create privacy options:
			new.options.privacy = new.options.privacy or {} --create privacy table
			
			new.options.privacy.access = new.options.privacy.access or false  -- default to allow everyone in scope to see access to menu showing
			new.options.privacy.show = new.options.privacy.show or false -- default to allow everyone in scope to see showing of the menu after access
			--new.options.title = new.options.title or ''
			
			new.active = new.active or true
			--new.SelfName = SelfName
			
			menus[new] = new
			
			setmetatable(new, { __index = SlmodMenu }) -- set SlmodMenu as prototype
			return new
		end,
		
		
		setDisplayTime = function(self, display_time)
			self.options.display_time = display_time
		end,
		
		
		setDisplayMode = function(self, display_mode)
			self.options.display_mode = display_mode
		end,
		
		setScope = function(self, scope)
			self.scope = scope
		end,
		
		
		setShowCmds = function(self, showCmds)
			self.showCmds = showCmds
		end,
		
		getScope = function(self)
			return self.scope
		end,
		
		getItems = function(self)
			return self.items
		end,
		
		-- set_SelCmds = function(self, selCmds)
			-- self.selCmds = selCmds
		-- end,
		
		getSelCmds = function(self)  -- not used atm
			local selCmds = {}
			for i = 1, #self.items do
				if self.items[i] and self.items[i].active == true and self.items[i].selCmds then
					selCmds[i] = self.items[i].selCmds  --not consecutive elements, so will need to do for i,v in pairs(selCmds) to unpack
				end
			end
			return selCmds
		end,
		
		addItem = function(self, item)  -- item == table , = { description = string, onSelect = function, active = bool, (optional) selCmds = table, (optional) id = number }
			--first, edit if necessary
			for i = 1, #self.items do
				if self.items[i].id and item.id and self.items[i].id == item.id then --match found, edit
					self.items[i] = item
					return --no need to do anything else
				end
			end
			--if still here, no id match found
			table.insert(self.items, item)			
			--item is a table that includes various options such as active when visible or not, and the onSelect function.
		
		end,
		
		removeByInd = function(self, ind)  --not really used ATM
			if self.items[ind] then
				table.remove(self.items, ind)
				return true --success
			end
			return false --failed to find
		end,
		
		removeById = function(self, id)
			for i = 1, #self.items do
				if self.items[i].id and self.items[i].id == id then --match found
					table.remove(self.items, i)
					return true  --success
				end
			end
			return false --failed to find
		end,
		
		setItemActiveByInd = function(self, ind, state)
			if self.items[ind] then
				self.items[ind].active = state
				return true --success
			end
			return false --failure
		end,
		
		setItemActiveById = function(self, id, state)
			for i = 1, #self.items do
				if self.items[i].id and self.items[i].id == id then --match found
					self.items[i].active = state
					return true  --success
				end
			end
			return false --failed to find
		end,
		
		destroy = function(self)
			if menus and menus[self] then
				menus[self] = nil --remove from global table of menus
			end 
			return nil -- not really necessary, but helps me think of the way this should be used.
		end,
		
		
		show = function(self, client_id, show_scope)  --show_scope here is optional.  Allows you to optionally specify a show_scope.  If show_scope not specified, show_scope is retrieved from the menu- it's the scope of the menu if the options.privacy.show is false, otherwise, it's just the caller.
			if self.active then
				local msgstring = ''
				if self.options and self.options.title then
					msgstring = msgstring .. self.options.title .. '\n'
				end
				
				local active_item_count = 0  --count active items, not just items.
				for i = 1, #self.items do
					if self.items[i].active then
						active_item_count = active_item_count + 1
					end
				end
				
				if active_item_count == 0 then
					msgstring = msgstring .. '(This menu is empty)'
				else
					for i = 1, #self.items do
						if self.items[i].active then
							--msgstring = msgstring .. tostring(i) .. ') ' .. self.items[i].description .. '\n'   --lets NOT list a number first.
							msgstring = msgstring .. '--> ' .. self.items[i].description .. '\n'
						end
					end
				end
				if not show_scope then
					if (not client_id) or (not self.options.privacy.show) then
						show_scope = self.scope -- show menu to all in scope if no client_id passed to function 
					else  -- so a either a client_id was not passed or this is supposed to be a private showing.
						show_scope = {clients = {client_id}}
					end
					
				end
                
                
				slmod.scopeMsg(msgstring, self.options.display_time, self.options.display_mode, show_scope)
			end	
		end,
		
		setMenuActive = function(self, state)  -- for activating or deactivating list
			if self.active ~= state then
				self.active = state
			end
		end,
		
		getShowCmds = function(self)
			return self.showCmds
		end,
		
		getItemById = function(self, id)  --get an item by id
			for i = 1, #self.items do
				if self.items[i].id and self.items[i].id == id then --match found
					return self.items[i]
				end
			end
		end,
	} -- end of SlmodMenu class
	
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	-- Beginning of SlmodMenuItem class
	
	--[[ Some required fields for the table of variables for the SlmodMenuItem.create construtor
	  id = number
	  description = string
	  menu = table, the menu this item belongs to  --not required
	  selCmds = item selection commands
	  onSelect = function, what happens when this item is selected, not required, some menu items might just show something.
	  options = table
	  options.display_time = number, optional, if this item displays something, store its display time here.
	  options.display_mode = string, optional, if this item displays something, store its display mode here.
	  options.privacy = table
	  options.privacy.access = boolean - hide/show the chat message that accesses this option when someone says it, true is to hide it from everyone else
	  options.privacy.show = if this item shows something, then use this variable to hide/show the thing to only the person who selected the item
	  active = boolean - whether this item is active or not (visible and selectable in the menu)
	  ]]
	SlmodMenuItem = {
		--constructor function
		create = function (vars) -- vars is table of things
			local new = {}
			
			
			for ind, val in pairs(vars) do  -- probably unnecessary.
				new[ind] = val  -- assign all fields in vars to the new item.
			end
			-- new.description = vars.description
			-- new.id = vars.id
			-- new.menu = vars.menu  --what menu owns this item
			-- new.selCmds = vars.selCmds -- single table, accepted chat commands to get the table to show
			-- new.onSelect = vars.onSelect
			
			new.options = new.options or {}
			new.options.display_time = new.options.display_time or 40
			new.options.display_mode = new.options.display_mode or 'echo'
		
			--create privacy options:
			new.options.privacy = new.options.privacy or {} --create privacy table
			
			new.options.privacy.access = new.options.privacy.access or false  -- default to allow everyone in scope to see selection of this item
			new.options.privacy.show = new.options.privacy.show or false -- if the menu item shows something, then this variable can control the privacy of the showing
			--new.options.title = new.options.title or ''
			
			new.active = new.active or true
			
			new.onSelect = new.onSelect or function() end  -- at least make an empty onSelect function.
			
			setmetatable(new, { __index = SlmodMenuItem }) -- set SlmodMenuItem as prototype
			return new
		end,
		
		getMenu = function(self)
			return self.menu
		end,
		
		setDisplayTime = function(self, display_time)
			self.options.display_time = display_time
		end,
		
		
		setDisplayMode = function(self, display_mode)
			self.options.display_mode = display_mode
		end,
		
		setPrivacy = function(self, privacy)
			self.options.privacy = privacy
		end,

	} -- End of SlmodMenuItem class

	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--[[ Three functions follow:
	local function getCoords - takes raw text and tries to turn it into coordinates.  Text is supplied from a chat message.  Used in cmdMatch (below).
	local function cmdMatch - attempts to determine if a specific chat message said by a specific player matches a SlmodMenu command from one of the menus in the local menus table (local to this do - end statement)
	slmod.doMenuCommands - called in server.on_chat, it runs cmdMatch and any required onSelect functions.
	
	Really all three of these functions could be combined into slmod.doMenuCommands, but the code would be even more confusing than it is now.
	
	]]

	local function getCoords(s) --retrieves coordinates from raw chat text.  Used in cmdMatch.
		--[[ returns a error code, string, and table
			error code: 1 - successful
						0 - successful, but with warning(s)
					   -1 - unsuccessful
			string: any warnings/errors, also, 'success' if successful
			
			table: the coordinates
				MGRS = { type = 'MGRS', UTMZone = string, MGRSDigraph = string, Easting = number, Northing = number}
				LL = { type = 'LL', lat = number (degrees), lon = number (degrees)}
				BR = { type = 'BR', az = number (TBD), dist = number (TBD)} -- bearing and range, ref point determined outside this function
		

		]]
		----------------------------------------------------------------------------------------
		--Local function GetFields
		local GetFields = function(s)  -- returns table of fields and separators 
			local GetNextNumField = function(s) 
				local sep_s = (s:find('[^%d]'))
				if sep_s ~= nil then 
					local field = s:sub(1, sep_s - 1)
					local next_field_s = (s:find('%d', sep_s))
					if next_field_s then
						return field, s:sub(sep_s, next_field_s - 1), s:sub(next_field_s)  -- the numeric field, the separator, and the new string
					else
						return field, s:sub(sep_s) -- the numeric field, the separator
					end
				else
					return s  -- just return s, which is the field.
				end
			end 
			local field_s, sep, field
			local fields = {}
			while s do
				field_s, sep, s = GetNextNumField(s)
				-- net.log(field_s)
				-- net.log(sep)
				-- net.log(s)
				-- net.log('\n')
				if field_s then
					field = {}
					field['val'] = field_s
					if sep then
						field['sep'] = sep
					end	
					table.insert(fields, field)
				else
					break --not really necessary, but need to make sure
				end
			end
			return fields
		end
		---------------------------------------------------------------------------------
		--Local function GetCoordType
		local GetCoordType = function (s)
			local new_s = s:gsub('[^%d%a]', '')  --remove anything not a letter and not a number
			-- while ind <= new_s:len() do
				-- if new_s:sub(ind,ind) == ' ' then
					-- new_s = RemoveChar(new_s, ind)
				-- else
					-- ind = ind + 1
				-- end
			-- end
			if new_s ~= '' then
				local chars_s, chars_e = new_s:find('%u%u%u')
				if chars_s then
					if (string.sub(new_s, chars_s, chars_e) == 'FOR') and (chars_s > 1) and (chars_e < new_s:len()) then  --'FOR' exists in string, 'FOR' does not begin or end the string
						if string.find(new_s:sub(1, chars_s - 1), '[^%d]') or string.find(new_s:sub(chars_e + 1, new_s:len()), '[^%d]') then -- there are non-numbers found before or after 'FOR'
							return nil
						else  -- no non-numbers found before or after 'FOR'
							return 'BR'
						end
					--so not BR, is it MGRS?
					elseif ((chars_s == 2) or (chars_s == 3)) then -- the three letters begin in the right place
						if string.find(new_s:sub(1, chars_s - 1), '[^%d]') then --not MGRS if not numbers before 3 char sequence
							return nil
						else
							if chars_e == new_s:len() then  --if no northing or easting at all, still valid coords
								return 'MGRS'
							else
								if string.find(new_s:sub(chars_e+1, new_s:len()), '[^%d]') then --if any non-digits found after three char sequence
									return nil
								else
									return 'MGRS'
								end
							end
						end
						
					else
						return nil
					end
				end
				--OK, so there is no three-character sequence.  Is there a "NXXXXEXXXX", "XXXXNEXXXX", or "XXXXXNXXXXE"?
				if new_s:find('[^%dNESW]') then --if it finds anything that is not a digit AND not "N" AND not "E" and not "S" and not "W"
					return nil --can't interpret this
				else
					local lat_s = new_s:find('[NS]')
					local lon_s = new_s:find('[EW]')
					if lat_s and lon_s and lon_s > lat_s then --ok, so lat start and lon start detected, in proper order
						--case 1: "NXXXXEXXXX"
						if lat_s == 1 and lon_s < new_s:len() then
							if string.find(new_s:sub(2, lon_s - 1), '[^%d]') or string.find(new_s:sub(lon_s + 1, new_s:len()), '[^%d]') then --non number found
								return nil
							else
								return 'LL', 'NXEX'
							end
						--case 2: XXXXNXXXXE
						elseif (lat_s > 1 and lon_s == new_s:len()) then
							if string.find(new_s:sub(1, lat_s - 1), '[^%d]') or string.find(new_s:sub(lat_s + 1, new_s:len() - 1), '[^%d]') then --non number found
								return nil
							else
								return 'LL', 'XNXE'
							end
						--case 3: XXXXNEXXXX , not really correct, but I can figure this one out
						elseif (lat_s > 1 and lon_s == lat_s + 1) then
							if string.find(new_s:sub(1, lat_s - 1), '[^%d]') or string.find(new_s:sub(lon_s + 1, new_s:len()), '[^%d]') then --non number found
								return nil
							else
								return 'LL', 'XNEX'
							end
						else
							return nil
						end
					else
						return nil
					end
					
				end
			else
				return nil
			end
		end
		---------------------------------------------------------------------------------
		-- Compute Value function
		local FindDMS = function(fields)
			local dms = {} 
			--[=[fields contains field values:
			Examples (some of these are examples of incorrect input!
			Exs: fields = { [1] = { val = "044", sep = ' '}, [2] = { val = "39", sep = "'" }, [3] = { val = "14", sep = [["]]}}
			Exs: fields = { [1] = { val = "044", sep = ' '}, [2] = { val = "39"}}
			Exs: fields = { [1] = { val = "044", sep = '.'}, [2] = { val = "39", sep = "'" }, [3] = { val = "14"}}
			]=]
			if (#fields >= 1) and (#fields <= 4) then  --only up to four fields allowed
			
				--first field degrees
				local value = tonumber(fields[1].val)
				if value then
					dms[1] = value
					if #fields == 1 then
						return dms, 'D'
					end
				else
					return -1, 'Invalid Field Value 1'
				end
				if #fields == 2 then 
					--Two possibilities here:
					--	-Degrees(decimal)
					--  -Degrees, minutes(whole)
					local value = tonumber(fields[2].val)
					if value then
						if fields[1].sep:sub(1,1) == '.' then --interpret as decimal degrees the second field
							dms[1] = dms[1] + value/(10^( fields[2].val:len()))
							-- Done, lets return
							return dms, 'D'
						else -- interpret as minutes
							if value < 60 then
								dms[2] = value
								return dms, 'DM'
							else
								return -1, 'Invalid Field Value 2'
							end
						
						end
					else
						return -1, 'Invalid Field Value 3'
					end
				end
				if #fields == 3  then
					--Could be:
					--	-Degrees, minutes(decimal)
					--	-Degrees, minutes, seconds(whole)
					local value = tonumber(fields[2].val)
					if value and value < 60 then
						dms[2] = value
						
						if fields[2].sep:sub(1,1) == '.' then --interpret as degrees, decimal minutes
							value = tonumber(fields[3].val)
							if value then
								dms[2] = dms[2] + value/(10^( fields[3].val:len()))
								return dms, 'DM'
							else
								return -1, 'Invalid Field Value'
							end
								
						else --interpret as DMS
							value = tonumber(fields[3].val)
							if value and value < 60 then
								dms[3] = value
								return dms, 'DMS'
							else
								return -1, 'Invalid Field Value'
							end
							
						end
					else
						return -1, 'Invalid Field Value'
					end
				
				end
				
				if #fields == 4 then
					--only can be be:
					--	-Degrees, minutes, seconds(decimal)
					local value = tonumber(fields[2].val)
					if value and value < 60 then
						dms[2] = value -- add in the minutes
							
						value = tonumber(fields[3].val)
						if value and value < 60 then
							dms[3] = value
							
							value = tonumber(fields[4].val)
							if value then
								dms[3] = dms[3] + value/(10^( fields[4].val:len()))
								return dms, 'DMS'
							else
								return -1, 'Invalid Field Value'
							end
						else
							return -1, 'Invalid Field Value'
						end
					else
						return -1, 'Invalid Field Value'
					end
					
				else
					return -1, 'Invalid Field Value'
				end
					
			else
				return -1, 'Invalid Field Count'
			end
		end
		------------------------------------------------------------------------------------------------------------
		
		-- Main part of getCoords function starts here
		local s_orig = s --store the original
		--convert to all caps
		s = s:upper()  
		
		-- Replace commas with spaces
		s = s:gsub(',', ' ')  
		
		-- reduce all spaces to single spaces
		local num_rep = 0 
		repeat
			s, num_rep = s:gsub('  ', ' ')
		until num_rep == 0

		local CoordType, LLVar = GetCoordType(s)
		
		if CoordType then
			if CoordType == 'BR' then
				s = s:gsub(' ', '') --remove spaces
				local for_s, for_e = s:find('FOR')
				local az = tonumber(s:sub(1, for_s - 1))
				local dist = tonumber(s:sub(for_e + 1, s:len()))
				if not az then
					return -1, 'Invalid input for BR coordinate. Unable to determine azimuth.'
				end
				if not dist then
					return -1, 'Invalid input for BR coordinate. Unable to determine distance.'
				end
				if dist < 0 then
					return -1, 'Invalid input for BR coordinate.  You cannot have negative distance.'
				end
				if az >= 0 and az <= 360 then
					local coords = {}
					coords['type'] = 'BR'
					coords['az'] = az
					coords['dist'] = dist
					return 1,  '"' .. s_orig ..  '" interpretted as: ' .. tostring(az) .. ' for ' .. tostring(dist), coords
				else
					return -1, 'Invalid input for BR coordinate. Azimuth from reference point must be between 0 and 360 degrees.'
				end

			elseif CoordType == 'MGRS' then
				s = s:gsub(' ', '') --remove spaces
				local chars_s, chars_e = s:find('%u%u%u')
				local UTMZone, MGRSDigraph, Easting, Northing, coords
				local accuracy -- for the interpretted message
				if chars_e == s:len() then -- zero digit grid
					Easting = 50000  -- center of grid square
					Northing = 50000 
				elseif s:sub(chars_e + 1):len() == 2 then
					Easting = tonumber(s:sub(chars_e + 1, chars_e + 1))*10000  -- + 5000 -- "precision" coordinates now... maybe it's not correct for MGRS system, but people round.
					Northing = tonumber(s:sub(chars_e + 2, chars_e + 2))*10000 -- + 5000
				elseif s:sub(chars_e + 1):len() == 4 then
					Easting = tonumber(s:sub(chars_e + 1, chars_e + 2))*1000 -- + 500 
					Northing = tonumber(s:sub(chars_e + 3, chars_e + 4))*1000 -- + 500
				elseif s:sub(chars_e + 1):len() == 6 then
					Easting = tonumber(s:sub(chars_e + 1, chars_e + 3))*100 -- + 50  
					Northing = tonumber(s:sub(chars_e + 4, chars_e + 6))*100 -- + 50
				elseif s:sub(chars_e + 1):len() == 8 then
					Easting = tonumber(s:sub(chars_e + 1, chars_e + 4))*10 -- + 5
					Northing = tonumber(s:sub(chars_e + 5, chars_e + 8))*10 -- + 5
				elseif s:sub(chars_e + 1):len() == 10 then
					Easting = tonumber(s:sub(chars_e + 1, chars_e + 5)) -- + 0.5
					Northing = tonumber(s:sub(chars_e + 6, chars_e + 10)) -- + 0.5	
				else
					return -1, 'Invalid input for MGRS coordinates, you need to specify 0, 2, 4, 6, 8, or 10 digits total for easting and northing'
				end
				
				local UTMZone = s:sub(1, chars_s)
				local MGRSDigraph = s:sub(chars_s + 1, chars_e)
				
				local coords = {}
				coords['type'] = 'MGRS'
				coords['UTMZone'] = UTMZone
				coords['MGRSDigraph'] = MGRSDigraph
				coords['Easting'] = Easting
				coords['Northing'] = Northing
				
				return 1, '"' .. s_orig ..  '" interpretted as: ' .. UTMZone .. ' ' .. MGRSDigraph .. ' ' ..  string.format('%05d', Easting) .. ' ' .. string.format('%05d', Northing), coords

			elseif CoordType == 'LL' then
				local lat_fields, lon_fields
				local lat_s, lon_s, lat_deg, lon_deg, lat_type, lon_type
				local lat_hemi = s:sub((string.find(s, '[NS]')), (string.find(s, '[NS]')))
				local lon_hemi = s:sub((string.find(s, '[EW]')), (string.find(s, '[EW]')))
				if LLVar == 'XNXE' then
					-- net.log('original string: ')
					-- net.log(s)
					lat_s = s:sub(1, (string.find(s, '[NS]')) - 1)
					lon_s = s:sub( (string.find(s, '%d', (string.find(s, '[NS]')) + 1)), s:len() - 1)
					-- net.log('lat_s and lon_s')
					-- net.log(lat_s)
					-- net.log(lon_s)
					lat_fields = GetFields(lat_s)
					lon_fields = GetFields(lon_s)
				elseif LLVar == 'NXEX' then
					lat_s = s:sub((string.find(s,'%d')), (string.find(s, '[EW]')) - 1)
					lon_s = s:sub( (string.find(s, '%d', (string.find(s, '[EW]')) + 1)) )
					lat_fields = GetFields(lat_s)
					lon_fields = GetFields(lon_s)
				elseif LLVar == 'XNEX' then
					lat_s = s:sub(1, (string.find(s, '[NS]')) - 1)
					lon_s = s:sub( (string.find(s, '%d', (string.find(s, '[EW]')) + 1)) )
					lat_fields = GetFields(lat_s)
					lon_fields = GetFields(lon_s)		
				end	
					
				if #lat_fields >= 1 then
					lat_dms, lat_type  = FindDMS(lat_fields)
					if type(lat_dms) == 'table' then
						lat_deg = lat_dms[1]
						if lat_dms[2] then
							lat_deg = lat_deg + lat_dms[2]/60
						end
						if lat_dms[3] then
							lat_deg = lat_deg + lat_dms[3]/3600
						end
						
						if lat_hemi == 'S' then
							lag_deg = lat_deg*(-1)
						end
					else
						return -1, lat_type  --lat_type is error msg in this case
					end
					if math.abs(lat_deg) > 90 then
						return -1, 'Latitude exceeds max allowable value (+/-90).'
					end
						
				else
					return -1, 'Unable to parse lat fields'
				end
				if #lon_fields >= 1 then
					lon_dms, lon_type  = FindDMS(lon_fields)
					if type(lon_dms) == 'table' then
						lon_deg = lon_dms[1]
						if lon_dms[2] then
							lon_deg = lon_deg + lon_dms[2]/60
						end
						if lon_dms[3] then
							lon_deg = lon_deg + lon_dms[3]/3600
						end
						
						if lon_hemi == 'W' then
							lon_deg = lon_deg*(-1)
						end
					else
						return -1, lon_type  --lon_type is error msg in this case
					end
					if math.abs(lon_deg) > 180 then
						return -1, 'Longitude exceeds max allowable value (+/-180).'
					end
						
				else
					return -1, 'Unable to parse lon fields'
				end
				
				local coords = {}
				coords['type'] = 'LL'
				coords['lat'] = lat_deg
				coords['lon'] = lon_deg
				
				local return_s = '"' .. s_orig .. '" interpretted as: '

				if lat_type == 'D' then
					return_s = return_s .. tostring(lat_dms[1]) .. lat_hemi .. ' '	
				elseif lat_type == 'DM' then
					return_s = return_s .. tostring(lat_dms[1]) .. ' ' .. tostring(lat_dms[2]) .. '\'' .. lat_hemi .. ' '
				elseif lat_type == 'DMS' then
					return_s = return_s .. tostring(lat_dms[1]) .. ' ' .. tostring(lat_dms[2]) .. '\' ' .. tostring(lat_dms[3]) .. '"' .. lat_hemi .. ' '
				end
				if lon_type == 'D' then
					return_s = return_s .. tostring(lon_dms[1]) .. lon_hemi
				elseif lon_type == 'DM' then
					return_s = return_s .. tostring(lon_dms[1]) .. ' ' .. tostring(lon_dms[2]) .. '\'' .. lon_hemi
				elseif lon_type == 'DMS' then
					return_s = return_s .. tostring(lon_dms[1]) .. ' ' .. tostring(lon_dms[2]) .. '\' ' .. tostring(lon_dms[3]) .. '"' .. lon_hemi
				end
				return 1, return_s, coords
				
			end
		else
			return -1, 'Unable to determine coordinate type'
		end
	end-- END OF getCoords function
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	
	-- cmdMatch
	--Determines if a chat message matches an SlmodMenu command, and if so, returns any necessary values from the chat message
	
	--NEED TO SUPPORT A NEW VARIABLE TYPE: A word.  Pass the value of the word_cmd in optionally.
	-- honestly, also need to support a word SET- one of a set of words
	--maybe make 'word' text field optionally a table
	--new piece of data 'word'- 'varname' - if varname exists, then treat this word as an input variable.
	--[[
	[1] = {
			[1] = { 
				type = 'word', 
				text = '-conv',
				required = true
			}, 
			[2] = { 
				type = 'word',
				text = {'bull', 'br'}
				varname = 'br_type', 
				required = false 
			}, 		
				
			[3] = { 
				type = 'coords',
				varname = 'coords', 
				required = true 
			}, 
			[4] = { 
				type = 'word',
				text = 'to',
				required = false
				},
			[5] = {
				type = 'word',
				text = {'bull', 'br', 'mgrs', 'll', 'la'},
				varname = 'toCoords',
				required = true,
			}
		}
	]]
	--[[ RESTRICTIONS (needs updating): 
	1) The contents of a command that come before a variable (at least, a coordinate variable) must be unique 
	(because separate words are delimited by spaces, and coordiantes can have an indeterminate number of these).
	2)VARIABLES CANNOT BEGIN A COMMAND.
	3) All commands must be specified in lower case
	4) No spaces allowed
	5) First word in command must be a word, and required
	6) Vars need padding with words  ??? Still true?
	]]

	--[[ RESTRICTIONS (needs updating): 
	1)VARIABLES CANNOT BEGIN A COMMAND.  ??? Still true?
	3) All commands must be specified in lower case 
	4) No spaces allowed
	5) First word in command must be a word, and required  (Maybe not true anymore)
	6) Vars need padding with words -- yes. A coord must be followed by a required word at some point, or run to the end of the command.
	However, you can have have as many consecutive optional words as you want BEFORE that required word.

	IF YOU ARE USING A 'text' TYPE WORD, ALL 'word' type variables must be unique.  text type commands must be the last commmand too.
	]]

	--[[bool match, table vars = cmdMatch(cmd, s) concept/pseudocode (obsolete): 
	s: received string, a chat message
	cmd: a table of the format described above.
	match: a true or false- if there was a command match
	vars: either nil or a table of variables extracted such as { coords = {...}, radius = 5000 }
	0) Convert s to all lower case(, remove any leading spaces?).
	1) Break string into a table of words (a word is any number of characters delimited by a space)
	2) From the beginning of cmd and s, start comparing the words of s to the words of cmd.  Only the first string.len(cmd[wordnum].text)
	are necessary- so cmd word "-req" would match to the s word "-req" BUT ALSO to the s word "-requesting"
	3) if there is a coordinate variable, then skip through the s words until either the end of s words or another match is found with any additional
	cmd words.  The coordiante variable is concatenated and passed into the coordinate interpreter. The coordiante interpreter returns to cmdMatch the
	coordinate
	4) If there is a required word after an optional word, look for both words at the same time (may need to build an
	  "search for" table or something with all possibilities).
	5) If there is a 'cmd' type variable reached, reassemble remaining words from s that haven't been used and call self on
	this new string.
	6) If all required words are present in command match, and the variables work, then return true

	]]

	--[[ 5/5/12
	New return type:
	instead of just returning true or false if the command matched, return a number:
	-1: no match
	0: partial match
	1: full match

	Partial matches require cmdMatch to be continued to run in case there is a full match.
	]]

	local function cmdMatch(cmd, s)  --determines if s is a version of cmd and returns variables from the message
		--slmod.info('into cmdMatch')
		--slmod.info(type(cmd))
        --slmod.info(slmod.oneLineSerialize(cmd))
		local vars = {}
		if not cmd[1] then --just protecting against empty cmd
			--slmod.info('return empty')
			return -1
		end
		-- need to first make sure that s can actually be a cmd
		if not s:find('[^ ]') then -- if no non-spaces found
			--slmod.info('no non-spaces')
			return -1
		end
		
		local s_original = s  -- save for later...
		
		s = s:lower()  -- convert to lower case
		
		s = s:gsub('\n', ' ') --remove any newlines (not likely to be there)
		
		local num_rep
		repeat  -- reduce all spaces to single space
			s, num_rep = s:gsub('  ', ' ')
		until num_rep == 0
		
		if s:sub(1,1) == ' ' then --remove any leading space
			s = s:sub(2, s:len())
		end
		
		if s:sub(s:len(), s:len()) == ' ' then  --remove any trailing space
			s = s:sub(1, s:len() - 1)
		end 
		
		-- now s definitely begins and ends with a non-space char
		local s_words = {}
		local s_ind = 1
		while s_ind <= s:len() do  -- probably unnecessary to do this check, while true do should work
			local next_space = s:find(' ', s_ind)
			if not next_space then
				table.insert(s_words, s:sub(s_ind, s:len()))  -- go till end
				break
			end
			--if still here, it found something
			table.insert(s_words, s:sub(s_ind, next_space - 1))
			s_ind = next_space + 1
		end
		
		--[[OK, now s should be broken down in to words in the s_words table such as:
		Example s:
		s = "-request bombs at 42 03.123'N 043 49.722'E"
		
		s_words would then be:
		s_words = { 
			[1] = '-request',
			[2] = 'bombs',
			[3] = 'at',
			[4] = '42'
			[5] = '03.124\'n',
			[6] = '043',
			[7] = '49.722\'e'
		}
		]]
		
		--now ready to analyze the message and see if it matches with cmd:
		--slmod.info(slmod.oneLineSerialize(s_words))
		
		 -- returns either true or a index number within the table of words text values of cmd_word for a word match, or false for no match
		 -- second variable: returns true if an exact match, false if not an exact match.
		local function word_match(s_word, cmd_word) 
			--slmod.info(s_word .. ' : ' .. cmd_word.text)
            if cmd_word then -- gotta have this check for next_word_match and the way I use it.
				--slmod.info(cmd_word.text)
                
                if type(cmd_word.text) == 'string' then
					if s_word:sub(1, cmd_word.text:len()) == cmd_word.text then 
						--slmod.info('substring match')
                        return true, (s_word == cmd_word.text)
					end
                  
					return false
				elseif type(cmd_word.text) == 'table' then
					for i = 1, #cmd_word.text do
						if  s_word:sub(1, cmd_word.text[i]:len()) == cmd_word.text[i] then
							return i, (s_word == cmd_word.text[i])
						end
					end
				end
			end
			return false
		end
		
		--search through s_words to find the next match to the next command, or the end of s_words
		--returns: either a positive number (index in s_words that matches the next_cmd), or -1 (for no match to end of s_words)
		local function next_word_match(s_words, cur_s_ind, next_cmd) -- remember! assume that the next command will be a word! 
			for s_ind = cur_s_ind, #s_words do
				if (word_match(s_words[s_ind], next_cmd)) then  --need to pass in more than just the next cmd, the next command could be optional- pass in everything up to the next required word.
					return s_ind
				end
			end
			--reached the end of s_words.  No match with next_cmd.
			--slmod.info('No matches with next_cmd')
            return -1
		end
		
		
		do  -- do some simple checks first.  Maybe remove this logic later.
			if #s_words < 1 then  -- just a dumb check. one can never be too safe
				--slmod.info('No Words')
				return -1
			end
			
			------------------------------------------------------------------------------------------------------
			--new code (11-16-12): allow a text-type command as first command (good for password entry).
			
			if cmd[1].type == 'text' then
				if cmd[1].varname then -- add to vars table
					vars[cmd[1].varname] = s_original
				end
				--slmod.info('here4')
				return 1, vars
			elseif cmd[1].type == 'word' then
			
			------------------------------------------------------------------------------------------------------
			
				-- first element of cmd must be a word word (or text as above), and required, so we can save a some computation time here
				local cmd_word_ind, exactmatch = word_match(s_words[1], cmd[1])
				if not cmd_word_ind then
					--slmod.info('no cmd_word_ind')
					return -1
				elseif #s_words == 1 and #cmd == 1 then  --match with a single word
					if cmd[1].varname then -- it had a varname, so need to add it to rawvars table
						if type(cmd_word_ind) == 'number' then 
							vars[cmd[1].varname] = cmd[1].text[cmd_word_ind] -- .text was a table of strings
						else
							vars[cmd[1].varname] = cmd[1].text -- .text was a string
						end
						
						
						if exactmatch then --exact match
							--slmod.info('here6')
							return 1, vars
						else --NOT an exact match
							--slmod.info('here7')
							return 0, vars
						end
						
					end
					
					--It wasn't a variable, so no vars table required.			
					--slmod.info('here6')
					if exactmatch then --exact match
						--slmod.info('here8')
						return 1
					else --NOT an exact match
						--slmod.info('here9')
						return 0
					end
				end
				if #cmd == 1 then --s_words had 2 or more words, and cmd had only 1, not a match
					--slmod.info('here10')
					return -1
				end
			else
				--slmod.info('here11')
				return -1 -- first command type not 'word' or 'text'.
			end
		
		end
		local part_match = false -- goes true if anything does not exactly match
		local s_ind = 2
		local cmd_ind = 2
		local rawvars = {}  -- raw vars extracted from the chat command, not yet processed, word vars can skip this step
		--cmd and s_words now have at least 2 elements each.  Start on 2nd element
		--slmod.info('before while')
		while s_ind <= #s_words and cmd_ind <= #cmd do -- definitely needs to be a while, coords commands can cause s_ind to skip ahead by variable amounts
			------------------------- 'word' -----------------------------
			if cmd[cmd_ind].type == 'word' then  --next cmd is a word
               --slmod.info('checking: ' .. s_words[s_ind])
               --slmod.info(slmod.oneLineSerialize(cmd[cmd_ind]))
                local cmd_word_ind, exactmatch = word_match(s_words[s_ind], cmd[cmd_ind])
                if not cmd_word_ind then -- cmd is a word and it doesn't match
                    --slmod.info('no match')
                    if cmd[cmd_ind].required then --no match on required word
                       --slmod.info('required, not matched')
                        return -1
                    else  --not required, it could be the next cmd
                        cmd_ind = cmd_ind + 1 --move on to the next cmd.
                    end
                else  -- next cmd is a word and it DOES match
                    --slmod.info('index')
                    --slmod.info(tostring(exactmatch))
                    if cmd[cmd_ind].varname then  -- need to add to the vars table
                        if type(cmd_word_ind) == 'number' then -- cmd[cmd_ind].text was a table
                            vars[cmd[cmd_ind].varname] = cmd[cmd_ind].text[cmd_word_ind]
                        else
                            vars[cmd[cmd_ind].varname] = cmd[cmd_ind].text
                        end
                    end
                    if not exactmatch then
                        --slmod.info('part match set to true')
                        part_match = true
                    end
                    s_ind = s_ind + 1
                    cmd_ind = cmd_ind + 1  --move onto the next cmd
                end
                
                
                
				
			---------------- 'number' ------------------------------------
			--------------NEEDS TO BE LOGICALLY RE-EXAMINED FOR OPTIONAL WORD FOLLOWING NUMBER--------------------------------------------
			elseif cmd[cmd_ind].type == 'number' then  -- it's a number
				if cmd[cmd_ind].required then 
					rawvars[#rawvars + 1] = {type = 'number', value = s_words[s_ind], validrange = cmd[cmd_ind].validrange, varname = cmd[cmd_ind].varname }  --this better well check out to be a number or 
					s_ind = s_ind + 1
					cmd_ind = cmd_ind + 1  --move onto the next cmd
				else -- a not required number
					-- see if this s_word[s_ind] matches the next cmd word, or this is the end of s_word, else fail
					if #s_words == s_ind then -- the end of s_words
						rawvars[#rawvars + 1] = {type = 'number', value = s_words[s_ind], validrange = cmd[cmd_ind].validrange, varname = cmd[cmd_ind].varname }
						s_ind = s_ind + 1
						cmd_ind = cmd_ind + 1
					elseif #cmd > cmd_ind and (word_match(s_words[s_ind + 1], cmd[cmd_ind + 1])) then -- the next s_word matches the next cmd
						rawvars[#rawvars + 1] = {type = 'number', value = s_words[s_ind], validrange = cmd[cmd_ind].validrange, varname = cmd[cmd_ind].varname }
						s_ind = s_ind + 1
						cmd_ind = cmd_ind + 1
					elseif #cmd > cmd_ind and (word_match(s_words[s_ind], cmd[cmd_ind + 1])) then -- THIS s_word matches the word for next cmd
						cmd_ind = cmd_ind + 1
					else  -- ok, so, this wasn't the last s_word, the next s_word didn't match the next cmd word, and this s_word didn't match the next cmd word 
						--slmod.info('herebreakout number')
						return -1 --ok, is this necessary?
					end	
				end	
			-------------------------------------------------------------------------------------------------------------
			
			
			----------------------------- 'coords' --------------------------------------------
			elseif cmd[cmd_ind].type == 'coords' then  -- it's a coordinate
				if cmd[cmd_ind].required then
				
				--------- NEW LOGIC TO HANDLE OPTIONAL WORD FOLLOWING COORD -------------------------------------------------------------------------------------------------------	
					
					------ if this cmd is going to match, then this s_word must be at least the beginning of coords.  So find the end.  The end is whereever the next word match is, or the end of s_words
					local match_ind
					local cmd_sub_ind = 0
					
					repeat
						cmd_sub_ind = cmd_sub_ind + 1
						match_ind = next_word_match(s_words, s_ind, cmd[cmd_ind + cmd_sub_ind])
					until match_ind > 0 or (cmd_ind + cmd_sub_ind >= #cmd) or cmd[cmd_ind + cmd_sub_ind].required or (cmd[cmd_ind + cmd_sub_ind + 1] and cmd[cmd_ind + cmd_sub_ind + 1].type ~= 'word')
			 --until:  a match is found    the last cmd was reached           the last searched cmd was required    the next command is not a word (the "and" is probably not required, because cmd[cmd_ind + cmd_sub_ind + 1] == nil should be caught by previous condition, but I am just including it to be safe)  

					if match_ind == -1 then -- no match to for a word to the end of s_words - ASSUME everything else is the coord, and catch a mis-match later.
						rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind), varname = cmd[cmd_ind].varname }
						s_ind = #s_words + 1  -- to break out of the loop, basically.              -- ^^ STARTS at s_ind
						cmd_ind = cmd_ind + 1  --go to the next command (shouldn't be one if there will be a match)
					else  -- matches at some later point
						rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind, match_ind - 1), varname = cmd[cmd_ind].varname  }
						s_ind = match_ind  --step s_ind down to the beginning of what should be the next command
						cmd_ind = cmd_ind + cmd_sub_ind  -- step down the line to the next command word.
					end
				--------------------------------------------------------------------------------------------------------------------
				
				
				-----------OLD LOGIC-------------------------------------------------------------------------------------------------
					---- if this cmd is going to match, then this s_word must be at least the beginning of coords.  So find the end.  The end is whereever the next word match is, or the end of s_words
					-- local match_ind = next_word_match(s_words, s_ind, cmd[cmd_ind + 1])
					-- if match_ind == -1 then -- no match to end of s_words
						-- rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind), varname = cmd[cmd_ind].varname }
						-- s_ind = #s_words + 1
						-- cmd_ind = cmd_ind + 1
					-- else
						-- rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind, match_ind - 1), varname = cmd[cmd_ind].varname }
						-- s_ind = match_ind
						-- cmd_ind = cmd_ind + 1
					-- end
				-------------------------------------------------------------------------------------------------------------------
				
				else -- a not required coordinate
					--[[see if:
						0) There is a next cmd
						1) This s_word[s_ind] matches the next cmd word, or 
						2) This if the next cmd word matches anything in the remaining of s_words, or 
						3) No match of the next_cmd (if there is one) to the end of s_words
					]]
					if #cmd > cmd_ind then -- ok, there is a next cmd
					
						-- NEW LOGIC TO HANDLE OPTIONAL WORD FOLLOWING COORD-----------------------------------------------
						--as long as the next cmd is a word and up to the first required word, step through and look for the first word match
						local match_ind
						local cmd_sub_ind = 0
						
						repeat
							cmd_sub_ind = cmd_sub_ind + 1
							match_ind = next_word_match(s_words, s_ind, cmd[cmd_ind + cmd_sub_ind])
							
						until match_ind > 0 or (cmd_ind + cmd_sub_ind >= #cmd) or cmd[cmd_ind + cmd_sub_ind].required or (cmd[cmd_ind + cmd_sub_ind + 1] and cmd[cmd_ind + cmd_sub_ind + 1].type ~= 'word')
			 --until:  a match is found         the last cmd was reached           the last searched cmd was required    the next command is not a word (the "and" is probably not required, because cmd[cmd_ind + cmd_sub_ind + 1] == nil should be caught by previous condition, but I am just including it to be safe)  
			 
						if match_ind == s_ind then -- THIS s_word matches the word for a later next cmd @ cmd + cmd_sub_ind, so this optional coordinate was skipped.
							cmd_ind = cmd_ind + cmd_sub_ind
							-- s = s_ind + 1 -- DO NOT STEP TO THE NEXT WORD- the next s_word should be analyzed properly by the word analyzing part of this loop.
						elseif match_ind == -1 then -- no match to for a word to the end of s_words - ASSUME everything else is the coord, and catch a mis-match later.
							rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind), varname = cmd[cmd_ind].varname }
							s_ind = #s_words + 1  -- to break out of the loop, basically.               -- ^^ STARTS at s_ind
							cmd_ind = cmd_ind + 1  --go to the next command (shouldn't be one if there will be a match)
						else  -- matches at some later point
							rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind, match_ind - 1), varname = cmd[cmd_ind].varname  }
							s_ind = match_ind  --step s_ind down to the beginning of what should be the next command
							cmd_ind = cmd_ind + cmd_sub_ind  -- step down the line to where the next cmd word matched
						end
						-----------------------------------------------------------------------------------
						
						
						---OLD LOGIC-----------------------------------------------------------------------------------------
						-- local match_ind = next_word_match(s_words, s_ind, cmd[cmd_ind + 1])  --re-examine this logic later... right now, the case of optional word after coordinate is not handled properly, because only the next command is checked for a word match, and if hte next command is optional, and omitted in the chat, the code doesn't look ahead.
		
						-- if match_ind == s_ind then -- THIS s_word matches the word for next cmd
							-- cmd_ind = cmd_ind + 1
						-- elseif match_ind == -1 then -- no match to end of s_words
							-- rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind), varname = cmd[cmd_ind].varname }
							-- s_ind = #s_words + 1
							-- cmd_ind = cmd_ind + 1
						-- else  -- matches at some later point
							-- rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind, match_ind - 1), varname = cmd[cmd_ind].varname  }
							-- s_ind = match_ind
							-- cmd_ind = cmd_ind + 1
						-- end
						-----------------------------------------------------------------------------------------------------
					else  -- this is the last cmd word, so the remaining s_words must be part of the coordinate
						rawvars[#rawvars + 1] = {type = 'coords', value = table.concat(s_words, ' ', s_ind), varname = cmd[cmd_ind].varname }
						s_ind = #s_words + 1			
						cmd_ind = cmd_ind + 1
					end
				end
				
			----------------------------------------------------------------------------------------
			-- text command
			elseif cmd[cmd_ind].type == 'text' and (cmd_ind == #cmd) then  --next cmd is raw text entry, and the last command- text can only be last variable
				--slmod.info('into the text type command')
				local s_original_lower = s_original:lower()
				local pstart, pend = s_original_lower:find(s_words[s_ind - 1])  -- should find the index of the previous s_word within the original s
				if cmd[cmd_ind].varname then -- add to vars table
					vars[cmd[cmd_ind].varname] = s_original:sub(pend + 2, s_original:len())-- THIS FUCKER RIGHT HERE IS THE PROBLEM!
					
					
					--slmod.info('adding ' .. s_original:sub(pend + 2, s_original:len()) .. ' to vars')
				end
				cmd_ind = cmd_ind + 1  -- should break out of loop, there can only be one text cmd and it must be the last one.

			-----------------------------------------------------------------------------------------	
			elseif cmd[cmd_ind].type == 'var' then
               --slmod.info('directPass')
                vars[cmd[cmd_ind].varname] = s_words[s_ind]
                
                s_ind = s_ind + 1
                cmd_ind = cmd_ind + 1
            else -- not number, text, coords, or text, never ever should happen.
				--slmod.info('here14')
				return -1
			end
		end
		--[[ OK, if we're still here, then rawvars contains any variables extracted from the chat message in raw form (hopefully)...  
		if: 
		there are required commands left unfulfilled, or
		there are leftover elements of s_words
		or the variables in rawvars fail to convert, then:
		still fail, and return -1
		else, 
		return true, and any variables
		]]
		if cmd_ind <= #cmd then -- look for any remaining required cmds
			for i = cmd_ind, #cmd do
				if cmd[i].required == true then
					--slmod.info('here15')
					return -1 -- there was a required cmd that wasn't used, return -1
				end
				
			end
		end
		
		if s_ind ~= #s_words + 1 and cmd[#cmd].type ~= 'text' then -- should be this value to have ended while loop?
			--slmod.info('here16')
			return -1 -- s_words not properly accounted for in cmd.
		end
		
		if #rawvars == 0 then -- no rawvars, go ahead and return
			--slmod.info('here13')
			if not part_match then
				--slmod.info('here17')
				return 1, vars
			else
				--slmod.info('here18')
				return 0, vars
			end
		else -- there are some variables that need convertin
			for i = 1, #rawvars do
				if rawvars[i].type == 'coords' then
				
					local err_code, coords_msg, coords = getCoords(rawvars[i].value)
					--slmod.info(rawvars[i].value)
					--slmod.info(str_msg)
					if err_code == 1 and type(coords) == 'table' then -- looks like it was successful
						vars[rawvars[i].varname] = coords
						vars['coords_msgs'] = vars['coords_msgs'] or {}
						table.insert(vars['coords_msgs'], coords_msg)  -- allows coordinate messages to be returned
					else
						--slmod.info('here19')
						return -1
					end
				elseif rawvars[i].type == 'number' then
					local num = tonumber(rawvars[i].value) -- attempt to do tonumber
					if type(num) == 'number' then --success
						if rawvars[i].validrange and num >= rawvars[i].validrange[1] and  num <= rawvars[i].validrange[2] then --make sure it's in valid range
							vars[rawvars[i].varname] = num
						elseif not rawvars[i].validrange then -- no validrange specified
							vars[rawvars[i].varname] = num
						else
						--slmod.info('here20')
							return -1 -- not within validrange
						end
					else
						--slmod.info('here21')
						return -1  --failed tonumber conversion
					
					end
					
				else
					--slmod.info('here22')
					return -1 --should never get here
				end	
			end
		end
		--if still here, there there are variables that need to be returned.
		--slmod.info('hereend')
		if not part_match then
			--slmod.info('here23')
			return 1, vars
		else
			--slmod.info('here24')
			return 0, vars
		end
		
	end -- end of cmdMatch
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	
	-- slmod.doMenuCommands
	-- Global function that checks if chat message is a valid menu command, and if so, does any onSelect/showing that is required.
	function slmod.doMenuCommands(client_id, chat_msg)
		--slmod.info(chat_msg)
        local MenuShowTbl = {}
		local ItemShowTbl = {}
		for MenuName, Menu in pairs(menus) do
            ----slmod.info(Menu.items[1].description)
            if Menu.active then
				if slmod.clientInScope(client_id, Menu.scope) then -- make sure that the client actually said something in scope for this menu
					--slmod.info('inScope')

					for ind, val in pairs(Menu.showCmds) do  --look for menu show commands
						local matchtype = (cmdMatch(val, chat_msg))
                        if matchtype == 1 then  --exact match, do this now
							Menu:show(client_id)
							return Menu.options.privacy.access  -- return whether or not this chat message should be shown
						elseif matchtype == 0 then
							table.insert(MenuShowTbl, { Menu = Menu, client_id = client_id})
						end
						-- if cmdMatch(val, chat_msg) then
							-- Menu:show(client_id)
							-- return Menu.options.privacy.access  -- return whether or not this chat message should be shown
						-- end
					end
					
					for item_name, item in pairs(Menu.items) do  -- look for item selects
						if item.selCmds and item.onSelect and item.active then
							--slmod.info(item.description)
                            for ind, cmd in pairs(item.selCmds) do
                                local matchtype, vars = cmdMatch(cmd, chat_msg)
								--slmod.info('matchType: ' .. matchtype)
                                if matchtype == 1 then  -- exact match, do immediately
									--slmod.info('exact')
                                    if vars then
										item:onSelect(vars, client_id)
									else
										item:onSelect(client_id)
									end
									return item.options.privacy.access  -- return whether or not this chat message should be shown
								elseif matchtype == 0 then
									--slmod.info('add To tbl')
                                    table.insert(ItemShowTbl, { item = item, client_id = client_id, vars = vars})
								end
								
								-- if match then
									-- if vars then
										-- item:onSelect(vars, client_id)
									-- else
										-- item:onSelect(client_id)
									-- end
									-- return item.options.privacy.access  -- return whether or not this chat message should be shown
								-- end
							end
						end
					end
				end
			end
		end
		--if still here, check to see if there were any partial matches
		if #MenuShowTbl > 0  then -- this doesn't really have to be a table.
			MenuShowTbl[1].Menu:show(MenuShowTbl[1].client_id)
			return MenuShowTbl[1].Menu.options.privacy.access  -- return whether or not this chat message should be shown
		end
		if #ItemShowTbl > 0 then
           --slmod.info('onSelectItems')
			if ItemShowTbl[1].vars then
				ItemShowTbl[1].item:onSelect(ItemShowTbl[1].vars, ItemShowTbl[1].client_id)
			else
				ItemShowTbl[1].item:onSelect(ItemShowTbl[1].client_id)
			end
			return ItemShowTbl[1].item.options.privacy.access  -- return whether or not this chat message should be shown
		end
	end
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
end

slmod.info('SlmodMenu.lua loaded.')