local crypt = require('cryptography')
local gui = require('gui')

interface = {}

interface.keys = {}

interface.fps = 1/60
interface.storages = {}
interface.fullStorages = {}
interface.currDrive = nil
interface.monitor = nil
interface.modem = nil
interface.reactor = nil
interface.snapshot = nil
interface.settings = nil
interface.initialized = false
interface.session = {}
interface.automations = {
    ['reactorToggle'] = true,
    ['turbineToggle'] = true,
    ['inductorToggle'] = true,
    ['powerToggle'] = true, -- Reactor if no turbine
    ['vaporToggle'] = true,
    ['tempToggle'] = true,
    ['controlRodsToggle'] = true,
    ['turbineSpeedToggle'] = false,
    ['turbineEfficiencyToggle'] = true,
    ['powerMin'] = 10,
    ['powerMax'] = 90,
    ['vaporMin'] = 10,
    ['vaporMax'] = 90,
    ['tempMin'] = 10,
    ['tempMax'] = 2000,
    ['turbineSpeedTarget'] = 1800,
    ['lastTimeTurbineSpeed'] = 0,
}

function interface.write(text)
    if text ~= nil then
        gui.log(text, interface.selectDrive())
    end
    if not interface.initialized then
        local _, y = term.current().getSize()
        term.setCursorPos(1, y)
        textutils.slowWrite(text)
        term.scroll(1)
    end
end --end write

function interface.findDrives()
    for _, i in pairs(peripheral.getNames()) do
        if string.find(peripheral.getType(i), 'drive') then
            table.insert(interface.storages, i)
        end
    end
end --end findDrives

function interface.checkIfKeyInTable(table, key)
    for _, i in pairs(table) do
        if i == key then
            return true
        end
    end
    return false
end -- end checkIfKeyInTable
  
function interface.selectDrive()
    if interface.currDrive ~= nil then
        if peripheral.wrap(interface.currDrive).isDiskPresent() then
            if fs.getFreeSpace(peripheral.wrap(interface.currDrive).getMountPath()) > 500 then
                return peripheral.wrap(interface.currDrive).getMountPath()..'/'
            end
        end
    end
    for _, i in pairs(interface.storages) do
        if peripheral.wrap(i).isDiskPresent() then
            if fs.getFreeSpace(peripheral.wrap(i).getMountPath()) > 500 then
                interface.currDrive = i
                gui.log('Now saving logs to '..interface.currDrive, interface.selectDrive())
                return peripheral.wrap(i).getMountPath()..'/'
            else
                if interface.checkIfKeyInTable(interface.fullStorages, i) == false then
                    table.insert(interface.fullStorages, i)
                end
            end
        end
    end
    return './'
end --end selectDrive
  
function interface.checkDriveStorage()
    for _, i in pairs(interface.fullStorages) do
        if peripheral.wrap(i).isDiskPresent() then
            if fs.getFreeSpace(peripheral.wrap(i).getMountPath()) > 500 then
                interface.fullStorages[i] = nil
            else
                gui.log(peripheral.wrap(i).getMountPath()..' is full.', server.selectDrive())
            end
        end
    end
end --end checkDriveStorage

function interface.getComputerInfo()
    return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end --end getComputerInfo

function interface.checkForMonitor()
    for _, i in pairs(peripheral.getNames()) do
        if peripheral.getType(i) == 'monitor' then
            interface.write('Monitor found!')
            -- return peripheral.wrap(i)
            local width, height = peripheral.wrap(i).getSize()
            return window.create(peripheral.wrap(i), 1, 1, width, height)
        end
    end
    interface.write('Could not find a monitor, using terminal.')
    local width, height = term.current().getSize()
    return window.create(term.current(), 1, 1, width, height)
end --end checkForMonitor
  
function interface.initializeMonitor()
    interface.monitor.clear()
    interface.monitor.setCursorPos(1,1)
    gui.initialize(interface.monitor)
end --end initializeMonitor

function interface.checkForWirelessModem()
    for _, i in pairs(peripheral.getNames()) do
        if peripheral.getType(i) == 'modem' then
            if peripheral.call(i, 'isWireless') then
                interface.write('Wireless Modem found!')
                return peripheral.wrap(i)
            end
        end
    end
    return false
end --end checkForWirelessModem

