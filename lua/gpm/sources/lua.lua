local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local paths = gpm.paths
local string = string
local table = table
local fs = gpm.fs

-- Variables
local SERVER = SERVER
local ipairs = ipairs
local type = type

if efsw ~= nil then
    hook.Add( "FileWatchEvent", "GPM.Sources.Lua.Hot-Reload", function( action, _, filePath )
        if action <= 0 then return end

        local importPath = string.match( string.sub( filePath, 5 ), "packages/[^/]+" )
        if not importPath then return end

        local pkg = gpm.Packages[ importPath ]
        if not pkg then return end

        if not pkg:IsInstalled() then return end
        if pkg:IsReloading() then return end

        pkg:Reload():Catch( function( message )
            gpm.Logger:Error( message )
        end )
    end )
end

module( "gpm.sources.lua" )

function CanImport( filePath )
    if fs.IsDir( filePath, "LUA" ) then return true end
    if fs.IsFile( filePath, "LUA" ) then
        local extension = string.GetExtensionFromFilename( filePath )
        return extension == "moon" or extension == "lua"
    end

    return false
end

GetMetadata = promise.Async( function( importPath )
    local metadata, folder = nil, importPath
    if fs.IsDir( folder, "LUA" ) then
        gpm.PreCacheMoon( folder, true )

        if SERVER then
            fs.Watch( folder .. "/", "lsv" )
        end
    else
        folder = string.GetPathFromFilename( importPath )
    end

    local packagePath = nil
    if not string.match( folder, "^includes/modules/?$" ) then
        local moonPath = paths.Fix( folder .. "/package.moon" )
        if fs.IsFile( moonPath, "LUA" ) then
            local ok, result = fs.CompileMoon( moonPath, "lsv" ):SafeAwait()
            if not ok then
                return promise.Reject( result )
            end

            metadata = package.BuildMetadata( result )
            packagePath = moonPath
        end

        if not packagePath then
            local luaPath = paths.Fix( folder .. "/package.lua" )
            if fs.IsFile( luaPath, "LUA" ) then
                local ok, result = gpm.CompileLua( luaPath ):SafeAwait()
                if not ok then
                    return promise.Reject( result )
                end

                metadata = package.BuildMetadata( result )
                packagePath = luaPath
            end
        end
    end

    -- Single file
    if not metadata then
        metadata = {
            ["autorun"] = true
        }

        local extension = string.GetExtensionFromFilename( importPath )
        if extension == "moon" then
            if not fs.IsFile( importPath, "LUA" ) then
                return promise.Reject( "Unable to compile Moonscript '" .. importPath .. "' file, file not found." )
            end

            gpm.PreCacheMoon( importPath, false )
            importPath = string.sub( importPath, 1, #importPath - #extension ) .. "lua"
        end

        if fs.IsFile( importPath, "LUA" ) then
            metadata.main = importPath
        end
    end

    if packagePath ~= nil then
        metadata.packagepath = packagePath
        metadata.folder = folder
    end


    -- Shared main file
    local main = metadata.main
    if type( main ) == "string" then
        main = paths.Fix( main )
    else
        main = "init.lua"
    end

    if not fs.IsFile( main, "LUA" ) then
        main = paths.Join( importPath, main )

        if not fs.IsFile( main, "LUA" ) then
            main = importPath .. "/init.lua"
            if not fs.IsFile( main, "LUA" ) then
                main = importPath .. "/main.lua"
            end
        end
    end

    if fs.IsFile( main, "LUA" ) then
        metadata.main = main
    else
        metadata.main = nil
    end

    -- Client main file
    local cl_main = metadata.cl_main
    if type( cl_main ) == "string" then
        cl_main = paths.Fix( cl_main )
    else
        cl_main = "cl_init.lua"
    end

    if not fs.IsFile( cl_main, "LUA" ) then
        cl_main = paths.Join( importPath, cl_main )
        if not fs.IsFile( cl_main, "LUA" ) then
            cl_main = importPath .. "/cl_init.lua"
        end
    end

    if fs.IsFile( cl_main, "LUA" ) then
        metadata.cl_main = cl_main
    else
        metadata.cl_main = nil
    end

    return metadata
end )

if SERVER then

    local addClientLuaFile = package.AddClientLuaFile

    function SendToClient( metadata )
        local packagePath = metadata.packagepath
        if packagePath then
            addClientLuaFile( packagePath )
        end

        local cl_main = metadata.cl_main
        if cl_main then
            addClientLuaFile( cl_main )
        end

        local main = metadata.main
        if main then
            addClientLuaFile( metadata.main )
        end

        local send = metadata.send
        if send then
            local folder = metadata.folder
            for _, filePath in ipairs( send ) do
                if folder then
                    local localFilePath = folder .. "/" .. filePath
                    if fs.IsFile( localFilePath, "lsv" ) then
                        addClientLuaFile( localFilePath )
                        continue
                    end
                end

                if fs.IsFile( filePath, "lsv" ) then
                    addClientLuaFile( filePath )
                end
            end
        end
    end

end

CompileMain = promise.Async( function( filePath )
    if not filePath then
        return promise.Reject( "Package main file '" .. ( filePath or "init.lua" ) .. "' is missing." )
    end

    return gpm.Compile( filePath )
end )

Import = promise.Async( function( metadata )
    local ok, result = CompileMain( metadata.main ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    return package.Initialize( metadata, result )
end )

Reload = promise.Async( function( pkg, metadata )
    table.Empty( pkg.Files )

    if SERVER then
        SendToClient( metadata )
    end

    local ok, result = CompileMain( metadata.main ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    pkg.Main = result

    local ok, result = pkg:Initialize( metadata ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    local ok, result = pkg:Run():SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    return result
end )