local fm_globals = require("fm-globals")

local M = {}

local function init()
    if not package.loaded["telescope"] then
        fm_globals.debug("Telescope is not loaded")
        return
    end

    M.builtin = require("telescope.builtin")
end

init()

local function get_telescope_dir(state)
    local item = fm_globals.get_cursor_navigation_item(state)
    if fm_globals.is_item_directory(item) then
        return state.dir_path .. item
    else
        return state.dir_path
    end
end

function M.find_files(state)
    if M.builtin == nil then
        return
    end

    local telescope_dir = get_telescope_dir(state)

    fm_globals.close_window(state)

    M.builtin.find_files({ cwd = telescope_dir })
end

function M.live_grep(state)
    if M.builtin == nil then
        return
    end

    local telescope_dir = get_telescope_dir(state)

    fm_globals.close_window(state)

    M.builtin.live_grep({ cwd = telescope_dir })
end

return M
