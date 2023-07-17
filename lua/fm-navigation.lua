local fm_globals = require("fm-globals")
local fm_theming = require("fm-theming")
local fm_popup = require("fm-popup")
local fm_telescope = require("fm-plugin-telescope")
local path = require("plenary.path")

local function create_event(dir_path, item_name)
    return {
        dir_path = dir_path,
        item_name = item_name,
    }
end

---@class NavigationState
---@field win_id number
---@field parent_buf_id number
---@field buf_id number
---@field dir_path string
---@field show_hidden boolean
---@field is_initialized boolean
---@field history table
---@field buf_content table
local NavigationState = {
    is_initialized = false
}

---comment
---@param options any
---@return NavigationState
function NavigationState:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o:init(options)

    return o
end

function NavigationState:init(options)
    local function get_dir_path()
        local fd = vim.fn.expand('%:p:h')
        if vim.fn.isdirectory(fd) == 1 then
            return fd .. "/"
        else
            return vim.fn.expand('$HOME') .. "/"
        end
    end

    options = options or {}

    self.parent_buf_id = options.parent_buf_id or vim.api.nvim_get_current_buf()
    self.dir_path = options.dir_path or get_dir_path()
    self.win_id = vim.api.nvim_get_current_win()
    self.buf_id = vim.api.nvim_create_buf(false, true)
    self.show_hidden = true
    self.is_open = false
    self.is_initialized = true
    self.history = {}
    self.buf_content = {}
end

function NavigationState:create_help_popup()
    fm_popup.create_help_popup(self.win_id)
end

function NavigationState:toggle_hidden()
    self.show_hidden = not self.show_hidden
    self:reload_buffer()
end

function NavigationState:close_navigation()
    local parent_buffer_file = vim.api.nvim_buf_get_name(self.parent_buf_id)
    fm_globals.debug(parent_buffer_file)
    if parent_buffer_file ~= ""  then
        vim.api.nvim_set_current_buf(self.parent_buf_id)
    end
end

function NavigationState:get_cursor_item()
    local cursor = vim.api.nvim_win_get_cursor(self.win_id)
    return self.buf_content[cursor[1]]
end

function NavigationState:set_buffer_content(new_dir_path)
    assert(fm_globals.is_item_directory(new_dir_path), "Passed path is not a directory")

    local function get_buffer_content()
        local function get_cmd_prefix()
            if self.show_hidden then
                return "ls -pAL "
            else
                return "ls -pL "
            end
        end
        local buf_content = {}

        for item in io.popen(get_cmd_prefix() .. new_dir_path):lines() do
            table.insert(buf_content, item)
        end

        return buf_content
    end

    self.dir_path = new_dir_path
    self.buf_content = get_buffer_content()

    vim.api.nvim_buf_set_option(self.buf_id, 'modifiable', true)
    vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, true, self.buf_content)
    vim.api.nvim_buf_set_option(self.buf_id, 'modifiable', false)

    fm_theming.theme_buffer_content(self)


    local function set_window_cursor()
        for i, buf_item in ipairs(self.buf_content) do
            for _, event in ipairs(self.history) do
                if self.dir_path == event.dir_path and buf_item == event.item_name then
                    vim.api.nvim_win_set_cursor(self.win_id, { i, 0 })
                    return
                end
            end
        end
        vim.api.nvim_win_set_cursor(self.win_id, { 1, 0 })
    end

    set_window_cursor()

    vim.cmd("nohlsearch")
end

function NavigationState:reload_buffer()
    self:set_buffer_content(self.dir_path)
end

---@param self NavigationState
---@param dir_path string
function NavigationState:reload_navigation(dir_path)
    self:init({dir_path = dir_path, parent_buf_id = self.parent_buf_id })
    self:open_navigation()
end

