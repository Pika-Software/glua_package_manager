local gpm = gpm

-- Libraries
local promise = gpm.promise
local http = gpm.http
local string = string

module( "gpm.sources.github" )

function CanImport( filePath )
    return string.match( filePath, "github.com/(.+)" ) ~= nil
end

function GetInfo( url )
    local user, repository = string.match( url, "github.com/([%w_%-%.]+)/([%w_%-%.]+)" )
    return {
        ["tree"] = string.match( url, "/tree/([%w_%-%.%/]+)"),
        ["repository"] = repository,
        ["user"] = user,
        ["url"] = url
    }
end

ImportTree = promise.Async( function( user, repository, tree )
    local url = string.format( "https://github.com/%s/%s/archive/refs/heads/%s.zip", user, repository, tree )

    local ok, result = http.Fetch( url ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    if result.code ~= 200 then
        return promise.Reject( "invalid response http code - " .. result.code )
    end

    return gpm.SourceImport( "http", url, _PKG, false )
end )

Import = promise.Async( function( info )
    local user = info.user
    if not user then return promise.Reject( "attempt to download failed - repository not recognized" ) end

    local repository = info.repository
    if not repository then return promise.Reject( "attempt to download failed - user not recognized" ) end

    local tree = info.tree
    if tree ~= nil then
        local ok, result = ImportTree( user, repository, tree ):SafeAwait()
        if ok then return result end
    end

    local ok, result = ImportTree( user, repository, "main" ):SafeAwait()
    if ok then return result end

    ok, result = ImportTree( user, repository, "master" ):SafeAwait()
    if ok then return result end

    return promise.Reject( result )
end )