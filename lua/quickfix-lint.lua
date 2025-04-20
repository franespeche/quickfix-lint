local M = {}

-- Severity map for ESLint
local severity_map = {
    [1] = "W", -- warning
    [2] = "E" -- error
}

-- Parse tsc -b output
local function parse_tsc_output(output)
    local items = {}

    for line in output:gmatch("[^\r\n]+") do
        -- Match lines like: tsconfig.app.json(23,5): error TS5023: Unknown compiler option 'noUncheckedSideEffectImports'.
        local file, lnum, col, msg = line:match(
                                         "([^:]+)%((%d+),(%d+)%)%:%s+error%s+TS%d+%:%s+(.*)")
        if file and lnum and col and msg then
            table.insert(items, {
                filename = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = msg,
                type = "E" -- Always an error in this case
            })
        end
    end

    return items
end

-- Run ESLint and populate quickfix list
function M.run_eslint()
    local eslint_output = vim.fn.system("yarn eslint --format json")
    local cleaned = eslint_output:match("%b[]") or "[]"
    local ok, result = pcall(vim.json.decode, cleaned)
    if not ok then
        print("Failed to parse ESLint output:\n" .. eslint_output)
        return
    end

    local qf_list = {}

    for _, fileReport in ipairs(result) do
        local file = fileReport.filePath
        for _, msg in ipairs(fileReport.messages or {}) do
            -- skip warnings (severity 1)
            if msg.severity == 1 then goto continue end
            table.insert(qf_list, {
                filename = file,
                lnum = msg.line,
                col = msg.column,
                text = msg.message ..
                    (msg.ruleId and (" [" .. msg.ruleId .. "]") or ""),
                type = severity_map[msg.severity] or "I"
            })
            ::continue::
        end
    end

    -- Populate the quickfix list for ESLint results
    vim.fn.setqflist({}, " ", {title = "ESLint Results", items = qf_list})
    vim.cmd("copen")
end

-- Run tsc -b and populate quickfix list
function M.run_tsc()
    local tsc_output = vim.fn.system("tsc -b")
    local items = parse_tsc_output(tsc_output)

    -- Populate the quickfix list for TypeScript errors
    vim.fn
        .setqflist({}, " ", {title = "TypeScript Build Errors", items = items})
    vim.cmd("copen")
end

-- User command for manual triggering
vim.api.nvim_create_user_command("QuickFixLint", function() M.run_eslint() end,
                                 {})

vim.api.nvim_create_user_command("QuickFixTSC", function() M.run_tsc() end, {})

return M
