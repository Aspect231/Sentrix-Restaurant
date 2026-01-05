local loadedPeds = {}
local loadedObjects = {}
local clockedIn = false
local clockedInJob = nil
local currentJobInstance = nil

Core = BaseClass:extend()

function Core:init()
    self.peds = {}
    self.objects = {}
end

function Core:removePeds()
    for _, ped in pairs(loadedPeds) do
        if DoesEntityExist(ped) then 
            DeleteEntity(ped) 
        end
    end
    loadedPeds = {}
end

function Core:removeObjects()
    for _, obj in pairs(loadedObjects) do
        if DoesEntityExist(obj) then 
            DeleteEntity(obj) 
        end
    end
    loadedObjects = {}
end

function Core:cleanup()
    self:removePeds()
    self:removeObjects()
end

function Core:fadeScreen(fadeOut, duration)
    if fadeOut then
        DoScreenFadeOut(duration)
        while not IsScreenFadedOut() do Wait(0) end
    else
        DoScreenFadeIn(duration)
        while not IsScreenFadedIn() do Wait(0) end
    end
end

function Core:drawMarker(coords, type, color)
    local markerType = type or 2  
    local r, g, b = color.r or 255, color.g or 165, color.b or 0
    
    DrawMarker(
        markerType,
        coords.x, coords.y, coords.z + 1.2,  
        0.0, 0.0, 0.0,
        180.0, 0.0, 0.0,  
        0.5, 0.5, 0.5,  
        r, g, b, 200,    
        true, true, 2, false, nil, nil, false
    )
end

Manager = BaseClass:extend()

function Manager:init()
    self.ped = nil
end

function Manager:initiatePed()
    local playerJob = lib.callback.await('sentrix_restaurant:get:job', false)

    if playerJob == Config.Job then
        local data = Config.Interactions.manager
        local model = joaat(data.ped)
        
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end

        local ped = CreatePed(4, model, data.coords.x, data.coords.y, data.coords.z - 1.0, data.coords.w, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)

        table.insert(loadedPeds, ped)
        self.ped = ped

        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'restaurant-manager',
                distance = 2.0,
                icon = 'fa-solid fa-briefcase',
                label = 'Talk to manager Mike',
                onSelect = function()
                    self:openMainMenu()
                end
            }
        })
    end
end

function Manager:openMainMenu()
    local xp = XPManager:getXP()
    local level, maxXP, progress = XPManager:getLevelFromXP(xp)
    local status = clockedIn

    lib.registerContext({
        id = 'manager_main',
        title = 'De Claudio | Manager',
        options = {
            {
                title = ('Level %d'):format(level),
                description = ('XP: %d / %d'):format(xp, maxXP),
                icon = 'fa-solid fa-database',
                progress = progress,
                colorScheme = 'green',
            },
            {
                title = clockedIn and 'Clock Out' or 'Clock In',
                description = clockedInJob and ('Current role: %s'):format(Config.Interactions[clockedInJob].label) or 'Select a job role',
                icon = 'fa-solid fa-clock',
                onSelect = function()
                    JobManager:toggleJob()
                end
            },
        }
    })

    lib.showContext('manager_main')
end

XPManager = BaseClass:extend()

function XPManager:getXP()
    return lib.callback.await('sentrix_restaurant:request:xp', false)
end

function XPManager:getLevelFromXP(xp)
    for level, data in pairs(Config.Levels) do
        if xp >= data.min and xp < data.max then
            local progress = ((xp - data.min) / (data.max - data.min)) * 100
            return level, data.max, progress
        end
    end

    local maxLevel = 0
    local maxXP = 0
    for level, data in pairs(Config.Levels) do
        if level > maxLevel then
            maxLevel = level
            maxXP = data.max
        end
    end

    return maxLevel, maxXP, 100
end

function XPManager:getPlayerLevel()
    local xp = self:getXP()
    local level, _, _ = self:getLevelFromXP(xp)
    return level
end

BaseJob = BaseClass:extend()

function BaseJob:init(jobName)
    self.jobName = jobName
    self.active = false
    self.config = Config.Interactions[jobName]
end

