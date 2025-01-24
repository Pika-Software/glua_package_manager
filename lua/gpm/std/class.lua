local std = _G.gpm.std

local rawget = std.rawget
local rawset = std.rawset

local string = std.string
local string_sub = string.sub
local string_format = string.format

local pairs = std.pairs
local is_function = std.is.fn
local setmetatable = std.setmetatable
local debug_getmetatable = std.debug.getmetatable

--- [SHARED AND MENU] The class library.
---@class gpm.std.class
local class = {}

---@class gpm.std.Object
---@field __type string: The name of object type.
---@field __class Class: The class of the object (must be defined).
---@field __parent gpm.std.Object | nil: The parent of the object.
---@alias Object gpm.std.Object

---@class gpm.std.Class : gpm.std.Object
---@field __base gpm.std.Object: The base of the class (must be defined).
---@field __parent gpm.std.Class | nil: The parent of the class.
---@field __inherited fun( parent: gpm.std.Class, child: gpm.std.Class ) | nil: The function that will be called when the class is inherited.
---@alias Class gpm.std.Class

---@param obj Object: The object to convert to a string.
---@return string: The string representation of the object.
local function base__tostring( obj )
    return string_format( "%s: %p", rawget( debug_getmetatable( obj ), "__type" ), obj )
end

--- [SHARED AND MENU] Creates a new class base ( metatable ).
---@param name string: The name of the class.
---@param parent Class | unknown | nil: The parent of the class.
---@return Object: The base of the class.
function class.base( name, parent )
    local base = {
        __type = name,
        __tostring = base__tostring
    }

    base.__index = base

    if parent then
        local parent_base = rawget( parent, "__base" )
        if parent_base == nil then
            std.error( "parent class has no base", 2 )
        end

        ---@cast parent_base gpm.std.Object
        base.__parent = parent_base
        setmetatable( base, { __index = parent_base } )

        -- copy metamethods from parent
        for key, value in pairs( parent_base ) do
            if string_sub( key, 1, 2 ) == "__" and not ( key == "__index" and value == parent_base ) and key ~= "__type" then
                base[ key ] = value
            end
        end
    end

    return base
end

--- [SHARED AND MENU] Calls the base initialization function, <b>if it exists</b>, and returns the given object.
---@param obj table | userdata: The object to initialize.
---@param base Object: The base object, aka metatable.
---@param ... any: Arguments to pass to the constructor.
---@return Object | userdata: The initialized object.
local function init( obj, base, ... )
    local fn = rawget( base, "__init" )
    if is_function( fn ) then
        fn( obj, ... )
    end

    return obj
end

class.init = init

--- [SHARED AND MENU] Creates a new object from the given base.
---@param base Object: The base object, aka metatable.
---@param ... any: Arguments to pass to the constructor.
---@return Object | userdata: The new object.
local function new( base, ... )
    local fn = rawget( base, "__new" )
    if is_function( fn ) then
        local obj = fn( base, ... )
        if obj ~= nil then return obj end
    end

    return init( setmetatable( {}, base ), base, ... )
end

class.new = new

---@param self Class: The class.
---@return Object | userdata: The new object.
local function class__call( self, ... )
    return new( rawget( self, "__base" ), ... )
end

---@param cls Class: The class.
---@return string: The string representation of the class.
local function class__tostring( cls )
    return string_format( "%sClass: %p", rawget( rawget( cls, "__base" ), "__type" ), cls )
end

--- [SHARED AND MENU] Creates a new class from the given base.
---@param base Object: The base object, aka metatable.
---@return Class | unknown: The class.
function class.create( base )
    local cls = {
        __base = base
    }

    local parent = rawget( base, "__parent" )
    ---@cast parent gpm.std.Object
    if parent ~= nil then
        cls.__parent = parent.__class
    end

    setmetatable( cls, {
        __index = base,
        __call = class__call,
        __tostring = class__tostring,
        __type = rawget( base, "__type" ) .. "Class"
    } ) ---@cast cls -Object

    rawset( base, "__class", cls )
    return cls
end

--- [SHARED AND MENU] Calls the base <b>inherited</b> function, <b>if it exists</b>.
---@param cls Class: The class to be inherited.
function class.inherited( cls )
    local base = rawget( cls, "__base" )
    if base == nil then return end

    local parent = rawget( base, "__parent" )
    if parent == nil or not parent.__inherited then return end
    parent:__inherited( cls )
end

return class
