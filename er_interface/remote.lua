local crypt = require('cryptography')
local gui = require('gui')

remote = {}

remote.keys = {}
remote.fps = 1/60
remote.monitor = nil
remote.modem = nil
remote.snapshot = nil
remote.settings = nil

function remote.write(text)
    local _, y = term.current().getSize()
    term.scroll(1)
    term.setCursorPos(1, y)
    textutils.slowWrite(text)
end --end write

function remote.log(text)
    if text ~= nil then
        gui.log(text, remote.selectDrive())
    end
end --end log

function remote.checkForWirelessModem()
    for _, i in pairs(peripheral.getNames()) do
        if peripheral.getType(i) == 'modem' then
            if peripheral.call(i, 'isWireless') then
                remote.write('Wireless Modem found!')
                return peripheral.wrap(i)
            end
        end
    end
    return false
end --end checkForWirelessModem

function remote.checkForMonitor()
    for _, i in pairs(peripheral.getNames()) do
        if peripheral.getType(i) == 'monitor' then
            remote.write('Monitor found!')
            -- return peripheral.wrap(i)
            local width, height = peripheral.wrap(i).getSize()
            return window.create(peripheral.wrap(i), 1, 1, width, height)
        end
    end
    remote.write('Could not find a monitor, using terminal.')
    local width, height = term.current().getSize()
    return window.create(term.current(), 1, 1, width, height)
end --end checkForMonitor

function remote.initializeMonitor()
    remote.monitor.clear()
    remote.monitor.setCursorPos(1,1)
    gui.initialize(remote.monitor)
end --end initializeMonitor

function remote.generatePrivateKey()
    if not fs.exists('/er_interface/keys/private.key') then
        local file = fs.open('/er_interface/keys/private.key', 'w')
        file.write(crypt.generatePrivateKey())
        file.close()
    end
end --end generatePrivateKey

function remote.readPrivateKey()
    if fs.exists('/er_interface/keys/private.key') then
        local file = fs.open('/er_interface/keys/private.key', 'r')
        local key = tonumber(file.readAll())
        file.close()
        return key
    else
        remote.generatePrivateKey()
        return remote.readPrivateKey()
    end
end --end readPrivateKey

function remote.readServerKeys()
    if fs.exists('/er_interface/keys/server.key') then
        local file = fs.open('/er_interface/keys/server.key', 'r')
        remote.keys = textutils.unserialize(file.readAll())
        file.close()
    end
end --end readServerKeys

function remote.getComputerInfo()
    return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end --end getComputerInfo

function remote.scanForServer()
    remote.write('Scanning for servers...')
    local server = nil
    while server == nil do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 7 then
                if message['origin'] ~= nil then
                    if message['origin']['label'] ~= nil then
                        if string.find(string.lower(message['origin']['label']), 'reactor') then -- The name of the extreme_reactor_interface server must contain the name "reactor" in it
                            if message['packet']['type'] == 'broadcast' then
                                -- remote.keys['target'] = message['origin']
                                if message['packet'] ~= nil then
                                    remote.write('Reactor server found with name '..message['origin']['label']..' and id '..message['origin']['id'])
                                    for k, v in pairs(message['packet']['ports']) do
                                        remote.modem.open(v)
                                        -- remote.write('Opened port on '..v..' for '..k)
                                    end
                                    remote.write('Opened ports on 14, 21, and 28')
                                    remote.readServerKeys()
                                    -- gui.log(textutils.serialize(remote.keys))
                                    -- gui.log(textutils.serialize(message))
                                    if next(remote.keys) ~= nil then
                                        if message['origin']['id'] == remote.keys['target']['id'] or message['origin']['label'] == remote.keys['target']['label'] then
                                            remote.write('Reconnecting to '..remote.keys['target']['label']..' with id '..remote.keys['target']['id'])
                                        else
                                            remote.keys = nil
                                            remote.handshake(message)
                                        end
                                    else
                                        remote.handshake(message)
                                    end
                                    server = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end --end scanForServer

