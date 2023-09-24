export gpm

SERVER = SERVER
if SERVER
    AddCSLuaFile!

include = include
Color = Color
type = type

if type( gpm ) ~= "table"
    gpm = {
        VERSION: "2.0.0"
    }

gpm.StartTime = SysTime!

do

    splash = {
        "Flying over rooftops...",
        "We need more packages!",
        "Where's fireworks!?",
        "Now on MoonScript!",
        "I'm watching you.",
        "Faster than ever.",
        "v" .. gpm.VERSION,
        "Blazing fast ☄",
        "More splashes?!",
        "Here For You ♪",
        "Hello World!",
        "Once Again ♪",
        "Sandblast ♪",
        "That's me!",
        "I see you."
    }

    if CLIENT
        splash[ #splash + 1 ] = "I know you, " .. cvars.String( "name", "player" ) .. "..."
    splash[ #splash + 1 ] = "Wow, here more " .. #splash .. " splashes!"
    splash = splash[ math.random( 1, #splash ) ]
    for i = 1, ( 25 - #splash ) / 2
        if i % 2 == 1
            splash = splash .. " "
        splash = " " .. splash
    MsgN string.format "\n                                     ___          __            \n                                   /'___`\\      /'__`\\          \n     __    _____     ___ ___      /\\_\\ /\\ \\    /\\ \\/\\ \\         \n   /'_ `\\ /\\ '__`\\ /' __` __`\\    \\/_/// /__   \\ \\ \\ \\ \\        \n  /\\ \\L\\ \\\\ \\ \\L\\ \\/\\ \\/\\ \\/\\ \\      // /_\\ \\ __\\ \\ \\_\\ \\   \n  \\ \\____ \\\\ \\ ,__/\\ \\_\\ \\_\\ \\_\\    /\\______//\\_\\\\ \\____/   \n   \\/___L\\ \\\\ \\ \\/  \\/_/\\/_/\\/_/    \\/_____/ \\/_/ \\/___/    \n     /\\____/ \\ \\_\\                                          \n     \\_/__/   \\/_/                %s                        \n\n  GitHub: https://github.com/Pika-Software\n  Discord: https://discord.gg/Gzak99XGvv\n  Website: https://pika-soft.ru\n  Developers: Pika Software\n  License: MIT\n", splash

colors = gpm.Colors
if type( colors ) ~= "table"
    colors = {
        SecondaryText: Color 150, 150, 150,
        PrimaryText: Color 200, 200, 200,
        White: Color 255, 255, 255,
        Info: Color 70, 135, 255,
        Warn: Color 255, 130, 90,
        Error: Color 250, 55, 40,
        Debug: Color 0, 200, 150,
        gpm: Color 180, 180, 255
    }

    colors.State = colors.White
    gpm.Colors = colors

state = gpm.State
if type( state ) ~= "string"
    if MENU_DLL
        colors.State = Color 75, 175, 80
        state = "Menu"
    elseif CLIENT
        colors.State = Color 225, 170, 10
        state = "Client"
    elseif SERVER
        colors.State = Color 5, 170, 250
        state = "Server"

    gpm.State = state or "unknown"

unless gpm.Developer
    gpm.Developer = cvars.Number "developer", 0
    cvars.AddChangeCallback "developer",
        ( _, __, new ) -> gpm.Developer = tonumber( new ) or 0,
        "gLua Package Manager"

include "gpm/util.lua"
gpm.Logger\Info "metaworks v%s is initialized.", gpm.metaworks.VERSION
gpm.Logger\Info "gm_promise v%s is initialized.", (include "gpm/libs/promise.lua").VERSION
gpm.Logger\Info "gmad v%s is initialized.", (include "gpm/libs/gmad.lua").VERSION

include "gpm/filesystem.lua"
include "gpm/http.lua"
include "gpm/package.lua"

gpm.Logger\Info "Start-up time: %.4f sec.", SysTime() - gpm.StartTime
return gpm