![Brazzers Development Discord](https://i.imgur.com/nXhPxIO.png)

<details>
    <summary><b>Important Links</b></summary>
        <p>
            <a href="https://discord.gg/J7EH9f9Bp3">
                <img alt="GitHub" src="https://logos-download.com/wp-content/uploads/2021/01/Discord_Logo_full.png"
                width="150" height="55">
            </a>
        </p>
        <p>
            <a href="https://ko-fi.com/mannyonbrazzers">
                <img alt="GitHub" src="https://uploads-ssl.webflow.com/5c14e387dab576fe667689cf/61e11149b3af2ee970bb8ead_Ko-fi_logo.png"
                width="150" height="55">
            </a>
        </p>
</details>

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
    SetEntityHeading(veh, coords.w)

    local vehProps = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}

    if hasFakePlate then 
        SetVehicleNumberPlateText(veh, hasFakePlate)
        TriggerClientEvent("vehiclekeys:client:SetOwner", source, hasFakePlate)
    else 
        SetVehicleNumberPlateText(veh, plate)
        TriggerClientEvent("vehiclekeys:client:SetOwner", source, plate)
    end
    
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
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ? AND citizenid = ?', {plate, pData.PlayerData.citizenid}, function(fakeplate)
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
                    cb(false)
                end
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
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
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''
        if not Config["SharedGarages"] then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?'..shared, {plate}, function(fakeplate)
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
                    if Config.Garages[garage] then                                                             --Check if garage is existing
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
        if Config.StoreDamageAccuratly then
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), json.encode(damage), plate})
        else
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), plate})
        end
    else
        if Config.StoreDamageAccuratly then
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
    local plate = vehInfo.plate
    local hasFakePlate = exports['brazzers-fakeplates']:getFakePlateFromPlate(plate)
    
    if not veh or not NetworkGetNetworkIdFromEntity(veh) then
        print('ISSUE HERE', veh, NetworkGetNetworkIdFromEntity(veh))
    end
    local vehProps = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}

    if hasFakePlate then 
        SetVehicleNumberPlateText(veh, hasFakePlate)
        TriggerClientEvent("vehiclekeys:client:SetOwner", source, hasFakePlate)
    else 
        SetVehicleNumberPlateText(veh, plate)
        TriggerClientEvent("vehiclekeys:client:SetOwner", source, plate)
    end

    cb(netId, vehProps)
end)
```
Locate qb-garage:server:checkOwnership and replace with the code below
```lua
QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, garageType, garage, gang)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if garageType == "public" then        --Public garages only for player cars
        local addSQLForAllowParkingAnyonesVehicle = ""
        if not Config.AllowParkingAnyonesVehicle then
            addSQLForAllowParkingAnyonesVehicle = " AND citizenid = '"..pData.PlayerData.citizenid.."' "
        end
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? ' .. addSQLForAllowParkingAnyonesVehicle,{plate}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate}, function(fakeplate)
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
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    elseif garageType == "gang" then        --Gang garages only for gang members cars (for sharing)
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                --Check if found owner is part of the gang
                local Player = QBCore.Functions.GetPlayer(source)
                local playerGang = Player.PlayerData.gang.name
                cb(playerGang == gang)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?', {plate}, function(fakeplate)
                    if fakeplate[1] then
                        cb(true)
                    else
                        cb(false)
                    end
                end)
            end
        end)
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''
        if not TableContains(Config.SharedJobGarages, garage) then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate}, function(result)
            if result[1] then
                cb(true)
            else
                MySQL.query('SELECT * FROM player_vehicles WHERE fakeplate = ?'..shared, {plate}, function(fakeplate)
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
Locate the qb-garage:server:GetVehicleProperties callback and replace with the one below
```lua
QBCore.Functions.CreateCallback("qb-garage:server:GetVehicleProperties", function(source, cb, plate)
    local properties = {}
    local hasFakePlate = exports['brazzers-fakeplates']:getFakePlateFromPlate(plate)
    if hasFakePlate then plate = hasFakePlate end
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then
        properties = json.decode(result[1].mods)
    end
    cb(properties)
end)
```

## Exports Usage
This gets the original plate from the fake plate. Input the fake plate number in the plate param
```lua
    local originalPlate = exports['brazzers-fakeplates']:getPlateFromFakePlate(plate)
    if originalPlate then plate = originalPlate end
```
This gets the fake plate from the original plate. Input the original plate number in the plate param
```lua
    local fakePlate = exports['brazzers-fakeplates']:getFakePlateFromPlate(plate)
    if fakePlate then plate = fakePlate end
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