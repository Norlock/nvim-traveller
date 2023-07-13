local fmGlobals = require("fm-globals")
local fmTheming = require("fm-theming")

local function popup_module_builder()
    local function create_module()
        local buf_id = vim.api.nvim_create_buf(false, true)

        local state = {
            buf_id = buf_id,
            buf_content = {},
            is_open = false,
            buffer_options = { silent = true, buffer = buf_id }
        }

        local popup = { state }

        return popup, state
    end

    local function create_info_variant()
        local popup, state = create_module()

        vim.api.nvim_create_autocmd({"BufWinLeave", "BufLeave", "BufHidden"}, {
            buffer = state.buf_id,
            callback = function ()
                state.is_open = false
                vim.api.nvim_win_close(state.win_id, false)
            end
        })

        function popup.close_navigation()
            vim.api.nvim_win_close(state.win_id, false)
        end

        function popup.set_buffer_content(buf_content)
            state.buf_content = buf_content

            vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', true)
            vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, true, state.buf_content)
            vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', false)
        end

        return popup, state
    end

    local function create_cmd_variant()
        local popup, state = create_module()

        vim.api.nvim_create_autocmd({"BufWinLeave", "BufLeave", "BufHidden"}, {
            buffer = state.buf_id,
            callback = function ()
                state.is_open = false
                vim.cmd('stopinsert')
                vim.api.nvim_win_close(state.win_id, false)
            end
        })

        function popup.close_navigation()
            vim.api.nvim_win_close(state.win_id, false)
        end

        return popup, state
    end

    return {
        info_variant = create_info_variant,
        cmd_variant = create_cmd_variant,
    }
end

local mod_builder = popup_module_builder()

local function create_cmd_popup(dir_path, title)
    local popup, state = mod_builder.cmd_variant()

    function popup.create_rename_cmd(filename)
        local user_input = fmGlobals.trim(
            vim.api.nvim_buf_get_lines(state.buf_id, 0, 1, false)[1]
        )

        if user_input == "" then
            return ""
        end

        local old_filepath = dir_path .. filename

        local first_two_chars = string.sub(user_input, 1, 2)
        local first_char = string.sub(first_two_chars, 1, 1)
        if first_char == '/' or first_two_chars == '~/' then -- Absolute path
            return "mv " .. old_filepath .. " " .. user_input
        end

        local new_filepath = dir_path .. user_input
        return "mv " .. old_filepath .. " " .. new_filepath
    end

    function popup.create_sh_cmd(sh_cmd)
        local user_input = vim.api.nvim_buf_get_lines(state.buf_id, 0, 1, false)
        local parts = fmGlobals.split(user_input[1], " ")

        local cmd = sh_cmd

        for _, item in ipairs(parts) do
            cmd = cmd .. " " .. dir_path .. item
        end

        return cmd
    end

    local function init()
        local ui = vim.api.nvim_list_uis()[1]
        local width = fmGlobals.round(ui.width * 0.6)
        local height = 1

        local win_options = {
            relative = 'editor',
            width = width,
            height = height,
            col = (ui.width - width) * 0.5,
            row = (ui.height - height) * 0.2,
            anchor = 'NW',
            style = 'minimal',
            border = 'rounded',
            title = title,
            title_pos = 'left',
            noautocmd = true,
        }

        state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_options)
        state.is_open = true;
        fmTheming.add_theming(state)

        vim.keymap.set('i', '<Esc>', popup.close_navigation, state.buffer_options)

        vim.cmd('startinsert')
    end

    function popup.set_keymap(lhs, rhs)
        vim.keymap.set('i', lhs, rhs, state.buffer_options)
    end

    init()

    return popup
end

local M = {}

function M.create_delete_item_popup(buf_content, parent_win_id)
    return M.create_info_popup(buf_content, parent_win_id,
        'Confirm (Enter), cancel (Esc / q)')
end

function M.create_file_popup(dir_path)
    return create_cmd_popup(dir_path, ' Touch (separate by space) ')
end

function M.create_dir_popup(dir_path)
    return create_cmd_popup(dir_path, ' Mkdir (separate by space) ')
end

function M.create_move_popup(dir_path)
    return create_cmd_popup(dir_path, ' Move (mv) ')
end

function M.create_info_popup(buf_content, related_win_id, title)
    local popup, state = mod_builder.info_variant()

    local function init()
        local win_width = vim.api.nvim_win_get_width(related_win_id)
        local win_height = vim.api.nvim_win_get_height(related_win_id)
        local height = #buf_content

        local win_options = {
            relative = 'win',
            win = related_win_id,
            width = win_width,
            height = height,
            row = win_height - height - 1,
            col = -1,
            anchor = 'NW',
            style = 'minimal',
            border = 'single',
            title = ' ' .. title .. ' ',
            title_pos = "right",
            noautocmd = true,
        }

        state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_options)
        state.is_open = true;
        state.buffer_options = { silent = true, buffer = state.buf_id }

        vim.keymap.set('n', '<Esc>', popup.close_navigation, state.buffer_options)
        vim.keymap.set('n', 'q', popup.close_navigation, state.buffer_options)

        popup.set_buffer_content(buf_content)

        fmTheming.add_info_popup_theming(state)
    end

    function popup.set_keymap(lhs, rhs)
        vim.keymap.set('n', lhs, rhs, state.buffer_options)
    end

    init()

    return popup
end

function M.create_help_popup(related_win_id)
    local popup, state = mod_builder.info_variant()

    local buf_content = {
        " -- Navigation",
        " ",
        " [h / <Left>]              Navigate to parent",
        " [l / <Right> / <Cr>]      Navigate to directory or open item",
        " [q / <Esc>]               Close popup",
        " ",
        " -- Commands",
        " ",
        " [t]                       Open file as tab",
        " [s]                       Open file as split",
        " [v]                       Open file as vsplit",
        " [=]                       Open terminal in tab",
        " [cf]                      Create file (e.g.: test.lua test2.lua)",
        " [cd]                      Create directory (e.g.: css js public",
        " [dd]                      Delete item",
        " [m]                       Move or rename item (e.g.: .. will move to parent)",
    }

    local function init()
        local win_width = vim.api.nvim_win_get_width(related_win_id)
        local win_height = vim.api.nvim_win_get_height(related_win_id)

        local win_options = {
            relative = 'win',
            win = related_win_id,
            width = win_width,
            height = win_height,
            row = 0,
            col = 0,
            anchor = 'NW',
            style = 'minimal',
            --border = 'solid',
            --title = "test",
            noautocmd = true,
        }

        state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_options)
        state.is_open = true;
        state.buffer_options = { silent = true, buffer = state.buf_id }

        vim.keymap.set('n', '<Esc>', popup.close_navigation, state.buffer_options)
        vim.keymap.set('n', 'q', popup.close_navigation, state.buffer_options)

        fmTheming.add_help_popup_theming(state)

        popup.set_buffer_content(buf_content)

        fmTheming.theme_help_content(state)
    end

    init()
end

return M