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
        file = fs.open(storage..'er_interface/logs/'..os.date('%F'), 'a')
    else
        file = fs.open('./'..'er_interface/logs/'..os.date('%F'), 'a')
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

function gui.nextPage(forward) -- true/false forwards/backwards
    gui.readSettings()
    if forward ~= nil then
        if forward == true then
            if gui.settings['currentPage'] == gui.totalPages then
                gui.settings['currentPage'] = 1
            else
                gui.settings['currentPage'] = gui.settings['currentPage'] + 1
            end
        elseif forward == false then
            if gui.settings['currentPage'] == 1 then
                gui.settings['currentPage'] = gui.totalPages
            else
                gui.settings['currentPage'] = gui.settings['currentPage'] - 1
            end
        end
    end
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
        suffix = "μ"
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
    if gui.settings['currentPage'] == 1 then
        gui.page1()
    elseif gui.settings['currentPage'] == 2 then
        gui.page2()
    elseif gui.settings['currentPage'] == 3 then
        gui.page3()
    elseif gui.settings['currentPage'] == 4 then
        gui.page4()
    elseif gui.settings['currentPage'] == 5 then
        gui.page5()
    elseif gui.settings['currentPage'] == 6 then
        gui.page6()
    elseif gui.settings['currentPage'] == 7 then
        gui.page7()
    elseif gui.settings['currentPage'] == 8 then
        gui.page8()
    elseif gui.settings['currentPage'] == 9 then
        gui.page9()
    end
    gui.updateTime()
    gui.drawButtons()
    gui.monitor.setVisible(true)
end --end main

