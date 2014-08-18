-- Server hooks
module('server', package.seeall)

-- do not load real gettext here
-- _ only marks strings for translation
local _ = function(msg) return msg end

local log

local names = {}

local function log_write(str)
	net.log(str)
	if log then log:write(os.date("%c") .. " : " .. str .. "\n") end
end

local function unit_type(unit) return net.get_unit_property(unit, 4) or "" end

local function side_name(side)
	if side == 0 then return "Spectators"
	elseif side == 1 then return "Red"
	else return "Blue" end
end

function on_net_start()
	--log = io.open(lfs.writedir() .. "Logs/net-server-"..os.date("%Y%m%d-%H%M%S")..".log", "w")
	log = io.open(lfs.writedir() .. "Logs/net-server.log", "w")
	log_write("Server started")

	names = {}
	names[net.get_name(1)] = 1
end

function on_mission(filename)
	--already reported
	--log_write("Loaded mission ", filename)
	-- parse available slots
	local serializer = [[
	    serialize = function(val)
	        if type(val)=='number' or type(val)=='boolean' then
				return tostring(val)
			elseif type(val)=='string' then
				return string.format("%q", val)
	        elseif type(val)=='table' then
				local k,v
				local str = '{'
				for k,v in pairs(val) do
					str=str..'['..serialize(k)..']='..serialize(v)..','
				end
				str = str..'}'
				return str
	        end
			return 'nil'
	    end
	]]
	-- load serializer into mission env
	net.dostring_in('mission', serializer)
	
	-- parse available slots
	local slot_parser = [[
	    local side_parser = function(side)
			local i,v
			local slots = {}
			for i,v in ipairs(side) do
				local u = { unit_id = v.unitId, type = v.type, onboard_num = v.onboard_num }
				local group = v.group
				if group then
					u.group_name = group.name
					u.group_task = group.task
					u.country_name = group.country.name
				end
				table.insert(slots, u)
			end
			return slots
	    end
	    local res = { red = side_parser(db.clients.red), blue = side_parser(db.clients.blue) }
	    return serialize(res)
	]]
	local val, res = net.dostring_in('mission', slot_parser)
	--net.log(string.format("%s: (%s) %q", 'mission', tostring(res), val))
	if res then
		local t = loadstring('return '..val)
		game.slots = t()
	else
		game.slots = {}
	end
end

function on_net_stop()
	log_write("Server stopped")
	if log then
		log:close()
		log = nil
	end
	names = {}
end

function on_process()
end

function on_connect(id, addr, port, name, ucid)
--[[ banning example
	if banned_hosts and banned_hosts[addr] then
		-- extend the ban
		--banned_hosts[addr] = os.time()
		return "Banned by IP", false
	end
	if banned_names and banned_names[name] then
		-- extend the ban
		--banned_names[name] = os.time()
		return "Banned by name", false
	end
	if banned_serials and banned_serials[ucid] then
		-- extend the ban
		--banned_names[name] = os.time()
		return "Banned by UniqueClientID", false
	end
]]

	-- write to log
	log_write(string.format("Connected client: id = [%d], addr = %s:%d, name = %q, ucid = %q",
		id, addr, port, name, ucid))
	net.recv_chat(string.format("Connected client: id = [%d], addr = %s:%d, name = %q, ucid = %q", id, addr, port, name, ucid))

	if names[name] then
		return _("Please, provide a unique nickname."), false
	end

	names[name] = id

	return true
end

function on_disconnect(id, err)
	local n = net.get_name(id)
	if names[n] then
		names[n] = nil
	end
	log_write(string.format("Disconnected client [%d] %q", id, n or ""))
end

--
function on_set_name(id, new_name)
	-- check against ban list
	--if banned_names[new_name] then
	--	kick(id, "banned name")
	--end
	old_name = net.get_name(id)
	if names[new_name] then
		log_write(string.format("Client [%d] %q tried to changed name to %q", id, old_name, new_name))
		return old_name
	end
	names[old_name] = nil
	names[new_name] = id
	log_write(string.format("Client [%d] %q changed name to %q", id, old_name, new_name))
	return name
end

function on_set_unit(id, side, unit)
	name = net.get_name(id)
	if unit ~= "" then
		msg = string.format("Client [%d] %q joined %s in %q(%s)", id, name, side_name(side), unit_type(unit), unit)
	else
		msg = string.format("Client [%d] %q joined %s", id, name, side_name(side))
	end
	log_write(msg)
	return true
end

function on_chat(id, msg, all)
	if msg=="/mybad" then
		return string.format("I (%d, %q) have made a screenshot at %f", id, net.get_name(id), net.get_model_time())
	elseif string.sub(msg, 1, 1) == '/' then
		net.recv_chat("got command: "..msg, 0)
		return
	end
	return msg
end


--------------------------------------------------
-- load event callbacks

dofile('./Scripts/net/events.lua')
--------------------------------------------------
-- load Slmod
--[[]]
do
	local loadVersion = '7_3'
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodConfig.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodUtils.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodEvents.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodUnits.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodMenu.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodConvMenu.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodPTSMenu.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodPOSMenu.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodAdminMenu.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodStats.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodAutoAdmin.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodLibs.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodDebugger.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodMOTD.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodHelp.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodCallbacks.lua')
	dofile(lfs.writedir() .. 'Scripts/net/Slmodv'.. loadVersion .. '/SlmodTests.lua')
end
--]]
