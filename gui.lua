local ccStrings = require('cc.strings')

gui = {}

gui.authorized = nil
gui.snapshot = nil
-- gui.oldSnapshot = nil
gui.totalPages = 9
gui.width = nil
gui.height = 100
gui.widthFactor = 7/10
gui.monitor = nil
gui.logList = {}
gui.logCount = 0
gui.settings = nil
gui.stdBgColor = colors.gray
gui.colors = {
    ['power'] = colors.red,
    ['temperature'] = colors.orange,
    ['fuel'] = colors.yellow,
    ['coolant'] = colors.blue,
    ['vapor'] = colors.white,
    ['waste'] = colors.brown,
}
gui.pages = nil

function gui.initialize(monitor)
    gui.monitor = monitor
    gui.monitor.clear()
    gui.monitor.setCursorPos(1,1)
    gui.width, gui.height =  gui.monitor.getSize()
    gui.readSettings()
end --end initialize

function gui.log(string, storage)
    local logging = {['order'] = gui.logCount+1, ['time'] = os.date('%T'), ['message'] = string}
    table.insert(gui.logList, logging)
    local file = nil
    if storage ~= nil then
        file = fs.open(storage..'er_interface/logs/'..os.date('%F')..'.log', 'a')
    else
        file = fs.open('./'..'er_interface/logs/'..os.date('%F')..'.log', 'a')
    end 
    file.write(logging['time']..' '..logging['message']..'\n')
    file.close()
    gui.logCount = gui.logCount + 1
    while #gui.logList > gui.height-5 do
        local oldestIndex = nil
        local oldest = nil
        for i, j in pairs(gui.logList) do
            if oldest == nil then
                oldestIndex = i
                oldest = j['time']
            elseif j['time'] < oldest then
                oldestIndex = i
                oldest = j['time']
            end
        end
        table.remove(gui.logList, oldestIndex)
    end
end --end log

function gui.getNumPages()
    -- gui.log('Page Number gotten is '..#gui.pages)
    return #gui.pages
end --end getNumPages

function gui.compareElementsByID(a, b)
    return tonumber(a['id']) < tonumber(b['id'])
end --end compareKeys

function gui.readClients() --Only for Interface/Server; not remote
    local file = fs.open('./er_interface/keys/clients', 'r')
    local clients = textutils.unserialize(file.readAll())
    file.close()
    table.sort(clients, gui.compareElementsByID)
    return clients
end --end readClients

function gui.readSettings()
    if not fs.exists('./er_interface/settings.cfg') then
        gui.writeSettings('default')
    end
    local file = fs.open('./er_interface/settings.cfg', 'r')
    gui.settings = textutils.unserialize(file.readAll())
    file.close()
end --end readSettings

function gui.writeSettings(settings)
    if settings == 'default' then
        gui.settings = {
            ['currentPage'] = 1, 
            ['currentPageTitle'] = 'home',
            ['storedPower'] = 0, 
            ['deltaPower'] = 0, 
            ['snapshotTime'] = 0, 
            ['deltaTime'] = 0,
            ['mouseWheel'] = 0,
        }
    end
    local file = fs.open('./er_interface/settings.cfg', 'w')
    file.write(textutils.serialize(gui.settings))
    file.close()   
end --end writeSettings

function gui.getPageTitle(pageNum)
    if not gui.snapshot['activelyCooled'] then
        if pageNum == 1 then
            return 'Home'
        elseif pageNum == 2 then
            return 'Fuel'
        elseif pageNum == 3 then
            return 'Power'
        elseif pageNum == 4 then
            return 'Graphs'
        elseif pageNum == 5 then
            return 'Rod Statistics'
        elseif pageNum == 6 then
            return 'Automations'
        elseif pageNum == 7 then
            return 'Connection'
        end
    else
        if pageNum == 1 then
            return 'Home'
        elseif pageNum == 2 then
            return 'Fuel'
        elseif pageNum == 3 then
            return 'Vapor'
        elseif pageNum == 4 then
            return 'Coolant'
        elseif pageNum == 5 then
            return 'Graphs'
        elseif pageNum == 6 then
            return 'Rod Statistics'
        elseif pageNum == 7 then
            return 'Automations'
        elseif pageNum == 8 then
            return 'Connection'
        end
    end
end --end getPageTitle

function gui.nextPage(forward) -- true/false forwards/backwards
    gui.readSettings()
    if forward ~= nil then
        if forward == true then
            -- if gui.settings['currentPage'] == gui.totalPages then
            if gui.settings['currentPage'] == gui.getNumPages() then
                gui.settings['currentPage'] = 1
            else
                gui.settings['currentPage'] = gui.settings['currentPage'] + 1
            end
        elseif forward == false then
            if gui.settings['currentPage'] == 1 then
                -- gui.settings['currentPage'] = gui.totalPages
                gui.settings['currentPage'] = gui.getNumPages()
            else
                gui.settings['currentPage'] = gui.settings['currentPage'] - 1
            end
        end
    end
    gui.settings['currentPageTitle'] = gui.getPageTitle(gui.settings['currentPage'])
    gui.settings['mouseWheel'] = 0
    gui.writeSettings()
end --end nextPage

function gui.clickedButton(button, x, y, craftables)
    gui.readSettings()
    if button == 1 or peripheral.isPresent(tostring(button)) then
        if y == 1 and x == gui.width then -- Terminate Program
            gui.monitor.setBackgroundColor(colors.black)
            gui.monitor.clear()
            gui.monitor.setTextColor(colors.red)
            print('AE2 Interface has been ')
            gui.monitor.setTextColor(colors.white)
            os.queueEvent('terminate')
            os.sleep(100)
        elseif y == gui.height then -- Previous/Next Buttons
            if x>=gui.width-6 and x<=gui.width-2 then --Next
                gui.nextPage(true)
                gui.writeSettings()
                return true
            elseif x>=2 and x<=6 then --Prev
                gui.nextPage(false)
                gui.writeSettings()
                return true
            end
        end
    end
    return false
end --end clickedButton

function gui.updateTime()
    local tempText = gui.monitor.getTextColor()
    local tempBack = gui.monitor.getBackgroundColor()
    local x, y = gui.monitor.getCursorPos()
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.red)
    gui.monitor.setCursorPos(gui.width, 1)
    gui.monitor.write('X')
    gui.monitor.setBackgroundColor(gui.stdBgColor)
    for i=1, gui.width-1 do
        gui.monitor.setCursorPos(i,1)
        gui.monitor.write(' ')
    end
    gui.monitor.setCursorPos(1,1)
    gui.monitor.write(os.date())
    gui.monitor.setCursorPos(x, y)
    gui.monitor.setTextColor(tempText)
    gui.monitor.setBackgroundColor(tempBack)
