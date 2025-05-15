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
    ['powerToggle'] = true,
    ['powerMin'] = 10,
    ['powerMax'] = 90,
    ['tempToggle'] = true,
    ['tempMin'] = 10,
    ['tempMax'] = 1000,
    ['controlRodsToggle'] = true,
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

function interface.checkForinterface()
    for _, i in pairs(peripheral.getNames()) do
        if string.find(peripheral.getType(i), 'BigReactors') ~= nil then
            if peripheral.call(i, 'mbIsAssembled') then
                interface.write('Reactor found!')
                return peripheral.wrap(i)
            end
        end
    end
    return false
end --end checkForinterface

function interface.getControlRodsInfo()
    local info = {
        ['rodLevels'] = interface.reactor.getControlRodsLevels(),
        ['quantity'] = interface.reactor.getNumberOfControlRods(),
        ['rods'] = {},
    }
    for i=0, info['quantity']-1 do
        info['rods'][i] = {
            ['name'] = interface.reactor.getControlRodName(i),
            ['level'] = interface.reactor.getControlRodLevel(i),
            ['location'] = interface.reactor.getControlRodLocation(i),
        }
    end
    return info
end --end getControlRodsInfo

function interface.getCoolantInfo()
    local info = {
        ['amount'] = interface.reactor.getCoolantAmount(),
        ['max'] = interface.reactor.getCoolantAmountMax(),
        ['stats'] = interface.reactor.getCoolantFluidStats(),
        ['type'] = interface.reactor.getCoolantType(),
    }
    return info
end --end getCoolantInfo

function interface.getEnergyInfo()
    local info = {
        ['capacity'] = interface.reactor.getEnergyCapacity(),
        ['lastTick'] = interface.reactor.getEnergyProducedLastTick(),
        ['stats'] = interface.reactor.getEnergyStats(),
        ['stored'] = interface.reactor.getEnergyStored(),
        ['storedText'] = interface.reactor.getEnergyStoredAsText(),
    }
    return info
end --end getEnergyInfo

function interface.getFuelInfo()
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

function interface.getHotFluidInfo()
    local info = {
        ['amount'] = interface.reactor.getHotFluidAmount(),
        ['max'] = interface.reactor.getHotFluidAmountMax(),
        ['lastTick'] = interface.reactor.getHotFluidProducedLastTick(),
        ['stats'] = interface.reactor.getHotFluidStats(),
        ['type'] = interface.reactor.getHotFluidType(),
    }
    return info
end --end getHotFluidInfo

function interface.getMBInfo()
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

function interface.generateSnapshots() -- Run in parallel
    while true do
        interface.snapshot = {
            ['status'] = interface.reactor.getActive(),
            ['casingTemperature'] = interface.reactor.getCasingTemperature(),
            ['variation'] = interface.reactor.getVariant(),
            ['wasteAmount'] = interface.reactor.getWasteAmount(),
            ['activelyCooled'] = interface.reactor.isActivelyCooled(),
            ['coolantInfo'] = interface.getCoolantInfo(),
            ['energyInfo'] = interface.getEnergyInfo(),
            ['fuelInfo'] = interface.getFuelInfo(),
            ['hotFluidInfo'] = interface.getHotFluidInfo(),
            ['rodInfo'] = interface.getControlRodsInfo(),
            ['mbLocation'] = interface.getMBInfo(),
            ['report'] = {['datestamp'] = os.date(), ['origin'] = interface.getComputerInfo(), ['timestamp'] = os.epoch('local')},
            ['automations'] = interface.automations,
        }
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

function interface.broadcast()
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
        }
    }
    interface.modem.transmit(7, 0, info)
end --end broadcast

