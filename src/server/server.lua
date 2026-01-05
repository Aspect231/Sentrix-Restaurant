local activePlayers = {}

XPManager = BaseClass:extend()

function XPManager:new(identifier)
    local instance = BaseClass.new(self)
    instance.identifier = identifier
    return instance
end

function XPManager:create()
    MySQL.insert.await('INSERT INTO sentrix_restaurant (identifier, xp) VALUES (?, ?)', {
        self.identifier,
        0
    })
end

function XPManager:load()
    local result = MySQL.single.await('SELECT xp FROM sentrix_restaurant WHERE identifier = ?', {
        self.identifier
    })

    if not result then 
        self:create()
        return self:load()
    end

    return result.xp
end

function XPManager:add(amount)
    if type(amount) ~= 'number' or amount < 0 or amount > 100 then
        return false
    end
    
    MySQL.update.await('UPDATE sentrix_restaurant SET xp = xp + ? WHERE identifier = ?', {
        amount,
        self.identifier
    })
    return true
end

function XPManager:get()
    return self:load()
end

RewardManager = BaseClass:extend()

function RewardManager:giveReward(source, jobType)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    if not Config.Rewards[jobType] then 
        return false 
    end
    
    local rewards = Config.Rewards[jobType]
    local xpReward = rewards.xpPerPlate or rewards.xpPerOrder or rewards.xpPerDish or 1
    local moneyReward = rewards.moneyPerPlate or rewards.moneyPerOrder or rewards.moneyPerDish or 20
    
    xPlayer.addMoney(moneyReward)
    
    local xpManager = XPManager:new(xPlayer.identifier)
    xpManager:add(xpReward)
    
    return true, xpReward, moneyReward
end

local function validatePlayer(source, jobType)
    if not source or source == 0 then
        return false, 'Invalid source'
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false, 'Player not found'
    end
    
    if not activePlayers[source] then
        return false, 'Player not clocked in'
    end
    
    if activePlayers[source].job ~= jobType then
        return false, 'Player not working this job'
    end
    
    local currentTime = os.time()
    if activePlayers[source].lastAction and (currentTime - activePlayers[source].lastAction) < 2 then
        return false, 'Action too fast'
    end
    
    local playerJob = xPlayer.getJob()
    if not playerJob or playerJob.name ~= Config.Job then
        return false, 'Invalid job'
    end
    
    activePlayers[source].lastAction = currentTime
    return true
end

local function validateJobType(jobType)
    if type(jobType) ~= 'string' then
        return false
    end
    
    if not Config.Interactions[jobType] then
        return false
    end
    
    if jobType == 'manager' then
        return false
    end
    
    return true
end

lib.callback.register('sentrix_restaurant:request:config', function(source)
    if not source or source == 0 then return nil end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    
    return Config
end)

lib.callback.register('sentrix_restaurant:get:job', function(source)
    if not source or source == 0 then return nil end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    
    local job = xPlayer.getJob()
    if not job then return nil end
    
    return job.name
end)

lib.callback.register('sentrix_restaurant:request:xp', function(source)
    if not source or source == 0 then return 0 end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return 0 end
    
    local xpManager = XPManager:new(xPlayer.identifier)
    return xpManager:get()
end)

RegisterNetEvent('sentrix_restaurant:completeTask', function(jobType)
    local src = source
    
    if not src or src == 0 then return end
    
    if not validateJobType(jobType) then
        print(('Player %s sent invalid job type: %s'):format(GetPlayerName(src), tostring(jobType)))
        return
    end
    
    local valid, reason = validatePlayer(src, jobType)
    if not valid then
        print(('Player %s failed validation: %s'):format(GetPlayerName(src), reason))
        return
    end
    
    local rewardManager = RewardManager:new()
    local success, xpEarned, moneyEarned = rewardManager:giveReward(src, jobType)
end)

RegisterNetEvent('sentrix_restaurant:clockIn', function(jobType)
    local src = source
    
    if not src or src == 0 then return end
    
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local playerJob = xPlayer.getJob()
    if not playerJob or playerJob.name ~= Config.Job then
        print(('Player %s tried to clock in without proper job'):format(GetPlayerName(src)))
        return
    end
    
    if not validateJobType(jobType) then
        print(('Player %s attempted to clock in to invalid job: %s'):format(GetPlayerName(src), tostring(jobType)))
        return
    end
    
    local jobConfig = Config.Interactions[jobType]
    if not jobConfig or not jobConfig.level then
        return
    end
    
    local xpManager = XPManager:new(xPlayer.identifier)
    local playerXP = xpManager:get()
    local playerLevel = 0
    
    for level, data in pairs(Config.Levels) do
        if playerXP >= data.min and playerXP < data.max then
            playerLevel = level
            break
        end
    end
    
    if playerLevel < jobConfig.level then
        print(('Player %s tried to clock in without required level'):format(GetPlayerName(src)))
        return
    end
    
    if activePlayers[src] then
        print(('Player %s already clocked in'):format(GetPlayerName(src)))
        return
    end
    
    activePlayers[src] = {
        job = jobType,
        clockedInTime = os.time(),
        lastAction = 0,
        identifier = xPlayer.identifier
    }
end)

RegisterNetEvent('sentrix_restaurant:clockOut', function()
    local src = source
    
    if not src or src == 0 then return end
    
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    if not activePlayers[src] then
        print(('Player %s tried to clock out without being clocked in'):format(GetPlayerName(src)))
        return
    end
    
    activePlayers[src] = nil
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if activePlayers[src] then
        activePlayers[src] = nil
    end
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if activePlayers[playerId] then
        activePlayers[playerId] = nil
    end
end)

AddEventHandler('esx:setJob', function(playerId, job, lastJob)
    if activePlayers[playerId] and job.name ~= Config.Job then
        activePlayers[playerId] = nil
    end
end)
