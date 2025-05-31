# Extreme_Reactor_Interface
A user interface program for the Minecraft mod ComputerCraft used to interface the mod with the Extreme Reactors mod. Non-pocket computers can utilize monitors to increase the size of available screen space. For these non-pocket computers, a minimum of a 3-by-3 monitor setup or no screens at all is recommended. The graphs page utilizes this extra screen space very well by stretching the graphs vertically and horizontally. This program is intended to work with just a single reactor. This UI program is written entirely in Lua. Preview images can be viewed here: https://imgur.com/a/VlOrHOI

## Features
- Clickable buttons
- Updater script
- Monitor support
- Support for power production or vapor production configuration
- Multiple pages (7 or 8 depending on the reactor configuration)
- Password protection and cryptography
- Remote access to the server via pocket computers or satellite computers
- Support for multiple remote clients concurrently (suggested limit: TBD)
- Client management page where you can remove clients and force them to re-establish a connection

## Installation
To install onto a ComputerCraft device type this into the console: 
wget https://raw.githubusercontent.com/CastilloAnthony/Extreme_Reactor_Interface/refs/heads/main/installer installer
Then run the installer.
When the prompt shows up, type 'y' for server or 'n' for remote.
For first time users, you will have to wait a couple of minutes while cryptography parameters are generated.

### Todo
- Help button next to the close button
-- Should bring up a new window with a title bar, a close button, and text that varies depending on the page the interface is on.
- Turbine information pages
-- Turbine automations
- Scrolling features / Scroll bar
-- Specifically for Rod Stats, Automations, and Client Management