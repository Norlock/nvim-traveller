local NavigationState = require("fm-navigation")
local fm_globals = require("fm-globals")
local fm_telescope = require("fm-plugin-telescope")

local state = {}
local M = {}

---@class ModOptions
---@field sync_cwd boolean sync working directory if project in git repository (default is false)
---@field replace_netrw boolean replace netrw on startup (default is false)
---@field show_hidden boolean show hidden by default or not (default is true)
local ModOptions = {}

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

---Searches directories and opens traveller / (or a terminal with C-t)
---@param search_dir string absolute directory to start search from
---@param show_hidden boolean show hidden files or not
function M.open_telescope_search(search_dir, show_hidden)
    if not state.is_initialized then
        state = NavigationState:new()
    end

    fm_telescope:global_search(state, search_dir, show_hidden)
end

---Setup global options
---@param options ModOptions
function M.setup(options)
    options = options or {}
    if options.replace_netrw then
        vim.api.nvim_create_autocmd("VimEnter", {
            callback = function()
                vim.api.nvim_del_augroup_by_name("FileExplorer")

                if vim.bo.filetype == "netrw" then
                    M.open_navigation()
                end
            end
        })
    end


    if options.sync_cwd then
        local function change_cwd_callback()
            if vim.bo.bufhidden == "hide" then
                return
            end

            local fd = vim.fn.expand('%:p:h')

            if vim.fn.isdirectory(fd) == 1 then
                fm_globals.set_cwd_to_git_root(fd)
            end
        end

        vim.api.nvim_create_autocmd("BufEnter", {
            callback = change_cwd_callback
        })
    end

    NavigationState:set_mod_options(options)
end

return M