function interface.initializeNetwork()
    --['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
    if not interface.modem.isOpen(14) then
        interface.modem.open(14)
    end
    if not interface.modem.isOpen(21) then
        interface.modem.open(21)
    end
end --end initializeNetwork

function interface.checkForReactor()
    for _, i in pairs(peripheral.getNames()) do
        if string.find(peripheral.getType(i), '-Reactor') ~= nil then
            if peripheral.call(i, 'mbIsAssembled') then
                interface.write('Reactor found!')
                return peripheral.wrap(i)
            end
        end
    end
    return false
end --end checkForReactor

function interface.checkForTurbine()
    for _, i in pairs(peripheral.getNames()) do
        if string.find(peripheral.getType(i), '-Turbine') ~= nil then
            if peripheral.call(i, 'mbIsAssembled') then
                interface.write('Turbine found!')
                return peripheral.wrap(i)
            end
        end
    end
    return false
end --end checkForReactor

function interface.reactorGetControlRodsInfo()
    local info = {
        ['rodLevels'] = interface.reactor.getControlRodsLevels(),
        ['quantity'] = interface.reactor.getNumberOfControlRods(),
        ['rods'] = {},
    }
    for i=0, info['quantity']-1 do
        table.insert(info['rods'], {
            ['name'] = interface.reactor.getControlRodName(i),
            ['level'] = interface.reactor.getControlRodLevel(i),
            ['location'] = interface.reactor.getControlRodLocation(i),
            ['id'] = i,
        })
        -- info['rods'][i] = {
        --     ['name'] = interface.reactor.getControlRodName(i),
        --     ['level'] = interface.reactor.getControlRodLevel(i),
        --     ['location'] = interface.reactor.getControlRodLocation(i),
        -- }
    end
    return info
end --end getControlRodsInfo

function interface.reactorGetCoolantInfo()
    local info = {
        ['amount'] = interface.reactor.getCoolantAmount(),
        ['max'] = interface.reactor.getCoolantAmountMax(),
        ['stats'] = interface.reactor.getCoolantFluidStats(),
        ['type'] = interface.reactor.getCoolantType(),
    }
    return info
end --end getCoolantInfo

function interface.reactorGetEnergyInfo()
    local info = {
        ['capacity'] = interface.reactor.getEnergyCapacity(),
        ['lastTick'] = interface.reactor.getEnergyProducedLastTick(),
        ['stats'] = interface.reactor.getEnergyStats(),
        ['stored'] = interface.reactor.getEnergyStored(),
        ['storedText'] = interface.reactor.getEnergyStoredAsText(),
    }
    return info
end --end getEnergyInfo

function interface.reactorGetFuelInfo()
    local info = {
        ['amount'] = interface.reactor.getFuelAmount(),
        ['max'] = interface.reactor.getFuelAmountMax(),
        ['lastTick'] = interface.reactor.getFuelConsumedLastTick(),
        ['stats'] = interface.reactor.getFuelStats(),
        ['reactivity'] = interface.reactor.getFuelReactivity(),
        ['temperature'] = interface.reactor.getFuelTemperature(),
    }
    return info
end --end getFuelInfo

function interface.reactorGetHotFluidInfo()
    local info = {
        ['amount'] = interface.reactor.getHotFluidAmount(),
        ['max'] = interface.reactor.getHotFluidAmountMax(),
        ['lastTick'] = interface.reactor.getHotFluidProducedLastTick(),
        ['stats'] = interface.reactor.getHotFluidStats(),
        ['type'] = interface.reactor.getHotFluidType(),
    }
    return info
end --end getHotFluidInfo

function interface.reactorGetMBInfo()
    local info = {
        ['min'] = interface.reactor.mbGetMinimumCoordinate(),
        ['max'] = interface.reactor.mbGetMaximumCoordinate(),
        ['controllerType'] = interface.reactor.mbGetMultiblockControllerTypeName(),
        ['assembled'] = interface.reactor.mbIsAssembled(),
        ['connected'] = interface.reactor.mbIsConnected(),
        ['disassembled'] = interface.reactor.mbIsDisassembled(),
        ['paused'] = interface.reactor.mbIsPaused(),
    }
    return info
end --end getMBInfo

function interface.turbineGetEnergyInfo()
    local info = {
        ['capacity'] = interface.turbine.getEnergyCapacity(),
        ['lastTick'] = interface.turbine.getEnergyProducedLastTick(),
        ['stats'] = interface.turbine.getEnergyStats(),
        ['stored'] = interface.turbine.getEnergyStored(),
        ['storedText'] = interface.turbine.getEnergyStoredAsText(),
    }
    return info
end

function interface.turbineGetFluidInfo()
    local info = {
        ['max'] = interface.turbine.getFluidAmountMax(),
        ['flowRate'] = interface.turbine.getFluidFlowRate(),
        ['flowRateMax'] = interface.turbine.getFluidFlowRateMax(),
        ['flowRateMaxMax'] = interface.turbine.getFluidFlowRateMaxMax(), -- Yes this is a function... Strangely
    }
    return info
end

function interface.turbineRotorInfo()
    local info = {
        ['bladeEfficiency'] = interface.turbine.getBladeEfficiency(),
        ['bladeQuantity'] = interface.turbine.getNumberOfBlades(),
        ['rotorMass'] = interface.turbine.getRotorMass(),
        ['rotorSpeed'] = interface.turbine.getRotorSpeed(),
    }
    return info
end

function interface.turbineIOInfo()
    local info = {
        ['inputAmount'] = interface.turbine.getInputAmount(),
        ['inputType'] = interface.turbine.getInputType(),
        ['outputAmount'] = interface.turbine.getOutputAmount(),
        ['outputType'] = interface.turbine.getOutputType(),
    }
    return info
end

function interface.reactorSnapshot()
    local info = {
        ['status'] = interface.reactor.getActive(),
        ['casingTemperature'] = interface.reactor.getCasingTemperature(),
        ['variation'] = interface.reactor.getVariant(),
        ['wasteAmount'] = interface.reactor.getWasteAmount(),
        ['activelyCooled'] = interface.reactor.isActivelyCooled(),
        ['coolantInfo'] = interface.reactorGetCoolantInfo(),
        ['energyInfo'] = interface.reactorGetEnergyInfo(),
        ['fuelInfo'] = interface.reactorGetFuelInfo(),
        ['hotFluidInfo'] = interface.reactorGetHotFluidInfo(),
        ['rodInfo'] = interface.reactorGetControlRodsInfo(),
        ['mbLocation'] = interface.reactorGetMBInfo(),
    }
    return info
end

function interface.turbineSnapshot()
    local info = {
        ['status'] = interface.turbine.getActive(),
        ['variation'] = interface.turbine.getVariant(),
        ['inductorStatus'] = interface.turbine.getInductorEngaged(),
        ['energyInfo'] = interface.turbineGetEnergyInfo(),
        ['fluidInfo'] = interface.turbineGetFluidInfo(),
        ['rotorInfo'] = interface.turbineRotorInfo(),
        ['ioInfo'] = interface.turbineIOInfo(),
    }
    return info
end

function interface.generateSnapshots() -- Run in parallel
    while true do
        -- gui.log('Parallel - Snapshot Handler')
        interface.snapshot = {
            ['report'] = {['datestamp'] = os.date("%F %T"), ['origin'] = interface.getComputerInfo(), ['timestamp'] = os.epoch('local')},
            ['automations'] = interface.automations,
        }
        if interface.reactor ~= false then
            interface.snapshot['reactor'] = interface.reactorSnapshot()
        else
            interface.snapshot['reactor']['status'] = nil
        end
        if interface.turbine ~= false then
            interface.snapshot['turbine'] = interface.turbineSnapshot()
        else
            interface.snapshot['turbine']['status'] = nil
        end
        gui.updateSnapshot(interface.snapshot)
        os.sleep(interface.fps)
    end
end --end generateSnapshots

function interface.generatePrivatePublicKeys()
    if not fs.exists('/er_interface/keys/private.key') then
        local file = fs.open('./er_interface/keys/parameters.tmp', 'r')
        local params = textutils.unserialize(file.read())
        file.close()
        local privateKey, publicKey = crypt.generatePrivatePublicKeys(params['p'], params['g'])
        local file = fs.open('/er_interface/keys/private.key', 'w')
        file.write(privateKey)
        file.close()
        local file = fs.open('/er_interface/keys/public.key', 'w')
        file.write(publicKey)
        file.close()
    end
end --end generatePrivatePublicKeys

function interface.readPrivateKey()
    if fs.exists('/er_interface/keys/private.key') then
        local file = fs.open('/er_interface/keys/private.key', 'r')
        local key = tonumber(file.readAll())
        file.close()
        return key
    else
        interface.generatePrivatePublicKeys()
        return interface.readPrivateKey()
    end
end --end readPrivateKey

function interface.generateKeyParameters() -- Run in parallel
    while true do
        -- gui.log('Parallel - Parameter Handler')
        if fs.exists('./er_interface/keys/parameters.tmp') then
            os.sleep(60*5) -- Generate new ones every Five Minutes
            local p, g = crypt.generateParameters(10000, 100000)
            local file = fs.open('./er_interface/keys/parameters.tmp', 'w')
            file.write(textutils.serialize({['p'] = p, ['g'] = g}))
            file.close()
        else
            local p, g = crypt.generateParameters(1000, 10000)
            local file = fs.open('./er_interface/keys/parameters.tmp', 'w')
            file.write(textutils.serialize({['p'] = p, ['g'] = g}))
            file.close()
        end
    end
end --end generateKeyParameters

function interface.broadcast() -- Run in parallel
    while true do
        os.sleep(0.5)
        local file = fs.open('./er_interface/keys/parameters.tmp', 'r')
        local params = textutils.unserialize(file.readAll())
        -- local params = file.read()
        file.close()
        local info = {
            ['origin'] = interface.getComputerInfo(),
            ['target'] = nil,
            ['packet'] = {
                ['type'] = 'broadcast',
                ['message'] = 'This is an automated broadcast sharing the ports information for an Extreme Reactor Control Server.',
                ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28},
                ['handshakeParams'] = params,
                -- ['snapshot'] = nil,
            }
        }
        for _,i in pairs(interface.readClients()) do
            if (os.epoch('local') - i['lastActivity'])/1000 < 60*5 then
                info['packet']['snapshot'] = crypt.xorEncryptDecrypt(interface.readSnapshotKey(), textutils.serialize(gui.snapshot))
                break
            end
        end
        interface.modem.transmit(7, 0, info)
    end
