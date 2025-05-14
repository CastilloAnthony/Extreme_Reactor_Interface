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
        remote.scanForServer()
    else
        remote.handshake()
    end
end --end readServerKeys

function remote.getComputerInfo()
    return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end --end getComputerInfo

function remote.scanForServer()
    local server = nil
    while server == nil do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 7 then
                if message['origin'] ~= nil then
                    if message['origin']['label'] ~= nil then
                        if string.find(string.lower(message['origin']['label']), 'reactor') then -- The name of the extreme_reactor_interface server must contain the name "reactor" in it
                            if message['packet']['type'] == 'broadcast' then
                                remote.keys['target'] = message['origin']
                                if message['packet'] ~= nil then
                                    remote.write('Reactor server found with name '..message['origin']['label']..' and id '..message['origin']['id'])
                                    for k, v in pairs(message['packet']['ports']) do
                                        remote.modem.open(v)
                                        -- remote.write('Opened port on '..v..' for '..k)
                                    end
                                    remote.write('Opened ports on 14, 21, and 28')
                                    server = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function remote.handshake() -- Diffie–Hellman key exchange
    -- ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
    -- Message Format: {['origin'] = {}, ['target'] = {}, ['packet'] = {}}
    remote.write('Performing handshake...')
    local p, g = nil, nil
    while p == nil do -- Searching for server host and getting handshake parameters
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 7 then
                if message['origin'] ~= nil then
                    if message['origin']['label'] ~= nil then
                        if string.find(string.lower(message['origin']['label']), 'reactor') then -- The name of the extreme_reactor_interface server must contain the name "reactor" in it
                            if message['packet']['type'] == 'broadcast' then
                                remote.keys['target'] = message['origin']
                                if message['packet'] ~= nil then
                                    if message['packet']['handshakeParams'] ~= nil then
                                        if message['packet']['handshakeParams']['p'] ~= nil and message['packet']['handshakeParams']['g'] ~= nil then
                                            p = message['packet']['handshakeParams']['p']
                                            g = message['packet']['handshakeParams']['g']
                                            remote.write('Recieved key parameters from '..message['origin']['label']..' with server id '..message['origin']['id'])
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
    -- local p, g = nil, nil
    -- remote.modem.transmit(14, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = {['handshake'] = true, ['p'] = math.random(1,10^10), ['g'] = math.random(1, 10^10)}})
    -- while p == nil or g == nil do -- Agreeing on parameters
    --     local event, side, channel, replyChannel, message, distance = os.pullEvent()
    --     if event == 'modem_message' then
    --         if channel == 14 then
    --             if message['target'] ~= nil then
    --                 if message['target'] == remote.getComputerInfo() then
    --                     if message['origin'] ~= nil then
    --                         if message['origin'] == temote.keys['target'] then
    --                             if message['packet']['p'] ~= nil or message['packet']['g'] ~= nil then
    --                                 p = message['p']
    --                                 g = message['g']
    --                             end
    --                         end
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
    remote.write('Generating private and public keys...')
    remote.keys['private'], remote.keys['public'] = crypt.generatePrivatePublicKeys(p, g)
    -- remote.write(textutils.serialize({['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = {['type'] = 'handshake', ['p'] = p, ['g'] = g, ['publicKey'] = remote.keys['public']}}))
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
        -- remote.modem.transmit(14, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = {['type'] = 'handshake', ['data'] = 'retry'}})
        remote.handshake()
    end
end --end handshake

-- All commands issued must be encrypted 

function remote.login()
    local logged = false
    -- local pw = gui.login(remote.keys['target'])
    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'login', ['data'] = gui.login(remote.keys['target'])}))})
    gui.log('Login attempt sent...')
    while not logged do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if channel == 28 then
                gui.log('Message Recieved: '..textutils.serialize(message))
                if message['target'] ~= nil then
                    if message['target']['id'] == remote.getComputerInfo()['id'] and message['target']['label'] == remote.getComputerInfo()['label'] then
                        gui.log('Target Cleared')
                        if message['origin'] ~= nil then
                            if message['origin']['id'] == remote.keys['target']['id'] and message['origin']['label'] == remote.keys['target']['label'] then
                                gui.log('Origin Cleared')
                                local decryptedMsg = crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet'])
                                gui.log(decryptedMsg)
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
end