function BaseJob:start()
    self.active = true
    local core = Core:new()
    
    core:fadeScreen(true, 1000)

    local spawn = self.config.spawnLocation
    SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), spawn.w)
    
    Wait(500)
    core:fadeScreen(false, 1000)
    
    self:onStart()
end

function BaseJob:stop()
    self.active = false
    self:onStop()
end

function BaseJob:onStart()

end

function BaseJob:onStop()

end

DishwasherJob = BaseJob:extend()

function DishwasherJob:init(jobName)
    BaseJob.init(self, jobName)
    self.activePlates = {}
    self.spawnThread = nil
    self.holdingPlate = false
    self.heldPlateObject = nil
    self.markerThread = nil
end

function DishwasherJob:onStart()
    self:startSpawningPlates()
    self:setupStorageZone()
    self:startMarkers()
end

function DishwasherJob:onStop()
    self.active = false
    for _, plate in pairs(self.activePlates) do
        if DoesEntityExist(plate.object) then
            exports.ox_target:removeLocalEntity(plate.object)
            DeleteEntity(plate.object)
        end
    end
    self.activePlates = {}
    if self.holdingPlate and self.heldPlateObject then
        DeleteEntity(self.heldPlateObject)
        self.holdingPlate = false
        self.heldPlateObject = nil
    end
end

function DishwasherJob:startMarkers()
    self.markerThread = CreateThread(function()
        local core = Core:new()
        while self.active do
            local playerPos = GetEntityCoords(PlayerPedId())
            
            for _, plate in pairs(self.activePlates) do
                local platePos = GetEntityCoords(plate.object)
                if #(playerPos - platePos) < 10.0 then
                    core:drawMarker(plate.location, 2, {r = 255, g = 0, b = 0})  
                end
            end

            if self.holdingPlate then
                local storage = self.config.plates.storageLocation
                if #(playerPos - storage) < 10.0 then
                    core:drawMarker(storage, 2, {r = 0, g = 255, b = 0})  
                end
            end
            
            Wait(0)
        end
    end)
end

function DishwasherJob:startSpawningPlates()
    CreateThread(function()
        while self.active do
            if #self.activePlates < self.config.plates.maxActive then
                self:spawnPlate()
            end
            Wait(self.config.plates.spawnInterval)
        end
    end)
end

function DishwasherJob:spawnPlate()
    local plateConfig = self.config.plates
    local location = plateConfig.locations[math.random(#plateConfig.locations)]
    local model = joaat(plateConfig.model)
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local plate = CreateObject(model, location.x, location.y, location.z, false, false, false)
    SetEntityHeading(plate, location.w)
    FreezeEntityPosition(plate, true)
    
    table.insert(loadedObjects, plate)
    table.insert(self.activePlates, {object = plate, location = location})
    
    exports.ox_target:addLocalEntity(plate, {
        {
            name = 'clean_plate_' .. plate,
            distance = 1.0,
            icon = 'fa-solid fa-soap',
            label = 'Clean Plate',
            canInteract = function()
                return self.active
            end,
            onSelect = function()
                self:cleanPlate(plate)
            end
        }
    })
end

function DishwasherJob:cleanPlate(plateObj)
    if self.holdingPlate then
        lib.notify({
            title = 'Already holding a plate!',
            description = 'Place the current plate first',
            type = 'error'
        })
        return
    end

    if lib.progressBar({
        duration = self.config.plates.cleanTime,
        label = 'Cleaning plate...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'timetable@maid@cleaning_surface@base',
            clip = 'base'
        }
    }) then
        for i, plate in ipairs(self.activePlates) do
            if plate.object == plateObj then
                table.remove(self.activePlates, i)
                break
            end
        end
        
        exports.ox_target:removeLocalEntity(plateObj)
        DeleteEntity(plateObj)
        
        self:giveCleanPlate()
        
        lib.notify({
            title = 'Plate cleaned!',
            description = 'Now take it to the storage area',
            type = 'success'
        })
    else
        lib.notify({title = 'Cleaning cancelled', type = 'error'})
    end
end

function DishwasherJob:giveCleanPlate()
    local ped = PlayerPedId()
    local model = joaat('v_ret_fh_plate3')
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local plate = CreateObject(model, 0, 0, 0, true, true, true)
    AttachEntityToEntity(plate, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    self.holdingPlate = true
    self.heldPlateObject = plate
end

function DishwasherJob:placeCleanPlate()
    if not self.holdingPlate then return end
    
    if lib.progressBar({
        duration = 2000,
        label = 'Placing plate...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a'
        }
    }) then
        if DoesEntityExist(self.heldPlateObject) then
            DeleteEntity(self.heldPlateObject)
        end
        
        self.holdingPlate = false
        self.heldPlateObject = nil
        
        TriggerServerEvent('sentrix_restaurant:completeTask', 'dishwashing')
        
        lib.notify({
            title = 'Plate stored!',
            description = ('Earned $%d and %d XP'):format(Config.Rewards.dishwasher.moneyPerPlate, Config.Rewards.dishwasher.xpPerPlate),
            type = 'success'
        })
    else
        lib.notify({title = 'Cancelled', type = 'error'})
    end
end

function DishwasherJob:setupStorageZone()
    local storage = self.config.plates.storageLocation
    
    exports.ox_target:addBoxZone({
        coords = vec3(storage.x, storage.y, storage.z),
        size = vec3(1.5, 1.5, 1.0),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'place_clean_plate',
                distance = 1.0,
                icon = 'fa-solid fa-box',
                label = 'Place Clean Plate',
                canInteract = function()
                    return self.active and self.holdingPlate
                end,
                onSelect = function()
                    self:placeCleanPlate()
                end
            }
        }
    })