end

function gui.clearScreen()
    local x, y = gui.monitor.getCursorPos()
    gui.monitor.setBackgroundColor(gui.stdBgColor)
    for i=1, gui.height do
        for j=1, gui.width do
            gui.monitor.setCursorPos(j,i)
            gui.monitor.write(' ')
        end
    end
    gui.monitor.setCursorPos(x, y)
end

function gui.drawButtons()
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.lightGray)
    gui.monitor.setCursorPos(2, gui.height)
    gui.monitor.write('<PREV')
    gui.monitor.setCursorPos(gui.width-5-1, gui.height)
    gui.monitor.write('NEXT>')
    gui.monitor.setCursorPos(1, gui.height)
    gui.monitor.setBackgroundColor(gui.stdBgColor)
    gui.monitor.setCursorPos(gui.width/2-3, gui.height)
    if gui.settings['currentPage'] < 10 then
        gui.monitor.write('Page 0'..gui.settings['currentPage'])
    else
        gui.monitor.write('Page '..gui.settings['currentPage'])
    end
    gui.monitor.setCursorPos(1, gui.height)
end --end drawButtons

function gui.signup(target)
    local info = {
        '',
        'Connecting to:',
        string.sub(target['label'], 0, gui.width-4),
        'with server ID: '..target['id'],
        ' ',
        'Please Enter a',
        'Strong Password',
        '(3-17 Characters)',
        '',
        '',
        '',
    }
    local length = ''
    for _, v in pairs(info) do
        if #v > #length then
            length = string.format('%'..tostring(#v+2)..'s', ' ')
        end
    end
    gui.monitor.setVisible(false)
    gui.clearScreen()
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.lightGray)
    -- for k, _ in pairs(info) do
    --     gui.monitor.setCursorPos(math.floor(gui.width/2)-math.floor(#length/2), math.floor(gui.height/2)-math.floor(#info/2)+k)
    --     gui.monitor.write(length)
    -- end
    for k, v in pairs(info) do
        gui.monitor.setCursorPos(math.ceil(gui.width/2)-math.floor(#length/2), math.ceil(gui.height/2)-math.floor(#info/2)+k)
        gui.monitor.write(length)
        gui.monitor.setCursorPos(math.ceil(gui.width/2)-math.floor(#v/2), math.ceil(gui.height/2)-math.floor(#info/2)+k)
        gui.monitor.write(v)
    end
    gui.monitor.setCursorPos(math.ceil(gui.width/2)-math.floor(#length/2)+1, math.ceil(gui.height/2)-math.floor(#info/2)+#info-1)
    gui.monitor.setVisible(true)
    return read('*')
end --end signup

function gui.login(target)
    gui.monitor.setVisible(false)
    gui.clearScreen()
    local info = {
        '',
        'Connecting to:',
        string.sub(target['label'], 0, gui.width-4),
        'with server ID: '..target['id'],
        '',
        'Please enter the',
        'login password:',
        '',
        '',
        '',
    }
    local length = ''
    for _, v in pairs(info) do
        if #v > #length then
            length = string.format('%'..tostring(#v)..'s', ' ')
        end
    end
    length = length..'  '
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.lightGray)
    for k, v in pairs(info) do
        gui.monitor.setCursorPos(math.ceil((gui.width-(#length-2))/2), math.floor((gui.height-#info)/2)+k)
        gui.monitor.write(length)
        gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), math.floor((gui.height-#info)/2)+k)
        gui.monitor.write(v)
    end
    gui.monitor.setCursorPos(math.floor((gui.width-(#length-5))/2), math.floor((gui.height-#info)/2)+#info-1)
    gui.monitor.setVisible(true)
    return read('*')
end --end login

function gui.updateSnapshot(snapshot)
    gui.snapshot = snapshot
    if not gui.snapshot['activelyCooled'] then
        gui.pages = {
            [1] = gui.pageSnapshot,
            [2] = gui.pageFuel,
            [3] = gui.pagePower,
            [4] = gui.pageGraphs,
            [5] = gui.pageRods,
            [6] = gui.pageAutomations,
            [7] = gui.pageConnections,
        }
        gui.readSettings()
        if gui.settings['currentPage'] > #gui.pages then
            gui.settings['currentPage'] = #gui.pages
            gui.writeSettings(gui.settings)
        end
    else 
        gui.pages = {
            [1] = gui.pageSnapshot,
            [2] = gui.pageFuel,
            [3] = gui.pageVapor,
            [4] = gui.pageCoolant,
            [5] = gui.pageGraphs,
            [6] = gui.pageRods,
            [7] = gui.pageAutomations,
            [8] = gui.pageConnections,
        }
    end
end --end updateSnapshot

function gui.formatNum(number)
    if number == nil then
        number = 0.00
    end
    local absNum, suffix, scaled = math.abs(number), '', number
    if absNum >= 1000000000000 then -- Trillion
        scaled = number / 1000000000000
        suffix = "T"
    elseif absNum >= 1000000000 then -- Billion
        scaled = number / 1000000000
        suffix = "B"
    elseif absNum >= 1000000 then -- Million
        scaled = number / 1000000
        suffix = "M"
    elseif absNum >= 1000 then -- Kilo
        scaled = number / 1000
        suffix = "K"
    elseif absNum >= 1 then
        scaled = number
        suffix = ""
    elseif absNum >= 0.001 then -- Milli
        scaled = number * 1000
        suffix = "m"
    elseif absNum >= 0.000001 then -- Micro
        scaled = number * 1000000
        -- suffix = "μ"
        suffix = string.char(181)
    elseif absNum >= 0.000000001 then -- Nano
        scaled = number * 1000000000
        suffix = "n"
    end
    return string.format("%.1f%s", scaled, suffix)
end --end formatNum

function gui.main()
    gui.monitor.setVisible(false)
    gui.readSettings()
    gui.clearScreen()
    -- gui.log('Drawing page: '..gui.settings['currentPage'])
    -- gui.log('Page drawn was: '..tostring(gui.pages[gui.settings['currentPage']]))
    gui.pages[gui.settings['currentPage']]()
    -- if not gui.snapshot['activelyCooled'] then
    --     if gui.settings['currentPage'] == 1 then
    --         gui.pageSnapshot()
    --     elseif gui.settings['currentPage'] == 2 then
    --         gui.pageFuel()
    --     elseif gui.settings['currentPage'] == 3 then
    --         gui.pagePower()
    --     elseif gui.settings['currentPage'] == 4 then
    --         gui.pageGraphs()
    --     elseif gui.settings['currentPage'] == 5 then
    --         gui.pageRods()
    --     elseif gui.settings['currentPage'] == 6 then
    --         gui.pageAutomations()
    --     elseif gui.settings['currentPage'] == 7 then
    --         gui.pageConnection()
    --     end
    -- else
    --     if gui.settings['currentPage'] == 1 then
    --         gui.pageSnapshot()
    --     elseif gui.settings['currentPage'] == 2 then
    --         gui.pageFuel()
    --     elseif gui.settings['currentPage'] == 3 then
    --         gui.pageVapor()
    --     elseif gui.settings['currentPage'] == 4 then
    --         gui.pageCoolant()
    --     elseif gui.settings['currentPage'] == 5 then
    --         gui.pageGraphs()
    --     elseif gui.settings['currentPage'] == 6 then
    --         gui.pageRods()
    --     elseif gui.settings['currentPage'] == 7 then
    --         gui.pageAutomations()
    --     elseif gui.settings['currentPage'] == 8 then
    --         gui.pageConnection()
    --     end
    -- end
    gui.updateTime()
    gui.drawButtons()
    gui.monitor.setVisible(true)
end --end main

function gui.pageSnapshot() --Snapshot Report
    local content, contentColors = nil, nil
    if not gui.snapshot['activelyCooled'] then
        content = {
            [0] = 'Snapshot Report: ',
            [1] = gui.snapshot['report']['datestamp'],
            [2] = ccStrings.ensure_width('Server Name', gui.width*gui.widthFactor)..'ID',
            [3] = ccStrings.ensure_width(string.sub(gui.snapshot['report']['origin']['label'], 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..gui.snapshot['report']['origin']['id'],
            [4] = '',
            [5] = '',
            [6] = 'reactorStatus',
            [7] = '',
            [8] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['casingTemperature']),
            [9] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['amount']),
            [10] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['wasteAmount']),
            [11] = ccStrings.ensure_width('Power (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['energyInfo']['stored']),
            [12] = '',
        }
        contentColors = {
            [0] = colors.yellow,
            [1] = colors.white,
            [2] = colors.yellow,
            [3] = colors.white,
            [4] = gui.stdBgColor,
            [5] = gui.stdBgColor, -- Empty Space
            [6] = colors.yellow,
            [7] = gui.stdBgColor, -- Empty Space
            [8] = gui.colors['temperature'], 
            [9] = gui.colors['fuel'],
            [10] = gui.colors['waste'],
            [11] = gui.colors['power'],    
            [12] = colors.lightGray,
        }
    else
        content = {
            [0] = 'Snapshot Report: ',
            [1] = gui.snapshot['report']['datestamp'],
            [2] = ccStrings.ensure_width('Server Name', gui.width*gui.widthFactor)..'ID',
            [3] = ccStrings.ensure_width(string.sub(gui.snapshot['report']['origin']['label'], 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..gui.snapshot['report']['origin']['id'],
            [4] = '',
            [5] = '',
            [6] = 'reactorStatus',
            [7] = '',
            [8] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['casingTemperature']),
            [9] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['amount']),
            [10] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['wasteAmount']),
            [11] = ccStrings.ensure_width('Vapor (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['amount']),
            [12] = ccStrings.ensure_width('Coolant (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['coolantInfo']['amount']),
            [13] = '',
        }
        contentColors = {
            [0] = colors.yellow,
            [1] = colors.white,
            [2] = colors.yellow,
            [3] = colors.white,
            [4] = gui.stdBgColor,
            [5] = gui.stdBgColor, -- Empty Space
            [6] = colors.yellow,
            [7] = gui.stdBgColor, -- Empty Space
            [8] = gui.colors['temperature'],
            [9] = gui.colors['fuel'],
            [10] = gui.colors['waste'],
            [11] = gui.colors['vapor'],
            [12] = gui.colors['coolant'],
            [13] = colors.lightGray,
        }
    end
    gui.monitor.setBackgroundColor(gui.stdBgColor)
    for k, v in pairs(content) do
        if k > 4 then
            gui.monitor.setCursorPos(2,3+k)
            gui.monitor.setBackgroundColor(colors.black)
            for i=0, gui.width-3 do
                gui.monitor.write(' ')
            end
            gui.monitor.setCursorPos(3,3+k)
        else
            gui.monitor.setCursorPos(2,3+k)
        end
        if v == 'reactorStatus' then
            gui.monitor.setBackgroundColor(colors.black)
            -- gui.monitor.setCursorPos(2,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(ccStrings.ensure_width('Reactor Status:', gui.width*gui.widthFactor-1))
            gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
            if gui.snapshot['status'] == true then
                gui.monitor.setBackgroundColor(colors.green)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' ON  ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            else
                gui.monitor.setBackgroundColor(colors.red)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' OFF ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            end
        else
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
            gui.monitor.setBackgroundColor(gui.stdBgColor)
        end
    end
end --end page

function gui.pagePower() -- Power
    local powerBar = ''
    for i=1, (gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*(gui.width-4) do
        powerBar = powerBar..' '
    end
    local content = {
        [0] = '',
        [1] = 'Power Statistics',
        [2] = '',
        [3] = ccStrings.ensure_width('Power:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*1000)/10)..'%',
        [4] = 'powerBar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['energyInfo']['stored']),
        [7] = ccStrings.ensure_width('Capacity (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['energyInfo']['capacity']),
        [8] = ccStrings.ensure_width('FE/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['energyInfo']['lastTick']),
        -- [9] = ccStrings.ensure_width('Delta Power:', gui.width*gui.widthFactor-1)..gui.formatNum((gui.snapshot['energyInfo']['stored']-gui.oldSnapshot['energyInfo']['stored'])),
        [9] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = gui.colors['power'],
        [2] = gui.stdBgColor,
        [3] = gui.colors['power'],
        [4] = gui.colors['power'],
        [5] = gui.stdBgColor,
        [6] = gui.colors['power'],
        [7] = gui.colors['power'],
        [8] = gui.colors['power'],
        -- [9] = colors.magenta,
        [9] = gui.stdBgColor,
    }    
    for k, v in pairs(content) do
        gui.monitor.setCursorPos(2,3+k)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        elseif v == 'powerBar' then
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setBackgroundColor(contentColors[k])
            gui.monitor.write(powerBar)
            gui.monitor.setBackgroundColor(gui.stdBgColor)
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page

function gui.pageFuel() -- Fuel Page
    local fuelBar = ''
    for i=1, (gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*(gui.width-4) do
        fuelBar = fuelBar..' '
    end
    local content = {
        [0] = '',
        [1] = 'Fuel Statistics',
        [2] = '',
        [3] = ccStrings.ensure_width('Fuel:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*1000)/10)..'%',
        [4] = 'fuelBar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['max']),
        [8] = ccStrings.ensure_width('mB/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['lastTick']),
        [9] = ccStrings.ensure_width('Reactivity:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['reactivity']),
        [10] = ccStrings.ensure_width('Temperature (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['temperature']),
        [11] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['wasteAmount']),
        [12] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = gui.colors['fuel'],
        [2] = gui.stdBgColor,
        [3] = gui.colors['fuel'],
        [4] = gui.colors['fuel'],
        [5] = gui.stdBgColor,
        [6] = gui.colors['fuel'],
        [7] = gui.colors['fuel'],
        [8] = gui.colors['fuel'],
        [9] = gui.colors['fuel'],
        [10] = gui.colors['fuel'],
        [11] = gui.colors['fuel'],
        [12] = gui.stdBgColor,
    }
    for k, v in pairs(content) do
        gui.monitor.setCursorPos(2,3+k)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        elseif v == 'fuelBar' then
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setBackgroundColor(contentColors[k])
            gui.monitor.write(fuelBar)
            gui.monitor.setBackgroundColor(gui.stdBgColor)
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page

function gui.pageCoolant() -- Coolant
    local coolantBar = ''
    for i=1, (gui.snapshot['coolantInfo']['amount']/gui.snapshot['coolantInfo']['max'])*(gui.width-4) do
        coolantBar = coolantBar..' '
    end
    local content = {
        [0] = '',
        [1] = 'Coolant Statistics',
        [2] = '',
        [3] = ccStrings.ensure_width('Coolant:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['coolantInfo']['amount']/gui.snapshot['coolantInfo']['max'])*1000)/10)..'%',
        [4] = 'coolantBar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['coolantInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['coolantInfo']['max']),
        [8] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..tostring(gui.snapshot['coolantInfo']['type']),
        [9] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = gui.colors['coolant'],
        [2] = gui.stdBgColor,
        [3] = gui.colors['coolant'],
        [4] = gui.colors['coolant'],
        [5] = gui.stdBgColor,
        [6] = gui.colors['coolant'],
        [7] = gui.colors['coolant'],
        [8] = gui.colors['coolant'],
        [9] = gui.stdBgColor,
    }
    for k, v in pairs(content) do
        gui.monitor.setCursorPos(2,3+k)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        elseif v == 'coolantBar' then
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setBackgroundColor(contentColors[k])
            gui.monitor.write(coolantBar)
            gui.monitor.setBackgroundColor(gui.stdBgColor)
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page

function gui.pageVapor() -- Hot Fluid
    local vaporbar = ''
    for i=1, (gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*(gui.width-4) do
        vaporbar = vaporbar..' '
    end
    local content = {
        [0] = '',
        [1] = 'Vapor Statistics',
        [2] = '',
        [3] = ccStrings.ensure_width('Vapor:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*1000)/10)..'%',
        [4] = 'vaporbar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['max']),
        [8] = ccStrings.ensure_width('mB/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['lastTick']),
        [9] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..tostring(gui.snapshot['hotFluidInfo']['type']),
        [10] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = gui.colors['vapor'],
        [2] = gui.stdBgColor,
        [3] = gui.colors['vapor'],
        [4] = gui.colors['vapor'],
        [5] = gui.stdBgColor,
        [6] = gui.colors['vapor'],
        [7] = gui.colors['vapor'],
        [8] = gui.colors['vapor'],
        [9] = gui.colors['vapor'],
        [10] = gui.stdBgColor,
    }
    for k, v in pairs(content) do
        gui.monitor.setCursorPos(2,3+k)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        elseif v == 'vaporbar' then
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setBackgroundColor(contentColors[k])
            gui.monitor.write(vaporbar)
            gui.monitor.setBackgroundColor(gui.stdBgColor)
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page

function gui.pageGraphs() -- Graphs
    local content = {
        [0] = '',
        [1] = 'Graphs',
        [2] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.yellow,
        [2] = gui.stdBgColor,
    }
    local graphContent, graphNames, graphColors = nil, nil, nil
    if not gui.snapshot['activelyCooled'] then
        graphContent = {
            [0] = math.floor((gui.snapshot['casingTemperature']+gui.snapshot['fuelInfo']['temperature'])/2/(gui.snapshot['automations']['tempMax']+gui.snapshot['automations']['tempMax']*0.1)), --Temperature
            [1] = math.floor((gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*1000)/10, --Fuel
            [2] = math.floor((gui.snapshot['wasteAmount']/gui.snapshot['fuelInfo']['max'])*1000)/10, --Waste
            [3] = math.floor((gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*1000)/10, --Power
        }
        graphNames = {
            [0] = 'Temp.',
            [1] = 'Fuel',
            [2] = 'Waste',
            [3] = 'Power',
        }
        graphColors = {
            [0] = gui.colors['temperature'],
            [1] = gui.colors['fuel'],
            [2] = gui.colors['waste'],
            [3] = gui.colors['power'],
        }
    else
        graphContent = {
            [0] = math.floor((gui.snapshot['casingTemperature']+gui.snapshot['fuelInfo']['temperature'])/2/(gui.snapshot['automations']['tempMax']+gui.snapshot['automations']['tempMax']*0.1)), --Temperature
            [1] = math.floor((gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*1000)/10, --Fuel
            [2] = math.floor((gui.snapshot['wasteAmount']/gui.snapshot['fuelInfo']['max'])*1000)/10, --Waste
            [3] = math.floor((gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*1000)/10, --Vapor
            [4] = math.floor((gui.snapshot['coolantInfo']['amount']/gui.snapshot['coolantInfo']['max'])*1000)/10, --Coolant
            
        }
        graphNames = {
            [0] = 'Temp.',
            [1] = 'Fuel',
            [2] = 'Waste',
            [3] = 'Vapor',
            [4] = 'Coolant',
        }
        graphColors = {
            [0] = gui.colors['temperature'],
            [1] = gui.colors['fuel'],
            [2] = gui.colors['waste'],
            [3] = gui.colors['vapor'],
            [4] = gui.colors['coolant'],
        }
    end
    for i=1, gui.height-4 do -- Background
        gui.monitor.setCursorPos(2,2+i)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
    end
    for k, v in pairs(content) do -- Title Card
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        end
    end
    local graphWidth = math.floor(((gui.width-4)-(#graphContent))/(#graphContent+1))
    local removedGraphs = 0
    while graphWidth < 3 do -- If there are too many graphs, we must reduce the number of drawn 
        removedGraphs = removedGraphs + 1
        graphWidth = math.floor(((gui.width-4)-(#graphContent-removedGraphs))/(#graphContent+1-removedGraphs))
    end
    
    -- for k, v in pairs(graphContent) do -- Per Graph
    for k=0, #graphContent-removedGraphs do -- Per Graph
        gui.monitor.setTextColor(graphColors[k])
        for i = 1, graphWidth do -- Per Width Pixel
            if i == 1 then -- Name of graph
                for j = 1, gui.height-8 do -- Per Height Pixel
                    gui.monitor.setBackgroundColor(colors.gray)
                    if gui.height-8-j <= #graphNames[k] and gui.height-8-j ~= 0 then
                        gui.monitor.setCursorPos(2+graphWidth*(k)+k+i, gui.height-2-j)
                        gui.monitor.write(string.sub(graphNames[k], gui.height-8-j, gui.height-8-j))
                    else
                        gui.monitor.setCursorPos(2+graphWidth*(k)+k+i, gui.height-2-j)
                        gui.monitor.write(' ')
                    end
                end
            elseif i == graphWidth then -- End of graph
                gui.monitor.setBackgroundColor(colors.gray)
                for j = 1, gui.height-8 do -- Per Height Pixel
                    gui.monitor.setCursorPos(2+graphWidth*(k)+k+i, gui.height-2-j)
                    gui.monitor.write(' ')
                end
            else -- Main body of graph
                for j = 1, gui.height-8 do -- Per Height Pixel
                    if j > 1 and j < gui.height-8 and j-1 <= (gui.height-10)*(graphContent[k]/100) then
                        gui.monitor.setBackgroundColor(graphColors[k])
                        gui.monitor.setCursorPos(2+graphWidth*(k)+k+i, gui.height-2-j)
                        gui.monitor.write(' ')
                    else
                        gui.monitor.setBackgroundColor(colors.gray)
                        gui.monitor.setCursorPos(2+graphWidth*(k)+k+i, gui.height-2-j)
                        gui.monitor.write(' ')
                    end
                end
            end
        end
    end
    -- local buttons = {
    --     [0] = 'SCRAM!',
    -- }
    -- gui.monitor.setTextColor(colors.white)
    -- for k, v in pairs(buttons) do
    --     gui.monitor.setCursorPos(gui.width*gui.widthFactor+1, 6+k)
    --     if v == 'SCRAM!' then
    --         if gui.snapshot['status'] then
    --             gui.monitor.setBackgroundColor(colors.green)
    --         else
    --             gui.monitor.setBackgroundColor(colors.red)
    --         end
    --         gui.monitor.write(v)
    --     end
    -- end
end --end page

function gui.pageRods() -- Rods Page
    local buttons = {
        [0] = '-1', 
        [1] = '-5',
        [2] = '-10',
        [3] = '+10',
        [4] = '+5',
        [5] = '+1',
    }
    local content = {
        [0] = '',
        [1] = 'Rod Statistics',
        [2] = '',
        [3] = ccStrings.ensure_width('# Name', gui.width*gui.widthFactor-1)..'Level',
        [4] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.yellow,
        [2] = gui.stdBgColor,
        [3] = colors.yellow,
        [4] = gui.stdBgColor,
    }
    for k, v in pairs(gui.snapshot['rodInfo']['rods']) do
        if (k+1)*2 >= (gui.height-6-2) then
            break
        end
        content[#content] = ccStrings.ensure_width(tostring(k)..' '..v['name'], gui.width*gui.widthFactor-1)..v['level']
        content[#content+1] = '      buttons      '
        contentColors[#contentColors] = colors.white
        contentColors[#contentColors+1] = colors.white
    end
    content[#content+1] = ''
    contentColors[#contentColors+1] = gui.stdBgColor
    for k, v in pairs(content) do
        gui.monitor.setCursorPos(2,3+k)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        elseif v == '      buttons      ' then
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.setTextColor(contentColors[k])
            for k, v in pairs(buttons) do
                gui.monitor.setBackgroundColor(colors.lightGray)
                gui.monitor.write(v)
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.write(' ')
            end
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page

function gui.pageAutomations() -- Automations
    local buttons = {
        [0] = '-1', 
        [1] = '-5',
        [2] = '-10',
        [3] = '+10',
        [4] = '+5',
        [5] = '+1',
    }
    local content = nil
    if not gui.snapshot['activelyCooled'] then
        content = {
            [0] = '',
            [1] = 'Automations',
            [2] = '',
            [3] = 'Power',
            [4] = ccStrings.ensure_width('Max Power %', gui.width*gui.widthFactor-1)..gui.snapshot['automations']['powerMax'],
            [5] = '      buttons      ',
            [6] = ccStrings.ensure_width('Min Power %', gui.width*gui.widthFactor-1)..gui.snapshot['automations']['powerMin'],
            [7] = '      buttons      ',
            [8] = '',
            [9] = 'Temperature',
            [10] = ccStrings.ensure_width('Max Temperature', gui.width*gui.widthFactor-1)..gui.snapshot['automations']['tempMax'],
            [11] = '      buttons      ',
            [12] = '',
            [13] = 'Control Rods',
            [14] = '',
        }
    else
        content = {
            [0] = '',
            [1] = 'Automations',
            [2] = '',
            [3] = 'Vapor',
            [4] = ccStrings.ensure_width('Max Vapor %', gui.width*gui.widthFactor-1)..gui.snapshot['automations']['powerMax'],
            [5] = '      buttons      ',
            [6] = ccStrings.ensure_width('Min Vapor %', gui.width*gui.widthFactor-1)..gui.snapshot['automations']['powerMin'],
            [7] = '      buttons      ',
            [8] = '',
            [9] = 'Temperature',
            [10] = ccStrings.ensure_width('Max Temperature', gui.width*gui.widthFactor-1)..gui.snapshot['automations']['tempMax'],
            [11] = '      buttons      ',
            [12] = '',
            [13] = 'Control Rods',
            [14] = '',
        }
    end
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.yellow,
        [2] = gui.stdBgColor,
        [3] = colors.yellow,
        [4] = colors.white,
        [5] = colors.white,
        [6] = colors.white,
        [7] = colors.white,
        [8] = colors.white,
        [9] = colors.yellow,
        [10] = colors.white,
        [11] = colors.white,
        [12] = colors.white,
        [13] = colors.yellow,
        [14] = gui.stdBgColor,
    }
    for k, v in pairs(content) do
        gui.monitor.setCursorPos(2,3+k)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        elseif v == '      buttons      ' then
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.setTextColor(contentColors[k])
            for k, v in pairs(buttons) do
                gui.monitor.setBackgroundColor(colors.lightGray)
                gui.monitor.write(v)
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.write(' ')
            end
        elseif v == 'Power' or v == 'Vapor' then
            gui.monitor.setBackgroundColor(colors.black)
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(ccStrings.ensure_width(v, gui.width*gui.widthFactor-1))
            gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
            if gui.snapshot['automations']['powerToggle'] == true then
                gui.monitor.setBackgroundColor(colors.green)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' ON  ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            else
                gui.monitor.setBackgroundColor(colors.red)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' OFF ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            end
        elseif v == 'Temperature' then
            gui.monitor.setBackgroundColor(colors.black)
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(ccStrings.ensure_width(v, gui.width*gui.widthFactor-1))
            gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
            if gui.snapshot['automations']['tempToggle'] == true then
                gui.monitor.setBackgroundColor(colors.green)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' ON  ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            else
                gui.monitor.setBackgroundColor(colors.red)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' OFF ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            end
        elseif v == 'Control Rods' then
            gui.monitor.setBackgroundColor(colors.black)
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(ccStrings.ensure_width(v, gui.width*gui.widthFactor-1))
            gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
            if gui.snapshot['automations']['controlRodsToggle'] == true then
                gui.monitor.setBackgroundColor(colors.green)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' ON  ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            else
                gui.monitor.setBackgroundColor(colors.red)
                gui.monitor.setTextColor(colors.white)
                gui.monitor.write(' OFF ')
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            end
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page

function gui.pageConnections() -- Manage Clients // Connection to Server
    if fs.exists('./er_interface/interface.lua') then -- Manage Clients on Server
        local content = {
            [0] = '',
            [1] = 'Manage Clients',
            [2] = '',
            -- [3] = ccStrings.ensure_width('Name', gui.width*gui.widthFactor-1)..'ID',
            [3] = ccStrings.ensure_width(ccStrings.ensure_width('ID', 4)..' '..ccStrings.ensure_width('Name', gui.width*gui.widthFactor-1-5)..' '..'Idle', gui.width-4),
        }
        local contentColors = {
            [0] = gui.stdBgColor,
            [1] = colors.yellow,
            [2] = gui.stdBgColor,
            [3] = colors.yellow,
        }
        local contentBackgroundColors = {
            [0] = colors.black,
            [1] = colors.black,
            [2] = colors.black,
            [3] = colors.black,
        }
        for _, i in pairs(gui.readClients()) do
            -- content[#content+1] = ccStrings.ensure_width(ccStrings.ensure_width(i['label'], gui.width*gui.widthFactor-1)..i['id'], gui.width-4)
            content[#content+1] = ccStrings.ensure_width(ccStrings.ensure_width(tostring(i['id']), 4)..' '..ccStrings.ensure_width(i['label'], gui.width*gui.widthFactor-1-5)..' '..gui.formatNum((os.epoch('local')-i['lastActivity'])/1000)..'s', gui.width-4)
            contentColors[#contentColors+1] = colors.white
            local timeoutPeriod = 60*5
            if (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.2 then -- 1/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.green
            elseif (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.4 then -- 2/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.lime
            elseif (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.6 then -- 3/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.yellow
            elseif (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.8 then -- 4/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.orange
            else -- The full Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.red
            end
        end
        content[#content+1] = ''
        contentColors[#contentColors+1] = gui.stdBgColor
        contentBackgroundColors[#contentBackgroundColors+1] = colors.black
        for k, v in pairs(content) do
            gui.monitor.setCursorPos(2,3+k)
            gui.monitor.setBackgroundColor(colors.black)
            for i=0, gui.width-3 do
                gui.monitor.write(' ')
            end
            gui.monitor.setBackgroundColor(contentBackgroundColors[k])
            if k == 1 then --Title
                gui.monitor.setTextColor(contentColors[k])
                gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
                gui.monitor.write(v)
            else
                gui.monitor.setCursorPos(3,3+k)
                gui.monitor.setTextColor(contentColors[k])
                gui.monitor.write(v)
            end
        end
    else
        local content = {
            [0] = '',
            [1] = 'Connection Info',
            [2] = '',
            [3] = ccStrings.ensure_width('Client Name', gui.width*gui.widthFactor)..'ID',
            [4] = ccStrings.ensure_width(string.sub(os.getComputerLabel(), 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..os.getComputerID(),
            [5] = '',
            [6] = ccStrings.ensure_width('Server Name', gui.width*gui.widthFactor)..'ID',
            [7] = ccStrings.ensure_width(string.sub(gui.snapshot['report']['origin']['label'], 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..gui.snapshot['report']['origin']['id'],
            [8] = '',
            [9] = ccStrings.ensure_width('Latency', gui.width*gui.widthFactor),
            [10] = ccStrings.ensure_width(gui.formatNum((os.epoch('local')-gui.snapshot['report']['timestamp'])/1000)..'s', gui.width*gui.widthFactor),
            [11] = '',
        }
        local contentColors = {
            [0] = gui.stdBgColor,
            [1] = colors.yellow,
            [2] = gui.stdBgColor,
            [3] = colors.yellow,
            [4] = colors.white,
            [5] = gui.stdBgColor,
            [6] = colors.yellow,
            [7] = colors.white,
            [8] = gui.stdBgColor,
            [9] = colors.yellow,
            [10] = colors.white,
            [11] = gui.stdBgColor,
        }
        for k, v in pairs(content) do
            gui.monitor.setCursorPos(2,3+k)
            gui.monitor.setBackgroundColor(colors.black)
            for i=0, gui.width-3 do
                gui.monitor.write(' ')
            end
            if k == 1 then --Title
                gui.monitor.setTextColor(contentColors[k])
                gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
                gui.monitor.write(v)
            else
                gui.monitor.setCursorPos(3,3+k)
                gui.monitor.setTextColor(contentColors[k])
                gui.monitor.write(v)
            end
        end
    end
end  --end page

function gui.pageN_format()
    return
end  --end page 

return gui