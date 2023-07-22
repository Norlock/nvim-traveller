local fm_globals = require("fm-globals")
local fm_theming = require("fm-theming")
local fm_popup = require("fm-popup")
local fm_telescope = require("fm-plugin-telescope")
local fm_shell = require("fm-shell")

local path = require("plenary.path")
local Location = require("fm-location")

local item_cmd = {
    open = 'e',
    openTab = 'tabe',
    vSplit = 'vsplit',
    hSplit = 'split',
}

---@type ModOptions
local mod_options

---@class NavigationState
---@field win_id number
---@field buf_id number
---@field dir_path string
---@field show_hidden boolean
---@field is_initialized boolean
---@field history Location[]
---@field selection Location[]
---@field buf_content table
local NavigationState = {
    is_initialized = false
}

---Create new navigation state
---@param options any
---@return NavigationState
function NavigationState:new(options)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o:init(options)

    return o
end

---@param opts ModOptions
function NavigationState:set_mod_options(opts)
    mod_options = opts
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

    self.dir_path = options.dir_path or get_dir_path()
    self.win_id = vim.api.nvim_get_current_win()
    self.buf_id = vim.api.nvim_create_buf(false, true)
    self.show_hidden = self.show_hidden or mod_options.show_hidden
    self.is_initialized = true
    self.history = {}
    self.selection = options.selection or {}
    self.buf_content = {}

    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = self.buf_id,
        callback = function()
            self:close_status_popup()
        end
    })
end

function NavigationState:toggle_hidden()
    self.show_hidden = not self.show_hidden
    self:reload_buffer()
end

function NavigationState:get_current_location()
    local item_name = self:get_cursor_item()
    return Location:new(self.dir_path, item_name)
end

function NavigationState:get_relative_path()
    local rel = path:new(self.dir_path):make_relative()

    if fm_globals.is_item_directory(rel) then
        return rel
    else
        return rel .. "/"
    end
end

function NavigationState:get_absolute_path()
    local abs = path:new(self.dir_path):absolute()

    if fm_globals.is_item_directory(abs) then
        return abs
    else
        return abs .. "/"
    end
end

function NavigationState:paste_selection(copy)
    local sh_cmds
    if copy then
        sh_cmds = fm_shell.create_cp_cmds_selection(self)
    else
        sh_cmds = fm_shell.create_mv_cmds_selection(self)
    end

    fm_globals.debug(sh_cmds)
    local errors = {}

    for _, cmd in pairs(sh_cmds) do
        local output = vim.fn.systemlist(cmd)
        if #output ~= 0 then
            fm_globals.concat_table(errors, output)
        end
    end

    self:undo_selection()
    self:reload_buffer()

    if #errors ~= 0 then
        fm_globals.debug(errors)
        fm_popup.create_info_popup(errors, self.win_id, 'Command failed (Esc / q)')
    end
end

function NavigationState:close_status_popup()
    if self.status_popup then
        self.status_popup:close()
        self.status_popup = nil;
    end
end

function NavigationState:init_status_popup()
    local has_selection = #self.selection ~= 0

    if self.status_popup then
        if has_selection then
            self.status_popup:update_status_text(self)
        else
            self:close_status_popup()
        end
    elseif has_selection then
        self.status_popup = fm_popup.create_selection_popup(self)
    end
end

function NavigationState:add_to_selection()
    local event = self:get_current_location()
    local selection_index = self:get_selection_index(event.item_name)

    if selection_index == -1 then
        table.insert(self.selection, event)
    else
        table.remove(self.selection, selection_index)
    end

    fm_theming.theme_buffer_content(self)
    self:init_status_popup()
end

function NavigationState:undo_selection()
    self.selection = {}
    fm_theming.theme_buffer_content(self)
    self:close_status_popup()
end

---Checks if in selection
---@param item_name string
---@return boolean
function NavigationState:is_selected(item_name)
    return self:get_selection_index(item_name) ~= -1
end

