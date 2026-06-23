local M = setmetatable({}, {
    __call = function(t, ...)
        t.select(...)
    end,
})

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

---@generic T
---@class Select
---@field items T[]
---@field on_choice fun(item: T|nil, index: integer|nil)
---@field winid integer
---@field buf integer
---@field titles string[]
---@field labels string[]
---@field prompt string
local Select = {}
Select.__index = Select

function Select.new(items, opts, on_choice)
    opts = opts or {}

    local config = require "select.config"
    local titles = vim.iter(items)
        :map(function(item)
            return opts.format_item and opts.format_item(item) or item
        end)
        :totable()

    return setmetatable({
        items = items,
        on_choice = on_choice,
        winid = nil,
        bufnr = nil,
        titles = titles,
        labels = create_labels(titles),
        prompt = opts.prompt or config.default_prompt,
    }, Select)
end

function Select:choose(index)
    self:close()
    self.on_choice(self.items[index], index)
end

function Select:close()
    show_cursor(true)

    if self.winid and vim.api.nvim_win_is_valid(self.winid) then
        vim.api.nvim_win_close(self.winid, true)
    end

    if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
        vim.api.nvim_buf_delete(self.buf, { force = true })
    end
end

function Select:cancel()
    self:choose(nil)
end

function Select:create_buffer()
    self.buf = vim.api.nvim_create_buf(false, true)

    ---@type vim.bo
    local buf_options = {
        swapfile = false,
        bufhidden = "wipe",
        filetype = "select",
    }

    for option, value in pairs(buf_options) do
        vim.bo[self.buf][option] = value
    end
end

function Select:create_window()
    local config = require "select.config"
    local size_options = config.size_options
    local win_config = config.win_config

    win_config.title = trim_and_pad_title(self.prompt)

    local lines = {}
    local height = 0
    local max_line_width = self.prompt and vim.api.nvim_strwidth(self.prompt) or size_options.width.min

    for _, title in ipairs(self.titles) do
        local prefix = self.labels[title] .. ": "
        local line = prefix .. title
        local line_width = vim.api.nvim_strwidth(line)

        max_line_width = math.max(max_line_width, line_width)
        height = height + math.ceil(line_width / size_options.width.max)

        table.insert(lines, line)
    end

    vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, lines)
    vim.bo[self.buf].modifiable = false

    local ns = vim.api.nvim_create_namespace "select"

    for i, title in ipairs(self.titles) do
        vim.hl.range(self.buf, ns, "SelectOptionLabel", { i - 1, 0 }, { i - 1, #self.labels[title] + 1 })
    end

    win_config.width = clamp(max_line_width, size_options.width.min, size_options.width.max) + 2
    win_config.height = clamp(height, size_options.height.min, size_options.height.max)
    win_config.row = math.floor((vim.o.lines - win_config.height) / 2)
    win_config.col = math.floor((vim.o.columns - win_config.width) / 2)

    self.winid = vim.api.nvim_open_win(self.buf, true, win_config)

    for option, value in pairs(config.win_options) do
        vim.wo[self.winid][option] = value
    end

    show_cursor(false)
end

function Select:set_keymaps()
    for i, title in ipairs(self.titles) do
        vim.keymap.set("n", self.labels[title], function()
            self:choose(i)
        end, { buffer = self.buf, nowait = true })
    end

    vim.keymap.set("n", "<Esc>", function()
        self:cancel()
    end, { buffer = self.buf })
    vim.keymap.set("n", "<C-c>", function()
        self:cancel()
    end, { buffer = self.buf })
    vim.keymap.set("n", "q", function()
        self:cancel()
    end, { buffer = self.buf })
    vim.keymap.set("n", "<cr>", function()
        local index = vim.api.nvim_win_get_cursor(self.winid)[1]
        self:choose(index)
    end, { buffer = self.buf })
end

function Select:create_autocmds()
    local augroup = vim.api.nvim_create_augroup("select", {})

    vim.api.nvim_create_autocmd("BufLeave", {
        group = augroup,
        desc = "Cancel vim.ui.select",
        buffer = self.buf,
        nested = true,
        once = true,
        callback = function()
            self:close()
        end,
    })
    vim.api.nvim_create_autocmd("CmdlineEnter", {
        group = augroup,
        desc = "Show cursor",
        buffer = self.buf,
        nested = true,
        callback = function()
            show_cursor(true)
        end,
    })
    vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = augroup,
        desc = "Hide cursor",
        buffer = self.buf,
        nested = true,
        callback = function()
            show_cursor(false)
        end,
    })
end

function Select:show()
    self:create_buffer()
    self:create_window()
    self:set_keymaps()
    self:create_autocmds()
end

---@type Select
local instance = nil

function M.select(items, opts, on_choice)
    if instance then
        instance:close()
    end

    instance = Select.new(items, opts, on_choice)
    instance:show()
end

return M
