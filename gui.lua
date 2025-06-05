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
gui.pageTitles = nil
gui.helpWindow = false
gui.toggleHelpWindow = false

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

function gui.readClients() --Only for Interface/Server; not remote
    local file = fs.open('./er_interface/keys/clients', 'r')
    local clients = textutils.unserialize(file.readAll())
    file.close()
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
            ['currentPageTitle'] = '',
            ['storedPower'] = 0, 
            ['deltaPower'] = 0, 
            ['snapshotTime'] = 0, 
            ['deltaTime'] = 0,
            ['mouseWheel'] = 0,
            ['helpWindowWidth'] = 0, 
            ['helpWindowHeight'] = 0,
            ['scrollAbleLines'] = 0,
        }
    end
    local file = fs.open('./er_interface/settings.cfg', 'w')
    file.write(textutils.serialize(gui.settings))
    file.close()   
end --end writeSettings

function gui.getPageTitle(pageNum)
    return gui.pageTitles[pageNum]
    -- if not gui.snapshot['reactor']['activelyCooled'] then
    --     if pageNum == 1 then
    --         return 'Home'
    --     elseif pageNum == 2 then
    --         return 'Fuel'
    --     elseif pageNum == 3 then
    --         return 'Power'
    --     elseif pageNum == 4 then
    --         return 'Graphs'
    --     elseif pageNum == 5 then
    --         return 'Rod Statistics'
    --     elseif pageNum == 6 then
    --         return 'Automations'
    --     elseif pageNum == 7 then
    --         return 'Connection'
    --     end
    -- else
    --     if pageNum == 1 then
    --         return 'Home'
    --     elseif pageNum == 2 then
    --         return 'Fuel'
    --     elseif pageNum == 3 then
    --         return 'Vapor'
    --     elseif pageNum == 4 then
    --         return 'Coolant'
    --     elseif pageNum == 5 then
    --         return 'Graphs'
    --     elseif pageNum == 6 then
    --         return 'Rod Statistics'
    --     elseif pageNum == 7 then
    --         return 'Automations'
    --     elseif pageNum == 8 then
    --         return 'Connection'
    --     end
    -- end
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