end --end broadcast

function interface.readSnapshotKey()
    if fs.exists('./er_interface/keys/snapshot.key') then
        local file = fs.open('./er_interface/keys/snapshot.key', 'r')
        local snapshotKey = file.readAll()
        file.close()
        return snapshotKey
    else
        local file = fs.open('./er_interface/keys/parameters.tmp', 'r')
        local params = textutils.unserialize(file.readAll())
        file.close()
        local private, _ = crypt.generatePrivatePublicKeys(params['p'], params['g'])
        local _, public2 = crypt.generatePrivatePublicKeys(params['p'], params['g'])
        local snapshotKey = crypt.generateSharedKey(private, public2, params['p'])
        local file = fs.open('./er_interface/keys/snapshot.key', 'w')
        file.write(snapshotKey)
        file.close()
        return snapshotKey
    end
end --end readSnapshotKey

function interface.eventHandler() -- Run in parallel
    local timer = os.startTimer(60*5)
    while true do
        -- gui.log('Parallel - Event Handler')
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        -- gui.log(tostring(event)..tostring(arg1)..tostring(arg2)..tostring(arg3)..tostring(arg4)..tostring(arg5))
        -- if event == 'timer' then
        --     interface.broadcast()
        --     timer = os.startTimer(5) --------------------------------------------------------------------------------------------------------------------------------
        if event == 'modem_message' then
            interface.checkMessages(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_up' or event == 'monitor_touch' then
            interface.clickedButton(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_scroll' then
            interface.mouseWheel(event, arg1, arg2, arg3, arg4, arg5)
        end
    end
end --end eventHandler

function interface.readClients()
    local file = fs.open('./er_interface/keys/clients', 'r')
    local clients = textutils.unserialize(file.readAll())
    file.close()
    return clients
end --end readClients

function interface.writeClients(clients)
    local file = fs.open('./er_interface/keys/clients', 'w')
    file.write(textutils.serialize(clients))
    -- local clients = textutils.serialize(clients)
    file.close()
end --end writeClients

function interface.compareElementsByID(a, b)
    return tonumber(a) < tonumber(b)
end --end compareKeys

function interface.addNewClient(client)
    local clients = interface.readClients()
    table.insert(clients, client)
    -- if #clients == 0 then
    --     clients[1] = client
    -- else
    --     clients[#clients+1] = client
    -- end
    -- gui.log(textutils.serialize{['clientsLength'] = #clients, ['clientsPlusOne'] = #clients+1, ['clients'] = clients})
    interface.writeClients(clients)
end

function interface.removeClient(client)
    local clients = interface.readClients()
    for k, v in pairs(clients) do
        -- gui.log(textutils.serialize({['k'] = k, ['v'] = v, ['client'] = client}))
        if v['id'] == client['id'] then
            table.remove(clients, k)
            interface.writeClients(clients)
            -- client[k] = nil
            -- for i=k, #clients do
            --     if clients[i+1] ~= nil then
            --         clients[i] = clients[i+1]
            --         clients[i+1] = nil
            --     else
            --         break
            --     end
            -- end
            break
        end
    end
end

function interface.getClientInfo(client)
    local clients = interface.readClients()
    for k, v in pairs(clients) do
        if v['id'] == client['id'] then
            return v
        end
    end
    return false
end

function interface.updateClient(client)
    local clients = interface.readClients()
    for k, v in pairs(clients) do
        if v['id'] == client['id'] then
            -- gui.log(textutils.serialize({['newClient'] = client, ['oldClient'] = v, ['vClient'] = v, ['kClient'] = clients[k]}))
            clients[k] = client
            interface.writeClients(clients)
            break
        end
    end
end

function interface.checkMessages(event, side, channel, replyChannel, message, distance)
    -- ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28},
    -- Message Format: {['origin'] = {}, ['target'] = {}, ['packet'] = {}}
    -- ['packet'] = crypt.encrpt(sharedKey, )
    if channel == 14 then -- Handshakes
        if message['target'] ~= nil then
            if message['target']['id'] == interface.getComputerInfo()['id'] and message['target']['label'] == interface.getComputerInfo()['label'] then
                if message['origin'] ~= nil then
                    -- local clients = interface.readClients()
                    -- if clients[message['origin']['id']] ~= nil then -- Exists
                    local client = interface.getClientInfo(message['origin'])
                    if client ~= false then -- Exists
                        if message['packet']['attempt'] ~= nil then
                            interface.modem.transmit(14, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(client['sharedKey'], 'success')})
                            if crypt.xorEncryptDecrypt(client['sharedKey'], message['packet']['attempt']) ~= 'success' then -- Unsuccessful handshake, start over.
                                interface.removeClient({['id'] = message['origin']['id']})
                                -- clients[message['origin']['id']] = nil
                                -- interface.writeClients(clients)
                            end
                        end
                    else -- Add to clients & their public key & parameters
                        if message['packet']['p'] ~= nil and message['packet']['g'] ~= nil and message['packet']['publicKey'] ~= nil then
                            -- clients[message['origin']['id']] = message['origin']
                            -- clients[message['origin']['label']]['p'] = message['packet']['p']
                            -- clients[message['origin']['label']]['g'] = message['packet']['g']
                            -- clients[message['origin']['label']]['privateKey'], clients[message['origin']['label']]['publicKey'] = crypt.generatePrivatePublicKeys(message['packet']['p'], message['packet']['g'])
                            local privateKey, publicKey = crypt.generatePrivatePublicKeys(message['packet']['p'], message['packet']['g'])
                            interface.modem.transmit(14, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = {['publicKey'] = publicKey}})
                            -- clients[message['origin']['id']]['sharedKey'] = crypt.generateSharedKey(privateKey, message['packet']['publicKey'], message['packet']['p'])
                            -- clients[message['origin']['id']]['creationTimestamp'] = os.epoch('local')
                            -- clients[message['origin']['id']]['lastLogin'] = os.epoch('local')
                            -- clients[message['origin']['id']]['lastActivity'] = os.epoch('local')
                            local client = {
                                ['id'] = message['origin']['id'],
                                ['label'] = message['origin']['label'],
                                ['sharedKey'] = crypt.generateSharedKey(privateKey, message['packet']['publicKey'], message['packet']['p']),
                                ['creationTimestamp'] = os.epoch('local'),
                                ['lastLogin'] = os.epoch('local'),
                                ['lastActivity'] = os.epoch('local')
                            }
                            interface.addNewClient(client)
                            -- table.sort(clients, interface.compareElementsByID)
                            -- interface.writeClients(clients)
                            -- interface.modem.transmit(14, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = {['publicKey'] = clients[message['origin']['label']]['publicKey']}})
                        end
                    end
                end
            end
        end
    elseif channel == 21 then -- Requests, login attempts, issue commands
        if message['target'] ~= nil then
            if message['target']['id'] == interface.getComputerInfo()['id'] and message['target']['label'] == interface.getComputerInfo()['label'] then
                if message['origin'] ~= nil then
                    -- local clients = interface.readClients()
                    local client = interface.getClientInfo(message['origin'])
                    -- if clients[message['origin']['id']] ~= nil then -- Exists
                    if client ~= false then
                        -- if session[messager['origin']['label']] -- Check if already logged in (TBD)
                        if client['id'] == message['origin']['id'] then 
                            local decryptedMsg = textutils.unserialize(crypt.xorEncryptDecrypt(client['sharedKey'], message['packet']))
                            if decryptedMsg['type'] == 'login' then
                                if interface.verifyLogin(decryptedMsg['data']) then
                                    gui.log('User logged in from '..message['origin']['label']..' with device id '..message['origin']['id'])
                                    -- interface.session[message['origin']['label']] = message['origin']
                                    -- interface.session[message['origin']['label']]['timestamp'] = os.clock()
                                    interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(client['sharedKey'], textutils.serialize({['type'] = 'login', ['data'] = 'Granted'}))})
                                    -- clients[message['origin']['id']]['lastLogin'] = os.epoch('local')
                                    -- clients[message['origin']['id']]['lastActivity'] = os.epoch('local')
                                    client['lastLogin'] = os.epoch('local')
                                    client['lastActivity'] = os.epoch('local')
                                    interface.updateClient(client)
                                    -- interface.writeClients(clients)
                                else
                                    gui.log('Failed login attempt from: '..message['origin']['label']..' with ID '..message['origin']['id'])
                                    interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(client['sharedKey'], textutils.serialize({['type'] = 'login', ['data'] = 'Denied'}))})
                                end
                            elseif decryptedMsg['type'] == 'snapshotKey' then
                                -- interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(clients[message['origin']['id']..'_'..message['origin']['label']]['sharedKey'], textutils.serialize({['type'] = 'snapshot', ['data'] = gui.snapshot}))})
                                interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(client['sharedKey'], textutils.serialize({['type'] = 'snapshotKey', ['data'] = interface.readSnapshotKey()}))})
                                client['lastActivity'] = os.epoch('local')
                                interface.updateClient(client)
                                os.sleep(interface.fps)
                            elseif decryptedMsg['type'] == 'command' then
                                if gui.checkIfTableContains({
                                    'turbineToggle', 
                                    'inductorToggle', 
                                    'turbineEfficiencyToggle',
                                    'turbineSpeedToggle',
                                    'powerToggle', 
                                    'reactorToggle',
                                    'controlRodsToggle', 
                                    'tempToggle', 
                                    'vaporToggle',
                                }, decryptedMsg['data']) then
                                    if gui.snapshot['automations'][decryptedMsg['data']] then
                                        if decryptedMsg['data'] == 'turbineEfficiencyToggle' then
                                            interface.automations['turbineSpeedToggle'] = true
                                        elseif decryptedMsg['data'] == 'turbineSpeedToggle' then
                                            interface.automations['turbineEfficiencyToggle'] = true
                                        end
                                        interface.automations[decryptedMsg['data']] = false
                                    else
                                        if decryptedMsg['data'] == 'turbineEfficiencyToggle' then
                                            interface.automations['turbineSpeedToggle'] = false
                                        elseif decryptedMsg['data'] == 'turbineSpeedToggle' then
                                            interface.automations['turbineEfficiencyToggle'] = false
                                        end
                                        interface.automations[decryptedMsg['data']] = true
                                    end
                                    interface.writeAutomations()
                                elseif gui.checkIfTableContains({
                                    'toggleTurbine',
                                    'toggleInductor',
                                    'toggleReactor', 
                                }, decryptedMsg['data']) then
                                    if decryptedMsg['data'] == 'toggleTurbine' then
                                        if interface.turbine.getActive() then
                                            interface.turbine.setActive(false)
                                        else
                                            interface.turbine.setActive(true)
                                        end
                                        client['lastActivity'] = os.epoch('local')
                                        interface.updateClient(client)
                                    elseif decryptedMsg['data'] == 'toggleInductor' then
                                        if interface.turbine.getInductorEngaged() then
                                            interface.turbine.setInductorEngaged(false)
                                        else
                                            interface.turbine.setInductorEngaged(true)
                                        end
                                        client['lastActivity'] = os.epoch('local')
                                        interface.updateClient(client)
                                    elseif decryptedMsg['data'] == 'toggleReactor' then
                                        if interface.reactor.getActive() then
                                        interface.reactor.setActive(false)
                                        else
                                            interface.reactor.setActive(true)
                                        end
                                        client['lastActivity'] = os.epoch('local')
                                        interface.updateClient(client)
                                    end
                                elseif decryptedMsg['data'] == 'scram' then
                                    if gui.snapshot['reactor']['status'] then
                                        for k, v in pairs(gui.snapshot['reactor']['rodInfo']['rods']) do
                                            interface.reactor.setControlRodLevel(k, 100)
                                        end
                                        interface.reactor.setActive(false)
                                    end
                                    client['lastActivity'] = os.epoch('local')
                                    interface.updateClient(client)
                                end     
                            elseif decryptedMsg['type'] == 'adjustRod' then
                                if decryptedMsg['direction'] == 'up' then
                                    interface.reactor.setControlRodLevel(decryptedMsg['target']-1, gui.snapshot['reactor']['rodInfo']['rods'][decryptedMsg['target']]['level']+decryptedMsg['data'])
                                elseif decryptedMsg['direction'] == 'down' then
                                    interface.reactor.setControlRodLevel(decryptedMsg['target']-1, gui.snapshot['reactor']['rodInfo']['rods'][decryptedMsg['target']]['level']-decryptedMsg['data'])
                                end
                                interface.writeAutomations()
                                client['lastActivity'] = os.epoch('local')
                                interface.updateClient(client)
                            elseif gui.checkIfTableContains({
                                'powerMax',
                                'powerMin',
                                'vaporMax',
                                'vaporMin',
                            }, decryptedMsg['type']) then
                                if decryptedMsg['direction'] == 'up' then
                                    if not (interface.automations[decryptedMsg['type']]+decryptedMsg['data'] > 100) then
                                        interface.automations[decryptedMsg['type']] = interface.automations[decryptedMsg['type']]+decryptedMsg['data']
                                    end
                                elseif decryptedMsg['direction'] == 'down' then
                                    gui.log(string.sub(decryptedMsg['type'], 0, 5)..'Min')
                                    if not (interface.automations[decryptedMsg['type']]+decryptedMsg['data'] < interface.automations[string.sub(decryptedMsg['type'], 0, 5)..'Min']) then
                                        interface.automations[decryptedMsg['type']] = interface.automations[decryptedMsg['type']]-decryptedMsg['data']
                                    end
                                end
                                interface.writeAutomations()
                                client['lastActivity'] = os.epoch('local')
                                interface.updateClient(client)
                            elseif decryptedMsg['type'] == 'turbineSpeedTarget' then
                                if decryptedMsg['direction'] == 'up' then
                                    interface.automations['turbineSpeedTarget'] = interface.automations['turbineSpeedTarget']+decryptedMsg['data']
                                elseif decryptedMsg['direction'] == 'down' then
                                    if not (interface.automations['turbineSpeedTarget']+decryptedMsg['data'] < 0) then
                                        interface.automations['turbineSpeedTarget'] = interface.automations['turbineSpeedTarget']-decryptedMsg['data']
                                    end
                                end
                                interface.writeAutomations()
                                client['lastActivity'] = os.epoch('local')
                                interface.updateClient(client)
                            end
                        end
                    end
                end
            end
        end
    elseif channel == 28 then -- Data Transfers
    end
