if SERVER
    AddCSLuaFile!

setmetatable = setmetatable
ipairs = ipairs
error = error
type = type
gpm = gpm
_G = _G

gpm_Lib = ( name, default ) ->
    lib = gpm[ name ]
    if type( lib ) ~= "table"
        lib = default or {}
        gpm[ name ] = lib
    return lib
gpm.Lib = gpm_Lib

types = gpm_Lib "Types", {
    Indexes: {},
    Names: {
        [TYPE_PARTICLESYSTEM]: "CNewParticleEffect",
        [TYPE_PROJECTEDTEXTURE]: "ProjectedTexture",
        [TYPE_PIXELVISHANDLE]: "pixelvis_handle_t",
        [TYPE_RECIPIENTFILTER]: "CRecipientFilter",
        [TYPE_SOUNDHANDLE]: "IGModAudioChannel",
        [TYPE_LIGHTUSERDATA]: "light userdata",
        [TYPE_PARTICLEEMITTER]: "CLuaEmitter",
        [TYPE_DAMAGEINFO]: "CTakeDamageInfo",
        [TYPE_LOCOMOTION]: "CLuaLocomotion",
        [TYPE_SURFACEINFO]: "SurfaceInfo",
        [TYPE_PHYSCOLLIDE]: "PhysCollide",
        [TYPE_EFFECTDATA]: "CEffectData",
        [TYPE_PARTICLE]: "CLuaParticle",
        [TYPE_NAVLADDER]: "CNavLadder",
        [TYPE_VIDEO]: "IVideoWriter",
        [TYPE_MATERIAL]: "IMaterial",
        [TYPE_MOVEDATA]: "CMoveData",
        [TYPE_PATH]: "PathFollower",
        [TYPE_SOUND]: "CSoundPatch",
        [TYPE_USERDATA]: "userdata",
        [TYPE_FUNCTION]: "function",
        [TYPE_TEXTURE]: "ITexture",
        [TYPE_USERCMD]: "CUserCmd",
        [TYPE_RESTORE]: "IRestore",
        [TYPE_NAVAREA]: "CNavArea",
        [TYPE_PHYSOBJ]: "PhysObj",
        [TYPE_DLIGHT]: "dlight_t",
        [TYPE_USERMSG]: "bf_read",
        [TYPE_MATRIX]: "VMatrix",
        [TYPE_CONVAR]: "ConVar",
        [TYPE_VECTOR]: "Vector",
        [TYPE_ENTITY]: "Entity",
        [TYPE_THREAD]: "thread",
        [TYPE_STRING]: "string",
        [TYPE_NUMBER]: "number",
        [TYPE_NONE]: "unknown",
        [TYPE_BOOL]: "boolean",
        [TYPE_IMESH]: "IMesh",
        [TYPE_PANEL]: "Panel",
        [TYPE_ANGLE]: "Angle",
        [TYPE_COLOR]: "Color",
        [TYPE_TABLE]: "table",
        [TYPE_SAVE]: "ISave",
        [TYPE_FILE]: "File",
        [TYPE_NIL]: "nil"
    }
}

typeNames = types.Names
indexes = types.Indexes

do

    TYPE_USERDATA = TYPE_USERDATA
    TYPE_TABLE = TYPE_TABLE
    TypeID = TypeID

    gpm.TypeID = ( any ) ->
        id = TypeID any
        if id == TYPE_TABLE or id == TYPE_USERDATA
            for data in *indexes
                if data[ 1 ]( any )
                    return data[ 2 ]

        id

do
    gpm_TypeID = gpm.TypeID
    gpm.type = ( any ) -> typeNames[ gpm_TypeID( any ) ] or "unknown"

string = gpm_Lib "string", setmetatable( {}, { __index: _G.string } )
string.StartsWith = string.StartsWith or string.StartWith

do
    string_match = string.match
    string.IsURL = ( str ) ->
        string_match( str, "^https?://.+$" ) ~= nil

string_format = string.format
string_lower = string.lower
string_sub = string.sub

