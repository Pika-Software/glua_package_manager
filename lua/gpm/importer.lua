-- Libraries
local promise = gpm.promise
local paths = gpm.paths
local gpm = gpm

-- Variables
local ipairs = ipairs
local pairs = pairs
local type = type

local sources = {}
for _, source in pairs( gpm.sources ) do
    sources[ #sources + 1 ] = source
end

gpm.AsyncImport = promise.Async( function( filePath, parentPackage )
    ArgAssert( filePath, 1, "string" )

    for _, source in ipairs( sources ) do
        if type( source.CanImport ) ~= "function" then continue end
        if not source.CanImport( filePath ) then continue end
        return source.Import( filePath, parentPackage )
    end
end )

do

    local assert = assert

    function gpm.Import( filePath, async, parentPackage )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local p = gpm.AsyncImport( filePath, parentPackage )
        if not async then return p:Await() end
        return p
    end

end

_G.import = gpm.Import

do

    local file_Find = file.Find

    gpm.ImportFolder = promise.Async( function( luaPath )
        luaPath = paths.Fix( luaPath )

        local files, folders = file_Find( luaPath .. "/*", "LUA" )
        for _, folderName in ipairs( folders ) do
            gpm.AsyncImport( luaPath .. "/" .. folderName )
        end

        for _, fileName in ipairs( files ) do
            gpm.AsyncImport( luaPath .. "/" .. fileName )
        end
    end )

end

local pkgs = gpm.Packages
if type( pkgs ) == "table" then
    for packageName in pairs( pkgs ) do
        pkgs[ packageName ] = nil
    end
end

gpm.ImportFolder( "gpm/packages" )
gpm.ImportFolder( "packages" )

if SERVER then

    local BroadcastLua = BroadcastLua
    local IsValid = IsValid

    concommand.Add( "gpm_reload", function( ply )
        if ply == nil or ( IsValid( ply ) and ply:IsSuperAdmin() ) then
            BroadcastLua( "include( \"gpm/init.lua\" )" )
            include( "gpm/init.lua" )

            hook.Run( "GPM - Reloaded" )
        end
    end )

end