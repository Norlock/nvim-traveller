local fm_globals = require("fm-globals")

local M = {
    navigation_ns_id = vim.api.nvim_create_namespace("Traveller"),
    popup_ns_id = vim.api.nvim_create_namespace("TravellerInfo"),
    help_ns_id = vim.api.nvim_create_namespace("TravellerHelp")
}

---@param state NavigationState | Popup
function M.add_theming(state)
    vim.opt.cursorline = true
    vim.api.nvim_create_autocmd("BufEnter", {
        buffer = state.buf_id,
        callback = function()
            vim.opt_local.cursorline = true
        end
    })

    vim.api.nvim_create_autocmd("BufHidden", {
        buffer = state.buf_id,
        callback = function()
            vim.opt_local.cursorline = false
            vim.api.nvim_win_set_hl_ns(state.win_id, 0)
        end
    })

    local cursor_line_hl = vim.api.nvim_get_hl(0, { name = 'CursorLine' })
    cursor_line_hl.bold = true

    vim.api.nvim_set_hl(M.navigation_ns_id, 'CursorLine', cursor_line_hl)
    vim.api.nvim_win_set_hl_ns(state.win_id, M.navigation_ns_id)
end

---@param state Popup
function M.add_info_popup_theming(state)
    local hlBorder = {
        link = "Question",
    }

    vim.api.nvim_set_hl(M.popup_ns_id, 'FloatBorder', hlBorder)
    vim.api.nvim_set_hl(M.popup_ns_id, 'FloatTitle', hlBorder)
    vim.api.nvim_set_hl(M.popup_ns_id, 'NormalFloat', { italic = true })

    vim.api.nvim_win_set_hl_ns(state.win_id, M.popup_ns_id)
end

---@param state Popup
function M.add_help_popup_theming(state)
    vim.api.nvim_set_hl(M.help_ns_id, 'FloatBorder', {})
    vim.api.nvim_set_hl(M.help_ns_id, 'NormalFloat', {})
    vim.api.nvim_win_set_hl_ns(state.win_id, M.help_ns_id)
end

---Themes the buffer
---@param state NavigationState
function M.theme_buffer_content(state)
    vim.api.nvim_buf_clear_namespace(state.buf_id, M.navigation_ns_id, 0, -1)

    for i, item_name in ipairs(state.buf_content) do
        if fm_globals.is_item_directory(item_name) then
            vim.api.nvim_buf_add_highlight(state.buf_id, M.navigation_ns_id, "Directory", i - 1, 0, -1)
        end

        if state:is_selected(item_name) then
            vim.api.nvim_buf_add_highlight(state.buf_id, M.navigation_ns_id, "Special", i - 1, 0, -1)
        end
    end
end

---@param state Popup
function M.theme_help_content(state)
    local function add_hl(hl_group, i, col_start, col_end)
        vim.api.nvim_buf_add_highlight(
            state.buf_id, M.help_ns_id, hl_group, i - 1, col_start, col_end
        )
    end

    local function hl_comment(i, line)
        local trim = fm_globals.trim(line)
        if string.sub(trim, 1, 2) == "--" then
            add_hl('Title', i, 0, -1)
        end
    end

    local function hl_keymap(i, line)
        local start_column = line:find('%[')
        local end_column = line:find('%]')

        if start_column ~= nil and end_column ~= nil then
            add_hl('SpecialChar', i, start_column, end_column - 1)
        end
    end

    local function hl_slash(line_idx, line)
        local columns = {}

        local slash_byte = string.byte("/")

        for i = 1, line:len(), 1 do
            local char_byte = line:byte(i)

            if slash_byte == char_byte then
                table.insert(columns, i)
            end
        end

        for _, column in ipairs(columns) do
            add_hl('@conditional', line_idx, column - 1, column)
        end
    end

    for i, line in ipairs(state.buf_content) do
        hl_comment(i, line)
        hl_keymap(i, line)
        hl_slash(i, line)
    end
end

return M
