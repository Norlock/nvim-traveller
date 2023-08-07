local fm_globals = require("fm-globals")
local Job = require('plenary.job')
local persist = require("persist-data")
local mod_options = {}

local M = {}

if package.loaded["telescope"] then
    M.builtin = require("telescope.builtin")
    M.pickers = require("telescope.pickers")
    M.finders = require("telescope.finders")
    M.config = require("telescope.config").values
    M.actions = require("telescope.actions")
    M.action_state = require("telescope.actions.state")
    M.themes = require("telescope.themes")
end

---@param state NavigationState
function M:find_files(state)
    if self.builtin == nil then
        return
    end

    M.builtin.find_files({ cwd = state.dir_path })
end

function M.set_mod_options(options)
    mod_options = options
end

---@param state NavigationState
function M:live_grep(state)
    if self.builtin == nil then
        return
    end

    self.builtin.live_grep({ cwd = state.dir_path })
end

---@param state NavigationState
function M:directories_search(state, show_last_used)
    local search_dir = fm_globals.get_home_directory()
    local last_used_dirs = persist.last_used_dirs()

    if #last_used_dirs == 0 then
        show_last_used = false
    end

    local all_dirs = {}

    local function get_results()
        if show_last_used then
            return last_used_dirs
        else
            return all_dirs
        end
    end

    local function attach_mappings(_, map)
        local actions = self.actions
        local action_state = self.action_state
        local mappings = mod_options.mappings or {}

        map('i', mappings.directories_tab or "<Tab>", function()
            show_last_used = not show_last_used

            self.picker:refresh(self.finders.new_table({
                results = get_results()
            }))
        end)

        map('i', mod_options.directories_delete or "<C-d>", function()
            local selected_dir = action_state.get_selected_entry()[1]

            if selected_dir == nil or not show_last_used then
                return
            end

            last_used_dirs = persist.remove(selected_dir)

            self.picker:refresh(self.finders.new_table({
                results = last_used_dirs
            }))
        end)

        local function execute_item(opts, callback)
            local selected_entry = action_state.get_selected_entry()

            if #selected_entry == 0 then
                return
            end

            actions.close(opts)

            callback()

            local selected_item = selected_entry[1]
            local dir_path = search_dir .. selected_item
            state:reload_navigation(dir_path)
            persist.store_data(selected_item)

            if #state.selection == 0 and #state.buf_content ~= 0 then
                self:find_files(state)
            end
        end

        actions.toggle_selection:replace(function() end)
        actions.select_all:replace(function() end)

        actions.select_tab:replace(function(opts)
            execute_item(opts, function()
                vim.cmd("tabnew")
                vim.bo.bufhidden = "hide"
                vim.bo.buflisted = false
            end)
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

    local opts = M.themes.get_dropdown({
        attach_mappings = attach_mappings,
    })

    Job:new({
        command = 'fd',
        args = { "--type", "directory", "--base-directory", search_dir },
        cwd = search_dir,
        on_stdout = function(_, line)
            table.insert(all_dirs, line)
        end,
    }):sync()

    Job:new({
        command = 'fd',
        args = { "--type", "directory", "--base-directory", search_dir, ".", ".config" },
        cwd = search_dir,
        on_stdout = function(_, line)
            table.insert(all_dirs, line)
        end,
    }):sync()

    self.picker = self.pickers.new(opts, {
        prompt_title = "Directories (Tab)",
        finder = self.finders.new_table({
            results = get_results()
        }),
        sorter = self.config.file_sorter(opts),
    })

    self.picker:find()
end

return M