function gui.page1() --Snapshot Report
    local content = {
        [0] = 'Snapshot Report: ',
        [1] = gui.snapshot['report']['datestamp'],
        [2] = ccStrings.ensure_width('Server Name', gui.width*gui.widthFactor)..'ID',
        [3] = ccStrings.ensure_width(string.sub(gui.snapshot['report']['origin']['label'], 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..gui.snapshot['report']['origin']['id'],
        [4] = '',
        [5] = '',
        [6] = 'reactorStatus',
        [7] = '',
        [8] = ccStrings.ensure_width('Power (FE):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['energyInfo']['stored']),
        [9] = ccStrings.ensure_width('Fuel (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['fuelInfo']['amount']),
        [10] = ccStrings.ensure_width('Coolant (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['coolantInfo']['amount']),
        [11] = ccStrings.ensure_width('Hot Fluid (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['amount']),
        [12] = ccStrings.ensure_width('Case Temp. (C):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['casingTemperature']),
        [13] = ccStrings.ensure_width('Waste (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['wasteAmount']),
        [14] = '',
    }
    local contentColors = {
        [0] = colors.yellow,
        [1] = colors.white,
        [2] = colors.yellow,
        [3] = colors.white,
        [4] = gui.stdBgColor,
        [5] = gui.stdBgColor, -- Empty Space
        [6] = colors.yellow,
        [7] = gui.stdBgColor, -- Empty Space
        [8] = colors.magenta,
        [9] = colors.orange,
        [10] = colors.blue,
        [11] = colors.red,
        [12] = colors.lime,
        [13] = colors.brown,
        [14] = colors.lightGray,
    }
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
end --end page1

function gui.page2() -- Power
    local powerBar = ''
    for i=2, (gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*gui.width-4 do
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
        [1] = colors.magenta,
        [2] = gui.stdBgColor,
        [3] = colors.magenta,
        [4] = colors.red,
        [5] = gui.stdBgColor,
        [6] = colors.magenta,
        [7] = colors.magenta,
        [8] = colors.magenta,
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
end --end page2

function gui.page3() -- Fuel Page
    local fuelBar = ''
    for i=2, (gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*gui.width-4 do
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
        [1] = colors.orange,
        [2] = gui.stdBgColor,
        [3] = colors.orange,
        [4] = colors.lime,
        [5] = gui.stdBgColor,
        [6] = colors.orange,
        [7] = colors.orange,
        [8] = colors.orange,
        [9] = colors.orange,
        [10] = colors.orange,
        [11] = colors.orange,
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
end --end page3

function gui.page4() -- Coolant
    local coolantBar = ''
    for i=2, (gui.snapshot['coolantInfo']['amount']/gui.snapshot['coolantInfo']['max'])*gui.width-4 do
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
        [1] = colors.blue,
        [2] = gui.stdBgColor,
        [3] = colors.blue,
        [4] = colors.lightBlue,
        [5] = gui.stdBgColor,
        [6] = colors.blue,
        [7] = colors.blue,
        [8] = colors.blue,
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
end --end page4

function gui.page5() -- Hot Fluid
    local hotFluidbar = ''
    for i=2, (gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*gui.width-4 do
        hotFluidbar = hotFluidbar..' '
    end
    local content = {
        [0] = '',
        [1] = 'Hot Fluid Statistics',
        [2] = '',
        [3] = ccStrings.ensure_width('Hot Fluid:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*1000)/10)..'%',
        [4] = 'hotFluidbar',
        [5] = '',
        [6] = ccStrings.ensure_width('Stored (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['amount']),
        [7] = ccStrings.ensure_width('Capacity (mB):', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['max']),
        [8] = ccStrings.ensure_width('mB/t:', gui.width*gui.widthFactor-1)..gui.formatNum(gui.snapshot['hotFluidInfo']['lastTick']),
        [9] = ccStrings.ensure_width('Type:', gui.width*gui.widthFactor-1)..tostring(gui.snapshot['hotFluidInfo']['type']),
        [10] = '',
    }
    local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.red,
        [2] = gui.stdBgColor,
        [3] = colors.red,
        [4] = colors.orange,
        [5] = gui.stdBgColor,
        [6] = colors.red,
        [7] = colors.red,
        [8] = colors.red,
        [9] = colors.red,
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
        elseif v == 'hotFluidbar' then
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setBackgroundColor(contentColors[k])
            gui.monitor.write(hotFluidbar)
            gui.monitor.setBackgroundColor(gui.stdBgColor)
        else
            gui.monitor.setCursorPos(3,3+k)
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.write(v)
        end
    end
end --end page5

function gui.page6() -- Rods Page
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
end --end page6

function gui.page7() -- Automations
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
        elseif v == 'Power' then
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
end --end page7

function gui.page8() -- Graphs
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
    -- local graphs = {
        -- [0] = ccStrings.ensure_width('Power:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*1000)/10)..'%',
        -- [1] = ccStrings.ensure_width('Fuel:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*1000)/10)..'%',
        -- [2] = ccStrings.ensure_width('Coolant:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['coolantInfo']['amount']/gui.snapshot['coolantInfo']['max'])*1000)/10)..'%',
        -- [3] = ccStrings.ensure_width('Hot Fluid:', gui.width*gui.widthFactor-1)..tostring(math.floor((gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*1000)/10)..'%',
    -- }
    local graphContent = {
        [0] = math.floor((gui.snapshot['energyInfo']['stored']/gui.snapshot['energyInfo']['capacity'])*1000)/10, --Power
        [1] = math.floor((gui.snapshot['fuelInfo']['amount']/gui.snapshot['fuelInfo']['max'])*1000)/10, --Fuel
        [2] = math.floor((gui.snapshot['coolantInfo']['amount']/gui.snapshot['coolantInfo']['max'])*1000)/10, --Coolant
        [3] = math.floor((gui.snapshot['hotFluidInfo']['amount']/gui.snapshot['hotFluidInfo']['max'])*1000)/10, --HotFluid
        -- [4] = math.floor((gui.snapshot['wasteAmount']/gui.snapshot['fuelInfo']['max'])*1000)/10, --Waste
    }
    local graphNames = {
        [0] = 'Power',
        [1] = 'Fuel',
        [2] = 'Coolant',
        [3] = 'Hot Fluid',
        -- [4] = 'Waste',
    }
    local graphColors = {
        [0] = colors.red,
        [1] = colors.lime,
        [2] = colors.blue,
        [3] = colors.orange,
        -- [4] = colors.brown,
    }
    for i=1, gui.height-4 do
        gui.monitor.setCursorPos(2,2+i)
        gui.monitor.setBackgroundColor(colors.black)
        for i=0, gui.width-3 do
            gui.monitor.write(' ')
        end
    end
    for k, v in pairs(content) do
        if k == 1 then --Title
            gui.monitor.setTextColor(contentColors[k])
            gui.monitor.setCursorPos(math.ceil((gui.width-(#v-2))/2), 3+k)
            gui.monitor.write(v)
        end
    end

    for k, v in pairs(graphContent) do 
        -- Max Height: gui.height-#content-4
        -- Max Width: gui.width*gui.widthFactor-2
        local width = ((gui.width*gui.widthFactor-2)/4)-3
        local x = (((gui.width*gui.widthFactor)-2)/(4))*(k)+3
        gui.monitor.setTextColor(graphColors[k])
        for i=1, (gui.height-8) do
            gui.monitor.setCursorPos(x, gui.height-2-i)
            gui.monitor.setBackgroundColor(colors.gray)
            if gui.height-8-i <= #graphNames[k] and gui.height-8-i ~= 0 then
                gui.monitor.write(string.sub(graphNames[k], gui.height-8-i, gui.height-8-i))
                gui.monitor.write('  ')
            else
                gui.monitor.write('   ')
            end
        end
        for i=2, (gui.height-8)*(v/100) do
            gui.monitor.setCursorPos(x+1, gui.height-2-i)
            gui.monitor.setBackgroundColor(graphColors[k])
            gui.monitor.write(' ')
        end
    end
    local buttons = {
        [0] = 'SCRAM!',
    }
    gui.monitor.setTextColor(colors.white)
    for k, v in pairs(buttons) do
        gui.monitor.setCursorPos(gui.width*gui.widthFactor+1, 6+k)
        if v == 'SCRAM!' then
            if gui.snapshot['status'] then
                gui.monitor.setBackgroundColor(colors.green)
            else
                gui.monitor.setBackgroundColor(colors.red)
            end
            gui.monitor.write(v)
        end
    end
end --end page8

function gui.readClients()
    local file = fs.open('./er_interface/keys/clients', 'r')
    local clients = textutils.unserialize(file.readAll())
    file.close()
    return clients
end --end readClients

function gui.page9() -- Manage Clients // Connection to Server
    if fs.exists('./er_interface/interface.lua') then -- Manage Clients on Server
        local content = {
            [0] = '',
            [1] = 'Manage Clients',
            [2] = '',
            [3] = ccStrings.ensure_width('Name', gui.width*gui.widthFactor-1)..'ID',
        }
        local contentColors = {
        [0] = gui.stdBgColor,
        [1] = colors.yellow,
        [2] = gui.stdBgColor,
        [3] = colors.yellow,
        }
        for _, i in pairs(gui.readClients()) do
            content[#content+1] = ccStrings.ensure_width(i['label'], gui.width*gui.widthFactor-1)..i['id']
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
            else
                gui.monitor.setCursorPos(3,3+k)
                gui.monitor.setTextColor(contentColors[k])
                gui.monitor.write(v)
            end
        end
    else
        local content = {
            [0] = '',
            [1] = 'Connection to Server',
            [2] = '',
            [3] = ccStrings.ensure_width('Server Name', gui.width*gui.widthFactor)..'ID',
            [4] = ccStrings.ensure_width(string.sub(gui.snapshot['report']['origin']['label'], 0, gui.width*gui.widthFactor-1), gui.width*gui.widthFactor)..gui.snapshot['report']['origin']['id'],
            [5] = '',
            [6] = ccStrings.ensure_width('Latency', gui.width*gui.widthFactor),
            [7] = ccStrings.ensure_width(gui.formatNum((os.epoch('local')-gui.snapshot['report']['timestamp'])/1000)..'s', gui.width*gui.widthFactor),
            [8] = '',
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