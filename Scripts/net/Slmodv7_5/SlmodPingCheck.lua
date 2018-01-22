-- Slmod PingCheck
---- autokicks players with a high píng
 
slmod = slmod or {}
do
    slmod.pingCheck = {}
    local pingCheckConfig = slmod.config.pingcheck_conf
    local lastCheck = 0
    local pingCheckClients = {}
    
    local exemptList = slmod.config.autoAdmin.exemptionList
    
    function slmod.loadPingExemptList()
        if slmod.exemptAll then -- append external exemption all list to the local one
            for id, data in pairs(slmod.exemptAll) do
                if not exemptList[id] then
                    exemptList[id] = data
                end
            end
        end
        
        if slmod.exemptPing then
            for id, data in pairs(slmod.exemptPing) do -- check if anyone is only on the exempt autoAdmin list
                if not exemptList[id] then
                    exemptList[id] = data
                end
            end
        end
    end
    function slmod.pingCheck.addClient(id)
        local ucid = net.get_player_info(id, 'ucid')
        if slmod.isAdmin(ucid) == false and (not exemptList[ucid]) and (not (id == 1)) then -- cant be an admin or on the exemption list
            if pingCheckClients[id] == nil then

                local newClient = {}
                newClient['id'] = id
                newClient['name'] = net.get_player_info(id, 'name')
                newClient['ping'] = net.get_player_info(id, 'ping')
                newClient['avgPing'] = 0
                newClient['ucid'] = ucid
                newClient['warnings'] = 0
                newClient['lastWarnTime'] = 0
                pingCheckClients[newClient.id] = newClient
            end
        end

        return
    end
    local function getClients()
        -- check for disconnected clients
        local count = 0
        for id, client in pairs(pingCheckClients) do
            if slmod.clients[id] == nil then
                slmod.info('remove client')
                pingCheckClients[id] = nil
            else
                count = count + 1
            end
        end
        return count
    end
 
    --- warns and eventually kicks a player if his ping is too high
    local function warnClient(id)
        local client = pingCheckClients[id]
        local show_scope = {}
        show_scope["clients"] = {id}
 
        -- get ping/warning limit configuration
        local maxPing = pingCheckConfig.max_ping
        local warnLimit = pingCheckConfig.warning_limit
 
        -- set warning count
        client.warnings = client.warnings + 1
 
        if client.warnings > warnLimit then
            net.kick(client.id, "Your ping is too high (".. client.avgPing ..", max: ".. maxPing ..")")
            kickMsg = "Player ".. client.name .." got kicked for a too high ping (current: ".. client.ping ..", average: ".. client.avgPing ..", max: ".. maxPing ..")"
            slmod.info(kickMsg)

            if pingCheckConfig.warning_msg then
                slmod.scopeMsg(kickMsg, 10, 'chat', nil)
            end
        else
            if pingCheckConfig.warning_msg then
                slmod.scopeMsg("Your ping is too high (current: ".. client.ping ..", average: ".. client.avgPing ..", max: ".. maxPing ..")", 10, 'chat', show_scope)
                slmod.scopeMsg("Warning ".. client.warnings .."/".. warnLimit .." before getting kicked", 10, 'chat', show_scope)
            end
        end
 
        client.lastWarnTime = DCS.getModelTime()
    end
 
    -- gets called every simulation frame
    function slmod.pingCheck.heartbeat()
        local doCheck = false
 
       
        -- check if elapsed time since last check is > 10 secs
        if DCS.getModelTime() - lastCheck > pingCheckConfig.wait_time then
            lastCheck = DCS.getModelTime()
            doCheck = true
        end
 
        -- dont check if pingCheck is disabled
        if pingCheckConfig.enabled == false then
            doCheck = false
        end
 
        if doCheck == false then
            return
        end
        -- get clients and check ping values
        
        if getClients() > 0 then
            for id, client in pairs(pingCheckClients) do
                local curPing = net.get_player_info(id, 'ping')
                client.avgPing = math.floor((client.ping + curPing + client.avgPing)/3)
                client.ping = curPing
     
                local warnRepeatTime = pingCheckConfig.warning_repeat_time
     
                -- check client's ping and warn if the repeat time has elapsed
                if (client.avgPing > pingCheckConfig.max_ping) and (DCS.getModelTime() - client.lastWarnTime > warnRepeatTime) then
                    warnClient(client.id)
                elseif (client.avgPing < pingCheckConfig.max_ping) then
                    client.warnings = 0
                end
            end
        end
        return
    end
end
slmod.info('SlmodPingCheck.lua loaded.')