------------------------------------------------------------------------------------
-- Coordinate converter menu
function slmod.create_ConvMenu()
	local on_Select_ConvMenu_item1 = function(self, vars, client_id)
		if self and client_id and vars and type(vars.coords) == 'table' and vars.toCoords then -- do a quick check to make sure there is minimum info.
			local coord_string
			
			if vars.coords.type == 'MGRS' and vars.coords.UTMZone and vars.coords.MGRSDigraph and vars.coords.Easting and vars.coords.Northing then
				local MGRS = { UTMZone = vars.coords.UTMZone, MGRSDigraph = vars.coords.MGRSDigraph, Easting = vars.coords.Easting, Northing = vars.coords.Northing }  
				
				if vars.toCoords == 'll' or vars.toCoords == 'la' then --MGRS to LL
					local coords = slmod.coord.MGRStoLL(MGRS)
					coord_string = vars.coords_msgs[1] .. ', CONVERTED TO: ' .. slmod.coord.tostring({type = 'LL', lat = coords.lat, lon = coords.lon})
				
				elseif vars.toCoords == 'bul' then --MGRS to bullseye
					local client_coa = slmod.getClientSide(client_id)
					if client_coa == 'red' then
						client_coa = 1
					elseif client_coa == 'blue' then
						client_coa = 2
					else
						return --can't do bullseye if spectators.
					end
					local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.MGRStoBR(' .. slmod.oneLineSerialize(MGRS) .. ', coalition.getMainRefPoint(' .. tostring(client_coa) .. ')))')
					if ret_err and type(ret_str) == 'string' then -- successful
						local coords = slmod.deserializeValue('coords = ' .. ret_str)
						if type(coords) == 'table' then
							coord_string = vars.coords_msgs[1] .. ', CONVERTED TO: Bullseye ' .. slmod.coord.tostring({type = 'BR', az = coords.az, dist = coords.dist})
						else
							return
						end
					else
						return -- net.dotring_in failed
					end
					
				elseif vars.toCoords == 'br' then -- MGRS to BR
					local rtid = slmod.getClientRtId(client_id)
					if rtid then 
						rtid = tonumber(rtid) -- just gotta be careful
					else
						return
					end
					if rtid == 0 then
						return --can't do BR if no valid rtid
					end
					local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.MGRStoBR(' .. slmod.oneLineSerialize(MGRS) .. ', Unit.getPosition({ id_ = ' .. tostring(rtid) .. ' }).p))')
					if ret_err and type(ret_str) == 'string' then -- successful
						local coords = slmod.deserializeValue('coords = ' .. ret_str)
						if type(coords) == 'table' then
							coord_string = vars.coords_msgs[1] .. ', CONVERTED TO: BR ' .. slmod.coord.tostring({type = 'BR', az = coords.az, dist = coords.dist})
						else
							return
						end
					else
						return -- net.dotring_in failed
					end
					
				elseif vars.toCoords == 'mg' then -- MGRS to MGRS
					coord_string = 'MGRS to MGRS? What is the point of that?'
				else --wtf
					return
				end
				
				
			elseif vars.coords.type == 'LL' and vars.coords.lat and vars.coords.lon then
				local LL = { lat = vars.coords.lat, lon = vars.coords.lon }  
				
				if vars.toCoords == 'mg' then -- LL to MGRS
					--net.log('trying to do LL to MGRS')
					local coords = slmod.coord.LLtoMGRS(LL)
					coord_string = vars.coords_msgs[1] .. ', CONVERTED TO: ' .. slmod.coord.tostring({type = 'MGRS', UTMZone = coords.UTMZone, MGRSDigraph = coords.MGRSDigraph, Easting = coords.Easting, Northing = coords.Northing})
				
				elseif vars.toCoords == 'bul' then -- LL to bullseye
					local client_coa = slmod.getClientSide(client_id)
					if client_coa == 'red' then
						client_coa = 1
					elseif client_coa == 'blue' then
						client_coa = 2
					else
						return --can't do bullseye if spectators.
					end
					local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.LLtoBR(' .. slmod.oneLineSerialize(LL) .. ', coalition.getMainRefPoint(' .. tostring(client_coa) .. ')))')
					if ret_err and type(ret_str) == 'string' then -- successful
						local coords = slmod.deserializeValue('coords = ' .. ret_str)
						if type(coords) == 'table' then
							coord_string = vars.coords_msgs[1] .. ', CONVERTED TO: Bullseye ' .. slmod.coord.tostring({type = 'BR', az = coords.az, dist = coords.dist})
						else
							return
						end
					else
						return -- net.dotring_in failed
					end
				
				elseif vars.toCoords == 'br' then -- LL to BR
					local rtid = slmod.getClientRtId(client_id)
					if rtid then 
						rtid = tonumber(rtid) -- just gotta be careful
					else
						return
					end
					if rtid == 0 then
						return --can't do BR if no valid rtid
					end
					local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.LLtoBR(' .. slmod.oneLineSerialize(LL) .. ', Unit.getPosition({ id_ = ' .. tostring(rtid) .. ' }).p))')
					if ret_err and type(ret_str) == 'string' then -- successful
						local coords = slmod.deserializeValue('coords = ' .. ret_str)
						if type(coords) == 'table' then
							coord_string = vars.coords_msgs[1] .. ', CONVERTED TO: BR ' .. slmod.coord.tostring({type = 'BR', az = coords.az, dist = coords.dist})
						else
							return
						end
					else
						return -- net.dotring_in failed
					end
				
				elseif vars.toCoords == 'll' or vars.toCoords == 'la' then -- LL to LL
					coord_string = 'LL to LL? What is the point of that?'
				else --wtf
					return
				end
			
			elseif vars.coords.type == 'BR' then
				local BR = { az = vars.coords.az, dist = vars.coords.dist }  
				
				if vars.br_type and vars.br_type == 'br' then  --must have a br_type to distinguish bulls from br
					
					if vars.toCoords == 'mg' then -- BR to MGRS
						local rtid = slmod.getClientRtId(client_id)
						if rtid then 
							rtid = tonumber(rtid) -- just gotta be careful
						else
							return
						end
						if rtid == 0 then
							return --can't do BR if no valid rtid
						end
						local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoMGRS(' .. slmod.oneLineSerialize(BR) .. ', Unit.getPosition({ id_ = ' .. tostring(rtid) .. ' }).p))')
						if ret_err and type(ret_str) == 'string' then -- successful
							local coords = slmod.deserializeValue('coords = ' .. ret_str)
							if type(coords) == 'table' then
								coord_string = 'BR: ' .. vars.coords_msgs[1] .. ', CONVERTED TO: ' .. slmod.coord.tostring({type = 'MGRS', UTMZone = coords.UTMZone, MGRSDigraph = coords.MGRSDigraph, Easting = coords.Easting, Northing = coords.Northing})
							else
								return
							end
						else
							return -- net.dotring_in failed
						end
					
					elseif vars.toCoords == 'll' or vars.toCoords == 'la' then -- BR to LL
						local rtid = slmod.getClientRtId(client_id)
						if rtid then 
							rtid = tonumber(rtid) -- just gotta be careful
						else
							return
						end
						if rtid == 0 then
							return --can't do BR if no valid rtid
						end
						local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoLL(' .. slmod.oneLineSerialize(BR) .. ', Unit.getPosition({ id_ = ' .. tostring(rtid) .. ' }).p))')
						if ret_err and type(ret_str) == 'string' then -- successful
							local coords = slmod.deserializeValue('coords = ' .. ret_str)
							if type(coords) == 'table' then
								coord_string = 'BR: ' .. vars.coords_msgs[1] .. ', CONVERTED TO: ' .. slmod.coord.tostring({type = 'LL', lat = coords.lat, lon = coords.lon})
							else
								return
							end
						else
							return -- net.dotring_in failed
						end
					
					elseif vars.toCoords == 'bul' then -- BR to bullseye
						local rtid = slmod.getClientRtId(client_id)
						if rtid then 
							rtid = tonumber(rtid) -- just gotta be careful
						else
							return
						end
						if rtid == 0 then
							return --can't do BR if no valid rtid
						end
						
						local client_coa = slmod.getClientSide(client_id)
						if client_coa == 'red' then
							client_coa = 1
						elseif client_coa == 'blue' then
							client_coa = 2
						else
							return --can't do bullseye if spectators.
						end
						
						local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoBR(' .. slmod.oneLineSerialize(BR) .. ', Unit.getPosition({ id_ = ' .. tostring(rtid) .. ' }).p, coalition.getMainRefPoint(' .. tostring(client_coa) .. ')))')
						if ret_err and type(ret_str) == 'string' then -- successful
							local coords = slmod.deserializeValue('coords = ' .. ret_str)
							if type(coords) == 'table' then	
								coord_string = 'BR: ' .. vars.coords_msgs[1] .. ', CONVERTED TO: Bullseye ' .. slmod.coord.tostring({type = 'BR', az = coords.az, dist = coords.dist})
							else
								return
							end
						else
							return -- net.dotring_in failed
						end
			
					elseif vars.toCoords == 'br' then -- BR to BR
						coord_string = 'BR to BR? What is the point of that?'

					else --wtf
						
						return
					
					end
				elseif vars.br_type and vars.br_type == 'bul' then
					local BR = { az = vars.coords.az, dist = vars.coords.dist }  
					
					if vars.toCoords == 'mg' then -- Bullseye to MGRS
						local client_coa = slmod.getClientSide(client_id)
						if client_coa == 'red' then
							client_coa = 1
						elseif client_coa == 'blue' then
							client_coa = 2
						else
							return --can't do bullseye if spectators.
						end
						local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoMGRS(' .. slmod.oneLineSerialize(BR) .. ', coalition.getMainRefPoint(' .. tostring(client_coa) .. ')))')
						if ret_err and type(ret_str) == 'string' then -- successful
							local coords = slmod.deserializeValue('coords = ' .. ret_str)
							if type(coords) == 'table' then
								coord_string = 'Bullseye: ' .. vars.coords_msgs[1] .. ', CONVERTED TO: ' ..  slmod.coord.tostring({type = 'MGRS', UTMZone = coords.UTMZone, MGRSDigraph = coords.MGRSDigraph, Easting = coords.Easting, Northing = coords.Northing})
							else
								return
							end
						else
							return -- net.dotring_in failed
						end
			
					elseif vars.toCoords == 'll' or vars.toCoords == 'la' then -- Bullseye to LL
						local client_coa = slmod.getClientSide(client_id)
						if client_coa == 'red' then
							client_coa = 1
						elseif client_coa == 'blue' then
							client_coa = 2
						else
							return --can't do bullseye if spectators.
						end
						local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoLL(' .. slmod.oneLineSerialize(BR) .. ', coalition.getMainRefPoint(' .. tostring(client_coa) .. ')))')
						if ret_err and type(ret_str) == 'string' then -- successful
							local coords = slmod.deserializeValue('coords = ' .. ret_str)
							if type(coords) == 'table' then
								coord_string = 'Bullseye: ' .. vars.coords_msgs[1] .. ', CONVERTED TO: ' .. slmod.coord.tostring({type = 'LL', lat = coords.lat, lon = coords.lon})
							else
								return
							end
						else
							return -- net.dotring_in failed
						end
			
					elseif vars.toCoords == 'br' then -- Bullseye to BR
						local rtid = slmod.getClientRtId(client_id)
						if rtid then 
							rtid = tonumber(rtid) -- just gotta be careful
						else
							return
						end
						if rtid == 0 then
							return --can't do BR if no valid rtid
						end
						
						local client_coa = slmod.getClientSide(client_id)
						if client_coa == 'red' then
							client_coa = 1
						elseif client_coa == 'blue' then
							client_coa = 2
						else
							return --can't do bullseye if spectators.
						end
						
						local ret_str, ret_err = net.dostring_in('server', 'return slmod.oneLineSerialize(slmod.coord.BRtoBR(' .. slmod.oneLineSerialize(BR) .. ', coalition.getMainRefPoint(' .. tostring(client_coa) .. '), Unit.getPosition({ id_ = ' .. tostring(rtid) .. ' }).p))')
						if ret_err and type(ret_str) == 'string' then -- successful
							local coords = slmod.deserializeValue('coords = ' .. ret_str)
							if type(coords) == 'table' then
								coord_string = 'Bullseye: ' .. vars.coords_msgs[1] .. ', CONVERTED TO: BR ' .. slmod.coord.tostring({type = 'BR', az = coords.az, dist = coords.dist})
							else
								return
							end
						else
							return -- net.dotring_in failed
						end
					
					elseif vars.toCoords == 'bul' then -- Bulls to Bulls
						coord_string = 'Bullseye to Bullseye? What is the point of that?'
			
					else --wtf
						return
					end
				else  -- br_type invalid
					return
				end
			else --not recognized coord
				return 
			end	
			if type(coord_string) == 'string' then
				local show_scope = {}
				if self.options.privacy.show then --show it only to selector - in this case, this will always be true.
					show_scope["clients"] = {client_id}
				else
					show_scope["coa"] = slmod.getClientSide(client_id)  --it would be better to set this to the MENU'S scope.
				end
				slmod.scheduleFunctionByRt(slmod.scopeMsg, {coord_string, self.options.display_time or 5, self.options.display_mode or 'chat', show_scope}, DCS.getRealTime() + 0.1)
			end
		end
	end
	
	
	local ConvMenuShowCmds = {
		[1] = {
			[1] = {  
				type = 'word',
				text = '-scm',
				required = true
			}
		},
		[2] = {  
			[1] = {
				type = 'word',
				text = '-conv',
				required = true
			},
			[2] = {
				type = 'word',
				text = 'menu',
				required = false
			}
		}
	}
	
	-- Create the items
	local item1vars = {}
	item1vars.description = 'Say in chat "-conv <coordinate> to <desired coordinate system>".\nAccepted coordinate systems are LL, MGRS, BR (bearing and range from your aircraft), and BULLS (bearing and range from bullseye).\nNot case sensitive. See the extended help (option 2 on this menu) for more info and examples.'
	item1vars.active = true
	item1vars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
	item1vars.selCmds = {
			[1] = {
				[1] = { 
					type = 'word', 
					text = '-conv',
					required = true
				}, 
				[2] = { 
					type = 'word',
					text = {'bul', 'br', 'll', 'la', 'mg'}, -- ll, la, mg, etc- can be used, but do nothing.
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
					text = {'bul', 'br', 'mg', 'll', 'la'},
					varname = 'toCoords',
					required = true,
				}
			}
		} 
	item1vars.onSelect = on_Select_ConvMenu_item1
	
	local ConvMenuItems = {}
	ConvMenuItems[1] = SlmodMenuItem.create(item1vars)
	
	-- Item 2: extended help.
	local item2vars = {}
	local on_Select_ConvMenu_item2 = function(self, vars, client_id)
		if not client_id then
			client_id = vars
		end
		--net.log('got into trying to do the help text')
		local helptext = "This is the format of a coordinate conversion request:\n\n(Required): \"-conv\" + (Optional for LL and MGRS / Requred for BR or BULLS): \"ll\" or \"mg\" or \"br\" or \"bul\"\n + (Required): <Coordinates> + (Optional): \"to\" + (Required): \"ll\" or \"mg\" or \"br\" or \"bul\"\n\n-Only the first letters of each word must match, and case (capitalization) does not matter.\n-Lat/long coordinates can be in degrees, degrees minutes, or even degrees minutes seconds.\n-MGRS coordinates must at least have a space between the UTM zone and MGRS digraph, and an even number of digits.\n-Bearing and range coordinates MUST be prefaced with either \"br\" or \"bul\" to signify whether it's bearing and range from your aircraft, or from the bullseye.\nSome examples are:\n\n\"-conv bulls 170 for 35 to LL\"\n\"-conv 42 34N 44 15E mgrs\"\n\"-conv 38T KM 492 009 to bulls\"\n\"-CONV 42 14.914'N 040 37.379'E to MGRS\"\n\"-Convert Br 055 For 90 To BULLSEYE\"\n\"-conv LL N 43 13 39 E 038 55 31 MG\"\n\"-CoNvt 38t km775334 to ll\"\n\"-CoNvZZZ bUlpsyeedgsdee 295 FoR 62 MgSSAkksL\" (Illustrates how it's only necessary to match the first few letters- the entire word \"for\" has to be spelled correctly though)"
		local show_scope = {}
		if self.options.privacy.show then --show it only to selector - in this case, this will always be true.
			show_scope["clients"] = {client_id}
		else
			show_scope["coa"] = slmod.getClientSide(client_id)  --it would be better to set this to the MENU'S scope.
		end
		--net.log('trying to do this helptext')
		slmod.scheduleFunctionByRt(slmod.scopeMsg, {helptext, self.options.display_time or 60, self.options.display_mode or 'text', show_scope}, DCS.getRealTime() + 0.1)
	end
	
	item2vars.description = 'Say in chat "-conv help" to see extended help text on the coordinate converter (*CAUTION* Will be sent to you as trigger text- but only you will see it).'
	item2vars.active = true
	item2vars.options = {display_mode = 'text', display_time = 60, privacy = {access = true, show = true}}
	item2vars.selCmds = {
		[1] = {
			[1] = { 
				type = 'word', 
				text = '-conv',
				required = true
			}, 
			[2] = { 
				type = 'word',
				text = 'help',
				required = true
			}
		}
	} 
	item2vars.onSelect = on_Select_ConvMenu_item2

	
	ConvMenuItems[2] = SlmodMenuItem.create(item2vars)

	
	slmod.ConvMenu = SlmodMenu.create({ showCmds = ConvMenuShowCmds, scope = {coa = 'all'}, options = { display_time = 1, display_mode = 'chat', title = 'Slmod Coordinate Conversion Utility', privacy = { access = true, show = true}}, items = ConvMenuItems})
end

slmod.info('SlmodConvMenu.lua loaded.')