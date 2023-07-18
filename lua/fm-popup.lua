local fm_globals = require("fm-globals")
local fmTheming = require("fm-theming")

local function popup_module_builder()
    local function create_module()
        local buf_id = vim.api.nvim_create_buf(false, true)

        -- TODO refactor similar to navigation state
        local state = {
            buf_id = buf_id,
            buf_content = {},
            is_open = false,
            buffer_options = { silent = true, buffer = buf_id }
        }

        local popup = { state = state }

        function popup.close_navigation()
            fm_globals.close_window(state)
        end

        return popup, state
    end

    local function create_info_variant()
        local popup, state = create_module()

        vim.api.nvim_create_autocmd({ "BufLeave", "BufHidden" }, {
            buffer = state.buf_id,
            callback = popup.close_navigation
        })

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

        vim.api.nvim_create_autocmd({ "BufWinLeave", "BufLeave", "BufHidden" }, {
            buffer = state.buf_id,
            callback = function()
                vim.cmd('stopinsert')
                popup.close_navigation()
            end
        })

        return popup, state
    end

    return {
        info_variant = create_info_variant,
        cmd_variant = create_cmd_variant,
    }
end

local mod_builder = popup_module_builder()

local function create_cmd_popup(dir_path, title, buf_content)
    local popup, state = mod_builder.cmd_variant()

    --TODO create fm-shell for shell commands
    function popup.create_mv_cmd(item_name, mv_cmd)
        local user_input = vim.api.nvim_buf_get_lines(state.buf_id, 0, 1, false)[1]

        if user_input == nil then
            return ""
        end

        local sh_cmd_prefix = table.concat({ "cd", dir_path, "&&", mv_cmd, fm_globals.sanitize(item_name) }, " ")

        local first_two_chars = string.sub(user_input, 1, 2)
        local first_char = string.sub(first_two_chars, 1, 1)

        -- Check for absolute path in input
        if first_char == '/' or first_two_chars == '~/' then
            local sanitize = fm_globals.sanitize(user_input)
            return sh_cmd_prefix .. " " .. sanitize
        else
            return sh_cmd_prefix .. fm_globals.sanitize(dir_path .. user_input)
        end
    end

    function popup.create_new_items_cmd()
        local user_input = vim.api.nvim_buf_get_lines(state.buf_id, 0, 1, false)
        local parts = fm_globals.split(user_input[1], " ")

        --local cmd = sh_cmd
        local touch_cmds = {}
        local mkdir_cmds = {}

        for _, item in ipairs(parts) do
            if fm_globals.is_item_directory(item) then
                table.insert(mkdir_cmds, dir_path .. item)
            else
                table.insert(touch_cmds, dir_path .. item)
            end
        end

        local mkdr_sh_cmd = "mkdir -p"
        local touch_sh_cmd = "touch"
        local has_mkdir_cmds = #mkdir_cmds ~= 0
        local has_touch_cmds = #touch_cmds ~= 0

        if has_mkdir_cmds then
            for _, item in pairs(mkdir_cmds) do
                mkdr_sh_cmd = mkdr_sh_cmd .. " " .. item
            end
        end

        if has_touch_cmds then
            for _, item in pairs(touch_cmds) do
                touch_sh_cmd = touch_sh_cmd .. " " .. item
            end
        end

        if has_mkdir_cmds then
            if has_touch_cmds then
                return mkdr_sh_cmd .. " && " .. touch_sh_cmd
            else
                return mkdr_sh_cmd
            end
        else
            return touch_sh_cmd
        end
    end

    local function init()
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

        vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, true, buf_content)

        state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_options)
        state.is_open = true;
        fmTheming.add_theming(state)
    end

    function popup.set_keymap(mode, lhs, rhs)
        vim.keymap.set(mode, lhs, rhs, state.buffer_options)
    end

    init()

    return popup
end

local M = {}

function M:create_delete_item_popup(buf_content, parent_win_id)
    return self.create_info_popup(buf_content, parent_win_id,
        'Confirm (Enter), cancel (Esc / q)')
end

function M.create_item_popup(dir_path)
    local popup = create_cmd_popup(dir_path, ' Create (separate by space) ', {})

    popup.set_keymap('i', '<Esc>', popup.close_navigation)
    vim.cmd("startinsert")

    return popup
end

function M.create_move_popup(dir_path, item_name)
    local popup = create_cmd_popup(dir_path, ' Move (mv) ', { dir_path .. item_name })

    vim.api.nvim_win_set_cursor(popup.state.win_id, { 1, #dir_path })
    popup.set_keymap('n', '<Esc>', popup.close_navigation)
    popup.set_keymap('n', 'q', popup.close_navigation)

    return popup
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

function M.create_help_popup()
    local popup, state = mod_builder.info_variant()

    local buf_content = {
        " -- Navigation",
        " ",
        " [h / <Left>]              Navigate to parent",
        " [l / <Right> / <Cr>]      Navigate to directory or open item",
        " [q / <Esc>]               Close popup / navigation",
        " [<A-.>]                   Toggle hidden or all files",
        " [~]                       Navigate to home directory",
        " ",
        " -- Commands",
        " ",
        " [t]                       Open file as tab",
        " [s]                       Open file as split",
        " [v]                       Open file as vsplit",
        " [=]                       Open terminal in tab",
        " [c]                       Create items (e.g.: test.lua lua/ lua/some_file.lua)",
        " [dd]                      Delete item",
        " [m]                       Move or rename item (e.g.: .. will move to parent)",
        " [f]                       Toggle telescope find_files inside directory",
        " [a]                       Toggle telescope live_grep inside directory",
    }

    local function init()
        local ui = vim.api.nvim_list_uis()[1]
        local width = fm_globals.round(ui.width * 0.9)
        local height = fm_globals.round(ui.height * 0.8)

        local win_options = {
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

    local function resize_window()
        popup:close_navigation()
        init()
    end

    vim.api.nvim_create_autocmd("VimResized", {
        buffer = state.buf_id,
        callback = resize_window
    })
end

return M
