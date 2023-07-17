local fmGlobals = require("fm-globals")

local theming = {
    ns_id = vim.api.nvim_create_namespace("FmTheming"),
    popup_ns_id = vim.api.nvim_create_namespace("FmInfoTheming"),
    help_ns_id = vim.api.nvim_create_namespace("FmHelpTheming")
}

function theming.add_theming(state)
    vim.opt_local.cursorline = true

    vim.api.nvim_set_hl(theming.ns_id, 'Normal', {})
    vim.api.nvim_set_hl(theming.ns_id, 'FloatBorder', {})
    vim.api.nvim_set_hl(theming.ns_id, 'CursorLine', { bold = true })

    vim.api.nvim_win_set_hl_ns(state.win_id, theming.ns_id)
end

function theming.add_info_popup_theming(state)
    local hlBorder = {
        link = "Question",
    }

    vim.api.nvim_set_hl(theming.popup_ns_id, 'FloatBorder', hlBorder)
    vim.api.nvim_set_hl(theming.popup_ns_id, 'FloatTitle', hlBorder)
    vim.api.nvim_set_hl(theming.popup_ns_id, 'NormalFloat', { italic = true })

    vim.api.nvim_win_set_hl_ns(state.win_id, theming.popup_ns_id)
end

function theming.add_help_popup_theming(state)
    vim.api.nvim_set_hl(theming.help_ns_id, 'FloatBorder', {})
    vim.api.nvim_set_hl(theming.help_ns_id, 'NormalFloat', {})
    vim.api.nvim_win_set_hl_ns(state.win_id, theming.help_ns_id)
end

function theming.theme_buffer_content(state)
    for i, buf_dir_name in ipairs(state.buf_content) do
        if fmGlobals.is_item_directory(buf_dir_name) then
            vim.api.nvim_buf_add_highlight(state.buf_id, theming.ns_id, "Directory", i - 1, 0, -1)
        end
    end
end

function theming.theme_help_content(state)
    local function add_hl(hl_group, i, col_start, col_end)
        vim.api.nvim_buf_add_highlight(
            state.buf_id, theming.help_ns_id, hl_group, i - 1, col_start, col_end
        )
    end

    local function hl_comment(i, line)
        local trim = fmGlobals.trim(line)
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

return theming
