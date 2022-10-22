local QBCore = exports[Config.Core]:GetCoreObject()

-- Functions

local function GeneratePlate()
    local plate = QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(2)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

local function isVehicleOwned(plate)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return true
    end
end

local function isFakePlateOnVehicle(plate)
    local result = MySQL.scalar.await('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate})
    if result then
        return true
    end
end

local function getPlateFromFakePlate(fakeplate)
    local result = MySQL.scalar.await('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate})
    if result then
        return result[1].plate
    end
end

local function hasFakePlate(plate)
    local result = MySQL.scalar.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        if result[1].fakeplate then
            return result[1].fakeplate
        end
    end
end exports("hasFakePlate", hasFakePlate)

-- Net Events

RegisterNetEvent('brazzers-fakeplates:server:usePlate', function(vehicle, vehPlate, newPlate, hasKeys)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not vehicle or not vehPlate or not newPlate then return end

    if isFakePlateOnVehicle(vehPlate) then TriggerClientEvent('QBCore:Notify', src, Lang:t("error.already_has_plate"), 'error') end
    if not isVehicleOwned(vehPlate) then
        if hasKeys then
            TriggerClientEvent('brazzers-fakeplates:client:syncKeys', src, newPlate)
            TriggerClientEvent('brazzers-fakeplates:client:syncNewPlate', -1, vehicle, newPlate)
            return
        end
    end

    MySQL.update('UPDATE player_vehicles set fakeplate = ? WHERE plate = ?',{newPlate, vehPlate})
    TriggerClientEvent('brazzers-fakeplates:client:syncNewPlate', -1, vehicle, newPlate)

    Player.Functions.RemoveItem('fakeplate', 1, false)
    TriggerClientEvent('inventory:client:ItemBox', src,  QBCore.Shared.Items["fakeplate"], 'remove')
    if hasKeys then
        TriggerClientEvent('brazzers-fakeplates:client:syncKeys', src, newPlate)
    end
end)

RegisterNetEvent('brazzers-fakeplates:server:removePlate', function(vehicle, vehPlate, hasKeys)
    local src = source
    if not src then return end
    if not vehicle or not vehPlate then return end

    if not isFakePlateOnVehicle(vehPlate) then return TriggerClientEvent('QBCore:Notify', src, Lang:t("error.does_not_have_fakeplate"), 'error') end

    local originalPlate = getPlateFromFakePlate(vehPlate)
    if not originalPlate then return end

    MySQL.update('UPDATE player_vehicles set fakeplate = ? WHERE plate = ?',{NULL, originalPlate})
    TriggerClientEvent('brazzers-fakeplates:client:syncNewPlate', -1, vehicle, originalPlate)
    if hasKeys then
        TriggerClientEvent('brazzers-fakeplates:client:syncKeys', src, originalPlate)
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('brazzers-fakeplates:server:checkPlateStatus', function(_, cb, vehPlate)
    local retval = false
    local result = MySQL.query.await('SELECT fakeplate FROM player_vehicles WHERE fakeplate = ?', { vehPlate })
    if result then
        for k, v in pairs(result) do
            if vehPlate == v.fakeplate then
                retval = true
            end
        end
    end
    cb(retval)
end)

-- Items

QBCore.Functions.CreateUseableItem('fakeplate', function(source)
    local src = source
    local plate = GeneratePlate()
    TriggerClientEvent("brazzers-fakeplates:client:usePlate", src, plate)
end)