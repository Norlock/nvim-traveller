local fm_globals = require("fm-globals")
local fm_theming = require("fm-theming")
local Job = require('plenary.job')

local M = {}

local function init()
    if package.loaded["telescope"] then
        M.builtin = require("telescope.builtin")
        M.pickers = require("telescope.pickers")
        M.finders = require("telescope.finders")
        M.config = require("telescope.config").values
        M.actions = require("telescope.actions")
        M.action_state = require("telescope.actions.state")
        M.themes = require("telescope.themes")
        M.previewers = require("telescope.previewers")
    end

    if package.loaded["harpoon"] then
        M.harpoon = require("harpoon")
        M.harpoon_mark = require("harpoon.mark")
    end
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

local max_buffers = 20

local function sort_buffers(buffers)
    function compare(a, b)
        return a.lastused < b.lastused
    end

    table.sort(buffers, compare)

    if max_buffers < #buffers then
        local result = {}

        for i, buff in ipairs(buffers) do
            if i <= max_buffers then
                table.insert(result, buff)
            end
        end

        return result
    else
        return buffers
    end
end

local function get_harpoon_buffers(buffers)
    local harpoon_marks = M.harpoon.get_mark_config().marks

    for _, buf_info in pairs(harpoon_marks) do
        local bufnr = vim.fn.bufadd(buf_info.filename)

        if buf_info.filename ~= "" then
            table.insert(buffers, {
                -- TODO veranderen naar icon
                name = buf_info.filename,
                filename = buf_info.filename,
                display = function(entry)
                    return entry.value .. " (H)", { { { #entry.value + 1, #entry.value + 4 }, "Comment" } }
                end,
                ordinal = buf_info.filename,
                bufnr = bufnr,
                lnum = buf_info.row,
                col = buf_info.col,
                lastused = 0,
                harpoon_buffer = true,
            })
        end
    end
end

local function get_project_buffers(root)
    local buffers = {}

    if M.harpoon ~= nil then
        get_harpoon_buffers(buffers)
    end

    local function already_in_list(buf_info)
        for _, buffer in pairs(buffers) do
            if buffer.bufnr == buf_info.bufnr then
                return true
            end
        end

        return false
    end

    for _, buf_info in pairs(vim.fn.getbufinfo({ buflisted = true })) do
        local parts = vim.split(buf_info.name, root .. "/", { plain = true })

        if 1 < #parts and not already_in_list(buf_info) then
            table.insert(buffers, {
                name = buf_info.name,
                ordinal = buf_info.name,
                filename = buf_info.name,
                display = parts[2],
                bufnr = buf_info.bufnr,
                lnum = buf_info.lnum,
                col = 0,
                lastused = buf_info.lastused,
                harpoon_buffer = false,
            })
        end
    end

    return sort_buffers(buffers)
end

local function get_other_buffers(root)
    local buffers = {}

    for _, buf_info in pairs(vim.fn.getbufinfo({ buflisted = true })) do
        local parts = vim.split(buf_info.name, root .. "/", { plain = true })

        if 1 == #parts then
            table.insert(buffers, {
                name = buf_info.name,
                filename = buf_info.name,
                display = buf_info.name,
                ordinal = buf_info.name,
                bufnr = buf_info.bufnr,
                lnum = buf_info.lnum,
                lastused = buf_info.lastused,
                harpoon_buffer = false,
            })
        end
    end

    return sort_buffers(buffers)
end

local entry_maker = function(entry)
    return {
        value = entry.name,
        ordinal = entry.name,
        display = entry.display,
        filename = entry.name,
        bufnr = entry.bufnr,
        lnum = entry.lnum,
        harpoon_buffer = entry.harpoon_buffer,
    }
end

function M:list_project_buffers()
    if self.builtin == nil then
        return
    end

    local fd = vim.fn.expand('%:p:h')
    local output = fm_globals.get_git_root(fd)
    local root

    if #output == 0 then
        root = fd
    else
        root = output[1]
    end

    local show_project_buffers = true
    local picker = {}

    local define_preview = function(this, entry, _)
        local content = vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
        vim.api.nvim_buf_set_lines(this.state.bufnr, 0, -1, true, content)

        self.previewers.buffer_previewer_maker(entry.value, this.state.bufnr, {
            callback = function()
                vim.api.nvim_win_set_cursor(this.state.winid, { entry.lnum, 0 })
            end,
        })
    end

    local attach_mappings = function(promt_buf_id, map)
        local actions = self.actions
        local action_state = self.action_state

        map('i', "<C-b>", actions.preview_scrolling_up)
        map('i', "<C-f>", actions.preview_scrolling_down)
        map('i', "<C-u>", function() end)
        map('i', "<C-d>", function()
            local entry = action_state.get_selected_entry()

            if entry.harpoon_buffer then
                self.harpoon_mark.rm_file(entry.value)
            end

            actions.delete_buffer(promt_buf_id)
        end)

        map('i', "<C-h>", function()
            if not show_project_buffers then
                return
            end

            local entry = action_state.get_selected_entry()
            self.harpoon_mark.toggle_file(entry.value)

            picker:refresh(self.finders.new_table({
                results = get_project_buffers(root),
                entry_maker = entry_maker,
            }), {})
        end)

        map('i', "<tab>", function()
            show_project_buffers = not show_project_buffers
            local results;

            if show_project_buffers then
                results = get_project_buffers(root)
            else
                results = get_other_buffers(root)
            end

            picker:refresh(self.finders.new_table({
                results = results,
                entry_maker = entry_maker,
            }), {})
        end)

        return true;
    end

    local opts = {}

    picker = self.pickers.new(opts, {
        prompt_title = "Project buffers (Tab / S-Tab)",
        finder = self.finders.new_table({
            results = get_project_buffers(root),
            entry_maker = entry_maker,
        }),
        sorter = self.config.file_sorter(opts),
        previewer = self.previewers.new_buffer_previewer({
            define_preview = define_preview,
        }),
        attach_mappings = attach_mappings,
    });
    picker:find()
end

---@param state NavigationState
function M:global_search(state)
    local search_dir = fm_globals.get_home_directory()
    local output = {}

    local function attach_mappings(_, _)
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