end --end checkMessages

function interface.clickedButton(event, button, x, y, arg4, arg5)
    gui.readSettings()
    if button == 1 or peripheral.isPresent(tostring(button)) then
        if y == 1 and x == gui.width then -- Terminate Program
            gui.monitor.setBackgroundColor(colors.black)
            gui.monitor.clear()
            gui.monitor.setTextColor(colors.red)
            print('ER Interface has been ')
            gui.monitor.setTextColor(colors.white)
            os.queueEvent('terminate')
            os.sleep(100)
        elseif y == gui.height then -- Previous/Next Buttons
            if x>=gui.width-6 and x<=gui.width-2 then --Next
                gui.nextPage(true)
            elseif x>=2 and x<=6 then --Prev
                gui.nextPage(false)
            end
        elseif y == 1 and x == gui.width-1 then -- Toggle Help Window
            if gui.toggleHelpWindow ~= true then
                if gui.helpWindow == false then
                    gui.helpWindow = window.create(gui.monitor, 1, math.floor(gui.height*0.1)+1, gui.width, gui.height-math.floor(gui.height*0.1)*2, false)
                    gui.settings['helpWindowWidth'], gui.settings['helpWindowHeight'] = gui.helpWindow.getSize()
                end
                gui.toggleHelpWindow = true
            else
                gui.toggleHelpWindow = false
                gui.helpWindow.setVisible(false)
            end
            gui.settings['mouseWheel'] = 0
            gui.writeSettings()
        elseif gui.toggleHelpWindow == true then -- Help Window Terminate
            if x == gui.width and y == math.floor(gui.height*0.1)+1 then
                gui.toggleHelpWindow = false
                gui.helpWindow.setVisible(false)
                gui.settings['mouseWheel'] = 0
                gui.writeSettings()
            end
        elseif y >= 3 and y <= gui.height-3 then
            if gui.settings['currentPageTitle'] == 'Reactor Summary' then
                if y == 8-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                    if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                        if interface.reactor.getActive() then
                            interface.reactor.setActive(false)
                        else
                            interface.reactor.setActive(true)
                        end
                    end
                end
            elseif gui.settings['currentPageTitle'] == 'Turbine Summary' then
                if y == 8-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                    if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                        if interface.turbine.getActive() then
                            interface.turbine.setActive(false)
                        else
                            interface.turbine.setActive(true)
                        end
                    end
                elseif y == 9-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                    if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                        if interface.turbine.getInductorEngaged() then
                            interface.turbine.setInductorEngaged(false)
                        else
                            interface.turbine.setInductorEngaged(true)
                        end
                    end
                end
            elseif gui.settings['currentPageTitle'] == 'Histograms' then
                if y == 4 then
                    if x == 2 then
                        if gui.snapshot['turbine']['status'] ~= nil and gui.snapshot['reactor']['status'] ~= nil then
                            if gui.settings['histogramTarget'] == 'turbinePower' then
                                gui.settings['histogramTarget'] = 'reactorCoolant'
                            elseif gui.settings['histogramTarget'] == 'turbineVapor' then
                                gui.settings['histogramTarget'] = 'turbinePower'
                            elseif gui.settings['histogramTarget'] == 'turbineCoolant' then
                                gui.settings['histogramTarget'] = 'turbineVapor'
                            elseif gui.settings['histogramTarget'] == 'reactorFuel' then
                                gui.settings['histogramTarget'] = 'turbineCoolant'
                            elseif gui.settings['histogramTarget'] == 'reactorVapor' then
                                gui.settings['histogramTarget'] = 'reactorFuel'
                            elseif gui.settings['histogramTarget'] == 'reactorCoolant' then
                                gui.settings['histogramTarget'] = 'reactorVapor'
                            end
                        elseif gui.settings['turbine']['status'] ~= nil then
                            if gui.settings['histogramTarget'] == 'turbinePower' then
                                gui.settings['histogramTarget'] = 'turbineCoolant'
                            elseif gui.settings['histogramTarget'] == 'turbineVapor' then
                                gui.settings['histogramTarget'] = 'turbinePower'
                            elseif gui.settings['histogramTarget'] == 'turbineCoolant' then
                                gui.settings['histogramTarget'] = 'turbineVapor'
                            end
                        elseif gui.snapshot['reactor']['status'] ~= nil then
                            if not gui.snapshot['reactor']['activelyCooled'] then
                                if gui.settings['histogramTarget'] == 'reactorFuel' then
                                    gui.settings['histogramTarget'] = 'reactorPower'
                                elseif gui.settings['histogramTarget'] == 'reactorPower' then
                                    gui.settings['histogramTarget'] = 'reactorFuel'
                                end
                            else
                                if gui.settings['histogramTarget'] == 'reactorFuel' then
                                    gui.settings['histogramTarget'] = 'reactorCoolant'
                                elseif gui.settings['histogramTarget'] == 'reactorVapor' then
                                    gui.settings['histogramTarget'] = 'reactorFuel'
                                elseif gui.settings['histogramTarget'] == 'reactorCoolant' then
                                    gui.settings['histogramTarget'] = 'reactorVapor'
                                end
                            end
                        end
                    elseif x == gui.width-1 then
                        if gui.snapshot['turbine']['status'] ~= nil and gui.snapshot['reactor']['status'] ~= nil then
                            if gui.settings['histogramTarget'] == 'turbinePower' then
                                gui.settings['histogramTarget'] = 'turbineVapor'
                            elseif gui.settings['histogramTarget'] == 'turbineVapor' then
                                gui.settings['histogramTarget'] = 'turbineCoolant'
                            elseif gui.settings['histogramTarget'] == 'turbineCoolant' then
                                gui.settings['histogramTarget'] = 'reactorFuel'
                            elseif gui.settings['histogramTarget'] == 'reactorFuel' then
                                gui.settings['histogramTarget'] = 'reactorVapor'
                            elseif gui.settings['histogramTarget'] == 'reactorVapor' then
                                gui.settings['histogramTarget'] = 'reactorCoolant'
                            elseif gui.settings['histogramTarget'] == 'reactorCoolant' then
                                gui.settings['histogramTarget'] = 'turbinePower'
                            end
                        elseif gui.snapshot['turbine']['status'] ~= nil then
                            if gui.settings['histogramTarget'] == 'turbinePower' then
                                gui.settings['histogramTarget'] = 'turbineVapor'
                            elseif gui.settings['histogramTarget'] == 'turbineVapor' then
                                gui.settings['histogramTarget'] = 'turbineCoolant'
                            elseif gui.settings['histogramTarget'] == 'turbineCoolant' then
                                gui.settings['histogramTarget'] = 'turbinePower'
                            end
                        elseif gui.snapshot['reactor']['status'] ~= nil then
                            if not gui.snapshot['reactor']['activelyCooled'] then
                                if gui.settings['histogramTarget'] == 'reactorFuel' then
                                    gui.settings['histogramTarget'] = 'reactorPower'
                                elseif gui.settings['histogramTarget'] == 'reactorPower' then
                                    gui.settings['histogramTarget'] = 'reactorFuel'
                                end
                            else
                                if gui.settings['histogramTarget'] == 'reactorFuel' then
                                    gui.settings['histogramTarget'] = 'reactorVapor'
                                elseif gui.settings['histogramTarget'] == 'reactorVapor' then
                                    gui.settings['histogramTarget'] = 'reactorCoolant'
                                elseif gui.settings['histogramTarget'] == 'reactorCoolant' then
                                    gui.settings['histogramTarget'] = 'reactorFuel'
                                end
                            end
                        end
                    end
                    gui.writeSettings()
                elseif y == gui.height-3 then
                    if x >= gui.width*gui.widthFactor-1 or x <= gui.width*gui.widthFactor+2 then
                        if gui.settings['histogramMinutes'] < gui.settings['maxHistogramMinutes'] then
                            gui.settings['histogramMinutes'] = gui.settings['histogramMinutes'] +1
                        else
                            gui.settings['histogramMinutes'] = 1
                        end
                        gui.writeSettings()
                    end
                end
            -- elseif gui.settings['currentPageTitle'] == 'Graphs' then -- Graphs
            --     if y == 6 then
            --         if x >=gui.width*gui.widthFactor+1 and x <= gui.width*gui.widthFactor+1+5 then
            --             if gui.snapshot['reactor']['status'] then
            --                 for k, v in pairs(gui.snapshot['reactor']['rodInfo']['rods']) do
            --                     interface.reactor.setControlRodLevel(k, 100)
            --                 end
            --                 interface.reactor.setActive(false)
            --             end
            --         end
            --     end
            elseif gui.settings['currentPageTitle'] == 'Rod Statistics Info' then -- Control Rods
                for k, v in pairs(gui.snapshot['reactor']['rodInfo']['rods']) do
                    if y == 6+k*2-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                        if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                            interface.reactor.setControlRodLevel(k-1, v['level']-1)
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                            if v['level']-5 < 0 then
                                interface.reactor.setControlRodLevel(k-1, 0)
                            else
                                interface.reactor.setControlRodLevel(k-1, v['level']-5)
                            end
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                            if v['level']-10 < 0 then
                                interface.reactor.setControlRodLevel(k-1, 0)
                            else
                                interface.reactor.setControlRodLevel(k-1, v['level']-10)
                            end
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                            if v['level']+10 > 100 then
                                interface.reactor.setControlRodLevel(k-1, 100)
                            else
                                interface.reactor.setControlRodLevel(k-1, v['level']+10)
                            end
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                            if v['level']+5 > 100 then
                                interface.reactor.setControlRodLevel(k-1, 100)
                            else
                                interface.reactor.setControlRodLevel(k-1, v['level']+5)
                            end
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                            interface.reactor.setControlRodLevel(k-1, v['level']+1)
                        end
                        break
                    end
                end
            elseif gui.settings['currentPageTitle'] == 'Automations' then -- Automations
                if y > 2 and y < gui.height-2 then
                    local positionTable = {
                        [1] = '',
                        [2] = 'title',
                        [3] = '',
                    }
                    if gui.snapshot['turbine']['status'] ~= nil then
                        table.insert(positionTable, '----- Turbine -----')
                        table.insert(positionTable, 'turbineToggle')
                        table.insert(positionTable, 'inductorToggle')
                        table.insert(positionTable, 'turbineEfficiencyToggle')
                        table.insert(positionTable, 'turbineSpeedToggle')
                        table.insert(positionTable, 'turbineSpeedTarget')
                        table.insert(positionTable, '      buttons      ')
                        table.insert(positionTable, 'powerToggle')
                        table.insert(positionTable, 'powerMax')
                        table.insert(positionTable, '      buttons      ')
                        table.insert(positionTable, 'powerMin')
                        table.insert(positionTable, '      buttons      ')
                    end
                    if gui.snapshot['reactor']['status'] ~= nil then
                        if gui.snapshot['reactor']['activelyCooled'] then
                            table.insert(positionTable, '----- Reactor -----')
                            table.insert(positionTable, 'reactorToggle')
                            table.insert(positionTable, 'controlRodsToggle')
                            table.insert(positionTable, 'tempToggle')
                            table.insert(positionTable, 'vaporToggle')
                            table.insert(positionTable, 'vaporMax')
                            table.insert(positionTable, '      buttons      ')
                            table.insert(positionTable, 'vaporMin')
                            table.insert(positionTable, '      buttons      ')
                        else
                            table.insert(positionTable, '----- Reactor -----')
                            table.insert(positionTable, 'reactorToggle')
                            table.insert(positionTable, 'controlRodsToggle')
                            table.insert(positionTable, 'tempToggle')
                            table.insert(positionTable, 'powerToggle')
                            table.insert(positionTable, 'powerMax')
                            table.insert(positionTable, '      buttons      ')
                            table.insert(positionTable, 'powerMin')
                            table.insert(positionTable, '      buttons      ')
                        end
                    end
                    table.insert(positionTable, '')
                    if positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))] == '      buttons      ' then
                        if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                            interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] -1
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                            interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] -5
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                            interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] -10
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                            interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] +10
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                            interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] +5
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                            interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] +1
                        end
                        if positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1] ~= 'turbineSpeedTarget' then
                            if interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] < 0 then
                                interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = 0
                            elseif interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] > 100 then
                                interface.automations[positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1]] = 100
                            end
                        end
                        interface.writeAutomations()
                    elseif gui.checkIfTableContains({'turbineToggle', 'inductorToggle', 'turbineEfficiencyToggle', 'turbineSpeedToggle', 'powerToggle', 'reactorToggle', 'controlRodsToggle', 'tempToggle', 'vaporToggle', 'powerToggle'}, positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]) then
                        if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                            if interface.automations[positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]] then
                                interface.automations[positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]] = false
                                if positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))] == 'turbineEfficiencyToggle' then
                                    interface.automations['turbineSpeedToggle'] = true
                                elseif positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))] == 'turbineSpeedToggle' then
                                    interface.automations['turbineEfficiencyToggle'] = true
                                end
                            else
                                interface.automations[positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]] = true
                                if positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))] == 'turbineEfficiencyToggle' then
                                    interface.automations['turbineSpeedToggle'] = false
                                elseif positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))] == 'turbineSpeedToggle' then
                                    interface.automations['turbineEfficiencyToggle'] = false
                                end
                            end
                            interface.writeAutomations()
                        end
                    end
                end
            elseif gui.settings['currentPageTitle'] == 'Manage Clients' then -- Manage Clients
                if x > 2 and x < gui.width-2 then
                    if y > 6-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) and y < gui.height-3-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                        local count = 1
                        local clients = interface.readClients()
                        for k, v in pairs(clients) do
                            if y-6 == count then
                                interface.removeClient(v)
                                break
                            end
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
end --end clickedButton

