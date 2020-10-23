function slmod.create_getMissionUnitData()  --creates function to get all the mission units in a mission
	local v7MissionUnitData_string = [==[slmod = slmod or {}
function slmod.getMissionUnitData()   --new import mission data function for Slmodv6.
	
	local miz_units_tbl = {}
	miz_units_tbl[#miz_units_tbl + 1] = '{\n'
	
	for coa_name, coa_data in pairs(mission.coalition) do
	
		if coa_name == 'red' or coa_name == 'blue' and type(coa_data) == 'table' then
			miz_units_tbl[#miz_units_tbl + 1] = '	[' --one tab inside mission
			miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(coa_name)
			miz_units_tbl[#miz_units_tbl + 1] = '] = {\n' --starting a new coaltion
			
			if coa_data.country then --there is a country table
				for cntry_id, cntry_data in pairs(coa_data.country) do
					
					miz_units_tbl[#miz_units_tbl + 1] = '		[' --two tabs inside a coalition
					miz_units_tbl[#miz_units_tbl + 1] = string.lower(slmod.basicSerialize(cntry_data.name))
					miz_units_tbl[#miz_units_tbl + 1] = '] = {\n' --starting a new country
					
					miz_units_tbl[#miz_units_tbl + 1] = '			["country_id_num"] = ' --three tabs inside a coutnry
					miz_units_tbl[#miz_units_tbl + 1] = tostring(cntry_id)
					miz_units_tbl[#miz_units_tbl + 1] = ',\n'
					
					if type(cntry_data) == 'table' then  --just making sure
					
						for obj_type_name, obj_type_data in pairs(cntry_data) do
						
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" or obj_type_name == "static" then --should be an unncessary check  -- re-allowing statics 
								
								local category = obj_type_name
								
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then  --there's a group!
									
									miz_units_tbl[#miz_units_tbl + 1] = '			[' --three tabs inside a coutnry
									miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(obj_type_name)
									miz_units_tbl[#miz_units_tbl + 1] = '] = {\n' --new table for these groups
									
									for group_num, group_data in pairs(obj_type_data.group) do
										
										if group_data and group_data.units and type(group_data.units) == 'table' then  --making sure again- this is a valid group
												
											miz_units_tbl[#miz_units_tbl + 1] = '				[' --four tabs inside a unit type
											miz_units_tbl[#miz_units_tbl + 1] = tostring(group_num)
											miz_units_tbl[#miz_units_tbl + 1] = '] = {\n' --new table for this group
											
											miz_units_tbl[#miz_units_tbl + 1] = '					["name"] = ' --five tabs inside a group
											miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(group_data.name)
											
											
											miz_units_tbl[#miz_units_tbl + 1] = ',\n'
											
											miz_units_tbl[#miz_units_tbl + 1] = '					["groupId"] = ' --five tabs inside a group
											miz_units_tbl[#miz_units_tbl + 1] = tostring(group_data.groupId)
											miz_units_tbl[#miz_units_tbl + 1] = ',\n'
											miz_units_tbl[#miz_units_tbl + 1] = '					["units"] = {\n' --five tabs inside a group
											
											for unit_num, unit_data in pairs(group_data.units) do
												miz_units_tbl[#miz_units_tbl + 1] = '						['  --six tabs inside a units table
												miz_units_tbl[#miz_units_tbl + 1] = tostring(unit_num)
												miz_units_tbl[#miz_units_tbl + 1] = '] = { name = '
												miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(unit_data.name)
												miz_units_tbl[#miz_units_tbl + 1] = ', type = '
												miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(unit_data.type)
												miz_units_tbl[#miz_units_tbl + 1] = ', skill = '
												miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(unit_data.skill)
												miz_units_tbl[#miz_units_tbl + 1] = ', unitId = '
												miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(unit_data.unitId)
												miz_units_tbl[#miz_units_tbl + 1] = ', category = '
												miz_units_tbl[#miz_units_tbl + 1] = slmod.basicSerialize(category)
												miz_units_tbl[#miz_units_tbl + 1] = ' },\n'
									
											end --for unit_num, unit_data in pairs(group_data.units) do
											miz_units_tbl[#miz_units_tbl + 1] = '					},\n' --five tabs inside a group
											miz_units_tbl[#miz_units_tbl + 1] = '				},\n' --four tabs inside a unit type
										
										end --if group_data and group_data.units then
							
									end --for group_num, group_data in pairs(obj_type_data.group) do
										
									miz_units_tbl[#miz_units_tbl + 1] = '			},\n' --close the type name
								
								end --if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then
							
							end --if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" or obj_type_name == "static" then
							
						end --for obj_type_name, obj_type_data in pairs(cntry_data) do
						
					end --if type(cntry_data) == 'table' then
					
					miz_units_tbl[#miz_units_tbl + 1] = '		},\n' -- close the country
					
				end --for cntry_id, cntry_data in pairs(coa_data.country) do
				
			end --if coa_data.country then --there is a country table
		
			miz_units_tbl[#miz_units_tbl + 1] = '	},\n' --close the coalition
		end --if coa_name == 'red' or coa_name == 'blue' and type(coa_data) == 'table' then
			
	end --for coa_name, coa_data in pairs(mission.coalition) do
	
	miz_units_tbl[#miz_units_tbl + 1] = '}' --close the mission table
	
	local miz_units_str = table.concat(miz_units_tbl)
	
	return miz_units_str
	
end]==]
    --local str, err = net.dostring_in('server', v7MissionUnitData_string)
	local str, err = net.dostring_in('mission', v7MissionUnitData_string)
	if not err then
		slmod.error('failed to load slmod.getMissionUnitData into mission environment, reason: ' .. tostring(str))
	end
end

--function slmod.create_getMissionUnitData2()


--end

--Import all the mission units to a global table 
function slmod.makeMissionUnitData()
	local mission_units_str, call_err = net.dostring_in('mission', 'return slmod.getMissionUnitData()')
	if call_err == true then
		dostring('slmod.missionUnitData = ' .. mission_units_str)
		
		slmod.activeUnitsBase = {}  -- the base table used for creating slmod.activeUnits.
		slmod.allMissionUnitsByName = {}  -- just a listing of all missionUnitData by name.
		slmod.allMissionUnitsById = {}
		local lUnitsBase = slmod.activeUnitsBase -- just a local reference, easier to write.
		

		--Now, copy data from missionUnitData into the activeUnitsBase
		for coaName, coa in pairs(slmod.missionUnitData) do
			for countryName, country in pairs(coa) do
				for unitType, groups in pairs(country) do
					if type(groups) == 'table' then 
						for groupInd, group in pairs(groups) do
							if group.units[1] then
								local ref = slmod.missionUnitData[coaName][countryName][unitType][groupInd]
								ref.name =  DCS.getUnitProperty(group.units[1].unitId, 7)
								for unitInd, unit in pairs(group.units) do
									ref.units[unitInd].name = DCS.getUnitProperty(unit.unitId, 3)
									ref.units[unitInd].group = ref.name
								end
							end
							
							if type(group) == 'table' then -- index 4 to end
								for unitInd, unit in pairs(group.units) do
									local newUnit = {}
									newUnit['coalition'] = coaName
									newUnit['name'] = DCS.getUnitProperty(unit.unitId, 3)
									newUnit['unitId'] = unit.unitId
									newUnit['mpname'] = unit.name --at least, for now.
									newUnit['objtype'] = unit.type
									newUnit['group'] = DCS.getUnitProperty(unit.unitId, 7)
									newUnit['groupId'] = group.groupId
									newUnit['category'] = unit.category
									newUnit['skill'] = unit.skill
									newUnit['countryName'] = countryName
									newUnit['countryId'] = country.country_id_num
									slmod.allMissionUnitsByName[newUnit.name] = newUnit
                                    slmod.allMissionUnitsById[newUnit.unitId] = newUnit
									if unitType ~= 'static' then
										lUnitsBase[#lUnitsBase + 1] = newUnit -- create new entry in the activeUnits base
									end
								end
							end
						end
					end
				end
			end
		end
		
		--slmod.info(slmod.tableshow(slmod.activeUnitsBase))
		--slmod.info(slmod.tableshow(slmod.allMissionUnitsByName))
		local s = table.concat({'slmod = slmod or {}\n', 'slmod.allMissionUnitsById = ', slmod.oneLineSerialize(slmod.allMissionUnitsById)})
        
        local str, err = net.dostring_in('server', s)
        if not err then
            slmod.error('failed to create table slmod.allMissionUnitsById in server environment, reason: ' .. str)
        end
		slmod.info('successfully completed slmod.getMissionUnitData()')
		-- local miz_units_file = io.open(lfs.writedir() .. [[Logs\]] .. 'v6_mission_units.txt', 'w')
		-- miz_units_file:write(slmod.serialize('slmod.missionUnitData', slmod.missionUnitData))
		-- miz_units_file:close()
		--net.log(mission_units[50].name)

		
	else
		slmod.error('error in slmod.getMissionUnitData(): ' .. tostring(mission_units_str))
	end
end

function slmod.makeUnitTable(tbl) -- uses slmod.missionUnitData for creating a table of units for Slmod function
--[[
Prefixes:
"[-u]<unit name>" - subtract this unit if its in the table
"[g]<group name>" - add this group to the table
"[-g]<group name>" - subtract this group from the table
"[c]<country name>"  - add this country's units
"[-c]<country name>" - subtract this country's units if any are in the table

Stand-alone identifiers
"[all]" - add all units
"[-all]" - subtract all units (not very useful by itself)
"[blue]" - add all blue units
"[-blue]" - subtract all blue units
"[red]" - add all red coalition units
"[-red]" - subtract all red units

Compound Identifiers:
"[c][helicopter]<country name>"  - add all of this country's helicopters
"[-c][helicopter]<country name>" - subtract all of this country's helicopters
"[c][plane]<country name>"  - add all of this country's planes
"[-c][plane]<country name>" - subtract all of this country's planes
"[c][ship]<country name>"  - add all of this country's ships
"[-c][ship]<country name>" - subtract all of this country's ships
"[c][vehicle]<country name>"  - add all of this country's vehicles
"[-c][vehicle]<country name>" - subtract all of this country's vehicles

"[all][helicopter]" -  add all helicopters
"[-all][helicopter]" - subtract all helicopters
"[all][plane]" - add all  planes
"[-all][plane]" - subtract all planes
"[all][ship]" - add all ships
"[-all][ship]" - subtract all ships
"[all][vehicle]" - add all vehicles
"[-all][vehicle]" - subtract all vehicles

"[blue][helicopter]" -  add all blue coalition helicopters
"[-blue][helicopter]" - subtract all blue coalition helicopters
"[blue][plane]" - add all blue coalition planes
"[-blue][plane]" - subtract all blue coalition planes
"[blue][ship]" - add all blue coalition ships
"[-blue][ship]" - subtract all blue coalition ships
"[blue][vehicle]" - add all blue coalition vehicles
"[-blue][vehicle]" - subtract all blue coalition vehicles

"[red][helicopter]" -  add all red coalition helicopters
"[-red][helicopter]" - subtract all red coalition helicopters
"[red][plane]" - add all red coalition planes
"[-red][plane]" - subtract all red coalition planes
"[red][ship]" - add all red coalition ships
"[-red][ship]" - subtract all red coalition ships
"[red][vehicle]" - add all red coalition vehicles
"[-red][vehicle]" - subtract all red coalition vehicles


Country names to be used in [c] and [-c] short-cuts:
"Turkey" 
"Norway"
"The Netherlands"
"Spain"
"UK"
"Denmark"
"USA"
"Georgia"
"Germany"
"Belgium"
"Canada"
"France"
"Israel"
"Ukraine"
"Russia"
"South Osetia"
"Abkhazia"
]]

	--Assumption: will be passed a table of strings, sequential
	local units_by_name = {}
	if not slmod.missionUnitData then --unable to do this at this time, no slmod.missionUnitData
		slmod.error('unable to get "slmod.missionUnitData", cannot interpret unit table short-cuts.')
		return tbl
	end
	local l_munits = slmod.missionUnitData
	for i = 1, #tbl do
		local unit = tbl[i]
		if unit:sub(1,4) == '[-u]' then --subtract a unit
			if units_by_name[unit:sub(5)] then -- 5 to end
				units_by_name[unit:sub(5)] = nil  --remove
			end
		elseif unit:sub(1,3) == '[g]' then -- add a group
			for coa, coa_tbl in pairs(l_munits) do
				for country, country_table in pairs(coa_tbl) do
					for unit_type, unit_type_tbl in pairs(country_table) do
						if type(unit_type_tbl) == 'table' then 
							for group_ind, group_tbl in pairs(unit_type_tbl) do
								if type(group_tbl) == 'table' and group_tbl.name == unit:sub(4) then -- index 4 to end
									for unit_ind, unit in pairs(group_tbl.units) do
										units_by_name[unit.name] = true  --add	
									end
								end
							end
						end
					end
				end
			end
		elseif unit:sub(1,4) == '[-g]' then -- subtract a group
			for coa, coa_tbl in pairs(l_munits) do
				for country, country_table in pairs(coa_tbl) do
					for unit_type, unit_type_tbl in pairs(country_table) do
						if type(unit_type_tbl) == 'table' then 
							for group_ind, group_tbl in pairs(unit_type_tbl) do
								if type(group_tbl) == 'table' and group_tbl.name == unit:sub(5) then -- index 5 to end
									for unit_ind, unit in pairs(group_tbl.units) do
										if units_by_name[unit.name] then
											units_by_name[unit.name] = nil --remove
										end
									end
								end
							end
						end
					end
				end
			end
		elseif unit:sub(1,3) == '[c]' then -- add a country
			local category = ''
			local country_start = 4
			if unit:sub(4,15) == '[helicopter]' then 
				category = 'helicopter'
				country_start = 16
			elseif unit:sub(4,10) == '[plane]' then 
				category = 'plane'
				country_start = 11
			elseif unit:sub(4,9) == '[ship]' then 
				category = 'ship'
				country_start = 10
			elseif unit:sub(4,12) == '[vehicle]' then 
				category = 'vehicle'
				country_start = 13
			end	
			for coa, coa_tbl in pairs(l_munits) do
				for country, country_table in pairs(coa_tbl) do
					if country == string.lower(unit:sub(country_start)) then   -- match
						for unit_type, unit_type_tbl in pairs(country_table) do
							if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then 
								for group_ind, group_tbl in pairs(unit_type_tbl) do
									if type(group_tbl) == 'table' then
										for unit_ind, unit in pairs(group_tbl.units) do
											units_by_name[unit.name] = true  --add	
										end
									end
								end
							end
						end
					end
				end
			end
		elseif unit:sub(1,4) == '[-c]' then -- subtract a country
			local category = ''
			local country_start = 5
			if unit:sub(5,16) == '[helicopter]' then 
				category = 'helicopter'
				country_start = 17
			elseif unit:sub(5,11) == '[plane]' then 
				category = 'plane'
				country_start = 12
			elseif unit:sub(5,10) == '[ship]' then 
				category = 'ship'
				country_start = 11
			elseif unit:sub(5,13) == '[vehicle]' then 
				category = 'vehicle'
				country_start = 14
			end	
			for coa, coa_tbl in pairs(l_munits) do
				for country, country_table in pairs(coa_tbl) do
					if country == string.lower(unit:sub(country_start)) then   -- match
						for unit_type, unit_type_tbl in pairs(country_table) do
							if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then 
								for group_ind, group_tbl in pairs(unit_type_tbl) do
									if type(group_tbl) == 'table' then 
										for unit_ind, unit in pairs(group_tbl.units) do
											if units_by_name[unit.name] then
												units_by_name[unit.name] = nil  --remove
											end
										end
									end
								end
							end
						end
					end
				end
			end
		elseif unit:sub(1,6) ==  '[blue]' then -- add blue coalition
			local category = ''
			if unit:sub(7) == '[helicopter]' then 
				category = 'helicopter'
			elseif unit:sub(7) == '[plane]' then 
				category = 'plane'
			elseif unit:sub(7) == '[ship]' then 
				category = 'ship'
			elseif unit:sub(7) == '[vehicle]' then 
				category = 'vehicle'
			end	
			for coa, coa_tbl in pairs(l_munits) do
				if coa == 'blue' then
					for country, country_table in pairs(coa_tbl) do
						for unit_type, unit_type_tbl in pairs(country_table) do
							if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then 
								for group_ind, group_tbl in pairs(unit_type_tbl) do
									if type(group_tbl) == 'table' then
										for unit_ind, unit in pairs(group_tbl.units) do
											units_by_name[unit.name] = true  --add										
										end
									end
								end
							end
						end
					end
				end
			end	
		elseif unit:sub(1,7) == '[-blue]' then -- subtract blue coalition
			local category = ''
			if unit:sub(8) == '[helicopter]' then 
				category = 'helicopter'
			elseif unit:sub(8) == '[plane]' then 
				category = 'plane'
			elseif unit:sub(8) == '[ship]' then 
				category = 'ship'
			elseif unit:sub(8) == '[vehicle]' then 
				category = 'vehicle'
			end	
			for coa, coa_tbl in pairs(l_munits) do
				if coa == 'blue' then
					for country, country_table in pairs(coa_tbl) do
						for unit_type, unit_type_tbl in pairs(country_table) do
							if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then  
								for group_ind, group_tbl in pairs(unit_type_tbl) do
									if type(group_tbl) == 'table' then
										for unit_ind, unit in pairs(group_tbl.units) do
											if units_by_name[unit.name] then
												units_by_name[unit.name] = nil  --remove
											end
										end
									end
								end
							end
						end
					end
				end
			end	
		elseif unit:sub(1,5) == '[red]' then -- add red coalition
			local category = ''
			if unit:sub(6) == '[helicopter]' then 
				category = 'helicopter'
			elseif unit:sub(6) == '[plane]' then 
				category = 'plane'
			elseif unit:sub(6) == '[ship]' then 
				category = 'ship'
			elseif unit:sub(6) == '[vehicle]' then 
				category = 'vehicle'
			end	
			for coa, coa_tbl in pairs(l_munits) do
				if coa == 'red' then
					for country, country_table in pairs(coa_tbl) do
						for unit_type, unit_type_tbl in pairs(country_table) do
							if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then  
								for group_ind, group_tbl in pairs(unit_type_tbl) do
									if type(group_tbl) == 'table' then
										for unit_ind, unit in pairs(group_tbl.units) do
											units_by_name[unit.name] = true  --add									
										end
									end
								end
							end
						end
					end
				end
			end
		elseif unit:sub(1,6) == '[-red]' then -- subtract red coalition
			local category = ''
			if unit:sub(7) == '[helicopter]' then 
				category = 'helicopter'
			elseif unit:sub(7) == '[plane]' then 
				category = 'plane'
			elseif unit:sub(7) == '[ship]' then 
				category = 'ship'
			elseif unit:sub(7) == '[vehicle]' then 
				category = 'vehicle'
			end	
			for coa, coa_tbl in pairs(l_munits) do
				if coa == 'red' then
					for country, country_table in pairs(coa_tbl) do
						for unit_type, unit_type_tbl in pairs(country_table) do
							if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then  
								for group_ind, group_tbl in pairs(unit_type_tbl) do
									if type(group_tbl) == 'table' then
										for unit_ind, unit in pairs(group_tbl.units) do
											if units_by_name[unit.name] then
												units_by_name[unit.name] = nil  --remove
											end
										end
									end
								end
							end
						end
					end
				end
			end	
		elseif unit:sub(1,5) == '[all]' then -- add all of a certain category (or all categories)
			local category = ''
			if unit:sub(6) == '[helicopter]' then 
				category = 'helicopter'
			elseif unit:sub(6) == '[plane]' then 
				category = 'plane'
			elseif unit:sub(6) == '[ship]' then 
				category = 'ship'
			elseif unit:sub(6) == '[vehicle]' then 
				category = 'vehicle'
			end	
			for coa, coa_tbl in pairs(l_munits) do
				for country, country_table in pairs(coa_tbl) do
					for unit_type, unit_type_tbl in pairs(country_table) do
						if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then  
							for group_ind, group_tbl in pairs(unit_type_tbl) do
								if type(group_tbl) == 'table' then
									for unit_ind, unit in pairs(group_tbl.units) do
										units_by_name[unit.name] = true  --add										
									end
								end
							end
						end
					end
				end
			end
		elseif unit:sub(1,6) == '[-all]' then -- subtract all of a certain category (or all categories)
			local category = ''
			if unit:sub(7) == '[helicopter]' then 
				category = 'helicopter'
			elseif unit:sub(7) == '[plane]' then 
				category = 'plane'
			elseif unit:sub(7) == '[ship]' then 
				category = 'ship'
			elseif unit:sub(7) == '[vehicle]' then 
				category = 'vehicle'
			end	
			for coa, coa_tbl in pairs(l_munits) do
				for country, country_table in pairs(coa_tbl) do
					for unit_type, unit_type_tbl in pairs(country_table) do
						if type(unit_type_tbl) == 'table' and (category == '' or unit_type == category) then  
							for group_ind, group_tbl in pairs(unit_type_tbl) do
								if type(group_tbl) == 'table' then
									for unit_ind, unit in pairs(group_tbl.units) do
										if units_by_name[unit.name] then
											units_by_name[unit.name] = nil  --remove
										end
									end
								end
							end
						end
					end
				end
			end				
		else -- just a regular unit
			units_by_name[unit] = true  --add	
		end
	end
	
	local units_tbl = {}  -- indexed sequentially
	for unit_name, val in pairs(units_by_name) do
		if val then 
			units_tbl[#units_tbl + 1] = unit_name  -- add all the units to the table
		end
	end
	
	units_tbl['processed'] = true  --add the processed flag
	return units_tbl
end

--[[ Structure of slmod.clients:
slmod.clients = {
	--Note: host is always client ID# 1
	
	[<client id#] = {
		id = <number, client ID#>, 
		addr = <number, ip address (N/A for host)>, 
		name = <string multiplayer name>, 
		ucid = <string ucid; not guaranteed for host!>,
		ip = <number, ip address (N/A for host)>, -- same as addr
		
		-- updated quantities, could be maybe a second old..
		coalition = <string>, -- either "red", "blue" or "spec"; should be guaranteed field.
		unitName = <string ME unit name>, -- not guaranteed
		rtid = <number, unit runtime id#>, -- not guaranteed
	},
	
}
--Also existing:
slmod.clientsByRtId -- same as above, indexed by unit rtid, does not include CA/spectators.
slmod.clientsByName -- same as above, indexed by unitName, does not include CA/spectators

In main simulation:

slmod.clientsMission -- should be the same as slmod.clientsByName, renamed because I was confused. 

]]


--this goes in SlmodUnits after every new slmod.activeUnits table is created.
function slmod.updateClients()  --net function, updates clients in the server environment- provides ME name/id_ pairs.
	-- save old data, could need it.

	if slmod.clients then
		slmod.oldClients = slmod.deepcopy(slmod.clients)
	end
	if slmod.clientsByRtId then
		slmod.oldClientsByRtId = slmod.deepcopy(slmod.clientsByRtId)
	end
	if slmod.clientsByName then
		slmod.oldClientsByName = slmod.deepcopy(slmod.clientsByName)
	end
	
	slmod.clientsByRtId = {}
	slmod.clientsByName = {}
	local serverSlmodClients = {}
	for id, client in pairs(slmod.clients) do   -- key and client should be same in this case.
		client['coalition'] = slmod.getClientSide(id)
		local name, rtid, seatId = slmod.getClientNameAndRtId(id)
		if name and rtid and rtid ~= '' and name ~= '' then
			rtid = tonumber(rtid)
			if rtid > 0 then
				serverSlmodClients[name] = client
				client['unitName'] = name  -- add unitName and rtid to slmod.clients.
				client['rtid'] = rtid
								-- add to clientsByRtId
                              
				if not slmod.clientsByRtId[rtid] then
                    slmod.clientsByRtId[rtid]= {}
                end
                slmod.clientsByRtId[rtid][seatId] = client
				if not slmod.clientsByName[name] then
                    slmod.clientsByName[name] = {}
                end
                slmod.clientsByName[name][seatId] = client
			end
		else
			-- erase in case old data is still there.
			client['rtid'] = nil
			client['unitName'] = nil
			--net.log('Slmod warning: unable to retrieve runtime id and/or ME unit name for client number ' .. tostring(key))  --remove this line in final versions.  Normal if client is not in a unit.
		end
	end
	local s = table.concat({'slmod = slmod or {}\n', 'slmod.clientsMission = ', slmod.oneLineSerialize(serverSlmodClients)})
	
	local str, err = net.dostring_in('server', s)
	if not err then
		slmod.error('failed to create table slmod.clients in server environment, reason: ' .. str)
	end
end


function slmod.checkSlmodClients()  -- global function- checks for errors in slmod.clients... experimental.
	slmod.scheduleFunctionByRt(slmod.checkSlmodClients, {}, DCS.getRealTime() + 60)
	for i = 2, 250 do  -- arbitrarily up to 250.
		local name = net.get_name(i)
		if name then  -- client exists
			--slmod.info('slmod.checkSlmodClients(): client ' .. tostring(i) .. ' exists.')
			if not slmod.clients[i] then
				net.kick(i, 'Slmod: You were not found in internal slmod.clients database, sorry, please reconnect.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for not existing in slmod.clients database!')
			elseif (not slmod.clients[i].name) then
				net.kick(i, 'Slmod: Error- you have no name, please reconnect.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for having no name in slmod.clients!')
			elseif name ~= slmod.clients[i].name then
				net.kick(i, 'Slmod: Sorry, you may not change your name, please reconnect.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for their name not matching their name in slmod.clients database!')
			elseif (not slmod.clients[i].ip) then
				net.kick(i, 'Slmod: Error- you have no IP, please reconnect.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for having no IP in slmod.clients!')
			elseif slmod.bannedIps and slmod.bannedIps[slmod.clients[i].ip] then -- client is supposed to be banned... wtf.
				net.kick(i, 'Slmod: You are banned from this server.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for somehow being connected with a banned IP!')
			elseif (not slmod.clients[i].ucid) then
				net.kick(i, 'Slmod: Error- you have no UCID, please reconnect.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for having no UCID in slmod.clients!')
			elseif slmod.bannedUcids and slmod.bannedUcids[slmod.clients[i].ucid] then -- client is supposed to be banned... wtf.
				net.kick(i, 'Slmod: You are banned from this server.')
				slmod.error('Client ' .. tostring(i) .. ' was kicked for somehow being connected with a banned UCID!')		
			end
		end
	end
end

-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-- Code to build all the activeUnits databases.

function slmod.create_getUnitXYZ()  -- function to return unit x,y,z data.
	local getUnitXYZ_string = [[slmod = slmod or {}
slmod.getUnitXYZ = function(rtId)
	local unit = {id_ = rtId}
    if unit then
        if Unit.isExist(unit) and Unit.isActive(unit) then
            local pos = Unit.getPosition(unit).p
            return table.concat({pos.x, ' ', pos.y, ' ', pos.z}) 
        end
    end
end]]
	net.dostring_in('server', getUnitXYZ_string)
end


function slmod.getUnitXYZ(rtId)
	local str, err = net.dostring_in('server', table.concat({'return slmod.getUnitXYZ(', rtId, ')'}))  -- avoiding string concatenation operator whenever possible!
	if err and str ~= '' then
		local firstSpace, secondSpace, x, y, z
		local firstSpace = str:find(' ')
		if firstSpace then
			secondSpace = str:find(' ', firstSpace + 1)
			if secondSpace then
				return tonumber(str:sub(1, firstSpace - 1)), tonumber(str:sub(firstSpace + 1, secondSpace - 1)), tonumber(str:sub(secondSpace + 1))
				--						x											y												z                                   
			end
		end
	elseif slmod.config.export_world_objs and not err then
		slmod.info('Error trying to do slmod.getUnitXYZ: ' .. rtId .. ' : error' ..tostring(str))
	end
end


function slmod.updateActiveUnits()  -- the coroutine to update active units table.
	--slmod.info('beginning slmod.updateActiveUnits')
	-- start a new cycle...  beginning assumption: assume this function runs about 20 times a sec.
	if slmod.activeUnitsBase then  -- only run if slmod.activeUnitsBase
		local numUnits = #slmod.activeUnitsBase
		--slmod.info(numUnits)
		
		local newActiveUnits = {}  -- the beginning of the NEW activeUnits tables.
		local newActiveUnitsByName = {}
		
		local unitsPerCycle = math.floor(numUnits/60) + 1  -- at 20 times a second, this should put us at one update every 3 seconds.
		
		if unitsPerCycle < 5 then -- it would be kinda stupid to do, like, 2 units per cycle.  So the coroutine could finish early, but it will probably save execution time.
			unitsPerCycle = 5
		end
		
		for unitInd = 1, #slmod.activeUnitsBase do
            local unit = slmod.activeUnitsBase[unitInd]
			local rtId = DCS.getUnitProperty(unit.unitId, 1)
			if rtId then
                local x, y, z = slmod.getUnitXYZ(rtId)
				if x then -- x, y, and z must exist, so unit is alive and active.
                    local activeUnit = slmod.deepcopy(unit)

					activeUnit.id = tonumber(rtId) -- I do believe it is a number, but it might be a string...
					activeUnit.x = x
					activeUnit.y = y
					activeUnit.z = z
					if activeUnit.skill == 'Client' or activeUnit.skill == 'Player' then
						activeUnit.mpname = DCS.getUnitProperty(unit.unitId, 14)
					end
                    newActiveUnits[tonumber(rtId)] = activeUnit
					newActiveUnitsByName[unit.name] = activeUnit
				end
			end
			
			--Now check if coroutine is ready for pause.
			if unitInd%unitsPerCycle == 0 then
				coroutine.yield()
			end
		end
		--udpateActiveUnits coroutine complete, update active units now.
		
		slmod.oldActiveUnits = slmod.activeUnits
		slmod.oldActiveUnitsByName = slmod.activeUnitsByName  
		
		slmod.activeUnits = newActiveUnits  
		slmod.activeUnitsByName = newActiveUnitsByName
		if slmod.config.export_world_objs then
			local f = io.open(lfs.writedir() .. 'Slmod\\activeUnits.txt', 'w')
			if f then
				f:write(slmod.serialize('slmod.activeUnits', slmod.activeUnits))
				f:close()
			end
		end
		
		--slmod.info('completed slmod.updateActiveUnits at ' .. os.clock())
	else
		slmod.warning('Unable to start active units database, slmod.activeUnitsBase does not exist.')
	end
end

--Gonna comment out loadstring_res, but going to leave it in for now
--[==[
-- Uses up too much memory, use slmod_mem_ls instead
local loadstring_res = {}
function mem_loadstring(s)
	local res = loadstring_res[s]
	if res == nil then 
		res = assert(loadstring(s))
		loadstring_res[s] = res
	end
	return res
end

ls_res = {}  --global table of memoized loadstrings, will need to access it in multple functions
ls_strng_list = {} --Contains a list of all the strings that the slmod mem_loadstring function was used on

function slmod_mem_ls(s)  --The slmod version of mem_loadstring, made especially for the GetActiveUnits function
--[[Specialized mem_loadstring- set up to work with gc_slmod_mem_ls to garbage collect anything that wasn't used in current active units cycle
	Maybe I can implement this more elegantly with weak tables? - need to investigate further ]]--
	local res = ls_res[s]
	ls_strng_list[s] = true
	if res == nil then 
		res = assert(loadstring(s))
		ls_res[s] = res
	end
	--Determining relative memory usage
	-- memoize_c = memoize_c  or 0			
	-- if memoize_c >= 10 then
		-- local ls_res_size = 0

		-- for k, v in pairs(ls_res) do
			-- ls_res_size = ls_res_size + #k
		-- end
		-- net.log('the size of loadstring_res is:')
		-- net.log(ls_res_size)
		-- net.log('\n')
					
		-- memoize_c = 0
	-- end
	return res
end

function gc_slmod_mem_ls()  -- garbage collection for slmod_mem_loadstring, do after each GetActiveUnits cycle is completed
	--[[ ls_strng_list contains all the strings that slmod_mem_ls(s) was used on.  Due to the nature of units, once a string
	     that was loaded last cycle is not loaded this cycle, that string will almost certainly never appear again- the unit 
		 is moving.  So delete that string from the ls_res table to prevent what would effectively be a large memory leak!]]--
	for s, f in pairs(ls_res) do
		if ls_strng_list[s] == nil then  --if this string was not attempted to be loaded this cycle
			ls_res[s] = nil  --then delete this entry
		end
	end
	ls_strng_list = nil --delete string table in preparation for next cycle
	ls_strng_list = {} -- recreate
end
]==]


function slmod.create_getUnitAttributes()
	
	local getUnitAttributesString = [[slmod = slmod or {}
function slmod.getUnitAttributes()

	local objects = {} -- the returned table.
	local alreadyNamed = {} -- some objects have duplicate entries- "aliases".
	for objName, object in pairs(Objects) do
		local name = object.Name
		if not alreadyNamed[name] then
			alreadyNamed[name] = true
			local obj = {}
			obj['name'] = name  -- used in ME display. Could be useful.
			obj['shapeName'] = object.ShapeName  -- 3D model shape name, I think.
			obj['displayName'] = object.DisplayName -- display name in ME?  Or where?
			obj['origin'] = object._origin
            obj['attributes'] = {}
			if object.attribute then
				for ind, attribute in pairs(object.attribute) do
					if type(attribute) == 'string' then -- throw out wsTypes.
						obj.attributes[attribute] = true
					end
				end
			else
				obj.attributes['Static'] = true
			end
			obj['aliases'] = object.Aliases  -- not sure what the aliases are good for...

			-- now, add to the objects table.
			objects[name] = obj

		end
	end

	return slmod.serializeWithCycles('unitAttributes', objects)
end]]
	local str, err = net.dostring_in('server', getUnitAttributesString)
	if not err then
		slmod.error('unable to create slmod.getUnitAttributes in server env, reason: ' .. tostring(str))
	end
end

function slmod.makeUnitAttributesTable()
	local str, err = net.dostring_in('server', 'return slmod.getUnitAttributes()')
	if err then
		local val, err = slmod.deserializeValue(str)
		if val then
			slmod.unitAttributes = val
			slmod.info('successfully loaded unitAttributes.')
		else
			slmod.error('unable deserialize unit attributes, reason: ' .. tostring(err))
		end
	else
		slmod.error('unable to run slmod.getUnitAttributes in server env, reason: ' .. tostring(str))
	end
end
--[[
"Ground Units"

SAM Categories:
"SAM"
"SAM LL"
"SR SAM"
"MR SAM"
"LR SAM"
"SAM CC"

if not above, then,
"AAA"

If not above, then try
"MLRS" or "Artillery" or "Indirect fire"

If not above, then try:
"Infantry"

If still here, then try:
"Armored vehicles"

If still here, then try:
"NonAndLightArmoredUnits"

Now see how it parses up...
]]

function slmod.unitHasAttribute(unitType, attr)
	local unit = slmod.unitAttributes[unitType]
	if unit then
		if unit.attributes and unit.attributes[attr] then
			return true
		else
			return false
		end
	else
		slmod.error('slmod.unitHasAttribute- unitType "' .. unitType .. '" not in slmod.unitAttributes!')
	end
end

function slmod.makeUnitCategories()
	slmod.unitCategories = {
		['Ground Units'] = {
			['SAM'] = {}, 
			['AAA'] = {}, 
			['EWR'] = {}, 
			['Arty/MLRS'] = {}, 
			['Infantry'] = {}, 
			['Tanks'] = {},
			['IFVs'] = {},
			['APCs'] = {},
			['Unarmored'] = {}, 
			['Forts'] = {}, 
			['Other'] = {} 
		}, 
		['Planes'] = {
			['Fighters'] = {},
			['Attack'] = {},
			['Bombers'] = {},
			['Support'] = {},
			['UAVs'] = {},
			['Transports'] = {},
			['Other'] = {}
		}, 
		['Helicopters'] = {
			['Attack'] = {},
			['Utility'] = {},
			['Other'] = {}
		}, 
		['Ships'] = {
			['Warships'] = {},
			['Subs'] = {},
			['Unarmed'] = {},
			['Other'] = {}
		}, 
		['Buildings'] = {
			['Static'] = {},
			['Other'] = {}, -- not used at this time.
		}
	}
	slmod.catsByUnitType = {}
	for unitTypeName, unitData in pairs(slmod.unitAttributes) do
        -- Ground Units
        --slmod.info(unitTypeName)
		if slmod.unitHasAttribute(unitTypeName, "Ground Units") or slmod.unitHasAttribute(unitTypeName, "Air Defence") then  -- only do ground units!
			if slmod.unitHasAttribute(unitTypeName, "SAM") or slmod.unitHasAttribute(unitTypeName, "SAM LL") or slmod.unitHasAttribute(unitTypeName, "SR SAM") or slmod.unitHasAttribute(unitTypeName, "MR SAM") or slmod.unitHasAttribute(unitTypeName, "LR SAM") or slmod.unitHasAttribute(unitTypeName, "SAM CC") then
				slmod.unitCategories['Ground Units']['SAM'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'SAM'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "AAA") then
				slmod.unitCategories['Ground Units']['AAA'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'AAA'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "EWR") or slmod.unitHasAttribute(unitTypeName, "SAM SR") or slmod.unitHasAttribute(unitTypeName, "SAM TR") then
				slmod.unitCategories['Ground Units']['EWR'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'EWR'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Artillery") or slmod.unitHasAttribute(unitTypeName, "MLRS") or slmod.unitHasAttribute(unitTypeName, "Indirect fire") then
				slmod.unitCategories['Ground Units']['Arty/MLRS'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'Arty/MLRS'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Infantry") then
				slmod.unitCategories['Ground Units']['Infantry'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'Infantry'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Tanks") then
				slmod.unitCategories['Ground Units']['Tanks'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'Tanks'}	
				
			elseif slmod.unitHasAttribute(unitTypeName, 'IFV') then
				slmod.unitCategories['Ground Units']["IFVs"][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'IFVs'}	
				
			elseif slmod.unitHasAttribute(unitTypeName, "APC") then
				slmod.unitCategories['Ground Units']["APCs"][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', "APCs"}
				
			elseif slmod.unitHasAttribute(unitTypeName, "NonAndLightArmoredUnits") then
				slmod.unitCategories['Ground Units']['Unarmored'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'Unarmored'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Fortifications") then
				slmod.unitCategories['Ground Units']['Forts'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'Forts'}
				
			else
				slmod.unitCategories['Ground Units']['Other'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ground Units', 'Other'}
			end	
			
		elseif slmod.unitHasAttribute(unitTypeName, "Ships") then  
			if slmod.unitHasAttribute(unitTypeName, "Heavy armed ships") then
				slmod.unitCategories['Ships']['Warships'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ships', 'Warships'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Submarines") then
				slmod.unitCategories['Ships']['Subs'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ships', 'Subs'}
			
			elseif slmod.unitHasAttribute(unitTypeName, "Unarmed ships") then
				slmod.unitCategories['Ships']['Unarmed'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ships', 'Unarmed'}
				
			else 
				slmod.unitCategories['Ships']['Other'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Ships', 'Other'}
			end
			
		elseif slmod.unitHasAttribute(unitTypeName, "Planes") then  
            if slmod.unitHasAttribute(unitTypeName, "Multirole fighters")  or slmod.unitHasAttribute(unitTypeName, "Fighters") or slmod.unitHasAttribute(unitTypeName, "Interceptors") or unitTypeName == "I-16" or (slmod.unitHasAttribute(unitTypeName, "Battleplanes") and unitData.origin and (string.find(unitData.origin, 'World War II') or string.find(unitData.origin, 'WWII'))) then
				slmod.unitCategories['Planes']['Fighters'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'Fighters'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Battleplanes") then
				slmod.unitCategories['Planes']['Attack'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'Attack'}
			
			elseif slmod.unitHasAttribute(unitTypeName, "Aux") or slmod.unitHasAttribute(unitTypeName, "Tankers") or slmod.unitHasAttribute(unitTypeName, "AWACS") then
				slmod.unitCategories['Planes']['Support'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'Support'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Strategic bombers") or slmod.unitHasAttribute(unitTypeName, "Bombers") then
				slmod.unitCategories['Planes']['Bombers'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'Bombers'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "UAVs") then
				slmod.unitCategories['Planes']['UAVs'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'UAVs'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Transports") then
				slmod.unitCategories['Planes']['Transports'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'Transports'}
				
			else
				slmod.unitCategories['Planes']['Other'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Planes', 'Other'}
			
			end	
			
		elseif slmod.unitHasAttribute(unitTypeName, "Helicopters") then  
			if slmod.unitHasAttribute(unitTypeName, "Attack helicopters") and unitTypeName ~= "UH-1H" and unitTypeName ~= "SH-60B" and unitTypeName ~= "Mi-8MT" and unitTypeName ~= "Mi-8MTV2"then
				slmod.unitCategories['Helicopters']['Attack'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Helicopters', 'Attack'}
				
			elseif slmod.unitHasAttribute(unitTypeName, "Transport helicopters") or unitTypeName == "UH-1H" or unitTypeName == "SH-60B" or unitTypeName == "Mi-8MT" or unitTypeName == "Mi-8MTV2" then
				if unitTypeName == 'Mi-8MTV2' then -- creates the Mi-8 exception because sigh
					slmod.unitCategories['Helicopters']['Utility']["Mi-8MT"] = true
					slmod.catsByUnitType["Mi-8MT"] = {'Helicopters', 'Utility'}
				end
				slmod.unitCategories['Helicopters']['Utility'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Helicopters', 'Utility'}
			else
				slmod.unitCategories['Helicopters']['Other'][unitTypeName] = true
				slmod.catsByUnitType[unitTypeName] = {'Helicopters', 'Other'}
			
			end
			
		else--if slmod.unitHasAttribute(unitTypeName, "Static") then
			slmod.unitCategories['Buildings']['Static'][unitTypeName] = true
			slmod.catsByUnitType[unitTypeName] = {'Buildings', 'Static'}
		--else
		
		end
		
	end
    -- Hard-code attributes in that may be missed due to Dedicated Server Bug. 
    if not slmod.catsByUnitType['TF-51D'] then
        slmod.unitCategories['Planes']['Fighters']['TF-51D'] = true
        slmod.catsByUnitType['TF-51D'] = {'Planes', 'Fighters'}
    end
    
end

slmod.info('SlmodUnits.lua loaded.')