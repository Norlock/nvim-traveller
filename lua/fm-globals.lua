local M = {
    os = vim.loop.os_uname().sysname,
    only_stderr = " > /dev/null"
}

function M.is_item_directory(item)
    local ending = "/"
    return item:sub(- #ending) == ending
end

local path = vim.fn.stdpath('log') .. '/nvim-traveller.log'

function M.debug(val)
    local filewrite = io.open(path, "a+")

    if filewrite == nil then
        print("Can't open debug file")
        return
    end

    filewrite:write(vim.inspect(val) .. "\n\n")
    filewrite:close()
end

M.debug("Opening Neovim " .. path)

function M.round(num)
    local fraction = num % 1
    if 0.5 < fraction then
        return math.ceil(num)
    else
        return math.floor(num)
    end
end

function M.split(str, sep)
    local parts = {}
    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

function M.trim(str)
    return str:match("^%s*(.-)%s*$")
end

function M.item_is_part_of_git_repo(dir_path, item)
    local sh_cmd = "cd " .. dir_path .. " && git ls-files --error-unmatch " .. item .. " > /dev/null"
    return #vim.fn.systemlist(sh_cmd) == 0
end

function M.directory_is_inside_a_git_repo(dir_path)
    local sh_cmd = "cd " .. dir_path .. " && git rev-parse --is-inside-work-tree" .. M.only_stderr
    return #vim.fn.systemlist(sh_cmd) == 0
end

function M.close_window(state)
    if vim.api.nvim_win_is_valid(state.win_id) then
        state.is_open = false
        vim.api.nvim_win_close(state.win_id, false)
    end
end

function M.get_cursor_navigation_item(state)
	local cursor = vim.api.nvim_win_get_cursor(state.win_id)
	return state.buf_content[cursor[1]]
end

return M
