local select = require "select"
local config = require "select.config"

describe("Config options", function()
    it("could be indexed without options field", function()
        assert.equal("Select", config.default_prompt)
    end)
end)

describe("Override config", function()
    local expected = {
        default_prompt = "Select",
        win_config = {
            relative = "editor",
            anchor = "SE",
            border = "rounded",
        },
    }

    select.setup(expected)

    it("should change default config", function()
        local function tbl_contains(table, value)
            return vim.tbl_contains(table, function(v)
                for k, _ in pairs(value) do
                    if v[k] ~= value[k] then
                        return false
                    end
                end

                return true
            end, { predicate = true })
        end

        assert.equal(expected.default_prompt, config.default_prompt)
        assert.is_true(tbl_contains({ config.win_config }, { relative = "editor", anchor = "SE", border = "rounded" }))
    end)
end)
