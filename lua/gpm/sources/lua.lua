-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local paths = gpm.paths
local string = string
local fs = gpm.fs

-- Variables
local activeGamemode = engine.ActiveGamemode()
local isSinglePlayer = game.SinglePlayer()
local CLIENT, SERVER = CLIENT, SERVER
local AddCSLuaFile = AddCSLuaFile
local setmetatable = setmetatable
local CompileFile = CompileFile
local luaRealm = gpm.LuaRealm
local util_MD5 = util.MD5
local logger = gpm.Logger
local ipairs = ipairs
local rawset = rawset
local pcall = pcall
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    return fs.Exists( filePath, luaRealm ) and string.EndsWith( filePath, ".lua" ) or fs.IsDir( filePath, luaRealm )
end

Files = setmetatable( {}, {
    ["__index"] = function( self, filePath )
        if type( filePath ) == "string" and fs.Exists( filePath, luaRealm ) and not fs.IsDir( filePath, luaRealm ) then
            local ok, result = pcall( CompileFile, filePath )
            if ok then
                rawset( self, filePath, result )
                return result
            end
        end

        rawset( self, filePath, false )
        return false
    end
} )

Import = promise.Async( function( filePath, parentPackage, isAutorun )
    filePath = paths.Fix( filePath )

    local packagePath = filePath
    if not fs.IsDir( packagePath, luaRealm ) then
        packagePath = string.GetPathFromFilename( packagePath )
    end

    local packageFilePath = packagePath .. "/package.lua"
    local identifier = packageFilePath

    local packageFile, metadata = Files[ packageFilePath ], nil
    if packageFile then
        metadata = packages.GetMetadata( packageFile )
        if not metadata then
            return promise.Reject( string.format( "Package `%s` package.lua file is empty! (%s)", identifier, packagePath ) )
        end

        if not metadata.name then metadata.name = util_MD5( filePath ) end
        identifier = metadata.name .. "@" .. metadata.version

        if not metadata.singleplayer and isSinglePlayer then
            return promise.Reject( string.format( "Package `%s` cannot be executed in a single-player game. (%s)", identifier, packagePath ) )
        end

        local gamemodeType = type( metadata.gamemode )
        if gamemodeType == "string" and metadata.gamemode ~= activeGamemode then
            return promise.Reject( string.format( "Package `%s` is not compatible with this gamemode. (%s)", identifier, packagePath ) )
        end

        if gamemodeType == "table" and not table.HasIValue( metadata.gamemode, activeGamemode ) then
            return promise.Reject( string.format( "Package `%s` is not compatible with this gamemode. (%s)", identifier, packagePath ) )
        end

        if SERVER and metadata.client then
            AddCSLuaFile( packageFilePath )
        end
    else

        local data = {
            ["name"] = util_MD5( filePath ),
            ["autorun"] = true
        }

        if fs.Exists( filePath, luaRealm ) and not fs.IsDir( filePath, luaRealm ) then
            data.main = filePath
        end

        metadata = packages.GetMetadata( data )
        identifier = metadata.name .. "@" .. metadata.version

    end

    if CLIENT and not metadata.client then return end

    local mainFile = metadata.main
    if not mainFile then
        mainFile = packagePath .. "/init.lua"
    end

    local func = Files[ mainFile ]
    if not func then
        mainFile = packagePath .. "/" .. mainFile
        func = Files[ mainFile ]
    end

    -- Legacy packages support
    if not func then
        mainFile = packagePath .. "/main.lua"
        func = Files[ mainFile ]
    end

    if not func then
        return promise.Reject( string.format( "Package `%s` main file is missing! (%s)", identifier, packagePath ) )
    end

    if SERVER then
        if metadata.client then
            AddCSLuaFile( mainFile )

            local send = metadata.send
            if send ~= nil then
                for _, filePath in ipairs( send ) do
                    local insideFilePath = packagePath .. "/" .. filePath
                    if fs.Exists( insideFilePath, luaRealm ) then
                        AddCSLuaFile( insideFilePath )
                    elseif fs.Exists( filePath, luaRealm ) then
                        AddCSLuaFile( filePath )
                    end
                end
            end
        end

        if not metadata.server then return end
    end

    if isAutorun and not metadata.autorun then
        logger:Debug( "Package `%s` autorun restricted. (%s)", identifier, packagePath )
        return
    end

    metadata.folder = packagePath

    return packages.Initialize( metadata, func, Files, parentPackage )
end )