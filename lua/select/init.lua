local M = {}

local buf_options = {
    swapfile = false,
    bufhidden = "wipe",
    filetype = "select",
}

local min_size = 0.15
local max_size = 0.8
local max_width = 80

---Show or hide cursor.
---@param show boolean
local function show_cursor(show)
    local guicursor = "a:SelectHiddenCursor"

    vim.api.nvim_set_hl(0, "SelectHiddenCursor", { reverse = true, blend = show and 0 or 100 })

    if show then
        vim.opt.guicursor:remove(guicursor)
    else
        vim.opt.guicursor:append(guicursor)
    end
end

---Trim and pad title.
---@param title string
---@return string
local function trim_and_pad_title(title)
    title = vim.trim(title):gsub(":$", "")

    return (" %s "):format(title)
end

---Clamp value to between min and max.
---@param value number
---@param min number
---@param max number
local function clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

---Create list of labels.
---@param items string[]
local function create_labels(items)
    local labels = {}
    local used = {}
    local fallback = "a"
    local preserve_keys = { j = true, k = true, g = true }

    for _, item in ipairs(items) do
        local first_letter = item:sub(1, 1):lower()

        if preserve_keys[first_letter] == nil and not used[first_letter] then
            used[first_letter] = true
            labels[item] = first_letter
        end
    end

    for _, item in ipairs(items) do
        if not labels[item] then
            while used[fallback] do
                fallback = string.char(fallback:byte() + 1)
            end

            if fallback:byte() > 122 then
                fallback = "A"
            end

            used[fallback] = true
            labels[item] = fallback
        end
    end

    return labels
end

local function select(items, opts, on_choice)
    opts = opts or {}

    local config = require "select.config"
    local win_config = config.win_config

    local prompt = opts.prompt or config.default_prompt
    win_config.title = trim_and_pad_title(prompt)

    local function close(winid)
        show_cursor(true)
        vim.api.nvim_win_close(winid, true)
    end

    local function choose(winid, index)
        close(winid)
        on_choice(items[index], index)
    end

    local function cancel(winid)
        choose(winid, nil)
    end

    -- Create buffer.
    local bufnr = vim.api.nvim_create_buf(false, true)

    -- Set buffer options.
    for option, value in pairs(buf_options) do
        vim.bo[bufnr][option] = value
    end

    local titles = vim.iter(items)
        :map(function(item)
            return opts.format_item and opts.format_item(item) or item
        end)
        :totable()
    local labels = create_labels(titles)
    local lines = {}
    local max_line_width = prompt and vim.api.nvim_strwidth(prompt) or 1

    for _, title in ipairs(titles) do
        local prefix = labels[title] .. ": "
        local line = prefix .. title

        max_line_width = math.max(max_line_width, vim.api.nvim_strwidth(line))

        table.insert(lines, line)
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.bo[bufnr].modifiable = false

    local ns = vim.api.nvim_create_namespace "select"

    for i, title in ipairs(titles) do
        vim.hl.range(bufnr, ns, "SelectOptionLabel", { i - 1, 0 }, { i - 1, #labels[title] + 1 })
    end

    win_config.width = math.max(max_line_width, max_width)

    local height = clamp((#lines + 4) / vim.o.lines, min_size, max_size)
    win_config.height = math.min(#lines, math.floor(height * vim.o.lines))

    win_config.row = math.floor((vim.o.lines - win_config.height) / 2)
    win_config.col = math.floor((vim.o.columns - win_config.width) / 2)

    -- Create floating window.
    local winid = vim.api.nvim_open_win(bufnr, true, win_config)

    -- Set window options.
    for option, value in pairs(config.win_options) do
        vim.wo[winid][option] = value
    end

    show_cursor(false)

    for i, title in ipairs(titles) do
        vim.keymap.set("n", labels[title], function()
            choose(winid, i)
        end, { buffer = bufnr, nowait = true })
    end

    vim.keymap.set("n", "<C-c>", function()
        cancel(winid)
    end, { buffer = bufnr })
    vim.keymap.set("n", "q", function()
        cancel(winid)
    end, { buffer = bufnr })
    vim.keymap.set("n", "<cr>", function()
        local index = vim.api.nvim_win_get_cursor(winid)[1]
        choose(winid, index)
    end, { buffer = bufnr })

    local augroup = vim.api.nvim_create_augroup("select", { clear = true })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = augroup,
        desc = "Cancel vim.ui.select",
        buffer = bufnr,
        nested = true,
        once = true,
        callback = function()
            close(winid)
        end,
    })

    vim.api.nvim_create_autocmd("CmdlineEnter", {
        group = augroup,
        desc = "Show cursor",
        buffer = bufnr,
        nested = true,
        callback = function()
            show_cursor(true)
        end,
    })

    vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = augroup,
        desc = "Hide cursor",
        buffer = bufnr,
        nested = true,
        callback = function()
            show_cursor(false)
        end,
    })
end

function M.setup(opts)
    local config = require "select.config"

    if vim.fn.hlexists "SelectOptionLabel" == 0 then
        vim.api.nvim_set_hl(0, "SelectOptionLabel", { link = "Type" })
    end

    config.extend(opts)

    vim.ui.select = select
end

return M