end

WaiterJob = BaseJob:extend()

function WaiterJob:init(jobName)
    BaseJob.init(self, jobName)
    self.activeCustomers = {}
    self.spawnThread = nil
    self.pendingOrders = {}
    self.holdingFood = false
    self.heldFoodObject = nil
    self.currentDelivery = nil
    self.spawnedPlates = {}
    self.markerThread = nil
end

function WaiterJob:onStart()
    if not self.config.bar then
        lib.notify({
            title = 'Configuration Error',
            description = 'Bar configuration not found',
            type = 'error'
        })
        return
    end
    self:startSpawningCustomers()
    self:setupCounterZone()
    self:startMarkers()
end

function WaiterJob:onStop()
    self.active = false
    for _, customer in pairs(self.activeCustomers) do
        if DoesEntityExist(customer.ped) then
            exports.ox_target:removeLocalEntity(customer.ped)
            DeleteEntity(customer.ped)
        end
    end
    self.activeCustomers = {}
    self.pendingOrders = {}
    for _, plate in pairs(self.spawnedPlates) do
        if DoesEntityExist(plate.object) then
            exports.ox_target:removeLocalEntity(plate.object)
            DeleteEntity(plate.object)
        end
    end
    self.spawnedPlates = {}
    if self.holdingFood and self.heldFoodObject then
        DeleteEntity(self.heldFoodObject)
        self.holdingFood = false
        self.heldFoodObject = nil
    end
end

