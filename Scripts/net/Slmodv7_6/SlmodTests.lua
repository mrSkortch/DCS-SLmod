function slmod.doOnceTest1()  -- called ONCE at t = 1 after mission start

	local testStatsStr = [[Stats for player: "Speed", SlmodStats ID# 43:
			
			FLIGHT TIMES:
				A-10C = 17.4 hours
				Ka-50 = 45.1 hours
				CA = 23.7 hours
				Su-27 = 3.0 hours
				F-15C = 6.2 hours
				
			KILLS:
			Ground Targets:		Planes:				Helicopters:		Ships:					Buildings:
			Tanks = 51			Fighters = 13		Attack = 6			Warships = 2			Static Objects = 15
			IFVs = 43			Attack = 7			Utility = 3			Unarmed Ships = 1
			APCs = 25			Bombers = 2								Other Ships = 3
			Arty/MLRS = 15		Support/Recon = 1						
			SAMs = 25			UAVs = 0
			AAA = 20			Transports = 4
			EWR = 3					
			Unarmored = 51
			Forts = 4
			---------------------------------------------------------------------------------------------------------
			TOTAL = 345			TOTAL = 25			TOTAL = 9			TOTAL = 6				TOTAL = 15
			
			LOSSES:
				Crashes = 12
				Ejections = 9
				Pilot Deaths = 3
			
			PLAYER VS. PLAYER:
				Kills = 30
				Losses = 19]]
				
	local luaCode = 'trigger.action.outText(' .. slmod.basicSerialize(testStatsStr) .. ', 30)'

	-- local str, err = net.dostring_in('server', luaCode)
	-- if not err then
		-- slmod.info('error doing code: ' .. tostring(str))
	-- end
	-- local retUnitXYZ_string = [[retUnitXYZ = function(unitName)
	-- local unit = Unit.getByName(unitName)
	-- if unit and unit:isActive() then
		-- local pos = unit:getPosition().p
		-- return table.concat({pos.x, ' ', pos.y, ' ', pos.z}) 
		----return pos.x .. ' ' .. pos.y .. ' ' .. pos.z
	-- end
-- end	]]

	
	-- local str, err = net.dostring_in('server', retUnitXYZ_string)
	
	
	
	-- local teststring = [[START "C:\Program Files\Eagle Dynamics\DCS World\bin\luae.exe" "]] .. [[C:\Program Files\Eagle Dynamics\DCS World\test.lua]] .. [["]]
	-- os.execute(teststring)
	-- slmod.makeCLSIDsTbl()
	
	
	
	
	
	
	
	-- local err, bool = net.dostring_in('mission', "net.log(\"TESTING a_do_script!\"); net.log(a_do_script(\"net.log('testing 123'); return 'test'\"))")
	-- net.log(err)
	-- net.log(bool)
end



function slmod.onProcessTest1()  -- called every 1 second

	-- local function testToNumber()
		-- local testStr = '5421.445231 344112.1133 -100442.32312'
		
		
		-- local startTime = os.clock()
		-- slmod.info('starting testToNumber test at: ' .. startTime)
		-- for i = 1, 1e3 do
			-- local firstSpace, secondSpace, x, y, z
			-- local firstSpace = testStr:find(' ')
			-- if firstSpace then
				-- secondSpace = testStr:find(' ', firstSpace + 1)
				-- if secondSpace then
					-- x = tonumber(testStr:sub(1, firstSpace - 1))
					-- y = tonumber(testStr:sub(firstSpace + 1, secondSpace - 1))
					-- z = tonumber(testStr:sub(secondSpace + 1))
				-- end
			-- end
		-- end
		-- local stopTime = os.clock()
		
		-- slmod.info('completed testToNumber test at: ' .. stopTime)
		-- slmod.info('processing time required: ' .. (stopTime - startTime)*1e3 .. ' milliseconds.')
	-- end
	
	
	-- local function testLoadString()
		-- local testStr = 'data = {x = 5421.445231, y = 344112.1133, z = -100442.32312}'
		
		
		-- local startTime = os.clock()
		-- slmod.info('starting testLoadString at: ' .. startTime)
		-- for i = 1, 1e3 do
			-- local f = loadstring(testStr)
			-- local env = {}
			-- setfenv(f, env)
			-- f()
			-- local data = env.data
		-- end
		-- local stopTime = os.clock()
		
		-- slmod.info('completed testLoadString at: ' .. stopTime)
		-- slmod.info('processing time required: ' .. (stopTime - startTime)*1e3 .. ' milliseconds.')
	-- end
	
	-- testToNumber()
	-- testLoadString()



	-- local startTime = os.clock()
	-- slmod.info('starting retUnitXYZ test at: ' .. startTime)
	-- for i = 1, 1e3 do
		-- local str, err = net.dostring_in('server', 'return retUnitXYZ(\'testunit\')')
		-- if err and str ~= '' then
			-- local firstSpace, secondSpace, x, y, z
			-- local firstSpace = str:find(' ')
			-- if firstSpace then
				-- secondSpace = str:find(' ', firstSpace + 1)
				-- if secondSpace then
					-- x = tonumber(str:sub(1, firstSpace - 1))
					-- y = tonumber(str:sub(firstSpace + 1, secondSpace - 1))
					-- z = tonumber(str:sub(secondSpace + 1))
				-- end
			-- end
		-- else
			-- slmod.info('Error trying to do retUnitXYZ: ' .. tostring(str))
		-- end
	-- end
	-- local stopTime = os.clock()
	-- slmod.info('completed retUnitXYZ test at: ' .. stopTime)
	-- slmod.info('processing time required: ' .. (stopTime - startTime)*1e3 .. ' milliseconds.')

	
	---DOESN'T WORK except when scriptman calls this via a function?! (Perhaps change all references of scriptman to refer to this data?)  probably not, it's probably already like this.  Hmmm..
	-- local mizstr, mizerr = net.dostring_in('mission', [[mission["coalition"]["blue"]["country"][9]["vehicle"]["group"][1]["tasks"][1]["params"]["action"]["params"]["command"] = 'output(\'SUCCESSFULLY MODIFIED SCRIPT!\')']])
	--net.dostring_in('mission', "a_ai_task(\"scriptman\", 1)")
	-- net.log('mizstr and mizerr')
	-- net.log(mizstr)
	-- net.log(mizerr)
	------------------------------------------------------------------------------------------------
	--NEXT: see what happens if I make a phony group with a script action.
	
	
	
	---------WORKS!  Trigger function modification.---------------------
	-- local mizstr, mizerr = net.dostring_in('mission', 'mission["trig"]["actions"][1] = function () net.log(\'modified the trigger!!!\') end')
	-- net.log('mizstr and mizerr')
	-- net.log(mizstr)
	-- net.log(mizerr)
	---------------------------------------------------

