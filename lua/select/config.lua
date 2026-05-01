---@class select.type.range
---@field min integer
---@field max integer

---@class select.config.size_options
---@field width select.type.range
---@field height select.type.range
---
---@class select.config
---@field default_prompt string
---@field win_options vim.wo
---@field win_config vim.api.keyset.win_config
---@field size_options select.config.size_options
local config = {}

---@type select.config
local defaults = {
    default_prompt = "Select",
    win_options = {
        cursorline = true,
        cursorlineopt = "both",
        winhighlight = "Normal:FloatNormal,FloatBorder:FloatBorder,CursorLine:Visual",
    },
    win_config = {
        relative = "editor",
        anchor = "NW",
        focusable = false,
        noautocmd = true,
        zindex = 150,
        style = "minimal",
    },
    size_options = {
        width = {
            min = 80,
            max = 100,
        },
        height = {
            min = 1,
            max = 999,
        },
    },
}

local options = vim.deepcopy(defaults)

---Extend default with user's config.
---@param opts select.config
function config.extend(opts)
    if not opts or vim.tbl_isempty(opts) then
        return
    end

    options = vim.tbl_deep_extend("force", options, opts)
end

setmetatable(config, {
    __index = function(_, k)
        return options[k]
    end,
})

return config
