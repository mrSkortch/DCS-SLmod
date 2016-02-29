-- Slmod PingCheck
---- autokicks players with a high píng
 
slmod = slmod or {}
do
    slmod.pingCheck = {}
    slmod.pingCheck.clients = {}
    slmod.pingCheck.config = slmod.config.pingcheck_conf
    slmod.pingCheck.lastCheckTime = 0
 
    local function getClients()
        -- check for disconnected clients
        for id, client in pairs(slmod.pingCheck.clients) do
            if slmod.clients[id] == nil then
                slmod.pingCheck.clients[id] = nil
            end
        end
 
        -- get currently connected clients
        for id, client in pairs(slmod.clients) do
            if slmod.pingCheck.clients[id] == nil then
                local newClient = {}
                newClient['id'] = id
                newClient['name'] = net.get_player_info(id, 'name')
                newClient['ping'] = net.get_player_info(id, 'ping')
                newClient['avgPing'] = 0
                newClient['ucid'] = net.get_player_info(id, 'ucid')
                newClient['warnings'] = 0
                newClient['lastWarnTime'] = 0
                slmod.pingCheck.clients[newClient.id] = newClient
            end
        end
    end
 
    --- warns and eventually kicks a player if his ping is too high
    local function warnClient(id)
        local client = slmod.pingCheck.clients[id]
        local show_scope = {}
        show_scope["clients"] = {id}
 
        -- get ping/warning limit configuration
        local maxPing = slmod.pingCheck.config.max_ping
        local warnLimit = slmod.pingCheck.config.warning_limit
 
        -- set warning count
        client.warnings = client.warnings + 1
 
        if client.warnings > warnLimit then
            net.kick(client.id, "Your ping is too high (".. client.avgPing ..", max: ".. maxPing ..")")
            kickMsg = "Player ".. client.name .." got kicked for a too high ping (current: ".. client.ping ..", average: ".. client.avgPing ..", max: ".. maxPing ..")"
            slmod.info(kickMsg)
            slmod.scopeMsg(kickMsg, 10, 'chat', nil)
        else
            slmod.scopeMsg("Your ping is too high (current: ".. client.ping ..", average: ".. client.avgPing ..", max: ".. maxPing ..")", 10, 'chat', show_scope)
            slmod.scopeMsg("Warning ".. client.warnings .."/".. warnLimit .." before getting kicked", 10, 'chat', show_scope)
        end
 
        client.lastWarnTime = DCS.getModelTime()
    end
 
    -- gets called every simulation frame
    function slmod.pingCheck.heartbeat()
        local doCheck = false
 
       
        -- check if elapsed time since last check is > 10 secs
        if DCS.getModelTime() - slmod.pingCheck.lastCheckTime > slmod.pingCheck.config.wait_time then
            slmod.pingCheck.lastCheckTime = DCS.getModelTime()
            doCheck = true
        end
 
        -- dont check if pingCheck is disabled
        if slmod.pingCheck.config.enabled == false then
            doCheck = false
        end
 
        if doCheck == false then
            return
        end
 
        -- get clients and check ping values
        getClients()
        for id, client in pairs(slmod.pingCheck.clients) do
            local curPing = net.get_player_info(id, 'ping')
           
            client.avgPing = math.floor((client.ping + curPing + client.avgPing)/3)
            client.ping = curPing
 
            local warnRepeatTime = slmod.pingCheck.config.warning_repeat_time
 
            -- check client's ping and warn if the repeat time has elapsed
            if (client.avgPing > slmod.pingCheck.config.max_ping) and (DCS.getModelTime() - client.lastWarnTime > warnRepeatTime) then
                warnClient(client.id)
            elseif (client.avgPing < slmod.pingCheck.config.max_ping) then
                client.warnings = 0
            end
        end
    end
end
slmod.info('SlmodPingCheck.lua loaded.')