function interface.mouseWheel(event, direction, x, y, arg4, arg5)
    gui.readSettings()
    if direction == -1 then -- Up
        if gui.settings['mouseWheel'] < 1 then
            gui.settings['mouseWheel'] = gui.settings['mouseWheel'] + 0.05 -- Incrementing by 5%
        end
    elseif direction == 1 then -- Down
        if gui.settings['mouseWheel'] > 0 then
            gui.settings['mouseWheel'] = gui.settings['mouseWheel'] - 0.05 -- Decrementing by 5%
        end
    end
    gui.writeSettings()
end --end mouseWheel

function interface.guiHandler() -- Run in parallel
    while true do
        -- gui.log('Parallel - Gui Handler')
        os.sleep(interface.fps)
        gui.main()
    end
end --end guiHandler

function interface.login() -- For the server logging in
    local logged = false
    while not logged do
        if fs.exists('./er_interface/keys/login') then
            local pw = gui.login(interface.getComputerInfo())
            local file = fs.open('./er_interface/keys/login', 'r')
            local pwEncrypted = file.readAll()
            file.close()
            if pw == crypt.xorEncryptDecrypt(math.pi, pwEncrypted) then
                logged = true
            end
        else
            local pw = gui.signup(interface.getComputerInfo())
            if #pw > 2 and #pw < 18 then
                local pwEncrypted = crypt.xorEncryptDecrypt(math.pi, pw)
                local file = fs.open('./er_interface/keys/login', 'w')
                file.write(pwEncrypted)
                file.close()
            end
        end
    end
