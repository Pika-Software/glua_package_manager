local _G = _G
local glua_input, glua_gui = _G.input, _G.gui

---@class gpm.std.input
local input = {}

-- TODO: https://wiki.facepunch.com/gmod/input
-- TODO: https://wiki.facepunch.com/gmod/motionsensor
-- TODO: https://wiki.facepunch.com/gmod/gui

do

    ---@clas gpm.std.input.cursor
    local cursor = {
        isVisible = _G.vgui.CursorVisible,
        getPosition = glua_input.GetCursorPos,
        setPosition = glua_input.SetCursorPos
    }

    input.cursor = cursor

end

return input