end


function slmod.onProcessTest2()  -- called every few secs (according to variable in SlmodCallbacks)

	-- local teststring = [[START "C:\Program Files\Eagle Dynamics\DCS World\bin\luarun.exe" "]] .. [[C:\Program Files\Eagle Dynamics\DCS World\test.lua]] .. [["]] .. '\n' .. "pause"

	-- os.execute(teststring)
end


function slmod.create_ReturnWeapons()

	local ReturnWeapons_string = [=======[function ReturnWeapons()
	local units = LoGetWorldObjects()
	local weapons = {}
	for unit_id, unit_tbl in pairs(units) do
		if not unit_tbl.GroupName then -- maybe a missile?
			weapons[unit_id] = unit_tbl
		end
	end
	return slmod.serialize('weapons', weapons)
end]=======]

	-- REPLACE WITH LOAD_IN_EXPORT
	local success, load_success = net.dostring_in('export', ReturnWeapons_string)
	net.log(success)
	--Keep re-trying to load until successful
	if load_success == false then
		net.log('unable to load into export')
		slmod.schedule_dostring_in('net', 'slmod.create_ReturnWeapons()', DCS.getModelTime() + 0.1)
	else
		net.log('successfully loaded ReturnWeapons function')	
	end

end

----------------------------------------------------------------
-- test functions
function slmod.deactUnit(unitname)
	local deactunit = slmod.getUnitByName(unitname)
	if deactunit then
		net.dostring_in('server', 'Unit.destroy(' .. tostring(deactunit.id) .. ')')
	end
end

function slmod.getBallisticsFromExport()
	local retstr, err = net.dostring_in('export', "return slmod.serialize('ballistics', LoGetWorldObjects('ballistic'), '')")
	slmod.info('trying to output ballistics')
	if err then
		local f = io.open(lfs.writedir() .. [[Logs\]] .. 'exportballistics.txt', 'w')
		f:write(retstr)
		f:close()	
		f = nil
		slmod.info('file made')
	else
		slmod.warning('unable to output, reason: ' .. retstr)
	end
end


--Harvest CLSIDs function, not optimized, just for one-time harvesting of weapon CLSIDs
function slmod.makeCLSIDsTbl()
	local CLSIDs_fnc_str = 	[[do
		local s = 'CLSIDs = {\n'
		for CLSID, Wpn in pairs(db.Weapons.ByCLSID) do
			s = s .. string.format('%q', CLSID) .. ',\n'
		end
		s = s .. '}'
		local fdir = lfs.writedir() .. '/Logs/CLSIDs.txt'
		local f = io.open(fdir, 'w')
		f:write(s)
		f:close()
	end]]
	
	local str, err = net.dostring_in('server', CLSIDs_fnc_str)
	net.log('slmod.makeCLSIDsTbl result:')
	net.log(str)
	net.log(err)
end

function slmod.getWeaponsFromExport()
	local retstr, err = net.dostring_in('export', "return ReturnWeapons()")
	net.log('trying to output weapons')
	if err then
		local f = io.open(lfs.writedir() .. [[Logs\]] .. 'exportweapons.txt', 'w')
		f:write(retstr)
		f:close()	
		f = nil
		net.log('file made')
	else
		net.log('unable to output, reason: ' .. retstr)
	end
end

slmod.info('SlmodTests.lua loaded.')