end --end login

function interface.verifyLogin(pw) -- For remotes attempting to login
    if fs.exists('./er_interface/keys/login') then
        local file = fs.open('./er_interface/keys/login', 'r')
        local pwEncrypted = file.readAll()
        file.close()
        if pw == crypt.xorEncryptDecrypt(math.pi, pwEncrypted) then
            return true
        end
    else
        return false
    end
end --end verifyLogin

function interface.writeAutomations()
    if not fs.exists('./er_interface/settings_automations.cfg') then
        automations = {
            ['reactorToggle'] = true,
            ['turbineToggle'] = true,
            ['inductorToggle'] = true,
            ['powerToggle'] = true, -- Reactor if no turbine
            ['vaporToggle'] = true,
            ['tempToggle'] = true,
            ['controlRodsToggle'] = true,
            ['turbineSpeedToggle'] = false,
            ['turbineEfficiencyToggle'] = true,
            ['powerMin'] = 10,
            ['powerMax'] = 90,
            ['vaporMin'] = 10,
            ['vaporMax'] = 90,
            ['tempMin'] = 10,
            ['tempMax'] = 2000,
            ['turbineSpeedTarget'] = 1800,
            ['lastTimeTurbineSpeed'] = 0,
        }
        local file = fs.open('./er_interface/settings_automations.cfg', 'w')
        file.write(textutils.serialize(automations))
        file.close()
    else
        local file = fs.open('./er_interface/settings_automations.cfg', 'w')
        file.write(textutils.serialize(interface.automations))
        file.close()
    end
