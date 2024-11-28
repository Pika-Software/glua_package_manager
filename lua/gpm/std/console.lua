local _G = _G
local std = _G.gpm.std
local select = std.select
local is_string = std.is.string
local string_format = std.string.format
local RunConsoleCommand = _G.RunConsoleCommand

---@type ConVar
local CONVAR = _G.FindMetaTable( "ConVar" )
local getName, getDefault = CONVAR.GetName, CONVAR.GetDefault

---@class gpm.std.console
local console = {}

if std.MENU then
    console.show = _G.gui.ShowConsole
end

function console.hide()
    RunConsoleCommand( "hideconsole" )
end

function console.toggle()
    RunConsoleCommand( "toggleconsole" )
end

do

    local AddConsoleCommand = _G.AddConsoleCommand

    -- TODO: make own concommands with AddConsoleCommand

    ---@class gpm.std.console.command
    local command = {
        run = RunConsoleCommand,
        isBlacklisted = _G.IsConCommandBlocked
    }

    function command.create()

        -- AddConsoleCommand
    end

    function command.remove()

    end

    console.command = command

end

do

    local unpack = std.table.unpack
    local MsgC = _G.MsgC

    console.write = MsgC

    --- Writes a colored message to the console on a new line.
    ---@param ... string | Color: The message to write to the console.
    function console.writeLine( ... )
        local args, length = { ... }, select( '#', ... ) + 1
        args[ length ] = "\n"
        MsgC( unpack( args, 1, length ) )
    end

end

---@class gpm.std.console.variable
local variable = {
    create = _G.CreateConVar,
    exists = _G.ConVarExists
}

console.variable = variable

do

    -- local debug_getfpackage = std.debug.getfpackage

    -- TODO: make own callbacks for cvars

    _G.cvars.OnConVarChanged = gpm.detour.attach( _G.cvars.OnConVarChanged, function( fn, name, old, new )

        return fn( name, old, new )
    end )

    -- TODO: Rewrite this crap
    -- variable.getCallbacks = cvars_GetConVarCallbacks

    -- variable.addCallback = function( name, callback, identifier )
    --     local package = debug_getfpackage( 2 )
    --     if package == nil then
    --         -- cvars_AddChangeCallback( name, callback, identifier )
    --     else
    --         local prefix = package.prefix
    --         identifier = prefix .. ( identifier or "" )
    --     end
    -- end

    -- variable.removeCallback = function( name, identifier )
    --     local package = debug_getfpackage( 2 )
    --     if package == nil then
    --         -- cvars_RemoveChangeCallback( name, identifier )
    --     else
    --         local prefix = package.prefix
    --         identifier = prefix .. ( identifier or "" )
    --     end
    -- end

end

local variable_get
do

    local GetConVar_Internal = _G.GetConVar_Internal
    local cache = {}

    --- Gets the `ConVar` with the specified name.
    ---@param name string Name of the `ConVar` to get.
    ---@return ConVar | nil: The `ConVar` object, or `nil` if no such `ConVar` was found.
    function variable_get( name )
        local value = cache[ name ]
        if value == nil then
            value = GetConVar_Internal( name )
            cache[ name ] = value
        end

        return value
    end

    variable.get = variable_get

end

do

    local tostring = std.tostring

    --- Sets the value of the ConVar with the specified name.
    ---@param name string | ConVar: The name or `ConVar` object of the `ConVar` to set.
    ---@param value any: The value to set.
    function variable.set( name, value )
        value = tostring( value )

        if is_string( name ) then
            ---@cast name string
            RunConsoleCommand( name, value )
        else
            ---@cast name ConVar
            RunConsoleCommand( getName( name ), value )
        end
    end

end