function gui.clickedButton(button, x, y, craftables) -- Deprecated
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
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.lightBlue)
    gui.monitor.setCursorPos(gui.width-1, 1)
    gui.monitor.write('?')
    gui.monitor.setBackgroundColor(gui.stdBgColor)
    for i=1, gui.width-2 do
        gui.monitor.setCursorPos(i,1)
        gui.monitor.write(' ')
    end
    gui.monitor.setCursorPos(1,1)
    gui.monitor.write(os.date("%F %T"))
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
    local pages = {[0] = nil,}
    local pageTitles = {[0] = nil,}
    if gui.snapshot['turbine']['status'] ~= nil then
        pages[#pages+1] = gui.turbine_pageSummary
        pageTitles[#pageTitles+1] = 'Turbine Summary'
    end
    if gui.snapshot['reactor']['status'] ~= nil then
        pages[#pages+1] = gui.reactor_summary
        pageTitles[#pageTitles+1] = 'Reactor Summary'
    end
    if gui.snapshot['turbine']['status'] ~= nil then
        pages[#pages+1] = gui.turbine_pagePower
        pages[#pages+1] = gui.turbine_pageVapor
        pages[#pages+1] = gui.turbine_pageCoolant
        pageTitles[#pageTitles+1] = 'Turbine Power Stats'
        pageTitles[#pageTitles+1] = 'Turbine Vapor Stats'
        pageTitles[#pageTitles+1] = 'Turbine Coolant Stats'
    end
    if gui.snapshot['reactor']['status'] ~= nil then
        if not gui.snapshot['reactor']['activelyCooled'] then
            pages[#pages+1] = gui.reactor_pageFuel
            pages[#pages+1] = gui.reactor_pagePower
            pageTitles[#pageTitles+1] = 'Reactor Fuel Stats'
            pageTitles[#pageTitles+1] = 'Reactor Power Stats'
        else
            pages[#pages+1] = gui.reactor_pageFuel
            pages[#pages+1] = gui.reactor_pageVapor
            pages[#pages+1] = gui.reactor_pageCoolant
            pages[#pages+1] = gui.pageGraphs
            pages[#pages+1] = gui.reactor_pageRods
            pageTitles[#pageTitles+1] = 'Reactor Fuel Stats'
            pageTitles[#pageTitles+1] = 'Reactor Vapor Stats'
            pageTitles[#pageTitles+1] = 'Reactor Coolant Stats'
            pageTitles[#pageTitles+1] = 'Graphs'
            pageTitles[#pageTitles+1] = 'Rod Statistics Info'
        end
    end
    pages[#pages+1] = gui.pageAutomations
    pages[#pages+1] = gui.pageConnections
    pageTitles[#pageTitles+1] = 'Automations'
    if fs.exists('./er_interface/interface.lua') then -- If this file exists then it is a server
        pageTitles[#pageTitles+1] = 'Manage Clients'
    else
        pageTitles[#pageTitles+1] = 'Connection Info'
    end
    gui.readSettings()
    if gui.settings['currentPage'] > #pages then
        gui.settings['currentPage'] = #pages
        gui.writeSettings()
    end
    -- gui.log(textutils.serialize(pages))
    -- gui.log(textutils.serialize(pageTitles))
    gui.pages = pages
    gui.pageTitles = pageTitles
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

function gui.help_page()
    gui.readSettings()
    local folderDir = './er_interface/docs/help/'
    gui.helpWindow.setVisible(false)
    -- if gui.helpWindow == false then
    --     local width, height = gui.monitor.getSize()
    --     gui.helpWindow = window.create(gui.monitor, width*0.1, height*0.1, width-width*0.2, height-height*0.2, false)
    --     gui.settings['helpWindowWidth'], gui.settings['helpWindowHeight'] = width-width*0.2, height-height*0.2
    --     gui.writeSettings()
    -- else
        -- gui.helpWindow.setVisible(false)
    -- end
    gui.helpWindow.setBackgroundColor(colors.lightBlue)
    gui.helpWindow.setTextColor(colors.white)
    for i=1, gui.settings['helpWindowWidth'] do
        gui.helpWindow.setCursorPos(i, 1)
        gui.helpWindow.write(' ')
    end
    gui.helpWindow.setCursorPos(1, 1)
    gui.helpWindow.write(gui.getPageTitle(gui.settings['currentPage'])..' - Help')
    gui.helpWindow.setCursorPos(gui.settings['helpWindowWidth'], 1)
    gui.helpWindow.setBackgroundColor(colors.red)
    gui.helpWindow.write('X')
    local helpText = ''
    if not fs.exists(folderDir..gui.getPageTitle(gui.settings['currentPage'])..'.txt') then
        local file = fs.open(folderDir..'default.txt', 'r')
        helpText = ccStrings.wrap(file.readAll(), gui.settings['helpWindowWidth'])
        file.close()
    else
        local file = fs.open(folderDir..gui.getPageTitle(gui.settings['currentPage'])..'.txt', 'r')
        helpText = ccStrings.wrap(file.readAll(), gui.settings['helpWindowWidth'])
        file.close()
    end
    -- gui.log(textutils.serialize(helpText))
    gui.helpWindow.setBackgroundColor(colors.blue)
    gui.helpWindow.setTextColor(colors.white)
    for i=2, gui.settings['helpWindowHeight'] do
        gui.helpWindow.setCursorPos(1, i)
        for k=1, gui.settings['helpWindowWidth'] do
            gui.helpWindow.write(' ')
        end
    end
    for i=1, gui.settings['helpWindowHeight'] do
        if #helpText > gui.settings['helpWindowHeight']-1 then
            if math.floor(i+(#helpText-(gui.settings['helpWindowHeight']-1))*gui.settings['mouseWheel']) > #helpText then
                break
            -- elseif i > #helpText then
            --     break
            else
                -- gui.log(math.floor(i+(#helpText*gui.settings['mouseWheel'])))
                gui.helpWindow.setCursorPos(1, i+1)
                gui.helpWindow.write(helpText[math.floor(i+(#helpText-(gui.settings['helpWindowHeight']-1))*gui.settings['mouseWheel'])])
                -- local x, y = gui.helpWindow.getCursorPos()z
            end
        else
            if i > #helpText then
                break
            else
                gui.helpWindow.setCursorPos(1, i+1)
                gui.helpWindow.write(helpText[i])
            end
        end
    end
    gui.helpWindow.setVisible(true)
end

function gui.main()
    gui.monitor.setVisible(false)
    gui.readSettings()
    gui.settings['currentPageTitle'] = gui.getPageTitle(gui.settings['currentPage'])
    gui.writeSettings()
    gui.clearScreen()
    -- gui.log('Drawing page: '..gui.settings['currentPage'])
    -- gui.log('Page drawn was: '..tostring(gui.pages[gui.settings['currentPage']]))
    if gui.toggleHelpWindow then -- Don't generate more than once... For now...
        gui.help_page()
    else
        gui.pages[gui.settings['currentPage']]()
    end
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

function gui.turbine_pageSummary()
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = 'Snapshot Timestamp: ',
        [4] = gui.snapshot['report']['datestamp'],
        [5] = 'status',
        [6] = 'status2',
        [7] = '',
        [8] = ccStrings.ensure_width('Power (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['energyInfo']['stored']),
        [9] = ccStrings.ensure_width('Vapor (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['ioInfo']['inputAmount']),
        [10] = ccStrings.ensure_width('Flow (mB/t):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['fluidInfo']['flowRate']),
        [11] = ccStrings.ensure_width('Coolant (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['ioInfo']['outputAmount']),
        [12] = ccStrings.ensure_width('Speed (RPM):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['rotorInfo']['rotorSpeed']),
        [13] = ccStrings.ensure_width('Efficiency (%):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['rotorInfo']['bladeEfficiency']),
        [14] = '',
        ['status'] = gui.snapshot['turbine']['status'],
        ['status2'] = gui.snapshot['turbine']['inductorStatus'],
        ['statusText'] = 'Turbine Status: ',
        ['status2Text'] = 'Inductor Status: ',
    }
    local contentColors = {
        [0] = colors.black,
        [1] = colors.yellow,
        [2] = colors.black,
        [3] = colors.yellow,
        [4] = colors.white,
        [5] = colors.yellow,
        [6] = colors.yellow,
        [7] = colors.black,
        [8] = gui.colors['power'],
        [9] = gui.colors['vapor'],
        [10] = gui.colors['vapor'],
        [11] = gui.colors['coolant'],
        [12] = colors.green,
        [13] = colors.green,
        [14] = colors.black,
    }
    gui.draw_title_content(content, contentColors)
end --end gui.turbine_pageSummary

function gui.reactor_summary()
    local content, contentColors  = nil, nil
    if not gui.snapshot['reactor']['activelyCooled'] then -- Power Configuration
        content = {
            [0] = '',
            [1] = gui.getPageTitle(gui.settings['currentPage']),
            [2] = '',
            [3] = 'Snapshot Timestamp: ',
            [4] = gui.snapshot['report']['datestamp'],
            [7] = 'status',
            [8] = '',
            [9] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['casingTemperature']),
            [10] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['amount']),
            [11] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['wasteAmount']),
            [12] = ccStrings.ensure_width('Power (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['energyInfo']['stored']),
            [13] = '',
            ['status'] = gui.snapshot['reactor']['status'],
            ['statusText'] = 'Reactor Status: ',
        }
        contentColors = {
            [0] = colors.black,
            [1] = colors.yellow,
            [2] = colors.black,
            [3] = colors.yellow,
            [4] = colors.white,
            [5] = colors.yellow,
            [6] = colors.black,
            [7] = gui.colors['temperature'], 
            [8] = gui.colors['fuel'],
            [9] = gui.colors['waste'],
            [10] = gui.colors['power'],    
            [11] = colors.black,
        }
    else -- Vapor Configuration
        content = {
            [0] = '',
            [1] = gui.getPageTitle(gui.settings['currentPage']),
            [2] = '',
            [3] = 'Snapshot Timestamp: ',
            [4] = gui.snapshot['report']['datestamp'],
            [5] = 'status',
            [6] = '',
            [7] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['casingTemperature']),
            [8] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['amount']),
            [9] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['wasteAmount']),
            [10] = ccStrings.ensure_width('Vapor (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['hotFluidInfo']['amount']),
            [11] = ccStrings.ensure_width('Coolant (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['coolantInfo']['amount']),
            [12] = '',
            ['status'] = gui.snapshot['reactor']['status'],
            ['statusText'] = 'Reactor Status: ',
        }
        contentColors = {
            [0] = colors.black,
            [1] = colors.yellow,
            [2] = colors.black,
            [3] = colors.yellow,
            [4] = colors.white,
            [5] = colors.yellow,
            [6] = colors.black,
            [7] = gui.colors['temperature'], 
            [8] = gui.colors['fuel'],
            [9] = gui.colors['waste'],
            [10] = gui.colors['vapor'],
            [11] = gui.colors['coolant'],    
            [12] = colors.black,
        }
    end
    gui.draw_title_content(content, contentColors)
end --end reactor_summary

function gui.pageSnapshot() --Snapshot Report -- Deprecated
    local content, contentColors = nil, nil
    if not gui.snapshot['reactor']['activelyCooled'] then
        content = {
            [0] = 'Snapshot Report: ',
            [1] = gui.snapshot['report']['datestamp'],
            [2] = ccStrings.ensure_width('Server Name', gui.width*gui.widthFactor)..'ID',
            [3] = ccStrings.ensure_width(string.sub(gui.snapshot['report']['origin']['label'], 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..gui.snapshot['report']['origin']['id'],
            [4] = '',
            [5] = '',
            [6] = 'reactorStatus',
            [7] = '',
            [8] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['casingTemperature']),
            [9] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['amount']),
            [10] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['wasteAmount']),
            [11] = ccStrings.ensure_width('Power (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['energyInfo']['stored']),
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
            [8] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['casingTemperature']),
            [9] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['amount']),
            [10] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['wasteAmount']),
            [11] = ccStrings.ensure_width('Vapor (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['hotFluidInfo']['amount']),
            [12] = ccStrings.ensure_width('Coolant (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['coolantInfo']['amount']),
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
            if gui.snapshot['reactor']['status'] == true then
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

function gui.reactor_pagePower() -- Power
    local powerBar = ''
    for i=1, (gui.snapshot['reactor']['energyInfo']['stored']/gui.snapshot['reactor']['energyInfo']['capacity'])*(gui.width-4) do
        powerBar = powerBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Power:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['reactor']['energyInfo']['stored']/gui.snapshot['reactor']['energyInfo']['capacity'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['energyInfo']['stored']),
        [7] = ccStrings.ensure_width('Capacity (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['energyInfo']['capacity']),
        [8] = ccStrings.ensure_width('FE/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['energyInfo']['lastTick']),
        -- [9] = ccStrings.ensure_width('Delta Power:', gui.width*gui.widthFactor-1)..gui.formatNum((gui.snapshot['energyInfo']['stored']-gui.oldSnapshot['energyInfo']['stored'])),
        [9] = '',
        ['bar'] = powerBar,
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
    gui.draw_title_content(content, contentColors)
    -- for k, v in pairs(content) do
    --     gui.monitor.setCursorPos(2,3+k)
    --     gui.monitor.setBackgroundColor(colors.black)
    --     for i=0, gui.width-3 do
    --         gui.monitor.write(' ')
    --     end
    --     if k == 1 then --Title
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.write(v)
    --     elseif v == 'powerBar' then
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setBackgroundColor(contentColors[k])
    --         gui.monitor.write(powerBar)
    --         gui.monitor.setBackgroundColor(gui.stdBgColor)
    --     else
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(v)
    --     end
    -- end
end --end page

function gui.reactor_pageFuel() -- Fuel Page
    local fuelBar = ''
    for i=1, (gui.snapshot['reactor']['fuelInfo']['amount']/gui.snapshot['reactor']['fuelInfo']['max'])*(gui.width-4) do
        fuelBar = fuelBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Fuel:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['reactor']['fuelInfo']['amount']/gui.snapshot['reactor']['fuelInfo']['max'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['max']),
        [8] = ccStrings.ensure_width('mB/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['lastTick']),
        -- [9] = ccStrings.ensure_width('Reactivity:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['reactivity']),
        [9] = ccStrings.ensure_width('Temperature (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['fuelInfo']['temperature']),
        [10] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['wasteAmount']),
        [11] = '',
        ['bar'] = fuelBar,
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
        -- [9] = gui.colors['fuel'],
        [9] = gui.colors['fuel'],
        [10] = gui.colors['fuel'],
        [11] = gui.stdBgColor,
    }
    gui.draw_title_content(content, contentColors)
    -- for k, v in pairs(content) do
    --     gui.monitor.setCursorPos(2,3+k)
    --     gui.monitor.setBackgroundColor(colors.black)
    --     for i=0, gui.width-3 do
    --         gui.monitor.write(' ')
    --     end
    --     if k == 1 then --Title
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.write(v)
    --     elseif v == 'fuelBar' then
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setBackgroundColor(contentColors[k])
    --         gui.monitor.write(fuelBar)
    --         gui.monitor.setBackgroundColor(gui.stdBgColor)
    --     else
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(v)
    --     end
    -- end
end --end page

function gui.reactor_pageCoolant() -- Coolant
    local coolantBar = ''
    for i=1, (gui.snapshot['reactor']['coolantInfo']['amount']/gui.snapshot['reactor']['coolantInfo']['max'])*(gui.width-4) do
        coolantBar = coolantBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Coolant:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['reactor']['coolantInfo']['amount']/gui.snapshot['reactor']['coolantInfo']['max'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['coolantInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['coolantInfo']['max']),
        -- [8] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..tostring(gui.snapshot['reactor']['coolantInfo']['type']),
        [8] = '',
        ['bar'] = coolantBar,
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
        -- [8] = gui.colors['coolant'],
        [8] = gui.stdBgColor,
    }
    gui.draw_title_content(content, contentColors)
    -- for k, v in pairs(content) do
    --     gui.monitor.setCursorPos(2,3+k)
    --     gui.monitor.setBackgroundColor(colors.black)
    --     for i=0, gui.width-3 do
    --         gui.monitor.write(' ')
    --     end
    --     if k == 1 then --Title
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.write(v)
    --     elseif v == 'coolantBar' then
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setBackgroundColor(contentColors[k])
    --         gui.monitor.write(coolantBar)
    --         gui.monitor.setBackgroundColor(gui.stdBgColor)
    --     else
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(v)
    --     end
    -- end
end --end page

function gui.reactor_pageVapor() -- Hot Fluid
    local vaporBar = ''
    for i=1, (gui.snapshot['reactor']['hotFluidInfo']['amount']/gui.snapshot['reactor']['hotFluidInfo']['max'])*(gui.width-4) do
        vaporBar = vaporBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Vapor:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['reactor']['hotFluidInfo']['amount']/gui.snapshot['reactor']['hotFluidInfo']['max'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['hotFluidInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['hotFluidInfo']['max']),
        [8] = ccStrings.ensure_width('mB/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['reactor']['hotFluidInfo']['lastTick']),
        -- [9] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..tostring(gui.snapshot['reactor']['hotFluidInfo']['type']),
        [9] = '',
        ['bar'] = vaporBar,
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
        -- [9] = gui.colors['vapor'],
        [9] = gui.stdBgColor,
    }
    gui.draw_title_content(content, contentColors)
    -- for k, v in pairs(content) do
    --     gui.monitor.setCursorPos(2,3+k)
    --     gui.monitor.setBackgroundColor(colors.black)
    --     for i=0, gui.width-3 do
    --         gui.monitor.write(' ')
    --     end
    --     if k == 1 then --Title
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.write(v)
    --     elseif v == 'vaporbar' then
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setBackgroundColor(contentColors[k])
    --         gui.monitor.write(vaporbar)
    --         gui.monitor.setBackgroundColor(gui.stdBgColor)
    --     else
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(v)
    --     end
    -- end
end --end page

function gui.turbine_pagePower()
    local powerBar = ''
    for i=1, (gui.snapshot['turbine']['energyInfo']['stored']/gui.snapshot['turbine']['energyInfo']['capacity'])*(gui.width-4) do
        powerBar = powerBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Power:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['turbine']['energyInfo']['stored']/gui.snapshot['turbine']['energyInfo']['capacity'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['energyInfo']['stored']),
        [7] = ccStrings.ensure_width('Capacity (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['energyInfo']['capacity']),
        [8] = ccStrings.ensure_width('FE/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['energyInfo']['lastTick']),
        [9] = ccStrings.ensure_width('Speed (RPM):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['rotorInfo']['rotorSpeed']),
        [10] = ccStrings.ensure_width('Efficiency (%):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['rotorInfo']['bladeEfficiency']),
        [11] = '',
        ['bar'] = powerBar,
    }
    local contentColors = {
        [0] = colors.black,
        [1] = gui.colors['power'],
        [2] = colors.black,
        [3] = gui.colors['power'],
        [4] = gui.colors['power'],
        [5] = colors.black,
        [6] = gui.colors['power'],
        [7] = gui.colors['power'],
        [8] = gui.colors['power'],
        [9] = gui.colors['power'],
        [10] = gui.colors['power'],
        [11] = colors.black,
    }
    gui.draw_title_content(content, contentColors)
end --end turbine_pagePower

function gui.turbine_pageVapor()
    local vaporBar = ''
    for i=1, (gui.snapshot['turbine']['ioInfo']['inputAmount']/gui.snapshot['turbine']['fluidInfo']['max'])*(gui.width-4) do
        vaporBar = vaporBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Vapor:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['turbine']['ioInfo']['inputAmount']/gui.snapshot['turbine']['fluidInfo']['max'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['ioInfo']['inputAmount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['fluidInfo']['max']),
        [8] = ccStrings.ensure_width('Flow (mB/t):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['fluidInfo']['flowRate']),
        [9] = ccStrings.ensure_width('Max Flow (mB/t):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['fluidInfo']['flowRateMax']),
        [10] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..gui.snapshot['turbine']['ioInfo']['inputType'],
        [11] = '',
        ['bar'] = vaporBar,
    }
    local contentColors = {
        [0] = colors.black,
        [1] = gui.colors['vapor'],
        [2] = colors.black,
        [3] = gui.colors['vapor'],
        [4] = gui.colors['vapor'],
        [5] = colors.black,
        [6] = gui.colors['vapor'],
        [7] = gui.colors['vapor'],
        [8] = gui.colors['vapor'],
        [9] = gui.colors['vapor'],
        [10] = gui.colors['vapor'],
        [11] = colors.black,
    }
    gui.draw_title_content(content, contentColors)
end --end turbine_pageVapor

function gui.turbine_pageCoolant()
    local coolantBar = ''
    for i=1, (gui.snapshot['turbine']['ioInfo']['outputAmount']/gui.snapshot['turbine']['fluidInfo']['max'])*(gui.width-4) do
        coolantBar = coolantBar..' '
    end
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('Power:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['turbine']['ioInfo']['outputAmount']/gui.snapshot['turbine']['fluidInfo']['max'])*1000)/10)..'%',
        [4] = 'bar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['ioInfo']['outputAmount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['fluidInfo']['max']),
        [8] = ccStrings.ensure_width('mB/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['turbine']['fluidInfo']['flowRate']),
        [9] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..gui.snapshot['turbine']['ioInfo']['outputType'],
        [10] = '',
        ['bar'] = coolantBar,
    }
    local contentColors = {
        [0] = colors.black,
        [1] = gui.colors['coolant'],
        [2] = colors.black,
        [3] = gui.colors['coolant'],
        [4] = gui.colors['coolant'],
        [5] = colors.black,
        [6] = gui.colors['coolant'],
        [7] = gui.colors['coolant'],
        [8] = gui.colors['coolant'],
        [9] = gui.colors['coolant'],
        [10] = colors.black,
    }
    gui.draw_title_content(content, contentColors)
end --end turbine_pageCoolant

function gui.pageGraphs() -- Graphs
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.yellow,
        [2] = gui.stdBgColor,
    }
    local graphContent, graphNames, graphColors = nil, nil, nil
    if not gui.snapshot['reactor']['activelyCooled'] then
        graphContent = {
            [0] = math.floor((gui.snapshot['reactor']['casingTemperature']+gui.snapshot['reactor']['fuelInfo']['temperature'])/2/(gui.snapshot['automations']['tempMax']+gui.snapshot['automations']['tempMax']*0.1)), --Temperature
            [1] = math.floor((gui.snapshot['reactor']['fuelInfo']['amount']/gui.snapshot['reactor']['fuelInfo']['max'])*1000)/10, --Fuel
            [2] = math.floor((gui.snapshot['reactor']['wasteAmount']/gui.snapshot['reactor']['fuelInfo']['max'])*1000)/10, --Waste
            [3] = math.floor((gui.snapshot['reactor']['energyInfo']['stored']/gui.snapshot['reactor']['energyInfo']['capacity'])*1000)/10, --Power
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
            [0] = math.floor(((gui.snapshot['reactor']['casingTemperature']+gui.snapshot['reactor']['fuelInfo']['temperature'])/2)/(gui.snapshot['automations']['tempMax']+gui.snapshot['automations']['tempMax']*0.1)), --Temperature
            [1] = math.floor((gui.snapshot['reactor']['fuelInfo']['amount']/gui.snapshot['reactor']['fuelInfo']['max'])*1000)/10, --Fuel
            [2] = math.floor((gui.snapshot['reactor']['wasteAmount']/gui.snapshot['reactor']['fuelInfo']['max'])*1000)/10, --Waste
            [3] = math.floor((gui.snapshot['reactor']['hotFluidInfo']['amount']/gui.snapshot['reactor']['hotFluidInfo']['max'])*1000)/10, --Vapor
            [4] = math.floor((gui.snapshot['reactor']['coolantInfo']['amount']/gui.snapshot['reactor']['coolantInfo']['max'])*1000)/10, --Coolant
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

function gui.reactor_pageRods() -- Rods Page
    -- local buttons = {
    --     [0] = '-1', 
    --     [1] = '-5',
    --     [2] = '-10',
    --     [3] = '+10',
    --     [4] = '+5',
    --     [5] = '+1',
    -- }
    local content = {
        [0] = '',
        [1] = gui.getPageTitle(gui.settings['currentPage']),
        [2] = '',
        [3] = ccStrings.ensure_width('# Name', gui.width*gui.widthFactor-1)..'Level',
        -- [4] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.yellow,
        [2] = gui.stdBgColor,
        [3] = colors.yellow,
        -- [4] = gui.stdBgColor,
    }
    for k, v in pairs(gui.snapshot['reactor']['rodInfo']['rods']) do
        -- if (k+1)*2 >= (gui.height-4) then
        --     break
        -- end
        table.insert(content, ccStrings.ensure_width(tostring(k)..' '..v['name'], gui.width*gui.widthFactor-1)..v['level'])
        table.insert(content, '      buttons      ')
        table.insert(contentColors, colors.white)
        table.insert(contentColors, colors.white)
        -- content[#content] = ccStrings.ensure_width(tostring(k)..' '..v['name'], gui.width*gui.widthFactor-1)..v['level']
        -- content[#content+1] = '      buttons      '
        -- contentColors[#contentColors] = colors.white
        -- contentColors[#contentColors+1] = colors.white
    end
    table.insert(content, '')
    table.insert(contentColors, gui.stdBgColor)
    -- content[#content+1] = ''
    -- contentColors[#contentColors+1] = gui.stdBgColor
    gui.draw_title_content(content, contentColors)
    -- for k, v in pairs(content) do
    --     gui.monitor.setCursorPos(2,3+k)
    --     gui.monitor.setBackgroundColor(colors.black)
    --     for i=0, gui.width-3 do
    --         gui.monitor.write(' ')
    --     end
    --     if k == 1 then --Title
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.write(v)
    --     elseif v == '      buttons      ' then
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         for k, v in pairs(buttons) do
    --             gui.monitor.setBackgroundColor(colors.lightGray)
    --             gui.monitor.write(v)
    --             gui.monitor.setBackgroundColor(colors.black)
    --             gui.monitor.write(' ')
    --         end
    --     else
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(v)
    --     end
    -- end
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
    if not gui.snapshot['reactor']['activelyCooled'] then
        content = {
            [0] = '',
            [1] = gui.getPageTitle(gui.settings['currentPage']),
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
            -- ['PowerVapor'] = gui.snapshot['automations']['powerToggle'],
            -- ['Temperature'] = gui.snapshot['automations']['tempToggle'],
            -- ['Control Rods'] = gui.snapshot['automations']['controlRodsToggle'],
        }
    else
        content = {
            [0] = '',
            [1] = gui.getPageTitle(gui.settings['currentPage']),
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
            -- ['PowerVapor'] = gui.snapshot['automations']['powerToggle'],
            -- ['Temperature'] = gui.snapshot['automations']['tempToggle'],
            -- ['Control Rods'] = gui.snapshot['automations']['controlRodsToggle'],
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
    gui.draw_title_content(content, contentColors)
    -- for k, v in pairs(content) do
    --     gui.monitor.setCursorPos(2,3+k)
    --     gui.monitor.setBackgroundColor(colors.black)
    --     for i=0, gui.width-3 do
    --         gui.monitor.write(' ')
    --     end
    --     if k == 1 then --Title
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.write(v)
    --     elseif v == '      buttons      ' then
    --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         for k, v in pairs(buttons) do
    --             gui.monitor.setBackgroundColor(colors.lightGray)
    --             gui.monitor.write(v)
    --             gui.monitor.setBackgroundColor(colors.black)
    --             gui.monitor.write(' ')
    --         end
    --     elseif v == 'Power' or v == 'Vapor' then
    --         gui.monitor.setBackgroundColor(colors.black)
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(ccStrings.ensure_width(v, gui.width*gui.widthFactor-1))
    --         gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
    --         if gui.snapshot['automations']['powerToggle'] == true then
    --             gui.monitor.setBackgroundColor(colors.green)
    --             gui.monitor.setTextColor(colors.white)
    --             gui.monitor.write(' ON  ')
    --             gui.monitor.setBackgroundColor(gui.stdBgColor)
    --         else
    --             gui.monitor.setBackgroundColor(colors.red)
    --             gui.monitor.setTextColor(colors.white)
    --             gui.monitor.write(' OFF ')
    --             gui.monitor.setBackgroundColor(gui.stdBgColor)
    --         end
    --     elseif v == 'Temperature' then
    --         gui.monitor.setBackgroundColor(colors.black)
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(ccStrings.ensure_width(v, gui.width*gui.widthFactor-1))
    --         gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
    --         if gui.snapshot['automations']['tempToggle'] == true then
    --             gui.monitor.setBackgroundColor(colors.green)
    --             gui.monitor.setTextColor(colors.white)
    --             gui.monitor.write(' ON  ')
    --             gui.monitor.setBackgroundColor(gui.stdBgColor)
    --         else
    --             gui.monitor.setBackgroundColor(colors.red)
    --             gui.monitor.setTextColor(colors.white)
    --             gui.monitor.write(' OFF ')
    --             gui.monitor.setBackgroundColor(gui.stdBgColor)
    --         end
    --     elseif v == 'Control Rods' then
    --         gui.monitor.setBackgroundColor(colors.black)
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(ccStrings.ensure_width(v, gui.width*gui.widthFactor-1))
    --         gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+k)
    --         if gui.snapshot['automations']['controlRodsToggle'] == true then
    --             gui.monitor.setBackgroundColor(colors.green)
    --             gui.monitor.setTextColor(colors.white)
    --             gui.monitor.write(' ON  ')
    --             gui.monitor.setBackgroundColor(gui.stdBgColor)
    --         else
    --             gui.monitor.setBackgroundColor(colors.red)
    --             gui.monitor.setTextColor(colors.white)
    --             gui.monitor.write(' OFF ')
    --             gui.monitor.setBackgroundColor(gui.stdBgColor)
    --         end
    --     else
    --         gui.monitor.setCursorPos(3,3+k)
    --         gui.monitor.setTextColor(contentColors[k])
    --         gui.monitor.write(v)
    --     end
    -- end
end --end page

function gui.pageConnections() -- Manage Clients // Connection to Server
    if fs.exists('./er_interface/interface.lua') then -- Manage Clients on Server
        local content = {
            [0] = '',
            [1] = gui.getPageTitle(gui.settings['currentPage']),
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
            -- table.insert(content, ccStrings.ensure_width(ccStrings.ensure_width(tostring(i['id']), 4)..' '..ccStrings.ensure_width(i['label'], gui.width*gui.widthFactor-1-5)..' '..gui.formatNum((os.epoch('local')-i['lastActivity'])/1000)..'s', gui.width-4))
            -- table.insert(contentColors, colors.white)
            local timeoutPeriod = 60*5
            if (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.2 then -- 1/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.green
                -- table.insert(contentBackgroundColors, colors.green)
            elseif (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.4 then -- 2/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.lime
                -- table.insert(contentBackgroundColors, colors.lime)
            elseif (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.6 then -- 3/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.yellow
                -- table.insert(contentBackgroundColors, colors.yellow)
            elseif (os.epoch('local')-i['lastActivity'])/1000 < timeoutPeriod*.8 then -- 4/5 of the Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.orange
                -- table.insert(contentBackgroundColors, colors.orange)
            else -- The full Timeout Period
                contentBackgroundColors[#contentBackgroundColors+1] = colors.red
                -- table.insert(contentBackgroundColors, colors.red)
            end
        end
        content[#content+1] = ''
        contentColors[#contentColors+1] = gui.stdBgColor
        contentBackgroundColors[#contentBackgroundColors+1] = colors.black
        -- table.insert(content, '')
        -- table.insert(contentColors, gui.stdBgColor)
        -- table.insert(contentBackgroundColors, colors.black)
        -- for k, v in pairs(content) do
        --     gui.monitor.setCursorPos(2,3+k)
        --     gui.monitor.setBackgroundColor(colors.black)
        --     for i=0, gui.width-3 do
        --         gui.monitor.write(' ')
        --     end
        --     gui.monitor.setBackgroundColor(contentBackgroundColors[k])
        --     if k == 1 then --Title
        --         gui.monitor.setTextColor(contentColors[k])
        --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
        --         gui.monitor.write(v)
        --     else
        --         gui.monitor.setCursorPos(3,3+k)
        --         gui.monitor.setTextColor(contentColors[k])
        --         gui.monitor.write(v)
        --     end
        -- end
        content['backgrounds'] = contentBackgroundColors
        gui.draw_title_content(content, contentColors)
    else
        local content = {
            [0] = '',
            [1] = gui.getPageTitle(gui.settings['currentPage']),
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
            [12] = 'Snapshot Timestamp: ',
            [13] = gui.snapshot['report']['datestamp'],
            [14] = '',
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
            [12] = colors.yellow,
            [13] = colors.white,
            [14] = gui.stdBgColor,
        }
        -- for k, v in pairs(content) do
        --     gui.monitor.setCursorPos(2,3+k)
        --     gui.monitor.setBackgroundColor(colors.black)
        --     for i=0, gui.width-3 do
        --         gui.monitor.write(' ')
        --     end
        --     if k == 1 then --Title
        --         gui.monitor.setTextColor(contentColors[k])
        --         gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
        --         gui.monitor.write(v)
        --     else
        --         gui.monitor.setCursorPos(3,3+k)
        --         gui.monitor.setTextColor(contentColors[k])
        --         gui.monitor.write(v)
        --     end
        -- end
        gui.draw_title_content(content, contentColors)
    end
end  --end page

-- function interface.turbineSnapshot()
--     local info = {
--         ['status'] = interface.turbine.getActive(),
--         ['variation'] = interface.turbine.getVariant(),
--         ['inductorStatus'] = interface.turbine.getInductorEngaged(),
--         ['energyInfo'] = interface.turbineGetEnergyInfo(),
--         ['fluidInfo'] = interface.turbineGetFluidInfo(),
--         ['rotorInfo'] = interface.turbineRotorInfo(),
--         ['ioInfo'] = interface.turbineIOInfo(),
--     }
--     return info
-- end

function gui.draw_title_content(content, contentColors)
    --gui.readSettings() -- +gui.settings['mouseWheel']*100
    if #content < gui.height-5 then
        gui.readSettings()
        gui.settings['scrollAbleLines'] = 0
        gui.writeSettings()
        for i=0, gui.height-5 do
        -- for k, v in pairs(content) do
            gui.monitor.setCursorPos(2,3+i)
            if content[1] == 'Manage Clients' and i < #content['backgrounds'] then
                gui.monitor.setBackgroundColor(content['backgrounds'][i])
            else
                gui.monitor.setBackgroundColor(colors.black)
            end
            for k=0, gui.width-3 do
                gui.monitor.write(' ')
            end
            if i > #content then
            elseif i == 1 then --Title
                gui.monitor.setCursorPos(math.ceil((gui.width-(#content[i]-2))/2), 3+i)
                gui.monitor.setTextColor(contentColors[i])
                gui.monitor.write(content[i])
            elseif content[i] == 'bar' then
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setBackgroundColor(contentColors[i])
                gui.monitor.write(content['bar'])
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            elseif content[i] == 'status' or content[i] == 'status2' then
                gui.monitor.setBackgroundColor(colors.black)
                -- gui.monitor.setCursorPos(2,3+k)
                gui.monitor.setTextColor(contentColors[i])
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.write(ccStrings.ensure_width(content[content[i]..'Text'], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
                if content[content[i]] == true then
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
            elseif content[i] == '      buttons      ' then
                local buttons = {
                    [0] = '-1', 
                    [1] = '-5',
                    [2] = '-10',
                    [3] = '+10',
                    [4] = '+5',
                    [5] = '+1',
                }
                gui.monitor.setCursorPos(math.ceil((gui.width-(#content[i]-2))/2), 3+i)
                gui.monitor.setTextColor(contentColors[i])
                for k, v in pairs(buttons) do
                    gui.monitor.setBackgroundColor(colors.lightGray)
                    gui.monitor.write(v)
                    gui.monitor.setBackgroundColor(colors.black)
                    gui.monitor.write(' ')
                end
            elseif content[i] == 'Power' or content[i] == 'Vapor' then
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[i])
                gui.monitor.write(ccStrings.ensure_width(content[i], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
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
            elseif content[i] == 'Temperature' then
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[i])
                gui.monitor.write(ccStrings.ensure_width(content[i], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
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
            elseif content[i] == 'Control Rods' then
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[i])
                gui.monitor.write(ccStrings.ensure_width(content[i], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
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
                -- gui.log(textutils.serialize({['i'] = i, ['contentColorsI'] = contentColors[i], ['contentI'] = content[i]}))
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[i])
                gui.monitor.write(content[i])
            end
        end
    else -- mouse_scroll
        gui.readSettings()
        gui.settings['scrollAbleLines'] = #content-(gui.height-5)
        gui.writeSettings()
        for i=0, gui.height-5 do
            -- math.floor(i+(#helpText-(gui.settings['helpWindowHeight']-1))*gui.settings['mouseWheel'])
        -- for k, v in pairs(content) do
            gui.monitor.setCursorPos(2,3+i)
            if content[1] == 'Manage Clients' and math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel']) < #content['backgrounds'] then
                gui.monitor.setBackgroundColor(content['backgrounds'][math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
            else
                gui.monitor.setBackgroundColor(colors.black)
            end
            for k=0, gui.width-3 do
                gui.monitor.write(' ')
            end
            if math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel']) > #content then
            elseif math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel']) == 1 then --Title
                gui.monitor.setCursorPos(math.ceil((gui.width-(#content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])]-2))/2), 3+i)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.write(content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
            elseif content[math.floor(math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'bar' then
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setBackgroundColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.write(content['bar'])
                gui.monitor.setBackgroundColor(gui.stdBgColor)
            elseif content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'status' or content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'status2' then
                gui.monitor.setBackgroundColor(colors.black)
                -- gui.monitor.setCursorPos(2,3+k)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.write(ccStrings.ensure_width(content[content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])]..'Text'], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
                if content[content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])]] == true then
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
            elseif content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == '      buttons      ' then
                local buttons = {
                    [0] = '-1', 
                    [1] = '-5',
                    [2] = '-10',
                    [3] = '+10',
                    [4] = '+5',
                    [5] = '+1',
                }
                gui.monitor.setCursorPos(math.ceil((gui.width-(#content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])]-2))/2), 3+i)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                for k, v in pairs(buttons) do
                    gui.monitor.setBackgroundColor(colors.lightGray)
                    gui.monitor.write(v)
                    gui.monitor.setBackgroundColor(colors.black)
                    gui.monitor.write(' ')
                end
            elseif content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'Power' or content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'Vapor' then
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.write(ccStrings.ensure_width(content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
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
            elseif content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'Temperature' then
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.write(ccStrings.ensure_width(content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
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
            elseif content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])] == 'Control Rods' then
                gui.monitor.setBackgroundColor(colors.black)
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.write(ccStrings.ensure_width(content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])], gui.width*gui.widthFactor-1))
                gui.monitor.setCursorPos(2+gui.width*gui.widthFactor,3+i)
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
                -- gui.log(textutils.serialize({['i'] = i, ['contentColorsI'] = contentColors[i], ['contentI'] = content[i]}))
                gui.monitor.setCursorPos(3,3+i)
                gui.monitor.setTextColor(contentColors[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
                gui.monitor.write(content[math.floor(i+(#content-(gui.height-5))*gui.settings['mouseWheel'])])
            end
        end
    end
end --end draw_title_content

-- function gui.turbine_pageSummary()
--     return
--     local title = 'Turbine'
--     local content = {
--         [0] = 'turbiineStatus',
--         [1] = 'inductorStatus',
--         [2] = '',
--     }
-- end  --end page 

-- function gui.turbine_pagePower()
--     return
-- end  --end page 

-- function gui.turbine_pageVapor()
--     return
-- end  --end page 

-- function gui.turbine_pageCoolant()
--     return
-- end  --end page 

-- function gui.pageN_format()
--     return
-- end  --end page 

return gui