end --end writeAutomations

function interface.readAutomations()
    if not fs.exists('./er_interface/settings_automations.cfg') then
        interface.writeAutomations()
        -- interface.readAutomations()
    else
        local file = fs.open('./er_interface/settings_automations.cfg', 'r')
        interface.automations = textutils.unserialize(file.readAll())
        file.close()
    end
end --end readAutomations

function interface.manageAutomations() -- Run in Parallel
    while true do
        -- gui.log('Parallel - Automations')
        os.sleep(interface.fps)
        interface.readAutomations()
        if interface.snapshot['reactor']['status'] ~= nil then
            if interface.automations['reactorToggle'] then
                if interface.reactor.getActive() then -- Is active
                    if not interface.reactor.isActivelyCooled() then
                        if (gui.snapshot['reactor']['energyInfo']['stored']/gui.snapshot['reactor']['energyInfo']['capacity'])*100 >= interface.automations['powerMax'] then
                            interface.reactor.setActive(false)
                        end
                        if interface.automations['controlRodsToggle'] then
                            if interface.automations['tempToggle'] then
                                if interface.snapshot['reactor']['fuelInfo']['temperature'] > 1000 then
                                    local lowest, level = 0, 100
                                    for k, v in pairs(interface.snapshot['reactor']['rodInfo']['rods']) do
                                        if v['level'] < level then
                                            lowest = v['id']
                                            level = v['level']
                                        end
                                    end
                                    -- gui.log(textutils.serialize({['lowest'] = lowest, ['level'] = level}))
                                    interface.reactor.setControlRodLevel(lowest, level+1)
                                elseif interface.snapshot['reactor']['fuelInfo']['temperature'] < 1000 then
                                    local highest, level = 0, 0
                                    for k, v in pairs(interface.snapshot['reactor']['rodInfo']['rods']) do
                                        if v['level'] > level then
                                            highest = v['id']
                                            level = v['level']
                                        end
                                    end
                                    -- gui.log(textutils.serialize({['lowest'] = highest, ['level'] = level}))
                                    interface.reactor.setControlRodLevel(highest, level-1)
                                end
                            else
                                interface.reactor.setAllControlRodLevels(math.floor((gui.snapshot['reactor']['energyInfo']['stored'])/(gui.snapshot['reactor']['energyInfo']['capacity']*(interface.automations['powerMax']/100))*100))
                            end
                        end
                    else
                        if (gui.snapshot['reactor']['hotFluidInfo']['amount']/gui.snapshot['reactor']['hotFluidInfo']['max'])*100 >= interface.automations['vaporMax'] then
                            interface.reactor.setActive(false)
                        end
                        if interface.automations['controlRodsToggle'] then
                            if interface.automations['tempToggle'] then
                                if interface.snapshot['reactor']['fuelInfo']['temperature'] > 1000 then
                                    local lowest, level = 0, 100
                                    for k, v in pairs(interface.snapshot['reactor']['rodInfo']['rods']) do
                                        if v['level'] < level then
                                            lowest = v['id']
                                            level = v['level']
                                        end
                                    end
                                    -- gui.log(textutils.serialize({['lowest'] = lowest, ['level'] = level}))
                                    interface.reactor.setControlRodLevel(lowest, level+1)
                                elseif interface.snapshot['reactor']['fuelInfo']['temperature'] < 1000 then
                                    local highest, level = 0, 0
                                    for k, v in pairs(interface.snapshot['reactor']['rodInfo']['rods']) do
                                        if v['level'] > level then
                                            highest = v['id']
                                            level = v['level']
                                        end
                                    end
                                    -- gui.log(textutils.serialize({['highest'] = highest, ['level'] = level}))
                                    interface.reactor.setControlRodLevel(highest, level-1)
                                end
                            else
                                interface.reactor.setAllControlRodLevels(math.floor((gui.snapshot['reactor']['hotFluidInfo']['amount'])/(gui.snapshot['reactor']['hotFluidInfo']['max']*(interface.automations['vaporMax']/100))*100))
                            end
                        end
                    end
                else -- If Reactor is not turned on
                    if not interface.reactor.isActivelyCooled() then
                        if (gui.snapshot['reactor']['energyInfo']['stored']/gui.snapshot['reactor']['energyInfo']['capacity'])*100 <= interface.automations['powerMin'] then
                            interface.reactor.setActive(true)
                        end
                    else
                        if (gui.snapshot['reactor']['hotFluidInfo']['amount']/gui.snapshot['reactor']['hotFluidInfo']['max'])*100 <= interface.automations['vaporMin'] then
                            interface.reactor.setActive(true)
                        end
                    end
                end
            end
        end
        if interface.snapshot['turbine']['status'] ~= nil then
            if interface.automations['turbineToggle'] then
                if interface.snapshot['turbine']['status'] then
                    if gui.snapshot['turbine']['rotorInfo']['rotorSpeed'] > interface.automations['turbineSpeedTarget']+interface.automations['turbineSpeedTarget']*0.1 then
                        interface.turbine.setActive(false)
                    end
                else
                    if gui.snapshot['turbine']['rotorInfo']['rotorSpeed'] < interface.automations['turbineSpeedTarget']-interface.automations['turbineSpeedTarget']*0.1 then
                        interface.turbine.setActive(true)
                        interface.turbine.setFluidFlowRateMax(math.floor(gui.snapshot['turbine']['rotorInfo']['bladeQuantity']*25))
                    end
                end
            end
            if interface.automations['inductorToggle'] then
                if interface.snapshot['turbine']['inductorStatus'] then
                    if (gui.snapshot['turbine']['energyInfo']['stored']/gui.snapshot['turbine']['energyInfo']['capacity'])*100 >= interface.automations['powerMax'] then
                        interface.turbine.setInductorEngaged(false)
                        interface.turbine.setFluidFlowRateMax(0)
                    end
                else
                    if (gui.snapshot['turbine']['energyInfo']['stored']/gui.snapshot['turbine']['energyInfo']['capacity'])*100 <= interface.automations['powerMin'] then
                        interface.turbine.setInductorEngaged(true)
                        interface.turbine.setFluidFlowRateMax(math.floor(gui.snapshot['turbine']['rotorInfo']['bladeQuantity']*25))
                    end
                end
            end
            if (os.epoch('local') - interface.automations['lastTimeTurbineSpeed'])/1000 > 1 then
                if interface.automations['turbineSpeedToggle'] then
                    if interface.snapshot['turbine']['rotorInfo']['rotorSpeed'] < interface.automations['turbineSpeedTarget']-5 then
                        interface.turbine.setFluidFlowRateMax(gui.snapshot['turbine']['fluidInfo']['flowRate']+1+math.floor((interface.automations['turbineSpeedTarget']-gui.snapshot['turbine']['rotorInfo']['rotorSpeed'])/100))
                    elseif gui.snapshot['turbine']['rotorInfo']['rotorSpeed'] > interface.automations['turbineSpeedTarget']+5 then
                        interface.turbine.setFluidFlowRateMax(gui.snapshot['turbine']['fluidInfo']['flowRate']-1-math.floor((gui.snapshot['turbine']['rotorInfo']['rotorSpeed']-interface.automations['turbineSpeedTarget'])/100))
                    end
                elseif interface.automations['turbineEfficiencyToggle'] then
                    if gui.snapshot['turbine']['rotorInfo']['bladeEfficiency'] < 100 then
                        interface.turbine.setFluidFlowRateMax(math.floor(gui.snapshot['turbine']['rotorInfo']['bladeQuantity']*25))
                    end
                end
                interface.automations['lastTimeTurbineSpeed'] = os.epoch('local')
                interface.writeAutomations()
            end
        end
    end
