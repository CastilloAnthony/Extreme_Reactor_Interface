if fs.exists('./er_interface/remote.lua') then
    local remote = require('remote')
    remote.initialize()
elseif fs.exists('./er_interface/interface.lua') then
    local interface = require('interface')
    interface.initialize()
else
	print('Cannot find remote.lua or interface.lua.')
end