---Checks if in selection
---@param item_name string
---@return number
function NavigationState:get_selection_index(item_name)
    for i, location in ipairs(self.selection) do
        if location.dir_path == self.dir_path and location.item_name == item_name then
            return i
        end
    end
    return -1
end

function NavigationState:close_navigation()
    if self.buf_id == vim.api.nvim_get_current_buf() then
        self:close_status_popup()
        vim.api.nvim_buf_delete(self.buf_id, {})
    end
end

---@return string
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

        return vim.fn.systemlist(get_cmd_prefix() .. new_dir_path)
    end

    self.dir_path = new_dir_path

    if mod_options.sync_cwd then
        vim.cmd("cd " .. self.dir_path)
    end

    self.buf_content = get_buffer_content()

    vim.api.nvim_buf_set_option(self.buf_id, 'modifiable', true)

    if #self.buf_content == 0 then
        -- TODO empty directory feedback
        --local ns_id = vim.api.nvim_create_namespace('demo')
        --vim.api.nvim_buf_set_extmark(self.buf_id, ns_id, 0, 0, {
            --id = 5,
            --virt_text = {{"demo", "IncSearch"}},
            --virt_text_win_col = 0,
        --})
    end
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
    if not fm_globals.is_item_directory(dir_path) then
        dir_path = dir_path .. "/"
    end

    self:init({ dir_path = dir_path, selection = self.selection })
    self:open_navigation()
end