function remote.handshake(targetMessage) -- Diffie–Hellman key exchange
    -- ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
    -- Message Format: {['origin'] = {}, ['target'] = {}, ['packet'] = {}}
    remote.write('Performing handshake...')
    -- local p, g = nil, nil
    -- while p == nil do -- Searching for server host and getting handshake parameters
    --     local event, side, channel, replyChannel, message, distance = os.pullEvent()
    --     if event == 'modem_message' then
    --         if channel == 7 then
    --             if message['origin'] ~= nil then
    --                 if message['origin']['label'] ~= nil then
    --                     if string.find(string.lower(message['origin']['label']), 'reactor') then -- The name of the extreme_reactor_interface server must contain the name "reactor" in it
    --                         if message['origin']['label'] == target['label'] and message['origin']['id'] == target['id'] then
    --                             if message['packet']['type'] == 'broadcast' then
    --                                 remote.keys['target'] = message['origin']
    --                                 if message['packet'] ~= nil then
    --                                     if message['packet']['handshakeParams'] ~= nil then
    --                                         if message['packet']['handshakeParams']['p'] ~= nil and message['packet']['handshakeParams']['g'] ~= nil then
    --                                             p = message['packet']['handshakeParams']['p']
    --                                             g = message['packet']['handshakeParams']['g']
    --                                             remote.write('Recieved key parameters from '..message['origin']['label']..' with server id '..message['origin']['id'])
    --                                         end
    --                                     end
    --                                 end
    --                             end
    --                         end
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
    remote.keys['target'] = targetMessage['origin']
    if targetMessage['packet']['handshakeParams'] ~= nil then
        if targetMessage['packet']['handshakeParams']['p'] ~= nil and targetMessage['packet']['handshakeParams']['g'] ~= nil then
            p = targetMessage['packet']['handshakeParams']['p']
            g = targetMessage['packet']['handshakeParams']['g']
            remote.write('Recieved key parameters from '..targetMessage['origin']['label']..' with server id '..targetMessage['origin']['id'])
        end
    end
    remote.write('Generating private and public keys. This may take a few minutes...')
    remote.keys['private'], remote.keys['public'] = crypt.generatePrivatePublicKeys(p, g)
    remote.write('Transmitting public key...')
    local publicKey = nil
    remote.modem.transmit(14, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = {['type'] = 'handshake', ['p'] = p, ['g'] = g, ['publicKey'] = remote.keys['public']}})
    while publicKey == nil do -- Exchanging public keys
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 14 then
                if message['target'] ~= nil then
                    if message['target']['id'] == remote.getComputerInfo()['id'] and message['target']['label'] == remote.getComputerInfo()['label'] then
                        if message['origin'] ~= nil then
                            if message['origin']['id'] == remote.keys['target']['id'] and message['origin']['label'] == remote.keys['target']['label'] then
                                if message['packet'] ~= nil then
                                    if message['packet']['publicKey'] ~= nil then
                                        remote.write('Recieved public key from '..message['origin']['label'])
                                        publicKey = message['packet']['publicKey']
                                        -- remote.write(tostring(publicKey))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    remote.write('Generating shared key...')
    remote.keys['shared'] = crypt.generateSharedKey(remote.keys['private'], publicKey, p)
    remote.write('Validating shared key with '..remote.keys['target']['label'])
    local verified = nil
    remote.modem.transmit(14, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = {['type'] = 'handshake', ['attempt'] = crypt.xorEncryptDecrypt(remote.keys['shared'], 'success')}})
    while verified == nil do -- Verifying a successful exchange
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 14 then
                if message['target'] ~= nil then
                    if message['target']['id'] == remote.getComputerInfo()['id'] and message['target']['label'] == remote.getComputerInfo()['label'] then
                        if message['origin'] ~= nil then
                            if message['origin']['id'] == remote.keys['target']['id'] and message['origin']['label'] == remote.keys['target']['label'] then
                                if crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet']) == 'success' then
                                    remote.write('Key successfully validated with '..message['origin']['label'])
                                    verified = true
                                else
                                    remote.write('Key validation failed with '..message['origin']['label'])
                                    verified = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if verified then
        local file = fs.open('./er_interface/keys/server.key', 'w')
        file.write(textutils.serialize(remote.keys))
        file.close()
        remote.write('Key saved to '..'./er_interface/keys/server.key')
    else
        remote.write('Reattempting handshake...')
        remote.scanForServer()
        -- remote.handshake()
    end
