# Extreme_Reactor_Interface
A user interface program for the Minecraft mod ComputerCraft used to interface the mod with the Extreme Reactors mod. Non-pocket computers can utilize monitors to increase the size of available screen space. For these non-pocket computers, a minimum of a 3-by-3 monitor setup or no screens at all is recommended. The graphs page utilizes this extra screen space very well by stretching the graphs vertically and horizontally. This program is intended to work with just a single reactor. This UI program is written entirely in Lua. Preview images can be viewed here: https://imgur.com/a/Y7JEOX3

## Features
- Supports a single reactor and a single turbine simultaneously
    - Automated monitoring and management of various reactor & turbine settings
- Clickable buttons including buttons that:
    -Terminate the program
    -Open a help window
    -Switch to next/previous page
    -Toggle reactor/trubine/inductor status
    -Increment/decrement control rods
    -Toggle/increment/decrement automations
    -Remove client authorizations
- Updater script
    - run "er_interface/updater" to update the program
- Monitor support
- Support for power production or vapor production configurations
- Multiple dynamically selected information pages
- Password protection and cryptography
- Remote access to the server via pocket computers or satellite computers
- Support for multiple remote clients concurrently (suggested limit: TBD)
- Client management page where you can remove clients and force them to re-establish a connection
    - Clients must manually remove "er_interface/keys/server.key" in order to be eligible for re-authorization

## Installation
To install onto a ComputerCraft device type this into the console: 
1. wget https://raw.githubusercontent.com/CastilloAnthony/Extreme_Reactor_Interface/refs/heads/main/installer installer
2. Then run the installer.
3. When the prompt shows up, type 'y' for server or 'n' for remote.
4. The installer should now reboot the computer and load up the program at startup.

For first time users, you will have to wait a couple of minutes while cryptography parameters are generated.

### Todo
- Add non-default help text to all pages
    - Turbine Summary
    - Reactor Summary
    - Turbine Power Stats
    - Turbine Vapor Stats
    - Turbine Coolant Stats 
    - Reactor Fuel Stats
    - Reactor Vapor Stats
    - Reactor Coolant Stats
    - Graphs
    - Histograms
- Modify Graphs page
    -Add Turbine Graphs
- Histograms page
    - Add temperature and rotor speed
- Version checker
    - Checksums so that only changed files are downloaded
    - Optional auto-updater