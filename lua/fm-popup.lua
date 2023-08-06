local fm_globals = require("fm-globals")
local fm_theming = require("fm-theming")
local fm_shell = require("fm-shell")

---@class Popup
---@field win_id integer
---@field buf_id integer
---@field buf_content string[]
---@field buffer_options table
Popup = {}

---@return Popup
function Popup:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local buf_id = vim.api.nvim_create_buf(false, true)
    o.buf_id = buf_id
    o.buf_content = {}
    o.buffer_options = { silent = true, buffer = buf_id }

    return o
end

function Popup:close()
    if vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, false)
    end
end

function Popup:set_keymap(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, self.buffer_options)
end

function Popup:set_buffer_content(buf_content)
    self.buf_content = buf_content

    vim.api.nvim_buf_set_option(self.buf_id, 'modifiable', true)
    vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, true, self.buf_content)
    vim.api.nvim_buf_set_option(self.buf_id, 'modifiable', false)
end

function Popup:init_cmd_variant(title, buf_content)
    vim.api.nvim_create_autocmd({ "BufWinLeave", "BufLeave", "BufHidden" }, {
        buffer = self.buf_id,
        callback = function()
            vim.cmd('stopinsert')
            self:close()
        end
    })

    local ui = vim.api.nvim_list_uis()[1]
    local width = fm_globals.round(ui.width * 0.6)
    local height = 1

    local win_options = {
        relative = 'editor',
        width = width,
        height = height,
        col = fm_globals.round((ui.width - width) * 0.5),
        row = fm_globals.round((ui.height - height) * 0.2),
        anchor = 'NW',
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'left',
        noautocmd = true,
    }

    vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, true, buf_content)

    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_options)
    fm_theming.add_cmd_popup_theming(self)
end

local function create_help_window_options()
    local ui = vim.api.nvim_list_uis()[1]
    local width = fm_globals.round(ui.width * 0.9)
    local height = fm_globals.round(ui.height * 0.8)

    return {
        relative = 'editor',
        width = width,
        height = height,
        col = (ui.width - width) * 0.5,
        row = (ui.height - height) * 0.2,
        anchor = 'NW',
        style = 'minimal',
        border = 'rounded',
        title = ' Help ',
        title_pos = 'center',
        noautocmd = true,
    }
end

local function create_feedback_window_options(related_win_id, title, buf_content)
    local win_width = vim.api.nvim_win_get_width(related_win_id)
    local win_height = vim.api.nvim_win_get_height(related_win_id)
    local height = #buf_content

    return {
        relative = 'win',
        win = related_win_id,
        width = win_width,
        height = height,
        row = win_height - height - 1,
        col = -1,
        anchor = 'NW',
        style = 'minimal',
        border = 'single',
        title = title,
        title_pos = "right",
        noautocmd = true,
    }
end

local function create_selection_window_options(related_win_id)
    local win_width = vim.api.nvim_win_get_width(related_win_id)
    local win_height = vim.api.nvim_win_get_height(related_win_id)
    local height = 1

    return {
        relative = 'win',
        win = related_win_id,
        width = win_width,
        height = height,
        row = win_height - height,
        col = -1,
        anchor = 'NW',
        style = 'minimal',
        border = 'none',
        noautocmd = true,
    }
end

---@param buf_content string[]
---@param win_options any
function Popup:init_info_variant(buf_content, win_options)
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        buffer = self.buf_id,
        callback = function()
            self:close()
        end
    })

    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_options)
    self.buffer_options = { silent = true, buffer = self.buf_id }

    vim.keymap.set('n', '<Esc>', function() self:close() end, self.buffer_options)
    vim.keymap.set('n', 'q', function() self:close() end, self.buffer_options)

    self:set_buffer_content(buf_content)
end

---@param buf_content string[]
---@param win_options any
function Popup:init_status_variant(buf_content, win_options)
    self.win_id = vim.api.nvim_open_win(self.buf_id, false, win_options)
    self.buffer_options = { silent = true, buffer = self.buf_id }

    vim.keymap.set('n', '<Esc>', function() self:close() end, self.buffer_options)
    vim.keymap.set('n', 'q', function() self:close() end, self.buffer_options)

    self:set_buffer_content(buf_content)
end