function remote.requestSnapshot()
    local timer, snapshot = os.startTimer(60), nil
    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshot', ['data'] = nil}))})
    while snapshot == nil do
        local event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'timer' then
            timer = os.startTimer(60)
            remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshot', ['data'] = nil}))})
        elseif event == 'modem_message' then
            if channel == 28 then
                if message['target'] ~= nil then
                    if message['target']['label'] == remote.getComputerInfo()['label'] and message['target']['id'] == remote.getComputerInfo()['id'] then
                        if message['origin'] ~= nil then
                            if message['origin']['label'] == remote.keys['target']['label'] and message['origin']['id'] == remote.keys['target']['id'] then
                                local unencryptedPacket = textutils.unserialize(crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet']))
                                if unencryptedPacket['type'] == 'snapshot' then
                                    snapshot = unencryptedPacket['data']
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    gui.snapshot = snapshot
end

function remote.checkMessages(event, side, channel, replyChannel, message, distance)
    -- ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28},
    -- Message Format: {['origin'] = {}, ['target'] = {}, ['packet'] = {}}
    -- ['packet'] = crypt.encrpt(sharedKey, )
    if channel == 14 then -- Handshakes
    elseif channel == 21 then -- Requests, login attempts, issue commands
    elseif channel == 28 then -- Data Transfers
        if message['target'] ~= nil then
            if message['target']['label'] == remote.getComputerInfo()['label'] and message['target']['id'] == remote.getComputerInfo()['id'] then
                if message['origin'] ~= nil then
                    if message['origin']['label'] == remote.keys['target']['label'] and message['origin']['id'] == remote.keys['target']['id'] then
                        local unencryptedPacket = textutils.unserialize(crypt.xorEncryptDecrypt(remote.keys['shared'], message['packet']))
                        if unencryptedPacket['type'] == 'snapshot' then
                            gui.snapshot = unencryptedPacket['data']
                        end
                    end
                end
            end
        end
    end
end --end checkMessages

