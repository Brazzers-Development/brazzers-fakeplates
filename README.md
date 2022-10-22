# Installation steps

## General Setup
Very simple persistent fake plate script. I didn't see one made so here you go

Preview: [SOON]

## Installation
Locate your spawn vehicle callback in your qb-garages and replace with the one below: 
```lua
QBCore.Functions.CreateCallback('qb-garage:server:spawnvehicle', function (source, cb, vehInfo, coords, warp)
    local plate = vehInfo.plate
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)
    local hasFakePlate = exports['brazzers-fakeplates']:hasFakePlate(plate)
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

## Features
1. Persistent Fake Plates ( Saves through garages )
2. Synced Plate Changing
3. Multi-Language Support using QBCore Locales
4.  24/7 Support in discord

## Dependencies
1. qb-target
2. oxmysql
3. qb-vehiclekeys