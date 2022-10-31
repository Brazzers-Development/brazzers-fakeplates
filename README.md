# Installation steps

## General Setup
Very simple persistent fake plate script. I didn't see one made so here you go

Preview: https://www.youtube.com/watch?v=PsGh2FnSM1o

## Installation Default QBCore Garages
If you're to lazy to do this, I included the drag and drop of qb-garages server.lua in the files lazy fuck

Locate your qb-garage:server:spawnVehicle callback in your qb-garages and replace with the one below: 
```lua
QBCore.Functions.CreateCallback('qb-garage:server:spawnvehicle', function (source, cb, vehInfo, coords, warp)
    local plate = vehInfo.plate
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)
    local hasFakePlate = exports['brazzers-fakeplates']:getFakePlateFromPlate(plate)
    if hasFakePlate then SetVehicleNumberPlateText(veh, hasFakePlate) else SetVehicleNumberPlateText(veh, plate) end
    SetEntityHeading(veh, coords.w)
    local vehProps = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}
    cb(netId, vehProps)
end)
```
Locate your qb-garage:server:checkOwnership callback in your qb-garages and replace with the one below:
```lua
QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, type, house, gang)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages only for player cars
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    elseif type == "house" then     --House garages only for player cars that have keys of the house
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                local hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, house)
                if hasHouseKey then
                    cb(true)
                else
                    MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(fakeplate)
                        if fakeplate[1] then
                            cb(true)
                        else
                            cb(false)
                        end
                    end)
                end
            else
                cb(false)
            end
        end)
    elseif type == "gang" then        --Gang garages only for gang members cars (for sharing)
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                --Check if found owner is part of the gang
                local resultplayer = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { result[1].citizenid })
                if resultplayer then
                    local playergang = json.decode(resultplayer.gang)
                    if playergang.name == gang then
                        cb(true)
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''
        if not SharedGarages then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?',{plate}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    end
end)
```
Locate qb-garage:server:updateVehicle and replace with the code below
```lua
RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, garage, type, gang)
    QBCore.Functions.TriggerCallback('qb-garage:server:checkOwnership', source, function(owned)     --Check ownership
        if owned then
            if state == 0 or state == 1 or state == 2 then                                          --Check state value
                if type ~= "house" then
                    if Garages[garage] then
                        local hasFakePlate = exports['brazzers-fakeplates']:isFakePlateOnVehicle(plate)
                        if hasFakePlate then
                            --Check if garage is existing
                            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE fakeplate = ?', {state, garage, fuel, engine, body, plate})
                        else
                            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
                        end
                    end
                else
                    if hasFakePlate then
                        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE fakeplate = ?', {state, garage, fuel, engine, body, plate})
                    else
                        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
                    end
                end
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        end
    end, plate, type, garage, gang)
end)
```
## Installation JDev QBCore Garages

You must have SpawnVehicleServerside = true for this plate system to work. Or just rewrite the client and create some callbacks with my fake plates to make it work

Locate qb-garage:server:updateVehicle and replace with the code below
```lua
RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, properties, garage, location, damage)
    local hasFakePlate = exports['brazzers-fakeplates']:getPlateFromFakePlate(plate)
    if hasFakePlate then plate = hasFakePlate end
    Wait(100)

    if location and type(location) == 'vector3' then
        if StoreDamageAccuratly then
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), json.encode(damage), plate})
        else
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), plate})
        end
    else
        if StoreDamageAccuratly then
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(damage), plate})
        else
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ? WHERE plate = ?', {state, garage, fuel, engine, body, json.encode(properties), plate})
        end
    end
end)
```
Locate qb-garage:server:updateVehicleState and replace with the code below
```lua
RegisterNetEvent('qb-garage:server:updateVehicleState', function(state, plate, garage)
    local hasFakePlate = exports['brazzers-fakeplates']:getPlateFromFakePlate(plate)
    if hasFakePlate then plate = hasFakePlate end
    Wait(100)

    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, depotprice = ? WHERE plate = ?',{state, garage, 0, plate})
end)
```
Locate qb-garage:server:spawnvehicle and replace with the code below
```lua
QBCore.Functions.CreateCallback('qb-garage:server:spawnvehicle', function (source, cb, vehInfo, coords, warp)
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)
    local hasFakePlate = exports['brazzers-fakeplates']:getFakePlateFromPlate(vehInfo.plate)

    if not veh or not NetworkGetNetworkIdFromEntity(veh) then
        print('ISSUE HERE', veh, NetworkGetNetworkIdFromEntity(veh))
    end
    local vehProps = {}
    local plate = vehInfo.plate
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}
    if hasFakePlate then SetVehicleNumberPlateText(veh, hasFakePlate) else SetVehicleNumberPlateText(veh, vehInfo.plate) end
    cb(netId, vehProps)
end)
```
Locate qb-garage:server:checkOwnership and replace with the code below
```lua
QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, garageType, garage, gang)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    local hasHouseKey = false

    if garageType == "public" then        --Public garages only for player cars
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    elseif garageType == "house" then     --House garages only for player cars that have keys of the house
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, garage)
                cb(hasHouseKey)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?',{plate}, function(fakeplate)
                    if fakeplate[1] then
                        hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, garage)
                        cb(hasHouseKey)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    elseif garageType == "gang" then        --Gang garages only for gang members cars (for sharing)
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                local Player = QBCore.Functions.GetPlayer(source)
                local playerGang = Player.PlayerData.gang.name
                cb(playerGang == gang)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?',{plate}, function(fakeplate)
                    if fakeplate[1] then
                        local Player = QBCore.Functions.GetPlayer(source)
                        local playerGang = Player.PlayerData.gang.name
                        cb(playerGang == gang)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''
        if not TableContains(SharedJobGarages, garage) then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?',{plate}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    end
end)
```

## Features
1. Persistent Fake Plates ( Saves through garages )
2. Synced Plate Changing
3. Multi-Language Support using QBCore Locales
4.  24/7 Support in discord

## Dependencies
1. qb-target
2. oxmysql
3. qb-vehiclekeys