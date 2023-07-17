local NavigationState = require("fm-navigation")
local fm_globals = require("fm-globals")

local state = NavigationState
local M = {}

function M.close_navigation()
    if state.is_initialized then
        state:close_navigation()
    end
end

function M.open_navigation()
    local function is_open()
        return vim.api.nvim_get_current_buf() == state.buf_id
    end

    if state.is_initialized then
        if not is_open() then
            state:init()
            state:open_navigation()
        end
    else
        state = NavigationState:new()
        state:open_navigation()
    end
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
        if vim.bo.bufhidden == "hide" then
            return
        end

        local fd = vim.fn.expand('%:p:h')

        if vim.fn.isdirectory(fd) == 1 then
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
