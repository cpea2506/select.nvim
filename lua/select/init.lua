local M = {}

function M.setup(opts)
    local config = require "select.config"

    config.extend(opts)

    vim.ui.select = require "select.select"
end

return M