end --end handshake

-- All commands transmitted must be encrypted 

function remote.login()
    local logged = false
    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'login', ['data'] = gui.login(remote.keys['target'])}))})
    gui.log('Login attempt sent...')
    while not logged do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 28 then
                -- gui.log('Message Recieved: '..textutils.serialize(message))
                if message['target'] ~= nil then
                    if message['target']['id'] == remote.getComputerInfo()['id'] and message['target']['label'] == remote.getComputerInfo()['label'] then
                        -- gui.log('Target Cleared')
                        if message['origin'] ~= nil then
                            if message['origin']['id'] == remote.keys['target']['id'] and message['origin']['label'] == remote.keys['target']['label'] then
                                -- gui.log('Origin Cleared')
                                local decryptedMsg = crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet'])
                                -- gui.log(decryptedMsg)
                                if textutils.unserialize(decryptedMsg)['data'] == 'Granted' then
                                    gui.log('Successfully logged into '..message['origin']['label']..' with server id '..message['origin']['id'])
                                    logged = true
                                else
                                    gui.log('Logged rejected by '..message['origin']['label']..' with server id '..message['origin']['id'])
                                    remote.login()
                                    logged = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end --end login

function remote.requestSnapshot()
    local timer, keys, snapshot = os.startTimer(60), nil, nil
    -- remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshot', ['data'] = nil}))})
    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshotKey', ['data'] = nil}))})
    gui.log('Requesting snapshot keys.')
    while keys == nil do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'timer' and side == timer then
            timer = os.startTimer(60)
            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshotKey', ['data'] = nil}))})
            gui.log('Requesting snapshot keys.')
        elseif event == 'modem_message' then
            if channel == 28 then
                if message['target'] ~= nil then
                    if message['target']['label'] == remote.getComputerInfo()['label'] and message['target']['id'] == remote.getComputerInfo()['id'] then
                        if message['origin'] ~= nil then
                            if message['origin']['label'] == remote.keys['target']['label'] and message['origin']['id'] == remote.keys['target']['id'] then
                                local unencryptedPacket = textutils.unserialize(crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet']))
                                if unencryptedPacket['type'] == 'snapshotKey' then
                                    remote.keys['snapshotKey'] = unencryptedPacket['data']
                                    local file = fs.open('./er_interface/keys/server.key', 'w')
                                    file.write(textutils.serialize(remote.keys))
                                    file.close()
                                    keys = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    gui.log('Snapshot Key Acquired')
    while snapshot == nil do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 7 then
                if message['target'] == nil then
                    if message['origin'] ~= nil then
                        if message['origin']['label'] == remote.keys['target']['label'] and message['origin']['id'] == remote.keys['target']['id'] then
                            if message['packet'] ~= nil then
                                if message['packet']['type'] ~= nil then
                                    if message['packet']['type'] == 'broadcast' then
                                        if message['packet']['snapshot'] ~= nil then
                                            snapshot = textutils.unserialize(crypt.xorEncryptDecrypt(remote.keys['snapshotKey'], message['packet']['snapshot']))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    gui.log('Snapshot Acquired')
    gui.updateSnapshot(snapshot)
end --end requestSnapshot

function remote.checkMessages(event, side, channel, replyChannel, message, distance)
    -- ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28},
    -- Message Format: {['origin'] = {}, ['target'] = {}, ['packet'] = {}}
    -- ['packet'] = crypt.encrpt(sharedKey, payload)
    if channel == 7 then -- Broadcasts // Snapshot retrivel
        if message['target'] == nil then
            if message['origin'] ~= nil then
                if message['origin']['label'] == remote.keys['target']['label'] and message['origin']['id'] == remote.keys['target']['id'] then
                    if message['packet'] ~= nil then
                        if message['packet']['type'] ~= nil then
                            if message['packet']['type'] == 'broadcast' then
                                if message['packet']['snapshot'] ~= nil then
                                    gui.updateSnapshot(textutils.unserialize(crypt.xorEncryptDecrypt(remote.keys['snapshotKey'], message['packet']['snapshot'])))
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif channel == 14 then -- Handshakes
    elseif channel == 21 then -- Requests, login attempts, issue commands
    elseif channel == 28 then -- Data Transfers
        if message['target'] ~= nil then
            if message['target']['label'] == remote.getComputerInfo()['label'] and message['target']['id'] == remote.getComputerInfo()['id'] then
                if message['origin'] ~= nil then
                    if message['origin']['label'] == remote.keys['target']['label'] and message['origin']['id'] == remote.keys['target']['id'] then
                        local unencryptedPacket = textutils.unserialize(crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet']))
                        if unencryptedPacket['type'] == 'snapshotKey' then
                            -- gui.snapshot = unencryptedPacket['data']
                            remote.keys['snapshotKey'] = unencryptedPacket['data']
                            local file = fs.open('./er_interface/keys/server.key', 'w')
                            file.write(textutils.serialize(remote.keys))
                            file.close()
                        end
                    end
                end
            end
        end
    end
end --end checkMessages

function remote.clickedButton(event, button, x, y, arg4, arg5)
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
                    -- gui.log(textutils.serialize({['width']=gui.width, ['height']=gui.height}))
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
        elseif y >= 3 then
            if gui.settings['currentPageTitle'] == 'Reactor Summary' then
                if y == 8-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                    if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'toggleReactor'}))})
                    end
                end
            elseif gui.settings['currentPageTitle'] == 'Turbine Summary' then
                if y == 8-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                    if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'toggleTurbine'}))})
                    end
                elseif y == 9-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                    if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'toggleInductor'}))})
                    end
                end
            -- elseif gui.settings['currentPageTitle'] == 'Graphs' then -- Graphs
            --     if y == 6 then
            --         if x >=gui.width*gui.widthFactor+1 and x <= gui.width*gui.widthFactor+1+5 then
            --             if gui.snapshot['reactor']['status'] then
            --                 remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'scram'}))})
            --             end
            --         end
            --     end
            elseif gui.settings['currentPageTitle'] == 'Rod Statistics Info' then -- Control Rods
                for k, v in pairs(gui.snapshot['reactor']['rodInfo']['rods']) do
                    if y == 6+k*2-math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])) then
                        if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                            if v['level'] > 0 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = 1, ['direction'] = 'down', ['target'] = k}))})
                            end
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                            if v['level']-5 < 0 then
                                for i=1, 5 do
                                    if v['level']-1 == 0 then
                                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = i, ['direction'] = 'down', ['target'] = k}))})
                                        break
                                    end
                                end
                            else
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = 5, ['direction'] = 'down', ['target'] = k}))})
                            end
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                            if v['level']-10 < 0 then
                                for i=1, 10 do
                                    if v['level']-i == 0 then
                                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = i, ['direction'] = 'down', ['target'] = k}))})
                                        break
                                    end
                                end
                            else
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = 10, ['direction'] = 'down', ['target'] = k}))})
                            end
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                            if v['level']+10 > 100 then
                                for i=1, 10 do
                                    if v['level']+i == 100 then
                                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = i, ['direction'] = 'up', ['target'] = k}))})
                                        break
                                    end
                                end
                            else
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = 10, ['direction'] = 'up', ['target'] = k}))})
                            end
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                            if v['level']+5 > 100 then
                                for i=1, 5 do
                                    if v['level']+i == 100 then
                                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = i, ['direction'] = 'up', ['target'] = k}))})
                                        break
                                    end
                                end
                            else
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = 5, ['direction'] = 'up', ['target'] = k}))})
                            end
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                            if v['level'] < 100 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'adjustRod', ['data'] = 1, ['direction'] = 'up', ['target'] = k}))})
                            end
                        end
                        break
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
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 1, ['direction'] = 'down'}))})
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 5, ['direction'] = 'down'}))})
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 10, ['direction'] = 'down'}))})
                        elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 10, ['direction'] = 'up'}))})
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 5, ['direction'] = 'up'}))})
                        elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 1, ['direction'] = 'up'}))})
                        end
                        -- gui.log(textutils.serialize({['type'] = positionTable[((y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel'])))-1], ['data'] = 1, ['direction'] = 'up'}))
                    elseif gui.checkIfTableContains({'turbineToggle', 'inductorToggle', 'turbineEfficiencyToggle', 'turbineSpeedToggle', 'powerToggle', 'reactorToggle', 'controlRodsToggle', 'tempToggle', 'vaporToggle', 'powerToggle'}, positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]) then
                        if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]}))})
                            -- gui.log(textutils.serialize({['type'] = 'command', ['data'] = positionTable[(y-2)+math.floor((gui.settings['scrollAbleLines']*gui.settings['mouseWheel']))]}))
                        end
                    end
                end
            end
        end
    end
