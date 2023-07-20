local fm_globals = require("fm-globals")
local fm_shell = require("fm-shell")

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
    M.themes = require("telescope.themes")
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
---@param search_dir string absolute directory to start search from
---@param show_hidden boolean show hidden files or not
function M:global_search(state, search_dir, show_hidden)
    local home_dir = fm_globals.get_home_directory()

    search_dir = search_dir or home_dir
    show_hidden = show_hidden == true

    if not fm_globals.is_item_directory(search_dir) then
        search_dir = search_dir .. "/"
    end

    local function attach_mappings(_, _)
        local actions = M.actions
        local action_state = M.action_state

        local function execute_item(opts, callback)
            local selection = action_state.get_selected_entry()

            if #selection == 0 then
                return
            end

            actions.close(opts)

            callback()
            state:reload_navigation(search_dir .. selection[1])
        end

        actions.select_all:replace(function() end)

        actions.select_tab:replace(function(opts)
            local selection = action_state.get_selected_entry()

            if #selection == 0 then
                return
            end

            actions.close(opts)
            fm_shell.open_terminal(search_dir .. selection[1])
        end)

        actions.select_vertical:replace(function(opts)
            execute_item(opts, function()
                vim.cmd("vsplit")
            end)
        end)

        actions.select_horizontal:replace(function(opts)
            execute_item(opts, function()
                vim.cmd("split")
            end)
        end)

        actions.select_default:replace(function(opts)
            execute_item(opts, function() end)
        end)

        return true
    end

    local function get_search_cmd()
        if home_dir == search_dir then
            return { "fd", "--type", "directory", "--base-directory", search_dir, ".", "./",
                ".config/" }
        end

        if show_hidden then
            return { "fd", "-H", "--exclude", ".git/", "--type", "directory", "--base-directory", search_dir }
        else
            return { "fd", "--type", "directory", "--base-directory", search_dir }
        end
    end

    local opts = M.themes.get_dropdown({
        attach_mappings = attach_mappings,
    })

    local cmd = get_search_cmd()

    -- TODO remove ./ from result

    self.pickers.new(opts, {
        prompt_title = "Directories",
        finder = M.finders.new_oneshot_job(cmd),
        sorter = M.config.file_sorter(opts),
    }):find()
end

return M
