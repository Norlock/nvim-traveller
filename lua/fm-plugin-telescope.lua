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

---@param state NavigationState
function M:find_files(state)
    if self.builtin == nil then
        return
    end

    M.builtin.find_files({ cwd = state.dir_path })
end

---@param state NavigationState
function M:live_grep(state)
    if self.builtin == nil then
        return
    end

    self.builtin.live_grep({ cwd = state.dir_path })
end

---@param state NavigationState
function M:global_search(state)
    local function attach_mappings(_, _)
        local actions = M.actions
        local action_state = M.action_state

        actions.select_all:replace(function() end)
        actions.select_tab:replace(function() end)
        actions.select_vertical:replace(function() end)
        actions.select_horizontal:replace(function() end)

        -- TODO replace close function for the other ones
        actions.select_default:replace(function(opts)
            local selection = action_state.get_selected_entry()

            if #selection == 0 then
                return
            end

            actions.close(opts)

            state:reload_navigation(selection[1])
        end)

        return true
    end

    local home_dir = fm_globals.get_home_directory()

    -- to execute the function
    local opts = {
        attach_mappings = attach_mappings,
    }

    self.pickers.new(opts, {
        prompt_title = "Directories",
        finder = M.finders.new_oneshot_job({ "fd", "-t", "directory", ".", home_dir }),
        sorter = M.config.file_sorter(opts),
        previewer = M.config.file_previewer(opts),
    }):find()
end

return M