function NavigationState:navigate_to_parent()
    if self.dir_path == "/" then
        return
    end

    local function get_current_event()
        local item_name = self:get_cursor_item()
        return create_event(self.dir_path, item_name)
    end

    local function get_parent_event()
        local parts = fm_globals.split(self.dir_path, "/")
        local item_name = table.remove(parts, #parts)

        local dir_path = "/"
        for _, value in ipairs(parts) do
            dir_path = dir_path .. value .. "/"
        end

        return create_event(dir_path, item_name .. "/")
    end

    local function get_history_index(cmp_path)
        for i, event in ipairs(self.history) do
            if event.dir_path == cmp_path then
                return i
            end
        end
        return -1
    end

    local function update_history_event(event)
        local his_index = get_history_index(event.dir_path)

        if his_index == -1 then
            table.insert(self.history, event)
        else
            self.history[his_index].item_name = event.item_name
        end
    end

    local current_event = get_current_event()
    local parent_event = get_parent_event()

    update_history_event(current_event)
    update_history_event(parent_event)

    self:set_buffer_content(parent_event.dir_path)
end

function NavigationState:open_navigation()
    vim.api.nvim_create_autocmd("BufEnter", {
        buffer = self.parent_buf_id,
        callback = function()
            self:close_navigation()
        end
    })

    local cmd = {
        open = 'e',
        openTab = 'tabe',
        vSplit = 'vsplit',
        hSplit = 'split',
    }

    local function action_on_item(cmd_str)
        local item = self:get_cursor_item()

        if fm_globals.is_item_directory(item) then
            if cmd_str == cmd.open then
                self:set_buffer_content(self.dir_path .. item)
            end
        else
            local file_rel = path:new(self.dir_path .. item):make_relative()
            self:close_navigation()
            vim.cmd(cmd_str .. ' ' .. file_rel)
        end
    end

    local function get_relative_path()
        local rel = path:new(self.dir_path):make_relative()

        if fm_globals.is_item_directory(rel) then
            return rel
        else
            return rel .. "/"
        end
    end

    local function get_absolute_path()
        local abs = path:new(self.dir_path):absolute()

        if fm_globals.is_item_directory(abs) then
            return abs
        else
            return abs .. "/"
        end
    end


    local function open_terminal()
        local dir_path = get_relative_path()

        local sh_cmd = ":terminal"
        vim.cmd("tabe")
        vim.cmd(sh_cmd .. " cd " .. dir_path .. " && $SHELL")
        vim.cmd("startinsert")
    end

    -- Needs to happen here before new buffer gets loaded
    local fn = vim.fn.expand('%:t')

    self.win_id = vim.api.nvim_get_current_win()

    vim.api.nvim_set_current_buf(self.buf_id)

    vim.api.nvim_win_set_option(self.win_id, 'relativenumber', true)
    fm_theming.add_theming(self)

    local buffer_options = { silent = true, buffer = self.buf_id }

    local function confirm_callback(popup, sh_cmd)
        fm_globals.debug('mv cmd: ' .. sh_cmd)
        local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)
        self:reload_buffer()
        popup.close_navigation()

        if #output ~= 0 then
            fm_globals.debug(output)
            fm_popup.create_info_popup(output, self.win_id, 'Command failed (Esc / q)')
        end
    end

    local function create_item_popup()
        local popup = fm_popup.create_item_popup(get_relative_path())

        local function confirm_mkdir_callback()
            confirm_callback(popup, popup.create_new_items_cmd())
        end

        popup.set_keymap('i', '<Cr>', confirm_mkdir_callback)
    end

    local function create_move_popup()
        local item_name = self:get_cursor_item()
        local popup = fm_popup.create_move_popup(get_absolute_path(), item_name)

        local function confirm_move_callback()
            -- Tries git mv first, if fails fallsback to mv.
            local sh_cmd = popup.create_mv_cmd(item_name, "git mv")
            local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)

            if #output ~= 0 then
                fm_globals.debug(output)
                confirm_callback(popup, popup.create_mv_cmd(item_name, "mv"))
            else
                self:reload_buffer()
                popup.close_navigation()
            end
        end

        popup.set_keymap('i', '<Cr>', confirm_move_callback)
        popup.set_keymap('n', '<Cr>', confirm_move_callback)
    end

    local function delete_item()
        local dir_path = get_relative_path()
        local item_name = self:get_cursor_item()

        local function create_sh_cmd()
            local function get_rm_cmd()
                if fm_globals.item_is_part_of_git_repo(dir_path, item_name) then
                    return "cd " .. dir_path .. " && git rm", fm_globals.sanitize(item_name)
                else
                    return "rm", fm_globals.sanitize(dir_path .. item_name)
                end
            end

            local rm_prefix, rm_suffix = get_rm_cmd()

            if fm_globals.is_item_directory(item_name) then
                return rm_prefix .. " -rf " .. rm_suffix
            else
                return rm_prefix .. " " .. rm_suffix
            end
        end

        local sh_cmd = create_sh_cmd()
        fm_globals.debug("delete: " .. sh_cmd)

        local popup = fm_popup.create_delete_item_popup({ sh_cmd }, self.win_id)

        local function confirm_delete_callback()
            confirm_callback(popup, sh_cmd)
        end

        popup.set_keymap('<Cr>', confirm_delete_callback)
    end

    local function navigate_to_home_directory()
        self:set_buffer_content(vim.fn.expand('$HOME') .. "/")
    end

    vim.keymap.set('n', 'q', function() self:close_navigation() end, buffer_options)
    vim.keymap.set('n', '<Esc>', function() self:close_navigation() end, buffer_options)
    vim.keymap.set('n', '<Right>', function() action_on_item(cmd.open) end, buffer_options)
    vim.keymap.set('n', 'l', function() action_on_item(cmd.open) end, buffer_options)
    vim.keymap.set('n', '<Cr>', function() action_on_item(cmd.open) end, buffer_options)
    vim.keymap.set('n', 'v', function() action_on_item(cmd.vSplit) end, buffer_options)
    vim.keymap.set('n', 's', function() action_on_item(cmd.hSplit) end, buffer_options)
    vim.keymap.set('n', 't', function() action_on_item(cmd.openTab) end, buffer_options)
    vim.keymap.set('n', '=', open_terminal, buffer_options)
    vim.keymap.set('n', 'c', create_item_popup, buffer_options)
    vim.keymap.set('n', 'm', create_move_popup, buffer_options)
    vim.keymap.set('n', 'd', delete_item, buffer_options)
    vim.keymap.set('n', '<F1>', "", buffer_options)
    vim.keymap.set('n', '<Left>', function() self:navigate_to_parent() end, buffer_options)
    vim.keymap.set('n', 'h', function() self:navigate_to_parent() end, buffer_options)
    vim.keymap.set('n', '?', function() self:create_help_popup() end, buffer_options)
    vim.keymap.set('n', '<A-.>', function() self:toggle_hidden() end, buffer_options)
    vim.keymap.set('n', '~', navigate_to_home_directory, buffer_options)

    -- Plugin integration
    vim.keymap.set('n', 'ff', function() fm_telescope.find_files(self) end, buffer_options)
    vim.keymap.set('n', 'fg', function() fm_telescope.live_grep(self) end, buffer_options)
    vim.keymap.set('n', 'fd', function()
        fm_telescope.global_search(self)
    end, buffer_options)

    if fn ~= "" then
        table.insert(self.history, create_event(self.dir_path, fn))
    end

    self:reload_buffer()
end

return NavigationState
