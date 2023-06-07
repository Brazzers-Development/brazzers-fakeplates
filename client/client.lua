local QBCore = exports[Config.Core]:GetCoreObject()

local hasFakePlate = false

-- Net Events

RegisterNetEvent('brazzers-fakeplates:client:usePlate', function(plate)
    if not plate then return end
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local vehicle = QBCore.Functions.GetClosestVehicle()
    local vehicleCoords = GetEntityCoords(vehicle)
    local dist = #(vehicleCoords - pedCoords)
    local hasKeys = false
    
    if dist <= 5.0 then
        local currentPlate = QBCore.Functions.GetPlate(vehicle)
        -- Has Keys Check
        if exports[Config.Keys]:HasKeys(currentPlate) then
            hasKeys = true
        end
        TaskTurnPedToFaceEntity(ped, vehicle, 3.0)
        QBCore.Functions.Progressbar("attaching_plate", "Attaching Plate", 4000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            anim = 'machinic_loop_mechandplayer',
            flags = 1,
        }, {}, {}, function()
            TriggerServerEvent('brazzers-fakeplates:server:usePlate', VehToNet(vehicle), currentPlate, plate, hasKeys)
            ClearPedTasks(ped)
        end, function()
            ClearPedTasks(ped)
        end)
    end
end)

RegisterNetEvent('brazzers-fakeplates:client:removePlate', function()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local vehicle = QBCore.Functions.GetClosestVehicle()
    local vehicleCoords = GetEntityCoords(vehicle)
    local dist = #(vehicleCoords - pedCoords)
    local hasKeys = false
    
    if dist <= 5.0 then
        local currentPlate = QBCore.Functions.GetPlate(vehicle)
        -- Has Keys Check
        if exports[Config.Keys]:HasKeys(currentPlate) then
            hasKeys = true
        end
        TaskTurnPedToFaceEntity(ped, vehicle, 3.0)
        QBCore.Functions.Progressbar("removing_plate", "Removing Plate", 4000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            anim = 'machinic_loop_mechandplayer',
            flags = 1,
        }, {}, {}, function()
            TriggerServerEvent('brazzers-fakeplates:server:removePlate', VehToNet(vehicle), currentPlate, hasKeys)
            ClearPedTasks(ped)
        end, function()
            ClearPedTasks(ped)
        end)
    end
end)

-- Threads

CreateThread(function()
    while true do
        Wait(1000)
        local inRange = false
        local pos = GetEntityCoords(PlayerPedId())
        local vehicle = QBCore.Functions.GetClosestVehicle()
        local vehCoords = GetEntityCoords(vehicle)
        local closestPlate = QBCore.Functions.GetPlate(vehicle)

        if exports[Config.Keys]:HasKeys(closestPlate) then -- Has Keys
            if not IsPedInAnyVehicle(PlayerPedId()) then -- Not in vehicle
                if #(pos - vector3(vehCoords.xyz)) < 7.0 then -- dist check
                    inRange = true
                    QBCore.Functions.TriggerCallback('brazzers-fakeplates:server:checkPlateStatus', function(result)
                        if result then
                            hasFakePlate = true
                        else
                            hasFakePlate = false
                        end
                    end, closestPlate)
                end
                if not inRange then
                    Wait(3000)
                end
            end
        end
    end
end)

CreateThread(function()
    local bones = {
        'boot',
    }
    
    exports[Config.Target]:AddTargetBone(bones, {
        options = {
            {
                type = 'client',
                event = 'brazzers-fakeplates:client:removePlate',
                icon = 'fas fa-closed-captioning',
                label = 'Remove Plate',
                canInteract = function()
                    if hasFakePlate then
                        return true
                    end
                end,
            }
        },
        distance = 2.5,
    })
end)
