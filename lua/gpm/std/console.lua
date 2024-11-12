local _G = _G
local tostring, select, getfenv, string_format, cvars, concommand, GetConVar_Internal, RunConsoleCommand, MsgC, unpack = _G.tostring, _G.select, _G.getfenv, _G.string.format, _G.cvars, _G.concommand, _G.GetConVar_Internal, _G.RunConsoleCommand, _G.MsgC, _G.unpack
local cvars_GetConVarCallbacks, cvars_AddChangeCallback, cvars_RemoveChangeCallback = cvars.GetConVarCallbacks, cvars.AddChangeCallback, cvars.RemoveChangeCallback

local CONVAR = _G.FindMetaTable( "ConVar" )
local getName, getDefault = CONVAR.GetName, CONVAR.GetDefault

local console = {
    ["variable"] = {},
    ["command"] = {}
}

console.write = MsgC

function console.writeLine( ... )
    local args, length = { ... }, select( '#', ... ) + 1
    args[ length ] = "\n"

    return MsgC( unpack( args, 1, length ) )
end

local variable = console.variable

-- TODO: Rewrite this crap
variable.getCallbacks = cvars_GetConVarCallbacks

variable.addCallback = function( name, callback, identifier )
    local fenv = getfenv( 2 )
    if fenv then
        local package = fenv.__package
        if package then
            local prefix = package.prefix
            identifier = prefix .. ( identifier or "" )
        end
    end

    cvars_AddChangeCallback( name, callback, identifier )
end

variable.removeCallback = function( name, identifier )
    local fenv = getfenv( 2 )
    if fenv then
        local package = fenv.__package
        if package then
            local prefix = package.prefix
            identifier = prefix .. ( identifier or "" )
        end
    end

    cvars_RemoveChangeCallback( name, identifier )
end

variable.create = _G.CreateConVar
variable.exists = _G.ConVarExists

do

    local cache = {}

    function variable.get( name )
        local value = cache[ name ]
        if value == nil then
            value = GetConVar_Internal( name )
            cache[ name ] = value
        end

        return value
    end

end

variable.set = function( name, value )
    RunConsoleCommand( name, tostring( value ) )
    return nil
end

-- get value
variable.getString = CONVAR.GetString
variable.getFloat = CONVAR.GetFloat
variable.getBool = CONVAR.GetBool
variable.getInt = CONVAR.GetInt

-- set value
variable.setString = function( self, value )
    RunConsoleCommand( getName( self ), value )
    return self
end

variable.setFloat = function( self, value )
    RunConsoleCommand( getName( self ), string_format( "%f", value ) )
    return self
end

variable.setBool = function( self, value )
    RunConsoleCommand( getName( self ), value == true and "1" or "0" )
    return self
end

variable.setInt = function( self, value )
    RunConsoleCommand( getName( self ), string_format( "%d", value ) )
    return self
end

variable.revert = function( self )
    RunConsoleCommand( getName( self ), getDefault( self ) )
    return self
end

-- get info
variable.getName = getName
variable.getFlags = CONVAR.GetFlags
variable.isFlagSet = CONVAR.IsFlagSet
variable.getDefault = getDefault
variable.getHelpText = CONVAR.GetHelpText
variable.getMin = CONVAR.GetMin
variable.getMax = CONVAR.GetMax

local command = console.command

command.add = concommand.Add
command.run = RunConsoleCommand
command.remove = concommand.Remove
command.getTable = concommand.GetTable

return console