function remote.clickedButton(event, button, x, y, arg4, arg5)
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
        elseif gui.settings['currentPage'] == 1 then
            if y == 9 then
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'toggleReactor'}))})
                end
            end
        elseif gui.settings['currentPage'] == 6 then -- Control Rods
            for k, v in pairs(gui.snapshot['rodInfo']['rods']) do
                if y == 8+k*2 then
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
        elseif gui.settings['currentPage'] == 7 then -- Automations
            if y == 6 then -- Power
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'powerToggle'}))})
                end
            elseif y == 8 then -- Power Max
                if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                    if gui.snapshot['automations']['powerMax'] > gui.snapshot['automations']['powerMin'] then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = 1, ['direction'] = 'down'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                    if gui.snapshot['automations']['powerMax']-5 < gui.snapshot['automations']['powerMin'] then
                        for i=1, 5 do
                            if gui.snapshot['automations']['powerMax']-1 == gui.snapshot['automations']['powerMin'] then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = i, ['direction'] = 'down'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = 5, ['direction'] = 'down'}))})
                    end
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                    if gui.snapshot['automations']['powerMax']-10 < gui.snapshot['automations']['powerMin'] then
                        for i=1, 10 do
                            if gui.snapshot['automations']['powerMax']-i == gui.snapshot['automations']['powerMin'] then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = i, ['direction'] = 'down'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = 10, ['direction'] = 'down'}))})
                    end
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                    if gui.snapshot['automations']['powerMax']+10 > 100 then
                        for i=1, 10 do
                            if gui.snapshot['automations']['powerMax']+i == 100 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = i, ['direction'] = 'up'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = 10, ['direction'] = 'up'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                    if gui.snapshot['automations']['powerMax']+5 > 100 then
                        for i=1, 5 do
                            if gui.snapshot['automations']['powerMax']+i == 100 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = i, ['direction'] = 'up'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = 5, ['direction'] = 'up'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                    if gui.snapshot['automations']['powerMax'] < 100 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMax', ['data'] = 1, ['direction'] = 'up'}))})
                    end
                end
                -- if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                --     gui.snapshot['automation']['powerMax'] = gui.snapshot['automation']['powerMax'] -1
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                --     gui.snapshot['automation']['powerMax'] = gui.snapshot['automation']['powerMax'] -5
                -- elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                --     gui.snapshot['automation']['powerMax'] = gui.snapshot['automation']['powerMax'] -10
                -- elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                --     gui.snapshot['automation']['powerMax'] = gui.snapshot['automation']['powerMax'] +10
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                --     gui.snapshot['automation']['powerMax'] = gui.snapshot['automation']['powerMax'] +5
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                --     gui.snapshot['automation']['powerMax'] = gui.snapshot['automation']['powerMax'] +1
                -- end
                -- if interface.automations['powerMax'] < 0 then
                --     interface.automations['powerMax'] = 0
                -- elseif interface.automations['powerMax'] > 100 then
                --     interface.automations['powerMax'] = 100
                -- end
            elseif y == 10 then -- Power Min
                if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                    if gui.snapshot['automations']['powerMin'] > 0 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = 1, ['direction'] = 'down'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                    if gui.snapshot['automations']['powerMin']-5 < 0 then
                        for i=1, 5 do
                            if gui.snapshot['automations']['powerMin']-1 == 0 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = i, ['direction'] = 'down'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = 5, ['direction'] = 'down'}))})
                    end
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                    if gui.snapshot['automations']['powerMin']-10 < 0 then
                        for i=1, 10 do
                            if gui.snapshot['automations']['powerMin']-i == 0 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = i, ['direction'] = 'down'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = 10, ['direction'] = 'down'}))})
                    end
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                    if gui.snapshot['automations']['powerMin']+10 > gui.snapshot['automations']['powerMax'] then
                        for i=1, 10 do
                            if gui.snapshot['automations']['powerMin']+i == gui.snapshot['automations']['powerMax'] then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = i, ['direction'] = 'up'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = 10, ['direction'] = 'up'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                    if gui.snapshot['automations']['powerMin']+5 > gui.snapshot['automations']['powerMax'] then
                        for i=1, 5 do
                            if gui.snapshot['automations']['powerMin']+i == gui.snapshot['automations']['powerMax'] then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = i, ['direction'] = 'up'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = 5, ['direction'] = 'up'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                    if gui.snapshot['automations']['powerMin'] < gui.snapshot['automations']['powerMax'] then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'powerMin', ['data'] = 1, ['direction'] = 'up'}))})
                    end
                end
                -- if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                --     interface.automations['powerMin'] = interface.automations['powerMin'] -1
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                --     interface.automations['powerMin'] = interface.automations['powerMin'] -5
                -- elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                --     interface.automations['powerMin'] = interface.automations['powerMin'] -10
                -- elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                --     interface.automations['powerMin'] = interface.automations['powerMin'] +10
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                --     interface.automations['powerMin'] = interface.automations['powerMin'] +5
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                --     interface.automations['powerMin'] = interface.automations['powerMin'] +1
                -- end
                -- if interface.automations['powerMin'] < 0 then
                --     interface.automations['powerMin'] = 0
                -- elseif interface.automations['powerMin'] > 100 then
                --     interface.automations['powerMin'] = 100
                -- end
            elseif y == 12 then -- Temperature
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'tempToggle'}))})
                end
            elseif y == 14 then -- Temperature Max
                if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                    if gui.snapshot['automations']['tempMax'] > 0 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = 1, ['direction'] = 'down'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                    if gui.snapshot['automations']['tempMax']-5 < 0 then
                        for i=1, 5 do
                            if gui.snapshot['automations']['tempMax']-1 == 0 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = i, ['direction'] = 'down'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = 5, ['direction'] = 'down'}))})
                    end
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                    if gui.snapshot['automations']['tempMax']-10 < 0 then
                        for i=1, 10 do
                            if gui.snapshot['automations']['tempMax']-i == 0 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = i, ['direction'] = 'down'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = 10, ['direction'] = 'down'}))})
                    end
                elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                    if gui.snapshot['automations']['tempMax']+10 > 1000 then
                        for i=1, 10 do
                            if gui.snapshot['automations']['tempMax']+i == 1000 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = i, ['direction'] = 'up'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = 10, ['direction'] = 'up'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                    if gui.snapshot['automations']['tempMax']+5 > 1000 then
                        for i=1, 5 do
                            if gui.snapshot['automations']['tempMax']+i == 1000 then
                                remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = i, ['direction'] = 'up'}))})
                                break
                            end
                        end
                    else
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = 5, ['direction'] = 'up'}))})
                    end
                elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                    if gui.snapshot['automations']['tempMax'] < 1000 then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'tempMax', ['data'] = 1, ['direction'] = 'up'}))})
                    end
                end
                -- if x == math.ceil((gui.width-(#'      buttons      '-2))/2) or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+1 then
                --     interface.automations['tempMax'] = interface.automations['tempMax'] -1
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+3 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+4 then
                --     interface.automations['tempMax'] = interface.automations['tempMax'] -5
                -- elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+6 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+8 then
                --     interface.automations['tempMax'] = interface.automations['tempMax'] -10
                -- elseif x >= math.ceil((gui.width-(#'      buttons      '-2))/2)+10 and x <= math.ceil((gui.width-(#'      buttons      '-2))/2)+12 then
                --     interface.automations['tempMax'] = interface.automations['tempMax'] +10
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+14 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+15 then
                --     interface.automations['tempMax'] = interface.automations['tempMax'] +5
                -- elseif x == math.ceil((gui.width-(#'      buttons      '-2))/2)+17 or x == math.ceil((gui.width-(#'      buttons      '-2))/2)+18 then
                --     interface.automations['tempMax'] = interface.automations['tempMax'] +1
                -- end
                -- if interface.automations['tempMax'] < 0 then
                --     interface.automations['tempMax'] = 0
                -- end
            elseif y == 16 then -- Control Rods
                if x>=1+gui.width*gui.widthFactor and x<=1+gui.width*gui.widthFactor+5 then
                    remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'controlRodsToggle'}))})
                end
            end
        elseif gui.settings['currentPage'] == 8 then -- Graphs
            if y == 6 then
                if x >=gui.width*gui.widthFactor+1 and x <= gui.width*gui.widthFactor+1+5 then
                    if gui.snapshot['status'] then
                        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'command', ['data'] = 'scram'}))})
                    end
                end
            end
        end
    end