---@param current_location Location
---@param mv_cmd mv_cmd
---@return string
function Popup:create_mv_cmd(current_location, mv_cmd)
    local user_input = vim.api.nvim_buf_get_lines(self.buf_id, 0, 1, false)[1]
    return fm_shell.create_mv_cmd(current_location, user_input, mv_cmd)
end

---@param dir_path string
---@return string
function Popup:create_new_items_cmd(dir_path)
    local user_input = vim.api.nvim_buf_get_lines(self.buf_id, 0, 1, false)
    return fm_shell.create_new_items_cmd(dir_path, user_input)
end

---@param nav_state any
---@return string[]
local function create_selection_buf_content(nav_state)
    return { "    " .. #nav_state.selection .. " items selected: [u] undo, [pm] paste as move, "
    .. "[pc] paste as copy)" }
end
---updates text for popups with
---@param nav_state NavigationState
function Popup:update_status_text(nav_state)
    local buf_content = create_selection_buf_content(nav_state)
    self:set_buffer_content(buf_content)
end

local M = {}

---@param parent_win_id integer
---@param buf_content string[]
---@return Popup
function M.create_delete_item_popup(parent_win_id, buf_content)
    local popup = Popup:new()

    local title = 'Confirm (Enter), cancel (Esc / q)'
    local window_options = create_feedback_window_options(parent_win_id, title, buf_content)
    popup:init_info_variant(buf_content, window_options)

    fm_theming.add_info_popup_theming(popup)

    return popup
end

function M.create_items_popup()
    local popup = Popup:new()
    popup:init_cmd_variant(' Create (separate by space) ', {})

    popup:set_keymap('i', '<Esc>', function() popup:close() end)
    vim.cmd("startinsert")

    return popup
end

---comment
---@param location Location
---@return Popup
function M.create_move_popup(location)
    local popup = Popup:new()
    popup:init_cmd_variant(' Move (mv) ', { location.dir_path .. location.item_name })

    vim.api.nvim_win_set_cursor(popup.win_id, { 1, #location.dir_path })
    popup:set_keymap('n', '<Esc>', function() popup:close() end)
    popup:set_keymap('n', '<Esc>', function() popup:close() end)

    return popup
end

---@param nav_state NavigationState
function M.create_selection_popup(nav_state)
    local popup = Popup:new()

    local buf_content = create_selection_buf_content(nav_state)
    local window_opts = create_selection_window_options(nav_state.win_id)

    popup:init_status_variant(buf_content, window_opts)
    fm_theming.add_status_popup_theming(popup)

    return popup
end

function M.create_help_popup()
    local popup = Popup:new()

    local buf_content = {
        " -- Navigation",
        " [h / <Left>]              Navigate to parent",
        " [l / <Right> / <Cr>]      Navigate to directory or open item",
        " [q / <Esc>]               Close popup / navigation",
        " [.]                       Toggle hidden or all files",
        " [gh]                      Navigate to the home directory",
        " [g/]                      Navigate to the root directory",
        " ",
        " -- Commands",
        " [t]                       Open file as tab",
        " [s]                       Open file as split",
        " [v]                       Open file as vsplit",
        " [os]                      Open terminal in Neovim",
        " [ot]                      Open terminal (using $TERM)",
        " [c]                       Create items (e.g.: test.lua lua/ lua/some_file.lua)",
        " [dd]                      Delete item / Delete selection",
        " [m]                       Move or rename item (e.g.: .. will move to parent)",
        " [f]                       Toggle telescope find_files inside directory",
        " [a]                       Toggle telescope live_grep inside directory",
        " ",
        " -- Selection",
        " [y]                       Yank item (add / remove to selection)",
        " [pm]                      Paste as move",
        " [pc]                      Paste as copy",
        " [u]                       Undo selection",
        " ",
        " -- Telescope search directory",
        " [<Cr> / t / v / s]        Open directory in traveller",
        " [<Tab>]                   Toggle all directories / last used ones",
        " [<C-d>]                   Remove directory from the last used list",
    }

    local function init()
        local window_options = create_help_window_options()
        popup:init_info_variant(buf_content, window_options)
        fm_theming.add_help_popup_theming(popup)
        fm_theming.theme_help_content(popup)
    end

    init()

    vim.api.nvim_create_autocmd("VimResized", {
        buffer = popup.buf_id,
        callback = function()
            popup:close()
            init()
        end
    })
end

return M
