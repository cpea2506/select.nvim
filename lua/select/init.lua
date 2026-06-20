local M = {}

function M.setup(opts)
    local config = require "select.config"
    config.extend(opts)

    vim.api.nvim_set_hl(0, "SelectOptionLabel", { link = "Type", default = true })

    vim.ui.select = require "select.select"
end

return M
