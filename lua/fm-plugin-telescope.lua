local fm_globals = require("fm-globals")
local Job = require('plenary.job')

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
function M:global_search(state)
    local search_dir = fm_globals.get_home_directory()
    local output = {}

    local function attach_mappings(prompt_buf_id, map)
        local actions = self.actions
        local action_state = self.action_state

        local function execute_item(opts, callback)
            local selected_dir = action_state.get_selected_entry()

            if #selected_dir == 0 then
                return
            end

            actions.close(opts)

            callback()

            local dir = selected_dir[1]

            if dir:sub(1, 1) == "/" then
                state:reload_navigation(dir)
            else
                state:reload_navigation(search_dir .. selected_dir[1])
            end

            if #state.selection == 0 and #state.buf_content ~= 0 then
                self:find_files(state)
            end
        end

        actions.select_all:replace(function() end)

        actions.select_tab:replace(function(opts)
            execute_item(opts, function()
                vim.cmd("tabnew")
                --vim.cmd('set bufhidden="hide"')
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
            table.insert(output, line)
        end,
    }):sync()

    Job:new({
        command = 'fd',
        args = { "--type", "directory", "--base-directory", search_dir, ".", ".config" },
        cwd = search_dir,
        on_stdout = function(_, line)
            table.insert(output, line)
        end,
    }):sync()

    self.pickers.new(opts, {
        prompt_title = "Directories",
        finder = self.finders.new_table({
            results = output
        }),
        sorter = self.config.file_sorter(opts),
    }):find()
end

return M
