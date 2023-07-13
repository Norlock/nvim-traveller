local fmTheming = require("fm-theming")
local fmGlobals = require("fm-globals")
local fmPopup = require("fm-popup")
local path = require("plenary.path")

local function get_buffer_content(dir_path)
    local buf_content = {}

    for item in io.popen("ls -pA " .. dir_path):lines() do
        table.insert(buf_content, item)
    end

    return buf_content
end

local function create_event(dir_path, item_name)
    return {
        dir_path = dir_path,
        item_name = item_name,
    }
end

local function get_cursor_item(state)
    local cursor = vim.api.nvim_win_get_cursor(state.win_id)
    return state.buf_content[cursor[1]]
end

local M = {
    state = {
        is_open = false,
        history = {},
    }
}

function M.create_new_state()
    M.state = {
        buf_id = vim.api.nvim_create_buf(false, true),
        is_open = false,
        history = {},
    }

    return M.state
end

-- Opens the navigation
function M.open_navigation()
    if M.state.is_open then
        return
    end

    local state = M.create_new_state();

    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = state.buf_id,
        callback = function()
            state.is_open = false
            vim.api.nvim_win_close(state.win_id, false)
        end
    })

    local cmd = {
        open = 'e',
        openTab = 'tabe',
        vSplit = 'vsplit',
        hSplit = 'split',
    }

    local function close_navigation()
        if state.is_open then
            vim.api.nvim_win_close(state.win_id, false)
            --state.is_open = false
        end
    end

    local function set_window_cursor()
        for i, buf_item in ipairs(state.buf_content) do
            for _, event in ipairs(state.history) do
                if state.dir_path == event.dir_path and buf_item == event.item_name then
                    vim.api.nvim_win_set_cursor(state.win_id, { i, 0 })
                    return
                end
            end
        end
        vim.api.nvim_win_set_cursor(state.win_id, { 1, 0 })
    end

    local function set_buffer_content(new_dir_path)
        assert(fmGlobals.is_item_directory(new_dir_path), "Passed path is not a directory")

        state.dir_path = new_dir_path
        state.buf_content = get_buffer_content(new_dir_path)

        vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', true)
        vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, true, state.buf_content)
        vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', false)

        fmTheming.theme_buffer_content(state)
        set_window_cursor()
    end

    local function reload()
        set_buffer_content(state.dir_path)
    end

    local function action_on_item(cmd_str)
        local item = get_cursor_item(state)

        if fmGlobals.is_item_directory(item) then
            if cmd_str == cmd.open then
                set_buffer_content(state.dir_path .. item)
            end
        else
            local file_rel = path:new(state.dir_path .. item):make_relative()
            close_navigation()
            vim.cmd(cmd_str .. ' ' .. file_rel)
        end
    end

    local function get_relative_path()
        return path:new(state.dir_path):make_relative() .. "/"
    end


    local function open_terminal()
        local dir_path = get_relative_path()

        local sh_cmd = ":terminal"
        vim.cmd("tabe")
        vim.cmd(sh_cmd .. " cd ".. dir_path .. " && $SHELL")
        vim.cmd("startinsert")
    end

    local function navigate_to_parent()
        if state.dir_path == "/" then
            return
        end

        local function get_current_event()
            local item_name = get_cursor_item(state)
            return create_event(state.dir_path, item_name)
        end

        local function get_parent_event()
            local parts = fmGlobals.split(state.dir_path, "/")
            local item_name = table.remove(parts, #parts)

            local dir_path = "/"
            for _, value in ipairs(parts) do
                dir_path = dir_path .. value .. "/"
            end

            return create_event(dir_path, item_name .. "/")
        end

        local function get_history_index(cmp_path)
            for i, event in ipairs(state.history) do
                if event.dir_path == cmp_path then
                    return i
                end
            end
            return -1
        end

        local function update_history_event(event)
            local his_index = get_history_index(event.dir_path)

            if his_index == -1 then
                table.insert(state.history, event)
            else
                state.history[his_index].item_name = event.item_name
            end
        end

        local current_event = get_current_event()
        local parent_event = get_parent_event()

        update_history_event(current_event)
        update_history_event(parent_event)

        set_buffer_content(parent_event.dir_path)
    end

    local function init()
        local fd = vim.fn.expand('%:p:h') .. "/"
        local fn = vim.fn.expand('%:t')
        local ui = vim.api.nvim_list_uis()[1]
        local width = fmGlobals.round(ui.width * 0.9)
        local height = fmGlobals.round(ui.height * 0.8)

        local options = {
            relative = 'editor',
            width = width,
            height = height,
            col = (ui.width - width) * 0.5,
            row = (ui.height - height) * 0.2,
            anchor = 'NW',
            style = 'minimal',
            border = 'rounded',
            title = ' File manager (help: ?) ',
            title_pos = 'center',
        }

        state.win_id = vim.api.nvim_open_win(state.buf_id, true, options)
        state.is_open = true;

        fmTheming.add_theming(state)

        local buffer_options = { silent = true, buffer = state.buf_id }

        local function confirm_new_item_callback(popup, sh_cmd)
            local output = vim.fn.systemlist(popup.create_sh_cmd(sh_cmd))
            reload()
            popup.close_navigation()

            if #output ~= 0 then
                fmGlobals.debug(output)
                fmPopup.create_info_popup(output, state.win_id, 'Command failed (Esc / q)')
            end
        end

        local function create_dir_popup()
            local popup = fmPopup.create_dir_popup(get_relative_path())

            popup.set_keymap(
                '<Cr>', function() confirm_new_item_callback(popup, 'mkdir') end
            )
        end

        local function create_file_popup()
            local popup = fmPopup.create_file_popup(get_relative_path())

            popup.set_keymap(
                '<Cr>', function() confirm_new_item_callback(popup, 'touch') end
            )
        end

        local function create_move_popup()
            local popup = fmPopup.create_move_popup(get_relative_path())

            local function confirm_callback()
                local item_name = get_cursor_item(state)
                local sh_cmd = popup.create_rename_cmd(item_name)
                local output = vim.fn.systemlist(sh_cmd)
                popup.close_navigation()

                if #output ~= 0 then
                    fmGlobals.debug(output)
                    fmPopup.create_info_popup(output, state.win_id, 'Command failed (Esc / q)')
                else
                    reload()
                end
            end

            popup.set_keymap('<Cr>', confirm_callback)
        end

        local function delete_item()
            local dir_path = get_relative_path()
            local item_name = get_cursor_item(state)

            local function create_sh_cmd()
                if fmGlobals.is_item_directory(item_name) then
                    return "rm -rf " .. dir_path .. item_name
                else
                    return "rm " .. dir_path .. item_name
                end
            end

            local sh_cmd = { create_sh_cmd() }
            local popup = fmPopup.create_delete_item_popup(sh_cmd, state.win_id)

            local function confirm_callback()
                vim.fn.systemlist(sh_cmd[1])
                reload()
                popup.close_navigation()
            end

            popup.set_keymap('<Cr>', confirm_callback)
        end

        vim.keymap.set('n', 'q', close_navigation, buffer_options)
        vim.keymap.set('n', '<Esc>', close_navigation, buffer_options)
        vim.keymap.set('n', '<Right>', function() action_on_item(cmd.open) end, buffer_options)
        vim.keymap.set('n', 'l', function() action_on_item(cmd.open) end, buffer_options)
        vim.keymap.set('n', '<Cr>', function() action_on_item(cmd.open) end, buffer_options)
        vim.keymap.set('n', 'v', function() action_on_item(cmd.vSplit) end, buffer_options)
        vim.keymap.set('n', 's', function() action_on_item(cmd.hSplit) end, buffer_options)
        vim.keymap.set('n', 't', function() action_on_item(cmd.openTab) end, buffer_options)
        vim.keymap.set('n', '=', open_terminal, buffer_options)
        vim.keymap.set('n', 'cd', create_dir_popup, buffer_options)
        vim.keymap.set('n', 'cf', create_file_popup, buffer_options)
        vim.keymap.set('n', 'm', create_move_popup, buffer_options)
        vim.keymap.set('n', 'dd', delete_item, buffer_options)
        vim.keymap.set('n', '<Left>', navigate_to_parent, buffer_options)
        vim.keymap.set('n', 'h', navigate_to_parent, buffer_options)
        vim.keymap.set('n', '<F1>', "", buffer_options)
        vim.keymap.set('n', '?', function() fmPopup.create_help_popup(state.win_id) end, buffer_options)

        if fn ~= "" then
            table.insert(state.history, create_event(fd, fn))
            set_buffer_content(fd)
        else
            set_buffer_content(path:new("./"):absolute() .. "/")
        end
    end

    init()
end

return M
