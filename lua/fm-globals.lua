local M = {
    os = vim.loop.os_uname().sysname,
    only_stderr = " > /dev/null",
    only_stdout = " 2> /dev/null",
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

M.debug("Opening Neovim " .. os.date('%Y-%m-%d %H:%M:%S'))

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

function M.sanitize(str)
    return M.trim('"' .. str .. '"')
end

function M.item_is_part_of_git_repo(dir_path, item)
    local sh_cmd = "cd " ..
    M.sanitize(dir_path) .. " && git ls-files --error-unmatch " .. M.sanitize(item) .. M.only_stderr
    return #vim.fn.systemlist(sh_cmd) == 0
end

function M.set_cwd_to_git_root(dir_path)
    local sh_cmd = "cd " .. dir_path .. " && git rev-parse --show-toplevel" .. M.only_stdout
    local output = vim.fn.systemlist(sh_cmd)

    if #output ~= 0 then
        vim.cmd("cd " .. output[1])
    end
end

function M.directory_is_inside_a_git_repo(dir_path)
    local sh_cmd = "cd " .. dir_path .. " && git rev-parse --is-inside-work-tree" .. M.only_stderr
    return #vim.fn.systemlist(sh_cmd) == 0
end

function M.get_home_directory()
    return vim.fn.expand("$HOME") .. "/"
end

---@param target table
---@param other table
---@return table
function M.concat_table(target, other)
    for i = 1, #other do
        target[#target + 1] = other[i]
    end
    return target
end

return M