debug = gpm_Lib "debug", setmetatable( {}, { __index: _G.debug } )
debug.fempty = ->
debug_getinfo = debug.getinfo
debug.fcall = ( func, ... ) ->
    return func( ... )

do
    gpm_type = gpm.type
    gpm.ArgAssert = ( value, argNum, expected, errorlevel ) ->
        valueType, expectedType = gpm_type( value ), gpm_type( expected )
        if expectedType == "table"
            str, len = "[ ", #expected
            for index = 1, len
                typeName = expected[ index ]

                if valueType == typeName
                    return value
                elseif index ~= len
                    str = str .. typeName .. ", "

            expected = str .. " ]"
        elseif expectedType == "function"
            expected = expected( value, argNum )
            if type( expected ) ~= "string"
                return value
        elseif valueType == expected
            return value

        dinfo = debug_getinfo( 2, "n" )
        error( string_format( "bad argument #%d to \'%s\' (%s expected, got %s)", argNum, dinfo and dinfo.name or "func", expected, valueType ), errorlevel or 3 )

table = gpm_Lib "table", setmetatable( {}, { __index: _G.table } )
table_remove = table.remove
string_Split = string.Split

table.HasIValue = ( tbl, any ) ->
    for value in *tbl do
        if value == any
            return true
    return false

table.RemoveByIValue = ( tbl, any ) ->
    for index, value in ipairs( tbl )
        if value == any
            return table_remove( tbl, index )

table.Lookup = ( tbl, str, default ) ->
    for key in *string_Split( str, "." )
        tbl = tbl[ key ]
        if not tbl
            return default
    return tbl

table.SetValue = ( tbl, str, value, ifEmpty ) ->
    keys = string_Split( str, "." )
    len = #keys

    for index = 1, len
        key = keys[ index ]
        if index == len then
            oldValue = tbl[ key ]
            if oldValue ~= nil and ifEmpty
                return oldValue

            tbl[ key ] = value
            return value

        nextValue = tbl[ key ]
        if nextValue == nil
            tbl[ key ] = {}
        elseif type( nextValue ) ~= "table"
            return

        tbl = tbl[ key ]

table_Lower = ( tbl ) ->
    for key, value in pairs( tbl )
        if type( value ) == "table"
            value = table_Lower( value )

        keyType = type( key )
        if keyType == "string"
            tbl[ string_lower( key ) ] = value
            tbl[ key ] = nil
        elseif keyType == "table"
            tbl[ table_Lower( key ) ] = value
            tbl[ key ] = nil

    return tbl
table.Lower = table_Lower

