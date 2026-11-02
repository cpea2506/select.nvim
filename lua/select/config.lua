---@alias input.type.range { min: integer, max: integer }

---@class select.config
local config = {}

---@class select.options
local defaults = {
    default_prompt = "Select",
    ---@type Partial<vim.wo>
    win_options = {
        cursorline = true,
        cursorlineopt = "both",
        winhighlight = "Normal:FloatNormal,FloatBorder:FloatBorder,CursorLine:Visual",
    },
    ---@type vim.api.keyset.win_config
    win_config = {
        relative = "editor",
        anchor = "NW",
        focusable = false,
        noautocmd = true,
        zindex = 150,
        style = "minimal",
    },
    size_options = {
        ---@type input.type.range
        width = {
            min = 80,
            max = 100,
        },
        ---@type input.type.range
        height = {
            min = 1,
            max = 999,
        },
    },
}

config.options = vim.deepcopy(defaults)

---Extend default with user's config.
---@param opts select.options
function config.extend(opts)
    if not opts or vim.tbl_isempty(opts) then
        return
    end

    config.options = vim.tbl_deep_extend("force", config.options, opts)
end

return config
