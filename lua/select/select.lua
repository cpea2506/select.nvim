---@class SelectModule
---@overload fun<T>(items: T[], opts: vim.ui.select.Opts, on_choice: fun(item?: T, idx?: integer))
local M = {}

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
---@generic T: number|integer
---@param value T
---@param min T
---@param max T
---@return T
local function clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

---@param n integer
---@return integer
local function factorial(n)
    if n < 2 then
        return 1
    end

    local result = 1

    for i = 2, n do
        result = result * i
    end

    return result
end

---@param n integer
---@param k integer
---@return integer
local function permutations(n, k)
    if k < 0 or k > n then
        return 0
    end

    return (factorial(n) / factorial(n - k)) ---@as integer
end

---@param allowed_key_count integer
---@param item_count integer
---@return integer
local function calculate_min_keymap_len(allowed_key_count, item_count)
    if item_count <= 0 then
        return 0
    end

    local length = 1

    while permutations(allowed_key_count, length) < item_count do
        length = length + 1
    end

    return length
end

---@param title string
---@param valid_keys table<string, boolean>
---@param invalid_keys table<string, boolean>
---@param min_keymap_len integer
---@return string?
local function get_keymap_from_title(title, valid_keys, invalid_keys, min_keymap_len)
    title = title:lower()

    for index = 1, #title - min_keymap_len + 1 do
        local key = title:sub(index, index + min_keymap_len - 1)
        local used = {}
        local valid = true

        for i = 1, #key do
            local char = key:sub(i, i)

            if used[char] then
                valid = false
                break
            end

            used[char] = true
        end

        if valid and valid_keys[key] and not invalid_keys[key] then
            return key
        end
    end

    return nil
end

---@param letters string[]
---@param min_keymap_len integer
---@param max_results_len integer
---@param invalid_keys table<string, boolean>
---@return string[]
local function generate_key_permutations(letters, min_keymap_len, max_results_len, invalid_keys)
    local results = {}
    local used = {}

    local function backtrack(current)
        if #results >= max_results_len then
            return true
        end

        if #current == min_keymap_len then
            if not invalid_keys[current] then
                results[#results + 1] = current
            end

            return #results >= max_results_len
        end

        for i = 1, #letters do
            local char = letters[i]

            if not used[char] then
                used[char] = true

                local stop = backtrack(current .. char)

                used[char] = nil

                if stop then
                    return true
                end
            end
        end

        return false
    end

    backtrack ""

    return results
end

--- Create dictionary of labels.
---@param items string[]
---@return table<string, string>
local function create_labels(items)
    local alphabet = "fjdkslaghrueiwocnxvbmztyqp"
    local preserve_keys = { "g", "j", "k", "q" }
    local invalid_keys = {}

    for _, key in ipairs(preserve_keys) do
        invalid_keys[key] = true
    end

    local letters = vim.iter(vim.split(alphabet, "", { plain = true }))
        :filter(function(char)
            return not invalid_keys[char]
        end)
        :totable()

    local valid_keys = {}

    for _, char in ipairs(letters) do
        valid_keys[char] = true
    end

    local min_keymap_len = calculate_min_keymap_len(#letters, #items)
    ---@type table<string, string>
    local result = {}

    -- Try prioritize keymaps derived from titles.
    for _, title in ipairs(items) do
        local key = get_keymap_from_title(title, valid_keys, invalid_keys, min_keymap_len)

        if key then
            result[title] = key
            invalid_keys[key] = true
        end
    end

    local remaining_len = #items - vim.iter(result):count()

    if remaining_len <= 0 then
        return result
    end

    local key_permutations = generate_key_permutations(letters, min_keymap_len, remaining_len, invalid_keys)
    local permutation_index = 1

    for _, title in ipairs(items) do
        if not result[title] then
            local key = key_permutations[permutation_index]

            result[title] = key
            invalid_keys[key] = true

            permutation_index = permutation_index + 1
        end
    end

    return result
end

---@generic T
---@class Select
---@field items table<integer, T>
---@field on_choice fun(item?: T, index?: integer)
---@field winid integer
---@field buf integer
---@field titles string[]
---@field labels table<string, string>
---@field prompt string
local Select = {}
Select.__index = Select

---@generic T
---@param items T[]
---@param opts vim.ui.select.Opts
---@param on_choice fun(item?: T, idx?: integer)
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
        buf = nil,
        titles = titles,
        labels = create_labels(titles),
        prompt = opts.prompt or config.options.default_prompt,
    }, Select)
end

---@param index? integer
function Select:choose(index)
    self:close()
    self.on_choice(self.items[index], index)
end

function Select:close()
    show_cursor(true)

    if self.winid and vim.api.nvim_win_is_valid(self.winid) then
        vim.api.nvim_win_close(self.winid, true)
        self.winid = nil
    end
end

function Select:cancel()
    self:choose(nil)
end

function Select:create_buffer()
    self.buf = vim.api.nvim_create_buf(false, true)

    ---@type Partial<vim.bo>
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
    local size_options = config.options.size_options
    local win_config = config.options.win_config

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

    for option, value in pairs(config.options.win_options) do
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

---@type Select?
local instance = nil

---@generic T
---@param items T[]
---@param opts vim.ui.select.Opts
---@param on_choice fun(item?: T, idx?: integer)
local function select(items, opts, on_choice)
    if instance then
        instance:close()
    end

    instance = Select.new(items, opts, on_choice)
    instance:show()
end

setmetatable(M, {
    __call = function(_, ...)
        select(...)
    end,
})

return M