end --end manageAutomations

function interface.initialize()
    local _, y = term.getSize()
    interface.findDrives()
    term.setCursorPos(1, y)
    interface.write('Initializing...')
    if os.getComputerLabel() == nil or string.find(string.lower(os.getComputerLabel()), 'reactor') == nil then -- The name must have the word "reactor" in it somewhere, we need to check for it
        os.setComputerLabel('Extreme_Reactor_Server')
        interface.write('Set computer\'s label to '..os.getComputerLabel())
    end
    local initial = {
            ['computerInfo'] = interface.getComputerInfo(),
            ['monitor'] = interface.checkForMonitor(),
            ['modem'] = interface.checkForWirelessModem(),
            ['reactor'] = interface.checkForReactor(),
            ['turbine'] = interface.checkForTurbine(),
        }
    for k, i in pairs(initial) do
        if i == false then
            interface.write('There was an error in setting up the '..k)
        end
    end
    interface.write('Computer ID: '..initial['computerInfo']['id'])
    interface.write('Computer Label: '..initial['computerInfo']['label'])
    if not fs.exists('./er_interface/keys/clients') then
        local file = fs.open('./er_interface/keys/clients', 'w')
        file.write(textutils.serialize({}))
        file.close()
    end
    if not fs.exists('./er_interface/keys/parameters.tmp') then
        interface.write('Generating first run security parameters. This may take a few minutes...')
        local p, g = crypt.generateParameters(1000, 10000)      
        local file = fs.open('./er_interface/keys/parameters.tmp', 'w')
        file.write(textutils.serialize({['p'] = p, ['g'] = g}))
        file.close()
    end
    interface.monitor = initial['monitor']
    interface.modem = initial['modem']
    interface.reactor = initial['reactor']
    interface.turbine = initial['turbine']
    interface.initializeMonitor()
    interface.initializeNetwork()
    interface.initialized = true
    interface.login()
    interface.readAutomations()
    parallel.waitForAny(interface.generateKeyParameters, interface.generateSnapshots, interface.eventHandler, interface.guiHandler, interface.manageAutomations, interface.broadcast)
end --end initialize

return interface