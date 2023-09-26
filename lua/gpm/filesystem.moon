SERVER = SERVER
if SERVER
    AddCSLuaFile!

file = file
gpm = gpm

import string, paths, util, metaworks, Logger, Table from gpm

string_GetPathFromFilename = string.GetPathFromFilename
File = FindMetaTable( "File" )
MENU_DLL = MENU_DLL
CLIENT = CLIENT
error = error
type = type

-- https://github.com/Pika-Software/gm_efsw
if SERVER and not efsw and util.IsBinaryModuleInstalled( "efsw" ) and pcall( require, "efsw" )
    Logger\Info( "gm_efsw is initialized, package auto-reloading are available." )

lib = Table gpm, "fs", metaworks.CreateLink( file, true )
lib.Move = file.Rename
lib.Time = file.Time

string_GetExtensionFromFilename = string.GetExtensionFromFilename
lib_IsMounted = nil
do

    mountedFiles = lib.MountedFiles
    if type( mountedFiles ) ~= "table"
        string_StartsWith = string.StartsWith
        rawget, rawset = rawget, rawset
        table_insert = table.insert

        mountedFiles = setmetatable( {}, {
            __index: ( tbl, key ) ->
                for value in *tbl
                    if string_StartsWith( value, key )
                        return true

                return false
            __newindex: ( tbl, key ) ->
                unless rawget( tbl, key )
                    table_insert( tbl, 1, key )
                    rawset( tbl, key, true )
        } )

        lib.MountedFiles = mountedFiles

    lib_IsMounted = ( filePath, gamePath, onlyDir ) ->
        if onlyDir and string_GetExtensionFromFilename( filePath )
            return

        if gamePath == "LUA" or gamePath == "lsv" or gamePath == "lcl"
            filePath = "lua/" .. filePath

        return mountedFiles[ filePath ]
    lib.IsMounted = lib_IsMounted

    game_MountGMA = game.MountGMA
    lib.MountGMA = ( gmaPath ) ->
        ok, files = game_MountGMA( gmaPath )
        unless ok
            return false

        for filePath in *files
            mountedFiles[ filePath ] = true

        Logger\Debug( "GMA file '%s' was mounted to GAME with %d files.", gmaPath, #files )
        return ok, files

lib_CreateDir, lib_IsFile, lib_IsDir = nil, nil, nil
paths_Join = paths.Join
lib_Find = file.Find
lib.Find = lib_Find

do
    table_HasIValue = table.HasIValue
    string_Split = string.Split
    file_Exists = file.Exists
    file_Delete = file.Delete
    file_IsDir = file.IsDir

    lib.Exists = ( filePath, gamePath ) ->
        lib_IsMounted( filePath, gamePath ) or file_Exists( filePath, gamePath )

    lib_IsDir = ( filePath, gamePath ) ->
        if lib_IsMounted( filePath, gamePath, true ) or file_IsDir( filePath, gamePath )
            return true

        _, folders = lib_Find( filePath .. "*", gamePath )
        if folders == nil or #folders == 0
            return false

        splits = string_Split( filePath, "/" )
        table_HasIValue( folders, splits[ #splits ] )
    lib.IsDir = lib_IsDir

    lib_IsFile = ( filePath, gamePath ) ->
        lib_IsMounted( filePath, gamePath ) or ( file_Exists( filePath, gamePath ) and not lib_IsDir( filePath, gamePath ) )
    lib.IsFile = lib_IsFile

    lib_Delete = ( filePath, gamePath, force ) ->
            gamePath = gamePath or "DATA"

            if lib_IsDir filePath, gamePath
                if force
                    files, folders = lib_Find paths_Join( filePath, "*" ), gamePath
                    for folderName in *folders
                        lib_Delete paths_Join( filePath, folderName ), gamePath, force

                    for fileName in *files
                        file_Delete paths_Join( filePath, fileName ), gamePath, force

                file_Delete filePath, gamePath
                return not lib_IsDir filePath, gamePath

            file_Delete filePath, gamePath
            return not lib_IsFile filePath, gamePath
    lib.Delete = lib_Delete

    do
        file_CreateDir = file.CreateDir
        lib_CreateDir = ( folderPath, force ) ->
            unless force
                file_CreateDir folderPath
                return folderPath

            currentPath = nil
            for folderName in *string_Split folderPath, "/"
                if folderName
                    unless currentPath
                        currentPath = folderName
                    else
                        currentPath = currentPath .. "/" .. folderName

                    unless file_IsDir currentPath, "DATA"
                        file_Delete currentPath, "DATA"
                        file_CreateDir currentPath

            return currentPath
        lib.CreateDir = lib_CreateDir

    do
        file_Size = file.Size
        lib_Size = ( filePath, gamePath ) ->
            if not lib_IsDir( filePath, gamePath )
                return file_Size( filePath, gamePath )

            size, files, folders = 0, lib_Find( paths_Join( filePath, "*" ), gamePath )
            for fileName in *files
                size += file_Size( paths_Join( filePath, fileName ), gamePath )

            for folderName in *folders
                size += lib_Size( paths_Join( filePath, folderName ), gamePath )

            return size
        lib.Size = lib_Size

lib_BuildFilePath = ( filePath ) ->
    folderPath = string_GetPathFromFilename( filePath )
    if folderPath
        lib_CreateDir( folderPath )
lib.BuildFilePath = lib_BuildFilePath

lib_IsLuaFile = nil
do

    string_sub = string.sub
    moonloader_PreCacheFile = nil
    if type( moonloader ) == "table"
        moonloader_PreCacheFile = moonloader.PreCacheFile

    lib_IsLuaFile = ( filePath, gamePath, compileMoon ) ->
        extension = string_GetExtensionFromFilename filePath
        if extension and extension ~= "lua" and extension ~= "moon"
            return false

        filePath = string_sub filePath, 1, #filePath - ( extension ~= nil and ( #extension + 1 ) or 0 )

        if compileMoon and ( SERVER or MENU_DLL ) and moonloader_PreCacheFile
            moonPath = filePath  .. ".moon"
            if lib_IsFile moonPath, gamePath
                unless moonloader_PreCacheFile moonPath
                    error "Compiling Moonscript file '" .. moonPath .. "' into Lua is failed!"

                Logger\Debug "The MoonScript file '%s' was successfully compiled into Lua.", moonPath
                return true

        return lib_IsFile filePath .. ".lua", gamePath
    lib.IsLuaFile = lib_IsLuaFile

lib_Read, lib_Write = nil, nil
do
    lib_Open = file.Open
    lib.Open = lib_Open

    lib_Read = ( filePath, gamePath, length ) ->
        fileObject = lib_Open filePath, "rb", gamePath
        unless fileObject
            return false

        content = File.Read( fileObject, length )
        File.Close( fileObject )
        return true, content
    lib.Read = lib_Read

    lib_Write = ( filePath, content, fileMode, fastMode ) ->
        unless fastMode
            lib_BuildFilePath filePath

        fileObject = lib_Open filePath, fileMode or "wb", "DATA"
        unless fileObject
            return false

        File.Write fileObject, content
        File.Close fileObject
        return true
    lib.Write = lib_Write

lib_Append = ( filePath, content, fastMode ) ->
    lib_Write filePath, content, "ab", fastMode
lib.Append = lib_Append
paths_Fix = paths.Fix

if SERVER
    debug_getfpath = debug.getfpath
    gpm_ArgAssert = gpm.ArgAssert
    AddCSLuaFile = AddCSLuaFile
    paths_ToLua = paths.ToLua

    lib.AddCSLuaFile = ( fileName ) ->
        luaPath = debug_getfpath!
        if not fileName and luaPath and lib_IsFile luaPath, "LUA"
            AddCSLuaFile luaPath
            return

        gpm_ArgAssert fileName, 1, "string"
        fileName = paths_ToLua paths_Fix fileName

        if luaPath
            folder = string_GetPathFromFilename luaPath
            if folder
                filePath = folder .. fileName
                if lib_IsLuaFile filePath, "LUA", true
                    AddCSLuaFile filePath
                    return

        if lib_IsLuaFile fileName, "LUA", true
            AddCSLuaFile fileName
            return

        error "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found"

    lib_AddCSLuaFolder = ( folder ) ->
        files, folders = lib_Find paths_Join( folder, "*" ), "lsv"
        for folderName in *folders
            lib_AddCSLuaFolder paths_Join( folder, folderName )

        for fileName in *files
            filePath = paths_Join folder, fileName
            if lib_IsLuaFile filePath, "lsv", true
                AddCSLuaFile paths_ToLua filePath
    lib.AddCSLuaFolder = lib_AddCSLuaFolder

if type( efsw ) == "table"
    watchList = lib.WatchList
    if type( watchList ) ~= "table"
        watchList = {}
        lib.WatchList = watchList

    do
        efsw_Watch = efsw.Watch
        lib_Watch = ( filePath, gamePath, recursively ) ->
            filePath = paths_Fix( filePath )

            if watchList[ filePath .. ";" .. gamePath ] or ( CLIENT and lib_IsMounted( filePath, gamePath ) )
                return false

            if lib_IsDir( filePath, gamePath )
                filePath = filePath .. "/"
                if recursively
                    _, folders = lib_Find filePath .. "*", gamePath
                    for folderName in *folders
                        lib_Watch( filePath .. folderName, gamePath, recursively )

            watchList[ filePath .. ";" .. gamePath ] = efsw_Watch( filePath, gamePath )
            return true
        lib.Watch = lib_Watch

    do
        efsw_Unwatch = efsw.Unwatch
        lib_UnWatch = ( filePath, gamePath, recursively ) ->
            filePath = paths_Fix filePath

            watchID = watchList[ filePath .. ";" .. gamePath ]
            if not watchID
                return false

            if lib_IsDir filePath, gamePath
                filePath = filePath .. "/"
                if recursively
                    _, folders = lib_Find filePath .. "*", gamePath
                    for folderName in *folders
                        lib_UnWatch filePath .. folderName, gamePath, recursively

            efsw_Unwatch watchID
            watchList[ filePath .. ";" .. gamePath ] = nil
            return true
        lib.UnWatch = lib_UnWatch

promise = promise
lib_AsyncRead = nil
do

    PROMISE = promise.PROMISE
    PROMISE_Resolve = PROMISE.Resolve
    PROMISE_Reject = PROMISE.Reject
    promise_New = promise.New

    async = {
        Append: false,
        Write: false,
        Read: false
    }

    do

        sources = {
            {
                Name: "gm_asyncio",
                Available: util.IsBinaryModuleInstalled( "asyncio" ),
                Get: ->
                    require "asyncio"
                    return {
                        Append: asyncio.AsyncAppend,
                        Write: asyncio.AsyncWrite,
                        Read: asyncio.AsyncRead
                    }
            },
            {
                Name: "async_write",
                Available: util.IsBinaryModuleInstalled( "async_write" ),
                Get: ->
                    require "async_write"
                    return {
                        Append: file.AsyncAppen,
                        Write: file.AsyncWrite
                    }
            },
            {
                Name: "Legacy Async",
                Available: not MENU_DLL,
                Get: -> {
                    Read: file.AsyncRead
                }
            },
            {
                Name: "Legacy",
                Available: true,
                Get: -> {
                        Append: ( fileName, content, func ) ->
                            state = lib_Append( fileName, content, true ) and 0 or -1
                            func( fileName, "DATA", state )
                            return state,
                        Write: ( fileName, content, func ) ->
                            state = lib_Write( fileName, content, "wb", true ) and 0 or -1
                            func( fileName, "DATA", state )
                            return state,
                        Read: ( fileName, gamePath, func ) ->
                            ok, content = lib_Read( fileName, gamePath )
                            state = ok and 0 or -1
                            func( fileName, gamePath, state, content )
                            return state
                    }
            }
        }

        count = 0
        for source in *sources
            unless source.Available
                continue

            functions = source.Get!
            installed = 0
            for funcName, func in pairs( async )
                unless func
                    func = functions[ funcName ]
                    if func
                        async[ funcName ] = func
                        installed += 1
                        count += 1

            if installed > 0
                Logger\Info "'%s' was connected as filesystem API.", source.Name

            if count > 2
                break

    do
        async_Read = async.Read
        lib_AsyncRead = ( filePath, gameDir ) ->
            p = promise_New()
            state = async_Read( filePath, gameDir, ( fileName, gamePath, code, content ) ->
                if code ~= 0
                    PROMISE_Reject p, "FSASYNC_READ_ERR: " .. code
                else
                    PROMISE_Resolve p, {
                        fileName: fileName,
                        gamePath: gamePath,
                        content: content
                    }
            )

            if state ~= 0
                PROMISE_Reject p, "FSASYNC_READ_ERR: " .. state

            return p
        lib.AsyncRead = lib_AsyncRead

    do
        async_Write = async.Write
        lib.AsyncWrite = ( filePath, content, fastMode ) ->
            unless fastMode
                lib_BuildFilePath( filePath )

            p = promise_New()
            state = async_Write( filePath, content, ( fileName, gamePath, code ) ->
                if code ~= 0 then
                    PROMISE_Reject p, "FSASYNC_WRITE_ERR: " .. code
                else
                    PROMISE_Resolve p, {
                        fileName: fileName,
                        gamePath: gamePath
                    }
            )

            if state ~= 0
                PROMISE_Reject p, "FSASYNC_WRITE_ERR: " .. state

            return p

    do
        async_Append = async.Append
        lib.AsyncAppend = ( filePath, content, fastMode ) ->
            unless fastMode
                lib_BuildFilePath( filePath )

            p = promise_New()
            state = async_Append( filePath, content, ( fileName, gamePath, code ) ->
                if code ~= 0
                    PROMISE_Reject p, "FSASYNC_APPEND_ERR: " .. code
                else
                    PROMISE_Resolve p, {
                        fileName: fileName,
                        gamePath: gamePath
                    }
            )

            if state ~= 0
                PROMISE_Reject p, "FSASYNC_APPEND_ERR: " .. state

            return p

do

    promise_Reject = promise.Reject

    do

        CompileString = CompileString
        CompileFile = CompileFile

        lib.CompileLua = promise.Async( ( filePath, gamePath, handleError ) ->
            if CLIENT and lib_IsMounted filePath, gamePath
                filePath = "lua/" .. filePath
                gamePath = "GAME"

            ok, result = lib_AsyncRead( filePath, gamePath )\SafeAwait!
            unless ok
                return promise_Reject result

            content = result.content
            unless content
                return promise_Reject "File compilation '" .. filePath .. "' failed, file cannot be read."

            func = CompileString content, filePath, handleError
            if not func and ( gamePath == "LUA" or gamePath == "lsv" or gamePath == "lcl" )
                func = CompileFile filePath

            unless func
                return promise_Reject "File compilation '" .. filePath .. "' failed, unknown error."

            return func
        )

    do
        util_CompileMoonString = util.CompileMoonString
        lib.CompileMoon = promise.Async( ( filePath, gamePath, handleError ) ->
            ok, result = lib_AsyncRead( filePath, gamePath )\SafeAwait!
            unless ok
                return promise_Reject result

            content = result.content
            unless content
                return promise_Reject "File compilation '" .. filePath .. "' failed, file cannot be read."

            return util_CompileMoonString content, filePath, handleError
        )

lib