function interface.eventHandler() -- Run in parallel
    local timer = os.startTimer(60*5)
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        if event == 'timer' then
            interface.broadcast()
            timer = os.startTimer(60*5)
        elseif event == 'modem_message' then
            interface.checkMessages(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_up' or event == 'monitor_touch' then
            interface.clickedButton(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_wheel' then
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

function interface.checkMessages(event, side, channel, replyChannel, message, distance)
    -- ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28},
    -- Message Format: {['origin'] = {}, ['target'] = {}, ['packet'] = {}}
    -- ['packet'] = crypt.encrpt(sharedKey, )
    if channel == 14 then -- Handshakes
        if message['target'] ~= nil then
            if message['target']['id'] == interface.getComputerInfo()['id'] and message['target']['label'] == interface.getComputerInfo()['label'] then
                if message['origin'] ~= nil then
                    local clients = interface.readClients()
                    if clients[message['origin']['label']] ~= nil then -- Exists
                        if message['packet']['attempt'] ~= nil then
                            interface.modem.transmit(14, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(clients[message['origin']['label']]['sharedKey'], 'success')})
                            if crypt.xorEncryptDecrypt(clients[message['origin']['label']]['sharedKey'], message['packet']['attempt']) ~= 'success' then -- Unsuccessful handshake, start over.
                                clients[message['origin']['label']] = nil
                                interface.writeClients(clients)
                            end
                        end
                    else -- Add to clients & their public key & parameters
                        if message['packet']['p'] ~= nil and message['packet']['g'] ~= nil and message['packet']['publicKey'] ~= nil then
                            clients[message['origin']['label']] = message['origin']
                            -- clients[message['origin']['label']]['p'] = message['packet']['p']
                            -- clients[message['origin']['label']]['g'] = message['packet']['g']
                            -- clients[message['origin']['label']]['privateKey'], clients[message['origin']['label']]['publicKey'] = crypt.generatePrivatePublicKeys(message['packet']['p'], message['packet']['g'])
                            local privateKey, publicKey = crypt.generatePrivatePublicKeys(message['packet']['p'], message['packet']['g'])
                            interface.modem.transmit(14, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = {['publicKey'] = publicKey}})
                            clients[message['origin']['label']]['sharedKey'] = crypt.generateSharedKey(privateKey, message['packet']['publicKey'], message['packet']['p'])
                            clients[message['origin']['label']]['creationTimestamp'] = os.epoch('local')
                            clients[message['origin']['label']]['lastLogin'] = os.epoch('local')
                            clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                            interface.writeClients(clients)
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
                    local clients = interface.readClients()
                    if clients[message['origin']['label']] ~= nil then -- Exists
                        -- if session[messager['origin']['label']] -- Check if already logged in (TBD)
                        if clients[message['origin']['label']]['id'] == message['origin']['id'] then 
                            local decryptedMsg = textutils.unserialize(crypt.xorEncryptDecrypt(clients[message['origin']['label']]['sharedKey'], message['packet']))
                            if decryptedMsg['type'] == 'login' then
                                if interface.verifyLogin(decryptedMsg['data']) then
                                    gui.log('User logged in from '..message['origin']['label']..' with device id '..message['origin']['id'])
                                    -- interface.session[message['origin']['label']] = message['origin']
                                    -- interface.session[message['origin']['label']]['timestamp'] = os.clock()
                                    interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(clients[message['origin']['label']]['sharedKey'], textutils.serialize({['type'] = 'login', ['data'] = 'Granted'}))})
                                    clients[message['origin']['label']]['lastLogin'] = os.epoch('local')
                                    clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                    interface.writeClients(clients)
                                else
                                    gui.log('Failed login attempt from: '..message['origin']['label']..' with ID '..message['origin']['id'])
                                    interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(clients[message['origin']['label']]['sharedKey'], textutils.serialize({['type'] = 'login', ['data'] = 'Denied'}))})
                                end
                            elseif decryptedMsg['type'] == 'snapshot' then
                                interface.modem.transmit(28, 0, {['origin'] = interface.getComputerInfo(), ['target'] = message['origin'], ['packet'] = crypt.xorEncryptDecrypt(clients[message['origin']['label']]['sharedKey'], textutils.serialize({['type'] = 'snapshot', ['data'] = gui.snapshot}))})
                                clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                interface.writeClients(clients)
                            elseif decryptedMsg['type'] == 'command' then
                                if decryptedMsg['data'] == 'toggleReactor' then
                                    if interface.reactor.getActive() then
                                        interface.reactor.setActive(false)
                                    else
                                        interface.reactor.setActive(true)
                                    end
                                    clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                    interface.writeClients(clients)
                                elseif decryptedMsg['data'] == 'powerToggle' then
                                    if gui.snapshot['automations']['powerToggle'] then
                                        interface.automations['powerToggle'] = false
                                    else
                                        interface.automations['powerToggle'] = true
                                    end
                                    interface.writeAutomations()
                                    clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                    interface.writeClients(clients)
                                elseif decryptedMsg['data'] == 'tempToggle' then
                                    if gui.snapshot['automations']['tempToggle'] then
                                        interface.automations['tempToggle'] = false
                                    else
                                        interface.automations['tempToggle'] = true
                                    end
                                    interface.writeAutomations()
                                    clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                    interface.writeClients(clients)
                                elseif decryptedMsg['data'] == 'controlRodsToggle' then
                                    if gui.snapshot['automations']['controlRodsToggle'] then
                                        interface.automations['controlRodsToggle'] = false
                                    else
                                        interface.automations['controlRodsToggle'] = true
                                    end
                                    interface.writeAutomations()
                                    clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                    interface.writeClients(clients)
                                elseif decryptedMsg['data'] == 'scram' then
                                    if gui.snapshot['status'] then
                                        for k, v in pairs(gui.snapshot['rodInfo']['rods']) do
                                            interface.reactor.setControlRodLevel(k, 100)
                                        end
                                        interface.reactor.setActive(false)
                                    end
                                    clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                    interface.writeClients(clients)
                                end
                            elseif decryptedMsg['type'] == 'adjustRod' then
                                if decryptedMsg['direction'] == 'up' then
                                    interface.reactor.setControlRodLevel(decryptedMsg['target'], gui.snapshot['rodInfo']['rods'][decryptedMsg['target']]['level']+decryptedMsg['data'])
                                elseif decryptedMsg['direction'] == 'down' then
                                    interface.reactor.setControlRodLevel(decryptedMsg['target'], gui.snapshot['rodInfo']['rods'][decryptedMsg['target']]['level']-decryptedMsg['data'])
                                end
                                interface.writeAutomations()
                                clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                interface.writeClients(clients)
                            elseif decryptedMsg['type'] == 'powerMax' then
                                if decryptedMsg['direction'] == 'up' then
                                    interface.automations['powerMax'] = interface.automations['powerMax']+decryptedMsg['data']
                                elseif decryptedMsg['direction'] == 'down' then
                                    interface.automations['powerMax'] = interface.automations['powerMax']-decryptedMsg['data']
                                end
                                interface.writeAutomations()
                                clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                interface.writeClients(clients)
                            elseif decryptedMsg['type'] == 'powerMin' then
                                if decryptedMsg['direction'] == 'up' then
                                    interface.automations['powerMin'] = interface.automations['powerMin']+decryptedMsg['data']
                                elseif decryptedMsg['direction'] == 'down' then
                                    interface.automations['powerMin'] = interface.automations['powerMin']-decryptedMsg['data']
                                end
                                interface.writeAutomations()
                                clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                interface.writeClients(clients)
                            elseif decryptedMsg['type'] == 'tempMax' then
                                if decryptedMsg['direction'] == 'up' then
                                    interface.automations['tempMax'] = interface.automations['tempMax']+decryptedMsg['data']
                                elseif decryptedMsg['direction'] == 'down' then
                                    interface.automations['tempMax'] = interface.automations['tempMax']-decryptedMsg['data']
                                end
                                interface.writeAutomations()
                                clients[message['origin']['label']]['lastActivity'] = os.epoch('local')
                                interface.writeClients(clients)
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
        elseif gui.settings['currentPageTitle'] == 'Home' then
            if y == 9 then
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    if interface.reactor.getActive() then
                        interface.reactor.setActive(false)
                    else
                        interface.reactor.setActive(true)
                    end
                end
            end
        elseif gui.settings['currentPageTitle'] == 'Graphs' then -- Graphs
            if y == 6 then
                if x >=gui.width*gui.widthFactor+1 and x <= gui.width*gui.widthFactor+1+5 then
                    if gui.snapshot['status'] then
                        for k, v in pairs(gui.snapshot['rodInfo']['rods']) do
                            interface.reactor.setControlRodLevel(k, 100)
                        end
                        interface.reactor.setActive(false)
                    end
                end
            end
        elseif gui.settings['currentPageTitle'] == 'Rod Statistics' then -- Control Rods
            for k, v in pairs(gui.snapshot['rodInfo']['rods']) do
                if y == 8+k*2 then
                    if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                        interface.reactor.setControlRodLevel(k, v['level']-1)
                    elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                        if v['level']-5 < 0 then
                            interface.reactor.setControlRodLevel(k, 0)
                        else
                            interface.reactor.setControlRodLevel(k, v['level']-5)
                        end
                    elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                        if v['level']-10 < 0 then
                            interface.reactor.setControlRodLevel(k, 0)
                        else
                            interface.reactor.setControlRodLevel(k, v['level']-10)
                        end
                    elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                        if v['level']+10 > 100 then
                            interface.reactor.setControlRodLevel(k, 100)
                        else
                            interface.reactor.setControlRodLevel(k, v['level']+10)
                        end
                    elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                        if v['level']+5 > 100 then
                            interface.reactor.setControlRodLevel(k, 100)
                        else
                            interface.reactor.setControlRodLevel(k, v['level']+5)
                        end
                    elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                        interface.reactor.setControlRodLevel(k, v['level']+1)
                    end
                    break
                end
            end
        elseif gui.settings['currentPageTitle'] == 'Automations' then -- Automations
            if y == 6 then -- Power
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    if interface.automations['powerToggle'] then
                        interface.automations['powerToggle'] = false
                    else
                        interface.automations['powerToggle'] = true
                    end
                end
            elseif y == 8 then -- Power Max
                if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                    interface.automations['powerMax'] = interface.automations['powerMax'] -1
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                    interface.automations['powerMax'] = interface.automations['powerMax'] -5
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                    interface.automations['powerMax'] = interface.automations['powerMax'] -10
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                    interface.automations['powerMax'] = interface.automations['powerMax'] +10
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                    interface.automations['powerMax'] = interface.automations['powerMax'] +5
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                    interface.automations['powerMax'] = interface.automations['powerMax'] +1
                end
                if interface.automations['powerMax'] < 0 then
                    interface.automations['powerMax'] = 0
                elseif interface.automations['powerMax'] > 100 then
                    interface.automations['powerMax'] = 100
                end
            elseif y == 10 then -- Power Min
                if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                    interface.automations['powerMin'] = interface.automations['powerMin'] -1
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                    interface.automations['powerMin'] = interface.automations['powerMin'] -5
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                    interface.automations['powerMin'] = interface.automations['powerMin'] -10
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                    interface.automations['powerMin'] = interface.automations['powerMin'] +10
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                    interface.automations['powerMin'] = interface.automations['powerMin'] +5
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                    interface.automations['powerMin'] = interface.automations['powerMin'] +1
                end
                if interface.automations['powerMin'] < 0 then
                    interface.automations['powerMin'] = 0
                elseif interface.automations['powerMin'] > 100 then
                    interface.automations['powerMin'] = 100
                end
            elseif y == 12 then -- Temperature
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    if interface.automations['tempToggle'] then
                        interface.automations['tempToggle'] = false
                    else
                        interface.automations['tempToggle'] = true
                    end
                end
            elseif y == 14 then -- Temperature Max
                if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                    interface.automations['tempMax'] = interface.automations['tempMax'] -1
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                    interface.automations['tempMax'] = interface.automations['tempMax'] -5
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                    interface.automations['tempMax'] = interface.automations['tempMax'] -10
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                    interface.automations['tempMax'] = interface.automations['tempMax'] +10
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                    interface.automations['tempMax'] = interface.automations['tempMax'] +5
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                    interface.automations['tempMax'] = interface.automations['tempMax'] +1
                end
                if interface.automations['tempMax'] < 0 then
                    interface.automations['tempMax'] = 0
                end
            elseif y == 16 then -- Control Rods
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    if interface.automations['controlRodsToggle'] then
                        interface.automations['controlRodsToggle'] = false
                    else
                        interface.automations['controlRodsToggle'] = true
                    end
                end
            end
            interface.writeAutomations()
        elseif gui.settings['currentPageTitle'] == 'Connection' then -- Manage Clients // Server Connection
            if x > 2 and x < gui.width-2 then
                if y > 6 and y < gui.height-3 then
                    local count = 1
                    local clients = interface.readClients()
                    for _, i in pairs(clients) do
                        if y-6 == count then
                            clients[i['label']] = nil
                            interface.writeClients(clients)
                            break
                        end
                        count = count + 1
                    end
                end
            end
        end
    end
