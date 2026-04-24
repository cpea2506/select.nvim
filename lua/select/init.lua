local M = {}

function M.setup(opts)
    local config = require "select.config"

    if vim.fn.hlexists "SelectOptionLabel" == 0 then
        vim.api.nvim_set_hl(0, "SelectOptionLabel", { link = "Type" })
    end

    config.extend(opts)

    vim.ui.select = require "select.select"
end

return M
