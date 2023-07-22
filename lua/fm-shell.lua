local fm_globals = require("fm-globals")

local M = {}

---@alias mv_cmd 'mv' | 'git mv'
---@param src_location Location
---@param dst_str string
---@param mv_cmd mv_cmd
---@return string
function M.create_mv_cmd(src_location, dst_str, mv_cmd)
    local dir_path = src_location.dir_path
    local item_name = src_location.item_name

    local sh_cmd_prefix = table.concat({ "cd", dir_path, "&&", mv_cmd, fm_globals.sanitize(item_name) }, " ")

    local sanitize = fm_globals.sanitize(dst_str)
    return sh_cmd_prefix .. " " .. sanitize
end

---@param state NavigationState
---@return string[]
function M.create_mv_cmds_selection(state)
    local sh_cmds = {}

    -- TODO try to use git mv cmd as well
    for _, event in pairs(state.selection) do
        local sanitize_src = fm_globals.sanitize(event.dir_path .. event.item_name)
        local sanitize_dst = fm_globals.sanitize(state.dir_path)

        local cmd = { "mv", sanitize_src, sanitize_dst, fm_globals.only_stderr }

        table.insert(sh_cmds, table.concat(cmd, " "))
    end
    return sh_cmds
end

---@param state NavigationState
---@return string[]
function M.create_cp_cmds_selection(state)
    local sh_cmds = {}
    for _, event in pairs(state.selection) do
        local sanitize_src = fm_globals.sanitize(event.dir_path .. event.item_name)
        local sanitize_dst = fm_globals.sanitize(state.dir_path)

        local cp_prefix = "cp"
        if fm_globals.is_item_directory(event.item_name) then
            cp_prefix = cp_prefix .. " -r"
        end

        local cmd = { cp_prefix, sanitize_src, sanitize_dst, fm_globals.only_stderr }

        table.insert(sh_cmds, table.concat(cmd, " "))
    end
    return sh_cmds
end

local function get_rm_cmd(dir_path, item_name)
    local function get_rm_cmd_parts()
        if fm_globals.item_is_part_of_git_repo(dir_path, item_name) then
            return "cd " .. dir_path .. " && git rm", fm_globals.sanitize(item_name)
        else
            return "rm", fm_globals.sanitize(dir_path .. item_name)
        end
    end

    local rm_prefix, rm_suffix = get_rm_cmd_parts()

    if fm_globals.is_item_directory(item_name) then
        return rm_prefix .. " -rf " .. rm_suffix
    else
        return rm_prefix .. " " .. rm_suffix
    end
end

---@param state NavigationState
---@return string[]
function M.create_rm_cmds(state)
    local sh_cmds = {}

    if #state.selection ~= 0 then
        for _, event in pairs(state.selection) do
            table.insert(sh_cmds, get_rm_cmd(event.dir_path, event.item_name))
        end
    else
        local dir_path = state:get_relative_path()
        local item_name = state:get_cursor_item()
        table.insert(sh_cmds, get_rm_cmd(dir_path, item_name))
    end

    return sh_cmds
end

---Creates new items through touch or mkdir
---@param dir_path string
---@param user_input string
---@return string
function M.create_new_items_cmd(dir_path, user_input)
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

function M.open_terminal(abs_path)
    local term = vim.fn.expand("$TERM")
    vim.fn.jobstart(term, { cwd = abs_path, detach = true })
end

function M.open_shell(rel_path)
    vim.cmd("tabe")
    vim.cmd("terminal cd " .. rel_path .. " && $SHELL")
    vim.cmd("startinsert")
end

function M.is_file_binary(file_path)
    local output = vim.fn.systemlist("file --mime " .. file_path .. " | grep charset=binary")
    return #output ~= 0
end

return M