end --end clickedButton

function interface.mouseWheel(event, direction, x, y, arg4, arg5)
    if direction == -1 then -- Up
        if gui.settings['mouseWheel'] < 1 then
            gui.settings['mouseWheel'] = gui.settings['mouseWheel'] + 0.01
        end
    elseif direction == 1 then -- Down
        if gui.settings['mouseWheel'] > 0 then
            gui.settings['mouseWheel'] = gui.settings['mouseWheel'] - 0.01
        end
    end
end --end mouseWheel

function interface.guiHandler() -- Run in parallel
    while true do
        gui.main()
        os.sleep(interface.fps)
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
        local automations = {
            ['powerToggle'] = true,
            ['powerMin'] = 10,
            ['powerMax'] = 90,
            ['tempToggle'] = true,
            ['tempMin'] = 10,
            ['tempMax'] = 1000,
            ['controlRodsToggle'] = true,
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
        interface.readAutomations()
    else
        local file = fs.open('./er_interface/settings_automations.cfg', 'r')
        interface.automations = textutils.unserialize(file.readAll())
        file.close()
    end
end --end readAutomations

function interface.manageAutomations() -- Run in Parallel
    while true do
        os.sleep(interface.fps)
        if interface.automations['powerToggle'] then
            if interface.reactor.getActive() then -- Is active
                if (gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*100 >= interface.automations['powerMax'] then
                    interface.reactor.setActive(false)
                end
            else -- Is not active
                if (gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*100 <= interface.automations['powerMin'] then
                    interface.reactor.setActive(true)
                end
            end
        end
        if interface.automations['tempoggle'] then
            if gui.snapshot['casingTemperature'] >= interface.automations['tempMax'] then
                if interface.reactor.getActive() then -- Is active
                    interface.reactor.setActive(false)
                end
            end
        end
        if interface.automations['controlRodsToggle'] then -- Use Control Rods to float around slightly positive power output
            if interface.reactor.getActive() then -- Is active
                for k, v in pairs(gui.snapshot['rodInfo']['rods']) do
                    interface.reactor.setControlRodLevel(k, math.floor((gui.snapshot['energyInfo']['stored'])/(gui.snapshot['energyInfo']['capacity']*(interface.automations['powerMax']/100))*100))
                end
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
            ['reactor'] = interface.checkForinterface(),
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
    interface.initializeMonitor()
    interface.initializeNetwork()
    interface.initialized = true
    interface.login()
    interface.readAutomations()
    parallel.waitForAny(interface.generateKeyParameters, interface.generateSnapshots, interface.eventHandler, interface.guiHandler, interface.manageAutomations)
end --end initialize

return interface