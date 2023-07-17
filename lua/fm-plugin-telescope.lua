local fm_globals = require("fm-globals")

local M = {}

local function init()
    if not package.loaded["telescope"] then
        fm_globals.debug("Telescope is not loaded")
        return
    end

    M.builtin = require("telescope.builtin")
    M.pickers = require("telescope.pickers")
    M.finders = require("telescope.finders")
    M.config = require("telescope.config").values
    M.actions = require("telescope.actions")
    M.action_state = require("telescope.actions.state")
end

init()

local function close_navigation(state)
    if state.as_popup then
        fm_globals.close_window(state)
    end
end

function M.find_files(state)
    if M.builtin == nil then
        return
    end

    close_navigation(state)

    M.builtin.find_files({ cwd = state.dir_path })
end

function M.live_grep(state)
    if M.builtin == nil then
        return
    end

    close_navigation(state)

    M.builtin.live_grep({ cwd = state.dir_path })
end

function M.global_search(traveller)
    local home_dir = fm_globals.get_home_directory()

    local global_directories = function(opts)
        -- TODO default find

        M.pickers.new(opts, {
            prompt_title = "Directories",
            finder = M.finders.new_oneshot_job({ "fd", "-t", "directory", ".", home_dir }),
            sorter = M.config.file_sorter(opts),
            previewer = M.config.file_previewer(opts),
        }):find()
    end

    local function attach_mappings(prompt_bufnr, map)
        fm_globals.debug(map)

        local actions = M.actions
        local action_state = M.action_state

        actions.select_all:replace(function () end)

        actions.select_default:replace(function(opts)
            local selection = action_state.get_selected_entry()

            if #selection == 0 then
                return
            end

            fm_globals.debug(selection)
            actions.close(opts)
            traveller.open_navigation_in_window(selection[1])

        end)

        return true
    end

    -- to execute the function
    local opts = {
        attach_mappings = attach_mappings,
        cwd = "~"
    }

    global_directories(opts)
end

return M
