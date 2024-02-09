local NavigationState = require("nvim-traveller.navigation")
local fm_globals = require("nvim-traveller.fm-globals")
local fm_telescope = require("nvim-traveller.plugin-telescope")
local path = require("plenary.path")
local fm_shell = require("nvim-traveller.fm-shell")

local state = {}
local M = {}

---@class ModOptions
---@field show_hidden boolean show hidden by default or not (default is true)
---@field mappings table
local ModOptions = {}

function M.close_navigation()
    if state.is_initialized then
        state:close_navigation()
    end
end

function M.open_navigation()
    if state.is_initialized then
        if vim.api.nvim_get_current_buf() ~= state.buf_id then
            state:init()
            state:open_navigation()
        end
    else
        state = NavigationState:new()
        state:open_navigation()
    end
end

---Searches directories and opens traveller
---deprecated (use all_directories_search / last_directories_search)
function M.open_telescope_search()
    M.last_directories_search()
end

function M.all_directories_search()
    if not state.is_initialized then
        state = NavigationState:new()
    end

    fm_telescope:directories_search(state, false)
end

function M.last_directories_search()
    if not state.is_initialized then
        state = NavigationState:new()
    end

    fm_telescope:directories_search(state, true)
end

function M.open_terminal()
    local fd = vim.fn.expand('%:p:h')

    if vim.fn.isdirectory(fd) == 1 then
        local abs = path:new(fd):absolute()
        fm_shell.open_terminal(abs)
    end
end

---Setup global options
---@param options ModOptions
function M.setup(options)
    vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
            vim.api.nvim_del_augroup_by_name("FileExplorer")

            local fn = vim.fn.expand('%:t')
            local filetype = vim.bo.filetype
            if filetype == "netrw" or fn == "" then
                vim.bo.buftype = "nofile"
                vim.bo.bufhidden = "wipe"
                vim.bo.buflisted = false
                M.open_navigation()
            end
        end
    })

    NavigationState:set_mod_options(options or {})
    fm_telescope.set_mod_options(options or {})

    return M
end

return M
