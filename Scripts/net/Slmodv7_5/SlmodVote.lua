do
    --[[
    Voting How should it work...
    
    
    List missions with prefix [map] Name
    
    If RTV enabled...
        Players must RTV
    
    
    
    needed commands...
    admin: vote stop
    admin: vote start
    admin: vote toggle
    admin: vote allow
    
    user: rtv
    user: rtv remove  --- removes users vote from RTV
    user: vote list
    user: vote mission id
    user: vote restart
    user: vote remove
    ]]
    local config = slmod.config.voteConfig
    
    local voteStatus = {
        active = false
        timeout = config.voteTimeout or 1200
        minVoteTime = config.minVoteTime or 60
        maxVoteTime = config.maxVoteTime or 180
        lastVoteEnd = 0
        startedAt = 0
    }
    local anyVoteActive = false
    local rtvStatus = {
        active = false
        time = config.rtvVoteTime or 600
        timeout = config.rtvVoteTimeout or 1200
        lastVoteEnd = 0
        startedAt = 0
        level = config.rtvLevel or 0.5
        
    }
    local voteTbl = {}
    local rtvTbl = {}
    -- in case of syntax error
    local mapStrings = slmod.config.mapStrings or { 
        ['Caucasus'] = 'BS',
        ['Nevada'] = 'NV',
        ['Normandy'] = 'NO',
        ['PersianGulf'] = 'PG',
    }
    
    
    local function countVotes(tbl)
        local keepList = {}
        for id, clientData in pairs(slmod.clients) do
            if tbl[clientData.ucid] then
                keepList[clientData.ucid] = true
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
        rtvStatus.active = false
        rtvStatus.lastVoteEnd = os.time()
        
        if result then
            -- start mission vote. 
            -- do messages for mission vote
        else
            -- MSG: RTV has failed. RTV will be available again in x Time
        end
        rtvTbl = {} -- clear tbl
    end
    
    local function voteReset(result)
        voteStatus.active = false
        voteStatus.lastVoteEnd = os.time()
        
        if result then
            -- start mission vote. 
            -- do messages for mission vote
        else
            -- MSG: RTV has failed. RTV will be available again in x Time
        end
        voteTbl = {} -- clear tbl
    
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
            
            if currentVote > slmod.num_clients * rtvStatus.level then
                -- RTV wins
                rtvReset(true)
            else
                if os.time() > rtvStatus.startedAt + rtvStatus.voteTime then
                -- vote time has ended. 
                    rtvReset()
                end
            end
        end
        
        if voteStatus and voteStatus.startedAt > 0 and voteStatus.active == true then
            local totVotes, result = countVotes(voteTbl)
            local useRule = 1
            for i = 1, #config.ruleSets do
                if config.ruleSets[i].rangeMin and config.ruleSets[i].rangeMax then
                    if slmod.num_clients >= config.ruleSets[i].rangeMin and slmod.num_clients =< config.ruleSets[i].rangeMax then
                        useRule = i
                        break
                    end
                end
            end
            local rule = config.ruleSets[useRule]
            if voteStatus.minVoteTime + voteStatus.startedAT > os.time() then
            -- start to tally votes to check for winner
                local leader = 0
                local endCondition = getEndIfCondition(totVotes, rule.endIf)
                for voteFor, voteTally in pairs(result) do
                    if leader == 0 then
                        leader = voteFor
                    end
                    if voteTally > result[leader] then
                       leader = voteFor -- current winner
                    end
                end
                -- vote leader is found, now figure out what to do with that information
                if voteStatus.maxVoteTime + voteStatus.startedAT > os.time() or endCondition >= totVotes then
                    -- vote time ended or end condition reached
                    local voteSuccessful = false
                    if rule.use == 'magic' and rule.val >= result[leader] then
                        voteSuccessful = true
                    elseif rule.use == 'ratio' and rule.val * slmod.num_clients <= result[leader] then
                        voteSuccessful = true
                    else -- assumes majority rule
                        voteSuccessful = true
                    end
                    
                    if config.requireAdminVerifyIfPresent == true then
                    
                    else
                        -- 
                    end
                    voteReset()
                end
            end
        end
        
        
    end
    
    
    local function getVoteTimeRemainingInMin()
        return tostring(120/60)
    end
    
    local function create_VoteMissionMenuFor(id)  --creates the temporary load mission menu for this client id.
		local path
		local mStats = slmod.stats.getMetaStats()
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
		local display_mode = slmod.config.admin_display_mode or 'text'
		local display_time = slmod.config.admin_display_time or 30
		local VMenu = SlmodMenu.create({showCmds = LoadShowCommands, scope = {clients = {id}}, options = {display_time = display_time, display_mode = display_mode, title = 'Available missions to vote for' .. path .. ' (you have '.. getVoteTimeRemainingInMin() .. ' minutes to make a choice):', privacy = {access = true, show = true}}, items = LoadItems})
		slmod.scheduleFunctionByRt(SlmodMenu.destroy, {VMenu}, DCS.getRealTime() + 120)  --scheduling self-destruct of this menu in two minutes.
		
		local miz_cntr = 1
        for file in lfs.dir(path) do
            if file:sub(-4) == '.miz' then
				local mapName = ''
                local sName = string.gsub(file, '.miz', '')
                if mStats and mStats.missionStats then
                    if mStats.missionStats[sName] then
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
                            if not client_id then
                                client_id = vars
                            end
                            
                            if slmod.clients[client_id] then
                               voteTbl[slmod.clients[client_id].ucid] = self.filename
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
		local statsShowCommands = {
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
                if config.rtvEnabled then -- rtv enabled
                    if rtvStatus.active ~= true then -- not active 
                        if rtvStatus.lastVoteEnd = 0 or os.time() > rtvStatus.lastVoteEnd + rtvStatus.timeout then
                            rtvStatus.active = true
                            rtvStatus.startedAt = os.time()
                        else
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
                    end
                end
            end
            
            voteItems[#voteItems + 1] = SlmodMenuItem.create(rtvVars)  -- add the item into the items table.
        
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
                if config.rtvEnabled then -- rtv enabled
                    if slmod.clients[vars] then
                        if rtvTbl[slmod.clients[vars].ucid] then
                            rtvTbl[slmod.clients[vars].ucid] = nil
                            --TODO:
                        else
                            -- no rtv vote found
                        end
                    end
                end
            end
            
            voteItems[#voteItems + 1] = SlmodMenuItem.create(rtvRemoveVars)  -- add the item into the items table.
        end
        
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
                        required = true
                    },
                    [2] = { 
                        type = 'word',
                        text = 'list'
                        required = true
                    },                        
                },
            } 
        vList.onSelect = function(self, vars, client_id)
            if not client_id then
                client_id = vars
            end
            
            create_VoteMissionMenuFor(client_id)
        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(vList)
        
       
        local voteMizVars = {}
        voteMizVars.menu = SlmodVoteMenu
        voteMizVars.description = 'Type "-vote" <id> to vote for the mission'
        voteMizVars.active = true
        voteMizVars.options = {display_mode = 'chat', display_time = 5, privacy = {access = true, show = true}}
        voteMizVars.selCmds = {
                [1] = {
                    [1] = { 
                        type = 'word', 
                        text = '-vote',
                        required = true
                    },
                    [2] = { 
                        type = 'word', 
                        text = 'mission',
                        required = true
                    },
                    [3] = { 
                        type = 'word', 
                        var = 'mission',
                        required = true
                    },                          
                },
            } 
        voteMizVars.onSelect = function(self, vars, client_id)

        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(voteMizVars)
      
        
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
                        text = '-restart',
                        required = true
                    },                        
                },
            } 
        restartVars.onSelect = function(self, vars, client_id)

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
                        text = '-remove',
                        required = true
                    },                        
                },
            } 
        voteRemoveVars.onSelect = function(self, vars, client_id)
            if not client_id then
                client_id = vars
            end
            if slmod.clients[client_id] then
                if voteTbl[slmod.clients[client_id].ucid] then
                    voteTbl[slmod.clients[client_id].ucid] = nil
                end
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
                        text = '-status',
                        required = true
                    },                        
                },
            } 
        voteStatusVars.onSelect = function(self, vars, client_id)
            if not client_id then
                client_id = vars
            end
            if config.hidden then
                if slmod.clients[client_id] and slmod.clients[client_id].ucid and Admins[slmod.clients[client_id].ucid] then
                        -- show vote status
                else
                     -- sorry vote status is hidden, time left = 
                end
            else
               -- show vote status
            end
        end
        
        voteItems[#voteItems + 1] = SlmodMenuItem.create(voteStatusVars)
    end

end
slmod.info('SlmodVote.lua loaded.')