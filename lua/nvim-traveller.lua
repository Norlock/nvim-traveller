local fm_theming = require("fm-theming")
local fm_globals = require("fm-globals")
local fm_popup = require("fm-popup")
local fm_plugin = require("fm-plugin-integration")
local path = require("plenary.path")

local function create_event(dir_path, item_name)
    return {
        dir_path = dir_path,
        item_name = item_name,
    }
end

local M = {
    state = {
        is_open = false,
        history = {},
    }
}

function M.create_new_state()
    M.state = {
        parent_buf_id = vim.api.nvim_get_current_buf(),
        buf_id = vim.api.nvim_create_buf(false, true),
        is_open = false,
        history = {},
        show_hidden = true,
    }

    return M.state
end

function M.close_navigation()
    fm_globals.close_window(M.state)
end

-- Opens the navigation
function M.open_navigation()
    if M.state.is_open then
        return
    end

    local state = M.create_new_state();

    vim.api.nvim_create_autocmd("BufEnter", {
        buffer = state.parent_buf_id,
        callback = M.close_navigation
    })

    local cmd = {
        open = 'e',
        openTab = 'tabe',
        vSplit = 'vsplit',
        hSplit = 'split',
    }

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
        assert(fm_globals.is_item_directory(new_dir_path), "Passed path is not a directory")

        local function get_buffer_content()
            local function get_cmd_prefix()
                if state.show_hidden then
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

        state.dir_path = new_dir_path
        state.buf_content = get_buffer_content()

        vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', true)
        vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, true, state.buf_content)
        vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', false)

        fm_theming.theme_buffer_content(state)
        set_window_cursor()
    end

    local function reload()
        set_buffer_content(state.dir_path)
    end

    local function action_on_item(cmd_str)
        local item = fm_globals.get_cursor_navigation_item(state)

        if fm_globals.is_item_directory(item) then
            if cmd_str == cmd.open then
                set_buffer_content(state.dir_path .. item)
            end
        else
            local file_rel = path:new(state.dir_path .. item):make_relative()
            M.close_navigation()
            vim.cmd(cmd_str .. ' ' .. file_rel)
        end
    end

    local function get_relative_path()
        local rel = path:new(state.dir_path):make_relative()

        if rel == "/" then return rel else return rel .. "/" end
    end


    local function open_terminal()
        local dir_path = get_relative_path()

        local sh_cmd = ":terminal"
        vim.cmd("tabe")
        vim.cmd(sh_cmd .. " cd " .. dir_path .. " && $SHELL")
        vim.cmd("startinsert")
    end

    local function navigate_to_parent()
        if state.dir_path == "/" then
            return
        end

        local function get_current_event()
            local item_name = fm_globals.get_cursor_navigation_item(state)
            return create_event(state.dir_path, item_name)
        end

        local function get_parent_event()
            local parts = fm_globals.split(state.dir_path, "/")
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
        local width = fm_globals.round(ui.width * 0.9)
        local height = fm_globals.round(ui.height * 0.8)

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
        vim.api.nvim_win_set_option(state.win_id, 'relativenumber', true)
        state.is_open = true;

        fm_theming.add_theming(state)

        local buffer_options = { silent = true, buffer = state.buf_id }

        local function confirm_callback(popup, sh_cmd)
            local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)
            reload()
            popup.close_navigation()

            if #output ~= 0 then
                fm_globals.debug(output)
                fm_popup.create_info_popup(output, state.win_id, 'Command failed (Esc / q)')
            end
        end

        local function create_item_popup()
            local popup = fm_popup.create_dir_popup(get_relative_path())

            local function confirm_mkdir_callback()
                confirm_callback(popup, popup.create_new_items_cmd())
            end

            popup.set_keymap('<Cr>', confirm_mkdir_callback)
        end

        local function create_move_popup()
            local popup = fm_popup.create_move_popup(get_relative_path())

            local function confirm_move_callback()
                local item_name = fm_globals.get_cursor_navigation_item(state)

                -- Tries git mv first, if fails fallsback to mv.
                local sh_cmd = popup.create_mv_cmd(item_name, "git mv")
                local output = vim.fn.systemlist(sh_cmd .. fm_globals.only_stderr)

                if #output ~= 0 then
                    fm_globals.debug(output)
                    confirm_callback(popup, popup.create_mv_cmd(item_name, "mv"))
                else
                    reload()
                    popup.close_navigation()
                end
            end

            popup.set_keymap('<Cr>', confirm_move_callback)
        end

        local function delete_item()
            local dir_path = get_relative_path()
            local item_name = fm_globals.get_cursor_navigation_item(state)

            local function create_sh_cmd()
                local function get_rm_cmd()
                    if fm_globals.item_is_part_of_git_repo(dir_path, item_name) then
                        return "cd " .. dir_path .. " && git rm", item_name
                    else
                        return "rm", dir_path .. item_name
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
            local popup = fm_popup.create_delete_item_popup({ sh_cmd }, state.win_id)

            local function confirm_delete_callback()
                confirm_callback(popup, sh_cmd)
            end

            popup.set_keymap('<Cr>', confirm_delete_callback)
        end

        local function toggle_hidden()
            state.show_hidden = not state.show_hidden
            reload()
        end

        local function navigate_to_home_directory()
            set_buffer_content(vim.fn.expand('$HOME') .. "/")
        end

        vim.keymap.set('n', 'q', M.close_navigation, buffer_options)
        vim.keymap.set('n', '<Esc>', M.close_navigation, buffer_options)
        vim.keymap.set('n', '<Right>', function() action_on_item(cmd.open) end, buffer_options)
        vim.keymap.set('n', 'l', function() action_on_item(cmd.open) end, buffer_options)
        vim.keymap.set('n', '<Cr>', function() action_on_item(cmd.open) end, buffer_options)
        vim.keymap.set('n', 'v', function() action_on_item(cmd.vSplit) end, buffer_options)
        vim.keymap.set('n', 's', function() action_on_item(cmd.hSplit) end, buffer_options)
        vim.keymap.set('n', 't', function() action_on_item(cmd.openTab) end, buffer_options)
        vim.keymap.set('n', '=', open_terminal, buffer_options)
        vim.keymap.set('n', 'c', create_item_popup, buffer_options)
        vim.keymap.set('n', 'm', create_move_popup, buffer_options)
        vim.keymap.set('n', 'dd', delete_item, buffer_options)
        vim.keymap.set('n', '<Left>', navigate_to_parent, buffer_options)
        vim.keymap.set('n', 'h', navigate_to_parent, buffer_options)
        vim.keymap.set('n', '<F1>', "", buffer_options)
        vim.keymap.set('n', '?', function() fm_popup.create_help_popup(state.win_id) end, buffer_options)
        vim.keymap.set('n', '<A-.>', toggle_hidden, buffer_options)
        vim.keymap.set('n', '~', navigate_to_home_directory, buffer_options)

        -- Plugin integration
        vim.keymap.set('n', 'f', function() fm_plugin.find_files(state) end, buffer_options)
        vim.keymap.set('n', 'a', function() fm_plugin.live_grep(state) end, buffer_options)

        if fn ~= "" then
            table.insert(state.history, create_event(fd, fn))
            set_buffer_content(fd)
        else
            set_buffer_content(path:new("./"):absolute() .. "/")
        end
    end

    init()
end

function M.setup(options)
    if options.replace_netrw then
        vim.g.loaded_netrwPlugin = 1
        vim.g.loaded_netrw = 1

        local fn = vim.fn.expand('%:t')

        if fn == "" then
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = M.open_navigation
            })
        end
    end

    local function change_cwd_callback()
        local buf_options = vim.api.nvim_buf_get_option(0, "bufhidden")

        if buf_options ~= "hide" then
            local fd = vim.fn.expand('%:p:h')
            fm_globals.debug("heeft cmd geroepen " .. fd)
            fm_globals.set_cwd_to_git_root(fd)
        end
    end

    if options.sync_cwd then
        vim.api.nvim_create_autocmd("BufEnter", {
            callback = change_cwd_callback
        })
    end
end

return M
