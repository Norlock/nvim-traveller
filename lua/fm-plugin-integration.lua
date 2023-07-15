local fm_globals = require("fm-globals")

local M = {}

-- Telescope integration
function M.open_telescope(state)
    if not package.loaded["telescope"] then
        fm_globals.debug("Telescope is not loaded")
        return
    end

    local function get_telescope_dir()
        local item = fm_globals.get_cursor_navigation_item(state)
        if fm_globals.is_item_directory(item) then
            return state.dir_path .. item
        else
            return state.dir_path
        end
    end

    local telescope_dir = get_telescope_dir()

	fm_globals.close_window(state)

    local builtin = require("telescope.builtin")

    builtin.find_files({ cwd = telescope_dir })
    --if fm_globals.directory_is_inside_a_git_repo(telescope_dir) then
        --fm_globals.debug("is a git repo")
        --builtin.git_files({ cwd = telescope_dir })
    --else
        --fm_globals.debug("is not a git repo")
        --builtin.find_files({ cwd = telescope_dir })
    --end
end

return M
