do
    local config = slmod.config.voteConfig
    local anyAdmin = false
    local mStats = slmod.stats.getMetaStats()
    local voteStatus = {}
    voteStatus.active = false
    voteStatus.timeout = config.voteTimeout or 1200
    voteStatus.minVoteTime = config.minVoteTime or 60
    voteStatus.maxVoteTime = config.maxVoteTime or 180
    voteStatus.lastVoteEnd = 0
    voteStatus.startedAt = 0
    voteStatus.lastMsg = 0
    
    if voteStatus.maxVoteTime < voteStatus.minVoteTime then
        slmod.info('Vote min time is greater than vote max time. Setting both to same value')
        voteStatus.minVoteTime = voteStatus.maxVoteTime
    end

    local anyVoteActive = false
    local rtvStatus = {}
    rtvStatus.active = false
    rtvStatus.voteTime = config.rtvVoteTime or 600
    rtvStatus.timeout = config.rtvVoteTimeout or 1200
    rtvStatus.lastVoteEnd = 0
    rtvStatus.startedAt = 0
    rtvStatus.level = config.rtvLevel or 0.5
        

    local voteTbl = {}
    local rtvTbl = {}
    -- in case of syntax error
    local mapStrings = slmod.config.mapStrings or { 
        ['Caucasus'] = 'BS',
        ['Nevada'] = 'NV',
        ['Normandy'] = 'NO',
        ['PersianGulf'] = 'PG',
    }
    
    local useRule = 1
    
    local function countVotes(tbl)
        local keepList = {}
        anyAdmin = false
        
        for id, clientData in pairs(slmod.clients) do
            if tbl[clientData.ucid] then
                keepList[clientData.ucid] = true
            end
            if slmod.isAdmin(clientData.ucid) then
                anyAdmin = true
            end
        end
        local count = 0
        local tally = {}
        for ucid, val in pairs(tbl) do -- clear any disconnected clients
            if keepList[ucid] then
                count = count + 1
                if not tally[val] then
                    tally[val] = 0
                end
                tally[val] = tally[val] + 1
            end
        end
        return count, tally
    end
    
    local function rtvReset(result)
        rtvStatus.lastVoteEnd = os.time()
        rtvStatus.active = false
        if result then
            voteStatus.active = true
            voteStatus.startedAt = os.time()
            
        else
            anyVoteActive = false
        end
        rtvTbl = {} -- clear tbl
        return
    end
    
    local function voteReset(result)
        if result then
            voteStatus.active = true
            voteStatus.startedAt = os.time()
            anyVoteActive = true
        else
            anyVoteActive = false
            voteStatus.active = false
            voteStatus.lastVoteEnd = os.time()
        end
        
        voteTbl = {} -- clear tbl
        return
    end

    local function getVoteTimeRemainingInMin(r)
        return string.format('%.2f', (r/60))
    end
    local function getEndIfCondition(totalVotes, endIf)
        if endIf and type(endIf) == 'number' then
            if endIf < 1 and endIf > 0 then
                 return endIf * slmod.num_clients              
            elseif endIf >= 1 then
                 return endIf
            end
        end
        return slmod.num_clients -- return the number of clients on a server
    end
    local function voteClock()
        if anyVoteActive == true then
            slmod.scheduleFunctionByRt(voteClock, {}, DCS.getRealTime() + 5)
        end

        if rtvStatus and rtvStatus.startedAt > 0 and rtvStatus.active == true then -- there is an RTV vote currently going on
            local currentVote = countVotes(rtvTbl)
            
            if currentVote >= slmod.num_clients * rtvStatus.level then
                slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: RTV has been succsseful. Mission vote now starting. Vote will last for: ' .. getVoteTimeRemainingInMin(voteStatus.maxVoteTime) .. ' minutes.'}, DCS.getRealTime() + 0.1)
                rtvReset(true)
                return
            else
                if os.time() > rtvStatus.startedAt + rtvStatus.voteTime then
                    rtvReset()
                    slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: RTV has failed. Will become available again in: ' .. getVoteTimeRemainingInMin(rtvStatus.timeout) .. ' minutes.'}, DCS.getRealTime() + 0.1)
                end
            end
        end
        
        if voteStatus and voteStatus.startedAt > 0 and voteStatus.active == true then
            local totVotes, result = countVotes(voteTbl)
            for i = 1, #config.ruleSets do
                if config.ruleSets[i].rangeMin and config.ruleSets[i].rangeMax then
                    if slmod.num_clients >= config.ruleSets[i].rangeMin and slmod.num_clients <= config.ruleSets[i].rangeMax then
                        useRule = i
                        break
                    end
                end
            end
            local rule = config.ruleSets[useRule]
            if voteStatus.minVoteTime + voteStatus.startedAt < os.time() then
                -- start to tally votes to check for winner
                local leader
                local endCondition = getEndIfCondition(totVotes, rule.endIf)
                for voteFor, voteTally in pairs(result) do
                    if leader == nil then
                        leader = voteFor
                    end
                    if voteTally > result[leader] then
                       leader = voteFor -- current winner
                    end
                end
                -- vote leader is found, now figure out what to do with that information
                if (voteStatus.maxVoteTime + voteStatus.startedAt > os.time() or endCondition >= totVotes) then
                   -- vote time ended or end condition reached
                    local checkVal = result[leader]
                    if checkVal == nil then
                        checkVal = 0
                    end
                    local voteSuccessful = false
                    if rule.use == 'magic' then
                        if rule.val <= checkVal then -- if check val reached the number of votes.
                            voteSuccessful = true
                        end
                    elseif rule.use == 'ratio' then
                        if rule.val <= checkVal * slmod.num_clients then -- if the ratio of clients voted above the rule.val
                            voteSuccessful = true
                        end
                    else -- assumes majority rule
                        voteSuccessful = true
                    end
                    
                    if voteSuccessful == true and leader then 
                        local path
		
                        if slmod.config.admin_tools_mission_folder and type(slmod.config.admin_tools_mission_folder) == 'string' then
                            path = slmod.config.admin_tools_mission_folder
                            if (path:sub(-1) ~= '\\') or (path:sub(-1) ~= '/') then
                                path = path .. '\\'
                            end
                        else
                            path = lfs.writedir() .. [[Slmod\Missions\]]
                        end
                        
                        if anyAdmin == true and config.requireAdminVerifyIfPresent == true and slmod.currentVoteIsAllowed == false then
                            slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: Vote complete. Results must be verified by an admin.'}, DCS.getRealTime() + 0.1)
                        else
                            -- 
                            slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: Vote has been successful! ' .. leader .. ' has won the vote. The server will be switching to it in a moment.', 10, 'both' }, DCS.getRealTime() + 0.1)  -- scheduled so that reply from Slmod appears after your chat message.

                            local nameString = string.gsub(leader, '.miz', '')
                            if mStats.missionStats[nameString] and mStats.missionStats[nameString].totalVoteLoaded then
                                 slmod.stats.changeMetaStatsValue(mStats.missionStats[nameString],'totalVoteLoaded', mStats.missionStats[nameString].totalVoteLoaded + 1)
                            end
                            slmod.scheduleFunctionByRt(net.load_mission, {path .. leader}, DCS.getRealTime() + 10)
                        end
                    else
                        local reason = ''
                        if rule.use == 'magic' then
                            
                        end
                        
                        if leader then 
                            slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: Vote failed. ' .. leader .. ' had the most votes.', config.display_time, config.display_mode}, DCS.getRealTime() + 0.1)
                        else
                            slmod.scheduleFunctionByRt(slmod.scopeMsg, {'Slmod: Vote failed. No votes cast.', config.display_time, config.display_mode}, DCS.getRealTime() + 0.1)
                        end
                    end
                    voteReset()
                end

            end
            if voteStatus.lastMsg == 0 or voteStatus.lastMsg + config.voteReminder < os.time() then
                    voteStatus.lastMsg = os.time()
                    local msg = {}
                    msg[#msg+1] = 'Time Remaining:'
                    msg[#msg+1] = getVoteTimeRemainingInMin(os.time() - voteStatus.startedAt + voteStatus.maxVoteTime)
                    msg[#msg+1] = '\nTotal Votes:'
                    msg[#msg+1] = totVotes
                    if config.hidden == false then
                        msg[#msg+1] = '\nMissions with votes: \n'
                        for mizName, curVotes in pairs(result) do
                            msg[#msg+1] = curVotes
                            msg[#msg+1] = ' votes for : '
                            msg[#msg+1] = mizName
                            msg[#msg+1] = '\n'
                        end
                    end
                    
                     slmod.scheduleFunctionByRt(slmod.scopeMsg, {table.concat(msg), config.display_time, config.display_mode}, DCS.getRealTime() + 0.1)
                end
        end
        
        
    end

    local function showVoteStatus(id)
        -- time remaining
        -- votes needed to winner
        -- current tally
        local msg = {}
        local rule = config.ruleSets[useRule]
        msg[#msg+1] = 'Active Voting Rules: '
        msg[#msg+1] = rule.use
        msg[#msg+1] = '\n '
        
        if anyVoteActive == true then 
            if rtvStatus.active == true then
                msg[#msg+1] = 'RTV Active\n'
                msg[#msg+1] = '\nRTV Time remaining: '
                msg[#msg+1] = getVoteTimeRemainingInMin(rtvStatus.startedAt - os.time() + rtvStatus.voteTime)
                if config.hidden == false then 
                    msg[#msg+1] = '\nRTV Votes Needed: '
                    msg[#msg+1] = slmod.num_clients * rtvStatus.level
                    msg[#msg+1] = '     Current RV Votes: '
                    msg[#msg+1] = countVotes(rtvTbl)
                end
            end
            
            if voteStatus.active == true then 
                msg[#msg+1] = 'Mission Vote Time Remaining: '
                msg[#msg+1] = getVoteTimeRemainingInMin(voteStatus.startedAt - os.time() + voteStatus.maxVoteTime)
                msg[#msg+1] = ' minutes\n' 
                if os.time() > voteStatus.startedAt + voteStatus.minVoteTime then
                    msg[#msg+1] = 'Minimum vote time reached, vote can end early if needed votes reached. \n'
                else
                    msg[#msg+1] = getVoteTimeRemainingInMin(voteStatus.startedAt - os.time() + voteStatus.minVoteTime)
                    msg[#msg+1] = ' minutes until minimum vote time. is reached. \n'
                end

               
                local totVotes, result = countVotes(voteTbl)
                msg[#msg+1] = totVotes
                msg[#msg+1] = ' votes have been cast. \n \n'
                
                if config.hidden == false then 
                    msg[#msg+1] = 'Missions with votes: \n'
                    for mizName, curVotes in pairs(result) do
                        msg[#msg+1] = curVotes
                        msg[#msg+1] = ' votes for : '
                        msg[#msg+1] = mizName
                        msg[#msg+1] = '\n'
                    end
                end
            end
        else
            msg[#msg+1] = 'No Votes Active\n'
            if slmod.config.voteConfig.rtvEnabled then
                msg[#msg+1] = 'RTV is enabled on the server.\n'
                if rtvStatus.startedAt == 0 or rtvStatus.timeout + rtvStatus.lastVoteEnd < os.time() then
                    msg[#msg+1] = 'Type "-rtv" to start a rock the vote.'
                else
                    msg[#msg+1] = 'RTV is on timeout for '
                    msg[#msg+1] = getVoteTimeRemainingInMin(rtvStatus.lastVoteEnd - os.time() + rtvStatus.timeout)
                    msg[#msg+1] = ' more minutes.\n'
                end
            else
                msg[#msg+1] = 'RTV is disabled on the server.\n'
            end
            if slmod.config.voteConfig.enabled then
                msg[#msg+1] = 'Vote is enabled on the server.\n'
                if voteStatus.startedAt == 0 or rtvStatus.timeout + rtvStatus.lastVoteEnd < os.time() then
                    if slmod.config.voteConfig.rtvEnabled then
                        msg[#msg+1] = '"-rtv" is required to start a mission vote.\n'
                    else
                        msg[#msg+1] = 'Type "-vote list" or "-vote restart" to start a vote.'
                    end
                    
                else
                    msg[#msg+1] = 'Vote is on timeout for '
                    msg[#msg+1] = getVoteTimeRemainingInMin(rtvStatus.lastVoteEnd - os.time() + rtvStatus.timeout)
                    msg[#msg+1] = ' more minutes.\n'
                end
            else
                msg[#msg+1] = 'Voting is disabled on the server.\n'
            end
        end
        slmod.scopeMsg(table.concat(msg), 20, 'text', {clients = {id}})
    end

    function slmod.adminStartVote(name)
        slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: Mission Vote has been started by admin: ' .. name}, DCS.getRealTime() + 0.1)
        rtvReset()
        voteReset(true)
      
        voteClock()  
    end
    
    function slmod.adminStopVote(name)
        if anyVoteActive == true then 
            slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: Mission Vote has been stopped by admin: ' .. name}, DCS.getRealTime() + 0.1)
            rtvReset()
            voteReset()
        else
            
        end
    end
    
    function slmod.toggleVote(name)
        if slmod.config.voteConfig.enabled == false then
            slmod.config.voteConfig.enabled = true
            if anyVoteActive == true then 
                 slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. name .. '" has disabled mission voting. Current Voting will be cancelled and reset.'}, DCS.getRealTime() + 0.1)
                 voteReset()
                 rtvReset()
            else
                slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. name .. '" has disabled mission voting.'}, DCS.getRealTime() + 0.1)
            end
        elseif
            slmod.config.voteConfig.enabled == true then 
            slmod.config.voteConfig.enabled = false
            slmod.scheduleFunctionByRt(slmod.basicChat, {'Slmod: admin "' .. name .. '" has enabled mission voting.'}, DCS.getRealTime() + 0.1)
        end
    
    end

    
    local function create_VoteMissionMenuFor(id)  --creates the temporary load mission menu for this client id.
		local path
		
        if slmod.config.admin_tools_mission_folder and type(slmod.config.admin_tools_mission_folder) == 'string' then
			path = slmod.config.admin_tools_mission_folder
			if (path:sub(-1) ~= '\\') or (path:sub(-1) ~= '/') then
				path = path .. '\\'
			end
		else
			path = lfs.writedir() .. [[Slmod\Missions\]]
		end
		-- load mission menu show commands  -- this menu is automatically shown when it is created, but
		local LoadShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-show',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'list',
					required = true,
				}
			}
		}
		
		local LoadItems = {}
		local display_mode = slmod.config.admin_display_mode or 'chat'
		local display_time = slmod.config.admin_display_time or 30
        local voteTimeRemain = 120
        if voteStatus.active == true then
            voteTimeRemain = (voteStatus.maxVoteTime + voteStatus.startedAt) - os.time()
        end
		local VMenu = SlmodMenu.create({showCmds = LoadShowCommands, scope = {clients = {id}}, options = {display_time = display_time, display_mode = display_mode, title = 'Available missions to vote for' .. path .. ' (you have '.. getVoteTimeRemainingInMin(voteTimeRemain) .. ' minutes to make a choice):', privacy = {access = true, show = true}}, items = LoadItems})
		slmod.scheduleFunctionByRt(SlmodMenu.destroy, {VMenu}, DCS.getRealTime() + voteTimeRemain)  --scheduling self-destruct of this menu in two minutes.
		
		local miz_cntr = 1
        for file in lfs.dir(path) do
            if file:sub(-4) == '.miz' then
				local mapName = ''
                local sName = string.gsub(file, '%.miz', '')
                if mStats and mStats.missionStats then
                    if mStats.missionStats[sName] and  mStats.missionStats[sName].voteEnabled then
                        if mapStrings[mStats.missionStats[sName].map] then
                            mapName = mapStrings[mStats.missionStats[sName].map]
                        end
                        local LoadVars = {}
                        LoadVars.menu = VMenu
                        LoadVars.description = 'Mission ' .. tostring(miz_cntr) .. ' -' .. mapName .. ': "' .. file .. '", say in chat "-vote ' .. tostring(miz_cntr) .. '" to vote for this mission.'
                        LoadVars.active = true
                        LoadVars.filename = file
                        LoadVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
                        LoadVars.selCmds = {
                                [1] = {
                                    [1] = { 
                                        type = 'word', 
                                        text = '-vote',
                                        required = true
                                    }, 
                                    [2] = { 
                                        type = 'word',
                                        text = tostring(miz_cntr),
                                        required = true
                                    }
                                }
                            } 
                        LoadVars.onSelect = function(self, vars, client_id)
                            if slmod.config.voteConfig.enabled == true then
                                if not client_id then
                                    client_id = vars
                                end

                                if slmod.clients[client_id] then
                                   voteTbl[slmod.clients[client_id].ucid] = self.filename
                                    
                                    if config.hidden then
                                        slmod.scheduleFunctionByRt(slmod.scopeMsg,{'Slmod: Vote Successful for: ' .. self.filename, 5, 'chat', {clients = {id}}}, DCS.getRealTime() + .1) 
                                    else
                                        slmod.scheduleFunctionByRt(slmod.basicChat, {slmod.clients[client_id].name .. ' has voted for: ' .. self.filename}, DCS.getRealTime() + .1)
                                    end
                                  
            
                                end
                            end
                        end
                        LoadItems[miz_cntr] = SlmodMenuItem.create(LoadVars) 
                        miz_cntr = miz_cntr + 1
                    end
                end
                
			end
		end
		
		local ShowAgainVars = {}
		ShowAgainVars.menu = VMenu
		ShowAgainVars.description = 'Say "-show list" in chat to view this menu again.'
		ShowAgainVars.active = true
		ShowAgainVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
		ShowAgainVars.selCmds = {} 
		ShowAgainVars.onSelect = function() end
		LoadItems[miz_cntr] = SlmodMenuItem.create(ShowAgainVars) 
		
		VMenu:show()
	end
    
    function slmod.create_SlmodVoteMenu()
		-- stats menu show commands
        mStats = slmod.stats.getMetaStats() -- reload meta stats
		local voteShowCommands = {
			[1] = {
				[1] = {
					type = 'word',
					text = '-vote',
					required = true,
				},
				[2] = {
					type = 'word',
					text = 'help',
					required = false,
				}
			}
		}
		
		local voteItems = {}
		
		-- create the menu.
		SlmodVoteMenu = SlmodMenu.create{ 
			showCmds = voteShowCommands, 
			scope = {
				coa = 'all'
			}, 
			options = {
				display_time = 30, 
				display_mode = 'text', 
				title = 'SlmodVote Multiplayer Voting System', 
				privacy = {access = true, show = true}
			}, 
			items = voteItems,

		}

        if config.rtvEnabled then  -- if rtv enabled add the rtv thingy
            local rtvVars = {}
            rtvVars.menu = SlmodVoteMenu
            rtvVars.description = 'Type "-rtv" to call for a mission vote. If enough players call for it, a vote mission will commence.'
            rtvVars.active = true
            rtvVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
            rtvVars.selCmds = {
                    [1] = {
                        [1] = { 
                            type = 'word', 
                            text = '-rtv',
                            required = true
                        }, 
                    },
                } 
            rtvVars.onSelect = function(self, vars, client_id)
                if slmod.config.voteConfig.rtvEnabled == true and slmod.config.voteConfig.enabled == true then
                    if not client_id then
                        client_id = vars
                    end
                    if config.rtvEnabled then -- rtv enabled
                        if rtvStatus.active ~= true then -- not active 
                            if rtvStatus.lastVoteEnd == 0 or os.time() > rtvStatus.lastVoteEnd + rtvStatus.timeout then
                                rtvStatus.active = true
                                rtvStatus.startedAt = os.time()
                            else
                                slmod.scopeMsg('RTV is currently on cooldown. Please wait ' .. getVoteTimeRemainingInMin(rtvStatus.startedAt - os.time() + rtvStatus.voteTime) ..' minutes until RTV is available again.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                                return
                            end
                        end
                        if anyVoteActive == false then
                            anyVoteActive = true
                            voteClock()
                        end
                        -- break out before this if the RTV is inactive
                        if slmod.clients[vars] and slmod.clients[vars].ucid then
                            rtvTbl[slmod.clients[vars].ucid] = tostring(true)
                            if config.hidden then
                                slmod.scopeMsg('You have voted to rock the vote.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                            else
                                slmod.scheduleFunctionByRt(slmod.basicChat, {slmod.clients[vars].name .. ' has voted to rock the vote.'}, DCS.getRealTime() + 0.1)
                            end
                        end
                    else
                        slmod.scopeMsg('RTV is disabled on the server.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                    end
                end
            end
            
            voteItems[#voteItems + 1] = SlmodMenuItem.create(rtvVars)  -- add the item into the items table.
        end
   

        local rtvRemoveVars = {}
        rtvRemoveVars.menu = SlmodVoteMenu
        rtvRemoveVars.description = 'Type "-rtv remove" to remove your vote for RTV'
        rtvRemoveVars.active = true
        rtvRemoveVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
        rtvRemoveVars.selCmds = {
                [1] = {
                    [1] = { 
                        type = 'word', 
                        text = '-rtv',
                        required = true,
                    },
                    [2] = { 
                        type = 'word', 
                        text = 'remove',
                        required = true,
                    }, 
                },
            } 
        rtvRemoveVars.onSelect = function(self, vars, client_id)
             if slmod.config.voteConfig.rtvEnabled == true  then
                if not client_id then
                    client_id = vars
                end
                if config.rtvEnabled then -- rtv enabled
                    if rtvStatus.active == true then 
                        if slmod.clients[vars] then
                            if rtvTbl[slmod.clients[vars].ucid] then
                                rtvTbl[slmod.clients[vars].ucid] = nil
                                slmod.scopeMsg('Your rtv vote has been removed', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                            else
                                slmod.scopeMsg('You never exercised your civic duty to vote in the first place.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                            end
                        end
                    else
                    slmod.scopeMsg('RTV is currently on cooldown. Please wait ' .. getVoteTimeRemainingInMin(rtvStatus.startedAt - os.time() + rtvStatus.voteTime) ..' minutes until RTV is available again.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})  
                    end
                else
                    slmod.scopeMsg('RTV is disabled on the server.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                end
            end
        end
            
        voteItems[#voteItems + 1] = SlmodMenuItem.create(rtvRemoveVars)  -- add the item into the items table.
        
        

        local vList = {}
        vList.menu = SlmodVoteMenu
        vList.description = 'Type "-vote list" to call for a mission vote. If enough players call for it, a vote mission will commence.'
        vList.active = true
        vList.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
        vList.selCmds = {
                [1] = {
                    [1] = { 
                        type = 'word', 
                        text = '-vote',
                        required = true,
                    },
                    [2] = { 
                        type = 'word',
                        text = 'list',
                        required = true,
                    },                        
                },
            } 
        vList.onSelect = function(self, vars, client_id)
            if slmod.config.voteConfig.enabled == true then
                if voteStatus.active == true then 
                    if not client_id then
                        client_id = vars
                    end
                    
                    create_VoteMissionMenuFor(client_id)
                else
                    slmod.scopeMsg('Voting is current inactive.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                end
            else 
                 slmod.scopeMsg('Voting is disabled on the server.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
            end
        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(vList)

        local restartVars = {}
        restartVars.menu = SlmodVoteMenu
        restartVars.description = 'Type "-vote restart" to vote for a mission restart. '
        restartVars.active = true
        restartVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
        restartVars.selCmds = {
                [1] = {
                    [1] = { 
                        type = 'word', 
                        text = '-vote',
                        required = true
                    },
                    [2] = { 
                        type = 'word', 
                        text = 'restart',
                        required = true
                    },                        
                },
            } 
        restartVars.onSelect = function(self, vars, client_id)
            if slmod.config.voteConfig.enabled == true then
                if not client_id then
                    client_id = vars
                end
                if mStats.missionStats[slmod.current_mission] and mStats.missionStats[slmod.current_mission].voteEnabled == true then
                    slmod.scopeMsg('You have voted to restart the mission.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                    voteTbl[slmod.clients[client_id].ucid] = slmod.current_mission .. '.miz'
                else    
                    slmod.scopeMsg('This mission has voting disabled for it. Sorry.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                end
            else 
                 slmod.scopeMsg('Voting is disabled on the server.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
            end
        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(restartVars)

        local voteRemoveVars = {}
        voteRemoveVars.menu = SlmodVoteMenu
        voteRemoveVars.description = 'Type "-vote remove" to manually remove your vote.'
        voteRemoveVars.active = true
        voteRemoveVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
        voteRemoveVars.selCmds = {
                [1] = {
                    [1] = { 
                        type = 'word', 
                        text = '-vote',
                        required = true
                    },
                    [2] = { 
                        type = 'word', 
                        text = 'remove',
                        required = true
                    },                        
                },
            } 
        voteRemoveVars.onSelect = function(self, vars, client_id)
            if slmod.config.voteConfig.enabled == true then
                 if voteStatus.active == true then 
                    if not client_id then
                        client_id = vars
                    end
                    if slmod.clients[client_id] then
                        if voteTbl[slmod.clients[client_id].ucid] then
                            slmod.scopeMsg('Your vote has been removed', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                            voteTbl[slmod.clients[client_id].ucid] = nil
                        else
                            slmod.scopeMsg('No vote found. Nothing has been removed.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                        end
                    end
                end
            else 
                 slmod.scopeMsg('Voting is disabled on the server.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
            end
        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(voteRemoveVars)

        local voteStatusVars = {}
        voteStatusVars.menu = SlmodVoteMenu
        voteStatusVars.description = 'Type "-vote status" to be updated of the current vote status.'
        voteStatusVars.active = true
        voteStatusVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
        voteStatusVars.selCmds = {
                [1] = {
                    [1] = { 
                        type = 'word', 
                        text = '-vote',
                        required = true
                    },
                    [2] = { 
                        type = 'word', 
                        text = 'status',
                        required = true
                    },                        
                },
            } 
        voteStatusVars.onSelect = function(self, vars, client_id)
            if slmod.config.voteConfig.enabled == true then
                if not client_id then
                    client_id = vars
                end
                if config.hidden then
                    if slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
                        showVoteStatus(client_id)
                    else
                        slmod.scopeMsg('Sorry vote status is hidden. Time remaining: ' .. ''.. ' You haved for: ' .. '', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
                    end
                else

                    showVoteStatus(client_id)
                end
            else 
                 slmod.scopeMsg('Voting is disabled on the server.', self.options.display_time/2, self.options.display_mode, {clients = {client_id}})
            end
        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(voteStatusVars)
   
    end

end
slmod.info('SlmodVote.lua loaded.')