-- get value
do

    local getString = CONVAR.GetString

    --- Returns the value of the `ConVar` with the specified name.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return string: The value of the `ConVar`.
    function variable.getString( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return ""
        else
            ---@cast convar ConVar
            return getString( convar )
        end
    end

end

do

    local getFloat = CONVAR.GetFloat

    --- Returns the value of the `ConVar` with the specified name.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return number: The value of the `ConVar`.
    function variable.getFloat( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return 0
        else
            ---@cast convar ConVar
            return getFloat( convar )
        end
    end

end

do

    local getBool = CONVAR.GetBool

    --- Returns the value of the `ConVar` with the specified name.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return boolean: The value of the `ConVar`.
    function variable.getBool( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return false
        else
            ---@cast convar ConVar
            return getBool( convar )
        end
    end

end

do

    local getInt = CONVAR.GetInt

    --- Returns the value of the `ConVar` with the specified name.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return number: The value of the `ConVar`.
    function variable.getInt( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return 0
        else
            ---@cast convar ConVar
            return getInt( convar )
        end
    end

end

--- Sets the value of the ConVar with the specified name.
---@param convar string | ConVar: The name or `ConVar` object of the `ConVar` to set.
---@param value any: The value to set.
function variable.setString( convar, value )
    if is_string( convar ) then
        ---@cast convar string
        RunConsoleCommand( convar, value )
    else
        ---@cast convar ConVar
        RunConsoleCommand( getName( convar ), value )
    end
end

--- Sets the value of the ConVar with the specified name.
---@param convar string | ConVar: The name or `ConVar` object of the `ConVar` to set.
---@param value number: The value to set.
function variable.setFloat( convar, value )
    local str = string_format( "%f", value )

    if is_string( convar ) then
        ---@cast convar string
        RunConsoleCommand( convar, str )
    else
        ---@cast convar ConVar
        RunConsoleCommand( getName( convar ), str )
    end
end

--- Sets the value of the ConVar with the specified name.
---@param convar string | ConVar:
---@param value boolean:
function variable.setBool( convar, value )
    local str = value == true and "1" or "0"

    if is_string( convar ) then
        ---@cast convar string
        RunConsoleCommand( convar, str )
    else
        ---@cast convar ConVar
        RunConsoleCommand( getName( convar ), str )
    end
end

--- Sets the value of the ConVar with the specified name.
---@param convar string | ConVar: The name or `ConVar` object of the `ConVar` to set.
---@param value number: The value to set.
function variable.setInt( convar, value )
    local str = string_format( "%d", value )
    if is_string( convar ) then
        ---@cast convar string
        RunConsoleCommand( convar, str )
    else
        ---@cast convar ConVar
        RunConsoleCommand( getName( convar ), value )
    end
end

--- Reverts the value of the ConVar with the specified name.
--- @param convar string | ConVar: The name or `ConVar` object of the `ConVar` to revert to the default value.
function variable.revert( convar )
    if is_string( convar ) then
        ---@cast convar string
        RunConsoleCommand( convar, variable_get( convar ) )
    else
        ---@cast convar ConVar
        RunConsoleCommand( getName( convar ), getDefault( convar ) )
    end
end

--- Returns the name of the ConVar.
---@param convar string | ConVar: The name or `ConVar` object of the `ConVar` to get name.
---@return string: The name of the console variable.
function variable.getName( convar )
    if is_string( convar ) then
        ---@cast convar string
        return convar
    else
        ---@cast convar ConVar
        return getName( convar )
    end
end

do

    local getFlags = CONVAR.GetFlags

    --- Returns the `Enums/FCVAR` flags of the ConVar.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return number: The value of the `ConVar`.
    function variable.getFlags( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return 0
        else
            ---@cast convar ConVar
            return getFlags( convar )
        end
    end

end

do

    local isFlagSet = CONVAR.IsFlagSet

    --- Returns whether the specified flag is set on the ConVar.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@param flag number: The `Enums/FCVAR` flag to test.
    ---@return boolean: Whether the flag is set or not.
    function variable.isFlagSet( convar, flag )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return false
        else
            ---@cast convar ConVar
            return isFlagSet( convar, flag )
        end
    end

end

--- Returns the default value of the ConVar.
---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
---@return string: The default value of the `ConVar`.
function variable.getDefault( convar )
    if is_string( convar ) then
        ---@cast convar string
        convar = variable_get( convar )
    end

    if convar == nil then
        return ""
    else
        ---@cast convar ConVar
        return getDefault( convar )
    end
end

do

    local getHelpText = CONVAR.GetHelpText

    --- Returns the help text of the ConVar.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return string: The help text of the `ConVar`.
    function variable.getHelpText( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return ""
        else
            ---@cast convar ConVar
            return getHelpText( convar )
        end
    end

end

do

    local getMin, getMax = CONVAR.GetMin, CONVAR.GetMax

    --- Returns the minimum value of the ConVar.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return number?
    function variable.getMin( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return nil
        else
            ---@cast convar ConVar
            return getMin( convar )
        end
    end

    --- Returns the maximum value of the ConVar.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return number?
    function variable.getMax( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return nil
        else
            ---@cast convar ConVar
            return getMax( convar )
        end
    end

    --- Returns the minimum and maximum values of the ConVar.
    ---@param convar string | ConVar | nil: The name or `ConVar` object of the `ConVar` to get.
    ---@return number?, number?: The minimum and maximum values of the `ConVar`.
    function variable.getBounds( convar )
        if is_string( convar ) then
            ---@cast convar string
            convar = variable_get( convar )
        end

        if convar == nil then
            return nil, nil
        else
            ---@cast convar ConVar
            return getMin( convar ), getMax( convar )
        end
    end

end

return console