function WaiterJob:startMarkers()
    self.markerThread = CreateThread(function()
        local core = Core:new()
        while self.active do
            local playerPos = GetEntityCoords(PlayerPedId())
            
            for _, customer in pairs(self.activeCustomers) do
                if not customer.hasOrdered then
                    local customerPos = GetEntityCoords(customer.ped)
                    if #(playerPos - customerPos) < 15.0 then
                        core:drawMarker(vec3(customerPos.x, customerPos.y, customerPos.z), 2, {r = 255, g = 255, b = 0}) 
                    end
                end
            end
            
            for _, plate in pairs(self.spawnedPlates) do
                local platePos = GetEntityCoords(plate.object)
                if #(playerPos - platePos) < 15.0 then
                    core:drawMarker(vec3(platePos.x, platePos.y, platePos.z - 1.0), 2, {r = 0, g = 255, b = 255})  
                end
            end
            
            if self.holdingFood and self.currentDelivery then
                for _, customer in pairs(self.activeCustomers) do
                    if customer.ped == self.currentDelivery.customerPed and customer.hasOrdered then
                        local customerPos = GetEntityCoords(customer.ped)
                        if #(playerPos - customerPos) < 15.0 then
                            core:drawMarker(vec3(customerPos.x, customerPos.y, customerPos.z), 2, {r = 0, g = 255, b = 0}) 
                        end
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function WaiterJob:startSpawningCustomers()
    CreateThread(function()
        while self.active do
            if #self.activeCustomers < self.config.bar.maxCustomers then
                self:spawnCustomer()
            end
            Wait(self.config.bar.spawnInterval)
        end
    end)
end

function WaiterJob:spawnCustomer()
    local barConfig = self.config.bar
    local availableSeats = {}
    
    for i, seat in ipairs(barConfig.seats) do
        local occupied = false
        for _, customer in pairs(self.activeCustomers) do
            if customer.seatIndex == i then
                occupied = true
                break
            end
        end
        if not occupied then
            table.insert(availableSeats, {seat = seat, index = i})
        end
    end
    
    if #availableSeats == 0 then return end
    
    local chosenSeat = availableSeats[math.random(#availableSeats)]
    local seat = chosenSeat.seat
    local modelName = barConfig.npcModels[math.random(#barConfig.npcModels)]
    local model = joaat(modelName)
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local customerPed = CreatePed(4, model, seat.x, seat.y, seat.z - 1.0, seat.w, false, true)
    SetEntityInvincible(customerPed, true)
    SetBlockingOfNonTemporaryEvents(customerPed, true)
    FreezeEntityPosition(customerPed, true)
    
    table.insert(loadedPeds, customerPed)
    
    local order = self.config.menu[math.random(#self.config.menu)]
    
    table.insert(self.activeCustomers, {
        ped = customerPed,
        seatIndex = chosenSeat.index,
        order = order,
        hasOrdered = false
    })
    
    exports.ox_target:addLocalEntity(customerPed, {
        {
            name = 'take_order_' .. customerPed,
            distance = 1.5,
            icon = 'fa-solid fa-clipboard',
            label = 'Take Order',
            canInteract = function(entity)
                for _, customer in pairs(self.activeCustomers) do
                    if customer.ped == entity and not customer.hasOrdered and self.active then
                        return true
                    end
                end
                return false
            end,
            onSelect = function(data)
                self:takeOrder(data.entity)
            end
        },
        {
            name = 'serve_order_' .. customerPed,
            distance = 1.5,
            icon = 'fa-solid fa-utensils',
            label = 'Serve Order',
            canInteract = function(entity)
                if not self.holdingFood or not self.currentDelivery then
                    return false
                end
                for _, customer in pairs(self.activeCustomers) do
                    if customer.ped == entity and customer.ped == self.currentDelivery.customerPed and self.active then
                        return true
                    end
                end
                return false
            end,
            onSelect = function(data)
                self:serveOrder(data.entity)
            end
        }
    })
end

function WaiterJob:takeOrder(customerPed)
    local customer = nil
    for _, c in pairs(self.activeCustomers) do
        if c.ped == customerPed then
            customer = c
            break
        end
    end
    
    if not customer then return end
    
    if lib.progressBar({
        duration = self.config.bar.orderTime,
        label = 'Taking order...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'amb@world_human_clipboard@male@idle_a',
            clip = 'idle_c'
        }
    }) then
        customer.hasOrdered = true
        
        table.insert(self.pendingOrders, {
            order = customer.order,
            customerPed = customerPed,
            readyTime = GetGameTimer() + 15000
        })
        
        lib.notify({
            title = 'Order taken!',
            description = ('Customer wants: %s - Wait for it at the counter'):format(customer.order),
            type = 'inform'
        })
        
        self:startOrderTimer(customer.order, customerPed)
    else
        lib.notify({title = 'Cancelled', type = 'error'})
    end
end

function WaiterJob:startOrderTimer(orderName, customerPed)
    CreateThread(function()
        Wait(15000)
        if self.active then
            self:spawnFoodPlate(orderName, customerPed)
            
            lib.notify({
                title = 'Order Ready!',
                description = ('%s is ready at the counter'):format(orderName),
                type = 'success'
            })
        end
    end)
end

function WaiterJob:spawnFoodPlate(orderName, customerPed)
    local counter = self.config.counterLocation
    local model = joaat('prop_cs_plate_01')
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local plate = CreateObject(model, counter.x, counter.y, counter.z, false, false, false)
    FreezeEntityPosition(plate, true)
    
    table.insert(loadedObjects, plate)
    table.insert(self.spawnedPlates, {
        object = plate,
        order = orderName,
        customerPed = customerPed
    })
    
    for i, order in ipairs(self.pendingOrders) do
        if order.customerPed == customerPed then
            table.remove(self.pendingOrders, i)
            break
        end
    end
    
    exports.ox_target:addLocalEntity(plate, {
        {
            name = 'pickup_food_' .. plate,
            distance = 1.0,
            icon = 'fa-solid fa-hand',
            label = ('Pick up %s'):format(orderName),
            canInteract = function()
                return self.active and not self.holdingFood
            end,
            onSelect = function()
                self:pickupFood(plate, orderName, customerPed)
            end
        }
    })
end

function WaiterJob:pickupFood(plateObj, orderName, customerPed)
    if self.holdingFood then
        lib.notify({
            title = 'Already carrying food!',
            description = 'Deliver current order first',
            type = 'error'
        })
        return
    end
    
    if lib.progressBar({
        duration = 2000,
        label = 'Picking up food...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a'
        }
    }) then
        for i, plate in ipairs(self.spawnedPlates) do
            if plate.object == plateObj then
                table.remove(self.spawnedPlates, i)
                break
            end
        end
        
        exports.ox_target:removeLocalEntity(plateObj)
        DeleteEntity(plateObj)
        
        self:giveFoodPlate()
        
        self.currentDelivery = {
            orderName = orderName,
            customerPed = customerPed
        }
        
        lib.notify({
            title = 'Food picked up!',
            description = 'Deliver it to the customer',
            type = 'success'
        })
    else
        lib.notify({title = 'Cancelled', type = 'error'})
    end
end

function WaiterJob:giveFoodPlate()
    local ped = PlayerPedId()
    local model = joaat('prop_cs_plate_01')
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local plate = CreateObject(model, 0, 0, 0, true, true, true)
    AttachEntityToEntity(plate, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    self.holdingFood = true
    self.heldFoodObject = plate
end

function WaiterJob:serveOrder(customerPed)
    if not self.holdingFood or not self.currentDelivery then return end
    
    if self.currentDelivery.customerPed ~= customerPed then
        lib.notify({
            title = 'Wrong customer!',
            description = 'This is not their order',
            type = 'error'
        })
        return
    end
    
    if lib.progressBar({
        duration = 2000,
        label = 'Serving food...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a'
        }
    }) then
        if DoesEntityExist(self.heldFoodObject) then
            DeleteEntity(self.heldFoodObject)
        end
        
        self.holdingFood = false
        self.heldFoodObject = nil
        
        TriggerServerEvent('sentrix_restaurant:completeTask', 'waiter')
        
        lib.notify({
            title = 'Order delivered!',
            description = ('Earned $%d and %d XP'):format(Config.Rewards.waiter.moneyPerOrder, Config.Rewards.waiter.xpPerOrder),
            type = 'success'
        })
        
        for i, customer in ipairs(self.activeCustomers) do
            if customer.ped == customerPed then
                exports.ox_target:removeLocalEntity(customer.ped)
                DeleteEntity(customer.ped)
                table.remove(self.activeCustomers, i)
                break
            end
        end
        
        self.currentDelivery = nil
    else
        lib.notify({title = 'Cancelled', type = 'error'})
    end
end

function WaiterJob:setupCounterZone()
    local counter = self.config.counterLocation
    
    exports.ox_target:addBoxZone({
        coords = vec3(counter.x, counter.y, counter.z),
        size = vec3(2.0, 2.0, 1.0),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'counter_info',
                distance = 1.5,
                icon = 'fa-solid fa-info',
                label = 'Counter',
                canInteract = function()
                    return self.active
                end,
                onSelect = function()
                    lib.notify({
                        title = 'Counter',
                        description = 'Food orders will appear here',
                        type = 'inform'
                    })
                end
            }
        }
    })
end

ChefJob = BaseJob:extend()

function ChefJob:init(jobName)
    BaseJob.init(self, jobName)
    self.activeOrders = {}
    self.orderThread = nil
    self.currentStep = 0
    self.currentOrder = nil
    self.markerThread = nil
end

function ChefJob:onStart()
    if not self.config.kitchen then
        lib.notify({
            title = 'Configuration Error',
            description = 'Kitchen configuration not found',
            type = 'error'
        })
        return
    end
    self:setupKitchen()
    self:startReceivingOrders()
    self:startMarkers()
end

function ChefJob:onStop()
    self.active = false
    self.activeOrders = {}
    self.currentOrder = nil
    self.currentStep = 0
end

function ChefJob:startMarkers()
    self.markerThread = CreateThread(function()
        local core = Core:new()
        while self.active do
            local playerPos = GetEntityCoords(PlayerPedId())
            
            if self.currentOrder and self.currentStep > 0 then
                local step = self.currentOrder.dish.steps[self.currentStep]
                if step then
                    local stationCoords = self.config.kitchen.stations[step.station]
                    if stationCoords and #(playerPos - stationCoords) < 10.0 then
                        core:drawMarker(stationCoords, 2, {r = 255, g = 165, b = 0})  
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function ChefJob:setupKitchen()
    for stationName, coords in pairs(self.config.kitchen.stations) do
        exports.ox_target:addBoxZone({
            coords = vec3(coords.x, coords.y, coords.z),
            size = vec3(1.5, 1.5, 1.0),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = 'chef_station_' .. stationName,
                    distance = 1.0,
                    icon = 'fa-solid fa-fire-burner',
                    label = 'Use Station',
                    canInteract = function()
                        if not self.currentOrder then 
                            return false 
                        end

                        local step = self.currentOrder.dish.steps[self.currentStep]
    
                        return self.active and self.currentOrder ~= nil and step ~= nil and step.station == stationName
                    end,
                    onSelect = function()
                        self:useStation(stationName)
                    end
                }
            }
        })
    end
    
    local mainStation = self.config.kitchen.stations.main
    exports.ox_target:addBoxZone({
        coords = vec3(mainStation.x, mainStation.y, mainStation.z),
        size = vec3(2, 2, 2),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'view_orders',
                distance = 1.0,
                icon = 'fa-solid fa-list',
                label = 'View Orders',
                canInteract = function()
                    return self.active and self.currentOrder == nil
                end,
                onSelect = function()
                    self:showOrders()
                end
            }
        }
    })