function NavigationState:navigate_to_parent()
    if self.dir_path == "/" then
        return
    end

    local function get_parent_location()
        local parts = fm_globals.split(self.dir_path, "/")
        local item_name = table.remove(parts, #parts)

        local dir_path = "/"
        for _, value in ipairs(parts) do
            dir_path = dir_path .. value .. "/"
        end

        return Location:new(dir_path, item_name .. "/")
    end

    local function get_history_index(cmp_path)
        for i, event in ipairs(self.history) do
            if event.dir_path == cmp_path then
                return i
            end
        end
        return -1
    end

    local function update_history_location(event)
        local his_index = get_history_index(event.dir_path)

        if his_index == -1 then
            table.insert(self.history, event)
        else
            self.history[his_index].item_name = event.item_name
        end
    end

    local current_location = self:get_current_location()
    local parent_location = get_parent_location()

    update_history_location(current_location)
    update_history_location(parent_location)

    self:set_buffer_content(parent_location.dir_path)
end

function NavigationState:open_navigation()
    local function action_on_item(cmd_str)
        local item = self:get_cursor_item()

        if item == nil then
            return
        end


        if fm_globals.is_item_directory(item) then
            if cmd_str == item_cmd.open then
                self:set_buffer_content(self.dir_path .. item)
            end
        else
            local abs_path = path:new(self.dir_path .. item):absolute()

            if fm_shell.is_file_binary(abs_path) then
                vim.fn.jobstart("open " .. abs_path, { detach = true })
            else
                local file_rel = path:new(self.dir_path .. item):make_relative()
                vim.cmd(cmd_str .. ' ' .. file_rel)
            end
        end
    end

    -- Needs to happen here before new buffer gets loaded
    local fn = vim.fn.expand('%:t')

    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)

    --vim.cmd("file! Traveller (help: ?)") TODO fix

    fm_theming.add_navigation_theming(self)
    self:init_status_popup()

    local buffer_options = { silent = true, buffer = self.buf_id }

    ---@param popup Popup
    ---@param sh_cmd string
    local function confirm_callback(popup, sh_cmd)
        local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)
        self:reload_buffer()
        popup:close()

        if #output ~= 0 then
            fm_globals.debug(output)
            fm_popup.create_info_popup(output, self.win_id, 'Command failed (Esc / q)')
        end
    end

    local function create_items_popup()
        local popup = fm_popup.create_items_popup()

        local function confirm_mkdir_callback()
            confirm_callback(popup, popup:create_new_items_cmd(self.dir_path))
        end

        popup:set_keymap('i', '<Cr>', confirm_mkdir_callback)
    end

    local function create_move_popup()
        local current_location = self:get_current_location()
        local popup = fm_popup.create_move_popup(current_location)

        local function confirm_move_callback()
            -- Tries git mv first, if fails fallsback to mv.
            local sh_cmd = popup:create_mv_cmd(current_location, "git mv")
            local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)

            if #output ~= 0 then
                fm_globals.debug(output)
                confirm_callback(popup, popup:create_mv_cmd(current_location, "mv"))
            else
                self:reload_buffer()
                popup:close()
            end
        end

        popup:set_keymap('i', '<Cr>', confirm_move_callback)
        popup:set_keymap('n', '<Cr>', confirm_move_callback)
    end

    local function delete_item()
        local sh_cmds = fm_shell.create_rm_cmds(self)
        local popup = fm_popup.create_delete_item_popup(self.win_id, sh_cmds)

        local function confirm_delete_callback()
            local errors = {}

            for _, sh_cmd in pairs(sh_cmds) do
                local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)

                if #output ~= 0 then
                    fm_globals.concat_table(errors, output)
                end
            end

            self:undo_selection()
            self:reload_buffer()
            popup:close()

            if #errors ~= 0 then
                fm_globals.debug(errors)
                fm_popup.create_info_popup(errors, self.win_id, 'Command failed (Esc / q)')
            end
        end

        popup:set_keymap('n', '<Cr>', confirm_delete_callback)
    end

    local function navigate_to_home_directory()
        self:set_buffer_content(vim.fn.expand('$HOME') .. "/")
    end

    vim.keymap.set('n', 'q', function() self:close_navigation() end, buffer_options)
    vim.keymap.set('n', '<Esc>', function() self:close_navigation() end, buffer_options)
    vim.keymap.set('n', '<Right>', function() action_on_item(item_cmd.open) end, buffer_options)
    vim.keymap.set('n', 'l', function() action_on_item(item_cmd.open) end, buffer_options)
    vim.keymap.set('n', '<Cr>', function() action_on_item(item_cmd.open) end, buffer_options)
    vim.keymap.set('n', 'v', function() action_on_item(item_cmd.vSplit) end, buffer_options)
    vim.keymap.set('n', 's', function() action_on_item(item_cmd.hSplit) end, buffer_options)
    vim.keymap.set('n', 't', function() action_on_item(item_cmd.openTab) end, buffer_options)

    vim.keymap.set('n', 'ot', function()
        fm_shell.open_terminal(self:get_absolute_path())
    end, buffer_options)

    vim.keymap.set('n', 'os', function()
        fm_shell.open_shell(self:get_relative_path())
    end, buffer_options)

    vim.keymap.set('n', 'c', create_items_popup, buffer_options)
    vim.keymap.set('n', 'm', create_move_popup, buffer_options)
    vim.keymap.set('n', 'dd', delete_item, buffer_options)
    vim.keymap.set('n', '<F1>', "", buffer_options)
    vim.keymap.set('n', '<Left>', function() self:navigate_to_parent() end, buffer_options)
    vim.keymap.set('n', 'h', function() self:navigate_to_parent() end, buffer_options)
    vim.keymap.set('n', '?', function() fm_popup.create_help_popup() end, buffer_options)
    vim.keymap.set('n', '<A-.>', function() self:toggle_hidden() end, buffer_options)
    vim.keymap.set('n', 'y', function() self:add_to_selection() end, buffer_options)
    vim.keymap.set('n', 'u', function() self:undo_selection() end, buffer_options)
    vim.keymap.set('n', 'pm', function() self:paste_selection(false) end, buffer_options)
    vim.keymap.set('n', 'pc', function() self:paste_selection(true) end, buffer_options)
    vim.keymap.set('n', '~', navigate_to_home_directory, buffer_options)

    -- Plugin integration
    vim.keymap.set('n', 'f', function() fm_telescope:find_files(self) end, buffer_options)
    vim.keymap.set('n', 'a', function() fm_telescope:live_grep(self) end, buffer_options)

    if fn ~= "" then
        table.insert(self.history, Location:new(self.dir_path, fn))
    end

    self:reload_buffer()
end

return NavigationState
