mythic_action = {
    name = "",
    duration = 0,
    label = "",
    useWhileDead = false,
    canCancel = true,
    controlDisables = {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = false,
    },
    animation = {
        {animDict = nil, anim = nil, flags = 0, task = nil},
    },
    prop = {
        {
            model = nil, bone = nil,
            coords = { x = 0.0, y = 0.0, z = 0.0 },
            rotation = { x = 0.0, y = 0.0, z = 0.0 }
        },
    },
}

local isDoingAction = false
local disableMouse = false
local wasCancelled = false
local isAnim = false
local isProp = false
local prop_net = nil

RegisterNetEvent("mythic_progbar:client:progress")
AddEventHandler("mythic_progbar:client:progress", function(action, cb)
    mythic_action = action

    if not IsEntityDead(GetPlayerPed(-1)) or mythic_action.useWhileDead then
        if not isDoingAction then
            isDoingAction = true
            wasCancelled = false
            isAnim = false
            isProp = false

            SendNUIMessage({
                action = "mythic_progress",
                duration = mythic_action.duration,
                label = mythic_action.label
            })

            Citizen.CreateThread(function ()
                while isDoingAction do
                    Citizen.Wait(0)
                    if IsControlJustPressed(0, 178) and mythic_action.canCancel then
                        TriggerEvent("mythic_progbar:client:cancel")
                    end
                end
                if cb ~= nil then
                    cb(wasCancelled)
                end
            end)
        else
            print('Action Already Performing') -- Replace with alert call if you want the player to see this warning on-screen
        end
    else
        print('Cannot do action while dead') -- Replace with alert call if you want the player to see this warning on-screen
    end
end)

RegisterNetEvent("mythic_progbar:client:cancel")
AddEventHandler("mythic_progbar:client:cancel", function()
    isDoingAction = false
    wasCancelled = true

    TriggerEvent("mythic_progbar:client:actionCleanup")

    SendNUIMessage({
        action = "mythic_progress_cancel"
    })
end)

RegisterNetEvent("mythic_progbar:client:actionCleanup")
AddEventHandler("mythic_progbar:client:actionCleanup", function()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    StopAnimTask(ped, mythic_action.animDict, mythic_action.anim, 1.0)

    local obj = not (prop_net == 0 or prop_net == nil) and NetToObj(prop_net) or 0
    if DoesEntityExist(obj) then
        DetachEntity(obj, 1, 1)
        DeleteEntity(obj)
    end

    prop_net = nil
end)

-- Disable controls while GUI open
Citizen.CreateThread(function()
    while true do
        if isDoingAction then
            if not isAnim then
                if mythic_action.animation ~= nil then
                    for k,v in ipairs(mythic_action.animation) do
                        if v.task ~= nil then
                            TaskStartScenarioInPlace(PlayerPedId(), v.task, 0, true)
                        elseif v.animDict ~= nil and v.anim ~= nil then
                            if v.flags == nil then
                                v.flags = 1
                            end
    
                            local player = PlayerPedId()
                            if ( DoesEntityExist( player ) and not IsEntityDead( player )) then
                                loadAnimDict( v.animDict )
                                TaskPlayAnim( player, v.animDict, v.anim, 3.0, 1.0, -1, v.flags, 0, 0, 0, 0 )     
                            end
                        else
                            TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_BUM_BIN', 0, true)
                        end
                    end 
                end

                isAnim = true
            end

            if not isProp and mythic_action.prop ~= nil then
                for k, v in ipairs(mythic_action.prop) do
                    if v.model ~= nil then
                        RequestModel(v.model)

                        while not HasModelLoaded(GetHashKey(v.model)) do
                            Citizen.Wait(0)
                        end

                        local pCoords = GetOffsetFromEntityInWorldCoords(GetPlayerPed(PlayerId()), 0.0, 0.0, 0.0)
                        local modelSpawn = CreateObject(GetHashKey(v.model), pCoords.x, pCoords.y, pCoords.z, true, true, true)

                        local netid = ObjToNet(modelSpawn)
                        SetNetworkIdExistsOnAllMachines(netid, true)
                        NetworkSetNetworkIdDynamic(netid, true)
                        SetNetworkIdCanMigrate(netid, false)
                        if v.bone == nil then
                            v.bone = 60309
                        end

                        if v.coords == nil then
                            v.coords = { x = 0.0, y = 0.0, z = 0.0 }
                        end

                        if v.rotation == nil then
                            v.rotation = { x = 0.0, y = 0.0, z = 0.0 }
                        end

                        AttachEntityToEntity(modelSpawn, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), v.bone), v.coords.x, v.coords.y, v.coords.z, v.rotation.x, v.rotation.y, v.rotation.z, 1, 1, 0, 1, 0, 1)
                        prop_net = netid
                    end
                end
                
                isProp = true
            end

            DisableActions(GetPlayerPed(-1))
        end
        Citizen.Wait(0)
    end
end)

function loadAnimDict(dict)
	while (not HasAnimDictLoaded(dict)) do
		RequestAnimDict(dict)
		Citizen.Wait(5)
	end
end

function DisableActions(ped)
    if mythic_action.controlDisables.disableMouse then
        DisableControlAction(0, 1, true) -- LookLeftRight
        DisableControlAction(0, 2, true) -- LookUpDown
        DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
    end

    if mythic_action.controlDisables.disableMovement then
        DisableControlAction(0, 30, true) -- disable left/right
        DisableControlAction(0, 31, true) -- disable forward/back
        DisableControlAction(0, 36, true) -- INPUT_DUCK
        DisableControlAction(0, 21, true) -- disable sprint
    end

    if mythic_action.controlDisables.disableCarMovement then
        DisableControlAction(0, 63, true) -- veh turn left
        DisableControlAction(0, 64, true) -- veh turn right
        DisableControlAction(0, 71, true) -- veh forward
        DisableControlAction(0, 72, true) -- veh backwards
        DisableControlAction(0, 75, true) -- disable exit vehicle
    end

    if mythic_action.controlDisables.disableCombat then
        DisablePlayerFiring(ped, true) -- Disable weapon firing
        DisableControlAction(0, 24, true) -- disable attack
        DisableControlAction(0, 25, true) -- disable aim
        DisableControlAction(1, 37, true) -- disable weapon select
        DisableControlAction(0, 47, true) -- disable weapon
        DisableControlAction(0, 58, true) -- disable weapon
        DisableControlAction(0, 140, true) -- disable melee
        DisableControlAction(0, 141, true) -- disable melee
        DisableControlAction(0, 142, true) -- disable melee
        DisableControlAction(0, 143, true) -- disable melee
        DisableControlAction(0, 263, true) -- disable melee
        DisableControlAction(0, 264, true) -- disable melee
        DisableControlAction(0, 257, true) -- disable melee
    end
end

RegisterNUICallback('actionFinish', function(data, cb)
    -- Do something here
    isDoingAction = false
    TriggerEvent("mythic_progbar:client:actionCleanup")
    cb('ok')
end)

RegisterNUICallback('actionCancel', function(data, cb)
    -- Do something here
    cb('ok')
end)
