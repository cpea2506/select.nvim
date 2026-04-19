---@class select.config
---@field default_prompt string
---@field win_options vim.wo
---@field win_config vim.api.keyset.win_config
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
