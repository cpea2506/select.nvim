local M = setmetatable({}, {
    __call = function(t, ...)
        t.select(...)
    end,
})

local buf_options = {
    swapfile = false,
    bufhidden = "wipe",
    filetype = "select",
}

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
    local alphabet = "abcdefghijklmnopqrstuvwxyz"
    local preserve_keys = { j = true, k = true, g = true, q = true }

    local labels = {}
    local used = {}

    -- Mark reserved keys as already used.
    for k in pairs(preserve_keys) do
        used[k] = true
    end
    local function next_label(i)
        local result = ""

        i = i + 1

        while i > 0 do
            local r = (i - 1) % 26
            result = alphabet:sub(r + 1, r + 1) .. result
            i = math.floor((i - 1) / 26)
        end

        return result
    end

    local function get_next_available()
        local i = 0

        while true do
            local label = next_label(i)

            if not used[label] then
                used[label] = true

                return label
            end

            i = i + 1
        end
    end

    -- Try first-letter labels.
    for _, item in ipairs(items) do
        local first_letter = item:sub(1, 1):lower()

        if not preserve_keys[first_letter] and not used[first_letter] then
            used[first_letter] = true
            labels[item] = first_letter
        end
    end

    -- Try fallback labels.
    for _, item in ipairs(items) do
        if not labels[item] then
            labels[item] = get_next_available()
        end
    end

    return labels
end

function M.select(items, opts, on_choice)
    opts = opts or {}

    local config = require "select.config"
    local win_config = config.win_config
    local size_options = config.size_options

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
    local max_line_width = prompt and vim.api.nvim_strwidth(prompt) or size_options.width.min

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

    win_config.width = math.max(max_line_width, size_options.width.max)
    win_config.height = clamp(#lines, size_options.height.min, size_options.height.max)

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

return M