end

function ChefJob:useStation(stationName)
    if not self.currentOrder or self.currentStep == 0 then
        lib.notify({
            title = 'No active order',
            description = 'Select an order first',
            type = 'error'
        })
        return
    end
    
    local step = self.currentOrder.dish.steps[self.currentStep]
    
    if step.station ~= stationName then
        lib.notify({
            title = 'Wrong station!',
            description = ('You need to %s'):format(step.action),
            type = 'error'
        })
        return
    end
    
    if lib.progressBar({
        duration = self.config.kitchen.cookingTime,
        label = ('%s...'):format(step.action),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = step.anim
    }) then
        self.currentStep = self.currentStep + 1
        
        if self.currentStep > #self.currentOrder.dish.steps then
            self:completeDish()
        else
            local nextStep = self.currentOrder.dish.steps[self.currentStep]
            lib.notify({
                title = 'Step completed!',
                description = ('Next: %s'):format(nextStep.action),
                type = 'success'
            })
        end
    else
        lib.notify({title = 'Cancelled', type = 'error'})
    end
end

function ChefJob:completeDish()
    lib.notify({
        title = 'Dish completed!',
        description = ('%s is ready!'):format(self.currentOrder.dish.name),
        type = 'success'
    })
    
    TriggerServerEvent('sentrix_restaurant:completeTask', 'chef')
    
    lib.notify({
        title = 'Reward earned!',
        description = ('Earned $%d and %d XP'):format(Config.Rewards.chef.moneyPerDish, Config.Rewards.chef.xpPerDish),
        type = 'success'
    })
    
    for i, order in ipairs(self.activeOrders) do
        if order == self.currentOrder then
            table.remove(self.activeOrders, i)
            break
        end
    end
    
    self.currentOrder = nil
    self.currentStep = 0