end --end clickedButton

function remote.mouseWheel(event, direction, x, y, arg4, arg5)
    gui.readSettings()
    if direction == 1 then -- Up
        if gui.settings['mouseWheel'] < 1 then
            gui.settings['mouseWheel'] = gui.settings['mouseWheel'] + 0.05
        end
    elseif direction == -1 then -- Down
        if gui.settings['mouseWheel'] > 0 then
            gui.settings['mouseWheel'] = gui.settings['mouseWheel'] - 0.05
        end
    end
    -- gui.log(textutils.serialize({['event'] = event, ['direction'] = direciton, ['x'] = x, ['y'] = y, ['arg4'] = arg4, ['arg5'] = arg5, ['mouseWheel'] = gui.settings['mouseWheel']}))
    gui.writeSettings()
end --end mouseWheel

function remote.snapshotHandler() -- Run in Parallel
    while true do
        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshot', ['data'] = nil}))})
        os.sleep(remote.fps)
    end
end --end snapshotHandler

function remote.guiHandler() -- Run in Parallel
    while true do
        gui.main()
        os.sleep(remote.fps)
    end
end --end guiHandler

function remote.eventHandler() -- Run in Parallel
    local timer = os.startTimer(60)
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        if event == 'timer' and arg1 == timer then
            os.cancelTimer(timer)
            -- remote.requestSnapshot()
            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshotKey', ['data'] = nil}))})
            timer = os.startTimer(60)
        elseif event == 'modem_message' then
            remote.checkMessages(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_up' or event == 'monitor_touch' then
            remote.clickedButton(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_scroll' then
            remote.mouseWheel(event, arg1, arg2, arg3, arg4, arg5)
        end
    end
end --end eventHandler

function remote.initialize()
    remote.write('Initializing...')
    remote.monitor = remote.checkForMonitor()
    remote.initializeMonitor()
    local tempModem = remote.checkForWirelessModem()
    if tempModem ~= false then
        remote.modem = tempModem
        remote.modem.open(7)
    end
    if os.getComputerLabel() == nil then
        os.setComputerLabel('Remote Device '..os.getComputerID())
        remote.write('Set computer\'s label to '..os.getComputerLabel())
    end
    remote.scanForServer()
    -- remote.readServerKeys()
    remote.login()
    remote.requestSnapshot()
    parallel.waitForAny(remote.eventHandler, remote.guiHandler) --remote.snapshotHandler, 
end --end initialize

return remote