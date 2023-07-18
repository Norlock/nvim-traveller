local fm_globals = require("fm-globals")

local M = {}

---@param state NavigationState
---@return string[]
function M:create_mv_cmds_selection(state)
    local sh_cmds = {}
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
function M:create_cp_cmds_selection(state)
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

return M
