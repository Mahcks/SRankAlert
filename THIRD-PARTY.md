# Included JSON library

`Scripts/sra_dkjson.lua` is an unmodified copy of David Heiko Kolf's **dkjson 2.11**,
renamed to avoid colliding with another mod's JSON module. Its copyright notice
and full MIT license are included at the top of that file. It needs no additional
installation and makes no network requests.

- Project and documentation: <https://dkolf.de/dkjson-lua/>
- Pinned source: <https://dkolf.de/dkjson-lua/dkjson-2.11.lua>
- Published checksums: <https://dkolf.de/downloads>
- SHA-256: `197cb50834c642f84b4cf99fe724932c50e6d9c92faec7ad89aa25e91df4d481`

The installed UE4SS shared folder contains UEHelpers but no JSON module. Bundling
a known pure-Lua library avoids relying on another mod to install one. Other UE4SS
projects use this approach too (for example the JSON module in
[palworld-server-toolkit](https://github.com/fol2/palworld-server-toolkit)).

Config paths come from Lua's module source filename. UE4SS supplies the module's
path as its chunk name, as shown in its
[Lua loader](https://github.com/UE4SS-RE/RE-UE4SS/blob/main/UE4SS/src/Mod/LuaMod.cpp).
The mod does not assume that the working directory is Win64 or that Steam is on C:.
