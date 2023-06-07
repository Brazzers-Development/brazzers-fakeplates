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
end exports("isFakePlateOnVehicle", isFakePlateOnVehicle)

-- THIS GETS THE ORIGINAL PLATE FROM THE FAKE PLATE
local function getPlateFromFakePlate(fakeplate)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE fakeplate = ?', {fakeplate})
    if result then
        return result
    end
end exports("getPlateFromFakePlate", getPlateFromFakePlate)

-- THIS GETS THE FAKEPLATE FROM THE ORIGINAL PLATE
local function getFakePlateFromPlate(plate)
    local result = MySQL.scalar.await('SELECT fakeplate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return result
    end
end exports("getFakePlateFromPlate", getFakePlateFromPlate)

-- Net Events

RegisterNetEvent('brazzers-fakeplates:server:usePlate', function(vehNetID, vehPlate, newPlate, hasKeys)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not vehNetID or not vehPlate or not newPlate then return end
    local vehicle = NetworkGetEntityFromNetworkId(vehNetID)

    if isFakePlateOnVehicle(vehPlate) then return TriggerClientEvent('QBCore:Notify', src, Lang:t("error.already_has_plate"), 'error') end
    if not isVehicleOwned(vehPlate) then
        if not hasKeys then return TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_keys"), 'error') end

        SetVehicleNumberPlateText(vehicle, newPlate)
        TriggerClientEvent('vehiclekeys:client:SetOwner', src, newPlate)
        Player.Functions.RemoveItem('fakeplate', 1)
        TriggerClientEvent('inventory:client:ItemBox', src,  QBCore.Shared.Items["fakeplate"], 'remove')
        return
    end

    MySQL.update('UPDATE player_vehicles set fakeplate = ? WHERE plate = ?',{newPlate, vehPlate})
    -- Transfer trunk/ glovebox items
	MySQL.update('UPDATE trunkitems SET plate = ? WHERE plate = ?', {newPlate, vehPlate})
	MySQL.update('UPDATE gloveboxitems SET plate = ? WHERE plate = ?', {newPlate, vehPlate})

    SetVehicleNumberPlateText(vehicle, newPlate)

    Player.Functions.RemoveItem('fakeplate', 1)
    TriggerClientEvent('inventory:client:ItemBox', src,  QBCore.Shared.Items["fakeplate"], 'remove')
    if hasKeys then
        TriggerClientEvent('vehiclekeys:client:SetOwner', src, newPlate)
    end
end)

RegisterNetEvent('brazzers-fakeplates:server:removePlate', function(vehNetID, vehPlate, hasKeys)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not vehNetID or not vehPlate then return end
    local vehicle = NetworkGetEntityFromNetworkId(vehNetID)

    if not isFakePlateOnVehicle(vehPlate) then return TriggerClientEvent('QBCore:Notify', src, Lang:t("error.does_not_have_fakeplate"), 'error') end

    local originalPlate = getPlateFromFakePlate(vehPlate)
    if not originalPlate then return end

    MySQL.update('UPDATE player_vehicles set fakeplate = ? WHERE plate = ?',{nil, originalPlate})

    -- Transfer trunk/ glovebox items
	MySQL.update('UPDATE trunkitems SET plate = ? WHERE plate = ?', {originalPlate, vehPlate})
	MySQL.update('UPDATE gloveboxitems SET plate = ? WHERE plate = ?', {originalPlate, vehPlate})

    Player.Functions.AddItem('fakeplate', 1)
    TriggerClientEvent('inventory:client:ItemBox', src,  QBCore.Shared.Items["fakeplate"], 'add')

    SetVehicleNumberPlateText(vehicle, originalPlate)
    if hasKeys then
        TriggerClientEvent('vehiclekeys:client:SetOwner', src, originalPlate)
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('brazzers-fakeplates:server:checkPlateStatus', function(_, cb, vehPlate)
    local retval = false
    local result = MySQL.query.await('SELECT fakeplate FROM player_vehicles WHERE fakeplate = ?', { vehPlate })
    if result then
        for _, v in pairs(result) do
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