end --end clickedButton

function remote.mouseWheel(event, arg1, arg2, arg3, arg4, arg5)
    local nothing = nil
end --end mouseWheel

function remote.snapshotHandler()
    while true do
        -- remote.requestSnapshot()
        remote.modem.transmit(21, 0, {['origin'] = remote.getComputerInfo(), ['target'] = remote.keys['target'], ['packet'] = crypt.xorEncryptDecrypt(remote.keys['shared'], textutils.serialize({['type'] = 'snapshot', ['data'] = nil}))})
        os.sleep(remote.fps)
    end
end

function remote.guiHandler()
    while true do
        gui.main()
        os.sleep(remote.fps)
    end
end

function remote.eventHandler()
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        if event == 'modem_message' then
            remote.checkMessages(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_up' or event == 'monitor_touch' then
            remote.clickedButton(event, arg1, arg2, arg3, arg4, arg5)
        elseif event == 'mouse_wheel' then
            remote.mouseWheel(event, arg1, arg2, arg3, arg4, arg5)
        end
    end
end

function remote.initialize()
    -- remote.generatePrivateKey()
    remote.write('Initializing...')
    remote.monitor = remote.checkForMonitor()
    remote.initializeMonitor()
    local tempModem = remote.checkForWirelessModem()
    if tempModem ~= false then
        remote.modem = tempModem
        remote.modem.open(7)
    end
    remote.readServerKeys()
    remote.login()
    remote.requestSnapshot()
    -- gui.log('Snapshot acquired: '..textutils.serialize(gui.snapshot))
    parallel.waitForAny(remote.snapshotHandler, remote.eventHandler, remote.guiHandler)
end --end initialize

return remote