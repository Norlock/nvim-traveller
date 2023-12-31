local fm_globals = require("nvim-traveller.fm-globals")

local M = {}

local data_path = vim.fn.stdpath('data') .. '/nvim-traveller.json'

local function retrieve_data()
    fm_globals.debug("history test");
    if vim.fn.filereadable(data_path) == 0 then
        local filewrite = io.open(data_path, "w")

        if filewrite == nil then
            fm_globals.debug("Can't write data")
            return {}
        end

        filewrite:write("[]") -- empty JSON array
        filewrite:close()
        return {}
    end

    local file_output = vim.fn.readfile(data_path)
    fm_globals.debug(file_output, "history");
    local json_str = ""

    for _, item in pairs(file_output) do
        json_str = json_str .. item
    end

    return vim.fn.json_decode(json_str)
end

local history = retrieve_data()

local function update_history(dir_path)
    local function compare(a, b)
        return b.last_used < a.last_used
    end

    for _, item in pairs(history) do
        if item.dir_path == dir_path then
            item.last_used = os.time()
            table.sort(history, compare)
            return item
        end
    end

    table.insert(history, {
        dir_path = dir_path,
        last_used = os.time()
    })

    table.sort(history, compare)

    while 15 < #history do
        table.remove(history, #history)
    end
end

local function persist()
    local json = vim.fn.json_encode(history)
    local filewrite = io.open(data_path, "w+")

    if filewrite == nil then
        fm_globals.debug(data_path, "Can't open data file")
        return
    end

    filewrite:write(json)
    filewrite:close()
end

function M.store_data(dir_path)
    update_history(dir_path)
    persist()
end

function M.remove(dir_path)
    local function get_index()
        for i, item in ipairs(history) do
            if item.dir_path == dir_path then
                return i
            end
        end
    end

    table.remove(history, get_index())

    persist()
    return M.last_used_dirs()
end

function M.last_used_dirs()
    local dirs = {}

    for _, item in pairs(history) do
        table.insert(dirs, item.dir_path)
    end

    return dirs
end

return M
