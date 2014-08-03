-- New AirCmdbl class, for commandable air groups.
do
	 -- returns the loadout for the flight, from mission.  Indexed by flight lead.
	local function getLoadout(groupName)
		
		local function getWeaponName(CLSID)  -- returns type name of weapon by CLSID, only for external stores/bomb bays
	
		end
		
		
	end
	
	-- gets the unit names, maybe more data? aircraft type? runtime id? from mission.
	local function getUnits(groupName)
	
	end
	
	-- Gets the group's original mission from mission.
	local function getOriginalMission(groupName)
	
	end
	
	-- get's the group's base task (SEAD, CAS, Transport, etc.) from mission.
	local function getBaseTask(groupName)
	
	end
	
	-- get aircraft type from v6mission_unit_data or whatever.
	local function getAircraftType(groupName)
	
	end
	

	--[[
	CmdblAir class:
	instance.groupName = string -- passed in with the create function
	instance.unitNames = table of unit names, indexed by flight order
	instance.loadout = table of starting load out, indexed by flight order
	instance.getWeapons = 
	]]
	CmdblAir = {
		create = function(vars) -- for now, vars just has one entry, groupName
			local new = {}
			for key, val in pairs(vars) do
				if type(val) == 'table' then
					new[key] = slmod.deepcopy(val)
				else
					new[key] = val
				end
			end
			
			new.loadout = getLoadout(new.groupName)  -- starting loadout
			new.unitNames = getUnits(new.groupName)
			new.originalMission = getOriginalMission(new.groupName)
			new.baseTask = getBaseTask(new.groupName)
			new.type = getAircraftType(new.groupName)
			
			setmetatable(new, { __index = AirCmdbl })
			return new
		end,
		
		getWeapons = function(self)  -- returns table of weapons, indexed by flight order
			--[[returns:
			weapons = {
				[1] = {  --flight lead
					[1] = {
						type = "GBU-31",
						quant = 4,
					},
				},
				[2] = {
					[1] = {
						type = "GBU-31",
						quant = 4,
					},
				},
			}
			]]
			local loadout = self.loadout
			-- now, look through Slmod events and subtract all fired munitions.
			-- problem- events uses events type names, donno if I can get those anywhere.
		end,
		
		pushTask = function(self, task)
			net.dostring_in('server', 'Group.getByName(' .. slmod.basicSerialize(self.groupName) .. '):getController():pushTask(' .. slmod.oneLineSerialize(task) .. ')')
		end,
		
		popTask = function(self)
			net.dostring_in('server', 'Group.getByName(' .. slmod.basicSerialize(self.groupName) .. '):getController():popTask()')
		end,
		
		setOrbit = function(self, point)
		
		end,
		
		RTB = function(self) 
			--return to either starting or stopping runway (prefer stopping) else, pop all tasks?
		end,
		
		getWeaponsReport = function(self)
			local weapons = 
		end,


	}
	
	CmdblBomber = {
		create = function(vars)
			local new = CmdblAir.create(vars)
			setmetatable(new, { __index = CmdblBomber })
			return new
		end,
		
		bombPoint = function(self, point, expend)
		
		end,
		
		bombUnit = function(self, point)
		
		end,
		
	}
	setmetatable(CmdblBomber, { __index = CmdblAir }) -- set CmdblBomber as child class of CmdblAir
	
	CmdblSEAD = {
		create = function(vars)
			local new = CmdblAir.create(vars)
			setmetatable(new, { __index = CmdblSEAD })
			return new
		end,
		
		searchThenEngage = function(self, point, radius)
		
		end,
		
		SEADPoint = function(self, point, radius)
		
		end,
		
		enableSEAD = function(self, enable)
		
		end,
		
		attackUnit = function(self, point)
			-- attempt to find and attack a unit near a point
			-- idea: flies to point, tries to find unit near point
		end,
		
		setOrbit = function(self, point)
		
		end,
		
	}
	setmetatable(CmdblSEAD, { __index = CmdblAir }) -- set CmdblSEAD as child class of CmdblAir
	
	CmdblCAP = {
		create = function(vars)
			local new = CmdblAir.create(vars)
			setmetatable(new, { __index = CmdblCAP })
			return new
		end,
		
		searchThenEngage = function(self, point, radius)
		
		end,
		
		engageGroup = function(self, groupName) -- probably won't need this one, but it seems too basic to not include
		
		end,
		
		CAPPoint = function(self, point)  -- assumption- only one 
		
		end,
		
		enableCAP = function(self, enable) -- enable is a bool
		
		end,
		
		setOrbit = function(self, point)
		
		end,
		
		help = function(self, requester) -- could use escort if it gets fixed for MP clients
		
		end,
		
	}
	setmetatable(CmdblCAP, { __index = CmdblAir }) -- set CmdblCAP child class of CmdblAir
	
	CmdblCAS = {
		create = function(vars)
			local new = CmdblAir.create(vars)
			setmetatable(new, { __index = CmdblCAS })
			return new
		end,
		
		searchThenEngage = function(self, point, radius)
		
		end,
		
		engageGroup = function(self, groupName) -- probably won't need this one, but it seems too basic to not include
		
		end,
		
		CASPoint = function(self, point)  -- assumption- only one 
		
		end,
		
		enableCAS = function(self, enable) -- enable is a bool
		
		end,
		
		attackUnit = function(self, point)
			-- attempt to find and attack a unit near a point
			-- idea: flies to point, tries to find unit near point
		end,
		
		help = function(self, requester) -- could use escort if it gets fixed for MP clients
		
		end,
		
	}
	setmetatable(CmdblCAS, { __index = CmdblAir }) -- set CmdblCAS as child class of CmdblAir

end

-- Create the menus
do
	CmdblAirMenu = {
	
	
	
	}
	
	
	CmdblBomberMenu = {
	
	}
	setmetatable(CmdblBomberMenu, { __index = CmdblAirMenu })
	
	CmdblSEADMenu = {
	
	}
	setmetatable(CmdblSEADMenu, { __index = CmdblAirMenu })	
	
	CmdblCAPMenu = {
	
	}
	setmetatable(CmdblCAPMenu, { __index = CmdblAirMenu })
	
	CmdblCASMenu = {
	
	}
	setmetatable(CmdblCASMenu, { __index = CmdblAirMenu })


end
