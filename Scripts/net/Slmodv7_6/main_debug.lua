net.log('Loading main.lua')
-- insert this script before you use dofile
function dofile(fname) -- replaces the old dofile with a new version that will actually report errors.
	local f = io.open(fname, 'r')
	if f then
		local fs = f:read('*all')
		if fs then
			local func, err = loadstring(fs)
			if func then
				local bool, err = pcall(func)
				if not bool then
					net.log('dofile error: runtime error: ' .. err)
				else
					net.log('Successfully loaded ' .. fname)
				end
			else
				net.log('dofile error: syntax error in file "' .. fname .. '", error: ' .. err) -- if the loadstring failed, err is the error message.
			end
		else
			net.log('dofile error: unable to read file "' .. fname .. '"!') -- I donno if this would ever happen...
		end
	else
		net.log('dofile error: unable to open file "' .. fname .. '" for reading!')
	end
end


fontsPath  = './MissionEditor/themes/fonts/'
imagesPath = './MissionEditor/themes/main/images/'
imageSearchPath = {imagesPath}
skinPath = './dxgui/skins/skinME/'
mainPath = 'MissionEditor/'
simPath  = './'

guiBindPath = './dxgui/old_loader/?.lua;' .. 
              './dxgui/ThemeConverter/?.lua;' ..
              './dxgui/bind/?.lua;' .. 
              './dxgui/skins/skinME/?.lua;' .. 
              './dxgui/skins/common/?.lua;'

package.path = ''
    .. guiBindPath
--    .. '.\\MissionEditor\\?.lua;'
    .. '.\\MissionEditor\\themes\\main\\?.lua;'
--    .. '.\\MissionEditor\\modules\\?.lua;'
    .. '.\\Scripts\\?.lua;'
    .. '.\\LuaSerializer\\?.lua;'
    .. '.\\LuaSocket\\?.lua;'


gettext = require("i_18n")
lfs = require("lfs")
if not lfs.writedir then lfs.writedir = function() return "./" end end

log = log or function(str) net.log(str) end
-- loaded once on start

local scripts_dir = "./Scripts/net/"
local temp_dir = lfs.writedir() .. "Temp/"
local config_dir = lfs.writedir() .. "Config/"
local config_file = config_dir .. "network.cfg"

package.path = scripts_dir..'?.lua;'..package.path

dofile(scripts_dir..'api.lua')

game = {}
server = require('server')
client = require('client')

-- load config file
local function merge(dest, src)
    local k,v
	for k,v in pairs(src) do
		local d = dest[k]
		if k == "integrity_check" then
			dest[k] = v
		elseif type(v)=="table" and type(d)=="table" and v[1] == nil then
			merge(d, v)
		else
			dest[k] = v
		end
	end
end

local function load_env(filename, env)
	local file, err = loadfile(filename)
	local res = {false}
	if file then
		if env then setfenv(file, env) end
		res = {pcall(file)}
	end
	local msg
	if res[1] then msg = "OK" else msg = err end
	log("loading "..filename.." : "..msg)
	return unpack(res)
end

-- load config
config = {}
load_env("./Scripts/net/default.cfg", config)
local new_config = {}
if load_env(config_file, new_config) then
    merge(config, new_config)
end
config.master_login = nil
config.master_password = nil

-- bind config
server.config = config.server
client.config = config.client

-- connection speed
connection_types = {}

function set_connection_type(idx)
	if idx < 1 then return end
	local t = connection_types[idx]
	if type(t)=="table" then config.connection = t end
end

function get_connection_speed()
	return config.connection[2], config.connection[3]
end

-- load connection types
local ok, default_conn
ok, connection_types, default_conn = load_env(scripts_dir..'net_types.lua')
if not ok then 
	connection_types = {}
end
log("default_conn is "..default_conn)
if not config.connection and default_conn then
	set_connection_type(default_conn)
end



dofile(scripts_dir..'save.lua')
--dofile(scripts_dir..'cleanup.lua')
function cleanup_temp(temp_dir) end

-- clean temp files on start
cleanup_temp(temp_dir)

-- called on exit
function on_exit()
	cleanup_temp(temp_dir)

	if config.do_not_save then
		return nil
	else
		local vlt
		if vault then
			vlt = ""
			save(function(str) vlt = vlt .. str end, vault)
		end
		local cfg = ""
		save(function(str) cfg = cfg .. str end, config)
		return vlt, cfg
	end
end

--- TEST
--[[
function test_exec(state, str)
	local val, res = net.dostring_in(state, "return " .. str)
	net.log(string.format("%s: (%s) %q", state, tostring(res), val))
end

test_exec("export", "LoGetModelTime()")
test_exec("config", "cmdline")
]]

function ui_start()
	local uiLobby = require('net.uiLobby')
	uiLobby.show(true)
end