end

function ChefJob:startReceivingOrders()
    CreateThread(function()
        while self.active do
            if #self.activeOrders < self.config.kitchen.maxOrders then
                self:receiveOrder()
            end
            Wait(self.config.kitchen.orderInterval)
        end
    end)
end

function ChefJob:receiveOrder()
    local dishes = self.config.kitchen.dishes
    local dish = dishes[math.random(#dishes)]
    
    table.insert(self.activeOrders, {
        dish = dish
    })
    
    lib.notify({
        title = 'New Order!',
        description = ('Prepare: %s'):format(dish.name),
        type = 'inform'
    })
end

function ChefJob:showOrders()
    if #self.activeOrders == 0 then
        lib.notify({title = 'No orders', description = 'Wait for new orders to arrive', type = 'inform'})
        return
    end
    
    local options = {}
    for i, order in ipairs(self.activeOrders) do
        local steps = {}
        for _, step in ipairs(order.dish.steps) do
            table.insert(steps, step.action)
        end
        local stepsText = table.concat(steps, ' → ')
        
        table.insert(options, {
            title = order.dish.name,
            description = stepsText,
            icon = 'fa-solid fa-burger',
            onSelect = function()
                self:selectOrder(i)
            end
        })
    end
    
    lib.registerContext({
        id = 'chef_orders',
        title = 'Active Orders',
        options = options
    })
    
    lib.showContext('chef_orders')
end

function ChefJob:selectOrder(orderIndex)
    self.currentOrder = self.activeOrders[orderIndex]
    self.currentStep = 1
    
    local firstStep = self.currentOrder.dish.steps[1]
    lib.notify({
        title = 'Order selected!',
        description = ('Start with: %s'):format(firstStep.action),
        type = 'success'
    })
end

JobManager = BaseClass:extend()

function JobManager:toggleJob()
    if not clockedIn then
        self:clockIn()
    else
        self:clockOut()
    end
end

function JobManager:clockIn()
    local playerLevel = XPManager:getPlayerLevel()
    local availableJobs = {}
    
    for jobName, jobConfig in pairs(Config.Interactions) do
        if jobName ~= 'manager' and jobConfig.level then
            if playerLevel >= jobConfig.level then
                table.insert(availableJobs, {
                    title = jobConfig.label,
                    description = ('Required Level: %d'):format(jobConfig.level),
                    icon = 'fa-solid fa-briefcase',
                    onSelect = function()
                        self:startJob(jobName)
                    end
                })
            end
        end
    end
    
    if #availableJobs == 0 then
        lib.notify({title = 'No jobs available', description = 'Level up to unlock jobs', type = 'error'})
        return
    end
    
    lib.registerContext({
        id = 'select_job',
        title = 'Select Job',
        options = availableJobs
    })
    
    lib.showContext('select_job')
end

function JobManager:startJob(jobName)
    local jobClasses = {
        dishwashing = DishwasherJob,
        waiter = WaiterJob,
        chef = ChefJob
    }
    
    local JobClass = jobClasses[jobName]
    if not JobClass then
        lib.notify({title = 'Invalid job', type = 'error'})
        return
    end
    
    currentJobInstance = JobClass:new(jobName)
    currentJobInstance:start()
    
    clockedIn = true
    clockedInJob = jobName
    
    TriggerServerEvent('sentrix_restaurant:clockIn', jobName)
    
    lib.notify({
        title = 'Clocked In',
        description = ('Working as: %s'):format(Config.Interactions[jobName].label),
        type = 'success'
    })
end

function JobManager:clockOut()
    if currentJobInstance then
        currentJobInstance:stop()
        currentJobInstance = nil
    end
    
    TriggerServerEvent('sentrix_restaurant:clockOut')
    
    clockedIn = false
    clockedInJob = nil
    
    lib.notify({title = 'Clocked Out', type = 'inform'})
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    local core = Core:new()
    core:cleanup()
    
    if currentJobInstance then
        currentJobInstance:stop()
    end
end)

CreateThread(function()
    local manager = Manager:new()
    manager:initiatePed()
end)