table.RemoveByFunction = ( tbl, func ) ->
    result, fulfilled = {}, false
    while not fulfilled
        fulfilled = true

        for index, value in ipairs( tbl )
            if func( index, value )
                result[ #result + 1 ] = table.remove( tbl, index )
                fulfilled = false
                break

    return result

table.unpack = unpack

metaworks = include "libs/metaworks.lua"
gpm_ArgAssert = gpm.ArgAssert

gpm_AddType = ( typeName, func ) ->
    gpm_ArgAssert( typeName, 1, "string" )
    gpm_ArgAssert( func, 2, "function" )

    nextIndex = 256
    for key, name in pairs typeNames
        if typeName == name
            nextIndex = key
            break
        elseif key >= nextIndex
            nextIndex = key + 1

    typeNames[ nextIndex ] = typeName

    for index, data in ipairs indexes
        if nextIndex == data[ 2 ]
            table_remove( indexes, index )
            break

    indexes[ #indexes + 1 ] = { func, nextIndex }
    return nextIndex

gpm.AddType = gpm_AddType
getmetatable = getmetatable

do

    meta = FindMetaTable( "Color" )

    gpm_IsColor = ( any ) ->
        if getmetatable( any ) == meta
            return true

        if type( any ) == "table"
            return type( any.r ) == "number" and type( any.g ) == "number" and type( any.b ) == "number"

        return false

    gpm_AddType( "Color", gpm_IsColor )
    gpm.IsColor = gpm_IsColor

paths = gpm_Lib "paths"
string_gsub = string.gsub
paths_Fix = ( filePath ) -> string_lower( string_gsub( filePath, "[/\\]+", "/" ) )
paths.Fix = paths_Fix

paths.Join = ( ... ) ->
    args, filePath = { ... }
    len = #args

    for i = 1, len do
        if filePath ~= nil
            filePath = filePath .. args[ i ]
        else
            filePath = args[ i ]

        if i == len then
            return paths_Fix( filePath )

        filePath = filePath .. "/"

paths_Localize = ( filePath ) ->
    return string_gsub( string_gsub( string_gsub( filePath, "^cache/moonloader/", "" ), "^addons/[%w%-_]-/", "" ), "^lua/", "" )
paths.Localize = paths_Localize

debug.getfpath = ->
    for i = 2, 6
        info = debug_getinfo( i, "S" )
        if not info
            break

        if info.what == "main"
            return paths_Localize paths_Fix info.short_src

do
    string_GetExtensionFromFilename = string.GetExtensionFromFilename
    paths.ToLua = ( filePath ) ->
        extension = string_GetExtensionFromFilename( filePath )
        if extension ~= "lua"
            if extension
                filePath = string_gsub( filePath, "%..+$", ".lua" )
            else
                filePath = filePath .. ".lua"
        return filePath

do

    util = gpm_Lib "util", metaworks.CreateLink _G.util, true
    tonumber = tonumber

    util.Version = ( number ) ->
        if not number
            return "unknown"

        if type( number ) == "string"
            return number

        version = string_format( "%06d", number )
        return string_format( "%d.%d.%d", tonumber( string_sub( version, 0, 2 ) ), tonumber( string_sub( version, 3, 4 ) ), tonumber( string_sub( version, 5 ) ) )

    do
        timer_Simple = timer.Simple
        util.NextTick = ( func, a, b, c, d ) ->
            gpm_ArgAssert( func, 1, "function" )
            timer_Simple( 0, () -> func( a, b, c, d ) )

    file_Exists = file.Exists
    util.IsLuaModuleInstalled = ( name ) -> file_Exists( "includes/modules/" .. name .. ".lua", "LUA" )

    isWindows, isLinux = system.IsWindows(), system.IsLinux()
    jit_versionnum, jit_arch = jit.versionnum, jit.arch

    suffix = ( { "osx64", "osx", "linux64", "linux", "win64", "win32" } )[ ( isWindows and 4 or 0 ) + ( isLinux and 2 or 0 ) + ( jit_arch == "x86" and 1 or 0 ) + 1 ]
    fmt = "lua/bin/gm" .. ( ( CLIENT and not MENU_DLL ) and "cl" or "sv" ) .. "_%s_%s.dll"

    util.IsBinaryModuleInstalled = ( name ) ->
        gpm_ArgAssert( name, 1, "string" )

        if file_Exists( string_format( fmt, name, suffix ), "GAME" ) then
            return true

        if jit_versionnum ~= 20004 and jit_arch == "x86" and isLinux then
            return file_Exists( string_format( fmt, name, "linux32" ), "GAME" )

        return false

    do

        CompileString = CompileString

        moonloader_ToLua = nil
        if type( moonloader ) == "table"
            moonloader_ToLua = moonloader.ToLua

        util.CompileMoonString = ( moonCode, identifier, handleError ) ->
            if not moonloader_ToLua
                error "Attempting to compile a Moonscript file fails, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader."

            luaCode, msg = moonloader_ToLua moonCode
            msg = msg or "MoonScript to Lua code compilation failed."
            if not luaCode
                error msg

            func = CompileString luaCode, identifier, handleError
            if type( func ) ~= "function"
                error msg

            return func

do

    meta = FindMetaTable( "File" )

    meta_WriteULong = meta.WriteULong
    meta_ReadULong = meta.ReadULong
    meta_WriteByte = meta.WriteByte
    meta_EndOfFile = meta.EndOfFile
    meta_ReadByte = meta.ReadByte
    meta_Write = meta.Write
    meta_Read = meta.Read
    meta_Seek = meta.Seek
    meta_Skip = meta.Skip
    meta_Tell = meta.Tell

    meta.SkipEmpty = ( fileObject ) ->
        while not meta_EndOfFile( fileObject ) do
            if meta_ReadByte( fileObject ) ~= 0 then
                meta_Skip( fileObject, -1 )
                break

    meta.ReadString = ( fileObject ) ->
        startPos, len = meta_Tell( fileObject ), 0

        while not meta_EndOfFile( fileObject ) and meta_ReadByte( fileObject ) ~= 0 do
            len = len + 1

        meta_Seek( fileObject, startPos )
        data = meta_Read( fileObject, len )
        meta_Skip( fileObject, 1 )
        return data

    meta.WriteString = ( fileObject, str ) ->
        meta_Write( fileObject, str )
        meta_WriteByte( fileObject, 0 )

    unless meta.ReadUInt64
        meta.ReadUInt64 = ( fileObject ) ->
            number = meta_ReadULong( fileObject )
            meta_Skip( fileObject, 4 )
            return number

    unless meta.WriteUInt64
        meta.WriteUInt64 = ( fileObject, number ) ->
            meta_WriteULong( fileObject, number )
            meta_WriteULong( fileObject, 0 )

do

    colors = gpm.Colors
    whiteColor = colors.White
    debugFilter = () -> gpm.Developer > 0
    primaryTextColor = colors.PrimaryText
    secondaryTextColor = colors.SecondaryText
    stateName, stateColor = string.upper( gpm.State ), colors.State

    gpm_IsColor = gpm.IsColor
    os_date = os.date
    select = select
    MsgC = MsgC

    infoColor = colors.Info
    warnColor = colors.Warn
    errorColor = colors.Error
    debugColor = colors.Debug

    class Logger
        __tostring: () => "Logger [" .. @GetName! .. "]"

        new: ( name, color, func ) =>
            @DebugFilter = type( func ) == "function" and func or debugFilter
            @Name = type( name ) == "string" and name or "unknown"
            @Color = gpm_IsColor( color ) and color or whiteColor
            @TextColor = primaryTextColor

        GetName: => @Name
        SetName: ( str ) =>
            gpm_ArgAssert( str, 1, "string" )
            @Name = str

        GetColor: => @Color
        SetColor: ( color ) =>
            gpm_ArgAssert( color, 1, "Color" )
            @Color = color

        GetTextColor: => @TextColor
        SetTextColor: ( color ) =>
            gpm_ArgAssert( color, 1, "Color" )
            @TextColor = color

        GetDebugFilter: => @DebugFilter
        SetDebugFilter: ( func ) =>
            gpm_ArgAssert( func, 1, "function" )
            @DebugFilter = func

        Log: ( color, level, str, ... ) =>
            gpm_ArgAssert( color, 1, "Color" )
            gpm_ArgAssert( level, 2, "string" )

            if select( "#", ... ) > 0
                str = string_format( str, ... )
            MsgC( secondaryTextColor, os_date( "%d-%m-%Y %H:%M:%S " ), stateColor, "[" .. stateName .. "] ", color, level, secondaryTextColor, " --> ", @Color, @Name, secondaryTextColor, " : ", @TextColor, str, "\n" )

        Info: ( str, ... ) =>
            @Log( infoColor, "INFO ", str, ... )

        Warn: ( str, ... ) =>
            @Log( warnColor, "WARN ", str, ... )

        Error: ( str, ... ) =>
            @Log( errorColor, "ERROR", str, ... )

        Debug: ( str, ... ) =>
            if @DebugFilter( str, ... ) then
                @Log( debugColor, "DEBUG", str, ... )

    meta = Logger.__index
    gpm.LOGGER = meta

    gpm_IsLogger = ( any ) ->
        getmetatable( any ) == meta

    gpm.AddType( "Logger", gpm_IsLogger )
    gpm.IsLogger = gpm_IsLogger

    gpm.Logger = Logger "gpm@" .. gpm.VERSION, colors.gpm
