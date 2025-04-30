local M = {}

local uv = vim.loop

-- Severity map for ESLint
local severity_map = {
    [1] = "W", -- warning
    [2] = "E" -- error
}

-- Parse tsc or build script output
local function parse_tsc_output(output)
    local items = {}

    for line in output:gmatch("[^\r\n]+") do
        local file, lnum, col, msg = line:match(
                                         "([^:]+)%((%d+),(%d+)%)%:%s+error%s+TS%d+%:%s+(.*)")
        if file and lnum and col and msg then
            table.insert(items, {
                filename = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = msg,
                type = "E"
            })
        end
    end

    return items
end

-- Run ESLint
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

    vim.fn.setqflist({}, " ", {title = "ESLint Results", items = qf_list})
    vim.cmd("copen")
end

-- Run tsc -b
function M.run_tsc()
    local tsc_output = vim.fn.system("tsc -b")
    local items = parse_tsc_output(tsc_output)
    vim.fn
        .setqflist({}, " ", {title = "TypeScript Build Errors", items = items})
    vim.cmd("copen")
end

-- Run custom build script from package.json
function M.run_package_build()
    local package_json = vim.fn.findfile("package.json", ".;")
    if package_json == "" then
        print("No package.json found.")
        return
    end

    local json_data = vim.fn.readfile(package_json)
    local ok, parsed = pcall(vim.fn.json_decode, table.concat(json_data, "\n"))
    if not ok or not parsed.scripts or not parsed.scripts.build then
        print("No build script found in package.json.")
        return
    end

    local build_cmd = parsed.scripts.build
    print("Running: " .. build_cmd)

    local output = vim.fn.system(build_cmd)
    local items = parse_tsc_output(output)

    vim.fn.setqflist({}, " ", {title = "Build Script Output", items = items})
    vim.cmd("copen")
end

-- User commands
vim.api.nvim_create_user_command("QuickFixLint", function() M.run_eslint() end,
                                 {})

vim.api.nvim_create_user_command("QuickFixTSC", function() M.run_tsc() end, {})

vim.api.nvim_create_user_command("QuickFixBuildScript",
                                 function() M.run_package_build() end, {})

return M
